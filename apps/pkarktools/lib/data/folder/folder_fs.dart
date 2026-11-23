import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Un archivo dentro de la carpeta del Arca.
class FsEntry {
  const FsEntry(this.path, this.size, this.modified);

  /// Ruta relativa a la raíz, siempre con `/`.
  final String path;
  final int size;
  final DateTime? modified;

  @override
  String toString() => 'FsEntry($path, $size)';
}

/// El archivo de destino ya existe: los archivos del Arca nunca se sobrescriben.
class FsExistsException implements Exception {
  const FsExistsException(this.path);
  final String path;
  @override
  String toString() => 'Ya existe $path';
}

/// Se perdió el permiso sobre la carpeta (bookmark caducado, SAF revocado,
/// unidad desconectada…).
class FolderAccessLostException implements Exception {
  const FolderAccessLostException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Acceso mínimo a una carpeta elegida por el usuario.
///
/// Todas las rutas son relativas a la raíz y usan `/`. Hay una implementación
/// con `dart:io` (escritorio, iOS/macOS tras resolver el bookmark, carpeta
/// local) y otra con el Storage Access Framework de Android.
abstract class FolderFs {
  /// Texto para mostrar al usuario (ruta o nombre de la carpeta).
  String get label;

  /// Ruta del sistema de archivos si la hay (para el watcher en escritorio).
  String? get nativePath => null;

  /// Lista recursiva de archivos bajo [dir] ('' = raíz). No sigue enlaces.
  Future<List<FsEntry>> list(String dir);

  Future<Uint8List> read(String path);

  Future<bool> exists(String path);

  /// Escribe un archivo nuevo de forma atómica (temporal + rename). Lanza
  /// [FsExistsException] si ya existe: nunca sobrescribe.
  Future<void> writeNew(String path, Uint8List bytes);

  /// Escribe (o reemplaza) un archivo de forma atómica: temporal + rename.
  /// Solo para archivos derivados (el archivo principal, `ultima.json`, el
  /// README), nunca para el historial.
  Future<void> writeReplace(String path, Uint8List bytes);

  Future<void> delete(String path);

  /// Comprueba que la carpeta sigue accesible y se puede escribir.
  Future<bool> checkAccess();
}

/// [FolderFs] sobre `dart:io`.
class IoFolderFs implements FolderFs {
  IoFolderFs(this.root, {String? label}) : _label = label;

  final Directory root;
  final String? _label;
  static final _rand = Random();

  @override
  String get label => _label ?? root.path;

  @override
  String? get nativePath => root.path;

  String _abs(String rel) => p.joinAll([root.path, ...rel.split('/').where((s) => s.isNotEmpty)]);

  @override
  Future<List<FsEntry>> list(String dir) async {
    final base = Directory(_abs(dir));
    if (!await base.exists()) return const [];
    final out = <FsEntry>[];
    try {
      await for (final e in base.list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        try {
          final st = await e.stat();
          out.add(FsEntry(p.relative(e.path, from: root.path).split(p.separator).join('/'), st.size, st.modified));
        } on FileSystemException {
          // Archivo que desaparece mientras se lista (sincronización en curso).
        }
      }
    } on FileSystemException catch (e) {
      if (!await root.exists()) throw FolderAccessLostException('La carpeta ${root.path} ya no existe: ${e.message}');
      rethrow;
    }
    return out;
  }

  @override
  Future<Uint8List> read(String path) => File(_abs(path)).readAsBytes();

  @override
  Future<bool> exists(String path) => File(_abs(path)).exists();

  @override
  Future<void> writeNew(String path, Uint8List bytes) async {
    final f = File(_abs(path));
    if (await f.exists()) throw FsExistsException(path);
    await f.parent.create(recursive: true);
    // El temporal empieza por '.' y termina en '.tmp': el reindexado lo ignora
    // aunque otro dispositivo lo vea a medio sincronizar.
    final tmp = File(p.join(f.parent.path, '.${p.basename(f.path)}.${_rand.nextInt(1 << 32).toRadixString(16)}.tmp'));
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      if (await f.exists()) throw FsExistsException(path);
      await tmp.rename(f.path);
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
  }

  @override
  Future<void> writeReplace(String path, Uint8List bytes) async {
    final f = File(_abs(path));
    await f.parent.create(recursive: true);
    final tmp = File(p.join(f.parent.path, '.${p.basename(f.path)}.${_rand.nextInt(1 << 32).toRadixString(16)}.tmp'));
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      // rename reemplaza el destino de forma atómica (POSIX y MoveFileEx).
      await tmp.rename(f.path);
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
  }

  @override
  Future<void> delete(String path) async {
    final f = File(_abs(path));
    if (await f.exists()) await f.delete();
  }

  @override
  Future<bool> checkAccess() async {
    try {
      if (!await root.exists()) return false;
      final probe = File(p.join(root.path, '.pkarktools-acceso-${_rand.nextInt(1 << 32).toRadixString(16)}.tmp'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}
