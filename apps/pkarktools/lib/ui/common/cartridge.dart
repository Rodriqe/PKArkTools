import 'package:flutter/material.dart';
import 'package:pkcore/pkcore.dart';

import '../../theme/app_theme.dart';
import '../../theme/game_palette.dart';
import 'format.dart';

/// Forma de "cartucho": esquinas redondeadas con la esquina superior derecha
/// biselada, como la muesca de un cartucho. Es el elemento de identidad del Arca.
class CartridgeBorder extends OutlinedBorder {
  const CartridgeBorder({this.radius = 20, this.notch = 28, super.side});

  final double radius;
  final double notch;

  Path _path(Rect r) {
    final rr = radius.clamp(0, r.shortestSide / 2).toDouble();
    final n = notch.clamp(0, r.shortestSide / 2).toDouble();
    return Path()
      ..moveTo(r.left + rr, r.top)
      ..lineTo(r.right - n, r.top)
      ..lineTo(r.right, r.top + n)
      ..lineTo(r.right, r.bottom - rr)
      ..arcToPoint(Offset(r.right - rr, r.bottom), radius: Radius.circular(rr))
      ..lineTo(r.left + rr, r.bottom)
      ..arcToPoint(Offset(r.left, r.bottom - rr), radius: Radius.circular(rr))
      ..lineTo(r.left, r.top + rr)
      ..arcToPoint(Offset(r.left + rr, r.top), radius: Radius.circular(rr))
      ..close();
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(_path(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) => CartridgeBorder(radius: radius * t, notch: notch * t, side: side.scale(t));

  @override
  CartridgeBorder copyWith({BorderSide? side}) => CartridgeBorder(radius: radius, notch: notch, side: side ?? this.side);
}

/// Fondo de la etiqueta de una versión: un color con profundidad, o la
/// pareja (p. ej. Oro/Plata) partida en diagonal.
LinearGradient versionGradient(List<Color> colors) {
  if (colors.length == 1) {
    final c = colors.first;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.lerp(c, Colors.white, 0.10)!, Color.lerp(c, Colors.black, 0.28)!],
    );
  }
  final a = colors[0], b = colors[1];
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: const [0, 0.47, 0.53, 1],
    colors: [
      Color.lerp(a, Colors.white, 0.08)!,
      Color.lerp(a, Colors.black, 0.12)!,
      Color.lerp(b, Colors.white, 0.05)!,
      Color.lerp(b, Colors.black, 0.22)!,
    ],
  );
}

/// Etiqueta del cartucho: color del juego, título y número de generación.
/// Se comparte (Hero) entre la tarjeta del Arca y el detalle de la partida.
class CartridgeLabel extends StatelessWidget {
  const CartridgeLabel({
    super.key,
    required this.game,
    this.versionId,
    this.height = 96,
    this.large = false,
  });

  final GameVersion game;
  final int? versionId;
  final double height;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = VersionPalette.forSave(game, versionId);
    final on = VersionPalette.inkOn(colors);
    final pair = colors.length > 1;
    final title = gameTitle(context, game, versionId);
    final titleStyle = (large ? context.text.displaySmall : context.text.headlineSmall)!.copyWith(color: on);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: height,
        decoration: BoxDecoration(gradient: versionGradient(colors)),
        child: Stack(
          children: [
            // Ranuras del cartucho: líneas en relieve que dan textura sin ruido.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 6,
              child: Row(
                children: List.generate(
                  14,
                  (i) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      color: on.withValues(alpha: i.isEven ? 0.10 : 0.05),
                    ),
                  ),
                ),
              ),
            ),
            if (pair)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.15, 1],
                      colors: [Colors.black.withValues(alpha: 0), Colors.black.withValues(alpha: VersionPalette.pairScrim)],
                    ),
                  ),
                ),
              ),
            Positioned(
              right: large ? 28 : 18,
              bottom: large ? -22 : -16,
              child: Text(
                '${game.generation}',
                style: TextStyle(
                  fontFamily: AppTheme.display,
                  fontSize: large ? height * 1.15 : height * 1.05,
                  fontWeight: FontWeight.w800,
                  fontVariations: const [FontVariation('wght', 800)],
                  height: 1,
                  color: on.withValues(alpha: 0.14),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(large ? 28 : 18, large ? 26 : 18, large ? 120 : 64, large ? 20 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(title,
                        maxLines: large ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: pair
                            ? titleStyle.copyWith(shadows: [
                                Shadow(color: (on == Colors.white ? Colors.black : Colors.white).withValues(alpha: 0.35), blurRadius: 6),
                              ])
                            : titleStyle)),
                  const SizedBox(height: 4),
                  Text(
                    '${platformName(context, game.platform)}  ${context.l10n.genLabel(game.generation)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium!.copyWith(color: on.withValues(alpha: 0.78)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
