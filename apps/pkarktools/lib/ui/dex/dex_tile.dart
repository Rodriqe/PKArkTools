import 'package:flutter/material.dart';
import 'package:pkcore/pkcore.dart';

import '../../data/sprites/sprites.dart';
import '../../theme/app_theme.dart';
import '../../theme/game_palette.dart';
import '../common/sprite_image.dart';
import 'dex_text.dart';

/// Matriz de escala de grises (luminancia Rec. 709).
const List<double> _greyscale = [
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

/// Icono de la Dex: silueta (sin registrar), atenuado en gris (visto) o a
/// color (capturado). Los iconos se descargan bajo demanda como en el resto
/// de la app; sin icono se ve el número.
class DexIcon extends StatelessWidget {
  const DexIcon({super.key, required this.species, this.form = 0, required this.status, required this.size, this.label});

  final int species;
  final int form;
  final DexStatus status;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final sprite = Sprites.pokemon(species, form: form);
    final fallback = Text(
      status == DexStatus.unknown ? '?' : '$species',
      style: TextStyle(
        fontFamily: AppTheme.display,
        fontWeight: FontWeight.w800,
        fontSize: size * 0.28,
        color: tokens.muted.withValues(alpha: status == DexStatus.unknown ? 0.5 : 0.8),
      ),
    );
    Widget img = SpriteImage(sprite: sprite, size: size, fallback: fallback, semanticLabel: label);
    switch (status) {
      case DexStatus.unknown:
        img = ColorFiltered(
          colorFilter: ColorFilter.mode(tokens.muted.withValues(alpha: 0.32), BlendMode.srcIn),
          child: img,
        );
      case DexStatus.seen:
        img = Opacity(opacity: 0.55, child: ColorFiltered(colorFilter: const ColorFilter.matrix(_greyscale), child: img));
      case DexStatus.caught:
        break;
    }
    return SizedBox.square(dimension: size, child: Center(child: img));
  }
}

/// Casilla de la cuadrícula de la Dex.
class DexTile extends StatelessWidget {
  const DexTile({
    super.key,
    required this.entry,
    required this.status,
    required this.name,
    required this.onTap,
    this.shiny = false,
  });

  final SpeciesDex entry;
  final DexStatus status;
  final String name;
  final bool shiny;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final caught = status == DexStatus.caught;
    final (t1, _) = SpeciesForms.types(entry.species, 0);
    final tint = TypePalette.of(t1);
    return Semantics(
      button: true,
      label: '${dexNumber(entry.species)} $name',
      child: Material(
        color: caught ? Color.alphaBlend(tint.withValues(alpha: 0.10), tokens.raised) : tokens.raised.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: shiny ? tokens.shiny.withValues(alpha: 0.7) : tokens.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: LayoutBuilder(builder: (context, c) {
            final icon = c.maxWidth * 0.62;
            return Stack(children: [
              Positioned(
                left: 7,
                top: 5,
                child: Text(
                  '${entry.species}',
                  style: context.text.labelSmall!.copyWith(
                    color: tokens.muted,
                    fontSize: 10,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (shiny)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Icon(Icons.auto_awesome, size: 13, color: tokens.shiny, semanticLabel: '✦'),
                ),
              Positioned.fill(
                bottom: 16,
                top: 8,
                child: Center(
                  child: DexIcon(species: entry.species, status: status, size: icon),
                ),
              ),
              Positioned(
                left: 4,
                right: 4,
                bottom: 5,
                child: Text(
                  status == DexStatus.unknown ? '—' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall!.copyWith(
                    fontSize: 10.5,
                    color: caught ? null : tokens.muted,
                    fontWeight: caught ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

/// Chip de tipo elemental con su color.
class TypeChip extends StatelessWidget {
  const TypeChip(this.type, {super.key, this.dense = false});
  final PokemonType type;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = TypePalette.of(type);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(999)),
      child: Text(
        typeName(context, type),
        style: (dense ? context.text.labelSmall : context.text.labelMedium)!
            .copyWith(color: GamePalette.onAccent(c), fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Barra de progreso con etiqueta y cifras.
class DexBar extends StatelessWidget {
  const DexBar({super.key, required this.label, required this.value, required this.total, this.color, this.trailing});
  final String label;
  final int value;
  final int total;
  final Color? color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final frac = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelLarge)),
        const SizedBox(width: 8),
        Text(trailing ?? '$value / $total',
            style: context.text.labelMedium!.copyWith(color: tokens.muted, fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: frac,
          minHeight: 8,
          backgroundColor: tokens.sunken,
          color: color ?? context.colors.primary,
        ),
      ),
    ]);
  }
}
