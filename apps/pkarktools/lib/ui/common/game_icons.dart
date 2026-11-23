import 'package:flutter/material.dart';
import 'package:pkcore/pkcore.dart';

import '../../data/sprites/sprites.dart';
import '../../theme/app_theme.dart';
import '../../theme/game_palette.dart';
import 'sprite_image.dart';

/// Icono de Poké Ball (sprite o, sin conexión, una bola de dos colores).
class BallIcon extends StatelessWidget {
  const BallIcon({super.key, required this.ball, this.size = 22});
  final int ball;
  final double size;

  @override
  Widget build(BuildContext context) => SpriteImage(
        sprite: Sprites.ball(ball),
        size: size,
        fallback: CustomPaint(size: Size.square(size), painter: _BallPainter(_ballColor(ball))),
      );

  /// Color aproximado de la mitad superior de cada Ball (para el respaldo).
  static Color _ballColor(int b) => switch (b) {
        1 => const Color(0xFF7B3FB5), // Master
        2 => const Color(0xFF3A6FD8), // Super
        3 => const Color(0xFF2B2B2B), // Ultra
        4 || 28 => const Color(0xFFE3350D), // Poké
        5 => const Color(0xFF6E9E4A), // Safari
        6 => const Color(0xFF2F7FC1), // Malla
        7 => const Color(0xFF2E9CC9), // Buceo
        8 => const Color(0xFFD8B33A), // Nido
        9 => const Color(0xFFD13A3A), // Acopio
        10 => const Color(0xFFE88A2A), // Turno
        11 => const Color(0xFF3B7A4A), // Lujo
        12 => const Color(0xFFD8D8D8), // Honor
        16 => const Color(0xFFB0203A), // Gloria
        25 => const Color(0xFFE08BB8), // Ensueño
        26 => const Color(0xFF2B4FA8), // Ente
        _ => const Color(0xFF8A90A6),
      };
}

class _BallPainter extends CustomPainter {
  _BallPainter(this.top);
  final Color top;
  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width * 0.42;
    final c = s.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(rect, 3.14159, 3.14159, true, Paint()..color = top);
    canvas.drawArc(rect, 0, 3.14159, true, Paint()..color = const Color(0xFFF4F4F4));
    final line = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.08;
    canvas.drawCircle(c, r, line);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), line);
    canvas.drawCircle(c, r * 0.28, Paint()..color = const Color(0xFFF4F4F4));
    canvas.drawCircle(c, r * 0.28, line);
  }

  @override
  bool shouldRepaint(_BallPainter old) => old.top != top;
}

/// Icono de objeto (con la numeración de su generación).
class ItemIcon extends StatelessWidget {
  const ItemIcon({super.key, required this.item, this.generation = 9, this.size = 24});
  final int item;
  final int generation;
  final double size;

  @override
  Widget build(BuildContext context) => SpriteImage(
        sprite: Sprites.item(item, generation: generation),
        size: size,
        fallback: Icon(Icons.inventory_2_outlined, size: size * 0.8, color: context.tokens.muted),
      );
}

/// Icono de tipo elemental (sprite o un círculo de su color).
class TypeIcon extends StatelessWidget {
  const TypeIcon({super.key, required this.type, this.size = 16});
  final PokemonType type;
  final double size;

  @override
  Widget build(BuildContext context) => SpriteImage(
        sprite: Sprites.type(type),
        size: size,
        pixelated: false,
        fallback: Container(
          width: size * 0.7,
          height: size * 0.7,
          decoration: BoxDecoration(color: TypePalette.of(type), shape: BoxShape.circle),
        ),
      );
}

/// Icono de cinta o marca (sprite o una roseta del color de su categoría).
class RibbonIcon extends StatelessWidget {
  const RibbonIcon({super.key, required this.ribbon, this.size = 32, this.dim = false});
  final RibbonInfo ribbon;
  final double size;
  final bool dim;

  static Color colorOf(RibbonCategory c) => switch (c) {
        RibbonCategory.contest => const Color(0xFFE07AB0),
        RibbonCategory.battle => const Color(0xFFE0A33A),
        RibbonCategory.commemorative => const Color(0xFF5FB8E0),
        RibbonCategory.event => const Color(0xFF9B7BE0),
        RibbonCategory.mark => const Color(0xFF6FC28A),
      };

  @override
  Widget build(BuildContext context) {
    final w = SpriteImage(
      sprite: Sprites.ribbon(ribbon.key),
      size: size,
      pixelated: false,
      fallback: Icon(ribbon.category == RibbonCategory.mark ? Icons.verified_outlined : Icons.military_tech_rounded,
          size: size * 0.85, color: colorOf(ribbon.category)),
    );
    return dim ? Opacity(opacity: 0.28, child: ColorFiltered(colorFilter: const ColorFilter.matrix(_grey), child: w)) : w;
  }

  static const List<double> _grey = [
    0.33, 0.33, 0.33, 0, 0, //
    0.33, 0.33, 0.33, 0, 0,
    0.33, 0.33, 0.33, 0, 0,
    0, 0, 0, 1, 0,
  ];
}
