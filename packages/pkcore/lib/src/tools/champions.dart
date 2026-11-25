import '../data/forms.dart';
import '../data/game_data.dart';
import '../data/generated/champions_data.dart';
import '../legal/legality.dart';
import '../model/game.dart';
import '../pkm/pkm.dart';
import 'showdown.dart';

/// Regulación oficial de Pokémon Champions.
///
/// La lista de especies y las reglas del formato salen de Pokémon Showdown
/// (`tool/gen_champions_data.py`, tabla generada `champions_data.dart`); las
/// fechas no están en Showdown y se escriben aquí a mano con su fuente.
/// Cómo actualizarla: `docs/usuario/formato-oficial.md`.
class ChampionsRegulation {
  const ChampionsRegulation({
    required this.code,
    required this.from,
    required this.until,
    required this.datesSource,
    required this.datesConfirmed,
  });

  /// Código de la regulación (`M-C`).
  final String code;
  final DateTime from;
  final DateTime until;

  /// De dónde salen las fechas.
  final String datesSource;

  /// `false` si las fechas no se han podido confirmar en una fuente oficial:
  /// la interfaz lo indica.
  final bool datesConfirmed;
}

/// Por qué un Pokémon no puede (o quizá no pueda) usarse en el formato.
enum ChampionsReason {
  egg,
  shadow,
  mythical,
  restricted,
  speciesNotAllowed,
  formNotAllowed,

  /// No bloquea: PKArkTools ve algo raro y HOME podría rechazarlo al subirlo.
  legalityWarning,
}

class ChampionsEligibility {
  const ChampionsEligibility(this.reasons, {this.canMega = false, this.detail = ''});

  final List<ChampionsReason> reasons;

  /// La especie tiene Megaevolución en el formato.
  final bool canMega;

  /// Primer aviso de legalidad (si [ChampionsReason.legalityWarning]).
  final String detail;

  bool get eligible => reasons.every((r) => r == ChampionsReason.legalityWarning);

  static String reasonText(ChampionsReason r, {required bool es}) => switch (r) {
    ChampionsReason.egg => es ? 'Es un huevo.' : 'It is an egg.',
    ChampionsReason.shadow =>
      es
          ? 'Es un Pokémon oscuro: no puede salir de Colosseum/XD sin purificarlo.'
          : 'It is a Shadow Pokémon: it cannot leave Colosseum/XD until purified.',
    ChampionsReason.mythical => es ? 'Los Pokémon singulares están prohibidos.' : 'Mythical Pokémon are banned.',
    ChampionsReason.restricted =>
      es ? 'Los legendarios restringidos están prohibidos.' : 'Restricted legendaries are banned.',
    ChampionsReason.speciesNotAllowed =>
      es ? 'La especie no está en la lista de la regulación.' : 'The species is not on the regulation list.',
    ChampionsReason.formNotAllowed =>
      es ? 'La especie está permitida, pero no en esta forma.' : 'The species is allowed, but not in this form.',
    ChampionsReason.legalityWarning =>
      es
          ? 'Tiene avisos de legalidad: Pokémon HOME podría rechazarlo.'
          : 'It has legality warnings: Pokémon HOME might reject it.',
  };
}

/// Problema de un equipo completo.
enum ChampionsTeamIssue { tooFew, duplicateSpecies, duplicateItem }

/// Formato oficial vigente de Pokémon Champions.
abstract final class ChampionsFormat {
  /// Regulación vigente (actualízala junto con la tabla generada).
  static final regulation = ChampionsRegulation(
    code: 'M-C',
    from: DateTime(2026, 9, 9),
    until: DateTime(2026, 12, 2),
    datesSource: 'Bulbapedia (calendario de regulaciones de Pokémon Champions)',
    datesConfirmed: false,
  );

  /// Nombre del formato en Showdown (`VGC 2026 Reg M-C`).
  static String get formatName => kChampionsFormatName;
  static String get sourceCommit => kChampionsSourceCommit;
  static String get sourceDate => kChampionsSourceDate;
  static const sourceUrl = 'https://github.com/smogon/pokemon-showdown/blob/master/data/mods/champions/formats-data.ts';
  static List<String> get ruleset => kChampionsRuleset;
  static List<String> get flatRules => kChampionsFlatRules;
  static List<String> get flatBanlist => kChampionsFlatBanlist;

  /// Nivel al que se ajustan los Pokémon («Adjust Level Down = 50»).
  static int get level => _intRule('Adjust Level Down', 50);

  /// Máximo de Pokémon con el mismo objeto («Item Clause = 1»).
  static int get itemClause => _intRule('Item Clause', 1);
  static bool get speciesClause => kChampionsFlatRules.contains('Species Clause');
  static bool get openTeamSheets => kChampionsRuleset.any((r) => r.contains('Open Team Sheets'));

  static int _intRule(String name, int fallback) {
    for (final r in kChampionsFlatRules) {
      if (r.startsWith(name)) return int.tryParse(r.split('=').last.trim()) ?? fallback;
    }
    return fallback;
  }

  /// Fase en la que se juega en dobles (VGC): equipo de 6, se eligen 4.
  static const teamSize = 6;
  static const bringDoubles = 4;
  static const bringSingles = 3;

