// Verificación masiva de los datos por forma contra PKHeX.
//
// `test/data/form_oracle.csv.gz` lo genera tool/gen_form_data.sh con el oráculo
// (tools/pkhex_oracle, comando `forms`): una fila por cada (juego, especie,
// forma) presente en cada juego de Gen 3–9 según PKHeX (`IsPresentInGame`), con
// tipos, stats base, habilidades y género de `PersonalTable`. El test no
// necesita PKHeX: usa la tabla versionada.
import 'dart:io';

import 'package:pkcore/pkcore.dart';
import 'package:test/test.dart';

const _games = {
  'rs': GameVersion.rubySapphire,
  'e': GameVersion.emerald,
  'fr': GameVersion.fireRedLeafGreen,
  'dp': GameVersion.diamondPearl,
  'pt': GameVersion.platinum,
  'hgss': GameVersion.heartGoldSoulSilver,
  'bw': GameVersion.blackWhite,
  'b2w2': GameVersion.black2White2,
  'xy': GameVersion.xy,
  'ao': GameVersion.omegaRubyAlphaSapphire,
  'sm': GameVersion.sunMoon,
  'uu': GameVersion.ultraSunUltraMoon,
  'gg': GameVersion.letsGo,
  'swsh': GameVersion.swordShield,
  'bdsp': GameVersion.brilliantDiamondShiningPearl,
  'la': GameVersion.legendsArceus,
  'sv': GameVersion.scarletViolet,
  'za': GameVersion.legendsZA,
};

typedef _Row = ({String key, int species, int form, List<int> v, String pre});

List<_Row> _load() {
  final raw = GZipCodec().decode(File('test/data/form_oracle.csv.gz').readAsBytesSync());
  return [
    for (final line in String.fromCharCodes(raw).split('\n'))
      if (line.isNotEmpty && !line.startsWith('#'))
        () {
          final c = line.split(',');
          return (
            key: c[0],
            species: int.parse(c[1]),
            form: int.parse(c[2]),
            v: [for (final x in c.sublist(3, 15)) int.parse(x)],
            pre: c[15],
          );
        }(),
  ];
}

void main() {
  final rows = _load();

  test('la tabla cubre todos los juegos de Gen 3–9', () {
    expect({for (final r in rows) r.key}, _games.keys.toSet());
    expect(rows.length, greaterThan(11000));
  });

  test('tipos, stats base, habilidades y género por (especie, forma, juego) = PKHeX', () {
    final diffs = <String>[];
    for (final r in rows) {
      final game = _games[r.key]!;
      final id = '${r.key} ${r.species}-${r.form}';
      final e = SpeciesForms.personal(r.species, r.form, game);
      if (e == null) {
        diffs.add('$id: sin datos');
        continue;
      }
      final (t1, t2) = SpeciesForms.types(r.species, r.form, game);
      final w1 = PokemonType.values[r.v[0] + 1], w2 = PokemonType.values[r.v[1] + 1];
      if (t1 != w1 || t2 != (w2 == w1 ? PokemonType.none : w2)) diffs.add('$id: tipos $t1/$t2 ≠ $w1/$w2');
      // PKHeX: PS, Atq, Def, AtqEsp, DefEsp, Vel (mismo orden que PersonalEntry.baseStats).
      final stats = r.v.sublist(2, 8);
      if (e.baseStats.join(',') != stats.join(',')) diffs.add('$id: stats ${e.baseStats} ≠ $stats');
      final abil = r.v.sublist(8, 11).where((a) => a != 0).toList();
      if (e.abilities.join(',') != abil.join(',')) diffs.add('$id: habilidades ${e.abilities} ≠ $abil');
      if (e.genderRatio != r.v[11]) diffs.add('$id: género ${e.genderRatio} ≠ ${r.v[11]}');
    }
    expect(diffs, isEmpty, reason: '${diffs.length} diferencias:\n${diffs.take(40).join('\n')}');
  });

  test('formas presentes en cada juego = PKHeX IsPresentInGame', () {
    final want = {for (final r in rows) '${r.key} ${r.species}-${r.form}'};
    final got = <String>{};
    for (final MapEntry(:key, value: game) in _games.entries) {
      for (var s = 1; s <= Species.max; s++) {
        for (final f in SpeciesForms.presentForms(s, game)) {
          got.add('$key $s-$f');
        }
      }
    }
    final missing = want.difference(got), extra = got.difference(want);
    expect([...missing.map((m) => 'falta $m'), ...extra.map((m) => 'sobra $m')], isEmpty,
        reason: 'faltan ${missing.length}, sobran ${extra.length}: ${[...missing, ...extra].take(40)}');
  });

  test('preevolución con forma = PKHeX EvolutionTree', () {
    final diffs = <String>[];
    for (final r in rows) {
      final pre = SpeciesForms.preEvolution(r.species, r.form, _games[r.key]!);
      final got = pre == null ? '' : '${pre.$1}-${pre.$2}';
      if (r.pre.isNotEmpty && got != r.pre) diffs.add('${r.key} ${r.species}-${r.form}: $got ≠ ${r.pre}');
    }
    expect(diffs, isEmpty, reason: '${diffs.length} diferencias:\n${diffs.take(40).join('\n')}');
  });
}
