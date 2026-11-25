import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../data/generated/living_dex_data.dart';
import '../data/game_data.dart';
import '../data/species.dart';
import '../edit/save_editor.dart';
import '../edit/save_edits.dart';
import '../events/event_db.dart';
import '../events/event_factory.dart';
import '../legal/origin.dart';
import '../model/game.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import '../strings/string_codec.dart';

/// Cómo se obtuvo el Pokémon de la plantilla en su juego.
enum LivingDexSource { egg, staticEncounter, wild, event }

/// Por qué una especie/forma del juego no entra en la Living Dex.
enum LivingDexExclusion {
  /// Forma que solo existe en combate (megas, Castform clima, Darmanitan Daruma…).
  battleOnly,

  /// Fusión (Kyurem blanco/negro, Necrozma, Calyrex jinete): consume el otro legendario.
  fused,

  /// Pokémon dominante (Sol/Luna) o noble (Leyendas Arceus): no se pueden tener.
  totemOrLord,

  /// Vuelve a la forma base al dejarlo en la caja (cortes de Furfrou y Hoopa desatado en Gen 6).
  boxReverts,

  /// Forma que solo se repartió por evento (Vivillon Elegante y Poké Ball en Gen 6–7).
  eventOnlyForm,

  /// Necesita los datos de región de otra consola (dibujos de Vivillon).
  needsRegion,

  /// Sin encuentro propio en esta versión (solo por intercambio, HOME u otra versión).
  notObtainable,
}

/// Modo de re-ID que PKHeX aceptó para la plantilla (ver tools/pkhex_oracle/LivingDexTable.cs).
enum LivingDexMode {
  /// PID libre que conserva lo que el PID decide (huevos, Gen 6+, DV en Gen 1–2).
  free,

  /// Gen 3–4 Method 1: PID e IV de cuatro tiradas del LCRNG.
  method1,

  /// Correlación que pkcore no reproduce: se conserva el PID/IV de la plantilla.
  keep,
}

/// Una fila de la tabla: especie/forma de una o varias versiones (ids de PKHeX).
class LivingDexEntry {
  LivingDexEntry._(this._index, this.versions, this.species, this.form,
      {this.source, this.mode, this.shinyMode, this.shinyLocked = false, this.fateful = false, this.encounterSpecies = 0, this.level = 0, this.exclusion});

  final int _index;
  final List<int> versions;
  final int species;
  final int form;
  final LivingDexSource? source;
  final LivingDexMode? mode;

  /// Modo para el variocolor; null si no se puede generar.
  final LivingDexMode? shinyMode;

  /// Variocolor bloqueado por el propio juego (encuentro que nunca es variocolor).
  final bool shinyLocked;

  /// Encuentro del destino: exige un objeto o pase de evento (Isla Lejana, Ticket Libertad…).
  final bool fateful;
  final int encounterSpecies;
  final int level;
  final LivingDexExclusion? exclusion;

  bool get creatable => exclusion == null;
  bool get canBeShiny => shinyMode != null;

  static Uint8List _unrle(String b64) {
    final src = base64.decode(b64);
    final out = BytesBuilder(copy: false);
    for (var i = 0; i < src.length; i++) {
      if (src[i] == 0) {
        out.add(Uint8List(src[++i]));
      } else {
        out.addByte(src[i]);
      }
    }
    return out.toBytes();
  }

  /// Plantilla (Pokémon de PKHeX con el entrenador de prueba ARKA 12345/54321).
  Uint8List? get templateBytes => kLivingDexTpl[_index].isEmpty ? null : _unrle(kLivingDexTpl[_index]);
  Uint8List? get alternateBytes => kLivingDexAlt[_index].isEmpty ? null : _unrle(kLivingDexAlt[_index]);

  @override
  String toString() => '#$species-$form ${versions.join('/')} ${source?.name ?? exclusion?.name}';
}

/// Tabla de la Living Dex (generada desde PKHeX con tool/gen_living_dex_data.sh).
abstract final class LivingDexDb {
  static List<LivingDexEntry>? _all;

  static List<LivingDexEntry> get all => _all ??= [
        for (var i = 0; i < kLivingDexMeta.length; i++) _parse(i, kLivingDexMeta[i]),
      ];

