/// Conversión entre índices internos de especie y la Pokédex Nacional.
///
/// Tablas portadas de PKHeX.Core `SpeciesConverter.cs` (GPL-3.0).
abstract final class SpeciesConvert {
  static const List<int> _g1InternalToNational = [
    0x00, 0x70, 0x73, 0x20, 0x23, 0x15, 0x64, 0x22, 0x50, 0x02, 0x67, 0x6C, 0x66, 0x58, 0x5E, 0x1D, //
    0x1F, 0x68, 0x6F, 0x83, 0x3B, 0x97, 0x82, 0x5A, 0x48, 0x5C, 0x7B, 0x78, 0x09, 0x7F, 0x72, 0x00, //
    0x00, 0x3A, 0x5F, 0x16, 0x10, 0x4F, 0x40, 0x4B, 0x71, 0x43, 0x7A, 0x6A, 0x6B, 0x18, 0x2F, 0x36, //
    0x60, 0x4C, 0x00, 0x7E, 0x00, 0x7D, 0x52, 0x6D, 0x00, 0x38, 0x56, 0x32, 0x80, 0x00, 0x00, 0x00, //
    0x53, 0x30, 0x95, 0x00, 0x00, 0x00, 0x54, 0x3C, 0x7C, 0x92, 0x90, 0x91, 0x84, 0x34, 0x62, 0x00, //
    0x00, 0x00, 0x25, 0x26, 0x19, 0x1A, 0x00, 0x00, 0x93, 0x94, 0x8C, 0x8D, 0x74, 0x75, 0x00, 0x00, //
    0x1B, 0x1C, 0x8A, 0x8B, 0x27, 0x28, 0x85, 0x88, 0x87, 0x86, 0x42, 0x29, 0x17, 0x2E, 0x3D, 0x3E, //
    0x0D, 0x0E, 0x0F, 0x00, 0x55, 0x39, 0x33, 0x31, 0x57, 0x00, 0x00, 0x0A, 0x0B, 0x0C, 0x44, 0x00, //
    0x37, 0x61, 0x2A, 0x96, 0x8F, 0x81, 0x00, 0x00, 0x59, 0x00, 0x63, 0x5B, 0x00, 0x65, 0x24, 0x6E, //
    0x35, 0x69, 0x00, 0x5D, 0x3F, 0x41, 0x11, 0x12, 0x79, 0x01, 0x03, 0x49, 0x00, 0x76, 0x77, 0x00, //
    0x00, 0x00, 0x00, 0x4D, 0x4E, 0x13, 0x14, 0x21, 0x1E, 0x4A, 0x89, 0x8E, 0x00, 0x51, 0x00, 0x00, //
    0x04, 0x07, 0x05, 0x08, 0x06, 0x00, 0x00, 0x00, 0x00, 0x2B, 0x2C, 0x2D, 0x45, 0x46, 0x47, //
  ];

  static int nationalFromGen1(int raw) =>
      raw < _g1InternalToNational.length ? _g1InternalToNational[raw] : 0;

  static int gen1FromNational(int species) {
    if (species <= 0 || species > 151) return 0;
    return _g1InternalToNational.indexOf(species);
  }

  static const int _firstUnalignedNational3 = 252;
  static const int _firstUnalignedInternal3 = 277;

  static const List<int> _table3NationalToInternal = [
    25, 25, 25, 25, 25, 25, 25, 25, //
    25, 25, 25, 25, 25, 25, 25, 25, 25, 25, //
    25, 25, 25, 25, 25, 25, 28, 28, 31, 31, //
    112, 112, 112, 28, 28, 21, 21, 77, 77, 77, //
    11, 11, 11, 77, 77, 77, 39, 39, 52, 21, //
    15, 15, 20, 52, 78, 78, 78, 49, 49, 28, //
    28, 42, 42, 73, 73, 48, 51, 51, 12, 12, //
    -7, -7, 17, 17, -3, 26, 26, -19, 4, 4, //
    4, 13, 13, 25, 25, 45, 43, 11, 11, -16, //
    -16, -15, -15, -25, -25, 43, 43, 43, 43, -21, //
    -21, 34, -35, 24, 24, 6, 6, 12, 53, 17, //
    0, -15, -15, -22, -22, -22, 7, 7, 7, 12, //
    -45, 24, 24, 24, 24, 24, 24, 24, 24, 24, //
    27, 27, 22, 22, 22, 24, 24, //
  ];

