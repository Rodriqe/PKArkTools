import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pkcore/pkcore.dart';

import '../../data/sprites/sprites.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../common/sprite_image.dart';
import 'dex_text.dart';
import 'dex_tile.dart';

/// Insignia «G» de Gigamax: en «Tus ejemplares» marca el factor Gigamax y,
/// en una forma Gigamax sin icono propio, que el icono es el de la especie.
class GmaxBadge extends StatelessWidget {
  const GmaxBadge({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Color(0xFFE5385A), Color(0xFF8E2DE2)]),
        ),
        child: Text('G',
            style: TextStyle(color: Colors.white, fontSize: size * 0.62, fontWeight: FontWeight.w900, height: 1)),
      );
}

/// Insignia de la clase de forma especial (Mega, Primigenio, Ultra, Gigamax).
/// [compact] es la versión pequeña que se pone sobre el icono de la especie
/// cuando la forma no tiene icono propio.
class SpecialKindBadge extends StatelessWidget {
  const SpecialKindBadge(this.kind, {super.key, this.compact = false});
  final SpecialFormKind kind;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (kind) {
      SpecialFormKind.mega => ('MEGA', const Color(0xFF7B61FF)),
      SpecialFormKind.primal => (context.isSpanish ? 'PRIMIGENIO' : 'PRIMAL', const Color(0xFFE0663D)),
      SpecialFormKind.ultraBurst => ('ULTRA', const Color(0xFFE9B10E)),
      SpecialFormKind.gigantamax => ('G-MAX', const Color(0xFFD8335B)),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 7, vertical: compact ? 1 : 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(compact ? 4 : 6)),
      child: Text(compact && kind == SpecialFormKind.primal ? 'P' : label,
          style: TextStyle(color: Colors.white, fontSize: compact ? 8 : 10, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
    );
  }
}

