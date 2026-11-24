import '../model/game.dart';

/// Formato binario de una entidad Pokémon.
enum PkFormat {
  pk1(1, 'pk1', 33, 44),
  pk2(2, 'pk2', 32, 48),
  pk3(3, 'pk3', 80, 100),
  pk4(4, 'pk4', 136, 236),
  pk5(5, 'pk5', 136, 220),
  pk6(6, 'pk6', 0xE8, 0x104),
  pk7(7, 'pk7', 0xE8, 0x104),
  pb7(7, 'pb7', 0x104, 0x104),
  pk8(8, 'pk8', 0x148, 0x158),
  pb8(8, 'pb8', 0x148, 0x158),
  pa8(8, 'pa8', 0x168, 0x178),
  pk9(9, 'pk9', 0x148, 0x158),
  pa9(9, 'pa9', 0x148, 0x158);

  const PkFormat(this.generation, this.extension, this.storedSize, this.partySize);

  final int generation;

  /// Extensión de archivo suelto (sin punto).
  final String extension;
  final int storedSize;
  final int partySize;

  bool get isGameBoy => this == pk1 || this == pk2;

  /// Formatos con PID/EC separados (Gen 6+).
  bool get hasEncryptionConstant => generation >= 6;

  /// Formatos con naturaleza de estadísticas separada (mentas).
  bool get hasStatNature => generation >= 8;

  bool get hasAwakeningValues => this == pb7;
  bool get hasGanbaruValues => this == pa8;
  bool get hasTeraType => this == pk9;

  int get maxIv => isGameBoy ? 15 : 31;
  int get maxEv => isGameBoy ? 65535 : 252;
  int get maxEvTotal => isGameBoy ? 65535 * 6 : 510;
  int get maxNicknameLength => switch (this) {
        pk1 || pk2 || pk3 => 10,
        pk4 || pk5 => 10,
        _ => 12,
      };
  int get maxTrainerNameLength => switch (this) {
        pk1 || pk2 || pk3 => 7,
        pk4 || pk5 => 7,
        _ => 12,
      };

  /// Formato nativo de cada juego.
  static PkFormat forGame(GameVersion game) => switch (game) {
        GameVersion.redBlue || GameVersion.yellow => pk1,
        GameVersion.goldSilver || GameVersion.crystal => pk2,
        GameVersion.rubySapphire ||
        GameVersion.emerald ||
        GameVersion.fireRedLeafGreen ||
        GameVersion.colosseum ||
        GameVersion.xd =>
          pk3,
        GameVersion.diamondPearl || GameVersion.platinum || GameVersion.heartGoldSoulSilver => pk4,
        GameVersion.blackWhite || GameVersion.black2White2 => pk5,
        GameVersion.xy || GameVersion.omegaRubyAlphaSapphire => pk6,
        GameVersion.sunMoon || GameVersion.ultraSunUltraMoon => pk7,
        GameVersion.letsGo => pb7,
        GameVersion.swordShield => pk8,
        GameVersion.brilliantDiamondShiningPearl => pb8,
        GameVersion.legendsArceus => pa8,
        GameVersion.scarletViolet => pk9,
        GameVersion.legendsZA => pa9,
      };

  static PkFormat? fromExtension(String ext) {
    final e = ext.toLowerCase().replaceFirst('.', '');
    for (final f in values) {
      if (f.extension == e) return f;
    }
    return null;
  }
}

/// Orden de estadísticas usado por la API: PS, Ataque, Defensa, At. Esp., Def. Esp., Velocidad.
enum Stat { hp, atk, def, spa, spd, spe }
