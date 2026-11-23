import 'dart:convert';
import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';

import 'arca_repository.dart';
import 'folder/arca_folder.dart';
import 'folder/arca_layout.dart';
import 'folder/arca_main_files.dart';
import 'folder/folder_fs.dart';

/// Tipos de problema de la carpeta del Arca que Ajustes resume y sabe
/// arreglar. El orden es el de los grupos en pantalla (lo grave primero).
enum ArcaProblemKind {
  /// `.json` ilegible, de otro formato o con campos que faltan.
  corruptSidecar,

  /// Save del historial sin su `.json`.
  missingSidecar,

  /// `.json` del historial sin su save.
  missingSave,

  /// El save no coincide con su `.json` (tamaño o SHA-256).
  contentMismatch,

  /// No se pudo leer el `.json` (permiso, archivo bloqueado…).
  unreadable,

  /// No se pudo escribir el archivo principal o `ultima.json`.
  mainFailed,

  /// Save de una bandeja de entrada que no se puede leer.
  inboxUnreadable,

  /// Save de una bandeja de entrada que es de otro juego.
  inboxWrongGame,

  /// Archivo principal reemplazado a mano (contenido fuera del historial).
  modifiedMain,

  /// Copia de conflicto de la nube (`main (1)`, `… (1).sav`, `conflicted copy`…).
  conflictCopy,

  /// Copia del historial con el mismo SHA-256 que otra más antigua de la
  /// misma carpeta de entrenador ([ArcaProblem.detail] = la que se conserva).
  duplicateCopy,

  /// Save copiado a mano fuera de su sitio.
  looseSave;

  /// Errores (rojo) frente a avisos (ámbar).
  bool get isError => switch (this) {
        corruptSidecar || missingSidecar || missingSave || contentMismatch || unreadable || mainFailed || inboxUnreadable => true,
        _ => false,
      };
}

/// Un problema concreto, con lo necesario para arreglarlo o ignorarlo.
class ArcaProblem {
  const ArcaProblem(this.kind, this.path, {this.size, this.modified, this.detail, this.game});

  final ArcaProblemKind kind;

  /// Ruta relativa a la raíz del Arca del archivo afectado (el `.json` en
  /// [ArcaProblemKind.missingSave], [ArcaProblemKind.corruptSidecar] y
  /// [ArcaProblemKind.unreadable]; el save o principal en el resto).
  final String path;
  final int? size;
  final DateTime? modified;
  final String? detail;

  /// Juego real del save (bandeja con un save de otro juego).
  final GameVersion? game;

  String get name => path.split('/').last;

  /// Clave para «Ignorar»: ruta + tamaño + fecha. Si el archivo cambia, la
  /// clave cambia y el problema vuelve a avisar.
  String get ignoreKey => '$path|${size ?? -1}|${modified?.millisecondsSinceEpoch ?? 0}';

  /// Save al que se refiere el problema (sin `.json`).
  String get savePath =>
      path.endsWith(ArcaLayout.sidecarExt) ? path.substring(0, path.length - ArcaLayout.sidecarExt.length) : path;

  @override
  String toString() => '${kind.name} $path';
}

