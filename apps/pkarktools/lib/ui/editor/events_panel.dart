import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../../editing/draft.dart';
import '../../theme/app_theme.dart';
import '../common/adaptive.dart';
import '../common/format.dart';
import '../editor/legality_view.dart' show warningColor;
import 'pickers.dart';

enum _EventTab { flags, work }

/// Editor de flags y constantes de eventos, con nombres donde hay tabla fiable.
class EventsPanel extends ConsumerStatefulWidget {
  const EventsPanel({super.key, required this.snapshotId, required this.editor});
  final int snapshotId;
  final SaveEditor editor;

  @override
  ConsumerState<EventsPanel> createState() => _EventsPanelState();
}

class _EventsPanelState extends ConsumerState<EventsPanel> {
  _EventTab _tab = _EventTab.flags;
  bool? _namedOnly;
  String _query = '';
  int _limit = 150;

  void _apply(SaveEditOp op) => ref.read(draftProvider(widget.snapshotId).notifier).apply(op);

  EventLanguage get _lang => context.dataLang == DataLanguage.es ? EventLanguage.es : EventLanguage.en;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final ev = widget.editor.events;
    if (ev == null) return Text(l10n.eventsUnsupported, style: context.text.bodyLarge!.copyWith(color: tokens.muted));

    final flags = _tab == _EventTab.flags;
    final named = flags ? ev.namedFlags(_lang) : ev.namedWork(_lang);
    final hasNames = named.isNotEmpty;
    final namedOnly = (_namedOnly ?? hasNames) && hasNames;
    final total = flags ? ev.flagCount : ev.workCount;
    final q = _query.trim().toLowerCase();

    // Filas: (índice, nombre, etiqueta)
    final rows = <(int, String?, EventLabel?)>[];
    if (namedOnly) {
      for (final l in named) {
        rows.add((l.index, l.text, l));
      }
    } else {
      final byIndex = {for (final l in named) l.index: l};
      for (var i = 0; i < total; i++) {
        rows.add((i, byIndex[i]?.text, byIndex[i]));
      }
    }
    final filtered = [
      for (final r in rows)
        if (q.isEmpty || '${r.$1}' == q || '0x${r.$1.toRadixString(16)}' == q || (r.$2?.toLowerCase().contains(q) ?? false)) r,
    ];
    final visible = filtered.take(_limit).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: warningColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: warningColor.withValues(alpha: 0.45)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.report_gmailerrorred_rounded, color: warningColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.eventsWarningTitle, style: context.text.titleMedium),
              const SizedBox(height: 4),
              Text(l10n.eventsWarningBody, style: context.text.bodyMedium),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SegmentedButton<_EventTab>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: _EventTab.flags, icon: const Icon(Icons.flag_outlined), label: Text(l10n.eventsFlags(ev.flagCount))),
            if (ev.workCount > 0)
              ButtonSegment(value: _EventTab.work, icon: const Icon(Icons.tag_rounded), label: Text(l10n.eventsWork(ev.workCount))),
          ],
          selected: {_tab},
          onSelectionChanged: (v) => setState(() {
            _tab = v.first;
            _limit = 150;
          }),
        ),
        if (hasNames)
          FilterChip(
            label: Text(l10n.eventsNamed),
            selected: namedOnly,
            onSelected: (v) => setState(() => _namedOnly = v),
          ),
        SizedBox(
          // En teléfono, a lo ancho y con un placeholder corto que no se corta.
          width: context.isPhone ? double.infinity : 280,
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: context.isPhone ? l10n.dexSearchShort : l10n.eventsSearch,
              hintMaxLines: 1,
              isDense: !context.isPhone,
            ),
            onChanged: (v) => setState(() {
              _query = v;
              _limit = 150;
            }),
          ),
        ),
      ]),
      if (!hasNames) ...[
        const SizedBox(height: 12),
        Text(l10n.eventsNoNames, style: context.text.bodySmall!.copyWith(color: tokens.muted)),
      ],
      const SizedBox(height: 14),
      if (visible.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(l10n.eventsNoMatch, style: context.text.bodyMedium!.copyWith(color: tokens.muted)),
        )
      else
        Material(
          color: tokens.raised,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: tokens.hairline)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) Divider(height: 1, color: tokens.hairline),
              flags
                  ? _FlagRow(
                      index: visible[i].$1,
                      name: visible[i].$2,
                      value: ev.getFlag(visible[i].$1),
                      onChanged: (v) => _apply(EventEdit(flags: {visible[i].$1: v})),
                    )
                  : _WorkRow(
                      key: ValueKey('w${visible[i].$1}-${ev.getWork(visible[i].$1)}'),
                      index: visible[i].$1,
                      name: visible[i].$2,
                      label: visible[i].$3,
                      value: ev.getWork(visible[i].$1),
                      max: ev.workMax,
                      onChanged: (v) => _apply(EventEdit(work: {visible[i].$1: v})),
                    ),
            ],
          ]),
        ),
      const SizedBox(height: 12),
      Row(children: [
        Text(l10n.eventsShowing(filtered.length, '${visible.length}'),
            style: context.text.bodySmall!.copyWith(color: tokens.muted)),
        const Spacer(),
        if (visible.length < filtered.length)
          TextButton(onPressed: () => setState(() => _limit += 300), child: Text(l10n.showMore)),
      ]),
    ]);
  }
}

