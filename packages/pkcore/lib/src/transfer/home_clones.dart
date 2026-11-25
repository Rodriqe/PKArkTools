import '../legal/origin.dart';
import '../pkm/pkm.dart';

/// Pokémon que comparten rastreador de HOME.
class HomeTrackerCloneGroup<T> {
  const HomeTrackerCloneGroup(this.tracker, this.owners, this.pokemon);

  final int tracker;

  /// Dueño de cada Pokémon (p. ej. id de la partida), en el mismo orden que [pokemon].
  final List<T> owners;
  final List<Pkm> pokemon;
}

/// Clones por rastreador de HOME (como el verificador de clones de PKHeX):
/// cada Pokémon que pasó por HOME tiene un rastreador propio, así que dos
/// con el mismo valor son copias del mismo Pokémon.
abstract final class HomeTrackerClones {
  /// Grupos de dos o más Pokémon con el mismo rastreador (distinto de 0).
  static List<HomeTrackerCloneGroup<T>> find<T>(Iterable<(T, Pkm)> entries) {
    final by = <int, List<(T, Pkm)>>{};
    for (final e in entries) {
      final t = e.$2.homeTracker;
      if (t != 0) (by[t] ??= []).add(e);
    }
    return [
      for (final MapEntry(key: t, value: list) in by.entries)
        if (list.length > 1) HomeTrackerCloneGroup<T>(t, [for (final e in list) e.$1], [for (final e in list) e.$2]),
    ];
  }
}
