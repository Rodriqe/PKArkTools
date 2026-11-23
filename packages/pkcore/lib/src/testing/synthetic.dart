import 'dart:typed_data';

import 'package:crypto/crypto.dart' show md5;

import '../crypto/meme_crypto.dart';
import '../crypto/pk_crypto.dart';
import '../crypto/sc_block.dart';
import '../crypto/swish_crypto.dart';
import '../edit/ctr_editors.dart';
import '../edit/gb_editors.dart';
import '../formats/gb_saves.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import '../data/game_data.dart';
import '../data/species.dart';
import '../data/species_convert.dart';
import '../formats/ctr_saves.dart';
import '../legal/encounters.dart';
import '../legal/origin.dart';
import '../legal/ribbons.dart';
import '../formats/nds_saves.dart';
import '../formats/switch_saves.dart';
import '../model/game.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';
import '../util/checksums.dart';
import '../write/save_writer.dart';

/// Pokémon a incluir en un save sintético.
class SynthMon {
  const SynthMon(this.species,
      {this.level = 5, this.nickname, this.shiny = false, this.egg = false, this.item = 0, this.form = 0, this.gigantamax = false});

  final int species;

  /// Forma (índice de PKHeX; Gen 4 en adelante).
  final int form;

  /// Factor Gigamax (solo PK8).
  final bool gigantamax;
  final int level;
  final String? nickname;
  final bool shiny;
  final bool egg;
  final int item;
}

/// Entrenador de un save sintético.
class SynthTrainer {
  const SynthTrainer({
    this.name = 'ASH',
    this.tid = 12345,
    this.sid = 54321,
    this.gender = 0,
    this.hours = 12,
    this.minutes = 34,
    this.seconds = 56,
    this.versionId,
  });

  final String name;
  final int tid, sid, gender, hours, minutes, seconds;
  final int? versionId;
}

/// Generadores de saves mínimos pero estructuralmente válidos, sin contenido
/// con copyright: solo estructuras, checksums y cifrados reimplementados.
///
/// Se usan en los tests de `pkcore` y en el modo demostración de la app.
abstract final class SyntheticSaves {
  // ------------------------------------------------------------ entidades

  static int _pidFor(SynthMon m, int tid, int sid, int salt, {int threshold = 8}) {
    final low = (0x1234 + salt * 0x9E37 + m.species * 31) & 0xFFFF;
    final hiShiny = (tid ^ sid ^ low) & 0xFFFF; // xor = 0
    final hi = m.shiny ? hiShiny : (hiShiny ^ 0x8000);
    final pid = (hi << 16) | low;
    assert(((tid ^ sid ^ hi ^ low) < threshold) == m.shiny);
    return pid;
  }

  /// Género coherente con la especie (0 macho, 1 hembra, 2 sin género).
  static int _genderFor(int species, int pid) {
    var t = GameDataTable.forGame(GameVersion.scarletViolet);
    if (!t.hasSpecies(species)) t = GameDataTable.forGame(GameVersion.ultraSunUltraMoon);
    final r = t.entry(species)?.genderRatio ?? 255;
    if (r == 255) return 2;
    if (r == 254) return 1;
    if (r == 0) return 0;
    return (pid & 0xFF) < r ? 1 : 0;
  }

  static Uint8List _pk1(SynthMon m, int tid, {required bool party}) {
    final d = Uint8List(party ? 44 : 33);
    d[0] = SpeciesConvert.gen1FromNational(m.species);
    d[3] = m.level;
    d.setU16be(12, tid);
    final exp = Species.expForLevel(m.species, m.level);
    d[14] = (exp >> 16) & 0xFF;
    d[15] = (exp >> 8) & 0xFF;
    d[16] = exp & 0xFF;
    d.setU16be(27, m.shiny ? 0xAAAA : 0x8888);
    if (party) d[33] = m.level;
    return d;
  }

  static Uint8List _pk2(SynthMon m, int tid, {required bool party}) {
    final d = Uint8List(party ? 48 : 32);
    d[0] = m.species;
    d[1] = m.item;
    d.setU16be(6, tid);
    final exp = Species.expForLevel(m.species, m.level);
    d[8] = (exp >> 16) & 0xFF;
    d[9] = (exp >> 8) & 0xFF;
    d[10] = exp & 0xFF;
    d.setU16be(21, m.shiny ? 0xAAAA : 0x8888);
    d[31] = m.level;
    return d;
  }

  static Uint8List _pk3(SynthMon m, int tid, int sid, int salt, {required bool party}) {
    final d = Uint8List(PkCrypto.size3Party);
    final pid = _pidFor(m, tid, sid, salt);
    d.setU32le(0, pid);
    d.setU16le(4, tid);
    d.setU16le(6, sid);
    final nick = m.nickname ?? Species.name(m.species, SpeciesLanguage.en).toUpperCase();
    d.setRange(8, 18, StringCodec.encodeG3(nick, 10));
    d[0x12] = 2; // inglés
    d[0x13] = m.egg ? 0x06 : 0x02;
    d.setRange(0x14, 0x1B, StringCodec.encodeG3('SYN', 7));
    d.setU16le(0x20, SpeciesConvert.gen3FromNational(m.species));
    d.setU16le(0x22, m.item);
    d.setU32le(0x24, Species.expForLevel(m.species, m.level));
    d.setU32le(0x48, (m.egg ? 1 << 30 : 0) | 0x1F);
    d.setU16le(0x46, (4 << 11) | (3 << 7) | 5); // Poké Ball, Esmeralda, nivel 5
    d.setU16le(0x2C, 33); // Placaje
    d[0x34] = 35;
    d[0x29] = 70;
    d.setU16le(0x1C, PkCrypto.checksum3(d));
    final enc = PkCrypto.encrypt3(d.copyRange(0, PkCrypto.size3Stored));
    if (!party) return enc;
    final out = Uint8List(PkCrypto.size3Party)..setRange(0, 80, enc);
    out[0x54] = m.level;
    return out;
  }

  static Uint8List _pk45(SynthMon m, int tid, int sid, int salt, {required int gen, required bool party}) {
    final d = Uint8List(party ? (gen == 4 ? PkCrypto.size4Party : PkCrypto.size5Party) : PkCrypto.size4Stored);
    final pid = _pidFor(m, tid, sid, salt);
    d.setU32le(0, pid);
    d.setU16le(8, m.species);
    d.setU16le(0x0A, m.item);
    d.setU16le(0x0C, tid);
    d.setU16le(0x0E, sid);
    d.setU32le(0x10, Species.expForLevel(m.species, m.level));
    d.setU32le(0x38, (m.nickname != null ? 1 << 31 : 0) | (m.egg ? 1 << 30 : 0));
    d[0x40] = ((_genderFor(m.species, pid) & 3) << 1) | ((m.form & 0x1F) << 3);
    d[0x83] = 4;
    d[0x5F] = gen == 4 ? 12 : 21; // Platino / Negro
    d[0x84] = m.level.clamp(1, 100);
    d.setU16le(0x28, 33);
    d[0x30] = 35;
    d[0x14] = 70;
    if (gen == 5) d[0x41] = pid % 25;
    final nick = m.nickname ?? Species.name(m.species, SpeciesLanguage.en).toUpperCase();
    final enc = gen == 4 ? StringCodec.encodeG4(nick, 22) : _utf16Ffff(nick, 22);
    d.setRange(0x48, 0x48 + 22, enc);
    if (party) d[0x8C] = m.level;
    d.setU16le(6, PkCrypto.checksumFrom8(d, PkCrypto.size4Stored));
    return PkCrypto.encrypt45(d);
  }

