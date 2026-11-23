import 'package:flutter/material.dart';

import '../../data/arca_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/game_palette.dart';
import '../common/cartridge.dart';
import '../common/format.dart';
import '../common/species_avatar.dart';

/// Tarjeta de una partida del Arca con forma de cartucho.
class SaveCard extends StatefulWidget {
  const SaveCard({super.key, required this.entry, required this.onOpen});

  final ArcaEntry entry;
  final VoidCallback onOpen;

  @override
  State<SaveCard> createState() => _SaveCardState();
}

class _SaveCardState extends State<SaveCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final tokens = context.tokens;
    final l10n = context.l10n;
    final accent = GamePalette.of(e.game, e.slot.versionId);
    final party = ArcaRepository.decodeParty(e.latest.partySummary);
    final hours = Duration(seconds: e.latest.playTimeSeconds).inHours;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedSlide(
        offset: _hover && !reduceMotion ? const Offset(0, -0.012) : Offset.zero,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Material(
          color: tokens.raised,
          shape: CartridgeBorder(side: BorderSide(color: _hover ? accent.withValues(alpha: 0.7) : tokens.hairline)),
          clipBehavior: Clip.antiAlias,
          elevation: _hover ? 10 : 2,
          shadowColor: accent.withValues(alpha: 0.35),
          child: InkWell(
            onTap: widget.onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Hero(
                  tag: 'slot-label-${e.slot.id}',
                  child: CartridgeLabel(game: e.game, versionId: e.slot.versionId),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(e.slot.trainerName,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.headlineSmall),
                            ),
                            Text(l10n.hoursShort(hours),
                                style: context.text.titleLarge!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${l10n.trainerId} ${e.slot.displayTid}   ${l10n.copies}: ${e.snapshotCount}',
                          style: context.text.bodySmall!.copyWith(color: tokens.muted, fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 34,
                          child: party.isEmpty
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(e.latest.boxedCount > 0 ? Icons.inventory_2_outlined : Icons.catching_pokemon_rounded,
                                        size: 18, color: tokens.muted.withValues(alpha: 0.7)),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                          e.latest.boxedCount > 0 ? l10n.pokemonCount(e.latest.boxedCount) : l10n.cardNoParty,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.text.bodySmall!.copyWith(color: tokens.muted)),
                                    ),
                                  ]),
                                )
                              : Row(children: [
                                  for (final p in party)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: SpeciesAvatar(species: p.species, shiny: p.shiny, egg: p.egg, size: 32),
                                    ),
                                ]),
                        ),
                        const SizedBox(height: 10),
                        Text(l10n.lastCopy(formatDate(context, e.latest.importedAt)),
                            style: context.text.labelSmall!.copyWith(color: tokens.muted)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
