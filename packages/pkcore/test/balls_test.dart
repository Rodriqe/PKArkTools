import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:test/test.dart';

void main() {
  group('BallTables', () {
    test('Leyendas Arceus muestra las Balls de Hisui y no las modernas', () {
      final la = BallTables.forGame(GameVersion.legendsArceus);
      for (var b = 28; b <= 37; b++) {
        expect(la, contains(b), reason: 'Ball de Hisui $b');
      }
      expect(la, isNot(contains(4)));
      expect(la, isNot(contains(26)));
      expect(BallTables.defaultFor(GameVersion.legendsArceus), 28);
    });

    test('cada juego solo muestra sus Balls', () {
      expect(BallTables.forGame(GameVersion.emerald), hasLength(12));
      expect(BallTables.forGame(GameVersion.platinum), isNot(contains(17)));
      expect(BallTables.forGame(GameVersion.heartGoldSoulSilver), contains(17));
      expect(BallTables.forGame(GameVersion.blackWhite), contains(25));
      expect(BallTables.forGame(GameVersion.xy), isNot(contains(26)));
      expect(BallTables.forGame(GameVersion.sunMoon), contains(26));
      expect(BallTables.forGame(GameVersion.letsGo), unorderedEquals([1, 2, 3, 4, 12, 16]));
      expect(BallTables.forGame(GameVersion.swordShield), isNot(contains(28)));
      expect(BallTables.forGame(GameVersion.scarletViolet), containsAll([27, 28, 37]));
      for (final g in GameVersion.values.where((g) => g.generation >= 3)) {
        final list = BallTables.forGame(g);
        expect(list.toSet(), hasLength(list.length), reason: '$g sin duplicados');
        expect(list.every((b) => b >= 1 && b <= 37), isTrue);
      }
    });

    test('todas las Balls tienen nombre (incluidas las de Hisui)', () {
      final names = <String>{};
      for (var b = 1; b <= 37; b++) {
        final item = OriginGames.ballItem(b);
        expect(item, greaterThan(0), reason: 'ball $b');
        final n = BallTables.name(b, DataLanguage.en);
        expect(n, isNotEmpty);
        names.add(n);
      }
      expect(names.length, 37, reason: 'nombres distintos');
      expect(BallTables.name(37, DataLanguage.en), contains('Origin'));
      expect(BallTables.name(28), contains('Hisui'));
    });

    test('el selector conserva una Ball de otro juego en lugar de cambiarla', () {
      final opts = BallTables.pickerOptions(GameVersion.swordShield, 30);
      expect(opts.last, 30);
      expect(BallTables.pickerOptions(GameVersion.legendsArceus, 29), isNot(contains(4)));
    });

    test('legalidad: Ball de Hisui en Espada/Escudo se avisa y se corrige', () {
      final pk = Pkm.fromDecrypted(PkFormat.pk8, Uint8List(PkFormat.pk8.partySize))
        ..species = 25
        ..version = 44
        ..metLevel = 5
        ..exp = Species.expForLevel(25, 5)
        ..ball = 30;
      pk.dataGame = GameVersion.swordShield;
      final issues = Legality.check(pk, GameVersion.swordShield);
      final ball = issues.where((i) => i.code == LegalityCode.ballInvalid).toList();
      expect(ball, isNotEmpty);
      expect(ball.first.fix, LegalityFix.ball);
      final fixed = Legality.applyFix(pk, ball.first, GameVersion.swordShield)!;
      expect(fixed.ball, 4);
    });
  });
}
