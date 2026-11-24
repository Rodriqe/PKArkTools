import 'dart:typed_data';

import '../crypto/pk_crypto.dart';
import '../formats/gc_container.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';
import 'pk_format.dart';
import 'pkm.dart';

/// Formato de entidad de GameCube.
enum GcKind {
  /// Pokémon Colosseum (312 bytes, big endian).
  ck3(312, 'ck3'),

  /// Pokémon XD (196 bytes, big endian).
  xk3(196, 'xk3');

  const GcKind(this.size, this.extension);
  final int size;
  final String extension;

  static GcKind? fromExtension(String ext) {
    final e = ext.toLowerCase().replaceFirst('.', '');
    for (final k in values) {
      if (k.extension == e) return k;
    }
    return null;
  }
}

/// Valor de purificación que Colosseum guarda en un Pokémon ya purificado
/// (PKHeX `CK3.Purified`).
const int kColoPurified = -100;

/// Datos de GameCube de un Pokémon que no caben en un PK3.
///
/// [raw] son los bytes CK3/XK3 originales (o los últimos escritos): al volver
/// a escribir el Pokémon solo se cambian los campos que se editaron en el
/// PK3, así que todo lo demás (campos de combate, apodo mostrado, glifos…)
/// se conserva byte a byte.
class GcExtra {
  GcExtra(this.kind, this.raw, {this.xdPurification = 0, this.xdPurified = false, this.xdSnagged = false});

  final GcKind kind;
  final Uint8List raw;

  /// XD: contador de purificación de la tabla de Pokémon oscuros del save.
  int xdPurification;

  /// XD: bit «purificado» de la tabla de Pokémon oscuros del save.
  bool xdPurified;

  /// XD: bit «capturado» de la tabla (solo lectura).
  bool xdSnagged;

  GcExtra clone() => GcExtra(kind, Uint8List.fromList(raw),
      xdPurification: xdPurification, xdPurified: xdPurified, xdSnagged: xdSnagged);

  bool get _ck3 => kind == GcKind.ck3;

  /// Id de Pokémon oscuro (0 = nunca fue oscuro).
  int get shadowId => raw.u16be(_ck3 ? 0xD8 : 0xBA);
  set shadowId(int v) => raw.setU16be(_ck3 ? 0xD8 : 0xBA, v);

  /// Medidor de corazón restante (Colosseum: [kColoPurified] si ya está purificado).
  int get purification => _ck3 ? _s32(raw.u32be(0xDC)) : xdPurification;
  set purification(int v) {
    if (_ck3) {
      _setU32be(raw, 0xDC, v);
    } else {
      xdPurification = v;
    }
  }

  /// Sigue siendo oscuro (no purificado).
  bool get isShadow => shadowId != 0 && (_ck3 ? purification != kColoPurified : !xdPurified);

  /// Fue oscuro y ya está purificado.
  bool get isPurified => shadowId != 0 && !isShadow;

  GcRegion get currentRegion => GcRegion.fromByte(raw[_ck3 ? 0x09 : 0x35]);
  GcRegion get originalRegion => GcRegion.fromByte(raw[_ck3 ? 0x0A : 0x36]);

  /// Marca el Pokémon como purificado (o vuelve a oscuro con [gauge]).
  void setPurified(bool purified, {int gauge = 0}) {
    if (shadowId == 0) return;
    if (_ck3) {
      purification = purified ? kColoPurified : gauge;
    } else {
      xdPurified = purified;
      xdPurification = purified ? 0 : gauge;
    }
  }
}

int _s32(int v) => v >= 0x80000000 ? v - 0x100000000 : v;

void _setU32be(Uint8List d, int o, int v) {
  d[o] = (v >> 24) & 0xFF;
  d[o + 1] = (v >> 16) & 0xFF;
  d[o + 2] = (v >> 8) & 0xFF;
  d[o + 3] = v & 0xFF;
}

/// Acceso por campos a un CK3/XK3 (offsets de PKHeX `CK3`/`XK3`, GPL-3.0).
class _Gc {
  _Gc(this.kind, this.d);
  final GcKind kind;
  final Uint8List d;
  bool get ck3 => kind == GcKind.ck3;

