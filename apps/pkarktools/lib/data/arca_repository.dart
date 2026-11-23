import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart';
import 'package:pkcore/pkcore.dart';

import 'db/arca_database.dart';
import 'folder/arca_folder.dart';
import 'folder/arca_layout.dart';
import 'folder/folder_fs.dart';
import 'save_source.dart';

export 'save_source.dart' show SaveSource;

/// Lee un save en otro isolate. Es una función de nivel superior para que
/// el closure solo capture los bytes (nunca la base de datos).
Future<SaveFile> parseSaveInIsolate(Uint8List bytes) => Isolate.run(() => readSaveWithVersion(bytes));

/// Avisos de legalidad (severidad «aviso») de todos los Pokémon del save:
/// equipo y cajas. 0 si el save no se puede abrir con el editor.
int countLegalityWarnings(Uint8List bytes) {
  final SaveEditor editor;
  try {
    editor = SaveEditor.open(bytes);
  } catch (_) {
    return 0;
  }
  int warnings(Pkm pk) => Legality.check(pk, editor.game).where((i) => i.severity == LegalitySeverity.warning).length;
  var n = 0;
  try {
    for (final pk in editor.party) {
      n += warnings(pk);
    }
    for (var b = 0; b < editor.boxCount; b++) {
      for (var i = 0; i < editor.boxSlotCount; i++) {
        final pk = editor.get(SlotRef.box(b, i));
        if (pk != null) n += warnings(pk);
      }
    }
  } catch (_) {
    // Lo que no se puede leer ya lo señala el aviso de daño.
  }
  return n;
}

/// Lee el save y, si no guarda su versión concreta (Rubí o Zafiro, Oro HG o
/// Plata SS…), la deduce de los Pokémon del propio entrenador.
SaveFile readSaveWithVersion(Uint8List bytes) {
  final s = SaveDetector.read(bytes);
  if (s.versionId != null) return s;
  final v = GameVersions.infer(bytes, s);
  return v == null ? s : s.withVersion(v);
}

/// Origen de un import.
enum ImportOrigin {
  file('file'),
  folder('folder'),
  saf('saf'),
  demo('demo'),
  restoreBackup('restore-backup'),
  edit('edit'),
  adopted('adopted'),
  migrated('migrated');

  const ImportOrigin(this.code);
  final String code;

  static ImportOrigin fromCode(String c) =>
      values.firstWhere((o) => o.code == c, orElse: () => ImportOrigin.file);
}

/// Resultado de importar un archivo.
sealed class ImportOutcome {
  const ImportOutcome(this.fileName);
  final String fileName;
}

class ImportAdded extends ImportOutcome {
  const ImportAdded(super.fileName, this.slotId, this.snapshotId, this.save, {required this.newSlot});
  final int slotId;
  final int snapshotId;
  final SaveFile save;
  final bool newSlot;
}

class ImportDuplicate extends ImportOutcome {
  const ImportDuplicate(super.fileName, this.slotId, this.save);
  final int slotId;
  final SaveFile save;
}

class ImportFailed extends ImportOutcome {
  const ImportFailed(super.fileName, this.reason);
  final String reason;
}

/// Una partida del Arca con su snapshot más reciente.
class ArcaEntry {
  const ArcaEntry({
    required this.slot,
    required this.latest,
    required this.snapshotCount,
    this.sources = const {},
    this.edited = false,
  });
  final SaveSlot slot;
  final Snapshot latest;
  final int snapshotCount;

  /// De dónde salieron las copias importadas (sin contar las ediciones).
  final Set<SaveSource> sources;

  /// Alguna copia nació de una edición hecha en la app.
  final bool edited;

  /// La copia más reciente tiene checksums que no cuadran o un problema de
  /// lectura detectado al reindexar.
  bool get damaged => latest.checksum == ChecksumStatus.invalid.name || latest.problem != null;

  GameVersion get game => GameVersion.fromCode(slot.gameCode) ?? GameVersion.redBlue;
}

