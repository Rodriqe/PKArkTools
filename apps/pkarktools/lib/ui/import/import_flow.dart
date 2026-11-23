import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pkcore/testing.dart';

import 'package:pkcore/pkcore.dart' show GameVersion;

import '../../data/arca_archive.dart';
import '../../data/arca_repository.dart';
import '../../data/file_sources.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';

/// Abre el selector "Añadir al Arca" (hoja inferior en móvil, diálogo en escritorio).
Future<void> showImportChooser(BuildContext context, WidgetRef ref) async {
  final wide = MediaQuery.sizeOf(context).width >= 720;
  final child = _ImportChooser(onPick: (kind) async {
    Navigator.of(context, rootNavigator: true).pop();
    if (kind == _ImportKind.file) {
      await importFiles(context, ref);
    } else {
      await importFolder(context, ref);
    }
  });
  if (wide) {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: child)),
    );
  } else {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => child);
  }
}

enum _ImportKind { file, folder }

class _ImportChooser extends StatelessWidget {
  const _ImportChooser({required this.onPick});
  final void Function(_ImportKind) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.importSheetTitle, style: context.text.headlineMedium),
            const SizedBox(height: 20),
            _Option(
              icon: Icons.upload_file_rounded,
              title: l10n.importFile,
              body: l10n.importFileDesc,
              onTap: () => onPick(_ImportKind.file),
            ),
            const SizedBox(height: 12),
            _Option(
              icon: Icons.folder_open_rounded,
              title: l10n.importFolder,
              body: l10n.importFolderDesc,
              onTap: () => onPick(_ImportKind.folder),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.icon, required this.title, required this.body, required this.onTap});
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: tokens.sunken,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: context.colors.primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: context.colors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleMedium),
                    const SizedBox(height: 4),
                    Text(body, style: context.text.bodyMedium!.copyWith(color: tokens.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Importa archivos sueltos elegidos con el selector del sistema.
Future<void> importFiles(BuildContext context, WidgetRef ref) async {
  final sources = ref.read(fileSourcesProvider);
  final picked = await sources.pickFiles();
  if (picked.isEmpty || !context.mounted) return;
  if (picked.length == 1) {
    await runImport(context, ref, picked);
    return;
  }
  final scan = await sources.scanPicked(picked);
  if (context.mounted) await _reviewAndImport(context, ref, scan);
}

/// Exporta el Arca completa como zip con manifiesto.
Future<void> exportArcaZip(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final (bytes, count) = await ArcaArchive.export(ref.read(arcaRepositoryProvider));
  if (count == 0) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.archiveEmpty)));
    return;
  }
  final now = DateTime.now();
  final name = 'PKArkTools-Arca_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.zip';
  final path = await ref.read(fileSourcesProvider).exportBytes(name, bytes);
  if (path != null) messenger.showSnackBar(SnackBar(content: Text(l10n.archiveExported(count))));
}

/// Restaura un zip exportado y muestra el resumen.
Future<void> restoreArcaZip(BuildContext context, WidgetRef ref) async {
  final zip = await ref.read(fileSourcesProvider).pickZip();
  if (zip == null || !context.mounted) return;
  try {
    final outcomes = await ArcaArchive.restore(ref.read(arcaRepositoryProvider), zip);
    if (context.mounted) await showDialog<void>(context: context, builder: (_) => ImportSummaryDialog(outcomes: outcomes));
  } on FormatException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.archiveInvalid)));
    }
  }
}

