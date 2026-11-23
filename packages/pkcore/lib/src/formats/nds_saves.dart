import 'dart:typed_data';

import '../crypto/pk_crypto.dart';
import '../model/game.dart';
import '../model/save.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';
import '../util/checksums.dart';
import 'pkm.dart';

/// Disposición de un save de Gen 4. Portado de PKHeX `SAV4*` (GPL-3.0).
class Gen4Layout {
  const Gen4Layout._(this.game, this.generalSize, this.storageStart, this.storageSize, this.footerSize,
      this.trainer1, this.party, this.boxStart, this.boxStride);

  static const dp = Gen4Layout._(GameVersion.diamondPearl, 0xC100, 0xC100, 0x121E0, 0x14, 0x64, 0x98, 4, 0xFF0);
  static const pt = Gen4Layout._(GameVersion.platinum, 0xCF2C, 0xCF2C, 0x121E4, 0x14, 0x68, 0xA0, 4, 0xFF0);
  static const hgss = Gen4Layout._(GameVersion.heartGoldSoulSilver, 0xF628, 0xF700, 0x12310, 0x10, 0x64, 0x98, 0, 0x1000);

  static const all = [dp, pt, hgss];
  static const int partitionSize = 0x40000;
  static const int magicIntl = 0x20060623;
  static const int magicKorean = 0x20070903;

  final GameVersion game;
  final int generalSize, storageStart, storageSize, footerSize, trainer1, party, boxStart, boxStride;

  /// Detección: el pie del bloque general de la 2ª partición tiene su tamaño y la firma.
  bool matches(Uint8List d) {
    if (d.length != 0x80000) return false;
    final end = partitionSize + generalSize;
    final size = d.u32le(end - 0xC);
    if (size != generalSize) return false;
    final magic = d.u32le(end - 0x8);
    return magic == magicIntl || magic == magicKorean;
  }
}

/// Disposición de un save de Gen 5.
class Gen5Layout {
  const Gen5Layout._(this.game, this.mainSize, this.infoLength);

  static const bw = Gen5Layout._(GameVersion.blackWhite, 0x24000, 0x8C);
  static const b2w2 = Gen5Layout._(GameVersion.black2White2, 0x26000, 0x94);
  static const all = [bw, b2w2];

  final GameVersion game;
  final int mainSize, infoLength;

  int get footerOffset => mainSize - 0x100;

  bool matches(Uint8List d) {
    if (d.length != 0x80000) return false;
    final f = footerOffset;
    final stored = d.u16le(f + infoLength + 0x10 - 2);
    return stored == Checksums.crc16Ccitt(d, f, f + infoLength);
  }
}

abstract final class NdsSaveReader {
  static int _compareCounters(int a, int b) {
    if (a == 0xFFFFFFFF && b != 0xFFFFFFFE) return 1;
    if (b == 0xFFFFFFFF && a != 0xFFFFFFFE) return 0;
    if (a > b) return 0;
    if (a < b) return 1;
    return -1;
  }

  /// 0 = primera partición, 1 = segunda.
  static int _activeBlock(Uint8List d, int begin, int length) {
    final o1 = begin + length - 0x14;
    final o2 = o1 + Gen4Layout.partitionSize;
    final major = _compareCounters(d.u32le(o1), d.u32le(o2));
    if (major != -1) return major;
    final minor = _compareCounters(d.u32le(o1 + 4), d.u32le(o2 + 4));
    return minor == 1 ? 1 : 0;
  }

