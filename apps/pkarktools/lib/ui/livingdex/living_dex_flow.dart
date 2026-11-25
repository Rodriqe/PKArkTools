import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../../editing/draft.dart';
import '../common/adaptive.dart';
import '../../l10n/app_localizations.dart';
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
    final summaryContext = nav.context;
    if (summaryContext.mounted) {
      await showDialog<void>(
        context: summaryContext,
        builder: (_) => LivingDexSummaryDialog(game: game, result: r, missing: livingDexMissing(plan, r)),
      );
    }
  } catch (e) {
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.loadError('$e'))));
  }
}

/// Resumen al terminar: cuántos se generaron y todo lo que no, agrupado por motivo.
class LivingDexSummaryDialog extends StatelessWidget {
  const LivingDexSummaryDialog({super.key, required this.game, required this.result, required this.missing});
  final GameVersion game;
  final LivingDexResult result;
  final Map<LivingDexMissingReason, List<(int, int)>> missing;

  static String reasonLabel(AppLocalizations l10n, LivingDexMissingReason r) => switch (r) {
        LivingDexMissingReason.battleOnly => l10n.ldReasonBattleOnly,
        LivingDexMissingReason.fusedOrTotem => l10n.ldReasonFused,
        LivingDexMissingReason.boxReverts => l10n.ldReasonBoxReverts,
        LivingDexMissingReason.eventOnly => l10n.ldReasonEventOnly,
        LivingDexMissingReason.needsRegion => l10n.ldReasonNeedsRegion,
        LivingDexMissingReason.notObtainable => l10n.ldReasonNotObtainable,
        LivingDexMissingReason.shinyImpossible => l10n.ldReasonShinyImpossible,
        LivingDexMissingReason.doesNotFit => l10n.ldReasonDoesNotFit,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groups = [for (final r in LivingDexMissingReason.values) if (missing[r]?.isNotEmpty ?? false) r];
    return AlertDialog(
      key: const Key('livingDexSummary'),
      title: Text(l10n.livingDexSummaryTitle),
      content: SizedBox(
        width: 560,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(l10n.livingDexDone(result.written, result.shiny)),
            const SizedBox(height: 12),
            Text(groups.isEmpty ? l10n.livingDexSummaryNone : l10n.livingDexSummaryMissing),
            for (final g in groups)
              ExpansionTile(
                key: Key('livingDexMissing-${g.name}'),
                tilePadding: EdgeInsets.zero,
                title: Text('${reasonLabel(l10n, g)} (${missing[g]!.length})'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      missing[g]!.map((m) => pokemonName(context, m.$1, m.$2, game)).toSet().join(', '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(MaterialLocalizations.of(context).okButtonLabel))],
    );
  }
}