  static LivingDexEntry _parse(int i, String m) {
    final p = m.split('|');
    final vs = [for (final v in p[0].split('.')) int.parse(v)];
    final s = int.parse(p[1]), f = int.parse(p[2]);
    final st = p[3];
    if (st.startsWith('!')) {
      final why = switch (st.substring(1)) {
        'battle' => LivingDexExclusion.battleOnly,
        'fused' => LivingDexExclusion.fused,
        'totem' || 'lord' => LivingDexExclusion.totemOrLord,
        'boxrevert' => LivingDexExclusion.boxReverts,
        'eventform' => LivingDexExclusion.eventOnlyForm,
        'region' => LivingDexExclusion.needsRegion,
        _ => LivingDexExclusion.notObtainable,
      };
      return LivingDexEntry._(i, vs, s, f, exclusion: why);
    }
    final q = st.split(',');
    LivingDexMode? mode(String c) => switch (c) { 'f' => LivingDexMode.free, '1' => LivingDexMode.method1, 'k' => LivingDexMode.keep, _ => null };
    return LivingDexEntry._(i, vs, s, f,
        source: switch (q[0]) { 'e' => LivingDexSource.egg, 's' => LivingDexSource.staticEncounter, _ => LivingDexSource.wild },
        mode: mode(q[1]),
        shinyMode: mode(q[2]),
        shinyLocked: q[3].contains('L'),
        fateful: q[3].contains('F'),
        encounterSpecies: int.parse(q[4]),
        level: int.parse(q[5]));
  }

  /// Versiones de origen (ids de PKHeX) de cada juego, la primera por defecto.
  static List<int> versionsOf(GameVersion game) => switch (game) {
        GameVersion.redBlue => const [35, 36],
        GameVersion.yellow => const [38],
        GameVersion.goldSilver => const [39, 40],
        GameVersion.crystal => const [41],
        GameVersion.rubySapphire => const [2, 1],
        GameVersion.emerald => const [3],
        GameVersion.fireRedLeafGreen => const [4, 5],
        GameVersion.diamondPearl => const [10, 11],
        GameVersion.platinum => const [12],
        GameVersion.heartGoldSoulSilver => const [7, 8],
        GameVersion.blackWhite => const [21, 20],
        GameVersion.black2White2 => const [23, 22],
        GameVersion.xy => const [24, 25],
        GameVersion.omegaRubyAlphaSapphire => const [27, 26],
        GameVersion.sunMoon => const [30, 31],
        GameVersion.ultraSunUltraMoon => const [32, 33],
        GameVersion.letsGo => const [42, 43],
        GameVersion.swordShield => const [44, 45],
        GameVersion.brilliantDiamondShiningPearl => const [48, 49],
        GameVersion.legendsArceus => const [47],
        GameVersion.scarletViolet => const [50, 51],
        GameVersion.legendsZA => const [52],
        _ => const [],
      };

  /// `true` si se puede generar una Living Dex en partidas de [game].
  static bool supports(GameVersion game) => versionsOf(game).isNotEmpty;

  /// Versión de origen para el save: la suya si se conoce, si no la primera del juego.
  static int? versionFor(GameVersion game, int? versionId) {
    final vs = versionsOf(game);
    if (vs.isEmpty) return null;
    return versionId != null && vs.contains(versionId) ? versionId : vs.first;
  }

  static Set<int>? _obtainable;

  /// `true` si la especie solo se pudo obtener en eventos o repartos oficiales (ya
  /// terminados): ningún juego tiene un encuentro propio que no exija un objeto de evento.
  static bool eventOnly(int species) {
    if (!isLegendaryOrMythical(species)) return false;
    final ok = _obtainable ??= {for (final e in all) if (e.creatable && !e.fateful) e.species};
    return !ok.contains(species);
  }

  /// Filas de [version], en orden de la Pokédex nacional y de forma.
  static List<LivingDexEntry> forVersion(int version) =>
      [for (final e in all) if (e.versions.contains(version)) e]..sort((a, b) => a.species != b.species ? a.species - b.species : a.form - b.form);
}

/// Un hueco de la Living Dex: la especie/forma y de dónde sale.
class LivingDexSlot {
  const LivingDexSlot(this.species, this.form, {this.entry, this.gift});
  final int species;
  final int form;
  final LivingDexEntry? entry;

  /// Evento oficial (míticos/legendarios que solo se obtuvieron así).
  final EventGift? gift;

  LivingDexSource get source => gift != null ? LivingDexSource.event : entry!.source!;

