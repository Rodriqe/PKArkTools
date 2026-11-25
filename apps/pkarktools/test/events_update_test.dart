import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pkarktools/data/update/anonymous_get.dart';
import 'package:pkarktools/data/update/app_update.dart' show MemoryUpdateStore;
import 'package:pkarktools/data/update/events_update.dart';
import 'package:pkcore/pkcore.dart';

void main() {
  final file = File('../../data/events/events.json').readAsStringSync();
  String remote({String generatedAt = '2030-01-01T00:00:00Z', int schema = 1, bool dropLast = false}) {
    final j = jsonDecode(file) as Map<String, Object?>;
    j['schemaVersion'] = schema;
    j['generatedAt'] = generatedAt;
    if (dropLast) {
      final ev = j['events']! as List..removeLast();
      j['count'] = ev.length;
    }
    return jsonEncode(j);
  }

  var now = DateTime.utc(2026, 11, 25, 12);
  late MemoryUpdateStore store;
  late MemoryBlobStore files;
  EventsUpdater updater(Future<String> Function() answer) =>
      EventsUpdater(store: store, files: files, now: () => now, fetch: (_) => answer());

  setUp(() {
    store = MemoryUpdateStore();
    files = MemoryBlobStore();
    now = DateTime.utc(2026, 11, 25, 12);
  });

  test('sin nada guardado: la base integrada y toca consultar', () async {
    final u = updater(() async => remote());
    final s = await u.load();
    expect(s.origin, EventsOrigin.builtin);
    expect(s.data, same(EventData.builtin));
    expect(u.due(s), isTrue);
  });

  test('descarga válida y más nueva: se usa y se guarda; luego sale de la caché; una cada 24 h', () async {
    final u = updater(() async => remote(dropLast: true));
    final s = await u.check(await u.load());
    expect(s.check, EventsCheck.updated);
    expect(s.data.count, EventData.builtin.count - 1);
    final again = await u.load();
    expect(again.origin, EventsOrigin.cache);
    expect(again.data.count, EventData.builtin.count - 1);
    expect(u.due(again), isFalse);
    now = now.add(const Duration(hours: 25));
    expect(u.due(again), isTrue);
  });

  test('sin conexión o descarga no válida: caché o integrada, sin guardar nada', () async {
    for (final answer in <Future<String> Function()>[
      () async => throw const SocketException('offline'),
      () async => '<html>404</html>',
      () async => remote().replaceFirst('"events"', '"x"'),
    ]) {
      final u = updater(answer);
      final s = await u.check(await u.load());
      expect(s.check, EventsCheck.failed);
      expect(s.origin, EventsOrigin.builtin);
      expect(files.files[EventsUpdater.fileJson], isNull);
    }
    files.files[EventsUpdater.fileJson] = remote(dropLast: true);
    final u = updater(() async => throw const SocketException('offline'));
    final s = await u.check(await u.load());
    expect(s.origin, EventsOrigin.cache);
  });

  test('caché estropeada o más vieja que la integrada: se ignora', () async {
    files.files[EventsUpdater.fileJson] = '{"schemaVersion": 1';
    expect((await updater(() async => '').load()).origin, EventsOrigin.builtin);
    files.files[EventsUpdater.fileJson] = remote(generatedAt: '2020-01-01T00:00:00Z');
    expect((await updater(() async => '').load()).origin, EventsOrigin.builtin);
  });

  test('esquema futuro: se ignora y se sugiere actualizar la app', () async {
    final u = updater(() async => '{"schemaVersion": 2, "events": []}');
    final s = await u.check(await u.load());
    expect(s.futureSchema, 2);
    expect(s.origin, EventsOrigin.builtin);
  });

  test('eventos nuevos desde la última vista (la primera vez, ninguno)', () async {
    final u = updater(() async => '');
    final s = await u.load();
    expect(await u.markSeen(s), isEmpty);
    expect(await u.markSeen(s), isEmpty);
    final keys = files.files[EventsUpdater.fileSeen]!.split('\n');
    files.files[EventsUpdater.fileSeen] = keys.skip(1).join('\n');
    expect(await u.markSeen(s), {keys.first});
    expect(await u.markSeen(s), isEmpty);
  });

  test('el GET es anónimo y tiene límite de tamaño', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final seen = <String>{};
    server.listen((req) {
      req.headers.forEach((n, _) => seen.add(n));
      req.response
        ..write('x' * 2000)
        ..close();
    });
    final url = Uri.parse('http://127.0.0.1:${server.port}/events.json');
    expect(await anonymousGet(url, maxBytes: 4096), hasLength(2000));
    expect(seen.difference({'host', 'accept-encoding', 'content-length'}), isEmpty);
    await expectLater(anonymousGet(url, maxBytes: 1000), throwsA(isA<HttpException>()));
  });
}