  static Uint8List _utf16Ffff(String s, int len) {
    final out = StringCodec.encodeUtf16(s, len);
    final term = s.length * 2;
    if (term + 1 < len) {
      out[term] = 0xFF;
      out[term + 1] = 0xFF;
    }
    return out;
  }

  static Uint8List _pk67(SynthMon m, int tid, int sid, int salt, {required bool party}) {
    final d = Uint8List(party ? PkCrypto.size6Party : PkCrypto.size6Stored);
    d.setU32le(0, 0xC0FFEE00 + salt * 0x1357);
    d.setU16le(8, m.species);
    d.setU16le(0x0A, m.item);
    d.setU16le(0x0C, tid);
    d.setU16le(0x0E, sid);
    d.setU32le(0x10, Species.expForLevel(m.species, m.level));
    d.setU32le(0x18, _pidFor(m, tid, sid, salt));
    d.setRange(0x40, 0x40 + 24, StringCodec.encodeUtf16(m.nickname ?? Species.name(m.species, SpeciesLanguage.en), 24));
    d.setU32le(0x74, (m.nickname != null ? 1 << 31 : 0) | (m.egg ? 1 << 30 : 0));
    d[0x1D] = ((_genderFor(m.species, salt * 37) & 3) << 1) | ((m.form & 0x1F) << 3);
    d[0xDC] = 4;
    d[0xDF] = 26; // Zafiro Alfa
    d[0xDD] = m.level.clamp(1, 100);
    d.setU16le(0x5A, 33);
    d[0x62] = 35;
    d[0xCA] = 70;
    final abil = GameDataTable.forGame(GameVersion.ultraSunUltraMoon).entry(m.species)?.abilities ?? const <int>[];
    if (abil.isNotEmpty) {
      d[0x14] = abil.first;
      d[0x15] = 1;
    }
    if (party) d[0xEC] = m.level;
    d.setU16le(6, PkCrypto.checksumFrom8(d, PkCrypto.size6Stored));
    return PkCrypto.encrypt67(d);
  }

  static Uint8List _pk89(SynthMon m, int tid, int sid, int salt, {required bool gen9}) {
    final d = Uint8List(PkCrypto.size8Party);
    d.setU32le(0, 0xBADC0DE0 + salt * 0x2468);
    d.setU16le(8, gen9 ? SpeciesConvert.gen9FromNational(m.species) : m.species);
    d.setU16le(0x0A, m.item);
    d.setU16le(0x0C, tid);
    d.setU16le(0x0E, sid);
    d.setU32le(0x10, Species.expForLevel(m.species, m.level));
    d.setU32le(0x1C, _pidFor(m, tid, sid, salt));
    d.setRange(0x58, 0x58 + 26, StringCodec.encodeUtf16(m.nickname ?? Species.name(m.species, SpeciesLanguage.en), 26));
    d.setU32le(0x8C, (m.nickname != null ? 1 << 31 : 0) | (m.egg ? 1 << 30 : 0));
    d[0x22] = (_genderFor(m.species, salt * 37) & 3) << (gen9 ? 1 : 2);
    d[0x124] = 4;
    final (metLoc, metLv) = plausibleMet(gen9 ? 50 : 44, m);
    d.setU16le(0x122, metLoc);
    d[0x125] = metLv;
    d[gen9 ? 0xCE : 0xDE] = gen9 ? 50 : 44; // Escarlata / Espada
    d[gen9 ? 0xD4 : 0xE8] = 0xFF; // sin cinta mostrada (PKHeX AffixedRibbon.None)
    // Fecha de encuentro verosímil (aa, mm, dd).
    d[0x11C] = gen9 ? 23 : 20;
    d[0x11D] = 1 + salt % 12;
    d[0x11E] = 1 + salt % 28;
    if (gen9) d[0x11F] = metLv; // ObedienceLevel, como el juego
    d.setU16le(0x72, 33);
    d[0x7A] = 35;
    d[0x112] = 70;
    final abil = GameDataTable.forGame(gen9 ? GameVersion.scarletViolet : GameVersion.swordShield).entry(m.species)?.abilities ??
        const <int>[];
    if (abil.isNotEmpty) {
      d.setU16le(0x14, abil.first);
      d[0x16] = 1;
    }
    if (m.gigantamax && !gen9) d[0x16] |= 0x10;
    d[0x24] = m.form;
    d[0x148] = m.level;
    d.setU16le(6, PkCrypto.checksumFrom8(d, PkCrypto.size8Stored));
    return PkCrypto.encrypt8(d);
  }

  // ------------------------------------------------------------ Gen 1 / 2

  static void _writeGbList(Uint8List d, int ofs, int capacity, int strLen, List<SynthMon> mons,
      Uint8List Function(SynthMon) build, int Function(SynthMon) speciesByte, String ot,
      {bool korean = false, bool japanese = false}) {
    final count = mons.length.clamp(0, capacity);
    d[ofs] = count;
    for (var i = 0; i < count; i++) {
      d[ofs + 1 + i] = speciesByte(mons[i]);
    }
    d[ofs + 1 + count] = 0xFF;
    final dataStart = ofs + 1 + capacity + 1;
    final size = build(mons.isEmpty ? const SynthMon(1) : mons.first).length;
    final otStart = dataStart + capacity * size;
    final nickStart = otStart + capacity * strLen;
    for (var i = 0; i < count; i++) {
      d.setRange(dataStart + i * size, dataStart + (i + 1) * size, build(mons[i]));
      d.setRange(otStart + i * strLen, otStart + (i + 1) * strLen, StringCodec.encodeGb(ot, strLen, korean: korean, japanese: japanese));
      final nick = mons[i].nickname ??
          (japanese ? Species.name(mons[i].species, SpeciesLanguage.ja) : Species.name(mons[i].species, SpeciesLanguage.en).toUpperCase());
      d.setRange(nickStart + i * strLen, nickStart + (i + 1) * strLen,
          StringCodec.encodeGb(nick, strLen, korean: korean, japanese: japanese));
    }
  }

  /// Rojo/Azul/Amarillo internacional (32 KB).
  static Uint8List gen1({
    SynthTrainer trainer = const SynthTrainer(name: 'RED'),
    List<SynthMon> party = const [],
    Map<int, List<SynthMon>> boxes = const {},
    bool yellow = false,
  }) {
    final d = Uint8List(0x8000);
    d.setRange(0x2598, 0x2598 + 11, StringCodec.encodeGb(trainer.name, 11));
    d.setU16be(0x2605, trainer.tid);
    d[0x2CED] = trainer.hours.clamp(0, 255);
    d[0x2CEF] = trainer.minutes;
    d[0x2CF0] = trainer.seconds;
    if (yellow) d[0x29C3] = 0x54;
    _writeGbList(d, 0x2F2C, 6, 11, party, (m) => _pk1(m, trainer.tid, party: true),
        (m) => SpeciesConvert.gen1FromNational(m.species), trainer.name);
    d[0x284C] = 0; // caja actual = 1
    const boxSize = 0x462;
    for (var b = 0; b < 12; b++) {
      final ofs = b == 0 ? 0x30C0 : (b < 6 ? 0x4000 + b * boxSize : 0x6000 + (b - 6) * boxSize);
      _writeGbList(d, ofs, 20, 11, boxes[b] ?? const [], (m) => _pk1(m, trainer.tid, party: false),
          (m) => SpeciesConvert.gen1FromNational(m.species), trainer.name);
    }
    const Gen1ChecksumFixer().fix(d);
    return d;
  }

