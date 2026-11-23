import '../data/game_data.dart';
import '../data/generated/ribbon_data.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';

/// Grupo en que se muestra una cinta o marca.
enum RibbonCategory { contest, battle, commemorative, event, mark }

/// Juegos (o familias) donde se puede conseguir una cinta. Se usan para
/// saber si una cinta es imposible según por dónde pudo pasar el Pokémon
/// (PKHeX `EvolutionHistory.HasVisited*`).
enum RibbonEra { g3, g4, g5, g6, g7, lgpe, swsh, bdsp, pla, g9, za }

/// Descripción estática de una cinta o marca.
class RibbonInfo {
  const RibbonInfo._(this.key, this.category, this.eras, this.maxCount, {this.encounterMark = false});

  /// Nombre de la propiedad en PKHeX (p. ej. `RibbonChampionKalos`).
  final String key;
  final RibbonCategory category;

  /// Juegos donde se consigue jugando (vacío = solo eventos/distribuciones).
  final Set<RibbonEra> eras;

  /// 0 = bandera; >0 = contador con ese máximo.
  final int maxCount;

  /// Marca de encuentro (solo una por Pokémon, la pone el juego al capturarlo).
  final bool encounterMark;

  bool get isCount => maxCount > 0;
  bool get isEventOnly => eras.isEmpty;

  /// Nombre de archivo del icono en los recursos de PKHeX (`ribbons/<x>.png`).
  String get iconName => key.toLowerCase();

  String name([DataLanguage lang = DataLanguage.es]) {
    final n = kRibbonNames[key];
    if (n == null) return key.replaceFirst('Ribbon', '');
    var s = lang == DataLanguage.es ? n.$1 : n.$2;
    // Los contadores de Gen 3 se llaman como la categoría: se aclara.
    if (key.startsWith('RibbonCountG3')) s = lang == DataLanguage.es ? '$s (Hoenn, nº)' : '$s (Hoenn, count)';
    return s;
  }

  String description([DataLanguage lang = DataLanguage.es]) => RibbonText.describe(this, lang);

  @override
  String toString() => key;
}

/// Estado de una cinta en un Pokémon concreto.
class RibbonState {
  const RibbonState(this.info, this.value);
  final RibbonInfo info;

  /// 0/1 para banderas, el número para contadores.
  final int value;
  bool get has => value > 0;
}

/// Aviso de legalidad sobre las cintas.
class RibbonIssue {
  const RibbonIssue(this.kind, [this.ribbon]);
  final RibbonIssueKind kind;
  final RibbonInfo? ribbon;

  String message([DataLanguage lang = DataLanguage.es]) {
    final es = lang == DataLanguage.es;
    final n = ribbon?.name(lang) ?? '';
    return switch (kind) {
      RibbonIssueKind.unobtainable => es
          ? '«$n» no se puede conseguir en los juegos por los que pudo pasar este Pokémon.'
          : '"$n" cannot be obtained in any game this Pokémon could have visited.',
      RibbonIssueKind.eventOnly => es
          ? '«$n» solo se repartió en eventos: revisa que venga de uno.'
          : '"$n" was only distributed at events: make sure it comes from one.',
      RibbonIssueKind.markOrigin => es
          ? '«$n» solo la pone el juego al capturarlo, y este Pokémon no se capturó allí.'
          : '"$n" is only given on capture, and this Pokémon was not caught there.',
      RibbonIssueKind.multipleMarks => es
          ? 'Tiene más de una marca de encuentro: un Pokémon salvaje solo puede llevar una.'
          : 'It has more than one encounter mark: a wild Pokémon can only carry one.',
      RibbonIssueKind.egg => es ? 'Un huevo no puede tener cintas ni marcas.' : 'An egg cannot have ribbons or marks.',
      RibbonIssueKind.affixedMissing => es
          ? 'La cinta mostrada («$n») no está entre las que tiene.'
          : 'The displayed ribbon ("$n") is not one it has.',
      RibbonIssueKind.countTooHigh => es ? '«$n» supera el máximo posible.' : '"$n" exceeds the possible maximum.',
    };
  }

  /// `true` para avisos informativos (no hacen ilegal al Pokémon con seguridad).
  bool get isInfo => kind == RibbonIssueKind.eventOnly;
}

enum RibbonIssueKind { unobtainable, eventOnly, markOrigin, multipleMarks, egg, affixedMissing, countTooHigh }

