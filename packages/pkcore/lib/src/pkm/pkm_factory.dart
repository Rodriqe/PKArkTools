import 'dart:math';
import 'dart:typed_data';

import '../data/forms.dart';
import '../data/game_data.dart';
import '../data/species.dart';
import '../edit/save_editor.dart';
import '../legal/origin.dart';
import '../legal/plus_moves.dart';
import '../legal/ribbons.dart';
import '../model/game.dart';
import 'pk_format.dart';
import 'pkm.dart';

/// Crea Pokémon nuevos coherentes con el juego y el entrenador del save.
abstract final class PkmFactory {
  /// Pokémon "recién capturado": OT/TID/SID del entrenador, Poké Ball,
  /// movimientos de su learnset al [level] y estadísticas calculadas.
  ///
  /// El origen queda coherente con el juego (como PKHeX `EntityTemplates`):
  /// versión de origen [versionId] (o la primera del juego), nivel y fecha de
  /// encuentro (hoy, o [today]), lugar de encuentro de las tablas si la especie
  /// aparece en el juego y, en Gen 9, nivel de obediencia. Un Pokémon con fecha
  /// 00/00/00 u obediencia 0 es ilegal y el juego puede rechazar el save.
  static Pkm create(GameVersion game, TrainerData trainer,
      {int species = 25,
      int form = 0,
      int level = 5,
      int language = 7,
      bool japanese = false,
      int? versionId,
      DateTime? today,
      Random? random}) {
    final rnd = random ?? Random();
    final f = PkFormat.forGame(game);
    final Pkm pk = f.isGameBoy
        ? Pkm.fromGb(f, Uint8List(f.partySize), nickname: '', otName: trainer.name, japanese: japanese)
        : Pkm.fromDecrypted(f, Uint8List(f.partySize));
    pk.dataGame = game;
    if (f.hasEncryptionConstant) pk.encryptionConstant = rnd.nextInt(0x7FFFFFFF) | 1;
    if (!f.isGameBoy) pk.pid = (rnd.nextInt(0x10000) << 16) | rnd.nextInt(0x10000);
    pk.species = species;
    pk.form = form;
    pk.tid = trainer.tid;
    pk.sid = trainer.sid;
    pk.language = f.isGameBoy ? 2 : language;
    pk.otName = trainer.name;
    pk.otGender = trainer.gender ?? 0;
    pk.exp = Species.expForLevel(species, level);
    pk.ball = 4;
    pk.friendship = 70;
    final table = GameDataTable.forGame(game);
    final personal = table.entry(species, form);
    if (f.generation >= 3) {
      if (f.generation >= 5) pk.nature = rnd.nextInt(25);
      if (f.hasStatNature) pk.statNature = pk.nature;
      pk.setAbilitySlot(0);
      if (personal != null && f.generation >= 6) {
        final r = personal.genderRatio;
        pk.gender = r == 255 ? 2 : (r == 254 ? 1 : (r == 0 ? 0 : (rnd.nextInt(253) + 1 < r ? 1 : 0)));
      }
    }
    // Gen 9: teratipo original = primer tipo de la forma (PKHeX), salvo Ogerpon.
    if (f.hasTeraType) {
      pk.teraTypeOriginal = SpeciesForms.defaultTeraType(species, form, game);
      pk.teraType = pk.teraTypeOriginal; // sin teralito (19)
    }
    pk.setIvs([for (var i = 0; i < 6; i++) rnd.nextInt(f.maxIv + 1)]);
    // Últimos 4 movimientos aprendidos por nivel.
    final learned = [
      for (final m in table.levelUpMoves(species, form))
        if (m.level <= level && m.move != 0) m.move,
    ];
    final unique = <int>[];
    for (final m in learned.reversed) {
      if (!unique.contains(m)) unique.add(m);
      if (unique.length == 4) break;
    }
    for (var i = 0; i < 4; i++) {
      pk.setMove(i, i < unique.length ? unique.reversed.toList()[i] : 0, context: table.context);
    }
    if (f.generation >= 3) {
      final v = versionId ?? defaultVersion(game);
      if (v != null) {
        pk.version = v;
        final locs = OriginPlace.locations(v, species, DataLanguage.en);
        if (locs.isNotEmpty) pk.metLocation = locs.first.id;
      }
      pk.metLevel = level;
      if (pk.hasDates) {
        final d = today ?? DateTime.now();
        pk.metDate = DateTime(d.year, d.month, d.day);
      }
      if (f == PkFormat.pk9 || f == PkFormat.pa9) pk.data[0x11F] = level; // ObedienceLevel
    }
    // Leyendas Z-A: flags «plus» que el juego marca por nivel (PKHeX exige
    // las que tocan por el learnset; sin ellas avisa PlusMoveSufficientLevelMissing).
    PlusMoves.sync(pk);
    pk.setDefaultNickname();
    pk.refreshPartyStats();
    pk.refreshChecksum();
    Ribbons.setAffixed(pk, null); // sin cinta mostrada
    return pk;
  }

  /// Primera versión de origen (id de PKHeX `GameVersion`) de [game].
  static int? defaultVersion(GameVersion game) {
    for (var v = 1; v <= 52; v++) {
      if (OriginPlace.gameOf(v) == game) return v;
    }
    return null;
  }
}