  /// Oro/Plata o Cristal internacional (32 KB).
  /// Rojo/Verde/Azul/Amarillo japonés (32 KB; 8 cajas de 30, cadenas de 6 bytes).
  static Uint8List gen1Jp({
    SynthTrainer trainer = const SynthTrainer(name: 'サトシ'),
    List<SynthMon> party = const [],
    Map<int, List<SynthMon>> boxes = const {},
  }) {
    const l = Gen1Layout.japanese;
    final d = Uint8List(0x8000);
    d.setRange(Gen1Layout.ot, Gen1Layout.ot + 6, StringCodec.encodeGb(trainer.name, 6, japanese: true));
    d.setU16be(l.tid, trainer.tid);
    d[l.playTime] = trainer.hours.clamp(0, 255);
    d[l.playTime + 2] = trainer.minutes;
    d[l.playTime + 3] = trainer.seconds;
    int sp(SynthMon m) => SpeciesConvert.gen1FromNational(m.species);
    _writeGbList(d, l.party, 6, 6, party, (m) => _pk1(m, trainer.tid, party: true), sp, trainer.name, japanese: true);
    d[l.currentBoxIndex] = 0;
    for (var b = 0; b < 8; b++) {
      final ofs = b == 0 ? l.currentBox : (b < 4 ? 0x4000 + b * l.boxSize : 0x6000 + (b - 4) * l.boxSize);
      _writeGbList(d, ofs, 30, 6, boxes[b] ?? const [], (m) => _pk1(m, trainer.tid, party: false), sp, trainer.name,
          japanese: true);
    }
    d[l.checksum] = Checksums.gen1(d, Gen1Layout.ot, l.checksum);
    return d;
  }

  /// Oro/Plata o Cristal japonés (9 cajas de 30, cadenas de 6 bytes).
  static Uint8List gen2Jp({
    bool crystal = false,
    SynthTrainer trainer = const SynthTrainer(name: 'ヒビキ'),
    List<SynthMon> party = const [],
    Map<int, List<SynthMon>> boxes = const {},
  }) {
    final l = crystal ? Gen2Layout.crystalJp : Gen2Layout.goldSilverJp;
    final d = Uint8List(crystal ? 0x10000 : 0x8000);
    d.setU16be(Gen2Layout.trainer, trainer.tid);
    d.setRange(Gen2Layout.trainer + 2, Gen2Layout.trainer + 8, StringCodec.encodeGb(trainer.name, 6, japanese: true));
    d.setU16be(l.timePlayed, trainer.hours);
    d[l.timePlayed + 2] = trainer.minutes;
    d[l.timePlayed + 3] = trainer.seconds;
    if (crystal) d[l.gender] = trainer.gender;
    int sp(SynthMon m) => m.egg ? 0xFD : m.species;
    _writeGbList(d, l.party, 6, 6, party, (m) => _pk2(m, trainer.tid, party: true), sp, trainer.name, japanese: true);
    d[l.currentBoxIndex] = 0;
    for (var b = 0; b < 9; b++) {
      final ofs = b == 0 ? l.currentBox : (b < 6 ? 0x4000 + b * 0x54A : 0x6000 + (b - 6) * 0x54A);
      _writeGbList(d, ofs, 30, 6, boxes[b] ?? const [], (m) => _pk2(m, trainer.tid, party: false), sp, trainer.name,
          japanese: true);
    }
    Gen2Finalizer.finalize(d, l);
    return d;
  }

  static Uint8List gen2({
    bool crystal = false,
    bool korean = false,
    SynthTrainer trainer = const SynthTrainer(name: 'GOLD'),
    List<SynthMon> party = const [],
    Map<int, List<SynthMon>> boxes = const {},
  }) {
    final d = Uint8List(0x8000);
    final timePlayed = korean ? 0x204D : (crystal ? 0x2052 : 0x2053);
    final curIdx = korean ? 0x26FC : (crystal ? 0x2700 : 0x2724);
    final names = korean ? 0x26FF : (crystal ? 0x2703 : 0x2727);
    final partyOfs = korean ? 0x28CC : (crystal ? 0x2865 : 0x288A);
    final curBox = korean ? 0x2DAE : (crystal ? 0x2D10 : 0x2D6C);
    final nameLen = korean ? 17 : 9;
    d.setU16be(0x2009, trainer.tid);
    d.setRange(0x200B, 0x200B + 11, StringCodec.encodeGb(trainer.name, 11, korean: korean));
    d.setU16be(timePlayed, trainer.hours);
    d[timePlayed + 2] = trainer.minutes;
    d[timePlayed + 3] = trainer.seconds;
    if (crystal) d[0x3E3D] = trainer.gender;
    int sp(SynthMon m) => m.egg ? 0xFD : m.species;
    _writeGbList(d, partyOfs, 6, 11, party, (m) => _pk2(m, trainer.tid, party: true), sp, trainer.name, korean: korean);
    d[curIdx] = 0;
    for (var b = 0; b < 14; b++) {
      final ofs = b == 0 ? curBox : (b < 7 ? 0x4000 + b * 0x450 : 0x6000 + (b - 7) * 0x450);
      _writeGbList(d, ofs, 20, 11, boxes[b] ?? const [], (m) => _pk2(m, trainer.tid, party: false), sp, trainer.name,
          korean: korean);
      d.setRange(names + b * nameLen, names + (b + 1) * nameLen,
          StringCodec.encodeGb(korean ? '상자${b + 1}' : 'BOX${b + 1}', nameLen, korean: korean));
    }
    Gen2Finalizer.finalize(
        d, korean ? Gen2Layout.goldSilverKor : (crystal ? Gen2Layout.crystalIntl : Gen2Layout.goldSilverIntl));
    return d;
  }

  // ------------------------------------------------------------ Gen 3

