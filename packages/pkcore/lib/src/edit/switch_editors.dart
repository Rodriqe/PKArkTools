import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../crypto/sc_block.dart';
import '../crypto/swish_crypto.dart';
import '../data/game_data.dart';
import '../formats/switch_saves.dart';
import '../model/game.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';
import 'events.dart';
import 'pokedex.dart';
import 'pokedex_modern.dart';
import 'save_editor.dart';

/// Claves adicionales de escritura (PKHeX `SaveBlockAccessor8SWSH/8LA/9SV/9ZA`).
abstract final class SCWriteKeys {
  static const int swshMisc = 0x1B882B09;
  static const int swshItems = 0x1177C2C4;
  static const int laMoney = 0x3279D927;
  static const int svMoney = 0x4F35D0DD;
  static const int svItems = 0x21C9BD44;
  static const int zaRevision = 0x0926555A;

  // Leyendas Arceus (PKHeX `SaveBlockAccessor8LA`).
  static const int laItemRegular = 0x9FE2790A;
  static const int laItemKey = 0x59A4D0C3;
  static const int laItemStored = 0x8E434F0D;
  static const int laItemRecipe = 0xF5D9F4A5;
  static const int laSatchelUpgrades = 0x75CE2CF6;

  // Leyendas Z-A (PKHeX `SaveBlockAccessor9ZA`, mismo id de bloque que SV).
  static const int zaItems = 0x21C9BD44;
  static const int zaMegaShardPatch = 0x0ABC6547;
}

/// Bloques de la Pokédex (PKHeX `SaveBlockAccessor8SWSH/8LA/9SV/9ZA`).
abstract final class SCDexKeys {
  static const int swshGalar = 0x4716C404;
  static const int swshArmor = 0x3F936BA9;
  static const int swshCrown = 0x3C9366F0;
  static const int la = 0x02168706;
  static const int svPaldea = 0x0DEAAEBD;
  static const int svKitakami = 0xF5D7C0E2;
  static const int za = 0x2D87BE5C;
}

/// Editor de los saves cifrados con SwishCrypto: Espada/Escudo, Leyendas
/// Arceus, Escarlata/Púrpura y Leyendas Z-A. Edita los bloques en memoria y
/// al construir vuelve a serializar y cifrar (recalculando el SHA-256).
class SwishEditor extends SaveEditor {
  SwishEditor(Uint8List payload, super.game, {super.versionId})
      : _orig = Uint8List.fromList(payload),
        _blocks = SwishCrypto.decrypt(payload) {
    for (final b in _blocks) {
      _byKey[b.key] = b;
    }
  }

  final Uint8List _orig;
  final List<SCBlock> _blocks;
  final Map<int, SCBlock> _byKey = {};
  bool _dirty = false;

  SCBlock? _block(int key) => _byKey[key];

  bool get _la => game == GameVersion.legendsArceus;
  bool get _za => game == GameVersion.legendsZA;
  bool get _gen9 => game.generation == 9;

  int get _partyKey => switch (game) {
        GameVersion.swordShield => SCKeys.swshParty,
        GameVersion.legendsArceus => SCKeys.laParty,
        _ => SCKeys.svParty,
      };
  int get _boxKey => switch (game) {
        GameVersion.swordShield => SCKeys.swshBox,
        GameVersion.legendsArceus => SCKeys.laBox,
        _ => SCKeys.svBox,
      };
  int get _statusKey => switch (game) {
        GameVersion.swordShield => SCKeys.swshMyStatus,
        GameVersion.legendsArceus => SCKeys.laMyStatus,
        _ => SCKeys.svMyStatus,
      };
  int get _playKey => switch (game) {
        GameVersion.swordShield => SCKeys.swshPlayTime,
        GameVersion.legendsArceus => SCKeys.laPlayTime,
        _ => SCKeys.svPlayTime,
      };

  /// Tamaño de un hueco de caja dentro del bloque.
  int get _boxSlot => switch (game) {
        GameVersion.legendsArceus => 0x168,
        GameVersion.legendsZA => 0x158 + 0x40,
        _ => 0x158,
      };

  /// Tamaño de un hueco del equipo dentro del bloque.
  int get _partySlot => switch (game) {
        GameVersion.legendsArceus => 0x178,
        GameVersion.legendsZA => 0x158 + 0x88,
        _ => 0x158,
      };

