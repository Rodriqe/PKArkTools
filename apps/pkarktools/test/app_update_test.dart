import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:pkarktools/app.dart';
import 'package:pkarktools/app_version.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/data/update/app_update.dart';
import 'package:pkarktools/data/update/update_notice.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/settings/update_section.dart';

import 'arca_folder_test.dart' show memoryDb;
import 'arca_screen_test.dart' show settle;
import 'phone_layout_test.dart' show loadAppFonts, phoneSizes;

/// Forma real de `GET /repos/Rodriqe/PKArkTools/releases/latest` (v0.1.2).
Map<String, Object?> releaseJson(String tag, {int apkSize = 89080111, String host = 'https://github.com'}) => {
      'tag_name': tag,
      'draft': false,
      'prerelease': false,
      'html_url': 'https://github.com/Rodriqe/PKArkTools/releases/tag/$tag',
      'body': '## PKArkTools $tag\n\nUn párrafo\npartido en dos líneas.\n\n### Added\n'
          '- **Algo nuevo** con `código` y [un enlace](https://example.com),\n  que sigue aquí.\n- Otra cosa.',
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

bool _local(Uri u) => u.host == '127.0.0.1';

void main() {
  test('kAppVersion es la versión de pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final v = RegExp(r'^version:\s*([^+\s]+)', multiLine: true).firstMatch(pubspec)![1];
    expect(kAppVersion, v);
  });

  group('versiones y respuesta', () {
    test('se leen los tags y se ordenan como semver (sin el build)', () {
      AppVersion v(String s) => AppVersion.tryParse(s)!;
      expect(v('v0.1.3'), const AppVersion(0, 1, 3));
      expect(v('1.2'), const AppVersion(1, 2, 0));
      expect(v('v0.1.10') > v('v0.1.9'), isTrue);
      expect(v('v0.2.0') > v('v0.1.99'), isTrue);
      expect(v('v0.2.0') > v('v0.2.0-beta.2'), isTrue);
      expect(v('v0.2.0-beta.10') > v('v0.2.0-beta.2'), isTrue);
      expect(v('v0.1.2') > v('0.1.2'), isFalse);
      expect(v('0.1.2+3'), v('0.1.2'));
      expect(v('0.1.4+5') > v('0.1.4+4'), isFalse);
      expect(AppVersion.tryParse('latest'), isNull);
      expect(AppVersion.current.toString(), kAppVersion);
    });

    test('cada plataforma toma su archivo del release; iOS ninguno', () {
      final json = releaseJson('v0.1.3');
      String? asset(UpdatePlatform pl) => ReleaseInfo.fromGitHub(json, pl)!.asset?.name;
      expect(asset(UpdatePlatform.android), 'PKArkTools-v0.1.3.apk');
      expect(asset(UpdatePlatform.macos), 'PKArkTools-v0.1.3-macos.zip');
      expect(asset(UpdatePlatform.windows), 'PKArkTools-v0.1.3-windows-x64-setup.exe');
      expect(asset(UpdatePlatform.linux), 'PKArkTools-v0.1.3-linux-x64.tar.gz');
      expect(asset(UpdatePlatform.ios), isNull);
      final r = ReleaseInfo.fromGitHub(json, UpdatePlatform.android)!;
      expect(r.asset!.size, 89080111);
      expect(r.page.toString(), 'https://github.com/Rodriqe/PKArkTools/releases/tag/v0.1.3');
      expect(r.notes, startsWith('## PKArkTools'));
      expect(ReleaseInfo.fromGitHub(releaseJson(kAppVersion), UpdatePlatform.android)!.isNewer, isFalse);
      expect(ReleaseInfo.fromGitHub(releaseJson('v99.0.0'), UpdatePlatform.android)!.isNewer, isTrue);
      expect(ReleaseInfo.fromGitHub({...json, 'draft': true}, UpdatePlatform.android), isNull);
      expect(ReleaseInfo.fromGitHub({'tag_name': 'nightly'}, UpdatePlatform.android), isNull);
      // Una página de otro sitio no se usa: se construye la del repo.
      final evil = ReleaseInfo.fromGitHub({...json, 'html_url': 'https://evil.example/x'}, UpdatePlatform.ios)!;
      expect(evil.page.toString(), 'https://github.com/Rodriqe/PKArkTools/releases/tag/v0.1.3');
    });

    test('solo HTTPS, del repo y de los dominios de GitHub', () {
      bool ok(String u) => isTrustedDownload(Uri.parse(u));
      expect(ok('https://github.com/Rodriqe/PKArkTools/releases/download/v0.1.2/PKArkTools-v0.1.2.apk'), isTrue);
      expect(ok('https://release-assets.githubusercontent.com/github-production-release-asset/1/2?sig=x'), isTrue);
      expect(ok('https://objects.githubusercontent.com/github-production-release-asset-2e65be/1'), isTrue);
      expect(ok('http://github.com/Rodriqe/PKArkTools/releases/download/v0.1.2/a.apk'), isFalse);
      expect(ok('https://github.com/otro/PKArkTools/releases/download/v0.1.2/a.apk'), isFalse);
      expect(ok('https://github.com.evil.example/Rodriqe/PKArkTools/releases/download/a.apk'), isFalse);
      expect(ok('https://github.com:8443/Rodriqe/PKArkTools/releases/download/v0.1.2/a.apk'), isFalse);
      expect(ok('https://example.com/a.apk'), isFalse);
      expect(isTrustedPage(Uri.parse('https://github.com/Rodriqe/PKArkTools/releases/tag/v1.0.0')), isTrue);
      expect(isTrustedPage(Uri.parse('https://github.com/otro/repo/releases')), isFalse);
    });

    test('notas: markdown sencillo', () {
      final blocks = ReleaseNotes.parse(releaseJson('v9.0.0')['body']! as String);
      expect(blocks, [
        ('h2', 'PKArkTools v9.0.0'),
        ('p', 'Un párrafo partido en dos líneas.'),
        ('h3', 'Added'),
        ('li', '**Algo nuevo** con `código` y [un enlace](https://example.com), que sigue aquí.'),
        ('li', 'Otra cosa.'),
      ]);
      final spans = ReleaseNotes.spans(blocks[3].$2, const TextStyle(), Colors.black);
      expect(spans.map((s) => (s as TextSpan).text), ['Algo nuevo', ' con ', 'código', ' y ', 'un enlace', ', que sigue aquí.']);
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

    test('latest: release, ETag (304 usa la caché), 404, 500, límite, basura y sin red', () async {
      var mode = 'ok';
      final seen = <(String?, String?)>[];
      final s = await serve((r) {
        seen.add((r.headers.value(HttpHeaders.userAgentHeader), r.headers.value(HttpHeaders.ifNoneMatchHeader)));
        switch (mode) {
          case 'ok':
            if (r.headers.value(HttpHeaders.ifNoneMatchHeader) == '"abc"') {
              r.response.statusCode = 304;
              return;
            }
            r.response.headers.set(HttpHeaders.etagHeader, '"abc"');
            r.response.write(jsonEncode(releaseJson('v9.0.0')));
          case '404':
            r.response.statusCode = 404;
          case '500':
            r.response.statusCode = 500;
          case '403':
            r.response.statusCode = 403;
          default:
            r.response.write('<html>');
        }
      });
      addTearDown(s.close);
      final store = MemoryUpdateStore();
      final u = AppUpdater(api: Uri.parse('http://127.0.0.1:${s.port}/latest'), platform: UpdatePlatform.android, store: store);
      final r = await u.latest();
      expect(r!.version, const AppVersion(9, 0, 0));
      expect(r.isNewer, isTrue);
      expect(seen.last, ('PKArkTools/$kAppVersion', null));
      expect(store.values[AppUpdater.kEtag], '"abc"');
      // Segunda vez: manda el ETag, GitHub contesta 304 y sale de la caché.
      final again = await u.latest();
      expect(seen.last.$2, '"abc"');
      expect(again!.version, r.version);
      expect(again.asset!.name, r.asset!.name);

      mode = '404';
      expect(await u.latest(), isNull);
      expect(await u.cached(), isNull);
      mode = '500';
      await expectLater(u.latest(), throwsA(isA<UpdateException>().having((e) => e.code, 'code', 'http')));
      mode = '403';
      await expectLater(u.latest(), throwsA(isA<UpdateException>().having((e) => e.code, 'code', 'rate')));
      mode = 'html';
      await expectLater(u.latest(), throwsA(isA<UpdateException>().having((e) => e.code, 'code', 'format')));
      final port = s.port;
      await s.close(force: true);
      final down = AppUpdater(api: Uri.parse('http://127.0.0.1:$port/latest'), platform: UpdatePlatform.android);
      await expectLater(down.latest(), throwsA(isA<UpdateException>().having((e) => e.code, 'code', 'network')));
    });

    test('autoCheck: una consulta cada 24 h, desactivable, omitir versión y en silencio sin red', () async {
      var hits = 0;
      var tag = 'v9.0.0';
      final s = await serve((r) {
        hits++;
        final etag = '"$tag"';
        if (r.headers.value(HttpHeaders.ifNoneMatchHeader) == etag) {
          r.response.statusCode = 304;
          return;
        }
        r.response.headers.set(HttpHeaders.etagHeader, etag);
        r.response.write(jsonEncode(releaseJson(tag)));
      });
      addTearDown(() => s.close(force: true));
      var now = DateTime.utc(2026, 11, 23, 10);
      final store = MemoryUpdateStore();
      AppUpdater updater([int? port]) => AppUpdater(
          api: Uri.parse('http://127.0.0.1:${port ?? s.port}/latest'),
          platform: UpdatePlatform.android,
          store: store,
          now: () => now);
      final u = updater();

      expect((await u.autoCheck())!.version.toString(), '9.0.0');
      expect(hits, 1);
      now = now.add(const Duration(hours: 23));
      expect((await u.autoCheck())!.version.toString(), '9.0.0', reason: 'de la caché, sin red');
      expect(hits, 1);
      now = now.add(const Duration(hours: 2));
      expect(await u.autoCheck(), isNotNull);
      expect(hits, 2, reason: 'pasadas 24 h vuelve a preguntar (con ETag → 304)');

      // Omitir 9.0.0: no vuelve a avisar de ella, sí de la siguiente.
      await u.skip(const AppVersion(9, 0, 0));
      expect(await u.autoCheck(), isNull);
      tag = 'v9.0.1';
      now = now.add(const Duration(days: 1));
      expect((await u.autoCheck())!.version.toString(), '9.0.1');
      expect(hits, 3);

      // Desactivado: ni consulta ni aviso.
      await u.setAutoCheck(false);
      now = now.add(const Duration(days: 2));
      expect(await u.autoCheck(), isNull);
      expect(hits, 3);
      await u.setAutoCheck(true);

      // Sin red: no falla; usa la última respuesta guardada.
      final port = s.port;
      await s.close(force: true);
      now = now.add(const Duration(days: 2));
      expect((await updater(port).autoCheck())!.version.toString(), '9.0.1');
      expect(await AppUpdater(api: Uri.parse('http://127.0.0.1:$port/x'), platform: UpdatePlatform.android).autoCheck(),
          isNull);
    });

    test('download: progreso, archivo completo, redirecciones y se borran las descargas anteriores', () async {
      final apk = List<int>.generate(300000, (i) => i % 251);
      final s = await serve((r) async {
        if (r.uri.path.startsWith('/Rodriqe/')) {
          r.response.statusCode = 302;
          r.response.headers.set(HttpHeaders.locationHeader, '/asset/1');
          return;
        }
        r.response.contentLength = apk.length;
        for (var i = 0; i < apk.length; i += 65536) {
          r.response.add(apk.sublist(i, (i + 65536).clamp(0, apk.length)));
          await r.response.flush();
        }
      });
      addTearDown(s.close);
      final dir = Directory(p.join(tmp.path, 'dl'))..createSync();
      File(p.join(dir.path, 'PKArkTools-v0.1.1.apk')).writeAsStringSync('viejo');
      final u = AppUpdater(platform: UpdatePlatform.android, downloadDir: dir, trusted: _local);
      final r = ReleaseInfo.fromGitHub(releaseJson('v9.0.0', apkSize: apk.length, host: 'http://127.0.0.1:${s.port}'),
          UpdatePlatform.android)!;
      final progress = <int>[];
      final f = await u.download(r, onProgress: (done, total) {
        expect(total, apk.length);
        progress.add(done);
      });
      expect(await f.readAsBytes(), apk);
      expect(progress.last, apk.length);
      expect(progress, orderedEquals([...progress]..sort()));
      expect(dir.listSync().map((e) => p.basename(e.path)), ['PKArkTools-v9.0.0.apk']);
      await u.deleteDownload(f);
      expect(dir.listSync(), isEmpty);
      await u.cleanDownloads();
      expect(dir.existsSync(), isFalse);

      // Con la comprobación real, un enlace http o una redirección fuera de
      // GitHub no se descargan.
      final strict = AppUpdater(platform: UpdatePlatform.android, downloadDir: dir);
      await expectLater(strict.download(r), throwsA(isA<UpdateException>().having((e) => e.code, 'code', 'untrusted')));
      final onlyFirstHop = AppUpdater(
          platform: UpdatePlatform.android, downloadDir: dir, trusted: (u) => _local(u) && u.path.startsWith('/Rodriqe/'));
      await expectLater(
          onlyFirstHop.download(r), throwsA(isA<UpdateException>().having((e) => e.code, 'code', 'untrusted')));
      expect(dir.listSync(), isEmpty);
    });

    test('download: incompleta, más grande o cancelada no deja archivo', () async {
      final gate = Completer<void>();
      var mode = 'short';
      final s = await serve((r) async {
        if (mode == 'short') {
          r.response.add(List.filled(1000, 1));
        } else if (mode == 'long') {
          r.response.add(List.filled(9000, 1));
        } else {
          r.response.bufferOutput = false;
          r.response.add(List.filled(1000, 1));
          await r.response.flush();
          await gate.future;
        }
      });
      addTearDown(() => s.close(force: true));
      final dir = Directory(p.join(tmp.path, 'dl'));
      final u = AppUpdater(platform: UpdatePlatform.android, downloadDir: dir, trusted: _local);
      final r = ReleaseInfo.fromGitHub(releaseJson('v9.0.0', apkSize: 5000, host: 'http://127.0.0.1:${s.port}'),
          UpdatePlatform.android)!;
      await expectLater(u.download(r), throwsA(isA<UpdateException>().having((e) => e.code, 'code', 'size')));
      expect(dir.listSync(), isEmpty);
      mode = 'long';
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

  group('firma del APK', () {
    const app = ApkSignature('dev.pkarktools.app', {'aa11'});
    Future<String?> check(ApkSignature? apk, {ApkSignature? mine = app}) async {
      try {
        await (FakeUpdater(UpdatePlatform.android, const {})
              ..mine = mine
              ..apk = apk)
            .verify(File('x.apk'));
        return null;
      } on UpdateException catch (e) {
        expect(e.code, 'signature');
        return e.detail;
      }
    }

    test('mismo paquete y certificado: se instala; si no, se bloquea', () async {
      expect(await check(const ApkSignature('dev.pkarktools.app', {'AA11'})), isNull);
      expect(await check(const ApkSignature('dev.pkarktools.app', {'bb22'})), 'otro certificado');
      expect(await check(const ApkSignature('dev.pkarktools.app', {'aa11', 'bb22'})), 'otro certificado');
      expect(await check(const ApkSignature('com.evil', {'aa11'})), 'paquete com.evil');
      expect(await check(null), contains('sin firma'));
      expect(await check(const ApkSignature('dev.pkarktools.app', {})), contains('sin firma'));
      expect(await check(const ApkSignature('dev.pkarktools.app', {'aa11'}), mine: null), contains('instalada'));
    });

    test('lee la respuesta del canal nativo', () {
      final s = ApkSignature.fromChannel({
        'package': 'dev.pkarktools.app',
        'certificates': ['AB12', 'cd34'],
      })!;
      expect(s.package, 'dev.pkarktools.app');
      expect(s.certificates, {'ab12', 'cd34'});
      expect(ApkSignature.fromChannel(null), isNull);
      expect(ApkSignature.fromChannel({'package': 1}), isNull);
    });
  });

  group('aviso y Ajustes', () {
    Future<ProviderContainer> pump(WidgetTester tester, AppUpdater u, {Widget? home}) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [appUpdaterProvider.overrideWithValue(u)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home ??
              const Scaffold(body: SingleChildScrollView(child: Column(children: [UpdateBanner(), UpdateAboutControls()]))),
        ),
      ));
      return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    }

    testWidgets('al abrir: aviso, hoja con notas y «Omitir esta versión»', (tester) async {
      final u = FakeUpdater(UpdatePlatform.android, releaseJson('v9.0.0'));
      final c = await pump(tester, u);
      expect(find.text('PKArkTools 9.0.0 disponible'), findsNothing);
      await c.read(updateNoticeProvider.notifier).startup();
      await tester.pumpAndSettle();
      expect(u.cleaned, 1, reason: 'borra APKs que quedaran de otra vez');
      expect(find.text('PKArkTools 9.0.0 disponible'), findsNWidgets(2)); // tarjeta y chip
      await tester.tap(find.text('PKArkTools 9.0.0 disponible').first);
      await tester.pumpAndSettle();
      expect(find.byType(UpdateSheet), findsOneWidget);
      expect(find.text('Novedades'), findsOneWidget);
      expect(find.textContaining('Otra cosa.'), findsOneWidget);
      expect(find.text('Actualizar'), findsOneWidget);
      await tester.tap(find.text('Omitir esta versión'));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateSheet), findsNothing);
      expect(find.text('PKArkTools 9.0.0 disponible'), findsNothing);
      expect(await u.skippedVersion(), const AppVersion(9, 0, 0));
      // Al volver a abrir la app, no avisa de la omitida.
      await c.read(updateNoticeProvider.notifier).startup();
      await tester.pumpAndSettle();
      expect(find.text('PKArkTools 9.0.0 disponible'), findsNothing);
    });

    testWidgets('Android: descarga con progreso, comprueba la firma, instala y borra el APK', (tester) async {
      final u = FakeUpdater(UpdatePlatform.android, releaseJson('v9.0.0'));
      await pump(tester, u);
      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateSheet), findsOneWidget, reason: 'la búsqueda manual abre la hoja');
      await tester.tap(find.text('Actualizar'));
      await tester.pump();
      u.progress!(1000, 4000);
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('Descargando'), findsOneWidget);
      u.finishDownload();
      await tester.pump();
      await tester.pump();
      expect(u.installed, ['/cache/PKArkTools-v9.0.0.apk']);
      expect(find.textContaining('Confirma la instalación'), findsOneWidget);
      // El usuario cancela en la ventana de Android: el APK se borra.
      u.installResult.completeError(const UpdateException('aborted'));
      await tester.pumpAndSettle();
      expect(u.deleted, ['/cache/PKArkTools-v9.0.0.apk']);
      expect(find.text('Actualizar'), findsOneWidget);
      expect(find.text('Actualización cancelada.'), findsOneWidget);
    });

    testWidgets('Android: cancelar la descarga', (tester) async {
      final u = FakeUpdater(UpdatePlatform.android, releaseJson('v9.0.0'));
      final c = await pump(tester, u);
      await c.read(updateNoticeProvider.notifier).checkNow();
      await tester.pump();
      await tester.tap(find.text('PKArkTools 9.0.0 disponible').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar'));
      await tester.pump();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(u.cancelled, isTrue);
      expect(u.installed, isEmpty);
      expect(find.text('Actualización cancelada.'), findsOneWidget);
    });

    testWidgets('Android: firma distinta → no instala, avisa y borra el APK', (tester) async {
      final u = FakeUpdater(UpdatePlatform.android, releaseJson('v9.0.0'))
        ..apk = const ApkSignature('dev.pkarktools.app', {'release'});
      await pump(tester, u);
      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar'));
      await tester.pump();
      u.finishDownload();
      await tester.pumpAndSettle();
      expect(u.installed, isEmpty);
      expect(u.deleted, ['/cache/PKArkTools-v9.0.0.apk']);
      expect(find.textContaining('no está firmado con el mismo certificado'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('Android sin «instalar apps desconocidas»: explica y abre el ajuste, sin descargar', (tester) async {
      final u = FakeUpdater(UpdatePlatform.android, releaseJson('v9.0.0'))..allowed = false;
      await pump(tester, u);
      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();
      expect(find.text('Permitir instalar la actualización'), findsOneWidget);
      expect(find.textContaining('Permitir de esta fuente'), findsOneWidget);
      await tester.tap(find.text('Abrir ajustes'));
      await tester.pumpAndSettle();
      expect(u.permissionOpened, 1);
      expect(u.downloads, 0);
    });

    testWidgets('al día, sin red y límite de GitHub', (tester) async {
      final u = FakeUpdater(UpdatePlatform.android, releaseJson('v$kAppVersion'));
      await pump(tester, u);
      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();
      expect(find.text('Tienes la última versión ($kAppVersion).'), findsOneWidget);
      u.error = const UpdateException('network');
      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo conectar con GitHub'), findsOneWidget);
      u.error = const UpdateException('rate', '403');
      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();
      expect(find.textContaining('GitHub limita las consultas'), findsOneWidget);
    });

    testWidgets('«Buscar automáticamente» se guarda', (tester) async {
      final u = FakeUpdater(UpdatePlatform.android, releaseJson('v9.0.0'));
      final c = await pump(tester, u);
      await c.read(updateNoticeProvider.notifier).startup();
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
      await tester.tap(find.text('Buscar actualizaciones automáticamente'));
      await tester.pumpAndSettle();
      expect(await u.autoCheckEnabled(), isFalse);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
    });

    testWidgets('escritorio: descarga, guarda y explica el paso manual', (tester) async {
      final u = FakeUpdater(UpdatePlatform.macos, releaseJson('v9.0.0'));
      await pump(tester, u);
      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();
      expect(find.text('Descargar'), findsOneWidget);
      await tester.tap(find.text('Descargar'));
      await tester.pump();
      u.finishDownload();
      await tester.pumpAndSettle();
      expect(u.saved, ['PKArkTools-v9.0.0-macos.zip']);
      expect(find.text('Guardado en /Users/ash/Downloads/PKArkTools-v9.0.0-macos.zip'), findsOneWidget);
      expect(find.textContaining('arrastra PKArkTools.app a Aplicaciones'), findsOneWidget);
      await tester.tap(find.text('Mostrar en la carpeta'));
      expect(u.revealed, ['/Users/ash/Downloads/PKArkTools-v9.0.0-macos.zip']);
      await tester.ensureVisible(find.text('Abrir la página del release'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir la página del release'));
      expect(u.opened.single.toString(), 'https://github.com/Rodriqe/PKArkTools/releases/tag/v9.0.0');
      expect(u.installed, isEmpty);
    });

    testWidgets('iOS: abre la página del release', (tester) async {
      final u = FakeUpdater(UpdatePlatform.ios, releaseJson('v9.0.0'));
      await pump(tester, u);
      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();
      expect(find.textContaining('En iPhone y iPad'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Abrir la página del release'));
      await tester.pumpAndSettle();
      expect(u.opened.single.toString(), 'https://github.com/Rodriqe/PKArkTools/releases/tag/v9.0.0');
      expect(u.downloads, 0);
    });
  });

  group('sin desbordes', () {
    late ArcaDatabase db;
    late Directory tmp;
    late ArcaRepository repo;
    setUpAll(loadAppFonts);
    setUp(() async {
      db = memoryDb();
      tmp = await Directory.systemTemp.createTemp('update_layout');
      repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
    });
    tearDown(() async {
      await db.close();
      await tmp.delete(recursive: true);
    });

    final sizes = {
      ...phoneSizes,
      'escritorio 1280×800': (const Size(1280, 800), 1.0),
    };
    for (final MapEntry(key: name, value: (size, scale)) in sizes.entries) {
      for (final locale in ['es', 'en']) {
        testWidgets('Ajustes con aviso y hoja: $name ($locale)', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.localesTestValue = [Locale(locale)];
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearLocalesTestValue);
          await tester.runAsync(() => repo.setSetting('locale', locale));
          final u = FakeUpdater(UpdatePlatform.android, releaseJson('v9.0.0'));
          await tester.pumpWidget(ProviderScope(
            overrides: [arcaRepositoryProvider.overrideWithValue(repo), appUpdaterProvider.overrideWithValue(u)],
            child: const PKArkToolsApp(initialLocation: '/ajustes'),
          ));
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 1));
          });
          final c = ProviderScope.containerOf(tester.element(find.byType(PKArkToolsApp)));
          await tester.runAsync(() => c.read(updateNoticeProvider.notifier).startup());
          await settle(tester);
          expect(tester.takeException(), isNull);
          // Punto en el icono de Ajustes (barra inferior o rail).
          expect(find.byType(Badge), findsOneWidget);
          expect(find.byType(UpdateBanner), findsOneWidget);
          final title = locale == 'es' ? 'PKArkTools 9.0.0 disponible' : 'PKArkTools 9.0.0 available';
          // Ajustes › Acerca de, hasta el final.
          final check = find.text(locale == 'es' ? 'Buscar actualizaciones' : 'Check for updates');
          await tester.scrollUntilVisible(check, 300, scrollable: contentScrollable);
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(title).last);
          await settle(tester);
          expect(find.byType(UpdateSheet), findsOneWidget);
          expect(tester.takeException(), isNull);
          final update = find.text(locale == 'es' ? 'Actualizar' : 'Update');
          await tester.ensureVisible(update);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(update);
          await tester.pump();
          u.progress!(30 << 20, 89 << 20);
          await tester.pump();
          expect(tester.takeException(), isNull);
          u.apk = const ApkSignature('dev.pkarktools.app', {'release'});
          u.finishDownload();
          await settle(tester);
          final retry = find.text(locale == 'es' ? 'Reintentar' : 'Retry');
          await tester.ensureVisible(retry);
          await tester.pump(const Duration(milliseconds: 300));
          expect(retry, findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}

class FakeUpdater extends AppUpdater {
  FakeUpdater(UpdatePlatform platform, this.json) : super(platform: platform, store: MemoryUpdateStore());
  final Map<String, Object?> json;
  UpdateException? error;
  bool allowed = true, cancelled = false;
  int permissionOpened = 0, downloads = 0, cleaned = 0;
  final installed = <String>[], deleted = <String>[], saved = <String>[], revealed = <String>[];
  final opened = <Uri>[];
  void Function(int, int)? progress;
  Completer<File>? _download;
  final installResult = Completer<void>();
  ApkSignature? mine = const ApkSignature('dev.pkarktools.app', {'debug'});
  ApkSignature? apk = const ApkSignature('dev.pkarktools.app', {'debug'});

  void finishDownload() => _download!.complete(File(platform == UpdatePlatform.android
      ? '/cache/PKArkTools-v9.0.0.apk'
      : '/tmp/${ReleaseInfo.fromGitHub(json, platform)!.asset!.name}'));

  @override
  Future<ReleaseInfo?> latest() async {
    if (error != null) throw error!;
    return ReleaseInfo.fromGitHub(json, platform);
  }

  @override
  Future<void> cleanDownloads() async => cleaned++;

  @override
  Future<File> download(ReleaseInfo release, {void Function(int, int)? onProgress, Future<void>? cancel}) {
    downloads++;
    progress = onProgress;
    final c = _download = Completer<File>();
    cancel?.then((_) {
      cancelled = true;
      if (!c.isCompleted) c.completeError(const UpdateException('aborted'));
    });
    return c.future;
  }

  @override
  Future<void> deleteDownload(File f) async => deleted.add(f.path);

  @override
  Future<String?> saveDownload(File file, String name) async {
    saved.add(name);
    return '/Users/ash/Downloads/$name';
  }

  @override
  Future<bool> reveal(String path) async {
    revealed.add(path);
    return true;
  }

  @override
  Future<bool> canRequestInstall() async => allowed;

  @override
  Future<void> openInstallPermission() async => permissionOpened++;

  @override
  Future<ApkSignature?> installedSignature() async => mine;

  @override
  Future<ApkSignature?> apkSignature(File apk) async => this.apk;

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

/// Primera lista del contenido (no la de la barra lateral, que también se
/// desplaza en pantallas bajas).
Finder get contentScrollable =>
    find.descendant(of: find.byType(StatefulNavigationShell), matching: find.byType(Scrollable)).first;
