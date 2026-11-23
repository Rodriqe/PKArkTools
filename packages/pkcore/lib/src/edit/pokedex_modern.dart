import 'dart:typed_data';

import '../crypto/sc_block.dart';
import '../data/forms.dart';
import '../data/game_data.dart';
import '../data/generated/dex_data.dart';
import '../data/species_convert.dart';
import '../model/game.dart';
import '../util/bytes.dart';
import 'pokedex.dart';

// Pokédex de Gen 6 a Gen 9. Portado de PKHeX.Core (GPL-3.0): `Zukan6XY/AO`,
// `Zukan7`/`Zukan7b`, `Zukan8` (SwSh), `Zukan8b` (BDSP), `PokedexSave8a`
// (Leyendas Arceus), `Zukan9Paldea`/`Zukan9Kitakami` (SV) y `Zukan9a` (Z-A).

bool _bit(Uint8List d, int ofs, int i) => (d[ofs + (i >> 3)] >> (i & 7)) & 1 == 1;

void _setBitV(Uint8List d, int ofs, int i, bool v) {
  final o = ofs + (i >> 3);
  d[o] = v ? d[o] | (1 << (i & 7)) : d[o] & ~(1 << (i & 7));
}

int _setMask(int mask, int bit, bool v) => v ? mask | (1 << bit) : mask & ~(1 << bit);

/// Reparto de géneros de una especie en un juego.
mixin _GenderInfo on Pokedex {
  GameVersion get game;

  // Primera forma presente: en Leyendas Arceus Growlithe solo existe como forma de Hisui.
  int _ratio(int species) {
    final forms = SpeciesForms.presentForms(species, game);
    return GameDataTable.forGame(game).entry(species, forms.isEmpty ? 0 : forms.first)?.genderRatio ?? 255;
  }

  bool _dualGender(int species) {
    final r = _ratio(species);
    return r != 0 && r != 254 && r != 255;
  }

  bool _genderless(int species) => _ratio(species) == 255;

  /// Género que muestra el juego por defecto (0 = macho/sin género, 1 = hembra).
  int _defaultGender(int species) => _ratio(species) == 254 ? 1 : 0;

  @override
  int allGenders(int species) => _dualGender(species) ? 3 : (_ratio(species) == 254 ? 2 : 1);

  @override
  bool isGenderless(int species) => _genderless(species);
}

/// Lista de especies para el filtro "regional" de la interfaz.
const kDexRegionKeys = ['galar', 'armor', 'crown', 'hisui', 'paldea', 'kitakami', 'blueberry', 'lumiose', 'hyperspace'];

// =================================================================== Gen 6

/// X/Y y Rubí Omega/Zafiro Alfa (PKHeX `Zukan6`). Bloque de 0x6A0 (XY) o 0x11CC (ORAS).
class Gen6Pokedex extends Pokedex with _GenderInfo {
  Gen6Pokedex(this.d, this.base, {required this.oras}) : game = oras ? GameVersion.omegaRubyAlphaSapphire : GameVersion.xy;

  final Uint8List d;
  final int base;
  final bool oras;
  @override
  final GameVersion game;

  @override
  int get maxSpecies => 721;
  @override
  String get description => oras ? 'Zukan6AO' : 'Zukan6XY';
  @override
  bool get hasShiny => true;
  @override
  bool get hasGender => true;
  @override
  bool get hasForms => true;

  int get _formLen => oras ? 0x26 : 0x18;
  int get _caught => base + 0x8;
  int _seen(int r) => base + 0x68 + r * 0x60;
  int _disp(int r) => base + 0x1E8 + r * 0x60;
  int get _formDex => base + 0x368;
  int get _lang => _formDex + _formLen * 4;
  int get _foreign => base + 0x64C;

  (int, int)? _forms(int species) {
    if (oras) {
      final f = kDexFormsAO[species];
      if (f != null) return f;
    }
    return kDexFormsXY[species] ?? kDexFormsB2W2[species] ?? kDexFormsBW[species];
  }

  @override
  int formCount(int species) => _forms(species)?.$2 ?? 1;

  @override
  bool formAvailable(int species, int form) {
    final f = _forms(species);
    return f != null && form < f.$2 && f.$1 + form < _formLen * 8;
  }

  @override
  bool isCaught(int species) => _bit(d, _caught, species - 1);

  @override
  bool isSeen(int species) => genderMask(species) != 0;

  @override
  bool isShinySeen(int species) => _bit(d, _seen(2), species - 1) || _bit(d, _seen(3), species - 1);

  @override
  int genderMask(int species) {
    final i = species - 1;
    return (_bit(d, _seen(0), i) || _bit(d, _seen(2), i) ? 1 : 0) | (_bit(d, _seen(1), i) || _bit(d, _seen(3), i) ? 2 : 0);
  }

  @override
  int formMask(int species) {
    final f = _forms(species);
    if (f == null) return 0;
    var m = 0;
    for (var k = 0; k < f.$2; k++) {
      if (!formAvailable(species, k)) continue;
      if (_bit(d, _formDex, f.$1 + k) || _bit(d, _formDex + _formLen, f.$1 + k)) m |= 1 << k;
    }
    return m;
  }

  void _ensureDisplayed(int species, int region) {
    final i = species - 1;
    for (var r = 0; r < 4; r++) {
      if (_bit(d, _disp(r), i)) return;
    }
    _setBitV(d, _disp(region), i, true);
  }

  void _setCount(int species, int value) {
    if (oras) d.setU16le(base + 0x684 + species * 2, value);
  }

