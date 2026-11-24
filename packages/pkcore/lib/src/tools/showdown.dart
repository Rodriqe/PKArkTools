import 'dart:math';

import '../data/forms.dart';
import '../data/game_data.dart';
import '../data/species.dart';
import '../edit/save_editor.dart';
import '../legal/legality.dart';
import '../model/game.dart';
import '../pkm/pkm.dart';
import '../pkm/pkm_factory.dart';
import 'stat_calc.dart';

/// Un Pokémon descrito en texto de Pokémon Showdown (lo que se lee, sin
/// resolver todavía contra un juego concreto).
class ShowdownSet {
  ShowdownSet({
    required this.speciesText,
    this.nickname,
    this.gender,
    this.item,
    this.ability,
    this.level,
    this.shiny = false,
    this.teraType,
    this.nature,
    this.happiness,
    this.gigantamax = false,
    this.ball,
    this.hiddenPowerType,
    Map<int, int>? evs,
    Map<int, int>? ivs,
    List<String>? moves,
  }) : evs = evs ?? {},
       ivs = ivs ?? {},
       moves = moves ?? [];

  /// Especie con forma tal como se escribió («Rotom-Wash», «Tauros-Paldea-Blaze»).
  final String speciesText;
  final String? nickname;

  /// 'M' o 'F' (null = sin indicar).
  final String? gender;
  final String? item;
  final String? ability;
  final int? level;
  final bool shiny;
  final String? teraType;
  final String? nature;
  final int? happiness;
  final bool gigantamax;
  final String? ball;

  /// Tipo pedido con «Hidden Power: X» o «- Hidden Power [X]».
  final String? hiddenPowerType;

  /// EVs/IVs indicados (índice API → valor). Los demás toman el valor por defecto.
  final Map<int, int> evs;
  final Map<int, int> ivs;
  final List<String> moves;
}

/// Aviso al convertir un set de Showdown en un Pokémon de un juego.
class ShowdownWarning {
  const ShowdownWarning(this.code, [this.value = '']);

  final ShowdownWarningCode code;

  /// Texto que lo provocó (nombre de objeto, movimiento…).
  final String value;

  String message({required bool es}) => switch (code) {
    ShowdownWarningCode.unknownSpecies => es ? 'Especie desconocida: «$value».' : 'Unknown species: “$value”.',
    ShowdownWarningCode.speciesNotInGame =>
      es ? '$value no existe en este juego.' : '$value is not available in this game.',
    ShowdownWarningCode.unknownForm =>
      es ? 'Forma desconocida «$value»: se usa la forma normal.' : 'Unknown form “$value”: using the default form.',
    ShowdownWarningCode.unknownItem => es ? 'Objeto desconocido: «$value».' : 'Unknown item: “$value”.',
    ShowdownWarningCode.itemNotInGame =>
      es ? '$value no se puede llevar en este juego.' : '$value cannot be held in this game.',
    ShowdownWarningCode.unknownAbility => es ? 'Habilidad desconocida: «$value».' : 'Unknown ability: “$value”.',
    ShowdownWarningCode.abilityNotAvailable =>
      es
          ? '$value no es una habilidad de esta especie: se deja la primera.'
          : '$value is not an ability of this species: keeping the first one.',
    ShowdownWarningCode.unknownNature => es ? 'Naturaleza desconocida: «$value».' : 'Unknown nature: “$value”.',
    ShowdownWarningCode.unknownMove => es ? 'Movimiento desconocido: «$value».' : 'Unknown move: “$value”.',
    ShowdownWarningCode.moveNotInGame => es ? '$value no existe en este juego.' : '$value does not exist in this game.',
    ShowdownWarningCode.moveNotLearnable =>
      es ? 'La especie no puede aprender $value en este juego.' : 'The species cannot learn $value in this game.',
    ShowdownWarningCode.tooManyMoves =>
      es ? 'Más de 4 movimientos: se ignoran los sobrantes.' : 'More than 4 moves: extra ones are ignored.',
    ShowdownWarningCode.unknownTeraType => es ? 'Teratipo desconocido: «$value».' : 'Unknown Tera Type: “$value”.',
    ShowdownWarningCode.featureNotInGame =>
      es ? '$value no existe en este juego: se ignora.' : '$value does not exist in this game: ignored.',
    ShowdownWarningCode.evTotal =>
      es
          ? 'Los EVs suman $value (máximo 510): el juego no lo permite.'
          : 'EVs add up to $value (max 510): not allowed by the game.',
    ShowdownWarningCode.legality => value,
  };
}