  int get _zaRevision => (_block(SCWriteKeys.zaRevision)?.intValue ?? 0);

  @override
  int get boxCount {
    final b = _block(_boxKey);
    if (b == null) return 0;
    return (b.data.length ~/ (30 * _boxSlot)).clamp(0, 40);
  }

  @override
  int get boxSlotCount => 30;

  @override
  bool get canEditStorage => _block(_partyKey) != null && _block(_boxKey) != null;

  Pkm? _decode(Uint8List data, int ofs, int size) {
    final pk = Pkm.fromEncrypted(format, data.copyRange(ofs, size));
    if (pk == null || !pk.checksumValid || pk.species == 0) return null;
    return pk;
  }

  Uint8List _blankEncrypted(int size) => Pkm.fromDecrypted(format, Uint8List(format.partySize)).encryptParty().copyRange(0, size);

  @override
  int get partyCount {
    final b = _block(_partyKey);
    if (b == null) return 0;
    if (_za) {
      for (var i = 0; i < 6; i++) {
        if (_decode(b.data, i * _partySlot, 0x158) == null) return i;
      }
      return 6;
    }
    return b.data[6 * _partySlot].clamp(0, 6);
  }

  @override
  Pkm readPartySlot(int index) {
    final b = _block(_partyKey)!;
    return _decode(b.data, index * _partySlot, format.partySize)!;
  }

  @override
  void writeParty(List<Pkm> party) {
    final d = _block(_partyKey)!.data;
    for (var i = 0; i < 6; i++) {
      final o = i * _partySlot;
      // Z-A: los huecos que ya estaban vacíos se dejan tal cual (el juego los
      // escribe con su propio relleno, p. ej. Ball = 4); solo se vacían los que
      // tenían un Pokémon, como PKHeX `Party9a.WriteEmpty`.
      if (_za && i >= party.length && _decode(d, o, 0x158) == null) continue;
      final bytes = i < party.length ? party[i].encryptParty() : _blankEncrypted(format.partySize);
      d.setRange(o, o + format.partySize, bytes);
      if (_za) {
        if (_zaRevision != 0) d[o + 0x158] = 1;
        d[o + 0x158 + 0x48] = 1;
      }
    }
    if (!_za) d[6 * _partySlot] = party.length;
    _dirty = true;
  }

  @override
  Pkm? readBoxSlot(int box, int slot) {
    final b = _block(_boxKey);
    if (b == null) return null;
    final o = (box * 30 + slot) * _boxSlot;
    return _decode(b.data, o, _la ? 0x168 : 0x158);
  }

  @override
  void writeBoxSlot(int box, int slot, Pkm? pk) {
    final d = _block(_boxKey)!.data;
    final o = (box * 30 + slot) * _boxSlot;
    final size = _la ? 0x168 : 0x158;
    final bytes = pk == null ? _blankEncrypted(size) : (_la ? pk.encryptStored() : pk.encryptParty());
    d.setRange(o, o + size, bytes);
    if (_za && _zaRevision != 0) d[o + 0x158] = 1;
    _dirty = true;
  }

  @override
  String boxName(int box) {
    final l = _block(SCKeys.boxLayout);
    if (l == null || !l.data.hasRange(box * 0x22, 0x22)) return super.boxName(box);
    final n = StringCodec.decodeUtf16(l.data, box * 0x22, 0x22);
    return n.isEmpty ? super.boxName(box) : n;
  }

  @override
  bool get canRenameBoxes => _block(SCKeys.boxLayout) != null;

  @override
  void setBoxName(int box, String name) {
    final l = _block(SCKeys.boxLayout)!;
    l.data.setRange(box * 0x22, box * 0x22 + 0x22, StringCodec.encodeUtf16(name.length > 16 ? name.substring(0, 16) : name, 0x22));
    _dirty = true;
  }

  // ------------------------------------------------------------ entrenador

  int get _nameOfs => switch (game) {
        GameVersion.swordShield => 0xB0,
        GameVersion.legendsArceus => 0x20,
        _ => 0x10,
      };
  int get _idOfs => switch (game) {
        GameVersion.swordShield => 0xA0,
        GameVersion.legendsArceus => 0x10,
        _ => 0x00,
      };

