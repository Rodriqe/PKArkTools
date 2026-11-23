import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'folder_fs.dart';
import 'volume_info.dart';

/// Códigos `errno` (o de Windows) de fallos pasajeros en volúmenes de red.
abstract final class TransientErrors {
  static bool get _linux => Platform.isLinux || Platform.isAndroid;

  static int get eagain => _linux ? 11 : 35;
  static int get etimedout => _linux ? 110 : 60;
  static int get enoent => 2;
  static int get estale => _linux ? 116 : 70;
  static int get enetdown => _linux ? 100 : 50;
  static int get ehostdown => _linux ? 112 : 64;

  /// Errores de red: tras agotar los reintentos la carpeta se da por no
  /// disponible (no por vacía ni dañada).
  static Set<int> get network => Platform.isWindows
      ? const {51, 53, 59, 64, 67, 121, 1231}
      : _linux
          ? const {100, 101, 102, 103, 104, 110, 112, 113, 116}
          : const {50, 51, 52, 53, 54, 60, 64, 65, 70};

  /// Se reintentan: EINTR, EIO, EBUSY, EAGAIN y los de red (y los de bloqueo
  /// y red de Windows).
  static Set<int> get retryable => {
        ...network,
        if (Platform.isWindows) ...const {32, 33} else ...{4, 5, 16, eagain},
      };

  static int? codeOf(Object e) => e is FileSystemException ? e.osError?.errorCode : null;
}

/// Envuelve un [FolderFs] para una carpeta de red:
///
/// * reintenta con espera creciente los fallos pasajeros (EAGAIN,
///   ETIMEDOUT, ESTALE, red caída un momento…) y un ENOENT momentáneo al
///   leer (SMB tarda a veces en mostrar un archivo recién renombrado);
/// * pone un tiempo máximo a cada operación para que nada se quede colgado
///   esperando a un servidor que no responde;
/// * convierte los fallos de red persistentes en
///   [NetworkFolderUnavailableException] («carpeta de red no disponible»).
class ResilientFolderFs implements FolderFs {
  ResilientFolderFs(
    this.inner, {
    this.retries = 3,
    this.backoff = const Duration(milliseconds: 250),
    this.timeout = const Duration(seconds: 30),
    this.listTimeout = const Duration(minutes: 3),
  });

  final FolderFs inner;
  final int retries;
  final Duration backoff;
  final Duration timeout;
  final Duration listTimeout;

  /// Reintentos hechos (para pruebas y diagnóstico).
  int retried = 0;

  @override
  String get label => inner.label;

  @override
  String? get nativePath => inner.nativePath;

  @override
  VolumeInfo? get volume => inner.volume;

  Future<T> _run<T>(String what, Future<T> Function() op, {bool retryNotFound = false, Duration? limit}) async {
    var attempt = 0;
    while (true) {
      try {
        return await op().timeout(limit ?? timeout);
      } on TimeoutException {
        throw NetworkFolderUnavailableException('La carpeta de red ${inner.label} no responde ($what)');
      } on FileSystemException catch (e) {
        final code = TransientErrors.codeOf(e);
        final transient = code != null &&
            (TransientErrors.retryable.contains(code) || (retryNotFound && code == TransientErrors.enoent));
        if (!transient || attempt >= retries) {
          if (code != null && TransientErrors.network.contains(code)) {
            throw NetworkFolderUnavailableException('La carpeta de red ${inner.label} no está disponible: ${e.message}');
          }
          rethrow;
        }
        attempt++;
        retried++;
        await Future<void>.delayed(backoff * (1 << (attempt - 1)));
      }
    }
  }

  @override
  Future<List<FsEntry>> list(String dir) => _run('listar', () => inner.list(dir), limit: listTimeout);

  @override
  Future<Uint8List> read(String path) => _run('leer $path', () => inner.read(path), retryNotFound: true);

  @override
  Future<bool> exists(String path) => _run('comprobar $path', () => inner.exists(path));

  @override
  Future<void> writeNew(String path, Uint8List bytes) => _run('escribir $path', () => inner.writeNew(path, bytes));

  @override
  Future<void> writeReplace(String path, Uint8List bytes) =>
      _run('escribir $path', () => inner.writeReplace(path, bytes));

  @override
  Future<void> delete(String path) => _run('borrar $path', () => inner.delete(path));

  @override
  Future<bool> checkAccess() async {
    try {
      return await inner.checkAccess().timeout(timeout);
    } on TimeoutException {
      return false;
    }
  }
}

/// Envuelve [fs] con [ResilientFolderFs] si está en un volumen de red.
FolderFs forVolume(FolderFs fs) => fs.isNetwork && fs is! ResilientFolderFs ? ResilientFolderFs(fs) : fs;
