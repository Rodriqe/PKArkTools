import 'package:flutter/widgets.dart';
import 'package:pkcore/pkcore.dart';

import '../common/format.dart';

/// Textos de la Dex que dependen de datos (regiones, formas especiales,
/// métodos de evolución). Todo sale de tablas objetivas: nunca descripciones
/// de la Pokédex.
extension DexTextX on BuildContext {
  DataLanguage get dexLang => isSpanish ? DataLanguage.es : DataLanguage.en;
}

String regionName(BuildContext context, DexRegion r) => switch (r) {
      DexRegion.kanto => 'Kanto',
      DexRegion.johto => 'Johto',
      DexRegion.hoenn => 'Hoenn',
      DexRegion.sinnoh => 'Sinnoh',
      DexRegion.unova => context.isSpanish ? 'Teselia' : 'Unova',
      DexRegion.kalos => 'Kalos',
      DexRegion.alola => 'Alola',
      DexRegion.galar => 'Galar',
      DexRegion.paldea => 'Paldea',
    };

String genRegionLabel(BuildContext context, int gen) =>
    context.l10n.dexGenRegion('$gen', regionName(context, DexRegion.ofGeneration(gen)));

String typeName(BuildContext context, PokemonType t) => GameStrings.type(t.index - 1, context.dexLang);

/// Nombre corto de un juego (familia) para listas: «X / Y», «Espada / Escudo».
String shortGame(BuildContext context, GameVersion g) {
  final n = context.isSpanish ? g.nameEs : g.nameEn;
  return n.replaceFirst(RegExp(r'^Pokémon '), '');
}

/// Nombre visible de una forma especial: «Charizard (Mega X)», «Toxtricity (Grave) · Gigamax».
String specialFormName(BuildContext context, SpecialForm f) {
  if (f.kind == SpecialFormKind.gigantamax) {
    final base = f.baseForms != null && f.baseForms!.length == 1 && f.baseForms!.first > 0
        ? pokemonName(context, f.species, f.baseForms!.first, GameVersion.swordShield)
        : speciesName(context, f.species);
    final variant = f.variant.isNotEmpty && f.baseForms?.first == 0 && f.species != 25 && f.species != 52
        ? SpeciesForms.formName(f.species, 0, GameVersion.swordShield, context.dexLang)
        : '';
    final label = variant.isEmpty ? base : '$base ($variant)';
    return '$label · ${context.l10n.dexGigantamax}';
  }
  return pokemonName(context, f.species, f.form!, f.games.last);
}

/// Forma con la que se dibuja el icono de una forma especial.
int specialFormIconForm(SpecialForm f) => f.form ?? (f.baseForms?.first ?? 0);

/// Cómo se desbloquea una forma especial.
String specialFormHowTo(BuildContext context, SpecialForm f) {
  final l10n = context.l10n;
  final games = [for (final g in GameVersion.values) if (f.games.contains(g)) shortGame(context, g)].join(', ');
  switch (f.kind) {
    case SpecialFormKind.gigantamax:
      final base = f.baseForms != null && f.baseForms!.length == 1
          ? pokemonName(context, f.species, f.baseForms!.first, GameVersion.swordShield)
          : speciesName(context, f.species);
      return l10n.dexHowGmax(base);
    case SpecialFormKind.ultraBurst:
      return l10n.dexHowUltra;
    case SpecialFormKind.mega || SpecialFormKind.primal:
      if (f.baseForms != null && f.baseForms!.length == 1) {
        final g = f.games.last;
        final formName = SpeciesForms.formName(f.species, f.baseForms!.first, g, context.dexLang);
        if (formName.isNotEmpty) return l10n.dexHowMegaForm(formName, games, speciesName(context, f.species));
      }
      return l10n.dexHowMega(games, speciesName(context, f.species));
  }
}

String itemName(BuildContext context, int item) => GameStrings.item(item, 9, context.dexLang);

/// Texto del método de una evolución.
String evolutionText(BuildContext context, EvolutionStep s) {
  final l10n = context.l10n;
  final lang = context.dexLang;
  String lv() => s.level > 0 ? l10n.dexEvoLevel('${s.level}') : l10n.dexEvoLevelUp;
  String item() => itemName(context, s.argument);
  return switch (s.kind) {
    EvolutionKind.level => lv(),
    EvolutionKind.friendship => l10n.dexEvoFriendship,
    EvolutionKind.friendshipDay => l10n.dexEvoFriendshipDay,
    EvolutionKind.friendshipNight => l10n.dexEvoFriendshipNight,
    EvolutionKind.trade => l10n.dexEvoTrade,
    EvolutionKind.tradeItem => l10n.dexEvoTradeItem(item()),
    EvolutionKind.tradeWith => l10n.dexEvoTradeWith(speciesName(context, s.species == 588 ? 616 : 588)),
    EvolutionKind.item => item(),
    EvolutionKind.itemMale => l10n.dexEvoItemMale(item()),
    EvolutionKind.itemFemale => l10n.dexEvoItemFemale(item()),
    EvolutionKind.levelMale => l10n.dexEvoLevelMale(lv()),
    EvolutionKind.levelFemale => l10n.dexEvoLevelFemale(lv()),
    EvolutionKind.levelDay => l10n.dexEvoDay(lv()),
    EvolutionKind.levelNight => l10n.dexEvoNight(lv()),
    EvolutionKind.levelDusk => l10n.dexEvoDusk(lv()),
    EvolutionKind.heldItemDay => l10n.dexEvoHeldDay(item()),
    EvolutionKind.heldItemNight => l10n.dexEvoHeldNight(item()),
    EvolutionKind.knowMove => l10n.dexEvoKnowMove(GameStrings.move(s.argument, lang)),
    EvolutionKind.moveType => l10n.dexEvoMoveType(GameStrings.type(s.argument, lang)),
    EvolutionKind.teammate => l10n.dexEvoTeammate(speciesName(context, s.argument)),
    EvolutionKind.location => l10n.dexEvoLocation,
    EvolutionKind.stats => l10n.dexEvoStats(lv()),
    EvolutionKind.random => l10n.dexEvoRandom(lv()),
    EvolutionKind.other => l10n.dexEvoOther,
  };
}

String dexNumber(int species) => '#${species.toString().padLeft(4, '0')}';