  SCBlock? get _moneyBlock => switch (game) {
        GameVersion.swordShield => _block(SCWriteKeys.swshMisc),
        GameVersion.legendsArceus => _block(SCWriteKeys.laMoney),
        _ => _block(SCWriteKeys.svMoney),
      };
  int get _moneyOfs => game == GameVersion.swordShield ? 4 : 0;

  @override
  Set<TrainerField> get trainerFields => {
        TrainerField.name,
        TrainerField.tid,
        TrainerField.sid,
        TrainerField.gender,
        if (_block(_playKey) != null || (_za && _block(SCKeys.zaPlayedSeconds) != null)) TrainerField.playTime,
        if (_moneyBlock != null && _moneyBlock!.data.length >= _moneyOfs + 4) TrainerField.money,
      };

  @override
  TrainerData readTrainer() {
    final s = _block(_statusKey)!.data;
    final p = _block(_playKey)?.data;
    final m = _moneyBlock?.data;
    Duration play = Duration.zero;
    final zaPlay = _za ? zaPlayTime(_block(SCKeys.zaPlayedSeconds)) : null;
    if (zaPlay != null) {
      play = zaPlay;
    } else if (p != null) {
      play = _gen9
          ? (p.length >= 12 ? Duration(hours: p.s32le(0), minutes: p.s32le(4), seconds: p.s32le(8)) : Duration.zero)
          : (p.length >= 4 ? Duration(hours: p.u16le(0), minutes: p[2], seconds: p[3]) : Duration.zero);
    }
    return TrainerData(
      name: StringCodec.decodeUtf16(s, _nameOfs, 0x1A),
      tid: s.u16le(_idOfs),
      sid: s.u16le(_idOfs + 2),
      gender: s[_idOfs + 5],
      playTime: play,
      money: m != null && m.length >= _moneyOfs + 4 ? m.u32le(_moneyOfs) : 0,
    );
  }

  @override
  void writeTrainer(TrainerData t) {
    final s = _block(_statusKey)!.data;
    final old = readTrainer();
    if (t.name != old.name) s.setRange(_nameOfs, _nameOfs + 0x1A, StringCodec.encodeUtf16(t.name, 0x1A));
    s.setU16le(_idOfs, t.tid & 0xFFFF);
    s.setU16le(_idOfs + 2, t.sid & 0xFFFF);
    s[_idOfs + 5] = (t.gender ?? old.gender ?? 0) & 1;
    final p = _block(_playKey)?.data;
    final zaPlay = _za ? _block(SCKeys.zaPlayedSeconds) : null;
    if (zaPlay != null && zaPlay.data.length >= 8) {
      if (t.playTime != old.playTime) setZaPlayTime(zaPlay, t.playTime);
    } else if (p != null && t.playTime != old.playTime) {
      if (_gen9 && p.length >= 12) {
        p.setU32le(0, t.playTime.inHours);
        p.setU32le(4, t.playTime.inMinutes % 60);
        p.setU32le(8, t.playTime.inSeconds % 60);
      } else if (p.length >= 4) {
        p.setU16le(0, t.playTime.inHours.clamp(0, 65535));
        p[2] = t.playTime.inMinutes % 60;
        p[3] = t.playTime.inSeconds % 60;
      }
    }
    final m = _moneyBlock?.data;
    if (m != null && m.length >= _moneyOfs + 4 && t.money != old.money) m.setU32le(_moneyOfs, t.money.clamp(0, maxMoney));
    _dirty = true;
  }

  // ------------------------------------------------------------ inventario

  static const _swshPouches = [
    ('Medicine', 0x0000, 60),
    ('Balls', 0x00F0, 30),
    ('BattleItems', 0x0168, 20),
    ('Berries', 0x01B8, 80),
    ('Items', 0x02F8, 550),
    ('TMHMs', 0x0B90, 210),
    ('Treasure', 0x0ED8, 100),
    ('Candy', 0x1068, 100),
    ('KeyItems', 0x11F8, 64),
  ];

  static const _svPouches = {
    'Medicine': 0,
    'Balls': 1,
    'BattleItems': 2,
    'Berries': 3,
    'Items': 4,
    'TMHMs': 5,
    'Treasure': 6,
    'Ingredients': 7,
    'KeyItems': 8,
    'Candy': 9,
  };

