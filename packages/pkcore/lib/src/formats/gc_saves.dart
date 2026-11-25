import 'dart:typed_data';

import '../crypto/gc_crypto.dart';
import '../model/game.dart';
import '../model/save.dart';
import '../pkm/gc_pkm.dart';
import '../util/bytes.dart';
import 'gc_container.dart';

/// Save de Pokémon Colosseum o XD sin cabecera GCI: descifra la ranura
/// activa, expone los offsets de sus bloques y la vuelve a cifrar.
///
/// Portado de PKHeX `SAV3Colosseum`, `SAV3XD`, `ColoCrypto` y `XDCrypto` (GPL-3.0).
class GcSaveData {
  GcSaveData._(this.title, this.payload, this.slotIndex, this.counter, this.slot);

  /// Descifra la ranura más reciente de [payload] (0x60000 Colosseum, 0x56000 XD).
  factory GcSaveData.open(GcTitle title, Uint8List payload) {
    if (title == GcTitle.rsBox) throw ArgumentError('Pokémon Box no es Colosseum/XD');
    final colo = title == GcTitle.colosseum;
    final (idx, ctr) = colo ? ColoCrypto.latest(payload) : XdCrypto.latest(payload);
    final ofs = colo ? ColoCrypto.slotOffset(idx) : XdCrypto.slotOffset(idx);
    final size = colo ? ColoCrypto.slotSize : XdCrypto.slotSize;
    final slot = payload.copyRange(ofs, size);
    if (colo) {
      ColoCrypto.decrypt(slot);
    } else {
      XdCrypto.decryptSlot(slot);
    }
    final s = GcSaveData._(title, payload, idx, ctr, slot);
    if (!colo) s._readXdHeader();
    return s;
  }

  final GcTitle title;

  /// Datos del archivo tal como llegaron (no se modifican).
  final Uint8List payload;
  final int slotIndex;
  final int counter;

  /// Ranura activa descifrada (copia de trabajo).
  final Uint8List slot;

  bool get isColosseum => title == GcTitle.colosseum;
  GameVersion get game => isColosseum ? GameVersion.colosseum : GameVersion.xd;
  GcKind get kind => isColosseum ? GcKind.ck3 : GcKind.xk3;
  int get monSize => kind.size;
  int get boxCount => isColosseum ? 3 : 8;
  static const int slotsPerBox = 30;

  final List<int> _subOfs = List.filled(16, 0);
  final List<int> _subLen = List.filled(16, 0);

  void _readXdHeader() {
    for (var i = 0; i < 16; i++) {
      _subLen[i] = slot.u16be(0x20 + 2 * i);
      _subOfs[i] = slot.u16be(0x40 + 4 * i) | (slot.u16be(0x40 + 4 * i + 2) << 16);
    }
    if (_subOfs[1] + 0xA8 + 0x8F0 > slot.length || _subOfs[2] + 0xA8 + 8 * (0x14 + 30 * 0xC4) > slot.length || _subOfs[0] + 0xA8 + 0x40 > slot.length) {
      throw const FormatException('Cabecera de bloques de XD fuera de la ranura.');
    }
  }

  /// Offsets dentro de la ranura descifrada (PKHeX `SAV3Colosseum.Initialize`, `SAV3XD.InitializeData`).
  int get config => isColosseum ? 0x08 : _subOfs[0] + 0xA8;
  int get trainer => isColosseum ? 0x78 : _subOfs[1] + 0xA8;
  int get party => isColosseum ? 0xA8 : trainer + 0x30;
  int get box => isColosseum ? 0xB90 : _subOfs[2] + 0xA8;
  int get daycare => isColosseum ? 0x8170 : _subOfs[4] + 0xA8;
  int get memo => isColosseum ? 0x82B0 : _subOfs[5] + 0xA8;
  int get memoLength => isColosseum ? 4 + 500 * 12 : _subLen[5];
  int get pouch => isColosseum ? 0x7F8 : trainer + 0x4C8;
  int get shadowTable => _subOfs[7] + 0xA8;
  int get shadowTableLength => isColosseum ? 0 : _subLen[7];

  /// XD japonés (tabla de oscuros con entradas de 60 bytes).
  bool get xdJapanese => !isColosseum && _subLen[7] == 0x1E00;
  int get shadowEntrySize => xdJapanese ? 60 : 72;
  int get shadowEntryCount => isColosseum ? 0 : shadowTableLength ~/ shadowEntrySize;

  int get tidOfs => isColosseum ? 0xA6 : trainer + 0x2E;
  int get sidOfs => isColosseum ? 0xA4 : trainer + 0x2C;
  int get genderOfs => isColosseum ? 0xAF8 : trainer + 0x8E0;
  int get moneyOfs => isColosseum ? 0xAFC : trainer + 0x8E4;
  int get couponsOfs => isColosseum ? 0xB00 : trainer + 0x8E8;