/// Cintas y marcas de Gen 3–9 (PKHeX `IRibbonSet*`, `RibbonIndex`, `RibbonVerifier*`, GPL-3.0).
abstract final class Ribbons {
  static const _g3 = {RibbonEra.g3};
  static const _g4 = {RibbonEra.g4};
  static const _g4b = {RibbonEra.g4, RibbonEra.bdsp};
  static const _g6 = {RibbonEra.g6};
  static const _g7 = {RibbonEra.g7};
  static const _sw = {RibbonEra.swsh};
  static const _g9 = {RibbonEra.g9};
  static const Set<RibbonEra> _event = {};
  static const _effort = {RibbonEra.g3, RibbonEra.g4, RibbonEra.g6, RibbonEra.g7, RibbonEra.swsh, RibbonEra.bdsp, RibbonEra.g9};
  static const _friends = {RibbonEra.g6, RibbonEra.g7, RibbonEra.swsh, RibbonEra.bdsp, RibbonEra.g9};
  static const _footprint = {RibbonEra.g4, RibbonEra.g6, RibbonEra.g7, RibbonEra.swsh, RibbonEra.bdsp, RibbonEra.g9};
  static const _marks8 = {RibbonEra.swsh, RibbonEra.g9};

  static RibbonInfo _r(String k, RibbonCategory c, Set<RibbonEra> e, [int max = 0]) => RibbonInfo._(k, c, e, max);
  static RibbonInfo _m(String k, Set<RibbonEra> e, {bool encounter = true}) =>
      RibbonInfo._(k, RibbonCategory.mark, e, 0, encounterMark: encounter);

  /// Todas las cintas conocidas, en el orden en que se muestran.
  static final List<RibbonInfo> all = () {
    const c = RibbonCategory.contest, b = RibbonCategory.battle, m = RibbonCategory.commemorative, e = RibbonCategory.event;
    final list = <RibbonInfo>[
      // Concursos
      for (final cat in ['Cool', 'Beauty', 'Cute', 'Smart', 'Tough'])
        for (final rank in ['', 'Super', 'Hyper', 'Master']) _r('RibbonG3$cat$rank', c, _g3),
      for (final cat in ['Cool', 'Beauty', 'Cute', 'Smart', 'Tough']) _r('RibbonCountG3$cat', c, _g3, 4),
      for (final cat in ['Cool', 'Beauty', 'Cute', 'Smart', 'Tough'])
        for (final rank in ['', 'Great', 'Ultra', 'Master']) _r('RibbonG4$cat$rank', c, _g4b),
      _r('RibbonArtist', c, _g3),
      _r('RibbonContestStar', c, _g6),
      for (final cat in ['Coolness', 'Beauty', 'Cuteness', 'Cleverness', 'Toughness']) _r('RibbonMaster$cat', c, _g6),
      _r('RibbonCountMemoryContest', c, {RibbonEra.g3, RibbonEra.g4}, 40),
      // Combate
      _r('RibbonChampionG3', b, _g3),
      _r('RibbonWinning', b, _g3),
      _r('RibbonVictory', b, _g3),
      _r('RibbonChampionSinnoh', b, _g4b),
      _r('RibbonAbility', b, _g4),
      _r('RibbonAbilityGreat', b, _g4),
      _r('RibbonAbilityDouble', b, _g4),
      _r('RibbonAbilityMulti', b, _g4),
      _r('RibbonAbilityPair', b, _g4),
      _r('RibbonAbilityWorld', b, _g4),
      _r('RibbonLegend', b, _g4),
      _r('RibbonChampionKalos', b, _g6),
      _r('RibbonChampionG6Hoenn', b, _g6),
      _r('RibbonBattlerSkillful', b, _g6),
      _r('RibbonBattlerExpert', b, _g6),
      _r('RibbonChampionAlola', b, _g7),
      _r('RibbonBattleRoyale', b, _g7),
      _r('RibbonBattleTreeGreat', b, _g7),
      _r('RibbonBattleTreeMaster', b, _g7),
      _r('RibbonChampionGalar', b, _sw),
      _r('RibbonTowerMaster', b, {RibbonEra.swsh, RibbonEra.bdsp}),
      _r('RibbonMasterRank', b, {RibbonEra.swsh, RibbonEra.g9}),
      _r('RibbonChampionPaldea', b, _g9),
      _r('RibbonCountMemoryBattle', b, {RibbonEra.g3, RibbonEra.g4}, 8),
      // Conmemorativas
      _r('RibbonEffort', m, _effort),
      _r('RibbonBestFriends', m, _friends),
      _r('RibbonTraining', m, _g6),
      _r('RibbonFootprint', m, _footprint),
      for (final k in ['Alert', 'Shock', 'Downcast', 'Careless', 'Relax', 'Snooze', 'Smile', 'Gorgeous', 'Royal', 'GorgeousRoyal'])
        _r('Ribbon$k', m, _g4b),
      _r('RibbonNational', m, _g3),
      _r('RibbonEarth', m, _g3),
      _r('RibbonHisui', m, {RibbonEra.pla}),
      _r('RibbonTwinklingStar', m, {RibbonEra.bdsp}),
      _r('RibbonPartner', m, {RibbonEra.za}),
      // Eventos
      for (final k in [
        'Country', 'World', 'Classic', 'Premier', 'Event', 'Birthday', 'Special', 'Souvenir', 'Wishing', 'Record',
        'ChampionBattle', 'ChampionRegional', 'ChampionNational', 'ChampionWorld', 'OnceInALifetime',
      ])
        _r('Ribbon$k', e, _event),
      // Marcas de Espada/Escudo (también en Escarlata/Púrpura salvo Curry y Pesca)
      for (final k in [
        'Lunchtime', 'SleepyTime', 'Dusk', 'Dawn', 'Cloudy', 'Rainy', 'Stormy', 'Snowy', 'Blizzard', 'Dry', 'Sandstorm', 'Misty',
      ])
        _m('RibbonMark$k', _marks8),
      _m('RibbonMarkDestiny', _g9),
      _m('RibbonMarkFishing', _sw),
      _m('RibbonMarkCurry', _sw),
      for (final k in [
        'Uncommon', 'Rare', 'Rowdy', 'AbsentMinded', 'Jittery', 'Excited', 'Charismatic', 'Calmness', 'Intense', 'ZonedOut',
        'Joyful', 'Angry', 'Smiley', 'Teary', 'Upbeat', 'Peeved', 'Intellectual', 'Ferocious', 'Crafty', 'Scowling', 'Kindly',
        'Flustered', 'PumpedUp', 'ZeroEnergy', 'Prideful', 'Unsure', 'Humble', 'Thorny', 'Vigor', 'Slump',
      ])
        _m('RibbonMark$k', _marks8),
      // Marcas de Escarlata/Púrpura
      _m('RibbonMarkJumbo', _g9),
      _m('RibbonMarkMini', _g9),
      _m('RibbonMarkAlpha', {RibbonEra.pla, RibbonEra.g9, RibbonEra.za}),
      _m('RibbonMarkMightiest', _g9),
      _m('RibbonMarkTitan', _g9),
      _m('RibbonMarkItemfinder', _g9, encounter: false),
      _m('RibbonMarkPartner', _g9, encounter: false),
      _m('RibbonMarkGourmand', _g9, encounter: false),
    ];
    return list;
  }();

