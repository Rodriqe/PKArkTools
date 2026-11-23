import 'package:drift/drift.dart';

import '../blob_store.dart';
import '../db/arca_database.dart';
import 'arca_folder.dart';
import 'arca_layout.dart';
import 'folder_fs.dart';

/// Progreso de una migración o copia.
typedef MigrationProgress = void Function(int done, int total);

class MigrationResult {
  MigrationResult();
  int copied = 0;

  /// Ya estaban en el destino con el mismo contenido.
  int skipped = 0;
  final List<String> failures = [];

  /// Archivos sueltos o desconocidos que se quedan en el origen.
  int leftBehind = 0;
  bool get ok => failures.isEmpty;
  int get total => copied + skipped;
}

/// Mueve el Arca entre almacenes, verificando cada copia por su SHA-256 antes
/// de dar nada por terminado.
abstract final class ArcaMigration {
  /// Copia el Arca interna de versiones anteriores (SQLite + blobs por hash)
  /// a [dest]. No toca el origen: quien llama decide qué hacer con él cuando
  /// [MigrationResult.ok].
  static Future<MigrationResult> fromLegacy({
    required ArcaDatabase legacyDb,
    required BlobStore blobs,
    required ArcaFolder dest,
    String? deviceId,
    String? deviceName,
    MigrationProgress? onProgress,
  }) async {
    final result = MigrationResult();
    final slots = {for (final s in await legacyDb.select(legacyDb.saveSlots).get()) s.id: s};
    final snaps = await (legacyDb.select(legacyDb.snapshots)
          ..orderBy([(s) => OrderingTerm.asc(s.importedAt), (s) => OrderingTerm.asc(s.id)]))
        .get();
    await dest.ensureReadme();
    var done = 0;
    onProgress?.call(0, snaps.length);
    for (final s in snaps) {
      final slot = slots[s.slotId];
      try {
        if (slot == null) throw StateError('partida ${s.slotId} inexistente');
        final Uint8List bytes;
        try {
          bytes = await blobs.read(s.sha256);
        } catch (e) {
          throw StateError('no se encontró el contenido ($e)');
        }
        if (ArcaFolder.sha256Of(bytes) != s.sha256) throw StateError('el contenido no coincide con su SHA-256');
        final meta = legacyMeta(slot, s, deviceId: deviceId, deviceName: deviceName, size: bytes.length);
        final rel = await dest.writeSnapshot(bytes, meta);
        await _verify(dest, rel, s.sha256);
        result.copied++;
      } catch (e) {
        result.failures.add('${s.fileName} (${s.importedAt.toIso8601String()}): $e');
      }
      onProgress?.call(++done, snaps.length);
    }
    return result;
  }

  /// Metadatos de un snapshot de la base antigua.
  static SnapshotMeta legacyMeta(SaveSlot slot, Snapshot s, {String? deviceId, String? deviceName, int? size}) =>
      SnapshotMeta(
        sha256: s.sha256,
        sizeBytes: size ?? s.sizeBytes,
        importedAt: s.importedAt,
        originalFileName: s.fileName,
        origin: s.origin,
        sourcePath: s.sourcePath,
        note: s.note,
        deviceId: deviceId,
        deviceName: s.deviceName ?? deviceName,
        gameCode: s.gameCode,
        generation: slot.generation,
        versionId: s.versionId,
        format: s.formatInfo,
        checksum: s.checksum,
        trainerName: s.trainerName,
        tid: slot.tid,
        sid: slot.sid,
        displayTid: slot.displayTid,
        displaySid: slot.displaySid,
        playTimeSeconds: s.playTimeSeconds,
        partySummary: s.partySummary,
        boxedCount: s.boxedCount,
        slot: SlotMeta(
          identityKey: slot.identityKey,
          gameCode: slot.gameCode,
          generation: slot.generation,
          versionId: slot.versionId,
          trainerName: slot.trainerName,
          tid: slot.tid,
          sid: slot.sid,
          displayTid: slot.displayTid,
          displaySid: slot.displaySid,
        ),
      );

