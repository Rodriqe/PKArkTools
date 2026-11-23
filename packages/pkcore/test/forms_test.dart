import 'package:pkcore/pkcore.dart';
import 'package:test/test.dart';

const _t = PokemonType.values;

// PK9: habilidad en 0x14 (u16).
void _setAbility(Pkm pk, int id) => pk.data
  ..[0x14] = id & 0xFF
  ..[0x15] = id >> 8;

(PokemonType, PokemonType) _types(String a, [String? b]) =>
    (_t.byName(a), b == null ? PokemonType.none : _t.byName(b));

void main() {
  const sv = GameVersion.scarletViolet;
  const la = GameVersion.legendsArceus;
  const za = GameVersion.legendsZA;

  group('tipos por forma y juego', () {
    test('Decidueye de Hisui es Planta/Lucha (no Planta/Fantasma)', () {
      expect(SpeciesForms.types(724, 0, sv), _types('grass', 'ghost'));
      expect(SpeciesForms.types(724, 1, sv), _types('grass', 'fighting'));
      expect(SpeciesForms.types(724, 1, la), _types('grass', 'fighting'));
      // Sin juego conocido: el más reciente que tenga la forma.
      expect(SpeciesForms.types(724, 1), _types('grass', 'fighting'));
    });

    test('formas regionales: Alola, Galar, Hisui, Paldea', () {
      expect(SpeciesForms.types(38, 1, GameVersion.ultraSunUltraMoon), _types('ice', 'fairy')); // Ninetales de Alola
      expect(SpeciesForms.types(110, 1, GameVersion.swordShield), _types('poison', 'fairy')); // Weezing de Galar
      expect(SpeciesForms.types(59, 1, la), _types('fire', 'rock')); // Arcanine de Hisui
      expect(SpeciesForms.types(194, 1, sv), _types('poison', 'ground')); // Wooper de Paldea
    });

    test('Tauros de Paldea (tres razas)', () {
      expect(SpeciesForms.types(128, 0, sv), _types('normal'));
      expect(SpeciesForms.types(128, 1, sv), _types('fighting'));
      expect(SpeciesForms.types(128, 2, sv), _types('fighting', 'fire'));
      expect(SpeciesForms.types(128, 3, sv), _types('fighting', 'water'));
    });

    test('Rotom, Urshifu y Ogerpon', () {
      expect(SpeciesForms.types(479, 1, sv), _types('electric', 'fire'));
      expect(SpeciesForms.types(479, 2, sv), _types('electric', 'water'));
      expect(SpeciesForms.types(892, 0, sv), _types('fighting', 'dark'));
      expect(SpeciesForms.types(892, 1, sv), _types('fighting', 'water'));
      expect(SpeciesForms.types(1017, 0, sv), _types('grass'));
      expect(SpeciesForms.types(1017, 1, sv), _types('grass', 'water'));
      expect(SpeciesForms.types(1017, 2, sv), _types('grass', 'fire'));
      expect(SpeciesForms.types(1017, 3, sv), _types('grass', 'rock'));
    });

    test('megaevoluciones en Let\'s Go y Z-A', () {
      expect(SpeciesForms.types(6, 1, za), _types('fire', 'dragon')); // Mega Charizard X
      expect(SpeciesForms.types(6, 2, za), _types('fire', 'flying')); // Mega Charizard Y
      expect(SpeciesForms.types(6, 1, GameVersion.letsGo), _types('fire', 'dragon'));
      expect(SpeciesForms.types(181, 1, za), _types('electric', 'dragon')); // Mega Ampharos
      expect(SpeciesForms.displayName(6, 1, za, DataLanguage.en), 'Charizard (Mega X)');
    });

    test('tipos que cambian entre generaciones (Clefairy Normal → Hada)', () {
      expect(SpeciesForms.types(35, 0, GameVersion.black2White2), _types('normal'));
      expect(SpeciesForms.types(35, 0, GameVersion.xy), _types('fairy'));
      expect(SpeciesForms.types(4, 0, GameVersion.redBlue), _types('fire')); // ids internos de Gen 1
      expect(SpeciesForms.types(208, 0, GameVersion.crystal), _types('steel', 'ground'));
    });
  });

  group('stats y habilidades por forma', () {
    test('Decidueye de Hisui', () {
      final e = SpeciesForms.personal(724, 1, sv)!;
      expect(e.baseStats, [88, 112, 80, 95, 95, 60]);
      expect(e.abilities, [65, 65, 113]); // Espesura / Intrépido
      expect(SpeciesForms.personal(724, 0, sv)!.abilities.last, 203); // Decidueye normal: Remoto
    });

    test('Urshifu y Tauros de Paldea', () {
      expect(SpeciesForms.personal(892, 0, sv)!.abilities.first, 260); // Golpe Oculto
      expect(SpeciesForms.personal(128, 1, sv)!.baseStats, [75, 110, 105, 30, 70, 100]);
    });
  });

  group('nombres de forma', () {
    test('«Decidueye (Hisui)» en inglés y español', () {
      expect(SpeciesForms.displayName(724, 1, sv, DataLanguage.en), 'Decidueye (Hisui)');
      expect(SpeciesForms.displayName(724, 1, sv), 'Decidueye (Hisui)');
      expect(SpeciesForms.displayName(724, 0, sv, DataLanguage.en), 'Decidueye');
      expect(SpeciesForms.displayName(479, 2, sv), 'Rotom (Lavado)');
      expect(SpeciesForms.displayName(479, 2, sv, DataLanguage.en), 'Rotom (Wash)');
      expect(SpeciesForms.displayName(128, 3, sv, DataLanguage.en), 'Tauros (Paldea Aqua)');
      expect(SpeciesForms.displayName(892, 1, sv, DataLanguage.en), 'Urshifu (Rapid Strike)');
      expect(SpeciesForms.formName(892, 0, sv, DataLanguage.en), 'Single Strike');
    });

    test('formas presentes por juego', () {
      expect(SpeciesForms.presentForms(724, la), [1]); // solo el de Hisui
      expect(SpeciesForms.presentForms(724, sv), [0, 1]);
      expect(SpeciesForms.presentForms(6, za), [0, 1, 2]);
      expect(SpeciesForms.presentForms(6, sv), [0]);
      expect(SpeciesForms.isPresent(386, 3, GameVersion.emerald), isTrue); // Deoxys en Gen 3
      expect(GameDataTable.forGame(GameVersion.diamondPearl).hasSpecies(494), isFalse);
      expect(GameDataTable.forGame(la).hasSpecies(58), isTrue); // Growlithe solo de Hisui
    });
  });

  group('evoluciones con forma', () {
    test('cadenas', () {
      expect(SpeciesForms.evolutionChain(724, 1, sv), [(724, 1), (723, 0), (722, 0)]);
      expect(SpeciesForms.evolutionChain(28, 1, GameVersion.sunMoon), [(28, 1), (27, 1)]);
      expect(SpeciesForms.evolutionChain(26, 1, GameVersion.sunMoon), [(26, 1), (25, 0), (172, 0)]);
      expect(SpeciesForms.evolutionChain(863, 0, GameVersion.swordShield), [(863, 0), (52, 2)]);
    });
  });

  group('legalidad y creación', () {
    const trainer = TrainerData(name: 'ASH', tid: 12345, sid: 54321);

    test('Pokémon nuevo con forma: tipos, habilidades y teratipo de la forma', () {
      final pk = PkmFactory.create(sv, trainer, species: 724, form: 1, level: 50);
      expect(pk.form, 1);
      expect(pk.teraTypeOriginal, 11); // Planta
      expect(pk.teraType, 11);
      final og = PkmFactory.create(sv, trainer, species: 1017, form: 1, level: 70);
      expect(og.teraTypeOriginal, 10); // Ogerpon Fuente: Agua
      final abilities = SpeciesForms.personal(724, 1, sv)!.abilities;
      expect(abilities, contains(pk.ability));
    });

    test('una forma que no existe en el juego se avisa con su nombre', () {
      final pk = PkmFactory.create(la, trainer, species: 724, form: 1, level: 50);
      expect(Legality.check(pk, la).where((i) => i.field == 'form'), isEmpty);
      pk.form = 0;
      final issues = Legality.check(pk, la, lang: DataLanguage.en).where((i) => i.field == 'form').toList();
      expect(issues, hasLength(1));
      expect(issues.single.message(DataLanguage.en), 'Decidueye is not available in this game.');
      pk.form = 1;
      pk.species = 6;
      expect(Legality.check(pk, la).where((i) => i.code == LegalityCode.speciesNotInGame), isNotEmpty);
    });

    test('las habilidades se validan con las de la forma', () {
      final pk = PkmFactory.create(sv, trainer, species: 724, form: 1, level: 50);
      _setAbility(pk, 203); // Remoto: habilidad oculta del Decidueye normal, no del de Hisui
      expect(Legality.check(pk, sv).map((i) => i.code), contains(LegalityCode.abilityNotPossible));
      _setAbility(pk, 113); // Intrépido
      expect(Legality.check(pk, sv).map((i) => i.code), isNot(contains(LegalityCode.abilityNotPossible)));
    });
  });
}
