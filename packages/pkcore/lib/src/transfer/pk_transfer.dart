import 'dart:math';
import 'dart:typed_data';

import '../data/forms.dart';
import '../data/game_data.dart';
import '../data/generated/transfer_data.dart';
import '../data/species.dart';
import '../legal/origin.dart';
import '../legal/ribbons.dart';
import '../model/game.dart';
import '../pkm/gc_pkm.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import '../util/bytes.dart';
import 'home_transfer.dart';
import 'transfer_fields.dart';

/// Motivo por el que un Pokémon no puede ir a otro juego.
enum TransferBlock {
  /// Gen 3+ no puede volver a un formato anterior (salvo entre juegos de Switch vía HOME).
  backwards,

  /// Gen 1/2 solo puede ir a Gen 1/2 o, por la Consola Virtual, a Gen 7+.
  noRoute,

  /// Pokémon oscuro sin purificar (Colosseum/XD).
  shadow,

  /// Los huevos solo se pueden intercambiar entre juegos del mismo formato.
  egg,

  /// La especie no existe en el juego de destino.
  speciesNotInGame,

  /// La forma no existe en el juego de destino o no puede salir de su juego
  /// (Pikachu con gorra/disfraz, compañeros de Let's Go, Koraidon/Miraidon de montura…).
  formNotAllowed,

  /// Spinda y Nincada no pueden entrar ni salir de Diamante Brillante/Perla Reluciente.
  bdspLocked,

  /// A Let's Go solo vuelven Pokémon de Let's Go (o de GO a través de Let's Go).
  letsGoOnly,

  /// Gen 1/2: entre saves japoneses e internacionales no se puede intercambiar.
  gbLanguage,

  /// La especie, sus movimientos u objeto no existen en Gen 1.
  notInGen1,

  /// El juego de destino no admite Pokémon de otros formatos (Colosseum/XD).
  unsupported,
}

/// Entrenador del save de destino: pasa a ser el último entrenador (HT) si no es el original.
class TransferTrainer {
  const TransferTrainer({required this.name, required this.tid, required this.sid, this.gender = 0, this.language = 2});

  final String name;
  final int tid, sid, gender, language;
}

/// Resultado de una conversión.
class TransferResult {
  const TransferResult._(this.pk, this.block, this.route);

  /// Pokémon convertido al formato del juego de destino (null si [block]).
  final Pkm? pk;
  final TransferBlock? block;

  /// Formatos por los que ha pasado (incluye origen y destino).
  final List<PkFormat> route;

  bool get ok => pk != null;
}

