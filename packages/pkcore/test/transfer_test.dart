import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

import 'transfer_cases.dart';

/// Save sintético vacío de [game] (para el round-trip).
Uint8List _blankSave(GameVersion game) => switch (game) {
      GameVersion.redBlue => SyntheticSaves.gen1(party: const [SynthMon(25)]),
      GameVersion.yellow => SyntheticSaves.gen1(yellow: true, party: const [SynthMon(25)]),
      GameVersion.goldSilver => SyntheticSaves.gen2(party: const [SynthMon(25)]),
      GameVersion.crystal => SyntheticSaves.gen2(crystal: true, party: const [SynthMon(25)]),
      GameVersion.rubySapphire ||
      GameVersion.emerald ||
      GameVersion.fireRedLeafGreen =>
        SyntheticSaves.gen3(game: game, party: const [SynthMon(25)]),
      GameVersion.diamondPearl => SyntheticSaves.gen4(layout: Gen4Layout.dp, party: const [SynthMon(25)]),
      GameVersion.platinum => SyntheticSaves.gen4(layout: Gen4Layout.pt, party: const [SynthMon(25)]),
      GameVersion.heartGoldSoulSilver => SyntheticSaves.gen4(layout: Gen4Layout.hgss, party: const [SynthMon(25)]),
      GameVersion.blackWhite => SyntheticSaves.gen5(layout: Gen5Layout.bw, party: const [SynthMon(25)]),
      GameVersion.black2White2 => SyntheticSaves.gen5(layout: Gen5Layout.b2w2, party: const [SynthMon(25)]),
      GameVersion.xy => SyntheticSaves.ctr(layout: CtrLayout.xy, party: const [SynthMon(25)]),
      GameVersion.omegaRubyAlphaSapphire => SyntheticSaves.ctr(layout: CtrLayout.oras, party: const [SynthMon(25)]),
      GameVersion.sunMoon => SyntheticSaves.ctr(layout: CtrLayout.sm, party: const [SynthMon(25)]),
      GameVersion.ultraSunUltraMoon => SyntheticSaves.ctr(layout: CtrLayout.usum, party: const [SynthMon(25)]),
      GameVersion.swordShield => SyntheticSaves.swordShield(party: const [SynthMon(25)]),
      GameVersion.brilliantDiamondShiningPearl => SyntheticSaves.bdsp(party: const [SynthMon(25)]),
      GameVersion.legendsArceus => SyntheticSaves.legendsArceus(party: const [SynthMon(25)]),
      GameVersion.scarletViolet => SyntheticSaves.scarletViolet(party: const [SynthMon(25)]),
      GameVersion.legendsZA => SyntheticSaves.legendsZA(party: const [SynthMon(25)]),
      _ => throw UnsupportedError('$game'),
    };

Pkm _mon(GameVersion game, int species, {int level = 20, bool egg = false, int item = 0, int form = 0}) {
  final ed = SaveEditor.open(_blankSave(game));
  final pk = PkmFactory.create(game, ed.readTrainer(), species: species, level: level, form: form,
      random: Random(1), today: transferDay);
  if (item != 0) pk.heldItem = item;
  if (egg) pk.isEgg = true;
  return pk..refreshChecksum();
}

