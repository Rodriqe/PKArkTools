import 'champions_build.dart';
import 'champions_dex.dart';
import 'stat_calc.dart';

/// Clima, campo y pantallas para la calculadora de daño.
enum ChampionsWeather { none, sun, rain, sand, snow }

enum ChampionsTerrain { none, electric, grassy, psychic, misty }

/// Estado del combate que afecta al daño.
class ChampionsField {
  const ChampionsField({
    this.doubles = true,
    this.weather = ChampionsWeather.none,
    this.terrain = ChampionsTerrain.none,
    this.reflect = false,
    this.lightScreen = false,
    this.auroraVeil = false,
    this.helpingHand = false,
    this.crit = false,
    this.spread = true,
  });

  /// Dobles (VGC) o individuales.
  final bool doubles;
  final ChampionsWeather weather;
  final ChampionsTerrain terrain;

  /// Pantallas en el lado del defensor.
  final bool reflect;
  final bool lightScreen;
  final bool auroraVeil;

  /// Refuerzo (Helping Hand) sobre el atacante.
  final bool helpingHand;

  /// Golpe crítico.
  final bool crit;

  /// En dobles, un movimiento a varios objetivos golpea a más de uno
  /// (reducción ×0,75). Sin efecto en individuales.
  final bool spread;

  Map<String, Object?> toJson() => {
    'doubles': doubles,
    'weather': weather.name,
    'terrain': terrain.name,
    'reflect': reflect,
    'lightScreen': lightScreen,
    'auroraVeil': auroraVeil,
    'helpingHand': helpingHand,
    'crit': crit,
    'spread': spread,
  };

  static ChampionsField fromJson(Map<String, Object?> j) => ChampionsField(
    doubles: j['doubles'] != false,
    weather: ChampionsWeather.values.byName(j['weather'] as String? ?? 'none'),
    terrain: ChampionsTerrain.values.byName(j['terrain'] as String? ?? 'none'),
    reflect: j['reflect'] == true,
    lightScreen: j['lightScreen'] == true,
    auroraVeil: j['auroraVeil'] == true,
    helpingHand: j['helpingHand'] == true,
    crit: j['crit'] == true,
    spread: j['spread'] != false,
  );
}

/// Un Pokémon en el combate: su set más el estado del momento.
class ChampionsSide {
  ChampionsSide(this.build, {Map<String, int>? boosts, this.status = '', this.hpPercent = 100}) : boosts = boosts ?? {};
  final ChampionsBuild build;

  /// Cambios de estadística (`atk`, `def`, `spa`, `spd`, `spe`: −6…+6).
  final Map<String, int> boosts;

  /// `''`, `brn`, `par`, `psn`, `tox`, `slp`, `frz`.
  final String status;

  /// PS actuales en % (para Blaze, Eruption, Multiscale y el KO).
  final int hpPercent;

  int get maxHp => build.stats[0];
  int get hp => hpPercent >= 100 ? maxHp : (maxHp * hpPercent / 100).floor().clamp(1, maxHp);

  Map<String, Object?> toJson() => {...build.toJson(), 'boosts': boosts, 'status': status, 'hpPercent': hpPercent};

  static ChampionsSide fromJson(Map<String, Object?> j) => ChampionsSide(
    ChampionsBuild.fromJson(j),
    boosts: (j['boosts'] as Map?)?.cast<String, int>(),
    status: j['status'] as String? ?? '',
    hpPercent: j['hpPercent'] as int? ?? 100,
  );
}

/// Resultado de un cálculo.
class ChampionsDamageResult {
  ChampionsDamageResult({
    required this.rolls,
    required this.defenderHp,
    required this.defenderMaxHp,
    this.hitRolls = const [],
    this.hits = 1,
    this.hitChances = const {},
    this.immune = false,
    this.unsupported = const [],
    this.moveType = '',
  });

  /// 16 tiradas del primer golpe (de menor a mayor).
  final List<int> rolls;

  /// Tiradas de cada golpe si hay varios (Parental Bond, movimientos de
  /// varios golpes).
  final List<List<int>> hitRolls;

  /// Golpes del movimiento (el más probable si varía).
  final int hits;

  /// Probabilidad de cada número de golpes (2–5: 35/35/15/15 %).
  final Map<int, double> hitChances;
  final int defenderHp;
  final int defenderMaxHp;
  final bool immune;
  final String moveType;

  /// Cosas que influyen en el daño y la calculadora no tiene en cuenta.
  final List<String> unsupported;

  /// Daño total por uso (suma de golpes) mínimo y máximo.
  int get min => immune ? 0 : _perUse.first;
  int get max => immune ? 0 : _perUse.last;

  late final List<int> _perUse = _usePossibilities();

  List<int> _usePossibilities() {
    if (hitRolls.length <= 1) return rolls;
    var lo = 0, hi = 0;
    for (final h in hitRolls) {
      lo += h.first;
      hi += h.last;
    }
    return [lo, hi];
  }

  /// % de los PS máximos como en Showdown (truncado a una décima).
  double percent(int d) => (d * 1000 ~/ defenderMaxHp) / 10;

  /// Distribución del daño de un uso: daño → probabilidad.
  Map<int, double> useDistribution() {
    if (immune) return {0: 1};
    Map<int, double> one(List<int> r) {
      final m = <int, double>{};
      for (final d in r) {
        m[d] = (m[d] ?? 0) + 1 / r.length;
      }
      return m;
    }

    Map<int, double> conv(Map<int, double> a, Map<int, double> b) {
      final m = <int, double>{};
      for (final x in a.entries) {
        for (final y in b.entries) {
          m[x.key + y.key] = (m[x.key + y.key] ?? 0) + x.value * y.value;
        }
      }
      return m;
    }

    if (hitChances.isNotEmpty) {
      // Varios golpes con número variable: cada golpe igual que el primero.
      final per = one(rolls);
      final out = <int, double>{};
      var acc = per;
      for (var n = 1; n <= hitChances.keys.reduce((a, b) => a > b ? a : b); n++) {
        if (n > 1) acc = conv(acc, per);
        final p = hitChances[n] ?? 0;
        if (p == 0) continue;
        for (final e in acc.entries) {
          out[e.key] = (out[e.key] ?? 0) + e.value * p;
        }
      }
      return out;
    }
    var acc = one(hitRolls.isEmpty ? rolls : hitRolls.first);
    for (final h in hitRolls.skip(1)) {
      acc = conv(acc, one(h));
    }
    return acc;
  }

