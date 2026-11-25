import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../common/species_avatar.dart';
import '../editor/pickers.dart';
import '../tools/champions_screen.dart' show championsCandidatesProvider;

/// Opciones de especie: solo las permitidas en la regulación vigente.
List<PickOption> championsSpeciesOptions(BuildContext context) {
  final out = <PickOption>[];
  for (final (i, s) in ChampionsDex.allowedSpecies().indexed) {
    final k = s.key!;
    out.add(PickOption(i, pokemonName(context, k.$1, k.$2, GameVersion.scarletViolet), hint: s.name));
  }
  return out;
}

/// Editor de un [ChampionsBuild]: especie, Mega, naturaleza, puntos de
/// estadística (con las estadísticas finales) y, si [full], habilidad,
/// objeto y movimientos.
class ChampionsBuildEditor extends StatefulWidget {
  const ChampionsBuildEditor({
    super.key,
    required this.build,
    required this.onChanged,
    this.full = true,
    this.keyPrefix = 'build',
  });
  final ChampionsBuild build;
  final VoidCallback onChanged;
  final bool full;
  final String keyPrefix;

  @override
  State<ChampionsBuildEditor> createState() => _ChampionsBuildEditorState();
}

class _ChampionsBuildEditorState extends State<ChampionsBuildEditor> {
  late List<ChampionsSpecies> _allowed = ChampionsDex.allowedSpecies();

  ChampionsBuild get b => widget.build;

  void _set(VoidCallback f) {
    setState(f);
    widget.onChanged();
  }

  void _setSpecies(ChampionsSpecies s) => _set(() {
    b.speciesId = s.id;
    b.megaId = '';
    if (!s.abilities.contains(b.ability)) b.ability = s.abilities.isEmpty ? '' : s.abilities.first;
    b.moves = [
      for (final m in b.moves)
        if (ChampionsDex.canLearn(s, m)) m,
    ];
  });

  @override
  void didUpdateWidget(covariant ChampionsBuildEditor old) {
    super.didUpdateWidget(old);
    _allowed = ChampionsDex.allowedSpecies();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.dataLang;
    final es = context.isSpanish;
    final s = b.species;
    final p = widget.keyPrefix;
    final options = championsSpeciesOptions(context);
    final index = s == null ? -1 : _allowed.indexWhere((x) => x.id == s.id);
    final megas = s == null ? const <ChampionsSpecies>[] : ChampionsDex.allowedMegas(s);
    final stats = b.stats;
    final total = b.sp.fold(0, (a, v) => a + v);
    final problems = b.problems(es: es);
    final base = b.battleSpecies?.baseStats ?? List.filled(6, 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (s?.key case (final sp, final f))
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SpeciesAvatar(species: sp, form: f, game: GameVersion.scarletViolet, size: 44),
              ),
            Expanded(
              child: SearchPicker(
                key: ValueKey('$p-species'),
                label: context.l10n.compSpecies,
                options: options,
                value: index,
                labelFor: (_) => s?.name ?? '',
                onSelected: (i) => _setSpecies(_allowed[i]),
              ),
            ),
          ],
        ),
        if (megas.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                key: ValueKey('$p-mega-none'),
                label: Text(context.l10n.compNoMega),
                selected: b.megaId.isEmpty,
                onSelected: (_) => _set(() => b.megaId = ''),
              ),
              for (final m in megas)
                ChoiceChip(
                  key: ValueKey('$p-mega-${m.id}'),
                  label: Text(m.name),
                  selected: b.megaId == m.id,
                  onSelected: (_) => _set(() {
                    b.megaId = m.id;
                    b.item = m.megaStone;
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<int>(
                key: ValueKey('$p-nature-${b.nature}'),
                initialValue: b.nature,
                isExpanded: true,
                decoration: InputDecoration(labelText: context.l10n.toolsNature, isDense: true),
                items: [for (var n = 0; n < 25; n++) DropdownMenuItem(value: n, child: Text(_natureLabel(n, lang)))],
                onChanged: (n) => _set(() => b.nature = n ?? 0),
              ),
            ),
            if (widget.full && s != null) ...[
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('$p-ability-${s.id}-${b.ability}'),
                  initialValue: s.abilities.contains(b.ability) ? b.ability : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: context.l10n.toolsAbility, isDense: true),
                  items: [
                    for (final a in s.abilities)
                      DropdownMenuItem(value: a, child: Text(ChampionsDex.abilityName(a, lang))),
                  ],
                  onChanged: (a) => _set(() => b.ability = a ?? ''),
                ),
              ),
              SizedBox(
                width: 240,
                child: SearchPicker(
                  key: ValueKey('$p-item'),
                  label: context.l10n.toolsItem,
                  allowNone: true,
                  options: [
                    for (final (i, it) in ChampionsDex.allItems.indexed)
                      PickOption(i + 1, ChampionsDex.itemName(it.id, lang)),
                  ],
                  value: ChampionsDex.allItems.indexWhere((x) => x.id == b.item) + 1,
                  onSelected: (i) => _set(() => b.item = i == 0 ? '' : ChampionsDex.allItems[i - 1].id),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _SpTable(
          prefix: p,
          base: base,
          sp: b.sp,
          stats: stats,
          nature: b.nature,
          lang: lang,
          onChanged: (i, v) => _set(() => b.sp[i] = v),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.compSpTotal(ChampionsStats.maxTotal, total),
          key: ValueKey('$p-sp-total'),
          style: context.text.bodySmall!.copyWith(
            color: total > ChampionsStats.maxTotal ? context.colors.error : context.tokens.muted,
          ),
        ),
        if (widget.full && s != null) ...[
          const SizedBox(height: 12),
          _MovesPicker(prefix: p, set: b, species: s, onChanged: () => _set(() {})),
        ],
        for (final pr in problems)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: context.colors.error),
                const SizedBox(width: 6),
                Expanded(child: Text(pr, style: context.text.bodySmall)),
              ],
            ),
          ),
      ],
    );
  }

  static String _natureLabel(int n, DataLanguage lang) {
    final e = GameStrings.natureEffect(n);
    final name = GameStrings.nature(n, lang);
    if (e == null) return name;
    return '$name (+${Legality.statName(e.$1, lang)} −${Legality.statName(e.$2, lang)})';
  }
}

