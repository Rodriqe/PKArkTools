import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pkcore/pkcore.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/game_palette.dart';
import '../common/format.dart';
import '../common/game_icons.dart';
import '../dex/dex_text.dart';
import '../dex/dex_tile.dart';

/// Ruta de la guía de una especie/forma.
String ribbonGuidePath(int species, int form) => '/cintas/guia/$species${form == 0 ? '' : '?forma=$form'}';

/// Color de acento de un juego del grafo (paleta de las versiones del Arca).
Color ribbonGameColor(RibbonGame g) => switch (g) {
  RibbonGame.vc => GamePalette.of(GameVersion.crystal),
  RibbonGame.colosseum => const Color(0xFF8E6BB8),
  RibbonGame.xd => const Color(0xFF5B4A9E),
  RibbonGame.rse => GamePalette.of(GameVersion.emerald),
  RibbonGame.frlg => GamePalette.of(GameVersion.fireRedLeafGreen),
  RibbonGame.dppt => GamePalette.of(GameVersion.platinum),
  RibbonGame.hgss => GamePalette.of(GameVersion.heartGoldSoulSilver),
  RibbonGame.bw => GamePalette.of(GameVersion.black2White2),
  RibbonGame.xy => GamePalette.of(GameVersion.xy),
  RibbonGame.oras => GamePalette.of(GameVersion.omegaRubyAlphaSapphire),
  RibbonGame.smusum => GamePalette.of(GameVersion.ultraSunUltraMoon),
  RibbonGame.lgpe => GamePalette.of(GameVersion.letsGo),
  RibbonGame.go => const Color(0xFF3FA7D6),
  RibbonGame.swsh => GamePalette.of(GameVersion.swordShield),
  RibbonGame.bdsp => GamePalette.of(GameVersion.brilliantDiamondShiningPearl),
  RibbonGame.pla => GamePalette.of(GameVersion.legendsArceus),
  RibbonGame.sv => GamePalette.of(GameVersion.scarletViolet),
  RibbonGame.za => GamePalette.of(GameVersion.legendsZA),
};

String _originKind(AppLocalizations l10n, OriginKind k) => switch (k) {
  OriginKind.egg => l10n.rmKindEgg,
  OriginKind.wild => l10n.rmKindWild,
  OriginKind.static => l10n.rmKindStatic,
  OriginKind.gift => l10n.rmKindGift,
  OriginKind.trade => l10n.rmKindTrade,
  OriginKind.shadow => l10n.rmKindShadow,
  OriginKind.raid => l10n.rmKindRaid,
  OriginKind.go => l10n.rmKindGo,
  OriginKind.event => l10n.rmKindEvent,
};

String _name(BuildContext context, int species, int form) => SpeciesForms.displayName(species, form, null, context.dexLang);

String _fold(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñç';
  const to = 'aaaaeeeeiiiioooouuuunc';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}

// =========================================================================== Inicio

/// Pestaña Ribbon Hunter: buscador de especie y forma, acceso al ranking por niveles.
class RibbonHunterScreen extends StatefulWidget {
  const RibbonHunterScreen({super.key});

  @override
  State<RibbonHunterScreen> createState() => _RibbonHunterScreenState();
}

