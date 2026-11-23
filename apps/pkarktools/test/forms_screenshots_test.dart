import 'dart:io' hide Platform;
import 'dart:io' as io show Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:pkarktools/data/sprites/sprite_cache.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/editor/pokemon_editor.dart';
import 'package:pkcore/pkcore.dart';

import 'shots_i18n.dart';

/// Capturas de las formas regionales y alternativas en el editor
/// (`docs/screenshots/35_forma_hisui.png`, `36_selector_forma.png`):
///
///   flutter test test/forms_screenshots_test.dart --dart-define=SHOTS_FORMS=true
///
/// Sin la define se omite (el CI no reescribe capturas).
const _enabled = bool.fromEnvironment('SHOTS_FORMS');

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

void main() {
  testWidgets('capturas: Decidueye de Hisui y selector de forma', skip: !_enabled, (tester) async {
    await _loadFonts();
    HttpOverrides.global = null;
    final cacheDir = Directory('../../.scratch/sprite-cache')..createSync(recursive: true);
    SpriteCache.instance = SpriteCache(directory: () async => cacheDir);
    await tester.runAsync(() => SpriteCache.instance.downloadAll());
    addTearDown(tester.view.reset);

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
      shotFile(name).writeAsBytesSync(png!.buffer.asUint8List());
    }

    const trainer = TrainerData(name: 'NEMONA', tid: 202611, sid: 1);
    final pk = PkmFactory.create(GameVersion.scarletViolet, trainer,
        species: 724, form: 1, level: 62, language: shotsSpanish ? 7 : 2, today: DateTime(2026, 11, 23));
    tester.view.physicalSize = const Size(1280, 900) * 2;
    tester.view.devicePixelRatio = 2;
    await tester.pumpWidget(RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        locale: shotsLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PokemonEditorScreen(game: GameVersion.scarletViolet, initial: pk, slotLabel: tr('Equipo, hueco 1', 'Party, slot 1')),
      ),
    ));
    await settle();
    await write('35_forma_hisui');

    final selector = find.byKey(ValueKey('${tr('Forma')}-1'));
    await tester.ensureVisible(selector);
    await settle(3);
    await tester.tap(selector);
    await settle();
    await write('36_selector_forma');
  });
}
