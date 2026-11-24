import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  group('Pokémon Box: Rubí y Zafiro', () {
    final box = SyntheticSaves.rsBox(
      boxes: const {
        0: [SynthMon(25, level: 20), null, SynthMon(252, level: 5, shiny: true)],
        1: [SynthMon(280, level: 12)],
        49: [SynthMon(384, level: 70)],
      },
      boxNames: const ['FAVS'],
    );

    test('lectura sin cabecera, en .gci y en Memory Card', () {
      for (final bytes in [
        box,
        SyntheticSaves.gci(box, GcTitle.rsBox),
        SyntheticSaves.memoryCard([(GcTitle.rsBox, box)], size: 0x400000),
      ]) {
        final s = SaveDetector.read(bytes);
        expect(s.game, GameVersion.boxRS);
        expect(s.versionId, 65);
        expect(s.checksum, ChecksumStatus.valid);
        expect(s.boxes.length, 50);
        expect(s.boxes[0].slots.map((p) => p?.species), [25, null, 252, ...List.filled(27, null)]);
        expect(s.boxes[0].slots[2]!.isShiny, isTrue);
        expect(s.boxes[1].slots.first!.species, 280);
        expect(s.boxes[49].slots.first!.species, 384);
        expect(s.boxes[0].name, startsWith('FAVS'));
        expect(s.party, isEmpty);
      }
    });

    test('round-trip y edición verificada', () {
      final g = SyntheticSaves.gci(box, GcTitle.rsBox);
      final ed = SaveEditor.open(g);
      expect(ed.readOnly, isFalse, reason: ed.integrityIssues.join('; '));
      expect(_same(ed.build(), g), isTrue);
      expect(_same(ed.buildRepaired(), g), isTrue);
      final pk = ed.get(const SlotRef.box(0, 0))!;
      pk.setNickname('ZAP');
      ed.set(const SlotRef.box(10, 5), pk);
      ed.set(const SlotRef.box(0, 2), null);
      ed.setBoxName(2, 'NEW');
      final out = ed.buildVerified();
      expect(out.sublist(0, 0x40), g.sublist(0, 0x40));
      final re = SaveEditor.open(out);
      expect(re.get(const SlotRef.box(10, 5))!.nickname, 'ZAP');
      expect(re.get(const SlotRef.box(0, 2)), isNull);
      expect(re.boxName(2), startsWith('NEW'));
      expect(re.boxName(3), startsWith('NEW'));
      expect(SaveVerifier.checksums(out), isEmpty);
      expect(() => re.set(const SlotRef.party(0), pk), throwsA(isA<SaveEditException>()));
    });

    test('una suma rota se detecta', () {
      final bad = Uint8List.fromList(box);
      bad[0x2000 + 23 * 0x2000 + 0x100] ^= 0xFF; // bloque de la copia activa
      expect(SaveDetector.read(bad).checksum, ChecksumStatus.invalid);
      expect(SaveEditor.open(bad).readOnly, isTrue);
    });
  });

  group('Pokémon Stadium y Stadium 2', () {
    for (final l in StadiumLayout.all) {
      for (final swapped in [false, true]) {
        test('${l.label}${swapped ? ' (bytes invertidos)' : ''}: lectura, round-trip y edición', () {
          final gen1 = l.generation == 1;
          final nick = l.japanese ? 'ピカ' : 'SPARK';
          final boxName = l.japanese ? 'ボックス' : 'FAVS';
          final bytes = SyntheticSaves.stadium(
            layout: l,
            swapped: swapped,
            boxes: {
              0: [SynthMon(gen1 ? 25 : 152, level: 30, nickname: nick), const SynthMon(1, level: 5), SynthMon(gen1 ? 150 : 249, level: 70, shiny: true)],
              1: const [SynthMon(4, level: 9)],
            },
            team: const [SynthMon(6, level: 50), SynthMon(9, level: 50)],
            boxNames: [boxName],
          );
          final s = SaveDetector.read(bytes);
          expect(s.game, gen1 ? GameVersion.stadium : GameVersion.stadium2);
          expect(s.checksum, ChecksumStatus.valid);
          expect(s.boxes.length, l.boxCount);
          expect(s.boxes[0].slots.take(4).map((p) => p?.species), [gen1 ? 25 : 152, 1, gen1 ? 150 : 249, null]);
          expect(s.boxes[0].slots.first!.nickname, nick);
          expect(s.boxes[0].slots[2]!.isShiny, isTrue);
          expect(s.warnings.single, contains('1'));
          if (!gen1) expect(s.boxes[0].name, boxName);

          final ed = SaveEditor.open(bytes) as StadiumEditor;
          expect(ed.readOnly, isFalse, reason: ed.integrityIssues.join('; '));
          expect(ed.swapped, swapped);
          expect(_same(ed.build(), bytes), isTrue);
          expect(ed.teams.first.$2.map((p) => p.species), [6, 9]);
          // Mover, borrar (compacta la lista) y añadir.
          final mew = ed.get(const SlotRef.box(0, 2))!;
          final list = l.countAt != null; // el Stadium japonés original no guarda contador
          ed.set(const SlotRef.box(0, 0), null);
          expect(ed.get(const SlotRef.box(0, 0))?.species, list ? 1 : null);
          ed.set(const SlotRef.box(2, 7), mew);
          final out = ed.buildVerified();
          final re = SaveEditor.open(out);
          expect(re.get(SlotRef.box(0, list ? 1 : 2))!.species, gen1 ? 150 : 249);
          final moved = re.get(SlotRef.box(2, list ? 0 : 7))!;
          expect(moved.species, gen1 ? 150 : 249, reason: 'en las listas con contador se compacta');
          expect(moved.isShiny, isTrue);
          expect(SaveDetector.read(out).checksum, ChecksumStatus.valid);
          if (swapped) expect(StadiumLayout.detect(out)!.$2, isTrue, reason: 'se conserva el orden de bytes');
        });
      }
    }
  });

  group('My Pokémon Ranch', () {
    for (final pt in [false, true]) {
      test('${pt ? 'Platino' : 'Diamante/Perla'}: lectura, round-trip y edición', () {
        final bytes = SyntheticSaves.ranch(
            platinum: pt, mons: const [SynthMon(25, level: 20), SynthMon(393, level: 5, shiny: true), SynthMon(448, level: 40)]);
        final s = SaveDetector.read(bytes);
        expect(s.game, GameVersion.ranch);
        expect(s.versionId, 200);
        expect(s.checksum, ChecksumStatus.valid);
        expect(s.trainer.name, 'HAYLEY');
        expect(s.trainer.playTime.inHours, 25);
        expect(s.boxes.length, 4, reason: 'nivel 8 = 100 huecos');
        expect(s.boxes.first.slots.take(4).map((p) => p?.species), [25, 393, 448, null]);
        expect(s.boxes.first.slots[1]!.isShiny, isTrue);

        final ed = SaveEditor.open(bytes) as RanchEditor;
        expect(ed.readOnly, isFalse, reason: ed.integrityIssues.join('; '));
        expect(_same(ed.build(), bytes), isTrue);
        expect(ed.isSlotLocked(const SlotRef.box(3, 10)), isTrue);
        expect(() => ed.set(const SlotRef.box(3, 10), ed.get(const SlotRef.box(0, 0))), throwsA(isA<SaveEditException>()));
        // Un Pokémon de Platino entra con Hayley como dueña.
        final pt4 = SaveEditor.open(SyntheticSaves.gen4(party: const [SynthMon(150, level: 70)])).get(const SlotRef.party(0))!;
        ed.set(const SlotRef.box(0, 3), pt4);
        ed.set(const SlotRef.box(0, 0), null);
        final out = ed.buildVerified();
        expect(RanchLayout.shaValid(out), isTrue);
        final re = SaveEditor.open(out) as RanchEditor;
        expect(re.get(const SlotRef.box(0, 3))!.species, 150);
        expect(re.get(const SlotRef.box(0, 3))!.nativeRaw![0x88], 4);
        expect(re.get(const SlotRef.box(0, 0)), isNull);
        expect(out.buffer.asByteData().getUint32(RanchLayout.countOffset(out)), 4);
      });
    }
  });
}
