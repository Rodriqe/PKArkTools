import 'dart:typed_data';

import '../util/bytes.dart';

/// Distribuciones de las memorias de Pokémon Stadium (N64). Portado de PKHeX
/// `SAV1Stadium`, `SAV1StadiumJ`, `SAV2Stadium`, `SAV_STADIUM` y
/// `StadiumUtil` (GPL-3.0).
///
/// Las cajas son listas: cabecera, Pokémon guardados uno tras otro (estructura
/// de GB + apodo + entrenador), relleno, la firma `POKE` (`P3v0` en Stadium 2)
/// y una suma de 16 bits (suma de bytes) en big endian.
class StadiumLayout {
  const StadiumLayout._({
    required this.generation,
    required this.japanese,
    required this.fileSizes,
    required this.boxStart,
    required this.boxStartRest,
    required this.boxHeader,
    required this.boxSize,
    required this.boxCount,
    required this.slotsPerBox,
    required this.slotSize,
    required this.strLen,
    required this.magic,
    required this.teamSize,
    required this.teamHeader,
    required this.label,
    this.headerMagic,
    this.countAt,
  });

  final int generation;
  final bool japanese;
  final Set<int> fileSizes;
  final int boxStart;

  /// Stadium 2 guarda la caja 1 aparte (0x5E00) y el resto desde 0x8000.
  final int? boxStartRest;
  final int boxHeader, boxSize, boxCount, slotsPerBox, slotSize, strLen;
  final int magic, teamSize, teamHeader;
  final String label;

  /// Primeros 4 bytes (big endian) de la cabecera de caja de Stadium 1.
  final int? headerMagic;

  /// Posición del contador de Pokémon relativa al inicio de la caja
  /// (null = el juego no lo guarda: Pocket Monsters Stadium japonés).
  final int? countAt;

  static const int _poke = 0x454B4F50; // «POKE»
  static const int _p3v0 = 0x30763350; // «P3v0»

  /// Pokémon Stadium (internacional): 12 cajas de 20.
  static const stadiumU = StadiumLayout._(
      generation: 1, japanese: false, fileSizes: {0x20000, 0x1FF00}, boxStart: 0xC000, boxStartRest: null,
      boxHeader: 0x10, boxSize: 0x468, boxCount: 12, slotsPerBox: 20, slotSize: 33 + 22, strLen: 11,
      magic: _poke, teamSize: 0x160, teamHeader: 0x10, label: 'Stadium', headerMagic: 0x00500000, countAt: 0x0F);

  /// Pokémon Stadium 2 japonés (Pocket Monsters Stadium 2 en Japón): 8 cajas de 30.
  static const stadiumJ = StadiumLayout._(
      generation: 1, japanese: true, fileSizes: {0x20000, 0x1FF00}, boxStart: 0xC000, boxStartRest: null,
      boxHeader: 0x0C, boxSize: 0x558, boxCount: 8, slotsPerBox: 30, slotSize: 33 + 12, strLen: 6,
      magic: _poke, teamSize: 0x120, teamHeader: 0x0C, label: 'Stadium (JP)', headerMagic: 0x00005000, countAt: 0x0B);

  /// Pocket Monsters Stadium (el primero, solo Japón): 4 cajas de 30 (más copia).
  static const stadiumJOld = StadiumLayout._(
      generation: 1, japanese: true, fileSizes: {0x8000}, boxStart: 0x2500, boxStartRest: null,
      boxHeader: 0x14, boxSize: 0x560, boxCount: 4, slotsPerBox: 30, slotSize: 33 + 12, strLen: 6,
      magic: _poke, teamSize: 0x128, teamHeader: 0x14, label: 'Pocket Monsters Stadium (JP)');

  /// Pokémon Stadium 2 (internacional): 14 cajas de 20.
  static const stadium2U = StadiumLayout._(
      generation: 2, japanese: false, fileSizes: {0x20000, 0x1FF00}, boxStart: 0x5E00, boxStartRest: 0x8000,
      boxHeader: 0x20, boxSize: 0x4D8, boxCount: 14, slotsPerBox: 20, slotSize: 60, strLen: 12,
      magic: _p3v0, teamSize: 0x180, teamHeader: 0x10, label: 'Stadium 2', countAt: 0x01);

  /// Pokémon Stadium 2 japonés (Pocket Monsters Stadium Kin Gin): 9 cajas de 30.
  static const stadium2J = StadiumLayout._(
      generation: 2, japanese: true, fileSizes: {0x20000, 0x1FF00}, boxStart: 0x5E00, boxStartRest: 0x8000,
      boxHeader: 0x20, boxSize: 0x730, boxCount: 9, slotsPerBox: 30, slotSize: 60, strLen: 12,
      magic: _p3v0, teamSize: 0x180, teamHeader: 0x10, label: 'Stadium 2 (JP)', countAt: 0x01);

  /// Inicio de la caja [box] (su cabecera), con [base] = desplazamiento de la copia.
  int boxOffset(int box, [int base = 0]) {
    if (boxStartRest != null && box > 0) return boxStartRest! + (box - 1) * boxSize;
    return base + boxStart + box * boxSize;
  }

