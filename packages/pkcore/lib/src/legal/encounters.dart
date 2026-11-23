import 'dart:convert';
import '../data/forms.dart';
import '../data/game_data.dart';
import '../data/generated/encounter_data.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import '../util/bytes.dart';
import 'origin.dart';

/// Tipo de encuentro (PKHeX `EncounterSlot*`, `EncounterStatic*`, `EncounterTrade*`).
enum EncounterKind { wild, static, gift, trade, raid }

/// Una entrada de las tablas de encuentros de un juego de origen.
class EncounterSlot {
  const EncounterSlot(this.location, this.species, this.form, this.minLevel, this.maxLevel, this.kind);

  /// Lugar (id interno del juego); [anyLocation] para intercambios con NPC.
  final int location;
  final int species;
  final int form;
  final int minLevel;
  final int maxLevel;
  final EncounterKind kind;

  static const int anyLocation = 0xFFFF;

  /// Incursión Dinamax de Espada/Escudo: cualquier guarida (PKHeX `EncounterStatic8N.IsMatchLocation`).
  static const int anyDen = 0xFFFE;

  /// `true` si el encuentro pudo registrarse en el lugar [loc].
  bool acceptsLocation(int loc) => location == loc || (location == anyDen && isDenLocation8(loc));

  /// Zona Silvestre, Isla de la Armadura, Corona Nevada (PKHeX `EncounterArea8.IsWildArea`)
  /// o el nido compartido (162, incursiones en línea).
  static bool isDenLocation8(int loc) =>
      loc == 162 || (loc >= 122 && loc <= 154) || (loc >= 164 && loc <= 194) || (loc >= 204 && loc <= 234 && loc != 206);

  bool acceptsLevel(int level) => level >= minLevel && level <= maxLevel;

  @override
  String toString() => '#$species@$location niv.$minLevel-$maxLevel ${kind.name}';
}

/// Tablas de encuentros portadas de PKHeX.Core (salvajes, estáticos, regalos e
/// intercambios con NPC), generadas con `tool/gen_encounter_data.py`.
///
/// Incluyen las incursiones Dinamax de Espada/Escudo (nidos, distribuciones,
/// Aventura Dinamax y cristales). No incluyen (todavía) teraincursiones, brotes masivos, el
/// Subsuelo de DBPR, eventos (Mystery Gift) ni los estáticos de Gen 3, Leyendas
/// Arceus y Z-A, que en PKHeX están en constructores posicionales: en esos
/// juegos un encuentro no encontrado solo genera un aviso informativo.
abstract final class EncounterTables {
  static final Map<int, List<EncounterSlot>> _cache = {};

  /// Versiones (ids de PKHeX) con tablas cargadas.
  static Iterable<int> get versions => kEncounters.keys;

  /// Juegos cuyas tablas cubren todas las fuentes normales de Pokémon
  /// (salvajes, estáticos, regalos e intercambios): ahí un desajuste es un
  /// aviso fuerte. En el resto es informativo.
  static bool isComplete(int version) => const {24, 25, 26, 27, 30, 31, 32, 33, 42, 43}.contains(version);

  static List<EncounterSlot> forVersion(int version) => _cache.putIfAbsent(version, () {
        final raw = kEncounters[version];
        if (raw == null) return const [];
        final d = base64Decode(raw);
        return [
          for (var o = 0; o + 8 <= d.length; o += 8)
            EncounterSlot(d.u16le(o), d.u16le(o + 2), d[o + 4], d[o + 5], d[o + 6], EncounterKind.values[d[o + 7].clamp(0, 4)]),
        ];
      });

  /// La especie y sus preevoluciones (de la más evolucionada a la base).
  static List<int> evolutionChain(int species) {
    final out = <int>[];
    var s = species;
    while (s > 0 && s < kEvolvesFrom.length && !out.contains(s)) {
      out.add(s);
      s = kEvolvesFrom[s];
    }
    return out;
  }

  static final Map<String, Map<int, String>> _names = {};

  static String _locKey(int version) => switch (version) {
        42 || 43 => 'lgpe',
        47 => 'la',
        48 || 49 => 'bdsp',
        1 || 2 || 3 || 4 || 5 => '3',
        7 || 8 || 10 || 11 || 12 => '4',
        20 || 21 || 22 || 23 => '5',
        24 || 25 || 26 || 27 => '6',
        30 || 31 || 32 || 33 => '7',
        44 || 45 => '8',
        _ => '9',
      };

