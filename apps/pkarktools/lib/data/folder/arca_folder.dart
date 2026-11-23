import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pkcore/pkcore.dart' show SaveDetector;

import 'arca_game_folders.dart';
import 'arca_layout.dart';
import 'folder_fs.dart';
import 'unicode_names.dart';

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

  /// `ultima.json` de cada carpeta de entrenador.
  final List<String> latestIndexes = [];

  /// Copias de conflicto de la nube (se ignoran, pero el reindexado retira
  /// las del archivo principal cuyo contenido ya está en el historial).
  final List<FsEntry> conflicts = [];

  /// Todos los archivos listados (ruta relativa → entrada), para saber el
  /// tamaño y la fecha de cualquier archivo con problema.
  final Map<String, FsEntry> entries = {};
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

  /// Abre una carpeta elegida:
  ///
  /// * si contiene una `PKArkTools/` (p. ej. la carpeta compartida del NAS
  ///   donde otro dispositivo ya creó el Arca) se usa esa, sin crear otra;
  /// * si es ya la carpeta `PKArkTools` de otro dispositivo (tiene nuestro
  ///   README en la raíz, o se llama así y no contiene otra `PKArkTools/`)
  ///   se usa tal cual: nunca se anida `PKArkTools/PKArkTools`.
  static Future<ArcaFolder> open(FolderFs fs) async {
    if (await fs.exists('${ArcaLayout.rootDir}/${ArcaLayout.readmeName}')) return ArcaFolder(fs);
    if (await fs.exists(ArcaLayout.readmeName)) {
      try {
        final text = utf8.decode(await fs.read(ArcaLayout.readmeName), allowMalformed: true);
        if (text.startsWith(ArcaLayout.readmeMarker)) return ArcaFolder(fs, prefix: '');
      } catch (_) {}
    }
    final name = fs.label.split(RegExp(r'[/\\:]')).where((s) => s.isNotEmpty).lastOrNull ?? '';
    if (name.toLowerCase() == ArcaLayout.rootDir.toLowerCase()) {
      try {
        if ((await fs.list(ArcaLayout.rootDir)).isEmpty) return ArcaFolder(fs, prefix: '');
      } on FolderAccessLostException {
        rethrow;
      } catch (_) {}
    }
    return ArcaFolder(fs);
  }

  /// Carpetas vistas en el último listado: nombre en minúsculas → nombre real.
  /// En un NAS (SMB) o en macOS el sistema de archivos no distingue
  /// mayúsculas: una copia nueva se escribe en la carpeta existente con su
  /// grafía real para que la ruta del índice coincida con la del listado.
  final Map<String, String> _dirCase = {};

  void _learnDirs(String rel) {
    final segs = rel.split('/');
    for (var i = 1; i < segs.length; i++) {
      final d = segs.take(i).join('/');
      _dirCase.putIfAbsent(d.toLowerCase(), () => d);
    }
  }

  /// [rel] con las carpetas existentes en su grafía real.
  String canonicalCase(String rel) {
    if (_dirCase.isEmpty) return rel;
    final segs = rel.split('/');
    for (var i = segs.length - 1; i > 0; i--) {
      final known = _dirCase[segs.take(i).join('/').toLowerCase()];
      if (known != null) return [known, ...segs.skip(i)].join('/');
    }
    return rel;
  }

  static String sha256Of(Uint8List bytes) => crypto.sha256.convert(bytes).toString();

  /// Escribe el README si falta, o lo actualiza si es nuestro y de una
  /// versión anterior de la estructura (un README ajeno nunca se toca).
  Future<void> ensureReadme() async {
    final path = _full(ArcaLayout.readmeName);
    if (await fs.exists(path)) {
      try {
        final text = utf8.decode(await fs.read(path), allowMalformed: true);
        if (text.startsWith(ArcaLayout.readmeMarker) && !text.contains(ArcaLayout.readmeRevision)) {
          await fs.writeReplace(path, Uint8List.fromList(utf8.encode(ArcaLayout.readme())));
        }
      } catch (_) {
        // README ilegible o a medio sincronizar: se reintenta en otro momento.
      }
      return;
    }
    try {
      await fs.writeNew(path, Uint8List.fromList(utf8.encode(ArcaLayout.readme())));
    } on FsExistsException {
      // Otro dispositivo lo escribió a la vez.
    }
  }

  Future<Uint8List> read(String rel) => fs.read(_full(rel));

  Future<bool> exists(String rel) => fs.exists(_full(rel));

  Future<void> delete(String rel) => fs.delete(_full(rel));

  /// Escribe un archivo nuevo (nunca sobrescribe).
  Future<void> writeNew(String rel, Uint8List bytes) => fs.writeNew(_full(rel), bytes);

  /// Escribe o reemplaza de forma atómica un archivo derivado.
  Future<void> writeReplace(String rel, Uint8List bytes) => fs.writeReplace(_full(rel), bytes);

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
      final rel = canonicalCase(ArcaLayout.savePath(
        gameCode: meta.slot.gameCode,
        trainerName: meta.slot.trainerName,
        displayTid: meta.slot.displayTid,
        importedAt: meta.importedAt,
        sha256: meta.sha256,
        originalName: meta.originalFileName,
        attempt: attempt,
      ));
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
      _learnDirs(rel);
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
  Future<FolderListing> listing({String sub = ''}) async {
    final out = FolderListing();
    final entries = await fs.list(sub.isEmpty ? prefix : _full(sub));
    final byPath = <String, FsEntry>{};
    for (final e in entries) {
      // Nombres en NFC: macOS (smbfs, AFP) los devuelve descompuestos.
      final path = toNfc(e.path);
      final rel = prefix.isEmpty ? path : path.substring(prefix.length + 1);
      byPath[rel] = FsEntry(rel, e.size, e.modified);
      _learnDirs(rel);
    }
    out.entries.addAll(byPath);
    final sidecars = <String>{};
    final saves = <String, FsEntry>{};
    for (final e in byPath.values) {
      final rel = e.path;
      if (rel == ArcaLayout.readmeName) continue;
      final name = rel.split('/').last;
      if (name == ArcaLayout.latestName) {
        out.latestIndexes.add(rel);
        continue;
      }
      if (ArcaGameFolders.isGameReadme(rel)) continue;
      final reason = ArcaLayout.ignoreReason(rel);
      // Lo apartado por «Arreglar» no cuenta para nada.
      if (reason == IgnoreReason.quarantined) continue;
      if (reason != null) {
        out.ignored.update(reason, (v) => v + 1, ifAbsent: () => 1);
        if (reason == IgnoreReason.cloudPlaceholder) out.placeholders.add(rel);
        if (reason == IgnoreReason.conflictCopy) out.conflicts.add(e);
        continue;
      }
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