  @override
  void setSeen(int species, bool value) {
    final i = species - 1;
    if (value) {
      if (isSeen(species)) return;
      final g = _defaultGender(species);
      _setBitV(d, _seen(g), i, true);
      _ensureDisplayed(species, g);
      if (oras && d.u16le(base + 0x684 + species * 2) == 0) _setCount(species, 1);
      return;
    }
    for (var r = 0; r < 4; r++) {
      _setBitV(d, _seen(r), i, false);
      _setBitV(d, _disp(r), i, false);
    }
    final f = _forms(species);
    if (f != null) {
      for (var k = 0; k < f.$2; k++) {
        if (!formAvailable(species, k)) continue;
        for (var r = 0; r < 4; r++) {
          _setBitV(d, _formDex + r * _formLen, f.$1 + k, false);
        }
      }
    }
    setCaught(species, false);
    if (oras) {
      _setCount(species, 0);
      d.setU16le(base + 0xC28 + species * 2, 0);
    }
  }

  @override
  void setCaught(int species, bool value) {
    final i = species - 1;
    _setBitV(d, _caught, i, value);
    if (!oras && species <= 649) _setBitV(d, _foreign, i, value);
    var anyLang = false;
    for (var l = 0; l < 7; l++) {
      anyLang |= _bit(d, _lang, i * 7 + l);
    }
    if (value && !anyLang || !value) {
      for (var l = 0; l < 7; l++) {
        _setBitV(d, _lang, i * 7 + l, value);
      }
    }
  }

  @override
  void setShinySeen(int species, bool value) {
    final i = species - 1;
    if (value) {
      if (isShinySeen(species)) return;
      _setBitV(d, _seen(2 + _defaultGender(species)), i, true);
    } else {
      _setBitV(d, _seen(2), i, false);
      _setBitV(d, _seen(3), i, false);
    }
  }

  @override
  void setGenderSeen(int species, int gender, bool value) {
    if (gender > 1) return;
    _setBitV(d, _seen(gender), species - 1, value);
    if (value) _ensureDisplayed(species, gender);
  }

  @override
  void setFormSeen(int species, int form, bool value) {
    final f = _forms(species);
    if (f == null || !formAvailable(species, form)) return;
    final b = f.$1 + form;
    _setBitV(d, _formDex, b, value);
    if (!value) {
      _setBitV(d, _formDex + _formLen, b, false);
      _setBitV(d, _formDex + 2 * _formLen, b, false);
      _setBitV(d, _formDex + 3 * _formLen, b, false);
      return;
    }
    for (var k = 0; k < f.$2; k++) {
      if (formAvailable(species, k) && (_bit(d, _formDex + 2 * _formLen, f.$1 + k) || _bit(d, _formDex + 3 * _formLen, f.$1 + k))) {
        return;
      }
    }
    _setBitV(d, _formDex + 2 * _formLen, b, true);
  }
}

// =================================================================== Gen 7

/// Sol/Luna, Ultrasol/Ultraluna y Let's Go (PKHeX `Zukan7`/`Zukan7b`).
///
/// Bits: capturado en 0x88; visto (4 regiones: macho, hembra, macho
/// variocolor, hembra variocolor) desde 0xF0 de 0x8C bytes cada una, y otras
/// 4 regiones de "mostrado". Las formas alternativas usan bits a partir de
/// `maxSpecies` (`DexFormUtil`).
class Gen7Pokedex extends Pokedex with _GenderInfo {
  Gen7Pokedex(this.d, this.base, this.game);

  final Uint8List d;
  final int base;
  @override
  final GameVersion game;

  @override
  int get maxSpecies => switch (game) {
        GameVersion.sunMoon => 802,
        GameVersion.letsGo => 809,
        _ => 807,
      };

  @override
  String get description => game == GameVersion.letsGo ? 'Zukan7b' : 'Zukan7';
  @override
  bool get hasShiny => true;
  @override
  bool get hasGender => true;
  @override
  bool get hasForms => true;

  @override
  bool contains(int species) =>
      species >= 1 && species <= maxSpecies && (game != GameVersion.letsGo || species <= 151 || species == 808 || species == 809);

  (List<int>, List<int>) get _formTable => switch (game) {
        GameVersion.sunMoon => (kDex7SpeciesSm, kDex7CountsSm),
        GameVersion.letsGo => (kDex7SpeciesGg, kDex7CountsGg),
        _ => (kDex7SpeciesUsum, kDex7CountsUsum),
      };

  int get _caught => base + 0x88;
  int _region(int r) => base + 0xF0 + r * 0x8C;
  int get _lang => base + 0x550;

  @override
  int formCount(int species) {
    final (sp, ct) = _formTable;
    final i = sp.indexOf(species);
    return i < 0 ? 1 : ct[i];
  }

  /// Bit de la forma (forma 0 = bit de la especie).
  int _formBit(int species, int form) {
    if (form == 0) return species - 1;
    final (sp, ct) = _formTable;
    final i = sp.indexOf(species);
    if (i < 0) return -1;
    var prior = -i;
    for (var k = 0; k < i; k++) {
      prior += ct[k];
    }
    final bit = maxSpecies + prior + form - 1;
    return bit < 0x8C * 8 ? bit : -1;
  }

  @override
  bool formAvailable(int species, int form) => form < formCount(species) && _formBit(species, form) >= 0;

  bool _anySeen(int bit) {
    for (var r = 0; r < 4; r++) {
      if (_bit(d, _region(r), bit)) return true;
    }
    return false;
  }

