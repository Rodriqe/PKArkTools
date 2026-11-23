import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/file_sources.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/providers.dart';

import 'arca_screen_test.dart' show settle;

/// Exportar y abrir carpeta sin diálogos ni ventanas del sistema.
class FakeSources extends FileSources {
  FakeSources();
  final exported = <String, Uint8List>{};
  final revealed = <String>[];

  @override
  Future<String?> exportBytes(String suggestedName, Uint8List bytes) async {
    exported[suggestedName] = bytes;
    return '/descargas/$suggestedName';
  }

  @override
  Future<bool> revealFolder(String path) async {
    revealed.add(path);
    return true;
  }
}

Uint8List emerald({int hours = 48}) => SyntheticSaves.gen3(
      trainer: SynthTrainer(name: 'MAY', hours: hours),
      party: const [SynthMon(254, level: 52, nickname: 'LEAFY')],
    );

void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late ArcaRepository repo;
  late FakeSources sources;

  File mainFile() => File(p.join(tmp.path, 'PKArkTools', 'Pokémon Esmeralda', 'MAY (12345)', 'Pokémon Esmeralda.sav'));

  setUp(() async {
    db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    tmp = await Directory.systemTemp.createTemp('arca_current');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
    sources = FakeSources();
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> openDetail(WidgetTester tester, {Size size = const Size(1280, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(ProviderScope(
      overrides: [arcaRepositoryProvider.overrideWithValue(repo), fileSourcesProvider.overrideWithValue(sources)],
      child: const PKArkToolsApp(),
    ));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
    await settle(tester);
    await tester.tap(find.text('MAY'));
    await settle(tester, until: find.text('Equipo'));
  }

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
        await repo.importBytes(emerald(), fileName: 'Esmeralda.sav', origin: ImportOrigin.demo, now: DateTime(2026, 11, 20, 10));
        await repo.importBytes(emerald(hours: 60), fileName: 'Esmeralda.sav', origin: ImportOrigin.demo,
            now: DateTime(2026, 11, 22, 17, 52, 58));
        await repo.reindex();
      });

  testWidgets('la versión actual se destaca con Exportar / Abrir carpeta; el historial empieza plegado', (tester) async {
    await seed(tester);
    await openDetail(tester);
    expect(find.textContaining('Versión actual ·'), findsOneWidget);
    expect(find.textContaining('«Pokémon Esmeralda.sav»'), findsOneWidget);
    expect(find.text('Historial (2)'), findsOneWidget);
    expect(find.text('Más reciente'), findsNothing, reason: 'historial plegado');

    await tester.tap(find.widgetWithText(TextButton, 'Exportar').first);
    await settle(tester);
    expect(sources.exported.keys, ['Pokémon Esmeralda.sav']);
    expect(sources.exported.values.single, emerald(hours: 60));

    await tester.tap(find.text('Abrir carpeta'));
    await settle(tester);
    expect(sources.revealed.single, p.join(tmp.path, 'PKArkTools', 'Pokémon Esmeralda', 'MAY (12345)'));
  });

  testWidgets('principal cambiado a mano: aviso y «Guardar como nueva copia»', (tester) async {
    await seed(tester);
    final fromGame = emerald(hours: 99);
    await tester.runAsync(() async {
      mainFile().writeAsBytesSync(fromGame);
      await repo.reindex();
    });
    await openDetail(tester);
    expect(find.text('El archivo principal cambió fuera de la app'), findsOneWidget);
    await tester.tap(find.text('Guardar como nueva copia'));
    await settle(tester, until: find.text('Historial (3)'));
    for (var i = 0; i < 60 && find.text('El archivo principal cambió fuera de la app').evaluate().isNotEmpty; i++) {
      await settle(tester);
    }
    expect(find.text('El archivo principal cambió fuera de la app'), findsNothing);
    expect(find.text('Historial (3)'), findsOneWidget);
    expect(mainFile().readAsBytesSync(), fromGame);
  });

  testWidgets('restaurar una copia antigua crea una entrada nueva y actualiza el principal', (tester) async {
    await seed(tester);
    await openDetail(tester, size: const Size(1280, 1400));
    await tester.tap(find.text('Historial (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Más reciente'), findsOneWidget);
    // El botón Restaurar de la copia más antigua (la última de la lista).
    await tester.tap(find.widgetWithText(TextButton, 'Restaurar').last);
    await tester.pumpAndSettle();
    expect(find.text('¿Restaurar como versión actual?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Restaurar'));
    await settle(tester, until: find.text('Historial (3)'));
    for (var i = 0; i < 60 && mainFile().lengthSync() > 0 && !_same(mainFile().readAsBytesSync(), emerald()); i++) {
      await settle(tester);
    }
    expect(find.text('Historial (3)'), findsOneWidget);
    expect(find.textContaining('Restaurada'), findsWidgets);
    expect(mainFile().readAsBytesSync(), emerald());
  });

  testWidgets('en el teléfono la versión actual va arriba, antes del equipo', (tester) async {
    await seed(tester);
    await openDetail(tester, size: const Size(400, 900));
    final card = tester.getTopLeft(find.textContaining('Versión actual ·'));
    final team = tester.getTopLeft(find.text('Equipo'));
    expect(card.dy, lessThan(team.dy));
  });
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
