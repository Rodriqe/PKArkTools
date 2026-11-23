import 'dart:convert';
import 'dart:typed_data';

import 'arca_folder.dart';
import 'arca_layout.dart';
import 'folder_fs.dart';

/// Una copia del historial, con lo necesario para elegir la última.
class HistoryEntry {
  const HistoryEntry({
    required this.path,
    required this.sha256,
    required this.importedAt,
    required this.gameCode,
    required this.originalName,
  });

  /// Ruta del save (relativa a la raíz del Arca).
  final String path;
  final String sha256;
  final DateTime importedAt;
  final String gameCode;
  final String originalName;

  String get ownerDir => ArcaLayout.ownerDirOf(path);
  String get mainName => ArcaLayout.mainFileName(gameCode, originalName);
  String get mainPath => ArcaLayout.mainPath(ownerDir, mainName);

  /// Más reciente primero; a igual fecha, la ruta mayor (estable en todos
  /// los dispositivos).
  static int newestFirst(HistoryEntry a, HistoryEntry b) {
    final c = b.importedAt.compareTo(a.importedAt);
    return c != 0 ? c : b.path.compareTo(a.path);
  }
}

/// Estado de un archivo principal tras sincronizarlo con el historial.
enum MainState {
  /// Coincide con la última copia del historial.
  current,

  /// Se escribió (faltaba o era una versión anterior).
  written,

  /// Alguien lo reemplazó a mano: su contenido no está en el historial. No se
  /// toca hasta que el usuario lo guarde como copia nueva.
  modified,

  /// Otro dispositivo escribió una versión más nueva cuyo historial aún no
  /// ha llegado por la sincronización: se espera sin tocar nada.
  pending,

  /// No se pudo escribir o leer (se informa y se reintenta).
  failed,
}

class MainFileStatus {
  const MainFileStatus({
    required this.path,
    required this.ownerDir,
    required this.name,
    required this.state,
    this.latest,
    this.fileSha,
    this.detail,
  });

  final String path;
  final String ownerDir;
  final String name;
  final MainState state;

  /// Última copia del historial para este archivo.
  final HistoryEntry? latest;

  /// SHA-256 del archivo principal tal como está en la carpeta.
  final String? fileSha;
  final String? detail;
}

class MainSyncReport {
  final List<MainFileStatus> mains = [];

  /// Copias de conflicto del principal retiradas (su contenido ya estaba en
  /// el historial).
  int conflictsCleaned = 0;

  /// Archivos sueltos que no son principales ni copias de conflicto ya
  /// conocidas (se ofrecen para adoptar).
  final List<FsEntry> loose = [];

  Iterable<MainFileStatus> get modified => mains.where((m) => m.state == MainState.modified);
  int get written => mains.where((m) => m.state == MainState.written).length;
}

/// Caché de hashes de los archivos principales (tamaño + fecha → SHA-256)
/// para no releerlos en cada reindexado.
typedef MainHashCache = Map<String, (int, DateTime?, String)>;

