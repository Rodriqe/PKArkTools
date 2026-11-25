import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../../data/arca_repository.dart';
import '../../data/db/arca_database.dart' show Snapshot;
import '../../data/transfer_service.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/adaptive.dart';
import '../common/format.dart';
import '../common/species_avatar.dart';
import '../editor/legality_view.dart';
import '../editor/pickers.dart';

/// Ajuste por dispositivo: el usuario ya leyó el aviso de HOME.
const kTransferHomeAckSetting = 'transferHomeAck';

/// «HOME local»: lleva Pokémon de una partida del Arca a otra.
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({
    super.key,
    required this.snapshotId,
    required this.slotId,
    required this.game,
    this.initial = const [],
  });

  final int snapshotId;
  final int slotId;
  final GameVersion game;

  /// Pokémon ya elegidos (desde la ficha).
  final List<SlotRef> initial;

  static Future<void> open(BuildContext context,
          {required int snapshotId, required int slotId, required GameVersion game, List<SlotRef> initial = const []}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TransferScreen(snapshotId: snapshotId, slotId: slotId, game: game, initial: initial),
      ));

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  Snapshot? _srcSnap;
  Uint8List? _srcBytes;
  SaveEditor? _src;
  late final Set<SlotRef> _selected = {...widget.initial};

  ArcaEntry? _dest;
  Uint8List? _dstBytes;
  SaveEditor? _dst;
  int? _startBox;
  bool _move = true;
  bool _homeAck = false;
  bool _cloneOk = false;
  bool _busy = false;
  Object? _error;

  TransferPlan? _plan;
  Object? _planKey;

  ArcaRepository get _repo => ref.read(arcaRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await _repo.snapshot(widget.snapshotId);
      final bytes = await _repo.snapshotBytes(snap);
      final ack = await _repo.getSetting(kTransferHomeAckSetting);
      if (!mounted) return;
      setState(() {
        _srcSnap = snap;
        _srcBytes = bytes;
        _src = SaveEditor.open(bytes);
        _homeAck = ack == '1';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pickDest(ArcaEntry e) async {
    setState(() {
      _dest = e;
      _dst = null;
      _dstBytes = null;
      _startBox = null;
    });
    try {
      final bytes = await _repo.snapshotBytes(e.latest);
      if (!mounted || _dest != e) return;
      setState(() {
        _dstBytes = bytes;
        _dst = SaveEditor.open(bytes);
      });
    } catch (err) {
      if (mounted) setState(() => _error = err);
    }
  }

  List<SlotRef> get _allRefs {
    final src = _src!;
    return [
      for (var i = 0; i < src.partyCount; i++) SlotRef.party(i),
      for (var b = 0; b < src.boxCount; b++)
        for (var s = 0; s < src.boxSlotCount; s++)
          if (src.get(SlotRef.box(b, s)) != null) SlotRef.box(b, s),
    ];
  }

  TransferPlan? _currentPlan() {
    final src = _src, dst = _dst, dest = _dest;
    if (src == null || dst == null || dest == null || _selected.isEmpty) return null;
    final refs = [for (final r in _allRefs) if (_selected.contains(r)) r];
    final key = Object.hashAll([...refs, dest.latest.id, _startBox, _move]);
    if (key == _planKey && _plan != null) return _plan;
    _planKey = key;
    return _plan = TransferService.plan(
      src: src,
      fromGame: widget.game,
      refs: refs,
      dst: dst,
      toGame: dest.game,
      startBox: _startBox ?? 0,
      move: _move,
      language: context.isSpanish ? 7 : 2,
      dataLang: context.dataLang,
    );
  }

  Future<void> _run(TransferPlan plan) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final dest = _dest!;
    final fromName = gameTitle(context, widget.game);
    final toName = gameTitle(context, dest.game, dest.slot.versionId);
    setState(() => _busy = true);
    try {
      if (plan.viaHome && !_homeAck) await _repo.setSetting(kTransferHomeAckSetting, '1');
      final out = TransferService.apply(plan, _srcBytes!, _dstBytes!, move: _move);
      await TransferService.commit(
        _repo,
        out,
        fromSlotId: widget.slotId,
        fromFileName: _srcSnap!.fileName,
        toSlotId: dest.slot.id,
        toFileName: dest.latest.fileName,
        toNote: l10n.transferNoteTo(fromName, out.count),
        fromNote: l10n.transferNoteFrom(toName, out.count),
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.transferDone(toName, out.count))));
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.transferFailed('$e'))));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopAtAlola(List<ArcaEntry> entries) async {
    final l10n = context.l10n;
    final alola = [
      for (final e in entries)
        if (e.slot.id != widget.slotId &&
            (e.game == GameVersion.sunMoon || e.game == GameVersion.ultraSunUltraMoon))
          e,
    ];
    if (alola.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.transferAlolaNone)));
      return;
    }
    var pick = alola.first;
    if (alola.length > 1) {
      final chosen = await showAdaptiveSheet<ArcaEntry>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.all(20), child: Text(l10n.transferAlolaPick, style: ctx.text.titleMedium)),
            for (final e in alola) _DestTile(entry: e, selected: false, onTap: () => Navigator.pop(ctx, e)),
            const SizedBox(height: 12),
          ]),
        ),
      );
      if (chosen == null) return;
      pick = chosen;
    }
    await _pickDest(pick);
    if (mounted) await _showGuide();
  }

  Future<void> _showGuide() => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.transferGuideTitle),
          content: SingleChildScrollView(child: Text(ctx.l10n.transferGuideBody)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(MaterialLocalizations.of(ctx).okButtonLabel))],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = ref.watch(arcaEntriesProvider).value ?? const <ArcaEntry>[];
    final src = _src;
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 720 ? 16.0 : 32.0;
    if (_error != null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l10n.loadError('$_error'))));
    }
    if (src == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final plan = _currentPlan();
    final dests = [for (final e in entries) if (e.slot.id != widget.slotId) e];
    final ready = plan?.ready.length ?? 0;
    final needsAck = plan != null && plan.viaHome && !_homeAck;
    final needsClone = plan != null && !_move && plan.hasTrackers && !_cloneOk;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.transferTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, 8, pad, 120),
        children: [
          Text(l10n.transferIntro, style: context.text.bodyMedium!.copyWith(color: context.tokens.muted)),
          const SizedBox(height: 24),
          _Step(
            title: l10n.transferStepPokemon,
            trailing: Text(l10n.transferSelectedCount(_selected.length), style: context.text.labelLarge),
            child: _PokemonPicker(
              editor: src,
              game: widget.game,
              refs: _allRefs,
              selected: _selected,
              onToggle: (r) => setState(() => _selected.contains(r) ? _selected.remove(r) : _selected.add(r)),
              onAll: (all) => setState(() => all ? _selected.addAll(_allRefs) : _selected.clear()),
            ),
          ),
          _Step(
            title: l10n.transferStepDestination,
            child: dests.isEmpty
                ? Text(l10n.transferNoDestinations)
                : Column(children: [
                    for (final e in dests)
                      _DestTile(entry: e, selected: _dest?.slot.id == e.slot.id, onTap: () => _pickDest(e)),
                  ]),
          ),
          if (_dest != null && _dst == null) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (_dst != null) ...[
            _Step(
              title: l10n.transferStepWhere,
              child: Align(
                alignment: Alignment.centerLeft,
                child: DropdownButton<int?>(
                  value: _startBox,
                  items: [
                    DropdownMenuItem(value: null, child: Text(l10n.transferFirstFree)),
                    for (var b = 0; b < _dst!.boxCount; b++)
                      DropdownMenuItem(value: b, child: Text(l10n.transferFromBox(_dst!.boxName(b)))),
                  ],
                  onChanged: (v) => setState(() => _startBox = v),
                ),
              ),
            ),
            _Step(
              title: l10n.transferStepMode,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(l10n.transferModeMove), icon: const Icon(Icons.drive_file_move_outline)),
                    ButtonSegment(value: false, label: Text(l10n.transferModeCopy), icon: const Icon(Icons.copy_rounded)),
                  ],
                  selected: {_move},
                  onSelectionChanged: (s) => setState(() => _move = s.first),
                ),
                const SizedBox(height: 8),
                Text(_move ? l10n.transferModeMoveDesc : l10n.transferModeCopyDesc,
                    style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
                if (plan != null && !_move && plan.hasTrackers) ...[
                  const SizedBox(height: 12),
                  _Warning(
                    text: l10n.transferCloneWarning,
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _cloneOk,
                      onChanged: (v) => setState(() => _cloneOk = v ?? false),
                      title: Text(l10n.transferCloneConfirm),
                    ),
                  ),
                ],
              ]),
            ),
            if (plan != null && plan.viaHome)
              _Warning(
                title: l10n.transferHomeTitle,
                text: l10n.transferHomeBody,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (plan.canStopAtAlola) ...[
                    const SizedBox(height: 8),
                    Text(l10n.transferAlolaRecommended, style: context.text.bodyMedium),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => _stopAtAlola(entries),
                      icon: const Icon(Icons.flag_circle_outlined),
                      label: Text(l10n.transferAlolaButton),
                    ),
                  ],
                  TextButton.icon(
                    onPressed: _showGuide,
                    icon: const Icon(Icons.menu_book_outlined),
                    label: Text(l10n.transferGuideButton),
                  ),
                  if (!_homeAck)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: false,
                      onChanged: (v) => setState(() => _homeAck = v ?? false),
                      title: Text(l10n.transferHomeAck),
                    ),
                ]),
              ),
            if (plan != null)
              _Step(
                title: l10n.transferStepPreview,
                child: Column(children: [
                  for (final i in plan.items) _PreviewCard(item: i, plan: plan, dst: _dst!, toGame: _dest!.game),
                ]),
              ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 12),
          child: FilledButton.icon(
            onPressed: plan == null || ready == 0 || needsAck || needsClone || _busy ? null : () => _run(plan),
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.swap_horiz_rounded),
            label: Text(plan != null && ready == 0 ? l10n.transferNothingReady : l10n.transferConfirm(ready == 0 ? 1 : ready)),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: context.text.titleLarge)),
            ?trailing,
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _Warning extends StatelessWidget {
  const _Warning({this.title, required this.text, this.child});
  final String? title;
  final String text;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 28),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
          color: warningColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: warningColor.withValues(alpha: 0.45)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null) ...[
            Row(children: [
              const Icon(Icons.warning_amber_rounded, color: warningColor),
              const SizedBox(width: 10),
              Expanded(child: Text(title!, style: context.text.titleSmall)),
            ]),
            const SizedBox(height: 8),
          ],
          Text(text, style: context.text.bodyMedium),
          // Material propio: las casillas (ListTile) pintan su tinta sobre el fondo del aviso.
          if (child != null) Material(type: MaterialType.transparency, child: child),
        ]),
      );
}

