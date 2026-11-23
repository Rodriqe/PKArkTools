import 'package:flutter/material.dart';

/// Logo de PKArkTools (escudo con alas, corona y cristales).
///
/// El PNG transparente lo genera `tool/gen_branding.py` a partir del logo del
/// owner (`assets/branding/`).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.semanticLabel = 'PKArkTools'});
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/branding/logo_256.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
      );
}
