import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

const _team = [SynthMon(25, level: 30), SynthMon(133, level: 20)];

/// (nombre, save, especie con formas, forma alternativa, especie solo hembra)
final _fixtures = <(String, Uint8List Function(), int, int)>[
  ('X/Y', () => SyntheticSaves.ctr(layout: CtrLayout.xy, party: _team), 666, 5),
  ('Rubí Omega/Zafiro Alfa', () => SyntheticSaves.ctr(party: _team), 382, 1),
  ('Sol/Luna', () => SyntheticSaves.ctr(layout: CtrLayout.sm, party: _team), 745, 1),
  ('Ultrasol/Ultraluna', () => SyntheticSaves.ctr(layout: CtrLayout.usum, party: _team), 800, 2),
  ("Let's Go", () => SyntheticSaves.letsGo(party: _team), 26, 1),
  ('Espada/Escudo', () => SyntheticSaves.swordShield(party: _team), 849, 1),
  ('DBPR', () => SyntheticSaves.bdsp(party: _team), 479, 3),
  ('Leyendas Arceus', () => SyntheticSaves.legendsArceus(party: _team), 422, 1),
  ('Escarlata/Púrpura', () => SyntheticSaves.scarletViolet(party: _team), 128, 1),
  ('Leyendas Z-A', () => SyntheticSaves.legendsZA(party: _team), 670, 2),
];

void main() {
  group('Pokédex Gen 6–9', () {
    for (final (name, build, formSpecies, altForm) in _fixtures) {
      test('$name: visto/capturado, género, variocolor y formas (round-trip)', () {
        final original = build();
        final e = SaveEditor.open(original);
        final dex = e.pokedex;
        expect(dex, isNotNull, reason: 'el juego tiene Pokédex');
        dex!;
        expect(dex.hasShiny && dex.hasGender && dex.hasForms, isTrue);
        // Sin cambios: bytes idénticos.
        expect(e.build(), original);
        expect(dex.counts, (seen: 0, caught: 0, shiny: 0));

        const pika = 25;
        expect(dex.contains(pika), isTrue, reason: 'Pikachu está en la Pokédex');
        expect(dex.contains(formSpecies), isTrue, reason: '#$formSpecies con formas');
        expect(dex.formCount(formSpecies), greaterThan(altForm), reason: 'formas de #$formSpecies');
        expect(dex.formAvailable(formSpecies, altForm), isTrue);

        PokedexEdit([
          const DexEntry(pika, seen: true, caught: true, genders: 3),
          DexEntry(formSpecies, seen: true, shiny: true, forms: (1 << altForm) | 1),
        ]).applyTo(e);
        final out = e.build();
        expect(SaveDetector.read(out).checksum, isNot(ChecksumStatus.invalid));
        expect(SaveDetector.read(out).party.length, 2, reason: 'el resto del save sigue intacto');

        final re = SaveEditor.open(out).pokedex!;
        expect(re.isSeen(pika), isTrue);
        expect(re.isCaught(pika), isTrue);
        expect(re.genderMask(pika), 3);
        expect(re.isShinySeen(pika), isFalse);
        expect(re.isSeen(formSpecies), isTrue);
        expect(re.isCaught(formSpecies), isFalse);
        expect(re.isShinySeen(formSpecies), isTrue);
        expect((re.formMask(formSpecies) >> altForm) & 1, 1, reason: 'forma $altForm vista');
        expect(re.counts.seen, 2);
        expect(re.counts.caught, 1);

        // Releer → escribir sin cambios = mismos bytes.
        final again = SaveEditor.open(out);
        again.pokedex!.apply(again.pokedex!.entry(pika));
        expect(again.build(), out);
      });

      test('$name: completar y limpiar', () {
        final e = SaveEditor.open(build());
        const PokedexEdit.bulk(PokedexBulk.completeAllShiny).applyTo(e);
        var out = e.build();
        expect(SaveDetector.read(out).checksum, isNot(ChecksumStatus.invalid));
        var dex = SaveEditor.open(out).pokedex!;
        final total = dex.species.length;
        expect(total, greaterThan(100));
        expect(dex.counts, (seen: total, caught: total, shiny: total));
        for (final s in dex.species.take(60)) {
          expect(dex.genderMask(s) & dex.allGenders(s), dex.allGenders(s), reason: 'géneros de #$s');
        }

        const PokedexEdit.bulk(PokedexBulk.clearAll).applyTo(e);
        out = e.build();
        dex = SaveEditor.open(out).pokedex!;
        expect(dex.counts, (seen: 0, caught: 0, shiny: 0));
        expect(SaveDetector.read(out).party.length, 2);
      });
    }

    test("Let's Go solo registra Kanto, Meltan y Melmetal", () {
      final dex = SaveEditor.open(SyntheticSaves.letsGo(party: _team)).pokedex!;
      expect(dex.species.length, 153);
      expect(dex.contains(152), isFalse);
      expect(dex.contains(809), isTrue);
    });

    test('Espada/Escudo: Pokédex regionales de Galar, Armadura y Corona', () {
      final dex = SaveEditor.open(SyntheticSaves.swordShield()).pokedex!;
      expect(dex.regions, ['galar', 'armor', 'crown']);
      expect(dex.regionalNumber(810), ('galar', 1)); // Grookey
      expect(dex.regionalNumber(891)?.$1, 'armor'); // Kubfu
      expect(dex.regionalNumber(898)?.$1, 'crown'); // Calyrex
      expect(dex.contains(1), isTrue); // Bulbasaur (Armadura)
      expect(dex.contains(152), isFalse); // Chikorita no está en Galar
    });

    test('Escarlata/Púrpura: Paldea, Kitakami y Arándano', () {
      final dex = SaveEditor.open(SyntheticSaves.scarletViolet()).pokedex!;
      expect(dex.regions, ['paldea', 'kitakami', 'blueberry']);
      expect(dex.regionalNumber(906), ('paldea', 1)); // Sprigatito
      expect(dex.regionalNumber(1011)?.$1, 'kitakami'); // Dipplin
      expect(dex.regionalNumber(1019)?.$1, 'blueberry'); // Hydrapple
    });

    test('Leyendas Arceus: Hisui, nivel de investigación y entradas por forma', () {
      final e = SaveEditor.open(SyntheticSaves.legendsArceus());
      final dex = e.pokedex!;
      expect(dex.regionalNumber(722), ('hisui', 1)); // Rowlet
      expect(dex.researchLevel(722), 0);
      dex.apply(const DexEntry(722, seen: true, caught: true));
      final re = SaveEditor.open(e.build()).pokedex!;
      expect(re.isCaught(722), isTrue);
      expect(re.researchLevel(722), 0, reason: 'la investigación no se toca');
    });

    test('Leyendas Z-A: Luminalia e Hiperespacio', () {
      final dex = SaveEditor.open(SyntheticSaves.legendsZA()).pokedex!;
      expect(dex.regionalNumber(152), ('lumiose', 1)); // Chikorita
      expect(dex.species.length, greaterThan(200));
    });

    test('BDSP: estado oído/visto/capturado y formas de Unown', () {
      final e = SaveEditor.open(SyntheticSaves.bdsp());
      final dex = e.pokedex!;
      expect(dex.maxSpecies, 493);
      expect(dex.formCount(201), 28);
      dex.apply(const DexEntry(201, seen: true, forms: 0x7));
      final re = SaveEditor.open(e.build()).pokedex!;
      expect(re.formMask(201), 0x7);
      expect(re.isCaught(201), isFalse);
    });
  });
}
