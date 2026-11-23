import 'package:pkcore/pkcore.dart';

import '../../data/arca_repository.dart';

/// Orden de las tarjetas del Arca.
enum ArcaSort { recent, trainer, game, playTime, copies }

/// Filtros de estado.
enum ArcaStatus { damaged, legality, edited, multipleCopies }

/// Atajos de fecha de la última copia (relativos a hoy, para que una
/// selección recordada siga teniendo sentido otro día).
enum DatePreset { week, month, year }

/// Grupos de filtro (para contar resultados por opción sin el propio grupo).
enum FilterGroup { generation, platform, source, game, status, date }

/// Selección de filtros y orden de la pestaña Arca. Inmutable.
///
/// Dentro de un grupo las opciones se suman (O); entre grupos se combinan (Y).
class ArcaFilter {
  const ArcaFilter({
    this.query = '',
    this.generations = const {},
    this.platforms = const {},
    this.sources = const {},
    this.games = const {},
    this.statuses = const {},
    this.datePreset,
    this.from,
    this.to,
    this.sort = ArcaSort.recent,
  });

  final String query;
  final Set<int> generations;
  final Set<Platform> platforms;
  final Set<SaveSource> sources;

  /// Claves de [gameKey].
  final Set<String> games;
  final Set<ArcaStatus> statuses;
  final DatePreset? datePreset;

  /// Rango propio (días completos, inclusivo). Se ignora si hay [datePreset].
  final DateTime? from;
  final DateTime? to;
  final ArcaSort sort;

  static const none = ArcaFilter();

  /// Juego concreto: familia + versión (Espada y Escudo son dos opciones).
  static String gameKey(ArcaEntry e) => '${e.slot.gameCode}:${e.slot.versionId ?? ''}';

  bool get hasDate => datePreset != null || from != null || to != null;

  /// Número de filtros activos (sin contar búsqueda ni orden).
  int get activeCount =>
      generations.length + platforms.length + sources.length + games.length + statuses.length + (hasDate ? 1 : 0);

  bool get isActive => activeCount > 0 || query.trim().isNotEmpty;

  ArcaFilter copyWith({
    String? query,
    Set<int>? generations,
    Set<Platform>? platforms,
    Set<SaveSource>? sources,
    Set<String>? games,
    Set<ArcaStatus>? statuses,
    DatePreset? Function()? datePreset,
    DateTime? Function()? from,
    DateTime? Function()? to,
    ArcaSort? sort,
  }) =>
      ArcaFilter(
        query: query ?? this.query,
        generations: generations ?? this.generations,
        platforms: platforms ?? this.platforms,
        sources: sources ?? this.sources,
        games: games ?? this.games,
        statuses: statuses ?? this.statuses,
        datePreset: datePreset != null ? datePreset() : this.datePreset,
        from: from != null ? from() : this.from,
        to: to != null ? to() : this.to,
        sort: sort ?? this.sort,
      );

  /// Quita todos los filtros; conserva el orden y, si se pide, la búsqueda.
  ArcaFilter cleared({bool keepQuery = false}) => ArcaFilter(sort: sort, query: keepQuery ? query : '');

  /// El mismo filtro sin el grupo [g] (para contar opciones de ese grupo).
  ArcaFilter without(FilterGroup g) => switch (g) {
        FilterGroup.generation => copyWith(generations: const {}),
        FilterGroup.platform => copyWith(platforms: const {}),
        FilterGroup.source => copyWith(sources: const {}),
        FilterGroup.game => copyWith(games: const {}),
        FilterGroup.status => copyWith(statuses: const {}),
        FilterGroup.date => copyWith(datePreset: () => null, from: () => null, to: () => null),
      };

  static Set<T> toggled<T>(Set<T> s, T v) => s.contains(v) ? ({...s}..remove(v)) : {...s, v};

  /// Inicio del rango de fechas efectivo (null = sin límite).
  DateTime? effectiveFrom(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (datePreset) {
      DatePreset.week => today.subtract(const Duration(days: 6)),
      DatePreset.month => today.subtract(const Duration(days: 29)),
      DatePreset.year => today.subtract(const Duration(days: 364)),
      null => from == null ? null : DateTime(from!.year, from!.month, from!.day),
    };
  }

  /// Fin (exclusivo) del rango de fechas efectivo.
  DateTime? effectiveTo(DateTime now) =>
      datePreset != null || to == null ? null : DateTime(to!.year, to!.month, to!.day).add(const Duration(days: 1));

