import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/arca_session.dart';
import 'l10n/app_localizations.dart';
import 'providers.dart';
import 'theme/app_theme.dart';
import 'ui/activity/activity_screen.dart';
import 'ui/arca/arca_screen.dart';
import 'ui/detail/save_detail_screen.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/settings/settings_screen.dart';
import 'ui/shell.dart';

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
                    builder: (_, state) => SaveDetailScreen(slotId: int.parse(state.pathParameters['id']!)),
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
