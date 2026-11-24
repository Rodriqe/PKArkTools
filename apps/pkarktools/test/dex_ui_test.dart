// Dex global: pestaña, ficha con formas especiales (bloqueadas y
// desbloqueadas, normal y variocolor por separado), progreso, filtros, living
// dex, salto al Pokémon en su caja y diseño sin desbordes en teléfono y
// escritorio. Además, el índice real: importar partidas → escaneo cacheado →
// Dex.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/sprites/sprites.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/providers.dart';
import 'package:pkarktools/ui/common/sprite_image.dart';
import 'package:pkarktools/ui/dex/dex_tile.dart';
import 'package:pkarktools/ui/shell.dart';

import 'arca_folder_test.dart' show memoryDb;
import 'arca_screen_test.dart' show settle;
import 'phone_layout_test.dart' show loadAppFonts;

/// Dex de prueba: Espada/Escudo (Charizard variocolor con factor Gigamax en
/// la caja 1), X/Y (Charizard normal con Charizardita X equipada, sin factor)
/// y Leyendas Z-A (Clefable variocolor).
GlobalDex sampleDex() {
  final swsh = SaveDexScan(
    game: GameVersion.swordShield,
    hasPokedex: true,
    seen: {for (var s = 810; s <= 830; s++) s, 6},
    caught: {810, 813, 6},
    specimens: const [
      DexSpecimen(species: 25, level: 12, box: -1, slot: 0),
      DexSpecimen(species: 6, level: 50, shiny: true, gigantamax: true, box: 0, slot: 3, nickname: 'Blaze'),
      DexSpecimen(species: 52, form: 2, level: 20, box: 1, slot: 0),
    ],
  );
  final xy = SaveDexScan(
    game: GameVersion.xy,
    hasPokedex: true,
    seen: {for (var s = 1; s <= 151; s++) s},
    caught: {for (var s = 1; s <= 40; s++) s},
    specimens: const [DexSpecimen(species: 6, level: 36, box: -1, slot: 0, heldItem: 660)],
    items: const {660},
  );
  final za = SaveDexScan(
    game: GameVersion.legendsZA,
    hasPokedex: true,
    seen: const {35, 36},
    caught: const {36},
    specimens: const [DexSpecimen(species: 36, level: 40, shiny: true, box: 2, slot: 5)],
  );
  return GlobalDex.build([
    DexSource(id: 11, game: GameVersion.swordShield, versionId: 44, trainer: 'Leon', scan: swsh),
    DexSource(id: 12, game: GameVersion.xy, versionId: 24, trainer: 'Serena', scan: xy),
    DexSource(id: 13, game: GameVersion.legendsZA, trainer: 'Urbain', scan: za),
  ]);
}

const sizes = {
  'iPhone SE 320×568': Size(320, 568),
  'Android 360×800': Size(360, 800),
  'iPhone Pro Max 430×932': Size(430, 932),
  'Escritorio 1440×900': Size(1440, 900),
};

