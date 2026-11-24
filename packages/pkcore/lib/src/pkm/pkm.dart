import 'dart:math';
import 'dart:typed_data';

import '../crypto/pk_crypto.dart';
import '../data/game_data.dart';
import '../data/species.dart';
import '../data/species_convert.dart';
import '../model/game.dart';
import '../model/save.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';
import '../util/checksums.dart';
import 'gc_pkm.dart';
import 'pk_format.dart';

/// Entidad Pokémon editable (descifrada) de cualquier generación.
///
/// Los offsets y reglas de cada formato están portados de PKHeX.Core
/// (`PK1` … `PK9`, `PB7`, `PB8`, `PA8`, `PA9`; GPL-3.0).
///
/// [data] siempre tiene el tamaño "de equipo" del formato. En Gen 1/2 el
/// apodo y el nombre del entrenador viven fuera de la estructura (en la lista
/// del save), por eso se guardan en [gbNickname] y [gbOtName].
class Pkm {
  Pkm._(this.format, this.data,
      {this.japanese = false, this.korean = false, String? gbNickname, String? gbOtName, bool gbEgg = false})
      : _gbNick = gbNickname ?? '',
        _gbOt = gbOtName ?? '',
        _gbEgg = gbEgg;

  final PkFormat format;
  final Uint8List data;

  /// Gen 1/2: save japonés (cadenas de 5 caracteres, tabla japonesa).
  final bool japanese;

  /// Gen 2: save coreano (cadenas en la codificación de Oro/Plata coreano).
  final bool korean;
  String _gbNick;
  String _gbOt;
  bool _gbEgg;

  int get generation => format.generation;

  Pkm clone() => Pkm._(format, Uint8List.fromList(data),
      japanese: japanese, korean: korean, gbNickname: _gbNick, gbOtName: _gbOt, gbEgg: _gbEgg)
    ..gc = gc?.clone();

  /// Datos propios de Pokémon Colosseum / XD (CK3/XK3) que el PK3 no guarda:
  /// estado oscuro, región, apodo mostrado… null si el Pokémon no viene de
  /// un save de GameCube. Ver [GcPkm].
  GcExtra? gc;

  // ------------------------------------------------------------ creación

  /// Desde bytes cifrados tal como están en el save. Devuelve null si el hueco está vacío.
  static Pkm? fromEncrypted(PkFormat format, Uint8List bytes) {
    if (format.isGameBoy) throw ArgumentError('Usa fromGb para Gen 1/2');
    if (bytes.length < format.storedSize || bytes.view(0, format.storedSize).isAllValue(0)) return null;
    final dec = switch (format) {
      PkFormat.pk3 => PkCrypto.decrypt3(bytes.copyRange(0, min(bytes.length, PkCrypto.size3Party))),
      PkFormat.pk4 || PkFormat.pk5 => PkCrypto.decrypt45(bytes.copyRange(0, min(bytes.length, format.partySize))),
      PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 =>
        PkCrypto.decrypt67(bytes.copyRange(0, min(bytes.length, format.partySize))),
      PkFormat.pa8 => PkCrypto.decrypt8a(bytes.copyRange(0, min(bytes.length, format.partySize))),
      _ => PkCrypto.decrypt8(bytes.copyRange(0, min(bytes.length, format.partySize))),
    };
    return fromDecrypted(format, dec);
  }

  /// Desde bytes descifrados (archivo `.pkX` exportado). Rellena hasta el tamaño de equipo.
  static Pkm fromDecrypted(PkFormat format, Uint8List decrypted) {
    final d = Uint8List(format.partySize);
    d.setRange(0, min(decrypted.length, d.length), decrypted);
    return Pkm._(format, d);
  }

  /// Gen 1/2 desde la estructura de lista (33/44 o 32/48 bytes) más cadenas.
  static Pkm fromGb(PkFormat format, Uint8List struct,
      {required String nickname, required String otName, bool japanese = false, bool korean = false, bool egg = false}) {
    final d = Uint8List(format.partySize);
    d.setRange(0, min(struct.length, d.length), struct);
    final pk = Pkm._(format, d,
        japanese: japanese, korean: korean, gbNickname: nickname, gbOtName: otName, gbEgg: egg);
    if (struct.length < format.partySize) pk._fillGbPartyFromStored();
    return pk;
  }

  /// Importa un archivo suelto (`.pk1` … `.pa9`).
  static Pkm? fromFile(PkFormat format, Uint8List bytes) {
    if (format.isGameBoy) {
      // Formato "lista de uno": [1][especie][FF][estructura][OT][apodo].
      final jp = bytes.length == (format == PkFormat.pk1 ? 59 : 63);
      final strLen = jp ? 6 : 11;
      final size = format.partySize;
      if (bytes.length < 3 + size + 2 * strLen || bytes[0] != 1) return null;
      final struct = bytes.copyRange(3, size);
      final kor = !jp && format == PkFormat.pk2 && StringCodec.looksKorean(bytes, 3 + size);
      final ot = StringCodec.decodeGb(bytes, 3 + size, strLen, japanese: jp, korean: kor);
      final nick = StringCodec.decodeGb(bytes, 3 + size + strLen, strLen, japanese: jp, korean: kor);
      return fromGb(format, struct, nickname: nick, otName: ot, japanese: jp, korean: kor, egg: bytes[1] == 0xFD);
    }
    if (bytes.length != format.storedSize && bytes.length != format.partySize) return null;
    final pk = fromDecrypted(format, bytes);
    if (!pk.checksumValid) {
      // ¿Viene cifrado?
      final enc = fromEncrypted(format, bytes);
      if (enc != null && enc.checksumValid) return enc;
    }
    return pk;
  }

  /// Exporta como archivo suelto (descifrado, tamaño de equipo; Gen 1/2 = lista de uno).
  Uint8List toFile() {
    if (format.isGameBoy) {
      final strLen = japanese ? 6 : 11;
      final out = Uint8List(3 + format.partySize + 2 * strLen);
      out[0] = 1;
      out[1] = isEgg ? 0xFD : _gbSpeciesByte;
      out[2] = 0xFF;
      out.setRange(3, 3 + format.partySize, data);
      out.setRange(3 + format.partySize, 3 + format.partySize + strLen, StringCodec.encodeGb(_gbOt, strLen, japanese: japanese, korean: korean));
      out.setRange(3 + format.partySize + strLen, out.length,
          StringCodec.encodeGb(_gbNick, strLen, japanese: japanese, korean: korean));
      return out;
    }
    refreshChecksum();
    return Uint8List.fromList(data);
  }

  /// Hueco vacío tal como lo escribe el juego: la estructura a cero, cifrada
  /// (PID/EC 0, checksum 0). En Gen 4+ no equivale a bytes a cero: el cifrado
  /// con semilla 0 produce datos no nulos, y un hueco con ceros literales se
  /// descifra como basura (Huevo Malo en el juego). PKHeX `BlankPKM`.
  static Uint8List blankEncrypted(PkFormat format, {bool party = false}) {
    final blank = fromDecrypted(format, Uint8List(format.partySize));
    return party ? blank.encryptParty() : blank.encryptStored();
  }

  /// Bytes cifrados para un hueco de caja (tamaño almacenado).
  Uint8List encryptStored() => _encrypt().copyRange(0, format.storedSize);