  static final Map<String, RibbonInfo> _byKey = {for (final r in all) r.key: r};
  static RibbonInfo? info(String key) => _byKey[key];

  static final Map<PkFormat, Map<String, (int, int, int)>> _layouts = {};

  static Map<String, (int, int, int)> _layout(PkFormat f) => _layouts.putIfAbsent(f, () {
        final raw = kRibbonLayouts[f.extension] ?? const [];
        return {for (final (n, o, b, w) in raw) n: (o, b, w)};
      });

  /// `true` si el formato guarda cintas (Gen 3 en adelante).
  static bool supports(PkFormat f) => kRibbonLayouts.containsKey(f.extension);

  /// Cintas que existen en el formato, en orden de visualización.
  static List<RibbonInfo> forFormat(PkFormat f) {
    final l = _layout(f);
    final out = [for (final r in all) if (l.containsKey(r.key)) r];
    // Las Gen 3 guardan el rango como contador (PK3): se ocultan las banderas que no existen.
    return out;
  }

  /// Valor de una cinta (0/1 para banderas; el número para contadores). 0 si no existe en el formato.
  static int get(Pkm pk, String key) {
    final pos = _layout(pk.format)[key];
    if (pos == null) return 0;
    final (o, b, w) = pos;
    final d = pk.data;
    return switch (w) {
      1 => (d[o] >> b) & 1,
      3 => ((d[o] | d[o + 1] << 8 | d[o + 2] << 16 | d[o + 3] << 24) >> b) & 7,
      _ => d[o],
    };
  }

  /// Fija una cinta. Los contadores se recortan a su máximo; los recuerdos de
  /// concurso/combate actualizan también su bandera «tiene la cinta».
  static void set(Pkm pk, String key, int value) {
    final pos = _layout(pk.format)[key];
    if (pos == null) return;
    final (o, b, w) = pos;
    final d = pk.data;
    final max = info(key)?.maxCount ?? 0;
    switch (w) {
      case 1:
        d[o] = value > 0 ? d[o] | (1 << b) : d[o] & ~(1 << b);
      case 3:
        var u = d[o] | d[o + 1] << 8 | d[o + 2] << 16 | d[o + 3] << 24;
        u = (u & ~(7 << b)) | ((value.clamp(0, max == 0 ? 7 : max) & 7) << b);
        for (var i = 0; i < 4; i++) {
          d[o + i] = (u >> (8 * i)) & 0xFF;
        }
      default:
        d[o] = value.clamp(0, max == 0 ? 255 : max);
    }
    if (key == 'RibbonCountMemoryContest') _setFlag(pk, 'HasContestMemoryRibbon', value > 0);
    if (key == 'RibbonCountMemoryBattle') _setFlag(pk, 'HasBattleMemoryRibbon', value > 0);
    // Si se quita la cinta mostrada, deja de mostrarse.
    if (value <= 0 && affixed(pk) == key) setAffixed(pk, null);
    pk.refreshChecksum();
  }