  int get speciesRaw => d.u16be(0);
  set speciesRaw(int v) => d.setU16be(0, v);
  int get pid => d.u32be(ck3 ? 0x04 : 0x28);
  set pid(int v) => _setU32be(d, ck3 ? 0x04 : 0x28, v);
  int get gcVersion => d[ck3 ? 0x08 : 0x34];
  set gcVersion(int v) => d[ck3 ? 0x08 : 0x34] = v;
  set currentRegion(int v) => d[ck3 ? 0x09 : 0x35] = v;
  set originalRegion(int v) => d[ck3 ? 0x0A : 0x36] = v;
  int get gcLanguage => d[ck3 ? 0x0B : 0x37];
  set gcLanguage(int v) => d[ck3 ? 0x0B : 0x37] = v;
  int get metLocation => d.u16be(ck3 ? 0x0C : 0x08);
  set metLocation(int v) => d.setU16be(ck3 ? 0x0C : 0x08, v);
  int get metLevel => d[0x0E];
  set metLevel(int v) => d[0x0E] = v;
  int get ball => d[0x0F];
  set ball(int v) => d[0x0F] = v;
  int get otGender => d[0x10];
  set otGender(int v) => d[0x10] = v;
  int get sid => d.u16be(ck3 ? 0x14 : 0x24);
  set sid(int v) => d.setU16be(ck3 ? 0x14 : 0x24, v);
  int get tid => d.u16be(ck3 ? 0x16 : 0x26);
  set tid(int v) => d.setU16be(ck3 ? 0x16 : 0x26, v);
  int get otOfs => ck3 ? 0x18 : 0x38;
  int get nickDisplayOfs => ck3 ? 0x2E : 0x4E;
  int get nickOfs => ck3 ? 0x44 : 0x64;
  int get exp => d.u32be(ck3 ? 0x5C : 0x20);
  set exp(int v) => _setU32be(d, ck3 ? 0x5C : 0x20, v);
  int get level => d[ck3 ? 0x60 : 0x11];
  set level(int v) => d[ck3 ? 0x60 : 0x11] = v;
  int _moveOfs(int i) => (ck3 ? 0x78 : 0x80) + i * 4;
  int move(int i) => d.u16be(_moveOfs(i));
  void setMove(int i, int v) => d.setU16be(_moveOfs(i), v);
  int pp(int i) => d[_moveOfs(i) + 2];
  void setPp(int i, int v) => d[_moveOfs(i) + 2] = v;
  int ppUps(int i) => d[_moveOfs(i) + 3];
  void setPpUps(int i, int v) => d[_moveOfs(i) + 3] = v;
  int get heldItem => d.u16be(ck3 ? 0x88 : 0x02);
  set heldItem(int v) => d.setU16be(ck3 ? 0x88 : 0x02, v);
  int get hpCurrent => d.u16be(ck3 ? 0x8A : 0x04);
  set hpCurrent(int v) => d.setU16be(ck3 ? 0x8A : 0x04, v);

  // Estadísticas en orden GC: PS máx., Atq, Def, AtqE, DefE, Vel.
  int stat(int i) => d.u16be((ck3 ? 0x8C : 0x90) + i * 2);
  void setStat(int i, int v) => d.setU16be((ck3 ? 0x8C : 0x90) + i * 2, v);
  int ev(int i) {
    final v = d.u16be((ck3 ? 0x98 : 0x9C) + i * 2);
    return v > 255 ? 255 : v;
  }

  void setEv(int i, int v) => d.setU16be((ck3 ? 0x98 : 0x9C) + i * 2, v & 0xFF);
  int iv(int i) {
    if (ck3) {
      final v = d.u16be(0xA4 + i * 2);
      return v > 31 ? 31 : v;
    }
    return d[0xA8 + i];
  }

  void setIv(int i, int v) => ck3 ? d.setU16be(0xA4 + i * 2, v & 0x1F) : d[0xA8 + i] = v & 0x1F;
  int get friendship => ck3 ? (d.u16be(0xB0) > 255 ? 255 : d.u16be(0xB0)) : d.u16be(0x06) & 0xFF;
  set friendship(int v) => d.setU16be(ck3 ? 0xB0 : 0x06, v & 0xFF);

