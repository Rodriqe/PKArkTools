import 'package:pkcore/pkcore.dart';
import 'package:test/test.dart';

void main() {
  group('Species', () {
    test('nombres en español e inglés', () {
      expect(Species.name(25), 'Pikachu');
      expect(Species.name(1, SpeciesLanguage.en), 'Bulbasaur');
      expect(Species.name(1025, SpeciesLanguage.en), 'Pecharunt');
      expect(Species.name(0), '#0');
      expect(Species.name(5000), '#5000');
    });

    test('tipos de especie', () {
      expect(Species.types(6), (PokemonType.fire, PokemonType.flying));
      expect(Species.types(25).$1, PokemonType.electric);
    });

    test('nivel a partir de experiencia es inverso de expForLevel', () {
      for (final s in [1, 25, 129, 150, 373, 649, 813, 1007]) {
        for (final lv in [1, 2, 5, 17, 50, 99, 100]) {
          expect(Species.levelFromExp(s, Species.expForLevel(s, lv)), lv, reason: 'especie $s nivel $lv');
        }
      }
    });

    test('generación de debut', () {
      expect(Species.introducedIn(151), 1);
      expect(Species.introducedIn(152), 2);
      expect(Species.introducedIn(906), 9);
    });
  });

  group('SpeciesConvert', () {
    test('Gen 1: índice interno <-> nacional para las 151 especies', () {
      for (var s = 1; s <= 151; s++) {
        expect(SpeciesConvert.nationalFromGen1(SpeciesConvert.gen1FromNational(s)), s);
      }
      expect(SpeciesConvert.nationalFromGen1(0x99), 1); // Bulbasaur
      expect(SpeciesConvert.nationalFromGen1(0x54), 25); // Pikachu
    });

    test('Gen 3: índice interno <-> nacional para 1–386', () {
      for (var s = 1; s <= 386; s++) {
        expect(SpeciesConvert.nationalFromGen3(SpeciesConvert.gen3FromNational(s)), s);
      }
      expect(SpeciesConvert.gen3FromNational(252), 277); // Treecko
    });

    test('Gen 9: índice interno <-> nacional para 1–1025', () {
      for (var s = 1; s <= 1025; s++) {
        expect(SpeciesConvert.nationalFromGen9(SpeciesConvert.gen9FromNational(s)), s);
      }
    });
  });

  group('StringCodec', () {
    test('Gen 3 ida y vuelta', () {
      final enc = StringCodec.encodeG3('Brendan!', 10);
      expect(StringCodec.decodeG3(enc, 0, 10), 'Brendan!');
    });

    test('Gen 4 ida y vuelta', () {
      final enc = StringCodec.encodeG4('Lucas42', 16);
      expect(StringCodec.decodeG4(enc, 0, 16), 'Lucas42');
    });

    test('Game Boy ida y vuelta', () {
      final enc = StringCodec.encodeGb('RED', 11);
      expect(enc[3], 0x50);
      expect(StringCodec.decodeGb(enc, 0, 11), 'RED');
    });

    test('UTF-16 con acentos', () {
      final enc = StringCodec.encodeUtf16('Íñigo', 0x1A);
      expect(StringCodec.decodeUtf16(enc, 0, 0x1A), 'Íñigo');
    });
  });

  group('TrainerInfo', () {
    test('IDs de 5 dígitos (Gen 1–6)', () {
      const t = TrainerInfo(name: 'A', tid: 123, sid: 45, playTime: Duration.zero);
      expect(t.displayTid, '00123');
      expect(t.displaySid, '00045');
    });

    test('IDs de 6 dígitos (Gen 7+)', () {
      const t = TrainerInfo(name: 'A', tid: 0x5678, sid: 0x1234, playTime: Duration.zero, sixDigitIds: true);
      final id32 = 0x12345678;
      expect(t.displayTid, (id32 % 1000000).toString().padLeft(6, '0'));
      expect(t.displaySid, (id32 ~/ 1000000).toString().padLeft(4, '0'));
    });
  });
}
