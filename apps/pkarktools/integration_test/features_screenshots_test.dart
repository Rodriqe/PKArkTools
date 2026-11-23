import 'dart:io' as io;

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';
import 'package:pkarktools/data/sprites/sprite_cache.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/ui/editor/pokemon_editor.dart';

/// Capturas de cintas/marcas, iconos, origen, colores por versión y logo,
/// con datos sintéticos, en un teléfono (nunca abre la app de escritorio):
///
///   flutter drive -d DISPOSITIVO --driver test_driver/screenshot_driver.dart \
///     --target integration_test/features_screenshots_test.dart --dart-define=SHOTS=android/v2 \
///     [--dart-define=SHOTS_LANG=es]   (por defecto en; SHOTS_OUT=carpeta en el entorno del driver)
///
/// Los iconos se descargan de verdad (caché de la app) antes de capturar.
const _prefix = String.fromEnvironment('SHOTS', defaultValue: 'v2/phone');
const _lang = String.fromEnvironment('SHOTS_LANG', defaultValue: 'en');

/// Rutas de origen de ejemplo: el filtro «Origen» las clasifica.
const _sources = {
  'Esmeralda.sav': '/storage/emulated/0/mGBA/Esmeralda.sav',
  'Espada_main': '/Users/ash/.config/Ryujinx/bis/user/save/0000000000000001/0/main',
  'Escarlata_main': '/Volumes/SD/switch/JKSM/Pokemon Scarlet/2026-11-20/main',
  'Cristal.sav': '/Volumes/GBxCart/Cristal.sav',
  'Platino.sav': 'content://com.android.externalstorage.documents/tree/primary%3ADraStic%2Fbackup/Platino.dsv',
  'Rojo.sav': '/Users/ash/RetroArch/saves/Rojo.srm',
  'UltraSol.sav': '/Volumes/SD/3ds/Checkpoint/saves/0x01B50 Pokemon Ultra Sun/main',
  'Arceus_main': 'content://dev.eden.eden_emulator.provider/tree/nand%2Fuser%2Fsave/main',
  'Oro.sav': '/Volumes/GB Operator/Oro.sav',
  'Rubi.sav': '/private/var/mobile/Containers/Shared/AppGroup/x/Delta/Rubi.sav',
};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Solo teléfono (emulador -no-window o simulador headless). En el Mac las
  // capturas de escritorio son offscreen: test/desktop_screenshots_test.dart.
  testWidgets('capturas de las funciones nuevas', skip: io.Platform.isMacOS || io.Platform.isWindows || io.Platform.isLinux,
      (tester) async {
    // Idioma de las capturas sea cual sea el del dispositivo.
    final locale = _lang == 'es' ? const Locale('es', 'ES') : const Locale('en', 'US');
    tester.platformDispatcher.localesTestValue = [locale];
    tester.platformDispatcher.localeTestValue = locale;
    final l10n = lookupAppLocalizations(locale);
    // Iconos: descarga completa (con red) para que salgan en las capturas.
    await tester.runAsync(() => SpriteCache.instance.downloadAll());

    final db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final repo = ArcaRepository(db, ArcaFolder(MemoryFolderFs(label: 'PKArkTools')));
    final ids = <String, int>{};
    final saves = {
      ...SyntheticSaves.demoSet(),
      'Oro.sav': SyntheticSaves.gen2(
          trainer: const SynthTrainer(name: 'ETHAN', tid: 4242), party: const [SynthMon(155, level: 30), SynthMon(25, level: 22)]),
      'Rubi.sav': SyntheticSaves.gen3(
          game: GameVersion.rubySapphire,
          trainer: const SynthTrainer(name: 'BRENDAN', tid: 2024, sid: 77),
          party: const [SynthMon(258, level: 34), SynthMon(282, level: 30)]),
    };
    for (final e in saves.entries) {
      final r = await tester.runAsync(
          () => repo.importBytes(e.value, fileName: e.key, origin: ImportOrigin.file, sourcePath: _sources[e.key]));
      if (r is ImportAdded) ids[e.key] = r.slotId;
    }

    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    final boundary = GlobalKey();

    var n = 0;
    Future<void> shot(String name) async {
      // Deja que terminen de leerse los iconos del disco.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await settle(8);
      n++;
      await binding.takeScreenshot('${_prefix}_${n.toString().padLeft(2, '0')}_$name');
    }

    Future<void> open(String location, {ArcaSetup? setup}) async {
      await tester.pumpWidget(const SizedBox());
      await settle(3);
      await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: ProviderScope(
          key: UniqueKey(),
          overrides: [
            arcaRepositoryProvider.overrideWithValue(repo),
            if (setup != null) initialArcaSetupProvider.overrideWithValue(setup),
          ],
          child: PKArkToolsApp(initialLocation: location),
        ),
      ));
      await settle(25);
    }

    Future<void> reveal(Finder f, {double alignment = 0.1}) async {
      // En el editor (ruta encima del detalle) se usa su propia lista.
      final editor = find.byType(PokemonEditorScreen);
      final list = editor.evaluate().isNotEmpty
          ? find.descendant(of: editor, matching: find.byType(Scrollable)).first
          : find.byType(Scrollable).first;
      await tester.scrollUntilVisible(f, 300, scrollable: list, maxScrolls: 80);
      await settle(5);
      await Scrollable.ensureVisible(tester.element(f), alignment: alignment);
      await settle(10);
    }

    if (io.Platform.isAndroid) await binding.convertFlutterSurfaceToImage();

    // 1. Bienvenida con el logo.
    await open('/bienvenida', setup: const SetupNeeded());
    await shot('onboarding_logo');

    // 2. Arca con colores por versión (Rojo/Azul y Oro/Plata en pareja; Rubí deducido).
    await open('/arca');
    await shot('arca_colores');
    // Desplaza las tarjetas hasta ver la pareja Oro/Plata.
    final grid = find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text(_lang == 'es' ? GameVersion.goldSilver.nameEs : GameVersion.goldSilver.nameEn), 250, scrollable: grid, maxScrolls: 40);
    await settle(8);
    await shot('arca_colores_pareja');

    // 3. Ficha/editor con iconos y Origen (un Pokémon de Espada).
    await open('/arca/save/${ids['Espada_main']!}');
    final mon = find.bySemanticsLabel(RegExp('Eternatus')).first;
    await Scrollable.ensureVisible(tester.element(mon), alignment: 0.5);
    await settle(10);
    await shot('cajas_iconos');
    await tester.tap(mon);
    await settle(25);
    await shot('ficha_iconos');
    await reveal(find.text(l10n.originGame), alignment: 0.15);
    await reveal(find.text(l10n.sectionOrigin).last, alignment: 0.02);
    await shot('origen');

    // 4. Cintas y marcas: dar todas las válidas.
    await reveal(find.text(l10n.ribbonsGiveAll), alignment: 0.05);
    await tester.tap(find.text(l10n.ribbonsGiveAll));
    await settle(10);
    await shot('cintas');

    // 5. Ajustes > Iconos.
    await open('/ajustes');
    await reveal(find.text(l10n.spritesSection), alignment: 0.05);
    await shot('ajustes_iconos');

    // 6. Filtros del Arca: hoja inferior con una selección y el resultado.
    await open('/arca');
    Future<void> tapKey(String key, [int frames = 8]) async {
      final f = find.byKey(Key(key));
      await tester.ensureVisible(f);
      await settle(4);
      await tester.tap(f);
      await settle(frames);
    }

    await tapKey('arca-filters-button', 15);
    await tapKey('platform-nintendoSwitch');
    await tapKey('sort-playTime');
    await shot('filtros_hoja');
    await tapKey('panel-show', 15);
    await shot('arca_filtrada');
    await tapKey('arca-filters-clear', 5);

    await tester.pumpWidget(const SizedBox());
    await settle(5);
    await db.close();
  });
}