  /// Probabilidad de debilitar en exactamente [n] usos o menos (1 = OHKO).
  double koChance(int n) {
    if (immune) return 0;
    final use = useDistribution();
    var acc = <int, double>{0: 1};
    for (var i = 0; i < n; i++) {
      final next = <int, double>{};
      for (final a in acc.entries) {
        for (final u in use.entries) {
          final k = a.key + u.key;
          next[k] = (next[k] ?? 0) + a.value * u.value;
        }
      }
      acc = next;
    }
    var p = 0.0;
    for (final e in acc.entries) {
      if (e.key >= defenderHp) p += e.value;
    }
    return p;
  }

  /// Menor número de usos con alguna posibilidad de KO (hasta 9) y su
  /// probabilidad. null si no hace daño.
  ({int n, double chance})? get ko {
    if (immune || max == 0) return null;
    for (var n = 1; n <= 9; n++) {
      final c = koChance(n);
      if (c > 0) return (n: n, chance: c);
    }
    return null;
  }
}

/// Calculadora de daño de Pokémon Champions.
///
/// Reproduce `getDamage` y `modifyDamage` de Pokémon Showdown con el mod
/// `champions` (`sim/battle-actions.ts`, `data/mods/champions/scripts.ts`):
/// los modificadores se encadenan en base 4096 en el mismo orden que los
/// eventos del simulador (prioridad, velocidad y tipo de efecto). Ver
/// `docs/champions-mecanicas.md` para la lista de lo que **no** se tiene en
/// cuenta.
abstract final class ChampionsDamage {
  static const types = [
    'Bug', 'Dark', 'Dragon', 'Electric', 'Fairy', 'Fighting', 'Fire', 'Flying', 'Ghost', //
    'Grass', 'Ground', 'Ice', 'Normal', 'Poison', 'Psychic', 'Rock', 'Steel', 'Stellar', 'Water',
  ];

