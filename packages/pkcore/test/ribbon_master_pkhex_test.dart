// Verifica el motor de Ribbon Master contra PKHeX: para cada especie/forma, las
// cintas que la ruta da por legales deben ser exactamente las que PKHeX
// (`RibbonApplicator.SetAllValidRibbons` + `RibbonVerifier`) acepta para un
// ejemplar del mismo origen pasado por todos los juegos posibles.
// Tabla versionada: test/data/ribbon_oracle.csv.gz (tool/gen_ribbon_master_data.sh).
import 'dart:convert';
import 'dart:io';

import 'package:pkcore/pkcore.dart';
import 'package:test/test.dart';

bool _comparable(String k) =>
    k.startsWith('Ribbon') &&
    !k.startsWith('RibbonMark') &&
    !k.startsWith('RibbonCountMemory') &&
    RibbonGuide.entry(k)?.availability != RibbonAvailability.event;

/// Cintas que trae de serie un regalo de evento concreto (PKHeX exige que las tenga).
const _fromGift = {(25, 9): {'RibbonChampionAlola'}};

void main() {
  final lines = const LineSplitter()
      .convert(utf8.decode(gzip.decode(File('test/data/ribbon_oracle.csv.gz').readAsBytesSync())))
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toList();

  test('la tabla del oráculo cubre todas las rutas', () {
    expect(lines.length, RibbonMaster.targets.length);
    expect(lines.length, greaterThan(1300));
  });

  test('0 contradicciones con PKHeX (cintas por especie y forma)', () {
    final problems = <String>[];
    var compared = 0;
    for (final l in lines) {
      final p = l.split(',');
      final sp = int.parse(p[0]), form = int.parse(p[1]);
      final route = RibbonMaster.route(sp, form)!;
      final pkhex = {for (final k in p[4].split('|')) if (_comparable(k)) k};
      final ours = {for (final k in route.legalKeys) if (_comparable(k)) k, ...?_fromGift[(sp, form)]};
      final extra = ours.difference(pkhex), missing = pkhex.difference(ours);
      if (extra.isNotEmpty || missing.isNotEmpty) {
        problems.add('$sp-$form: de más ${extra.toList()..sort()}, faltan ${missing.toList()..sort()}');
      }
      // Recuerdos de concurso/combate al llegar a Gen 6+.
      final (mc, mb) = route.memoryCounts;
      final oc = int.parse(p[5]), ob = int.parse(p[6]);
      if (route.data.finalFormat != 'PK5' && route.data.finalFormat != 'PK4' && route.data.finalFormat != 'PK3' && (mc != oc || mb != ob)) {
        problems.add('$sp-$form: recuerdos $mc/$mb, PKHeX $oc/$ob');
      }
      compared++;
    }
    expect(compared, lines.length);
    expect(problems, isEmpty, reason: '${problems.length} diferencias:\n${problems.take(40).join('\n')}');
  });
}
