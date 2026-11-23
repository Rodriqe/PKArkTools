import 'dart:typed_data';

import '../crypto/pk_crypto.dart';
import '../data/game_data.dart';
import '../formats/nds_saves.dart';
import '../model/game.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';
import '../util/checksums.dart';
import 'events.dart';
import 'pokedex.dart';
import 'save_editor.dart';

int _compareCounters(int a, int b) {
  if (a == 0xFFFFFFFF && b != 0xFFFFFFFE) return 1;
  if (b == 0xFFFFFFFF && a != 0xFFFFFFFE) return 0;
  if (a > b) return 0;
  if (a < b) return 1;
  return -1;
}

int _activeBlock(Uint8List d, int begin, int length) {
  final o1 = begin + length - 0x14;
  final o2 = o1 + Gen4Layout.partitionSize;
  final major = _compareCounters(d.u32le(o1), d.u32le(o2));
  if (major != -1) return major;
  final minor = _compareCounters(d.u32le(o1 + 4), d.u32le(o2 + 4));
  return minor == 1 ? 1 : 0;
}

/// Lee/escribe bolsillos de 4 bytes (u16 objeto, u16 cantidad) — Gen 4–6.
List<InventoryPouch> _readPouches4(Uint8List d, int base, GameVersion game, List<(String, int, int)> defs) => [
      for (final (type, ofs, max) in defs)
        () {
          final legal = ItemTables.pouch(game, type);
          return InventoryPouch(
            type: type,
            capacity: legal.length,
            maxCount: max,
            legalItems: legal,
            items: [
              for (var i = 0; i < legal.length; i++)
                if (d.u16le(base + ofs + i * 4) != 0 && d.u16le(base + ofs + i * 4 + 2) != 0)
                  InventoryItem(d.u16le(base + ofs + i * 4), d.u16le(base + ofs + i * 4 + 2)),
            ],
          );
        }(),
    ];

void _writePouches4(Uint8List d, int base, List<(String, int, int)> defs, List<InventoryPouch> pouches) {
  for (final p in pouches) {
    final def = defs.firstWhere((e) => e.$1 == p.type);
    final items = p.items.where((e) => e.item != 0 && e.count > 0).take(p.capacity).toList();
    for (var i = 0; i < p.capacity; i++) {
      final o = base + def.$2 + i * 4;
      d.setU16le(o, i < items.length ? items[i].item : 0);
      d.setU16le(o + 2, i < items.length ? items[i].count.clamp(1, def.$3) : 0);
    }
  }
}

// =================================================================== Gen 4

/// Editor de Diamante/Perla, Platino y HeartGold/SoulSilver (PKHeX `SAV4`).
class Gen4Editor extends SaveEditor {
  Gen4Editor(this._d, GameVersion game)
      : l = Gen4Layout.all.firstWhere((e) => e.game == game),
        _orig = Uint8List.fromList(_d),
        super(game) {
    _gbo = _activeBlock(_d, 0, l.generalSize) == 0 ? 0 : Gen4Layout.partitionSize;
    _sbo = (_activeBlock(_d, l.storageStart, l.storageSize) == 0 ? 0 : Gen4Layout.partitionSize) + l.storageStart;
  }

  final Uint8List _d;
  final Uint8List _orig;
  final Gen4Layout l;
  late final int _gbo, _sbo;

  Uint8List get _general => _d.view(_gbo, l.generalSize);
  Uint8List get _storage => _d.view(_sbo, l.storageSize);
  bool get _hgss => game == GameVersion.heartGoldSoulSilver;
  int get _boxNames => _hgss ? 0x12008 : 4 + 18 * 0xFF0;

  @override
  int get boxCount => 18;
  @override
  int get boxSlotCount => 30;

  @override
  int get partyCount => _general[l.party - 4].clamp(0, 6);

  @override
  Pkm readPartySlot(int index) =>
      Pkm.fromEncrypted(PkFormat.pk4, _general.copyRange(l.party + index * PkCrypto.size4Party, PkCrypto.size4Party))!;