  // damageTaken de Showdown: fila = tipo defensor, columna = tipo atacante
  // (0 normal, 1 débil, 2 resiste, 3 inmune).
  static const _chart = <String, List<int>>{
    'Bug': [0, 0, 0, 0, 0, 2, 1, 1, 0, 2, 2, 0, 0, 0, 0, 1, 0, 0, 0],
    'Dark': [1, 2, 0, 0, 1, 1, 0, 0, 2, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0],
    'Dragon': [0, 0, 1, 2, 1, 0, 2, 0, 0, 2, 0, 1, 0, 0, 0, 0, 0, 0, 2],
    'Electric': [0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 1, 0, 0, 0, 0, 0, 2, 0, 0],
    'Fairy': [2, 2, 3, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0],
    'Fighting': [2, 2, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0],
    'Fire': [2, 0, 0, 0, 2, 0, 2, 0, 0, 2, 1, 2, 0, 0, 0, 1, 2, 0, 1],
    'Flying': [2, 0, 0, 1, 0, 2, 0, 0, 0, 2, 3, 1, 0, 0, 0, 1, 0, 0, 0],
    'Ghost': [2, 1, 0, 0, 0, 3, 0, 0, 1, 0, 0, 0, 3, 2, 0, 0, 0, 0, 0],
    'Grass': [1, 0, 0, 2, 0, 0, 1, 1, 0, 2, 2, 1, 0, 1, 0, 0, 0, 0, 2],
    'Ground': [0, 0, 0, 3, 0, 0, 0, 0, 0, 1, 0, 1, 0, 2, 0, 2, 0, 0, 1],
    'Ice': [0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 2, 0, 0, 0, 1, 1, 0, 0],
    'Normal': [0, 0, 0, 0, 0, 1, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'Poison': [2, 0, 0, 0, 2, 2, 0, 0, 0, 2, 1, 0, 0, 2, 1, 0, 0, 0, 0],
    'Psychic': [1, 1, 0, 0, 0, 2, 0, 0, 1, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0],
    'Rock': [0, 0, 0, 0, 0, 1, 2, 2, 0, 1, 1, 0, 2, 2, 0, 0, 1, 0, 1],
    'Steel': [2, 0, 2, 0, 2, 1, 1, 2, 0, 2, 1, 2, 2, 3, 2, 2, 2, 0, 0],
    'Water': [0, 0, 0, 1, 0, 0, 2, 0, 0, 1, 0, 2, 0, 0, 0, 0, 2, 0, 2],
  };

  /// Efectividad base (−1 resiste, 0, 1 débil) o null si es inmune.
  static int? effectiveness(String attack, String defend) {
    final row = _chart[defend];
    final i = types.indexOf(attack);
    if (row == null || i < 0) return 0;
    return switch (row[i]) {
      1 => 1,
      2 => -1,
      3 => null,
      _ => 0,
    };
  }

  /// Habilidades que la calculadora modela.
  static const supportedAbilities = {
    'adaptability', 'aerilate', 'pixilate', 'refrigerate', 'galvanize', 'dragonize', 'normalize', 'liquidvoice', //
    'blaze', 'torrent', 'overgrow', 'swarm', 'guts', 'hugepower', 'purepower', 'hustle', 'ironfist', 'strongjaw',
    'megalauncher', 'sharpness', 'toughclaws', 'technician', 'sheerforce', 'reckless', 'sandforce', 'solarpower',
    'punkrock', 'sniper', 'tintedlens', 'firemane', 'steelworker', 'transistor', 'dragonsmaw', 'rockypayload',
    'waterbubble', 'scrappy', 'skilllink', 'parentalbond', 'infiltrator', 'megasol', 'moldbreaker', 'teravolt',
    'turboblaze', 'thickfat', 'heatproof', 'purifyingsalt', 'multiscale', 'shadowshield', 'filter', 'solidrock',
    'prismarmor', 'fluffy', 'icescales', 'furcoat', 'marvelscale', 'grasspelt', 'levitate', 'eelevate', 'flashfire',
    'waterabsorb', 'stormdrain', 'dryskin', 'voltabsorb', 'lightningrod', 'motordrive', 'sapsipper', 'eartheater',
    'wellbakedbody', 'bulletproof', 'soundproof', 'wonderguard', 'auraguard', 'battlearmor', 'shellarmor', 'mimicry',
    'ripen', 'fairyaura', 'darkaura',
  };

  /// Habilidades que cambian el daño y la calculadora no modela.
  static const unsupportedAbilities = {
    'analytic',
    'supremeoverlord',
    'stakeout',
    'unaware',
    'friendguard',
    'cloudnine',
    'airlock',
    'heavymetal',
    'lightmetal',
    'protosynthesis',
    'quarkdrive',
    'flowergift',
    'powerspot',
    'battery',
    'steelyspirit',
    'aurabreak',
    'fairyaura',
    'darkaura',
    'neutralizinggas',
    'gorillatactics',
    'libero',
    'protean',
    'stancechange',
    'disguise',
    'iceface',
    'merciless',
    'rivalry',
    'toxicboost',
    'flareboost',
    'defeatist',
    'slowstart',
    'plus',
    'minus',
    'unseenfist',
    'piercingdrill',
    'sturdy',
    'contrary',
    'simple',
    'trace',
    'imposter',
  };

  static const _typeItems = {
    'silverpowder': 'Bug', 'blackglasses': 'Dark', 'dragonfang': 'Dragon', 'magnet': 'Electric', //
    'fairyfeather': 'Fairy', 'blackbelt': 'Fighting', 'charcoal': 'Fire', 'sharpbeak': 'Flying', 'spelltag': 'Ghost',
    'miracleseed': 'Grass', 'softsand': 'Ground', 'nevermeltice': 'Ice', 'silkscarf': 'Normal', 'poisonbarb': 'Poison',
    'twistedspoon': 'Psychic', 'hardstone': 'Rock', 'metalcoat': 'Steel', 'mysticwater': 'Water',
  };

  static const _berries = {
    'tangaberry': 'Bug', 'colburberry': 'Dark', 'habanberry': 'Dragon', 'wacanberry': 'Electric', //
    'roseliberry': 'Fairy', 'chopleberry': 'Fighting', 'occaberry': 'Fire', 'cobaberry': 'Flying',
    'kasibberry': 'Ghost', 'rindoberry': 'Grass', 'shucaberry': 'Ground', 'yacheberry': 'Ice', 'kebiaberry': 'Poison',
    'payapaberry': 'Psychic', 'chartiberry': 'Rock', 'babiriberry': 'Steel', 'passhoberry': 'Water',
  };

  /// Objetos que la calculadora modela (el resto no cambia el daño o se avisa).
  static final supportedItems = {
    ..._typeItems.keys, ..._berries.keys, 'chilanberry', 'lifeorb', 'expertbelt', 'muscleband', 'wiseglasses', //
    'lightball', 'choicescarf', 'airballoon', 'ironball',
  };

  /// Objetos que cambian el daño o el KO y no se modelan.
  static const unsupportedItems = {'normalgem', 'metronome', 'focussash', 'sitrusberry', 'leftovers', 'focusband'};

  /// Movimientos de daño que la calculadora no sabe calcular (potencia o daño
  /// que dependen de cosas que no se piden: turnos, golpes recibidos…).
  static const unsupportedMoves = {
    'assurance',
    'avalanche',
    'beatup',
    'comeuppance',
    'counter',
    'endeavor',
    'expandingforce',
    'ficklebeam',
    'finalgambit',
    'fissure',
    'guillotine',
    'hardpress',
    'horndrill',
    'infernalparade',
    'lashout',
    'lastrespects',
    'metalburst',
    'mirrorcoat',
    'mistyexplosion',
    'payback',
    'ragefist',
    'ragingbull',
    'risingvoltage',
    'round',
    'sheercold',
    'spitup',
    'stompingtantrum',
    'superfang',
    'temperflare',
    'terrainpulse',
    'tripleaxel',
    'watershuriken',
    'aurawheel',
    'gravapple',
    'barbbarrage',
    'fling',
    'beakblast',
    'focuspunch',
    'shellsidearm',
    'pollenpuff',
    'struggle',
  };

  static bool moveSupported(ChampionsMove m) =>
      !m.isStatus && !unsupportedMoves.contains(m.id) && m.extra['ohko'] == null;

  /// Calcula el daño de [move] de [attacker] a [defender].
  static ChampionsDamageResult calculate({
    required ChampionsSide attacker,
    required ChampionsSide defender,
    required ChampionsMove move,
    ChampionsField field = const ChampionsField(),
  }) {
    if (attacker.build.battleSpecies == null || defender.build.battleSpecies == null) {
      return ChampionsDamageResult(rolls: List.filled(16, 0), defenderHp: 1, defenderMaxHp: 1, immune: true);
    }
    return _Calc(attacker, defender, move, field).run();
  }
}

/// Un manejador de evento: prioridad, velocidad de quien lo lleva y tipo de
/// efecto (orden de Showdown: `comparePriority`).
class _H {
  _H(this.priority, this.speed, this.subOrder, this.fn);
  final int priority;
  final int speed;
  final int subOrder;

  /// Devuelve un multiplicador para encadenar ([num] o `(n, d)`), un valor
  /// que sustituye al actual (`_Replace`) o null.
  final Object? Function() fn;
}

class _Replace {
  const _Replace(this.value);
  final int value;
}

class _Calc {
  _Calc(this.a, this.d, this.move, this.field);
  final ChampionsSide a;
  final ChampionsSide d;
  final ChampionsMove move;
  final ChampionsField field;

  final unsupported = <String>[];

  late final ChampionsSpecies aSp = a.build.battleSpecies!;
  late final ChampionsSpecies dSp = d.build.battleSpecies!;
  late final List<int> aStats = a.build.stats;
  late final List<int> dStats = d.build.stats;
  late final String aAbility = a.build.battleAbility;
  late final bool moldBreaker = const {'moldbreaker', 'teravolt', 'turboblaze'}.contains(aAbility);

  static const _breakable = {
    'punkrock', 'waterbubble', 'thickfat', 'heatproof', 'purifyingsalt', 'multiscale', 'filter', 'solidrock', //
    'fluffy', 'icescales', 'furcoat', 'marvelscale', 'grasspelt', 'levitate', 'eelevate', 'flashfire', 'waterabsorb',
    'stormdrain', 'dryskin', 'voltabsorb', 'lightningrod', 'motordrive', 'sapsipper', 'eartheater', 'wellbakedbody',
    'bulletproof', 'soundproof', 'wonderguard', 'auraguard', 'battlearmor', 'shellarmor',
  };
  late final String dAbility = moldBreaker && _breakable.contains(d.build.battleAbility) ? '' : d.build.battleAbility;
  String get aItem => a.build.item;
  String get dItem => d.build.item;

