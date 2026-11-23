import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/settings/game_folders.dart';
import 'package:pkarktools/ui/shell.dart';

import 'arca_screen_test.dart' show settle;

void main() {
  group('selector de juegos', () {
    Future<Set<GameVersion>?> open(WidgetTester tester, {Set<GameVersion> owned = const {}, Set<GameVersion> existing = const {}}) async {
      Set<GameVersion>? result;
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<Set<GameVersion>>(
                context: context,
                builder: (_) => GameFoldersPicker(owned: owned, existing: existing),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('por defecto los que tengo; chips de todos/ninguno/plataforma y casilla por generación', (tester) async {
      await open(tester, owned: {GameVersion.emerald}, existing: {GameVersion.emerald});
      // Esmeralda ya existe: nada que crear.
      expect(find.text('Crear 0 carpetas'), findsOneWidget);
      expect(find.text('ya existe'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('platform-nintendoSwitch')));
      await tester.pump();
      expect(find.text('Crear 6 carpetas'), findsOneWidget);

      await tester.tap(find.text('Ninguno'));
      await tester.pump();
      expect(find.text('Crear 0 carpetas'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('gen-4')));
      await tester.tap(find.byKey(const ValueKey('gen-4')));
      await tester.pump();
      expect(find.text('Crear 3 carpetas'), findsOneWidget);

      await tester.tap(find.text('Todos'));
      await tester.pump();
      expect(find.text('Crear ${GameVersion.values.length - 1} carpetas'), findsOneWidget);

      await tester.tap(find.text('Los que tengo'));
      await tester.pump();
      expect(find.text('Crear 0 carpetas'), findsOneWidget);
    });

    testWidgets('confirmar devuelve la selección', (tester) async {
      Set<GameVersion>? got;
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => got = await showDialog<Set<GameVersion>>(
                context: context, builder: (_) => const GameFoldersPicker()),
            child: const Text('abrir'),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      for (final k in ['game-emerald', 'game-pt']) {
        await tester.ensureVisible(find.byKey(ValueKey(k)));
        await tester.tap(find.byKey(ValueKey(k)));
      }
      await tester.pump();
      await tester.tap(find.text('Crear 2 carpetas'));
      await tester.pumpAndSettle();
      expect(got, {GameVersion.emerald, GameVersion.platinum});
    });
  });

  group('pregunta tras elegir la carpeta', () {
    late ArcaDatabase db;
    late Directory tmp;
    late ArcaRepository repo;

    setUp(() async {
      db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
      tmp = await Directory.systemTemp.createTemp('arca_gf');
      repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
    });

    tearDown(() async {
      await db.close();
      await tmp.delete(recursive: true);
    });

    Future<ProviderContainer> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
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
      await settle(tester);
      return ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    }

    List<String> gameDirs() => [
          for (final e in Directory('${tmp.path}/PKArkTools').listSync())
            if (e is Directory) e.path.split('/').last,
        ];

    testWidgets('«Ahora no» no crea nada y no se vuelve a preguntar', (tester) async {
      final c = await pumpApp(tester);
      await tester.runAsync(() => c.read(gameFoldersPromptProvider.notifier).request());
      await settle(tester, until: find.text('¿Quieres crear las carpetas de tus juegos?'));
      expect(find.text('Sí, todos los juegos'), findsOneWidget);
      expect(find.text('Elegir juegos…'), findsOneWidget);
      await tester.tap(find.text('Ahora no'));
      await settle(tester);
      expect(find.text('¿Quieres crear las carpetas de tus juegos?'), findsNothing);
      expect(Directory('${tmp.path}/PKArkTools').existsSync() ? gameDirs() : const <String>[], isEmpty);
      expect(await tester.runAsync(() => repo.getSetting(GameFoldersPrompt.askedKey)), '1');
      // Siguiente arranque: no se pregunta.
      await tester.runAsync(() => c.read(gameFoldersPromptProvider.notifier).request());
      await settle(tester);
      expect(find.text('¿Quieres crear las carpetas de tus juegos?'), findsNothing);
    });

    testWidgets('«Sí, todos los juegos» crea una carpeta por juego con su LEEME', (tester) async {
      final c = await pumpApp(tester);
      await tester.runAsync(() => c.read(gameFoldersPromptProvider.notifier).request());
      await settle(tester, until: find.text('Sí, todos los juegos'));
      await tester.tap(find.text('Sí, todos los juegos'));
      await settle(tester, until: find.textContaining('Carpetas creadas'));
      expect(gameDirs(), hasLength(GameVersion.values.length));
      expect(File('${tmp.path}/PKArkTools/Pokémon Esmeralda/LEEME.txt').existsSync(), isTrue);
    });

    testWidgets('Ajustes → Crear carpetas de juegos abre el selector', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Ajustes').first);
      await settle(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('create-game-folders')));
      await tester.tap(find.byKey(const ValueKey('create-game-folders')));
      await settle(tester, until: find.text('Carpetas de juegos'));
      await tester.ensureVisible(find.byKey(const ValueKey('game-emerald')));
      await tester.tap(find.byKey(const ValueKey('game-emerald')));
      await tester.pump();
      await tester.tap(find.text('Crear 1 carpeta'));
      await settle(tester, until: find.textContaining('Carpetas creadas'));
      expect(gameDirs(), ['Pokémon Esmeralda']);
    });
  });
}
