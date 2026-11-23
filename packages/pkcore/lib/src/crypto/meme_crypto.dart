import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../model/game.dart';

/// MemeCrypto V1: firma de los saves de Sol/Luna y Ultrasol/Ultraluna.
///
/// El bloque 36 del save ("TurtleSalmonSave") guarda en `+0x100` una región
/// de 0x80 bytes: un SHA-256 de la tabla de checksums firmado con la clave
/// `PokedexAndSaveFile`. El juego calcula el CRC del bloque 36 con esa región
/// a cero y **después** escribe la firma, así que en un save real el CRC del
/// bloque 36 nunca coincide si no se pone antes la región a cero (PKHeX
/// `SAV7.ClearMemeCrypto`).
///
/// Portado de PKHeX.Core `MemeCrypto.cs` y `MemeKey.cs` (GPL-3.0); solo la
/// clave de saves (la única que PKHeX sabe firmar).
abstract final class MemeCrypto {
  static const int signatureLength = 0x60;

  /// Longitud de la región de firma del save.
  static const int saveSignatureLength = 0x80;

  /// Offset de la región de firma en un save de SM/USUM, o `null` si el juego no la usa.
  static int? saveSignatureOffset(GameVersion game) => switch (game) {
        GameVersion.sunMoon => 0x6BA00 + 0x100,
        GameVersion.ultraSunUltraMoon => 0x6C000 + 0x100,
        _ => null,
      };

  static int _checksumTableLength(GameVersion game) => game == GameVersion.ultraSunUltraMoon ? 0x150 : 0x140;

  /// Pone a cero la región de firma de un save de SM/USUM (sin efecto en otros juegos).
  static void clearSave(Uint8List d, GameVersion game) {
    final ofs = saveSignatureOffset(game);
    if (ofs == null || ofs + saveSignatureLength > d.length) return;
    d.fillRange(ofs, ofs + saveSignatureLength, 0);
  }

  /// Firma un save de SM/USUM en el sitio (PKHeX `MemeCrypto.SignInPlace`):
  /// SHA-256 de la tabla de checksums en los primeros 0x20 bytes de la región
  /// (el resto a cero) y firma de los 0x80 bytes.
  static void signSave(Uint8List d, GameVersion game) {
    final ofs = saveSignatureOffset(game);
    if (ofs == null || ofs + saveSignatureLength > d.length) return;
    final table = d.length - 0x200;
    final region = Uint8List(saveSignatureLength);
    region.setRange(0, 0x20, sha256.convert(Uint8List.sublistView(d, table, table + _checksumTableLength(game))).bytes);
    _sign(region);
    d.setRange(ofs, ofs + saveSignatureLength, region);
  }

  /// `true` si la firma del save de SM/USUM corresponde a su tabla de checksums.
  /// Para otros juegos devuelve `true` (no hay firma que comprobar).
  static bool isSaveSignatureValid(Uint8List d, GameVersion game) {
    final ofs = saveSignatureOffset(game);
    if (ofs == null) return true;
    if (ofs + saveSignatureLength > d.length) return false;
    final region = Uint8List.fromList(Uint8List.sublistView(d, ofs, ofs + saveSignatureLength));
    final plain = _verify(region);
    if (plain == null) return false;
    final table = d.length - 0x200;
    final hash = sha256.convert(Uint8List.sublistView(d, table, table + _checksumTableLength(game))).bytes;
    for (var i = 0; i < 0x20; i++) {
      if (plain[i] != hash[i]) return false;
    }
    return true;
  }

  // ------------------------------------------------------------------ firma

  static void _sign(Uint8List data) {
    final key = _MemeKey.saveFile;
    final payloadEnd = data.length - 8;
    final h = sha1.convert(Uint8List.sublistView(data, 0, payloadEnd)).bytes;
    data.setRange(payloadEnd, data.length, h);
    key.aesEncrypt(data);
    final sigStart = data.length - signatureLength;
    data[sigStart] &= 0x7F;
    key.rsa(data, sigStart, key.d);
  }

