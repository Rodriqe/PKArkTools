import '../data/game_data.dart';
import '../data/species.dart';
import '../model/game.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import 'balls.dart';
import 'encounters.dart';
import 'origin.dart';
import 'plus_moves.dart';

/// Gravedad de un aviso. Ninguno bloquea al usuario.
enum LegalitySeverity {
  /// Imposible o muy sospechoso en una partida normal.
  warning,

  /// Poco habitual, pero puede tener explicación (evento, traspaso…).
  notice,
}

/// Tipo de aviso de legalidad.
enum LegalityCode {
  speciesNotInGame,
  levelOutOfRange,
  levelBelowMet,
  ivOutOfRange,
  evOutOfRange,
  evTotalTooHigh,
  moveNotInGame,
  moveNotLearnable,
  moveDuplicate,
  noMoves,
  ppTooHigh,
  itemNotInGame,
  abilityNotPossible,
  genderImpossible,
  ballInvalid,
  encounterNotInGame,
  encounterWrongLocation,
  encounterWrongLevel,
  natureInvalid,
  // ---- orígenes y encuentros (Fase 3)
  originVersionMissing,
  originFromFuture,
  ballTooNew,
  ballOnlyInLegends,
  ballRequiredInLegends,
  cherishWithoutEvent,
  hiddenAbilityOldOrigin,
  shinyLocked,
  relearnInvalid,
  eventSpeciesNotFateful,
  metLevelInvalid,
  // ---- integridad de datos que el juego comprueba (PKHeX `MiscDateVerifier`, `MiscVerifierPK9/PA9`)
  metDateInvalid,
  obedienceLevelInvalid,
  // ---- Leyendas Z-A: flags de movimientos «plus» (PKHeX `LegendsZAVerifier`)
  plusMoveMissing,
  plusMoveInvalid,
}

/// Agrupación de avisos en la vista detallada.
enum LegalityArea { encounter, origin, moves, stats, misc }

/// Corrección automática "segura": solo toca el campo del aviso.
enum LegalityFix { ball, ability, shiny, relearn, moves, level, metLevel, evs, ivs, pp, duplicateMove, metDate, obedienceLevel, plusFlags }

/// Un aviso concreto sobre un Pokémon.
class LegalityIssue {
  const LegalityIssue(this.code, this.severity, {this.field, this.args = const {}, this.fix});

  final LegalityCode code;
  final LegalitySeverity severity;

  /// Corrección segura disponible (null = hay que revisarlo a mano).
  final LegalityFix? fix;

  LegalityArea get area => switch (code) {
        LegalityCode.originVersionMissing ||
        LegalityCode.originFromFuture ||
        LegalityCode.ballTooNew ||
        LegalityCode.ballOnlyInLegends ||
        LegalityCode.ballRequiredInLegends ||
        LegalityCode.cherishWithoutEvent ||
        LegalityCode.hiddenAbilityOldOrigin ||
        LegalityCode.shinyLocked ||
        LegalityCode.eventSpeciesNotFateful ||
        LegalityCode.metLevelInvalid ||
        LegalityCode.metDateInvalid ||
        LegalityCode.obedienceLevelInvalid ||
        LegalityCode.levelBelowMet ||
        LegalityCode.ballInvalid =>
          LegalityArea.origin,
        LegalityCode.encounterNotInGame || LegalityCode.encounterWrongLocation || LegalityCode.encounterWrongLevel =>
          LegalityArea.encounter,
        LegalityCode.moveNotInGame ||
        LegalityCode.moveNotLearnable ||
        LegalityCode.moveDuplicate ||
        LegalityCode.noMoves ||
        LegalityCode.ppTooHigh ||
        LegalityCode.relearnInvalid ||
        LegalityCode.plusMoveMissing ||
        LegalityCode.plusMoveInvalid =>
          LegalityArea.moves,
        LegalityCode.ivOutOfRange || LegalityCode.evOutOfRange || LegalityCode.evTotalTooHigh || LegalityCode.levelOutOfRange =>
          LegalityArea.stats,
        _ => LegalityArea.misc,
      };

