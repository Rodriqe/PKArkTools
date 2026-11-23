import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

const _party = [
  SynthMon(6, level: 50),
  SynthMon(25, level: 33, shiny: true, nickname: 'SPARKY'),
  SynthMon(143, level: 45),
];

void expectTrainer(SaveFile s, String name, int tid, {int? sid, Duration? time}) {
  expect(s.trainer.name, name);
  expect(s.trainer.tid, tid);
  if (sid != null) expect(s.trainer.sid, sid);
  if (time != null) expect(s.trainer.playTime, time);
}

void main() {
  group('Gen 1', () {
    test('Rojo/Azul: entrenador, equipo y cajas', () {
      final bytes = SyntheticSaves.gen1(
        trainer: const SynthTrainer(name: 'RED', tid: 1234, hours: 99, minutes: 59, seconds: 1),
        party: _party,
        boxes: {
          0: const [SynthMon(150, level: 70)],
          7: const [SynthMon(129, level: 5), SynthMon(130, level: 20, shiny: true)],
        },
      );
      final det = SaveDetector.detect(bytes);
      expect(det.game, GameVersion.redBlue);
      final s = det.read();
      expectTrainer(s, 'RED', 1234, time: const Duration(hours: 99, minutes: 59, seconds: 1));
      expect(s.checksum, ChecksumStatus.valid);
      expect(s.party.map((p) => p.species), [6, 25, 143]);
      expect(s.party[1].isShiny, isTrue);
      expect(s.party[1].nickname, 'SPARKY');
      expect(s.party[0].nickname, isNull);
      expect(s.party[0].level, 50);
      expect(s.boxes, hasLength(12));
      expect(s.boxes[0].slots.first?.species, 150);
      expect(s.boxes[7].slots[1]?.isShiny, isTrue);
      expect(s.boxedCount, 3);
    });

    test('Amarillo se distingue por el Pikachu inicial', () {
      final s = SaveDetector.read(SyntheticSaves.gen1(yellow: true, party: const [SynthMon(25, level: 5)]));
      expect(s.game, GameVersion.yellow);
    });

    test('checksum alterado se informa como inválido', () {
      final bytes = SyntheticSaves.gen1(party: _party);
      bytes[0x2600] ^= 0xFF;
      expect(SaveDetector.read(bytes).checksum, ChecksumStatus.invalid);
    });

    test('pie RTC de emulador se ignora', () {
      final s = SaveDetector.read(SyntheticSaves.withRtcFooter(SyntheticSaves.gen1(party: _party), 0x2C));
      expect(s.game, GameVersion.redBlue);
      expect(s.format, contains('RTC'));
      expect(s.raw.length, 0x8000 + 0x2C);
    });
  });

  group('Gen 2', () {
    test('Oro/Plata internacional', () {
      final s = SaveDetector.read(SyntheticSaves.gen2(
        trainer: const SynthTrainer(name: 'GOLD', tid: 4321, hours: 300, minutes: 1, seconds: 2),
        party: const [SynthMon(155, level: 12), SynthMon(16, egg: true, level: 1)],
        boxes: {
          0: const [SynthMon(249, level: 45)],
          9: const [SynthMon(250, level: 45, shiny: true)],
        },
      ));
      expect(s.game, GameVersion.goldSilver);
      expectTrainer(s, 'GOLD', 4321, time: const Duration(hours: 300, minutes: 1, seconds: 2));
      expect(s.checksum, ChecksumStatus.valid);
      expect(s.party, hasLength(2));
      expect(s.party[1].isEgg, isTrue);
      expect(s.boxes, hasLength(14));
      expect(s.boxes[0].name, 'BOX1');
      expect(s.boxes[9].slots.first?.species, 250);
      expect(s.boxes[9].slots.first?.isShiny, isTrue);
    });

    test('Cristal con género del entrenador', () {
      final s = SaveDetector.read(SyntheticSaves.gen2(
        crystal: true,
        trainer: const SynthTrainer(name: 'KRIS', tid: 1, gender: 1),
        party: const [SynthMon(158, level: 5)],
      ));
      expect(s.game, GameVersion.crystal);
      expect(s.trainer.gender, 1);
      expect(s.party.single.species, 158);
    });
  });

  group('Gen 3', () {
    for (final game in [GameVersion.rubySapphire, GameVersion.emerald, GameVersion.fireRedLeafGreen]) {
      test('${game.code}: lectura completa', () {
        final bytes = SyntheticSaves.gen3(
          game: game,
          trainer: const SynthTrainer(name: 'MAY', tid: 31415, sid: 9265, gender: 1, hours: 48, minutes: 7, seconds: 9),
          party: const [
            SynthMon(254, level: 52, nickname: 'LEAFY'),
            SynthMon(282, level: 49, shiny: true),
            SynthMon(384, level: 70),
          ],
          boxes: {
            0: const [SynthMon(25, level: 22), null, SynthMon(359, level: 33, shiny: true)],
            13: const [SynthMon(386, level: 30)],
          },
          boxNames: const ['FAVS'],
        );
        final det = SaveDetector.detect(bytes);
        expect(det.game, game);
        final s = det.read();
        expectTrainer(s, 'MAY', 31415, sid: 9265, time: const Duration(hours: 48, minutes: 7, seconds: 9));
        expect(s.trainer.gender, 1);
        expect(s.checksum, ChecksumStatus.valid);
        expect(s.support.party && s.support.boxes, isTrue);
        expect(s.party.map((p) => p.species), [254, 282, 384]);
        expect(s.party[0].nickname, 'LEAFY');
        expect(s.party[1].nickname, isNull);
        expect(s.party[1].isShiny, isTrue);
        expect(s.party[2].isShiny, isFalse);
        expect(s.party.map((p) => p.level), [52, 49, 70]);
        expect(s.boxes, hasLength(14));
        expect(s.boxes[0].name, 'FAVS');
        expect(s.boxes[1].name, 'BOX 2');
        expect(s.boxes[0].slots[0]?.species, 25);
        expect(s.boxes[0].slots[0]?.level, 22); // nivel calculado por experiencia
        expect(s.boxes[0].slots[1], isNull);
        expect(s.boxes[0].slots[2]?.isShiny, isTrue);
        expect(s.boxes[13].slots[0]?.species, 386);
        expect(s.boxedCount, 3);
      });
    }

    test('usa la ranura con mayor contador de guardado', () {
      final bytes = SyntheticSaves.gen3(trainer: const SynthTrainer(name: 'NEW'), party: _party);
      // Corromper el nombre en la ranura 0 (antigua) no debe afectar.
      bytes[0x0000] = 0xBB;
      final s = SaveDetector.read(bytes);
      expect(s.trainer.name, 'NEW');
    });

    test('un sector dañado se reporta como checksum inválido', () {
      final bytes = SyntheticSaves.gen3(party: _party);
      bytes[0xE000 + 0x500] ^= 0x55;
      expect(SaveDetector.read(bytes).checksum, ChecksumStatus.invalid);
    });

    test('save de 128 KB vacío (0xFF) no se reconoce', () {
      final blank = Uint8List(0x20000)..fillRange(0, 0x20000, 0xFF);
      expect(
        () => SaveDetector.detect(blank),
        throwsA(isA<UnsupportedSaveException>().having((e) => e.message, 'message', contains('GBA'))),
      );
    });
  });

  group('Gen 4', () {
    for (final l in Gen4Layout.all) {
      test('${l.game.code}: entrenador, equipo y cajas', () {
        final bytes = SyntheticSaves.gen4(
          layout: l,
          trainer: const SynthTrainer(name: 'Lucas', tid: 777, sid: 888, hours: 12, minutes: 3, seconds: 4),
          party: const [SynthMon(387, level: 10), SynthMon(493, level: 80, shiny: true, nickname: 'Dios')],
          boxes: {
            0: const [SynthMon(25, level: 30)],
            17: const [null, SynthMon(483, level: 47)],
          },
        );
        final s = SaveDetector.read(bytes);
        expect(s.game, l.game);
        expectTrainer(s, 'Lucas', 777, sid: 888, time: const Duration(hours: 12, minutes: 3, seconds: 4));
        expect(s.checksum, ChecksumStatus.valid);
        expect(s.party.map((p) => p.species), [387, 493]);
        expect(s.party[1].nickname, 'Dios');
        expect(s.party[1].isShiny, isTrue);
        expect(s.boxes, hasLength(18));
        expect(s.boxes[0].slots[0]?.level, 30);
        expect(s.boxes[17].slots[1]?.species, 483);
      });
    }

    test('.dsv de DeSmuME', () {
      final s = SaveDetector.read(SyntheticSaves.withDesmumeFooter(SyntheticSaves.gen4(layout: Gen4Layout.hgss)));
      expect(s.game, GameVersion.heartGoldSoulSilver);
      expect(s.format, contains('DeSmuME'));
    });
  });

  group('Gen 5', () {
    for (final l in Gen5Layout.all) {
      test('${l.game.code}: entrenador y equipo', () {
        final s = SaveDetector.read(SyntheticSaves.gen5(
          layout: l,
          trainer: SynthTrainer(name: 'Hilda', tid: 11111, sid: 22222, versionId: l == Gen5Layout.bw ? 20 : 23),
          party: const [SynthMon(495, level: 7), SynthMon(643, level: 50, shiny: true)],
          boxes: {
            23: const [SynthMon(649, level: 15)],
          },
        ));
        expect(s.game, l.game);
        expectTrainer(s, 'Hilda', 11111, sid: 22222);
        expect(s.titleEs, l == Gen5Layout.bw ? 'Pokémon Blanco' : 'Pokémon Negro 2');
        expect(s.party.map((p) => p.species), [495, 643]);
        expect(s.party[1].isShiny, isTrue);
        expect(s.boxes[23].slots.first?.species, 649);
      });
    }
  });

  group('Gen 6 / 7 (3DS)', () {
    for (final l in CtrLayout.all) {
      test('${l.game.code}: entrenador, equipo y cajas', () {
        final s = SaveDetector.read(SyntheticSaves.ctr(
          layout: l,
          trainer: const SynthTrainer(name: 'Serena', tid: 0x1234, sid: 0x00AB, hours: 5, minutes: 6, seconds: 7),
          party: const [SynthMon(658, level: 36, shiny: true), SynthMon(700, level: 40, nickname: 'Lazo')],
          boxes: {
            2: const [SynthMon(716, level: 50)],
          },
        ));
        expect(s.game, l.game);
        expectTrainer(s, 'Serena', 0x1234, sid: 0x00AB, time: const Duration(hours: 5, minutes: 6, seconds: 7));
        expect(s.trainer.sixDigitIds, l.game.generation == 7);
        expect(s.party.map((p) => p.species), [658, 700]);
        expect(s.party[0].isShiny, isTrue);
        expect(s.party[1].nickname, 'Lazo');
        expect(s.boxes, hasLength(l.boxCount));
        expect(s.boxes[2].slots.first?.species, 716);
        expect(s.boxes[2].slots.first?.level, 50);
      });
    }
  });

  group('Switch (SwishCrypto)', () {
    test('Espada/Escudo: lectura completa', () {
      final bytes = SyntheticSaves.swordShield(
        trainer: const SynthTrainer(name: 'Gloria', tid: 0xA1B2, sid: 0x0C3D, gender: 1, hours: 210, minutes: 5, seconds: 6, versionId: 45),
        party: const [SynthMon(818, level: 65), SynthMon(887, level: 63, shiny: true), SynthMon(884, level: 60, nickname: 'Acerito')],
        boxes: {
          0: const [SynthMon(810, level: 12), null, SynthMon(890, level: 60, shiny: true)],
          31: const [SynthMon(898, level: 75)],
        },
        boxNames: const ['Galar'],
      );
      expect(SwishCrypto.isHashValid(bytes), isTrue);
      final det = SaveDetector.detect(bytes);
      expect(det.game, GameVersion.swordShield);
      final s = det.read();
      expect(s.titleEs, 'Pokémon Escudo');
      expectTrainer(s, 'Gloria', 0xA1B2, sid: 0x0C3D, time: const Duration(hours: 210, minutes: 5, seconds: 6));
      expect(s.trainer.sixDigitIds, isTrue);
      expect(s.party.map((p) => p.species), [818, 887, 884]);
      expect(s.party[1].isShiny, isTrue);
      expect(s.party[2].nickname, 'Acerito');
      expect(s.boxes, hasLength(32));
      expect(s.boxes[0].name, 'Galar');
      expect(s.boxes[0].slots[2]?.species, 890);
      expect(s.boxes[0].slots[2]?.isShiny, isTrue);
      expect(s.boxes[31].slots[0]?.species, 898);
      expect(s.format, contains('SwishCrypto'));
    });

    test('Escarlata/Púrpura: convierte especies internas de Gen 9', () {
      final s = SaveDetector.read(SyntheticSaves.scarletViolet(
        trainer: const SynthTrainer(name: 'Juliana', tid: 0x5F10, sid: 0x2A77, hours: 96, minutes: 41, seconds: 3, versionId: 51),
        party: const [SynthMon(906, level: 5), SynthMon(1007, level: 72), SynthMon(25, level: 50, shiny: true)],
        boxes: {
          1: const [SynthMon(1024, level: 85), SynthMon(983, level: 58, nickname: 'Rey')],
        },
      ));
      expect(s.game, GameVersion.scarletViolet);
      expect(s.titleEs, 'Pokémon Púrpura');
      expectTrainer(s, 'Juliana', 0x5F10, sid: 0x2A77, time: const Duration(hours: 96, minutes: 41, seconds: 3));
      expect(s.party.map((p) => p.species), [906, 1007, 25]);
      expect(s.party[2].isShiny, isTrue);
      expect(s.boxes[1].slots.map((p) => p?.species).take(2), [1024, 983]);
      expect(s.boxes[1].slots[1]?.nickname, 'Rey');
    });

    test('Leyendas Arceus: metadatos del entrenador', () {
      final s = SaveDetector.read(SyntheticSaves.legendsArceus(
          trainer: const SynthTrainer(name: 'Akari', tid: 100, sid: 200, hours: 40)));
      expect(s.game, GameVersion.legendsArceus);
      expectTrainer(s, 'Akari', 100, sid: 200);
      expect(s.trainer.playTime.inHours, 40);
      expect(s.support.party, isTrue);
    });

    test('Leyendas Z-A: metadatos del entrenador', () {
      final s = SaveDetector.read(SyntheticSaves.legendsZA(
          trainer: const SynthTrainer(name: 'Urbain', tid: 9, sid: 8, hours: 3, minutes: 2, seconds: 1)));
      expect(s.game, GameVersion.legendsZA);
      expectTrainer(s, 'Urbain', 9, sid: 8, time: const Duration(hours: 3, minutes: 2, seconds: 1));
    });

    test("Let's Go: metadatos del entrenador", () {
      final s = SaveDetector.read(SyntheticSaves.letsGo(trainer: const SynthTrainer(name: 'Chase', tid: 5, versionId: 43)));
      expect(s.game, GameVersion.letsGo);
      expect(s.titleEs, "Pokémon Let's Go, Eevee!");
      expect(s.trainer.name, 'Chase');
    });

    test('BDSP: metadatos del entrenador', () {
      final s = SaveDetector.read(SyntheticSaves.bdsp(
          trainer: const SynthTrainer(name: 'Dawn', tid: 42, sid: 24, gender: 1, hours: 7)));
      expect(s.game, GameVersion.brilliantDiamondShiningPearl);
      expectTrainer(s, 'Dawn', 42, sid: 24);
      expect(s.trainer.gender, 1);
    });

    test('hash alterado: error claro', () {
      final bytes = SyntheticSaves.swordShield(party: _party);
      final big = Uint8List(0x180000)..setRange(0, bytes.length, bytes);
      expect(
        () => SaveDetector.detect(big),
        throwsA(isA<UnsupportedSaveException>().having((e) => e.message, 'message', contains('SwishCrypto'))),
      );
    });
  });

  group('Errores', () {
    test('archivo vacío', () {
      expect(() => SaveDetector.detect(Uint8List(0)), throwsA(isA<UnsupportedSaveException>()));
    });

    test('tamaño desconocido', () {
      expect(
        () => SaveDetector.detect(Uint8List(12345)),
        throwsA(isA<UnsupportedSaveException>().having((e) => e.message, 'message', contains('No se reconoce'))),
      );
    });

    test('512 KB sin pies de bloque válidos', () {
      expect(
        () => SaveDetector.detect(Uint8List(0x80000)),
        throwsA(isA<UnsupportedSaveException>().having((e) => e.message, 'message', contains('NDS'))),
      );
    });
  });

  group('Conjunto de demostración', () {
    test('todos los saves de demo se detectan y leen', () {
      final demo = SyntheticSaves.demoSet();
      expect(demo, isNotEmpty);
      for (final MapEntry(:key, :value) in demo.entries) {
        final s = SaveDetector.read(value);
        expect(s.trainer.name, isNotEmpty, reason: key);
      }
    });

    test('identityKey agrupa por juego y entrenador', () {
      final a = SaveDetector.read(SyntheticSaves.gen3(party: _party));
      final b = SaveDetector.read(SyntheticSaves.gen3(party: const [SynthMon(1)]));
      final c = SaveDetector.read(SyntheticSaves.gen3(trainer: const SynthTrainer(name: 'OTRO')));
      expect(a.identityKey, b.identityKey);
      expect(a.identityKey, isNot(c.identityKey));
    });
  });
}
