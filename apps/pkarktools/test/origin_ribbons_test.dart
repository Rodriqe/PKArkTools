import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/common/version_chip.dart';
import 'package:pkarktools/ui/editor/origin_panel.dart';
import 'package:pkarktools/ui/editor/pokemon_editor.dart';
import 'package:pkarktools/ui/editor/ribbons_panel.dart';

Pkm _swsh() => SaveEditor.open(SyntheticSaves.swordShield(party: const [SynthMon(25, level: 30)])).get(const SlotRef.party(0))!;

Future<void> _pump(WidgetTester t, Pkm pk, GameVersion game, {Size size = const Size(1300, 1800), double scale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: AppTheme.dark(),
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
    home: PokemonEditorScreen(game: game, initial: pk, slotLabel: 'Equipo, hueco 1'),
  ));
  await t.pump();
}

void main() {
  testWidgets('Origen: juego con su color, lugar real, traspasos y Ball', (t) async {
    final pk = _swsh()..version = 12; // Platino traído a Espada
    pk.metLocation = 0x37; // en Gen 4 sería Parque Compi; aquí basta con que tenga nombre
    await _pump(t, pk, GameVersion.swordShield);
    expect(find.byType(OriginPanel), findsOneWidget);
    expect(find.text('Origen'), findsOneWidget);
    expect(find.widgetWithText(VersionChip, 'Platino'), findsWidgets);
    expect(find.textContaining('Pokétransfer → Poké Transporter / Banco → Pokémon Banco → Pokémon HOME'), findsOneWidget);
    expect(find.textContaining('Entrenador original: '), findsOneWidget);
    // Cambiar el juego de origen desde el selector.
    final dd = find.byKey(const ValueKey('origin-version-12'));
    await t.ensureVisible(dd);
    await t.tap(dd);
    await t.pumpAndSettle();
    await t.tap(find.text('Espada').last);
    await t.pumpAndSettle();
    expect(find.widgetWithText(VersionChip, 'Espada'), findsWidgets);
    expect(find.textContaining('Pokétransfer'), findsNothing);
  });

  testWidgets('Cintas: dar todas, filtro y quitar todas', (t) async {
    final pk = _swsh()..version = 44;
    await _pump(t, pk, GameVersion.swordShield);
    expect(find.byType(RibbonsPanel), findsOneWidget);
    expect(find.text('Cintas y marcas'), findsOneWidget);
    expect(find.text('0 de 111'), findsOneWidget);
    await t.ensureVisible(find.text('Dar todas las válidas'));
    await t.tap(find.text('Dar todas las válidas'));
    await t.pump();
    expect(find.textContaining('cintas añadidas'), findsOneWidget);
    expect(find.text('0 de 111'), findsNothing);
    expect(find.textContaining('no se puede conseguir'), findsNothing);
    await t.tap(find.text('Solo las que tiene'));
    await t.pump();
    expect(find.text('Marcas · 0/0'), findsNothing); // sin marcas dadas: el grupo desaparece
    await t.tap(find.text('Quitar todas'));
    await t.pump();
    expect(find.text('No tiene cintas ni marcas.'), findsOneWidget);
  });

  testWidgets('Cintas: aviso de cinta imposible y detalle con descripción', (t) async {
    final pk = _swsh()..version = 44;
    Ribbons.set(pk, 'RibbonChampionKalos', 1);
    await _pump(t, pk, GameVersion.swordShield);
    expect(find.textContaining('no se puede conseguir en los juegos'), findsOneWidget);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('teléfono 360×800 al ${(scale * 100).round()} %: Origen y Cintas sin desbordes', (t) async {
      final pk = _swsh()..version = 12;
      pk.eggLocation = 60002;
      Ribbons.giveAllValid(pk);
      Ribbons.setAffixed(pk, 'RibbonChampionSinnoh');
      await _pump(t, pk, GameVersion.swordShield, size: const Size(360, 800), scale: scale);
      final list = find.byType(Scrollable).first;
      for (final f in [find.text('Juego de origen'), find.text('Dar todas las válidas'), find.textContaining('Conmemorativas')]) {
        await t.scrollUntilVisible(f, 250, scrollable: list);
        await t.pump();
        expect(t.takeException(), isNull);
      }
      expect(find.textContaining('Muestra: '), findsOneWidget);
    });
  }
}