class _SpTable extends StatelessWidget {
  const _SpTable({
    required this.prefix,
    required this.base,
    required this.sp,
    required this.stats,
    required this.nature,
    required this.lang,
    required this.onChanged,
  });
  final String prefix;
  final List<int> base;
  final List<int> sp;
  final List<int> stats;
  final int nature;
  final DataLanguage lang;
  final void Function(int, int) onChanged;

  @override
  Widget build(BuildContext context) {
    final num = context.text.titleMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FlexColumnWidth(1.4),
        1: FixedColumnWidth(40),
        2: FlexColumnWidth(3),
        3: FixedColumnWidth(52),
      },
      children: [
        TableRow(
          children: [
            const SizedBox.shrink(),
            Text('Base', style: context.text.labelSmall, textAlign: TextAlign.right),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(context.l10n.compStatPoints, style: context.text.labelSmall),
            ),
            const SizedBox.shrink(),
          ],
        ),
        for (var i = 0; i < 6; i++)
          TableRow(
            children: [
              Text(
                Legality.statName(i, lang),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: switch (StatCalc.natureTenths(nature, i)) {
                    11 => context.colors.primary,
                    9 => context.colors.error,
                    _ => null,
                  },
                ),
              ),
              Text(
                '${base[i]}',
                textAlign: TextAlign.right,
                style: TextStyle(color: context.tokens.muted),
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      key: ValueKey('$prefix-sp-slider-$i'),
                      value: sp[i].clamp(0, ChampionsStats.maxPerStat).toDouble(),
                      max: ChampionsStats.maxPerStat.toDouble(),
                      divisions: ChampionsStats.maxPerStat,
                      onChanged: (v) => onChanged(i, v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: _SpField(key: ValueKey('$prefix-sp-$i'), value: sp[i], onChanged: (v) => onChanged(i, v)),
                  ),
                ],
              ),
              Text('${stats[i]}', key: ValueKey('$prefix-stat-$i'), textAlign: TextAlign.right, style: num),
            ],
          ),
      ],
    );
  }
}

