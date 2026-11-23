import 'package:flutter/material.dart';
import 'package:pkcore/pkcore.dart';

import '../../theme/app_theme.dart';
import '../../theme/game_palette.dart';
import 'format.dart';

/// Muestra de color de una versión (o de una pareja partida en diagonal).
class VersionSwatch extends StatelessWidget {
  const VersionSwatch({super.key, required this.colors, this.size = 14});
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.tokens.hairline),
        gradient: colors.length == 1
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0, 0.5, 0.5, 1],
                colors: [colors[0], colors[0], colors[1], colors[1]],
              ),
        color: colors.length == 1 ? colors.first : null,
      ),
    );
  }
}

/// Chip del juego de origen de un Pokémon: color de su versión y nombre.
class VersionChip extends StatelessWidget {
  const VersionChip({super.key, required this.version, this.label});

  /// Id de PKHeX `GameVersion`.
  final int version;

  static Color colorOf(BuildContext context, int v) => VersionPalette.of(v) ?? context.tokens.muted;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = VersionPalette.of(version) ?? context.tokens.muted;
    final name = label ?? GameVersions.name(version, es: context.isSpanish);
    return Semantics(
      label: name,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: c.withValues(alpha: 0.55)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          VersionSwatch(colors: [c], size: 12),
          const SizedBox(width: 6),
          Flexible(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium!.copyWith(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

/// Diálogo para fijar a mano la versión concreta de una partida.
/// Devuelve `(true, id)` al aceptar (id null = sin especificar) o null al cancelar.
Future<(bool, int?)?> pickSlotVersion(BuildContext context, GameVersion game, int? current) {
  final options = GameVersions.ofGame[game]!;
  final l10n = context.l10n;
  return showDialog<(bool, int?)>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.versionPickTitle),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(l10n.versionPickBody, style: ctx.text.bodySmall!.copyWith(color: ctx.tokens.muted)),
        ),
        for (final v in options)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, (true, v)),
            child: Row(children: [
              VersionSwatch(colors: [VersionPalette.of(v)!], size: 18),
              const SizedBox(width: 12),
              Expanded(child: Text(GameVersions.name(v, es: ctx.isSpanish))),
              if (v == current) Icon(Icons.check_rounded, color: ctx.colors.primary),
            ]),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, (true, null)),
          child: Row(children: [
            VersionSwatch(colors: VersionPalette.forSave(game, null), size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.versionUnspecified)),
            if (current == null) Icon(Icons.check_rounded, color: ctx.colors.primary),
          ]),
        ),
      ],
    ),
  );
}