  static SaveFile readGen4(Uint8List d, Gen4Layout l) {
    final gbo = _activeBlock(d, 0, l.generalSize) == 0 ? 0 : Gen4Layout.partitionSize;
    final sbo = (_activeBlock(d, l.storageStart, l.storageSize) == 0 ? 0 : Gen4Layout.partitionSize) +
        l.storageStart;
    final general = d.view(gbo, l.generalSize);
    final storage = d.view(sbo, l.storageSize);

    final t = l.trainer1;
    final trainer = TrainerInfo(
      name: StringCodec.decodeG4(general, t, 16),
      tid: general.u16le(t + 0x10),
      sid: general.u16le(t + 0x12),
      gender: general[t + 0x18],
      playTime: Duration(hours: general.u16le(t + 0x22), minutes: general[t + 0x24], seconds: general[t + 0x25]),
    );

    final count = general[l.party - 4].clamp(0, 6);
    final party = <PokemonSummary>[
      for (var i = 0; i < count; i++)
        ?PkmReader.pk45(general.copyRange(l.party + i * PkCrypto.size4Party, PkCrypto.size4Party), generation: 4),
    ];
    final namesOfs = l.game == GameVersion.heartGoldSoulSilver ? 0x12008 : 4 + 18 * 0xFF0;
    String boxName(int b) {
      final n = StringCodec.decodeG4(storage, namesOfs + b * 40, 40);
      return n.isEmpty ? 'Caja ${b + 1}' : n;
    }

    final boxes = <PokemonBox>[
      for (var b = 0; b < 18; b++)
        PokemonBox(index: b, name: boxName(b), slots: [
          for (var s = 0; s < 30; s++)
            PkmReader.pk45(
                storage.copyRange(l.boxStart + b * l.boxStride + s * PkCrypto.size4Stored, PkCrypto.size4Stored),
                generation: 4),
        ]),
    ];

    bool blockOk(Uint8List blk) =>
        Checksums.crc16Ccitt(blk, 0, blk.length - l.footerSize) == blk.u16le(blk.length - 2);

    return SaveFile(
      game: l.game,
      trainer: trainer,
      raw: d,
      format: 'EEPROM/Flash NDS 512 KB',
      party: party,
      boxes: boxes,
      support: ReadSupport.full,
      checksum: blockOk(general) && blockOk(storage) ? ChecksumStatus.valid : ChecksumStatus.invalid,
    );
  }

  static SaveFile readGen5(Uint8List d, Gen5Layout l) {
    const p = 0x19400;
    final trainer = TrainerInfo(
      name: StringCodec.decodeUtf16(d, p + 4, 0x10),
      tid: d.u16le(p + 0x14),
      sid: d.u16le(p + 0x16),
      language: d[p + 0x1E],
      gender: d[p + 0x21],
      playTime: Duration(hours: d.u16le(p + 0x24), minutes: d[p + 0x26], seconds: d[p + 0x27]),
    );
    const partyOfs = 0x18E00;
    final count = d[partyOfs + 4].clamp(0, 6);
    final party = <PokemonSummary>[
      for (var i = 0; i < count; i++)
        ?PkmReader.pk45(d.copyRange(partyOfs + 8 + i * PkCrypto.size5Party, PkCrypto.size5Party), generation: 5),
    ];
    String boxName(int b) {
      final n = StringCodec.decodeUtf16(d, 0x28 * b + 4, 0x14);
      return n.isEmpty ? 'Caja ${b + 1}' : n;
    }

    final boxes = <PokemonBox>[
      for (var b = 0; b < 24; b++)
        PokemonBox(index: b, name: boxName(b), slots: [
          for (var s = 0; s < 30; s++)
            PkmReader.pk45(d.copyRange(0x400 + b * 0x1000 + s * PkCrypto.size4Stored, PkCrypto.size4Stored),
                generation: 5),
        ]),
    ];
    final game = d[p + 0x1F];
    return SaveFile(
      game: l.game,
      versionId: const {20, 21, 22, 23}.contains(game) ? game : null,
      trainer: trainer,
      raw: d,
      format: 'Flash NDS 512 KB',
      party: party,
      boxes: boxes,
      support: ReadSupport.full,
      checksum: ChecksumStatus.valid, // validado en la detección (CRC16 de la tabla de bloques)
    );
  }
}
