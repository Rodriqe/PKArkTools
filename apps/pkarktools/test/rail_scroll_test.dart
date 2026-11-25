import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/ui/common/brand_mark.dart';
import 'package:pkarktools/ui/settings/settings_screen.dart';

import 'arca_screen_test.dart' show settle;

/// Barra lateral en pantallas bajas (teléfonos en horizontal, como el AYN
/// Odin3 a 1920×1080 físicos): el logo conserva su tamaño y queda fijo arriba,
/// y la lista de secciones se desplaza para que Ajustes siempre se alcance.
void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late ArcaRepository repo;

  setUp(() async {
    db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    tmp = await Directory.systemTemp.createTemp('rail_scroll');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> pumpApp(WidgetTester tester, Size physical, double dpr, {String initial = '/arca'}) async {
    tester.view.physicalSize = physical;
    tester.view.devicePixelRatio = dpr;
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
        child: PKArkToolsApp(initialLocation: initial),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
    await settle(tester);
  }

  Finder inRail(String text) => find.descendant(of: find.byType(NavigationRail), matching: find.text(text));

  // (nombre, tamaño físico, DPR, rail extendido, ¿la lista desborda?)
  const cases = [
    ('800×400', Size(800, 400), 1.0, false, true),
    // AYN Odin3: 1920×1080 a 420 dpi (DPR 2.625) ≈ 731×411 dp.
    ('Odin3 1920×1080 @2.625', Size(1920, 1080), 2.625, false, true),
    ('1920×1080 @2.25', Size(1920, 1080), 2.25, false, true),
    // Rango del Odin3 en horizontal (420–480 dpi): 360–411 dp de alto.
    ('732×411 dp', Size(732 * 2.625, 411 * 2.625), 2.625, false, true),
    ('780×393 dp', Size(780 * 2.75, 393 * 2.75), 2.75, false, true),
    ('840×360 dp', Size(840 * 3.0, 360 * 3.0), 3.0, false, true),
    ('tableta 1280×800', Size(1280, 800), 1.0, true, false),
    ('escritorio 1920×1080', Size(1920, 1080), 1.0, true, false),
  ];

  for (final (name, physical, dpr, extended, overflows) in cases) {
    testWidgets('rail a $name: logo fijo de su tamaño y Ajustes alcanzable', (tester) async {
      await pumpApp(tester, physical, dpr);
      expect(tester.takeException(), isNull);
      final height = physical.height / dpr;
      expect(find.byType(NavigationRail), findsOneWidget);

      final mark = tester.getRect(find.byType(BrandMark));
      expect(mark.height, extended ? 96 : 72);

      final scroll = find.byKey(const ValueKey('rail-scroll'));
      final scrollable = find.descendant(of: scroll, matching: find.byType(Scrollable));
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent > 0, overflows);
      expect(tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('rail-more-fade'))).opacity, overflows ? 1 : 0);

      // Todas las secciones se alcanzan; al final, Ajustes.
      for (final label in ['Arca', 'Dex', 'Competitivo', 'Ajustes']) {
        await tester.scrollUntilVisible(inRail(label), 40, scrollable: scrollable);
        final r = tester.getRect(inRail(label));
        expect(r.bottom, lessThanOrEqualTo(height));
        expect(r.top, greaterThanOrEqualTo(mark.bottom));
      }
      // El logo no se movió al desplazar.
      expect(tester.getRect(find.byType(BrandMark)), mark);
      if (overflows) {
        expect(position.pixels, greaterThan(0));
        // Al final de la lista se apaga el degradado de «hay más».
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('rail-more-fade'))).opacity, 0);
      }

      await tester.tap(inRail('Ajustes'));
      await settle(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex, 5);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Odin3: abrir en Ajustes desplaza la lista hasta el destino', (tester) async {
    await pumpApp(tester, const Size(1920, 1080), 2.625, initial: '/ajustes');
    expect(find.byType(SettingsScreen), findsOneWidget);
    final r = tester.getRect(inRail('Ajustes'));
    expect(r.bottom, lessThanOrEqualTo(1080 / 2.625));
    expect(tester.getRect(find.byType(BrandMark)).height, 72);
    expect(tester.takeException(), isNull);
  });

  testWidgets('teléfono 640×360 en horizontal: barra inferior con Ajustes', (tester) async {
    await pumpApp(tester, const Size(640, 360), 1.0);
    expect(find.byType(NavigationRail), findsNothing);
    await tester.tap(find.byKey(const ValueKey('nav-5')));
    await settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
