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

import 'arca_screen_test.dart' show settle;

/// Logo grande de la cabecera de la barra lateral: cabe en el rail (compacto y
/// extendido) sin desbordes, en tema claro y oscuro.
void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late ArcaRepository repo;

  setUp(() async {
    db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    tmp = await Directory.systemTemp.createTemp('rail_logo');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  // (tamaño, rail extendido)
  const sizes = [
    (Size(720, 560), false), // rail estrecho justo en el corte, ventana baja
    (Size(1000, 700), false),
    (Size(1280, 800), true),
    (Size(1440, 900), true),
    (Size(1920, 1080), true),
  ];

  for (final theme in ['dark', 'light']) {
    for (final (size, extended) in sizes) {
      testWidgets('logo de la barra lateral a ${size.width.toInt()}×${size.height.toInt()} ($theme)', (tester) async {
        await tester.runAsync(() => repo.setSetting('themeMode', theme));
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.localesTestValue = const [Locale('es')];
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        await tester.pumpWidget(ProviderScope(
          overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
          child: const PKArkToolsApp(),
        ));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        });
        await settle(tester, until: find.byKey(const ValueKey('rail-logo')));
        expect(tester.takeException(), isNull);

        final rail = tester.getRect(find.byType(NavigationRail));
        final logo = tester.getRect(find.byKey(const ValueKey('rail-logo')));
        final mark = tester.getRect(find.byType(BrandMark));
        final name = tester.getRect(find.byKey(const ValueKey('rail-logo-name')));
        // Logo notoriamente más grande que antes (48 px).
        expect(mark.height, extended ? 96 : 72);
        // Todo dentro del rail y el nombre debajo del logo.
        for (final r in [logo, mark, name]) {
          expect(r.left, greaterThanOrEqualTo(rail.left));
          expect(r.right, lessThanOrEqualTo(rail.right));
          expect(r.bottom, lessThanOrEqualTo(rail.bottom));
        }
        expect(name.top, greaterThanOrEqualTo(mark.bottom));
        // Centrado en el rail.
        expect((mark.center.dx - rail.center.dx).abs(), lessThan(4));
        // Los destinos caben debajo (sin solaparse con la cabecera).
        final first = tester.getRect(find.text('Arca').first);
        expect(first.top, greaterThan(name.bottom));
        final last = tester.getRect(find.text('Ajustes').first);
        expect(last.bottom, lessThanOrEqualTo(size.height));
      });
    }
  }
}