  /// `true` si se puede crear variocolor.
  bool get canBeShiny => gift != null ? EventFactory.canBeShiny(gift!) : entry!.canBeShiny;

  /// El juego (o el evento) nunca lo da variocolor.
  bool get shinyLocked => gift != null ? !EventFactory.canBeShiny(gift!) : entry!.shinyLocked;
}

/// Lo que se generará en una partida: huecos en orden, capacidad y lo que queda fuera.
class LivingDexPlan {
  LivingDexPlan(this.game, this.version, this.slots, this.excluded, this.capacity);
  final GameVersion game;
  final int version;
  final List<LivingDexSlot> slots;
  final List<LivingDexEntry> excluded;

  /// Huecos de caja del save.
  final int capacity;

  bool get fits => slots.length <= capacity;
  int get boxesNeeded => slots.length;
  Iterable<LivingDexEntry> excludedBy(LivingDexExclusion why) => excluded.where((e) => e.exclusion == why);
  int get eventCount => slots.where((s) => s.gift != null).length;
  int shinyImpossibleCount() => slots.where((s) => !s.canBeShiny).length;
}

/// Resultado de escribir la Living Dex en el save.
class LivingDexResult {
  const LivingDexResult(this.written, this.shiny, this.normalInsteadOfShiny, this.left);
  final int written;
  final int shiny;

  /// Pedidos variocolor que quedaron normales (variocolor imposible).
  final List<LivingDexSlot> normalInsteadOfShiny;

  /// Los que no cupieron en las cajas.
  final List<LivingDexSlot> left;
}

/// Legendarios y míticos (Pokédex nacional): los únicos que la Living Dex toma de un evento.
bool isLegendaryOrMythical(int s) =>
    const {144, 145, 146, 150, 151, 243, 244, 245, 249, 250, 251, 638, 639, 640, 641, 642, 643, 644, 645, 646, 647, 648, 649,
      716, 717, 718, 719, 720, 721, 772, 773, 789, 790, 791, 792, 800, 801, 802, 807, 808, 809, 888, 889, 890, 891, 892, 893,
      894, 895, 896, 897, 898, 905, 1001, 1002, 1003, 1004, 1007, 1008, 1014, 1015, 1016, 1017, 1024, 1025}.contains(s) ||
    (s >= 377 && s <= 386) || (s >= 480 && s <= 494) || (s >= 785 && s <= 788) || (s >= 793 && s <= 799) || (s >= 803 && s <= 806);

/// Motivo por el que algo no quedó (o no quedó como se pidió) en la Living Dex.
enum LivingDexMissingReason {
  /// Formas que solo existen en combate.
  battleOnly,

  /// Fusiones, dominantes y nobles.
  fusedOrTotem,

  /// Formas que vuelven a la base en la caja.
  boxReverts,

  /// Solo por evento (míticos sin evento creable aquí, formas de evento).
  eventOnly,

  /// Necesita la región de otra consola.
  needsRegion,

  /// Sin encuentro propio en esta versión (otra versión, intercambio o HOME).
  notObtainable,

  /// Pedido variocolor que quedó normal.
  shinyImpossible,

  /// No cupo en las cajas.
  doesNotFit,
}

/// Todo lo que no se generó (o se generó normal en vez de variocolor), agrupado por motivo.
Map<LivingDexMissingReason, List<(int species, int form)>> livingDexMissing(LivingDexPlan plan, LivingDexResult result) {
  final out = <LivingDexMissingReason, List<(int, int)>>{};
  void add(LivingDexMissingReason r, int s, int f) => (out[r] ??= []).add((s, f));
  for (final e in plan.excluded) {
    final r = switch (e.exclusion!) {
      LivingDexExclusion.battleOnly => LivingDexMissingReason.battleOnly,
      LivingDexExclusion.fused || LivingDexExclusion.totemOrLord => LivingDexMissingReason.fusedOrTotem,
      LivingDexExclusion.boxReverts => LivingDexMissingReason.boxReverts,
      LivingDexExclusion.eventOnlyForm => LivingDexMissingReason.eventOnly,
      LivingDexExclusion.needsRegion => LivingDexMissingReason.needsRegion,
      LivingDexExclusion.notObtainable =>
        LivingDexDb.eventOnly(e.species) ? LivingDexMissingReason.eventOnly : LivingDexMissingReason.notObtainable,
    };
    add(r, e.species, e.form);
  }
  for (final s in result.normalInsteadOfShiny) {
    add(LivingDexMissingReason.shinyImpossible, s.species, s.form);
  }
  for (final s in result.left) {
    add(LivingDexMissingReason.doesNotFit, s.species, s.form);
  }
  return out;
}

