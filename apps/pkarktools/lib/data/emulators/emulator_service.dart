import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:pkcore/pkcore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../arca_repository.dart';
import '../arca_session.dart' show arcaRepositoryProvider;
import '../file_sources.dart';
import '../folder/folder_fs.dart';
import 'emulators.dart';

/// Resultado de respaldar la carpeta de un emulador en el Arca.
class EmulatorBackupResult {
  int added = 0;
  int duplicates = 0;

  /// Archivos que no son saves reconocibles (o demasiado grandes).
  int skipped = 0;
  final List<String> failures = [];

  int get total => added + duplicates;
}

/// Copia al Arca los saves que encuentre en [fs]. Nunca modifica la carpeta
/// del emulador: solo lee. Los saves que el Arca ya tiene (mismo SHA-256)
/// cuentan como duplicados y no se vuelven a guardar.
Future<EmulatorBackupResult> backupEmulatorFolder(
  FolderFs fs,
  ArcaRepository repo, {
  int maxFiles = 600,
  void Function(int done)? onProgress,
}) async {
  final r = EmulatorBackupResult();
  final entries = await fs.list('');
  var done = 0;
  for (final e in entries.take(maxFiles)) {
    final name = p.posix.basename(e.path);
    if (name.startsWith('.') || FileSources.isBlocked(name) || !SaveDetector.isPlausibleSize(e.size)) {
      r.skipped++;
      continue;
    }
    try {
      final bytes = await fs.read(e.path);
      final out = await repo.importBytes(bytes, fileName: name, origin: ImportOrigin.folder);
      switch (out) {
        case ImportAdded():
          r.added++;
        case ImportDuplicate():
          r.duplicates++;
        case ImportFailed():
          r.skipped++;
      }
    } catch (err) {
      r.failures.add('${e.path}: $err');
    }
    onProgress?.call(++done);
  }
  return r;
}

/// Carpetas de emuladores vinculadas (guardadas en el índice local).
class EmulatorLinksNotifier extends Notifier<List<EmulatorLink>> {
  static const settingKey = 'emulatorLinks';

  @override
  List<EmulatorLink> build() {
    _load();
    return const [];
  }

  ArcaRepository get _repo => ref.read(arcaRepositoryProvider);

  Future<void> _load() async {
    try {
      state = EmulatorLink.decodeList(await _repo.getSetting(settingKey));
    } catch (_) {}
  }

  Future<void> _save(List<EmulatorLink> links) async {
    state = links;
    await _repo.setSetting(settingKey, EmulatorLink.encodeList(links));
  }

  Future<void> add(EmulatorLink link) => _save([
    for (final l in state)
      if (!(l.emulatorId == link.emulatorId && l.location.value == link.location.value)) l,
    link,
  ]);

  Future<void> remove(EmulatorLink link) => _save([
    for (final l in state)
      if (!identical(l, link)) l,
  ]);

  Future<void> markBackup(EmulatorLink link, DateTime t) =>
      _save([for (final l in state) identical(l, link) ? l.withBackup(t) : l]);
}

final emulatorLinksProvider = NotifierProvider<EmulatorLinksNotifier, List<EmulatorLink>>(EmulatorLinksNotifier.new);

/// Abre un emulador instalado: intent en Android, esquema de URL en iOS. En
/// el resto de sistemas no hay forma fiable y el botón no se muestra.
class EmulatorLauncher {
  const EmulatorLauncher();

  static const _ch = MethodChannel('dev.pkarktools/emulators');

  static TargetPlatform? get _platform {
    if (kIsWeb) return null;
    if (io.Platform.isAndroid) return TargetPlatform.android;
    if (io.Platform.isIOS) return TargetPlatform.iOS;
    return null;
  }

  /// Paquete instalado (Android) o esquema (iOS) con el que abrir [e], o null.
  Future<String?> target(Emulator e) async {
    final platform = _platform;
    if (platform == null || !e.canLaunchOn(platform)) return null;
    if (platform == TargetPlatform.iOS) {
      // Requiere el esquema en LSApplicationQueriesSchemes (Info.plist).
      try {
        return await canLaunchUrl(Uri.parse('${e.iosScheme}://')) ? e.iosScheme : null;
      } catch (_) {
        return null;
      }
    }
    try {
      return await _ch.invokeMethod<String>('installed', {'packages': e.androidPackages});
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> launch(Emulator e) async {
    final t = await target(e);
    if (t == null) return false;
    if (_platform == TargetPlatform.iOS) {
      return launchUrl(Uri.parse('$t://'), mode: LaunchMode.externalApplication);
    }
    try {
      return await _ch.invokeMethod<bool>('launch', {'package': t}) ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Emuladores de la consola de [game] instalados en este dispositivo.
  Future<List<Emulator>> installedFor(GameVersion game) async {
    final out = <Emulator>[];
    for (final e in Emulators.all) {
      if (!e.consoles.contains(game.platform)) continue;
      if (await target(e) != null) out.add(e);
    }
    return out;
  }
}

final emulatorLauncherProvider = Provider<EmulatorLauncher>((ref) => const EmulatorLauncher());
