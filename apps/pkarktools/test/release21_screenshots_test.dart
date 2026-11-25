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
import 'package:pkarktools/data/team_store.dart';
import 'package:pkarktools/providers.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';

import 'arca_folder_test.dart' show memoryDb;
import 'shots_i18n.dart';

/// Capturas de escritorio de la 2.1 (`<SHOTS_OUT>/v2.1/*.png`): pestaña
/// Competitivo y marca de Pokémon oscuro, con datos sintéticos, offscreen:
///
///   flutter test test/release21_screenshots_test.dart --dart-define=SHOTS_V21=true \
///     [--dart-define=SHOTS_LANG=es] [--dart-define=SHOTS_OUT=<carpeta>]
///
/// Sin la define se omite (el CI no reescribe capturas).
const _enabled = bool.fromEnvironment('SHOTS_V21');

Future<void> _loadFonts() async {
  final flutterRoot = io.Platform.environment['FLUTTER_ROOT'];
  for (final (family, file) in [
    ('Manrope', 'assets/fonts/Manrope.ttf'),
    ('Bricolage', 'assets/fonts/BricolageGrotesque.ttf'),
    ('NotoSansSymbols', 'assets/fonts/NotoSansSymbols-Subset.ttf'),
    ('NotoSansSymbols2', 'assets/fonts/NotoSansSymbols2-Subset.ttf'),
    if (flutterRoot != null)
      ('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'),
  ]) {
    final f = File(file);
    if (f.existsSync()) {
      await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
    }
  }
}

ChampionsBuild _set(String text) => ChampionsBuild.fromShowdown(Showdown.parse(text).single)!.build;

void main() {
  testWidgets('capturas de la 2.1', skip: !_enabled, timeout: const Timeout(Duration(minutes: 10)), (tester) async {
    await _loadFonts();
    HttpOverrides.global = null;
    final cacheDir = Directory('../../.scratch/sprite-cache')..createSync(recursive: true);
    SpriteCache.instance = SpriteCache(directory: () async => cacheDir);
    addTearDown(tester.view.reset);
    final tmp = Directory('../../.scratch/tmp/release21-shots-$shotsLang');
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    tmp.createSync(recursive: true);
    final repo = ArcaRepository(memoryDb(), ArcaFolder(IoFolderFs(tmp)));
    final xd = await tester.runAsync(
      () => repo.importBytes(
        SyntheticSaves.xd(
          party: const [
            SynthGcMon(133, level: 25, nickname: 'EON'),
            SynthGcMon(37, level: 20, shadow: 1),
            SynthGcMon(216, level: 15, shadow: 2),
            SynthGcMon(363, level: 18, shadow: 1, gauge: 300),
          ],
          boxes: const {
            0: [
              SynthGcMon(27, level: 23),
              SynthGcMon(179, level: 18, shadow: 1),
              SynthGcMon(296, level: 18, shadow: 2),
            ],
          },
        ),
        fileName: 'xd.gci',
        origin: ImportOrigin.demo,
      ),
    );
    final xdSlot = (await tester.runAsync(() => repo.snapshot((xd! as ImportAdded).snapshotId)))!.slotId;
    final store = TeamStore(repo.folder);
    await tester.runAsync(
      () => store.save(
        ChampionsTeam(
          name: shotsSpanish ? 'Lluvia' : 'Rain',
          members: [
            _set(
              'Pelipper @ Damp Rock\nAbility: Drizzle\nEVs: 32 HP / 32 SpA / 2 SpD\nModest Nature\n- Hurricane\n- Weather Ball',
            ),
            _set(
              'Archaludon @ Life Orb\nAbility: Stamina\nEVs: 32 SpA / 32 Spe / 2 HP\nModest Nature\n- Electro Shot\n- Flash Cannon',
            ),
            _set(
              'Garchomp @ Choice Scarf\nAbility: Rough Skin\nEVs: 2 HP / 32 Atk / 32 Spe\nJolly Nature\n- Earthquake\n- Dragon Claw',
            ),
            _set(
              'Incineroar @ Sitrus Berry\nAbility: Intimidate\nEVs: 32 HP / 32 SpD / 2 Spe\nCareful Nature\n- Fake Out\n- Flare Blitz',
            ),
          ],
        ),
      ),
    );
    await tester.runAsync(
      () => store.save(
        ChampionsTeam(
          name: shotsSpanish ? 'Sol' : 'Sun',
          members: [
            _set('Charizard @ Charizardite Y\nAbility: Blaze\nEVs: 32 SpA / 32 Spe / 2 HP\nTimid Nature\n- Heat Wave'),
            _set(
              'Venusaur @ Life Orb\nAbility: Chlorophyll\nEVs: 32 SpA / 32 Spe / 2 HP\nModest Nature\n- Sludge Bomb',
            ),
          ],
        ),
      ),
    );

    Future<void> settle([int frames = 25]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 100));
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
      shotFile('v2.1/$name').writeAsBytesSync(png!.buffer.asUint8List());
    }

    Future<void> open(String at, Size size) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.localesTestValue = [shotsLocale];
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ProviderScope(
            key: UniqueKey(),
            overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
            child: PKArkToolsApp(initialLocation: at),
          ),
        ),
      );
      await settle();
    }

    const desktop = Size(1440, 900);
    await open('/competitivo', desktop);
    await write('01_competitive');
    await open('/competitivo/formato', desktop);
    await write('02_official_format');
    await open('/competitivo/estadisticas', desktop);
    await write('03_champions_stats');
    await open('/competitivo/danio', const Size(1440, 1300));
    await write('04_damage_calculator');
    await open('/competitivo/equipos', desktop);
    await write('05_my_teams');
    await open('/arca/save/$xdSlot', const Size(1440, 1500));
    await write('06_shadow_mark');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
