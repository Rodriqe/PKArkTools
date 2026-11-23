import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'sprite_manifest.g.dart';
import 'sprites.dart';

/// Descarga un archivo; devuelve los bytes o lanza ([SpriteHttpStatusException]
/// si el servidor responde algo distinto de 200).
typedef SpriteFetcher = Future<Uint8List> Function(Uri url);

/// Respuesta HTTP distinta de 200.
class SpriteHttpStatusException implements Exception {
  const SpriteHttpStatusException(this.statusCode, this.url, {this.retryAfter});
  final int statusCode;
  final Uri url;

  /// Cabecera `Retry-After` (429/503), si la había.
  final Duration? retryAfter;

  /// 429 y 5xx son transitorios; 403/404 no mejoran reintentando.
  bool get transient => statusCode == 408 || statusCode == 429 || statusCode >= 500;

  @override
  String toString() => 'HTTP $statusCode ($url)';
}

/// Progreso de [SpriteCache.downloadAll]. [done]/[bytes] incluyen lo que ya
/// estaba en disco, así una descarga reanudada empieza donde se quedó.
class SpriteDownloadProgress {
  const SpriteDownloadProgress({required this.done, required this.total, required this.bytes, required this.totalBytes});
  final int done;
  final int total;
  final int bytes;
  final int totalBytes;
}

/// Resultado de [SpriteCache.downloadAll].
class SpriteDownloadResult {
  const SpriteDownloadResult({
    required this.total,
    required this.alreadyCached,
    required this.downloaded,
    required this.failed,
    required this.bytes,
    required this.cancelled,
    required this.offline,
    this.missing = 0,
  });

  final int total;

  /// Iconos que ya estaban en disco (descarga reanudada).
  final int alreadyCached;
  final int downloaded;
  final int failed;

  /// Bytes descargados en esta ejecución.
  final int bytes;
  final bool cancelled;

  /// Se abortó porque no hay red (o la app no tiene permiso de Internet):
  /// todos los intentos fallaron a nivel de conexión.
  final bool offline;

  /// Iconos que siguen sin estar bien guardados en disco al terminar
  /// (comprobado leyendo la caché, no contando respuestas).
  final int missing;

  bool get complete => !cancelled && !offline && failed == 0 && missing == 0;
}

/// Estado de la caché en disco según [SpriteCache.verify].
class SpriteCacheReport {
  const SpriteCacheReport({required this.total, required this.valid, required this.invalid});

  final int total;

  /// Iconos guardados y válidos (PNG completo con el tamaño del índice).
  final int valid;

  /// Archivos presentes pero inválidos (vacíos, truncados, no PNG): se borran.
  final int invalid;

  /// Iconos que faltan o hay que volver a descargar.
  int get missing => total - valid;
  bool get complete => missing == 0;
}

/// Caché de iconos: memoria → disco (directorio de caché de la app, nunca la
/// carpeta del Arca) → red (raw de GitHub con commit fijo; jsDelivr como
/// respaldo ante errores transitorios).
///
/// Sin conexión o si algo falla devuelve null y la interfaz usa su avatar de
/// iniciales. Los fallos se recuerdan durante un rato para no reintentar en
/// bucle, y si la red no responde en absoluto se deja de intentar enseguida.
class SpriteCache {
  SpriteCache({
    Future<Directory?> Function()? directory,
    SpriteFetcher? fetcher,
    this.maxFileBytes = 512 * 1024,
    this.maxCacheBytes = 64 * 1024 * 1024,
    this.retries = 2,
    this.retryDelay = const Duration(milliseconds: 300),
    this.enabled = true,
    this.mirrors = const [baseUrl, mirrorUrl],
    this.strictSizes = true,
  })  : _directory = directory ?? _defaultDirectory,
        _customFetcher = fetcher;

  /// Caché sin red ni disco (tests de widgets, o si el usuario desactiva los iconos).
  SpriteCache.disabled() : this(enabled: false);

  /// Instancia global (la usan los widgets de iconos).
  static SpriteCache instance = SpriteCache();

  final Future<Directory?> Function() _directory;
  final SpriteFetcher? _customFetcher;
  final int maxFileBytes;
  final int maxCacheBytes;

  /// Reintentos por archivo y origen, solo ante errores de red o HTTP 429/5xx.
  final int retries;

  /// Espera base entre reintentos (crece exponencialmente).
  final Duration retryDelay;
  final bool enabled;

