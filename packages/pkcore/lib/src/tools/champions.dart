import 'dart:convert';

import '../data/forms.dart';
import '../data/game_data.dart';
import '../data/generated/champions_data.dart';
import '../legal/legality.dart';
import '../model/game.dart';
import '../pkm/pkm.dart';
import 'showdown.dart';

/// Una regulación de Pokémon Champions con sus fechas.
///
/// Las fechas salen de la página oficial de la regulación (noticias del
/// juego, ver `tool/champions_official.py`) y pueden faltar.
class ChampionsRegulation {
  const ChampionsRegulation({
    required this.code,
    this.name = '',
    required this.from,
    required this.until,
    required this.datesSource,
    required this.datesConfirmed,
  });

  /// Código de la regulación (`M-C`).
  final String code;

  /// Nombre del formato en Showdown (`VGC 2026 Reg M-C`); vacío si solo se
  /// conoce por la tabla de fechas.
  final String name;
  final DateTime? from;
  final DateTime? until;

  /// De dónde salen las fechas.
  final String datesSource;

  /// `false` si las fechas no se han podido confirmar en una fuente oficial:
  /// la interfaz lo indica.
  final bool datesConfirmed;
}

/// Un JSON de datos del formato que no se puede usar.
class ChampionsDataException implements Exception {
  const ChampionsDataException(this.message, {this.futureSchema});
  final String message;

  /// `schemaVersion` del JSON si es mayor que el que entiende esta versión de
  /// la app (hay que actualizar la app para usarlo).
  final int? futureSchema;

  @override
  String toString() => 'ChampionsDataException: $message';
}

/// Datos del formato oficial: los genera `tool/gen_champions_data.py` desde
/// las fuentes oficiales del juego, con Pokémon Showdown para Flat Rules,
/// Megas y comprobación (`data/champions/champions.json`, que la app descarga
/// de GitHub, y su copia integrada `champions_data.dart`).
class ChampionsData {
  ChampionsData._({
    required this.schemaVersion,
    required this.generatedAt,
    required this.sourceCommit,
    required this.sourceDate,
    required this.sourceUrl,
    required this.regulation,
    required this.nextRegulation,
    required this.regulations,
    required this.ruleset,
    required this.flatRulesDesc,
    required this.flatRules,
    required this.flatBanlist,
    required this.allowedIds,
    required this.megaIds,
  });

  /// Versión del esquema que entiende esta versión de la app.
  static const supportedSchemaVersion = 1;

  /// El JSON de la copia que lleva la app.
  static String get builtinJson => kChampionsBuiltinJson;

  /// La copia que lleva la app.
  static final ChampionsData builtin = ChampionsData.parse(kChampionsBuiltinJson);

  final int schemaVersion;
  final DateTime generatedAt;
  final String sourceCommit;

  /// Fecha del commit de Showdown (`AAAA-MM-DD`).
  final String sourceDate;
  final String sourceUrl;
  final ChampionsRegulation regulation;

  /// La siguiente regulación, si Showdown ya la tiene.
  final ChampionsRegulation? nextRegulation;

  /// Calendario de todas las regulaciones conocidas.
  final List<ChampionsRegulation> regulations;
  final List<String> ruleset;
  final String flatRulesDesc;
  final List<String> flatRules;
  final List<String> flatBanlist;

  /// Especies y formas legales (ids de Showdown), sin Megaevoluciones.
  final List<String> allowedIds;

  /// Megaevoluciones disponibles (ids de Showdown).
  final List<String> megaIds;

  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _id = RegExp(r'^[a-z0-9]+$');

  /// Lee y valida un JSON (lanza [ChampionsDataException]).
  static ChampionsData parse(String text) {
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException catch (e) {
      throw ChampionsDataException('JSON: ${e.message}');
    }
    if (root is! Map<String, Object?>) throw const ChampionsDataException('not an object');
    final v = root['schemaVersion'];
    if (v is! int || v < 1) throw const ChampionsDataException('schemaVersion');
    if (v > supportedSchemaVersion) throw ChampionsDataException('schemaVersion $v', futureSchema: v);
    return fromJson(root);
  }

