import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:pkcore/pkcore.dart';

import '../../editing/draft.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/adaptive.dart';
import '../common/format.dart';

/// Texto legible de una lista de ediciones (para la nota del snapshot).
String describeEdits(BuildContext context, List<SaveEditOp> edits, SaveEditor editor) {
  final l10n = context.l10n;
  String slot(SlotRef r) => r.isParty ? l10n.slotParty(r.slot + 1) : l10n.slotBox(editor.boxName(r.box), r.slot + 1);
  final lines = <String>[];
  for (final e in edits) {
    lines.add(switch (e) {
      SetSlotEdit(:final ref, :final pk) => l10n.editSet(speciesName(context, pk.species), slot(ref)),
      ClearSlotEdit(:final ref, :final species) =>
        l10n.editClear(species > 0 ? speciesName(context, species) : l10n.pokemon, slot(ref)),
      SwapSlotsEdit(:final from, :final to) => l10n.editMove(slot(from), slot(to)),
      SetTrainerEdit() => l10n.editTrainer,
      SetInventoryEdit() => l10n.editInventory,
      SetBoxNameEdit(:final box, :final name) => l10n.editBoxName(box + 1, name),
      PokedexEdit() => l10n.editPokedex,
      EventEdit() => l10n.editEvents,
      FillBoxesEdit(:final label, :final pokemon) => label ?? l10n.livingDexNote(l10n.livingDexKindNormal, pokemon.length),
    });
  }
  final unique = <String>[];
  for (final l in lines) {
    if (!unique.contains(l)) unique.add(l);
  }
  if (unique.length <= 6) return unique.join('\n');
  return '${unique.take(6).join('\n')}\n${l10n.andMore(unique.length - 6)}';
}

/// Barra del borrador: cambios pendientes, deshacer/rehacer, guardar y exportar.
class DraftBar extends ConsumerWidget {
  const DraftBar({super.key, required this.snapshotId, required this.onSaved});
  final int snapshotId;
  final ValueChanged<int> onSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final draft = ref.watch(draftProvider(snapshotId));
    final ctrl = ref.read(draftProvider(snapshotId).notifier);
    final dirty = draft.dirty;
    final primary = context.colors.primary;

    final undo = IconButton(
      tooltip: withShortcut(l10n.undo, AppShortcut.undo),
      onPressed: draft.canUndo ? ctrl.undo : null,
      icon: const Icon(Icons.undo_rounded),
    );
    final redo = IconButton(
      tooltip: withShortcut(l10n.redo, AppShortcut.redo),
      onPressed: draft.canRedo ? ctrl.redo : null,
      icon: const Icon(Icons.redo_rounded),
    );

