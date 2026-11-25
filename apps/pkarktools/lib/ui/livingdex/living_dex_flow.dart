import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../../editing/draft.dart';
import '../common/adaptive.dart';
import '../common/format.dart';

/// Botón «Generar Living Dex en la partida actual» de la ficha de la partida.
class LivingDexButton extends ConsumerWidget {
  const LivingDexButton({super.key, required this.snapshotId, required this.game, required this.onSaved});
  final int snapshotId;
  final GameVersion game;
  final ValueChanged<int> onSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Tooltip(
      message: l10n.livingDexButtonDesc,
      child: OutlinedButton.icon(
        key: const Key('livingDexButton'),
        icon: const Icon(Icons.auto_awesome_motion_rounded),
        label: Text(l10n.livingDexButton),
        onPressed: () => runLivingDexFlow(context, ref, snapshotId, game, onSaved),
      ),
    );
  }
}

/// Pregunta normal/variocolor, avisa de que se sobrescriben las cajas (la versión
/// anterior queda en el historial del Arca), genera la Living Dex y la guarda como
/// versión nueva del save.
Future<void> runLivingDexFlow(
    BuildContext context, WidgetRef ref, int snapshotId, GameVersion game, ValueChanged<int> onSaved) async {
  final l10n = context.l10n;
  final draft = ref.read(draftProvider(snapshotId));
  final editor = draft.editor;
  final messenger = ScaffoldMessenger.of(context);
  if (editor == null) return;
  if (!LivingDexDb.supports(game)) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.livingDexUnsupported)));
    return;
  }
  if (editor.readOnly) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.livingDexReadOnly)));
    return;
  }

  // 1) Normal o variocolor.
  final shiny = await showDialog<bool>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.livingDexKindTitle),
      children: [
        ListTile(
          key: const Key('livingDexNormal'),
          leading: const Icon(Icons.catching_pokemon_rounded),
          title: Text(l10n.livingDexNormal),
          subtitle: Text(l10n.livingDexNormalDesc),
          onTap: () => Navigator.pop(ctx, false),
        ),
        ListTile(
          key: const Key('livingDexShiny'),
          leading: const Icon(Icons.auto_awesome_rounded),
          title: Text(l10n.livingDexShiny),
          subtitle: Text(l10n.livingDexShinyDesc),
          onTap: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  if (shiny == null || !context.mounted) return;

  // 2) Aviso con lo que se sobrescribe y confirmación explícita.
  final plan = LivingDex.plan(editor);
  final es = context.isSpanish;
  var current = 0;
  for (var b = 0; b < editor.boxCount; b++) {
    for (var s = 0; s < editor.boxSlotCount; s++) {
      if (editor.get(SlotRef.box(b, s)) != null) current++;
    }
  }
  final notObtainable = plan.excludedBy(LivingDexExclusion.notObtainable).length;
  final body = StringBuffer(l10n.livingDexConfirmBody(es ? game.nameEs : game.nameEn, plan.slots.length, editor.boxCount, current));
  if (!plan.fits) {
    final last = plan.slots[plan.capacity - 1];
    body.write('\n\n${l10n.livingDexNoFit(Species.name(last.species, es ? SpeciesLanguage.es : SpeciesLanguage.en), plan.slots.length, plan.capacity)}');
  }
  final impossible = plan.slots.take(plan.capacity).where((s) => !s.canBeShiny).length;
  if (shiny && impossible > 0) body.write('\n\n${l10n.livingDexShinyNote(impossible)}');
  body.write('\n\n${l10n.livingDexExcludedNote(notObtainable)}');
  final ok = await confirmAdaptive(
    context,
    title: l10n.livingDexConfirmTitle,
    body: body.toString(),
    confirm: l10n.livingDexGenerate,
    cancel: l10n.cancel,
    icon: Icons.auto_awesome_motion_rounded,
    destructive: true,
  );
  if (!ok || !context.mounted) return;

  // 3) Generar, aplicar al borrador y guardar como versión nueva en el Arca.
  final nav = Navigator.of(context, rootNavigator: true);
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: Row(children: [
        const CircularProgressIndicator(),
        const SizedBox(width: 20),
        Expanded(child: Text(l10n.livingDexWorking)),
      ]),
    ),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 50));
  try {
    final batch = LivingDex.generate(editor, plan, shiny: shiny);
    final note = l10n.livingDexNote(shiny ? l10n.livingDexKindShiny : l10n.livingDexKindNormal, batch.pokemon.length);
    final ctrl = ref.read(draftProvider(snapshotId).notifier);
    ctrl.apply(batch.edit(label: note));
    final id = await ctrl.saveToArca(note);
    nav.pop();
    if (id != null) onSaved(id);
    final r = batch.result;
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      content: Text([
        l10n.livingDexDone(r.written, r.shiny),
        if (r.left.isNotEmpty) l10n.livingDexDoneLeft(r.left.length),
      ].join(' ')),
    ));
  } catch (e) {
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.loadError('$e'))));
  }
}
