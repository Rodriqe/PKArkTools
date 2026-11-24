import 'dart:typed_data';

import '../crypto/gc_crypto.dart';
import '../crypto/pk_crypto.dart';
import '../util/bytes.dart';

/// Pokémon Battle Revolution (Wii): `PbrSaveData` descifrado de la NAND.
///
/// 0x380000 bytes en dos mitades de 0x1C0000, cada una cifrada con Genius
/// Sonority (claves en +0, datos desde +8). La mitad válida con el contador
/// (+0x4C) más alto tiene 4 perfiles de 0x6FF00; las sumas son 16 contadores
/// de bits de palabras big endian (cabecera 0–0x100 en +8 y la mitad entera
/// al final). Portado de PKHeX `SAV4BR` y `BK4` (GPL-3.0).
class BrData {
  BrData._(this.encrypted, this.plain, this.partition, this.counter);

  static const int size = 0x380000;
  static const int half = 0x1C0000;
  static const int slotSize = 0x6FF00;
  static const int profiles = 4;

  /// Descifra y elige la mitad activa; null si ninguna mitad tiene sumas correctas.
  static BrData? open(Uint8List d) {
    if (d.length != size) return null;
    final plain = Uint8List.fromList(d);
    for (var o = 0; o < size; o += half) {
      final h = Uint8List.sublistView(plain, o, o + half);
      GeniusCrypto.decrypt(h, 8, half, GeniusCrypto.readKeys(h, 0));
    }
    final first = plain.u32be(0x4C), second = plain.u32be(half + 0x4C);
    final v1 = halfValid(plain, 0), v2 = halfValid(plain, half);
    if (v2 && (!v1 || second > first)) return BrData._(d, plain, 1, second);
    if (v1) return BrData._(d, plain, 0, first);
    return null;
  }

  final Uint8List encrypted;
  final Uint8List plain;
  final int partition;
  final int counter;

  int slotOffset(int profile) => partition * half + profile * slotSize;

  /// Copia de trabajo de un perfil.
  Uint8List profile(int i) => plain.copyRange(slotOffset(i), slotSize);

  static List<int> _sums(Uint8List d, int start, int len, int skipAt) {
    final c = List<int>.filled(16, 0);
    for (var i = start; i < start + len; i += 2) {
      final v = (i >= skipAt && i < skipAt + 64) ? 0 : d.u16be(i);
      if (v == 0) continue;
      for (var b = 0; b < 16; b++) {
        if ((v >> b) & 1 == 1) c[b]++;
      }
    }
    return c;
  }

  static bool _verify(Uint8List d, int base, int len, int at) {
    final c = _sums(d, base, len, at);
    for (var i = 0; i < 16; i++) {
      if (d.u32be(at + i * 4) != c[i]) return false;
    }
    return true;
  }

  static void _set(Uint8List d, int base, int len, int at) {
    d.fillRange(at, at + 64, 0);
    final c = _sums(d, base, len, at);
    for (var i = 0; i < 16; i++) {
      final o = at + i * 4;
      d[o] = c[i] >> 24;
      d[o + 1] = (c[i] >> 16) & 0xFF;
      d[o + 2] = (c[i] >> 8) & 0xFF;
      d[o + 3] = c[i] & 0xFF;
    }
  }

  static void _setHalf(Uint8List d, int base) {
    _set(d, base, 0x100, base + 8);
    _set(d, base, half, base + half - 0x80);
  }

  static bool halfValid(Uint8List d, int base) => _verify(d, base, 0x100, base + 8) && _verify(d, base, half, base + half - 0x80);

  /// Archivo con los perfiles [changed] escritos, sumas recalculadas y cifrado.
  Uint8List build(Map<int, Uint8List> changed) {
    final out = Uint8List.fromList(plain);
    changed.forEach((i, data) => out.setRange(slotOffset(i), slotOffset(i) + slotSize, data));
    _setHalf(out, partition * half);
    for (var o = 0; o < size; o += half) {
      final h = Uint8List.sublistView(out, o, o + half);
      GeniusCrypto.encrypt(h, 8, half, GeniusCrypto.readKeys(h, 0));
    }
    return out;
  }

