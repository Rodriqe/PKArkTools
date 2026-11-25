import 'dart:convert';
import 'dart:io';

import 'package:pkcore/pkcore.dart';
import 'package:test/test.dart';

/// Estadísticas de Champions contra los valores que calcula el simulador de
/// Pokémon Showdown (`tool/showdown_ref/stats_ref.js`, mod champions).
void main() {
  final ref = jsonDecode(File('test/data/champions_stats_ref.json').readAsStringSync()) as Map<String, Object?>;
  final cases = (ref['cases'] as List).cast<Map<String, Object?>>();

  test('las ${cases.length} referencias de Showdown coinciden exactamente', () {
    expect(cases.length, greaterThanOrEqualTo(380));
    var checked = 0;
    for (final c in cases) {
      final s = ChampionsDex.species(c['species'] as String);
      expect(s, isNotNull, reason: '${c['species']}');
      final nature = Showdown.natureId(c['nature'] as String)!;
      final sp = (c['sp'] as List).cast<int>();
      final got = ChampionsStats.all(base: s!.baseStats, sp: sp, nature: nature, shedinja: s.num == 292);
      expect(got, c['stats'], reason: '${s.id} ${c['nature']} $sp');
      checked++;
    }
    expect(checked, cases.length);
  });

  test('fórmula: PS = base + SP + 75; resto (base + SP + 20) × naturaleza', () {
    final g = ChampionsDex.species('garchomp')!;
    final jolly = Showdown.natureId('Jolly')!;
    expect(ChampionsStats.all(base: g.baseStats, sp: [2, 32, 0, 0, 0, 32], nature: jolly), [
      185,
      182,
      115,
      90,
      105,
      169,
    ]);
  });

  test('límites de puntos: 32 por estadística y 66 en total', () {
    expect(ChampionsStats.problems([32, 32, 2, 0, 0, 0], es: true), isEmpty);
    expect(ChampionsStats.problems([33, 0, 0, 0, 0, 0], es: true), hasLength(1));
    expect(ChampionsStats.problems([32, 32, 3, 0, 0, 0], es: false), hasLength(1));
  });

  test('equivalencia EV → SP a nivel 50 (misma estadística con IVs 31)', () {
    expect(ChampionsStats.spFromEv(0), 0);
    expect(ChampionsStats.spFromEv(4), 1);
    expect(ChampionsStats.spFromEv(12), 2);
    expect(ChampionsStats.spFromEv(252), 32);
    // Comprueba la equivalencia contra la fórmula clásica para todos los EVs.
    for (final base in [45, 80, 130]) {
      for (var ev = 0; ev <= 252; ev++) {
        final classic = StatCalc.stat(1, base: base, iv: 31, ev: ev, level: 50);
        expect(
          ChampionsStats.stat(1, base: base, sp: ChampionsStats.spFromEv(ev)),
          classic,
          reason: 'base $base ev $ev',
        );
        final hp = StatCalc.stat(0, base: base, iv: 31, ev: ev, level: 50);
        expect(ChampionsStats.stat(0, base: base, sp: ChampionsStats.spFromEv(ev)), hp);
      }
    }
    // Cualquier reparto de 510 EVs cabe en 66 puntos.
    expect([252, 252, 4, 0, 0, 0].map(ChampionsStats.spFromEv).fold(0, (a, b) => a + b), 65);
  });

  test('datos: especies permitidas resueltas, Megas y movimientos aprendibles', () {
    final allowed = ChampionsDex.allowedSpecies();
    expect(allowed.length, greaterThan(150));
    final unresolved = [
      for (final (s, f) in ChampionsFormat.allowed)
        if (ChampionsDex.byKey(s, f) == null) '$s-$f',
    ];
    expect(unresolved, isEmpty, reason: 'permitidos sin datos de combate');
    final zard = ChampionsDex.byKey(6, 0)!;
    expect(ChampionsDex.megasOf(zard).map((m) => m.id), containsAll(['charizardmegax', 'charizardmegay']));
    expect(ChampionsDex.canLearn(ChampionsDex.species('garchomp')!, 'earthquake'), isTrue);
    expect(ChampionsDex.canLearn(ChampionsDex.species('garchompmega')!, 'earthquake'), isTrue);
    expect(ChampionsDex.moveName(ChampionsDex.move('earthquake')!, DataLanguage.es), 'Terremoto');
    expect(ChampionsDex.itemName('lifeorb', DataLanguage.es), 'Vidasfera');
    expect(ChampionsDex.itemName('charizarditex', DataLanguage.en), 'Charizardite X');
  });

  test('ChampionsBuild: Showdown ida y vuelta, EVs clásicos convertidos y JSON', () {
    const text = '''Chompy (Garchomp) @ Garchompite
Ability: Rough Skin
Level: 50
EVs: 2 HP / 32 Atk / 32 Spe
Jolly Nature
- Earthquake
- Dragon Claw''';
    final r = ChampionsBuild.fromShowdown(Showdown.parse(text).single)!;
    expect(r.convertedEvs, isFalse);
    final b = r.build;
    expect(b.speciesId, 'garchomp');
    expect(b.megaId, 'garchompmega');
    expect(b.sp, [2, 32, 0, 0, 0, 32]);
    expect(b.moves, ['earthquake', 'dragonclaw']);
    expect(b.toShowdown(), text);
    expect(ChampionsBuild.fromJson(b.toJson()).toShowdown(), text);
    expect(b.stats[0], 185);

    final classic = ChampionsBuild.fromShowdown(
      Showdown.parse(
        'Incineroar @ Sitrus Berry\nAbility: Intimidate\nEVs: 252 HP / 4 Atk / 252 SpD\nCareful Nature\n- Fake Out',
      ).single,
    )!;
    expect(classic.convertedEvs, isTrue);
    expect(classic.build.sp, [32, 1, 0, 0, 32, 0]);
    expect(classic.build.problems(es: true), isEmpty);
  });
}
