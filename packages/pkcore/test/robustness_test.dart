import 'dart:math';
import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

const _team = [SynthMon(25, level: 30), SynthMon(133, level: 20)];
const _box = {
  0: [SynthMon(1, level: 5), null, SynthMon(4, level: 7)],
};

const _gcTeam = [SynthGcMon(25, level: 30), SynthGcMon(133, level: 20)];
const _gcBox = {
  0: [SynthGcMon(1, level: 5), null, SynthGcMon(4, level: 7)],
};

/// Un save sintético por cada uno de los 29 formatos (GameVersion).
final Map<GameVersion, Uint8List Function()> _fixtures = {
  GameVersion.redBlue: () => SyntheticSaves.gen1(party: _team),
  GameVersion.yellow: () => SyntheticSaves.gen1(party: _team, yellow: true),
  GameVersion.goldSilver: () => SyntheticSaves.gen2(party: _team),
  GameVersion.crystal: () => SyntheticSaves.gen2(crystal: true, party: _team),
  GameVersion.rubySapphire: () => SyntheticSaves.gen3(game: GameVersion.rubySapphire, party: _team, boxes: _box),
  GameVersion.emerald: () => SyntheticSaves.gen3(party: _team, boxes: _box),
  GameVersion.fireRedLeafGreen: () => SyntheticSaves.gen3(game: GameVersion.fireRedLeafGreen, party: _team, boxes: _box),
  GameVersion.colosseum: () => SyntheticSaves.gci(SyntheticSaves.colosseum(party: _gcTeam, boxes: _gcBox), GcTitle.colosseum),
  GameVersion.xd: () => SyntheticSaves.memoryCard([(GcTitle.xd, SyntheticSaves.xd(party: _gcTeam, boxes: _gcBox))]),
  GameVersion.boxRS: () => SyntheticSaves.gci(SyntheticSaves.rsBox(boxes: _box), GcTitle.rsBox),
  GameVersion.stadium: () => SyntheticSaves.stadium(boxes: const {0: _team}),
  GameVersion.stadium2: () => SyntheticSaves.stadium(layout: StadiumLayout.stadium2U, boxes: const {0: _team}, swapped: true),
  GameVersion.ranch: () => SyntheticSaves.ranch(mons: _team),
  GameVersion.battleRevolution: () => SyntheticSaves.battleRevolution(party: _team, boxes: _box),
  GameVersion.diamondPearl: () => SyntheticSaves.gen4(layout: Gen4Layout.dp, party: _team, boxes: _box),
  GameVersion.platinum: () => SyntheticSaves.gen4(party: _team, boxes: _box),
  GameVersion.heartGoldSoulSilver: () => SyntheticSaves.gen4(layout: Gen4Layout.hgss, party: _team, boxes: _box),
  GameVersion.blackWhite: () => SyntheticSaves.gen5(party: _team, boxes: _box),
  GameVersion.black2White2: () => SyntheticSaves.gen5(layout: Gen5Layout.b2w2, party: _team, boxes: _box),
  GameVersion.xy: () => SyntheticSaves.ctr(layout: CtrLayout.xy, party: _team, boxes: _box),
  GameVersion.omegaRubyAlphaSapphire: () => SyntheticSaves.ctr(party: _team, boxes: _box),
  GameVersion.sunMoon: () => SyntheticSaves.ctr(layout: CtrLayout.sm, party: _team, boxes: _box),
  GameVersion.ultraSunUltraMoon: () => SyntheticSaves.ctr(layout: CtrLayout.usum, party: _team, boxes: _box),
  GameVersion.letsGo: () => SyntheticSaves.letsGo(party: _team, boxes: _box),
  GameVersion.swordShield: () => SyntheticSaves.swordShield(party: _team, boxes: _box),
  GameVersion.brilliantDiamondShiningPearl: () => SyntheticSaves.bdsp(party: _team, boxes: _box),
  GameVersion.legendsArceus: () => SyntheticSaves.legendsArceus(party: _team, boxes: _box),
  GameVersion.scarletViolet: () => SyntheticSaves.scarletViolet(party: _team, boxes: _box),
  GameVersion.legendsZA: () => SyntheticSaves.legendsZA(party: _team, boxes: _box),
};

