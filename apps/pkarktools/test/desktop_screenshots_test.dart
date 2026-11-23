import 'dart:io' hide Platform;
import 'dart:io' as io show Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';
import 'package:pkarktools/data/sprites/sprite_cache.dart';
import 'package:pkarktools/ui/editor/pokemon_editor.dart';

import 'shots_i18n.dart';

/// Capturas de ESCRITORIO renderizadas fuera de pantalla: `flutter test` sin
/// dispositivo, ventana lógica de 1440×900 a 2×, fuentes reales y
/// `RepaintBoundary.toImage`. Nunca abre ni enfoca una ventana del Mac.
///
///   flutter test test/desktop_screenshots_test.dart --dart-define=SHOTS_DESKTOP=true
///
/// Escribe `docs/screenshots/v2/mac_NN_nombre.png`. Sin la define se omite
/// (el CI no reescribe capturas). Descarga los iconos de verdad a
/// `.scratch/sprite-cache` (fuera del repo).
const _enabled = bool.fromEnvironment('SHOTS_DESKTOP');

Future<void> _loadFonts() async {
  final flutterRoot = io.Platform.environment['FLUTTER_ROOT'];
  final fonts = <(String, String)>[
    ('Manrope', 'assets/fonts/Manrope.ttf'),
    ('Bricolage', 'assets/fonts/BricolageGrotesque.ttf'),
    ('NotoSansSymbols', 'assets/fonts/NotoSansSymbols-Subset.ttf'),
    ('NotoSansSymbols2', 'assets/fonts/NotoSansSymbols2-Subset.ttf'),
    if (flutterRoot != null) ('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'),
  ];
  for (final (family, file) in fonts) {
    final f = File(file);
    if (!f.existsSync()) continue;
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
  }
}

void main() {
  testWidgets('capturas de escritorio offscreen', skip: !_enabled, (tester) async {
    await _loadFonts();
    // Red real para los iconos (flutter_test la simula por defecto).
    HttpOverrides.global = null;
    final cacheDir = Directory('../../.scratch/sprite-cache')..createSync(recursive: true);
    SpriteCache.instance = SpriteCache(directory: () async => cacheDir);
    await tester.runAsync(() => SpriteCache.instance.downloadAll());

    tester.view.physicalSize = const Size(1440, 900) * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.localesTestValue = [shotsLocale];
    tester.platformDispatcher.localeTestValue = shotsLocale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

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
    // Rutas de origen de ejemplo: el filtro «Origen» las clasifica.
    const sources = {
      'Esmeralda.sav': '/Users/ash/Library/Application Support/mGBA/Esmeralda.sav',
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
    for (final e in saves.entries) {
      final r = await tester.runAsync(
          () => repo.importBytes(e.value, fileName: e.key, origin: ImportOrigin.file, sourcePath: sources[e.key]));
      if (r is ImportAdded) ids[e.key] = r.slotId;
    }

    final boundary = GlobalKey();
    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    var n = 0;
    Future<void> shot(String name) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
      await settle(10);
      n++;
      final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final png = await tester.runAsync(() async {
        final image = await ro.toImage(pixelRatio: 2);
        return image.toByteData(format: ui.ImageByteFormat.png);
      });
      shotFile('v2/mac_${n.toString().padLeft(2, '0')}_$name').writeAsBytesSync(png!.buffer.asUint8List());
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
      final editor = find.byType(PokemonEditorScreen);
      final scope = editor.evaluate().isNotEmpty ? editor : find.byType(Scaffold).last;
      final list = find.descendant(of: scope, matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(f, 300, scrollable: list, maxScrolls: 80);
      await settle(5);
      await Scrollable.ensureVisible(tester.element(f), alignment: alignment);
      await settle(10);
    }

    await open('/bienvenida', setup: const SetupNeeded());
    await shot('onboarding_logo');

    await open('/arca');
    await shot('arca_colores');
    final grid = find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text(tr('Pokémon Oro / Plata', 'Pokémon Gold / Silver')), 250, scrollable: grid, maxScrolls: 40);
    await settle(8);
    await shot('arca_colores_pareja');

    await open('/arca/save/${ids['Espada_main']!}');
    final mon = find.bySemanticsLabel(RegExp('Eternatus')).first;
    await Scrollable.ensureVisible(tester.element(mon), alignment: 0.5);
    await settle(10);
    await shot('cajas_iconos');
    await tester.tap(mon);
    await settle(25);
    await shot('ficha_iconos');
    await reveal(find.text(tr('Juego de origen')), alignment: 0.1);
    await shot('origen');
    await reveal(find.text(tr('Dar todas las válidas')), alignment: 0.05);
    await tester.tap(find.text(tr('Dar todas las válidas')));
    await settle(10);
    await shot('cintas');

    await open('/ajustes');
    await reveal(find.text(tr('Iconos')), alignment: 0.05);
    await shot('ajustes_iconos');

    // Filtros del Arca (panel lateral en escritorio ancho).
    await open('/arca');
    await tester.tap(find.byKey(const Key('platform-nintendoSwitch')));
    await settle(8);
    await tester.tap(find.byKey(const Key('sort-playTime')));
    await settle(8);
    await shot('arca_filtros');
    await tester.tap(find.byKey(const Key('panel-clear')));
    await tester.tap(find.byKey(const Key('sort-recent')));
    await settle(8);

    await tester.pumpWidget(const SizedBox());
    await settle(5);
    await tester.runAsync(db.close);
  });
}
