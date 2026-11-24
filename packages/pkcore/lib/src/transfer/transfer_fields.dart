import 'dart:typed_data';

import '../data/generated/transfer_data.dart';
import '../data/species.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';

/// Offsets de los campos de Gen 6+ que [Pkm] no expone y que hacen falta
/// para convertir entre formatos (PKHeX `PK6` … `PA9`, GPL-3.0).
///
/// -1 = el formato no guarda ese campo.
class G6Fields {
  const G6Fields._({
    required this.marking,
    required this.markingWide,
    required this.contest,
    required this.pokerus,
    required this.abilityNumber,
    required this.iv32,
    required this.htName,
    required this.htGender,
    required this.htLanguage,
    required this.currentHandler,
    required this.htFriendship,
    required this.htMemory,
    required this.otFriendship,
    required this.otMemory,
    required this.eggLocation,
    required this.hyperTrain,
    required this.battleVersion,
    required this.formArgument,
    required this.heightScalar,
    required this.tracker,
    required this.geo,
  });

  /// Marcas: byte de 6 bits (PK6) o u16 de 2 bits por marca (PK7+).
  final int marking;
  final bool markingWide;
  final int contest, pokerus, abilityNumber, iv32;
  final int htName, htGender, htLanguage, currentHandler, htFriendship;

  /// Recuerdo del último entrenador: (intensidad, recuerdo, sentimiento, variable u16).
  final (int, int, int, int)? htMemory;
  final int otFriendship;

  /// Recuerdo del entrenador original: (intensidad, recuerdo, variable u16, sentimiento).
  final (int, int, int, int)? otMemory;
  final int eggLocation, hyperTrain, battleVersion, formArgument;

  /// Escalas de altura y peso (el peso va en el byte siguiente).
  final int heightScalar;
  final int tracker;

  /// Región de la consola y geolocalizaciones (Gen 6/7): (país, región, consola, geo1).
  final (int, int, int, int)? geo;