  /// Explicación larga: por qué importa y qué se puede hacer.
  String detail([DataLanguage lang = DataLanguage.es]) {
    final es = lang == DataLanguage.es;
    String a(String k) => '${args[k] ?? ''}';
    return switch (code) {
      LegalityCode.originVersionMissing => es
          ? 'El campo "juego de origen" está vacío. Todos los Pokémon de Gen 3 en adelante registran en qué juego se encontraron; un valor vacío suele venir de un editor o de un traspaso roto.'
          : 'The origin game field is empty. Every Pokémon from Gen 3 onwards records the game it was met in; an empty value usually comes from an editor or a broken transfer.',
      LegalityCode.originFromFuture => es
          ? 'Dice venir de ${a('origin')} (Gen ${a('originGen')}), un juego posterior a este formato (Gen ${a('gen')}). Un Pokémon no puede viajar hacia atrás entre generaciones.'
          : 'It claims to come from ${a('origin')} (Gen ${a('originGen')}), newer than this format (Gen ${a('gen')}). Pokémon cannot travel back between generations.',
      LegalityCode.encounterNotInGame => es
          ? '${a('species')} (ni sus preevoluciones) no aparece en las tablas de encuentros de ${a('origin')}: ni salvaje, ni estático, ni regalo, ni intercambio. Puede venir de un evento, de un huevo mal registrado o de una edición. ${a('scope')}'
          : '${a('species')} (and its pre-evolutions) does not appear in the encounter tables of ${a('origin')}: not wild, static, gift or trade. It may come from an event, a mis-recorded egg or an edit. ${a('scope')}',
      LegalityCode.encounterWrongLocation => es
          ? 'Se registró en ${a('location')}, pero en ${a('origin')} ${a('species')} solo se encuentra en: ${a('places')}. El lugar de encuentro no se corrige automáticamente porque no hay forma segura de saber cuál era. ${a('scope')}'
          : 'It was recorded at ${a('location')}, but in ${a('origin')} ${a('species')} is only found at: ${a('places')}. The met location is not fixed automatically because there is no safe way to know the right one. ${a('scope')}',
      LegalityCode.encounterWrongLevel => es
          ? 'En ${a('location')} (${a('origin')}) ${a('species')} aparece a ${a('levels')}, pero el nivel de encuentro registrado es ${a('met')}. ${a('fixNote')}'
          : 'At ${a('location')} (${a('origin')}) ${a('species')} appears at ${a('levels')}, but the recorded met level is ${a('met')}. ${a('fixNote')}',
      LegalityCode.ballInvalid => es
          ? '${a('ball')} no existe en ${a('game')} ni puede llegar con un traspaso (por ejemplo, las Balls de Hisui solo existen en Leyendas Arceus y en juegos que reciben Pokémon de HOME). Corregir pone la Poké Ball del juego.'
          : '${a('ball')} does not exist in ${a('game')} and cannot arrive through a transfer (e.g. Hisuian balls only exist in Legends: Arceus and in games that receive Pokémon from HOME). Fixing sets the game\'s Poké Ball.',
      LegalityCode.ballTooNew => es
          ? '${a('ball')} apareció en la Gen ${a('ballGen')}, pero este Pokémon se encontró en ${a('origin')} (Gen ${a('originGen')}). Corregir pone una Poké Ball normal.'
          : '${a('ball')} was introduced in Gen ${a('ballGen')}, but this Pokémon was met in ${a('origin')} (Gen ${a('originGen')}). Fixing sets a regular Poké Ball.',
      LegalityCode.ballOnlyInLegends => es
          ? 'Las Balls de estilo Hisui solo existen en Leyendas Pokémon: Arceus. Corregir pone una Poké Ball normal.'
          : 'Hisuian-style balls only exist in Pokémon Legends: Arceus. Fixing sets a regular Poké Ball.',
      LegalityCode.ballRequiredInLegends => es
          ? 'Los Pokémon capturados en Leyendas Arceus usan las Balls de Hisui. Corregir pone la Poké Ball de Hisui.'
          : 'Pokémon caught in Legends: Arceus use Hisuian balls. Fixing sets the Hisuian Poké Ball.',
      LegalityCode.cherishWithoutEvent => es
          ? 'La Gloria Ball solo se usa en Pokémon de evento, que llevan la marca de encuentro fatídico. Aquí falta esa marca.'
          : 'The Cherish Ball is only used for event Pokémon, which carry the fateful-encounter flag. That flag is missing here.',
      LegalityCode.hiddenAbilityOldOrigin => es
          ? 'Las habilidades ocultas llegaron en la Gen 5. Un Pokémon de ${a('origin')} no puede tenerla. Corregir elige la primera habilidad normal.'
          : 'Hidden abilities arrived in Gen 5. A Pokémon from ${a('origin')} cannot have one. Fixing picks the first regular ability.',
      LegalityCode.shinyLocked => es
          ? 'En ${a('origin')} todos los encuentros de ${a('species')} tienen el variocolor bloqueado. Corregir lo hace normal conservando naturaleza y género.'
          : 'In ${a('origin')} every ${a('species')} encounter is shiny-locked. Fixing makes it non-shiny, keeping nature and gender.',
      LegalityCode.relearnInvalid => es
          ? '${a('move')} figura como movimiento recordable, pero ${a('species')} no lo aprende por nivel ni huevo. Corregir lo quita de la lista de recordables (no de sus movimientos actuales).'
          : '${a('move')} is listed as a relearn move, but ${a('species')} does not learn it by level or egg. Fixing removes it from the relearn list (not from its current moves).',
      LegalityCode.eventSpeciesNotFateful => es
          ? '${a('species')} solo se obtiene en eventos en ${a('origin')}, y esos Pokémon llevan la marca de encuentro fatídico.'
          : '${a('species')} is event-only in ${a('origin')}, and those Pokémon carry the fateful-encounter flag.',
      LegalityCode.metLevelInvalid => es
          ? 'El nivel de encuentro (${a('met')}) no es válido: debe estar entre 1 y 100 salvo en huevos.'
          : 'The met level (${a('met')}) is invalid: it must be 1–100 except for eggs.',
      LegalityCode.metDateInvalid => es
          ? 'Tiene lugar de encuentro pero la fecha de encuentro está vacía o no existe (p. ej. 00/00/00). Los juegos guardan siempre la fecha; un valor así suele venir de un editor y el juego puede negarse a cargar el save. Corregir pone la fecha de hoy.'
          : 'It has a met location but the met date is empty or impossible (e.g. 00/00/00). Games always store the date; such a value usually comes from an editor and the game may refuse to load the save. Fixing sets today\'s date.',
      LegalityCode.obedienceLevelInvalid => es
          ? 'En Gen 9 el nivel de obediencia (${a('obey')}) debe estar entre el nivel de encuentro (${a('met')}) y el nivel actual (${a('level')}). Corregir lo iguala al nivel de encuentro.'
          : 'In Gen 9 the obedience level (${a('obey')}) must be between the met level (${a('met')}) and the current level (${a('level')}). Fixing sets it to the met level.',
      LegalityCode.plusMoveMissing => es
          ? 'En Leyendas Z-A cada movimiento se vuelve «plus» al llegar a cierto nivel, y el juego lo marca solo. A este Pokémon le falta la marca de: ${a('moves')}. Corregir pone las marcas que tocan por su nivel y quita las imposibles.'
          : 'In Legends: Z-A every move becomes a Plus move at a given level, and the game flags it automatically. This Pokémon lacks the flag for: ${a('moves')}. Fixing sets the flags due at its level and clears impossible ones.',
      LegalityCode.plusMoveInvalid => es
          ? 'Tiene la marca «plus» de movimientos que no puede aprender en Leyendas Z-A a su nivel (ni por MT ni por nivel): ${a('moves')}. Corregir quita esas marcas.'
          : 'It has the Plus flag for moves it cannot learn in Legends: Z-A at its level (neither by TM nor by level-up): ${a('moves')}. Fixing clears those flags.',
      LegalityCode.moveNotLearnable => es
          ? '${message(lang)} Corregir sustituye los movimientos dudosos por los últimos que aprende por nivel.'
          : '${message(lang)} Fixing replaces the doubtful moves with the latest level-up moves.',
      LegalityCode.levelBelowMet => es
          ? '${message(lang)} Corregir sube el nivel al de encuentro.'
          : '${message(lang)} Fixing raises the level to the met level.',
      LegalityCode.evTotalTooHigh || LegalityCode.evOutOfRange => es
          ? '${message(lang)} Corregir reduce los EVs hasta el máximo permitido.'
          : '${message(lang)} Fixing lowers EVs to the allowed maximum.',
      LegalityCode.ivOutOfRange => es ? '${message(lang)} Corregir ajusta el IV al máximo.' : '${message(lang)} Fixing clamps the IV.',
      LegalityCode.ppTooHigh => es ? '${message(lang)} Corregir restaura los PP al máximo legal.' : '${message(lang)} Fixing restores PP to the legal maximum.',
      LegalityCode.moveDuplicate => es ? '${message(lang)} Corregir elimina la copia.' : '${message(lang)} Fixing removes the copy.',
      _ => message(lang),
    };
  }

