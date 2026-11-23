import 'dart:typed_data';

import '../crypto/pk_crypto.dart';
import '../crypto/sc_block.dart';
import '../model/game.dart';
import '../model/save.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';
import 'pkm.dart';

/// Claves de bloques SCBlock. Portadas de PKHeX `SaveBlockAccessor8SWSH/8LA/9SV/9ZA` (GPL-3.0).
abstract final class SCKeys {
  // Comunes
  static const int boxLayout = 0x19722C89;

  // Espada / Escudo
  static const int swshMyStatus = 0xF25C070E;
  static const int swshPlayTime = 0x8CBBFD90;
  static const int swshParty = 0x2985FE5D;
  static const int swshBox = 0x0D66012C;

  // Leyendas Arceus
  static const int laMyStatus = 0xF25C070E;
  static const int laPlayTime = 0xC4FA7C8C;
  static const int laParty = 0x2985FE5D;
  static const int laBox = 0x47E1CEAB;

  // Escarlata / Púrpura y Leyendas Z-A
  static const int svMyStatus = 0xE3E89BD1;
  static const int svPlayTime = 0xEDAFF794;
  static const int svParty = 0x3AA1A9AD;
  static const int svBox = 0x0D66012C;

  /// Bloques exclusivos de Z-A (estado de Mable y su registro de tareas).
  static const int zaStatusMable = 0x85DBDCE9;
  static const int zaEventWorkMable = 0x03913534;

  /// Tiempo de juego de Z-A: segundos en coma flotante (double). El bloque
  /// `svPlayTime` existe pero el juego no lo usa (PKHeX `PlayTime9a`).
  static const int zaPlayedSeconds = 0xCE3AF8F2;

  /// Revisión del save de Z-A: 0 = juego base, 1 = Mega Dimensión, 2 = última
  /// actualización (PKHeX `SAV9ZA.SaveRevision`).
  static const int zaSaveRevision = 0x0926555A;
}

/// Revisión más alta de save de Z-A que se sabe leer y escribir.
const int kZaMaxKnownRevision = 2;

/// Segundos de juego de Z-A guardados como double en un bloque de 8 bytes.
Duration? zaPlayTime(SCBlock? b) {
  if (b == null || b.data.length < 8) return null;
  final s = ByteData.sublistView(b.data).getFloat64(0, Endian.little);
  if (!s.isFinite || s < 0) return Duration.zero;
  return Duration(seconds: s.floor());
}

/// Escribe [t] en el bloque de segundos de Z-A conservando la fracción de segundo.
void setZaPlayTime(SCBlock b, Duration t) {
  final bd = ByteData.sublistView(b.data);
  final old = bd.getFloat64(0, Endian.little);
  final frac = old.isFinite && old > 0 ? old - old.floorToDouble() : 0.0;
  bd.setFloat64(0, t.inSeconds + frac, Endian.little);
}

/// Tamaños conocidos de `main` (PKHeX `SaveUtil`), usados como pista adicional.
abstract final class SwitchSizes {
  static const swsh = {0x1716B3, 0x17195E, 0x180B19, 0x180AD0, 0x1876B1, 0x187693, 0x187668, 0x18764A};
  static const la = {0x136DDE, 0x13AD06};
  static const za = {0x2F3284, 0x2F3289, 0x309FA6, 0x309FB3};
  static const bdsp = {0xE9828: 0x25, 0xEDC20: 0x2C, 0xEED8C: 0x32, 0xEF0A4: 0x34};
  static const int lgpe = 0x100000;
  static const int lgpeUsed = 0xB8800;
}

/// Identifica qué juego de Switch contiene un conjunto de bloques ya descifrado.
GameVersion? classifySwishBlocks(SCBlockSet blocks, int fileSize) {
  if (blocks.contains(SCKeys.swshMyStatus)) {
    if (blocks.contains(SCKeys.laBox) || SwitchSizes.la.contains(fileSize)) return GameVersion.legendsArceus;
    if (blocks.contains(SCKeys.swshBox)) return GameVersion.swordShield;
    return SwitchSizes.swsh.contains(fileSize) ? GameVersion.swordShield : null;
  }
  if (blocks.contains(SCKeys.svMyStatus)) {
    if (SwitchSizes.za.contains(fileSize) ||
        blocks.contains(SCKeys.zaStatusMable) ||
        blocks.contains(SCKeys.zaEventWorkMable)) {
      return GameVersion.legendsZA;
    }
    return GameVersion.scarletViolet;
  }
  return null;
}