  static const _mythicals = {
    151, 251, 385, 386, 489, 490, 491, 492, 493, 494, 647, 648, 649, 719, 720, 721, //
    801, 802, 807, 808, 809, 893, 1025,
  };
  static const _restricted = {
    150, 249, 250, 382, 383, 384, 483, 484, 487, 643, 644, 646, 716, 717, 718, //
    789, 790, 791, 792, 800, 888, 889, 890, 898, 1007, 1008, 1024,
  };

  static final List<(int, int)> _allowed = _resolve(kChampionsAllowed);
  static final Set<int> _allowedKeys = {for (final (s, f) in _allowed) s * 100 + f};
  static final Set<int> _allowedSpecies = {for (final (s, _) in _allowed) s};
  static final Set<int> _megaSpecies = {
    for (final id in kChampionsMegas)
      if (Showdown.resolveId(id.replaceAll(RegExp(r'mega[xyz]?$'), ''), GameVersion.scarletViolet) case (final s, _)) s,
  };

  /// Ids de Showdown que no se pudieron traducir a especie y forma.
  static final List<String> unresolved = [
    for (final id in kChampionsAllowed)
      if (_resolveOne(id) == null) id,
  ];

  static (int, int)? _resolveOne(String id) =>
      Showdown.resolveId(id, GameVersion.scarletViolet) ?? Showdown.resolveId(id, GameVersion.legendsZA);

  static List<(int, int)> _resolve(List<String> ids) => [for (final id in ids) ?_resolveOne(id)];

  /// Especies y formas permitidas (orden de la tabla: Pokédex Nacional).
  static List<(int, int)> get allowed => _allowed;

  /// Especies con Megaevolución en la regulación.
  static Set<int> get megaSpecies => _megaSpecies;

  /// Singulares y legendarios restringidos (prohibidos por «Flat Rules»).
  static Set<int> get mythicalSpecies => _mythicals;
  static Set<int> get restrictedSpecies => _restricted;

  static bool isMythical(int species) => _mythicals.contains(species);
  static bool isRestricted(int species) => _restricted.contains(species);

  /// ¿Puede usarse [pk] (de un save de [game]) en el formato?
  static ChampionsEligibility check(Pkm pk, GameVersion game, {DataLanguage lang = DataLanguage.es}) {
    final reasons = <ChampionsReason>[];
    if (pk.isEgg) reasons.add(ChampionsReason.egg);
    if (pk.gc?.isShadow ?? false) reasons.add(ChampionsReason.shadow);
    final s = pk.species, f = pk.form;
    if (_mythicals.contains(s)) {
      reasons.add(ChampionsReason.mythical);
    } else if (_restricted.contains(s)) {
      reasons.add(ChampionsReason.restricted);
    } else if (!_allowedSpecies.contains(s)) {
      reasons.add(ChampionsReason.speciesNotAllowed);
    } else if (!_allowedKeys.contains(s * 100 + f)) {
      // Formas solo estéticas (Vivillon, Alcremie…): cuentan como la forma base.
      final cosmetic = _allowedKeys.contains(s * 100) && !SpeciesForms.formsDiffer(s, 0, f, game);
      if (!cosmetic) reasons.add(ChampionsReason.formNotAllowed);
    }
    var detail = '';
    if (reasons.isEmpty) {
      final warn = Legality.check(pk, game, lang: lang).where((i) => i.severity == LegalitySeverity.warning);
      if (warn.isNotEmpty) {
        reasons.add(ChampionsReason.legalityWarning);
        detail = warn.first.message(lang);
      }
    }
    return ChampionsEligibility(reasons, canMega: _megaSpecies.contains(s), detail: detail);
  }

  /// Problemas del equipo como conjunto (cláusulas y tamaño mínimo).
  static List<(ChampionsTeamIssue, String)> teamIssues(
    List<Pkm> team,
    GameVersion game, {
    DataLanguage lang = DataLanguage.es,
  }) {
    final out = <(ChampionsTeamIssue, String)>[];
    if (team.length < bringDoubles) out.add((ChampionsTeamIssue.tooFew, '$bringDoubles'));
    final species = <int>{}, items = <int, int>{};
    for (final pk in team) {
      if (speciesClause && !species.add(pk.species)) {
        out.add((ChampionsTeamIssue.duplicateSpecies, GameStrings.species(pk.species, lang)));
      }
      if (pk.heldItem != 0) {
        final n = (items[pk.heldItem] ?? 0) + 1;
        items[pk.heldItem] = n;
        if (n == itemClause + 1) {
          out.add((ChampionsTeamIssue.duplicateItem, GameStrings.itemFor(pk.heldItem, game, lang)));
        }
      }
    }
    return out;
  }

  static String teamIssueText((ChampionsTeamIssue, String) i, {required bool es}) => switch (i.$1) {
    ChampionsTeamIssue.tooFew =>
      es ? 'Hacen falta al menos ${i.$2} Pokémon elegibles.' : 'At least ${i.$2} eligible Pokémon are needed.',
    ChampionsTeamIssue.duplicateSpecies =>
      es ? 'Cláusula de especie: ${i.$2} está repetido.' : 'Species clause: ${i.$2} is repeated.',
    ChampionsTeamIssue.duplicateItem =>
      es ? 'Cláusula de objeto: ${i.$2} está repetido.' : 'Item clause: ${i.$2} is repeated.',
  };
}