/// Conversión de Pokémon entre juegos, como Pal Park, Poké Transfer, Poké
/// Transporter, Pokémon Bank y Pokémon HOME.
///
/// Portado de PKHeX.Core `EntityConverter` y los `ConvertToPKx` de cada
/// formato (GPL-3.0). Solo se permiten las rutas reales: hacia adelante, y
/// entre los juegos de Switch (PK8/PB8/PA8/PK9/PA9) en cualquier sentido.
abstract final class PkTransfer {
  /// Comprueba si [pk] (de [from]) puede ir a [to]. null = se puede.
  static TransferBlock? check(Pkm pk, GameVersion from, GameVersion to, {bool destJapanese = false}) {
    final src = pk.gc != null ? PkFormat.pk3 : pk.format;
    final dest = PkFormat.forGame(to);
    if (pk.gc != null && pk.gc!.isShadow && from != to) return TransferBlock.shadow;
    if (src == dest) {
      if (src.isGameBoy && pk.japanese != destJapanese) return TransferBlock.gbLanguage;
      if (to.isColosseumOrXd && from != to) return TransferBlock.unsupported;
      return null;
    }
    if (pk.isEgg) return TransferBlock.egg;
    if (to.isColosseumOrXd) return TransferBlock.unsupported;
    final species = pk.species;
    final form = pk.form;
    // Salida (PKHeX CheckTransferOutbound).
    if (src == PkFormat.pk4 && species == 172 && form != 0) return TransferBlock.formNotAllowed;
    if (src == PkFormat.pk6 && species == 25 && form != 0) return TransferBlock.formNotAllowed;
    if (src == PkFormat.pb7 && (species == 25 || species == 133) && form != 0) return TransferBlock.formNotAllowed;
    if (src == PkFormat.pb8 && (species == 327 || species == 290)) return TransferBlock.bdspLocked;
    if (src == PkFormat.pk9 && (species == 1007 || species == 1008) && pk.formArgument != 0) {
      return TransferBlock.formNotAllowed;
    }
    if (dest == PkFormat.pb8 && (species == 327 || species == 290)) return TransferBlock.bdspLocked;
    // Leyendas Z-A: se puede llevar allí, pero PKHeX no reconoce como legal nada
    // que salga de Z-A hacia otro juego (movimientos y medidas sin origen válido).
    if (src == PkFormat.pa9) return TransferBlock.noRoute;

    if (src.isGameBoy) {
      if (dest.isGameBoy) {
        if (pk.japanese != destJapanese || pk.korean) return TransferBlock.gbLanguage;
        if (dest == PkFormat.pk1 && !_gen1Compatible(pk)) return TransferBlock.notInGen1;
        return null;
      }
      if (dest.generation < 7) return TransferBlock.noRoute;
    } else if (dest.isGameBoy) {
      return TransferBlock.backwards;
    }
    // HOME solo devuelve a Let's Go lo que salió de Let's Go (o de GO vía Let's Go),
    // y pkcore solo lo hace desde un save de Let's Go.
    if (dest == PkFormat.pb7) return TransferBlock.letsGoOnly;
    if (!src.isGameBoy && dest.generation < 8 && dest.generation < src.generation) return TransferBlock.backwards;
    if (src == PkFormat.pb7 && dest.generation < 8) return TransferBlock.backwards;
    if (src == PkFormat.pk7 && dest == PkFormat.pb7) return TransferBlock.backwards;
    if (dest.generation >= 8 || dest == PkFormat.pb7) {
      // HOME: Arceus y Silvally se guardan en su forma base.
      final f = (species == 493 || species == 773) ? 0 : form;
      if (!GameDataTable.forGame(to).hasSpecies(species)) return TransferBlock.speciesNotInGame;
      if (!SpeciesForms.isPresent(species, f, to)) return TransferBlock.formNotAllowed;
    }
    return null;
  }

  static bool _gen1Compatible(Pkm pk) {
    if (pk.species > 151) return false;
    if (pk.moves.any((m) => m > 165)) return false;
    return true;
  }

  /// Convierte [pk] (leído de un save de [from]) para un save de [to].
  ///
  /// [trainer] es el entrenador del save de destino (último entrenador en
  /// Bank/Transporter y, en Switch, si no es el original). [today] y
  /// [random] fijan la fecha y los valores aleatorios (tests).
  static TransferResult convert(Pkm pk, GameVersion from, GameVersion to,
      {TransferTrainer? trainer, DateTime? today, Random? random, bool destJapanese = false}) {
    final block = check(pk, from, to, destJapanese: destJapanese);
    final route = <PkFormat>[pk.gc != null ? PkFormat.pk3 : pk.format];
    if (block != null) return TransferResult._(null, block, route);
    final ctx = _Ctx(
      from: from,
      to: to,
      trainer: trainer ?? const TransferTrainer(name: 'ARCA', tid: 12345, sid: 54321),
      today: today ?? DateTime.now(),
      rnd: random ?? Random(),
    );
    var cur = pk.clone()..dataGame = from;
    if (cur.gc != null && !to.isColosseumOrXd) cur = GcPkm.toGba(cur)..dataGame = from;
    final dest = PkFormat.forGame(to);
    var guard = 0;
    while (cur.format != dest) {
      cur = _step(cur, dest, ctx);
      route.add(cur.format);
      if (++guard > 12) throw StateError('ruta de transferencia sin fin');
    }
    cur.dataGame = to;
    if (dest.generation >= 8 && route.length > 1) _updateHandler(cur, ctx);
    if (!cur.format.isGameBoy) {
      cur.refreshPartyStats();
      cur.refreshChecksum();
    }
    return TransferResult._(cur, null, route);
  }

