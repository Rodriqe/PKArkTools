import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

void main() {
  Pkm pikachu(GameVersion game) {
    final raw = switch (game) {
      GameVersion.scarletViolet => SyntheticSaves.scarletViolet(party: const [SynthMon(25, level: 30)]),
      GameVersion.emerald => SyntheticSaves.gen3(party: const [SynthMon(25, level: 30)]),
      _ => SyntheticSaves.swordShield(party: const [SynthMon(25, level: 30)]),
    };
    return SaveEditor.open(raw).get(const SlotRef.party(0))!;
  }

  Set<LegalityCode> codes(Pkm pk, GameVersion g) => {for (final i in Legality.check(pk, g)) i.code};

  test('Pokémon razonable sin avisos graves', () {
    final pk = pikachu(GameVersion.scarletViolet);
    pk.setMove(0, 84, context: '9'); // Impactrueno
    pk.setMove(1, 0);
    pk.ball = 4;
    final issues = Legality.check(pk, GameVersion.scarletViolet);
    expect(issues.where((i) => i.severity == LegalitySeverity.warning), isEmpty, reason: '$issues');
  });

  test('EVs por encima de 510 y por estadística', () {
    final pk = pikachu(GameVersion.scarletViolet)..setEvs(const [252, 252, 252, 0, 0, 0]);
    expect(codes(pk, GameVersion.scarletViolet), contains(LegalityCode.evTotalTooHigh));
    pk.setEv(0, 255);
    expect(codes(pk, GameVersion.scarletViolet), contains(LegalityCode.evOutOfRange));
  });

  test('movimiento imposible, inexistente y repetido', () {
    final pk = pikachu(GameVersion.scarletViolet);
    pk.setMove(0, 14, context: '9'); // Danza Espada: no la aprende Pikachu en SV
    pk.setMove(1, 84, context: '9');
    pk.setMove(2, 84, context: '9');
    final c = codes(pk, GameVersion.scarletViolet);
    expect(c, contains(LegalityCode.moveNotLearnable));
    expect(c, contains(LegalityCode.moveDuplicate));
    final dummied = [for (var m = 1; m < 900; m++) if (!MoveData.existsIn(m, '9')) m].first;
    pk.setMove(3, dummied, context: '9');
    expect(codes(pk, GameVersion.scarletViolet), contains(LegalityCode.moveNotInGame));
  });

  test('objeto que no existe en el juego', () {
    final pk = pikachu(GameVersion.emerald)..heldItem = 376 + 100;
    expect(codes(pk, GameVersion.emerald), contains(LegalityCode.itemNotInGame));
  });

  test('mensajes en español e inglés', () {
    final pk = pikachu(GameVersion.scarletViolet)..setEvs(const [252, 252, 252, 0, 0, 0]);
    final issue = Legality.check(pk, GameVersion.scarletViolet).firstWhere((i) => i.code == LegalityCode.evTotalTooHigh);
    expect(issue.message(), contains('756'));
    expect(issue.message(DataLanguage.en), contains('exceeds'));
  });

  group('datos de juego', () {
    test('stats base y habilidades por juego', () {
      final sv = GameDataTable.forGame(GameVersion.scarletViolet).entry(25)!;
      expect(sv.baseStats, [35, 55, 40, 50, 50, 90]);
      expect(GameStrings.ability(sv.abilities.first, DataLanguage.en), 'Static');
      final rb = GameDataTable.forGame(GameVersion.redBlue).entry(6)!;
      expect(rb.baseStats, [78, 84, 78, 85, 85, 100]); // Especial = 85
      final gen5 = GameDataTable.forGame(GameVersion.blackWhite).entry(25)!;
      expect(gen5.baseStats.last, 90);
    });

    test('formas con stats propias', () {
      final t = GameDataTable.forGame(GameVersion.scarletViolet);
      final alola = t.entry(26, 1)!; // Raichu de Alola
      final base = t.entry(26)!;
      expect(alola.baseStats, isNot(base.baseStats));
    });

    test('learnsets por nivel, huevo y MT', () {
      final sv = GameDataTable.forGame(GameVersion.scarletViolet);
      expect(sv.levelUpMoves(25).map((m) => m.move), contains(84));
      expect(sv.eggMoves(172), isNotEmpty); // Pichu
      expect(sv.machineMoves(25), contains(85)); // Rayo por MT
      final e = GameDataTable.forGame(GameVersion.emerald);
      expect(e.levelUpMoves(25).map((m) => m.move), contains(84));
    });

    test('nombres y PP', () {
      expect(GameStrings.move(85), 'Rayo');
      expect(GameStrings.move(85, DataLanguage.en), 'Thunderbolt');
      expect(GameStrings.item(1, 9), 'Master Ball');
      expect(GameStrings.nature(3), 'Firme');
      expect(MoveData.basePp(85, '9'), 15);
      expect(MoveData.maxPp(85, '9', 3), 24);
      expect(GameStrings.natureEffect(3), (1, 3)); // Firme: +Atq −AtqEsp
    });
  });
}