  @override
  void writeParty(List<Pkm> party) {
    final g = _general;
    g[l.party - 4] = party.length;
    for (var i = 0; i < 6; i++) {
      final o = l.party + i * PkCrypto.size4Party;
      if (i < party.length) {
        g.setRange(o, o + PkCrypto.size4Party, party[i].encryptParty());
      } else {
        g.setRange(o, o + PkCrypto.size4Party, Pkm.blankEncrypted(PkFormat.pk4, party: true));
      }
    }
  }

  int _boxOfs(int b, int s) => l.boxStart + b * l.boxStride + s * PkCrypto.size4Stored;

  @override
  Pkm? readBoxSlot(int box, int slot) {
    final pk = Pkm.fromEncrypted(PkFormat.pk4, _storage.copyRange(_boxOfs(box, slot), PkCrypto.size4Stored));
    return pk != null && pk.checksumValid && pk.species != 0 ? pk : null;
  }

  @override
  void writeBoxSlot(int box, int slot, Pkm? pk) {
    final o = _boxOfs(box, slot);
    if (pk == null) {
      _storage.setRange(o, o + PkCrypto.size4Stored, Pkm.blankEncrypted(PkFormat.pk4));
    } else {
      _storage.setRange(o, o + PkCrypto.size4Stored, pk.encryptStored());
    }
  }

  @override
  String boxName(int box) {
    final n = StringCodec.decodeG4(_storage, _boxNames + box * 40, 40);
    return n.isEmpty ? super.boxName(box) : n;
  }

  @override
  bool get canRenameBoxes => true;
  @override
  void setBoxName(int box, String name) {
    final o = _boxNames + box * 40;
    final enc = StringCodec.encodeG4(name.length > 8 ? name.substring(0, 8) : name, 40);
    // Relleno a cero tras el terminador (como el juego).
    final end = !enc.contains(0xFF) ? 40 : (enc.indexOf(0xFF) + 2).clamp(0, 40);
    enc.fillRange(end, 40, 0);
    _storage.setRange(o, o + 40, enc);
  }

  @override
  Set<TrainerField> get trainerFields => TrainerField.values.toSet();

  @override
  TrainerData readTrainer() {
    final g = _general, t = l.trainer1;
    return TrainerData(
      name: StringCodec.decodeG4(g, t, 16),
      tid: g.u16le(t + 0x10),
      sid: g.u16le(t + 0x12),
      money: g.u32le(t + 0x14),
      gender: g[t + 0x18],
      playTime: Duration(hours: g.u16le(t + 0x22), minutes: g[t + 0x24], seconds: g[t + 0x25]),
    );
  }

  @override
  void writeTrainer(TrainerData tr) {
    final g = _general, t = l.trainer1;
    final old = readTrainer();
    if (tr.name != old.name) g.setRange(t, t + 16, StringCodec.encodeG4(tr.name, 16));
    g.setU16le(t + 0x10, tr.tid & 0xFFFF);
    g.setU16le(t + 0x12, tr.sid & 0xFFFF);
    g.setU32le(t + 0x14, tr.money.clamp(0, maxMoney));
    g[t + 0x18] = (tr.gender ?? old.gender ?? 0) & 1;
    if (tr.playTime != old.playTime) {
      g.setU16le(t + 0x22, tr.playTime.inHours.clamp(0, 9999));
      g[t + 0x24] = tr.playTime.inMinutes % 60;
      g[t + 0x25] = tr.playTime.inSeconds % 60;
    }
  }

  int get _bagBase => switch (game) {
        GameVersion.diamondPearl => 0x624,
        GameVersion.platinum => 0x630,
        _ => 0x644,
      };

  List<(String, int, int)> get _pouchDefs => _hgss
      ? const [
          ('Items', 0x000, 999),
          ('KeyItems', 0x294, 1),
          ('TMHMs', 0x35C, 99),
          ('MailItems', 0x4F0, 999),
          ('Medicine', 0x520, 999),
          ('Berries', 0x5C0, 999),
          ('Balls', 0x6C0, 999),
          ('BattleItems', 0x720, 999),
        ]
      : const [
          ('Items', 0x000, 999),
          ('KeyItems', 0x294, 1),
          ('TMHMs', 0x35C, 99),
          ('MailItems', 0x4EC, 999),
          ('Medicine', 0x51C, 999),
          ('Berries', 0x5BC, 999),
          ('Balls', 0x6BC, 999),
          ('BattleItems', 0x6F8, 999),
        ];