  // Concurso: guapo, bello, lindo, listo, duro (y brillo aparte).
  int contest(int i) => d[(ck3 ? 0xB2 : 0xAE) + i];
  void setContest(int i, int v) => d[(ck3 ? 0xB2 : 0xAE) + i] = v;
  int ribbonCount(int i) => d[(ck3 ? 0xB7 : 0xB3) + i];
  void setRibbonCount(int i, int v) => d[(ck3 ? 0xB7 : 0xB3) + i] = v;
  int get sheen => d[ck3 ? 0xBC : 0x12];
  set sheen(int v) => d[ck3 ? 0xBC : 0x12] = v;

  /// Cintas de Gen 3 sin contador, en el orden de los bits 15–26 del PK3.
  bool ribbon(int i) => ck3 ? d[0xBD + i] == 1 : (d.u16be(0x7C) >> (15 - i)) & 1 == 1;
  void setRibbon(int i, bool v) {
    if (ck3) {
      d[0xBD + i] = v ? 1 : 0;
    } else {
      final r = d.u16be(0x7C);
      d.setU16be(0x7C, v ? r | (1 << (15 - i)) : r & ~(1 << (15 - i)));
    }
  }

  int get pokerusStrain => d[ck3 ? 0xCA : 0x13] & 0xF;
  set pokerusStrain(int v) => d[ck3 ? 0xCA : 0x13] = v & 0xF;
  int get pokerusDays {
    final v = d[ck3 ? 0xD0 : 0x15];
    return v >= 0x80 ? 0 : v;
  }

  set pokerusDays(int v) => d[ck3 ? 0xD0 : 0x15] = v == 0 ? 0xFF : v & 0xF;
  int get markingsRaw => d[ck3 ? 0xCF : 0x14];
  set markingsRaw(int v) => d[ck3 ? 0xCF : 0x14] = v;

  bool get isEgg => ck3 ? d[0xCB] == 1 : (d[0x1D] >> 7) & 1 == 1;
  set isEgg(bool v) => ck3 ? d[0xCB] = v ? 1 : 0 : d[0x1D] = (d[0x1D] & 0x7F) | (v ? 0x80 : 0);
  bool get abilityBit => ck3 ? d[0xCC] == 1 : (d[0x1D] >> 6) & 1 == 1;
  set abilityBit(bool v) => ck3 ? d[0xCC] = v ? 1 : 0 : d[0x1D] = (d[0x1D] & ~0x40) | (v ? 0x40 : 0);
  void markValid() => ck3 ? d[0xCD] = 0 : d[0x1D] = d[0x1D] & ~0x20;

  bool get fateful {
    if (ck3) return ((d[0xC9] >> 4) & 1) != (d[0xFB] & 1);
    return d[0x33] != 0 || d[0x30] == 1;
  }

  void setFateful(bool v, {required bool japanese}) {
    if (ck3) {
      d[0xC9] = (d[0xC9] & ~0x10) | (japanese && v ? 0x10 : 0);
      d[0xFB] = (d[0xFB] & ~1) | (!japanese && v ? 1 : 0);
      return;
    }
    if (d[0x33] != 0) {
      if (!v) d[0x33] = 0;
      return;
    }
    d[0x33] = (d[0x33] & ~1) | (v ? 1 : 0);
  }

  String string(int ofs) {
    final out = StringBuffer();
    for (var i = 0; i < 11; i++) {
      final c = d.u16be(ofs + i * 2);
      if (c == 0) break;
      out.writeCharCode(c);
    }
    return out.toString();
  }

  void setString(int ofs, String s, int max) {
    final r = s.runes.take(max).toList();
    for (var i = 0; i < 11; i++) {
      d.setU16be(ofs + i * 2, i < r.length ? r[i] & 0xFFFF : 0);
    }
  }
}

/// Conversión CK3/XK3 ↔ PK3 (PKHeX `CK3`/`XK3`, `ConvertToPK3`, GPL-3.0).
///
/// Los editores de GameCube trabajan con [Pkm] en formato PK3 (así sirven el
/// editor, la legalidad y la Dex de Gen 3) más [GcExtra] con lo propio de
/// GameCube.
abstract final class GcPkm {
  // Idioma GC → idioma principal (PKHeX `Language.GetMainLangIDfromGC`).
  static int mainLanguage(int gc) => switch (gc) { 3 => 5, 4 => 3, 5 => 4, 6 => 7, 7 => 6, _ => gc };
  static int gcLanguage(int main) => switch (main) { 5 => 3, 3 => 4, 4 => 5, 7 => 6, 6 => 7, _ => main };

