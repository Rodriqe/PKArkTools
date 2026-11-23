import 'dart:typed_data';

import '../data/generated/charsets.dart';

/// Decodificación (y codificación básica, para fixtures y fases futuras)
/// de los juegos de caracteres propietarios de cada generación.
abstract final class StringCodec {
  // ---- Gen 1/2 ----

  /// Decodifica texto GB (terminador 0x50). [japanese] usa la tabla japonesa
  /// y [korean] la codificación de Oro/Plata coreano (1 o 2 bytes por carácter).
  static String decodeGb(Uint8List data, int offset, int length,
      {bool japanese = false, bool korean = false}) {
    if (korean) return decodeGbKor(data, offset, length);
    final table = japanese ? kCharsG1Jp : kCharsG1En;
    final sb = StringBuffer();
    for (var i = offset; i < offset + length && i < data.length; i++) {
      final b = data[i];
      if (b == 0x50 || b == 0x00) break;
      if (b == 0x5D && i == offset) return '*'; // Entrenador de intercambio
      final c = table[b];
      if (c == 0) break;
      sb.writeCharCode(c);
    }
    return sb.toString().trim();
  }

  /// Codifica a la tabla GB (internacional, japonesa o coreana), rellenando con 0x50.
  static Uint8List encodeGb(String value, int length, {bool japanese = false, bool korean = false}) {
    if (korean) return encodeGbKor(value, length);
    final table = japanese ? kCharsG1Jp : kCharsG1En;
    final out = Uint8List(length)..fillRange(0, length, 0x50);
    var i = 0;
    for (final r in value.runes) {
      if (i >= length - 1) break;
      var idx = r == 0x20 ? 0x7F : table.indexOf(r);
      if (idx <= 0) idx = table.indexOf(r == 0x2E ? 0x2024 : 0x3F);
      out[i++] = idx < 0 ? 0xE6 /* ? */ : idx;
    }
    return out;
  }

  // ---- Gen 2 coreano (PKHeX `StringConverter2KOR`) ----

  static const List<List<int>> _korTables = [
    kCharsG2Kor0, kCharsG2Kor1, kCharsG2Kor2, kCharsG2Kor3, kCharsG2Kor4, kCharsG2Kor5, //
    kCharsG2Kor6, kCharsG2Kor7, kCharsG2Kor8, kCharsG2Kor9, kCharsG2KorA, kCharsG2KorB,
  ];

  static String decodeGbKor(Uint8List data, int offset, int length) {
    final end = (offset + length).clamp(0, data.length);
    if (offset < end && data[offset] == 0x5D) return '*';
    final sb = StringBuffer();
    for (var i = offset; i < end; i++) {
      var v = data[i];
      if (v == 0) break;
      var table = kCharsG2Kor0;
      if (v <= 11) {
        if (++i >= end) break;
        table = _korTables[v];
        v = data[i];
      }
      final c = table[v];
      if (c == 0) break;
      sb.writeCharCode(c);
    }
    return sb.toString().trim();
  }

  static Uint8List encodeGbKor(String value, int length) {
    final out = Uint8List(length)..fillRange(0, length, 0x50);
    if (value.startsWith('*')) {
      out[0] = 0x5D;
      return out;
    }
    var i = 0;
    for (final r in value.runes) {
      var done = false;
      for (var t = 1; t <= 11 && !done; t++) {
        final idx = _korTables[t].indexOf(r);
        if (idx > 0) {
          if (i + 2 > length - 1) return out;
          out[i++] = t;
          out[i++] = idx;
          done = true;
        }
      }
      if (done) continue;
      final idx = kCharsG2Kor0.indexOf(r == 0x20 ? 0x20 : r);
      if (idx <= 0 || idx == 0x50) break;
      if (i + 1 > length - 1) break;
      out[i++] = idx;
    }
    return out;
  }

  /// `true` si la cadena codificada parece coreana (primer byte = página 1..B).
  static bool looksKorean(Uint8List data, int offset) => offset < data.length && data[offset] >= 1 && data[offset] <= 11;

  // ---- Gen 3 ----

