// Ribbon Hunter con los juegos de sobremesa: los ejemplares que la Dex lee de
// saves de Colosseum/XD, Stadium, Box R&S, Battle Revolution y el Rancho se
// sitúan en el grafo de cintas, y la Cinta Nacional de un purificado cuenta.
import 'dart:typed_data';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

void main() {
  test('cada juego de sobremesa tiene su nodo en el grafo de Ribbon Hunter', () {
    expect(RibbonGame.fromGameVersion(GameVersion.colosseum), RibbonGame.colosseum);
    expect(RibbonGame.fromGameVersion(GameVersion.xd), RibbonGame.xd);
    expect(RibbonGame.fromGameVersion(GameVersion.boxRS), RibbonGame.rse);
    expect(RibbonGame.fromGameVersion(GameVersion.stadium), RibbonGame.vc);
    expect(RibbonGame.fromGameVersion(GameVersion.stadium2), RibbonGame.vc);
    expect(RibbonGame.fromGameVersion(GameVersion.battleRevolution), RibbonGame.dppt);
    expect(RibbonGame.fromGameVersion(GameVersion.ranch), RibbonGame.dppt);
    // El código persistente de Colosseum es el mismo id que usa el grafo.
    expect(GameVersion.colosseum.code, RibbonGame.colosseum.id);
    expect(GameVersion.xd.code, RibbonGame.xd.id);
    for (final g in GameVersion.values) {
      expect(RibbonGame.fromGameVersion(g), isNotNull, reason: g.name);
    }
  });

  group('XD: un Pokémon purificado', () {
    // Teddiursa es el primer Pokémon oscuro de XD; Poochyena, uno normal.
    final bytes = SyntheticSaves.memoryCard([
      (
        GcTitle.xd,
        SyntheticSaves.xd(
          party: const [SynthGcMon(216, level: 20, shadow: 2, nickname: 'TEDDY'), SynthGcMon(261, level: 12)],
          boxes: const {0: [SynthGcMon(216, level: 11, shadow: 1)]},
        ),
      ),
    ]);
    final scan = SaveDexScan.scan(bytes);
    final route = RibbonMaster.route(216, 0)!;

    test('la Dex lo lee con su Cinta Nacional', () {
      expect(scan.game, GameVersion.xd);
      final purified = scan.specimens.firstWhere((s) => s.species == 216 && s.inParty);
      expect(purified.ribbons, contains('RibbonNational'));
      final shadow = scan.specimens.firstWhere((s) => s.species == 216 && !s.inParty);
      expect(shadow.ribbons, isNot(contains('RibbonNational')));
    });

    test('Tus ejemplares: la Cinta Nacional cuenta como obtenida', () {
      final game = RibbonGame.fromGameVersion(scan.game)!;
      expect(route.steps.expand((s) => [...s.ribbons, ...s.alsoHere]).map((e) => e.key), contains('RibbonNational'));
      final purified = scan.specimens.firstWhere((s) => s.species == 216 && s.inParty);
      final missing = route.missingFor(purified.ribbons, game).map((e) => e.key);
      expect(missing, isNot(contains('RibbonNational')));
      expect(missing, isNotEmpty, reason: 'le quedan las cintas de Gen 3 en adelante');
      // Sin purificar aún le falta la Cinta Nacional.
      final shadow = scan.specimens.firstWhere((s) => s.species == 216 && !s.inParty);
      expect(route.missingFor(shadow.ribbons, game).map((e) => e.key), contains('RibbonNational'));
      expect(missing.length, route.missingFor(shadow.ribbons, game).length - 1);
    });

    test('la Dex reconoce al ejemplar normal de XD', () {
      expect(scan.specimens.where((s) => s.species == 261), hasLength(1));
    });
  });

  test('Colosseum: un purificado tiene la Cinta Nacional en la Dex', () {
    final bytes = SyntheticSaves.gci(
      SyntheticSaves.colosseum(party: const [SynthGcMon(296, level: 30, shadow: 2)]),
      GcTitle.colosseum,
    );
    final scan = SaveDexScan.scan(bytes);
    expect(scan.game, GameVersion.colosseum);
    final p = scan.specimens.single;
    expect(p.ribbons, contains('RibbonNational'));
    final route = RibbonMaster.route(296, 0)!;
    expect(route.missingFor(p.ribbons, RibbonGame.fromGameVersion(scan.game)!).map((e) => e.key),
        isNot(contains('RibbonNational')));
  });

  test('Box R&S, Stadium, Battle Revolution y el Rancho aparecen como ejemplares', () {
    final cases = <GameVersion, Uint8List>{
      GameVersion.boxRS: SyntheticSaves.gci(SyntheticSaves.rsBox(boxes: const {0: [SynthMon(280, level: 12)]}), GcTitle.rsBox),
      GameVersion.stadium: SyntheticSaves.stadium(boxes: const {0: [SynthMon(25, level: 20)]}),
      GameVersion.stadium2: SyntheticSaves.stadium(layout: StadiumLayout.stadium2U, boxes: const {0: [SynthMon(152, level: 30)]}),
      GameVersion.battleRevolution: SyntheticSaves.battleRevolution(boxes: const {0: [SynthMon(393, level: 10)]}),
      GameVersion.ranch: SyntheticSaves.ranch(mons: const [SynthMon(393, level: 5)]),
    };
    cases.forEach((game, bytes) {
      final scan = SaveDexScan.scan(bytes);
      expect(scan.game, game);
      expect(scan.specimens, isNotEmpty, reason: game.name);
      final s = scan.specimens.first;
      final from = RibbonGame.fromGameVersion(game)!;
      final route = RibbonMaster.route(s.species, s.form)!;
      // Desde su juego actual aún puede ir hacia adelante y ganar cintas.
      expect(route.missingFor(s.ribbons, from), isNotEmpty, reason: game.name);
    });
  });
}
