import 'dart:convert';
import 'dart:typed_data';

import '../model/game.dart';
import '../util/bytes.dart';
import 'generated/game_binaries.dart';
import 'generated/form_names.dart';
import 'generated/game_text.dart';
import 'generated/gc_data.dart';
import 'generated/learn_extra.dart';
import 'species.dart';

/// Idioma de los nombres de datos de juego.
enum DataLanguage { es, en }

/// Datos "personales" de una especie/forma en un juego concreto.
class PersonalEntry {
  const PersonalEntry({
    required this.baseStats,
    required this.type1,
    required this.type2,
    required this.genderRatio,
    required this.growth,
    required this.abilities,
    required this.formCount,
    required this.formStatsIndex,
    required this.tmBits,
  });

  /// Stats base en orden PS, Atq, Def, AtqEsp, DefEsp, Vel.
  final List<int> baseStats;

  /// Tipos (ids de PKHeX: 0 = Normal … 17 = Hada; en Gen 1/2 son ids internos).
  final int type1, type2;

  /// 0 = solo macho, 254 = solo hembra, 255 = sin género; otro = umbral.
  final int genderRatio;
  final int growth;

  /// Habilidades (1, 2, oculta) donde existan.
  final List<int> abilities;
  final int formCount;
  final int formStatsIndex;
  final Uint8List tmBits;

  bool get genderless => genderRatio == 255;
  bool get onlyMale => genderRatio == 0;
  bool get onlyFemale => genderRatio == 254;
  int get baseStatTotal => baseStats.fold(0, (a, b) => a + b);
}

/// Un movimiento aprendido por nivel.
typedef LevelMove = ({int move, int level});

/// Tablas de datos (stats base, learnsets, MT) de un juego.
class GameDataTable {
  GameDataTable._(this.key, this.context, String personal, this._count, this._record, String tm, String lvl,
      String? egg)
      : _personal = base64Decode(personal),
        _tm = base64Decode(tm),
        _lvl = base64Decode(lvl),
        _egg = egg == null ? null : base64Decode(egg);

  static final Map<String, GameDataTable> _cache = {};

  /// Clave de tabla: rb, y, gs, c, rs, e, fr, dp, pt, hgss, bw, b2w2, xy, ao, sm, uu, gg, swsh, bdsp, la, sv, za.
  final String key;

  /// Contexto de movimientos (1 … 9a).
  final String context;
  final Uint8List _personal;
  final int _count;
  final int _record;
  final Uint8List _tm;
  final Uint8List _lvl;
  final Uint8List? _egg;

  static GameDataTable forGame(GameVersion game) {
    final (key, ctx) = switch (game) {
      GameVersion.redBlue => ('rb', '1'),
      GameVersion.yellow => ('y', '1'),
      GameVersion.goldSilver => ('gs', '2'),
      GameVersion.crystal => ('c', '2'),
      GameVersion.rubySapphire => ('rs', '3'),
      GameVersion.emerald => ('e', '3'),
      GameVersion.fireRedLeafGreen => ('fr', '3'),
      // Colosseum/XD usan los datos personales de RZ (PKHeX `PersonalTable.RS`)
      // y los movimientos por nivel de Esmeralda.
      GameVersion.colosseum || GameVersion.xd => ('e', '3'),
      GameVersion.diamondPearl => ('dp', '4'),
      GameVersion.platinum => ('pt', '4'),
      GameVersion.heartGoldSoulSilver => ('hgss', '4'),
      GameVersion.blackWhite => ('bw', '5'),
      GameVersion.black2White2 => ('b2w2', '5'),
      GameVersion.xy => ('xy', '6'),
      GameVersion.omegaRubyAlphaSapphire => ('ao', '6'),
      GameVersion.sunMoon => ('sm', '7'),
      GameVersion.ultraSunUltraMoon => ('uu', '7'),
      GameVersion.letsGo => ('gg', '7b'),
      GameVersion.swordShield => ('swsh', '8'),
      GameVersion.brilliantDiamondShiningPearl => ('bdsp', '8b'),
      GameVersion.legendsArceus => ('la', '8a'),
      GameVersion.scarletViolet => ('sv', '9'),
      GameVersion.legendsZA => ('za', '9a'),
    };
    return _cache.putIfAbsent(key, () {
      final t = kGameTables[key]!;
      return GameDataTable._(key, ctx, t.$1, t.$2, t.$3, t.$4, t.$5, t.$6);
    });
  }

  int get entryCount => _count;

