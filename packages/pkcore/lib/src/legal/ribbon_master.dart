import '../data/forms.dart';
import '../data/game_data.dart';
import '../data/generated/ribbon_master_data.dart';
import '../model/game.dart';
import 'ribbons.dart';

// Ribbon Master: guía por especie de todas las cintas que puede conseguir un
// mismo ejemplar, de la generación más antigua a la más nueva.
//
// * Catálogo: [RibbonGuide] (juego, método, requisito y disponibilidad de cada cinta).
// * Grafo de transferencias: [RibbonGame] y [RibbonGraph] (solo hacia adelante).
// * Disponibilidad por especie y forma: `ribbon_master_data.dart`, generada con el
//   oráculo PKHeX (origen que permite más cintas y cadena de evoluciones posible
//   en cada contexto de juego, PKHeX `EvolutionHistory`).
// * Ruta máxima: [RibbonMaster.route]; reglas portadas de PKHeX `RibbonRules` y
//   `RibbonVerifier*` (GPL-3.0) y comprobadas contra PKHeX en
//   `test/ribbon_master_pkhex_test.dart`.

/// Contexto de datos de PKHeX (`EntityContext`) por el que pasa un ejemplar.
enum RibbonContext { gen1, gen2, gen3, gen4, gen5, gen6, gen7, gen7b, gen8, gen8a, gen8b, gen9, gen9a }

/// Cómo se transfiere al siguiente tramo del grafo.
enum TransferLink {
  /// Pal Park (Gen 3 → Gen 4), solo de ida.
  palPark,

  /// Poké Transfer / Transportador Pokémon (Gen 4 → Gen 5), solo de ida.
  pokeTransfer,

  /// Poké Transporter + Banco de Pokémon (Gen 5 → Gen 6/7), solo de ida.
  bank,

  /// Banco de Pokémon → Pokémon HOME, solo de ida.
  bankToHome,

  /// Consola Virtual (Gen 1/2) → Poké Transporter → Gen 7, solo de ida.
  virtualConsole,

  /// Let's Go / GO → Pokémon HOME, solo de ida.
  oneWayHome,

  /// Pokémon HOME (ida y vuelta entre juegos de Switch donde exista la forma).
  home,

  /// Intercambio entre juegos de la misma generación (ida y vuelta).
  trade,
}

/// Juego (o pareja de juegos) del grafo de transferencias. Los ids ([id]) son estables.
enum RibbonGame {
  vc('vc', RibbonContext.gen1, 7, 'Consola Virtual (Gen 1/2)', 'Virtual Console (Gen 1/2)'),
  colosseum('colosseum', RibbonContext.gen3, 3, 'Pokémon Colosseum', 'Pokémon Colosseum'),
  xd('xd', RibbonContext.gen3, 3, 'Pokémon XD: Tempestad Oscura', 'Pokémon XD: Gale of Darkness'),
  rse('rse', RibbonContext.gen3, 3, 'Rubí / Zafiro / Esmeralda', 'Ruby / Sapphire / Emerald'),
  frlg('frlg', RibbonContext.gen3, 3, 'Rojo Fuego / Verde Hoja', 'FireRed / LeafGreen'),
  dppt('dppt', RibbonContext.gen4, 4, 'Diamante / Perla / Platino', 'Diamond / Pearl / Platinum'),
  hgss('hgss', RibbonContext.gen4, 4, 'Oro HeartGold / Plata SoulSilver', 'HeartGold / SoulSilver'),
  bw('bw', RibbonContext.gen5, 5, 'Negro / Blanco / Negro 2 / Blanco 2', 'Black / White / Black 2 / White 2'),
  xy('xy', RibbonContext.gen6, 6, 'X / Y', 'X / Y'),
  oras('oras', RibbonContext.gen6, 6, 'Rubí Omega / Zafiro Alfa', 'Omega Ruby / Alpha Sapphire'),
  smusum('smusum', RibbonContext.gen7, 7, 'Sol / Luna / Ultrasol / Ultraluna', 'Sun / Moon / Ultra Sun / Ultra Moon'),
  lgpe('lgpe', RibbonContext.gen7b, 7, "Let's Go, Pikachu! / Eevee!", "Let's Go, Pikachu! / Eevee!"),
  go('go', RibbonContext.gen8, 8, 'Pokémon GO', 'Pokémon GO'),
  swsh('swsh', RibbonContext.gen8, 8, 'Espada / Escudo', 'Sword / Shield'),
  bdsp('bdsp', RibbonContext.gen8b, 8, 'Diamante Brillante / Perla Reluciente', 'Brilliant Diamond / Shining Pearl'),
  pla('pla', RibbonContext.gen8a, 8, 'Leyendas Pokémon: Arceus', 'Pokémon Legends: Arceus'),
  sv('sv', RibbonContext.gen9, 9, 'Escarlata / Púrpura', 'Scarlet / Violet'),
  za('za', RibbonContext.gen9a, 9, 'Leyendas Pokémon: Z-A', 'Pokémon Legends: Z-A');

  const RibbonGame(this.id, this.context, this.generation, this.nameEs, this.nameEn);
  final String id;
  final RibbonContext context;
  final int generation;
  final String nameEs;
  final String nameEn;

  String name(DataLanguage lang) => lang == DataLanguage.es ? nameEs : nameEn;

  static RibbonGame? byId(String id) {
    for (final g in values) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Juego de origen a partir de la versión de PKHeX (`GameVersion`).
  static RibbonGame? fromPkhexVersion(String v) => switch (v) {
        'RD' || 'GN' || 'BU' || 'YW' || 'RBY' || 'GD' || 'SI' || 'C' || 'GS' || 'GSC' => vc,
        'COLO' => colosseum,
        'XD' || 'CXD' => xd,
        'S' || 'R' || 'E' || 'RS' || 'RSE' => rse,
        'FR' || 'LG' || 'FRLG' => frlg,
        'D' || 'P' || 'Pt' || 'DP' || 'DPPt' => dppt,
        'HG' || 'SS' || 'HGSS' => hgss,
        'B' || 'W' || 'B2' || 'W2' || 'BW' || 'B2W2' => bw,
        'X' || 'Y' || 'XY' => xy,
        'AS' || 'OR' || 'ORAS' => oras,
        'SN' || 'MN' || 'US' || 'UM' || 'SM' || 'USUM' => smusum,
        'GP' || 'GE' || 'GG' => lgpe,
        'GO' => go,
        'SW' || 'SH' || 'SWSH' => swsh,
        'BD' || 'SP' || 'BDSP' => bdsp,
        'PLA' => pla,
        'SL' || 'VL' || 'SV' => sv,
        'ZA' => za,
        _ => null,
      };
}

/// Grafo de transferencias, solo hacia adelante.
abstract final class RibbonGraph {
  /// Orden cronológico de la ruta (los juegos de Switch se pueden alternar por HOME).
  static const List<RibbonGame> order = [
    RibbonGame.vc, RibbonGame.colosseum, RibbonGame.xd, RibbonGame.rse, RibbonGame.frlg, //
    RibbonGame.dppt, RibbonGame.hgss, RibbonGame.bw, RibbonGame.xy, RibbonGame.oras, RibbonGame.smusum,
    RibbonGame.lgpe, RibbonGame.go, RibbonGame.swsh, RibbonGame.bdsp, RibbonGame.pla, RibbonGame.sv, RibbonGame.za,
  ];

