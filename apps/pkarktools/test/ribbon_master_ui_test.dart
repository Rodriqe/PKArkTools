// Ribbon Master: navegación (pestaña, buscador, Top 50, guía, botón desde la Dex)
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
    expect(find.text('Ribbon Master'), findsWidgets);
    expect(find.text('Top 50'), findsWidgets);
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

  testWidgets('Top 50 con empates y paso a la guía', (tester) async {
    await open(tester, '/cintas/top', const Size(1280, 900), locale: const Locale('en', 'US'));
    final first = RibbonMaster.top(50).first.route;
    expect(find.byKey(ValueKey('rm-rank-${first.species}-${first.form}')), findsOneWidget);
    expect(find.text('tie'), findsWidgets);
    await tester.tap(find.byKey(ValueKey('rm-rank-${first.species}-${first.form}')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('rm-total')), findsOneWidget);
    expect(find.text('Max today'), findsWidgets);
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
    for (final at in ['/cintas', '/cintas/top', '/cintas/guia/1', '/cintas/guia/26?forma=1', '/cintas/guia/6']) {
      testWidgets('sin desbordes en $at a ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
        await open(tester, at, size);
        await scrollAll(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
