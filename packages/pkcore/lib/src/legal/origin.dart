import '../data/game_data.dart';
import '../data/generated/encounter_data.dart';
import '../data/generated/gc_data.dart';
import '../model/game.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import 'balls.dart';
import 'encounters.dart';
import 'legality.dart';

/// Paso de un traspaso entre juegos.
enum TransferStep {
  /// Gen 3 → Gen 4 (Parque Compi).
  palPark,

  /// Gen 4 → Gen 5 (Pokétransfer).
  pokeTransfer,

  /// Gen 5 → Gen 6/7 (Poké Transporter + Banco).
  transporter,

  /// Consola Virtual (Gen 1/2) → Gen 7 (Poké Transporter).
  virtualConsole,

  /// Pokémon GO → Let's Go / HOME.
  go,

  /// Gen 7 → Gen 8+ (Pokémon Banco → HOME).
  bank,

  /// Entre juegos de Switch (Pokémon HOME).
  home,
}

/// Lugar con su id y nombre localizado.
class LocationOption {
  const LocationOption(this.id, this.name, {this.encounter = false});
  final int id;
  final String name;

  /// `true` si la especie (o una preevolución) aparece allí en las tablas de encuentros.
  final bool encounter;
}

/// Offsets de fechas por formato (PKHeX `PK4` … `PA9`): (huevo, encuentro).
(int, int)? _dateOfs(PkFormat f) => switch (f) {
      PkFormat.pk4 || PkFormat.pk5 => (0x78, 0x7B),
      PkFormat.pk6 || PkFormat.pk7 || PkFormat.pb7 => (0xD1, 0xD4),
      PkFormat.pa8 => (0x131, 0x134),
      PkFormat.pk8 || PkFormat.pb8 || PkFormat.pk9 || PkFormat.pa9 => (0x119, 0x11C),
      _ => null,
    };

/// Origen de un Pokémon: fechas, huevo, rastreador de HOME y traspasos.
extension PkmOrigin on Pkm {
  bool get hasDates => _dateOfs(format) != null;

  DateTime? _date(int o) {
    final y = data[o], m = data[o + 1], d = data[o + 2];
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime(2000 + y, m, d);
  }

  void _setDate(int o, DateTime? v) {
    if (v == null) {
      data[o] = data[o + 1] = data[o + 2] = 0;
    } else {
      data[o] = (v.year - 2000).clamp(0, 99);
      data[o + 1] = v.month;
      data[o + 2] = v.day;
    }
  }

  /// Fecha de encuentro (Gen 4+).
  DateTime? get metDate => _dateOfs(format) == null ? null : _date(_dateOfs(format)!.$2);
  set metDate(DateTime? v) {
    final o = _dateOfs(format);
    if (o != null) _setDate(o.$2, v);
  }

  /// Fecha en que se recibió el huevo (Gen 4+).
  DateTime? get eggDate => _dateOfs(format) == null ? null : _date(_dateOfs(format)!.$1);
  set eggDate(DateTime? v) {
    final o = _dateOfs(format);
    if (o != null) _setDate(o.$1, v);
  }

  /// Rastreador de Pokémon HOME (0 si nunca pasó por HOME).
  int get homeTracker {
    final o = switch (format) {
      PkFormat.pk8 || PkFormat.pb8 => 0x135,
      PkFormat.pa8 => 0x14D,
      PkFormat.pk9 || PkFormat.pa9 => 0x127,
      _ => -1,
    };
    if (o < 0) return 0;
    var v = 0;
    for (var i = 7; i >= 0; i--) {
      v = (v << 8) | data[o + i];
    }
    return v;
  }

  /// Traspasos por los que pasó el Pokémon para llegar a su formato actual.
  List<TransferStep> get transfers {
    final v = version;
    final gen = OriginGames.generation(v);
    final fmt = format.generation;
    final out = <TransferStep>[];
    if (v >= 35 && v <= 41) {
      out.add(TransferStep.virtualConsole);
      if (fmt >= 8) out.addAll([TransferStep.bank, TransferStep.home]);
      return out;
    }
    if (v == 34) {
      out.add(TransferStep.go);
      if (fmt >= 8) out.add(TransferStep.home);
      return out;
    }
    if (gen == null) return out;
    final switchOrigin = v == 42 || v == 43 || v >= 44;
    if (!switchOrigin) {
      if (gen <= 3 && fmt >= 4) out.add(TransferStep.palPark);
      if (gen <= 4 && fmt >= 5) out.add(TransferStep.pokeTransfer);
      if (gen <= 5 && fmt >= 6) out.add(TransferStep.transporter);
      if (gen <= 7 && fmt >= 8) out.addAll([TransferStep.bank, TransferStep.home]);
    } else if (format != OriginPlace.nativeFormat(v) || homeTracker != 0) {
      out.add(TransferStep.home);
    }
    return out;
  }
}

/// Lugares y juegos de origen para los selectores del editor.
abstract final class OriginPlace {
  /// Formato nativo del juego de origen (ids de PKHeX `GameVersion`).
  static PkFormat? nativeFormat(int v) => switch (v) {
        1 || 2 || 3 || 4 || 5 || 15 => PkFormat.pk3,
        7 || 8 || 10 || 11 || 12 => PkFormat.pk4,
        20 || 21 || 22 || 23 => PkFormat.pk5,
        24 || 25 || 26 || 27 => PkFormat.pk6,
        30 || 31 || 32 || 33 => PkFormat.pk7,
        42 || 43 => PkFormat.pb7,
        44 || 45 => PkFormat.pk8,
        47 => PkFormat.pa8,
        48 || 49 => PkFormat.pb8,
        50 || 51 => PkFormat.pk9,
        52 => PkFormat.pa9,
        _ => null,
      };