  /// Aristas (origen → destino, enlace). Las de [TransferLink.trade] y
  /// [TransferLink.home] son de ida y vuelta; el resto, solo de ida.
  static const List<(RibbonGame, RibbonGame, TransferLink)> edges = [
    (RibbonGame.colosseum, RibbonGame.rse, TransferLink.trade),
    (RibbonGame.xd, RibbonGame.rse, TransferLink.trade),
    (RibbonGame.colosseum, RibbonGame.frlg, TransferLink.trade),
    (RibbonGame.xd, RibbonGame.frlg, TransferLink.trade),
    (RibbonGame.rse, RibbonGame.frlg, TransferLink.trade),
    (RibbonGame.rse, RibbonGame.dppt, TransferLink.palPark),
    (RibbonGame.frlg, RibbonGame.dppt, TransferLink.palPark),
    (RibbonGame.dppt, RibbonGame.hgss, TransferLink.trade),
    (RibbonGame.dppt, RibbonGame.bw, TransferLink.pokeTransfer),
    (RibbonGame.hgss, RibbonGame.bw, TransferLink.pokeTransfer),
    (RibbonGame.bw, RibbonGame.xy, TransferLink.bank),
    (RibbonGame.bw, RibbonGame.oras, TransferLink.bank),
    (RibbonGame.bw, RibbonGame.smusum, TransferLink.bank),
    (RibbonGame.xy, RibbonGame.oras, TransferLink.trade),
    (RibbonGame.xy, RibbonGame.smusum, TransferLink.bank),
    (RibbonGame.oras, RibbonGame.smusum, TransferLink.bank),
    (RibbonGame.vc, RibbonGame.smusum, TransferLink.virtualConsole),
    (RibbonGame.xy, RibbonGame.swsh, TransferLink.bankToHome),
    (RibbonGame.oras, RibbonGame.swsh, TransferLink.bankToHome),
    (RibbonGame.smusum, RibbonGame.swsh, TransferLink.bankToHome),
    (RibbonGame.lgpe, RibbonGame.swsh, TransferLink.oneWayHome),
    (RibbonGame.go, RibbonGame.swsh, TransferLink.oneWayHome),
    (RibbonGame.go, RibbonGame.lgpe, TransferLink.oneWayHome),
    (RibbonGame.swsh, RibbonGame.bdsp, TransferLink.home),
    (RibbonGame.swsh, RibbonGame.pla, TransferLink.home),
    (RibbonGame.swsh, RibbonGame.sv, TransferLink.home),
    (RibbonGame.swsh, RibbonGame.za, TransferLink.home),
    (RibbonGame.bdsp, RibbonGame.pla, TransferLink.home),
    (RibbonGame.bdsp, RibbonGame.sv, TransferLink.home),
    (RibbonGame.bdsp, RibbonGame.za, TransferLink.home),
    (RibbonGame.pla, RibbonGame.sv, TransferLink.home),
    (RibbonGame.pla, RibbonGame.za, TransferLink.home),
    (RibbonGame.sv, RibbonGame.za, TransferLink.home),
  ];

  static bool _twoWay(TransferLink l) => l == TransferLink.trade || l == TransferLink.home;

  /// Juegos alcanzables desde [from] (incluido) siguiendo el grafo.
  static Set<RibbonGame> reachable(RibbonGame from) {
    final out = <RibbonGame>{from};
    var changed = true;
    while (changed) {
      changed = false;
      for (final (a, b, l) in edges) {
        if (out.contains(a) && out.add(b)) changed = true;
        if (_twoWay(l) && out.contains(b) && out.add(a)) changed = true;
      }
    }
    return out;
  }

  /// `true` si [to] es alcanzable desde [from].
  static bool canReach(RibbonGame from, RibbonGame to) => reachable(from).contains(to);

  /// `true` si salir de [game] hacia el siguiente tramo no tiene vuelta.
  static bool isOneWayExit(RibbonGame game) => switch (game) {
        RibbonGame.colosseum || RibbonGame.xd || RibbonGame.rse || RibbonGame.frlg => true,
        RibbonGame.dppt || RibbonGame.hgss || RibbonGame.bw => true,
        // Gen 6 ↔ Gen 7 se pueden mover por el Banco en los dos sentidos; Banco → HOME no.
        RibbonGame.smusum => true,
        RibbonGame.vc || RibbonGame.lgpe || RibbonGame.go => true,
        _ => false,
      };

  /// Enlace de salida de un juego (para los avisos de la guía).
  static TransferLink? exitLink(RibbonGame game) => switch (game) {
        RibbonGame.colosseum || RibbonGame.xd || RibbonGame.rse || RibbonGame.frlg => TransferLink.palPark,
        RibbonGame.dppt || RibbonGame.hgss => TransferLink.pokeTransfer,
        RibbonGame.bw => TransferLink.bank,
        RibbonGame.xy || RibbonGame.oras || RibbonGame.smusum => TransferLink.bankToHome,
        RibbonGame.vc => TransferLink.virtualConsole,
        RibbonGame.lgpe || RibbonGame.go => TransferLink.oneWayHome,
        _ => TransferLink.home,
      };
}

/// Cómo se consigue hoy una cinta.
enum RibbonAvailability {
  /// Jugando (sin conexión o con conexión local).
  playable,

  /// Necesita un servicio en línea que sigue activo (Combate Clasificatorio).
  online,

  /// Dependía de un servicio en línea ya cerrado (Nintendo Wi-Fi Connection).
  closedOnline,

  /// Solo en eventos y repartos.
  event,
}

/// Una cinta del catálogo de la guía.
class RibbonGuideEntry {
  const RibbonGuideEntry(this.key, this.games, this.availability, this.howEs, this.howEn, [this.reqEs = '', this.reqEn = '']);

  /// Nombre de PKHeX (`RibbonChampionKalos`…).
  final String key;

  /// Juegos donde se consigue, en orden.
  final List<RibbonGame> games;
  final RibbonAvailability availability;
  final String howEs, howEn, reqEs, reqEn;

  RibbonInfo? get info => Ribbons.info(key);
  String name(DataLanguage lang) => info?.name(lang) ?? key.replaceFirst('Ribbon', '');
  String how(DataLanguage lang) => lang == DataLanguage.es ? howEs : howEn;
  String requirement(DataLanguage lang) => lang == DataLanguage.es ? reqEs : reqEn;

  /// Cuenta para el máximo (se puede conseguir hoy jugando, con o sin conexión).
  bool get counts => availability == RibbonAvailability.playable || availability == RibbonAvailability.online;