  @override
  List<InventoryPouch>? readInventory() => _readPouches4(_general, _bagBase, game, _pouchDefs);

  @override
  void writeInventory(List<InventoryPouch> pouches) => _writePouches4(_general, _bagBase, _pouchDefs, pouches);

  int get _dexOfs => switch (game) {
        GameVersion.diamondPearl => 0x12DC,
        GameVersion.platinum => 0x1328,
        _ => 0x12B8,
      };

  @override
  Pokedex get pokedex {
    final o = _dexOfs;
    return BitPokedex(_general,
        maxSpecies: 493,
        caught: o + 4,
        seen: [o + 4 + 0x40],
        genderFirst: o + 4 + 0x80,
        genderSecond: o + 4 + 0xC0,
        description: 'Gen 4',
        game: game);
  }

  @override
  EventStore get events {
    final (work, flag) = switch (game) {
      GameVersion.diamondPearl => (0xD9C, 0xFDC),
      GameVersion.platinum => (0xDAC, 0xFEC),
      _ => (0xDE4, 0x10C4),
    };
    return BitEventStore(_general,
        flagOffset: flag,
        flagCount: 0xB60,
        workOffset: work,
        workCount: (flag - work) >> 1,
        labelKey: switch (game) {
          GameVersion.diamondPearl => 'dp',
          GameVersion.platinum => 'pt',
          _ => 'hgss',
        });
  }

  @override
  Uint8List buildPayload() {
    final s = _storage;
    if (_hgss) {
      // Marca de cajas modificadas: el juego solo reescribe las cajas marcadas.
      final origStorage = _orig.view(_sbo, l.storageSize);
      var changed = false;
      for (var i = 0; i < 18 * 0x1000 && !changed; i++) {
        if (s[i] != origStorage[i]) changed = true;
      }
      if (changed) s.setU32le(18 * 0x1000 + 4, 0x3FFFF);
    }
    for (final blk in [_general, s]) {
      final n = blk.length;
      blk.setU16le(n - 2, Checksums.crc16Ccitt(blk, 0, n - l.footerSize));
    }
    return Uint8List.fromList(_d);
  }
}

// =================================================================== Gen 5

/// Editor de Negro/Blanco y Negro 2/Blanco 2 (PKHeX `SAV5`, tabla de bloques con CRC16).
class Gen5Editor extends SaveEditor {
  Gen5Editor(this._d, GameVersion game, {super.versionId})
      : _orig = Uint8List.fromList(_d),
        super(game);

  final Uint8List _d;
  final Uint8List _orig;

  bool get _b2w2 => game == GameVersion.black2White2;
  List<(int, int, int, int)> get _blocks => _b2w2 ? Gen5Blocks.b2w2 : Gen5Blocks.bw;

  static const int _party = 0x18E00;
  static const int _trainer = 0x19400;
  static const int _items = 0x18400;
  int get _misc => _b2w2 ? 0x21100 : 0x21200;

  @override
  int get boxCount => 24;
  @override
  int get boxSlotCount => 30;

  @override
  int get partyCount => _d[_party + 4].clamp(0, 6);

  @override
  Pkm readPartySlot(int index) =>
      Pkm.fromEncrypted(PkFormat.pk5, _d.copyRange(_party + 8 + index * PkCrypto.size5Party, PkCrypto.size5Party))!;

  @override
  void writeParty(List<Pkm> party) {
    _d[_party + 4] = party.length;
    for (var i = 0; i < 6; i++) {
      final o = _party + 8 + i * PkCrypto.size5Party;
      if (i < party.length) {
        _d.setRange(o, o + PkCrypto.size5Party, party[i].encryptParty());
      } else {
        _d.setRange(o, o + PkCrypto.size5Party, Pkm.blankEncrypted(PkFormat.pk5, party: true));
      }
    }
  }