  /// Devuelve los datos descifrados si la firma es válida; `null` si no.
  static Uint8List? _verify(Uint8List input) {
    final key = _MemeKey.saveFile;
    final sigStart = input.length - signatureLength;
    final sig = Uint8List.fromList(Uint8List.sublistView(input, sigStart));
    key.rsa(sig, 0, key.e);
    for (final variant in [false, true]) {
      final out = Uint8List.fromList(input);
      out.setRange(sigStart, out.length, sig);
      if (variant) out[sigStart] |= 0x80;
      key.aesDecrypt(out);
      final h = sha1.convert(Uint8List.sublistView(out, 0, out.length - 8)).bytes;
      var ok = true;
      for (var i = 0; i < 8; i++) {
        if (h[i] != out[out.length - 8 + i]) {
          ok = false;
          break;
        }
      }
      if (ok) return out;
    }
    return null;
  }
}

class _MemeKey {
  _MemeKey(this.der, List<int> dBytes)
      : n = _big(der.sublist(0x18, 0x18 + 0x61)),
        e = _big(der.sublist(0x7B, 0x7B + 3)),
        d = _big(dBytes);

  static final saveFile = _MemeKey(_der3, _d3);

  final List<int> der;
  final BigInt n, e, d;

  static BigInt _big(List<int> bytes) {
    var r = BigInt.zero;
    for (final b in bytes) {
      r = (r << 8) | BigInt.from(b);
    }
    return r;
  }

  /// `data[start..]` (0x60 bytes, big-endian) ← `data^exp mod n`.
  void rsa(Uint8List data, int start, BigInt exp) {
    final m = _big(Uint8List.sublistView(data, start, start + MemeCrypto.signatureLength));
    var r = m.modPow(exp, n);
    for (var i = start + MemeCrypto.signatureLength - 1; i >= start; i--) {
      data[i] = (r & BigInt.from(0xFF)).toInt();
      r >>= 8;
    }
  }

  _Aes128 _aes(Uint8List data) {
    final payload = Uint8List.sublistView(data, 0, data.length - MemeCrypto.signatureLength);
    final h = sha1.convert([...der, ...payload]).bytes;
    return _Aes128(Uint8List.fromList(h.sublist(0, 16)));
  }

  void aesEncrypt(Uint8List data) {
    final aes = _aes(data);
    final sig = Uint8List.sublistView(data, data.length - MemeCrypto.signatureLength);
    final temp = Uint8List(16);
    final nextXor = Uint8List(16);
    for (var i = 0; i < sig.length; i += 16) {
      final slice = Uint8List.sublistView(sig, i, i + 16);
      _xor(slice, temp);
      aes.encrypt(slice);
      temp.setAll(0, slice);
    }
    _xor(temp, Uint8List.sublistView(sig, 0, 16));
    _subKey(temp, nextXor);
    for (var i = 0; i < sig.length; i += 16) {
      _xor(Uint8List.sublistView(sig, i, i + 16), nextXor);
    }
    temp.fillRange(0, 16, 0);
    for (var i = sig.length - 16; i >= 0; i -= 16) {
      final slice = Uint8List.sublistView(sig, i, i + 16);
      nextXor.setAll(0, slice);
      aes.encrypt(slice);
      _xor(slice, temp);
      temp.setAll(0, nextXor);
    }
  }

  void aesDecrypt(Uint8List data) {
    final aes = _aes(data);
    final sig = Uint8List.sublistView(data, data.length - MemeCrypto.signatureLength);
    final temp = Uint8List(16);
    final nextXor = Uint8List(16);
    for (var i = sig.length - 16; i >= 0; i -= 16) {
      final slice = Uint8List.sublistView(sig, i, i + 16);
      _xor(temp, slice);
      aes.decrypt(temp);
      slice.setAll(0, temp);
    }
    _xor(temp, Uint8List.sublistView(sig, sig.length - 16));
    _subKey(temp, nextXor);
    for (var i = 0; i < sig.length; i += 16) {
      _xor(Uint8List.sublistView(sig, i, i + 16), nextXor);
    }
    nextXor.fillRange(0, 16, 0);
    for (var i = 0; i < sig.length; i += 16) {
      final slice = Uint8List.sublistView(sig, i, i + 16);
      temp.setAll(0, slice);
      aes.decrypt(slice);
      _xor(slice, nextXor);
      nextXor.setAll(0, temp);
    }
  }

