import '../legal/encounters.dart';
import '../pkm/pkm.dart';
import 'event_db.dart';

/// Datos fijos de un evento con los que se reconoce un Pokémon (de su plantilla).
class _Key {
  _Key(Pkm t, EventGift g)
      : otNames = {if (!g.recipientOt) t.otName, ...g.otByLanguage.values, if (g.fixedOtName != null) g.fixedOtName!},
        tid = t.tid,
        sid = t.sid,
        metLocation = t.metLocation,
        metLevel = t.metLevel,
        ball = t.ball,
        heldItem = t.heldItem,
        moves = {...t.moves, ...t.relearnMoves}..remove(0);

  final Set<String> otNames;
  final int tid, sid, metLocation, metLevel, ball, heldItem;
  final Set<int> moves;
}

/// Reconoce el evento (Mystery Gift de la base de PKHeX) del que sale un Pokémon.
///
/// Compara los datos que el evento fija y el juego no cambia: especie (o su
/// preevolución), juego de origen, OT e ID cuando no son los de quien lo
/// recibe, lugar y nivel de encuentro y Poké Ball. Es deliberadamente
/// conservador: si algo no cuadra no hay coincidencia (el Pokémon se valida
/// entonces como cualquier otro), nunca un aviso por sí solo.
abstract final class EventMatch {
  static final Map<int, _Key?> _keys = {};

  static _Key? _key(EventGift g) => _keys.putIfAbsent(g.id, () {
        final t = g.template();
        return t == null ? null : _Key(t, g);
      });

  /// Eventos compatibles con [pk] (vacío si no sale de ninguno).
  static List<EventGift> find(Pkm pk) {
    final f = pk.format;
    if (f.isGameBoy || f.generation < 3) return const [];
    final out = <EventGift>[];
    for (final s in EncounterTables.evolutionChain(pk.species)) {
      for (final g in EventDb.forSpecies(s)) {
        if (_matches(g, pk)) out.add(g);
      }
    }
    return out;
  }

  /// El evento más probable de [pk] (el primero de la base), o null.
  static EventGift? best(Pkm pk) {
    final all = find(pk);
    return all.isEmpty ? null : all.first;
  }

  static bool _matches(EventGift g, Pkm pk) {
    if (g.versions.isNotEmpty && !g.versions.contains(pk.version)) return false;
    final k = _key(g);
    if (k == null) return false;
    if (!g.recipientOt && !k.otNames.contains(pk.otName)) return false;
    // Pokémon Center de Gen 3: el ID sale del RNG del regalo.
    final randomId = g.db == 'pcny' || g.db == 'pcjp';
    // Gen 3: algunos (Jirachi de Channel) sacan el SID del RNG; se compara el TID.
    final sidFixed = g.generation > 3;
    if (!g.recipientId && !randomId && (pk.tid != k.tid || (sidFixed && pk.sid != k.sid))) return false;
    if (g.isEgg) return true; // al eclosionar cambian lugar y nivel
    if (pk.ball != k.ball) return false;
    // Traspasado a otra generación (Pal Park, Poké Transfer, Bank, HOME): el
    // lugar y el nivel de encuentro se reescriben; bastan OT, ID, Ball y versión.
    if (pk.format.generation != g.generation) return true;
    return pk.metLocation == k.metLocation && pk.metLevel == k.metLevel;
  }

  /// Movimientos (actuales y recordables) que trae el evento.
  static Set<int> moves(EventGift g) => _key(g)?.moves ?? const {};

  /// Objeto que trae el evento (0 si ninguno).
  static int heldItem(EventGift g) => _key(g)?.heldItem ?? 0;

  /// Poké Ball del evento.
  static int ball(EventGift g) => _key(g)?.ball ?? 0;
}