  // ------------------------------------------------------------ perfil

  /// Nombre del entrenador del perfil (UTF-16 BE, fin 0).
  static String otName(Uint8List p) => utf16be(p, 0x390, 8);

  static String utf16be(Uint8List d, int ofs, int chars) {
    final out = StringBuffer();
    for (var i = 0; i < chars; i++) {
      final c = d.u16be(ofs + i * 2);
      if (c == 0 || c == 0xFFFF) break;
      out.writeCharCode(c);
    }
    return out.toString();
  }

  static int tid(Uint8List p) => (p[0x12867] << 8) | p[0x12860];
  static int sid(Uint8List p) => (p[0x12865] << 8) | p[0x12866];
  static int money(Uint8List p) => (p[0x12861] << 16) | (p[0x12862] << 8) | p[0x12863];
  static Duration playTime(Uint8List p) {
    final s = ByteData.sublistView(p).getFloat64(0x388);
    return s.isFinite && s >= 0 ? Duration(milliseconds: (s * 1000).round()) : Duration.zero;
  }

  static const int partyOfs = 0x44C;
  static const int partySlot = 220;
  static const int boxOfs = 0x978;
  static const int boxCount = 18;
  static const int boxNameOfs = 0x58674;
}

/// BK4 (Battle Revolution, big endian, sin cifrar en reposo) ↔ PK4.
abstract final class Bk4 {
  static int _ivBk4ToPk4(int v) {
    final spd = (v >> 2) & 31, spa = (v >> 7) & 31, spe = (v >> 12) & 31;
    final def = (v >> 17) & 31, atk = (v >> 22) & 31, hp = (v >> 27) & 31;
    final nick = v & 1, egg = (v >> 1) & 1;
    return hp | (atk << 5) | (def << 10) | (spe << 15) | (spa << 20) | (spd << 25) | (egg << 30) | (nick << 31);
  }

  static int _ivPk4ToBk4(int v) {
    final hp = v & 31, atk = (v >> 5) & 31, def = (v >> 10) & 31, spe = (v >> 15) & 31;
    final spa = (v >> 20) & 31, spd = (v >> 25) & 31, egg = (v >> 30) & 1, nick = (v >> 31) & 1;
    return (spd << 2) | (spa << 7) | (spe << 12) | (def << 17) | (atk << 22) | (hp << 27) | nick | (egg << 1);
  }

  // Campos de 16 y 32 bits (sin contar 0x04/0x06, propios de cada formato).
  static const List<int> _u16 = [
    0x08, 0x0A, 0x28, 0x2A, 0x2C, 0x2E, 0x42, 0x44, 0x46, //
    0x48, 0x4A, 0x4C, 0x4E, 0x50, 0x52, 0x54, 0x56, 0x58, 0x5A, 0x5C,
    0x68, 0x6A, 0x6C, 0x6E, 0x70, 0x72, 0x74, 0x76, 0x7E, 0x80,
  ];
  static const List<int> _u32 = [0x00, 0x0C, 0x10, 0x24, 0x3C, 0x60, 0x64];
  static const List<int> _partyU16 = [0x8E, 0x90, 0x92, 0x94, 0x96, 0x98, 0x9A];

  static void _swap(Uint8List src, Uint8List dst, int o, int n) {
    for (var i = 0; i < n; i++) {
      dst[o + i] = src[o + n - 1 - i];
    }
  }

