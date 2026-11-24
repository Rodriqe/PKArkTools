import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../../editing/draft.dart';
import '../../theme/app_theme.dart';
import '../common/adaptive.dart';
import '../common/format.dart';
import '../common/game_icons.dart';
import 'pickers.dart';

/// Edición de bolsillos y cantidades. Los cambios se acumulan y se aplican
/// al borrador de una vez con "Aplicar".
class InventoryPanel extends ConsumerStatefulWidget {
  const InventoryPanel({super.key, required this.snapshotId, required this.editor});
  final int snapshotId;
  final SaveEditor editor;

  @override
  ConsumerState<InventoryPanel> createState() => _InventoryPanelState();
}

class _InventoryPanelState extends ConsumerState<InventoryPanel> {
  List<InventoryPouch> _orig = const [];
  List<InventoryPouch> _work = const [];
  int _pouch = 0;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant InventoryPanel old) {
    super.didUpdateWidget(old);
    if (old.editor != widget.editor) _reset();
  }

  void _reset() {
    _orig = widget.editor.readInventory() ?? const [];
    _work = [..._orig];
    if (_pouch >= _work.length) _pouch = 0;
  }

  bool get _changed {
    for (var i = 0; i < _work.length; i++) {
      final a = _work[i].items, b = _orig[i].items;
      if (a.length != b.length) return true;
      for (var j = 0; j < a.length; j++) {
        if (a[j] != b[j]) return true;
      }
    }
    return false;
  }

  void _update(List<InventoryItem> items) => setState(() => _work[_pouch] = _work[_pouch].withItems(items));

  String _pouchName(BuildContext context, String type) {
    final l10n = context.l10n;
    final la = widget.editor.game == GameVersion.legendsArceus;
    return switch (type) {
      'Items' when la => l10n.pouchSatchel,
      'PCItems' when la => l10n.pouchStorage,
      'Treasure' when la => l10n.pouchRecipes,
      'MegaStones' => l10n.pouchMega,
      'Items' => l10n.pouchItems,
      'KeyItems' => l10n.pouchKey,
      'Balls' => l10n.pouchBalls,
      'TMHMs' => l10n.pouchTms,
      'Berries' => l10n.pouchBerries,
      'Medicine' => l10n.pouchMedicine,
      'BattleItems' => l10n.pouchBattle,
      'MailItems' => l10n.pouchMail,
      'PCItems' => l10n.pouchPc,
      'ZCrystals' => l10n.pouchZ,
      'Treasure' => l10n.pouchTreasure,
      'Candy' => l10n.pouchCandy,
      'Ingredients' => l10n.pouchIngredients,
      _ => type,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    if (_work.isEmpty) {
      return Text(l10n.inventoryUnsupported, style: context.text.bodyLarge!.copyWith(color: tokens.muted));
    }
    final gen = widget.editor.game.generation;
    final lang = context.dataLang;
    final pouch = _work[_pouch];
    final present = {for (final it in pouch.items) it.item};
    final addable = [
      for (final id in pouch.legalItems)
        if (!present.contains(id)) PickOption(id, GameStrings.itemFor(id, widget.editor.game, lang)),
    ];
    final full = pouch.items.length >= pouch.capacity;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ScrollingChipRow(
          selectedIndex: _pouch,
          children: [
            for (var i = 0; i < _work.length; i++)
              ChoiceChip(
                selected: i == _pouch,
                showCheckmark: false,
                label: Text('${_pouchName(context, _work[i].type)}  ${_work[i].items.length}'),
                onSelected: (_) => setState(() => _pouch = i),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: SearchPicker(
              key: ValueKey('add-$_pouch-${pouch.items.length}'),
              label: full ? l10n.pouchFull : l10n.addItem,
              options: addable,
              value: 0,
              allowNone: false,
              leading: const Icon(Icons.add_rounded),
              onSelected: (id) {
                if (full || id == 0) return;
                _update([...pouch.items, InventoryItem(id, pouch.maxCount == 1 ? 1 : 1)]);
              },
            ),
          ),
          const SizedBox(width: 12),
          Text(l10n.pouchUsage(pouch.items.length, pouch.capacity),
              style: context.text.labelLarge!.copyWith(color: tokens.muted, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 12),
        if (pouch.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(l10n.pouchEmpty, style: context.text.bodyMedium!.copyWith(color: tokens.muted)),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: tokens.raised,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tokens.hairline),
            ),
            child: Column(children: [
              for (var i = 0; i < pouch.items.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _ItemRow(
                  key: ValueKey('${pouch.type}-${pouch.items[i].item}'),
                  name: GameStrings.itemFor(pouch.items[i].item, widget.editor.game, lang),
                  generation: gen,
                  item: pouch.items[i],
                  max: pouch.maxCount,
                  legal: pouch.legalItems.isEmpty || pouch.legalItems.contains(pouch.items[i].item),
                  onCount: (c) {
                    final list = [...pouch.items];
                    list[i] = list[i].withCount(c);
                    _update(list);
                  },
                  onRemove: () => _update([...pouch.items]..removeAt(i)),
                ),
              ],
            ]),
          ),
        if (pouch.items.isNotEmpty && pouch.maxCount > 1 && context.isPhone) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.swipe_left_rounded, size: 16, color: tokens.muted),
            const SizedBox(width: 6),
            Expanded(child: Text(l10n.pouchSwipeHint, style: context.text.bodySmall!.copyWith(color: tokens.muted))),
          ]),
        ],
        const SizedBox(height: 20),
        ApplyBar(
          revertLabel: l10n.revert,
          applyLabel: l10n.applyChanges,
          onRevert: _changed ? () => setState(_reset) : null,
          onApply: _changed
              ? () {
                  ref.read(draftProvider(widget.snapshotId).notifier).apply(SetInventoryEdit(_work));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.inventoryApplied)));
                }
              : null,
        ),
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.name,
    required this.generation,
    required this.item,
    required this.max,
    required this.legal,
    required this.onCount,
    required this.onRemove,
  });

  final String name;
  final int generation;
  final InventoryItem item;
  final int max;
  final bool legal;
  final ValueChanged<int> onCount;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    {
      // Teléfono: sin botón de borrar (se desliza la fila) para dejar sitio al nombre.
      final compact = context.isPhone;
      final row = Padding(
        padding: EdgeInsets.fromLTRB(16, 6, compact ? 4 : 6, 6),
        child: Row(children: [
          Expanded(
            child: Row(children: [
              ItemIcon(item: item.item, generation: generation, size: compact ? 26 : 30),
              const SizedBox(width: 10),
              Flexible(
                child: Text(name, maxLines: compact ? 2 : 1, overflow: TextOverflow.ellipsis, style: context.text.bodyLarge),
              ),
              if (!legal) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: context.l10n.itemWrongPouch,
                  child: const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFF0A23B)),
                ),
              ],
            ]),
          ),
          if (max > 1) ...[
            IconButton(
              tooltip: '−1',
              onPressed: item.count > 1 ? () => onCount(item.count - 1) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: compact ? 52 : 64,
              child: _CountField(value: item.count, max: max, onCommit: onCount),
            ),
            IconButton(
              tooltip: '+1',
              onPressed: item.count < max ? () => onCount(item.count + 1) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
          if (!compact || max <= 1)
            IconButton(
              tooltip: context.l10n.removeItem,
              onPressed: onRemove,
              icon: Icon(Icons.delete_outline_rounded, color: tokens.muted),
            ),
        ]),
      );
      if (!compact || max <= 1) return row;
      return Dismissible(
        key: ValueKey('dismiss-${item.item}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onRemove(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: context.colors.error.withValues(alpha: 0.85),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(context.l10n.removeItem, style: context.text.labelLarge!.copyWith(color: context.colors.onError)),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: context.colors.onError),
          ]),
        ),
        child: Semantics(
          customSemanticsActions: {CustomSemanticsAction(label: context.l10n.removeItem): onRemove},
          child: row,
        ),
      );
    }
  }
}

class _CountField extends StatefulWidget {
  const _CountField({required this.value, required this.max, required this.onCommit});
  final int value;
  final int max;
  final ValueChanged<int> onCommit;
  @override
  State<_CountField> createState() => _CountFieldState();
}

class _CountFieldState extends State<_CountField> {
  late final _c = TextEditingController(text: '${widget.value}');
  final _f = FocusNode();

  @override
  void initState() {
    super.initState();
    _f.addListener(() {
      if (!_f.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _CountField old) {
    super.didUpdateWidget(old);
    if (!_f.hasFocus) _c.text = '${widget.value}';
  }

  void _commit() {
    final v = (int.tryParse(_c.text) ?? widget.value).clamp(1, widget.max);
    _c.text = '$v';
    if (v != widget.value) widget.onCommit(v);
  }

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        focusNode: _f,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        decoration: const InputDecoration(isDense: true),
        onSubmitted: (_) => _commit(),
      );
}
