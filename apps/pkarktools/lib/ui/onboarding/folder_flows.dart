import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/arca_session.dart';
import '../../data/folder/arca_migration.dart';
import '../../data/folder/folder_access.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';

/// Progreso observable de una operación larga sobre la carpeta.
class FolderProgress extends ValueNotifier<(int, int)?> {
  FolderProgress() : super(null);
  void report(int done, int total) => value = (done, total);
}

/// Indicador de progreso con texto "Copiando y verificando N de M".
class FolderProgressView extends StatelessWidget {
  const FolderProgressView({super.key, required this.progress});
  final FolderProgress progress;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<(int, int)?>(
        valueListenable: progress,
        builder: (context, v, _) {
          final total = v?.$2 ?? 0;
          final done = v?.$1 ?? 0;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(minHeight: 6, value: total == 0 ? null : done / total),
            ),
            const SizedBox(height: 10),
            Text(
              total == 0 ? context.l10n.folderPreparing : context.l10n.folderProgress(done, total),
              style: context.text.bodyMedium!.copyWith(color: context.tokens.muted),
            ),
          ]);
        },
      );
}

/// Primer arranque o recuperación: abre [opened] como carpeta del Arca.
/// Devuelve null si todo fue bien o el texto del error.
Future<String?> runSetUp(WidgetRef ref, OpenedFolder opened, FolderProgress progress) async {
  try {
    final result = await ref.read(arcaSetupProvider.notifier).setUp(opened, onProgress: progress.report);
    if (result != null && !result.ok) return 'migration:${result.failures.length}';
    return null;
  } catch (e) {
    return '$e';
  }
}

/// Ajustes → Cambiar carpeta: elige destino, pregunta mover/copiar y copia
/// con progreso y verificación.
Future<void> changeArcaFolder(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final OpenedFolder? opened;
  try {
    opened = await ref.read(folderAccessProvider).pick();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.folderPickFailed('$e'))));
    return;
  }
  if (opened == null || !context.mounted) return;
  final move = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l10n.folderChangeTitle),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PathPill(opened!.location.label.isEmpty ? opened.fs.label : opened.location.label),
        const SizedBox(height: 14),
        Text(l10n.folderChangeBody),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(MaterialLocalizations.of(c).cancelButtonLabel)),
        OutlinedButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.folderCopy)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l10n.folderMove)),
      ],
    ),
  );
  if (move == null || !context.mounted) return;
  final progress = FolderProgress();
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(move ? l10n.folderMove : l10n.folderCopy),
        content: SizedBox(width: 380, child: FolderProgressView(progress: progress)),
      ),
    ),
  ));
  MigrationResult? result;
  Object? error;
  try {
    result = await ref.read(arcaSetupProvider.notifier).changeFolder(opened, move: move, onProgress: progress.report);
  } catch (e) {
    error = e;
  }
  navigator.pop();
  progress.dispose();
  final text = error != null
      ? l10n.folderPickFailed('$error')
      : [
          l10n.folderChangeDone(result!.copied, result.skipped),
          if (!result.ok) l10n.migrationFailures(result.failures.length),
          if (result.leftBehind > 0) l10n.folderLeftBehind(result.leftBehind),
        ].join(' ');
  messenger.showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 6)));
}

class _PathPill extends StatelessWidget {
  const _PathPill(this.path);
  final String path;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: context.tokens.sunken, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(Icons.folder_rounded, size: 18, color: context.colors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(path, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
      );
}

/// Nombre de marca de cada servicio (igual en todos los idiomas).
String syncProviderName(SyncProvider p) => switch (p) {
      SyncProvider.iCloud => 'iCloud Drive',
      SyncProvider.googleDrive => 'Google Drive',
      SyncProvider.oneDrive => 'OneDrive',
      SyncProvider.dropbox => 'Dropbox',
      SyncProvider.syncthing => 'Syncthing',
      SyncProvider.none => '',
    };