/// Tarjeta de una forma especial: silueta si está bloqueada (con cómo se
/// desbloquea) y, por separado, sus variantes normal y variocolor.
class SpecialFormCard extends StatelessWidget {
  const SpecialFormCard({super.key, required this.dex, required this.unlock});
  final GlobalDex dex;
  final SpecialUnlock unlock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final f = unlock.form;
    final any = unlock.normalUnlocked || unlock.shinyUnlocked;
    final iconForm = specialFormIconForm(f);
    final iconStatus = any ? DexStatus.caught : DexStatus.unknown;
    // Icono propio de la forma (Gigamax, Mega…): el variocolor en cuanto la
    // variocolor está desbloqueada (también si la normal lo está; cada
    // pastilla muestra además el de su variante). Sin icono propio: el de la
    // especie con insignia. Sin variocolor en la fuente: el normal con ✦.
    final ownIcon = Sprites.hasSpecialIcon(f);
    final normalIcon = Sprites.specialVariant(f, shiny: false).ref;
    final shinyIcon = Sprites.hasSpecialShinyIcon(f) ? Sprites.special(f, shiny: true) : null;
    final shown = Sprites.specialVariant(f, shiny: unlock.shinyUnlocked);
    final (t1, t2) = f.form == null ? SpeciesForms.types(f.species, iconForm) : _types(f);
    final refs = [...unlock.normal, ...unlock.shiny];
    final itemSources = unlock.withItem;
    return Container(
      key: ValueKey('dex-special-${f.key}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.raised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlock.shinyUnlocked ? tokens.shiny.withValues(alpha: 0.7) : (any ? context.colors.primary.withValues(alpha: 0.5) : tokens.hairline),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: tokens.sunken, borderRadius: BorderRadius.circular(16)),
            child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              DexIcon(
                  key: ValueKey('dex-special-icon-${f.key}-${ownIcon ? 'own' : 'base'}'),
                  species: f.species,
                  form: iconForm,
                  status: iconStatus,
                  size: 60,
                  sprite: ownIcon ? shown.ref : null),
              if (!any) Icon(Icons.lock_rounded, size: 20, color: tokens.muted),
              if (unlock.shinyUnlocked)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Icon(Icons.auto_awesome,
                      key: ValueKey('dex-special-shiny-badge-${f.key}${shown.shinyMissing ? '-fallback' : ''}'),
                      size: 16,
                      color: tokens.shiny),
                ),
              if (!ownIcon)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: f.kind == SpecialFormKind.gigantamax ? const GmaxBadge() : SpecialKindBadge(f.kind, compact: true),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SpecialKindBadge(f.kind),
              const SizedBox(height: 4),
              Text(specialFormName(context, f), maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
              if (f.form != null) ...[
                const SizedBox(height: 4),
                Wrap(spacing: 4, runSpacing: 4, children: [
                  TypeChip(t1, dense: true),
                  if (t2 != t1 && t2 != PokemonType.none) TypeChip(t2, dense: true),
                  if (_bst(f) case final bst?)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 1),
                      child: Text('${l10n.dexStatTotal} $bst',
                          style: context.text.labelMedium!.copyWith(color: tokens.muted, fontFeatures: const [FontFeature.tabularFigures()])),
                    ),
                ]),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _VariantPill(
                  label: l10n.dexNormal,
                  unlocked: unlock.normalUnlocked,
                  shiny: false,
                  keyName: '${f.key}-normal',
                  sprite: ownIcon ? normalIcon : null)),
          const SizedBox(width: 8),
          Expanded(
              child: _VariantPill(
                  label: l10n.dexShinyVariant,
                  unlocked: unlock.shinyUnlocked,
                  shiny: true,
                  keyName: '${f.key}-shiny',
                  sprite: shinyIcon)),
        ]),
        if (!unlock.normalUnlocked || !unlock.shinyUnlocked) ...[
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 16, color: tokens.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                unlock.normalUnlocked
                    ? l10n.dexHowShiny
                    : (unlock.shinyUnlocked ? specialFormHowTo(context, f) : '${specialFormHowTo(context, f)} ${l10n.dexHowShiny}'),
                style: context.text.bodySmall!.copyWith(color: tokens.muted),
              ),
            ),
          ]),
        ],
        if (refs.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in _distinctSources(refs))
              ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: r.specimen.shiny ? Icon(Icons.auto_awesome, size: 14, color: tokens.shiny) : null,
                label: Text(l10n.dexUnlockedBy(shortGame(context, dex.sources[r.source].game), dex.sources[r.source].trainer)),
                onPressed: () => context.go('/arca/save/${dex.sources[r.source].id}?box=${r.specimen.box}&slot=${r.specimen.slot}'),
              ),
          ]),
        ],
        if (f.item != 0 && refs.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(itemSources.isNotEmpty ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                size: 16, color: itemSources.isNotEmpty ? context.colors.primary : tokens.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                itemSources.isNotEmpty
                    ? l10n.dexItemInBag(
                        itemName(context, f.item),
                        [for (final i in itemSources) '${dex.sources[i].trainer} (${shortGame(context, dex.sources[i].game)})'].join(', '))
                    : l10n.dexItemMissing(itemName(context, f.item)),
                style: context.text.bodySmall,
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  /// Un ejemplar por partida y variante (para no repetir chips).
  static List<DexSpecimenRef> _distinctSources(List<DexSpecimenRef> refs) {
    final seen = <String>{};
    return [
      for (final r in refs)
        if (seen.add('${r.source}:${r.specimen.shiny}')) r,
    ];
  }

  static (PokemonType, PokemonType) _types(SpecialForm f) {
    final g = f.games.contains(GameVersion.legendsZA) ? GameVersion.legendsZA : f.games.last;
    return SpeciesForms.types(f.species, f.form!, SpeciesForms.isPresent(f.species, f.form!, g) ? g : null);
  }

  static int? _bst(SpecialForm f) {
    final g = f.games.contains(GameVersion.legendsZA) ? GameVersion.legendsZA : f.games.last;
    final p = SpeciesForms.personal(f.species, f.form!, SpeciesForms.isPresent(f.species, f.form!, g) ? g : null);
    return p?.baseStatTotal;
  }
}

class _VariantPill extends StatelessWidget {
  const _VariantPill({required this.label, required this.unlocked, required this.shiny, required this.keyName, this.sprite});
  final String label;
  final bool unlocked;
  final bool shiny;
  final String keyName;

  /// Icono propio de la forma en esta variante (el variocolor en la pastilla
  /// variocolor): se muestra en vez de la marca o el destello cuando la
  /// variante está desbloqueada.
  final SpriteRef? sprite;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = shiny ? tokens.shiny : context.colors.primary;
    return Semantics(
      label: '$label: ${unlocked ? '✓' : context.l10n.dexLocked}',
      child: Container(
        key: ValueKey('dex-variant-$keyName-${unlocked ? 'on' : 'off'}'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: unlocked ? color.withValues(alpha: 0.16) : tokens.sunken,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: unlocked ? color.withValues(alpha: 0.7) : tokens.hairline),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (unlocked && sprite != null)
            SpriteImage(
              key: ValueKey('dex-variant-icon-$keyName'),
              sprite: sprite,
              size: 22,
              fallback: Icon(shiny ? Icons.auto_awesome : Icons.check_rounded, size: 15, color: color),
            )
          else
            Icon(unlocked ? (shiny ? Icons.auto_awesome : Icons.check_rounded) : Icons.lock_outline_rounded,
                size: 15, color: unlocked ? color : tokens.muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              unlocked ? label : '$label · ${context.l10n.dexLocked}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium!.copyWith(color: unlocked ? null : tokens.muted),
            ),
          ),
        ]),
      ),
    );
  }
}
