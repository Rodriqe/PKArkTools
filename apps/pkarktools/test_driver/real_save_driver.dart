import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Guarda las capturas de `integration_test/real_save_screenshots_test.dart` en
/// `.scratch/screenshots/` (fuera del control de versiones: pueden mostrar
/// datos personales del dueño del save). Si `REAL_SAVE_PATH` está definido,
/// envía ese archivo a la prueba por HTTP local (saves demasiado grandes para
/// `--dart-define`).
Future<void> main() async {
  final path = Platform.environment['REAL_SAVE_PATH'];
  if (path != null) unawaited(_sendSave(File(path)));
  await integrationDriver(
    responseDataCallback: (data) async {
      if (data == null) return;
      final dir = Directory('../../.scratch/screenshots')..createSync(recursive: true);
      for (final MapEntry(:key, :value) in data.entries) {
        File('${dir.path}/$key.png').writeAsBytesSync(base64Decode(value as String));
        stdout.writeln('captura: .scratch/screenshots/$key.png');
      }
    },
  );
}

/// Reintenta el envío hasta que la prueba abra el puerto (la app tarda en arrancar).
Future<void> _sendSave(File file) async {
  final bytes = file.readAsBytesSync();
  final client = HttpClient();
  for (var i = 0; i < 360; i++) {
    try {
      final req = await client.post('127.0.0.1', 47321, '/');
      req.add(bytes);
      final res = await req.close();
      await res.drain<void>();
      stdout.writeln('save enviado (${bytes.length} bytes): HTTP ${res.statusCode}');
      client.close();
      return;
    } on SocketException {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }
  client.close();
  stderr.writeln('no se pudo enviar el save a la prueba');
}
