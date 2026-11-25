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
            _ScrollableRail(
              extended: extended,
              selectedIndex: shell.currentIndex,
              header: Padding(
                padding: EdgeInsets.only(top: 20, bottom: extended ? 28 : 20),
                child: _Logo(extended: extended),
              ),
              rail: NavigationRail(
                extended: extended,
                minExtendedWidth: 220,
                selectedIndex: shell.currentIndex,
                onDestinationSelected: _go,
                labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                destinations: [
                  for (final (i, (icon, sel, label)) in destinations.indexed)
                    NavigationRailDestination(
                      icon: dot(i, icon),
                      // Ancla para desplazar la lista hasta el destino elegido.
                      selectedIcon: i == shell.currentIndex
                          ? KeyedSubtree(key: _ScrollableRail.selectedKey, child: dot(i, sel))
                          : dot(i, sel),
                      label: Text(label),
                    ),
                ],
              ),
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

/// Barra lateral con el logo fijo arriba y la lista de secciones debajo, que
/// se desplaza cuando no cabe (teléfonos en horizontal, como el AYN Odin3):
/// así Ajustes, con el botón de actualizar, siempre se puede alcanzar. Cuando
/// cabe, se ve igual que un `NavigationRail` normal con el logo de `leading`.
class _ScrollableRail extends StatefulWidget {
  const _ScrollableRail({
    required this.extended,
    required this.header,
    required this.rail,
    required this.selectedIndex,
  });
  final bool extended;
  final Widget header;
  final NavigationRail rail;
  final int selectedIndex;

  /// Envuelve el icono del destino seleccionado (solo hay uno a la vez).
  static final selectedKey = GlobalKey(debugLabel: 'rail-selected');

  @override
  State<_ScrollableRail> createState() => _ScrollableRailState();
}

class _ScrollableRailState extends State<_ScrollableRail> {
  final _controller = ScrollController();

  /// Queda lista por debajo: se muestra un degradado sutil al pie.
  final _moreBelow = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateMore);
    _revealSelected(animate: false);
  }

  @override
  void didUpdateWidget(_ScrollableRail old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex || old.extended != widget.extended) _revealSelected(animate: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _moreBelow.dispose();
    super.dispose();
  }

  void _updateMore() {
    _moreBelow.value =
        _controller.hasClients && _controller.position.hasContentDimensions && _controller.position.extentAfter > 0.5;
  }

  /// Lleva a la vista el destino seleccionado si quedó fuera (desplazamiento
  /// mínimo; con margen para la etiqueta que va debajo del icono).
  void _revealSelected({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _ScrollableRail.selectedKey.currentContext?.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        final s = box.size;
        box.showOnScreen(
          rect: Rect.fromLTRB(0, -16, s.width, s.height + 32),
          duration: animate ? const Duration(milliseconds: 200) : Duration.zero,
          curve: Curves.easeOut,
        );
      }
      _updateMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.navigationRailTheme.backgroundColor ?? theme.colorScheme.surface;
    return ColoredBox(
      color: bg,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            widget.header,
            Expanded(
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  _updateMore();
                  return false;
                },
                child: Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, c) => Scrollbar(
                        controller: _controller,
                        thumbVisibility: true,
                        // Sin la barra automática de escritorio (ya hay una).
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                          child: SingleChildScrollView(
                            key: const ValueKey('rail-scroll'),
                            controller: _controller,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: c.maxHeight),
                              child: IntrinsicHeight(child: widget.rail),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _moreBelow,
                          builder: (context, more, _) => AnimatedOpacity(
                            key: const ValueKey('rail-more-fade'),
                            opacity: more ? 1 : 0,
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              height: 24,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [bg.withValues(alpha: 0), bg],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