  /// Nombre del lugar [location] en el juego [version] (o "#id" si no se conoce).
  static String locationName(int version, int location, [DataLanguage lang = DataLanguage.es]) {
    if (location == EncounterSlot.anyLocation) return lang == DataLanguage.es ? 'intercambio' : 'trade';
    if (location == EncounterSlot.anyDen) return lang == DataLanguage.es ? 'incursión Dinamax' : 'Max Raid';
    final key = '${_locKey(version)}_${lang.name}';
    final map = _names.putIfAbsent(key, () {
      final raw = kLocationNames[key] ?? '';
      return {
        for (final line in raw.split('\n'))
          if (line.split('\t') case [final id, final name]) int.parse(id): name,
      };
    });
    final name = map[location];
    if (name != null && name.trim().isNotEmpty) return name;
    // Nunca «#0»: un lugar sin nombre se describe con texto legible.
    final es = lang == DataLanguage.es;
    if (location <= 0) return es ? 'un lugar desconocido' : 'an unknown place';
    return es ? 'un lugar sin nombre (id $location)' : 'an unnamed place (id $location)';
  }

  /// Errantes por versión (PKHeX `IsRoaming`): su lugar de encuentro es cualquier ruta.
  static const Map<int, Set<int>> _roamers = {
    1: {380}, 2: {381}, 3: {380, 381}, // Latias/Latios (Zafiro, Rubí, Esmeralda)
    4: {243, 244, 245}, 5: {243, 244, 245}, // Raikou, Entei, Suicune (RFVH)
    7: {243, 244, 380}, 8: {243, 244, 381}, // Raikou, Entei y Latias/Latios (HGSS)
    10: {481, 488}, 11: {481, 488}, 12: {481, 488, 144, 145, 146}, // Mesprit, Cresselia (y aves en Platino)
    20: {642}, 21: {641}, // Thundurus (Blanco), Tornadus (Negro)
    24: {144, 145, 146}, 25: {144, 145, 146}, // Aves legendarias (X/Y)
  };

  static bool isRoamer(int version, int species) => _roamers[version]?.contains(species) ?? false;

  /// `true` si [location] es un lugar especial (huevo, intercambio, evento,
  /// traspaso) que no aparece en las tablas de encuentros.
  static bool isSpecialLocation(PkFormat format, int version, int location) {
    if (location < 0) return true;
    final gen = switch (version) {
      >= 1 && <= 5 => 3,
      >= 7 && <= 12 => 4,
      >= 20 && <= 23 => 5,
      _ => 6,
    };
    return switch (gen) {
      3 => location >= 253,
      4 => location >= 2000,
      _ => location >= 30000,
    };
  }
}

/// Resultado de buscar el encuentro de un Pokémon en las tablas de su juego de origen.
class EncounterCheck {
  const EncounterCheck({
    required this.version,
    required this.candidates,
    required this.atLocation,
    required this.matching,
    required this.checked,
  });

  final int version;

  /// Encuentros de la especie (o sus preevoluciones) en el juego de origen.
  final List<EncounterSlot> candidates;

  /// Los anteriores que coinciden con el lugar de encuentro.
  final List<EncounterSlot> atLocation;

  /// Los que además coinciden con el nivel de encuentro.
  final List<EncounterSlot> matching;

  /// `false` si no se comprobó (huevo, evento, lugar especial, juego sin tablas).
  final bool checked;

  bool get valid => !checked || matching.isNotEmpty;