  /// Save de GBA de 128 KB con dos ranuras; la activa es la de mayor contador.
  static Uint8List gen3({
    GameVersion game = GameVersion.emerald,
    SynthTrainer trainer = const SynthTrainer(name: 'MAY'),
    List<SynthMon> party = const [],
    Map<int, List<SynthMon?>> boxes = const {},
    List<String> boxNames = const [],
    int sectorRotation = 3,
  }) {
    const used = 0xF80;
    final small = Uint8List(used);
    small.setRange(0, 8, StringCodec.encodeG3(trainer.name, 8));
    small[0x08] = trainer.gender;
    small.setU16le(0x0A, trainer.tid);
    small.setU16le(0x0C, trainer.sid);
    small.setU16le(0x0E, trainer.hours);
    small[0x10] = trainer.minutes;
    small[0x11] = trainer.seconds;
    switch (game) {
      case GameVersion.fireRedLeafGreen:
        small.setU32le(0xAC, 1);
      case GameVersion.emerald:
        small.setU32le(0xAC, 0x5EC0DE01);
        small[0x900] = 0x01;
      default:
        small.setU32le(0xAC, 0);
    }

    final large = Uint8List(4 * used);
    final key = switch (game) {
      GameVersion.emerald => small.u32le(0xAC),
      GameVersion.fireRedLeafGreen => small.u32le(0xF20),
      _ => 0,
    };
    large.setU32le(game == GameVersion.fireRedLeafGreen ? 0x290 : 0x490, 3000 ^ key);
    final countOfs = game == GameVersion.fireRedLeafGreen ? 0x34 : 0x234;
    large[countOfs] = party.length.clamp(0, 6);
    for (var i = 0; i < party.length && i < 6; i++) {
      large.setRange(countOfs + 4 + i * 100, countOfs + 4 + (i + 1) * 100,
          _pk3(party[i], trainer.tid, trainer.sid, i, party: true));
    }

    final storage = Uint8List(9 * used);
    storage.setU32le(0, 0);
    boxes.forEach((b, mons) {
      for (var s = 0; s < mons.length && s < 30; s++) {
        final m = mons[s];
        if (m == null) continue;
        final ofs = 4 + (b * 30 + s) * 80;
        storage.setRange(ofs, ofs + 80, _pk3(m, trainer.tid, trainer.sid, 100 + b * 30 + s, party: false));
      }
    });
    const namesOfs = 4 + 14 * 30 * 80;
    for (var b = 0; b < 14; b++) {
      final name = b < boxNames.length ? boxNames[b] : 'BOX ${b + 1}';
      storage.setRange(namesOfs + b * 9, namesOfs + b * 9 + 9, StringCodec.encodeG3(name, 9));
    }

    Uint8List sectorData(int id) {
      if (id == 0) return small;
      if (id <= 4) return large.view((id - 1) * used, used);
      return storage.view((id - 5) * used, used);
    }

    final d = Uint8List(0x20000);
    void writeSlot(int slot, int counter, int rotation) {
      for (var id = 0; id < 14; id++) {
        final pos = (id + rotation) % 14;
        final ofs = slot * 0xE000 + pos * 0x1000;
        d.setRange(ofs, ofs + used, sectorData(id));
        d.setU16le(ofs + 0xFF4, id);
        d.setU32le(ofs + 0xFF8, 0x08012025);
        d.setU32le(ofs + 0xFFC, counter);
      }
    }

    // Ranura 0 = guardado antiguo (contador menor); ranura 1 = activa.
    writeSlot(0, 41, 0);
    writeSlot(1, 42, sectorRotation);
    const Gen3ChecksumFixer().fix(d);
    return d;
  }

  // ------------------------------------------------------------ Gen 4 / 5

  static Uint8List gen4({
    Gen4Layout layout = Gen4Layout.pt,
    SynthTrainer trainer = const SynthTrainer(name: 'Lucas'),
    List<SynthMon> party = const [],
    Map<int, List<SynthMon?>> boxes = const {},
  }) {
    final d = Uint8List(0x80000)..fillRange(0, 0x40000, 0xFF);
    const base = Gen4Layout.partitionSize;
    final g = d.view(base, layout.generalSize)..fillRange(0, layout.generalSize, 0);
    final t = layout.trainer1;
    g.setRange(t, t + 16, StringCodec.encodeG4(trainer.name, 16));
    g.setU16le(t + 0x10, trainer.tid);
    g.setU16le(t + 0x12, trainer.sid);
    g[t + 0x18] = trainer.gender;
    g.setU16le(t + 0x22, trainer.hours);
    g[t + 0x24] = trainer.minutes;
    g[t + 0x25] = trainer.seconds;
    g[layout.party - 4] = party.length;
    for (var i = 0; i < party.length; i++) {
      final o = layout.party + i * PkCrypto.size4Party;
      g.setRange(o, o + PkCrypto.size4Party, _pk45(party[i], trainer.tid, trainer.sid, i, gen: 4, party: true));
    }
    final s = d.view(base + layout.storageStart, layout.storageSize)..fillRange(0, layout.storageSize, 0);
    // Huecos vacíos como los deja el juego: estructura a cero cifrada (no ceros literales).
    final blank = Pkm.blankEncrypted(PkFormat.pk4);
    for (var b = 0; b < 18; b++) {
      for (var i = 0; i < 30; i++) {
        final o = layout.boxStart + b * layout.boxStride + i * PkCrypto.size4Stored;
        s.setRange(o, o + PkCrypto.size4Stored, blank);
      }
    }
    boxes.forEach((b, mons) {
      for (var i = 0; i < mons.length; i++) {
        final m = mons[i];
        if (m == null) continue;
        final o = layout.boxStart + b * layout.boxStride + i * PkCrypto.size4Stored;
        s.setRange(o, o + PkCrypto.size4Stored, _pk45(m, trainer.tid, trainer.sid, 50 + i, gen: 4, party: false));
      }
    });
    void footer(Uint8List blk) {
      final n = blk.length;
      blk.setU32le(n - 0x14, 7); // contador mayor
      blk.setU32le(n - 0x10, 1); // contador menor
      blk.setU32le(n - 0xC, n);
      blk.setU32le(n - 0x8, Gen4Layout.magicIntl);
      blk.setU16le(n - 2, Checksums.crc16Ccitt(blk, 0, n - layout.footerSize));
    }

    footer(g);
    footer(s);
    return d;
  }

  static Uint8List gen5({
    Gen5Layout layout = Gen5Layout.bw,
    SynthTrainer trainer = const SynthTrainer(name: 'Hilda', versionId: 21),
    List<SynthMon> party = const [],
    Map<int, List<SynthMon?>> boxes = const {},
  }) {
    final d = Uint8List(0x80000);
    const p = 0x19400;
    d.setRange(p + 4, p + 0x14, _utf16Ffff(trainer.name, 0x10));
    d.setU16le(p + 0x14, trainer.tid);
    d.setU16le(p + 0x16, trainer.sid);
    d[p + 0x1E] = 2;
    d[p + 0x1F] = trainer.versionId ?? 21;
    d[p + 0x21] = trainer.gender;
    d.setU16le(p + 0x24, trainer.hours);
    d[p + 0x26] = trainer.minutes;
    d[p + 0x27] = trainer.seconds;
    d[0x18E00 + 4] = party.length;
    for (var i = 0; i < party.length; i++) {
      final o = 0x18E00 + 8 + i * PkCrypto.size5Party;
      d.setRange(o, o + PkCrypto.size5Party, _pk45(party[i], trainer.tid, trainer.sid, i, gen: 5, party: true));
    }
    final blank5 = Pkm.blankEncrypted(PkFormat.pk5);
    for (var b = 0; b < 24; b++) {
      for (var i = 0; i < 30; i++) {
        final o = 0x400 + b * 0x1000 + i * PkCrypto.size4Stored;
        d.setRange(o, o + PkCrypto.size4Stored, blank5);
      }
    }
    boxes.forEach((b, mons) {
      for (var i = 0; i < mons.length; i++) {
        final m = mons[i];
        if (m == null) continue;
        final o = 0x400 + b * 0x1000 + i * PkCrypto.size4Stored;
        d.setRange(o, o + PkCrypto.size4Stored, _pk45(m, trainer.tid, trainer.sid, 60 + i, gen: 5, party: false));
      }
    });
    final f = layout.footerOffset;
    for (var i = 0; i < layout.infoLength; i++) {
      d[f + i] = (i * 7) & 0xFF;
    }
    d.setU16le(f + layout.infoLength + 0x10 - 2, Checksums.crc16Ccitt(d, f, f + layout.infoLength));
    return d;
  }

