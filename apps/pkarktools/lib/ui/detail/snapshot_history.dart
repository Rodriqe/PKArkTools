import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/arca_repository.dart';
import '../../data/db/arca_database.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';

/// Historial de snapshots de una partida con exportar/restaurar.
class SnapshotHistory extends ConsumerWidget {
  const SnapshotHistory(
      {super.key, required this.snapshots, required this.selectedId, required this.onSelect, this.onCompare});

  final List<Snapshot> snapshots;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  /// Compara dos snapshots (antes, después).
  final void Function(int before, int after)? onCompare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Con qué copia se compara cada una: la seleccionada, o la anterior si es ella misma.
    VoidCallback? compare(int i) {
      if (onCompare == null || snapshots.length < 2) return null;
      final sel = snapshots.indexWhere((s) => s.id == selectedId);
      final other = sel >= 0 && sel != i ? sel : (i + 1 < snapshots.length ? i + 1 : i - 1);
      // Índice mayor = más antiguo.
      final (older, newer) = other > i ? (other, i) : (i, other);
      return () => onCompare!(snapshots[older].id, snapshots[newer].id);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.history, style: context.text.headlineMedium),
      const SizedBox(height: 14),
      // Línea de tiempo: las copias sí son una secuencia, del más reciente al más antiguo.
      for (var i = 0; i < snapshots.length; i++)
        _SnapshotTile(
          snapshot: snapshots[i],
          latest: i == 0,
          last: i == snapshots.length - 1,
          selected: snapshots[i].id == selectedId,
          onSelect: () => onSelect(snapshots[i].id),
          onCompare: compare(i),
        ),
    ]);
  }
}

class _SnapshotTile extends ConsumerWidget {
  const _SnapshotTile({
    required this.snapshot,
    required this.latest,
    required this.last,
    required this.selected,
    required this.onSelect,
    this.onCompare,
  });

  final Snapshot snapshot;
  final bool latest;
  final bool last;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback? onCompare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final primary = context.colors.primary;
    final s = snapshot;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 22,
          child: Column(children: [
            const SizedBox(height: 20),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? primary : tokens.raised,
                border: Border.all(color: selected ? primary : tokens.muted, width: 2),
              ),
            ),
            if (!last) Expanded(child: Container(width: 2, color: tokens.hairline)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: selected ? primary.withValues(alpha: 0.08) : tokens.raised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: selected ? primary.withValues(alpha: 0.5) : tokens.hairline),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onSelect,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(formatDate(context, s.importedAt, withTime: true), style: context.text.titleSmall),
                      ),
                      if (latest)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: primary.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
                          child: Text(l10n.latest, style: context.text.labelSmall!.copyWith(color: primary)),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      '${s.fileName}\n${originLabel(context, s.origin)}, ${formatPlayTime(Duration(seconds: s.playTimeSeconds))}, ${formatBytes(s.sizeBytes)}',
                      style: context.text.bodySmall!.copyWith(color: tokens.muted),
                    ),
                    const SizedBox(height: 4),
                    Tooltip(
                      message: 'SHA-256 ${s.sha256}',
                      child: Text(s.sha256.substring(0, 12),
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall!.copyWith(color: tokens.muted, fontFeatures: const [FontFeature.tabularFigures()])),
                    ),
                    Wrap(spacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      if (onCompare != null)
                        TextButton.icon(
                          style: _compact,
                          onPressed: onCompare,
                          icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                          label: Text(l10n.compareAction),
                        ),
                      TextButton(style: _compact, onPressed: () => exportSnapshot(context, ref, s), child: Text(l10n.export)),
                      TextButton(style: _compact, onPressed: () => restoreSnapshot(context, ref, s), child: Text(l10n.restore)),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

final _compact = TextButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 10),
  minimumSize: const Size(0, 36),
  visualDensity: VisualDensity.compact,
);

Future<void> exportSnapshot(BuildContext context, WidgetRef ref, Snapshot s) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final repo = ref.read(arcaRepositoryProvider);
    final bytes = await repo.snapshotBytes(s);
    final stamp = s.importedAt.toIso8601String().substring(0, 19).replaceAll(':', '-');
    final ext = p.extension(s.fileName);
    final base = p.basenameWithoutExtension(s.fileName);
    final path = await ref.read(fileSourcesProvider).exportBytes('${base}_$stamp$ext', bytes);
    if (path != null) messenger.showSnackBar(SnackBar(content: Text(l10n.exportDone(path))));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed('$e'))));
  }
}

/// Restaura un snapshot sobre su archivo original, guardando antes en el
/// Arca una copia del contenido actual (nunca se pierde nada).
Future<void> restoreSnapshot(BuildContext context, WidgetRef ref, Snapshot s) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final sources = ref.read(fileSourcesProvider);
  final path = s.sourcePath;
  if (!sources.canRestoreInPlace(path)) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.restoreUnavailable)));
    await exportSnapshot(context, ref, s);
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.restoreTitle),
      content: Text(l10n.restoreBody(path!)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.restore)),
      ],
    ),
  );
  if (ok != true) return;
  try {
    final repo = ref.read(arcaRepositoryProvider);
    final current = await sources.readSource(path!);
    if (current != null && ArcaRepository.sha256Of(current) != s.sha256) {
      await repo.importBytes(current, fileName: p.basename(path), origin: ImportOrigin.restoreBackup, sourcePath: path);
    }
    await sources.writeSource(path, await repo.snapshotBytes(s));
    messenger.showSnackBar(SnackBar(content: Text(l10n.restoreDone)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.restoreFailed('$e'))));
  }
}
