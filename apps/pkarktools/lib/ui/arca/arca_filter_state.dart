import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/arca_repository.dart';
import '../../data/db/arca_database.dart' show Snapshot;
import '../../providers.dart';
import 'arca_filter.dart';

/// Filtros y orden de la pestaña Arca. Se recuerdan en los ajustes locales
/// de este dispositivo (el índice), nunca en la carpeta del Arca.
class ArcaFilterNotifier extends Notifier<ArcaFilter> {
  static const settingKey = 'arcaFilter';

  ArcaRepository get _repo => ref.read(arcaRepositoryProvider);
  bool _touched = false;

  @override
  ArcaFilter build() {
    _load();
    return ArcaFilter.none;
  }

  Future<void> _load() async {
    try {
      final saved = ArcaFilter.fromJson(await _repo.getJsonSetting(settingKey));
      // Si el usuario ya tocó algo mientras se cargaba, gana lo suyo.
      if (!_touched) state = saved.copyWith(query: state.query);
    } catch (_) {
      // Sin ajustes legibles: filtros por defecto.
    }
  }

  void set(ArcaFilter f) {
    _touched = true;
    final persist = f.toJson().toString() != state.toJson().toString();
    state = f;
    if (persist) unawaited(_repo.setJsonSetting(settingKey, f.toJson()).catchError((_) {}));
  }

  void update(ArcaFilter Function(ArcaFilter f) change) => set(change(state));
}

final arcaFilterProvider = NotifierProvider<ArcaFilterNotifier, ArcaFilter>(ArcaFilterNotifier.new);

/// Avisos de legalidad por id de copia, calculados bajo demanda (solo cuando
/// se filtra por legalidad) y de uno en uno en otro isolate.
class LegalityScan {
  const LegalityScan(this.warnings, {this.pending = 0, this.total = 0});
  final Map<int, int> warnings;
  final int pending;
  final int total;
  bool get running => pending > 0;
}

class LegalityScanNotifier extends Notifier<LegalityScan> {
  final _queue = <Snapshot>[];
  bool _busy = false;

  @override
  LegalityScan build() => const LegalityScan({});

  /// Encola las copias que aún no se han revisado.
  void ensure(Iterable<Snapshot> snaps) {
    final known = state.warnings.keys.toSet()..addAll(_queue.map((s) => s.id));
    final add = [for (final s in snaps) if (!known.contains(s.id)) s];
    if (add.isEmpty) return;
    _queue.addAll(add);
    state = LegalityScan(state.warnings, pending: _queue.length, total: state.warnings.length + _queue.length);
    if (!_busy) unawaited(_run());
  }

  Future<void> _run() async {
    _busy = true;
    final repo = ref.read(arcaRepositoryProvider);
    while (_queue.isNotEmpty) {
      final s = _queue.first;
      int n;
      try {
        n = await repo.legalityWarnings(s);
      } catch (_) {
        n = 0;
      }
      if (!ref.mounted) return;
      _queue.removeAt(0);
      state = LegalityScan({...state.warnings, s.id: n}, pending: _queue.length, total: state.total);
    }
    _busy = false;
  }
}

final legalityScanProvider = NotifierProvider<LegalityScanNotifier, LegalityScan>(LegalityScanNotifier.new);