  /// Bytes cifrados para un hueco del equipo (tamaño de equipo).
  Uint8List encryptParty() => _encrypt();

  Uint8List _encrypt() {
    if (format.isGameBoy) return Uint8List.fromList(data);
    refreshChecksum();
    return switch (format) {
      PkFormat.pk3 => () {
          final stored = PkCrypto.encrypt3(data.copyRange(0, PkCrypto.size3Stored));
          final out = Uint8List(PkCrypto.size3Party)..setRange(0, 80, stored);
          out.setRange(80, 100, data, 80);
          return out;
        }(),
      PkFormat.pk4 || PkFormat.pk5 => PkCrypto.encrypt45(data),
      PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => PkCrypto.encrypt67(data),
      PkFormat.pa8 => PkCrypto.encrypt8a(data),
      _ => PkCrypto.encrypt8(data),
    };
  }

  // ------------------------------------------------------------ checksum

  int get _checksumOffset => format == PkFormat.pk3 ? 0x1C : 0x06;

  int computeChecksum() => switch (format) {
        PkFormat.pk1 || PkFormat.pk2 => 0,
        PkFormat.pk3 => PkCrypto.checksum3(data),
        _ => Checksums.add16(data, 8, format.storedSize),
      };

  bool get checksumValid => format.isGameBoy || computeChecksum() == data.u16le(_checksumOffset);

  void refreshChecksum() {
    if (format.isGameBoy) return;
    data.setU16le(_checksumOffset, computeChecksum());
  }

  // ------------------------------------------------------------ helpers

  bool get _pa8 => format == PkFormat.pa8;

  // Gen 1/2: [especie, ...] — offsets en la estructura de equipo.
  int get _gbSpeciesByte => format == PkFormat.pk1 ? data[0] : data[0];

  // ------------------------------------------------------------ especie y forma

  /// Número de la Pokédex Nacional.
  int get species => switch (format) {
        PkFormat.pk1 => SpeciesConvert.nationalFromGen1(data[0]),
        PkFormat.pk2 => data[0],
        PkFormat.pk3 => SpeciesConvert.nationalFromGen3(data.u16le(0x20)),
        PkFormat.pk9 || PkFormat.pa9 => SpeciesConvert.nationalFromGen9(data.u16le(0x08)),
        _ => data.u16le(0x08),
      };

  set species(int value) {
    final wasDefaultName = !isNicknamed;
    switch (format) {
      case PkFormat.pk1:
        data[0] = SpeciesConvert.gen1FromNational(value);
        final p = _personal;
        if (p != null) {
          data[5] = p.type1;
          data[6] = p.type2;
        }
      case PkFormat.pk2:
        data[0] = value;
      case PkFormat.pk3:
        data.setU16le(0x20, SpeciesConvert.gen3FromNational(value));
        data[0x13] |= 0x02; // FlagHasSpecies
      case PkFormat.pk9 || PkFormat.pa9:
        data.setU16le(0x08, SpeciesConvert.gen9FromNational(value));
      default:
        data.setU16le(0x08, value);
    }
    if (wasDefaultName) setDefaultNickname();
  }

  int get form => switch (format) {
        PkFormat.pk1 || PkFormat.pk2 || PkFormat.pk3 => 0,
        PkFormat.pk4 || PkFormat.pk5 => data[0x40] >> 3,
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => data[0x1D] >> 3,
        _ => data[0x24],
      };

  set form(int v) {
    switch (format) {
      case PkFormat.pk1 || PkFormat.pk2 || PkFormat.pk3:
        return;
      case PkFormat.pk4 || PkFormat.pk5:
        data[0x40] = (data[0x40] & 0x07) | ((v & 0x1F) << 3);
      case PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        data[0x1D] = (data[0x1D] & 0x07) | ((v & 0x1F) << 3);
      default:
        data[0x24] = v;
    }
  }

  /// Factor Gigamax (PKHeX `G8PKM.CanGigantamax`: bit 4 del byte 0x16 en
  /// PK8/PB8/PA8). Solo Espada/Escudo lo usa; `false` en otros formatos.
  bool get canGigantamax => switch (format) {
        PkFormat.pk8 || PkFormat.pb8 || PkFormat.pa8 => (data[0x16] & 0x10) != 0,
        _ => false,
      };

  set canGigantamax(bool v) {
    if (format != PkFormat.pk8 && format != PkFormat.pb8 && format != PkFormat.pa8) return;
    data[0x16] = (data[0x16] & ~0x10) | (v ? 0x10 : 0);
  }

  // ------------------------------------------------------------ huevo / apodo

  bool get isEgg => switch (format) {
        PkFormat.pk1 => false,
        PkFormat.pk2 => _gbEgg,
        PkFormat.pk3 => ((data.u32le(0x48) >> 30) & 1) == 1 || (data[0x13] & 0x04) != 0,
        _ => ((data.u32le(_iv32Ofs) >> 30) & 1) == 1,
      };

  set isEgg(bool v) {
    switch (format) {
      case PkFormat.pk1:
        return;
      case PkFormat.pk2:
        _gbEgg = v;
      case PkFormat.pk3:
        _setIv32((_iv32 & ~(1 << 30)) | (v ? 1 << 30 : 0));
        data[0x13] = (data[0x13] & ~0x04) | (v ? 0x04 : 0);
      default:
        _setIv32((_iv32 & ~(1 << 30)) | (v ? 1 << 30 : 0));
    }
  }

  int get _nickOfs => switch (format) {
        PkFormat.pk3 => 0x08,
        PkFormat.pk4 || PkFormat.pk5 => 0x48,
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => 0x40,
        PkFormat.pa8 => 0x60,
        _ => 0x58,
      };

  int get _nickLen => switch (format) {
        PkFormat.pk3 => 10,
        PkFormat.pk4 || PkFormat.pk5 => 22,
        _ => 26,
      };

  String get nickname => switch (format) {
        PkFormat.pk1 || PkFormat.pk2 => _gbNick,
        PkFormat.pk3 => StringCodec.decodeG3(data, 0x08, 10, japanese: language == 1),
        PkFormat.pk4 => StringCodec.decodeG4(data, _nickOfs, _nickLen),
        _ => StringCodec.decodeUtf16(data, _nickOfs, _nickLen),
      };

  set nickname(String v) {
    final max = format.maxNicknameLength;
    final s = v.characters(max);
    switch (format) {
      case PkFormat.pk1 || PkFormat.pk2:
        _gbNick = s;
        return;
      case PkFormat.pk3:
        data.setRange(0x08, 0x12, StringCodec.encodeG3(s, 10, japanese: language == 1));
      case PkFormat.pk4:
        data.setRange(_nickOfs, _nickOfs + _nickLen, StringCodec.encodeG4(s, _nickLen));
      case PkFormat.pk5:
        data.setRange(_nickOfs, _nickOfs + _nickLen, StringCodec.encodeUtf16Gen5(s, _nickLen));
      default:
        data.setRange(_nickOfs, _nickOfs + _nickLen, StringCodec.encodeUtf16(s, _nickLen));
    }
  }

