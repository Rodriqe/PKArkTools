import 'package:pkcore/pkcore.dart';
import 'package:test/test.dart';

RibbonRoute _r(int s, [int f = 0]) => RibbonMaster.route(s, f)!;
List<RibbonGame> _games(RibbonRoute r) => [for (final s in r.steps) s.game];
Set<String> _keys(RibbonRoute r) => {for (final s in r.steps) for (final e in s.ribbons) e.key};

void main() {
  group('catálogo de cintas', () {
    test('cada cinta del catálogo existe en pkcore y tiene textos es/en', () {
      for (final e in RibbonGuide.all) {
        expect(Ribbons.info(e.key), isNotNull, reason: e.key);
        expect(e.howEs, isNotEmpty, reason: e.key);
        expect(e.howEn, isNotEmpty, reason: e.key);
        if (e.availability != RibbonAvailability.event) expect(e.games, isNotEmpty, reason: e.key);
      }
    });

    test('concursos en orden de rango y clasificación', () {
      final keys = RibbonGuide.all.map((e) => e.key).toList();
      expect(keys.indexOf('RibbonG3Cool'), lessThan(keys.indexOf('RibbonG3CoolSuper')));
      expect(keys.indexOf('RibbonG3CoolSuper'), lessThan(keys.indexOf('RibbonG3CoolHyper')));
      expect(keys.indexOf('RibbonG3CoolHyper'), lessThan(keys.indexOf('RibbonG3CoolMaster')));
      expect(keys.indexOf('RibbonG4CoolGreat'), lessThan(keys.indexOf('RibbonG4CoolUltra')));
      expect(RibbonGuide.entry('RibbonAbilityWorld')!.availability, RibbonAvailability.closedOnline);
      expect(RibbonGuide.entry('RibbonMasterRank')!.availability, RibbonAvailability.online);
      expect(RibbonGuide.entry('RibbonClassic')!.availability, RibbonAvailability.event);
      expect(RibbonGuide.entry('RibbonNational')!.games, [RibbonGame.colosseum, RibbonGame.xd]);
      for (final k in ['Country', 'World', 'Classic', 'Premier', 'Wishing', 'Souvenir']) {
        expect(RibbonGuide.entry('Ribbon$k')!.counts, isFalse, reason: k);
      }
    });

    test('ids de juego estables', () {
      expect(RibbonGame.byId('colosseum'), RibbonGame.colosseum);
      expect(RibbonGame.byId('xd'), RibbonGame.xd);
      expect(RibbonGame.fromPkhexVersion('COLO'), RibbonGame.colosseum);
      expect(RibbonGame.fromPkhexVersion('LG'), RibbonGame.frlg);
      expect({for (final g in RibbonGame.values) g.id}.length, RibbonGame.values.length);
    });
  });

  group('grafo de transferencias', () {
    test('solo hacia adelante', () {
      expect(RibbonGraph.canReach(RibbonGame.xd, RibbonGame.sv), isTrue);
      expect(RibbonGraph.canReach(RibbonGame.rse, RibbonGame.xd), isTrue); // intercambio GBA ↔ GameCube
      expect(RibbonGraph.canReach(RibbonGame.dppt, RibbonGame.rse), isFalse);
      expect(RibbonGraph.canReach(RibbonGame.swsh, RibbonGame.smusum), isFalse);
      expect(RibbonGraph.canReach(RibbonGame.vc, RibbonGame.smusum), isTrue);
      expect(RibbonGraph.canReach(RibbonGame.vc, RibbonGame.oras), isFalse);
      expect(RibbonGraph.canReach(RibbonGame.lgpe, RibbonGame.sv), isTrue);
      expect(RibbonGraph.canReach(RibbonGame.sv, RibbonGame.lgpe), isFalse); // Let's Go: solo de ida
      expect(RibbonGraph.canReach(RibbonGame.sv, RibbonGame.bdsp), isTrue); // HOME: ida y vuelta
    });

    test('los juegos de cada ruta son alcanzables desde su origen', () {
      for (final (s, f) in RibbonMaster.targets) {
        final r = _r(s, f);
        final reach = RibbonGraph.reachable(r.data.originGame);
        for (final g in _games(r)) {
          expect(reach.contains(g), isTrue, reason: '$s-$f: ${g.id} desde ${r.data.originGame.id}');
        }
        expect(r.steps.first.game, r.data.originGame, reason: '$s-$f empieza en su origen');
      }
    });
  });

  group('ruta máxima', () {
    test('Gen 3: Bulbasaur desde Rojo Fuego/Verde Hoja hasta Escarlata/Púrpura', () {
      final r = _r(1);
      expect(r.data.originGame, RibbonGame.frlg);
      expect(_games(r), containsAllInOrder([RibbonGame.frlg, RibbonGame.rse, RibbonGame.dppt, RibbonGame.xy, RibbonGame.smusum, RibbonGame.swsh, RibbonGame.sv]));
      expect(_keys(r), containsAll(['RibbonG3CoolMaster', 'RibbonG4ToughMaster', 'RibbonChampionKalos', 'RibbonChampionPaldea', 'RibbonEarth']));
      expect(_keys(r), isNot(contains('RibbonHisui'))); // no está en Leyendas Arceus
      expect(_keys(r), isNot(contains('RibbonNational'))); // no viene de un Pokémon oscuro
      expect(r.total, 85);
      // Cada cinta se cuenta una vez, en el primer juego donde se puede ganar.
      final all = [for (final s in r.steps) ...s.ribbons.map((e) => e.key)];
      expect(all.toSet().length, all.length);
      expect(r.steps.firstWhere((s) => s.game == RibbonGame.rse).ribbons.map((e) => e.key), contains('RibbonEffort'));
    });

    test('Pokémon oscuro de XD: Cinta Nacional y origen GameCube', () {
      final r = _r(37); // Vulpix
      expect(r.data.originGame, RibbonGame.xd);
      expect(r.data.kind, OriginKind.shadow);
      expect(r.steps.first.ribbons.map((e) => e.key), containsAll(['RibbonNational', 'RibbonEarth']));
    });

    test('Gen 4, 5, 6, 7, 8 y 9: el origen más antiguo posible', () {
      expect(_r(387).data.originGeneration, 4); // Turtwig
      expect(_r(495).data.originGeneration, 5); // Snivy
      expect(_r(650).data.originGeneration, 6); // Chespin
      expect(_r(722).data.originGeneration, 7); // Rowlet
      expect(_r(810).data.originGeneration, 8); // Grookey
      expect(_r(906).data.originGeneration, 9); // Sprigatito
      // Gen 5 no tiene cintas: el máximo de Snivy empieza a sumar en Gen 6.
      expect(_r(495).steps.first.count, 0);
      expect(_keys(_r(495)), isNot(contains('RibbonG3Cool')));
      expect(_keys(_r(906)), containsAll(['RibbonChampionPaldea', 'RibbonMasterRank']));
    });

    test('evoluciones de especies antiguas heredan su ruta (Sylveon desde Eevee)', () {
      final r = _r(700);
      expect(r.data.originGeneration, 3);
      expect(r.formFirstGame, RibbonGame.xy);
      final xy = r.steps.firstWhere((s) => s.game == RibbonGame.xy);
      expect(xy.notes.map((n) => n.kind), contains(RouteNoteKind.formAppears));
      final bdsp = r.steps.firstWhere((s) => s.game == RibbonGame.bdsp);
      expect(bdsp.notes.map((n) => n.kind), contains(RouteNoteKind.beforeEvolving)); // Sylveon no está en DBPR
    });

    test('formas regionales: no existen antes de su generación', () {
      final alola = _r(26, 1);
      expect(alola.formFirstGame, RibbonGame.smusum);
      expect(alola.steps.where((s) => s.game.generation < 7).every((s) => !s.stages.contains((26, 1))), isTrue);
      expect(_r(110, 1).formFirstGame, RibbonGame.swsh); // Weezing de Galar desde Koffing
      expect(_r(157, 1).formFirstGame, RibbonGame.pla); // Typhlosion de Hisui
      expect(_keys(_r(157, 1)), contains('RibbonHisui'));
      final paldea = _r(194, 1); // Wooper de Paldea
      expect(paldea.data.originGeneration, 9);
      expect(_games(paldea), isNot(contains(RibbonGame.swsh)));
    });

    test('restricciones: vetados del Frente Batalla y singulares', () {
      final mewtwo = _keys(_r(150));
      expect(mewtwo, isNot(contains('RibbonWinning')));
      expect(mewtwo, isNot(contains('RibbonAbility')));
      expect(mewtwo, isNot(contains('RibbonBattlerSkillful')));
      expect(mewtwo, contains('RibbonBattleTreeGreat'));
      expect(_keys(_r(132)), isNot(contains('RibbonG4Cool'))); // Ditto no entra en Superconcursos
    });

    test('Let\'s Go solo de ida: Meltan llega a HOME', () {
      final r = _r(808);
      expect(_games(r), isNot(contains(RibbonGame.smusum)));
    });

    test('servicios cerrados y eventos van aparte y no suman', () {
      final r = _r(1);
      expect(r.unavailable.map((e) => e.key), containsAll(['RibbonAbilityWorld', 'RibbonClassic', 'RibbonWishing']));
      expect(r.steps.expand((s) => s.ribbons).where((e) => !e.counts).map((e) => e.key), ['RibbonAbilityWorld']);
      expect(r.total, r.steps.expand((s) => s.ribbons).where((e) => e.counts).length);
    });

    test('marcas: aparte, sin sumar', () {
      final r = _r(906);
      expect(r.postCaptureMarks, RibbonGuide.postCaptureMarks);
      expect(r.markGames, contains(RibbonGame.sv));
      expect(RibbonGuide.encounterMarks(RibbonGame.sv), isNotEmpty);
    });

    test('recuerdos de concurso y combate al pasar a Gen 6', () {
      expect(_r(1).memoryCounts, (40, 8));
      expect(_r(150).memoryCounts, (40, 0));
      expect(_r(1).visibleInFinalGame, lessThan(_r(1).total));
    });

    test('lo que le falta a un ejemplar según su juego actual', () {
      final r = _r(1);
      final inSv = r.missingFor(const ['RibbonChampionPaldea'], RibbonGame.sv);
      expect(inSv.map((e) => e.key), containsAll(['RibbonEffort', 'RibbonBestFriends', 'RibbonChampionGalar', 'RibbonTwinklingStar']));
      expect(inSv.map((e) => e.key), isNot(contains('RibbonChampionPaldea')));
      expect(inSv.map((e) => e.key), isNot(contains('RibbonChampionKalos'))); // Gen 6 ya no es alcanzable
      expect(r.missingFor(const [], RibbonGame.rse).length, r.total);
      expect(RibbonGame.fromGameVersion(GameVersion.emerald), RibbonGame.rse);
    });

    test('texto para foros', () {
      final t = _r(1).toText(DataLanguage.en);
      expect(t, contains('Ribbon Master: Bulbasaur'));
      expect(t, contains('Max ribbons today: 85'));
      expect(_r(1).toText(DataLanguage.es), contains('No disponibles hoy'));
    });
  });

  group('ranking', () {
    test('orden por total, desempate por Dex y empates con puesto compartido', () {
      final all = RibbonMaster.ranking();
      expect(all.length, RibbonMaster.targets.length);
      for (var i = 1; i < all.length; i++) {
        final a = all[i - 1], b = all[i];
        expect(a.route.total >= b.route.total, isTrue);
        if (a.route.total == b.route.total) {
          expect(b.position, a.position);
          expect(a.route.species <= b.route.species, isTrue);
          expect(a.tied && b.tied, isTrue);
        } else {
          expect(b.position, i + 1);
        }
      }
      expect(all.first.position, 1);
    });

    test('niveles: uno por total, ordenados, con todas las especies y en orden de Dex', () {
      final tiers = RibbonMaster.tiers();
      final all = RibbonMaster.ranking();
      expect(tiers.map((t) => t.length).fold(0, (a, b) => a + b), all.length);
      expect(tiers.map((t) => t.total).toSet().length, tiers.length);
      for (final (i, t) in tiers.indexed) {
        expect(t.position, i + 1);
        if (i > 0) expect(tiers[i - 1].total, greaterThan(t.total));
        expect(t.routes.every((r) => r.total == t.total), isTrue);
        for (var j = 1; j < t.routes.length; j++) {
          final a = t.routes[j - 1], b = t.routes[j];
          expect(a.species < b.species || (a.species == b.species && a.form < b.form), isTrue);
        }
        expect(t.length, all.where((e) => e.route.total == t.total).length);
        expect(t.speciesCount, lessThanOrEqualTo(t.length));
        expect(t.origins.fold(0, (a, o) => a + o.count), t.length);
        for (var j = 1; j < t.origins.length; j++) {
          expect(t.origins[j - 1].count, greaterThanOrEqualTo(t.origins[j].count));
        }
        expect(t.sample(6).length, t.length < 6 ? t.length : 6);
      }
      expect(tiers.first.total, greaterThanOrEqualTo(85));
      expect(tiers.first.length, greaterThan(1));
    });

    test('nivel más alto: origen oscuro en Colosseum / XD', () {
      final top = RibbonMaster.tiers().first;
      expect(top.mainOrigin.kind, OriginKind.shadow);
      expect(top.mainOrigin.games.every((g) => g == RibbonGame.colosseum || g == RibbonGame.xd), isTrue);
      expect(top.origins.length, 1); // Colosseum y XD van juntos
      expect(top.mainOrigin.gamesLabel(DataLanguage.en), 'Colosseum / XD');
    });

    test('nivel de una especie', () {
      final t = RibbonMaster.tierOf(1, 0)!;
      expect(t.total, RibbonMaster.route(1, 0)!.total);
      expect(t.routes.any((r) => r.species == 1 && r.form == 0), isTrue);
      expect(RibbonMaster.tier(t.total), same(t));
      expect(RibbonMaster.tier(-1), isNull);
      expect(RibbonMaster.tierOf(0, 0), isNull);
    });
  });
}
