import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pkcore/pkcore.dart';

import '../../editing/draft.dart';
import '../common/format.dart';
import 'box_sort_ui.dart';
import 'showdown_ui.dart';
import 'tools_common.dart';

/// Herramientas de la sección Pokémon de una partida: Showdown (importar y
/// exportar), ordenar cajas y formato oficial.
class SaveToolsBar extends ConsumerWidget {
  const SaveToolsBar({super.key, required this.snapshotId, required this.editor, this.onTransfer});
  final int snapshotId;
  final SaveEditor editor;

  /// «Transferir Pokémon…» (solo en la última copia y si se puede escribir).
  final VoidCallback? onTransfer;

  DraftController _draft(WidgetRef ref) => ref.read(draftProvider(snapshotId).notifier);

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final r = await showShowdownImport(context, editor: editor);
    if (r == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final slots = placementFor(editor, r.pokemon.length, r.target);
    var added = 0;
    try {
      for (var i = 0; i < slots.length; i++) {
        _draft(ref).apply(SetSlotEdit(slots[i], r.pokemon[i], label: 'Importado de Showdown'));
        added++;
      }
    } on SaveEditException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (added > 0 && context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr(context, '$added Pokémon añadidos al borrador.', '$added Pokémon added to the draft.')),
        ),
      );
    }
  }

  Future<void> _sort(BuildContext context, WidgetRef ref) async {
    final plan = await showBoxSort(context, editor);
    if (plan == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      _draft(ref).apply(RearrangeSlotsEdit(plan.layout));
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr(context, 'Cajas ordenadas.', 'Boxes sorted.')),
          action: SnackBarAction(label: tr(context, 'Deshacer', 'Undo'), onPressed: () => _draft(ref).undo()),
        ),
      );
    } on SaveEditException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final writable = !editor.readOnly && editor.canEditStorage;
    final hasBoxes = editor.boxCount > 0;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (onTransfer != null)
          OutlinedButton.icon(
            key: const ValueKey('tool-transfer'),
            onPressed: onTransfer,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: Text(context.l10n.transferPokemonMenu),
          ),
        if (writable)
          OutlinedButton.icon(
            key: const ValueKey('tool-showdown-import'),
            onPressed: () => _import(context, ref),
            icon: const Icon(Icons.content_paste_go_rounded),
            label: Text(tr(context, 'Importar de Showdown', 'Import from Showdown')),
          ),
        if (editor.partyCapacity > 0)
          OutlinedButton.icon(
            key: const ValueKey('tool-showdown-export'),
            onPressed: () => showShowdownExport(context, editor.party, editor.game),
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(tr(context, 'Equipo a Showdown', 'Team to Showdown')),
          ),
        if (writable && hasBoxes)
          OutlinedButton.icon(
            key: const ValueKey('tool-sort'),
            onPressed: () => _sort(context, ref),
            icon: const Icon(Icons.sort_rounded),
            label: Text(tr(context, 'Ordenar cajas', 'Sort boxes')),
          ),
        OutlinedButton.icon(
          key: const ValueKey('tool-official'),
          onPressed: () => context.push('/dex/formato-oficial'),
          icon: const Icon(Icons.emoji_events_outlined),
          label: Text(tr(context, 'Formato oficial', 'Official format')),
        ),
      ],
    );
  }
}
