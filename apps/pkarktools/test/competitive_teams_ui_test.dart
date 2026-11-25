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
import 'package:pkarktools/ui/competitive/teams_screen.dart';

import 'arca_folder_test.dart' show memoryDb;
import 'arca_screen_test.dart' show settle;

void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late ArcaRepository repo;

  setUp(() async {
    db = memoryDb();
    tmp = await Directory.systemTemp.createTemp('comp_teams');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  for (final size in [const Size(1280, 1000), const Size(360, 800)]) {
    testWidgets('crear equipo, añadir un miembro y guardar en el Arca (${size.width.toInt()} px)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.localesTestValue = const [Locale('es')];
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
          child: const PKArkToolsApp(initialLocation: '/competitivo'),
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
      await settle(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('comp-teams')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('comp-teams')));
      await settle(tester);
      expect(find.byType(TeamsScreen), findsOneWidget);
      expect(find.text('Todavía no hay equipos.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('teams-new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('team-name-field')), 'Lluvia');
      await tester.tap(find.byKey(const ValueKey('team-name-ok')));
      await settle(tester, until: find.byType(TeamEditorScreen));
      expect(find.byType(TeamEditorScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('team-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('team-save')));
      await settle(tester, until: find.text('Equipo guardado.'));
      expect(find.text('Equipo guardado.'), findsOneWidget);
      final file = File('${tmp.path}/PKArkTools/Competitive/Teams/Lluvia.json');
      final alt = File('${tmp.path}/Competitive/Teams/Lluvia.json');
      expect(await tester.runAsync(() async => await file.exists() || await alt.exists()), isTrue);

      await tester.tap(find.byType(BackButton));
      await settle(tester, until: find.byKey(const ValueKey('team-Lluvia')));
      expect(find.byKey(const ValueKey('team-Lluvia')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
