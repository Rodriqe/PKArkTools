import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/arca_problems.dart';
import '../../data/arca_session.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';

/// Todos los problemas del último reindexado (ignorados incluidos).
final arcaProblemsProvider = Provider<List<ArcaProblem>>((ref) {
  final repo = ref.watch(arcaRepositoryProvider);
  return arcaProblemsOf(ref.watch(reindexReportProvider).value ?? repo.lastReport);
});

/// Claves de los problemas ignorados en este dispositivo.
final arcaProblemIgnoresProvider = AsyncNotifierProvider<ArcaProblemIgnoresNotifier, Set<String>>(ArcaProblemIgnoresNotifier.new);

class ArcaProblemIgnoresNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() => ArcaProblemIgnores.load(ref.watch(arcaRepositoryProvider));

  Future<void> _set(Set<String> keys) async {
    // Solo se guardan las claves de problemas que siguen existiendo: un
    // archivo cambiado o arreglado deja de estar ignorado.
    final current = {for (final p in ref.read(arcaProblemsProvider)) p.ignoreKey};
    final next = keys.intersection(current);
    state = AsyncData(next);
    await ArcaProblemIgnores.save(ref.read(arcaRepositoryProvider), next);
  }

  Future<void> ignore(Iterable<ArcaProblem> problems) =>
      _set({...state.value ?? const <String>{}, for (final p in problems) p.ignoreKey});

  Future<void> unignore(Iterable<ArcaProblem> problems) =>
      _set((state.value ?? const <String>{}).difference({for (final p in problems) p.ignoreKey}));
}

/// Problemas visibles (sin los ignorados) y los ignorados.
final visibleArcaProblemsProvider = Provider<({List<ArcaProblem> shown, List<ArcaProblem> ignored})>((ref) {
  final all = ref.watch(arcaProblemsProvider);
  final ignored = ref.watch(arcaProblemIgnoresProvider).value ?? const <String>{};
  return (
    shown: [
      for (final p in all)
        if (!ignored.contains(p.ignoreKey)) p,
    ],
    ignored: [
      for (final p in all)
        if (ignored.contains(p.ignoreKey)) p,
    ],
  );
});

extension ArcaProblemText on ArcaProblemKind {
  String title(AppLocalizations l10n) => switch (this) {
    ArcaProblemKind.corruptSidecar => l10n.problemCorruptSidecar,
    ArcaProblemKind.missingSidecar => l10n.problemMissingSidecar,
    ArcaProblemKind.missingSave => l10n.problemMissingSave,
    ArcaProblemKind.contentMismatch => l10n.problemContentMismatch,
    ArcaProblemKind.unreadable => l10n.problemUnreadable,
    ArcaProblemKind.mainFailed => l10n.problemMainFailed,
    ArcaProblemKind.inboxUnreadable => l10n.problemInboxUnreadable,
    ArcaProblemKind.inboxWrongGame => l10n.problemInboxWrongGame,
    ArcaProblemKind.modifiedMain => l10n.problemModifiedMain,
    ArcaProblemKind.conflictCopy => l10n.problemConflictCopy,
    ArcaProblemKind.looseSave => l10n.problemLooseSave,
  };

  String description(AppLocalizations l10n) => switch (this) {
    ArcaProblemKind.corruptSidecar => l10n.problemCorruptSidecarDesc,
    ArcaProblemKind.missingSidecar => l10n.problemMissingSidecarDesc,
    ArcaProblemKind.missingSave => l10n.problemMissingSaveDesc,
    ArcaProblemKind.contentMismatch => l10n.problemContentMismatchDesc,
    ArcaProblemKind.unreadable => l10n.problemUnreadableDesc,
    ArcaProblemKind.mainFailed => l10n.problemMainFailedDesc,
    ArcaProblemKind.inboxUnreadable => l10n.problemInboxUnreadableDesc,
    ArcaProblemKind.inboxWrongGame => l10n.problemInboxWrongGameDesc,
    ArcaProblemKind.modifiedMain => l10n.problemModifiedMainDesc,
    ArcaProblemKind.conflictCopy => l10n.problemConflictCopyDesc,
    ArcaProblemKind.looseSave => l10n.problemLooseSaveDesc,
  };
}

/// «2 arreglados, 1 en cuarentena».
String fixSummaryText(AppLocalizations l10n, FixSummary s) => [
  if (s.fixed > 0 || (s.quarantined == 0 && s.failed == 0)) l10n.problemsResultFixed(s.fixed),
  if (s.quarantined > 0) l10n.problemsResultQuarantined(s.quarantined),
  if (s.failed > 0) l10n.problemsResultFailed(s.failed),
].join(', ');

/// Ajustes → Carpeta del Arca: resumen de una línea de los problemas,
/// plegado por defecto; desplegado, agrupado por tipo con Arreglar/Ignorar.
class ArcaProblemsPanel extends ConsumerStatefulWidget {
  const ArcaProblemsPanel({super.key, this.initiallyExpanded = false});

  final bool initiallyExpanded;

  @override
  ConsumerState<ArcaProblemsPanel> createState() => _ArcaProblemsPanelState();
}

