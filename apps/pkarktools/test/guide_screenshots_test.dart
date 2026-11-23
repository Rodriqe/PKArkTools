import 'dart:async';
import 'dart:io' hide Platform;
import 'dart:io' as io show Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/file_sources.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/arca_game_folders.dart';
import 'package:pkarktools/data/folder/folder_access.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';
import 'package:pkarktools/data/sprites/sprite_cache.dart';
import 'package:pkarktools/providers.dart';
import 'package:pkarktools/ui/import/import_flow.dart';

import 'shots_i18n.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';

/// Capturas de la GUÍA DE USUARIO (`docs/screenshots/NN_nombre.png`)
/// renderizadas fuera de pantalla con `flutter test`: sin dispositivo ni
/// ventana, fuentes reales, datos sintéticos y carpeta en memoria.
///
///   flutter test test/guide_screenshots_test.dart --dart-define=SHOTS_GUIDE=true
///
/// Sin la define se omite (el CI no reescribe capturas). Sustituye a los
/// arneses `integration_test/screenshots_test.dart` y
/// `folder_screenshots_test.dart`, que necesitaban `flutter drive -d macos`.
const _enabled = bool.fromEnvironment('SHOTS_GUIDE');

Future<void> _loadFonts() async {
  final flutterRoot = io.Platform.environment['FLUTTER_ROOT'];
  final fonts = <(String, String)>[
    ('Manrope', 'assets/fonts/Manrope.ttf'),
    ('Bricolage', 'assets/fonts/BricolageGrotesque.ttf'),
    if (flutterRoot != null) ('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'),
  ];
  for (final (family, file) in fonts) {
    final f = File(file);
    if (!f.existsSync()) continue;
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
  }
}

/// Carpetas sintéticas (en memoria) para las capturas.
class _ShotAccess implements FolderAccess {
  _ShotAccess(this.current);
  final MemoryFolderFs current;
  static const drive = '/Users/entrenador/Library/CloudStorage/GoogleDrive/Mi unidad/Juegos';

  @override
  FolderSuggestion get suggestion => FolderSuggestion.iCloudDrive;

  @override
  Future<OpenedFolder?> pick() async =>
      OpenedFolder(const ArcaLocation(LocationKind.path, value: drive, label: drive), MemoryFolderFs(label: drive));

  @override
  Future<OpenedFolder> appLocal() async => OpenedFolder(const ArcaLocation(LocationKind.appLocal), current);

  @override
  Future<OpenedFolder> open(ArcaLocation location) async => OpenedFolder(location, current);
}