/// Resume en una lista de [ArcaProblem] todo lo que el reindexado deja
/// pendiente: problemas de los `.json`, principales, bandeja, conflictos y
/// saves sueltos.
List<ArcaProblem> arcaProblemsOf(ReindexReport? report) {
  if (report == null) return const [];
  final entries = report.entries;
  ArcaProblem p(ArcaProblemKind kind, String path, {String? detail, GameVersion? game}) {
    final e = entries[path];
    return ArcaProblem(kind, path, size: e?.size, modified: e?.modified, detail: detail, game: game);
  }

  final out = <ArcaProblem>[];
  for (final i in report.issues) {
    out.add(switch (i.kind) {
      ArcaIssueKind.missingSave => p(ArcaProblemKind.missingSave, i.path, detail: i.detail),
      ArcaIssueKind.missingSidecar => p(ArcaProblemKind.missingSidecar, i.path, detail: i.detail),
      ArcaIssueKind.corruptSidecar => p(ArcaProblemKind.corruptSidecar, i.path, detail: i.detail),
      ArcaIssueKind.sizeMismatch || ArcaIssueKind.hashMismatch => p(ArcaProblemKind.contentMismatch, i.path, detail: i.detail),
      ArcaIssueKind.unreadable => p(ArcaProblemKind.unreadable, i.path, detail: i.detail),
    });
  }
  for (final m in report.mains) {
    if (m.state == MainState.failed) out.add(p(ArcaProblemKind.mainFailed, m.path, detail: m.detail));
    if (m.state == MainState.modified) out.add(p(ArcaProblemKind.modifiedMain, m.path));
  }
  for (final i in report.inboxProblems) {
    out.add(i.kind == InboxProblemKind.wrongGame
        ? p(ArcaProblemKind.inboxWrongGame, i.path, game: i.actualGame)
        : p(ArcaProblemKind.inboxUnreadable, i.path, detail: i.detail));
  }
  for (final e in report.conflicts) {
    out.add(p(ArcaProblemKind.conflictCopy, e.path));
  }
  for (final (path, kept) in report.historyDuplicates) {
    out.add(p(ArcaProblemKind.duplicateCopy, path, detail: kept));
  }
  for (final e in report.loose) {
    out.add(p(ArcaLayout.ignoreReason(e.path) == IgnoreReason.conflictCopy ? ArcaProblemKind.conflictCopy : ArcaProblemKind.looseSave,
        e.path));
  }
  out.sort((a, b) {
    final c = a.kind.index.compareTo(b.kind.index);
    return c != 0 ? c : a.path.compareTo(b.path);
  });
  return out;
}

/// Problemas ignorados en este dispositivo (en los ajustes locales, nunca en
/// la carpeta del Arca).
abstract final class ArcaProblemIgnores {
  static const settingKey = 'arcaIgnoredProblems';

  static Future<Set<String>> load(ArcaRepository repo) async {
    final raw = await repo.getJsonSetting(settingKey);
    final keys = raw?['keys'];
    return keys is List ? {for (final k in keys) if (k is String) k} : <String>{};
  }

  static Future<void> save(ArcaRepository repo, Set<String> keys) =>
      repo.setJsonSetting(settingKey, {'keys': (keys.toList()..sort())});
}

/// Qué pasó al arreglar un problema.
enum FixOutcome {
  /// Arreglado en su sitio (`.json` regenerado, save adoptado, principal reescrito…).
  fixed,

  /// Copia de conflicto o suelta cuyo contenido ya estaba en el historial: retirada.
  retired,

  /// Irreparable: apartado a `_cuarentena/` con una nota.
  quarantined,

  /// No se pudo hacer nada (se queda como estaba).
  failed,
}

class FixSummary {
  final Map<FixOutcome, int> counts = {};
  final List<String> errors = [];

  int get fixed => (counts[FixOutcome.fixed] ?? 0) + (counts[FixOutcome.retired] ?? 0);
  int get quarantined => counts[FixOutcome.quarantined] ?? 0;
  int get failed => counts[FixOutcome.failed] ?? 0;

  void add(FixOutcome o) => counts.update(o, (v) => v + 1, ifAbsent: () => 1);
}

/// Arregla problemas de la carpeta del Arca. Nunca borra un save: lo que no
/// se puede reparar se mueve a `_cuarentena/` (verificado por su SHA-256)
/// con una nota; solo se retira una copia cuando su contenido exacto ya está
/// a salvo en el historial.
class ArcaRepair {
  ArcaRepair(this.repo);

  final ArcaRepository repo;

  ArcaFolder get folder => repo.folder;

  /// Arregla [problems] en orden y reindexa una vez al final.
  Future<FixSummary> fixAll(List<ArcaProblem> problems, {void Function(int done, int total)? onProgress}) async {
    final summary = FixSummary();
    onProgress?.call(0, problems.length);
    for (final (i, p) in problems.indexed) {
      FixOutcome o;
      try {
        o = await fix(p);
      } catch (e) {
        o = FixOutcome.failed;
        summary.errors.add('${p.path}: $e');
      }
      summary.add(o);
      onProgress?.call(i + 1, problems.length);
    }
    await repo.reindex();
    return summary;
  }