  static const _pk6 = G6Fields._(
      marking: 0x2A, markingWide: false, contest: 0x24, pokerus: 0x2B, abilityNumber: 0x15, iv32: 0x74,
      htName: 0x78, htGender: 0x92, htLanguage: -1, currentHandler: 0x93, htFriendship: 0xA2,
      htMemory: (0xA4, 0xA5, 0xA6, 0xA8), otFriendship: 0xCA, otMemory: (0xCC, 0xCD, 0xCE, 0xD0),
      eggLocation: 0xD8, hyperTrain: -1, battleVersion: -1, formArgument: 0x3C, heightScalar: -1, tracker: -1,
      geo: (0xE0, 0xE1, 0xE2, 0x94));
  static const _pk7 = G6Fields._(
      marking: 0x16, markingWide: true, contest: 0x24, pokerus: 0x2B, abilityNumber: 0x15, iv32: 0x74,
      htName: 0x78, htGender: 0x92, htLanguage: -1, currentHandler: 0x93, htFriendship: 0xA2,
      htMemory: (0xA4, 0xA5, 0xA6, 0xA8), otFriendship: 0xCA, otMemory: (0xCC, 0xCD, 0xCE, 0xD0),
      eggLocation: 0xD8, hyperTrain: 0xDE, battleVersion: -1, formArgument: 0x3C, heightScalar: -1, tracker: -1,
      geo: (0xE0, 0xE1, 0xE2, 0x94));
  static const _pb7 = G6Fields._(
      marking: 0x16, markingWide: true, contest: -1, pokerus: 0x2B, abilityNumber: 0x15, iv32: 0x74,
      htName: 0x78, htGender: 0x92, htLanguage: -1, currentHandler: 0x93, htFriendship: 0xA2,
      htMemory: (0xA4, 0xA5, 0xA6, 0xA8), otFriendship: 0xCA, otMemory: null,
      eggLocation: 0xD8, hyperTrain: 0xDE, battleVersion: -1, formArgument: 0x3C, heightScalar: 0x3A, tracker: -1,
      geo: null);
  static const _pk8 = G6Fields._(
      marking: 0x18, markingWide: true, contest: 0x2C, pokerus: 0x32, abilityNumber: 0x16, iv32: 0x8C,
      htName: 0xA8, htGender: 0xC2, htLanguage: 0xC3, currentHandler: 0xC4, htFriendship: 0xC8,
      htMemory: (0xC9, 0xCA, 0xCB, 0xCC), otFriendship: 0x112, otMemory: (0x113, 0x114, 0x116, 0x118),
      eggLocation: 0x120, hyperTrain: 0x126, battleVersion: 0xDF, formArgument: 0xE4, heightScalar: 0x50,
      tracker: 0x135, geo: null);
  static const _pb8 = G6Fields._(
      marking: 0x18, markingWide: true, contest: 0x2C, pokerus: 0x32, abilityNumber: 0x16, iv32: 0x8C,
      htName: 0xA8, htGender: 0xC2, htLanguage: 0xC3, currentHandler: 0xC4, htFriendship: 0xC8,
      htMemory: (0xC9, 0xCA, 0xCB, 0xCC), otFriendship: 0x112, otMemory: (0x113, 0x114, 0x116, 0x118),
      eggLocation: 0x120, hyperTrain: 0x126, battleVersion: -1, formArgument: 0xE4, heightScalar: 0x50,
      tracker: 0x135, geo: null);
  static const _pa8 = G6Fields._(
      marking: 0x18, markingWide: true, contest: 0x2C, pokerus: 0x32, abilityNumber: 0x16, iv32: 0x94,
      htName: 0xB8, htGender: 0xD2, htLanguage: 0xD3, currentHandler: 0xD4, htFriendship: 0xD8,
      htMemory: (0xD9, 0xDA, 0xDB, 0xDC), otFriendship: 0x12A, otMemory: (0x12B, 0x12C, 0x12E, 0x130),
      eggLocation: 0x138, hyperTrain: 0x13E, battleVersion: 0xEF, formArgument: 0xF4, heightScalar: 0x50,
      tracker: 0x14D, geo: null);
  static const _pk9 = G6Fields._(
      marking: 0x18, markingWide: true, contest: 0x2C, pokerus: 0x32, abilityNumber: 0x16, iv32: 0x8C,
      htName: 0xA8, htGender: 0xC2, htLanguage: 0xC3, currentHandler: 0xC4, htFriendship: 0xC8,
      htMemory: (0xC9, 0xCA, 0xCB, 0xCC), otFriendship: 0x112, otMemory: (0x113, 0x114, 0x116, 0x118),
      eggLocation: 0x120, hyperTrain: 0x126, battleVersion: 0xCF, formArgument: 0xD0, heightScalar: 0x48,
      tracker: 0x127, geo: null);

  static G6Fields of(PkFormat f) => switch (f) {
        PkFormat.pk6 => _pk6,
        PkFormat.pk7 => _pk7,
        PkFormat.pb7 => _pb7,
        PkFormat.pk8 => _pk8,
        PkFormat.pb8 => _pb8,
        PkFormat.pa8 => _pa8,
        PkFormat.pk9 || PkFormat.pa9 => _pk9,
        _ => throw ArgumentError('${f.extension} no es Gen 6+'),
      };

  int get htNameLength => htName == 0x78 ? 24 : 26;
}

/// Lectura y escritura de esos campos sobre un [Pkm] de Gen 6+.
extension G6FieldAccess on Pkm {
  G6Fields get g6 => G6Fields.of(format);

  int get markingValue => g6.markingWide ? data.u16le(g6.marking) : data[g6.marking];
  set markingValue(int v) => g6.markingWide ? data.setU16le(g6.marking, v & 0xFFFF) : data[g6.marking] = v & 0xFF;

