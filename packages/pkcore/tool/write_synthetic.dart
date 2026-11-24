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
  files.forEach((name, bytes) => File('${dir.path}/$name').writeAsBytesSync(bytes));
  stdout.writeln('${files.length} archivos en ${dir.path}');
}
