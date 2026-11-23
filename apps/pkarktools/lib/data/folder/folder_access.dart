import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'folder_fs.dart';
import 'resilient_folder_fs.dart';
import 'volume_info.dart';

/// Cómo se llega a la carpeta del Arca en este dispositivo.
enum LocationKind {
  /// Documentos de la app (sin sincronización salvo la del sistema).
  appLocal,

  /// Ruta directa (Windows/Linux).
  path,

  /// Security-scoped bookmark (iOS/macOS).
  bookmark,

  /// Árbol del Storage Access Framework (Android).
  saf,
}

/// Carpeta del Arca elegida en este dispositivo (se guarda en el índice local).
class ArcaLocation {
  const ArcaLocation(this.kind, {this.value = '', this.label = '', this.network = false, this.volume = ''});
  final LocationKind kind;

  /// Ruta, bookmark en base64 o URI del árbol SAF.
  final String value;
  final String label;

  /// La carpeta está en un volumen de red (NAS). Se recuerda para que, si al
  /// abrir la app el recurso no está montado, se muestre «Carpeta de red no
  /// disponible» y nunca se escriba en la ruta local que queda en su lugar.
  final bool network;

  /// Nombre del NAS y del recurso (`NAS/Compartido`) para mostrar.
  final String volume;

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'value': value,
        'label': label,
        if (network) 'network': true,
        if (volume.isNotEmpty) 'volume': volume,
      };

  static ArcaLocation? fromJson(Map<String, Object?>? m) {
    if (m == null) return null;
    final kind = LocationKind.values.where((k) => k.name == m['kind']).firstOrNull;
    if (kind == null) return null;
    return ArcaLocation(kind,
        value: (m['value'] as String?) ?? '',
        label: (m['label'] as String?) ?? '',
        network: m['network'] == true,
        volume: (m['volume'] as String?) ?? '');
  }

  ArcaLocation withValue(String v) => ArcaLocation(kind, value: v, label: label, network: network, volume: volume);

  /// Copia con los datos del volumen detectado en [fs].
  ArcaLocation withVolumeOf(FolderFs fs) {
    final v = fs.volume;
    if (v == null) return this;
    return ArcaLocation(kind, value: value, label: label, network: v.isNetwork, volume: v.isNetwork ? v.displayName : '');
  }
}

/// Servicio de nube que sincroniza la carpeta, deducido de su ruta.
enum SyncProvider { iCloud, googleDrive, oneDrive, dropbox, syncthing, nas, none }

/// Servicio que sincroniza o aloja la carpeta. [network] = la carpeta está en
/// un volumen de red (NAS por SMB/AFP/NFS/WebDAV, o un proveedor SMB de SAF).
SyncProvider detectSyncProvider(String label, {bool network = false}) {
  if (network) return SyncProvider.nas;
  final l = label.toLowerCase();
  if (l.startsWith('smb://') || l.startsWith('afp://') || l.startsWith('nfs://') || l.startsWith(r'\\')) {
    return SyncProvider.nas;
  }
  if (l.contains('mobile documents') || l.contains('clouddocs') || l.contains('icloud')) return SyncProvider.iCloud;
  if (l.contains('google drive') || l.contains('googledrive') || l.contains('com.google.android.apps.docs')) {
    return SyncProvider.googleDrive;
  }
  if (l.contains('onedrive')) return SyncProvider.oneDrive;
  if (l.contains('dropbox')) return SyncProvider.dropbox;
  if (l.contains('syncthing') || l.contains('/sync/')) return SyncProvider.syncthing;
  return SyncProvider.none;
}

/// Sugerencia de carpeta en el onboarding según la plataforma.
enum FolderSuggestion {
  /// iOS y macOS.
  iCloudDrive,

  /// Android: Google Drive (o Documentos, solo en el teléfono).
  googleDrive,

  /// Windows.
  oneDrive,

  /// Linux.
  syncthing,

  /// Genérica: Documentos.
  documents;

  static FolderSuggestion forPlatform(TargetPlatform p) => switch (p) {
        TargetPlatform.iOS || TargetPlatform.macOS => iCloudDrive,
        TargetPlatform.android => googleDrive,
        TargetPlatform.windows => oneDrive,
        TargetPlatform.linux => syncthing,
        TargetPlatform.fuchsia => documents,
      };

  /// Nubes que se muestran en el onboarding, la sugerida primero.
  List<String> get providers => switch (this) {
        iCloudDrive => const ['iCloud Drive', 'Google Drive', 'Dropbox', 'OneDrive'],
        googleDrive => const ['Google Drive', 'Dropbox', 'OneDrive', 'Syncthing'],
        oneDrive => const ['OneDrive', 'Google Drive', 'Dropbox', 'iCloud Drive'],
        syncthing => const ['Syncthing', 'Dropbox', 'Google Drive', 'Nextcloud'],
        documents => const ['Google Drive', 'Dropbox', 'OneDrive', 'Syncthing'],
      };
}

