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

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Punto en Ajustes cuando hay una versión nueva de la que avisar.
    final update = ref.watch(updateNoticeProvider.select((n) => n.available != null));
    Widget dot(int i, IconData icon) => i == 3 && update ? Badge(smallSize: 8, child: Icon(icon)) : Icon(icon);
    final destinations = [
      (Icons.inventory_2_outlined, Icons.inventory_2_rounded, l10n.navArca),
      (Icons.catching_pokemon_outlined, Icons.catching_pokemon_rounded, l10n.navDex),
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
                padding: const EdgeInsets.only(top: 20, bottom: 28),
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
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          destinations: [
            for (final (i, (icon, sel, label)) in destinations.indexed)
              NavigationDestination(icon: dot(i, icon), selectedIcon: dot(i, sel), label: label),
          ],
        ),
      );
    }));
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.extended});
  final bool extended;

  @override
  Widget build(BuildContext context) {
    const mark = BrandMark(size: 40);
    if (!extended) return mark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      mark,
      const SizedBox(width: 12),
      Text('PKArkTools', style: context.text.titleLarge!.copyWith(fontFamily: AppTheme.display)),
      const SizedBox(width: 16),
    ]);
  }
}
