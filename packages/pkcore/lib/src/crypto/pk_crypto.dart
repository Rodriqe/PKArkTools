import 'dart:typed_data';

import '../util/bytes.dart';
import '../util/checksums.dart';

/// Cifrado/barajado de las entidades Pokémon (PK3 … PK9).
///
/// Portado de PKHeX.Core `PokeCrypto.cs` (GPL-3.0).
abstract final class PkCrypto {
  static const int size3Stored = 80;
  static const int size3Party = 100;
  static const int size4Stored = 136;
  static const int size4Party = 236;
  static const int size5Party = 220;
  static const int size6Stored = 0xE8;
  static const int size6Party = 0x104;
  static const int size8Stored = 0x148;
  static const int size8Party = 0x158;

  static const List<int> _blockPosition = [
    0, 1, 2, 3, 0, 1, 3, 2, 0, 2, 1, 3, 0, 3, 1, 2, //
    0, 2, 3, 1, 0, 3, 2, 1, 1, 0, 2, 3, 1, 0, 3, 2, //
    2, 0, 1, 3, 3, 0, 1, 2, 2, 0, 3, 1, 3, 0, 2, 1, //
    1, 2, 0, 3, 1, 3, 0, 2, 2, 1, 0, 3, 3, 1, 0, 2, //
    2, 3, 0, 1, 3, 2, 0, 1, 1, 2, 3, 0, 1, 3, 2, 0, //
    2, 1, 3, 0, 3, 1, 2, 0, 2, 3, 1, 0, 3, 2, 1, 0, //
    0, 1, 2, 3, 0, 1, 3, 2, 0, 2, 1, 3, 0, 3, 1, 2, //
    0, 2, 3, 1, 0, 3, 2, 1, 1, 0, 2, 3, 1, 0, 3, 2, //
  ];

  static const List<int> _blockPositionInvert = [
    0, 1, 2, 4, 3, 5, 6, 7, 12, 18, 13, 19, 8, 10, 14, 20, //
    16, 22, 9, 11, 15, 21, 17, 23, 0, 1, 2, 4, 3, 5, 6, 7, //
  ];

  /// Reordena 4 bloques de [blockSize] bytes empezando en [start]:
  /// el bloque de salida i es el bloque de entrada `pos[sv*4+i]`.
  static void _shuffle(Uint8List data, int start, int sv, int blockSize) {
    if (sv == 0) return;
    final src = data.copyRange(start, blockSize * 4);
    for (var i = 0; i < 4; i++) {
      final from = _blockPosition[sv * 4 + i];
      data.setRange(start + i * blockSize, start + (i + 1) * blockSize,
          src, from * blockSize);
    }
  }

  /// XOR con el LCRNG de Game Freak sobre palabras u16.
  static void cryptArray(Uint8List data, int start, int end, int seed) {
    var s = seed & 0xFFFFFFFF;
    for (var i = start; i < end; i += 2) {
      s = (0x41C64E6D * s + 0x6073) & 0xFFFFFFFF;
      final xor = s >> 16;
      data[i] ^= xor & 0xFF;
      data[i + 1] ^= (xor >> 8) & 0xFF;
    }
  }

  // ---- Gen 3 ----

  static Uint8List decrypt3(Uint8List encrypted) {
    final d = Uint8List.fromList(encrypted);
    final pid = d.u32le(0);
    final seed = pid ^ d.u32le(4);
    for (var i = 32; i < 80; i += 4) {
      d.setU32le(i, d.u32le(i) ^ seed);
    }
    _shuffle(d, 32, pid % 24, 12);
    return d;
  }

  static Uint8List encrypt3(Uint8List decrypted) {
    final d = Uint8List.fromList(decrypted);
    final pid = d.u32le(0);
    final seed = pid ^ d.u32le(4);
    _shuffle(d, 32, _blockPositionInvert[pid % 24], 12);
    for (var i = 32; i < 80; i += 4) {
      d.setU32le(i, d.u32le(i) ^ seed);
    }
    return d;
  }

  /// Checksum de la zona cifrable de un PK3 descifrado.
  static int checksum3(Uint8List d) => Checksums.add16(d, 32, 80);