  @override
  bool isCaught(int species) => _bit(d, _caught, species - 1);

  @override
  bool isSeen(int species) => _anySeen(species - 1);

  @override
  bool isShinySeen(int species) {
    for (var f = 0; f < formCount(species); f++) {
      final b = _formBit(species, f);
      if (b >= 0 && (_bit(d, _region(2), b) || _bit(d, _region(3), b))) return true;
    }
    return false;
  }

  @override
  int genderMask(int species) {
    final b = species - 1;
    return (_bit(d, _region(0), b) || _bit(d, _region(2), b) ? 1 : 0) | (_bit(d, _region(1), b) || _bit(d, _region(3), b) ? 2 : 0);
  }

  @override
  int formMask(int species) {
    var m = 0;
    for (var f = 0; f < formCount(species); f++) {
      final b = _formBit(species, f);
      if (b >= 0 && _anySeen(b)) m |= 1 << f;
    }
    return m;
  }

  void _ensureDisplayed(int bit, int region) {
    for (var r = 4; r < 8; r++) {
      if (_bit(d, _region(r), bit)) return;
    }
    _setBitV(d, _region(4 + region), bit, true);
  }

  @override
  void setSeen(int species, bool value) {
    final b = species - 1;
    if (value) {
      if (isSeen(species)) return;
      final g = _defaultGender(species);
      _setBitV(d, _region(g), b, true);
      _ensureDisplayed(b, g);
      return;
    }
    for (var f = 0; f < formCount(species); f++) {
      final fb = _formBit(species, f);
      if (fb < 0) continue;
      for (var r = 0; r < 8; r++) {
        _setBitV(d, _region(r), fb, false);
      }
    }
    setCaught(species, false);
  }

  @override
  void setCaught(int species, bool value) {
    final b = species - 1;
    _setBitV(d, _caught, b, value);
    var anyLang = false;
    for (var l = 0; l < 9; l++) {
      anyLang |= _bit(d, _lang, b * 9 + l);
    }
    if (!value || !anyLang) {
      for (var l = 0; l < 9; l++) {
        if (_lang + ((b * 9 + l) >> 3) < base + 0xF78) _setBitV(d, _lang, b * 9 + l, value);
      }
    }
  }

  @override
  void setShinySeen(int species, bool value) {
    final b = species - 1;
    if (value) {
      if (isShinySeen(species)) return;
      _setBitV(d, _region(2 + _defaultGender(species)), b, true);
    } else {
      for (var f = 0; f < formCount(species); f++) {
        final fb = _formBit(species, f);
        if (fb < 0) continue;
        _setBitV(d, _region(2), fb, false);
        _setBitV(d, _region(3), fb, false);
      }
    }
  }

  @override
  void setGenderSeen(int species, int gender, bool value) {
    if (gender > 1) return;
    final b = species - 1;
    _setBitV(d, _region(gender), b, value);
    if (value) _ensureDisplayed(b, gender);
  }

  @override
  void setFormSeen(int species, int form, bool value) {
    if (form == 0) return; // la forma base es el propio registro de la especie
    final b = _formBit(species, form);
    if (b < 0) return;
    if (value) {
      if (_anySeen(b)) return;
      final g = _defaultGender(species);
      _setBitV(d, _region(g), b, true);
    } else {
      for (var r = 0; r < 8; r++) {
        _setBitV(d, _region(r), b, false);
      }
    }
  }
}

// =================================================================== BDSP

/// Diamante Brillante/Perla Reluciente (PKHeX `Zukan8b`): estado por especie
/// (0 nada, 1 oído, 2 visto, 3 capturado) y booleanos de 4 bytes.
class BdspPokedex extends Pokedex with _GenderInfo {
  BdspPokedex(this.d, this.base);

  final Uint8List d;
  final int base;
  @override
  GameVersion get game => GameVersion.brilliantDiamondShiningPearl;

  static const int _n = 493;
  static const int _maleShiny = _n * 4, _femaleShiny = _maleShiny + _n * 4, _male = _femaleShiny + _n * 4, _female = _male + _n * 4;
  static const int _forms0 = _female + _n * 4;
  static const List<(int, int)> _formSpecies = [
    (201, 28), (351, 4), (386, 4), (412, 3), (413, 3), (414, 3), (421, 2), //
    (422, 2), (423, 2), (479, 6), (487, 2), (492, 2), (493, 18),
  ];
  static final int _lang = () {
    var o = _forms0;
    for (final (_, c) in _formSpecies) {
      o += c * 4 * 2;
    }
    return o;
  }();

  @override
  int get maxSpecies => _n;
  @override
  String get description => 'Zukan8b';
  @override
  bool get hasShiny => true;
  @override
  bool get hasGender => true;
  @override
  bool get hasForms => true;

  int _state(int s) => d.s32le(base + (s - 1) * 4);
  void _setState(int s, int v) => d.setU32le(base + (s - 1) * 4, v);
  bool _b(int ofs, int s) => d.u32le(base + ofs + (s - 1) * 4) == 1;
  void _setB(int ofs, int s, bool v) => d.setU32le(base + ofs + (s - 1) * 4, v ? 1 : 0);

  int? _formOfs(int species) {
    var o = _forms0;
    for (final (sp, c) in _formSpecies) {
      if (sp == species) return o;
      o += c * 4 * 2;
    }
    return null;
  }

  @override
  int formCount(int species) => _formSpecies.where((e) => e.$1 == species).firstOrNull?.$2 ?? 1;

