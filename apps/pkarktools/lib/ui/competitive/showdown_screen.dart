import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../../data/arca_repository.dart';
import '../../data/update/champions_update.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../common/species_avatar.dart';
import '../tools/showdown_ui.dart';

/// Un set de Showdown comprobado contra la regulación vigente.
class CheckedSet {
  const CheckedSet(this.set, this.species, this.form, this.reasons);
  final ShowdownSet set;

  /// null si la especie no se reconoce.
  final int? species;
  final int form;
  final List<ChampionsReason> reasons;

  bool get ok => species != null && reasons.isEmpty;

  /// Especie y forma de un texto de Showdown (formas de Escarlata/Púrpura o
  /// de Leyendas Z-A, que son las que usa Champions).
  static (int, int)? resolve(String text) {
    for (final g in const [GameVersion.scarletViolet, GameVersion.legendsZA]) {
      final r = Showdown.resolveSpecies(text, g);
      if (r != null) return (r.species, r.form);
    }
    return null;
  }

  static List<CheckedSet> check(String text) => [
    for (final s in Showdown.parse(text))
      if (resolve(s.speciesText) case (final sp, final f))
        CheckedSet(s, sp, f, ChampionsFormat.speciesReasons(sp, f))
      else
        CheckedSet(s, null, 0, const []),
  ];

  /// Cláusulas del equipo (especie y objeto repetidos, tamaño).
  static List<String> teamIssues(List<CheckedSet> sets, {required bool es}) {
    final out = <String>[];
    final species = <int>{}, items = <String, int>{};
    for (final c in sets) {
      if (c.species != null && ChampionsFormat.speciesClause && !species.add(c.species!)) {
        out.add(
          ChampionsFormat.teamIssueText((
            ChampionsTeamIssue.duplicateSpecies,
            Species.name(c.species!, es ? SpeciesLanguage.es : SpeciesLanguage.en),
          ), es: es),
        );
      }
      final item = c.set.item?.trim() ?? '';
      if (item.isNotEmpty) {
        final k = Showdown.norm(item);
        final n = (items[k] ?? 0) + 1;
        items[k] = n;
        if (n == ChampionsFormat.itemClause + 1) {
          out.add(ChampionsFormat.teamIssueText((ChampionsTeamIssue.duplicateItem, item), es: es));
        }
      }
    }
    if (sets.length > ChampionsFormat.teamSize) {
      out.add(es ? 'Más de ${ChampionsFormat.teamSize} Pokémon.' : 'More than ${ChampionsFormat.teamSize} Pokémon.');
    }
    if (sets.length < ChampionsFormat.bringDoubles) {
      out.add(ChampionsFormat.teamIssueText((ChampionsTeamIssue.tooFew, '${ChampionsFormat.bringDoubles}'), es: es));
    }
    return out;
  }
}

/// Showdown en Competitivo: comprobar un equipo pegado con la regulación
/// vigente y exportar el equipo de una partida del Arca. Importar a una
/// partida sigue en la partida (necesita su borrador).
class ShowdownScreen extends ConsumerStatefulWidget {
  const ShowdownScreen({super.key});

  @override
  ConsumerState<ShowdownScreen> createState() => _ShowdownScreenState();
}

class _ShowdownScreenState extends ConsumerState<ShowdownScreen> {
  final _text = TextEditingController();
  List<CheckedSet>? _sets;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _export(ArcaEntry e) async {
    final repo = ref.read(arcaRepositoryProvider);
    final bytes = await repo.snapshotBytes(e.latest);
    if (!mounted) return;
    final editor = SaveEditor.open(bytes);
    final game = GameVersion.fromCode(e.slot.gameCode) ?? editor.game;
    await showShowdownExport(context, editor.party, game);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(championsDataProvider);
    final es = context.isSpanish;
    final l10n = context.l10n;
    final sets = _sets;
    final issues = sets == null || sets.isEmpty ? const <String>[] : CheckedSet.teamIssues(sets, es: es);
    final entries = ref.watch(arcaEntriesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.compShowdownTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          Text(
            l10n.compShowdownPasteHint(ChampionsFormat.formatName),
            style: context.text.bodyMedium!.copyWith(color: context.tokens.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('comp-showdown-text'),
            controller: _text,
            minLines: 6,
            maxLines: 14,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Garchomp @ Choice Scarf\nAbility: Rough Skin\nJolly Nature\n- Earthquake',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: const ValueKey('comp-showdown-check'),
              onPressed: () => setState(() => _sets = CheckedSet.check(_text.text)),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(l10n.compShowdownCheck),
            ),
          ),
          if (sets != null) ...[
            const SizedBox(height: 16),
            if (sets.isEmpty) Text(l10n.toolsNoPokemonFoundIn),
            for (final c in sets) _CheckedTile(c: c, es: es),
            if (sets.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: issues.isEmpty
                    ? Text(l10n.compTeamOk, key: const ValueKey('comp-team-ok'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final i in issues)
                            Text('• $i', style: context.text.bodyMedium!.copyWith(color: context.colors.error)),
                        ],
                      ),
              ),
          ],
          const SizedBox(height: 28),
          Text(l10n.compShowdownExportTitle, style: context.text.titleMedium),
          const SizedBox(height: 4),
          Text(l10n.compShowdownImportHint, style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
          const SizedBox(height: 8),
          if (entries.isEmpty) Text(l10n.toolsThereAreNoPokemon),
          for (final e in entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.ios_share_rounded),
              title: Text(gameTitle(context, e.game, e.slot.versionId)),
              subtitle: Text(e.slot.trainerName),
              onTap: () => _export(e),
            ),
        ],
      ),
    );
  }
}

class _CheckedTile extends StatelessWidget {
  const _CheckedTile({required this.c, required this.es});
  final CheckedSet c;
  final bool es;

  @override
  Widget build(BuildContext context) {
    final level = c.set.level;
    final notes = [
      if (c.species == null) es ? 'Especie desconocida: «${c.set.speciesText}».' : 'Unknown species: “${c.set.speciesText}”.',
      for (final r in c.reasons) ChampionsEligibility.reasonText(r, es: es),
      if (level != null && level > ChampionsFormat.level)
        context.l10n.compShowdownLevel('$level', '${ChampionsFormat.level}'),
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: c.species == null
          ? Icon(Icons.help_outline_rounded, size: 40, color: context.colors.error)
          : SpeciesAvatar(species: c.species!, form: c.form, game: GameVersion.scarletViolet, size: 40),
      title: Text(
        c.species == null ? c.set.speciesText : pokemonName(context, c.species!, c.form, GameVersion.scarletViolet),
      ),
      subtitle: Text(notes.isEmpty ? context.l10n.compShowdownAllowed : notes.join(' ')),
      trailing: Icon(
        c.ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
        color: c.ok ? const Color(0xFF52C98A) : context.colors.error,
      ),
    );
  }
}