  /// Exige que cada icono mida exactamente lo que dice el índice (el commit
  /// es fijo, así que cualquier diferencia es una respuesta truncada o ajena).
  /// Los tests con PNG de prueba lo desactivan.
  final bool strictSizes;

  /// Orígenes, en orden. El primero es el principal; los demás solo se usan
  /// si el anterior falla con un error transitorio.
  final List<String> mirrors;

  /// Origen principal. `{repo}` y `{commit}` se sustituyen por los del grupo
  /// del icono ([kSpriteSources], [kSpriteCommits]).
  static const String baseUrl = 'https://raw.githubusercontent.com/{repo}/{commit}/';

  /// jsDelivr sirve el mismo commit, pero los dos repositorios superan su
  /// límite de 50 MB y responde 403 a lo que no tenga ya en caché: solo respaldo.
  static const String mirrorUrl = 'https://cdn.jsdelivr.net/gh/{repo}@{commit}/';

  /// Versión de la caché en disco: cambia si cambia cualquiera de los commits.
  static final String cacheVersion = [for (final c in kSpriteCommits.values) c.substring(0, 7)].join('-');

  /// Descargas simultáneas por defecto (todas por el mismo [HttpClient]).
  static const int defaultConcurrency = 32;

  final _memory = <String, Uint8List>{};
  static const _memoryEntries = 400;
  final _inFlight = <String, Future<Uint8List?>>{};
  final _failedAt = <String, DateTime>{};
  static const _failureTtl = Duration(minutes: 2);
  Directory? _dir;
  bool _dirResolved = false;

  /// Tras detectar que no hay red, las cargas sueltas no lo intentan hasta entonces.
  DateTime? _offlineUntil;
  static const _offlineTtl = Duration(seconds: 30);
  int _consecutiveNetworkFailures = 0;
  static const _offlineAfterFailures = 6;

  /// Avisa a los widgets cuando cambia la caché (borrado, descarga completa).
  final ValueNotifier<int> generation = ValueNotifier(0);

  HttpClient? _client;

  static Future<Directory?> _defaultDirectory() async {
    final base = await getApplicationCacheDirectory();
    final root = Directory(p.join(base.path, 'sprites'));
    // Las cachés de commits anteriores ya no se usan: se borran en segundo plano.
    unawaited(() async {
      try {
        await for (final e in root.list()) {
          if (e is Directory && p.basename(e.path) != cacheVersion) await e.delete(recursive: true);
        }
      } catch (_) {}
    }());
    return Directory(p.join(root.path, cacheVersion));
  }

  /// Un único cliente con conexiones persistentes (keep-alive): cada archivo
  /// reutiliza una conexión TLS ya abierta en vez de negociar una nueva.
  HttpClient get _http => _client ??= HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..idleTimeout = const Duration(seconds: 20)
    ..maxConnectionsPerHost = defaultConcurrency
    ..userAgent = 'PKArkTools-sprites';

  Future<Uint8List> _fetch(Uri url) {
    final custom = _customFetcher;
    return custom != null ? custom(url) : _httpFetch(url);
  }