  @override
  List<InventoryPouch>? readInventory() {
    if (game == GameVersion.swordShield) {
      final d = _block(SCWriteKeys.swshItems)?.data;
      if (d == null) return null;
      return [
        for (final (type, ofs, slots) in _swshPouches)
          InventoryPouch(
            type: type,
            capacity: slots,
            maxCount: type == 'KeyItems' ? 1 : 999,
            legalItems: ItemTables.pouch(game, type),
            items: [
              for (var i = 0; i < slots; i++)
                if (d.hasRange(ofs + i * 4, 4) && (d.u32le(ofs + i * 4) & 0x7FF) != 0)
                  () {
                    final v = d.u32le(ofs + i * 4);
                    return InventoryItem(v & 0x7FF, (v >> 15) & 0x3FF, extra: v & 0xC0000000);
                  }(),
            ],
          ),
      ];
    }
    if (game == GameVersion.scarletViolet) {
      final d = _block(SCWriteKeys.svItems)?.data;
      if (d == null) return null;
      return [
        for (final MapEntry(key: type, value: pouchId) in _svPouches.entries)
          () {
            final legal = ItemTables.pouch(game, type);
            return InventoryPouch(
              type: type,
              capacity: legal.length,
              maxCount: type == 'KeyItems' ? 1 : 999,
              legalItems: legal,
              items: [
                for (final id in legal)
                  if (d.hasRange(id * 0x10, 0x10) && d.u32le(id * 0x10) == pouchId && d.u32le(id * 0x10 + 4) > 0)
                    InventoryItem(id, d.u32le(id * 0x10 + 4), extra: d.u32le(id * 0x10 + 8)),
              ],
            );
          }(),
      ];
    }
    if (_la) return _readLaInventory();
    if (_za) return _readZaInventory();
    return null;
  }

  // ---- Leyendas Arceus (PKHeX `PlayerBag8a`): 4 bloques de huecos (u16 id, u16 cantidad).

  List<(String, int, int, int)> get _laPouches {
    final satchel = _block(SCWriteKeys.laSatchelUpgrades)?.intValue ?? 0;
    return [
      ('Items', SCWriteKeys.laItemRegular, (satchel + 20).clamp(20, 675), 999),
      ('KeyItems', SCWriteKeys.laItemKey, 100, 1),
      ('PCItems', SCWriteKeys.laItemStored, 180, 999),
      ('Treasure', SCWriteKeys.laItemRecipe, 70, 1),
    ];
  }

  List<InventoryPouch>? _readLaInventory() {
    if (_block(SCWriteKeys.laItemRegular) == null) return null;
    return [
      for (final (type, key, slots, max) in _laPouches)
        if (_block(key) case final b?)
          InventoryPouch(
            type: type,
            capacity: slots,
            maxCount: max,
            legalItems: ItemTables.pouch(game, type),
            items: [
              for (var i = 0; i < slots && b.data.hasRange(i * 4, 4); i++)
                if (b.data.u16le(i * 4) != 0 && b.data.u16le(i * 4 + 2) != 0)
                  InventoryItem(b.data.u16le(i * 4), b.data.u16le(i * 4 + 2)),
            ],
          ),
    ];
  }

  void _writeLaInventory(List<InventoryPouch> pouches) {
    for (final p in pouches) {
      final def = _laPouches.where((e) => e.$1 == p.type).firstOrNull;
      final d = def == null ? null : _block(def.$2)?.data;
      if (def == null || d == null) continue;
      final items = p.items.where((e) => e.item != 0 && e.count > 0).take(def.$3).toList();
      for (var i = 0; i < def.$3 && d.hasRange(i * 4, 4); i++) {
        if (i < items.length) {
          d.setU16le(i * 4, items[i].item);
          d.setU16le(i * 4 + 2, items[i].count.clamp(1, def.$4));
        } else {
          d.setU32le(i * 4, 0);
        }
      }
    }
  }

  // ---- Leyendas Z-A (PKHeX `MyItem9a`/`InventoryPouch9a`): 0x10 bytes por id de objeto.

  static const _zaPouches = {
    'Medicine': 0,
    'Balls': 1,
    'Items': 2,
    'Treasure': 3,
    'KeyItems': 4,
    'Berries': 5,
    'TMHMs': 6,
    'MegaStones': 7,
  };
  static const _zaNone = 0xFFFFFFFF;
  static const _zaColorfulScrew = 2619, _zaCherishedRing = 2612, _zaMegaShard = 2618, _zaTastyTrash = 2598;

