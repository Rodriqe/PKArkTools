import 'dart:io' as io;

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';
import 'package:pkarktools/data/sprites/sprite_cache.dart';
import 'package:pkarktools/providers.dart';

import '../test/dex_demo.dart';

/// Capturas de Ribbon Hunter en un teléfono real (emulador -no-window o simulador
/// headless), con la misma Dex sintética que las offscreen:
///
///   flutter drive -d DISPOSITIVO --driver test_driver/screenshot_driver.dart \
///     --target integration_test/ribbon_screenshots_test.dart --dart-define=SHOTS=android/ribbons
const _prefix = String.fromEnvironment('SHOTS', defaultValue: 'ribbons/phone');
const _lang = String.fromEnvironment('SHOTS_LANG', defaultValue: 'en');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capturas de Ribbon Hunter', skip: io.Platform.isMacOS || io.Platform.isWindows || io.Platform.isLinux, (tester) async {
    final locale = _lang == 'es' ? const Locale('es', 'ES') : const Locale('en', 'US');
    tester.platformDispatcher.localesTestValue = [locale];
    tester.platformDispatcher.localeTestValue = locale;
    await tester.runAsync(() => SpriteCache.instance.downloadAll());
    final db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final repo = ArcaRepository(db, ArcaFolder(MemoryFolderFs(label: 'PKArkTools')));
    final dex = demoDex();

    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    var n = 0;
    Future<void> shot(String name) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await settle(8);
      n++;
      await binding.takeScreenshot('${_prefix}_${n.toString().padLeft(2, '0')}_$name');
    }

    Future<void> open(String location, {GlobalDex? using}) async {
      await tester.pumpWidget(const SizedBox());
      await settle(3);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          arcaRepositoryProvider.overrideWithValue(repo),
          globalDexProvider.overrideWith((ref) async => using ?? dex),
        ],
        child: PKArkToolsApp(initialLocation: location),
      ));
      await settle(25);
    }

    Future<void> scrollTo(Finder f) async {
      await tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first, maxScrolls: 60);
      await settle(5);
      await Scrollable.ensureVisible(tester.element(f), alignment: 0.1);
      await settle(10);
    }

    if (io.Platform.isAndroid) await binding.convertFlutterSurfaceToImage();

    await open('/cintas');
    await shot('home');
    await open('/cintas/ranking');
    await shot('ranking');
    await open('/cintas/ranking/${RibbonMaster.tiers().first.total}');
    await shot('ranking_tier');
    await open('/cintas/guia/1');
    await shot('guide');
    await scrollTo(find.byKey(const ValueKey('rm-step-dppt')));
    await shot('guide_contests');
    await open('/cintas/guia/26?forma=1');
    await scrollTo(find.byKey(const ValueKey('rm-step-smusum')));
    await shot('regional_form');
    await open('/cintas/guia/6');
    await scrollTo(find.text(_lang == 'es' ? 'Tus ejemplares de esta especie' : 'Your specimens of this species'));
    await shot('your_specimens');
    await open('/dex/especie/700');
    await shot('dex_button');
  });
}
