import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
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
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/providers.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/common/species_avatar.dart';
import 'package:pkarktools/ui/editor/legality_view.dart';
import 'package:pkarktools/ui/editor/pokemon_editor.dart';

import 'arca_screen_test.dart' show settle;

void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late ArcaRepository repo;

  setUp(() async {
    db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    tmp = await Directory.systemTemp.createTemp('editor_test');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
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
  }

  Future<void> openEmerald(WidgetTester tester) async {
    await tester.runAsync(() => repo.importBytes(
          SyntheticSaves.gen3(
            trainer: const SynthTrainer(name: 'MAY'),
            party: const [SynthMon(254, level: 52, nickname: 'LEAFY'), SynthMon(25, level: 30)],
            boxes: {0: const [SynthMon(133, level: 18)]},
          ),
          fileName: 'Esmeralda.sav',
          origin: ImportOrigin.demo,
        ));
    await pumpApp(tester);
    await tester.tap(find.text('MAY'));
    await settle(tester, until: find.text('Equipo'));
  }

  testWidgets('editar un Pokémon: aplicar, deshacer, rehacer y guardar en el Arca', (tester) async {
    await openEmerald(tester);
    expect(find.textContaining('Sin cambios'), findsOneWidget);

    await tester.tap(find.text('Pikachu'));
    await settle(tester, until: find.text('Editar Pokémon'));
    expect(find.text('Editar Pokémon'), findsOneWidget);
    expect(find.textContaining('Estadísticas a nivel 30'), findsOneWidget);

    await tester.ensureVisible(find.text('IVs perfectos'));
    await tester.tap(find.text('IVs perfectos'));
    await tester.pump();
    await tester.tap(find.text('Aplicar cambios'));
    await settle(tester, until: find.textContaining('1 cambio sin guardar'));
    expect(find.textContaining('1 cambio sin guardar'), findsOneWidget);

    // En el test la plataforma es Android: sin atajos de teclado en el tooltip.
    await tester.tap(find.byTooltip('Deshacer'));
    await settle(tester);
    expect(find.textContaining('Sin cambios'), findsOneWidget);
    await tester.tap(find.byTooltip('Rehacer'));
    await settle(tester);
    expect(find.textContaining('1 cambio sin guardar'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar en el Arca'));
    await settle(tester, until: find.text('Descripción de los cambios'));
    expect(find.textContaining('Pikachu en Equipo, hueco 2'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Guardar en el Arca')));
    await settle(tester, until: find.text('Guardado como copia nueva en el Arca'));

    final snaps = await tester.runAsync(() => repo.watchSnapshots(1).first);
    expect(snaps!.length, 2);
    final edited = snaps.firstWhere((s) => s.origin == 'edit');
    expect(edited.note, contains('Pikachu'));
    final bytes = await tester.runAsync(() => repo.snapshotBytes(edited));
    final pk = SaveEditor.open(bytes!).get(const SlotRef.party(1))!;
    expect(pk.ivs, everyElement(31));
    // El original sigue intacto.
    final original = snaps.firstWhere((s) => s.origin == 'demo');
    final ob = await tester.runAsync(() => repo.snapshotBytes(original));
    expect(SaveEditor.open(ob!).get(const SlotRef.party(1))!.ivs, isNot(everyElement(31)));
  });

  testWidgets('entrenador: cambiar dinero va al borrador', (tester) async {
    await openEmerald(tester);
    await tester.tap(find.text('Entrenador'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Dinero'), '424242');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar cambios'));
    await settle(tester, until: find.textContaining('1 cambio sin guardar'));
    expect(find.textContaining('1 cambio sin guardar'), findsOneWidget);
    expect(find.text('424.242'), findsOneWidget);
  });

  testWidgets('inventario: añadir un objeto con el buscador', (tester) async {
    await openEmerald(tester);
    await tester.tap(find.text('Inventario'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Añadir objeto'), 'poci');
    await settle(tester);
    await tester.tap(find.text('Poción').last);
    await settle(tester);
    expect(find.text('Poción'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar cambios'));
    await settle(tester, until: find.textContaining('1 cambio sin guardar'));
    expect(find.textContaining('1 cambio sin guardar'), findsOneWidget);
  });

  testWidgets('arrastrar de una caja al equipo intercambia', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await openEmerald(tester);
    final eevee = find.byWidgetPredicate((w) => w is SpeciesAvatar && w.species == 133);
    final pikachu = find.text('Pikachu');
    expect(eevee, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(eevee));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(10, 10));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(pikachu));
    await tester.pump();
    await gesture.up();
    await settle(tester, until: find.textContaining('1 cambio sin guardar'));
    expect(find.textContaining('1 cambio sin guardar'), findsOneWidget);
    expect(find.text('Eevee'), findsOneWidget); // ahora está en el equipo
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('salir con cambios pide confirmación', (tester) async {
    await openEmerald(tester);
    await tester.tap(find.text('Entrenador'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Dinero'), '5');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar cambios'));
    await settle(tester);
    await tester.tap(find.byTooltip('Atrás'));
    await settle(tester);
    expect(find.text('¿Salir sin guardar?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await settle(tester);
    expect(find.textContaining('1 cambio sin guardar'), findsOneWidget);
  });

  testWidgets('el editor muestra avisos de legalidad sin bloquear', (tester) async {
    final editor = SaveEditor.open(SyntheticSaves.scarletViolet(party: const [SynthMon(25, level: 30)]));
    final pk = editor.get(const SlotRef.party(0))!..setEvs(const [252, 252, 252, 0, 0, 0]);
    tester.view.physicalSize = const Size(1300, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PokemonEditorScreen(game: GameVersion.scarletViolet, initial: pk, slotLabel: 'Equipo, hueco 1'),
    ));
    await tester.pump();
    expect(find.byType(LegalityPanel), findsOneWidget);
    expect(find.textContaining('El total de EVs (756) supera 510'), findsOneWidget);
    expect(find.text('Son solo avisos: puedes guardar igualmente.'), findsOneWidget);
    // Teratipo visible solo en SV.
    expect(find.text('Teratipo'), findsOneWidget);
    await tester.ensureVisible(find.text('Limpiar'));
    await tester.tap(find.text('Limpiar'));
    await tester.pump();
    expect(find.textContaining('El total de EVs'), findsNothing);
  });

  testWidgets('sin la calculadora clásica: los IVs y EVs se siguen editando y aplicando', (tester) async {
    final editor = SaveEditor.open(SyntheticSaves.scarletViolet(party: const [SynthMon(25, level: 30)]));
    final pk = editor.get(const SlotRef.party(0))!
      ..setIvs(const [1, 2, 3, 4, 5, 6])
      ..setEvs(const [0, 0, 0, 0, 0, 0]);
    tester.view.physicalSize = const Size(1300, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    EditorResult? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result =
              await PokemonEditorScreen.open(context, game: GameVersion.scarletViolet, pk: pk, slotLabel: 'Equipo, hueco 1'),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    // Secciones de IVs y EVs con sus campos; el panel de la calculadora ya no está.
    expect(find.text('IVs (valores individuales)'), findsOneWidget);
    expect(find.text('EVs (puntos de esfuerzo)'), findsOneWidget);
    expect(find.byKey(const ValueKey('calc-infer')), findsNothing);
    expect(find.byKey(const ValueKey('stat-calculator')), findsNothing);
    await tester.ensureVisible(find.text('IVs perfectos'));
    await tester.tap(find.text('IVs perfectos'));
    await tester.pump();
    await tester.ensureVisible(find.text('Atacante físico'));
    await tester.tap(find.text('Atacante físico'));
    await tester.pump();
    expect(find.textContaining('Estadísticas a nivel 30'), findsOneWidget);
    await tester.tap(find.text('Aplicar cambios'));
    await tester.pumpAndSettle();
    final applied = (result! as EditorApply).pk;
    expect(applied.ivs, everyElement(31));
    expect(applied.evs, [4, 252, 0, 0, 0, 252]);
  });
}
