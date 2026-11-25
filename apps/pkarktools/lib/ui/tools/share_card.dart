import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/game_palette.dart';
import '../common/brand_mark.dart';
import '../common/format.dart';
import '../common/game_icons.dart';
import '../common/species_avatar.dart';
import '../editor/pickers.dart';
import 'tools_common.dart';

/// Abre la vista de la tarjeta de [pk] con «Guardar PNG» y «Compartir».
Future<void> showShareCard(BuildContext context, Pkm pk, GameVersion game) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ShareCardScreen(pk: pk.clone()..dataGame = game, game: game),
      ),
    );

/// Renderiza lo que hay bajo [key] como PNG.
Future<Uint8List?> captureBoundary(GlobalKey key, {double pixelRatio = 3}) async {
  final ro = key.currentContext?.findRenderObject();
  if (ro is! RenderRepaintBoundary) return null;
  final image = await ro.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data?.buffer.asUint8List();
}

class ShareCardScreen extends ConsumerStatefulWidget {
  const ShareCardScreen({super.key, required this.pk, required this.game});
  final Pkm pk;
  final GameVersion game;

  @override
  ConsumerState<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> {
  final _key = GlobalKey();
  bool _busy = false;

  String get _fileName {
    final n = Species.name(widget.pk.species, SpeciesLanguage.en).replaceAll(RegExp(r'[^A-Za-z0-9]+'), '');
    return 'PKArkTools_${n}_Lv${widget.pk.level}.png';
  }

  Future<void> _run(Future<void> Function(Uint8List png) f) async {
    setState(() => _busy = true);
    try {
      final png = await captureBoundary(_key);
      if (png != null) await f(png);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.toolsShareCard)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: FittedBox(
            child: RepaintBoundary(
              key: _key,
              child: PokemonShareCard(pk: widget.pk, game: widget.game),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('card-save'),
                onPressed: _busy
                    ? null
                    : () => _run((png) async {
                        final done = context.l10n.toolsSavedTo;
                        final path = await ref.read(fileSourcesProvider).exportBytes(_fileName, png);
                        if (path != null) messenger.showSnackBar(SnackBar(content: Text('$done $path')));
                      }),
                icon: const Icon(Icons.download_rounded),
                label: Text(context.l10n.toolsSavePNG),
              ),
              Builder(
                builder: (b) => FilledButton.icon(
                  key: const ValueKey('card-share'),
                  onPressed: _busy
                      ? null
                      : () => _run((png) async {
                          final unavailable = context.l10n.toolsNoShareMenuOnThis;
                          if (!await shareFile(b, png, _fileName, 'image/png')) {
                            messenger.showSnackBar(SnackBar(content: Text(unavailable)));
                          }
                        }),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(context.l10n.toolsShare),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de 540×720 con los datos de un Pokémon, pensada para exportarse
/// a PNG (×3 = 1620×2160). Usa siempre el tema oscuro de la marca.
class PokemonShareCard extends StatelessWidget {
  const PokemonShareCard({super.key, required this.pk, required this.game});
  final Pkm pk;
  final GameVersion game;

  static const width = 540.0;
  static const height = 720.0;

  @override
  Widget build(BuildContext context) {
    final lang = context.dataLang;
    final es = context.isSpanish;
    final accent = GamePalette.of(game, null);
    final (t1, t2) = SpeciesForms.types(pk.species, pk.form, game);
    final species = pokemonName(context, pk.species, pk.form, game);
    final nick = pk.isNicknamed ? pk.nickname : null;
    final gen = pk.generation;
    final gb = pk.format.isGameBoy;
    final ivs = pk.ivs, evs = pk.evs;
    final ribbons = Ribbons.supports(pk.format) ? Ribbons.countOwned(pk) : 0;
    final origin = gen >= 3 && pk.version > 0 ? GameVersions.name(pk.version, es: es) : gameTitle(context, game);
    const fg = Colors.white;
    final muted = Colors.white.withValues(alpha: 0.66);
    final base = Theme.of(context).textTheme;
    TextStyle st(double size, {FontWeight w = FontWeight.w600, Color color = fg}) =>
        (base.bodyMedium ?? const TextStyle()).copyWith(fontSize: size, fontWeight: w, color: color, height: 1.2);
    String statLabel(int i) => gb && i == 3 ? context.l10n.special : Legality.statName(i, lang);
    final visible = gb ? const [0, 1, 2, 3, 5] : const [0, 1, 2, 3, 4, 5];
    final maxIv = pk.format.maxIv;

    Widget chip(String text, Color color, {Widget? leading}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 5)],
          Text(text, style: st(13)),
        ],
      ),
    );

    Widget info(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: st(12, w: FontWeight.w500, color: muted),
            ),
          ),
          Expanded(
            child: Text(value, style: st(13), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: const ValueKey('share-card'),
        width: width,
        height: height,
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(accent, const Color(0xFF0E1116), 0.55)!, const Color(0xFF0E1116)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const BrandMark(size: 30, semanticLabel: null),
                const SizedBox(width: 8),
                Text(
                  'PKArkTools',
                  style: st(15, w: FontWeight.w800).copyWith(fontFamily: AppTheme.display),
                ),
                const Spacer(),
                Text(
                  origin,
                  style: st(12, w: FontWeight.w500, color: muted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SpeciesAvatar(
                  species: pk.species,
                  form: pk.form,
                  game: game,
                  female: pk.gender == 1,
                  shiny: pk.isShiny,
                  egg: pk.isEgg,
                  size: 150,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nick ?? species,
                        style: st(30, w: FontWeight.w800),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (nick != null)
                        Text(
                          species,
                          style: st(15, w: FontWeight.w500, color: muted),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          context.l10n.level(pk.level),
                          if (pk.gender == 0) '♂' else if (pk.gender == 1) '♀',
                          '#${pk.species.toString().padLeft(4, '0')}',
                        ].join('   '),
                        style: st(15, w: FontWeight.w500, color: muted),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          chip(
                            GameStrings.type(t1.index - 1, lang),
                            TypePalette.of(t1),
                            leading: TypeIcon(type: t1, size: 15),
                          ),
                          if (t2 != PokemonType.none && t2 != t1)
                            chip(
                              GameStrings.type(t2.index - 1, lang),
                              TypePalette.of(t2),
                              leading: TypeIcon(type: t2, size: 15),
                            ),
                          if (pk.isShiny)
                            chip(
                              context.l10n.toolsShiny,
                              const Color(0xFFFFC94A),
                              leading: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFFFC94A)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (gen >= 3) info(context.l10n.toolsNature, GameStrings.nature(pk.statNature, lang)),
            if (gen >= 3 && pk.ability > 0) info(context.l10n.toolsAbility, GameStrings.ability(pk.ability, lang)),
            if (pk.heldItem > 0) info(context.l10n.toolsItem, GameStrings.itemFor(pk.heldItem, game, lang)),
            if (pk.format.hasTeraType)
              info(
                context.l10n.toolsTeraType,
                pk.teraType == 99 ? context.l10n.toolsStellar : GameStrings.type(pk.teraType, lang),
              ),
            info(context.l10n.toolsOrigin, origin),
            if (ribbons > 0) info(context.l10n.toolsRibbons, '$ribbons'),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(gb ? 'DV / ${context.l10n.statExp}' : 'IV / EV', style: st(13, w: FontWeight.w700)),
                        const SizedBox(height: 6),
                        for (final i in visible)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.5),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 62,
                                  child: Text(
                                    statLabel(i),
                                    style: st(12, w: FontWeight.w500, color: muted),
                                  ),
                                ),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ivs[i] / maxIv,
                                      minHeight: 7,
                                      color: accent,
                                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: Text('${ivs[i]} / ${evs[i]}', textAlign: TextAlign.right, style: st(12)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.toolsMoves, style: st(13, w: FontWeight.w700)),
                        const SizedBox(height: 6),
                        for (final m in pk.moves)
                          if (m != 0)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                GameStrings.move(m, lang),
                                style: st(13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                context.l10n.toolsMadeWithPKArkTools,
                style: st(10, w: FontWeight.w500, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
