import '../model/game.dart';

/// Tipo de forma especial (de combate o temporal) que la Dex global muestra
/// como forma desbloqueable de la especie.
enum SpecialFormKind {
  /// Megaevolución (piedra activadora).
  mega,

  /// Regresión primigenia (Kyogre/Groudon con su orbe).
  primal,

  /// Ultraexplosión (Necrozma fusionado con el Ultranecrostal Z).
  ultraBurst,

  /// Gigamax (factor Gigamax del Pokémon en Espada/Escudo).
  gigantamax,
}

/// Qué tiene que tener un ejemplar para habilitar la forma.
enum UnlockRequirement {
  /// Un ejemplar de la especie (de una forma de [SpecialForm.baseForms]) en
  /// una partida de uno de [SpecialForm.games].
  specimenInGame,

  /// Además, el factor Gigamax activado (PK8 `CanGigantamax`).
  gigantamaxFactor,
}

/// Una forma especial desbloqueable.
///
/// Es una fila de [SpecialForms.all]: toda la lógica de desbloqueo de la Dex
/// lee esta tabla (no hay reglas repartidas por el código). Las formas de
/// Mega/Primigenio/Ultra usan el índice de forma de PKHeX; Gigamax no es una
/// forma en los datos del juego (es un flag del Pokémon), así que [form] es
/// null y la forma visible es la de [baseForms].
class SpecialForm {
  const SpecialForm({
    required this.kind,
    required this.species,
    required this.form,
    required this.games,
    this.baseForms,
    this.item = 0,
    this.variant = '',
    this.requirement = UnlockRequirement.specimenInGame,
  });

  final SpecialFormKind kind;
  final int species;

  /// Índice de forma de PKHeX (null en Gigamax).
  final int? form;

  /// Juegos en los que existe la forma y en los que un ejemplar la habilita.
  final Set<GameVersion> games;

  /// Formas del ejemplar que la habilitan (null = cualquiera).
  final Set<int>? baseForms;

  /// Objeto activador (piedra, orbe, cristal Z): es un indicador, no un
  /// requisito. Ids de objeto modernos (PKHeX). 0 = ninguno.
  final int item;

  /// Sufijo para distinguir varias formas del mismo tipo: «X», «Y», «Z»,
  /// o el nombre de la forma base en Gigamax (Urshifu, Toxtricity).
  final String variant;

  final UnlockRequirement requirement;

  /// Clave estable (para persistir y para los tests): `mega:6:1`, `gmax:849:0`.
  String get key => switch (kind) {
        SpecialFormKind.gigantamax => 'gmax:$species:${baseForms == null ? '*' : (baseForms!.toList()..sort()).join('+')}',
        _ => '${kind.name}:$species:$form',
      };

  /// `true` si un ejemplar de [specimenForm] en [game] (con o sin factor
  /// Gigamax) habilita esta forma.
  bool unlockedBy({required GameVersion game, required int specimenForm, bool gigantamaxFactor = false}) {
    if (!games.contains(game)) return false;
    if (baseForms != null && !baseForms!.contains(specimenForm)) return false;
    if (requirement == UnlockRequirement.gigantamaxFactor && !gigantamaxFactor) return false;
    return true;
  }

  @override
  String toString() => key;
}

