import '../data/game_data.dart';
import '../model/game.dart';
import '../pkm/pkm.dart';
import 'encounters.dart';

/// Flags de movimientos «plus» de Leyendas Z-A (PA9), como PKHeX
/// (`LegendsZAVerifier.CheckFlagsPlus` y `PlusRecordApplicator`).
///
/// * **Obligatorias**: cada movimiento del learnset «plus» de la especie y forma
///   (`plus_za.pkl`) cuyo nivel sea ≤ el nivel actual; el juego las marca solo
///   al subir de nivel. Sin ellas PKHeX avisa `PlusMoveSufficientLevelMissing`.
///   Rotom y Hoopa con forma distinta de 0 también llevan las de la forma 0.
/// * **Permitidas**: las de movimientos que la especie o sus preevoluciones
///   aprenden en Z-A por MT o por nivel ≤ el actual (Semilla de Maestría) y, en
///   un alfa, su movimiento alfa. Las demás (o índices fuera de la tabla) son
///   ilegales (`PlusMoveInvalid`, `PlusMoveCountInvalid`).
abstract final class PlusMoves {
  static GameDataTable get _za => GameDataTable.forGame(GameVersion.legendsZA);

  static bool _formChangesMoves(int species) => species == 479 || species == 720; // Rotom, Hoopa

  /// Índices de flag que deben estar puestos en [pk] por su nivel y learnset.
  static Set<int> requiredIndexes(Pkm pk) {
    if (!pk.hasPlusFlags || pk.isEgg) return const {};
    final t = _za;
    final idx = GameDataTable.zaPlusMoves;
    final level = pk.level;
    final out = <int>{};
    void add(int form) {
      for (final lm in t.plusLevelMoves(pk.species, form)) {
        if (lm.level > level) continue; // sin `break`: Spewpa tiene niveles irregulares
        final i = idx.indexOf(lm.move);
        if (i >= 0) out.add(i);
      }
    }

    add(pk.form);
    if (pk.form != 0 && _formChangesMoves(pk.species)) add(0);
    return out;
  }

  /// Movimientos cuya flag «plus» puede estar puesta legalmente en [pk].
  static Set<int> permittedMoves(Pkm pk) {
    if (!pk.hasPlusFlags) return const {};
    final t = _za;
    final level = pk.level;
    final out = <int>{};
    for (final s in EncounterTables.evolutionChain(pk.species)) {
      final forms = <int>{
        if (s == pk.species && _formChangesMoves(s)) ...List.generate(t.entry(s)?.formCount ?? 1, (f) => f),
        if (s == pk.species) pk.form else ...{0, pk.form},
      };
      for (final f in forms) {
        out.addAll(t.machineMoves(s, f));
        for (final lm in t.levelUpMoves(s, f)) {
          if (lm.level <= level) out.add(lm.move);
        }
        if (pk.isAlpha) out.add(t.alphaMove(s, f));
      }
    }
    out.remove(0);
    return out;
  }

  /// Índices obligatorios que faltan.
  static List<int> missingIndexes(Pkm pk) =>
      [for (final i in requiredIndexes(pk).toList()..sort()) if (!pk.plusFlag(i)) i];

  /// Índices puestos que no pueden estarlo.
  static List<int> invalidIndexes(Pkm pk) {
    if (!pk.hasPlusFlags) return const [];
    final idx = GameDataTable.zaPlusMoves;
    final permitted = permittedMoves(pk);
    return [
      for (var i = 0; i < Pkm.plusFlagCount; i++)
        if (pk.plusFlag(i) && (i >= idx.length || !permitted.contains(idx[i]))) i,
    ];
  }

  /// Deja las flags coherentes con el nivel y los learnsets: pone las
  /// obligatorias y quita las imposibles; conserva las demás (Semilla de
  /// Maestría, MT, alfa). No hace nada fuera de PA9.
  static void sync(Pkm pk) {
    if (!pk.hasPlusFlags) return;
    for (final i in invalidIndexes(pk)) {
      pk.setPlusFlag(i, false);
    }
    for (final i in requiredIndexes(pk)) {
      pk.setPlusFlag(i, true);
    }
  }

  /// Movimiento del índice de flag [index] (0 si no existe).
  static int moveAt(int index) {
    final idx = GameDataTable.zaPlusMoves;
    return index >= 0 && index < idx.length ? idx[index] : 0;
  }
}
