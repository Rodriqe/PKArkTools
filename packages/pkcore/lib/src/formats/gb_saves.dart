import 'dart:typed_data';

import '../model/game.dart';
import '../model/save.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';
import '../util/checksums.dart';
import 'pkm.dart';

/// Región de un save de Game Boy.
enum GbRegion { international, japanese, korean }

/// Offsets de RBY. Portado de PKHeX `SAV1Offsets` (GPL-3.0).
class Gen1Layout {
  const Gen1Layout._({
    required this.region,
    required this.tid,
    required this.pikaFriendship,
    required this.currentBoxIndex,
    required this.starter,
    required this.playTime,
    required this.party,
    required this.currentBox,
    required this.checksum,
  });

  static const international = Gen1Layout._(
    region: GbRegion.international,
    tid: 0x2605,
    pikaFriendship: 0x271C,
    currentBoxIndex: 0x284C,
    starter: 0x29C3,
    playTime: 0x2CED,
    party: 0x2F2C,
    currentBox: 0x30C0,
    checksum: 0x3523,
  );

  static const japanese = Gen1Layout._(
    region: GbRegion.japanese,
    tid: 0x25FB,
    pikaFriendship: 0x2712,
    currentBoxIndex: 0x2842,
    starter: 0x29B9,
    playTime: 0x2CA0,
    party: 0x2ED5,
    currentBox: 0x302D,
    checksum: 0x3594,
  );

  static const int ot = 0x2598;
  final GbRegion region;
  final int tid, pikaFriendship, currentBoxIndex, starter, playTime, party, currentBox, checksum;

  bool get jp => region == GbRegion.japanese;
  int get stringLength => jp ? 6 : 11;
  int get boxCapacity => jp ? 30 : 20;
  int get boxCount => jp ? 8 : 12;
  int get boxSize => 1 + (boxCapacity + 1) + boxCapacity * (33 + 2 * stringLength);
}

/// Offsets de GSC. Portado de PKHeX `SAV2Offsets` (GPL-3.0).
class Gen2Layout {
  const Gen2Layout._({
    required this.region,
    required this.crystal,
    required this.timePlayed,
    required this.currentBoxIndex,
    required this.boxNames,
    required this.party,
    required this.currentBox,
    required this.gender,
    required this.checksumEnd,
    required this.checksumPos,
  });

  static const goldSilverIntl = Gen2Layout._(
      region: GbRegion.international, crystal: false, timePlayed: 0x2053, currentBoxIndex: 0x2724,
      boxNames: 0x2727, party: 0x288A, currentBox: 0x2D6C, gender: -1, checksumEnd: 0x2D68, checksumPos: 0x2D69);
  static const crystalIntl = Gen2Layout._(
      region: GbRegion.international, crystal: true, timePlayed: 0x2052, currentBoxIndex: 0x2700,
      boxNames: 0x2703, party: 0x2865, currentBox: 0x2D10, gender: 0x3E3D, checksumEnd: 0x2B82, checksumPos: 0x2D0D);
  static const goldSilverJp = Gen2Layout._(
      region: GbRegion.japanese, crystal: false, timePlayed: 0x2034, currentBoxIndex: 0x2705,
      boxNames: 0x2708, party: 0x283E, currentBox: 0x2D10, gender: -1, checksumEnd: 0x2C8B, checksumPos: 0x2D0D);
  static const crystalJp = Gen2Layout._(
      region: GbRegion.japanese, crystal: true, timePlayed: 0x2034, currentBoxIndex: 0x26E2,
      boxNames: 0x26E5, party: 0x281A, currentBox: 0x2D10, gender: 0x8000, checksumEnd: 0x2AE2, checksumPos: 0x2D0D);
  static const goldSilverKor = Gen2Layout._(
      region: GbRegion.korean, crystal: false, timePlayed: 0x204D, currentBoxIndex: 0x26FC,
      boxNames: 0x26FF, party: 0x28CC, currentBox: 0x2DAE, gender: -1, checksumEnd: 0x2DAA, checksumPos: 0x2DAB);

  static const int trainer = 0x2009;
  final GbRegion region;
  final bool crystal;
  final int timePlayed, currentBoxIndex, boxNames, party, currentBox, gender, checksumEnd, checksumPos;

  bool get jp => region == GbRegion.japanese;
  int get stringLength => jp ? 6 : 11;
  int get boxCapacity => jp ? 30 : 20;
  int get boxCount => jp ? 9 : 14;
  int get boxSize => 1 + (boxCapacity + 1) + boxCapacity * (32 + 2 * stringLength);
}

/// Lista de Pokémon de GB: [count][especies N+1][datos N*size][OT N*L][apodos N*L].
bool isGbListValid(Uint8List d, int offset, int maxCount) {
  if (!d.hasRange(offset, maxCount + 2)) return false;
  final count = d[offset];
  return count <= maxCount && d[offset + 1 + count] == 0xFF;
}

abstract final class GbSaveReader {
  static Duration _time(int h, int m, int s) => Duration(hours: h, minutes: m, seconds: s);

  // ---------------- Gen 1 ----------------

