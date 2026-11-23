import '../data/forms.dart';
import '../data/game_data.dart';
import '../data/species.dart';
import '../model/game.dart';
import 'dex_forms.dart';
import 'dex_scan.dart';
import 'special_forms.dart';

/// Una partida del Arca vista por la Dex (su copia más reciente).
class DexSource {
  const DexSource({required this.id, required this.game, this.versionId, required this.trainer, required this.scan});

  /// Id de la partida en el índice del Arca.
  final int id;
  final GameVersion game;
  final int? versionId;
  final String trainer;
  final SaveDexScan scan;
}

/// Estado de registro de una especie.
enum DexStatus { unknown, seen, caught }

/// Un ejemplar concreto y la partida ([source] = índice en [GlobalDex.sources]) donde está.
class DexSpecimenRef {
  const DexSpecimenRef(this.source, this.specimen);
  final int source;
  final DexSpecimen specimen;
}

/// Estado de desbloqueo de una forma especial (normal y variocolor por separado).
class SpecialUnlock {
  SpecialUnlock(this.form);
  final SpecialForm form;

  /// Ejemplares que la desbloquean (normal / variocolor).
  final List<DexSpecimenRef> normal = [];
  final List<DexSpecimenRef> shiny = [];

  /// Partidas (índices) con el objeto activador en el inventario.
  final Set<int> withItem = {};

  bool get normalUnlocked => normal.isNotEmpty;
  bool get shinyUnlocked => shiny.isNotEmpty;

  /// Variantes desbloqueadas (0–2).
  int get unlockedCount => (normalUnlocked ? 1 : 0) + (shinyUnlocked ? 1 : 0);
}

/// Una especie en la Dex global.
class SpeciesDex {
  SpeciesDex(this.species);
  final int species;

  /// Partidas (índices) donde la Pokédex la marca vista / capturada.
  final Set<int> seenIn = {};
  final Set<int> caughtIn = {};

  /// Partidas donde la Pokédex la marca vista variocolor.
  final Set<int> shinySeenIn = {};

  /// Ejemplares en equipos y cajas (incluye huevos).
  final List<DexSpecimenRef> specimens = [];

  /// Formas registradas en alguna Pokédex (máscara unida).
  int formsSeenMask = 0;

  /// Formas especiales y su estado.
  final List<SpecialUnlock> specials = [];

  Iterable<DexSpecimenRef> get _hatched => specimens.where((r) => !r.specimen.egg);

  /// Tiene algún ejemplar (no huevo) en equipo o cajas: cuenta para la living dex.
  bool get owned => _hatched.isNotEmpty;

  /// Tiene algún ejemplar variocolor.
  bool get shinyOwned => _hatched.any((r) => r.specimen.shiny);

  /// Formas de las que tiene ejemplar.
  Set<int> get formsOwned => {for (final r in _hatched) r.specimen.form};

  DexStatus get status => caughtIn.isNotEmpty || owned
      ? DexStatus.caught
      : (seenIn.isNotEmpty || specimens.isNotEmpty ? DexStatus.seen : DexStatus.unknown);

  /// Estado en la living dex: capturada solo si hay ejemplar.
  DexStatus get livingStatus => owned ? DexStatus.caught : (status == DexStatus.unknown ? DexStatus.unknown : DexStatus.seen);

  /// Formas coleccionables (siempre incluye la 0).
  List<int> get collectableForms => DexForms.collectable(species);

  /// Formas alternativas coleccionables (sin la 0) con ejemplar.
  int get altFormsOwned => collectableForms.where((f) => f != 0 && formsOwned.contains(f)).length;

  /// Variantes de formas por desbloquear: formas alternativas sin ejemplar y
  /// formas especiales (normal + variocolor) bloqueadas.
  int get lockedForms =>
      (collectableForms.length - 1 - altFormsOwned) + specials.fold(0, (a, s) => a + 2 - s.unlockedCount);

  int get unlockedSpecials => specials.fold(0, (a, s) => a + s.unlockedCount);
}

/// Contadores de progreso.
class DexProgress {
  DexProgress();
  int total = 0;
  int caught = 0;
  int seen = 0;
  int shiny = 0;
  int owned = 0;
  int formsUnlocked = 0;
  int formsTotal = 0;

  void _add(SpeciesDex e) {
    total++;
    final st = e.status;
    if (st == DexStatus.caught) caught++;
    if (st != DexStatus.unknown) seen++;
    if (e.shinyOwned) shiny++;
    if (e.owned) owned++;
    formsUnlocked += e.altFormsOwned + e.unlockedSpecials;
    formsTotal += e.collectableForms.length - 1 + e.specials.length * 2;
  }
}

/// Progreso de las partidas de un juego.
class GameDexProgress {
  GameDexProgress(this.game);
  final GameVersion game;

  /// Especies que existen en el juego.
  int available = 0;
  int caught = 0;
  int seen = 0;

  /// Partidas de este juego.
  int saves = 0;
}

enum DexStatusFilter { all, caught, missing, seenOnly }