void main() {
  setUpAll(() async {
    if (!_enabled) return;
    await _loadFonts();
  });

  Future<void> prepare(WidgetTester tester) async {
    HttpOverrides.global = null;
    final cacheDir = Directory('../../.scratch/sprite-cache')..createSync(recursive: true);
    SpriteCache.instance = SpriteCache(directory: () async => cacheDir);
    await tester.runAsync(() => SpriteCache.instance.downloadAll());
    tester.platformDispatcher.localesTestValue = [shotsLocale];
    tester.platformDispatcher.localeTestValue = shotsLocale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  }

  Future<void> write(WidgetTester tester, GlobalKey boundary, String name) async {
    final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = await tester.runAsync(() async {
      final image = await ro.toImage(pixelRatio: 2);
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    shotFile(name).writeAsBytesSync(png!.buffer.asUint8List());
  }

  testWidgets('capturas de la guía: Arca, editor, Pokédex, eventos', skip: !_enabled, (tester) async {
    await prepare(tester);
    late final MemoryFolderFs tmp;
    late final ArcaDatabase db;
    late final ArcaRepository repo;
    late final DateTime now;
    late final int scarlet, emerald, sword;
    await tester.runAsync(() async {
      // Carpeta del Arca en memoria: las capturas no escriben en disco.
      tmp = MemoryFolderFs(label: 'PKArkTools');
      db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
      repo = ArcaRepository(db, ArcaFolder(tmp));
      now = DateTime(2026, 11, 22, 9, 30);

      // Historial: una partida de Esmeralda con tres copias en el tiempo.
      for (final (i, hours) in [(0, 31), (1, 44), (2, 48)]) {
        final raw = SyntheticSaves.gen3(
          trainer: SynthTrainer(name: 'MAY', tid: 31415, sid: 9265, gender: 1, hours: hours, minutes: 12),
          party: [
            const SynthMon(254, level: 52, nickname: 'LEAFY'),
            const SynthMon(260, level: 50),
            const SynthMon(282, level: 49, shiny: true),
            const SynthMon(334, level: 47),
            const SynthMon(373, level: 55),
            if (i > 0) const SynthMon(384, level: 70),
          ],
          boxes: {
            0: const [
              SynthMon(25, level: 22),
              SynthMon(133, level: 18, shiny: true),
              SynthMon(252, level: 5),
              null,
              SynthMon(280, level: 12),
              SynthMon(359, level: 33),
              SynthMon(328, level: 20),
              SynthMon(371, level: 30),
            ],
            1: const [SynthMon(350, level: 40), SynthMon(380, level: 50), SynthMon(381, level: 50)],
          },
          boxNames: const ['FAVORITOS', 'LEGENDS'],
        );
        // Progreso realista de Pokédex y medallas que crece con cada copia.
        final ed = SaveEditor.open(raw);
        final dex = ed.pokedex!;
        final upto = [120, 204, 262][i];
        for (var s = 1; s <= upto; s++) {
          if (s % 7 == 0) continue;
          dex.setSeen(s, true);
          if (s % 3 != 0) dex.setCaught(s, true);
        }
        final ev = ed.events!;
        for (var b = 0; b < [4, 6, 8][i]; b++) {
          ev.setFlag(2151 + b, true);
        }
        ed.writeTrainer(ed.readTrainer().copyWith(money: [48210, 91550, 123400][i]));
        if (i == 2) {
          final lead = ed.get(const SlotRef.party(0))!..level = 58;
          ed.set(const SlotRef.party(0), lead);
        }
        await repo.importBytes(
          ed.build(),
          fileName: 'Pokemon Esmeralda.sav',
          origin: i == 2 ? ImportOrigin.folder : ImportOrigin.file,
          now: now.subtract(Duration(days: (2 - i) * 9, hours: i)),
        );
      }
      var minutes = 0;
      for (final e in SyntheticSaves.demoSet().entries) {
        if (e.key.startsWith('Esmeralda')) continue;
        minutes += 37;
        await repo.importBytes(
          e.value,
          fileName: e.key,
          origin: ImportOrigin.demo,
          now: now.subtract(Duration(minutes: minutes * 11)),
        );
      }
      // Copia de Escarlata con un Pokémon "sospechoso" para la captura de avisos de legalidad.
      final svEditor = SaveEditor.open(SyntheticSaves.demoSet()['Escarlata_main']!);
      final odd = svEditor.get(const SlotRef.party(0))!
        ..setEvs(const [252, 252, 252, 0, 0, 0])
        ..setMove(1, 14, context: '9')
        ..setMove(
          2,
          [
            for (var m = 1; m < 900; m++)
              if (!MoveData.existsIn(m, '9')) m,
          ].first,
          context: '9',
        )
        ..ball = 30
        ..setRelearnMove(0, 14)
        ..refreshPartyStats();
      svEditor.set(const SlotRef.party(0), odd);
      await repo.importBytes(svEditor.build(), fileName: 'main', origin: ImportOrigin.file, now: now);

      final entries = await repo.watchArca().first;
      scarlet = entries.firstWhere((e) => e.slot.gameCode == 'sv').slot.id;
      emerald = entries.firstWhere((e) => e.slot.gameCode == 'emerald').slot.id;
      sword = entries.firstWhere((e) => e.slot.gameCode == 'swsh').slot.id;
    });

    final boundary = GlobalKey();
    Future<void> settle([int frames = 25]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> show(String location, Size size, {ThemeMode mode = ThemeMode.dark}) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      await tester.pumpWidget(const SizedBox());
      await settle(3);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ProviderScope(
            key: UniqueKey(),
            overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
            child: PKArkToolsApp(initialLocation: location),
          ),
        ),
      );
      await settle(8);
      final container = ProviderScope.containerOf(tester.element(find.byType(PKArkToolsApp)));
      await tester.runAsync(() => container.read(settingsProvider.notifier).setThemeMode(mode));
      await tester.runAsync(() => container.read(settingsProvider.notifier).setLocale(Locale(shotsLang)));
      await settle();
    }

    Future<void> capture(String name) async {
      await settle(10);
      await write(tester, boundary, name);
    }

    const desktop = Size(1440, 900);
    const mobile = Size(390, 844);

    await show('/arca', desktop);
    await capture('01_arca_escritorio');

    await show('/arca/save/$emerald', const Size(1440, 1500));
    await capture('02_detalle_esmeralda_escritorio');

    await show('/arca/save/$sword', const Size(1440, 1500));
    await capture('03_detalle_espada_escritorio');

    await show('/arca', mobile);
    await capture('04_arca_movil');

    await show('/arca/save/$sword', const Size(390, 1700));
    await capture('05_detalle_espada_movil');

    await show('/arca', desktop, mode: ThemeMode.light);
    await capture('06_arca_claro');

    await show('/actividad', const Size(1280, 860));
    await capture('07_actividad');

    await show('/ajustes', const Size(1280, 860));
    await capture('08_ajustes');

    // ---------------------------------------------------------------- Fase 2: editor
    // Con la app montada, sus consultas (zona de fake async) pueden retener
    // el candado de drift y bloquear una importación dentro de runAsync.
    Future<void> unmount() async {
      await tester.pumpWidget(const SizedBox());
      await settle(3);
    }

    Future<void> tapText(String text, {bool last = false}) async {
      final f = last ? find.text(text).last : find.text(text).first;
      await tester.ensureVisible(f);
      await settle(4);
      await tester.tap(f);
      await settle(14);
    }

    // Editor de Pokémon (escritorio): Meowscarada de Escarlata.
    await show('/arca/save/$scarlet', const Size(1440, 1100));
    await tapText('Meowscarada');
    await capture('10_editor_pokemon');
    await tapText(tr('IVs perfectos'));
    await tapText(tr('Atacante físico'));
    await tester.ensureVisible(find.text(tr('EVs (puntos de esfuerzo)')));
    await settle(10);
    await capture('11_editor_estadisticas');
    await tester.tap(find.text(tr('Cancelar')).last);
    await settle(10);
    await tester.tap(find.text(tr('Descartar')).last);
    await settle(10);

    // Cajas arrastrando (escritorio: arrastre con ratón).
    await show('/arca/save/$emerald', const Size(1440, 1500));
    final eevee = find.byWidgetPredicate((w) => w.runtimeType.toString() == 'SpeciesAvatar' && (w as dynamic).species == 133);
    final target = find.byWidgetPredicate((w) => w.runtimeType.toString() == 'SpeciesAvatar' && (w as dynamic).species == 359);
    await tester.ensureVisible(eevee);
    await settle(4);
    // Pulsación larga (LongPressDraggable) y arrastre hasta otro hueco.
    final g = await tester.startGesture(tester.getCenter(eevee), kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 700));
    await g.moveBy(const Offset(20, 8));
    await tester.pump();
    await g.moveTo(tester.getCenter(target) + const Offset(-6, -4));
    await tester.pump(const Duration(milliseconds: 100));
    await write(tester, boundary, '12_cajas_arrastrando');
    await g.up();
    await settle(10);

    // Entrenador, con un cambio en el borrador (el arrastre con pulsación
    // larga no se reproduce fuera de pantalla).
    await tapText(tr('Entrenador'));
    await tester.enterText(find.byType(TextField).first, 'MAYA');
    await settle(4);
    await tapText(tr('Aplicar cambios'));
    await capture('13_entrenador');

    // Inventario.
    await tapText(tr('Inventario'));
    await capture('14_inventario');

    // Guardar en el Arca con la nota de cambios.
    final save = find.widgetWithText(FilledButton, tr('Guardar en el Arca'));
    await tester.ensureVisible(save);
    await settle(4);
    await tester.tap(save);
    await settle(14);
    await capture('15_guardar_en_arca');
    await tester.tap(find.text(tr('Cancelar')).last);
    await settle(8);

    // Avisos de legalidad: ficha del Pokémon modificado.
    await show('/arca/save/$scarlet', const Size(1440, 1100));
    await tapText('Meowscarada');
    await capture('16_avisos_legalidad');
    await tester.tap(find.text(tr('Cancelar')).last);
    await settle(10);

    // Editor en móvil.
    await show('/arca/save/$scarlet', const Size(390, 844));
    await tapText('Meowscarada');
    await capture('17_editor_movil');
    await tester.tap(find.text(tr('Cancelar')).last);
    await settle(10);

    // ---------------------------------------------------------------- Fase 3
    // Pokédex de Esmeralda.
    await show('/arca/save/$emerald', const Size(1440, 1500));
    await tapText(tr('Pokédex'));
    await capture('18_pokedex');

    // Eventos con nombres (medallas, MO…).
    await tapText(tr('Eventos'));
    await capture('19_eventos');

    // Comparar la última copia con la anterior (el historial empieza plegado).
    final fold = find.textContaining(shotsSpanish ? 'Historial (' : 'History (');
    await tester.ensureVisible(fold);
    await settle(4);
    await tester.tap(fold);
    await settle(10);
    await tapText(tr('Comparar con…'));
    await settle(20);
    await capture('22_comparar_copias');

    // Legalidad detallada con explicación desplegada.
    await show('/arca/save/$scarlet', const Size(1440, 1100));
    await tapText('Meowscarada');
    final hisui = find.textContaining(tr('solo existe en Leyendas Arceus', 'only exists in Legends: Arceus'));
    await tester.ensureVisible(hisui);
    await settle(4);
    await tester.tap(hisui);
    await settle(10);
    await capture('20_legalidad_detallada');
    await tester.tap(find.text(tr('Cancelar')).last);
    await settle(10);

    // Importación en bloque: resumen previo de una carpeta de Checkpoint.
    await show('/arca', desktop);
    final known = (await tester.runAsync(repo.knownHashes))!;
    PickedSave picked(String n, List<int> b) => PickedSave(name: n, bytes: Uint8List.fromList(b), origin: ImportOrigin.folder);
    final demo = SyntheticSaves.demoSet();
    final existing = (await tester.runAsync(() async => repo.snapshotBytes((await repo.watchSnapshots(sword).first).first)))!;
    final scan = FolderScan(
      rootLabel: '/Volumes/SD/3ds/Checkpoint/saves',
      found: [
        FolderCandidate(
          file: picked('main', SyntheticSaves.gen4(party: const [SynthMon(392, level: 40)])),
          relativePath: '0x00ADA Pokémon Platinum/2026-11-20/main',
          game: GameVersion.platinum,
          trainer: 'LUCAS',
        ),
        FolderCandidate(
          file: picked('main', SyntheticSaves.ctr(layout: CtrLayout.usum, party: const [SynthMon(724, level: 55)])),
          relativePath: '0x01B50 Pokémon Ultra Moon/2026-11-18/main',
          game: GameVersion.ultraSunUltraMoon,
          trainer: 'Selene',
        ),
        FolderCandidate(
          file: picked('main', SyntheticSaves.ctr(layout: CtrLayout.xy, party: const [SynthMon(658, level: 60)])),
          relativePath: '0x0055D Pokémon Y/2026-10-02/main',
          game: GameVersion.xy,
          trainer: 'Serena',
        ),
        FolderCandidate(
          file: picked('main', existing),
          relativePath: 'switch/Sword/main',
          game: GameVersion.swordShield,
          trainer: 'Gloria',
        ),
        for (final k in demo.keys.where((k) => k.startsWith('Cristal')))
          FolderCandidate(file: picked(k, demo[k]!), relativePath: 'gbc/$k', game: GameVersion.crystal, trainer: 'KRIS'),
      ],
      scanned: 9,
      ignored: 14,
      unrecognized: const ['0x00ADA Pokémon Platinum/2026-11-20/extdata.bin', 'gba/save-backup.bak'],
    );
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(
      showDialog<void>(
        context: nav.context,
        builder: (_) => BulkImportDialog(scan: scan, known: known),
      ),
    );
    await settle(14);
    await capture('21_importacion_masiva');
    nav.pop();
    await settle(6);

    // Pokédex en móvil.
    await show('/arca/save/$emerald', const Size(390, 1500));
    await tapText(tr('Pokédex'));
    await capture('23_pokedex_movil');

    // ---------------------------------------------------------------- Fase 4
    // Pokédex de Espada/Escudo con progreso en Galar, Armadura y Corona Nieve.
    final swEd = SaveEditor.open(SyntheticSaves.demoSet()['Espada_main']!);
    final swDex = swEd.pokedex!;
    var k = 0;
    for (final s in swDex.species) {
      k++;
      if (k % 5 == 0) continue;
      swDex.setSeen(s, true);
      if (k % 3 != 0) swDex.setCaught(s, true);
      if (k % 11 == 0) swDex.setShinySeen(s, true);
      if (k % 2 == 0) swDex.setGenderSeen(s, 1, true);
    }
    for (var f = 0; f < swDex.formCount(849); f++) {
      swDex.setFormSeen(849, f, true);
    }
    swEd.writeTrainer(swEd.readTrainer().copyWith(money: 412500));
    await unmount();
    await tester.runAsync(
      () => repo.importBytes(
        swEd.buildVerified(),
        fileName: 'main',
        origin: ImportOrigin.file,
        now: now.add(const Duration(minutes: 3)),
      ),
    );
    await show('/arca/save/$sword', const Size(1440, 1500));
    await tapText(tr('Pokédex'));
    await tapText(tr('Isla de la Armadura'));
    await capture('24_pokedex_switch');
    await tester.tap(find.widgetWithText(ChoiceChip, tr('Todas')));
    await settle(10);
    final toxtricity = find.text('#849');
    await tester.ensureVisible(toxtricity);
    await settle(4);
    await tester.longPress(toxtricity);
    await settle(14);
    await capture('25_pokedex_detalle');
    await tester.tap(find.text(tr('Cancelar')).last);
    await settle(8);

    // Pokédex de Switch en móvil.
    await show('/arca/save/$sword', const Size(390, 1500));
    await tapText(tr('Pokédex'));
    await capture('26_pokedex_switch_movil');

    // Eventos con nombre en Ultrasol.
    final usEd = SaveEditor.open(SyntheticSaves.demoSet()['UltraSol.sav']!);
    final usEv = usEd.events!;
    final named = usEv.namedFlags(EventLanguage.es);
    for (var i = 0; i < named.length; i += 2) {
      usEv.setFlag(named[i].index, true);
    }
    await unmount();
    await tester.runAsync(
      () => repo.importBytes(
        usEd.buildVerified(),
        fileName: 'UltraSol.sav',
        origin: ImportOrigin.file,
        now: now.add(const Duration(minutes: 4)),
      ),
    );
    final usum = (await tester.runAsync(() => repo.watchArca().first))!.firstWhere((e) => e.slot.gameCode == 'usum').slot.id;
    await show('/arca/save/$usum', const Size(1440, 1500));
    await tapText(tr('Eventos'));
    await capture('27_eventos_gen7');

    // Legalidad de encuentros: Pikachu de X con un nivel de encuentro imposible.
    final slot = EncounterTables.forVersion(24).firstWhere((e) => e.species == 25 && e.kind == EncounterKind.wild);
    final xyEd = SaveEditor.open(
      SyntheticSaves.ctr(
        layout: CtrLayout.xy,
        trainer: const SynthTrainer(name: 'Serena', tid: 24680, sid: 1357, gender: 1, hours: 61, minutes: 7, versionId: 24),
        party: const [SynthMon(25, level: 70), SynthMon(658, level: 64), SynthMon(700, level: 60)],
      ),
    );
    final pika = xyEd.get(const SlotRef.party(0))!
      ..version = 24
      ..metLocation = slot.location
      ..metLevel = 60;
    xyEd.set(const SlotRef.party(0), pika);
    await unmount();
    await tester.runAsync(
      () => repo.importBytes(
        xyEd.buildVerified(),
        fileName: 'main',
        origin: ImportOrigin.file,
        now: now.add(const Duration(minutes: 5)),
      ),
    );
    final xy = (await tester.runAsync(() => repo.watchArca().first))!.firstWhere((e) => e.slot.gameCode == 'xy').slot.id;
    await show('/arca/save/$xy', const Size(1440, 1100));
    await tapText('Pikachu');
    final enc = find.textContaining(tr('imposible en Bosque de Novarte', 'impossible at Santalune Forest'));
    await tester.ensureVisible(enc);
    await settle(4);
    await tester.tap(enc);
    await settle(10);
    await capture('28_legalidad_encuentros');
    await tester.tap(find.text(tr('Cancelar')).last);
    await settle(10);

    final emptyDb = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final emptyRepo = ArcaRepository(emptyDb, ArcaFolder(tmp));
    tester.view.physicalSize = desktop * 2;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ProviderScope(
          key: UniqueKey(),
          overrides: [arcaRepositoryProvider.overrideWithValue(emptyRepo)],
          child: const PKArkToolsApp(),
        ),
      ),
    );
    await settle();
    final c = ProviderScope.containerOf(tester.element(find.byType(PKArkToolsApp)));
    await tester.runAsync(() => c.read(settingsProvider.notifier).setLocale(Locale(shotsLang)));
    await settle();
    await capture('09_arca_vacia');

    await tester.pumpWidget(const SizedBox());
    await settle(4);
    await tester.runAsync(db.close);
    await tester.runAsync(emptyDb.close);
  });

  testWidgets('capturas de la guía: carpeta del Arca', skip: !_enabled, (tester) async {
    await prepare(tester);
    late final MemoryFolderFs fs;
    late final ArcaRepository mac;
    final dbs = <ArcaDatabase>[];
    ArcaDatabase newDb() {
      final db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
      dbs.add(db);
      return db;
    }

    const icloud = '/Users/entrenador/Library/Mobile Documents/com~apple~CloudDocs/Juegos';
    await tester.runAsync(() async {
      fs = MemoryFolderFs(label: icloud);

      // Dos dispositivos escriben en la misma carpeta.
      mac = ArcaRepository(newDb(), ArcaFolder(fs), deviceName: 'Mac (macos)');
      final phone = ArcaRepository(newDb(), ArcaFolder(fs), deviceName: 'iPhone (ios)');
      final now = DateTime(2026, 11, 22, 9, 30);
      var i = 0;
      for (final e in SyntheticSaves.demoSet().entries) {
        final repo = i.isEven ? mac : phone;
        await repo.importBytes(
          e.value,
          fileName: e.key,
          origin: ImportOrigin.demo,
          now: now.subtract(Duration(hours: 7 * i++)),
        );
      }
      // El mismo save importado también en el otro dispositivo (se deduplica).
      final first = SyntheticSaves.demoSet().entries.first;
      await phone.importBytes(
        first.value,
        fileName: first.key,
        origin: ImportOrigin.file,
        now: now.add(const Duration(hours: 1)),
      );
      // Un save copiado a mano, una copia de conflicto, un parcial de iCloud y
      // un save cuyo .json aún no ha llegado.
      await fs.writeNew(
        'PKArkTools/Copiados a mano/Pokemon Platino.sav',
        SyntheticSaves.gen4(trainer: const SynthTrainer(name: 'DAWN', tid: 4242, hours: 77)),
      );
      final listing = await mac.folder.listing();
      final some = listing.pairs.keys.first;
      final base = some.substring(0, some.lastIndexOf('.'));
      await fs.writeNew('PKArkTools/$base (conflicted copy).sav', Uint8List(16));
      await fs.writeNew(
        'PKArkTools/${some.substring(0, some.lastIndexOf('/'))}/.2026-11-22_101010_0badc0de.sav.icloud',
        Uint8List(4),
      );
      await fs.writeNew(
        'PKArkTools/${some.substring(0, some.lastIndexOf('/'))}/2026-11-22_111111_5eedf00d.sav',
        SyntheticSaves.gen3(trainer: const SynthTrainer(name: 'WALLY')),
      );
      await mac.reindex();
    });

    final boundary = GlobalKey();
    Future<void> settle([int frames = 25]) async {
      for (var f = 0; f < frames; f++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> show(String location, Size size, {required ArcaRepository repo, required ArcaSetup setup}) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      await tester.pumpWidget(const SizedBox());
      await settle(3);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ProviderScope(
            key: UniqueKey(),
            overrides: [
              arcaRepositoryProvider.overrideWithValue(repo),
              initialArcaSetupProvider.overrideWithValue(setup),
              folderAccessProvider.overrideWithValue(_ShotAccess(fs)),
            ],
            child: PKArkToolsApp(initialLocation: location),
          ),
        ),
      );
      await settle(8);
      final container = ProviderScope.containerOf(tester.element(find.byType(PKArkToolsApp)));
      await tester.runAsync(() => container.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark));
      await tester.runAsync(() => container.read(settingsProvider.notifier).setLocale(Locale(shotsLang)));
      await settle();
    }

    Future<void> capture(String name) async {
      await settle(10);
      await write(tester, boundary, name);
    }

    final fresh = ArcaRepository(newDb(), null, deviceName: 'Mac (macos)');
    await show('/arca', const Size(1440, 900), repo: fresh, setup: const SetupNeeded(legacyCount: 12));
    await capture('29_onboarding');

    await show('/arca', const Size(390, 1240), repo: fresh, setup: const SetupNeeded());
    await capture('30_onboarding_movil');

    const ready = SetupReady(ArcaLocation(LocationKind.bookmark, value: 'x', label: icloud));
    await show('/ajustes', const Size(1280, 1500), repo: mac, setup: ready);
    await capture('31_ajustes_carpeta');

    await tester.tap(find.text(tr('Reindexar')));
    await settle(20);
    await capture('32_reindexado');

    await tester.tap(find.text(tr('Cambiar carpeta…')));
    await settle(12);
    await capture('33_cambiar_carpeta');
    await tester.tap(find.text(tr('Cancelar')));
    await settle(6);

    await show(
      '/arca',
      const Size(1440, 900),
      repo: fresh,
      setup: const SetupAccessLost(
        ArcaLocation(LocationKind.bookmark, value: 'x', label: '/Volumes/USB/PKArkTools'),
        'La carpeta /Volumes/USB/PKArkTools no está disponible',
      ),
    );
    await capture('34_acceso_perdido');

    await tester.pumpWidget(const SizedBox());
    await settle(4);
    for (final db in dbs) {
      await tester.runAsync(db.close);
    }
  });

  testWidgets('capturas de la guía: última versión, carpetas de juegos y bandeja', skip: !_enabled, (tester) async {
    await prepare(tester);
    late final MemoryFolderFs fs;
    late final ArcaDatabase db;
    late final ArcaRepository repo;
    late final int may;
    const icloud = '/Users/entrenador/Library/Mobile Documents/com~apple~CloudDocs/Juegos';
    await tester.runAsync(() async {
      fs = MemoryFolderFs(label: icloud);
      db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
      repo = ArcaRepository(db, ArcaFolder(fs), deviceName: 'Mac (macos)', inboxSettle: Duration.zero);
      final base = DateTime(2026, 11, 22, 17, 52, 58);
      for (final (i, hours) in [(0, 31), (1, 44), (2, 48)]) {
        await repo.importBytes(
          SyntheticSaves.gen3(
            trainer: SynthTrainer(name: 'MAY', tid: 31415, sid: 9265, gender: 1, hours: hours, minutes: 12),
            party: [
              const SynthMon(254, level: 52, nickname: 'LEAFY'),
              const SynthMon(282, level: 49, shiny: true),
              if (i > 0) const SynthMon(384, level: 70),
            ],
          ),
          fileName: 'Pokemon Emerald.sav',
          origin: i == 1 ? ImportOrigin.edit : ImportOrigin.folder,
          note: i == 1 ? 'Team: Rayquaza' : null,
          now: base.subtract(Duration(days: 2 - i)),
        );
      }
      may = (await repo.allSlots()).single.$1.id;
      await ArcaGameFolders.create(repo.folder, {GameVersion.emerald, GameVersion.platinum, GameVersion.swordShield},
          es: shotsSpanish);
      // Un save de otro juego dejado en la bandeja de Esmeralda.
      await fs.writeNew('PKArkTools/Pokémon Esmeralda/POKEMON_PL_CPUS01.sav',
          SyntheticSaves.gen4(trainer: const SynthTrainer(name: 'DAWN', tid: 4242)));
      await repo.reindex();
    });

    final boundary = GlobalKey();
    Future<void> settle([int frames = 25]) async {
      for (var f = 0; f < frames; f++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    late ProviderContainer container;
    Future<void> show(String location, Size size) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      await tester.pumpWidget(const SizedBox());
      await settle(3);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ProviderScope(
            key: UniqueKey(),
            overrides: [
              arcaRepositoryProvider.overrideWithValue(repo),
              initialArcaSetupProvider.overrideWithValue(
                  const SetupReady(ArcaLocation(LocationKind.bookmark, value: 'x', label: icloud))),
              folderAccessProvider.overrideWithValue(_ShotAccess(fs)),
            ],
            child: PKArkToolsApp(initialLocation: location),
          ),
        ),
      );
      await settle(8);
      container = ProviderScope.containerOf(tester.element(find.byType(PKArkToolsApp)));
      await tester.runAsync(() => container.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark));
      await tester.runAsync(() => container.read(settingsProvider.notifier).setLocale(Locale(shotsLang)));
      await settle();
    }

    Future<void> capture(String name) async {
      await settle(10);
      await write(tester, boundary, name);
    }

    await show('/arca/save/$may', const Size(1440, 1000));
    await capture('v2/mac_42_version_actual');

    // El usuario copia a mano un save nuevo encima del archivo principal.
    await tester.runAsync(() async {
      await fs.writeReplace('PKArkTools/Pokémon Esmeralda/MAY (31415)/Pokémon Esmeralda.sav',
          SyntheticSaves.gen3(trainer: const SynthTrainer(name: 'MAY', tid: 31415, sid: 9265, gender: 1, hours: 52)));
      await repo.reindex();
    });
    await show('/ajustes', const Size(1280, 1900));
    await capture('v2/mac_43_ajustes_arca');

    await show('/arca', const Size(1440, 900));
    await tester.runAsync(() async {
      await repo.setSetting(GameFoldersPrompt.askedKey, '');
      await container.read(gameFoldersPromptProvider.notifier).request();
    });
    await settle(15);
    await capture('v2/mac_40_carpetas_juegos_pregunta');
    await tester.tap(find.text(tr('Elegir juegos…')));
    await settle(15);
    await tester.tap(find.byKey(const ValueKey('platform-nintendoSwitch')).last);
    await settle(6);
    await capture('v2/mac_41_carpetas_juegos_selector');

    await tester.pumpWidget(const SizedBox());
    await settle(4);
    await tester.runAsync(db.close);
  });
}
