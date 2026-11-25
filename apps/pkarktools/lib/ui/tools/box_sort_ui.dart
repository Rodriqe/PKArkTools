import 'package:flutter/material.dart';
import 'package:pkcore/pkcore.dart';

import '../common/format.dart';
import '../../theme/app_theme.dart';
import '../common/species_avatar.dart';

String boxSortModeLabel(BuildContext context, BoxSortMode m) => switch (m) {
  BoxSortMode.dex => context.l10n.toolsDexNumber,
  BoxSortMode.type => context.l10n.toolsType,
  BoxSortMode.generation => context.l10n.toolsGeneration,
  BoxSortMode.livingDex => context.l10n.toolsLivingDexEachSpeciesIn,
  BoxSortMode.level => context.l10n.toolsLevel,
  BoxSortMode.shinyFirst => context.l10n.toolsShinyFirst,
};

/// Diálogo de ordenar cajas: criterio, alcance y vista previa. Devuelve el
/// plan a aplicar (o null si se cancela).
Future<BoxSortPlan?> showBoxSort(BuildContext context, SaveEditor editor) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => BoxSortScreen(editor: editor)));

class BoxSortScreen extends StatefulWidget {
  const BoxSortScreen({super.key, required this.editor});
  final SaveEditor editor;

  @override
  State<BoxSortScreen> createState() => _BoxSortScreenState();
}

class _BoxSortScreenState extends State<BoxSortScreen> {
  BoxSortMode _mode = BoxSortMode.dex;
  int _first = 0;
  late int _last = widget.editor.boxCount - 1;
  BoxSortPlan? _plan;

  SaveEditor get e => widget.editor;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  void _recompute() => _plan = BoxSorter.plan(e, _mode, firstBox: _first, lastBox: _last);

  void _update(void Function() f) => setState(() {
    f();
    if (_last < _first) _last = _first;
    _recompute();
  });

  @override
  Widget build(BuildContext context) {
    final plan = _plan!;
    final boxes = [for (var b = 0; b < e.boxCount; b++) b];
    // Vista previa: las cajas del rango con algún Pokémon (máximo 4).
    final preview = <int>[
      for (var b = plan.firstBox; b <= plan.lastBox; b++)
        if (plan.layout.entries.any((x) => x.key.box == b && x.value != null)) b,
    ].take(4).toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.toolsSortBoxes)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Text(context.l10n.toolsOrderBy, style: context.text.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in BoxSortMode.values)
                ChoiceChip(
                  key: ValueKey('sort-${m.name}'),
                  label: Text(boxSortModeLabel(context, m)),
                  selected: _mode == m,
                  onSelected: (_) => _update(() => _mode = m),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(context.l10n.toolsScope, style: context.text.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ActionChip(
                label: Text(context.l10n.toolsAllBoxes),
                onPressed: () => _update(() {
                  _first = 0;
                  _last = e.boxCount - 1;
                }),
              ),
              Text(context.l10n.toolsFrom),
              DropdownButton<int>(
                value: _first,
                items: [for (final b in boxes) DropdownMenuItem(value: b, child: Text(e.boxName(b)))],
                onChanged: (v) => _update(() => _first = v ?? 0),
              ),
              Text(context.l10n.toolsTo),
              DropdownButton<int>(
                value: _last,
                items: [
                  for (final b in boxes)
                    if (b >= _first) DropdownMenuItem(value: b, child: Text(e.boxName(b))),
                ],
                onChanged: (v) => _update(() => _last = v ?? _first),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            plan.isNoop
                ? context.l10n.toolsAlreadySortedNothingToMove
                : context.l10n.toolsSlotsChangeYouCanUndo(plan.moved),
            key: const ValueKey('sort-summary'),
            style: context.text.bodyMedium!.copyWith(color: context.tokens.muted),
          ),
          if (_mode == BoxSortMode.livingDex && plan.overflow > 0)
            Text(context.l10n.toolsDuplicatesGoAfterTheLast(plan.overflow), style: context.text.bodySmall),
          const SizedBox(height: 12),
          for (final b in preview) ...[
            Text(e.boxName(b), style: context.text.labelLarge),
            const SizedBox(height: 6),
            _BoxPreview(plan: plan, box: b, game: e.game),
            const SizedBox(height: 14),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            key: const ValueKey('sort-apply'),
            onPressed: plan.isNoop ? null : () => Navigator.of(context).pop(plan),
            icon: const Icon(Icons.sort_rounded),
            label: Text(context.l10n.toolsApplyOrder),
          ),
        ),
      ),
    );
  }
}

class _BoxPreview extends StatelessWidget {
  const _BoxPreview({required this.plan, required this.box, required this.game});
  final BoxSortPlan plan;
  final int box;
  final GameVersion game;

  @override
  Widget build(BuildContext context) {
    final cols = plan.slotsPerBox % 6 == 0 ? 6 : 5;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: context.tokens.sunken, borderRadius: BorderRadius.circular(14)),
      child: GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var s = 0; s < plan.slotsPerBox; s++)
            Center(
              child: switch (plan.layout[SlotRef.box(box, s)]) {
                final Pkm pk => SpeciesAvatar(
                  species: pk.species,
                  form: pk.form,
                  game: game,
                  shiny: pk.isShiny,
                  egg: pk.isEgg,
                  size: 34,
                ),
                null => const SizedBox(width: 34, height: 34),
              },
            ),
        ],
      ),
    );
  }
}
