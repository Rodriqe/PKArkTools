// Filtros de la pestaña Arca: origen de cada copia, combinaciones, orden,
// recuento, estado vacío, persistencia por dispositivo y diseño en teléfono
// (sin desbordes) y escritorio (panel lateral), todo offscreen.
import 'dart:io';
import 'dart:typed_data';

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
import 'package:pkarktools/ui/arca/arca_filter.dart';
import 'package:pkarktools/ui/arca/save_card.dart';

import 'arca_folder_test.dart' show memoryDb;
import 'arca_screen_test.dart' show settle;
import 'phone_layout_test.dart' show loadAppFonts;

final _now = DateTime(2026, 11, 20, 12);

/// Arca de ejemplo con orígenes, fechas, ediciones y copias variadas.
Future<void> seed(ArcaRepository repo) async {
  final demo = SyntheticSaves.demoSet();
  Future<void> add(String key, {String? path, DateTime? at, ImportOrigin origin = ImportOrigin.file, Uint8List? bytes}) async {
    final r = await repo.importBytes(bytes ?? demo[key]!, fileName: key, origin: origin, sourcePath: path, now: at ?? _now);
    expect(r, isA<ImportAdded>(), reason: key);
  }

  await add('Esmeralda.sav', path: '/Users/ana/mGBA/saves/Esmeralda.sav', at: _now.subtract(const Duration(days: 3)));
  await add('Espada_main', path: '/Users/ana/Ryujinx/bis/user/save/0000000000000001/0/main');
  await add('Escarlata_main', path: '/Users/ana/Descargas/main', at: _now.subtract(const Duration(days: 60)));
  await add('Cristal.sav', path: '/Volumes/GBxCart/Cristal.sav', at: _now.subtract(const Duration(days: 400)));
  await add('Platino.sav',
      path: 'content://com.android.externalstorage.documents/tree/primary%3ADraStic%2Fbackup/Platino.dsv',
      origin: ImportOrigin.saf);
  await add('Rojo.sav', path: '/Users/ana/RetroArch/saves/Rojo.srm');
  await add('UltraSol.sav', path: '/sd/3ds/Checkpoint/saves/0x01B50 Ultra Sun/main', at: _now.subtract(const Duration(days: 10)));
  await add('Arceus_main', origin: ImportOrigin.demo);
  // Segunda copia de MAY (más horas) y una edición de Gloria.
  await add('Esmeralda_2.sav',
      bytes: SyntheticSaves.gen3(
        game: GameVersion.emerald,
        trainer: const SynthTrainer(name: 'MAY', tid: 31415, sid: 9265, gender: 1, hours: 49, minutes: 12),
        party: const [SynthMon(254, level: 53)],
      ),
      path: '/Users/ana/mGBA/saves/Esmeralda.sav',
      at: _now.subtract(const Duration(days: 1)));
  await add('Espada_editada',
      bytes: SyntheticSaves.swordShield(
          trainer: const SynthTrainer(name: 'Gloria', tid: 0xA1B2, sid: 0x0C3D, gender: 1, hours: 210, minutes: 9, versionId: 44)),
      origin: ImportOrigin.edit);
}

