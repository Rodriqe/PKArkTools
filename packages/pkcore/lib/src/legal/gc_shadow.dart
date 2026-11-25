import 'dart:math';

import '../data/game_data.dart';
import '../data/generated/gc_shadow_data.dart';
import '../data/species.dart';
import '../edit/save_editor.dart';
import '../formats/gc_container.dart';
import '../model/game.dart';
import '../pkm/gc_pkm.dart';
import '../pkm/pkm.dart';
import '../pkm/pkm_factory.dart';
import 'ribbons.dart';

/// Un Pokémon oscuro que se puede capturar en Colosseum o XD, con todo lo
/// necesario para crearlo como lo haría el juego (PKHeX `EncounterShadow3Colo`
/// / `EncounterShadow3XD`, GPL-3.0). No incluye los oscuros de e-Reader de
/// Colosseum (solo japoneses, con PID fijado por la tarjeta).
class GcShadowEncounter {
  const GcShadowEncounter._(this.xd, this.shadowId, this.species, this.level, this.location, this.gauge, this.fixedBall,
      this.friendship, this.moves, this.seeds);

  final bool xd;

  /// Id oscuro (índice en la tabla de oscuros del juego).
  final int shadowId;
  final int species, level, location;

  /// Medidor de corazón inicial.
  final int gauge;

  /// Ball obligatoria (0 = cualquiera; Teddiursa de XD: Poké Ball).
  final int fixedBall;

  /// Amistad base de la especie (PKHeX `PersonalInfo.BaseFriendship`).
  final int friendship;

  /// Movimientos normales con los que se captura. El movimiento oscuro
  /// (Ataque Oscuro en Colosseum; los de XD) no se guarda en el Pokémon: lo
  /// asigna el juego mientras sigue siendo oscuro.
  final List<int> moves;

  /// Semillas de origen del RNG de GameCube cuyo PID/IV respeta los bloqueos del
  /// equipo del entrenador (comprobadas con PKHeX `LockFinder` y `LegalityAnalysis`).
  final List<int> seeds;

  GameVersion get game => xd ? GameVersion.xd : GameVersion.colosseum;
  GcKind get kind => xd ? GcKind.xk3 : GcKind.ck3;

  /// Ball con la que se crea (la fija, o Poké Ball).
  int get ball => fixedBall != 0 ? fixedBall : 4;

  static final List<GcShadowEncounter> all = [
    for (final e in kGcShadowEncounters)
      GcShadowEncounter._(e.$1 == 'xd', e.$2, e.$3, e.$4, e.$5, e.$6, e.$7, e.$8, e.$9, e.$10),
  ];

  /// Encuentros oscuros de [game] (vacío si no es Colosseum ni XD), por id oscuro.
  static List<GcShadowEncounter> forGame(GameVersion game) => switch (game) {
        GameVersion.colosseum => [for (final e in all) if (!e.xd) e],
        GameVersion.xd => [for (final e in all) if (e.xd) e],
        _ => const [],
      };

  /// Encuentros con ese id oscuro en [game] (varios si se puede combatir en varios sitios).
  static List<GcShadowEncounter> byShadowId(GameVersion game, int shadowId) =>
      [for (final e in forGame(game)) if (e.shadowId == shadowId) e];
}

/// PID, IV y bit de habilidad de una semilla de origen de Colosseum/XD.
class GcShadowRoll {
  const GcShadowRoll(this.pid, this.ivs, this.abilityBit);
  final int pid;

  /// IV en orden API (PS, Atq, Def, AtqEsp, DefEsp, Vel).
  final List<int> ivs;
  final int abilityBit;

  static int _next(int s) => (s * 0x343FD + 0x269EC3) & 0xFFFFFFFF;

  /// Como el juego (PKHeX `MethodCXD`): origen → IV, IV, habilidad, PID alto, PID bajo.
  factory GcShadowRoll.fromSeed(int origin) {
    var s = _next(origin);
    final iv1 = (s >> 16) & 0x7FFF;
    s = _next(s);
    final iv2 = (s >> 16) & 0x7FFF;
    s = _next(s);
    final ab = (s >> 16) & 1;
    s = _next(s);
    final hi = s >> 16;
    s = _next(s);
    final lo = s >> 16;
    return GcShadowRoll(
      (hi << 16) | lo,
      [iv1 & 0x1F, (iv1 >> 5) & 0x1F, (iv1 >> 10) & 0x1F, (iv2 >> 5) & 0x1F, (iv2 >> 10) & 0x1F, iv2 & 0x1F],
      ab,
    );
  }

  bool shinyFor(int tid, int sid) => (tid ^ sid ^ (pid >> 16) ^ (pid & 0xFFFF)) < 8;

