import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pkcore/pkcore.dart' as pk show Platform;

import '../folder/folder_access.dart';

/// Un emulador conocido: dónde guarda las partidas en cada sistema y cómo
/// abrirlo. Las rutas son plantillas: `~` (carpeta personal), `%APPDATA%`,
/// `%USERPROFILE%`, `$XDG_DATA_HOME`, `$XDG_CONFIG_HOME` y `$SDCARD`
/// (almacenamiento compartido de Android).
///
/// Compatibilidad documentada en `docs/usuario/emuladores.md`.
class Emulator {
  const Emulator({
    required this.id,
    required this.name,
    required this.consoles,
    this.paths = const {},
    this.androidPackages = const [],
    this.iosScheme,
    required this.notesEs,
    required this.notesEn,
  });

  /// Id estable (persistencia).
  final String id;
  final String name;
  final Set<pk.Platform> consoles;

  /// Carpetas de saves conocidas por sistema.
  final Map<TargetPlatform, List<String>> paths;

  /// Paquetes de Android que abren el emulador (el primero instalado).
  final List<String> androidPackages;

  /// Esquema de URL para abrirlo en iOS (null = no se puede abrir desde la app).
  final String? iosScheme;
  final String notesEs;
  final String notesEn;

  String notes({required bool es}) => es ? notesEs : notesEn;

  /// `true` si «Abrir el juego» puede funcionar en [platform].
  bool canLaunchOn(TargetPlatform platform) => switch (platform) {
    TargetPlatform.android => androidPackages.isNotEmpty,
    TargetPlatform.iOS => iosScheme != null,
    _ => false,
  };
}

abstract final class Emulators {
  static const _sdcard = r'$SDCARD';

