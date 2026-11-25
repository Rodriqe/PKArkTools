import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pkcore/pkcore.dart';

import '../../data/team_store.dart';
import '../../data/update/champions_update.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../common/species_avatar.dart';
import '../tools/tools_common.dart';
import 'build_editor.dart';
import 'damage_screen.dart';
import 'stats_screen.dart' show defaultChampionsBuild;

/// Equipos guardados en `Competitive/Teams/` del Arca (null si el Arca aún no
/// tiene carpeta).
final teamStoreProvider = Provider<TeamStore?>((ref) {
  final repo = ref.watch(arcaRepositoryProvider);
  return repo.hasFolder ? TeamStore(repo.folder) : null;
});

final teamsProvider = FutureProvider.autoDispose<({List<StoredTeam> teams, List<String> unreadable})>((ref) async {
  await ref.watch(championsDataProvider.future);
  final store = ref.watch(teamStoreProvider);
  if (store == null) return (teams: <StoredTeam>[], unreadable: <String>[]);
  return store.list();
});

Widget _teamAvatars(ChampionsTeam t, {double size = 34}) => Wrap(
  spacing: 2,
  children: [
    for (final m in t.members)
      if (m.battleSpecies?.key ?? m.species?.key case (final s, final f))
        SpeciesAvatar(species: s, form: f, game: GameVersion.scarletViolet, size: size),
  ],
);

/// «Mis equipos»: lista, crear, renombrar, duplicar, borrar, importar y
/// exportar.
class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  Future<String?> _askName(BuildContext context, {String initial = ''}) => showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(initial: initial),
  );

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function(TeamStore s) f) async {
    final store = ref.read(teamStoreProvider);
    if (store == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.compTeamSaveFailed;
    try {
      await f(store);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$failed $e')));
    }
    ref.invalidate(teamsProvider);
  }

  Future<void> _new(BuildContext context, WidgetRef ref) async {
    final name = await _askName(context);
    if (name == null || !context.mounted) return;
    StoredTeam? created;
    await _run(context, ref, (s) async => created = await s.save(ChampionsTeam(name: name)));
    if (created != null && context.mounted) await openTeam(context, created!);
    ref.invalidate(teamsProvider);
  }

  Future<void> _importShowdown(BuildContext context, WidgetRef ref) async {
    final sets = await pasteFromShowdown(context);
    if (sets == null || sets.isEmpty || !context.mounted) return;
    final name = await _askName(context, initial: 'Showdown');
    if (name == null || !context.mounted) return;
    await _run(
      context,
      ref,
      (s) => s.save(ChampionsTeam(name: name, members: sets.take(ChampionsTeam.maxMembers).toList())),
    );
  }

  Future<void> _importJson(BuildContext context, WidgetRef ref) async {
    final text = await ref.read(fileSourcesProvider).pickJson();
    if (text == null || !context.mounted) return;
    await _run(context, ref, (s) => s.importJson(text));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final store = ref.watch(teamStoreProvider);
    final data = ref.watch(teamsProvider);
    final es = context.isSpanish;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.compTeamsTitle),
        actions: [
          if (store != null)
            PopupMenuButton<String>(
              key: const ValueKey('teams-import'),
              tooltip: l10n.compImport,
              icon: const Icon(Icons.download_rounded),
              onSelected: (v) => v == 'json' ? _importJson(context, ref) : _importShowdown(context, ref),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'showdown', child: Text(l10n.compPasteShowdown)),
                PopupMenuItem(value: 'json', child: Text(l10n.compImportJson)),
              ],
            ),
        ],
      ),
      floatingActionButton: store == null
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('teams-new'),
              onPressed: () => _new(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.compNewTeam),
            ),
      body: store == null
          ? _NoFolder()
          : data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _NoFolder(error: '$e'),
              data: (d) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  Text(
                    l10n.compTeamsWhere(TeamStore.dir),
                    style: context.text.bodySmall!.copyWith(color: context.tokens.muted),
                  ),
                  const SizedBox(height: 8),
                  if (d.teams.isEmpty) Padding(padding: const EdgeInsets.only(top: 24), child: Text(l10n.compNoTeams)),
                  for (final s in d.teams)
                    Card(
                      key: ValueKey('team-${s.team.name}'),
                      child: ListTile(
                        title: Text(s.team.name.isEmpty ? '—' : s.team.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            _teamAvatars(s.team),
                            if (s.team.notAllowed().isNotEmpty)
                              Text(
                                l10n.compMembersNotAllowed(s.team.notAllowed().length),
                                style: context.text.bodySmall!.copyWith(color: context.colors.error),
                              )
                            else if (s.team.teamIssues(es: es).isNotEmpty)
                              Text(
                                s.team.teamIssues(es: es).first,
                                style: context.text.bodySmall!.copyWith(color: context.tokens.muted),
                              ),
                          ],
                        ),
                        onTap: () async {
                          await openTeam(context, s);
                          ref.invalidate(teamsProvider);
                        },
                        trailing: PopupMenuButton<String>(
                          key: ValueKey('team-menu-${s.team.name}'),
                          onSelected: (v) async {
                            switch (v) {
                              case 'rename':
                                final n = await _askName(context, initial: s.team.name);
                                if (n == null || !context.mounted) return;
                                await _run(context, ref, (st) async {
                                  s.team.name = n;
                                  await st.save(s.team, previous: s);
                                });
                              case 'duplicate':
                                await _run(context, ref, (st) => st.duplicate(s, l10n.compCopyOf(s.team.name)));
                              case 'showdown':
                                await showTeamShowdown(context, s.team);
                              case 'json':
                                await exportTeamJson(context, ref, s.team);
                              case 'delete':
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: Text(l10n.compDeleteTeam(s.team.name)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, false),
                                        child: Text(MaterialLocalizations.of(c).cancelButtonLabel),
                                      ),
                                      FilledButton(
                                        key: const ValueKey('team-delete-ok'),
                                        onPressed: () => Navigator.pop(c, true),
                                        child: Text(MaterialLocalizations.of(c).deleteButtonTooltip),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true && context.mounted) await _run(context, ref, (st) => st.delete(s));
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'rename', child: Text(l10n.compRename)),
                            PopupMenuItem(value: 'duplicate', child: Text(l10n.compDuplicate)),
                            PopupMenuItem(value: 'showdown', child: Text(l10n.toolsShowdownText)),
                            PopupMenuItem(value: 'json', child: Text(l10n.compExportJson)),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(MaterialLocalizations.of(context).deleteButtonTooltip),
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (final u in d.unreadable)
                    ListTile(
                      leading: Icon(Icons.error_outline_rounded, color: context.colors.error),
                      title: Text(u.split('/').last),
                      subtitle: Text(l10n.compTeamUnreadable),
                    ),
                ],
              ),
            ),
    );
  }
}

