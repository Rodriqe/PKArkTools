import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

const _team = [SynthMon(25, level: 30), SynthMon(6, level: 40)];

final _dexFixtures = <(String, Uint8List Function(), int, bool)>[
  ('RBY', () => SyntheticSaves.gen1(party: _team), 151, false),
  ('RBY japonés', () => SyntheticSaves.gen1Jp(party: _team), 151, false),
  ('Oro/Plata', () => SyntheticSaves.gen2(party: _team), 251, false),
  ('Cristal', () => SyntheticSaves.gen2(crystal: true, party: _team), 251, false),
  ('Oro/Plata coreano', () => SyntheticSaves.gen2(korean: true, trainer: const SynthTrainer(name: '골드'), party: _team), 251, false),
  ('Esmeralda', () => SyntheticSaves.gen3(party: _team), 386, false),
  ('Rubí/Zafiro', () => SyntheticSaves.gen3(game: GameVersion.rubySapphire, party: _team), 386, false),
  ('RFVH', () => SyntheticSaves.gen3(game: GameVersion.fireRedLeafGreen, party: _team), 386, false),
  ('Diamante/Perla', () => SyntheticSaves.gen4(layout: Gen4Layout.dp, party: _team), 493, false),
  ('Platino', () => SyntheticSaves.gen4(party: _team), 493, false),
  ('HGSS', () => SyntheticSaves.gen4(layout: Gen4Layout.hgss, party: _team), 493, false),
  ('Negro/Blanco', () => SyntheticSaves.gen5(party: _team), 649, true),
  ('Negro 2/Blanco 2', () => SyntheticSaves.gen5(layout: Gen5Layout.b2w2, party: _team), 649, true),
];