/// Pide una carpeta, la escanea y deja elegir qué saves importar.
Future<void> importFolder(BuildContext context, WidgetRef ref) async {
  final sources = ref.read(fileSourcesProvider);
  final progress = ValueNotifier<int>(0);
  var dialogOpen = false;
  final scanFuture = sources.pickAndScanFolder(onProgress: (n) {
    progress.value = n;
    if (!dialogOpen && context.mounted) {
      dialogOpen = true;
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ProgressDialog(progress: progress),
      ));
    }
  });
  FolderScan? scan;
  try {
    scan = await scanFuture;
  } finally {
    if (dialogOpen && context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
  if (scan == null || !context.mounted) return;
  await _reviewAndImport(context, ref, scan);
}

Future<void> _reviewAndImport(BuildContext context, WidgetRef ref, FolderScan scan) async {
  final known = await ref.read(arcaRepositoryProvider).knownHashes();
  if (!context.mounted) return;
  final chosen = await showDialog<List<PickedSave>>(context: context, builder: (_) => BulkImportDialog(scan: scan, known: known));
  if (chosen == null || chosen.isEmpty || !context.mounted) return;
  await runImport(context, ref, chosen);
}

/// Añade al Arca el conjunto de partidas sintéticas de demostración.
Future<void> loadDemo(BuildContext context, WidgetRef ref) async {
  final picked = [
    for (final MapEntry(:key, :value) in SyntheticSaves.demoSet().entries)
      PickedSave(name: key, bytes: value, origin: ImportOrigin.demo),
  ];
  await runImport(context, ref, picked, showSummary: false);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.demoLoaded(picked.length))));
  }
}

Future<List<ImportOutcome>> runImport(BuildContext context, WidgetRef ref, List<PickedSave> files,
    {bool showSummary = true}) async {
  final repo = ref.read(arcaRepositoryProvider);
  final outcomes = <ImportOutcome>[];
  // Importaciones grandes (y sobre todo en un NAS, donde cada copia son varias
  // idas y vueltas): diálogo con «Importando N de M».
  final progress = ValueNotifier<(int, int)>((0, files.length));
  final showProgress = files.length >= importProgressThreshold && context.mounted;
  if (showProgress) {
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportProgressDialog(progress: progress),
    ));
  }
  try {
    for (final f in files) {
      outcomes.add(await repo.importBytes(f.bytes, fileName: f.name, origin: f.origin, sourcePath: f.sourcePath));
      progress.value = (outcomes.length, files.length);
    }
  } finally {
    if (showProgress && context.mounted) Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();
  }
  if (showSummary && context.mounted) {
    await showDialog<void>(context: context, builder: (_) => ImportSummaryDialog(outcomes: outcomes));
  }
  return outcomes;
}

/// A partir de cuántos archivos se muestra el progreso de la importación.
const importProgressThreshold = 4;

/// «Importando N de M» con barra de progreso.
class ImportProgressDialog extends StatelessWidget {
  const ImportProgressDialog({super.key, required this.progress});
  final ValueListenable<(int, int)> progress;

  @override
  Widget build(BuildContext context) => AlertDialog(
        content: ValueListenableBuilder<(int, int)>(
          valueListenable: progress,
          builder: (context, v, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.l10n.importProgress('${v.$1}', '${v.$2}')),
            const SizedBox(height: 14),
            LinearProgressIndicator(value: v.$2 == 0 ? null : v.$1 / v.$2),
          ]),
        ),
      );
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.progress});
  final ValueListenable<int> progress;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(children: [
        const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
        const SizedBox(width: 20),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (context, n, _) => Text(context.l10n.folderScanning(n)),
          ),
        ),
      ]),
    );
  }
}

/// Resumen previo de una importación en bloque: qué es nuevo, qué ya está en el
/// Arca, qué se repite dentro de la selección y qué no se reconoce.
class BulkImportDialog extends StatefulWidget {
  const BulkImportDialog({super.key, required this.scan, required this.known});
  final FolderScan scan;

  /// SHA-256 ya presentes en el Arca.
  final Set<String> known;