  /// Campo afectado (`move1`…`move4`, `ivs`, `evs`, `item`, `ability`, `level`, `species`, `gender`, `ball`).
  final String? field;
  final Map<String, Object> args;

  String message([DataLanguage lang = DataLanguage.es]) {
    final es = lang == DataLanguage.es;
    String a(String k) => '${args[k] ?? ''}';
    return switch (code) {
      LegalityCode.speciesNotInGame => es
          ? '${a('species')} no existe en este juego.'
          : '${a('species')} is not available in this game.',
      LegalityCode.levelOutOfRange => es ? 'El nivel debe estar entre 1 y 100.' : 'Level must be between 1 and 100.',
      LegalityCode.levelBelowMet => es
          ? 'El nivel (${a('level')}) es menor que el nivel de encuentro (${a('met')}).'
          : 'Level (${a('level')}) is lower than the met level (${a('met')}).',
      LegalityCode.ivOutOfRange => es
          ? 'IV de ${a('stat')} fuera de rango (máx. ${a('max')}).'
          : '${a('stat')} IV out of range (max ${a('max')}).',
      LegalityCode.evOutOfRange => es
          ? 'EV de ${a('stat')} por encima de ${a('max')}.'
          : '${a('stat')} EV above ${a('max')}.',
      LegalityCode.evTotalTooHigh => es
          ? 'El total de EVs (${a('total')}) supera ${a('max')}.'
          : 'EV total (${a('total')}) exceeds ${a('max')}.',
      LegalityCode.moveNotInGame => es
          ? '${a('move')} no existe en este juego.'
          : '${a('move')} does not exist in this game.',
      LegalityCode.moveNotLearnable => es
          ? '${a('species')} no aprende ${a('move')} por nivel, huevo ni MT en este juego (¿preevolución, tutor o evento?).'
          : '${a('species')} cannot learn ${a('move')} by level, egg or TM in this game (pre-evolution, tutor or event?).',
      LegalityCode.moveDuplicate => es ? '${a('move')} está repetido.' : '${a('move')} is duplicated.',
      LegalityCode.noMoves => es ? 'No tiene ningún movimiento.' : 'It has no moves.',
      LegalityCode.ppTooHigh => es
          ? 'PP de ${a('move')} por encima del máximo (${a('max')}).'
          : '${a('move')} PP above the maximum (${a('max')}).',
      LegalityCode.itemNotInGame => es
          ? '${a('item')} no puede equiparse en este juego.'
          : '${a('item')} cannot be held in this game.',
      LegalityCode.abilityNotPossible => es
          ? '${a('ability')} no es una habilidad posible para ${a('species')}.'
          : '${a('ability')} is not a possible ability for ${a('species')}.',
      LegalityCode.genderImpossible => es
          ? 'Género imposible para ${a('species')}.'
          : 'Impossible gender for ${a('species')}.',
      LegalityCode.encounterNotInGame => es
          ? '${a('species')} no se encuentra en ${a('origin')}.'
          : '${a('species')} is not found in ${a('origin')}.',
      LegalityCode.encounterWrongLocation => es
          ? '${a('species')} no aparece en ${a('location')}.'
          : '${a('species')} does not appear at ${a('location')}.',
      LegalityCode.encounterWrongLevel => es
          ? 'Nivel de encuentro ${a('met')} imposible en ${a('location')}.'
          : 'Met level ${a('met')} impossible at ${a('location')}.',
      LegalityCode.ballInvalid => es ? '${a('ball')} no puede estar en ${a('game')}.' : '${a('ball')} cannot appear in ${a('game')}.',
      LegalityCode.natureInvalid => es ? 'Naturaleza inválida.' : 'Invalid nature.',
      LegalityCode.originVersionMissing => es ? 'Sin juego de origen.' : 'Missing origin game.',
      LegalityCode.originFromFuture => es
          ? 'Juego de origen (${a('origin')}) posterior a este formato.'
          : 'Origin game (${a('origin')}) is newer than this format.',
      LegalityCode.ballTooNew => es
          ? '${a('ball')} no existía en ${a('origin')}.'
          : '${a('ball')} did not exist in ${a('origin')}.',
      LegalityCode.ballOnlyInLegends => es
          ? '${a('ball')} solo existe en Leyendas Arceus.'
          : '${a('ball')} only exists in Legends: Arceus.',
      LegalityCode.ballRequiredInLegends => es
          ? 'Ball no disponible en Leyendas Arceus (${a('ball')}).'
          : 'Ball not available in Legends: Arceus (${a('ball')}).',
      LegalityCode.cherishWithoutEvent => es ? 'Gloria Ball sin marca de evento.' : 'Cherish Ball without event flag.',
      LegalityCode.hiddenAbilityOldOrigin => es
          ? 'Habilidad oculta imposible en ${a('origin')}.'
          : 'Hidden ability impossible in ${a('origin')}.',
      LegalityCode.shinyLocked => es
          ? '${a('species')} no puede ser variocolor en ${a('origin')}.'
          : '${a('species')} cannot be shiny in ${a('origin')}.',
      LegalityCode.relearnInvalid => es
          ? 'Movimiento recordable dudoso: ${a('move')}.'
          : 'Doubtful relearn move: ${a('move')}.',
      LegalityCode.eventSpeciesNotFateful => es
          ? '${a('species')} sin marca de encuentro fatídico.'
          : '${a('species')} without fateful-encounter flag.',
      LegalityCode.metLevelInvalid => es ? 'Nivel de encuentro inválido.' : 'Invalid met level.',
      LegalityCode.metDateInvalid => es ? 'Fecha de encuentro vacía o inválida.' : 'Empty or invalid met date.',
      LegalityCode.obedienceLevelInvalid => es ? 'Nivel de obediencia inválido.' : 'Invalid obedience level.',
      LegalityCode.plusMoveMissing => es ? 'Faltan marcas «plus»: ${a('moves')}.' : 'Missing Plus move flags: ${a('moves')}.',
      LegalityCode.plusMoveInvalid => es ? 'Marcas «plus» imposibles: ${a('moves')}.' : 'Impossible Plus move flags: ${a('moves')}.',
    };
  }

