import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'folder_fs.dart';

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
  const ArcaLocation(this.kind, {this.value = '', this.label = ''});
  final LocationKind kind;

  /// Ruta, bookmark en base64 o URI del árbol SAF.
  final String value;
  final String label;

  Map<String, Object?> toJson() => {'kind': kind.name, 'value': value, 'label': label};

  static ArcaLocation? fromJson(Map<String, Object?>? m) {
    if (m == null) return null;
    final kind = LocationKind.values.where((k) => k.name == m['kind']).firstOrNull;
    if (kind == null) return null;
    return ArcaLocation(kind, value: (m['value'] as String?) ?? '', label: (m['label'] as String?) ?? '');
  }

  ArcaLocation withValue(String v) => ArcaLocation(kind, value: v, label: label);
}

/// Servicio de nube que sincroniza la carpeta, deducido de su ruta.
enum SyncProvider { iCloud, googleDrive, oneDrive, dropbox, syncthing, none }

SyncProvider detectSyncProvider(String label) {
  final l = label.toLowerCase();
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
      final loc = ArcaLocation(LocationKind.bookmark, value: r['bookmark']! as String, label: path);
      return OpenedFolder(loc, IoFolderFs(Directory(path), label: path));
    }
    if (_isAndroid) {
      final tree = await _saf.invokeMethod<String>('pickTree');
      if (tree == null) return null;
      final label = SafFolderFs.labelFor(tree);
      return OpenedFolder(ArcaLocation(LocationKind.saf, value: tree, label: label), SafFolderFs(tree, label));
    }
    String? initial;
    try {
      initial = (await getApplicationDocumentsDirectory()).path;
    } catch (_) {}
    final uri = await FilePicker.pickDirectory(dialogTitle: 'Carpeta del Arca', initialDirectory: initial);
    if (uri == null || uri.scheme != 'file') return null;
    final path = uri.toFilePath();
    return OpenedFolder(ArcaLocation(LocationKind.path, value: path, label: path), IoFolderFs(Directory(path)));
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
        final fs = IoFolderFs(Directory(location.value));
        if (!await fs.checkAccess()) throw FolderAccessLostException('No se puede escribir en ${location.value}');
        return OpenedFolder(location, fs);
      case LocationKind.bookmark:
        final Map<String, Object?>? r;
        try {
          r = await _apple.invokeMapMethod<String, Object?>('resolve', {'bookmark': location.value});
        } on PlatformException catch (e) {
          throw FolderAccessLostException(e.message ?? 'No se pudo recuperar el acceso a la carpeta');
        }
        if (r == null) throw const FolderAccessLostException('No se pudo recuperar el acceso a la carpeta');
        final path = r['path']! as String;
        final refreshed = r['bookmark'] as String?;
        final loc = ArcaLocation(LocationKind.bookmark, value: refreshed ?? location.value, label: path);
        final fs = IoFolderFs(Directory(path), label: path);
        if (!await fs.checkAccess()) throw FolderAccessLostException('La carpeta $path no está disponible');
        return OpenedFolder(loc, fs);
      case LocationKind.saf:
        final fs = SafFolderFs(location.value, location.label);
        if (!await fs.checkAccess()) {
          throw FolderAccessLostException('Android ya no da permiso sobre "${location.label}"');
        }
        return OpenedFolder(location, fs);
    }
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
