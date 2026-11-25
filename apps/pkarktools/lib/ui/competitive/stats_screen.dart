import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../../data/update/champions_update.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../editor/pickers.dart';
import 'build_editor.dart';
import 'damage_screen.dart';

/// Un set de ejemplo para empezar: el primero permitido (Garchomp si está).
ChampionsBuild defaultChampionsBuild() {
  final allowed = ChampionsDex.allowedSpecies();
  final s = allowed.firstWhere((x) => x.id == 'garchomp', orElse: () => allowed.first);
  return ChampionsBuild(speciesId: s.id, ability: s.abilities.isEmpty ? '' : s.abilities.first);
}

/// Calculadora de estadísticas de Competitivo: la de Champions (por
/// defecto) y la clásica de los juegos principales.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  bool _classic = false;
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
          Center(
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text('Champions', key: const ValueKey('stats-mode-champions'))),
                ButtonSegment(value: true, label: Text(l10n.compClassic, key: const ValueKey('stats-mode-classic'))),
              ],
              selected: {_classic},
              onSelectionChanged: (s) => setState(() => _classic = s.first),
            ),
          ),
          const SizedBox(height: 12),
          if (_classic)
            const ClassicStatCalculator()
          else ...[
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
        ],
      ),
    );
  }
}

/// Modo «Clásica»: fórmula de los juegos principales (Gen 3+) con especie,
/// nivel, naturaleza, IVs y EVs libres.
class ClassicStatCalculator extends StatefulWidget {
  const ClassicStatCalculator({super.key});

  @override
  State<ClassicStatCalculator> createState() => _ClassicStatCalculatorState();
}

class _ClassicStatCalculatorState extends State<ClassicStatCalculator> {
  static const _game = GameVersion.scarletViolet;
  int _species = 445;
  int _nature = 0;
  int _level = 50;
  final _ivs = List<int>.filled(6, 31);
  final _evs = List<int>.filled(6, 0);

  @override
  Widget build(BuildContext context) {
    final lang = context.dataLang;
    final base = GameDataTable.forGame(_game).entry(_species, 0)?.baseStats ?? List.filled(6, 0);
    final stats = StatCalc.all(base: base, ivs: _ivs, evs: _evs, level: _level, nature: _nature, species: _species);
    final evTotal = _evs.fold(0, (a, b) => a + b);
    Widget numField(String key, int value, int max, ValueChanged<int> onChanged) => SizedBox(
      width: 64,
      child: TextFormField(
        key: ValueKey(key),
        initialValue: '$value',
        keyboardType: TextInputType.number,
        textAlign: TextAlign.right,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
        onChanged: (v) => setState(() => onChanged((int.tryParse(v) ?? 0).clamp(0, max))),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.compClassicDesc, style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
        const SizedBox(height: 12),
        SearchPicker(
          key: const ValueKey('classic-species'),
          label: context.l10n.compSpecies,
          options: speciesOptions(context, _game),
          value: _species,
          onSelected: (s) => setState(() => _species = s),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<int>(
                initialValue: _nature,
                isExpanded: true,
                decoration: InputDecoration(labelText: context.l10n.toolsNature, isDense: true),
                items: [
                  for (var n = 0; n < 25; n++) DropdownMenuItem(value: n, child: Text(GameStrings.nature(n, lang))),
                ],
                onChanged: (n) => setState(() => _nature = n ?? 0),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${context.l10n.toolsLevel} '),
                numField('classic-level', _level, 100, (v) => _level = v.clamp(1, 100)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(1.6),
            1: FixedColumnWidth(40),
            2: FixedColumnWidth(72),
            3: FixedColumnWidth(72),
            4: FixedColumnWidth(48),
          },
          children: [
            TableRow(
              children: [
                const SizedBox.shrink(),
                Text('Base', style: context.text.labelMedium, textAlign: TextAlign.right),
                Text('IV', style: context.text.labelMedium, textAlign: TextAlign.center),
                Text('EV', style: context.text.labelMedium, textAlign: TextAlign.center),
                const SizedBox.shrink(),
              ],
            ),
            for (var i = 0; i < 6; i++)
              TableRow(
                children: [
                  Text(Legality.statName(i, lang), overflow: TextOverflow.ellipsis),
                  Text('${base[i]}', textAlign: TextAlign.right),
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: numField('classic-iv-$i', _ivs[i], 31, (v) => _ivs[i] = v),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: numField('classic-ev-$i', _evs[i], 252, (v) => _evs[i] = v),
                  ),
                  Text(
                    '${stats[i]}',
                    key: ValueKey('classic-stat-$i'),
                    textAlign: TextAlign.right,
                    style: context.text.titleMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'EV: $evTotal / 510',
          style: context.text.bodySmall!.copyWith(color: evTotal > 510 ? context.colors.error : context.tokens.muted),
        ),
      ],
    );
  }
}