  Future<Uint8List> _httpFetch(Uri url) async {
    final req = await _http.getUrl(url);
    final res = await req.close().timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      await res.drain<void>().catchError((_) {});
      final ra = int.tryParse(res.headers.value(HttpHeaders.retryAfterHeader) ?? '');
      throw SpriteHttpStatusException(res.statusCode, url, retryAfter: ra == null ? null : Duration(seconds: ra));
    }
    final len = res.contentLength;
    if (len > maxFileBytes) {
      await res.drain<void>().catchError((_) {});
      throw SpriteHttpStatusException(413, url);
    }
    final b = BytesBuilder(copy: false);
    await for (final chunk in res.timeout(const Duration(seconds: 15))) {
      b.add(chunk);
      if (b.length > maxFileBytes) throw SpriteHttpStatusException(413, url);
    }
    return b.takeBytes();
  }

  /// Cierra las conexiones abiertas (se vuelven a abrir al necesitarlas).
  void closeConnections() {
    _client?.close(force: true);
    _client = null;
  }

  Future<Directory?> _cacheDir() async {
    if (_dirResolved) return _dir;
    try {
      final d = await _directory();
      if (d != null) await d.create(recursive: true);
      _dir = d;
    } catch (_) {
      _dir = null; // sin path_provider (tests) o sin permisos: solo memoria
    }
    _dirResolved = true;
    return _dir;
  }

  static Uri urlOf(SpriteRef ref, [String base = baseUrl]) {
    final (repo, dir) = kSpriteSources[ref.group]!;
    final root = base.replaceAll('{repo}', repo).replaceAll('{commit}', kSpriteCommits[repo]!);
    return Uri.parse(root + [...dir.split('/'), '${ref.name}.png'].map(Uri.encodeComponent).join('/'));
  }

  static String _fileName(SpriteRef ref) => '${ref.group}_${ref.name}.png';

  /// Bytes ya disponibles sin esperar (memoria), para pintar sin parpadeo.
  Uint8List? peek(SpriteRef ref) => _memory[ref.key];

  /// Si hace poco se comprobó que no hay red.
  bool get isOffline {
    final until = _offlineUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// Bytes PNG del icono, o null si no se pudo obtener.
  Future<Uint8List?> load(SpriteRef ref) {
    if (!enabled) return Future.value(null);
    final hit = _memory[ref.key];
    if (hit != null) return Future.value(hit);
    final failed = _failedAt[ref.key];
    if (failed != null && DateTime.now().difference(failed) < _failureTtl) return Future.value(null);
    return _inFlight.putIfAbsent(ref.key, () {
      // Ojo: el callback no debe devolver el Future quitado (se esperaría a sí mismo).
      return _load(ref).whenComplete(() {
        _inFlight.remove(ref.key);
      });
    });
  }

  Future<Uint8List?> _load(SpriteRef ref) async {
    final dir = await _cacheDir();
    final file = dir == null ? null : File(p.join(dir.path, _fileName(ref)));
    try {
      if (file != null && await file.exists()) {
        final b = await file.readAsBytes();
        if (_isValid(ref, b)) return _remember(ref, b);
        await file.delete(); // vacío, truncado o ajeno: se vuelve a descargar
      }
    } catch (_) {
      // Archivo de caché ilegible: se vuelve a descargar.
    }
    if (isOffline) return null; // sin red: el avatar de iniciales, sin esperar
    final bytes = (await _download(ref)).bytes;
    if (bytes == null) {
      _failedAt[ref.key] = DateTime.now();
      return null;
    }
    await _write(file, bytes);
    return _remember(ref, bytes);
  }

  static final _rnd = math.Random();

  /// Escribe a un temporal con nombre único y lo renombra: un corte nunca deja
  /// un PNG a medias con el nombre definitivo, y dos escrituras simultáneas no
  /// se pisan el temporal. Comprueba el tamaño final; devuelve `false` si no
  /// quedó bien guardado (disco lleno, sin permisos). Sin `flush` (fsync) por
  /// archivo: son miles de archivos pequeños y [verify] detecta lo que falte.
  static Future<bool> _write(File? file, Uint8List bytes) async {
    if (file == null) return true; // sin disco: solo memoria, no es un fallo
    final tmp = File('${file.path}.${_rnd.nextInt(1 << 32).toRadixString(16)}.part');
    try {
      await tmp.writeAsBytes(bytes);
      await tmp.rename(file.path);
      return await file.length() == bytes.length;
    } catch (_) {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      return false;
    }
  }

  static bool _isNetworkError(Object e) =>
      e is SocketException || e is TlsException || e is TimeoutException || e is HttpException || e is OSError;

  void _noteSuccess() {
    _consecutiveNetworkFailures = 0;
    _offlineUntil = null;
  }

  void _noteNetworkFailure() {
    if (++_consecutiveNetworkFailures >= _offlineAfterFailures) _offlineUntil = DateTime.now().add(_offlineTtl);
  }

  /// Descarga con reintentos (backoff exponencial) solo ante errores de red o
  /// HTTP transitorios, probando los orígenes en orden. [abort] corta la espera.
  ///
  /// Si todos los intentos fallan sin que ningún servidor responda, cuenta
  /// como fallo de red; varios seguidos activan [isOffline].
  ///
  /// `permanent` indica que reintentar más tarde no lo arreglará (404, una
  /// respuesta que no es un PNG): [downloadAll] no lo repite en su segunda pasada.
  Future<({Uint8List? bytes, bool permanent})> _download(SpriteRef ref, {bool Function()? abort}) async {
    var networkOnly = true;
    var permanent = true;
    try {
      for (final base in mirrors) {
        var transient = false;
        for (var attempt = 0; attempt <= retries; attempt++) {
          if ((abort?.call() ?? false) || isOffline) return (bytes: null, permanent: false);
          Duration? wait;
          try {
            final b = await _fetch(urlOf(ref, base));
            networkOnly = false;
            _noteSuccess();
            if (_isValid(ref, b)) return (bytes: b, permanent: false);
            // Un PNG truncado o de otro tamaño es un corte de la conexión: se
            // reintenta. Una página de error (HTML, JSON) no mejora reintentando.
            if (b.length > maxFileBytes || !_hasPngSignature(b)) return (bytes: null, permanent: true);
            transient = true;
          } on SpriteHttpStatusException catch (e) {
            networkOnly = false;
            _noteSuccess(); // el servidor respondió: hay red
            if (!e.transient) break; // 403/404: este origen no lo tiene
            transient = true;
            wait = e.retryAfter;
          } catch (e) {
            if (!_isNetworkError(e)) {
              networkOnly = false;
              return (bytes: null, permanent: true);
            }
            transient = true;
          }
          if (attempt < retries) {
            final backoff = retryDelay * math.pow(2, attempt).toInt();
            final d = wait == null ? backoff : (wait > const Duration(seconds: 5) ? const Duration(seconds: 5) : wait);
            await Future<void>.delayed(d);
          }
        }
        if (!transient) return (bytes: null, permanent: permanent); // otro origen no arregla un 404
        permanent = false;
      }
      return (bytes: null, permanent: false);
    } finally {
      if (networkOnly && !(abort?.call() ?? false)) _noteNetworkFailure();
    }
  }

  Uint8List _remember(SpriteRef ref, Uint8List b) {
    _memory[ref.key] = b;
    while (_memory.length > _memoryEntries) {
      _memory.remove(_memory.keys.first);
    }
    return b;
  }

  static const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  static const _iendChunk = [0, 0, 0, 0, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82];

  static bool _hasPngSignature(Uint8List b) {
    if (b.length < 8) return false;
    for (var i = 0; i < 8; i++) {
      if (b[i] != _pngSignature[i]) return false;
    }
    return true;
  }

  /// PNG completo: firma, cabecera IHDR al principio y bloque IEND al final
  /// (un archivo vacío, cortado a mitad o una página de error no lo cumplen).
  static bool isCompletePng(Uint8List b) {
    if (b.length < 8 + 25 + 12 || !_hasPngSignature(b)) return false;
    if (b[12] != 0x49 || b[13] != 0x48 || b[14] != 0x44 || b[15] != 0x52) return false; // IHDR
    final o = b.length - 12;
    for (var i = 0; i < 12; i++) {
      if (b[o + i] != _iendChunk[i]) return false;
    }
    return true;
  }

  /// Bytes aceptables para [ref]: PNG completo y, con [strictSizes], del
  /// tamaño exacto que registra el índice para el commit fijo.
  bool _isValid(SpriteRef ref, Uint8List b) {
    if (b.length > maxFileBytes || !isCompletePng(b)) return false;
    final expected = _sizes[ref];
    return !strictSizes || expected == null || expected == b.length;
  }

  /// Tamaño actual de la caché en disco.
  Future<int> diskBytes() async {
    final dir = await _cacheDir();
    if (dir == null || !await dir.exists()) return 0;
    var total = 0;
    await for (final e in dir.list()) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  /// Borra la caché (memoria y disco).
  Future<void> clear() async {
    _memory.clear();
    _failedAt.clear();
    _invalidated.clear();
    final dir = await _cacheDir();
    if (dir != null && await dir.exists()) {
      await for (final e in dir.list()) {
        try {
          await e.delete(recursive: true);
        } catch (_) {}
      }
    }
    generation.value++;
  }

  /// Todos los iconos del índice con su tamaño.
  static final Map<SpriteRef, int> _sizes = {
    for (final g in kSpriteFiles.keys)
      for (final e in kSpriteFiles[g]!.split(','))
        SpriteRef(g, e.substring(0, e.lastIndexOf(':'))): int.parse(e.substring(e.lastIndexOf(':') + 1)),
  };

  /// Todos los iconos del índice.
  static List<SpriteRef> allRefs() => _sizes.keys.toList();

  /// Iconos de las especies de un equipo (`ArcaRepository.decodeParty`), para
  /// descargarlos antes que el resto (sin repetidos; los variocolor usan el
  /// mismo icono con insignia).
  static List<SpriteRef> refsForParty(Iterable<({int species, int form, bool shiny, bool egg})> party) => {
        for (final m in party) ?Sprites.pokemon(m.species, form: m.form, egg: m.egg),
      }.toList();

  /// Comprueba la caché en disco sin red: cuántos iconos del índice están
  /// guardados y son válidos. Borra los archivos inválidos (vacíos, truncados,
  /// de otro tamaño) y los temporales que no pertenezcan a una escritura en
  /// curso, para que [downloadAll] / [repair] los vuelvan a pedir.
  Future<SpriteCacheReport> verify() async => (await _scan()).report;

  Future<({SpriteCacheReport report, Set<SpriteRef> valid})> _scan() async {
    final dir = await _cacheDir();
    final valid = <SpriteRef>{};
    var invalid = 0;
    if (dir != null) {
      final byName = {for (final r in _sizes.keys) _fileName(r): r};
      final writing = {for (final k in _inFlight.keys) k.replaceFirst('/', '_')};
      try {
        await for (final e in dir.list()) {
          if (e is! File) continue;
          final name = p.basename(e.path);
          if (name.endsWith('.part')) {
            // Restos de una descarga cortada (pero no los de una escritura en curso).
            final png = name.indexOf('.png.');
            final owner = png < 0 ? '' : name.substring(0, png);
            if (!writing.contains(owner)) await e.delete().catchError((_) => e);
            continue;
          }
          final ref = byName[name];
          if (ref == null) continue;
          Uint8List? b;
          try {
            b = await e.readAsBytes();
          } catch (_) {}
          if (b != null && _isValid(ref, b)) {
            valid.add(ref);
          } else {
            invalid++;
            _memory.remove(ref.key);
            await e.delete().catchError((_) => e);
          }
        }
      } catch (_) {}
    } else {
      valid.addAll(_sizes.keys.where((r) => _memory.containsKey(r.key))); // solo memoria
    }
    return (report: SpriteCacheReport(total: _sizes.length, valid: valid.length, invalid: invalid), valid: valid);
  }

  final _invalidated = <String>{};

  /// La interfaz no pudo decodificar los bytes de [ref]: se olvidan (memoria
  /// y disco) para volver a descargarlos. Una sola vez por icono y sesión,
  /// para no entrar en bucle con un archivo que el servidor sirva mal.
  Future<bool> invalidate(SpriteRef ref) async {
    if (!_invalidated.add(ref.key)) return false;
    _memory.remove(ref.key);
    _failedAt.remove(ref.key);
    final dir = await _cacheDir();
    if (dir != null) {
      final f = File(p.join(dir.path, _fileName(ref)));
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    return true;
  }

  /// Vuelve a descargar solo los iconos que faltan o están dañados en disco
  /// (lo comprueba [verify] antes); el resultado dice cuántos siguen faltando.
  Future<SpriteDownloadResult> repair({
    Iterable<SpriteRef> priority = const [],
    void Function(SpriteDownloadProgress progress)? onProgress,
    bool Function()? cancel,
    int concurrency = defaultConcurrency,
  }) {
    _failedAt.clear();
    _invalidated.clear();
    return downloadAll(priority: priority, onProgress: onProgress, cancel: cancel, concurrency: concurrency);
  }

  /// Descarga todos los iconos que falten, primero los de [priority] (lo que
  /// el usuario tiene a la vista) y luego el resto, con [concurrency]
  /// descargas simultáneas por un único cliente HTTP.
  ///
  /// Es reanudable: lo que ya está bien guardado en disco no se vuelve a
  /// pedir, y lo que está dañado se borra y se pide de nuevo. Los fallos
  /// transitorios (429, 5xx, cortes) se reintentan en una segunda pasada más
  /// lenta. Al terminar se vuelve a comprobar el disco: [SpriteDownloadResult.missing]
  /// cuenta lo que de verdad falta y solo sin faltas es [SpriteDownloadResult.complete].
  /// Se puede cancelar con [cancel]. Si no hay red (o la app no tiene permiso
  /// de Internet) se aborta enseguida con [SpriteDownloadResult.offline].
  Future<SpriteDownloadResult> downloadAll({
    Iterable<SpriteRef> priority = const [],
    void Function(SpriteDownloadProgress progress)? onProgress,
    bool Function()? cancel,
    int concurrency = defaultConcurrency,
  }) async {
    final ordered = <SpriteRef>{...priority.where(_sizes.containsKey), ..._sizes.keys};
    final dir = await _cacheDir();
    final workers = math.max(1, concurrency);
    if (_customFetcher == null) _http.maxConnectionsPerHost = math.max(_http.maxConnectionsPerHost ?? 0, workers);
    final onDisk = dir == null ? <SpriteRef>{} : (await _scan()).valid;
    final total = ordered.length;
    final totalBytes = _sizes.values.fold(0, (a, b) => a + b);
    var done = 0, cachedBytes = 0;
    final queue = Queue<SpriteRef>();
    for (final ref in ordered) {
      if (onDisk.contains(ref)) {
        done++;
        cachedBytes += _sizes[ref]!;
      } else {
        queue.add(ref);
      }
    }
    final alreadyCached = done;
    var downloaded = 0, bytes = 0;
    final failedRefs = <SpriteRef>[];
    final retryLater = Queue<SpriteRef>();
    var offline = false, cancelled = false;
    _consecutiveNetworkFailures = 0;
    _offlineUntil = null;

    bool stop() {
      if (cancel?.call() ?? false) cancelled = true;
      // Sin ninguna respuesta del servidor y con varios fallos de conexión
      // seguidos: no hay red. Se corta ya en vez de reintentar miles de archivos.
      if (isOffline) offline = true;
      return cancelled || offline;
    }

    void report() =>
        onProgress?.call(SpriteDownloadProgress(done: done, total: total, bytes: cachedBytes + bytes, totalBytes: totalBytes));

    report();

    Future<void> worker(Queue<SpriteRef> q, {required bool lastPass}) async {
      while (q.isNotEmpty && !stop()) {
        final ref = q.removeFirst();
        _failedAt.remove(ref.key);
        final file = dir == null ? null : File(p.join(dir.path, _fileName(ref)));
        final pending = _inFlight[ref.key];
        Uint8List? b;
        var permanent = false;
        final mem = _memory[ref.key];
        if (pending == null && mem != null && file != null && await file.exists() && await file.length() == mem.length) {
          b = mem; // un widget lo cargó y guardó mientras tanto: no se pide otra vez
        } else if (pending != null) {
          b = await pending; // un widget ya lo está pidiendo (y lo escribe)
          if (b != null && file != null && !await file.exists() && !await _write(file, b)) b = null;
        } else {
          final f = _download(ref, abort: stop).then((r) async {
            permanent = r.permanent;
            final got = r.bytes;
            if (got == null) return null;
            if (!await _write(file, got)) return null; // no quedó guardado: no cuenta
            return got; // sin pasar por memoria: no desplaza lo que está a la vista
          });
          _inFlight[ref.key] = f;
          b = await f.whenComplete(() {
            _inFlight.remove(ref.key);
          });
        }
        if (b == null) {
          if (stop()) break; // no cuenta como fallo: se reintentará al reanudar
          if (!lastPass && !permanent) {
            retryLater.add(ref); // 429/5xx/corte: segunda pasada más lenta
            continue;
          }
          failedRefs.add(ref);
          _failedAt[ref.key] = DateTime.now();
        } else {
          downloaded++;
          bytes += b.length;
        }
        done++;
        report();
      }
    }

    await Future.wait([for (var i = 0; i < workers; i++) worker(queue, lastPass: false)]);
    if (retryLater.isNotEmpty && !stop()) {
      // Segunda pasada: menos conexiones a la vez y más paciencia.
      await Future<void>.delayed(retryDelay * 4);
      await Future.wait([for (var i = 0; i < math.min(4, workers); i++) worker(retryLater, lastPass: true)]);
    }
    await _enforceLimit();
    final after = dir == null ? null : await verify();
    generation.value++;
    return SpriteDownloadResult(
      total: total,
      alreadyCached: alreadyCached,
      downloaded: downloaded,
      failed: failedRefs.length,
      bytes: bytes,
      cancelled: cancelled,
      offline: offline,
      missing: after?.missing ?? 0,
    );
  }

  /// Si la caché supera el límite, borra los archivos más antiguos.
  Future<void> _enforceLimit() async {
    final dir = await _cacheDir();
    if (dir == null || !await dir.exists()) return;
    final files = <(File, int, DateTime)>[];
    var total = 0;
    await for (final e in dir.list()) {
      if (e is File && !e.path.endsWith('.part')) {
        final st = await e.stat();
        files.add((e, st.size, st.modified));
        total += st.size;
      }
    }
    if (total <= maxCacheBytes) return;
    files.sort((a, b) => a.$3.compareTo(b.$3));
    for (final (f, size, _) in files) {
      if (total <= maxCacheBytes) break;
      try {
        await f.delete();
        total -= size;
      } catch (_) {}
    }
  }
}
