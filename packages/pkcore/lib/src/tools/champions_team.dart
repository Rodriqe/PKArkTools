import 'dart:convert';
import 'dart:math';

import '../data/species.dart';
import 'champions.dart';
import 'champions_build.dart';
import 'champions_dex.dart';
import 'showdown.dart';

/// Un equipo de Pokémon Champions (hasta 6 miembros).
///
/// Se guarda como JSON legible (`schema` + `schemaVersion`) en
/// `Competitive/Teams/` de la carpeta del Arca. Un miembro que deja de estar
/// permitido cuando cambia la regulación no se borra: se marca.
class ChampionsTeam {
  ChampionsTeam({
    String? id,
    required this.name,
    List<ChampionsBuild>? members,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? newId(),
       members = members ?? <ChampionsBuild>[],
       createdAt = createdAt ?? DateTime.now().toUtc(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now().toUtc();

  static const schema = 'pkarktools-team';
  static const schemaVersion = 1;
  static const maxMembers = 6;

  /// Identificador estable (no cambia al renombrar).
  final String id;
  String name;
  final List<ChampionsBuild> members;
  final DateTime createdAt;
  DateTime updatedAt;

  static final _rand = Random.secure();
  static String newId() => List.generate(12, (_) => _rand.nextInt(36).toRadixString(36)).join();

  /// Copia con otro id y nombre («Duplicar»).
  ChampionsTeam duplicate(String newName) => ChampionsTeam(name: newName, members: [for (final m in members) m.copy()]);

  Map<String, Object?> toJson() => {
    'schema': schema,
    'schemaVersion': schemaVersion,
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'members': [for (final m in members) m.toJson()],
  };

  String encode() => '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';

  /// Lee un equipo. Lanza [FormatException] si no es un equipo o es de una
  /// versión más nueva del esquema.
  static ChampionsTeam decode(String text) {
    final Object? j;
    try {
      j = jsonDecode(text);
    } on FormatException {
      throw const FormatException('not JSON');
    }
    if (j is! Map<String, Object?> || j['schema'] != schema) throw const FormatException('not a team');
    final v = j['schemaVersion'];
    if (v is! int || v < 1) throw const FormatException('schemaVersion');
    if (v > schemaVersion) throw FormatException('schemaVersion $v');
    final members = j['members'];
    return ChampionsTeam(
      id: j['id'] is String && (j['id']! as String).isNotEmpty ? j['id']! as String : null,
      name: j['name'] is String ? j['name']! as String : '',
      members: [
        if (members is List)
          for (final m in members.take(maxMembers))
            if (m is Map<String, Object?>) ChampionsBuild.fromJson(m),
      ],
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
    );
  }

  String toShowdown() => ChampionsBuild.teamToShowdown(members);

  /// Equipo a partir de texto de Showdown (los sets que no se reconocen se
  /// devuelven en `skipped`).
  static ({ChampionsTeam team, List<String> skipped}) fromShowdown(String name, String text) {
    final team = ChampionsTeam(name: name);
    final skipped = <String>[];
    for (final s in Showdown.parse(text)) {
      final r = ChampionsBuild.fromShowdown(s);
      if (r == null || team.members.length >= maxMembers) {
        skipped.add(s.speciesText);
      } else {
        team.members.add(r.build);
      }
    }
    return (team: team, skipped: skipped);
  }

  /// Problemas del equipo como conjunto con la regulación vigente:
  /// cláusulas de especie y de objeto, tamaño y una sola Mega.
  List<String> teamIssues({required bool es}) {
    final out = <String>[];
    if (members.length > maxMembers) {
      out.add(es ? 'Más de $maxMembers Pokémon.' : 'More than $maxMembers Pokémon.');
    }
    final seen = <int>{};
    final items = <String, int>{};
    for (final m in members) {
      final num = m.species?.num;
      if (num != null && ChampionsFormat.speciesClause && !seen.add(num)) {
        out.add(
          ChampionsFormat.teamIssueText((
            ChampionsTeamIssue.duplicateSpecies,
            Species.name(num, es ? SpeciesLanguage.es : SpeciesLanguage.en),
          ), es: es),
        );
      }
      if (m.item.isNotEmpty) {
        final n = (items[m.item] ?? 0) + 1;
        items[m.item] = n;
        if (n == ChampionsFormat.itemClause + 1) {
          out.add(
            ChampionsFormat.teamIssueText((
              ChampionsTeamIssue.duplicateItem,
              ChampionsDex.item(m.item)?.name ?? m.item,
            ), es: es),
          );
        }
      }
    }
    if (members.length < ChampionsFormat.bringDoubles) {
      out.add(ChampionsFormat.teamIssueText((ChampionsTeamIssue.tooFew, '${ChampionsFormat.bringDoubles}'), es: es));
    }
    return out;
  }

  /// Miembros que ya no se permiten en la regulación vigente (índices).
  List<int> notAllowed() => [
    for (final (i, m) in members.indexed)
      if (m.species?.key case final k? when !ChampionsFormat.isAllowed(k.$1, k.$2)) i else if (m.species == null) i,
  ];

  bool get valid => teamIssues(es: false).isEmpty && members.every((m) => m.problems(es: false).isEmpty);
}
