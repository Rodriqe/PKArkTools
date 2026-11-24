import 'package:pkcore/pkcore.dart';

/// Dex de demostración: varias partidas sintéticas con Pokédex medio llenas,
/// ejemplares variocolor, factor Gigamax y piedras activadoras.
GlobalDex demoDex() {
  Set<int> range(int a, int b) => {for (var s = a; s <= b; s++) s};
  final swsh = SaveDexScan(
    game: GameVersion.swordShield,
    hasPokedex: true,
    seen: {...range(810, 898), ...range(1, 9), 25, 133, 143},
    caught: {...range(810, 870), 1, 4, 6, 25, 133},
    specimens: const [
      DexSpecimen(species: 6, level: 50, shiny: true, gigantamax: true, box: 0, slot: 3, nickname: 'Blaze'),
      DexSpecimen(species: 6, level: 47, gigantamax: true, box: 0, slot: 4),
      DexSpecimen(species: 25, level: 22, gigantamax: true, box: -1, slot: 0, ribbons: ['RibbonChampionGalar', 'RibbonEffort']),
      DexSpecimen(species: 133, level: 30, shiny: true, box: 1, slot: 0),
      DexSpecimen(species: 849, form: 1, level: 40, gigantamax: true, box: 1, slot: 1),
      DexSpecimen(species: 892, form: 1, level: 70, box: -1, slot: 1),
    ],
  );
  final xy = SaveDexScan(
    game: GameVersion.xy,
    hasPokedex: true,
    seen: range(1, 251),
    caught: {...range(1, 160), ...range(650, 721)},
    specimens: const [
      DexSpecimen(
          species: 6,
          level: 36,
          box: -1,
          slot: 0,
          heldItem: 660,
          ribbons: ['RibbonChampionKalos', 'RibbonTraining', 'RibbonBestFriends', 'RibbonEffort']),
      DexSpecimen(species: 448, level: 40, box: 0, slot: 2),
      DexSpecimen(species: 3, level: 32, shiny: true, box: 0, slot: 5),
    ],
    items: const {660, 673},
  );
  final oras = SaveDexScan(
    game: GameVersion.omegaRubyAlphaSapphire,
    hasPokedex: true,
    seen: range(252, 386),
    caught: range(252, 380),
    specimens: const [DexSpecimen(species: 382, level: 45, box: 3, slot: 0), DexSpecimen(species: 384, level: 70, box: 3, slot: 1)],
    items: const {535},
  );
  final sv = SaveDexScan(
    game: GameVersion.scarletViolet,
    hasPokedex: true,
    seen: {...range(906, 1025), ...range(387, 493)},
    caught: {...range(906, 1000), ...range(387, 420)},
    specimens: const [DexSpecimen(species: 1000, level: 66, shiny: true, box: 0, slot: 0)],
  );
  final za = SaveDexScan(
    game: GameVersion.legendsZA,
    hasPokedex: true,
    seen: {35, 36, 670, 678, 26},
    caught: {36, 26},
    specimens: const [DexSpecimen(species: 36, level: 40, shiny: true, box: 2, slot: 5), DexSpecimen(species: 26, level: 38, box: 2, slot: 6)],
  );
  return GlobalDex.build([
    DexSource(id: 1, game: GameVersion.swordShield, versionId: 44, trainer: 'Gloria', scan: swsh),
    DexSource(id: 2, game: GameVersion.xy, versionId: 24, trainer: 'Serena', scan: xy),
    DexSource(id: 3, game: GameVersion.omegaRubyAlphaSapphire, versionId: 26, trainer: 'May', scan: oras),
    DexSource(id: 4, game: GameVersion.scarletViolet, versionId: 50, trainer: 'Nemona', scan: sv),
    DexSource(id: 5, game: GameVersion.legendsZA, trainer: 'Urbain', scan: za),
  ]);
}

/// Charizard Gigamax normal y variocolor (Espada) y Charizard normal y
/// variocolor en Leyendas Z-A (Megas X/Y en sus dos variantes).
GlobalDex shinySpecialDex() => GlobalDex.build([
      DexSource(
        id: 1,
        game: GameVersion.swordShield,
        versionId: 44,
        trainer: 'Gloria',
        scan: SaveDexScan(game: GameVersion.swordShield, hasPokedex: true, seen: const {4, 5, 6}, caught: const {4, 5, 6}, specimens: const [
          DexSpecimen(species: 6, level: 50, shiny: true, gigantamax: true, box: 0, slot: 3, nickname: 'Blaze'),
          DexSpecimen(species: 6, level: 47, gigantamax: true, box: 0, slot: 4),
        ]),
      ),
      DexSource(
        id: 5,
        game: GameVersion.legendsZA,
        trainer: 'Urbain',
        scan: SaveDexScan(game: GameVersion.legendsZA, hasPokedex: true, seen: const {6}, caught: const {6}, specimens: const [
          DexSpecimen(species: 6, level: 55, shiny: true, box: 2, slot: 6, nickname: 'Ember'),
          DexSpecimen(species: 6, level: 38, box: 2, slot: 7),
        ]),
      ),
    ]);