/// Pokémon generados y el edit que los coloca en las cajas.
class LivingDexBatch {
  const LivingDexBatch(this.pokemon, this.result);
  final List<Pkm> pokemon;
  final LivingDexResult result;
  FillBoxesEdit edit({String? label}) => FillBoxesEdit(pokemon, label: label ?? 'Living Dex');
}

/// Genera la Living Dex de una partida (ver docs/usuario/living-dex.md).
abstract final class LivingDex {
  /// Plan para el save de [editor]: especies/formas del juego con encuentro
  /// propio en su versión (o un evento oficial si solo existieron así).
  static LivingDexPlan plan(SaveEditor editor) {
    final game = editor.game;
    final v = LivingDexDb.versionFor(game, editor.versionId);
    if (v == null) throw ArgumentError('Living Dex no disponible en ${game.nameEs}');
    final slots = <LivingDexSlot>[];
    final excluded = <LivingDexEntry>[];
    final gifts = EventDb.creatableIn(game);
    for (final e in LivingDexDb.forVersion(v)) {
      if (e.creatable) {
        slots.add(LivingDexSlot(e.species, e.form, entry: e));
        continue;
      }
      if (e.exclusion == LivingDexExclusion.notObtainable) {
        final g = _eventFor(gifts, e.species, e.form, game);
        if (g != null) {
          slots.add(LivingDexSlot(e.species, e.form, gift: g));
          continue;
        }
      }
      excluded.add(e);
    }
    return LivingDexPlan(game, v, slots, excluded, editor.boxCount * editor.boxSlotCount);
  }

  /// Solo míticos o legendarios que el juego no da de otra forma; un evento no huevo
  /// y, si lo hay, uno que admita variocolor.
  static EventGift? _eventFor(List<EventGift> gifts, int species, int form, GameVersion game) {
    if (!isLegendaryOrMythical(species)) return null;
    // Let's Go: Mew y Meltan llegan por Poké Ball Plus / GO con una ventana de fecha local
    // que PKHeX no acepta para un regalo recibido hoy.
    if (game == GameVersion.letsGo) return null;
    final c = [for (final g in gifts) if (g.species == species && g.form == form && !g.isEgg && EventFactory.canCreateIn(g, game)) g];
    if (c.isEmpty) return null;
    c.sort((a, b) => (EventFactory.canBeShiny(b) ? 1 : 0) - (EventFactory.canBeShiny(a) ? 1 : 0));
    return c.first;
  }

  /// Crea los Pokémon de [plan] para el entrenador del save (hasta llenar las cajas).
  static LivingDexBatch generate(SaveEditor editor, LivingDexPlan plan,
      {bool shiny = false, int? language, DateTime? today, Random? random}) {
    final rnd = random ?? Random();
    final trainer = editor.readTrainer();
    final lang = language ?? guessSaveLanguage(editor);
    var free = 0;
    for (var b = 0; b < editor.boxCount; b++) {
      for (var s = 0; s < editor.boxSlotCount; s++) {
        if (!editor.isSlotLocked(SlotRef.box(b, s))) free++;
      }
    }
    final mons = <Pkm>[];
    var shinyCount = 0;
    final normal = <LivingDexSlot>[];
    for (final slot in plan.slots) {
      if (mons.length >= free) break;
      final wantShiny = shiny && slot.canBeShiny;
      if (shiny && !slot.canBeShiny) normal.add(slot);
      final pk = create(slot, editor.game, trainer,
          version: plan.version, language: lang, shiny: wantShiny, today: today, random: rnd);
      mons.add(pk);
      if (pk.isShiny) shinyCount++;
    }
    final n = mons.length;
    return LivingDexBatch(mons, LivingDexResult(n, shinyCount, normal, plan.slots.sublist(min(n, plan.slots.length))));
  }

  /// Sobrescribe las cajas de [editor] con la Living Dex de [plan] (el equipo no se toca).
  static LivingDexResult apply(SaveEditor editor, LivingDexPlan plan,
      {bool shiny = false, int? language, DateTime? today, Random? random}) {
    final batch = generate(editor, plan, shiny: shiny, language: language, today: today, random: random);
    batch.edit().applyTo(editor);
    return batch.result;
  }

