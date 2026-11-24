// Ribbon Hunter: navegación (pestaña, buscador, ranking por niveles, nivel, guía, botón desde la Dex)
// y ningún desbordamiento en teléfono (320×568, 360×800, 430×932) ni escritorio.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/providers.dart';
import 'package:pkcore/pkcore.dart';

import 'arca_folder_test.dart' show memoryDb;
import 'dex_demo.dart';
import 'phone_layout_test.dart' show loadAppFonts;

void main() {
  setUpAll(loadAppFonts);

  Future<void> open(WidgetTester tester, String at, Size size, {Locale locale = const Locale('es', 'ES')}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = [locale];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final tmp = await tester.runAsync(() => Directory.systemTemp.createTemp('ribbon_master'));
    final repo = ArcaRepository(memoryDb(), ArcaFolder(IoFolderFs(tmp!)));
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        arcaRepositoryProvider.overrideWithValue(repo),
        globalDexProvider.overrideWith((ref) async => demoDex()),
      ],
      child: PKArkToolsApp(initialLocation: at),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> scrollAll(WidgetTester tester) async {
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) return;
    for (var i = 0; i < 40; i++) {
      await tester.drag(scrollables.first, const Offset(0, -500), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('pestaña, buscador y guía', (tester) async {
    await open(tester, '/cintas', const Size(1280, 900));
    expect(find.text('Ribbon Hunter'), findsWidgets);
    expect(find.text('Ranking por niveles'), findsWidgets);
    expect(find.byKey(ValueKey('rm-teaser-tier-${RibbonMaster.tiers().first.total}')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('rm-search')), 'raichu');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('rm-result-26-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('rm-result-26-1')), findsOneWidget); // Raichu de Alola
    await tester.tap(find.byKey(const ValueKey('rm-result-26-1')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('rm-guide-name')), findsOneWidget);
    expect(find.textContaining('Raichu'), findsWidgets);
    expect(find.byKey(const ValueKey('rm-step-smusum')), findsOneWidget);
    expect(find.textContaining('no existe antes de'), findsWidgets);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('ranking por niveles: niveles, origen común, nivel completo, filtro y guía', (tester) async {
    final tiers = RibbonMaster.tiers();
    final top = tiers.first;
    await open(tester, '/cintas/ranking', const Size(1280, 900), locale: const Locale('en', 'US'));
    expect(find.text('Ranking by tiers'), findsWidgets);
    expect(find.byKey(ValueKey('rm-tier-${top.total}')), findsOneWidget);
    expect(find.text('${top.total} ribbons · ${top.length} species & forms'), findsOneWidget);
    expect(find.text('Tier 1'), findsOneWidget);
    expect(find.byKey(ValueKey('rm-tier-origin-${top.total}')), findsOneWidget);
    expect(find.text('Common origin: Shadow Pokémon in Colosseum / XD'), findsOneWidget);
    // El segundo nivel también se ve, con su propio conteo.
    final second = tiers[1];
    expect(find.text('${second.total} ribbons · ${second.length} species & forms'), findsOneWidget);
    // Todos los niveles están (el último, tras desplazarse).
    final last = tiers.last;
    await tester.scrollUntilVisible(find.byKey(ValueKey('rm-tier-${last.total}')), 600, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(ValueKey('rm-tier-${last.total}')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(ValueKey('rm-tier-${top.total}')), -600, scrollable: find.byType(Scrollable).first);

    // Al entrar se ve la lista completa del nivel, en orden de Dex.
    await tester.tap(find.byKey(ValueKey('rm-tier-${top.total}')));
    await settle(tester);
    expect(find.text('Tier 1 · ${top.total} ribbons'), findsOneWidget);
    expect(find.byKey(const ValueKey('rm-tier-count')), findsOneWidget);
    final rows = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('rm-tier-row-'));
    final firstKeys = [for (final e in rows.evaluate()) (e.widget.key! as ValueKey<String>).value];
    final expected = [for (final r in top.routes) 'rm-tier-row-${r.species}-${r.form}'];
    expect(firstKeys, expected.sublist(0, firstKeys.length));
    final lastRow = top.routes.last;
    await tester.scrollUntilVisible(find.byKey(ValueKey('rm-tier-row-${lastRow.species}-${lastRow.form}')), 600,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(ValueKey('rm-tier-row-${lastRow.species}-${lastRow.form}')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('rm-tier-filter')), -600, scrollable: find.byType(Scrollable).first);

    // Filtro por número de Dex.
    final pick = top.routes[top.length ~/ 2];
    await tester.enterText(find.byKey(const ValueKey('rm-tier-filter')), '${pick.species}');
    await settle(tester);
    final matching = top.routes.where((r) => r.species == pick.species).length;
    expect(find.text('$matching results'), findsOneWidget);
    expect(rows, findsNWidgets(matching));

    // Al tocar una especie se abre su guía; atrás vuelve al nivel.
    await tester.ensureVisible(find.byKey(ValueKey('rm-tier-row-${pick.species}-${pick.form}')));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('rm-tier-row-${pick.species}-${pick.form}')));
    await settle(tester);
    expect(find.byKey(const ValueKey('rm-total')), findsOneWidget);
    expect(find.text('Max today'), findsWidgets);
    expect(find.text('Tier 1 of ${tiers.length} in the ranking · ${top.length} species & forms'), findsOneWidget);
    await tester.tap(find.byTooltip('Back').first);
    await settle(tester);
    expect(find.byKey(const ValueKey('rm-tier-filter')), findsOneWidget);
  });

  testWidgets('del inicio al nivel, de la guía a su nivel y redirección de /cintas/top', (tester) async {
    final top = RibbonMaster.tiers().first;
    await open(tester, '/cintas', const Size(1280, 900));
    await tester.tap(find.byKey(ValueKey('rm-teaser-tier-${top.total}')));
    await settle(tester);
    expect(find.text('Nivel 1 · ${top.total} cintas'), findsOneWidget);

    await open(tester, '/cintas', const Size(1280, 900));
    await tester.tap(find.byKey(const ValueKey('rm-see-ranking')));
    await settle(tester);
    expect(find.byKey(ValueKey('rm-tier-${top.total}')), findsOneWidget);

    final bulba = RibbonMaster.tierOf(1, 0)!;
    await open(tester, '/cintas/guia/1', const Size(1280, 900));
    expect(find.textContaining('Nivel ${bulba.position} de '), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rm-rank-pos')));
    await settle(tester);
    expect(find.byKey(const ValueKey('rm-tier-row-1-0')), findsOneWidget);

    await open(tester, '/cintas/top', const Size(1280, 900));
    expect(find.byKey(ValueKey('rm-tier-${top.total}')), findsOneWidget);

    await open(tester, '/cintas/ranking/999', const Size(1280, 900));
    expect(find.text('Ese nivel no existe.'), findsOneWidget);
  });

  testWidgets('botón de la ficha de la Dex y tus ejemplares', (tester) async {
    await open(tester, '/dex/especie/6', const Size(1280, 1400));
    await tester.tap(find.byKey(const ValueKey('dex-ribbon-guide')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('rm-guide-name')), findsOneWidget);
    await scrollAll(tester);
    expect(find.text('Tus ejemplares de esta especie'), findsOneWidget);
    expect(find.textContaining('Blaze'), findsOneWidget);
  });

  const sizes = [Size(320, 568), Size(360, 800), Size(430, 932), Size(1440, 900)];
  for (final size in sizes) {
    for (final at in [
      '/cintas',
      '/cintas/ranking',
      '/cintas/ranking/${RibbonMaster.tiers().first.total}',
      '/cintas/ranking/${RibbonMaster.tiers().reduce((a, b) => a.length >= b.length ? a : b).total}',
      '/cintas/ranking/${RibbonMaster.tiers().last.total}',
      '/cintas/guia/1',
      '/cintas/guia/26?forma=1',
      '/cintas/guia/6',
    ]) {
      testWidgets('sin desbordes en $at a ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
        await open(tester, at, size);
        await scrollAll(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