  @override
  String toString() => key;
}

/// Catálogo de cintas de Gen 3 a Gen 9 (datos objetivos; textos propios).
abstract final class RibbonGuide {
  static const _cats = ['Cool', 'Beauty', 'Cute', 'Smart', 'Tough'];
  static const _catEs = {'Cool': 'Carisma', 'Beauty': 'Belleza', 'Cute': 'Dulzura', 'Smart': 'Ingenio', 'Tough': 'Dureza'};
  static const _g3Ranks = [('', 'Normal', 'Normal'), ('Super', 'Alto', 'Super'), ('Hyper', 'Avanzado', 'Hyper'), ('Master', 'Experto', 'Master')];
  static const _g4Ranks = [('', 'Normal', 'Normal'), ('Great', 'Difícil', 'Great'), ('Ultra', 'Superior', 'Ultra'), ('Master', 'Experto', 'Master')];
  static const _daily = ['Alert', 'Shock', 'Downcast', 'Careless', 'Relax', 'Snooze', 'Smile'];
  static const _dayEs = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  static const _dayEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _masterCats = [('Coolness', 'Cool'), ('Beauty', 'Beauty'), ('Cuteness', 'Cute'), ('Cleverness', 'Smart'), ('Toughness', 'Tough')];

  static const _p = RibbonAvailability.playable;
  static const _e = RibbonAvailability.event;

