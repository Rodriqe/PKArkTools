import 'dart:typed_data';

import '../crypto/meme_crypto.dart';
import '../crypto/pk_crypto.dart';
import '../data/game_data.dart';
import '../formats/ctr_saves.dart';
import '../model/game.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';
import '../util/checksums.dart';
import 'events.dart';
import 'pokedex.dart';
import 'pokedex_modern.dart';
import 'save_editor.dart';

/// Checksums de la tabla "BEEF": cada bloque tiene su CRC16 en `bo + 0x14 + id*8 + 6`.
/// Solo se recalculan los bloques cuyo contenido cambió.
void _fixBeefChecksums(Uint8List d, Uint8List orig, List<(int, int)> blocks, int bo, int Function(Uint8List, int, int) crc,
    {bool force = false}) {
  for (var i = 0; i < blocks.length; i++) {
    final (ofs, len) = blocks[i];
    if (ofs + len > d.length) continue;
    var changed = force;
    for (var j = ofs; j < ofs + len; j++) {
      if (d[j] != orig[j]) {
        changed = true;
        break;
      }
    }
    if (changed) d.setU16le(bo + 0x14 + i * 8 + 6, crc(d, ofs, ofs + len));
  }
}

int _crc16Invert(Uint8List d, int start, int end) => (~Checksums.crc16Arc(d, start, end, 0xFFFF)) & 0xFFFF;
int _crc16NoInvert(Uint8List d, int start, int end) => Checksums.crc16Arc(d, start, end, 0);

/// Editor de X/Y, Rubí Omega/Zafiro Alfa, Sol/Luna y Ultrasol/Ultraluna (PKHeX `SAV6*`/`SAV7*`).
class CtrEditor extends SaveEditor {
  CtrEditor(this._d, GameVersion game, {super.versionId})
      : l = CtrLayout.all.firstWhere((e) => e.game == game),
        _orig = Uint8List.fromList(_d),
        super(game);

  final Uint8List _d;
  final Uint8List _orig;
  final CtrLayout l;

  bool get _gen7 => game.generation == 7;
  PkFormat get _fmt => _gen7 ? PkFormat.pk7 : PkFormat.pk6;

  List<(int, int)> get _blocks => switch (game) {
        GameVersion.xy => CtrBlocks.xy,
        GameVersion.omegaRubyAlphaSapphire => CtrBlocks.oras,
        GameVersion.sunMoon => CtrBlocks.sm,
        _ => CtrBlocks.usum,
      };

  int get _misc => switch (game) {
        GameVersion.xy || GameVersion.omegaRubyAlphaSapphire => 0x4200 + 0x8,
        GameVersion.sunMoon => 0x4000 + 0x4,
        _ => 0x4400 + 0x4,
      };

  int get _items => switch (game) {
        GameVersion.xy || GameVersion.omegaRubyAlphaSapphire => 0x400,
        _ => 0x0,
      };

  @override
  int get boxCount => l.boxCount;
  @override
  int get boxSlotCount => 30;

  int get _partyCountOfs => l.party + 6 * PkCrypto.size6Party;

  @override
  int get partyCount => _d[_partyCountOfs].clamp(0, 6);

  @override
  Pkm readPartySlot(int index) =>
      Pkm.fromEncrypted(_fmt, _d.copyRange(l.party + index * PkCrypto.size6Party, PkCrypto.size6Party))!;

  @override
  void writeParty(List<Pkm> party) {
    for (var i = 0; i < 6; i++) {
      final o = l.party + i * PkCrypto.size6Party;
      if (i < party.length) {
        _d.setRange(o, o + PkCrypto.size6Party, party[i].encryptParty());
      } else {
        _d.setRange(o, o + PkCrypto.size6Party, _emptyEncrypted(PkCrypto.size6Party));
      }
    }
    _d[_partyCountOfs] = party.length;
  }

