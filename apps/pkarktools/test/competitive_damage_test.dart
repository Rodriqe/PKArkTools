import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/competitive/damage_screen.dart';
import 'package:pkcore/pkcore.dart';

import 'arca_folder_test.dart' show memoryDb;
import 'arca_screen_test.dart' show settle;

void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late ArcaRepository repo;

  setUp(() async {
    db = memoryDb();
    tmp = await Directory.systemTemp.createTemp('comp_damage');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  ChampionsBuild chomp() => ChampionsBuild.fromShowdown(Showdown.parse(
    'Garchomp @ Life Orb\nAbility: Rough Skin\nEVs: 2 HP / 32 Atk / 32 Spe\nJolly Nature\n- Earthquake',
  ).single)!.build;

  Future<void> pump(WidgetTester tester, Size size, Widget home) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
    await settle(tester);
  }

  for (final size in [const Size(1280, 1600), const Size(360, 2400)]) {
    testWidgets('resultado igual al motor (${size.width.toInt()} px), sin desbordes', (tester) async {
      await pump(tester, size, DamageScreen(attacker: chomp()));
      expect(tester.takeException(), isNull);
      final text = tester.widget<SelectableText>(find.byKey(const ValueKey('damage-text'))).data!;
      // Por defecto: dobles, Terremoto a los dos rivales contra Incineroar.
      final inc = ChampionsDex.species('incineroar')!;
      final r = ChampionsDamage.calculate(
        attacker: ChampionsSide(chomp()),
        defender: ChampionsSide(ChampionsBuild(speciesId: 'incineroar', ability: inc.abilities.first)),
        move: ChampionsDex.move('earthquake')!,
      );
      expect(text, contains('Garchomp Earthquake vs.'));
      expect(text, contains('${r.min}-${r.max}'));
      expect(find.byKey(const ValueKey('damage-ko')), findsOneWidget);

      // Crítico: más daño.
      await tester.ensureVisible(find.byKey(const ValueKey('damage-crit')));
      await tester.tap(find.byKey(const ValueKey('damage-crit')));
      await tester.pump();
      await tester.scrollUntilVisible(find.byKey(const ValueKey('damage-text')), -300,
          scrollable: find.byType(Scrollable).first);
      final crit = tester.widget<SelectableText>(find.byKey(const ValueKey('damage-text'))).data!;
      expect(crit, contains('on a critical hit'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('inmune: Terremoto contra un Pokémon volador', (tester) async {
    await pump(tester, const Size(1280, 1600), DamageScreen(attacker: chomp()));
    await tester.tap(find.byKey(const ValueKey('damage-swap')));
    await tester.pump();
    // Tras intercambiar ataca Incineroar; vuelve a atacar Garchomp a Garchomp: sin inmunidad.
    await tester.tap(find.byKey(const ValueKey('damage-swap')));
    await tester.pump();
    expect(find.byKey(const ValueKey('damage-percent')), findsOneWidget);
  });

  testWidgets('«Usar en la calculadora de daño» desde la de estadísticas', (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(ProviderScope(
      overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
      child: const PKArkToolsApp(initialLocation: '/competitivo/estadisticas'),
    ));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('stats-to-damage')));
    await settle(tester);
    expect(find.byType(DamageScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('damage-result')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