  /// Arregla un problema (sin reindexar).
  Future<FixOutcome> fix(ArcaProblem p) async {
    switch (p.kind) {
      case ArcaProblemKind.corruptSidecar:
      case ArcaProblemKind.unreadable:
      case ArcaProblemKind.missingSidecar:
        return _regenerateSidecar(p.savePath, oldSidecar: p.kind == ArcaProblemKind.missingSidecar ? null : p.path);
      case ArcaProblemKind.missingSave:
        await quarantine(p.path, 'El .json no tiene su save / The .json has no save');
        return FixOutcome.quarantined;
      case ArcaProblemKind.contentMismatch:
        return _replaceMismatch(p.savePath);
      case ArcaProblemKind.mainFailed:
        final mains = await repo.refreshMainsFor(ArcaLayout.ownerDirOf(p.path));
        final m = mains.where((m) => m.path == p.path).firstOrNull;
        return m == null || m.state == MainState.failed ? FixOutcome.failed : FixOutcome.fixed;
      case ArcaProblemKind.modifiedMain:
        return _adoptBytes(p.path, keepSource: true);
      case ArcaProblemKind.inboxWrongGame:
      case ArcaProblemKind.looseSave:
      case ArcaProblemKind.conflictCopy:
        return _adoptBytes(p.path);
      case ArcaProblemKind.duplicateCopy:
        return _retireDuplicate(p.path, p.detail);
      case ArcaProblemKind.inboxUnreadable:
        await quarantine(p.path, 'No es un save legible / Not a readable save${p.detail == null ? '' : ': ${p.detail}'}');
        return FixOutcome.quarantined;
    }
  }

  /// Mueve [rel] a `_cuarentena/<rel>` (sufijo si ya existe), comprueba la
  /// copia por su SHA-256, escribe una nota al lado y solo entonces retira el
  /// original. Devuelve la ruta en cuarentena.
  Future<String> quarantine(String rel, String reason, {String subdir = ''}) async {
    final bytes = await folder.read(rel);
    final sha = ArcaFolder.sha256Of(bytes);
    String? dest;
    for (var n = 0; n < 50 && dest == null; n++) {
      final candidate = '${ArcaLayout.quarantineDir}/${subdir.isEmpty ? '' : '$subdir/'}$rel${n == 0 ? '' : ' ($n)'}';
      try {
        await folder.writeNew(candidate, bytes);
        dest = candidate;
      } on FsExistsException {
        if (ArcaFolder.sha256Of(await folder.read(candidate)) == sha) dest = candidate;
      }
    }
    if (dest == null) throw StateError('sin nombre libre en ${ArcaLayout.quarantineDir}/');
    await folder.readVerified(dest, sha);
    final note = [
      'PKArkTools · cuarentena / quarantine',
      'Archivo / File: $rel',
      'Motivo / Reason: $reason',
      'Fecha / Date: ${DateTime.now().toUtc().toIso8601String()}',
      'SHA-256: $sha',
      '',
      'Nada se ha borrado: este archivo es el original, apartado para que no moleste.',
      'Nothing was deleted: this is the original file, set aside so it stops getting in the way.',
      '',
    ].join('\n');
    try {
      await folder.writeReplace('$dest.nota.txt', Uint8List.fromList(utf8.encode(note)));
    } catch (_) {
      // La nota es una ayuda: la copia ya está verificada.
    }
    await folder.delete(rel);
    return dest;
  }

  /// Subcarpeta de la cuarentena para las copias duplicadas del historial.
  static const duplicatesDir = 'duplicados';

