import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pkcore/pkcore.dart';

import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/game_palette.dart';
import '../common/adaptive.dart';
import '../common/format.dart';
import 'dex_text.dart';
import 'dex_tile.dart';

/// Pestaña Dex: Pokédex global de todas las partidas del Arca.
class DexScreen extends ConsumerStatefulWidget {
  const DexScreen({super.key});

  @override
  ConsumerState<DexScreen> createState() => _DexScreenState();
}

class _DexScreenState extends ConsumerState<DexScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(dexFilterProvider).query;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _update(DexFilter Function(DexFilter) f) => ref.read(dexFilterProvider.notifier).update(f);

  @override
  Widget build(BuildContext context) {
    final dexAsync = ref.watch(globalDexProvider);
    final living = ref.watch(dexLivingProvider);
    final filter = ref.watch(dexFilterProvider).copyWith(living: living);
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final pad = compact ? 16.0 : 32.0;
    final dex = dexAsync.value;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: dex == null
                ? (dexAsync.hasError
                    ? Center(child: Text(l10n.loadError('${dexAsync.error}')))
                    : const Center(child: CircularProgressIndicator()))
                : _DexBody(
                    dex: dex,
                    filter: filter,
                    living: living,
                    pad: pad,
                    compact: compact,
                    search: _search,
                    onFilter: _update,
                  ),
          ),
        ),
      ),
    );
  }
}

class _DexBody extends ConsumerWidget {
  const _DexBody({
    required this.dex,
    required this.filter,
    required this.living,
    required this.pad,
    required this.compact,
    required this.search,
    required this.onFilter,
  });

  final GlobalDex dex;
  final DexFilter filter;
  final bool living;
  final double pad;
  final bool compact;
  final TextEditingController search;
  final void Function(DexFilter Function(DexFilter)) onFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final progress = dex.progress;
    final results = dex.filter(filter, lang: context.dexLang);
    final empty = dex.sources.isEmpty;
    final caughtCount = living ? progress.owned : progress.caught;

    return CustomScrollView(
      key: const PageStorageKey('dex-grid'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, compact ? 20 : 36, pad, 4),
          sliver: SliverToBoxAdapter(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.navDex, style: compact ? context.text.displaySmall : context.text.displayMedium),
                  const SizedBox(height: 4),
                  Text(
                    (living ? l10n.dexSubtitleLiving : l10n.dexSubtitle)(
                        '$caughtCount', '${dex.sources.length}', '${progress.total}'),
                    style: context.text.bodyMedium!.copyWith(color: tokens.muted),
                  ),
                ]),
              ),
              IconButton(
                key: const ValueKey('dex-progress'),
                tooltip: l10n.dexProgress,
                onPressed: () => context.go('/dex/progreso'),
                icon: const Icon(Icons.insights_rounded),
              ),
              IconButton(
                key: const ValueKey('dex-settings'),
                tooltip: l10n.dexSettings,
                onPressed: () => showDexSettings(context, ref),
                icon: Badge(isLabelVisible: living, smallSize: 8, child: const Icon(Icons.tune_rounded)),
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 14, pad, 0),
          sliver: SliverToBoxAdapter(
            child: DexStatsRow(progress: progress, living: living, onTap: () => context.go('/dex/progreso')),
          ),
        ),
        if (empty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 18, pad, 0),
            sliver: SliverToBoxAdapter(child: _EmptyNotice()),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 18, pad, 0),
          sliver: SliverToBoxAdapter(
            child: TextField(
              key: const ValueKey('dex-search'),
              controller: search,
              onChanged: (v) => onFilter((f) => f.copyWith(query: v)),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.dexSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.dexClear,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          search.clear();
                          onFilter((f) => f.copyWith(query: ''));
                        },
                      ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
          sliver: SliverToBoxAdapter(child: DexFilterBar(dex: dex, filter: filter, onFilter: onFilter)),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 10, pad, 8),
          sliver: SliverToBoxAdapter(
            child: Row(children: [
              Text(l10n.dexResults(results.length), style: context.text.labelLarge!.copyWith(color: tokens.muted)),
              const Spacer(),
              if (!filter.isDefault)
                TextButton.icon(
                  onPressed: () {
                    search.clear();
                    ref.read(dexFilterProvider.notifier).clear();
                  },
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                  label: Text(l10n.dexClear),
                ),
            ]),
          ),
        ),
        if (results.isEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 24, pad, 0),
            sliver: SliverToBoxAdapter(
              child: Text(l10n.dexNoResults, style: context.text.bodyLarge!.copyWith(color: tokens.muted)),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 120),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: compact ? 96 : 112,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.86,
            ),
            itemCount: results.length,
            itemBuilder: (context, i) {
              final s = results[i];
              final e = dex[s];
              final status = filter.game != null
                  ? dex.statusIn(s, filter.game!, living: living)
                  : (living ? e.livingStatus : e.status);
              return DexTile(
                key: ValueKey('dex-$s'),
                entry: e,
                status: status,
                name: speciesName(context, s),
                shiny: e.shinyOwned,
                onTap: () => context.go('/dex/especie/$s'),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.raised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.hairline),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.menu_book_rounded, color: context.colors.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.l10n.dexEmptyTitle, style: context.text.titleMedium),
            const SizedBox(height: 4),
            Text(context.l10n.dexEmptyBody, style: context.text.bodyMedium!.copyWith(color: tokens.muted)),
          ]),
        ),
      ]),
    );
  }
}