void main() {
  group('SaveSource.classify', () {
    SaveSource c({String? f, String? p, String? n, String? o}) =>
        SaveSource.classify(formatInfo: f, sourcePath: p, fileName: n, origin: o);

    test('reconoce cada origen', () {
      expect(c(f: 'Save 3DS (exportado con Checkpoint/JKSM)'), SaveSource.checkpoint);
      expect(c(p: '/switch/JKSM/Pokemon Escarlata/main'), SaveSource.checkpoint);
      expect(c(f: 'Flash NDS 512 KB · DeSmuME (.dsv)'), SaveSource.emulator);
      expect(c(p: r'C:\Users\a\AppData\Roaming\yuzu\nand\user\save\0\main'), SaveSource.emulator);
      expect(c(n: 'Pokemon - Esmeralda.srm'), SaveSource.emulator);
      expect(c(p: 'content://com.android.externalstorage.documents/tree/x', o: 'saf'), SaveSource.mobile);
      expect(c(p: '/private/var/mobile/Containers/Shared/AppGroup/x/Delta/Esmeralda.sav'), SaveSource.mobile);
      expect(c(p: '/Volumes/GBxCart/Cristal.sav'), SaveSource.cartridge);
      expect(c(p: '/Users/a/Descargas/Esmeralda.sav'), SaveSource.other);
      expect(c(p: '/sd/Checkpoint/x', o: 'demo'), SaveSource.other);
    });
  });

  group('ArcaFilter', () {
    test('JSON: ida y vuelta, sin búsqueda, tolerante a valores desconocidos', () {
      final f = ArcaFilter(
        query: 'may',
        generations: {3, 8},
        platforms: {Platform.nintendoSwitch},
        sources: {SaveSource.checkpoint},
        games: {'sv:50'},
        statuses: {ArcaStatus.edited},
        from: DateTime(2026, 1, 2),
        to: DateTime(2026, 3, 4),
        sort: ArcaSort.playTime,
      );
      final back = ArcaFilter.fromJson(f.toJson());
      expect(back.query, '');
      expect(back.generations, {3, 8});
      expect(back.platforms, {Platform.nintendoSwitch});
      expect(back.sources, {SaveSource.checkpoint});
      expect(back.games, {'sv:50'});
      expect(back.statuses, {ArcaStatus.edited});
      expect(back.from, DateTime(2026, 1, 2));
      expect(back.to, DateTime(2026, 3, 4));
      expect(back.sort, ArcaSort.playTime);
      expect(back.activeCount, 7);
      final odd = ArcaFilter.fromJson({'sort': 'nope', 'gen': [0, 3, 'x', 12], 'platform': ['wii'], 'preset': 'week'});
      expect(odd.sort, ArcaSort.recent);
      expect(odd.generations, {3});
      expect(odd.platforms, isEmpty);
      expect(odd.datePreset, DatePreset.week);
      expect(ArcaFilter.fromJson(null).isActive, isFalse);
    });

    group('sobre un Arca real', () {
      late ArcaDatabase db;
      late Directory tmp;
      late ArcaRepository repo;
      late List<ArcaEntry> all;

      setUp(() async {
        db = memoryDb();
        tmp = await Directory.systemTemp.createTemp('arca_filters');
        repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
        await seed(repo);
        all = await repo.watchArca().first;
      });

      tearDown(() async {
        await db.close();
        await tmp.delete(recursive: true);
      });

      List<String> names(ArcaFilter f) => [for (final e in f.apply(all, now: _now)) e.slot.trainerName];

      test('cada grupo y sus combinaciones', () {
        expect(all, hasLength(8));
        expect(names(const ArcaFilter(generations: {3, 4})).toSet(), {'MAY', 'Dawn'});
        expect(names(const ArcaFilter(generations: {8}, platforms: {Platform.nintendoSwitch})).length, 2);
        expect(names(const ArcaFilter(platforms: {Platform.gameBoy, Platform.gameBoyColor})).toSet(), {'RED', 'KRIS'});
        expect(names(const ArcaFilter(sources: {SaveSource.checkpoint})), ['Elio']);
        expect(names(const ArcaFilter(sources: {SaveSource.mobile})), ['Dawn']);
        expect(names(const ArcaFilter(sources: {SaveSource.cartridge})), ['KRIS']);
        expect(names(const ArcaFilter(sources: {SaveSource.emulator})).toSet(), {'MAY', 'Gloria', 'RED'});
        expect(names(const ArcaFilter(sources: {SaveSource.emulator, SaveSource.cartridge})).length, 4);
        expect(names(const ArcaFilter(games: {'swsh:44', 'sv:50'})).toSet(), {'Gloria', 'Juliana'});
        expect(names(const ArcaFilter(statuses: {ArcaStatus.multipleCopies})).toSet(), {'MAY', 'Gloria'});
        expect(names(const ArcaFilter(statuses: {ArcaStatus.edited})), ['Gloria']);
        expect(names(const ArcaFilter(statuses: {ArcaStatus.damaged})), isEmpty);
        // Y entre grupos: emulador + Gen 3 = solo MAY.
        expect(names(const ArcaFilter(sources: {SaveSource.emulator}, generations: {3})), ['MAY']);
        expect(names(const ArcaFilter(sources: {SaveSource.checkpoint}, generations: {3})), isEmpty);
      });

      test('rango de fechas de la última copia', () {
        expect(names(const ArcaFilter(datePreset: DatePreset.week)).toSet(), {'MAY', 'Gloria', 'Dawn', 'RED', 'Akari'});
        final month = names(const ArcaFilter(datePreset: DatePreset.month)).toSet();
        expect(month.containsAll({'MAY', 'Elio'}), isTrue);
        expect(month.contains('Juliana'), isFalse); // hace 60 días
        expect(names(const ArcaFilter(datePreset: DatePreset.year)).contains('KRIS'), isFalse); // hace 400 días
        final custom = ArcaFilter(from: _now.subtract(const Duration(days: 61)), to: _now.subtract(const Duration(days: 59)));
        expect(names(custom), ['Juliana']);
      });

      test('orden', () {
        expect(names(const ArcaFilter(sort: ArcaSort.playTime)).first, 'Gloria'); // 210 h
        expect(names(const ArcaFilter(sort: ArcaSort.copies)).take(2).toSet(), {'MAY', 'Gloria'});
        final byName = names(const ArcaFilter(sort: ArcaSort.trainer));
        expect(byName, [...byName]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));
        final byGame = const ArcaFilter(sort: ArcaSort.game).apply(all, now: _now);
        expect(byGame.first.slot.generation, 1);
        expect(byGame.last.slot.generation, 9);
        expect(names(const ArcaFilter(sort: ArcaSort.recent)).last, 'KRIS');
      });

      test('legalidad: se cuenta sin errores y alimenta el filtro', () async {
        final warnings = {for (final e in all) e.latest.id: await repo.legalityWarnings(e.latest)};
        expect(warnings.values.every((n) => n >= 0), isTrue);
        final flagged = {for (final e in all) if (warnings[e.latest.id]! > 0) e.slot.trainerName};
        final got = const ArcaFilter(statuses: {ArcaStatus.legality}).apply(all, now: _now, warnings: warnings);
        expect({for (final e in got) e.slot.trainerName}, flagged);
        // Una partida sin revisar no pasa el filtro de legalidad.
        expect(const ArcaFilter(statuses: {ArcaStatus.legality}).apply(all, now: _now), isEmpty);
      });
    });
  });

  group('pestaña Arca', () {
    late ArcaDatabase db;
    late Directory tmp;
    late ArcaRepository repo;

    setUpAll(loadAppFonts);

    setUp(() async {
      db = memoryDb();
      tmp = await Directory.systemTemp.createTemp('arca_filters_ui');
      repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
    });

    tearDown(() async {
      await db.close();
      await tmp.delete(recursive: true);
    });

    Future<void> pumpApp(WidgetTester tester, Size size, {double textScale = 1}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.localesTestValue = const [Locale('es')];
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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

    Future<void> tapKey(WidgetTester tester, String key) async {
      final f = find.byKey(Key(key));
      await tester.ensureVisible(f);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(f);
      await settle(tester);
    }

    /// Texto del recuento (vuelve arriba si la cabecera quedó fuera de la vista).
    Future<String> countText(WidgetTester tester) async {
      final f = find.byKey(const Key('arca-count'));
      if (f.evaluate().isEmpty) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
        await settle(tester);
      }
      return tester.widget<Text>(f).data!;
    }

    testWidgets('escritorio: panel lateral, combinaciones, chips quitables y estado vacío', (tester) async {
      await tester.runAsync(() => seed(repo));
      await pumpApp(tester, const Size(1440, 900));
      expect(find.byKey(const Key('arca-side-panel')), findsOneWidget);
      expect(find.byKey(const Key('arca-filters-button')), findsNothing);
      expect(await countText(tester), '8 partidas a salvo');

      await tapKey(tester, 'gen-3');
      expect(await countText(tester), '1 partida de 8');
      expect(find.text('MAY'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Gen 3'), findsOneWidget);

      await tapKey(tester, 'gen-8');
      expect(await countText(tester), '3 partidas de 8');

      // Con Gen 3 u 8 ningún save es de Checkpoint/JKSM: esa opción se desactiva.
      expect(tester.widget<FilterChip>(find.byKey(const Key('source-checkpoint'))).onSelected, isNull);
      await tapKey(tester, 'source-emulator');
      expect(await countText(tester), '2 partidas de 8');
      expect(find.text('RED'), findsNothing);

      // Quitar el chip de origen devuelve los resultados.
      await tester.tap(find.byTooltip('Quitar filtro Emulador'));
      await settle(tester);
      expect(await countText(tester), '3 partidas de 8');

      await tapKey(tester, 'arca-filters-clear');
      expect(await countText(tester), '8 partidas a salvo');

      // Vacío por búsqueda + filtro, y «Limpiar filtros» lo limpia todo.
      await tapKey(tester, 'platform-gameBoy');
      await tester.enterText(find.byType(TextField).first, 'gloria');
      await settle(tester);
      expect(find.text('Ninguna partida coincide'), findsOneWidget);
      await tapKey(tester, 'arca-no-match-clear');
      expect(await countText(tester), '8 partidas a salvo');
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '');
    });

    testWidgets('orden desde el menú y desde el panel', (tester) async {
      await tester.runAsync(() => seed(repo));
      await pumpApp(tester, const Size(1440, 900));
      List<String> order() => [for (final c in tester.widgetList<SaveCard>(find.byType(SaveCard))) c.entry.slot.trainerName];
      await tapKey(tester, 'sort-playTime');
      expect(order().first, 'Gloria');
      await tester.tap(find.byKey(const Key('arca-sort-button')));
      await settle(tester);
      await tester.tap(find.text('Entrenador').last);
      await settle(tester);
      expect(order().take(3), ['Akari', 'Dawn', 'Elio']);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('sort-trainer'))).selected, isTrue);
    });

    testWidgets('la selección se recuerda en los ajustes locales', (tester) async {
      await tester.runAsync(() => seed(repo));
      await pumpApp(tester, const Size(1440, 900));
      await tapKey(tester, 'platform-nintendoSwitch');
      await tapKey(tester, 'sort-copies');
      final saved = await tester.runAsync(() => repo.getJsonSetting('arcaFilter'));
      expect(saved!['platform'], ['nintendoSwitch']);
      expect(saved['sort'], 'copies');
      // Nunca en la carpeta del Arca.
      final inFolder = tmp.listSync(recursive: true).whereType<File>().where((f) => !f.path.endsWith('.sav') && !f.path.endsWith('main')).where((f) => f.readAsStringSync().contains('nintendoSwitch'));
      expect(inFolder, isEmpty);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await pumpApp(tester, const Size(1440, 900));
      expect(await countText(tester), '3 partidas de 8');
      expect(find.widgetWithText(InputChip, 'Switch'), findsOneWidget);
    });

    testWidgets('ventana mediana: «Filtros» abre el panel derecho', (tester) async {
      await tester.runAsync(() => seed(repo));
      await pumpApp(tester, const Size(900, 800));
      expect(find.byKey(const Key('arca-side-panel')), findsNothing);
      await tapKey(tester, 'arca-filters-button');
      await tapKey(tester, 'status-multipleCopies');
      expect(find.text('Ver 2 partidas'), findsOneWidget);
      await tapKey(tester, 'panel-show');
      expect(await countText(tester), '2 partidas de 8');
      expect(find.text('Filtros · 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    const phones = {
      '320×568': (Size(320, 568), 1.0),
      '360×800': (Size(360, 800), 1.0),
      '430×932': (Size(430, 932), 1.0),
      '360×800 texto 130 %': (Size(360, 800), 1.3),
    };
    for (final MapEntry(key: name, value: (size, scale)) in phones.entries) {
      testWidgets('teléfono $name: chips, hoja de filtros y vacío sin desbordes', (tester) async {
        await tester.runAsync(() => seed(repo));
        tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
        await pumpApp(tester, size, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('arca-filters-button')), findsOneWidget);

        await tapKey(tester, 'arca-filters-button');
        expect(find.text('Generación'.toUpperCase()), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'hoja abierta');
        await tapKey(tester, 'gen-1');
        await tapKey(tester, 'gen-2');
        await tapKey(tester, 'source-cartridge');
        expect(tester.takeException(), isNull, reason: 'hoja con selección');
        // Desplazar la hoja hasta el final.
        for (var i = 0; i < 6; i++) {
          await tester.drag(find.byKey(const Key('gen-1')), const Offset(0, -300), warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(tester.takeException(), isNull, reason: 'hoja desplazada');
        expect(find.text('Ver 1 partida'), findsOneWidget);
        await tapKey(tester, 'panel-show');
        expect(find.text('KRIS'), findsOneWidget);
        expect(find.text('Filtros · 3'), findsOneWidget);
        expect(await countText(tester), '1 partida de 8');

        // Quitar el origen desde su chip: aparece también RED.
        final remove = find.byTooltip('Quitar filtro Cartucho');
        await tester.ensureVisible(remove);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(remove);
        await settle(tester);
        expect(await countText(tester), '2 partidas de 8');
        expect(tester.takeException(), isNull, reason: 'resultado');

        // Sin coincidencias: estado vacío claro.
        await tester.enterText(find.byType(TextField).first, 'nadie');
        await settle(tester);
        expect(find.text('Ninguna partida coincide'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'vacío');
        await tapKey(tester, 'arca-no-match-clear');
        expect(await countText(tester), '8 partidas a salvo');
      });
    }
  });
}
