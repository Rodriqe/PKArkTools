import '../data/forms.dart';
import '../data/generated/encounter_data.dart' show kEvolvesFrom;
import '../data/generated/evolution_data.dart';

/// Método de evolución (ids de PKHeX `EvolutionType`), agrupado para mostrarlo.
enum EvolutionKind {
  level,
  friendship,
  friendshipDay,
  friendshipNight,
  trade,
  tradeItem,
  tradeWith,
  item,
  itemMale,
  itemFemale,
  levelMale,
  levelFemale,
  levelDay,
  levelNight,
  levelDusk,
  heldItemDay,
  heldItemNight,
  knowMove,
  moveType,
  teammate,
  location,
  stats,
  random,
  other,
}

/// Una evolución de [species]/[form] a [to]/[toForm].
class EvolutionStep {
  const EvolutionStep({
    required this.species,
    required this.form,
    required this.to,
    required this.toForm,
    required this.method,
    required this.argument,
    required this.level,
  });

  final int species, form, to, toForm;

  /// Método de PKHeX (`EvolutionType`).
  final int method;

  /// Argumento: objeto, movimiento, tipo o especie según el método.
  final int argument;
  final int level;

  EvolutionKind get kind => switch (method) {
        1 => EvolutionKind.friendship,
        2 => EvolutionKind.friendshipDay,
        3 => EvolutionKind.friendshipNight,
        4 || 45 || 46 || 47 || 52 || 53 => level > 0 ? EvolutionKind.level : EvolutionKind.other,
        5 => EvolutionKind.trade,
        6 => EvolutionKind.tradeItem,
        7 => EvolutionKind.tradeWith,
        8 || 90 => EvolutionKind.item,
        17 => EvolutionKind.itemMale,
        18 => EvolutionKind.itemFemale,
        9 || 10 || 11 => EvolutionKind.stats,
        12 || 13 => EvolutionKind.random,
        19 => EvolutionKind.heldItemDay,
        20 => EvolutionKind.heldItemNight,
        21 || 57 || 58 => EvolutionKind.knowMove,
        22 => EvolutionKind.teammate,
        23 => EvolutionKind.levelMale,
        24 || 34 => EvolutionKind.levelFemale,
        25 || 26 || 27 || 39 || 41 || 42 => EvolutionKind.location,
        29 || 30 => EvolutionKind.moveType,
        32 || 37 => EvolutionKind.levelDay,
        33 || 38 => EvolutionKind.levelNight,
        40 => EvolutionKind.levelDusk,
        _ => EvolutionKind.other,
      };

  @override
  String toString() => '$species-$form → $to-$toForm (m$method a$argument l$level)';
}

/// Árbol de evoluciones (tabla generada desde PKHeX por `tool/gen_dex_tables.sh`).
abstract final class Evolutions {
  static final Map<int, List<EvolutionStep>> _forward = () {
    final m = <int, List<EvolutionStep>>{};
    const r = kEvolutionRows;
    for (var i = 0; i + 6 < r.length; i += 7) {
      final step = EvolutionStep(
          species: r[i], form: r[i + 1], to: r[i + 2], toForm: r[i + 3], method: r[i + 4], argument: r[i + 5], level: r[i + 6]);
      m.putIfAbsent(r[i] * 64 + r[i + 1], () => []).add(step);
    }
    return m;
  }();

  /// Evoluciones directas de [species]/[form].
  static List<EvolutionStep> from(int species, int form) => _forward[species * 64 + form] ?? const [];

  /// Primera fase de la familia de [species]/[form] (con su forma).
  static (int, int) root(int species, int form) {
    var cur = (species, form);
    final seen = <int>{};
    while (seen.add(cur.$1)) {
      final pre = _pre(cur.$1, cur.$2);
      if (pre == null) break;
      cur = pre;
    }
    return cur;
  }

  static (int, int)? _pre(int species, int form) {
    // Primero, una evolución de la tabla que lleve exactamente a esta forma.
    for (final e in _forward.values) {
      for (final s in e) {
        if (s.to == species && s.toForm == form) return (s.species, s.form);
      }
    }
    if (species <= 0 || species >= kEvolvesFrom.length || kEvolvesFrom[species] == 0) return null;
    final g = SpeciesForms.resolveGame(species, form);
    return g == null ? (kEvolvesFrom[species], 0) : SpeciesForms.preEvolution(species, form, g);
  }

  /// Todas las evoluciones de la familia, desde la raíz, en anchura.
  static List<EvolutionStep> family(int species, int form) {
    final (rs, rf) = root(species, form);
    final out = <EvolutionStep>[];
    final queue = [(rs, rf)];
    final seen = <int>{rs * 64 + rf};
    while (queue.isNotEmpty) {
      final (s, f) = queue.removeAt(0);
      for (final step in from(s, f)) {
        out.add(step);
        if (seen.add(step.to * 64 + step.toForm)) queue.add((step.to, step.toForm));
      }
    }
    return out;
  }
}
