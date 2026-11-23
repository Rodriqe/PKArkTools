import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/update/app_update.dart';
import '../../data/update/update_notice.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';

/// Texto para el usuario de un fallo al buscar o actualizar.
String updateErrorText(AppLocalizations l10n, UpdateException e) => switch (e.code) {
      'network' => l10n.updateErrorNetwork,
      'rate' => l10n.updateErrorRate,
      'size' => l10n.updateErrorSize,
      'aborted' => l10n.updateErrorAborted,
      'signature' => l10n.updateErrorSignature,
      'untrusted' => l10n.updateErrorUntrusted,
      'conflict' || 'incompatible' => l10n.updateErrorConflict,
      'storage' => l10n.updateErrorStorage,
      'permission' => l10n.updateErrorPermission,
      _ => l10n.updateErrorGeneric(e.detail == null ? e.code : '${e.code}: ${e.detail}'),
    };

// ------------------------------------------------------------------ aviso

/// Tarjeta discreta arriba de Ajustes cuando hay una versión nueva.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(updateNoticeProvider).available;
    if (r == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Material(
        color: context.colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showUpdateSheet(context, r),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(children: [
              Icon(Icons.system_update_rounded, color: context.colors.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.updateBannerTitle(r.version.toString()),
                      style: context.text.titleSmall!.copyWith(color: context.colors.onPrimaryContainer)),
                  Text(l10n.updateBannerBody,
                      style: context.text.bodySmall!.copyWith(color: context.colors.onPrimaryContainer)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: context.colors.onPrimaryContainer),
            ]),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------- Ajustes › Acerca de

/// Versión instalada, «Buscar actualizaciones» y la opción de buscar solo.
class UpdateAboutControls extends ConsumerStatefulWidget {
  const UpdateAboutControls({super.key});

  @override
  ConsumerState<UpdateAboutControls> createState() => _UpdateAboutControlsState();
}

class _UpdateAboutControlsState extends ConsumerState<UpdateAboutControls> {
  bool _checking = false;
  String? _result;
  bool _error = false;

  Future<void> _check() async {
    final l10n = context.l10n;
    setState(() {
      _checking = true;
      _result = null;
    });
    try {
      final r = await ref.read(updateNoticeProvider.notifier).checkNow();
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = false;
        _result = r != null && r.isNewer ? null : l10n.updateUpToDate(AppVersion.current.toString());
      });
      if (r != null && r.isNewer) unawaited(showUpdateSheet(context, r));
    } on UpdateException catch (e) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = true;
          _result = updateErrorText(l10n, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notice = ref.watch(updateNoticeProvider);
    final muted = context.text.bodyMedium!.copyWith(color: context.tokens.muted);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FilledButton.tonalIcon(
          onPressed: _checking ? null : _check,
          icon: _checking
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.system_update_alt_rounded),
          label: Text(_checking ? l10n.updateChecking : l10n.updateCheck),
        ),
        if (notice.available case final r?)
          ActionChip(
            avatar: const Icon(Icons.new_releases_rounded, size: 18),
            label: Text(l10n.updateBannerTitle(r.version.toString())),
            onPressed: () => showUpdateSheet(context, r),
          ),
      ]),
      if (_result != null) ...[
        const SizedBox(height: 8),
        Text(_result!, style: _error ? context.text.bodyMedium!.copyWith(color: context.colors.error) : muted),
      ],
      const SizedBox(height: 4),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: notice.autoCheck,
        onChanged: (v) => ref.read(updateNoticeProvider.notifier).setAutoCheck(v),
        title: Text(l10n.updateAutoCheck),
        subtitle: Text(l10n.updateAutoCheckDesc),
      ),
    ]);
  }
}

// ------------------------------------------------------------------- hoja

/// Hoja con las notas del release y los botones Actualizar / Omitir.
Future<void> showUpdateSheet(BuildContext context, ReleaseInfo release) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => UpdateSheet(release: release),
    );

sealed class _Step {
  const _Step();
}

class _Ready extends _Step {
  const _Ready();
}

class _Downloading extends _Step {
  const _Downloading(this.done, this.total);
  final int done, total;
}

class _Verifying extends _Step {
  const _Verifying();
}

class _Installing extends _Step {
  const _Installing();
}

class _Saved extends _Step {
  const _Saved(this.path);
  final String path;
}