class _ArcaProblemsPanelState extends ConsumerState<ArcaProblemsPanel> {
  late bool _expanded = widget.initiallyExpanded;
  bool _showIgnored = false;
  bool _busy = false;
  String? _lastResult;

  static const _perGroup = 20;

  Future<FixSummary?> _run(List<ArcaProblem> problems, {bool dialog = false}) async {
    if (problems.isEmpty || _busy) return null;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(arcaRepositoryProvider);
    setState(() => _busy = true);
    final progress = ValueNotifier<(int, int)>((0, problems.length));
    final nav = Navigator.of(context, rootNavigator: true);
    if (dialog) {
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (_) => PopScope(canPop: false, child: _FixProgressDialog(progress: progress)),
        ),
      );
    }
    FixSummary? summary;
    try {
      summary = await ArcaRepair(repo).fixAll(problems, onProgress: (d, t) => progress.value = (d, t));
    } finally {
      if (dialog) nav.pop();
      progress.dispose();
      if (mounted) setState(() => _busy = false);
    }
    final text = fixSummaryText(l10n, summary);
    if (mounted) setState(() => _lastResult = text);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    return summary;
  }

  Future<void> _fixAll(List<ArcaProblem> shown) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmFixAllDialog(problems: shown),
    );
    if (ok == true && mounted) await _run(shown, dialog: true);
  }

  Future<void> _ignore(List<ArcaProblem> p) => ref.read(arcaProblemIgnoresProvider.notifier).ignore(p);

  Future<void> _unignore(List<ArcaProblem> p) => ref.read(arcaProblemIgnoresProvider.notifier).unignore(p);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (:shown, :ignored) = ref.watch(visibleArcaProblemsProvider);
    final repo = ref.watch(arcaRepositoryProvider);
    // Ruta mostrada: relativa a la carpeta elegida (PKArkTools/…).
    final prefix = repo.hasFolder ? repo.folder.prefix : '';
    String rel(String path) => prefix.isEmpty ? path : '$prefix/$path';
    if (shown.isEmpty && ignored.isEmpty) {
      return Padding(
        key: const ValueKey('arca-problems-none'),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 18, color: context.tokens.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.problemsNone, style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
            ),
          ],
        ),
      );
    }
    final errors = shown.where((p) => p.kind.isError).length;
    final warnings = shown.length - errors;
    final color = shown.isEmpty ? context.tokens.muted : (errors > 0 ? context.colors.error : context.tokens.shiny);
    final icon = shown.isEmpty
        ? Icons.check_circle_outline_rounded
        : (errors > 0 ? Icons.error_outline_rounded : Icons.warning_amber_rounded);
    final groups = <ArcaProblemKind, List<ArcaProblem>>{};
    for (final p in shown) {
      groups.putIfAbsent(p.kind, () => []).add(p);
    }

    final header = InkWell(
      key: const ValueKey('arca-problems-summary'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              // En el teléfono solo cabe el título: el icono ya dice si hay errores.
              child: LayoutBuilder(
                builder: (context, box) => Row(
                  children: [
                    Flexible(
                      flex: 3,
                      child: Text(
                        shown.isEmpty ? l10n.problemsNone : l10n.problemsSummary(shown.length),
                        style: context.text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (shown.isNotEmpty && box.maxWidth >= 380) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        flex: 2,
                        child: Text(
                          [
                            if (errors > 0) l10n.problemsErrors(errors),
                            if (warnings > 0) l10n.problemsWarnings(warnings),
                          ].join(' · '),
                          style: context.text.bodySmall!.copyWith(color: context.tokens.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(Icons.expand_more_rounded, color: context.tokens.muted),
            ),
          ],
        ),
      ),
    );

    return Container(
      key: const ValueKey('arca-problems'),
      decoration: BoxDecoration(
        color: context.tokens.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: shown.isEmpty ? context.tokens.hairline : color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(button: true, expanded: _expanded, child: header),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(height: 1, color: context.tokens.hairline),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (shown.isNotEmpty)
                              FilledButton.tonalIcon(
                                key: const ValueKey('arca-problems-fix-all'),
                                onPressed: _busy ? null : () => _fixAll(shown),
                                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                                label: Text(l10n.problemsFixAll),
                              ),
                            if (ignored.isNotEmpty)
                              TextButton(
                                key: const ValueKey('arca-problems-show-ignored'),
                                onPressed: () => setState(() => _showIgnored = !_showIgnored),
                                child: Text(_showIgnored ? l10n.problemsHideIgnored : l10n.problemsShowIgnored(ignored.length)),
                              ),
                          ],
                        ),
                        if (_lastResult != null) ...[
                          const SizedBox(height: 6),
                          Text(_lastResult!, style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
                        ],
                        for (final MapEntry(key: kind, value: items) in groups.entries)
                          _Group(
                            kind: kind,
                            items: items,
                            rel: rel,
                            limit: _perGroup,
                            busy: _busy,
                            onFix: (p) => _run(p),
                            onIgnore: _ignore,
                          ),
                        if (_showIgnored && ignored.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(l10n.problemsIgnoredHint, style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
                          const SizedBox(height: 4),
                          for (final p in ignored.take(100))
                            _Item(
                              problem: p,
                              subtitle: '${p.kind.title(l10n)} · ${rel(p.path)}',
                              actions: [
                                IconButton(
                                  tooltip: l10n.problemsUnignore,
                                  onPressed: () => _unignore([p]),
                                  icon: const Icon(Icons.visibility_rounded, size: 20),
                                ),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.kind,
    required this.items,
    required this.rel,
    required this.limit,
    required this.busy,
    required this.onFix,
    required this.onIgnore,
  });

  final ArcaProblemKind kind;
  final List<ArcaProblem> items;
  final String Function(String path) rel;
  final int limit;
  final bool busy;
  final Future<void> Function(List<ArcaProblem>) onFix;
  final Future<void> Function(List<ArcaProblem>) onIgnore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = kind.isError ? context.colors.error : context.tokens.shiny;
    return Padding(
      key: ValueKey('arca-problems-group-${kind.name}'),
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(kind.isError ? Icons.error_outline_rounded : Icons.warning_amber_rounded, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${kind.title(l10n)} (${items.length})', style: context.text.titleSmall),
                    const SizedBox(height: 2),
                    Text(kind.description(l10n), style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: busy ? null : () => onFix(items),
                  icon: const Icon(Icons.build_rounded, size: 16),
                  label: Text(l10n.problemsFixGroup(items.length)),
                ),
                TextButton.icon(
                  onPressed: busy ? null : () => onIgnore(items),
                  icon: const Icon(Icons.visibility_off_rounded, size: 16),
                  label: Text(l10n.problemsIgnoreGroup(items.length)),
                ),
              ],
            ),
          ),
          for (final p in items.take(limit))
            _Item(
              problem: p,
              subtitle: p.game == null ? rel(p.path) : '${rel(p.path)}  →  ${gameTitle(context, p.game!)}',
              actions: [
                IconButton(
                  tooltip: l10n.problemsFix,
                  onPressed: busy ? null : () => onFix([p]),
                  icon: const Icon(Icons.build_rounded, size: 20),
                ),
                IconButton(
                  tooltip: l10n.problemsIgnore,
                  onPressed: busy ? null : () => onIgnore([p]),
                  icon: const Icon(Icons.visibility_off_rounded, size: 20),
                ),
              ],
            ),
          if (items.length > limit)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 2),
              child: Text(
                l10n.problemsMore(items.length - limit),
                style: context.text.bodySmall!.copyWith(color: context.tokens.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.problem, required this.subtitle, required this.actions});

  final ArcaProblem problem;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 26),
    child: Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(problem.name, style: context.text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  subtitle,
                  style: context.text.bodySmall!.copyWith(color: context.tokens.muted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        ...actions,
      ],
    ),
  );
}

class _ConfirmFixAllDialog extends StatelessWidget {
  const _ConfirmFixAllDialog({required this.problems});

  final List<ArcaProblem> problems;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final counts = <ArcaProblemKind, int>{};
    for (final p in problems) {
      counts.update(p.kind, (v) => v + 1, ifAbsent: () => 1);
    }
    return AlertDialog(
      key: const ValueKey('arca-problems-confirm'),
      icon: const Icon(Icons.auto_fix_high_rounded),
      title: Text(l10n.problemsConfirmTitle(problems.length)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final MapEntry(:key, :value) in counts.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('•  ${key.title(l10n)} ($value)', style: context.text.bodyMedium),
                ),
              const SizedBox(height: 10),
              Text(l10n.problemsConfirmBody, style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(
          key: const ValueKey('arca-problems-confirm-fix'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.problemsFixAll),
        ),
      ],
    );
  }
}

class _FixProgressDialog extends StatelessWidget {
  const _FixProgressDialog({required this.progress});

  final ValueNotifier<(int, int)> progress;

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('arca-problems-progress'),
    content: ValueListenableBuilder<(int, int)>(
      valueListenable: progress,
      builder: (context, v, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.problemsFixing(v.$1, v.$2), style: context.text.bodyMedium),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: v.$2 == 0 ? null : v.$1 / v.$2),
        ],
      ),
    ),
  );
}

/// Pestaña Arca: aviso discreto de una línea que lleva a Ajustes (nada si
/// no hay problemas visibles).
class ArcaProblemsNotice extends ConsumerWidget {
  const ArcaProblemsNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(visibleArcaProblemsProvider).shown;
    if (shown.isEmpty) return const SizedBox.shrink();
    final error = shown.any((p) => p.kind.isError);
    final color = error ? context.colors.error : context.tokens.shiny;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        key: const ValueKey('arca-problems-notice'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.go('/ajustes'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Icon(error ? Icons.error_outline_rounded : Icons.warning_amber_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.problemsSummary(shown.length),
                  style: context.text.bodySmall!.copyWith(color: context.tokens.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(context.l10n.problemsSeeSettings, style: context.text.labelMedium!.copyWith(color: context.colors.primary)),
              Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