/// Tabla de formas especiales y sus reglas de desbloqueo (documentada en
/// `docs/usuario/dex.md`).
///
/// * **Mega**: existe en los juegos cuyas tablas personales de PKHeX la marcan
///   presente (`PersonalInfo.IsPresentInGame` + `FormInfo.IsMegaForm`): X/Y,
///   Rubí Omega/Zafiro Alfa, Sol/Luna, Ultrasol/Ultraluna, Let's Go (solo las
///   de Kanto) y Leyendas Z-A (su propia lista, con Mega Dimensión). La piedra
///   es la de PKHeX `ItemStorage9ZA.GetExpectedMegaStoneOrPrimalOrb`.
/// * **Primigenio**: Kyogre/Groudon en ROZA, SL, USUL y Z-A (orbe como indicador).
/// * **Ultra Necrozma**: Necrozma fusionado (Melena Crepuscular o Alas del
///   Alba) en Ultrasol/Ultraluna (Ultranecrostal Z como indicador).
/// * **Gigamax**: un ejemplar en Espada/Escudo con el factor Gigamax
///   (PKHeX `Gigantamax.CanToggle`; Pikachu y Meowth solo en forma 0). Melmetal
///   también: no puede tomar la Maxisopa, pero llega con el factor desde GO/HOME.
///   Urshifu y Toxtricity tienen una Gigamax por forma.
///
/// Eternamax (Eternatus) no se desbloquea: no hay ejemplar que la habilite.
/// Cada forma tiene versión normal y variocolor: un ejemplar variocolor
/// desbloquea la variocolor; uno normal, la normal.
abstract final class SpecialForms {
  static const _xy = GameVersion.xy;
  static const _oras = GameVersion.omegaRubyAlphaSapphire;
  static const _sm = GameVersion.sunMoon;
  static const _usum = GameVersion.ultraSunUltraMoon;
  static const _lgpe = GameVersion.letsGo;
  static const _za = GameVersion.legendsZA;
  static const _swsh = GameVersion.swordShield;

  /// Juegos con Megaevolución.
  static const Set<GameVersion> megaGames = {_xy, _oras, _sm, _usum, _lgpe, _za};

  // Conjuntos de juegos (verificados contra PKHeX en `special_forms_test.dart`).
  static const _gen6to7za = {_xy, _oras, _sm, _usum, _za};
  static const _all = {_xy, _oras, _sm, _usum, _lgpe, _za};
  static const _orasOnZa = {_oras, _sm, _usum, _za};
  static const _orasOnAll = {_oras, _sm, _usum, _lgpe, _za};

  static SpecialForm _mega(int species, int form, int item, Set<GameVersion> games, [String variant = '']) =>
      SpecialForm(kind: SpecialFormKind.mega, species: species, form: form, games: games, item: item, variant: variant);

  static SpecialForm _gmax(int species, [Set<int>? baseForms, String variant = '']) => SpecialForm(
        kind: SpecialFormKind.gigantamax,
        species: species,
        form: null,
        games: const {_swsh},
        baseForms: baseForms,
        variant: variant,
        requirement: UnlockRequirement.gigantamaxFactor,
      );

