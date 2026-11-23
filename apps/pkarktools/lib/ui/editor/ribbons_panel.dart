import 'package:flutter/material.dart';
import 'package:pkcore/pkcore.dart';

import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../common/game_icons.dart';
import 'pickers.dart';

/// Sección «Cintas y marcas» del editor: agrupadas, con filtro «solo las que
/// tiene», dar todas las válidas / quitar todas, cinta mostrada y avisos de
/// legalidad (PKHeX `RibbonVerifier`).
class RibbonsPanel extends StatefulWidget {
  const RibbonsPanel({super.key, required this.pk, required this.mutate});
  final Pkm pk;
  final void Function(void Function(Pkm p)) mutate;

  @override
  State<RibbonsPanel> createState() => _RibbonsPanelState();
}

class _RibbonsPanelState extends State<RibbonsPanel> {
  bool _onlyOwned = false;

  Pkm get pk => widget.pk;

  String _category(BuildContext context, RibbonCategory c) {
    final l10n = context.l10n;
    return switch (c) {
      RibbonCategory.contest => l10n.ribbonsContest,
      RibbonCategory.battle => l10n.ribbonsBattle,
      RibbonCategory.commemorative => l10n.ribbonsCommemorative,
      RibbonCategory.event => l10n.ribbonsEvent,
      RibbonCategory.mark => l10n.ribbonsMarks,
    };
  }

  Future<void> _details(BuildContext context, RibbonState s) async {
    final l10n = context.l10n;
    final lang = context.dataLang;
    final r = s.info;
    final obtainable = Ribbons.isObtainable(pk, r);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: StatefulBuilder(builder: (ctx, setSheet) {
            final value = Ribbons.get(pk, r.key);
            void apply(int v) {
              widget.mutate((p) => Ribbons.set(p, r.key, v));
              setSheet(() {});
            }

            return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                RibbonIcon(ribbon: r, size: 48),
                const SizedBox(width: 14),
                Expanded(child: Text(r.name(lang), style: ctx.text.titleLarge)),
              ]),
              const SizedBox(height: 10),
              Text(r.description(lang), style: ctx.text.bodyMedium),
              const SizedBox(height: 6),
              Text(
                r.isEventOnly
                    ? l10n.ribbonEventOnly
                    : r.encounterMark
                        ? l10n.ribbonEncounterMark
                        : (obtainable ? l10n.ribbonObtainable : l10n.ribbonNotObtainable),
                style: ctx.text.bodySmall!.copyWith(color: ctx.tokens.muted),
              ),
              const SizedBox(height: 16),
              if (r.isCount)
                Row(children: [
                  Expanded(
                    child: Slider(
                      value: value.clamp(0, r.maxCount).toDouble(),
                      max: r.maxCount.toDouble(),
                      divisions: r.maxCount,
                      label: '$value',
                      onChanged: (v) => apply(v.round()),
                    ),
                  ),
                  SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.end, style: ctx.text.titleMedium)),
                ])
              else
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.ribbonHas),
                  value: value > 0,
                  onChanged: (v) => apply(v ? 1 : 0),
                ),
              if (Ribbons.supportsAffixed(pk.format) && Ribbons.canAffix(r.key))
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.ribbonAffixed),
                  subtitle: Text(l10n.ribbonAffixedHint),
                  value: Ribbons.affixed(pk) == r.key,
                  onChanged: value > 0
                      ? (v) {
                          widget.mutate((p) => Ribbons.setAffixed(p, v ? r.key : null));
                          setSheet(() {});
                        }
                      : null,
                ),
            ]);
          }),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = context.dataLang;
    final tokens = context.tokens;
    final states = Ribbons.of(pk);
    final owned = states.where((s) => s.has).length;
    final issues = Ribbons.check(pk);
    final affixed = Ribbons.affixed(pk);

    final groups = <RibbonCategory, List<RibbonState>>{};
    for (final s in states) {
      if (_onlyOwned && !s.has) continue;
      groups.putIfAbsent(s.info.category, () => []).add(s);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(l10n.ribbonsOwned(owned, states.length), style: context.text.titleSmall),
        FilterChip(
          label: Text(l10n.ribbonsOnlyOwned),
          selected: _onlyOwned,
          onSelected: (v) => setState(() => _onlyOwned = v),
        ),
        OutlinedButton.icon(
          onPressed: pk.isEgg
              ? null
              : () {
                  var n = 0;
                  widget.mutate((p) => n = Ribbons.giveAllValid(p));
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l10n.ribbonsGiven(n))));
                },
          icon: const Icon(Icons.add_task_rounded, size: 18),
          label: Text(l10n.ribbonsGiveAll),
        ),
        TextButton.icon(
          onPressed: owned == 0 && affixed == null ? null : () => widget.mutate(Ribbons.removeAll),
          icon: const Icon(Icons.remove_done_rounded, size: 18),
          label: Text(l10n.ribbonsRemoveAll),
        ),
      ]),
      if (affixed != null) ...[
        const SizedBox(height: 10),
        Row(children: [
          RibbonIcon(ribbon: Ribbons.info(affixed)!, size: 28),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.ribbonAffixedNow(Ribbons.info(affixed)!.name(lang)), style: context.text.bodyMedium)),
        ]),
      ],
      if (issues.isNotEmpty) ...[
        const SizedBox(height: 12),
        for (final i in issues)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(i.isInfo ? Icons.info_outline_rounded : Icons.warning_amber_rounded,
                  size: 18, color: i.isInfo ? tokens.muted : context.colors.error),
              const SizedBox(width: 8),
              Expanded(child: Text(i.message(lang), style: context.text.bodySmall)),
            ]),
          ),
      ],
      const SizedBox(height: 8),
      if (groups.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(l10n.ribbonsNone, style: context.text.bodyMedium!.copyWith(color: tokens.muted)),
        ),
      for (final MapEntry(key: cat, value: list) in groups.entries) ...[
        const SizedBox(height: 12),
        Text('${_category(context, cat)} · ${list.where((s) => s.has).length}/${list.length}',
            style: context.text.labelLarge!.copyWith(color: tokens.muted)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in list)
            Tooltip(
              message: s.info.isCount ? '${s.info.name(lang)}: ${s.value}' : s.info.name(lang),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _details(context, s),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: s.has ? RibbonIcon.colorOf(cat).withValues(alpha: 0.14) : null,
                    border: Border.all(
                      color: affixed == s.info.key
                          ? context.colors.primary
                          : (s.has ? RibbonIcon.colorOf(cat).withValues(alpha: 0.6) : tokens.hairline),
                      width: affixed == s.info.key ? 2 : 1,
                    ),
                  ),
                  child: Stack(alignment: Alignment.center, children: [
                    Semantics(
                      label: s.info.name(lang),
                      selected: s.has,
                      child: RibbonIcon(ribbon: s.info, size: 38, dim: !s.has),
                    ),
                    if (s.info.isCount && s.value > 0)
                      Positioned(
                        right: 3,
                        bottom: 2,
                        child: Text('${s.value}', style: context.text.labelSmall!.copyWith(fontWeight: FontWeight.w800)),
                      ),
                  ]),
                ),
              ),
            ),
        ]),
      ],
    ]);
  }
}
