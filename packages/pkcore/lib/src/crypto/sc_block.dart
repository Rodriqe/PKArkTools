import 'dart:typed_data';

import '../util/bytes.dart';

/// Tipo de dato almacenado en un [SCBlock]. Portado de PKHeX `SCTypeCode`.
enum SCTypeCode {
  none(0, 0),
  bool1(1, 0),
  bool2(2, 0),
  bool3(3, 1),
  object(4, 0),
  array(5, 0),
  byte(8, 1),
  uint16(9, 2),
  uint32(10, 4),
  uint64(11, 8),
  sbyte(12, 1),
  int16(13, 2),
  int32(14, 4),
  int64(15, 8),
  single(16, 4),
  double(17, 8);

  const SCTypeCode(this.code, this.size);
  final int code;

  /// Tamaño en bytes de un elemento (para arrays y valores simples).
  final int size;

  static SCTypeCode fromCode(int code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    throw FormatException('Tipo de SCBlock desconocido: $code');
  }

  bool get isBoolean => this == bool1 || this == bool2 || this == bool3;
}

/// Generador xorshift32 que produce la máscara de cada bloque a partir de su clave.
///
/// Portado de PKHeX `SCXorShift32` (GPL-3.0).
class SCXorShift32 {
  SCXorShift32(int seed) : _state = _initialState(seed & 0xFFFFFFFF);

  int _counter = 0;
  int _state;

  static int _initialState(int state) {
    final pop = popCount32(state);
    for (var i = 0; i < pop; i++) {
      state = _advance(state);
    }
    return state;
  }

  static int _advance(int s) {
    s ^= (s << 2) & 0xFFFFFFFF;
    s ^= s >> 15;
    s ^= (s << 13) & 0xFFFFFFFF;
    return s & 0xFFFFFFFF;
  }

  int next() {
    final c = _counter;
    final result = (_state >> (c << 3)) & 0xFF;
    if (c == 3) {
      _state = _advance(_state);
      _counter = 0;
    } else {
      _counter++;
    }
    return result;
  }

  int next32() => next() | (next() << 8) | (next() << 16) | (next() << 24);
}

/// Un bloque clave/valor de los saves de Switch de Game Freak.
class SCBlock {
  SCBlock._(this.key, this.type, this.data, [this.subType = SCTypeCode.none]);

  /// Bloque con datos arbitrarios (`object`).
  factory SCBlock.object(int key, Uint8List data) =>
      SCBlock._(key, SCTypeCode.object, data);

  /// Bloque booleano (`bool1` = falso, `bool2` = verdadero).
  factory SCBlock.boolean(int key, bool value) =>
      SCBlock._(key, value ? SCTypeCode.bool2 : SCTypeCode.bool1, Uint8List(0));

  /// Bloque de valor simple (u8, u32, ...).
  factory SCBlock.value(int key, SCTypeCode type, int value) {
    final d = Uint8List(type.size);
    for (var i = 0; i < type.size; i++) {
      d[i] = (value >> (8 * i)) & 0xFF;
    }
    return SCBlock._(key, type, d);
  }

  /// Bloque array de [subType].
  factory SCBlock.array(int key, SCTypeCode subType, Uint8List data) =>
      SCBlock._(key, SCTypeCode.array, data, subType);

  final int key;

  /// Tipo del bloque. En los booleanos el valor vive en el tipo (`bool1`/`bool2`).
  SCTypeCode type;
  final SCTypeCode subType;
  final Uint8List data;

  /// Valor entero para bloques de tipo simple.
  int get intValue {
    var v = 0;
    for (var i = data.length - 1; i >= 0; i--) {
      v = (v << 8) | data[i];
    }
    return v;
  }

  set intValue(int value) {
    for (var i = 0; i < data.length; i++) {
      data[i] = (value >> (8 * i)) & 0xFF;
    }
  }

  bool get boolValue => type == SCTypeCode.bool2;

  /// Lee todos los bloques de un payload ya sin xorpad.
  static List<SCBlock> readAll(Uint8List payload) {
    final result = <SCBlock>[];
    var offset = 0;
    while (offset < payload.length) {
      final (block, next) = readAt(payload, offset);
      result.add(block);
      offset = next;
    }
    return result;
  }

  /// Lee un bloque en [offset]; devuelve el bloque y el offset siguiente.
  static (SCBlock, int) readAt(Uint8List d, int offset) {
    if (!d.hasRange(offset, 5)) {
      throw const FormatException('SCBlock truncado');
    }
    final key = d.u32le(offset);
    offset += 4;
    final xk = SCXorShift32(key);
    final type = SCTypeCode.fromCode(d[offset++] ^ xk.next());
    switch (type) {
      case SCTypeCode.bool1:
      case SCTypeCode.bool2:
      case SCTypeCode.bool3:
        return (SCBlock._(key, type, Uint8List(0)), offset);
      case SCTypeCode.object:
        final len = (d.u32le(offset) ^ xk.next32()) & 0xFFFFFFFF;
        offset += 4;
        if (!d.hasRange(offset, len)) {
          throw const FormatException('SCBlock object truncado');
        }
        final arr = d.copyRange(offset, len);
        offset += len;
        for (var i = 0; i < arr.length; i++) {
          arr[i] ^= xk.next();
        }
        return (SCBlock._(key, type, arr), offset);
      case SCTypeCode.array:
        final count = (d.u32le(offset) ^ xk.next32()) & 0xFFFFFFFF;
        offset += 4;
        final sub = SCTypeCode.fromCode(d[offset++] ^ xk.next());
        final len = count * sub.size;
        if (!d.hasRange(offset, len)) {
          throw const FormatException('SCBlock array truncado');
        }
        final arr = d.copyRange(offset, len);
        offset += len;
        for (var i = 0; i < arr.length; i++) {
          arr[i] ^= xk.next();
        }
        return (SCBlock._(key, type, arr, sub), offset);
      case SCTypeCode.none:
        throw const FormatException('SCBlock con tipo nulo');
      default:
        final len = type.size;
        if (!d.hasRange(offset, len)) {
          throw const FormatException('SCBlock valor truncado');
        }
        final arr = d.copyRange(offset, len);
        offset += len;
        for (var i = 0; i < arr.length; i++) {
          arr[i] ^= xk.next();
        }
        return (SCBlock._(key, type, arr), offset);
    }
  }

  /// Serializa el bloque (clave + tipo + datos enmascarados).
  Uint8List serialize() {
    final b = BytesBuilder(copy: false);
    final header = Uint8List(4)..setU32le(0, key);
    b.add(header);
    final xk = SCXorShift32(key);
    b.addByte(type.code ^ xk.next());
    if (type == SCTypeCode.object) {
      final len = Uint8List(4)..setU32le(0, data.length ^ xk.next32());
      b.add(len);
    } else if (type == SCTypeCode.array) {
      final count = data.length ~/ subType.size;
      final c = Uint8List(4)..setU32le(0, count ^ xk.next32());
      b.add(c);
      b.addByte(subType.code ^ xk.next());
    }
    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      out[i] = data[i] ^ xk.next();
    }
    b.add(out);
    return b.takeBytes();
  }
}

/// Acceso por clave a un conjunto de bloques.
class SCBlockSet {
  SCBlockSet(List<SCBlock> blocks) : _byKey = {for (final b in blocks) b.key: b};

  final Map<int, SCBlock> _byKey;

  SCBlock? operator [](int key) => _byKey[key];
  bool contains(int key) => _byKey.containsKey(key);
  int get length => _byKey.length;
}
