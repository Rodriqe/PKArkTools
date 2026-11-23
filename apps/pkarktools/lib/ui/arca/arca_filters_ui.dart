import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../../data/arca_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/game_palette.dart';
import '../common/adaptive.dart';
import '../common/format.dart';
import 'arca_filter.dart';
import 'arca_filter_state.dart';

// ------------------------------------------------------------ textos

String sortLabel(AppLocalizations l10n, ArcaSort s) => switch (s) {
      ArcaSort.recent => l10n.sortRecent,
      ArcaSort.trainer => l10n.sortTrainer,
      ArcaSort.game => l10n.sortGame,
      ArcaSort.playTime => l10n.sortPlayTime,
      ArcaSort.copies => l10n.sortCopies,
    };

IconData sortIcon(ArcaSort s) => switch (s) {
      ArcaSort.recent => Icons.schedule_rounded,
      ArcaSort.trainer => Icons.sort_by_alpha_rounded,
      ArcaSort.game => Icons.videogame_asset_outlined,
      ArcaSort.playTime => Icons.timer_outlined,
      ArcaSort.copies => Icons.layers_outlined,
    };

String platformShort(Platform p) => switch (p) {
      Platform.gameBoy => 'Game Boy',
      Platform.gameBoyColor => 'GB Color',
      Platform.gameBoyAdvance => 'GBA',
      Platform.nintendoDs => 'DS',
      Platform.nintendo3ds => '3DS',
      Platform.nintendoSwitch => 'Switch',
    };

String sourceLabel(AppLocalizations l10n, SaveSource s) => switch (s) {
      SaveSource.emulator => l10n.sourceEmulator,
      SaveSource.mobile => l10n.sourceMobile,
      SaveSource.checkpoint => l10n.sourceCheckpoint,
      SaveSource.cartridge => l10n.sourceCartridge,
      SaveSource.other => l10n.sourceOther,
    };

IconData sourceIcon(SaveSource s) => switch (s) {
      SaveSource.emulator => Icons.computer_rounded,
      SaveSource.mobile => Icons.smartphone_rounded,
      SaveSource.checkpoint => Icons.sd_card_outlined,
      SaveSource.cartridge => Icons.memory_rounded,
      SaveSource.other => Icons.help_outline_rounded,
    };

String statusLabel(AppLocalizations l10n, ArcaStatus s) => switch (s) {
      ArcaStatus.damaged => l10n.statusDamaged,
      ArcaStatus.legality => l10n.statusLegality,
      ArcaStatus.edited => l10n.statusEdited,
      ArcaStatus.multipleCopies => l10n.statusMultiple,
    };

IconData statusIcon(ArcaStatus s) => switch (s) {
      ArcaStatus.damaged => Icons.report_gmailerrorred_rounded,
      ArcaStatus.legality => Icons.gpp_maybe_outlined,
      ArcaStatus.edited => Icons.edit_outlined,
      ArcaStatus.multipleCopies => Icons.layers_outlined,
    };

String presetLabel(AppLocalizations l10n, DatePreset p) => switch (p) {
      DatePreset.week => l10n.datePresetWeek,
      DatePreset.month => l10n.datePresetMonth,
      DatePreset.year => l10n.datePresetYear,
    };

String dateLabel(BuildContext context, ArcaFilter f) {
  final l10n = context.l10n;
  if (f.datePreset != null) return presetLabel(l10n, f.datePreset!);
  final from = f.from == null ? '…' : formatDate(context, f.from!);
  final to = f.to == null ? '…' : formatDate(context, f.to!);
  return l10n.dateRange(from, to);
}

/// Un filtro activo, con lo que hace falta para quitarlo.
class ActiveFilter {
  const ActiveFilter(this.label, this.remove, {this.icon, this.color});
  final String label;
  final ArcaFilter Function(ArcaFilter f) remove;
  final IconData? icon;
  final Color? color;
}

/// Juegos presentes en el Arca, en orden de lanzamiento: clave → (título, color).
Map<String, (String, Color)> gameOptions(BuildContext context, List<ArcaEntry> all) {
  final sorted = [...all]..sort((a, b) {
      final c = a.game.index.compareTo(b.game.index);
      return c != 0 ? c : (a.slot.versionId ?? 0).compareTo(b.slot.versionId ?? 0);
    });
  return {
    for (final e in sorted)
      ArcaFilter.gameKey(e): (gameTitle(context, e.game, e.slot.versionId), GamePalette.of(e.game, e.slot.versionId)),
  };
}

