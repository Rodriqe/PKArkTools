import 'dart:typed_data';

import '../data/species_convert.dart';
import '../formats/gc_container.dart';
import '../formats/gc_saves.dart';
import '../model/game.dart';
import '../pkm/gc_pkm.dart';
import '../pkm/pkm.dart';
import '../util/bytes.dart';
import 'pokedex.dart';
import 'save_editor.dart';

List<int> _range(int a, int b) => [for (var i = a; i <= b; i++) i];

/// Objetos por bolsillo de Colosseum y XD (PKHeX `ItemStorage3Colo`/`ItemStorage3XD`, GPL-3.0).
abstract final class GcItems {
  static const List<int> _generalBase = [
    13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, //
    40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 63, 64, 65, 66, 67, 68, 69, 70, 71, 73, 74, 75, 76, 77, 78, 79,
    80, 81, 83, 84, 85, 86, 93, 94, 95, 96, 97, 98, 103, 104, 106, 107, 108, 109, 110, 111, 121, 122, 123, 124, 125,
    126, 127, 128, 129, 130, 131, 132, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194,
    195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217,
    218, 219, 220, 221, 222, 223, 224, 225, 254, 255, 256, 257, 258,
  ];
  static const List<int> coloGeneral = [..._generalBase, 537]; // Flauta del Tiempo
  static const List<int> xdGeneral = [..._generalBase, 511]; // Poké Snack
  static final List<int> coloKey = [..._range(500, 536), 538, 539, 540, 541, 542, 546, 547];
  static final List<int> xdKey = [..._range(500, 510), 512, ..._range(516, 519), ..._range(523, 533)];
  static const List<int> coloCologne = [543, 544, 545];
  static const List<int> xdCologne = [513, 514, 515];
  static final List<int> xdDisc = _range(534, 593);
  static final List<int> balls = _range(1, 12);
  static final List<int> tms = _range(289, 338);
  static final List<int> berries = _range(133, 175);

  /// (tipo PKHeX, offset en la bolsa, huecos, máximo, objetos válidos).
  static List<(String, int, int, int, List<int>)> pouches(GameVersion game) => game == GameVersion.colosseum
      ? [
          ('Items', 0x000, 20, 99, coloGeneral),
          ('KeyItems', 0x050, 43, 1, coloKey),
          ('Balls', 0x0FC, 16, 99, balls),
          ('TMHMs', 0x13C, 64, 99, tms),
          ('Berries', 0x23C, 46, 999, berries),
          ('Medicine', 0x2F4, 3, 99, coloCologne),
        ]
      : [
          ('Items', 0x000, 30, 999, xdGeneral),
          ('KeyItems', 0x078, 43, 1, xdKey),
          ('Balls', 0x124, 16, 999, balls),
          ('TMHMs', 0x164, 64, 999, tms),
          ('Berries', 0x264, 46, 999, berries),
          ('Medicine', 0x31C, 3, 999, xdCologne),
          ('BattleItems', 0x328, 60, 1, xdDisc),
        ];
}

/// Editor de Pokémon Colosseum y XD (GameCube).
///
/// Lee y escribe la ranura más reciente; los Pokémon se exponen como PK3 con
/// [Pkm.gc] (CK3/XK3). Si nada cambia, [buildPayload] devuelve el archivo
/// original byte a byte. Portado de PKHeX `SAV3Colosseum` / `SAV3XD`.
class GcEditor extends SaveEditor {
  GcEditor(Uint8List payload, GcTitle title)
      : _s = GcSaveData.open(title, payload),
        super(title == GcTitle.colosseum ? GameVersion.colosseum : GameVersion.xd,
            versionId: title == GcTitle.colosseum ? 66 : 67) {
    _pristine = Uint8List.fromList(_s.slot);
  }

  final GcSaveData _s;
  late final Uint8List _pristine;

  /// Datos descifrados (para herramientas y tests).
  GcSaveData get data => _s;
  bool get _colo => _s.isColosseum;
  GcRegion get region => _s.currentRegion;