  static Pkm _step(Pkm pk, PkFormat dest, _Ctx ctx) {
    switch (pk.format) {
      case PkFormat.pk1:
        return dest == PkFormat.pk2 ? _pk1to2(pk) : _gbTo7(pk, ctx);
      case PkFormat.pk2:
        return dest == PkFormat.pk1 ? _pk2to1(pk) : _gbTo7(pk, ctx);
      case PkFormat.pk3:
        return _pk3to4(pk, ctx);
      case PkFormat.pk4:
        return _pk4to5(pk, ctx);
      case PkFormat.pk5:
        return _pk5to6(pk, ctx);
      case PkFormat.pk6:
        return _pk6to7(pk, ctx);
      default:
        return HomeTransfer.convert(pk, dest, ctx.rnd, ctx.today);
    }
  }

  // ------------------------------------------------------------ Gen 1 ↔ Gen 2 (Cápsula del Tiempo)

  static Pkm _pk1to2(Pkm s) {
    final d = Pkm.fromGb(PkFormat.pk2, Uint8List(PkFormat.pk2.partySize),
        nickname: s.nickname, otName: s.otName, japanese: s.japanese, korean: s.korean);
    d.data.setRange(1, 1 + 0x1A, s.data, 7);
    d.data[0] = s.species;
    // Objeto de Gen 2 a partir del ratio de captura de Gen 1.
    d.data[1] = kItemFuture1[s.data[7]];
    d.data[27] = baseFriendship(s.species);
    d.data[31] = s.level;
    d.dataGame = GameVersion.crystal;
    d.refreshPartyStats();
    return d;
  }

  static Pkm _pk2to1(Pkm s) {
    final d = Pkm.fromGb(PkFormat.pk1, Uint8List(PkFormat.pk1.partySize),
        nickname: s.nickname, otName: s.otName, japanese: s.japanese);
    d.data.setRange(7, 7 + 0x1A, s.data, 1);
    d.dataGame = GameVersion.yellow;
    d.species = s.species; // también los tipos
    d.data[3] = s.level;
    d.data[33] = s.level;
    // Sin movimientos de Gen 2.
    final moves = [for (final m in s.moves) if (m <= 165) m];
    for (var i = 0; i < 4; i++) {
      d.setMove(i, i < moves.length ? moves[i] : 0, refillPp: false);
    }
    d.refreshPartyStats();
    return d;
  }

  // ------------------------------------------------------------ Gen 1/2 → Gen 7 (Poké Transporter, Consola Virtual)

