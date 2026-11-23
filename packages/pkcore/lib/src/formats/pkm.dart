import 'dart:typed_data';

import '../crypto/pk_crypto.dart';
import '../data/species.dart';
import '../data/species_convert.dart';
import '../model/save.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';

/// Lectores de entidades Pokémon individuales (PK1 … PK9).
///
/// Devuelven `null` para huecos vacíos o entidades con checksum inválido.
abstract final class PkmReader {
  // ---------------- Gen 1 / Gen 2 ----------------

  static bool _isShinyGb(int dvs) {
    final atk = (dvs >> 12) & 0xF;
    final def = (dvs >> 8) & 0xF;
    final spe = (dvs >> 4) & 0xF;
    final spc = dvs & 0xF;
    return def == 10 && spe == 10 && spc == 10 && const {2, 3, 6, 7, 10, 11, 14, 15}.contains(atk);
  }

  /// PK1: [d] apunta al inicio de la estructura (33 o 44 bytes).
  static PokemonSummary? pk1(Uint8List d, int offset, {required bool party, String? nickname}) {
    final species = SpeciesConvert.nationalFromGen1(d[offset]);
    if (species == 0) return null;
    final exp = (d[offset + 14] << 16) | (d[offset + 15] << 8) | d[offset + 16];
    final level = party ? d[offset + 33] : d[offset + 3];
    return PokemonSummary(
      species: species,
      level: level == 0 ? Species.levelFromExp(species, exp) : level,
      isShiny: _isShinyGb(d.u16be(offset + 27)),
      nickname: _gbNickname(species, nickname),
    );
  }

  /// PK2: [d] apunta al inicio de la estructura (32 o 48 bytes).
  static PokemonSummary? pk2(Uint8List d, int offset, {required bool isEgg, String? nickname}) {
    final species = d[offset];
    if (species == 0 || species > 251) return null;
    return PokemonSummary(
      species: species,
      heldItem: d[offset + 1],
      level: d[offset + 31],
      isShiny: _isShinyGb(d.u16be(offset + 21)),
      isEgg: isEgg,
      nickname: isEgg ? null : _gbNickname(species, nickname),
    );
  }

  static String? _gbNickname(int species, String? nick) {
    if (nick == null || nick.isEmpty) return null;
    final en = Species.name(species, SpeciesLanguage.en).toUpperCase();
    final es = Species.name(species, SpeciesLanguage.es).toUpperCase();
    final n = nick.toUpperCase().replaceAll('․', '.');
    if (n == en || n == es || n == en.replaceAll(' ', '')) return null;
    return nick;
  }

  // ---------------- Gen 3 ----------------

  /// PK3 cifrado (80 bytes almacenado, 100 en equipo).
  static PokemonSummary? pk3(Uint8List encrypted, {required bool party}) {
    if (encrypted.isAllValue(0)) return null;
    final d = PkCrypto.decrypt3(encrypted.copyRange(0, PkCrypto.size3Stored));
    if (PkCrypto.checksum3(d) != d.u16le(0x1C)) return null;
    final raw = d.u16le(0x20);
    final species = SpeciesConvert.nationalFromGen3(raw);
    if (species == 0) return null;
    final pid = d.u32le(0);
    final tid = d.u16le(4), sid = d.u16le(6);
    final iv32 = d.u32le(0x48);
    final isEgg = ((iv32 >> 30) & 1) == 1 || (d[0x13] & 0x04) != 0;
    final japanese = d[0x12] == 1;
    final exp = d.u32le(0x24);
    final level = party && encrypted.length >= PkCrypto.size3Party
        ? encrypted[0x54]
        : Species.levelFromExp(species, exp);
    final nick = StringCodec.decodeG3(d, 0x08, 10, japanese: japanese);
    return PokemonSummary(
      species: species,
      level: level,
      pid: pid,
      heldItem: d.u16le(0x22),
      isEgg: isEgg,
      isShiny: (tid ^ sid ^ (pid >> 16) ^ (pid & 0xFFFF)) < 8,
      nickname: isEgg ? null : _gbNickname(species, nick),
    );
  }

  // ---------------- Gen 4 / Gen 5 ----------------