class _NoFolder extends StatelessWidget {
  const _NoFolder({this.error});
  final String? error;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_off_outlined, size: 40, color: context.tokens.muted),
          const SizedBox(height: 12),
          Text(context.l10n.compTeamsNoFolder, textAlign: TextAlign.center),
          if (error != null) Text(error!, style: context.text.bodySmall),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('teams-choose-folder'),
            onPressed: () => context.go('/ajustes'),
            child: Text(context.l10n.compChooseFolder),
          ),
        ],
      ),
    ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.compTeamName),
    content: TextField(
      key: const ValueKey('team-name-field'),
      controller: _c,
      autofocus: true,
      maxLength: 60,
      onSubmitted: (v) => v.trim().isEmpty ? null : Navigator.pop(context, v.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      FilledButton(
        key: const ValueKey('team-name-ok'),
        onPressed: () => _c.text.trim().isEmpty ? null : Navigator.pop(context, _c.text.trim()),
        child: Text(MaterialLocalizations.of(context).okButtonLabel),
      ),
    ],
  );
}

Future<void> showTeamShowdown(BuildContext context, ChampionsTeam t) {
  final text = t.toShowdown();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.l10n.toolsShowdownText),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: SelectableText(
            text.isEmpty ? ctx.l10n.toolsNoPokemon : text,
            key: const ValueKey('team-showdown-text'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(MaterialLocalizations.of(ctx).closeButtonLabel)),
        FilledButton.icon(
          onPressed: text.isEmpty ? null : () => copyText(ctx, text),
          icon: const Icon(Icons.copy_rounded),
          label: Text(ctx.l10n.toolsCopy),
        ),
      ],
    ),
  );
}

Future<void> exportTeamJson(BuildContext context, WidgetRef ref, ChampionsTeam t) async {
  final bytes = Uint8List.fromList(utf8.encode(t.encode()));
  final name =
      '${t.name.replaceAll(RegExp(r'[^\w\- ]'), '_').trim().isEmpty ? 'team' : t.name.replaceAll(RegExp(r'[^\w\- ]'), '_').trim()}.json';
  final messenger = ScaffoldMessenger.of(context);
  final saved = context.l10n.toolsSavedTo;
  try {
    final path = await ref.read(fileSourcesProvider).exportBytes(name, bytes);
    if (path != null) messenger.showSnackBar(SnackBar(content: Text('$saved $path')));
  } catch (_) {
    if (context.mounted) await shareFile(context, bytes, name, 'application/json');
  }
}

Future<void> openTeam(BuildContext context, StoredTeam s) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TeamEditorScreen(stored: s)));