  /// Todas las cintas, en el orden de la guía (de la más antigua a la más nueva).
  static final List<RibbonGuideEntry> all = () {
    const g = RibbonGame.values;
    RibbonGame gm(String id) => g.firstWhere((x) => x.id == id);
    final out = <RibbonGuideEntry>[
      // ---------------------------------------------------------------- Gen 3
      RibbonGuideEntry('RibbonNational', [gm('colosseum'), gm('xd')], _p,
          'Se la gana al purificar un Pokémon oscuro capturado en Colosseum o XD.',
          'Earned when a Shadow Pokémon caught in Colosseum or XD is purified.',
          'Solo para Pokémon oscuros: el ejemplar tiene que venir de una captura a un entrenador oscuro.',
          'Shadow Pokémon only: the specimen must be snagged from a Shadow trainer.'),
      RibbonGuideEntry('RibbonEarth', [gm('colosseum'), gm('xd')], _p,
          'Gana el desafío de 100 combates seguidos del Monte Batalla.', 'Win the 100-battle Mt. Battle challenge.',
          'Origen de Gen 3 (pásalo a la GameCube por intercambio con un juego de GBA).',
          'Gen 3 origin (trade it to the GameCube from a GBA game).'),
      for (final cat in _cats)
        for (final (i, (rank, es, en)) in _g3Ranks.indexed)
          RibbonGuideEntry('RibbonG3$cat$rank', [gm('rse')], _p,
              'Gana el concurso de ${_catEs[cat]} en rango $es.', 'Win the $cat contest at $en Rank.',
              i == 0 ? 'Cualquier especie puede participar.' : 'Antes hay que ganar el rango ${_g3Ranks[i - 1].$2} de ${_catEs[cat]}.',
              i == 0 ? 'Any species can enter.' : 'Win the $cat ${_g3Ranks[i - 1].$3} Rank first.'),
      RibbonGuideEntry('RibbonArtist', [gm('rse')], _p,
          'Tras ganar un concurso de rango Experto, acepta que pinten su retrato en el museo de Ciudad Calagua.',
          'After winning a Master Rank contest, let the Lilycove Museum paint its portrait.',
          'Ganar un concurso de rango Experto con nota alta.', 'Win a Master Rank contest with a high score.'),
      RibbonGuideEntry('RibbonChampionG3', [gm('rse'), gm('frlg')], _p,
          'Entra en el Salón de la Fama con él en el equipo.', 'Enter the Hall of Fame with it in your party.'),
      RibbonGuideEntry('RibbonEffort', [gm('rse'), gm('dppt'), gm('xy'), gm('oras'), gm('smusum'), gm('swsh'), gm('bdsp'), gm('sv')], _p,
          'Enséñaselo con los puntos de esfuerzo al máximo a quien entrega la cinta (en Hoenn, Ciudad Portual).',
          'Show it with maxed effort values to the ribbon giver (in Hoenn, Slateport City).',
          'Puntos de esfuerzo totales al máximo (510).', 'Total effort values maxed (510).'),
      RibbonGuideEntry('RibbonWinning', [gm('rse')], _p,
          'Gana el desafío de nivel 50 de la Torre Batalla (racha de 56 en R/Z o 50 en Esmeralda).',
          'Clear the Battle Tower Lv. 50 challenge (56-win streak in R/S, 50 in Emerald).',
          'Especie admitida en la Torre (no legendarios restringidos) y nivel 50 o menos al conseguirla.',
          'Species allowed in the Tower (no restricted legendaries) and level 50 or lower when earning it.'),
      RibbonGuideEntry('RibbonVictory', [gm('rse')], _p,
          'Gana el desafío de nivel abierto de la Torre Batalla.', 'Clear the Battle Tower Open Level challenge.',
          'Especie admitida en la Torre (no legendarios restringidos).', 'Species allowed in the Tower (no restricted legendaries).'),
      // ---------------------------------------------------------------- Gen 4
      RibbonGuideEntry('RibbonChampionSinnoh', [gm('dppt'), gm('bdsp')], _p,
          'Entra en el Salón de la Fama de Sinnoh con él en el equipo.', 'Enter the Sinnoh Hall of Fame with it in your party.'),
      for (final cat in _cats)
        for (final (i, (rank, es, en)) in _g4Ranks.indexed)
          RibbonGuideEntry('RibbonG4$cat$rank', [gm('dppt')], _p,
              'Gana el Superconcurso de ${_catEs[cat]} en rango $es (Ciudad Corazón).', 'Win the $cat Super Contest at $en Rank (Hearthome City).',
              i == 0 ? 'Todas las especies menos Ditto y Unown.' : 'Antes hay que ganar el rango ${_g4Ranks[i - 1].$2} de ${_catEs[cat]}.',
              i == 0 ? 'Any species except Ditto and Unown.' : 'Win the $cat ${_g4Ranks[i - 1].$3} Rank first.'),
      RibbonGuideEntry('RibbonAbility', [gm('dppt'), gm('hgss')], _p,
          'Gana al As de la Torre Batalla (racha de 21 combates individuales).', 'Beat the Tower Tycoon at the Battle Tower (21-win singles streak).',
          'Especie admitida en el Frente/Torre Batalla.', 'Species allowed in the Battle Tower/Frontier.'),
      RibbonGuideEntry('RibbonAbilityGreat', [gm('dppt'), gm('hgss')], _p,
          'Vuelve a ganar al As de la Torre Batalla (racha de 49 individuales).', 'Beat the Tower Tycoon again (49-win singles streak).',
          'Especie admitida en el Frente/Torre Batalla.', 'Species allowed in the Battle Tower/Frontier.'),
      RibbonGuideEntry('RibbonAbilityDouble', [gm('dppt'), gm('hgss')], _p,
          'Racha de 50 combates dobles en la Torre Batalla.', '50-win Double Battle streak at the Battle Tower.',
          'Especie admitida en el Frente/Torre Batalla.', 'Species allowed in the Battle Tower/Frontier.'),
      RibbonGuideEntry('RibbonAbilityMulti', [gm('dppt'), gm('hgss')], _p,
          'Racha de 50 combates múltiples con un compañero del juego.', '50-win Multi Battle streak with an in-game partner.',
          'Especie admitida en el Frente/Torre Batalla.', 'Species allowed in the Battle Tower/Frontier.'),
      RibbonGuideEntry('RibbonAbilityPair', [gm('dppt'), gm('hgss')], _p,
          'Racha de 50 combates múltiples con un amigo (conexión local entre dos consolas).',
          '50-win Multi Battle streak with a friend (local link between two consoles).',
          'Especie admitida en el Frente/Torre Batalla.', 'Species allowed in the Battle Tower/Frontier.'),
      const RibbonGuideEntry('RibbonAbilityWorld', [RibbonGame.dppt, RibbonGame.hgss], RibbonAvailability.closedOnline,
          'Torre Batalla Wi-Fi (Conexión Wi-Fi de Nintendo, cerrada en 2014).', 'Wi-Fi Battle Tower (Nintendo Wi-Fi Connection, closed in 2014).'),
      RibbonGuideEntry('RibbonLegend', [gm('hgss')], _p,
          'Gana al entrenador legendario de la cima del Monte Plateado.', 'Beat the legendary trainer at the top of Mt. Silver.'),
      RibbonGuideEntry('RibbonFootprint', [gm('dppt'), gm('xy'), gm('oras'), gm('smusum'), gm('bdsp')], _p,
          'Enséñaselo con la amistad al máximo al Dr. Huella (Ruta 213).', 'Show it with maxed friendship to Dr. Footstep (Route 213).',
          'Gen 4: amistad máxima. Después de Gen 4: además, haber subido 30 niveles desde que se capturó (en DBPR, las especies sin voz a cualquier nivel).',
          'Gen 4: max friendship. After Gen 4: it must also have gained 30 levels since it was caught (in BDSP, voiceless species at any level).'),
      for (final (i, d) in _daily.indexed)
        RibbonGuideEntry('Ribbon$d', [gm('dppt'), gm('oras'), gm('bdsp')], _p,
            'Te la dan solo los ${_dayEs[i]} (Ciudad Marina en Sinnoh, Ciudad Malvalona en ROZA).',
            'Given only on ${_dayEn[i]}s (Sunyshore City in Sinnoh, Mauville City in ORAS).',
            'Llevarlo primero del equipo ese día.', 'Have it lead your party that day.'),
      RibbonGuideEntry('RibbonGorgeous', [gm('dppt'), gm('oras'), gm('bdsp')], _p,
          'Cómprala en la tienda de cintas (Ciudad Marina; en ROZA, Ciudad Malvalona).', 'Buy it at the ribbon shop (Sunyshore City; in ORAS, Mauville City).',
          'Precio alto; en Sinnoh, primero esta, luego la Real y por último la Real Deluxe.',
          'Expensive; in Sinnoh you buy this one first, then Royal, then Gorgeous Royal.'),
      RibbonGuideEntry('RibbonRoyal', [gm('dppt'), gm('oras'), gm('bdsp')], _p,
          'Cómprala en la tienda de cintas tras la anterior.', 'Buy it at the ribbon shop after the previous one.',
          'En Sinnoh hace falta tener la cinta Lujo.', 'In Sinnoh it requires the Gorgeous Ribbon.'),
      RibbonGuideEntry('RibbonGorgeousRoyal', [gm('dppt'), gm('oras'), gm('bdsp')], _p,
          'La cinta más cara de la tienda de cintas.', 'The most expensive ribbon at the ribbon shop.',
          'En Sinnoh hacen falta las dos anteriores.', 'In Sinnoh it requires the two previous ones.'),
      // ---------------------------------------------------------------- Gen 6
      RibbonGuideEntry('RibbonChampionKalos', [gm('xy')], _p,
          'Entra en el Salón de la Fama de Kalos con él en el equipo.', 'Enter the Kalos Hall of Fame with it in your party.'),
      RibbonGuideEntry('RibbonTraining', [gm('xy'), gm('oras')], _p,
          'Supera todos los niveles del Superentrenamiento, también los secretos.', 'Clear every Super Training regimen, secret ones included.'),
      RibbonGuideEntry('RibbonBestFriends', [gm('xy'), gm('oras'), gm('smusum'), gm('swsh'), gm('bdsp'), gm('sv')], _p,
          'Lleva el afecto (Poké Recreo / Poké Refresh) o la amistad al máximo y habla con quien da la cinta.',
          'Max its affection (Pokémon-Amie / Refresh) or friendship and talk to the ribbon giver.',
          'Afecto o amistad al máximo.', 'Max affection or friendship.'),
      RibbonGuideEntry('RibbonBattlerSkillful', [gm('xy'), gm('oras')], _p,
          'Gana un desafío de la Maison Batalla (racha de 20).', 'Clear a Battle Maison challenge (20-win streak).',
          'Especie admitida en la Maison (no legendarios restringidos ni singulares).', 'Species allowed in the Maison (no restricted legendaries or mythicals).'),
      RibbonGuideEntry('RibbonBattlerExpert', [gm('xy'), gm('oras')], _p,
          'Gana a la Dama de la Maison en un desafío súper (racha de 50).', 'Beat the Chatelaine in a Super challenge (50-win streak).',
          'Especie admitida en la Maison.', 'Species allowed in the Maison.'),
      RibbonGuideEntry('RibbonChampionG6Hoenn', [gm('oras')], _p,
          'Entra en el Salón de la Fama de Hoenn (ROZA) con él en el equipo.', 'Enter the Hoenn Hall of Fame (ORAS) with it in your party.'),
      for (final (k, cat) in _masterCats)
        RibbonGuideEntry('RibbonMaster$k', [gm('oras'), gm('bdsp')], _p,
            'Gana el concurso de ${_catEs[cat]} en rango Experto (Concursos Pokémon Espectáculo / Superconcursos de DBPR).',
            'Win the $cat contest at Master Rank (Contest Spectaculars / BDSP Super Contest Shows).',
            'Ganar antes los rangos Normal, Alto y Avanzado.', 'Win Normal, Super and Hyper Rank first.'),
      RibbonGuideEntry('RibbonContestStar', [gm('oras'), gm('bdsp')], _p,
          'Se gana sola al conseguir las cinco cintas de concurso de rango Experto.', 'Awarded automatically after winning all five Master Rank contest ribbons.',
          'Las cinco cintas Experto de concurso.', 'All five Master Rank contest ribbons.'),
      // ---------------------------------------------------------------- Gen 7
      RibbonGuideEntry('RibbonChampionAlola', [gm('smusum')], _p,
          'Hazte Campeón de Alola (o defiende el título) con él en el equipo.', 'Become (or defend) the Alola Champion with it in your party.'),
      RibbonGuideEntry('RibbonBattleRoyale', [gm('smusum')], _p,
          'Gana el rango Maestro del Battle Royal (Ciudad Hauoli).', 'Win the Master Rank of the Battle Royal Dome.',
          'Especie admitida en el Árbol Batalla.', 'Species allowed in the Battle Tree.'),
      RibbonGuideEntry('RibbonBattleTreeGreat', [gm('smusum')], _p,
          'Racha de 50 en el Árbol Batalla en modo normal.', '50-win streak in the Battle Tree (regular).',
          'Las especies vetadas solo pueden conseguirla en Ultrasol/Ultraluna.', 'Banned species can only earn it in Ultra Sun/Ultra Moon.'),
      RibbonGuideEntry('RibbonBattleTreeMaster', [gm('smusum')], _p,
          'Racha de 50 en el Árbol Batalla en modo súper.', '50-win streak in the Battle Tree (super).',
          'Especie admitida en el Árbol Batalla.', 'Species allowed in the Battle Tree.'),
      // ---------------------------------------------------------------- Gen 8
      RibbonGuideEntry('RibbonChampionGalar', [gm('swsh')], _p,
          'Gana la Copa de Campeones de Galar con él en el equipo.', 'Win the Galar Champion Cup with it in your party.'),
      RibbonGuideEntry('RibbonTowerMaster', [gm('swsh'), gm('bdsp')], _p,
          'Gana en la Torre Batalla (rango Master Ball en Galar; al As de la torre en DBPR).',
          'Win at the Battle Tower (Master Ball tier in Galar; beat the Tower Tycoon in BDSP).',
          'En DBPR no se admiten singulares.', 'Mythicals are not allowed in BDSP.'),
      const RibbonGuideEntry('RibbonMasterRank', [RibbonGame.swsh, RibbonGame.sv], RibbonAvailability.online,
          'Llega al rango Master Ball en el Combate Clasificatorio con él en el equipo.', 'Reach Master Ball tier in Ranked Battles with it on your team.',
          'Necesita Nintendo Switch Online y que la especie esté permitida en la temporada.',
          'Requires Nintendo Switch Online and the species being allowed that season.'),
      RibbonGuideEntry('RibbonTwinklingStar', [gm('bdsp')], _p,
          'Consigue la puntuación máxima en un Superconcurso Espectáculo de rango Experto.', 'Score perfectly in a Master Rank Super Contest Show.',
          'Tener antes la cinta Estelar de Concursos.', 'It must already have the Contest Star Ribbon.'),
      RibbonGuideEntry('RibbonHisui', [gm('pla')], _p,
          'Hazte una foto con él en el estudio fotográfico de Villa Jubileo.', 'Take a photo with it at the Jubilife Village photo studio.'),
      // ---------------------------------------------------------------- Gen 9
      RibbonGuideEntry('RibbonChampionPaldea', [gm('sv')], _p,
          'Supera el examen de la Liga de Paldea con él en el equipo.', 'Pass the Paldea League exam with it in your party.'),
      // ---------------------------------------------------------------- Evento
      for (final k in const [
        'Country', 'World', 'Classic', 'Premier', 'Event', 'Birthday', 'Special', 'Souvenir', 'Wishing', 'Record',
        'ChampionBattle', 'ChampionRegional', 'ChampionNational', 'ChampionWorld', 'OnceInALifetime', 'Partner',
      ])
        RibbonGuideEntry('Ribbon$k', const [], _e, 'Solo en eventos, repartos o torneos oficiales.',
            'Only from events, distributions or official tournaments.'),
    ];
    return out;
  }();

