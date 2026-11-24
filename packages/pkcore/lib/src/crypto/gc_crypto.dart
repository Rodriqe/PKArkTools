import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha1;

import '../util/bytes.dart';

int _s32(int v) {
  v &= 0xFFFFFFFF;
  return v >= 0x80000000 ? v - 0x100000000 : v;
}

int _u32be(Uint8List d, int o) => d.u32be(o);

void _setU32be(Uint8List d, int o, int v) {
  d[o] = (v >> 24) & 0xFF;
  d[o + 1] = (v >> 16) & 0xFF;
  d[o + 2] = (v >> 8) & 0xFF;
  d[o + 3] = v & 0xFF;
}

/// Cifrado y sumas de Pokémon Colosseum. Portado de PKHeX `ColoCrypto` (GPL-3.0).
///
/// El save (sin cabecera GCI) mide 0x60000: 0x6000 de banner/icono de la
/// Memory Card y tres ranuras de 0x1E000. Cada ranura guarda al final el
/// SHA-1 de sus datos descifrados, que es también la clave: los datos desde
/// 0x18 se cifran en bloques de 20 bytes con XOR, y la clave de cada bloque es
/// el SHA-1 del bloque cifrado anterior.
abstract final class ColoCrypto {
  static const int slotSize = 0x1E000;
  static const int slotStart = 0x6000;
  static const int slotCount = 3;
  static const int saveSize = slotStart + slotSize * slotCount; // 0x60000
  static const int _hash = 20;

  static int slotOffset(int index) => slotStart + index * slotSize;

  /// Ranura más reciente (contador de guardado mayor en +4) y su contador.
  static (int index, int counter) latest(Uint8List data) {
    var counter = -1, index = -1;
    for (var i = 0; i < slotCount; i++) {
      final ctr = _s32(_u32be(data, slotOffset(i) + 4));
      if (ctr <= counter) continue;
      counter = ctr;
      index = i;
    }
    return (index < 0 ? 0 : index, counter);
  }

  /// Descifra una ranura (in situ).
  static void decrypt(Uint8List slot) {
    final digest = Uint8List.fromList([for (var i = slot.length - _hash; i < slot.length; i++) ~slot[i] & 0xFF]);
    final end = slot.length - _hash;
    for (var o = 0x18; o + _hash <= end; o += _hash) {
      final next = sha1.convert(Uint8List.sublistView(slot, o, o + _hash)).bytes;
      for (var j = 0; j < _hash; j++) {
        slot[o + j] ^= digest[j];
      }
      digest.setAll(0, next);
    }
  }

  /// Cifra una ranura (in situ) con el SHA-1 guardado al final como clave.
  static void encrypt(Uint8List slot) {
    final digest = Uint8List.fromList([for (var i = slot.length - _hash; i < slot.length; i++) ~slot[i] & 0xFF]);
    final end = slot.length - _hash;
    for (var o = 0x18; o + _hash <= end; o += _hash) {
      for (var j = 0; j < _hash; j++) {
        slot[o + j] ^= digest[j];
      }
      digest.setAll(0, sha1.convert(Uint8List.sublistView(slot, o, o + _hash)).bytes);
    }
  }

  static int _headerChecksum(Uint8List header, List<int> hash) {
    var r = 0;
    for (var i = 0; i < 0x18; i += 4) {
      r -= _u32be(header, i);
    }
    final h0 = (hash[0] << 24) | (hash[1] << 16) | (hash[2] << 8) | hash[3];
    final h1 = (hash[4] << 24) | (hash[5] << 16) | (hash[6] << 8) | hash[7];
    r -= _u32be(header, 0x18) ^ (~h0 & 0xFFFFFFFF);
    r -= _u32be(header, 0x1C) ^ (~h1 & 0xFFFFFFFF);
    return r & 0xFFFFFFFF;
  }

  /// Recalcula el SHA-1 del cuerpo y la suma de la cabecera de una ranura descifrada.
  static void setChecksums(Uint8List slot) {
    _setU32be(slot, 0x0C, 0);
    final hash = sha1.convert(Uint8List.sublistView(slot, 0, slot.length - 2 * _hash)).bytes;
    slot.setRange(slot.length - _hash, slot.length, hash);
    _setU32be(slot, 0x0C, _headerChecksum(slot, hash));
  }

  /// (cabecera válida, cuerpo válido) de una ranura descifrada. No la modifica.
  static (bool header, bool body) checksumsValid(Uint8List slot) {
    final copy = Uint8List.fromList(slot);
    final old = _u32be(copy, 0x0C);
    _setU32be(copy, 0x0C, 0);
    final hash = sha1.convert(Uint8List.sublistView(copy, 0, copy.length - 2 * _hash)).bytes;
    var body = true;
    for (var i = 0; i < _hash; i++) {
      if (hash[i] != slot[slot.length - _hash + i]) body = false;
    }
    return (_headerChecksum(copy, hash) == old, body);
  }
}

/// Cifrado de Genius Sonority (XD y Battle Revolution). Portado de PKHeX
/// `GeniusCrypto` (GPL-3.0): cada palabra de 16 bits (big endian) suma o resta
/// una de cuatro claves, que se transforman cada cuatro palabras.
abstract final class GeniusCrypto {
  static List<int> readKeys(Uint8List d, int offset) => [for (var i = 0; i < 4; i++) d.u16be(offset + i * 2)];