/// Una carpeta recién elegida, ya accesible.
class OpenedFolder {
  const OpenedFolder(this.location, this.fs);
  final ArcaLocation location;
  final FolderFs fs;
}

/// Elegir carpetas y recuperar el acceso en cada arranque.
abstract class FolderAccess {
  FolderSuggestion get suggestion;

  /// Abre el selector del sistema. null si el usuario cancela.
  Future<OpenedFolder?> pick();

  /// Carpeta local de la app.
  Future<OpenedFolder> appLocal();

  /// Recupera el acceso a una carpeta guardada. Lanza
  /// [FolderAccessLostException] si ya no es accesible. Puede devolver una
  /// ubicación renovada (bookmark caducado y regenerado).
  Future<OpenedFolder> open(ArcaLocation location);
}

/// Implementación real por plataforma.
class PlatformFolderAccess implements FolderAccess {
  const PlatformFolderAccess();

  static const _apple = MethodChannel('dev.pkarktools/folder');
  static const _saf = MethodChannel('dev.pkarktools/saf');

  bool get _isApple => !kIsWeb && (Platform.isIOS || Platform.isMacOS);
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  @override
  FolderSuggestion get suggestion => FolderSuggestion.forPlatform(defaultTargetPlatform);

  @override
  Future<OpenedFolder?> pick() async {
    if (_isApple) {
      final r = await _apple.invokeMapMethod<String, Object?>('pick');
      if (r == null) return null;
      final path = r['path']! as String;
      final fs = forVolume(IoFolderFs(Directory(path), label: path, expectNetwork: r['volumeIsLocal'] == false));
      final loc = ArcaLocation(LocationKind.bookmark, value: r['bookmark']! as String, label: path).withVolumeOf(fs);
      return OpenedFolder(loc, fs);
    }
    if (_isAndroid) {
      final tree = await _saf.invokeMethod<String>('pickTree');
      if (tree == null) return null;
      final label = SafFolderFs.labelFor(tree);
      final fs = SafFolderFs(tree, label);
      return OpenedFolder(ArcaLocation(LocationKind.saf, value: tree, label: label).withVolumeOf(fs), fs);
    }
    String? initial;
    try {
      initial = (await getApplicationDocumentsDirectory()).path;
    } catch (_) {}
    final uri = await FilePicker.pickDirectory(dialogTitle: 'Carpeta del Arca', initialDirectory: initial);
    if (uri == null || uri.scheme != 'file') return null;
    final path = uri.toFilePath();
    final fs = forVolume(IoFolderFs(Directory(path)));
    return OpenedFolder(ArcaLocation(LocationKind.path, value: path, label: path).withVolumeOf(fs), fs);
  }

  @override
  Future<OpenedFolder> appLocal() async {
    final docs = await getApplicationDocumentsDirectory();
    return OpenedFolder(
      ArcaLocation(LocationKind.appLocal, label: docs.path),
      IoFolderFs(docs, label: docs.path),
    );
  }

  @override
  Future<OpenedFolder> open(ArcaLocation location) async {
    switch (location.kind) {
      case LocationKind.appLocal:
        return appLocal();
      case LocationKind.path:
        return openIoFolder(location, location.value);
      case LocationKind.bookmark:
        final Map<String, Object?>? r;
        try {
          // Resolver un bookmark de un recurso de red puede intentar montarlo:
          // nunca más de unos segundos.
          r = await _apple
              .invokeMapMethod<String, Object?>('resolve', {'bookmark': location.value}).timeout(resolveTimeout);
        } on TimeoutException {
          throw NetworkFolderUnavailableException('La carpeta de red ${location.label} no responde');
        } on PlatformException catch (e) {
          final msg = e.message ?? 'No se pudo recuperar el acceso a la carpeta';
          throw location.network ? NetworkFolderUnavailableException(msg) : FolderAccessLostException(msg);
        }
        if (r == null) throw const FolderAccessLostException('No se pudo recuperar el acceso a la carpeta');
        final path = r['path']! as String;
        final refreshed = r['bookmark'] as String?;
        final loc = ArcaLocation(LocationKind.bookmark,
            value: refreshed ?? location.value, label: path, network: location.network, volume: location.volume);
        return openIoFolder(loc, path, expectNetwork: r['volumeIsLocal'] == false);
      case LocationKind.saf:
        final fs = SafFolderFs(location.value, location.label);
        if (!await fs.checkAccess()) {
          final msg = 'Android ya no da permiso sobre "${location.label}"';
          throw location.network ? NetworkFolderUnavailableException(msg) : FolderAccessLostException(msg);
        }
        return OpenedFolder(location.withVolumeOf(fs), fs);
    }
  }

  /// Tiempo máximo para resolver un bookmark (puede montar un recurso de red).
  static const resolveTimeout = Duration(seconds: 20);

