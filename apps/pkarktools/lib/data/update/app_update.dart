import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// La versión instalada. Solo las pruebas la cambian (para simular una
  /// versión anterior frente al release publicado).
  static AppVersion current = tryParse(kAppVersion)!;

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

/// Plataformas con descarga propia en los releases (iOS solo abre la página).
enum UpdatePlatform { android, macos, windows, linux, ios, other }

UpdatePlatform get currentUpdatePlatform {
  if (kIsWeb) return UpdatePlatform.other;
  if (Platform.isAndroid) return UpdatePlatform.android;
  if (Platform.isMacOS) return UpdatePlatform.macos;
  if (Platform.isWindows) return UpdatePlatform.windows;
  if (Platform.isLinux) return UpdatePlatform.linux;
  if (Platform.isIOS) return UpdatePlatform.ios;
  return UpdatePlatform.other;
}

/// Solo se descarga del repositorio de PKArkTools, por HTTPS y desde los
/// dominios de GitHub (`github.com` redirige a `*.githubusercontent.com`).
bool isTrustedDownload(Uri url) {
  if (url.scheme != 'https' || url.hasPort && url.port != 443) return false;
  final host = url.host.toLowerCase();
  if (host == 'github.com') return url.path.startsWith('/${AppUpdater.repo}/releases/download/');
  return host == 'objects.githubusercontent.com' || host == 'release-assets.githubusercontent.com';
}

/// La página de un release solo se abre si es de este repositorio.
bool isTrustedPage(Uri url) =>
    url.scheme == 'https' && url.host.toLowerCase() == 'github.com' && url.path.startsWith('/${AppUpdater.repo}/releases');

/// Firma de un paquete Android: nombre y huellas SHA-256 de sus certificados.
@immutable
class ApkSignature {
  const ApkSignature(this.package, this.certificates);
  final String package;
  final Set<String> certificates;

  static ApkSignature? fromChannel(Object? m) {
    if (m is! Map) return null;
    final pkg = m['package'], certs = m['certificates'];
    if (pkg is! String || certs is! List) return null;
    return ApkSignature(pkg, {for (final c in certs) '$c'.toLowerCase()});
  }
}

/// Dónde guarda el comprobador lo suyo (ETag, última respuesta, fecha de la
/// última consulta, versión omitida y si busca solo). En la app es la tabla de
/// ajustes del índice local; en los tests, memoria.
abstract class UpdateStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class MemoryUpdateStore implements UpdateStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
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
      UpdatePlatform.ios || UpdatePlatform.other => (_) => false,
    };
    final html = json['html_url'] is String ? Uri.tryParse(json['html_url'] as String) : null;
    final page = html != null && isTrustedPage(html) ? html : Uri.parse('https://github.com/${AppUpdater.repo}/releases/tag/$tag');
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

  /// `network`, `http`, `rate`, `format`, `size`, `untrusted`, `signature`,
  /// `permission`, `conflict`, `incompatible`, `storage`, `aborted`, `install`.
  final String code;
  final String? detail;

  @override
  String toString() => 'UpdateException($code${detail == null ? '' : ': $detail'})';
}

/// Busca la última versión en GitHub Releases (con ETag y caché para no gastar
/// el límite de 60 consultas por hora de la API sin token) y descarga el
/// archivo de esta plataforma. En Android comprueba que el APK está firmado
/// con el mismo certificado que la app instalada y lo entrega al instalador
/// del sistema, que pide una confirmación; los datos se conservan porque es
/// una actualización. En escritorio el archivo se guarda donde diga el usuario
/// y en iOS solo se abre la página del release.
class AppUpdater {
  AppUpdater({
    HttpClient Function()? client,
    Uri? api,
    this.platform = UpdatePlatform.other,
    this.downloadDir,
    UpdateStore? store,
    DateTime Function()? now,
    bool Function(Uri)? trusted,
  })  : _client = client ?? HttpClient.new,
        _api = api ?? Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
        store = store ?? MemoryUpdateStore(),
        _now = now ?? DateTime.now,
        _trusted = trusted ?? isTrustedDownload;

  factory AppUpdater.forCurrentPlatform({UpdateStore? store}) => AppUpdater(platform: currentUpdatePlatform, store: store);

  static const repo = 'Rodriqe/PKArkTools';
  static const releasesPage = 'https://github.com/$repo/releases/latest';

  /// Como mucho una consulta automática por periodo.
  static const autoInterval = Duration(hours: 24);

  static const _channel = MethodChannel('dev.pkarktools/update');
  static const kEtag = 'update.etag', kBody = 'update.body', kChecked = 'update.checkedAt';
  static const kSkipped = 'update.skipped', kAuto = 'update.auto';

  final HttpClient Function() _client;
  final Uri _api;
  final UpdatePlatform platform;
  final UpdateStore store;
  final DateTime Function() _now;
  final bool Function(Uri) _trusted;

  /// Carpeta temporal de las descargas (por defecto, la caché de la app).
  final Directory? downloadDir;

  /// Android: se descarga e instala desde la app.
  bool get canInstallInApp => platform == UpdatePlatform.android;