  int _boxOfs(int b, int s) => 0x400 + b * 0x1000 + s * PkCrypto.size4Stored;

  @override
  Pkm? readBoxSlot(int box, int slot) {
    final pk = Pkm.fromEncrypted(PkFormat.pk5, _d.copyRange(_boxOfs(box, slot), PkCrypto.size4Stored));
    return pk != null && pk.checksumValid && pk.species != 0 ? pk : null;
  }

  @override
  void writeBoxSlot(int box, int slot, Pkm? pk) {
    final o = _boxOfs(box, slot);
    if (pk == null) {
      _d.setRange(o, o + PkCrypto.size4Stored, Pkm.blankEncrypted(PkFormat.pk5));
    } else {
      _d.setRange(o, o + PkCrypto.size4Stored, pk.encryptStored());
    }
  }

  @override
  String boxName(int box) {
    final n = StringCodec.decodeUtf16(_d, 0x28 * box + 4, 0x14);
    return n.isEmpty ? super.boxName(box) : n;
  }

  @override
  bool get canRenameBoxes => true;
  @override
  void setBoxName(int box, String name) {
    final o = 0x28 * box + 4;
    _d.setRange(o, o + 0x14, StringCodec.encodeUtf16Gen5(name.length > 8 ? name.substring(0, 8) : name, 0x14));
  }

  @override
  Set<TrainerField> get trainerFields => TrainerField.values.toSet();

  @override
  TrainerData readTrainer() => TrainerData(
        name: StringCodec.decodeUtf16(_d, _trainer + 4, 0x10),
        tid: _d.u16le(_trainer + 0x14),
        sid: _d.u16le(_trainer + 0x16),
        gender: _d[_trainer + 0x21],
        playTime: Duration(hours: _d.u16le(_trainer + 0x24), minutes: _d[_trainer + 0x26], seconds: _d[_trainer + 0x27]),
        money: _d.u32le(_misc),
      );

  @override
  void writeTrainer(TrainerData t) {
    final old = readTrainer();
    if (t.name != old.name) _d.setRange(_trainer + 4, _trainer + 0x14, StringCodec.encodeUtf16Gen5(t.name, 0x10));
    _d.setU16le(_trainer + 0x14, t.tid & 0xFFFF);
    _d.setU16le(_trainer + 0x16, t.sid & 0xFFFF);
    _d[_trainer + 0x21] = (t.gender ?? old.gender ?? 0) & 1;
    if (t.playTime != old.playTime) {
      _d.setU16le(_trainer + 0x24, t.playTime.inHours.clamp(0, 9999));
      _d[_trainer + 0x26] = t.playTime.inMinutes % 60;
      _d[_trainer + 0x27] = t.playTime.inSeconds % 60;
    }
    _d.setU32le(_misc, t.money.clamp(0, maxMoney));
  }

  static const _pouchDefs = [
    ('Items', 0x000, 999),
    ('KeyItems', 0x4D8, 1),
    ('TMHMs', 0x624, 1),
    ('Medicine', 0x7D8, 999),
    ('Berries', 0x898, 999),
  ];

  @override
  List<InventoryPouch>? readInventory() => _readPouches4(_d, _items, game, _pouchDefs);

  @override
  void writeInventory(List<InventoryPouch> pouches) => _writePouches4(_d, _items, _pouchDefs, pouches);

  @override
  Pokedex get pokedex {
    final o = _blocks[_b2w2 ? 54 : 55].$1;
    const r = 0x54;
    return BitPokedex(_d,
        maxSpecies: 649,
        caught: o + 8,
        seen: [o + 0x5C],
        seenFemale: o + 0x5C + r,
        shiny: o + 0x5C + 2 * r,
        shinyFemale: o + 0x5C + 3 * r,
        displayed: o + 0x1AC,
        displayedFemale: o + 0x1AC + r,
        description: 'Gen 5',
        game: game);
  }