  int partySlot(int i) => party + i * monSize;
  int boxInfo(int b) => box + (30 * monSize + 0x14) * b;
  int boxSlot(int b, int s) => boxInfo(b) + 0x14 + s * monSize;

  GcRegion get currentRegion => GcRegion.fromByte(slot[config + 1]);
  GcRegion get originalRegion => GcRegion.fromByte(slot[config + 2]);
  int get gcLanguage => slot[config + 3];

  /// Japonés por región (las cadenas de 5 caracteres).
  bool get japanese => isColosseum ? currentRegion == GcRegion.ntscJ || payload[0] == 0x83 : xdJapanese;

  String readString(int ofs, int maxChars) {
    final out = StringBuffer();
    for (var i = 0; i < maxChars; i++) {
      final c = slot.u16be(ofs + i * 2);
      if (c == 0) break;
      out.writeCharCode(c);
    }
    return out.toString();
  }

  void writeString(int ofs, int bytes, String s, int maxChars) {
    slot.fillRange(ofs, ofs + bytes, 0);
    final r = s.runes.take(maxChars).toList();
    for (var i = 0; i < r.length; i++) {
      slot.setU16be(ofs + i * 2, r[i] & 0xFFFF);
    }
  }

  String get trainerName => readString(trainer, 10);
  int get tid => slot.u16be(tidOfs);
  int get sid => slot.u16be(sidOfs);

  Duration get playTime {
    final bd = ByteData.sublistView(slot);
    final double secs;
    if (isColosseum || xdJapanese) {
      secs = bd.getFloat32(config + 0x20);
    } else {
      secs = bd.getFloat64(config + 0x30);
    }
    if (!secs.isFinite || secs < 0) return Duration.zero;
    return Duration(milliseconds: (secs * 1000).round());
  }

  set playTime(Duration d) {
    final bd = ByteData.sublistView(slot);
    final secs = d.inMilliseconds / 1000.0;
    if (isColosseum || xdJapanese) {
      bd.setFloat32(config + 0x20, secs);
    } else {
      bd.setFloat64(config + 0x30, secs);
    }
  }

  /// Equipo (huecos con especie ≠ 0; el juego no guarda el número).
  int get partyCount {
    var n = 0;
    for (var i = 0; i < 6; i++) {
      if (slot.u16be(partySlot(i)) != 0) n++;
    }
    return n;
  }

  /// (cabecera válida, cuerpo válido) de la ranura activa tal como está en el archivo.
  (bool, bool) get checksums {
    final fresh = GcSaveData.open(title, payload);
    return isColosseum ? ColoCrypto.checksumsValid(fresh.slot) : XdCrypto.checksumsValid(fresh.slot, fresh._subOfs[0]);
  }

  /// Ranura con sumas recalculadas y cifrada, dentro de una copia de [payload].
  Uint8List build() {
    final s = Uint8List.fromList(slot);
    final out = Uint8List.fromList(payload);
    if (isColosseum) {
      ColoCrypto.setChecksums(s);
      ColoCrypto.encrypt(s);
      out.setRange(ColoCrypto.slotOffset(slotIndex), ColoCrypto.slotOffset(slotIndex) + s.length, s);
    } else {
      XdCrypto.setChecksums(s, _subOfs[0]);
      XdCrypto.encryptSlot(s);
      out.setRange(XdCrypto.slotOffset(slotIndex), XdCrypto.slotOffset(slotIndex) + s.length, s);
    }
    return out;
  }

  // ------------------------------------------------------------ Pokémon oscuros de XD

  int shadowEntry(int id) => shadowTable + id * shadowEntrySize;

  /// (purificación, purificado, capturado) de la tabla de XD, o null si [id] no está.
  (int, bool, bool)? xdShadow(int id) {
    if (isColosseum || id <= 0 || id >= shadowEntryCount) return null;
    final o = shadowEntry(id);
    final p = slot.u32be(o + 0x24);
    return (p >= 0x80000000 ? p - 0x100000000 : p, slot[o] >> 7 == 1, slot[o] >> 6 != 0);
  }

