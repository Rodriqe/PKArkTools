import 'dart:typed_data';

import '../data/game_data.dart';
import '../data/species_convert.dart';
import '../formats/gb_saves.dart';
import '../model/game.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';
import '../util/checksums.dart';
import 'events.dart';
import 'pokedex.dart';
import 'save_editor.dart';

/// Lista de Pokémon de Game Boy: [n][especies…FF][datos][OT][apodos].
/// En las cajas no hay huecos: la lista siempre está compactada.
class _GbList {
  const _GbList(this.offset, this.capacity, this.format,
      {required this.party, required this.japanese, this.korean = false});

  final int offset;
  final int capacity;
  final PkFormat format;
  final bool party;
  final bool japanese;
  final bool korean;

  int get strLen => japanese ? 6 : 11;
  int get structSize => party ? format.partySize : format.storedSize;
  int get dataStart => offset + 1 + capacity + 1;
  int get otStart => dataStart + capacity * structSize;
  int get nickStart => otStart + capacity * strLen;
  int get length => nickStart + capacity * strLen - offset;

  List<Pkm> read(Uint8List d) {
    if (!isGbListValid(d, offset, capacity)) return [];
    final count = d[offset].clamp(0, capacity);
    return [
      for (var i = 0; i < count; i++)
        Pkm.fromGb(
          format,
          d.copyRange(dataStart + i * structSize, structSize),
          nickname: StringCodec.decodeGb(d, nickStart + i * strLen, strLen, japanese: japanese, korean: korean),
          otName: StringCodec.decodeGb(d, otStart + i * strLen, strLen, japanese: japanese, korean: korean),
          japanese: japanese,
          korean: korean,
          egg: format == PkFormat.pk2 && d[offset + 1 + i] == 0xFD,
        ),
    ];
  }

  void write(Uint8List d, List<Pkm> mons) {
    final count = mons.length.clamp(0, capacity);
    d[offset] = count;
    for (var i = 0; i < count; i++) {
      final p = mons[i];
      d[offset + 1 + i] = p.isEgg ? 0xFD : p.data[0];
    }
    d[offset + 1 + count] = 0xFF;
    for (var i = count + 1; i <= capacity; i++) {
      d[offset + 1 + i] = 0x00;
    }
    for (var i = 0; i < capacity; i++) {
      final ds = dataStart + i * structSize;
      final os = otStart + i * strLen;
      final ns = nickStart + i * strLen;
      if (i < count) {
        final p = mons[i];
        d.setRange(ds, ds + structSize, p.data);
        d.setRange(os, os + strLen, StringCodec.encodeGb(p.otName, strLen, japanese: japanese, korean: korean));
        d.setRange(ns, ns + strLen, StringCodec.encodeGb(p.nickname, strLen, japanese: japanese, korean: korean));
      } else {
        d.fillRange(ds, ds + structSize, 0);
        d.fillRange(os, os + strLen, 0x50);
        d.fillRange(ns, ns + strLen, 0x50);
      }
    }
  }
}

/// Objetos en formato GB: [n][(id, cantidad)…][FF] o lista de ids (clave) o array fijo (MT).
List<InventoryItem> _readGbPouch(Uint8List d, int ofs, String type, int capacity, List<int> legal) {
  if (type == 'TMHMs') {
    return [
      for (var i = 0; i < legal.length; i++)
        if (d[ofs + i] != 0) InventoryItem(legal[i], d[ofs + i]),
    ];
  }
  var n = d[ofs];
  if (n > capacity) n = 0;
  if (type == 'KeyItems') return [for (var i = 0; i < n; i++) InventoryItem(d[ofs + 1 + i], 1)];
  return [for (var i = 0; i < n; i++) InventoryItem(d[ofs + 1 + i * 2], d[ofs + 2 + i * 2])];
}

