import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_version.dart';
import '../../data/update/app_update.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';

sealed class _State {
  const _State();
}

class _Idle extends _State {
  const _Idle();
}

class _Checking extends _State {
  const _Checking();
}

class _UpToDate extends _State {
  const _UpToDate(this.release);
  final ReleaseInfo? release;
}

class _Available extends _State {
  const _Available(this.release);
  final ReleaseInfo release;
}

class _Downloading extends _State {
  const _Downloading(this.release, this.done, this.total);
  final ReleaseInfo release;
  final int done, total;
}

class _Installing extends _State {
  const _Installing(this.release);
  final ReleaseInfo release;
}

class _Failed extends _State {
  const _Failed(this.error, this.release);
  final UpdateException error;

  /// Release ya encontrado (el reintento vuelve a descargarlo).
  final ReleaseInfo? release;
}

/// «Actualizaciones» en Ajustes: buscar la última versión en GitHub y, en
/// Android, descargarla e instalarla encima (con la confirmación del sistema).
class UpdateSection extends ConsumerStatefulWidget {
  const UpdateSection({super.key});

  /// Si la sección tiene sentido en esta plataforma.
  static bool supported(AppUpdater u) => u.platform != UpdatePlatform.other;

  @override
  ConsumerState<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends ConsumerState<UpdateSection> {
  _State _state = const _Idle();
  Completer<void>? _cancel;

  AppUpdater get _updater => ref.read(appUpdaterProvider);

  void _set(_State s) {
    if (mounted) setState(() => _state = s);
  }

  Future<void> _check() async {
    _set(const _Checking());
    try {
      final r = await _updater.latest();
      _set(r != null && r.isNewer ? _Available(r) : _UpToDate(r));
    } on UpdateException catch (e) {
      _set(_Failed(e, null));
    }
  }

  Future<void> _install(ReleaseInfo r) async {
    final u = _updater;
    if (!u.canInstallInApp || r.asset == null) {
      await u.openPage(r.page);
      return;
    }
    if (!await u.canRequestInstall()) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final open = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l10n.updatePermissionTitle),
          content: Text(l10n.updatePermissionBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.updateCancel)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l10n.updatePermissionOpen)),
          ],
        ),
      );
      if (open == true) await u.openInstallPermission();
      return;
    }
    final cancel = _cancel = Completer<void>();
    _set(_Downloading(r, 0, r.asset!.size));
    try {
      final apk = await u.download(r, cancel: cancel.future, onProgress: (done, total) => _set(_Downloading(r, done, total)));
      _set(_Installing(r));
      await u.install(apk);
      _set(_Available(r));
    } on UpdateException catch (e) {
      _set(e.code == 'aborted' ? _Available(r) : _Failed(e, r));
      if (e.code == 'aborted' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).updateErrorAborted)));
      }
    } finally {
      if (identical(_cancel, cancel)) _cancel = null;
    }
  }

  @override
  void dispose() {
    _cancel?.complete();
    super.dispose();
  }

  String _error(AppLocalizations l10n, UpdateException e) => switch (e.code) {
        'network' => l10n.updateErrorNetwork,
        'size' => l10n.updateErrorSize,
        'aborted' => l10n.updateErrorAborted,
        'conflict' || 'incompatible' => l10n.updateErrorConflict,
        'storage' => l10n.updateErrorStorage,
        'permission' => l10n.updateErrorPermission,
        _ => l10n.updateErrorGeneric(e.detail == null ? e.code : '${e.code}: ${e.detail}'),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final u = ref.watch(appUpdaterProvider);
    final muted = context.text.bodyMedium!.copyWith(color: context.tokens.muted);
    final checkButton = FilledButton.tonalIcon(
      onPressed: _state is _Checking || _state is _Downloading || _state is _Installing ? null : _check,
      icon: _state is _Checking
          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.system_update_alt_rounded),
      label: Text(_state is _Checking ? l10n.updateChecking : l10n.updateCheck),
    );

    Widget release(ReleaseInfo r, Widget actions) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.updateAvailable(r.version.toString()), style: context.text.titleMedium),
          if (r.notes.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(l10n.updateNotes),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: SingleChildScrollView(child: SelectableText(r.notes, style: muted)),
                ),
              ],
            ),
          const SizedBox(height: 8),
          actions,
        ]);

    final body = switch (_state) {
      _Idle() || _Checking() => checkButton,
      _UpToDate(:final release) => Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          checkButton,
          Text(l10n.updateUpToDate(release?.version.toString() ?? kAppVersion), style: muted),
        ]),
      _Available(release: final r) => release(
          r,
          Wrap(spacing: 12, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: () => _install(r),
              icon: Icon(u.canInstallInApp && r.asset != null ? Icons.download_rounded : Icons.open_in_new_rounded),
              label: Text(u.canInstallInApp && r.asset != null ? l10n.updateInstall : l10n.updateOpenPage),
            ),
            if (u.canInstallInApp && r.asset == null) Text(l10n.updateNoAsset, style: muted),
          ])),
      _Downloading(release: final r, :final done, :final total) => release(
          r,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LinearProgressIndicator(value: total > 0 ? (done / total).clamp(0.0, 1.0) : null),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text(l10n.updateDownloading(formatBytes(done), formatBytes(total)), style: muted)),
              TextButton(onPressed: () => _cancel?.complete(), child: Text(l10n.updateCancel)),
            ]),
          ])),
      _Installing(release: final r) => release(
          r,
          Row(children: [
            const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.updateInstalling, style: muted)),
            TextButton(onPressed: () => _set(_Available(r)), child: Text(l10n.updateBack)),
          ])),
      _Failed(:final error, release: final r) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_error(l10n, error), style: context.text.bodyMedium!.copyWith(color: context.colors.error)),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 8, children: [
            FilledButton.tonal(onPressed: r == null ? _check : () => _install(r), child: Text(l10n.updateRetry)),
            if (r != null || error.code != 'network')
              OutlinedButton.icon(
                onPressed: () => u.openPage(r?.page ?? Uri.parse(AppUpdater.releasesPage)),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(l10n.updateOpenPage),
              ),
          ]),
        ]),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.updateCurrent(kAppVersion), style: muted),
      const SizedBox(height: 10),
      body,
    ]);
  }
}
