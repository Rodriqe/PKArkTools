import 'dart:typed_data';

import '../crypto/sc_block.dart';
import '../crypto/swish_crypto.dart';
import '../model/game.dart';
import '../model/save.dart';
import '../util/bytes.dart';
import '../util/checksums.dart';

/// Contratos de escritura (Fase 2+). En esta fase solo hay implementaciones
/// de checksums/cifrado, que ya se usan para generar fixtures sintéticos.

/// Recalcula y verifica los checksums de un formato concreto.
abstract interface class ChecksumFixer {
  bool supports(GameVersion game);

  /// `true` si todos los checksums del buffer son correctos.
  bool verify(Uint8List data);

  /// Corrige in situ todos los checksums del buffer.
  void fix(Uint8List data);
}

/// Una edición atómica sobre un save (cambiar nombre, mover Pokémon, …).
abstract interface class SaveEdit {
  String get description;
}

/// Escritor de saves: aplica ediciones y produce bytes exportables con
/// checksums correctos. Se implementará por generación en la Fase 2.
abstract interface class SaveWriter {
  bool canWrite(SaveFile save);

  /// Devuelve un nuevo buffer; nunca modifica `save.raw`.
  Uint8List apply(SaveFile save, List<SaveEdit> edits);
}

/// Checksums de RBY.
class Gen1ChecksumFixer implements ChecksumFixer {
  const Gen1ChecksumFixer({this.japanese = false});
  final bool japanese;
  int get _pos => japanese ? 0x3594 : 0x3523;

  @override
  bool supports(GameVersion game) => game == GameVersion.redBlue || game == GameVersion.yellow;

  @override
  bool verify(Uint8List data) => data[_pos] == Checksums.gen1(data, 0x2598, _pos);

  @override
  void fix(Uint8List data) => data[_pos] = Checksums.gen1(data, 0x2598, _pos);
}

/// Checksum principal de GSC internacional (suma de bytes).
class Gen2ChecksumFixer implements ChecksumFixer {
  const Gen2ChecksumFixer({required this.crystal});
  final bool crystal;

  int get _end => crystal ? 0x2B82 : 0x2D68;
  int get _pos => crystal ? 0x2D0D : 0x2D69;

  @override
  bool supports(GameVersion game) => game == GameVersion.goldSilver || game == GameVersion.crystal;

  @override
  bool verify(Uint8List data) => Checksums.sum16Bytes(data, 0x2009, _end) == data.u16le(_pos);

  @override
  void fix(Uint8List data) => data.setU16le(_pos, Checksums.sum16Bytes(data, 0x2009, _end));
}

/// Checksums por sector de GBA.
class Gen3ChecksumFixer implements ChecksumFixer {
  const Gen3ChecksumFixer();

  @override
  bool supports(GameVersion game) => game.generation == 3;

  @override
  bool verify(Uint8List data) {
    for (var ofs = 0; ofs + 0x1000 <= data.length && ofs < 0x1C000; ofs += 0x1000) {
      if (data.u32le(ofs + 0xFF8) != 0x08012025) continue;
      if (Checksums.checkSum32(data, ofs, 0xF80) != data.u16le(ofs + 0xFF6)) return false;
    }
    return true;
  }

  @override
  void fix(Uint8List data) {
    for (var ofs = 0; ofs + 0x1000 <= data.length && ofs < 0x1C000; ofs += 0x1000) {
      if (data.u32le(ofs + 0xFF8) != 0x08012025) continue;
      data.setU16le(ofs + 0xFF6, Checksums.checkSum32(data, ofs, 0xF80));
    }
  }
}

/// Hash SHA-256 de los saves SwishCrypto: re-serializa y re-cifra.
class SwishChecksumFixer implements ChecksumFixer {
  const SwishChecksumFixer();

  @override
  bool supports(GameVersion game) =>
      game == GameVersion.swordShield ||
      game == GameVersion.legendsArceus ||
      game == GameVersion.scarletViolet ||
      game == GameVersion.legendsZA;

  @override
  bool verify(Uint8List data) => SwishCrypto.isHashValid(data);

  @override
  void fix(Uint8List data) {
    throw UnsupportedError('Usa SwishCrypto.encrypt(bloques) para regenerar el archivo completo.');
  }

  /// Re-cifra una lista de bloques (camino de escritura real para Switch).
  Uint8List rebuild(List<SCBlock> blocks) => SwishCrypto.encrypt(blocks);
}
