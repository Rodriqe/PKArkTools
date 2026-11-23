import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/arca_repository.dart';
import '../../data/db/arca_database.dart';
import '../../data/folder/arca_layout.dart';
import '../../data/folder/arca_main_files.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';

/// Versión actual de la partida (destacada) y, plegado debajo, el historial
/// de copias con exportar/restaurar/comparar.
class SnapshotHistory extends ConsumerWidget {
  const SnapshotHistory({
    super.key,
    required this.snapshots,
    required this.selectedId,
    required this.onSelect,
    this.onCompare,
    this.initiallyExpanded = false,
  });

  final List<Snapshot> snapshots;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  /// Compara dos snapshots (antes, después).
  final void Function(int before, int after)? onCompare;

  /// Historial desplegado al abrir (capturas).
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (snapshots.isEmpty) return const SizedBox.shrink();
    // Con qué copia se compara cada una: la seleccionada, o la anterior si es ella misma.
    VoidCallback? compare(int i) {
      if (onCompare == null || snapshots.length < 2) return null;
      final sel = snapshots.indexWhere((s) => s.id == selectedId);
      final other = sel >= 0 && sel != i ? sel : (i + 1 < snapshots.length ? i + 1 : i - 1);
      // Índice mayor = más antiguo.
      final (older, newer) = other > i ? (other, i) : (i, other);
      return () => onCompare!(snapshots[older].id, snapshots[newer].id);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CurrentVersionCard(latest: snapshots.first, selected: snapshots.first.id == selectedId, onSelect: () => onSelect(snapshots.first.id)),
      const SizedBox(height: 16),
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const ValueKey('history-fold'),
          initiallyExpanded: initiallyExpanded,
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(l10n.historyCount(snapshots.length), style: context.text.titleLarge),
          subtitle: Text(l10n.historyFoldedHint, style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
          children: [
            const SizedBox(height: 8),
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
          ],
        ),
      ),
    ]);
  }
}

/// «Versión actual · fecha»: el archivo principal de la carpeta, con
/// Exportar / Abrir carpeta y el aviso si se cambió a mano.
class CurrentVersionCard extends ConsumerWidget {
  const CurrentVersionCard({super.key, required this.latest, this.selected = false, this.onSelect});
  final Snapshot latest;
  final bool selected;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final primary = context.colors.primary;
    final s = latest;
    final mainPath = ArcaRepository.mainPathOf(s);
    final mainName = mainPath?.split('/').last ?? s.fileName;
    final report = ref.watch(reindexReportProvider).value;
    final ownerDir = mainPath == null ? null : ArcaLayout.ownerDirOf(mainPath);
    final modified = report?.modifiedMains.where((m) => m.path == mainPath || (ownerDir != null && m.ownerDir == ownerDir)).firstOrNull;

    return Material(
      color: primary.withValues(alpha: selected ? 0.12 : 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: primary.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.bookmark_rounded, color: primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.currentVersionTitle(formatDate(context, s.importedAt, withTime: true)),
                    style: context.text.titleMedium),
              ),
            ]),
            const SizedBox(height: 6),
            Text(l10n.mainFileLabel(mainName), style: context.text.bodySmall!.copyWith(color: tokens.muted)),
            const SizedBox(height: 2),
            Text(
              '${originLabel(context, s.origin)}, ${formatPlayTime(Duration(seconds: s.playTimeSeconds))}, ${formatBytes(s.sizeBytes)}',
              style: context.text.bodySmall!.copyWith(color: tokens.muted),
            ),
            if (modified != null) ...[
              const SizedBox(height: 10),
              _ModifiedMainNotice(status: modified),
            ],
            const SizedBox(height: 4),
            Wrap(spacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              TextButton.icon(
                style: _compact,
                onPressed: () => exportSnapshot(context, ref, s, asMain: true),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: Text(l10n.export),
              ),
              TextButton.icon(
                style: _compact,
                onPressed: ownerDir == null ? null : () => openSaveFolder(context, ref, ownerDir),
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: Text(l10n.openFolder),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _ModifiedMainNotice extends ConsumerStatefulWidget {
  const _ModifiedMainNotice({required this.status});
  final MainFileStatus status;

  @override
  ConsumerState<_ModifiedMainNotice> createState() => _ModifiedMainNoticeState();
}

class _ModifiedMainNoticeState extends ConsumerState<_ModifiedMainNotice> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = context.tokens.shiny;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.edit_document, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.mainModifiedTitle, style: context.text.titleSmall),
              const SizedBox(height: 2),
              Text(l10n.mainModifiedBody(widget.status.name), style: context.text.bodySmall),
            ]),
          ),
        ]),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: _busy ? null : () => _save(context),
            child: Text(l10n.saveAsNewCopy),
          ),
        ),
      ]),
    );
  }

  Future<void> _save(BuildContext context) async {
    setState(() => _busy = true);
    await saveMainAsNewCopy(context, ref, widget.status.path);
    if (mounted) setState(() => _busy = false);
  }
}