  static Pkm _gbTo7(Pkm s, _Ctx ctx) {
    final rnd = ctx.rnd;
    final gen1 = s.format == PkFormat.pk1;
    final species = s.species;
    var lang = ctx.trainer.language;
    if ((lang == 1) != s.japanese) lang = s.japanese ? 1 : 2;
    if (s.korean) lang = 8;
    final d = Pkm.fromDecrypted(PkFormat.pk7, Uint8List(PkFormat.pk7.partySize))..dataGame = GameVersion.ultraSunUltraMoon;
    final level = s.level;
    d.encryptionConstant = _rand32(rnd);
    d.data.setU16le(0x08, species);
    d.tid = s.tid;
    d.sid = 0;
    d.metLevel = level;
    d.data[0x1C] = s.exp % 25; // naturaleza = experiencia % 25
    d.exp = Species.expForLevel(species, level); // la experiencia se recorta al mínimo del nivel
    d.pid = _rand32(rnd);
    d.ball = 4;
    d.metDate = _day(ctx.today);
    d.version = gen1 ? (s.japanese ? 37 : 35) : (s.data[0x1D] != 0 || s.data[0x1E] != 0 ? 41 : 40);
    final moves = [for (final m in s.moves) if (m != 0 && !(m == 146 && !gen1)) m];
    for (var i = 0; i < 4; i++) {
      d.setMove(i, i < moves.length ? moves[i] : 0);
      d.setPpUps(i, i < moves.length ? s.ppUps(s.moves.indexOf(moves[i])) : 0);
    }
    d.metLocation = gen1 ? 30013 : 30017;
    // Género: el de Gen 1/2 (DV de ataque).
    final g = s.format == PkFormat.pk2 ? (s..dataGame = GameVersion.crystal).gender : _gen1Gender(s);
    d.data[0x1D] = (d.data[0x1D] & ~0x06) | ((g & 3) << 1);
    if (!gen1) d.form = s.form;
    d.currentHandler = 1;
    d.htName = ctx.trainer.name;
    d.htGender = ctx.trainer.gender;
    d.language = lang;
    d.otName = _gbTrainerName(s, lang);
    if (!gen1) d.otGender = s.otGender;
    final bf = baseFriendship(species);
    d.otFriendship = bf;
    d.htFriendship = bf;
    final hiddenDisallowed = gen1
        ? const {92, 93, 94, 109, 110, 151}.contains(species)
        : const {92, 93, 94, 109, 110, 200, 201, 151, 251}.contains(species);
    final slot = hiddenDisallowed ? 0 : 2;
    d.setAbilitySlot(slot);
    // IV: 3 perfectos (5 para Mew y Celebi), barajados.
    final special = species == 151 || species == 251;
    final ivs = [for (var i = 0; i < 6; i++) rnd.nextInt(32)];
    for (var i = 0; i < (special ? 5 : 3); i++) {
      ivs[i] = 31;
    }
    ivs.shuffle(rnd);
    d.setIvs(ivs);
    // Variocolor: se conserva el estado (cuadrado si era variocolor).
    final shiny = s.isShiny;
    final xor = (d.tid ^ d.sid ^ (d.pid >> 16) ^ (d.pid & 0xFFFF)) & 0xFFFF;
    if (shiny && xor >= 16) {
      final low = d.pid & 0xFFFF;
      d.pid = ((low ^ d.tid) << 16) | low;
    } else if (!shiny && xor < 16) {
      d.pid = d.pid ^ 0x10000000;
    }
    _setTransferLocale(d, lang, ctx, bank: true);
    d.setNicknameRaw(TransferNames.gen7(species, lang));
    if (special) {
      d.fatefulEncounter = true;
    } else if (_isNicknamedBank(s)) {
      d.setNicknameRaw(s.nickname);
      d.nicknamedFlag = true;
    }
    d.healPp('7');
    d.refreshChecksum();
    return d;
  }

  static int _gen1Gender(Pkm s) {
    final p = GameDataTable.forGame(GameVersion.crystal).entry(s.species);
    final ratio = p?.genderRatio ?? 127;
    if (ratio == 255) return 2;
    if (ratio == 254) return 1;
    if (ratio == 0) return 0;
    final atk = (s.data.u16be(27) >> 12) & 0xF;
    return (atk << 4) < ratio ? 1 : 0;
  }

  static bool _isNicknamedBank(Pkm s) {
    final n = s.nickname;
    for (final l in const [1, 2, 3, 4, 5, 7, 8]) {
      if (TransferNames.gen4(s.species, l).toUpperCase() == n.toUpperCase()) return false;
      if (TransferNames.gen7(s.species, l).toUpperCase() == n.toUpperCase()) return false;
    }
    return n.isNotEmpty;
  }

  static String _gbTrainerName(Pkm s, int lang) {
    final n = s.otName;
    if (n.isEmpty) return lang == 1 ? 'トレーナー' : 'Trainer';
    return n;
  }

  // ------------------------------------------------------------ Gen 3 → Gen 4 (Pal Park)

  static const _hm3 = {15, 19, 57, 70, 148, 249, 127, 291};
  static const _hm4dppt = {15, 19, 57, 70, 432, 249, 127, 431};
  static const _hm4hgss = {15, 19, 57, 70, 250, 249, 127, 431};

