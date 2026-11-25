import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/providers.dart';

import 'arca_screen_test.dart' show settle;

/// «Generar Living Dex en la partida actual» desde la ficha de la partida.
void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late ArcaRepository repo;

  setUp(() async {
    db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    tmp = await Directory.systemTemp.createTemp('living_dex_ui_test');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  testWidgets('pregunta normal/variocolor, avisa de las cajas y guarda una versión nueva', (tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final bytes = SyntheticSaves.gen1(
      trainer: const SynthTrainer(name: 'ROJO', tid: 4321),
      boxes: {0: [const SynthMon(25, level: 5)]},
    );
    final out = await tester.runAsync(() => repo.importBytes(bytes, fileName: 'rojo.sav', origin: ImportOrigin.demo));
    final slotId = (await tester.runAsync(() => repo.snapshot((out! as ImportAdded).snapshotId)))!.slotId;
    await tester.pumpWidget(ProviderScope(
      overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
      child: const PKArkToolsApp(),
    ));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
    await settle(tester);
    await tester.tap(find.text('ROJO'));
    await settle(tester, until: find.text('Equipo'));

    final button = find.byKey(const Key('livingDexButton'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(find.text('Generar Living Dex en la partida actual'), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();

    // 1) Normal o variocolor.
    expect(find.text('¿Living Dex normal o variocolor?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('livingDexNormal')));
    await tester.pumpAndSettle();

    // 2) Aviso: cajas sobrescritas, historial del Arca y formas excluidas.
    expect(find.text('¿Sobrescribir las cajas?'), findsOneWidget);
    expect(find.textContaining('Se sobrescribirán las 12 cajas'), findsOneWidget);
    expect(find.textContaining('historial del Arca'), findsOneWidget);
    expect(find.textContaining('solo existen en combate'), findsOneWidget);
    await tester.tap(find.text('Generar y guardar'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await settle(tester, until: find.textContaining('Living Dex guardada en el Arca'));

    // 3) Versión nueva con las cajas llenas; la anterior sigue en el historial.
    final snaps = await tester.runAsync(() => repo.watchSnapshots(slotId).first);
    expect(snaps!.length, 2);
    final latest = await tester.runAsync(() => repo.snapshotBytes(snaps.first));
    final ed = SaveEditor.open(latest!);
    var n = 0;
    for (var b = 0; b < ed.boxCount; b++) {
      for (var s = 0; s < ed.boxSlotCount; s++) {
        final pk = ed.get(SlotRef.box(b, s));
        if (pk == null) continue;
        n++;
        expect(pk.tid, 4321);
      }
    }
    final plan = LivingDex.plan(ed);
    expect(n, plan.slots.length);
    expect(ed.get(const SlotRef.box(0, 0))!.species, 1);
  });
}
