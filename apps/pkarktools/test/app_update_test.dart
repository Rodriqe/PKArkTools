import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pkarktools/app_version.dart';
import 'package:pkarktools/data/update/app_update.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/providers.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/settings/update_section.dart';

/// Forma real de `GET /repos/Rodriqe/PKArkTools/releases/latest` (v0.1.2).
Map<String, Object?> releaseJson(String tag, {int apkSize = 89080111, String host = 'https://github.com'}) => {
      'tag_name': tag,
      'draft': false,
      'prerelease': false,
      'html_url': 'https://github.com/Rodriqe/PKArkTools/releases/tag/$tag',
      'body': '### Added\n- Algo nuevo.',
      'assets': [
        for (final (name, size) in [
          ('PKArkTools-$tag-linux-x64.tar.gz', 15705677),
          ('PKArkTools-$tag-macos.zip', 29426111),
          ('PKArkTools-$tag-windows-x64-setup.exe', 14496338),
          ('PKArkTools-$tag-windows-x64.zip', 18094604),
          ('PKArkTools-$tag.apk', apkSize),
        ])
          {'name': name, 'size': size, 'browser_download_url': '$host/Rodriqe/PKArkTools/releases/download/$tag/$name'},
      ],
    };

/// Servidor local que responde con [handler].
Future<HttpServer> serve(FutureOr<void> Function(HttpRequest) handler) async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  s.listen((r) async {
    await handler(r);
    await r.response.close();
  });
  return s;
}