  /// Escribe el estado oscuro de un XK3 en la tabla (solo lo que cambió, como PKHeX
  /// `SAV3XD.SetPKM`: purificación, PID e IV; y el bit «purificado» si se editó).
  ///
  /// Con [speciesRaw] (Pokémon oscuro creado o importado) la entrada queda como
  /// la deja el juego al capturarlo: especie si estaba vacía, bit «capturado» e
  /// índice.
  void writeXdShadow(int id,
      {required int purification, required bool purified, required int pid, required List<int> ivsGc, int? speciesRaw}) {
    if (isColosseum || id <= 0 || id >= shadowEntryCount) return;
    final o = shadowEntry(id);
    if (speciesRaw != null) {
      if (slot.u16be(o + 0x1A) == 0) slot.setU16be(o + 0x1A, speciesRaw);
      if (slot[o] >> 6 == 0) slot[o] |= 0x40;
      final idx = o + (xdJapanese ? 0x35 : 0x3F);
      if (slot[idx] == 0 && id < 256) slot[idx] = id;
    }
    if (slot.u32be(o + 0x24) != (purification & 0xFFFFFFFF)) {
      final v = purification & 0xFFFFFFFF;
      slot[o + 0x24] = v >> 24;
      slot[o + 0x25] = (v >> 16) & 0xFF;
      slot[o + 0x26] = (v >> 8) & 0xFF;
      slot[o + 0x27] = v & 0xFF;
    }
    if ((slot[o] >> 7 == 1) != purified) slot[o] = (slot[o] & 0x7F) | (purified ? 0x80 : 0);
    if (slot.u32be(o + 0x1C) != pid) {
      slot[o + 0x1C] = pid >> 24;
      slot[o + 0x1D] = (pid >> 16) & 0xFF;
      slot[o + 0x1E] = (pid >> 8) & 0xFF;
      slot[o + 0x1F] = pid & 0xFF;
    }
    for (var i = 0; i < 6; i++) {
      if (slot[o + 0x0B + i] != ivsGc[i]) slot[o + 0x0B + i] = ivsGc[i];
    }
  }

  /// Estado de los Pokémon oscuros de la tabla de XD (id, especie interna, purificación, capturado, purificado).
  List<({int id, int speciesRaw, int purification, bool snagged, bool purified})> get xdShadowTable => [
        for (var id = 1; id < shadowEntryCount; id++)
          if (slot.u16be(shadowEntry(id) + 0x1A) != 0)
            (
              id: id,
              speciesRaw: slot.u16be(shadowEntry(id) + 0x1A),
              purification: xdShadow(id)!.$1,
              snagged: xdShadow(id)!.$3,
              purified: xdShadow(id)!.$2,
            ),
      ];

  // ------------------------------------------------------------ identificación

  /// Datos sin cabecera con la estructura de Colosseum/XD (PKHeX `IsG3Colosseum`/`IsG3XD`).
  static GcTitle? identifyRaw(Uint8List d) {
    if (d.length == ColoCrypto.saveSize) {
      for (var i = 0; i < ColoCrypto.slotCount; i++) {
        if (d.u32le(ColoCrypto.slotOffset(i)) != 0x101) return null;
      }
      return GcTitle.colosseum;
    }
    if (d.length == XdCrypto.saveSize) {
      for (var i = 0; i < XdCrypto.slotCount; i++) {
        if ((d.u32le(XdCrypto.slotOffset(i)) & 0xFFFEFFFF) != 0x101) return null;
      }
      return GcTitle.xd;
    }
    return null;
  }
}

/// Lector de resúmenes de Colosseum/XD.
abstract final class GcSaveReader {
  static SaveFile read(Uint8List payload, GcTitle title, GcContainer container) {
    final s = GcSaveData.open(title, payload);
    PokemonSummary? mon(int ofs) {
      final pk = GcPkm.read(s.kind, s.slot.copyRange(ofs, s.monSize));
      return pk?.toSummary();
    }

    final party = <PokemonSummary>[
      for (var i = 0; i < 6; i++) ?mon(s.partySlot(i)),
    ];
    final boxes = <PokemonBox>[
      for (var b = 0; b < s.boxCount; b++)
        PokemonBox(
          index: b,
          name: () {
            final n = s.readString(s.boxInfo(b), 8);
            return n.isEmpty ? 'Caja ${b + 1}' : n;
          }(),
          slots: [for (var i = 0; i < GcSaveData.slotsPerBox; i++) mon(s.boxSlot(b, i))],
        ),
    ];
    final (h, body) = s.checksums;
    final region = container.entry?.region ?? s.currentRegion;
    return SaveFile(
      game: s.game,
      versionId: s.isColosseum ? 66 : 67,
      trainer: TrainerInfo(
        name: s.trainerName,
        tid: s.tid,
        sid: s.sid,
        gender: s.slot[s.genderOfs],
        playTime: s.playTime,
        language: GcPkm.mainLanguage(s.gcLanguage),
      ),
      raw: payload,
      format: 'GameCube ${s.isColosseum ? 'Colosseum' : 'XD'} ${region.label} (ranura ${s.slotIndex + 1})',
      party: party,
      boxes: boxes,
      support: ReadSupport.full,
      checksum: h && body ? ChecksumStatus.valid : ChecksumStatus.invalid,
    );
  }
}
