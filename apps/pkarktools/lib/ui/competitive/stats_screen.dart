import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pkcore/pkcore.dart';

import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../editor/pickers.dart';

/// Calculadora de estadísticas de Competitivo.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.compStatsTitle)),
    body: const ClassicStatCalculator(),
  );
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
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
          columnWidths: const {0: FlexColumnWidth(1.6), 1: FixedColumnWidth(48), 2: FixedColumnWidth(76), 3: FixedColumnWidth(76), 4: FixedColumnWidth(56)},
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
