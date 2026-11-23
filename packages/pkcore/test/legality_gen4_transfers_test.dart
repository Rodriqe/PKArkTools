import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

/// Falsos positivos de legalidad hallados con un save real de SoulSilver
/// (Pokémon de Pal Park, movimientos heredados, tutores, errantes y regalos).
const _hgss = GameVersion.heartGoldSoulSilver;

Pkm _pk4(int species, {int level = 30, int version = 7, int metLocation = 55, int? metLevel, List<int> moves = const []}) {
  final raw = SyntheticSaves.gen4(layout: Gen4Layout.hgss, party: [SynthMon(species, level: level)]);
  final pk = SaveEditor.open(raw).get(const SlotRef.party(0))!
    ..version = version
    ..metLocation = metLocation
    ..metLevel = metLevel ?? level
    ..ball = 4;
  pk.data[0x40] &= ~1; // sin encuentro fatídico
  pk.data.setRange(0x44, 0x46, [0, 0]); // sin lugar de huevo
  pk.data.setRange(0x7E, 0x80, [0, 0]);
  for (var i = 0; i < 4; i++) {
    pk.setMove(i, i < moves.length ? moves[i] : 0, context: '4');
  }
  return pk..refreshChecksum();
}

Set<LegalityCode> _codes(Pkm pk) => {for (final i in Legality.check(pk, _hgss)) i.code};

void main() {
  group('Pal Park (origen Gen 3 en un PK4)', () {
    test('el lugar (Pal Park) y el nivel de encuentro sobrescritos no generan avisos de encuentro', () {
      for (final (species, version) in [(1, 4), (10, 4), (41, 1), (25, 5), (37, 3), (169, 1)]) {
        final pk = _pk4(species, level: 29, version: version, metLocation: 55, moves: const [33]);
        final codes = _codes(pk);
        expect(codes.intersection({
          LegalityCode.encounterNotInGame,
          LegalityCode.encounterWrongLocation,
          LegalityCode.encounterWrongLevel,
        }), isEmpty, reason: '#$species desde versión $version');
      }
    });

    test('un Pokémon nativo de Gen 4 sí se sigue comprobando', () {
      // Geodude de HeartGold "encontrado" en Pal Park (lugar que no es de HGSS).
      final pk = _pk4(74, version: 7, metLocation: 55, moves: const [33]);
      expect(_codes(pk), contains(LegalityCode.encounterWrongLocation));
    });

    test('MT de Gen 3 aprendidas antes del traspaso (Charizard con Garra Dragón, MT02 de Gen 3)', () {
      expect(GameDataTable.forGame(GameVersion.fireRedLeafGreen).machineMoves(6), contains(337));
      expect(GameDataTable.forGame(GameVersion.fireRedLeafGreen).machineMoves(6), isNotEmpty);
      final pk = _pk4(6, level: 40, version: 4, moves: const [53, 337]);
      expect(_codes(pk), isNot(contains(LegalityCode.moveNotLearnable)));
    });

    test('huevos regalo de Pokémon Box: Skitty con Día de Pago y Altaria con Falso Tortazo', () {
      expect(_codes(_pk4(301, level: 5, version: 3, moves: const [47, 6])), isNot(contains(LegalityCode.moveNotLearnable)));
      expect(_codes(_pk4(334, level: 35, version: 2, moves: const [206, 225])), isNot(contains(LegalityCode.moveNotLearnable)));
      // Sin origen Gen 3, Día de Pago en Skitty no tiene explicación.
      expect(_codes(_pk4(300, level: 5, version: 7, metLocation: 149, moves: const [6])), contains(LegalityCode.moveNotLearnable));
    });
  });

  group('movimientos', () {
    test('movimientos de la preevolución (Metapod/Butterfree con Placaje y Disparo Demora)', () {
      expect(_codes(_pk4(11, level: 7, moves: const [106, 33, 81])), isNot(contains(LegalityCode.moveNotLearnable)));
      expect(_codes(_pk4(12, level: 10, moves: const [93, 106, 33, 81])), isNot(contains(LegalityCode.moveNotLearnable)));
      expect(_codes(_pk4(11, level: 7, moves: const [57])), contains(LegalityCode.moveNotLearnable), reason: 'Surf');
    });

    test('tutores de Platino/HGSS (Typhlosion con Onda Ígnea, Crobat con Cabezazo Zen)', () {
      expect(GameDataTable.forGame(_hgss).tutorMoves(157), contains(257));
      expect(_codes(_pk4(157, level: 100, version: 7, moves: const [257])), isNot(contains(LegalityCode.moveNotLearnable)));
      expect(_codes(_pk4(169, level: 100, version: 7, moves: const [428])), isNot(contains(LegalityCode.moveNotLearnable)));
    });

    test('Shedinja conserva lo que Ninjask aprende al evolucionar (Chirrido)', () {
      expect(_codes(_pk4(292, level: 20, version: 7, moves: const [104, 210, 103])),
          isNot(contains(LegalityCode.moveNotLearnable)));
    });

    test('los Pokémon de evento (encuentro fatídico) no se marcan por movimientos especiales', () {
      final pk = _pk4(493, level: 100, version: 10, metLocation: 3060, moves: const [449, 460])..data[0x40] |= 1;
      expect(_codes(pk..refreshChecksum()), isNot(contains(LegalityCode.moveNotLearnable)));
    });
  });

  group('encuentros y eventos', () {
    test('errantes (Mesprit y Cresselia en Platino) aceptan cualquier ruta', () {
      for (final species in [481, 488]) {
        final pk = _pk4(species, level: 50, version: 12, metLocation: 17, metLevel: 50, moves: const [93]);
        expect(_codes(pk).intersection({LegalityCode.encounterWrongLocation, LegalityCode.encounterNotInGame}), isEmpty);
      }
      // El nivel sí se comprueba.
      final low = _pk4(481, level: 50, version: 12, metLocation: 17, metLevel: 20, moves: const [93]);
      expect(_codes(low), contains(LegalityCode.encounterWrongLevel));
    });

    test('Phione criado y Darkrai de Platino no requieren encuentro fatídico; Darkrai de Diamante sí', () {
      expect(_codes(_pk4(489, level: 1, version: 7, metLocation: 2000, moves: const [145])),
          isNot(contains(LegalityCode.eventSpeciesNotFateful)));
      expect(_codes(_pk4(491, level: 50, version: 12, metLocation: 79, moves: const [95])),
          isNot(contains(LegalityCode.eventSpeciesNotFateful)));
      expect(_codes(_pk4(491, level: 50, version: 10, metLocation: 79, moves: const [95])),
          contains(LegalityCode.eventSpeciesNotFateful));
    });
  });

  test('nombres de objetos de Gen 4: Cartas y MO07/MO08', () {
    expect(GameStrings.item(137, 4), 'Carta Hierba');
    expect(GameStrings.item(148, 4, DataLanguage.en), 'Brick Mail');
    expect(GameStrings.item(426, 4), 'MO07');
    expect(GameStrings.item(427, 4, DataLanguage.en), 'HM08');
    expect(GameStrings.item(425, 4), 'MO06');
    expect(GameStrings.item(137, 5), isNot('Carta Hierba'));
  });
}