  static void _xor(Uint8List a, Uint8List b) {
    for (var i = 0; i < 16; i++) {
      a[i] ^= b[i];
    }
  }

  static void _subKey(Uint8List t, Uint8List k) {
    for (var i = 0; i < 16; i += 2) {
      final b1 = t[i], b2 = t[i + 1];
      k[i] = ((2 * b1) + (b2 >> 7)) & 0xFF;
      k[i + 1] = (2 * b2) & 0xFF;
      if (i + 2 < 16) k[i + 1] = (k[i + 1] + (t[i + 2] >> 7)) & 0xFF;
    }
    if ((t[0] & 0x80) != 0) k[15] ^= 0x87;
  }

  static const _der3 = [
    0x30, 0x7C, 0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, //
    0x00, 0x03, 0x6B, 0x00, 0x30, 0x68, 0x02, 0x61, 0x00, 0xB6, 0x1E, 0x19, 0x20, 0x91, 0xF9, 0x0A, //
    0x8F, 0x76, 0xA6, 0xEA, 0xAA, 0x9A, 0x3C, 0xE5, 0x8C, 0x86, 0x3F, 0x39, 0xAE, 0x25, 0x3F, 0x03, //
    0x78, 0x16, 0xF5, 0x97, 0x58, 0x54, 0xE0, 0x7A, 0x9A, 0x45, 0x66, 0x01, 0xE7, 0xC9, 0x4C, 0x29, //
    0x75, 0x9F, 0xE1, 0x55, 0xC0, 0x64, 0xED, 0xDF, 0xA1, 0x11, 0x44, 0x3F, 0x81, 0xEF, 0x1A, 0x42, //
    0x8C, 0xF6, 0xCD, 0x32, 0xF9, 0xDA, 0xC9, 0xD4, 0x8E, 0x94, 0xCF, 0xB3, 0xF6, 0x90, 0x12, 0x0E, //
    0x8E, 0x6B, 0x91, 0x11, 0xAD, 0xDA, 0xF1, 0x1E, 0x7C, 0x96, 0x20, 0x8C, 0x37, 0xC0, 0x14, 0x3F, //
    0xF2, 0xBF, 0x3D, 0x7E, 0x83, 0x11, 0x41, 0xA9, 0x73, 0x02, 0x03, 0x01, 0x00, 0x01, //
  ];

  static const _d3 = [
    0x00, 0x77, 0x54, 0x55, 0x66, 0x8F, 0xFF, 0x3C, 0xBA, 0x30, 0x26, 0xC2, 0xD0, 0xB2, 0x6B, 0x80, //
    0x85, 0x89, 0x59, 0x58, 0x34, 0x11, 0x57, 0xAE, 0xB0, 0x3B, 0x6B, 0x04, 0x95, 0xEE, 0x57, 0x80, //
    0x3E, 0x21, 0x86, 0xEB, 0x6C, 0xB2, 0xEB, 0x62, 0xA7, 0x1D, 0xF1, 0x8A, 0x3C, 0x9C, 0x65, 0x79, //
    0x07, 0x76, 0x70, 0x96, 0x1B, 0x3A, 0x61, 0x02, 0xDA, 0xBE, 0x5A, 0x19, 0x4A, 0xB5, 0x8C, 0x32, //
    0x50, 0xAE, 0xD5, 0x97, 0xFC, 0x78, 0x97, 0x8A, 0x32, 0x6D, 0xB1, 0xD7, 0xB2, 0x8D, 0xCC, 0xCB, //
    0x2A, 0x3E, 0x01, 0x4E, 0xDB, 0xD3, 0x97, 0xAD, 0x33, 0xB8, 0xF2, 0x8C, 0xD5, 0x25, 0x05, 0x42, //
    0x51, //
  ];
}

/// AES-128 en modo ECB (un bloque de 16 bytes en el sitio). Implementación
/// directa de FIPS-197, suficiente para MemeCrypto (unos pocos bloques).
class _Aes128 {
  _Aes128(Uint8List key) : _rk = _expand(key);

