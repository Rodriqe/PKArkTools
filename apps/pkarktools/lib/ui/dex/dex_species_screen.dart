import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pkcore/pkcore.dart';

import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/game_palette.dart';
import '../common/format.dart';
import '../ribbons/ribbon_master_screen.dart';
import 'dex_screen.dart';
import 'dex_special_forms.dart';
import 'dex_text.dart';
import 'dex_tile.dart';

/// Ficha de una especie en la Dex global. Solo datos objetivos (tipos, stats,
/// habilidades, género, evoluciones, formas, juegos) y los registros y
/// ejemplares del usuario; nunca descripciones de la Pokédex.
class DexSpeciesScreen extends ConsumerStatefulWidget {
  const DexSpeciesScreen({super.key, required this.species});
  final int species;

  @override
  ConsumerState<DexSpeciesScreen> createState() => _DexSpeciesScreenState();
}

class _DexSpeciesScreenState extends ConsumerState<DexSpeciesScreen> {
  int? _form;

  @override
  void didUpdateWidget(covariant DexSpeciesScreen old) {
    super.didUpdateWidget(old);
    if (old.species != widget.species) _form = null;
  }

  @override
  Widget build(BuildContext context) {
    final dex = ref.watch(globalDexProvider).value;
    final living = ref.watch(dexLivingProvider);
    final l10n = context.l10n;
    final s = widget.species;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final wide = width >= 1100;
    final pad = compact ? 16.0 : 32.0;

    if (dex == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final e = dex[s];
    final forms = e.collectableForms;
    final form = _form != null && forms.contains(_form) ? _form! : _defaultForm(e);
    final status = living ? e.livingStatus : e.status;

    void go(int to) => context.go('/dex/especie/$to');

    final header = _Header(entry: e, form: form, status: status, living: living);
    final main = <Widget>[
      _Section(title: l10n.dexBaseStats, child: _BaseStats(species: s, form: form)),
      _Section(title: l10n.dexAbilities, child: _Abilities(species: s, form: form)),
      _Section(title: l10n.dexGender, child: _Gender(species: s, form: form)),
      _Section(title: l10n.dexEvolution, child: _Evolution(dex: dex, species: s, form: form, living: living)),
      if (forms.length > 1)
        _Section(
          title: l10n.dexForms,
          trailing: l10n.dexFormsCount(forms.length),
          child: _Forms(entry: e, selected: form, onSelect: (f) => setState(() => _form = f)),
        ),
      _Section(title: l10n.dexGames, child: _Games(dex: dex, species: s)),
    ];
    final side = <Widget>[
      if (e.specials.isNotEmpty)
        _Section(
          title: l10n.dexSpecialForms,
          subtitle: l10n.dexSpecialFormsHint,
          child: Column(children: [
            for (final u in e.specials) ...[
              SpecialFormCard(dex: dex, unlock: u),
              const SizedBox(height: 10),
            ],
          ]),
        ),
      _Section(title: l10n.dexRecords, child: _Records(dex: dex, entry: e)),
      _Section(title: l10n.dexSpecimens, child: _Specimens(dex: dex, entry: e)),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dex'),
        ),
        title: Text(dexNumber(s), style: context.text.titleMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        actions: [
          IconButton(
            key: const ValueKey('dex-prev'),
            tooltip: l10n.dexPrev,
            onPressed: s > 1 ? () => go(s - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            key: const ValueKey('dex-next'),
            tooltip: l10n.dexNext,
            onPressed: s < GlobalDex.maxSpecies ? () => go(s + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          SizedBox(width: compact ? 4 : 16),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: ListView(
              key: PageStorageKey('dex-species-$s'),
              padding: EdgeInsets.fromLTRB(pad, 4, pad, 96),
              children: [
                header,
                if (RibbonMaster.has(s, form))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('dex-ribbon-guide'),
                        onPressed: () => context.go(ribbonGuidePath(s, form)),
                        icon: const Icon(Icons.military_tech_rounded),
                        label: Text(l10n.rmOpenGuide),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                if (wide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 5, child: Column(children: main)),
                    const SizedBox(width: 28),
                    Expanded(flex: 4, child: Column(children: side)),
                  ])
                else ...[
                  ...main.take(2),
                  ...side,
                  ...main.skip(2),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Forma inicial: la primera de la que hay ejemplar, o la 0.
  static int _defaultForm(SpeciesDex e) {
    for (final f in e.collectableForms) {
      if (e.formsOwned.contains(f)) return f;
    }
    return e.collectableForms.first;
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: context.text.titleLarge)),
          if (trailing != null) Text(trailing!, style: context.text.labelLarge!.copyWith(color: tokens.muted)),
        ]),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: context.text.bodySmall!.copyWith(color: tokens.muted)),
        ],
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.entry, required this.form, required this.status, required this.living});
  final SpeciesDex entry;
  final int form;
  final DexStatus status;
  final bool living;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final s = entry.species;
    final (t1, t2) = SpeciesForms.types(s, form);
    final accent = TypePalette.of(t1);
    final compact = MediaQuery.sizeOf(context).width < 520;
    final iconSize = compact ? 96.0 : 128.0;
    final gen = Species.introducedIn(s);
    final (statusLabel, statusIcon, statusColor) = switch (status) {
      DexStatus.caught when living => (l10n.dexStatusOwned, Icons.catching_pokemon_rounded, context.colors.primary),
      DexStatus.caught => (l10n.dexStatusCaught, Icons.catching_pokemon_rounded, context.colors.primary),
      DexStatus.seen => (l10n.dexStatusSeen, Icons.visibility_rounded, context.colors.secondary),
      DexStatus.unknown => (l10n.dexStatusUnknown, Icons.help_outline_rounded, tokens.muted),
    };
    final formName = form == 0 ? '' : SpeciesForms.formName(s, form, DexForms.displayGame(s, form), context.dexLang);
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.alphaBlend(accent.withValues(alpha: 0.22), tokens.raised), tokens.raised],
        ),
        border: Border.all(color: tokens.hairline),
      ),
      child: Row(children: [
        Container(
          width: iconSize + 16,
          height: iconSize + 16,
          decoration: BoxDecoration(color: tokens.base.withValues(alpha: 0.5), shape: BoxShape.circle),
          child: Center(
            child: DexIcon(species: s, form: form, status: status, size: iconSize, label: speciesName(context, s)),
          ),
        ),
        SizedBox(width: compact ? 14 : 24),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dexNumber(s),
                style: context.text.labelLarge!.copyWith(color: tokens.muted, fontFeatures: const [FontFeature.tabularFigures()])),
            Text(
              speciesName(context, s),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (compact ? context.text.headlineMedium : context.text.displaySmall)!.copyWith(fontWeight: FontWeight.w800),
            ),
            if (formName.isNotEmpty)
              Text(formName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall!.copyWith(color: tokens.muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              TypeChip(t1),
              if (t2 != t1 && t2 != PokemonType.none) TypeChip(t2),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _Pill(icon: statusIcon, label: statusLabel, color: statusColor),
              if (entry.shinyOwned) _Pill(icon: Icons.auto_awesome, label: l10n.dexShinyVariant, color: tokens.shiny),
              Text(genRegionLabel(context, gen), style: context.text.labelMedium!.copyWith(color: tokens.muted)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium)),
        ]),
      );
}

