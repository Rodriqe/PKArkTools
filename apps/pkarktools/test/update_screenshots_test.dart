import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/app_version.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';
import 'package:pkarktools/data/update/app_update.dart';
import 'package:pkarktools/data/update/update_notice.dart';

import 'app_update_test.dart' show FakeUpdater, releaseJson;
import 'arca_folder_test.dart' show memoryDb;
import 'shots_i18n.dart';

/// Captura de ESCRITORIO de la hoja de actualización, offscreen (sin ventana):
///
///   flutter test test/update_screenshots_test.dart --dart-define=SHOTS_UPDATE=true
///
/// Escribe `docs/screenshots/v2/mac_46_update.png` (macOS: descargado y
/// guardado, con el paso manual).
const _enabled = bool.fromEnvironment('SHOTS_UPDATE');

void main() {
  testWidgets('captura de la actualización en escritorio', skip: !_enabled, (tester) async {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    for (final (family, file) in [
      ('Manrope', 'assets/fonts/Manrope.ttf'),
      ('Bricolage', 'assets/fonts/BricolageGrotesque.ttf'),
      ('NotoSansSymbols', 'assets/fonts/NotoSansSymbols-Subset.ttf'),
      ('NotoSansSymbols2', 'assets/fonts/NotoSansSymbols2-Subset.ttf'),
      if (flutterRoot != null) ('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'),
    ]) {
      final f = File(file);
      if (f.existsSync()) await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
    }
    tester.view.physicalSize = const Size(1440, 900) * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.localesTestValue = [shotsLocale];
    tester.platformDispatcher.localeTestValue = shotsLocale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    final db = memoryDb();
    final repo = ArcaRepository(db, ArcaFolder(MemoryFolderFs(label: 'PKArkTools')));
    final json = releaseJson('v0.1.4')
      ..['body'] = '## PKArkTools 0.1.4\n\nCheck for updates and install them from the app.\n\n### Added\n'
          '- **Check for updates** in Settings › About, at most once a day, with a discreet notice.\n'
          '- **Android**: the APK is downloaded, its signing certificate is checked and the system installer opens.\n'
          '- **macOS, Windows and Linux**: the release file is downloaded where you choose.';
    final u = FakeUpdater(UpdatePlatform.macos, json);
    AppVersion.current = const AppVersion(0, 1, 3);
    addTearDown(() => AppVersion.current = AppVersion.tryParse(kAppVersion)!);

    final boundary = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundary,
      child: ProviderScope(
        overrides: [arcaRepositoryProvider.overrideWithValue(repo), appUpdaterProvider.overrideWithValue(u)],
        child: const PKArkToolsApp(initialLocation: '/ajustes'),
      ),
    ));
    Future<void> settle([int n = 20]) async {
      for (var i = 0; i < n; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    final c = ProviderScope.containerOf(tester.element(find.byType(PKArkToolsApp)));
    await tester.runAsync(() => c.read(updateNoticeProvider.notifier).startup());
    await settle();
    await tester.tap(find.text(tr('PKArkTools 0.1.4 disponible', 'PKArkTools 0.1.4 available')).first);
    await settle();
    await tester.tap(find.text(tr('Descargar')));
    await tester.pump();
    u.finishDownload();
    await settle();

    final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = await tester.runAsync(() async {
      final image = await ro.toImage(pixelRatio: 2);
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    shotFile('v2/mac_46_update').writeAsBytesSync(png!.buffer.asUint8List());
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
}