  int slotOffset(int box, int slot, [int base = 0]) => boxOffset(box, base) + boxHeader + slot * slotSize;

  /// (inicio, longitud) de la región que cubre la suma de la caja; la suma va justo después.
  (int, int) checksumRegion(int box, [int base = 0]) => (boxOffset(box, base), boxSize - 2);

  static int sum16(Uint8List d, int start, int len) {
    var c = 0;
    for (var i = start; i < start + len; i++) {
      c += d[i];
    }
    return c & 0xFFFF;
  }

  bool boxChecksumValid(Uint8List d, int box, [int base = 0]) {
    final (s, l) = checksumRegion(box, base);
    return sum16(d, s, l) == d.u16be(s + l);
  }

  void setBoxChecksum(Uint8List d, int box, [int base = 0]) {
    final (s, l) = checksumRegion(box, base);
    d.setU16be(s + l, sum16(d, s, l));
  }

  bool _footer(Uint8List d, int ofs) => ofs >= 0 && ofs + 4 <= d.length && d.u32le(ofs) == magic;

  /// Firma `POKE`/`P3v0` en los pies de [count] listas de [size] desde [start].
  bool _lists(Uint8List d, int start, int size, int count) {
    for (var i = 0; i < count; i++) {
      if (!_footer(d, start + size - 6 + i * size)) return false;
    }
    return true;
  }

  /// `true` si [d] (ya sin intercambiar) tiene esta distribución (PKHeX `IsStadium*`).
  bool matches(Uint8List d) {
    if (!fileSizes.contains(d.length)) return false;
    switch (this) {
      case stadiumJOld:
        return _lists(d, 0, teamSize, 10) || _lists(d, boxStart, boxSize, 1);
      case stadium2U || stadium2J:
        return _footer(d, boxStart + boxSize - 6);
      default:
        return _lists(d, 0, teamSize, 10) || _lists(d, boxStart, boxSize, 5);
    }
  }

  /// La copia de seguridad de Stadium 1 (0x10000 más allá) se usa si la caja
  /// 1 principal no es válida (PKHeX `IsUsingBackupBoxSlots`).
  int boxBase(Uint8List d) {
    if (headerMagic == null || generation != 1 || this == stadiumJOld) return 0;
    bool valid(int base) {
      final o = boxOffset(0, base);
      return o + boxSize <= d.length && d.u32be(o) == headerMagic && _footer(d, o + boxSize - 6);
    }

    return !valid(0) && valid(0x10000) ? 0x10000 : 0;
  }

  /// Número de Pokémon en la caja (o null si el juego no lo guarda).
  int? count(Uint8List d, int box, [int base = 0]) {
    final at = countAt;
    if (at == null) return null;
    return d[boxOffset(box, base) + at];
  }

  /// Equipos registrados: (nombre, offset de la lista).
  List<(String, int)> teams() {
    switch (this) {
      case stadiumJOld:
        return [for (var t = 0; t < 16; t++) ('Equipo ${t + 1}', t * 2 * teamSize)];
      case stadium2U || stadium2J:
        const types = ['Libre', 'Copa Pichu', 'Copa Poké', 'Copa Prime', 'Castillo de Líderes', 'Contra el Rival'];
        return [
          for (var t = 0; t < 60; t++) ('${types[t ~/ 10]} ${t % 10 + 1}', t < 40 ? t * teamSize : 0x4000 + (t - 40) * teamSize),
        ];
      default:
        final jp = japanese;
        final perType = jp ? 12 : 10;
        final typeOfs = jp
            ? const [0x0000, 0x0D80, 0x1B00, 0x2880, 0x4000, 0x4D80, 0x5B00, 0x6880, 0x8000]
            : const [0x0000, 0x0DC0, 0x1B80, 0x2940, 0x4000, 0x4DC0, 0x5B80, 0x6940, 0x8000];
        const names = ['Libre', 'Copa Nintendo 97', 'Copa Nintendo 98', 'Copa Poké', 'Copa Petit', 'Copa Pika', 'Copa Prime',
          'Castillo de Líderes', 'Contra Mewtwo'];
        return [
          for (var type = 0; type < 9; type++)
            if (jp || (type != 1 && type != 2))
              for (var i = 0; i < perType; i++) ('${names[type]} ${i + 1}', typeOfs[type] + i * teamSize),
        ];
    }
  }

  static const all = [stadium2J, stadium2U, stadiumJ, stadiumU, stadiumJOld];

  /// Distribución y si el archivo viene con palabras de 32 bits invertidas
  /// (volcados de N64 con otro orden de bytes).
  static (StadiumLayout, bool)? detect(Uint8List d) {
    for (final l in all) {
      if (l.matches(d)) return (l, false);
    }
    final swapped = swap32(d);
    for (final l in all) {
      if (l.matches(swapped)) return (l, true);
    }
    return null;
  }

  /// Invierte el orden de bytes de cada palabra de 32 bits.
  static Uint8List swap32(Uint8List d) {
    final out = Uint8List(d.length);
    for (var i = 0; i + 3 < d.length; i += 4) {
      out[i] = d[i + 3];
      out[i + 1] = d[i + 2];
      out[i + 2] = d[i + 1];
      out[i + 3] = d[i];
    }
    return out;
  }
}
