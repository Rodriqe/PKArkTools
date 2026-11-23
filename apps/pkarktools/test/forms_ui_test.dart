import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/editor/pokemon_editor.dart';

Widget _app(Widget home, String lang) => MaterialApp(
      theme: AppTheme.dark(),
      locale: Locale(lang),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

const _trainer = TrainerData(name: 'ASH', tid: 12345, sid: 54321);

Future<void> _open(WidgetTester t, Pkm pk, GameVersion game, String lang) async {
  t.view.physicalSize = const Size(1440, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(_app(PokemonEditorScreen(key: UniqueKey(), game: game, initial: pk, slotLabel: 'Party 1'), lang));
  await t.pump();
}

void main() {
  testWidgets('Decidueye de Hisui: nombre de forma y tipos Planta/Lucha en la ficha', (t) async {
    final pk = PkmFactory.create(GameVersion.scarletViolet, _trainer, species: 724, form: 1, level: 50);
    await _open(t, pk, GameVersion.scarletViolet, 'en');
    expect(find.text('Decidueye (Hisui)'), findsWidgets);
    expect(find.text('Grass'), findsWidgets);
    expect(find.text('Fighting'), findsWidgets);
    expect(find.text('Ghost'), findsNothing);
  });

  testWidgets('el selector de forma nombra las formas y cambia tipos y habilidad', (t) async {
    final pk = PkmFactory.create(GameVersion.scarletViolet, _trainer, species: 724, form: 1, level: 50);
    await _open(t, pk, GameVersion.scarletViolet, 'es');
    expect(find.text('Decidueye (Hisui)'), findsWidgets);
    expect(find.text('Lucha'), findsWidgets);

    final selector = find.byKey(const ValueKey('Forma-1'));
    expect(selector, findsOneWidget);
    await t.ensureVisible(selector);
    await t.tap(selector);
    await t.pumpAndSettle();
    expect(find.text('Hisui'), findsWidgets);
    await t.tap(find.text('Normal').last);
    await t.pumpAndSettle();

    expect(find.text('Decidueye (Hisui)'), findsNothing);
    expect(find.text('Fantasma'), findsWidgets);
    expect(find.text('Lucha'), findsNothing);
  });

  testWidgets('Rotom Lavado y Tauros de Paldea en inglés', (t) async {
    final rotom = PkmFactory.create(GameVersion.scarletViolet, _trainer, species: 479, form: 2, level: 50);
    await _open(t, rotom, GameVersion.scarletViolet, 'en');
    expect(find.text('Rotom (Wash)'), findsWidgets);
    expect(find.text('Water'), findsWidgets);

    final tauros = PkmFactory.create(GameVersion.scarletViolet, _trainer, species: 128, form: 2, level: 50);
    await _open(t, tauros, GameVersion.scarletViolet, 'en');
    expect(find.text('Tauros (Paldea Blaze)'), findsWidgets);
    expect(find.text('Fire'), findsWidgets);
    expect(find.text('Normal'), findsNothing);
  });

  test('el resumen del equipo guarda la forma (y lee los índices antiguos)', () {
    final party = [
      const PokemonSummary(species: 724, form: 1, level: 50, isShiny: true),
      const PokemonSummary(species: 25, level: 5, isEgg: true),
    ];
    final s = ArcaRepository.encodeParty(party);
    expect(s, '724f1s,25e');
    expect(ArcaRepository.decodeParty(s), [
      (species: 724, form: 1, shiny: true, egg: false),
      (species: 25, form: 0, shiny: false, egg: true),
    ]);
    expect(ArcaRepository.decodeParty('724s'), [(species: 724, form: 0, shiny: true, egg: false)]);
  });
}