  String _defaultName() {
    final lang = language;
    final sl = lang == 7 ? SpeciesLanguage.es : (lang == 1 ? SpeciesLanguage.ja : SpeciesLanguage.en);
    final n = Species.name(species, sl);
    return generation <= 4 ? n.toUpperCase() : n;
  }

  /// `true` si el apodo es distinto del nombre de la especie.
  bool get isNicknamed {
    if (generation >= 4) return ((_iv32 >> 31) & 1) == 1 && !isEgg;
    final n = nickname.toUpperCase();
    if (n.isEmpty) return false;
    for (final l in SpeciesLanguage.values) {
      if (Species.name(species, l).toUpperCase() == n) return false;
    }
    return true;
  }

  /// Cambia el apodo y marca/desmarca el flag de apodado.
  void setNickname(String? value) {
    if (value == null || value.isEmpty) {
      setDefaultNickname();
      return;
    }
    nickname = value;
    if (generation >= 4) _setIv32((_iv32 & 0x7FFFFFFF) | (value == _defaultName() ? 0 : 1 << 31));
  }

  void setDefaultNickname() {
    if (isEgg) return;
    nickname = _defaultName();
    if (generation >= 4) _setIv32(_iv32 & 0x7FFFFFFF);
  }

  // ------------------------------------------------------------ PID / EC / IDs

  int get pid => switch (format) {
        PkFormat.pk1 || PkFormat.pk2 => 0,
        PkFormat.pk3 || PkFormat.pk4 || PkFormat.pk5 => data.u32le(0),
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => data.u32le(0x18),
        _ => data.u32le(0x1C),
      };

  set pid(int v) {
    switch (format) {
      case PkFormat.pk1 || PkFormat.pk2:
        return;
      case PkFormat.pk3 || PkFormat.pk4 || PkFormat.pk5:
        data.setU32le(0, v);
      case PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        data.setU32le(0x18, v);
      default:
        data.setU32le(0x1C, v);
    }
  }

  /// Constante de cifrado (Gen 6+; en Gen 3–5 coincide con el PID).
  int get encryptionConstant => format.hasEncryptionConstant ? data.u32le(0) : pid;
  set encryptionConstant(int v) {
    if (format.hasEncryptionConstant) data.setU32le(0, v);
  }

  int get _tidOfs => switch (format) {
        PkFormat.pk1 => 12,
        PkFormat.pk2 => 6,
        PkFormat.pk3 => 0x04,
        _ => 0x0C,
      };

  int get tid => format.isGameBoy ? data.u16be(_tidOfs) : data.u16le(_tidOfs);
  set tid(int v) => format.isGameBoy ? data.setU16be(_tidOfs, v) : data.setU16le(_tidOfs, v);

  int get sid => format.isGameBoy ? 0 : data.u16le(_tidOfs + 2);
  set sid(int v) {
    if (!format.isGameBoy) data.setU16le(_tidOfs + 2, v);
  }

  int get _xor => (tid ^ sid ^ (pid >> 16) ^ (pid & 0xFFFF)) & 0xFFFF;

  // ------------------------------------------------------------ shiny

  bool get isShiny {
    if (format.isGameBoy) return _isShinyGb(_dv16);
    return _xor < (generation <= 5 ? 8 : 16);
  }

  /// Gen 8+: variocolor "cuadrado" (xor = 0) frente a "estrella".
  bool get isSquareShiny => generation >= 8 && _xor == 0;

  static bool _isShinyGb(int dvs) {
    final atk = (dvs >> 12) & 0xF, def = (dvs >> 8) & 0xF, spe = (dvs >> 4) & 0xF, spc = dvs & 0xF;
    return def == 10 && spe == 10 && spc == 10 && const {2, 3, 6, 7, 10, 11, 14, 15}.contains(atk);
  }

  /// Regenera PID (o DVs en Gen 1/2) para hacerlo (o dejar de hacerlo) variocolor,
  /// conservando naturaleza, género y habilidad cuando dependen del PID.
  void setShiny(bool shiny, {bool square = false, Random? random}) {
    final rnd = random ?? Random();
    if (format.isGameBoy) {
      if (shiny == isShiny) return;
      final atk = (_dv16 >> 12) & 0xF;
      if (shiny) {
        const ok = [2, 3, 6, 7, 10, 11, 14, 15];
        final a = ok.contains(atk) ? atk : 10;
        _dv16 = (a << 12) | 0xAAA;
      } else {
        _dv16 = (_dv16 & 0xF0FF) | (0x9 << 8); // Def 9
      }
      return;
    }
    if (generation >= 6) {
      final lo = pid & 0xFFFF;
      final base = (tid ^ sid ^ lo) & 0xFFFF;
      if (shiny) {
        final x = generation >= 8 ? (square ? 0 : 1) : rnd.nextInt(16);
        pid = ((base ^ x) << 16) | lo;
      } else if (isShiny) {
        pid = ((base ^ (0x100 + rnd.nextInt(0xFE00))) << 16) | lo;
      }
      return;
    }
    // Gen 3–5: el PID determina naturaleza (Gen 3/4), género y habilidad.
    _regeneratePid(shiny: shiny, random: rnd);
  }

  /// Busca un PID que cumpla las restricciones actuales (Gen 3–5).
  void _regeneratePid({bool? shiny, int? nature, int? gender, Random? random}) {
    final rnd = random ?? Random();
    final wantShiny = shiny ?? isShiny;
    final wantNature = nature ?? this.nature;
    final wantGender = gender ?? this.gender;
    final abilityBit = generation == 5 ? (pid >> 16) & 1 : pid & 1;
    final ratio = _personal?.genderRatio ?? 255;
    final natureFromPid = generation <= 4;
    for (var i = 0; i < 200000; i++) {
      final lo = rnd.nextInt(0x10000);
      final int hi;
      if (wantShiny) {
        hi = (tid ^ sid ^ lo ^ rnd.nextInt(8)) & 0xFFFF;
      } else {
        hi = rnd.nextInt(0x10000);
      }
      final p = (hi << 16) | lo;
      if (((tid ^ sid ^ hi ^ lo) < 8) != wantShiny) continue;
      if (natureFromPid && p % 25 != wantNature) continue;
      final ab = generation == 5 ? (p >> 16) & 1 : p & 1;
      if (ab != abilityBit) continue;
      if (_genderFromPid(p, ratio) != wantGender) continue;
      pid = p;
      if (generation >= 4) _setGenderBits(wantGender);
      return;
    }
  }

  static int _genderFromPid(int pid, int ratio) {
    if (ratio == 255) return 2;
    if (ratio == 254) return 1;
    if (ratio == 0) return 0;
    return (pid & 0xFF) < ratio ? 1 : 0;
  }

  // ------------------------------------------------------------ juego de datos

  /// Juego de referencia para datos personales (stats base, habilidades).
  GameVersion? dataGame;

  PersonalEntry? get _personal {
    final g = dataGame;
    if (g == null) return null;
    return GameDataTable.forGame(g).entry(species, form);
  }

  // ------------------------------------------------------------ género