  @override
  int get boxCount => _s.boxCount;
  @override
  int get boxSlotCount => GcSaveData.slotsPerBox;
  @override
  int get partyCount => _s.partyCount;
  @override
  int get maxMoney => 9999999;
  @override
  int get maxTrainerNameLength => _colo ? 10 : 7;

  Pkm? _readMon(int ofs) {
    final raw = _s.slot.copyRange(ofs, _s.monSize);
    if (!GcPkm.isPresent(raw)) return null;
    final id = raw.u16be(0xBA);
    final xd = _colo ? null : _s.xdShadow(id);
    return GcPkm.read(_s.kind, raw, xdPurification: xd?.$1 ?? 0, xdPurified: xd?.$2 ?? false, xdSnagged: xd?.$3 ?? false);
  }

  void _writeMon(int ofs, Pkm? pk) {
    if (pk == null) {
      _s.slot.fillRange(ofs, ofs + _s.monSize, 0);
      return;
    }
    final bytes = GcPkm.write(pk, _s.kind, region: region);
    _s.slot.setRange(ofs, ofs + _s.monSize, bytes);
    final gc = pk.gc;
    // Un Pokémon oscuro queda en el Strategy Memo (el juego lo anota al verlo en combate).
    if (gc != null && gc.shadowId != 0) {
      StrategyMemoDex(_s.slot, _s.memo, xd: !_colo).register(pk.species, tid: pk.tid, sid: pk.sid, pid: pk.pid);
    }
    if (!_colo && gc != null && gc.kind == GcKind.xk3) {
      final iv = pk.data.u32le(0x48);
      _s.writeXdShadow(bytes.u16be(0xBA),
          purification: gc.xdPurification,
          purified: gc.xdPurified,
          pid: pk.pid,
          ivsGc: [for (final s in const [0, 1, 2, 4, 5, 3]) (iv >> (5 * s)) & 0x1F],
          speciesRaw: bytes.u16be(0));
    }
  }

  @override
  Pkm readPartySlot(int index) =>
      _readMon(_s.partySlot(index)) ?? (throw RangeError.range(index, 0, partyCount - 1, 'index'));

  @override
  void writeParty(List<Pkm> party) {
    for (var i = 0; i < 6; i++) {
      final o = _s.partySlot(i);
      if (i < party.length) {
        // Un hueco sin cambios no se reescribe: así se conservan sus bytes.
        final cur = _readMon(o);
        if (cur != null && _sameMon(cur, party[i])) continue;
        _writeMon(o, party[i]);
      } else if (GcPkm.isPresent(_s.slot.view(o, _s.monSize))) {
        _writeMon(o, null);
      }
    }
  }

  static bool _sameMon(Pkm a, Pkm b) {
    if (a.gc == null || b.gc == null) return false;
    for (var i = 0; i < a.data.length; i++) {
      if (a.data[i] != b.data[i]) return false;
    }
    final ra = a.gc!.raw, rb = b.gc!.raw;
    if (ra.length != rb.length) return false;
    for (var i = 0; i < ra.length; i++) {
      if (ra[i] != rb[i]) return false;
    }
    return a.gc!.xdPurification == b.gc!.xdPurification && a.gc!.xdPurified == b.gc!.xdPurified;
  }

  @override
  Pkm? readBoxSlot(int box, int slot) => _readMon(_s.boxSlot(box, slot));

  @override
  void writeBoxSlot(int box, int slot, Pkm? pk) => _writeMon(_s.boxSlot(box, slot), pk);

  @override
  String boxName(int box) {
    final n = _s.readString(_s.boxInfo(box), 8);
    return n.isEmpty ? super.boxName(box) : n;
  }

  @override
  bool get canRenameBoxes => true;

  @override
  void setBoxName(int box, String name) => _s.writeString(_s.boxInfo(box), 16, name, 8);

  // ------------------------------------------------------------ entrenador