  static const all = <Emulator>[
    Emulator(
      id: 'retroarch',
      name: 'RetroArch',
      consoles: {
        pk.Platform.gameBoy,
        pk.Platform.gameBoyColor,
        pk.Platform.gameBoyAdvance,
        pk.Platform.nintendoDs,
        pk.Platform.nintendo64,
        pk.Platform.gameCube,
        pk.Platform.wii,
      },
      paths: {
        TargetPlatform.windows: [r'%APPDATA%\RetroArch\saves', r'C:\RetroArch-Win64\saves'],
        TargetPlatform.linux: [
          r'$XDG_CONFIG_HOME/retroarch/saves',
          '~/.var/app/org.libretro.RetroArch/config/retroarch/saves',
        ],
        TargetPlatform.macOS: ['~/Library/Application Support/RetroArch/saves', '~/Documents/RetroArch/saves'],
        TargetPlatform.android: ['$_sdcard/RetroArch/saves'],
        TargetPlatform.iOS: ['RetroArch/saves'],
      },
      androidPackages: ['com.retroarch', 'com.retroarch.aarch64', 'com.retroarch.ra32'],
      notesEs:
          'Saves .srm con el nombre de la ROM (Game Boy, GBA, DS con melonDS/DeSmuME, N64). En iOS la carpeta está en «En mi iPhone › RetroArch».',
      notesEn:
          '.srm saves named after the ROM (Game Boy, GBA, DS with melonDS/DeSmuME, N64). On iOS the folder is under “On My iPhone › RetroArch”.',
    ),
    Emulator(
      id: 'mgba',
      name: 'mGBA',
      consoles: {pk.Platform.gameBoy, pk.Platform.gameBoyColor, pk.Platform.gameBoyAdvance},
      notesEs: 'Guarda el .sav junto a la ROM: vincula la carpeta de tus ROMs.',
      notesEn: 'Stores the .sav next to the ROM: link your ROM folder.',
    ),
    Emulator(
      id: 'melonds',
      name: 'melonDS',
      consoles: {pk.Platform.nintendoDs},
      androidPackages: ['me.magnum.melonds'],
      notesEs: 'Guarda el .sav junto a la ROM (o en la carpeta de saves elegida en sus ajustes).',
      notesEn: 'Stores the .sav next to the ROM (or in the save folder chosen in its settings).',
    ),
    Emulator(
      id: 'azahar',
      name: 'Azahar / Lime3DS',
      consoles: {pk.Platform.nintendo3ds},
      paths: {
        TargetPlatform.windows: [r'%APPDATA%\Azahar\sdmc', r'%APPDATA%\Lime3DS\sdmc', r'%APPDATA%\Citra\sdmc'],
        TargetPlatform.linux: [
          r'$XDG_DATA_HOME/azahar-emu/sdmc',
          r'$XDG_DATA_HOME/lime3ds-emu/sdmc',
          r'$XDG_DATA_HOME/citra-emu/sdmc',
        ],
        TargetPlatform.macOS: [
          '~/Library/Application Support/Azahar/sdmc',
          '~/Library/Application Support/Lime3DS/sdmc',
        ],
        TargetPlatform.android: ['$_sdcard/azahar-emu/sdmc', '$_sdcard/lime3ds-emu/sdmc'],
      },
      androidPackages: ['org.azahar_emu.azahar', 'io.github.lime3ds.android'],
      notesEs: 'El save es el archivo «main» de Nintendo 3DS/<id>/<id>/title/00040000/<juego>/data/00000001/.',
      notesEn: 'The save is the “main” file in Nintendo 3DS/<id>/<id>/title/00040000/<game>/data/00000001/.',
    ),
    Emulator(
      id: 'dolphin',
      name: 'Dolphin',
      consoles: {pk.Platform.gameCube, pk.Platform.wii},
      paths: {
        TargetPlatform.windows: [r'%APPDATA%\Dolphin Emulator', r'%USERPROFILE%\Documents\Dolphin Emulator'],
        TargetPlatform.linux: [r'$XDG_DATA_HOME/dolphin-emu', '~/.var/app/org.DolphinEmu.dolphin-emu/data/dolphin-emu'],
        TargetPlatform.macOS: ['~/Library/Application Support/Dolphin'],
        TargetPlatform.android: ['$_sdcard/Android/data/org.dolphinemu.dolphinemu/files', '$_sdcard/dolphin-emu'],
      },
      androidPackages: ['org.dolphinemu.dolphinemu'],
      notesEs:
          'GameCube: GC/<región>/Card A (.gci) o la Memory Card .raw. Wii: Wii/title/00010000/<juego>/data. En Android 11+ la carpeta Android/data no se puede elegir: usa «Exportar» de Dolphin.',
      notesEn:
          'GameCube: GC/<region>/Card A (.gci) or the .raw Memory Card. Wii: Wii/title/00010000/<game>/data. On Android 11+ Android/data cannot be picked: use Dolphin’s export.',
    ),
    Emulator(
      id: 'delta',
      name: 'Delta (iOS)',
      consoles: {pk.Platform.gameBoy, pk.Platform.gameBoyColor, pk.Platform.gameBoyAdvance, pk.Platform.nintendoDs},
      iosScheme: 'delta',
      notesEs:
          'Delta no expone su carpeta: exporta el save desde el menú del juego (Exportar archivo de guardado) e impórtalo; o vincula la carpeta de sincronización de Delta en Dropbox/Google Drive.',
      notesEn:
          'Delta does not expose its folder: export the save from the game menu (Export Save File) and import it, or link Delta’s Dropbox/Google Drive sync folder.',
    ),
    Emulator(
      id: 'switch-android',
      name: 'Eden / Citron / Sudachi / Yuzu (Android)',
      consoles: {pk.Platform.nintendoSwitch},
      paths: {
        TargetPlatform.android: [
          '$_sdcard/Android/data/dev.eden.eden_emulator/files/nand/user/save',
          '$_sdcard/Android/data/org.citron.citron_emu/files/nand/user/save',
          '$_sdcard/Android/data/org.sudachi.sudachi_emu/files/nand/user/save',
          '$_sdcard/Android/data/org.yuzu.yuzu_emu/files/nand/user/save',
        ],
      },
      androidPackages: [
        'dev.eden.eden_emulator',
        'org.citron.citron_emu',
        'org.sudachi.sudachi_emu',
        'org.yuzu.yuzu_emu',
      ],
      notesEs:
          'Saves en nand/user/save/0000000000000000/<usuario>/<juego>/. En Android 11+ el sistema no deja elegir Android/data: exporta los datos de guardado desde el emulador a una carpeta normal y vincula esa.',
      notesEn:
          'Saves under nand/user/save/0000000000000000/<user>/<game>/. On Android 11+ the system won’t let you pick Android/data: export the save data from the emulator to a regular folder and link that one.',
    ),
  ];