  /// Todas las formas especiales, por especie.
  static final List<SpecialForm> all = List.unmodifiable([
    // ---------------------------------------------------- Megas de X/Y
    _mega(3, 1, 659, _all), // Venusaur
    _mega(6, 1, 660, _all, 'X'), // Charizard X
    _mega(6, 2, 678, _all, 'Y'), // Charizard Y
    _mega(9, 1, 661, _all), // Blastoise
    _mega(65, 1, 679, _all), // Alakazam
    _mega(94, 1, 656, _all), // Gengar
    _mega(115, 1, 675, _all), // Kangaskhan
    _mega(127, 1, 671, _all), // Pinsir
    _mega(130, 1, 676, _all), // Gyarados
    _mega(142, 1, 672, _all), // Aerodactyl
    _mega(150, 1, 662, _all, 'X'), // Mewtwo X
    _mega(150, 2, 663, _all, 'Y'), // Mewtwo Y
    _mega(181, 1, 658, _gen6to7za), // Ampharos
    _mega(212, 1, 670, _gen6to7za), // Scizor
    _mega(214, 1, 680, _gen6to7za), // Heracross
    _mega(229, 1, 666, _gen6to7za), // Houndoom
    _mega(248, 1, 669, _gen6to7za), // Tyranitar
    _mega(257, 1, 664, _gen6to7za), // Blaziken
    _mega(282, 1, 657, _gen6to7za), // Gardevoir
    _mega(303, 1, 681, _gen6to7za), // Mawile
    _mega(306, 1, 667, _gen6to7za), // Aggron
    _mega(308, 1, 665, _gen6to7za), // Medicham
    _mega(310, 1, 682, _gen6to7za), // Manectric
    _mega(354, 1, 668, _gen6to7za), // Banette
    _mega(359, 1, 677, _gen6to7za), // Absol
    _mega(380, 1, 684, _gen6to7za), // Latias
    _mega(381, 1, 685, _gen6to7za), // Latios
    _mega(445, 1, 683, _gen6to7za), // Garchomp
    _mega(448, 1, 673, _gen6to7za), // Lucario
    _mega(460, 1, 674, _gen6to7za), // Abomasnow
    // ---------------------------------------------------- Megas de ROZA
    _mega(15, 1, 770, _orasOnAll), // Beedrill
    _mega(18, 1, 762, _orasOnAll), // Pidgeot
    _mega(80, 1, 760, _orasOnAll), // Slowbro
    _mega(208, 1, 761, _orasOnZa), // Steelix
    _mega(254, 1, 753, _orasOnZa), // Sceptile
    _mega(260, 1, 752, _orasOnZa), // Swampert
    _mega(302, 1, 754, _orasOnZa), // Sableye
    _mega(319, 1, 759, _orasOnZa), // Sharpedo
    _mega(323, 1, 767, _orasOnZa), // Camerupt
    _mega(334, 1, 755, _orasOnZa), // Altaria
    _mega(362, 1, 763, _orasOnZa), // Glalie
    _mega(373, 1, 769, _orasOnZa), // Salamence
    _mega(376, 1, 758, _orasOnZa), // Metagross
    _mega(384, 1, 0, _orasOnZa), // Rayquaza (Ascenso del Dragón, sin piedra)
    _mega(428, 1, 768, _orasOnZa), // Lopunny
    _mega(475, 1, 756, _orasOnZa), // Gallade
    _mega(531, 1, 757, _orasOnZa), // Audino
    _mega(719, 1, 764, _orasOnZa), // Diancie
    // ---------------------------------------------------- Megas de Leyendas Z-A
    _mega(36, 1, 2559, const {_za}), // Clefable
    _mega(71, 1, 2560, const {_za}), // Victreebel
    _mega(121, 1, 2561, const {_za}), // Starmie
    _mega(149, 1, 2562, const {_za}), // Dragonite
    _mega(154, 1, 2563, const {_za}), // Meganium
    _mega(160, 1, 2564, const {_za}), // Feraligatr
    _mega(227, 1, 2565, const {_za}), // Skarmory
    _mega(478, 1, 2566, const {_za}), // Froslass
    _mega(485, 1, 2567, const {_za}), // Heatran
    _mega(491, 1, 2568, const {_za}), // Darkrai
    _mega(500, 1, 2569, const {_za}), // Emboar
    _mega(530, 1, 2570, const {_za}), // Excadrill
    _mega(545, 1, 2571, const {_za}), // Scolipede
    _mega(560, 1, 2572, const {_za}), // Scrafty
    _mega(604, 1, 2573, const {_za}), // Eelektross
    _mega(609, 1, 2574, const {_za}), // Chandelure
    _mega(652, 1, 2575, const {_za}), // Chesnaught
    _mega(655, 1, 2576, const {_za}), // Delphox
    _mega(658, 3, 2577, const {_za}), // Greninja
    _mega(668, 1, 2578, const {_za}), // Pyroar
    const SpecialForm(
        kind: SpecialFormKind.mega, species: 670, form: 6, games: {_za}, item: 2579, baseForms: {5}), // Floette (Flor Eterna)
    _mega(687, 1, 2580, const {_za}), // Malamar
    _mega(689, 1, 2581, const {_za}), // Barbaracle
    _mega(691, 1, 2582, const {_za}), // Dragalge
    _mega(701, 1, 2583, const {_za}), // Hawlucha
    _mega(718, 5, 2584, const {_za}), // Zygarde
    _mega(780, 1, 2585, const {_za}), // Drampa
    _mega(807, 1, 2586, const {_za}), // Zeraora
    _mega(870, 1, 2587, const {_za}), // Falinks
    // ---------------------------------------------------- Megas de Mega Dimensión (Z-A)
    const SpecialForm(
        kind: SpecialFormKind.mega, species: 26, form: 2, games: {_za}, item: 2635, variant: 'X', baseForms: {0}), // Raichu X
    const SpecialForm(
        kind: SpecialFormKind.mega, species: 26, form: 3, games: {_za}, item: 2636, variant: 'Y', baseForms: {0}), // Raichu Y
    _mega(358, 1, 2637, const {_za}), // Chimecho
    _mega(359, 2, 2638, const {_za}, 'Z'), // Absol Z
    _mega(398, 1, 2639, const {_za}), // Staraptor
    _mega(445, 2, 2640, const {_za}, 'Z'), // Garchomp Z
    _mega(448, 2, 2641, const {_za}, 'Z'), // Lucario Z
    _mega(623, 1, 2642, const {_za}), // Golurk
    const SpecialForm(
        kind: SpecialFormKind.mega, species: 678, form: 2, games: {_za}, item: 2643, variant: '♂', baseForms: {0}), // Meowstic ♂
    const SpecialForm(
        kind: SpecialFormKind.mega, species: 678, form: 3, games: {_za}, item: 2643, variant: '♀', baseForms: {1}), // Meowstic ♀
    _mega(740, 1, 2644, const {_za}), // Crabominable
    _mega(768, 1, 2645, const {_za}), // Golisopod
    const SpecialForm(
        kind: SpecialFormKind.mega, species: 801, form: 2, games: {_za}, item: 2646, baseForms: {0}), // Magearna
    const SpecialForm(
        kind: SpecialFormKind.mega, species: 801, form: 3, games: {_za}, item: 2646, baseForms: {1}), // Magearna (Original)
    _mega(952, 1, 2647, const {_za}), // Scovillain
    _mega(998, 1, 2648, const {_za}), // Baxcalibur
    const SpecialForm(
        kind: SpecialFormKind.mega, species: 978, form: 3, games: {_za}, item: 2649, baseForms: {0}), // Tatsugiri (Curvo)
    const SpecialForm(
        kind: SpecialFormKind.mega, species: 978, form: 4, games: {_za}, item: 2649, baseForms: {1}), // Tatsugiri (Lánguido)
    const SpecialForm(
        kind: SpecialFormKind.mega, species: 978, form: 5, games: {_za}, item: 2649, baseForms: {2}), // Tatsugiri (Estirado)
    _mega(970, 1, 2650, const {_za}), // Glimmora
    // ---------------------------------------------------- Regresión primigenia
    const SpecialForm(kind: SpecialFormKind.primal, species: 382, form: 1, games: _orasOnZa, item: 535), // Kyogre
    const SpecialForm(kind: SpecialFormKind.primal, species: 383, form: 1, games: _orasOnZa, item: 534), // Groudon
    // ---------------------------------------------------- Ultraexplosión
    const SpecialForm(
        kind: SpecialFormKind.ultraBurst, species: 800, form: 3, games: {_usum}, item: 923, baseForms: {1, 2}), // Ultra Necrozma
    // ---------------------------------------------------- Gigamax (Espada/Escudo)
    _gmax(3), _gmax(6), _gmax(9), _gmax(12),
    _gmax(25, const {0}), _gmax(52, const {0}),
    _gmax(68), _gmax(94), _gmax(99), _gmax(131), _gmax(133), _gmax(143), _gmax(569), _gmax(809),
    _gmax(812), _gmax(815), _gmax(818), _gmax(823), _gmax(826), _gmax(834), _gmax(839), _gmax(841), _gmax(842),
    _gmax(844), _gmax(849, const {0}, 'amped'), _gmax(849, const {1}, 'lowKey'), _gmax(851), _gmax(858),
    _gmax(861), _gmax(869), _gmax(879), _gmax(884),
    _gmax(892, const {0}, 'single'), _gmax(892, const {1}, 'rapid'),
  ]);

  static final Map<int, List<SpecialForm>> _bySpecies = () {
    final m = <int, List<SpecialForm>>{};
    for (final f in all) {
      m.putIfAbsent(f.species, () => []).add(f);
    }
    return m;
  }();

  /// Formas especiales de [species] (vacía si no tiene).
  static List<SpecialForm> of(int species) => _bySpecies[species] ?? const [];

  /// Especies con alguna forma especial.
  static Iterable<int> get species => _bySpecies.keys;

  /// Forma especial con esa clave, o null.
  static SpecialForm? byKey(String key) {
    for (final f in all) {
      if (f.key == key) return f;
    }
    return null;
  }

  /// `true` si [species]/[form] es una forma especial (no se cuenta como forma
  /// «normal» registrada: no existe fuera de combate).
  static bool isSpecialForm(int species, int form) =>
      of(species).any((f) => f.form != null && f.form == form);
}