  /// 0 = macho, 1 = hembra, 2 = sin género.
  int get gender {
    switch (format) {
      case PkFormat.pk1:
        return 2;
      case PkFormat.pk2:
        final ratio = _personal?.genderRatio ?? 127;
        if (ratio == 255) return 2;
        if (ratio == 254) return 1;
        if (ratio == 0) return 0;
        final atk = (_dv16 >> 12) & 0xF;
        return (atk << 4) < ratio ? 1 : 0; // umbral de Gen 2 sobre el DV de ataque
      case PkFormat.pk3:
        return _genderFromPid(pid, _personal?.genderRatio ?? 127);
      case PkFormat.pk4 || PkFormat.pk5:
        return (data[0x40] >> 1) & 3;
      case PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        return (data[0x1D] >> 1) & 3;
      case PkFormat.pk8 || PkFormat.pb8 || PkFormat.pa8:
        return (data[0x22] >> 2) & 3;
      default:
        return (data[0x22] >> 1) & 3;
    }
  }

  set gender(int v) {
    switch (format) {
      case PkFormat.pk1:
        return;
      case PkFormat.pk2:
        final ratio = _personal?.genderRatio ?? 127;
        if (ratio == 255 || ratio == 254 || ratio == 0) return;
        final threshold = (ratio + 15) >> 4; // DV de ataque < umbral => hembra
        var atk = (_dv16 >> 12) & 0xF;
        if (v == 1 && atk >= threshold) atk = max(0, threshold - 1);
        if (v == 0 && atk < threshold) atk = min(15, threshold);
        _dv16 = (_dv16 & 0x0FFF) | (atk << 12);
      case PkFormat.pk3 || PkFormat.pk4 || PkFormat.pk5:
        if (v == gender) return;
        _regeneratePid(gender: v);
      default:
        _setGenderBits(v);
    }
  }

  void _setGenderBits(int v) {
    switch (format) {
      case PkFormat.pk4 || PkFormat.pk5:
        data[0x40] = (data[0x40] & ~0x06) | ((v & 3) << 1);
      case PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        data[0x1D] = (data[0x1D] & ~0x06) | ((v & 3) << 1);
      case PkFormat.pk8 || PkFormat.pb8 || PkFormat.pa8:
        data[0x22] = (data[0x22] & ~0x0C) | ((v & 3) << 2);
      case PkFormat.pk9 || PkFormat.pa9:
        data[0x22] = (data[0x22] & ~0x06) | ((v & 3) << 1);
      default:
    }
  }

  // ------------------------------------------------------------ naturaleza

  int get nature => switch (format) {
        PkFormat.pk1 || PkFormat.pk2 => _gbNatureFromExp,
        PkFormat.pk3 || PkFormat.pk4 => pid % 25,
        PkFormat.pk5 => data[0x41],
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => data[0x1C],
        _ => data[0x20],
      };

  int get _gbNatureFromExp => exp % 25; // así lo trata Pokémon Bank/HOME

  set nature(int v) {
    switch (format) {
      case PkFormat.pk1 || PkFormat.pk2:
        return;
      case PkFormat.pk3 || PkFormat.pk4:
        if (v == nature) return;
        _regeneratePid(nature: v);
      case PkFormat.pk5:
        data[0x41] = v;
      case PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        data[0x1C] = v;
      default:
        // Sin menta previa, la naturaleza de stats acompaña a la real.
        if (data[0x21] == data[0x20]) data[0x21] = v;
        data[0x20] = v;
    }
  }

  /// Naturaleza que afecta a las estadísticas (menta en Gen 8+).
  int get statNature => format.hasStatNature ? data[0x21] : nature;
  set statNature(int v) {
    if (format.hasStatNature) data[0x21] = v;
  }

  // ------------------------------------------------------------ habilidad

  int get ability {
    switch (format) {
      case PkFormat.pk1 || PkFormat.pk2:
        return 0;
      case PkFormat.pk3:
        final abil = _personal?.abilities ?? const [];
        final slot = (data.u32le(0x48) >> 31) & 1;
        if (abil.isEmpty) return 0;
        return slot < abil.length ? abil[slot] : abil.first;
      case PkFormat.pk4 || PkFormat.pk5 || PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        return data[generation <= 5 ? 0x15 : 0x14];
      default:
        return data.u16le(0x14);
    }
  }

  /// Ranura de habilidad: 0, 1 o 2 (oculta).
  int get abilitySlot {
    switch (format) {
      case PkFormat.pk1 || PkFormat.pk2:
        return 0;
      case PkFormat.pk3:
        return (data.u32le(0x48) >> 31) & 1;
      case PkFormat.pk4:
        final abil = _personal?.abilities ?? const [];
        final i = abil.indexOf(ability);
        return i < 0 ? 0 : i;
      case PkFormat.pk5:
        if ((data[0x42] & 1) == 1) return 2;
        return (pid >> 16) & 1;
      case PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        return _numToSlot(data[0x15] & 7);
      default:
        return _numToSlot(data[0x16] & 7);
    }
  }

  static int _numToSlot(int n) => n == 4 ? 2 : (n == 2 ? 1 : 0);

  /// Fija la habilidad por ranura (0, 1, 2 = oculta) usando los datos personales.
  void setAbilitySlot(int slot) {
    final abil = _personal?.abilities ?? const <int>[];
    final id = abil.isEmpty ? 0 : abil[slot.clamp(0, abil.length - 1)];
    switch (format) {
      case PkFormat.pk1 || PkFormat.pk2:
        return;
      case PkFormat.pk3:
        _setIv32((data.u32le(0x48) & 0x7FFFFFFF) | ((slot & 1) << 31));
      case PkFormat.pk4:
        data[0x15] = id;
      case PkFormat.pk5:
        data[0x15] = id;
        data[0x42] = (data[0x42] & ~1) | (slot == 2 ? 1 : 0);
      case PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        data[0x14] = id;
        data[0x15] = (data[0x15] & ~7) | (1 << slot.clamp(0, 2));
      default:
        data.setU16le(0x14, id);
        data[0x16] = (data[0x16] & ~7) | (1 << slot.clamp(0, 2));
    }
  }

  // ------------------------------------------------------------ objeto

  int get heldItem => switch (format) {
        PkFormat.pk1 => 0,
        PkFormat.pk2 => data[1],
        PkFormat.pk3 => data.u16le(0x22),
        _ => data.u16le(0x0A),
      };

  set heldItem(int v) {
    switch (format) {
      case PkFormat.pk1:
        return;
      case PkFormat.pk2:
        data[1] = v & 0xFF;
      case PkFormat.pk3:
        data.setU16le(0x22, v);
      default:
        data.setU16le(0x0A, v);
    }
  }

  // ------------------------------------------------------------ experiencia y nivel

  int get exp => switch (format) {
        PkFormat.pk1 => (data[14] << 16) | (data[15] << 8) | data[16],
        PkFormat.pk2 => (data[8] << 16) | (data[9] << 8) | data[10],
        PkFormat.pk3 => data.u32le(0x24),
        _ => data.u32le(0x10),
      };

  set exp(int v) {
    switch (format) {
      case PkFormat.pk1:
        data[14] = (v >> 16) & 0xFF;
        data[15] = (v >> 8) & 0xFF;
        data[16] = v & 0xFF;
      case PkFormat.pk2:
        data[8] = (v >> 16) & 0xFF;
        data[9] = (v >> 8) & 0xFF;
        data[10] = v & 0xFF;
      case PkFormat.pk3:
        data.setU32le(0x24, v);
      default:
        data.setU32le(0x10, v);
    }
  }

