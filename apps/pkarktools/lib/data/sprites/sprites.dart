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

/// Traduce Pokémon (iconos de HOME de smogon/sprites), objetos, Balls, tipos
/// y cintas (nombres de PKHeX `SpriteName`) a iconos del índice, comprobando
/// que existan.
abstract final class Sprites {
  static final Map<String, Set<String>> _names = {
    for (final e in kSpriteFiles.entries) e.key: {for (final f in e.value.split(',')) f.substring(0, f.lastIndexOf(':'))},
  };

  /// Lado de referencia del contenido de cada grupo (en píxeles del sprite):
  /// el percentil 92 del contenido no transparente de todo el set, medido
  /// por `tool/gen_sprite_manifest.py`. Todos los iconos de un grupo se
  /// dibujan a la misma escala, la que hace que este lado llene [fill] del
  /// hueco; los pocos que lo superan ([needOf]) se reducen lo justo.
  static double contentRef(String group) => kSpriteContentRef[group] ?? 32;

  /// Fracción del hueco que llena el recuadro de referencia de cada grupo.
  /// Los Pokémon y los objetos dejan un margen; tipos, cintas y Balls ya
  /// ocupan su lienzo entero.
  static const Map<String, double> fill = {'pokemon': 0.88, 'item': 0.88};

  /// Grupos de arte de píxeles (se amplían con vecino más próximo). Los
  /// iconos de HOME, tipos y cintas son ilustraciones y se suavizan.
  static bool isPixelArt(String group) => group == 'item' || group == 'ball';

  static final Map<String, double> _oversize = {
    for (final e in kSpriteOversize.entries)
      if (e.value.isNotEmpty)
        for (final f in e.value.split(','))
          '${e.key}/${f.substring(0, f.lastIndexOf(':'))}': double.parse(f.substring(f.lastIndexOf(':') + 1)),
  };

  /// Lado que necesita el contenido de [ref] si supera la referencia de su
  /// grupo (si no, null).
  static double? needOf(SpriteRef ref) => _oversize[ref.key];

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

  /// Icono de un Pokémon (iconos de HOME). Una forma sin icono propio usa el
  /// de la especie; con hembra, el de hembra si lo hay. No hay iconos
  /// variocolor: [shiny] no cambia el archivo (la interfaz pone la insignia).
  static SpriteRef? pokemon(int species, {int form = 0, bool female = false, bool shiny = false, bool egg = false}) {
    if (egg) return exists('pokemon', kPokemonIconEgg) ? const SpriteRef('pokemon', kPokemonIconEgg) : null;
    if (species <= 0 || species >= kPokemonIconBase.length) return null;
    final byForm = kPokemonIconForms['$species-$form'];
    if (byForm != null && byForm != kPokemonIconBase[species]) return SpriteRef('pokemon', byForm);
    final base = kPokemonIconBase[species];
    if (female && kPokemonIconFemale.contains(species) && exists('pokemon', '$base-f')) {
      return SpriteRef('pokemon', '$base-f');
    }
    return exists('pokemon', base) ? SpriteRef('pokemon', base) : null;
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
