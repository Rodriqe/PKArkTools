import 'package:flutter/material.dart';
import 'package:pkcore/pkcore.dart';

import '../../theme/app_theme.dart';
import 'format.dart';

/// Marca de Pokémon oscuro (Colosseum / XD): solo lectura para la interfaz.
///
/// Usa el estado que ya lee pkcore (`GcExtra.isShadow` / `isPurified`, que en
/// XD sale de la tabla de oscuros del save). Fuera de Colosseum/XD no se marca
/// nada, aunque el Pokémon venga de allí.
abstract final class ShadowMark {
  /// Morado oscuro legible sobre fondo claro y su versión clara para el tema oscuro.
  static const _light = Color(0xFF6B3FA0);
  static const _dark = Color(0xFFB794E6);

  /// Verde de «purificado» (el mismo de la sección del editor).
  static const purifiedColor = Color(0xFF3E9E6F);

  static Color color(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  /// El Pokémon se marca como oscuro en [game]: solo en Colosseum/XD, y solo
  /// si sigue oscuro (un purificado no lleva marca).
  static bool applies(Pkm pk, GameVersion game) =>
      game.isColosseumOrXd && !pk.isEgg && (pk.gc?.isShadow ?? false);

  /// Fue oscuro y está purificado, en un save de Colosseum/XD.
  static bool purified(Pkm pk, GameVersion game) =>
      game.isColosseumOrXd && !pk.isEgg && (pk.gc?.isPurified ?? false);

  /// Máximo del medidor de corazón del id oscuro según las tablas del juego
  /// (null si el id no está en ellas).
  static int? maxGauge(GcExtra gc) {
    final enc = GcEncounter.byShadowId(gc.shadowId, xd: gc.kind == GcKind.xk3);
    return enc.isEmpty ? null : enc.first.gauge;
  }
}

/// Halo morado suave detrás del avatar de un Pokémon oscuro.
class ShadowAura extends StatelessWidget {
  const ShadowAura({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = ShadowMark.color(context);
    return IgnorePointer(
      child: Container(
        key: const ValueKey('shadow-aura'),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c.withValues(alpha: 0.42), c.withValues(alpha: 0.18), c.withValues(alpha: 0)], stops: const [0, 0.55, 1]),
        ),
      ),
    );
  }
}

/// Insignia redonda de Pokémon oscuro (huecos de caja y tarjetas del equipo).
/// Mantener pulsado o pasar el ratón muestra la explicación.
class ShadowBadge extends StatelessWidget {
  const ShadowBadge({super.key, this.size = 16});
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: context.l10n.shadowMarkTooltip,
        child: Container(
          key: const ValueKey('shadow-mark'),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: ShadowMark.color(context),
            shape: BoxShape.circle,
            border: Border.all(color: context.tokens.base, width: 2),
          ),
          child: Icon(Icons.heart_broken_rounded, size: size * 0.6,
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1030) : Colors.white),
        ),
      );
}

/// Chip «Pokémon oscuro» / «Purificado» de la cabecera del editor, con la
/// explicación al mantener pulsado o pasar el ratón.
class ShadowStateChip extends StatelessWidget {
  const ShadowStateChip({super.key, required this.purified});
  final bool purified;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = purified ? ShadowMark.purifiedColor : ShadowMark.color(context);
    return Tooltip(
      message: purified ? l10n.shadowPurifiedTooltip : l10n.shadowMarkTooltip,
      child: Container(
        key: ValueKey(purified ? 'shadow-purified-chip' : 'shadow-chip'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(purified ? Icons.favorite_rounded : Icons.heart_broken_rounded, size: 13, color: color),
          const SizedBox(width: 5),
          Text(purified ? l10n.shadowStatePurified : l10n.shadowMarkChip, style: context.text.labelMedium),
        ]),
      ),
    );
  }
}

/// Progreso de purificación (medidor de corazón) en la cabecera del editor.
/// El save guarda lo que queda del medidor; el máximo sale de las tablas.
class ShadowHeartProgress extends StatelessWidget {
  const ShadowHeartProgress({super.key, required this.gc});
  final GcExtra gc;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final max = ShadowMark.maxGauge(gc);
    final left = gc.purification;
    final muted = context.text.bodySmall!.copyWith(color: context.tokens.muted);
    if (max == null || max <= 0) {
      return Text(l10n.shadowHeartUnknown('$left'), key: const ValueKey('shadow-heart'), style: muted);
    }
    final done = 1 - left.clamp(0, max) / max;
    return SizedBox(
      key: const ValueKey('shadow-heart'),
      width: 260,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: done,
            minHeight: 6,
            color: ShadowMark.color(context),
            backgroundColor: ShadowMark.color(context).withValues(alpha: 0.18),
          ),
        ),
        const SizedBox(height: 4),
        Text(l10n.shadowHeartProgress('$max', '${(done * 100).round()}', '$left'), style: muted),
      ]),
    );
  }
}
