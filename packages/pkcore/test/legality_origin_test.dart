import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

Pkm _mon(GameVersion game, int species, {int level = 50}) {
  final raw = switch (game) {
    GameVersion.scarletViolet => SyntheticSaves.scarletViolet(party: [SynthMon(species, level: level)]),
    GameVersion.platinum => SyntheticSaves.gen4(party: [SynthMon(species, level: level)]),
    GameVersion.blackWhite => SyntheticSaves.gen5(party: [SynthMon(species, level: level)]),
    _ => SyntheticSaves.swordShield(party: [SynthMon(species, level: level)]),
  };
  return SaveEditor.open(raw).get(const SlotRef.party(0))!;
}

Set<LegalityCode> _codes(Pkm pk, GameVersion g) => {for (final i in Legality.check(pk, g)) i.code};

void _setVersion(Pkm pk, int v) {
  switch (pk.format) {
    case PkFormat.pk4 || PkFormat.pk5:
      pk.data[0x5F] = v;
    case PkFormat.pk8:
      pk.data[0xDE] = v;
    default:
      pk.data[0xCE] = v;
  }
}

void main() {
  test('origen: versión vacía y juego futuro', () {
    final pk = _mon(GameVersion.platinum, 25);
    _setVersion(pk, 0);
    expect(_codes(pk, GameVersion.platinum), contains(LegalityCode.originVersionMissing));
    _setVersion(pk, 20); // Blanco en un PK4
    expect(_codes(pk, GameVersion.platinum), contains(LegalityCode.originFromFuture));
  });

  test('ball posterior al origen se corrige a Poké Ball', () {
    final pk = _mon(GameVersion.swordShield, 25);
    _setVersion(pk, 12); // Platino
    pk.ball = 26; // Ente
    final issue = Legality.check(pk, GameVersion.swordShield).firstWhere((i) => i.code == LegalityCode.ballTooNew);
    expect(issue.fix, LegalityFix.ball);
    expect(issue.detail(), contains('Gen 7'));
    final fixed = Legality.applyFix(pk, issue, GameVersion.swordShield)!;
    expect(fixed.ball, 4);
    expect(_codes(fixed, GameVersion.swordShield), isNot(contains(LegalityCode.ballTooNew)));
  });

  test('balls de Hisui fuera de Leyendas Arceus', () {
    final pk = _mon(GameVersion.scarletViolet, 25)..ball = 30;
    expect(_codes(pk, GameVersion.scarletViolet), contains(LegalityCode.ballOnlyInLegends));
  });

  test('habilidad oculta con origen Gen 4 → primera habilidad', () {
    final pk = _mon(GameVersion.swordShield, 25);
    _setVersion(pk, 12);
    pk.setAbilitySlot(2);
    final issue =
        Legality.check(pk, GameVersion.swordShield).firstWhere((i) => i.code == LegalityCode.hiddenAbilityOldOrigin);
    final fixed = Legality.applyFix(pk, issue, GameVersion.swordShield)!;
    expect(fixed.abilitySlot, 0);
  });

  test('variocolor bloqueado: Zacian de Espada', () {
    final pk = _mon(GameVersion.swordShield, 888, level: 70);
    _setVersion(pk, 44);
    pk.setShiny(true);
    final issue = Legality.check(pk, GameVersion.swordShield).firstWhere((i) => i.code == LegalityCode.shinyLocked);
    final fixed = Legality.applyFix(pk, issue, GameVersion.swordShield)!;
    expect(fixed.isShiny, isFalse);
    expect(fixed.nature, pk.nature);
  });

  test('movimientos recordables dudosos y corrección', () {
    final pk = _mon(GameVersion.scarletViolet, 25);
    pk.setRelearnMove(0, 14); // Danza Espada
    final issue = Legality.check(pk, GameVersion.scarletViolet).firstWhere((i) => i.code == LegalityCode.relearnInvalid);
    expect(issue.area, LegalityArea.moves);
    final fixed = Legality.applyFix(pk, issue, GameVersion.scarletViolet)!;
    expect(fixed.relearnMoves, everyElement(0));
  });

  test('movimientos imposibles → últimos por nivel; EVs y PP', () {
    final pk = _mon(GameVersion.scarletViolet, 25);
    pk.setMove(0, 14, context: '9');
    pk.setEvs(const [252, 252, 252, 0, 0, 0]);
    var p = pk;
    for (final code in [LegalityCode.moveNotLearnable, LegalityCode.evTotalTooHigh]) {
      final issue = Legality.check(p, GameVersion.scarletViolet).firstWhere((i) => i.code == code);
      p = Legality.applyFix(p, issue, GameVersion.scarletViolet)!;
    }
    final c = _codes(p, GameVersion.scarletViolet);
    expect(c, isNot(contains(LegalityCode.moveNotLearnable)));
    expect(c, isNot(contains(LegalityCode.evTotalTooHigh)));
    expect(p.moves.where((m) => m != 0), isNotEmpty);
  });

  test('singular de evento sin marca (Gen 4)', () {
    final pk = _mon(GameVersion.platinum, 491); // Darkrai
    _setVersion(pk, 10); // Diamante (en Platino hay un estático sin marca de evento)
    expect(_codes(pk, GameVersion.platinum), contains(LegalityCode.eventSpeciesNotFateful));
    pk.data[0x40] |= 1;
    expect(_codes(pk, GameVersion.platinum), isNot(contains(LegalityCode.eventSpeciesNotFateful)));
  });

  test('todas las explicaciones tienen texto en ambos idiomas', () {
    for (final code in LegalityCode.values) {
      final i = LegalityIssue(code, LegalitySeverity.notice, args: const {'x': 1});
      expect(i.message(DataLanguage.es), isNotEmpty);
      expect(i.detail(DataLanguage.en), isNotEmpty);
    }
  });
}
