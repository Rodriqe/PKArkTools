import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pkcore/pkcore.dart';

import '../arca_session.dart' show arcaRepositoryProvider;
import 'anonymous_get.dart';
import 'app_update.dart' show UpdateStore;
import 'update_notice.dart' show RepositoryUpdateStore;

/// Archivos de datos descargados (la base de eventos ocupa unos 4 MB: no va
/// en la tabla de ajustes).
abstract class BlobStore {
  Future<String?> read(String name);
  Future<void> write(String name, String text);
}

class MemoryBlobStore implements BlobStore {
  final files = <String, String>{};
  @override
  Future<String?> read(String name) async => files[name];
  @override
  Future<void> write(String name, String text) async => files[name] = text;
}

/// En la carpeta de soporte de la app (`data_cache/`), nunca en la del Arca.
class FileBlobStore implements BlobStore {
  FileBlobStore([Future<Directory> Function()? dir]) : _dir = dir ?? _defaultDir;
  final Future<Directory> Function() _dir;

  static Future<Directory> _defaultDir() async =>
      Directory(p.join((await getApplicationSupportDirectory()).path, 'data_cache'));

  @override
  Future<String?> read(String name) async {
    try {
      final f = File(p.join((await _dir()).path, name));
      return await f.exists() ? await f.readAsString() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String name, String text) async {
    try {
      final d = await _dir();
      await d.create(recursive: true);
      final tmp = File(p.join(d.path, '$name.tmp'));
      await tmp.writeAsString(text, flush: true);
      await tmp.rename(p.join(d.path, name));
    } catch (_) {}
  }
}

enum EventsOrigin { builtin, cache, downloaded }

enum EventsCheck { none, updated, upToDate, failed }

@immutable
class EventsStatus {
  const EventsStatus({
    required this.data,
    required this.origin,
    this.checkedAt,
    this.check = EventsCheck.none,
    this.futureSchema,
    this.newKeys = const {},
  });

  final EventData data;
  final EventsOrigin origin;
  final DateTime? checkedAt;
  final EventsCheck check;

  /// La base publicada tiene un esquema que esta versión no entiende.
  final int? futureSchema;

  /// Eventos nuevos desde la última vez que se abrió el explorador
  /// ([EventGift.key]).
  final Set<String> newKeys;

  EventsStatus copyWith({
    EventData? data,
    EventsOrigin? origin,
    DateTime? checkedAt,
    EventsCheck? check,
    int? Function()? futureSchema,
    Set<String>? newKeys,
  }) => EventsStatus(
    data: data ?? this.data,
    origin: origin ?? this.origin,
    checkedAt: checkedAt ?? this.checkedAt,
    check: check ?? this.check,
    futureSchema: futureSchema != null ? futureSchema() : this.futureSchema,
    newKeys: newKeys ?? this.newKeys,
  );
}

/// Descarga del repositorio la base de eventos que regenera cada día
/// `.github/workflows/events-data.yml`, la guarda y, sin conexión, usa la
/// última guardada o la que lleva la app. Solo un GET anónimo
/// ([anonymousGet]).
class EventsUpdater {
  EventsUpdater({
    required this.store,
    required this.files,
    Future<String> Function(Uri url)? fetch,
    DateTime Function()? now,
  }) : _fetch = fetch ?? httpGet,
       _now = now ?? DateTime.now;

  static final url = Uri.parse('https://raw.githubusercontent.com/Rodriqe/PKArkTools/main/data/events/events.json');

  /// Como mucho una consulta automática cada 24 h.
  static const interval = Duration(hours: 24);
  static const timeout = Duration(seconds: 30);

  /// Hoy ocupa unos 4 MB.
  static const maxBytes = 32 * 1024 * 1024;

  static const keyCheckedAt = 'eventsCheckedAt';
  static const fileJson = 'events.json';
  static const fileSeen = 'events_seen.txt';

  /// Ajustes (fecha de la última consulta).
  final UpdateStore store;

  /// La base descargada y los eventos ya vistos.
  final BlobStore files;
  final Future<String> Function(Uri url) _fetch;
  final DateTime Function() _now;

  static Future<String> httpGet(Uri url) => anonymousGet(url, maxBytes: maxBytes, timeout: timeout);

