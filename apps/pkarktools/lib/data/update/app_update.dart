import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../app_version.dart';

/// Versión `MAJOR.MINOR.PATCH[-pre]` de un tag (`v0.1.3`, `0.2.0-beta.1`).
@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, [this.pre = '']);

  final int major, minor, patch;

  /// Sufijo de prerelease (`beta.1`); vacío en una versión final.
  final String pre;

  static final _re = RegExp(r'^v?(\d+)\.(\d+)(?:\.(\d+))?(?:-([0-9A-Za-z.\-]+))?(?:\+.*)?$');

  static AppVersion? tryParse(String s) {
    final m = _re.firstMatch(s.trim());
    if (m == null) return null;
    return AppVersion(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3] ?? '0'), m[4] ?? '');
  }

  static final current = tryParse(kAppVersion)!;

  @override
  int compareTo(AppVersion o) {
    for (final (a, b) in [(major, o.major), (minor, o.minor), (patch, o.patch)]) {
      if (a != b) return a.compareTo(b);
    }
    // Una final va después de sus prereleases (0.2.0-beta < 0.2.0).
    if (pre.isEmpty || o.pre.isEmpty) return (pre.isEmpty ? 1 : 0) - (o.pre.isEmpty ? 1 : 0);
    final x = pre.split('.'), y = o.pre.split('.');
    for (var i = 0; i < x.length && i < y.length; i++) {
      final nx = int.tryParse(x[i]), ny = int.tryParse(y[i]);
      final c = nx != null && ny != null ? nx.compareTo(ny) : x[i].compareTo(y[i]);
      if (c != 0) return c;
    }
    return x.length.compareTo(y.length);
  }

  bool operator >(AppVersion o) => compareTo(o) > 0;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, pre);

  @override
  String toString() => '$major.$minor.$patch${pre.isEmpty ? '' : '-$pre'}';
}

/// Plataformas con descarga propia en los releases.
enum UpdatePlatform { android, macos, windows, linux, other }

UpdatePlatform get currentUpdatePlatform {
  if (kIsWeb) return UpdatePlatform.other;
  if (Platform.isAndroid) return UpdatePlatform.android;
  if (Platform.isMacOS) return UpdatePlatform.macos;
  if (Platform.isWindows) return UpdatePlatform.windows;
  if (Platform.isLinux) return UpdatePlatform.linux;
  return UpdatePlatform.other;
}

@immutable
class ReleaseAsset {
  const ReleaseAsset(this.name, this.url, this.size);
  final String name;
  final Uri url;
  final int size;
}

/// El último release publicado.
@immutable
class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.tag, required this.notes, required this.page, this.asset});

  final AppVersion version;
  final String tag;
  final String notes;

  /// Página del release (para descargar a mano).
  final Uri page;

  /// Archivo para esta plataforma (el APK en Android), si lo hay.
  final ReleaseAsset? asset;

  bool get isNewer => version > AppVersion.current;

  /// Interpreta la respuesta de `GET /repos/{repo}/releases/latest` (la API
  /// ya excluye borradores y prereleases).
  static ReleaseInfo? fromGitHub(Map<String, Object?> json, UpdatePlatform platform) {
    final tag = json['tag_name'];
    final version = tag is String ? AppVersion.tryParse(tag) : null;
    if (version == null || json['draft'] == true) return null;
    final assets = <ReleaseAsset>[
      for (final a in (json['assets'] as List?) ?? const [])
        if (a is Map && a['name'] is String && a['browser_download_url'] is String)
          ReleaseAsset(a['name'] as String, Uri.parse(a['browser_download_url'] as String), (a['size'] as num?)?.toInt() ?? 0),
    ];
    final bool Function(String) want = switch (platform) {
      UpdatePlatform.android => (n) => n.endsWith('.apk'),
      UpdatePlatform.macos => (n) => n.endsWith('-macos.zip'),
      UpdatePlatform.windows => (n) => n.endsWith('-setup.exe'),
      UpdatePlatform.linux => (n) => n.endsWith('-linux-x64.tar.gz'),
      UpdatePlatform.other => (_) => false,
    };
    final page = json['html_url'] is String
        ? Uri.parse(json['html_url'] as String)
        : Uri.parse('https://github.com/${AppUpdater.repo}/releases/tag/$tag');
    return ReleaseInfo(
      version: version,
      tag: tag as String,
      notes: (json['body'] as String? ?? '').trim(),
      page: page,
      asset: assets.where((a) => want(a.name.toLowerCase())).firstOrNull,
    );
  }
}

class UpdateException implements Exception {
  const UpdateException(this.code, [this.detail]);

  /// `network`, `http`, `format`, `size`, `permission`, `conflict`,
  /// `incompatible`, `storage`, `aborted`, `install`.
  final String code;
  final String? detail;

  @override
  String toString() => 'UpdateException($code${detail == null ? '' : ': $detail'})';
}

/// Busca la última versión en GitHub Releases y, en Android, descarga el APK
/// y lo entrega al instalador del sistema (que pide una confirmación: Android
/// no deja actualizar apps de fuera de la tienda sin ella). Los datos se
/// conservan porque es una actualización, no una instalación nueva.
class AppUpdater {
  AppUpdater({HttpClient Function()? client, Uri? api, this.platform = UpdatePlatform.other, this.downloadDir})
      : _client = client ?? HttpClient.new,
        _api = api ?? Uri.parse('https://api.github.com/repos/$repo/releases/latest');

  factory AppUpdater.forCurrentPlatform() => AppUpdater(platform: currentUpdatePlatform);

