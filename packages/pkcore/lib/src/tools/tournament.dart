import '../data/forms.dart';
import '../data/game_data.dart';
import '../legal/legality.dart';
import '../model/game.dart';
import '../pkm/pkm.dart';

/// Reglas de un formato de combate oficial (VGC / Combates Clasificatorios).
///
/// Los datos viven en [TournamentFormats.all], una tabla versionada
/// ([TournamentFormats.dataVersion]): al salir una regulación nueva se añade
/// una entrada y se sube la versión. Ver `docs/usuario/torneos.md`.
class TournamentFormat {
  const TournamentFormat({
    required this.id,
    required this.nameEs,
    required this.nameEn,
    required this.games,
    required this.from,
    this.until,
    this.doubles = true,
    this.level = 50,
    this.teamSize = 6,
    this.minTeam = 4,
    this.speciesClause = true,
    this.itemClause = true,
    this.maxRestricted = 0,
    this.banned = const {},
    this.restricted = const {},
    this.bannedForms = const {},
    this.notesEs = '',
    this.notesEn = '',
  });

  /// Identificador estable (`sv-reg-g`).
  final String id;
  final String nameEs;
  final String nameEn;

  /// Juegos en los que se juega el formato.
  final Set<GameVersion> games;

  /// Temporada: fechas de inicio y fin (null = sin fin conocido).
  final DateTime from;
  final DateTime? until;

  /// Combates dobles (VGC) o individuales.
  final bool doubles;

  /// Nivel al que se ajustan los Pokémon (los de más nivel bajan, los de menos se quedan).
  final int level;
  final int teamSize;

  /// Mínimo de Pokémon para poder inscribir el equipo (4 en dobles, 3 en individuales).
  final int minTeam;
  final bool speciesClause;
  final bool itemClause;

  /// Máximo de Pokémon «restringidos» (legendarios de portada) en el equipo.
  final int maxRestricted;

  /// Especies prohibidas (número de Pokédex Nacional).
  final Set<int> banned;

  /// Especies restringidas (cuentan para [maxRestricted]).
  final Set<int> restricted;

  /// Formas concretas prohibidas (`especie * 100 + forma`).
  final Set<int> bannedForms;
  final String notesEs;
  final String notesEn;

  String name({required bool es}) => es ? nameEs : nameEn;
  String notes({required bool es}) => es ? notesEs : notesEn;
}

/// Problema encontrado al validar un equipo.
enum TournamentIssueCode {
  wrongGame,
  teamTooSmall,
  teamTooLarge,
  egg,
  notInGame,
  banned,
  bannedForm,
  tooManyRestricted,
  duplicateSpecies,
  duplicateItem,
  levelScaled,
  illegal,
}

class TournamentIssue {
  const TournamentIssue(this.code, {this.slot, this.value = '', this.blocking = true});

  final TournamentIssueCode code;

  /// Posición en el equipo (0–5) o null si es del equipo entero.
  final int? slot;
  final String value;

  /// `false` = solo informativo (por ejemplo, el ajuste a nivel 50).
  final bool blocking;

  String message({required bool es}) => switch (code) {
    TournamentIssueCode.wrongGame => es ? 'Este formato se juega en $value.' : 'This format is played in $value.',
    TournamentIssueCode.teamTooSmall =>
      es ? 'Hacen falta al menos $value Pokémon.' : 'At least $value Pokémon are needed.',
    TournamentIssueCode.teamTooLarge => es ? 'Máximo $value Pokémon.' : 'At most $value Pokémon.',
    TournamentIssueCode.egg => es ? 'Los huevos no pueden combatir.' : 'Eggs cannot battle.',
    TournamentIssueCode.notInGame =>
      es ? '$value no está disponible en este juego.' : '$value is not available in this game.',
    TournamentIssueCode.banned => es ? '$value está prohibido en este formato.' : '$value is banned in this format.',
    TournamentIssueCode.bannedForm =>
      es ? 'La forma $value está prohibida en este formato.' : 'The $value form is banned in this format.',
    TournamentIssueCode.tooManyRestricted =>
      es ? 'Demasiados Pokémon restringidos ($value).' : 'Too many restricted Pokémon ($value).',
    TournamentIssueCode.duplicateSpecies =>
      es ? 'Cláusula de especie: $value está repetido.' : 'Species clause: $value is repeated.',
    TournamentIssueCode.duplicateItem =>
      es ? 'Cláusula de objeto: $value está repetido.' : 'Item clause: $value is repeated.',
    TournamentIssueCode.levelScaled =>
      es ? 'Se ajustará al nivel $value durante el combate.' : 'It will be scaled to level $value in battle.',
    TournamentIssueCode.illegal => value,
  };
}

class TournamentReport {
  const TournamentReport(this.format, this.issues);
  final TournamentFormat format;
  final List<TournamentIssue> issues;

  bool get valid => issues.every((i) => !i.blocking);
  List<TournamentIssue> forSlot(int slot) => [
    for (final i in issues)
      if (i.slot == slot) i,
  ];
  List<TournamentIssue> get teamIssues => [
    for (final i in issues)
      if (i.slot == null) i,
  ];
}