  // ---- Gen 4/5 ----

  static Uint8List decrypt45(Uint8List encrypted) {
    final d = Uint8List.fromList(encrypted);
    final pv = d.u32le(0);
    final chk = d.u16le(6);
    final sv = (pv >> 13) & 31;
    cryptArray(d, 8, size4Stored, chk);
    if (d.length > size4Stored) cryptArray(d, size4Stored, d.length, pv);
    _shuffle(d, 8, sv, 32);
    return d;
  }

  /// BK4 de Battle Revolution: solo barajado de bloques, sin XOR (PKHeX `Decrypt4BE`).
  static Uint8List unshuffle4BE(Uint8List stored) {
    final d = Uint8List.fromList(stored);
    final pv = (d[0] << 24) | (d[1] << 16) | (d[2] << 8) | d[3];
    _shuffle(d, 8, (pv >> 13) & 31, 32);
    return d;
  }

  /// Inverso de [unshuffle4BE] (PKHeX `Encrypt4BE`).
  static Uint8List shuffle4BE(Uint8List decrypted) {
    final d = Uint8List.fromList(decrypted);
    final pv = (d[0] << 24) | (d[1] << 16) | (d[2] << 8) | d[3];
    _shuffle(d, 8, _blockPositionInvert[(pv >> 13) & 31], 32);
    return d;
  }

  static Uint8List encrypt45(Uint8List decrypted) {
    final d = Uint8List.fromList(decrypted);
    final pv = d.u32le(0);
    final chk = d.u16le(6);
    final sv = _blockPositionInvert[(pv >> 13) & 31];
    _shuffle(d, 8, sv, 32);
    cryptArray(d, 8, size4Stored, chk);
    if (d.length > size4Stored) cryptArray(d, size4Stored, d.length, pv);
    return d;
  }

  // ---- Gen 6/7 (bloques de 56) y Gen 8/9 (bloques de 80) ----

  static Uint8List _decryptEc(Uint8List encrypted, int storedSize, int blockSize) {
    final d = Uint8List.fromList(encrypted);
    final ec = d.u32le(0);
    final sv = (ec >> 13) & 31;
    cryptArray(d, 8, storedSize, ec);
    if (d.length > storedSize) cryptArray(d, storedSize, d.length, ec);
    _shuffle(d, 8, sv, blockSize);
    return d;
  }

  static Uint8List _encryptEc(Uint8List decrypted, int storedSize, int blockSize) {
    final d = Uint8List.fromList(decrypted);
    final ec = d.u32le(0);
    final sv = _blockPositionInvert[(ec >> 13) & 31];
    _shuffle(d, 8, sv, blockSize);
    cryptArray(d, 8, storedSize, ec);
    if (d.length > storedSize) cryptArray(d, storedSize, d.length, ec);
    return d;
  }

  static Uint8List decrypt67(Uint8List e) => _decryptEc(e, size6Stored, 56);
  static Uint8List encrypt67(Uint8List d) => _encryptEc(d, size6Stored, 56);
  static Uint8List decrypt8(Uint8List e) => _decryptEc(e, size8Stored, 80);
  static Uint8List encrypt8(Uint8List d) => _encryptEc(d, size8Stored, 80);

  /// PA8 (Leyendas Arceus): bloques de 0x58 bytes.
  static const int size8aStored = 0x168;
  static const int size8aParty = 0x178;
  static Uint8List decrypt8a(Uint8List e) => _decryptEc(e, size8aStored, 88);
  static Uint8List encrypt8a(Uint8List d) => _encryptEc(d, size8aStored, 88);

  /// PB7 (Let's Go): estructura de 0x104 bytes cifrada como Gen 6/7.
  static Uint8List decrypt7b(Uint8List e) => _decryptEc(e, size6Stored, 56);
  static Uint8List encrypt7b(Uint8List d) => _encryptEc(d, size6Stored, 56);

  /// Checksum estándar Gen 4–9: suma u16 desde 0x08 hasta el tamaño almacenado.
  static int checksumFrom8(Uint8List d, int storedSize) =>
      Checksums.add16(d, 8, storedSize);
}
