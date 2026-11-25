import 'dart:math';

import '../data/game_data.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';

/// Calculadora de estadísticas: directa (stats finales a partir de base,
/// IVs, EVs, naturaleza y nivel) e inversa (IVs posibles a partir de las
/// estadísticas que se ven en el juego).
///
/// Fórmulas de Gen 3 en adelante (las mismas de PKHeX `PersonalInfo` /
/// `EntityStats`) y de Gen 1/2 (DVs y experiencia de estadística). Let's Go
/// y Leyendas Arceus usan fórmulas propias (AV/GV): ahí [supports] es `false`
/// y la vista previa del editor sigue siendo [Pkm.computeStats].
abstract final class StatCalc {
  /// `true` si el formato usa las fórmulas clásicas de esta calculadora.
  static bool supports(PkFormat f) => f != PkFormat.pb7 && f != PkFormat.pa8;

  /// Multiplicador de naturaleza en décimas (11 = +10 %, 9 = −10 %).
  static int natureTenths(int nature, int stat) {
    final e = GameStrings.natureEffect(nature);
    if (e == null || stat == 0) return 10;
    if (e.$1 == stat) return 11;
    if (e.$2 == stat) return 9;
    return 10;
  }

  /// Estadística [stat] (0 = PS … 5 = Vel, orden API) en Gen 3+.
  ///
  /// [nature] < 0 = neutra. Shedinja (292) tiene siempre 1 PS.
  static int stat(
    int stat, {
    required int base,
    required int iv,
    required int ev,
    required int level,
    int nature = -1,
    int species = 0,
  }) {
    final core = (2 * base + iv + ev ~/ 4) * level ~/ 100;
    if (stat == 0) return species == 292 ? 1 : core + level + 10;
    return (core + 5) * (nature < 0 ? 10 : natureTenths(nature, stat)) ~/ 10;
  }

  /// Estadística en Gen 1/2: [dv] 0–15 y [statExp] 0–65535.
  static int statGb(int stat, {required int base, required int dv, required int statExp, required int level}) {
    final bonus = min(sqrt(max(statExp, 0)).ceil(), 255) ~/ 4;
    final core = ((base + dv) * 2 + bonus) * level ~/ 100;
    return stat == 0 ? core + level + 10 : core + 5;
  }

  /// Las seis estadísticas (orden API).
  static List<int> all({
    required List<int> base,
    required List<int> ivs,
    required List<int> evs,
    required int level,
    int nature = -1,
    bool gameBoy = false,
    int species = 0,
  }) => [
    for (var i = 0; i < 6; i++)
      gameBoy
          ? statGb(i, base: base[i], dv: ivs[i], statExp: evs[i], level: level)
          : stat(i, base: base[i], iv: ivs[i], ev: evs[i], level: level, nature: nature, species: species),
  ];

  /// IVs (o DVs en Gen 1/2) con los que [stat] da exactamente [observed].
  /// Lista vacía si ninguno encaja (EVs, nivel o naturaleza mal puestos).
  static List<int> possibleIvs(
    int stat, {
    required int base,
    required int observed,
    required int ev,
    required int level,
    int nature = -1,
    bool gameBoy = false,
    int species = 0,
  }) {
    final maxIv = gameBoy ? 15 : 31;
    return [
      for (var iv = 0; iv <= maxIv; iv++)
        if ((gameBoy
                ? statGb(stat, base: base, dv: iv, statExp: ev, level: level)
                : StatCalc.stat(stat, base: base, iv: iv, ev: ev, level: level, nature: nature, species: species)) ==
            observed)
          iv,
    ];
  }