  @override
  Set<TrainerField> get trainerFields => TrainerField.values.toSet();

  @override
  TrainerData readTrainer() => TrainerData(
        name: _s.trainerName,
        tid: _s.tid,
        sid: _s.sid,
        money: _s.slot.u32be(_s.moneyOfs),
        playTime: _s.playTime,
        gender: _s.slot[_s.genderOfs],
      );

  @override
  void writeTrainer(TrainerData t) {
    final old = readTrainer();
    if (t.name != old.name) {
      _s.writeString(_s.trainer, 20, t.name, maxTrainerNameLength);
      if (_colo) _s.writeString(0x8C, 20, t.name, maxTrainerNameLength); // copia (PKHeX `OT2`)
    }
    if (t.tid != old.tid) _s.slot.setU16be(_s.tidOfs, t.tid & 0xFFFF);
    if (t.sid != old.sid) _s.slot.setU16be(_s.sidOfs, t.sid & 0xFFFF);
    if (t.money != old.money) {
      final m = t.money.clamp(0, maxMoney);
      _s.slot.setRange(_s.moneyOfs, _s.moneyOfs + 4, [m >> 24, (m >> 16) & 0xFF, (m >> 8) & 0xFF, m & 0xFF]);
    }
    if (t.playTime != old.playTime) _s.playTime = t.playTime;
    if (t.gender != null && t.gender != old.gender) _s.slot[_s.genderOfs] = t.gender! & 1;
  }

  // ------------------------------------------------------------ inventario

  @override
  List<InventoryPouch>? readInventory() => [
        for (final (type, ofs, slots, max, legal) in GcItems.pouches(game))
          InventoryPouch(
            type: type,
            capacity: slots,
            maxCount: max,
            legalItems: legal,
            items: [
              for (var i = 0; i < slots; i++)
                if (_s.slot.u16be(_s.pouch + ofs + i * 4) != 0)
                  InventoryItem(_s.slot.u16be(_s.pouch + ofs + i * 4), _s.slot.u16be(_s.pouch + ofs + i * 4 + 2)),
            ],
          ),
      ];

  @override
  void writeInventory(List<InventoryPouch> pouches) {
    final current = {for (final p in readInventory()!) p.type: p.items};
    for (final p in pouches) {
      final def = GcItems.pouches(game).where((e) => e.$1 == p.type).firstOrNull;
      if (def == null) continue;
      final items = p.items.where((e) => e.item != 0 && e.count > 0).take(def.$3).toList();
      final cur = current[p.type] ?? const [];
      if (cur.length == items.length && [for (var i = 0; i < cur.length; i++) cur[i] == items[i]].every((e) => e)) {
        continue; // sin cambios: no se tocan los bytes
      }
      for (var i = 0; i < def.$3; i++) {
        final o = _s.pouch + def.$2 + i * 4;
        final it = i < items.length ? items[i] : null;
        _s.slot.setU16be(o, it?.item ?? 0);
        _s.slot.setU16be(o + 2, it == null ? 0 : it.count.clamp(1, def.$4));
      }
    }
  }

  // ------------------------------------------------------------ Strategy Memo

  @override
  Pokedex get pokedex => StrategyMemoDex(_s.slot, _s.memo, xd: !_colo);

  /// Pokémon oscuros de la tabla de XD (vacío en Colosseum, que los guarda en
  /// cada CK3).
  List<({int id, int species, int purification, bool snagged, bool purified})> get xdShadowTable => [
        for (final e in _s.xdShadowTable)
          (
            id: e.id,
            species: SpeciesConvert.nationalFromGen3(e.speciesRaw),
            purification: e.purification,
            snagged: e.snagged,
            purified: e.purified,
          ),
      ];

  // ------------------------------------------------------------ salida

  @override
  Uint8List buildPayload() {
    var same = !forceChecksums;
    if (same) {
      for (var i = 0; i < _pristine.length; i++) {
        if (_pristine[i] != _s.slot[i]) {
          same = false;
          break;
        }
      }
    }
    return same ? Uint8List.fromList(_s.payload) : _s.build();
  }
}

