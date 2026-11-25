import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/update/champions_update.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../common/species_avatar.dart';
import '../editor/pickers.dart';

/// Un Pokémon de una partida del Arca con su veredicto para el formato.
class ChampionsCandidate {
  const ChampionsCandidate({
    required this.pk,
    required this.game,
    required this.trainer,
    required this.where,
    required this.result,
  });
  final Pkm pk;
  final GameVersion game;
  final String trainer;

  /// «Equipo» o el nombre de la caja.
  final String where;
  final ChampionsEligibility result;
}

/// Revisa la copia más reciente de cada partida del Arca.
final championsCandidatesProvider = FutureProvider.autoDispose.family<List<ChampionsCandidate>, DataLanguage>((
  ref,
  lang,
) async {
  // Se vuelve a revisar si llegan datos nuevos del formato.
  await ref.watch(championsDataProvider.future);
  final repo = ref.watch(arcaRepositoryProvider);
  final entries = await ref.watch(arcaEntriesProvider.future);
  final out = <ChampionsCandidate>[];
  for (final e in entries) {
    final game = GameVersion.fromCode(e.slot.gameCode);
    if (game == null) continue;
    try {
      final editor = SaveEditor.open(await repo.snapshotBytes(e.latest));
      if (!editor.canEditStorage) continue;
      void add(Pkm? pk, String where) {
        if (pk == null) return;
        out.add(
          ChampionsCandidate(
            pk: pk,
            game: game,
            trainer: e.slot.trainerName,
            where: where,
            result: ChampionsFormat.check(pk, game, lang: lang),
          ),
        );
      }

      for (final pk in editor.party) {
        add(pk, lang == DataLanguage.es ? 'Equipo' : 'Party');
      }
      for (var b = 0; b < editor.boxCount; b++) {
        for (var s = 0; s < editor.boxSlotCount; s++) {
          add(editor.get(SlotRef.box(b, s)), editor.boxName(b));
        }
      }
    } catch (_) {
      // Una partida que no se puede abrir no impide revisar las demás.
    }
  }
  return out;
});

/// Sección «Formato oficial»: la regulación vigente de Pokémon Champions,
/// sus reglas, la lista de Pokémon permitidos y cuáles de tus partidas valen.
class ChampionsScreen extends ConsumerStatefulWidget {
  const ChampionsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<ChampionsScreen> createState() => _ChampionsScreenState();
}

class _ChampionsScreenState extends ConsumerState<ChampionsScreen> {
  String _query = '';
  bool _onlyEligible = false;
  bool _checking = false;

  /// Un solo controlador para el buscador de las dos pestañas.
  final _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  bool _matches(int species, int form) {
    if (_query.isEmpty) return true;
    final q = Showdown.norm(_query);
    final es = SpeciesForms.displayName(species, form, GameVersion.scarletViolet, DataLanguage.es);
    final en = SpeciesForms.displayName(species, form, GameVersion.scarletViolet, DataLanguage.en);
    return Showdown.norm(es).contains(q) || Showdown.norm(en).contains(q) || '$species' == _query.trim();
  }