  final Uint8List _rk; // 11 claves de ronda × 16 bytes

  static final Uint8List _sbox = _makeSbox();
  static final Uint8List _inv = () {
    final inv = Uint8List(256);
    for (var i = 0; i < 256; i++) {
      inv[_sbox[i]] = i;
    }
    return inv;
  }();

  static int _mul(int a, int b) {
    var r = 0;
    while (b != 0) {
      if (b & 1 != 0) r ^= a;
      a = ((a << 1) ^ ((a & 0x80) != 0 ? 0x1B : 0)) & 0xFF;
      b >>= 1;
    }
    return r;
  }

  static Uint8List _makeSbox() {
    final s = Uint8List(256);
    for (var i = 0; i < 256; i++) {
      // Inverso multiplicativo en GF(2^8) (0 → 0).
      var inv = 0;
      if (i != 0) {
        for (var j = 1; j < 256; j++) {
          if (_mul(i, j) == 1) {
            inv = j;
            break;
          }
        }
      }
      var x = inv;
      var y = inv;
      for (var k = 0; k < 4; k++) {
        y = ((y << 1) | (y >> 7)) & 0xFF;
        x ^= y;
      }
      s[i] = x ^ 0x63;
    }
    return s;
  }

  static Uint8List _expand(Uint8List key) {
    final w = Uint8List(176)..setAll(0, key);
    var rcon = 1;
    for (var i = 16; i < 176; i += 4) {
      var t0 = w[i - 4], t1 = w[i - 3], t2 = w[i - 2], t3 = w[i - 1];
      if (i % 16 == 0) {
        final tmp = t0;
        t0 = _sbox[t1] ^ rcon;
        t1 = _sbox[t2];
        t2 = _sbox[t3];
        t3 = _sbox[tmp];
        rcon = _mul(rcon, 2);
      }
      w[i] = w[i - 16] ^ t0;
      w[i + 1] = w[i - 15] ^ t1;
      w[i + 2] = w[i - 14] ^ t2;
      w[i + 3] = w[i - 13] ^ t3;
    }
    return w;
  }

  void _addRoundKey(Uint8List s, int round) {
    for (var i = 0; i < 16; i++) {
      s[i] ^= _rk[round * 16 + i];
    }
  }

  static void _shiftRows(Uint8List s, {bool inverse = false}) {
    final t = Uint8List.fromList(s);
    for (var c = 0; c < 4; c++) {
      for (var r = 0; r < 4; r++) {
        final src = inverse ? (c - r + 4) % 4 : (c + r) % 4;
        s[c * 4 + r] = t[src * 4 + r];
      }
    }
  }

  static void _mixColumns(Uint8List s, {bool inverse = false}) {
    final m = inverse ? const [14, 11, 13, 9] : const [2, 3, 1, 1];
    for (var c = 0; c < 4; c++) {
      final a = [s[c * 4], s[c * 4 + 1], s[c * 4 + 2], s[c * 4 + 3]];
      for (var r = 0; r < 4; r++) {
        s[c * 4 + r] = _mul(a[0], m[(4 - r) % 4]) ^
            _mul(a[1], m[(5 - r) % 4]) ^
            _mul(a[2], m[(6 - r) % 4]) ^
            _mul(a[3], m[(7 - r) % 4]);
      }
    }
  }

  void encrypt(Uint8List s) {
    _addRoundKey(s, 0);
    for (var round = 1; round <= 10; round++) {
      for (var i = 0; i < 16; i++) {
        s[i] = _sbox[s[i]];
      }
      _shiftRows(s);
      if (round != 10) _mixColumns(s);
      _addRoundKey(s, round);
    }
  }

  void decrypt(Uint8List s) {
    _addRoundKey(s, 10);
    for (var round = 9; round >= 0; round--) {
      _shiftRows(s, inverse: true);
      for (var i = 0; i < 16; i++) {
        s[i] = _inv[s[i]];
      }
      _addRoundKey(s, round);
      if (round != 0) _mixColumns(s, inverse: true);
    }
  }
}
