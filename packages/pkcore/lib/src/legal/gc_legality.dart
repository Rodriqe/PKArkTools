import '../data/game_data.dart';
import '../data/generated/gc_data.dart';
import '../model/game.dart';
import '../pkm/gc_pkm.dart';
import '../pkm/pkm.dart';
import 'encounters.dart';
import 'gc_shadow.dart';
import 'legality.dart';
import 'ribbons.dart';

/// Un encuentro de Colosseum o XD (PKHeX `Encounters3Colo`/`Encounters3XD`).
class GcEncounter {
  const GcEncounter(this.xd, this.kind, this.species, this.minLevel, this.maxLevel, this.location, this.shadowId, this.gauge);

  final bool xd;

  /// 0 oscuro, 1 inicial, 2 regalo, 3 intercambio, 4 Poké Spot.
  final int kind;
  final int species, minLevel, maxLevel, location, shadowId;

  /// Medidor de corazón inicial (oscuros).
  final int gauge;

  bool get isShadow => kind == 0;

  /// En XD todos los encuentros llevan la marca de encuentro fatídico (obediencia).
  bool get fateful => xd;

  static final List<GcEncounter> all = [
    for (final e in kGcEncounters) GcEncounter(e.$1 == 'xd', e.$2, e.$3, e.$4, e.$5, e.$6, e.$7, e.$8),
  ];

  /// Encuentros oscuros con el id [shadowId] del juego.
  static List<GcEncounter> byShadowId(int shadowId, {required bool xd}) =>
      [for (final e in all) if (e.isShadow && e.xd == xd && e.shadowId == shadowId) e];

  /// Encuentros que encajan con el Pokémon (especie o preevolución, lugar y nivel).
  static List<GcEncounter> matching(Pkm pk) {
    final chain = EncounterTables.evolutionChain(pk.species);
    return [
      for (final e in all)
        if (chain.contains(e.species) && e.location == pk.metLocation && pk.metLevel >= e.minLevel && pk.metLevel <= e.maxLevel) e,
    ];
  }
}

/// Reglas propias de Pokémon Colosseum y XD: Pokémon oscuros, Cinta Nacional
/// y marca de encuentro fatídico de XD. Portado de PKHeX `RibbonRules.GetValidRibbonStateNational`,
/// `EncounterShadow3*`, `EncounterStatic3XD` y `CXDVerifier` (GPL-3.0).
abstract final class GcLegality {
  static List<LegalityIssue> check(Pkm pk, GameVersion game, String speciesName) {
    final out = <LegalityIssue>[];
    final gc = pk.gc;
    if (gc != null && gc.isShadow && !game.isColosseumOrXd) {
      out.add(LegalityIssue(LegalityCode.shadowCannotLeave, LegalitySeverity.warning, args: {'species': speciesName}));
    }
    if (pk.isEgg || pk.version != EncounterTables.cxd || pk.format.generation != 3) return out;
    // Id oscuro: debe corresponder a la especie (o su preevolución) en ese juego.
    final enc = GcEncounter.matching(pk);
    if (gc != null && gc.shadowId != 0) {
      final xd = gc.kind == GcKind.xk3;
      final gameName = xd ? 'Pokémon XD' : 'Pokémon Colosseum';
      final byId = GcEncounter.byShadowId(gc.shadowId, xd: xd);
      final chain = EncounterTables.evolutionChain(pk.species);
      final everShadow = GcEncounter.all.any((e) => e.isShadow && e.xd == xd && chain.contains(e.species));
      if (byId.isEmpty) {
        out.add(LegalityIssue(LegalityCode.shadowIdUnknown, LegalitySeverity.warning,
            field: 'shadow', args: {'id': gc.shadowId, 'game': gameName}));
      } else if (!everShadow) {
        out.add(LegalityIssue(LegalityCode.shadowSpeciesNotShadow, LegalitySeverity.warning,
            field: 'shadow', args: {'species': speciesName, 'game': gameName}));
      }
      // PID/IV del RNG de GameCube (PKHeX `MethodCXD`); los bloqueos de equipo no se comprueban.
      if (!GcShadowRoll.isCxd(pk.pid, pk.ivs)) {
        out.add(const LegalityIssue(LegalityCode.shadowPidIvMismatch, LegalitySeverity.notice, field: 'pid'));
      }
      if (xd && pk.isShiny) {
        out.add(const LegalityIssue(LegalityCode.xdShadowShiny, LegalitySeverity.warning, field: 'pid'));
      }
      if (byId.isNotEmpty && everShadow && !byId.any((e) => chain.contains(e.species))) {
        out.add(LegalityIssue(LegalityCode.shadowIdMismatch, LegalitySeverity.warning, field: 'shadow', args: {
          'species': speciesName,
          'id': gc.shadowId,
          'expected': GameStrings.species(byId.first.species),
        }));
      }
      if (gc.isShadow && byId.isNotEmpty) {
        final max = byId.first.gauge;
        final p = gc.purification;
        if (p < 0 || (max > 0 && p > max)) {
          out.add(LegalityIssue(LegalityCode.shadowGaugeInvalid, LegalitySeverity.notice,
              field: 'shadow', args: {'value': p, 'max': max}));
        }
      }
    }
    // Cinta Nacional: la da la purificación de un Pokémon oscuro.
    final fromShadow = (gc != null && gc.shadowId != 0) || (gc == null && enc.isNotEmpty && enc.every((e) => e.isShadow));
    if (fromShadow) {
      final stillShadow = gc?.isShadow ?? false;
      final has = Ribbons.get(pk, 'RibbonNational') != 0;
      if (has == stillShadow) {
        out.add(LegalityIssue(LegalityCode.shadowNationalRibbon, LegalitySeverity.warning,
            field: 'ribbons', args: {'species': speciesName, 'required': !stillShadow}, fix: LegalityFix.nationalRibbon));
      }
    } else if (gc != null && enc.isNotEmpty && Ribbons.get(pk, 'RibbonNational') != 0 && !enc.any((e) => e.isShadow)) {
      out.add(LegalityIssue(LegalityCode.shadowNationalRibbon, LegalitySeverity.warning,
          field: 'ribbons', args: {'species': speciesName, 'required': false}, fix: LegalityFix.nationalRibbon));
    }
    // XD marca todos sus encuentros como fatídicos (obediencia).
    if (enc.isNotEmpty && enc.every((e) => e.xd) && !pk.fatefulEncounter) {
      out.add(LegalityIssue(LegalityCode.xdFatefulMissing, LegalitySeverity.warning,
          field: 'fateful', args: {'species': speciesName}, fix: LegalityFix.fateful));
    }
    return out;
  }

  /// Valor correcto de la Cinta Nacional para [pk] (null si no aplica).
  static bool? nationalRibbonRequired(Pkm pk) {
    final gc = pk.gc;
    if (gc != null && gc.shadowId != 0) return !gc.isShadow;
    final enc = GcEncounter.matching(pk);
    if (pk.version == EncounterTables.cxd && enc.isNotEmpty && enc.every((e) => e.isShadow)) return true;
    return pk.version == EncounterTables.cxd ? false : null;
  }
}
