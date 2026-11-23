import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pkcore/pkcore.dart';

import '../../data/arca_repository.dart';
import '../../data/arca_session.dart';
import '../../data/folder/arca_game_folders.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';

/// Pregunta (una vez, tras elegir la carpeta) si se crean las carpetas de
/// los juegos. Por defecto no se crea nada.
Future<void> askGameFolders(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final choice = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.create_new_folder_rounded, color: ctx.colors.primary),
      title: Text(l10n.gameFoldersQuestion),
      content: Text(l10n.gameFoldersQuestionBody),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'no'), child: Text(l10n.gameFoldersNotNow)),
        OutlinedButton(onPressed: () => Navigator.pop(ctx, 'choose'), child: Text(l10n.gameFoldersChoose)),
        FilledButton(onPressed: () => Navigator.pop(ctx, 'all'), child: Text(l10n.gameFoldersAll)),
      ],
    ),
  );
  await ref.read(gameFoldersPromptProvider.notifier).answered();
  if (!context.mounted) return;
  switch (choice) {
    case 'all':
      await _create(context, ref, GameVersion.values.toSet());
    case 'choose':
      await createGameFolders(context, ref);
  }
}

/// Ajustes → Crear carpetas de juegos: selector y creación.
Future<void> createGameFolders(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(arcaRepositoryProvider);
  final existing = repo.hasFolder ? await ArcaGameFolders.existing(repo.folder) : <GameVersion>{};
  final owned = {for (final e in ref.read(arcaEntriesProvider).value ?? const <ArcaEntry>[]) e.game};
  if (!context.mounted) return;
  final picked = await showDialog<Set<GameVersion>>(
    context: context,
    builder: (_) => GameFoldersPicker(existing: existing, owned: owned),
  );
  if (picked == null || picked.isEmpty || !context.mounted) return;
  await _create(context, ref, picked);
}

Future<void> _create(BuildContext context, WidgetRef ref, Set<GameVersion> games) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final repo = ref.read(arcaRepositoryProvider);
  if (!repo.hasFolder) return;
  final r = await ArcaGameFolders.create(repo.folder, games, es: context.isSpanish);
  messenger.showSnackBar(SnackBar(
    content: Text([
      l10n.gameFoldersDone('${r.created}', '${r.existing}'),
      ...r.failures.take(3),
    ].join('\n')),
  ));
}

/// Selector de juegos con casillas: todos, ninguno, los que tengo, por
/// plataforma o por generación.
class GameFoldersPicker extends StatefulWidget {
  const GameFoldersPicker({super.key, this.existing = const {}, this.owned = const {}, this.initial});
  final Set<GameVersion> existing;
  final Set<GameVersion> owned;

  /// Selección inicial (por defecto, los juegos que ya hay en el Arca).
  final Set<GameVersion>? initial;

  @override
  State<GameFoldersPicker> createState() => _GameFoldersPickerState();
}

class _GameFoldersPickerState extends State<GameFoldersPicker> {
  late final Set<GameVersion> _selected = {...(widget.initial ?? widget.owned)};

  void _toggleAll(Iterable<GameVersion> games, bool on) =>
      setState(() => on ? _selected.addAll(games) : _selected.removeAll(games));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final byGen = <int, List<GameVersion>>{};
    for (final g in GameVersion.values) {
      byGen.putIfAbsent(g.generation, () => []).add(g);
    }
    final toCreate = _selected.difference(widget.existing).length;
    final platforms = [for (final p in Platform.values.reversed) if (GameVersion.values.any((g) => g.platform == p)) p];

    Widget chip(String label, bool selected, VoidCallback onTap, {Key? key}) =>
        FilterChip(key: key, label: Text(label), selected: selected, onSelected: (_) => onTap());

