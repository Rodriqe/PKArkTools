import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/providers.dart';

/// Deja avanzar el trabajo asíncrono real (drift, isolates) y repinta.
Future<void> settle(WidgetTester tester, {Finder? until}) async {
  for (var i = 0; i < 40; i++) {
    if (i >= 6 && (until == null || until.evaluate().isNotEmpty)) break;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late ArcaRepository repo;

  setUp(() async {
    db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    tmp = await Directory.systemTemp.createTemp('arca_test');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> pumpApp(WidgetTester tester, {Size size = const Size(1280, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(ProviderScope(
      overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
      child: const PKArkToolsApp(),
    ));
    // Desmontar antes de que el framework verifique timers pendientes: así
    // drift cancela sus streams y vacía sus temporizadores.
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
    await settle(tester);
  }

  Future<void> importDemo(WidgetTester tester, Map<String, Uint8List> files) async {
    await tester.runAsync(() async {
      for (final e in files.entries) {
        await repo.importBytes(e.value, fileName: e.key, origin: ImportOrigin.demo);
      }
    });
  }

  testWidgets('Arca vacía muestra la invitación a importar', (tester) async {
    await pumpApp(tester);
    expect(find.text('Tu Arca está vacía'), findsOneWidget);
    expect(find.text('Probar con partidas de ejemplo'), findsOneWidget);
    expect(find.text('Importar'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('las partidas importadas aparecen como tarjetas', (tester) async {
    await importDemo(tester, {
      'Esmeralda.sav': SyntheticSaves.gen3(
        trainer: const SynthTrainer(name: 'MAY', hours: 48),
        party: const [SynthMon(254, level: 52), SynthMon(282, level: 49, shiny: true)],
      ),
      'main': SyntheticSaves.swordShield(trainer: const SynthTrainer(name: 'Gloria', versionId: 44, hours: 210)),
    });
    await pumpApp(tester);
    expect(find.text('2 partidas a salvo'), findsOneWidget);
    expect(find.text('MAY'), findsOneWidget);
    expect(find.text('Gloria'), findsOneWidget);
    expect(find.text('Pokémon Esmeralda'), findsOneWidget);
    expect(find.text('Pokémon Espada'), findsOneWidget);
    expect(find.text('48 h'), findsOneWidget);
  });

  testWidgets('el buscador filtra por entrenador', (tester) async {
    await importDemo(tester, {
      'a.sav': SyntheticSaves.gen3(trainer: const SynthTrainer(name: 'MAY')),
      'b.sav': SyntheticSaves.gen2(trainer: const SynthTrainer(name: 'GOLD')),
    });
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField), 'gold');
    await settle(tester);
    expect(find.text('GOLD'), findsOneWidget);
    expect(find.text('MAY'), findsNothing);
  });

  testWidgets('abrir una tarjeta muestra equipo, cajas e historial', (tester) async {
    await importDemo(tester, {
      'Esmeralda.sav': SyntheticSaves.gen3(
        trainer: const SynthTrainer(name: 'MAY'),
        party: const [SynthMon(254, level: 52, nickname: 'LEAFY'), SynthMon(25, level: 30)],
        boxes: {0: const [SynthMon(133, level: 18)]},
      ),
    });
    // Un segundo snapshot de la misma partida (más horas).
    await importDemo(tester, {
      'Esmeralda_v2.sav': SyntheticSaves.gen3(
        trainer: const SynthTrainer(name: 'MAY', hours: 50),
        party: const [SynthMon(254, level: 55, nickname: 'LEAFY'), SynthMon(25, level: 31)],
      ),
    });
    await pumpApp(tester);
    await tester.tap(find.text('MAY'));
    // El parseo ocurre en un isolate.
    await settle(tester, until: find.text('Equipo'));

    expect(find.text('Equipo'), findsOneWidget);
    expect(find.text('LEAFY'), findsOneWidget);
    expect(find.text('Pikachu'), findsOneWidget);
    expect(find.text('Cajas'), findsOneWidget);
    // Versión actual destacada; el historial empieza plegado.
    expect(find.textContaining('Versión actual'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Esmeralda_v2\.sav')), findsNothing);
    await tester.ensureVisible(find.text('Historial (2)'));
    await tester.tap(find.text('Historial (2)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Esmeralda_v2.sav'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Esmeralda\.sav')), findsOneWidget);
    expect(find.textContaining('«Pokémon Esmeralda.sav»'), findsOneWidget);
    expect(find.text('Más reciente'), findsOneWidget);
    expect(find.text('Checksum correcto'), findsOneWidget);
  });

  testWidgets('en pantallas estrechas se usa barra de navegación inferior', (tester) async {
    await pumpApp(tester, size: const Size(400, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  test('importar el mismo archivo dos veces no duplica el snapshot', () async {
    final bytes = SyntheticSaves.gen1(party: const [SynthMon(25)]);
    final a = await repo.importBytes(bytes, fileName: 'r.sav', origin: ImportOrigin.file);
    final b = await repo.importBytes(bytes, fileName: 'r.sav', origin: ImportOrigin.file);
    expect(a, isA<ImportAdded>());
    expect(b, isA<ImportDuplicate>(), reason: b is ImportFailed ? b.reason : '');
    final c = await repo.importBytes(SyntheticSaves.gen1(), fileName: 'x', origin: ImportOrigin.file);
    expect(c, isA<ImportAdded>());
    expect((c as ImportAdded).newSlot, isFalse);
    final entries = await repo.watchArca().first;
    expect(entries.single.snapshotCount, 2);
  });

  test('archivos no reconocidos devuelven un error legible', () async {
    final r = await repo.importBytes(Uint8List(100), fileName: 'foto.bin', origin: ImportOrigin.file);
    expect(r, isA<ImportFailed>());
    expect((r as ImportFailed).reason, contains('No se reconoce'));
  });
}