  /// Mimetismo: el tipo pasa a ser el del campo.
  List<String> _types(ChampionsSpecies s, String ability) {
    if (ability != 'mimicry') return s.types;
    return switch (field.terrain) {
      ChampionsTerrain.electric => const ['Electric'],
      ChampionsTerrain.grassy => const ['Grass'],
      ChampionsTerrain.misty => const ['Fairy'],
      ChampionsTerrain.psychic => const ['Psychic'],
      ChampionsTerrain.none => s.types,
    };
  }

  late final List<String> aTypes = _types(aSp, aAbility);
  late final List<String> dTypes = _types(dSp, d.build.battleAbility);
  bool aHasType(String t) => aTypes.contains(t);
  bool dHasType(String t) => dTypes.contains(t);

  // Clima tal como lo ve el atacante (Mega Sol = sol para sus movimientos).
  ChampionsWeather get weather => field.weather;
  ChampionsWeather get attackerWeather => aAbility == 'megasol' ? ChampionsWeather.sun : weather;

  int _boosted(int stat, int boost) {
    final b = boost.clamp(-6, 6);
    return b >= 0 ? stat * (2 + b) ~/ 2 : stat * 2 ~/ (2 - b);
  }

  static const _statKeys = ['hp', 'atk', 'def', 'spa', 'spd', 'spe'];

  int speedOf(ChampionsSide s, List<int> stats, String ability) {
    var v = _boosted(stats[5], s.boosts['spe'] ?? 0);
    // getStat: runEvent('ModifySpe') → modificador encadenado y modify.
    var mod = 4096;
    if (s.build.item == 'choicescarf') mod = _chain(mod, 6144);
    if (s.status == 'par' && ability != 'quickfeet') mod = _chain(mod, 2048);
    v = _modify(v, mod);
    return v;
  }

  late final int aSpeed = speedOf(a, aStats, aAbility);
  late final int dSpeed = speedOf(d, dStats, d.build.battleAbility);

  static int _chain(int prev, int next) => (prev * next + 2048) >> 12;
  static int _mod4096(num n, [num den = 1]) => (n * 4096 / den).truncate();

  /// `Battle.modify(value, modifier)` con el modificador ya en base 4096.
  static int _modify(int value, int mod4096) => ((value * mod4096) + 2048 - 1) ~/ 4096;

  /// runEvent: ordena los manejadores y aplica la cadena de modificadores.
  int _run(int value, List<_H> hs) {
    hs.sort((x, y) {
      if (x.priority != y.priority) return y.priority - x.priority;
      if (x.speed != y.speed) return y.speed - x.speed;
      return x.subOrder - y.subOrder;
    });
    var mod = 4096;
    var v = value;
    for (final h in hs) {
      _currentMod = mod;
      _currentValue = v;
      final r = h.fn();
      if (r == null) continue;
      if (r is _Replace) {
        v = r.value;
      } else if (r is (num, num)) {
        mod = _chain(mod, _mod4096(r.$1, r.$2));
      } else if (r is num) {
        mod = _chain(mod, _mod4096(r));
      }
    }
    return mod == 4096 ? v : _modify(v, mod);
  }

  int _currentMod = 4096;
  int _currentValue = 0;

  // subOrder de Showdown: condición 2, campo/clima 5, habilidad 7, objeto 8.
  static const _cond = 2, _ability = 7, _item = 8, _move = 0;

  late String type = move.type;
  late int basePowerBase = move.basePower;
  bool typeChangerBoosted = false;
  bool sheerForce = false;
  bool infiltrates = false;
  late bool isSpread = field.doubles && field.spread && move.isSpread;
  late bool isParental = aAbility == 'parentalbond' && !move.multiHit && !isSpread;

  ChampionsDamageResult run() {
    final dMaxHp = dStats[0];
    ChampionsDamageResult empty({bool immune = false}) => ChampionsDamageResult(
      rolls: List.filled(16, 0),
      defenderHp: d.hp,
      defenderMaxHp: dMaxHp,
      immune: immune,
      unsupported: unsupported,
      moveType: type,
    );
    _notes();
    _modifyType();
    _modifyMove();
    if (_immune()) return empty(immune: true);

    // Varios golpes.
    var hits = 1;
    var hitChances = <int, double>{};
    if (move.multiHit) {
      if (move.minHits == move.maxHits || aAbility == 'skilllink') {
        hits = aAbility == 'skilllink' ? move.maxHits : move.minHits;
      } else {
        hits = 2;
        hitChances = {2: 0.35, 3: 0.35, 4: 0.15, 5: 0.15};
      }
    }
    final parental = isParental;
    final first = _hit(1);
    if (first == null) return empty();
    final hitRolls = <List<int>>[first];
    if (parental) {
      hitRolls.add(_hit(2)!);
    } else if (hits > 1 && hitChances.isEmpty) {
      // Los golpes siguientes ya no tienen la baya ni Multiescamas.
      for (var i = 2; i <= hits; i++) {
        hitRolls.add(_hit(i)!);
      }
    }
    return ChampionsDamageResult(
      rolls: first,
      hitRolls: hitRolls.length > 1 ? hitRolls : const [],
      hits: parental ? 2 : hits,
      hitChances: hitChances,
      defenderHp: d.hp,
      defenderMaxHp: dMaxHp,
      unsupported: unsupported,
      moveType: type,
    );
  }

  void _notes() {
    String abilityName(String id) => ChampionsDex.ability(id)?.name ?? id;
    for (final ab in {aAbility, d.build.battleAbility}) {
      if (ChampionsDamage.unsupportedAbilities.contains(ab)) unsupported.add(abilityName(ab));
    }
    for (final it in {aItem, dItem}) {
      if (ChampionsDamage.unsupportedItems.contains(it)) unsupported.add(ChampionsDex.item(it)?.name ?? it);
    }
    if (!ChampionsDamage.moveSupported(move)) unsupported.add(move.name);
  }