/// Tabla versionada de formatos y validador.
abstract final class TournamentFormats {
  /// Versión de los datos de formatos. Súbela al añadir o corregir reglas.
  static const dataVersion = '2026.11.1';

  /// Legendarios restringidos (los «de portada» y equivalentes).
  static const restrictedLegends = {
    150, 249, 250, 382, 383, 384, 483, 484, 487, 643, 644, 646, 716, 717, 718, //
    789, 790, 791, 792, 800, 888, 889, 890, 898, 1007, 1008, 1024,
  };

  /// Singulares (míticos): prohibidos en todos los formatos oficiales.
  static const mythicals = {
    151, 251, 385, 386, 489, 490, 491, 492, 493, 494, 647, 648, 649, 719, 720, 721, //
    801, 802, 807, 808, 809, 893, 1025,
  };

  /// Legendarios no restringidos, Ultraentes y Paradoja (prohibidos en Reg. H).
  static const subLegendsAndParadox = {
    144, 145, 146, 243, 244, 245, 377, 378, 379, 380, 381, 480, 481, 482, 485, 486, 488, //
    638, 639, 640, 641, 642, 645, 772, 773, 785, 786, 787, 788, 793, 794, 795, 796, 797, 798, 799,
    803, 804, 805, 806, 891, 892, 894, 895, 896, 897, 905, //
    984, 985, 986, 987, 988, 989, 990, 991, 992, 993, 994, 995, //
    1001, 1002, 1003, 1004, 1005, 1006, 1009, 1010, 1014, 1015, 1016, 1017, 1020, 1021, 1022, 1023,
  };

  static final _sv = {GameVersion.scarletViolet};
  static final _swsh = {GameVersion.swordShield};

  static final List<TournamentFormat> all = [
    TournamentFormat(
      id: 'sv-reg-i',
      nameEs: 'VGC Escarlata/Púrpura · Regulación I',
      nameEn: 'VGC Scarlet/Violet · Regulation I',
      games: _sv,
      from: DateTime(2025, 5, 1),
      until: DateTime(2025, 8, 31),
      maxRestricted: 2,
      banned: mythicals,
      restricted: restrictedLegends,
      notesEs: 'Dobles a nivel 50, hasta 2 legendarios restringidos, sin singulares.',
      notesEn: 'Doubles at level 50, up to 2 restricted legendaries, no mythicals.',
    ),
    TournamentFormat(
      id: 'sv-reg-h',
      nameEs: 'VGC Escarlata/Púrpura · Regulación H',
      nameEn: 'VGC Scarlet/Violet · Regulation H',
      games: _sv,
      from: DateTime(2024, 9, 1),
      until: DateTime(2025, 1, 5),
      banned: {...mythicals, ...restrictedLegends, ...subLegendsAndParadox},
      notesEs: 'Sin legendarios, singulares, Ultraentes ni Pokémon Paradoja.',
      notesEn: 'No legendaries, mythicals, Ultra Beasts or Paradox Pokémon.',
    ),
    TournamentFormat(
      id: 'sv-reg-g',
      nameEs: 'VGC Escarlata/Púrpura · Regulación G',
      nameEn: 'VGC Scarlet/Violet · Regulation G',
      games: _sv,
      from: DateTime(2024, 5, 1),
      until: DateTime(2025, 4, 30),
      maxRestricted: 1,
      banned: mythicals,
      restricted: restrictedLegends,
      notesEs: 'Dobles a nivel 50, 1 legendario restringido, sin singulares.',
      notesEn: 'Doubles at level 50, 1 restricted legendary, no mythicals.',
    ),
    TournamentFormat(
      id: 'sv-reg-f',
      nameEs: 'VGC Escarlata/Púrpura · Regulación F',
      nameEn: 'VGC Scarlet/Violet · Regulation F',
      games: _sv,
      from: DateTime(2024, 1, 1),
      until: DateTime(2024, 4, 30),
      banned: {...mythicals, ...restrictedLegends},
      notesEs: 'Sin legendarios restringidos ni singulares; Paradoja y legendarios menores permitidos.',
      notesEn: 'No restricted legendaries or mythicals; Paradox and minor legendaries allowed.',
    ),
    TournamentFormat(
      id: 'sv-bss-reg-g',
      nameEs: 'Combates Clasificatorios Individuales · Regulación G',
      nameEn: 'Battle Stadium Singles · Regulation G',
      games: _sv,
      from: DateTime(2024, 5, 1),
      until: DateTime(2025, 4, 30),
      doubles: false,
      minTeam: 3,
      maxRestricted: 1,
      banned: mythicals,
      restricted: restrictedLegends,
      notesEs: 'Individuales: equipo de 6, se eligen 3; 1 restringido.',
      notesEn: 'Singles: team of 6, bring 3; 1 restricted.',
    ),
    TournamentFormat(
      id: 'swsh-series-12',
      nameEs: 'VGC Espada/Escudo · Serie 12',
      nameEn: 'VGC Sword/Shield · Series 12',
      games: _swsh,
      from: DateTime(2022, 2, 1),
      until: DateTime(2022, 10, 31),
      maxRestricted: 2,
      banned: mythicals,
      restricted: restrictedLegends,
      notesEs: 'Dobles a nivel 50, hasta 2 restringidos, sin Gigamax en el campeonato.',
      notesEn: 'Doubles at level 50, up to 2 restricted, no Gigantamax at championships.',
    ),
    TournamentFormat(
      id: 'flat-50',
      nameEs: 'Libre a nivel 50 (sin legendarios restringidos)',
      nameEn: 'Flat level 50 (no restricted legendaries)',
      games: GameVersion.values.where((g) => g.generation >= 6 && !g.isStorage).toSet(),
      from: DateTime(2013, 10, 12),
      banned: {...mythicals, ...restrictedLegends},
      notesEs: 'Formato genérico para cualquier juego desde X/Y.',
      notesEn: 'Generic format for any game from X/Y onwards.',
    ),
  ];

