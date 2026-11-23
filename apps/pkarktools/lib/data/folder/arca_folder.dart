import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pkcore/pkcore.dart' show SaveDetector;

import 'arca_layout.dart';
import 'folder_fs.dart';

/// Un save gestionado con su sidecar.
class ScannedSnapshot {
  const ScannedSnapshot(this.path, this.size);

  /// Ruta del save, relativa a la raíz del Arca.
  final String path;
  final int size;
}

/// Tipos de problema que el reindexado marca y deja pasar.
enum ArcaIssueKind { missingSave, missingSidecar, corruptSidecar, sizeMismatch, hashMismatch, unreadable }

class ArcaIssue {
  const ArcaIssue(this.kind, this.path, [this.detail]);
  final ArcaIssueKind kind;
  final String path;
  final String? detail;

  @override
  String toString() => '$kind $path${detail == null ? '' : ' ($detail)'}';
}

/// Resultado de listar la carpeta (sin leer el contenido de los saves).
class FolderListing {
  FolderListing();

  /// Pares save + sidecar: ruta del save → ruta del sidecar.
  final Map<String, String> pairs = {};
  final Map<String, FsEntry> files = {};

  /// Saves con nombre del Arca cuyo `.json` no está (aún).
  final List<FsEntry> missingSidecar = [];

  /// `.json` cuyo save no está (aún).
  final List<String> missingSave = [];

  /// Archivos sueltos con tamaño de save (candidatos a "adoptar").
  final List<FsEntry> loose = [];
  final Map<IgnoreReason, int> ignored = {};

  /// Marcadores `.icloud` (archivos aún no descargados): ruta absoluta si la hay.
  final List<String> placeholders = [];
}

/// La carpeta del Arca: layout + acceso a archivos.
class ArcaFolder {
  ArcaFolder(this.fs, {this.prefix = ArcaLayout.rootDir});

  final FolderFs fs;

  /// Subcarpeta donde vive el Arca dentro de la carpeta elegida
  /// (`PKArkTools`, o '' si el usuario eligió directamente esa carpeta).
  final String prefix;

  String get label => fs.label;

  String _full(String rel) => prefix.isEmpty ? rel : '$prefix/$rel';

  /// Abre una carpeta elegida: si es ya la carpeta `PKArkTools` de otro
  /// dispositivo (tiene nuestro README en la raíz) se usa tal cual.
  static Future<ArcaFolder> open(FolderFs fs) async {
    if (await fs.exists(ArcaLayout.readmeName) && !await fs.exists('${ArcaLayout.rootDir}/${ArcaLayout.readmeName}')) {
      try {
        final text = utf8.decode(await fs.read(ArcaLayout.readmeName), allowMalformed: true);
        if (text.startsWith(ArcaLayout.readmeMarker)) return ArcaFolder(fs, prefix: '');
      } catch (_) {}
    }
    return ArcaFolder(fs);
  }

  static String sha256Of(Uint8List bytes) => crypto.sha256.convert(bytes).toString();

  /// Escribe el README si falta (nunca lo sobrescribe).
  Future<void> ensureReadme() async {
    final path = _full(ArcaLayout.readmeName);
    if (await fs.exists(path)) return;
    try {
      await fs.writeNew(path, Uint8List.fromList(utf8.encode(ArcaLayout.readme())));
    } on FsExistsException {
      // Otro dispositivo lo escribió a la vez.
    }
  }

  Future<Uint8List> read(String rel) => fs.read(_full(rel));

  Future<bool> exists(String rel) => fs.exists(_full(rel));

  Future<void> delete(String rel) => fs.delete(_full(rel));