  /// Duplicado del historial: con la copia que se conserva verificada por su
  /// SHA-256, el duplicado y su `.json` van a `_cuarentena/duplicados/`.
  Future<FixOutcome> _retireDuplicate(String rel, String? kept) async {
    if (kept == null) return FixOutcome.failed;
    final sha = ArcaFolder.sha256Of(await folder.read(rel));
    // Lanza si la que se conserva falta o no coincide: entonces no se toca nada.
    await folder.readVerified(kept, sha);
    final keptMeta = await folder.readMeta(kept);
    if (keptMeta.sha256 != sha) throw StateError('$kept no tiene el mismo contenido');
    final reason = 'Copia duplicada de / Duplicate of: $kept';
    final side = ArcaLayout.sidecarFor(rel);
    if (await folder.exists(side)) await quarantine(side, reason, subdir: duplicatesDir);
    await quarantine(rel, reason, subdir: duplicatesDir);
    // Su contenido sigue a salvo en la copia conservada: cuenta como arreglado.
    return FixOutcome.retired;
  }

  /// Importa el contenido de [rel] como copia nueva de su partida y, con la
  /// copia verificada (o si ya estaba en el historial), retira [rel] salvo
  /// con [keepSource]. Si no es un save legible, va a la cuarentena.
  Future<FixOutcome> _adoptBytes(String rel, {bool keepSource = false}) async {
    final bytes = await folder.read(rel);
    final sha = ArcaFolder.sha256Of(bytes);
    final out = await repo.importBytes(bytes, fileName: rel.split('/').last, origin: ImportOrigin.adopted);
    switch (out) {
      case ImportFailed(:final reason):
        if (keepSource) return FixOutcome.failed;
        await quarantine(rel, reason);
        return FixOutcome.quarantined;
      case ImportAdded(:final snapshotId):
        final s = await repo.snapshot(snapshotId);
        await folder.readVerified(s.relPath!, sha);
        if (!keepSource) await folder.delete(rel);
        return FixOutcome.fixed;
      case ImportDuplicate():
        if (!await _inHistory(sha)) return FixOutcome.failed;
        if (keepSource) return FixOutcome.fixed;
        await folder.delete(rel);
        return FixOutcome.retired;
    }
  }

  /// `true` si alguna copia íntegra del historial tiene ese contenido.
  Future<bool> _inHistory(String sha) async {
    for (final s in await repo.db.select(repo.db.snapshots).get()) {
      if (s.sha256 != sha || s.relPath == null) continue;
      try {
        await folder.readVerified(s.relPath!, sha);
        return true;
      } catch (_) {}
    }
    return false;
  }

  /// El save no coincide con su `.json`: su contenido actual entra como copia
  /// nueva (si es un save legible) y la pareja antigua va a la cuarentena.
  Future<FixOutcome> _replaceMismatch(String saveRel) async {
    final bytes = await folder.read(saveRel);
    final sha = ArcaFolder.sha256Of(bytes);
    final out = await repo.importBytes(bytes, fileName: saveRel.split('/').last, origin: ImportOrigin.adopted);
    final kept = switch (out) {
      ImportAdded(:final snapshotId) => await _verifiedSnapshot(snapshotId, sha),
      ImportDuplicate() => await _inHistory(sha),
      ImportFailed() => false,
    };
    await quarantine(saveRel, 'El save no coincide con su .json / The save does not match its .json');
    if (await folder.exists(ArcaLayout.sidecarFor(saveRel))) {
      await quarantine(ArcaLayout.sidecarFor(saveRel), 'El .json no coincide con su save / The .json does not match its save');
    }
    return kept ? FixOutcome.fixed : FixOutcome.quarantined;
  }