List<ActiveFilter> activeFilters(BuildContext context, ArcaFilter f, List<ArcaEntry> all) {
  final l10n = context.l10n;
  final games = gameOptions(context, all);
  return [
    for (final g in f.generations.toList()..sort())
      ActiveFilter(l10n.filterGenShort(g), (x) => x.copyWith(generations: ArcaFilter.toggled(x.generations, g))),
    for (final p in Platform.values.where(f.platforms.contains))
      ActiveFilter(platformShort(p), (x) => x.copyWith(platforms: ArcaFilter.toggled(x.platforms, p)),
          icon: Icons.sports_esports_outlined),
    for (final s in SaveSource.values.where(f.sources.contains))
      ActiveFilter(sourceLabel(l10n, s), (x) => x.copyWith(sources: ArcaFilter.toggled(x.sources, s)), icon: sourceIcon(s)),
    for (final k in f.games)
      ActiveFilter(games[k]?.$1 ?? k, (x) => x.copyWith(games: ArcaFilter.toggled(x.games, k)), color: games[k]?.$2),
    for (final s in ArcaStatus.values.where(f.statuses.contains))
      ActiveFilter(statusLabel(l10n, s), (x) => x.copyWith(statuses: ArcaFilter.toggled(x.statuses, s)), icon: statusIcon(s)),
    if (f.hasDate)
      ActiveFilter(dateLabel(context, f), (x) => x.without(FilterGroup.date), icon: Icons.event_outlined),
  ];
}

// ------------------------------------------------------------ barra

/// Fila de chips sobre las tarjetas: «Filtros» (con cuántos hay), orden,
/// filtros activos quitables y «Limpiar». En el teléfono se desliza.
class ArcaFilterBar extends ConsumerWidget {
  const ArcaFilterBar({super.key, required this.all, required this.showFiltersButton});
  final List<ArcaEntry> all;

  /// En escritorio ancho el panel lateral sustituye al botón.
  final bool showFiltersButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final f = ref.watch(arcaFilterProvider);
    final notifier = ref.read(arcaFilterProvider.notifier);
    final active = activeFilters(context, f, all);
    final chips = <Widget>[
      if (showFiltersButton)
        _BarButton(
          key: const Key('arca-filters-button'),
          icon: Icons.tune_rounded,
          label: l10n.filtersAction,
          badge: f.activeCount,
          onPressed: () => showArcaFilters(context),
        ),
      _SortButton(sort: f.sort, onChanged: (s) => notifier.update((x) => x.copyWith(sort: s))),
      for (final a in active)
        InputChip(
          label: Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          avatar: a.color != null
              ? _Dot(a.color!)
              : a.icon != null
                  ? Icon(a.icon, size: 16)
                  : null,
          onDeleted: () => notifier.update(a.remove),
          deleteButtonTooltipMessage: l10n.filtersRemove(a.label),
          visualDensity: VisualDensity.compact,
        ),
      if (active.isNotEmpty)
        TextButton(
          key: const Key('arca-filters-clear'),
          onPressed: () => notifier.update((x) => x.cleared(keepQuery: true)),
          child: Text(l10n.filtersClear),
        ),
    ];
    return ScrollingChipRow(children: chips);
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({super.key, required this.icon, required this.label, required this.onPressed, this.badge = 0});
  final IconData icon;
  final String label;
  final int badge;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final on = badge > 0;
    return ActionChip(
      avatar: Icon(icon, size: 18, color: on ? context.colors.onPrimary : null),
      label: Text(on ? '$label · $badge' : label),
      onPressed: onPressed,
      backgroundColor: on ? context.colors.primary : null,
      labelStyle: on ? TextStyle(color: context.colors.onPrimary, fontWeight: FontWeight.w700) : null,
      side: on ? BorderSide.none : null,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onChanged});
  final ArcaSort sort;
  final ValueChanged<ArcaSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MenuAnchor(
      menuChildren: [
        for (final s in ArcaSort.values)
          MenuItemButton(
            leadingIcon: Icon(sortIcon(s), size: 18),
            trailingIcon: s == sort ? const Icon(Icons.check_rounded, size: 18) : null,
            onPressed: () => onChanged(s),
            child: Text(sortLabel(l10n, s)),
          ),
      ],
      builder: (context, controller, _) => ActionChip(
        key: const Key('arca-sort-button'),
        avatar: Icon(Icons.swap_vert_rounded, size: 18, color: context.tokens.muted),
        label: Text(sortLabel(l10n, sort)),
        tooltip: l10n.sortLabel,
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: context.tokens.hairline),
        ),
      );
}

