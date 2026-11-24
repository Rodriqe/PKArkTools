import 'dart:convert';

import 'package:pkcore/pkcore.dart' as pk show Platform;
import 'package:pkcore/pkcore.dart' hide Platform;

import 'folder_fs.dart' show SystemJunk;

/// Estructura de la carpeta del Arca.
///
/// ```
/// PKArkTools/
///   README.txt
///   <Juego>/<Entrenador (TID)>/
///     main                      ← última versión (nombre según el juego, ver [mainFileName])
///     ultima.json               ← qué copia del historial es la última (derivado)
///     historial/
///       <AAAA-MM-DD_HHMMSS>_<hash8>.<ext>        ← copias inmutables
///       <AAAA-MM-DD_HHMMSS>_<hash8>.<ext>.json
/// ```
/// Las copias del historial son inmutables y su nombre es único (fecha +
/// hash), así que varios dispositivos pueden escribir en la misma carpeta
/// sincronizada sin pisarse. El historial es la fuente de verdad: el archivo
/// principal y `ultima.json` se regeneran siempre desde él.
abstract final class ArcaLayout {
  static const rootDir = 'PKArkTools';
  static const readmeName = 'README.txt';
  static const readmeMarker = 'PKArkTools · Arca';

  /// Línea que identifica la versión del README (se reescribe si cambia).
  static const readmeRevision = 'Estructura v2 (historial/ + archivo principal)';
  static const sidecarExt = '.json';
  static const schema = 'pkarktools-snapshot';

  /// Esquemas de versiones con el nombre anterior de la app
  /// (`<nombre>-snapshot`): mismo formato, se leen igual (el resto de campos
  /// se valida como siempre) y se reescriben con [schema] al migrar o arreglar.
  static final legacySchema = RegExp(r'^[a-z][a-z0-9]*-snapshot$');

  static bool isSnapshotSchema(Object? s) => s == schema || (s is String && legacySchema.hasMatch(s));

  /// Carpeta (en la raíz del Arca) donde «Arreglar» aparta lo irreparable.
  /// Nunca se indexa ni se ofrece para adoptar.
  static const quarantineDir = '_cuarentena';

  /// Subcarpeta con las copias inmutables de cada entrenador.
  static const historyDir = 'historial';

  /// Índice derivado con la última copia de cada archivo principal.
  static const latestName = 'ultima.json';
  static const latestSchema = 'pkarktools-latest';

  static const schemaVersion = 1;
  static const maxSegment = 64;

  static const _windowsReserved = {
    'CON', 'PRN', 'AUX', 'NUL', //
    'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
  };

