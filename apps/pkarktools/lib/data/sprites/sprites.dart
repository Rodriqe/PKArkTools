import 'package:pkcore/pkcore.dart';

import 'sprite_manifest.g.dart';

/// Referencia a un icono del índice (grupo + nombre de archivo sin «.png»).
class SpriteRef {
  const SpriteRef(this.group, this.name);
  final String group;
  final String name;
  String get key => '$group/$name';

  @override
  bool operator ==(Object other) => other is SpriteRef && other.key == key;
  @override
  int get hashCode => key.hashCode;
  @override
  String toString() => key;
}

/// Traduce Pokémon, objetos, Balls, tipos y cintas a iconos del índice
/// (nombres de PKHeX `SpriteName`), comprobando que existan.
abstract final class Sprites {
  static final Map<String, Set<String>> _names = {
    for (final e in kSpriteFiles.entries) e.key: {for (final f in e.value.split(',')) f.substring(0, f.lastIndexOf(':'))},
  };

  /// Lienzo de referencia de cada grupo (el mayor de sus PNG). Todos los
  /// iconos de un grupo se dibujan a la misma escala sobre este lienzo, así
  /// el tamaño relativo entre ellos es el del juego (un objeto de 16×16 no se
  /// amplía como uno de 32×32, ni un Joltik como un Wailord).
  static const Map<String, (int, int)> canvas = {
    'pokemon': (68, 56),
    'shiny': (68, 56),
    'item': (32, 32),
    'ball': (20, 20),
    'type': (60, 60),
    'ribbon': (40, 40),
  };

  static bool exists(String group, String name) => _names[group]?.contains(name) ?? false;

  static final Map<String, int> _bytesByKey = {
    for (final e in kSpriteFiles.entries)
      for (final f in e.value.split(','))
        '${e.key}/${f.substring(0, f.lastIndexOf(':'))}': int.parse(f.substring(f.lastIndexOf(':') + 1)),
  };

  /// Tamaño exacto en bytes de un icono según el índice (0 si no existe).
  static int bytesOfRef(SpriteRef ref) => _bytesByKey[ref.key] ?? 0;

  static int bytesOf(String group) =>
      kSpriteFiles[group]!.split(',').fold(0, (a, f) => a + int.parse(f.substring(f.lastIndexOf(':') + 1)));

  /// Especies que solo cambian de sprite por género (PKHeX `SpeciesGenderedSprite`).
  static const _gendered = {449, 450, 521, 592, 593, 668};

  /// Especies que muestran siempre la forma base (PKHeX `SpeciesDefaultFormSprite`).
  static const _defaultForm = {414, 664, 665, 744, 778, 854, 855, 892, 982, 1012, 1013};

  /// Icono de un Pokémon. Si no hay sprite de la forma, el género o el
  /// variocolor, cae a la forma base / normal.
  static SpriteRef? pokemon(int species, {int form = 0, bool female = false, bool shiny = false, bool egg = false}) {
    if (egg) return const SpriteRef('pokemon', 'b_egg');
    if (species <= 0) return null;
    final f = _defaultForm.contains(species) ? 0 : form;
    final g = female && _gendered.contains(species) ? 'f' : '';
    final candidates = [
      if (f > 0) 'b_$species-$f$g',
      'b_$species$g',
      'b_$species',
    ];
    if (shiny) {
      for (final c in candidates) {
        if (exists('shiny', '${c}s')) return SpriteRef('shiny', '${c}s');
      }
    }
    for (final c in candidates) {
      if (exists('pokemon', c)) return SpriteRef('pokemon', c);
    }
    return null;
  }

  /// Icono de un objeto. [generation] indica en qué numeración está [item]
  /// (Gen 2 y 3 usan la suya; Gen 4+ la moderna).
  static SpriteRef? item(int item, {int generation = 9}) {
    if (item <= 0) return null;
    var id = item;
    if (generation == 3) id = item < kItem3to4.length ? kItem3to4[item] : 65535;
    if (generation == 2) id = item < kItem2to4.length ? kItem2to4[item] : 65535;
    if (generation <= 1) return null;
    if (id <= 0 || id == 65535) return null;
    return exists('item', 'bitem_$id') ? SpriteRef('item', 'bitem_$id') : null;
  }

  /// Icono de una Poké Ball (ids de PKHeX `Ball`).
  static SpriteRef? ball(int ball) => exists('ball', '_ball$ball') ? SpriteRef('ball', '_ball$ball') : null;

  /// Icono de un tipo elemental.
  static SpriteRef? type(PokemonType t) {
    if (t == PokemonType.none) return null;
    final n = 'type_icon_${(t.index - 1).toString().padLeft(2, '0')}';
    return exists('type', n) ? SpriteRef('type', n) : null;
  }

  /// Icono de una cinta o marca (por su nombre de propiedad en PKHeX).
  static SpriteRef? ribbon(String key) {
    final n = key.toLowerCase();
    return exists('ribbon', n) ? SpriteRef('ribbon', n) : null;
  }
}
