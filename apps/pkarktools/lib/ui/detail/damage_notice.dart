import 'package:flutter/material.dart';
import 'package:pkcore/pkcore.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';

/// Color de los avisos leves (los graves usan `colorScheme.error`).
const damageMinorColor = Color(0xFFE0A030);

/// Aviso de un save abierto en solo lectura por daño: qué parte falla, qué
/// significa, por qué puede pasar y qué hacer, con el detalle técnico
/// desplegable para usuarios avanzados.
class DamageNotice extends StatelessWidget {
  const DamageNotice({super.key, required this.editor, this.onRepairExport});

  final SaveEditor editor;

  /// Acción «Reparar checksums y exportar» (solo daño leve).
  final VoidCallback? onRepairExport;

  static String partText(AppLocalizations l10n, SavePart part) => switch (part) {
    SavePart.whole => l10n.damagePartWhole,
    SavePart.trainer => l10n.damagePartTrainer,
    SavePart.party => l10n.damagePartParty,
    SavePart.boxes => l10n.damagePartBoxes,
    SavePart.other => l10n.damagePartOther,
    SavePart.signature => l10n.damagePartSignature,
    SavePart.fileHash => l10n.damagePartFileHash,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final minor = editor.damage == SaveDamage.minor;
    final accent = minor ? damageMinorColor : context.colors.error;
    final parts = <String>[
      if (editor.readErrors.isNotEmpty) l10n.damagePartUnreadable,
      for (final part in {for (final p in editor.checksumProblems) p.part}) partText(l10n, part),
    ];
    final technical = [for (final p in editor.checksumProblems) p.detail, ...editor.readErrors];
    final body = context.text.bodyMedium;
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(minor ? Icons.lock_outline_rounded : Icons.report_rounded, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(minor ? l10n.damageMinorTitle : l10n.damageMajorTitle, style: context.text.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final t in parts)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10, left: 4),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                  ),
                  Expanded(
                    child: Text(t, style: body?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(minor ? l10n.damageMinorMeaning : l10n.damageMajorMeaning, style: body),
          const SizedBox(height: 8),
          Text(l10n.damageWhy, style: body?.copyWith(color: context.tokens.muted)),
          const SizedBox(height: 8),
          Text(minor ? l10n.damageMinorTodo : l10n.damageMajorTodo, style: body),
          if (minor && onRepairExport != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRepairExport,
              icon: const Icon(Icons.build_circle_outlined),
              label: Text(l10n.damageRepairExport),
            ),
          ],
          // Material propio: el ListTile del desplegable pinta sobre el fondo del aviso.
          Material(
            type: MaterialType.transparency,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: Text(l10n.damageTechnical, style: context.text.labelLarge),
                children: [
                  SelectableText(
                    technical.join('\n'),
                    style: body?.copyWith(fontFamily: 'monospace', fontSize: 12.5, color: context.tokens.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta corta del estado de verificación (nunca «checksum mismatch» a secas).
String damageChipLabel(AppLocalizations l10n, SaveDamage damage) => switch (damage) {
  SaveDamage.none => l10n.checksumValid,
  SaveDamage.minor => l10n.checksumMinor,
  SaveDamage.major => l10n.checksumMajor,
};