  @override
  EventStore get events {
    final o = _blocks[45].$1;
    final work = _b2w2 ? 0x1AF : 0x13E;
    return BitEventStore(_d,
        flagOffset: o + work * 2,
        flagCount: _b2w2 ? 0xBF8 : 0xB60,
        workOffset: o,
        workCount: work,
        labelKey: _b2w2 ? 'b2w2' : 'bw');
  }

  @override
  Uint8List buildPayload() {
    final blocks = _blocks;
    var any = false;
    for (var i = 0; i < blocks.length - 1; i++) {
      final (ofs, len, chk, mirror) = blocks[i];
      if (!forceChecksums && !_changed(ofs, len)) continue;
      any = true;
      final crc = Checksums.crc16Ccitt(_d, ofs, ofs + len);
      _d.setU16le(chk, crc);
      _d.setU16le(mirror, crc);
    }
    if (any) {
      final (ofs, len, chk, _) = blocks.last;
      _d.setU16le(chk, Checksums.crc16Ccitt(_d, ofs, ofs + len));
    }
    return Uint8List.fromList(_d);
  }

  bool _changed(int ofs, int len) {
    for (var i = ofs; i < ofs + len; i++) {
      if (_d[i] != _orig[i]) return true;
    }
    return false;
  }
}

/// Tablas de bloques de Gen 5: (offset, longitud, checksum, espejo). PKHeX `SaveBlockAccessor5*`.
abstract final class Gen5Blocks {
  static const List<(int, int, int, int)> bw = [
    (0x00000, 0x03E0, 0x003E2, 0x23F00), (0x00400, 0x0FF0, 0x013F2, 0x23F02), (0x01400, 0x0FF0, 0x023F2, 0x23F04), //
    (0x02400, 0x0FF0, 0x033F2, 0x23F06), (0x03400, 0x0FF0, 0x043F2, 0x23F08), (0x04400, 0x0FF0, 0x053F2, 0x23F0A), //
    (0x05400, 0x0FF0, 0x063F2, 0x23F0C), (0x06400, 0x0FF0, 0x073F2, 0x23F0E), (0x07400, 0x0FF0, 0x083F2, 0x23F10), //
    (0x08400, 0x0FF0, 0x093F2, 0x23F12), (0x09400, 0x0FF0, 0x0A3F2, 0x23F14), (0x0A400, 0x0FF0, 0x0B3F2, 0x23F16), //
    (0x0B400, 0x0FF0, 0x0C3F2, 0x23F18), (0x0C400, 0x0FF0, 0x0D3F2, 0x23F1A), (0x0D400, 0x0FF0, 0x0E3F2, 0x23F1C), //
    (0x0E400, 0x0FF0, 0x0F3F2, 0x23F1E), (0x0F400, 0x0FF0, 0x103F2, 0x23F20), (0x10400, 0x0FF0, 0x113F2, 0x23F22), //
    (0x11400, 0x0FF0, 0x123F2, 0x23F24), (0x12400, 0x0FF0, 0x133F2, 0x23F26), (0x13400, 0x0FF0, 0x143F2, 0x23F28), //
    (0x14400, 0x0FF0, 0x153F2, 0x23F2A), (0x15400, 0x0FF0, 0x163F2, 0x23F2C), (0x16400, 0x0FF0, 0x173F2, 0x23F2E), //
    (0x17400, 0x0FF0, 0x183F2, 0x23F30), (0x18400, 0x09C0, 0x18DC2, 0x23F32), (0x18E00, 0x0534, 0x19336, 0x23F34), //
    (0x19400, 0x0068, 0x1946A, 0x23F36), (0x19500, 0x009C, 0x1959E, 0x23F38), (0x19600, 0x1338, 0x1A93A, 0x23F3A), //
    (0x1AA00, 0x07C4, 0x1B1C6, 0x23F3C), (0x1B200, 0x0D54, 0x1BF56, 0x23F3E), (0x1C000, 0x002C, 0x1C02E, 0x23F40), //
    (0x1C100, 0x0658, 0x1C75A, 0x23F42), (0x1C800, 0x0A94, 0x1D296, 0x23F44), (0x1D300, 0x01AC, 0x1D4AE, 0x23F46), //
    (0x1D500, 0x03EC, 0x1D8EE, 0x23F48), (0x1D900, 0x005C, 0x1D95E, 0x23F4A), (0x1DA00, 0x01E0, 0x1DBE2, 0x23F4C), //
    (0x1DC00, 0x00A8, 0x1DCAA, 0x23F4E), (0x1DD00, 0x0460, 0x1E162, 0x23F50), (0x1E200, 0x1400, 0x1F602, 0x23F52), //
    (0x1F700, 0x02A4, 0x1F9A6, 0x23F54), (0x1FA00, 0x02DC, 0x1FCDE, 0x23F56), (0x1FD00, 0x034C, 0x2004E, 0x23F58), //
    (0x20100, 0x03EC, 0x204EE, 0x23F5A), (0x20500, 0x00F8, 0x205FA, 0x23F5C), (0x20600, 0x02FC, 0x208FE, 0x23F5E), //
    (0x20900, 0x0094, 0x20996, 0x23F60), (0x20A00, 0x035C, 0x20D5E, 0x23F62), (0x20E00, 0x01CC, 0x20FCE, 0x23F64), //
    (0x21000, 0x0168, 0x2116A, 0x23F66), (0x21200, 0x00EC, 0x212EE, 0x23F68), (0x21300, 0x01B0, 0x214B2, 0x23F6A), //
    (0x21500, 0x001C, 0x2151E, 0x23F6C), (0x21600, 0x04D4, 0x21AD6, 0x23F6E), (0x21B00, 0x0034, 0x21B36, 0x23F70), //
    (0x21C00, 0x003C, 0x21C3E, 0x23F72), (0x21D00, 0x01AC, 0x21EAE, 0x23F74), (0x21F00, 0x0B90, 0x22A92, 0x23F76), //
    (0x22B00, 0x009C, 0x22B9E, 0x23F78), (0x22C00, 0x0850, 0x23452, 0x23F7A), (0x23500, 0x0028, 0x2352A, 0x23F7C), //
    (0x23600, 0x0284, 0x23886, 0x23F7E), (0x23900, 0x0010, 0x23912, 0x23F80), (0x23A00, 0x005C, 0x23A5E, 0x23F82), //
    (0x23B00, 0x016C, 0x23C6E, 0x23F84), (0x23D00, 0x0040, 0x23D42, 0x23F86), (0x23E00, 0x00FC, 0x23EFE, 0x23F88), //
    (0x23F00, 0x008C, 0x23F9A, 0x23F9A),
  ];