  static int _zaMax(String type) => switch (type) {
        'TMHMs' || 'MegaStones' || 'KeyItems' => 1,
        _ => 999,
      };

  /// Cantidad máxima de un objeto concreto en Z-A (casos especiales de PKHeX `PlayerBag9a`).
  int zaMaxCount(int item, String type) => switch (item) {
        _zaMegaShard when _block(SCWriteKeys.zaMegaShardPatch) != null => 9999,
        _zaCherishedRing => 0,
        _ => _zaMax(type),
      };

  List<InventoryPouch>? _readZaInventory() {
    final d = _block(SCWriteKeys.zaItems)?.data;
    if (d == null) return null;
    return [
      for (final MapEntry(key: type, value: pouchId) in _zaPouches.entries)
        () {
          final legal = ItemTables.pouch(game, type);
          return InventoryPouch(
            type: type,
            capacity: legal.length,
            maxCount: type == 'Items' && _block(SCWriteKeys.zaMegaShardPatch) != null ? 9999 : _zaMax(type),
            legalItems: legal,
            items: [
              for (final id in legal)
                if (d.hasRange(id * 0x10, 0x10) && d.u32le(id * 0x10) == pouchId && d.u32le(id * 0x10 + 4) > 0)
                  InventoryItem(id, d.u32le(id * 0x10 + 4), extra: d.u32le(id * 0x10 + 8)),
            ],
          );
        }(),
    ];
  }

  void _writeZaInventory(List<InventoryPouch> pouches) {
    final d = _block(SCWriteKeys.zaItems)!.data;
    for (final p in pouches) {
      final pouchId = _zaPouches[p.type];
      if (pouchId == null) continue;
      final want = {for (final it in p.items) if (it.count > 0) it.item: it};
      for (final id in p.legalItems) {
        final o = id * 0x10;
        if (!d.hasRange(o, 0x10)) continue;
        final it = want[id];
        final oldCount = d.u32le(o + 4);
        if (id == _zaColorfulScrew) continue; // PKHeX: no modificar
        if (it != null && zaMaxCount(id, p.type) > 0) {
          d.setU32le(o, pouchId);
          d.setU32le(o + 4, it.count.clamp(1, zaMaxCount(id, p.type)));
          d.setU32le(o + 8, d.u32le(o + 8) & ~0x4); // ya notificado
        } else if (oldCount != 0) {
          d.setU32le(o + 4, 0);
          if (d.u32le(o) != _zaNone) {
            d.setU32le(o + 8, d.u32le(o + 8) & ~0x4);
          } else {
            d.fillRange(o, o + 0x10, 0);
            d.setU32le(o, _zaNone);
            d.setU32le(o + 8, 0xD);
          }
        }
      }
      if (p.type == 'KeyItems' && d.hasRange(_zaTastyTrash * 0x10, 0x10)) d.setU32le(_zaTastyTrash * 0x10 + 4, 0);
    }
  }

  @override
  void writeInventory(List<InventoryPouch> pouches) {
    if (_la || _za) {
      _la ? _writeLaInventory(pouches) : _writeZaInventory(pouches);
      _dirty = true;
      return;
    }
    if (game == GameVersion.swordShield) {
      final d = _block(SCWriteKeys.swshItems)!.data;
      for (final p in pouches) {
        final def = _swshPouches.firstWhere((e) => e.$1 == p.type);
        final items = p.items.where((e) => e.item != 0 && e.count > 0).take(def.$3).toList();
        for (var i = 0; i < def.$3; i++) {
          final o = def.$2 + i * 4;
          if (!d.hasRange(o, 4)) break;
          if (i < items.length) {
            final it = items[i];
            d.setU32le(o, (it.item & 0x7FF) | ((it.count.clamp(1, p.maxCount) & 0x3FF) << 15) | (it.extra & 0xC0000000));
          } else {
            d.setU32le(o, 0);
          }
        }
      }
    } else if (game == GameVersion.scarletViolet) {
      final d = _block(SCWriteKeys.svItems)!.data;
      for (final p in pouches) {
        final pouchId = _svPouches[p.type]!;
        final want = {for (final it in p.items) if (it.count > 0) it.item: it};
        for (final id in p.legalItems) {
          final o = id * 0x10;
          if (!d.hasRange(o, 0x10)) continue;
          final it = want[id];
          if (it != null) {
            d.setU32le(o, pouchId);
            d.setU32le(o + 4, it.count.clamp(1, p.maxCount));
            d.setU32le(o + 8, d.u32le(o + 8) | 0x4); // obtenido al menos una vez
          } else if (d.u32le(o) == pouchId) {
            d.setU32le(o + 4, 0);
          }
        }
      }
    } else {
      throw const SaveEditException('Inventario no soportado en este juego.');
    }
    _dirty = true;
  }