  @override
  String toString() => 'LegalityIssue($code, $args)';
}

/// Comprobaciones básicas de legalidad (avisos, nunca bloqueos).
abstract final class Legality {
  static const _statNamesEs = ['PS', 'Ataque', 'Defensa', 'At. Esp.', 'Def. Esp.', 'Velocidad'];
  static const _statNamesEn = ['HP', 'Attack', 'Defense', 'Sp. Atk', 'Sp. Def', 'Speed'];

  static String statName(int i, [DataLanguage lang = DataLanguage.es]) =>
      (lang == DataLanguage.es ? _statNamesEs : _statNamesEn)[i];

  static List<LegalityIssue> check(Pkm pk, GameVersion game, {DataLanguage lang = DataLanguage.es}) {
    final issues = <LegalityIssue>[];
    final table = GameDataTable.forGame(game);
    final ctx = table.context;
    final species = pk.species;
    final speciesName = GameStrings.species(species, lang);
    final f = pk.format;

    // Especie
    if (!Species.isValid(species) || !table.hasSpecies(species)) {
      issues.add(LegalityIssue(LegalityCode.speciesNotInGame, LegalitySeverity.warning,
          field: 'species', args: {'species': speciesName}));
    }

    // Nivel
    final level = pk.level;
    if (level < 1 || level > 100) {
      issues.add(const LegalityIssue(LegalityCode.levelOutOfRange, LegalitySeverity.warning, field: 'level'));
    } else if (!pk.isEgg && pk.metLevel > 0 && level < pk.metLevel) {
      issues.add(LegalityIssue(LegalityCode.levelBelowMet, LegalitySeverity.warning,
          field: 'level', args: {'level': level, 'met': pk.metLevel}, fix: LegalityFix.level));
    }

    // IV / EV
    final ivs = pk.ivs;
    for (var i = 0; i < 6; i++) {
      if (ivs[i] < 0 || ivs[i] > f.maxIv) {
        issues.add(LegalityIssue(LegalityCode.ivOutOfRange, LegalitySeverity.warning,
            field: 'ivs', args: {'stat': statName(i, lang), 'max': f.maxIv}, fix: LegalityFix.ivs));
      }
    }
    if (!f.isGameBoy && f != PkFormat.pb7) {
      final evs = pk.evs;
      final maxEv = f.generation >= 6 ? 252 : 255;
      for (var i = 0; i < 6; i++) {
        if (evs[i] > maxEv) {
          issues.add(LegalityIssue(LegalityCode.evOutOfRange, LegalitySeverity.warning,
              field: 'evs', args: {'stat': statName(i, lang), 'max': maxEv}, fix: LegalityFix.evs));
        }
      }
      final total = evs.fold(0, (a, b) => a + b);
      if (total > 510) {
        issues.add(LegalityIssue(LegalityCode.evTotalTooHigh, LegalitySeverity.warning,
            field: 'evs', args: {'total': total, 'max': 510}, fix: LegalityFix.evs));
      }
    }

    // Movimientos
    final moves = pk.moves;
    if (!pk.isEgg && moves.every((m) => m == 0)) {
      issues.add(const LegalityIssue(LegalityCode.noMoves, LegalitySeverity.warning, field: 'move1', fix: LegalityFix.moves));
    }
    // Los eventos traen movimientos especiales que no están en los learnsets: no se avisa.
    final learnable = pk.fatefulEncounter ? const <int>{} : learnableMoves(pk, game);
    final seen = <int>{};
    for (var i = 0; i < 4; i++) {
      final m = moves[i];
      if (m == 0) continue;
      final name = GameStrings.move(m, lang);
      if (!seen.add(m)) {
        issues.add(LegalityIssue(LegalityCode.moveDuplicate, LegalitySeverity.warning,
            field: 'move${i + 1}', args: {'move': name}, fix: LegalityFix.duplicateMove));
        continue;
      }
      if (!MoveData.existsIn(m, ctx)) {
        issues.add(LegalityIssue(LegalityCode.moveNotInGame, LegalitySeverity.warning,
            field: 'move${i + 1}', args: {'move': name}));
        continue;
      }
      if (learnable.isNotEmpty && !learnable.contains(m) && !pk.isEgg) {
        issues.add(LegalityIssue(LegalityCode.moveNotLearnable, LegalitySeverity.notice,
            field: 'move${i + 1}', args: {'move': name, 'species': speciesName}, fix: LegalityFix.moves));
      }
      // Como PKHeX (`VerifyCurrentMoves`): el máximo depende de los Más PP que tenga el movimiento.
      final maxPp = MoveData.maxPp(m, ctx, pk.ppUps(i));
      if (maxPp > 0 && pk.pp(i) > maxPp) {
        issues.add(LegalityIssue(LegalityCode.ppTooHigh, LegalitySeverity.warning,
            field: 'move${i + 1}', args: {'move': name, 'max': maxPp}, fix: LegalityFix.pp));
      }
    }

    // Flags «plus» de Leyendas Z-A
    if (pk.hasPlusFlags && !pk.isEgg) {
      String names(List<int> indexes) {
        final ms = [for (final i in indexes) PlusMoves.moveAt(i)];
        return [for (final m in ms) m == 0 ? '?' : GameStrings.move(m, lang)].join(', ');
      }

      final missing = PlusMoves.missingIndexes(pk);
      if (missing.isNotEmpty) {
        issues.add(LegalityIssue(LegalityCode.plusMoveMissing, LegalitySeverity.warning,
            field: 'level', args: {'moves': names(missing)}, fix: LegalityFix.plusFlags));
      }
      final invalid = PlusMoves.invalidIndexes(pk);
      if (invalid.isNotEmpty) {
        issues.add(LegalityIssue(LegalityCode.plusMoveInvalid, LegalitySeverity.warning,
            field: 'level', args: {'moves': names(invalid)}, fix: LegalityFix.plusFlags));
      }
    }

    // Objeto
    final item = pk.heldItem;
    if (item != 0) {
      final held = ItemTables.held(game);
      final allItems = ItemTables.all(game);
      if (held.isNotEmpty && !held.contains(item) && !allItems.contains(item)) {
        issues.add(LegalityIssue(LegalityCode.itemNotInGame, LegalitySeverity.warning,
            field: 'item', args: {'item': GameStrings.item(item, f.generation, lang)}));
      } else if (held.isNotEmpty && !held.contains(item)) {
        issues.add(LegalityIssue(LegalityCode.itemNotInGame, LegalitySeverity.notice,
            field: 'item', args: {'item': GameStrings.item(item, f.generation, lang)}));
      }
    }

    // Habilidad, género, naturaleza, ball
    final personal = table.entry(species, pk.form);
    if (personal != null && f.generation >= 3) {
      final ability = pk.ability;
      if (ability != 0 && personal.abilities.isNotEmpty && !personal.abilities.contains(ability)) {
        issues.add(LegalityIssue(LegalityCode.abilityNotPossible, LegalitySeverity.warning,
            field: 'ability', args: {'ability': GameStrings.ability(ability, lang), 'species': speciesName}));
      }
      final g = pk.gender;
      final bad = (personal.genderless && g != 2) ||
          (!personal.genderless && g == 2) ||
          (personal.onlyMale && g == 1) ||
          (personal.onlyFemale && g == 0);
      if (bad) {
        issues.add(LegalityIssue(LegalityCode.genderImpossible, LegalitySeverity.warning,
            field: 'gender', args: {'species': speciesName}));
      }
    }
    if (f.generation >= 3 && (pk.nature < 0 || pk.nature > 24)) {
      issues.add(const LegalityIssue(LegalityCode.natureInvalid, LegalitySeverity.warning, field: 'nature'));
    }
    if (f.generation >= 3) {
      if (pk.ball == 0 || !BallTables.isValidIn(game, pk.ball)) {
        issues.add(LegalityIssue(LegalityCode.ballInvalid, LegalitySeverity.warning,
            field: 'ball',
            args: {'ball': BallTables.name(pk.ball, lang), 'game': lang == DataLanguage.es ? game.nameEs : game.nameEn},
            fix: LegalityFix.ball));
      }
    }
    _checkOrigin(pk, game, table, issues, lang, speciesName);
    _checkEncounter(pk, issues, lang, speciesName);
    return issues;
  }

