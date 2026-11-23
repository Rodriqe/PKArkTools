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

/// Cada cuánto se reindexa una carpeta de red mientras la app está en primer
/// plano (FSEvents no ve los cambios que otros equipos hacen en un recurso SMB).
final networkPollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 60));

/// `true` cuando hay que preguntar (una sola vez, tras elegir la carpeta en el
/// primer arranque) si se crean las carpetas de los juegos.
final gameFoldersPromptProvider = NotifierProvider<GameFoldersPrompt, bool>(GameFoldersPrompt.new);

class GameFoldersPrompt extends Notifier<bool> {
  /// Preferencia local: ya se preguntó (la respuesta, sea cual sea, no se
  /// vuelve a pedir; queda en Ajustes → Crear carpetas de juegos).
  static const askedKey = 'gameFoldersAsked';

  @override
  bool build() => false;

  Future<void> request() async {
    final repo = ref.read(arcaRepositoryProvider);
    if (await repo.getSetting(askedKey) == '1') return;
    state = true;
  }

  Future<void> answered() async {
    state = false;
    await ref.read(arcaRepositoryProvider).setSetting(askedKey, '1');
  }
}

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
  Timer? _inboxRetry;
  Timer? _poll;
  bool _foreground = true;

  /// Reindexados periódicos hechos en la carpeta de red (diagnóstico y pruebas).
  int networkPolls = 0;

  /// `true` si la carpeta actual se vigila sondeando (carpeta de red).
  bool get polling => _poll != null;

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
    await ref.read(gameFoldersPromptProvider.notifier).request();
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

  /// Estado «sin acceso» para [e]: si es un recurso de red no disponible se
  /// recuerda en la ubicación (pantalla «Carpeta de red no disponible»).
  static SetupAccessLost lostFor(ArcaLocation loc, FolderAccessLostException e) => SetupAccessLost(
        e is NetworkFolderUnavailableException && !loc.network
            ? ArcaLocation(loc.kind, value: loc.value, label: loc.label, network: true, volume: loc.volume)
            : loc,
        e.message,
      );

  /// La app vuelve a primer plano: reindexa (o reintenta abrir una carpeta de
  /// red que no estaba disponible) y reanuda el sondeo.
  Future<void> appResumed() async {
    _foreground = true;
    final s = state;
    if (s is SetupAccessLost && s.location.network) {
      await retry();
    } else {
      await reindex();
    }
    if (state is SetupReady && _repo.hasFolder && _repo.folder.fs.isNetwork) _schedulePoll();
  }

  /// La app pasa a segundo plano: se deja de sondear la red.
  void appPaused() {
    _foreground = false;
    _poll?.cancel();
    _poll = null;
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
      state = lostFor(loc, e);
      return false;
    }
  }

  /// Reindexa; si la carpeta ya no es accesible pasa a [SetupAccessLost].
  Future<ReindexReport?> reindex() async {
    final current = state;
    if (current is! SetupReady || !_repo.hasFolder) return null;
    try {
      final fs = _repo.folder.fs;
      // En red no se escribe una sonda en cada sondeo: el listado ya comprueba
      // que el recurso está montado y que la carpeta existe.
      if (!fs.isNetwork && !await fs.checkAccess()) {
        throw FolderAccessLostException('La carpeta ${_repo.folder.label} no está disponible');
      }
      final r = await _repo.reindex();
      // Saves de la bandeja aún copiándose: se recogen en un momento.
      _inboxRetry?.cancel();
      if (r.inboxPending > 0) _inboxRetry = Timer(_repo.inboxSettle + const Duration(seconds: 1), () => unawaited(reindex()));
      final native = _repo.folder.fs.nativePath;
      if (native != null && r.placeholders.isNotEmpty) {
        unawaited(PlatformFolderAccess.requestDownloads(p.join(native, _repo.folder.prefix), r.placeholders));
      }
      return r;
    } on FolderAccessLostException catch (e) {
      _stopWatching();
      state = lostFor(current.location, e);
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
    if (fs.isNetwork) {
      // FSEvents/inotify no ven lo que otros equipos escriben en un recurso
      // SMB/NFS: reindexado ligero periódico (solo lista y lee lo nuevo).
      _schedulePoll();
      return;
    }
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

  /// Programa el siguiente sondeo de la carpeta de red. Nunca se solapan: el
  /// siguiente se programa al terminar el anterior, y si un reindexado tarda
  /// mucho (red lenta, Arca grande) se espacian para no saturar la red.
  void _schedulePoll([Duration? after]) {
    _poll?.cancel();
    if (!_foreground) {
      _poll = null;
      return;
    }
    final interval = ref.read(networkPollIntervalProvider);
    _poll = Timer(after ?? interval, () async {
      if (!_foreground || state is! SetupReady) return;
      final sw = Stopwatch()..start();
      networkPolls++;
      final r = await reindex();
      if (r == null || state is! SetupReady || !_foreground) return;
      final took = sw.elapsed * 3;
      _schedulePoll(took > interval ? took : interval);
    });
  }

  void _stopWatching() {
    _poll?.cancel();
    _poll = null;
    _debounce?.cancel();
    _inboxRetry?.cancel();
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
    return ArcaBootstrap(repo, ArcaController.lostFor(location, e), legacyPresent ? legacy : null);
  } on Exception catch (e) {
    return ArcaBootstrap(repo, SetupAccessLost(location, '$e'), legacyPresent ? legacy : null);
  }
}
