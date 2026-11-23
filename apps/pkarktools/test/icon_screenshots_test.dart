import 'dart:io' hide Platform;
import 'dart:io' as io show Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/data/sprites/sprite_cache.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/ui/common/game_icons.dart';
import 'package:pkarktools/ui/common/species_avatar.dart';

/// Lámina de iconos para revisar proporciones (Pokémon pequeños y grandes,
/// objetos de lienzos distintos, Balls, tipos y cintas) a varios tamaños y
/// densidades, renderizada fuera de pantalla con los sprites reales:
///
///   flutter test test/icon_screenshots_test.dart --dart-define=SHOTS_ICONS=true \
///     [--dart-define=SHOTS_OUT=../../.scratch/shots/after]
///
/// Sin la define se omite. Descarga los iconos a `.scratch/sprite-cache`.
const _enabled = bool.fromEnvironment('SHOTS_ICONS');
const _out = String.fromEnvironment('SHOTS_OUT', defaultValue: '../../.scratch/shots/icons');

Future<void> _loadFonts() async {
  final root = io.Platform.environment['FLUTTER_ROOT'];
  for (final (family, file) in [
    ('Manrope', 'assets/fonts/Manrope.ttf'),
    ('Bricolage', 'assets/fonts/BricolageGrotesque.ttf'),
    if (root != null) ('MaterialIcons', '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'),
  ]) {
    final f = File(file);
    if (f.existsSync()) await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
  }
}

void main() {
  testWidgets('lámina de iconos', skip: !_enabled, (tester) async {
    await _loadFonts();
    HttpOverrides.global = null;
    final cacheDir = Directory('../../.scratch/sprite-cache')..createSync(recursive: true);
    SpriteCache.instance = SpriteCache(directory: () async => cacheDir);
    await tester.runAsync(() => SpriteCache.instance.downloadAll());

    // Joltik, Pikachu, Bulbasaur, Charizard, Snorlax, Wailord, Eternatus, Rotom Lavado (forma), Totodile variocolor.
    const mons = [(595, 0, false), (25, 0, false), (1, 0, false), (6, 0, false), (143, 0, false), (321, 0, false), (890, 0, false), (479, 3, false), (158, 0, true)];
    const items = [1, 4, 17, 28, 50, 221, 1606, 2564]; // Master Ball, Poké Ball, Poción, Revivir, Caramelo raro, Restos, Mega piedra…
    const balls = [1, 2, 3, 4, 5, 26];
    final ribbons = Ribbons.all.take(6).toList();

    for (final (dpr, name) in [(2.3, 'odin3'), (3.0, 'phone'), (2.0, 'desktop')]) {
      tester.view.physicalSize = Size(1100 * dpr, 900 * dpr);
      tester.view.devicePixelRatio = dpr;
      final key = GlobalKey();
      Widget row(String label, List<Widget> children) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12))),
              for (final c in children)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(border: Border.all(color: const Color(0x22000000))),
                    child: c,
                  ),
                ),
            ]),
          );
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: RepaintBoundary(
          key: key,
          child: Material(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('dpr $dpr', style: const TextStyle(fontWeight: FontWeight.bold)),
                for (final s in [32.0, 44.0, 64.0, 96.0])
                  row('Pokémon ${s.toInt()}', [
                    for (final (sp, form, shiny) in mons) SpeciesAvatar(species: sp, form: form, shiny: shiny, size: s),
                  ]),
                for (final s in [20.0, 28.0, 40.0])
                  row('Objetos ${s.toInt()}', [for (final i in items) ItemIcon(item: i, size: s)]),
                for (final s in [16.0, 22.0, 32.0]) row('Balls ${s.toInt()}', [for (final b in balls) BallIcon(ball: b, size: s)]),
                row('Tipos 16/28', [
                  for (final t in [PokemonType.fire, PokemonType.water, PokemonType.dragon]) ...[
                    TypeIcon(type: t, size: 16),
                    TypeIcon(type: t, size: 28),
                  ],
                ]),
                row('Cintas 24/40', [
                  for (final r in ribbons) ...[RibbonIcon(ribbon: r, size: 24), RibbonIcon(ribbon: r, size: 40)],
                ]),
              ]),
            ),
          ),
        ),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
        await tester.pump();
      }
      final ro = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final png = await tester.runAsync(() async {
        final image = await ro.toImage(pixelRatio: dpr);
        return image.toByteData(format: ui.ImageByteFormat.png);
      });
      File('$_out/iconos_$name.png')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    }
    tester.view.reset();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
