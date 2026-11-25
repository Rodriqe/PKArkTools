import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../arca_session.dart' show arcaRepositoryProvider;
import 'anonymous_get.dart';
import 'app_update.dart' show UpdateStore;
import 'update_notice.dart' show RepositoryUpdateStore;

/// De dónde salen los datos del formato oficial que se están usando.
enum ChampionsOrigin { builtin, cache, downloaded }

/// Resultado de la última consulta.
enum ChampionsCheck { none, updated, upToDate, failed }

@immutable
class ChampionsStatus {
  const ChampionsStatus({
    required this.data,
    required this.origin,
    this.checkedAt,
    this.check = ChampionsCheck.none,
    this.futureSchema,
  });

  final ChampionsData data;
  final ChampionsOrigin origin;

  /// Última vez que se consultó GitHub (con o sin éxito).
  final DateTime? checkedAt;
  final ChampionsCheck check;

  /// Hay datos con un `schemaVersion` que esta versión de la app no entiende:
  /// se ignoran y se sugiere actualizar la app.
  final int? futureSchema;

  ChampionsStatus copyWith({
    ChampionsData? data,
    ChampionsOrigin? origin,
    DateTime? checkedAt,
    ChampionsCheck? check,
    int? Function()? futureSchema,
  }) => ChampionsStatus(
    data: data ?? this.data,
    origin: origin ?? this.origin,
    checkedAt: checkedAt ?? this.checkedAt,
    check: check ?? this.check,
    futureSchema: futureSchema != null ? futureSchema() : this.futureSchema,
  );
}

/// Descarga del repositorio los datos del formato oficial que regenera cada
/// día `.github/workflows/champions-data.yml`, los guarda en el índice local
/// y, sin conexión, usa la última copia guardada o la que lleva la app.
///
/// Solo hace un GET anónimo: sin cabeceras propias ni identificadores (ni
/// siquiera la versión de la app en el User-Agent).
class ChampionsUpdater {
  ChampionsUpdater({required this.store, Future<String> Function(Uri url)? fetch, DateTime Function()? now})
    : _fetch = fetch ?? httpGet,
      _now = now ?? DateTime.now;

  static final url = Uri.parse(
    'https://raw.githubusercontent.com/Rodriqe/PKArkTools/main/data/champions/champions.json',
  );

  /// Como mucho una consulta automática cada 12 h.
  static const interval = Duration(hours: 12);
  static const timeout = Duration(seconds: 10);

  /// Un JSON de la regulación ocupa unos 7 KB.
  static const maxBytes = 512 * 1024;

  static const keyJson = 'championsJson';
  static const keyCheckedAt = 'championsCheckedAt';

  final UpdateStore store;
  final Future<String> Function(Uri url) _fetch;
  final DateTime Function() _now;

  /// La copia guardada si es válida y más reciente que la integrada; si no,
  /// la integrada.
  Future<ChampionsStatus> load() async {
    final checked = DateTime.tryParse(await store.read(keyCheckedAt) ?? '');
    final builtin = ChampionsData.builtin;
    final cached = await store.read(keyJson);
    if (cached != null) {
      try {
        final d = ChampionsData.parse(cached);
        if (d.isNewerThan(builtin)) {
          return ChampionsStatus(data: d, origin: ChampionsOrigin.cache, checkedAt: checked);
        }
      } on ChampionsDataException {
        // Una copia guardada que ya no vale se ignora.
      }
    }
    return ChampionsStatus(data: builtin, origin: ChampionsOrigin.builtin, checkedAt: checked);
  }

  /// ¿Toca consultar? (máximo una vez cada [interval]).
  bool due(ChampionsStatus s) {
    final c = s.checkedAt;
    if (c == null) return true;
    final age = _now().difference(c);
    return age >= interval || age.isNegative;
  }

  /// Consulta GitHub. Nunca lanza: si falla, devuelve [current] con
  /// [ChampionsCheck.failed].
  Future<ChampionsStatus> check(ChampionsStatus current) async {
    final now = _now();
    await store.write(keyCheckedAt, now.toUtc().toIso8601String());
    final String text;
    try {
      text = await _fetch(url).timeout(timeout);
    } catch (_) {
      return current.copyWith(checkedAt: now, check: ChampionsCheck.failed);
    }
    final ChampionsData d;
    try {
      d = ChampionsData.parse(text);
    } on ChampionsDataException catch (e) {
      final future = e.futureSchema;
      return current.copyWith(
        checkedAt: now,
        check: future != null ? ChampionsCheck.upToDate : ChampionsCheck.failed,
        futureSchema: future != null ? () => future : null,
      );
    }
    if (!d.isNewerThan(current.data)) {
      return current.copyWith(checkedAt: now, check: ChampionsCheck.upToDate, futureSchema: () => null);
    }
    await store.write(keyJson, text);
    return ChampionsStatus(data: d, origin: ChampionsOrigin.downloaded, checkedAt: now, check: ChampionsCheck.updated);
  }

  static Future<String> httpGet(Uri url) => anonymousGet(url, maxBytes: maxBytes, timeout: timeout);
}

/// Sustituible en los tests.
final championsUpdaterProvider = Provider<ChampionsUpdater>(
  (ref) => ChampionsUpdater(store: RepositoryUpdateStore(() => ref.read(arcaRepositoryProvider))),
);

/// Datos del formato oficial en uso. Al construirse (al abrir «Formato
/// oficial») carga la copia guardada y, si toca, consulta GitHub en segundo
/// plano. Aplica los datos a [ChampionsFormat].
class ChampionsDataController extends AsyncNotifier<ChampionsStatus> {
  ChampionsUpdater get _u => ref.read(championsUpdaterProvider);
  bool _checking = false;

  @override
  Future<ChampionsStatus> build() async {
    final s = await _u.load();
    ChampionsFormat.use(s.data);
    if (_u.due(s)) unawaited(Future(() => checkNow(silent: true)));
    return s;
  }

  /// «Buscar actualizaciones» (o la consulta automática si [silent]).
  Future<ChampionsCheck> checkNow({bool silent = false}) async {
    final cur = state.value ?? await future;
    if (_checking) return ChampionsCheck.none;
    _checking = true;
    try {
      final s = await _u.check(cur);
      if (!ref.mounted) return s.check;
      ChampionsFormat.use(s.data);
      state = AsyncData(silent && s.check == ChampionsCheck.failed ? s.copyWith(check: ChampionsCheck.none) : s);
      return s.check;
    } finally {
      _checking = false;
    }
  }
}

final championsDataProvider = AsyncNotifierProvider<ChampionsDataController, ChampionsStatus>(
  ChampionsDataController.new,
);