void main() {
  final fixture = {
    for (final c in (jsonDecode(File('test/data/transfer_oracle.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>())
      c['id'] as String: c,
  };

  group('Oráculo PKHeX: cada salto de generación da un Pokémon legal', () {
    for (final c in transferCases) {
      test('${c.id}: ${c.from.name} → ${c.to.name}', () {
        final f = fixture[c.id];
        expect(f, isNotNull, reason: 'falta en transfer_oracle.json: ejecuta tool/transfer_oracle.sh');
        expect(f!['sourceLegal'], isTrue, reason: 'el origen generado por PKHeX debe ser legal');
        expect(f['oursLegal'], isTrue, reason: 'PKHeX: ${f['oursIssues']}');
        final r = c.convert();
        expect(r.ok, isTrue, reason: '${r.block}');
        final pk = r.pk!;
        final o = f['ours'] as Map<String, dynamic>;
        // El resultado coincide con el que validó PKHeX (mismos datos deterministas).
        expect(pk.species, o['species']);
        expect(pk.form, o['form']);
        expect(pk.level, o['level']);
        expect(pk.moves, o['moves']);
        expect(pk.nickname, o['nickname']);
        expect(pk.otName, o['ot']);
        expect(pk.heldItem, o['heldItem']);
        expect(pk.isShiny, o['shiny']);
        if (!pk.format.isGameBoy) {
          expect(pk.ball, o['ball']);
          expect(pk.metLocation, o['metLocation']);
          expect(pk.metLevel, o['metLevel']);
          expect(pk.version, o['version']);
          expect(pk.isNicknamed, o['isNicknamed']);
          expect(pk.ability, o['ability']);
        }
      });
    }
  });

  group('Round-trip: el Pokémon convertido se guarda en el save de destino', () {
    for (final c in transferCases) {
      test(c.id, () {
        final pk = c.convert().pk!;
        final ed = SaveEditor.open(_blankSave(c.to));
        final slot = ed.firstEmptyBoxSlot()!;
        ed.set(slot, pk);
        final out = ed.buildVerified();
        final back = SaveEditor.open(out).get(slot)!;
        expect(back.species, pk.species);
        expect(back.moves, pk.moves);
        expect(back.nickname, pk.nickname);
        if (!pk.format.isGameBoy) {
          expect(back.data.sublist(0, pk.format.storedSize), pk.data.sublist(0, pk.format.storedSize));
          expect(back.checksumValid, isTrue);
        }
        expect(SaveVerifier.checksums(out), isEmpty);
      });
    }
  });

  group('Reglas de transferencia', () {
    test('solo hacia adelante (salvo entre juegos de Switch)', () {
      final pk7 = _mon(GameVersion.ultraSunUltraMoon, 25);
      expect(PkTransfer.check(pk7, GameVersion.ultraSunUltraMoon, GameVersion.xy), TransferBlock.backwards);
      final pk4 = _mon(GameVersion.platinum, 25);
      expect(PkTransfer.check(pk4, GameVersion.platinum, GameVersion.emerald), TransferBlock.backwards);
      final pk9 = _mon(GameVersion.scarletViolet, 25);
      expect(PkTransfer.check(pk9, GameVersion.scarletViolet, GameVersion.swordShield), isNull);
      expect(PkTransfer.check(pk9, GameVersion.scarletViolet, GameVersion.ultraSunUltraMoon), TransferBlock.backwards);
    });

    test('Gen 1/2 solo van a Gen 1/2 o, por la Consola Virtual, a Gen 7+', () {
      final pk1 = _mon(GameVersion.redBlue, 25);
      expect(PkTransfer.check(pk1, GameVersion.redBlue, GameVersion.emerald), TransferBlock.noRoute);
      expect(PkTransfer.check(pk1, GameVersion.redBlue, GameVersion.xy), TransferBlock.noRoute);
      expect(PkTransfer.check(pk1, GameVersion.redBlue, GameVersion.sunMoon), isNull);
      // Japonés ↔ internacional no se puede intercambiar.
      expect(PkTransfer.check(pk1, GameVersion.redBlue, GameVersion.crystal, destJapanese: true), TransferBlock.gbLanguage);
      // Gen 2 → Gen 1: solo especies y movimientos de Gen 1.
      final pk2 = _mon(GameVersion.crystal, 152);
      expect(PkTransfer.check(pk2, GameVersion.crystal, GameVersion.redBlue), TransferBlock.notInGen1);
    });

    test('huevos: solo entre juegos del mismo formato', () {
      final egg = _mon(GameVersion.platinum, 25, egg: true);
      expect(PkTransfer.check(egg, GameVersion.platinum, GameVersion.heartGoldSoulSilver), isNull);
      expect(PkTransfer.check(egg, GameVersion.platinum, GameVersion.blackWhite), TransferBlock.egg);
    });

    test('especie o forma que no existe en el destino', () {
      final pikachu = _mon(GameVersion.swordShield, 25);
      expect(PkTransfer.check(pikachu, GameVersion.swordShield, GameVersion.scarletViolet), isNull);
      final pidgey = _mon(GameVersion.swordShield, 16); // Pidgey no está en Escarlata/Púrpura
      expect(PkTransfer.check(pidgey, GameVersion.swordShield, GameVersion.scarletViolet),
          TransferBlock.speciesNotInGame);
      final caterpie = _mon(GameVersion.swordShield, 10);
      expect(PkTransfer.check(caterpie, GameVersion.swordShield, GameVersion.scarletViolet),
          TransferBlock.speciesNotInGame);
      final pk7 = _mon(GameVersion.ultraSunUltraMoon, 731); // Pikipek no está en Espada/Escudo
      expect(PkTransfer.check(pk7, GameVersion.ultraSunUltraMoon, GameVersion.swordShield),
          TransferBlock.speciesNotInGame);
    });

    test('Spinda y Nincada no entran ni salen de BDSP; Let\'s Go solo recibe lo suyo; Z-A no envía', () {
      final spinda = _mon(GameVersion.brilliantDiamondShiningPearl, 327);
      expect(PkTransfer.check(spinda, GameVersion.brilliantDiamondShiningPearl, GameVersion.scarletViolet),
          TransferBlock.bdspLocked);
      final pk8 = _mon(GameVersion.swordShield, 25);
      expect(PkTransfer.check(pk8, GameVersion.swordShield, GameVersion.letsGo), TransferBlock.letsGoOnly);
      final za = _mon(GameVersion.legendsZA, 25);
      expect(PkTransfer.check(za, GameVersion.legendsZA, GameVersion.scarletViolet), TransferBlock.noRoute);
      expect(PkTransfer.check(pk8, GameVersion.swordShield, GameVersion.legendsZA), isNull);
    });

    test('Pokémon oscuro sin purificar no sale de Colosseum/XD', () {
      final ed = SaveEditor.open(SyntheticSaves.colosseumDemo());
      final shadow = [
        for (var b = 0; b < ed.boxCount; b++)
          for (var s = 0; s < ed.boxSlotCount; s++) ed.get(SlotRef.box(b, s))
      ].whereType<Pkm>().firstWhere((p) => p.gc?.isShadow ?? false, orElse: () => ed.party.firstWhere((p) => p.gc?.isShadow ?? false));
      expect(PkTransfer.check(shadow, GameVersion.colosseum, GameVersion.emerald), TransferBlock.shadow);
    });

    test('HOME: rastreador nuevo y no nulo; se conserva en saltos posteriores', () {
      final us = transferCases.firstWhere((c) => c.id == 'us-sw');
      final sw = us.convert().pk!;
      expect(sw.homeTracker, isNot(0));
      final sv = PkTransfer.convert(sw, GameVersion.swordShield, GameVersion.scarletViolet,
              trainer: destTrainer, random: Random(9))
          .pk!;
      expect(sv.homeTracker, sw.homeTracker);
      // Dos Pokémon distintos reciben rastreadores distintos.
      final other = transferCases.firstWhere((c) => c.id == 'us-sv').convert().pk!;
      expect(other.homeTracker, isNot(sw.homeTracker));
    });

    test('HOME quita el objeto; Gen 3 → 4 pierde las MO y convierte el objeto', () {
      final pk7 = _mon(GameVersion.ultraSunUltraMoon, 25, item: 1);
      final r = PkTransfer.convert(pk7, GameVersion.ultraSunUltraMoon, GameVersion.swordShield, today: transferDay);
      expect(r.pk!.heldItem, 0);
      final pk3 = _mon(GameVersion.emerald, 25, item: 13) // Poción (Gen 3)
        ..setMove(0, 57) // Surf (MO)
        ..setMove(1, 84);
      final pk4 = PkTransfer.convert(pk3, GameVersion.emerald, GameVersion.diamondPearl, today: transferDay).pk!;
      expect(pk4.moves.first, 84);
      expect(pk4.moves, isNot(contains(57)));
      expect(pk4.heldItem, 17); // Poción (Gen 4)
      expect(pk4.metLocation, 55); // Parque Compi
      expect(pk4.metDate, transferDay);
    });

    test('cintas: los rangos de concurso de Gen 3 pasan a cintas; en Gen 6 se resumen en el recuerdo', () {
      final pk3 = _mon(GameVersion.emerald, 25);
      Ribbons.set(pk3, 'RibbonCountG3Cool', 3); // hasta Ultra
      Ribbons.set(pk3, 'RibbonChampionG3', 1);
      final pk4 = PkTransfer.convert(pk3, GameVersion.emerald, GameVersion.diamondPearl, today: transferDay).pk!;
      expect(Ribbons.get(pk4, 'RibbonG3Cool'), 1);
      expect(Ribbons.get(pk4, 'RibbonG3CoolHyper'), 1);
      expect(Ribbons.get(pk4, 'RibbonG3CoolMaster'), 0);
      expect(Ribbons.get(pk4, 'RibbonChampionG3'), 1);
      final pk6 = PkTransfer.convert(pk4, GameVersion.diamondPearl, GameVersion.xy, today: transferDay).pk!;
      expect(Ribbons.get(pk6, 'RibbonCountMemoryContest'), 3);
      expect(Ribbons.get(pk6, 'RibbonChampionG3'), 1);
    });

    test('Arceus pierde la tabla al pasar a Gen 5', () {
      final arceus = _mon(GameVersion.heartGoldSoulSilver, 493, level: 80, form: 2, item: 298);
      final pk5 = PkTransfer.convert(arceus, GameVersion.heartGoldSoulSilver, GameVersion.blackWhite).pk!;
      expect(pk5.form, 0);
      expect(pk5.heldItem, 0);
    });

    test('la ruta pasa por todos los formatos intermedios', () {
      final c = transferCases.firstWhere((c) => c.id == 'e-sv');
      expect(c.convert().route,
          [PkFormat.pk3, PkFormat.pk4, PkFormat.pk5, PkFormat.pk6, PkFormat.pk7, PkFormat.pk9]);
    });
  });

  group('Vista previa', () {
    test('Gen 3 → 4: MO borradas, objeto convertido, cintas de concurso conservadas', () {
      final pk3 = _mon(GameVersion.emerald, 25, item: 13)
        ..setMove(0, 57)
        ..setMove(1, 84);
      Ribbons.set(pk3, 'RibbonCountG3Cool', 2);
      final r = PkTransfer.convert(pk3, GameVersion.emerald, GameVersion.diamondPearl, today: transferDay);
      final d = TransferDiff.of(pk3, r.pk!);
      expect(d.movesChanged, isTrue);
      expect(d.itemChanged, isTrue);
      expect(d.ribbonsKept, greaterThan(0));
      expect(d.ribbonsLost, isEmpty);
      expect(r.viaHome, isFalse);
    });
    test('USUM → SV pasa por HOME y se puede parar en Alola; SV → SwSh no', () {
      final us = transferCases.firstWhere((c) => c.id == 'us-sv').convert();
      expect(us.viaHome, isTrue);
      expect(us.canStopAtAlola, isTrue);
      final sv = transferCases.firstWhere((c) => c.id == 'sv-sw').convert();
      expect(sv.viaHome, isTrue);
      expect(sv.canStopAtAlola, isFalse);
      final d = TransferDiff.of(transferCases.firstWhere((c) => c.id == 'us-sv').source(), us.pk!);
      expect(d.itemRemoved || d.itemBefore == 0, isTrue); // HOME no guarda objetos
    });
  });

  group('Clones por rastreador de HOME', () {
    test('detecta el mismo rastreador en dos partidas', () {
      final a = transferCases.firstWhere((c) => c.id == 'us-sw').convert().pk!;
      final b = a.clone();
      final c = transferCases.firstWhere((c) => c.id == 'us-sv').convert().pk!;
      final groups = HomeTrackerClones.find([('save1', a), ('save2', b), ('save2', c)]);
      expect(groups, hasLength(1));
      expect(groups.single.tracker, a.homeTracker);
      expect(groups.single.owners, ['save1', 'save2']);
    });
  });
}