String _hex(int i) => '0x${i.toRadixString(16).toUpperCase().padLeft(3, '0')}';

class _FlagRow extends StatelessWidget {
  const _FlagRow({required this.index, required this.name, required this.value, required this.onChanged});
  final int index;
  final String? name;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SwitchListTile(
      dense: true,
      value: value,
      onChanged: onChanged,
      title: Text(name ?? context.l10n.eventsUnnamed,
          style: name == null ? context.text.bodyMedium!.copyWith(color: tokens.muted) : context.text.bodyMedium),
      subtitle: Text('#$index  ${_hex(index)}',
          style: context.text.labelSmall!.copyWith(color: tokens.muted, fontFeatures: const [FontFeature.tabularFigures()])),
    );
  }
}

class _WorkRow extends StatefulWidget {
  const _WorkRow(
      {super.key, required this.index, required this.name, required this.label, required this.value, required this.max, required this.onChanged});
  final int index;
  final String? name;
  final EventLabel? label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  State<_WorkRow> createState() => _WorkRowState();
}

class _WorkRowState extends State<_WorkRow> {
  late final _c = TextEditingController(text: '${widget.value}');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _commit() {
    final v = int.tryParse(_c.text);
    if (v == null || v == widget.value) {
      _c.text = '${widget.value}';
      return;
    }
    widget.onChanged(v.clamp(0, widget.max));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final options = widget.label?.options ?? const <EventOption>[];
    final known = options.any((o) => o.value == widget.value);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.name ?? context.l10n.eventsUnnamed,
                style: widget.name == null ? context.text.bodyMedium!.copyWith(color: tokens.muted) : context.text.bodyMedium),
            Text('#${widget.index}  ${_hex(widget.index)}',
                style: context.text.labelSmall!.copyWith(color: tokens.muted, fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
        if (options.length > 1)
          DropdownButton<int>(
            value: known ? widget.value : null,
            hint: Text('${widget.value}'),
            underline: const SizedBox.shrink(),
            items: [for (final o in options.where((o) => o.value >= 0)) DropdownMenuItem(value: o.value, child: Text(o.label))],
            onChanged: (v) => v == null ? null : widget.onChanged(v),
          )
        else
          SizedBox(
            width: 110,
            child: TextField(
              controller: _c,
              textAlign: TextAlign.end,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(isDense: true),
              onSubmitted: (_) => _commit(),
              onTapOutside: (_) => _commit(),
            ),
          ),
      ]),
    );
  }
}
