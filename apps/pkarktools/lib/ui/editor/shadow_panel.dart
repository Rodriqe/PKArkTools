import 'package:flutter/material.dart';
import 'package:pkcore/pkcore.dart';

import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../common/shadow_mark.dart';
import '../common/species_avatar.dart';

/// Sección «Pokémon oscuro» del editor (Colosseum / XD): estado, id oscuro y
/// medidor de corazón; o, si el Pokémon no es oscuro, el botón para
/// sustituirlo por uno de los Pokémon oscuros del juego. Purificar o volver a
/// oscuro pide confirmación: no es lo mismo que hacerlo en el juego (no da
/// experiencia ni movimientos).
class ShadowPanel extends StatelessWidget {
  const ShadowPanel({super.key, required this.pk, required this.game, required this.mutate});
  final Pkm pk;
  final GameVersion game;
  final void Function(void Function(Pkm p)) mutate;

  /// `true` si hay algo que mostrar: el Pokémon fue o es oscuro, o el juego
  /// abierto es Colosseum/XD (se puede convertir en uno de sus oscuros).
  static bool applies(Pkm pk, GameVersion game) =>
      (pk.gc?.shadowId ?? 0) != 0 || (game.isColosseumOrXd && !pk.isEgg);

  int? _maxGauge(GcExtra gc) => ShadowMark.maxGauge(gc);

  Future<bool> _confirm(BuildContext context, String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  /// Elige un encuentro oscuro y sustituye el Pokémon por él (mismo OT/ID).
  Future<void> _replace(BuildContext context) async {
    final l10n = context.l10n;
    final choice = await ShadowPicker.show(context, game);
    if (choice == null || !context.mounted) return;
    if (!await _confirm(context, l10n.shadowApplyTitle, l10n.shadowApplyBody, l10n.shadowApplyConfirm)) return;
    final trainer = TrainerData(name: pk.otName, tid: pk.tid, sid: pk.sid, gender: pk.otGender);
    final created = GcShadow.create(choice.encounter, trainer,
        region: pk.gc?.currentRegion ?? GcRegion.ntscU, language: pk.language, purified: choice.purified);
    mutate((p) {
      p.data.setRange(0, p.data.length, created.data);
      p.gc = created.gc;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final gc = pk.gc;
    if (gc == null || gc.shadowId == 0) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.shadowMakeShadowHint, style: context.text.bodySmall!.copyWith(color: tokens.muted)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('shadow-make'),
          icon: const Icon(Icons.heart_broken_outlined),
          label: Text(l10n.shadowMakeShadow),
          onPressed: () => _replace(context),
        ),
      ]);
    }
    final max = _maxGauge(gc);
    final shadow = gc.isShadow;
    final color = shadow ? const Color(0xFF6B3FA0) : const Color(0xFF3E9E6F);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Container(
          key: const ValueKey('shadow-state'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(shadow ? Icons.heart_broken_rounded : Icons.favorite_rounded, size: 18, color: color),
            const SizedBox(width: 6),
            Text(shadow ? l10n.shadowStateShadow : l10n.shadowStatePurified,
                style: context.text.labelLarge!.copyWith(color: color, fontWeight: FontWeight.w700)),
          ]),
        ),
        Text(l10n.shadowIdLabel('${gc.shadowId}'), style: context.text.bodyMedium!.copyWith(color: tokens.muted)),
      ]),
      const SizedBox(height: 14),
      if (shadow) ...[
        Text(l10n.shadowGauge, style: context.text.labelMedium!.copyWith(color: tokens.muted)),
        if (max != null && max > 0)
          Row(children: [
            Expanded(
              child: Slider(
                key: const ValueKey('shadow-gauge'),
                value: gc.purification.clamp(0, max).toDouble(),
                max: max.toDouble(),
                divisions: (max ~/ 100).clamp(1, 200),
                label: '${gc.purification}',
                onChanged: (v) => mutate((p) => p.gc!.purification = v.round()),
              ),
            ),
            SizedBox(width: 92, child: Text('${gc.purification} / $max', textAlign: TextAlign.end)),
          ])
        else
          Text('${gc.purification}', style: context.text.titleMedium),
        Text(max != null ? l10n.shadowGaugeHint('$max') : l10n.shadowGaugeUnknown,
            style: context.text.bodySmall!.copyWith(color: tokens.muted)),
        const SizedBox(height: 6),
        Text(gc.kind == GcKind.xk3 ? l10n.shadowMoveNoteXd : l10n.shadowMoveNoteColo,
            style: context.text.bodySmall!.copyWith(color: tokens.muted)),
        const SizedBox(height: 6),
        Text(l10n.shadowCannotLeaveNote, style: context.text.bodySmall!.copyWith(color: tokens.muted)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            key: const ValueKey('shadow-purify'),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(l10n.shadowPurify),
            onPressed: () async {
              if (!await _confirm(context, l10n.shadowPurifyTitle, l10n.shadowPurifyBody, l10n.shadowPurifyConfirm)) return;
              mutate((p) => GcShadow.setPurified(p, true));
            },
          ),
          if (game.isColosseumOrXd)
            TextButton.icon(
              key: const ValueKey('shadow-change'),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text(l10n.shadowChangeEncounter),
              onPressed: () => _replace(context),
            ),
        ]),
      ] else ...[
        Text(l10n.shadowPurifiedNote, style: context.text.bodySmall!.copyWith(color: tokens.muted)),
        const SizedBox(height: 12),
        TextButton.icon(
          key: const ValueKey('shadow-revert'),
          icon: const Icon(Icons.undo_rounded),
          label: Text(l10n.shadowRevert),
          onPressed: () async {
            if (!await _confirm(context, l10n.shadowRevertTitle, l10n.shadowRevertBody, l10n.shadowRevertConfirm)) return;
            mutate((p) => GcShadow.setPurified(p, false, gauge: max ?? 0));
          },
        ),
      ],
    ]);
  }
}

