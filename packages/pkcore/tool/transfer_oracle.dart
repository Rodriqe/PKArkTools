// Oráculo de transferencias: compara PkTransfer con PKHeX EntityConverter.
//
//   dart run tool/transfer_oracle.dart cases <cases.json>
//       lista de orígenes; PkhexOracle transfersrc los genera (legales) en test/data/transfer/
//   dart run tool/transfer_oracle.dart gen <dir>
//       escribe origen y resultado de pkcore de cada caso de
//       test/transfer_cases.dart y el manifiesto para el oráculo .NET
//   dotnet <oracle>/PkhexOracle.dll transfer <dir>/manifest.json <dir>/oracle.json
//   dart run tool/transfer_oracle.dart collect <dir>/oracle.json test/data/transfer_oracle.json
//       resume el veredicto de PKHeX (fixture versionado de transfer_test.dart)
//
// tool/transfer_oracle.sh hace los tres pasos.
import 'dart:convert';
import 'dart:io';

import 'package:pkcore/pkcore.dart';

import '../test/transfer_cases.dart';

void main(List<String> args) {
  if (args.length >= 2 && args[0] == 'cases') return _cases(args[1]);
  if (args.length >= 2 && args[0] == 'gen') return _gen(args[1]);
  if (args.length >= 3 && args[0] == 'collect') return _collect(args[1], args[2]);
  stderr.writeln('uso: gen <dir> | collect <oracle.json> <fixture.json>');
  exitCode = 2;
}

/// Lista de orígenes para `PkhexOracle transfersrc`.
void _cases(String path) {
  final list = [
    for (final c in transferCases)
      {'id': c.id, 'version': c.pkhexVersion, 'species': c.species, 'ext': c.sourceFormat.extension},
  ];
  File(path).writeAsStringSync(jsonEncode(list));
}

void _gen(String dir) {
  Directory(dir).createSync(recursive: true);
  final manifest = <Map<String, Object?>>[];
  for (final c in transferCases) {
    final src = c.source();
    final r = c.convert();
    final srcName = '${c.id}.src.${src.format.extension}';
    File('$dir/$srcName').writeAsBytesSync(src.toFile());
    final dest = PkFormat.forGame(c.to).extension;
    final entry = <String, Object?>{'id': c.id, 'src': srcName, 'dest': dest, 'pkhexOut': '${c.id}.pkhex.$dest'};
    if (r.pk != null) {
      final name = '${c.id}.ours.$dest';
      File('$dir/$name').writeAsBytesSync(r.pk!.toFile());
      entry['ours'] = name;
    } else {
      stderr.writeln('${c.id}: bloqueado (${r.block})');
    }
    manifest.add(entry);
  }
  File('$dir/manifest.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
  stdout.writeln('${manifest.length} casos en $dir');
}

void _collect(String oraclePath, String fixturePath) {
  final cases = jsonDecode(File(oraclePath).readAsStringSync()) as List;
  final out = <Map<String, Object?>>[];
  for (final c in cases.cast<Map<String, dynamic>>()) {
    List<String> issues(Map<String, dynamic>? m) => [
          for (final i in (m?['legality']?['issues'] as List? ?? const []).cast<Map<String, dynamic>>())
            if (i['severity'] == 'Invalid') '${i['id']}:${i['code']}',
        ];
    final ours = c['ours'] as Map<String, dynamic>?;
    final pkhex = c['pkhex'] as Map<String, dynamic>?;
    out.add({
      'id': c['id'],
      'sourceLegal': c['source']['legality']['valid'],
      'pkhexResult': c['result'],
      'pkhexLegal': pkhex?['legality']['valid'],
      'oursLegal': ours?['legality']['valid'],
      'oursIssues': issues(ours),
      'pkhexIssues': issues(pkhex),
      if (ours != null)
        'ours': {
          for (final k in const ['species', 'form', 'level', 'ability', 'ball', 'metLocation', 'metLevel', 'version',
            'moves', 'nickname', 'ot', 'isNicknamed', 'heldItem', 'shiny'])
            k: ours[k],
        },
      if (pkhex != null)
        'pkhex': {
          for (final k in const ['species', 'form', 'level', 'ability', 'ball', 'metLocation', 'metLevel', 'version',
            'moves', 'nickname', 'ot', 'isNicknamed', 'heldItem', 'shiny'])
            k: pkhex[k],
        },
    });
  }
  File(fixturePath).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(out)}\n');
  final bad = out.where((c) => c['sourceLegal'] == true && c['oursLegal'] != true).map((c) => c['id']).toList();
  stdout.writeln('${out.length} casos; ilegales tras convertir (origen legal): ${bad.isEmpty ? 'ninguno' : bad.join(', ')}');
}