  /// Sanea un segmento de ruta para Windows, macOS, Linux, Android (FAT/exFAT)
  /// y los proveedores de nube: sin separadores ni caracteres reservados, sin
  /// puntos o espacios al final, sin nombres reservados de Windows y con
  /// longitud acotada.
  static String safeSegment(String s) {
    var out = s
        .replaceAll(RegExp(r'\s*[/\\:]\s*'), ' - ')
        .replaceAll(RegExp(r'[*?"<>|\x00-\x1F\x7F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Sin punto inicial (archivo oculto) ni puntos/espacios finales (Windows).
    out = out.replaceFirst(RegExp(r'^[.\s]+'), '').replaceFirst(RegExp(r'[.\s]+$'), '');
    if (out.isEmpty) out = '_';
    final runes = out.runes.toList();
    if (runes.length > maxSegment) out = String.fromCharCodes(runes.take(maxSegment)).trimRight();
    final stem = out.split('.').first.toUpperCase();
    if (_windowsReserved.contains(stem)) out = '_$out';
    return out;
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// `AAAA-MM-DD_HHMMSS` en hora local.
  static String stamp(DateTime d) {
    final l = d.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-${_two(l.month)}-${_two(l.day)}_${_two(l.hour)}${_two(l.minute)}${_two(l.second)}';
  }

  /// Extensión del archivo original, en minúsculas; `.sav` si no tiene una
  /// razonable (p. ej. el `main` de Switch).
  static String extensionFor(String originalName) {
    final dot = originalName.lastIndexOf('.');
    if (dot <= 0 || dot == originalName.length - 1) return '.sav';
    final ext = originalName.substring(dot).toLowerCase();
    if (!RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(ext)) return '.sav';
    if (const {'.json', '.tmp', '.txt', '.icloud', '.part', '.partial'}.contains(ext)) return '.sav';
    return ext;
  }

  static String gameDir(String gameCode) => safeSegment(GameVersion.fromCode(gameCode)?.nameEs ?? gameCode);

  static String trainerDir(String trainerName, String displayTid) =>
      safeSegment('${trainerName.trim().isEmpty ? '_' : trainerName} ($displayTid)');

  /// Extensiones de contenedor que conservan los emuladores y lectores
  /// (el resto se guarda como `.sav`).
  static const containerExts = {'.sav', '.dsv', '.srm', '.sa1', '.fla', '.dat', '.bin', '.sra', '.eep'};

  /// Contenedores de GameCube: `.gci` (un archivo de la Memory Card, carpeta
  /// GCI de Dolphin) e imágenes de Memory Card (`.raw` de Dolphin, `.gcp`, `.mci`).
  static const gameCubeExts = {'.gci', '.raw', '.gcp', '.mci'};

  /// Nombre del archivo principal (la última versión) de una copia.
  ///
  /// | Juego / plataforma                         | Nombre           |
  /// |--------------------------------------------|------------------|
  /// | Espada/Escudo, Leyendas Arceus, Escarlata/Púrpura, Leyendas Z-A | `main` |
  /// | Diamante Brillante / Perla Reluciente      | `SaveData.bin`   |
  /// | Let's Go Pikachu / Eevee                   | `savedata.bin`   |
  /// | 3DS (X/Y, ROZA, Sol/Luna, USUL)            | `main`           |
  /// | GB, GBC, GBA, DS                           | `<Juego><ext>`   |
  /// | Colosseum, XD, Box (GameCube)              | el `.gci` / `.raw` original, o `<Juego>.bin` |
  /// | Stadium, Stadium 2 (N64)                   | `<Juego><ext>` (`.fla`, `.sra`, `.sav`…) |
  /// | Battle Revolution / Rancho (Wii)           | `PbrSaveData` / `pokemonranch.bin` |
  ///
  /// Son los nombres que usan Checkpoint/JKSM y los emuladores de Switch y
  /// 3DS. En GB…DS `<ext>` es la del contenedor original si es conocida
  /// (`.sav`, `.dsv` de DeSmuME/DraStic, `.srm` de RetroArch, `.sa1`, `.fla`,
  /// `.dat`, `.bin`) y `.sav` si no: un mismo entrenador con contenedores
  /// distintos tiene un archivo principal por contenedor.
  static String mainFileName(String gameCode, String originalName) {
    final game = GameVersion.fromCode(gameCode);
    switch (game) {
      case GameVersion.brilliantDiamondShiningPearl:
        return 'SaveData.bin';
      case GameVersion.letsGo:
        return 'savedata.bin';
      case null:
        break;
      default:
        if (game.platform == pk.Platform.nintendoSwitch || game.platform == pk.Platform.nintendo3ds) return 'main';
        // Wii: el nombre del archivo de la NAND de Dolphin.
        if (game == GameVersion.battleRevolution) return 'PbrSaveData';
        if (game == GameVersion.ranch) return 'pokemonranch.bin';
        if (game.platform == pk.Platform.gameCube) {
          // Dolphin identifica los .gci por su cabecera, no por el nombre, pero
          // conservar el original (`01-GC6E-….gci`, `MemoryCardA.USA.raw`)
          // ayuda a reconocerlo; los datos sin cabecera, `<Juego>.bin`.
          final ext = extensionFor(originalName);
          if (gameCubeExts.contains(ext)) return safeSegment(originalName);
          return '${gameDir(gameCode)}.bin';
        }
    }
    var ext = extensionFor(originalName);
    if (!containerExts.contains(ext)) ext = '.sav';
    return '${gameDir(gameCode)}$ext';
  }

  /// Carpeta del entrenador (`<Juego>/<Entrenador (TID)>`) de una copia, esté
  /// en `historial/` o (diseño anterior) suelta en la carpeta del entrenador.
  static String ownerDirOf(String savePath) {
    final parts = savePath.split('/')..removeLast();
    if (parts.isNotEmpty && parts.last == historyDir) parts.removeLast();
    return parts.join('/');
  }

  /// `true` si la copia está en un `historial/` (diseño actual).
  static bool inHistory(String savePath) {
    final parts = savePath.split('/');
    return parts.length >= 2 && parts[parts.length - 2] == historyDir;
  }

  /// Ruta en `historial/` de una copia del diseño anterior.
  static String historyPathFor(String legacySavePath) {
    final name = legacySavePath.split('/').last;
    final dir = ownerDirOf(legacySavePath);
    return dir.isEmpty ? '$historyDir/$name' : '$dir/$historyDir/$name';
  }

  static String _join(String dir, String name) => dir.isEmpty ? name : '$dir/$name';

  static String mainPath(String ownerDir, String mainName) => _join(ownerDir, mainName);

  static String latestPath(String ownerDir) => _join(ownerDir, latestName);

  /// Copias de conflicto de la nube de un archivo principal: `main (1)`,
  /// `main 2`, `main-PORTATIL`, `Esmeralda (conflicted copy).sav`…
  static bool isConflictOf(String name, String mainName) {
    if (name == mainName) return false;
    final dot = mainName.lastIndexOf('.');
    final stem = dot > 0 ? mainName.substring(0, dot) : mainName;
    final ext = dot > 0 ? mainName.substring(dot) : '';
    if (!name.startsWith(stem) || !name.toLowerCase().endsWith(ext.toLowerCase())) return false;
    final middle = name.substring(stem.length, name.length - ext.length);
    return middle.isNotEmpty && RegExp(r'^[\s_\-.(]').hasMatch(middle);
  }

  /// Ruta relativa (a `PKArkTools/`) del save de un snapshot (en `historial/`).
  static String savePath({
    required String gameCode,
    required String trainerName,
    required String displayTid,
    required DateTime importedAt,
    required String sha256,
    required String originalName,
    int attempt = 0,
  }) {
    final base = '${stamp(importedAt)}_${sha256.substring(0, 8)}${attempt > 0 ? '-${attempt + 1}' : ''}';
    return '${gameDir(gameCode)}/${trainerDir(trainerName, displayTid)}/$historyDir/$base${extensionFor(originalName)}';
  }

  static String sidecarFor(String savePath) => '$savePath$sidecarExt';

  /// Nombre de un save gestionado por el Arca.
  static final managedSave = RegExp(r'^\d{4}-\d{2}-\d{2}_\d{6}_[0-9a-f]{8}(-\d+)?\.[a-z0-9]{1,8}$');

  /// Nombre de un sidecar gestionado.
  static final managedSidecar = RegExp(r'^\d{4}-\d{2}-\d{2}_\d{6}_[0-9a-f]{8}(-\d+)?\.[a-z0-9]{1,8}\.json$');

  static final _managedPrefix = RegExp(r'^\d{4}-\d{2}-\d{2}_\d{6}_[0-9a-f]{8}');

  /// Copia de conflicto de la nube de una copia del historial o de su `.json`
  /// (`2026-01-01_120000_1a2b3c4d (1).sav`…).
  static bool isHistoryConflict(String name) =>
      _managedPrefix.hasMatch(name) && !managedSave.hasMatch(name) && !managedSidecar.hasMatch(name);

  static final _conflict = RegExp(
    r'(conflicted copy|copia en conflicto|\bconflict\b|\.sync-conflict-|\s\(\d+\)$)',
    caseSensitive: false,
  );

  /// Archivos que se ignoran sin error: temporales y parciales de la nube,
  /// copias de conflicto, ocultos y metadatos del sistema.
  static IgnoreReason? ignoreReason(String relPath) {
    final segments = relPath.split('/');
    if (segments.length > 1 && segments.first == quarantineDir) return IgnoreReason.quarantined;
    for (final s in segments.take(segments.length - 1)) {
      if (s.startsWith('.') || s.startsWith('~') || SystemJunk.isDir(s)) return IgnoreReason.hidden;
    }
    final name = segments.last;
    final lower = name.toLowerCase();
    if (lower.endsWith('.icloud')) return IgnoreReason.cloudPlaceholder;
    if (lower.endsWith('.tmp') ||
        lower.endsWith('.part') ||
        lower.endsWith('.partial') ||
        lower.endsWith('.crdownload') ||
        lower.endsWith('.download') ||
        lower.endsWith('.gdoc') ||
        lower.startsWith('~\$') ||
        lower.startsWith('.~')) {
      return IgnoreReason.partial;
    }
    if (name.startsWith('.') || SystemJunk.isFile(name)) return IgnoreReason.hidden;
    if (managedSave.hasMatch(name) || managedSidecar.hasMatch(name)) return null;
    // Un nombre del Arca con algo añadido es una copia de conflicto de la nube
    // ("… 2.sav" de iCloud, "…-PORTATIL.sav" de OneDrive, "… (1).sav"…).
    if (_managedPrefix.hasMatch(name)) return IgnoreReason.conflictCopy;
    final stem = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    if (_conflict.hasMatch(stem)) return IgnoreReason.conflictCopy;
    return null;
  }

  static String readme() => '''
$readmeMarker
====================
$readmeRevision

Esta carpeta contiene las copias de tus partidas guardadas por PKArkTools.
Puedes ponerla en iCloud Drive, Google Drive, OneDrive, Dropbox o Syncthing
y todos tus dispositivos verán las mismas copias.

Estructura
----------
  PKArkTools/
    README.txt                       (este archivo)
    <Juego>/<Entrenador (TID)>/
      main                           LA ÚLTIMA VERSIÓN, lista para copiar al
                                     juego o al emulador. Se llama como la
                                     espera cada juego: "main" (Switch y 3DS),
                                     "SaveData.bin" (Diamante Brillante / Perla
                                     Reluciente), "savedata.bin" (Let's Go) o
                                     "<Juego>.sav" / ".dsv" / ".srm"... (GB, GBA, DS)
                                     o el .gci / .raw original (GameCube).
      ultima.json                    qué copia del historial es la última.
      historial/
        AAAA-MM-DD_HHMMSS_<hash8>.<ext>        cada copia del save, tal cual
        AAAA-MM-DD_HHMMSS_<hash8>.<ext>.json   sus datos: SHA-256 completo, juego,
                                               entrenador, TID/SID, horas, origen,
                                               notas, dispositivo y versión.

Reglas
------
* El historial es la fuente de verdad. Sus archivos nunca se modifican ni se
  sobrescriben: cada copia nueva es un archivo nuevo con nombre único (fecha +
  hash). Por eso varios dispositivos pueden usar la misma carpeta a la vez.
* El archivo principal es una copia de la entrada más reciente del historial.
  PKArkTools lo reescribe (de forma atómica) cuando llega una copia más nueva
  y lo regenera si falta.
* Si reemplazas el archivo principal a mano (p. ej. copias encima un save
  nuevo del juego), PKArkTools lo detecta y te ofrece "Guardar como nueva
  copia"; nunca lo borra ni lo pisa.
* Restaurar una copia antigua crea una entrada nueva en el historial y
  actualiza el archivo principal: el historial nunca se reescribe.
* Si copias un save suelto en cualquier subcarpeta, PKArkTools lo detecta y
  te ofrece "adoptarlo" (lo identifica y lo coloca en su sitio).
* Las copias de conflicto de la nube ("conflicted copy", "(1)", .icloud,
  .tmp...) se ignoran. Las del archivo principal se retiran solas si su
  contenido ya está en el historial; si no, se ofrecen para adoptar.
* La base de datos de la app es solo un índice local de cada dispositivo y
  nunca se guarda aquí: se puede reconstruir en cualquier momento desde
  Ajustes → Reindexar.
''';
}

enum IgnoreReason { hidden, cloudPlaceholder, partial, conflictCopy, quarantined }

/// Metadatos de un snapshot tal como se guardan en su `.json`.
class SnapshotMeta {
  const SnapshotMeta({
    required this.sha256,
    required this.sizeBytes,
    required this.importedAt,
    required this.originalFileName,
    required this.origin,
    required this.gameCode,
    required this.generation,
    required this.versionId,
    required this.format,
    required this.checksum,
    required this.trainerName,
    required this.tid,
    required this.sid,
    required this.displayTid,
    required this.displaySid,
    required this.playTimeSeconds,
    required this.partySummary,
    required this.boxedCount,
    required this.slot,
    this.sourcePath,
    this.note,
    this.deviceId,
    this.deviceName,
    this.schemaVersion = ArcaLayout.schemaVersion,
  });

  final String sha256;
  final int sizeBytes;
  final DateTime importedAt;
  final String originalFileName;
  final String origin;
  final String? sourcePath;
  final String? note;
  final String gameCode;
  final int generation;
  final int? versionId;
  final String format;
  final String checksum;
  final String trainerName;
  final int tid;
  final int? sid;
  final String displayTid;
  final String? displaySid;
  final int playTimeSeconds;
  final String partySummary;
  final int boxedCount;
  final String? deviceId;
  final String? deviceName;
  final int schemaVersion;

  /// Partida a la que pertenece (para una edición puede diferir del
  /// entrenador del propio save, p. ej. si se cambió el nombre).
  final SlotMeta slot;

  /// Copia con la versión de la partida fijada a mano (null = sin fijar).
  SnapshotMeta withSlotVersion(int? v) => SnapshotMeta(
        sha256: sha256,
        sizeBytes: sizeBytes,
        importedAt: importedAt,
        originalFileName: originalFileName,
        origin: origin,
        gameCode: gameCode,
        generation: generation,
        versionId: versionId,
        format: format,
        checksum: checksum,
        trainerName: trainerName,
        tid: tid,
        sid: sid,
        displayTid: displayTid,
        displaySid: displaySid,
        playTimeSeconds: playTimeSeconds,
        partySummary: partySummary,
        boxedCount: boxedCount,
        sourcePath: sourcePath,
        note: note,
        deviceId: deviceId,
        deviceName: deviceName,
        schemaVersion: schemaVersion,
        slot: SlotMeta(
          identityKey: slot.identityKey,
          gameCode: slot.gameCode,
          generation: slot.generation,
          versionId: v ?? versionId,
          trainerName: slot.trainerName,
          tid: slot.tid,
          sid: slot.sid,
          displayTid: slot.displayTid,
          displaySid: slot.displaySid,
          versionManual: v != null,
        ),
      );

  Map<String, Object?> toJson() => {
        'schema': ArcaLayout.schema,
        'schemaVersion': schemaVersion,
        'sha256': sha256,
        'sizeBytes': sizeBytes,
        'importedAt': importedAt.toUtc().toIso8601String(),
        'originalFileName': originalFileName,
        'origin': origin,
        'sourcePath': sourcePath,
        'note': note,
        'device': {'id': deviceId, 'name': deviceName},
        'game': {
          'code': gameCode,
          'name': GameVersion.fromCode(gameCode)?.nameEs,
          'generation': generation,
          'versionId': versionId,
          'format': format,
          'checksum': checksum,
        },
        'trainer': {
          'name': trainerName,
          'tid': tid,
          'sid': sid,
          'displayTid': displayTid,
          'displaySid': displaySid,
          'playTimeSeconds': playTimeSeconds,
        },
        'summary': {'party': partySummary, 'boxedCount': boxedCount},
        'slot': slot.toJson(),
      };

  String encode() => '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';

  /// Lanza [FormatException] si el JSON no es un sidecar válido.
  static SnapshotMeta decode(String text) {
    final Object? raw;
    try {
      raw = jsonDecode(text);
    } catch (_) {
      throw const FormatException('JSON ilegible');
    }
    if (raw is! Map<String, Object?> || !ArcaLayout.isSnapshotSchema(raw['schema'])) {
      throw const FormatException('No es un sidecar de PKArkTools');
    }
    T req<T>(Map<String, Object?> m, String k) {
      final v = m[k];
      if (v is T) return v;
      throw FormatException('Falta "$k"');
    }

    Map<String, Object?> obj(Map<String, Object?> m, String k) => req<Map<String, Object?>>(m, k);
    final sha = req<String>(raw, 'sha256');
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) throw const FormatException('SHA-256 no válido');
    final game = obj(raw, 'game');
    final trainer = obj(raw, 'trainer');
    final summary = obj(raw, 'summary');
    final device = raw['device'] is Map<String, Object?> ? raw['device'] as Map<String, Object?> : const <String, Object?>{};
    final importedAt = DateTime.tryParse(req<String>(raw, 'importedAt'));
    if (importedAt == null) throw const FormatException('Fecha no válida');
    return SnapshotMeta(
      schemaVersion: (raw['schemaVersion'] as num?)?.toInt() ?? 1,
      sha256: sha,
      sizeBytes: req<num>(raw, 'sizeBytes').toInt(),
      importedAt: importedAt.toLocal(),
      originalFileName: req<String>(raw, 'originalFileName'),
      origin: req<String>(raw, 'origin'),
      sourcePath: raw['sourcePath'] as String?,
      note: raw['note'] as String?,
      deviceId: device['id'] as String?,
      deviceName: device['name'] as String?,
      gameCode: req<String>(game, 'code'),
      generation: req<num>(game, 'generation').toInt(),
      versionId: (game['versionId'] as num?)?.toInt(),
      format: (game['format'] as String?) ?? '',
      checksum: (game['checksum'] as String?) ?? 'notChecked',
      trainerName: req<String>(trainer, 'name'),
      tid: req<num>(trainer, 'tid').toInt(),
      sid: (trainer['sid'] as num?)?.toInt(),
      displayTid: req<String>(trainer, 'displayTid'),
      displaySid: trainer['displaySid'] as String?,
      playTimeSeconds: (trainer['playTimeSeconds'] as num?)?.toInt() ?? 0,
      partySummary: (summary['party'] as String?) ?? '',
      boxedCount: (summary['boxedCount'] as num?)?.toInt() ?? 0,
      slot: SlotMeta.fromJson(obj(raw, 'slot')),
    );
  }
}

/// Identidad de la partida (agrupa snapshots).
class SlotMeta {
  const SlotMeta({
    required this.identityKey,
    required this.gameCode,
    required this.generation,
    required this.versionId,
    required this.trainerName,
    required this.tid,
    required this.sid,
    required this.displayTid,
    required this.displaySid,
    this.versionManual = false,
  });

  final String identityKey;

  /// `true` si [versionId] lo fijó el usuario (el save no la guarda).
  final bool versionManual;
  final String gameCode;
  final int generation;
  final int? versionId;
  final String trainerName;
  final int tid;
  final int? sid;
  final String displayTid;
  final String? displaySid;

  Map<String, Object?> toJson() => {
        'identityKey': identityKey,
        'gameCode': gameCode,
        'generation': generation,
        'versionId': versionId,
        if (versionManual) 'versionManual': true,
        'trainerName': trainerName,
        'tid': tid,
        'sid': sid,
        'displayTid': displayTid,
        'displaySid': displaySid,
      };

  static SlotMeta fromJson(Map<String, Object?> m) {
    final key = m['identityKey'];
    final game = m['gameCode'];
    final name = m['trainerName'];
    final tid = m['tid'];
    final dtid = m['displayTid'];
    if (key is! String || game is! String || name is! String || tid is! num || dtid is! String) {
      throw const FormatException('Bloque "slot" incompleto');
    }
    return SlotMeta(
      identityKey: key,
      gameCode: game,
      generation: (m['generation'] as num?)?.toInt() ?? 0,
      versionId: (m['versionId'] as num?)?.toInt(),
      trainerName: name,
      tid: tid.toInt(),
      sid: (m['sid'] as num?)?.toInt(),
      displayTid: dtid,
      displaySid: m['displaySid'] as String?,
      versionManual: m['versionManual'] == true,
    );
  }
}