  /// Crea el Pokémon de [slot] para [trainer].
  static Pkm create(LivingDexSlot slot, GameVersion game, TrainerData trainer,
      {required int version, int language = 2, bool shiny = false, DateTime? today, Random? random}) {
    final rnd = random ?? Random();
    if (slot.gift != null) {
      return EventFactory.create(slot.gift!, game, trainer,
          language: language, versionId: version, shiny: shiny && EventFactory.canBeShiny(slot.gift!) ? true : null, today: today, random: rnd);
    }
    return LivingDexFactory.create(slot.entry!, game, trainer,
        version: version, language: language, shiny: shiny, today: today, random: rnd);
  }
}

/// Re-ID de las plantillas de PKHeX con el entrenador del save.
abstract final class LivingDexFactory {
  static const _tid0 = 12345, _sid0 = 54321;

  static Pkm _decode(Uint8List bytes, PkFormat f, GameVersion game, TrainerData trainer, int language) {
    if (f.isGameBoy) {
      final pk = Pkm.fromGb(f, bytes, nickname: '', otName: trainer.name);
      pk.dataGame = game;
      pk.setDefaultNickname();
      return pk;
    }
    return Pkm.fromDecrypted(f, bytes)..dataGame = game;
  }

  static Pkm create(LivingDexEntry e, GameVersion game, TrainerData trainer,
      {required int version, int language = 2, bool shiny = false, DateTime? today, Random? random}) {
    final rnd = random ?? Random();
    final f = PkFormat.forGame(game);
    final tpl = e.templateBytes;
    if (tpl == null) throw ArgumentError('Sin plantilla: $e');
    var pk = _decode(tpl, f, game, trainer, language);
    final pid0 = pk.pid;

    // 1) Entrenador del save.
    _reId(pk, trainer, language, version);

    // 2) PID / IV según el modo.
    final wantShiny = shiny && e.shinyMode != null;
    final mode = wantShiny ? e.shinyMode! : e.mode!;
    if (f.isGameBoy) {
      if (wantShiny) _shinyDvs(pk, rnd);
    } else if (mode == LivingDexMode.free) {
      _rerollFree(pk, pid0, wantShiny, rnd);
    } else if (mode == LivingDexMode.method1) {
      _rerollMethod1(pk, pid0, e.encounterSpecies, game, wantShiny, rnd);
    } else if (pk.isShiny) {
      // keep: la plantilla sería variocolor con el ID del save; se usa la alternativa.
      final alt = e.alternateBytes;
      if (alt != null) {
        pk = _decode(alt, f, game, trainer, language);
        _reId(pk, trainer, language, version);
      }
    }

    // 3) Fecha de encuentro: hoy (la del huevo, si la hay, es anterior).
    if (pk.hasDates && pk.metDate != null && !pk.isEgg) {
      final d = today ?? DateTime.now();
      final t = DateTime(d.year, d.month, d.day);
      if (!t.isBefore(pk.metDate!)) pk.metDate = t;
    }
    if (!f.isGameBoy) pk.refreshPartyStats();
    if (f == PkFormat.pb7) EventFactory.resetCp(pk);
    pk.refreshChecksum();
    return pk;
  }

  static void _reId(Pkm pk, TrainerData trainer, int language, int version) {
    pk.tid = trainer.tid;
    pk.sid = trainer.sid;
    if (!pk.format.isGameBoy) {
      final lang0 = pk.language;
      final name0 = pk.isNicknamed ? null : _defaultName(pk);
      pk.language = language;
      pk.otGender = trainer.gender ?? 0;
      pk.version = version;
      // Mismo nombre de especie en los dos idiomas: se conserva el de PKHeX (Nidoran♀,
      // Farfetch’d… con los caracteres exactos del juego); si no, el del idioma del save.
      if (name0 != null && (lang0 == language || _defaultName(pk) != name0)) {
        if (lang0 != language) pk.setDefaultNickname();
      }
      _setHandler(pk, trainer, language);
    }
    pk.otName = trainer.name;
  }

  static String _defaultName(Pkm pk) {
    final sl = pk.language == 7 ? SpeciesLanguage.es : (pk.language == 1 ? SpeciesLanguage.ja : SpeciesLanguage.en);
    return Species.name(pk.species, sl);
  }