  static final Map<String, RibbonGuideEntry> _byKey = {for (final e in all) e.key: e};
  static RibbonGuideEntry? entry(String key) => _byKey[key];

  /// Marcas que un ejemplar ya capturado puede ganar en Escarlata/Púrpura.
  static const List<String> postCaptureMarks = ['RibbonMarkItemfinder', 'RibbonMarkPartner', 'RibbonMarkGourmand'];

  /// Marcas de encuentro (solo al capturarlo; como mucho una por ejemplar).
  static List<RibbonInfo> encounterMarks(RibbonGame game) => [
        for (final r in Ribbons.all)
          if (r.encounterMark && r.eras.contains(game == RibbonGame.swsh ? RibbonEra.swsh : RibbonEra.g9)) r,
      ];

  /// Cintas de evento (sección «No disponibles hoy»).
  static Iterable<RibbonGuideEntry> get eventRibbons => all.where((e) => e.availability == RibbonAvailability.event);
}

/// Tipo de encuentro del origen.
enum OriginKind { egg, wild, static, gift, trade, shadow, raid, go, event }

/// Datos de origen y paso por los juegos de una especie/forma (tabla generada).
class RibbonSpeciesData {
  RibbonSpeciesData._(this.species, this.form, this.finalFormat, this.originGeneration, this.originVersion, this.kind,
      this.shadow, this.minLevel, this.chains, this.voicelessBdsp, this.mythical);

  final int species, form;

  /// Formato de PKHeX donde termina la ruta (PK9, PK8…).
  final String finalFormat;
  final int originGeneration;
  final String originVersion;
  final OriginKind kind;
  final bool shadow;
  final int minLevel;

  /// Especie/forma que puede tener en cada contexto (de la más evolucionada a la base).
  final Map<RibbonContext, List<(int, int)>> chains;
  final bool voicelessBdsp, mythical;

  RibbonGame get originGame => RibbonGame.fromPkhexVersion(originVersion) ?? RibbonGame.sv;
  bool visited(RibbonContext c) => chains[c]?.isNotEmpty ?? false;
  (int, int)? head(RibbonContext c) => (chains[c]?.isNotEmpty ?? false) ? chains[c]!.first : null;

  static RibbonSpeciesData? _parse(String line) {
    final p = line.split(',');
    if (p.length < 10) return null;
    final chains = <RibbonContext, List<(int, int)>>{};
    for (final part in p[8].split(';')) {
      final i = part.indexOf('=');
      if (i <= 0) continue;
      final ctx = _ctx(part.substring(0, i));
      if (ctx == null) continue;
      chains[ctx] = [
        for (final sf in part.substring(i + 1).split('/'))
          if (sf.contains('-')) (int.parse(sf.split('-')[0]), int.parse(sf.split('-')[1])),
      ];
    }
    return RibbonSpeciesData._(int.parse(p[0]), int.parse(p[1]), p[2], int.parse(p[3]), p[4],
        OriginKind.values.byName(p[5]), p[6] == '1', int.parse(p[7]), chains, p[9].contains('V'), p[9].contains('M'));
  }

  static RibbonContext? _ctx(String s) => switch (s) {
        'Gen1' => RibbonContext.gen1,
        'Gen2' => RibbonContext.gen2,
        'Gen3' => RibbonContext.gen3,
        'Gen4' => RibbonContext.gen4,
        'Gen5' => RibbonContext.gen5,
        'Gen6' => RibbonContext.gen6,
        'Gen7' => RibbonContext.gen7,
        'Gen7b' => RibbonContext.gen7b,
        'Gen8' => RibbonContext.gen8,
        'Gen8a' => RibbonContext.gen8a,
        'Gen8b' => RibbonContext.gen8b,
        'Gen9' => RibbonContext.gen9,
        'Gen9a' => RibbonContext.gen9a,
        _ => null,
      };
}

/// Aviso de un tramo de la ruta.
enum RouteNoteKind { oneWay, formAppears, evolveHere, beforeEvolving, homeFree }

class RouteNote {
  const RouteNote(this.kind, {this.link, this.game, this.stage});
  final RouteNoteKind kind;
  final TransferLink? link;
  final RibbonGame? game;
  final (int, int)? stage;

