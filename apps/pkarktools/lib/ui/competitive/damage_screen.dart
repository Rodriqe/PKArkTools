import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pkcore/pkcore.dart';

import '../../data/update/champions_update.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../editor/pickers.dart';
import '../tools/tools_common.dart';
import 'build_editor.dart';
import 'stats_screen.dart' show defaultChampionsBuild;

/// Atacante que se manda a la calculadora de daño desde otra pantalla
/// («Usar en la calculadora de daño»).
class DamageSeed extends Notifier<ChampionsBuild?> {
  @override
  ChampionsBuild? build() => null;

  void set(ChampionsBuild? b) => state = b;
}

final damageSeedProvider = NotifierProvider<DamageSeed, ChampionsBuild?>(DamageSeed.new);

/// Lleva [b] como atacante a la calculadora de daño de Competitivo.
void openDamageCalc(BuildContext context, WidgetRef ref, ChampionsBuild b) {
  ref.read(damageSeedProvider.notifier).set(b.copy());
  context.go('/competitivo/danio');
}

/// Abre la calculadora encima de la pantalla actual (desde el editor, sin
/// cerrarlo).
Future<void> pushDamageCalc(BuildContext context, ChampionsBuild attacker) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => DamageScreen(attacker: attacker)));

/// Calculadora de daño de Pokémon Champions.
class DamageScreen extends ConsumerStatefulWidget {
  const DamageScreen({super.key, this.attacker});

  /// Atacante inicial (si no, el de [damageSeedProvider] o uno de ejemplo).
  final ChampionsBuild? attacker;

  @override
  ConsumerState<DamageScreen> createState() => _DamageScreenState();
}

class _Mon {
  _Mon(this.build);
  ChampionsBuild build;
  final boosts = <String, int>{};
  String status = '';
  int hpPercent = 100;
  int version = 0;

  ChampionsSide get side => ChampionsSide(build, boosts: {...boosts}, status: status, hpPercent: hpPercent);
}

class _DamageScreenState extends ConsumerState<DamageScreen> {
  late final _Mon _a;
  late final _Mon _d;
  String _move = '';
  bool _doubles = true;
  ChampionsWeather _weather = ChampionsWeather.none;
  ChampionsTerrain _terrain = ChampionsTerrain.none;
  bool _reflect = false, _lightScreen = false, _veil = false, _hh = false, _crit = false, _spread = true;

