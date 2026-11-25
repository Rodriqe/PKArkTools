import 'dart:io' as io;
import 'dart:math';
import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

/// Generador de Living Dex.
///
/// Con `LIVINGDEX_OUT=<carpeta>` genera la Living Dex completa (normal y
/// variocolor, dos entrenadores) en saves sintéticos de un juego por versión y
/// escribe cada Pokémon leído de vuelta del save como archivo suelto, para
/// comprobarlo con el oráculo PKHeX (`tool/check_living_dex_pkhex.sh`).
const _trainers = [
  (SynthTrainer(name: 'Prueba', tid: 4242, sid: 31337, gender: 1), 7, false),
  (SynthTrainer(name: 'Tester', tid: 60123, sid: 999, gender: 0), 2, true),
];

SynthTrainer _v(SynthTrainer t, int? v) =>
    SynthTrainer(name: t.name.length > 7 && v != null && v < 10 ? t.name.substring(0, 7) : t.name, tid: t.tid, sid: t.sid, gender: t.gender, versionId: v);

/// Saves sintéticos vacíos por juego (código corto, juego, bytes).
List<(String, GameVersion, Uint8List)> syntheticSaves(SynthTrainer t) {
  SynthTrainer gb(SynthTrainer t) => SynthTrainer(name: t.name.toUpperCase().substring(0, min(7, t.name.length)), tid: t.tid, gender: t.gender);
  return [
    ('rb', GameVersion.redBlue, SyntheticSaves.gen1(trainer: gb(t))),
    ('c', GameVersion.crystal, SyntheticSaves.gen2(crystal: true, trainer: gb(t))),
    ('e', GameVersion.emerald, SyntheticSaves.gen3(trainer: t)),
    ('frlg', GameVersion.fireRedLeafGreen, SyntheticSaves.gen3(game: GameVersion.fireRedLeafGreen, trainer: t)),
    ('pt', GameVersion.platinum, SyntheticSaves.gen4(layout: Gen4Layout.pt, trainer: t)),
    ('hgss', GameVersion.heartGoldSoulSilver, SyntheticSaves.gen4(layout: Gen4Layout.hgss, trainer: t)),
    ('b2w2', GameVersion.black2White2, SyntheticSaves.gen5(layout: Gen5Layout.b2w2, trainer: _v(t, 22))),
    ('xy', GameVersion.xy, SyntheticSaves.ctr(layout: CtrLayout.xy, trainer: _v(t, 24))),
    ('oras', GameVersion.omegaRubyAlphaSapphire, SyntheticSaves.ctr(layout: CtrLayout.oras, trainer: _v(t, 26))),
    ('usum', GameVersion.ultraSunUltraMoon, SyntheticSaves.ctr(layout: CtrLayout.usum, trainer: _v(t, 32))),
    ('lgpe', GameVersion.letsGo, SyntheticSaves.letsGo(trainer: _v(t, 42))),
    ('swsh', GameVersion.swordShield, SyntheticSaves.swordShield(trainer: _v(t, 44))),
    ('bdsp', GameVersion.brilliantDiamondShiningPearl, SyntheticSaves.bdsp(trainer: t)),
    ('pla', GameVersion.legendsArceus, SyntheticSaves.legendsArceus(trainer: t)),
    ('sv', GameVersion.scarletViolet, SyntheticSaves.scarletViolet(trainer: _v(t, 50))),
    ('za', GameVersion.legendsZA, SyntheticSaves.legendsZA(trainer: t)),
  ];
}