  String text(DataLanguage lang) {
    final es = lang == DataLanguage.es;
    final st = stage == null ? '' : SpeciesForms.displayName(stage!.$1, stage!.$2, null, lang);
    return switch (kind) {
      RouteNoteKind.oneWay => es
          ? 'Transfiere solo cuando termines este juego: ${_linkEs(link)} es de ida y no hay vuelta.'
          : "Only transfer once you finish this game: ${_linkEn(link)} is one-way, there's no coming back.",
      RouteNoteKind.formAppears => es
          ? '$st no existe antes de ${game?.name(lang) ?? ''}: hasta entonces viaja como su preevolución.'
          : "$st doesn't exist before ${game?.name(lang) ?? ''}: until then it travels as its pre-evolution.",
      RouteNoteKind.evolveHere => es ? 'Aquí ya puede ser $st.' : 'From here it can be $st.',
      RouteNoteKind.beforeEvolving => es
          ? 'Aquí solo puede estar como $st: visita este juego antes de evolucionarlo.'
          : 'It can only be $st here: visit this game before evolving it.',
      RouteNoteKind.homeFree => es
          ? 'Desde aquí puedes ir y volver entre juegos de Switch con Pokémon HOME.'
          : 'From here you can move back and forth between Switch games with Pokémon HOME.',
    };
  }

  static String _linkEs(TransferLink? l) => switch (l) {
        TransferLink.palPark => 'el Parque Compi',
        TransferLink.pokeTransfer => 'el Pokétransfer',
        TransferLink.bank || TransferLink.virtualConsole => 'el Poké Transporter',
        TransferLink.bankToHome => 'el paso del Banco a HOME',
        TransferLink.oneWayHome => 'el paso a HOME',
        _ => 'la transferencia',
      };
  static String _linkEn(TransferLink? l) => switch (l) {
        TransferLink.palPark => 'Pal Park',
        TransferLink.pokeTransfer => 'Poké Transfer',
        TransferLink.bank || TransferLink.virtualConsole => 'Poké Transporter',
        TransferLink.bankToHome => 'moving from Bank to HOME',
        TransferLink.oneWayHome => 'moving to HOME',
        _ => 'the transfer',
      };
}

/// Un tramo de la ruta: un juego, la forma en que puede estar y las cintas que gana ahí.
class RouteStep {
  RouteStep(this.game, this.stages);
  final RibbonGame game;

  /// Especies/formas que puede tener en este juego (de la más evolucionada a la base).
  final List<(int, int)> stages;
  final List<RibbonGuideEntry> ribbons = [];

  /// Cintas que ya se pudieron ganar antes pero también están aquí.
  final List<RibbonGuideEntry> alsoHere = [];
  final List<RouteNote> notes = [];
  final List<String> marks = [];

  int get count => ribbons.where((r) => r.counts).length;
}

/// Ruta máxima de cintas de una especie/forma.
class RibbonRoute {
  RibbonRoute(this.data, this.steps, this.unavailable, this.legalKeys);
  final RibbonSpeciesData data;
  final List<RouteStep> steps;

  /// Cintas que no se pueden conseguir hoy (servicios cerrados y eventos).
  final List<RibbonGuideEntry> unavailable;

  /// Todas las cintas que la ruta da por legales (incluidas las de servicios cerrados).
  final Set<String> legalKeys;

  int get species => data.species;
  int get form => data.form;

  /// Máximo obtenible hoy (jugando, con o sin conexión).
  int get total => steps.fold(0, (a, s) => a + s.count);

  /// Cintas que se ven en el juego final: las de concurso y combate de Gen 3/4
  /// pasan a ser las cintas Recuerdo de Concurso y Recuerdo de Combate.
  int get visibleInFinalGame {
    final old = steps.where((s) => s.game.generation <= 4 && s.game != RibbonGame.vc).expand((s) => s.ribbons).where((r) => r.counts);
    final contest = old.where((r) => r.key.startsWith('RibbonG3') || r.key.startsWith('RibbonG4')).length;
    final battle = old.where((r) => r.key.startsWith('RibbonAbility') || r.key == 'RibbonWinning' || r.key == 'RibbonVictory').length;
    return total - contest - battle + (contest > 0 ? 1 : 0) + (battle > 0 ? 1 : 0);
  }

  /// Valor del Recuerdo de Concurso / Combate al llegar a Gen 6.
  (int, int) get memoryCounts {
    final keys = legalKeys;
    final contest = keys.where((k) => k.startsWith('RibbonG3') || k.startsWith('RibbonG4')).length;
    final battle = keys.where((k) => k.startsWith('RibbonAbility') || k == 'RibbonWinning' || k == 'RibbonVictory').length;
    return (contest, battle);
  }

  /// Marcas que puede ganar ya capturado (no suman).
  List<String> get postCaptureMarks => steps.expand((s) => s.marks).toList();

  /// Juegos de captura con marcas de encuentro (si se captura allí; como mucho una).
  List<RibbonGame> get markGames => [
        for (final g in const [RibbonGame.swsh, RibbonGame.sv])
          if (SpeciesForms.isPresent(species, form, g == RibbonGame.swsh ? _swsh : _sv)) g,
      ];
  static const _swsh = GameVersion.swordShield;
  static const _sv = GameVersion.scarletViolet;

  /// Juego donde aparece por primera vez la forma de la especie.
  RibbonGame? get formFirstGame {
    for (final s in steps) {
      if (s.stages.any((e) => e.$1 == species && e.$2 == form)) return s.game;
    }
    return null;
  }

  /// Texto plano para compartir en foros.
  String toText(DataLanguage lang) {
    final es = lang == DataLanguage.es;
    final b = StringBuffer();
    final name = SpeciesForms.displayName(species, form, null, lang);
    b.writeln(es ? 'Ribbon Master: $name' : 'Ribbon Master: $name');
    b.writeln(es
        ? 'Máximo de cintas hoy: $total · Origen recomendado: ${data.originGame.name(lang)} (Gen ${data.originGame.generation})'
        : 'Max ribbons today: $total · Recommended origin: ${data.originGame.name(lang)} (Gen ${data.originGame.generation})');
    for (final s in steps) {
      if (s.ribbons.isEmpty && s.notes.isEmpty) continue;
      b.writeln();
      b.writeln('## ${s.game.name(lang)} (Gen ${s.game.generation}) — ${s.count}');
      for (final r in s.ribbons) {
        final tag = r.availability == RibbonAvailability.online ? (es ? ' [en línea]' : ' [online]') : '';
        b.writeln('- ${r.name(lang)}$tag: ${r.how(lang)}');
      }
      for (final n in s.notes) {
        b.writeln('  ! ${n.text(lang)}');
      }
    }
    if (unavailable.isNotEmpty) {
      b.writeln();
      b.writeln(es ? '## No disponibles hoy' : '## Not available today');
      b.writeln(unavailable.map((r) => r.name(lang)).join(', '));
    }
    b.writeln();
    b.writeln(es ? 'Generado con PKArkTools (datos verificados con PKHeX).' : 'Made with PKArkTools (data checked against PKHeX).');
    return b.toString();
  }
}

/// Puesto en el ranking (los empates comparten puesto).
class RibbonRankEntry {
  const RibbonRankEntry(this.position, this.route, {required this.tied});
  final int position;
  final RibbonRoute route;
  final bool tied;
}

/// Motor de Ribbon Master.
abstract final class RibbonMaster {
  static Map<(int, int), RibbonSpeciesData>? _data;

