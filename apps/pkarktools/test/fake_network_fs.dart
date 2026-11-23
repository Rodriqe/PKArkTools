import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/data/folder/resilient_folder_fs.dart';
import 'package:pkarktools/data/folder/unicode_names.dart';
import 'package:pkarktools/data/folder/volume_info.dart';

/// Una operación del NAS simulado: `list`, `read`, `exists`, `writeNew`,
/// `writeReplace`, `delete`.
typedef FailPlan = Object? Function(String op, String path, int call);

/// Error del sistema con un `errno` concreto, como los que da smbfs.
FileSystemException osError(int code, [String path = '']) =>
    FileSystemException('error $code', path, OSError('errno $code', code));

/// [FolderFs] que se comporta como un recurso SMB montado en macOS:
///
/// * no distingue mayúsculas y devuelve los nombres en NFD;
/// * crea un `._<nombre>` (AppleDouble) por cada archivo escrito;
/// * tiene latencia y puede fallar según [failPlan] o colgarse ([hang]);
/// * si se «desmonta» ([mounted] = false) falla como el `IoFolderFs` real.
class FakeNetworkFs implements FolderFs {
  FakeNetworkFs({
    this.latency = const Duration(milliseconds: 2),
    this.failPlan,
    this.appleDouble = true,
    this.label = '/Volumes/Compartido/Juegos',
  });

  @override
  final String label;
  final Duration latency;
  FailPlan? failPlan;
  final bool appleDouble;
  bool mounted = true;
  bool hang = false;

  /// clave NFC en minúsculas → (ruta tal como se creó, bytes, fecha).
  final Map<String, (String, Uint8List, DateTime)> files = {};
  final Map<String, int> calls = {};
  int writes = 0;

  @override
  String? get nativePath => null;

  @override
  VolumeInfo? get volume =>
      const VolumeInfo(fsType: 'smbfs', mountPoint: '/Volumes/Compartido', source: '//ana@NAS._smb._tcp.local/Compartido');

  static String _norm(String p) => p.split('/').where((s) => s.isNotEmpty).join('/');
  static String _key(String p) => toNfc(_norm(p)).toLowerCase();

  Future<void> _op(String op, String path) async {
    final n = calls.update(op, (v) => v + 1, ifAbsent: () => 1);
    if (hang) await Completer<void>().future;
    await Future<void>.delayed(latency);
    if (!mounted) throw const NetworkFolderUnavailableException('Compartido no está montado');
    final e = failPlan?.call(op, path, n);
    if (e != null) throw e;
  }

  /// Rutas reales de la carpeta (para comprobar qué se escribió).
  List<String> get paths => [for (final f in files.values) f.$1]..sort();

  @override
  Future<List<FsEntry>> list(String dir) async {
    await _op('list', dir);
    final prefix = _key(dir);
    return [
      for (final (path, bytes, at) in files.values)
        if (prefix.isEmpty || _key(path).startsWith('$prefix/')) FsEntry(toNfd(path), bytes.length, at),
    ];
  }

  @override
  Future<Uint8List> read(String path) async {
    await _op('read', path);
    final f = files[_key(path)];
    if (f == null) throw osError(TransientErrors.enoent, path);
    return f.$2;
  }

  @override
  Future<bool> exists(String path) async {
    await _op('exists', path);
    return files.containsKey(_key(path));
  }

  void _put(String path, Uint8List bytes) {
    final key = _key(path);
    // Como en SMB: si ya existe con otra grafía, se conserva la del primero.
    final existing = files[key]?.$1;
    final dirs = _norm(path).split('/');
    // Las carpetas también conservan la grafía con la que se crearon.
    for (var i = 1; i < dirs.length; i++) {
      final d = dirs.take(i).join('/').toLowerCase();
      for (final f in files.values) {
        final fp = f.$1.split('/');
        if (fp.length > i && toNfc(fp.take(i).join('/')).toLowerCase() == toNfc(d)) {
          dirs.replaceRange(0, i, fp.take(i));
          break;
        }
      }
    }
    files[key] = (existing ?? dirs.join('/'), Uint8List.fromList(bytes), DateTime.now());
    writes++;
    if (appleDouble) {
      final segs = _norm(path).split('/');
      final ad = [...segs.take(segs.length - 1), '._${segs.last}'].join('/');
      files[_key(ad)] = (ad, Uint8List(4096), DateTime.now());
    }
  }

  @override
  Future<void> writeNew(String path, Uint8List bytes) async {
    await _op('writeNew', path);
    if (files.containsKey(_key(path))) throw FsExistsException(path);
    _put(path, bytes);
  }

  @override
  Future<void> writeReplace(String path, Uint8List bytes) async {
    await _op('writeReplace', path);
    _put(path, bytes);
  }

  @override
  Future<void> delete(String path) async {
    await _op('delete', path);
    files.remove(_key(path));
  }

  @override
  Future<bool> checkAccess() async {
    try {
      await _op('check', '');
      return true;
    } on Exception {
      return false;
    }
  }
}
