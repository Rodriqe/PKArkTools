import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// GET anónimo de un archivo de datos del repositorio (formato oficial,
/// eventos): sin cabeceras propias ni identificadores (ni siquiera la versión
/// de la app en el User-Agent), sin seguir redirecciones y con un tamaño
/// máximo. Lanza [HttpException], [SocketException] o [TimeoutException].
Future<String> anonymousGet(Uri url, {required int maxBytes, Duration timeout = const Duration(seconds: 10)}) async {
  final http = HttpClient()
    ..connectionTimeout = timeout
    ..userAgent = null;
  try {
    final req = await http.getUrl(url).timeout(timeout);
    req.followRedirects = false;
    final res = await req.close().timeout(timeout);
    if (res.statusCode != HttpStatus.ok) {
      await res.drain<void>();
      throw HttpException('HTTP ${res.statusCode}', uri: url);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in res.timeout(timeout)) {
      bytes.add(chunk);
      if (bytes.length > maxBytes) throw HttpException('too large', uri: url);
    }
    return utf8.decode(bytes.takeBytes());
  } finally {
    http.close(force: true);
  }
}
