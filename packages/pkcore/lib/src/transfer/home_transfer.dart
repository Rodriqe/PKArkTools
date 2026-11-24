import 'dart:math';
import 'dart:typed_data';

import '../data/forms.dart';
import '../data/game_data.dart';
import '../data/generated/transfer_data.dart';
import '../data/species.dart';
import '../legal/origin.dart';
import '../legal/plus_moves.dart';
import '../legal/ribbons.dart';
import '../model/game.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import '../util/bytes.dart';
import 'transfer_fields.dart';

/// Datos de juego que HOME guarda aparte para cada formato (PKHeX
/// `GameDataPK8`, `GameDataPB8`…): movimientos, Ball y lugares.
class _Side {
  _Side(this.kind);
  final PkFormat kind;
  List<int> moves = [0, 0, 0, 0];
  List<int> relearn = [0, 0, 0, 0];
  List<int> pp = [0, 0, 0, 0];
  List<int> ppUps = [0, 0, 0, 0];
  int ball = 4, metLocation = 0, eggLocation = 0, abilityNumber = 1, pokerus = 0;
  int? scale;
}

/// Conversión entre formatos de Switch (y desde PK7) a través de Pokémon HOME.
///
/// Portado de PKHeX.Core `PKH`, `GameDataCore` y `GameData*` (GPL-3.0). Se
/// copian los datos comunes (núcleo de HOME) y, si el juego de destino no es
/// el de origen, HOME crea sus datos de juego a partir del más cercano:
/// Ball y lugares se conservan, la habilidad sigue la ranura y los
/// movimientos se reinician a los del nivel en ese juego.
abstract final class HomeTransfer {
  static Pkm convert(Pkm src, PkFormat dest, Random rnd, DateTime today) {
    final side = _readSide(src);
    final species = src.species;
    var form = src.form;
    if (species == 493 || species == 773) form = 0; // HOME guarda Arceus/Silvally en su forma base

    final d = Pkm.fromDecrypted(dest, Uint8List(dest.partySize))..dataGame = _gameOf(dest);
    // --- núcleo
    d.encryptionConstant = src.encryptionConstant;
    d.pid = src.pid;
    d.data.setU16le(0x08, 0); // la especie se escribe con su codificación (PK9/PA9 usan otra numeración)
    _setSpecies(d, species);
    d.form = form;
    d.tid = src.tid;
    d.sid = src.sid;
    d.exp = src.exp;
    var marking = src.g6.markingWide ? src.markingValue : 0;
    if (src.format == PkFormat.pk7) marking &= 0xFFF;
    d.markingValue = marking;
    d.data[0x20] = src.nature;
    d.data[0x21] = src.statNature;
    d.fatefulEncounter = src.fatefulEncounter;
    d.iv32Raw = src.iv32Raw & 0x3FFFFFFF;
    d.nicknamedFlag = src.isNicknamed;
    d.setEvs(src.evs);
    _setGender(d, src.gender);
    d.htGender = src.htGender;
    d.currentHandler = src.currentHandler;
    d.htFriendship = src.htFriendship;
    d.version = src.version;
    var language = src.language;
    d.otFriendship = src.otFriendship;
    d.eggDate = src.eggDate;
    d.metDate = src.metDate;
    d.metLevel = src.metLevel;
    d.otGender = src.otGender;
    d.heightScalar = src.heightScalar;
    d.weightScalar = src.weightScalar;
    d.otMemory = src.otMemory;
    d.htMemory = src.htMemory;
    d.htLanguage = src.htLanguage;
    if (src.format == PkFormat.pb7 && d.htLanguage == 0 && src.htName.isNotEmpty) d.htLanguage = src.language;
    d.contestStats = src.contestStats;
    d.hyperTrainFlags = src.hyperTrainFlags;
    d.formArgument = src.formArgument;
    d.battleVersion = src.battleVersion;
    d.otName = src.otName;
    d.htName = src.htName;
    if (src.format == PkFormat.pk7 && !src.isNicknamed) {
      d.setNicknameRaw(TransferNames.home(species, language));
    } else {
      d.setNicknameRaw(src.nickname);
    }
    for (final r in Ribbons.forFormat(src.format)) {
      final v = Ribbons.get(src, r.key);
      if (v != 0) Ribbons.set(d, r.key, v);
    }
    Ribbons.setAffixed(d, Ribbons.affixed(src));
    // HOME: una etiqueta de alfa (Leyendas Arceus) fija la escala al máximo.
    final alpha = (src.format == PkFormat.pa8 && (src.data[0x16] & 0x20) != 0) || src.isAlpha;
    if (src.format == PkFormat.pa8 && alpha) Ribbons.set(d, 'RibbonMarkAlpha', 1);
    if (src.format == PkFormat.pk9 || src.format == PkFormat.pa9 || src.format == PkFormat.pa8) {
      d.heightScalar = side.scale!;
    }
    if (Ribbons.get(src, 'RibbonMarkAlpha') != 0 || (src.format == PkFormat.pa8 && alpha)) {
      d.heightScalar = 255;
      d.weightScalar = 255;
      if (side.scale != null) side.scale = 255;
    } else if (side.scale == null) {
      while (d.heightScalar == 0 && d.weightScalar == 0) {
        d.heightScalar = rnd.nextInt(0x81) + rnd.nextInt(0x80);
        d.weightScalar = rnd.nextInt(0x81) + rnd.nextInt(0x80);
      }
    }
    // Rastreador de HOME: lo asigna HOME la primera vez y se conserva después.
    final tracker = src.format.generation >= 8 ? src.tracker : 0;
    d.tracker = tracker != 0 ? tracker : _newTracker(rnd);
    // Español de Latinoamérica (Z-A) se guarda como español en los demás juegos.
    if (language == 11 && dest != PkFormat.pa9) language = 7;
    d.language = language;

    // --- datos del juego de destino
    final game = _gameOf(dest);
    final table = GameDataTable.forGame(game);
    final level = Species.levelFromExp(species, d.exp);
    final sameSide = side.kind == dest || (dest == PkFormat.pk8 && side.kind == PkFormat.pb7);
    var ball = side.ball;
    if (dest == PkFormat.pa8 && d.version == 47 && !(ball >= 28 && ball <= 37)) ball = 28;
    d.ball = ball;
    d.metLocation = side.metLocation;
    d.eggLocation = side.eggLocation;
    d.pokerus = side.pokerus;
    if (sameSide) {
      for (var i = 0; i < 4; i++) {
        d.setMove(i, side.moves[i], refillPp: false);
        d.setPp(i, side.pp[i]);
        d.setPpUps(i, side.ppUps[i]);
        d.setRelearnMove(i, side.relearn[i]);
      }
    } else {
      final moves = _encounterMoves(table, species, form, level);
      for (var i = 0; i < 4; i++) {
        d.setMove(i, moves[i], context: table.context);
        d.setPpUps(i, 0);
        d.setRelearnMove(i, 0);
      }
    }
    final p = table.entry(species, form);
    var index = side.abilityNumber >> 1;
    if (p == null || index >= p.abilities.length) index = 0;
    d.abilityNumber = side.abilityNumber == 0 ? 1 : side.abilityNumber;
    d.abilityId = p == null || p.abilities.isEmpty ? 0 : p.abilities[index];

    switch (dest) {
      case PkFormat.pk8:
        if (d.ball > 26) d.ball = 4;
        final v = d.version;
        final remap = _swshRemap[v];
        if (remap != null) {
          d.version = remap.$1;
          d.metLocation = remap.$2;
          final egg = d.eggLocation;
          d.eggLocation = egg == 0 ? 0 : (egg > 60000 ? 65534 : remap.$2);
        }
        if (src.format == PkFormat.pk8) d.canGigantamax = src.canGigantamax;
      case PkFormat.pb8:
        d.eggLocation = _local8b(d.eggLocation);
        d.metLocation = _local8b(d.metLocation);
      case PkFormat.pa8:
        d.data[0x16] = (d.data[0x16] & ~0x20) | (alpha ? 0x20 : 0);
        final sc = side.scale ?? d.heightScalar;
        d.scale = sc;
        final la = _laHeightWeight['$species,$form'];
        if (la != null) {
          final bd = ByteData.sublistView(d.data);
          bd.setFloat32(0xAC, _f32(la.$1 * _scalarPercent(d.heightScalar)), Endian.little);
          bd.setFloat32(
              0xB0, _f32(la.$2 * _f32(_scalarPercent(d.heightScalar) * _scalarPercent(d.weightScalar))), Endian.little);
        }
      case PkFormat.pk9:
        d.scale = side.scale ?? d.heightScalar;
        if (src.format != PkFormat.pk9) {
          d.data[0x11F] = d.metLevel; // obediencia
          final t = SpeciesForms.defaultTeraType(species, form, GameVersion.scarletViolet);
          d.data[0x94] = t;
          d.data[0x95] = t;
        }
      case PkFormat.pa9:
        d.scale = side.scale ?? d.heightScalar;
        if (alpha || Ribbons.get(d, 'RibbonMarkAlpha') != 0) {
          d.data[0x23] = 1;
          d.scale = 255;
          d.heightScalar = 255;
          d.weightScalar = 255;
        }
        d.data[0x11F] = d.metLevel;
        PlusMoves.sync(d);
        for (var i = 0; i < 4; i++) {
          d.setPp(i, 0); // HOME deja los PP a 0 en Z-A
        }
      default:
        break;
    }
    d.refreshPartyStats();
    d.refreshChecksum();
    return d;
  }