enum ShowdownWarningCode {
  unknownSpecies,
  speciesNotInGame,
  unknownForm,
  unknownItem,
  itemNotInGame,
  unknownAbility,
  abilityNotAvailable,
  unknownNature,
  unknownMove,
  moveNotInGame,
  moveNotLearnable,
  tooManyMoves,
  unknownTeraType,
  featureNotInGame,
  evTotal,

  /// Aviso del comprobador de legalidad ([Legality.check]) ya traducido.
  legality,
}

/// Resultado de convertir un set: el Pokémon (null si la especie no se pudo
/// resolver) y los avisos.
class ShowdownImport {
  const ShowdownImport(this.set, this.pkm, this.warnings);
  final ShowdownSet set;
  final Pkm? pkm;
  final List<ShowdownWarning> warnings;

  bool get ok => pkm != null;
}

/// Importar y exportar el formato de texto de Pokémon Showdown
/// (`Apodo (Especie) (M) @ Objeto`, `Ability:`, `EVs:`, `- Movimiento`…).
///
/// Los nombres van siempre en inglés, como en Showdown.
abstract final class Showdown {
  static const _statKeys = ['hp', 'atk', 'def', 'spa', 'spd', 'spe'];
  static const _statLabels = ['HP', 'Atk', 'Def', 'SpA', 'SpD', 'Spe'];

  /// Normaliza un nombre para compararlo: minúsculas, sin acentos ni signos.
  static String norm(String s) {
    const accents = {'é': 'e', 'è': 'e', 'á': 'a', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ñ': 'n', 'ü': 'u'};
    final b = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      final c = String.fromCharCode(r);
      final a = accents[c] ?? c;
      if (RegExp(r'[a-z0-9]').hasMatch(a)) b.write(a);
    }
    return b.toString();
  }

  // ------------------------------------------------------------ lectura

  /// Lee uno o varios sets separados por líneas en blanco. Ignora las
  /// cabeceras de equipo (`=== [gen9vgc2024regg] Equipo ===`).
  static List<ShowdownSet> parse(String text) {
    final blocks = <List<String>>[];
    var cur = <String>[];
    for (final raw in text.replaceAll('\r', '').split('\n')) {
      final line = raw.trim();
      if (line.startsWith('===')) {
        if (cur.isNotEmpty) blocks.add(cur);
        cur = [];
        continue;
      }
      if (line.isEmpty) {
        if (cur.isNotEmpty) blocks.add(cur);
        cur = [];
        continue;
      }
      cur.add(line);
    }
    if (cur.isNotEmpty) blocks.add(cur);
    return [for (final b in blocks) ?_parseBlock(b)];
  }

