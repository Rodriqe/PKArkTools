import 'dart:io' hide Platform;
import 'dart:io' as io show Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';
import 'package:pkarktools/data/sprites/sprite_cache.dart';

import 'shots_i18n.dart';

/// Capturas de los juegos de almacenamiento (Stadium, Stadium 2, Box Rubí y
/// Zafiro, Battle Revolution y My Pokémon Ranch) con saves sintéticos,
/// renderizadas fuera de pantalla (1440×900 a 2×, sin ventana).
///
///   flutter test test/storage_screenshots_test.dart --dart-define=SHOTS_STORAGE=true
///
/// Escribe `docs/screenshots/storage/NN_nombre.png`.
const _enabled = bool.fromEnvironment('SHOTS_STORAGE');

Future<void> _loadFonts() async {
  final flutterRoot = io.Platform.environment['FLUTTER_ROOT'];
  final fonts = <(String, String)>[
    ('Manrope', 'assets/fonts/Manrope.ttf'),
    ('Bricolage', 'assets/fonts/BricolageGrotesque.ttf'),
    ('NotoSansSymbols', 'assets/fonts/NotoSansSymbols-Subset.ttf'),
    ('NotoSansSymbols2', 'assets/fonts/NotoSansSymbols2-Subset.ttf'),
    if (flutterRoot != null) ('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'),
  ];
  for (final (family, file) in fonts) {
    final f = File(file);
    if (!f.existsSync()) continue;
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
  }
}

void main() {
  testWidgets('capturas de los juegos de almacenamiento offscreen', skip: !_enabled, (tester) async {
    await _loadFonts();
    HttpOverrides.global = null;
    final cacheDir = Directory('../../.scratch/sprite-cache')..createSync(recursive: true);
    SpriteCache.instance = SpriteCache(directory: () async => cacheDir);
    await tester.runAsync(() => SpriteCache.instance.downloadAll());

    tester.view.physicalSize = const Size(1440, 900) * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.localesTestValue = [shotsLocale];
    tester.platformDispatcher.localeTestValue = shotsLocale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    final db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final repo = ArcaRepository(db, ArcaFolder(MemoryFolderFs(label: 'PKArkTools')));
    final ids = <String, int>{};
    final saves = {
      'Pokemon Stadium (USA).fla': SyntheticSaves.stadium(
        trainer: const SynthTrainer(name: 'RED', tid: 1999),
        boxes: const {
          0: [SynthMon(6, level: 50), SynthMon(25, level: 30, nickname: 'SPARKY'), SynthMon(150, level: 70, shiny: true), SynthMon(131, level: 45), SynthMon(143, level: 50)],
          1: [SynthMon(1, level: 5), SynthMon(4, level: 5), SynthMon(7, level: 5)],
        },
        team: const [SynthMon(6, level: 50), SynthMon(9, level: 50)],
      ),
      'Pokemon Stadium 2 (USA).sra': SyntheticSaves.stadium(
        layout: StadiumLayout.stadium2U,
        trainer: const SynthTrainer(name: 'GOLD', tid: 2000),
        boxes: const {0: [SynthMon(157, level: 55), SynthMon(181, level: 50, shiny: true), SynthMon(249, level: 70), SynthMon(248, level: 60)]},
        boxNames: const ['JOHTO'],
      ),
      '01-GPXE-pokemon_box.gci': SyntheticSaves.gci(
          SyntheticSaves.rsBox(boxes: const {
            0: [SynthMon(254, level: 50), SynthMon(257, level: 50), SynthMon(260, level: 50), null, SynthMon(384, level: 70, shiny: true)],
            1: [SynthMon(380, level: 50), SynthMon(381, level: 50)],
          }, boxNames: const ['HOENN']),
          GcTitle.rsBox),
      'PbrSaveData': SyntheticSaves.battleRevolution(
        party: const [SynthMon(448, level: 60, nickname: 'Lucky'), SynthMon(445, level: 62, shiny: true), SynthMon(392, level: 55), SynthMon(487, level: 70)],
        boxes: const {0: [SynthMon(483, level: 70), SynthMon(484, level: 70), SynthMon(493, level: 80)]},
      ),
      'pokemonranch.bin': SyntheticSaves.ranch(
        platinum: true,
        mons: const [SynthMon(25, level: 20), SynthMon(393, level: 5, shiny: true), SynthMon(387, level: 5), SynthMon(390, level: 5), SynthMon(133, level: 15), SynthMon(446, level: 10)],
      ),
    };
    for (final e in saves.entries) {
      final r = await tester.runAsync(() => repo.importBytes(e.value, fileName: e.key, origin: ImportOrigin.file));
      if (r is ImportAdded) ids[e.key] = r.slotId;
    }
    expect(ids.length, 5);

    final boundary = GlobalKey();
    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    var n = 0;
    Future<void> shot(String name) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
      await settle(10);
      n++;
      final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final png = await tester.runAsync(() async {
        final image = await ro.toImage(pixelRatio: 2);
        return image.toByteData(format: ui.ImageByteFormat.png);
      });
      shotFile('storage/${n.toString().padLeft(2, '0')}_$name').writeAsBytesSync(png!.buffer.asUint8List());
    }

    Future<void> open(String location) async {
      await tester.pumpWidget(const SizedBox());
      await settle(3);
      await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: ProviderScope(
          key: UniqueKey(),
          overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
          child: PKArkToolsApp(initialLocation: location),
        ),
      ));
      await settle(25);
    }

    Future<void> tapMon(String species) async {
      final mon = find.bySemanticsLabel(RegExp(species)).first;
      await Scrollable.ensureVisible(tester.element(mon), alignment: 0.5);
      await settle(8);
      await tester.tap(mon);
      await settle(25);
    }

    await open('/arca');
    await shot('arca');
    for (final (file, name) in const [
      ('Pokemon Stadium (USA).fla', 'stadium'),
      ('Pokemon Stadium 2 (USA).sra', 'stadium2'),
      ('01-GPXE-pokemon_box.gci', 'box_ruby_sapphire'),
      ('pokemonranch.bin', 'ranch'),
      ('PbrSaveData', 'battle_revolution'),
    ]) {
      await open('/arca/save/${ids[file]!}');
      await shot(name);
    }
    await tapMon('Lucario');
    await shot('battle_revolution_pokemon');

    await tester.pumpWidget(const SizedBox());
    await settle(5);
    await tester.runAsync(db.close);
  });
}