  /// Hueco vacío tal como lo deja el juego (estructura a cero cifrada con EC = 0).
  Uint8List _emptyEncrypted(int size) => Pkm.blankEncrypted(_fmt, party: true).copyRange(0, size);

  int _boxOfs(int b, int s) => l.box + (b * 30 + s) * PkCrypto.size6Stored;

  @override
  Pkm? readBoxSlot(int box, int slot) {
    final pk = Pkm.fromEncrypted(_fmt, _d.copyRange(_boxOfs(box, slot), PkCrypto.size6Stored));
    return pk != null && pk.checksumValid && pk.species != 0 ? pk : null;
  }

  @override
  void writeBoxSlot(int box, int slot, Pkm? pk) {
    final o = _boxOfs(box, slot);
    _d.setRange(o, o + PkCrypto.size6Stored, pk == null ? _emptyEncrypted(PkCrypto.size6Stored) : pk.encryptStored());
  }

  @override
  String boxName(int box) {
    final n = StringCodec.decodeUtf16(_d, l.boxLayout + box * 0x22, 0x22);
    return n.isEmpty ? super.boxName(box) : n;
  }

  @override
  bool get canRenameBoxes => true;
  @override
  void setBoxName(int box, String name) {
    final o = l.boxLayout + box * 0x22;
    _d.setRange(o, o + 0x22, StringCodec.encodeUtf16(name.length > 16 ? name.substring(0, 16) : name, 0x22));
  }

  @override
  Set<TrainerField> get trainerFields => TrainerField.values.toSet();

  @override
  TrainerData readTrainer() {
    final s = l.myStatus;
    return TrainerData(
      name: StringCodec.decodeUtf16(_d, s + l.otOffset, 0x1A),
      tid: _d.u16le(s),
      sid: _d.u16le(s + 2),
      gender: _d[s + 5],
      money: _d.u32le(_misc),
      playTime: Duration(hours: _d.u16le(l.playTime), minutes: _d[l.playTime + 2], seconds: _d[l.playTime + 3]),
    );
  }

  @override
  void writeTrainer(TrainerData t) {
    final s = l.myStatus;
    final old = readTrainer();
    if (t.name != old.name) _d.setRange(s + l.otOffset, s + l.otOffset + 0x1A, StringCodec.encodeUtf16(t.name, 0x1A));
    _d.setU16le(s, t.tid & 0xFFFF);
    _d.setU16le(s + 2, t.sid & 0xFFFF);
    _d[s + 5] = (t.gender ?? old.gender ?? 0) & 1;
    _d.setU32le(_misc, t.money.clamp(0, maxMoney));
    if (t.playTime != old.playTime) {
      _d.setU16le(l.playTime, t.playTime.inHours.clamp(0, 9999));
      _d[l.playTime + 2] = t.playTime.inMinutes % 60;
      _d[l.playTime + 3] = t.playTime.inSeconds % 60;
    }
  }

  // Gen 6: u16/u16 como Gen 4. Gen 7: u32 empaquetado (10 bits objeto, 10 bits cantidad, resto banderas).
  List<(String, int, int, int)> get _pouches7 => game == GameVersion.sunMoon
      ? const [
          ('Items', 0x000, 430, 999),
          ('Medicine', 0xB48, 64, 999),
          ('TMHMs', 0x998, 108, 1),
          ('Berries', 0xC48, 72, 999),
          ('KeyItems', 0x6B8, 184, 1),
          ('ZCrystals', 0xD68, 30, 1),
        ]
      : const [
          ('Items', 0x000, 427, 999),
          ('Medicine', 0xB74, 60, 999),
          ('TMHMs', 0x9C4, 108, 1),
          ('Berries', 0xC64, 67, 999),
          ('KeyItems', 0x6AC, 198, 1),
          ('ZCrystals', 0xD70, 35, 1),
          ('BattleItems', 0xDFC, 11, 999),
        ];