  static int _prev(int s) => (s * 0xB9B33155 + 0xA170F641) & 0xFFFFFFFF;

  /// `true` si [pid] y [ivs] (orden API) salen seguidos del RNG de GameCube
  /// (IV, IV, habilidad, PID, PID), como un Pokémon oscuro generado por el juego.
  /// No comprueba los bloqueos del equipo del entrenador (eso lo hace PKHeX).
  static bool isCxd(int pid, List<int> ivs) {
    final hi = pid >> 16, lo = pid & 0xFFFF;
    for (var low = 0; low < 0x10000; low++) {
      final s4 = (hi << 16) | low;
      if (_next(s4) >> 16 != lo) continue;
      final s3 = _prev(s4), s2 = _prev(s3), s1 = _prev(s2);
      final r = GcShadowRoll.fromSeed(_prev(s1));
      var same = true;
      for (var i = 0; i < 6 && same; i++) {
        same = r.ivs[i] == ivs[i];
      }
      if (same) return true;
    }
    return false;
  }
}

/// Crea Pokémon oscuros de Colosseum y XD y cambia su estado oscuro/purificado.
abstract final class GcShadow {
  /// Pokémon oscuro recién capturado del encuentro [e] para el entrenador [trainer]:
  /// especie, nivel, movimientos, lugar y nivel de encuentro, Ball, OT/ID del
  /// jugador, versión de origen Colosseum/XD, marca de encuentro fatídico (XD),
  /// PID/IV de una semilla válida, id oscuro y medidor de corazón al máximo.
  ///
  /// Con [purified] sale ya purificado y con la Cinta Nacional.
  static Pkm create(GcShadowEncounter e, TrainerData trainer,
      {required GcRegion region, int language = 2, bool purified = false, int? gauge, Random? random}) {
    final rnd = random ?? Random();
    final pk = PkmFactory.create(e.game, trainer, species: e.species, level: e.level, language: language, random: rnd);
    // PID/IV de una semilla que pasa los bloqueos; XD nunca da oscuros variocolor.
    final order = [for (var i = 0; i < e.seeds.length; i++) i]..shuffle(rnd);
    var roll = GcShadowRoll.fromSeed(e.seeds[order.first]);
    if (e.xd) {
      for (final i in order) {
        final r = GcShadowRoll.fromSeed(e.seeds[i]);
        if (!r.shinyFor(trainer.tid, trainer.sid)) {
          roll = r;
          break;
        }
      }
    }
    pk.pid = roll.pid;
    pk.setIvs(roll.ivs);
    final abil = GameDataTable.forGame(GameVersion.emerald).entry(e.species, 0)?.abilities ?? const <int>[];
    final hasSecond = abil.length > 1 && abil[1] != 0 && abil[1] != abil[0];
    pk.setAbilitySlot(roll.abilityBit == 1 && hasSecond ? 1 : 0);
    for (var i = 0; i < 4; i++) {
      pk.setMove(i, i < e.moves.length ? e.moves[i] : 0, context: '3');
    }
    pk.exp = Species.expForLevel(e.species, e.level);
    pk.version = 15; // Colosseum/XD
    pk.metLocation = e.location;
    pk.metLevel = e.level;
    pk.ball = e.ball;
    pk.friendship = e.friendship;
    pk.fatefulEncounter = e.xd;
    Ribbons.set(pk, 'RibbonNational', purified ? 1 : 0);
    pk.setDefaultNickname();
    pk.refreshPartyStats();
    pk.refreshChecksum();
    // Datos de GameCube: id oscuro y medidor (CK3 en el propio Pokémon; XD en la tabla del save).
    final raw = GcPkm.write(pk, e.kind, region: region);
    final extra = GcExtra(e.kind, raw, xdSnagged: true)..shadowId = e.shadowId;
    if (purified) {
      extra.setPurified(true);
    } else {
      extra.purification = (gauge ?? e.gauge).clamp(0, e.gauge);
    }
    pk.gc = extra;
    return pk;
  }

  /// Purifica (con Cinta Nacional) o vuelve a oscuro (sin ella, con el medidor
  /// en [gauge] o al máximo del encuentro).
  static void setPurified(Pkm pk, bool purified, {int? gauge}) {
    final gc = pk.gc;
    if (gc == null || gc.shadowId == 0) return;
    final enc = GcShadowEncounter.byShadowId(gc.kind == GcKind.xk3 ? GameVersion.xd : GameVersion.colosseum, gc.shadowId);
    gc.setPurified(purified, gauge: gauge ?? (enc.isEmpty ? 0 : enc.first.gauge));
    Ribbons.set(pk, 'RibbonNational', purified ? 1 : 0);
    pk.refreshChecksum();
  }
}
