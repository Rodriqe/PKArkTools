import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pkcore/pkcore.dart';

import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/game_palette.dart';
import '../common/format.dart';

/// Registro cronológico de todas las copias que entraron al Arca.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(activityProvider).value ?? const [];
    final l10n = context.l10n;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final pad = compact ? 16.0 : 32.0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: CustomScrollView(slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, compact ? 20 : 36, pad, 16),
                sliver: SliverToBoxAdapter(
                  child: Row(children: [
                    // En el teléfono se llega desde el Arca: botón para volver.
                    if (compact)
                      IconButton(
                        key: const ValueKey('activity-back'),
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () => context.go('/arca'),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    Expanded(
                      child: Text(l10n.navActivity,
                          style: compact ? context.text.displaySmall : context.text.displayMedium),
                    ),
                  ]),
                ),
              ),
              if (items.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  sliver: SliverToBoxAdapter(
                    child: Text(l10n.activityEmpty, style: context.text.bodyLarge!.copyWith(color: context.tokens.muted)),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 100),
                sliver: SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final it = items[i];
                    final game = GameVersion.fromCode(it.snapshot.gameCode) ?? GameVersion.redBlue;
                    final accent = GamePalette.of(game, it.snapshot.versionId);
                    final day = formatDate(context, it.snapshot.importedAt);
                    final showDay = i == 0 || formatDate(context, items[i - 1].snapshot.importedAt) != day;
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (showDay)
                        Padding(
                          padding: const EdgeInsets.only(top: 18, bottom: 8),
                          child: Text(day, style: context.text.titleSmall!.copyWith(color: context.tokens.muted)),
                        ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: Container(
                          width: 10,
                          height: 40,
                          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4)),
                        ),
                        title: Text('${it.slot.trainerName}, ${gameTitle(context, game, it.snapshot.versionId)}'),
                        subtitle: Text('${it.snapshot.fileName}\n${originLabel(context, it.snapshot.origin)}'),
                        isThreeLine: true,
                        trailing: Text(formatPlayTime(Duration(seconds: it.snapshot.playTimeSeconds)), style: context.text.labelLarge),
                        onTap: () => context.go('/arca/save/${it.slot.id}'),
                      ),
                    ]);
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