  int get _statLevelOfs => switch (format) {
        PkFormat.pk1 => 33,
        PkFormat.pk2 => 31,
        PkFormat.pk3 => 0x54,
        PkFormat.pk4 || PkFormat.pk5 => 0x8C,
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => 0xEC,
        PkFormat.pa8 => 0x168,
        _ => 0x148,
      };

  /// Nivel calculado a partir de la experiencia.
  int get level => Species.levelFromExp(species, exp);

  /// Fija el nivel (ajusta la experiencia al mínimo del nivel y recalcula stats).
  set level(int v) {
    final l = v.clamp(1, 100);
    exp = Species.expForLevel(species, l);
    _writeLevelByte(l);
  }

  void _writeLevelByte(int l) {
    data[_statLevelOfs] = l;
    if (format == PkFormat.pk1) data[3] = l;
  }

  // ------------------------------------------------------------ movimientos

  int get _moveOfs => switch (format) {
        PkFormat.pk1 => 8,
        PkFormat.pk2 => 2,
        PkFormat.pk3 => 0x2C,
        PkFormat.pk4 || PkFormat.pk5 => 0x28,
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => 0x5A,
        PkFormat.pa8 => 0x54,
        _ => 0x72,
      };

  List<int> get moves => [for (var i = 0; i < 4; i++) move(i)];

  int move(int i) => format.isGameBoy ? data[_moveOfs + i] : data.u16le(_moveOfs + i * 2);

  void setMove(int i, int moveId, {String? context, bool refillPp = true}) {
    if (format.isGameBoy) {
      data[_moveOfs + i] = moveId & 0xFF;
    } else {
      data.setU16le(_moveOfs + i * 2, moveId);
    }
    if (refillPp && context != null) setPp(i, MoveData.maxPp(moveId, context, ppUps(i)));
  }

  int get _ppOfs => switch (format) {
        PkFormat.pk1 => 29,
        PkFormat.pk2 => 23,
        PkFormat.pk3 => 0x34,
        PkFormat.pk4 || PkFormat.pk5 => 0x30,
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => 0x62,
        PkFormat.pa8 => 0x5C,
        _ => 0x7A,
      };

  int pp(int i) => format.isGameBoy ? data[_ppOfs + i] & 0x3F : data[_ppOfs + i];

  void setPp(int i, int v) {
    if (format.isGameBoy) {
      data[_ppOfs + i] = (data[_ppOfs + i] & 0xC0) | (v & 0x3F);
    } else {
      data[_ppOfs + i] = v.clamp(0, 255);
    }
  }

  int ppUps(int i) => switch (format) {
        PkFormat.pk1 || PkFormat.pk2 => data[_ppOfs + i] >> 6,
        PkFormat.pk3 => (data[0x28] >> (i * 2)) & 3,
        PkFormat.pk4 || PkFormat.pk5 => data[0x34 + i],
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => data[0x66 + i],
        PkFormat.pa8 => data[0x86 + i],
        _ => data[0x7E + i],
      };

  void setPpUps(int i, int v) {
    final u = v.clamp(0, 3);
    switch (format) {
      case PkFormat.pk1 || PkFormat.pk2:
        data[_ppOfs + i] = (data[_ppOfs + i] & 0x3F) | (u << 6);
      case PkFormat.pk3:
        data[0x28] = (data[0x28] & ~(3 << (i * 2))) | (u << (i * 2));
      case PkFormat.pk4 || PkFormat.pk5:
        data[0x34 + i] = u;
      case PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        data[0x66 + i] = u;
      case PkFormat.pa8:
        data[0x86 + i] = u;
      default:
        data[0x7E + i] = u;
    }
  }

  /// Rellena los PP de todos los movimientos a su máximo.
  void healPp(String context) {
    for (var i = 0; i < 4; i++) {
      setPp(i, MoveData.maxPp(move(i), context, ppUps(i)));
    }
  }

  // ------------------------------------------------------------ IV / EV / AV / GV

  int get _iv32Ofs => switch (format) {
        PkFormat.pk3 => 0x48,
        PkFormat.pk4 || PkFormat.pk5 => 0x38,
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => 0x74,
        PkFormat.pa8 => 0x94,
        _ => 0x8C,
      };

  int get _iv32 => format.isGameBoy ? 0 : data.u32le(_iv32Ofs);
  void _setIv32(int v) => data.setU32le(_iv32Ofs, v & 0xFFFFFFFF);

  int get _dvOfs => format == PkFormat.pk1 ? 27 : 21;
  int get _dv16 => data.u16be(_dvOfs);
  set _dv16(int v) => data.setU16be(_dvOfs, v);

  // Índice API -> posición de almacenamiento (PS, Atq, Def, Vel, AtqE, DefE).
  static const _apiToStore = [0, 1, 2, 4, 5, 3];

  /// IVs en orden API (PS, Atq, Def, AtqEsp, DefEsp, Vel). En Gen 1/2 son DVs 0–15.
  List<int> get ivs {
    if (format.isGameBoy) {
      final dv = _dv16;
      final atk = (dv >> 12) & 0xF, def = (dv >> 8) & 0xF, spe = (dv >> 4) & 0xF, spc = dv & 0xF;
      final hp = ((atk & 1) << 3) | ((def & 1) << 2) | ((spe & 1) << 1) | (spc & 1);
      return [hp, atk, def, spc, spc, spe];
    }
    final v = _iv32;
    return [for (var i = 0; i < 6; i++) (v >> (5 * _apiToStore[i])) & 0x1F];
  }

  void setIv(int stat, int value) {
    if (format.isGameBoy) {
      final v = value.clamp(0, 15);
      var dv = _dv16;
      switch (stat) {
        case 1:
          dv = (dv & 0x0FFF) | (v << 12);
        case 2:
          dv = (dv & 0xF0FF) | (v << 8);
        case 5:
          dv = (dv & 0xFF0F) | (v << 4);
        case 3 || 4:
          dv = (dv & 0xFFF0) | v;
        default:
          // PS se deriva de los bits bajos del resto.
          dv = (dv & ~0x1111) |
              (((v >> 3) & 1) << 12) |
              (((v >> 2) & 1) << 8) |
              (((v >> 1) & 1) << 4) |
              (v & 1);
      }
      _dv16 = dv;
      return;
    }
    final shift = 5 * _apiToStore[stat];
    _setIv32((_iv32 & ~(0x1F << shift)) | ((value.clamp(0, 31)) << shift));
  }

  void setIvs(List<int> values) {
    for (var i = 0; i < 6; i++) {
      setIv(i, values[i]);
    }
  }

  int get _evOfs => switch (format) {
        PkFormat.pk1 => 17,
        PkFormat.pk2 => 11,
        PkFormat.pk3 => 0x38,
        PkFormat.pk4 || PkFormat.pk5 => 0x18,
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => 0x1E,
        _ => 0x26,
      };