abstract final class SwitchSaveReader {
  static String _boxName(SCBlock? layout, int b) {
    if (layout == null || !layout.data.hasRange(b * 0x22, 0x22)) return 'Caja ${b + 1}';
    final n = StringCodec.decodeUtf16(layout.data, b * 0x22, 0x22);
    return n.isEmpty ? 'Caja ${b + 1}' : n;
  }

  static Duration _playTime16(SCBlock? b) => b == null || b.data.length < 4
      ? Duration.zero
      : Duration(hours: b.data.u16le(0), minutes: b.data[2], seconds: b.data[3]);

  static Duration _playTime32(SCBlock? b) => b == null || b.data.length < 12
      ? Duration.zero
      : Duration(hours: b.data.s32le(0), minutes: b.data.s32le(4), seconds: b.data.s32le(8));

  static SaveFile readSwish(Uint8List raw, SCBlockSet blocks, GameVersion game) {
    final warnings = <String>[];
    switch (game) {
      case GameVersion.swordShield:
        final s = blocks[SCKeys.swshMyStatus]!.data;
        final trainer = TrainerInfo(
          name: StringCodec.decodeUtf16(s, 0xB0, 0x1A),
          tid: s.u16le(0xA0),
          sid: s.u16le(0xA2),
          gender: s[0xA5],
          language: s[0xA7],
          playTime: _playTime16(blocks[SCKeys.swshPlayTime]),
          sixDigitIds: true,
        );
        final (party, boxes) = _readPk8Storage(blocks[SCKeys.swshParty], blocks[SCKeys.swshBox],
            blocks[SCKeys.boxLayout], gen9: false, warnings: warnings);
        final v = s[0xA4];
        return SaveFile(
          game: game,
          versionId: v == 44 || v == 45 ? v : null,
          trainer: trainer,
          raw: raw,
          format: 'SCBlock cifrado (SwishCrypto) · ${blocks.length} bloques',
          party: party,
          boxes: boxes,
          support: ReadSupport.full,
          checksum: ChecksumStatus.valid,
          warnings: warnings,
        );
      case GameVersion.scarletViolet:
        final s = blocks[SCKeys.svMyStatus]!.data;
        final trainer = TrainerInfo(
          name: StringCodec.decodeUtf16(s, 0x10, 0x1A),
          tid: s.u16le(0x00),
          sid: s.u16le(0x02),
          gender: s[0x05],
          language: s[0x07],
          playTime: _playTime32(blocks[SCKeys.svPlayTime]),
          sixDigitIds: true,
        );
        final (party, boxes) = _readPk8Storage(blocks[SCKeys.svParty], blocks[SCKeys.svBox],
            blocks[SCKeys.boxLayout], gen9: true, warnings: warnings);
        final v = s[0x04];
        return SaveFile(
          game: game,
          versionId: v == 50 || v == 51 ? v : null,
          trainer: trainer,
          raw: raw,
          format: 'SCBlock cifrado (SwishCrypto) · ${blocks.length} bloques',
          party: party,
          boxes: boxes,
          support: ReadSupport.full,
          checksum: ChecksumStatus.valid,
          warnings: warnings,
        );
      case GameVersion.legendsArceus:
        final s = blocks[SCKeys.laMyStatus]!.data;
        final (party, boxes) = _readGeneric(blocks[SCKeys.laParty], blocks[SCKeys.laBox], blocks[SCKeys.boxLayout],
            format: PkFormat.pa8, partySlot: 0x178, boxSlot: 0x168, boxRead: 0x168, countAt: 6 * 0x178, warnings: warnings);
        return SaveFile(
          game: game,
          versionId: 47,
          trainer: TrainerInfo(
            name: StringCodec.decodeUtf16(s, 0x20, 0x1A),
            tid: s.u16le(0x10),
            sid: s.u16le(0x12),
            gender: s[0x15],
            language: s[0x17],
            playTime: _playTime16(blocks[SCKeys.laPlayTime]),
            sixDigitIds: true,
          ),
          raw: raw,
          format: 'SCBlock cifrado (SwishCrypto) · ${blocks.length} bloques',
          party: party,
          boxes: boxes,
          support: ReadSupport.full,
          checksum: ChecksumStatus.valid,
          warnings: warnings,
        );
      case GameVersion.legendsZA:
        final status = blocks[SCKeys.svMyStatus];
        final rev = blocks[SCKeys.zaSaveRevision]?.intValue ?? 0;
        if (status == null || blocks[SCKeys.svParty] == null || blocks[SCKeys.svBox] == null) {
          throw UnsupportedSaveException(
              'Save de Leyendas Pokémon Z-A (revisión $rev) sin los bloques de entrenador, equipo o cajas: '
              'probablemente es de una versión del juego que esta app aún no soporta.',
              size: raw.length);
        }
        if (rev > kZaMaxKnownRevision) {
          warnings.add('Save de Leyendas Z-A de una versión más nueva que la conocida (revisión $rev): '
              'se lee, pero conviene no editarlo hasta actualizar la app.');
        }
        final s = status.data;
        final (party, boxes) = _readGeneric(blocks[SCKeys.svParty], blocks[SCKeys.svBox], blocks[SCKeys.boxLayout],
            format: PkFormat.pa9, partySlot: 0x158 + 0x88, boxSlot: 0x158 + 0x40, boxRead: 0x158, countAt: -1,
            warnings: warnings);
        return SaveFile(
          game: game,
          versionId: 52,
          trainer: TrainerInfo(
            name: StringCodec.decodeUtf16(s, 0x10, 0x1A),
            tid: s.u16le(0x00),
            sid: s.u16le(0x02),
            gender: s[0x05],
            language: s[0x07],
            playTime: zaPlayTime(blocks[SCKeys.zaPlayedSeconds]) ?? _playTime32(blocks[SCKeys.svPlayTime]),
            sixDigitIds: true,
          ),
          raw: raw,
          format: 'SCBlock cifrado (SwishCrypto) · ${blocks.length} bloques',
          party: party,
          boxes: boxes,
          support: ReadSupport.full,
          checksum: ChecksumStatus.valid,
          warnings: warnings,
        );
      default:
        throw ArgumentError('Juego no SwishCrypto: $game');
    }
  }