/// Encuentro oscuro elegido y si se crea ya purificado.
typedef ShadowChoice = ({GcShadowEncounter encounter, bool purified});

/// Diálogo con los Pokémon oscuros que se capturan en Colosseum o XD.
class ShadowPicker extends StatefulWidget {
  const ShadowPicker({super.key, required this.game});
  final GameVersion game;

  static Future<ShadowChoice?> show(BuildContext context, GameVersion game) =>
      showDialog<ShadowChoice>(context: context, builder: (_) => ShadowPicker(game: game));

  @override
  State<ShadowPicker> createState() => _ShadowPickerState();
}

class _ShadowPickerState extends State<ShadowPicker> {
  late final List<GcShadowEncounter> _all = GcShadowEncounter.forGame(widget.game);
  String _query = '';
  bool _purified = false;
  GcShadowEncounter? _selected;

  String _species(GcShadowEncounter e) =>
      Species.name(e.species, context.isSpanish ? SpeciesLanguage.es : SpeciesLanguage.en);
  String _place(GcShadowEncounter e) =>
      EncounterTables.locationName(EncounterTables.cxd, e.location, context.isSpanish ? DataLanguage.es : DataLanguage.en);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = _query.trim().toLowerCase();
    final list = [
      for (final e in _all)
        if (q.isEmpty ||
            _species(e).toLowerCase().contains(q) ||
            _place(e).toLowerCase().contains(q) ||
            '${e.shadowId}' == q)
          e,
    ];
    return AlertDialog(
      title: Text(l10n.shadowPickTitle),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 520,
        height: 520,
        child: Column(children: [
          TextField(
            key: const ValueKey('shadow-search'),
            autofocus: false,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l10n.shadowPickSearch),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text(l10n.shadowPickEmpty))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final e = list[i];
                      return ListTile(
                        key: ValueKey('shadow-enc-${e.shadowId}-${e.location}'),
                        dense: true,
                        selected: identical(e, _selected),
                        leading: SpeciesAvatar(species: e.species, game: widget.game, size: 36),
                        title: Text(_species(e)),
                        subtitle: Text(l10n.shadowPickEntry('${e.level}', '${e.shadowId}', _place(e)),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => setState(() => _selected = e),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(l10n.shadowPickShadow), icon: const Icon(Icons.heart_broken_rounded)),
              ButtonSegment(value: true, label: Text(l10n.shadowPickPurified), icon: const Icon(Icons.favorite_rounded)),
            ],
            selected: {_purified},
            onSelectionChanged: (v) => setState(() => _purified = v.first),
          ),
          const SizedBox(height: 8),
          Text(l10n.shadowPickHint, style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
        FilledButton(
          key: const ValueKey('shadow-pick-create'),
          onPressed: _selected == null ? null : () => Navigator.pop(context, (encounter: _selected!, purified: _purified)),
          child: Text(l10n.shadowPickCreate),
        ),
      ],
    );
  }
}