  static const _swshRemap = <int, (int, int)>{
    47: (44, 60000), // Leyendas Arceus
    48: (44, 59999), // Diamante Brillante
    49: (45, 59998), // Perla Reluciente
    50: (44, 59997), // Escarlata
    51: (45, 59996), // Púrpura
    56: (44, 59995), // Rojo Fuego (Switch)
    57: (45, 59994), // Verde Hoja (Switch)
  };

  static int _local8b(int loc) => switch (loc) {
        0 => 65535,
        658 => 0,
        _ => loc,
      };

  static int _mainline8b(int loc) => switch (loc) {
        0 => 658,
        65535 => 0,
        _ => loc,
      };

  static _Side _readSide(Pkm s) {
    final kind = s.format == PkFormat.pk7 ? PkFormat.pk8 : s.format;
    final side = _Side(kind)
      ..moves = s.moves
      ..relearn = s.relearnMoves
      ..pp = [for (var i = 0; i < 4; i++) s.pp(i)]
      ..ppUps = [for (var i = 0; i < 4; i++) s.ppUps(i)]
      ..ball = s.ball
      ..metLocation = s.metLocation
      ..eggLocation = s.eggLocation
      ..abilityNumber = s.abilityNumber
      ..pokerus = s.pokerus;
    if (s.format == PkFormat.pb8) {
      side.metLocation = _mainline8b(side.metLocation);
      side.eggLocation = _mainline8b(side.eggLocation);
    }
    if (s.format == PkFormat.pk9 || s.format == PkFormat.pa9 || s.format == PkFormat.pa8) side.scale = s.scale;
    if (s.format == PkFormat.pa8 && (s.data[0x16] & 0x20) != 0) side.scale = 255;
    return side;
  }