void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late ArcaRepository repo;

  setUpAll(loadAppFonts);

  setUp(() async {
    db = memoryDb();
    tmp = await Directory.systemTemp.createTemp('dex_ui');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> pumpDex(WidgetTester t, String at, {Size size = const Size(1440, 900), String lang = 'en', GlobalDex? dex}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.localesTestValue = [Locale(lang)];
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final d = dex ?? sampleDex();
    await t.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        arcaRepositoryProvider.overrideWithValue(repo),
        globalDexProvider.overrideWith((ref) async => d),
      ],
      child: PKArkToolsApp(initialLocation: at),
    ));
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
    await settle(t);
  }

  String location(WidgetTester t) =>
      GoRouter.of(t.element(find.byType(AppShell))).routerDelegate.currentConfiguration.uri.toString();

  testWidgets('la pestaña Dex está en la navegación y muestra progreso y cuadrícula', (t) async {
    await pumpDex(t, '/arca');
    await t.tap(find.text('Dex').first);
    await settle(t);
    expect(location(t), '/dex');
    // 40 de X/Y + Pikachu, Grookey, Gossifleur, Sandshrew… (solo registro: 6 ya cuenta).
    final p = sampleDex().progress;
    expect(find.text('${p.caught} of 1025 caught · 3 saves'), findsOneWidget);
    expect(find.text('1025 species'), findsOneWidget);
    expect(find.byKey(const ValueKey('dex-6')), findsOneWidget);
  });

  testWidgets('filtros: faltantes, variocolor, juego, generación y búsqueda', (t) async {
    await pumpDex(t, '/dex');
    await t.tap(find.byKey(const ValueKey('dex-status-missing')));
    await settle(t);
    final dex = sampleDex();
    expect(find.text('${1025 - dex.progress.caught} species'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('dex-status-all')));
    await t.tap(find.byKey(const ValueKey('dex-shiny')));
    await settle(t);
    expect(find.text('2 species'), findsOneWidget, reason: 'Charizard y Clefable');

    await t.tap(find.byKey(const ValueKey('dex-shiny')));
    await t.enterText(find.byKey(const ValueKey('dex-search')), 'char');
    await settle(t);
    final chars = dex.filter(const DexFilter(query: 'char'));
    expect(chars, containsAll([4, 5, 6]));
    expect(find.text('${chars.length} species'), findsOneWidget);
    expect(find.text('Clear'), findsWidgets);
    await t.tap(find.text('Clear').last);
    await settle(t);
    expect(find.text('1025 species'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('dex-game')));
    await settle(t);
    await t.tap(find.text('Legends: Z-A').last);
    await settle(t);
    expect(find.text('1025 species'), findsNothing, reason: 'solo las especies de Z-A');
  });

  testWidgets('ficha de Charizard: Gigamax variocolor desbloqueada (Espada) y Megas por X/Y con piedra', (t) async {
    await pumpDex(t, '/dex/especie/6');
    expect(find.text('Charizard'), findsWidgets);
    expect(find.text('Fire'), findsWidgets);
    expect(find.text('Flying'), findsWidgets);
    // Gigamax: solo la variocolor (el ejemplar con factor es variocolor).
    expect(find.byKey(const ValueKey('dex-variant-gmax:6:*-shiny-on')), findsOneWidget);
    expect(find.byKey(const ValueKey('dex-variant-gmax:6:*-normal-off')), findsOneWidget);
    // Icono propio de Charizard Gigamax: el variocolor, que es el desbloqueado.
    final gmaxIcon = t.widget<DexIcon>(find.byKey(const ValueKey('dex-special-icon-gmax:6:*-own')));
    expect(gmaxIcon.sprite?.key, 'pokemon_small_shiny/0006-000-Charizard-Gmax');
    final megaIcon = t.widget<DexIcon>(find.byKey(const ValueKey('dex-special-icon-mega:6:1-own')));
    expect(megaIcon.sprite?.key, 'pokemon/scharizard-omega_x');
    // «Tus ejemplares»: el Charizard con factor Gigamax se ve con su icono Gigamax.
    expect(find.byWidgetPredicate((w) => w is DexIcon && w.gigantamax && w.shiny && w.species == 6), findsOneWidget);
    // Mega X e Y: el Charizard normal de X/Y las habilita; variocolor no.
    expect(find.byKey(const ValueKey('dex-variant-mega:6:1-normal-on')), findsOneWidget);
    expect(find.byKey(const ValueKey('dex-variant-mega:6:1-shiny-off')), findsOneWidget);
    expect(find.byKey(const ValueKey('dex-variant-mega:6:2-normal-on')), findsOneWidget);
    // Piedra: la X está en la partida, la Y no (indicador, no requisito).
    expect(find.textContaining('Charizardite X in the bag: Serena'), findsOneWidget);
    expect(find.textContaining('Charizardite Y: not in the bag'), findsOneWidget);
    // Registros y ejemplares.
    expect(find.text('Blaze · Charizard'), findsOneWidget);
    expect(find.text('Leon · Sword / Shield · Box 1, slot 4'), findsOneWidget);
  });

  testWidgets('variocolor y normal desbloqueadas: la tarjeta y la pastilla variocolor usan el icono variocolor', (t) async {
    // El caso del Odin3 (1.0.3): Charizard Gigamax normal Y variocolor; la
    // tarjeta mostraba el icono normal. Más Mega X variocolor por Z-A.
    final dex = GlobalDex.build([
      DexSource(
        id: 21,
        game: GameVersion.swordShield,
        trainer: 'Leon',
        scan: SaveDexScan(game: GameVersion.swordShield, hasPokedex: true, seen: const {6}, caught: const {6}, specimens: const [
          DexSpecimen(species: 6, level: 60, gigantamax: true, box: 0, slot: 0, nickname: 'Plain'),
          DexSpecimen(species: 6, level: 70, shiny: true, gigantamax: true, box: 0, slot: 1, nickname: 'Star'),
        ]),
      ),
      DexSource(
        id: 22,
        game: GameVersion.legendsZA,
        trainer: 'Urbain',
        scan: SaveDexScan(game: GameVersion.legendsZA, hasPokedex: true, seen: const {6}, caught: const {6}, specimens: const [
          DexSpecimen(species: 6, level: 50, box: 1, slot: 0),
          DexSpecimen(species: 6, level: 55, shiny: true, box: 1, slot: 1),
        ]),
      ),
    ]);
    await pumpDex(t, '/dex/especie/6', dex: dex);
    SpriteRef? imageIn(Finder f) => t.widget<SpriteImage>(find.descendant(of: f, matching: find.byType(SpriteImage)).first).sprite;

    for (final (key, normal, shiny) in [
      ('gmax:6:*', 'pokemon_small/0006-000-Charizard-Gmax', 'pokemon_small_shiny/0006-000-Charizard-Gmax'),
      ('mega:6:1', 'pokemon/scharizard-omega_x', 'pokemon_small_shiny/0006-001-Charizard-Mega~X'),
    ]) {
      expect(find.byKey(ValueKey('dex-variant-$key-normal-on')), findsOneWidget);
      expect(find.byKey(ValueKey('dex-variant-$key-shiny-on')), findsOneWidget);
      final card = find.byKey(ValueKey('dex-special-$key'));
      final icon = t.widget<DexIcon>(find.byKey(ValueKey('dex-special-icon-$key-own')));
      expect(icon.sprite?.key, shiny, reason: '$key: tarjeta con la variocolor desbloqueada');
      expect(imageIn(find.byKey(ValueKey('dex-special-icon-$key-own')))?.key, shiny);
      expect(find.descendant(of: card, matching: find.byKey(ValueKey('dex-special-shiny-badge-$key'))), findsOneWidget);
      expect(t.widget<SpriteImage>(find.byKey(ValueKey('dex-variant-icon-$key-normal'))).sprite?.key, normal);
      expect(t.widget<SpriteImage>(find.byKey(ValueKey('dex-variant-icon-$key-shiny'))).sprite?.key, shiny);
    }
    // «Tus ejemplares»: el Gigamax variocolor con su icono variocolor y el normal con el normal.
    expect(imageIn(find.byKey(const ValueKey('dex-specimen-21-0-1')))?.key, 'pokemon_small_shiny/0006-000-Charizard-Gmax');
    expect(imageIn(find.byKey(const ValueKey('dex-specimen-21-0-0')))?.key, 'pokemon_small/0006-000-Charizard-Gmax');
  });

  testWidgets('solo la normal desbloqueada: tarjeta normal, sin insignia ✦; bloqueada: silueta normal', (t) async {
    await pumpDex(t, '/dex/especie/6');
    final mega = t.widget<DexIcon>(find.byKey(const ValueKey('dex-special-icon-mega:6:1-own')));
    expect(mega.sprite?.key, 'pokemon/scharizard-omega_x');
    expect(find.byKey(const ValueKey('dex-special-shiny-badge-mega:6:1')), findsNothing);
    expect(find.byKey(const ValueKey('dex-variant-icon-mega:6:1-shiny')), findsNothing);
    expect(find.byKey(const ValueKey('dex-special-shiny-badge-gmax:6:*')), findsOneWidget);
  });

  testWidgets('formas bloqueadas: silueta y cómo se desbloquean (Venusaur, Necrozma)', (t) async {
    await pumpDex(t, '/dex/especie/3');
    expect(find.byKey(const ValueKey('dex-variant-mega:3:1-normal-off')), findsOneWidget);
    expect(find.byKey(const ValueKey('dex-variant-gmax:3:*-normal-off')), findsOneWidget);
    // Bloqueadas: silueta del icono propio (Venusaur Gigamax de previews/gen9).
    final locked = t.widget<DexIcon>(find.byKey(const ValueKey('dex-special-icon-gmax:3:*-own')));
    expect(locked.sprite?.key, 'pokemon_preview/svenusaur-g');
    expect(locked.status, DexStatus.unknown);
    expect(find.textContaining('Have a Venusaur with the Gigantamax Factor in Sword/Shield.'), findsOneWidget);
    expect(find.textContaining('Have a Venusaur in X / Y'), findsOneWidget);
    expect(find.textContaining('The shiny one needs a shiny specimen'), findsNWidgets(2), reason: 'ningún Venusaur');

    await t.tap(find.byKey(const ValueKey('dex-next')));
    await settle(t);
    expect(location(t), '/dex/especie/4');

    await pumpDex(t, '/dex/especie/800');
    expect(find.textContaining('Have a fused Necrozma'), findsOneWidget);
    expect(find.text('Forms'), findsOneWidget, reason: 'Melena Crepuscular y Alas del Alba son coleccionables');
  });

  testWidgets('un ejemplar salta a su caja en la partida', (t) async {
    await pumpDex(t, '/dex/especie/6');
    final tile = find.byKey(const ValueKey('dex-specimen-11-0-3'));
    await t.dragUntilVisible(tile, find.byType(ListView), const Offset(0, -250));
    await t.pump();
    await t.tap(tile);
    await settle(t);
    expect(location(t), '/arca/save/11?box=0&slot=3');
  });

  testWidgets('progreso: por generación y por juego; tocar una fila filtra', (t) async {
    await pumpDex(t, '/dex/progreso');
    expect(find.text('By generation and region'), findsOneWidget);
    expect(find.text('Gen 1 · Kanto'), findsOneWidget);
    expect(find.byKey(const ValueKey('dex-game-row-xy')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('dex-gen-row-8')));
    await settle(t);
    expect(location(t), '/dex');
    expect(find.text('${GlobalDex.build(const []).filter(const DexFilter(generation: 8)).length} species'), findsOneWidget);
  });

  testWidgets('living dex: el ajuste cuenta solo lo que hay en cajas y se recuerda', (t) async {
    await pumpDex(t, '/dex');
    await t.tap(find.byKey(const ValueKey('dex-settings')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('dex-living')));
    await settle(t);
    await t.tapAt(const Offset(10, 10));
    await settle(t);
    expect(find.text('4 of 1025 in your boxes · 3 saves'), findsOneWidget, reason: 'Pikachu, Charizard, Meowth, Clefable');
    expect(await repo.getSetting('dexLiving'), '1');
  });

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    testWidgets('sin desbordes en $name (cuadrícula, ficha, formas, progreso)', (t) async {
      for (final at in ['/dex', '/dex/especie/6', '/dex/especie/800', '/dex/especie/849', '/dex/progreso']) {
        for (final lang in ['en', 'es']) {
          await pumpDex(t, at, size: size, lang: lang);
          // Recorre la página entera: los desbordes de abajo también cuentan.
          final scroll = find.byType(Scrollable).first;
          for (var i = 0; i < 6; i++) {
            await t.drag(scroll, const Offset(0, -700), warnIfMissed: false);
            await t.pump(const Duration(milliseconds: 50));
          }
          expect(t.takeException(), isNull, reason: '$at ($lang)');
        }
      }
    });
  }

  test('índice real: importar partidas → escaneo cacheado → Dex con Gigamax variocolor', () async {
    await repo.importBytes(
      SyntheticSaves.swordShield(
        trainer: const SynthTrainer(name: 'Leon'),
        party: const [SynthMon(6, level: 50, shiny: true, gigantamax: true)],
        boxes: {0: const [SynthMon(25, level: 5)]},
      ),
      fileName: 'main',
      origin: ImportOrigin.file,
    );
    await repo.importBytes(
      SyntheticSaves.ctr(layout: CtrLayout.xy, party: const [SynthMon(6, level: 36)]),
      fileName: 'xy.sav',
      origin: ImportOrigin.file,
    );
    final entries = await repo.watchArca().first;
    expect(entries, hasLength(2));
    final sw = Stopwatch()..start();
    final dex = await repo.dex.build(entries);
    sw.stop();
    final gmax = dex[6].specials.firstWhere((u) => u.form.kind == SpecialFormKind.gigantamax);
    expect(gmax.shinyUnlocked, isTrue);
    expect(gmax.normalUnlocked, isFalse);
    final megaX = dex[6].specials.firstWhere((u) => u.form.key == 'mega:6:1');
    expect(megaX.normalUnlocked, isTrue);
    expect(dex[25].owned, isTrue);
    // Cacheado en drift: una segunda construcción no vuelve a escanear.
    expect(await db.select(db.dexScans).get(), hasLength(2));
    final again = await repo.dex.build(entries);
    expect(identical(again, dex), isTrue);
    // ignore: avoid_print
    print('Dex desde el Arca (2 partidas, primer escaneo incluido): ${sw.elapsedMilliseconds} ms');
  });
}
