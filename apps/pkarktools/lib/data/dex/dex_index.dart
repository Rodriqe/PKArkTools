import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:pkcore/pkcore.dart';

import '../arca_repository.dart';
import '../db/arca_database.dart';

/// Lee varias copias en otro isolate y devuelve su escaneo para la Dex (JSON).
/// Función de nivel superior: el closure solo captura los bytes.
Future<List<String>> scanForDexInIsolate(List<(Uint8List, int?)> saves) =>
    Isolate.run(() => [for (final (b, v) in saves) SaveDexScan.scan(b, versionId: v).encode()]);

/// Datos mínimos de una partida para construir la Dex en otro isolate.
typedef DexSourceData = ({int id, String game, int? versionId, String trainer, String json});

GlobalDex buildGlobalDex(List<DexSourceData> data) => GlobalDex.build([
      for (final d in data)
        if (GameVersion.fromCode(d.game) case final game?)
          if (SaveDexScan.decode(d.json) case final scan?)
            DexSource(id: d.id, game: game, versionId: d.versionId, trainer: d.trainer, scan: scan),
    ]);

/// Índice de la Dex global: escaneos cacheados en el índice local (drift,
/// tabla `dex_scans`, por SHA-256) y la Dex construida a partir de la copia
/// más reciente de cada partida.
///
/// El escaneo es incremental: solo se leen las copias que no están en la
/// caché (normalmente, las nuevas de un reindexado), en segundo plano. Abrir
/// la pestaña solo decodifica la caché y cruza las partidas (milisegundos).
class DexIndex {
  DexIndex(this.repo);
  final ArcaRepository repo;
  ArcaDatabase get _db => repo.db;

  String? _lastKey;
  GlobalDex? _last;
  Future<void>? _scanning;

  /// Escanea en segundo plano las copias que faltan en la caché y borra las
  /// que ya no son la última de ninguna partida.
  Future<void> refresh(List<Snapshot> latest) {
    final prev = _scanning;
    final next = () async {
      if (prev != null) await prev;
      await _ensure(latest);
      await _prune({for (final s in latest) s.sha256});
    }();
    _scanning = next;
    return next.whenComplete(() {
      if (identical(_scanning, next)) _scanning = null;
    });
  }

  Future<void> _ensure(List<Snapshot> snaps) async {
    final rows = await _db.select(_db.dexScans).get();
    final have = {for (final r in rows) if (r.version == SaveDexScan.formatVersion) r.sha256};
    final missing = <String, Snapshot>{
      for (final s in snaps)
        if (!have.contains(s.sha256) && s.relPath != null) s.sha256: s,
    }.values.toList();
    const batch = 6;
    for (var i = 0; i < missing.length; i += batch) {
      final part = missing.sublist(i, (i + batch).clamp(0, missing.length));
      final inputs = <(Uint8List, int?)>[];
      final ok = <Snapshot>[];
      for (final s in part) {
        try {
          inputs.add((await repo.snapshotBytes(s), s.versionId));
          ok.add(s);
        } catch (_) {
          // Copia ilegible: la señala el Arca; la Dex la omite.
        }
      }
      if (inputs.isEmpty) continue;
      final out = await scanForDexInIsolate(inputs);
      await _db.batch((b) {
        for (final (j, s) in ok.indexed) {
          b.insert(
            _db.dexScans,
            DexScansCompanion.insert(sha256: s.sha256, version: SaveDexScan.formatVersion, data: out[j]),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    }
  }

  Future<void> _prune(Set<String> keep) async {
    if (keep.isEmpty) {
      await _db.delete(_db.dexScans).go();
      return;
    }
    await (_db.delete(_db.dexScans)..where((t) => t.sha256.isNotIn(keep))).go();
  }

  /// Dex de las partidas [entries] (su copia más reciente). Reutiliza la
  /// última si nada cambió.
  Future<GlobalDex> build(List<ArcaEntry> entries) async {
    final key = [for (final e in entries) '${e.slot.id}:${e.latest.sha256}:${e.slot.versionId}'].join('|');
    if (key == _lastKey && _last != null) return _last!;
    await refresh([for (final e in entries) e.latest]);
    final shas = {for (final e in entries) e.latest.sha256};
    final rows = shas.isEmpty
        ? const <DexScanRow>[]
        : await (_db.select(_db.dexScans)..where((t) => t.sha256.isIn(shas))).get();
    final bySha = {for (final r in rows) r.sha256: r.data};
    final data = <DexSourceData>[
      for (final e in entries)
        if (bySha[e.latest.sha256] case final json?)
          (id: e.slot.id, game: e.slot.gameCode, versionId: e.slot.versionId, trainer: e.slot.trainerName, json: json),
    ];
    final dex = data.length > 4 ? await Isolate.run(() => buildGlobalDex(data)) : buildGlobalDex(data);
    _lastKey = key;
    _last = dex;
    return dex;
  }
}
