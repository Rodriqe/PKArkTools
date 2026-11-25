import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/emulators/emulator_service.dart';
import 'package:pkarktools/data/emulators/emulators.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_access.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';
import 'package:pkarktools/editing/draft.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/providers.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/tools/champions_screen.dart';
import 'package:pkarktools/ui/tools/emulators_section.dart';
import 'package:pkarktools/ui/tools/share_card.dart';
import 'package:pkarktools/ui/tools/showdown_ui.dart';
import 'package:pkarktools/ui/tools/stat_calculator.dart';

import 'arca_screen_test.dart' show settle;

const _showdown = '''
Swampert @ Leftovers
Ability: Torrent
Level: 60
Relaxed Nature
- Surf
- Earthquake

Gardevoir (F) @ Twisted Spoon
Ability: Synchronize
Level: 40
Modest Nature
- Psychic
''';

void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late ArcaRepository repo;

  setUp(() async {
    db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    tmp = await Directory.systemTemp.createTemp('tools_ui_test');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await db.close();
    await tmp.delete(recursive: true);
  });

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }

  Widget wrap(Widget child, {List overrides = const []}) => ProviderScope(
    overrides: [arcaRepositoryProvider.overrideWithValue(repo), ...overrides.cast()],
    child: MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    ),
  );

  Future<int> importEmerald(WidgetTester tester) async {
    final out = await tester.runAsync(
      () => repo.importBytes(
        SyntheticSaves.gen3(
          trainer: const SynthTrainer(name: 'MAY'),
          party: const [SynthMon(25, level: 30)],
          boxes: {
            0: const [SynthMon(150, level: 70), null, SynthMon(1, level: 5), SynthMon(4, level: 9)],
          },
        ),
        fileName: 'Esmeralda.sav',
        origin: ImportOrigin.demo,
      ),
    );
    return (out! as ImportAdded).snapshotId;
  }

  Future<void> openSave(WidgetTester tester) async {
    bigView(tester);
    await tester.pumpWidget(
      ProviderScope(overrides: [arcaRepositoryProvider.overrideWithValue(repo)], child: const PKArkToolsApp()),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
    await settle(tester);
    await tester.tap(find.text('MAY'));
    await settle(tester, until: find.byKey(const ValueKey('tool-showdown-import')));
  }

  SaveEditor draftEditor(WidgetTester tester, int snapshotId) {
    final container = ProviderScope.containerOf(tester.element(find.byKey(const ValueKey('tool-sort'))));
    return container.read(draftProvider(snapshotId)).editor!;
  }

  testWidgets('importar de Showdown al equipo y exportar el equipo', (tester) async {
    final id = await importEmerald(tester);
    await openSave(tester);
    await tester.tap(find.byKey(const ValueKey('tool-showdown-import')));
    await settle(tester, until: find.byKey(const ValueKey('showdown-text')));
    await tester.enterText(find.byKey(const ValueKey('showdown-text')), _showdown);
    await tester.tap(find.byKey(const ValueKey('showdown-analyze')));
    await settle(tester);
    expect(find.textContaining('Swampert'), findsWidgets);
    expect(find.textContaining('Gardevoir'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('showdown-add')));
    await settle(tester, until: find.byKey(const ValueKey('tool-sort')));

    final party = draftEditor(tester, id).party;
    expect([for (final p in party) p.species], [25, 260, 282]);
    expect(party[1].level, 60);
    expect(party[2].gender, 1);

    await tester.tap(find.byKey(const ValueKey('tool-showdown-export')));
    await settle(tester, until: find.byKey(const ValueKey('showdown-export-text')));
    final text = tester.widget<SelectableText>(find.byKey(const ValueKey('showdown-export-text'))).data!;
    expect(Showdown.parse(text), hasLength(3));
    expect(text, contains('Swampert (M) @ Leftovers'));
  });

  testWidgets('ordenar cajas con vista previa y deshacer', (tester) async {
    final id = await importEmerald(tester);
    await openSave(tester);
    await tester.tap(find.byKey(const ValueKey('tool-sort')));
    await settle(tester, until: find.byKey(const ValueKey('sort-apply')));
    expect(find.textContaining('Cambian'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sort-apply')));
    await settle(tester, until: find.byKey(const ValueKey('tool-sort')));

    final e = draftEditor(tester, id);
    expect([for (var s = 0; s < 4; s++) e.get(SlotRef.box(0, s))?.species], [1, 4, 150, null]);

    final container = ProviderScope.containerOf(tester.element(find.byKey(const ValueKey('tool-sort'))));
    container.read(draftProvider(id).notifier).undo();
    await settle(tester);
    final back = container.read(draftProvider(id)).editor!;
    expect([for (var s = 0; s < 4; s++) back.get(SlotRef.box(0, s))?.species], [150, null, 1, 4]);
  });

  testWidgets('calculadora: IVs a partir de las estadísticas y Poder Oculto', (tester) async {
    bigView(tester);
    final mon =
        SaveEditor.open(SyntheticSaves.gen3(party: const [SynthMon(376, level: 100)])).get(const SlotRef.party(0))!
          ..dataGame = GameVersion.emerald
          ..setIvs(const [12, 31, 0, 17, 25, 30])
          ..setEvs(const [0, 0, 0, 0, 0, 0]);
    List<int>? applied;
    await tester.pumpWidget(
      wrap(
        SingleChildScrollView(
          child: StatCalculatorPanel(pk: mon, onApplyIvs: (v) => applied = v),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('hidden-power')), findsOneWidget);
    final stats = mon.computeStats()!;
    for (var i = 0; i < 6; i++) {
      await tester.enterText(find.byKey(ValueKey('calc-observed-$i')), '${stats[i]}');
    }
    await tester.tap(find.byKey(const ValueKey('calc-infer')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('calc-apply')));
    expect(applied, [12, 31, 0, 17, 25, 30]);
  });

  testWidgets('tarjeta para compartir: se dibuja y se exporta a PNG', (tester) async {
    bigView(tester);
    final pk = Showdown.toPkm(
      Showdown.parse('Chompy (Garchomp) (F) @ Life Orb\nLevel: 50\nShiny: Yes\n- Earthquake').single,
      GameVersion.scarletViolet,
      const TrainerData(name: 'Juliana', tid: 1, sid: 2),
      random: Random(1),
    ).pkm!;
    final key = GlobalKey();
    await tester.pumpWidget(
      wrap(
        Center(
          child: RepaintBoundary(
            key: key,
            child: PokemonShareCard(pk: pk, game: GameVersion.scarletViolet),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Chompy'), findsOneWidget);
    expect(find.text('Variocolor'), findsOneWidget);
    expect(find.text('PKArkTools'), findsOneWidget);
    final png = await tester.runAsync(() => captureBoundary(key, pixelRatio: 1));
    expect(png, isNotNull);
    expect(png!.sublist(1, 4), 'PNG'.codeUnits);
  });

  testWidgets('formato oficial: reglas, búsqueda y elegibilidad de tus Pokémon', (tester) async {
    bigView(tester);
    await tester.runAsync(
      () => repo.importBytes(
        SyntheticSaves.scarletViolet(
          party: const [SynthMon(445, level: 60), SynthMon(1007, level: 70), SynthMon(194, level: 10)],
        ),
        fileName: 'main',
        origin: ImportOrigin.demo,
      ),
    );
    await tester.pumpWidget(wrap(const ChampionsScreen()));
    await settle(tester);
    expect(find.textContaining(ChampionsFormat.formatName), findsWidgets);
    expect(find.byKey(const ValueKey('champions-dates-unconfirmed')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('champions-search')), 'garch');
    await tester.pump();
    expect(find.text('Garchomp'), findsOneWidget);

    await tester.tap(find.text('Tus Pokémon'));
    await settle(tester, until: find.byKey(const ValueKey('champions-summary')));
    expect(find.textContaining('1 de 3'), findsOneWidget);
    // La búsqueda se comparte entre pestañas: solo sale Garchomp.
    expect(find.textContaining('Garchomp ·'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('champions-search')).hitTestable(), '');
    await tester.pump();
    expect(find.textContaining('restringidos'), findsWidgets);
    expect(find.textContaining('no está en la lista'), findsOneWidget);
  });

  testWidgets('emuladores: buscar carpetas conocidas y vincular con permiso', (tester) async {
    bigView(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final emu = Emulators.byId('retroarch')!;
    await tester.pumpWidget(
      wrap(
        SingleChildScrollView(child: EmulatorsSection(detect: () async => [(emu, '/home/u/.config/retroarch/saves')])),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('emu-detect')));
    await settle(tester);
    expect(find.text('/home/u/.config/retroarch/saves'), findsOneWidget);
    await tester.tap(find.text('Vincular'));
    await settle(tester);
    expect(find.textContaining('¿Dar acceso'), findsOneWidget);
    await tester.tap(find.text('Dar acceso'));
    await settle(tester);
    expect(find.byKey(const ValueKey('emu-link-retroarch-/home/u/.config/retroarch/saves')), findsOneWidget);
    final saved = await tester.runAsync(() => repo.getSetting(EmulatorLinksNotifier.settingKey));
    expect(EmulatorLink.decodeList(saved).single.location.value, '/home/u/.config/retroarch/saves');
    debugDefaultTargetPlatformOverride = null;
  });

  test('respaldo de la carpeta de un emulador en el Arca', () async {
    final fs = MemoryFolderFs();
    await fs.writeNew('saves/Pokemon Esmeralda.srm', SyntheticSaves.gen3(trainer: const SynthTrainer(name: 'MAY')));
    await fs.writeNew('saves/otra.sav', SyntheticSaves.gen3(trainer: const SynthTrainer(name: 'BRENDAN', tid: 777)));
    await fs.writeNew('roms/Pokemon.gba', Uint8List(1024));
    await fs.writeNew('notas.sav', Uint8List.fromList(List.filled(64, 1)));
    final r = await backupEmulatorFolder(fs, repo);
    expect(r.added, 2);
    expect(r.skipped, 2);
    final again = await backupEmulatorFolder(fs, repo);
    expect(again.added, 0);
    expect(again.duplicates, 2);
  });

  group('rutas de emuladores', () {
    test('plantillas por sistema', () {
      final ra = Emulators.byId('retroarch')!;
      expect(
        Emulators.expand(r'%APPDATA%\RetroArch\saves', env: {'APPDATA': r'C:\Users\a\AppData\Roaming'}, windows: true),
        r'C:\Users\a\AppData\Roaming\RetroArch\saves',
      );
      expect(
        Emulators.candidates(ra, TargetPlatform.linux, env: const {}, home: '/home/a'),
        contains('/home/a/.config/retroarch/saves'),
      );
      expect(Emulators.candidates(ra, TargetPlatform.android, env: const {}, home: null), [
        '/storage/emulated/0/RetroArch/saves',
      ]);
      expect(Emulators.expand(r'%APPDATA%\x', env: const {}), isNull);
    });

    test('abrir el juego solo donde se puede', () {
      expect(Emulators.byId('delta')!.canLaunchOn(TargetPlatform.iOS), isTrue);
      expect(Emulators.byId('delta')!.canLaunchOn(TargetPlatform.android), isFalse);
      expect(Emulators.byId('dolphin')!.canLaunchOn(TargetPlatform.android), isTrue);
      for (final e in Emulators.all) {
        expect(e.canLaunchOn(TargetPlatform.macOS), isFalse);
        expect(e.canLaunchOn(TargetPlatform.windows), isFalse);
      }
    });

    test('vínculos se guardan y se leen', () {
      final links = [
        const EmulatorLink('dolphin', ArcaLocation(LocationKind.saf, value: 'content://tree/x', label: 'x')),
      ];
      final back = EmulatorLink.decodeList(EmulatorLink.encodeList(links));
      expect(back.single.emulatorId, 'dolphin');
      expect(back.single.location.kind, LocationKind.saf);
      expect(EmulatorLink.decodeList('basura'), isEmpty);
    });
  });

  test('placementFor: equipo primero y después huecos libres de las cajas', () {
    final e = SaveEditor.open(
      SyntheticSaves.gen3(
        party: const [SynthMon(25), SynthMon(1), SynthMon(4), SynthMon(7), SynthMon(10)],
        boxes: {
          0: const [SynthMon(150)],
        },
      ),
    );
    final refs = placementFor(e, 3, ShowdownTarget.party);
    expect(refs, [const SlotRef.party(5), const SlotRef.box(0, 1), const SlotRef.box(0, 2)]);
    expect(placementFor(e, 1, ShowdownTarget.boxes), [const SlotRef.box(0, 1)]);
  });
}
