import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Un sistema de archivos montado.
class MountEntry {
  const MountEntry({required this.mountPoint, required this.fsType, required this.source});

  /// Dónde está montado (`/Volumes/Compartido`).
  final String mountPoint;

  /// `smbfs`, `afpfs`, `nfs`, `webdav`, `apfs`, `cifs`…
  final String fsType;

  /// Origen (`//usuario@NAS._smb._tcp.local/Compartido`, `nas:/export`…).
  final String source;

  @override
  String toString() => 'MountEntry($mountPoint, $fsType, $source)';
}

/// Volumen en el que está la carpeta del Arca.
class VolumeInfo {
  const VolumeInfo({required this.fsType, required this.mountPoint, this.source = '', bool? network})
      : _network = network;

  final String fsType;
  final String mountPoint;
  final String source;
  final bool? _network;

  /// Tipos de sistema de archivos de red (macOS, Linux y FUSE).
  static const networkFsTypes = {
    'smbfs', 'afpfs', 'nfs', 'webdav', 'cifs', 'smb3', 'smb2', 'smb', 'nfs4', 'ncpfs', 'ftp', //
    'fuse.sshfs', 'sshfs', 'davfs', 'fuse.davfs2', 'fuse.rclone', '9p', 'ceph', 'glusterfs', 'fuse.glusterfs',
  };

  bool get isNetwork => _network ?? networkFsTypes.contains(fsType.toLowerCase());

  /// Protocolo para mostrar (`SMB`, `AFP`, `NFS`, `WebDAV`…).
  String get protocol => switch (fsType.toLowerCase()) {
        'smbfs' || 'cifs' || 'smb3' || 'smb2' || 'smb' => 'SMB',
        'afpfs' => 'AFP',
        'nfs' || 'nfs4' => 'NFS',
        'webdav' || 'davfs' || 'fuse.davfs2' => 'WebDAV',
        'fuse.sshfs' || 'sshfs' => 'SFTP',
        final t => t,
      };

  /// Servidor del recurso (sin `usuario@` ni `._smb._tcp.local`), si se sabe.
  String? get server => parseSource(source).$1;

  /// Recurso compartido (`Compartido`), si se sabe.
  String? get share => parseSource(source).$2;

  /// `NAS/Compartido` (o el punto de montaje si no se sabe el origen).
  String get displayName {
    final (srv, sh) = parseSource(source);
    if (srv != null && sh != null) return '$srv/$sh';
    if (srv != null) return srv;
    final parts = mountPoint.split('/').where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? mountPoint : parts.last;
  }

  /// Servidor y recurso a partir del origen del montaje:
  /// `//usuario;DOM@nas._smb._tcp.local/Compartido`, `//nas/share` (cifs),
  /// `nas.local:/volume1/share` (NFS), `https://nas:5006/share` (WebDAV),
  /// `\\nas\share` (UNC de Windows).
  static (String?, String?) parseSource(String source) {
    var s = source.trim();
    if (s.isEmpty) return (null, null);
    String clean(String host) {
      var h = host;
      final at = h.lastIndexOf('@');
      if (at >= 0) h = h.substring(at + 1);
      final colon = h.indexOf(':');
      if (colon >= 0) h = h.substring(0, colon);
      h = h.replaceFirst(RegExp(r'\._(smb|afpovertcp|nfs|webdav)\._tcp\.local\.?$', caseSensitive: false), '');
      return Uri.decodeComponent(h);
    }

    String? firstSeg(String rest) {
      final segs = rest.split('/').where((e) => e.isNotEmpty).toList();
      return segs.isEmpty ? null : Uri.decodeComponent(segs.last);
    }

    final scheme = RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).firstMatch(s);
    if (scheme != null) {
      s = s.substring(scheme.end);
      final slash = s.indexOf('/');
      return slash < 0 ? (clean(s), null) : (clean(s.substring(0, slash)), firstSeg(s.substring(slash)));
    }
    if (s.startsWith('//') || s.startsWith(r'\\')) {
      final parts = s.substring(2).split(RegExp(r'[/\\]')).where((e) => e.isNotEmpty).toList();
      if (parts.isEmpty) return (null, null);
      return (clean(parts.first), parts.length > 1 ? Uri.decodeComponent(parts[1]) : null);
    }
    final nfs = RegExp(r'^([^/:]+):(/.*)$').firstMatch(s);
    if (nfs != null) return (clean(nfs.group(1)!), firstSeg(nfs.group(2)!));
    return (null, null);
  }

  @override
  String toString() => 'VolumeInfo($fsType, $mountPoint, $source)';
}

/// Tabla de montajes del sistema. Se puede sustituir en pruebas.
abstract class MountTable {
  const MountTable();

