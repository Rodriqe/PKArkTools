import 'package:pkcore/pkcore.dart';
import 'package:pkcore/src/util/bytes.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

/// Bugs hallados al comparar pkcore con PKHeX (tools/pkhex_oracle) sobre dos
/// saves reales (SoulSilver y Espada). Cada caso reproduce el hallazgo con
/// datos sintéticos.
const _swsh = GameVersion.swordShield;
const _hgss = GameVersion.heartGoldSoulSilver;

Pkm _pk8(int species,
    {int level = 50, int form = 0, int version = 44, int metLocation = 30001, int? metLevel, List<int> moves = const [33]}) {
  final raw = SyntheticSaves.swordShield(party: [SynthMon(species, level: level)]);
  final pk = SaveEditor.open(raw).get(const SlotRef.party(0))!
    ..form = form
    ..version = version
    ..metLocation = metLocation
    ..metLevel = metLevel ?? level
    ..ball = 4;
  pk.data[0x22] &= ~1; // sin encuentro fatídico
  pk.data.setRange(0x120, 0x122, [0, 0]); // sin lugar de huevo
  for (var i = 0; i < 4; i++) {
    pk.setMove(i, i < moves.length ? moves[i] : 0, context: '8');
    pk.setRelearnMove(i, 0);
  }
  return pk..refreshChecksum();
}

Pkm _pk4({int version = 7}) {
  final raw = SyntheticSaves.gen4(layout: Gen4Layout.hgss, party: [const SynthMon(448, level: 60)]);
  return SaveEditor.open(raw).get(const SlotRef.party(0))!..version = version;
}

Set<LegalityCode> _codes(Pkm pk, [GameVersion game = _swsh]) => {for (final i in Legality.check(pk, game)) i.code};

const _encounterCodes = {
  LegalityCode.encounterNotInGame,
  LegalityCode.encounterWrongLocation,
  LegalityCode.encounterWrongLevel,
};