  static Map<(int, int), RibbonSpeciesData> get _table => _data ??= () {
        final out = <(int, int), RibbonSpeciesData>{};
        for (final line in kRibbonRoutes.split('\n')) {
          final d = RibbonSpeciesData._parse(line);
          if (d != null) out[(d.species, d.form)] = d;
        }
        return out;
      }();

  /// Especies y formas con guía, en orden de Dex.
  static List<(int, int)> get targets => _table.keys.toList()..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);

  static RibbonSpeciesData? data(int species, int form) => _table[(species, form)];

  static bool has(int species, int form) => _table.containsKey((species, form));

  static final Map<(int, int), RibbonRoute> _routes = {};

  /// Ruta máxima de la especie/forma (null si no hay datos).
  static RibbonRoute? route(int species, int form) {
    final cached = _routes[(species, form)];
    if (cached != null) return cached;
    final d = _table[(species, form)];
    if (d == null) return null;
    return _routes[(species, form)] = _build(d);
  }

  // PKHeX `RibbonRules.BattleFrontierBanlist`.
  static const Set<int> _frontierBan = {
    150, 151, 249, 250, 251, 382, 383, 384, 385, 386, 483, 484, 487, 489, 490, 491, 492, 493, //
    494, 643, 644, 646, 647, 648, 649, 716, 717, 718, 719, 720, 721, 789, 790, 791, 792, 800, 801, 802, 807,
    808, 809, 1007, 1008,
  };
  static bool frontierAllowed(int species) => !_frontierBan.contains(species);

  static bool _contest4Allowed((int, int)? h) => h != null && h.$1 != 132 && h.$1 != 201 && !(h.$1 == 172 && h.$2 == 1);

  /// Cintas legales por juego (reglas de PKHeX `RibbonRules`/`RibbonVerifier*`).
  static Map<RibbonGame, List<String>> _ribbonsByGame(RibbonSpeciesData d) {
    final out = <RibbonGame, List<String>>{};
    void add(RibbonGame g, Iterable<String> keys) => out.putIfAbsent(g, () => []).addAll(keys);
    final origin = d.originGame;
    final spiky = d.species == 172 && d.form == 1;
    final levelGain = d.minLevel <= 70; // Huella después de Gen 4: +30 niveles
    // Gen 3
    if (d.visited(RibbonContext.gen3)) {
      final h3 = d.head(RibbonContext.gen3)!;
      final gc = <String>[];
      if (d.shadow) gc.add('RibbonNational');
      if (d.originGeneration == 3) gc.add('RibbonEarth');
      if (gc.isNotEmpty) add(origin == RibbonGame.colosseum ? RibbonGame.colosseum : RibbonGame.xd, gc);
      add(RibbonGame.rse, [
        for (final c in RibbonGuide._cats)
          for (final r in RibbonGuide._g3Ranks) 'RibbonG3$c${r.$1}',
        'RibbonArtist', 'RibbonChampionG3', 'RibbonEffort',
        if (frontierAllowed(h3.$1) && d.minLevel <= 50) 'RibbonWinning',
        if (frontierAllowed(h3.$1)) 'RibbonVictory',
      ]);
      add(RibbonGame.frlg, ['RibbonChampionG3']);
    }
    // Gen 4
    if (d.visited(RibbonContext.gen4)) {
      final h4 = d.head(RibbonContext.gen4);
      final bf = h4 != null && frontierAllowed(h4.$1) && !spiky;
      add(RibbonGame.dppt, [
        if (!spiky) 'RibbonChampionSinnoh',
        if (_contest4Allowed(h4))
          for (final c in RibbonGuide._cats)
            for (final r in RibbonGuide._g4Ranks) 'RibbonG4$c${r.$1}',
        if (bf) ...['RibbonAbility', 'RibbonAbilityGreat', 'RibbonAbilityDouble', 'RibbonAbilityMulti', 'RibbonAbilityPair', 'RibbonAbilityWorld'],
        'RibbonFootprint', 'RibbonEffort',
        for (final k in RibbonGuide._daily) 'Ribbon$k',
        if (!spiky) ...['RibbonGorgeous', 'RibbonRoyal', 'RibbonGorgeousRoyal'],
      ]);
      add(RibbonGame.hgss, [
        'RibbonLegend',
        if (bf) ...['RibbonAbility', 'RibbonAbilityGreat', 'RibbonAbilityDouble', 'RibbonAbilityMulti', 'RibbonAbilityPair', 'RibbonAbilityWorld'],
      ]);
    }
    final early = d.visited(RibbonContext.gen3) || d.visited(RibbonContext.gen4);
    // Gen 6
    if (d.visited(RibbonContext.gen6)) {
      final maison = frontierAllowed(d.species);
      final cosplay = d.species == 25 && d.form != 0 && d.originGame == RibbonGame.oras;
      add(RibbonGame.xy, [
        if (!cosplay) 'RibbonChampionKalos',
        'RibbonTraining', 'RibbonBestFriends', 'RibbonEffort',
        if (maison) ...['RibbonBattlerSkillful', 'RibbonBattlerExpert'],
        if (early || levelGain) 'RibbonFootprint',
      ]);
      add(RibbonGame.oras, [
        'RibbonChampionG6Hoenn',
        for (final (k, _) in RibbonGuide._masterCats) 'RibbonMaster$k',
        'RibbonContestStar',
        for (final k in RibbonGuide._daily) 'Ribbon$k',
        'RibbonGorgeous', 'RibbonRoyal', 'RibbonGorgeousRoyal',
        'RibbonTraining', 'RibbonBestFriends', 'RibbonEffort',
        if (maison) ...['RibbonBattlerSkillful', 'RibbonBattlerExpert'],
      ]);
    }
    // Gen 7
    if (d.visited(RibbonContext.gen7)) {
      final h7 = d.head(RibbonContext.gen7)!;
      final tree = frontierAllowed(h7.$1);
      add(RibbonGame.smusum, [
        'RibbonChampionAlola',
        if (tree) 'RibbonBattleRoyale',
        'RibbonBattleTreeGreat',
        if (tree) 'RibbonBattleTreeMaster',
        'RibbonBestFriends', 'RibbonEffort',
        if (early || levelGain) 'RibbonFootprint',
      ]);
    }
    // Espada/Escudo
    if (d.visited(RibbonContext.gen8)) {
      // Los singulares con fecha de servidor (GO, regalos) solo pudieron usarse en la Serie 13
      // (hasta noviembre de 2022): Marshadow y Zeraora llegaron a GO después.
      final dated = d.mythical && (d.kind == OriginKind.go || d.kind == OriginKind.event) && _lateGoMythicals.contains(d.species);
      add(RibbonGame.swsh, ['RibbonChampionGalar', 'RibbonTowerMaster', if (!dated) 'RibbonMasterRank', 'RibbonEffort', 'RibbonBestFriends']);
    }
    // DBPR
    if (d.visited(RibbonContext.gen8b)) {
      final h8b = d.head(RibbonContext.gen8b)!;
      add(RibbonGame.bdsp, [
        'RibbonChampionSinnoh',
        for (final (k, _) in RibbonGuide._masterCats) 'RibbonMaster$k',
        'RibbonContestStar', 'RibbonTwinklingStar',
        if (!_mythical.contains(h8b.$1)) 'RibbonTowerMaster',
        for (final k in RibbonGuide._daily) 'Ribbon$k',
        'RibbonGorgeous', 'RibbonRoyal', 'RibbonGorgeousRoyal',
        'RibbonEffort', 'RibbonBestFriends',
        if (early || d.voicelessBdsp || levelGain) 'RibbonFootprint',
      ]);
    }
    if (d.visited(RibbonContext.gen8a)) add(RibbonGame.pla, ['RibbonHisui']);
    if (d.visited(RibbonContext.gen9)) {
      final ash = d.species == 658 && d.form != 0;
      add(RibbonGame.sv, ['RibbonChampionPaldea', if (!ash) 'RibbonMasterRank', 'RibbonEffort', 'RibbonBestFriends']);
    }
    return out;
  }

