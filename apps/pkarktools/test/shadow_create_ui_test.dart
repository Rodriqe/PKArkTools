import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/editor/shadow_panel.dart';

/// Crear Pokémon oscuros desde la interfaz: selector de encuentros y sección
/// «Pokémon oscuro» del editor.
void main() {
  Future<void> host(WidgetTester tester, Widget Function(BuildContext) child) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: Builder(builder: child))),
    ));
  }

  testWidgets('el selector lista los oscuros de XD, filtra y devuelve el elegido', (tester) async {
    ShadowChoice? got;
    await host(
      tester,
      (context) => TextButton(
        onPressed: () async => got = await ShadowPicker.show(context, GameVersion.xd),
        child: const Text('abrir'),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Elige un Pokémon oscuro'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('shadow-search')), 'teddiursa');
    await tester.pump();
    expect(find.text('Teddiursa'), findsOneWidget);
    await tester.tap(find.text('Teddiursa'));
    await tester.tap(find.text('Purificado'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('shadow-pick-create')));
    await tester.pumpAndSettle();
    expect(got!.encounter.species, 216);
    expect(got!.encounter.shadowId, 1);
    expect(got!.purified, isTrue);
  });

  testWidgets('editor de Colosseum: un Pokémon normal se puede convertir en oscuro', (tester) async {
    final ed = SaveEditor.open(SyntheticSaves.colosseumDemo());
    final pk = ed.get(const SlotRef.party(0))!; // Umbreon inicial
    expect(pk.gc!.shadowId, 0);
    late StateSetter set;
    await host(
      tester,
      (context) => StatefulBuilder(builder: (context, s) {
        set = s;
        return ShadowPanel(pk: pk, game: GameVersion.colosseum, mutate: (f) => set(() => f(pk)));
      }),
    );
    await tester.tap(find.byKey(const ValueKey('shadow-make')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('shadow-search')), 'makuhita');
    await tester.pump();
    await tester.tap(find.text('Makuhita'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('shadow-pick-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sustituir'));
    await tester.pumpAndSettle();
    expect(pk.species, 296);
    expect(pk.gc!.shadowId, 1);
    expect(pk.gc!.isShadow, isTrue);
    expect(find.byKey(const ValueKey('shadow-gauge')), findsOneWidget);
    // Purificar con confirmación: Cinta Nacional.
    await tester.tap(find.byKey(const ValueKey('shadow-purify')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Purificar'));
    await tester.pumpAndSettle();
    expect(pk.gc!.isPurified, isTrue);
    expect(Ribbons.get(pk, 'RibbonNational'), 1);
    expect(Legality.check(pk, GameVersion.colosseum).where((i) => i.severity == LegalitySeverity.warning), isEmpty);
  });
}