  // ------------------------------------------------------------ 3DS

  static Uint8List ctr({
    CtrLayout layout = CtrLayout.oras,
    SynthTrainer trainer = const SynthTrainer(name: 'Serena', versionId: 26),
    List<SynthMon> party = const [],
    Map<int, List<SynthMon?>> boxes = const {},
  }) {
    final d = Uint8List(layout.size);
    final s = layout.myStatus;
    d.setU16le(s, trainer.tid);
    d.setU16le(s + 2, trainer.sid);
    d[s + 4] = trainer.versionId ?? 0;
    d[s + 5] = trainer.gender;
    d.setRange(s + layout.otOffset, s + layout.otOffset + 0x1A, StringCodec.encodeUtf16(trainer.name, 0x1A));
    d.setU16le(layout.playTime, trainer.hours);
    d[layout.playTime + 2] = trainer.minutes;
    d[layout.playTime + 3] = trainer.seconds;
    for (var i = 0; i < party.length; i++) {
      final o = layout.party + i * PkCrypto.size6Party;
      d.setRange(o, o + PkCrypto.size6Party, _pk67(party[i], trainer.tid, trainer.sid, i, party: true));
    }
    d[layout.party + 6 * PkCrypto.size6Party] = party.length;
    boxes.forEach((b, mons) {
      for (var i = 0; i < mons.length; i++) {
        final m = mons[i];
        if (m == null) continue;
        final o = layout.box + (b * 30 + i) * PkCrypto.size6Stored;
        d.setRange(o, o + PkCrypto.size6Stored, _pk67(m, trainer.tid, trainer.sid, 70 + i, party: false));
      }
    });
    d.setU32le(d.length - 0x1F0, 0x42454546);
    _writeBeefTable(d, switch (layout.game) {
      GameVersion.xy => CtrBlocks.xy,
      GameVersion.omegaRubyAlphaSapphire => CtrBlocks.oras,
      GameVersion.sunMoon => CtrBlocks.sm,
      _ => CtrBlocks.usum,
    }, d.length - 0x200, layout.game.generation == 7 ? 1 : 0);
    // SM/USUM: como el juego, la firma MemeCrypto se escribe después de los
    // checksums (el CRC del bloque 36 se calcula con la firma a cero).
    MemeCrypto.signSave(d, layout.game);
    return d;
  }

  /// Escribe la tabla de bloques BEEF con longitudes, ids y checksums.
  /// [crcKind]: 0 = CRC16-CCITT (Gen 6), 1 = CRC16 invertido (Gen 7), 2 = sin invertir (Let's Go).
  static void _writeBeefTable(Uint8List d, List<(int, int)> blocks, int bo, int crcKind) {
    for (var i = 0; i < blocks.length; i++) {
      final (ofs, len) = blocks[i];
      final e = bo + 0x14 + i * 8;
      d.setU32le(e, len);
      d.setU16le(e + 4, i);
      final crc = switch (crcKind) {
        0 => Checksums.crc16Ccitt(d, ofs, ofs + len),
        1 => (~Checksums.crc16Arc(d, ofs, ofs + len, 0xFFFF)) & 0xFFFF,
        _ => Checksums.crc16Arc(d, ofs, ofs + len, 0),
      };
      d.setU16le(e + 6, crc);
    }
  }

  /// Lugar y nivel de encuentro verosímiles para [m] en la versión [version]
  /// según las tablas de encuentros (la especie o una preevolución, a un nivel
  /// no mayor que el actual). Sin candidatos: (0, nivel).
  static (int, int) plausibleMet(int version, SynthMon m) {
    final level = m.level.clamp(1, 100);
    final chain = EncounterTables.evolutionChain(m.species);
    EncounterSlot? best;
    for (final e in EncounterTables.forVersion(version)) {
      if (!chain.contains(e.species) || e.minLevel > level) continue;
      // Preferir un lugar con nombre (ni intercambio ni «cualquier guarida»)
      // y la propia especie antes que una preevolución.
      int score(EncounterSlot x) =>
          (x.location == EncounterSlot.anyLocation || x.location == EncounterSlot.anyDen ? 2 : 0) +
          (x.species == m.species ? 0 : 1);
      if (best == null || score(e) < score(best)) best = e;
    }
    if (best == null) return (0, level);
    final loc = best.location == EncounterSlot.anyDen ? 162 : best.location;
    return (loc, level < best.maxLevel ? level : best.maxLevel);
  }

  /// Construye un Pokémon de los formatos nuevos (PB7, PB8, PA8, PA9) con la API de [Pkm].
  static Pkm synthPkm(PkFormat f, SynthMon m, SynthTrainer t, int salt, GameVersion game) {
    final pk = Pkm.fromDecrypted(f, Uint8List(f.partySize))..dataGame = game;
    pk.encryptionConstant = 0x5EED0000 + salt * 0x3141;
    pk.species = m.species;
    pk.form = m.form;
    pk.tid = t.tid;
    pk.sid = t.sid;
    pk.pid = _pidFor(m, t.tid, t.sid, salt, threshold: 16);
    pk.language = 7;
    pk.exp = Species.expForLevel(m.species, m.level);
    pk.heldItem = m.item;
    pk.otName = t.name;
    pk.nature = salt % 25;
    pk.statNature = salt % 25;
    pk.setAbilitySlot(0);
    pk.setMove(0, 33, context: '9');
    pk.friendship = 70;
    pk.ball = game == GameVersion.legendsArceus ? 28 : 4;
    pk.version = switch (game) {
      GameVersion.letsGo => 42,
      GameVersion.swordShield => 44,
      GameVersion.legendsArceus => 47,
      GameVersion.brilliantDiamondShiningPearl => 48,
      GameVersion.legendsZA => 52,
      _ => 50,
    };
    final (metLoc, metLv) = plausibleMet(pk.version, m);
    pk.metLocation = metLoc;
    pk.metLevel = metLv;
    pk.metDate = DateTime(2019 + salt % 6, 1 + salt % 12, 1 + salt % 28);
    if (f == PkFormat.pk9 || f == PkFormat.pa9) pk.data[0x11F] = metLv; // ObedienceLevel, como el juego
    Ribbons.setAffixed(pk, null);
    if (m.egg) pk.isEgg = true;
    if (m.nickname != null) {
      pk.setNickname(m.nickname);
    } else {
      pk.setDefaultNickname();
    }
    pk.refreshPartyStats();
    pk.refreshChecksum();
    return pk;
  }

  // ------------------------------------------------------------ Switch

  static Uint8List _boxLayout(List<String> names) {
    final out = Uint8List(32 * 0x22 + 0x40);
    for (var b = 0; b < 32; b++) {
      final n = b < names.length ? names[b] : 'Caja ${b + 1}';
      out.setRange(b * 0x22, b * 0x22 + 0x22, StringCodec.encodeUtf16(n, 0x22));
    }
    return out;
  }