    bool allOf(Iterable<GameVersion> gs) => gs.every(_selected.contains);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 6),
            child: Text(l10n.gameFoldersPickerTitle, style: context.text.headlineSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(l10n.gameFoldersCreateDesc, style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              chip(l10n.gameFoldersPickAll, allOf(GameVersion.values), () => _toggleAll(GameVersion.values, true)),
              chip(l10n.gameFoldersPickNone, _selected.isEmpty, () => setState(_selected.clear)),
              if (widget.owned.isNotEmpty)
                chip(l10n.gameFoldersPickOwned, _selected.length == widget.owned.length && allOf(widget.owned),
                    () => setState(() => _selected
                      ..clear()
                      ..addAll(widget.owned))),
              for (final p in platforms)
                chip(platformName(context, p), allOf(GameVersion.values.where((g) => g.platform == p)), () {
                  final games = GameVersion.values.where((g) => g.platform == p);
                  _toggleAll(games, !allOf(games));
                }, key: ValueKey('platform-${p.name}')),
            ]),
          ),
          const Divider(height: 1),
          Flexible(
            // Pocas filas (≈30): todas construidas, sin lista perezosa.
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final MapEntry(key: gen, value: games) in byGen.entries) ...[
                  CheckboxListTile(
                    key: ValueKey('gen-$gen'),
                    tristate: true,
                    value: allOf(games) ? true : (games.any(_selected.contains) ? null : false),
                    onChanged: (_) => _toggleAll(games, !allOf(games)),
                    title: Text(l10n.gameFoldersGeneration(gen), style: context.text.titleSmall),
                    subtitle: Text({for (final g in games) platformName(context, g.platform)}.join(' · ')),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  for (final g in games)
                    CheckboxListTile(
                      key: ValueKey('game-${g.code}'),
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 40, right: 16),
                      value: _selected.contains(g),
                      onChanged: (v) => setState(() => v == true ? _selected.add(g) : _selected.remove(g)),
                      title: Text(gameTitle(context, g)),
                      subtitle: widget.existing.contains(g) ? Text(l10n.gameFoldersExists) : null,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ],
              ]),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: toCreate == 0 ? null : () => Navigator.pop(context, {..._selected}),
                child: Text(l10n.gameFoldersConfirm(toCreate)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Escucha eventos del Arca que piden la atención del usuario fuera de una
/// pantalla concreta: la pregunta de las carpetas de juegos y lo recogido (o
/// no) de la bandeja de entrada.
class ArcaEventsHost extends ConsumerStatefulWidget {
  const ArcaEventsHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ArcaEventsHost> createState() => _ArcaEventsHostState();
}

class _ArcaEventsHostState extends ConsumerState<ArcaEventsHost> {
  bool _asking = false;
  Set<String> _shownProblems = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(gameFoldersPromptProvider)) _ask();
    });
  }

  Future<void> _ask() async {
    if (_asking) return;
    _asking = true;
    await askGameFolders(context, ref);
    _asking = false;
  }

  void _onReport(ReindexReport? r) {
    if (r == null || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final l10n = context.l10n;
    if (r.inboxAdopted.isNotEmpty) {
      final files = [
        for (final (file, game, trainer) in r.inboxAdopted) '$file → ${gameTitle(context, game)} · $trainer',
      ].join('\n');
      messenger.showSnackBar(SnackBar(content: Text(l10n.inboxAdoptedToast(files)), duration: const Duration(seconds: 5)));
    }
    final problems = {for (final p in r.inboxProblems) p.path};
    // Solo se avisa de problemas nuevos (no en cada reindexado).
    if (problems.difference(_shownProblems).isNotEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.inboxProblemsToast(problems.length)),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: l10n.inboxSee, onPressed: () => context.go('/ajustes')),
      ));
    }
    _shownProblems = problems;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameFoldersPromptProvider, (_, ask) {
      if (ask) _ask();
    });
    ref.listen(reindexReportProvider, (_, next) => _onReport(next.value));
    return widget.child;
  }
}