  /// Juegos cuyos movimientos puede conservar [pk] guardado en [game]: el
  /// propio juego y, desde Gen 3 hasta Gen 8 (los movimientos viajan intactos
  /// por Pal Park, Poké Transfer, Pokémon Bank y HOME), todos los juegos desde
  /// la generación de origen hasta la 7. Los de GO y Let's Go llegan con lo
  /// aprendido en Let's Go; los de Consola Virtual, con lo de Gen 1/2.
  static Set<GameVersion> _moveGames(Pkm pk, GameVersion game) {
    final f = pk.format;
    final gen = f.generation;
    final v = pk.version;
    final games = <GameVersion>{game};
    if (gen < 3 || gen > 8 || f == PkFormat.pb7 || f == PkFormat.pb8 || f == PkFormat.pa8) return games;
    final last = gen < 7 ? gen : 7;
    final origin = (OriginGames.generation(v) ?? gen).clamp(3, last);
    for (final g in GameVersion.values) {
      if (g.generation >= origin && g.generation <= last && g != GameVersion.letsGo) games.add(g);
    }
    if (v == 34 || v == 42 || v == 43) games.add(GameVersion.letsGo);
    if (v >= 35 && v <= 41) {
      games.addAll(const [GameVersion.redBlue, GameVersion.yellow, GameVersion.goldSilver, GameVersion.crystal]);
    }
    return games;
  }

  /// Movimientos que [pk] pudo aprender: los de su especie y sus preevoluciones
  /// (nivel, huevo, MT y tutores) en los juegos de [_moveGames] (p. ej. MT de
  /// Gen 3 en un Pokémon de Pal Park o MO de Gen 4 en uno llegado por HOME).
  static Set<int> learnableMoves(Pkm pk, GameVersion game) {
    final chain = EncounterTables.evolutionChain(pk.species);
    // Shedinja nace como copia de Nincada al evolucionar a Ninjask y conserva lo que este aprende al evolucionar.
    if (pk.species == 292) chain.add(291);
    final gen3Origin = OriginGames.generation(pk.version) == 3;
    return {
      for (final g in _moveGames(pk, game))
        for (final s in chain) ...GameDataTable.forGame(g).learnableMoves(s, s == pk.species ? pk.form : 0),
      if (gen3Origin && pk.format.generation >= 3)
        for (final s in chain) ...?_gen3GiftEggMoves[s],
    };
  }

  /// Movimientos que pueden figurar como recordables: los de nivel y huevo de la
  /// especie y sus preevoluciones (un huevo recuerda los de la forma base) en
  /// el juego actual y en los de origen.
  static Set<int> relearnableMoves(Pkm pk, GameVersion game) {
    final chain = EncounterTables.evolutionChain(pk.species);
    return {
      for (final g in _moveGames(pk, game))
        for (final s in chain) ...[
          for (final m in GameDataTable.forGame(g).levelUpMoves(s, s == pk.species ? pk.form : 0)) m.move,
          ...GameDataTable.forGame(g).eggMoves(s, s == pk.species ? pk.form : 0),
        ],
    };
  }