  /// Montajes actuales. Nunca bloquea en un volumen de red colgado.
  List<MountEntry> mounts();

  /// Volumen que contiene [path] (el punto de montaje más largo que lo
  /// contiene), o null si no se sabe.
  VolumeInfo? volumeOf(String path) => volumeFor(path, mounts());

  static VolumeInfo? volumeFor(String path, List<MountEntry> mounts) {
    if (Platform.isWindows || path.startsWith(r'\\')) {
      // \\servidor\recurso\... (UNC): siempre red.
      if (path.startsWith(r'\\') && !path.startsWith(r'\\?\')) {
        final (srv, sh) = VolumeInfo.parseSource(path);
        return VolumeInfo(fsType: 'smb', mountPoint: r'\\' '$srv\\${sh ?? ''}', source: path, network: true);
      }
    }
    MountEntry? best;
    for (final m in mounts) {
      final mp = m.mountPoint;
      final inside = mp == '/' || path == mp || path.startsWith(mp.endsWith('/') ? mp : '$mp/');
      if (inside && (best == null || mp.length > best.mountPoint.length)) best = m;
    }
    if (best == null) return null;
    return VolumeInfo(fsType: best.fsType, mountPoint: best.mountPoint, source: best.source);
  }

  /// Implementación de la plataforma actual.
  static MountTable get system => _system ??= Platform.isMacOS
      ? const DarwinMountTable()
      : (Platform.isLinux || Platform.isAndroid)
          ? const ProcMountTable()
          : const _NoMountTable();
  static MountTable? _system;
}

class _NoMountTable extends MountTable {
  const _NoMountTable();
  @override
  List<MountEntry> mounts() => const [];
}

/// Tabla fija (pruebas).
class StaticMountTable extends MountTable {
  StaticMountTable(this.entries);
  List<MountEntry> entries;
  @override
  List<MountEntry> mounts() => entries;
}

/// Linux/Android: `/proc/self/mounts`.
class ProcMountTable extends MountTable {
  const ProcMountTable();

  @override
  List<MountEntry> mounts() {
    try {
      return parse(File('/proc/self/mounts').readAsStringSync());
    } catch (_) {
      return const [];
    }
  }

  static String _unescape(String s) =>
      s.replaceAllMapped(RegExp(r'\\([0-7]{3})'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 8)));

  static List<MountEntry> parse(String text) => [
        for (final line in text.split('\n'))
          if (line.trim().split(RegExp(r'\s+')) case [final src, final mp, final type, ...])
            MountEntry(mountPoint: _unescape(mp), fsType: type, source: _unescape(src)),
      ];
}

/// macOS: `getfsstat(MNT_NOWAIT)` por FFI. Con `MNT_NOWAIT` el kernel
/// devuelve la información en caché y nunca espera a un servidor de red que
/// no responde (a diferencia de `statfs` sobre la ruta).
class DarwinMountTable extends MountTable {
  const DarwinMountTable();

  // struct statfs (64 bits): f_fstypename en 72 (16), f_mntonname en 88
  // (1024), f_mntfromname en 1112 (1024); tamaño total 2168.
  static const _size = 2168;
  static const _typeOff = 72;
  static const _onOff = 88;
  static const _fromOff = 1112;
  static const _mntNoWait = 2;

  static int Function(Pointer<Uint8>, int, int)? _fn;

  static int Function(Pointer<Uint8>, int, int) _lookup() {
    final lib = DynamicLibrary.process();
    for (final name in const [r'getfsstat$INODE64', 'getfsstat']) {
      try {
        return lib.lookupFunction<Int32 Function(Pointer<Uint8>, Int32, Int32), int Function(Pointer<Uint8>, int, int)>(
            name);
      } on ArgumentError {
        continue;
      }
    }
    throw UnsupportedError('getfsstat no disponible');
  }

  static String _cstr(Pointer<Uint8> base, int off, int max) {
    final bytes = <int>[];
    for (var i = 0; i < max; i++) {
      final b = base[off + i];
      if (b == 0) break;
      bytes.add(b);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  List<MountEntry> mounts() {
    try {
      final fn = _fn ??= _lookup();
      final n = fn(nullptr, 0, _mntNoWait);
      if (n <= 0) return const [];
      final cap = n + 4;
      final buf = calloc<Uint8>(cap * _size);
      try {
        final got = fn(buf, cap * _size, _mntNoWait);
        return [
          for (var i = 0; i < got; i++)
            MountEntry(
              fsType: _cstr(buf, i * _size + _typeOff, 16),
              mountPoint: _cstr(buf, i * _size + _onOff, 1024),
              source: _cstr(buf, i * _size + _fromOff, 1024),
            ),
        ];
      } finally {
        calloc.free(buf);
      }
    } catch (_) {
      return const [];
    }
  }
}

