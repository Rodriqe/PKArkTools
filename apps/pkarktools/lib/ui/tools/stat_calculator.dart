import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pkcore/pkcore.dart';

import '../../theme/app_theme.dart';
import '../../theme/game_palette.dart';
import '../common/format.dart';
import '../editor/pickers.dart';
import 'tools_common.dart';

/// Calculadora del editor: stats finales a nivel 50 y 100 con los IVs, EVs y
/// naturaleza actuales, Poder Oculto y cálculo inverso de IVs a partir de
/// las estadísticas que se ven en el juego.
class StatCalculatorPanel extends StatefulWidget {
  const StatCalculatorPanel({super.key, required this.pk, required this.onApplyIvs});
  final Pkm pk;
  final ValueChanged<List<int>> onApplyIvs;

  @override
  State<StatCalculatorPanel> createState() => _StatCalculatorPanelState();
}

class _StatCalculatorPanelState extends State<StatCalculatorPanel> {
  late final List<TextEditingController> _observed = [for (var i = 0; i < 6; i++) TextEditingController()];
  List<IvRange>? _ranges;

  @override
  void dispose() {
    for (final c in _observed) {
      c.dispose();
    }
    super.dispose();
  }

  void _fillCurrent() {
    final s = widget.pk.computeStats();
    if (s == null) return;
    setState(() {
      for (var i = 0; i < 6; i++) {
        _observed[i].text = '${s[i]}';
      }
      _ranges = null;
    });
  }

  void _infer() {
    final values = [for (final c in _observed) int.tryParse(c.text.trim()) ?? -1];
    if (values.any((v) => v <= 0)) {
      setState(() => _ranges = null);
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(tr(context, 'Escribe las seis estadísticas.', 'Enter all six stats.'))));
      return;
    }
    setState(() => _ranges = StatCalc.inferFor(widget.pk, values));
  }

  @override
  Widget build(BuildContext context) {
    final pk = widget.pk;
    final f = pk.format;
    if (!StatCalc.supports(f) || pk.dataGame == null) return const SizedBox.shrink();
    final personal = GameDataTable.forGame(pk.dataGame!).entry(pk.species, pk.form);
    if (personal == null) return const SizedBox.shrink();
    final gb = f.isGameBoy;
    final lang = context.dataLang;
    final ivs = pk.ivs, evs = pk.evs;
    List<int> at(int level) => StatCalc.all(
      base: personal.baseStats,
      ivs: ivs,
      evs: evs,
      level: level,
      nature: gb ? -1 : pk.statNature,
      gameBoy: gb,
      species: pk.species,
    );
    final l50 = at(50), l100 = at(100);
    final gen = pk.generation;
    final ranges = _ranges;
    final allExact = ranges != null && ranges.every((r) => r.isExact);
    final num = context.text.bodyMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    String label(int i) => gb && i == 3 ? context.l10n.special : Legality.statName(i, lang);
    final visible = gb ? const [0, 1, 2, 3, 5] : const [0, 1, 2, 3, 4, 5];

    return Container(
      key: const ValueKey('stat-calculator'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tokens.raised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.tokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr(context, 'Calculadora', 'Calculator'), style: context.text.titleMedium),
          const SizedBox(height: 10),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(),
              2: FlexColumnWidth(),
              3: FlexColumnWidth(1.6),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  Text(tr(context, 'Nv. 50', 'Lv. 50'), style: context.text.labelMedium, textAlign: TextAlign.right),
                  Text(tr(context, 'Nv. 100', 'Lv. 100'), style: context.text.labelMedium, textAlign: TextAlign.right),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(tr(context, 'Observada', 'Observed'), style: context.text.labelMedium),
                  ),
                ],
              ),
              for (final i in visible)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(label(i), style: context.text.labelMedium, overflow: TextOverflow.ellipsis),
                    ),
                    Text('${l50[i]}', style: num, textAlign: TextAlign.right, key: ValueKey('calc-l50-$i')),
                    Text('${l100[i]}', style: num, textAlign: TextAlign.right),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
                      child: TextField(
                        key: ValueKey('calc-observed-$i'),
                        controller: _observed[i],
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          helperText: ranges == null ? null : 'IV ${ranges[i]}',
                          helperStyle: TextStyle(color: ranges?[i].isEmpty ?? false ? context.colors.error : null),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (gb) ...[
            const SizedBox(height: 4),
            Text(
              tr(
                context,
                'En Gen 1/2 la Especial vale para ataque y defensa especiales.',
                'In Gen 1/2 Special covers both special attack and defense.',
              ),
              style: context.text.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            tr(
              context,
              'IVs a partir de stats: escribe las estadísticas que ves en el juego (con los EVs, nivel ${pk.level} y naturaleza actuales).',
              'IVs from stats: enter the stats you see in the game (with the current EVs, level ${pk.level} and nature).',
            ),
            style: context.text.bodySmall!.copyWith(color: context.tokens.muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(onPressed: _fillCurrent, child: Text(tr(context, 'Usar las actuales', 'Use current'))),
              FilledButton.tonal(
                key: const ValueKey('calc-infer'),
                onPressed: _infer,
                child: Text(tr(context, 'Calcular IVs', 'Calculate IVs')),
              ),
              if (allExact)
                FilledButton(
                  key: const ValueKey('calc-apply'),
                  onPressed: () =>
                      widget.onApplyIvs([for (var i = 0; i < 6; i++) gb && i == 4 ? ranges[3].min : ranges[i].min]),
                  child: Text(tr(context, 'Aplicar IVs', 'Apply IVs')),
                ),
            ],
          ),
          if (ranges != null && ranges.any((r) => r.isEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                tr(
                  context,
                  'Alguna estadística no encaja con ningún IV: revisa los EVs, el nivel o la naturaleza.',
                  'Some stat fits no IV: check EVs, level or nature.',
                ),
                style: context.text.bodySmall!.copyWith(color: context.colors.error),
              ),
            ),
          if (HiddenPower.appliesTo(gen)) ...[const SizedBox(height: 14), _HiddenPowerRow(ivs: ivs, generation: gen)],
        ],
      ),
    );
  }
}

class _HiddenPowerRow extends StatelessWidget {
  const _HiddenPowerRow({required this.ivs, required this.generation});
  final List<int> ivs;
  final int generation;

  @override
  Widget build(BuildContext context) {
    final t = HiddenPower.type(ivs, generation: generation);
    final power = HiddenPower.power(ivs, generation: generation);
    final type = SpeciesForms.typeFromId(t, 9);
    final name = GameStrings.type(t, context.dataLang);
    return Row(
      key: const ValueKey('hidden-power'),
      children: [
        Text('${GameStrings.move(237, context.dataLang)}: ', style: context.text.labelLarge),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: TypePalette.of(type).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TypePalette.of(type).withValues(alpha: 0.6)),
          ),
          child: Text(name, style: context.text.labelMedium),
        ),
        const SizedBox(width: 8),
        Text(tr(context, 'potencia $power', 'power $power'), style: context.text.labelMedium),
      ],
    );
  }
}
