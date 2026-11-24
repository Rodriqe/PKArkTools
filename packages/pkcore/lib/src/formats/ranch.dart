import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha1;

import '../util/bytes.dart';

/// My Pokémon Ranch (Wii): archivo `pokemonranch.bin` descifrado (el de la
/// NAND de Dolphin). Portado de PKHeX `SAV4Ranch`, `RK4` y `RanchLevel` (GPL-3.0).
///
/// SHA-1 de todo lo que sigue en los primeros 20 bytes; tabla de bloques en
/// 0x18 (big endian); los Pokémon son RK4 de 164 bytes (PK4 de 136 + datos del
/// rancho) seguidos de un marcador de fin.
abstract final class RanchLayout {
  static const int sizeDP = 0x54000;
  static const int sizePt = 0x7C000;
  static const int slotSize = 164;

  static bool identify(Uint8List d) {
    if (d.length == sizeDP && d.u32be(0x22AC) != 0) return _tableOk(d);
    if (d.length == sizePt && d.u32be(0x268C) != 0) return _tableOk(d);
    return false;
  }

  static bool _tableOk(Uint8List d) {
    for (final at in const [0x24, 0x2C, 0x34, 0x3C]) {
      final v = d.u32be(at);
      if (v <= 0x40 || v + 8 > d.length) return false;
    }
    return pokemonStart(d) < d.length;
  }

  static bool platinum(Uint8List d) => d.length == sizePt;
  static int countOffset(Uint8List d) => d.u32be(0x34) + 4;
  static int pokemonStart(Uint8List d) => countOffset(d) + 4;

  /// Huecos que admite el rancho según su nivel (PKHeX `RanchLevel.GetSlotCount`).
  static int capacity(Uint8List d) {
    final level = d[0x5A] + 1;
    const t = [0, 20, 25, 30, 40, 50, 60, 80, 100, 150, 200, 250, 300, 350, 400, 500, 600, 700, 800, 900, 1000];
    final c = level < t.length ? t[level] : 1000;
    return c.clamp(0, (d.length - pokemonStart(d)) ~/ slotSize);
  }

  static bool shaValid(Uint8List d) {
    final h = sha1.convert(Uint8List.sublistView(d, 20)).bytes;
    for (var i = 0; i < 20; i++) {
      if (h[i] != d[i]) return false;
    }
    return true;
  }

  static void setSha(Uint8List d) => d.setRange(0, 20, sha1.convert(Uint8List.sublistView(d, 20)).bytes);

  /// Nombre del dueño del rancho (UTF-16 BE, fin 0xFFFF).
  static String owner(Uint8List d) {
    final out = StringBuffer();
    for (var i = 0x770; i < 0x770 + 0x12; i += 2) {
      final c = d.u16be(i);
      if (c == 0xFFFF || c == 0) break;
      out.writeCharCode(c);
    }
    return out.toString();
  }

  static Duration playTime(Uint8List d) => Duration(seconds: d.u32be(0x60));
}