  /// Movimientos especiales de los huevos regalo de Gen 3 (PKHeX `EncountersWC3.Eggs`):
  /// Pokémon Box Rubí y Zafiro y huevos del 5.º aniversario del Pokémon Center.
  static const Map<int, List<int>> _gen3GiftEggMoves = {
    333: [206], // Swablu con Falso Tortazo
    263: [245], // Zigzagoon con Veloc. Extrema
    300: [6], // Skitty con Día de Pago
    172: [57, 298, 273], // Pichu con Surf, Danza Caos o Deseo
    280: [204, 273], // Ralts con Encanto o Deseo
    359: [180, 273], // Absol con Rencor o Deseo
    371: [334, 273], // Bagon con Defensa Férrea o Deseo
  };

  // ------------------------------------------------------------ orígenes

  /// Offset de `ObedienceLevel` en PK9/PA9.
  static const _obedienceOfs = 0x11F;

  static void _checkOrigin(
      Pkm pk, GameVersion game, GameDataTable table, List<LegalityIssue> issues, DataLanguage lang, String speciesName) {
    final f = pk.format;
    if (f.generation < 3 || pk.isEgg) return;
    final v = pk.version;
    final originGen = OriginGames.generation(v);
    final origin = OriginGames.name(v, lang);
    final formatGen = f.generation;

    if (v == 0) {
      issues.add(const LegalityIssue(LegalityCode.originVersionMissing, LegalitySeverity.warning, field: 'version'));
    } else if (originGen != null && originGen > formatGen && f != PkFormat.pb7) {
      issues.add(LegalityIssue(LegalityCode.originFromFuture, LegalitySeverity.warning,
          field: 'version', args: {'origin': origin, 'originGen': originGen, 'gen': formatGen}));
    }

    final met = pk.metLevel;
    if (!pk.isEgg && met > 100) {
      issues.add(LegalityIssue(LegalityCode.metLevelInvalid, LegalitySeverity.warning, field: 'level', args: {'met': met}));
    }

    // Fecha de encuentro (Gen 4+): con lugar de encuentro siempre hay fecha.
    final noLocation = f == PkFormat.pb8 ? 65535 : 0;
    if (pk.hasDates && pk.metLocation != noLocation && pk.metDate == null) {
      issues.add(const LegalityIssue(LegalityCode.metDateInvalid, LegalitySeverity.warning,
          field: 'metDate', fix: LegalityFix.metDate));
    }

    // Nivel de obediencia de Gen 9 (Escarlata/Púrpura, Z-A).
    if (f == PkFormat.pk9 || f == PkFormat.pa9) {
      final obey = pk.data[_obedienceOfs];
      if (obey < met || obey > pk.level) {
        issues.add(LegalityIssue(LegalityCode.obedienceLevelInvalid, LegalitySeverity.warning,
            field: 'level', args: {'obey': obey, 'met': met, 'level': pk.level}, fix: LegalityFix.obedienceLevel));
      }
    }

    // Ball
    final ball = pk.ball;
    final ballName = BallTables.name(ball, lang);
    final laOrigin = v == OriginGames.legendsArceus;
    if (ball >= 28 && ball <= 37 && !laOrigin && v != 0) {
      issues.add(LegalityIssue(LegalityCode.ballOnlyInLegends, LegalitySeverity.warning,
          field: 'ball', args: {'ball': ballName}, fix: LegalityFix.ball));
    } else if (laOrigin && !(ball == 1 || (ball >= 27 && ball <= 37))) {
      issues.add(LegalityIssue(LegalityCode.ballRequiredInLegends, LegalitySeverity.warning,
          field: 'ball', args: {'ball': ballName}, fix: LegalityFix.ball));
    } else if (originGen != null && ball > 0) {
      final ballGen = OriginGames.ballGeneration(ball);
      if (ballGen > originGen && !(ball == 16 && pk.fatefulEncounter)) {
        issues.add(LegalityIssue(LegalityCode.ballTooNew, LegalitySeverity.warning,
            field: 'ball', args: {'ball': ballName, 'ballGen': ballGen, 'origin': origin, 'originGen': originGen},
            fix: LegalityFix.ball));
      }
    }
    if (ball == 16 && formatGen >= 4 && !pk.fatefulEncounter) {
      issues.add(const LegalityIssue(LegalityCode.cherishWithoutEvent, LegalitySeverity.notice, field: 'ball'));
    }

    // Habilidad oculta en orígenes Gen 3–4
    if (formatGen >= 5 && originGen != null && originGen < 5 && pk.abilitySlot == 2) {
      final personal = table.entry(pk.species, pk.form);
      final hidden = personal != null && personal.abilities.length > 2 && personal.abilities[2] != personal.abilities[0];
      if (hidden) {
        issues.add(LegalityIssue(LegalityCode.hiddenAbilityOldOrigin, LegalitySeverity.warning,
            field: 'ability', args: {'origin': origin}, fix: LegalityFix.ability));
      }
    }

    // Variocolor bloqueado (solo en el encuentro del juego; los eventos, p. ej. Zacian
    // y Zamazenta variocolor de 2020, sí pueden serlo).
    if (pk.isShiny && !pk.fatefulEncounter && OriginGames.isShinyLocked(pk.species, v)) {
      issues.add(LegalityIssue(LegalityCode.shinyLocked, LegalitySeverity.warning,
          field: 'shiny', args: {'species': speciesName, 'origin': origin}, fix: LegalityFix.shiny));
    }

    // Singulares de evento sin marca
    if (formatGen >= 4 && originGen != null && originGen >= 4 && !pk.fatefulEncounter &&
        OriginGames.isEventOnly(pk.species, v)) {
      issues.add(LegalityIssue(LegalityCode.eventSpeciesNotFateful, LegalitySeverity.notice,
          field: 'species', args: {'species': speciesName, 'origin': origin}));
    }

    // Movimientos recordables
    if (pk.hasRelearnMoves) {
      final known = table.learnableMoves(pk.species, pk.form);
      if (known.isNotEmpty && !pk.fatefulEncounter) {
        final pool = relearnableMoves(pk, game);
        for (final m in pk.relearnMoves) {
          if (m == 0 || pool.contains(m)) continue;
          issues.add(LegalityIssue(LegalityCode.relearnInvalid, LegalitySeverity.notice,
              field: 'relearn', args: {'move': GameStrings.move(m, lang), 'species': speciesName}, fix: LegalityFix.relearn));
        }
      }
    }
  }

