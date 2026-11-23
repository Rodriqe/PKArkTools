import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../import/import_flow.dart';
import 'arca_filter.dart';
import 'arca_filter_state.dart';
import 'arca_filters_ui.dart';
import 'save_card.dart';

class ArcaScreen extends ConsumerStatefulWidget {
  const ArcaScreen({super.key});

  @override
  ConsumerState<ArcaScreen> createState() => _ArcaScreenState();
}

class _ArcaScreenState extends ConsumerState<ArcaScreen> {
  final _search = TextEditingController();

  /// El botón flotante se contrae a icono al desplazarse hacia abajo.
  bool _fabExtended = true;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(arcaFilterProvider).query;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _onScroll(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final extended = switch (n.direction) {
      ScrollDirection.reverse => false,
      ScrollDirection.forward => true,
      ScrollDirection.idle => n.metrics.pixels <= n.metrics.minScrollExtent + 8 ? true : _fabExtended,
    };
    if (extended != _fabExtended) setState(() => _fabExtended = extended);
    return false;
  }

  void _clearAll() {
    _search.clear();
    ref.read(arcaFilterProvider.notifier).update((f) => f.cleared());
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(arcaEntriesProvider);
    final filter = ref.watch(arcaFilterProvider);
    final scan = ref.watch(legalityScanProvider);
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final sidePanel = width >= 1100;
    final pad = compact ? 16.0 : 32.0;

    return Scaffold(
      floatingActionButton: compact
          ? FloatingActionButton.extended(
              onPressed: () => showImportChooser(context, ref),
              tooltip: _fabExtended ? null : l10n.importAction,
              isExtended: _fabExtended,
              icon: const Icon(Icons.add_rounded),
              label: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Text(l10n.importAction),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: entries.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (all) {
            if (all.isEmpty) return _EmptyArca(onImport: () => showImportChooser(context, ref));
            if (filter.statuses.contains(ArcaStatus.legality)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) ref.read(legalityScanProvider.notifier).ensure(all.map((e) => e.latest));
              });
            }
            final list = filter.apply(
              all,
              now: DateTime.now(),
              titleOf: (e) => gameTitle(context, e.game, e.slot.versionId),
              warnings: scan.warnings,
            );
            final scanning = filter.statuses.contains(ArcaStatus.legality) && scan.running;
            final scroll = NotificationListener<UserScrollNotification>(
              onNotification: _onScroll,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, compact ? 20 : 36, pad, 0),
                    sliver: SliverToBoxAdapter(
                      child: _Header(
                        count: all.length,
                        shown: filter.isActive ? list.length : null,
                        compact: compact,
                        search: _search,
                        onImport: () => showImportChooser(context, ref),
                        onSearch: (v) => ref.read(arcaFilterProvider.notifier).update((f) => f.copyWith(query: v)),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(compact ? 0 : pad, 14, compact ? 0 : pad, 0),
                    sliver: SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: compact ? pad : 0),
                        child: ArcaFilterBar(all: all, showFiltersButton: !sidePanel),
                      ),
                    ),
                  ),
                  if (scanning)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
                      sliver: SliverToBoxAdapter(child: LegalityProgress(scan: scan)),
                    ),
                  if (list.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _NoMatches(query: filter.query.trim(), onClear: _clearAll),
                    )
                  else
                    SliverPadding(
                      // Hueco bajo la última tarjeta: el botón flotante nunca la tapa.
                      padding: EdgeInsets.fromLTRB(pad, 16, pad, compact ? 136 : 112),
                      sliver: SliverGrid.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          mainAxisExtent: 268,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, i) => SaveCard(
                          key: ValueKey(list[i].slot.id),
                          entry: list[i],
                          onOpen: () => context.go('/arca/save/${list[i].slot.id}'),
                        ),
                      ),
                    ),
                ],
              ),
            );
            if (!sidePanel) return scroll;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 300,
                  margin: const EdgeInsets.fromLTRB(20, 28, 0, 20),
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: context.tokens.raised,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.tokens.hairline),
                  ),
                  child: const ArcaFilterPanel(key: Key('arca-side-panel')),
                ),
                Expanded(child: scroll),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.shown,
    required this.compact,
    required this.search,
    required this.onImport,
    required this.onSearch,
  });
  final int count;

  /// Partidas que pasan los filtros (null = sin filtros).
  final int? shown;
  final bool compact;
  final TextEditingController search;
  final VoidCallback onImport;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final field = SizedBox(
      width: compact ? double.infinity : 300,
      child: TextField(
        controller: search,
        onChanged: onSearch,
        decoration: InputDecoration(
          hintText: l10n.searchHint,
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: context.tokens.sunken,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
    );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.arcaTitle, style: compact ? context.text.displaySmall : context.text.displayMedium),
        const SizedBox(height: 6),
        Text(
          shown == null ? l10n.arcaSubtitle(count) : l10n.filtersResults(shown!, count),
          key: const Key('arca-count'),
          style: context.text.bodyLarge!.copyWith(color: context.tokens.muted),
        ),
      ],
    );
    if (compact) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 18), field]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: title),
        Flexible(child: field),
        const SizedBox(width: 12),
        FilledButton.icon(onPressed: onImport, icon: const Icon(Icons.add_rounded), label: Text(l10n.importAction)),
      ],
    );
  }
}