  static Pkm _pk3to4(Pkm s, _Ctx ctx) {
    s.dataGame ??= GameVersion.emerald;
    final d = Pkm.fromDecrypted(PkFormat.pk4, Uint8List(PkFormat.pk4.partySize))..dataGame = GameVersion.heartGoldSoulSilver;
    final sd = s.data;
    final pid = s.pid;
    final species = s.species;
    d.pid = pid;
    d.data.setU16le(0x08, species);
    d.tid = s.tid;
    d.sid = s.sid;
    d.exp = s.exp;
    final form = species == 201 ? _unownForm3(pid) : 0;
    d.data[0x40] = ((form & 0x1F) << 3) | ((s.gender & 3) << 1);
    d.data[0x14] = 70; // amistad
    d.data[0x16] = sd[0x1B] & 0x0F; // marcas
    d.language = s.language;
    d.data.setRange(0x18, 0x1E, sd, 0x38); // EV
    d.data.setRange(0x1E, 0x24, sd, 0x3E); // concursos
    for (var i = 0; i < 4; i++) {
      d.data.setU16le(0x28 + i * 2, s.move(i));
      d.data[0x34 + i] = s.ppUps(i);
    }
    d.data.setU32le(0x38, sd.u32le(0x48) & 0x3FFFFFFF);
    d.data[0x15] = s.ability;
    d.data[0x5F] = s.version;
    d.ball = s.ball;
    d.data[0x82] = sd[0x44]; // Pokérus
    d.otGender = s.otGender;
    d.metDate = _day(ctx.today);
    d.metLevel = s.level;
    // Pal Park: lugar 55; Platino y HGSS también rellenan el campo extendido.
    d.data.setU16le(0x80, 0x37);
    if (ctx.to == GameVersion.platinum || ctx.to == GameVersion.heartGoldSoulSilver) d.data.setU16le(0x46, 0x37);
    // Cintas: las que comparten nombre, y los rangos de concurso de Gen 3 como cintas sueltas.
    _copyRibbons(s, d);
    for (final c in const ['Cool', 'Beauty', 'Cute', 'Smart', 'Tough']) {
      final n = Ribbons.get(s, 'RibbonCountG3$c');
      Ribbons.set(d, 'RibbonG3$c', n > 0 ? 1 : 0);
      Ribbons.set(d, 'RibbonG3${c}Super', n > 1 ? 1 : 0);
      Ribbons.set(d, 'RibbonG3${c}Hyper', n > 2 ? 1 : 0);
      Ribbons.set(d, 'RibbonG3${c}Master', n > 3 ? 1 : 0);
    }
    d.fatefulEncounter = s.fatefulEncounter;
    // Apodo y entrenador (en mayúsculas de Gen 4 si no tenía apodo).
    if (s.isNicknamed) {
      d.nickname = s.nickname;
      d.data[0x3B] |= 0x80;
    } else {
      d.nickname = TransferNames.gen4(species, s.language);
    }
    d.otName = s.otName;
    final item = s.heldItem;
    if (item != 0 && item < kItem3to4.length) {
      final f = kItem3to4[item];
      if (f != 128 && f > 0) d.heldItem = f;
    }
    _removeMoves(d, _hm3);
    d.healPp('4');
    d.refreshChecksum();
    return d;
  }

  static int _unownForm3(int pid) {
    final v = ((pid & 0x3000000) >> 18) | ((pid & 0x30000) >> 12) | ((pid & 0x300) >> 6) | (pid & 0x3);
    return v % 28;
  }

  // ------------------------------------------------------------ Gen 4 → Gen 5 (Poké Transfer)

