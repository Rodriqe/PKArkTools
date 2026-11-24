/// Plataforma de origen de una partida.
enum Platform {
  gameBoy('Game Boy', 'Game Boy'),
  gameBoyColor('Game Boy Color', 'Game Boy Color'),
  gameBoyAdvance('Game Boy Advance', 'Game Boy Advance'),
  gameCube('GameCube', 'GameCube'),
  nintendo64('Nintendo 64', 'Nintendo 64'),
  wii('Wii', 'Wii'),
  nintendoDs('Nintendo DS', 'Nintendo DS'),
  nintendo3ds('Nintendo 3DS', 'Nintendo 3DS'),
  nintendoSwitch('Nintendo Switch', 'Nintendo Switch');

  const Platform(this.nameEs, this.nameEn);
  final String nameEs;
  final String nameEn;
}

/// Familia de juego detectada (un mismo formato de save).
enum GameVersion {
  redBlue(1, Platform.gameBoy, 'rby', 'Pokémon Rojo / Azul', 'Pokémon Red / Blue'),
  yellow(1, Platform.gameBoy, 'yellow', 'Pokémon Amarillo', 'Pokémon Yellow'),
  stadium(1, Platform.nintendo64, 'stadium', 'Pokémon Stadium', 'Pokémon Stadium'),
  goldSilver(2, Platform.gameBoyColor, 'gs', 'Pokémon Oro / Plata', 'Pokémon Gold / Silver'),
  crystal(2, Platform.gameBoyColor, 'crystal', 'Pokémon Cristal', 'Pokémon Crystal'),
  stadium2(2, Platform.nintendo64, 'stadium2', 'Pokémon Stadium 2', 'Pokémon Stadium 2'),
  rubySapphire(3, Platform.gameBoyAdvance, 'rs', 'Pokémon Rubí / Zafiro', 'Pokémon Ruby / Sapphire'),
  emerald(3, Platform.gameBoyAdvance, 'emerald', 'Pokémon Esmeralda', 'Pokémon Emerald'),
  fireRedLeafGreen(3, Platform.gameBoyAdvance, 'frlg', 'Pokémon Rojo Fuego / Verde Hoja', 'Pokémon FireRed / LeafGreen'),
  colosseum(3, Platform.gameCube, 'colosseum', 'Pokémon Colosseum', 'Pokémon Colosseum'),
  xd(3, Platform.gameCube, 'xd', 'Pokémon XD: Tempestad Oscura', 'Pokémon XD: Gale of Darkness'),
  boxRS(3, Platform.gameCube, 'rsbox', 'Pokémon Box: Rubí y Zafiro', 'Pokémon Box: Ruby & Sapphire'),
  diamondPearl(4, Platform.nintendoDs, 'dp', 'Pokémon Diamante / Perla', 'Pokémon Diamond / Pearl'),
  platinum(4, Platform.nintendoDs, 'pt', 'Pokémon Platino', 'Pokémon Platinum'),
  heartGoldSoulSilver(4, Platform.nintendoDs, 'hgss', 'Pokémon Oro HeartGold / Plata SoulSilver', 'Pokémon HeartGold / SoulSilver'),
  battleRevolution(4, Platform.wii, 'batrev', 'Pokémon Battle Revolution', 'Pokémon Battle Revolution'),
  ranch(4, Platform.wii, 'ranch', 'My Pokémon Ranch', 'My Pokémon Ranch'),
  blackWhite(5, Platform.nintendoDs, 'bw', 'Pokémon Negro / Blanco', 'Pokémon Black / White'),
  black2White2(5, Platform.nintendoDs, 'b2w2', 'Pokémon Negro 2 / Blanco 2', 'Pokémon Black 2 / White 2'),
  xy(6, Platform.nintendo3ds, 'xy', 'Pokémon X / Y', 'Pokémon X / Y'),
  omegaRubyAlphaSapphire(6, Platform.nintendo3ds, 'oras', 'Pokémon Rubí Omega / Zafiro Alfa', 'Pokémon Omega Ruby / Alpha Sapphire'),
  sunMoon(7, Platform.nintendo3ds, 'sm', 'Pokémon Sol / Luna', 'Pokémon Sun / Moon'),
  ultraSunUltraMoon(7, Platform.nintendo3ds, 'usum', 'Pokémon Ultrasol / Ultraluna', 'Pokémon Ultra Sun / Ultra Moon'),
  letsGo(7, Platform.nintendoSwitch, 'lgpe', "Pokémon Let's Go, Pikachu! / Eevee!", "Pokémon Let's Go, Pikachu! / Eevee!"),
  swordShield(8, Platform.nintendoSwitch, 'swsh', 'Pokémon Espada / Escudo', 'Pokémon Sword / Shield'),
  brilliantDiamondShiningPearl(8, Platform.nintendoSwitch, 'bdsp', 'Pokémon Diamante Brillante / Perla Reluciente', 'Pokémon Brilliant Diamond / Shining Pearl'),
  legendsArceus(8, Platform.nintendoSwitch, 'pla', 'Leyendas Pokémon: Arceus', 'Pokémon Legends: Arceus'),
  scarletViolet(9, Platform.nintendoSwitch, 'sv', 'Pokémon Escarlata / Púrpura', 'Pokémon Scarlet / Violet'),
  legendsZA(9, Platform.nintendoSwitch, 'za', 'Leyendas Pokémon: Z-A', 'Pokémon Legends: Z-A');

