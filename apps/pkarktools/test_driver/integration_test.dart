import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Recibe las capturas tomadas dentro de la app (base64) y las guarda en
/// `docs/screenshots/` en la raíz del repositorio.
Future<void> main() => integrationDriver(
      responseDataCallback: (data) async {
        if (data == null) return;
        final dir = Directory('../../docs/screenshots')..createSync(recursive: true);
        for (final MapEntry(:key, :value) in data.entries) {
          File('${dir.path}/$key.png').writeAsBytesSync(base64Decode(value as String));
          stdout.writeln('captura: docs/screenshots/$key.png');
        }
      },
    );