  static const repo = 'Rodriqe/PKArkTools';
  static const releasesPage = 'https://github.com/$repo/releases/latest';
  static const _channel = MethodChannel('dev.pkarktools/update');

  final HttpClient Function() _client;
  final Uri _api;
  final UpdatePlatform platform;

  /// Carpeta de descarga del APK (por defecto, la caché de la app).
  final Directory? downloadDir;

  /// En esta plataforma se puede descargar e instalar desde la app.
  bool get canInstallInApp => platform == UpdatePlatform.android;

  HttpClient _http() => _client()
    ..connectionTimeout = const Duration(seconds: 10)
    ..userAgent = 'PKArkTools/$kAppVersion';

  /// El último release, o `null` si no hay ninguno publicado.
  Future<ReleaseInfo?> latest() async {
    final http = _http();
    try {
      final req = await http.getUrl(_api);
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final res = await req.close().timeout(const Duration(seconds: 15));
      final body = await utf8.decodeStream(res).timeout(const Duration(seconds: 15));
      if (res.statusCode == 404) return null;
      if (res.statusCode != 200) throw UpdateException('http', '${res.statusCode}');
      final json = jsonDecode(body);
      if (json is! Map<String, Object?>) throw const UpdateException('format');
      return ReleaseInfo.fromGitHub(json, platform) ?? (throw const UpdateException('format'));
    } on UpdateException {
      rethrow;
    } on FormatException catch (e) {
      throw UpdateException('format', e.message);
    } on SocketException catch (e) {
      throw UpdateException('network', e.message);
    } on HandshakeException catch (e) {
      throw UpdateException('network', e.message);
    } on HttpException catch (e) {
      throw UpdateException('network', e.message);
    } on TimeoutException {
      throw const UpdateException('network', 'timeout');
    } finally {
      http.close(force: true);
    }
  }

  Future<Directory> _dir() async {
    final d = downloadDir ?? Directory(p.join(Directory.systemTemp.path, 'actualizaciones'));
    await d.create(recursive: true);
    return d;
  }

  /// Descarga el archivo de [release] (comprobando su tamaño) y devuelve la
  /// ruta. Borra antes las descargas anteriores. [cancel] la detiene.
  Future<File> download(ReleaseInfo release, {void Function(int received, int total)? onProgress, Future<void>? cancel}) async {
    final asset = release.asset ?? (throw const UpdateException('format', 'sin archivo para esta plataforma'));
    final dir = await _dir();
    await for (final e in dir.list()) {
      try {
        await e.delete(recursive: true);
      } catch (_) {}
    }
    final target = File(p.join(dir.path, asset.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')));
    final part = File('${target.path}.part');
    final http = _http();
    var cancelled = false;
    final finished = Completer<void>();
    StreamSubscription<List<int>>? sub;
    unawaited(cancel?.then((_) {
      cancelled = true;
      http.close(force: true);
      unawaited(sub?.cancel());
      if (!finished.isCompleted) finished.completeError(const UpdateException('aborted'));
    }));
    IOSink? sink;
    try {
      final req = await http.getUrl(asset.url);
      final res = await req.close().timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        await res.drain<void>().catchError((_) {});
        throw UpdateException('http', '${res.statusCode}');
      }
      final total = asset.size > 0 ? asset.size : res.contentLength;
      sink = part.openWrite();
      var received = 0;
      if (cancelled) throw const UpdateException('aborted');
      final out = sink;
      sub = res.timeout(const Duration(seconds: 30)).listen(
        (chunk) {
          out.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        },
        onError: (Object e) {
          if (!finished.isCompleted) finished.completeError(e);
        },
        onDone: () {
          if (!finished.isCompleted) finished.complete();
        },
        cancelOnError: true,
      );
      await finished.future;
      await sink.flush();
      await sink.close();
      sink = null;
      if (asset.size > 0 && received != asset.size) throw UpdateException('size', '$received ≠ ${asset.size}');
      return await part.rename(target.path);
    } on UpdateException {
      rethrow;
    } catch (e) {
      if (cancelled) throw const UpdateException('aborted');
      if (e is FileSystemException) throw UpdateException('storage', e.message);
      throw UpdateException('network', '$e');
    } finally {
      await sink?.close().catchError((_) {});
      if (await part.exists()) await part.delete().catchError((_) => part);
      http.close(force: true);
    }
  }

  /// Android: si la app puede pedir instalar paquetes (permiso «Instalar apps
  /// desconocidas» para PKArkTools).
  Future<bool> canRequestInstall() async => await _channel.invokeMethod<bool>('canInstall') ?? false;

  /// Android: abre el ajuste del sistema «Instalar apps desconocidas».
  Future<void> openInstallPermission() => _channel.invokeMethod<void>('openInstallPermission');

  /// Android: entrega [apk] al instalador del sistema. Si el usuario acepta,
  /// Android cierra la app y la reabre ya actualizada (no se vuelve de aquí);
  /// si cancela o falla, lanza [UpdateException].
  Future<void> install(File apk) async {
    try {
      await _channel.invokeMethod<void>('install', {'path': apk.path});
    } on PlatformException catch (e) {
      throw UpdateException(e.code, e.message);
    }
  }

  /// Escritorio: abre la página del release en el navegador.
  Future<bool> openPage(Uri url) async {
    if (kIsWeb) return false;
    final (cmd, args) = Platform.isMacOS
        ? ('open', [url.toString()])
        : Platform.isWindows
            ? ('rundll32', ['url.dll,FileProtocolHandler', url.toString()])
            : ('xdg-open', [url.toString()]);
    try {
      return (await Process.run(cmd, args)).exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