  static ShowdownSet? _parseBlock(List<String> lines) {
    var head = lines.first;
    String? item;
    final at = head.lastIndexOf(' @ ');
    if (at >= 0) {
      item = head.substring(at + 3).trim();
      head = head.substring(0, at).trim();
    } else if (head.endsWith('@')) {
      head = head.substring(0, head.length - 1).trim();
    }
    String? gender;
    final g = RegExp(r'\s*\((M|F)\)$').firstMatch(head);
    if (g != null) {
      gender = g.group(1);
      head = head.substring(0, g.start).trim();
    }
    String? nickname;
    var species = head;
    final paren = RegExp(r'^(.*\S)\s*\(([^()]+)\)$').firstMatch(head);
    if (paren != null) {
      nickname = paren.group(1)!.trim();
      species = paren.group(2)!.trim();
    }
    if (species.isEmpty) return null;

    String? ability, tera, nature, ball, hpType;
    int? level, happiness;
    var shiny = false, gmax = false;
    final evs = <int, int>{}, ivs = <int, int>{};
    final moves = <String>[];

    Map<int, int> spread(String s) {
      final out = <int, int>{};
      for (final part in s.split('/')) {
        final m = RegExp(r'^\s*(\d+)\s+([A-Za-z]+)\s*$').firstMatch(part);
        if (m == null) continue;
        final idx = _statKeys.indexOf(m.group(2)!.toLowerCase());
        if (idx >= 0) out[idx] = int.parse(m.group(1)!);
      }
      return out;
    }

    for (final line in lines.skip(1)) {
      if (line.startsWith('-') || line.startsWith('~')) {
        var mv = line.substring(1).trim();
        final hp = RegExp(r'^Hidden Power\s*\[?\s*([A-Za-z]+)\s*\]?$', caseSensitive: false).firstMatch(mv);
        if (hp != null) {
          hpType = hp.group(1);
          mv = 'Hidden Power';
        }
        // «Move / Alternative»: solo la primera opción.
        mv = mv.split(' / ').first.trim();
        if (mv.isNotEmpty) moves.add(mv);
        continue;
      }
      final natureM = RegExp(r'^([A-Za-z]+)\s+Nature$').firstMatch(line);
      if (natureM != null) {
        nature = natureM.group(1);
        continue;
      }
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      final key = line.substring(0, colon).trim().toLowerCase();
      final value = line.substring(colon + 1).trim();
      switch (key) {
        case 'ability':
          ability = value;
        case 'level':
          level = int.tryParse(value);
        case 'shiny':
          shiny = value.toLowerCase() == 'yes';
        case 'tera type':
          tera = value;
        case 'happiness' || 'friendship':
          happiness = int.tryParse(value);
        case 'gigantamax':
          gmax = value.toLowerCase() == 'yes';
        case 'pokeball' || 'ball':
          ball = value;
        case 'hidden power':
          hpType = value;
        case 'evs':
          evs.addAll(spread(value));
        case 'ivs':
          ivs.addAll(spread(value));
      }
    }
    if (species.toLowerCase().endsWith('-gmax')) {
      gmax = true;
      species = species.substring(0, species.length - 5);
    }
    return ShowdownSet(
      speciesText: species,
      nickname: nickname,
      gender: gender,
      item: item,
      ability: ability,
      level: level,
      shiny: shiny,
      teraType: tera,
      nature: nature,
      happiness: happiness,
      gigantamax: gmax,
      ball: ball,
      hiddenPowerType: hpType,
      evs: evs,
      ivs: ivs,
      moves: moves,
    );
  }

  // ------------------------------------------------------------ nombres

  static final Map<String, int> _speciesByName = () {
    final m = <String, int>{};
    for (var s = 1; s <= Species.max; s++) {
      final n = norm(Species.name(s, SpeciesLanguage.en));
      if (n.isNotEmpty) m.putIfAbsent(n, () => s);
    }
    // Nidoran♀/♂ se normalizan igual: Showdown los escribe con -F/-M.
    m.remove('nidoran');
    m['nidoranf'] = 29;
    m['nidoranm'] = 32;
    return m;
  }();

  static final Map<String, int> _naturesByName = {
    for (var i = 0; i < 25; i++) norm(GameStrings.nature(i, DataLanguage.en)): i,
  };

  static Map<String, int> _index(List<String> names) {
    final m = <String, int>{};
    for (var i = 1; i < names.length; i++) {
      final n = norm(names[i]);
      if (n.isNotEmpty) m.putIfAbsent(n, () => i);
    }
    return m;
  }

  static final Map<String, int> _moves = _index(GameStrings.moveList(DataLanguage.en));
  static final Map<String, int> _abilities = _index(GameStrings.abilityList(DataLanguage.en));
  static final Map<int, Map<String, int>> _items = {};
  static Map<String, int> _itemsFor(int generation) =>
      _items.putIfAbsent(generation, () => _index(GameStrings.itemList(generation, DataLanguage.en)));

  /// Id de tipo de PKHeX (0 = Normal … 17 = Hada, 99 = Astral) o null.
  static int? typeId(String name) {
    final n = norm(name);
    if (n == 'stellar') return 99;
    final list = GameStrings.typeList(DataLanguage.en);
    for (var i = 0; i < 18 && i < list.length; i++) {
      if (norm(list[i]) == n) return i;
    }
    return null;
  }

  static int? moveId(String name) => _moves[norm(name)];
  static int? abilityId(String name) => _abilities[norm(name)];
  static int? natureId(String name) => _naturesByName[norm(name)];
  static int? itemId(String name, int generation) => _itemsFor(generation)[norm(name)];