class _PokemonPicker extends StatelessWidget {
  const _PokemonPicker({
    required this.editor,
    required this.game,
    required this.refs,
    required this.selected,
    required this.onToggle,
    required this.onAll,
  });
  final SaveEditor editor;
  final GameVersion game;
  final List<SlotRef> refs;
  final Set<SlotRef> selected;
  final ValueChanged<SlotRef> onToggle;
  final ValueChanged<bool> onAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        TextButton(onPressed: () => onAll(true), child: Text(l10n.transferSelectAll)),
        TextButton(onPressed: () => onAll(false), child: Text(l10n.transferSelectNone)),
      ]),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: SingleChildScrollView(
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in refs)
              if (editor.get(r) case final pk?)
                Tooltip(
                  message: '${pokemonName(context, pk.species, pk.form, game)} · ${r.isParty ? l10n.slotParty(r.slot + 1) : l10n.slotBox(editor.boxName(r.box), r.slot + 1)}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onToggle(r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: selected.contains(r) ? context.colors.primary.withValues(alpha: 0.18) : context.tokens.raised,
                        border: Border.all(
                          color: selected.contains(r) ? context.colors.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: SpeciesAvatar(
                        species: pk.species,
                        form: pk.form,
                        game: game,
                        shiny: pk.isShiny,
                        egg: pk.isEgg,
                        female: pk.gender == 1,
                        size: 40,
                      ),
                    ),
                  ),
                ),
          ]),
        ),
      ),
    ]);
  }
}