class _BaseStats extends StatelessWidget {
  const _BaseStats({required this.species, required this.form});
  final int species;
  final int form;

  @override
  Widget build(BuildContext context) {
    final p = SpeciesForms.personal(species, form, DexForms.displayGame(species, form));
    final tokens = context.tokens;
    if (p == null) return Text('—', style: TextStyle(color: tokens.muted));
    final labels = context.isSpanish ? const ['PS', 'Ataque', 'Defensa', 'At. Esp.', 'Def. Esp.', 'Velocidad'] : const ['HP', 'Attack', 'Defense', 'Sp. Atk', 'Sp. Def', 'Speed'];
    Color colorOf(int v) => switch (v) {
          < 50 => const Color(0xFFE5736A),
          < 80 => const Color(0xFFF0B54A),
          < 110 => const Color(0xFF8CCB5E),
          < 140 => const Color(0xFF4FC3A1),
          _ => const Color(0xFF4FA3E8),
        };
    return Column(children: [
      for (final (i, v) in p.baseStats.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(children: [
            SizedBox(width: 82, child: Text(labels[i], style: context.text.labelLarge!.copyWith(color: tokens.muted))),
            SizedBox(
              width: 36,
              child: Text('$v',
                  textAlign: TextAlign.right,
                  style: context.text.labelLarge!.copyWith(fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: (v / 200).clamp(0.0, 1.0), minHeight: 8, color: colorOf(v), backgroundColor: tokens.sunken),
              ),
            ),
          ]),
        ),
      Row(children: [
        SizedBox(width: 82, child: Text(context.l10n.dexStatTotal, style: context.text.labelLarge)),
        SizedBox(
          width: 36,
          child: Text('${p.baseStatTotal}',
              textAlign: TextAlign.right,
              style: context.text.labelLarge!.copyWith(fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
        ),
      ]),
    ]);
  }
}

class _Abilities extends StatelessWidget {
  const _Abilities({required this.species, required this.form});
  final int species;
  final int form;

  @override
  Widget build(BuildContext context) {
    final p = SpeciesForms.personal(species, form, DexForms.displayGame(species, form));
    final tokens = context.tokens;
    final ab = p?.abilities ?? const <int>[];
    final regular = <int>{for (final (i, a) in ab.indexed) if (i < 2 && a > 0) a};
    final hidden = ab.length > 2 && ab[2] > 0 ? ab[2] : null;
    if (regular.isEmpty && hidden == null) return Text('—', style: TextStyle(color: tokens.muted));
    Widget chip(int a, {bool isHidden = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: tokens.raised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isHidden ? context.colors.secondary.withValues(alpha: 0.6) : tokens.hairline),
          ),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: GameStrings.ability(a, context.dexLang), style: context.text.labelLarge),
            if (isHidden)
              TextSpan(
                  text: '  ${context.l10n.dexHiddenAbility}',
                  style: context.text.labelMedium!.copyWith(color: context.colors.secondary)),
          ])),
        );
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final a in regular) chip(a),
      if (hidden != null) chip(hidden, isHidden: true),
    ]);
  }
}