  static (Uint8List party, Uint8List box) _pk8Storage(
      SynthTrainer t, List<SynthMon> party, Map<int, List<SynthMon?>> boxes, {required bool gen9, int boxCount = 32}) {
    const size = PkCrypto.size8Party;
    final p = Uint8List(6 * size + 8);
    for (var i = 0; i < party.length && i < 6; i++) {
      p.setRange(i * size, (i + 1) * size, _pk89(party[i], t.tid, t.sid, i, gen9: gen9));
    }
    p[6 * size] = party.length.clamp(0, 6);
    final box = Uint8List(boxCount * 30 * size);
    boxes.forEach((b, mons) {
      for (var i = 0; i < mons.length && i < 30; i++) {
        final m = mons[i];
        if (m == null) continue;
        final o = (b * 30 + i) * size;
        box.setRange(o, o + size, _pk89(m, t.tid, t.sid, 200 + b * 30 + i, gen9: gen9));
      }
    });
    return (p, box);
  }

  static List<SCBlock> _filler() => [
        SCBlock.boolean(0x0000A001, true),
        SCBlock.boolean(0x0000A002, false),
        SCBlock.value(0x0000A003, SCTypeCode.uint32, 0xDEADBEEF),
        SCBlock.value(0x0000A004, SCTypeCode.byte, 7),
        SCBlock.array(0x0000A005, SCTypeCode.uint16, Uint8List.fromList(List.generate(16, (i) => i))),
      ];

  /// Espada/Escudo (`main` cifrado con SwishCrypto).
  static Uint8List swordShield({
    SynthTrainer trainer = const SynthTrainer(name: 'Gloria', versionId: 44),
    List<SynthMon> party = const [],
    Map<int, List<SynthMon?>> boxes = const {},
    List<String> boxNames = const [],
  }) {
    final status = Uint8List(0x110);
    status.setU16le(0xA0, trainer.tid);
    status.setU16le(0xA2, trainer.sid);
    status[0xA4] = trainer.versionId ?? 44;
    status[0xA5] = trainer.gender;
    status[0xA7] = 7; // español
    status.setRange(0xB0, 0xB0 + 0x1A, StringCodec.encodeUtf16(trainer.name, 0x1A));
    final play = Uint8List(0x10)
      ..setU16le(0, trainer.hours)
      ..[2] = trainer.minutes
      ..[3] = trainer.seconds;
    final (p, b) = _pk8Storage(trainer, party, boxes, gen9: false);
    return SwishCrypto.encrypt([
      ..._filler(),
      SCBlock.object(SCKeys.swshMyStatus, status),
      SCBlock.object(SCKeys.swshPlayTime, play),
      SCBlock.object(SCKeys.swshParty, p),
      SCBlock.object(SCKeys.swshBox, b),
      SCBlock.object(SCKeys.boxLayout, _boxLayout(boxNames)),
      SCBlock.object(0x1B882B09, Uint8List(0x10)..setU32le(4, 25000)),
      SCBlock.object(0x1177C2C4, Uint8List(0x2CF8)..setU32le(0, 17 | (5 << 15))),
      SCBlock.object(0x4716C404, Uint8List(400 * 0x30)), // Pokédex de Galar
      SCBlock.object(0x3F936BA9, Uint8List(211 * 0x30)), // Isla de la Armadura
      SCBlock.object(0x3C9366F0, Uint8List(210 * 0x30)), // Corona Nieve
    ]);
  }

  /// Escarlata/Púrpura (`main` cifrado con SwishCrypto, especies internas Gen 9).
  static Uint8List scarletViolet({
    SynthTrainer trainer = const SynthTrainer(name: 'Juliana', versionId: 50),
    List<SynthMon> party = const [],
    Map<int, List<SynthMon?>> boxes = const {},
    List<String> boxNames = const [],
  }) {
    final status = Uint8List(0x80);
    status.setU16le(0, trainer.tid);
    status.setU16le(2, trainer.sid);
    status[4] = trainer.versionId ?? 50;
    status[5] = trainer.gender;
    status[7] = 7;
    status.setRange(0x10, 0x10 + 0x1A, StringCodec.encodeUtf16(trainer.name, 0x1A));
    final play = Uint8List(0x10)
      ..setU32le(0, trainer.hours)
      ..setU32le(4, trainer.minutes)
      ..setU32le(8, trainer.seconds);
    final (p, b) = _pk8Storage(trainer, party, boxes, gen9: true);
    return SwishCrypto.encrypt([
      SCBlock.object(SCKeys.svMyStatus, status),
      ..._filler(),
      SCBlock.object(SCKeys.svPlayTime, play),
      SCBlock.object(SCKeys.svParty, p),
      SCBlock.object(SCKeys.svBox, b),
      SCBlock.object(SCKeys.boxLayout, _boxLayout(boxNames)),
      SCBlock.value(0x4F35D0DD, SCTypeCode.uint32, 77777),
      SCBlock.object(0x21C9BD44, Uint8List(0x10 * 2600)
        ..setU32le(17 * 0x10, 0)
        ..setU32le(17 * 0x10 + 4, 3)
        ..setU32le(17 * 0x10 + 8, 4)),
      SCBlock.object(0x0DEAAEBD, Uint8List(0x18 * 1100)), // Pokédex de Paldea (antigua)
      SCBlock.object(0xF5D7C0E2, Uint8List(0x20 * 1100)), // Pokédex unificada (2.0.1+)
    ]);
  }

  static Uint8List legendsArceus({
    SynthTrainer trainer = const SynthTrainer(name: 'Akari'),
    List<SynthMon> party = const [],
    Map<int, List<SynthMon?>> boxes = const {},
    List<String> boxNames = const [],
  }) {
    const f = PkFormat.pa8;
    final p = Uint8List(6 * 0x178 + 8);
    for (var i = 0; i < party.length && i < 6; i++) {
      p.setRange(i * 0x178, (i + 1) * 0x178, synthPkm(f, party[i], trainer, i, GameVersion.legendsArceus).encryptParty());
    }
    p[6 * 0x178] = party.length.clamp(0, 6);
    final box = Uint8List(32 * 30 * 0x168);
    boxes.forEach((b, mons) {
      for (var i = 0; i < mons.length && i < 30; i++) {
        final m = mons[i];
        if (m == null) continue;
        final o = (b * 30 + i) * 0x168;
        box.setRange(o, o + 0x168, synthPkm(f, m, trainer, 300 + b * 30 + i, GameVersion.legendsArceus).encryptStored());
      }
    });
    final status = Uint8List(0x80);
    status.setU16le(0x10, trainer.tid);
    status.setU16le(0x12, trainer.sid);
    status[0x14] = 47;
    status[0x15] = trainer.gender;
    status[0x17] = 7;
    status.setRange(0x20, 0x20 + 0x1A, StringCodec.encodeUtf16(trainer.name, 0x1A));
    final play = Uint8List(4)
      ..setU16le(0, trainer.hours)
      ..[2] = trainer.minutes
      ..[3] = trainer.seconds;
    return SwishCrypto.encrypt([
      SCBlock.object(SCKeys.laMyStatus, status),
      SCBlock.object(SCKeys.laPlayTime, play),
      SCBlock.object(SCKeys.laParty, p),
      SCBlock.object(SCKeys.laBox, box),
      SCBlock.object(SCKeys.boxLayout, _boxLayout(boxNames)),
      SCBlock.value(0x3279D927, SCTypeCode.uint32, 12345),
      SCBlock.value(0x75CE2CF6, SCTypeCode.uint32, 10), // mejoras de la bolsa
      SCBlock.object(0x9FE2790A, Uint8List(675 * 4)..setU16le(0, 17)..setU16le(2, 4)), // Poción ×4
      SCBlock.object(0x59A4D0C3, Uint8List(100 * 4)),
      SCBlock.object(0x8E434F0D, Uint8List(180 * 4)..setU16le(0, 26)..setU16le(2, 12)),
      SCBlock.object(0xF5D9F4A5, Uint8List(70 * 4)),
      SCBlock.object(0x00EF4BAE, Uint8List(0x100)),
      SCBlock.object(0x02168706, Uint8List(0x1E460)), // Pokédex de Hisui
      ..._filler(),
    ]);
  }