class _SpField extends StatefulWidget {
  const _SpField({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_SpField> createState() => _SpFieldState();
}

class _SpFieldState extends State<_SpField> {
  late final _c = TextEditingController(text: '${widget.value}');

  @override
  void didUpdateWidget(covariant _SpField old) {
    super.didUpdateWidget(old);
    if (int.tryParse(_c.text) != widget.value) _c.text = '${widget.value}';
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _c,
    keyboardType: TextInputType.number,
    textAlign: TextAlign.right,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.all(6)),
    onChanged: (v) => widget.onChanged((int.tryParse(v) ?? 0).clamp(0, ChampionsStats.maxPerStat)),
  );
}

class _MovesPicker extends StatelessWidget {
  const _MovesPicker({required this.prefix, required this.set, required this.species, required this.onChanged});
  final String prefix;
  final ChampionsBuild set;
  final ChampionsSpecies species;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = context.dataLang;
    final learn = ChampionsDex.learnset(species);
    final options = [for (final m in learn) PickOption(m.index + 1, ChampionsDex.moveName(m, lang), hint: m.type)];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < 4; i++)
          SizedBox(
            width: 220,
            child: SearchPicker(
              key: ValueKey('$prefix-move-$i'),
              label: '${context.l10n.compMove} ${i + 1}',
              allowNone: true,
              dense: true,
              options: options,
              value: i < set.moves.length ? (ChampionsDex.move(set.moves[i])?.index ?? -1) + 1 : 0,
              onSelected: (v) {
                final id = v == 0 ? '' : ChampionsDex.allMoves[v - 1].id;
                final list = [...set.moves];
                if (i < list.length) {
                  if (id.isEmpty) {
                    list.removeAt(i);
                  } else {
                    list[i] = id;
                  }
                } else if (id.isNotEmpty) {
                  list.add(id);
                }
                set.moves = list;
                onChanged();
              },
            ),
          ),
      ],
    );
  }
}

/// Elige un Pokémon de las partidas del Arca y lo convierte a Champions.
Future<ChampionsBuild?> pickFromArk(BuildContext context) => showModalBottomSheet<ChampionsBuild>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _ArkPicker(),
);

class _ArkPicker extends ConsumerWidget {
  const _ArkPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(championsCandidatesProvider(context.dataLang));
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final usable = [
            for (final c in all)
              if (!c.pk.isEgg && ChampionsDex.byKey(c.pk.species, c.pk.form) != null) c,
          ]..sort((a, b) => (b.result.eligible ? 1 : 0) - (a.result.eligible ? 1 : 0));
          if (usable.isEmpty) return Center(child: Text(context.l10n.toolsThereAreNoPokemon));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  context.l10n.compFromArkNote,
                  style: context.text.bodySmall!.copyWith(color: context.tokens.muted),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: usable.length,
                  itemBuilder: (context, i) {
                    final c = usable[i];
                    return ListTile(
                      key: ValueKey('ark-pick-$i'),
                      leading: SpeciesAvatar(
                        species: c.pk.species,
                        form: c.pk.form,
                        game: c.game,
                        shiny: c.pk.isShiny,
                        size: 40,
                      ),
                      title: Text(
                        '${pokemonName(context, c.pk.species, c.pk.form, c.game)} · ${context.l10n.level(c.pk.level)}',
                      ),
                      subtitle: Text('${gameTitle(context, c.game)} · ${c.trainer} · ${c.where}'),
                      trailing: Icon(
                        c.result.eligible ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: c.result.eligible ? const Color(0xFF52C98A) : context.colors.error,
                      ),
                      onTap: () => Navigator.pop(context, ChampionsBuild.fromPkm(c.pk)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Pide un texto de Showdown y devuelve los sets que se pudieron leer.
Future<List<ChampionsBuild>?> pasteFromShowdown(BuildContext context) async {
  final text = await showDialog<String>(context: context, builder: (_) => const _PasteDialog());
  if (text == null) return null;
  return [
    for (final s in Showdown.parse(text))
      if (ChampionsBuild.fromShowdown(s) case (:final build, convertedEvs: _)) build,
  ];
}

class _PasteDialog extends StatefulWidget {
  const _PasteDialog();

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.compPasteShowdown),
    content: SizedBox(
      width: 480,
      child: TextField(
        key: const ValueKey('paste-showdown-text'),
        controller: _ctl,
        minLines: 6,
        maxLines: 12,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'Garchomp @ Life Orb\nEVs: 32 Atk / 32 Spe\n…',
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      FilledButton(
        key: const ValueKey('paste-showdown-ok'),
        onPressed: () => Navigator.pop(context, _ctl.text),
        child: Text(MaterialLocalizations.of(context).okButtonLabel),
      ),
    ],
  );
}