  /// Índice de la entrada para especie+forma.
  int formIndex(int species, int form) {
    if (species <= 0 || species >= _count) return 0;
    if (form <= 0) return species;
    final base = _entryAt(species);
    if (form >= base.formCount || base.formStatsIndex == 0) return species;
    final idx = base.formStatsIndex + form - 1;
    return idx < _count ? idx : species;
  }

  /// Última especie (Pokédex Nacional) de los datos personales; las entradas
  /// siguientes son formas alternativas, no especies.
  int get maxSpecies => switch (key) {
        'rb' || 'y' => 151,
        'gs' || 'c' => 251,
        _ => kGameMaxSpecies[key] ?? _count - 1,
      };

  /// `true` si la especie existe en el juego, en alguna forma (PKHeX
  /// `IsPresentInGame`): Growlithe solo está en Leyendas Arceus como forma de
  /// Hisui; Caterpie tiene datos en Escarlata/Púrpura pero no está en el juego.
  bool hasSpecies(int species) {
    if (species <= 0 || species > maxSpecies || species >= _count) return false;
    final mask = kFormPresence[key]?[species];
    if (mask != null) return mask != 0;
    return _entryAt(species).baseStatTotal > 0;
  }

  PersonalEntry? entry(int species, [int form = 0]) {
    if (species <= 0 || species >= _count) return null;
    return _entryAt(formIndex(species, form));
  }

  PersonalEntry _entryAt(int i) {
    final o = i * _record;
    final d = _personal;
    final abil = <int>[for (var j = 0; j < 3; j++) d.u16le(o + 10 + j * 2)]..removeWhere((a) => a == 0);
    return PersonalEntry(
      baseStats: [d[o], d[o + 1], d[o + 2], d[o + 4], d[o + 5], d[o + 3]],
      type1: d[o + 6],
      type2: d[o + 7],
      genderRatio: d[o + 8],
      growth: d[o + 9],
      abilities: abil,
      formCount: d[o + 18] == 0 ? 1 : d[o + 18],
      formStatsIndex: d.u16le(o + 16),
      tmBits: d.sublist(o + 20, o + _record),
    );
  }

  int get _gen => int.parse(context.substring(0, 1));

  /// Movimientos de MT/MO/DT compatibles con la especie+forma.
  Set<int> machineMoves(int species, [int form = 0]) {
    final e = entry(species, form);
    if (e == null) return const {};
    // Gen 3: los datos personales no traen las MT/MO (PKHeX `hmtm_g3.pkl`).
    if (_gen == 3) return _bitMoves(_g3Machine, kG3MachineWidth, species, kG3MachineMoves);
    final result = <int>{};
    final n = _tm.length ~/ 2;
    for (var i = 0; i < n && (i >> 3) < e.tmBits.length; i++) {
      if ((e.tmBits[i >> 3] & (1 << (i & 7))) != 0) result.add(_tm.u16le(i * 2));
    }
    return result;
  }

  /// Todos los movimientos de MT/MO del juego (por índice de MT).
  List<int> get machineList => [for (var i = 0; i < _tm.length ~/ 2; i++) _tm.u16le(i * 2)];

  int _learnsetIndex(int species, int form) {
    final gen = int.parse(context.substring(0, 1));
    return gen <= 3 ? species : formIndex(species, form);
  }

  List<LevelMove> levelUpMoves(int species, [int form = 0]) {
    final entry = _BinLinker16(_lvl)[_learnsetIndex(species, form)];
    if (entry == null || entry.isEmpty) return const [];
    final count = entry.length ~/ 3;
    return [
      for (var i = 0; i < count; i++) (move: entry.u16le(i * 2), level: entry[count * 2 + i]),
    ];
  }

  static final Uint8List _zaPlusLevels = base64Decode(kZaPlusLevels);
  static final Uint8List _zaAlphaMoves = base64Decode(kZaAlphaMoves);

  /// Leyendas Z-A: movimiento de cada índice de flag «plus» (PKHeX `PersonalInfo9ZA.PlusMoves`).
  static final List<int> zaPlusMoves = () {
    final b = base64Decode(kZaPlusMoves);
    return List<int>.unmodifiable([for (var i = 0; i + 1 < b.length; i += 2) b.u16le(i)]);
  }();

  /// Leyendas Z-A: nivel al que cada movimiento se vuelve «plus» de forma
  /// natural (PKHeX `plus_za.pkl`). Vacío en otros juegos.
  List<LevelMove> plusLevelMoves(int species, [int form = 0]) {
    if (key != 'za') return const [];
    final entry = _BinLinker16(_zaPlusLevels)[formIndex(species, form)];
    if (entry == null || entry.isEmpty) return const [];
    final count = entry.length ~/ 3;
    return [
      for (var i = 0; i < count; i++) (move: entry.u16le(i * 2), level: entry[count * 2 + i]),
    ];
  }

