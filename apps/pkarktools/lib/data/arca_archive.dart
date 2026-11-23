import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pkcore/pkcore.dart';

import 'arca_repository.dart';

/// Formato de la exportación en bloque del Arca.
///
/// ```
/// PKArkTools-Arca/
///   manifest.json
///   <juego>/<entrenador>-<id>/<fecha>_<sha8>_<archivo>
/// ```
/// El manifiesto guarda, por partida, cada snapshot con su ruta, SHA-256,
/// fecha, origen, nota y ruta de origen, para restaurarlo tal cual.
abstract final class ArcaArchive {
  static const root = 'PKArkTools-Arca';
  static const manifestName = '$root/manifest.json';
  static const format = 'pkarktools-arca';

  static const formatVersion = 1;

  static String _safe(String s) {
    final cleaned = s.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
    return cleaned.isEmpty ? '_' : cleaned;
  }

  static String _stamp(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}_${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }

  /// Crea el zip del Arca completa. Devuelve los bytes y el número de snapshots.
  static Future<(Uint8List, int)> export(ArcaRepository repo, {DateTime? now}) async {
    final archive = Archive();
    final slots = <Map<String, Object?>>[];
    var count = 0;
    for (final (slot, snaps) in await repo.allSlots()) {
      if (snaps.isEmpty) continue;
      final game = GameVersion.fromCode(slot.gameCode);
      final dir = '$root/${_safe(game?.nameEs ?? slot.gameCode)}/${_safe(slot.trainerName)}-${_safe(slot.displayTid)}';
      final entries = <Map<String, Object?>>[];
      for (final s in snaps) {
        final bytes = await repo.snapshotBytes(s);
        final path = '$dir/${_stamp(s.importedAt)}_${s.sha256.substring(0, 8)}_${_safe(s.fileName)}';
        archive.addFile(ArchiveFile(path, bytes.length, bytes));
        entries.add({
          'path': path,
          'sha256': s.sha256,
          'importedAt': s.importedAt.toUtc().toIso8601String(),
          'fileName': s.fileName,
          'origin': s.origin,
          'note': s.note,
          'sourcePath': s.sourcePath,
          'playTimeSeconds': s.playTimeSeconds,
        });
        count++;
      }
      slots.add({
        'identityKey': slot.identityKey,
        'game': slot.gameCode,
        'trainer': slot.trainerName,
        'tid': slot.displayTid,
        'snapshots': entries,
      });
    }
    final manifest = utf8.encode(const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': formatVersion,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'slots': slots,
    }));
    archive.addFile(ArchiveFile(manifestName, manifest.length, manifest));
    return (Uint8List.fromList(ZipEncoder().encode(archive)), count);
  }

  /// Restaura un zip exportado. Las partidas se agrupan como en el original y
  /// los snapshots que ya existen se cuentan como duplicados.
  static Future<List<ImportOutcome>> restore(ArcaRepository repo, Uint8List zip) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zip);
    } catch (_) {
      throw const FormatException('zip');
    }
    final mf = archive.findFile(manifestName);
    if (mf == null) throw const FormatException('manifest');
    final manifest = jsonDecode(utf8.decode(mf.content)) as Map<String, Object?>;
    if (manifest['format'] != format) throw const FormatException('manifest');
    final outcomes = <ImportOutcome>[];
    for (final slot in (manifest['slots'] as List).cast<Map<String, Object?>>()) {
      int? slotId;
      for (final e in (slot['snapshots'] as List).cast<Map<String, Object?>>()) {
        final path = e['path'] as String;
        final file = archive.findFile(path);
        final name = (e['fileName'] as String?) ?? path.split('/').last;
        if (file == null) {
          outcomes.add(ImportFailed(name, 'Falta $path en el zip.'));
          continue;
        }
        final bytes = Uint8List.fromList(file.content);
        final expected = e['sha256'] as String?;
        if (expected != null && ArcaRepository.sha256Of(bytes) != expected) {
          outcomes.add(ImportFailed(name, 'El contenido de $path no coincide con su SHA-256.'));
          continue;
        }
        final out = await repo.importBytes(
          bytes,
          fileName: name,
          origin: ImportOrigin.fromCode((e['origin'] as String?) ?? 'file'),
          sourcePath: e['sourcePath'] as String?,
          note: e['note'] as String?,
          now: DateTime.tryParse((e['importedAt'] as String?) ?? '')?.toLocal(),
          forceSlotId: slotId,
        );
        slotId ??= switch (out) {
          ImportAdded(:final slotId) => slotId,
          ImportDuplicate(:final slotId) => slotId,
          ImportFailed() => null,
        };
        outcomes.add(out);
      }
    }
    return outcomes;
  }
}