  // Versión GC → versión de origen (PKHeX `GCVersion`).
  static int originVersion(int gc) => switch (gc) { 1 => 4, 2 => 5, 8 => 1, 9 => 2, 10 => 3, 11 => 15, _ => 0 };
  static int gcVersion(int v) => switch (v) { 4 => 1, 5 => 2, 1 => 8, 2 => 9, 3 => 10, 15 => 11, _ => 0 };

  // Orden GC (PS, Atq, Def, AtqE, DefE, Vel) → posición en el PK3 (PS, Atq, Def, Vel, AtqE, DefE).
  static const List<int> _gcToPk3 = [0, 1, 2, 4, 5, 3];

  static bool isPresent(Uint8List raw) => raw.length >= 2 && raw.u16be(0) != 0;

  /// PK3 descifrado (100 bytes, con la parte de equipo) equivalente a [raw].
  static Uint8List toPk3Bytes(GcKind kind, Uint8List raw) {
    final g = _Gc(kind, raw);
    final p = Uint8List(PkCrypto.size3Party);
    final lang = mainLanguage(g.gcLanguage);
    final jp = lang == 1;
    p.setU32le(0, g.pid);
    p.setU16le(4, g.tid);
    p.setU16le(6, g.sid);
    p.setRange(0x08, 0x12, StringCodec.encodeG3(g.string(g.nickOfs), 10, japanese: jp));
    p[0x12] = lang;
    p[0x13] = (g.speciesRaw != 0 ? 2 : 0) | (g.isEgg ? 4 : 0);
    p.setRange(0x14, 0x1B, StringCodec.encodeG3(g.string(g.otOfs), 7, japanese: jp));
    p[0x1B] = g.markingsRaw;
    p.setU16le(0x20, g.speciesRaw);
    p.setU16le(0x22, g.heldItem);
    p.setU32le(0x24, g.exp);
    var ups = 0;
    for (var i = 0; i < 4; i++) {
      ups |= (g.ppUps(i) & 3) << (2 * i);
      p.setU16le(0x2C + i * 2, g.move(i));
      p[0x34 + i] = g.pp(i);
    }
    p[0x28] = ups;
    p[0x29] = g.friendship;
    for (var i = 0; i < 6; i++) {
      p[0x38 + _gcToPk3[i]] = g.ev(i);
    }
    for (var i = 0; i < 5; i++) {
      p[0x3E + i] = g.contest(i);
    }
    p[0x43] = g.sheen;
    p[0x44] = (g.pokerusStrain << 4) | (g.pokerusDays & 0xF);
    p[0x45] = g.metLocation & 0xFF;
    p.setU16le(0x46,
        (g.metLevel & 0x7F) | ((originVersion(g.gcVersion) & 0xF) << 7) | ((g.ball & 0xF) << 11) | ((g.otGender & 1) << 15));
    var iv32 = 0;
    for (var i = 0; i < 6; i++) {
      iv32 |= (g.iv(i) & 0x1F) << (5 * _gcToPk3[i]);
    }
    if (g.isEgg) iv32 |= 1 << 30;
    if (g.abilityBit) iv32 |= 1 << 31;
    p.setU32le(0x48, iv32);
    var rib = 0;
    for (var i = 0; i < 5; i++) {
      rib |= (g.ribbonCount(i) & 7) << (3 * i);
    }
    for (var i = 0; i < 12; i++) {
      if (g.ribbon(i)) rib |= 1 << (15 + i);
    }
    if (g.fateful) rib |= 1 << 31;
    p.setU32le(0x4C, rib);
    p[0x54] = g.level;
    p.setU16le(0x56, g.hpCurrent);
    for (var i = 0; i < 6; i++) {
      p.setU16le(0x58 + _gcToPk3[i] * 2, g.stat(i));
    }
    p.setU16le(0x1C, PkCrypto.checksum3(p));
    return p;
  }