  /// Leyendas Z-A: movimiento que traen los alfa salvajes (PKHeX `AlphaMove`); 0 si no hay.
  int alphaMove(int species, [int form = 0]) {
    if (key != 'za') return 0;
    final i = formIndex(species, form);
    return i * 2 + 1 < _zaAlphaMoves.length ? _zaAlphaMoves.u16le(i * 2) : 0;
  }

  List<int> eggMoves(int species, [int form = 0]) {
    final egg = _egg;
    if (egg == null) return const [];
    final entry = _BinLinker16(egg)[_learnsetIndex(species, form)];
    if (entry == null) return const [];
    return [for (var i = 0; i + 1 < entry.length; i += 2) entry.u16le(i)];
  }

  static final Uint8List _g3Machine = base64Decode(kG3MachineFlags);
  static final Uint8List _g3Tutor = base64Decode(kG3TutorFlags);
  static final Uint8List _g4Tutor = base64Decode(kG4TutorFlags);

  static Set<int> _bitMoves(Uint8List flags, int width, int index, List<int> moves) {
    final o = index * width;
    if (index <= 0 || o + width > flags.length) return const {};
    return {
      for (var i = 0; i < moves.length && (i >> 3) < width; i++)
        if ((flags[o + (i >> 3)] & (1 << (i & 7))) != 0) moves[i],
    };
  }

  /// Movimientos de tutor (PKHeX `LearnSource3*`/`LearnSource4*`): tutores de
  /// RFVH/Esmeralda en Gen 3; de Platino/HGSS, movimientos definitivos de los
  /// iniciales, Cometa Draco y formas de Rotom en Gen 4. Otras generaciones: vacío.
  Set<int> tutorMoves(int species, [int form = 0]) {
    final gen = _gen;
    if (gen != 3 && gen != 4) return const {};
    final out = <int>{};
    if (gen == 3) {
      out.addAll(_bitMoves(_g3Tutor, kG3TutorWidth, species, kG3TutorMoves));
    } else {
      final idx = GameDataTable.forGame(GameVersion.heartGoldSoulSilver).formIndex(species, form);
      out.addAll(_bitMoves(_g4Tutor, kG4TutorWidth, idx, kG4TutorMoves));
      if (species == 479 && form >= 1 && form <= 5) out.add(const [315, 56, 59, 403, 437][form - 1]);
      if (const {147, 148, 149, 230, 329, 330, 334, 371, 372, 373, 380, 381, 384, 443, 444, 445, 483, 484, 487}
          .contains(species)) {
        out.add(434); // Cometa Draco
      }
    }
    // Movimientos definitivos de los iniciales (Cabo Cicatriz en RFVH; Ruta 228 en Platino/HGSS).
    if (const {3, 154, 254, 389}.contains(species)) out.add(338); // Planta Feroz
    if (const {6, 157, 257, 392}.contains(species)) out.add(307); // Anillo Ígneo
    if (const {9, 160, 260, 395}.contains(species)) out.add(308); // Hidrocañón
    return out;
  }

  /// Unión de movimientos aprendibles conocidos (nivel, huevo, MT y tutores).
  Set<int> learnableMoves(int species, [int form = 0]) => {
        for (final m in levelUpMoves(species, form)) m.move,
        ...eggMoves(species, form),
        ...machineMoves(species, form),
        ...tutorMoves(species, form),
      };
}

class _BinLinker16 {
  _BinLinker16(this.data);
  final Uint8List data;

  int get length => data.u16le(2);

  Uint8List? operator [](int index) {
    if (index < 0 || index >= length) return null;
    final ofs = 4 + index * 2;
    final start = data.u16le(ofs);
    final end = data.u16le(ofs + 2);
    if (end < start || end > data.length) return null;
    return Uint8List.sublistView(data, start, end);
  }
}

/// Información de movimientos (PP, tipo, disponibilidad) por contexto.
abstract final class MoveData {
  static final Map<String, (Uint8List, Uint8List?, Uint8List?)> _cache = {};

  static (Uint8List, Uint8List?, Uint8List?) _tables(String ctx) => _cache.putIfAbsent(ctx, () {
        final t = kMoveTables[ctx]!;
        return (
          base64Decode(t.$1),
          t.$2 == null ? null : base64Decode(t.$2!),
          t.$3 == null ? null : base64Decode(t.$3!),
        );
      });

