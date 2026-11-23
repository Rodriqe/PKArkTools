import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pkcore/pkcore.dart';

import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../common/game_icons.dart';
import '../common/version_chip.dart';
import 'pickers.dart';

/// Resumen del origen (juego, Ball y lugar) para la ficha.
class OriginSummary extends StatelessWidget {
  const OriginSummary({super.key, required this.pk});
  final Pkm pk;

  @override
  Widget build(BuildContext context) {
    final lang = context.dataLang;
    final v = pk.version;
    final loc = pk.metLocation;
    return Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
      if (v > 0) VersionChip(version: v),
      if (pk.generation >= 3) BallIcon(ball: pk.ball, size: 22),
      if (loc > 0 && v > 0)
        Text(EncounterTables.locationName(v, loc, lang),
            style: context.text.bodySmall!.copyWith(color: context.tokens.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
    ]);
  }
}

/// Sección «Origen» del editor: juego, lugar, nivel y fecha de encuentro,
/// huevo, Ball, entrenador original y traspasos. Los selectores solo ofrecen
/// lugares y Balls válidos para el juego (tablas de encuentros portadas).
class OriginPanel extends StatefulWidget {
  const OriginPanel({super.key, required this.pk, required this.game, required this.mutate});
  final Pkm pk;
  final GameVersion game;
  final void Function(void Function(Pkm p)) mutate;

  @override
  State<OriginPanel> createState() => _OriginPanelState();
}

class _OriginPanelState extends State<OriginPanel> {
  bool _allPlaces = false;

  Pkm get pk => widget.pk;

  String _date(BuildContext context, DateTime? d) => d == null ? context.l10n.originDateUnknown : formatDate(context, d);