class _Failed extends _Step {
  const _Failed(this.error);
  final UpdateException error;
}

class UpdateSheet extends ConsumerStatefulWidget {
  const UpdateSheet({super.key, required this.release});
  final ReleaseInfo release;

  @override
  ConsumerState<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends ConsumerState<UpdateSheet> {
  _Step _step = const _Ready();
  Completer<void>? _cancel;

  AppUpdater get _u => ref.read(appUpdaterProvider);
  ReleaseInfo get _r => widget.release;

  void _set(_Step s) {
    if (mounted) setState(() => _step = s);
  }

  bool get _busy => _step is _Downloading || _step is _Verifying || _step is _Installing;

  Future<void> _update() async {
    final u = _u;
    if (_r.asset == null || !(u.canInstallInApp || u.canDownload)) {
      await u.openPage(_r.page);
      return;
    }
    if (u.canInstallInApp && !await u.canRequestInstall()) {
      if (!mounted) return;
      final l10n = context.l10n;
      final open = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.security_rounded),
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
    _set(_Downloading(0, _r.asset!.size));
    File? file;
    try {
      file = await u.download(_r, cancel: cancel.future, onProgress: (done, total) => _set(_Downloading(done, total)));
      if (cancel.isCompleted) throw const UpdateException('aborted');
      _cancel = null;
      if (u.canInstallInApp) {
        _set(const _Verifying());
        await u.verify(file);
        _set(const _Installing());
        await u.install(file);
        _set(const _Ready());
      } else {
        final saved = await u.saveDownload(file, _r.asset!.name);
        file = null; // saveDownload ya la borró
        _set(saved == null ? const _Ready() : _Saved(saved));
      }
    } on UpdateException catch (e) {
      _set(e.code == 'aborted' ? const _Ready() : _Failed(e));
      if (e.code == 'aborted' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.updateErrorAborted)));
      }
    } finally {
      if (identical(_cancel, cancel)) _cancel = null;
      // El APK no se queda en el dispositivo: ni tras instalar ni al cancelar.
      if (file != null && u.canInstallInApp) await u.deleteDownload(file);
    }
  }

  Future<void> _skip() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(updateNoticeProvider.notifier).skip(_r);
    if (mounted) Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(l10n.updateSkipped(_r.version.toString()))));
  }

  @override
  void dispose() {
    _cancel?.complete();
    super.dispose();
  }

  String _hint(AppLocalizations l10n) => switch (_u.platform) {
        UpdatePlatform.android => l10n.updateAndroidHint,
        UpdatePlatform.macos || UpdatePlatform.windows || UpdatePlatform.linux => l10n.updateDesktopHint,
        _ => l10n.updateIosHint,
      };

  String _steps(AppLocalizations l10n) => switch (_u.platform) {
        UpdatePlatform.macos => l10n.updateStepsMacos,
        UpdatePlatform.windows => l10n.updateStepsWindows,
        _ => l10n.updateStepsLinux,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final u = _u;
    final muted = context.text.bodyMedium!.copyWith(color: context.tokens.muted);
    final inApp = _r.asset != null && (u.canInstallInApp || u.canDownload);

    final Widget status = switch (_step) {
      _Ready() => const SizedBox.shrink(),
      _Downloading(:final done, :final total) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LinearProgressIndicator(value: total > 0 ? (done / total).clamp(0.0, 1.0) : null),
          const SizedBox(height: 8),
          Text(l10n.updateDownloading(formatBytes(done), formatBytes(total)), style: muted),
        ]),
      _Verifying() => _Spinner(l10n.updateVerifying),
      _Installing() => _Spinner(l10n.updateInstalling),
      _Saved(:final path) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.updateSaved(path), style: context.text.bodyMedium),
          const SizedBox(height: 6),
          Text(_steps(l10n), style: muted),
        ]),
      _Failed(:final error) =>
        Text(updateErrorText(l10n, error), style: context.text.bodyMedium!.copyWith(color: context.colors.error)),
    };

    final actions = <Widget>[
      if (_step is _Downloading)
        OutlinedButton(onPressed: () => _cancel?.complete(), child: Text(l10n.updateCancel))
      else if (_step case _Saved(:final path))
        FilledButton.icon(
          onPressed: () => u.reveal(path),
          icon: const Icon(Icons.folder_open_rounded),
          label: Text(l10n.updateShowFolder),
        )
      else
        FilledButton.icon(
          onPressed: _busy ? null : _update,
          icon: Icon(inApp ? Icons.download_rounded : Icons.open_in_new_rounded),
          label: Text(_step is _Failed
              ? l10n.updateRetry
              : !inApp
                  ? l10n.updateOpenPage
                  : u.canInstallInApp
                      ? l10n.updateNow
                      : l10n.updateDownload),
        ),
      if (!_busy) ...[
        if (inApp || _step is _Failed)
          TextButton.icon(
            onPressed: () => u.openPage(_r.page),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(l10n.updateOpenPage),
          ),
        TextButton(onPressed: _skip, child: Text(l10n.updateSkip)),
      ],
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.updateBannerTitle(_r.version.toString()), style: context.text.headlineSmall),
          const SizedBox(height: 4),
          Text(l10n.updateCurrent(AppVersion.current.toString()), style: muted),
          if (_r.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.updateNotes, style: context.text.titleMedium),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: context.tokens.hairline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: ReleaseNotes(_r.notes),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(_hint(l10n), style: muted),
          if (u.canInstallInApp && _r.asset == null) Text(l10n.updateNoAsset, style: muted),
          const SizedBox(height: 12),
          status,
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
        ]),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: context.text.bodyMedium!.copyWith(color: context.tokens.muted))),
      ]);
}