  void _modifyType() {
    if (move.id == 'weatherball') {
      type = switch (attackerWeather) {
        ChampionsWeather.sun => 'Fire',
        ChampionsWeather.rain => 'Water',
        ChampionsWeather.sand => 'Rock',
        ChampionsWeather.snow => 'Ice',
        ChampionsWeather.none => type,
      };
    }
    // Normalize (prioridad 1) y después las -ate (prioridad −1).
    const noModify = {
      'judgment',
      'multiattack',
      'naturalgift',
      'revelationdance',
      'technoblast',
      'terrainpulse',
      'weatherball',
    };
    if (aAbility == 'normalize' && !noModify.contains(move.id) && move.id != 'hiddenpower' && move.id != 'struggle') {
      type = 'Normal';
      typeChangerBoosted = true;
    }
    const ate = {
      'aerilate': 'Flying',
      'pixilate': 'Fairy',
      'refrigerate': 'Ice',
      'galvanize': 'Electric',
      'dragonize': 'Dragon',
    };
    final to = ate[aAbility];
    if (to != null && type == 'Normal' && !noModify.contains(move.id)) {
      type = to;
      typeChangerBoosted = true;
    }
    if (aAbility == 'liquidvoice' && move.flags.contains('sound')) type = 'Water';
  }

  void _modifyMove() {
    if (move.id == 'weatherball' && attackerWeather != ChampionsWeather.none) basePowerBase *= 2;
    if (aAbility == 'sheerforce' && move.extra['sec'] != null) sheerForce = true;
    if (aAbility == 'infiltrator') infiltrates = true;
  }

  bool get dGrounded {
    if (dItem == 'ironball') return true;
    if (dHasType('Flying')) return false;
    if (dAbility == 'levitate' || dAbility == 'eelevate') return false;
    return dItem != 'airballoon';
  }

  bool get aGrounded {
    if (aItem == 'ironball') return true;
    if (aHasType('Flying')) return false;
    if (aAbility == 'levitate' || aAbility == 'eelevate') return false;
    return aItem != 'airballoon';
  }

  bool _immune() {
    // runImmunity (tipo; Scrappy ignora la inmunidad de Fantasma).
    if (type == 'Ground') {
      if (!dGrounded) return true;
    } else {
      final scrappy = aAbility == 'scrappy' && (type == 'Normal' || type == 'Fighting');
      if (!scrappy) {
        for (final t in dTypes) {
          if (ChampionsDamage.effectiveness(type, t) == null) return true;
        }
      }
    }
    // TryHit de las habilidades (inmunidades y absorciones).
    switch (dAbility) {
      case 'flashfire' || 'wellbakedbody' when type == 'Fire':
        return true;
      case 'waterabsorb' || 'stormdrain' || 'dryskin' when type == 'Water':
        return true;
      case 'voltabsorb' || 'lightningrod' || 'motordrive' when type == 'Electric':
        return true;
      case 'sapsipper' when type == 'Grass':
        return true;
      case 'eartheater' when type == 'Ground':
        return true;
      case 'bulletproof' when move.flags.contains('bullet'):
        return true;
      case 'soundproof' when move.flags.contains('sound'):
        return true;
      case 'wonderguard':
        if (_typeMod() <= 0) return true;
    }
    // Campo psíquico: bloquea movimientos con prioridad contra objetivos en el suelo.
    if (field.terrain == ChampionsTerrain.psychic && move.priority > 0 && dGrounded) return true;
    return false;
  }

  int _typeMod() {
    var total = 0;
    for (final t in dTypes) {
      var m = ChampionsDamage.effectiveness(type, t) ?? 0;
      if (move.id == 'freezedry' && t == 'Water') m = 1;
      if (move.id == 'flyingpress') m += ChampionsDamage.effectiveness('Flying', t) ?? 0;
      if (dItem == 'ironball' && type == 'Ground' && t == 'Flying') m = 0;
      total += m;
    }
    return total;
  }

  int _weight(ChampionsSpecies s) => (s.weightKg * 10).round();

  /// Las 16 tiradas de un golpe (null si no hace daño).
  List<int>? _hit(int hitNumber) {
    final fixed = move.extra['fixed'];
    if (fixed == 'level') return List.filled(16, 50);
    if (fixed is int) return List.filled(16, fixed);

    // Potencia base (basePowerCallback).
    var bp = basePowerBase;
    switch (move.id) {
      case 'acrobatics':
        if (aItem.isEmpty) bp *= 2;
      case 'eruption' || 'waterspout' || 'dragonenergy':
        bp = bp * a.hp ~/ a.maxHp;
      case 'hex':
        if (d.status.isNotEmpty) bp *= 2;
      case 'lowkick' || 'grassknot':
        final w = _weight(dSp);
        bp = w >= 2000
            ? 120
            : w >= 1000
            ? 100
            : w >= 500
            ? 80
            : w >= 250
            ? 60
            : w >= 100
            ? 40
            : 20;
      case 'heavyslam' || 'heatcrash':
        final aw = _weight(aSp), dw = _weight(dSp);
        bp = aw >= dw * 5
            ? 120
            : aw >= dw * 4
            ? 100
            : aw >= dw * 3
            ? 80
            : aw >= dw * 2
            ? 60
            : 40;
      case 'storedpower' || 'powertrip':
        bp += 20 * a.boosts.values.where((v) => v > 0).fold(0, (s, v) => s + v);
      case 'gyroball':
        bp = (25 * dSpeed ~/ aSpeed + 1).clamp(1, 150);
      case 'electroball':
        final r = dSpeed == 0 ? 4 : aSpeed ~/ dSpeed;
        bp = const [40, 60, 80, 120, 150][r.clamp(0, 4)];
      case 'flail' || 'reversal':
        final r = (a.hp * 48 ~/ a.maxHp).clamp(1, 48);
        bp = r < 2
            ? 200
            : r < 5
            ? 150
            : r < 10
            ? 100
            : r < 17
            ? 80
            : r < 33
            ? 40
            : 20;
    }
    if (bp <= 0) return null;

    // Crítico (Armadura Batalla / Caparazón lo impiden).
    final crit =
        (field.crit || move.extra['willCrit'] != null) && dAbility != 'battlearmor' && dAbility != 'shellarmor';

    bp = _basePower(bp);
    if (bp == 0) return null;

    // Estadísticas.
    final physical = move.isPhysical;
    final offMon = move.extra['offMon'] == 'target' ? d : a;
    final offStats = identical(offMon, d) ? dStats : aStats;
    final offStat = (move.extra['offStat'] as String?) ?? (physical ? 'atk' : 'spa');
    final defStat = (move.extra['defStat'] as String?) ?? (physical ? 'def' : 'spd');
    var atkBoost = offMon.boosts[offStat] ?? 0;
    var defBoost = d.boosts[defStat] ?? 0;
    if (crit && atkBoost < 0) atkBoost = 0;
    if (crit && defBoost > 0) defBoost = 0;
    if (move.extra['ignoreDef'] != null) defBoost = 0;
    var attack = _boosted(offStats[_statKeys.indexOf(offStat)], atkBoost);
    var defense = _boosted(dStats[_statKeys.indexOf(defStat)], defBoost);
    attack = physical ? _modifyAtk(attack) : _modifySpA(attack);
    defense = defStat == 'def' ? _modifyDef(defense) : _modifySpD(defense);

    final base = (22 * bp * attack ~/ defense) ~/ 50;
    return [for (var r = 15; r >= 0; r--) _modifyDamage(base, crit, 100 - r, hitNumber)];
  }

