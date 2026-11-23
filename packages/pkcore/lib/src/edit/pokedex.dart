import 'dart:typed_data';

import '../data/game_data.dart';
import '../model/game.dart';

/// Estado de una especie en la Pokédex.
///
/// [genders] y [forms] son máscaras de bits (bit 0 = macho/sin género,
/// bit 1 = hembra; bit n = forma n) y valen null cuando el juego no los guarda
/// o no se quieren cambiar al aplicar.
class DexEntry {
  const DexEntry(this.species, {this.seen = false, this.caught = false, this.shiny = false, this.genders, this.forms});

  final int species;
  final bool seen;
  final bool caught;

  /// Visto variocolor (solo en juegos que lo guardan, ver [Pokedex.hasShiny]).
  final bool shiny;

  /// Géneros vistos (bit 0 macho/sin género, bit 1 hembra), si el juego lo guarda.
  final int? genders;

  /// Formas vistas (bit n = forma n), si el juego lo guarda.
  final int? forms;

  bool genderSeen(int g) => genders != null && (genders! >> g) & 1 == 1;
  bool formSeen(int f) => forms != null && (forms! >> f) & 1 == 1;

  DexEntry copyWith({bool? seen, bool? caught, bool? shiny, int? genders, int? forms}) => DexEntry(species,
      seen: seen ?? this.seen,
      caught: caught ?? this.caught,
      shiny: shiny ?? this.shiny,
      genders: genders ?? this.genders,
      forms: forms ?? this.forms);

  @override
  bool operator ==(Object other) =>
      other is DexEntry &&
      other.species == species &&
      other.seen == seen &&
      other.caught == caught &&
      other.shiny == shiny &&
      other.genders == genders &&
      other.forms == forms;

  @override
  int get hashCode => Object.hash(species, seen, caught, shiny, genders, forms);

  @override
  String toString() => '#$species${seen ? ' visto' : ''}${caught ? ' capturado' : ''}${shiny ? ' ✦' : ''}'
      '${genders != null ? ' g=$genders' : ''}${forms != null ? ' f=$forms' : ''}';
}

/// Acceso a la Pokédex de un save. Las especies van en orden nacional (1…[maxSpecies]).
///
/// Las implementaciones escriben directamente sobre los bytes de trabajo del
/// editor; los checksums se recalculan al construir el archivo.
abstract class Pokedex {
  /// Última especie que registra la Pokédex del juego.
  int get maxSpecies;

  /// `true` si el juego guarda "visto variocolor".
  bool get hasShiny => false;

  /// `true` si el juego guarda por separado macho y hembra vistos.
  bool get hasGender => false;

  /// `true` si el juego guarda las formas vistas.
  bool get hasForms => false;

  /// Nombre del formato (para la interfaz y los informes).
  String get description;

  /// `true` si la especie tiene entrada en la Pokédex de este juego (las
  /// Pokédex regionales de Switch solo guardan una parte de las especies).
  bool contains(int species) => species >= 1 && species <= maxSpecies;

  /// Pokédex regionales del juego, en orden (vacío = solo nacional).
  List<String> get regions => const [];

  /// Pokédex regional y número dentro de ella, si la especie pertenece a alguna.
  (String, int)? regionalNumber(int species) => null;

  /// Número de formas que registra la Pokédex para la especie (1 = sin formas).
  int formCount(int species) => 1;

  /// `false` para formas que existen pero no se pueden registrar en este juego.
  bool formAvailable(int species, int form) => form < formCount(species);

  /// Nivel de investigación (0–100) en Leyendas Arceus; null en el resto.
  int? researchLevel(int species) => null;

  bool isSeen(int species);
  bool isCaught(int species);
  bool isShinySeen(int species) => false;

  /// Máscara de géneros vistos (bit 0 macho/sin género, bit 1 hembra).
  int genderMask(int species) => 0;

  /// Máscara de formas vistas.
  int formMask(int species) => 0;

  void setSeen(int species, bool value);
  void setCaught(int species, bool value);
  void setShinySeen(int species, bool value) {}
  void setGenderSeen(int species, int gender, bool value) {}
  void setFormSeen(int species, int form, bool value) {}

  DexEntry entry(int species) => DexEntry(species,
      seen: isSeen(species),
      caught: isCaught(species),
      shiny: hasShiny && isShinySeen(species),
      genders: hasGender ? genderMask(species) : null,
      forms: hasForms && formCount(species) > 1 ? formMask(species) : null);

  /// Especies registrables, en orden nacional.
  Iterable<int> get species sync* {
    for (var s = 1; s <= maxSpecies; s++) {
      if (contains(s)) yield s;
    }
  }

  List<DexEntry> get entries => [for (final s in species) entry(s)];

  /// Aplica un estado completo a una especie (capturado implica visto).
  void apply(DexEntry e) {
    if (e.species < 1 || e.species > maxSpecies || !contains(e.species)) return;
    final seen = e.seen || e.caught || e.shiny;
    setSeen(e.species, seen);
    setCaught(e.species, e.caught);
    if (hasShiny) setShinySeen(e.species, e.shiny);
    if (!seen) return;
    if (hasGender && e.genders != null && e.genders != 0) {
      for (var g = 0; g < 2; g++) {
        setGenderSeen(e.species, g, (e.genders! >> g) & 1 == 1);
      }
    }
    if (hasForms && e.forms != null && e.forms != 0) {
      for (var f = 0; f < formCount(e.species); f++) {
        if (formAvailable(e.species, f)) setFormSeen(e.species, f, (e.forms! >> f) & 1 == 1);
      }
    }
  }