void _writeGbPouch(Uint8List d, int ofs, InventoryPouch p) {
  final items = p.items.where((e) => e.item != 0 && e.count > 0).take(p.capacity).toList();
  switch (p.type) {
    case 'TMHMs':
      for (var i = 0; i < p.legalItems.length; i++) {
        d[ofs + i] = 0;
      }
      for (final it in items) {
        final i = p.legalItems.indexOf(it.item);
        if (i >= 0) d[ofs + i] = it.count.clamp(0, p.maxCount);
      }
    case 'KeyItems':
      d[ofs] = items.length;
      for (var i = 0; i < items.length; i++) {
        d[ofs + 1 + i] = items[i].item;
      }
      d[ofs + 1 + items.length] = 0xFF;
    default:
      d[ofs] = items.length;
      for (var i = 0; i < items.length; i++) {
        d[ofs + 1 + i * 2] = items[i].item;
        d[ofs + 2 + i * 2] = items[i].count.clamp(1, p.maxCount);
      }
      d[ofs + 1 + 2 * items.length] = 0xFF;
  }
}

int _bcdToInt(Uint8List d, int ofs, int len) {
  var v = 0;
  for (var i = 0; i < len; i++) {
    v = v * 100 + ((d[ofs + i] >> 4) & 0xF) * 10 + (d[ofs + i] & 0xF);
  }
  return v;
}

void _intToBcd(Uint8List d, int ofs, int len, int value) {
  var v = value;
  for (var i = len - 1; i >= 0; i--) {
    final two = v % 100;
    d[ofs + i] = ((two ~/ 10) << 4) | (two % 10);
    v ~/= 100;
  }
}

// =================================================================== Gen 1

/// Editor de Rojo/Azul/Amarillo. Offsets: PKHeX `SAV1` (GPL-3.0).
class Gen1Editor extends SaveEditor {
  Gen1Editor._(this._d, super.game, this.l) : _orig = Uint8List.fromList(_d);

  factory Gen1Editor.open(Uint8List payload, GameVersion game) {
    final jp = isGbListValid(payload, 0x2ED5, 30) && isGbListValid(payload, 0x302D, 30);
    return Gen1Editor._(payload, game, jp ? Gen1Layout.japanese : Gen1Layout.international);
  }

  final Uint8List _d;
  final Uint8List _orig;
  final Gen1Layout l;

  int get _items => l.jp ? 0x25C4 : 0x25C9;
  int get _money => l.jp ? 0x25EE : 0x25F3;
  int get _pcItems => l.jp ? 0x27DC : 0x27E6;

  _GbList get _partyList => _GbList(l.party, 6, PkFormat.pk1, party: true, japanese: l.jp);
  int get _current => _d[l.currentBoxIndex] & 0x7F;
  int get _perBank => l.boxCount ~/ 2;
  int _bankOffset(int box) => box < _perBank ? 0x4000 + box * l.boxSize : 0x6000 + (box - _perBank) * l.boxSize;
  _GbList _boxList(int box) =>
      _GbList(box == _current ? l.currentBox : _bankOffset(box), l.boxCapacity, PkFormat.pk1, party: false, japanese: l.jp);

  @override
  int get boxCount => l.boxCount;
  @override
  int get boxSlotCount => l.boxCapacity;
  @override
  int get maxMoney => 999999;
  @override
  int get maxTrainerNameLength => l.jp ? 5 : 7;

  @override
  int get partyCount => _partyList.read(_d).length;
  @override
  Pkm readPartySlot(int index) => _partyList.read(_d)[index];
  @override
  void writeParty(List<Pkm> party) => _partyList.write(_d, party);

  @override
  Pkm? readBoxSlot(int box, int slot) {
    final list = _boxList(box).read(_d);
    return slot < list.length ? list[slot] : null;
  }

  @override
  void writeBoxSlot(int box, int slot, Pkm? pk) {
    final list = _boxList(box).read(_d);
    if (pk == null) {
      if (slot < list.length) list.removeAt(slot);
    } else if (slot < list.length) {
      list[slot] = pk;
    } else {
      if (list.length >= l.boxCapacity) throw const SaveEditException('La caja está llena.');
      list.add(pk);
    }
    _writeBox(box, list);
  }

