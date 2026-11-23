import 'generated/species_data.dart';

/// Idiomas disponibles para nombres de especies.
enum SpeciesLanguage { es, en, ja }

/// Tipos elementales (ids de PokeAPI).
enum PokemonType {
  none,
  normal,
  fighting,
  flying,
  poison,
  ground,
  rock,
  bug,
  ghost,
  steel,
  fire,
  water,
  grass,
  electric,
  psychic,
  ice,
  dragon,
  dark,
  fairy,
}

/// Datos de especies (Pokédex Nacional 1–1025).
abstract final class Species {
  static const int max = kMaxSpeciesId;

  static bool isValid(int species) => species > 0 && species <= max;

  /// Nombre de la especie en [lang]; `#123` si no se conoce.
  static String name(int species, [SpeciesLanguage lang = SpeciesLanguage.es]) {
    if (!isValid(species)) return '#$species';
    final list = switch (lang) {
      SpeciesLanguage.es => kSpeciesNamesEs,
      SpeciesLanguage.en => kSpeciesNamesEn,
      SpeciesLanguage.ja => kSpeciesNamesJa,
    };
    final n = list[species];
    return n.isEmpty ? '#$species' : n;
  }

  static (PokemonType, PokemonType) types(int species) {
    if (!isValid(species)) return (PokemonType.none, PokemonType.none);
    final packed = kSpeciesTypes[species];
    final t1 = packed & 31;
    final t2 = (packed >> 5) & 31;
    return (
      t1 < PokemonType.values.length ? PokemonType.values[t1] : PokemonType.none,
      t2 < PokemonType.values.length ? PokemonType.values[t2] : PokemonType.none,
    );
  }

  /// Generación en la que debutó la especie.
  static int introducedIn(int species) {
    const limits = [151, 251, 386, 493, 649, 721, 809, 905, 1025];
    for (var i = 0; i < limits.length; i++) {
      if (species <= limits[i]) return i + 1;
    }
    return 9;
  }

  /// Nivel correspondiente a [exp] para la especie (tasa de crecimiento).
  static int levelFromExp(int species, int exp) {
    if (!isValid(species)) return 1;
    final table = kExperienceTables[kSpeciesGrowth[species]];
    if (table == null) return 1;
    var level = 1;
    for (var l = 2; l <= 100; l++) {
      if (exp >= table[l]) {
        level = l;
      } else {
        break;
      }
    }
    return level;
  }

  /// Experiencia mínima para [level] (útil para generar fixtures).
  static int expForLevel(int species, int level) {
    if (!isValid(species)) return 0;
    final table = kExperienceTables[kSpeciesGrowth[species]];
    if (table == null) return 0;
    return table[level.clamp(1, 100)];
  }
}
