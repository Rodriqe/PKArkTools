// Escribe saves sintéticos de Colosseum y XD (sin datos con copyright) para
// compararlos con el oráculo PKHeX y para las capturas.
//
//   dart run tool/write_synthetic.dart <carpeta>
//
// Genera: Colosseum.gci, XD.gci (PAL), Colosseum.bin / XD.bin (sin cabecera)
// MemoryCardA.raw (los dos juegos, con bloques no contiguos) y
// MemoryCardB.raw (solo XD, la que PKHeX abre sin preguntar).
import 'dart:io';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('uso: write_synthetic.dart <carpeta>');
    exit(2);
  }
  final dir = Directory(args.first)..createSync(recursive: true);
  final colo = SyntheticSaves.colosseumDemo();
  final xd = SyntheticSaves.xdDemo();
  final files = {
    'Colosseum.bin': colo,
    'XD.bin': xd,
    '01-GC6E-pokemon_colosseum.gci': SyntheticSaves.gci(colo, GcTitle.colosseum),
    '01-GXXP-pokemon_xd.gci': SyntheticSaves.gci(xd, GcTitle.xd, region: GcRegion.pal),
    'MemoryCardA.raw': SyntheticSaves.memoryCard([(GcTitle.colosseum, colo), (GcTitle.xd, xd)], scatter: true),
    'MemoryCardB.raw': SyntheticSaves.memoryCard([(GcTitle.xd, xd)]),
    '01-GPXE-pokemon_box.gci': SyntheticSaves.gci(
        SyntheticSaves.rsBox(boxes: const {
          0: [SynthMon(25, level: 20), null, SynthMon(252, level: 5, shiny: true)],
          1: [SynthMon(280, level: 12)],
          49: [SynthMon(384, level: 70)],
        }, boxNames: const ['FAVS']),
        GcTitle.rsBox),
  };
  for (final l in StadiumLayout.all) {
    final g1 = l.generation == 1;
    final name = l.label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    for (final swapped in [false, true]) {
      files['$name${swapped ? '_swap' : ''}.sav'] = SyntheticSaves.stadium(
        layout: l,
        swapped: swapped,
        boxes: {
          0: [SynthMon(g1 ? 25 : 152, level: 30), const SynthMon(1, level: 5), SynthMon(g1 ? 150 : 249, level: 70, shiny: true)],
          1: const [SynthMon(4, level: 9)],
        },
        team: const [SynthMon(6, level: 50), SynthMon(9, level: 50)],
      );
    }
  }
  for (final pt in [false, true]) {
    files['pokemonranch${pt ? '_pt' : ''}.bin'] = SyntheticSaves.ranch(
        platinum: pt, mons: const [SynthMon(25, level: 20), SynthMon(393, level: 5, shiny: true), SynthMon(448, level: 40)]);
  }
  files['PbrSaveData'] = SyntheticSaves.battleRevolution(
    party: const [SynthMon(448, level: 60, nickname: 'Lucky'), SynthMon(445, level: 62, shiny: true)],
    boxes: const {0: [SynthMon(25, level: 10), null, SynthMon(493, level: 80)], 17: [SynthMon(1, level: 5)]},
  );
  files.forEach((name, bytes) => File('${dir.path}/$name').writeAsBytesSync(bytes));
  stdout.writeln('${files.length} archivos en ${dir.path}');
}