  List<int> get contestStats => g6.contest < 0 ? const [0, 0, 0, 0, 0, 0] : data.sublist(g6.contest, g6.contest + 6);
  set contestStats(List<int> v) {
    if (g6.contest >= 0) data.setRange(g6.contest, g6.contest + 6, v);
  }

  int get pokerus => data[g6.pokerus];
  set pokerus(int v) => data[g6.pokerus] = v;

  int get abilityNumber => data[g6.abilityNumber] & 7;
  set abilityNumber(int v) => data[g6.abilityNumber] = (data[g6.abilityNumber] & ~7) | (v & 7);

  set abilityId(int v) => format.generation >= 8 ? data.setU16le(0x14, v) : data[0x14] = v;

  int get iv32Raw => data.u32le(g6.iv32);
  set iv32Raw(int v) => data.setU32le(g6.iv32, v & 0xFFFFFFFF);

  set nicknamedFlag(bool v) => iv32Raw = (iv32Raw & 0x7FFFFFFF) | (v ? 0x80000000 : 0);

  String get htName => StringCodec.decodeUtf16(data, g6.htName, g6.htNameLength);
  set htName(String v) =>
      data.setRange(g6.htName, g6.htName + g6.htNameLength, StringCodec.encodeUtf16(v.characters(12), g6.htNameLength));

  int get htGender => data[g6.htGender];
  set htGender(int v) => data[g6.htGender] = v;
  int get htLanguage => g6.htLanguage < 0 ? 0 : data[g6.htLanguage];
  set htLanguage(int v) {
    if (g6.htLanguage >= 0) data[g6.htLanguage] = v;
  }

  int get currentHandler => data[g6.currentHandler];
  set currentHandler(int v) => data[g6.currentHandler] = v;
  int get htFriendship => data[g6.htFriendship];
  set htFriendship(int v) => data[g6.htFriendship] = v;
  int get otFriendship => data[g6.otFriendship];
  set otFriendship(int v) => data[g6.otFriendship] = v;

  /// (intensidad, recuerdo, sentimiento, variable).
  (int, int, int, int) get htMemory {
    final m = g6.htMemory;
    if (m == null) return (0, 0, 0, 0);
    return (data[m.$1], data[m.$2], data[m.$3], data.u16le(m.$4));
  }

  set htMemory((int, int, int, int) v) {
    final m = g6.htMemory;
    if (m == null) return;
    data[m.$1] = v.$1;
    data[m.$2] = v.$2;
    data[m.$3] = v.$3;
    data.setU16le(m.$4, v.$4);
  }

  /// (intensidad, recuerdo, sentimiento, variable).
  (int, int, int, int) get otMemory {
    final m = g6.otMemory;
    if (m == null) return (0, 0, 0, 0);
    return (data[m.$1], data[m.$2], data[m.$4], data.u16le(m.$3));
  }

  set otMemory((int, int, int, int) v) {
    final m = g6.otMemory;
    if (m == null) return;
    data[m.$1] = v.$1;
    data[m.$2] = v.$2;
    data[m.$4] = v.$3;
    data.setU16le(m.$3, v.$4);
  }

  int get eggLocation => data.u16le(g6.eggLocation);
  set eggLocation(int v) => data.setU16le(g6.eggLocation, v);

  int get hyperTrainFlags => g6.hyperTrain < 0 ? 0 : data[g6.hyperTrain];
  set hyperTrainFlags(int v) {
    if (g6.hyperTrain >= 0) data[g6.hyperTrain] = v;
  }

  int get battleVersion => g6.battleVersion < 0 ? 0 : data[g6.battleVersion];
  set battleVersion(int v) {
    if (g6.battleVersion >= 0) data[g6.battleVersion] = v;
  }

  int get formArgument => data.u32le(g6.formArgument);
  set formArgument(int v) => data.setU32le(g6.formArgument, v);

  int get heightScalar => g6.heightScalar < 0 ? 0 : data[g6.heightScalar];
  set heightScalar(int v) {
    if (g6.heightScalar >= 0) data[g6.heightScalar] = v;
  }