/// Resultado de procesar un archivo mutado: nunca un error no controlado.
enum _Outcome { rejected, readOnly, opened }

/// Abre [bytes] como lo haría la app y recorre todo lo que la interfaz lee.
/// Devuelve cómo terminó; cualquier excepción no controlada hace fallar el test.
_Outcome _exercise(Uint8List bytes) {
  try {
    SaveDetector.read(bytes);
  } on UnsupportedSaveException {
    // Puede seguir siendo abrible por el editor? No: ambos usan la misma detección.
  } on CorruptSaveException {
    // Detectado pero ilegible: el editor también debe rechazarlo o abrirlo en solo lectura.
  }
  final SaveEditor e;
  try {
    e = SaveEditor.open(bytes);
  } on UnsupportedSaveException {
    return _Outcome.rejected;
  } on CorruptSaveException {
    return _Outcome.rejected;
  }
  if (e.readOnly) {
    expect(() => e.set(const SlotRef.box(0, 0), null), throwsA(isA<SaveEditException>()));
    return _Outcome.readOnly;
  }
  // Lectura completa (lo que pintan las vistas).
  e.readTrainer();
  e.party;
  for (var b = 0; b < e.boxCount; b++) {
    for (var s = 0; s < e.boxSlotCount; s++) {
      e.get(SlotRef.box(b, s));
    }
  }
  e.readInventory();
  e.pokedex?.entries;
  e.events?.namedFlags(EventLanguage.es);
  for (final pk in e.party) {
    Legality.check(pk, e.game);
  }
  // Una edición y exportación: o se verifica bien o se rechaza, nunca un archivo inválido.
  try {
    e.writeTrainer(e.readTrainer().copyWith(money: 1234));
    final out = e.buildVerified();
    expect(SaveVerifier.checksums(out), isEmpty);
  } on SaveEditException {
    // Formato que no admite la edición: correcto.
  } on SaveVerificationException {
    // La verificación detectó el problema y no se entrega el archivo: correcto.
  }
  return _Outcome.opened;
}

final _totals = <_Outcome>[];

