import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../../editing/draft.dart';
import '../../theme/app_theme.dart';
import '../common/adaptive.dart';
import '../common/format.dart';
import '../common/species_avatar.dart';

enum _DexFilter { all, missing, seen, caught }

/// Pokédex editable: visto / capturado (y variocolor donde el juego lo guarda).
///
/// Cada toque es una edición del borrador (se puede deshacer).
class PokedexPanel extends ConsumerStatefulWidget {
  const PokedexPanel({super.key, required this.snapshotId, required this.editor, required this.accent});
  final int snapshotId;
  final SaveEditor editor;
  final Color accent;

  @override
  ConsumerState<PokedexPanel> createState() => _PokedexPanelState();
}

/// Nombre localizado de una Pokédex regional (claves de pkcore `kDexRegionKeys`).
String dexRegionName(BuildContext context, String key) {
  final l10n = context.l10n;
  return switch (key) {
    'galar' => l10n.dexRegion_galar,
    'armor' => l10n.dexRegion_armor,
    'crown' => l10n.dexRegion_crown,
    'hisui' => l10n.dexRegion_hisui,
    'paldea' => l10n.dexRegion_paldea,
    'kitakami' => l10n.dexRegion_kitakami,
    'blueberry' => l10n.dexRegion_blueberry,
    'lumiose' => l10n.dexRegion_lumiose,
    'hyperspace' => l10n.dexRegion_hyperspace,
    _ => key,
  };
}

class _PokedexPanelState extends ConsumerState<PokedexPanel> {
  _DexFilter _filter = _DexFilter.all;
  String _query = '';
  String? _region;

  Future<void> _detail(Pokedex dex, DexEntry entry) async {
    final result = await showAdaptiveSheet<DexEntry>(
      context: context,
      builder: (ctx) => _DexDetailDialog(dex: dex, entry: entry, accent: widget.accent),
    );
    if (result != null && result != entry) _apply(PokedexEdit([result]));
  }

  void _apply(SaveEditOp op) => ref.read(draftProvider(widget.snapshotId).notifier).apply(op);