  /// Especie y forma de un nombre de Showdown («Rotom-Wash» → (479, 2)).
  /// `formFound` es `false` si había un sufijo de forma que no se reconoció.
  static ({int species, int form, bool formFound, bool female})? resolveSpecies(String text, GameVersion game) {
    final full = norm(text);
    final direct = _speciesByName[full];
    if (direct != null) return (species: direct, form: 0, formFound: true, female: false);
    final parts = text.split('-');
    for (var k = parts.length - 1; k >= 1; k--) {
      final sp = _speciesByName[norm(parts.sublist(0, k).join('-'))];
      if (sp == null) continue;
      final suffix = parts.sublist(k).join('-');
      final r = _resolveForm(sp, suffix, game);
      return (species: sp, form: r?.$1 ?? 0, formFound: r != null, female: r?.$2 ?? false);
    }
    return null;
  }

  /// Forma de [species] cuyo nombre encaja con [suffix]. El segundo valor es
  /// `true` si el sufijo es «-F» en una especie sin formas por género.
  static (int, bool)? _resolveForm(int species, String suffix, GameVersion game) {
    final s = norm(suffix);
    var names = SpeciesForms.formNames(species, game, DataLanguage.en);
    if (names.isEmpty) {
      final g = SpeciesForms.resolveGame(species, 1, game);
      if (g != null) names = SpeciesForms.formNames(species, g, DataLanguage.en);
    }
    if (s == 'f' || s == 'm') {
      final fi = names.indexWhere((n) => n == (s == 'f' ? '♀' : '♂'));
      if (fi >= 0) return (fi, false);
      return (0, s == 'f');
    }
    final normNames = [for (final n in names) norm(n.replaceAll('*', ''))];
    for (var i = 0; i < normNames.length; i++) {
      if (normNames[i] == s && !names[i].startsWith('*')) return (i, false);
    }
    // «Necrozma-Dusk-Mane» → «Dusk»; «Basculin-Blue-Striped» → «Blue».
    var best = -1;
    for (var i = 0; i < normNames.length; i++) {
      final n = normNames[i];
      if (n.isEmpty || names[i].startsWith('*')) continue;
      if (s.startsWith(n) && (best < 0 || n.length > normNames[best].length)) best = i;
    }
    if (best >= 0) return (best, false);
    // «Maushold-Four» → «Family of Four»; «Ogerpon-Wellspring-Tera» → «*Wellspring».
    for (var i = 0; i < normNames.length; i++) {
      final n = normNames[i];
      if (n.isNotEmpty && (n.contains(s) || s.startsWith(n))) {
        if (s.endsWith('tera')) {
          final tera = names.indexWhere((x) => x.startsWith('*') && norm(x) == n);
          if (tera >= 0) return (tera, false);
        }
        return (i, false);
      }
    }
    return null;
  }

  /// Nombre de Showdown de especie + forma («Rotom-Wash», «Nidoran-F»).
  static String speciesName(int species, int form, GameVersion? game, {bool gigantamax = false}) {
    var name = switch (species) {
      29 => 'Nidoran-F',
      32 => 'Nidoran-M',
      _ => Species.name(species, SpeciesLanguage.en),
    };
    if (form > 0) {
      final names = game == null ? const <String>[] : SpeciesForms.formNames(species, game, DataLanguage.en);
      var f = form < names.length ? names[form] : SpeciesForms.formName(species, form, game, DataLanguage.en);
      final tera = f.startsWith('*');
      f = f.replaceAll('*', '').replaceAll('♀', 'F').replaceAll('♂', 'M').replaceAll('’', "'");
      f = f.replaceAll(RegExp(r'\s+Form$'), '').trim().replaceAll(RegExp(r'\s+'), '-');
      if (f.isNotEmpty) name = '$name-$f${tera ? '-Tera' : ''}';
    }
    if (gigantamax) name = '$name-Gmax';
    return name;
  }

  // ------------------------------------------------------------ conversión

