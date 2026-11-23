import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pkcore/pkcore.dart';

import '../../data/db/arca_database.dart';
import '../../data/folder/arca_layout.dart';
import '../../editing/draft.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/game_palette.dart';
import '../common/adaptive.dart';
import '../common/cartridge.dart';
import '../common/format.dart';
import '../common/version_chip.dart';
import '../editor/draft_bar.dart';
import '../editor/events_panel.dart';
import '../editor/inventory_panel.dart';
import '../editor/pokedex_panel.dart';
import '../editor/trainer_panel.dart';
import 'pokemon_views.dart';
import 'compare_screen.dart';
import 'damage_notice.dart';
import 'snapshot_history.dart';

class SaveDetailScreen extends ConsumerStatefulWidget {
  const SaveDetailScreen({super.key, required this.slotId});
  final int slotId;

  @override
  ConsumerState<SaveDetailScreen> createState() => _SaveDetailScreenState();
}

class _SaveDetailScreenState extends ConsumerState<SaveDetailScreen> {
  int? _selectedSnapshot;

  /// Fija la versión a mano. Si el save ya la guarda, solo se informa.
  Future<void> _pickVersion(BuildContext context, GameVersion game, SaveSlot slot, Snapshot? current) async {
    final fromSave = current?.versionId;
    if (fromSave != null && GameVersions.exact(game, fromSave) != null && GameVersions.ofGame[game]!.length > 1) {
      final repo = ref.read(arcaRepositoryProvider);
      SnapshotMeta? meta;
      try {
        meta = current?.relPath == null ? null : await repo.folder.readMeta(current!.relPath!);
      } catch (_) {
        meta = null;
      }
      // Solo se avisa si la versión viene del propio save (no fijada a mano).
      if (meta != null && !meta.slot.versionManual && context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(context.l10n.versionFromSave(GameVersions.name(fromSave, es: context.isSpanish))),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(MaterialLocalizations.of(ctx).okButtonLabel))],
          ),
        );
        return;
      }
    }
    if (!context.mounted) return;
    final picked = await pickSlotVersion(context, game, slot.versionId);
    if (picked == null) return;
    await ref.read(arcaRepositoryProvider).setSlotVersion(slot.id, picked.$2);
  }

  @override
  Widget build(BuildContext context) {
    final slot = ref.watch(slotProvider(widget.slotId)).value;
    final snaps = ref.watch(snapshotsProvider(widget.slotId)).value ?? const <Snapshot>[];
    if (slot == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final current = snaps.where((s) => s.id == _selectedSnapshot).firstOrNull ?? snaps.firstOrNull;
    final game = GameVersion.fromCode(slot.gameCode) ?? GameVersion.redBlue;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1100;
    final compact = width < 720;
    final pad = compact ? 16.0 : 32.0;

    final history = SnapshotHistory(
      snapshots: snaps,
      selectedId: current?.id,
      onCompare: (a, b) => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => CompareScreen(beforeId: a, afterId: b, game: game),
          )),
      onSelect: (id) async {
        if (current != null && id != current.id && !await _confirmLeave(context, current.id)) return;
        setState(() => _selectedSnapshot = id);
      },
    );

    final content = current == null
        ? const SizedBox.shrink()
        : _SnapshotContent(
            key: ValueKey(current.id),
            snapshot: current,
            game: game,
            slot: slot,
            isLatest: current.id == snaps.first.id,
            onSaved: (id) => setState(() => _selectedSnapshot = id),
          );

    final dirty = current != null && ref.watch(draftProvider(current.id).select((d) => d.dirty));

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || current == null) return;
        if (await _confirmLeave(context, current.id) && context.mounted) context.go('/arca');
      },
      child: Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, compact ? 8 : 20, pad, 0),
              sliver: SliverToBoxAdapter(
                child: Row(children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () async {
                      if (current != null && !await _confirmLeave(context, current.id)) return;
                      if (context.mounted) context.go('/arca');
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: context.l10n.moreActions,
                    onSelected: (v) async {
                      if (v == 'delete') await _confirmDelete(context, snaps.length);
                      if (v == 'version' && context.mounted) await _pickVersion(context, game, slot, current);
                    },
                    itemBuilder: (_) => [
                      if (GameVersions.ofGame[game]!.length > 1)
                        PopupMenuItem(value: 'version', child: Text(context.l10n.versionPickMenu)),
                      PopupMenuItem(value: 'delete', child: Text(context.l10n.deleteSave)),
                    ],
                  ),
                ]),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
              sliver: SliverToBoxAdapter(
                child: Material(
                  shape: const CartridgeBorder(radius: 26, notch: 40),
                  clipBehavior: Clip.antiAlias,
                  color: context.tokens.raised,
                  child: Hero(
                    tag: 'slot-label-${slot.id}',
                    child: CartridgeLabel(game: game, versionId: slot.versionId, height: compact ? 150 : 190, large: true),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 24, pad, 120),
              sliver: SliverToBoxAdapter(
                child: wide
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: content),
                        const SizedBox(width: 32),
                        SizedBox(width: 360, child: history),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        content,
                        const SizedBox(height: 32),
                        history,
                      ]),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  /// `true` si se puede abandonar el snapshot (sin cambios o el usuario los descarta).
  Future<bool> _confirmLeave(BuildContext context, int snapshotId) async {
    final draft = ref.read(draftProvider(snapshotId));
    if (!draft.dirty) return true;
    final l10n = context.l10n;
    final ok = await confirmAdaptive(
      context,
      title: l10n.leaveDraftTitle,
      body: l10n.leaveDraftBody(draft.cursor),
      confirm: l10n.discard,
      cancel: l10n.keepEditing,
      icon: Icons.edit_off_rounded,
    );
    if (ok) ref.read(draftProvider(snapshotId).notifier).discard();
    return ok;
  }

  Future<void> _confirmDelete(BuildContext context, int count) async {
    final l10n = context.l10n;
    final ok = await confirmAdaptive(
      context,
      title: l10n.deleteTitle,
      body: l10n.deleteBody(count),
      confirm: l10n.delete,
      cancel: l10n.cancel,
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    context.go('/arca');
    await ref.read(arcaRepositoryProvider).deleteSlot(widget.slotId);
  }
}

