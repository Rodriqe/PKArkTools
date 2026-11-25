import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../common/species_avatar.dart';
import '../editor/pickers.dart';
import 'tools_common.dart';

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
          title: Text(tr(context, 'Formato oficial', 'Official format')),
          bottom: TabBar(
            tabs: [
              Tab(text: tr(context, 'Regulación', 'Regulation')),
              Tab(text: tr(context, 'Tus Pokémon', 'Your Pokémon')),
            ],
          ),
        ),
        body: TabBarView(children: [_regulationTab(context, es), _yoursTab(context, es)]),
      ),
    );
  }

  Widget _search(BuildContext context) => TextField(
    key: const ValueKey('champions-search'),
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.search_rounded),
      hintText: tr(context, 'Buscar Pokémon', 'Search Pokémon'),
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    onChanged: (v) => setState(() => _query = v),
  );

  Widget _regulationTab(BuildContext context, bool es) {
    final reg = ChampionsFormat.regulation;
    final allowed = [
      for (final (s, f) in ChampionsFormat.allowed)
        if (_matches(s, f)) (s, f),
    ];
    final banned = [
      for (final s in {...ChampionsFormat.restrictedSpecies, ...ChampionsFormat.mythicalSpecies}.toList()..sort())
        if (_matches(s, 0)) s,
    ];
    String date(DateTime d) => formatDate(context, d);
    final muted = context.text.bodySmall!.copyWith(color: context.tokens.muted);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        Text('Pokémon Champions · ${ChampionsFormat.formatName}', style: context.text.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '${tr(context, 'Regulación', 'Regulation')} ${reg.code}: ${date(reg.from)} – ${date(reg.until)}',
          style: context.text.titleSmall,
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
                    tr(
                      context,
                      'Fechas sin confirmar en una fuente oficial (${reg.datesSource}).',
                      'Dates not confirmed by an official source (${reg.datesSource}).',
                    ),
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
                Text(tr(context, 'Reglas', 'Rules'), style: context.text.titleMedium),
                const SizedBox(height: 8),
                for (final r in _rules(context)) _bullet(context, r),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            context,
            'Datos: Pokémon Showdown (mod «champions»), versión del ${ChampionsFormat.sourceDate}, commit ${ChampionsFormat.sourceCommit.substring(0, 7)}.',
            'Data: Pokémon Showdown (“champions” mod), version of ${ChampionsFormat.sourceDate}, commit ${ChampionsFormat.sourceCommit.substring(0, 7)}.',
          ),
          style: muted,
        ),
        TextButton.icon(
          onPressed: () => launchUrl(Uri.parse(ChampionsFormat.sourceUrl)),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: Text(tr(context, 'Ver la fuente', 'View source')),
        ),
        const SizedBox(height: 12),
        _search(context),
        const SizedBox(height: 14),
        Text(
          tr(context, 'Permitidos (${allowed.length})', 'Allowed (${allowed.length})'),
          style: context.text.titleMedium,
        ),
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
        Text(
          tr(
            context,
            'Prohibidos: legendarios restringidos y singulares (${banned.length})',
            'Banned: restricted legendaries and mythicals (${banned.length})',
          ),
          style: context.text.titleMedium,
        ),
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
    tr(
      context,
      'Combates dobles (VGC): equipo de ${ChampionsFormat.teamSize}, se eligen ${ChampionsFormat.bringDoubles}. Individuales: se eligen ${ChampionsFormat.bringSingles}.',
      'Double battles (VGC): team of ${ChampionsFormat.teamSize}, bring ${ChampionsFormat.bringDoubles}. Singles: bring ${ChampionsFormat.bringSingles}.',
    ),
    tr(
      context,
      'Nivel ${ChampionsFormat.level}: los Pokémon de más nivel se ajustan a ${ChampionsFormat.level}.',
      'Level ${ChampionsFormat.level}: higher-level Pokémon are scaled down to ${ChampionsFormat.level}.',
    ),
    if (ChampionsFormat.speciesClause)
      tr(context, 'Cláusula de especie: no se puede repetir especie.', 'Species clause: no repeated species.'),
    tr(
      context,
      'Cláusula de objeto: cada objeto como mucho ${ChampionsFormat.itemClause} vez.',
      'Item clause: each item at most ${ChampionsFormat.itemClause} time.',
    ),
    tr(
      context,
      'Prohibidos los legendarios restringidos y los singulares.',
      'Restricted legendaries and mythicals are banned.',
    ),
    tr(
      context,
      'Megaevolución disponible para ${ChampionsFormat.megaSpecies.length} especies.',
      'Mega Evolution available for ${ChampionsFormat.megaSpecies.length} species.',
    ),
    if (ChampionsFormat.openTeamSheets)
      tr(context, 'Hojas de equipo abiertas (Open Team Sheets).', 'Open Team Sheets.'),
    tr(
      context,
      'Objetos permitidos: la fuente no da una lista completa; consúltala en el juego.',
      'Allowed items: the source has no complete list; check it in the game.',
    ),
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
              tr(
                context,
                '$eligible de ${all.length} Pokémon de tus partidas son elegibles para ${ChampionsFormat.formatName}.',
                '$eligible of ${all.length} Pokémon in your saves are eligible for ${ChampionsFormat.formatName}.',
              ),
              key: const ValueKey('champions-summary'),
              style: context.text.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                context,
                'Para usarlos hay que llevarlos a Pokémon Champions a través de Pokémon HOME.',
                'To use them they must reach Pokémon Champions through Pokémon HOME.',
              ),
              style: context.text.bodySmall!.copyWith(color: context.tokens.muted),
            ),
            const SizedBox(height: 12),
            _search(context),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr(context, 'Solo elegibles', 'Eligible only')),
              value: _onlyEligible,
              onChanged: (v) => setState(() => _onlyEligible = v),
            ),
            for (final c in list.take(500)) _CandidateTile(c: c, es: es),
            if (all.isEmpty) Text(tr(context, 'No hay Pokémon en el Arca.', 'There are no Pokémon in the Ark.')),
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
            message: tr(context, 'Tiene Megaevolución', 'Has a Mega Evolution'),
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
