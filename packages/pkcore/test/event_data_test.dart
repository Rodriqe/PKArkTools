import 'dart:convert';
import 'dart:io';

import 'package:pkcore/pkcore.dart';
import 'package:test/test.dart';

void main() {
  final text = File('../../data/events/events.json').readAsStringSync();
  Map<String, Object?> base() => jsonDecode(text) as Map<String, Object?>;
  EventData parse(Map<String, Object?> j) => EventData.parse(jsonEncode(j));
  Matcher invalid({int? future}) =>
      throwsA(isA<EventDataException>().having((e) => e.futureSchema, 'futureSchema', future));
  List<Object?> events(Map<String, Object?> j) => j['events']! as List<Object?>;
  Map<String, Object?> withEvent(int i, Map<String, Object?> Function(Map<String, Object?>) f) {
    final j = base();
    final ev = events(j);
    ev[i] = f(ev[i]! as Map<String, Object?>);
    return j;
  }

  tearDown(EventDb.reset);

  test('data/events/events.json es válido y se parece a la copia integrada', () {
    final d = EventData.parse(text);
    expect(d.schemaVersion, EventData.supportedSchemaVersion);
    expect(d.sourceCommit, matches(RegExp(r'^[0-9a-f]{40}$')));
    expect(d.count, greaterThanOrEqualTo(EventData.minEvents));
    expect(d.count, greaterThanOrEqualTo(EventData.builtin.count * 0.9));
    expect(d.gifts.where((g) => g.canCreate).length, greaterThan(d.count * 0.9));
    final b = EventData.builtin;
    expect(b.sourceCommit, matches(RegExp(r'^[0-9a-f]{40}$')));
    expect(b.gifts.first.key, d.gifts.first.key);
  });

  test('una base descargada sustituye a la integrada y se puede volver', () {
    final j = base();
    final ev = events(j)..removeLast();
    j['count'] = ev.length;
    j['generatedAt'] = '2030-01-01T00:00:00Z';
    final d = parse(j);
    expect(d.isNewerThan(EventData.builtin), isTrue);
    EventDb.use(d);
    expect(EventDb.all.length, ev.length);
    expect(EventDb.data, same(d));
    // La plantilla sale de la base descargada.
    final g = EventDb.all.firstWhere((g) => g.canCreate);
    expect(g.template()!.species, g.species);
    EventDb.reset();
    expect(EventDb.all.length, EventData.builtin.count);
  });

  test('no válido', () {
    expect(() => EventData.parse('nada'), invalid());
    expect(() => EventData.parse('[]'), invalid());
    expect(() => parse(base()..remove('source')), invalid());
    expect(() => parse(base()..['source'] = {'commit': 'abc', 'date': '2026-11-22'}), invalid());
    expect(() => parse(base()..['count'] = 5), invalid());
    final short = base();
    events(short).removeRange(10, events(short).length);
    expect(() => parse(short..['count'] = 10), invalid());
    expect(() => parse(withEvent(3, (e) => {...e, 't': 'no es base64!'})), invalid());
    expect(
      () => parse(
        withEvent(
          3,
          (e) => {
            ...e,
            'm': {...e['m']! as Map, 's': 5000},
          },
        ),
      ),
      invalid(),
    );
    // Un campo con otro tipo (nivel como texto): no llega a la app.
    expect(
      () => parse(
        withEvent(
          3,
          (e) => {
            ...e,
            'm': {...e['m']! as Map, 'l': '10'},
          },
        ),
      ),
      invalid(),
    );
  });

  test('esquema futuro: se ignora y se avisa', () {
    expect(() => parse(base()..['schemaVersion'] = 2), invalid(future: 2));
    expect(() => EventData.parse('{"schemaVersion": 9}'), invalid(future: 9));
  });
}