/// Guarda en el historial un archivo principal cambiado a mano.
Future<void> saveMainAsNewCopy(BuildContext context, WidgetRef ref, String mainPath) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final out = await ref.read(arcaRepositoryProvider).saveMainAsCopy(mainPath);
  messenger.showSnackBar(SnackBar(
    content: Text(switch (out) {
      ImportFailed(:final reason) => reason,
      _ => l10n.savedAsNewCopy(mainPath.split('/').last),
    }),
  ));
}

/// Abre la carpeta de la partida en el gestor de archivos (escritorio) o
/// muestra su ruta dentro del Arca (móvil, SAF).
Future<void> openSaveFolder(BuildContext context, WidgetRef ref, String ownerDir) async {
  final repo = ref.read(arcaRepositoryProvider);
  final l10n = context.l10n;
  final native = repo.hasFolder ? repo.folder.fs.nativePath : null;
  if (native != null) {
    final abs = p.joinAll([native, ...repo.folder.prefix.split('/'), ...ownerDir.split('/')].where((e) => e.isNotEmpty));
    if (await ref.read(fileSourcesProvider).revealFolder(abs)) return;
  }
  if (!context.mounted) return;
  final rel = [if (repo.hasFolder && repo.folder.prefix.isNotEmpty) repo.folder.prefix, ownerDir].join('/');
  final root = repo.hasFolder ? repo.folder.label : '';
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.openFolderTitle),
      content: SelectableText(l10n.openFolderBody(root, '$rel/')),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: '$rel/'));
            if (ctx.mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.pathCopied)));
            }
          },
          child: Text(l10n.copyPath),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(MaterialLocalizations.of(ctx).okButtonLabel)),
      ],
    ),
  );
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

Future<void> exportSnapshot(BuildContext context, WidgetRef ref, Snapshot s, {bool asMain = false}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final repo = ref.read(arcaRepositoryProvider);
    final bytes = await repo.snapshotBytes(s);
    final String name;
    if (asMain) {
      // La versión actual se exporta con el nombre que espera el juego.
      name = ArcaRepository.mainPathOf(s)?.split('/').last ?? s.fileName;
    } else {
      final stamp = s.importedAt.toIso8601String().substring(0, 19).replaceAll(':', '-');
      name = '${p.basenameWithoutExtension(s.fileName)}_$stamp${p.extension(s.fileName)}';
    }
    final path = await ref.read(fileSourcesProvider).exportBytes(name, bytes);
    if (path != null) messenger.showSnackBar(SnackBar(content: Text(l10n.exportDone(path))));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed('$e'))));
  }
}

/// Restaura una copia como versión actual: entrada nueva del historial
/// (origen «restaurada») y archivo principal actualizado. Si el archivo
/// original es accesible, se puede escribir también ahí, guardando antes en
/// el Arca su contenido actual (nunca se pierde nada).
Future<void> restoreSnapshot(BuildContext context, WidgetRef ref, Snapshot s) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final sources = ref.read(fileSourcesProvider);
  final path = s.sourcePath;
  final inPlace = sources.canRestoreInPlace(path);
  final mainName = ArcaRepository.mainPathOf(s)?.split('/').last ?? s.fileName;
  final choice = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.restoreAsCurrentTitle),
      content: Text(l10n.restoreAsCurrentBody(mainName)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 0), child: Text(l10n.cancel)),
        if (inPlace) TextButton(onPressed: () => Navigator.pop(ctx, 2), child: Text(l10n.restoreAlsoSource)),
        FilledButton(onPressed: () => Navigator.pop(ctx, 1), child: Text(l10n.restore)),
      ],
    ),
  );
  if (choice == null || choice == 0 || !context.mounted) return;
  final note = l10n.restoredNote(formatDate(context, s.importedAt, withTime: true));
  try {
    final repo = ref.read(arcaRepositoryProvider);
    final out = await repo.restoreAsCurrent(s, note: note);
    if (out is ImportFailed) throw StateError(out.reason);
    if (choice == 2) {
      final current = await sources.readSource(path!);
      if (current != null && ArcaRepository.sha256Of(current) != s.sha256) {
        await repo.importBytes(current, fileName: p.basename(path), origin: ImportOrigin.restoreBackup, sourcePath: path);
      }
      await sources.writeSource(path, await repo.snapshotBytes(s));
      messenger.showSnackBar(SnackBar(content: Text(l10n.restoreDone)));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(l10n.restoredAsCurrent)));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.restoreFailed('$e'))));
  }
}