  static ChampionsData fromJson(Map<String, Object?> j) {
    Never bad(String what) => throw ChampionsDataException(what);
    T get<T>(Map<String, Object?> m, String k) => m[k] is T ? m[k] as T : bad(k);
    List<String> strings(Object? l, String k) =>
        l is List && l.every((e) => e is String) ? l.cast<String>().toList(growable: false) : bad(k);
    DateTime? day(Object? s, String k) {
      if (s == null) return null;
      if (s is! String || !_date.hasMatch(s)) bad(k);
      return DateTime.parse(s);
    }

    ChampionsRegulation reg(Object? o, String k) {
      if (o is! Map<String, Object?>) bad(k);
      final code = get<String>(o, 'code');
      final name = get<String>(o, 'name');
      if (code.isEmpty || !name.startsWith('VGC ') || !name.endsWith('Reg $code')) bad('$k.name');
      return ChampionsRegulation(
        code: code,
        name: name,
        from: day(o['from'], '$k.from'),
        until: day(o['until'], '$k.until'),
        datesSource: get<String>(o, 'datesSource'),
        datesConfirmed: get<bool>(o, 'datesConfirmed'),
      );
    }

    final generatedAt = DateTime.tryParse(get<String>(j, 'generatedAt')) ?? bad('generatedAt');
    final source = get<Map<String, Object?>>(j, 'source');
    final commit = get<String>(source, 'commit');
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) bad('source.commit');
    final sourceDate = get<String>(source, 'date');
    day(sourceDate, 'source.date');
    final sourceUrl = get<String>(source, 'url');
    final url = Uri.tryParse(sourceUrl);
    if (url == null || url.scheme != 'https' || url.host != 'github.com') bad('source.url');
    final regulation = reg(j['regulation'], 'regulation');
    if (regulation.from == null || regulation.until == null || !regulation.from!.isBefore(regulation.until!)) {
      bad('regulation dates');
    }
    final next = j['nextRegulation'] == null ? null : reg(j['nextRegulation'], 'nextRegulation');
    final regs = j['regulations'];
    if (regs is! List) bad('regulations');
    final regulations = [
      for (final r in regs)
        if (r is Map<String, Object?>)
          ChampionsRegulation(
            code: get<String>(r, 'code'),
            from: day(r['from'], 'regulations.from'),
            until: day(r['until'], 'regulations.until'),
            datesSource: get<String>(r, 'source'),
            datesConfirmed: get<bool>(r, 'confirmed'),
          )
        else
          bad('regulations'),
    ];
    final flat = get<Map<String, Object?>>(j, 'flatRules');
    final allowed = strings(j['allowed'], 'allowed');
    final megas = strings(j['megas'], 'megas');
    // Una lista de la regulación tiene unas 200-300 especies y formas.
    if (allowed.length < 150 || allowed.length > 600 || allowed.toSet().length != allowed.length) bad('allowed');
    if (megas.isEmpty) bad('megas');
    if (![...allowed, ...megas].every(_id.hasMatch)) bad('ids');
    final rules = strings(flat['rules'], 'flatRules.rules');
    final ban = strings(flat['banlist'], 'flatRules.banlist');
    final ruleset = strings(j['ruleset'], 'ruleset');
    if (!ruleset.contains('Flat Rules') || !rules.contains('Species Clause')) bad('ruleset');
    if (!ban.contains('Mythical') || !ban.contains('Restricted Legendary')) bad('flatRules.banlist');
    return ChampionsData._(
      schemaVersion: get<int>(j, 'schemaVersion'),
      generatedAt: generatedAt,
      sourceCommit: commit,
      sourceDate: sourceDate,
      sourceUrl: sourceUrl,
      regulation: regulation,
      nextRegulation: next,
      regulations: regulations,
      ruleset: ruleset,
      flatRulesDesc: get<String>(flat, 'desc'),
      flatRules: rules,
      flatBanlist: ban,
      allowedIds: allowed,
      megaIds: megas,
    );
  }

  /// ¿Es más reciente que [other]? (por la fecha en que se generó).
  bool isNewerThan(ChampionsData other) => generatedAt.isAfter(other.generatedAt);

  // Tablas derivadas (se calculan una vez por juego de datos).
  late final List<(int, int)> allowed = [for (final id in allowedIds) ?_resolveOne(id)];
  late final Set<int> allowedKeys = {for (final (s, f) in allowed) s * 100 + f};
  late final Set<int> allowedSpecies = {for (final (s, _) in allowed) s};
  late final Set<int> megaSpecies = {
    for (final id in megaIds)
      if (Showdown.resolveId(id.replaceAll(RegExp(r'mega[xyz]?$'), ''), GameVersion.scarletViolet) case (final s, _)) s,
  };
  late final List<String> unresolved = [
    for (final id in allowedIds)
      if (_resolveOne(id) == null) id,
  ];

  static (int, int)? _resolveOne(String id) =>
      Showdown.resolveId(id, GameVersion.scarletViolet) ?? Showdown.resolveId(id, GameVersion.legendsZA);
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
  static ChampionsData _data = ChampionsData.builtin;

  /// Datos en uso: la copia integrada o la última descargada
  /// (ver `docs/usuario/formato-oficial.md`).
  static ChampionsData get data => _data;

  /// Cambia los datos en uso (la app, al descargar unos nuevos).
  static void use(ChampionsData d) => _data = d;

  /// Vuelve a la copia integrada.
  static void reset() => _data = ChampionsData.builtin;

  /// Regulación vigente.
  static ChampionsRegulation get regulation => _data.regulation;

  /// La siguiente regulación, si ya se conoce.
  static ChampionsRegulation? get nextRegulation => _data.nextRegulation;

  /// Nombre del formato en Showdown (`VGC 2026 Reg M-C`).
  static String get formatName => _data.regulation.name;
  static String get sourceCommit => _data.sourceCommit;
  static String get sourceDate => _data.sourceDate;
  static String get sourceUrl => _data.sourceUrl;
  static List<String> get ruleset => _data.ruleset;
  static List<String> get flatRules => _data.flatRules;
  static List<String> get flatBanlist => _data.flatBanlist;

  /// Nivel al que se ajustan los Pokémon («Adjust Level Down = 50»).
  static int get level => _intRule('Adjust Level Down', 50);

  /// Máximo de Pokémon con el mismo objeto («Item Clause = 1»).
  static int get itemClause => _intRule('Item Clause', 1);
  static bool get speciesClause => flatRules.contains('Species Clause');
  static bool get openTeamSheets => ruleset.any((r) => r.contains('Open Team Sheets'));

  static int _intRule(String name, int fallback) {
    for (final r in flatRules) {
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

  /// Ids de Showdown que no se pudieron traducir a especie y forma.
  static List<String> get unresolved => _data.unresolved;

  /// Especies y formas permitidas (orden de la tabla: Pokédex Nacional).
  static List<(int, int)> get allowed => _data.allowed;

  /// Especies con Megaevolución en la regulación.
  static Set<int> get megaSpecies => _data.megaSpecies;

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
    } else if (!_data.allowedSpecies.contains(s)) {
      reasons.add(ChampionsReason.speciesNotAllowed);
    } else if (!_data.allowedKeys.contains(s * 100 + f)) {
      // Formas solo estéticas (Vivillon, Alcremie…): cuentan como la forma base.
      final cosmetic = _data.allowedKeys.contains(s * 100) && !SpeciesForms.formsDiffer(s, 0, f, game);
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
    return ChampionsEligibility(reasons, canMega: _data.megaSpecies.contains(s), detail: detail);
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