  int _basePower(int bp) {
    final hs = <_H>[];
    void aH(int p, int sub, Object? Function() f) => hs.add(_H(p, aSpeed, sub, f));
    void dH(int p, int sub, Object? Function() f) => hs.add(_H(p, dSpeed, sub, f));
    void fieldH(int p, Object? Function() f) => hs.add(_H(p, 0, _ChampionsSub.field, f));

    // Movimiento (onBasePower propio; efecto de tipo Move, subOrder 0).
    switch (move.id) {
      case 'facade':
        aH(0, _Calc._move, () => a.status.isNotEmpty && a.status != 'slp' ? 2 : null);
      case 'knockoff':
        // Las megapiedras no se pueden quitar.
        final stone = ChampionsDex.allSpecies.any((s) => s.megaStone == dItem && s.megaOf == d.build.speciesId);
        aH(0, _Calc._move, () => dItem.isNotEmpty && !stone ? 1.5 : null);
      case 'venoshock':
        aH(0, _Calc._move, () => d.status == 'psn' || d.status == 'tox' ? 2 : null);
      case 'solarbeam' || 'solarblade':
        aH(0, _Calc._move, () {
          final w = attackerWeather;
          return w == ChampionsWeather.rain || w == ChampionsWeather.sand || w == ChampionsWeather.snow ? 0.5 : null;
        });
    }
    // Habilidad del atacante.
    switch (aAbility) {
      case 'technician':
        aH(30, _Calc._ability, () => _modify(_currentValue, _currentMod) <= 60 ? 1.5 : null);
      case 'aerilate' || 'pixilate' || 'refrigerate' || 'galvanize' || 'dragonize' || 'normalize':
        aH(23, _Calc._ability, () => typeChangerBoosted ? (4915, 4096) : null);
      case 'ironfist':
        aH(23, _Calc._ability, () => move.flags.contains('punch') ? (4915, 4096) : null);
      case 'reckless':
        aH(23, _Calc._ability, () => move.extra['recoil'] != null || move.extra['crash'] != null ? (4915, 4096) : null);
      case 'toughclaws':
        aH(21, _Calc._ability, () => move.flags.contains('contact') ? (5325, 4096) : null);
      case 'sheerforce':
        aH(21, _Calc._ability, () => sheerForce ? (5325, 4096) : null);
      case 'sandforce':
        aH(21, _Calc._ability, () {
          return weather == ChampionsWeather.sand && (type == 'Rock' || type == 'Ground' || type == 'Steel')
              ? (5325, 4096)
              : null;
        });
      case 'strongjaw':
        aH(19, _Calc._ability, () => move.flags.contains('bite') ? 1.5 : null);
      case 'megalauncher':
        aH(19, _Calc._ability, () => move.flags.contains('pulse') ? 1.5 : null);
      case 'sharpness':
        aH(19, _Calc._ability, () => move.flags.contains('slicing') ? 1.5 : null);
      case 'punkrock':
        aH(7, _Calc._ability, () => move.flags.contains('sound') ? (5325, 4096) : null);
    }
    // Aura Feérica / Aura Oscura (de cualquiera de los dos; solo una cuenta).
    for (final (aura, t) in const [('fairyaura', 'Fairy'), ('darkaura', 'Dark')]) {
      if (type != t) continue;
      final dAura = d.build.battleAbility == aura;
      if (aAbility == aura && (!dAura || aSpeed >= dSpeed)) {
        aH(20, _Calc._ability, () => (5448, 4096));
      } else if (dAura) {
        dH(20, _Calc._ability, () => (5448, 4096));
      }
    }
    // Objeto del atacante.
    final ti = ChampionsDamage._typeItems[aItem];
    if (ti != null) aH(15, _Calc._item, () => type == ti ? (4915, 4096) : null);
    if (aItem == 'muscleband') aH(16, _Calc._item, () => move.isPhysical ? (4505, 4096) : null);
    if (aItem == 'wiseglasses') aH(16, _Calc._item, () => !move.isPhysical ? (4505, 4096) : null);
    // Refuerzo.
    if (field.helpingHand) aH(10, _Calc._cond, () => 1.5);
    // Defensor: Piel Seca (onSourceBasePower).
    if (dAbility == 'dryskin') dH(17, _Calc._ability, () => type == 'Fire' ? 1.25 : null);
    // Campos.
    switch (field.terrain) {
      case ChampionsTerrain.electric:
        fieldH(6, () => type == 'Electric' && aGrounded ? (5325, 4096) : null);
      case ChampionsTerrain.grassy:
        fieldH(6, () {
          if (const {'earthquake', 'bulldoze', 'magnitude'}.contains(move.id) && dGrounded) return 0.5;
          return type == 'Grass' && aGrounded ? (5325, 4096) : null;
        });
      case ChampionsTerrain.psychic:
        fieldH(6, () => type == 'Psychic' && aGrounded ? (5325, 4096) : null);
      case ChampionsTerrain.misty:
        fieldH(6, () => type == 'Dragon' && dGrounded ? 0.5 : null);
      case ChampionsTerrain.none:
        break;
    }
    return _run(bp, hs).clamp(1, 1 << 30);
  }

