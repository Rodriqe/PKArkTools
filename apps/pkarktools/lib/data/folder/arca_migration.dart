import 'package:drift/drift.dart';

import '../blob_store.dart';
import '../db/arca_database.dart';
import 'arca_folder.dart';
import 'arca_layout.dart';

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
    result.leftBehind = listing.loose.length + listing.missingSidecar.length + listing.missingSave.length;
    final pairs = listing.pairs.keys.toList()..sort();
    await to.ensureReadme();
    final verified = <String>[];
    var done = 0;
    onProgress?.call(0, pairs.length);
    for (final rel in pairs) {
      try {
        final meta = await from.readMeta(rel);
        final bytes = await from.readVerified(rel, meta.sha256);
        final existed = await to.exists(rel) && await to.exists(ArcaLayout.sidecarFor(rel));
        // writeSnapshot reutiliza un archivo idéntico y nunca pisa uno distinto.
        final destRel = await to.writeSnapshot(bytes, meta);
        await _verify(to, destRel, meta.sha256);
        existed ? result.skipped++ : result.copied++;
        verified.add(rel);
      } catch (e) {
        result.failures.add('$rel: $e');
      }
      onProgress?.call(++done, pairs.length);
    }
    if (move) {
      for (final rel in verified) {
        await from.delete(ArcaLayout.sidecarFor(rel));
        await from.delete(rel);
      }
    }
    return result;
  }

  static Future<void> _verify(ArcaFolder dest, String rel, String sha) async {
    await dest.readVerified(rel, sha);
    final meta = await dest.readMeta(rel);
    if (meta.sha256 != sha) throw StateError('el .json escrito no corresponde a la copia');
  }
}