  static void _setFlag(Pkm pk, String key, bool v) {
    final pos = _layout(pk.format)[key];
    if (pos == null) return;
    final (o, b, _) = pos;
    pk.data[o] = v ? pk.data[o] | (1 << b) : pk.data[o] & ~(1 << b);
  }

  /// Estado de todas las cintas del formato.
  static List<RibbonState> of(Pkm pk) => [for (final r in forFormat(pk.format)) RibbonState(r, get(pk, r.key))];

  static int countOwned(Pkm pk) => of(pk).where((s) => s.has).length;

  // ------------------------------------------------------------ cinta mostrada

  static bool supportsAffixed(PkFormat f) => kRibbonAffixedOffset.containsKey(f.extension);

  /// Cinta o marca mostrada (Gen 8+); null si ninguna.
  static String? affixed(Pkm pk) {
    final o = kRibbonAffixedOffset[pk.format.extension];
    if (o == null) return null;
    final v = pk.data[o];
    if (v == 0xFF || v >= kRibbonIndex.length) return null;
    return kRibbonIndex[v];
  }

  static void setAffixed(Pkm pk, String? key) {
    final o = kRibbonAffixedOffset[pk.format.extension];
    if (o == null) return;
    final i = key == null ? -1 : kRibbonIndex.indexOf(key);
    pk.data[o] = i < 0 ? 0xFF : i;
    pk.refreshChecksum();
  }

  /// Cintas que se pueden mostrar (las que están en `RibbonIndex`).
  static bool canAffix(String key) => kRibbonIndex.contains(key);

  // ------------------------------------------------------------ legalidad

  /// Familia de juego de origen (ids de PKHeX `GameVersion`).
  static RibbonEra? originEra(int version) => switch (version) {
        1 || 2 || 3 || 4 || 5 || 15 => RibbonEra.g3,
        7 || 8 || 10 || 11 || 12 => RibbonEra.g4,
        20 || 21 || 22 || 23 => RibbonEra.g5,
        24 || 25 || 26 || 27 => RibbonEra.g6,
        30 || 31 || 32 || 33 || (>= 35 && <= 41) => RibbonEra.g7,
        42 || 43 => RibbonEra.lgpe,
        44 || 45 => RibbonEra.swsh,
        47 => RibbonEra.pla,
        48 || 49 => RibbonEra.bdsp,
        50 || 51 => RibbonEra.g9,
        52 => RibbonEra.za,
        _ => null,
      };

  static RibbonEra formatEra(PkFormat f) => switch (f) {
        PkFormat.pk1 || PkFormat.pk2 || PkFormat.pk3 => RibbonEra.g3,
        PkFormat.pk4 => RibbonEra.g4,
        PkFormat.pk5 => RibbonEra.g5,
        PkFormat.pk6 => RibbonEra.g6,
        PkFormat.pk7 => RibbonEra.g7,
        PkFormat.pb7 => RibbonEra.lgpe,
        PkFormat.pk8 => RibbonEra.swsh,
        PkFormat.pb8 => RibbonEra.bdsp,
        PkFormat.pa8 => RibbonEra.pla,
        PkFormat.pk9 => RibbonEra.g9,
        PkFormat.pa9 => RibbonEra.za,
      };

  static const _chain = [RibbonEra.g3, RibbonEra.g4, RibbonEra.g5, RibbonEra.g6, RibbonEra.g7];
  static const _home = {RibbonEra.swsh, RibbonEra.bdsp, RibbonEra.pla, RibbonEra.g9, RibbonEra.za};

  /// Juegos por los que pudo pasar el Pokémon según su origen y su formato actual
  /// (aproximación de PKHeX `EvolutionHistory`: no comprueba qué especies admite cada juego).
  static Set<RibbonEra> visitedEras(Pkm pk) {
    final fmt = formatEra(pk.format);
    final origin = originEra(pk.version) ?? fmt;
    final out = <RibbonEra>{origin, fmt};
    final homeFormat = pk.format.generation >= 8;
    final vc = pk.version >= 35 && pk.version <= 41;
    final oi = _chain.indexOf(origin);
    if (oi >= 0 && !vc) {
      final fi = homeFormat ? _chain.length - 1 : _chain.indexOf(fmt);
      for (var i = oi; i <= fi && i >= 0; i++) {
        out.add(_chain[i]);
      }
    }
    if (homeFormat) out.addAll(_home);
    if (pk.version == 34 && (pk.format == PkFormat.pb7 || homeFormat)) out.add(RibbonEra.lgpe); // GO → Let's Go
    return out;
  }

