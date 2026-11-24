import 'package:flutter/material.dart';
import 'package:pkcore/pkcore.dart';

import '../../theme/app_theme.dart';
import '../common/format.dart';

/// Sección «Pokémon oscuro» del editor (Colosseum / XD): estado, id oscuro y
/// medidor de corazón. Purificar o volver a oscuro pide confirmación: no es lo
/// mismo que hacerlo en el juego (no da experiencia ni movimientos).
class ShadowPanel extends StatelessWidget {
  const ShadowPanel({super.key, required this.pk, required this.mutate});
  final Pkm pk;
  final void Function(void Function(Pkm p)) mutate;

  /// `true` si el Pokémon fue o es oscuro (hay algo que mostrar).
  static bool applies(Pkm pk) => (pk.gc?.shadowId ?? 0) != 0;

  int? _maxGauge(GcExtra gc) {
    final enc = GcEncounter.byShadowId(gc.shadowId, xd: gc.kind == GcKind.xk3);
    return enc.isEmpty ? null : enc.first.gauge;
  }

  Future<bool> _confirm(BuildContext context, String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final gc = pk.gc!;
    final max = _maxGauge(gc);
    final shadow = gc.isShadow;
    final color = shadow ? const Color(0xFF6B3FA0) : const Color(0xFF3E9E6F);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Container(
          key: const ValueKey('shadow-state'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(shadow ? Icons.heart_broken_rounded : Icons.favorite_rounded, size: 18, color: color),
            const SizedBox(width: 6),
            Text(shadow ? l10n.shadowStateShadow : l10n.shadowStatePurified,
                style: context.text.labelLarge!.copyWith(color: color, fontWeight: FontWeight.w700)),
          ]),
        ),
        Text(l10n.shadowIdLabel('${gc.shadowId}'), style: context.text.bodyMedium!.copyWith(color: tokens.muted)),
      ]),
      const SizedBox(height: 14),
      if (shadow) ...[
        Text(l10n.shadowGauge, style: context.text.labelMedium!.copyWith(color: tokens.muted)),
        if (max != null && max > 0)
          Row(children: [
            Expanded(
              child: Slider(
                key: const ValueKey('shadow-gauge'),
                value: gc.purification.clamp(0, max).toDouble(),
                max: max.toDouble(),
                divisions: (max ~/ 100).clamp(1, 200),
                label: '${gc.purification}',
                onChanged: (v) => mutate((p) => p.gc!.purification = v.round()),
              ),
            ),
            SizedBox(width: 92, child: Text('${gc.purification} / $max', textAlign: TextAlign.end)),
          ])
        else
          Text('${gc.purification}', style: context.text.titleMedium),
        Text(max != null ? l10n.shadowGaugeHint('$max') : l10n.shadowGaugeUnknown,
            style: context.text.bodySmall!.copyWith(color: tokens.muted)),
        const SizedBox(height: 6),
        Text(l10n.shadowCannotLeaveNote, style: context.text.bodySmall!.copyWith(color: tokens.muted)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('shadow-purify'),
          icon: const Icon(Icons.auto_awesome_rounded),
          label: Text(l10n.shadowPurify),
          onPressed: () async {
            if (!await _confirm(context, l10n.shadowPurifyTitle, l10n.shadowPurifyBody, l10n.shadowPurifyConfirm)) return;
            mutate((p) {
              p.gc!.setPurified(true);
              Ribbons.set(p, 'RibbonNational', 1);
            });
          },
        ),
      ] else ...[
        Text(l10n.shadowPurifiedNote, style: context.text.bodySmall!.copyWith(color: tokens.muted)),
        const SizedBox(height: 12),
        TextButton.icon(
          icon: const Icon(Icons.undo_rounded),
          label: Text(l10n.shadowRevert),
          onPressed: () async {
            if (!await _confirm(context, l10n.shadowRevertTitle, l10n.shadowRevertBody, l10n.shadowRevertConfirm)) return;
            mutate((p) {
              p.gc!.setPurified(false, gauge: max ?? 0);
              Ribbons.set(p, 'RibbonNational', 0);
            });
          },
        ),
      ],
    ]);
  }
}
