import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pkcore/pkcore.dart';

import '../../data/update/champions_update.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';

/// Pestaña «Competitivo»: todo lo de Pokémon Champions con la regulación
/// vigente (formato oficial, calculadoras, equipos y Showdown).
///
/// No hay selector de regulaciones: se usa siempre la de los datos en uso
/// (`champions.json`, que se actualiza solo), y cuando cambia, cambia todo.
class CompetitiveScreen extends ConsumerWidget {
  const CompetitiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Se reconstruye cuando llegan datos nuevos del formato.
    ref.watch(championsDataProvider);
    final l10n = context.l10n;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final pad = compact ? 16.0 : 32.0;
    final sections = [
      _Section(
        key: const ValueKey('comp-format'),
        icon: Icons.emoji_events_outlined,
        title: l10n.toolsOfficialFormat,
        body: l10n.compFormatDesc,
        route: '/competitivo/formato',
      ),
      _Section(
        key: const ValueKey('comp-stats'),
        icon: Icons.bar_chart_rounded,
        title: l10n.compStatsTitle,
        body: l10n.compStatsDesc,
        route: '/competitivo/estadisticas',
      ),
      _Section(
        key: const ValueKey('comp-showdown'),
        icon: Icons.content_paste_rounded,
        title: l10n.compShowdownTitle,
        body: l10n.compShowdownDesc,
        route: '/competitivo/showdown',
      ),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: EdgeInsets.fromLTRB(pad, compact ? 20 : 36, pad, 32),
              children: [
                Text(l10n.navCompetitive, style: compact ? context.text.displaySmall : context.text.displayMedium),
                const SizedBox(height: 6),
                Text(
                  l10n.compSubtitle(ChampionsFormat.formatName),
                  key: const ValueKey('comp-format-name'),
                  style: context.text.bodyLarge!.copyWith(color: context.tokens.muted),
                ),
                const SizedBox(height: 12),
                const RegulationNotice(),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth >= 640 ? 2 : 1;
                  final w = (c.maxWidth - (cols - 1) * 12) / cols;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [for (final s in sections) SizedBox(width: w, child: s)],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso de una línea: «Regulación M-C · hasta el … · siguiente: …».
class RegulationNotice extends ConsumerWidget {
  const RegulationNotice({super.key, this.now});

  /// Fecha de hoy (tests).
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(championsDataProvider);
    final l10n = context.l10n;
    final reg = ChampionsFormat.regulation;
    final next = ChampionsFormat.nextRegulation;
    String date(DateTime? d) => d == null ? '?' : formatDate(context, d);
    final today = now ?? DateTime.now();
    final ended = reg.until != null && !today.isBefore(reg.until!);
    final text = ended
        ? l10n.compRegulationEnded(reg.code, date(reg.until))
        : l10n.compRegulationUntil(
            reg.code,
            date(reg.until),
            next == null
                ? l10n.toolsChampionsNextNotAnnounced
                : next.from == null
                ? next.code
                : l10n.toolsChampionsNextFrom(date(next.from), next.code),
          );
    return Row(
      key: const ValueKey('comp-regulation'),
      children: [
        Icon(
          ended ? Icons.update_rounded : Icons.event_rounded,
          size: 16,
          color: ended ? context.colors.error : context.tokens.muted,
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: context.text.bodySmall!.copyWith(color: context.tokens.muted))),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({super.key, required this.icon, required this.title, required this.body, required this.route});
  final IconData icon;
  final String title;
  final String body;
  final String route;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.go(route),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: context.colors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleMedium),
                  const SizedBox(height: 4),
                  Text(body, style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.tokens.muted),
          ],
        ),
      ),
    ),
  );
}
