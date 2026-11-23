import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pkcore/pkcore.dart';

import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/game_palette.dart';
import '../common/format.dart';
import 'dex_screen.dart';
import 'dex_text.dart';
import 'dex_tile.dart';

/// Progreso de la Dex global: cifras, desglose por generación/región y por juego.
class DexProgressScreen extends ConsumerWidget {
  const DexProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dex = ref.watch(globalDexProvider).value;
    final living = ref.watch(dexLivingProvider);
    final l10n = context.l10n;
    final tokens = context.tokens;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final pad = compact ? 16.0 : 32.0;
    if (dex == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final progress = dex.progress;
    final byGen = dex.byGeneration;
    final byGame = dex.byGame;

    void openGen(int g) {
      ref.read(dexFilterProvider.notifier).update((f) => f.cleared().copyWith(generation: () => g));
      context.go('/dex');
    }

    void openGame(GameVersion g) {
      ref.read(dexFilterProvider.notifier).update((f) => f.cleared().copyWith(game: () => g));
      context.go('/dex');
    }

    Widget card(List<Widget> children) => Material(
          color: tokens.raised,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: tokens.hairline)),
          child: Column(children: children),
        );

    final gens = card([
      for (var g = 1; g <= 9; g++)
        InkWell(
          key: ValueKey('dex-gen-row-$g'),
          onTap: () => openGen(g),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: DexBar(
              label: genRegionLabel(context, g),
              value: living ? byGen[g]!.owned : byGen[g]!.caught,
              total: byGen[g]!.total,
              trailing: '${living ? byGen[g]!.owned : byGen[g]!.caught} / ${byGen[g]!.total}'
                  '${byGen[g]!.shiny > 0 ? ' · ${l10n.dexShinyCount(byGen[g]!.shiny)}' : ''}',
            ),
          ),
        ),
    ]);

    final games = byGame.isEmpty
        ? Text(l10n.dexEmptyBody, style: context.text.bodyMedium!.copyWith(color: tokens.muted))
        : card([
            for (final p in byGame)
              InkWell(
                key: ValueKey('dex-game-row-${p.game.code}'),
                onTap: () => openGame(p.game),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    DexBar(
                      label: shortGame(context, p.game),
                      value: p.caught,
                      total: p.available,
                      color: GamePalette.of(p.game, null),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.dexGameLine('${p.available}', '${p.caught}', p.saves, '${p.seen}'),
                      style: context.text.labelSmall!.copyWith(color: tokens.muted),
                    ),
                  ]),
                ),
              ),
          ]);

    Widget title(String t) => Padding(
          padding: const EdgeInsets.only(top: 26, bottom: 12),
          child: Text(t, style: context.text.titleLarge),
        );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dex'),
        ),
        title: Text(l10n.dexProgress),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, 4, pad, 96),
            children: [
              if (living)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(avatar: const Icon(Icons.inventory_2_rounded, size: 16), label: Text(l10n.dexLivingBadge)),
                  ),
                ),
              DexStatsRow(progress: progress, living: living),
              if (width >= 1000)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title(l10n.dexByGeneration), gens])),
                  const SizedBox(width: 24),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title(l10n.dexByGame), games])),
                ])
              else ...[
                title(l10n.dexByGeneration),
                gens,
                title(l10n.dexByGame),
                games,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