  /// Compara el lugar, el nivel y la especie de [pk] con las tablas de su juego de origen.
  static EncounterCheck of(Pkm pk) {
    final v = pk.version;
    const none = <EncounterSlot>[];
    EncounterCheck skip() => EncounterCheck(version: v, candidates: none, atLocation: none, matching: none, checked: false);
    final table = EncounterTables.forVersion(v);
    if (table.isEmpty || pk.isEgg || pk.fatefulEncounter || pk.hatchedFromEgg) return skip();
    final loc = pk.metLocation;
    if (EncounterTables.isSpecialLocation(pk.format, v, loc)) return skip();
    // Pal Park (Gen 3 → 4) sobrescribe el lugar y el nivel de encuentro: el original se pierde.
    final gen3Origin = (v >= 1 && v <= 5) || v == 15;
    if (gen3Origin && pk.format.generation >= 4) return skip();
    final chain = EncounterTables.evolutionChain(pk.species);
    // Con forma: un Growlithe de Hisui no sale de un encuentro de Growlithe
    // normal. Solo cuentan las formas con otros tipos o stats (regionales,
    // Rotom…); las de aspecto (Unown, Vivillon) se aceptan en cualquier forma.
    final origin = OriginPlace.gameOf(v);
    final formChain = origin == null ? null : SpeciesForms.evolutionChain(pk.species, pk.form, origin);
    bool formMatches(EncounterSlot e) {
      if (formChain == null || e.form >= 30) return true; // 30/31: forma aleatoria o dinámica
      final want = formChain.where((c) => c.$1 == e.species).firstOrNull;
      return want == null || !SpeciesForms.formsDiffer(e.species, e.form, want.$2, origin);
    }

    final candidates = [for (final e in table) if (chain.contains(e.species) && formMatches(e)) e];
    // Errantes: se pueden encontrar en cualquier ruta, el lugar registrado varía.
    final roamer = EncounterTables.isRoamer(v, pk.species);
    final atLocation = [for (final e in candidates) if (e.acceptsLocation(loc) || (roamer && e.species == pk.species)) e];
    final met = pk.metLevel;
    final matching = [for (final e in atLocation) if (e.acceptsLevel(met)) e];
    return EncounterCheck(version: v, candidates: candidates, atLocation: atLocation, matching: matching, checked: true);
  }

  /// Nivel de encuentro válido más cercano al actual (para corregir), o null.
  int? nearestLevel(int metLevel, int currentLevel) {
    int? best;
    for (final e in atLocation) {
      final l = metLevel.clamp(e.minLevel, e.maxLevel);
      if (l > currentLevel) continue;
      if (best == null || (l - metLevel).abs() < (best - metLevel).abs()) best = l;
    }
    return best;
  }

  /// Resumen legible de los lugares posibles: "Ruta 3 (niv. 3–5), …".
  String describe(List<EncounterSlot> slots, DataLanguage lang, {int max = 4}) {
    final byLoc = <int, (int, int)>{};
    for (final e in slots) {
      final cur = byLoc[e.location];
      byLoc[e.location] = cur == null ? (e.minLevel, e.maxLevel) : (cur.$1 < e.minLevel ? cur.$1 : e.minLevel, cur.$2 > e.maxLevel ? cur.$2 : e.maxLevel);
    }
    final lv = lang == DataLanguage.es ? 'niv.' : 'lv.';
    final parts = [
      for (final MapEntry(key: l, value: (a, b)) in byLoc.entries.take(max))
        '${EncounterTables.locationName(version, l, lang)} ($lv ${a == b ? '$a' : '$a–$b'})',
    ];
    final more = byLoc.length - parts.length;
    if (more > 0) parts.add(lang == DataLanguage.es ? 'y $more más' : 'and $more more');
    return parts.join(', ');
  }
}

/// Lugar de eclosión (si el Pokémon salió de un huevo).
extension PkmEggOrigin on Pkm {
  int get eggLocation => switch (format) {
        PkFormat.pk4 => data.u16le(0x44) != 0 ? data.u16le(0x44) : data.u16le(0x7E),
        PkFormat.pk5 => data.u16le(0x7E),
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => data.u16le(0xD8),
        PkFormat.pa8 => data.u16le(0x138),
        PkFormat.pk8 || PkFormat.pb8 || PkFormat.pk9 || PkFormat.pa9 => data.u16le(0x120),
        _ => 0,
      };

  set eggLocation(int v) {
    switch (format) {
      case PkFormat.pk4:
        data.setU16le(0x7E, v == 0 ? 0 : ((v > 111 && v < 2000) || (v > 2010 && v < 3000) ? 3002 : v));
        data.setU16le(0x44, v);
      case PkFormat.pk5:
        data.setU16le(0x7E, v);
      case PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        data.setU16le(0xD8, v);
      case PkFormat.pa8:
        data.setU16le(0x138, v);
      case PkFormat.pk8 || PkFormat.pb8 || PkFormat.pk9 || PkFormat.pa9:
        data.setU16le(0x120, v);
      default:
        return;
    }
  }

  /// `true` si salió de un huevo (Gen 3: nivel de encuentro 0).
  bool get hatchedFromEgg => format == PkFormat.pk3 ? metLevel == 0 : eggLocation != 0;
}
