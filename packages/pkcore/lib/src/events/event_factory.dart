import 'dart:math';
import 'dart:typed_data';

import '../edit/save_editor.dart';
import '../legal/origin.dart';
import '../model/game.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import '../strings/string_codec.dart';
import '../util/bytes.dart';
import 'event_db.dart';

/// Crea Pokémon de evento como los entregaría el juego al recibir la tarjeta.
///
/// Parte de la plantilla que generó PKHeX (`ConvertToPKM`, validada con
/// `LegalityAnalysis`) y aplica lo que depende de quien lo recibe: nombre, ID y
/// género del entrenador cuando el evento los toma del receptor, idioma (OT y
/// apodo por idioma de la tarjeta), versión de origen, fecha de recepción y la
/// regla de variocolor. El PID/IV sale de una de las variantes legales que
/// exportó PKHeX, así que en Gen 3–4 conserva su método RNG (BACD, Method 1…).
abstract final class EventFactory {
  /// Placeholder del entrenador de prueba con el que PKHeX generó la plantilla.
  static const _placeholder = 'ARKA';

  /// `true` si [gift] se puede crear en una partida de [game].
  static bool canCreateIn(EventGift gift, GameVersion game) =>
      gift.canCreate && !game.isStorage && !game.isColosseumOrXd && gift.format == PkFormat.forGame(game);

  /// Idioma con el que se crearía en una partida en [saveLanguage]: el mismo si
  /// el evento se distribuyó en ese idioma, si no el de la plantilla.
  static int languageFor(EventGift gift, int saveLanguage) =>
      gift.trainerLanguages.contains(saveLanguage) ? saveLanguage : gift.templateLanguage;

  /// `true` si el Pokémon creado podría ser variocolor (o el evento lo es siempre).
  static bool canBeShiny(EventGift gift) {
    if (gift.shiny.isShiny) return true;
    if (gift.isEgg) return false; // el PID se decide al recibirlo y al eclosionar
    if (gift.shiny != EventShiny.random) return false;
    // Gen 3–4: PID ligado a los IV por el RNG; solo si alguna variante legal lo es.
    return (gift.format?.generation ?? 0) >= 5;
  }

  /// Crea el Pokémon de [gift] para el entrenador [trainer] de [game].
  ///
  /// [language]: idioma de la partida (ids de PKHeX; 2 inglés, 7 español…).
  /// [versionId]: versión concreta del save (p. ej. Espada = 44), si se conoce.
  /// [shiny]: solo en eventos de PID al azar (null = como salga).
  static Pkm create(EventGift gift, GameVersion game, TrainerData trainer,
      {int language = 2, int? versionId, bool? shiny, DateTime? today, Random? random}) {
    final rnd = random ?? Random();
    final pk = gift.template(game);
    if (pk == null || !canCreateIn(gift, game)) {
      throw ArgumentError('El evento ${gift.cardId} no se puede crear en ${game.nameEs}');
    }
    final f = pk.format;
    final lang = languageFor(gift, language);

    // 1) Entrenador que lo recibe.
    if (gift.recipientId) {
      pk.tid = trainer.tid;
      pk.sid = trainer.sid;
    }
    if (gift.recipientGender) pk.otGender = trainer.gender ?? 0;
    final nick = gift.nicknameByLanguage[lang];
    if (nick != null) pk.language = nick.$1;
    if (gift.recipientOt) {
      pk.otName = trainer.name;
    } else if (gift.otByLanguage[lang] case final ot?) {
      pk.otName = ot;
    }
    if (nick != null && pk.isEgg) {
      pk.nickname = nick.$3; // «Huevo», «Egg»… en el idioma del Pokémon
    } else if (nick != null) {
      if (nick.$2) {
        pk.setNickname(nick.$3);
      } else {
        pk.setDefaultNickname();
      }
    }
    _setHandler(pk, trainer, lang);

    // 2) PID/IV: una variante legal que cumpla la regla de variocolor con el ID final.
    _applyVariant(pk, gift, shiny, rnd);

    // 3) Versión de origen y fecha de recepción.
    final v = versionId;
    if (v != null && gift.versions.contains(v)) pk.version = v;
    if (gift.metToday && pk.hasDates && !pk.isEgg) {
      final d = today ?? DateTime.now();
      pk.metDate = DateTime(d.year, d.month, d.day);
    }
    pk.dataGame = game;
    if (!f.isGameBoy) pk.refreshPartyStats();
    if (f == PkFormat.pb7) resetCp(pk);
    pk.refreshChecksum();
    return pk;
  }

  /// Let's Go: recalcula los PC guardados (PKHeX `PB7.ResetCP`), que dependen
  /// de IV, naturaleza, nivel, amistad y valores de esfuerzo (AV).
  static void resetCp(Pkm pk) {
    if (pk.format != PkFormat.pb7) return;
    final stats = pk.computeStats();
    if (stats == null) return;
    final av = pk.avs;
    final level = pk.level;
    var sum = 0;
    for (var i = 0; i < 6; i++) {
      sum += (stats[i] - av[i]) & 0xFFFF;
    }
    final f = Float32List(1);
    f[0] = sum * 6.0;
    f[0] = f[0] * level;
    f[0] = f[0] / 100.0;
    final base = f[0].toInt();
    final avSum = av.fold(0, (a, b) => a + b);
    var awake = 0;
    if (avSum != 0) {
      f[0] = level * 4.0;
      f[0] = f[0] / 100.0;
      f[0] = f[0] + 2.0;
      f[0] = avSum * f[0];
      awake = f[0].toInt();
    }
    pk.data.setU16le(0xFE, min(10000, base + awake));
  }