  /// Id máximo de movimiento del contexto.
  static int maxMove(String ctx) => _tables(ctx).$1.length - 1;

  /// PP base del movimiento.
  static int basePp(int move, String ctx) {
    final pp = _tables(ctx).$1;
    return move > 0 && move < pp.length ? pp[move] : 0;
  }

  /// PP máximos con [ppUps] (0–3) aplicados.
  static int maxPp(int move, String ctx, int ppUps) {
    final b = basePp(move, ctx);
    if (ctx == '8a' || ctx == '9a') return b; // sin Más PP
    return b + (b * ppUps.clamp(0, 3)) ~/ 5;
  }

  /// Tipo del movimiento (0 = Normal … 17 = Hada).
  static int type(int move, String ctx) {
    final key = ctx == '1' ? '1' : (int.parse(ctx[0]) <= 5 ? '5' : (ctx == '9a' ? '9a' : '9'));
    final t = _tables(key).$2!;
    return move > 0 && move < t.length ? t[move] : 0;
  }

  /// `true` si el movimiento existe y es utilizable en el contexto.
  static bool existsIn(int move, String ctx) {
    if (move <= 0 || move > maxMove(ctx)) return false;
    final d = _tables(ctx).$3;
    if (d == null) return true;
    final byte = move >> 3;
    if (byte >= d.length) return true;
    return (d[byte] & (1 << (move & 7))) == 0;
  }
}

/// Nombres de movimientos, objetos, habilidades, naturalezas y tipos.
abstract final class GameStrings {
  static String _pick(List<String> list, int i) => i >= 0 && i < list.length ? list[i] : '#$i';

  static String move(int id, [DataLanguage lang = DataLanguage.es]) =>
      _pick(lang == DataLanguage.es ? kMovesEs : kMovesEn, id);
  static String ability(int id, [DataLanguage lang = DataLanguage.es]) =>
      _pick(lang == DataLanguage.es ? kAbilitiesEs : kAbilitiesEn, id);
  static String nature(int id, [DataLanguage lang = DataLanguage.es]) =>
      _pick(lang == DataLanguage.es ? kNaturesEs : kNaturesEn, id);
  static String type(int id, [DataLanguage lang = DataLanguage.es]) =>
      _pick(lang == DataLanguage.es ? kTypesEs : kTypesEn, id);

  static List<String> moveList([DataLanguage lang = DataLanguage.es]) => lang == DataLanguage.es ? kMovesEs : kMovesEn;
  static List<String> abilityList([DataLanguage lang = DataLanguage.es]) =>
      lang == DataLanguage.es ? kAbilitiesEs : kAbilitiesEn;
  static List<String> natureList([DataLanguage lang = DataLanguage.es]) =>
      lang == DataLanguage.es ? kNaturesEs : kNaturesEn;
  static List<String> typeList([DataLanguage lang = DataLanguage.es]) => lang == DataLanguage.es ? kTypesEs : kTypesEn;

  /// Lista de nombres de objetos con los ids propios de [generation].
  static List<String> itemList(int generation, [DataLanguage lang = DataLanguage.es]) {
    final es = lang == DataLanguage.es;
    return switch (generation) {
      1 => es ? kItemsG1Es : kItemsG1En,
      2 => es ? kItemsG2Es : kItemsG2En,
      3 => es ? kItemsG3Es : kItemsG3En,
      4 => es ? _itemsG4Es : _itemsG4En,
      _ => es ? kItemsEs : kItemsEn,
    };
  }

  // Gen 4 (PKHeX `GameStrings.g4items`): las Cartas 137–148 cambiaron de nombre en
  // Gen 5 (`text_Mail4_*.txt`) y MO07/MO08 (426–427) no existen en la lista moderna.
  static final List<String> _itemsG4Es = _g4Items(kItemsEs, const [
    'Carta Hierba', 'Carta Fuego', 'Carta Pompas', 'Carta Flores', 'Carta Mina', 'Carta Acero', //
    'Carta Corazón', 'Carta Nieve', 'Carta Sideral', 'Carta Aérea', 'Carta Mosaico', 'Carta Pared',
  ], 'MO');
  static final List<String> _itemsG4En = _g4Items(kItemsEn, const [
    'Grass Mail', 'Flame Mail', 'Bubble Mail', 'Bloom Mail', 'Tunnel Mail', 'Steel Mail', //
    'Heart Mail', 'Snow Mail', 'Space Mail', 'Air Mail', 'Mosaic Mail', 'Brick Mail',
  ], 'HM');

