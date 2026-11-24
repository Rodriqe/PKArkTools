// Tarjeta de partida del Arca: no se desborda en una ventana de 1000×700
// con las fuentes reales de la app y los Material Icons cargados (con el
// glifo real, el icono de la fila sin equipo y las líneas de texto suman unos
// píxeles más que con la fuente de prueba: antes se desbordaba ~4,3 px).
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/ui/arca/save_card.dart';

import 'arca_folder_test.dart' show memoryDb;
import 'arca_screen_test.dart' show settle;
import 'phone_layout_test.dart' show loadAppFonts;

Future<void> _loadMaterialIcons() async {
  final root = io.Platform.environment['FLUTTER_ROOT'] ??
      p.dirname(p.dirname(io.File(io.Platform.resolvedExecutable).resolveSymbolicLinksSync()));
  final candidates = [
    p.join(root, 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'),
    p.join(p.dirname(p.dirname(p.dirname(root))), 'artifacts/material_fonts/MaterialIcons-Regular.otf'),
  ];
  final file = candidates.map(io.File.new).where((f) => f.existsSync()).firstOrNull;
  expect(file, isNotNull, reason: 'MaterialIcons-Regular.otf no encontrado (FLUTTER_ROOT=$root)');
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(file!.readAsBytesSync())))).load();
}

void main() {
  late ArcaDatabase db;
  late io.Directory tmp;
  late ArcaRepository repo;

  setUpAll(() async {
    await loadAppFonts();
    await _loadMaterialIcons();
  });

  setUp(() async {
    db = memoryDb();
    tmp = await io.Directory.systemTemp.createTemp('save_card_overflow');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  for (final locale in const [Locale('en'), Locale('es')]) {
    for (final (size, scale) in const [(Size(1000, 700), 1.0), (Size(1000, 700), 1.15), (Size(1440, 900), 1.0)]) {
      testWidgets('${locale.languageCode} ${size.width.toInt()}×${size.height.toInt()} texto ×$scale: tarjetas sin desborde',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.localesTestValue = [locale];
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final errors = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.toString());
        addTearDown(() => FlutterError.onError = previous);

        await tester.runAsync(() async {
          for (final e in SyntheticSaves.demoSet().entries) {
            await repo.importBytes(e.value, fileName: e.key, origin: ImportOrigin.demo);
          }
          // Una partida sin equipo (fila con icono en lugar de iconos de especie).
          await repo.importBytes(SyntheticSaves.gen3(party: const []), fileName: 'Empty', origin: ImportOrigin.demo);
        });
        await tester.pumpWidget(ProviderScope(
          overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
          child: const PKArkToolsApp(initialLocation: '/arca'),
        ));
        await settle(tester);
        expect(find.byType(SaveCard), findsWidgets);
        for (var i = 0; i < 6; i++) {
          await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -300), warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 300));
        }
        FlutterError.onError = previous;
        expect(errors, isEmpty, reason: errors.isEmpty ? null : errors.first);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
