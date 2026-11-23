import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/common/species_avatar.dart';
import 'package:pkarktools/ui/editor/pokemon_editor.dart';

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

/// Comprueba que la insignia está dentro del avatar y dentro de [visible].
void _expectInside(WidgetTester t, Rect visible) {
  final badges = find.byKey(const ValueKey('shiny-badge'));
  expect(badges, findsWidgets);
  for (final e in badges.evaluate()) {
    final badge = t.getRect(find.byWidget(e.widget));
    final avatar = t.getRect(find.ancestor(of: find.byWidget(e.widget), matching: find.byType(SpeciesAvatar)).first);
    expect(avatar.inflate(0.5).contains(badge.topLeft) && avatar.inflate(0.5).contains(badge.bottomRight), isTrue,
        reason: 'insignia $badge fuera del avatar $avatar');
    expect(visible.inflate(0.5).contains(badge.topLeft) && visible.inflate(0.5).contains(badge.bottomRight), isTrue,
        reason: 'insignia $badge fuera de la zona visible $visible');
  }
}

void main() {
  testWidgets('la insignia variocolor queda dentro del avatar en todos los tamaños', (t) async {
    await t.pumpWidget(_app(Scaffold(
      body: Wrap(children: [
        for (final s in [24.0, 32.0, 44.0, 52.0, 64.0, 104.0])
          ClipRect(child: SpeciesAvatar(species: 25, shiny: true, size: s)),
      ]),
    )));
    await t.pump();
    _expectInside(t, Offset.zero & t.view.physicalSize / t.view.devicePixelRatio);
  });

  for (final size in const [Size(360, 800), Size(430, 932), Size(1440, 900)]) {
    testWidgets('editor ${size.width.toInt()}×${size.height.toInt()}: insignia completa y visible', (t) async {
      final pk = SaveEditor.open(SyntheticSaves.swordShield(party: const [SynthMon(890, level: 60, shiny: true)]))
          .get(const SlotRef.party(0))!;
      expect(pk.isShiny, isTrue);
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(PokemonEditorScreen(game: GameVersion.swordShield, initial: pk, slotLabel: 'Equipo, hueco 1')));
      await t.pump();
      // Zona visible: el cuerpo bajo la AppBar (la lista del editor recorta lo que sobresale).
      final list = t.getRect(find.byType(Scrollable).first);
      _expectInside(t, list);
    });
  }
}
