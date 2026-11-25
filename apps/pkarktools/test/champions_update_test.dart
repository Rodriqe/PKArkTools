import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pkarktools/data/update/app_update.dart' show MemoryUpdateStore;
import 'package:pkarktools/data/update/champions_update.dart';
import 'package:pkcore/pkcore.dart';

/// Datos de otra regulación, generados después que la copia integrada.
String remote({String generatedAt = '2030-01-01T00:00:00Z', int schema = 1, String code = 'M-D'}) {
  final j = jsonDecode(ChampionsData.builtinJson) as Map<String, Object?>;
  j['schemaVersion'] = schema;
  j['generatedAt'] = generatedAt;
  j['regulation'] = {
    ...j['regulation'] as Map<String, Object?>,
    'code': code,
    'name': 'VGC 2026 Reg $code',
    'from': '2026-12-02',
    'until': '2027-03-01',
  };
  return jsonEncode(j);
}

void main() {
  var now = DateTime.utc(2026, 11, 25, 12);
  late MemoryUpdateStore store;
  late List<Uri> calls;
  ChampionsUpdater updater(Future<String> Function() answer) => ChampionsUpdater(
    store: store,
    now: () => now,
    fetch: (u) {
      calls.add(u);
      return answer();
    },
  );

  setUp(() {
    store = MemoryUpdateStore();
    calls = [];
    now = DateTime.utc(2026, 11, 25, 12);
  });

  test('sin nada guardado: la copia integrada y toca consultar', () async {
    final u = updater(() async => remote());
    final s = await u.load();
    expect(s.origin, ChampionsOrigin.builtin);
    expect(s.data, same(ChampionsData.builtin));
    expect(u.due(s), isTrue);
  });

  test('descarga válida y más nueva: se usa y se guarda; al volver, sale de la caché', () async {
    final u = updater(() async => remote());
    final s = await u.check(await u.load());
    expect(calls.single, ChampionsUpdater.url);
    expect(s.check, ChampionsCheck.updated);
    expect(s.origin, ChampionsOrigin.downloaded);
    expect(s.data.regulation.code, 'M-D');
    expect(store.values[ChampionsUpdater.keyJson], isNotNull);

    final again = await u.load();
    expect(again.origin, ChampionsOrigin.cache);
    expect(again.data.regulation.code, 'M-D');
    // Como mucho una consulta cada 12 h.
    expect(u.due(again), isFalse);
    now = now.add(const Duration(hours: 13));
    expect(u.due(again), isTrue);
  });

  test('sin conexión: se queda con la caché (o la integrada)', () async {
    await updater(() async => remote()).check(await updater(() async => '').load());
    final u = updater(() async => throw const SocketException('offline'));
    final cached = await u.load();
    final s = await u.check(cached);
    expect(s.check, ChampionsCheck.failed);
    expect(s.data, same(cached.data));
    expect(s.data.regulation.code, 'M-D');

    store = MemoryUpdateStore();
    final u2 = updater(() async => throw const SocketException('offline'));
    final s2 = await u2.check(await u2.load());
    expect(s2.data.regulation.code, ChampionsData.builtin.regulation.code);
  });

  test('descarga no válida: no se guarda', () async {
    for (final bad in ['<html>404</html>', '{}', remote().replaceAll('"allowed"', '"x"')]) {
      final u = updater(() async => bad);
      final s = await u.check(await u.load());
      expect(s.check, ChampionsCheck.failed, reason: bad.length > 10 ? bad.substring(0, 10) : bad);
      expect(s.origin, ChampionsOrigin.builtin);
      expect(store.values[ChampionsUpdater.keyJson], isNull);
    }
  });

  test('caché estropeada o más vieja que la integrada: se ignora', () async {
    store.values[ChampionsUpdater.keyJson] = '{"schemaVersion": 1';
    expect((await updater(() async => '').load()).origin, ChampionsOrigin.builtin);
    store.values[ChampionsUpdater.keyJson] = remote(generatedAt: '2020-01-01T00:00:00Z');
    expect((await updater(() async => '').load()).origin, ChampionsOrigin.builtin);
  });

  test('esquema futuro: se ignora y se sugiere actualizar la app', () async {
    final u = updater(() async => remote(schema: 2));
    final s = await u.check(await u.load());
    expect(s.futureSchema, 2);
    expect(s.origin, ChampionsOrigin.builtin);
    expect(store.values[ChampionsUpdater.keyJson], isNull);
  });

  test('igual o más vieja que la que se usa: al día', () async {
    final u = updater(() async => ChampionsData.builtinJson);
    final s = await u.check(await u.load());
    expect(s.check, ChampionsCheck.upToDate);
    expect(s.data, same(ChampionsData.builtin));
  });

  test('el GET es anónimo: sin User-Agent ni cabeceras propias', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    late HttpHeaders seen;
    late String method;
    server.listen((req) {
      seen = req.headers;
      method = req.method;
      req.response
        ..write(ChampionsData.builtinJson)
        ..close();
    });
    final body = await ChampionsUpdater.httpGet(Uri.parse('http://127.0.0.1:${server.port}/champions.json'));
    expect(body, ChampionsData.builtinJson);
    expect(method, 'GET');
    expect(seen.value(HttpHeaders.userAgentHeader), isNull);
    final names = <String>[];
    seen.forEach((n, _) => names.add(n));
    expect(names.toSet().difference({'host', 'accept-encoding', 'content-length'}), isEmpty);
  });
}