void main() {
  group('Datos de SWSH: DT y tutores alineados', () {
    final t = GameDataTable.forGame(_swsh);
    test('los bits de DT empiezan tras los 13 bytes de MT (antes se desplazaban 4)', () {
      expect(t.machineMoves(849), contains(85)); // Toxtricity: Rayo (DT08)
      expect(t.machineMoves(849), isNot(contains(57))); // ni Surf
      expect(t.machineMoves(6), containsAll([53, 126])); // Charizard: Lanzallamas, Llamarada
    });
    test('tutores de tipo y de la Isla de la Armadura', () {
      expect(t.machineMoves(815), containsAll([519, 307])); // Cinderace: Voto Fuego, Anillo Ígneo
      expect(t.machineMoves(884), contains(796)); // Duraludon: Metaláser
      expect(t.machineMoves(442), contains(809)); // Spiritomb: Poltergeist
    });
    test('un movimiento por DT ya no se marca como no aprendible', () {
      expect(_codes(_pk8(849, moves: const [85])), isNot(contains(LegalityCode.moveNotLearnable)));
    });
  });

  group('Movimientos y recordables que viajan por HOME', () {
    test('MO de Gen 4 en un Pokémon de Platino guardado en Espada (Mesprit con Bofetón Lodo)', () {
      expect(_codes(_pk8(481, version: 12, moves: const [189])), isNot(contains(LegalityCode.moveNotLearnable)));
      // Sin ese origen no hay forma de aprenderlo.
      expect(_codes(_pk8(481, version: 44, moves: const [189])), contains(LegalityCode.moveNotLearnable));
    });
    test('Pokémon GO llegado por Let\'s Go conserva lo aprendido allí', () {
      expect(_codes(_pk8(139, version: 34, metLocation: 50, metLevel: 8, moves: const [88])),
          isNot(contains(LegalityCode.moveNotLearnable)));
    });
    test('recordables de un huevo: los de la forma base (Metapod con Placaje y Disparo Demora)', () {
      final pk = _pk8(11, version: 45, metLocation: 30002, metLevel: 1)
        ..setRelearnMove(0, 33)
        ..setRelearnMove(1, 81);
      expect(_codes(pk..refreshChecksum()), isNot(contains(LegalityCode.relearnInvalid)));
      final bad = _pk8(11, version: 45)..setRelearnMove(0, 94); // Psíquico
      expect(_codes(bad..refreshChecksum()), contains(LegalityCode.relearnInvalid));
    });
    test('recordables del juego de origen (Salamence de Ultraluna con Furia)', () {
      final pk = _pk8(373, version: 33, metLocation: 74, metLevel: 1)..setRelearnMove(0, 99);
      expect(_codes(pk..refreshChecksum()), isNot(contains(LegalityCode.relearnInvalid)));
    });
  });

  group('Encuentros de Espada/Escudo', () {
    test('incursiones Dinamax en cualquier guarida y con el nivel rebajado', () {
      final slots = EncounterTables.forVersion(44);
      expect(slots.where((e) => e.kind == EncounterKind.raid && e.location == EncounterSlot.anyDen), isNotEmpty);
      // Corviknight de una incursión en el Gorro del Gigante (nivel 56).
      expect(_codes(_pk8(823, version: 44, metLocation: 152, metLevel: 56)).intersection(_encounterCodes), isEmpty);
      // Toxtricity de una incursión de distribución en la Pradera Radiante.
      expect(_codes(_pk8(849, version: 44, metLocation: 122, metLevel: 40)).intersection(_encounterCodes), isEmpty);
    });
    test('Aventura Dinamax (Supernido Dinamax)', () {
      expect(_codes(_pk8(108, version: 44, metLocation: 244, metLevel: 65)).intersection(_encounterCodes), isEmpty);
    });
    test('aves de Galar errantes (Crossover)', () {
      expect(_codes(_pk8(144, form: 1, version: 44, metLocation: 214, metLevel: 70)).intersection(_encounterCodes),
          isEmpty);
      expect(_codes(_pk8(146, form: 1, version: 44, metLocation: 178, metLevel: 70)).intersection(_encounterCodes),
          isEmpty);
    });
    test('salvajes de la Zona Silvestre a nivel 60 tras las 8 medallas', () {
      final slots = EncounterTables.forVersion(44);
      expect(slots.any((e) => e.kind == EncounterKind.wild && e.location == 122 && e.minLevel == 60), isTrue);
    });
    test('un lugar fuera de las guaridas sigue avisando', () {
      // Corviknight "encontrado" en Pueblo Plié (sin guaridas) a nivel 56.
      expect(_codes(_pk8(823, version: 44, metLocation: 6, metLevel: 56)).intersection(_encounterCodes), isNotEmpty);
    });
  });

  group('Variocolor bloqueado', () {
    test('no se aplica a eventos (Zacian variocolor de 2020)', () {
      final pk = _pk8(888, level: 100, version: 44, metLocation: 40001)..setShiny(true);
      expect(_codes(pk..refreshChecksum()), contains(LegalityCode.shinyLocked));
      pk.data[0x22] |= 1; // encuentro fatídico
      expect(_codes(pk..refreshChecksum()), isNot(contains(LegalityCode.shinyLocked)));
    });
  });

  group('Let\'s Go: combo de captura y zonas vecinas', () {
    test('el combo de captura sube en 1 el nivel máximo de la tabla', () {
      final slots = EncounterTables.forVersion(42).where((e) => e.species == 41 && e.location == 41 && e.kind == EncounterKind.wild);
      expect(slots.map((e) => e.maxLevel), contains(24)); // Túnel Roca: Zubat 18–23 (+1)
    });
  });

  group('Código Cero/Silvally variocolor', () {
    test('el regalo de Æther no tiene variocolor bloqueado', () {
      final pk = _pk8(773, level: 41, version: 31, metLocation: 188, metLevel: 40)..setShiny(true);
      expect(_codes(pk..refreshChecksum()), isNot(contains(LegalityCode.shinyLocked)));
    });
  });

  group('PK4: lugar de encuentro extendido de Platino/HGSS', () {
    test('se lee el campo extendido (0x46) si DP guarda «lugar lejano»', () {
      final pk = _pk4();
      pk.data.setU16le(0x80, 3002);
      pk.data.setU16le(0x46, 231);
      expect(pk.metLocation, 231);
      pk.data.setU16le(0x46, 0);
      pk.data.setU16le(0x80, 55);
      expect(pk.metLocation, 55);
    });
    test('al escribir se rellenan ambos campos como el juego', () {
      final pk = _pk4(version: 8)..metLocation = 207; // lugar exclusivo de HGSS
      expect((pk.data.u16le(0x80), pk.data.u16le(0x46)), (3002, 207));
      pk.metLocation = 55; // lugar que también existe en DP
      expect((pk.data.u16le(0x80), pk.data.u16le(0x46)), (55, 55));
      final dp = _pk4(version: 10);
      dp.data.setU16le(0x46, 0);
      dp.metLocation = 55;
      expect((dp.data.u16le(0x80), dp.data.u16le(0x46)), (55, 0));
      expect(_pk4()..metLocation = 0, isA<Pkm>().having((p) => p.metLocation, 'metLocation', 0));
    });
  });

  group('PP por encima del máximo con los Más PP que tiene', () {
    test('Danza Espada con 40 PP y sin Más PP (máximo 30)', () {
      final pk = _pk4()..setMove(0, 14, context: '4');
      pk.setPpUps(0, 0);
      pk.setPp(0, 40);
      expect(_codes(pk..refreshChecksum(), _hgss), contains(LegalityCode.ppTooHigh));
      pk.setPpUps(0, 3); // 3 Más PP: máximo 48
      expect(_codes(pk..refreshChecksum(), _hgss), isNot(contains(LegalityCode.ppTooHigh)));
    });
  });
}