  static (List<PokemonSummary>, List<PokemonBox>) _readPk8Storage(
      SCBlock? partyBlock, SCBlock? boxBlock, SCBlock? layout,
      {required bool gen9, required List<String> warnings}) {
    const size = PkCrypto.size8Party;
    final party = <PokemonSummary>[];
    if (partyBlock != null && partyBlock.data.length >= 6 * size + 1) {
      final count = partyBlock.data[6 * size].clamp(0, 6);
      for (var i = 0; i < count; i++) {
        final pk = PkmReader.pk89(partyBlock.data.copyRange(i * size, size), gen9: gen9);
        if (pk != null) party.add(pk);
      }
    } else {
      warnings.add('No se encontró el bloque del equipo.');
    }
    final boxes = <PokemonBox>[];
    if (boxBlock != null) {
      final boxCount = (boxBlock.data.length ~/ (30 * size)).clamp(0, 40);
      for (var b = 0; b < boxCount; b++) {
        boxes.add(PokemonBox(
          index: b,
          name: _boxName(layout, b),
          slots: [
            for (var s = 0; s < 30; s++) PkmReader.pk89(boxBlock.data.copyRange((b * 30 + s) * size, size), gen9: gen9),
          ],
        ));
      }
    } else {
      warnings.add('No se encontró el bloque de cajas.');
    }
    return (party, boxes);
  }

  /// Lector genérico de equipo + cajas con [Pkm] (PA8, PA9, PB7, PB8).
  static (List<PokemonSummary>, List<PokemonBox>) _readGeneric(SCBlock? partyBlock, SCBlock? boxBlock, SCBlock? layout,
      {required PkFormat format,
      required int partySlot,
      required int boxSlot,
      required int boxRead,
      required int countAt,
      required List<String> warnings,
      int slotsPerBox = 30,
      int maxBoxes = 40}) {
    final party = <PokemonSummary>[];
    if (partyBlock != null) {
      final d = partyBlock.data;
      final count = countAt >= 0 && d.length > countAt ? d[countAt].clamp(0, 6) : 6;
      for (var i = 0; i < count && d.hasRange(i * partySlot, format.partySize); i++) {
        final pk = decodeSlot(format, d, i * partySlot, format.partySize);
        if (pk == null) {
          if (countAt < 0) break;
          continue;
        }
        party.add(pk.toSummary());
      }
    } else {
      warnings.add('No se encontró el bloque del equipo.');
    }
    final boxes = <PokemonBox>[];
    if (boxBlock != null) {
      final d = boxBlock.data;
      final boxCount = (d.length ~/ (slotsPerBox * boxSlot)).clamp(0, maxBoxes);
      for (var b = 0; b < boxCount; b++) {
        boxes.add(PokemonBox(
          index: b,
          name: _boxName(layout, b),
          slots: [
            for (var s = 0; s < slotsPerBox; s++) decodeSlot(format, d, (b * slotsPerBox + s) * boxSlot, boxRead)?.toSummary(),
          ],
        ));
      }
    } else {
      warnings.add('No se encontró el bloque de cajas.');
    }
    return (party, boxes);
  }

