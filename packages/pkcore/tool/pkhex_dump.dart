// Volcado de un save con pkcore en el mismo esquema JSON que el oráculo PKHeX
// (tools/pkhex_oracle). Lo usa tool/compare_with_pkhex.sh.
//
//   dart run tool/pkhex_dump.dart <save> [out.json]
//   dart run tool/pkhex_dump.dart --edit <in> <out>   (edición simple para el round-trip cruzado)
//
// Los volcados de saves reales contienen datos personales: guárdalos en .scratch/.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('uso: pkhex_dump.dart <save> [out.json] | --edit <in> <out>');
    exit(2);
  }
  if (args.first == '--edit') {
    _edit(args[1], args[2]);
    return;
  }
  final bytes = Uint8List.fromList(File(args[0]).readAsBytesSync());
  final json = const JsonEncoder.withIndent('  ').convert(dump(bytes));
  if (args.length > 1) {
    File(args[1]).writeAsStringSync(json);
  } else {
    stdout.writeln(json);
  }
}

/// Misma edición que `PkhexOracle edit`: dinero 123456 y, en el primer Pokémon
/// de la caja 1, +1 nivel y Placaje como cuarto movimiento.
void _edit(String input, String output) {
  final ed = SaveEditor.open(Uint8List.fromList(File(input).readAsBytesSync()));
  ed.writeTrainer(ed.readTrainer().copyWith(money: 123456));
  for (var s = 0; s < ed.boxSlotCount; s++) {
    final ref = SlotRef.box(0, s);
    final pk = ed.get(ref);
    if (pk == null) continue;
    ed.set(ref, pk.clone()
      ..level = (pk.level + 1).clamp(1, 100)
      ..setMove(3, 33));
    stdout.writeln('pkcore edit: dinero=123456, caja 1 hueco $s');
    break;
  }
  File(output).writeAsBytesSync(ed.buildVerified());
}

Map<String, Object?> dump(Uint8List bytes) {
  final save = SaveDetector.read(bytes);
  final ed = SaveEditor.open(bytes);
  final t = ed.readTrainer();
  final h = t.playTime.inHours, m = t.playTime.inMinutes % 60, s = t.playTime.inSeconds % 60;
  final slots = <Map<String, Object?>>[
    for (var i = 0; i < ed.partyCount; i++) _mon('party:$i', ed.party[i], ed.game),
    for (var b = 0; b < ed.boxCount; b++)
      for (var s = 0; s < ed.boxSlotCount; s++)
        if (ed.get(SlotRef.box(b, s)) case final pk?) _mon('box:$b:$s', pk, ed.game),
  ];
  final items = <int, int>{};
  for (final p in ed.readInventory() ?? const <InventoryPouch>[]) {
    for (final it in p.items) {
      if (it.item != 0 && it.count > 0) items[it.item] = (items[it.item] ?? 0) + it.count;
    }
  }
  final dex = ed.pokedex;
  return {
    'source': 'pkcore',
    'game': ed.game.name,
    'checksumsValid': save.checksum == ChecksumStatus.valid,
    'trainer': {
      'name': t.name,
      'tid16': t.tid,
      'sid16': t.sid,
      'money': t.money,
      'playTime': '$h:${'$m'.padLeft(2, '0')}:${'$s'.padLeft(2, '0')}',
      'badges': null, // pkcore no lee medallas
    },
    'slots': slots,
    'items': {for (final k in items.keys.toList()..sort()) '$k': items[k]},
    'pokedex': dex == null
        ? null
        : {
            'seen': [for (var sp = 1; sp <= dex.maxSpecies; sp++) if (dex.isSeen(sp)) sp],
            'caught': [for (var sp = 1; sp <= dex.maxSpecies; sp++) if (dex.isCaught(sp)) sp],
          },
  };
}

Map<String, Object?> _mon(String slot, Pkm pk, GameVersion game) {
  final issues = Legality.check(pk, game);
  return {
    'slot': slot,
    'species': pk.species,
    'form': pk.form,
    'nickname': pk.nickname,
    'isNicknamed': pk.isNicknamed,
    'level': pk.level,
    'exp': pk.exp,
    'pid': pk.pid,
    'ec': pk.encryptionConstant,
    'nature': pk.nature,
    'statNature': pk.statNature,
    'ability': pk.ability,
    'heldItem': pk.heldItem,
    'moves': pk.moves,
    'pp': [for (var i = 0; i < 4; i++) pk.pp(i)],
    'ppUps': [for (var i = 0; i < 4; i++) pk.ppUps(i)],
    'relearn': pk.hasRelearnMoves ? pk.relearnMoves : [0, 0, 0, 0],
    'ivs': pk.ivs,
    'evs': pk.evs,
    'shiny': pk.isShiny,
    'isEgg': pk.isEgg,
    'ball': pk.ball,
    'ot': pk.otName,
    'tid16': pk.tid,
    'sid16': pk.sid,
    'metLocation': pk.metLocation,
    'metLevel': pk.metLevel,
    'version': pk.version,
    'fateful': pk.fatefulEncounter,
    'checksumValid': pk.checksumValid,
    'shadowId': pk.gc?.shadowId,
    'purification': pk.gc?.purification,
    'isShadow': pk.gc?.isShadow,
    'legality': {
      'valid': issues.every((i) => i.severity != LegalitySeverity.warning),
      'issues': [
        for (final i in issues) {'id': i.field, 'code': i.code.name, 'severity': i.severity.name},
      ],
    },
  };
}