  static void _advance(List<int> k) {
    final k3 = k[3] + 0x13, k2 = k[2] + 0x17, k1 = k[1] + 0x29, k0 = k[0] + 0x43;
    k[3] = (((k0 >> 12) & 0xf) | ((k1 >> 8) & 0xf0) | ((k2 >> 4) & 0xf00) | (k3 & 0xf000)) & 0xFFFF;
    k[2] = (((k0 >> 8) & 0xf) | ((k1 >> 4) & 0xf0) | (k2 & 0xf00) | ((k3 << 4) & 0xf000)) & 0xFFFF;
    k[1] = (((k0 >> 4) & 0xf) | (k1 & 0xf0) | ((k2 << 4) & 0xf00) | ((k3 << 8) & 0xf000)) & 0xFFFF;
    k[0] = ((k0 & 0xf) | ((k1 << 4) & 0xf0) | ((k2 << 8) & 0xf00) | ((k3 << 12) & 0xf000)) & 0xFFFF;
  }

  static void _apply(Uint8List d, int start, int end, List<int> keys, int sign) {
    final k = List<int>.of(keys);
    var o = start;
    while (o < end) {
      for (var i = 0; i < 4 && o < end; i++, o += 2) {
        d.setU16be(o, (d.u16be(o) + sign * k[i]) & 0xFFFF);
      }
      _advance(k);
    }
  }

  static void decrypt(Uint8List d, int start, int end, List<int> keys) => _apply(d, start, end, keys, -1);
  static void encrypt(Uint8List d, int start, int end, List<int> keys) => _apply(d, start, end, keys, 1);
}

/// Cifrado y sumas de Pokémon XD. Portado de PKHeX `XDCrypto` (GPL-3.0).
///
/// El save (sin cabecera GCI) mide 0x56000: 0x6000 de banner/icono y dos
/// ranuras de 0x28000. Cada ranura: contador en +4, claves en +8, cuatro
/// sumas de 32 bits en +0x10 y datos cifrados de +0x10 a +0x27FD8.
abstract final class XdCrypto {
  static const int slotSize = 0x28000;
  static const int slotStart = 0x6000;
  static const int slotCount = 2;
  static const int saveSize = slotStart + slotSize * slotCount; // 0x56000
  static const int _dataEnd = 0x27FD8;

  static int slotOffset(int index) => slotStart + index * slotSize;

  static (int index, int counter) latest(Uint8List data) {
    var counter = -1, index = -1;
    for (var i = 0; i < slotCount; i++) {
      final ctr = _s32(_u32be(data, slotOffset(i) + 4));
      if (ctr <= counter) continue;
      counter = ctr;
      index = i;
    }
    return (index < 0 ? 0 : index, counter);
  }

  static void decryptSlot(Uint8List slot) => GeniusCrypto.decrypt(slot, 0x10, _dataEnd, GeniusCrypto.readKeys(slot, 8));
  static void encryptSlot(Uint8List slot) => GeniusCrypto.encrypt(slot, 0x10, _dataEnd, GeniusCrypto.readKeys(slot, 8));

  /// Posición de la suma de cabecera (dentro del bloque de configuración).
  static int headerChecksumOffset(int subOffset0) => 0xA8 + subOffset0 + 0x38;

  static int _headerSum(Uint8List d) {
    var v = 0;
    for (var i = 0; i < 8; i++) {
      v += d[i];
    }
    return v;
  }

  static List<int> _bodySums(Uint8List d) {
    final out = <int>[];
    var dt = 8;
    for (var i = 0; i < 4; i++) {
      var v = 0;
      final end = dt + 0x9FF4;
      for (var j = dt; j < end; j += 2) {
        v += d.u16be(j);
      }
      dt = end;
      out.add(v & 0xFFFFFFFF);
    }
    return out;
  }

  static void _writeBody(Uint8List d, List<int> sums) {
    final words = <int>[for (final s in sums) ...[(s >> 16) & 0xFFFF, s & 0xFFFF]];
    for (var i = 0; i < 8; i++) {
      d.setU16be(0x10 + 2 * i, words[7 - i]);
    }
  }

  /// Recalcula las sumas de una ranura descifrada.
  static void setChecksums(Uint8List slot, int subOffset0) {
    _setU32be(slot, headerChecksumOffset(subOffset0), _headerSum(slot));
    slot.fillRange(0x10, 0x20, 0);
    _writeBody(slot, _bodySums(slot));
  }

  /// (cabecera válida, cuerpo válido) de una ranura descifrada. No la modifica.
  static (bool header, bool body) checksumsValid(Uint8List slot, int subOffset0) {
    final copy = Uint8List.fromList(slot);
    setChecksums(copy, subOffset0);
    final h = headerChecksumOffset(subOffset0);
    final header = _u32be(copy, h) == _u32be(slot, h);
    var body = true;
    for (var i = 0x10; i < 0x20; i++) {
      if (copy[i] != slot[i]) body = false;
    }
    return (header, body);
  }
}