  @override
  EventStore get events => SwishEventStore(_blocks,
      switch (game) {
        GameVersion.swordShield => 'swsh',
        GameVersion.legendsArceus => 'la',
        GameVersion.legendsZA => 'za',
        _ => 'sv',
      },
      onChange: () => _dirty = true);

  @override
  Pokedex? get pokedex {
    void dirty() => _dirty = true;
    switch (game) {
      case GameVersion.swordShield:
        final g = _block(SCDexKeys.swshGalar);
        return g == null ? null : SwshPokedex(g, _block(SCDexKeys.swshArmor), _block(SCDexKeys.swshCrown), dirty);
      case GameVersion.legendsArceus:
        final b = _block(SCDexKeys.la);
        return b == null || b.data.length < 0x1E460 ? null : LaPokedex(b, dirty);
      case GameVersion.scarletViolet:
        final p = _block(SCDexKeys.svPaldea), k = _block(SCDexKeys.svKitakami);
        return p == null && k == null ? null : SvPokedex(p, k, dirty);
      case GameVersion.legendsZA:
        final b = _block(SCDexKeys.za);
        return b == null ? null : ZaPokedex(b, dirty);
      default:
        return null;
    }
  }

  @override
  Uint8List buildPayload() => _dirty || forceChecksums ? SwishCrypto.encrypt(_blocks) : Uint8List.fromList(_orig);
}

// =================================================================== BDSP

/// Editor de Diamante Brillante/Perla Reluciente (PKHeX `SAV8BS`). El save no
/// está cifrado; lleva un MD5 del archivo completo (con el hash a cero).
class BdspEditor extends SaveEditor {
  BdspEditor(this._d)
      : _orig = Uint8List.fromList(_d),
        super(GameVersion.brilliantDiamondShiningPearl);

  final Uint8List _d;
  final Uint8List _orig;

  static const int _items = 0x563C;
  static const int _party = 0x14098;
  static const int _boxLayout = 0x148AA;
  static const int _box = 0x14EF4;
  static const int _status = 0x79BB4;
  static const int _played = 0x79C04;
  static const int _hash = 0xE9818;
  static const int _size = 0x158;

  @override
  int get boxCount => 40;
  @override
  int get boxSlotCount => 30;

  Pkm? _decode(int ofs) {
    final pk = Pkm.fromEncrypted(PkFormat.pb8, _d.copyRange(ofs, _size));
    if (pk == null || !pk.checksumValid || pk.species == 0) return null;
    return pk;
  }

  Uint8List get _blank => Pkm.fromDecrypted(PkFormat.pb8, Uint8List(_size)).encryptParty();

  @override
  int get partyCount => _d[_party + 6 * _size].clamp(0, 6);

  @override
  Pkm readPartySlot(int index) => _decode(_party + index * _size)!;

  @override
  void writeParty(List<Pkm> party) {
    for (var i = 0; i < 6; i++) {
      final o = _party + i * _size;
      _d.setRange(o, o + _size, i < party.length ? party[i].encryptParty() : _blank);
    }
    _d[_party + 6 * _size] = party.length;
  }

  int _boxOfs(int b, int s) => _box + (b * 30 + s) * _size;

  @override
  Pkm? readBoxSlot(int box, int slot) => _decode(_boxOfs(box, slot));

  @override
  void writeBoxSlot(int box, int slot, Pkm? pk) {
    final o = _boxOfs(box, slot);
    _d.setRange(o, o + _size, pk == null ? _blank : pk.encryptParty());
  }

  @override
  String boxName(int box) {
    final n = StringCodec.decodeUtf16(_d, _boxLayout + box * 0x22, 0x22);
    return n.isEmpty ? super.boxName(box) : n;
  }

