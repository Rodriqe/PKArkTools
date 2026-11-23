import 'package:flutter/material.dart';
import 'package:pkcore/pkcore.dart';

import '../../theme/app_theme.dart';
import '../common/format.dart';
import 'pickers.dart';

const warningColor = Color(0xFFF0A23B);

/// Avisos de legalidad agrupados por área, con explicación y corrección segura.
/// Nunca impide guardar: solo informa.
class LegalityPanel extends StatelessWidget {
  const LegalityPanel({super.key, required this.issues, this.onFix, this.onFixAll});
  final List<LegalityIssue> issues;

  /// Aplica la corrección segura de un aviso (null = solo lectura).
  final ValueChanged<LegalityIssue>? onFix;
  final VoidCallback? onFixAll;

  String _area(BuildContext context, LegalityArea a) => switch (a) {
        LegalityArea.encounter => context.l10n.legalityAreaEncounter,
        LegalityArea.origin => context.l10n.legalityAreaOrigin,
        LegalityArea.moves => context.l10n.legalityAreaMoves,
        LegalityArea.stats => context.l10n.legalityAreaStats,
        LegalityArea.misc => context.l10n.legalityAreaMisc,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    if (issues.isEmpty) {
      return Row(children: [
        const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF52C98A)),
        const SizedBox(width: 10),
        Expanded(child: Text(l10n.legalityClean, style: context.text.bodyMedium!.copyWith(color: tokens.muted))),
      ]);
    }
    final fixable = issues.where((i) => i.fix != null).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: warningColor.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
          Text(l10n.legalityTitle(issues.length), style: context.text.titleSmall),
          if (onFixAll != null && fixable > 1)
            TextButton.icon(
              onPressed: onFixAll,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: Text(l10n.legalityFixAll(fixable)),
            ),
        ]),
        const SizedBox(height: 2),
        Text(l10n.legalityHint, style: context.text.bodySmall!.copyWith(color: tokens.muted)),
        for (final area in LegalityArea.values)
          if (issues.any((i) => i.area == area)) ...[
            const SizedBox(height: 14),
            Text(_area(context, area), style: context.text.labelLarge!.copyWith(color: tokens.muted)),
            const SizedBox(height: 6),
            for (final i in issues.where((i) => i.area == area)) _IssueTile(issue: i, onFix: onFix),
          ],
        const SizedBox(height: 8),
        Text(l10n.legalityScope, style: context.text.labelSmall!.copyWith(color: tokens.muted)),
      ]),
    );
  }
}

class _IssueTile extends StatefulWidget {
  const _IssueTile({required this.issue, this.onFix});
  final LegalityIssue issue;
  final ValueChanged<LegalityIssue>? onFix;

  @override
  State<_IssueTile> createState() => _IssueTileState();
}

class _IssueTileState extends State<_IssueTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final i = widget.issue;
    final tokens = context.tokens;
    final warn = i.severity == LegalitySeverity.warning;
    final lang = context.dataLang;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(warn ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                      size: 16, color: warn ? warningColor : tokens.muted),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(i.message(lang), style: context.text.bodySmall)),
                Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: tokens.muted),
              ]),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topLeft,
                child: !_open
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(26, 8, 0, 4),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(i.detail(lang), style: context.text.bodySmall!.copyWith(color: tokens.muted, height: 1.45)),
                          const SizedBox(height: 8),
                          if (i.fix != null && widget.onFix != null)
                            FilledButton.tonalIcon(
                              onPressed: () => widget.onFix!(i),
                              icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                              label: Text(context.l10n.legalityFix),
                            )
                          else
                            Text(context.l10n.legalityManual, style: context.text.labelSmall!.copyWith(color: tokens.muted)),
                        ]),
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Punto de aviso para un hueco con problemas de legalidad.
class LegalityDot extends StatelessWidget {
  const LegalityDot({super.key, required this.count, this.size = 16});
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: context.l10n.legalityTitle(count),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: warningColor,
            shape: BoxShape.circle,
            border: Border.all(color: context.tokens.base, width: 2),
          ),
          child: Icon(Icons.priority_high_rounded, size: size * 0.62, color: const Color(0xFF3A2500)),
        ),
      );
}
