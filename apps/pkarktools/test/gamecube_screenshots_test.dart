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
import 'package:pkarktools/ui/editor/pokemon_editor.dart';

import 'shots_i18n.dart';

/// Capturas de Pokémon Colosseum y XD (saves sintéticos), renderizadas fuera
/// de pantalla como `desktop_screenshots_test.dart`: 1440×900 a 2×, fuentes
/// reales, sin ventana.
///
///   flutter test test/gamecube_screenshots_test.dart --dart-define=SHOTS_GC=true
///
/// Escribe `docs/screenshots/gamecube/NN_nombre.png`.
const _enabled = bool.fromEnvironment('SHOTS_GC');

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
  testWidgets('capturas de Colosseum y XD offscreen', skip: !_enabled, (tester) async {
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
      '01-GXXE-pokemon_xd.gci': SyntheticSaves.gci(SyntheticSaves.xdDemo(), GcTitle.xd),
      'MemoryCardA.USA.raw': SyntheticSaves.memoryCard([(GcTitle.colosseum, SyntheticSaves.colosseumDemo())]),
      'Esmeralda.sav': SyntheticSaves.demoSet()['Esmeralda.sav']!,
    };
    const sources = {
      '01-GXXE-pokemon_xd.gci': '/Users/ash/Library/Application Support/Dolphin/GC/USA/Card A/01-GXXE-pokemon_xd.gci',
      'MemoryCardA.USA.raw': '/Users/ash/Library/Application Support/Dolphin/GC/MemoryCardA.USA.raw',
    };
    for (final e in saves.entries) {
      final r = await tester.runAsync(
          () => repo.importBytes(e.value, fileName: e.key, origin: ImportOrigin.file, sourcePath: sources[e.key]));
      if (r is ImportAdded) ids[e.key] = r.slotId;
    }
    expect(ids.length, 3);

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
      shotFile('gamecube/${n.toString().padLeft(2, '0')}_$name').writeAsBytesSync(png!.buffer.asUint8List());
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

    await open('/arca');
    await shot('arca');

    await open('/arca/save/${ids['01-GXXE-pokemon_xd.gci']!}');
    await shot('xd_save');
    await tapMon('Vulpix');
    await reveal(find.byKey(const ValueKey('shadow-state')), alignment: 0.05);
    await shot('xd_shadow_pokemon');

    await open('/arca/save/${ids['MemoryCardA.USA.raw']!}');
    await shot('colosseum_save');
    await tapMon('Quilava');
    await reveal(find.byKey(const ValueKey('shadow-state')), alignment: 0.05);
    await shot('colosseum_purified');

    // Ribbon Hunter: el Quilava purificado aparece en «Tus ejemplares» con su
    // Cinta Nacional ya contada.
    await open('/cintas/guia/156');
    final specimen = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('rm-specimen-'));
    await reveal(specimen.first, alignment: 0.05);
    await tester.tap(specimen.first);
    await settle(15);
    await shot('ribbon_hunter_purified');

    await tester.pumpWidget(const SizedBox());
    await settle(5);
    await tester.runAsync(db.close);
  });
}