  static void _common(Uint8List s, Uint8List d, {required bool toPk4}) {
    for (var o = 0x14; o < 0x24; o++) {
      d[o] = s[o];
    }
    for (var o = 0x30; o < 0x38; o++) {
      d[o] = s[o];
    }
    d[0x41] = s[0x41];
    d[0x5E] = s[0x5E];
    d[0x5F] = s[0x5F];
    for (var o = 0x78; o < 0x7E; o++) {
      d[o] = s[o];
    }
    for (final o in [0x82, 0x83, 0x85, 0x86, 0x87]) {
      d[o] = s[o];
    }
    for (final o in _u16) {
      _swap(s, d, o, 2);
    }
    for (final o in _u32) {
      _swap(s, d, o, 4);
    }
    final iv = toPk4 ? _ivBk4ToPk4(s.u32be(0x38)) : _ivPk4ToBk4(s.u32le(0x38));
    if (toPk4) {
      d.setU32le(0x38, iv);
      final b = s[0x40];
      d[0x40] = (b >> 7) | (((b >> 5) & 3) << 1) | ((b & 31) << 3);
      d[0x84] = (s[0x84] >> 1) | ((s[0x84] & 1) << 7);
    } else {
      d[0x38] = iv >> 24;
      d[0x39] = (iv >> 16) & 0xFF;
      d[0x3A] = (iv >> 8) & 0xFF;
      d[0x3B] = iv & 0xFF;
      final b = s[0x40];
      d[0x40] = ((b & 1) << 7) | (((b >> 1) & 3) << 5) | (b >> 3);
      d[0x84] = ((s[0x84] & 0x7F) << 1) | (s[0x84] >> 7);
    }
  }

  /// PK4 descifrado (236 bytes, con la parte de equipo si [bk4] la trae) desde un BK4 almacenado (barajado).
  static Uint8List toPk4(Uint8List bk4) {
    final s = Uint8List(220)..setRange(0, bk4.length.clamp(0, 220), bk4);
    s.setRange(0, 136, PkCrypto.unshuffle4BE(s.copyRange(0, 136)));
    final d = Uint8List(PkCrypto.size4Party);
    _common(s, d, toPk4: true);
    if (bk4.length >= 220) {
      _swap(s, d, 0x88, 4);
      d[0x8C] = s[0x8C];
      d[0x8D] = s[0x8D];
      for (final o in _partyU16) {
        _swap(s, d, o, 2);
      }
    }
    return d;
  }

  /// BK4 (barajado, [size] 136 o 220) desde un PK4 descifrado; parte de
  /// [base] (BK4 original) para conservar la marca de estado y el resto.
  static Uint8List fromPk4(Uint8List pk4, {Uint8List? base, int size = 136}) {
    final d = Uint8List(220);
    if (base != null) {
      d.setRange(0, base.length.clamp(0, 220), base);
      d.setRange(0, 136, PkCrypto.unshuffle4BE(d.copyRange(0, 136)));
    }
    _common(pk4, d, toPk4: false);
    if (size >= 220) {
      _swap(pk4, d, 0x88, 4);
      d[0x8C] = pk4[0x8C];
      d[0x8D] = pk4[0x8D];
      for (final o in _partyU16) {
        _swap(pk4, d, o, 2);
      }
    }
    // Estado «descifrado» de caja (y de equipo) que pone PKHeX al escribir.
    var sanity = d.u16be(4) | 0x4000;
    sanity = size >= 220 ? sanity | 0x8000 : sanity & ~0x8000;
    d.setU16be(4, sanity);
    var c = 0;
    for (var o = 8; o < 136; o += 2) {
      c += d.u16be(o);
    }
    d.setU16be(6, c & 0xFFFF);
    final out = d.copyRange(0, size);
    out.setRange(0, 136, PkCrypto.shuffle4BE(out.copyRange(0, 136)));
    return out;
  }

  /// BK4 presente (PKHeX `IsPresent`: especie o PID distintos de 0).
  static bool isPresent(Uint8List bk4) =>
      bk4.u32be(0) != 0 || PkCrypto.unshuffle4BE(bk4.copyRange(0, 136)).u16be(8) != 0;
}

/// Acceso a las sumas para los generadores sintéticos.
abstract final class BrDataTesting {
  static void setSums(Uint8List plain, int base) => BrData._setHalf(plain, base);
}