  void _writeBox(int box, List<Pkm> list) {
    // La caja actual vive en la WRAM del save y también en su banco.
    _GbList(_bankOffset(box), l.boxCapacity, PkFormat.pk1, party: false, japanese: l.jp).write(_d, list);
    if (box == _current) {
      _GbList(l.currentBox, l.boxCapacity, PkFormat.pk1, party: false, japanese: l.jp).write(_d, list);
    } else {
      _d[l.currentBoxIndex] |= 0x80; // cajas inicializadas
    }
  }

  @override
  Set<TrainerField> get trainerFields => {TrainerField.name, TrainerField.tid, TrainerField.money, TrainerField.playTime};

  @override
  TrainerData readTrainer() => TrainerData(
        name: StringCodec.decodeGb(_d, Gen1Layout.ot, l.stringLength, japanese: l.jp),
        tid: _d.u16be(l.tid),
        money: _bcdToInt(_d, _money, 3),
        playTime: Duration(hours: _d[l.playTime], minutes: _d[l.playTime + 2], seconds: _d[l.playTime + 3]),
      );

  @override
  void writeTrainer(TrainerData t) {
    final old = readTrainer();
    if (t.name != old.name) {
      _d.setRange(Gen1Layout.ot, Gen1Layout.ot + l.stringLength, StringCodec.encodeGb(t.name, l.stringLength, japanese: l.jp));
    }
    _d.setU16be(l.tid, t.tid & 0xFFFF);
    _intToBcd(_d, _money, 3, t.money.clamp(0, maxMoney));
    if (t.playTime != old.playTime) {
      _d[l.playTime] = t.playTime.inHours.clamp(0, 255);
      _d[l.playTime + 2] = t.playTime.inMinutes % 60;
      _d[l.playTime + 3] = t.playTime.inSeconds % 60;
    }
  }

  @override
  List<InventoryPouch>? readInventory() {
    final legal = ItemTables.pouch(game, 'Items');
    return [
      InventoryPouch(type: 'Items', capacity: 20, maxCount: 99, legalItems: legal, items: _readGbPouch(_d, _items, 'Items', 20, legal)),
      InventoryPouch(
          type: 'PCItems', capacity: 50, maxCount: 99, legalItems: legal, items: _readGbPouch(_d, _pcItems, 'PCItems', 50, legal)),
    ];
  }

  @override
  void writeInventory(List<InventoryPouch> pouches) {
    for (final p in pouches) {
      _writeGbPouch(_d, p.type == 'PCItems' ? _pcItems : _items, p);
    }
  }

  @override
  Pokedex get pokedex => BitPokedex(_d,
      maxSpecies: 151, caught: l.jp ? 0x259E : 0x25A3, seen: [l.jp ? 0x25B1 : 0x25B6], description: 'Gen 1');

  @override
  EventStore get events => BitEventStore(_d, flagOffset: l.jp ? 0x29E9 : 0x29F3, flagCount: 0xA00);

  @override
  Uint8List buildPayload() {
    // Checksums de banco (cajas): solo si el original ya los tenía válidos.
    for (final bank in const [0x4000, 0x6000]) {
      final all = bank + _perBank * l.boxSize;
      if (_bankValid(_orig, bank, all)) {
        _d[all] = Checksums.gen1(_d, bank, all);
        for (var i = 0; i < _perBank; i++) {
          final s = bank + i * l.boxSize;
          _d[all + 1 + i] = Checksums.gen1(_d, s, s + l.boxSize);
        }
      }
    }
    _d[l.checksum] = Checksums.gen1(_d, Gen1Layout.ot, l.checksum);
    return Uint8List.fromList(_d);
  }