/// Mantiene el archivo principal de cada carpeta de entrenador como copia
/// derivada de la entrada más reciente de su `historial/`.
abstract final class ArcaMainFiles {
  /// Recalcula los principales: escribe los que faltan o están atrasados,
  /// detecta los reemplazados a mano, retira copias de conflicto ya conocidas
  /// y actualiza `ultima.json`. Nunca borra contenido que no esté en el
  /// historial.
  static Future<MainSyncReport> sync({
    required ArcaFolder folder,
    required FolderListing listing,
    required List<HistoryEntry> history,
    MainHashCache? cache,
    Set<String>? knownShas,
  }) async {
    final report = MainSyncReport();
    final hashes = cache ?? <String, (int, DateTime?, String)>{};
    // Contenido que ya está a salvo en algún historial del Arca.
    final known = {...?knownShas, for (final h in history) h.sha256};

    // Última copia por carpeta y nombre de principal.
    final groups = <String, Map<String, List<HistoryEntry>>>{};
    for (final h in history) {
      groups.putIfAbsent(h.ownerDir, () => {}).putIfAbsent(h.mainName, () => []).add(h);
    }
    final latestIndexes = <String, Map<String, Object?>>{};
    for (final rel in listing.latestIndexes) {
      latestIndexes[_dirOf(rel)] = await _readLatest(folder, rel);
    }

    // Archivos candidatos (sueltos o de conflicto) por carpeta.
    final byDir = <String, Map<String, FsEntry>>{};
    for (final e in [...listing.loose, ...listing.conflicts]) {
      byDir.putIfAbsent(_dirOf(e.path), () => {})[e.path.split('/').last] = e;
    }
    final placeholders = listing.placeholders.toSet();
    final claimed = <String>{};

    Future<String> hashOf(FsEntry e) async {
      final c = hashes[e.path];
      if (c != null && c.$1 == e.size && c.$2 == e.modified) return c.$3;
      final sha = ArcaFolder.sha256Of(await folder.read(e.path));
      hashes[e.path] = (e.size, e.modified, sha);
      return sha;
    }

    final dirs = {...groups.keys, ...latestIndexes.keys};
    for (final dir in dirs) {
      final names = groups[dir] ?? const {};
      final previous = latestIndexes[dir];
      final prevFiles = (previous?['files'] as Map<String, Object?>?) ?? const {};
      final files = byDir[dir] ?? const {};
      final nextFiles = <String, Object?>{...prevFiles};

      // Principales que ultima.json conoce pero ya sin historial (p. ej. la
      // sincronización aún no lo ha traído): no se tocan ni se ofrecen.
      for (final name in prevFiles.keys) {
        if (!names.containsKey(name)) claimed.add(ArcaLayout.mainPath(dir, name));
      }

      for (final MapEntry(key: name, value: entries) in names.entries) {
        entries.sort(HistoryEntry.newestFirst);
        final latest = entries.first;
        final path = ArcaLayout.mainPath(dir, name);
        claimed.add(path);
        final prev = prevFiles[name] as Map<String, Object?>?;
        final prevSha = prev?['sha256'] as String?;
        final prevAt = DateTime.tryParse((prev?['importedAt'] as String?) ?? '');
        // Otro dispositivo ya apunta a una copia más nueva que aún no vemos.
        final behind = prevSha != null && !known.contains(prevSha) && prevAt != null && prevAt.isAfter(latest.importedAt);
        final existing = files[name];
        MainFileStatus status(MainState s, {String? sha, String? detail}) => MainFileStatus(
            path: path, ownerDir: dir, name: name, state: s, latest: latest, fileSha: sha, detail: detail);

        try {
          if (existing == null) {
            final placeholder = placeholders.contains(_join(dir, '.$name.icloud'));
            if (behind || placeholder) {
              report.mains.add(status(MainState.pending));
              continue;
            }
            await _write(folder, path, latest);
            report.mains.add(status(MainState.written, sha: latest.sha256));
          } else {
            final sha = await hashOf(existing);
            if (sha == latest.sha256) {
              report.mains.add(status(MainState.current, sha: sha));
            } else if (known.contains(sha)) {
              if (behind) {
                report.mains.add(status(MainState.pending, sha: sha));
                continue;
              }
              await _write(folder, path, latest);
              hashes.remove(path);
              report.mains.add(status(MainState.written, sha: latest.sha256));
            } else if (sha == prevSha) {
              report.mains.add(status(MainState.pending, sha: sha));
              continue;
            } else {
              report.mains.add(status(MainState.modified, sha: sha));
              continue;
            }
          }
          nextFiles[name] = {
            'sha256': latest.sha256,
            'history': latest.path.substring(dir.isEmpty ? 0 : dir.length + 1),
            'importedAt': latest.importedAt.toUtc().toIso8601String(),
          };
        } catch (e) {
          report.mains.add(status(MainState.failed, detail: '$e'));
        }
      }

      // Copias de conflicto del principal: fuera si su contenido es conocido.
      for (final MapEntry(key: fileName, value: e) in files.entries) {
        final owner = names.keys.followedBy(prevFiles.keys).where((n) => ArcaLayout.isConflictOf(fileName, n)).firstOrNull;
        if (owner == null) continue;
        try {
          if (known.contains(await hashOf(e))) {
            await folder.delete(e.path);
            hashes.remove(e.path);
            report.conflictsCleaned++;
            claimed.add(e.path);
          }
        } catch (_) {
          // Se reintenta en el próximo reindexado.
        }
      }

      if (names.isNotEmpty && !_sameFiles(prevFiles, nextFiles)) {
        try {
          await folder.writeReplace(ArcaLayout.latestPath(dir), encodeLatest(nextFiles));
        } catch (_) {
          // Derivado: se regenera en el próximo reindexado.
        }
      }
    }

    final conflictPaths = {for (final c in listing.conflicts) c.path};
    for (final e in listing.loose) {
      if (!claimed.contains(e.path) && !conflictPaths.contains(e.path)) report.loose.add(e);
    }
    // Copias de conflicto del principal con contenido desconocido: se ofrecen
    // para adoptar en vez de ignorarlas en silencio.
    for (final e in listing.conflicts) {
      if (claimed.contains(e.path)) continue;
      final dir = _dirOf(e.path);
      final name = e.path.split('/').last;
      final mains = {...?groups[dir]?.keys, ...?(latestIndexes[dir]?['files'] as Map<String, Object?>?)?.keys};
      if (mains.any((m) => ArcaLayout.isConflictOf(name, m))) report.loose.add(e);
    }
    report.loose.sort((a, b) => a.path.compareTo(b.path));
    return report;
  }

  static Future<void> _write(ArcaFolder folder, String path, HistoryEntry latest) async {
    final bytes = await folder.readVerified(latest.path, latest.sha256);
    await folder.writeReplace(path, bytes);
    // Verificación: lo escrito debe coincidir con la copia del historial.
    if (ArcaFolder.sha256Of(await folder.read(path)) != latest.sha256) {
      throw ArcaFileCorruptException(path, 'el archivo principal escrito no coincide con el historial');
    }
  }

  static Uint8List encodeLatest(Map<String, Object?> files) {
    final sorted = {for (final k in files.keys.toList()..sort()) k: files[k]};
    final json = const JsonEncoder.withIndent('  ').convert({
      'schema': ArcaLayout.latestSchema,
      'schemaVersion': 1,
      'files': sorted,
    });
    return Uint8List.fromList(utf8.encode('$json\n'));
  }

  static Future<Map<String, Object?>> _readLatest(ArcaFolder folder, String rel) async {
    try {
      final raw = jsonDecode(utf8.decode(await folder.read(rel)));
      if (raw is Map<String, Object?> && raw['schema'] == ArcaLayout.latestSchema && raw['files'] is Map<String, Object?>) {
        return raw;
      }
    } catch (_) {}
    // Ilegible: se regenera desde el historial.
    return const {};
  }

  static bool _sameFiles(Map<String, Object?> a, Map<String, Object?> b) => jsonEncode(_sortDeep(a)) == jsonEncode(_sortDeep(b));

  static Object? _sortDeep(Object? v) => v is Map
      ? {for (final k in (v.keys.map((e) => '$e').toList()..sort())) k: _sortDeep(v[k])}
      : v;

  static String _dirOf(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? '' : path.substring(0, i);
  }

  static String _join(String dir, String name) => dir.isEmpty ? name : '$dir/$name';
}
