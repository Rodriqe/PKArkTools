import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/arca_session.dart';
import '../../data/folder/folder_access.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';
import 'arca_problems_section.dart';
import 'game_folders.dart';
import '../onboarding/folder_flows.dart';

final _snapshotCountProvider = StreamProvider<int>((ref) => ref.watch(arcaRepositoryProvider).watchSnapshotCount());

/// Ajustes → Carpeta del Arca: dónde está, estado del último reindexado,
/// resumen plegable de problemas (con Arreglar/Ignorar) y cambio de carpeta.
class ArcaFolderSection extends ConsumerStatefulWidget {
  const ArcaFolderSection({super.key});

  @override
  ConsumerState<ArcaFolderSection> createState() => _ArcaFolderSectionState();
}

class _ArcaFolderSectionState extends ConsumerState<ArcaFolderSection> {
  bool _reindexing = false;

  Future<void> _reindex() async {
    setState(() => _reindexing = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final r = await ref.read(arcaSetupProvider.notifier).reindex();
    if (!mounted) return;
    setState(() => _reindexing = false);
    if (r != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.reindexResult(r.added, r.removed, r.duplicates))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final setup = ref.watch(arcaSetupProvider);
    final repo = ref.watch(arcaRepositoryProvider);
    final report = ref.watch(reindexReportProvider).value ?? repo.lastReport;
    final count = ref.watch(_snapshotCountProvider).value ?? 0;
    final location = setup is SetupReady ? setup.location : null;
    final label = repo.hasFolder ? repo.folder.label : (location?.label ?? '');
    final provider = location?.kind == LocationKind.appLocal ? SyncProvider.none : detectSyncProvider(label);
    final synced = provider != SyncProvider.none;
    final arcaPath = repo.hasFolder && repo.folder.prefix.isNotEmpty ? '$label/${repo.folder.prefix}' : label;

    Widget stat(String value, String name, {Color? color}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: context.text.titleLarge!.copyWith(color: color, fontFamily: AppTheme.display),
        ),
        Text(name, style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
      ],
    );

    final problems = ref.watch(visibleArcaProblemsProvider).shown;
    final moved = (report?.historyMigration?.copied ?? 0) + (report?.historyMigration?.skipped ?? 0);
    final time = report == null
        ? null
        : DateFormat.Hms(Localizations.localeOf(context).toLanguageTag()).format(report.at);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.tokens.raised,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.tokens.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      synced ? Icons.cloud_sync_rounded : Icons.folder_rounded,
                      color: context.colors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          synced
                              ? l10n.folderSynced(syncProviderName(provider))
                              : (location?.kind == LocationKind.appLocal ? l10n.folderAppLocal : l10n.folderLocalOnly),
                          style: context.text.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          arcaPath,
                          style: context.text.bodySmall!.copyWith(color: context.tokens.muted),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 28,
                runSpacing: 12,
                children: [
                  stat('$count', l10n.statBackups),
                  stat('${problems.length}', l10n.statIssues,
                      color: problems.isEmpty ? null : (problems.any((p) => p.kind.isError) ? context.colors.error : context.tokens.shiny)),
                ],
              ),
              const SizedBox(height: 16),
              _LayoutExplainer(),
              const SizedBox(height: 14),
              Text(
                time == null ? l10n.reindexNever : l10n.reindexLast(time),
                style: context.text.bodySmall!.copyWith(color: context.tokens.muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _reindexing ? null : _reindex,
                    icon: _reindexing
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync_rounded),
                    label: Text(l10n.folderReindex),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => changeArcaFolder(context, ref),
                    icon: const Icon(Icons.drive_file_move_rounded),
                    label: Text(l10n.folderChange),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('create-game-folders'),
                    onPressed: () => createGameFolders(context, ref),
                    icon: const Icon(Icons.create_new_folder_rounded),
                    label: Text(l10n.gameFoldersCreate),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const ArcaProblemsPanel(),
        if (moved > 0) ...[
          const SizedBox(height: 12),
          Text(l10n.historyMigrated(moved), style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
        ],
        if ((report?.ignoredCount ?? 0) > 0) ...[
          const SizedBox(height: 10),
          Text(
            l10n.ignoredFiles(report!.ignoredCount),
            style: context.text.bodySmall!.copyWith(color: context.tokens.muted),
          ),
        ],
      ],
    );
  }
}

/// Explicación corta del diseño de la carpeta (última versión + historial/).
class _LayoutExplainer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mono = context.text.bodySmall!.copyWith(color: context.tokens.muted, height: 1.5);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.arcaLayoutTitle, style: context.text.titleSmall),
        const SizedBox(height: 4),
        Text(l10n.arcaLayoutDesc, style: context.text.bodySmall),
        const SizedBox(height: 8),
        Text(
          context.isSpanish
              ? 'PKArkTools/<Juego>/<Entrenador (TID)>/\n  main            ← última versión\n  historial/      ← todas las copias'
              : 'PKArkTools/<Game>/<Trainer (TID)>/\n  main            ← latest version\n  historial/      ← every copy',
          style: mono,
        ),
      ]),
    );
  }
}