  /// EVs en orden API. En Gen 1/2 son "stat exp" (0–65535; AtqEsp = DefEsp = Especial).
  List<int> get evs {
    if (format.isGameBoy) {
      final o = _evOfs;
      final hp = data.u16be(o), atk = data.u16be(o + 2), def = data.u16be(o + 4);
      final spe = data.u16be(o + 6), spc = data.u16be(o + 8);
      return [hp, atk, def, spc, spc, spe];
    }
    return [for (var i = 0; i < 6; i++) data[_evOfs + _apiToStore[i]]];
  }

  void setEv(int stat, int value) {
    if (format.isGameBoy) {
      const map = [0, 1, 2, 4, 4, 3];
      data.setU16be(_evOfs + map[stat] * 2, value.clamp(0, 65535));
      return;
    }
    data[_evOfs + _apiToStore[stat]] = value.clamp(0, 255);
  }

  void setEvs(List<int> values) {
    for (var i = 0; i < 6; i++) {
      setEv(i, values[i]);
    }
  }

  /// Valores de despertar (Let's Go), orden API.
  List<int> get avs => format.hasAwakeningValues ? [for (var i = 0; i < 6; i++) data[0x24 + _apiToStore[i]]] : const [];
  void setAv(int stat, int v) {
    if (format.hasAwakeningValues) data[0x24 + _apiToStore[stat]] = v.clamp(0, 200);
  }

  /// Niveles de esfuerzo (Leyendas Arceus), orden API.
  List<int> get gvs => format.hasGanbaruValues ? [for (var i = 0; i < 6; i++) data[0xA4 + _apiToStore[i]]] : const [];
  void setGv(int stat, int v) {
    if (format.hasGanbaruValues) data[0xA4 + _apiToStore[stat]] = v.clamp(0, 10);
  }

  // ------------------------------------------------------------ entrenador original

  int get _otOfs => switch (format) {
        PkFormat.pk3 => 0x14,
        PkFormat.pk4 || PkFormat.pk5 => 0x68,
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => 0xB0,
        PkFormat.pa8 => 0x110,
        _ => 0xF8,
      };

  String get otName => switch (format) {
        PkFormat.pk1 || PkFormat.pk2 => _gbOt,
        PkFormat.pk3 => StringCodec.decodeG3(data, 0x14, 7, japanese: language == 1),
        PkFormat.pk4 => StringCodec.decodeG4(data, _otOfs, 16),
        PkFormat.pk5 => StringCodec.decodeUtf16(data, _otOfs, 16),
        _ => StringCodec.decodeUtf16(data, _otOfs, 26),
      };

  set otName(String v) {
    final s = v.characters(format.maxTrainerNameLength);
    switch (format) {
      case PkFormat.pk1 || PkFormat.pk2:
        _gbOt = s;
      case PkFormat.pk3:
        data.setRange(0x14, 0x1B, StringCodec.encodeG3(s, 7, japanese: language == 1));
      case PkFormat.pk4:
        data.setRange(_otOfs, _otOfs + 16, StringCodec.encodeG4(s, 16));
      case PkFormat.pk5:
        data.setRange(_otOfs, _otOfs + 16, StringCodec.encodeUtf16Gen5(s, 16));
      default:
        data.setRange(_otOfs, _otOfs + 26, StringCodec.encodeUtf16(s, 26));
    }
  }

  int get otGender => switch (format) {
        PkFormat.pk1 || PkFormat.pk2 => 0,
        PkFormat.pk3 => (data.u16le(0x46) >> 15) & 1,
        PkFormat.pk4 || PkFormat.pk5 => data[0x84] >> 7,
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => data[0xDD] >> 7,
        PkFormat.pa8 => data[0x13D] >> 7,
        _ => data[0x125] >> 7,
      };

  set otGender(int v) {
    final b = v & 1;
    switch (format) {
      case PkFormat.pk1 || PkFormat.pk2:
        return;
      case PkFormat.pk3:
        data.setU16le(0x46, (data.u16le(0x46) & 0x7FFF) | (b << 15));
      case PkFormat.pk4 || PkFormat.pk5:
        data[0x84] = (data[0x84] & 0x7F) | (b << 7);
      case PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        data[0xDD] = (data[0xDD] & 0x7F) | (b << 7);
      case PkFormat.pa8:
        data[0x13D] = (data[0x13D] & 0x7F) | (b << 7);
      default:
        data[0x125] = (data[0x125] & 0x7F) | (b << 7);
    }
  }

  int get language => switch (format) {
        PkFormat.pk1 || PkFormat.pk2 => japanese ? 1 : (korean ? 8 : 2),
        PkFormat.pk3 => data[0x12],
        PkFormat.pk4 || PkFormat.pk5 => data[0x17],
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => data[0xE3],
        PkFormat.pk8 || PkFormat.pb8 => data[0xE2],
        PkFormat.pa8 => data[0xF2],
        _ => data[0xD5],
      };

  set language(int v) {
    switch (format) {
      case PkFormat.pk1 || PkFormat.pk2:
        return;
      case PkFormat.pk3:
        data[0x12] = v;
      case PkFormat.pk4 || PkFormat.pk5:
        data[0x17] = v;
      case PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        data[0xE3] = v;
      case PkFormat.pk8 || PkFormat.pb8:
        data[0xE2] = v;
      case PkFormat.pa8:
        data[0xF2] = v;
      default:
        data[0xD5] = v;
    }
  }

  // ------------------------------------------------------------ amistad / ball

  int get _currentHandler => switch (format) {
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => data[0x93],
        PkFormat.pa8 => data[0xD4],
        PkFormat.pk8 || PkFormat.pb8 || PkFormat.pk9 || PkFormat.pa9 => data[0xC4],
        _ => 0,
      };

  int get _otFriendOfs => switch (format) {
        PkFormat.pk1 => -1,
        PkFormat.pk2 => 27,
        PkFormat.pk3 => 0x29,
        PkFormat.pk4 || PkFormat.pk5 => 0x14,
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => 0xCA,
        PkFormat.pa8 => 0x12A,
        _ => 0x112,
      };

  int get _htFriendOfs => switch (format) {
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => 0xA2,
        PkFormat.pa8 => 0xD8,
        _ => 0xC8,
      };

  /// Amistad del entrenador que lo tiene ahora (OT o el último entrenador).
  int get friendship {
    if (_otFriendOfs < 0) return 0;
    if (generation >= 6 && _currentHandler != 0) return data[_htFriendOfs];
    return data[_otFriendOfs];
  }

  set friendship(int v) {
    if (_otFriendOfs < 0) return;
    if (generation >= 6 && _currentHandler != 0) {
      data[_htFriendOfs] = v.clamp(0, 255);
    } else {
      data[_otFriendOfs] = v.clamp(0, 255);
    }
  }

  int get ball => switch (format) {
        PkFormat.pk1 || PkFormat.pk2 => 4,
        PkFormat.pk3 => (data.u16le(0x46) >> 11) & 0xF,
        PkFormat.pk4 => data[0x86] != 0 ? data[0x86] : data[0x83],
        PkFormat.pk5 => data[0x83],
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => data[0xDC],
        PkFormat.pa8 => data[0x137],
        _ => data[0x124],
      };