void main() {
  group('Pokédex', () {
    for (final (name, build, max, shiny) in _dexFixtures) {
      test('$name: editar especie, completar y limpiar con checksums válidos', () {
        final original = build();
        final e = SaveEditor.open(original);
        final dex = e.pokedex!;
        expect(dex.maxSpecies, max);
        expect(dex.hasShiny, shiny);

        PokedexEdit([const DexEntry(25, seen: true, caught: true), const DexEntry(6, seen: true)]).applyTo(e);
        var out = e.build();
        expect(SaveDetector.read(out).checksum, ChecksumStatus.valid);
        var re = SaveEditor.open(out).pokedex!;
        expect(re.entry(25), const DexEntry(25, seen: true, caught: true));
        expect(re.isSeen(6), isTrue);
        expect(re.isCaught(6), isFalse);
        expect(re.counts.seen, 2);

        const PokedexEdit.bulk(PokedexBulk.completeAllShiny).applyTo(e);
        out = e.build();
        expect(SaveDetector.read(out).checksum, ChecksumStatus.valid);
        re = SaveEditor.open(out).pokedex!;
        expect(re.counts.caught, max);
        expect(re.counts.seen, max);
        if (shiny) expect(re.counts.shiny, max);

        const PokedexEdit.bulk(PokedexBulk.clearAll).applyTo(e);
        re = SaveEditor.open(e.build()).pokedex!;
        expect(re.counts, (seen: 0, caught: 0, shiny: 0));
        // Sin cambios de Pokédex el resto del save sigue intacto.
        expect(SaveDetector.read(e.build()).party.length, 2);
      });
    }

    test('Gen 3: los tres registros de "visto" quedan sincronizados', () {
      final e = SaveEditor.open(SyntheticSaves.gen3(party: _team));
      e.pokedex!.setSeen(150, true);
      final out = e.build();
      final dex = SaveEditor.open(out).pokedex! as BitPokedex;
      expect(dex.isSeen(150), isTrue);
      for (final (buf, ofs) in dex.seenMirrors) {
        expect((buf[ofs + (149 >> 3)] >> (149 & 7)) & 1, 1);
      }
    });

    test('Gen 5: especie solo hembra usa el registro de hembra', () {
      final e = SaveEditor.open(SyntheticSaves.gen5(party: _team));
      final dex = e.pokedex! as BitPokedex;
      dex.setSeen(113, true); // Chansey
      expect((dex.data[dex.seenFemale! + (112 >> 3)] >> (112 & 7)) & 1, 1);
      expect((dex.data[dex.seen.first + (112 >> 3)] >> (112 & 7)) & 1, 0);
      expect(dex.isSeen(113), isTrue);
    });
  });

  group('Eventos', () {
    test('Esmeralda: flags con nombre y constantes', () {
      final e = SaveEditor.open(SyntheticSaves.gen3(party: _team));
      final ev = e.events!;
      expect(ev.flagCount, 2400);
      final named = ev.namedFlags(EventLanguage.es);
      expect(named, isNotEmpty);
      final badge = named.firstWhere((l) => l.text.contains('Medalla') || l.text.contains('Badge'));
      EventEdit(flags: {badge.index: true}, work: {0x46: 0x1234}).applyTo(e);
      final out = e.build();
      expect(SaveDetector.read(out).checksum, ChecksumStatus.valid);
      final re = SaveEditor.open(out).events!;
      expect(re.getFlag(badge.index), isTrue);
      expect(re.getWork(0x46), 0x1234);
      expect(re.flagName(badge.index, EventLanguage.en), isNotNull);
    });

    for (final (name, build, key) in <(String, Uint8List Function(), String?)>[
      ('RBY', () => SyntheticSaves.gen1(party: _team), null),
      ('Cristal', () => SyntheticSaves.gen2(crystal: true, party: _team), 'c'),
      ('Platino', () => SyntheticSaves.gen4(party: _team), 'pt'),
      ('HGSS', () => SyntheticSaves.gen4(layout: Gen4Layout.hgss, party: _team), 'hgss'),
      ('Negro 2/Blanco 2', () => SyntheticSaves.gen5(layout: Gen5Layout.b2w2, party: _team), 'b2w2'),
      ('X/Y', () => SyntheticSaves.ctr(layout: CtrLayout.xy, party: _team), 'xy'),
      ('Rubí Omega/Zafiro Alfa', () => SyntheticSaves.ctr(party: _team), 'oras'),
      ('Sol/Luna', () => SyntheticSaves.ctr(layout: CtrLayout.sm, party: _team), 'sm'),
      ('Ultrasol/Ultraluna', () => SyntheticSaves.ctr(layout: CtrLayout.usum, party: _team), 'usum'),
      ("Let's Go", () => SyntheticSaves.letsGo(party: _team), 'gg'),
      ('DBPR', () => SyntheticSaves.bdsp(party: _team), 'bdsp'),
    ]) {
      test('$name: alternar flag y releer', () {
        final e = SaveEditor.open(build());
        final ev = e.events!;
        expect(ev.labelKey, key);
        if (key != null) expect(ev.namedFlags(EventLanguage.es), isNotEmpty);
        EventEdit(flags: {7: true}).applyTo(e);
        if (ev.workCount > 0) EventEdit(work: {1: 9}).applyTo(e);
        final out = e.build();
        expect(SaveDetector.read(out).checksum, isNot(ChecksumStatus.invalid));
        final re = SaveEditor.open(out).events!;
        expect(re.getFlag(7), isTrue);
        if (ev.workCount > 0) expect(re.getWork(1), 9);
        // Un flag con nombre se puede activar y conserva su nombre al releer.
        if (key != null && ev.namedFlags(EventLanguage.es).isNotEmpty) {
          final named = ev.namedFlags(EventLanguage.es).first;
          final e2 = SaveEditor.open(out);
          EventEdit(flags: {named.index: !re.getFlag(named.index)}).applyTo(e2);
          final out2 = e2.build();
          expect(SaveDetector.read(out2).checksum, isNot(ChecksumStatus.invalid));
          expect(SaveEditor.open(out2).events!.getFlag(named.index), !re.getFlag(named.index));
          expect(SaveEditor.open(out2).events!.flagName(named.index, EventLanguage.es), named.text);
        }
        // Sin cambios: bytes idénticos.
        expect(SaveEditor.open(out).build(), out);
      });
    }

    test("Let's Go: etiquetas por zona convertidas a índice absoluto", () {
      final ev = SaveEditor.open(SyntheticSaves.letsGo()).events!;
      final snorlax = ev.namedFlags(EventLanguage.en).firstWhere((l) => l.text.contains('Snorlax'));
      expect(snorlax.index, 0x80 + 0x200 + 277); // v0277
      expect(ev.namedWork(EventLanguage.en), isNotEmpty);
    });

    test('Gen 8–9: flags = bloques booleanos con nombre si PKHeX lo conoce', () {
      final original = SyntheticSaves.scarletViolet(party: _team);
      final e = SaveEditor.open(original);
      final ev = e.events! as SwishEventStore;
      expect(ev.flagCount, 2);
      final i = [for (var i = 0; i < ev.flagCount; i++) i].firstWhere((i) => !ev.getFlag(i));
      ev.setFlag(i, true);
      final w = [for (var j = 0; j < ev.workCount; j++) j].firstWhere((j) => ev.workKey(j) == 0x4F35D0DD);
      expect(ev.workName(w, EventLanguage.es), isNotNull); // KMoney
      ev.setWork(w, 4242);
      final out = e.build();
      final re = SaveEditor.open(out).events! as SwishEventStore;
      expect(re.getFlag(i), isTrue);
      expect(re.getWork(w), 4242);
      expect(SaveEditor.open(out).readTrainer().money, 4242);
    });
  });
}