  @override
  bool get canRenameBoxes => true;
  @override
  void setBoxName(int box, String name) {
    final o = _boxLayout + box * 0x22;
    _d.setRange(o, o + 0x22, StringCodec.encodeUtf16(name.length > 16 ? name.substring(0, 16) : name, 0x22));
  }

  @override
  Set<TrainerField> get trainerFields => TrainerField.values.toSet();

  @override
  TrainerData readTrainer() => TrainerData(
        name: StringCodec.decodeUtf16(_d, _status, 0x1A),
        tid: _d.u16le(_status + 0x1C),
        sid: _d.u16le(_status + 0x1E),
        money: _d.u32le(_status + 0x20),
        gender: _d[_status + 0x24] == 1 ? 0 : 1,
        playTime: Duration(hours: _d.u16le(_played), minutes: _d[_played + 2], seconds: _d[_played + 3]),
      );

  @override
  void writeTrainer(TrainerData t) {
    final old = readTrainer();
    if (t.name != old.name) _d.setRange(_status, _status + 0x1A, StringCodec.encodeUtf16(t.name, 0x1A));
    _d.setU16le(_status + 0x1C, t.tid & 0xFFFF);
    _d.setU16le(_status + 0x1E, t.sid & 0xFFFF);
    _d.setU32le(_status + 0x20, t.money.clamp(0, maxMoney));
    _d[_status + 0x24] = (t.gender ?? old.gender ?? 0) == 0 ? 1 : 0;
    if (t.playTime != old.playTime) {
      _d.setU16le(_played, t.playTime.inHours.clamp(0, 65535));
      _d[_played + 2] = t.playTime.inMinutes % 60;
      _d[_played + 3] = t.playTime.inSeconds % 60;
    }
  }

  @override
  Pokedex get pokedex => BdspPokedex(_d, 0x7A328);

  /// PKHeX `FlagWork8b` en 0x4: 500 constantes, 4000 flags (4 bytes cada uno).
  @override
  EventStore get events =>
      WordEventStore(_d, workOffset: 0x4, workCount: 500, flagOffset: 0x4 + 500 * 4, flagCount: 4000, labelKey: 'bdsp');

  static const _pouchTypes = ['Items', 'KeyItems', 'TMHMs', 'Medicine', 'Berries', 'Balls', 'BattleItems', 'Treasure'];

  @override
  List<InventoryPouch>? readInventory() => [
        for (final type in _pouchTypes)
          () {
            final legal = ItemTables.pouch(game, type);
            return InventoryPouch(
              type: type,
              capacity: legal.length,
              maxCount: type == 'KeyItems' ? 1 : 999,
              legalItems: legal,
              items: [
                for (final id in legal)
                  if (_d.s32le(_items + id * 0x10) > 0) InventoryItem(id, _d.s32le(_items + id * 0x10)),
              ],
            );
          }(),
      ];

  @override
  void writeInventory(List<InventoryPouch> pouches) {
    var nextSort = 1;
    for (var id = 0; id < 0xBB80 ~/ 0x10; id++) {
      final s = _d.u16le(_items + id * 0x10 + 12);
      if (s >= nextSort) nextSort = s + 1;
    }
    for (final p in pouches) {
      final want = {for (final it in p.items) if (it.count > 0) it.item: it.count};
      for (final id in p.legalItems) {
        final o = _items + id * 0x10;
        final c = want[id];
        if (c != null) {
          final wasEmpty = _d.s32le(o) <= 0;
          _d.setU32le(o, c.clamp(1, p.maxCount));
          if (wasEmpty) {
            _d.setU32le(o + 4, 1); // no "nuevo"
            _d.setU16le(o + 12, nextSort++);
          }
        } else if (_d.s32le(o) > 0) {
          _d.setU32le(o, 0);
        }
      }
    }
  }

  @override
  Uint8List buildPayload() {
    var changed = false;
    for (var i = 0; i < _d.length; i++) {
      if (_d[i] != _orig[i]) {
        changed = true;
        break;
      }
    }
    if ((!changed && !forceChecksums) || _d.length < _hash + 0x10) return Uint8List.fromList(_d);
    _d.fillRange(_hash, _hash + 0x10, 0);
    final digest = md5.convert(_d).bytes;
    _d.setRange(_hash, _hash + 0x10, digest);
    return Uint8List.fromList(_d);
  }
}