  /// [revision]: 0 = juego base, 1 = Mega Dimensión, 2 = última versión.
  /// Con [gameEmptySlots] los huecos vacíos del equipo llevan el relleno que
  /// escribe el juego (Poké Ball y checksum 4, marcas de presencia), y con
  /// [playedSeconds] se añade el bloque de tiempo de juego real (double).
  static Uint8List legendsZA({
    SynthTrainer trainer = const SynthTrainer(name: 'Urbain'),
    List<SynthMon> party = const [],
    Map<int, List<SynthMon?>> boxes = const {},
    List<String> boxNames = const [],
    int revision = 0,
    bool gameEmptySlots = false,
    double? playedSeconds,
    bool withParty = true,
  }) {
    const f = PkFormat.pa9;
    const ps = 0x158 + 0x88, bs = 0x158 + 0x40;
    final p = Uint8List(6 * ps);
    final blank = Pkm.fromDecrypted(f, Uint8List(f.partySize)).encryptParty();
    final gameBlank = (Uint8List(f.partySize)
      ..[0x124] = 4
      ..[0x06] = 4);
    final emptySlot = gameEmptySlots ? Pkm.fromDecrypted(f, gameBlank).encryptParty() : blank;
    for (var i = 0; i < 6; i++) {
      p.setRange(i * ps, i * ps + 0x158,
          i < party.length ? synthPkm(f, party[i], trainer, i, GameVersion.legendsZA).encryptParty() : emptySlot);
      if (revision != 0) p[i * ps + 0x158] = 1;
      p[i * ps + 0x158 + 0x48] = 1;
    }
    final box = Uint8List(32 * 30 * bs);
    for (var i = 0; i < 32 * 30; i++) {
      box.setRange(i * bs, i * bs + 0x158, blank);
    }
    boxes.forEach((b, mons) {
      for (var i = 0; i < mons.length && i < 30; i++) {
        final m = mons[i];
        if (m == null) continue;
        final o = (b * 30 + i) * bs;
        box.setRange(o, o + 0x158, synthPkm(f, m, trainer, 400 + b * 30 + i, GameVersion.legendsZA).encryptParty());
      }
    });
    final status = Uint8List(0x80);
    status.setU16le(0, trainer.tid);
    status.setU16le(2, trainer.sid);
    status[4] = 52;
    status[5] = trainer.gender;
    status[7] = 7;
    status.setRange(0x10, 0x10 + 0x1A, StringCodec.encodeUtf16(trainer.name, 0x1A));
    final play = Uint8List(0x10)
      ..setU32le(0, trainer.hours)
      ..setU32le(4, trainer.minutes)
      ..setU32le(8, trainer.seconds);
    return SwishCrypto.encrypt([
      SCBlock.object(SCKeys.svMyStatus, status),
      SCBlock.object(SCKeys.svPlayTime, play),
      SCBlock.object(SCKeys.zaStatusMable, Uint8List(0x20)),
      if (withParty) SCBlock.object(SCKeys.svParty, p),
      SCBlock.object(SCKeys.svBox, box),
      SCBlock.object(SCKeys.boxLayout, _boxLayout(boxNames)),
      SCBlock.value(0x4F35D0DD, SCTypeCode.uint32, 5000),
      SCBlock.value(SCKeys.zaSaveRevision, SCTypeCode.uint64, revision),
      if (playedSeconds != null)
        SCBlock.value(SCKeys.zaPlayedSeconds, SCTypeCode.double, 0)
          ..data.buffer.asByteData(0).setFloat64(0, playedSeconds, Endian.little),
      SCBlock.object(0x21C9BD44, _zaItems()),
      SCBlock.object(0x2D87BE5C, Uint8List(0x84 * 1100)), // Pokédex de Luminalia
      ..._filler(),
    ]);
  }

  /// Bloque de objetos de Z-A: 3000 entradas de 0x10 (bolsillo, cantidad, flags, relleno) + flags de bolsillos.
  static Uint8List _zaItems() {
    final d = Uint8List(0xBC00);
    for (var i = 0; i < 3000; i++) {
      d.setU32le(i * 0x10, 0xFFFFFFFF);
      d.setU32le(i * 0x10 + 8, 0xD);
    }
    d
      ..setU32le(17 * 0x10, 0) // Poción ×5 en Medicinas
      ..setU32le(17 * 0x10 + 4, 5)
      ..setU32le(17 * 0x10 + 8, 0x1)
      ..setU32le(4 * 0x10, 1) // Poké Ball ×10
      ..setU32le(4 * 0x10 + 4, 10)
      ..setU32le(4 * 0x10 + 8, 0x1)
      ..setU32le(0xBB80, 0x3);
    return d;
  }

  static Uint8List letsGo({
    SynthTrainer trainer = const SynthTrainer(name: 'Chase', versionId: 42),
    List<SynthMon> party = const [],
    Map<int, List<SynthMon?>> boxes = const {},
  }) {
    final d = Uint8List(SwitchSizes.lgpe);
    // Almacenamiento compacto: primero el equipo y luego las cajas.
    final mons = <SynthMon>[...party];
    final sortedBoxes = boxes.keys.toList()..sort();
    for (final b in sortedBoxes) {
      mons.addAll(boxes[b]!.whereType<SynthMon>());
    }
    for (var i = 0; i < 7; i++) {
      d.setU16le(0x5A00 + i * 2, i < party.length ? i : 1001);
    }
    d.setU16le(0x5A00 + 14, mons.length);
    for (var i = 0; i < mons.length && i < 1000; i++) {
      final pk = synthPkm(PkFormat.pb7, mons[i], trainer, i, GameVersion.letsGo);
      d.setRange(0x5C00 + i * 0x104, 0x5C00 + (i + 1) * 0x104, pk.encryptParty());
    }
    d.setU32le(0x4C04, 3000);
    const used = SwitchSizes.lgpeUsed;
    d.setU32le(used - 0x1F0, 0x42454546);
    d.setU16le(used - 0x200 + 0xB0, 0x13);
    const s = 0x1000;
    d.setU16le(s, trainer.tid);
    d.setU16le(s + 2, trainer.sid);
    d[s + 4] = trainer.versionId ?? 42;
    d[s + 5] = trainer.gender;
    d.setRange(s + 0x38, s + 0x38 + 0x1A, StringCodec.encodeUtf16(trainer.name, 0x1A));
    d.setU16le(0x45400, trainer.hours);
    d[0x45402] = trainer.minutes;
    d[0x45403] = trainer.seconds;
    _writeBeefTable(d, CtrBlocks.lgpe, 0xB8800 - 0x200, 2);
    return d;
  }