  Future<void> _bulk(PokedexBulk bulk, int max) async {
    final l10n = context.l10n;
    final clear = bulk == PokedexBulk.clearAll;
    final ok = await confirmAdaptive(
      context,
      icon: clear ? Icons.layers_clear_rounded : Icons.auto_stories_rounded,
      title: clear ? l10n.dexConfirmClearTitle : l10n.dexConfirmCompleteTitle,
      body: clear ? l10n.dexConfirmClearBody : l10n.dexConfirmCompleteBody(max),
      confirm: clear ? l10n.dexClear : (bulk == PokedexBulk.completeAllShiny ? l10n.dexCompleteShiny : l10n.dexComplete),
      cancel: l10n.cancel,
      destructive: clear,
    );
    if (ok) _apply(PokedexEdit.bulk(bulk));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final dex = widget.editor.pokedex;
    if (dex == null) {
      return Text(l10n.dexUnsupported, style: context.text.bodyLarge!.copyWith(color: tokens.muted));
    }
    final counts = dex.counts;
    final total = dex.species.length;
    final regions = dex.regions;
    if (_region != null && !regions.contains(_region)) _region = null;
    final entries = [
      for (final e in dex.entries)
        if (_region == null || dex.regionalNumber(e.species)?.$1 == _region) e,
    ];
    if (_region != null) {
      entries.sort((a, b) => dex.regionalNumber(a.species)!.$2.compareTo(dex.regionalNumber(b.species)!.$2));
    }
    final q = _query.trim().toLowerCase();
    final detailed = dex.hasGender || dex.hasForms;
    final phone = context.isPhone;
    final shown = [
      for (final e in entries)
        if (switch (_filter) {
              _DexFilter.all => true,
              _DexFilter.missing => !e.caught,
              _DexFilter.seen => e.seen && !e.caught,
              _DexFilter.caught => e.caught,
            } &&
            (q.isEmpty || '${e.species}' == q || speciesName(context, e.species).toLowerCase().contains(q)))
          e,
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _DexMeter(max: total, seen: counts.seen, caught: counts.caught, shiny: dex.hasShiny ? counts.shiny : null, accent: widget.accent),
      const SizedBox(height: 20),
      Builder(builder: (context) {
        final bulk = [
          FilledButton.tonalIcon(
            onPressed: () => _bulk(PokedexBulk.completeAll, total),
            icon: const Icon(Icons.auto_stories_rounded, size: 18),
            label: Text(l10n.dexComplete),
          ),
          if (dex.hasShiny)
            FilledButton.tonalIcon(
              onPressed: () => _bulk(PokedexBulk.completeAllShiny, total),
              icon: Icon(Icons.auto_awesome, size: 18, color: tokens.shiny),
              label: Text(l10n.dexCompleteShiny),
            ),
          OutlinedButton.icon(
            onPressed: () => _bulk(PokedexBulk.clearAll, total),
            icon: const Icon(Icons.layers_clear_rounded, size: 18),
            label: Text(l10n.dexClear),
          ),
        ];
        return phone
            ? ScrollingChipRow(spacing: 10, children: bulk)
            : Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: bulk);
      }),
      const SizedBox(height: 20),
      Builder(builder: (context) {
        final search = TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: phone ? l10n.dexSearchShort : l10n.dexSearch,
            hintMaxLines: 1,
            isDense: !phone,
          ),
          onChanged: (v) => setState(() => _query = v),
        );
        final filters = SectionTabs<_DexFilter>(
          dense: true,
          accent: widget.accent,
          tabs: [
            SectionTab(_DexFilter.all, l10n.dexFilterAll, icon: Icons.apps_rounded),
            SectionTab(_DexFilter.missing, l10n.dexFilterMissing, icon: Icons.radio_button_unchecked_rounded),
            SectionTab(_DexFilter.seen, l10n.dexFilterSeen, icon: Icons.visibility_outlined),
            SectionTab(_DexFilter.caught, l10n.dexFilterCaught, icon: Icons.catching_pokemon_rounded),
          ],
          selected: _filter,
          onChanged: (v) => setState(() => _filter = v),
        );
        return phone
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [search, const SizedBox(height: 12), filters])
            : Row(children: [SizedBox(width: 300, child: search), const SizedBox(width: 12), Expanded(child: filters)]);
      }),
      if (regions.isNotEmpty) ...[
        const SizedBox(height: 12),
        ScrollingChipRow(
          selectedIndex: _region == null ? 0 : regions.indexOf(_region!) + 1,
          children: [
            ChoiceChip(
              label: Text(l10n.dexRegionAll),
              selected: _region == null,
              onSelected: (_) => setState(() => _region = null),
            ),
            for (final r in regions)
              ChoiceChip(
                avatar: Icon(Icons.map_outlined, size: 16, color: _region == r ? widget.accent : tokens.muted),
                label: Text(dexRegionName(context, r)),
                selected: _region == r,
                selectedColor: widget.accent.withValues(alpha: 0.18),
                onSelected: (_) => setState(() => _region = r),
              ),
          ],
        ),
      ],
      if (detailed) ...[
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.touch_app_outlined, size: 16, color: tokens.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(isDesktopPlatform ? l10n.dexDetailHint : l10n.dexDetailHintTouch,
                style: context.text.bodySmall!.copyWith(color: tokens.muted)),
          ),
        ]),
      ],
      const SizedBox(height: 18),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(l10n.dexNoMatch, style: context.text.bodyMedium!.copyWith(color: tokens.muted)),
        )
      else
        LayoutBuilder(builder: (context, c) {
          final cols = (c.maxWidth / 150).floor().clamp(2, 8);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shown.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols, mainAxisExtent: 64, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemBuilder: (context, i) => _DexTile(
              entry: shown[i],
              hasShiny: dex.hasShiny,
              accent: widget.accent,
              number: _region == null ? null : dex.regionalNumber(shown[i].species)?.$2,
              research: dex.researchLevel(shown[i].species),
              onDetail: detailed ? () => _detail(dex, shown[i]) : null,
              onCycle: () {
                final e = shown[i];
                final next = !e.seen
                    ? e.copyWith(seen: true)
                    : !e.caught
                        ? e.copyWith(caught: true)
                        : DexEntry(e.species);
                _apply(PokedexEdit([next]));
              },
              onShiny: dex.hasShiny ? () => _apply(PokedexEdit([shown[i].copyWith(shiny: !shown[i].shiny)])) : null,
            ),
          );
        }),
    ]);
  }
}

