import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/competitive/stats_screen.dart';

import 'arca_folder_test.dart' show memoryDb;
import 'arca_screen_test.dart' show settle;

void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late ArcaRepository repo;

  setUp(() async {
    db = memoryDb();
    tmp = await Directory.systemTemp.createTemp('comp_stats');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StatsScreen(),
      ),
    ));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
    await settle(tester);
  }

  String stat(WidgetTester tester, int i) => tester.widget<Text>(find.byKey(ValueKey('stats-stat-$i'))).data!;

  testWidgets('Champions: estadísticas con puntos y naturaleza neutra', (tester) async {
    await pump(tester);
    // Garchomp sin puntos: PS 108+75, Ataque 130+20.
    expect(stat(tester, 0), '183');
    expect(stat(tester, 1), '150');
    await tester.enterText(find.byKey(const ValueKey('stats-sp-1')), '32');
    await tester.pump();
    expect(stat(tester, 1), '182');
    expect(tester.widget<Text>(find.byKey(const ValueKey('stats-sp-total'))).data, 'Puntos: 32 / 66');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pegar de Showdown carga el set (con su Mega)', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('stats-from-showdown')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('paste-showdown-text')),
      'Garchomp @ Garchompite\nAbility: Rough Skin\nEVs: 2 HP / 32 Atk / 32 Spe\nJolly Nature\n- Earthquake',
    );
    await tester.tap(find.byKey(const ValueKey('paste-showdown-ok')));
    await settle(tester);
    // Mega Garchomp: 108/170/115/120/95/92 → PS 185, Ataque 222, Vel 158.
    expect(stat(tester, 0), '185');
    expect(stat(tester, 1), '222');
    expect(stat(tester, 5), '158');
  });
}