class _RibbonHunterScreenState extends State<RibbonHunterScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<(int, int)> _results(BuildContext context) {
    final q = _fold(_query.trim());
    if (q.isEmpty) return const [];
    final number = int.tryParse(q.replaceFirst('#', ''));
    final out = <(int, int)>[];
    for (final t in RibbonMaster.targets) {
      if (number != null) {
        if (t.$1 == number) out.add(t);
        continue;
      }
      final es = _fold(SpeciesForms.displayName(t.$1, t.$2, null, DataLanguage.es));
      final en = _fold(SpeciesForms.displayName(t.$1, t.$2, null, DataLanguage.en));
      if (es.contains(q) || en.contains(q)) out.add(t);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final pad = compact ? 16.0 : 32.0;
    final results = _results(context);
    final tiers = RibbonMaster.tiers();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: CustomScrollView(
              key: const PageStorageKey('ribbon-hunter'),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, compact ? 20 : 36, pad, 4),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.navRibbonHunter, style: compact ? context.text.displaySmall : context.text.displayMedium),
                        const SizedBox(height: 6),
                        Text(l10n.rmSubtitle, style: context.text.bodyMedium!.copyWith(color: tokens.muted)),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 18, pad, 0),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      key: const ValueKey('rm-search'),
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: l10n.rmSearchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: l10n.dexClear,
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => setState(() {
                                  _search.clear();
                                  _query = '';
                                }),
                              ),
                      ),
                    ),
                  ),
                ),
                if (_query.trim().isNotEmpty) ...[
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 12, pad, 6),
                    sliver: SliverToBoxAdapter(
                      child: Text(l10n.rmResults(results.length), style: context.text.labelLarge!.copyWith(color: tokens.muted)),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 0, pad, 120),
                    sliver: SliverList.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final (s, f) = results[i];
                        return _SpeciesRow(key: ValueKey('rm-result-$s-$f'), species: s, form: f);
                      },
                    ),
                  ),
                ] else ...[
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 22, pad, 0),
                    sliver: SliverToBoxAdapter(child: _RankingTeaser(tiers: tiers.length <= 8 ? tiers : tiers.sublist(0, 8))),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 18, pad, 120),
                    sliver: SliverToBoxAdapter(child: _HowCard()),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeciesRow extends StatelessWidget {
  const _SpeciesRow({super.key, required this.species, required this.form, this.push = false});
  final int species, form;

  /// Abre la guía encima (para volver al nivel) en vez de sustituir la ruta.
  final bool push;

  @override
  Widget build(BuildContext context) {
    final r = RibbonMaster.route(species, form)!;
    final tokens = context.tokens;
    final origin = r.data.originGame;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: DexIcon(species: species, form: form, status: DexStatus.caught, size: 40),
        title: Text(_name(context, species, form), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${dexNumber(species)} · ${origin.name(context.dexLang)} · ${_originKind(context.l10n, r.data.kind)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tokens.muted),
        ),
        trailing: _TotalBadge(total: r.total),
        onTap: () => push ? context.push(ribbonGuidePath(species, form)) : context.go(ribbonGuidePath(species, form)),
      ),
    );
  }
}