  /// Avisos de legalidad de las cintas (PKHeX `RibbonVerifier`, simplificado).
  static List<RibbonIssue> check(Pkm pk) {
    if (!supports(pk.format)) return const [];
    final owned = [for (final s in of(pk)) if (s.has) s];
    if (owned.isEmpty) {
      final a = affixed(pk);
      return a == null ? const [] : [RibbonIssue(RibbonIssueKind.affixedMissing, info(a))];
    }
    if (pk.isEgg) return const [RibbonIssue(RibbonIssueKind.egg)];
    final visited = visitedEras(pk);
    final origin = originEra(pk.version);
    final issues = <RibbonIssue>[];
    var encounterMarks = 0;
    for (final s in owned) {
      final r = s.info;
      if (r.encounterMark) {
        encounterMarks++;
        if (origin == null || !r.eras.contains(origin)) issues.add(RibbonIssue(RibbonIssueKind.markOrigin, r));
        continue;
      }
      if (r.isEventOnly) {
        if (!pk.fatefulEncounter) issues.add(RibbonIssue(RibbonIssueKind.eventOnly, r));
        continue;
      }
      if (!r.eras.any(visited.contains)) issues.add(RibbonIssue(RibbonIssueKind.unobtainable, r));
      if (r.key.startsWith('RibbonCountG3') && s.value > 4) issues.add(RibbonIssue(RibbonIssueKind.countTooHigh, r));
    }
    if (encounterMarks > 1) issues.add(const RibbonIssue(RibbonIssueKind.multipleMarks));
    final a = affixed(pk);
    if (a != null && get(pk, a) == 0) issues.add(RibbonIssue(RibbonIssueKind.affixedMissing, info(a)));
    return issues;
  }

  /// `true` si dar la cinta a este Pokémon sería válido.
  static bool isObtainable(Pkm pk, RibbonInfo r) {
    if (pk.isEgg) return false;
    if (r.isEventOnly) return false;
    if (r.encounterMark) return false; // una marca de encuentro no se «da»
    if (r.category == RibbonCategory.mark) return r.eras.any(visitedEras(pk).contains);
    return r.eras.any(visitedEras(pk).contains);
  }

  /// Da todas las cintas que el Pokémon pudo conseguir jugando (sin eventos ni marcas de encuentro).
  static int giveAllValid(Pkm pk) {
    var n = 0;
    for (final r in forFormat(pk.format)) {
      if (!isObtainable(pk, r)) continue;
      final v = switch (r.key) {
        'RibbonCountMemoryContest' => _hadIn(pk, const {RibbonEra.g3, RibbonEra.g4}) ? 40 : 0,
        'RibbonCountMemoryBattle' => _hadIn(pk, const {RibbonEra.g3, RibbonEra.g4}) ? 8 : 0,
        _ => r.isCount ? r.maxCount : 1,
      };
      if (v > 0 && get(pk, r.key) < v) {
        set(pk, r.key, v);
        n++;
      }
    }
    return n;
  }

  /// En Gen 6+ los recuerdos sustituyen a las cintas de concurso/combate de Gen 3–4.
  static bool _hadIn(Pkm pk, Set<RibbonEra> eras) => pk.format.generation >= 6 && eras.any(visitedEras(pk).contains);

  /// Quita todas las cintas y marcas (y la cinta mostrada).
  static void removeAll(Pkm pk) {
    for (final r in forFormat(pk.format)) {
      if (get(pk, r.key) != 0) set(pk, r.key, 0);
    }
    setAffixed(pk, null);
  }
}

/// Descripciones de las cintas (es/en), escritas para PKArkTools.
abstract final class RibbonText {
  static const _contestEs = {'Cool': 'Carisma', 'Beauty': 'Belleza', 'Cute': 'Dulzura', 'Smart': 'Ingenio', 'Tough': 'Dureza'};
  static const _contestEn = {'Cool': 'Cool', 'Beauty': 'Beauty', 'Cute': 'Cute', 'Smart': 'Smart', 'Tough': 'Tough'};