  List<(String, int, int)> get _pouches6 => game == GameVersion.xy
      ? const [('Items', 0x000, 999), ('KeyItems', 0x640, 1), ('TMHMs', 0x7C0, 1), ('Medicine', 0x968, 999), ('Berries', 0xA68, 999)]
      : const [('Items', 0x000, 999), ('KeyItems', 0x640, 1), ('TMHMs', 0x7C0, 1), ('Medicine', 0x970, 999), ('Berries', 0xA70, 999)];

  @override
  List<InventoryPouch>? readInventory() {
    if (!_gen7) {
      return [
        for (final (type, ofs, max) in _pouches6)
          () {
            final legal = ItemTables.pouch(game, type);
            final base = _items + ofs;
            return InventoryPouch(type: type, capacity: legal.length, maxCount: max, legalItems: legal, items: [
              for (var i = 0; i < legal.length; i++)
                if (_d.u16le(base + i * 4) != 0 && _d.u16le(base + i * 4 + 2) != 0)
                  InventoryItem(_d.u16le(base + i * 4), _d.u16le(base + i * 4 + 2)),
            ]);
          }(),
      ];
    }
    return [
      for (final (type, ofs, slots, max) in _pouches7)
        InventoryPouch(
          type: type,
          capacity: slots,
          maxCount: max,
          legalItems: ItemTables.pouch(game, type),
          items: [
            for (var i = 0; i < slots; i++)
              if ((_d.u32le(_items + ofs + i * 4) & 0x3FF) != 0)
                () {
                  final v = _d.u32le(_items + ofs + i * 4);
                  return InventoryItem(v & 0x3FF, (v >> 10) & 0x3FF, extra: v & 0xFFF00000);
                }(),
          ],
        ),
    ];
  }

  @override
  void writeInventory(List<InventoryPouch> pouches) {
    for (final p in pouches) {
      final items = p.items.where((e) => e.item != 0 && e.count > 0).take(p.capacity).toList();
      if (!_gen7) {
        final def = _pouches6.firstWhere((e) => e.$1 == p.type);
        for (var i = 0; i < p.capacity; i++) {
          final o = _items + def.$2 + i * 4;
          _d.setU16le(o, i < items.length ? items[i].item : 0);
          _d.setU16le(o + 2, i < items.length ? items[i].count.clamp(1, def.$3) : 0);
        }
        continue;
      }
      final def = _pouches7.firstWhere((e) => e.$1 == p.type);
      for (var i = 0; i < def.$3; i++) {
        final o = _items + def.$2 + i * 4;
        if (i < items.length) {
          final it = items[i];
          _d.setU32le(o, (it.item & 0x3FF) | ((it.count.clamp(1, def.$4) & 0x3FF) << 10) | (it.extra & 0xFFF00000));
        } else {
          _d.setU32le(o, 0);
        }
      }
    }
  }

  @override
  Pokedex get pokedex => switch (game) {
        GameVersion.xy => Gen6Pokedex(_d, 0x15000, oras: false),
        GameVersion.omegaRubyAlphaSapphire => Gen6Pokedex(_d, 0x15000, oras: true),
        GameVersion.sunMoon => Gen7Pokedex(_d, 0x2A00, game),
        _ => Gen7Pokedex(_d, 0x2C00, game),
      };

  // ---------------------------------------------------------- Regalo Misterioso

  /// Bandeja de tarjetas del Regalo Misterioso (PKHeX `MysteryBlock6/7`, bloque 41 en
  /// Gen 6 y 27 en Gen 7): 0x100 bytes de flags de recibido y después las tarjetas
  /// WC6/WC7 de 0x108 bytes que el juego guarda para recogerlas con el repartidor.
  int get _giftBlock => switch (game) {
        GameVersion.xy => 0x1BC00,
        GameVersion.omegaRubyAlphaSapphire => 0x1CC00,
        GameVersion.sunMoon => 0x65C00,
        _ => 0x66200,
      };

