import 'dart:typed_data';

import '../crypto/pk_crypto.dart';
import '../util/bytes.dart';

/// Datos de Pokémon Box: Rubí y Zafiro (GameCube) sin cabecera GCI.
///
/// 0x76000 bytes: 0x2000 de banner y 58 bloques de 0x2000 (dos copias de 23
/// bloques más 12 «extra» sin copia). Cada bloque: suma (u32 BE) en +0, id en
/// +4, contador de guardado en +8 y 0x1FF0 bytes de datos en +0xC. Los datos
/// de los bloques activos forman el almacenamiento: 25 cajas de 60 huecos
/// (12×5) de 84 bytes (PK3 cifrado + ID32 del depositante). Portado de PKHeX
/// `SAV3RSBox` y `BlockInfoRSBOX` (GPL-3.0).
class RsBoxData {
  RsBoxData._(this.payload, this._blocks) {
    _unpack();
  }

  static const int saveSize = 0x76000;
  static const int blockSize = 0x2000;
  static const int blockCount = 23;
  static const int extraCount = 12;
  static const int _copy = blockSize - 0x10;
  static const int slotSize = PkCrypto.size3Stored + 4;
  static const int boxCount = 50; // 25 cajas de 60, vistas como 50 medias cajas de 30
  static const int _namesOfs = 0x1EC38;

  /// Abre los datos (lanza [FormatException] si no tienen la estructura).
  factory RsBoxData.open(Uint8List payload) {
    if (payload.length != saveSize) throw const FormatException('Tamaño de Pokémon Box incorrecto.');
    final all = <_Block>[
      for (var i = 0; i < 2 * blockCount + extraCount; i++)
        _Block(blockSize + i * blockSize, payload.u32be(blockSize + i * blockSize + 4),
            payload.u32be(blockSize + i * blockSize + 8), i >= 2 * blockCount),
    ];
    var max = 0, at = 0;
    for (var i = 0; i < all.length; i++) {
      if (all[i].counter > max || i == 0) {
        max = all[i].counter;
        at = i;
      }
    }
    final active = at ~/ blockCount;
    final ordered = all.skip(active * blockCount).take(blockCount).toList()..sort((a, b) => a.id.compareTo(b.id));
    final extra = all.skip(2 * blockCount).take(extraCount).toList()..sort((a, b) => a.id.compareTo(b.id));
    for (final b in [...ordered, ...extra]) {
      final ofs = b.id * _copy + (b.extra ? blockCount * blockSize : 0);
      if (ofs + _copy > (blockCount + extraCount) * blockSize) {
        throw FormatException('Id de bloque de Pokémon Box fuera de rango (${b.id}).');
      }
    }
    return RsBoxData._(payload, [...ordered, ...extra]);
  }

  final Uint8List payload;
  final List<_Block> _blocks;
  final Uint8List storage = Uint8List((blockCount + extraCount) * blockSize);

  /// Japonés si el nombre del juego del banner empieza en Shift-JIS (PKHeX).
  bool get japanese => payload[0] == 0x83;

  void _unpack() {
    for (final b in _blocks) {
      final ofs = b.id * _copy + (b.extra ? blockCount * blockSize : 0);
      storage.setRange(ofs, ofs + _copy, payload, b.offset + 0xC);
    }
  }

  /// Offset del hueco [slot] (0–29) de la media caja [box] (0–49).
  static int slotOffset(int box, int slot) {
    final row = slot ~/ 6;
    var col = slot % 6;
    if (box.isOdd) col += 6;
    return 8 + slotSize * (box & ~1) * 30 + (row * 12 + col) * slotSize;
  }

  static int nameOffset(int box) => _namesOfs + 9 * (box ~/ 2);

  static int checksum(Uint8List d, int ofs) {
    var c = 0;
    for (var i = ofs + 4; i < ofs + 4 + 0x1FF8; i += 2) {
      c = (c + d.u16be(i)) & 0xFFFF;
    }
    return ((c << 16) | ((0xF004 - c) & 0xFFFF)) & 0xFFFFFFFF;
  }

  /// `true` si todas las sumas de los bloques activos son correctas.
  bool get checksumsValid => _blocks.every((b) => checksum(payload, b.offset) == payload.u32be(b.offset));

  /// Archivo con el almacenamiento escrito en los mismos bloques y sus sumas.
  Uint8List build() {
    final out = Uint8List.fromList(payload);
    for (final b in _blocks) {
      final ofs = b.id * _copy + (b.extra ? blockCount * blockSize : 0);
      out.setRange(b.offset + 0xC, b.offset + 0xC + _copy, storage, ofs);
      final c = checksum(out, b.offset);
      out[b.offset] = c >> 24;
      out[b.offset + 1] = (c >> 16) & 0xFF;
      out[b.offset + 2] = (c >> 8) & 0xFF;
      out[b.offset + 3] = c & 0xFF;
    }
    return out;
  }

  /// Datos sin cabecera con la primera suma correcta (PKHeX `IsG3RSBox`).
  static bool identify(Uint8List d) => d.length == saveSize && checksum(d, blockSize) == d.u32be(blockSize);
}

class _Block {
  const _Block(this.offset, this.id, this.counter, this.extra);
  final int offset, id, counter;
  final bool extra;
}