  static Pkm _pk4to5(Pkm s, _Ctx ctx) {
    final d = Pkm.fromDecrypted(PkFormat.pk5, Uint8List(PkFormat.pk5.partySize))..dataGame = GameVersion.black2White2;
    d.data.setRange(0, 136, s.data);
    final species = s.species;
    d.data[0x8D] = 0;
    d.data[0x14] = 70;
    if (species == 493) {
      d.form = 0;
      d.heldItem = 0;
    } else if (!kHeldItemsBW.contains(s.heldItem)) {
      d.heldItem = 0;
    }
    d.data[0x41] = s.pid % 25; // naturaleza separada del PID
    d.data.setRange(0x42, 0x48, Uint8List(6)); // sin habilidad oculta; sin lugares extendidos de Pt/HGSS
    d.data.setU16le(0x80, _transferMet4(s));
    d.data.setRange(0x86, 0x88, Uint8List(2));
    d.data[0x83] = s.ball;
    d.metDate = _day(ctx.today);
    d.nickname = s.nickname;
    d.otName = s.otName;
    d.metLevel = s.level;
    final hasDefog = s.moves.contains(432);
    _removeMoves(d, hasDefog ? _hm4hgss : _hm4dppt);
    if (species == 292) d.data[0x40] = (d.data[0x40] & ~0x06) | (2 << 1); // Shedinja sin género
    d.healPp('5');
    d.refreshChecksum();
    return d;
  }

  static int _transferMet4(Pkm s) {
    final gen4 = s.version >= 7 && s.version <= 12;
    if (!s.fatefulEncounter || !gen4) return 30001;
    return switch (s.species) {
      243 || 244 || 245 => 30012,
      251 => 30010,
      _ => 30001,
    };
  }

  // ------------------------------------------------------------ Gen 5 → Gen 6 (Poké Transporter)

  static Pkm _pk5to6(Pkm s, _Ctx ctx) {
    final sd = s.data;
    final d = Pkm.fromDecrypted(PkFormat.pk6, Uint8List(PkFormat.pk6.partySize))..dataGame = GameVersion.omegaRubyAlphaSapphire;
    final pid = s.pid;
    final species = s.species;
    d.encryptionConstant = pid;
    d.data.setU16le(0x08, species);
    d.tid = s.tid;
    d.sid = s.sid;
    d.exp = s.exp;
    // PID: si con la regla de Gen 6 pasaría a ser variocolor, se invierte el bit alto.
    final id32 = (s.sid << 16) | s.tid;
    final tmp = pid ^ id32;
    final xor = (tmp ^ (tmp >> 16)) & 0xFFFF;
    d.pid = (xor & 0xFFF8) == 8 ? (pid ^ 0x80000000) : pid;
    d.data[0x2A] = sd[0x16]; // marcas
    d.language = max(1, s.language);
    d.data.setRange(0x24, 0x2A, sd, 0x1E); // concursos
    for (var i = 0; i < 6; i++) {
      d.data[0x1E + i] = min(sd[0x18 + i], 252);
    }
    for (var i = 0; i < 4; i++) {
      d.data.setU16le(0x5A + i * 2, s.move(i));
      d.data[0x66 + i] = s.ppUps(i);
    }
    d.data.setU32le(0x74, sd.u32le(0x38));
    d.fatefulEncounter = s.fatefulEncounter;
    d.data[0x1D] = (d.data[0x1D] & 0x01) | (sd[0x40] & 0x06) | (sd[0x40] & 0xF8);
    d.data[0x1C] = sd[0x41];
    d.data[0xDF] = s.version;
    d.data.setRange(0xD1, 0xD4, sd, 0x78); // fecha de huevo
    d.data.setRange(0xD4, 0xD7, sd, 0x7B); // fecha de encuentro
    d.data.setU16le(0xDA, sd.u16le(0x80));
    d.data.setU16le(0xD8, sd.u16le(0x7E));
    d.data[0x2B] = sd[0x82];
    d.data[0xDC] = sd[0x83];
    d.data[0xDD] = sd[0x84]; // nivel + género del OT
    d.data[0xDE] = sd[0x85]; // tipo de terreno
    // Cintas: contadores de recuerdo y las que siguen existiendo.
    final contest = _popcount((sd.u32le(0x60) & 0xFFFFF) << 20 | (sd.u32le(0x3C) & 0xFFFFF));
    final battle = _popcount((sd[0x24] & 0x7E) | ((sd[0x3E] & 0x60) << 2));
    _copyRibbons(s, d);
    Ribbons.set(d, 'RibbonCountMemoryContest', contest);
    Ribbons.set(d, 'RibbonCountMemoryBattle', battle);
    // Último entrenador: quien usa Poké Transporter.
    d.currentHandler = 1;
    d.htName = ctx.trainer.name;
    d.htGender = ctx.trainer.gender;
    d.htMemory = (1, 4, ctx.rnd.nextInt(10), 0);
    _setTransferLocale(d, d.language, ctx, bank: true, memory: false);
    final cur = TransferNames.languageOf(species, s.nickname);
    d.setNicknameRaw(TransferNames.gen6(species, cur <= 0 ? s.language : cur));
    if (s.isNicknamed) {
      d.setNicknameRaw(s.nickname);
      d.nicknamedFlag = true;
    }
    final bf = baseFriendship(species);
    d.otFriendship = bf;
    d.htFriendship = bf;
    d.otName = s.otName;
    _fixMoves(d);
    d.healPp('6');
    // Habilidad: misma ranura (la oculta si lo era).
    final p = GameDataTable.forGame(GameVersion.blackWhite).entry(species, s.form);
    var index = 0;
    if ((sd[0x42] & 1) == 1) {
      index = 2;
    } else if (p != null && p.abilities.isNotEmpty && s.ability == p.abilities[0]) {
      index = 0;
    } else if (p != null && p.abilities.length > 1 && s.ability == p.abilities[1]) {
      index = 1;
    } else {
      index = (pid >> 16) & 1;
    }
    d.setAbilitySlot(index);
    d.refreshChecksum();
    return d;
  }