  static const int giftCardSize = 0x108;

  /// Tarjetas que caben en la bandeja: 24 en X/Y y ROZA, 48 en Sol/Luna y USUL.
  int get giftTrayCapacity => _gen7 ? 48 : 24;

  int _giftOfs(int i) => _giftBlock + 0x100 + i * giftCardSize;

  /// Tarjeta del hueco [i] de la bandeja (null si está vacío).
  Uint8List? giftCard(int i) {
    final o = _giftOfs(i);
    final c = Uint8List.sublistView(_d, o, o + giftCardSize);
    return c.every((b) => b == 0) ? null : Uint8List.fromList(c);
  }

  /// Pone [card] (WC6/WC7 de 0x108 bytes) en el hueco [i] de la bandeja.
  void setGiftCard(int i, Uint8List card) {
    checkWritable();
    if (card.length != giftCardSize) throw const SaveEditException('Tarjeta de tamaño incorrecto.');
    if (i < 0 || i >= giftTrayCapacity) throw const SaveEditException('Hueco de la bandeja fuera de rango.');
    _d.setRange(_giftOfs(i), _giftOfs(i) + giftCardSize, card);
  }


  @override
  EventStore get events => switch (game) {
        GameVersion.xy || GameVersion.omegaRubyAlphaSapphire => BitEventStore(_d,
            workOffset: 0x14A00,
            workCount: 0x178,
            flagOffset: 0x14A00 + 0x178 * 2,
            flagCount: 0xD00,
            labelKey: game == GameVersion.xy ? 'xy' : 'oras'),
        GameVersion.sunMoon =>
          BitEventStore(_d, workOffset: 0x1C00, workCount: 1000, flagOffset: 0x1C00 + 0x7D0, flagCount: 4000, labelKey: 'sm'),
        _ => BitEventStore(_d, workOffset: 0x1E00, workCount: 1000, flagOffset: 0x1E00 + 0x7D0, flagCount: 4960, labelKey: 'usum'),
      };

  @override
  Uint8List buildPayload() {
    if (!_gen7) {
      _fixBeefChecksums(_d, _orig, _blocks, _d.length - 0x200, Checksums.crc16Ccitt, force: forceChecksums);
      return Uint8List.fromList(_d);
    }
    // SM/USUM: sin cambios se devuelve el original intacto (con su firma).
    if (!forceChecksums && _sameAs(_d, _orig)) return Uint8List.fromList(_d);
    // Como el juego (y PKHeX `SAV7.GetFinalData`): checksums con la firma a
    // cero y después la firma MemeCrypto sobre la tabla de checksums.
    MemeCrypto.clearSave(_d, game);
    _fixBeefChecksums(_d, _orig, _blocks, _d.length - 0x200, _crc16Invert, force: forceChecksums);
    final out = Uint8List.fromList(_d);
    MemeCrypto.signSave(out, game);
    return out;
  }