  @override
  bool isSeen(int species) => _state(species) >= 2;
  @override
  bool isCaught(int species) => _state(species) >= 3;
  @override
  bool isShinySeen(int species) => _b(_maleShiny, species) || _b(_femaleShiny, species);

  @override
  int genderMask(int species) =>
      (_b(_male, species) || _b(_maleShiny, species) ? 1 : 0) | (_b(_female, species) || _b(_femaleShiny, species) ? 2 : 0);

  @override
  int formMask(int species) {
    final o = _formOfs(species);
    if (o == null) return 0;
    final c = formCount(species);
    var m = 0;
    for (var f = 0; f < c; f++) {
      if (d.u32le(base + o + f * 4) == 1 || d.u32le(base + o + c * 4 + f * 4) == 1) m |= 1 << f;
    }
    return m;
  }

  @override
  void setSeen(int species, bool value) {
    if (value) {
      if (isSeen(species)) return;
      _setState(species, 2);
      _setB(_defaultGender(species) == 1 ? _female : _male, species, true);
      if (_formOfs(species) != null) setFormSeen(species, 0, true);
      return;
    }
    _setState(species, 0);
    for (final o in [_male, _female, _maleShiny, _femaleShiny]) {
      _setB(o, species, false);
    }
    final fo = _formOfs(species);
    if (fo != null) d.fillRange(base + fo, base + fo + formCount(species) * 8, 0);
    d.setU32le(base + _lang + (species - 1) * 4, 0);
  }

  @override
  void setCaught(int species, bool value) {
    if (value) {
      if (!isSeen(species)) setSeen(species, true);
      _setState(species, 3);
      if (d.u32le(base + _lang + (species - 1) * 4) == 0) d.setU32le(base + _lang + (species - 1) * 4, 0x1FF);
    } else {
      if (_state(species) == 3) _setState(species, 2);
      d.setU32le(base + _lang + (species - 1) * 4, 0);
    }
  }

  @override
  void setShinySeen(int species, bool value) {
    if (value) {
      if (isShinySeen(species)) return;
      _setB(_defaultGender(species) == 1 ? _femaleShiny : _maleShiny, species, true);
    } else {
      _setB(_maleShiny, species, false);
      _setB(_femaleShiny, species, false);
    }
  }

  @override
  void setGenderSeen(int species, int gender, bool value) {
    if (gender > 1) return;
    _setB(gender == 1 ? _female : _male, species, value);
  }

  @override
  void setFormSeen(int species, int form, bool value) {
    final o = _formOfs(species);
    if (o == null || form >= formCount(species)) return;
    d.setU32le(base + o + form * 4, value ? 1 : 0);
    if (!value) d.setU32le(base + o + formCount(species) * 4 + form * 4, 0);
  }
}

// =================================================================== Switch (bloques)

/// Base de las Pokédex que viven en bloques SwishCrypto: avisa al editor de
/// cada escritura para que vuelva a cifrar el save.
abstract class _BlockDex extends Pokedex with _GenderInfo {
  _BlockDex(this.onChange);
  final void Function() onChange;

  /// Fila de la tabla generada para la especie.
  List<int> get _table;
  int get _stride;

  int _row(int species, int col) {
    final o = species * _stride + col;
    return species >= 0 && o < _table.length ? _table[o] : 0;
  }

  @override
  int formCount(int species) => _row(species, 0).clamp(1, 31);

  int _presentMask(int species) => _row(species, 1);

  @override
  bool formAvailable(int species, int form) => form < formCount(species) && (_presentMask(species) >> form) & 1 == 1;

  int _firstPresent(int species) {
    final m = _presentMask(species);
    for (var f = 0; f < 31; f++) {
      if ((m >> f) & 1 == 1) return f;
    }
    return 0;
  }
}

/// Espada/Escudo (PKHeX `Zukan8`): tres bloques (Galar, Isla de la Armadura,
/// Corona Nieve) con entradas de 0x30 bytes por número regional.
class SwshPokedex extends _BlockDex {
  SwshPokedex(this.galar, this.armor, this.crown, super.onChange);

  final SCBlock galar;
  final SCBlock? armor, crown;
  @override
  GameVersion get game => GameVersion.swordShield;

  @override
  List<int> get _table => kDexSwsh;
  @override
  int get _stride => 5;

  @override
  int get maxSpecies => 898;
  @override
  String get description => 'Zukan8';
  @override
  bool get hasShiny => true;
  @override
  bool get hasGender => true;
  @override
  bool get hasForms => true;

  @override
  List<String> get regions => ['galar', if (_ok(armor)) 'armor', if (_ok(crown)) 'crown'];

  bool _ok(SCBlock? b) => b != null && b.data.isNotEmpty;

  /// (bloque, desplazamiento) de la entrada, o null si la especie no está en ninguna Pokédex.
  (Uint8List, int)? _entry(int species) {
    if (species < 1 || species > maxSpecies) return null;
    final g = _row(species, 2), a = _row(species, 3), c = _row(species, 4);
    (Uint8List, int)? at(SCBlock? b, int idx) =>
        _ok(b) && b!.data.length >= idx * 0x30 ? (b.data, (idx - 1) * 0x30) : null;
    if (g != 0) return at(galar, g);
    if (a != 0) return at(armor, a);
    if (c != 0) return at(crown, c);
    return null;
  }

  @override
  (String, int)? regionalNumber(int species) {
    final g = _row(species, 2), a = _row(species, 3), c = _row(species, 4);
    if (g != 0) return ('galar', g);
    if (a != 0 && _ok(armor)) return ('armor', a);
    if (c != 0 && _ok(crown)) return ('crown', c);
    return null;
  }

