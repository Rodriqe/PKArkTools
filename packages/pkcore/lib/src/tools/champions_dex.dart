import 'dart:convert';

import '../data/game_data.dart';
import '../data/generated/champions_dex.dart';
import '../model/game.dart';
import 'champions.dart';
import 'showdown.dart';
import 'stat_calc.dart';

/// Una especie (o forma, o Megaevolución) de Pokémon Champions con sus datos
/// de combate, tal como los tiene el mod `champions` de Pokémon Showdown.
class ChampionsSpecies {
  ChampionsSpecies._(
    this.id,
    this.name,
    this.num,
    this.baseStats,
    this.types,
    this.abilities,
    this.weightKg,
    this.megaOf,
    this.megaStone,
  );

  /// Id de Showdown (`garchomp`, `charizardmegax`, `rotomwash`).
  final String id;

  /// Nombre de Showdown, en inglés (`Charizard-Mega-X`).
  final String name;

  /// Número de la Pokédex Nacional.
  final int num;

  /// PS, Ataque, Defensa, At. Esp., Def. Esp., Velocidad.
  final List<int> baseStats;

  /// Tipos en inglés, como en Showdown (`Dragon`, `Ground`).
  final List<String> types;

  /// Ids de habilidades (la oculta, si la hay, la última).
  final List<String> abilities;
  final double weightKg;

  /// Id de la especie de la que sale si es una Megaevolución.
  final String megaOf;

  /// Id de la megapiedra que la activa (vacío si no es Mega).
  final String megaStone;

  bool get isMega => megaOf.isNotEmpty;

  /// Especie y forma en las tablas de PKArkTools (null si no se resuelve).
  late final (int, int)? key = isMega
      ? ChampionsDex.species(megaOf)?.key
      : Showdown.resolveId(id, GameVersion.scarletViolet) ?? Showdown.resolveId(id, GameVersion.legendsZA);

  /// Tipos como ids de PKArkTools (Normal = 0 …).
  List<int> get typeIds => [for (final t in types) Showdown.typeId(t) ?? 0];
}

/// Un movimiento de Champions.
class ChampionsMove {
  ChampionsMove._(
    this.index,
    this.id,
    this.name,
    this.num,
    this.type,
    this.category,
    this.basePower,
    this.target,
    this.priority,
    this.flags,
    this.minHits,
    this.maxHits,
    this.critRatio,
    this.extra,
  );
  final int index;
  final String id;
  final String name;
  final int num;
  final String type;

  /// `Physical`, `Special` o `Status`.
  final String category;
  final int basePower;

  /// Objetivo de Showdown (`normal`, `allAdjacentFoes`, `allAdjacent`…).
  final String target;
  final int priority;
  final Set<String> flags;
  final int minHits;
  final int maxHits;
  final int critRatio;

  /// Propiedades especiales (`recoil`, `offStat`, `fixed`…).
  final Map<String, Object?> extra;

  bool get isStatus => category == 'Status';
  bool get isPhysical => category == 'Physical';

  /// Golpea a varios objetivos en dobles (reducción ×0,75 si hay más de uno).
  bool get isSpread => target == 'allAdjacentFoes' || target == 'allAdjacent';
  bool get multiHit => maxHits > 1;
}

class ChampionsItem {
  const ChampionsItem._(this.id, this.name, this.num);
  final String id;
  final String name;
  final int num;
}

class ChampionsAbility {
  const ChampionsAbility._(this.id, this.name, this.num);
  final String id;
  final String name;
  final int num;
}

/// Datos de combate de Pokémon Champions (generados por
/// `tool/gen_champions_dex.js` desde el mod `champions` de Showdown).
///
/// Qué especies se pueden usar lo decide la regulación vigente
/// ([ChampionsFormat]); estos datos solo dicen cómo es cada una.
abstract final class ChampionsDex {
  static String get sourceCommit => kChampionsDexCommit;