/// Fila de cifras: capturados, vistos, variocolor y formas.
class DexStatsRow extends StatelessWidget {
  const DexStatsRow({super.key, required this.progress, required this.living, this.onTap});
  final DexProgress progress;
  final bool living;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final cards = [
      (living ? l10n.dexStatOwned : l10n.dexStatCaught, living ? progress.owned : progress.caught, progress.total,
          context.colors.primary, Icons.catching_pokemon_rounded),
      (l10n.dexStatSeen, progress.seen, progress.total, context.colors.secondary, Icons.visibility_rounded),
      (l10n.dexStatShiny, progress.shiny, progress.total, tokens.shiny, Icons.auto_awesome),
      (l10n.dexStatForms, progress.formsUnlocked, progress.formsTotal, const Color(0xFFB07CF2), Icons.auto_fix_high_rounded),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 640 ? 4 : 2;
      const gap = 10.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final (label, value, total, color, icon) in cards)
          SizedBox(
            width: w,
            child: Material(
              color: tokens.raised,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: tokens.hairline)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelMedium!.copyWith(color: tokens.muted)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: '$value', style: context.text.headlineSmall!.copyWith(fontWeight: FontWeight.w800)),
                          TextSpan(text: ' / $total', style: context.text.labelLarge!.copyWith(color: tokens.muted)),
                        ]),
                        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : value / total,
                        minHeight: 5,
                        color: color,
                        backgroundColor: tokens.sunken,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

/// Barra de filtros: estado, variocolor, formas, tipo, generación, juego y orden.
class DexFilterBar extends StatelessWidget {
  const DexFilterBar({super.key, required this.dex, required this.filter, required this.onFilter});
  final GlobalDex dex;
  final DexFilter filter;
  final void Function(DexFilter Function(DexFilter)) onFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final games = {for (final s in dex.sources) s.game}.toList()..sort((a, b) => a.index.compareTo(b.index));
    Widget status(DexStatusFilter v, String label) => ChoiceChip(
          key: ValueKey('dex-status-${v.name}'),
          label: Text(label),
          selected: filter.status == v,
          showCheckmark: false,
          onSelected: (_) => onFilter((f) => f.copyWith(status: v)),
        );
    Widget menu<T>({
      required Key key,
      required String label,
      required T? value,
      required List<(T?, String)> options,
      required void Function(T?) onSelected,
      IconData icon = Icons.arrow_drop_down_rounded,
    }) {
      final selected = value != null;
      final current = options.firstWhere((o) => o.$1 == value, orElse: () => options.first).$2;
      return PopupMenuButton<int>(
        key: key,
        tooltip: label,
        onSelected: (i) => onSelected(options[i].$1),
        itemBuilder: (context) => [
          for (final (i, (v, text)) in options.indexed)
            CheckedPopupMenuItem(value: i, checked: v == value, child: Text(text)),
        ],
        child: Chip(
          label: Text(selected ? current : label),
          avatar: null,
          deleteIcon: Icon(icon, size: 18),
          onDeleted: () {},
          side: BorderSide(color: selected ? context.colors.primary : tokens.hairline),
          backgroundColor: selected ? context.colors.primary.withValues(alpha: 0.16) : null,
        ),
      );
    }