  static const List<(int, int, int, int)> b2w2 = [
    (0x00000, 0x03e0, 0x003E2, 0x25F00), (0x00400, 0x0ff0, 0x013F2, 0x25F02), (0x01400, 0x0ff0, 0x023F2, 0x25F04), //
    (0x02400, 0x0ff0, 0x033F2, 0x25F06), (0x03400, 0x0ff0, 0x043F2, 0x25F08), (0x04400, 0x0ff0, 0x053F2, 0x25F0A), //
    (0x05400, 0x0ff0, 0x063F2, 0x25F0C), (0x06400, 0x0ff0, 0x073F2, 0x25F0E), (0x07400, 0x0ff0, 0x083F2, 0x25F10), //
    (0x08400, 0x0ff0, 0x093F2, 0x25F12), (0x09400, 0x0ff0, 0x0A3F2, 0x25F14), (0x0A400, 0x0ff0, 0x0B3F2, 0x25F16), //
    (0x0B400, 0x0ff0, 0x0C3F2, 0x25F18), (0x0C400, 0x0ff0, 0x0D3F2, 0x25F1A), (0x0D400, 0x0ff0, 0x0E3F2, 0x25F1C), //
    (0x0E400, 0x0ff0, 0x0F3F2, 0x25F1E), (0x0F400, 0x0ff0, 0x103F2, 0x25F20), (0x10400, 0x0ff0, 0x113F2, 0x25F22), //
    (0x11400, 0x0ff0, 0x123F2, 0x25F24), (0x12400, 0x0ff0, 0x133F2, 0x25F26), (0x13400, 0x0ff0, 0x143F2, 0x25F28), //
    (0x14400, 0x0ff0, 0x153F2, 0x25F2A), (0x15400, 0x0ff0, 0x163F2, 0x25F2C), (0x16400, 0x0ff0, 0x173F2, 0x25F2E), //
    (0x17400, 0x0ff0, 0x183F2, 0x25F30), (0x18400, 0x09ec, 0x18DEE, 0x25F32), (0x18E00, 0x0534, 0x19336, 0x25F34), //
    (0x19400, 0x00b0, 0x194B2, 0x25F36), (0x19500, 0x00a8, 0x195AA, 0x25F38), (0x19600, 0x1338, 0x1A93A, 0x25F3A), //
    (0x1AA00, 0x07c4, 0x1B1C6, 0x25F3C), (0x1B200, 0x0d54, 0x1BF56, 0x25F3E), (0x1C000, 0x0094, 0x1C096, 0x25F40), //
    (0x1C100, 0x0658, 0x1C75A, 0x25F42), (0x1C800, 0x0a94, 0x1D296, 0x25F44), (0x1D300, 0x01ac, 0x1D4AE, 0x25F46), //
    (0x1D500, 0x03ec, 0x1D8EE, 0x25F48), (0x1D900, 0x005c, 0x1D95E, 0x25F4A), (0x1DA00, 0x01e0, 0x1DBE2, 0x25F4C), //
    (0x1DC00, 0x00a8, 0x1DCAA, 0x25F4E), (0x1DD00, 0x0460, 0x1E162, 0x25F50), (0x1E200, 0x1400, 0x1F602, 0x25F52), //
    (0x1F700, 0x02a4, 0x1F9A6, 0x25F54), (0x1FA00, 0x00e0, 0x1FAE2, 0x25F56), (0x1FB00, 0x034c, 0x1FE4E, 0x25F58), //
    (0x1FF00, 0x04e0, 0x203E2, 0x25F5A), (0x20400, 0x00f8, 0x204FA, 0x25F5C), (0x20500, 0x02fc, 0x207FE, 0x25F5E), //
    (0x20800, 0x0094, 0x20896, 0x25F60), (0x20900, 0x035c, 0x20C5E, 0x25F62), (0x20D00, 0x01d4, 0x20ED6, 0x25F64), //
    (0x20F00, 0x01e0, 0x210E2, 0x25F66), (0x21100, 0x00f0, 0x211F2, 0x25F68), (0x21200, 0x01b4, 0x213B6, 0x25F6A), //
    (0x21400, 0x04dc, 0x218DE, 0x25F6C), (0x21900, 0x0034, 0x21936, 0x25F6E), (0x21A00, 0x003c, 0x21A3E, 0x25F70), //
    (0x21B00, 0x01ac, 0x21CAE, 0x25F72), (0x21D00, 0x0b90, 0x22892, 0x25F74), (0x22900, 0x00ac, 0x229AE, 0x25F76), //
    (0x22A00, 0x0850, 0x23252, 0x25F78), (0x23300, 0x0284, 0x23586, 0x25F7A), (0x23600, 0x0010, 0x23612, 0x25F7C), //
    (0x23700, 0x00a8, 0x237AA, 0x25F7E), (0x23800, 0x016c, 0x2396E, 0x25F80), (0x23A00, 0x0080, 0x23A82, 0x25F82), //
    (0x23B00, 0x00fc, 0x23BFE, 0x25F84), (0x23C00, 0x16a8, 0x252AA, 0x25F86), (0x25300, 0x0498, 0x2579A, 0x25F88), //
    (0x25800, 0x0060, 0x25862, 0x25F8A), (0x25900, 0x00fc, 0x259FE, 0x25F8C), (0x25A00, 0x03e4, 0x25DE6, 0x25F8E), //
    (0x25E00, 0x00f0, 0x25EF2, 0x25F90), (0x25F00, 0x0094, 0x25FA2, 0x25FA2),
  ];
}