  /// Descifra un hueco; null si está vacío o es inválido.
  static Pkm? decodeSlot(PkFormat format, Uint8List d, int ofs, int size) {
    if (!d.hasRange(ofs, size)) return null;
    final pk = Pkm.fromEncrypted(format, d.copyRange(ofs, size));
    if (pk == null || !pk.checksumValid || pk.species == 0) return null;
    return pk;
  }

  // ---------------- Let's Go (sin SCBlock) ----------------

  static bool isLetsGo(Uint8List d) {
    if (d.length != SwitchSizes.lgpe) return false;
    const used = SwitchSizes.lgpeUsed;
    if (d.u32le(used - 0x1F0) != 0x42454546) return false;
    return d.u16le(used - 0x200 + 0xB0) == 0x13;
  }

  static SaveFile readLetsGo(Uint8List d) {
    const s = 0x1000;
    const pt = 0x45400;
    final v = d[s + 4];
    return SaveFile(
      game: GameVersion.letsGo,
      versionId: v == 42 || v == 43 ? v : null,
      trainer: TrainerInfo(
        name: StringCodec.decodeUtf16(d, s + 0x38, 0x1A),
        tid: d.u16le(s),
        sid: d.u16le(s + 2),
        gender: d[s + 5],
        playTime: Duration(hours: d.u16le(pt), minutes: d[pt + 2], seconds: d[pt + 3]),
        sixDigitIds: true,
      ),
      raw: d,
      format: 'savedata.bin (BEEF)',
      party: [
        for (var i = 0; i < 6; i++)
          if (d.u16le(0x5A00 + i * 2) < 1000)
            ?decodeSlot(PkFormat.pb7, d, 0x5C00 + d.u16le(0x5A00 + i * 2) * 0x104, 0x104)?.toSummary(),
      ],
      boxes: [
        for (var b = 0; b < 40; b++)
          PokemonBox(index: b, name: 'Caja ${b + 1}', slots: [
            for (var s = 0; s < 25; s++) decodeSlot(PkFormat.pb7, d, 0x5C00 + (b * 25 + s) * 0x104, 0x104)?.toSummary(),
          ]),
      ],
      support: ReadSupport.full,
    );
  }

  // ---------------- BDSP (sin SCBlock) ----------------

  static bool isBdsp(Uint8List d) {
    final expected = SwitchSizes.bdsp[d.length];
    return expected != null && d.u32le(0) == expected;
  }

  static SaveFile readBdsp(Uint8List d) {
    const s = 0x79BB4;
    const pt = 0x79C04;
    return SaveFile(
      game: GameVersion.brilliantDiamondShiningPearl,
      trainer: TrainerInfo(
        name: StringCodec.decodeUtf16(d, s, 0x1A),
        tid: d.u16le(s + 0x1C),
        sid: d.u16le(s + 0x1E),
        gender: d[s + 0x24] == 1 ? 0 : 1,
        playTime: Duration(hours: d.u16le(pt), minutes: d[pt + 2], seconds: d[pt + 3]),
        sixDigitIds: true,
      ),
      raw: d,
      format: 'SaveData.bin (rev. 0x${d.u32le(0).toRadixString(16)})',
      party: [
        for (var i = 0; i < d[0x14098 + 6 * 0x158].clamp(0, 6); i++)
          ?decodeSlot(PkFormat.pb8, d, 0x14098 + i * 0x158, 0x158)?.toSummary(),
      ],
      boxes: [
        for (var b = 0; b < 40; b++)
          PokemonBox(index: b, name: _bdspBoxName(d, b), slots: [
            for (var s = 0; s < 30; s++) decodeSlot(PkFormat.pb8, d, 0x14EF4 + (b * 30 + s) * 0x158, 0x158)?.toSummary(),
          ]),
      ],
      support: ReadSupport.full,
    );
  }

  static String _bdspBoxName(Uint8List d, int b) {
    final n = StringCodec.decodeUtf16(d, 0x148AA + b * 0x22, 0x22);
    return n.isEmpty ? 'Caja ${b + 1}' : n;
  }
}