  // ------------------------------------------------------------ Gen 6 → Gen 7 (Pokémon Bank)

  static Pkm _pk6to7(Pkm s, _Ctx ctx) {
    final d = Pkm.fromDecrypted(PkFormat.pk7, Uint8List.fromList(s.data))..dataGame = GameVersion.ultraSunUltraMoon;
    final sd = s.data;
    d.data[0x2A] = 0; // estado de evento del Poké Resort (antes, marcas)
    d.data.setU16le(0x16, 0); // marcas (antes, bolsa de entrenamiento)
    d.data[0xDE] = 0; // superentrenamiento (antes, terreno de Gen 4)
    d.data.setU32le(0x3C, 0);
    d.data[0xED] = 0;
    d.data[0xEE] = 0;
    var marks = 0;
    for (var i = 0; i < 6; i++) {
      if ((sd[0x2A] >> i) & 1 == 1) marks |= 1 << (i * 2);
    }
    d.data.setU16le(0x16, marks);
    final an = sd[0x15] & 7;
    if (an == 1 || an == 2 || an == 4) {
      final index = an >> 1;
      final p6 = GameDataTable.forGame(GameVersion.omegaRubyAlphaSapphire).entry(s.species, s.form);
      final p7 = GameDataTable.forGame(GameVersion.ultraSunUltraMoon).entry(s.species, s.form);
      if (p6 != null && p7 != null && index < p6.abilities.length && p6.abilities[index] == sd[0x14] &&
          index < p7.abilities.length) {
        d.data[0x14] = p7.abilities[index];
      }
    }
    d.htMemory = (1, 4, ctx.rnd.nextInt(10), 0);
    _setTransferLocale(d, d.language, ctx, bank: true, memory: false, consoleOnly: true);
    d.data.setRange(0x94, 0x9E, Uint8List(10));
    d.data.setRange(0xAA, 0xB0, Uint8List(6));
    d.data.setRange(0xE4, 0xE8, Uint8List(4));
    d.data[0x72] &= 0xFC;
    d.data[0xEF] = 0;
    // Furfrou y Hoopa conservan el tiempo de su forma.
    d.data[0x3C] = sd[0xED];
    d.data[0x3D] = sd[0xEE];
    d.data[0x3E] = sd[0x3C];
    // Geo1 = país/región de quien lo recibe.
    _setFirstGeo(d);
    // Un Pokémon que llega de otra generación siempre tiene último entrenador (PKHeX TransferHandlerFlagRequired).
    d.currentHandler = 1;
    if (d.htName.isEmpty) {
      d.htName = ctx.trainer.name;
      d.htGender = ctx.trainer.gender;
      d.htFriendship = baseFriendship(d.species);
    }
    d.healPp('7');
    d.refreshChecksum();
    return d;
  }

