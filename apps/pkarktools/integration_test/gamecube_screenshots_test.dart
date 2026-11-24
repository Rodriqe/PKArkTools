import 'dart:io' as io;

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';
import 'package:pkarktools/data/sprites/sprite_cache.dart';
import 'package:pkarktools/providers.dart';
import 'package:pkarktools/ui/editor/pokemon_editor.dart';

/// Capturas de Colosseum/XD y de los juegos de almacenamiento en un teléfono
/// (emulador -no-window o simulador headless), con saves sintéticos:
///
///   flutter drive -d DISPOSITIVO --driver test_driver/screenshot_driver.dart \
///     --target integration_test/gamecube_screenshots_test.dart --dart-define=SHOTS=android/gc
///     [--dart-define=SHOTS_LANG=es]
const _prefix = String.fromEnvironment('SHOTS', defaultValue: 'gamecube/phone');
const _lang = String.fromEnvironment('SHOTS_LANG', defaultValue: 'en');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capturas de Colosseum/XD y almacenamiento', skip: io.Platform.isMacOS || io.Platform.isWindows || io.Platform.isLinux,
      (tester) async {
    final locale = _lang == 'es' ? const Locale('es', 'ES') : const Locale('en', 'US');
    tester.platformDispatcher.localesTestValue = [locale];
    tester.platformDispatcher.localeTestValue = locale;
    await tester.runAsync(() => SpriteCache.instance.downloadAll());
    final db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final repo = ArcaRepository(db, ArcaFolder(MemoryFolderFs(label: 'PKArkTools')));

    final saves = {
      '01-GXXE-pokemon_xd.gci': SyntheticSaves.gci(SyntheticSaves.xdDemo(), GcTitle.xd),
      'MemoryCardA.USA.raw': SyntheticSaves.memoryCard([(GcTitle.colosseum, SyntheticSaves.colosseumDemo())]),
      'Pokemon Stadium 2 (USA).sra': SyntheticSaves.stadium(
        layout: StadiumLayout.stadium2U,
        trainer: const SynthTrainer(name: 'GOLD', tid: 2000),
        boxes: const {0: [SynthMon(157, level: 55), SynthMon(181, level: 50, shiny: true), SynthMon(249, level: 70), SynthMon(248, level: 60)]},
        boxNames: const ['JOHTO'],
      ),
      '01-GPXE-pokemon_box.gci': SyntheticSaves.gci(
          SyntheticSaves.rsBox(boxes: const {
            0: [SynthMon(254, level: 50), SynthMon(257, level: 50), SynthMon(260, level: 50), null, SynthMon(384, level: 70, shiny: true)],
          }, boxNames: const ['HOENN']),
          GcTitle.rsBox),
      'PbrSaveData': SyntheticSaves.battleRevolution(
        owner: 'Lucas',
        party: const [SynthMon(448, level: 60, nickname: 'Luca'), SynthMon(445, level: 62)],
        boxes: const {0: [SynthMon(25, level: 30), SynthMon(393, level: 20)]},
      ),
      'pokemonranch.bin': SyntheticSaves.ranch(
          owner: 'Hayley', mons: const [SynthMon(25, level: 10), SynthMon(54, level: 12), SynthMon(133, level: 15)]),
    };
    final ids = <String, int>{};
    for (final e in saves.entries) {
      final r = await tester.runAsync(() => repo.importBytes(e.value, fileName: e.key, origin: ImportOrigin.file));
      if (r is ImportAdded) ids[e.key] = r.slotId;
    }
    expect(ids.length, saves.length);

    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    var n = 0;
    Future<void> shot(String name) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await settle(8);
      n++;
      await binding.takeScreenshot('${_prefix}_${n.toString().padLeft(2, '0')}_$name');
    }

    Future<void> open(String location) async {
      await tester.pumpWidget(const SizedBox());
      await settle(3);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
        child: PKArkToolsApp(initialLocation: location),
      ));
      await settle(25);
    }

    Future<void> reveal(Finder f, {double alignment = 0.1}) async {
      final editor = find.byType(PokemonEditorScreen);
      final scope = editor.evaluate().isNotEmpty ? editor : find.byType(Scaffold).last;
      final list = find.descendant(of: scope, matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(f, 300, scrollable: list, maxScrolls: 80);
      await settle(5);
      await Scrollable.ensureVisible(tester.element(f), alignment: alignment);
      await settle(10);
    }

    Future<void> tapMon(String species) async {
      final mon = find.bySemanticsLabel(RegExp(species)).first;
      await Scrollable.ensureVisible(tester.element(mon), alignment: 0.5);
      await settle(8);
      await tester.tap(mon);
      await settle(25);
    }

    if (io.Platform.isAndroid) await binding.convertFlutterSurfaceToImage();

    await open('/arca');
    await shot('arca');
    await open('/arca/save/${ids['01-GXXE-pokemon_xd.gci']!}');
    await shot('xd_save');
    await tapMon('Vulpix');
    await reveal(find.byKey(const ValueKey('shadow-state')), alignment: 0.05);
    await shot('xd_shadow_pokemon');
    await open('/arca/save/${ids['MemoryCardA.USA.raw']!}');
    await shot('colosseum_save');

    await open('/cintas/guia/156');
    final specimen = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('rm-specimen-'));
    await reveal(specimen.first, alignment: 0.05);
    await tester.tap(specimen.first);
    await settle(15);
    await shot('ribbon_hunter_purified');

    for (final (file, name) in const [
      ('Pokemon Stadium 2 (USA).sra', 'stadium2'),
      ('01-GPXE-pokemon_box.gci', 'box_ruby_sapphire'),
      ('PbrSaveData', 'battle_revolution'),
      ('pokemonranch.bin', 'ranch'),
    ]) {
      await open('/arca/save/${ids[file]!}');
      await shot(name);
    }

    await tester.pumpWidget(const SizedBox());
    await settle(5);
    await tester.runAsync(db.close);
  });
}
