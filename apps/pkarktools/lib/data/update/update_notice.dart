import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../arca_repository.dart';
import '../arca_session.dart' show arcaRepositoryProvider;
import 'app_update.dart';

/// Guarda lo del comprobador en la tabla de ajustes del índice local (nunca en
/// la carpeta del Arca). Si el índice no está disponible, no guarda nada.
class RepositoryUpdateStore implements UpdateStore {
  RepositoryUpdateStore(this._repo);
  final ArcaRepository Function() _repo;

  @override
  Future<String?> read(String key) async {
    try {
      return await _repo().getSetting(key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _repo().setSetting(key, value);
    } catch (_) {}
  }
}

/// Buscar e instalar versiones nuevas (sustituible en los tests).
final appUpdaterProvider = Provider<AppUpdater>(
  (ref) => AppUpdater.forCurrentPlatform(store: RepositoryUpdateStore(() => ref.read(arcaRepositoryProvider))),
);

/// Estado del aviso de actualización.
class UpdateNotice {
  const UpdateNotice({this.available, this.autoCheck = true});

  /// Versión nueva de la que avisar (punto en Ajustes y tarjeta); `null` si
  /// no hay o el usuario la omitió.
  final ReleaseInfo? available;

  /// «Buscar actualizaciones automáticamente».
  final bool autoCheck;

  UpdateNotice copyWith({ReleaseInfo? Function()? available, bool? autoCheck}) =>
      UpdateNotice(available: available != null ? available() : this.available, autoCheck: autoCheck ?? this.autoCheck);
}

class UpdateNoticeController extends Notifier<UpdateNotice> {
  AppUpdater get _u => ref.read(appUpdaterProvider);

  @override
  UpdateNotice build() => const UpdateNotice();

  /// Al abrir la app: limpia descargas viejas y, si toca (máximo una consulta
  /// cada 24 h), busca en silencio.
  Future<void> startup() async {
    final u = _u;
    if (u.canInstallInApp) await u.cleanDownloads();
    final auto = await u.autoCheckEnabled();
    state = state.copyWith(autoCheck: auto);
    final r = await u.autoCheck();
    if (r != null) state = state.copyWith(available: () => r);
  }

  /// «Buscar actualizaciones»: consulta ya (lanza [UpdateException] con un
  /// motivo que se enseña). Una versión nueva se ofrece aunque se omitiera.
  Future<ReleaseInfo?> checkNow() async {
    final r = await _u.latest();
    state = state.copyWith(available: () => r != null && r.isNewer ? r : null);
    return r;
  }

  /// «Omitir esta versión»: no vuelve a avisar de ella (sí de las siguientes).
  Future<void> skip(ReleaseInfo r) async {
    state = state.copyWith(available: () => null);
    await _u.skip(r.version);
  }

  Future<void> setAutoCheck(bool on) async {
    state = state.copyWith(autoCheck: on);
    await _u.setAutoCheck(on);
  }
}

final updateNoticeProvider = NotifierProvider<UpdateNoticeController, UpdateNotice>(UpdateNoticeController.new);
