import '../data/game_data.dart';
import '../model/game.dart';
import 'legality.dart';

/// Poké Balls que puede llevar un Pokémon guardado en cada juego (ids de
/// PKHeX `Ball`). Basado en PKHeX `BallUseLegality` y en los traspasos
/// posibles hacia cada juego (GPL-3.0).
///
/// * 1–16: Master … Gloria (16 = Gloria, solo eventos).
/// * 17–23: Bonguri (HGSS) · 24: Competi · 25: Ensueño · 26: Ente · 27: Extraña.
/// * 28–37: Balls de Hisui (Leyendas Arceus): Poké, Super, Ultra, Pluma, Ala,
///   Aero, Plomo, Lastre, Megalastre y Origen.
abstract final class BallTables {
  static const int strange = 27;
  static const int hisuiFirst = 28;
  static const int hisuiLast = 37;
  static const int origin = 37;
  static const int cherish = 16;

  static bool isHisui(int ball) => ball >= hisuiFirst && ball <= hisuiLast;

  static List<int> _range(int a, int b) => [for (var i = a; i <= b; i++) i];

  /// Balls válidas en el formato de [game], en el orden en que se muestran
  /// (Poké/Super/Ultra/Master primero, como en PKHeX).
  static List<int> forGame(GameVersion game) {
    final List<int> raw = switch (game) {
      GameVersion.redBlue ||
      GameVersion.yellow ||
      GameVersion.goldSilver ||
      GameVersion.crystal ||
      GameVersion.stadium ||
      GameVersion.stadium2 =>
        const [4],
      // Rancho: Pokémon de Diamante/Perla/Platino; Battle Revolution también de HGSS.
      GameVersion.ranch => _range(1, 16),
      GameVersion.battleRevolution => _range(1, 24),
      GameVersion.rubySapphire ||
      GameVersion.emerald ||
      GameVersion.fireRedLeafGreen ||
      GameVersion.colosseum ||
      GameVersion.xd ||
      GameVersion.boxRS =>
        _range(1, 12),
      GameVersion.diamondPearl || GameVersion.platinum => _range(1, 16),
      // HGSS: Bonguri y Competi; los traspasos de Pal Park no traen otras.
      GameVersion.heartGoldSoulSilver => _range(1, 24),
      GameVersion.blackWhite || GameVersion.black2White2 => _range(1, 25),
      GameVersion.xy || GameVersion.omegaRubyAlphaSapphire => _range(1, 25),
      GameVersion.sunMoon || GameVersion.ultraSunUltraMoon => _range(1, 26),
      // Let's Go: Poké, Super, Ultra, Master, Honor y Gloria (eventos y GO).
      GameVersion.letsGo => const [1, 2, 3, 4, 12, 16],
      GameVersion.swordShield => _range(1, 26),
      // DBPR: Balls de Sinnoh + Bonguri (sin Competi/Ente/Ensueño en capturas propias).
      GameVersion.brilliantDiamondShiningPearl => [..._range(1, 23), 25],
      // Leyendas Arceus: solo las Balls de Hisui (+ Extraña y Gloria de eventos/traspasos).
      GameVersion.legendsArceus => [cherish, strange, ..._range(hisuiFirst, hisuiLast)],
      // SV y Z-A reciben Pokémon de HOME con cualquier Ball, incluidas las de Hisui.
      GameVersion.scarletViolet || GameVersion.legendsZA => _range(1, 37),
    };
    const first = [4, 3, 2, 1];
    return [
      for (final b in first) if (raw.contains(b)) b,
      for (final b in raw) if (!first.contains(b)) b,
    ];
  }

  /// `true` si [ball] puede aparecer en un Pokémon guardado en [game].
  static bool isValidIn(GameVersion game, int ball) => forGame(game).contains(ball);

  /// Ball por defecto del juego (la Poké Ball de Hisui en Leyendas Arceus).
  static int defaultFor(GameVersion game) => game == GameVersion.legendsArceus ? hisuiFirst : 4;

  /// Opciones del selector: las del juego y, si el Pokémon ya lleva otra
  /// (p. ej. traído de otro juego), también esa al final para no perderla.
  static List<int> pickerOptions(GameVersion game, int current) {
    final list = forGame(game);
    if (current > 0 && current <= hisuiLast && !list.contains(current)) return [...list, current];
    return list;
  }

  /// Nombre legible de una Ball. Las de Hisui que comparten nombre con las
  /// modernas (Poké, Super, Ultra y Peso Ball) llevan "de Hisui" para
  /// distinguirlas (PKHeX añade " (LA)").
  static String name(int ball, [DataLanguage lang = DataLanguage.es]) {
    final item = OriginGames.ballItem(ball);
    if (item == 0) return ball == 0 ? '—' : '#$ball';
    final n = GameStrings.item(item, 9, lang);
    if (ball == 28 || ball == 29 || ball == 30 || ball == 34) {
      return lang == DataLanguage.es ? '$n de Hisui' : 'Hisuian $n';
    }
    return n;
  }
}
