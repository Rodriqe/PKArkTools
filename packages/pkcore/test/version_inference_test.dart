import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

void main() {
  test('Rubí/Zafiro: la versión se deduce de los Pokémon del entrenador', () {
    final raw = SyntheticSaves.gen3(
        game: GameVersion.rubySapphire, party: const [SynthMon(25, level: 20), SynthMon(258, level: 12), SynthMon(263)]);
    final ed = SaveEditor.open(raw);
    for (var i = 0; i < 3; i++) {
      final pk = ed.get(SlotRef.party(i))!
        ..otName = 'MAY'
        ..version = i == 2 ? 1 : 2; // dos de Rubí, uno de Zafiro
      pk.refreshChecksum();
      ed.set(SlotRef.party(i), pk);
    }
    final out = ed.build();
    final save = SaveDetector.read(out);
    expect(save.versionId, isNull);
    expect(GameVersions.infer(out, save), 2);
    expect(save.withVersion(2).titleEs, 'Pokémon Rubí / Zafiro'); // el título de Gen 3 sigue siendo el de la familia
  });

  test('sin Pokémon propios o con empate no se deduce nada', () {
    final raw = SyntheticSaves.gen3(game: GameVersion.rubySapphire);
    expect(GameVersions.infer(raw, SaveDetector.read(raw)), isNull);
  });

  test('versión exacta y parejas', () {
    expect(GameVersions.exact(GameVersion.crystal, null), 41);
    expect(GameVersions.exact(GameVersion.goldSilver, null), isNull);
    expect(GameVersions.exact(GameVersion.heartGoldSoulSilver, 8), 8);
    expect(GameVersions.pair(GameVersion.redBlue), [35, 37]);
    for (final g in GameVersion.values) {
      expect(GameVersions.ofGame[g], isNotEmpty, reason: '$g');
    }
  });
}
