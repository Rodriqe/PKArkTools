import '../legal/ribbons.dart';
import '../pkm/pkm.dart';
import 'event_db.dart';

/// Datos fijos de un evento, deducidos de su plantilla y de sus variantes
/// legales (un dato es «fijo» si es igual en todas).
class EventDetails {
  EventDetails._(this.gift, this.template, this.fixedIvs, this.fixedNature, this.fixedAbilitySlot, this.fixedGender,
      this.ribbons);

  final EventGift gift;
  final Pkm template;

  /// IV fijos por estadística (orden PS, Atq, Def, AtE, DfE, Vel); null = al azar.
  final List<int?> fixedIvs;
  final int? fixedNature;

  /// Ranura de habilidad fija (0, 1, 2 = oculta) o null.
  final int? fixedAbilitySlot;
  final int? fixedGender;

  /// Cintas y marcas que trae (claves de [Ribbons]).
  final List<String> ribbons;

  static final Map<int, EventDetails?> _cache = {};

  static EventDetails? of(EventGift g) => _cache.putIfAbsent(g.id, () {
        final t = g.template();
        if (t == null) return null;
        final all = <Pkm>[t];
        final f = t.format;
        if (g.hasFullVariants) {
          for (final d in g.fullVariants) {
            all.add(Pkm.fromDecrypted(f, d)..dataGame = t.dataGame);
          }
        }
        T? same<T>(T Function(Pkm) get) {
          final v = get(all.first);
          return all.every((p) => get(p) == v) ? v : null;
        }

        final vars = g.variants;
        List<int?> ivs;
        int? nature, slot, gender;
        if (vars.isNotEmpty) {
          ivs = [
            for (var i = 0; i < 6; i++)
              vars.every((v) => v.ivs[i] == t.ivs[i]) ? t.ivs[i] : null,
          ];
          nature = vars.every((v) => v.nature == t.nature) ? t.nature : null;
          slot = vars.every((v) => _slot(v.abilityNumber) == t.abilitySlot) ? t.abilitySlot : null;
          gender = vars.every((v) => v.gender == t.gender) ? t.gender : null;
        } else {
          ivs = [for (var i = 0; i < 6; i++) same((p) => p.ivs[i])];
          nature = same((p) => p.nature);
          slot = same((p) => p.abilitySlot);
          gender = same((p) => p.gender);
        }
        // Con una sola muestra (sin variantes) no se puede saber qué es fijo.
        if (all.length == 1 && vars.isEmpty) {
          ivs = List.filled(6, null);
          nature = slot = gender = null;
        }
        final ribbons = Ribbons.supports(f) ? [for (final s in Ribbons.of(t)) if (s.has) s.info.key] : const <String>[];
        return EventDetails._(g, t, ivs, nature, slot, gender, ribbons);
      });

  static int _slot(int n) => n == 4 ? 2 : (n == 2 ? 1 : 0);

  int get level => template.level;
  int get metLevel => template.metLevel;
  int get ball => template.ball;
  int get heldItem => template.heldItem;
  int get metLocation => template.metLocation;
  bool get fateful => template.fatefulEncounter;
  List<int> get moves => [for (final m in template.moves) if (m != 0) m];
  List<int> get relearnMoves => [for (final m in template.relearnMoves) if (m != 0) m];

  /// Nombre del OT fijo (null si es el de quien lo recibe).
  String? get otName => gift.recipientOt ? null : template.otName;

  /// ID fijo (TID/SID de 16 bits) o null si es el de quien lo recibe.
  (int, int)? get trainerId => gift.recipientId || gift.db == 'pcny' || gift.db == 'pcjp' ? null : (template.tid, template.sid);

  /// ID con el formato del juego: 5 dígitos (Gen 3–6) o 6 dígitos (Gen 7+).
  String? get displayId {
    final id = trainerId;
    if (id == null) return null;
    final (tid, sid) = id;
    if (template.format.generation >= 7) {
      final full = (sid << 16) | tid;
      return (full % 1000000).toString().padLeft(6, '0');
    }
    return tid.toString().padLeft(5, '0');
  }
}