  @override
  bool contains(int species) => _entry(species) != null;

  int _seenWord(Uint8List b, int o, int region) => b.u32le(o + region * 8);

  @override
  bool isSeen(int species) {
    final e = _entry(species);
    if (e == null) return false;
    for (var i = 0; i < 0x20; i++) {
      if (e.$1[e.$2 + i] != 0) return true;
    }
    return false;
  }

  @override
  bool isCaught(int species) {
    final e = _entry(species);
    return e != null && e.$1[e.$2 + 0x20] & 1 == 1;
  }

  @override
  bool isShinySeen(int species) {
    final e = _entry(species);
    return e != null && (_seenWord(e.$1, e.$2, 2) | _seenWord(e.$1, e.$2, 3)) != 0;
  }

  @override
  int genderMask(int species) {
    final e = _entry(species);
    if (e == null) return 0;
    final m = _seenWord(e.$1, e.$2, 0) | _seenWord(e.$1, e.$2, 2);
    final f = _seenWord(e.$1, e.$2, 1) | _seenWord(e.$1, e.$2, 3);
    return (m != 0 ? 1 : 0) | (f != 0 ? 2 : 0);
  }

  @override
  int formMask(int species) {
    final e = _entry(species);
    if (e == null) return 0;
    var m = 0;
    for (var r = 0; r < 4; r++) {
      m |= _seenWord(e.$1, e.$2, r);
    }
    return m & ((1 << formCount(species)) - 1);
  }

  @override
  void setSeen(int species, bool value) {
    final e = _entry(species);
    if (e == null) return;
    if (value) {
      if (isSeen(species)) return;
      final g = _defaultGender(species);
      final f = _firstPresent(species);
      _setBitV(e.$1, e.$2 + g * 8, f, true);
      _setDisplay(e, f, g, false);
    } else {
      e.$1.fillRange(e.$2, e.$2 + 0x30, 0);
    }
    onChange();
  }

  void _setDisplay((Uint8List, int) e, int form, int gender, bool shiny) {
    final o = e.$2 + 0x20;
    var v = e.$1.u32le(o);
    v = (v & ~(0x1FFF << 15)) | ((form & 0x1FFF) << 15);
    v = (v & ~(3 << 29)) | ((gender & 3) << 29);
    v = (v & ~(1 << 31)) | ((shiny ? 1 : 0) << 31);
    e.$1.setU32le(o, v);
  }

  @override
  void setCaught(int species, bool value) {
    final e = _entry(species);
    if (e == null) return;
    final o = e.$2 + 0x20;
    var v = e.$1.u32le(o);
    v = _setMask(v, 0, value);
    if (value && (v >> 2) & 0x1FF == 0) v |= 0x1FF << 2; // idiomas
    if (!value) v &= ~(0x1FFF << 2) & ~2; // idiomas y Gigamax
    e.$1.setU32le(o, v);
    onChange();
  }

  @override
  void setShinySeen(int species, bool value) {
    final e = _entry(species);
    if (e == null) return;
    if (value) {
      if (isShinySeen(species)) return;
      _setBitV(e.$1, e.$2 + (2 + _defaultGender(species)) * 8, _firstPresent(species), true);
    } else {
      e.$1.fillRange(e.$2 + 0x10, e.$2 + 0x20, 0);
      final v = e.$1.u32le(e.$2 + 0x20);
      e.$1.setU32le(e.$2 + 0x20, v & ~(1 << 31));
    }
    onChange();
  }

  @override
  void setGenderSeen(int species, int gender, bool value) {
    final e = _entry(species);
    if (e == null || gender > 1) return;
    if (value) {
      if (_seenWord(e.$1, e.$2, gender) == 0) _setBitV(e.$1, e.$2 + gender * 8, _firstPresent(species), true);
    } else {
      e.$1.fillRange(e.$2 + gender * 8, e.$2 + gender * 8 + 8, 0);
    }
    onChange();
  }

  @override
  void setFormSeen(int species, int form, bool value) {
    final e = _entry(species);
    if (e == null || !formAvailable(species, form)) return;
    if (value) {
      if ((formMask(species) >> form) & 1 == 0) _setBitV(e.$1, e.$2 + _defaultGender(species) * 8, form, true);
    } else {
      for (var r = 0; r < 4; r++) {
        _setBitV(e.$1, e.$2 + r * 8, form, false);
      }
    }
    onChange();
  }
}

/// Leyendas Arceus (PKHeX `PokedexSave8a`). Visto = la especie tiene entrada de
/// investigación actualizada; capturado/variocolor/género/formas se leen de las
/// entradas estadísticas por especie+forma (bits: +1 hembra, +2 alfa, +4 variocolor).
class LaPokedex extends _BlockDex {
  LaPokedex(this.block, super.onChange);

  final SCBlock block;
  @override
  GameVersion get game => GameVersion.legendsArceus;
  Uint8List get _d => block.data;

  @override
  List<int> get _table => kDexLa;
  @override
  int get _stride => 3;

  static const int _research = 0x70, _researchSize = 0x58, _stats = 0x151A8, _statSize = 0x18;

  @override
  int get maxSpecies => 905;
  @override
  String get description => 'PokedexSave8a';
  @override
  bool get hasShiny => true;
  @override
  bool get hasGender => true;
  @override
  bool get hasForms => true;
  @override
  List<String> get regions => const ['hisui'];

  @override
  (String, int)? regionalNumber(int species) => _row(species, 2) == 0 ? null : ('hisui', _row(species, 2));

