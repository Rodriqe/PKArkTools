import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pkcore/pkcore.dart';

import '../../theme/app_theme.dart';
import '../../theme/game_palette.dart';
import '../../data/sprites/sprites.dart';
import 'format.dart';
import 'sprite_image.dart';

/// Avatar de especie: tesela partida en diagonal con los colores de sus dos
/// tipos y, encima, el sprite del Pokémon descargado bajo demanda (no se
/// distribuye arte con copyright). Sin conexión o mientras carga se ven las
/// iniciales del nombre.
class SpeciesAvatar extends StatelessWidget {
  const SpeciesAvatar({
    super.key,
    required this.species,
    this.shiny = false,
    this.egg = false,
    this.size = 44,
    this.showNumber = false,
    this.form = 0,
    this.female = false,
    this.game,
  });

  final int form;

  /// Juego cuyos datos dan los tipos de la forma (null: el más reciente que la tenga).
  final GameVersion? game;

  /// Hembra (algunas especies tienen sprite propio).
  final bool female;

  final int species;
  final bool shiny;
  final bool egg;
  final double size;

  /// Muestra el número de Pokédex (solo en tamaños grandes).
  final bool showNumber;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // Tipos de la forma en el juego: Decidueye de Hisui es Planta/Lucha.
    final (t1, t2) = SpeciesForms.types(species, form, game);
    final c1 = TypePalette.of(t1);
    final c2 = t2 == PokemonType.none || t2 == t1 ? null : TypePalette.of(t2);
    final name = pokemonName(context, species, form, game);
    final initials = _initials(name);
    final radius = size * 0.3;
    final ink = GamePalette.onAccent(c2 == null ? c1 : Color.lerp(c1, c2, 0.35)!);

    final sprite = Sprites.pokemon(species, form: form, female: female, shiny: shiny, egg: egg);
    final tile = egg
        ? SpriteImage(
            sprite: sprite,
            size: size,
            fallback: CustomPaint(painter: _EggPainter(), size: Size.square(size)),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: CustomPaint(
              painter: _TilePainter(c1, c2),
              child: Center(
                child: SpriteImage(
                  sprite: sprite,
                  size: size,
                  fallback: Text(
                    initials,
                    style: TextStyle(
                      fontFamily: AppTheme.display,
                      fontWeight: FontWeight.w800,
                      fontVariations: const [FontVariation('wght', 800)],
                      fontSize: size * 0.36,
                      height: 1,
                      color: ink,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: ink == Colors.white ? 0.28 : 0.0),
                          blurRadius: size * 0.06,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

    return Semantics(
      label: egg ? context.l10n.egg : name,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(egg ? size : radius),
                  boxShadow: shiny ? [BoxShadow(color: tokens.shiny.withValues(alpha: 0.5), blurRadius: size * 0.3)] : null,
                ),
                child: tile,
              ),
            ),
            if (shiny && !egg)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(color: tokens.shiny, width: math.max(1.5, size * 0.035)),
                    ),
                  ),
                ),
              ),
            if (showNumber && size >= 72 && !egg)
              Positioned(
                left: size * 0.08,
                bottom: size * 0.08,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: size * 0.05, vertical: size * 0.015),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    '#${species.toString().padLeft(4, '0')}',
                    style: TextStyle(
                      fontFamily: AppTheme.body,
                      fontSize: size * 0.1,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.92),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            // Insignia de variocolor DENTRO de los límites del avatar: si sobresale,
            // cualquier padre que recorte (listas, AppBar, safe area) la corta.
            if (shiny)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  key: const ValueKey('shiny-badge'),
                  width: size * 0.36,
                  height: size * 0.36,
                  decoration: BoxDecoration(
                    color: tokens.shiny,
                    shape: BoxShape.circle,
                    border: Border.all(color: tokens.base, width: 2),
                  ),
                  child: Icon(Icons.auto_awesome, size: size * 0.21, color: const Color(0xFF3A2A00)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final clean = name.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9 ]'), ' ').trim();
    if (clean.isEmpty) return name.isEmpty ? '?' : name.characters.first;
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length > 1) return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
    final w = parts.first;
    return w.characters.first.toUpperCase() + (w.length > 1 ? w.characters.elementAt(1).toLowerCase() : '');
  }
}

/// Fondo de la tesela: tipo 1 con profundidad, tipo 2 en la esquina inferior
/// derecha (corte diagonal limpio) y un anillo tenue descentrado.
class _TilePainter extends CustomPainter {
  _TilePainter(this.c1, this.c2);
  final Color c1;
  final Color? c2;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(c1, Colors.white, 0.10)!, Color.lerp(c1, Colors.black, 0.18)!],
        ).createShader(r),
    );
    final second = c2;
    if (second != null) {
      final path = Path()
        ..moveTo(size.width, size.height * 0.38)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width * 0.38, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [second, Color.lerp(second, Colors.black, 0.2)!],
          ).createShader(r),
      );
    }
    // Anillo de textura, sale por la esquina superior derecha.
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.12),
      size.width * 0.42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.07
        ..color = Colors.white.withValues(alpha: 0.13),
    );
    // Brillo superior.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.45),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0)],
        ).createShader(r),
    );
  }

  @override
  bool shouldRepaint(_TilePainter old) => old.c1 != c1 || old.c2 != c2;
}

class _EggPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final egg = Rect.fromLTWH(w * 0.14, h * 0.06, w * 0.72, h * 0.88);
    canvas.drawOval(
      egg,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFBF6E9), Color(0xFFD9CFB4)],
        ).createShader(egg),
    );
    final spot = Paint()..color = const Color(0xFF8FBF8A);
    for (final (x, y, r) in const [(0.38, 0.32, 0.07), (0.62, 0.48, 0.09), (0.42, 0.68, 0.06), (0.6, 0.22, 0.04)]) {
      canvas.drawCircle(Offset(w * x, h * y), w * r, spot);
    }
  }

  @override
  bool shouldRepaint(_EggPainter old) => false;
}