  @override
  void initState() {
    super.initState();
    final seed = widget.attacker ?? ref.read(damageSeedProvider);
    if (widget.attacker == null && seed != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(damageSeedProvider.notifier).set(null));
    }
    _a = _Mon(seed?.copy() ?? defaultChampionsBuild());
    final allowed = ChampionsDex.allowedSpecies();
    final def = allowed.firstWhere((s) => s.id == 'incineroar', orElse: () => allowed.last);
    _d = _Mon(ChampionsBuild(speciesId: def.id, ability: def.abilities.isEmpty ? '' : def.abilities.first));
    _pickDefaultMove();
  }

  void _pickDefaultMove() {
    final s = _a.build.species;
    if (s == null) return;
    final usable = [
      for (final id in _a.build.moves)
        if (ChampionsDex.move(id) case final m? when !m.isStatus) m.id,
    ];
    if (usable.isNotEmpty) {
      _move = usable.first;
      return;
    }
    final learn = ChampionsDex.learnset(s).where(ChampionsDamage.moveSupported).toList()
      // La más fuerte con STAB primero (sin las que obligan a recargar).
      ..sort((x, y) => _score(s, y).compareTo(_score(s, x)));
    _move = learn.isEmpty ? '' : learn.first.id;
  }

  static double _score(ChampionsSpecies s, ChampionsMove m) {
    if (m.extra['recharge'] != null || m.id == 'hyperbeam' || m.id == 'gigaimpact') return m.basePower * 0.5;
    return m.basePower * (s.types.contains(m.type) ? 1.5 : 1.0);
  }

  void _swap() => setState(() {
    final b = _a.build;
    _a.build = _d.build;
    _d.build = b;
    _a.version++;
    _d.version++;
    _pickDefaultMove();
  });

  Future<void> _load(_Mon m, {required bool ark}) async {
    final b = ark ? await pickFromArk(context) : (await pasteFromShowdown(context))?.firstOrNull;
    if (b == null || !mounted) return;
    setState(() {
      m.build = b;
      m.version++;
      if (identical(m, _a)) _pickDefaultMove();
    });
  }

  ChampionsField get _field => ChampionsField(
    doubles: _doubles,
    weather: _weather,
    terrain: _terrain,
    reflect: _reflect,
    lightScreen: _lightScreen,
    auroraVeil: _veil,
    helpingHand: _doubles && _hh,
    crit: _crit,
    spread: _spread,
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(championsDataProvider);
    final l10n = context.l10n;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final attacker = _monCard(context, _a, l10n.compAttacker, 'atk');
    final defender = _monCard(context, _d, l10n.compDefender, 'def');
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.compDamageTitle),
        actions: [
          IconButton(
            key: const ValueKey('damage-swap'),
            tooltip: l10n.compSwap,
            onPressed: _swap,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          _result(context),
          const SizedBox(height: 12),
          _moveAndField(context),
          const SizedBox(height: 12),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: attacker),
                const SizedBox(width: 12),
                Expanded(child: defender),
              ],
            )
          else ...[
            attacker,
            const SizedBox(height: 12),
            defender,
          ],
        ],
      ),
    );
  }

  Widget _monCard(BuildContext context, _Mon m, String title, String prefix) {
    final l10n = context.l10n;
    final isAtk = prefix == 'atk';
    final stats = isAtk ? const ['atk', 'spa', 'spe'] : const ['def', 'spd', 'spe'];
    final lang = context.dataLang;
    const statIndex = {'atk': 1, 'def': 2, 'spa': 3, 'spd': 4, 'spe': 5};
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: context.text.titleMedium)),
                IconButton(
                  key: ValueKey('$prefix-from-ark'),
                  tooltip: l10n.compLoadFromArk,
                  onPressed: () => _load(m, ark: true),
                  icon: const Icon(Icons.inventory_2_outlined),
                ),
                IconButton(
                  key: ValueKey('$prefix-from-showdown'),
                  tooltip: l10n.compPasteShowdown,
                  onPressed: () => _load(m, ark: false),
                  icon: const Icon(Icons.content_paste_rounded),
                ),
              ],
            ),
            ChampionsBuildEditor(
              key: ValueKey('$prefix-editor-${m.version}'),
              build: m.build,
              keyPrefix: prefix,
              full: true,
              onChanged: () => setState(() {
                if (isAtk && !ChampionsDex.canLearn(m.build.species!, _move) && !m.build.moves.contains(_move)) {
                  _pickDefaultMove();
                }
              }),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final s in stats)
                  _Stepper(
                    key: ValueKey('$prefix-boost-$s'),
                    label: Legality.statName(statIndex[s]!, lang),
                    value: m.boosts[s] ?? 0,
                    onChanged: (v) => setState(() => m.boosts[s] = v),
                  ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('$prefix-status-${m.status}'),
                    initialValue: m.status,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.compStatus, isDense: true),
                    items: [
                      DropdownMenuItem(value: '', child: Text(l10n.compStatusNone)),
                      DropdownMenuItem(value: 'brn', child: Text(l10n.compStatusBurn)),
                      DropdownMenuItem(value: 'par', child: Text(l10n.compStatusPar)),
                      DropdownMenuItem(value: 'psn', child: Text(l10n.compStatusPoison)),
                      DropdownMenuItem(value: 'slp', child: Text(l10n.compStatusSleep)),
                    ],
                    onChanged: (v) => setState(() => m.status = v ?? ''),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: Row(
                    children: [
                      Text('${l10n.compHp} ${m.hpPercent}%'),
                      Expanded(
                        child: Slider(
                          key: ValueKey('$prefix-hp'),
                          value: m.hpPercent.toDouble(),
                          min: 1,
                          max: 100,
                          onChanged: (v) => setState(() => m.hpPercent = v.round()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _moveAndField(BuildContext context) {
    final l10n = context.l10n;
    final lang = context.dataLang;
    final s = _a.build.species;
    final learn = s == null ? const <ChampionsMove>[] : ChampionsDex.learnset(s).where((m) => !m.isStatus).toList();
    final own = {..._a.build.moves};
    final options = [
      for (final m in learn)
        PickOption(
          m.index + 1,
          ChampionsDex.moveName(m, lang),
          hint: '${m.type} · ${m.basePower}',
          highlight: own.contains(m.id),
        ),
    ];
    final mv = ChampionsDex.move(_move);
    Widget chip(String key, String label, bool v, ValueChanged<bool> f) =>
        FilterChip(key: ValueKey(key), label: Text(label), selected: v, onSelected: (x) => setState(() => f(x)));
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SearchPicker(
              key: ValueKey('damage-move-${_a.version}-$_move'),
              label: l10n.compMove,
              options: options,
              value: mv == null ? 0 : mv.index + 1,
              onSelected: (i) => setState(() => _move = ChampionsDex.allMoves[i - 1].id),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(l10n.compDoubles)),
                    ButtonSegment(value: false, label: Text(l10n.compSingles)),
                  ],
                  selected: {_doubles},
                  onSelectionChanged: (v) => setState(() => _doubles = v.first),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<ChampionsWeather>(
                    initialValue: _weather,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.compWeather, isDense: true),
                    items: [
                      for (final w in ChampionsWeather.values)
                        DropdownMenuItem(value: w, child: Text(_weatherName(context, w))),
                    ],
                    onChanged: (v) => setState(() => _weather = v ?? ChampionsWeather.none),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<ChampionsTerrain>(
                    initialValue: _terrain,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.compTerrain, isDense: true),
                    items: [
                      for (final t in ChampionsTerrain.values)
                        DropdownMenuItem(value: t, child: Text(_terrainName(context, t))),
                    ],
                    onChanged: (v) => setState(() => _terrain = v ?? ChampionsTerrain.none),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                chip('damage-crit', l10n.compCrit, _crit, (v) => _crit = v),
                if (_doubles && (mv?.isSpread ?? false))
                  chip('damage-spread', l10n.compSpread, _spread, (v) => _spread = v),
                if (_doubles) chip('damage-hh', l10n.compHelpingHand, _hh, (v) => _hh = v),
                chip('damage-reflect', l10n.compReflect, _reflect, (v) => _reflect = v),
                chip('damage-lightscreen', l10n.compLightScreen, _lightScreen, (v) => _lightScreen = v),
                chip('damage-veil', l10n.compAuroraVeil, _veil, (v) => _veil = v),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _result(BuildContext context) {
    final l10n = context.l10n;
    final mv = ChampionsDex.move(_move);
    if (mv == null || _a.build.battleSpecies == null || _d.build.battleSpecies == null) {
      return Text(l10n.compPickMove);
    }
    final a = _a.side, d = _d.side, field = _field;
    final r = ChampionsDamage.calculate(attacker: a, defender: d, move: mv, field: field);
    final text = championsDamageText(a, d, mv, field, r, es: false);
    final ko = r.ko;
    final koLabel = r.immune
        ? l10n.compNoEffect
        : ko == null
        ? l10n.compNoKo
        : ko.chance >= 1 - 1e-9
        ? l10n.compKoGuaranteed(ko.n == 1 ? 'OHKO' : '${ko.n}HKO')
        : l10n.compKoChance((ko.chance * 100).toStringAsFixed(1), ko.n == 1 ? 'OHKO' : '${ko.n}HKO');
    String pct(double v) => v.toStringAsFixed(1);
    final notes = [...r.unsupported];
    return Container(
      key: const ValueKey('damage-result'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.immune ? l10n.compNoEffect : '${pct(r.percent(r.min))} – ${pct(r.percent(r.max))}%',
            key: const ValueKey('damage-percent'),
            style: context.text.headlineSmall,
          ),
          const SizedBox(height: 2),
          if (!r.immune)
            Text(
              l10n.compDamageRange(r.defenderMaxHp, r.max, r.min),
              key: const ValueKey('damage-range'),
              style: context.text.bodyMedium,
            ),
          Text(koLabel, key: const ValueKey('damage-ko'), style: context.text.titleMedium),
          if (r.hits > 1 || r.hitChances.isNotEmpty)
            Text(
              r.hitChances.isNotEmpty ? l10n.compHitsVariable : l10n.compHits(r.hits),
              style: context.text.bodySmall,
            ),
          if (!r.immune && r.hitChances.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${l10n.compRolls}: ${r.rolls.join(', ')}',
                style: context.text.bodySmall!.copyWith(color: context.tokens.muted),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  text,
                  key: const ValueKey('damage-text'),
                  style: context.text.bodyMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
              IconButton(
                tooltip: l10n.toolsCopy,
                onPressed: () => copyText(context, text),
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
          if (notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.compNotConsidered(notes.join(', ')),
                key: const ValueKey('damage-not-considered'),
                style: context.text.bodySmall!.copyWith(color: context.colors.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l10n.compDamageLimits, style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
          ),
        ],
      ),
    );
  }

  static String _weatherName(BuildContext context, ChampionsWeather w) => switch (w) {
    ChampionsWeather.none => context.l10n.compNone,
    ChampionsWeather.sun => context.l10n.compSun,
    ChampionsWeather.rain => context.l10n.compRain,
    ChampionsWeather.sand => context.l10n.compSand,
    ChampionsWeather.snow => context.l10n.compSnow,
  };

  static String _terrainName(BuildContext context, ChampionsTerrain t) => switch (t) {
    ChampionsTerrain.none => context.l10n.compNone,
    ChampionsTerrain.electric => context.l10n.compElectricTerrain,
    ChampionsTerrain.grassy => context.l10n.compGrassyTerrain,
    ChampionsTerrain.psychic => context.l10n.compPsychicTerrain,
    ChampionsTerrain.misty => context.l10n.compMistyTerrain,
  };
}

class _Stepper extends StatelessWidget {
  const _Stepper({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: context.text.labelMedium),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: value <= -6 ? null : () => onChanged(value - 1),
        icon: const Icon(Icons.remove_rounded, size: 18),
      ),
      SizedBox(
        width: 26,
        child: Text(value > 0 ? '+$value' : '$value', textAlign: TextAlign.center, style: context.text.labelLarge),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: value >= 6 ? null : () => onChanged(value + 1),
        icon: const Icon(Icons.add_rounded, size: 18),
      ),
    ],
  );
}