/// Medidor de progreso: barra de vistos con la de capturados encima.
class _DexMeter extends StatelessWidget {
  const _DexMeter({required this.max, required this.seen, required this.caught, required this.shiny, required this.accent});
  final int max, seen, caught;
  final int? shiny;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    Widget figure(String label, int value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: '$value', style: context.text.displaySmall!.copyWith(color: color, height: 1)),
            TextSpan(text: ' / $max', style: context.text.titleMedium!.copyWith(color: tokens.muted)),
          ])),
          const SizedBox(height: 4),
          Text(label, style: context.text.labelLarge!.copyWith(color: tokens.muted)),
        ]);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(color: tokens.raised, borderRadius: BorderRadius.circular(22), border: Border.all(color: tokens.hairline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 36, runSpacing: 12, children: [
          figure(l10n.dexCaught, caught, accent),
          figure(l10n.dexSeen, seen, context.colors.onSurface),
          if (shiny != null) figure(l10n.dexShiny, shiny!, tokens.shiny),
        ]),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Stack(fit: StackFit.expand, children: [
              ColoredBox(color: tokens.sunken),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: max == 0 ? 0 : seen / max,
                child: ColoredBox(color: accent.withValues(alpha: 0.35)),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: max == 0 ? 0 : caught / max,
                child: ColoredBox(color: accent),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _DexTile extends StatelessWidget {
  const _DexTile({
    required this.entry,
    required this.hasShiny,
    required this.accent,
    required this.onCycle,
    this.onShiny,
    this.onDetail,
    this.number,
    this.research,
  });
  final DexEntry entry;
  final bool hasShiny;
  final Color accent;
  final VoidCallback onCycle;
  final VoidCallback? onShiny;
  final VoidCallback? onDetail;

  /// Número regional (si se filtra por una Pokédex regional).
  final int? number;

  /// Nivel de investigación (Leyendas Arceus).
  final int? research;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final e = entry;
    final state = e.caught ? l10n.dexToggleCaught : (e.seen ? l10n.dexToggleSeen : '—');
    final bg = e.caught ? accent.withValues(alpha: 0.16) : (e.seen ? tokens.raised : tokens.sunken);
    final border = e.caught ? accent.withValues(alpha: 0.6) : (e.seen ? tokens.hairline : Colors.transparent);
    return Semantics(
      button: true,
      label: '${speciesName(context, e.species)}: $state',
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onCycle,
          onLongPress: onDetail,
          onSecondaryTap: onDetail,
          child: LayoutBuilder(builder: (context, c) {
            // Teselas estrechas (teléfono, dos columnas): avatar más pequeño y
            // sin el icono de capturado (ya lo indican el fondo y el borde).
            final narrow = c.maxWidth < 170;
            return Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
            child: Row(children: [
              Opacity(
                opacity: e.seen ? 1 : 0.28,
                child: SpeciesAvatar(species: e.species, shiny: e.shiny, size: narrow ? 36 : 44),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text('#${(number ?? e.species).toString().padLeft(3, '0')}',
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: context.text.labelSmall!.copyWith(
                              color: number != null ? accent : tokens.muted, fontFeatures: const [FontFeature.tabularFigures()])),
                    ),
                    if (research != null && research! > 0) ...[
                      const SizedBox(width: 4),
                      Text('${research!}%',
                          style: context.text.labelSmall!.copyWith(
                              color: research! >= 100 ? accent : tokens.muted, fontWeight: FontWeight.w700)),
                    ],
                  ]),
                  Text(e.seen ? speciesName(context, e.species) : '???',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelLarge),
                ]),
              ),
              if (e.caught && !narrow) Icon(Icons.catching_pokemon_rounded, size: 16, color: accent),
              if (hasShiny)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.dexToggleShiny,
                  onPressed: onShiny,
                  icon: Icon(e.shiny ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                      size: 16, color: e.shiny ? tokens.shiny : tokens.muted.withValues(alpha: 0.5)),
                ),
            ]),
          );
          }),
        ),
      ),
    );
  }
}


/// Detalle editable de una especie: visto/capturado, variocolor, géneros, formas
/// e investigación (solo lectura, Leyendas Arceus).
class _DexDetailDialog extends StatefulWidget {
  const _DexDetailDialog({required this.dex, required this.entry, required this.accent});
  final Pokedex dex;
  final DexEntry entry;
  final Color accent;

  @override
  State<_DexDetailDialog> createState() => _DexDetailDialogState();
}

class _DexDetailDialogState extends State<_DexDetailDialog> {
  late DexEntry e = widget.entry;

