import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:pkcore/pkcore.dart' hide Platform;

import 'arca_repository.dart';

/// Un archivo elegido por el usuario, listo para importar.
class PickedSave {
  const PickedSave({required this.name, required this.bytes, required this.origin, this.sourcePath});
  final String name;
  final Uint8List bytes;
  final ImportOrigin origin;

  /// Ruta del sistema de archivos o URI `content://` (SAF).
  final String? sourcePath;
}

/// Un save encontrado al escanear una carpeta.
class FolderCandidate {
  const FolderCandidate({required this.file, required this.relativePath, required this.game, required this.trainer});
  final PickedSave file;
  final String relativePath;
  final GameVersion game;
  final String trainer;
}

class FolderScan {
  const FolderScan(
      {required this.rootLabel, required this.found, required this.scanned, required this.ignored, this.unrecognized = const []});
  final String rootLabel;
  final List<FolderCandidate> found;
  final int scanned;
  final int ignored;

  /// Archivos con tamaño de save que no se pudieron identificar (ruta relativa).
  final List<String> unrecognized;
}

/// Acceso a archivos: selector nativo, escaneo de carpetas (dart:io o SAF en
/// Android) y escritura para exportar/restaurar.
///
/// Solo se leen archivos de save del usuario; las extensiones de ROMs, claves
/// y paquetes de juego se descartan sin abrirlas.
class FileSources {
  const FileSources();

  static const _saf = MethodChannel('dev.pkarktools/saf');

  static const _blockedExtensions = {
    '.nsp', '.xci', '.nca', '.nsz', '.xcz', '.keys', '.prod', '.title', '.nro', '.nso', // Switch
    '.gb', '.gbc', '.gba', '.nds', '.3ds', '.cia', '.cxi', '.cci', '.app', '.zip', '.7z', '.rar', // ROMs
    '.png', '.jpg', '.jpeg', '.webp', '.mp4', '.txt', '.json', '.xml', '.ini', '.log', '.db', '.dll', '.so',
  };

  static bool get _useSaf => !kIsWeb && Platform.isAndroid;

  static bool isBlocked(String name) => _blockedExtensions.contains(p.extension(name).toLowerCase());