  /// Crea el Pokémon de [set] para [game] con el entrenador [trainer].
  ///
  /// Nunca lanza: lo que no se puede aplicar se convierte en avisos, y al
  /// final se añaden los avisos graves de [Legality.check].
  static ShowdownImport toPkm(
    ShowdownSet set,
    GameVersion game,
    TrainerData trainer, {
    int? versionId,
    Random? random,
    DataLanguage lang = DataLanguage.es,
  }) {
    final warnings = <ShowdownWarning>[];
    final es = lang == DataLanguage.es;
    final resolved = resolveSpecies(set.speciesText, game);
    if (resolved == null) {
      return ShowdownImport(set, null, [ShowdownWarning(ShowdownWarningCode.unknownSpecies, set.speciesText)]);
    }
    final gen = game.generation;
    final table = GameDataTable.forGame(game);
    final species = resolved.species;
    final form = resolved.form;
    if (!resolved.formFound) {
      warnings.add(ShowdownWarning(ShowdownWarningCode.unknownForm, set.speciesText));
    }
    final personal = table.entry(species, form);
    if (!_speciesInGame(species, form, game)) {
      warnings.add(ShowdownWarning(ShowdownWarningCode.speciesNotInGame, speciesName(species, form, game)));
      if (personal == null || personal.baseStatTotal == 0) {
        return ShowdownImport(set, null, warnings);
      }
    }
    final level = (set.level ?? 100).clamp(1, 100);
    final pk = PkmFactory.create(
      game,
      trainer,
      species: species,
      form: form,
      level: level,
      versionId: versionId,
      random: random,
    );
    final f = pk.format;

    // Habilidad.
    if (set.ability != null && gen >= 3) {
      final id = abilityId(set.ability!);
      final list = personal?.abilities ?? const <int>[];
      if (id == null) {
        warnings.add(ShowdownWarning(ShowdownWarningCode.unknownAbility, set.ability!));
      } else {
        final slot = list.indexOf(id);
        if (slot < 0 || (slot == 2 && gen < 5)) {
          warnings.add(ShowdownWarning(ShowdownWarningCode.abilityNotAvailable, GameStrings.ability(id, lang)));
        } else {
          pk.setAbilitySlot(slot);
          // Gen 3–5: la ranura sale de un bit del PID; la naturaleza, el
          // género y el variocolor regeneran el PID conservando ese bit.
          if (gen <= 4 && slot < 2 && (pk.pid & 1) != slot) pk.pid = pk.pid ^ 1;
          if (gen == 5 && slot < 2 && (pk.pid >> 16 & 1) != slot) pk.pid = pk.pid ^ 0x10000;
        }
      }
    }

    // Naturaleza (Showdown usa Serious si no se indica).
    if (gen >= 3) {
      var nature = 12;
      if (set.nature != null) {
        final n = natureId(set.nature!);
        if (n == null) {
          warnings.add(ShowdownWarning(ShowdownWarningCode.unknownNature, set.nature!));
        } else {
          nature = n;
        }
      }
      pk.nature = nature;
      if (f.hasStatNature) pk.statNature = nature;
    } else if (set.nature != null) {
      warnings.add(ShowdownWarning(ShowdownWarningCode.featureNotInGame, es ? 'La naturaleza' : 'Nature'));
    }

    // Género.
    final wantFemale = set.gender == 'F' || resolved.female;
    if (set.gender != null || resolved.female) {
      final ratio = personal?.genderRatio ?? 255;
      if (ratio != 255 && ratio != 254 && ratio != 0 && gen >= 2) pk.gender = wantFemale ? 1 : 0;
    }

    // IVs (31 por defecto; en Gen 1/2 Showdown escribe IV = 2·DV).
    final gb = f.isGameBoy;
    var ivs = [for (var i = 0; i < 6; i++) set.ivs[i] ?? 31];
    if (gb) ivs = [for (final v in ivs) (v ~/ 2).clamp(0, 15)];
    if (set.hiddenPowerType != null && gen >= 3 && set.ivs.isEmpty) {
      final t = typeId(set.hiddenPowerType!);
      if (t != null && t >= 1 && t <= 16) ivs = HiddenPower.ivsFor(t, ivs);
    }
    pk.setIvs([for (final v in ivs) v.clamp(0, f.maxIv)]);

    // EVs (0 por defecto; en Gen 1/2 la experiencia de stat va al máximo).
    if (gb) {
      pk.setEvs([
        for (var i = 0; i < 6; i++) set.evs.containsKey(i) ? (set.evs[i]! * 65535 ~/ 252).clamp(0, 65535) : 65535,
      ]);
    } else if (!f.hasAwakeningValues && !f.hasGanbaruValues) {
      final maxEv = gen >= 6 ? 252 : 255;
      final evs = [for (var i = 0; i < 6; i++) (set.evs[i] ?? 0).clamp(0, maxEv)];
      final total = evs.fold(0, (a, b) => a + b);
      if (total > 510) warnings.add(ShowdownWarning(ShowdownWarningCode.evTotal, '$total'));
      pk.setEvs(evs);
    } else if (set.evs.isNotEmpty) {
      warnings.add(const ShowdownWarning(ShowdownWarningCode.featureNotInGame, 'EVs'));
    }

    // Objeto.
    if (set.item != null && set.item!.isNotEmpty) {
      if (gen == 1) {
        warnings.add(
          ShowdownWarning(ShowdownWarningCode.featureNotInGame, es ? 'Los objetos equipados' : 'Held items'),
        );
      } else {
        final id = itemId(set.item!, gen);
        if (id == null) {
          warnings.add(ShowdownWarning(ShowdownWarningCode.unknownItem, set.item!));
        } else {
          final held = ItemTables.held(game);
          if (held.isNotEmpty && !held.contains(id)) {
            warnings.add(ShowdownWarning(ShowdownWarningCode.itemNotInGame, GameStrings.itemFor(id, game, lang)));
          } else {
            pk.heldItem = id;
          }
        }
      }
    }

    // Movimientos.
    final learnable = <int>{
      for (final (sp, fo) in SpeciesForms.evolutionChain(species, form, game)) ...table.learnableMoves(sp, fo),
      ...?_formMoves[species * 100 + form],
    };
    final ids = <int>[];
    for (final m in set.moves) {
      if (ids.length == 4) {
        warnings.add(const ShowdownWarning(ShowdownWarningCode.tooManyMoves));
        break;
      }
      final id = moveId(m);
      if (id == null) {
        warnings.add(ShowdownWarning(ShowdownWarningCode.unknownMove, m));
        continue;
      }
      if (!MoveData.existsIn(id, table.context)) {
        warnings.add(ShowdownWarning(ShowdownWarningCode.moveNotInGame, GameStrings.move(id, lang)));
        continue;
      }
      // Aviso suave: [Legality.check] decide si es imposible; aquí se avisa
      // si ni la especie ni sus preevoluciones lo aprenden por nivel, MT o
      // huevo en este juego (p. ej. un movimiento huevo en uno salvaje).
      if (!learnable.contains(id)) {
        warnings.add(ShowdownWarning(ShowdownWarningCode.moveNotLearnable, GameStrings.move(id, lang)));
      }
      if (!ids.contains(id)) ids.add(id);
    }
    if (ids.isNotEmpty) {
      for (var i = 0; i < 4; i++) {
        pk.setMove(i, i < ids.length ? ids[i] : 0, context: table.context);
      }
    }

    // Teratipo.
    if (set.teraType != null) {
      if (!f.hasTeraType) {
        warnings.add(ShowdownWarning(ShowdownWarningCode.featureNotInGame, es ? 'El teratipo' : 'Tera Type'));
      } else {
        final t = typeId(set.teraType!);
        if (t == null) {
          warnings.add(ShowdownWarning(ShowdownWarningCode.unknownTeraType, set.teraType!));
        } else {
          pk.teraTypeOriginal = t;
          pk.teraType = t;
        }
      }
    }

    if (set.gigantamax) {
      if (game == GameVersion.swordShield) {
        pk.canGigantamax = true;
      } else {
        warnings.add(ShowdownWarning(ShowdownWarningCode.featureNotInGame, es ? 'El Gigamax' : 'Gigantamax'));
      }
    }
    if (set.happiness != null) pk.friendship = set.happiness!.clamp(0, 255);
    if (set.nickname != null &&
        set.nickname!.isNotEmpty &&
        Showdown.norm(set.nickname!) != norm(Species.name(species, SpeciesLanguage.en))) {
      final max = gen >= 6 ? 12 : (gen <= 2 ? 10 : 10);
      final runes = set.nickname!.runes.toList();
      pk.setNickname(String.fromCharCodes(runes.take(max)));
    }
    if (set.shiny) pk.setShiny(true, random: random);

    pk.refreshPartyStats();
    pk.refreshChecksum();

    // Datos de origen (lugar y nivel de encuentro, fechas…): el texto de
    // Showdown no los trae, así que se aplican las correcciones seguras del
    // comprobador. Nunca se tocan las que cambiarían lo que pide el texto
    // (variocolor, habilidad, movimientos).
    var fixed = pk;
    for (var round = 0; round < 3; round++) {
      final pending = [
        for (final i in Legality.check(fixed, game))
          if (i.fix != null &&
              (i.area == LegalityArea.origin || i.area == LegalityArea.encounter) &&
              i.code != LegalityCode.shinyLocked &&
              i.code != LegalityCode.hiddenAbilityOldOrigin)
            i,
      ];
      if (pending.isEmpty) break;
      for (final i in pending) {
        fixed = Legality.applyFix(fixed, i, game) ?? fixed;
      }
    }
    fixed
      ..dataGame = game
      ..refreshPartyStats()
      ..refreshChecksum();

    for (final issue in Legality.check(fixed, game, lang: lang)) {
      if (issue.severity != LegalitySeverity.warning) continue;
      warnings.add(ShowdownWarning(ShowdownWarningCode.legality, issue.message(lang)));
    }
    return ShowdownImport(set, fixed, warnings);
  }

