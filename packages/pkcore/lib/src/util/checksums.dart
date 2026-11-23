import 'dart:typed_data';

/// Algoritmos de checksum usados por las distintas generaciones.
///
/// Portado de PKHeX.Core `Checksums.cs` (GPL-3.0).
abstract final class Checksums {
  /// CRC16-CCITT (init 0xFFFF, poly 0x1021) usado en Gen 4 y Gen 5.
  static int crc16Ccitt(Uint8List data, [int start = 0, int? end]) {
    var top = 0xFF;
    var bot = 0xFF;
    final stop = end ?? data.length;
    for (var i = start; i < stop; i++) {
      var x = data[i] ^ top;
      x ^= x >> 4;
      top = (bot ^ (x >> 3) ^ (x << 4)) & 0xFF;
      bot = (x ^ (x << 5)) & 0xFF;
    }
    return (top << 8) | bot;
  }

  /// Suma de palabras de 32 bits plegada a 16 bits (sectores de Gen 3).
  static int checkSum32(Uint8List data, int start, int length) {
    var chk = 0;
    for (var i = start; i < start + length; i += 4) {
      chk = (chk +
              (data[i] |
                  (data[i + 1] << 8) |
                  (data[i + 2] << 16) |
                  (data[i + 3] << 24))) &
          0xFFFFFFFF;
    }
    return (chk + (chk >> 16)) & 0xFFFF;
  }

  /// Suma de bytes de 16 bits (Gen 2, rango inclusivo).
  static int sum16Bytes(Uint8List data, int start, int endInclusive) {
    var sum = 0;
    for (var i = start; i <= endInclusive; i++) {
      sum = (sum + data[i]) & 0xFFFF;
    }
    return sum;
  }

  /// Checksum de RBY: complemento a uno de la suma de bytes en [start, end).
  static int gen1(Uint8List data, int start, int end) {
    var sum = 0;
    for (var i = start; i < end; i++) {
      sum = (sum + data[i]) & 0xFF;
    }
    return (~sum) & 0xFF;
  }

  /// Suma de u16 little-endian (checksum de entidades Pokémon Gen 3–9).
  static int add16(Uint8List data, int start, int end) {
    var sum = 0;
    for (var i = start; i < end; i += 2) {
      sum = (sum + (data[i] | (data[i + 1] << 8))) & 0xFFFF;
    }
    return sum;
  }

  static final List<int> _crc16Table = List<int>.generate(256, (i) {
    var c = i;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (c >> 1) ^ 0xA001 : c >> 1;
    }
    return c;
  });

  /// CRC-16 reflejado (polinomio 0xA001) con valor inicial [initial]
  /// (Gen 7 usa `~crc(0xFFFF)`, Let's Go `crc(0)`).
  static int crc16Arc(Uint8List data, int start, int end, int initial) {
    var chk = initial & 0xFFFF;
    for (var i = start; i < end; i++) {
      chk = _crc16Table[(data[i] ^ chk) & 0xFF] ^ (chk >> 8);
    }
    return chk & 0xFFFF;
  }
}
