import 'dart:typed_data';

import '../crypto/pk_crypto.dart';
import '../data/game_data.dart';
import '../formats/gen3.dart';
import '../model/game.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';
import '../util/checksums.dart';
import 'events.dart';
import 'pokedex.dart';
import 'save_editor.dart';

/// Editor de Rubí/Zafiro, Esmeralda y Rojo Fuego/Verde Hoja.
///
/// Trabaja sobre la ranura activa: reconstruye los bloques pequeño, grande y
/// de almacenamiento a partir de sus sectores y, al construir, los vuelve a
/// repartir en los mismos sectores con su checksum. Portado de PKHeX `SAV3`.
class Gen3Editor extends SaveEditor {
  Gen3Editor(this._d, GameVersion game) : super(game) {
    final slot = Gen3.activeSlot(_d);
    final start = slot * Gen3.slotSize;
    for (var ofs = start; ofs < start + Gen3.slotSize; ofs += Gen3.sectorSize) {
      _sectors[_d.u16le(ofs + 0xFF4)] = ofs;
    }
    _small = _concat(0, 0);
    _large = _concat(1, 4);
    _storage = _concat(5, 13);
    _japanese = _detectJapanese();
  }

  final Uint8List _d;
  final Map<int, int> _sectors = {};
  late final Uint8List _small, _large, _storage;
  late final bool _japanese;

  Uint8List _concat(int from, int to) {
    final out = Uint8List((to - from + 1) * Gen3.sectorUsed);
    for (var id = from; id <= to; id++) {
      out.setRange((id - from) * Gen3.sectorUsed, (id - from + 1) * Gen3.sectorUsed, _d, _sectors[id]!);
    }
    return out;
  }

  bool get _frlg => game == GameVersion.fireRedLeafGreen;
  int get _partyCountOfs => _frlg ? 0x34 : 0x234;
  int get _partyOfs => _partyCountOfs + 4;
  int get _moneyOfs => _frlg ? 0x290 : 0x490;
  int get _inventoryOfs => _frlg ? 0x298 : 0x498;
  static const int _namesOfs = 4 + Gen3.boxCount * Gen3.slotsPerBox * PkCrypto.size3Stored;

  /// Clave de seguridad (Esmeralda y RFVH cifran dinero y cantidades con ella).
  int get _securityKey => switch (game) {
        GameVersion.emerald => _small.u32le(0xAC),
        GameVersion.fireRedLeafGreen => _small.u32le(0xF20),
        _ => 0,
      };

  bool _detectJapanese() {
    final count = _large[_partyCountOfs].clamp(0, 6);
    if (count == 0) return false;
    final first = PkCrypto.decrypt3(_large.copyRange(_partyOfs, PkCrypto.size3Stored));
    return first[0x12] == 1;
  }

  @override
  int get boxCount => Gen3.boxCount;
  @override
  int get boxSlotCount => Gen3.slotsPerBox;

  @override
  int get partyCount => _large[_partyCountOfs].clamp(0, 6);

  @override
  Pkm readPartySlot(int index) =>
      Pkm.fromEncrypted(PkFormat.pk3, _large.copyRange(_partyOfs + index * PkCrypto.size3Party, PkCrypto.size3Party))!;

  @override
  void writeParty(List<Pkm> party) {
    _large.setU32le(_partyCountOfs, party.length);
    for (var i = 0; i < 6; i++) {
      final o = _partyOfs + i * PkCrypto.size3Party;
      if (i < party.length) {
        _large.setRange(o, o + PkCrypto.size3Party, party[i].encryptParty());
      } else {
        _large.fillRange(o, o + PkCrypto.size3Party, 0);
      }
    }
  }

  int _boxOfs(int box, int slot) => 4 + (box * Gen3.slotsPerBox + slot) * PkCrypto.size3Stored;

  @override
  Pkm? readBoxSlot(int box, int slot) {
    final pk = Pkm.fromEncrypted(PkFormat.pk3, _storage.copyRange(_boxOfs(box, slot), PkCrypto.size3Stored));
    if (pk == null || !pk.checksumValid) return null;
    return pk;
  }

  @override
  void writeBoxSlot(int box, int slot, Pkm? pk) {
    final o = _boxOfs(box, slot);
    if (pk == null) {
      _storage.fillRange(o, o + PkCrypto.size3Stored, 0);
    } else {
      _storage.setRange(o, o + PkCrypto.size3Stored, pk.encryptStored());
    }
  }

  @override
  String boxName(int box) {
    final n = StringCodec.decodeG3(_storage, _namesOfs + box * 9, 9, japanese: _japanese);
    return n.isEmpty ? super.boxName(box) : n;
  }

  @override
  bool get canRenameBoxes => true;

  @override
  void setBoxName(int box, String name) => _storage.setRange(
      _namesOfs + box * 9, _namesOfs + box * 9 + 9, StringCodec.encodeG3(name, 9, japanese: _japanese));

  @override
  Set<TrainerField> get trainerFields => TrainerField.values.toSet();

  @override
  TrainerData readTrainer() => TrainerData(
        name: StringCodec.decodeG3(_small, 0, 7, japanese: _japanese),
        gender: _small[0x08],
        tid: _small.u16le(0x0A),
        sid: _small.u16le(0x0C),
        playTime: Duration(hours: _small.u16le(0x0E), minutes: _small[0x10], seconds: _small[0x11]),
        money: (_large.u32le(_moneyOfs) ^ _securityKey) & 0xFFFFFFFF,
      );