/// Un elemento del registro de actividad.
class ActivityItem {
  const ActivityItem(this.snapshot, this.slot);
  final Snapshot snapshot;
  final SaveSlot slot;
}

/// Resultado de un reindexado de la carpeta.
class ReindexReport {
  ReindexReport({required this.at});
  final DateTime at;
  int added = 0;
  int removed = 0;
  int unchanged = 0;

  /// Copias con el mismo contenido que otra de la misma partida (p. ej. dos
  /// dispositivos importaron el mismo save): se indexa solo la primera.
  int duplicates = 0;
  final List<ArcaIssue> issues = [];

  /// Saves sueltos que el usuario puede "adoptar".
  List<FsEntry> loose = const [];
  Map<IgnoreReason, int> ignored = const {};
  List<String> placeholders = const [];

  int get ignoredCount => ignored.values.fold(0, (a, b) => a + b);
}

/// Identidad de este dispositivo (se guarda en el `.json` de cada copia).
class ArcaDevice {
  const ArcaDevice(this.id, this.name);
  final String id;
  final String name;
}

/// Lógica de negocio del Arca: importar, listar, leer y exportar snapshots.
///
/// La fuente de verdad es la carpeta ([ArcaFolder]); la base drift es un
/// índice local de este dispositivo que [reindex] reconstruye.
class ArcaRepository {
  ArcaRepository(this.db, ArcaFolder? folder, {String? deviceName})
      : _folder = folder,
        _deviceName = deviceName;

  final ArcaDatabase db;
  ArcaFolder? _folder;
  final String? _deviceName;
  ArcaDevice? _device;

  final _reports = StreamController<ReindexReport>.broadcast();
  ReindexReport? _lastReport;
  Future<ReindexReport>? _running;
  bool _rerun = false;

  bool get hasFolder => _folder != null;

  ArcaFolder get folder => _folder ?? (throw StateError('El Arca no tiene carpeta configurada'));

  /// Cambia la carpeta: vacía el índice local y lo reconstruye.
  Future<ReindexReport> attachFolder(ArcaFolder folder) async {
    await _running;
    _folder = folder;
    await clearIndex();
    await folder.ensureReadme();
    return reindex();
  }

  /// Reabre la misma carpeta (p. ej. tras renovar el permiso) sin vaciar el índice.
  void replaceFolder(ArcaFolder folder) => _folder = folder;

  ReindexReport? get lastReport => _lastReport;
  Stream<ReindexReport> get reports => _reports.stream;

  static String sha256Of(Uint8List bytes) => crypto.sha256.convert(bytes).toString();

  static String encodeParty(List<PokemonSummary> party) =>
      party.map((p) => '${p.species}${p.isShiny ? 's' : ''}${p.isEgg ? 'e' : ''}').join(',');

  static List<({int species, bool shiny, bool egg})> decodeParty(String s) => [
        for (final part in s.split(',').where((e) => e.isNotEmpty))
          (
            species: int.tryParse(part.replaceAll(RegExp('[se]'), '')) ?? 0,
            shiny: part.contains('s'),
            egg: part.contains('e'),
          ),
      ];

  Future<ArcaDevice> device() async {
    if (_device != null) return _device!;
    var id = await getSetting('deviceId');
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = List.generate(8, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await setSetting('deviceId', id);
    }
    var name = _deviceName;
    if (name == null) {
      try {
        name = '${io.Platform.localHostname} (${io.Platform.operatingSystem})';
      } catch (_) {
        name = io.Platform.operatingSystem;
      }
    }
    return _device = ArcaDevice(id, name);
  }

  static SlotMeta _slotMetaOf(SaveSlot s) => SlotMeta(
        identityKey: s.identityKey,
        gameCode: s.gameCode,
        generation: s.generation,
        versionId: s.versionId,
        trainerName: s.trainerName,
        tid: s.tid,
        sid: s.sid,
        displayTid: s.displayTid,
        displaySid: s.displaySid,
      );