  static TournamentFormat? byId(String id) => all.where((f) => f.id == id).firstOrNull;

  /// Formatos que se juegan en [game] (los vigentes en [today] primero).
  static List<TournamentFormat> forGame(GameVersion game, {DateTime? today}) {
    final d = today ?? DateTime.now();
    bool current(TournamentFormat f) => !d.isBefore(f.from) && (f.until == null || !d.isAfter(f.until!));
    final list = all.where((f) => f.games.contains(game)).toList();
    list.sort((a, b) {
      final c = (current(b) ? 1 : 0).compareTo(current(a) ? 1 : 0);
      return c != 0 ? c : b.from.compareTo(a.from);
    });
    return list;
  }

  /// Valida [team] (el equipo del save) en [format] para [game].
  static TournamentReport validate(
    List<Pkm> team,
    GameVersion game,
    TournamentFormat format, {
    DataLanguage lang = DataLanguage.es,
  }) {
    final es = lang == DataLanguage.es;
    final issues = <TournamentIssue>[];
    if (!format.games.contains(game)) {
      final names = [for (final g in format.games) es ? g.nameEs : g.nameEn];
      issues.add(TournamentIssue(TournamentIssueCode.wrongGame, value: names.take(3).join(', ')));
    }
    if (team.length < format.minTeam) {
      issues.add(TournamentIssue(TournamentIssueCode.teamTooSmall, value: '${format.minTeam}'));
    }
    if (team.length > format.teamSize) {
      issues.add(TournamentIssue(TournamentIssueCode.teamTooLarge, value: '${format.teamSize}'));
    }
    final seenSpecies = <int, int>{};
    final seenItems = <int, int>{};
    var restricted = 0;
    for (var i = 0; i < team.length; i++) {
      final pk = team[i];
      final name = SpeciesForms.displayName(pk.species, pk.form, game, lang);
      if (pk.isEgg) {
        issues.add(TournamentIssue(TournamentIssueCode.egg, slot: i));
        continue;
      }
      final present = SpeciesForms.isPresent(pk.species, pk.form, game);
      if (!present) issues.add(TournamentIssue(TournamentIssueCode.notInGame, slot: i, value: name));
      if (format.banned.contains(pk.species)) {
        issues.add(TournamentIssue(TournamentIssueCode.banned, slot: i, value: name));
      }
      if (format.bannedForms.contains(pk.species * 100 + pk.form)) {
        issues.add(TournamentIssue(TournamentIssueCode.bannedForm, slot: i, value: name));
      }
      if (format.restricted.contains(pk.species)) restricted++;
      if (format.speciesClause) {
        if (seenSpecies.containsKey(pk.species)) {
          issues.add(
            TournamentIssue(
              TournamentIssueCode.duplicateSpecies,
              slot: i,
              value: GameStrings.species(pk.species, lang),
            ),
          );
        }
        seenSpecies.putIfAbsent(pk.species, () => i);
      }
      if (format.itemClause && pk.heldItem != 0) {
        if (seenItems.containsKey(pk.heldItem)) {
          issues.add(
            TournamentIssue(
              TournamentIssueCode.duplicateItem,
              slot: i,
              value: GameStrings.itemFor(pk.heldItem, game, lang),
            ),
          );
        }
        seenItems.putIfAbsent(pk.heldItem, () => i);
      }
      if (pk.level > format.level) {
        issues.add(
          TournamentIssue(TournamentIssueCode.levelScaled, slot: i, value: '${format.level}', blocking: false),
        );
      }
      for (final l in Legality.check(pk, game, lang: lang)) {
        if (l.severity != LegalitySeverity.warning) continue;
        issues.add(TournamentIssue(TournamentIssueCode.illegal, slot: i, value: l.message(lang)));
      }
    }
    if (restricted > format.maxRestricted) {
      issues.add(TournamentIssue(TournamentIssueCode.tooManyRestricted, value: '$restricted/${format.maxRestricted}'));
    }
    return TournamentReport(format, issues);
  }
}