  static const Map<String, (String, String)> _special = {
    'RibbonArtist': ('Elegido como modelo de un retrato en el Museo de Ciudad Calagua tras ganar en rango Master.',
        'Chosen as a model for a painting at the Lilycove Museum after a Master Rank win.'),
    'RibbonContestStar': ('Ganó los cinco concursos de rango Normal a Experto en Hoenn (ROZA).',
        'Won every contest condition in Hoenn (ORAS).'),
    'RibbonCountMemoryContest': ('Recuerdo de las cintas de concurso de Gen 3 y 4 al pasar a Gen 6 o posterior.',
        'Memory of the Gen 3–4 contest ribbons after moving to Gen 6 or later.'),
    'RibbonCountMemoryBattle': ('Recuerdo de las cintas de combate de Gen 3 y 4 al pasar a Gen 6 o posterior.',
        'Memory of the Gen 3–4 battle ribbons after moving to Gen 6 or later.'),
    'RibbonChampionG3': ('Venció al Alto Mando de Hoenn (Rubí, Zafiro, Esmeralda).', 'Beat the Hoenn Elite Four (Ruby, Sapphire, Emerald).'),
    'RibbonWinning': ('Superó el nivel 50 de la Torre Batalla de Hoenn.', 'Cleared the Hoenn Battle Tower Lv. 50 challenge.'),
    'RibbonVictory': ('Superó el nivel abierto de la Torre Batalla de Hoenn.', 'Cleared the Hoenn Battle Tower Open Level challenge.'),
    'RibbonChampionSinnoh': ('Venció al Alto Mando de Sinnoh (DPPt y DBPR).', 'Beat the Sinnoh Elite Four (DPPt and BDSP).'),
    'RibbonAbility': ('Venció al As de la Torre Batalla de Sinnoh.', 'Defeated the Sinnoh Battle Tower Tower Tycoon.'),
    'RibbonAbilityGreat': ('Gran victoria en la Torre Batalla de Sinnoh.', 'Great victory at the Sinnoh Battle Tower.'),
    'RibbonAbilityDouble': ('Superó los combates dobles de la Torre Batalla.', 'Completed the Battle Tower Double Battle challenge.'),
    'RibbonAbilityMulti': ('Superó los combates múltiples de la Torre Batalla.', 'Completed the Battle Tower Multi Battle challenge.'),
    'RibbonAbilityPair': ('Superó los combates múltiples con un amigo.', 'Completed the Battle Tower Link Multi Battle challenge.'),
    'RibbonAbilityWorld': ('Superó la Torre Batalla Wi-Fi.', 'Completed the Wi-Fi Battle Tower challenge.'),
    'RibbonLegend': ('Venció al legendario entrenador del Monte Plateado (HGSS).', 'Beat the legendary trainer on Mt. Silver (HGSS).'),
    'RibbonChampionKalos': ('Venció al Alto Mando de Kalos (X/Y).', 'Beat the Kalos Elite Four (X/Y).'),
    'RibbonChampionG6Hoenn': ('Venció al Alto Mando de Hoenn en Rubí Omega / Zafiro Alfa.', 'Beat the Hoenn Elite Four in Omega Ruby / Alpha Sapphire.'),
    'RibbonBattlerSkillful': ('Superó un desafío de la Maison Batalla.', 'Completed a Battle Maison challenge.'),
    'RibbonBattlerExpert': ('Superó el rango superior de la Maison Batalla.', 'Completed a Super Battle Maison challenge.'),
    'RibbonChampionAlola': ('Se convirtió en Campeón de Alola.', 'Became the Alola Champion.'),
    'RibbonBattleRoyale': ('Ganó el rango Maestro del Battle Royale.', 'Won the Master Rank of the Battle Royal Dome.'),
    'RibbonBattleTreeGreat': ('Superó el Árbol Batalla en rango normal.', 'Completed the Battle Tree regular challenge.'),
    'RibbonBattleTreeMaster': ('Superó el Árbol Batalla en rango súper.', 'Completed the Battle Tree super challenge.'),
    'RibbonChampionGalar': ('Ganó la Copa de Campeones de Galar.', 'Won the Galar Champion Cup.'),
    'RibbonTowerMaster': ('Venció en la Torre Batalla de Galar o de Sinnoh (DBPR).', 'Won at the Galar (or BDSP) Battle Tower.'),
    'RibbonMasterRank': ('Alcanzó el rango Master en combates clasificatorios.', 'Reached Master Ball tier in Ranked Battles.'),
    'RibbonChampionPaldea': ('Ganó la Academia y se convirtió en Campeón de Paldea.', 'Became a Paldea Champion.'),
    'RibbonEffort': ('Entrenado al máximo de puntos de esfuerzo.', 'Trained to the maximum effort values.'),
    'RibbonBestFriends': ('Alcanzó la máxima amistad (o afecto) con su entrenador.', 'Reached maximum friendship (or affection) with its trainer.'),
    'RibbonTraining': ('Superó el entrenamiento extremo del Superentrenamiento (X/Y).', 'Completed the toughest Super Training regimens (X/Y).'),
    'RibbonFootprint': ('Recibida del Dr. Huella por su gran amistad.', 'Given by Dr. Footstep for its strong bond.'),
    'RibbonAlert': ('Cinta de lunes: para levantarse con energía.', 'Monday ribbon: for waking up full of energy.'),
    'RibbonShock': ('Cinta de martes: para recordar ser fuerte.', 'Tuesday ribbon: a reminder to be strong.'),
    'RibbonDowncast': ('Cinta de miércoles: para animarse cuando está triste.', 'Wednesday ribbon: to cheer up when sad.'),
    'RibbonCareless': ('Cinta de jueves: para recordar tener cuidado.', 'Thursday ribbon: a reminder to be careful.'),
    'RibbonRelax': ('Cinta de viernes: para recordar relajarse.', 'Friday ribbon: a reminder to relax.'),
    'RibbonSnooze': ('Cinta de sábado: para recordar descansar.', 'Saturday ribbon: a reminder to take a nap.'),
    'RibbonSmile': ('Cinta de domingo: para recordar sonreír.', 'Sunday ribbon: a reminder to smile.'),
    'RibbonGorgeous': ('Cinta de lujo comprada en Ciudad Marina.', 'Luxury ribbon bought in Sunyshore City.'),
    'RibbonRoyal': ('Cinta de gran lujo comprada en Ciudad Marina.', 'Extremely luxurious ribbon bought in Sunyshore City.'),
    'RibbonGorgeousRoyal': ('La cinta más lujosa de Ciudad Marina.', 'The most luxurious ribbon in Sunyshore City.'),
    'RibbonNational': ('Purificado y entregado en Pokémon Colosseum / XD.', 'Purified in Pokémon Colosseum / XD.'),
    'RibbonEarth': ('Ganó 100 combates seguidos en el Monte Batalla (Colosseum / XD).', 'Won 100 straight battles at Mt. Battle (Colosseum / XD).'),
    'RibbonHisui': ('Completó la investigación de Hisui (Leyendas Arceus).', 'Completed the Hisui research (Legends: Arceus).'),
    'RibbonTwinklingStar': ('Superó el Espectáculo de Superconcursos con nota máxima (DBPR).', 'Earned a perfect Super Contest Show score (BDSP).'),
    'RibbonPartner': ('Compañero de confianza en Leyendas Z-A.', 'A trusted partner in Legends: Z-A.'),
    'RibbonCountry': ('Repartida en torneos y eventos nacionales.', 'Distributed at national tournaments and events.'),
    'RibbonWorld': ('Repartida en el Campeonato Mundial.', 'Distributed at the World Championships.'),
    'RibbonClassic': ('Regalo para un Pokémon que quiere a su entrenador (evento).', 'Event gift for a Pokémon that loves its trainer.'),
    'RibbonPremier': ('Conmemorativa de un evento especial.', 'Commemorates a special event.'),
    'RibbonEvent': ('Conmemorativa de un evento.', 'Commemorates an event.'),
    'RibbonBirthday': ('Conmemorativa de un cumpleaños (evento).', 'Commemorates a birthday (event).'),
    'RibbonSpecial': ('Conmemorativa de un evento especial.', 'Commemorates a special event.'),
    'RibbonSouvenir': ('Recuerdo de un evento.', 'Souvenir of an event.'),
    'RibbonWishing': ('Repartida en un evento para que se cumpla un deseo.', 'Event ribbon for making a wish come true.'),
    'RibbonRecord': ('Repartida por un récord en un evento.', 'Given for setting a record at an event.'),
    'RibbonChampionBattle': ('Ganador de un torneo oficial.', 'Winner of an official battle competition.'),
    'RibbonChampionRegional': ('Campeón de un torneo regional.', 'Champion of a regional tournament.'),
    'RibbonChampionNational': ('Campeón de un torneo nacional.', 'Champion of a national tournament.'),
    'RibbonChampionWorld': ('Campeón del Campeonato Mundial.', 'World Championships champion.'),
    'RibbonOnceInALifetime': ('Repartida una sola vez en la vida (evento).', 'A once-in-a-lifetime event ribbon.'),
    'RibbonMarkLunchtime': ('Encontrado a la hora de comer.', 'Found at lunchtime.'),
    'RibbonMarkSleepyTime': ('Encontrado de noche.', 'Found at night.'),
    'RibbonMarkDusk': ('Encontrado al anochecer.', 'Found at dusk.'),
    'RibbonMarkDawn': ('Encontrado al amanecer.', 'Found at dawn.'),
    'RibbonMarkCloudy': ('Encontrado con el cielo nublado.', 'Found under cloudy skies.'),
    'RibbonMarkRainy': ('Encontrado bajo la lluvia.', 'Found in the rain.'),
    'RibbonMarkStormy': ('Encontrado en una tormenta.', 'Found in a thunderstorm.'),
    'RibbonMarkSnowy': ('Encontrado en la nieve.', 'Found in the snow.'),
    'RibbonMarkBlizzard': ('Encontrado en una ventisca.', 'Found in a blizzard.'),
    'RibbonMarkDry': ('Encontrado con sol intenso.', 'Found in intense sunlight.'),
    'RibbonMarkSandstorm': ('Encontrado en una tormenta de arena.', 'Found in a sandstorm.'),
    'RibbonMarkMisty': ('Encontrado en la niebla.', 'Found in the fog.'),
    'RibbonMarkDestiny': ('Capturado el día del cumpleaños del entrenador.', "Caught on the trainer's birthday."),
    'RibbonMarkFishing': ('Pescado con caña.', 'Fished with a rod.'),
    'RibbonMarkCurry': ('Apareció en el campamento al preparar curry.', 'Showed up at camp while cooking curry.'),
    'RibbonMarkUncommon': ('Emblema poco común de un encuentro salvaje.', 'An uncommon mark from a wild encounter.'),
    'RibbonMarkRare': ('Emblema muy raro de un encuentro salvaje.', 'A very rare mark from a wild encounter.'),
    'RibbonMarkJumbo': ('El ejemplar más grande posible de su especie.', 'The largest possible size for its species.'),
    'RibbonMarkMini': ('El ejemplar más pequeño posible de su especie.', 'The smallest possible size for its species.'),
    'RibbonMarkItemfinder': ('Encontró objetos para su entrenador (SV).', 'Found items for its trainer (SV).'),
    'RibbonMarkPartner': ('Compañero inseparable en las aventuras de Paldea.', 'An inseparable partner on Paldea adventures.'),
    'RibbonMarkGourmand': ('Comió muchísimos bocadillos con su entrenador.', 'Ate lots of sandwiches with its trainer.'),
    'RibbonMarkAlpha': ('Fue un Pokémon alfa.', 'Was an Alpha Pokémon.'),
    'RibbonMarkMightiest': ('Capturado en una teraincursión de 7 estrellas.', 'Caught in a 7-star Tera Raid.'),
    'RibbonMarkTitan': ('Fue un Pokémon Titán de Paldea.', 'Was one of the Titan Pokémon of Paldea.'),
  };