/// Editor de un equipo: miembros con su set completo y validación.
class TeamEditorScreen extends ConsumerStatefulWidget {
  const TeamEditorScreen({super.key, required this.stored});
  final StoredTeam stored;

  @override
  ConsumerState<TeamEditorScreen> createState() => _TeamEditorScreenState();
}

class _TeamEditorScreenState extends ConsumerState<TeamEditorScreen> {
  late StoredTeam _stored = widget.stored;
  ChampionsTeam get _team => _stored.team;
  bool _dirty = false;
  bool _saving = false;
  int _version = 0;

  void _changed() => setState(() => _dirty = true);

  Future<bool> _save() async {
    final store = ref.read(teamStoreProvider);
    if (store == null) return false;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      _stored = await store.save(_team, previous: _stored);
      _dirty = false;
      messenger.showSnackBar(SnackBar(content: Text(l10n.compTeamSaved)));
      return true;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.compTeamSaveFailed} $e')));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _add(String how) async {
    ChampionsBuild? b;
    switch (how) {
      case 'new':
        b = defaultChampionsBuild();
      case 'ark':
        b = await pickFromArk(context);
      case 'showdown':
        final list = await pasteFromShowdown(context);
        if (list != null && list.isNotEmpty) {
          setState(() {
            for (final x in list) {
              if (_team.members.length < ChampionsTeam.maxMembers) _team.members.add(x);
            }
            _dirty = true;
            _version++;
          });
        }
        return;
    }
    if (b == null || !mounted) return;
    setState(() {
      _team.members.add(b!);
      _dirty = true;
      _version++;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(championsDataProvider);
    final l10n = context.l10n;
    final es = context.isSpanish;
    final issues = _team.teamIssues(es: es);
    final notAllowed = _team.notAllowed();
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final r = await showDialog<String>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l10n.compUnsavedTeam),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, 'discard'), child: Text(l10n.compDiscard)),
              FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: Text(l10n.compSave)),
            ],
          ),
        );
        if (r == 'save' && !await _save()) return;
        if (r == null) return;
        _dirty = false;
        nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_team.name),
          actions: [
            IconButton(
              tooltip: l10n.toolsShowdownText,
              onPressed: () => showTeamShowdown(context, _team),
              icon: const Icon(Icons.ios_share_rounded),
            ),
            IconButton(
              key: const ValueKey('team-save'),
              tooltip: l10n.compSave,
              onPressed: _saving || !_dirty ? null : _save,
              icon: const Icon(Icons.save_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (issues.isEmpty && notAllowed.isEmpty)
              Text(l10n.compTeamOk, key: const ValueKey('team-ok'))
            else
              for (final i in issues)
                Text('• $i', style: context.text.bodyMedium!.copyWith(color: context.colors.error)),
            const SizedBox(height: 8),
            for (final (i, m) in _team.members.indexed)
              Card(
                key: ValueKey('member-$i-$_version'),
                child: ExpansionTile(
                  initiallyExpanded: _team.members.length == 1,
                  leading: switch (m.battleSpecies?.key ?? m.species?.key) {
                    (final s, final f) => SpeciesAvatar(species: s, form: f, game: GameVersion.scarletViolet, size: 40),
                    null => const Icon(Icons.help_outline_rounded),
                  },
                  title: Text(m.nickname.isNotEmpty ? m.nickname : (m.battleSpecies?.name ?? m.speciesId)),
                  subtitle: notAllowed.contains(i)
                      ? Text(
                          l10n.compMemberNotAllowed(ChampionsFormat.regulation.code),
                          key: ValueKey('member-not-allowed-$i'),
                          style: TextStyle(color: context.colors.error),
                        )
                      : Text(m.stats.join(' / '), style: context.text.bodySmall),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    ChampionsBuildEditor(build: m, keyPrefix: 'member$i', onChanged: _changed),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          key: ValueKey('member-damage-$i'),
                          onPressed: () => pushDamageCalc(context, m),
                          icon: const Icon(Icons.flash_on_rounded),
                          label: Text(l10n.compUseInDamage),
                        ),
                        TextButton.icon(
                          key: ValueKey('member-remove-$i'),
                          onPressed: () => setState(() {
                            _team.members.removeAt(i);
                            _dirty = true;
                            _version++;
                          }),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: Text(l10n.compRemoveMember),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_team.members.length < ChampionsTeam.maxMembers)
              Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<String>(
                  key: const ValueKey('team-add'),
                  onSelected: _add,
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'new', child: Text(l10n.compNewMember)),
                    PopupMenuItem(value: 'ark', child: Text(l10n.compLoadFromArk)),
                    PopupMenuItem(value: 'showdown', child: Text(l10n.compPasteShowdown)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_outline_rounded, color: context.colors.primary),
                        const SizedBox(width: 8),
                        Text(l10n.compAddMember, style: TextStyle(color: context.colors.primary)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
