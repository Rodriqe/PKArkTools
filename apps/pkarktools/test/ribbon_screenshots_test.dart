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

import 'arca_folder_test.dart' show memoryDb;
import 'dex_demo.dart';
import 'shots_i18n.dart';

/// Capturas de la Dex global (`docs/screenshots/dex/*.png`) con partidas
/// sintéticas:
///
///   flutter test test/dex_screenshots_test.dart --dart-define=SHOTS_RIBBONS=true
///
/// Sin la define se omite (el CI no reescribe capturas).
const _enabled = bool.fromEnvironment('SHOTS_RIBBONS');

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
  testWidgets('capturas de Ribbon Master', skip: !_enabled, (tester) async {
    await _loadFonts();
    HttpOverrides.global = null;
    final cacheDir = Directory('../../.scratch/sprite-cache')..createSync(recursive: true);
    SpriteCache.instance = SpriteCache(directory: () async => cacheDir);
    await tester.runAsync(() => SpriteCache.instance.downloadAll());
    addTearDown(tester.view.reset);
    final tmp = Directory('../../.scratch/tmp/ribbon-shots')..createSync(recursive: true);
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
      shotFile('ribbons/$name').writeAsBytesSync(png!.buffer.asUint8List());
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
    await open('/cintas', desktop);
    await write('01_home');
    await open('/cintas/top', const Size(1440, 1500));
    await write('02_top50');
    await open('/cintas/guia/1', const Size(1440, 4200));
    await write('03_guide_bulbasaur');
    await open('/cintas/guia/26?forma=1', const Size(1440, 2400));
    await write('04_guide_alolan_raichu');
    await open('/cintas/guia/6', const Size(1440, 4400));
    await write('05_guide_your_specimens');
    await open('/cintas/guia/37', const Size(1440, 1300));
    await write('06_guide_shadow_origin');
    await open('/cintas', const Size(390, 844), phone: true);
    await write('07_phone_home');
    await open('/cintas/guia/700', const Size(390, 2400), phone: true);
    await write('08_phone_guide_sylveon');
    await open('/cintas/top', const Size(390, 844), phone: true);
    await write('09_phone_top50');
    await open('/dex/especie/700', const Size(1440, 1100));
    await write('10_dex_button');
    tester.platformDispatcher.clearLocalesTestValue();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
