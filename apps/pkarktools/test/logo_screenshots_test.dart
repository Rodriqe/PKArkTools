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
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';

import 'shots_i18n.dart';

/// Capturas del logo dentro de la app (barra lateral, onboarding y Ajustes ›
/// Acerca de) en escritorio y teléfono, renderizadas fuera de pantalla.
///
///   flutter test test/logo_screenshots_test.dart --dart-define=SHOTS_LOGO=true \
///       [--dart-define=SHOTS_LOGO_TAG=after]
///
/// Escribe `<SHOTS_OUT>/logo/<tag>_<pantalla>_<ancho>x<alto>.png`. Sin la
/// define se omite (el CI no reescribe capturas).
const _enabled = bool.fromEnvironment('SHOTS_LOGO');
const _tag = String.fromEnvironment('SHOTS_LOGO_TAG', defaultValue: 'after');

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
  const sizes = [Size(1440, 900), Size(1000, 700), Size(320, 568), Size(360, 800), Size(430, 932)];

  testWidgets('capturas del logo en la app', skip: !_enabled, (tester) async {
    await _loadFonts();
    tester.platformDispatcher.localesTestValue = [shotsLocale];
    tester.platformDispatcher.localeTestValue = shotsLocale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    final db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final repo = ArcaRepository(db, ArcaFolder(MemoryFolderFs(label: 'PKArkTools')));
    for (final e in SyntheticSaves.demoSet().entries.take(3)) {
      await tester.runAsync(() => repo.importBytes(e.value, fileName: e.key, origin: ImportOrigin.file));
    }

    final boundary = GlobalKey();
    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> shot(String name, Size size) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await settle(8);
      final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final png = await tester.runAsync(() async {
        final image = await ro.toImage(pixelRatio: 2);
        return image.toByteData(format: ui.ImageByteFormat.png);
      });
      shotFile('logo/${_tag}_${name}_${size.width.toInt()}x${size.height.toInt()}')
          .writeAsBytesSync(png!.buffer.asUint8List());
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
      await settle(20);
    }

    for (final size in sizes) {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      await open('/bienvenida', setup: const SetupNeeded());
      await shot('onboarding', size);
      await open('/arca');
      await shot('arca', size);
      await open('/ajustes');
      final about = find.text(tr('Acerca de', 'About'));
      final list = find.descendant(of: find.byType(Scaffold).last, matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(about, 300, scrollable: list, maxScrolls: 80);
      await Scrollable.ensureVisible(tester.element(about), alignment: 0.05);
      await settle(8);
      await shot('acerca_de', size);
      // Los desbordes los vigila test/phone_layout_test.dart; aquí solo se informa.
      final e = tester.takeException();
      if (e != null) debugPrint('aviso ${size.width.toInt()}×${size.height.toInt()}: $e');
    }

    await tester.pumpWidget(const SizedBox());
    await settle(5);
    await tester.runAsync(db.close);
  });
}