  @override
  Widget build(BuildContext context) {
    final es = context.isSpanish;
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.toolsOfficialFormat),
          bottom: TabBar(
            tabs: [
              Tab(text: context.l10n.toolsRegulation),
              Tab(text: context.l10n.toolsYourPokemon),
            ],
          ),
        ),
        body: TabBarView(children: [_regulationTab(context, es), _yoursTab(context, es)]),
      ),
    );
  }

  Widget _search(BuildContext context) => TextField(
    key: const ValueKey('champions-search'),
    controller: _searchCtl,
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.search_rounded),
      hintText: context.l10n.toolsSearchPokemon,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    onChanged: (v) => setState(() => _query = v),
  );

  Future<void> _checkNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _checking = true);
    final r = await ref.read(championsDataProvider.notifier).checkNow();
    if (!mounted) return;
    setState(() => _checking = false);
    final text = switch (r) {
      ChampionsCheck.updated => l10n.toolsChampionsUpdated(ChampionsFormat.formatName),
      ChampionsCheck.upToDate => l10n.toolsChampionsUpToDate,
      ChampionsCheck.failed => l10n.toolsChampionsCheckFailed,
      ChampionsCheck.none => null,
    };
    if (text != null) messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _regulationTab(BuildContext context, bool es) {
    final status = ref.watch(championsDataProvider).value;
    final reg = ChampionsFormat.regulation;
    final next = ChampionsFormat.nextRegulation;
    final allowed = [
      for (final (s, f) in ChampionsFormat.allowed)
        if (_matches(s, f)) (s, f),
    ];
    final banned = [
      for (final s in {...ChampionsFormat.restrictedSpecies, ...ChampionsFormat.mythicalSpecies}.toList()..sort())
        if (_matches(s, 0)) s,
    ];
    String date(DateTime? d) => d == null ? '?' : formatDate(context, d);
    final data = status?.data ?? ChampionsFormat.data;
    final muted = context.text.bodySmall!.copyWith(color: context.tokens.muted);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        Text('Pokémon Champions · ${ChampionsFormat.formatName}', style: context.text.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '${context.l10n.toolsRegulation} ${reg.code}: ${date(reg.from)} – ${date(reg.until)}',
          style: context.text.titleSmall,
        ),
        if (reg.until != null)
          Text(
            context.l10n.toolsChampionsEndsNext(
              date(reg.until),
              next == null
                  ? context.l10n.toolsChampionsNextNotAnnounced
                  : next.from == null
                  ? next.name
                  : context.l10n.toolsChampionsNextFrom(date(next.from), next.name),
            ),
            key: const ValueKey('champions-next'),
            style: context.text.bodyMedium,
          ),
        if (!reg.datesConfirmed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: context.colors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.l10n.toolsDatesNotConfirmedByAn(reg.datesSource),
                    key: const ValueKey('champions-dates-unconfirmed'),
                    style: muted,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.toolsRules, style: context.text.titleMedium),
                const SizedBox(height: 8),
                for (final r in _rules(context)) _bullet(context, r),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.toolsChampionsUpdatedOn(
            ChampionsFormat.sourceCommit.substring(0, 7),
            date(data.generatedAt.toLocal()),
          ),
          key: const ValueKey('champions-updated'),
          style: muted,
        ),
        if (status?.futureSchema != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              context.l10n.toolsChampionsFutureSchema,
              key: const ValueKey('champions-future-schema'),
              style: context.text.bodySmall!.copyWith(color: context.colors.error),
            ),
          ),
        Wrap(
          spacing: 4,
          children: [
            TextButton.icon(
              key: const ValueKey('champions-check'),
              onPressed: _checking || status == null ? null : _checkNow,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(context.l10n.updateCheck),
            ),
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(ChampionsFormat.sourceUrl)),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(context.l10n.toolsViewSource),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _search(context),
        const SizedBox(height: 14),
        Text(context.l10n.toolsAllowed(allowed.length), style: context.text.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (s, f) in allowed)
              _SpeciesChip(species: s, form: f, mega: ChampionsFormat.megaSpecies.contains(s)),
          ],
        ),
        const SizedBox(height: 18),
        Text(context.l10n.toolsBannedRestrictedLegendariesAndMythicals(banned.length), style: context.text.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final s in banned) _SpeciesChip(species: s, form: 0, banned: true)],
        ),
      ],
    );
  }

  List<String> _rules(BuildContext context) => [
    context.l10n.toolsDoubleBattlesVGCTeamOf(
      ChampionsFormat.teamSize,
      ChampionsFormat.bringDoubles,
      ChampionsFormat.bringSingles,
    ),
    context.l10n.toolsLevelHigherLevelPokemon(ChampionsFormat.level),
    if (ChampionsFormat.speciesClause) context.l10n.toolsSpeciesClauseNoRepeatedSpecies,
    context.l10n.toolsItemClauseEachItemAt(ChampionsFormat.itemClause),
    context.l10n.toolsRestrictedLegendariesAndMythicalsAre,
    context.l10n.toolsMegaEvolutionAvailableForSpecies(ChampionsFormat.megaSpecies.length),
    if (ChampionsFormat.openTeamSheets) context.l10n.toolsOpenTeamSheets,
    context.l10n.toolsAllowedItemsTheSourceHas,
  ];

  Widget _bullet(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  '),
        Expanded(child: Text(text, style: context.text.bodyMedium)),
      ],
    ),
  );

  Widget _yoursTab(BuildContext context, bool es) {
    final data = ref.watch(championsCandidatesProvider(context.dataLang));
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (all) {
        final list = [
          for (final c in all)
            if ((!_onlyEligible || c.result.eligible) && _matches(c.pk.species, c.pk.form)) c,
        ];
        final eligible = all.where((c) => c.result.eligible).length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            Text(
              context.l10n.toolsOfPokemonInYour(eligible, all.length, ChampionsFormat.formatName),
              key: const ValueKey('champions-summary'),
              style: context.text.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.toolsToUseThemTheyMust,
              style: context.text.bodySmall!.copyWith(color: context.tokens.muted),
            ),
            const SizedBox(height: 12),
            _search(context),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.toolsEligibleOnly),
              value: _onlyEligible,
              onChanged: (v) => setState(() => _onlyEligible = v),
            ),
            for (final c in list.take(500)) _CandidateTile(c: c, es: es),
            if (all.isEmpty) Text(context.l10n.toolsThereAreNoPokemon),
          ],
        );
      },
    );
  }
}

class _SpeciesChip extends StatelessWidget {
  const _SpeciesChip({required this.species, required this.form, this.mega = false, this.banned = false});
  final int species;
  final int form;
  final bool mega;
  final bool banned;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(4, 2, 10, 2),
    decoration: BoxDecoration(
      color: context.tokens.raised,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: banned ? context.colors.error.withValues(alpha: 0.5) : context.tokens.hairline),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SpeciesAvatar(species: species, form: form, game: GameVersion.scarletViolet, size: 28),
        const SizedBox(width: 4),
        Text(pokemonName(context, species, form, GameVersion.scarletViolet), style: context.text.labelMedium),
        if (mega) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: context.l10n.toolsHasAMegaEvolution,
            child: Text(
              'M',
              style: context.text.labelSmall!.copyWith(color: context.colors.primary, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    ),
  );
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.c, required this.es});
  final ChampionsCandidate c;
  final bool es;

  @override
  Widget build(BuildContext context) {
    final r = c.result;
    final reasons = [
      for (final x in r.reasons) ChampionsEligibility.reasonText(x, es: es),
      if (r.detail.isNotEmpty) r.detail,
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SpeciesAvatar(
        species: c.pk.species,
        form: c.pk.form,
        game: c.game,
        shiny: c.pk.isShiny,
        egg: c.pk.isEgg,
        size: 44,
      ),
      title: Text('${pokemonName(context, c.pk.species, c.pk.form, c.game)} · ${context.l10n.level(c.pk.level)}'),
      subtitle: Text(
        [
          '${gameTitle(context, c.game)} · ${c.trainer} · ${c.where}',
          if (reasons.isNotEmpty) reasons.join(' '),
        ].join('\n'),
      ),
      isThreeLine: reasons.isNotEmpty,
      trailing: Icon(
        r.eligible ? Icons.check_circle_rounded : Icons.cancel_rounded,
        color: r.eligible ? const Color(0xFF52C98A) : context.colors.error,
      ),
    );
  }
}
