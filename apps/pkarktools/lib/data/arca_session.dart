import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'arca_repository.dart';
import 'blob_store.dart';
import 'db/arca_database.dart';
import 'folder/arca_folder.dart';
import 'folder/arca_migration.dart';
import 'folder/folder_access.dart';
import 'folder/folder_fs.dart';

/// Estado de la carpeta del Arca en este dispositivo.
sealed class ArcaSetup {
  const ArcaSetup();
}

/// Carpeta configurada y accesible.
class SetupReady extends ArcaSetup {
  const SetupReady(this.location);
  final ArcaLocation location;
}

/// Primer arranque: hay que elegir carpeta. [legacyCount] = copias del Arca
/// interna anterior que se migrarán.
class SetupNeeded extends ArcaSetup {
  const SetupNeeded({this.legacyCount = 0});
  final int legacyCount;
}

/// La carpeta guardada ya no es accesible.
class SetupAccessLost extends ArcaSetup {
  const SetupAccessLost(this.location, this.message);
  final ArcaLocation location;
  final String message;
}

/// Arca interna de versiones anteriores (SQLite + blobs en Documentos).
class LegacyArca {
  LegacyArca(this.dir);

  /// `<Documentos>/PKArkTools/arca`
  final Directory dir;

  File get dbFile => File(p.join(dir.path, 'arca.sqlite'));

  Future<bool> exists() => dbFile.exists();

  Future<T> _withDb<T>(Future<T> Function(ArcaDatabase db) body) async {
    final db = ArcaDatabase(DatabaseConnection(NativeDatabase(dbFile)));
    try {
      return await body(db);
    } finally {
      await db.close();
    }
  }

  Future<int> count() async {
    if (!await exists()) return 0;
    try {
      return await _withDb((db) async => (await db.select(db.snapshots).get()).length);
    } catch (_) {
      return 0;
    }
  }

  Future<MigrationResult> migrateTo(ArcaFolder dest, {String? deviceId, String? deviceName, MigrationProgress? onProgress}) =>
      _withDb((db) => ArcaMigration.fromLegacy(
            legacyDb: db,
            blobs: BlobStore(Directory(p.join(dir.path, 'blobs'))),
            dest: dest,
            deviceId: deviceId,
            deviceName: deviceName,
            onProgress: onProgress,
          ));

  /// Tras migrar sin fallos, aparta el Arca antigua a una carpeta oculta (no
  /// se borra: queda como copia de seguridad y el reindexado la ignora).
  Future<void> retire() async {
    var target = Directory(p.join(dir.parent.path, '.arca-anterior'));
    var i = 2;
    while (await target.exists()) {
      target = Directory(p.join(dir.parent.path, '.arca-anterior-${i++}'));
    }
    await dir.rename(target.path);
  }
}

/// Valor inicial del estado (lo fija `main` tras abrir el índice).
final initialArcaSetupProvider = Provider<ArcaSetup>((ref) => const SetupReady(ArcaLocation(LocationKind.appLocal)));

final folderAccessProvider = Provider<FolderAccess>((ref) => const PlatformFolderAccess());

/// Arca interna antigua pendiente de migrar (null si no hay).
final legacyArcaProvider = Provider<LegacyArca?>((ref) => null);

/// Repositorio del Arca. Se sobreescribe en `main` (y en tests).
final arcaRepositoryProvider = Provider<ArcaRepository>((ref) {
  throw UnimplementedError('arcaRepositoryProvider debe sobreescribirse en main()');
});

final arcaSetupProvider = NotifierProvider<ArcaController, ArcaSetup>(ArcaController.new);

/// Último informe de reindexado.
final reindexReportProvider = StreamProvider<ReindexReport?>((ref) async* {
  final repo = ref.watch(arcaRepositoryProvider);
  yield repo.lastReport;
  yield* repo.reports;
});

/// Orquesta la carpeta del Arca: primer arranque, migración, cambio de
/// carpeta, reindexado y vigilancia de cambios.
class ArcaController extends Notifier<ArcaSetup> {
  static const locationKey = 'arcaLocation';

  StreamSubscription<FileSystemEvent>? _watch;
  Timer? _debounce;

  @override
  ArcaSetup build() {
    ref.onDispose(_stopWatching);
    return ref.read(initialArcaSetupProvider);
  }

  ArcaRepository get _repo => ref.read(arcaRepositoryProvider);

  /// Primer arranque: usa [opened] como carpeta del Arca, migrando el Arca
  /// interna si la hay. Devuelve el resultado de la migración (o null).
  Future<MigrationResult?> setUp(OpenedFolder opened, {MigrationProgress? onProgress}) async {
    final folder = await ArcaFolder.open(opened.fs);
    MigrationResult? result;
    final legacy = ref.read(legacyArcaProvider);
    if (legacy != null && await legacy.exists()) {
      final dev = await _repo.device();
      result = await legacy.migrateTo(folder, deviceId: dev.id, deviceName: dev.name, onProgress: onProgress);
      if (result.ok) await legacy.retire();
    }
    await _activate(opened.location, folder);
    return result;
  }