  const GameVersion(this.generation, this.platform, this.code, this.nameEs, this.nameEn);

  /// Generación principal (1–9).
  final int generation;
  final Platform platform;

  /// Código estable usado para persistencia (no cambiar).
  final String code;
  final String nameEs;
  final String nameEn;

  static GameVersion? fromCode(String code) {
    for (final g in values) {
      if (g.code == code) return g;
    }
    return null;
  }

  /// Formato de ID de entrenador de 6 dígitos (Gen 7 en adelante).
  bool get usesSixDigitIds => generation >= 7;

  /// Pokémon Colosseum o XD (GameCube): Gen 3 con formatos CK3/XK3.
  bool get isColosseumOrXd => this == colosseum || this == xd;

  /// Juegos de almacenamiento o estadio (Stadium, Box, Battle Revolution,
  /// Rancho): sin aventura propia, guardan Pokémon de los juegos principales.
  bool get isStorage => this == stadium || this == stadium2 || this == boxRS || this == battleRevolution || this == ranch;
}

/// Título concreto (cartucho) cuando el save lo identifica, p. ej. Espada vs Escudo.
///
/// Los ids coinciden con `GameVersion` de PKHeX.
abstract final class GameTitles {
  static const Map<int, (String es, String en)> _titles = {
    16: ('Pokémon Battle Revolution', 'Pokémon Battle Revolution'),
    65: ('Pokémon Box: Rubí y Zafiro', 'Pokémon Box: Ruby & Sapphire'),
    66: ('Pokémon Colosseum', 'Pokémon Colosseum'),
    67: ('Pokémon XD: Tempestad Oscura', 'Pokémon XD: Gale of Darkness'),
    93: ('Pokémon Stadium', 'Pokémon Stadium'),
    94: ('Pokémon Stadium 2', 'Pokémon Stadium 2'),
    7: ('Pokémon Oro HeartGold', 'Pokémon HeartGold'),
    8: ('Pokémon Plata SoulSilver', 'Pokémon SoulSilver'),
    10: ('Pokémon Diamante', 'Pokémon Diamond'),
    11: ('Pokémon Perla', 'Pokémon Pearl'),
    12: ('Pokémon Platino', 'Pokémon Platinum'),
    20: ('Pokémon Blanco', 'Pokémon White'),
    21: ('Pokémon Negro', 'Pokémon Black'),
    22: ('Pokémon Blanco 2', 'Pokémon White 2'),
    23: ('Pokémon Negro 2', 'Pokémon Black 2'),
    24: ('Pokémon X', 'Pokémon X'),
    25: ('Pokémon Y', 'Pokémon Y'),
    26: ('Pokémon Zafiro Alfa', 'Pokémon Alpha Sapphire'),
    27: ('Pokémon Rubí Omega', 'Pokémon Omega Ruby'),
    30: ('Pokémon Sol', 'Pokémon Sun'),
    31: ('Pokémon Luna', 'Pokémon Moon'),
    32: ('Pokémon Ultrasol', 'Pokémon Ultra Sun'),
    33: ('Pokémon Ultraluna', 'Pokémon Ultra Moon'),
    42: ("Pokémon Let's Go, Pikachu!", "Pokémon Let's Go, Pikachu!"),
    43: ("Pokémon Let's Go, Eevee!", "Pokémon Let's Go, Eevee!"),
    44: ('Pokémon Espada', 'Pokémon Sword'),
    45: ('Pokémon Escudo', 'Pokémon Shield'),
    47: ('Leyendas Pokémon: Arceus', 'Pokémon Legends: Arceus'),
    48: ('Pokémon Diamante Brillante', 'Pokémon Brilliant Diamond'),
    49: ('Pokémon Perla Reluciente', 'Pokémon Shining Pearl'),
    50: ('Pokémon Escarlata', 'Pokémon Scarlet'),
    51: ('Pokémon Púrpura', 'Pokémon Violet'),
    52: ('Leyendas Pokémon: Z-A', 'Pokémon Legends: Z-A'),
  };

  static String? nameEs(int? id) => id == null ? null : _titles[id]?.$1;
  static String? nameEn(int? id) => id == null ? null : _titles[id]?.$2;
}