  /// ¿Pasa [e] el filtro? [titleOf] da el nombre visible del juego (para la
  /// búsqueda); [warnings] los avisos de legalidad ya calculados por id de
  /// copia (una partida sin calcular no pasa el filtro de legalidad).
  bool matches(
    ArcaEntry e, {
    required DateTime now,
    String Function(ArcaEntry e)? titleOf,
    Map<int, int> warnings = const {},
  }) {
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty &&
        !e.slot.trainerName.toLowerCase().contains(q) &&
        !(titleOf?.call(e).toLowerCase().contains(q) ?? false)) {
      return false;
    }
    if (generations.isNotEmpty && !generations.contains(e.slot.generation)) return false;
    if (platforms.isNotEmpty && !platforms.contains(e.game.platform)) return false;
    if (sources.isNotEmpty && !e.sources.any(sources.contains)) return false;
    if (games.isNotEmpty && !games.contains(gameKey(e))) return false;
    if (statuses.isNotEmpty && !statuses.any((s) => _status(e, s, warnings))) return false;
    final at = e.latest.importedAt;
    final lo = effectiveFrom(now), hi = effectiveTo(now);
    if (lo != null && at.isBefore(lo)) return false;
    if (hi != null && !at.isBefore(hi)) return false;
    return true;
  }

  static bool _status(ArcaEntry e, ArcaStatus s, Map<int, int> warnings) => switch (s) {
        ArcaStatus.damaged => e.damaged,
        ArcaStatus.legality => (warnings[e.latest.id] ?? 0) > 0,
        ArcaStatus.edited => e.edited,
        ArcaStatus.multipleCopies => e.snapshotCount > 1,
      };

  /// Filtra y ordena.
  List<ArcaEntry> apply(
    List<ArcaEntry> all, {
    required DateTime now,
    String Function(ArcaEntry e)? titleOf,
    Map<int, int> warnings = const {},
  }) {
    final out = [for (final e in all) if (matches(e, now: now, titleOf: titleOf, warnings: warnings)) e];
    int recent(ArcaEntry a, ArcaEntry b) {
      final c = b.latest.importedAt.compareTo(a.latest.importedAt);
      return c != 0 ? c : b.slot.id.compareTo(a.slot.id);
    }

    int byName(ArcaEntry a, ArcaEntry b) {
      final c = a.slot.trainerName.toLowerCase().compareTo(b.slot.trainerName.toLowerCase());
      return c != 0 ? c : recent(a, b);
    }

    out.sort(switch (sort) {
      ArcaSort.recent => recent,
      ArcaSort.trainer => byName,
      ArcaSort.game => (a, b) {
          final c = a.game.index.compareTo(b.game.index);
          if (c != 0) return c;
          final v = (a.slot.versionId ?? 0).compareTo(b.slot.versionId ?? 0);
          return v != 0 ? v : byName(a, b);
        },
      ArcaSort.playTime => (a, b) {
          final c = b.latest.playTimeSeconds.compareTo(a.latest.playTimeSeconds);
          return c != 0 ? c : recent(a, b);
        },
      ArcaSort.copies => (a, b) {
          final c = b.snapshotCount.compareTo(a.snapshotCount);
          return c != 0 ? c : recent(a, b);
        },
    });
    return out;
  }

  // ---- Persistencia (ajustes locales de este dispositivo) ----

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// La búsqueda no se guarda: es de la sesión.
  Map<String, Object?> toJson() => {
        'v': 1,
        'sort': sort.name,
        if (generations.isNotEmpty) 'gen': (generations.toList()..sort()),
        if (platforms.isNotEmpty) 'platform': [for (final p in platforms) p.name],
        if (sources.isNotEmpty) 'source': [for (final s in sources) s.name],
        if (games.isNotEmpty) 'game': games.toList(),
        if (statuses.isNotEmpty) 'status': [for (final s in statuses) s.name],
        if (datePreset != null) 'preset': datePreset!.name,
        if (from != null) 'from': _day(from!),
        if (to != null) 'to': _day(to!),
      };

  /// Tolerante: lo que no reconoce se descarta.
  static ArcaFilter fromJson(Map<String, Object?>? j) {
    if (j == null) return none;
    Set<T> names<T extends Enum>(String k, List<T> values) => {
          for (final n in (j[k] as List?) ?? const [])
            for (final v in values)
              if (v.name == n) v,
        };
    T? one<T extends Enum>(String k, List<T> values) {
      for (final v in values) {
        if (v.name == j[k]) return v;
      }
      return null;
    }

    DateTime? day(String k) => j[k] is String ? DateTime.tryParse(j[k] as String) : null;
    return ArcaFilter(
      sort: one('sort', ArcaSort.values) ?? ArcaSort.recent,
      generations: {
        for (final g in (j['gen'] as List?) ?? const [])
          if (g is int && g >= 1 && g <= 9) g,
      },
      platforms: names('platform', Platform.values),
      sources: names('source', SaveSource.values),
      games: {
        for (final g in (j['game'] as List?) ?? const [])
          if (g is String) g,
      },
      statuses: names('status', ArcaStatus.values),
      datePreset: one('preset', DatePreset.values),
      from: day('from'),
      to: day('to'),
    );
  }
}