void main() {
  tearDownAll(() {
    // Resumen del fuzzing (visible con --reporter expanded).
    final byKind = {for (final o in _Outcome.values) o.name: _totals.where((x) => x == o).length};
    // ignore: avoid_print
    print('fuzzing: $byKind');
  });

  test('hay un save sintético para cada uno de los 29 formatos', () {
    expect(_fixtures.keys.toSet(), GameVersion.values.toSet());
    for (final MapEntry(key: game, value: build) in _fixtures.entries) {
      expect(SaveDetector.detect(build()).game, game);
    }
  });

  group('Exportación verificada', () {
    for (final MapEntry(key: game, value: build) in _fixtures.entries) {
      test('${game.nameEs}: editar, exportar y verificar (checksums + contenido)', () {
        final original = build();
        final e = SaveEditor.open(original);
        expect(e.integrityIssues, isEmpty);
        expect(SaveVerifier.checksums(original), isEmpty, reason: 'el sintético es válido');
        // Sin cambios también pasa la verificación.
        expect(e.buildVerified(), original);
        final first = e.partyCount > 0 ? e.party.first : e.get(const SlotRef.box(0, 0))!;
        if (e.canEditStorage) e.set(const SlotRef.box(0, 1), first);
        e.writeTrainer(e.readTrainer().copyWith(name: 'Ana', money: 4321));
        e.pokedex?.setCaught(e.pokedex!.species.first, true);
        if (e.events != null && e.events!.flagCount > 0) e.events!.setFlag(e.events!.flagCount - 1, true);
        final out = e.buildVerified();
        expect(SaveVerifier.checksums(out), isEmpty);
        expect(SaveVerifier.verifyExport(e, out), isEmpty);
        if (e.trainerFields.contains(TrainerField.money)) {
          expect(SaveEditor.open(out).readTrainer().money, e.maxMoney >= 4321 ? 4321 : e.maxMoney);
        }
      });
    }

    test('la verificación detecta un archivo dañado después de construirlo', () {
      final e = SaveEditor.open(SyntheticSaves.ctr(layout: CtrLayout.usum, party: _team));
      final out = e.build();
      out[0x1600 + 0x10] ^= 0xFF; // un byte del equipo sin recalcular el CRC
      expect(SaveVerifier.checksums(out), isNotEmpty);
      expect(SaveVerifier.verifyExport(e, out), isNotEmpty);
    });

    test('verificación de contenido: un cambio no aplicado se detecta', () {
      final original = SyntheticSaves.gen3(party: _team);
      final e = SaveEditor.open(original);
      e.writeTrainer(e.readTrainer().copyWith(money: 999));
      // El archivo original (sin el cambio) no coincide con el editor.
      expect(SaveVerifier.verifyExport(e, original), contains(contains('entrenador')));
    });
  });

  group('Fuzzing y mutaciones (nunca crashea, nunca escribe un save inválido)', () {
    for (final MapEntry(key: game, value: build) in _fixtures.entries) {
      test('${game.nameEs}: truncados, checksums rotos, bytes aleatorios y valores fuera de rango', () {
        final original = build();
        final outcomes = <_Outcome>[];
        // 1) Truncados (y vacío) y con bytes de más.
        for (final len in [0, 1, 0x100, original.length ~/ 2, original.length - 0x200, original.length - 1]) {
          if (len < 0 || len >= original.length) continue;
          outcomes.add(_exercise(Uint8List.sublistView(original, 0, len)));
        }
        outcomes.add(_exercise(Uint8List.fromList([...original, ...List.filled(3, 0xAB)])));

        // 2) Checksum / hash roto: el final del archivo y bytes de cabecera.
        for (final pos in [original.length - 1, original.length - 0x20, original.length - 0x1F0 + 6, 0x10]) {
          if (pos < 0) continue;
          final m = Uint8List.fromList(original)..[pos] ^= 0x5A;
          outcomes.add(_exercise(m));
        }

        // 3) Bytes aleatorios (semilla fija por juego para reproducibilidad).
        final rnd = Random(game.index * 7919 + 1);
        for (var k = 0; k < 12; k++) {
          final m = Uint8List.fromList(original);
          final flips = 1 + rnd.nextInt(64);
          for (var j = 0; j < flips; j++) {
            m[rnd.nextInt(m.length)] = rnd.nextInt(256);
          }
          outcomes.add(_exercise(m));
        }

        // 4) Valores fuera de rango en una copia que sigue siendo detectable:
        //    se editan los datos de trabajo del editor (sin tocar la detección).
        final e = SaveEditor.open(original);
        final ref = e.partyCount > 0 ? const SlotRef.party(0) : const SlotRef.box(0, 0);
        final pk = e.get(ref)!;
        pk.species = 0xFFF;
        pk.heldItem = 0xFFFF;
        pk.exp = 0x7FFFFFFF;
        pk.setMove(0, 0xFFFF, context: '9');
        try {
          e.set(ref, pk);
          final out = e.buildVerified();
          outcomes.add(_exercise(out));
        } on SaveEditException {
          // rechazado: correcto
        } on SaveVerificationException {
          // detectado al verificar: correcto
        }
        // Siempre se probaron casos y ninguno lanzó un error no controlado.
        expect(outcomes, isNotEmpty);
        expect(outcomes, contains(_Outcome.rejected), reason: 'los truncados se rechazan');
        _totals.addAll(outcomes);
      });
    }
  });
}