class _TotalBadge extends StatelessWidget {
  const _TotalBadge({required this.total});
  final int total;
  static const big = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors.primary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 14 : 10, vertical: big ? 8 : 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.military_tech_rounded, size: big ? 20 : 16, color: c),
          const SizedBox(width: 4),
          Text(
            '$total',
            style: (big ? context.text.titleLarge : context.text.labelLarge)!.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Iconos de muestra de un nivel, solapados, con "+N" si quedan más.
class _TierSample extends StatelessWidget {
  const _TierSample({required this.tier, required this.max, this.size = 40});
  final RibbonTier tier;
  final int max;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final shown = tier.sample(tier.length > max ? max - 1 : max);
    final rest = tier.length - shown.length;
    final step = size * 0.72;
    final count = shown.length + (rest > 0 ? 1 : 0);
    return SizedBox(
      height: size,
      width: step * (count - 1) + size,
      child: Stack(
        children: [
          for (final (i, r) in shown.indexed)
            Positioned(
              left: i * step,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: tokens.base,
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.hairline),
                ),
                child: Center(
                  child: DexIcon(species: r.species, form: r.form, status: DexStatus.caught, size: size - 4),
                ),
              ),
            ),
          if (rest > 0)
            Positioned(
              left: shown.length * step,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(context.colors.primary.withValues(alpha: 0.16), tokens.base),
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.hairline),
                ),
                child: Center(
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text('+$rest', style: context.text.labelMedium!.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Texto del origen común destacado de un nivel.
String _tierOrigin(BuildContext context, RibbonTier t) {
  final l10n = context.l10n;
  final o = t.mainOrigin;
  final kind = _originKind(l10n, o.kind);
  final games = o.gamesLabel(context.dexLang);
  return o.count == t.length ? l10n.rmTierOriginAll(kind, games) : l10n.rmTierOriginMost(kind, games, o.count, t.length);
}

String _tierPath(RibbonTier t) => '/cintas/ranking/${t.total}';

class _RankingTeaser extends StatelessWidget {
  const _RankingTeaser({required this.tiers});
  final List<RibbonTier> tiers;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.alphaBlend(context.colors.primary.withValues(alpha: 0.18), tokens.raised), tokens.raised],
        ),
        border: Border.all(color: tokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: tokens.shiny),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.rmRanking, style: context.text.titleLarge)),
            ],
          ),
          const SizedBox(height: 4),
          Text(l10n.rmRankingSubtitle, style: context.text.bodyMedium!.copyWith(color: tokens.muted)),
          const SizedBox(height: 14),
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tiers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final t = tiers[i];
                return InkWell(
                  key: ValueKey('rm-teaser-tier-${t.total}'),
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context.go(_tierPath(t)),
                  child: Container(
                    width: 132,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: tokens.base.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: tokens.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.rmTierPos(t.position), style: context.text.labelSmall!.copyWith(color: tokens.muted)),
                        Text(
                          l10n.rmRibbons(t.total),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium!.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        _TierSample(tier: t, max: 4, size: 32),
                        const SizedBox(height: 6),
                        Text(
                          l10n.rmTierCount(t.length),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall!.copyWith(color: tokens.muted),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const ValueKey('rm-see-ranking'),
              onPressed: () => context.go('/cintas/ranking'),
              icon: const Icon(Icons.leaderboard_rounded),
              label: Text(l10n.rmSeeRanking),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.raised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.route_rounded, color: context.colors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.rmHowTitle, style: context.text.titleMedium),
                const SizedBox(height: 4),
                Text(context.l10n.rmHowBody, style: context.text.bodyMedium!.copyWith(color: tokens.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================== Ranking por niveles

AppBar _subAppBar(BuildContext context, String title, String fallback) => AppBar(
  backgroundColor: Colors.transparent,
  leading: IconButton(
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    icon: const Icon(Icons.arrow_back_rounded),
    onPressed: () => context.canPop() ? context.pop() : context.go(fallback),
  ),
  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
);

/// Ranking agrupado por niveles: un nivel por cada máximo de cintas.
class RibbonRankingScreen extends StatelessWidget {
  const RibbonRankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final pad = compact ? 16.0 : 32.0;
    final tiers = RibbonMaster.tiers();
    return Scaffold(
      appBar: _subAppBar(context, l10n.rmRanking, '/cintas'),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView.builder(
              key: const PageStorageKey('rm-ranking'),
              padding: EdgeInsets.fromLTRB(pad, 4, pad, 96),
              itemCount: tiers.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(l10n.rmRankingSubtitle, style: context.text.bodyMedium!.copyWith(color: tokens.muted)),
                  );
                }
                return _TierCard(tier: tiers[i - 1]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier});
  final RibbonTier tier;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final t = tier;
    final originColor = ribbonGameColor(t.mainOrigin.games.first);
    return Card(
      key: ValueKey('rm-tier-${t.total}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(_tierPath(t)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TotalBadge(total: t.total),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l10n.rmRibbons(t.total)} · ${l10n.rmTierCount(t.length)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall!.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(l10n.rmTierPos(t.position), style: context.text.labelSmall!.copyWith(color: tokens.muted)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: tokens.muted),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, c) {
                  const size = 36.0;
                  final fit = ((c.maxWidth - size) / (size * 0.72)).floor() + 1;
                  return _TierSample(tier: t, max: fit.clamp(2, 14), size: size);
                },
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(Icons.flag_rounded, size: 16, color: originColor),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _tierOrigin(context, t),
                      key: ValueKey('rm-tier-origin-${t.total}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall!.copyWith(color: tokens.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un nivel del ranking: todas sus especies y formas en orden de Dex, con filtro.
class RibbonTierScreen extends StatefulWidget {
  const RibbonTierScreen({super.key, required this.total});
  final int total;

  @override
  State<RibbonTierScreen> createState() => _RibbonTierScreenState();
}

class _RibbonTierScreenState extends State<RibbonTierScreen> {
  final _filter = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  List<RibbonRoute> _visible(RibbonTier t) {
    final q = _fold(_query.trim());
    if (q.isEmpty) return t.routes;
    final number = int.tryParse(q.replaceFirst('#', ''));
    return [
      for (final r in t.routes)
        if (number != null
            ? r.species == number
            : _fold(SpeciesForms.displayName(r.species, r.form, null, DataLanguage.es)).contains(q) ||
                  _fold(SpeciesForms.displayName(r.species, r.form, null, DataLanguage.en)).contains(q))
          r,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final pad = compact ? 16.0 : 32.0;
    final t = RibbonMaster.tier(widget.total);
    if (t == null) {
      return Scaffold(
        appBar: _subAppBar(context, l10n.rmRanking, '/cintas/ranking'),
        body: Center(child: Text(l10n.rmTierNotFound)),
      );
    }
    final list = _visible(t);
    return Scaffold(
      appBar: _subAppBar(context, '${l10n.rmTierPos(t.position)} · ${l10n.rmRibbons(t.total)}', '/cintas/ranking'),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: CustomScrollView(
              key: PageStorageKey('rm-tier-${t.total}'),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 4, pad, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _TotalBadge(total: t.total),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(l10n.rmTierCount(t.length), key: const ValueKey('rm-tier-count'), style: context.text.titleMedium),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final o in t.origins)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(Icons.flag_rounded, size: 16, color: ribbonGameColor(o.games.first)),
                                label: Text('${_originKind(l10n, o.kind)} · ${o.gamesLabel(context.dexLang)} · ${o.count}', overflow: TextOverflow.ellipsis),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          key: const ValueKey('rm-tier-filter'),
                          controller: _filter,
                          onChanged: (v) => setState(() => _query = v),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: l10n.rmTierFilterHint,
                            prefixIcon: const Icon(Icons.filter_list_rounded),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: l10n.dexClear,
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () => setState(() {
                                      _filter.clear();
                                      _query = '';
                                    }),
                                  ),
                          ),
                        ),
                        if (_query.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(l10n.rmResults(list.length), style: context.text.labelLarge!.copyWith(color: tokens.muted)),
                          ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, 96),
                  sliver: SliverList.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final r = list[i];
                      return _SpeciesRow(key: ValueKey('rm-tier-row-${r.species}-${r.form}'), species: r.species, form: r.form, push: true);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================== Guía

class RibbonGuideScreen extends ConsumerStatefulWidget {
  const RibbonGuideScreen({super.key, required this.species, this.form = 0});
  final int species;
  final int form;

  @override
  ConsumerState<RibbonGuideScreen> createState() => _RibbonGuideScreenState();
}

class _RibbonGuideScreenState extends ConsumerState<RibbonGuideScreen> {
  final _shot = GlobalKey();

  Future<void> _share(RibbonRoute r, String action) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (action == 'text') {
      await Clipboard.setData(ClipboardData(text: r.toText(context.dexLang)));
      messenger.showSnackBar(SnackBar(content: Text(l10n.rmCopied)));
      return;
    }
    final boundary = _shot.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    final name = 'ribbon-hunter-${r.species}${r.form == 0 ? '' : '-${r.form}'}.png';
    final path = await ref.read(fileSourcesProvider).exportBytes(name, data.buffer.asUint8List());
    if (path != null) messenger.showSnackBar(SnackBar(content: Text(l10n.rmImageSaved(path))));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = RibbonMaster.route(widget.species, widget.form);
    final compact = MediaQuery.sizeOf(context).width < 720;
    final pad = compact ? 16.0 : 32.0;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/cintas'),
        ),
        title: Text(l10n.navRibbonHunter),
        actions: [
          if (r != null)
            PopupMenuButton<String>(
              key: const ValueKey('rm-share'),
              tooltip: l10n.rmShare,
              icon: const Icon(Icons.ios_share_rounded),
              onSelected: (a) => _share(r, a),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'text',
                  child: ListTile(leading: const Icon(Icons.content_copy_rounded), title: Text(l10n.rmCopyText)),
                ),
                PopupMenuItem(
                  value: 'image',
                  child: ListTile(leading: const Icon(Icons.image_outlined), title: Text(l10n.rmSaveImage)),
                ),
              ],
            ),
          SizedBox(width: compact ? 4 : 16),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: r == null
            ? Center(child: Text(l10n.rmNoGuide))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: SingleChildScrollView(
                    key: PageStorageKey('rm-guide-${widget.species}-${widget.form}'),
                    padding: EdgeInsets.fromLTRB(pad, 4, pad, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RepaintBoundary(
                          key: _shot,
                          child: ColoredBox(
                            color: context.colors.surface,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _GuideHeader(route: r),
                                const SizedBox(height: 22),
                                Text(l10n.rmTimeline, style: context.text.titleLarge),
                                const SizedBox(height: 12),
                                for (final (i, s) in r.steps.indexed) _StepCard(step: s, index: i, last: i == r.steps.length - 1),
                              ],
                            ),
                          ),
                        ),
                        _MemoryNote(route: r),
                        _MarksCard(route: r),
                        _UnavailableCard(route: r),
                        _YourSpecimens(route: r),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _GuideHeader extends StatelessWidget {
  const _GuideHeader({required this.route});
  final RibbonRoute route;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final r = route;
    final (t1, _) = SpeciesForms.types(r.species, r.form);
    final accent = TypePalette.of(t1);
    final compact = MediaQuery.sizeOf(context).width < 520;
    final iconSize = compact ? 84.0 : 120.0;
    final origin = r.data.originGame;
    final tier = RibbonMaster.tierOf(r.species, r.form)!;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: iconSize + 12,
                height: iconSize + 12,
                decoration: BoxDecoration(color: tokens.base.withValues(alpha: 0.5), shape: BoxShape.circle),
                child: Center(
                  child: DexIcon(species: r.species, form: r.form, status: DexStatus.caught, size: iconSize),
                ),
              ),
              SizedBox(width: compact ? 12 : 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dexNumber(r.species), style: context.text.labelLarge!.copyWith(color: tokens.muted)),
                    Text(
                      _name(context, r.species, r.form),
                      key: const ValueKey('rm-guide-name'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (compact ? context.text.headlineSmall : context.text.displaySmall)!.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      key: const ValueKey('rm-rank-pos'),
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => context.go(_tierPath(tier)),
                      child: Text(
                        l10n.rmTierOfRanking(tier.position, RibbonMaster.tiers().length, l10n.rmTierCount(tier.length)),
                        style: context.text.labelMedium!.copyWith(color: tokens.muted, decoration: TextDecoration.underline, decorationColor: tokens.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Fact(
                key: const ValueKey('rm-total'),
                icon: Icons.military_tech_rounded,
                label: l10n.rmMaxToday,
                value: l10n.rmRibbons(r.total),
                color: context.colors.primary,
              ),
              _Fact(
                icon: Icons.flag_rounded,
                label: l10n.rmOrigin,
                value: '${origin.name(context.dexLang)} · ${l10n.rmGen('${origin.generation}')}',
                sub: _originKind(l10n, r.data.kind),
                color: ribbonGameColor(origin),
              ),
            ],
          ),
          if (r.data.kind == OriginKind.event) ...[
            const SizedBox(height: 10),
            Text(l10n.rmOriginEvent, style: context.text.bodySmall!.copyWith(color: tokens.muted)),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({super.key, required this.icon, required this.label, required this.value, required this.color, this.sub});
  final IconData icon;
  final String label, value;
  final String? sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: context.text.labelSmall!.copyWith(color: tokens.muted)),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall!.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (sub != null) Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.index, required this.last});
  final RouteStep step;
  final int index;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final lang = context.dexLang;
    final color = ribbonGameColor(step.game);
    final compact = MediaQuery.sizeOf(context).width < 720;
    final stages = [for (final s in step.stages.reversed) _name(context, s.$1, s.$2)];
    return Stack(
      children: [
        // Línea de tiempo.
        if (!last) Positioned(left: 12.5, top: 26, bottom: 0, child: Container(width: 3, color: color.withValues(alpha: 0.35))),
        Positioned(
          left: 6,
          top: 18,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: tokens.base, width: 3),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Container(
            key: ValueKey('rm-step-${step.game.id}'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(compact ? 12 : 16),
            decoration: BoxDecoration(
              color: tokens.raised,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tokens.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        l10n.rmGen('${step.game.generation}'),
                        style: context.text.labelSmall!.copyWith(color: GamePalette.onAccent(color), fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(step.game.name(lang), maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                    ),
                    if (step.count > 0)
                      Text(
                        l10n.rmStepCount(step.count),
                        style: context.text.titleMedium!.copyWith(color: context.colors.primary, fontWeight: FontWeight.w800),
                      ),
                  ],
                ),
                if (stages.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.rmFormsLabel(stages.join(' → ')),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall!.copyWith(color: tokens.muted),
                  ),
                ],
                for (final n in step.notes)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _Note(note: n),
                  ),
                const SizedBox(height: 8),
                if (step.ribbons.isEmpty)
                  Text(l10n.rmTransferOnly, style: context.text.bodyMedium!.copyWith(color: tokens.muted))
                else
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth >= 760 ? 2 : 1;
                      final w = (c.maxWidth - (cols - 1) * 8) / cols;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final g in const ['G3', 'G4'])
                            if (step.ribbons.any((e) => _isContest(e, g)))
                              SizedBox(
                                width: c.maxWidth,
                                child: _ContestGroup(gen: g, entries: [for (final e in step.ribbons) if (_isContest(e, g)) e]),
                              ),
                          for (final e in step.ribbons)
                            if (!_isContest(e, 'G3') && !_isContest(e, 'G4'))
                              SizedBox(
                                width: w,
                                child: _RibbonCard(entry: e),
                              ),
                        ],
                      );
                    },
                  ),
                if (step.alsoHere.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.rmAlsoHere(step.alsoHere.map((e) => e.name(lang)).join(', ')),
                    style: context.text.bodySmall!.copyWith(color: tokens.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

bool _isContest(RibbonGuideEntry e, String gen) => e.key.startsWith('Ribbon$gen');

/// Las 20 cintas de concurso de Gen 3 o Gen 4 en una tarjeta: una fila por
/// categoría con sus cuatro rangos en orden.
class _ContestGroup extends StatelessWidget {
  const _ContestGroup({required this.gen, required this.entries});
  final String gen;
  final List<RibbonGuideEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final lang = context.dexLang;
    final g3 = gen == 'G3';
    final narrow = MediaQuery.sizeOf(context).width < 520;
    final icon = narrow ? 24.0 : 30.0;
    final byCat = <String, List<RibbonGuideEntry>>{};
    for (final e in entries) {
      final cat = RegExp('^Ribbon$gen(Cool|Beauty|Cute|Smart|Tough)').firstMatch(e.key)![1]!;
      byCat.putIfAbsent(cat, () => []).add(e);
    }
    return Container(
      key: ValueKey('rm-contests-$gen'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.base.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.hairline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(g3 ? l10n.rmContestG3(entries.length) : l10n.rmContestG4(entries.length), style: context.text.titleSmall),
        const SizedBox(height: 2),
        Text(g3 ? l10n.rmContestOrderG3 : l10n.rmContestOrderG4, style: context.text.bodySmall!.copyWith(color: tokens.muted)),
        const SizedBox(height: 10),
        for (final list in byCat.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              SizedBox(
                width: narrow ? 64 : 92,
                child: Text(
                  list.first.name(lang).replaceAll(RegExp(r'\s*\(G[34]\)'), ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge,
                ),
              ),
              Expanded(
                child: Wrap(spacing: narrow ? 1 : 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  for (final (i, e) in list.indexed) ...[
                    if (i > 0) Icon(Icons.chevron_right_rounded, size: narrow ? 10 : 16, color: tokens.muted),
                    Tooltip(
                      message: '${e.name(lang)} — ${e.how(lang)}',
                      child: e.info == null ? SizedBox(width: icon) : RibbonIcon(ribbon: e.info!, size: icon),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.note});
  final RouteNote note;

  @override
  Widget build(BuildContext context) {
    final warn = note.kind == RouteNoteKind.oneWay;
    final color = warn ? const Color(0xFFE0A33A) : context.colors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            switch (note.kind) {
              RouteNoteKind.oneWay => Icons.warning_amber_rounded,
              RouteNoteKind.homeFree => Icons.swap_horiz_rounded,
              _ => Icons.info_outline_rounded,
            },
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(note.text(context.dexLang), style: context.text.bodySmall)),
        ],
      ),
    );
  }
}

class _RibbonCard extends StatelessWidget {
  const _RibbonCard({required this.entry});
  final RibbonGuideEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final lang = context.dexLang;
    final info = entry.info;
    final req = entry.requirement(lang);
    final tag = switch (entry.availability) {
      RibbonAvailability.online => context.l10n.rmOnline,
      RibbonAvailability.closedOnline => context.l10n.rmClosedOnline,
      RibbonAvailability.event => context.l10n.rmEventOnly,
      RibbonAvailability.playable => null,
    };
    return Container(
      key: ValueKey('rm-ribbon-${entry.key}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.base.withValues(alpha: entry.counts ? 0.55 : 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info != null) RibbonIcon(ribbon: info, size: 36, dim: !entry.counts) else const SizedBox(width: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(entry.name(lang), style: context.text.titleSmall),
                    if (tag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: tokens.muted.withValues(alpha: 0.6)),
                        ),
                        child: Text(tag, style: context.text.labelSmall!.copyWith(color: tokens.muted)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(entry.how(lang), style: context.text.bodySmall),
                if (req.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    req,
                    style: context.text.bodySmall!.copyWith(color: tokens.muted, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Material(
        color: tokens.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: tokens.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: context.colors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(title, style: context.text.titleMedium)),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: context.text.bodySmall!.copyWith(color: tokens.muted)),
              ],
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryNote extends StatelessWidget {
  const _MemoryNote({required this.route});
  final RibbonRoute route;

  @override
  Widget build(BuildContext context) {
    final (contest, battle) = route.memoryCounts;
    if (contest == 0 && battle == 0) return const SizedBox.shrink();
    return _Panel(
      title: context.l10n.rmMemoryTitle,
      icon: Icons.auto_stories_rounded,
      child: Text(context.l10n.rmMemory('$battle', '$contest', route.visibleInFinalGame), style: context.text.bodyMedium),
    );
  }
}

class _MarksCard extends StatelessWidget {
  const _MarksCard({required this.route});
  final RibbonRoute route;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = context.dexLang;
    final post = route.postCaptureMarks;
    final games = route.markGames;
    if (post.isEmpty && games.isEmpty) return const SizedBox.shrink();
    final marks = {for (final g in games) ...RibbonGuide.encounterMarks(g).map((m) => m.key)};
    return _Panel(
      title: l10n.rmMarks,
      subtitle: l10n.rmMarksNote,
      icon: Icons.verified_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.isNotEmpty) ...[
            Text(l10n.rmMarksPost(post.map((k) => Ribbons.info(k)?.name(lang) ?? k).join(', ')), style: context.text.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final k in post)
                  if (Ribbons.info(k) case final i?)
                    Tooltip(
                      message: i.name(lang),
                      child: RibbonIcon(ribbon: i, size: 32),
                    ),
              ],
            ),
          ],
          if (games.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l10n.rmMarksCapture(games.map((g) => g.name(lang)).join(' / '), marks.length), style: context.text.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.route});
  final RibbonRoute route;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = context.dexLang;
    return _Panel(
      title: l10n.rmUnavailable,
      subtitle: l10n.rmUnavailableBody,
      icon: Icons.event_busy_rounded,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in route.unavailable)
            Chip(
              key: ValueKey('rm-unavailable-${e.key}'),
              avatar: e.info == null ? null : RibbonIcon(ribbon: e.info!, size: 22, dim: true),
              label: Text(
                '${e.name(lang)} · ${e.availability == RibbonAvailability.closedOnline ? l10n.rmClosedOnline : l10n.rmEventOnly}',
                style: context.text.labelMedium,
              ),
            ),
        ],
      ),
    );
  }
}

class _YourSpecimens extends ConsumerWidget {
  const _YourSpecimens({required this.route});
  final RibbonRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final lang = context.dexLang;
    final dex = ref.watch(globalDexProvider).value;
    if (dex == null) return const SizedBox.shrink();
    final list = [
      for (final r in dex[route.species].specimens)
        if (!r.specimen.egg && r.specimen.form == route.form) r,
    ]..sort((a, b) => b.specimen.ribbons.length.compareTo(a.specimen.ribbons.length));
    return _Panel(
      title: l10n.rmYourSpecimens,
      icon: Icons.catching_pokemon_rounded,
      child: list.isEmpty
          ? Text(l10n.rmSpecimensEmpty, style: context.text.bodyMedium!.copyWith(color: tokens.muted))
          : Column(
              children: [
                for (final sr in list.take(30))
                  Builder(
                    builder: (context) {
                      final src = dex.sources[sr.source];
                      final p = sr.specimen;
                      final game = RibbonGame.fromGameVersion(src.game);
                      final missing = game == null ? const <RibbonGuideEntry>[] : route.missingFor(p.ribbons, game);
                      final have = p.ribbons.where((k) => !k.startsWith('RibbonMark')).length;
                      final name = p.nickname != null
                          ? '${p.nickname} · ${_name(context, p.species, p.form)}'
                          : _name(context, p.species, p.form);
                      return ExpansionTile(
                        key: ValueKey('rm-specimen-${src.id}-${p.box}-${p.slot}'),
                        tilePadding: EdgeInsets.zero,
                        leading: DexIcon(species: p.species, form: p.form, status: DexStatus.caught, size: 40, shiny: p.shiny),
                        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${src.trainer} · ${shortGame(context, src.game)}\n${missing.isEmpty ? l10n.rmSpecimenComplete(have) : l10n.rmSpecimenLine(have, missing.length)}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall!.copyWith(color: tokens.muted),
                        ),
                        childrenPadding: const EdgeInsets.only(bottom: 10),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (missing.isNotEmpty) ...[
                            Text(l10n.rmMissingTitle(missing.length), style: context.text.labelLarge),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final e in missing)
                                  if (e.info case final i?)
                                    Tooltip(
                                      message: '${e.name(lang)} — ${e.how(lang)}',
                                      child: RibbonIcon(ribbon: i, size: 30),
                                    ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
              ],
            ),
    );
  }
}