/// Estado vacío cuando la búsqueda o los filtros no dejan ninguna partida.
class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query, required this.onClear});
  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: context.tokens.sunken, shape: BoxShape.circle),
                child: Icon(Icons.filter_alt_off_outlined, size: 34, color: context.tokens.muted),
              ),
              const SizedBox(height: 18),
              Text(l10n.filtersNoMatchTitle, style: context.text.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                query.isEmpty ? l10n.filtersNoMatchBody : '${l10n.noResults(query)}. ${l10n.filtersNoMatchBody}',
                style: context.text.bodyMedium!.copyWith(color: context.tokens.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.tonalIcon(
                key: const Key('arca-no-match-clear'),
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: Text(l10n.filtersClearAll),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyArca extends ConsumerWidget {
  const _EmptyArca({required this.onImport});
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StackedCartridges(color: context.colors.primary, tokens: tokens),
              const SizedBox(height: 32),
              Text(l10n.emptyTitle, style: context.text.displaySmall),
              const SizedBox(height: 12),
              Text(l10n.emptyBody, style: context.text.bodyLarge!.copyWith(color: tokens.muted)),
              const SizedBox(height: 28),
              Wrap(spacing: 12, runSpacing: 12, children: [
                FilledButton.icon(onPressed: onImport, icon: const Icon(Icons.add_rounded), label: Text(l10n.importAction)),
                OutlinedButton(onPressed: () => loadDemo(context, ref), child: Text(l10n.loadDemo)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ilustración del estado vacío: tres siluetas de cartucho apiladas.
class _StackedCartridges extends StatelessWidget {
  const _StackedCartridges({required this.color, required this.tokens});
  final Color color;
  final ArcaTokens tokens;

  @override
  Widget build(BuildContext context) {
    Widget cart(double dx, double angle, double alpha) => Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: 96,
              height: 112,
              decoration: ShapeDecoration(
                color: Color.lerp(tokens.raised, color, alpha),
                shape: _NotchShape(),
              ),
            ),
          ),
        );
    return SizedBox(
      height: 124,
      width: 220,
      child: Stack(alignment: Alignment.centerLeft, children: [
        cart(92, 0.14, 0.10),
        cart(46, 0.05, 0.22),
        cart(0, -0.06, 0.85),
      ]),
    );
  }
}

class _NotchShape extends ShapeBorder {
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  Path _p(Rect r) => Path()
    ..moveTo(r.left + 14, r.top)
    ..lineTo(r.right - 22, r.top)
    ..lineTo(r.right, r.top + 22)
    ..lineTo(r.right, r.bottom - 14)
    ..quadraticBezierTo(r.right, r.bottom, r.right - 14, r.bottom)
    ..lineTo(r.left + 14, r.bottom)
    ..quadraticBezierTo(r.left, r.bottom, r.left, r.bottom - 14)
    ..lineTo(r.left, r.top + 14)
    ..quadraticBezierTo(r.left, r.top, r.left + 14, r.top)
    ..close();
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _p(rect);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _p(rect);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
  @override
  ShapeBorder scale(double t) => this;
}