  static final Map<String, Object?> _raw = jsonDecode(kChampionsDexJson) as Map<String, Object?>;

  static final List<ChampionsSpecies> allSpecies = [
    for (final e in (_raw['species'] as List).cast<List<Object?>>())
      ChampionsSpecies._(
        e[0] as String,
        e[1] as String,
        e[2] as int,
        (e[3] as List).cast<int>(),
        (e[4] as List).cast<String>(),
        (e[5] as List).cast<String>(),
        (e[6] as num).toDouble(),
        e[7] as String,
        e[8] as String,
      ),
  ];
  static final Map<String, ChampionsSpecies> _species = {for (final s in allSpecies) s.id: s};

  static final List<ChampionsMove> allMoves = [
    for (final (i, e) in (_raw['moves'] as List).cast<List<Object?>>().indexed)
      ChampionsMove._(
        i,
        e[0] as String,
        e[1] as String,
        e[2] as int,
        e[3] as String,
        e[4] as String,
        e[5] as int,
        e[6] as String,
        e[7] as int,
        {...(e[8] as String).split(' ').where((f) => f.isNotEmpty)},
        e[9] is List ? (e[9] as List)[0] as int : 1,
        e[9] is List ? (e[9] as List)[1] as int : 1,
        e[10] as int,
        (e[11] as Map).cast<String, Object?>(),
      ),
  ];
  static final Map<String, ChampionsMove> _moves = {for (final m in allMoves) m.id: m};

  static final List<ChampionsItem> allItems = [
    for (final e in (_raw['items'] as List).cast<List<Object?>>())
      ChampionsItem._(e[0] as String, e[1] as String, e[2] as int),
  ];
  static final Map<String, ChampionsItem> _items = {for (final i in allItems) i.id: i};

  static final List<ChampionsAbility> allAbilities = [
    for (final e in (_raw['abilities'] as List).cast<List<Object?>>())
      ChampionsAbility._(e[0] as String, e[1] as String, e[2] as int),
  ];
  static final Map<String, ChampionsAbility> _abilities = {for (final a in allAbilities) a.id: a};

  static final Map<String, List<int>> _learn = {
    for (final MapEntry(:key, :value) in (_raw['learnsets'] as Map).cast<String, List<Object?>>().entries)
      key: value.cast<int>(),
  };

  static ChampionsSpecies? species(String id) => _species[id];
  static ChampionsMove? move(String id) => _moves[id];
  static ChampionsItem? item(String id) => _items[id];
  static ChampionsAbility? ability(String id) => _abilities[id];