  Future<bool> _verifiedSnapshot(int id, String sha) async {
    try {
      final s = await repo.snapshot(id);
      await folder.readVerified(s.relPath!, sha);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Regenera el `.json` de una copia del historial releyendo el save: SHA-256,
  /// tamaño, juego, entrenador, horas y resumen se recalculan; la fecha, el
  /// origen, la nota y la partida se conservan del `.json` anterior si se
  /// pueden leer (si no, la fecha sale del nombre). El `.json` anterior se
  /// aparta a la cuarentena antes de reemplazarlo.
  Future<FixOutcome> _regenerateSidecar(String saveRel, {String? oldSidecar}) async {
    final Uint8List bytes;
    try {
      bytes = await folder.read(saveRel);
    } catch (_) {
      // Sin save: el .json sobra.
      if (oldSidecar != null && await folder.exists(oldSidecar)) {
        await quarantine(oldSidecar, 'El .json no tiene su save / The .json has no save');
        return FixOutcome.quarantined;
      }
      return FixOutcome.failed;
    }
    final sha = ArcaFolder.sha256Of(bytes);
    final name = saveRel.split('/').last;
    // El nombre lleva los 8 primeros del hash: si no cuadra, el save cambió.
    if (!name.contains('_${sha.substring(0, 8)}')) return _replaceMismatch(saveRel);
    final SaveFile save;
    try {
      save = await parseSaveInIsolate(bytes);
    } catch (e) {
      await quarantine(saveRel, 'No es un save legible / Not a readable save: $e');
      if (oldSidecar != null && await folder.exists(oldSidecar)) {
        await quarantine(oldSidecar, 'Su save no se puede leer / Its save cannot be read');
      }
      return FixOutcome.quarantined;
    }
    // Sin .json: quizá se apartó antes a la cuarentena (save aún sin llegar).
    final quarantined = '${ArcaLayout.quarantineDir}/${ArcaLayout.sidecarFor(saveRel)}';
    final old = oldSidecar != null
        ? await _lenientRead(oldSidecar)
        : (await folder.exists(quarantined) ? await _lenientRead(quarantined) : null);
    final meta = await _metaFor(save, bytes, sha, name, old);
    if (oldSidecar != null && await folder.exists(oldSidecar)) {
      await quarantine(oldSidecar, 'Sustituido por un .json regenerado / Replaced by a regenerated .json');
    }
    await folder.rewriteMeta(saveRel, meta);
    final check = await folder.readMeta(saveRel);
    if (check.sha256 != sha) throw StateError('el .json regenerado no corresponde a la copia');
    return FixOutcome.fixed;
  }

  Future<Map<String, Object?>?> _lenientRead(String rel) async {
    try {
      final raw = jsonDecode(utf8.decode(await folder.read(rel), allowMalformed: true));
      return raw is Map<String, Object?> ? raw : null;
    } catch (_) {
      return null;
    }
  }

  /// Fecha del nombre `AAAA-MM-DD_HHMMSS_…` (hora local).
  static DateTime? stampOf(String name) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})_(\d{2})(\d{2})(\d{2})_').firstMatch(name);
    if (m == null) return null;
    final v = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
    return DateTime(v[0], v[1], v[2], v[3], v[4], v[5]);
  }

  Future<SnapshotMeta> _metaFor(SaveFile save, Uint8List bytes, String sha, String name, Map<String, Object?>? old) async {
    T? pick<T>(Object? v) => v is T ? v : null;
    final dev = await repo.device();
    final t = save.trainer;
    SlotMeta? slot;
    try {
      final s = old?['slot'];
      if (s is Map<String, Object?>) slot = SlotMeta.fromJson(s);
    } catch (_) {}
    final device = pick<Map<String, Object?>>(old?['device']);
    return SnapshotMeta(
      sha256: sha,
      sizeBytes: bytes.length,
      importedAt: DateTime.tryParse(pick<String>(old?['importedAt']) ?? '')?.toLocal() ?? stampOf(name) ?? DateTime.now(),
      originalFileName: pick<String>(old?['originalFileName']) ?? name,
      origin: pick<String>(old?['origin']) ?? ImportOrigin.adopted.code,
      sourcePath: pick<String>(old?['sourcePath']),
      note: pick<String>(old?['note']),
      deviceId: pick<String>(device?['id']) ?? dev.id,
      deviceName: pick<String>(device?['name']) ?? dev.name,
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
      partySummary: ArcaRepository.encodeParty(save.party),
      boxedCount: save.boxedCount,
      slot: slot ??
          SlotMeta(
            identityKey: save.identityKey,
            gameCode: save.game.code,
            generation: save.generation,
            versionId: save.versionId,
            trainerName: t.name,
            tid: t.tid,
            sid: t.sid,
            displayTid: t.displayTid,
            displaySid: t.displaySid,
          ),
    );
  }
}
