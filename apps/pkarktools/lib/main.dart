import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/arca_session.dart';
import 'data/folder/folder_access.dart';
import 'data/update/update_notice.dart';
import 'providers.dart';

/// Ruta inicial opcional (útil para capturas): `--dart-define=INITIAL_ROUTE=/ajustes`.
const _initialRoute = String.fromEnvironment('INITIAL_ROUTE', defaultValue: '/arca');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(['PKHeX.Core'],
        'PKArkTools porta lógica de PKHeX.Core (https://github.com/kwsch/PKHeX), '
        '© Kaphotics y colaboradores, bajo GPL-3.0.');
    yield const LicenseEntryWithLineBreaks(['PokeAPI'],
        'Datos de especies de PokeAPI (https://github.com/PokeAPI/pokeapi), licencia BSD-3-Clause.');
    yield const LicenseEntryWithLineBreaks(['Manrope', 'Bricolage Grotesque', 'Noto Sans Symbols', 'Noto Sans Symbols 2'],
        'Fuentes bajo SIL Open Font License 1.1 (ver assets/fonts).');
  });
  const access = PlatformFolderAccess();
  final boot = await bootstrapArca(
    indexDb: await openIndexDatabase(),
    access: access,
    legacy: await legacyArcaLocation(),
  );
  final container = ProviderContainer(overrides: [
    arcaRepositoryProvider.overrideWithValue(boot.repo),
    initialArcaSetupProvider.overrideWithValue(boot.setup),
    legacyArcaProvider.overrideWithValue(boot.legacy),
    folderAccessProvider.overrideWithValue(access),
  ]);
  runApp(UncontrolledProviderScope(
    container: container,
    child: const PKArkToolsApp(initialLocation: _initialRoute),
  ));
  // Buscar actualizaciones (como mucho una vez al día; falla en silencio).
  unawaited(container.read(updateNoticeProvider.notifier).startup());
  // Reindexado incremental al abrir y vigilancia de la carpeta en escritorio.
  if (boot.setup is SetupReady) {
    final controller = container.read(arcaSetupProvider.notifier);
    controller.startWatching();
    unawaited(controller.reindex());
  }
}