  /// Pokémon editable desde bytes CK3/XK3, o null si el hueco está vacío.
  static Pkm? read(GcKind kind, Uint8List raw, {int xdPurification = 0, bool xdPurified = false, bool xdSnagged = false}) {
    if (raw.length < kind.size || !isPresent(raw)) return null;
    final copy = raw.copyRange(0, kind.size);
    final pk = Pkm.fromDecrypted(PkFormat.pk3, toPk3Bytes(kind, copy));
    pk.gc = GcExtra(kind, copy, xdPurification: xdPurification, xdPurified: xdPurified, xdSnagged: xdSnagged);
    return pk;
  }

  /// Bytes CK3/XK3 de [pk] para un save de la región [region].
  ///
  /// Si [pk] viene de un save del mismo tipo ([Pkm.gc]) solo se escriben los
  /// campos que cambiaron respecto a sus bytes originales; si no (p. ej. un PK3
  /// de GBA), se crea la entidad entera con la región del save.
  static Uint8List write(Pkm pk, GcKind kind, {required GcRegion region}) {
    if (pk.format != PkFormat.pk3) throw ArgumentError('Solo PK3 se puede guardar en Colosseum/XD.');
    final same = pk.gc != null && pk.gc!.kind == kind;
    final out = same ? Uint8List.fromList(pk.gc!.raw) : Uint8List(kind.size);
    final g = _Gc(kind, out);
    final p = pk.data;
    final b = same ? toPk3Bytes(kind, pk.gc!.raw) : null;
    bool changed(int ofs, int len) {
      if (b == null) return true;
      for (var i = ofs; i < ofs + len; i++) {
        if (p[i] != b[i]) return true;
      }
      return false;
    }

    if (!same) {
      g.currentRegion = region.index;
      g.originalRegion = region.index;
    }
    final lang = p[0x12];
    final jp = lang == 1;
    if (changed(0x12, 1)) g.gcLanguage = gcLanguage(lang);
    if (changed(0, 4)) g.pid = p.u32le(0);
    if (changed(4, 2)) g.tid = p.u16le(4);
    if (changed(6, 2)) g.sid = p.u16le(6);
    String nick(Uint8List d) => StringCodec.decodeG3(d, 0x08, 10, japanese: d[0x12] == 1);
    String ot(Uint8List d) => StringCodec.decodeG3(d, 0x14, 7, japanese: d[0x12] == 1);
    if (b == null || nick(p) != nick(b)) {
      g.setString(g.nickOfs, nick(p), 10);
      out.setRange(g.nickDisplayOfs, g.nickDisplayOfs + 22, out, g.nickOfs);
      if (region == GcRegion.ntscJ) out.fillRange(g.nickDisplayOfs + 10, g.nickDisplayOfs + 22, 0);
    }
    if (b == null || ot(p) != ot(b)) g.setString(g.otOfs, ot(p), 10);
    if (changed(0x1B, 1)) g.markingsRaw = p[0x1B];
    if (changed(0x20, 2)) g.speciesRaw = p.u16le(0x20);
    if (changed(0x22, 2)) g.heldItem = p.u16le(0x22);
    if (changed(0x24, 4)) g.exp = p.u32le(0x24);
    for (var i = 0; i < 4; i++) {
      if (b == null || ((p[0x28] >> (2 * i)) & 3) != ((b[0x28] >> (2 * i)) & 3)) g.setPpUps(i, (p[0x28] >> (2 * i)) & 3);
      if (changed(0x2C + i * 2, 2)) g.setMove(i, p.u16le(0x2C + i * 2));
      if (changed(0x34 + i, 1)) g.setPp(i, p[0x34 + i]);
    }
    if (changed(0x29, 1)) g.friendship = p[0x29];
    for (var i = 0; i < 6; i++) {
      if (changed(0x38 + _gcToPk3[i], 1)) g.setEv(i, p[0x38 + _gcToPk3[i]]);
    }
    for (var i = 0; i < 5; i++) {
      if (changed(0x3E + i, 1)) g.setContest(i, p[0x3E + i]);
    }
    if (changed(0x43, 1)) g.sheen = p[0x43];
    if (b == null || (p[0x44] >> 4) != (b[0x44] >> 4)) g.pokerusStrain = p[0x44] >> 4;
    if (b == null || (p[0x44] & 0xF) != (b[0x44] & 0xF)) g.pokerusDays = p[0x44] & 0xF;
    if (changed(0x45, 1)) g.metLocation = p[0x45];
    final o = p.u16le(0x46), ob = b?.u16le(0x46);
    if (ob == null || (o & 0x7F) != (ob & 0x7F)) g.metLevel = o & 0x7F;
    if (ob == null || ((o >> 7) & 0xF) != ((ob >> 7) & 0xF)) g.gcVersion = gcVersion((o >> 7) & 0xF);
    if (ob == null || ((o >> 11) & 0xF) != ((ob >> 11) & 0xF)) g.ball = (o >> 11) & 0xF;
    if (ob == null || (o >> 15) != (ob >> 15)) g.otGender = o >> 15;
    final iv = p.u32le(0x48), ivb = b?.u32le(0x48);
    for (var i = 0; i < 6; i++) {
      final s = 5 * _gcToPk3[i];
      if (ivb == null || ((iv >> s) & 0x1F) != ((ivb >> s) & 0x1F)) g.setIv(i, (iv >> s) & 0x1F);
    }
    final egg = (iv >> 30) & 1 == 1 || (p[0x13] & 4) != 0;
    final eggB = b == null ? null : ((ivb! >> 30) & 1 == 1 || (b[0x13] & 4) != 0);
    if (egg != eggB) g.isEgg = egg;
    if (ivb == null || (iv >> 31) != (ivb >> 31)) g.abilityBit = (iv >> 31) == 1;
    final rib = p.u32le(0x4C), ribB = b?.u32le(0x4C);
    for (var i = 0; i < 5; i++) {
      if (ribB == null || ((rib >> (3 * i)) & 7) != ((ribB >> (3 * i)) & 7)) g.setRibbonCount(i, (rib >> (3 * i)) & 7);
    }
    for (var i = 0; i < 12; i++) {
      final bit = 15 + i;
      if (ribB == null || ((rib >> bit) & 1) != ((ribB >> bit) & 1)) g.setRibbon(i, (rib >> bit) & 1 == 1);
    }
    if (ribB == null || (rib >> 31) != (ribB >> 31)) g.setFateful(rib >> 31 == 1, japanese: jp);
    if (changed(0x54, 1)) g.level = p[0x54];
    if (changed(0x56, 2)) g.hpCurrent = p.u16le(0x56);
    for (var i = 0; i < 6; i++) {
      final at = 0x58 + _gcToPk3[i] * 2;
      if (changed(at, 2)) g.setStat(i, p.u16le(at));
    }
    if (!same) g.markValid();
    return out;
  }