  void _set(DexEntry next) => setState(() {
        var n = next;
        if (n.caught || n.shiny || (n.genders ?? 0) != 0 || (n.forms ?? 0) != 0) n = n.copyWith(seen: true);
        e = n;
      });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final dex = widget.dex;
    final s = e.species;
    final all = dex.allGenders(s);
    final region = dex.regionalNumber(s);
    final research = dex.researchLevel(s);
    final forms = dex.formCount(s);
    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(),
                style: context.text.labelSmall!.copyWith(color: tokens.muted, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            child,
          ]),
        );
    final header = Row(children: [
        SpeciesAvatar(species: s, shiny: e.shiny, size: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.dexDetailTitle.toUpperCase(),
                style: context.text.labelSmall!.copyWith(color: widget.accent, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            Text(speciesName(context, s), style: context.text.headlineSmall),
            Text(
              region == null
                  ? '#${s.toString().padLeft(4, '0')}'
                  : '#${s.toString().padLeft(4, '0')} · ${l10n.dexRegionalNumber(dexRegionName(context, region.$1), '${region.$2}')}',
              style: context.text.bodySmall!.copyWith(color: tokens.muted),
            ),
          ]),
        ),
      ]);
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.dexDetailSeen),
              value: e.seen,
              onChanged: (v) => _set(v ? e.copyWith(seen: true) : DexEntry(s, genders: e.genders == null ? null : 0, forms: e.forms == null ? null : 0)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.dexDetailCaught),
              value: e.caught,
              onChanged: (v) => _set(e.copyWith(caught: v)),
            ),
            if (dex.hasShiny)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(Icons.auto_awesome, color: e.shiny ? tokens.shiny : tokens.muted),
                title: Text(l10n.dexDetailShiny),
                value: e.shiny,
                onChanged: (v) => _set(e.copyWith(shiny: v)),
              ),
            if (dex.hasGender && e.genders != null)
              section(
                l10n.dexDetailGenders,
                Wrap(spacing: 8, children: [
                  if (dex.isGenderless(s))
                    FilterChip(
                      label: Text(l10n.dexDetailGenderless),
                      selected: e.genderSeen(0),
                      onSelected: (v) => _set(e.copyWith(genders: v ? 1 : 0)),
                    )
                  else ...[
                    if (all & 1 != 0)
                      FilterChip(
                        avatar: const Icon(Icons.male_rounded, size: 18),
                        label: Text(l10n.dexDetailMale),
                        selected: e.genderSeen(0),
                        onSelected: (v) => _set(e.copyWith(genders: v ? e.genders! | 1 : e.genders! & ~1)),
                      ),
                    if (all & 2 != 0)
                      FilterChip(
                        avatar: const Icon(Icons.female_rounded, size: 18),
                        label: Text(l10n.dexDetailFemale),
                        selected: e.genderSeen(1),
                        onSelected: (v) => _set(e.copyWith(genders: v ? e.genders! | 2 : e.genders! & ~2)),
                      ),
                  ],
                ]),
              ),
            if (dex.hasForms && forms > 1 && e.forms != null)
              section(
                l10n.dexDetailForms,
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var f = 0; f < forms; f++)
                    Tooltip(
                      message: dex.formAvailable(s, f) ? '' : l10n.dexDetailFormUnavailable,
                      child: FilterChip(
                        label: Text(f == 0 ? l10n.dexDetailFormBase : l10n.dexDetailForm('$f')),
                        selected: e.formSeen(f),
                        selectedColor: widget.accent.withValues(alpha: 0.2),
                        onSelected: dex.formAvailable(s, f)
                            ? (v) => _set(e.copyWith(forms: v ? e.forms! | (1 << f) : e.forms! & ~(1 << f)))
                            : null,
                      ),
                    ),
                ]),
              ),
            if (research != null)
              section(
                l10n.dexResearch,
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: research / 100,
                          minHeight: 8,
                          color: widget.accent,
                          backgroundColor: tokens.sunken,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$research%', style: context.text.titleMedium!.copyWith(color: widget.accent)),
                  ]),
                  const SizedBox(height: 8),
                  Text(l10n.dexResearchNote, style: context.text.bodySmall!.copyWith(color: tokens.muted)),
                ]),
              ),
          ]);
    final cancel = TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel));
    final apply = FilledButton(onPressed: () => Navigator.pop(context, e), child: Text(l10n.dexDetailApply));
    if (context.isPhone) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            header,
            Flexible(child: SingleChildScrollView(child: body)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: SizedBox(height: 48, child: cancel)),
              const SizedBox(width: 12),
              Expanded(child: SizedBox(height: 48, child: apply)),
            ]),
          ]),
        ),
      );
    }
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      title: header,
      content: SizedBox(width: 420, child: SingleChildScrollView(child: body)),
      actions: [cancel, apply],
    );
  }
}