  @override
  bool contains(int species) =>
      species >= 1 && species <= maxSpecies && _row(species, 2) != 0 && _d.length >= _stats + 1480 * _statSize;

  int _res(int species) => _research + species * _researchSize;

  int? _slot(int species, int form) {
    final key = species | (form << 11);
    var lo = 0, hi = kDexLaFormIds.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final v = kDexLaFormIds[mid];
      if (v == key) return _stats + kDexLaFormSlots[mid] * _statSize;
      if (v < key) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return null;
  }

  @override
  bool formAvailable(int species, int form) => super.formAvailable(species, form) && _slot(species, form) != null;

  /// OR de las banderas visto/obtenido/capturado de una forma.
  int _flags(int species, int form) {
    final o = _slot(species, form);
    return o == null ? 0 : _d[o + 4] | _d[o + 5] | _d[o + 6];
  }

  int _allFlags(int species) {
    var m = 0;
    for (var f = 0; f < formCount(species); f++) {
      m |= _flags(species, f);
    }
    return m;
  }

  @override
  int? researchLevel(int species) => contains(species) ? _d.u16le(_res(species) + 0x08).clamp(0, 100) : null;

  @override
  bool isSeen(int species) => contains(species) && (_d[_res(species)] & 1 == 1 || _allFlags(species) != 0);

  @override
  bool isCaught(int species) {
    for (var f = 0; f < formCount(species); f++) {
      final o = _slot(species, f);
      if (o != null && _d[o + 5] != 0) return true;
    }
    return false;
  }

  @override
  bool isShinySeen(int species) => _allFlags(species) & 0xF0 != 0;

  @override
  int genderMask(int species) {
    final m = _allFlags(species);
    return (m & 0x55 != 0 ? 1 : 0) | (m & 0xAA != 0 ? 2 : 0);
  }

  @override
  int formMask(int species) {
    var m = 0;
    for (var f = 0; f < formCount(species); f++) {
      if (_flags(species, f) != 0) m |= 1 << f;
    }
    return m;
  }

  void _touch(int species) {
    final r = _res(species);
    _d[r] |= 1;
    if (_d.u16le(r + 0x0C) == 0) {
      final counter = _d.u16le(0x06);
      _d.setU16le(r + 0x0C, counter == 0 ? 1 : counter);
      if (counter < 60000) _d.setU16le(0x06, counter + 1);
    }
  }

  void _orFlag(int species, int form, int byte, int shift) {
    final o = _slot(species, form);
    if (o != null) _d[o + byte] |= 1 << shift;
  }

  @override
  void setSeen(int species, bool value) {
    if (!contains(species)) return;
    if (value) {
      if (isSeen(species) && _allFlags(species) != 0) return;
      _touch(species);
      _orFlag(species, _firstPresent(species), 4, _defaultGender(species));
    } else {
      _d.fillRange(_res(species), _res(species) + _researchSize, 0);
      for (var f = 0; f < formCount(species); f++) {
        final o = _slot(species, f);
        if (o != null) _d.fillRange(o, o + _statSize, 0);
      }
    }
    onChange();
  }

  @override
  void setCaught(int species, bool value) {
    if (!contains(species)) return;
    if (value) {
      if (isCaught(species)) return;
      _touch(species);
      _orFlag(species, _firstPresent(species), 4, _defaultGender(species));
      _orFlag(species, _firstPresent(species), 5, _defaultGender(species));
      final r = _res(species);
      if (_d.u16le(r + 0x0A) == 0) _d.setU16le(r + 0x0A, 1);
    } else {
      for (var f = 0; f < formCount(species); f++) {
        final o = _slot(species, f);
        if (o != null) {
          _d[o + 5] = 0;
          _d[o + 6] = 0;
        }
      }
      _d.setU16le(_res(species) + 0x0A, 0);
    }
    onChange();
  }

  @override
  void setShinySeen(int species, bool value) {
    if (!contains(species)) return;
    if (value) {
      if (isShinySeen(species)) return;
      _touch(species);
      _orFlag(species, _firstPresent(species), 4, 4 + _defaultGender(species));
    } else {
      for (var f = 0; f < formCount(species); f++) {
        final o = _slot(species, f);
        if (o == null) continue;
        for (var k = 4; k <= 6; k++) {
          _d[o + k] &= 0x0F;
        }
      }
    }
    onChange();
  }

  @override
  void setGenderSeen(int species, int gender, bool value) {
    if (!contains(species) || gender > 1) return;
    if (value) {
      if ((genderMask(species) >> gender) & 1 == 1) return;
      _touch(species);
      _orFlag(species, _firstPresent(species), 4, gender);
    } else {
      final mask = gender == 0 ? 0xAA : 0x55;
      for (var f = 0; f < formCount(species); f++) {
        final o = _slot(species, f);
        if (o == null) continue;
        for (var k = 4; k <= 6; k++) {
          _d[o + k] &= mask;
        }
      }
    }
    onChange();
  }

  @override
  void setFormSeen(int species, int form, bool value) {
    if (!contains(species) || !formAvailable(species, form)) return;
    final o = _slot(species, form)!;
    if (value) {
      if (_flags(species, form) != 0) return;
      _touch(species);
      _d[o + 4] |= 1 << _defaultGender(species);
    } else {
      _d[o + 4] = 0;
      _d[o + 5] = 0;
      _d[o + 6] = 0;
    }
    onChange();
  }
}