enum DexSort { number, name }

/// Región de origen de cada generación.
enum DexRegion {
  kanto(1),
  johto(2),
  hoenn(3),
  sinnoh(4),
  unova(5),
  kalos(6),
  alola(7),
  galar(8),
  paldea(9);

  const DexRegion(this.generation);
  final int generation;

  static DexRegion ofGeneration(int g) => values[(g - 1).clamp(0, values.length - 1)];
}

/// Filtros de la cuadrícula de la Dex.
class DexFilter {
  const DexFilter({
    this.status = DexStatusFilter.all,
    this.shinyOnly = false,
    this.lockedForms = false,
    this.type,
    this.generation,
    this.game,
    this.query = '',
    this.sort = DexSort.number,
    this.living = false,
  });

  final DexStatusFilter status;
  final bool shinyOnly;

  /// Solo especies con formas por desbloquear.
  final bool lockedForms;
  final PokemonType? type;

  /// Generación (= región de origen).
  final int? generation;

  /// Solo especies del juego, con el estado de las partidas de ese juego.
  final GameVersion? game;
  final String query;
  final DexSort sort;

  /// Estado por ejemplares (living dex) en vez de por registro.
  final bool living;

  bool get isDefault =>
      status == DexStatusFilter.all &&
      !shinyOnly &&
      !lockedForms &&
      type == null &&
      generation == null &&
      game == null &&
      query.trim().isEmpty;

  int get activeCount =>
      (status != DexStatusFilter.all ? 1 : 0) +
      (shinyOnly ? 1 : 0) +
      (lockedForms ? 1 : 0) +
      (type != null ? 1 : 0) +
      (generation != null ? 1 : 0) +
      (game != null ? 1 : 0);

  DexFilter copyWith({
    DexStatusFilter? status,
    bool? shinyOnly,
    bool? lockedForms,
    PokemonType? Function()? type,
    int? Function()? generation,
    GameVersion? Function()? game,
    String? query,
    DexSort? sort,
    bool? living,
  }) =>
      DexFilter(
        status: status ?? this.status,
        shinyOnly: shinyOnly ?? this.shinyOnly,
        lockedForms: lockedForms ?? this.lockedForms,
        type: type != null ? type() : this.type,
        generation: generation != null ? generation() : this.generation,
        game: game != null ? game() : this.game,
        query: query ?? this.query,
        sort: sort ?? this.sort,
        living: living ?? this.living,
      );

  /// Sin filtros (conserva orden y modo living).
  DexFilter cleared() => DexFilter(sort: sort, living: living);
}

/// La Dex global: cruza todas las partidas del Arca.
class GlobalDex {
  GlobalDex._(this.sources, this._entries);

  /// Partidas incluidas (la copia más reciente de cada una).
  final List<DexSource> sources;
  final List<SpeciesDex> _entries;

  static const int maxSpecies = Species.max;

  /// Construye la Dex a partir de las partidas.
  factory GlobalDex.build(List<DexSource> sources) {
    final entries = [for (var s = 1; s <= maxSpecies; s++) SpeciesDex(s)];
    for (var s = 1; s <= maxSpecies; s++) {
      for (final f in SpecialForms.of(s)) {
        entries[s - 1].specials.add(SpecialUnlock(f));
      }
    }
    for (final (i, src) in sources.indexed) {
      final scan = src.scan;
      for (final s in scan.seen) {
        if (s >= 1 && s <= maxSpecies) entries[s - 1].seenIn.add(i);
      }
      for (final s in scan.caught) {
        if (s >= 1 && s <= maxSpecies) entries[s - 1].caughtIn.add(i);
      }
      for (final s in scan.shinySeen) {
        if (s >= 1 && s <= maxSpecies) entries[s - 1].shinySeenIn.add(i);
      }
      for (final e in scan.formsSeen.entries) {
        if (e.key >= 1 && e.key <= maxSpecies) entries[e.key - 1].formsSeenMask |= e.value;
      }
      for (final sp in scan.specimens) {
        if (sp.species < 1 || sp.species > maxSpecies) continue;
        final e = entries[sp.species - 1];
        final ref = DexSpecimenRef(i, sp);
        e.specimens.add(ref);
        if (sp.egg) continue;
        for (final u in e.specials) {
          if (!u.form.unlockedBy(game: scan.game, specimenForm: sp.form, gigantamaxFactor: sp.gigantamax)) continue;
          (sp.shiny ? u.shiny : u.normal).add(ref);
          if (u.form.item != 0 && scan.items.contains(u.form.item)) u.withItem.add(i);
        }
      }
    }
    return GlobalDex._(List.unmodifiable(sources), entries);
  }

  /// Dex vacía (sin partidas).
  factory GlobalDex.empty() => GlobalDex.build(const []);

  SpeciesDex operator [](int species) => _entries[species - 1];

  Iterable<SpeciesDex> get entries => _entries;

  /// Progreso global.
  DexProgress get progress {
    final p = DexProgress();
    for (final e in _entries) {
      p._add(e);
    }
    return p;
  }