  static String describe(RibbonInfo r, DataLanguage lang) {
    final es = lang == DataLanguage.es;
    final s = _special[r.key];
    if (s != null) return es ? s.$1 : s.$2;
    final k = r.key;
    final g3 = RegExp(r'^RibbonG3(Cool|Beauty|Cute|Smart|Tough)(Super|Hyper|Master)?$').firstMatch(k);
    if (g3 != null) {
      final cat = es ? _contestEs[g3[1]] : _contestEn[g3[1]];
      final rank = switch (g3[2]) { 'Super' => es ? 'Alto' : 'Super', 'Hyper' => es ? 'Avanzado' : 'Hyper', 'Master' => es ? 'Experto' : 'Master', _ => 'Normal' };
      return es ? 'Ganó el concurso de $cat en rango $rank (Hoenn, Gen 3).' : 'Won the $cat contest at $rank Rank (Hoenn, Gen 3).';
    }
    final g4 = RegExp(r'^RibbonG4(Cool|Beauty|Cute|Smart|Tough)(Great|Ultra|Master)?$').firstMatch(k);
    if (g4 != null) {
      final cat = es ? _contestEs[g4[1]] : _contestEn[g4[1]];
      final rank = switch (g4[2]) { 'Great' => es ? 'Difícil' : 'Great', 'Ultra' => es ? 'Superior' : 'Ultra', 'Master' => es ? 'Experto' : 'Master', _ => 'Normal' };
      return es
          ? 'Ganó el Superconcurso de $cat en rango $rank (Sinnoh, Gen 4 o DBPR).'
          : 'Won the $cat Super Contest at $rank Rank (Sinnoh, Gen 4 or BDSP).';
    }
    final cnt = RegExp(r'^RibbonCountG3(Cool|Beauty|Cute|Smart|Tough)$').firstMatch(k);
    if (cnt != null) {
      final cat = es ? _contestEs[cnt[1]] : _contestEn[cnt[1]];
      return es
          ? 'Rangos de concurso de $cat ganados en Hoenn (0–4: Normal, Alto, Avanzado, Experto).'
          : 'Hoenn $cat contest ranks won (0–4: Normal, Super, Hyper, Master).';
    }
    final master = RegExp(r'^RibbonMaster(Coolness|Beauty|Cuteness|Cleverness|Toughness)$').firstMatch(k);
    if (master != null) {
      return es ? 'Ganó un concurso de rango Experto en Rubí Omega / Zafiro Alfa.' : 'Won a Master Rank contest in Omega Ruby / Alpha Sapphire.';
    }
    if (r.category == RibbonCategory.mark) {
      return es
          ? 'Emblema de personalidad que puede aparecer en un Pokémon salvaje; le da un título.'
          : 'A personality mark a wild Pokémon may carry; it grants a title.';
    }
    return es ? 'Cinta especial.' : 'Special ribbon.';
  }
}
