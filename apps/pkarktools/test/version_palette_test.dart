import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkarktools/theme/game_palette.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('cada versión de cada juego tiene su color', () {
    for (final g in GameVersion.values) {
      for (final v in GameVersions.ofGame[g]!) {
        expect(VersionPalette.of(v), isNotNull, reason: '$g/$v');
      }
    }
  });

  test('versión exacta = un color; pareja = dos', () {
    expect(VersionPalette.forSave(GameVersion.goldSilver, null), hasLength(2));
    expect(VersionPalette.forSave(GameVersion.goldSilver, 39), [VersionPalette.of(39)]);
    expect(VersionPalette.forSave(GameVersion.redBlue, null), [VersionPalette.of(35), VersionPalette.of(37)]);
    expect(VersionPalette.forSave(GameVersion.redBlue, 36), [VersionPalette.of(36)]); // Verde (JP)
    expect(VersionPalette.forSave(GameVersion.crystal, null), [VersionPalette.of(41)]);
    expect(VersionPalette.forSave(GameVersion.rubySapphire, 1), [VersionPalette.of(1)]);
    // Un id de otra familia no cuenta como versión exacta.
    expect(VersionPalette.forSave(GameVersion.swordShield, 50), hasLength(2));
  });

  test('la tinta del título es legible sobre cada color y cada pareja', () {
    for (final g in GameVersion.values) {
      final sets = [
        VersionPalette.forSave(g, null),
        for (final v in GameVersions.ofGame[g]!) VersionPalette.forSave(g, v),
      ];
      for (final colors in sets) {
        final ink = VersionPalette.inkOn(colors);
        // Las parejas llevan un velo oscuro inferior bajo el título.
        final under = colors.length == 1
            ? colors
            : [for (final c in colors) Color.lerp(c, Colors.black, VersionPalette.pairScrim)!];
        final worst = under.map((c) => _contrast(ink, c)).reduce(math.min);
        // Texto grande (título del cartucho): WCAG AA pide 3:1.
        expect(worst, greaterThanOrEqualTo(3.0), reason: '$g $colors');
      }
    }
  });
}