/// Strategy Memo de Colosseum/XD como Pokédex (PKHeX `StrategyMemo`, GPL-3.0).
///
/// Lista de hasta 500 entradas de 12 bytes (especie interna + 2 bits, ID, PID)
/// precedida de un contador. En Colosseum una entrada es «vista» si existe y
/// «capturada» salvo que tenga el bit 7; XD solo registra vistas.
class StrategyMemoDex extends Pokedex {
  StrategyMemoDex(this._d, this._ofs, {required this.xd});

  final Uint8List _d;
  final int _ofs;
  final bool xd;
  static const int _max = 500;
  static const int _entry = 12;

  @override
  int get maxSpecies => 386;

  @override
  String get description => xd ? 'Strategy Memo (XD)' : 'Strategy Memo (Colosseum)';

  int get _count => _d.u16be(_ofs).clamp(0, _max);
  int _at(int i) => _ofs + 4 + i * _entry;
  int _speciesAt(int i) => SpeciesConvert.nationalFromGen3(_d.u16be(_at(i)) & 0x1FF);

  int? _find(int species) {
    for (var i = 0; i < _count; i++) {
      if (_speciesAt(i) == species) return i;
    }
    return null;
  }

  bool _flag1(int i) => _d[_at(i)] >> 7 == 1;
  bool _flag0(int i) => (_d[_at(i)] >> 6) & 1 == 1;

  @override
  bool isSeen(int species) {
    final i = _find(species);
    if (i == null) return false;
    return xd ? !_flag1(i) : true;
  }

  @override
  bool isCaught(int species) {
    if (xd) return false;
    final i = _find(species);
    return i != null && (_flag0(i) || !_flag1(i));
  }

  /// Anota [species] como la anota el juego al verla (y, en Colosseum, al
  /// capturarla) con el ID y PID del Pokémon, si aún no está.
  void register(int species, {required int tid, required int sid, required int pid}) {
    if (_find(species) != null) return;
    final n = _count;
    if (n >= _max) return;
    final o = _at(n);
    _d.fillRange(o, o + _entry, 0);
    _d.setU16be(o, SpeciesConvert.gen3FromNational(species) & 0x1FF);
    _d.setU16be(o + 4, sid & 0xFFFF);
    _d.setU16be(o + 6, tid & 0xFFFF);
    _d.setU16be(o + 8, (pid >> 16) & 0xFFFF);
    _d.setU16be(o + 10, pid & 0xFFFF);
    _d.setU16be(_ofs, n + 1);
  }

  void _setFlag1(int i, bool v) => _d[_at(i)] = (_d[_at(i)] & 0x7F) | (v ? 0x80 : 0);

  @override
  void setSeen(int species, bool value) {
    final i = _find(species);
    if (value) {
      if (i != null) {
        if (xd && _flag1(i)) _setFlag1(i, false);
        return;
      }
      final n = _count;
      if (n >= _max) return;
      final o = _at(n);
      _d.fillRange(o, o + _entry, 0);
      _d.setU16be(o, SpeciesConvert.gen3FromNational(species) & 0x1FF);
      if (!xd) _setFlag1(n, true); // vista, no capturada
      _d.setU16be(_ofs, n + 1);
      return;
    }
    if (i == null) return;
    final n = _count;
    _d.setRange(_at(i), _at(n - 1), _d, _at(i + 1));
    _d.fillRange(_at(n - 1), _at(n), 0);
    _d.setU16be(_ofs, n - 1);
  }

  @override
  void setCaught(int species, bool value) {
    if (xd) return;
    if (value && _find(species) == null) setSeen(species, true);
    final i = _find(species);
    if (i == null || isCaught(species) == value) return;
    if (value) {
      _setFlag1(i, false);
    } else {
      _d[_at(i)] &= ~0x40;
      _setFlag1(i, true);
    }
  }
}