  // ------------------------------------------------------------ encuentros

  /// Compara lugar, nivel y especie con las tablas de encuentros del juego de
  /// origen (PKHeX `EncounterFinder`, simplificado: sin eventos ni teraincursiones;
  /// las incursiones Dinamax de Espada/Escudo sí están).
  static void _checkEncounter(Pkm pk, List<LegalityIssue> issues, DataLanguage lang, String speciesName) {
    if (pk.format.generation < 3) return;
    final check = EncounterCheck.of(pk);
    if (!check.checked || check.valid) return;
    final v = pk.version;
    final es = lang == DataLanguage.es;
    final complete = EncounterTables.isComplete(v);
    final severity = complete ? LegalitySeverity.warning : LegalitySeverity.notice;
    final scope = complete
        ? ''
        : (es
            ? 'Las tablas portadas de este juego no incluyen todavía teraincursiones, brotes, eventos ni algunos estáticos, así que es solo informativo.'
            : 'The ported tables for this game do not yet include Tera Raids, outbreaks, events or some static encounters, so this is informational only.');
    final origin = OriginGames.name(v, lang);
    final location = EncounterTables.locationName(v, pk.metLocation, lang);
    if (check.candidates.isEmpty) {
      issues.add(LegalityIssue(LegalityCode.encounterNotInGame, severity,
          field: 'species', args: {'species': speciesName, 'origin': origin, 'scope': scope}));
      return;
    }
    if (check.atLocation.isEmpty) {
      issues.add(LegalityIssue(LegalityCode.encounterWrongLocation, severity, field: 'location', args: {
        'species': speciesName,
        'origin': origin,
        'location': location,
        'places': check.describe(check.candidates, lang),
        'scope': scope,
      }));
      return;
    }
    final fixTo = check.nearestLevel(pk.metLevel, pk.level);
    final lv = es ? 'nivel' : 'level';
    final ranges = {
      for (final e in check.atLocation) e.minLevel == e.maxLevel ? '$lv ${e.minLevel}' : '$lv ${e.minLevel}–${e.maxLevel}',
    }.join(', ');
    issues.add(LegalityIssue(LegalityCode.encounterWrongLevel, severity,
        field: 'level',
        args: {
          'species': speciesName,
          'origin': origin,
          'location': location,
          'levels': ranges,
          'met': pk.metLevel,
          'fixTo': fixTo ?? 0,
          'fixNote': fixTo == null
              ? (es
                  ? 'No se corrige: ningún nivel válido es menor o igual que el nivel actual.'
                  : 'Not fixed: no valid level is lower than or equal to the current level.')
              : (es ? 'Corregir pone el nivel de encuentro en $fixTo.' : 'Fixing sets the met level to $fixTo.'),
        },
        fix: fixTo == null ? null : LegalityFix.metLevel));
  }

  // ------------------------------------------------------------ correcciones

  /// Aplica la corrección segura de [issue] sobre una copia de [pk]. Devuelve null si no hay corrección.
  static Pkm? applyFix(Pkm pk, LegalityIssue issue, GameVersion game) {
    final fix = issue.fix;
    if (fix == null) return null;
    final p = pk.clone();
    final table = GameDataTable.forGame(game);
    final ctx = table.context;
    switch (fix) {
      case LegalityFix.ball:
        p.ball = p.version == OriginGames.legendsArceus || p.format == PkFormat.pa8 ? BallTables.hisuiFirst : 4;
      case LegalityFix.ability:
        p.setAbilitySlot(0);
      case LegalityFix.shiny:
        p.setShiny(false);
      case LegalityFix.relearn:
        final pool = relearnableMoves(p, game);
        final keep = [for (final m in p.relearnMoves) if (m != 0 && pool.contains(m)) m];
        for (var i = 0; i < 4; i++) {
          p.setRelearnMove(i, i < keep.length ? keep[i] : 0);
        }
      case LegalityFix.level:
        p.level = p.metLevel.clamp(1, 100);
      case LegalityFix.metDate:
        final d = DateTime.now();
        p.metDate = DateTime(d.year, d.month, d.day);
      case LegalityFix.obedienceLevel:
        p.data[_obedienceOfs] = p.metLevel.clamp(0, p.level);
      case LegalityFix.metLevel:
        final to = issue.args['fixTo'];
        if (to is! int || to < 1 || to > p.level) return null;
        p.metLevel = to;
      case LegalityFix.evs:
        final maxEv = p.format.generation >= 6 ? 252 : 255;
        final evs = [for (final e in p.evs) e.clamp(0, maxEv)];
        var excess = evs.fold(0, (a, b) => a + b) - 510;
        for (var i = 5; i >= 0 && excess > 0; i--) {
          final cut = excess < evs[i] ? excess : evs[i];
          evs[i] -= cut;
          excess -= cut;
        }
        p.setEvs(evs);
      case LegalityFix.ivs:
        p.setIvs([for (final iv in p.ivs) iv.clamp(0, p.format.maxIv)]);
      case LegalityFix.pp:
        p.healPp(ctx);
      case LegalityFix.plusFlags:
        PlusMoves.sync(p);
      case LegalityFix.duplicateMove:
        final seen = <int>{};
        final moves = [for (final m in p.moves) if (m != 0 && seen.add(m)) m];
        for (var i = 0; i < 4; i++) {
          p.setMove(i, i < moves.length ? moves[i] : 0, context: ctx);
        }
      case LegalityFix.moves:
        final learnable = learnableMoves(p, game);
        final keep = [
          for (final m in p.moves)
            if (m != 0 && MoveData.existsIn(m, ctx) && (learnable.isEmpty || learnable.contains(m))) m,
        ];
        final byLevel = [
          for (final lm in table.levelUpMoves(p.species, p.form).reversed)
            if (lm.level <= p.level && lm.move != 0 && MoveData.existsIn(lm.move, ctx)) lm.move,
        ];
        for (final m in byLevel) {
          if (keep.length >= 4) break;
          if (!keep.contains(m)) keep.add(m);
        }
        for (var i = 0; i < 4; i++) {
          p.setMove(i, i < keep.length ? keep[i] : 0, context: ctx);
        }
    }
    p.refreshChecksum();
    return p;
  }
}

