import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/arca_repository.dart';
import '../../data/arca_session.dart';
import '../../data/folder/arca_folder.dart';
import '../../data/folder/arca_main_files.dart';
import '../../data/folder/folder_access.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../detail/snapshot_history.dart' show saveMainAsNewCopy;
import '../onboarding/folder_flows.dart';

final _snapshotCountProvider = StreamProvider<int>((ref) => ref.watch(arcaRepositoryProvider).watchSnapshotCount());

/// Ajustes → Carpeta del Arca: dónde está, estado del último reindexado,
/// problemas, saves sueltos para adoptar y cambio de carpeta.
class ArcaFolderSection extends ConsumerStatefulWidget {
  const ArcaFolderSection({super.key});

  @override
  ConsumerState<ArcaFolderSection> createState() => _ArcaFolderSectionState();
}

class _ArcaFolderSectionState extends ConsumerState<ArcaFolderSection> {
  bool _reindexing = false;
  final Set<String> _adopting = {};

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

  Future<void> _saveMain(String path) async {
    setState(() => _adopting.add(path));
    await saveMainAsNewCopy(context, ref, path);
    if (mounted) setState(() => _adopting.remove(path));
  }

  Future<void> _adopt(List<String> paths) async {
    setState(() => _adopting.addAll(paths));
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final repo = ref.read(arcaRepositoryProvider);
    final lines = <String>[];
    for (final path in paths) {
      final out = await repo.adopt(path);
      lines.add(switch (out) {
        ImportAdded(:final save) || ImportDuplicate(:final save) => l10n.adoptDone(
          '${lang == 'en' ? save.game.nameEn : save.game.nameEs} · ${save.trainer.name}',
        ),
        ImportFailed(:final fileName, :final reason) => '$fileName: $reason',
      });
    }
    if (!mounted) return;
    setState(() => _adopting.removeAll(paths));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(lines.join('\n')), duration: const Duration(seconds: 5)));
  }

  String _issueText(BuildContext context, ArcaIssueKind k) => switch (k) {
    ArcaIssueKind.missingSave => context.l10n.issueMissingSave,
    ArcaIssueKind.missingSidecar => context.l10n.issueMissingSidecar,
    ArcaIssueKind.corruptSidecar => context.l10n.issueCorruptSidecar,
    ArcaIssueKind.sizeMismatch => context.l10n.issueSizeMismatch,
    ArcaIssueKind.hashMismatch => context.l10n.issueHashMismatch,
    ArcaIssueKind.unreadable => context.l10n.issueUnreadable,
  };

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

    final issues = report?.issues ?? const <ArcaIssue>[];
    final loose = report?.loose ?? const [];
    final modified = report?.modifiedMains ?? const <MainFileStatus>[];
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
                  stat('${issues.length}', l10n.statIssues, color: issues.isEmpty ? null : context.colors.error),
                  stat('${loose.length}', l10n.statLoose, color: loose.isEmpty ? null : context.tokens.shiny),
                  stat('${report?.ignoredCount ?? 0}', l10n.statIgnored),
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
                ],
              ),
            ],
          ),
        ),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('${l10n.issuesTitle} (${issues.length})', style: context.text.titleSmall),
          const SizedBox(height: 6),
          for (final i in issues.take(50))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.report_gmailerrorred_rounded, color: context.colors.error),
              title: Text(_issueText(context, i.kind)),
              subtitle: Text(i.detail == null ? i.path : '${i.path}\n${i.detail}', maxLines: 3),
            ),
        ],
        if (moved > 0) ...[
          const SizedBox(height: 12),
          Text(l10n.historyMigrated(moved), style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
        ],
        if (modified.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('${l10n.modifiedMainsTitle} (${modified.length})', style: context.text.titleSmall),
          Text(l10n.modifiedMainsDesc, style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
          const SizedBox(height: 6),
          for (final m in modified)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_document, color: context.tokens.shiny),
              title: Text(m.name),
              subtitle: Text(m.path),
              trailing: TextButton(
                onPressed: _adopting.isNotEmpty ? null : () => _saveMain(m.path),
                child: Text(l10n.saveAsNewCopy),
              ),
            ),
        ],
        if (loose.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text('${l10n.looseTitle} (${loose.length})', style: context.text.titleSmall)),
              TextButton(
                onPressed: _adopting.isNotEmpty ? null : () => _adopt([for (final e in loose) e.path]),
                child: Text(l10n.adoptAll),
              ),
            ],
          ),
          Text(l10n.looseDesc, style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
          const SizedBox(height: 6),
          for (final e in loose.take(100))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.sd_card_alert_rounded, color: context.tokens.shiny),
              title: Text(e.path.split('/').last),
              subtitle: Text('${e.path} · ${formatBytes(e.size)}'),
              trailing: _adopting.contains(e.path)
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(
                      onPressed: _adopting.isNotEmpty ? null : () => _adopt([e.path]),
                      child: Text(l10n.adopt),
                    ),
            ),
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
    final mono = context.text.bodySmall!.copyWith(fontFamily: 'monospace', color: context.tokens.muted);
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