  /// Cambia de carpeta copiando (o moviendo) todas las copias con verificación.
  Future<MigrationResult> changeFolder(OpenedFolder opened, {required bool move, MigrationProgress? onProgress}) async {
    final dest = await ArcaFolder.open(opened.fs);
    final result = await ArcaMigration.copyFolder(from: _repo.folder, to: dest, move: move, onProgress: onProgress);
    await _activate(opened.location, dest);
    return result;
  }

  Future<void> _activate(ArcaLocation location, ArcaFolder folder) async {
    await _repo.setSetting(locationKey, encodeLocation(location));
    await _repo.attachFolder(folder);
    state = SetupReady(location);
    _startWatching(folder.fs);
  }

  /// Reintenta abrir la carpeta guardada (tras perder el acceso).
  Future<bool> retry() async {
    final loc = switch (state) {
      SetupAccessLost(:final location) => location,
      SetupReady(:final location) => location,
      SetupNeeded() => null,
    };
    if (loc == null) return false;
    try {
      final opened = await ref.read(folderAccessProvider).open(loc);
      final folder = await ArcaFolder.open(opened.fs);
      await _repo.setSetting(locationKey, encodeLocation(opened.location));
      // Misma carpeta: se conserva el índice y se pone al día.
      _repo.replaceFolder(folder);
      await _repo.reindex();
      state = SetupReady(opened.location);
      _startWatching(folder.fs);
      return true;
    } on FolderAccessLostException catch (e) {
      state = SetupAccessLost(loc, e.message);
      return false;
    }
  }

  /// Reindexa; si la carpeta ya no es accesible pasa a [SetupAccessLost].
  Future<ReindexReport?> reindex() async {
    final current = state;
    if (current is! SetupReady || !_repo.hasFolder) return null;
    try {
      if (!await _repo.folder.fs.checkAccess()) {
        throw FolderAccessLostException('La carpeta ${_repo.folder.label} no está disponible');
      }
      final r = await _repo.reindex();
      final native = _repo.folder.fs.nativePath;
      if (native != null && r.placeholders.isNotEmpty) {
        unawaited(PlatformFolderAccess.requestDownloads(p.join(native, _repo.folder.prefix), r.placeholders));
      }
      return r;
    } on FolderAccessLostException catch (e) {
      _stopWatching();
      state = SetupAccessLost(current.location, e.message);
      return null;
    } on FileSystemException catch (e) {
      _stopWatching();
      state = SetupAccessLost(current.location, e.message);
      return null;
    }
  }

  /// Vigila la carpeta en escritorio para reindexar al cambiar (otro
  /// dispositivo sincronizó copias nuevas).
  void _startWatching(FolderFs fs) {
    _stopWatching();
    final path = fs.nativePath;
    if (path == null || kIsWeb || !(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) return;
    try {
      _watch = Directory(path).watch(recursive: !Platform.isLinux).listen((e) {
        final name = p.basename(e.path);
        if (name.endsWith('.tmp') || name.startsWith('.pkarktools-acceso')) return;
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 1500), () => unawaited(reindex()));
      }, onError: (_) {});
    } catch (_) {
      // Sin watcher: quedan el reindexado al abrir/volver y el botón manual.
    }
  }

  void _stopWatching() {
    _debounce?.cancel();
    unawaited(_watch?.cancel());
    _watch = null;
  }

  /// Llamado al arrancar con la carpeta ya abierta.
  void startWatching() {
    if (_repo.hasFolder) _startWatching(_repo.folder.fs);
  }
}

/// Resultado de preparar el Arca al arrancar.
class ArcaBootstrap {
  const ArcaBootstrap(this.repo, this.setup, this.legacy);
  final ArcaRepository repo;
  final ArcaSetup setup;
  final LegacyArca? legacy;
}

/// Abre el índice local y, si ya hay carpeta, recupera el acceso.
Future<ArcaBootstrap> bootstrapArca({
  required ArcaDatabase indexDb,
  required FolderAccess access,
  LegacyArca? legacy,
}) async {
  final repo = ArcaRepository(indexDb, null);
  final location = ArcaLocation.fromJson(await repo.getJsonSetting(ArcaController.locationKey));
  final legacyPresent = legacy != null && await legacy.exists();
  if (location == null) {
    return ArcaBootstrap(repo, SetupNeeded(legacyCount: legacyPresent ? await legacy.count() : 0), legacyPresent ? legacy : null);
  }
  try {
    final opened = await access.open(location);
    if (opened.location.value != location.value) {
      await repo.setSetting(ArcaController.locationKey, encodeLocation(opened.location));
    }
    final folder = await ArcaFolder.open(opened.fs);
    repo.replaceFolder(folder);
    return ArcaBootstrap(repo, SetupReady(opened.location), legacyPresent ? legacy : null);
  } on FolderAccessLostException catch (e) {
    return ArcaBootstrap(repo, SetupAccessLost(location, e.message), legacyPresent ? legacy : null);
  } on Exception catch (e) {
    return ArcaBootstrap(repo, SetupAccessLost(location, '$e'), legacyPresent ? legacy : null);
  }
}
