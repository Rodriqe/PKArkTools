import 'dart:typed_data';

import '../formats/rsbox.dart';
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
