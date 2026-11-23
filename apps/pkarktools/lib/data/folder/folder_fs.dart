import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'unicode_names.dart';
import 'volume_info.dart';

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

/// La carpeta está en un volumen de red (NAS por SMB/AFP/NFS/WebDAV) que no
/// está montado o no responde. Nunca se trata como un Arca vacía.
class NetworkFolderUnavailableException extends FolderAccessLostException {
  const NetworkFolderUnavailableException(super.message);
}

/// Archivos y carpetas de sistema que nunca forman parte del Arca y que ni
/// siquiera se recorren al listar: metadatos de macOS en volúmenes de red
/// (`._*` AppleDouble, `.DS_Store`), papeleras e índices de los NAS
/// (Synology `@eaDir` y `#recycle`, QNAP `@Recycle` y `.@__thumb`, NetApp
/// `.snapshot`, `#snapshot`) y de Windows (`$RECYCLE.BIN`,
/// `System Volume Information`, `Thumbs.db`, `desktop.ini`).
abstract final class SystemJunk {
  static const _dirs = {
    '@eadir', '#recycle', '@recycle', '#snapshot', '.snapshot', '.snapshots', '@recently-snapshot', //
    r'$recycle.bin', 'system volume information', '.@__thumb', '.trashes', '.trash', '.fseventsd',
    '.spotlight-v100', '.temporaryitems', '.documentrevisions-v100', 'lost+found', '.recycle', '@sharebin',
  };
  static const _files = {'.ds_store', 'thumbs.db', 'desktop.ini', '.localized', 'icon\r'};

  /// Carpeta que no se recorre.
  static bool isDir(String name) => _dirs.contains(name.toLowerCase());

  /// Archivo que no se lista.
  static bool isFile(String name) {
    final l = name.toLowerCase();
    return name.startsWith('._') || name.startsWith('.nfs') || name.startsWith('.smbdelete') || _files.contains(l);
  }
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

  /// Volumen donde está la carpeta, si se sabe (para detectar un NAS).
  VolumeInfo? get volume;
}

extension FolderFsNetwork on FolderFs {
  /// La carpeta está en un volumen de red (NAS).
  bool get isNetwork => volume?.isNetwork ?? false;
}

/// [FolderFs] sobre `dart:io`.
///
/// Si la carpeta está en un volumen de red, cada operación comprueba antes
/// (sin tocar la red, con la tabla de montajes) que el volumen sigue montado:
/// en macOS un recurso SMB desmontado deja `/Volumes/<recurso>` como carpeta
/// local vacía (o sin carpeta), y escribir ahí crearía un Arca en el disco
/// del Mac. Además nunca se crea la propia carpeta raíz.
class IoFolderFs implements FolderFs {
  IoFolderFs(this.root,
      {String? label, MountTable? mounts, bool expectNetwork = false, this.statConcurrency = 8, bool? nfdLookups})
      : _label = label,
        _mounts = mounts ?? MountTable.system,
        _expectNetwork = expectNetwork,
        _nfdLookupsOverride = nfdLookups;

  final bool? _nfdLookupsOverride;

  final Directory root;
  final String? _label;
  final MountTable _mounts;
  final bool _expectNetwork;

  /// `stat` simultáneos al listar (en red cada uno es una ida y vuelta).
  final int statConcurrency;
  static final _rand = Random();

  VolumeInfo? _volume;
  bool _volumeRead = false;

  /// Punto de montaje del volumen de red con el que se abrió la carpeta.
  String? _networkMount;

  @override
  String get label => _label ?? root.path;

  @override
  String? get nativePath => root.path;

  @override
  VolumeInfo? get volume {
    if (!_volumeRead) {
      _volumeRead = true;
      _volume = _mounts.volumeOf(root.absolute.path);
      if (_volume?.isNetwork ?? false) _networkMount = _volume!.mountPoint;
    }
    return _volume;
  }

  /// Comprueba que el volumen de red sigue montado en el mismo sitio.
  void _guard() {
    final first = volume;
    final mustBeNetwork = _expectNetwork || (first?.isNetwork ?? false);
    if (!mustBeNetwork) return;
    final now = _mounts.volumeOf(root.absolute.path);
    if (now == null || !now.isNetwork || (_networkMount != null && now.mountPoint != _networkMount)) {
      throw NetworkFolderUnavailableException('La carpeta de red ${root.path} no está montada');
    }
    _volume = now;
    _networkMount ??= now.mountPoint;
  }