  /// Abre una carpeta por ruta comprobando que se puede escribir. Si la
  /// ubicación es de red y el recurso no está montado lanza
  /// [NetworkFolderUnavailableException] sin crear ni escribir nada.
  static Future<OpenedFolder> openIoFolder(ArcaLocation location, String path,
      {bool expectNetwork = false, MountTable? mounts}) async {
    final io = IoFolderFs(Directory(path),
        label: location.kind == LocationKind.path ? null : path,
        mounts: mounts,
        expectNetwork: expectNetwork || location.network);
    final fs = forVolume(io);
    if (!await fs.checkAccess()) {
      if (location.network || io.isNetwork) {
        throw NetworkFolderUnavailableException(
            'La carpeta de red ${location.volume.isEmpty ? path : location.volume} no está disponible');
      }
      throw FolderAccessLostException('La carpeta $path no está disponible');
    }
    return OpenedFolder(location.withVolumeOf(fs), fs);
  }

  /// Pide a iCloud que descargue los archivos aún no presentes (`.icloud`).
  static Future<void> requestDownloads(String root, List<String> placeholders) async {
    if (kIsWeb || !(Platform.isIOS || Platform.isMacOS) || placeholders.isEmpty) return;
    try {
      await _apple.invokeMethod<void>('download', {'root': root, 'paths': placeholders});
    } catch (_) {}
  }
}

/// [FolderFs] sobre un árbol del Storage Access Framework (Android).
///
/// Las operaciones las hace `MainActivity.kt` recorriendo el árbol por nombre.
/// La escritura atómica es "crear `.<nombre>.tmp` + escribir + renombrar".
class SafFolderFs implements FolderFs {
  SafFolderFs(this.tree, this.label);

  static const _ch = MethodChannel('dev.pkarktools/saf');

  final String tree;
  @override
  final String label;

  @override
  String? get nativePath => null;

  /// Un proveedor de documentos SMB/CIFS (p. ej. «CIFS Documents Provider»)
  /// cuenta como carpeta de red.
  @override
  VolumeInfo? get volume => isNetworkTree(tree)
      ? VolumeInfo(fsType: 'smb', mountPoint: label, source: label, network: true)
      : null;

  static bool isNetworkTree(String tree) {
    final authority = Uri.tryParse(tree)?.authority.toLowerCase() ?? '';
    return authority.split(RegExp(r'[.\-_]')).any((p) => const {'cifs', 'smb', 'samba', 'nas', 'lan', 'smbj'}.contains(p)) ||
        authority.contains('cifsdocumentsprovider');
  }

  static String labelFor(String tree) {
    final last = Uri.decodeComponent(tree.split('/').last);
    final colon = last.indexOf(':');
    return colon >= 0 ? last.substring(colon + 1).ifEmpty(last) : last;
  }

  Never _lost(PlatformException e) => throw FolderAccessLostException(e.message ?? 'Sin acceso a la carpeta');

  @override
  Future<List<FsEntry>> list(String dir) async {
    try {
      final r = await _ch.invokeListMethod<Map<Object?, Object?>>('treeList', {'tree': tree, 'dir': dir});
      return [
        for (final e in r ?? const <Map<Object?, Object?>>[])
          FsEntry(
            e['path']! as String,
            (e['size'] as num?)?.toInt() ?? 0,
            e['modified'] == null ? null : DateTime.fromMillisecondsSinceEpoch((e['modified']! as num).toInt()),
          ),
      ];
    } on PlatformException catch (e) {
      if (e.code == 'access') _lost(e);
      rethrow;
    }
  }

  @override
  Future<Uint8List> read(String path) async {
    final r = await _ch.invokeMethod<Uint8List>('treeRead', {'tree': tree, 'path': path});
    if (r == null) throw FileSystemException('No se pudo leer', path);
    return r;
  }

  @override
  Future<bool> exists(String path) async =>
      (await _ch.invokeMethod<bool>('treeExists', {'tree': tree, 'path': path})) ?? false;

  @override
  Future<void> writeNew(String path, Uint8List bytes) async {
    try {
      await _ch.invokeMethod<void>('treeWriteNew', {'tree': tree, 'path': path, 'bytes': bytes});
    } on PlatformException catch (e) {
      if (e.code == 'exists') throw FsExistsException(path);
      if (e.code == 'access') _lost(e);
      rethrow;
    }
  }

  @override
  Future<void> writeReplace(String path, Uint8List bytes) async {
    try {
      await _ch.invokeMethod<void>('treeReplace', {'tree': tree, 'path': path, 'bytes': bytes});
    } on PlatformException catch (e) {
      if (e.code == 'access') _lost(e);
      rethrow;
    }
  }

  @override
  Future<void> delete(String path) => _ch.invokeMethod<void>('treeDelete', {'tree': tree, 'path': path});

  @override
  Future<bool> checkAccess() async {
    try {
      return (await _ch.invokeMethod<bool>('treeCheck', {'tree': tree})) ?? false;
    } on PlatformException {
      return false;
    }
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// Usado al serializar la ubicación en los ajustes.
String encodeLocation(ArcaLocation l) => jsonEncode(l.toJson());
