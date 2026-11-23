import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pkcore/pkcore.dart';

import 'data/arca_repository.dart';
import 'data/arca_session.dart';
import 'data/db/arca_database.dart';
import 'data/file_sources.dart';
import 'data/folder/arca_layout.dart';

export 'data/arca_session.dart'
    show arcaRepositoryProvider, arcaSetupProvider, folderAccessProvider, legacyArcaProvider, initialArcaSetupProvider, reindexReportProvider;

final fileSourcesProvider = Provider<FileSources>((ref) => const FileSources());

/// Abre el índice local (drift) en el soporte de la app: nunca dentro de la
/// carpeta sincronizada. Es reconstruible desde la carpeta.
Future<ArcaDatabase> openIndexDatabase() async {
  final support = await getApplicationSupportDirectory();
  final dir = Directory(p.join(support.path, ArcaLayout.rootDir, 'indice'));
  await dir.create(recursive: true);
  return ArcaDatabase(driftDatabase(
    name: 'arca_indice',
    native: DriftNativeOptions(databaseDirectory: () async => dir),
  ));
}

/// Arca interna de versiones anteriores, en `Documentos/PKArkTools/arca`.
Future<LegacyArca> legacyArcaLocation() async {
  final docs = await getApplicationDocumentsDirectory();
  return LegacyArca(Directory(p.join(docs.path, ArcaLayout.rootDir, 'arca')));
}

final arcaEntriesProvider = StreamProvider<List<ArcaEntry>>((ref) => ref.watch(arcaRepositoryProvider).watchArca());

final slotProvider = StreamProvider.family<SaveSlot?, int>((ref, id) => ref.watch(arcaRepositoryProvider).watchSlot(id));

final snapshotsProvider =
    StreamProvider.family<List<Snapshot>, int>((ref, slotId) => ref.watch(arcaRepositoryProvider).watchSnapshots(slotId));

final activityProvider = StreamProvider<List<ActivityItem>>((ref) => ref.watch(arcaRepositoryProvider).watchActivity());

/// Save parseado de un snapshot (en un isolate).
final parsedSnapshotProvider =
    FutureProvider.family<SaveFile, int>((ref, snapshotId) => ref.watch(arcaRepositoryProvider).parseSnapshot(snapshotId));

// ---------------------------------------------------------------- Dex global

/// Dex global: cruza la copia más reciente de cada partida. Se recalcula
/// cuando cambia el Arca (desde la caché de escaneos: milisegundos).
final globalDexProvider = FutureProvider<GlobalDex>((ref) async {
  final entries = await ref.watch(arcaEntriesProvider.future);
  return ref.watch(arcaRepositoryProvider).dex.build(entries);
});

/// Modo living dex (Ajustes de la Dex): «capturado» solo si hay ejemplar en
/// cajas o equipo. Se guarda en las preferencias de este dispositivo.
class DexLivingNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final v = await ref.read(arcaRepositoryProvider).getSetting('dexLiving');
    if (v == '1' && !state) state = true;
  }

  Future<void> set(bool value) async {
    state = value;
    await ref.read(arcaRepositoryProvider).setSetting('dexLiving', value ? '1' : '0');
  }
}

final dexLivingProvider = NotifierProvider<DexLivingNotifier, bool>(DexLivingNotifier.new);

/// Filtros de la cuadrícula de la Dex (en memoria; el modo living viene de
/// [dexLivingProvider]).
class DexFilterNotifier extends Notifier<DexFilter> {
  @override
  DexFilter build() => const DexFilter();

  void update(DexFilter Function(DexFilter) f) => state = f(state);
  void clear() => state = state.cleared();
}

final dexFilterProvider = NotifierProvider<DexFilterNotifier, DexFilter>(DexFilterNotifier.new);

// ---------------------------------------------------------------- ajustes

class AppSettings {
  const AppSettings({this.themeMode = ThemeMode.dark, this.locale});
  final ThemeMode themeMode;

  /// null = idioma del sistema (con español como predeterminado).
  final Locale? locale;

  AppSettings copyWith({ThemeMode? themeMode, Locale? Function()? locale}) =>
      AppSettings(themeMode: themeMode ?? this.themeMode, locale: locale != null ? locale() : this.locale);
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  ArcaRepository get _repo => ref.read(arcaRepositoryProvider);

  Future<void> _load() async {
    final theme = await _repo.getSetting('themeMode');
    final lang = await _repo.getSetting('locale');
    state = AppSettings(
      themeMode: ThemeMode.values.firstWhere((m) => m.name == theme, orElse: () => ThemeMode.dark),
      locale: (lang == null || lang.isEmpty) ? null : Locale(lang),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _repo.setSetting('themeMode', mode.name);
  }

  Future<void> setLocale(Locale? locale) async {
    state = state.copyWith(locale: () => locale);
    await _repo.setSetting('locale', locale?.languageCode ?? '');
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