enum _Section { pokemon, trainer, inventory, pokedex, events }

class _SnapshotContent extends ConsumerStatefulWidget {
  const _SnapshotContent({
    super.key,
    required this.snapshot,
    required this.game,
    required this.slot,
    required this.isLatest,
    required this.onSaved,
  });
  final Snapshot snapshot;
  final GameVersion game;
  final SaveSlot slot;
  final bool isLatest;
  final ValueChanged<int> onSaved;

  @override
  ConsumerState<_SnapshotContent> createState() => _SnapshotContentState();
}

class _SnapshotContentState extends ConsumerState<_SnapshotContent> {
  _Section _section = _Section.pokemon;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final game = widget.game;
    final parsed = ref.watch(parsedSnapshotProvider(snapshot.id));
    final draft = ref.watch(draftProvider(snapshot.id));
    final l10n = context.l10n;
    final accent = GamePalette.of(game, widget.slot.versionId);

    if (draft.error != null) {
      return Text(l10n.loadError('${draft.error}'), style: TextStyle(color: context.colors.error));
    }
    final save = parsed.value;
    final editor = draft.editor;
    if (save == null || editor == null) {
      return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
    }
    final trainer = editor.readTrainer();
    final hasStorage = editor.canEditStorage && (save.support.party || save.support.boxes);
    final hasInventory = editor.readInventory() != null;
    final hasDex = editor.pokedex != null;
    final hasEvents = editor.events != null;
    final available = {
      _Section.pokemon,
      _Section.trainer,
      if (hasInventory) _Section.inventory,
      if (hasDex) _Section.pokedex,
      if (hasEvents) _Section.events,
    };
    final section = available.contains(_section) ? _section : _Section.pokemon;
    final actions = StorageActions(context, ref, snapshot.id, game);
    final note = snapshot.note;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(trainer.name, style: context.text.displaySmall),
        const SizedBox(height: 6),
        Text(
          widget.isLatest
              ? l10n.lastCopy(formatDate(context, snapshot.importedAt, withTime: true))
              : l10n.snapshotOf(formatDate(context, snapshot.importedAt, withTime: true)),
          style: context.text.bodyMedium!.copyWith(color: context.tokens.muted),
        ),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Notice(text: note, accent: accent, icon: Icons.edit_note_rounded),
        ],
        if (editor.readOnly) ...[
          const SizedBox(height: 10),
          DamageNotice(
            editor: editor,
            onRepairExport: editor.damage == SaveDamage.minor ? () => exportRepaired(context, ref, snapshot.id) : null,
          ),
        ],
        const SizedBox(height: 20),
        _StatsRow(save: save, trainer: trainer, boxed: _countBoxed(editor), damage: editor.damage),
        const SizedBox(height: 24),
        DraftBar(snapshotId: snapshot.id, onSaved: widget.onSaved),
        const SizedBox(height: 24),
        SectionTabs<_Section>(
          accent: accent,
          tabs: [
            SectionTab(_Section.pokemon, l10n.sectionPokemon, icon: Icons.catching_pokemon_rounded),
            SectionTab(_Section.trainer, l10n.sectionTrainerTab, icon: Icons.badge_outlined),
            if (hasInventory) SectionTab(_Section.inventory, l10n.sectionInventory, icon: Icons.backpack_outlined),
            if (hasDex) SectionTab(_Section.pokedex, l10n.sectionPokedex, icon: Icons.menu_book_rounded),
            if (hasEvents) SectionTab(_Section.events, l10n.sectionEvents, icon: Icons.flag_outlined),
          ],
          selected: section,
          onChanged: (v) => setState(() => _section = v),
        ),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(a), child: child),
          ),
          child: KeyedSubtree(
            key: ValueKey(section),
            child: switch (section) {
          _Section.pokemon when !hasStorage => _Notice(text: l10n.notSupportedStorage, accent: accent),
          _Section.pokemon => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle(l10n.team),
              const SizedBox(height: 14),
              PartyGrid(party: editor.party, actions: actions, capacity: editor.partyCapacity),
              const SizedBox(height: 36),
              _SectionTitle(l10n.boxes),
              const SizedBox(height: 14),
              BoxBrowser(editor: editor, actions: actions, accent: accent, revision: draft.revision),
            ]),
          _Section.trainer => TrainerPanel(snapshotId: snapshot.id, editor: editor),
          _Section.inventory => InventoryPanel(snapshotId: snapshot.id, editor: editor),
          _Section.pokedex => PokedexPanel(snapshotId: snapshot.id, editor: editor, accent: accent),
          _Section.events => EventsPanel(snapshotId: snapshot.id, editor: editor),
            },
          ),
        ),
        for (final w in save.warnings) ...[
          const SizedBox(height: 16),
          _Notice(text: w, accent: accent),
        ],
      ],
    );
  }

  static int _countBoxed(SaveEditor e) {
    var n = 0;
    for (var b = 0; b < e.boxCount; b++) {
      for (var s = 0; s < e.boxSlotCount; s++) {
        if (e.get(SlotRef.box(b, s)) != null) n++;
      }
    }
    return n;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: context.text.headlineMedium);
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.accent, this.icon = Icons.info_outline_rounded});
  final String text;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: accent),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ]),
      );
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.save, required this.trainer, required this.boxed, required this.damage});
  final SaveFile save;
  final TrainerData trainer;
  final int boxed;

  /// Gravedad del daño según el editor (checksums, hashes, firma y datos ilegibles).
  final SaveDamage damage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = TrainerInfo(
      name: trainer.name,
      tid: trainer.tid,
      sid: save.trainer.sid == null ? null : trainer.sid,
      playTime: trainer.playTime,
      sixDigitIds: save.trainer.sixDigitIds,
    );
    // El editor ya comprobó todo al abrir (BEEF + firma MemeCrypto, MD5, SHA-256, datos).
    final label = damageChipLabel(l10n, damage);
    final (icon, color) = switch (damage) {
      SaveDamage.none => (Icons.verified_rounded, const Color(0xFF52C98A)),
      SaveDamage.minor => (Icons.lock_outline_rounded, damageMinorColor),
      SaveDamage.major => (Icons.report_rounded, context.colors.error),
    };
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _Stat(label: l10n.playTime, value: formatPlayTime(t.playTime)),
        _Stat(label: l10n.trainerId, value: t.displayTid),
        if (t.displaySid != null) _Stat(label: l10n.secretId, value: t.displaySid!),
        if (save.support.boxes) _Stat(label: l10n.inBoxes, value: '$boxed'),
        if (trainer.money > 0) _Stat(label: l10n.money, value: formatMoney(context, trainer.money)),
        Tooltip(
          message: save.format,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(label, style: context.text.labelLarge!.copyWith(color: color))),
            ]),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 18, 12),
        decoration: BoxDecoration(color: context.tokens.raised, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.tokens.hairline)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: context.text.labelSmall!.copyWith(color: context.tokens.muted)),
          const SizedBox(height: 2),
          Text(value, style: context.text.titleLarge!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );
}