// --------------------------------------------------------- notas en markdown

/// Markdown sencillo de las notas de un release: títulos, viñetas (con líneas
/// de continuación), párrafos, **negrita**, `código` y [enlaces](…) (solo el
/// texto: no se abre nada desde las notas).
class ReleaseNotes extends StatelessWidget {
  const ReleaseNotes(this.markdown, {super.key});
  final String markdown;

  static List<(String kind, String text)> parse(String md) {
    final out = <(String, String)>[];
    String? kind;
    final buf = StringBuffer();
    void flush() {
      if (kind != null && buf.isNotEmpty) out.add((kind!, buf.toString().trim()));
      kind = null;
      buf.clear();
    }

    for (final raw in md.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trimRight();
      final t = line.trimLeft();
      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(t);
      final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(t);
      if (t.isEmpty) {
        flush();
      } else if (heading != null) {
        flush();
        out.add(('h${heading[1]!.length.clamp(1, 3)}', heading[2]!));
      } else if (bullet != null) {
        flush();
        kind = 'li';
        buf.write(bullet[1]);
      } else {
        // Continuación de la viñeta (sangrada) o del párrafo.
        if (kind == 'li' && line.startsWith(' ') || kind == 'p') {
          buf.write(' $t');
        } else {
          flush();
          kind = 'p';
          buf.write(t);
        }
      }
    }
    flush();
    return out;
  }

  static final _inline = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`|\[([^\]]+)\]\([^)]*\)');

  static List<InlineSpan> spans(String text, TextStyle base, Color code) {
    final out = <InlineSpan>[];
    var i = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start > i) out.add(TextSpan(text: text.substring(i, m.start)));
      if (m[1] != null) {
        out.add(TextSpan(text: m[1], style: const TextStyle(fontWeight: FontWeight.w700)));
      } else if (m[2] != null) {
        out.add(TextSpan(text: m[2], style: TextStyle(fontFamily: 'monospace', backgroundColor: code)));
      } else {
        out.add(TextSpan(text: m[3], style: const TextStyle(decoration: TextDecoration.underline)));
      }
      i = m.end;
    }
    if (i < text.length) out.add(TextSpan(text: text.substring(i)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final body = context.text.bodyMedium!;
    final code = context.tokens.hairline;
    Widget rich(String t, TextStyle s) => Text.rich(TextSpan(style: s, children: spans(t, s, code)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final (kind, text) in parse(markdown))
        Padding(
          padding: EdgeInsets.only(bottom: 6, top: kind.startsWith('h') ? 6 : 0),
          child: switch (kind) {
            'h1' || 'h2' => rich(text, context.text.titleMedium!),
            'h3' => rich(text, context.text.titleSmall!),
            'li' => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('•  ', style: body),
                Expanded(child: rich(text, body)),
              ]),
            _ => rich(text, body),
          },
        ),
    ]);
  }
}