  int get weightScalar => g6.heightScalar < 0 ? 0 : data[g6.heightScalar + 1];
  set weightScalar(int v) {
    if (g6.heightScalar >= 0) data[g6.heightScalar + 1] = v;
  }

  /// Escala de SV/Z-A/Leyendas Arceus (PK9/PA9: 0x4A; PA8: 0x52).
  int get scale => switch (format) {
        PkFormat.pk9 || PkFormat.pa9 => data[0x4A],
        PkFormat.pa8 => data[0x52],
        _ => 0,
      };
  set scale(int v) {
    if (format == PkFormat.pk9 || format == PkFormat.pa9) data[0x4A] = v;
    if (format == PkFormat.pa8) data[0x52] = v;
  }

  int get tracker {
    final o = g6.tracker;
    if (o < 0) return 0;
    var v = 0;
    for (var i = 7; i >= 0; i--) {
      v = (v << 8) | data[o + i];
    }
    return v;
  }

  set tracker(int v) {
    final o = g6.tracker;
    if (o < 0) return;
    for (var i = 0; i < 8; i++) {
      data[o + i] = (v >> (8 * i)) & 0xFF;
    }
  }

  Uint8List nicknameTrash() => data.sublist(_nickOfsG6, _nickOfsG6 + 26);
  int get _nickOfsG6 => switch (format) {
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => 0x40,
        PkFormat.pa8 => 0x60,
        _ => 0x58,
      };

  /// Fija el apodo tal cual (sin tocar la marca de apodado).
  void setNicknameRaw(String v) {
    final len = (format == PkFormat.pk6 || format == PkFormat.pk7 || format == PkFormat.pb7) ? 24 : 26;
    data.setRange(_nickOfsG6, _nickOfsG6 + len, Uint8List(len));
    data.setRange(_nickOfsG6, _nickOfsG6 + len, StringCodec.encodeUtf16(v.characters(12), len));
  }
}

/// Nombres de especie por idioma de las tablas de PKHeX.
abstract final class TransferNames {
  static final Map<String, List<String>> _cache = {};

  static List<String> _list(String table, Map<int, String> src, int language) =>
      _cache.putIfAbsent('$table:$language', () => (src[language] ?? src[2]!).split('|'));

  static String _get(String table, Map<int, String> src, int species, int language) {
    final l = _list(table, src, language == 6 || language == 11 || language == 0 ? (language == 11 ? 7 : 2) : language);
    return species < l.length ? l[species] : '';
  }

  /// Nombre que pone el juego de Gen 4 (mayúsculas en idiomas latinos).
  static String gen4(int species, int language) => _get('g4', kTransferNamesG4, species, language);

  /// Nombre de Gen 6 (Poké Transfer → X/Y).
  static String gen6(int species, int language) => _get('g6', kTransferNamesG6, species, language);

  /// Nombre de Gen 7 (Poké Transporter, Consola Virtual).
  static String gen7(int species, int language) => _get('g7', kTransferNamesG7, species, language);

  /// Nombre que pone HOME al importar.
  static String home(int species, int language) {
    final n = _get('home', kTransferNamesHome, species, language);
    return n.isEmpty ? Species.name(species, SpeciesLanguage.en) : n;
  }

  /// Idioma cuyo nombre de especie (Gen 5) coincide con [nickname]; 0 si ninguno.
  static int languageOf(int species, String nickname) {
    for (final l in const [1, 2, 3, 4, 5, 7, 8, 9, 10]) {
      if (gen6(species, l) == nickname || gen4(species, l) == nickname) return l;
    }
    return 0;
  }
}

/// Amistad base (USUM) de la especie.
int baseFriendship(int species) =>
    species < kBaseFriendshipSM.length ? kBaseFriendshipSM[species] : 70;

extension on String {
  String characters(int max) {
    final runes = this.runes.toList();
    return runes.length <= max ? this : String.fromCharCodes(runes.take(max));
  }
}