  Future<List<PickedSave>> pickFiles() async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Importar saves');
    final out = <PickedSave>[];
    for (final f in files) {
      final bytes = await f.readAsBytes();
      out.add(PickedSave(
        name: f.name,
        bytes: bytes,
        origin: ImportOrigin.file,
        sourcePath: f.path ?? (f.uri.scheme == 'content' ? f.uri.toString() : null),
      ));
    }
    return out;
  }

  /// Pide una carpeta y busca saves dentro (recursivo, con límites).
  Future<FolderScan?> pickAndScanFolder({void Function(int scanned)? onProgress}) async {
    if (_useSaf) return _scanSaf(onProgress);
    final dir = await FilePicker.pickDirectory(dialogTitle: 'Carpeta de saves');
    if (dir == null || dir.scheme != 'file') return null;
    return scanDirectory(Directory(dir.toFilePath()), onProgress: onProgress);
  }

  /// Escanea una carpeta del sistema de archivos (escritorio/iOS).
  Future<FolderScan> scanDirectory(Directory root, {void Function(int scanned)? onProgress}) async {
    final found = <FolderCandidate>[];
    final unrecognized = <String>[];
    var scanned = 0, ignored = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (scanned >= 3000) break;
      final rel = p.relative(entity.path, from: root.path);
      if (rel.split(p.separator).length > 12 || isBlocked(entity.path)) {
        ignored++;
        continue;
      }
      final len = await entity.length();
      if (!SaveDetector.isPlausibleSize(len)) {
        ignored++;
        continue;
      }
      scanned++;
      onProgress?.call(scanned);
      final bytes = await entity.readAsBytes();
      final c = await _detect(PickedSave(
        name: p.basename(entity.path),
        bytes: bytes,
        origin: ImportOrigin.folder,
        sourcePath: entity.path,
      ), rel);
      if (c != null) {
        found.add(c);
      } else {
        unrecognized.add(rel);
      }
    }
    return FolderScan(rootLabel: root.path, found: found, scanned: scanned, ignored: ignored, unrecognized: unrecognized);
  }

  Future<FolderScan?> _scanSaf(void Function(int scanned)? onProgress) async {
    final tree = await _saf.invokeMethod<String>('pickTree');
    if (tree == null) return null;
    final entries = await _saf.invokeListMethod<Map<Object?, Object?>>('listFiles', {'uri': tree, 'maxDepth': 12});
    final found = <FolderCandidate>[];
    final unrecognized = <String>[];
    var scanned = 0, ignored = 0;
    for (final e in entries ?? const <Map<Object?, Object?>>[]) {
      final name = e['name'] as String? ?? '';
      final size = (e['size'] as num?)?.toInt() ?? 0;
      final uri = e['uri'] as String;
      final rel = e['path'] as String? ?? name;
      if (isBlocked(name) || !SaveDetector.isPlausibleSize(size)) {
        ignored++;
        continue;
      }
      scanned++;
      onProgress?.call(scanned);
      final bytes = await _saf.invokeMethod<Uint8List>('readFile', {'uri': uri});
      if (bytes == null) continue;
      final c = await _detect(PickedSave(name: name, bytes: bytes, origin: ImportOrigin.saf, sourcePath: uri), rel);
      if (c != null) {
        found.add(c);
      } else {
        unrecognized.add(rel);
      }
    }
    return FolderScan(
        rootLabel: Uri.decodeComponent(tree.split('/').last),
        found: found,
        scanned: scanned,
        ignored: ignored,
        unrecognized: unrecognized);
  }

  /// Clasifica archivos sueltos como si fueran una carpeta (importación múltiple).
  Future<FolderScan> scanPicked(List<PickedSave> files) async {
    final found = <FolderCandidate>[];
    final unrecognized = <String>[];
    for (final f in files) {
      final c = await _detect(f, f.name);
      if (c != null) {
        found.add(c);
      } else {
        unrecognized.add(f.name);
      }
    }
    return FolderScan(rootLabel: '', found: found, scanned: files.length, ignored: 0, unrecognized: unrecognized);
  }

  /// Elige un zip exportado del Arca.
  Future<Uint8List?> pickZip() async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Restaurar Arca', type: FileType.custom, allowedExtensions: const ['zip']);
    if (files.isEmpty) return null;
    return files.first.readAsBytes();
  }

  Future<FolderCandidate?> _detect(PickedSave f, String rel) async {
    final bytes = f.bytes;
    final r = await Isolate.run(() {
      try {
        final s = SaveDetector.read(bytes);
        return (s.game, s.trainer.name);
      } catch (_) {
        return null;
      }
    });
    if (r == null) return null;
    return FolderCandidate(file: f, relativePath: rel, game: r.$1, trainer: r.$2);
  }

  /// Exporta [bytes] con el diálogo "Guardar como". Devuelve la ruta o null.
  Future<String?> exportBytes(String suggestedName, Uint8List bytes) async {
    final uri = await FilePicker.saveFile(dialogTitle: 'Exportar save', fileName: suggestedName, bytes: bytes);
    if (uri == null) return null;
    if (uri.scheme == 'file') {
      final f = File(uri.toFilePath());
      if (!await f.exists() || await f.length() != bytes.length) {
        await f.writeAsBytes(bytes, flush: true);
      }
      return f.path;
    }
    return Uri.decodeComponent(uri.pathSegments.isEmpty ? uri.toString() : uri.pathSegments.last);
  }

  /// `true` si se puede reescribir el archivo original de un snapshot.
  bool canRestoreInPlace(String? sourcePath) {
    if (sourcePath == null || kIsWeb) return false;
    if (sourcePath.startsWith('content://')) return _useSaf;
    if (Platform.isIOS || Platform.isAndroid) return false;
    return File(sourcePath).existsSync();
  }

  Future<Uint8List?> readSource(String sourcePath) async {
    if (sourcePath.startsWith('content://')) {
      return _saf.invokeMethod<Uint8List>('readFile', {'uri': sourcePath});
    }
    final f = File(sourcePath);
    return await f.exists() ? f.readAsBytes() : null;
  }

  Future<void> writeSource(String sourcePath, Uint8List bytes) async {
    if (sourcePath.startsWith('content://')) {
      await _saf.invokeMethod<void>('writeFile', {'uri': sourcePath, 'bytes': bytes});
      return;
    }
    await File(sourcePath).writeAsBytes(bytes, flush: true);
  }
}