  static Uint8List bdsp({
    SynthTrainer trainer = const SynthTrainer(name: 'Dawn'),
    List<SynthMon> party = const [],
    Map<int, List<SynthMon?>> boxes = const {},
  }) {
    final d = Uint8List(0xEF0A4);
    const f = PkFormat.pb8;
    final blank = Pkm.fromDecrypted(f, Uint8List(f.partySize)).encryptParty();
    for (var i = 0; i < 6; i++) {
      final bytes = i < party.length
          ? synthPkm(f, party[i], trainer, i, GameVersion.brilliantDiamondShiningPearl).encryptParty()
          : blank;
      d.setRange(0x14098 + i * 0x158, 0x14098 + (i + 1) * 0x158, bytes);
    }
    d[0x14098 + 6 * 0x158] = party.length.clamp(0, 6);
    for (var i = 0; i < 40 * 30; i++) {
      d.setRange(0x14EF4 + i * 0x158, 0x14EF4 + (i + 1) * 0x158, blank);
    }
    boxes.forEach((b, mons) {
      for (var i = 0; i < mons.length && i < 30; i++) {
        final m = mons[i];
        if (m == null) continue;
        final o = 0x14EF4 + (b * 30 + i) * 0x158;
        d.setRange(o, o + 0x158, synthPkm(f, m, trainer, 500 + b * 30 + i, GameVersion.brilliantDiamondShiningPearl).encryptParty());
      }
    });
    // Objetos: 10 Pociones (id 17) en el array indexado por objeto.
    d.setU32le(0x563C + 17 * 0x10, 10);
    d.setU16le(0x563C + 17 * 0x10 + 12, 1);
    d.setU32le(0, 0x34);
    const s = 0x79BB4;
    d.setRange(s, s + 0x1A, StringCodec.encodeUtf16(trainer.name, 0x1A));
    d.setU16le(s + 0x1C, trainer.tid);
    d.setU16le(s + 0x1E, trainer.sid);
    d[s + 0x24] = trainer.gender == 0 ? 1 : 0;
    d.setU16le(0x79C04, trainer.hours);
    d[0x79C06] = trainer.minutes;
    d[0x79C07] = trainer.seconds;
    d.setRange(0xE9818, 0xE9828, md5.convert(d).bytes);
    return d;
  }

  /// Envuelve un save de NDS con el pie de DeSmuME (.dsv).
  static Uint8List withDesmumeFooter(Uint8List nds) {
    final footer = Uint8List(0x7A);
    const tag = '|-DESMUME SAVE-|';
    for (var i = 0; i < tag.length; i++) {
      footer[0x7A - tag.length + i] = tag.codeUnitAt(i);
    }
    return Uint8List.fromList([...nds, ...footer]);
  }

  /// Envuelve un save de GB/GBA con un pie RTC de emulador.
  static Uint8List withRtcFooter(Uint8List data, [int size = 0x10]) =>
      Uint8List.fromList([...data, ...List.filled(size, 0x5A)]);

  /// Conjunto de demostración variado (para la app y capturas).
  static Map<String, Uint8List> demoSet() => {
        'Esmeralda.sav': gen3(
          game: GameVersion.emerald,
          trainer: const SynthTrainer(name: 'MAY', tid: 31415, sid: 9265, gender: 1, hours: 48, minutes: 12),
          party: const [
            SynthMon(254, level: 52, nickname: 'LEAFY'),
            SynthMon(260, level: 50),
            SynthMon(282, level: 49, shiny: true),
            SynthMon(334, level: 47),
            SynthMon(373, level: 55),
            SynthMon(384, level: 70),
          ],
          boxes: {
            0: const [SynthMon(25, level: 22), SynthMon(133, level: 18, shiny: true), SynthMon(252, level: 5), null, SynthMon(280, level: 12), SynthMon(359, level: 33)],
            1: const [SynthMon(350, level: 40), SynthMon(380, level: 50), SynthMon(381, level: 50)],
          },
          boxNames: const ['FAVORITOS', 'LEGENDS'],
        ),
        'Espada_main': swordShield(
          trainer: const SynthTrainer(name: 'Gloria', tid: 0xA1B2, sid: 0x0C3D, gender: 1, hours: 210, minutes: 5, versionId: 44),
          party: const [
            SynthMon(818, level: 65),
            SynthMon(887, level: 63, shiny: true),
            SynthMon(823, level: 62),
            SynthMon(884, level: 60, nickname: 'Acerito'),
            SynthMon(861, level: 61),
            SynthMon(888, level: 70),
          ],
          boxes: {
            0: const [SynthMon(810, level: 12), SynthMon(813, level: 14), SynthMon(816, level: 13), SynthMon(890, level: 60, shiny: true)],
            3: const [SynthMon(133, level: 25), SynthMon(196, level: 30), SynthMon(197, level: 30), SynthMon(700, level: 35)],
          },
          boxNames: const ['Galar', 'Crianza', 'Shiny', 'Eevee'],
        ),
        'Escarlata_main': scarletViolet(
          trainer: const SynthTrainer(name: 'Juliana', tid: 0x5F10, sid: 0x2A77, gender: 1, hours: 96, minutes: 41, versionId: 50),
          party: const [
            SynthMon(908, level: 72),
            SynthMon(1007, level: 72),
            SynthMon(937, level: 66, shiny: true),
            SynthMon(1000, level: 60),
            SynthMon(983, level: 58, nickname: 'Rey'),
            SynthMon(925, level: 55),
          ],
          boxes: {
            0: const [SynthMon(906, level: 5), SynthMon(909, level: 5), SynthMon(912, level: 5), SynthMon(1024, level: 85, shiny: true)],
          },
          boxNames: const ['Paldea'],
        ),
        'Cristal.sav': gen2(
          crystal: true,
          trainer: const SynthTrainer(name: 'KRIS', tid: 1999, gender: 1, hours: 30, minutes: 2),
          party: const [SynthMon(157, level: 45), SynthMon(181, level: 41, shiny: true), SynthMon(249, level: 60)],
          boxes: {0: const [SynthMon(201, level: 10), SynthMon(130, level: 30, shiny: true)]},
        ),
        'Platino.sav': gen4(
          layout: Gen4Layout.pt,
          trainer: const SynthTrainer(name: 'Dawn', tid: 4040, sid: 1212, gender: 1, hours: 75, minutes: 33),
          party: const [SynthMon(392, level: 56), SynthMon(448, level: 54), SynthMon(487, level: 47, shiny: true)],
          boxes: {0: const [SynthMon(403, level: 20), SynthMon(443, level: 24)]},
        ),
        'Rojo.sav': gen1(
          trainer: const SynthTrainer(name: 'RED', tid: 151, hours: 99, minutes: 59),
          party: const [SynthMon(6, level: 78), SynthMon(25, level: 81), SynthMon(143, level: 70), SynthMon(131, level: 65)],
        ),
        'UltraSol.sav': ctr(
          layout: CtrLayout.usum,
          trainer: const SynthTrainer(name: 'Elio', tid: 0x7788, sid: 0x0099, hours: 140, minutes: 2, versionId: 32),
          party: const [SynthMon(724, level: 66), SynthMon(800, level: 70, shiny: true), SynthMon(745, level: 60)],
        ),
        'Arceus_main': legendsArceus(),
      };
}