    final types = [for (final t in PokemonType.values) if (t != PokemonType.none) t];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      EdgeFadeScroller(
        child: Row(children: [
          status(DexStatusFilter.all, l10n.dexAllSpecies),
          const SizedBox(width: 8),
          status(DexStatusFilter.caught, l10n.dexCaughtSpecies),
          const SizedBox(width: 8),
          status(DexStatusFilter.missing, l10n.dexMissingSpecies),
          const SizedBox(width: 8),
          status(DexStatusFilter.seenOnly, l10n.dexFilterSeenOnly),
        ]),
      ),
      const SizedBox(height: 8),
      EdgeFadeScroller(
        child: Row(children: [
          FilterChip(
            key: const ValueKey('dex-shiny'),
            avatar: Icon(Icons.auto_awesome, size: 16, color: tokens.shiny),
            label: Text(l10n.dexFilterShiny),
            selected: filter.shinyOnly,
            onSelected: (v) => onFilter((f) => f.copyWith(shinyOnly: v)),
          ),
          const SizedBox(width: 8),
          FilterChip(
            key: const ValueKey('dex-locked'),
            avatar: const Icon(Icons.lock_open_rounded, size: 16),
            label: Text(l10n.dexFilterLockedForms),
            selected: filter.lockedForms,
            onSelected: (v) => onFilter((f) => f.copyWith(lockedForms: v)),
          ),
          const SizedBox(width: 8),
          menu<PokemonType>(
            key: const ValueKey('dex-type'),
            label: l10n.dexFilterType,
            value: filter.type,
            options: [(null, l10n.dexAnyType), for (final t in types) (t, typeName(context, t))],
            onSelected: (v) => onFilter((f) => f.copyWith(type: () => v)),
          ),
          const SizedBox(width: 8),
          menu<int>(
            key: const ValueKey('dex-gen'),
            label: l10n.dexFilterGeneration,
            value: filter.generation,
            options: [(null, l10n.dexAnyGeneration), for (var g = 1; g <= 9; g++) (g, genRegionLabel(context, g))],
            onSelected: (v) => onFilter((f) => f.copyWith(generation: () => v)),
          ),
          const SizedBox(width: 8),
          menu<GameVersion>(
            key: const ValueKey('dex-game'),
            label: l10n.dexFilterGame,
            value: filter.game,
            options: [(null, l10n.dexAnyGame), for (final g in games) (g, shortGame(context, g))],
            onSelected: (v) => onFilter((f) => f.copyWith(game: () => v)),
          ),
          const SizedBox(width: 8),
          menu<DexSort>(
            key: const ValueKey('dex-sort'),
            label: l10n.dexSortNumber,
            value: filter.sort == DexSort.number ? null : filter.sort,
            options: [(null, l10n.dexSortNumber), (DexSort.name, l10n.dexSortName)],
            onSelected: (v) => onFilter((f) => f.copyWith(sort: v ?? DexSort.number)),
            icon: Icons.sort_rounded,
          ),
        ]),
      ),
    ]);
  }
}

/// Hoja de ajustes de la Dex (living dex).
Future<void> showDexSettings(BuildContext context, WidgetRef ref) => showAdaptiveSheet<void>(
      context: context,
      builder: (context) => Consumer(builder: (context, ref, _) {
        final living = ref.watch(dexLivingProvider);
        final l10n = context.l10n;
        final content = Padding(
          padding: EdgeInsets.fromLTRB(24, context.isPhone ? 8 : 24, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.dexSettings, style: context.text.titleLarge),
            const SizedBox(height: 12),
            SwitchListTile(
              key: const ValueKey('dex-living'),
              contentPadding: EdgeInsets.zero,
              value: living,
              onChanged: (v) => ref.read(dexLivingProvider.notifier).set(v),
              title: Text(l10n.dexLivingTitle),
              subtitle: Text(l10n.dexLivingBody),
            ),
          ]),
        );
        return context.isPhone
            ? SafeArea(child: content)
            : Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: content));
      }),
    );

/// Color de acento de una partida.
Color sourceAccent(DexSource s) => GamePalette.of(s.game, s.versionId);