void main() {
  final out = io.Platform.environment['LIVINGDEX_OUT'];

  test('tabla: todas las versiones de los juegos principales', () {
    for (final g in GameVersion.values) {
      if (g.isStorage || g.isColosseumOrXd) {
        expect(LivingDexDb.supports(g), isFalse, reason: '$g');
        continue;
      }
      expect(LivingDexDb.supports(g), isTrue, reason: '$g');
      for (final v in LivingDexDb.versionsOf(g)) {
        final rows = LivingDexDb.forVersion(v);
        expect(rows.where((e) => e.creatable).length, greaterThan(100), reason: '$g $v');
      }
    }
  });

  test('formas: excluye las de combate e incluye regionales y cosméticas', () {
    final sv = LivingDexDb.forVersion(50);
    bool has(int s, int f) => sv.any((e) => e.species == s && e.form == f && e.creatable);
    expect(has(25, 0), isTrue);
    expect(has(26, 1), isTrue, reason: 'Raichu de Alola');
    expect(has(1006, 0) || has(1005, 0), isTrue);
    final battle = sv.where((e) => e.exclusion == LivingDexExclusion.battleOnly).map((e) => e.species).toSet();
    expect(battle, containsAll([648, 888]), reason: 'Meloetta danza, Zacian');
    final xy = LivingDexDb.forVersion(24);
    expect(xy.where((e) => e.species == 666 && e.creatable).length, greaterThanOrEqualTo(15), reason: 'Vivillon');
    final e = LivingDexDb.forVersion(4);
    expect(e.where((x) => x.species == 201 && x.creatable).length, 28, reason: 'Unown en Rojo Fuego');
  });

  test('solo por evento (distribución terminada): míticos sin encuentro propio', () {
    expect(LivingDexDb.eventOnly(151), isTrue, reason: 'Mew (Isla Lejana exige el Mapa Viejo)');
    expect(LivingDexDb.eventOnly(385), isTrue, reason: 'Jirachi');
    expect(LivingDexDb.eventOnly(25), isFalse);
    expect(LivingDexDb.eventOnly(1019), isFalse, reason: 'no legendario');
    expect(LivingDexDb.eventOnly(150), isFalse, reason: 'Mewtwo estático');
  });

  group('generar en un save', () {
    for (final (code, _, raw) in syntheticSaves(_trainers[1].$1)) {
      test(code, () {
        final ed = SaveEditor.open(raw);
        final plan = LivingDex.plan(ed);
        expect(plan.slots, isNotEmpty);
        // Orden de la Pokédex nacional.
        for (var i = 1; i < plan.slots.length; i++) {
          final a = plan.slots[i - 1], b = plan.slots[i];
          expect(a.species < b.species || (a.species == b.species && a.form < b.form), isTrue, reason: '$code $i');
        }
        final res = LivingDex.apply(ed, plan, shiny: true, language: 2, random: Random(1));
        expect(res.written, min(plan.slots.length, plan.capacity));
        expect(res.left.length, max(0, plan.slots.length - plan.capacity));
        final again = SaveEditor.open(ed.build());
        final t = again.readTrainer();
        var n = 0, shiny = 0;
        for (var b = 0; b < again.boxCount; b++) {
          for (var s = 0; s < again.boxSlotCount; s++) {
            final pk = again.get(SlotRef.box(b, s));
            if (pk == null) continue;
            final slot = plan.slots[n++];
            expect((pk.species, LivingDexFactory.formOf(pk)), (slot.species, slot.form), reason: code);
            if (pk.isShiny) shiny++;
            if (slot.gift != null) continue; // eventos con OT/ID fijos
            if (!pk.format.isGameBoy) expect(pk.tid, t.tid, reason: '$code $pk');
            expect(pk.otName, t.name, reason: '$code ${pk.species}');
          }
        }
        expect(n, res.written);
        expect(shiny, greaterThan(res.written ~/ 2), reason: '$code: $shiny de ${res.written}');
      });
    }
  });

  test('archivos para el oráculo PKHeX', skip: out == null ? 'sin LIVINGDEX_OUT' : null, () {
    io.Directory(out!).createSync(recursive: true);
    for (var ti = 0; ti < _trainers.length; ti++) {
      final (st, lang, shiny) = _trainers[ti];
      for (final (code, _, raw) in syntheticSaves(st)) {
        final ed = SaveEditor.open(raw);
        final plan = LivingDex.plan(ed);
        LivingDex.apply(ed, plan, shiny: shiny, language: ed.format.isGameBoy ? 2 : lang, random: Random(ti));
        final again = SaveEditor.open(ed.build());
        for (var b = 0; b < again.boxCount; b++) {
          for (var s = 0; s < again.boxSlotCount; s++) {
            final pk = again.get(SlotRef.box(b, s));
            if (pk == null) continue;
            final name = 'ld_${code}_${ti}_${pk.species.toString().padLeft(4, '0')}_${LivingDexFactory.formOf(pk)}_${b * 100 + s}';
            io.File('$out/$name.${pk.format.extension}').writeAsBytesSync(pk.toFile());
          }
        }
      }
    }
  });
}
