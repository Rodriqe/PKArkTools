import 'package:flutter/material.dart';

/// Logo de PKArkTools (escudo con alas, corona y cristales).
///
/// El PNG transparente (recortado a su contenido, sin margen) lo genera
/// `tool/gen_branding.py` a partir del logo del owner (`assets/branding/`).
/// [size] es la altura del logo; el ancho sale de su proporción.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48, this.semanticLabel = 'PKArkTools'});
  final double size;
  final String? semanticLabel;

  /// Ancho / alto del contenido del logo (`logo_mark.png`, 375×512).
  static const aspect = 375 / 512;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/branding/logo_mark.png',
        width: size * aspect,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
      );
}