class _Gender extends StatelessWidget {
  const _Gender({required this.species, required this.form});
  final int species;
  final int form;

  /// Porcentaje de hembras según el umbral de género (valores habituales exactos).
  static double femalePercent(int ratio) => switch (ratio) {
        0 => 0,
        254 => 100,
        31 => 12.5,
        63 => 25,
        127 => 50,
        191 => 75,
        225 => 87.5,
        _ => ratio / 254 * 100,
      };

  @override
  Widget build(BuildContext context) {
    final p = SpeciesForms.personal(species, form, DexForms.displayGame(species, form));
    final tokens = context.tokens;
    if (p == null) return Text('—', style: TextStyle(color: tokens.muted));
    if (p.genderless) return Text(context.l10n.dexGenderless, style: context.text.bodyLarge);
    final female = femalePercent(p.genderRatio);
    String fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    const male = Color(0xFF5A9BE8), fem = Color(0xFFE86FA4);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.l10n.dexGenderRatio(fmt(female), fmt(100 - female)), style: context.text.bodyLarge),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 8,
          child: Row(children: [
            if (female < 100) Expanded(flex: ((100 - female) * 10).round(), child: Container(color: male)),
            if (female > 0) Expanded(flex: (female * 10).round(), child: Container(color: fem)),
          ]),
        ),
      ),
    ]);
  }
}

class _Evolution extends StatelessWidget {
  const _Evolution({required this.dex, required this.species, required this.form, required this.living});
  final GlobalDex dex;
  final int species;
  final int form;
  final bool living;