  @override
  void writeTrainer(TrainerData t) {
    final old = readTrainer();
    if (t.name != old.name) _small.setRange(0, 7, StringCodec.encodeG3(t.name, 7, japanese: _japanese));
    _small[0x08] = (t.gender ?? old.gender ?? 0) & 1;
    _small.setU16le(0x0A, t.tid & 0xFFFF);
    _small.setU16le(0x0C, t.sid & 0xFFFF);
    if (t.playTime != old.playTime) {
      _small.setU16le(0x0E, t.playTime.inHours.clamp(0, 999));
      _small[0x10] = t.playTime.inMinutes % 60;
      _small[0x11] = t.playTime.inSeconds % 60;
    }
    if (t.money != old.money) _large.setU32le(_moneyOfs, (t.money.clamp(0, maxMoney) ^ _securityKey) & 0xFFFFFFFF);
  }

  // Bolsillos: (tipo, offset, ranuras, máximo) — PKHeX `PlayerBag3*`.
  List<(String, int, int, int)> get _pouches => switch (game) {
        GameVersion.fireRedLeafGreen => const [
            ('Items', 0x078, 42, 999),
            ('KeyItems', 0x120, 30, 1),
            ('Balls', 0x198, 13, 999),
            ('TMHMs', 0x1CC, 58, 999),
            ('Berries', 0x2B4, 43, 999),
            ('PCItems', 0x000, 30, 999),
          ],
        GameVersion.emerald => const [
            ('Items', 0x0C8, 30, 99),
            ('KeyItems', 0x140, 30, 1),
            ('Balls', 0x1B8, 16, 99),
            ('TMHMs', 0x1F8, 64, 99),
            ('Berries', 0x2F8, 46, 999),
            ('PCItems', 0x000, 50, 999),
          ],
        _ => const [
            ('Items', 0x0C8, 20, 99),
            ('KeyItems', 0x118, 20, 1),
            ('Balls', 0x168, 16, 99),
            ('TMHMs', 0x1A8, 64, 99),
            ('Berries', 0x2A8, 46, 999),
            ('PCItems', 0x000, 50, 999),
          ],
      };

  @override
  List<InventoryPouch>? readInventory() {
    final key = _securityKey & 0xFFFF;
    return [
      for (final (type, ofs, slots, max) in _pouches)
        InventoryPouch(
          type: type,
          capacity: slots,
          maxCount: max,
          legalItems: ItemTables.pouch(game, type),
          items: [
            for (var i = 0; i < slots; i++)
              if (_large.u16le(_inventoryOfs + ofs + i * 4) != 0)
                InventoryItem(
                  _large.u16le(_inventoryOfs + ofs + i * 4),
                  _large.u16le(_inventoryOfs + ofs + i * 4 + 2) ^ (type == 'PCItems' ? 0 : key),
                ),
          ],
        ),
    ];
  }

  @override
  void writeInventory(List<InventoryPouch> pouches) {
    final key = _securityKey & 0xFFFF;
    for (final p in pouches) {
      final def = _pouches.firstWhere((e) => e.$1 == p.type);
      final base = _inventoryOfs + def.$2;
      final items = p.items.where((e) => e.item != 0 && e.count > 0).take(def.$3).toList();
      for (var i = 0; i < def.$3; i++) {
        final o = base + i * 4;
        final it = i < items.length ? items[i] : null;
        _large.setU16le(o, it?.item ?? 0);
        final count = it == null ? 0 : it.count.clamp(1, def.$4);
        _large.setU16le(o + 2, (it == null && p.type == 'PCItems') ? 0 : count ^ (p.type == 'PCItems' ? 0 : key));
      }
    }
  }

  /// (vistos 2, vistos 3, flags, constantes, nº flags) en el bloque grande (PKHeX `SaveBlock3Large*`).
  (int, int, int, int, int) get _largeOfs => switch (game) {
        GameVersion.emerald => (0x988, 0x3B24, 0x1270, 0x139C, 8 * 300),
        GameVersion.fireRedLeafGreen => (0x5F8, 0x3A18, 0xEE0, 0x1000, 8 * 288),
        _ => (0x938, 0x3A8C, 0x1220, 0x1340, 8 * 288),
      };

  @override
  Pokedex get pokedex => BitPokedex(_small,
      maxSpecies: 386,
      caught: 0x18 + 0x10,
      seen: const [0x18 + 0x44],
      seenMirrors: [(_large, _largeOfs.$1), (_large, _largeOfs.$2)],
      description: 'Gen 3');

  @override
  EventStore get events => BitEventStore(_large,
      flagOffset: _largeOfs.$3,
      flagCount: _largeOfs.$5,
      workOffset: _largeOfs.$4,
      workCount: 0x100,
      labelKey: switch (game) {
        GameVersion.emerald => 'e',
        GameVersion.fireRedLeafGreen => 'frlg',
        _ => 'rs',
      });

  @override
  Uint8List buildPayload() {
    final out = Uint8List.fromList(_d);
    for (final MapEntry(key: id, value: ofs) in _sectors.entries) {
      final Uint8List src;
      final int from;
      if (id == 0) {
        src = _small;
        from = 0;
      } else if (id <= 4) {
        src = _large;
        from = (id - 1) * Gen3.sectorUsed;
      } else {
        src = _storage;
        from = (id - 5) * Gen3.sectorUsed;
      }
      out.setRange(ofs, ofs + Gen3.sectorUsed, src, from);
      out.setU16le(ofs + 0xFF6, Checksums.checkSum32(out, ofs, Gen3.sectorUsed));
    }
    return out;
  }
}
