import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/events/event_explorer.dart';

/// Explorador de eventos (Regalo Misterioso) y «Crear Pokémon → Desde un evento».
void main() {
  Future<void> host(WidgetTester tester, Widget Function(BuildContext) child, {Size size = const Size(1000, 1400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: child),
      ),
    ));
  }

  testWidgets('explorador: busca, filtra por generación y abre la ficha con los datos fijos', (tester) async {
    await host(tester, (_) => const EventExplorerScreen());
    await tester.pumpAndSettle();
    expect(find.text('Eventos (Regalo Misterioso)'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('events-search')), 'MYSTRY');
    await tester.pumpAndSettle();
    final mew = EventDb.all.firstWhere((g) => g.fixedOtName == 'MYSTRY');
    expect(find.byKey(ValueKey('event-${mew.id}')), findsOneWidget);
    // Filtro de generación: el Mew de Gen 3 desaparece en Gen 4.
    await tester.tap(find.byKey(const ValueKey('events-filter-gen')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gen 4').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('events-empty')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('events-filter-gen')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('event-${mew.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Entrenador original'), findsOneWidget);
    expect(find.text('MYSTRY'), findsWidgets);
    expect(find.text('Distribución terminada'), findsOneWidget);
    // Gen 3 no tiene archivo de tarjeta: no se ofrece exportar.
    expect(find.byKey(const ValueKey('event-export')), findsNothing);
  });

  testWidgets('explorador filtrado por especie (desde la Dex) con tarjeta exportable', (tester) async {
    await host(tester, (_) => const EventExplorerScreen(species: 807)); // Zeraora
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('events-species-chip')), findsOneWidget);
    final first = EventDb.forSpecies(807).first;
    await tester.tap(find.byKey(ValueKey('event-${first.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('event-export')), findsOneWidget);
  });

  testWidgets('selector: solo eventos creables en Espada/Escudo y devuelve el elegido', (tester) async {
    EventChoice? got;
    await host(
      tester,
      (context) => Scaffold(
        body: TextButton(
          onPressed: () async => got = await EventPicker.show(context, GameVersion.swordShield, saveLanguage: 7),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Crear desde un evento'), findsOneWidget);
    final g = EventDb.creatableIn(GameVersion.swordShield).firstWhere((g) => g.species == 807);
    await tester.enterText(find.byKey(const ValueKey('events-search')), 'zeraora');
    await tester.pumpAndSettle();
    // Solo PK8: ningún Zeraora de Gen 7.
    final shown = EventDb.forSpecies(807).where((e) => find.byKey(ValueKey('event-${e.id}')).evaluate().isNotEmpty);
    expect(shown.every((e) => e.format == PkFormat.pk8), isTrue);
    await tester.tap(find.byKey(ValueKey('event-${g.id}')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('event-create')));
    await tester.tap(find.byKey(const ValueKey('event-create')));
    await tester.pumpAndSettle();
    expect(got, isNotNull);
    expect(got!.gift, same(g));
    expect(got!.language, EventFactory.languageFor(g, 7));
    // El Pokémon creado es legal para pkcore.
    final pk = EventFactory.create(got!.gift, GameVersion.swordShield,
        const TrainerData(name: 'Prueba', tid: 1234, sid: 4321, gender: 1), language: got!.language);
    expect(Legality.check(pk, GameVersion.swordShield), isEmpty);
  });
}