  bool _bankValid(Uint8List d, int bank, int all) {
    if (d[all] != Checksums.gen1(d, bank, all)) return false;
    for (var i = 0; i < _perBank; i++) {
      final s = bank + i * l.boxSize;
      if (d[all + 1 + i] != Checksums.gen1(d, s, s + l.boxSize)) return false;
    }
    return true;
  }
}

// =================================================================== Gen 2

/// Offsets de escritura de GSC (PKHeX `SAV2Offsets`).
class Gen2Extra {
  const Gen2Extra(this.money, this.tmhm, this.item, this.key, this.ball, this.pc, this.checksum2);
  final int money, tmhm, item, key, ball, pc, checksum2;

  static Gen2Extra of(Gen2Layout l) => switch ((l.region, l.crystal)) {
        (GbRegion.international, false) => const Gen2Extra(0x23DB, 0x23E6, 0x241F, 0x2449, 0x2464, 0x247E, 0x7E6D),
        (GbRegion.international, true) => const Gen2Extra(0x23DC, 0x23E7, 0x2420, 0x244A, 0x2465, 0x247F, 0x1F0D),
        (GbRegion.japanese, false) => const Gen2Extra(0x23BC, 0x23C7, 0x2400, 0x242A, 0x2445, 0x245F, 0x7F0D),
        (GbRegion.japanese, true) => const Gen2Extra(0x23BE, 0x23C9, 0x2402, 0x242C, 0x2447, 0x2461, 0x7F0D),
        _ => const Gen2Extra(0x23D3, 0x23DE, 0x2417, 0x2441, 0x245C, 0x2476, 0x7E6B),
      };
}

/// Editor de Oro/Plata/Cristal. Offsets: PKHeX `SAV2` (GPL-3.0).
class Gen2Editor extends SaveEditor {
  Gen2Editor._(this._d, super.game, this.l) : x = Gen2Extra.of(l);

  factory Gen2Editor.open(Uint8List payload, GameVersion game) {
    const candidates = [
      (0x288A, 0x2D6C, 20),
      (0x2865, 0x2D10, 20),
      (0x2D10, 0x283E, 30),
      (0x2D10, 0x281A, 30),
      (0x2DAE, 0x28CC, 20),
    ];
    const layouts = [
      Gen2Layout.goldSilverIntl,
      Gen2Layout.crystalIntl,
      Gen2Layout.goldSilverJp,
      Gen2Layout.crystalJp,
      Gen2Layout.goldSilverKor,
    ];
    for (var i = 0; i < candidates.length; i++) {
      final (a, b, m) = candidates[i];
      if (isGbListValid(payload, a, m) && isGbListValid(payload, b, m)) {
        return Gen2Editor._(payload, game, layouts[i]);
      }
    }
    throw const SaveEditException('Disposición de Gen 2 no reconocida.');
  }

  final Uint8List _d;
  final Gen2Layout l;
  final Gen2Extra x;

  bool get _kor => l.region == GbRegion.korean;
  int get _boxNameLen => _kor ? 17 : 9;

  int get _current => _d[l.currentBoxIndex] & 0x7F;
  int get _stride => l.jp ? 0x54A : 0x450;
  int get _firstBank => l.jp ? 6 : 7;
  int _bankOffset(int b) => b < _firstBank ? 0x4000 + b * _stride : 0x6000 + (b - _firstBank) * _stride;

  _GbList _list(int ofs, {bool party = false}) =>
      _GbList(ofs, party ? 6 : l.boxCapacity, PkFormat.pk2, party: party, japanese: l.jp, korean: _kor);
  _GbList get _partyList => _list(l.party, party: true);
  _GbList _boxList(int box) => _list(box == _current ? l.currentBox : _bankOffset(box));

  @override
  int get boxCount => l.boxCount;
  @override
  int get boxSlotCount => l.boxCapacity;
  @override
  int get maxMoney => 999999;
  @override
  int get maxTrainerNameLength => l.jp || _kor ? 5 : 7;