  /// Máscara con todos los géneros posibles de la especie.
  int allGenders(int species) => 1;

  /// `true` si la especie no tiene género (se registra como "macho").
  bool isGenderless(int species) => false;

  /// Máscara con todas las formas registrables de la especie.
  int allForms(int species) {
    var m = 0;
    for (var f = 0; f < formCount(species); f++) {
      if (formAvailable(species, f)) m |= 1 << f;
    }
    return m;
  }

  /// Marca todas las especies como vistas y capturadas, con todos sus géneros y
  /// formas (y variocolor si [shiny]).
  void completeAll({bool shiny = false}) {
    for (final s in species) {
      apply(DexEntry(s,
          seen: true,
          caught: true,
          shiny: hasShiny && (shiny || isShinySeen(s)),
          genders: hasGender ? allGenders(s) | genderMask(s) : null,
          forms: hasForms ? allForms(s) | formMask(s) : null));
    }
  }

  /// Borra todos los registros.
  void clearAll() {
    for (final s in species) {
      apply(DexEntry(s));
    }
  }

  ({int seen, int caught, int shiny}) get counts {
    var seen = 0, caught = 0, shiny = 0;
    for (final s in species) {
      if (isSeen(s)) seen++;
      if (isCaught(s)) caught++;
      if (hasShiny && isShinySeen(s)) shiny++;
    }
    return (seen: seen, caught: caught, shiny: shiny);
  }
}

bool _getBit(Uint8List d, int ofs, int index) => (d[ofs + (index >> 3)] >> (index & 7)) & 1 == 1;

void _setBit(Uint8List d, int ofs, int index, bool v) {
  final o = ofs + (index >> 3);
  d[o] = v ? d[o] | (1 << (index & 7)) : d[o] & ~(1 << (index & 7));
}

/// Pokédex de campos de bits (Gen 1–5). Portado de PKHeX `SAV1/2/3`, `Zukan4` y `Zukan5` (GPL-3.0).
///
/// * [caught]: inicio del bitfield de capturados.
/// * [seen]: inicios de los bitfields de vistos (todas las copias se mantienen iguales).
/// * [seenFemale]: bitfields de "visto hembra" (Gen 5), usado en especies solo hembra.
/// * [shiny]/[shinyFemale]: bitfields de "visto variocolor" (Gen 5).
/// * [displayed]/[displayedFemale]/[displayedShiny]: bitfields de "forma mostrada" (Gen 5).
/// * [genderFirst]/[genderSecond]: Gen 4 (primer/segundo género visto).
class BitPokedex extends Pokedex {
  BitPokedex(
    this.data, {
    required this.maxSpecies,
    required this.caught,
    required this.seen,
    required this.description,
    this.game,
    this.seenFemale,
    this.shiny,
    this.shinyFemale,
    this.displayed,
    this.displayedFemale,
    this.genderFirst,
    this.genderSecond,
    this.seenMirrors = const [],
  });

  final Uint8List data;
  @override
  final int maxSpecies;
  @override
  final String description;
  final GameVersion? game;
  final int caught;
  final List<int> seen;
  final int? seenFemale, shiny, shinyFemale, displayed, displayedFemale, genderFirst, genderSecond;

  /// Copias de "visto" en otros búferes (Gen 3 guarda tres).
  final List<(Uint8List, int)> seenMirrors;

  @override
  bool get hasShiny => shiny != null;

  bool _femaleOnly(int species) =>
      game != null && (GameDataTable.forGame(game!).entry(species)?.onlyFemale ?? false);

  @override
  bool isCaught(int species) => _getBit(data, caught, species - 1);

  @override
  bool isSeen(int species) =>
      _getBit(data, seen.first, species - 1) || (seenFemale != null && _getBit(data, seenFemale!, species - 1)) || isShinySeen(species);

  @override
  bool isShinySeen(int species) =>
      shiny != null &&
      (_getBit(data, shiny!, species - 1) || (shinyFemale != null && _getBit(data, shinyFemale!, species - 1)));

  @override
  void setCaught(int species, bool value) => _setBit(data, caught, species - 1, value);

  @override
  void setSeen(int species, bool value) {
    final i = species - 1;
    final female = seenFemale != null && _femaleOnly(species);
    if (value && isSeen(species)) return; // conserva género/variocolor ya registrados
    for (final o in seen) {
      _setBit(data, o, i, value && !female);
    }
    for (final (buf, o) in seenMirrors) {
      _setBit(buf, o, i, value);
    }
    if (seenFemale != null) _setBit(data, seenFemale!, i, value && female);
    if (!value && shiny != null) setShinySeen(species, false);
    if (displayed != null) {
      _setBit(data, displayed!, i, value && !female);
      if (displayedFemale != null) _setBit(data, displayedFemale!, i, value && female);
    }
    if (genderFirst != null) {
      final g = value && _femaleOnly(species);
      _setBit(data, genderFirst!, i, g);
      _setBit(data, genderSecond!, i, g);
    }
  }

  @override
  void setShinySeen(int species, bool value) {
    if (shiny == null) return;
    final i = species - 1;
    final female = shinyFemale != null && _femaleOnly(species);
    if (value && isShinySeen(species)) return;
    _setBit(data, shiny!, i, value && !female);
    if (shinyFemale != null) _setBit(data, shinyFemale!, i, value && female);
  }
}
