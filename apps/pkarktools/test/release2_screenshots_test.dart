import 'dart:async';
import 'dart:io' hide Platform;
import 'dart:io' as io show Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/data/sprites/sprite_cache.dart';
import 'package:pkarktools/providers.dart';
import 'package:pkarktools/ui/editor/pokemon_editor.dart';
import 'package:pkarktools/ui/events/event_explorer.dart';
import 'package:pkarktools/ui/tools/share_card.dart';
import 'package:pkarktools/ui/tools/stat_calculator.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';

import 'arca_folder_test.dart' show memoryDb;
import 'shots_i18n.dart';

/// Capturas de escritorio de las novedades de la 2.0 (`<SHOTS_OUT>/v2.0/*.png`)
/// con partidas sintéticas, offscreen:
///
///   flutter test test/release2_screenshots_test.dart --dart-define=SHOTS_V2=true \
///     [--dart-define=SHOTS_LANG=es] [--dart-define=SHOTS_OUT=<carpeta>]
///
/// Sin la define se omite (el CI no reescribe capturas).
const _enabled = bool.fromEnvironment('SHOTS_V2');

Future<void> _loadFonts() async {
  final flutterRoot = io.Platform.environment['FLUTTER_ROOT'];
  for (final (family, file) in [
    ('Manrope', 'assets/fonts/Manrope.ttf'),
    ('Bricolage', 'assets/fonts/BricolageGrotesque.ttf'),
    ('NotoSansSymbols', 'assets/fonts/NotoSansSymbols-Subset.ttf'),
    ('NotoSansSymbols2', 'assets/fonts/NotoSansSymbols2-Subset.ttf'),
    if (flutterRoot != null) ('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'),
  ]) {
    final f = File(file);
    if (f.existsSync()) await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
  }
}

Uint8List _scarlet() => SyntheticSaves.scarletViolet(
      trainer: const SynthTrainer(name: 'Juliana', tid: 12345, sid: 2024, gender: 1, versionId: 50),
      party: const [
        SynthMon(908, level: 52),
        SynthMon(959, level: 50),
        SynthMon(445, level: 55),
        SynthMon(282, level: 50),
        SynthMon(149, level: 58),
        SynthMon(25, level: 40, shiny: true),
      ],
      boxes: {
        0: const [SynthMon(906, level: 12), SynthMon(1000, level: 60), SynthMon(1007, level: 72)],
      },
      boxNames: _boxNames,
    );

Uint8List _ultraSun() => SyntheticSaves.ctr(
      layout: CtrLayout.usum,
      trainer: const SynthTrainer(name: 'Elio', tid: 54321, sid: 777, versionId: 32),
      party: const [SynthMon(724, level: 45), SynthMon(26, level: 40)],
      boxes: {
        0: const [SynthMon(722, level: 10), SynthMon(133, level: 21), SynthMon(744, level: 18)],
      },
    );

Uint8List _sword() => SyntheticSaves.swordShield(
      trainer: const SynthTrainer(name: 'Victor', tid: 11223, sid: 4455, versionId: 44),
      party: const [SynthMon(813, level: 20)],
      boxNames: _boxNames,
    );

List<String> get _boxNames => [for (var i = 1; i <= 32; i++) shotsSpanish ? 'Caja $i' : 'Box $i'];