// ------------------------------------------------------------ panel

/// Abre todos los filtros: hoja inferior en el teléfono, panel lateral
/// (diálogo a la derecha) en ventanas medianas.
Future<void> showArcaFilters(BuildContext context) {
  if (context.isPhone) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 1,
        builder: (context, controller) => ArcaFilterPanel(scrollController: controller, inSheet: true),
      ),
    );
  }
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.filtersTitle,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: context.tokens.raised,
        elevation: 12,
        child: SafeArea(
          child: SizedBox(width: 360, child: ArcaFilterPanel(inSheet: true)),
        ),
      ),
    ),
    transitionBuilder: (context, anim, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

/// Todos los filtros con el número de partidas de cada opción (teniendo en
/// cuenta el resto de filtros). Se usa en la hoja, en el panel derecho y
/// fijo a la izquierda en escritorio ancho.
class ArcaFilterPanel extends ConsumerWidget {
  const ArcaFilterPanel({super.key, this.scrollController, this.inSheet = false});
  final ScrollController? scrollController;

  /// En una hoja o diálogo: cabecera con cerrar y pie con «Ver N partidas».
  final bool inSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final all = ref.watch(arcaEntriesProvider).value ?? const <ArcaEntry>[];
    final f = ref.watch(arcaFilterProvider);
    final scan = ref.watch(legalityScanProvider);
    final notifier = ref.read(arcaFilterProvider.notifier);
    final now = DateTime.now();
    String titleOf(ArcaEntry e) => gameTitle(context, e.game, e.slot.versionId);

    int count(ArcaFilter x) => all.where((e) => x.matches(e, now: now, titleOf: titleOf, warnings: scan.warnings)).length;
    final results = count(f);

    Widget option<T>({
      required FilterGroup group,
      required ArcaFilter Function(ArcaFilter base) only,
      required bool selected,
      required String label,
      required VoidCallback onTap,
      Widget? avatar,
      bool hideEmpty = false,
      bool countable = true,
      Key? key,
    }) {
      final n = countable ? count(only(f.without(group))) : null;
      if (hideEmpty && n == 0 && !selected) return const SizedBox.shrink();
      return FilterChip(
        key: key,
        selected: selected,
        avatar: avatar,
        showCheckmark: avatar == null,
        label: Text(n == null ? label : '$label  $n', maxLines: 1, overflow: TextOverflow.ellipsis),
        onSelected: n == 0 && !selected ? null : (_) => onTap(),
        visualDensity: VisualDensity.compact,
      );
    }

    void set(ArcaFilter Function(ArcaFilter x) change) => notifier.update(change);

    final games = gameOptions(context, all);
    final sections = <Widget>[
      _Section(l10n.sortLabel, [
        for (final s in ArcaSort.values)
          ChoiceChip(
            key: Key('sort-${s.name}'),
            selected: f.sort == s,
            avatar: Icon(sortIcon(s), size: 16),
            showCheckmark: false,
            label: Text(sortLabel(l10n, s)),
            onSelected: (_) => set((x) => x.copyWith(sort: s)),
            visualDensity: VisualDensity.compact,
          ),
      ]),
      _Section(l10n.filterGeneration, [
        for (var g = 1; g <= 9; g++)
          option(
            key: Key('gen-$g'),
            group: FilterGroup.generation,
            only: (b) => b.copyWith(generations: {g}),
            selected: f.generations.contains(g),
            label: l10n.filterGenShort(g),
            onTap: () => set((x) => x.copyWith(generations: ArcaFilter.toggled(x.generations, g))),
          ),
      ]),
      _Section(l10n.filterPlatform, [
        for (final p in Platform.values)
          option(
            key: Key('platform-${p.name}'),
            group: FilterGroup.platform,
            only: (b) => b.copyWith(platforms: {p}),
            selected: f.platforms.contains(p),
            label: platformShort(p),
            onTap: () => set((x) => x.copyWith(platforms: ArcaFilter.toggled(x.platforms, p))),
          ),
      ]),
      _Section(l10n.filterSource, [
        for (final s in SaveSource.values)
          option(
            key: Key('source-${s.name}'),
            group: FilterGroup.source,
            only: (b) => b.copyWith(sources: {s}),
            selected: f.sources.contains(s),
            label: sourceLabel(l10n, s),
            avatar: Icon(sourceIcon(s), size: 16),
            hideEmpty: s == SaveSource.other,
            onTap: () => set((x) => x.copyWith(sources: ArcaFilter.toggled(x.sources, s))),
          ),
      ]),
      _Section(l10n.filterGame, [
        for (final MapEntry(key: k, value: (title, color)) in games.entries)
          option(
            key: Key('game-$k'),
            group: FilterGroup.game,
            only: (b) => b.copyWith(games: {k}),
            selected: f.games.contains(k),
            label: title,
            avatar: _Dot(color),
            onTap: () => set((x) => x.copyWith(games: ArcaFilter.toggled(x.games, k))),
          ),
      ]),
      _Section(
        l10n.filterStatus,
        [
          for (final s in ArcaStatus.values)
            option(
              key: Key('status-${s.name}'),
              group: FilterGroup.status,
              only: (b) => b.copyWith(statuses: {s}),
              selected: f.statuses.contains(s),
              label: statusLabel(l10n, s),
              avatar: Icon(statusIcon(s), size: 16),
              // La legalidad se calcula bajo demanda: hasta que se revisa todo
              // no hay recuento y siempre se puede elegir.
              countable: s != ArcaStatus.legality || all.every((e) => scan.warnings.containsKey(e.latest.id)),
              onTap: () => set((x) => x.copyWith(statuses: ArcaFilter.toggled(x.statuses, s))),
            ),
        ],
        footer: f.statuses.contains(ArcaStatus.legality) && scan.running
            ? LegalityProgress(scan: scan)
            : null,
      ),
      _Section(l10n.filterDate, [
        for (final p in DatePreset.values)
          option(
            key: Key('date-${p.name}'),
            group: FilterGroup.date,
            only: (b) => b.copyWith(datePreset: () => p),
            selected: f.datePreset == p,
            label: presetLabel(l10n, p),
            onTap: () => set((x) => f.datePreset == p
                ? x.without(FilterGroup.date)
                : x.copyWith(datePreset: () => p, from: () => null, to: () => null)),
          ),
        ActionChip(
          key: const Key('date-custom'),
          avatar: const Icon(Icons.date_range_rounded, size: 16),
          label: Text(f.datePreset == null && f.hasDate ? dateLabel(context, f) : l10n.dateCustom),
          onPressed: () async {
            final first = all.isEmpty
                ? DateTime(now.year - 1)
                : all.map((e) => e.latest.importedAt).reduce((a, b) => a.isBefore(b) ? a : b);
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(first.year, first.month, first.day).subtract(const Duration(days: 1)),
              lastDate: DateTime(now.year, now.month, now.day),
              initialDateRange: f.from != null && f.to != null ? DateTimeRange(start: f.from!, end: f.to!) : null,
            );
            if (picked != null) {
              set((x) => x.copyWith(datePreset: () => null, from: () => picked.start, to: () => picked.end));
            }
          },
          visualDensity: VisualDensity.compact,
        ),
      ]),
    ];

    // Pocas secciones: se construyen todas (sin carga perezosa).
    final list = SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(20, inSheet ? 4 : 0, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sections),
    );
    final header = Padding(
      padding: EdgeInsets.fromLTRB(20, inSheet ? 4 : 0, 8, 4),
      child: Row(children: [
        Expanded(child: Text(l10n.filtersTitle, style: context.text.titleLarge)),
        TextButton(
          key: const Key('panel-clear'),
          onPressed: f.activeCount == 0 ? null : () => notifier.update((x) => x.cleared(keepQuery: true)),
          child: Text(l10n.filtersClear),
        ),
        if (inSheet && !context.isPhone)
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
      ]),
    );
    return Column(children: [
      header,
      Expanded(child: list),
      if (inSheet)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('panel-show'),
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(l10n.filtersShow(results)),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.chips, {this.footer});
  final String title;
  final List<Widget> chips;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: context.text.labelSmall!.copyWith(color: context.tokens.muted, letterSpacing: 1.1)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
            if (footer != null) ...[const SizedBox(height: 10), footer!],
          ],
        ),
      );
}

/// Progreso de la revisión de legalidad.
class LegalityProgress extends StatelessWidget {
  const LegalityProgress({super.key, required this.scan});
  final LegalityScan scan;

  @override
  Widget build(BuildContext context) {
    final done = scan.total - scan.pending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.l10n.legalityScanning(done, scan.total),
            style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: scan.total == 0 ? null : done / scan.total, minHeight: 4),
        ),
      ],
    );
  }
}