  @override
  int get partyCount => _partyList.read(_d).length;
  @override
  Pkm readPartySlot(int index) => _partyList.read(_d)[index];
  @override
  void writeParty(List<Pkm> party) => _partyList.write(_d, party);

  @override
  Pkm? readBoxSlot(int box, int slot) {
    final list = _boxList(box).read(_d);
    return slot < list.length ? list[slot] : null;
  }

  @override
  void writeBoxSlot(int box, int slot, Pkm? pk) {
    final list = _boxList(box).read(_d);
    if (pk == null) {
      if (slot < list.length) list.removeAt(slot);
    } else if (slot < list.length) {
      list[slot] = pk;
    } else {
      if (list.length >= l.boxCapacity) throw const SaveEditException('La caja está llena.');
      list.add(pk);
    }
    _list(_bankOffset(box)).write(_d, list);
    if (box == _current) _list(l.currentBox).write(_d, list);
  }

  @override
  String boxName(int box) {
    final n = StringCodec.decodeGb(_d, l.boxNames + box * _boxNameLen, _boxNameLen, japanese: l.jp, korean: _kor);
    return n.isEmpty ? super.boxName(box) : n;
  }

  @override
  bool get canRenameBoxes => true;

  @override
  void setBoxName(int box, String name) {
    final o = l.boxNames + box * _boxNameLen;
    _d.setRange(o, o + _boxNameLen, StringCodec.encodeGb(name, _boxNameLen, japanese: l.jp, korean: _kor));
  }

  @override
  Set<TrainerField> get trainerFields => {
        TrainerField.name,
        TrainerField.tid,
        TrainerField.money,
        TrainerField.playTime,
        if (l.crystal && l.gender >= 0 && l.gender < _d.length) TrainerField.gender,
      };

  @override
  TrainerData readTrainer() => TrainerData(
        name: StringCodec.decodeGb(_d, Gen2Layout.trainer + 2, l.stringLength, japanese: l.jp, korean: _kor),
        tid: _d.u16be(Gen2Layout.trainer),
        money: (_d[x.money] << 16) | (_d[x.money + 1] << 8) | _d[x.money + 2],
        playTime: Duration(hours: _d.u16be(l.timePlayed), minutes: _d[l.timePlayed + 2], seconds: _d[l.timePlayed + 3]),
        gender: l.crystal && l.gender >= 0 && l.gender < _d.length ? _d[l.gender] & 1 : null,
      );

  @override
  void writeTrainer(TrainerData t) {
    final old = readTrainer();
    if (t.name != old.name) {
      // En coreano el nombre ocupa 2 × 5 bytes (+ terminador) dentro de los 11 del campo.
      _d.setRange(Gen2Layout.trainer + 2, Gen2Layout.trainer + 2 + l.stringLength,
          StringCodec.encodeGb(t.name, l.stringLength, japanese: l.jp, korean: _kor));
    }
    _d.setU16be(Gen2Layout.trainer, t.tid & 0xFFFF);
    final m = t.money.clamp(0, maxMoney);
    _d[x.money] = (m >> 16) & 0xFF;
    _d[x.money + 1] = (m >> 8) & 0xFF;
    _d[x.money + 2] = m & 0xFF;
    if (t.playTime != old.playTime) {
      _d.setU16be(l.timePlayed, t.playTime.inHours.clamp(0, 999));
      _d[l.timePlayed + 2] = t.playTime.inMinutes % 60;
      _d[l.timePlayed + 3] = t.playTime.inSeconds % 60;
    }
    if (t.gender != null && trainerFields.contains(TrainerField.gender)) {
      _d[l.gender] = (_d[l.gender] & ~1) | (t.gender! & 1);
    }
  }