  Future<EventsStatus> load() async {
    final checked = DateTime.tryParse(await store.read(keyCheckedAt) ?? '');
    final builtin = EventData.builtin;
    final cached = await files.read(fileJson);
    if (cached != null) {
      try {
        final d = EventData.parse(cached);
        if (d.isNewerThan(builtin)) return EventsStatus(data: d, origin: EventsOrigin.cache, checkedAt: checked);
      } on EventDataException {
        // Una copia guardada que ya no vale se ignora.
      }
    }
    return EventsStatus(data: builtin, origin: EventsOrigin.builtin, checkedAt: checked);
  }

  bool due(EventsStatus s) {
    final c = s.checkedAt;
    if (c == null) return true;
    final age = _now().difference(c);
    return age >= interval || age.isNegative;
  }

  /// Consulta GitHub. Nunca lanza.
  Future<EventsStatus> check(EventsStatus current) async {
    final now = _now();
    await store.write(keyCheckedAt, now.toUtc().toIso8601String());
    final String text;
    try {
      text = await _fetch(url).timeout(timeout * 2);
    } catch (_) {
      return current.copyWith(checkedAt: now, check: EventsCheck.failed);
    }
    final EventData d;
    try {
      d = EventData.parse(text);
    } on EventDataException catch (e) {
      final future = e.futureSchema;
      return current.copyWith(
        checkedAt: now,
        check: future != null ? EventsCheck.upToDate : EventsCheck.failed,
        futureSchema: future != null ? () => future : null,
      );
    }
    if (!d.isNewerThan(current.data)) {
      return current.copyWith(checkedAt: now, check: EventsCheck.upToDate, futureSchema: () => null);
    }
    await files.write(fileJson, text);
    return current.copyWith(data: d, origin: EventsOrigin.downloaded, checkedAt: now, check: EventsCheck.updated);
  }

  /// Marca como vistos los eventos de [s] y devuelve los que son nuevos
  /// respecto a la vista anterior (la primera vez, ninguno).
  Future<Set<String>> markSeen(EventsStatus s, {Set<String> alreadyNew = const {}}) async {
    final keys = {for (final g in s.data.gifts) g.key};
    final before = await files.read(fileSeen);
    final seen = before == null ? keys : before.split('\n').toSet();
    await files.write(fileSeen, (keys.toList()..sort()).join('\n'));
    return {...alreadyNew.intersection(keys), ...keys.difference(seen)};
  }
}

/// Sustituible en los tests.
final eventsUpdaterProvider = Provider<EventsUpdater>(
  (ref) => EventsUpdater(store: RepositoryUpdateStore(() => ref.read(arcaRepositoryProvider)), files: FileBlobStore()),
);

/// Base de eventos en uso. Se construye al abrir el explorador de eventos:
/// carga la copia guardada, marca los nuevos desde la última vista y, si
/// toca, consulta GitHub en segundo plano. Aplica la base a [EventDb].
class EventsDataController extends AsyncNotifier<EventsStatus> {
  EventsUpdater get _u => ref.read(eventsUpdaterProvider);
  bool _checking = false;

  @override
  Future<EventsStatus> build() async {
    var s = await _u.load();
    EventDb.use(s.data);
    s = s.copyWith(newKeys: await _u.markSeen(s));
    if (_u.due(s)) unawaited(Future(() => checkNow(silent: true)));
    return s;
  }

  /// «Buscar eventos nuevos» (o la consulta automática si [silent]).
  Future<EventsCheck> checkNow({bool silent = false}) async {
    final cur = state.value ?? await future;
    if (_checking) return EventsCheck.none;
    _checking = true;
    try {
      var s = await _u.check(cur);
      if (s.check == EventsCheck.updated) s = s.copyWith(newKeys: await _u.markSeen(s, alreadyNew: cur.newKeys));
      if (!ref.mounted) return s.check;
      EventDb.use(s.data);
      state = AsyncData(silent && s.check == EventsCheck.failed ? s.copyWith(check: EventsCheck.none) : s);
      return s.check;
    } finally {
      _checking = false;
    }
  }
}

final eventsDataProvider = AsyncNotifierProvider<EventsDataController, EventsStatus>(EventsDataController.new);
