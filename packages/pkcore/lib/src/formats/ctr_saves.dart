import 'dart:typed_data';

import '../crypto/pk_crypto.dart';
import '../model/game.dart';
import '../model/save.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';
import 'pkm.dart';

/// Saves de 3DS (XY, ORAS, SM, USUM) con pie "BEEF".
/// Offsets portados de PKHeX `SaveBlockAccessor6*/7*` (GPL-3.0).
class CtrLayout {
  const CtrLayout._(this.game, this.size, this.myStatus, this.playTime, this.party, this.box, this.boxLayout,
      this.boxCount, this.otOffset);

  static const xy = CtrLayout._(GameVersion.xy, 0x65600, 0x14000, 0x1800, 0x14200, 0x22600, 0x4400, 31, 0x48);
  static const oras =
      CtrLayout._(GameVersion.omegaRubyAlphaSapphire, 0x76000, 0x14000, 0x1800, 0x14200, 0x33000, 0x4400, 31, 0x48);
  static const sm = CtrLayout._(GameVersion.sunMoon, 0x6BE00, 0x1200, 0x40C00, 0x1400, 0x4E00, 0x4800, 32, 0x38);
  static const usum =
      CtrLayout._(GameVersion.ultraSunUltraMoon, 0x6CC00, 0x1400, 0x41000, 0x1600, 0x5200, 0x4C00, 32, 0x38);
  static const all = [xy, oras, sm, usum];

  final GameVersion game;
  final int size, myStatus, playTime, party, box, boxLayout, boxCount, otOffset;

  static bool hasBeefFooter(Uint8List d) => d.length > 0x1F0 && d.u32le(d.length - 0x1F0) == 0x42454546;

  bool matches(Uint8List d) => d.length == size && hasBeefFooter(d);
}

abstract final class CtrSaveReader {
  static SaveFile read(Uint8List d, CtrLayout l) {
    final s = l.myStatus;
    final gen7 = l.game.generation == 7;
    final trainer = TrainerInfo(
      name: StringCodec.decodeUtf16(d, s + l.otOffset, 0x1A),
      tid: d.u16le(s),
      sid: d.u16le(s + 2),
      gender: d[s + 5],
      language: gen7 ? d[s + 0x35] : d[s + 0x2D],
      playTime: Duration(hours: d.u16le(l.playTime), minutes: d[l.playTime + 2], seconds: d[l.playTime + 3]),
      sixDigitIds: gen7,
    );
    final count = d[l.party + 6 * PkCrypto.size6Party].clamp(0, 6);
    final party = <PokemonSummary>[
      for (var i = 0; i < count; i++) ?PkmReader.pk67(d.copyRange(l.party + i * PkCrypto.size6Party, PkCrypto.size6Party)),
    ];
    final boxes = <PokemonBox>[
      for (var b = 0; b < l.boxCount; b++)
        PokemonBox(
          index: b,
          name: _boxName(d, l.boxLayout + b * 0x22, b),
          slots: [
            for (var i = 0; i < 30; i++)
              PkmReader.pk67(d.copyRange(l.box + (b * 30 + i) * PkCrypto.size6Stored, PkCrypto.size6Stored)),
          ],
        ),
    ];
    final version = d[s + 4];
    return SaveFile(
      game: l.game,
      versionId: version >= 24 && version <= 33 ? version : null,
      trainer: trainer,
      raw: d,
      format: 'Save 3DS (exportado con Checkpoint/JKSM)',
      party: party,
      boxes: boxes,
      support: ReadSupport.full,
    );
  }

  static String _boxName(Uint8List d, int ofs, int index) {
    final n = StringCodec.decodeUtf16(d, ofs, 0x22);
    return n.isEmpty ? 'Caja ${index + 1}' : n;
  }
}