  static String decodeG3(Uint8List data, int offset, int length,
      {bool japanese = false}) {
    final table = japanese ? kCharsG3Jp : kCharsG3En;
    final sb = StringBuffer();
    for (var i = offset; i < offset + length && i < data.length; i++) {
      final b = data[i];
      if (b == 0xFF) break;
      final c = table[b];
      if (c == 0) break;
      sb.writeCharCode(_normalizeGender(c));
    }
    return sb.toString();
  }

  static Uint8List encodeG3(String value, int length, {bool japanese = false}) {
    final table = japanese ? kCharsG3Jp : kCharsG3En;
    final out = Uint8List(length)..fillRange(0, length, 0xFF);
    var i = 0;
    for (final r in value.runes) {
      if (i >= length) break;
      final c = switch (r) {
        0x2642 => 0x246D,
        0x2640 => 0x246E,
        _ => r,
      };
      var idx = table.indexOf(c);
      if (idx < 0) idx = table.indexOf(r);
      out[i++] = idx < 0 ? 0xAC /* ? */ : idx;
    }
    return out;
  }

  // ---- Gen 4 ----

  static String decodeG4(Uint8List data, int offset, int length) {
    final sb = StringBuffer();
    for (var i = offset; i + 1 < offset + length && i + 1 < data.length; i += 2) {
      final v = data[i] | (data[i + 1] << 8);
      if (v == 0xFFFF || v == 0) break;
      if (v >= kCharsG4.length) {
        sb.write('?');
        continue;
      }
      final c = kCharsG4[v];
      if (c == 0) break;
      sb.writeCharCode(_normalizeGender(c));
    }
    return sb.toString();
  }

  static Uint8List encodeG4(String value, int length) {
    final out = Uint8List(length)..fillRange(0, length, 0xFF);
    var i = 0;
    for (final r0 in value.runes) {
      if (i + 3 >= length) break;
      final r = switch (r0) {
        0x2642 => 0x246D,
        0x2640 => 0x246E,
        _ => r0,
      };
      var idx = kCharsG4.indexOf(r);
      if (idx <= 0) idx = kCharsG4.indexOf(r0);
      final v = idx <= 0 ? 0x01AC : idx;
      out[i] = v & 0xFF;
      out[i + 1] = v >> 8;
      i += 2;
    }
    return out;
  }

  // ---- Gen 5+ (UTF-16LE con terminador 0x0000 o 0xFFFF) ----

  static String decodeUtf16(Uint8List data, int offset, int length) {
    final units = <int>[];
    for (var i = offset; i + 1 < offset + length && i + 1 < data.length; i += 2) {
      final v = data[i] | (data[i + 1] << 8);
      if (v == 0 || v == 0xFFFF) break;
      units.add(_remapUtf16(v));
    }
    return String.fromCharCodes(units);
  }

  /// UTF-16LE con terminador 0x0000 (Gen 6+). Los símbolos ♂/♀ usan la fuente privada del juego.
  static Uint8List encodeUtf16(String value, int length, {bool remapGender = true}) {
    final out = Uint8List(length);
    var i = 0;
    for (final u0 in value.codeUnits) {
      if (i + 3 >= length) break;
      final u = !remapGender
          ? u0
          : switch (u0) {
              0x2642 => 0xE08E,
              0x2640 => 0xE08F,
              _ => u0,
            };
      out[i] = u & 0xFF;
      out[i + 1] = u >> 8;
      i += 2;
    }
    return out;
  }

  /// UTF-16LE de Gen 5: terminador 0xFFFF y relleno a cero.
  static Uint8List encodeUtf16Gen5(String value, int length) {
    final out = encodeUtf16(value, length);
    final end = value.length * 2;
    if (end + 1 < length) {
      out[end] = 0xFF;
      out[end + 1] = 0xFF;
    }
    return out;
  }

  // Símbolos de género de las fuentes de Game Freak.
  static int _normalizeGender(int c) => switch (c) {
        0x246D => 0x2642, // ♂
        0x246E => 0x2640, // ♀
        _ => c,
      };

  static int _remapUtf16(int v) => switch (v) {
        0xE08E => 0x2642, // ♂ (fuente privada Gen 5–7)
        0xE08F => 0x2640, // ♀
        0x246D => 0x2642,
        0x246E => 0x2640,
        _ => v,
      };
}