  /// Escritorio: se descarga el archivo y el usuario lo instala a mano.
  bool get canDownload => const {UpdatePlatform.macos, UpdatePlatform.windows, UpdatePlatform.linux}.contains(platform);

  HttpClient _http() => _client()
    ..connectionTimeout = const Duration(seconds: 10)
    ..userAgent = 'PKArkTools/$kAppVersion';

  // ------------------------------------------------------------ preferencias

  /// «Buscar actualizaciones automáticamente» (activado por defecto).
  Future<bool> autoCheckEnabled() async => await store.read(kAuto) != 'false';
  Future<void> setAutoCheck(bool on) => store.write(kAuto, '$on');

  /// Versión que el usuario pidió omitir (no vuelve a avisar de ella).
  Future<AppVersion?> skippedVersion() async => AppVersion.tryParse(await store.read(kSkipped) ?? '');
  Future<void> skip(AppVersion v) => store.write(kSkipped, '$v');

  Future<DateTime?> lastChecked() async => DateTime.tryParse(await store.read(kChecked) ?? '');

  /// El release de la última respuesta guardada (sin red).
  Future<ReleaseInfo?> cached() async {
    final body = await store.read(kBody);
    if (body == null || body.isEmpty) return null;
    try {
      final json = jsonDecode(body);
      return json is Map<String, Object?> ? ReleaseInfo.fromGitHub(json, platform) : null;
    } on FormatException {
      return null;
    }
  }

  // ---------------------------------------------------------------- consulta