void main() {
  testWidgets('capturas de la 2.0', skip: !_enabled, timeout: const Timeout(Duration(minutes: 20)), (tester) async {
    await _loadFonts();
    HttpOverrides.global = null;
    final cacheDir = Directory('../../.scratch/sprite-cache')..createSync(recursive: true);
    SpriteCache.instance = SpriteCache(directory: () async => cacheDir);
    addTearDown(tester.view.reset);
    final tmp = Directory('../../.scratch/tmp/release2-shots-$shotsLang');
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    tmp.createSync(recursive: true);
    final repo = ArcaRepository(memoryDb(), ArcaFolder(IoFolderFs(tmp)));
    Future<int> import(Uint8List bytes, String name) async {
      final out = await tester.runAsync(() => repo.importBytes(bytes, fileName: name, origin: ImportOrigin.demo));
      return (await tester.runAsync(() => repo.snapshot((out! as ImportAdded).snapshotId)))!.slotId;
    }

    final sv = await import(_scarlet(), 'sv/main');
    final us = await import(_ultraSun(), 'usum/main');
    final sw = await import(_sword(), 'swsh/main');

    Future<void> settle([int frames = 25]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> until(Finder f, [int tries = 40]) async {
      for (var i = 0; i < tries && f.evaluate().isEmpty; i++) {
        await settle(4);
      }
    }

    final boundary = GlobalKey();
    Future<void> write(String name) async {
      await settle(6);
      final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final png = await tester.runAsync(() async {
        final image = await ro.toImage(pixelRatio: 1.5);
        return image.toByteData(format: ui.ImageByteFormat.png);
      });
      shotFile('v2.0/$name').writeAsBytesSync(png!.buffer.asUint8List());
    }

    Future<void> open(String at, Size size) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.localesTestValue = [shotsLocale];
      await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: ProviderScope(
          key: UniqueKey(),
          overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
          child: PKArkToolsApp(initialLocation: at),
        ),
      ));
      await settle();
    }

    BuildContext appContext() => tester.element(find.byType(Scaffold).last);
    const desktop = Size(1440, 900);

    // 1. Explorador de eventos.
    await open('/dex/eventos', desktop);
    await write('01_events_explorer');

    // 2. Crear desde un evento (selector del hueco vacío) en Espada/Escudo.
    await open('/arca/save/$sw', desktop);
    unawaited(EventPicker.show(appContext(), GameVersion.swordShield, saveLanguage: 2));
    await settle();
    await tester.enterText(find.byKey(const ValueKey('events-search')), 'zeraora');
    await settle(10);
    final zeraora = EventDb.creatableIn(GameVersion.swordShield).firstWhere((g) => g.species == 807);
    await tester.tap(find.byKey(ValueKey('event-${zeraora.id}')));
    await settle();
    await write('02_create_from_event');

    // 3-5. Living Dex en la partida actual: botón, normal/variocolor, aviso y resumen.
    await open('/arca/save/$sw', const Size(1440, 1100));
    final ld = find.byKey(const Key('livingDexButton'));
    await until(ld);
    await tester.ensureVisible(ld);
    await settle(6);
    await write('03_living_dex_button');
    await tester.tap(ld);
    await settle(10);
    await write('04_living_dex_normal_shiny');
    await tester.tap(find.byKey(const Key('livingDexShiny')));
    await settle(10);
    await write('05_living_dex_overwrite');
    await tester.tap(find.byType(FilledButton).last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await until(find.byKey(const Key('livingDexSummary')), 80);
    await write('06_living_dex_summary');

    // 7. Transferir: de Ultrasol a Escarlata (pasa por HOME).
    await open('/arca/save/$us', const Size(1440, 1500));
    await until(find.byKey(const ValueKey('tool-transfer')));
    await tester.tap(find.byKey(const ValueKey('tool-transfer')));
    await settle(15);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await settle();
    final eevee = find.byTooltip(RegExp(shotsSpanish ? 'Eevee' : 'Eevee'));
    if (eevee.evaluate().isNotEmpty) await tester.tap(eevee.first);
    await settle(6);
    final dest = find.textContaining(shotsSpanish ? 'Escarlata' : 'Scarlet');
    if (dest.evaluate().isNotEmpty) await tester.tap(dest.first);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await settle(20);
    await write('07_transfer');

    // 8. Formato oficial (Pokémon Champions).
    await open('/dex/formato-oficial', desktop);
    await write('08_official_format');

    // 9-11. Herramientas de la partida: calculadora, Showdown y tarjeta.
    await open('/arca/save/$sv', const Size(1440, 1000));
    final latest = (await tester.runAsync(() => repo.watchSnapshots(sv).first))!.first;
    final ed = SaveEditor.open((await tester.runAsync(() => repo.snapshotBytes(latest)))!);
    // Un Meowscarada con datos de combate para la calculadora y la tarjeta.
    final lead = ed.party.first.clone()
      ..setIvs([31, 31, 28, 30, 31, 31])
      ..setEvs([4, 252, 0, 0, 0, 252]);
    // Flower Trick, Play Rough, Knock Off, U-turn.
    for (final (i, m) in const [(0, 870), (1, 583), (2, 282), (3, 369)]) {
      lead.setMove(i, m, context: GameDataTable.forGame(GameVersion.scarletViolet).context);
    }
    lead.refreshPartyStats();
    unawaited(PokemonEditorScreen.open(appContext(), game: GameVersion.scarletViolet, pk: lead, slotLabel: 'Party 1'));
    await settle(15);
    final calc = find.byKey(const ValueKey('calc-infer'));
    await until(calc);
    final panel = tester.element(find.byType(StatCalculatorPanel));
    await tester.runAsync(() => Scrollable.ensureVisible(panel, alignment: 0.05));
    await settle(10);
    await write('09_stat_calculator');
    Navigator.of(appContext(), rootNavigator: true).pop();
    await settle(10);

    await until(find.byKey(const ValueKey('tool-showdown-export')));
    await tester.tap(find.byKey(const ValueKey('tool-showdown-export')));
    await settle(10);
    await write('10_showdown');
    Navigator.of(appContext(), rootNavigator: true).pop();
    await settle(6);

    unawaited(showShareCard(appContext(), lead, GameVersion.scarletViolet));
    await settle(20);
    await write('11_share_card');

    // 12. Ajustes: clones de HOME y aviso de no afiliación.
    await open('/ajustes', const Size(1440, 1950));
    final clones = find.byKey(const ValueKey('ark-clones-check'));
    await until(clones);
    await tester.ensureVisible(clones);
    await tester.tap(clones);
    await settle(20);
    await write('12_settings_clones_about');

    tester.platformDispatcher.clearLocalesTestValue();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
