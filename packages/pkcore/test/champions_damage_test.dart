import 'dart:convert';
import 'dart:io';

import 'package:pkcore/pkcore.dart';
import 'package:test/test.dart';

/// Calculadora de daño contra el simulador de Pokémon Showdown (mod
/// champions): `tool/showdown_ref/damage_ref.js` genera los casos (bordes y al
/// azar) con las 16 tiradas que calcula el simulador; aquí tienen que
/// coincidir todas.
void main() {
  final ref = jsonDecode(File('test/data/champions_damage_ref.json').readAsStringSync()) as Map<String, Object?>;
  final cases = (ref['cases'] as List).cast<Map<String, Object?>>();

  String describe(Map<String, Object?> c) {
    final a = c['attacker'] as Map, d = c['defender'] as Map;
    return '${a['mega'] ?? a['species']}(${a['ability']},${a['item']},${a['status']},${a['boosts']},${a['hpPercent']}) '
        '${c['move']} → ${d['mega'] ?? d['species']}(${d['ability']},${d['item']},${d['status']},${d['boosts']},${d['hpPercent']}) '
        '${c['field']}';
  }

  test('las ${cases.length} referencias de Showdown coinciden tirada a tirada', () {
    expect(cases.length, greaterThanOrEqualTo(200));
    final fails = <String>[];
    var rolls = 0;
    for (final c in cases) {
      final attacker = ChampionsSide.fromJson((c['attacker'] as Map).cast<String, Object?>());
      final defender = ChampionsSide.fromJson((c['defender'] as Map).cast<String, Object?>());
      final move = ChampionsDex.move(c['move'] as String)!;
      final field = ChampionsField.fromJson((c['field'] as Map).cast<String, Object?>());
      final r = ChampionsDamage.calculate(attacker: attacker, defender: defender, move: move, field: field);
      final e = (c['expected'] as Map).cast<String, Object?>();
      if (e['immune'] == true) {
        if (!r.immune) fails.add('esperaba inmune: ${describe(c)} → ${r.rolls}');
        continue;
      }
      final want = (e['rolls'] as List).cast<int>();
      rolls += 16;
      if (r.immune || r.rolls.join(',') != want.join(',')) {
        fails.add(
          '${describe(c)}\n   showdown ${want.join(',')}\n   dart     ${r.immune ? 'inmune' : r.rolls.join(',')}',
        );
      }
      final hit2 = (e['hit2'] as List?)?.cast<int>();
      if (hit2 != null && (r.hitRolls.length < 2 || r.hitRolls[1].join(',') != hit2.join(','))) {
        fails.add(
          '2.º golpe ${describe(c)}\n   showdown ${hit2.join(',')}\n   dart     ${r.hitRolls.length > 1 ? r.hitRolls[1].join(',') : '-'}',
        );
      }
    }
    final ok = cases.length - fails.length;
    // ignore: avoid_print
    print(
      'Coincidencias: $ok/${cases.length} casos (${(ok * 100 / cases.length).toStringAsFixed(1)} %), $rolls tiradas',
    );
    expect(fails, isEmpty, reason: fails.take(15).join('\n'));
  });

  test('probabilidad de KO y texto', () {
    final a = ChampionsSide(
      ChampionsBuild.fromShowdown(
        Showdown.parse(
          'Garchomp @ Life Orb\nAbility: Rough Skin\nEVs: 2 HP / 32 Atk / 32 Spe\nJolly Nature\n- Earthquake',
        ).single,
      )!.build,
    );
    final d = ChampionsSide(
      ChampionsBuild.fromShowdown(
        Showdown.parse(
          'Incineroar\nAbility: Intimidate\nEVs: 32 HP / 32 SpD / 2 Spe\nCareful Nature\n- Fake Out',
        ).single,
      )!.build,
    );
    final move = ChampionsDex.move('earthquake')!;
    const field = ChampionsField(doubles: false);
    final r = ChampionsDamage.calculate(attacker: a, defender: d, move: move, field: field);
    expect(r.rolls, hasLength(16));
    expect(r.rolls, orderedEquals([...r.rolls]..sort()));
    final ko = r.ko!;
    expect(ko.n, greaterThanOrEqualTo(1));
    // Con el mínimo y el máximo se sabe el rango de golpes.
    expect(r.koChance(ko.n), ko.chance);
    if (ko.n > 1) expect(r.koChance(ko.n - 1), 0);
    final text = championsDamageText(a, d, move, field, r, es: false);
    expect(text, startsWith('32 Atk Life Orb Garchomp Earthquake vs. 32 HP / 0 Def Incineroar: '));
    expect(text, contains('HKO'));
  });

  test('inmunidad: Tierra contra Levitación', () {
    final a = ChampionsSide(ChampionsBuild(speciesId: 'garchomp', ability: 'roughskin'));
    final d = ChampionsSide(ChampionsBuild(speciesId: 'rotomwash', ability: 'levitate'));
    final r = ChampionsDamage.calculate(attacker: a, defender: d, move: ChampionsDex.move('earthquake')!);
    expect(r.immune, isTrue);
    expect(r.ko, isNull);
  });
}