  static SaveFile readGen1(Uint8List d, Gen1Layout l, {required bool yellow}) {
    final game = yellow ? GameVersion.yellow : GameVersion.redBlue;
    final name = StringCodec.decodeGb(d, Gen1Layout.ot, l.stringLength, japanese: l.jp);
    final trainer = TrainerInfo(
      name: name,
      tid: d.u16be(l.tid),
      playTime: _time(d[l.playTime], d[l.playTime + 2], d[l.playTime + 3]),
      language: l.jp ? 1 : 2,
    );
    final party = _readList1(d, l.party, 6, 44, l, party: true).whereType<PokemonSummary>().toList();

    final boxes = <PokemonBox>[];
    final current = d[l.currentBoxIndex] & 0x7F;
    final perBank = l.boxCount ~/ 2;
    for (var i = 0; i < l.boxCount; i++) {
      final ofs = i == current
          ? l.currentBox
          : (i < perBank ? 0x4000 + i * l.boxSize : 0x6000 + (i - perBank) * l.boxSize);
      final slots = isGbListValid(d, ofs, l.boxCapacity)
          ? _readList1(d, ofs, l.boxCapacity, 33, l, party: false)
          : List<PokemonSummary?>.filled(l.boxCapacity, null);
      boxes.add(PokemonBox(index: i, name: 'Caja ${i + 1}', slots: slots));
    }

    final expected = Checksums.gen1(d, Gen1Layout.ot, l.checksum);
    return SaveFile(
      game: game,
      trainer: trainer,
      raw: d,
      format: 'SRAM Game Boy (${l.jp ? 'japonés' : 'internacional'})',
      party: party,
      boxes: boxes,
      support: ReadSupport.full,
      checksum: expected == d[l.checksum] ? ChecksumStatus.valid : ChecksumStatus.invalid,
    );
  }

  static List<PokemonSummary?> _readList1(Uint8List d, int ofs, int capacity, int size, Gen1Layout l,
      {required bool party}) {
    final count = d[ofs].clamp(0, capacity);
    final dataStart = ofs + 1 + capacity + 1;
    final otStart = dataStart + capacity * size;
    final nickStart = otStart + capacity * l.stringLength;
    final result = List<PokemonSummary?>.filled(capacity, null);
    for (var i = 0; i < count; i++) {
      final nick = StringCodec.decodeGb(d, nickStart + i * l.stringLength, l.stringLength, japanese: l.jp);
      result[i] = PkmReader.pk1(d, dataStart + i * size, party: party, nickname: nick);
    }
    return party ? result.sublist(0, count) : result;
  }

  // ---------------- Gen 2 ----------------

  static SaveFile readGen2(Uint8List d, Gen2Layout l) {
    final game = l.crystal ? GameVersion.crystal : GameVersion.goldSilver;
    final kor = l.region == GbRegion.korean;
    final name = StringCodec.decodeGb(d, Gen2Layout.trainer + 2, l.stringLength, japanese: l.jp, korean: kor);
    final trainer = TrainerInfo(
      name: name,
      tid: d.u16be(Gen2Layout.trainer),
      gender: l.crystal && l.gender >= 0 && d.hasRange(l.gender, 1) ? (d[l.gender] & 1) : null,
      playTime: _time(d.u16be(l.timePlayed), d[l.timePlayed + 2], d[l.timePlayed + 3]),
      language: switch (l.region) {
        GbRegion.japanese => 1,
        GbRegion.korean => 8,
        GbRegion.international => 2,
      },
    );
    final warnings = <String>[];
    var party = <PokemonSummary>[];
    final boxes = <PokemonBox>[];
    {
      party = _readList2(d, l.party, 6, 48, l, party: true).whereType<PokemonSummary>().toList();
      final current = d[l.currentBoxIndex] & 0x7F;
      final perBankFirst = l.jp ? 6 : 7;
      for (var i = 0; i < l.boxCount; i++) {
        final ofs = i == current
            ? l.currentBox
            : (i < perBankFirst
                ? 0x4000 + i * (l.jp ? 0x54A : 0x450)
                : 0x6000 + (i - perBankFirst) * (l.jp ? 0x54A : 0x450));
        final slots = isGbListValid(d, ofs, l.boxCapacity)
            ? _readList2(d, ofs, l.boxCapacity, 32, l, party: false)
            : List<PokemonSummary?>.filled(l.boxCapacity, null);
        final nl = kor ? 17 : 9;
        final boxName = StringCodec.decodeGb(d, l.boxNames + i * nl, nl, japanese: l.jp, korean: kor);
        boxes.add(PokemonBox(index: i, name: boxName.isEmpty ? 'Caja ${i + 1}' : boxName, slots: slots));
      }
    }

    final sum = Checksums.sum16Bytes(d, Gen2Layout.trainer, l.checksumEnd);
    return SaveFile(
      game: game,
      trainer: trainer,
      raw: d,
      format: 'SRAM Game Boy Color (${switch (l.region) {
        GbRegion.international => 'internacional',
        GbRegion.japanese => 'japonés',
        GbRegion.korean => 'coreano',
      }})',
      party: party,
      boxes: boxes,
      support: ReadSupport.full,
      checksum: sum == d.u16le(l.checksumPos) ? ChecksumStatus.valid : ChecksumStatus.invalid,
      warnings: warnings,
    );
  }

  static List<PokemonSummary?> _readList2(Uint8List d, int ofs, int capacity, int size, Gen2Layout l,
      {required bool party}) {
    final count = d[ofs].clamp(0, capacity);
    final dataStart = ofs + 1 + capacity + 1;
    final otStart = dataStart + capacity * size;
    final nickStart = otStart + capacity * l.stringLength;
    final result = List<PokemonSummary?>.filled(capacity, null);
    for (var i = 0; i < count; i++) {
      final isEgg = d[ofs + 1 + i] == 0xFD;
      final nick = StringCodec.decodeGb(d, nickStart + i * l.stringLength, l.stringLength,
          japanese: l.jp, korean: l.region == GbRegion.korean);
      result[i] = PkmReader.pk2(d, dataStart + i * size, isEgg: isEgg, nickname: nick);
    }
    return party ? result.sublist(0, count) : result;
  }
}
