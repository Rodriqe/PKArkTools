import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

void main() {
  SaveEditor sv({List<SynthMon> party = const [], Map<int, List<SynthMon?>> boxes = const {}}) =>
      SaveEditor.open(SyntheticSaves.scarletViolet(party: party, boxes: boxes));

  group('StatCalc', () {
    test('Garchomp nivel 50 Alegre 252 Atq/Vel (valores de referencia)', () {
      // Base 108/130/95/80/85/102.
      final stats = StatCalc.all(
        base: const [108, 130, 95, 80, 85, 102],
        ivs: const [31, 31, 31, 31, 31, 31],
        evs: const [4, 252, 0, 0, 0, 252],
        level: 50,
        nature: 13, // Jolly: +Vel −AtqEsp
      );
      expect(stats, [184, 182, 115, 90, 105, 169]);
    });

    test('Shedinja siempre 1 PS', () {
      expect(StatCalc.stat(0, base: 1, iv: 31, ev: 252, level: 100, species: 292), 1);
    });

    test('coincide con Pkm.computeStats en un Pokémon real', () {
      final e = sv(party: const [SynthMon(445, level: 77)]);
      final pk = e.get(const SlotRef.party(0))!
        ..setIvs(const [10, 20, 30, 31, 0, 5])
        ..setEvs(const [100, 0, 252, 0, 80, 76])
        ..nature = 3
        ..statNature = 3;
      final p = GameDataTable.forGame(GameVersion.scarletViolet).entry(445, 0)!;
      expect(
        StatCalc.all(base: p.baseStats, ivs: pk.ivs, evs: pk.evs, level: pk.level, nature: pk.statNature, species: 445),
        pk.computeStats(),
      );
    });

    test('inversa: recupera los IVs a partir de las estadísticas', () {
      final e = sv(party: const [SynthMon(445, level: 100)]);
      final pk = e.get(const SlotRef.party(0))!
        ..setIvs(const [12, 31, 0, 17, 25, 30])
        ..setEvs(const [0, 0, 0, 0, 0, 0]);
      final ranges = StatCalc.inferFor(pk, pk.computeStats()!)!;
      // A nivel 100 sin EVs cada IV da un valor distinto: rango exacto.
      expect([for (final r in ranges) r.isExact ? r.min : -1], [12, 31, 0, 17, 25, 30]);
    });

    test('inversa a nivel bajo: rango e imposible', () {
      final r = StatCalc.possibleIvs(1, base: 130, observed: 33, ev: 0, level: 10);
      expect(r, [for (var i = 20; i <= 29; i++) i]);
      expect(IvRange.of(r).toString(), '20–29');
      expect(StatCalc.possibleIvs(1, base: 130, observed: 999, ev: 0, level: 10), isEmpty);
    });

    test('Gen 1/2 con DVs y experiencia de estadística', () {
      // Mewtwo nivel 100, DVs 15 y stat exp máxima: PS 415, Especial 406.
      expect(StatCalc.statGb(0, base: 106, dv: 15, statExp: 65535, level: 100), 415);
      expect(StatCalc.statGb(3, base: 154, dv: 15, statExp: 65535, level: 100), 406);
    });
  });

  group('HiddenPower', () {
    test('IVs perfectos = Siniestro 70 en Gen 3–5, 60 en Gen 6+', () {
      const all31 = [31, 31, 31, 31, 31, 31];
      expect(HiddenPower.type(all31), 16);
      expect(HiddenPower.power(all31, generation: 4), 70);
      expect(HiddenPower.power(all31, generation: 7), 60);
    });

    test('Fuego clásico: 31/30/31/30/31/30', () {
      // Orden API: PS, Atq, Def, AtqEsp, DefEsp, Vel.
      expect(HiddenPower.type(const [31, 30, 31, 30, 31, 30]), 9);
      expect(HiddenPower.type(const [31, 30, 30, 31, 31, 31]), 14); // Hielo
    });

    test('ivsFor busca el cambio mínimo', () {
      for (var t = 1; t <= 16; t++) {
        final ivs = HiddenPower.ivsFor(t, const [31, 31, 31, 31, 31, 31]);
        expect(HiddenPower.type(ivs), t);
        expect(ivs.every((v) => v >= 30), isTrue);
      }
    });

    test('Gen 2: DVs perfectos = Siniestro 70', () {
      expect(HiddenPower.type(const [15, 15, 15, 15, 15, 15], generation: 2), 16);
      expect(HiddenPower.power(const [15, 15, 15, 15, 15, 15], generation: 2), 70);
    });
  });

  group('Showdown', () {
    const trainer = TrainerData(name: 'Juliana', tid: 12345, sid: 54321);
    const set = '''
=== [gen9vgc2024regg] Equipo ===

Chompy (Garchomp) (F) @ Life Orb
Ability: Rough Skin
Level: 50
Shiny: Yes
Tera Type: Steel
EVs: 4 HP / 252 Atk / 252 Spe
Jolly Nature
IVs: 0 SpA
- Earthquake
- Dragon Claw
- Protect
- Swords Dance

Rotom-Wash @ Sitrus Berry
Ability: Levitate
Level: 50
EVs: 252 HP / 252 SpA / 4 SpD
Modest Nature
- Hydro Pump
- Thunderbolt
- Protect
- Will-O-Wisp
''';

    test('lee varios sets con todos los campos', () {
      final sets = Showdown.parse(set);
      expect(sets, hasLength(2));
      final a = sets.first;
      expect(a.nickname, 'Chompy');
      expect(a.speciesText, 'Garchomp');
      expect(a.gender, 'F');
      expect(a.item, 'Life Orb');
      expect(a.ability, 'Rough Skin');
      expect(a.level, 50);
      expect(a.shiny, isTrue);
      expect(a.teraType, 'Steel');
      expect(a.evs, {0: 4, 1: 252, 5: 252});
      expect(a.ivs, {3: 0});
      expect(a.nature, 'Jolly');
      expect(a.moves, ['Earthquake', 'Dragon Claw', 'Protect', 'Swords Dance']);
      expect(sets[1].speciesText, 'Rotom-Wash');
      expect(sets[1].nickname, isNull);
    });

    test('resuelve formas', () {
      const g = GameVersion.scarletViolet;
      (int, int) r(String s) {
        final x = Showdown.resolveSpecies(s, g)!;
        return (x.species, x.form);
      }

      expect(r('Rotom-Wash'), (479, 2));
      expect(r('Tauros-Paldea-Blaze'), (128, 2));
      expect(r('Urshifu-Rapid-Strike'), (892, 1));
      expect(r('Indeedee-F'), (876, 1));
      expect(r('Necrozma-Dusk-Mane'), (800, 1));
      expect(r('Maushold-Four'), (925, 1));
      expect(r('Ninetales-Alola'), (38, 1));
      expect(r('Nidoran-F'), (29, 0));
      expect(r('Ho-Oh'), (250, 0));
      expect(r('Porygon-Z'), (474, 0));
      expect(r('Calyrex-Shadow'), (898, 2));
      expect(Showdown.resolveSpecies('Notamon', g), isNull);
    });

    test('crea Pokémon legales con todos los datos', () {
      final sets = Showdown.parse(set);
      final imp = Showdown.toPkm(sets.first, GameVersion.scarletViolet, trainer, random: Random(1));
      final pk = imp.pkm!;
      expect(pk.species, 445);
      expect(pk.nickname, 'Chompy');
      expect(pk.level, 50);
      expect(pk.isShiny, isTrue);
      expect(pk.gender, 1);
      expect(pk.nature, 13);
      expect(pk.statNature, 13);
      expect(GameStrings.item(pk.heldItem, 9, DataLanguage.en), 'Life Orb');
      expect(GameStrings.ability(pk.ability, DataLanguage.en), 'Rough Skin');
      expect(pk.teraType, 8);
      expect(pk.ivs, [31, 31, 31, 0, 31, 31]);
      expect(pk.evs, [4, 252, 0, 0, 0, 252]);
      expect(
        [for (final m in pk.moves) GameStrings.move(m, DataLanguage.en)],
        ['Earthquake', 'Dragon Claw', 'Protect', 'Swords Dance'],
      );
      expect(imp.warnings, isEmpty, reason: [for (final w in imp.warnings) w.message(es: true)].join('\n'));

      final rotom = Showdown.toPkm(sets[1], GameVersion.scarletViolet, trainer, random: Random(2)).pkm!;
      expect((rotom.species, rotom.form), (479, 2));
    });

    test('avisa de lo que no es legal en el juego', () {
      const text = '''
Salamence @ Not An Item
Ability: Levitate
Tera Type: Fire
Bashful Nature
- Earthquake
- Spore
- Fakemove
''';
      final imp = Showdown.toPkm(
        Showdown.parse(text).single,
        GameVersion.emerald,
        const TrainerData(name: 'MAY', tid: 1, sid: 2),
        random: Random(3),
      );
      final codes = {for (final w in imp.warnings) w.code};
      expect(imp.pkm, isNotNull);
      expect(
        codes,
        containsAll([
          ShowdownWarningCode.unknownItem,
          ShowdownWarningCode.abilityNotAvailable,
          ShowdownWarningCode.featureNotInGame, // teratipo en Gen 3
          ShowdownWarningCode.moveNotLearnable, // Espora
          ShowdownWarningCode.unknownMove,
        ]),
      );
      expect(imp.pkm!.nature, 18); // Bashful
    });

    test('especie fuera del juego', () {
      final imp = Showdown.toPkm(
        Showdown.parse('Garchomp').single,
        GameVersion.redBlue,
        const TrainerData(name: 'RED', tid: 1),
        random: Random(4),
      );
      expect(imp.pkm, isNull);
      expect(imp.warnings.first.code, ShowdownWarningCode.speciesNotInGame);
    });

    test('Poder Oculto con tipo ajusta los IVs', () {
      const text = 'Magnezone\nAbility: Magnet Pull\n- Hidden Power [Fire]\n- Thunderbolt';
      final pk = Showdown.toPkm(
        Showdown.parse(text).single,
        GameVersion.ultraSunUltraMoon,
        const TrainerData(name: 'Sun', tid: 1, sid: 1),
        random: Random(5),
      ).pkm!;
      expect(HiddenPower.type(pk.ivs), 9);
      expect(Showdown.export(pk, GameVersion.ultraSunUltraMoon), contains('- Hidden Power [Fire]'));
    });

    test('exportar y volver a importar da el mismo Pokémon', () {
      final sets = Showdown.parse(set);
      for (final s in sets) {
        final pk = Showdown.toPkm(s, GameVersion.scarletViolet, trainer, random: Random(6)).pkm!;
        final text = Showdown.export(pk, GameVersion.scarletViolet);
        final again = Showdown.toPkm(
          Showdown.parse(text).single,
          GameVersion.scarletViolet,
          trainer,
          random: Random(7),
        ).pkm!;
        expect(
          (again.species, again.form, again.level, again.nature, again.heldItem, again.ability),
          (pk.species, pk.form, pk.level, pk.nature, pk.heldItem, pk.ability),
        );
        expect(again.moves, pk.moves);
        expect(again.ivs, pk.ivs);
        expect(again.evs, pk.evs);
        expect(again.isShiny, pk.isShiny);
        expect(again.teraType, pk.teraType);
      }
      final team = Showdown.exportTeam([
        for (final s in sets) Showdown.toPkm(s, GameVersion.scarletViolet, trainer, random: Random(8)).pkm!,
      ], GameVersion.scarletViolet);
      expect(Showdown.parse(team), hasLength(2));
      expect(
        team,
        startsWith('Chompy (Garchomp) (F) @ Life Orb\nAbility: Rough Skin\nLevel: 50\nShiny: Yes\nTera Type: Steel'),
      );
    });

    test('el Pokémon creado se puede guardar en el save', () {
      final e = sv(party: const [SynthMon(25, level: 30)]);
      final pk = Showdown.toPkm(
        Showdown.parse(set).first,
        GameVersion.scarletViolet,
        e.readTrainer(),
        random: Random(9),
      ).pkm!;
      e.set(const SlotRef.party(1), pk);
      final out = e.buildVerified();
      final back = SaveEditor.open(out).get(const SlotRef.party(1))!;
      expect(back.species, 445);
      expect(back.nickname, 'Chompy');
    });

    test('Gen 1/2: DVs y experiencia de estadística', () {
      const text = 'Snorlax @ Leftovers\nIVs: 28 Atk\n- Body Slam';
      final imp = Showdown.toPkm(
        Showdown.parse(text).single,
        GameVersion.crystal,
        const TrainerData(name: 'GOLD', tid: 1),
        random: Random(10),
      );
      final pk = imp.pkm!;
      expect(pk.ivs[1], 14);
      expect(pk.evs.first, 65535);
      expect(Showdown.export(pk, GameVersion.crystal), contains('IVs: 28 Atk'));
    });
  });

  group('BoxSorter', () {
    SaveEditor messy() => sv(
      boxes: {
        0: [
          const SynthMon(150, level: 70),
          null,
          const SynthMon(1, level: 5),
          const SynthMon(25, level: 50, shiny: true),
        ],
        1: [null, const SynthMon(4, level: 20), const SynthMon(25, level: 12)],
      },
    );

    List<int?> speciesOf(SaveEditor e, int box, int n) => [
      for (var s = 0; s < n; s++) e.get(SlotRef.box(box, s))?.species,
    ];

    test('por Pokédex, aplicable y deshacible', () {
      final e = messy();
      final plan = BoxSorter.plan(e, BoxSortMode.dex, firstBox: 0, lastBox: 1);
      expect(plan.moved, greaterThan(0));
      RearrangeSlotsEdit(plan.layout).applyTo(e);
      expect(speciesOf(e, 0, 7), [1, 4, 25, 25, 150, null, null]);
      expect(speciesOf(e, 1, 3), [null, null, null]);
      // Ya ordenado: no hay nada que mover.
      expect(BoxSorter.plan(e, BoxSortMode.dex, firstBox: 0, lastBox: 1).isNoop, isTrue);
      final out = e.buildVerified();
      expect(SaveEditor.open(out).get(const SlotRef.box(0, 4))!.species, 150);
    });

    test('nivel, variocolor primero y generación', () {
      var e = messy();
      RearrangeSlotsEdit(BoxSorter.plan(e, BoxSortMode.level, lastBox: 1).layout).applyTo(e);
      expect(speciesOf(e, 0, 5), [150, 25, 4, 25, 1]);
      e = messy();
      RearrangeSlotsEdit(BoxSorter.plan(e, BoxSortMode.shinyFirst, lastBox: 1).layout).applyTo(e);
      expect(e.get(const SlotRef.box(0, 0))!.isShiny, isTrue);
      e = messy();
      RearrangeSlotsEdit(BoxSorter.plan(e, BoxSortMode.type, lastBox: 1).layout).applyTo(e);
      expect(speciesOf(e, 0, 5), [4, 1, 25, 25, 150]); // Fuego, Planta, Eléctrico, Psíquico (orden de tipos)
    });

    test('living dex: cada especie en su hueco y repetidos detrás', () {
      final e = messy();
      final plan = BoxSorter.plan(e, BoxSortMode.livingDex, firstBox: 0, lastBox: 7);
      RearrangeSlotsEdit(plan.layout).applyTo(e);
      final per = e.boxSlotCount;
      expect(e.get(const SlotRef.box(0, 0))!.species, 1);
      expect(e.get(const SlotRef.box(0, 3))!.species, 4);
      expect(e.get(const SlotRef.box(0, 24))!.species, 25);
      expect(e.get(SlotRef.box(149 ~/ per, 149 % per))!.species, 150);
      expect(plan.overflow, 1);
      // El Pikachu repetido va después del último número usado.
      final after = e.get(SlotRef.box(150 ~/ per, 150 % per));
      expect(after?.species, 25);
    });

    test('solo el rango elegido', () {
      final e = messy();
      final plan = BoxSorter.plan(e, BoxSortMode.dex, firstBox: 1, lastBox: 1);
      expect(plan.layout.keys.every((r) => r.box == 1), isTrue);
      RearrangeSlotsEdit(plan.layout).applyTo(e);
      expect(speciesOf(e, 0, 4), [150, null, 1, 25]);
      expect(speciesOf(e, 1, 3), [4, 25, null]);
    });
  });

  group('ChampionsFormat', () {
    test('la tabla generada se traduce entera a especie y forma', () {
      expect(ChampionsFormat.unresolved, isEmpty);
      expect(ChampionsFormat.allowed.length, greaterThan(200));
      expect(ChampionsFormat.formatName, contains('Reg M-'));
      expect(ChampionsFormat.level, 50);
      expect(ChampionsFormat.itemClause, 1);
      expect(ChampionsFormat.speciesClause, isTrue);
      expect(ChampionsFormat.sourceCommit, hasLength(40));
      expect(ChampionsFormat.allowed, containsAll([(479, 2), (128, 2), (876, 1), (711, 3), (445, 0)]));
      expect(ChampionsFormat.megaSpecies, contains(445));
    });

    const t = TrainerData(name: 'Juliana', tid: 12345, sid: 54321);
    Pkm mon(String s, [GameVersion g = GameVersion.scarletViolet]) =>
        Showdown.toPkm(Showdown.parse(s).single, g, t, random: Random(1)).pkm!;

    test('elegibilidad y motivos', () {
      final chomp = ChampionsFormat.check(mon('Garchomp\nLevel: 50\n- Earthquake'), GameVersion.scarletViolet);
      expect(chomp.eligible, isTrue);
      expect(chomp.canMega, isTrue);
      expect(ChampionsFormat.check(mon('Koraidon\nLevel: 70'), GameVersion.scarletViolet).reasons, [
        ChampionsReason.restricted,
      ]);
      expect(ChampionsFormat.check(mon('Pecharunt\nLevel: 70'), GameVersion.scarletViolet).reasons, [
        ChampionsReason.mythical,
      ]);
      expect(ChampionsFormat.check(mon('Bulbasaur'), GameVersion.scarletViolet).reasons, [
        ChampionsReason.speciesNotAllowed,
      ]);
      // Meowth de Galar no está; Persian de Alola sí.
      expect(ChampionsFormat.check(mon('Persian-Alola'), GameVersion.scarletViolet).eligible, isTrue);
      expect(ChampionsFormat.check(mon('Wooper'), GameVersion.scarletViolet).reasons, [
        ChampionsReason.speciesNotAllowed,
      ]);
      final egg = mon('Garchomp')..isEgg = true;
      expect(ChampionsFormat.check(egg, GameVersion.scarletViolet).reasons, contains(ChampionsReason.egg));
      // Un Pokémon de Esmeralda también puede llegar por HOME.
      expect(
        ChampionsFormat.check(mon('Swampert\nLevel: 60', GameVersion.emerald), GameVersion.emerald).reasons,
        isNot(contains(ChampionsReason.speciesNotAllowed)),
      );
    });

    test('forma no permitida frente a forma estética', () {
      final tauros = mon('Tauros-Paldea-Aqua');
      expect(ChampionsFormat.check(tauros, GameVersion.scarletViolet).eligible, isTrue);
      // Vivillon no está, pero si una forma estética de una especie permitida
      // (Squawkabilly está con sus 4 plumajes) cuenta como permitida.
      final sq = mon('Squawkabilly-Yellow');
      expect(ChampionsFormat.check(sq, GameVersion.scarletViolet).eligible, isTrue);
    });

    test('cláusulas del equipo', () {
      final team = [mon('Garchomp @ Life Orb'), mon('Garchomp @ Leftovers'), mon('Rotom-Wash @ Life Orb')];
      final issues = {for (final i in ChampionsFormat.teamIssues(team, GameVersion.scarletViolet)) i.$1};
      expect(issues, {
        ChampionsTeamIssue.tooFew,
        ChampionsTeamIssue.duplicateSpecies,
        ChampionsTeamIssue.duplicateItem,
      });
      expect(ChampionsFormat.teamIssueText((ChampionsTeamIssue.tooFew, '4'), es: true), contains('4'));
    });
  });

  group('ChampionsData (JSON)', () {
    Map<String, Object?> base() => jsonDecode(ChampionsData.builtinJson) as Map<String, Object?>;
    ChampionsData parse(Map<String, Object?> j) => ChampionsData.parse(jsonEncode(j));
    Matcher invalid({int? future}) =>
        throwsA(isA<ChampionsDataException>().having((e) => e.futureSchema, 'futureSchema', future));

    test('la copia integrada es la misma que data/champions/champions.json', () {
      final file = File('../../data/champions/champions.json').readAsStringSync();
      expect(ChampionsData.builtinJson.trim(), file.trim());
      final d = ChampionsData.builtin;
      expect(d.schemaVersion, ChampionsData.supportedSchemaVersion);
      expect(d.regulation.code, 'M-C');
      expect(d.regulation.name, 'VGC 2026 Reg M-C');
      expect(d.regulation.until, DateTime(2026, 12, 2));
      expect(d.regulation.datesConfirmed, isFalse);
      expect(d.regulations.map((r) => r.code), containsAll(['M-A', 'M-B', 'M-C']));
      expect(d.megaIds, contains('garchompmega'));
    });

    test('válido: otra regulación cambia lo que se permite', () {
      final j = base()
        ..['generatedAt'] = '2030-01-01T00:00:00Z'
        ..['allowed'] = [...(base()['allowed'] as List).where((id) => id != 'garchomp')]
        ..['nextRegulation'] = {
          'code': 'M-D',
          'name': 'VGC 2026 Reg M-D',
          'from': null,
          'until': null,
          'datesSource': '',
          'datesConfirmed': false,
        };
      final d = parse(j);
      expect(d.isNewerThan(ChampionsData.builtin), isTrue);
      expect(d.nextRegulation!.code, 'M-D');
      expect(d.nextRegulation!.from, isNull);
      final t = const TrainerData(name: 'Juliana', tid: 12345, sid: 54321);
      final chomp = Showdown.toPkm(Showdown.parse('Garchomp').single, GameVersion.scarletViolet, t).pkm!;
      addTearDown(ChampionsFormat.reset);
      ChampionsFormat.use(d);
      expect(ChampionsFormat.check(chomp, GameVersion.scarletViolet).reasons, [ChampionsReason.speciesNotAllowed]);
      ChampionsFormat.reset();
      expect(ChampionsFormat.check(chomp, GameVersion.scarletViolet).eligible, isTrue);
    });

    test('no válido', () {
      expect(() => ChampionsData.parse('no es json'), invalid());
      expect(() => ChampionsData.parse('[]'), invalid());
      expect(() => parse(base()..remove('schemaVersion')), invalid());
      expect(() => parse(base()..['schemaVersion'] = '1'), invalid());
      expect(() => parse(base()..remove('regulation')), invalid());
      expect(() => parse(base()..['allowed'] = ['garchomp']), invalid());
      expect(() => parse(base()..['allowed'] = [...base()['allowed'] as List, 'garchomp']), invalid());
      expect(() => parse(base()..['allowed'] = [...base()['allowed'] as List, 'Bad Id']), invalid());
      expect(() => parse(base()..['megas'] = []), invalid());
      expect(() => parse(base()..['source'] = {...base()['source'] as Map, 'commit': 'abc'}), invalid());
      expect(() => parse(base()..['source'] = {...base()['source'] as Map, 'url': 'http://evil.example/'}), invalid());
      final reg = {...base()['regulation'] as Map, 'from': '2026-12-02', 'until': '2026-09-09'};
      expect(() => parse(base()..['regulation'] = reg), invalid());
      expect(() => parse(base()..['regulation'] = {...reg, 'name': 'National Dex'}), invalid());
    });

    test('esquema futuro: se ignora y se avisa', () {
      expect(() => parse(base()..['schemaVersion'] = 2), invalid(future: 2));
      // Aunque el resto no se entienda.
      expect(() => ChampionsData.parse('{"schemaVersion": 7}'), invalid(future: 7));
    });
  });

  test('Showdown: Gourgeist-Super es la forma Jumbo de PKHeX', () {
    expect(Showdown.resolveSpecies('Gourgeist-Super', GameVersion.scarletViolet)!.form, 3);
    expect(Showdown.speciesName(711, 3, GameVersion.scarletViolet), 'Gourgeist-Super');
  });
}
