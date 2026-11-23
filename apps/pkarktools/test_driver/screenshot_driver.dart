import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Guarda las capturas del dispositivo (`binding.takeScreenshot`) en
/// `docs/screenshots/`. El nombre puede llevar subcarpeta:
/// `ios/se_01_arca` → `docs/screenshots/ios/se_01_arca.png` (o `$SHOTS_OUT/…`).
Future<void> main() => integrationDriver(
      onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
        // SHOTS_OUT (entorno del driver) cambia el destino, p. ej. un kit fuera del repo.
        final out = Platform.environment['SHOTS_OUT'] ?? '../../docs/screenshots';
        final f = File('$out/$name.png')..parent.createSync(recursive: true);
        f.writeAsBytesSync(bytes);
        stdout.writeln('captura: ${f.path}');
        return true;
      },
    );