  /// Movimientos que da el cambio de forma (Rotom).
  static const _formMoves = {
    47901: {315}, // Calor: Sofoco
    47902: {56}, // Lavado: Hidrobomba
    47903: {59}, // Frío: Ventisca
    47904: {403}, // Ventilador: Tajo Aéreo
    47905: {437}, // Corte: Lluevehojas
  };

  static bool _speciesInGame(int species, int form, GameVersion game) {
    final p = GameDataTable.forGame(game).entry(species, form);
    if (p == null || p.baseStatTotal == 0) return false;
    return SpeciesForms.isPresent(species, form, game);
  }

  // ------------------------------------------------------------ escritura

  /// Texto de Showdown de un Pokémon.
  static String export(Pkm pk, GameVersion game) {
    final gen = pk.generation;
    final b = StringBuffer();
    final gmax = pk.canGigantamax;
    final species = speciesName(pk.species, pk.form, game, gigantamax: gmax);
    final nick = pk.isNicknamed ? pk.nickname : null;
    b.write(nick != null ? '$nick ($species)' : species);
    final ratio = GameDataTable.forGame(game).entry(pk.species, pk.form)?.genderRatio ?? 255;
    final g = pk.gender;
    if (ratio != 255 && ratio != 254 && ratio != 0 && gen >= 2) b.write(g == 1 ? ' (F)' : (g == 0 ? ' (M)' : ''));
    if (pk.heldItem > 0) b.write(' @ ${GameStrings.itemFor(pk.heldItem, game, DataLanguage.en)}');
    b.writeln();
    if (gen >= 3 && pk.ability > 0) b.writeln('Ability: ${GameStrings.ability(pk.ability, DataLanguage.en)}');
    if (pk.level != 100) b.writeln('Level: ${pk.level}');
    if (pk.isShiny) b.writeln('Shiny: Yes');
    if (pk.format.hasTeraType) {
      final t = pk.teraType;
      b.writeln('Tera Type: ${t == 99 ? 'Stellar' : GameStrings.type(t, DataLanguage.en)}');
    }
    if (pk.friendship != 255 && gen >= 2) b.writeln('Happiness: ${pk.friendship}');
    final gb = pk.format.isGameBoy;
    if (!pk.format.hasAwakeningValues && !pk.format.hasGanbaruValues) {
      final evs = gb ? [for (final e in pk.evs) (e * 252 / 65535).round()] : pk.evs;
      final evParts = [
        for (var i = 0; i < 6; i++)
          if (evs[i] > 0 && !(gb && i == 4)) '${evs[i]} ${_statLabels[i]}',
      ];
      if (evParts.isNotEmpty) b.writeln('EVs: ${evParts.join(' / ')}');
    }
    if (gen >= 3) b.writeln('${GameStrings.nature(pk.statNature, DataLanguage.en)} Nature');
    final ivs = gb ? [for (final d in pk.ivs) d * 2] : pk.ivs;
    final max = gb ? 30 : 31;
    final ivParts = [
      for (var i = 0; i < 6; i++)
        // Gen 1/2: los PS salen de los demás DVs y Especial es uno solo.
        if (ivs[i] != max && !(gb && (i == 0 || i == 4))) '${ivs[i]} ${_statLabels[i]}',
    ];
    if (ivParts.isNotEmpty) b.writeln('IVs: ${ivParts.join(' / ')}');
    for (final m in pk.moves) {
      if (m == 0) continue;
      var name = GameStrings.move(m, DataLanguage.en);
      if (m == 237 && HiddenPower.appliesTo(gen)) {
        name = '$name [${GameStrings.type(HiddenPower.type(pk.ivs, generation: gen), DataLanguage.en)}]';
      }
      b.writeln('- $name');
    }
    return b.toString().trimRight();
  }

  /// Varios Pokémon separados por una línea en blanco.
  static String exportTeam(Iterable<Pkm> team, GameVersion game) =>
      [for (final pk in team) export(pk, game)].join('\n\n');
}
