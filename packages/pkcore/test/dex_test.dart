import 'dart:io';
import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

/// Atajo: la Dex de varias partidas.
GlobalDex _dex(List<Uint8List> saves) => GlobalDex.build([
      for (final (i, b) in saves.indexed)
        () {
          final scan = SaveDexScan.scan(b);
          return DexSource(id: i + 1, game: scan.game, trainer: 'T$i', scan: scan);
        }(),
    ]);

SpecialUnlock _unlock(GlobalDex dex, String key) {
  final f = SpecialForms.byKey(key)!;
  return dex[f.species].specials.firstWhere((u) => u.form.key == key);
}

/// Añade [item] al primer bolsillo que lo admita.
Uint8List _withItem(Uint8List save, int item) {
  final e = SaveEditor.open(save);
  final pouches = e.readInventory()!;
  final i = pouches.indexWhere((p) => p.legalItems.contains(item));
  expect(i, isNonNegative, reason: 'algún bolsillo admite el objeto $item');
  final p = pouches[i];
  pouches[i] = InventoryPouch(
      type: p.type, capacity: p.capacity, maxCount: p.maxCount, legalItems: p.legalItems, items: [...p.items, InventoryItem(item, 1)]);
  e.writeInventory(pouches);
  return e.build();
}

void main() {
  group('Tabla de formas especiales (oráculo PKHeX)', () {
    // tipo,juego,especie,forma,objeto — generado por tool/gen_dex_tables.sh.
    final rows = [
      for (final l in File('test/data/special_forms_oracle.csv').readAsLinesSync())
        if (l.isNotEmpty && !l.startsWith('#')) l.split(','),
    ];
    GameVersion game(String code) => GameVersion.fromCode(code)!;

    test('Megas, Primigenio y Ultra: mismas formas, juegos y objeto que PKHeX', () {
      final expected = <String, (Set<GameVersion>, int)>{};
      for (final r in rows.where((r) => r[0] != 'gmax')) {
        final kind = r[0] == 'ultra' ? 'ultraBurst' : r[0];
        final key = '$kind:${r[2]}:${r[3]}';
        final e = expected.putIfAbsent(key, () => (<GameVersion>{}, int.parse(r[4])));
        e.$1.add(game(r[1]));
      }
      final table = {for (final f in SpecialForms.all) if (f.kind != SpecialFormKind.gigantamax) f.key: f};
      expect(table.keys.toSet(), expected.keys.toSet());
      for (final MapEntry(:key, :value) in expected.entries) {
        expect(table[key]!.games, value.$1, reason: '$key: juegos');
        // Ultra Necrozma no tiene «piedra» en PKHeX; la tabla lleva el Ultranecrostal Z.
        // Mega Meowstic ♀ (forma 3) usa la misma Meowsticita que la ♂ (PKHeX solo mapea la forma 2).
        if (key == 'ultraBurst:800:3' || key == 'mega:678:3') continue;
        expect(table[key]!.item, value.$2, reason: '$key: objeto');
      }
      expect(SpecialForms.byKey('ultraBurst:800:3')!.item, 923);
      expect(SpecialForms.byKey('mega:678:3')!.item, SpecialForms.byKey('mega:678:2')!.item);
    });

    test('Gigamax: especies y formas de PKHeX Gigantamax.CanToggle en Espada/Escudo', () {
      final oracle = {for (final r in rows.where((r) => r[0] == 'gmax')) (int.parse(r[2]), int.parse(r[3]))};
      final table = <(int, int)>{};
      for (final f in SpecialForms.all.where((f) => f.kind == SpecialFormKind.gigantamax)) {
        for (final form in SpeciesForms.presentForms(f.species, GameVersion.swordShield)) {
          if (f.baseForms == null || f.baseForms!.contains(form)) table.add((f.species, form));
        }
      }
      // Melmetal no puede tomar la Maxisopa (no está en CanToggle), pero llega
      // con el factor Gigamax desde GO/HOME: su Gigamax existe en Espada/Escudo.
      expect(table.difference(oracle), {(809, 0)});
      expect(oracle.difference(table), isEmpty);
    });

    test('Eternamax no se desbloquea y las formas especiales no son coleccionables', () {
      expect(SpecialForms.of(890), isEmpty);
      expect(DexForms.collectable(890), [0]);
      expect(DexForms.collectable(6), [0], reason: 'Mega Charizard X/Y no son formas de caja');
      expect(DexForms.collectable(38), [0, 1], reason: 'Ninetales y Ninetales de Alola');
      expect(DexForms.collectable(479), [0, 1, 2, 3, 4, 5]);
      expect(DexForms.collectable(20), [0, 1], reason: 'sin la forma Dominante');
    });
  });

  group('Reglas de desbloqueo', () {
    test('Gigamax: factor en Espada/Escudo, normal y variocolor por separado', () {
      final dex = _dex([
        SyntheticSaves.swordShield(party: const [
          SynthMon(6, level: 50, shiny: true, gigantamax: true), // Charizard ✦ con factor
          SynthMon(9, level: 50), // Blastoise sin factor
          SynthMon(849, level: 40, form: 1, gigantamax: true), // Toxtricity Grave
          SynthMon(52, level: 20, form: 2, gigantamax: true), // Meowth de Galar: sin Gigamax
        ]),
      ]);
      final zard = _unlock(dex, 'gmax:6:*');
      expect(zard.shinyUnlocked, isTrue);
      expect(zard.normalUnlocked, isFalse, reason: 'solo hay uno variocolor');
      expect(_unlock(dex, 'gmax:9:*').unlockedCount, 0, reason: 'sin factor Gigamax');
      expect(_unlock(dex, 'gmax:849:1').normalUnlocked, isTrue);
      expect(_unlock(dex, 'gmax:849:0').normalUnlocked, isFalse, reason: 'Toxtricity Aguda es otra Gigamax');
      expect(_unlock(dex, 'gmax:52:0').normalUnlocked, isFalse, reason: 'Meowth solo en forma 0');
      // Uno normal en otra partida desbloquea también la normal.
      final both = _dex([
        SyntheticSaves.swordShield(party: const [SynthMon(6, level: 50, shiny: true, gigantamax: true)]),
        SyntheticSaves.swordShield(
            trainer: const SynthTrainer(name: 'Hop', tid: 2, sid: 3), party: const [SynthMon(6, level: 50, gigantamax: true)]),
      ]);
      expect(_unlock(both, 'gmax:6:*').unlockedCount, 2);
      expect(_unlock(both, 'gmax:6:*').normal.single.source, 1);
    });

    test('El factor Gigamax se lee del PK8 (bit 4 de 0x16) y no existe fuera de Espada/Escudo', () {
      final e = SaveEditor.open(SyntheticSaves.swordShield(party: const [SynthMon(6, gigantamax: true), SynthMon(6)]));
      expect(e.party[0].canGigantamax, isTrue);
      expect(e.party[1].canGigantamax, isFalse);
      final sv = _dex([SyntheticSaves.scarletViolet(party: const [SynthMon(6, level: 50)])]);
      expect(_unlock(sv, 'gmax:6:*').unlockedCount, 0);
      expect(_unlock(sv, 'mega:6:1').unlockedCount, 0, reason: 'Escarlata/Púrpura no tiene Megas');
    });

    test('Mega: ejemplar en un juego con esa Mega; piedra en el inventario como indicador', () {
      final xy = _withItem(SyntheticSaves.ctr(layout: CtrLayout.xy, party: const [SynthMon(6, level: 50)]), 660);
      final dex = _dex([xy]);
      final x = _unlock(dex, 'mega:6:1'), y = _unlock(dex, 'mega:6:2');
      expect(x.normalUnlocked && y.normalUnlocked, isTrue);
      expect(x.shinyUnlocked, isFalse);
      expect(x.withItem, {0}, reason: 'Charizardita X en la mochila');
      expect(y.withItem, isEmpty, reason: 'sin Charizardita Y');
      // ROZA: Mega Beedrill sí; X/Y no la tiene.
      final b = _dex([
        SyntheticSaves.ctr(layout: CtrLayout.xy, party: const [SynthMon(15, level: 30)]),
      ]);
      expect(_unlock(b, 'mega:15:1').unlockedCount, 0, reason: 'Mega Beedrill no existe en X/Y');
      final b2 = _dex([SyntheticSaves.ctr(party: const [SynthMon(15, level: 30, shiny: true)])]);
      expect(_unlock(b2, 'mega:15:1').shinyUnlocked, isTrue);
      // Let's Go: solo las de Kanto.
      final lg = _dex([SyntheticSaves.letsGo(party: const [SynthMon(6, level: 50), SynthMon(9, level: 40)])]);
      expect(_unlock(lg, 'mega:6:1').normalUnlocked, isTrue);
      expect(_unlock(lg, 'mega:9:1').normalUnlocked, isTrue);
      // Espada/Escudo no tiene Megas.
      final swsh = _dex([SyntheticSaves.swordShield(party: const [SynthMon(6, level: 50)])]);
      expect(_unlock(swsh, 'mega:6:1').unlockedCount, 0);
    });

    test('Mega de Leyendas Z-A (nuevas y Mega Dimensión)', () {
      final za = _dex([
        SyntheticSaves.legendsZA(party: const [
          SynthMon(36, level: 40), // Clefable → Mega Clefable
          SynthMon(26, level: 40), // Raichu de Kanto → Mega Raichu X/Y
          SynthMon(26, level: 40, form: 1), // Raichu de Alola: no
        ]),
      ]);
      expect(_unlock(za, 'mega:36:1').normalUnlocked, isTrue);
      expect(_unlock(za, 'mega:26:2').normal.length, 1, reason: 'solo el de Kanto');
      expect(_unlock(za, 'mega:26:3').normalUnlocked, isTrue);
      final sv = _dex([SyntheticSaves.scarletViolet(party: const [SynthMon(36, level: 40)])]);
      expect(_unlock(sv, 'mega:36:1').unlockedCount, 0, reason: 'Mega Clefable solo existe en Z-A');
    });

    test('Primigenio en ROZA y Ultra Necrozma solo fusionado en USUL', () {
      final oras = _dex([_withItem(SyntheticSaves.ctr(party: const [SynthMon(382, level: 70)]), 535)]);
      expect(_unlock(oras, 'primal:382:1').normalUnlocked, isTrue);
      expect(_unlock(oras, 'primal:382:1').withItem, {0}, reason: 'Prisma Azul');
      final xy = _dex([SyntheticSaves.ctr(layout: CtrLayout.xy, party: const [SynthMon(382, level: 70)])]);
      expect(_unlock(xy, 'primal:382:1').unlockedCount, 0, reason: 'X/Y no tiene Regresión Primigenia');
      final usum = _dex([
        SyntheticSaves.ctr(layout: CtrLayout.usum, party: const [SynthMon(800, level: 70), SynthMon(800, level: 70, form: 2, shiny: true)]),
      ]);
      final ultra = _unlock(usum, 'ultraBurst:800:3');
      expect(ultra.normalUnlocked, isFalse, reason: 'Necrozma sin fusionar');
      expect(ultra.shinyUnlocked, isTrue, reason: 'Alas del Alba variocolor');
    });

    test('Los huevos no desbloquean nada ni cuentan como capturados', () {
      final dex = _dex([SyntheticSaves.ctr(layout: CtrLayout.xy, party: const [SynthMon(6, egg: true)])]);
      expect(_unlock(dex, 'mega:6:1').unlockedCount, 0);
      expect(dex[6].owned, isFalse);
      expect(dex[6].status, DexStatus.seen);
    });
  });

  group('Cruce de partidas', () {
    test('vistos y capturados de varias Pokédex, ejemplares y variocolor', () {
      final a = SaveEditor.open(SyntheticSaves.swordShield(party: const [SynthMon(25, level: 10)]));
      a.pokedex!
        ..setSeen(810, true)
        ..setSeen(813, true)
        ..setCaught(813, true);
      final b = SaveEditor.open(SyntheticSaves.ctr(layout: CtrLayout.xy, party: const [SynthMon(133, level: 5, shiny: true)]));
      b.pokedex!.setSeen(4, true);
      final dex = _dex([a.build(), b.build()]);
      expect(dex[810].status, DexStatus.seen);
      expect(dex[810].seenIn, {0});
      expect(dex[4].seenIn, {1});
      expect(dex[813].status, DexStatus.caught);
      expect(dex[813].owned, isFalse, reason: 'registrado pero sin ejemplar');
      expect(dex[813].livingStatus, DexStatus.seen);
      expect(dex[25].status, DexStatus.caught, reason: 'ejemplar en el equipo');
      expect(dex[133].shinyOwned, isTrue);
      expect(dex[133].specimens.single.source, 1);
      expect(dex[1].status, DexStatus.unknown);
      final p = dex.progress;
      expect(p.total, 1025);
      expect(p.caught, 3);
      expect(p.seen, 5);
      expect(p.shiny, 1);
      expect(p.owned, 2);
      final games = dex.byGame;
      expect(games.map((g) => g.game), [GameVersion.xy, GameVersion.swordShield]);
      final swsh = games.last;
      expect(swsh.caught, 2); // Pikachu y Gossifleur
      expect(swsh.seen, 3);
      expect(swsh.available, greaterThan(300));
      expect(dex.statusIn(810, GameVersion.xy), DexStatus.unknown, reason: 'Grookey no existe en X/Y');
    });

    test('formas: regionales con ejemplar cuentan como desbloqueadas', () {
      final dex = _dex([
        SyntheticSaves.swordShield(party: const [SynthMon(52, level: 20, form: 2), SynthMon(52, level: 20, form: 1)]),
      ]);
      expect(dex[52].formsOwned, {1, 2});
      expect(dex[52].altFormsOwned, 2);
      expect(dex[52].lockedForms, 2, reason: 'Gigamax normal y variocolor siguen bloqueadas');
    });

    test('la caché se lee igual que el escaneo (encode/decode)', () {
      final e = SaveEditor.open(SyntheticSaves.swordShield(
          party: const [SynthMon(6, level: 50, shiny: true, gigantamax: true, nickname: 'Dragón')],
          boxes: {2: const [null, SynthMon(25, level: 7)]}));
      for (var s = 1; s <= 30; s++) {
        e.pokedex!.setSeen(810 + s % 20, true);
      }
      final scan = SaveDexScan.scan(e.build(), versionId: 44);
      final back = SaveDexScan.decode(scan.encode())!;
      expect(back.game, GameVersion.swordShield);
      expect(back.versionId, 44);
      expect(back.seen, scan.seen);
      expect(back.caught, scan.caught);
      expect(back.specimens.map((s) => s.toString()), scan.specimens.map((s) => s.toString()));
      expect(back.specimens.first.nickname, 'Dragón');
      expect(back.specimens.last.box, 2);
      expect(back.specimens.last.slot, 1);
      expect(SaveDexScan.decode('{"v":0}'), isNull, reason: 'otra versión de caché');
      expect(SaveDexScan.decode('basura'), isNull);
    });

    test('partidas sin Pokédex legible: cuentan sus ejemplares', () {
      final dex = _dex([SyntheticSaves.gen1(party: const [SynthMon(6, level: 50)])]);
      expect(dex[6].status, DexStatus.caught);
    });
  });

  group('Filtros y búsqueda', () {
    late GlobalDex dex;
    setUpAll(() {
      final e = SaveEditor.open(SyntheticSaves.swordShield(party: const [
        SynthMon(6, level: 50, shiny: true, gigantamax: true),
        SynthMon(25, level: 10),
      ]));
      e.pokedex!.setSeen(810, true);
      dex = _dex([e.build(), SyntheticSaves.ctr(layout: CtrLayout.xy, party: const [SynthMon(150, level: 70)])]);
    });

    test('estado', () {
      expect(dex.filter(const DexFilter(status: DexStatusFilter.caught)), [6, 25, 150]);
      expect(dex.filter(const DexFilter(status: DexStatusFilter.seenOnly)), [810]);
      expect(dex.filter(const DexFilter(status: DexStatusFilter.missing)).length, 1022);
      expect(dex.filter(const DexFilter(shinyOnly: true)), [6]);
    });

    test('tipo, generación, juego y formas por desbloquear', () {
      final fire = dex.filter(const DexFilter(type: PokemonType.fire, generation: 1));
      expect(fire, containsAll([4, 5, 6, 37, 38, 58, 59]));
      expect(fire, isNot(contains(37 + 1000)));
      expect(dex.filter(const DexFilter(type: PokemonType.ice, generation: 1)), contains(38),
          reason: 'Ninetales de Alola es de tipo Hielo');
      expect(dex.filter(const DexFilter(generation: 9)).length, 120);
      final swsh = dex.filter(const DexFilter(game: GameVersion.swordShield, status: DexStatusFilter.caught));
      expect(swsh, [6, 25], reason: 'Mewtwo está capturado solo en X/Y');
      final locked = dex.filter(const DexFilter(lockedForms: true, status: DexStatusFilter.caught));
      expect(locked, containsAll([6, 25, 150]), reason: 'Megas de Charizard/Mewtwo sin desbloquear');
    });

    test('búsqueda por nombre (es/en, sin acentos) y número; orden por nombre', () {
      expect(dex.filter(const DexFilter(query: 'pikach')), [25]);
      expect(dex.filter(const DexFilter(query: 'flabebe')), [669], reason: 'Flabébé sin acento');
      expect(dex.filter(const DexFilter(query: '#150')), [150]);
      expect(dex.filter(const DexFilter(query: '15')).first, 15);
      final byName = dex.filter(const DexFilter(generation: 1, sort: DexSort.name), lang: DataLanguage.en);
      expect(byName.first, 63, reason: 'Abra');
    });

    test('living dex: solo cuenta lo que hay en cajas o equipo', () {
      final e = SaveEditor.open(SyntheticSaves.swordShield(party: const [SynthMon(25, level: 10)]));
      e.pokedex!.setCaught(813, true);
      final d = _dex([e.build()]);
      expect(d.filter(const DexFilter(status: DexStatusFilter.caught)), [25, 813]);
      expect(d.filter(const DexFilter(status: DexStatusFilter.caught, living: true)), [25]);
      expect(d.filter(const DexFilter(status: DexStatusFilter.missing, living: true)), contains(813));
    });
  });

  group('Evoluciones (PKHeX)', () {
    test('familias y métodos', () {
      final eevee = Evolutions.family(197, 0);
      expect({for (final s in eevee) s.to}, {134, 135, 136, 196, 197, 470, 471, 700});
      final umbreon = eevee.firstWhere((s) => s.to == 197);
      expect(umbreon.kind, EvolutionKind.friendshipNight);
      final vap = eevee.firstWhere((s) => s.to == 134);
      expect(vap.kind, EvolutionKind.item);
      expect(vap.argument, 84, reason: 'Piedra Agua');
      final zard = Evolutions.family(6, 0);
      expect([for (final s in zard) (s.species, s.to, s.level)], [(4, 5, 16), (5, 6, 36)]);
      expect(Evolutions.root(6, 0), (4, 0));
      expect(Evolutions.root(26, 1), (172, 0), reason: 'Raichu de Alola ← Pikachu ← Pichu');
      expect(Evolutions.family(132, 0), isEmpty, reason: 'Ditto no evoluciona');
      final meowth = Evolutions.from(52, 2);
      expect(meowth.single.to, 863, reason: 'Meowth de Galar → Perrserker');
    });
  });

  test('rendimiento: 50 partidas sintéticas y 1025 entradas', () {
    final saves = <Uint8List>[];
    for (var i = 0; i < 50; i++) {
      final mons = [for (var s = 0; s < 30; s++) SynthMon(1 + (i * 37 + s * 13) % 898, level: 5 + s, shiny: s == 3)];
      saves.add(SyntheticSaves.swordShield(
        trainer: SynthTrainer(name: 'T$i', tid: i + 1, sid: i + 2),
        party: mons.take(6).toList(),
        boxes: {for (var b = 0; b < 4; b++) b: mons},
      ));
    }
    final scanWatch = Stopwatch()..start();
    final json = [for (final b in saves) SaveDexScan.scan(b).encode()];
    scanWatch.stop();
    final buildWatch = Stopwatch()..start();
    final dex = GlobalDex.build([
      for (final (i, j) in json.indexed)
        DexSource(id: i, game: GameVersion.swordShield, trainer: 'T$i', scan: SaveDexScan.decode(j)!),
    ]);
    final p = dex.progress;
    final g = dex.byGeneration;
    final filtered = dex.filter(const DexFilter(status: DexStatusFilter.missing, type: PokemonType.water));
    buildWatch.stop();
    // ignore: avoid_print
    print('Dex: escaneo de 50 partidas ${scanWatch.elapsedMilliseconds} ms (una vez por copia, en segundo plano); '
        'decodificar caché + construir + progreso + filtro ${buildWatch.elapsedMilliseconds} ms');
    expect(p.total, 1025);
    expect(p.caught, greaterThan(100));
    expect(g.length, 9);
    expect(filtered, isNotEmpty);
    expect(dex[6].specimens.length, lessThan(2000));
    expect(buildWatch.elapsedMilliseconds, lessThan(1500), reason: 'la pestaña abre al instante desde la caché');
  });
}