  /// Offsets (nombre, longitud, género, idioma) del último entrenador (Gen 6+), como `EventFactory`.
  static (int, int, int, int)? _handlerOfs(PkFormat f) => switch (f) {
        PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => (0x78, 0x18, 0x92, -1),
        PkFormat.pa8 => (0xB8, 0x1A, 0xD2, 0xD3),
        PkFormat.pk8 || PkFormat.pb8 || PkFormat.pk9 || PkFormat.pa9 => (0xA8, 0x1A, 0xC2, 0xC3),
        _ => null,
      };

  /// Regalos que el juego entrega con el receptor como último entrenador (Koraidon…):
  /// en la plantilla es el de prueba ARKA.
  static void _setHandler(Pkm pk, TrainerData trainer, int lang) {
    final o = _handlerOfs(pk.format);
    if (o == null) return;
    final (ofs, len, gender, language) = o;
    final ht = StringCodec.decodeUtf16(pk.data, ofs, len);
    // Sin último entrenador pero con su idioma (regalos de Escarlata/Púrpura): el del save.
    if (ht.isEmpty && language >= 0 && pk.data[language] != 0) pk.data[language] = lang;
    if (ht != 'ARKA') return;
    final max = pk.format.maxTrainerNameLength;
    final name = trainer.name.runes.length <= max ? trainer.name : String.fromCharCodes(trainer.name.runes.take(max));
    pk.data.setRange(ofs, ofs + len, StringCodec.encodeUtf16(name, len));
    pk.data[gender] = (trainer.gender ?? 0) & 1;
    if (language >= 0) pk.data[language] = lang;
  }

  static bool _isShinyPid(int tid, int sid, int pid, int threshold) =>
      ((tid ^ sid ^ (pid >> 16) ^ (pid & 0xFFFF)) & 0xFFFF) < threshold;

  static bool _bit15Line(int s) => (s >= 29 && s <= 34) || s == 313 || s == 314;
  static bool _wurmpleLine(int s) => s >= 265 && s <= 269;
  static int _wurmpleEvo(int ec) => ((ec >> 16) & 0xFFFF) % 10 ~/ 5;

  /// Letra de Unown en Gen 3 (PKHeX `EntityPID.GetUnownForm3`).
  static int _unown3(int pid) {
    final v = ((pid >> 24) & 3) << 6 | ((pid >> 16) & 3) << 4 | ((pid >> 8) & 3) << 2 | (pid & 3);
    return v % 28;
  }

  /// Forma como la cuenta la Living Dex: en Gen 2–3 la letra de Unown sale de los DV / del PID.
  static int formOf(Pkm pk) {
    if (pk.species != 201) return pk.form;
    if (pk.format == PkFormat.pk3) return _unown3(pk.pid);
    if (pk.format == PkFormat.pk2) return _unown2(pk);
    return pk.form;
  }

  /// Letra de Unown en Gen 2 (bits 1–2 de cada DV salvo PS).
  static int _unown2(Pkm pk) {
    final iv = pk.ivs; // PS, Atq, Def, AtqE, DefE, Vel
    final atk = iv[1], def = iv[2], spe = iv[5], spc = iv[3];
    return (((atk & 6) << 5) | ((def & 6) << 3) | ((spe & 6) << 1) | ((spc & 6) >> 1)) ~/ 10;
  }

  static int _g5Xor(int pid, int tid, int sid) => ((tid ^ sid) & 1) ^ (pid & 1) ^ ((pid >> 31) & 1);

  /// Gen 1–2: DV variocolor (Def/Vel/Esp 10) conservando género (DV de ataque) y letra de Unown.
  static void _shinyDvs(Pkm pk, Random rnd) {
    final ivs = pk.ivs;
    final gender = pk.gender;
    final form = formOf(pk);
    const atks = [2, 3, 6, 7, 10, 11, 14, 15];
    for (final a in [...atks]..shuffle(rnd)) {
      pk.setIvs([0, a, 10, 10, 10, 10]);
      if (pk.format == PkFormat.pk2 && (pk.gender != gender || formOf(pk) != form)) continue;
      return;
    }
    // Ninguna combinación (Unown que no sea I/V): queda normal.
    pk.setIvs(ivs);
  }

