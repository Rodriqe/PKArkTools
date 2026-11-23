import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pkcore/pkcore.dart';

/// Colores oficiales de cada versión (cartucho), por id de PKHeX `GameVersion`
/// (Gen 1/2 con los ids de la Consola Virtual: 35 Rojo … 41 Cristal).
abstract final class VersionPalette {
  static const Map<int, Color> colors = {
    35: Color(0xFFE3350D), // Rojo
    36: Color(0xFF3E9E4F), // Verde (Japón)
    37: Color(0xFF2E5FD6), // Azul
    38: Color(0xFFF7CB2D), // Amarillo
    39: Color(0xFFCFA22E), // Oro
    40: Color(0xFFA9B3C1), // Plata
    41: Color(0xFF4CC3E6), // Cristal
    2: Color(0xFFC6162F), // Rubí
    1: Color(0xFF1F55C2), // Zafiro
    3: Color(0xFF169C5A), // Esmeralda
    4: Color(0xFFF0582A), // Rojo Fuego
    5: Color(0xFF6DB840), // Verde Hoja
    15: Color(0xFF7C5BA6), // Colosseum/XD
    10: Color(0xFF6F97E3), // Diamante
    11: Color(0xFFE39CC0), // Perla
    12: Color(0xFF8E96A3), // Platino
    7: Color(0xFFE0AE33), // HeartGold
    8: Color(0xFFB5C0CF), // SoulSilver
    21: Color(0xFF34353C), // Negro
    20: Color(0xFFE6E9EE), // Blanco
    23: Color(0xFF283F63), // Negro 2
    22: Color(0xFFEFE1DD), // Blanco 2
    24: Color(0xFF1E5FD0), // X
    25: Color(0xFFD5273F), // Y
    27: Color(0xFFB01430), // Rubí Omega
    26: Color(0xFF1C58C8), // Zafiro Alfa
    30: Color(0xFFF2992B), // Sol
    31: Color(0xFF6A5BD0), // Luna
    32: Color(0xFFF06A1E), // Ultrasol
    33: Color(0xFF5640C2), // Ultraluna
    42: Color(0xFFF5CC36), // Let's Go Pikachu
    43: Color(0xFFB98352), // Let's Go Eevee
    44: Color(0xFF00A0E6), // Espada
    45: Color(0xFFE0007A), // Escudo
    48: Color(0xFF4C7EDF), // Diamante Brillante
    49: Color(0xFFE28CB4), // Perla Reluciente
    47: Color(0xFFC2A66B), // Leyendas Arceus
    50: Color(0xFFE5332E), // Escarlata
    51: Color(0xFF8A3FC6), // Púrpura
    52: Color(0xFF4DBE77), // Leyendas Z-A
    34: Color(0xFF3FA9E0), // Pokémon GO
  };

  static Color? of(int? version) => version == null ? null : colors[version];

  /// Colores de la etiqueta: uno si se conoce la versión exacta (por el save,
  /// por el juego del entrenador o fijada a mano), la pareja si no.
  static List<Color> forSave(GameVersion game, int? versionId) {
    final exact = GameVersions.exact(game, versionId);
    if (exact != null) return [colors[exact]!];
    return [for (final v in GameVersions.pair(game)) colors[v]!];
  }

  /// Velo oscuro inferior de las etiquetas bicolor: el título va en blanco
  /// encima, así es legible aunque la pareja sea Negro/Blanco.
  static const double pairScrim = 0.5;

  /// Tinta legible sobre la etiqueta: blanco sobre el velo de una pareja; si
  /// es un solo color, la de mejor contraste.
  static Color inkOn(List<Color> bg) {
    if (bg.length > 1) return Colors.white;
    const dark = Color(0xFF151927);
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    double worst(Color ink) => bg.map((c) => contrast(ink, c)).reduce(math.min);
    return worst(Colors.white) >= worst(dark) ? Colors.white : dark;
  }
}

/// Colores de acento por juego (y por cartucho concreto cuando se conoce).
abstract final class GamePalette {
  /// Acento del juego: el color de su versión (la primera de la pareja si no se sabe).
  static Color of(GameVersion game, [int? versionId]) => VersionPalette.forSave(game, versionId).first;

  /// Color legible encima del acento.
  static Color onAccent(Color c) => c.computeLuminance() > 0.45 ? const Color(0xFF151927) : Colors.white;
}

/// Colores de tipo elemental para los avatares de especie.
abstract final class TypePalette {
  static const Map<PokemonType, Color> colors = {
    PokemonType.none: Color(0xFF8A90A6),
    PokemonType.normal: Color(0xFFA8A77A),
    PokemonType.fighting: Color(0xFFC22E28),
    PokemonType.flying: Color(0xFFA98FF3),
    PokemonType.poison: Color(0xFFA33EA1),
    PokemonType.ground: Color(0xFFE2BF65),
    PokemonType.rock: Color(0xFFB6A136),
    PokemonType.bug: Color(0xFFA6B91A),
    PokemonType.ghost: Color(0xFF735797),
    PokemonType.steel: Color(0xFFB7B7CE),
    PokemonType.fire: Color(0xFFEE8130),
    PokemonType.water: Color(0xFF6390F0),
    PokemonType.grass: Color(0xFF7AC74C),
    PokemonType.electric: Color(0xFFF7D02C),
    PokemonType.psychic: Color(0xFFF95587),
    PokemonType.ice: Color(0xFF96D9D6),
    PokemonType.dragon: Color(0xFF6F35FC),
    PokemonType.dark: Color(0xFF705746),
    PokemonType.fairy: Color(0xFFD685AD),
  };

  static Color of(PokemonType t) => colors[t]!;
}