  /// El último release, o `null` si no hay ninguno publicado. Manda el ETag
  /// de la respuesta anterior: si no ha cambiado, GitHub contesta 304 (que no
  /// cuenta para el límite) y se usa la guardada.
  Future<ReleaseInfo?> latest() async {
    final http = _http();
    try {
      final etag = await store.read(kEtag);
      final hasBody = (await store.read(kBody))?.isNotEmpty ?? false;
      final req = await http.getUrl(_api);
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      req.headers.set('X-GitHub-Api-Version', '2022-11-28');
      if (etag != null && etag.isNotEmpty && hasBody) req.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
      final res = await req.close().timeout(const Duration(seconds: 15));
      final body = await utf8.decodeStream(res).timeout(const Duration(seconds: 15));
      switch (res.statusCode) {
        case 304:
          await store.write(kChecked, _now().toUtc().toIso8601String());
          return await cached() ?? (throw const UpdateException('format', 'caché vacía'));
        case 404:
          await store.write(kBody, '');
          await store.write(kEtag, '');
          await store.write(kChecked, _now().toUtc().toIso8601String());
          return null;
        case 403 || 429:
          throw UpdateException('rate', '${res.statusCode}');
        case 200:
          break;
        default:
          throw UpdateException('http', '${res.statusCode}');
      }
      final json = jsonDecode(body);
      if (json is! Map<String, Object?>) throw const UpdateException('format');
      final release = ReleaseInfo.fromGitHub(json, platform) ?? (throw const UpdateException('format'));
      await store.write(kBody, body);
      await store.write(kEtag, res.headers.value(HttpHeaders.etagHeader) ?? '');
      await store.write(kChecked, _now().toUtc().toIso8601String());
      return release;
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

  /// Chequeo al abrir la app: si está activado, consulta GitHub como mucho
  /// una vez cada [autoInterval] (si no, usa la respuesta guardada) y nunca
  /// falla. Devuelve el release solo si es más nuevo y no se ha omitido.
  Future<ReleaseInfo?> autoCheck() async {
    try {
      if (!await autoCheckEnabled()) return null;
      final last = await lastChecked();
      final now = _now();
      ReleaseInfo? r;
      if (last != null && now.difference(last) < autoInterval && !now.isBefore(last)) {
        r = await cached();
      } else {
        try {
          r = await latest();
        } on UpdateException {
          r = await cached();
        }
      }
      return await offer(r);
    } catch (_) {
      return null;
    }
  }

  /// [r] si merece aviso: más nuevo que la instalada y no omitido.
  Future<ReleaseInfo?> offer(ReleaseInfo? r) async {
    if (r == null || !r.isNewer) return null;
    return await skippedVersion() == r.version ? null : r;
  }

  // ---------------------------------------------------------------- descarga

  Future<Directory> _dir() async {
    final d = downloadDir ?? Directory(p.join(Directory.systemTemp.path, 'actualizaciones'));
    await d.create(recursive: true);
    return d;
  }

  /// Borra lo que quedara en la carpeta de descargas (tras instalar, Android
  /// cierra la app antes de que pueda hacerlo).
  Future<void> cleanDownloads() async {
    final d = downloadDir ?? Directory(p.join(Directory.systemTemp.path, 'actualizaciones'));
    try {
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }

  /// Abre [url] siguiendo a mano las redirecciones, para comprobar que cada
  /// salto sigue siendo HTTPS hacia GitHub.
  Future<HttpClientResponse> _get(HttpClient http, Uri url) async {
    for (var hops = 0; hops < 6; hops++) {
      if (!_trusted(url)) throw UpdateException('untrusted', '$url');
      final req = await http.getUrl(url);
      req.followRedirects = false;
      req.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');
      final res = await req.close().timeout(const Duration(seconds: 30));
      if (!res.isRedirect) return res;
      final loc = res.headers.value(HttpHeaders.locationHeader);
      await res.drain<void>().catchError((_) {});
      if (loc == null) throw const UpdateException('http', 'redirección sin destino');
      url = url.resolve(loc);
    }
    throw const UpdateException('http', 'demasiadas redirecciones');
  }

  /// Descarga el archivo de [release] (comprobando su tamaño) a la carpeta
  /// temporal y devuelve la ruta. Borra antes las descargas anteriores.
  /// [cancel] la detiene; nada queda a medias.
  Future<File> download(ReleaseInfo release, {void Function(int received, int total)? onProgress, Future<void>? cancel}) async {
    final asset = release.asset ?? (throw const UpdateException('format', 'sin archivo para esta plataforma'));
    if (!_trusted(asset.url)) throw UpdateException('untrusted', '${asset.url}');
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
      final res = await _get(http, asset.url);
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
          received += chunk.length;
          // Más de lo anunciado: no es el archivo del release.
          if (asset.size > 0 && received > asset.size) {
            if (!finished.isCompleted) finished.completeError(UpdateException('size', '> ${asset.size}'));
            unawaited(sub?.cancel());
            return;
          }
          out.add(chunk);
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
    } on UpdateException catch (e) {
      if (cancelled && e.code != 'aborted') throw const UpdateException('aborted');
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

  // ------------------------------------------------------------ escritorio

  /// Escritorio: guarda [file] donde elija el usuario (diálogo «Guardar como»
  /// que empieza en Descargas); si no hay diálogo, en Descargas. Devuelve la
  /// ruta final o `null` si el usuario cancela. Borra [file].
  Future<String?> saveDownload(File file, String name) async {
    try {
      String? dir;
      try {
        dir = (await getDownloadsDirectory())?.path;
      } catch (_) {}
      Uri? uri;
      var dialog = true;
      try {
        uri = await FilePicker.saveFile(
            dialogTitle: name, fileName: name, initialDirectory: dir, bytes: await file.readAsBytes());
      } on PlatformException {
        dialog = false;
      } on UnimplementedError {
        dialog = false;
      }
      if (dialog) {
        if (uri == null) return null;
        return uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
      }
      if (dir == null) throw const UpdateException('storage', 'sin carpeta de descargas');
      final out = p.join(dir, name);
      await file.copy(out);
      return out;
    } on FileSystemException catch (e) {
      throw UpdateException('storage', e.message);
    } finally {
      await file.delete().catchError((_) => file);
    }
  }

  /// Borra una descarga (el APK, tras instalar o al cancelar).
  Future<void> deleteDownload(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Escritorio: muestra la carpeta que contiene [path].
  Future<bool> reveal(String path) => _launch(Uri.directory(p.dirname(path)));

  // ----------------------------------------------------------------- Android

  /// Android: si la app puede pedir instalar paquetes (permiso «Instalar apps
  /// desconocidas» para PKArkTools).
  Future<bool> canRequestInstall() async => await _channel.invokeMethod<bool>('canInstall') ?? false;

  /// Android: abre el ajuste del sistema «Instalar apps desconocidas».
  Future<void> openInstallPermission() => _channel.invokeMethod<void>('openInstallPermission');

  /// Android: firma de la app instalada.
  Future<ApkSignature?> installedSignature() async => ApkSignature.fromChannel(await _channel.invokeMethod<Object?>('installedSignature'));

  /// Android: firma del APK en [apk] (null si no se puede leer).
  Future<ApkSignature?> apkSignature(File apk) async =>
      ApkSignature.fromChannel(await _channel.invokeMethod<Object?>('apkSignature', {'path': apk.path}));

  /// Comprueba que [apk] es PKArkTools firmado con la misma clave que la app
  /// instalada. Si no, lanza `signature` y no se instala.
  Future<void> verify(File apk) async {
    final ApkSignature? mine, theirs;
    try {
      mine = await installedSignature();
      theirs = await apkSignature(apk);
    } on PlatformException catch (e) {
      throw UpdateException('signature', e.message);
    }
    if (mine == null || mine.certificates.isEmpty) throw const UpdateException('signature', 'instalada sin firma');
    if (theirs == null || theirs.certificates.isEmpty) throw const UpdateException('signature', 'APK sin firma o dañado');
    if (theirs.package != mine.package) throw UpdateException('signature', 'paquete ${theirs.package}');
    Set<String> norm(Set<String> c) => {for (final x in c) x.toLowerCase()};
    if (!setEquals(norm(theirs.certificates), norm(mine.certificates))) throw const UpdateException('signature', 'otro certificado');
  }

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

  // ------------------------------------------------------------------ página

  /// Abre la página del release en el navegador (solo páginas del repo).
  Future<bool> openPage(Uri url) => isTrustedPage(url) ? _launch(url) : Future.value(false);

  Future<bool> _launch(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
