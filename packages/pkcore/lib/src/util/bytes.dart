import 'dart:typed_data';

/// Lectura/escritura binaria little/big endian sobre un [Uint8List].
///
/// Todas las lecturas validan límites y lanzan [RangeError] si se sale del
/// buffer, de modo que un save truncado nunca produce lecturas silenciosas.
extension ByteAccess on Uint8List {
  int u8(int offset) => this[offset];

  int u16le(int offset) => this[offset] | (this[offset + 1] << 8);

  int u16be(int offset) => (this[offset] << 8) | this[offset + 1];

  int u32le(int offset) =>
      this[offset] |
      (this[offset + 1] << 8) |
      (this[offset + 2] << 16) |
      (this[offset + 3] << 24);

  int u32be(int offset) =>
      (this[offset] << 24) |
      (this[offset + 1] << 16) |
      (this[offset + 2] << 8) |
      this[offset + 3];

  int s32le(int offset) {
    final v = u32le(offset);
    return v >= 0x80000000 ? v - 0x100000000 : v;
  }

  void setU16le(int offset, int value) {
    this[offset] = value & 0xFF;
    this[offset + 1] = (value >> 8) & 0xFF;
  }

  void setU16be(int offset, int value) {
    this[offset] = (value >> 8) & 0xFF;
    this[offset + 1] = value & 0xFF;
  }

  void setU32le(int offset, int value) {
    this[offset] = value & 0xFF;
    this[offset + 1] = (value >> 8) & 0xFF;
    this[offset + 2] = (value >> 16) & 0xFF;
    this[offset + 3] = (value >> 24) & 0xFF;
  }

  /// Vista (sin copia) de una región.
  Uint8List view(int offset, int length) =>
      Uint8List.sublistView(this, offset, offset + length);

  /// Copia independiente de una región.
  Uint8List copyRange(int offset, int length) =>
      Uint8List.fromList(Uint8List.sublistView(this, offset, offset + length));

  bool hasRange(int offset, int length) =>
      offset >= 0 && length >= 0 && offset + length <= this.length;

  bool isAllValue(int value) {
    for (final b in this) {
      if (b != value) return false;
    }
    return true;
  }

  bool endsWithAscii(String suffix) {
    if (suffix.length > length) return false;
    final start = length - suffix.length;
    for (var i = 0; i < suffix.length; i++) {
      if (this[start + i] != suffix.codeUnitAt(i)) return false;
    }
    return true;
  }
}

/// Número de bits a 1 de un entero de 32 bits.
int popCount32(int v) {
  v &= 0xFFFFFFFF;
  var c = 0;
  while (v != 0) {
    v &= v - 1;
    c++;
  }
  return c;
}