  static bool _sameAs(Uint8List a, Uint8List b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// =================================================================== Let's Go

/// Editor de Let's Go Pikachu/Eevee (PKHeX `SAV7b`).
///
/// El almacenamiento es una lista plana de 1000 PB7; el equipo son punteros
/// a esa lista. Al construir se compacta la lista como hace el juego.
class LetsGoEditor extends SaveEditor {
  LetsGoEditor(this._d, {super.versionId})
      : _orig = Uint8List.fromList(_d),
        super(GameVersion.letsGo);

  final Uint8List _d;
  final Uint8List _orig;

  static const int _header = 0x5A00;
  static const int _storage = 0x5C00;
  static const int _slotSize = PkCrypto.size6Party;
  static const int _maxSlots = 1000;
  static const int _empty = 1001;
  static const int _status = 0x1000;
  static const int _misc = 0x4C04;
  static const int _played = 0x45400;

  List<int> get _pointers => [for (var i = 0; i < 7; i++) _d.u16le(_header + i * 2)];
  void _setPointer(int i, int v) => _d.setU16le(_header + i * 2, v);

  @override
  int get boxCount => 40;
  @override
  int get boxSlotCount => 25;

  int _index(int box, int slot) => box * 25 + slot;
  int _ofs(int index) => _storage + index * _slotSize;

  Pkm? _readIndex(int index) {
    if (index < 0 || index >= _maxSlots) return null;
    final pk = Pkm.fromEncrypted(PkFormat.pb7, _d.copyRange(_ofs(index), _slotSize));
    return pk != null && pk.checksumValid && pk.species != 0 ? pk : null;
  }

  void _writeIndex(int index, Pkm? pk) =>
      _d.setRange(_ofs(index), _ofs(index) + _slotSize, pk == null ? Pkm.blankEncrypted(PkFormat.pb7, party: true) : pk.encryptParty());

  @override
  int get partyCount => _pointers.take(6).where((p) => p < _maxSlots).length;

  @override
  Pkm readPartySlot(int index) => _readIndex(_pointers[index])!;

  @override
  void writeParty(List<Pkm> party) {
    final ptr = _pointers;
    final old = [for (var i = 0; i < 6; i++) if (ptr[i] < _maxSlots) ptr[i]];
    final used = <int>{};
    for (var i = 0; i < 6; i++) {
      if (i < party.length) {
        // Reutiliza la posición del miembro original si existe; si no, busca un hueco libre.
        var idx = i < old.length ? old[i] : -1;
        if (idx < 0 || used.contains(idx)) idx = _findFree(exclude: {...used, ...old});
        used.add(idx);
        _writeIndex(idx, party[i]);
        _setPointer(i, idx);
      } else {
        _setPointer(i, _empty);
      }
    }
    // Los antiguos miembros que ya no están en el equipo siguen en las cajas.
  }

  int _findFree({Set<int> exclude = const {}}) {
    for (var i = 0; i < _maxSlots; i++) {
      if (!exclude.contains(i) && _readIndex(i) == null) return i;
    }
    throw const SaveEditException('El almacenamiento está lleno.');
  }

  @override
  bool isSlotLocked(SlotRef ref) {
    if (ref.isParty) return false;
    final i = _index(ref.box, ref.slot);
    return _pointers.contains(i);
  }

  @override
  Pkm? readBoxSlot(int box, int slot) => _readIndex(_index(box, slot));

  @override
  void writeBoxSlot(int box, int slot, Pkm? pk) {
    final i = _index(box, slot);
    if (pk == null && _pointers.take(6).contains(i)) {
      throw const SaveEditException('Este Pokémon está en el equipo; sácalo del equipo primero.');
    }
    _writeIndex(i, pk);
    if (pk == null && _pointers[6] == i) _setPointer(6, _empty);
  }

  @override
  Set<TrainerField> get trainerFields => TrainerField.values.toSet();

  @override
  TrainerData readTrainer() => TrainerData(
        name: StringCodec.decodeUtf16(_d, _status + 0x38, 0x1A),
        tid: _d.u16le(_status),
        sid: _d.u16le(_status + 2),
        gender: _d[_status + 5],
        money: _d.u32le(_misc),
        playTime: Duration(hours: _d.u16le(_played), minutes: _d[_played + 2], seconds: _d[_played + 3]),
      );

  @override
  void writeTrainer(TrainerData t) {
    final old = readTrainer();
    if (t.name != old.name) _d.setRange(_status + 0x38, _status + 0x38 + 0x1A, StringCodec.encodeUtf16(t.name, 0x1A));
    _d.setU16le(_status, t.tid & 0xFFFF);
    _d.setU16le(_status + 2, t.sid & 0xFFFF);
    _d[_status + 5] = (t.gender ?? old.gender ?? 0) & 1;
    _d.setU32le(_misc, t.money.clamp(0, maxMoney));
    if (t.playTime != old.playTime) {
      _d.setU16le(_played, t.playTime.inHours.clamp(0, 9999));
      _d[_played + 2] = t.playTime.inMinutes % 60;
      _d[_played + 3] = t.playTime.inSeconds % 60;
    }
  }

  static const _pouches = [
    ('Medicine', 0x0000, 60, 999),
    ('TMHMs', 0x00F0, 108, 1),
    ('Candy', 0x02A0, 200, 999),
    ('ZCrystals', 0x05C0, 150, 999),
    ('Balls', 0x0818, 50, 999),
    ('BattleItems', 0x08E0, 150, 999),
    ('Items', 0x0B38, 150, 999),
  ];

  @override
  List<InventoryPouch>? readInventory() => [
        for (final (type, ofs, slots, max) in _pouches)
          InventoryPouch(type: type, capacity: slots, maxCount: max, legalItems: ItemTables.pouch(game, type), items: [
            for (var i = 0; i < slots; i++)
              if ((_d.u32le(ofs + i * 4) & 0x7FF) != 0)
                () {
                  final v = _d.u32le(ofs + i * 4);
                  return InventoryItem(v & 0x7FF, (v >> 15) & 0x3FF, extra: v & 0xC0000000);
                }(),
          ]),
      ];

  @override
  void writeInventory(List<InventoryPouch> pouches) {
    for (final p in pouches) {
      final def = _pouches.firstWhere((e) => e.$1 == p.type);
      final items = p.items.where((e) => e.item != 0 && e.count > 0).take(def.$3).toList();
      for (var i = 0; i < def.$3; i++) {
        final o = def.$2 + i * 4;
        if (i < items.length) {
          final it = items[i];
          _d.setU32le(o, (it.item & 0x7FF) | ((it.count.clamp(1, def.$4) & 0x3FF) << 15) | (it.extra & 0xC0000000));
        } else {
          _d.setU32le(o, 0);
        }
      }
    }
  }

  @override
  Pokedex get pokedex => Gen7Pokedex(_d, 0x2A00, GameVersion.letsGo);

  /// PKHeX `EventWork7b` (bloque 3 en 0x1200): 1000 constantes de 32 bits y
  /// después los flags (zona, sistema, desaparición y evento).
  @override
  EventStore get events => BitEventStore(_d,
      workOffset: 0x1200,
      workCount: 1000,
      workSize: 4,
      flagOffset: 0x1200 + 4000,
      flagCount: 0x80 + 0x200 + 0x600 + 0x780,
      labelKey: 'gg');

  /// Compacta el almacenamiento (los huecos vacíos se mueven al final) y reajusta punteros.
  void _compress() {
    final ptr = _pointers;
    final remap = <int, int>{};
    final mons = <Uint8List>[];
    for (var i = 0; i < _maxSlots; i++) {
      if (_readIndex(i) != null) {
        remap[i] = mons.length;
        mons.add(_d.copyRange(_ofs(i), _slotSize));
      }
    }
    var identity = true;
    remap.forEach((k, v) => identity &= k == v);
    if (identity) {
      _d.setU16le(_header + 14, mons.length);
      return;
    }
    for (var i = 0; i < _maxSlots; i++) {
      _d.setRange(_ofs(i), _ofs(i) + _slotSize, i < mons.length ? mons[i] : Pkm.blankEncrypted(PkFormat.pb7, party: true));
    }
    for (var i = 0; i < 7; i++) {
      _setPointer(i, ptr[i] < _maxSlots ? (remap[ptr[i]] ?? _empty) : ptr[i]);
    }
    _d.setU16le(_header + 14, mons.length);
  }

  @override
  Uint8List buildPayload() {
    _compress();
    _fixBeefChecksums(_d, _orig, CtrBlocks.lgpe, 0xB8800 - 0x200, _crc16NoInvert, force: forceChecksums);
    return Uint8List.fromList(_d);
  }
}

/// Tablas de bloques (offset, longitud) — PKHeX `SaveBlockAccessor6*/7*/7b`.
abstract final class CtrBlocks {
  static const List<(int, int)> xy = [
    (0x00000, 0x002C8), (0x00400, 0x00B88), (0x01000, 0x0002C), (0x01200, 0x00038), (0x01400, 0x00150), //
    (0x01600, 0x00004), (0x01800, 0x00008), (0x01A00, 0x001C0), (0x01C00, 0x000BE), (0x01E00, 0x00024), //
    (0x02000, 0x02100), (0x04200, 0x00140), (0x04400, 0x00440), (0x04A00, 0x00574), (0x05000, 0x04E28), //
    (0x0A000, 0x04E28), (0x0F000, 0x04E28), (0x14000, 0x00170), (0x14200, 0x0061C), (0x14A00, 0x00504), //
    (0x15000, 0x006A0), (0x15800, 0x00644), (0x16000, 0x00104), (0x16200, 0x00004), (0x16400, 0x00420), //
    (0x16A00, 0x00064), (0x16C00, 0x003F0), (0x17000, 0x0070C), (0x17800, 0x00180), (0x17A00, 0x00004), //
    (0x17C00, 0x0000C), (0x17E00, 0x00048), (0x18000, 0x00054), (0x18200, 0x00644), (0x18A00, 0x005C8), //
    (0x19000, 0x002F8), (0x19400, 0x01B40), (0x1B000, 0x001F4), (0x1B200, 0x001F0), (0x1B400, 0x00216), //
    (0x1B800, 0x00390), (0x1BC00, 0x01A90), (0x1D800, 0x00308), (0x1DC00, 0x00618), (0x1E400, 0x0025C), //
    (0x1E800, 0x00834), (0x1F200, 0x00318), (0x1F600, 0x007D0), (0x1FE00, 0x00C48), (0x20C00, 0x00078), //
    (0x20E00, 0x00200), (0x21000, 0x00C84), (0x21E00, 0x00628), (0x22600, 0x34AD0), (0x57200, 0x0E058),
  ];
  static const List<(int, int)> oras = [
    (0x00000, 0x002C8), (0x00400, 0x00B90), (0x01000, 0x0002C), (0x01200, 0x00038), (0x01400, 0x00150), //
    (0x01600, 0x00004), (0x01800, 0x00008), (0x01A00, 0x001C0), (0x01C00, 0x000BE), (0x01E00, 0x00024), //
    (0x02000, 0x02100), (0x04200, 0x00130), (0x04400, 0x00440), (0x04A00, 0x00574), (0x05000, 0x04E28), //
    (0x0A000, 0x04E28), (0x0F000, 0x04E28), (0x14000, 0x00170), (0x14200, 0x0061C), (0x14A00, 0x00504), //
    (0x15000, 0x011CC), (0x16200, 0x00644), (0x16A00, 0x00104), (0x16C00, 0x00004), (0x16E00, 0x00420), //
    (0x17400, 0x00064), (0x17600, 0x003F0), (0x17A00, 0x0070C), (0x18200, 0x00180), (0x18400, 0x00004), //
    (0x18600, 0x0000C), (0x18800, 0x00048), (0x18A00, 0x00054), (0x18C00, 0x00644), (0x19400, 0x005C8), //
    (0x19A00, 0x002F8), (0x19E00, 0x01B40), (0x1BA00, 0x001F4), (0x1BC00, 0x003E0), (0x1C000, 0x00216), //
    (0x1C400, 0x00640), (0x1CC00, 0x01A90), (0x1E800, 0x00400), (0x1EC00, 0x00618), (0x1F400, 0x0025C), //
    (0x1F800, 0x00834), (0x20200, 0x00318), (0x20600, 0x007D0), (0x20E00, 0x00C48), (0x21C00, 0x00078), //
    (0x21E00, 0x00200), (0x22000, 0x00C84), (0x22E00, 0x00628), (0x23600, 0x00400), (0x23A00, 0x07AD0), //
    (0x2B600, 0x078B0), (0x33000, 0x34AD0), (0x67C00, 0x0E058),
  ];
  static const List<(int, int)> sm = [
    (0x00000, 0x00DE0), (0x00E00, 0x0007C), (0x01000, 0x00014), (0x01200, 0x000C0), (0x01400, 0x0061C), //
    (0x01C00, 0x00E00), (0x02A00, 0x00F78), (0x03A00, 0x00228), (0x03E00, 0x00104), (0x04000, 0x00200), //
    (0x04200, 0x00020), (0x04400, 0x00004), (0x04600, 0x00058), (0x04800, 0x005E6), (0x04E00, 0x36600), //
    (0x3B400, 0x0572C), (0x40C00, 0x00008), (0x40E00, 0x01080), (0x42000, 0x01A08), (0x43C00, 0x06408), //
    (0x4A200, 0x06408), (0x50800, 0x03998), (0x54200, 0x00100), (0x54400, 0x00100), (0x54600, 0x10528), //
    (0x64C00, 0x00204), (0x65000, 0x00B60), (0x65C00, 0x03F50), (0x69C00, 0x00358), (0x6A000, 0x00728), //
    (0x6A800, 0x00200), (0x6AA00, 0x00718), (0x6B200, 0x001FC), (0x6B400, 0x00200), (0x6B600, 0x00120), //
    (0x6B800, 0x001C8), (0x6BA00, 0x00200),
  ];
  static const List<(int, int)> usum = [
    (0x00000, 0x00E28), (0x01000, 0x0007C), (0x01200, 0x00014), (0x01400, 0x000C0), (0x01600, 0x0061C), //
    (0x01E00, 0x00E00), (0x02C00, 0x00F78), (0x03C00, 0x00228), (0x04000, 0x0030C), (0x04400, 0x001FC), //
    (0x04600, 0x0004C), (0x04800, 0x00004), (0x04A00, 0x00058), (0x04C00, 0x005E6), (0x05200, 0x36600), //
    (0x3B800, 0x0572C), (0x41000, 0x00008), (0x41200, 0x01218), (0x42600, 0x01A08), (0x44200, 0x06408), //
    (0x4A800, 0x06408), (0x50E00, 0x03998), (0x54800, 0x00100), (0x54A00, 0x00100), (0x54C00, 0x10528), //
    (0x65200, 0x00204), (0x65600, 0x00B60), (0x66200, 0x03F50), (0x6A200, 0x00358), (0x6A600, 0x00728), //
    (0x6AE00, 0x00200), (0x6B000, 0x00718), (0x6B800, 0x001FC), (0x6BA00, 0x00200), (0x6BC00, 0x00120), //
    (0x6BE00, 0x001C8), (0x6C000, 0x00200), (0x6C200, 0x0039C), (0x6C600, 0x00400),
  ];
  static const List<(int, int)> lgpe = [
    (0x00000, 0x00D90), (0x00E00, 0x00200), (0x01000, 0x00168), (0x01200, 0x01800), (0x02A00, 0x020E8), //
    (0x04C00, 0x00930), (0x05600, 0x00004), (0x05800, 0x00130), (0x05A00, 0x00012), (0x05C00, 0x3F7A0), //
    (0x45400, 0x00008), (0x45600, 0x00E90), (0x46600, 0x010A4), (0x47800, 0x000F0), (0x47A00, 0x06010), //
    (0x4DC00, 0x00200), (0x4DE00, 0x00098), (0x4E000, 0x00068), (0x4E200, 0x69780), (0xB7A00, 0x000B0), //
    (0xB7C00, 0x00940),
  ];
}
