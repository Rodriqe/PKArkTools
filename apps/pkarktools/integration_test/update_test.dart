import 'dart:async';
import 'dart:io' as io;

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';
import 'package:pkarktools/data/update/app_update.dart';
import 'package:pkarktools/data/update/update_notice.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/ui/settings/update_section.dart';

/// Actualizar desde la app en Android, contra el release REAL publicado en
/// GitHub, simulando que está instalada la 0.1.0 (emulador headless):
///
///   flutter drive -d emulator-5554 --driver test_driver/screenshot_driver.dart \
///     --target integration_test/update_test.dart --dart-define=SHOTS=android/v2 \
///     [--dart-define=UPDATE_STEP=permission]
///
/// * `permission` (sin «Instalar apps desconocidas»): explica y ofrece abrir
///   el ajuste, sin descargar nada.
/// * por defecto (con el permiso, `appops set … REQUEST_INSTALL_PACKAGES
///   allow`): detecta la versión nueva, descarga el APK real, lee su firma y
///   la de la app instalada con PackageManager y, como la app de prueba está
///   firmada con la clave debug, **bloquea** la instalación con el mensaje.
///   Después, el camino feliz con un lector de firmas falso que dice que
///   coinciden: llega al instalador (también falso, para no instalar nada).
const _prefix = String.fromEnvironment('SHOTS', defaultValue: 'android/v2');
const _step = String.fromEnvironment('UPDATE_STEP');

/// El actualizador real, anotando lo que pasa (y, con [fakeMatch], fingiendo
/// que la firma del APK coincide y sin instalar de verdad).
class _Spy extends AppUpdater {
  _Spy({required super.store, this.fakeMatch = false}) : super(platform: UpdatePlatform.android);
  final bool fakeMatch;
  final installs = <String>[], deleted = <String>[];
  final hold = Completer<void>();
  ApkSignature? mine, theirs;

  @override
  Future<ApkSignature?> installedSignature() async => mine = await super.installedSignature();

  @override
  Future<ApkSignature?> apkSignature(io.File apk) async {
    theirs = await super.apkSignature(apk);
    return fakeMatch ? await super.installedSignature() : theirs;
  }

  @override
  Future<void> install(io.File apk) async {
    installs.add(apk.path);
    if (!fakeMatch) return super.install(apk);
    // El usuario «está» en la ventana del instalador hasta que el test siga.
    await hold.future;
  }

  @override
  Future<void> deleteDownload(io.File f) async {
    deleted.add(f.path);
    await super.deleteDownload(f);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('actualizar contra el release real (Android)', skip: !io.Platform.isAndroid, (tester) async {
    const locale = Locale('en', 'US');
    tester.platformDispatcher.localesTestValue = [locale];
    tester.platformDispatcher.localeTestValue = locale;
    final l10n = lookupAppLocalizations(locale);
    AppVersion.current = const AppVersion(0, 1, 0);

    final db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final repo = ArcaRepository(db, ArcaFolder(MemoryFolderFs(label: 'PKArkTools')), inboxSettle: Duration.zero);
    final store = RepositoryUpdateStore(() => repo);

    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> until(Finder f, {int seconds = 300}) async {
      for (var i = 0; i < seconds * 2 && f.evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(f, findsWidgets);
    }

    Future<ProviderContainer> open(AppUpdater u) async {
      await tester.pumpWidget(const SizedBox());
      await settle(3);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [arcaRepositoryProvider.overrideWithValue(repo), appUpdaterProvider.overrideWithValue(u)],
        child: const PKArkToolsApp(initialLocation: '/ajustes'),
      ));
      await settle(10);
      return ProviderScope.containerOf(tester.element(find.byType(PKArkToolsApp)));
    }

    Future<void> shot(String name) async {
      await settle(8);
      await binding.takeScreenshot('${_prefix}_$name');
    }

    await binding.convertFlutterSurfaceToImage();
    final real = _Spy(store: store);
    var c = await open(real);
    // Chequeo al abrir: consulta de verdad api.github.com (sin token).
    await tester.runAsync(() => c.read(updateNoticeProvider.notifier).startup());
    await settle();
    final release = c.read(updateNoticeProvider).available;
    expect(release, isNotNull, reason: 'el release publicado es más nuevo que 0.1.0');
    final title = l10n.updateBannerTitle(release!.version.toString());
    debugPrint('release: ${release.tag} ${release.asset?.name} ${release.asset?.size} B');
    expect(find.text(title), findsWidgets);
    expect(find.byType(Badge), findsOneWidget);
    expect(await tester.runAsync(() => store.read(AppUpdater.kEtag)), isNotEmpty);
    if (_step != 'permission') await shot('47_update_notice');

    await tester.tap(find.text(title).first);
    await settle();
    expect(find.byType(UpdateSheet), findsOneWidget);
    if (_step != 'permission') await shot('48_update_sheet');

    final allowed = await tester.runAsync(real.canRequestInstall);
    debugPrint('canRequestPackageInstalls: $allowed');
    if (_step == 'permission') {
      expect(allowed, isFalse, reason: 'ejecutar con «Instalar apps desconocidas» sin permitir');
      await tester.tap(find.text(l10n.updateNow));
      await settle();
      expect(find.text(l10n.updatePermissionTitle), findsOneWidget);
      await shot('49_update_permission');
      await tester.tap(find.text(l10n.updateCancel));
      await settle();
      return;
    }
    expect(allowed, isTrue, reason: 'appops set dev.pkarktools.app REQUEST_INSTALL_PACKAGES allow');

    // Firma distinta (debug frente a la del release): se bloquea.
    await tester.tap(find.text(l10n.updateNow));
    await tester.pump();
    await until(find.byType(LinearProgressIndicator), seconds: 60);
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    await tester.pump();
    await binding.takeScreenshot('${_prefix}_50_update_downloading');
    await until(find.text(l10n.updateErrorSignature));
    debugPrint('instalada: ${real.mine?.package} ${real.mine?.certificates}');
    debugPrint('APK:       ${real.theirs?.package} ${real.theirs?.certificates}');
    expect(real.theirs?.package, real.mine?.package);
    expect(real.theirs!.certificates.intersection(real.mine!.certificates), isEmpty);
    expect(real.installs, isEmpty, reason: 'no se entrega al instalador');
    expect(real.deleted, hasLength(1));
    expect(io.File(real.deleted.single).existsSync(), isFalse, reason: 'el APK se borra');
    await shot('51_update_signature_blocked');

    // Camino feliz con un lector de firmas falso: llega al instalador.
    final happy = _Spy(store: store, fakeMatch: true);
    c = await open(happy);
    await tester.runAsync(() => c.read(updateNoticeProvider.notifier).startup());
    await settle();
    await tester.tap(find.text(title).first);
    await settle();
    await tester.tap(find.text(l10n.updateNow));
    await tester.pump();
    await until(find.textContaining(l10n.updateInstalling.substring(0, 20)));
    expect(happy.installs, hasLength(1));
    await shot('52_update_installing');
    happy.hold.complete();
    await settle();
    expect(happy.deleted, hasLength(1));
    expect(io.File(happy.installs.single).existsSync(), isFalse);
    await db.close();
  });
}