    final content = LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 880;
      final status = Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dirty ? primary : tokens.muted.withValues(alpha: 0.4)),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            dirty ? l10n.unsavedChanges(draft.cursor) : l10n.noChanges,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall!.copyWith(color: dirty ? null : tokens.muted),
          ),
        ),
      ]);
      final export = OutlinedButton.icon(
        onPressed: draft.loaded ? () => exportDraft(context, ref, snapshotId) : null,
        icon: const Icon(Icons.ios_share_rounded, size: 18),
        label: Text(l10n.exportFile, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
      final save = FilledButton.icon(
        onPressed: dirty ? () => _save(context, ref) : null,
        icon: const Icon(Icons.inventory_2_rounded, size: 18),
        label: Text(l10n.saveToArca, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
      if (c.maxWidth < 520) {
        // Teléfono: estado, deshacer/rehacer + exportar, y guardar a lo ancho.
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.only(top: 4, right: 4), child: status),
          const SizedBox(height: 8),
          Row(children: [
            undo,
            redo,
            if (dirty) Flexible(child: TextButton(onPressed: () => _confirmDiscard(context, ctrl), child: Text(l10n.discard, maxLines: 1))),
            const Spacer(),
            Flexible(flex: 4, child: export),
          ]),
          const SizedBox(height: 8),
          SizedBox(height: 52, child: save),
        ]);
      }
      final buttons = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        undo,
        redo,
        if (dirty)
          TextButton(onPressed: () => _confirmDiscard(context, ctrl), child: Text(l10n.discard)),
        OutlinedButton.icon(
          onPressed: draft.loaded ? () => exportDraft(context, ref, snapshotId) : null,
          icon: const Icon(Icons.ios_share_rounded, size: 18),
          label: Text(l10n.exportFile),
        ),
        FilledButton.icon(
          onPressed: dirty ? () => _save(context, ref) : null,
          icon: const Icon(Icons.inventory_2_rounded, size: 18),
          label: Text(l10n.saveToArca),
        ),
      ]);
      return narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [status, const SizedBox(height: 10), buttons])
          : Row(children: [Expanded(child: status), buttons]);
    });

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): ctrl.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): ctrl.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): ctrl.redo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): ctrl.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): ctrl.redo,
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        decoration: BoxDecoration(
          color: dirty ? primary.withValues(alpha: 0.10) : tokens.raised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: dirty ? primary.withValues(alpha: 0.45) : tokens.hairline),
        ),
        child: content,
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context, DraftController ctrl) async {
    final l10n = context.l10n;
    final ok = await confirmAdaptive(
      context,
      title: l10n.discardDraftTitle,
      body: l10n.discardDraftBody,
      confirm: l10n.discard,
      cancel: l10n.keepEditing,
      icon: Icons.delete_sweep_outlined,
      destructive: true,
    );
    if (ok) ctrl.discard();
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final draft = ref.read(draftProvider(snapshotId));
    final note = TextEditingController(text: describeEdits(context, draft.applied, draft.editor!));
    final field = TextField(
      controller: note,
      minLines: 3,
      maxLines: 8,
      decoration: InputDecoration(labelText: l10n.changeNote),
    );
    final bool? ok;
    if (context.isPhone) {
      ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        useRootNavigator: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(l10n.saveDraftTitle, style: ctx.text.headlineSmall),
                const SizedBox(height: 8),
                Text(l10n.saveDraftBody, style: ctx.text.bodyMedium!.copyWith(color: ctx.tokens.muted)),
                const SizedBox(height: 16),
                field,
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.inventory_2_rounded, size: 18),
                  label: Text(l10n.saveToArca),
                ),
                const SizedBox(height: 6),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel),
                ),
              ]),
            ),
          ),
        ),
      );
    } else {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.saveDraftTitle),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.saveDraftBody),
              const SizedBox(height: 16),
              field,
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.saveToArca)),
          ],
        ),
      );
    }
    if (ok != true) return;
    try {
      final id = await ref.read(draftProvider(snapshotId).notifier).saveToArca(note.text.trim());
      messenger.showSnackBar(SnackBar(content: Text(l10n.savedToArca)));
      if (id != null) onSaved(id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed('$e'))));
    }
  }
}

/// Exporta el estado actual del borrador como archivo listo para el juego.
Future<void> exportDraft(BuildContext context, WidgetRef ref, int snapshotId) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final ctrl = ref.read(draftProvider(snapshotId).notifier);
  try {
    final bytes = ctrl.buildFile();
    final name = ctrl.fileName ?? 'save.sav';
    final base = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    final dirty = ref.read(draftProvider(snapshotId)).dirty;
    final suggested = dirty ? '${base}_${l10n.editedSuffix}$ext' : name;
    final path = await ref.read(fileSourcesProvider).exportBytes(suggested, bytes);
    if (path != null) messenger.showSnackBar(SnackBar(content: Text(dirty ? l10n.exportVerified(path) : l10n.exportReady(path))));
  } on SaveVerificationException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.exportVerifyFailed(e.problems.join('; ')))));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed('$e'))));
  }
}

/// Exporta una copia con los checksums recalculados de un save con daño leve.
Future<void> exportRepaired(BuildContext context, WidgetRef ref, int snapshotId) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final ctrl = ref.read(draftProvider(snapshotId).notifier);
  try {
    final bytes = ctrl.buildRepairedFile();
    final name = ctrl.fileName ?? 'save.sav';
    final suggested = '${p.basenameWithoutExtension(name)}_${l10n.repairedSuffix}${p.extension(name)}';
    final path = await ref.read(fileSourcesProvider).exportBytes(suggested, bytes);
    if (path != null) messenger.showSnackBar(SnackBar(content: Text(l10n.exportRepaired(path))));
  } on SaveVerificationException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.exportVerifyFailed(e.problems.join('; ')))));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed('$e'))));
  }
}