  static Emulator? byId(String id) => all.where((e) => e.id == id).firstOrNull;

  /// Expande una plantilla de ruta. null si falta alguna variable.
  static String? expand(String template, {required Map<String, String> env, String? home, bool windows = false}) {
    var s = template;
    if (s.startsWith('~')) {
      if (home == null) return null;
      s = home + s.substring(1);
    }
    String? val(String name) {
      final v = env[name];
      if (v != null && v.isNotEmpty) return v;
      if (home == null) return null;
      return switch (name) {
        'XDG_DATA_HOME' => p.join(home, '.local', 'share'),
        'XDG_CONFIG_HOME' => p.join(home, '.config'),
        _ => null,
      };
    }

    var failed = false;
    s = s.replaceAllMapped(RegExp(r'%([A-Z]+)%|\$([A-Z_]+)'), (m) {
      final name = m.group(1) ?? m.group(2)!;
      final v = name == 'SDCARD' ? (env['SDCARD'] ?? '/storage/emulated/0') : val(name);
      if (v == null) failed = true;
      return v ?? '';
    });
    if (failed) return null;
    return windows ? s.replaceAll('/', r'\') : s;
  }

  /// Rutas candidatas de [e] en [platform].
  static List<String> candidates(
    Emulator e,
    TargetPlatform platform, {
    required Map<String, String> env,
    String? home,
  }) => [
    for (final t in e.paths[platform] ?? const <String>[])
      ?expand(t, env: env, home: home, windows: platform == TargetPlatform.windows),
  ];

  /// Emuladores con alguna carpeta por defecto que existe en este equipo
  /// (solo escritorio sin sandbox: Windows y Linux; en macOS, iOS y Android
  /// el sistema exige elegir la carpeta).
  static Future<List<(Emulator, String)>> detectDesktop() async {
    if (kIsWeb || !(io.Platform.isWindows || io.Platform.isLinux)) return const [];
    final platform = io.Platform.isWindows ? TargetPlatform.windows : TargetPlatform.linux;
    final env = io.Platform.environment;
    final home = env['HOME'] ?? env['USERPROFILE'];
    final out = <(Emulator, String)>[];
    for (final e in all) {
      for (final path in candidates(e, platform, env: env, home: home)) {
        if (await io.Directory(path).exists()) {
          out.add((e, path));
          break;
        }
      }
    }
    return out;
  }
}

/// Carpeta de un emulador vinculada por el usuario.
class EmulatorLink {
  const EmulatorLink(this.emulatorId, this.location, {this.lastBackup});

  final String emulatorId;
  final ArcaLocation location;
  final DateTime? lastBackup;

  Emulator? get emulator => Emulators.byId(emulatorId);

  EmulatorLink withBackup(DateTime t) => EmulatorLink(emulatorId, location, lastBackup: t);

  Map<String, Object?> toJson() => {
    'emulator': emulatorId,
    'location': location.toJson(),
    if (lastBackup != null) 'lastBackup': lastBackup!.toIso8601String(),
  };

  static EmulatorLink? fromJson(Object? j) {
    if (j is! Map) return null;
    final loc = ArcaLocation.fromJson(Map<String, Object?>.from(j['location'] as Map? ?? const {}));
    final id = j['emulator'];
    if (loc == null || id is! String) return null;
    return EmulatorLink(id, loc, lastBackup: DateTime.tryParse('${j['lastBackup'] ?? ''}'));
  }

  static List<EmulatorLink> decodeList(String? s) {
    if (s == null || s.isEmpty) return const [];
    try {
      final list = jsonDecode(s);
      if (list is! List) return const [];
      return [for (final e in list) ?fromJson(e)];
    } catch (_) {
      return const [];
    }
  }

  static String encodeList(List<EmulatorLink> links) => jsonEncode([for (final l in links) l.toJson()]);
}