  static const Set<int> _lateGoMythicals = {802, 807};

  // PKHeX `SpeciesCategory.IsMythical`.
  static const Set<int> _mythical = {151, 251, 385, 386, 489, 490, 491, 492, 493, 494, 647, 648, 649, 719, 720, 721, 801, 802, 807, 808, 809, 893, 1025};

  static List<(int, int)> _stagesFor(RibbonSpeciesData d, RibbonGame g) => switch (g) {
        RibbonGame.vc => d.chains[RibbonContext.gen2] ?? d.chains[RibbonContext.gen1] ?? const [],
        RibbonGame.go => const [],
        _ => d.chains[g.context] ?? const [],
      };

  static RibbonRoute _build(RibbonSpeciesData d) {
    final byGame = _ribbonsByGame(d);
    final origin = d.originGame;
    final steps = <RouteStep>[];
    final earned = <String>{};
    final legal = <String>{for (final l in byGame.values) ...l};
    final reach = RibbonGraph.reachable(origin);
    for (final g in RibbonGraph.order) {
      final isOrigin = g == origin;
      var stages = _stagesFor(d, g);
      if (g == RibbonGame.go && isOrigin) stages = [(d.species, d.form)];
      // Juegos de Gen 3 distintos del origen: solo si aportan algo (GameCube para la Tierra).
      final keys = byGame[g] ?? const <String>[];
      if (!isOrigin) {
        if (stages.isEmpty || !reach.contains(g)) continue;
        if (g == RibbonGame.vc || g == RibbonGame.lgpe || g == RibbonGame.go || g == RibbonGame.colosseum) continue;
        if (g == RibbonGame.xd && keys.isEmpty) continue;
        if (g == RibbonGame.frlg && origin != RibbonGame.frlg) continue;
        if (g == RibbonGame.za && keys.isEmpty && !d.visited(RibbonContext.gen9a)) continue;
      }
      final step = RouteStep(g, stages);
      if (g == RibbonGame.sv) step.marks.addAll(RibbonGuide.postCaptureMarks);
      steps.add(step);
    }
    // Los juegos de GameCube van antes que los de GBA si son el origen; si no, después.
    final gcIndex = steps.indexWhere((s) => s.game == RibbonGame.xd && s.game != origin);
    if (gcIndex >= 0) {
      final gc = steps.removeAt(gcIndex);
      final after = steps.lastIndexWhere((s) => s.game == RibbonGame.rse || s.game == RibbonGame.frlg);
      steps.insert(after + 1, gc);
    }
    // El juego de origen va primero (p. ej. Rojo Fuego antes que Esmeralda).
    final oi = steps.indexWhere((s) => s.game == origin);
    if (oi > 0) steps.insert(0, steps.removeAt(oi));
    // Las cintas se asignan al primer juego de la ruta donde se pueden ganar.
    for (final s in steps) {
      s.ribbons.clear();
      s.alsoHere.clear();
      for (final e in [for (final k in byGame[s.game] ?? const <String>[]) ?RibbonGuide.entry(k)]) {
        if (earned.add(e.key)) {
          s.ribbons.add(e);
        } else if (!s.alsoHere.contains(e)) {
          s.alsoHere.add(e);
        }
      }
    }
    // Avisos.
    (int, int)? prevHead;
    final target = (d.species, d.form);
    var formShown = false;
    for (final (i, s) in steps.indexed) {
      final head = s.stages.isEmpty ? null : s.stages.first;
      if (!formShown && s.stages.contains(target)) {
        formShown = true;
        if (i > 0) {
          s.notes.add(RouteNote(RouteNoteKind.formAppears, game: s.game, stage: target));
        }
      } else if (formShown && head != null && head != target) {
        s.notes.add(RouteNote(RouteNoteKind.beforeEvolving, stage: head));
      } else if (head != null && prevHead != null && head != prevHead && head != target) {
        s.notes.add(RouteNote(RouteNoteKind.evolveHere, stage: head));
      }
      prevHead = head ?? prevHead;
      final next = i + 1 < steps.length ? steps[i + 1] : null;
      if (next != null && RibbonGraph.isOneWayExit(s.game) && next.game.context != s.game.context) {
        s.notes.add(RouteNote(RouteNoteKind.oneWay, link: RibbonGraph.exitLink(s.game)));
      }
      if (next != null && s.game.generation <= 7 && next.game.generation >= 8 && next.game != RibbonGame.lgpe) {
        next.notes.add(const RouteNote(RouteNoteKind.homeFree));
      }
    }
    // Contexto Gen 3 con la cinta de la GameCube: el aviso de ida va en el último juego de Gen 3.
    final unavailable = <RibbonGuideEntry>[
      for (final k in legal)
        if (RibbonGuide.entry(k) case final e? when e.availability == RibbonAvailability.closedOnline) e,
      ...RibbonGuide.eventRibbons,
    ];
    return RibbonRoute(d, steps, unavailable, legal);
  }

  static List<RibbonRankEntry>? _ranking;

  /// Todas las especies/formas ordenadas por el máximo de cintas (empates en el mismo puesto,
  /// desempate por número de Dex y forma).
  static List<RibbonRankEntry> ranking() => _ranking ??= () {
        final routes = [for (final t in targets) route(t.$1, t.$2)!];
        routes.sort((a, b) {
          final c = b.total.compareTo(a.total);
          if (c != 0) return c;
          if (a.species != b.species) return a.species - b.species;
          return a.form - b.form;
        });
        final out = <RibbonRankEntry>[];
        for (final (i, r) in routes.indexed) {
          final pos = i > 0 && routes[i - 1].total == r.total ? out[i - 1].position : i + 1;
          final tied = (i > 0 && routes[i - 1].total == r.total) || (i + 1 < routes.length && routes[i + 1].total == r.total);
          out.add(RibbonRankEntry(pos, r, tied: tied));
        }
        return out;
      }();

  /// Las [n] primeras entradas del ranking (con su puesto compartido si hay empate).
  static List<RibbonRankEntry> top(int n) {
    final all = ranking();
    return all.length <= n ? all : all.sublist(0, n);
  }

  /// Cuántas especies/formas más empatan con la última de [top] y quedan fuera.
  static int tiedBeyond(int n) {
    final all = ranking();
    if (all.length <= n) return 0;
    final last = all[n - 1].route.total;
    return all.skip(n).takeWhile((e) => e.route.total == last).length;
  }
}