  @override
  List<InventoryPouch>? readInventory() {
    InventoryPouch p(String type, int ofs, int cap) {
      final legal = ItemTables.pouch(game, type);
      final capacity = type == 'TMHMs' ? legal.length : cap;
      return InventoryPouch(
          type: type, capacity: capacity, maxCount: type == 'KeyItems' ? 1 : 99, legalItems: legal,
          items: _readGbPouch(_d, ofs, type, capacity, legal));
    }

    return [
      p('Items', x.item, 20),
      p('KeyItems', x.key, 26),
      p('Balls', x.ball, 12),
      p('TMHMs', x.tmhm, 57),
      p('PCItems', x.pc, 50),
    ];
  }

  @override
  void writeInventory(List<InventoryPouch> pouches) {
    for (final p in pouches) {
      final ofs = switch (p.type) {
        'Items' => x.item,
        'KeyItems' => x.key,
        'Balls' => x.ball,
        'TMHMs' => x.tmhm,
        _ => x.pc,
      };
      _writeGbPouch(_d, ofs, p);
    }
  }

  /// Offsets (capturados, vistos) de la Pokédex (PKHeX `SAV2Offsets`).
  (int, int) get _dex => switch ((l.region, l.crystal)) {
        (GbRegion.international, false) => (0x2A4C, 0x2A6C),
        (GbRegion.international, true) => (0x2A27, 0x2A47),
        (GbRegion.japanese, false) => (0x29CE, 0x29EE),
        (GbRegion.japanese, true) => (0x29AA, 0x29CA),
        _ => (0x2A8E, 0x2AAE),
      };

  @override
  Pokedex get pokedex =>
      BitPokedex(_d, maxSpecies: 251, caught: _dex.$1, seen: [_dex.$2], description: 'Gen 2', game: game);

  int get _eventFlag => l.currentBoxIndex - (l.crystal ? 0x100 : 0x105);

  @override
  EventStore get events => BitEventStore(_d,
      flagOffset: _eventFlag,
      flagCount: 2000,
      workOffset: _eventFlag - 0x100,
      workCount: 0x100,
      workSize: 1,
      labelKey: l.crystal ? 'c' : 'gs');

  @override
  Uint8List buildPayload() {
    Gen2Finalizer.finalize(_d, l);
    return Uint8List.fromList(_d);
  }
}

/// Checksums y copia de respaldo de GSC (PKHeX `SAV2.GetFinalData`).
abstract final class Gen2Finalizer {
  static void finalize(Uint8List d, Gen2Layout l) {
    final x = Gen2Extra.of(l);
    final sum = Checksums.sum16Bytes(d, Gen2Layout.trainer, l.checksumEnd);
    d.setU16le(l.checksumPos, sum);
    d.setU16le(x.checksum2, sum);
    void copy(int from, int to, int dest) => d.setRange(dest, dest + (to - from), Uint8List.fromList(d.sublist(from, to)));
    if (l.region == GbRegion.korean) {
      d.setU16le(0x7E6B, koreanChecksum(d));
    } else if (l.jp) {
      copy(0x2009, 0x2009 + (l.crystal ? 0xADA : 0xC83), 0x7209);
    } else if (l.crystal) {
      copy(0x2009, 0x2009 + 0xB7A, 0x1209);
    } else {
      copy(0x2009, 0x222F, 0x15C7);
      copy(0x222F, 0x23D9, 0x3D69);
      copy(0x23D9, 0x2856, 0x0C6B);
      copy(0x2856, 0x288A, 0x7E39);
      copy(0x288A, 0x2D69, 0x10E8);
    }
  }
}

/// Checksum secundario de Oro/Plata coreano (PKHeX `SAV2.GetKoreanChecksum`).
int koreanChecksum(Uint8List d) {
  var sum = 0;
  for (final (s, e) in const [(0x106B, 0x1533), (0x1534, 0x1A12), (0x1A13, 0x1C38), (0x3DD8, 0x3F79), (0x7E39, 0x7E6A)]) {
    for (var i = s; i < e; i++) {
      sum += d[i];
    }
  }
  return sum & 0xFFFF;
}

/// Especie interna de un PK1 (útil para la lista de especies).
int gen1SpeciesByte(int national) => SpeciesConvert.gen1FromNational(national);