  /// Ruta real (tal como la guarda el disco) de las rutas listadas cuyo nombre
  /// no estaba en NFC: ruta NFC → ruta real. Incluye las carpetas.
  final Map<String, String> _real = {};

  String _resolve(String rel) {
    if (_real.isEmpty) return rel;
    final hit = _real[rel];
    if (hit != null) return hit;
    final segs = rel.split('/');
    for (var i = segs.length - 1; i > 0; i--) {
      final dir = _real[segs.take(i).join('/')];
      if (dir != null) return '$dir/${segs.skip(i).join('/')}';
    }
    return rel;
  }

  String _abs(String rel) =>
      p.joinAll([root.path, ..._resolve(rel.split('/').where((s) => s.isNotEmpty).join('/')).split('/').where((s) => s.isNotEmpty)]);

  /// Buscar por NFD lo que no aparece por NFC (smbfs/AFP en macOS).
  bool get _nfdLookups => _nfdLookupsOverride ?? (Platform.isMacOS && (_expectNetwork || isNetwork));

  /// Ruta absoluta de [rel] tal como la encuentra el disco. En smbfs de
  /// macOS, tras listar una carpeta sus entradas pueden no encontrarse por la
  /// ruta en NFC (la que usa el Arca) pero sí por la de NFD: sin esto,
  /// `exists` diría que falta un archivo que está y `writeNew` lo
  /// reemplazaría. Solo cuesta un `stat` extra con nombres no ASCII que no
  /// aparecen por NFC; si no existe en ninguna forma, se resuelve la carpeta
  /// padre y el nombre nuevo se crea en NFC.
  Future<String> _locate(String rel) async {
    final abs = _abs(rel);
    if (!_nfdLookups || !rel.codeUnits.any((c) => c >= 0xC0)) return abs;
    if (await FileSystemEntity.type(abs, followLinks: false) != FileSystemEntityType.notFound) return abs;
    final relReal = p.relative(abs, from: root.path);
    final nfd = toNfd(relReal);
    if (nfd != relReal) {
      final alt = p.join(root.path, nfd);
      if (await FileSystemEntity.type(alt, followLinks: false) != FileSystemEntityType.notFound) {
        final clean = rel.split('/').where((s) => s.isNotEmpty).join('/');
        _real[clean] = nfd.split(p.separator).join('/');
        return alt;
      }
    }
    final segs = rel.split('/').where((s) => s.isNotEmpty).toList();
    if (segs.length < 2) return abs;
    return p.join(await _locate(segs.take(segs.length - 1).join('/')), p.basename(abs));
  }

  /// La raíz está bajo `/Volumes/<volumen>` pero ese volumen no está montado
  /// (la ruta caería en el disco del sistema).
  bool get _onDetachedVolume {
    if (!Platform.isMacOS) return false;
    final path = root.absolute.path;
    if (!path.startsWith('/Volumes/')) return false;
    final v = _mounts.volumeOf(path);
    return v != null && !v.mountPoint.startsWith('/Volumes/');
  }

  /// Crea las carpetas intermedias de [dir]. La raíz solo se crea si falta en
  /// un disco local: nunca en una carpeta de red ni en un volumen desmontado.
  Future<void> _mkdirs(Directory dir) async {
    if (!await root.exists()) {
      if (_expectNetwork || _networkMount != null) {
        throw NetworkFolderUnavailableException('La carpeta de red ${root.path} no está disponible');
      }
      if (_onDetachedVolume) throw FolderAccessLostException('El volumen de ${root.path} no está conectado');
    }
    if (await dir.exists()) return;
    await dir.create(recursive: true);
  }

