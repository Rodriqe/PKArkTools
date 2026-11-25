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
import 'package:pkarktools/data/transfer_service.dart';
import 'package:pkarktools/providers.dart';

import 'arca_screen_test.dart' show settle;

final _emerald = SyntheticSaves.gen3(
  trainer: const SynthTrainer(name: 'MAY'),
  party: const [SynthMon(254, level: 52), SynthMon(25, level: 30)],
  boxes: {0: const [SynthMon(133, level: 18), SynthMon(263, level: 5)]},
);
final _platinum = SyntheticSaves.gen4(trainer: const SynthTrainer(name: 'Lucas'), party: const [SynthMon(393, level: 10)]);
final _ultraSun = SyntheticSaves.ctr(
  layout: CtrLayout.usum,
  trainer: const SynthTrainer(name: 'Elio', versionId: 32),
  party: const [SynthMon(722, level: 10)],
  boxes: {0: const [SynthMon(25, level: 12)]},
);
final _scarlet = SyntheticSaves.scarletViolet(party: const [SynthMon(906, level: 10)]);

void main() {
  group('TransferService', () {
    test('mover de Esmeralda a Platino: plan, aplicar y releer', () {
      final src = SaveEditor.open(_emerald), dst = SaveEditor.open(_platinum);
      final plan = TransferService.plan(
        src: src,
        fromGame: GameVersion.emerald,
        refs: const [SlotRef.box(0, 0), SlotRef.box(0, 1)],
        dst: dst,
        toGame: GameVersion.platinum,
      );
      expect(plan.ready, hasLength(2));
      expect(plan.viaHome, isFalse);
      final out = TransferService.apply(plan, _emerald, _platinum);
      final d = SaveEditor.open(out.destination);
      expect(d.get(plan.ready[0].target!)!.species, 133);
      expect(d.get(plan.ready[1].target!)!.metLocation, 55); // Parque Compi
      final s = SaveEditor.open(out.source!);
      expect(s.get(const SlotRef.box(0, 0)), isNull);
      expect(s.get(const SlotRef.box(0, 1)), isNull);
    });

    test('copiar deja el original; el último del equipo no se puede mover', () {
      final src = SaveEditor.open(_platinum), dst = SaveEditor.open(SyntheticSaves.gen5(party: const [SynthMon(25)]));
      final move = TransferService.plan(
          src: src, fromGame: GameVersion.platinum, refs: const [SlotRef.party(0)], dst: dst, toGame: GameVersion.blackWhite);
      expect(move.skips[const SlotRef.party(0)], TransferSkip.lastInParty);
      final copy = TransferService.plan(
          src: src,
          fromGame: GameVersion.platinum,
          refs: const [SlotRef.party(0)],
          dst: dst,
          toGame: GameVersion.blackWhite,
          move: false);
      expect(copy.ready, hasLength(1));
      final out = TransferService.apply(copy, _platinum, SyntheticSaves.gen5(party: const [SynthMon(25)]), move: false);
      expect(out.source, isNull);
    });

    test('USUM → Escarlata pasa por HOME (aviso y opción de quedarse en Alola); bloqueos visibles', () {
      final src = SaveEditor.open(_ultraSun), dst = SaveEditor.open(_scarlet);
      final plan = TransferService.plan(
        src: src,
        fromGame: GameVersion.ultraSunUltraMoon,
        refs: const [SlotRef.box(0, 0)],
        dst: dst,
        toGame: GameVersion.scarletViolet,
      );
      expect(plan.viaHome, isTrue);
      expect(plan.canStopAtAlola, isTrue);
      expect(plan.ready.single.result.pk!.homeTracker, isNot(0));
      final back = TransferService.plan(
          src: SaveEditor.open(_scarlet),
          fromGame: GameVersion.scarletViolet,
          refs: const [SlotRef.party(0)],
          dst: SaveEditor.open(_ultraSun),
          toGame: GameVersion.ultraSunUltraMoon,
          move: false);
      expect(back.items.single.result.block, TransferBlock.backwards);
      expect(back.ready, isEmpty);
    });
  });

  group('Pantalla de transferencia', () {
    late ArcaDatabase db;
    late Directory tmp;
    late ArcaRepository repo;

    setUp(() async {
      db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
      tmp = await Directory.systemTemp.createTemp('transfer_test');
      repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
    });

    tearDown(() async {
      await db.close();
      await tmp.delete(recursive: true);
    });

    testWidgets('mover un Pokémon de Esmeralda a Platino guarda las dos partidas', timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await tester.runAsync(() async {
        await repo.importBytes(_emerald, fileName: 'Esmeralda.sav', origin: ImportOrigin.demo);
        await repo.importBytes(_platinum, fileName: 'Platino.sav', origin: ImportOrigin.demo);
      });
      tester.view.physicalSize = const Size(1400, 2400);
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
      await tester.tap(find.text('MAY'));
      await settle(tester, until: find.text('Transferir Pokémon…'));
      await tester.tap(find.text('Transferir Pokémon…'));
      await settle(tester, until: find.text('Partida de destino'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await settle(tester);
      // Elegir Eevee (caja 1) y Platino.
      await tester.tap(find.byTooltip(RegExp('Eevee')).first);
      await tester.pump();
      await tester.tap(find.textContaining('Platino').first);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await settle(tester, until: find.text('Vista previa'));
      expect(find.textContaining('PK3 → PK4'), findsOneWidget);
      final button = find.text('Transferir 1 Pokémon');
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.tap(button);
      // Guarda las dos partidas (E/S real): puede tardar más que un settle.
      for (var i = 0; i < 6 && find.textContaining('transferido a').evaluate().isEmpty; i++) {
        await settle(tester, until: find.textContaining('transferido a'));
      }
      expect(find.textContaining('transferido a'), findsOneWidget);

      final em = await tester.runAsync(() => repo.watchSnapshots(1).first);
      final pt = await tester.runAsync(() => repo.watchSnapshots(2).first);
      expect(em!.length, 2, reason: 'Esmeralda: copia nueva sin el Pokémon');
      expect(pt!.length, 2, reason: 'Platino: copia nueva con el Pokémon');
      final edited = pt.firstWhere((s) => s.origin == 'edit');
      final bytes = await tester.runAsync(() => repo.snapshotBytes(edited));
      final ed = SaveEditor.open(bytes!);
      final found = [
        for (var s = 0; s < ed.boxSlotCount; s++) ed.get(SlotRef.box(0, s))?.species,
      ];
      expect(found, contains(133));
    });
  });
}
