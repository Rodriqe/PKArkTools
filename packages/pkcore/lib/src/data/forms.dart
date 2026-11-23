import '../model/game.dart';
import 'game_data.dart';
import 'generated/encounter_data.dart' show kEvolvesFrom;
import 'generated/form_names.dart';
import 'species.dart';

/// Datos de una especie **en una forma concreta y en un juego concreto**:
/// tipos, stats base, habilidades, género, formas presentes y nombre de forma.
///
/// Es la única puerta para los datos que cambian con la forma (Decidueye de
/// Hisui es Planta/Lucha, no Planta/Fantasma) o con el juego (Clefairy es
/// Normal hasta Gen 5 y Hada desde Gen 6). Usa las tablas personales por forma
/// de PKHeX (`PersonalTable`, índice de forma por juego) y los nombres de forma
/// de `FormConverter`; la tabla (especie, forma, juego) se verifica contra PKHeX
/// en `test/form_data_pkhex_test.dart`.
abstract final class SpeciesForms {
  /// Juegos en orden de preferencia cuando no se conoce el juego (el más
  /// reciente que tenga la especie y la forma).
  static const List<GameVersion> _fallback = [
    GameVersion.scarletViolet,
    GameVersion.legendsZA,
    GameVersion.legendsArceus,
    GameVersion.swordShield,
    GameVersion.brilliantDiamondShiningPearl,
    GameVersion.letsGo,
    GameVersion.ultraSunUltraMoon,
    GameVersion.omegaRubyAlphaSapphire,
    GameVersion.black2White2,
    GameVersion.heartGoldSoulSilver,
    GameVersion.emerald,
    GameVersion.crystal,
    GameVersion.yellow,
  ];

  /// Contexto de PKHeX (`EntityContext`) de los nombres de forma.
  static String _context(GameVersion game) => switch (game) {
        GameVersion.redBlue || GameVersion.yellow => 'Gen1',
        GameVersion.goldSilver || GameVersion.crystal => 'Gen2',
        GameVersion.rubySapphire || GameVersion.emerald || GameVersion.fireRedLeafGreen => 'Gen3',
        GameVersion.diamondPearl || GameVersion.platinum || GameVersion.heartGoldSoulSilver => 'Gen4',
        GameVersion.blackWhite || GameVersion.black2White2 => 'Gen5',
        GameVersion.xy || GameVersion.omegaRubyAlphaSapphire => 'Gen6',
        GameVersion.sunMoon || GameVersion.ultraSunUltraMoon => 'Gen7',
        GameVersion.letsGo => 'Gen7b',
        GameVersion.swordShield => 'Gen8',
        GameVersion.brilliantDiamondShiningPearl => 'Gen8b',
        GameVersion.legendsArceus => 'Gen8a',
        GameVersion.scarletViolet => 'Gen9',
        GameVersion.legendsZA => 'Gen9a',
      };

  /// Juego cuyos datos se usan para [species]/[form]: [game] si se conoce; si
  /// no, el más reciente en el que exista esa forma.
  static GameVersion? resolveGame(int species, int form, [GameVersion? game]) {
    if (game != null) return game;
    for (final g in _fallback) {
      if (isPresent(species, form, g)) return g;
    }
    for (final g in _fallback) {
      if (GameDataTable.forGame(g).hasSpecies(species)) return g;
    }
    return null;
  }

  /// Datos personales de la especie en esa forma y juego (stats base, tipos,
  /// habilidades, género). Con [game] nulo, los del juego más reciente que la tenga.
  static PersonalEntry? personal(int species, int form, [GameVersion? game]) {
    final g = resolveGame(species, form, game);
    if (g == null) return null;
    return GameDataTable.forGame(g).entry(species, form);
  }

  /// Número de formas de la especie en el juego (1 si no tiene).
  static int formCount(int species, GameVersion game) {
    final e = GameDataTable.forGame(game).entry(species);
    var count = e?.formCount ?? 1;
    // Gen 3: los datos personales no traen formas; las de Unown, Castform y
    // Deoxys existen aunque comparten entrada (PKHeX `PersonalTable3.IsPresentInGame`).
    final mask = kFormPresence[GameDataTable.forGame(game).key]?[species];
    if (mask != null && mask != 0) count = count < mask.bitLength ? mask.bitLength : count;
    return count;
  }

  /// `true` si la forma existe en el juego (PKHeX `IsPresentInGame`): p. ej.
  /// Decidueye normal no está en Leyendas Arceus, solo el de Hisui.
  static bool isPresent(int species, int form, GameVersion game) {
    final t = GameDataTable.forGame(game);
    if (form < 0 || !t.hasSpecies(species)) return false;
    final mask = kFormPresence[t.key]?[species];
    if (mask != null) return form < 63 && (mask >> form) & 1 == 1;
    return form < (t.entry(species)?.formCount ?? 1);
  }

  /// Formas presentes de la especie en el juego (al menos la 0 si la especie existe).
  static List<int> presentForms(int species, GameVersion game) => [
        for (var f = 0; f < formCount(species, game); f++)
          if (isPresent(species, f, game)) f,
      ];

  /// Tipos de la especie en esa forma y juego. Sin datos del juego, los de la
  /// especie en su forma base (datos de PokeAPI).
  static (PokemonType, PokemonType) types(int species, int form, [GameVersion? game]) {
    final g = resolveGame(species, form, game);
    final e = g == null ? null : GameDataTable.forGame(g).entry(species, form);
    if (g == null || e == null || e.baseStatTotal == 0) return Species.types(species);
    final t1 = typeFromId(e.type1, g.generation), t2 = typeFromId(e.type2, g.generation);
    return (t1, t2 == t1 ? PokemonType.none : t2);
  }