  @override
  State<BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends State<BulkImportDialog> {
  late final List<FolderCandidate> _new;
  late final List<FolderCandidate> _dupes;
  late final List<FolderCandidate> _repeated;
  late final Set<int> _selected;
  bool _showUnknown = false;

  @override
  void initState() {
    super.initState();
    _new = [];
    _dupes = [];
    _repeated = [];
    final seen = <String>{};
    for (final c in widget.scan.found) {
      final sha = ArcaRepository.sha256Of(c.file.bytes);
      if (widget.known.contains(sha)) {
        _dupes.add(c);
      } else if (!seen.add(sha)) {
        _repeated.add(c);
      } else {
        _new.add(c);
      }
    }
    _selected = {for (var i = 0; i < _new.length; i++) i};
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final scan = widget.scan;
    final byGame = <GameVersion, List<int>>{};
    for (var i = 0; i < _new.length; i++) {
      byGame.putIfAbsent(_new[i].game, () => []).add(i);
    }

    Widget stat(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: context.text.bodyLarge)),
          ]),
        );

    return AlertDialog(
      title: Text(l10n.bulkTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (scan.rootLabel.isNotEmpty) ...[
              Text(scan.rootLabel, style: context.text.labelMedium!.copyWith(color: tokens.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(l10n.bulkSubfolders(scan.scanned + scan.ignored), style: context.text.bodySmall!.copyWith(color: tokens.muted)),
              const SizedBox(height: 14),
            ],
            stat(Icons.add_circle_outline_rounded, context.colors.primary, l10n.bulkDetected(_new.length)),
            if (_dupes.isNotEmpty) stat(Icons.inventory_2_outlined, tokens.muted, l10n.bulkDuplicates(_dupes.length)),
            if (_repeated.isNotEmpty) stat(Icons.copy_all_rounded, tokens.muted, l10n.bulkRepeated(_repeated.length)),
            if (scan.unrecognized.isNotEmpty)
              InkWell(
                onTap: () => setState(() => _showUnknown = !_showUnknown),
                child: stat(Icons.help_outline_rounded, context.colors.error, l10n.bulkUnrecognized(scan.unrecognized.length)),
              ),
            if (_showUnknown)
              Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 8),
                child: Text(scan.unrecognized.take(40).join('\n'),
                    style: context.text.bodySmall!.copyWith(color: tokens.muted)),
              ),
            if (scan.ignored > 0)
              Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 8),
                child: Text(l10n.bulkIgnored(scan.ignored), style: context.text.bodySmall!.copyWith(color: tokens.muted)),
              ),
            if (_new.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(scan.found.isEmpty ? l10n.folderNoneHint : l10n.bulkNothingNew,
                    style: context.text.bodyMedium!.copyWith(color: tokens.muted)),
              ),
            for (final MapEntry(key: game, value: idx) in byGame.entries) ...[
              const SizedBox(height: 14),
              Text(gameTitle(context, game), style: context.text.titleSmall),
              for (final i in idx)
                CheckboxListTile(
                  value: _selected.contains(i),
                  onChanged: (v) => setState(() => v! ? _selected.add(i) : _selected.remove(i)),
                  title: Text(_new[i].trainer),
                  subtitle: Text(_new[i].relativePath, maxLines: 2, overflow: TextOverflow.ellipsis),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        if (_new.isNotEmpty)
          FilledButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, [for (final i in _selected.toList()..sort()) _new[i].file]),
            child: Text(l10n.bulkImportNew(_selected.length)),
          ),
      ],
    );
  }
}

class ImportSummaryDialog extends StatelessWidget {
  const ImportSummaryDialog({super.key, required this.outcomes});
  final List<ImportOutcome> outcomes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final added = outcomes.whereType<ImportAdded>().toList();
    final dup = outcomes.whereType<ImportDuplicate>().toList();
    final failed = outcomes.whereType<ImportFailed>().toList();
    final single = outcomes.length == 1 && (added.isNotEmpty || dup.isNotEmpty);
    final slotId = added.isNotEmpty ? added.first.slotId : (dup.isNotEmpty ? dup.first.slotId : null);

    return AlertDialog(
      title: Text(l10n.importResultTitle),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (added.isNotEmpty) _line(context, Icons.check_circle_rounded, context.colors.primary, l10n.importAdded(added.length)),
              if (dup.isNotEmpty) _line(context, Icons.inventory_2_rounded, context.tokens.muted, l10n.importDuplicates(dup.length)),
              if (failed.isNotEmpty) ...[
                _line(context, Icons.error_outline_rounded, context.colors.error, l10n.importFailedCount(failed.length)),
                for (final f in failed)
                  Padding(
                    padding: const EdgeInsets.only(left: 36, bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f.fileName, style: context.text.titleSmall),
                      Text(f.reason, style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
                    ]),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (single && slotId != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/arca/save/$slotId');
            },
            child: Text(l10n.openSave),
          ),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.done)),
      ],
    );
  }

  Widget _line(BuildContext context, IconData icon, Color color, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: context.text.bodyLarge)),
        ]),
      );
}
