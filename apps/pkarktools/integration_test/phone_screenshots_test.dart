import 'dart:io' show Platform;

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';

/// Capturas de la app real en un teléfono (simulador de iOS o emulador),
/// a la resolución y con el safe area del dispositivo:
///
///   flutter drive -d SIMULADOR --driver test_driver/screenshot_driver.dart \
///     --target integration_test/phone_screenshots_test.dart --dart-define=SHOTS=ios/se
///
/// Guarda `docs/screenshots/{SHOTS}_NN_nombre.png`. Solo datos sintéticos.
const _prefix = String.fromEnvironment('SHOTS', defaultValue: 'ios/phone');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capturas de teléfono', (tester) async {
    final db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final repo = ArcaRepository(db, ArcaFolder(MemoryFolderFs(label: 'PKArkTools')));
    final ids = <String, int>{};
    for (final e in SyntheticSaves.demoSet().entries) {
      final r = await repo.importBytes(e.value, fileName: e.key, origin: ImportOrigin.demo);
      if (r is ImportAdded) ids[e.key] = r.slotId;
    }

    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    var n = 0;
    Future<void> shot(String name) async {
      await settle(8);
      n++;
      await binding.takeScreenshot('${_prefix}_${n.toString().padLeft(2, '0')}_$name');
    }

    Future<void> open(String location, {ArcaSetup? setup}) async {
      await tester.pumpWidget(const SizedBox());
      await settle(3);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          arcaRepositoryProvider.overrideWithValue(repo),
          if (setup != null) initialArcaSetupProvider.overrideWithValue(setup),
        ],
        child: PKArkToolsApp(initialLocation: location),
      ));
      await settle(25);
    }

    // Desplazamientos relativos a la altura lógica de la pantalla.
    final h = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    Future<void> scroll(double screens) async {
      final dy = screens * h;
      await tester.drag(find.byType(Scrollable).first, Offset(0, -dy), warnIfMissed: false);
      await settle(10);
    }

    Future<void> section(String label) async {
      final f = find.text(label).last;
      await tester.ensureVisible(f);
      await settle(5);
      await tester.tap(f);
      await settle(10);
    }

    // Android necesita convertir la superficie para poder capturarla.
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();

    // Onboarding (sugerencia de la plataforma real).
    await open('/bienvenida', setup: const SetupNeeded());
    await shot('onboarding');

    // Arca.
    await open('/arca');
    await shot('arca');
    await scroll(1.2);
    await shot('arca_desplazada');

    // Detalle de Espada: pestañas, cajas, editor.
    final sword = ids['Espada_main']!;
    await open('/arca/save/$sword');
    await tester.ensureVisible(find.text('Equipo').first);
    await scroll(-0.25);
    await shot('detalle_pestanas');
    final eternatus = find.bySemanticsLabel(RegExp('Eternatus')).first;
    await Scrollable.ensureVisible(tester.element(eternatus), alignment: 0.6);
    await settle(10);
    await shot('cajas');
    await tester.tap(eternatus);
    await settle(25);
    await shot('editor');
    await scroll(1.6);
    await shot('editor_formulario');

    for (final (label, name) in [('Entrenador', 'entrenador'), ('Inventario', 'inventario'), ('Pokédex', 'pokedex')]) {
      await open('/arca/save/$sword');
      await section(label);
      await scroll(0.3);
      await shot(name);
    }

    // Eventos (Ultrasol), Ajustes y Actividad.
    await open('/arca/save/${ids['UltraSol.sav']!}');
    await section('Eventos');
    await scroll(0.3);
    await shot('eventos');
    await open('/ajustes');
    await shot('ajustes');
    await open('/actividad');
    await shot('actividad');

    await tester.pumpWidget(const SizedBox());
    await settle(5);
    await db.close();
  });
}