  /// PID nuevo que conserva lo que decide el PID (ver `RerollFree` del oráculo).
  static void _rerollFree(Pkm pk, int pid0, bool shiny, Random rnd) {
    final gen = pk.format.generation;
    final tid = pk.tid, sid = pk.sid;
    final thr = gen <= 5 ? 8 : 16;
    if (gen >= 6) {
      final lo = pk.pid & 0xFFFF;
      if (shiny) {
        final x = gen >= 8 ? 1 + rnd.nextInt(15) : rnd.nextInt(16);
        pk.pid = (((tid ^ sid ^ lo ^ x) & 0xFFFF) << 16) | lo;
      } else if (_isShinyPid(tid, sid, pk.pid, thr)) {
        pk.pid = pk.pid ^ 0x10000000;
      }
      return;
    }
    final species = pk.species;
    final tsv = (tid ^ sid) & 0xFFFF;
    for (var k = 0; k < 4000000; k++) {
      final hi = rnd.nextInt(0x10000);
      final lo = shiny ? (hi ^ tsv ^ rnd.nextInt(thr)) & 0xFFFF : rnd.nextInt(0x10000);
      final pid = (hi << 16) | lo;
      if (_isShinyPid(tid, sid, pid, thr) != shiny) continue;
      if ((pid & 0xFF) != (pid0 & 0xFF)) continue;
      if (shiny && lo < 0x100) continue;
      if (gen <= 4 && pid % 25 != pid0 % 25) continue;
      if (gen == 5 && ((pid >> 16) & 1) != ((pid0 >> 16) & 1)) continue;
      if (gen == 5 && _g5Xor(pid0, _tid0, _sid0) == 0 && _g5Xor(pid, tid, sid) != 0) continue;
      if (_bit15Line(species) && (pid & 0x8000) != (pid0 & 0x8000)) continue;
      if (gen == 3 && species == 201 && _unown3(pid) != _unown3(pid0)) continue;
      if (_wurmpleLine(species) && _wurmpleEvo(pid) != _wurmpleEvo(pid0)) continue;
      pk.pid = pid;
      return;
    }
  }

  static int _lcrng(int s) => (s * 0x41C64E6D + 0x6073) & 0xFFFFFFFF;

  /// Method 1 (Gen 3–4): PID y IV de cuatro tiradas consecutivas del LCRNG.
  static void _rerollMethod1(Pkm pk, int pid0, int encSpecies, GameVersion game, bool shiny, Random rnd) {
    final tid = pk.tid, sid = pk.sid;
    final ratio = _ratio(game, encSpecies);
    for (var k = 0; k < 8000000; k++) {
      final seed = (rnd.nextInt(0x10000) << 16) | rnd.nextInt(0x10000);
      final a = _lcrng(seed), b = _lcrng(a), c = _lcrng(b), d = _lcrng(c);
      final pid = (b & 0xFFFF0000) | (a >> 16);
      if (_isShinyPid(tid, sid, pid, 8) != shiny) continue;
      if (ratio != 0 && ratio != 254 && ratio != 255 && ((pid & 0xFF) < ratio) != ((pid0 & 0xFF) < ratio)) continue;
      if (pk.format == PkFormat.pk3 && pk.species == 201 && _unown3(pid) != _unown3(pid0)) continue;
      if (_wurmpleLine(pk.species) && _wurmpleEvo(pid) != _wurmpleEvo(pid0)) continue;
      final iv1 = c >> 16, iv2 = d >> 16;
      pk.pid = pid;
      // Orden API: PS, Atq, Def, AtqE, DefE, Vel.
      pk.setIvs([iv1 & 31, (iv1 >> 5) & 31, (iv1 >> 10) & 31, (iv2 >> 5) & 31, (iv2 >> 10) & 31, iv2 & 31]);
      final abil = GameDataTable.forGame(game).entry(pk.species, pk.form)?.abilities ?? const <int>[];
      final two = abil.length > 1 && abil[1] != 0 && abil[0] != abil[1];
      pk.setAbilitySlot(pk.format == PkFormat.pk3 ? ((pid & 1) == 1 && two ? 1 : 0) : (pid & 1));
      if (pk.format == PkFormat.pk4) pk.gender = ratio == 255 ? 2 : (ratio == 254 ? 1 : (ratio == 0 ? 0 : ((pid & 0xFF) < ratio ? 1 : 0)));
      return;
    }
  }

  static int _ratio(GameVersion game, int species) => GameDataTable.forGame(game).entry(species, 0)?.genderRatio ?? 255;
}