  static PokemonSummary? pk45(Uint8List encrypted, {required int generation}) {
    if (encrypted.isAllValue(0)) return null;
    final d = PkCrypto.decrypt45(encrypted);
    if (PkCrypto.checksumFrom8(d, PkCrypto.size4Stored) != d.u16le(6)) return null;
    final species = d.u16le(0x08);
    if (!Species.isValid(species)) return null;
    final pid = d.u32le(0);
    final iv32 = d.u32le(0x38);
    final isEgg = ((iv32 >> 30) & 1) == 1;
    final nicknamed = ((iv32 >> 31) & 1) == 1;
    final level = d.length > PkCrypto.size4Stored
        ? d[0x8C]
        : Species.levelFromExp(species, d.u32le(0x10));
    final nick = generation == 4
        ? StringCodec.decodeG4(d, 0x48, 22)
        : StringCodec.decodeUtf16(d, 0x48, 22);
    return PokemonSummary(
      species: species,
      form: d[0x40] >> 3,
      level: level,
      pid: pid,
      heldItem: d.u16le(0x0A),
      isEgg: isEgg,
      isShiny: (d.u16le(0x0C) ^ d.u16le(0x0E) ^ (pid >> 16) ^ (pid & 0xFFFF)) < 8,
      nickname: nicknamed && !isEgg ? nick : null,
    );
  }

  // ---------------- Gen 6 / Gen 7 ----------------

  static PokemonSummary? pk67(Uint8List encrypted) {
    if (encrypted.isAllValue(0)) return null;
    final d = PkCrypto.decrypt67(encrypted);
    if (PkCrypto.checksumFrom8(d, PkCrypto.size6Stored) != d.u16le(6)) return null;
    final species = d.u16le(0x08);
    if (!Species.isValid(species)) return null;
    final pid = d.u32le(0x18);
    final iv32 = d.u32le(0x74);
    final isEgg = ((iv32 >> 30) & 1) == 1;
    final nicknamed = ((iv32 >> 31) & 1) == 1;
    final level = d.length > PkCrypto.size6Stored
        ? d[0xEC]
        : Species.levelFromExp(species, d.u32le(0x10));
    return PokemonSummary(
      species: species,
      form: d[0x1D] >> 3,
      level: level,
      pid: pid,
      heldItem: d.u16le(0x0A),
      isEgg: isEgg,
      isShiny: (d.u16le(0x0C) ^ d.u16le(0x0E) ^ (pid >> 16) ^ (pid & 0xFFFF)) < 16,
      nickname: nicknamed && !isEgg ? StringCodec.decodeUtf16(d, 0x40, 24) : null,
    );
  }

  // ---------------- Gen 8 (SwSh) / Gen 9 (SV) ----------------

  /// PK8/PK9 cifrado (0x148 o 0x158 bytes). En SV la especie es interna.
  static PokemonSummary? pk89(Uint8List encrypted, {required bool gen9}) {
    if (encrypted.isAllValue(0)) return null;
    final d = PkCrypto.decrypt8(encrypted);
    if (PkCrypto.checksumFrom8(d, PkCrypto.size8Stored) != d.u16le(6)) return null;
    final raw = d.u16le(0x08);
    final species = gen9 ? SpeciesConvert.nationalFromGen9(raw) : raw;
    if (!Species.isValid(species)) return null;
    final pid = d.u32le(0x1C);
    final iv32 = d.u32le(0x8C);
    final isEgg = ((iv32 >> 30) & 1) == 1;
    final nicknamed = ((iv32 >> 31) & 1) == 1;
    final level = d.length > PkCrypto.size8Stored && d[0x148] != 0
        ? d[0x148]
        : Species.levelFromExp(species, d.u32le(0x10));
    return PokemonSummary(
      species: species,
      form: d[0x24],
      level: level,
      pid: pid,
      heldItem: d.u16le(0x0A),
      isEgg: isEgg,
      isShiny: (d.u16le(0x0C) ^ d.u16le(0x0E) ^ (pid >> 16) ^ (pid & 0xFFFF)) < 16,
      nickname: nicknamed && !isEgg ? StringCodec.decodeUtf16(d, 0x58, 26) : null,
    );
  }
}