  Future<DateTime?> _pickDate(BuildContext context, DateTime? current) => showDatePicker(
        context: context,
        initialDate: current ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2099, 12, 31),
      );

  String _transferName(BuildContext context, TransferStep t) {
    final l10n = context.l10n;
    return switch (t) {
      TransferStep.palPark => l10n.transferPalPark,
      TransferStep.pokeTransfer => l10n.transferPokeTransfer,
      TransferStep.transporter => l10n.transferTransporter,
      TransferStep.virtualConsole => l10n.transferVirtualConsole,
      TransferStep.go => 'Pokémon GO',
      TransferStep.bank => l10n.transferBank,
      TransferStep.home => 'Pokémon HOME',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final lang = context.dataLang;
    final v = pk.version;
    final egg = pk.hatchedFromEgg || pk.isEgg;
    final gen = pk.generation;
    final check = EncounterCheck.of(pk);
    final places = OriginPlace.locations(v, pk.species, lang, all: _allPlaces);
    final loc = pk.metLocation;
    final placeOptions = [
      for (final o in places) PickOption(o.id, o.name, highlight: o.encounter, hint: o.encounter ? l10n.originEncounterHere : null),
    ];
    final versions = OriginPlace.originVersions(pk.format);
    final balls = OriginPlace.balls(v, widget.game);
    final ballOpts = [...balls, if (pk.ball > 0 && !balls.contains(pk.ball)) pk.ball];
    final transfers = pk.transfers;

    Widget fact(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: tokens.muted),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: context.text.bodyMedium)),
          ]),
        );

    final metName = v > 0 ? EncounterTables.locationName(v, loc, lang) : '—';
    final eggName = v > 0 && pk.eggLocation > 0 ? EncounterTables.locationName(v, pk.eggLocation, lang) : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Lectura
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (v > 0) VersionChip(version: v),
        if (gen >= 3)
          Row(mainAxisSize: MainAxisSize.min, children: [
            BallIcon(ball: pk.ball, size: 24),
            const SizedBox(width: 4),
            Text(ballName(context, pk.ball), style: context.text.labelLarge),
          ]),
        if (pk.fatefulEncounter) Chip(label: Text(l10n.originFateful), visualDensity: VisualDensity.compact),
      ]),
      const SizedBox(height: 12),
      if (egg) ...[
        fact(Icons.egg_outlined, l10n.originEggReceived(_date(context, pk.eggDate), eggName ?? '—')),
        if (!pk.isEgg) fact(Icons.place_outlined, l10n.originHatched(_date(context, pk.metDate), metName)),
      ] else
        fact(Icons.place_outlined,
            l10n.originMet(pk.hasDates ? _date(context, pk.metDate) : l10n.originNoDate, pk.metLevel, metName)),
      fact(Icons.person_outline_rounded, l10n.originTrainer(pk.otName.trim().isEmpty ? '—' : pk.otName, pk.tid.toString().padLeft(5, '0'))),
      if (transfers.isNotEmpty)
        fact(Icons.swap_horiz_rounded, transfers.map((t) => _transferName(context, t)).join(' → ')),
      if (pk.homeTracker != 0) fact(Icons.home_outlined, l10n.originHomeTracker(pk.homeTracker.toRadixString(16).toUpperCase())),
      if (check.checked && !check.valid)
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.errorContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            check.candidates.isEmpty
                ? l10n.originNotInGame
                : l10n.originValidPlaces(check.describe(check.candidates, lang)),
            style: context.text.bodySmall,
          ),
        ),
      const SizedBox(height: 16),
      // Edición
      LayoutBuilder(builder: (context, c) {
        final cols = math.max(1, (c.maxWidth / 240).floor());
        const gap = 14.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        SizedBox cell(Widget child) => SizedBox(width: w, child: child);
        return Wrap(spacing: gap, runSpacing: gap, children: [
          if (versions.isNotEmpty)
            cell(DropdownButtonFormField<int>(
              key: ValueKey('origin-version-$v'),
              initialValue: versions.contains(v) ? v : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.originGame),
              items: [
                for (final x in versions)
                  DropdownMenuItem(
                    value: x,
                    child: Row(children: [
                      VersionSwatch(colors: [VersionChip.colorOf(context, x)], size: 12),
                      const SizedBox(width: 8),
                      Expanded(child: Text(GameVersions.name(x, es: context.isSpanish), overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
              ],
              onChanged: (x) {
                if (x != null) widget.mutate((p) => p.version = x);
              },
            )),
          if (gen >= 3 && v > 0)
            cell(SearchPicker(
              key: ValueKey('origin-place-$v-$_allPlaces'),
              label: pk.hatchedFromEgg ? l10n.originHatchPlace : l10n.originPlace,
              options: placeOptions,
              value: loc,
              labelFor: (id) => EncounterTables.locationName(v, id, lang),
              onSelected: (id) => widget.mutate((p) => p.metLocation = id),
            )),
          if (gen >= 3)
            cell(TextFormField(
              key: ValueKey('origin-level-${pk.metLevel}'),
              initialValue: '${pk.metLevel}',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.originLevel),
              onFieldSubmitted: (t) {
                final n = int.tryParse(t);
                if (n != null) widget.mutate((p) => p.metLevel = n.clamp(0, 100));
              },
            )),
          if (pk.hasDates)
            cell(OutlinedButton.icon(
              onPressed: () async {
                final d = await _pickDate(context, pk.metDate);
                if (d != null) widget.mutate((p) => p.metDate = d);
              },
              icon: const Icon(Icons.event_outlined),
              label: Text('${l10n.originDate}: ${_date(context, pk.metDate)}', overflow: TextOverflow.ellipsis),
            )),
          if (gen >= 3)
            cell(DropdownButtonFormField<int>(
              key: ValueKey('origin-ball-${pk.ball}-$v'),
              initialValue: ballOpts.contains(pk.ball) ? pk.ball : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.ball),
              items: [
                for (final b in ballOpts)
                  DropdownMenuItem(
                    value: b,
                    child: Row(children: [
                      BallIcon(ball: b, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(balls.contains(b) ? ballName(context, b) : '${ballName(context, b)} ⚠',
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ),
              ],
              onChanged: (b) {
                if (b != null) widget.mutate((p) => p.ball = b);
              },
            )),
          if (pk.hasDates && egg)
            cell(OutlinedButton.icon(
              onPressed: () async {
                final d = await _pickDate(context, pk.eggDate);
                if (d != null) widget.mutate((p) => p.eggDate = d);
              },
              icon: const Icon(Icons.egg_outlined),
              label: Text('${l10n.originEggDate}: ${_date(context, pk.eggDate)}', overflow: TextOverflow.ellipsis),
            )),
        ]);
      }),
      if (gen >= 3 && v > 0)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _allPlaces = !_allPlaces),
            icon: Icon(_allPlaces ? Icons.filter_alt_rounded : Icons.filter_alt_off_outlined, size: 18),
            label: Text(_allPlaces ? l10n.originOnlyValid : l10n.originShowAll),
          ),
        ),
    ]);
  }
}
