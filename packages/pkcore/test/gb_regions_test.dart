import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/src/edit/gb_editors.dart' show koreanChecksum;
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

const _team = [SynthMon(152, level: 12), SynthMon(25, level: 30)];

void _commonChecks(
  String name,
  Uint8List Function() build, {
  required GameVersion game,
  required String trainer,
  int first = 152,
}) {
  group(name, () {
    test('detecta, lee entrenador/equipo y round-trip byte a byte', () {
      final original = build();
      final save = SaveDetector.read(original);
      expect(save.game, game);
      expect(save.trainer.name, trainer);
      expect(save.checksum, ChecksumStatus.valid);
      expect(save.party.map((p) => p.species), [first, 25]);
      final e = SaveEditor.open(original);
      expect(e.canEditStorage, isTrue);
      expect(e.build(), original);
    });

    test('editar Pokémon, cajas, entrenador e inventario', () {
      final original = build();
      final e = SaveEditor.open(original);
      final pk = e.get(const SlotRef.party(1))!;
      pk.level = 55;
      e.set(const SlotRef.party(1), pk);
      e.set(const SlotRef.box(2, 0), e.get(const SlotRef.party(0)));
      final t = e.readTrainer();
      e.writeTrainer(t.copyWith(money: 4321, tid: 777));
      final inv = e.readInventory()!;
      final items = inv.first;
      e.writeInventory([
        items.withItems([InventoryItem(items.legalItems.first, 9)]),
        ...inv.skip(1),
      ]);
      final out = e.build();
      final save = SaveDetector.read(out);
      expect(save.checksum, ChecksumStatus.valid);
      expect(save.party[1].level, 55);
      expect(save.boxes[2].slots.first?.species, first);
      expect(save.trainer.tid, 777);
      final re = SaveEditor.open(out);
      expect(re.readTrainer().money, 4321);
      expect(re.readTrainer().name, trainer);
      expect(re.readInventory()!.first.items.single.count, 9);
      expect(re.get(const SlotRef.party(1))!.nickname, pk.nickname);
    });
  });
}

void main() {
  _commonChecks(
    'Gen 1 internacional',
    () => SyntheticSaves.gen1(party: _gbTeam),
    game: GameVersion.redBlue,
    trainer: 'RED',
    first: 1,
  );
  _commonChecks(
    'Gen 1 japonés',
    () => SyntheticSaves.gen1Jp(party: _gbTeam),
    game: GameVersion.redBlue,
    trainer: 'サトシ',
    first: 1,
  );
  _commonChecks(
    'Gen 2 internacional',
    () => SyntheticSaves.gen2(party: _team),
    game: GameVersion.goldSilver,
    trainer: 'GOLD',
  );
  _commonChecks(
    'Gen 2 japonés',
    () => SyntheticSaves.gen2Jp(party: _team),
    game: GameVersion.goldSilver,
    trainer: 'ヒビキ',
  );
  _commonChecks(
    'Cristal japonés',
    () => SyntheticSaves.gen2Jp(crystal: true, party: _team),
    game: GameVersion.crystal,
    trainer: 'ヒビキ',
  );
  _commonChecks(
    'Gen 2 coreano',
    () => SyntheticSaves.gen2(
      korean: true,
      trainer: const SynthTrainer(name: '골드'),
      party: const [
        SynthMon(152, level: 12, nickname: '치코리타'),
        SynthMon(25, level: 30, nickname: '피카츄'),
      ],
    ),
    game: GameVersion.goldSilver,
    trainer: '골드',
  );

  group('Gen 2 coreano: detalles', () {
    Uint8List kor() => SyntheticSaves.gen2(
      korean: true,
      trainer: const SynthTrainer(name: '골드'),
      party: const [SynthMon(25, nickname: '피카츄')],
    );

    test('codec coreano: ida y vuelta de hangul', () {
      final enc = StringCodec.encodeGb('피카츄', 11, korean: true);
      expect(enc[0], inInclusiveRange(1, 11)); // página de 2 bytes
      expect(StringCodec.decodeGb(enc, 0, 11, korean: true), '피카츄');
    });

    test('apodos en hangul y checksum secundario coreano', () {
      final e = SaveEditor.open(kor());
      expect(e.get(const SlotRef.party(0))!.nickname, '피카츄');
      expect(e.get(const SlotRef.party(0))!.language, 8);
      e.writeTrainer(e.readTrainer().copyWith(name: '실버'));
      final out = e.build();
      expect(out[0x7E6B] | (out[0x7E6C] << 8), koreanChecksum(out));
      expect(SaveDetector.read(out).trainer.name, '실버');
    });

    test('exportar/importar .pk2 coreano conserva el apodo', () {
      final pk = SaveEditor.open(kor()).get(const SlotRef.party(0))!;
      final back = Pkm.fromFile(PkFormat.pk2, pk.toFile())!;
      expect(back.korean, isTrue);
      expect(back.nickname, '피카츄');
    });
  });
}

const _gbTeam = [SynthMon(1, level: 12), SynthMon(25, level: 30)];