  @override
  Widget build(BuildContext context) {
    final steps = Evolutions.family(species, form);
    final tokens = context.tokens;
    if (steps.isEmpty) return Text(context.l10n.dexNoEvolution, style: context.text.bodyLarge!.copyWith(color: tokens.muted));
    Widget mon(int s, int f) {
      final e = dex[s];
      final st = living ? e.livingStatus : e.status;
      final current = s == species;
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: current ? null : () => context.go('/dex/especie/$s'),
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: current ? context.colors.primary.withValues(alpha: 0.12) : null,
            border: Border.all(color: current ? context.colors.primary.withValues(alpha: 0.6) : Colors.transparent),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DexIcon(species: s, form: f, status: st, size: 48),
            const SizedBox(height: 2),
            Text(
              st == DexStatus.unknown ? dexNumber(s) : pokemonName(context, s, f, DexForms.displayGame(s, f)),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall,
            ),
          ]),
        ),
      );
    }

    return Column(children: [
      for (final st in steps)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            mon(st.species, st.form),
            Expanded(
              child: Column(children: [
                Text(
                  evolutionText(context, st),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium!.copyWith(color: tokens.muted),
                ),
                Icon(Icons.arrow_forward_rounded, size: 18, color: tokens.muted),
              ]),
            ),
            mon(st.to, st.toForm),
          ]),
        ),
    ]);
  }
}

class _Forms extends StatelessWidget {
  const _Forms({required this.entry, required this.selected, required this.onSelect});
  final SpeciesDex entry;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final s = entry.species;
    final owned = entry.formsOwned;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final f in entry.collectableForms)
        Builder(builder: (context) {
          final has = owned.contains(f);
          final seen = f < 31 && (entry.formsSeenMask >> f) & 1 == 1;
          final st = has ? DexStatus.caught : (seen || (f == 0 && entry.status != DexStatus.unknown) ? DexStatus.seen : DexStatus.unknown);
          final (t1, t2) = SpeciesForms.types(s, f);
          final name = SpeciesForms.formName(s, f, DexForms.displayGame(s, f), context.dexLang);
          final sel = f == selected;
          return Tooltip(
            message: has ? l10n.dexFormOwned : l10n.dexFormMissing,
            child: InkWell(
              key: ValueKey('dex-form-$f'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelect(f),
              child: Container(
                width: 120,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                decoration: BoxDecoration(
                  color: sel ? context.colors.primary.withValues(alpha: 0.12) : tokens.raised,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sel ? context.colors.primary : tokens.hairline, width: sel ? 1.5 : 1),
                ),
                child: Column(children: [
                  Stack(clipBehavior: Clip.none, children: [
                    DexIcon(species: s, form: f, status: st, size: 52),
                    if (has)
                      Positioned(right: -4, top: -4, child: Icon(Icons.check_circle_rounded, size: 16, color: context.colors.primary)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    name.isEmpty ? speciesName(context, s) : name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 4, children: [
                    TypeChip(t1, dense: true),
                    if (t2 != t1 && t2 != PokemonType.none) TypeChip(t2, dense: true),
                  ]),
                ]),
              ),
            ),
          );
        }),
    ]);
  }
}

class _Games extends StatelessWidget {
  const _Games({required this.dex, required this.species});
  final GlobalDex dex;
  final int species;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final mine = {for (final s in dex.sources) s.game};
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final g in GlobalDex.gamesWith(species))
        Builder(builder: (context) {
          final have = mine.contains(g);
          final accent = GamePalette.of(g, null);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: have ? accent.withValues(alpha: 0.18) : null,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: have ? accent.withValues(alpha: 0.7) : tokens.hairline),
            ),
            child: Text(shortGame(context, g),
                style: context.text.labelMedium!.copyWith(color: have ? null : tokens.muted, fontWeight: have ? FontWeight.w700 : null)),
          );
        }),
    ]);
  }
}