  /// Copia todas las copias gestionadas de [from] a [to] y, si [move], borra
  /// del origen solo las que se verificaron en el destino. Las copias dañadas
  /// del origen se informan y nunca se borran.
  static Future<MigrationResult> copyFolder({
    required ArcaFolder from,
    required ArcaFolder to,
    bool move = false,
    MigrationProgress? onProgress,
  }) async {
    final result = MigrationResult();
    final listing = await from.listing();
    final pairs = listing.pairs.keys.toList()..sort();
    await to.ensureReadme();
    final verified = <String>[];
    final movedShas = <String>{};
    // Archivos principales (derivados) de las copias del origen.
    final mains = <String>{};
    var done = 0;
    onProgress?.call(0, pairs.length);
    for (final rel in pairs) {
      try {
        final meta = await from.readMeta(rel);
        mains.add(ArcaLayout.mainPath(ArcaLayout.ownerDirOf(rel), ArcaLayout.mainFileName(meta.gameCode, meta.originalFileName)));
        final bytes = await from.readVerified(rel, meta.sha256);
        final existed = await to.exists(rel) && await to.exists(ArcaLayout.sidecarFor(rel));
        // writeSnapshot reutiliza un archivo idéntico y nunca pisa uno distinto.
        final destRel = await to.writeSnapshot(bytes, meta);
        await _verify(to, destRel, meta.sha256);
        existed ? result.skipped++ : result.copied++;
        verified.add(rel);
        movedShas.add(meta.sha256);
      } catch (e) {
        result.failures.add('$rel: $e');
      }
      onProgress?.call(++done, pairs.length);
    }
    result.leftBehind =
        listing.loose.where((e) => !mains.contains(e.path)).length + listing.missingSidecar.length + listing.missingSave.length;
    if (move) {
      for (final rel in verified) {
        await from.delete(ArcaLayout.sidecarFor(rel));
        await from.delete(rel);
      }
      // Los principales derivados de lo movido se retiran también (el destino
      // los regenera); uno cambiado a mano se queda.
      final remaining = {for (final r in pairs) if (!verified.contains(r)) ArcaLayout.ownerDirOf(r)};
      for (final path in mains) {
        final dir = ArcaLayout.ownerDirOf(path);
        if (remaining.contains(dir)) continue;
        try {
          if (await from.exists(path) && movedShas.contains(ArcaFolder.sha256Of(await from.read(path)))) await from.delete(path);
          await from.delete(ArcaLayout.latestPath(dir));
        } catch (_) {}
      }
    }
    return result;
  }

  /// `true` si la carpeta tiene copias del diseño anterior (sueltas en la
  /// carpeta del entrenador en vez de en `historial/`).
  static bool needsHistoryLayout(FolderListing listing) =>
      listing.pairs.keys.any((p) => !ArcaLayout.inHistory(p)) ||
      listing.missingSidecar.any((e) => !ArcaLayout.inHistory(e.path));

  /// Mueve las copias del diseño anterior a `<Entrenador>/historial/`.
  ///
  /// Para cada copia: comprueba su SHA-256, la escribe en `historial/` (sin
  /// sobrescribir nunca), relee y verifica save y `.json`, avisa con
  /// [onMoved] y solo entonces borra el original (primero el `.json`).
  /// Es idempotente: si se corta a mitad, la siguiente ejecución reconoce lo
  /// ya copiado por su hash y termina el trabajo sin duplicar ni perder nada.
  static Future<MigrationResult> toHistoryLayout(
    ArcaFolder folder,
    FolderListing listing, {
    Future<void> Function(String from, String to)? onMoved,
    MigrationProgress? onProgress,
  }) async {
    final result = MigrationResult();
    final legacy = listing.pairs.keys.where((p) => !ArcaLayout.inHistory(p)).toList()..sort();
    final orphans = listing.missingSidecar.where((e) => !ArcaLayout.inHistory(e.path)).toList();
    final total = legacy.length + orphans.length;
    var done = 0;
    onProgress?.call(0, total);
    for (final rel in legacy) {
      final dest = ArcaLayout.historyPathFor(rel);
      try {
        final meta = await folder.readMeta(rel);
        final bytes = await folder.readVerified(rel, meta.sha256);
        var existed = false;
        try {
          await folder.writeNew(dest, bytes);
        } on FsExistsException {
          if (ArcaFolder.sha256Of(await folder.read(dest)) != meta.sha256) {
            throw StateError('$dest ya existe con otro contenido');
          }
          existed = true;
        }
        await folder.readVerified(dest, meta.sha256);
        final side = ArcaLayout.sidecarFor(dest);
        try {
          await folder.writeNew(side, await folder.read(ArcaLayout.sidecarFor(rel)));
        } on FsExistsException {
          // Ya copiado en una ejecución anterior: se valida abajo.
        }
        if ((await folder.readMeta(dest)).sha256 != meta.sha256) {
          throw StateError('el .json de $dest no corresponde a la copia');
        }
        await onMoved?.call(rel, dest);
        await folder.delete(ArcaLayout.sidecarFor(rel));
        await folder.delete(rel);
        existed ? result.skipped++ : result.copied++;
      } catch (e) {
        result.failures.add('$rel: $e');
      }
      onProgress?.call(++done, total);
    }
    // Saves antiguos sin .json: si una ejecución anterior se cortó tras borrar
    // el .json, su copia verificada ya está en historial/ y se retiran.
    for (final e in orphans) {
      final dest = ArcaLayout.historyPathFor(e.path);
      try {
        if (await folder.exists(dest) && await folder.exists(ArcaLayout.sidecarFor(dest))) {
          final meta = await folder.readMeta(dest);
          final bytes = await folder.read(e.path);
          if (ArcaFolder.sha256Of(bytes) == meta.sha256) {
            await folder.readVerified(dest, meta.sha256);
            await onMoved?.call(e.path, dest);
            await folder.delete(e.path);
            result.skipped++;
          }
        }
      } catch (err) {
        result.failures.add('${e.path}: $err');
      }
      onProgress?.call(++done, total);
    }
    return result;
  }

  static Future<void> _verify(ArcaFolder dest, String rel, String sha) async {
    await dest.readVerified(rel, sha);
    final meta = await dest.readMeta(rel);
    if (meta.sha256 != sha) throw StateError('el .json escrito no corresponde a la copia');
  }
}