  @override
  Future<List<FsEntry>> list(String dir) async {
    _guard();
    final base = Directory(await _locate(dir));
    if (!await base.exists()) {
      if (!await root.exists()) throw FolderAccessLostException('La carpeta ${root.path} ya no existe');
      return const [];
    }
    final out = <FsEntry>[];
    final files = <File>[];
    try {
      // Recorrido propio (no `recursive: true`) para no bajar a las papeleras
      // e índices de los NAS, que pueden tener miles de archivos.
      final pending = <Directory>[base];
      while (pending.isNotEmpty) {
        final d = pending.removeLast();
        await for (final e in d.list(followLinks: false)) {
          final name = p.basename(e.path);
          if (e is Directory) {
            if (!SystemJunk.isDir(name)) pending.add(e);
          } else if (e is File && !SystemJunk.isFile(name)) {
            files.add(e);
          }
        }
      }
    } on FileSystemException catch (e) {
      if (!await root.exists()) throw FolderAccessLostException('La carpeta ${root.path} ya no existe: ${e.message}');
      rethrow;
    }
    // stat en paralelo acotado: en un NAS cada uno es una ida y vuelta.
    var next = 0;
    Future<void> worker() async {
      while (next < files.length) {
        final f = files[next++];
        try {
          final st = await f.stat();
          if (st.type == FileSystemEntityType.notFound) continue;
          final real = p.relative(f.path, from: root.path).split(p.separator).join('/');
          final nfc = toNfc(real);
          if (nfc != real) {
            _real[nfc] = real;
            final a = real.split('/'), b = nfc.split('/');
            for (var i = 1; i < a.length; i++) {
              final ra = a.take(i).join('/'), rb = b.take(i).join('/');
              if (ra != rb) _real[rb] = ra;
            }
          }
          out.add(FsEntry(nfc, st.size, st.modified));
        } on FileSystemException {
          // Archivo que desaparece mientras se lista (sincronización en curso).
        }
      }
    }

    await Future.wait([for (var i = 0; i < max(1, statConcurrency); i++) worker()]);
    out.sort((a, b) => a.path.compareTo(b.path));
    return out;
  }

  @override
  Future<Uint8List> read(String path) async {
    _guard();
    return File(await _locate(path)).readAsBytes();
  }

  @override
  Future<bool> exists(String path) async {
    _guard();
    return File(await _locate(path)).exists();
  }

  File _tmpFor(File f) => File(p.join(f.parent.path, '.${p.basename(f.path)}.${_rand.nextInt(1 << 32).toRadixString(16)}.tmp'));

  @override
  Future<void> writeNew(String path, Uint8List bytes) async {
    _guard();
    final f = File(await _locate(path));
    if (await f.exists()) throw FsExistsException(path);
    await _mkdirs(f.parent);
    // El temporal empieza por '.' y termina en '.tmp': el reindexado lo ignora
    // aunque otro dispositivo lo vea a medio sincronizar.
    final tmp = _tmpFor(f);
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      _guard();
      if (await f.exists()) throw FsExistsException(path);
      await tmp.rename(f.path);
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
  }

  @override
  Future<void> writeReplace(String path, Uint8List bytes) async {
    _guard();
    final f = File(await _locate(path));
    await _mkdirs(f.parent);
    final tmp = _tmpFor(f);
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      _guard();
      try {
        // rename reemplaza el destino de forma atómica (POSIX, smbfs con
        // SMB2+ y MoveFileEx).
        await tmp.rename(f.path);
      } on FileSystemException {
        // Algunos servidores SMB/AFP no reemplazan un archivo existente (o lo
        // tienen abierto otro cliente): se aparta el anterior, se renombra el
        // nuevo y solo entonces se borra el apartado.
        if (!await f.exists()) rethrow;
        final old = _tmpFor(f);
        await f.rename(old.path);
        try {
          await tmp.rename(f.path);
        } catch (_) {
          await old.rename(f.path);
          rethrow;
        }
        try {
          await old.delete();
        } catch (_) {}
      }
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
  }

  @override
  Future<void> delete(String path) async {
    _guard();
    final f = File(await _locate(path));
    if (await f.exists()) await f.delete();
  }

  @override
  Future<bool> checkAccess() async {
    try {
      _guard();
      if (!await root.exists()) return false;
      final probe = File(p.join(root.path, '.pkarktools-acceso-${_rand.nextInt(1 << 32).toRadixString(16)}.tmp'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } on FolderAccessLostException {
      return false;
    } on FileSystemException {
      return false;
    }
  }
}
