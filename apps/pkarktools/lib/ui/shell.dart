import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/update/update_notice.dart';
import '../theme/app_theme.dart';
import 'common/brand_mark.dart';
import 'common/format.dart';
import 'settings/game_folders.dart';

/// Contenedor adaptativo: rail lateral en pantallas anchas, barra inferior en móvil.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const double railBreakpoint = 720;

  /// Ramas del router (orden de `buildRouter`).
  static const arca = 0, dex = 1, competitive = 2, ribbons = 3, activity = 4, settings = 5;

  /// Entradas de la barra inferior del teléfono: seis no caben a 320 px con
  /// las etiquetas en español, así que Actividad se abre desde la cabecera del
  /// Arca (y en la barra se resalta el Arca mientras se ve).
  static const phoneBranches = [arca, dex, competitive, ribbons, settings];

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Punto en Ajustes cuando hay una versión nueva de la que avisar.
    final update = ref.watch(updateNoticeProvider.select((n) => n.available != null));
    Widget dot(int i, IconData icon) => i == settings && update ? Badge(smallSize: 8, child: Icon(icon)) : Icon(icon);
    final destinations = [
      (Icons.inventory_2_outlined, Icons.inventory_2_rounded, l10n.navArca),
      (Icons.catching_pokemon_outlined, Icons.catching_pokemon_rounded, l10n.navDex),
      (Icons.emoji_events_outlined, Icons.emoji_events_rounded, l10n.navCompetitive),
      (Icons.military_tech_outlined, Icons.military_tech_rounded, l10n.navRibbonHunter),
      (Icons.history_rounded, Icons.history_rounded, l10n.navActivity),
      (Icons.tune_outlined, Icons.tune_rounded, l10n.navSettings),
    ];
    return ArcaEventsHost(child: LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= railBreakpoint) {
        final extended = c.maxWidth >= 1280;
        return Scaffold(
          body: Row(children: [
            NavigationRail(
              extended: extended,
              minExtendedWidth: 220,
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              leading: Padding(
                padding: EdgeInsets.only(top: 20, bottom: extended ? 28 : 20),
                child: _Logo(extended: extended),
              ),
              destinations: [
                for (final (i, (icon, sel, label)) in destinations.indexed)
                  NavigationRailDestination(icon: dot(i, icon), selectedIcon: dot(i, sel), label: Text(label)),
              ],
            ),
            VerticalDivider(width: 1, color: context.tokens.hairline),
            Expanded(child: shell),
          ]),
        );
      }
      final current = shell.currentIndex == activity ? arca : shell.currentIndex;
      String short(int i, String label) => switch (i) {
            ribbons => l10n.navRibbonsShort,
            competitive => l10n.navCompetitiveShort,
            _ => label,
          };
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: phoneBranches.indexOf(current),
          onDestinationSelected: (i) => _go(phoneBranches[i]),
          destinations: [
            for (final i in phoneBranches)
              NavigationDestination(
                key: ValueKey('nav-$i'),
                icon: dot(i, destinations[i].$1),
                selectedIcon: dot(i, destinations[i].$2),
                label: short(i, destinations[i].$3),
                tooltip: destinations[i].$3,
              ),
          ],
        ),
      );
    }));
  }
}

/// Cabecera de la barra lateral: el logo ocupa el ancho útil del rail y el
/// nombre va debajo (en el rail compacto, en letra pequeña y ajustado al ancho).
class _Logo extends StatelessWidget {
  const _Logo({required this.extended});
  final bool extended;

  /// Alto del logo en el rail extendido (≥ 1280 px) y en el compacto.
  static const double extendedHeight = 96;
  static const double compactHeight = 72;

  @override
  Widget build(BuildContext context) {
    final name = Text(
      'PKArkTools',
      key: const ValueKey('rail-logo-name'),
      maxLines: 1,
      softWrap: false,
      style: extended
          ? context.text.titleLarge!.copyWith(fontFamily: AppTheme.display, fontWeight: FontWeight.w700)
          : context.text.labelMedium!.copyWith(fontFamily: AppTheme.display, fontWeight: FontWeight.w700),
    );
    return SizedBox(
      key: const ValueKey('rail-logo'),
      // Ancho útil: el del rail (220 extendido, 80 compacto) menos el margen.
      width: extended ? 196 : 76,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        BrandMark(size: extended ? extendedHeight : compactHeight),
        SizedBox(height: extended ? 10 : 6),
        FittedBox(fit: BoxFit.scaleDown, child: name),
      ]),
    );
  }
}
