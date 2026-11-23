import 'dart:typed_data';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_archive.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/file_sources.dart';
import 'package:pkarktools/editing/draft.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/providers.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/detail/compare_screen.dart';
import 'package:pkarktools/ui/editor/legality_view.dart';
import 'package:pkarktools/ui/import/import_flow.dart';

import 'arca_screen_test.dart' show settle;

void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late ArcaRepository repo;

  setUp(() async {
    db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    tmp = await Directory.systemTemp.createTemp('phase3_test');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Widget wrap(Widget child) => ProviderScope(
        overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }

  Future<int> openEmerald(WidgetTester tester) async {
    final out = await tester.runAsync(() => repo.importBytes(
          SyntheticSaves.gen3(trainer: const SynthTrainer(name: 'MAY'), party: const [SynthMon(254, level: 52), SynthMon(25, level: 30)]),
          fileName: 'Esmeralda.sav',
          origin: ImportOrigin.demo,
        ));
    bigView(tester);
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
    await settle(tester, until: find.text('Equipo'));
    return (out! as ImportAdded).snapshotId;
  }

  testWidgets('Pokédex: completar con confirmación y marcar especie', (tester) async {
    final snapId = await openEmerald(tester);
    await tester.ensureVisible(find.text('Pokédex'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokédex'));
    await settle(tester, until: find.text('Capturados'));
    expect(find.text('Capturados'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Completar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Completar la Pokédex?'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Completar')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.text('Pokédex').first));
    final draft = container.read(draftProvider(snapId));
    expect(draft.dirty, isTrue);
    expect(draft.editor!.pokedex!.counts.caught, 386);
    expect(find.textContaining('386', findRichText: true), findsWidgets);
  });

  testWidgets('Eventos: aviso visible y alternar un flag con nombre', (tester) async {
    final snapId = await openEmerald(tester);
    await tester.ensureVisible(find.text('Eventos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eventos'));
    await settle(tester, until: find.text('Cambiar eventos puede romper la partida'));
    expect(find.text('Cambiar eventos puede romper la partida'), findsOneWidget);
    final sw = find.byType(SwitchListTile).first;
    await tester.ensureVisible(sw);
    await tester.tap(sw);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.text('Eventos').first));
    expect(container.read(draftProvider(snapId)).edits.single, isA<EventEdit>());
  });

  testWidgets('Legalidad detallada: explicación y botón de corrección', (tester) async {
    bigView(tester);
    final pk = SaveEditor.open(SyntheticSaves.scarletViolet(party: const [SynthMon(25, level: 30)])).get(const SlotRef.party(0))!
      ..ball = 30;
    final issues = Legality.check(pk, GameVersion.scarletViolet);
    LegalityIssue? fixed;
    await tester.pumpWidget(wrap(Scaffold(body: SingleChildScrollView(child: LegalityPanel(issues: issues, onFix: (i) => fixed = i)))));
    expect(find.text('Origen y encuentro'), findsOneWidget);
    await tester.tap(find.textContaining('solo existe en Leyendas Arceus'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Corregir pone una Poké Ball normal'), findsOneWidget);
    await tester.tap(find.text('Intentar corregir'));
    expect(fixed?.code, LegalityCode.ballOnlyInLegends);
  });

  testWidgets('Importación en bloque: nuevos, duplicados y no reconocidos', (tester) async {
    bigView(tester);
    final emerald = SyntheticSaves.gen3(party: const [SynthMon(25)]);
    final crystal = SyntheticSaves.gen2(crystal: true, party: const [SynthMon(25)]);
    PickedSave f(String n, List<int> b) => PickedSave(name: n, bytes: Uint8List.fromList(b), origin: ImportOrigin.folder);
    final scan = FolderScan(
      rootLabel: '/Checkpoint/saves',
      found: [
        FolderCandidate(file: f('a.sav', emerald), relativePath: 'Esmeralda/a.sav', game: GameVersion.emerald, trainer: 'MAY'),
        FolderCandidate(file: f('b.sav', emerald), relativePath: 'copia/b.sav', game: GameVersion.emerald, trainer: 'MAY'),
        FolderCandidate(file: f('c.sav', crystal), relativePath: 'Cristal/c.sav', game: GameVersion.crystal, trainer: 'GOLD'),
      ],
      scanned: 4,
      ignored: 3,
      unrecognized: const ['raro/x.bin'],
    );
    await tester.pumpWidget(wrap(Scaffold(
        body: BulkImportDialog(scan: scan, known: {ArcaRepository.sha256Of(crystal)}))));
    expect(find.text('Detectados (1)'), findsOneWidget);
    expect(find.text('Ya en el Arca (1)'), findsOneWidget);
    expect(find.text('Repetidos en la selección (1)'), findsOneWidget);
    expect(find.text('No reconocidos (1)'), findsOneWidget);
    expect(find.text('Importar 1 nuevos'), findsOneWidget);
  });

  testWidgets('Comparar snapshots: muestra cambios de equipo y entrenador', (tester) async {
    bigView(tester);
    final before = SyntheticSaves.gen3(trainer: const SynthTrainer(name: 'MAY'), party: const [SynthMon(25, level: 30), SynthMon(6, level: 40)]);
    final e = SaveEditor.open(before);
    final pika = e.get(const SlotRef.party(0))!..level = 60;
    e.set(const SlotRef.party(0), pika);
    e.writeTrainer(e.readTrainer().copyWith(money: 777));
    final ids = await tester.runAsync(() async {
      final a = await repo.importBytes(before, fileName: 'E.sav', origin: ImportOrigin.file) as ImportAdded;
      final b = await repo.saveEdited(e.build(), slotId: a.slotId, fileName: 'E.sav', note: 'x') as ImportAdded;
      return (a.snapshotId, b.snapshotId);
    });
    await tester.pumpWidget(wrap(CompareScreen(beforeId: ids!.$1, afterId: ids.$2, game: GameVersion.emerald)));
    await settle(tester, until: find.text('Cambió'));
    expect(find.text('Comparar copias'), findsOneWidget);
    expect(find.text('Cambió'), findsOneWidget);
    expect(find.text('Dinero'), findsOneWidget);
    expect(find.text('Nivel'), findsWidgets);
  });

  test('Arca en zip: exportar y restaurar conserva partidas, fechas y notas', () async {
    final a = await repo.importBytes(SyntheticSaves.gen3(party: const [SynthMon(25)]), fileName: 'E.sav', origin: ImportOrigin.file)
        as ImportAdded;
    final e = SaveEditor.open(await repo.snapshotBytes(await repo.snapshot(a.snapshotId)));
    e.writeTrainer(e.readTrainer().copyWith(money: 1));
    await repo.saveEdited(e.build(), slotId: a.slotId, fileName: 'E.sav', note: 'dinero');
    await repo.importBytes(SyntheticSaves.swordShield(party: const [SynthMon(25)]), fileName: 'main', origin: ImportOrigin.folder);

    final (zip, count) = await ArcaArchive.export(repo);
    expect(count, 3);

    final db2 = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final tmp2 = await Directory.systemTemp.createTemp('phase3_restore');
    final repo2 = ArcaRepository(db2, ArcaFolder(IoFolderFs(tmp2)));
    final out = await ArcaArchive.restore(repo2, zip);
    expect(out.whereType<ImportAdded>(), hasLength(3));
    final slots = await repo2.allSlots();
    expect(slots, hasLength(2));
    final emerald = slots.firstWhere((s) => s.$2.length == 2);
    expect(emerald.$2.last.note, 'dinero');
    // Restaurar dos veces no duplica nada.
    final again = await ArcaArchive.restore(repo2, zip);
    expect(again.whereType<ImportDuplicate>(), hasLength(3));
    await db2.close();
    await tmp2.delete(recursive: true);
    expect(() => ArcaArchive.restore(repo2, Uint8List.fromList([1, 2, 3])), throwsFormatException);
  });
}