  /// Progreso por generación (1–9).
  Map<int, DexProgress> get byGeneration {
    final out = {for (var g = 1; g <= 9; g++) g: DexProgress()};
    for (final e in _entries) {
      out[Species.introducedIn(e.species)]!._add(e);
    }
    return out;
  }

  /// Progreso de cada juego con partidas en el Arca (especies del juego
  /// registradas en sus partidas).
  List<GameDexProgress> get byGame {
    final out = <GameVersion, GameDexProgress>{};
    for (final src in sources) {
      out.putIfAbsent(src.game, () => GameDexProgress(src.game)).saves++;
    }
    for (final p in out.values) {
      final t = GameDataTable.forGame(p.game);
      for (var s = 1; s <= maxSpecies; s++) {
        if (!t.hasSpecies(s)) continue;
        p.available++;
        final st = statusIn(s, p.game);
        if (st == DexStatus.caught) p.caught++;
        if (st != DexStatus.unknown) p.seen++;
      }
    }
    return out.values.toList()..sort((a, b) => a.game.index.compareTo(b.game.index));
  }

  /// Estado de [species] contando solo las partidas de [game].
  DexStatus statusIn(int species, GameVersion game, {bool living = false}) {
    final e = this[species];
    var caught = false, seen = false;
    for (final i in e.caughtIn) {
      if (sources[i].game == game && !living) caught = true;
    }
    for (final r in e.specimens) {
      if (sources[r.source].game != game) continue;
      if (!r.specimen.egg) caught = true;
      seen = true;
    }
    if (caught) return DexStatus.caught;
    for (final i in e.seenIn) {
      if (sources[i].game == game) seen = true;
    }
    if (living) {
      for (final i in e.caughtIn) {
        if (sources[i].game == game) seen = true;
      }
    }
    return seen ? DexStatus.seen : DexStatus.unknown;
  }

  /// Juegos (de los del Arca) en los que existe la especie.
  static List<GameVersion> gamesWith(int species) => [
        for (final g in GameVersion.values)
          if (GameDataTable.forGame(g).hasSpecies(species)) g,
      ];

  static final Map<int, int> _typeMasks = {};

  /// Máscara de tipos de la especie en cualquiera de sus formas coleccionables.
  static int typeMask(int species) => _typeMasks.putIfAbsent(species, () {
        var m = 0;
        for (final f in DexForms.collectable(species)) {
          final (a, b) = SpeciesForms.types(species, f);
          m |= (1 << a.index) | (1 << b.index);
        }
        return m & ~1;
      });

  /// Especies que cumplen [f], en el orden pedido.
  List<int> filter(DexFilter f, {DataLanguage lang = DataLanguage.es}) {
    final q = _fold(f.query.trim());
    final qNum = int.tryParse(q.replaceFirst('#', ''));
    final out = <int>[];
    for (final e in _entries) {
      final s = e.species;
      if (f.generation != null && Species.introducedIn(s) != f.generation) continue;
      if (f.game != null && !GameDataTable.forGame(f.game!).hasSpecies(s)) continue;
      if (f.type != null && (typeMask(s) >> f.type!.index) & 1 == 0) continue;
      if (q.isNotEmpty) {
        final match = qNum != null
            ? s.toString().startsWith(qNum.toString()) || s == qNum
            : _fold(Species.name(s, SpeciesLanguage.es)).contains(q) || _fold(Species.name(s, SpeciesLanguage.en)).contains(q);
        if (!match) continue;
      }
      final st = f.game != null ? statusIn(s, f.game!, living: f.living) : (f.living ? e.livingStatus : e.status);
      switch (f.status) {
        case DexStatusFilter.caught when st != DexStatus.caught:
        case DexStatusFilter.missing when st == DexStatus.caught:
        case DexStatusFilter.seenOnly when st != DexStatus.seen:
          continue;
        default:
      }
      if (f.shinyOnly && !_shinyIn(e, f.game)) continue;
      if (f.lockedForms && e.lockedForms == 0) continue;
      out.add(s);
    }
    if (f.sort == DexSort.name) {
      final sl = lang == DataLanguage.es ? SpeciesLanguage.es : SpeciesLanguage.en;
      final names = {for (final s in out) s: _fold(Species.name(s, sl))};
      out.sort((a, b) => names[a]!.compareTo(names[b]!));
    }
    return out;
  }

  bool _shinyIn(SpeciesDex e, GameVersion? game) =>
      e.specimens.any((r) => r.specimen.shiny && !r.specimen.egg && (game == null || sources[r.source].game == game));

  /// Minúsculas sin acentos (búsqueda «tolerante»).
  static String _fold(String s) {
    const from = 'áàäâéèëêíìïîóòöôúùüûñç♀♂';
    const to = 'aaaaeeeeiiiioooouuuuncfm';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().runes) {
      final c = String.fromCharCode(ch);
      final i = from.indexOf(c);
      b.write(i >= 0 ? to[i] : c);
    }
    return b.toString();
  }
}