  int _modifyAtk(int v) {
    final hs = <_H>[];
    void aH(int p, int sub, Object? Function() f) => hs.add(_H(p, aSpeed, sub, f));
    void dH(int p, int sub, Object? Function() f) => hs.add(_H(p, dSpeed, sub, f));
    final low = a.hp <= a.maxHp / 3;
    switch (aAbility) {
      case 'blaze' when type == 'Fire' && low:
      case 'torrent' when type == 'Water' && low:
      case 'overgrow' when type == 'Grass' && low:
      case 'swarm' when type == 'Bug' && low:
        aH(5, _Calc._ability, () => 1.5);
      case 'guts':
        aH(5, _Calc._ability, () => a.status.isNotEmpty ? 1.5 : null);
      case 'hugepower' || 'purepower':
        aH(5, _Calc._ability, () => 2);
      case 'hustle':
        aH(5, _Calc._ability, () => _Replace(_modify(_currentValue, 6144)));
      default:
        _commonAtk(aH);
    }
    if (aItem == 'lightball' && aSp.num == 25) aH(1, _Calc._item, () => 2);
    _commonSourceAtk(dH);
    return _run(v, hs);
  }

  int _modifySpA(int v) {
    final hs = <_H>[];
    void aH(int p, int sub, Object? Function() f) => hs.add(_H(p, aSpeed, sub, f));
    void dH(int p, int sub, Object? Function() f) => hs.add(_H(p, dSpeed, sub, f));
    final low = a.hp <= a.maxHp / 3;
    switch (aAbility) {
      case 'blaze' when type == 'Fire' && low:
      case 'torrent' when type == 'Water' && low:
      case 'overgrow' when type == 'Grass' && low:
      case 'swarm' when type == 'Bug' && low:
        aH(5, _Calc._ability, () => 1.5);
      case 'solarpower':
        aH(5, _Calc._ability, () => attackerWeather == ChampionsWeather.sun ? 1.5 : null);
      default:
        _commonAtk(aH);
    }
    if (aItem == 'lightball' && aSp.num == 25) aH(1, _Calc._item, () => 2);
    _commonSourceAtk(dH);
    return _run(v, hs);
  }

  void _commonAtk(void Function(int, int, Object? Function()) aH) {
    switch (aAbility) {
      case 'firemane':
        aH(5, _Calc._ability, () => type == 'Fire' ? 1.5 : null);
      case 'steelworker':
        aH(5, _Calc._ability, () => type == 'Steel' ? 1.5 : null);
      case 'transistor':
        aH(5, _Calc._ability, () => type == 'Electric' ? (5325, 4096) : null);
      case 'dragonsmaw':
        aH(5, _Calc._ability, () => type == 'Dragon' ? 1.5 : null);
      case 'rockypayload':
        aH(5, _Calc._ability, () => type == 'Rock' ? 1.5 : null);
      case 'waterbubble':
        aH(0, _Calc._ability, () => type == 'Water' ? 2 : null);
    }
  }

  void _commonSourceAtk(void Function(int, int, Object? Function()) dH) {
    switch (dAbility) {
      case 'thickfat':
        dH(move.isPhysical ? 6 : 5, _Calc._ability, () => type == 'Ice' || type == 'Fire' ? 0.5 : null);
      case 'heatproof':
        dH(move.isPhysical ? 6 : 5, _Calc._ability, () => type == 'Fire' ? 0.5 : null);
      case 'purifyingsalt':
        dH(move.isPhysical ? 6 : 5, _Calc._ability, () => type == 'Ghost' ? 0.5 : null);
      case 'waterbubble':
        dH(5, _Calc._ability, () => type == 'Fire' ? 0.5 : null);
    }
  }

  int _modifyDef(int v) {
    final hs = <_H>[];
    void dH(int p, int sub, Object? Function() f) => hs.add(_H(p, dSpeed, sub, f));
    switch (dAbility) {
      case 'furcoat':
        dH(6, _Calc._ability, () => 2);
      case 'marvelscale':
        dH(6, _Calc._ability, () => d.status.isNotEmpty ? 1.5 : null);
      case 'grasspelt':
        dH(6, _Calc._ability, () => field.terrain == ChampionsTerrain.grassy ? 1.5 : null);
    }
    if (weather == ChampionsWeather.snow && dHasType('Ice')) {
      hs.add(_H(10, 0, _ChampionsSub.field, () => _Replace(_modify(_currentValue, 6144))));
    }
    return _run(v, hs);
  }

  int _modifySpD(int v) {
    final hs = <_H>[];
    if (weather == ChampionsWeather.sand && dHasType('Rock')) {
      hs.add(_H(10, 0, _ChampionsSub.field, () => _Replace(_modify(_currentValue, 6144))));
    }
    return _run(v, hs);
  }

