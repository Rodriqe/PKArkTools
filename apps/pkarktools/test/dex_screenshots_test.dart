import 'dart:io' hide Platform;
import 'dart:io' as io show Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/data/sprites/sprite_cache.dart';
import 'package:pkarktools/providers.dart';
import 'package:pkcore/pkcore.dart';

import 'arca_folder_test.dart' show memoryDb;
import 'shots_i18n.dart';

/// Capturas de la Dex global (`docs/screenshots/dex/*.png`) con partidas
/// sintéticas:
///
///   flutter test test/dex_screenshots_test.dart --dart-define=SHOTS_DEX=true
///
/// Sin la define se omite (el CI no reescribe capturas).
const _enabled = bool.fromEnvironment('SHOTS_DEX');

Future<void> _loadFonts() async {
  final flutterRoot = io.Platform.environment['FLUTTER_ROOT'];
  for (final (family, file) in [
    ('Manrope', 'assets/fonts/Manrope.ttf'),
    ('Bricolage', 'assets/fonts/BricolageGrotesque.ttf'),
    if (flutterRoot != null) ('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'),
  ]) {
    final f = File(file);
    if (f.existsSync()) await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
  }
}

/// Dex de demostración: varias partidas sintéticas con Pokédex medio llenas,
/// ejemplares variocolor, factor Gigamax y piedras activadoras.
GlobalDex demoDex() {
  Set<int> range(int a, int b) => {for (var s = a; s <= b; s++) s};
  final swsh = SaveDexScan(
    game: GameVersion.swordShield,
    hasPokedex: true,
    seen: {...range(810, 898), ...range(1, 9), 25, 133, 143},
    caught: {...range(810, 870), 1, 4, 6, 25, 133},
    specimens: const [
      DexSpecimen(species: 6, level: 50, shiny: true, gigantamax: true, box: 0, slot: 3, nickname: 'Blaze'),
      DexSpecimen(species: 6, level: 47, gigantamax: true, box: 0, slot: 4),
      DexSpecimen(species: 25, level: 22, gigantamax: true, box: -1, slot: 0),
      DexSpecimen(species: 133, level: 30, shiny: true, box: 1, slot: 0),
      DexSpecimen(species: 849, form: 1, level: 40, gigantamax: true, box: 1, slot: 1),
      DexSpecimen(species: 892, form: 1, level: 70, box: -1, slot: 1),
    ],
  );
  final xy = SaveDexScan(
    game: GameVersion.xy,
    hasPokedex: true,
    seen: range(1, 251),
    caught: {...range(1, 160), ...range(650, 721)},
    specimens: const [
      DexSpecimen(species: 6, level: 36, box: -1, slot: 0, heldItem: 660),
      DexSpecimen(species: 448, level: 40, box: 0, slot: 2),
      DexSpecimen(species: 3, level: 32, shiny: true, box: 0, slot: 5),
    ],
    items: const {660, 673},
  );
  final oras = SaveDexScan(
    game: GameVersion.omegaRubyAlphaSapphire,
    hasPokedex: true,
    seen: range(252, 386),
    caught: range(252, 380),
    specimens: const [DexSpecimen(species: 382, level: 45, box: 3, slot: 0), DexSpecimen(species: 384, level: 70, box: 3, slot: 1)],
    items: const {535},
  );
  final sv = SaveDexScan(
    game: GameVersion.scarletViolet,
    hasPokedex: true,
    seen: {...range(906, 1025), ...range(387, 493)},
    caught: {...range(906, 1000), ...range(387, 420)},
    specimens: const [DexSpecimen(species: 1000, level: 66, shiny: true, box: 0, slot: 0)],
  );
  final za = SaveDexScan(
    game: GameVersion.legendsZA,
    hasPokedex: true,
    seen: {35, 36, 670, 678, 26},
    caught: {36, 26},
    specimens: const [DexSpecimen(species: 36, level: 40, shiny: true, box: 2, slot: 5), DexSpecimen(species: 26, level: 38, box: 2, slot: 6)],
  );
  return GlobalDex.build([
    DexSource(id: 1, game: GameVersion.swordShield, versionId: 44, trainer: 'Gloria', scan: swsh),
    DexSource(id: 2, game: GameVersion.xy, versionId: 24, trainer: 'Serena', scan: xy),
    DexSource(id: 3, game: GameVersion.omegaRubyAlphaSapphire, versionId: 26, trainer: 'May', scan: oras),
    DexSource(id: 4, game: GameVersion.scarletViolet, versionId: 50, trainer: 'Nemona', scan: sv),
    DexSource(id: 5, game: GameVersion.legendsZA, trainer: 'Urbain', scan: za),
  ]);
}

void main() {
  testWidgets('capturas de la Dex', skip: !_enabled, (tester) async {
    await _loadFonts();
    HttpOverrides.global = null;
    final cacheDir = Directory('../../.scratch/sprite-cache')..createSync(recursive: true);
    SpriteCache.instance = SpriteCache(directory: () async => cacheDir);
    await tester.runAsync(() => SpriteCache.instance.downloadAll());
    addTearDown(tester.view.reset);
    final tmp = Directory('../../.scratch/tmp/dex-shots')..createSync(recursive: true);
    final repo = ArcaRepository(memoryDb(), ArcaFolder(IoFolderFs(tmp)));
    final dex = demoDex();

    Future<void> settle([int frames = 25]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    final boundary = GlobalKey();
    Future<void> write(String name) async {
      final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final png = await tester.runAsync(() async {
        final image = await ro.toImage(pixelRatio: 2);
        return image.toByteData(format: ui.ImageByteFormat.png);
      });
      shotFile('dex/$name').writeAsBytesSync(png!.buffer.asUint8List());
    }

    Future<void> open(String at, Size size, {bool phone = false}) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      tester.view.padding = phone ? const FakeViewPadding(top: 47 * 2, bottom: 34 * 2) : FakeViewPadding.zero;
      tester.view.viewPadding = tester.view.padding;
      tester.platformDispatcher.localesTestValue = [shotsLocale];
      await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: ProviderScope(
          key: UniqueKey(),
          overrides: [
            arcaRepositoryProvider.overrideWithValue(repo),
            globalDexProvider.overrideWith((ref) async => dex),
          ],
          child: PKArkToolsApp(initialLocation: at),
        ),
      ));
      await settle();
    }

    const desktop = Size(1440, 900);
    const phone = Size(390, 844);
    await open('/dex', desktop);
    await write('01_grid');
    await open('/dex/especie/6', const Size(1440, 1500));
    await write('02_species_charizard');
    await open('/dex/especie/3', const Size(1440, 1300));
    await write('03_locked_forms');
    await open('/dex/especie/849', const Size(1440, 1300));
    await write('04_gigantamax_forms');
    await open('/dex/progreso', const Size(1440, 1100));
    await write('05_progress');
    await open('/dex', desktop);
    await tester.tap(find.byKey(const ValueKey('dex-shiny')));
    await settle(5);
    await write('06_filter_shiny');
    await open('/dex', phone, phone: true);
    await write('07_phone_grid');
    await open('/dex/especie/6', const Size(390, 1900), phone: true);
    await write('08_phone_species');
    tester.platformDispatcher.clearLocalesTestValue();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
