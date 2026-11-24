import 'dart:typed_data';

import '../formats/rsbox.dart';
import '../formats/ranch.dart';
import '../formats/stadium.dart';
import '../model/game.dart';
import '../model/save.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';
import 'save_editor.dart';

/// Base de los juegos de almacenamiento (Box, Stadium, Battle Revolution,
/// Rancho): solo cajas (y, según el juego, un equipo), sin entrenador
/// editable. Si nada cambia, el archivo sale idéntico byte a byte.
abstract class StorageEditor extends SaveEditor {
  StorageEditor(super.game, {super.versionId});

  /// Nombre con el que se muestra la partida (el juego no guarda entrenador).
  String get trainerLabel => '';

  @override
  int get partyCapacity => 0;
  @override
  int get partyCount => 0;
  @override
  Pkm readPartySlot(int index) => throw RangeError.range(index, 0, 0, 'index');
  @override
  void writeParty(List<Pkm> party) {
    if (party.isNotEmpty) throw SaveEditException('${game.nameEs} no tiene equipo.');
  }

  @override
  Set<TrainerField> get trainerFields => const {};
  @override
  TrainerData readTrainer() => TrainerData(name: trainerLabel, tid: 0);
  @override
  void writeTrainer(TrainerData t) {}
}

/// Editor de Pokémon Box: Rubí y Zafiro: 25 cajas de 60 que se muestran como
/// 50 medias cajas de 30 (izquierda y derecha), como en PKHeX.
class RsBoxEditor extends StorageEditor {
  RsBoxEditor(Uint8List payload)
      : _d = RsBoxData.open(payload),
        super(GameVersion.boxRS, versionId: 65) {
    _pristine = Uint8List.fromList(_d.storage);
  }

  final RsBoxData _d;
  late final Uint8List _pristine;

  @override
  String get trainerLabel => 'BOX';
  @override
  int get boxCount => RsBoxData.boxCount;
  @override
  int get boxSlotCount => 30;

  /// Bytes de un hueco: PK3 cifrado (80) + ID32 del depositante.
  Uint8List slotBytes(int box, int slot) => _d.storage.copyRange(RsBoxData.slotOffset(box, slot), RsBoxData.slotSize);

  @override
  Pkm? readBoxSlot(int box, int slot) {
    final raw = slotBytes(box, slot);
    if ((raw[0x13] & 0xFB) != 2) return null; // PKHeX `IsPresentGBA`
    final pk = Pkm.fromEncrypted(PkFormat.pk3, raw.copyRange(0, 80));
    if (pk == null || !pk.checksumValid) return null;
    return pk;
  }

  @override
  void writeBoxSlot(int box, int slot, Pkm? pk) {
    final o = RsBoxData.slotOffset(box, slot);
    if (pk == null) {
      _d.storage.fillRange(o, o + RsBoxData.slotSize, 0);
      return;
    }
    final cur = readBoxSlot(box, slot);
    if (cur != null && _same(cur.data, pk.data)) return; // sin cambios
    _d.storage.setRange(o, o + 80, pk.encryptStored());
    _d.storage.setU32le(o + 80, (pk.tid & 0xFFFF) | ((pk.sid & 0xFFFF) << 16));
  }

