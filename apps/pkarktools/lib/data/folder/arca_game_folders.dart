import 'dart:convert';
import 'dart:typed_data';

import 'package:pkcore/pkcore.dart' as pk show Platform;
import 'package:pkcore/pkcore.dart' hide Platform;

import 'arca_folder.dart';
import 'arca_layout.dart';
import 'folder_fs.dart';

class GameFoldersResult {
  int created = 0;

  /// Ya existían (no se tocan).
  int existing = 0;
  final List<String> failures = [];
}

/// Carpetas por juego (`PKArkTools/<Juego>/`) con un LEEME que explica qué
/// save dejar ahí. Son las mismas carpetas de juego del layout de
/// entrenadores, y hacen de bandeja de entrada: un save suelto dejado en
/// `<Juego>/` se adopta solo (ver `ArcaRepository`).
abstract final class ArcaGameFolders {
  /// Nombres de LEEME de las carpetas de juego (se escribe uno, en el idioma
  /// de la app; cualquiera de los dos cuenta como existente).
  static const readmeNames = {'LEEME.txt', 'README.txt'};

  static String readmeName({required bool es}) => es ? 'LEEME.txt' : 'README.txt';

  /// Carpeta de cada juego (igual que [ArcaLayout.gameDir]).
  static String dirOf(GameVersion g) => ArcaLayout.gameDir(g.code);

  /// Juego de una carpeta de primer nivel, o null si no es una carpeta de juego.
  static GameVersion? gameOfDir(String dir) {
    for (final g in GameVersion.values) {
      if (dirOf(g) == dir) return g;
    }
    return null;
  }

  /// `true` si [rel] es el LEEME de una carpeta de juego (`<Juego>/LEEME.txt`).
  static bool isGameReadme(String rel) {
    final parts = rel.split('/');
    return parts.length == 2 && readmeNames.contains(parts[1]) && gameOfDir(parts[0]) != null;
  }

  /// Qué archivo dejar en la carpeta de [g] y con qué nombre suele venir.
  static String hint(GameVersion g, {required bool es}) {
    final main = ArcaLayout.mainFileName(g.code, 'x.sav');
    return switch (g.platform) {
      pk.Platform.nintendoSwitch => es
          ? 'Switch: el archivo «$main» exportado con JKSM o Checkpoint, o el de la carpeta de guardado del emulador (Ryujinx, Eden, Citron…).'
          : 'Switch: the “$main” file exported with JKSM or Checkpoint, or the one in the emulator save folder (Ryujinx, Eden, Citron…).',
      pk.Platform.nintendo3ds => es
          ? '3DS: el archivo «main» exportado con Checkpoint o JKSM, o el de la carpeta de guardado de Azahar/Citra.'
          : '3DS: the “main” file exported with Checkpoint or JKSM, or the one in the Azahar/Citra save folder.',
      pk.Platform.nintendoDs => es
          ? 'DS: el .sav de Checkpoint, TWiLight Menu++, melonDS o un lector de cartuchos, o el .dsv de DeSmuME/DraStic.'
          : 'DS: the .sav from Checkpoint, TWiLight Menu++, melonDS or a cartridge reader, or the .dsv from DeSmuME/DraStic.',
      pk.Platform.gameBoyAdvance => es
          ? 'GBA: el .sav de mGBA, VisualBoyAdvance, Delta o un lector de cartuchos (o el .srm de RetroArch).'
          : 'GBA: the .sav from mGBA, VisualBoyAdvance, Delta or a cartridge reader (or the .srm from RetroArch).',
      _ => es
          ? 'Game Boy: el .sav de SameBoy, Gambatte, mGBA, Delta o un lector de cartuchos (o el .srm de RetroArch).'
          : 'Game Boy: the .sav from SameBoy, Gambatte, mGBA, Delta or a cartridge reader (or the .srm from RetroArch).',
    };
  }

  static String readme(GameVersion g, {required bool es}) {
    final name = es ? g.nameEs : g.nameEn;
    final main = ArcaLayout.mainFileName(g.code, 'x.sav');
    return es
        ? '''
${ArcaLayout.readmeMarker} · $name
${'=' * 40}

Deja aquí el save de $name tal cual sale del juego o del emulador:

  ${hint(g, es: true)}

No hace falta renombrarlo. Al abrir PKArkTools (o al reindexar) se comprueba
que es de este juego, se guarda como copia nueva en
<Entrenador (TID)>/historial/ y pasa a ser la última versión
(<Entrenador (TID)>/$main). El archivo suelto se retira de aquí cuando su
copia está verificada. Si no se puede leer o es de otro juego, se queda donde
está y la app te avisa.
'''
        : '''
${ArcaLayout.readmeMarker} · $name
${'=' * 40}

Drop the $name save here exactly as it comes from the game or emulator:

  ${hint(g, es: false)}

No need to rename it. When PKArkTools opens (or reindexes) it checks that it
belongs to this game, stores it as a new copy in <Trainer (TID)>/historial/
and makes it the latest version (<Trainer (TID)>/$main). The loose file is
removed from here once its copy is verified. If it can't be read or belongs
to another game, it stays where it is and the app tells you.
''';
  }

  /// Juegos cuya carpeta ya existe (tiene LEEME o alguna partida).
  static Future<Set<GameVersion>> existing(ArcaFolder folder) async {
    final out = <GameVersion>{};
    for (final e in await folder.fs.list(folder.prefix)) {
      final rel = folder.prefix.isEmpty ? e.path : e.path.substring(folder.prefix.length + 1);
      final parts = rel.split('/');
      if (parts.length < 2) continue;
      final g = gameOfDir(parts.first);
      if (g != null) out.add(g);
    }
    return out;
  }

  /// Crea las carpetas de [games] con su LEEME. Idempotente: una carpeta que
  /// ya tiene LEEME (en cualquier idioma) no se toca.
  static Future<GameFoldersResult> create(ArcaFolder folder, Iterable<GameVersion> games, {required bool es}) async {
    final result = GameFoldersResult();
    await folder.ensureReadme();
    for (final g in games) {
      final dir = dirOf(g);
      try {
        var found = false;
        for (final n in readmeNames) {
          if (await folder.exists('$dir/$n')) found = true;
        }
        if (found) {
          result.existing++;
          continue;
        }
        try {
          await folder.writeNew('$dir/${readmeName(es: es)}', Uint8List.fromList(utf8.encode(readme(g, es: es))));
          result.created++;
        } on FsExistsException {
          result.existing++;
        }
      } catch (e) {
        result.failures.add('$dir: $e');
      }
    }
    return result;
  }
}
