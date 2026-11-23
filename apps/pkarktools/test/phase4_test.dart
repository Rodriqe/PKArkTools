import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/editing/draft.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/editor/legality_view.dart';
import 'package:pkarktools/providers.dart';

import 'arca_screen_test.dart' show settle;

void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late ArcaRepository repo;

  setUp(() async {
    db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    tmp = await Directory.systemTemp.createTemp('phase4_test');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }

  /// Importa [bytes], abre la app y entra en el detalle de la partida de [trainer].
  Future<int> openSave(WidgetTester tester, Uint8List bytes, String fileName, String trainer) async {
    final out = await tester.runAsync(() => repo.importBytes(bytes, fileName: fileName, origin: ImportOrigin.demo));
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
    await tester.tap(find.text(trainer));
    await settle(tester, until: find.text('Equipo'));
    return (out! as ImportAdded).snapshotId;
  }

  Future<void> openSection(WidgetTester tester, String name, Finder until) async {
    await tester.ensureVisible(find.text(name).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).first);
    await settle(tester, until: until);
  }

  testWidgets('Pokédex de Espada/Escudo: Pokédex regionales y detalle de géneros', (tester) async {
    final snapId = await openSave(
      tester,
      SyntheticSaves.swordShield(trainer: const SynthTrainer(name: 'Gloria'), party: const [SynthMon(25, level: 30)]),
      'main',
      'Gloria',
    );
    await openSection(tester, 'Pokédex', find.text('Isla de la Armadura'));
    expect(find.text('Galar'), findsWidgets);
    expect(find.text('Corona Nieve'), findsOneWidget);

    // Filtrar por Corona Nieve muestra el número regional de Calyrex.
    await tester.tap(find.text('Corona Nieve'));
    await tester.pumpAndSettle();
    expect(find.text('???'), findsWidgets);

    // Volver a todas y abrir el detalle de Pikachu (Galar).
    await tester.tap(find.widgetWithText(ChoiceChip, 'Todas'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '25');
    await tester.pumpAndSettle();
    final tile = find.text('#025');
    await tester.longPress(tile);
    await tester.pumpAndSettle();
    expect(find.text('GÉNEROS VISTOS'), findsOneWidget);
    await tester.tap(find.text('Hembra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.text('Pokédex').first));
    final draft = container.read(draftProvider(snapId));
    final edit = draft.edits.single as PokedexEdit;
    expect(edit.entries.single.species, 25);
    expect(edit.entries.single.genderSeen(1), isTrue);
    expect(draft.editor!.pokedex!.genderMask(25) & 2, 2);
  });

  testWidgets('Eventos de Ultrasol: aviso, flags con nombre de PKHeX y edición', (tester) async {
    final snapId = await openSave(
      tester,
      SyntheticSaves.ctr(layout: CtrLayout.usum, trainer: const SynthTrainer(name: 'Elio', versionId: 32), party: const [SynthMon(25)]),
      'UltraSol.sav',
      'Elio',
    );
    await openSection(tester, 'Eventos', find.text('Cambiar eventos puede romper la partida'));
    expect(find.text('Cambiar eventos puede romper la partida'), findsOneWidget);
    final ev = SaveEditor.open(SyntheticSaves.ctr(layout: CtrLayout.usum)).events!;
    final first = ev.namedFlags(EventLanguage.es).first;
    expect(find.textContaining(first.text.split(' ').first), findsWidgets);
    final sw = find.byType(SwitchListTile).first;
    await tester.ensureVisible(sw);
    await tester.tap(sw);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.text('Eventos').first));
    expect(container.read(draftProvider(snapId)).edits.single, isA<EventEdit>());
  });

  testWidgets('Save con checksum roto: solo lectura con aviso y sin ediciones', (tester) async {
    final bytes = SyntheticSaves.gen1(trainer: const SynthTrainer(name: 'RED'), party: const [SynthMon(25, level: 30)]);
    // Romper un byte del bloque principal (dinero) sin recalcular el checksum.
    final damaged = Uint8List.fromList(bytes)..[0x25F3] ^= 0x11;
    expect(SaveDetector.read(damaged).checksum, ChecksumStatus.invalid);
    expect(SaveEditor.open(damaged).readOnly, isTrue);

    final snapId = await openSave(tester, damaged, 'Rojo.sav', 'RED');
    expect(find.textContaining('solo lectura'), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.text('Equipo').first));
    final ctrl = container.read(draftProvider(snapId).notifier);
    ctrl.apply(const SetTrainerEdit(TrainerData(name: 'X', tid: 1)));
    expect(container.read(draftProvider(snapId)).dirty, isFalse);
    // Exportar sin cambios devuelve el archivo original intacto.
    expect(ctrl.buildFile(), damaged);
  });

  test('Exportar un borrador verifica el archivo releyéndolo', () {
    final e = SaveEditor.open(SyntheticSaves.swordShield(party: const [SynthMon(25)]));
    e.writeTrainer(e.readTrainer().copyWith(money: 777));
    final out = e.buildVerified();
    expect(SaveVerifier.verifyExport(e, out), isEmpty);
    expect(SaveEditor.open(out).readTrainer().money, 777);
  });

  testWidgets('Legalidad de encuentros: nivel imposible en X/Y con explicación y corrección', (tester) async {
    bigView(tester);
    final slot = EncounterTables.forVersion(24).firstWhere((e) => e.species == 25 && e.kind == EncounterKind.wild);
    final pk = SaveEditor.open(SyntheticSaves.ctr(layout: CtrLayout.xy, party: const [SynthMon(25, level: 70)]))
        .get(const SlotRef.party(0))!
      ..version = 24
      ..metLocation = slot.location
      ..metLevel = 60;
    final issues = Legality.check(pk, GameVersion.xy);
    final enc = issues.where((i) => i.area == LegalityArea.encounter).single;
    expect(enc.code, LegalityCode.encounterWrongLevel);
    LegalityIssue? fixed;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: LegalityPanel(issues: issues, onFix: (i) => fixed = i))),
      ),
    ));
    expect(find.text('Encuentro según las tablas del juego (lugar, nivel y especie)'), findsOneWidget);
    await tester.tap(find.textContaining('imposible en Bosque de Novarte'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Corregir pone el nivel de encuentro'), findsOneWidget);
    await tester.tap(find.text('Intentar corregir').first);
    expect(fixed?.code, isNotNull);
    final after = Legality.applyFix(pk, enc, GameVersion.xy)!;
    expect(Legality.check(after, GameVersion.xy).where((i) => i.area == LegalityArea.encounter), isEmpty);
  });
}