  /// Importa un archivo. Nunca lanza: los errores se devuelven como [ImportFailed].
  Future<ImportOutcome> importBytes(
    Uint8List bytes, {
    required String fileName,
    required ImportOrigin origin,
    String? sourcePath,
    DateTime? now,
    String? note,
    int? forceSlotId,
  }) async {
    final SaveFile save;
    try {
      save = await parseSaveInIsolate(bytes);
    } on UnsupportedSaveException catch (e) {
      return ImportFailed(fileName, e.message);
    } on CorruptSaveException catch (e) {
      return ImportFailed(fileName, 'Archivo de ${e.game.nameEs} dañado: ${e.message}');
    } catch (e) {
      return ImportFailed(fileName, 'Error inesperado al leer el archivo: $e');
    }

    final sha = sha256Of(bytes);
    // Sin fracciones de segundo: la fecha viaja en el nombre y en el JSON.
    final ts = DateTime.fromMillisecondsSinceEpoch(((now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000) * 1000);
    final t = save.trainer;
    final dev = await device();
    final folder = this.folder;

    try {
      return await db.transaction(() async {
        final slot = forceSlotId != null
            ? await (db.select(db.saveSlots)..where((s) => s.id.equals(forceSlotId))).getSingleOrNull()
            : await (db.select(db.saveSlots)..where((s) => s.identityKey.equals(save.identityKey))).getSingleOrNull();
        if (slot != null) {
          final existing = await (db.select(db.snapshots)
                ..where((s) => s.slotId.equals(slot.id) & s.sha256.equals(sha)))
              .getSingleOrNull();
          if (existing != null) return ImportDuplicate(fileName, slot.id, save);
        }
        final slotMeta = slot != null
            ? (forceSlotId != null
                ? SlotMeta(
                    identityKey: slot.identityKey,
                    gameCode: slot.gameCode,
                    generation: slot.generation,
                    versionId: save.versionId ?? slot.versionId,
                    trainerName: t.name,
                    tid: slot.tid,
                    sid: slot.sid,
                    displayTid: t.displayTid,
                    displaySid: t.displaySid,
                  )
                : _slotMetaOf(slot))
            : SlotMeta(
                identityKey: save.identityKey,
                gameCode: save.game.code,
                generation: save.generation,
                versionId: save.versionId,
                trainerName: t.name,
                tid: t.tid,
                sid: t.sid,
                displayTid: t.displayTid,
                displaySid: t.displaySid,
              );
        final meta = SnapshotMeta(
          sha256: sha,
          sizeBytes: bytes.length,
          importedAt: ts,
          originalFileName: fileName,
          origin: origin.code,
          sourcePath: sourcePath,
          note: note,
          deviceId: dev.id,
          deviceName: dev.name,
          gameCode: save.game.code,
          generation: save.generation,
          versionId: save.versionId,
          format: save.format,
          checksum: save.checksum.name,
          trainerName: t.name,
          tid: t.tid,
          sid: t.sid,
          displayTid: t.displayTid,
          displaySid: t.displaySid,
          playTimeSeconds: t.playTime.inSeconds,
          partySummary: encodeParty(save.party),
          boxedCount: save.boxedCount,
          slot: slotMeta,
        );
        final rel = await folder.writeSnapshot(bytes, meta);
        final (slotId, newSlot) = await _upsertSlot(slotMeta, ts, renamed: forceSlotId != null);
        final snapId = await _insertSnapshot(slotId, meta, rel);
        return ImportAdded(fileName, slotId, snapId, save, newSlot: newSlot);
      });
    } catch (e) {
      return ImportFailed(fileName, 'No se pudo escribir en la carpeta del Arca: $e');
    }
  }

  /// Crea la partida si no existe o actualiza sus fechas. Devuelve (id, nueva).
  Future<(int, bool)> _upsertSlot(SlotMeta m, DateTime ts, {bool renamed = false}) async {
    final slot = await (db.select(db.saveSlots)..where((s) => s.identityKey.equals(m.identityKey))).getSingleOrNull();
    if (slot == null) {
      final id = await db.into(db.saveSlots).insert(SaveSlotsCompanion.insert(
            identityKey: m.identityKey,
            gameCode: m.gameCode,
            generation: m.generation,
            versionId: Value(m.versionId),
            trainerName: m.trainerName,
            tid: m.tid,
            sid: Value(m.sid),
            displayTid: m.displayTid,
            displaySid: Value(m.displaySid),
            createdAt: ts,
            updatedAt: ts,
          ));
      return (id, true);
    }
    final newer = !ts.isBefore(slot.updatedAt);
    await (db.update(db.saveSlots)..where((s) => s.id.equals(slot.id))).write(SaveSlotsCompanion(
      updatedAt: newer ? Value(ts) : const Value.absent(),
      createdAt: ts.isBefore(slot.createdAt) ? Value(ts) : const Value.absent(),
      versionId: Value(m.versionId ?? slot.versionId),
      trainerName: newer && renamed ? Value(m.trainerName) : const Value.absent(),
      displayTid: newer && renamed ? Value(m.displayTid) : const Value.absent(),
      displaySid: newer && renamed ? Value(m.displaySid) : const Value.absent(),
    ));
    return (slot.id, false);
  }

  Future<int> _insertSnapshot(int slotId, SnapshotMeta m, String rel, {String? problem}) =>
      db.into(db.snapshots).insert(SnapshotsCompanion.insert(
            slotId: slotId,
            sha256: m.sha256,
            importedAt: m.importedAt,
            fileName: m.originalFileName,
            origin: m.origin,
            sourcePath: Value(m.sourcePath),
            sizeBytes: m.sizeBytes,
            playTimeSeconds: m.playTimeSeconds,
            trainerName: m.trainerName,
            gameCode: m.gameCode,
            versionId: Value(m.versionId),
            partySummary: m.partySummary,
            boxedCount: m.boxedCount,
            formatInfo: m.format,
            checksum: m.checksum,
            note: Value(m.note),
            relPath: Value(rel),
            deviceName: Value(m.deviceName),
            problem: Value(problem),
          ));

  // ---------------------------------------------------------------- índice

  /// Vacía el índice local (la carpeta no se toca).
  Future<void> clearIndex() => db.transaction(() async {
        await db.delete(db.snapshots).go();
        await db.delete(db.saveSlots).go();
      });

  /// Reindexado incremental: añade los snapshots nuevos de la carpeta, quita
  /// los que ya no están y marca los problemas sin detenerse. Si ya hay uno en
  /// marcha, se encadena otro al terminar.
  Future<ReindexReport> reindex() {
    if (_running != null) {
      _rerun = true;
      return _running!;
    }
    final f = _reindexLoop();
    _running = f;
    return f.whenComplete(() => _running = null);
  }

  Future<ReindexReport> _reindexLoop() async {
    ReindexReport r;
    do {
      _rerun = false;
      r = await _reindexOnce();
    } while (_rerun);
    _lastReport = r;
    _reports.add(r);
    return r;
  }

  Future<ReindexReport> _reindexOnce() async {
    final folder = this.folder;
    final report = ReindexReport(at: DateTime.now());
    final listing = await folder.listing();
    report
      ..loose = listing.loose
      ..ignored = listing.ignored
      ..placeholders = listing.placeholders;
    for (final side in listing.missingSave) {
      report.issues.add(ArcaIssue(ArcaIssueKind.missingSave, side));
    }
    for (final e in listing.missingSidecar) {
      report.issues.add(ArcaIssue(ArcaIssueKind.missingSidecar, e.path));
    }

    final rows = await db.select(db.snapshots).get();
    final known = <String, Snapshot>{for (final r in rows) if (r.relPath != null) r.relPath!: r};

    // 1. Quitar del índice lo que ya no está en la carpeta (o no tiene ruta).
    final gone = [
      for (final r in rows)
        if (r.relPath == null || !listing.pairs.containsKey(r.relPath)) r.id,
    ];
    // 2. Revisar los que siguen (tamaño) y leer los nuevos.
    final metas = <(String, SnapshotMeta, String?)>[];
    for (final MapEntry(key: rel, value: _) in listing.pairs.entries) {
      final size = listing.files[rel]!.size;
      final row = known[rel];
      if (row != null) {
        report.unchanged++;
        final problem = size != row.sizeBytes ? 'size' : (row.problem == 'size' ? null : row.problem);
        if (problem != row.problem) {
          await (db.update(db.snapshots)..where((s) => s.id.equals(row.id))).write(SnapshotsCompanion(problem: Value(problem)));
        }
        if (problem == 'size') report.issues.add(ArcaIssue(ArcaIssueKind.sizeMismatch, rel));
        continue;
      }
      try {
        final meta = await folder.readMeta(rel);
        String? problem;
        if (meta.sizeBytes != size) {
          problem = 'size';
          report.issues.add(ArcaIssue(ArcaIssueKind.sizeMismatch, rel, '${meta.sizeBytes} ≠ $size'));
        }
        metas.add((rel, meta, problem));
      } on FormatException catch (e) {
        report.issues.add(ArcaIssue(ArcaIssueKind.corruptSidecar, listing.pairs[rel]!, e.message));
      } on Exception catch (e) {
        report.issues.add(ArcaIssue(ArcaIssueKind.unreadable, listing.pairs[rel]!, '$e'));
      }
    }
    // Orden estable en todos los dispositivos: la copia más antigua gana.
    metas.sort((a, b) {
      final c = a.$2.importedAt.compareTo(b.$2.importedAt);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });

    await db.transaction(() async {
      if (gone.isNotEmpty) {
        await (db.delete(db.snapshots)..where((s) => s.id.isIn(gone))).go();
        report.removed = gone.length;
      }
      for (final (rel, meta, problem) in metas) {
        final (slotId, _) = await _upsertSlot(meta.slot, meta.importedAt, renamed: true);
        final dup = await (db.select(db.snapshots)..where((s) => s.slotId.equals(slotId) & s.sha256.equals(meta.sha256)))
            .getSingleOrNull();
        if (dup != null) {
          report.duplicates++;
          // Todos los dispositivos convergen en la misma copia: la más antigua
          // (y, a igual fecha, la de ruta menor).
          final c = meta.importedAt.compareTo(dup.importedAt);
          if (c < 0 || (c == 0 && rel.compareTo(dup.relPath ?? '') < 0)) {
            await (db.update(db.snapshots)..where((s) => s.id.equals(dup.id))).write(SnapshotsCompanion(
              relPath: Value(rel),
              importedAt: Value(meta.importedAt),
              fileName: Value(meta.originalFileName),
              origin: Value(meta.origin),
              sourcePath: Value(meta.sourcePath),
              note: Value(meta.note),
              deviceName: Value(meta.deviceName),
              problem: Value(problem),
            ));
          }
          continue;
        }
        await _insertSnapshot(slotId, meta, rel, problem: problem);
        report.added++;
      }
      if (gone.isNotEmpty) await _dropEmptySlots();
    });
    return report;
  }

  Future<void> _dropEmptySlots() => db.customStatement(
      'DELETE FROM save_slots WHERE id NOT IN (SELECT DISTINCT slot_id FROM snapshots)');

  /// Adopta un save suelto de la carpeta: lo identifica, lo coloca en su sitio
  /// con su `.json` y, una vez verificada la copia, borra el suelto.
  Future<ImportOutcome> adopt(String relPath) async {
    final name = relPath.split('/').last;
    final Uint8List bytes;
    try {
      bytes = await folder.read(relPath);
    } catch (e) {
      return ImportFailed(name, 'No se pudo leer $relPath: $e');
    }
    final out = await importBytes(bytes, fileName: name, origin: ImportOrigin.adopted);
    final sha = sha256Of(bytes);
    final keep = switch (out) {
      ImportAdded(:final snapshotId) => await _verifyStored(snapshotId, sha),
      ImportDuplicate() => true,
      ImportFailed() => false,
    };
    if (keep) await folder.delete(relPath);
    await reindex();
    return out;
  }

  Future<bool> _verifyStored(int snapshotId, String sha) async {
    try {
      final s = await snapshot(snapshotId);
      await folder.readVerified(s.relPath!, sha);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------- lectura

  /// Partidas del Arca, la actualizada más recientemente primero.
  Stream<List<ArcaEntry>> watchArca() {
    final q = db.select(db.snapshots).join([
      innerJoin(db.saveSlots, db.saveSlots.id.equalsExp(db.snapshots.slotId)),
    ]);
    return q.watch().map((rows) {
      final bySlot = <int, List<Snapshot>>{};
      final slots = <int, SaveSlot>{};
      for (final r in rows) {
        final snap = r.readTable(db.snapshots);
        slots[snap.slotId] = r.readTable(db.saveSlots);
        bySlot.putIfAbsent(snap.slotId, () => []).add(snap);
      }
      final entries = [
        for (final MapEntry(:key, :value) in bySlot.entries)
          ArcaEntry(
            slot: slots[key]!,
            latest: value.reduce((a, b) => _newer(a, b) ? a : b),
            snapshotCount: value.length,
            sources: _sources(value),
            edited: value.any((s) => s.origin == ImportOrigin.edit.code),
          ),
      ]..sort((a, b) => b.slot.updatedAt.compareTo(a.slot.updatedAt));
      return entries;
    });
  }

  static Set<SaveSource> _sources(List<Snapshot> snaps) {
    const derived = {'edit', 'restore-backup'};
    final imported = snaps.where((s) => !derived.contains(s.origin));
    final found = {for (final s in imported) SaveSource.ofSnapshot(s)};
    if (found.length > 1) found.remove(SaveSource.other);
    return found.isEmpty ? const {SaveSource.other} : found;
  }

  static bool _newer(Snapshot a, Snapshot b) {
    final c = a.importedAt.compareTo(b.importedAt);
    return c != 0 ? c > 0 : a.id > b.id;
  }

  Stream<SaveSlot?> watchSlot(int slotId) =>
      (db.select(db.saveSlots)..where((s) => s.id.equals(slotId))).watchSingleOrNull();

  /// Snapshots de una partida, del más reciente al más antiguo.
  Stream<List<Snapshot>> watchSnapshots(int slotId) => (db.select(db.snapshots)
        ..where((s) => s.slotId.equals(slotId))
        ..orderBy([(s) => OrderingTerm.desc(s.importedAt), (s) => OrderingTerm.desc(s.id)]))
      .watch();

  Stream<List<ActivityItem>> watchActivity({int limit = 200}) {
    final q = db.select(db.snapshots).join([
      innerJoin(db.saveSlots, db.saveSlots.id.equalsExp(db.snapshots.slotId)),
    ])
      ..orderBy([OrderingTerm.desc(db.snapshots.importedAt), OrderingTerm.desc(db.snapshots.id)])
      ..limit(limit);
    return q.watch().map((rows) => [
          for (final r in rows) ActivityItem(r.readTable(db.snapshots), r.readTable(db.saveSlots)),
        ]);
  }

  Stream<int> watchSnapshotCount() {
    final c = db.snapshots.id.count();
    return (db.selectOnly(db.snapshots)..addColumns([c])).map((r) => r.read(c) ?? 0).watchSingle();
  }

  /// Avisos de legalidad de una copia, calculados en otro isolate.
  Future<int> legalityWarnings(Snapshot s) async {
    final bytes = await snapshotBytes(s);
    return Isolate.run(() => countLegalityWarnings(bytes));
  }

  Future<Snapshot> snapshot(int id) => (db.select(db.snapshots)..where((s) => s.id.equals(id))).getSingle();

  /// Bytes de un snapshot, comprobando su SHA-256. Si no coincide, la copia
  /// se marca como dañada y se lanza [ArcaFileCorruptException].
  Future<Uint8List> snapshotBytes(Snapshot s) async {
    final rel = s.relPath;
    if (rel == null) throw ArcaFileCorruptException(s.fileName, 'sin ruta en la carpeta');
    try {
      return await folder.readVerified(rel, s.sha256);
    } on ArcaFileCorruptException {
      await (db.update(db.snapshots)..where((x) => x.id.equals(s.id))).write(const SnapshotsCompanion(problem: Value('hash')));
      rethrow;
    } on io.FileSystemException catch (e) {
      throw ArcaFileCorruptException(rel, 'no se pudo leer (${e.message})');
    }
  }

  /// Lee y parsea un snapshot fuera del hilo de UI.
  Future<SaveFile> parseSnapshot(int snapshotId) async {
    final s = await snapshot(snapshotId);
    return parseSaveInIsolate(await snapshotBytes(s));
  }

  /// Guarda el resultado de una edición como snapshot nuevo de la misma partida.
  Future<ImportOutcome> saveEdited(
    Uint8List bytes, {
    required int slotId,
    required String fileName,
    required String note,
    String? sourcePath,
    DateTime? now,
  }) =>
      importBytes(bytes,
          fileName: fileName, origin: ImportOrigin.edit, sourcePath: sourcePath, now: now, note: note, forceSlotId: slotId);

  /// Elimina una partida: borra del índice y de la carpeta sus copias (save +
  /// `.json`). Los demás dispositivos lo verán en su próximo reindexado.
  /// Fija a mano la versión concreta de una partida (cuando el save no la
  /// guarda). Se escribe en el .json de cada snapshot de la partida, así
  /// sobrevive a un reindexado y viaja con la carpeta del Arca.
  Future<void> setSlotVersion(int slotId, int? versionId) async {
    final snaps = await (db.select(db.snapshots)..where((s) => s.slotId.equals(slotId))).get();
    for (final s in snaps) {
      final rel = s.relPath;
      if (rel == null) continue;
      try {
        final meta = await folder.readMeta(rel);
        await folder.rewriteMeta(rel, meta.withSlotVersion(versionId));
      } catch (_) {
        // Un sidecar ilegible se queda como está; el índice se actualiza igual.
      }
    }
    final fallback = snaps.map((s) => s.versionId).nonNulls.firstOrNull;
    await (db.update(db.saveSlots)..where((s) => s.id.equals(slotId)))
        .write(SaveSlotsCompanion(versionId: Value(versionId ?? fallback)));
  }

  Future<void> deleteSlot(int slotId) async {
    final snaps = await (db.select(db.snapshots)..where((s) => s.slotId.equals(slotId))).get();
    await db.transaction(() async {
      await (db.delete(db.snapshots)..where((s) => s.slotId.equals(slotId))).go();
      await (db.delete(db.saveSlots)..where((s) => s.id.equals(slotId))).go();
    });
    for (final s in snaps) {
      final rel = s.relPath;
      if (rel == null) continue;
      // Primero el .json: sin él, otro dispositivo nunca indexa un save a medias.
      await folder.delete(ArcaLayout.sidecarFor(rel));
      await folder.delete(rel);
    }
  }

  /// SHA-256 de todos los snapshots del Arca (para detectar duplicados antes de importar).
  Future<Set<String>> knownHashes() async => {for (final s in await db.select(db.snapshots).get()) s.sha256};

  /// Todas las partidas con sus snapshots (del más antiguo al más reciente).
  Future<List<(SaveSlot, List<Snapshot>)>> allSlots() async {
    final slots = await db.select(db.saveSlots).get();
    final snaps = await (db.select(db.snapshots)
          ..orderBy([(s) => OrderingTerm.asc(s.importedAt), (s) => OrderingTerm.asc(s.id)]))
        .get();
    return [for (final slot in slots) (slot, snaps.where((s) => s.slotId == slot.id).toList())];
  }

  // ---- Preferencias (locales de este dispositivo) ----

  Future<String?> getSetting(String key) async =>
      (await (db.select(db.settings)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSetting(String key, String value) =>
      db.into(db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> setJsonSetting(String key, Map<String, Object?> value) => setSetting(key, jsonEncode(value));

  Future<Map<String, Object?>?> getJsonSetting(String key) async {
    final v = await getSetting(key);
    if (v == null || v.isEmpty) return null;
    try {
      return jsonDecode(v) as Map<String, Object?>;
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() => _reports.close();
}