  /// Convierte un id de tipo de los datos personales a [PokemonType]. En
  /// Gen 1/2 los datos usan los ids internos del cartucho (Fuego = 20…).
  static PokemonType typeFromId(int id, int generation) {
    var t = id;
    if (generation <= 2) {
      t = switch (id) {
        <= 5 => id,
        7 => 6, // Bicho
        8 => 7, // Fantasma
        9 => 8, // Acero
        >= 20 && <= 27 => id - 11, // Fuego … Siniestro
        _ => -1,
      };
    }
    return t >= 0 && t + 1 < PokemonType.values.length ? PokemonType.values[t + 1] : PokemonType.none;
  }

  /// Nombres de las formas de la especie en el contexto del juego (PKHeX
  /// `FormConverter`); vacío si la especie no tiene formas con nombre.
  static List<String> formNames(int species, GameVersion game, [DataLanguage lang = DataLanguage.es]) {
    final pair = kFormNames[_context(game)]?[species];
    if (pair == null) return const [];
    final list = kFormNameLists[lang == DataLanguage.es ? pair.$2 : pair.$1];
    return [for (final i in list) kFormNamePool[i]];
  }

  /// Nombre de la forma ([form]) en el juego, o cadena vacía si no tiene o es
  /// la forma base sin nombre propio ("Normal").
  static String formName(int species, int form, GameVersion? game, [DataLanguage lang = DataLanguage.es]) {
    final g = resolveGame(species, form, game);
    if (g == null) return '';
    final names = formNames(species, g, lang);
    if (form < 0 || form >= names.length) return '';
    final n = names[form];
    if (form == 0 && (n == GameStrings.type(0, lang) || n == GameStrings.type(0, DataLanguage.en))) return '';
    return n;
  }

  /// Nombre visible de la especie con su forma: «Decidueye (Hisui)»,
  /// «Rotom (Lavado)». La forma 0 se muestra solo con el nombre de la especie.
  static String displayName(int species, int form, GameVersion? game, [DataLanguage lang = DataLanguage.es]) {
    final base = GameStrings.species(species, lang);
    if (form <= 0) return base;
    final f = formName(species, form, game, lang);
    return f.isEmpty ? base : '$base ($f)';
  }

  /// Preevolución con forma (PKHeX `EvolutionTree.Reverse`): Decidueye de Hisui
  /// viene de Dartrix (forma 0), Sandslash de Alola de Sandshrew de Alola,
  /// Perrserker de Meowth de Galar. Null si no tiene.
  static (int, int)? preEvolution(int species, int form, GameVersion game) {
    if (species <= 0 || species >= kEvolvesFrom.length) return null;
    final pre = kEvolvesFrom[species];
    if (pre <= 0) return null;
    final special = _preForm(species, form);
    if (special != null) return (pre, special);
    // Regla general: la misma forma si la preevolución la tiene en el juego
    // (formas regionales), si no la forma 0.
    return (pre, isPresent(pre, form, game) ? form : 0);
  }

  /// Excepciones a la regla «misma forma» (especies de evolución regional o
  /// cuya forma depende de la preevolución).
  static int? _preForm(int species, int form) => switch (species) {
        26 => 0, // Raichu de Alola ← Pikachu (no el de gorra)
        666 => form, // Vivillon ← Scatterbug con el mismo diseño
        745 => form == 2 ? 1 : 0, // Lycanroc crepuscular ← Rockruff (Ritmo Propio)
        80 => form == 2 ? 1 : 0, // Slowbro de Galar ← Slowpoke de Galar
        555 => form >= 2 ? 1 : 0, // Darmanitan de Galar ← Darumaka de Galar
        863 => 2, // Perrserker ← Meowth de Galar
        902 => 2, // Basculegion ← Basculin raya blanca
        862 || 864 || 865 || 866 || 867 || 903 || 904 || 980 => 1, // evoluciones de formas regionales
        _ => null,
      };

  /// La especie y sus preevoluciones con su forma, de la más evolucionada a la base.
  static List<(int, int)> evolutionChain(int species, int form, GameVersion game) {
    final out = <(int, int)>[];
    (int, int)? cur = (species, form);
    while (cur != null && !out.any((e) => e.$1 == cur!.$1)) {
      out.add(cur);
      cur = preEvolution(cur.$1, cur.$2, game);
    }
    return out;
  }

  /// `true` si dos formas de la especie tienen distintos tipos o stats base
  /// (forma regional, Rotom…), y no solo un aspecto distinto (Unown, Vivillon).
  static bool formsDiffer(int species, int a, int b, [GameVersion? game]) {
    if (a == b) return false;
    final ea = personal(species, a, game), eb = personal(species, b, game);
    if (ea == null || eb == null) return false;
    return ea.type1 != eb.type1 || ea.type2 != eb.type2 || ea.baseStats.join(',') != eb.baseStats.join(',');
  }

  /// Teratipo original por defecto (id de PKHeX, 0 = Normal … 17 = Hada): el
  /// primer tipo de la forma (Decidueye de Hisui → Planta); Ogerpon tiene el
  /// de su máscara (Turquesa → Planta, Fuente → Agua, Horno → Fuego, Cimiento → Roca).
  static int defaultTeraType(int species, int form, [GameVersion? game]) {
    if (species == 1017) return const [11, 10, 9, 5][form & 3];
    final (t1, _) = types(species, form, game ?? GameVersion.scarletViolet);
    return t1 == PokemonType.none ? 0 : t1.index - 1;
  }
}