  // El setter de Pkm repone el apodo si no estaba apodado: el apodo se fija después.
  static void _setSpecies(Pkm d, int species) => d.species = species;

  static void _setGender(Pkm d, int g) {
    switch (d.format) {
      case PkFormat.pk8 || PkFormat.pb8 || PkFormat.pa8:
        d.data[0x22] = (d.data[0x22] & ~0x0C) | ((g & 3) << 2);
      default:
        d.data[0x22] = (d.data[0x22] & ~0x06) | ((g & 3) << 1);
    }
  }

  /// Últimos cuatro movimientos aprendidos por nivel hasta [level] (PKHeX `Learnset.SetEncounterMoves`).
  static List<int> _encounterMoves(GameDataTable t, int species, int form, int level) {
    final out = <int>[];
    for (final m in t.levelUpMoves(species, form)) {
      if (m.level > level) break;
      if (m.move == 0 || out.contains(m.move)) continue;
      if (out.length == 4) out.removeAt(0);
      out.add(m.move);
    }
    while (out.length < 4) {
      out.add(0);
    }
    return out;
  }

  static GameVersion _gameOf(PkFormat f) => switch (f) {
        PkFormat.pb7 => GameVersion.letsGo,
        PkFormat.pk8 => GameVersion.swordShield,
        PkFormat.pb8 => GameVersion.brilliantDiamondShiningPearl,
        PkFormat.pa8 => GameVersion.legendsArceus,
        PkFormat.pk9 => GameVersion.scarletViolet,
        PkFormat.pa9 => GameVersion.legendsZA,
        _ => GameVersion.ultraSunUltraMoon,
      };

  static int _newTracker(Random rnd) {
    var v = 0;
    while (v == 0) {
      v = 0;
      for (var i = 0; i < 4; i++) {
        v = (v << 16) | rnd.nextInt(0x10000);
      }
    }
    return v;
  }

  static final Map<String, (int, int)> _laHeightWeight = {
    for (final p in [for (final e in kLaHeightWeight.split(';')) if (e.isNotEmpty) e.split(',')])
      '${p[0]},${p[1]}': (int.parse(p[2]), int.parse(p[3])),
  };

  static final Float32List _f = Float32List(1);
  static double _f32(double v) {
    _f[0] = v;
    return _f[0];
  }

  // PKHeX PA8.GetScalarPercent (aritmética de float32).
  static double _scalarPercent(int scalar) {
    final percent = _f32(scalar / _f32(255.0));
    return _f32(_f32(percent * _f32(0.40000004)) + _f32(0.8));
  }
}
