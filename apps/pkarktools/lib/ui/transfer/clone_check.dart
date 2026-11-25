import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../common/species_avatar.dart';

/// Dónde está un Pokémon del Arca (para el detector de clones).
class ArkPokemonPlace {
  const ArkPokemonPlace({required this.game, required this.trainer, required this.box});
  final GameVersion game;
  final String trainer;

  /// Nombre de la caja, o null si está en el equipo.
  final String? box;
}

/// Clones por rastreador de HOME en la copia más reciente de cada partida.
final arkClonesProvider = FutureProvider.autoDispose<List<HomeTrackerCloneGroup<ArkPokemonPlace>>>((ref) async {
  final repo = ref.watch(arcaRepositoryProvider);
  final entries = await ref.watch(arcaEntriesProvider.future);
  final all = <(ArkPokemonPlace, Pkm)>[];
  for (final e in entries) {
    final game = GameVersion.fromCode(e.slot.gameCode);
    if (game == null || game.generation < 8) continue; // Solo HOME pone rastreador.
    try {
      final editor = SaveEditor.open(await repo.snapshotBytes(e.latest));
      if (!editor.canEditStorage) continue;
      for (final pk in editor.party) {
        all.add((ArkPokemonPlace(game: game, trainer: e.slot.trainerName, box: null), pk));
      }
      for (var b = 0; b < editor.boxCount; b++) {
        for (var s = 0; s < editor.boxSlotCount; s++) {
          final pk = editor.get(SlotRef.box(b, s));
          if (pk != null) all.add((ArkPokemonPlace(game: game, trainer: e.slot.trainerName, box: editor.boxName(b)), pk));
        }
      }
    } catch (_) {
      // Una partida que no se puede abrir no impide revisar las demás.
    }
  }
  return HomeTrackerClones.find(all);
});

/// Ajustes → «Clones de HOME»: busca Pokémon con el mismo rastreador de HOME
/// en las partidas del Arca (copias del mismo Pokémon).
class ArkClonesSection extends ConsumerStatefulWidget {
  const ArkClonesSection({super.key});

  @override
  ConsumerState<ArkClonesSection> createState() => _ArkClonesSectionState();
}

class _ArkClonesSectionState extends ConsumerState<ArkClonesSection> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!_started) {
      return OutlinedButton.icon(
        key: const ValueKey('ark-clones-check'),
        onPressed: () => setState(() => _started = true),
        icon: const Icon(Icons.content_copy_rounded),
        label: Text(l10n.clonesCheck),
      );
    }
    final result = ref.watch(arkClonesProvider);
    return result.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e', style: TextStyle(color: context.colors.error)),
      data: (groups) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                groups.isEmpty ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                color: groups.isEmpty ? context.colors.primary : context.colors.error,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(groups.isEmpty ? l10n.clonesNone : l10n.clonesFound(groups.length))),
              IconButton(
                tooltip: l10n.clonesRecheck,
                onPressed: () => ref.invalidate(arkClonesProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          for (final g in groups) _CloneGroupTile(group: g),
        ],
      ),
    );
  }
}

class _CloneGroupTile extends StatelessWidget {
  const _CloneGroupTile({required this.group});
  final HomeTrackerCloneGroup<ArkPokemonPlace> group;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final first = group.pokemon.first;
    final place = group.owners.first;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        leading: SpeciesAvatar(species: first.species, form: first.form, shiny: first.isShiny, size: 40, game: place.game),
        title: Text(pokemonName(context, first.species, first.form, place.game)),
        subtitle: Text(l10n.clonesTracker(BigInt.from(group.tracker).toUnsigned(64).toRadixString(16).toUpperCase().padLeft(16, '0'), group.pokemon.length)),
        children: [
          for (final o in group.owners)
            ListTile(
              dense: true,
              title: Text('${gameTitle(context, o.game)} · ${o.trainer}'),
              subtitle: Text(o.box ?? l10n.team),
            ),
        ],
      ),
    );
  }
}