  /// Familia de juego de una versión concreta.
  static GameVersion? gameOf(int v) => switch (v) {
        1 || 2 => GameVersion.rubySapphire,
        3 => GameVersion.emerald,
        4 || 5 => GameVersion.fireRedLeafGreen,
        15 => GameVersion.colosseum,
        66 => GameVersion.colosseum,
        67 => GameVersion.xd,
        7 || 8 => GameVersion.heartGoldSoulSilver,
        10 || 11 => GameVersion.diamondPearl,
        12 => GameVersion.platinum,
        20 || 21 => GameVersion.blackWhite,
        22 || 23 => GameVersion.black2White2,
        24 || 25 => GameVersion.xy,
        26 || 27 => GameVersion.omegaRubyAlphaSapphire,
        30 || 31 => GameVersion.sunMoon,
        32 || 33 => GameVersion.ultraSunUltraMoon,
        42 || 43 => GameVersion.letsGo,
        44 || 45 => GameVersion.swordShield,
        47 => GameVersion.legendsArceus,
        48 || 49 => GameVersion.brilliantDiamondShiningPearl,
        50 || 51 => GameVersion.scarletViolet,
        52 => GameVersion.legendsZA,
        _ => null,
      };

  /// Juegos de origen posibles para un Pokémon guardado en [format]
  /// (el propio y los anteriores desde los que se puede traer).
  static List<int> originVersions(PkFormat format) {
    const all = [1, 2, 3, 4, 5, 15, 10, 11, 12, 7, 8, 20, 21, 22, 23, 24, 25, 26, 27, 30, 31, 32, 33, 35, 36, 37, 38, 39, 40, 41, 34, 42, 43, 44, 45, 47, 48, 49, 50, 51, 52];
    final g = format.generation;
    return [
      for (final v in all)
        if (_canReach(v, format, g)) v,
    ];
  }

  static bool _canReach(int v, PkFormat format, int fmtGen) {
    final native = nativeFormat(v);
    if (native == format) return true;
    if (v >= 35 && v <= 41) return format == PkFormat.pk7 || fmtGen >= 8;
    if (v == 34) return format == PkFormat.pb7 || fmtGen >= 8;
    final gen = OriginGames.generation(v);
    if (gen == null || native == null) return false;
    if (fmtGen >= 8) return true; // HOME acepta todos los orígenes
    if (native == PkFormat.pb7) return false;
    return gen < fmtGen || (gen == fmtGen && native.generation == fmtGen && format != PkFormat.pb7);
  }

  /// Lugares de encuentro de [version]: primero los válidos para la especie
  /// según las tablas de encuentros (marcados), luego el resto si [all].
  static List<LocationOption> locations(int version, int species, DataLanguage lang, {bool all = false}) {
    final chain = EncounterTables.evolutionChain(species);
    final valid = <int>{
      for (final e in EncounterTables.forVersion(version))
        if (chain.contains(e.species) && e.location != EncounterSlot.anyLocation && e.location != EncounterSlot.anyDen) e.location,
    };
    final out = <LocationOption>[
      for (final id in valid) LocationOption(id, EncounterTables.locationName(version, id, lang), encounter: true),
    ]..sort((a, b) => a.name.compareTo(b.name));
    if (all && version == EncounterTables.cxd) {
      final names = lang == DataLanguage.es ? kGcLocationsEs : kGcLocationsEn;
      final rest = <LocationOption>[
        for (var id = 1; id < names.length; id++)
          if (!valid.contains(id) && names[id].trim().isNotEmpty) LocationOption(id, names[id]),
      ]..sort((a, b) => a.name.compareTo(b.name));
      out.addAll(rest);
    } else if (all) {
      final key = _key(version);
      final raw = kLocationNames['${key}_${lang.name}'] ?? '';
      final rest = <LocationOption>[];
      for (final line in raw.split('\n')) {
        final parts = line.split('\t');
        if (parts.length != 2) continue;
        final id = int.tryParse(parts[0]);
        if (id == null || id == 0 || valid.contains(id) || parts[1].trim().isEmpty) continue;
        rest.add(LocationOption(id, parts[1]));
      }
      rest.sort((a, b) => a.name.compareTo(b.name));
      out.addAll(rest);
    }
    return out;
  }

  static String _key(int version) => switch (version) {
        42 || 43 => 'lgpe',
        47 => 'la',
        48 || 49 => 'bdsp',
        1 || 2 || 3 || 4 || 5 => '3',
        7 || 8 || 10 || 11 || 12 => '4',
        20 || 21 || 22 || 23 => '5',
        24 || 25 || 26 || 27 => '6',
        30 || 31 || 32 || 33 => '7',
        44 || 45 => '8',
        _ => '9',
      };

  /// Balls con las que se pudo capturar en el juego de origen (y que el formato actual guarda).
  static List<int> balls(int version, GameVersion current) {
    final origin = gameOf(version);
    final here = BallTables.forGame(current);
    if (origin == null) return here;
    return [for (final b in BallTables.forGame(origin)) if (here.contains(b)) b];
  }
}