/// Juegos de origen (ids de PKHeX `GameVersion`) y reglas por juego.
abstract final class OriginGames {
  static const int legendsArceus = 47;

  static int? generation(int v) => switch (v) {
        1 || 2 || 3 || 4 || 5 || 15 => 3,
        7 || 8 || 10 || 11 || 12 => 4,
        20 || 21 || 22 || 23 => 5,
        24 || 25 || 26 || 27 => 6,
        30 || 31 || 32 || 33 || 34 || 42 || 43 => 7,
        >= 35 && <= 41 => 7, // Consola Virtual (Gen 1/2 transferidos a Gen 7)
        44 || 45 || 47 || 48 || 49 => 8,
        50 || 51 || 52 => 9,
        _ => null,
      };

  static String name(int v, [DataLanguage lang = DataLanguage.es]) {
    final es = lang == DataLanguage.es;
    return switch (v) {
      1 => es ? 'Zafiro' : 'Sapphire',
      2 => es ? 'Rubí' : 'Ruby',
      3 => es ? 'Esmeralda' : 'Emerald',
      4 => es ? 'Rojo Fuego' : 'FireRed',
      5 => es ? 'Verde Hoja' : 'LeafGreen',
      15 => 'Colosseum/XD',
      7 => 'HeartGold',
      8 => 'SoulSilver',
      10 => es ? 'Diamante' : 'Diamond',
      11 => es ? 'Perla' : 'Pearl',
      12 => es ? 'Platino' : 'Platinum',
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
      >= 35 && <= 41 => es ? 'Consola Virtual' : 'Virtual Console',
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
      0 => es ? 'desconocido' : 'unknown',
      _ => '#$v',
    };
  }

  /// Generación en que apareció una Ball (ids de PKHeX `Ball`).
  static int ballGeneration(int ball) => switch (ball) {
        <= 12 => 3,
        13 || 14 || 15 || 16 => 4,
        >= 17 && <= 24 => 4, // Bonguri y Parque/Competi (HGSS)
        25 => 5, // Ensueño
        26 => 7, // Ente
        27 => 8, // Extraña
        _ => 8, // Hisui
      };

  /// Objeto correspondiente a una Ball (para mostrar su nombre).
  static int ballItem(int ball) => switch (ball) {
        >= 1 && <= 16 => ball,
        >= 17 && <= 23 => 492 + (ball - 17), // Rápida, Nivel, Cebo, Peso, Amor, Amigo, Luna
        24 => 499, // Competi
        25 => 576, // Ensueño
        26 => 851, // Ente
        27 => 1785, // Extraña
        28 => 1710, // Poké Ball de Hisui
        29 => 1711,
        30 => 1712,
        31 => 1713,
        32 => 1746,
        33 => 1747,
        34 => 1748,
        35 => 1749,
        36 => 1750,
        37 => 1771,
        _ => 0,
      };

  /// Encuentros con variocolor bloqueado en su juego de origen (estáticos de PKHeX `Shiny.Never`).
  static const Map<int, Set<int>> _shinyLocked = {
    494: {20, 21}, // Victini
    643: {20, 21}, 644: {20, 21}, // Reshiram, Zekrom
    647: {20, 21, 22, 23}, 648: {20, 21, 22, 23}, // Keldeo, Meloetta
    716: {24, 25}, 717: {24, 25}, 718: {24, 25}, // Xerneas, Yveltal, Zygarde
    720: {26, 27}, 721: {24, 25, 26, 27}, // Hoopa, Volcanion
    // Código Cero (772) no: el regalo de Æther puede ser variocolor (PKHeX `Encounters7SM`).
    789: {30, 31, 32, 33}, 790: {30, 31}, 791: {30}, 792: {31}, // Cosmog… Solgaleo/Lunala
    800: {30, 31, 32, 33}, 801: {30, 31, 32, 33}, 802: {32, 33}, // Necrozma, Magearna, Marshadow
    888: {44, 45}, 889: {44, 45}, 890: {44, 45}, 891: {44, 45}, 892: {44, 45}, 898: {44, 45}, // Zacian… Calyrex
    493: {47}, 483: {47}, 484: {47}, 487: {47}, // Arceus, Dialga, Palkia, Giratina (Leyendas Arceus)
    1001: {50, 51}, 1002: {50, 51}, 1003: {50, 51}, 1004: {50, 51}, // Tesoros ancestrales
    1007: {50, 51}, 1008: {50, 51}, 1017: {50, 51}, 1024: {50, 51}, 1025: {50, 51}, // Koraidon, Miraidon, Ogerpon, Terapagos, Pecharunt
  };

  static bool isShinyLocked(int species, int version) => _shinyLocked[species]?.contains(version) ?? false;

  /// Singulares que en ese origen solo se obtienen por evento.
  static bool isEventOnly(int species, int version) {
    final gen = generation(version);
    if (gen == null) return false;
    return switch (species) {
      // Phione (489) no: se cría con Manaphy. Darkrai tiene un estático sin marca de evento en Platino (PKHeX `Encounters4DPPt`).
      491 => gen >= 4 && gen <= 5 && version != 12,
      151 || 251 || 385 || 386 || 490 || 492 => gen >= 4 && gen <= 5,
      647 || 648 || 649 => gen == 5,
      719 || 720 || 721 => gen == 6,
      801 || 802 || 807 => gen == 7,
      893 => gen == 8,
      _ => false,
    };
  }
}
