import '../legal/ribbons.dart';
import '../pkm/pkm.dart';

/// Qué cambia en un Pokémon al transferirlo (para la vista previa).
class TransferDiff {
  TransferDiff._({
    required this.movesBefore,
    required this.movesAfter,
    required this.ballBefore,
    required this.ballAfter,
    required this.itemBefore,
    required this.itemAfter,
    required this.ribbonsKept,
    required this.ribbonsLost,
    required this.nicknameBefore,
    required this.nicknameAfter,
    required this.abilityBefore,
    required this.abilityAfter,
    required this.levelBefore,
    required this.levelAfter,
    required this.formBefore,
    required this.formAfter,
    required this.ivsChanged,
    required this.natureChanged,
  });

  /// Compara el Pokémon de origen [src] con el convertido [dst].
  factory TransferDiff.of(Pkm src, Pkm dst) {
    final lost = <String>[];
    var kept = 0;
    final dstKeys = {for (final r in Ribbons.forFormat(dst.format)) r.key};
    for (final r in Ribbons.forFormat(src.format)) {
      if (Ribbons.get(src, r.key) == 0) continue;
      // Los rangos de concurso de Gen 3/4 pasan a cintas sueltas o al recuerdo de concursos.
      if ((dstKeys.contains(r.key) && Ribbons.get(dst, r.key) != 0) || _contest(r.key)) {
        kept++;
      } else {
        lost.add(r.key);
      }
    }
    return TransferDiff._(
      movesBefore: src.moves,
      movesAfter: dst.moves,
      ballBefore: src.ball,
      ballAfter: dst.ball,
      itemBefore: src.heldItem,
      itemAfter: dst.heldItem,
      ribbonsKept: kept,
      ribbonsLost: lost,
      nicknameBefore: src.nickname,
      nicknameAfter: dst.nickname,
      abilityBefore: src.generation >= 3 ? src.ability : 0,
      abilityAfter: dst.generation >= 3 ? dst.ability : 0,
      levelBefore: src.level,
      levelAfter: dst.level,
      formBefore: src.form,
      formAfter: dst.form,
      ivsChanged: src.generation <= 2 && dst.generation >= 3,
      natureChanged: src.generation >= 3 && src.nature != dst.nature,
    );
  }

  static bool _contest(String key) =>
      key.startsWith('RibbonCountG3') || key.startsWith('RibbonG3') || key.startsWith('RibbonG4');

  final List<int> movesBefore, movesAfter;
  final int ballBefore, ballAfter, itemBefore, itemAfter;
  final int ribbonsKept;
  final List<String> ribbonsLost;
  final String nicknameBefore, nicknameAfter;
  final int abilityBefore, abilityAfter, levelBefore, levelAfter, formBefore, formAfter;

  /// Gen 1/2 → Gen 7: IV nuevos (3 perfectos) en lugar de los DV.
  final bool ivsChanged;
  final bool natureChanged;

  bool get movesChanged => !_same(movesBefore, movesAfter);
  bool get ballChanged => ballBefore != ballAfter && ballBefore != 0;
  bool get itemRemoved => itemBefore != 0 && itemAfter == 0;
  bool get itemChanged => itemBefore != 0 && itemAfter != 0 && itemBefore != itemAfter;
  bool get nicknameChanged => nicknameBefore != nicknameAfter;
  bool get abilityChanged => abilityBefore != 0 && abilityAfter != 0 && abilityBefore != abilityAfter;
  bool get levelChanged => levelBefore != levelAfter;
  bool get formChanged => formBefore != formAfter;

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
