import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'common/brand_mark.dart';
import 'common/format.dart';

/// Contenedor adaptativo: rail lateral en pantallas anchas, barra inferior en móvil.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const double railBreakpoint = 720;

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destinations = [
      (Icons.inventory_2_outlined, Icons.inventory_2_rounded, l10n.navArca),
      (Icons.history_rounded, Icons.history_rounded, l10n.navActivity),
      (Icons.tune_outlined, Icons.tune_rounded, l10n.navSettings),
    ];
    return LayoutBuilder(builder: (context, c) {
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
                for (final (icon, sel, label) in destinations)
                  NavigationRailDestination(icon: Icon(icon), selectedIcon: Icon(sel), label: Text(label)),
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
            for (final (icon, sel, label) in destinations)
              NavigationDestination(icon: Icon(icon), selectedIcon: Icon(sel), label: label),
          ],
        ),
      );
    });
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