  /// Escribe save + sidecar de un snapshot nuevo y devuelve la ruta del save.
  ///
  /// Nunca sobrescribe: si el nombre está ocupado por otro contenido, prueba
  /// con un sufijo. Si ya existe un archivo con el mismo contenido en esa
  /// ruta, se reutiliza. El save se escribe antes que el sidecar: otro
  /// dispositivo que vea solo el save lo marca como "falta el .json" y lo
  /// recoge en el siguiente reindexado.
  Future<String> writeSnapshot(Uint8List bytes, SnapshotMeta meta) async {
    await ensureReadme();
    for (var attempt = 0; attempt < 50; attempt++) {
      final rel = ArcaLayout.savePath(
        gameCode: meta.slot.gameCode,
        trainerName: meta.slot.trainerName,
        displayTid: meta.slot.displayTid,
        importedAt: meta.importedAt,
        sha256: meta.sha256,
        originalName: meta.originalFileName,
        attempt: attempt,
      );
      try {
        await fs.writeNew(_full(rel), bytes);
      } on FsExistsException {
        final existing = await fs.read(_full(rel));
        if (sha256Of(existing) != meta.sha256) continue;
      }
      final side = ArcaLayout.sidecarFor(rel);
      try {
        await fs.writeNew(_full(side), Uint8List.fromList(utf8.encode(meta.encode())));
      } on FsExistsException {
        // Sidecar ya presente (mismo save): se conserva el existente.
      }
      return rel;
    }
    throw StateError('No se encontró un nombre libre para ${meta.originalFileName}');
  }

  /// Reescribe el sidecar de un snapshot (p. ej. al fijar la versión a mano).
  Future<void> rewriteMeta(String saveRel, SnapshotMeta meta) async {
    final side = _full(ArcaLayout.sidecarFor(saveRel));
    if (await fs.exists(side)) await fs.delete(side);
    await fs.writeNew(side, Uint8List.fromList(utf8.encode(meta.encode())));
  }

  Future<SnapshotMeta> readMeta(String saveRel) async =>
      SnapshotMeta.decode(utf8.decode(await fs.read(_full(ArcaLayout.sidecarFor(saveRel)))));

  /// Lee el save y comprueba su SHA-256.
  Future<Uint8List> readVerified(String saveRel, String sha256) async {
    final bytes = await read(saveRel);
    if (sha256Of(bytes) != sha256) {
      throw ArcaFileCorruptException(saveRel, 'el contenido no coincide con su SHA-256');
    }
    return bytes;
  }

  /// Lista y clasifica los archivos de la carpeta (sin leer su contenido).
  Future<FolderListing> listing() async {
    final out = FolderListing();
    final entries = await fs.list(prefix);
    final byPath = <String, FsEntry>{};
    for (final e in entries) {
      final rel = prefix.isEmpty ? e.path : e.path.substring(prefix.length + 1);
      byPath[rel] = FsEntry(rel, e.size, e.modified);
    }
    final sidecars = <String>{};
    final saves = <String, FsEntry>{};
    for (final e in byPath.values) {
      final rel = e.path;
      if (rel == ArcaLayout.readmeName) continue;
      final reason = ArcaLayout.ignoreReason(rel);
      if (reason != null) {
        out.ignored.update(reason, (v) => v + 1, ifAbsent: () => 1);
        if (reason == IgnoreReason.cloudPlaceholder) out.placeholders.add(rel);
        continue;
      }
      final name = rel.split('/').last;
      if (ArcaLayout.managedSidecar.hasMatch(name)) {
        sidecars.add(rel);
      } else if (ArcaLayout.managedSave.hasMatch(name)) {
        saves[rel] = e;
      } else if (SaveDetector.isPlausibleSize(e.size) && !rel.toLowerCase().endsWith('.json')) {
        out.loose.add(e);
      } else {
        out.ignored.update(IgnoreReason.hidden, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    for (final side in sidecars) {
      final save = side.substring(0, side.length - ArcaLayout.sidecarExt.length);
      if (saves.containsKey(save)) {
        out.pairs[save] = side;
        out.files[save] = saves[save]!;
      } else {
        out.missingSave.add(side);
      }
    }
    for (final e in saves.values) {
      if (!out.pairs.containsKey(e.path)) out.missingSidecar.add(e);
    }
    out.loose.sort((a, b) => a.path.compareTo(b.path));
    return out;
  }
}

class ArcaFileCorruptException implements Exception {
  const ArcaFileCorruptException(this.path, this.reason);
  final String path;
  final String reason;
  @override
  String toString() => 'Copia dañada en el Arca ($path): $reason';
}