class _Records extends StatelessWidget {
  const _Records({required this.dex, required this.entry});
  final GlobalDex dex;
  final SpeciesDex entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final rows = <(int, DexStatus)>[];
    for (final (i, _) in dex.sources.indexed) {
      final owned = entry.specimens.any((r) => r.source == i && !r.specimen.egg);
      final st = entry.caughtIn.contains(i) || owned
          ? DexStatus.caught
          : (entry.seenIn.contains(i) || entry.specimens.any((r) => r.source == i) ? DexStatus.seen : DexStatus.unknown);
      if (st != DexStatus.unknown) rows.add((i, st));
    }
    if (rows.isEmpty) return Text(l10n.dexRecordsEmpty, style: context.text.bodyLarge!.copyWith(color: tokens.muted));
    return _Card(children: [
      for (final (i, st) in rows)
        Builder(builder: (context) {
          final src = dex.sources[i];
          final caught = st == DexStatus.caught;
          return ListTile(
            dense: true,
            leading: Container(width: 6, height: 28, decoration: BoxDecoration(color: sourceAccent(src), borderRadius: BorderRadius.circular(3))),
            minLeadingWidth: 6,
            title: Text(src.trainer.isEmpty ? '—' : src.trainer, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(gameTitle(context, src.game, src.versionId), maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (entry.shinySeenIn.contains(i)) Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.auto_awesome, size: 14, color: tokens.shiny),
              ),
              Icon(caught ? Icons.catching_pokemon_rounded : Icons.visibility_rounded,
                  size: 16, color: caught ? context.colors.primary : tokens.muted),
              const SizedBox(width: 4),
              Text(caught ? l10n.dexStatusCaught : l10n.dexStatusSeen, style: context.text.labelMedium),
            ]),
            onTap: () => context.go('/arca/save/${src.id}'),
          );
        }),
    ]);
  }
}

class _Specimens extends StatelessWidget {
  const _Specimens({required this.dex, required this.entry});
  final GlobalDex dex;
  final SpeciesDex entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final list = [...entry.specimens]..sort((a, b) {
        final sh = (b.specimen.shiny ? 1 : 0) - (a.specimen.shiny ? 1 : 0);
        return sh != 0 ? sh : b.specimen.level.compareTo(a.specimen.level);
      });
    if (list.isEmpty) return Text(l10n.dexSpecimensEmpty, style: context.text.bodyLarge!.copyWith(color: tokens.muted));
    const max = 60;
    return _Card(children: [
      for (final r in list.take(max))
        Builder(builder: (context) {
          final src = dex.sources[r.source];
          final p = r.specimen;
          final name = p.egg ? l10n.egg : pokemonName(context, p.species, p.form, src.game);
          final where = p.inParty ? l10n.dexInParty('${p.slot + 1}') : l10n.dexInBox('${p.box + 1}', '${p.slot + 1}');
          return ListTile(
            key: ValueKey('dex-specimen-${src.id}-${p.box}-${p.slot}'),
            leading: Stack(clipBehavior: Clip.none, children: [
              DexIcon(
                  species: p.species, form: p.form, status: DexStatus.caught, size: 40, gigantamax: p.gigantamax, shiny: p.shiny),
              if (p.shiny) Positioned(right: -4, top: -4, child: Icon(Icons.auto_awesome, size: 14, color: tokens.shiny)),
              if (p.gigantamax)
                Positioned(left: -4, bottom: -4, child: GmaxBadge(size: 14)),
            ]),
            title: Text(
              p.nickname != null ? '${p.nickname} · $name' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${src.trainer} · ${shortGame(context, src.game)} · $where',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (!p.egg)
                Text(l10n.level(p.level), style: context.text.labelLarge!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              Icon(Icons.chevron_right_rounded, color: tokens.muted),
            ]),
            onTap: () => context.go('/arca/save/${src.id}?box=${p.box}&slot=${p.slot}'),
          );
        }),
      if (list.length > max)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('+${list.length - max}', style: context.text.labelLarge!.copyWith(color: tokens.muted)),
        ),
    ]);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: tokens.raised,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: tokens.hairline)),
      child: Column(children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) Divider(height: 1, color: tokens.hairline),
          c,
        ],
      ]),
    );
  }
}
