import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../../data/update/champions_update.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';
import 'build_editor.dart';
import 'damage_screen.dart';

/// Un set de ejemplo para empezar: el primero permitido (Garchomp si está).
ChampionsBuild defaultChampionsBuild() {
  final allowed = ChampionsDex.allowedSpecies();
  final s = allowed.firstWhere((x) => x.id == 'garchomp', orElse: () => allowed.first);
  return ChampionsBuild(speciesId: s.id, ability: s.abilities.isEmpty ? '' : s.abilities.first);
}

/// Calculadora de estadísticas de Competitivo (reglas de Champions).
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  ChampionsBuild _build = defaultChampionsBuild();
  int _version = 0;

  void _replace(ChampionsBuild b) => setState(() {
    _build = b;
    _version++;
  });

  Future<void> _fromArk() async {
    final b = await pickFromArk(context);
    if (b != null && mounted) _replace(b);
  }

  Future<void> _fromShowdown() async {
    final list = await pasteFromShowdown(context);
    if (list != null && list.isNotEmpty && mounted) _replace(list.first);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(championsDataProvider);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.compStatsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          Text(
            l10n.compChampionsRules(ChampionsStats.maxPerStat, ChampionsStats.maxTotal),
            style: context.text.bodySmall!.copyWith(color: context.tokens.muted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('stats-from-ark'),
                onPressed: _fromArk,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(l10n.compLoadFromArk),
              ),
              OutlinedButton.icon(
                key: const ValueKey('stats-from-showdown'),
                onPressed: _fromShowdown,
                icon: const Icon(Icons.content_paste_rounded),
                label: Text(l10n.compPasteShowdown),
              ),
              FilledButton.tonalIcon(
                key: const ValueKey('stats-to-damage'),
                onPressed: () => openDamageCalc(context, ref, _build),
                icon: const Icon(Icons.flash_on_rounded),
                label: Text(l10n.compUseInDamage),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ChampionsBuildEditor(
            key: ValueKey('stats-editor-$_version'),
            build: _build,
            full: false,
            keyPrefix: 'stats',
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}
