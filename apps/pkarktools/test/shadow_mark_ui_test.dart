import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/common/shadow_mark.dart';
import 'package:pkarktools/ui/detail/pokemon_views.dart';
import 'package:pkarktools/ui/editor/pokemon_editor.dart';

/// Marca de Pokémon oscuro: solo en saves de Colosseum/XD, solo si sigue
/// oscuro (un purificado no lleva marca) y nunca en otros juegos.
void main() {
  // Equipo: normal, oscuro, purificado. Caja 1: normal, oscuro, purificado.
  SaveEditor xdEditor() => SaveEditor.open(SyntheticSaves.xd(
        party: const [
          SynthGcMon(133, level: 25, nickname: 'EON'),
          SynthGcMon(37, level: 20, shadow: 1),
          SynthGcMon(216, level: 15, shadow: 2),
        ],
        boxes: const {
          0: [SynthGcMon(27, level: 23), SynthGcMon(363, level: 18, shadow: 1, gauge: 300), SynthGcMon(296, level: 18, shadow: 2)],
        },
      ));

  List<Pkm> party(SaveEditor e) => [
        for (var i = 0; i < 6; i++) ?e.get(SlotRef.party(i)),
      ];

  Widget app(Widget body, {ThemeData? theme, Locale locale = const Locale('es')}) => ProviderScope(
        child: MaterialApp(
          theme: theme ?? AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: body,
        ),
      );

  Widget storage(SaveEditor e, GameVersion game) => Scaffold(
        body: Consumer(
          builder: (context, ref, _) {
            final actions = StorageActions(context, ref, 1, game);
            return SingleChildScrollView(
              child: Column(children: [
                PartyGrid(party: party(e), actions: actions, capacity: 6),
                BoxBrowser(editor: e, actions: actions, accent: Colors.purple, revision: 0),
              ]),
            );
          },
        ),
      );

  Future<void> size(WidgetTester t, Size s) async {
    t.view.physicalSize = s;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  test('ShadowMark.applies: oscuro sí, purificado y normal no; fuera de Colosseum/XD nunca', () {
    final e = xdEditor();
    final normal = e.get(const SlotRef.party(0))!;
    final shadow = e.get(const SlotRef.party(1))!;
    final purified = e.get(const SlotRef.party(2))!;
    expect(shadow.gc!.isShadow, isTrue);
    expect(purified.gc!.isPurified, isTrue);
    expect(ShadowMark.applies(shadow, GameVersion.xd), isTrue);
    expect(ShadowMark.applies(shadow, GameVersion.colosseum), isTrue);
    expect(ShadowMark.applies(purified, GameVersion.xd), isFalse);
    expect(ShadowMark.purified(purified, GameVersion.xd), isTrue);
    expect(ShadowMark.applies(normal, GameVersion.xd), isFalse);
    expect(ShadowMark.purified(normal, GameVersion.xd), isFalse);
    for (final g in [GameVersion.emerald, GameVersion.fireRedLeafGreen, GameVersion.diamondPearl]) {
      expect(ShadowMark.applies(shadow, g), isFalse, reason: g.name);
      expect(ShadowMark.purified(purified, g), isFalse, reason: g.name);
    }
  });

  for (final dark in [false, true]) {
    testWidgets('XD (${dark ? 'oscuro' : 'claro'}): equipo y caja marcan solo a los oscuros', (t) async {
      await size(t, const Size(1000, 1400));
      final e = xdEditor();
      await t.pumpWidget(app(storage(e, GameVersion.xd), theme: dark ? AppTheme.dark() : AppTheme.light()));
      await t.pump();
      // Vulpix (equipo) y Spheal (caja): insignia y halo; nada más.
      expect(find.byKey(const ValueKey('shadow-mark')), findsNWidgets(2));
      expect(find.byKey(const ValueKey('shadow-aura')), findsNWidgets(2));
      // La explicación está en el tooltip de la insignia.
      final tips = t.widgetList<Tooltip>(find.ancestor(of: find.byKey(const ValueKey('shadow-mark')), matching: find.byType(Tooltip)));
      expect(tips.map((w) => w.message), everyElement(contains('corazón cerrado')));
    });
  }

  testWidgets('XD: mantener pulsada la insignia muestra la explicación (en inglés)', (t) async {
    await size(t, const Size(1000, 1400));
    await t.pumpWidget(app(storage(xdEditor(), GameVersion.xd), locale: const Locale('en')));
    await t.pump();
    await t.longPress(find.byKey(const ValueKey('shadow-mark')).first);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Shadow Pokémon: its heart is closed'), findsWidgets);
    await t.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('GBA: sin marca de oscuro', (t) async {
    await size(t, const Size(1000, 1400));
    final e = SaveEditor.open(SyntheticSaves.demoSet()['Esmeralda.sav']!);
    await t.pumpWidget(app(storage(e, GameVersion.emerald)));
    await t.pump();
    expect(find.byKey(const ValueKey('shadow-mark')), findsNothing);
    expect(find.byKey(const ValueKey('shadow-aura')), findsNothing);
  });

  testWidgets('el mismo save de XD abierto como otro juego no marca nada', (t) async {
    await size(t, const Size(1000, 1400));
    final e = xdEditor();
    await t.pumpWidget(app(storage(e, GameVersion.emerald)));
    await t.pump();
    expect(find.byKey(const ValueKey('shadow-mark')), findsNothing);
  });

  group('cabecera del editor', () {
    Future<void> open(WidgetTester t, Pkm pk, GameVersion game) async {
      await size(t, const Size(1200, 1600));
      await t.pumpWidget(app(PokemonEditorScreen(game: game, initial: pk, slotLabel: 'Equipo, hueco 1')));
      await t.pump();
    }

    testWidgets('oscuro: chip «Pokémon oscuro» y progreso del medidor', (t) async {
      final pk = xdEditor().get(const SlotRef.box(0, 1))!; // Spheal, medidor 300
      await open(t, pk, GameVersion.xd);
      expect(find.byKey(const ValueKey('shadow-chip')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('shadow-chip')), matching: find.text('Pokémon oscuro')), findsOneWidget);
      expect(find.byKey(const ValueKey('shadow-purified-chip')), findsNothing);
      expect(find.byKey(const ValueKey('shadow-heart')), findsOneWidget);
      final max = ShadowMark.maxGauge(pk.gc!)!;
      expect(find.textContaining('medidor 300 / $max'), findsOneWidget);
    });

    testWidgets('purificado: dice «Purificado», sin chip de oscuro ni medidor', (t) async {
      await open(t, xdEditor().get(const SlotRef.party(2))!, GameVersion.xd);
      expect(find.byKey(const ValueKey('shadow-purified-chip')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('shadow-purified-chip')), matching: find.text('Purificado')), findsOneWidget);
      expect(find.byKey(const ValueKey('shadow-chip')), findsNothing);
      expect(find.byKey(const ValueKey('shadow-heart')), findsNothing);
    });

    testWidgets('normal: sin chip', (t) async {
      await open(t, xdEditor().get(const SlotRef.party(0))!, GameVersion.xd);
      expect(find.byKey(const ValueKey('shadow-chip')), findsNothing);
      expect(find.byKey(const ValueKey('shadow-purified-chip')), findsNothing);
      expect(find.byKey(const ValueKey('shadow-heart')), findsNothing);
    });
  });
}