/// Escarlata/Púrpura (PKHeX `Zukan9Paldea` y `Zukan9Kitakami`). Desde la
/// versión 2.0.1 el juego usa solo el bloque "Kitakami" (que cubre Paldea,
/// Kitakami y Arándano); los saves anteriores usan el bloque de Paldea.
class SvPokedex extends _BlockDex {
  SvPokedex(this.paldea, this.kitakami, super.onChange);

  final SCBlock? paldea;
  final SCBlock? kitakami;
  @override
  GameVersion get game => GameVersion.scarletViolet;

  bool get kitakamiMode => kitakami != null && kitakami!.data.isNotEmpty;

  @override
  List<int> get _table => kDexSv;
  @override
  int get _stride => 5;

  @override
  int get maxSpecies => 1025;
  @override
  String get description => kitakamiMode ? 'Zukan9Kitakami' : 'Zukan9Paldea';
  @override
  bool get hasShiny => true;
  @override
  bool get hasGender => true;
  @override
  bool get hasForms => true;

  @override
  List<String> get regions => kitakamiMode ? const ['paldea', 'kitakami', 'blueberry'] : const ['paldea'];

  @override
  (String, int)? regionalNumber(int species) {
    if (_row(species, 2) != 0) return ('paldea', _row(species, 2));
    if (!kitakamiMode) return null;
    if (_row(species, 3) != 0) return ('kitakami', _row(species, 3));
    if (_row(species, 4) != 0) return ('blueberry', _row(species, 4));
    return null;
  }

  int get _size => kitakamiMode ? 0x20 : 0x18;
  Uint8List? get _data => kitakamiMode ? kitakami!.data : paldea?.data;

  int? _ofs(int species) {
    final d = _data;
    if (d == null || species < 1 || species > maxSpecies) return null;
    final o = SpeciesConvert.gen9FromNational(species) * _size;
    return o + _size <= d.length ? o : null;
  }

  @override
  bool contains(int species) => regionalNumber(species) != null && _presentMask(species) != 0 && _ofs(species) != null;

  // ---- campos según el modo
  int _seenForms(Uint8List d, int o) => kitakamiMode ? d.u32le(o + 4) : d.u32le(o + 4);
  int _genderByte(Uint8List d, int o) => kitakamiMode ? d[o + 0x12] : d.u16le(o + 8);
  void _setGenderByte(Uint8List d, int o, int v) => kitakamiMode ? d[o + 0x12] = v : d.setU16le(o + 8, v);

  @override
  bool isSeen(int species) {
    final o = _ofs(species);
    if (o == null) return false;
    final d = _data!;
    return kitakamiMode ? d.u32le(o + 4) != 0 : d.u32le(o) >= 2;
  }

  @override
  bool isCaught(int species) {
    final o = _ofs(species);
    if (o == null) return false;
    final d = _data!;
    return kitakamiMode ? d.u32le(o) != 0 : d.u32le(o) >= 3;
  }

  @override
  bool isShinySeen(int species) {
    final o = _ofs(species);
    if (o == null) return false;
    final d = _data!;
    return kitakamiMode ? d[o + 0x13] & 2 != 0 : d[o + 0x0C] != 0;
  }

  @override
  int genderMask(int species) {
    final o = _ofs(species);
    if (o == null) return 0;
    final g = _genderByte(_data!, o);
    return (g & 5 != 0 ? 1 : 0) | (g & 2 != 0 ? 2 : 0);
  }

  @override
  int formMask(int species) {
    final o = _ofs(species);
    if (o == null) return 0;
    return _seenForms(_data!, o) & ((1 << formCount(species)) - 1);
  }

  int _genderBit(int species, int g) => g == 0 && _genderless(species) ? 4 : (1 << g);

  @override
  void setSeen(int species, bool value) {
    final o = _ofs(species);
    if (o == null) return;
    final d = _data!;
    if (value) {
      if (isSeen(species)) return;
      final f = _firstPresent(species);
      if (kitakamiMode) {
        for (final k in [4, 8, 0xC]) {
          d.setU32le(o + k, d.u32le(o + k) | (1 << f));
        }
        d[o + 0x13] |= 1;
      } else {
        d.setU32le(o, 2);
        d.setU32le(o + 4, d.u32le(o + 4) | (1 << f));
      }
      _setGenderByte(d, o, _genderByte(d, o) | _genderBit(species, _defaultGender(species)));
    } else {
      d.fillRange(o, o + _size, 0);
      if (!kitakamiMode) d.setU32le(o, 1); // "conocido": el juego lo deja visible pero vacío
    }
    onChange();
  }

  @override
  void setCaught(int species, bool value) {
    final o = _ofs(species);
    if (o == null) return;
    final d = _data!;
    if (value) {
      if (!isSeen(species)) setSeen(species, true);
      if (kitakamiMode) {
        if (d.u32le(o) == 0) d.setU32le(o, d.u32le(o + 4));
        if (d.u16le(o + 0x10) == 0) d.setU16le(o + 0x10, 0x1FF);
      } else {
        d.setU32le(o, 3);
        if (d.u16le(o + 0x0A) == 0) d.setU16le(o + 0x0A, 0x1FF);
      }
    } else {
      if (kitakamiMode) {
        d.setU32le(o, 0);
        d.setU16le(o + 0x10, 0);
      } else {
        if (d.u32le(o) == 3) d.setU32le(o, 2);
        d.setU16le(o + 0x0A, 0);
      }
    }
    onChange();
  }