void main() {
  test('kAppVersion es la versión de pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final v = RegExp(r'^version:\s*([^+\s]+)', multiLine: true).firstMatch(pubspec)![1];
    expect(kAppVersion, v);
  });

  group('versiones', () {
    test('se leen los tags y se ordenan como semver', () {
      AppVersion v(String s) => AppVersion.tryParse(s)!;
      expect(v('v0.1.3'), const AppVersion(0, 1, 3));
      expect(v('1.2'), const AppVersion(1, 2, 0));
      expect(v('v0.1.10') > v('v0.1.9'), isTrue);
      expect(v('v0.2.0') > v('v0.1.99'), isTrue);
      expect(v('v0.2.0') > v('v0.2.0-beta.2'), isTrue);
      expect(v('v0.2.0-beta.10') > v('v0.2.0-beta.2'), isTrue);
      expect(v('v0.1.2') > v('0.1.2'), isFalse);
      expect(v('0.1.2+3'), v('0.1.2'));
      expect(AppVersion.tryParse('latest'), isNull);
      expect(AppVersion.current.toString(), kAppVersion);
    });

    test('cada plataforma toma su archivo del release', () {
      final json = releaseJson('v0.1.3');
      String? asset(UpdatePlatform pl) => ReleaseInfo.fromGitHub(json, pl)!.asset?.name;
      expect(asset(UpdatePlatform.android), 'PKArkTools-v0.1.3.apk');
      expect(asset(UpdatePlatform.macos), 'PKArkTools-v0.1.3-macos.zip');
      expect(asset(UpdatePlatform.windows), 'PKArkTools-v0.1.3-windows-x64-setup.exe');
      expect(asset(UpdatePlatform.linux), 'PKArkTools-v0.1.3-linux-x64.tar.gz');
      final r = ReleaseInfo.fromGitHub(json, UpdatePlatform.android)!;
      expect(r.asset!.size, 89080111);
      expect(r.page.toString(), 'https://github.com/Rodriqe/PKArkTools/releases/tag/v0.1.3');
      expect(r.notes, startsWith('### Added'));
      expect(ReleaseInfo.fromGitHub(releaseJson(kAppVersion), UpdatePlatform.android)!.isNewer, isFalse);
      expect(ReleaseInfo.fromGitHub(releaseJson('v99.0.0'), UpdatePlatform.android)!.isNewer, isTrue);
      expect(ReleaseInfo.fromGitHub({...json, 'draft': true}, UpdatePlatform.android), isNull);
      expect(ReleaseInfo.fromGitHub({'tag_name': 'nightly'}, UpdatePlatform.android), isNull);
    });
  });

  group('GitHub (servidor local)', () {
    late Directory tmp;
    HttpOverrides? saved;
    setUp(() async {
      // El binding de flutter_test sustituye HttpClient por uno que responde
      // 400: aquí se habla con un servidor local de verdad.
      saved = HttpOverrides.current;
      HttpOverrides.global = null;
      tmp = await Directory.systemTemp.createTemp('app_update');
    });
    tearDown(() async {
      HttpOverrides.global = saved;
      await tmp.delete(recursive: true);
    });

    test('latest: release, sin releases (404), error del servidor, basura y sin red', () async {
      var mode = 'ok';
      String? ua;
      final s = await serve((r) {
        ua = r.headers.value(HttpHeaders.userAgentHeader);
        switch (mode) {
          case 'ok':
            r.response.write(jsonEncode(releaseJson('v0.9.0')));
          case '404':
            r.response.statusCode = 404;
          case '500':
            r.response.statusCode = 500;
          default:
            r.response.write('<html>');
        }
      });
      addTearDown(s.close);
      final u = AppUpdater(api: Uri.parse('http://127.0.0.1:${s.port}/latest'), platform: UpdatePlatform.android);
      final r = await u.latest();
      expect(r!.version, const AppVersion(0, 9, 0));
      expect(r.isNewer, isTrue);
      expect(ua, 'PKArkTools/$kAppVersion');
      mode = '404';
      expect(await u.latest(), isNull);
      mode = '500';
      await expectLater(u.latest(), throwsA(isA<UpdateException>().having((e) => e.code, 'code', 'http')));
      mode = 'html';
      await expectLater(u.latest(), throwsA(isA<UpdateException>().having((e) => e.code, 'code', 'format')));
      final port = s.port;
      await s.close(force: true);
      final down = AppUpdater(api: Uri.parse('http://127.0.0.1:$port/latest'), platform: UpdatePlatform.android);
      await expectLater(down.latest(), throwsA(isA<UpdateException>().having((e) => e.code, 'code', 'network')));
    });

    test('download: progreso, archivo completo y se borran las descargas anteriores', () async {
      final apk = List<int>.generate(300000, (i) => i % 251);
      final s = await serve((r) async {
        r.response.contentLength = apk.length;
        for (var i = 0; i < apk.length; i += 65536) {
          r.response.add(apk.sublist(i, (i + 65536).clamp(0, apk.length)));
          await r.response.flush();
        }
      });
      addTearDown(s.close);
      final dir = Directory(p.join(tmp.path, 'dl'))..createSync();
      File(p.join(dir.path, 'PKArkTools-v0.1.1.apk')).writeAsStringSync('viejo');
      final u = AppUpdater(platform: UpdatePlatform.android, downloadDir: dir);
      final r = ReleaseInfo.fromGitHub(releaseJson('v0.9.0', apkSize: apk.length, host: 'http://127.0.0.1:${s.port}'),
          UpdatePlatform.android)!;
      final progress = <int>[];
      final f = await u.download(r, onProgress: (done, total) {
        expect(total, apk.length);
        progress.add(done);
      });
      expect(await f.readAsBytes(), apk);
      expect(progress.last, apk.length);
      expect(progress, orderedEquals([...progress]..sort()));
      expect(dir.listSync().map((e) => p.basename(e.path)), ['PKArkTools-v0.9.0.apk']);
    });

    test('download: incompleta o cancelada no deja archivo', () async {
      final gate = Completer<void>();
      var mode = 'short';
      final s = await serve((r) async {
        if (mode == 'short') {
          r.response.add(List.filled(1000, 1));
        } else {
          r.response.bufferOutput = false;
          r.response.add(List.filled(1000, 1));
          await r.response.flush();
          await gate.future;
        }
      });
      addTearDown(() => s.close(force: true));
      final dir = Directory(p.join(tmp.path, 'dl'));
      final u = AppUpdater(platform: UpdatePlatform.android, downloadDir: dir);
      final r = ReleaseInfo.fromGitHub(releaseJson('v0.9.0', apkSize: 5000, host: 'http://127.0.0.1:${s.port}'),
          UpdatePlatform.android)!;
      await expectLater(u.download(r), throwsA(isA<UpdateException>().having((e) => e.code, 'code', 'size')));
      expect(dir.listSync(), isEmpty);

      mode = 'hang';
      final cancel = Completer<void>();
      final started = Completer<void>();
      final run = u.download(r, cancel: cancel.future, onProgress: (_, _) {
        if (!started.isCompleted) started.complete();
      });
      await started.future;
      cancel.complete();
      await expectLater(run, throwsA(isA<UpdateException>().having((e) => e.code, 'code', 'aborted')));
      gate.complete();
      expect(dir.listSync(), isEmpty);
    });
  });

  group('sección de Ajustes', () {
    Future<void> pump(WidgetTester tester, AppUpdater u) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [appUpdaterProvider.overrideWithValue(u)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SingleChildScrollView(child: UpdateSection())),
        ),
      ));
    }

    testWidgets('Android: buscar, descargar con progreso e instalar', (tester) async {
      final u = FakeUpdater(UpdatePlatform.android, releaseJson('v0.9.0'));
      await pump(tester, u);
      expect(find.text('Versión $kAppVersion'), findsOneWidget);
      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();
      expect(find.text('Hay una versión nueva: 0.9.0'), findsOneWidget);
      expect(find.text('Novedades'), findsOneWidget);

      await tester.tap(find.text('Descargar e instalar'));
      await tester.pump();
      u.progress!(1000, 4000);
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('Descargando'), findsOneWidget);
      u.finishDownload();
      await tester.pump();
      await tester.pump();
      expect(u.installed, ['/cache/PKArkTools-v0.9.0.apk']);
      expect(find.textContaining('Confirma la instalación'), findsOneWidget);
      // El usuario cancela en la ventana de Android.
      u.installResult.completeError(const UpdateException('aborted'));
      await tester.pumpAndSettle();
      expect(find.text('Descargar e instalar'), findsOneWidget);
      expect(find.text('Instalación cancelada.'), findsOneWidget);
    });

    testWidgets('Android sin permiso: explica y abre el ajuste, sin descargar', (tester) async {
      final u = FakeUpdater(UpdatePlatform.android, releaseJson('v0.9.0'))..allowed = false;
      await pump(tester, u);
      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descargar e instalar'));
      await tester.pumpAndSettle();
      expect(find.text('Permitir instalar la actualización'), findsOneWidget);
      await tester.tap(find.text('Abrir ajustes'));
      await tester.pumpAndSettle();
      expect(u.permissionOpened, 1);
      expect(u.downloads, 0);
    });

    testWidgets('firma distinta: lo explica', (tester) async {
      final u = FakeUpdater(UpdatePlatform.android, releaseJson('v0.9.0'));
      await pump(tester, u);
      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descargar e instalar'));
      await tester.pump();
      u.finishDownload();
      await tester.pump();
      u.installResult.completeError(const UpdateException('conflict'));
      await tester.pumpAndSettle();
      expect(find.textContaining('firmada con otra clave'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('al día, y sin red', (tester) async {
      final u = FakeUpdater(UpdatePlatform.android, releaseJson('v$kAppVersion'));
      await pump(tester, u);
      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();
      expect(find.text('Tienes la última versión ($kAppVersion).'), findsOneWidget);
      u.error = const UpdateException('network');
      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo conectar con GitHub'), findsOneWidget);
    });

    testWidgets('escritorio: abre la página de descarga', (tester) async {
      final u = FakeUpdater(UpdatePlatform.macos, releaseJson('v0.9.0'));
      await pump(tester, u);
      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir la página de descarga'));
      await tester.pumpAndSettle();
      expect(u.opened.single.toString(), 'https://github.com/Rodriqe/PKArkTools/releases/tag/v0.9.0');
      expect(u.downloads, 0);
    });
  });
}

class FakeUpdater extends AppUpdater {
  FakeUpdater(UpdatePlatform platform, this.json) : super(platform: platform);
  final Map<String, Object?> json;
  UpdateException? error;
  bool allowed = true;
  int permissionOpened = 0, downloads = 0;
  final installed = <String>[];
  final opened = <Uri>[];
  void Function(int, int)? progress;
  Completer<File>? _download;
  final installResult = Completer<void>();

  void finishDownload() => _download!.complete(File('/cache/PKArkTools-v0.9.0.apk'));

  @override
  Future<ReleaseInfo?> latest() async {
    if (error != null) throw error!;
    return ReleaseInfo.fromGitHub(json, platform);
  }

  @override
  Future<File> download(ReleaseInfo release, {void Function(int, int)? onProgress, Future<void>? cancel}) {
    downloads++;
    progress = onProgress;
    return (_download = Completer<File>()).future;
  }

  @override
  Future<bool> canRequestInstall() async => allowed;

  @override
  Future<void> openInstallPermission() async => permissionOpened++;

  @override
  Future<void> install(File apk) {
    installed.add(apk.path);
    return installResult.future;
  }

  @override
  Future<bool> openPage(Uri url) async {
    opened.add(url);
    return true;
  }
}