  static List<String> _g4Items(List<String> modern, List<String> mail, String hm) {
    final out = List<String>.of(modern);
    out.setRange(137, 137 + mail.length, mail);
    out[426] = '${hm}07';
    out[427] = '${hm}08';
    return List.unmodifiable(out);
  }

  static String item(int id, int generation, [DataLanguage lang = DataLanguage.es]) =>
      _pick(itemList(generation, lang), id);

  /// Nombre de un objeto en [game]: igual que [item], salvo en Colosseum y XD,
  /// que tienen objetos propios desde el id 500 (llaves, colonias, discos).
  static String itemFor(int id, GameVersion game, [DataLanguage lang = DataLanguage.es]) {
    if (game.isGameCube && id >= 500) {
      final es = lang == DataLanguage.es;
      final list = game == GameVersion.colosseum
          ? (es ? kGcItemsColoEs : kGcItemsColoEn)
          : (es ? kGcItemsXdEs : kGcItemsXdEn);
      if (id - 500 < list.length && list[id - 500].trim().isNotEmpty) return list[id - 500];
    }
    return item(id, game.generation, lang);
  }

  static String species(int id, [DataLanguage lang = DataLanguage.es]) =>
      Species.name(id, lang == DataLanguage.es ? SpeciesLanguage.es : SpeciesLanguage.en);

  /// Efecto de una naturaleza: (stat que sube, stat que baja) en orden API (1 = Atq … 5 = Vel), o null si es neutra.
  static (int, int)? natureEffect(int nature) {
    if (nature < 0 || nature >= 25) return null;
    final up = nature ~/ 5, down = nature % 5;
    if (up == down) return null;
    const map = [1, 2, 5, 3, 4]; // Atq, Def, Vel, AtqEsp, DefEsp -> índice API
    return (map[up], map[down]);
  }
}

/// Listas de objetos por bolsillo y equipables por juego.
abstract final class ItemTables {
  static final Map<String, Map<String, List<int>>> _cache = {};

  static String? keyFor(GameVersion game) => switch (game) {
        GameVersion.redBlue || GameVersion.yellow => 'g1',
        GameVersion.goldSilver => 'gs',
        GameVersion.crystal => 'c',
        GameVersion.rubySapphire => 'rs',
        GameVersion.emerald => 'e',
        GameVersion.fireRedLeafGreen => 'frlg',
        GameVersion.colosseum || GameVersion.xd => 'rs',
        GameVersion.diamondPearl => 'dp',
        GameVersion.platinum => 'pt',
        GameVersion.heartGoldSoulSilver => 'hgss',
        GameVersion.blackWhite => 'bw',
        GameVersion.black2White2 => 'b2w2',
        GameVersion.xy => 'xy',
        GameVersion.omegaRubyAlphaSapphire => 'ao',
        GameVersion.sunMoon => 'sm',
        GameVersion.ultraSunUltraMoon => 'usum',
        GameVersion.letsGo => 'lgpe',
        GameVersion.swordShield => 'swsh',
        GameVersion.brilliantDiamondShiningPearl => 'bdsp',
        GameVersion.scarletViolet => 'sv',
        GameVersion.legendsArceus => 'la',
        GameVersion.legendsZA => 'za',
      };

  static Map<String, List<int>>? _game(GameVersion game) {
    final key = keyFor(game);
    if (key == null) return null;
    return _cache.putIfAbsent(key, () {
      final raw = kItemTables[key]!;
      return {
        for (final MapEntry(:key, :value) in raw.entries)
          key: () {
            final b = base64Decode(value);
            return [
              for (var i = 0; i + 1 < b.length; i += 2)
                if ((b[i] | (b[i + 1] << 8)) != 0) b[i] | (b[i + 1] << 8),
            ];
          }(),
      };
    });
  }

  /// Objetos válidos para un bolsillo ([pouch] = nombre de `InventoryType` de PKHeX).
  static List<int> pouch(GameVersion game, String pouch) => _game(game)?[pouch] ?? const [];

  /// Objetos que pueden equiparse en el juego (vacío = sin datos).
  static Set<int> held(GameVersion game) => (_game(game)?['held'] ?? const <int>[]).toSet();

  /// Todos los objetos conocidos del juego (unión de bolsillos).
  static Set<int> all(GameVersion game) => {
        for (final MapEntry(:key, :value) in (_game(game) ?? const <String, List<int>>{}).entries)
          if (key != 'held') ...value,
      };
}