  @override
  void setShinySeen(int species, bool value) {
    final o = _ofs(species);
    if (o == null) return;
    final d = _data!;
    if (kitakamiMode) {
      d[o + 0x13] = value ? d[o + 0x13] | 3 : d[o + 0x13] & ~2;
    } else {
      d[o + 0x0C] = value ? 1 : 0;
    }
    onChange();
  }

  @override
  void setGenderSeen(int species, int gender, bool value) {
    final o = _ofs(species);
    if (o == null || gender > 1) return;
    final d = _data!;
    final b = _genderBit(species, gender);
    _setGenderByte(d, o, value ? _genderByte(d, o) | b : _genderByte(d, o) & ~b);
    onChange();
  }

  @override
  void setFormSeen(int species, int form, bool value) {
    final o = _ofs(species);
    if (o == null || !formAvailable(species, form)) return;
    final d = _data!;
    final keys = kitakamiMode ? (value ? [4, 8, 0xC] : [0, 4, 8, 0xC]) : [4];
    for (final k in keys) {
      d.setU32le(o + k, _setMask(d.u32le(o + k), form, value));
    }
    onChange();
  }
}

/// Leyendas Z-A (PKHeX `Zukan9a`): entradas de 0x84 bytes por especie interna.
class ZaPokedex extends _BlockDex {
  ZaPokedex(this.block, super.onChange);

  final SCBlock block;
  Uint8List get _d => block.data;
  @override
  GameVersion get game => GameVersion.legendsZA;

  @override
  List<int> get _table => kDexZa;
  @override
  int get _stride => 3;

  static const int _size = 0x84;

  @override
  int get maxSpecies => 1025;
  @override
  String get description => 'Zukan9a';
  @override
  bool get hasShiny => true;
  @override
  bool get hasGender => true;
  @override
  bool get hasForms => true;
  @override
  List<String> get regions => const ['lumiose', 'hyperspace'];

  @override
  (String, int)? regionalNumber(int species) {
    final i = _row(species, 2);
    if (i == 0) return null;
    return i <= 232 ? ('lumiose', i) : ('hyperspace', i - 232);
  }

  int? _ofs(int species) {
    if (species < 1 || species > maxSpecies) return null;
    final o = SpeciesConvert.gen9FromNational(species) * _size;
    return o + _size <= _d.length ? o : null;
  }

  @override
  bool contains(int species) => _row(species, 2) != 0 && _presentMask(species) != 0 && _ofs(species) != null;

  @override
  bool isSeen(int species) {
    final o = _ofs(species);
    return o != null && _d.u32le(o + 4) != 0;
  }

  @override
  bool isCaught(int species) {
    final o = _ofs(species);
    return o != null && _d.u32le(o) != 0;
  }

  @override
  bool isShinySeen(int species) {
    final o = _ofs(species);
    return o != null && _d.u32le(o + 0x0C) != 0;
  }

  @override
  int genderMask(int species) {
    final o = _ofs(species);
    if (o == null) return 0;
    final g = _d[o + 0x0B];
    return (g & 5 != 0 ? 1 : 0) | (g & 2 != 0 ? 2 : 0);
  }

  @override
  int formMask(int species) {
    final o = _ofs(species);
    return o == null ? 0 : _d.u32le(o + 4) & ((1 << formCount(species)) - 1);
  }

  int _genderBit(int species, int g) => g == 0 && _genderless(species) ? 4 : (1 << g);

  @override
  void setSeen(int species, bool value) {
    final o = _ofs(species);
    if (o == null) return;
    if (value) {
      if (isSeen(species)) return;
      final f = _firstPresent(species);
      _d.setU32le(o + 4, _d.u32le(o + 4) | (1 << f));
      _d[o + 0x0B] |= _genderBit(species, _defaultGender(species));
      _d[o + 0x5A] = f;
    } else {
      _d.fillRange(o, o + 0x12, 0);
      _d[o + 0x5A] = 0;
      _d[o + 0x5B] = 0;
      _d[o + 0x5C] = 0;
    }
    onChange();
  }

  @override
  void setCaught(int species, bool value) {
    final o = _ofs(species);
    if (o == null) return;
    if (value) {
      if (!isSeen(species)) setSeen(species, true);
      if (_d.u32le(o) == 0) _d.setU32le(o, _d.u32le(o + 4));
      if (_d.u16le(o + 8) == 0) _d.setU16le(o + 8, 0x1FF);
    } else {
      _d.setU32le(o, 0);
      _d.setU16le(o + 8, 0);
    }
    onChange();
  }

  @override
  void setShinySeen(int species, bool value) {
    final o = _ofs(species);
    if (o == null) return;
    if (value) {
      if (_d.u32le(o + 0x0C) == 0) _d.setU32le(o + 0x0C, 1 << _firstPresent(species));
    } else {
      _d.setU32le(o + 0x0C, 0);
      _d[o + 0x5C] = 0;
    }
    onChange();
  }

  @override
  void setGenderSeen(int species, int gender, bool value) {
    final o = _ofs(species);
    if (o == null || gender > 1) return;
    final b = _genderBit(species, gender);
    _d[o + 0x0B] = value ? _d[o + 0x0B] | b : _d[o + 0x0B] & ~b;
    onChange();
  }

  @override
  void setFormSeen(int species, int form, bool value) {
    final o = _ofs(species);
    if (o == null || !formAvailable(species, form)) return;
    _d.setU32le(o + 4, _setMask(_d.u32le(o + 4), form, value));
    if (!value) {
      _d.setU32le(o, _setMask(_d.u32le(o), form, false));
      _d.setU32le(o + 0x0C, _setMask(_d.u32le(o + 0x0C), form, false));
    }
    onChange();
  }
}
