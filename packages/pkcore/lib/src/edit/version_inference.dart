import 'dart:typed_data';

import '../model/game.dart';
import '../model/save.dart';
import 'save_editor.dart';

/// Versión concreta (cartucho) de una partida y sus parejas.
///
/// Los ids son los de PKHeX `GameVersion`; Gen 1/2 usan los de la Consola
/// Virtual (35 Rojo, 36 Verde, 37 Azul, 38 Amarillo, 39 Oro, 40 Plata, 41 Cristal).
abstract final class GameVersions {
  /// Versiones posibles de cada familia, en el orden de la pareja.
  static const Map<GameVersion, List<int>> ofGame = {
    GameVersion.redBlue: [35, 37, 36],
    GameVersion.yellow: [38],
    GameVersion.goldSilver: [39, 40],
    GameVersion.crystal: [41],
    GameVersion.rubySapphire: [2, 1],
    GameVersion.emerald: [3],
    GameVersion.fireRedLeafGreen: [4, 5],
    // Colosseum y XD comparten la versión de origen 15 en sus Pokémon; para
    // el save se usan los ids de grupo de PKHeX (`GameVersion.COLO`/`XD`).
    GameVersion.colosseum: [66],
    GameVersion.xd: [67],
    GameVersion.boxRS: [65],
    GameVersion.stadium: [93],
    GameVersion.stadium2: [94],
    GameVersion.battleRevolution: [16],
    // My Pokémon Ranch no tiene id en PKHeX: 200 es propio de PKArkTools.
    GameVersion.ranch: [200],
    GameVersion.diamondPearl: [10, 11],
    GameVersion.platinum: [12],
    GameVersion.heartGoldSoulSilver: [7, 8],
    GameVersion.blackWhite: [21, 20],
    GameVersion.black2White2: [23, 22],
    GameVersion.xy: [24, 25],
    GameVersion.omegaRubyAlphaSapphire: [27, 26],
    GameVersion.sunMoon: [30, 31],
    GameVersion.ultraSunUltraMoon: [32, 33],
    GameVersion.letsGo: [42, 43],
    GameVersion.swordShield: [44, 45],
    GameVersion.brilliantDiamondShiningPearl: [48, 49],
    GameVersion.legendsArceus: [47],
    GameVersion.scarletViolet: [50, 51],
    GameVersion.legendsZA: [52],
  };

  /// Versión exacta conocida sin ambigüedad: la del save, o la única de la familia.
  static int? exact(GameVersion game, int? versionId) {
    final options = ofGame[game]!;
    if (versionId != null && options.contains(versionId)) return versionId;
    return options.length == 1 ? options.first : null;
  }

  /// Pareja que se muestra cuando no se sabe la versión (Rojo/Azul sin Verde).
  static List<int> pair(GameVersion game) {
    final o = ofGame[game]!;
    return o.length > 2 ? o.sublist(0, 2) : o;
  }

  static bool belongs(GameVersion game, int version) => ofGame[game]!.contains(version);

  /// Nombre corto de una versión (sin «Pokémon»).
  static String name(int v, {bool es = true}) => switch (v) {
        35 => es ? 'Rojo' : 'Red',
        36 => es ? 'Verde' : 'Green',
        37 => es ? 'Azul' : 'Blue',
        38 => es ? 'Amarillo' : 'Yellow',
        39 => es ? 'Oro' : 'Gold',
        40 => es ? 'Plata' : 'Silver',
        41 => es ? 'Cristal' : 'Crystal',
        1 => es ? 'Zafiro' : 'Sapphire',
        2 => es ? 'Rubí' : 'Ruby',
        3 => es ? 'Esmeralda' : 'Emerald',
        4 => es ? 'Rojo Fuego' : 'FireRed',
        5 => es ? 'Verde Hoja' : 'LeafGreen',
        7 => 'HeartGold',
        8 => 'SoulSilver',
        10 => es ? 'Diamante' : 'Diamond',
        11 => es ? 'Perla' : 'Pearl',
        12 => es ? 'Platino' : 'Platinum',
        15 => 'Colosseum/XD',
        16 => 'Battle Revolution',
        65 => es ? 'Box Rubí y Zafiro' : 'Box Ruby & Sapphire',
        66 => 'Colosseum',
        67 => 'XD',
        93 => 'Stadium',
        94 => 'Stadium 2',
        200 => es ? 'Rancho' : 'Ranch',
        20 => es ? 'Blanco' : 'White',
        21 => es ? 'Negro' : 'Black',
        22 => es ? 'Blanco 2' : 'White 2',
        23 => es ? 'Negro 2' : 'Black 2',
        24 => 'X',
        25 => 'Y',
        26 => es ? 'Zafiro Alfa' : 'Alpha Sapphire',
        27 => es ? 'Rubí Omega' : 'Omega Ruby',
        30 => es ? 'Sol' : 'Sun',
        31 => es ? 'Luna' : 'Moon',
        32 => es ? 'Ultrasol' : 'Ultra Sun',
        33 => es ? 'Ultraluna' : 'Ultra Moon',
        34 => 'Pokémon GO',
        42 => "Let's Go Pikachu",
        43 => "Let's Go Eevee",
        44 => es ? 'Espada' : 'Sword',
        45 => es ? 'Escudo' : 'Shield',
        47 => es ? 'Leyendas Arceus' : 'Legends: Arceus',
        48 => es ? 'Diamante Brillante' : 'Brilliant Diamond',
        49 => es ? 'Perla Reluciente' : 'Shining Pearl',
        50 => es ? 'Escarlata' : 'Scarlet',
        51 => es ? 'Púrpura' : 'Violet',
        52 => es ? 'Leyendas Z-A' : 'Legends: Z-A',
        _ => '#$v',
      };

  /// Deduce la versión de un save que no la guarda a partir de los Pokémon
  /// del propio entrenador (mismo TID/SID y nombre): su juego de origen es el
  /// cartucho. Devuelve null si no hay datos o hay empate.
  static int? infer(Uint8List raw, SaveFile save) {
    final options = ofGame[save.game]!;
    if (save.versionId != null || options.length == 1 || save.game.generation <= 2) return save.versionId;
    try {
      final ed = SaveEditor.open(raw);
      final votes = <int, int>{};
      void vote(SlotRef ref) {
        final pk = ed.get(ref);
        if (pk == null || pk.isEgg) return;
        if (pk.tid != save.trainer.tid) return;
        if (save.trainer.sid != null && pk.sid != save.trainer.sid) return;
        if (pk.otName.trim() != save.trainer.name.trim()) return;
        if (!options.contains(pk.version)) return;
        votes[pk.version] = (votes[pk.version] ?? 0) + 1;
      }

      for (var i = 0; i < ed.partyCount; i++) {
        vote(SlotRef.party(i));
      }
      for (var b = 0; b < ed.boxCount; b++) {
        for (var s = 0; s < ed.boxSlotCount; s++) {
          vote(SlotRef.box(b, s));
        }
      }
      if (votes.isEmpty) return null;
      final sorted = votes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      if (sorted.length > 1 && sorted[0].value == sorted[1].value) return null;
      return sorted.first.key;
    } catch (_) {
      return null;
    }
  }
}
