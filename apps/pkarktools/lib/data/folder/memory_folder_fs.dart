import 'dart:typed_data';

import 'folder_fs.dart';
import 'volume_info.dart';

/// [FolderFs] en memoria: para capturas y pruebas sin tocar el disco.
class MemoryFolderFs implements FolderFs {
  MemoryFolderFs({this.label = 'memoria'});

  @override
  final String label;

  @override
  String? get nativePath => null;

  /// Volumen simulado (p. ej. un NAS en pruebas y capturas).
  @override
  VolumeInfo? volume;

  final Map<String, (Uint8List, DateTime)> files = {};
  bool accessible = true;

  static String _norm(String p) => p.split('/').where((s) => s.isNotEmpty).join('/');

  void _check() {
    if (!accessible) throw const FolderAccessLostException('Carpeta no disponible');
  }

  @override
  Future<List<FsEntry>> list(String dir) async {
    _check();
    final prefix = _norm(dir);
    return [
      for (final MapEntry(key: path, value: (bytes, at)) in files.entries)
        if (prefix.isEmpty || path.startsWith('$prefix/')) FsEntry(path, bytes.length, at),
    ];
  }

  @override
  Future<Uint8List> read(String path) async {
    _check();
    final f = files[_norm(path)];
    if (f == null) throw StateError('No existe $path');
    return f.$1;
  }

  @override
  Future<bool> exists(String path) async => files.containsKey(_norm(path));

  @override
  Future<void> writeNew(String path, Uint8List bytes) async {
    _check();
    final key = _norm(path);
    if (files.containsKey(key)) throw FsExistsException(path);
    files[key] = (Uint8List.fromList(bytes), DateTime.now());
  }

  /// Escrituras de reemplazo hechas (para pruebas).
  int replaceCount = 0;

  @override
  Future<void> writeReplace(String path, Uint8List bytes) async {
    _check();
    replaceCount++;
    files[_norm(path)] = (Uint8List.fromList(bytes), DateTime.now());
  }

  @override
  Future<void> delete(String path) async => files.remove(_norm(path));

  @override
  Future<bool> checkAccess() async => accessible;
}