  // ------------------------------------------------------------ entrenador actual

  /// Offsets (nombre, longitud en bytes, género, idioma) del último entrenador (Gen 6+).
  static (int, int, int, int)? _handlerOfs(PkFormat f) => switch (f) {
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => (0x78, 0x18, 0x92, -1),
        PkFormat.pa8 => (0xB8, 0x1A, 0xD2, 0xD3),
        PkFormat.pk8 || PkFormat.pb8 || PkFormat.pk9 || PkFormat.pa9 => (0xA8, 0x1A, 0xC2, 0xC3),
        _ => null,
      };

  /// Regalos de HOME: el último entrenador es quien lo recibe (en la plantilla, el de prueba).
  static void _setHandler(Pkm pk, TrainerData trainer, int lang) {
    final o = _handlerOfs(pk.format);
    if (o == null) return;
    final (ofs, len, gender, language) = o;
    if (StringCodec.decodeUtf16(pk.data, ofs, len) != _placeholder) return;
    final name = trainer.name.characters(pk.format.maxTrainerNameLength);
    pk.data.setRange(ofs, ofs + len, StringCodec.encodeUtf16(name, len));
    pk.data[gender] = (trainer.gender ?? 0) & 1;
    if (language >= 0) pk.data[language] = lang;
  }

  // ------------------------------------------------------------ PID / IV

  static bool _shinyWith(Pkm pk, int pid) {
    final xor = (pk.tid ^ pk.sid ^ (pid >> 16) ^ (pid & 0xFFFF)) & 0xFFFF;
    return xor < (pk.format.generation <= 5 ? 8 : 16);
  }

  static void _applyVariant(Pkm pk, EventGift gift, bool? wantShiny, Random rnd) {
    final rule = gift.shiny;
    final gen = pk.format.generation;
    final options = gift.variants;
    // Gen 3–5: el PID no se puede tocar sin romper el método RNG (Gen 3–4) o el
    // bit de habilidad/género (Gen 5): se elige la variante que cumpla la regla.
    bool ok(int pid) {
      final s = _shinyWith(pk, pid);
      return switch (rule) {
        EventShiny.never => !s,
        EventShiny.always || EventShiny.alwaysStar || EventShiny.alwaysSquare => s,
        EventShiny.random => wantShiny == null || wantShiny == s,
        EventShiny.fixed => true,
      };
    }

    final good = [for (final v in options) if (ok(v.pid)) v];
    final pick = good.isNotEmpty ? good[rnd.nextInt(good.length)] : (options.isEmpty ? null : options[rnd.nextInt(options.length)]);
    final templateOk = ok(pk.pid);
    if (pick != null && (good.isNotEmpty || !templateOk)) _setVariant(pk, pick);

    if (gen >= 6) {
      // PID independiente de los IV: se ajusta como el juego (PKHeX `GetPID`).
      switch (rule) {
        case EventShiny.never:
          if (pk.isShiny) pk.pid = pk.pid ^ 0x10000000;
        case EventShiny.random:
          if (wantShiny != null && wantShiny != pk.isShiny) pk.setShiny(wantShiny, random: rnd);
        case EventShiny.always:
          if (!pk.isShiny) pk.setShiny(true, square: gen >= 8, random: rnd);
        case EventShiny.alwaysStar:
          if (!pk.isShiny || pk.isSquareShiny) pk.setShiny(true, random: rnd);
        case EventShiny.alwaysSquare:
          if (!pk.isSquareShiny) pk.setShiny(true, square: true, random: rnd);
        case EventShiny.fixed:
          break;
      }
    } else if (gen == 5 && !ok(pk.pid)) {
      // PGF: PID al azar con el bit de habilidad y el género conservados.
      pk.setShiny(rule.isShiny || (wantShiny ?? false), random: rnd);
    }
  }

  static void _setVariant(Pkm pk, EventVariant v) {
    final f = pk.format;
    pk.pid = v.pid;
    if (f.hasEncryptionConstant) pk.encryptionConstant = v.encryptionConstant;
    pk.setIvs(v.ivs); // conserva los bits de huevo/apodo (y la habilidad en Gen 3)
    if (f.generation >= 5) pk.nature = v.nature;
    if (f.hasStatNature) pk.statNature = v.statNature;
    final slot = switch (v.abilityNumber) { 4 => 2, 2 => 1, _ => 0 };
    pk.setAbilitySlot(slot);
    // La habilidad exacta de PKHeX (especies con la misma habilidad en dos ranuras, formas).
    switch (f) {
      case PkFormat.pk3:
        break;
      case PkFormat.pk4 || PkFormat.pk5:
        pk.data[0x15] = v.ability;
      case PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7:
        pk.data[0x14] = v.ability;
      default:
        pk.data.setU16le(0x14, v.ability);
    }
    switch (f) {
      case PkFormat.pk3:
        break; // el género sale del PID
      case PkFormat.pk4 || PkFormat.pk5:
        pk.data[0x40] = (pk.data[0x40] & ~0x06) | ((v.gender & 3) << 1);
      default:
        pk.gender = v.gender;
    }
  }
}

extension on String {
  String characters(int max) => runes.length <= max ? this : String.fromCharCodes(runes.take(max));
}