  static const List<int> _table3InternalToNational = [
    -25, -25, -25, //
    -25, -25, -25, -25, -25, -25, -25, -25, -25, -25, //
    -25, -25, -25, -25, -25, -25, -25, -25, -25, -25, //
    -25, -11, -11, -11, -28, -28, -21, -21, 19, -31, //
    -31, -28, -28, 7, 7, -15, -15, 35, 25, 25, //
    -21, 3, -20, 16, 16, 45, 15, 15, 21, 21, //
    -12, -12, -4, -4, -4, -39, -39, -28, -28, -17, //
    -17, 22, 22, 22, -13, -13, 15, 15, -11, -11, //
    -52, -26, -26, -42, -42, -52, -49, -49, -25, -25, //
    0, -6, -6, -48, -77, -77, -77, -51, -51, -12, //
    -77, -77, -77, -7, -7, -7, -17, -24, -24, -43, //
    -45, -12, -78, -78, -78, -34, -73, -73, -43, -43, //
    -43, -43, -112, -112, -112, -24, -24, -24, -24, -24, //
    -24, -24, -24, -24, -22, -22, -22, -27, -27, -24, //
    -24, -53, //
  ];

  static int nationalFromGen3(int raw) {
    if (raw < _firstUnalignedNational3) return raw;
    final shift = raw - _firstUnalignedInternal3;
    if (shift < 0 || shift >= _table3InternalToNational.length) return 0;
    return raw + _table3InternalToNational[shift];
  }

  static int gen3FromNational(int species) {
    final shift = species - _firstUnalignedNational3;
    if (shift < 0 || shift >= _table3NationalToInternal.length) return species;
    return species + _table3NationalToInternal[shift];
  }

  static const int _firstUnaligned9 = 917;

  static const List<int> _table9NationalToInternal = [
    1, 1, 1, //
    1, 33, 33, 33, 21, 21, 44, 44, 7, 7, //
    7, 29, 31, 31, 31, 68, 68, 68, 2, 2, //
    17, 17, 30, 30, 24, 24, 28, 28, 58, 58, //
    12, -13, -13, -31, -31, -29, -29, 43, 43, 43, //
    -31, -31, -3, -30, -30, -23, -23, -14, -24, -3, //
    -3, -47, -47, -12, -27, -27, -44, -46, -26, 31, //
    29, -53, -65, 25, -6, -3, -7, -4, -4, -8, //
    -4, 1, -3, -3, -6, -4, -47, -47, -47, -23, //
    -23, -5, -7, -9, -7, -20, -13, -9, -9, -29, //
    -23, 1, 12, 12, 0, 0, 0, -6, 5, -6, //
    -3, -3, -2, -4, -3, -3, //
  ];

  static const List<int> _table9InternalToNational = [
    65, -1, -1, //
    -1, -1, 31, 31, 47, 47, 29, 29, 53, 31, //
    31, 46, 44, 30, 30, -7, -7, -7, 13, 13, //
    -2, -2, 23, 23, 24, -21, -21, 27, 27, 47, //
    47, 47, 26, 14, -33, -33, -33, -17, -17, 3, //
    -29, 12, -12, -31, -31, -31, 3, 3, -24, -24, //
    -44, -44, -30, -30, -28, -28, 23, 23, 6, 7, //
    29, 8, 3, 4, 4, 20, 4, 23, 6, 3, //
    3, 4, -1, 13, 9, 7, 5, 7, 9, 9, //
    -43, -43, -43, -68, -68, -68, -58, -58, -25, -29, //
    -31, 6, -1, 6, 0, 0, 0, 3, 3, 4, //
    2, 3, 3, -5, -12, -12, //
  ];

  static int nationalFromGen9(int raw) {
    final shift = raw - _firstUnaligned9;
    if (shift < 0 || shift >= _table9InternalToNational.length) return raw;
    return raw + _table9InternalToNational[shift];
  }

  static int gen9FromNational(int species) {
    final shift = species - _firstUnaligned9;
    if (shift < 0 || shift >= _table9NationalToInternal.length) return species;
    return species + _table9NationalToInternal[shift];
  }
}