  /// Copia de [pk] tal como llega a un juego de GBA (PKHeX `XK3.ConvertToPK3`):
  /// sin datos de GameCube y, si viene de XD, con la marca de encuentro
  /// fatídico (obediencia) y la Cinta Nacional si fue oscuro.
  static Pkm toGba(Pkm pk) {
    final gc = pk.gc;
    final out = pk.clone()..gc = null;
    if (gc == null || gc.kind != GcKind.xk3 || out.version != 15) return out;
    final rib = out.data.u32le(0x4C);
    if (gc.shadowId != 0) {
      out.data.setU32le(0x4C, rib | (1 << 24) | 0x80000000);
    } else if (const {0, 16, 90, 91, 92}.contains(out.metLocation)) {
      out.data.setU32le(0x4C, rib | 0x80000000);
    }
    out.refreshChecksum();
    return out;
  }

  /// Archivo suelto `.ck3`/`.xk3` (bytes tal cual, big endian, sin cifrar).
  static Uint8List toFile(Pkm pk, GcKind kind, {GcRegion region = GcRegion.ntscU}) =>
      write(pk, kind, region: pk.gc?.currentRegion ?? region);

  /// Importa un `.ck3`/`.xk3`.
  static Pkm? fromFile(GcKind kind, Uint8List bytes) {
    if (bytes.length != kind.size) return null;
    return read(kind, bytes);
  }
}
