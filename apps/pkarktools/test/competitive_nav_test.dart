// Navegación de la pestaña Competitivo: barra lateral (escritorio) y barra
// inferior (teléfono), con los atajos de siempre apuntando a la nueva ruta.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/ui/activity/activity_screen.dart';
import 'package:pkarktools/ui/competitive/competitive_screen.dart';
import 'package:pkarktools/ui/competitive/showdown_screen.dart';
import 'package:pkarktools/ui/competitive/stats_screen.dart';
import 'package:pkarktools/ui/tools/champions_screen.dart';

import 'arca_folder_test.dart' show memoryDb;
import 'arca_screen_test.dart' show settle;
import 'phone_layout_test.dart' show loadAppFonts;

void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late ArcaRepository repo;

  setUpAll(loadAppFonts);

  setUp(() async {
    db = memoryDb();
    tmp = await Directory.systemTemp.createTemp('comp_nav');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> pumpApp(WidgetTester tester, Size size, {String initial = '/arca', String lang = 'es'}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = [Locale(lang)];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(ProviderScope(
      overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
      child: PKArkToolsApp(initialLocation: initial),
    ));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
    await settle(tester);
  }

  testWidgets('escritorio: Competitivo en la barra lateral y sus secciones', (tester) async {
    await pumpApp(tester, const Size(1280, 860));
    final rail = find.byType(NavigationRail);
    expect(rail, findsOneWidget);
    expect(tester.widget<NavigationRail>(rail).destinations, hasLength(6));
    await tester.tap(find.descendant(of: rail, matching: find.text('Competitivo')));
    await settle(tester);
    expect(find.byType(CompetitiveScreen), findsOneWidget);
    expect(tester.widget<NavigationRail>(rail).selectedIndex, 2);
    expect(find.byKey(const ValueKey('comp-regulation')), findsOneWidget);

    for (final (key, type) in [
      ('comp-format', ChampionsScreen),
      ('comp-stats', StatsScreen),
      ('comp-showdown', ShowdownScreen),
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await settle(tester);
      expect(find.byType(type), findsOneWidget, reason: key);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.byType(CompetitiveScreen), findsOneWidget);
    }
  });

  testWidgets('el enlace viejo /dex/formato-oficial lleva a Competitivo', (tester) async {
    await pumpApp(tester, const Size(1280, 860), initial: '/dex/formato-oficial');
    expect(find.byType(ChampionsScreen), findsOneWidget);
    expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex, 2);
  });

  testWidgets('Dex: el botón de formato oficial abre Competitivo', (tester) async {
    await pumpApp(tester, const Size(1280, 860), initial: '/dex');
    await tester.tap(find.byKey(const ValueKey('dex-official-format')));
    await settle(tester);
    expect(find.byType(ChampionsScreen), findsOneWidget);
    expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex, 2);
  });

  for (final width in [320.0, 360.0, 430.0]) {
    for (final lang in ['es', 'en']) {
      testWidgets('teléfono ${width.toInt()} px ($lang): barra de 5 con Competitivo; Actividad desde el Arca',
          (tester) async {
        // Con alguna partida (el Arca vacío no tiene cabecera ni actividad).
        await tester.runAsync(() async {
          final e = SyntheticSaves.demoSet().entries.first;
          await repo.importBytes(e.value, fileName: e.key, origin: ImportOrigin.demo);
        });
        await pumpApp(tester, Size(width, 800), lang: lang);
        final bar = find.byType(NavigationBar);
        expect(bar, findsOneWidget);
        expect(tester.widget<NavigationBar>(bar).destinations, hasLength(5));
        // Las etiquetas caben enteras en su hueco (fuente real de la app).
        for (final p in tester.renderObjectList<RenderParagraph>(find.descendant(of: bar, matching: find.byType(RichText)))) {
          expect(p.didExceedMaxLines, isFalse, reason: p.text.toPlainText());
          expect(p.getMaxIntrinsicWidth(double.infinity), lessThanOrEqualTo(width / 5),
              reason: '«${p.text.toPlainText()}» no cabe');
        }
        await tester.tap(find.byKey(const ValueKey('nav-2')));
        await settle(tester);
        expect(find.byType(CompetitiveScreen), findsOneWidget);
        expect(tester.widget<NavigationBar>(bar).selectedIndex, 2);
        expect(tester.takeException(), isNull);

        // Actividad: botón en la cabecera del Arca (el Arca queda resaltado).
        await tester.tap(find.byKey(const ValueKey('nav-0')));
        await settle(tester);
        await tester.tap(find.byKey(const ValueKey('arca-activity')));
        await settle(tester);
        expect(find.byType(ActivityScreen), findsOneWidget);
        expect(tester.widget<NavigationBar>(bar).selectedIndex, 0);
        await tester.tap(find.byKey(const ValueKey('activity-back')));
        await settle(tester);
        expect(find.byType(ActivityScreen), findsNothing);
      });
    }
  }
}