  int _modifyDamage(int baseDamage, bool crit, int randomPercent, int hitNumber) {
    var dmg = baseDamage + 2;
    if (isSpread) {
      dmg = _modify(dmg, 3072);
    } else if (hitNumber > 1 && isParental) {
      dmg = _modify(dmg, 1024);
    }
    // Clima (WeatherModifyDamage).
    final w = attackerWeather;
    if (w == ChampionsWeather.sun) {
      if (move.id == 'hydrosteam') {
        dmg = _modify(dmg, 6144);
      } else if (type == 'Fire') {
        dmg = _modify(dmg, 6144);
      } else if (type == 'Water') {
        dmg = _modify(dmg, 2048);
      }
    } else if (w == ChampionsWeather.rain) {
      if (type == 'Water') {
        dmg = _modify(dmg, 6144);
      } else if (type == 'Fire') {
        dmg = _modify(dmg, 2048);
      }
    }
    if (crit) dmg = (dmg * 1.5).truncate();
    dmg = dmg * randomPercent ~/ 100;
    // STAB (Adaptabilidad: 2).
    if (aHasType(type) || move.extra['forceSTAB'] != null) {
      dmg = _modify(dmg, aAbility == 'adaptability' ? 8192 : 6144);
    }
    // Tipos.
    final typeMod = _typeMod().clamp(-6, 6);
    if (typeMod > 0) {
      for (var i = 0; i < typeMod; i++) {
        dmg *= 2;
      }
    } else {
      for (var i = 0; i > typeMod; i--) {
        dmg = dmg ~/ 2;
      }
    }
    // Quemadura.
    if (a.status == 'brn' && move.isPhysical && aAbility != 'guts' && move.id != 'facade') {
      dmg = _modify(dmg, 2048);
    }
    // ModifyDamage: atacante, defensor (onSource…) y pantallas.
    final hs = <_H>[];
    void aH(int p, int sub, Object? Function() f) => hs.add(_H(p, aSpeed, sub, f));
    void dH(int p, int sub, Object? Function() f) => hs.add(_H(p, dSpeed, sub, f));
    switch (aAbility) {
      case 'sniper':
        aH(0, _Calc._ability, () => crit ? 1.5 : null);
      case 'tintedlens':
        aH(0, _Calc._ability, () => typeMod < 0 ? 2 : null);
    }
    if (aItem == 'expertbelt') aH(0, _Calc._item, () => typeMod > 0 ? (4915, 4096) : null);
    if (aItem == 'lifeorb') aH(0, _Calc._item, () => (5324, 4096));
    switch (dAbility) {
      case 'multiscale':
        dH(0, _Calc._ability, () => d.hp >= d.maxHp && hitNumber == 1 ? 0.5 : null);
      case 'shadowshield':
        dH(0, _Calc._ability, () => d.hp >= d.maxHp && hitNumber == 1 ? 0.5 : null);
      case 'filter' || 'solidrock' || 'prismarmor':
        dH(0, _Calc._ability, () => typeMod > 0 ? 0.75 : null);
      case 'fluffy':
        dH(0, _Calc._ability, () {
          var m = 1.0;
          if (type == 'Fire') m *= 2;
          if (move.flags.contains('contact')) m /= 2;
          return m;
        });
      case 'icescales':
        dH(0, _Calc._ability, () => !move.isPhysical ? 0.5 : null);
      case 'punkrock':
        dH(0, _Calc._ability, () => move.flags.contains('sound') ? 0.5 : null);
      case 'auraguard':
        dH(0, _Calc._ability, () => move.flags.contains('contact') ? 0.5 : null);
    }
    final berry = ChampionsDamage._berries[dItem];
    final berryEaten =
        hitNumber == 1 &&
        ((berry != null && type == berry && typeMod > 0) || (dItem == 'chilanberry' && type == 'Normal'));
    if (berryEaten) {
      dH(0, _Calc._item, () => 0.5);
      // Maduración (Ripen): la baya hace el doble (prioridad −1).
      if (dAbility == 'ripen') dH(-1, _Calc._ability, () => 0.5);
    }
    // Pantallas (condición de lado: velocidad 0, subOrder 4).
    if (!crit && !infiltrates) {
      final screen = field.doubles ? (2732, 4096) : 0.5;
      final phys = move.isPhysical;
      if (field.reflect && phys) hs.add(_H(0, 0, 4, () => screen));
      if (field.lightScreen && !phys) hs.add(_H(0, 0, 4, () => screen));
      if (field.auroraVeil && !(phys ? field.reflect : field.lightScreen)) hs.add(_H(0, 0, 4, () => screen));
    }
    dmg = _run(dmg, hs);
    if (dmg == 0) return 1;
    return dmg & 0xFFFF;
  }
}

abstract final class _ChampionsSub {
  static const field = 5;
}

/// Texto del cálculo en el formato habitual
/// («32+ Atk Life Orb Garchomp Earthquake vs. 32 HP / 0 Def Incineroar: …»).
String championsDamageText(
  ChampionsSide attacker,
  ChampionsSide defender,
  ChampionsMove move,
  ChampionsField field,
  ChampionsDamageResult r, {
  required bool es,
}) {
  String statPart(ChampionsSide s, String key, String label) {
    final i = const ['hp', 'atk', 'def', 'spa', 'spd', 'spe'].indexOf(key);
    final t = StatCalc.natureTenths(s.build.nature, i);
    final sign = t == 11
        ? '+'
        : t == 9
        ? '-'
        : '';
    final boost = s.boosts[key] ?? 0;
    return '${boost != 0 ? '${boost > 0 ? '+' : ''}$boost ' : ''}${s.build.sp[i]}$sign $label';
  }

  final physical = move.isPhysical;
  final off = (move.extra['offStat'] as String?) ?? (physical ? 'atk' : 'spa');
  final defKey = (move.extra['defStat'] as String?) ?? (physical ? 'def' : 'spd');
  const labels = {'atk': 'Atk', 'def': 'Def', 'spa': 'SpA', 'spd': 'SpD'};
  final aItem = ChampionsDex.item(attacker.build.item)?.name;
  final dItem = ChampionsDex.item(defender.build.item)?.name;
  final aName = attacker.build.battleSpecies?.name ?? attacker.build.speciesId;
  final dName = defender.build.battleSpecies?.name ?? defender.build.speciesId;
  final b = StringBuffer()
    ..write(statPart(attacker, off, labels[off]!))
    ..write(aItem == null ? '' : ' $aItem')
    ..write(' $aName ${move.name}')
    ..write(field.crit ? (es ? ' (crítico)' : ' on a critical hit') : '')
    ..write(' vs. ${statPart(defender, 'hp', 'HP')} / ${statPart(defender, defKey, labels[defKey]!)}')
    ..write(dItem == null ? '' : ' $dItem')
    ..write(' $dName: ');
  if (r.immune) {
    b.write(es ? 'sin efecto' : 'no effect');
    return b.toString();
  }
  String pct(double v) => v.toStringAsFixed(1);
  b.write('${r.min}-${r.max} (${pct(r.percent(r.min))} - ${pct(r.percent(r.max))}%) -- ');
  final ko = r.ko;
  if (ko == null) return '$b${es ? 'sin KO' : 'no KO'}';
  final what = ko.n == 1 ? 'OHKO' : '${ko.n}HKO';
  if (ko.chance >= 1 - 1e-9) {
    b.write(es ? '$what asegurado' : 'guaranteed $what');
  } else {
    b.write(
      es
          ? '${(ko.chance * 100).toStringAsFixed(1)}% de $what'
          : '${(ko.chance * 100).toStringAsFixed(1)}% chance to $what',
    );
  }
  return b.toString();
}
