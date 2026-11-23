import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/arca_repository.dart';
import '../../data/sprites/sprite_cache.dart';
import '../../data/sprites/sprite_manifest.g.dart';
import '../../data/sprites/sprites.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';

/// Ajustes > Iconos: descarga completa con progreso (archivos y bytes),
/// cancelable y reanudable, estado real de la caché en disco (cuántos iconos
/// faltan o están dañados), reparación de solo esos y borrado de la caché.
class SpritesSection extends ConsumerStatefulWidget {
  const SpritesSection({super.key});

  @override
  ConsumerState<SpritesSection> createState() => _SpritesSectionState();
}

class _SpritesSectionState extends ConsumerState<SpritesSection> {
  int? _cached;
  SpriteCacheReport? _report;
  SpriteDownloadProgress? _progress;
  bool _running = false;
  bool _cancel = false;
  String? _result;
  DateTime _lastPaint = DateTime.fromMillisecondsSinceEpoch(0);

  SpriteCache get _cache => SpriteCache.instance;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final report = await _cache.verify();
    final n = await _cache.diskBytes();
    if (mounted) {
      setState(() {
        _cached = n;
        _report = report;
      });
    }
  }

  /// Iconos de los equipos de los saves del Arca: se descargan primero.
  List<SpriteRef> _priority() {
    final entries = ref.read(arcaEntriesProvider).asData?.value ?? const <ArcaEntry>[];
    return [for (final e in entries) ...SpriteCache.refsForParty(ArcaRepository.decodeParty(e.latest.partySummary))];
  }

  Future<void> _downloadAll({bool repair = false}) async {
    final l10n = context.l10n;
    setState(() {
      _running = true;
      _cancel = false;
      _result = null;
      _progress = null;
    });
    final r = await (repair ? _cache.repair : _cache.downloadAll)(
      priority: _priority(),
      cancel: () => _cancel || !mounted,
      onProgress: (p) {
        // Miles de avisos: se repinta como mucho ~12 veces por segundo.
        final now = DateTime.now();
        if (!mounted || (p.done < p.total && now.difference(_lastPaint) < const Duration(milliseconds: 80))) return;
        _lastPaint = now;
        setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    setState(() {
      _result = r.offline
          ? l10n.spritesOffline
          : r.cancelled
              ? l10n.spritesCancelled
              : r.complete
                  ? l10n.spritesDone
                  : r.missing > 0
                      ? l10n.spritesIncomplete(r.missing)
                      : l10n.spritesFailed(r.failed);
      _running = false;
      _progress = null;
    });
    await _refresh();
  }

  Future<void> _clear() async {
    await _cache.clear();
    if (!mounted) return;
    setState(() => _result = context.l10n.spritesCleared);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final total = SpriteCache.allRefs().length;
    final progress = _progress;
    final report = _report;
    final partial = report != null && report.valid > 0 && report.missing > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        l10n.spritesCacheSize(total, formatBytes(_cached ?? 0), formatBytes(kSpriteTotalBytes)),
        style: context.text.bodySmall!.copyWith(color: tokens.muted),
      ),
      if (report != null && report.valid > 0) ...[
        const SizedBox(height: 4),
        Text(
          report.complete ? l10n.spritesOnDisk(report.valid, report.total) : l10n.spritesMissing(report.missing),
          key: const ValueKey('sprites-status'),
          style: context.text.bodySmall!.copyWith(color: report.complete ? tokens.muted : context.colors.error),
        ),
      ],
      const SizedBox(height: 12),
      if (_running) ...[
        LinearProgressIndicator(value: progress == null || progress.total == 0 ? null : progress.done / progress.total),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Text(
                progress == null
                    ? l10n.spritesProgress(0, total)
                    : l10n.spritesProgressBytes(
                        progress.done, progress.total, formatBytes(progress.bytes), formatBytes(progress.totalBytes)),
                style: context.text.labelMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          ),
          TextButton(
            onPressed: _cancel ? null : () => setState(() => _cancel = true),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
        ]),
      ] else
        Wrap(spacing: 12, runSpacing: 12, children: [
          if (partial)
            FilledButton.tonalIcon(
              key: const ValueKey('sprites-repair'),
              onPressed: () => _downloadAll(repair: true),
              icon: const Icon(Icons.healing_rounded),
              label: Text(l10n.spritesRepair(report.missing)),
            )
          else
            FilledButton.tonalIcon(
              onPressed: _downloadAll,
              icon: const Icon(Icons.download_rounded),
              label: Text(l10n.spritesDownloadAll(formatBytes(kSpriteTotalBytes))),
            ),
          OutlinedButton.icon(
            onPressed: (_cached ?? 0) > 0 ? _clear : null,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: Text(l10n.spritesClear),
          ),
        ]),
      if (_result != null) ...[
        const SizedBox(height: 8),
        Text(_result!, style: context.text.bodySmall!.copyWith(color: tokens.muted)),
      ],
    ]);
  }
}
