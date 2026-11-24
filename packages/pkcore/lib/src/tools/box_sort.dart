import '../data/forms.dart';
import '../data/species.dart';
import '../edit/save_editor.dart';
import '../pkm/pkm.dart';

/// Criterio para ordenar las cajas.
enum BoxSortMode {
  /// Número de la Pokédex Nacional (y forma).
  dex,

  /// Primer tipo, después segundo tipo y número de Pokédex.
  type,

  /// Generación de debut de la especie.
  generation,

  /// Cada especie en su hueco (Nº − 1 desde la primera caja del rango);
  /// los repetidos van detrás.
  livingDex,

  /// Nivel, de mayor a menor.
  level,

  /// Variocolores primero, después por Pokédex.
  shinyFirst,
}

/// Resultado de calcular un orden: qué Pokémon va en cada hueco del rango.
class BoxSortPlan {
  BoxSortPlan(this.firstBox, this.lastBox, this.slotsPerBox, this.layout, this.moved, {this.overflow = 0});

  final int firstBox;
  final int lastBox;
  final int slotsPerBox;

  /// Hueco → Pokémon (null = vacío) para todo el rango.
  final Map<SlotRef, Pkm?> layout;

  /// Huecos cuyo contenido cambia.
  final int moved;

  /// Pokémon que no caben en su hueco de living dex (se colocan después).
  final int overflow;

  bool get isNoop => moved == 0;
}

/// Ordena los Pokémon de un rango de cajas sin tocar el equipo ni los huecos
/// bloqueados. Solo calcula el plan; se aplica con `RearrangeSlotsEdit`.
abstract final class BoxSorter {
  static int _typeKey(Pkm pk) {
    final (t1, t2) = SpeciesForms.types(pk.species, pk.form, pk.dataGame);
    return t1.index * 32 + (t2 == PokemonType.none ? 0 : t2.index);
  }

  static int _dexKey(Pkm pk) => pk.isEgg ? 100000 + pk.species : pk.species * 64 + pk.form;

  static int Function(Pkm, Pkm) comparator(BoxSortMode mode) => switch (mode) {
    BoxSortMode.dex || BoxSortMode.livingDex => (a, b) => _dexKey(a).compareTo(_dexKey(b)),
    BoxSortMode.type => (a, b) {
      final c = _typeKey(a).compareTo(_typeKey(b));
      return c != 0 ? c : _dexKey(a).compareTo(_dexKey(b));
    },
    BoxSortMode.generation => (a, b) {
      final c = Species.introducedIn(a.species).compareTo(Species.introducedIn(b.species));
      return c != 0 ? c : _dexKey(a).compareTo(_dexKey(b));
    },
    BoxSortMode.level => (a, b) {
      final c = b.level.compareTo(a.level);
      return c != 0 ? c : _dexKey(a).compareTo(_dexKey(b));
    },
    BoxSortMode.shinyFirst => (a, b) {
      final c = (b.isShiny ? 1 : 0).compareTo(a.isShiny ? 1 : 0);
      return c != 0 ? c : _dexKey(a).compareTo(_dexKey(b));
    },
  };

  /// Calcula el orden de las cajas [firstBox]..[lastBox] (incluidas).
  static BoxSortPlan plan(SaveEditor editor, BoxSortMode mode, {int firstBox = 0, int? lastBox}) {
    final last = (lastBox ?? editor.boxCount - 1).clamp(0, editor.boxCount - 1);
    final first = firstBox.clamp(0, last);
    final per = editor.boxSlotCount;
    final free = <SlotRef>[];
    final mons = <Pkm>[];
    final before = <SlotRef, Pkm?>{};
    for (var b = first; b <= last; b++) {
      for (var s = 0; s < per; s++) {
        final ref = SlotRef.box(b, s);
        if (editor.isSlotLocked(ref)) continue;
        final pk = editor.get(ref);
        before[ref] = pk;
        free.add(ref);
        if (pk != null) mons.add(pk);
      }
    }
    final cmp = comparator(mode);
    // Orden estable: a igualdad se respeta el orden actual.
    final indexed = [for (var i = 0; i < mons.length; i++) (i, mons[i])];
    indexed.sort((a, b) {
      final c = cmp(a.$2, b.$2);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    final sorted = [for (final e in indexed) e.$2];
    final layout = <SlotRef, Pkm?>{for (final r in free) r: null};
    var overflow = 0;
    if (mode == BoxSortMode.livingDex) {
      final rest = <Pkm>[];
      final freeSet = free.toSet();
      for (final pk in sorted) {
        if (pk.isEgg) {
          rest.add(pk);
          continue;
        }
        final idx = pk.species - 1;
        final ref = SlotRef.box(first + idx ~/ per, idx % per);
        if (freeSet.contains(ref) && layout[ref] == null) {
          layout[ref] = pk;
        } else {
          rest.add(pk);
          overflow++;
        }
      }
      // Los demás, en los huecos libres que queden (primero los posteriores
      // al último número usado, para no ocupar huecos de especies que faltan).
      final maxSpecies = sorted.where((p) => !p.isEgg).fold(0, (a, p) => p.species > a ? p.species : a);
      final tail = [
        for (final r in free)
          if (layout[r] == null && ((r.box - first) * per + r.slot) >= maxSpecies) r,
      ];
      final gaps = [
        for (final r in free)
          if (layout[r] == null && ((r.box - first) * per + r.slot) < maxSpecies) r,
      ];
      final targets = [...tail, ...gaps.reversed];
      for (var i = 0; i < rest.length && i < targets.length; i++) {
        layout[targets[i]] = rest[i];
      }
    } else {
      for (var i = 0; i < sorted.length; i++) {
        layout[free[i]] = sorted[i];
      }
    }
    var moved = 0;
    for (final r in free) {
      final a = before[r], b = layout[r];
      if (!identical(a, b)) moved++;
    }
    return BoxSortPlan(first, last, per, Map.unmodifiable(layout), moved, overflow: overflow);
  }
}