class _DestTile extends StatelessWidget {
  const _DestTile({required this.entry, required this.selected, required this.onTap});
  final ArcaEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        selected: selected,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
        title: Text(gameTitle(context, entry.game, entry.slot.versionId)),
        subtitle: Text('${entry.slot.trainerName} · ${entry.slot.displayTid}'),
        onTap: onTap,
      );
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.item, required this.plan, required this.dst, required this.toGame});
  final TransferItem item;
  final TransferPlan plan;
  final SaveEditor dst;
  final GameVersion toGame;

  String _block(BuildContext context, TransferBlock b) {
    final l = context.l10n;
    return switch (b) {
      TransferBlock.backwards => l.transferBlockBackwards,
      TransferBlock.noRoute => l.transferBlockNoRoute,
      TransferBlock.shadow => l.transferBlockShadow,
      TransferBlock.egg => l.transferBlockEgg,
      TransferBlock.speciesNotInGame => l.transferBlockSpecies,
      TransferBlock.formNotAllowed => l.transferBlockForm,
      TransferBlock.bdspLocked => l.transferBlockBdsp,
      TransferBlock.letsGoOnly => l.transferBlockLetsGo,
      TransferBlock.gbLanguage => l.transferBlockGbLanguage,
      TransferBlock.notInGen1 => l.transferBlockGen1,
      TransferBlock.unsupported => l.transferBlockUnsupported,
    };
  }

  String _skip(BuildContext context, TransferSkip s) => switch (s) {
        TransferSkip.noSpace => context.l10n.transferSkipNoSpace,
        TransferSkip.lockedSlot => context.l10n.transferSkipLocked,
        TransferSkip.lastInParty => context.l10n.transferSkipLastInParty,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final src = item.source;
    final lang = context.dataLang;
    final out = item.result.pk;
    final block = item.result.block;
    final skip = plan.skips[item.from];
    final diff = item.diff;
    String moves(List<int> m) => [for (final x in m) if (x != 0) GameStrings.move(x, lang)].join(', ');
    String itemName(int id, int gen) => GameStrings.item(id, gen, lang);
    final lines = <String>[
      if (diff != null) ...[
        if (diff.movesChanged) l10n.transferChangeMoves(moves(diff.movesBefore), moves(diff.movesAfter)),
        if (diff.ballChanged) l10n.transferChangeBall(ballName(context, diff.ballBefore), ballName(context, diff.ballAfter)),
        if (diff.itemRemoved) l10n.transferChangeItemRemoved(itemName(diff.itemBefore, src.generation)),
        if (diff.itemChanged)
          l10n.transferChangeItem(itemName(diff.itemBefore, src.generation), itemName(diff.itemAfter, out!.generation)),
        if (diff.ribbonsKept > 0) l10n.transferChangeRibbonsKept(diff.ribbonsKept),
        if (diff.ribbonsLost.isNotEmpty) l10n.transferChangeRibbonsLost(diff.ribbonsLost.join(', ')),
        if (diff.nicknameChanged) l10n.transferChangeNickname(diff.nicknameBefore, diff.nicknameAfter),
        if (diff.abilityChanged)
          l10n.transferChangeAbility(GameStrings.ability(diff.abilityBefore, lang), GameStrings.ability(diff.abilityAfter, lang)),
        if (diff.levelChanged) l10n.transferChangeLevel('${diff.levelBefore}', '${diff.levelAfter}'),
        if (diff.formChanged) l10n.transferChangeForm,
        if (diff.ivsChanged) l10n.transferChangeIvs,
        if (diff.natureChanged) l10n.transferChangeNature,
      ],
    ];
    final route = item.result.route.map((f) => f.extension.toUpperCase()).join(' → ');
    final bad = block != null || skip != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SpeciesAvatar(species: src.species, form: src.form, game: src.dataGame, shiny: src.isShiny, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${src.nickname} · ${l10n.level(src.level)}', style: context.text.titleSmall),
                Text(l10n.transferRoute(route), style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
              ]),
            ),
            Icon(bad ? Icons.block_rounded : Icons.check_circle_rounded,
                color: bad ? context.colors.error : const Color(0xFF52C98A)),
          ]),
          const SizedBox(height: 10),
          if (block != null)
            Text(_block(context, block), style: TextStyle(color: context.colors.error))
          else if (skip != null)
            Text(_skip(context, skip), style: TextStyle(color: context.colors.error))
          else ...[
            Text(
              l10n.transferGoesTo(item.target!.isParty
                  ? l10n.slotParty(item.target!.slot + 1)
                  : l10n.slotBox(dst.boxName(item.target!.box), item.target!.slot + 1)),
              style: context.text.labelLarge,
            ),
            const SizedBox(height: 6),
            if (lines.isEmpty) Text(l10n.transferNoChanges, style: context.text.bodySmall),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('•  '),
                  Expanded(child: Text(l, style: context.text.bodySmall)),
                ]),
              ),
            const SizedBox(height: 10),
            Text(l10n.transferLegality, style: context.text.labelLarge!.copyWith(color: context.tokens.muted)),
            const SizedBox(height: 6),
            LegalityPanel(issues: item.issues),
          ],
        ]),
      ),
    );
  }
}