  static bool _same(Uint8List a, Uint8List b) {
    for (var i = 0; i < 80; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String boxName(int box) {
    final o = RsBoxData.nameOffset(box);
    final raw = _d.storage[o];
    final base = raw == 0 || raw == 0xFF
        ? 'BOX ${box ~/ 2 + 1}'
        : StringCodec.decodeG3(_d.storage, o, 9, japanese: _d.japanese);
    return '$base ${box.isEven ? '◖' : '◗'}';
  }

  @override
  bool get canRenameBoxes => true;

  @override
  void setBoxName(int box, String name) {
    final clean = name.replaceAll(RegExp(r'\s*[◖◗]$'), '');
    final o = RsBoxData.nameOffset(box);
    _d.storage.setRange(o, o + 9, StringCodec.encodeG3(clean, 9, japanese: _d.japanese));
  }

  @override
  Uint8List buildPayload() {
    if (!forceChecksums) {
      var same = true;
      for (var i = 0; i < _pristine.length; i++) {
        if (_pristine[i] != _d.storage[i]) {
          same = false;
          break;
        }
      }
      if (same) return Uint8List.fromList(_d.payload);
    }
    return _d.build();
  }
}

/// Resumen de un save de almacenamiento a partir de su editor.
SaveFile storageSummary(SaveEditor ed, Uint8List raw, {required String format, required bool checksumOk, List<String> warnings = const []}) {
  final t = ed.readTrainer();
  return SaveFile(
    game: ed.game,
    versionId: ed.versionId,
    trainer: TrainerInfo(name: t.name, tid: t.tid, sid: t.sid, gender: t.gender, playTime: t.playTime),
    raw: raw,
    format: format,
    party: [for (var i = 0; i < ed.partyCount; i++) ed.readPartySlot(i).toSummary()],
    boxes: [
      for (var b = 0; b < ed.boxCount; b++)
        PokemonBox(index: b, name: ed.boxName(b), slots: [for (var s = 0; s < ed.boxSlotCount; s++) ed.readBoxSlot(b, s)?.toSummary()]),
    ],
    support: ReadSupport.full,
    checksum: checksumOk ? ChecksumStatus.valid : ChecksumStatus.invalid,
    warnings: warnings,
  );
}

/// Editor de Pokémon Stadium y Stadium 2 (N64): cajas (listas compactas con
/// contador y suma por caja) y equipos registrados en solo lectura.
class StadiumEditor extends StorageEditor {
  StadiumEditor(Uint8List payload, this.layout, {this.swapped = false})
      : _orig = payload,
        _d = swapped ? StadiumLayout.swap32(payload) : Uint8List.fromList(payload),
        super(layout.generation == 1 ? GameVersion.stadium : GameVersion.stadium2,
            versionId: layout.generation == 1 ? 93 : 94) {
    _base = layout.boxBase(_d);
    _pristine = Uint8List.fromList(_d);
  }

  final StadiumLayout layout;

  /// El archivo tenía las palabras de 32 bits invertidas.
  final bool swapped;
  final Uint8List _orig;
  final Uint8List _d;
  late final Uint8List _pristine;
  late final int _base;
  bool get _g1 => layout.generation == 1;
  PkFormat get _fmt => _g1 ? PkFormat.pk1 : PkFormat.pk2;

  @override
  String get trainerLabel => _g1 ? 'STADIUM' : 'STADIUM 2';
  @override
  int get boxCount => layout.boxCount;
  @override
  int get boxSlotCount => layout.slotsPerBox;

  /// La caja está inicializada (si no, el juego la crea vacía al abrirla).
  bool boxInitialized(int box) {
    final o = layout.boxOffset(box, _base);
    if (layout.headerMagic != null) return _d.u32be(o) == layout.headerMagic;
    if (!_g1) return _d[o] != 0;
    return true;
  }

  /// Sumas correctas de todas las cajas inicializadas.
  bool get checksumsValid {
    for (var b = 0; b < boxCount; b++) {
      if (boxInitialized(b) && !layout.boxChecksumValid(_d, b, _base)) return false;
    }
    return true;
  }

  int _count(int box) {
    if (!boxInitialized(box)) return 0;
    return (layout.count(_d, box, _base) ?? layout.slotsPerBox).clamp(0, layout.slotsPerBox);
  }

  Pkm? _readAt(int ofs) {
    final raw = _d.copyRange(ofs, layout.slotSize);
    if (raw[0] == 0) return null;
    final jp = layout.japanese;
    if (_g1) {
      return Pkm.fromGb(PkFormat.pk1, raw.copyRange(0, 33),
          nickname: StringCodec.decodeGb(raw, 33, layout.strLen, japanese: jp),
          otName: StringCodec.decodeGb(raw, 33 + layout.strLen, layout.strLen, japanese: jp),
          japanese: jp);
    }
    // SK2 → PK2 (PKHeX `SK2.ConvertToPK2`).
    final s = Uint8List(32);
    s.setRange(0, 8, raw); // especie, objeto, movimientos, TID
    final exp = raw.u32be(8);
    s[8] = (exp >> 16) & 0xFF;
    s[9] = (exp >> 8) & 0xFF;
    s[10] = exp & 0xFF;
    s.setRange(11, 23, raw, 0x0C); // EVs y DVs
    s.setRange(23, 27, raw, 0x18); // PP
    s[27] = raw[0x1C];
    s[28] = raw[0x20];
    s[29] = raw[0x21];
    s[30] = raw[0x22];
    s[31] = raw[0x1D];
    final pk = Pkm.fromGb(PkFormat.pk2, s,
        nickname: StringCodec.decodeGb(raw, 0x24, 12, japanese: jp),
        otName: StringCodec.decodeGb(raw, 0x30, 12, japanese: jp),
        japanese: jp,
        egg: raw[0x1E] & 1 == 1);
    pk.nativeRaw = raw;
    return pk;
  }

  Uint8List _encode(Pkm pk) {
    final jp = layout.japanese;
    final out = Uint8List(layout.slotSize);
    if (_g1) {
      out.setRange(0, 33, pk.data);
      out[3] = pk.level; // nivel de caja (PKHeX `Stat_LevelBox`)
      out.setRange(33, 33 + layout.strLen, StringCodec.encodeGb(pk.nickname, layout.strLen, japanese: jp));
      out.setRange(33 + layout.strLen, 33 + 2 * layout.strLen, StringCodec.encodeGb(pk.otName, layout.strLen, japanese: jp));
      return out;
    }
    final n = pk.nativeRaw;
    if (n != null && n.length == 60) out.setRange(0, 60, n);
    final s = pk.data;
    out.setRange(0, 8, s);
    final exp = (s[8] << 16) | (s[9] << 8) | s[10];
    out[8] = 0;
    out[9] = (exp >> 16) & 0xFF;
    out[10] = (exp >> 8) & 0xFF;
    out[11] = exp & 0xFF;
    out.setRange(0x0C, 0x18, s, 11);
    out.setRange(0x18, 0x1C, s, 23);
    out[0x1C] = s[27];
    out[0x20] = s[28];
    out[0x21] = s[29];
    out[0x22] = s[30];
    out[0x1D] = pk.level;
    out[0x1E] = (out[0x1E] & ~1) | (pk.isEgg ? 1 : 0);
    out.setRange(0x24, 0x30, StringCodec.encodeGb(pk.nickname, 12, japanese: jp));
    out.setRange(0x30, 0x3C, StringCodec.encodeGb(pk.otName, 12, japanese: jp));
    return out;
  }

  @override
  Pkm? readBoxSlot(int box, int slot) {
    if (layout.countAt != null && slot >= _count(box)) return null;
    return _readAt(layout.slotOffset(box, slot, _base));
  }

  static bool _sameMon(Pkm a, Pkm b) {
    if (a.nickname != b.nickname || a.otName != b.otName || a.isEgg != b.isEgg) return false;
    for (var i = 0; i < a.format.storedSize; i++) {
      if (a.data[i] != b.data[i]) return false;
    }
    return true;
  }

  @override
  void writeBoxSlot(int box, int slot, Pkm? pk) {
    if (pk != null && pk.format != _fmt) throw SaveEditException('Formato no compatible con ${game.nameEs}.');
    final cur = readBoxSlot(box, slot);
    if (pk != null && cur != null && _sameMon(cur, pk)) return;
    if (layout.countAt == null) {
      final o = layout.slotOffset(box, slot, _base);
      _d.setRange(o, o + layout.slotSize, pk == null ? Uint8List(layout.slotSize) : _encode(pk));
      return;
    }
    // Lista compacta: el juego solo lee los primeros «contador» huecos.
    final list = <Uint8List>[
      for (var s = 0; s < _count(box); s++) _d.copyRange(layout.slotOffset(box, s, _base), layout.slotSize),
    ];
    if (slot < list.length) {
      if (pk == null) {
        list.removeAt(slot);
      } else {
        list[slot] = _encode(pk);
      }
    } else if (pk != null) {
      if (list.length >= layout.slotsPerBox) throw const SaveEditException('La caja está llena.');
      list.add(_encode(pk));
    }
    final o = layout.boxOffset(box, _base);
    if (!boxInitialized(box)) _initBox(box);
    for (var s = 0; s < layout.slotsPerBox; s++) {
      final so = layout.slotOffset(box, s, _base);
      _d.setRange(so, so + layout.slotSize, s < list.length ? list[s] : Uint8List(layout.slotSize));
    }
    _d[o + layout.countAt!] = list.length;
  }

  void _initBox(int box) {
    final o = layout.boxOffset(box, _base);
    _d.fillRange(o, o + layout.boxSize, 0);
    if (layout.headerMagic != null) {
      final h = layout.headerMagic!;
      _d.setRange(o, o + 4, [h >> 24, (h >> 16) & 0xFF, (h >> 8) & 0xFF, h & 0xFF]);
    } else {
      // Stadium 2 (PKHeX `SetBoxMetadata`): inicializada, nombre «1234».
      _d[o] = 1;
      _d[o + 4] = 0x50;
      for (var i = 0; i < 4; i++) {
        _d[o + 0x10 + i] = 0xF6 + i;
      }
      _d[o + 0x14] = 0x50;
    }
    _d.setU32le(o + layout.boxSize - 6, layout.magic);
  }

  @override
  String boxName(int box) {
    if (!_g1 && boxInitialized(box)) {
      final n = StringCodec.decodeGb(_d, layout.boxOffset(box, _base) + 0x10, 12, japanese: layout.japanese).trim();
      if (n.isNotEmpty) return n;
    }
    return super.boxName(box);
  }

  @override
  bool get canRenameBoxes => !_g1;

  @override
  void setBoxName(int box, String name) {
    if (_g1) super.setBoxName(box, name);
    if (!boxInitialized(box)) _initBox(box);
    final o = layout.boxOffset(box, _base) + 0x10;
    _d.setRange(o, o + 12, StringCodec.encodeGb(name, 12, japanese: layout.japanese));
  }

  /// Equipos registrados (solo lectura): nombre y sus hasta 6 Pokémon.
  List<(String, List<Pkm>)> get teams => [
        for (final (name, ofs) in layout.teams())
          if (ofs + layout.teamSize <= _d.length)
            (name, [
              for (var i = 0; i < 6; i++)
                if (_readAt(ofs + layout.teamHeader + i * layout.slotSize) case final pk?) pk,
            ]),
      ];

  @override
  Uint8List buildPayload() {
    var changed = forceChecksums;
    for (var i = 0; i < _d.length && !changed; i++) {
      if (_d[i] != _pristine[i]) changed = true;
    }
    if (!changed) return Uint8List.fromList(_orig);
    final out = Uint8List.fromList(_d);
    for (var b = 0; b < boxCount; b++) {
      final o = layout.boxOffset(b, _base);
      var boxChanged = forceChecksums;
      for (var i = o; i < o + layout.boxSize && !boxChanged; i++) {
        if (out[i] != _pristine[i]) boxChanged = true;
      }
      if (boxChanged && boxInitialized(b)) layout.setBoxChecksum(out, b, _base);
    }
    return swapped ? StadiumLayout.swap32(out) : out;
  }
}

/// Editor de My Pokémon Ranch: los Pokémon depositados (RK4 = PK4 + datos del
/// rancho) en cajas de 30; los huecos por encima de la capacidad del nivel del
/// rancho están bloqueados. Al guardar se actualizan el contador, el marcador
/// de fin y el SHA-1 como PKHeX `SAV4Ranch.SetChecksums`.
class RanchEditor extends StorageEditor {
  RanchEditor(Uint8List payload)
      : _orig = payload,
        _d = Uint8List.fromList(payload),
        super(GameVersion.ranch, versionId: 200) {
    _pristine = Uint8List.fromList(_d);
    _start = RanchLayout.pokemonStart(_d);
    _capacity = RanchLayout.capacity(_d);
  }

  final Uint8List _orig, _d;
  late final Uint8List _pristine;
  late final int _start, _capacity;

  bool get platinum => RanchLayout.platinum(_d);
  int get capacity => _capacity;

  @override
  String get trainerLabel => RanchLayout.owner(_d);
  @override
  TrainerData readTrainer() => TrainerData(name: trainerLabel, tid: 0, playTime: RanchLayout.playTime(_d));
  @override
  int get boxCount => (_capacity + 29) ~/ 30;
  @override
  int get boxSlotCount => 30;

  int _index(int box, int slot) => box * 30 + slot;
  int _ofs(int i) => _start + i * RanchLayout.slotSize;

  @override
  bool isSlotLocked(SlotRef ref) => !ref.isParty && _index(ref.box, ref.slot) >= _capacity;

  @override
  Pkm? readBoxSlot(int box, int slot) {
    final i = _index(box, slot);
    if (i >= _capacity) return null;
    final raw = _d.copyRange(_ofs(i), RanchLayout.slotSize);
    if (raw.u32be(0) == 0x28) return null; // marcador de fin
    final pk4 = raw.copyRange(0, 136);
    final pk = pk4.u32le(0x64) != 0 ? Pkm.fromEncrypted(PkFormat.pk4, pk4) : Pkm.fromDecrypted(PkFormat.pk4, pk4);
    if (pk == null || pk.species == 0 || !pk.checksumValid) return null;
    pk.nativeRaw = raw;
    return pk;
  }

  @override
  void writeBoxSlot(int box, int slot, Pkm? pk) {
    final i = _index(box, slot);
    if (i >= _capacity) throw SaveEditException('El rancho solo admite $_capacity Pokémon con su nivel actual.');
    if (pk != null && pk.format != PkFormat.pk4) throw SaveEditException('Formato no compatible con ${game.nameEs}.');
    final o = _ofs(i);
    if (pk == null) {
      _d.fillRange(o, o + RanchLayout.slotSize, 0);
      return;
    }
    final cur = readBoxSlot(box, slot);
    if (cur != null) {
      var same = true;
      for (var j = 0; j < 136 && same; j++) {
        if (cur.data[j] != pk.data[j]) same = false;
      }
      if (same) return;
    }
    final out = Uint8List(RanchLayout.slotSize);
    final n = pk.nativeRaw;
    if (n != null && n.length == RanchLayout.slotSize) out.setRange(0, RanchLayout.slotSize, n);
    out.setRange(0, 136, pk.encryptStored());
    // Sin dueño, el rancho borra el Pokémon al cargar: Hayley por defecto (PKHeX).
    if (out[0x88] == 0) out[0x88] = 4;
    _d.setRange(o, o + RanchLayout.slotSize, out);
  }

  @override
  Uint8List buildPayload() {
    var changed = forceChecksums;
    for (var i = 0; i < _d.length && !changed; i++) {
      if (_d[i] != _pristine[i]) changed = true;
    }
    if (!changed) return Uint8List.fromList(_orig);
    final out = Uint8List.fromList(_d);
    var occupied = 0;
    for (var i = _capacity - 1; i >= 0; i--) {
      if (out.u32le(_ofs(i) + 0x88) != 0 || out.u32le(_ofs(i) + 0x8C) != 0) {
        occupied = i + 1;
        break;
      }
    }
    final end = _ofs(occupied);
    final marker = _pristine.u32be(_pristine.u32be(0x3C));
    void be(int at, int v) => out.setRange(at, at + 4, [v >> 24, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]);
    be(0x3C, end);
    out.fillRange(end, out.length, 0);
    be(end, marker);
    be(RanchLayout.countOffset(out), occupied);
    RanchLayout.setSha(out);
    return out;
  }
}