  /// Normaliza un nombre a id de Showdown (`Rotom-Wash` → `rotomwash`).
  static String toId(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  /// La especie de Champions para una especie y forma de PKArkTools.
  static ChampionsSpecies? byKey(int species, int form) {
    for (final s in allSpecies) {
      if (!s.isMega && s.num == species && s.key == (species, form)) return s;
    }
    return null;
  }

  /// Megaevoluciones de [s] (normalmente una; Charizard, Mewtwo… dos).
  static List<ChampionsSpecies> megasOf(ChampionsSpecies s) => [
    for (final m in allSpecies)
      if (m.megaOf == s.id) m,
  ];

  /// Movimientos que puede aprender [s] en Champions (los de la especie base
  /// si es una Mega).
  static List<ChampionsMove> learnset(ChampionsSpecies s) => [
    for (final i in _learn[s.isMega ? s.megaOf : s.id] ?? const <int>[]) allMoves[i],
  ];

  static bool canLearn(ChampionsSpecies s, String moveId) {
    final m = _moves[moveId];
    if (m == null) return false;
    return (_learn[s.isMega ? s.megaOf : s.id] ?? const []).contains(m.index);
  }

  /// Especies y formas permitidas en la regulación vigente que tienen datos
  /// (sin Megas: se eligen aparte, con su piedra).
  static List<ChampionsSpecies> allowedSpecies() => [
    for (final s in allSpecies)
      if (!s.isMega && s.key != null && ChampionsFormat.isAllowed(s.key!.$1, s.key!.$2)) s,
  ];

  /// Megas disponibles en la regulación vigente para [s].
  static List<ChampionsSpecies> allowedMegas(ChampionsSpecies s) => [
    for (final m in megasOf(s))
      if (ChampionsFormat.data.megaIds.contains(m.id)) m,
  ];

  /// Nombre de un movimiento en el idioma pedido (el de Showdown si no hay).
  static String moveName(ChampionsMove m, DataLanguage lang) {
    final n = m.num > 0 ? GameStrings.move(m.num, lang) : '';
    return n.isEmpty ? m.name : n;
  }

  static String abilityName(String id, DataLanguage lang) {
    final a = _abilities[id];
    if (a == null) return id;
    final n = a.num > 0 ? GameStrings.ability(a.num, lang) : '';
    return n.isEmpty ? a.name : n;
  }

  static String itemName(String id, DataLanguage lang) {
    final i = _items[id];
    if (i == null) return id;
    final n = i.num > 0 ? GameStrings.item(i.num, 9, lang) : '';
    return n.isEmpty || n.startsWith('(') ? i.name : n;
  }
}

/// Estadísticas de Pokémon Champions.
///
/// Fuente: `data/mods/champions/scripts.ts` (`statModify`) de Showdown y
/// `sim/team-validator.ts` (`validateStats`, límites de puntos); ver
/// `docs/champions-mecanicas.md`. Nivel 50 fijo («Adjust Level = 50»), IVs
/// 31 en todo, y en lugar de EVs, **puntos de estadística** (SP): 0–32 por
/// estadística y 66 en total.
///
///   PS = base + SP + 75
///   resto = (base + SP + 20) × naturaleza (×1,1 / ×0,9, truncando)
abstract final class ChampionsStats {
  static const level = 50;
  static const maxPerStat = 32;
  static const maxTotal = 66;

  /// Estadística [stat] (0 = PS … 5 = Vel). [nature] < 0 = neutra.
  static int stat(int stat, {required int base, required int sp, int nature = -1, bool shedinja = false}) {
    if (stat == 0) return shedinja ? 1 : base + sp + 75;
    final v = base + sp + 20;
    final t = nature < 0 ? 10 : StatCalc.natureTenths(nature, stat);
    // Showdown: tr(tr(stat * 110, 16) / 100) (16 bits; solo importa en hackmons).
    if (t == 11) return ((v * 110) & 0xFFFF) ~/ 100;
    if (t == 9) return ((v * 90) & 0xFFFF) ~/ 100;
    return v;
  }

  static List<int> all({required List<int> base, required List<int> sp, int nature = -1, bool shedinja = false}) => [
    for (var i = 0; i < 6; i++) stat(i, base: base[i], sp: sp[i], nature: nature, shedinja: shedinja),
  ];

  /// Problemas de un reparto de puntos (vacío si es válido).
  static List<String> problems(List<int> sp, {required bool es}) {
    final out = <String>[];
    if (sp.any((v) => v < 0 || v > maxPerStat)) {
      out.add(es ? 'Cada estadística admite de 0 a $maxPerStat puntos.' : 'Each stat takes 0 to $maxPerStat points.');
    }
    final total = sp.fold(0, (a, b) => a + b);
    if (total > maxTotal) {
      out.add(es ? 'Hay $total puntos (máximo $maxTotal).' : '$total points in total (max $maxTotal).');
    }
    return out;
  }

  /// Puntos que dan, a nivel 50 y con IVs 31, la misma estadística que [ev]
  /// EVs en los juegos principales. **No es una regla oficial de
  /// transferencia**: es la equivalencia que usa Showdown en `statModify`
  /// («el primer punto vale 4 EVs y los demás 8»), útil para cargar un
  /// Pokémon de una partida.
  static int spFromEv(int ev) => ((ev.clamp(0, 252) ~/ 4) + 1) ~/ 2;
}