  // ------------------------------------------------------------ utilidades comunes

  static void _copyRibbons(Pkm s, Pkm d) {
    for (final r in Ribbons.forFormat(s.format)) {
      final v = Ribbons.get(s, r.key);
      if (v != 0) Ribbons.set(d, r.key, v);
    }
  }

  static void _removeMoves(Pkm d, Set<int> banned) {
    for (var i = 0; i < 4; i++) {
      if (banned.contains(d.move(i))) {
        d.setMove(i, 0, refillPp: false);
        d.setPpUps(i, 0);
      }
    }
    _fixMoves(d);
  }

  /// Compacta los movimientos (sin huecos al principio), como PKHeX `FixMoves`.
  static void _fixMoves(Pkm d) {
    final list = [for (var i = 0; i < 4; i++) (d.move(i), d.ppUps(i))]..removeWhere((m) => m.$1 == 0);
    for (var i = 0; i < 4; i++) {
      d.setMove(i, i < list.length ? list[i].$1 : 0, refillPp: false);
      d.setPpUps(i, i < list.length ? list[i].$2 : 0);
    }
  }

  // Región de la consola de quien transfiere (PKHeX SimpleTrainerInfo: EE. UU.).
  static void _setTransferLocale(Pkm d, int lang, _Ctx ctx,
      {required bool bank, bool memory = true, bool consoleOnly = false}) {
    if (memory) d.htMemory = (1, 4, ctx.rnd.nextInt(10), bank ? 0 : 9);
    final geo = d.g6.geo!;
    var country = 49, region = 7, console = 1;
    if (lang == 1) {
      country = 1;
      region = 0;
      console = 0;
    }
    if (!consoleOnly || d.data[geo.$1] == 0) {
      d.data[geo.$1] = country;
      d.data[geo.$2] = region;
      d.data[geo.$3] = console;
    }
    _setFirstGeo(d);
  }

  static void _setFirstGeo(Pkm d) {
    final geo = d.g6.geo!;
    if (d.data[geo.$4 + 1] != 0) return;
    d.data[geo.$4] = d.data[geo.$2];
    d.data[geo.$4 + 1] = d.data[geo.$1];
  }

  /// En Switch, quien recibe un Pokémon de otro entrenador pasa a ser su
  /// último entrenador (PKHeX `PKH.UpdateHandler`).
  ///
  /// Si viene de otro juego (contexto distinto del de su origen), el último
  /// entrenador es obligatorio aunque sea el mismo que el original
  /// (PKHeX `TransferHandlerFlagRequired`).
  static void _updateHandler(Pkm pk, _Ctx ctx) {
    final t = ctx.trainer;
    final isOt = pk.otName == t.name && pk.tid == t.tid && pk.sid == t.sid && pk.otGender == t.gender;
    if (isOt && _nativeFormat(pk.version) == pk.format) {
      pk.currentHandler = 0;
      return;
    }
    pk.currentHandler = 1;
    if (pk.htGender == t.gender && pk.htName == t.name) return;
    pk.htMemory = (0, 0, 0, 0);
    pk.htName = t.name;
    pk.htLanguage = t.language;
    pk.htGender = t.gender;
    pk.htFriendship = baseFriendship(pk.species);
  }

  static PkFormat? _nativeFormat(int version) => switch (version) {
        44 || 45 => PkFormat.pk8,
        47 => PkFormat.pa8,
        48 || 49 => PkFormat.pb8,
        50 || 51 => PkFormat.pk9,
        52 => PkFormat.pa9,
        _ => null,
      };

  static int _rand32(Random r) => (r.nextInt(0x10000) << 16) | r.nextInt(0x10000);
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static int _popcount(int v) {
    var c = 0;
    while (v != 0) {
      c += v & 1;
      v >>= 1;
    }
    return c;
  }
}

class _Ctx {
  _Ctx({required this.from, required this.to, required this.trainer, required this.today, required this.rnd});
  final GameVersion from, to;
  final TransferTrainer trainer;
  final DateTime today;
  final Random rnd;
}