  set ball(int v) {
    switch (format) {
      case PkFormat.pk1 || PkFormat.pk2:
        return;
      case PkFormat.pk3:
        data.setU16le(0x46, (data.u16le(0x46) & ~0x7800) | ((v & 0xF) << 11));
      case PkFormat.pk4:
        data[0x83] = v <= 16 ? v : 4;
        data[0x86] = v <= 16 ? 0 : v;
      case PkFormat.pk5:
        data[0x83] = v;
      case PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        data[0xDC] = v;
      case PkFormat.pa8:
        data[0x137] = v;
      default:
        data[0x124] = v;
    }
  }

  int get metLevel => switch (format) {
        PkFormat.pk1 || PkFormat.pk2 => 0,
        PkFormat.pk3 => data.u16le(0x46) & 0x7F,
        PkFormat.pk4 || PkFormat.pk5 => data[0x84] & 0x7F,
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => data[0xDD] & 0x7F,
        PkFormat.pa8 => data[0x13D] & 0x7F,
        _ => data[0x125] & 0x7F,
      };

  // ------------------------------------------------------------ origen

  int get _relearnOfs => switch (format) {
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => 0x6A,
        PkFormat.pa8 => 0x8A,
        PkFormat.pk8 || PkFormat.pb8 || PkFormat.pk9 || PkFormat.pa9 => 0x82,
        _ => -1,
      };

  /// `true` si el formato guarda movimientos recordables (Gen 6+).
  bool get hasRelearnMoves => _relearnOfs >= 0;

  List<int> get relearnMoves => hasRelearnMoves ? [for (var i = 0; i < 4; i++) data.u16le(_relearnOfs + i * 2)] : const [];

  void setRelearnMove(int index, int move) {
    if (hasRelearnMoves) data.setU16le(_relearnOfs + index * 2, move);
  }

  /// Encuentro fatídico (marca de evento).
  bool get fatefulEncounter => switch (format) {
        PkFormat.pk4 || PkFormat.pk5 => data[0x40] & 1 == 1,
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => data[0x1D] & 1 == 1,
        PkFormat.pk1 || PkFormat.pk2 || PkFormat.pk3 => false,
        _ => data[0x22] & 1 == 1,
      };

  /// Lugar de encuentro (id interno del juego de origen; -1 si el formato no lo guarda).
  ///
  /// En PK4 hay dos campos: el de Diamante/Perla (0x80) y el extendido de
  /// Platino/HGSS (0x46). Los lugares que no existen en DP guardan 3002 («lugar
  /// lejano») en el primero y el real en el segundo; manda el extendido si no es 0
  /// (PKHeX `G4PKM.MetLocation`).
  int get metLocation => switch (format) {
        PkFormat.pk3 => data[0x45],
        PkFormat.pk4 => data.u16le(0x46) != 0 ? data.u16le(0x46) : data.u16le(0x80),
        PkFormat.pk5 => data.u16le(0x80),
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => data.u16le(0xDA),
        PkFormat.pa8 => data.u16le(0x13A),
        PkFormat.pk8 || PkFormat.pb8 || PkFormat.pk9 || PkFormat.pa9 => data.u16le(0x122),
        _ => -1,
      };

  set metLocation(int v) {
    switch (format) {
      case PkFormat.pk3:
        data[0x45] = v & 0xFF;
      case PkFormat.pk4:
        if (v == 0) {
          data.setU16le(0x80, 0);
          data.setU16le(0x46, 0);
        } else if ((v > 111 && v < 2000) || (v > 2010 && v < 3000)) {
          // Lugar exclusivo de Platino/HGSS: DP ve «lugar lejano».
          data.setU16le(0x80, 3002);
          data.setU16le(0x46, v);
        } else {
          // Solo los juegos Pt/HGSS (o un traspaso que ya lo rellenó) escriben el campo extendido.
          final ptHgss = const {7, 8, 12}.contains(version) || data.u16le(0x46) != 0;
          data.setU16le(0x80, v);
          data.setU16le(0x46, ptHgss ? v : 0);
        }
      case PkFormat.pk5:
        data.setU16le(0x80, v);
      case PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        data.setU16le(0xDA, v);
      case PkFormat.pa8:
        data.setU16le(0x13A, v);
      case PkFormat.pk8 || PkFormat.pb8 || PkFormat.pk9 || PkFormat.pa9:
        data.setU16le(0x122, v);
      default:
        return;
    }
  }

  set metLevel(int v) {
    final x = v & 0x7F;
    switch (format) {
      case PkFormat.pk1 || PkFormat.pk2:
        return;
      case PkFormat.pk3:
        data.setU16le(0x46, (data.u16le(0x46) & ~0x7F) | x);
      case PkFormat.pk4 || PkFormat.pk5:
        data[0x84] = (data[0x84] & 0x80) | x;
      case PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        data[0xDD] = (data[0xDD] & 0x80) | x;
      case PkFormat.pa8:
        data[0x13D] = (data[0x13D] & 0x80) | x;
      default:
        data[0x125] = (data[0x125] & 0x80) | x;
    }
  }

  set version(int v) {
    switch (format) {
      case PkFormat.pk1 || PkFormat.pk2:
        return;
      case PkFormat.pk3:
        data.setU16le(0x46, (data.u16le(0x46) & ~0x780) | ((v & 0xF) << 7));
      case PkFormat.pk4 || PkFormat.pk5:
        data[0x5F] = v;
      case PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        data[0xDF] = v;
      case PkFormat.pk8 || PkFormat.pb8:
        data[0xDE] = v;
      case PkFormat.pa8:
        data[0xEE] = v;
      default:
        data[0xCE] = v;
    }
  }

  /// Juego de origen (id de PKHeX).
  int get version => switch (format) {
        PkFormat.pk1 || PkFormat.pk2 => 0,
        PkFormat.pk3 => (data.u16le(0x46) >> 7) & 0xF,
        PkFormat.pk4 || PkFormat.pk5 => data[0x5F],
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => data[0xDF],
        PkFormat.pk8 || PkFormat.pb8 => data[0xDE],
        PkFormat.pa8 => data[0xEE],
        _ => data[0xCE],
      };

  // ------------------------------------------------------------ tera tipo (SV)

  /// Teratipo original (0–17; 99 = Astral en datos de PKHeX).
  int get teraTypeOriginal => format.hasTeraType ? data[0x94] : -1;
  set teraTypeOriginal(int v) {
    if (format.hasTeraType) data[0x94] = v;
  }

  /// Teratipo efectivo (el cambiado con teralitos si existe; 19 = sin cambio).
  int get teraType {
    if (!format.hasTeraType) return -1;
    final o = data[0x95];
    return o == 19 ? data[0x94] : o;
  }

  set teraType(int v) {
    if (!format.hasTeraType) return;
    data[0x95] = v == data[0x94] ? 19 : v;
  }

  // ------------------------------------------------------------ movimientos «plus» (Leyendas Z-A)

  /// `true` si el formato guarda flags de movimientos «plus» (PA9).
  bool get hasPlusFlags => format == PkFormat.pa9;

  /// Alfa (PA9, offset 0x23). Fuera de PA9 siempre `false`.
  bool get isAlpha => format == PkFormat.pa9 && data[0x23] != 0;

  /// Número de flags «plus» que existen en el formato (PKHeX `PlusCountTotal`).
  static const int plusFlagCount = 360;