  /// Rangos de IVs para las seis estadísticas observadas de [pk] (con sus
  /// EVs, nivel y naturaleza actuales). null si el formato no lo admite o
  /// no hay datos de la especie.
  static List<IvRange>? inferFor(Pkm pk, List<int> observed) {
    if (!supports(pk.format) || pk.dataGame == null) return null;
    final p = GameDataTable.forGame(pk.dataGame!).entry(pk.species, pk.form);
    if (p == null) return null;
    final gb = pk.format.isGameBoy;
    final evs = pk.evs;
    return [
      for (var i = 0; i < 6; i++)
        IvRange.of(
          possibleIvs(
            i,
            base: p.baseStats[i],
            observed: observed[i],
            ev: evs[i],
            level: pk.level,
            nature: gb ? -1 : pk.statNature,
            gameBoy: gb,
            species: pk.species,
          ),
        ),
    ];
  }
}

/// IVs posibles para una estadística.
class IvRange {
  const IvRange(this.values);
  factory IvRange.of(List<int> v) => IvRange(List.unmodifiable(v));

  final List<int> values;

  bool get isEmpty => values.isEmpty;
  bool get isExact => values.length == 1;
  int get min => values.first;
  int get max => values.last;

  @override
  String toString() => isEmpty ? '—' : (isExact ? '$min' : '$min–$max');
}

/// Poder Oculto: tipo y potencia según los IVs (o DVs en Gen 2).
abstract final class HiddenPower {
  /// Tipos posibles en orden de la fórmula (ids de tipo de PKHeX: 1 = Lucha … 16 = Siniestro).
  static const types = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

  /// Orden de la fórmula: PS, Atq, Def, Vel, AtqEsp, DefEsp (índices API).
  static const _order = [0, 1, 2, 5, 3, 4];

  /// `true` si el Poder Oculto existe en esa generación (Gen 2–7; en Gen 8+
  /// el movimiento ya no está disponible).
  static bool appliesTo(int generation) => generation >= 2 && generation <= 7;

  /// Id de tipo (PKHeX) del Poder Oculto. En Gen 2 los IVs son DVs (orden API).
  static int type(List<int> ivs, {int generation = 3}) {
    if (generation <= 2) return types[4 * (ivs[1] & 3) + (ivs[2] & 3)];
    var bits = 0;
    for (var i = 0; i < 6; i++) {
      bits |= (ivs[_order[i]] & 1) << i;
    }
    return types[bits * 15 ~/ 63];
  }

  /// Potencia: 31–70 en Gen 2, 30–70 en Gen 3–5 y 60 desde Gen 6.
  static int power(List<int> ivs, {int generation = 3}) {
    if (generation >= 6) return 60;
    if (generation <= 2) {
      int msb(int dv) => dv >> 3 & 1;
      final special = ivs[3], speed = ivs[5], def = ivs[2], atk = ivs[1];
      return (5 * (msb(special) + 2 * msb(speed) + 4 * msb(def) + 8 * msb(atk)) + min(special & 3, 3)) ~/ 2 + 31;
    }
    var bits = 0;
    for (var i = 0; i < 6; i++) {
      bits |= (ivs[_order[i]] >> 1 & 1) << i;
    }
    return bits * 40 ~/ 63 + 30;
  }

  /// IVs (Gen 3+) más altos posibles que dan el Poder Oculto de tipo
  /// [typeId], partiendo de [current]: solo se bajan en 1 los IVs que hace
  /// falta (31 → 30, 0 → 1).
  static List<int> ivsFor(int typeId, List<int> current, {int maxIv = 31}) {
    List<int>? best;
    var bestScore = -1;
    for (var mask = 0; mask < 64; mask++) {
      final cand = List<int>.of(current);
      for (var i = 0; i < 6; i++) {
        final want = mask >> i & 1;
        final idx = _order[i];
        if ((cand[idx] & 1) != want) {
          cand[idx] = cand[idx] >= maxIv ? cand[idx] - 1 : cand[idx] + 1;
        }
      }
      if (type(cand) != typeId) continue;
      var score = 0;
      for (var i = 0; i < 6; i++) {
        score -= (cand[i] - current[i]).abs();
      }
      if (best == null || score > bestScore) {
        best = cand;
        bestScore = score;
      }
    }
    return best ?? current;
  }
}
