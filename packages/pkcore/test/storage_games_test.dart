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
}
