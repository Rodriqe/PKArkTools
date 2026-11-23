import '../data/forms.dart';
import '../model/game.dart';
import 'special_forms.dart';

/// Formas «coleccionables» de cada especie para la Dex global: las que un
/// Pokémon puede tener en una caja (regionales, Rotom, Unown, Vivillon…).
///
/// Se excluyen las formas de combate (PKHeX `FormInfo.IsBattleOnlyForm`:
/// Megas, Primigenio, Darmanitan Daruma, Aegislash filo…), que la Dex trata
/// como [SpecialForms] cuando hay una regla de desbloqueo, y las formas Dominante
/// (Gen 7) y Señorial (Leyendas Arceus), que no son formas de la especie.
abstract final class DexForms {
  /// PKHeX `FormInfo.BattleForms` (especies con formas solo de combate).
  static const Set<int> _battleFormSpecies = {
    351, 382, 383, 421, 555, 648, 658, 681, 716, 718, 746, 774, 778, 800, //
    845, 877, 875, 888, 889, 890, 964, 1017, 1024,
  };

  /// PKHeX `FormInfo.IsBattleForm` para las especies de [_battleFormSpecies].
  static bool _isBattleForm(int species, int form) => switch (species) {
        555 => form & 1 == 1, // Darmanitan Daruma
        658 => form == 2 || form == 3, // Greninja Ash (y Mega)
        718 => form == 4 || form == 5, // Zygarde completo (y Mega)
        774 => form < 7, // Minior Escudo
        778 => form & 1 == 1, // Mimikyu descubierto
        800 => form == 3, // Ultra Necrozma
        1017 => form >= 4, // Ogerpon Teracristal
        _ => form != 0,
      };

  /// PKHeX `FormInfo.HasTotemForm`/`IsTotemForm`.
  static bool _isTotem(int species, int form) {
    if (form == 0) return false;
    return switch (species) {
      778 => form == 2 || form == 3,
      20 || 105 => form == 2,
      735 || 738 || 743 || 752 || 754 || 758 || 784 || 777 => form == 1,
      _ => false,
    };
  }

  /// PKHeX `FormInfo.IsLordForm`.
  static bool _isLord(int species, int form) => switch (species) {
        59 || 101 || 549 || 713 => form == 2,
        900 => form == 1,
        _ => false,
      };

  /// `true` si la forma no se puede tener fuera de combate (o es especial).
  static bool isBattleOnly(int species, int form) {
    if (form <= 0) return false;
    if (SpecialForms.isSpecialForm(species, form)) return true;
    return _battleFormSpecies.contains(species) && _isBattleForm(species, form);
  }

  /// `true` si la forma cuenta como forma coleccionable de la Dex.
  static bool isCollectable(int species, int form) =>
      !isBattleOnly(species, form) && !_isTotem(species, form) && !_isLord(species, form);

  static final Map<int, List<int>> _cache = {};

  /// Formas coleccionables de [species] presentes en algún juego, ordenadas
  /// (siempre incluye la 0).
  static List<int> collectable(int species) => _cache.putIfAbsent(species, () {
        final set = <int>{0};
        for (final g in GameVersion.values) {
          for (final f in SpeciesForms.presentForms(species, g)) {
            if (isCollectable(species, f)) set.add(f);
          }
        }
        return List.unmodifiable(set.toList()..sort());
      });

  /// Juego en el que se muestran nombre y datos de una forma: el más reciente
  /// en el que existe.
  static GameVersion? displayGame(int species, int form) => SpeciesForms.resolveGame(species, form);
}
