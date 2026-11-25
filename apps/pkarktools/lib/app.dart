import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pkcore/pkcore.dart';

import 'data/arca_session.dart';
import 'l10n/app_localizations.dart';
import 'providers.dart';
import 'theme/app_theme.dart';
import 'ui/events/event_explorer.dart';
import 'ui/activity/activity_screen.dart';
import 'ui/arca/arca_screen.dart';
import 'ui/detail/save_detail_screen.dart';
import 'ui/dex/dex_progress_screen.dart';
import 'ui/dex/dex_screen.dart';
import 'ui/dex/dex_species_screen.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/ribbons/ribbon_hunter_screen.dart';
import 'ui/settings/settings_screen.dart';
import 'ui/shell.dart';
import 'ui/competitive/competitive_screen.dart';
import 'ui/competitive/showdown_screen.dart';
import 'ui/competitive/stats_screen.dart';
import 'ui/tools/champions_screen.dart';

/// Ruta a la que hay que ir según el estado de la carpeta (null = ninguna).
String? setupRedirect(ArcaSetup setup, String location) => switch (setup) {
      SetupNeeded() => location == '/bienvenida' ? null : '/bienvenida',
      SetupAccessLost() => location == '/acceso' ? null : '/acceso',
      SetupReady() => (location == '/bienvenida' || location == '/acceso') ? '/arca' : null,
    };

GoRouter buildRouter({String initialLocation = '/arca', ValueNotifier<ArcaSetup>? setup}) => GoRouter(
      initialLocation: initialLocation,
      refreshListenable: setup,
      redirect: setup == null ? null : (context, state) => setupRedirect(setup.value, state.matchedLocation),
      routes: [
        GoRoute(path: '/bienvenida', builder: (_, _) => const OnboardingScreen()),
        GoRoute(path: '/acceso', builder: (_, _) => const OnboardingScreen(accessLost: true)),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/arca',
                builder: (_, _) => const ArcaScreen(),
                routes: [
                  GoRoute(
                    path: 'save/:id',
                    builder: (_, state) {
                      final q = state.uri.queryParameters;
                      final box = int.tryParse(q['box'] ?? ''), slot = int.tryParse(q['slot'] ?? '');
                      return SaveDetailScreen(
                        key: ValueKey(state.uri.toString()),
                        slotId: int.parse(state.pathParameters['id']!),
                        focus: box != null && slot != null ? (box: box, slot: slot) : null,
                      );
                    },
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/dex',
                builder: (_, _) => const DexScreen(),
                routes: [
                  GoRoute(path: 'progreso', builder: (_, _) => const DexProgressScreen()),
                  // Antes vivía aquí: los enlaces viejos llevan a Competitivo.
                  GoRoute(path: 'formato-oficial', redirect: (_, _) => '/competitivo/formato'),
                  GoRoute(
                    path: 'eventos',
                    builder: (_, state) => EventExplorerScreen(species: int.tryParse(state.uri.queryParameters['especie'] ?? '')),
                  ),
                  GoRoute(
                    path: 'especie/:species',
                    builder: (_, state) => DexSpeciesScreen(
                      species: (int.tryParse(state.pathParameters['species']!) ?? 1).clamp(1, GlobalDex.maxSpecies),
                    ),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/competitivo',
                builder: (_, _) => const CompetitiveScreen(),
                routes: [
                  GoRoute(path: 'formato', builder: (_, _) => const ChampionsScreen()),
                  GoRoute(path: 'estadisticas', builder: (_, _) => const StatsScreen()),
                  GoRoute(path: 'showdown', builder: (_, _) => const ShowdownScreen()),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/cintas',
                builder: (_, _) => const RibbonHunterScreen(),
                routes: [
                  GoRoute(path: 'top', redirect: (_, _) => '/cintas/ranking'),
                  GoRoute(
                    path: 'ranking',
                    builder: (_, _) => const RibbonRankingScreen(),
                    routes: [
                      GoRoute(
                        path: ':total',
                        builder: (_, state) => RibbonTierScreen(
                          key: ValueKey(state.uri.toString()),
                          total: int.tryParse(state.pathParameters['total']!) ?? -1,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'guia/:species',
                    builder: (_, state) => RibbonGuideScreen(
                      key: ValueKey(state.uri.toString()),
                      species: int.tryParse(state.pathParameters['species']!) ?? 1,
                      form: int.tryParse(state.uri.queryParameters['forma'] ?? '') ?? 0,
                    ),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/actividad', builder: (_, _) => const ActivityScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/ajustes', builder: (_, _) => const SettingsScreen()),
            ]),
          ],
        ),
      ],
    );

class PKArkToolsApp extends ConsumerStatefulWidget {
  const PKArkToolsApp({super.key, this.initialLocation = '/arca'});
  final String initialLocation;

  @override
  ConsumerState<PKArkToolsApp> createState() => _PKArkToolsAppState();
}

class _PKArkToolsAppState extends ConsumerState<PKArkToolsApp> {
  late final ValueNotifier<ArcaSetup> _setup = ValueNotifier(ref.read(arcaSetupProvider));
  late final GoRouter _router = buildRouter(initialLocation: widget.initialLocation, setup: _setup);
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Al volver a primer plano: reindexado incremental (otro dispositivo pudo
    // sincronizar copias nuevas mientras tanto).
    // En una carpeta de red además se sondea cada minuto solo mientras la app
    // está en primer plano.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(arcaSetupProvider.notifier).appResumed(),
      onInactive: () => ref.read(arcaSetupProvider.notifier).appPaused(),
      onHide: () => ref.read(arcaSetupProvider.notifier).appPaused(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    _setup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(arcaSetupProvider, (_, next) => _setup.value = next);
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Español por defecto si el idioma del sistema no está soportado.
      localeResolutionCallback: (locale, supported) =>
          supported.firstWhere((s) => s.languageCode == locale?.languageCode, orElse: () => const Locale('es')),
      routerConfig: _router,
    );
  }
}
