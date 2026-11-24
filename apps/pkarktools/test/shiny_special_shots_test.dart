import 'dart:io' hide Platform;
import 'dart:io' as io show Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/data/sprites/sprite_cache.dart';
import 'package:pkarktools/providers.dart';

import 'arca_folder_test.dart' show memoryDb;
import 'shots_i18n.dart';

/// Captura de prueba de los iconos variocolor de las formas especiales
/// (`docs/screenshots/dex/10_shiny_special_forms.png`): Charizard con
/// Gigamax normal y variocolor (las dos desbloqueadas, lado a lado en «Tus
/// ejemplares» y en las pastillas) y Mega Charizard X variocolor.
///
///   flutter test test/shiny_special_shots_test.dart --dart-define=SHOTS_SHINY=true
///
/// Descarga solo los iconos que se ven (caché en `.scratch/sprite-cache`).
const _enabled = bool.fromEnvironment('SHOTS_SHINY');

/// Charizard Gigamax normal y variocolor (Espada) y Charizard normal y
/// variocolor en Leyendas Z-A (Megas X/Y en sus dos variantes).
GlobalDex shinySpecialDex() => GlobalDex.build([
      DexSource(
        id: 1,
        game: GameVersion.swordShield,
        versionId: 44,
        trainer: 'Gloria',
        scan: SaveDexScan(game: GameVersion.swordShield, hasPokedex: true, seen: const {4, 5, 6}, caught: const {4, 5, 6}, specimens: const [
          DexSpecimen(species: 6, level: 50, shiny: true, gigantamax: true, box: 0, slot: 3, nickname: 'Blaze'),
          DexSpecimen(species: 6, level: 47, gigantamax: true, box: 0, slot: 4),
        ]),
      ),
      DexSource(
        id: 5,
        game: GameVersion.legendsZA,
        trainer: 'Urbain',
        scan: SaveDexScan(game: GameVersion.legendsZA, hasPokedex: true, seen: const {6}, caught: const {6}, specimens: const [
          DexSpecimen(species: 6, level: 55, shiny: true, box: 2, slot: 6, nickname: 'Ember'),
          DexSpecimen(species: 6, level: 38, box: 2, slot: 7),
        ]),
      ),
    ]);

Future<void> _loadFonts() async {
  final flutterRoot = io.Platform.environment['FLUTTER_ROOT'];
  for (final (family, file) in [
    ('Manrope', 'assets/fonts/Manrope.ttf'),
    ('Bricolage', 'assets/fonts/BricolageGrotesque.ttf'),
    ('NotoSansSymbols', 'assets/fonts/NotoSansSymbols-Subset.ttf'),
    ('NotoSansSymbols2', 'assets/fonts/NotoSansSymbols2-Subset.ttf'),
    if (flutterRoot != null) ('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'),
  ]) {
    final f = File(file);
    if (f.existsSync()) await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
  }
}

void main() {
  testWidgets('captura: formas especiales variocolor de Charizard', skip: !_enabled, (tester) async {
    await _loadFonts();
    HttpOverrides.global = null;
    final cacheDir = Directory('../../.scratch/sprite-cache')..createSync(recursive: true);
    SpriteCache.instance = SpriteCache(directory: () async => cacheDir);
    addTearDown(tester.view.reset);
    final tmp = Directory('../../.scratch/tmp/shiny-shots')..createSync(recursive: true);
    final repo = ArcaRepository(memoryDb(), ArcaFolder(IoFolderFs(tmp)));

    Future<void> settle([int frames = 40]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(1440, 1500) * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.localesTestValue = [shotsLocale];
    await tester.pumpWidget(RepaintBoundary(
      key: boundary,
      child: ProviderScope(
        overrides: [
          arcaRepositoryProvider.overrideWithValue(repo),
          globalDexProvider.overrideWith((ref) async => shinySpecialDex()),
        ],
        child: PKArkToolsApp(initialLocation: '/dex/especie/6'),
      ),
    ));
    await settle();
    // Segunda pasada: lo que falló por concurrencia en la primera.
    await settle();
    final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = await tester.runAsync(() async {
      final image = await ro.toImage(pixelRatio: 2);
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    shotFile('dex/10_shiny_special_forms').writeAsBytesSync(png!.buffer.asUint8List());
    tester.platformDispatcher.clearLocalesTestValue();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
