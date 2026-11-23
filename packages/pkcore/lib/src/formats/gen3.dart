import 'dart:typed_data';

import '../crypto/pk_crypto.dart';
import '../model/game.dart';
import '../model/save.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';
import '../util/checksums.dart';
import 'pkm.dart';

/// Saves de GBA (Rubí/Zafiro, Esmeralda, Rojo Fuego/Verde Hoja).
///
/// Estructura: 2 ranuras de 14 sectores de 0x1000 (más 4 sectores extra).
/// Cada sector tiene un pie con id (0xFF4), checksum (0xFF6), firma
/// 0x08012025 (0xFF8) y contador de guardado (0xFFC).
/// Portado de PKHeX `SAV3` (GPL-3.0).
abstract final class Gen3 {
  static const int sectorSize = 0x1000;
  static const int sectorUsed = 0xF80;
  static const int mainCount = 14;
  static const int slotSize = mainCount * sectorSize;
  static const int signature = 0x08012025;
  static const int boxCount = 14;
  static const int slotsPerBox = 30;

  /// Devuelve el offset del sector 0 si la ranura tiene los 14 sectores.
  static int? sector0IfComplete(Uint8List d, int slot) {
    final start = slotSize * slot;
    if (!d.hasRange(start, slotSize)) return null;
    var bits = 0;
    int? sector0;
    for (var ofs = start; ofs < start + slotSize; ofs += sectorSize) {
      final id = d.u16le(ofs + 0xFF4);
      if (id >= mainCount) return null;
      bits |= 1 << id;
      if (id == 0) sector0 = ofs;
    }
    return bits == 0x3FFF ? sector0 : null;
  }

  static int activeSlot(Uint8List d) {
    if (d.length < 2 * slotSize) return 0;
    final s0 = sector0IfComplete(d, 0);
    final s1 = sector0IfComplete(d, 1);
    if (s0 == null) return s1 != null ? 1 : 0;
    if (s1 == null) return 0;
    final c0 = d.u32le(s0 + 0xFFC), c1 = d.u32le(s1 + 0xFFC);
    if (c0 == 0xFFFFFFFF && c1 != 0xFFFFFFFE) return 1;
    if (c1 == 0xFFFFFFFF && c0 != 0xFFFFFFFE) return 0;
    return c1 > c0 ? 1 : 0;
  }

  /// Distingue RS / E / FRLG a partir del bloque pequeño (sector 0).
  static GameVersion versionFromSmall(Uint8List small) {
    final v = small.u32le(0xAC);
    if (v == 1) return GameVersion.fireRedLeafGreen;
    if (v == 0) return GameVersion.rubySapphire;
    for (var i = 0x890; i < 0xF2C; i++) {
      if (small[i] != 0) return GameVersion.emerald;
    }
    return GameVersion.rubySapphire;
  }

  static SaveFile read(Uint8List d) {
    final slot = activeSlot(d);
    final start = slot * slotSize;
    final sectors = <int, int>{};
    var checksumOk = true;
    for (var ofs = start; ofs < start + slotSize; ofs += sectorSize) {
      final id = d.u16le(ofs + 0xFF4);
      sectors[id] = ofs;
      if (Checksums.checkSum32(d, ofs, sectorUsed) != d.u16le(ofs + 0xFF6)) {
        checksumOk = false;
      }
    }
    Uint8List concat(int from, int to) {
      final out = Uint8List((to - from + 1) * sectorUsed);
      for (var id = from; id <= to; id++) {
        out.setRange((id - from) * sectorUsed, (id - from + 1) * sectorUsed, d, sectors[id]!);
      }
      return out;
    }

    final small = concat(0, 0);
    final large = concat(1, 4);
    final storage = concat(5, 13);
    final game = versionFromSmall(small);

    final partyCountOfs = game == GameVersion.fireRedLeafGreen ? 0x34 : 0x234;
    final partyOfs = partyCountOfs + 4;
    final count = large[partyCountOfs].clamp(0, 6);
    final party = <PokemonSummary>[];
    for (var i = 0; i < count; i++) {
      final pk = PkmReader.pk3(large.view(partyOfs + i * PkCrypto.size3Party, PkCrypto.size3Party), party: true);
      if (pk != null) party.add(pk);
    }

    // Idioma: el save no lo guarda; se infiere de los Pokémon propios.
    var japanese = false;
    if (count > 0) {
      final first = PkCrypto.decrypt3(large.copyRange(partyOfs, PkCrypto.size3Stored));
      japanese = first[0x12] == 1;
    }

    final boxes = <PokemonBox>[];
    const namesOfs = 4 + boxCount * slotsPerBox * PkCrypto.size3Stored;
    for (var b = 0; b < boxCount; b++) {
      final slots = <PokemonSummary?>[];
      for (var s = 0; s < slotsPerBox; s++) {
        final ofs = 4 + (b * slotsPerBox + s) * PkCrypto.size3Stored;
        slots.add(PkmReader.pk3(storage.view(ofs, PkCrypto.size3Stored), party: false));
      }
      final name = StringCodec.decodeG3(storage, namesOfs + b * 9, 9, japanese: japanese);
      boxes.add(PokemonBox(index: b, name: name.isEmpty ? 'Caja ${b + 1}' : name, slots: slots));
    }

    final trainer = TrainerInfo(
      name: StringCodec.decodeG3(small, 0, 7, japanese: japanese),
      gender: small[0x08],
      tid: small.u16le(0x0A),
      sid: small.u16le(0x0C),
      playTime: Duration(hours: small.u16le(0x0E), minutes: small[0x10], seconds: small[0x11]),
      language: japanese ? 1 : null,
    );

    return SaveFile(
      game: game,
      trainer: trainer,
      raw: d,
      format: 'Flash GBA ${d.length == 0x10000 ? '64 KB' : '128 KB'} (ranura ${slot + 1})',
      party: party,
      boxes: boxes,
      support: ReadSupport.full,
      checksum: checksumOk ? ChecksumStatus.valid : ChecksumStatus.invalid,
    );
  }
}