  // PKHeX `PA9`: índices 0‥263 en 0xD6 (33 bytes) y 264‥359 en 0x94 (12 bytes).
  int _plusOffset(int index) => index < 264 ? 0xD6 + (index >> 3) : 0x94 + ((index - 264) >> 3);

  /// Flag «plus» del índice [index] (orden de PKHeX `PersonalInfo9ZA.PlusMoves`).
  bool plusFlag(int index) {
    if (!hasPlusFlags || index < 0 || index >= plusFlagCount) return false;
    return (data[_plusOffset(index)] >> (index & 7)) & 1 != 0;
  }

  void setPlusFlag(int index, bool value) {
    if (!hasPlusFlags || index < 0 || index >= plusFlagCount) return;
    final o = _plusOffset(index);
    final bit = 1 << (index & 7);
    data[o] = value ? data[o] | bit : data[o] & ~bit;
  }

  // ------------------------------------------------------------ estadísticas

  /// Estadísticas calculadas (orden API) para un [level] dado con los datos de [dataGame].
  List<int>? computeStats([int? atLevel]) {
    final p = _personal;
    if (p == null) return null;
    final l = atLevel ?? level;
    final iv = ivs, ev = evs, b = p.baseStats;
    if (format.isGameBoy) {
      int st(int base, int dv, int sexp) => ((((base + dv) * 2 + (_isqrtCeil(sexp) ~/ 4)) * l) ~/ 100);
      final hp = st(b[0], iv[0], ev[0]) + l + 10;
      return [hp, for (var i = 1; i < 6; i++) st(b[i], iv[i], ev[i]) + 5];
    }
    final effect = GameStrings.natureEffect(statNature);
    int amp(int i, int v) {
      if (effect == null) return v;
      if (effect.$1 == i) return v * 110 ~/ 100;
      if (effect.$2 == i) return v * 90 ~/ 100;
      return v;
    }

    if (_pa8) {
      final gv = gvs;
      int gan(int base, int iv, int g) {
        const mul = [0, 2, 3, 4, 7, 8, 9, 14, 15, 16, 25];
        final bias = iv >= 31 ? 3 : (iv >= 26 ? 2 : (iv >= 20 ? 1 : 0));
        final m = mul[min(g + bias, 10)];
        return ((sqrt(base) * m + l) / 2.5).round();
      }

      final hp = gan(b[0], iv[0], gv[0]) + (((l / 100.0) + 1.0) * b[0] + l).floor();
      return [
        hp,
        for (var i = 1; i < 6; i++) gan(b[i], iv[i], gv[i]) + amp(i, ((((l / 50.0) + 1.0) * b[i]) / 1.5).floor()),
      ];
    }
    if (format == PkFormat.pb7) {
      final av = avs;
      final scalar = (((friendship / 255.0 / 10.0) + 1.0) * 100.0).floor();
      final hp = av[0] + ((iv[0] + 2 * b[0]) * l ~/ 100) + 10 + l;
      return [
        hp,
        for (var i = 1; i < 6; i++) av[i] + (scalar * amp(i, ((iv[i] + 2 * b[i]) * l ~/ 100) + 5) ~/ 100),
      ];
    }
    if (species == 292) {
      // Shedinja siempre tiene 1 PS.
      return [1, for (var i = 1; i < 6; i++) amp(i, ((2 * b[i] + iv[i] + ev[i] ~/ 4) * l ~/ 100) + 5)];
    }
    final hp = ((2 * b[0] + iv[0] + ev[0] ~/ 4) * l ~/ 100) + l + 10;
    return [hp, for (var i = 1; i < 6; i++) amp(i, ((2 * b[i] + iv[i] + ev[i] ~/ 4) * l ~/ 100) + 5)];
  }

  static int _isqrtCeil(int v) {
    if (v <= 0) return 0;
    final r = sqrt(v).ceil();
    return min(r, 255);
  }

  /// Estadísticas guardadas en la parte de equipo (orden API), si existen.
  List<int> get partyStats {
    switch (format) {
      case PkFormat.pk1:
        return [data.u16be(34), data.u16be(36), data.u16be(38), data.u16be(42), data.u16be(42), data.u16be(40)];
      case PkFormat.pk2:
        return [data.u16be(36), data.u16be(38), data.u16be(40), data.u16be(44), data.u16be(46), data.u16be(42)];
      default:
        final o = _partyHpMaxOfs;
        // Orden almacenado: PSmax, Atq, Def, Vel, AtqE, DefE.
        return [data.u16le(o), data.u16le(o + 2), data.u16le(o + 4), data.u16le(o + 8), data.u16le(o + 10), data.u16le(o + 6)];
    }
  }

  int get _partyHpMaxOfs => switch (format) {
        PkFormat.pk3 => 0x58,
        PkFormat.pk4 || PkFormat.pk5 => 0x90,
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => 0xF2,
        PkFormat.pa8 => 0x16A,
        _ => 0x14A,
      };

  int get _partyHpCurOfs => switch (format) {
        PkFormat.pk3 => 0x56,
        PkFormat.pk4 || PkFormat.pk5 => 0x8E,
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => 0xF0,
        PkFormat.pa8 => 0x92,
        _ => 0x8A,
      };

  /// Recalcula nivel y estadísticas de la parte de equipo (cura PS).
  void refreshPartyStats() {
    final l = level;
    _writeLevelByte(l);
    final st = computeStats(l);
    if (st == null) return;
    switch (format) {
      case PkFormat.pk1:
        data.setU16be(1, st[0]);
        data.setU16be(34, st[0]);
        data.setU16be(36, st[1]);
        data.setU16be(38, st[2]);
        data.setU16be(40, st[5]);
        data.setU16be(42, st[3]);
      case PkFormat.pk2:
        data.setU16be(34, st[0]);
        data.setU16be(36, st[0]);
        data.setU16be(38, st[1]);
        data.setU16be(40, st[2]);
        data.setU16be(42, st[5]);
        data.setU16be(44, st[3]);
        data.setU16be(46, st[4]);
      default:
        final o = _partyHpMaxOfs;
        data.setU16le(_partyHpCurOfs, st[0]);
        data.setU16le(o, st[0]);
        data.setU16le(o + 2, st[1]);
        data.setU16le(o + 4, st[2]);
        data.setU16le(o + 6, st[5]);
        data.setU16le(o + 8, st[3]);
        data.setU16le(o + 10, st[4]);
    }
  }

  void _fillGbPartyFromStored() {
    // Estructura de caja -> equipo: el nivel de caja de Gen 1 está en el byte 3.
    if (format == PkFormat.pk1) data[33] = data[3];
    refreshPartyStats();
  }

  // ------------------------------------------------------------ resumen

  PokemonSummary toSummary() => PokemonSummary(
        species: species,
        form: form,
        nickname: isNicknamed && !isEgg ? nickname : null,
        level: level,
        isShiny: isShiny,
        isEgg: isEgg,
        heldItem: heldItem,
        pid: format.isGameBoy ? null : pid,
      );

  @override
  String toString() => 'Pkm(${format.extension} #$species lv$level${isShiny ? ' ★' : ''} "$nickname")';
}

extension on String {
  /// Recorta a [max] caracteres (runas).
  String characters(int max) {
    final r = runes.toList();
    return r.length <= max ? this : String.fromCharCodes(r.take(max));
  }
}
