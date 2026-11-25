import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:math';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

/// Creación de Pokémon oscuros de Colosseum y XD (tabla de PKHeX con semillas
/// PID/IV válidas para los bloqueos de equipo).
///
/// Con `SHADOW_OUT=<carpeta>` escribe además saves sintéticos con los oscuros
/// creados para comprobarlos con el oráculo PKHeX (`PkhexOracle.dll dump`).
void main() {
  const gcCodes = {
    LegalityCode.shadowCannotLeave,
    LegalityCode.shadowIdMismatch,
    LegalityCode.shadowGaugeInvalid,
    LegalityCode.shadowNationalRibbon,
    LegalityCode.xdFatefulMissing,
    LegalityCode.shadowIdUnknown,
    LegalityCode.shadowSpeciesNotShadow,
    LegalityCode.shadowPidIvMismatch,
    LegalityCode.xdShadowShiny,
    LegalityCode.encounterNotInGame,
    LegalityCode.encounterWrongLocation,
    LegalityCode.encounterWrongLevel,
  };
  List<LegalityCode> codes(Pkm pk, GameVersion g) => [for (final i in Legality.check(pk, g)) i.code];

  group('tabla', () {
    test('todos los oscuros de PKHeX (sin e-Reader) con semillas CXD', () {
      final colo = GcShadowEncounter.forGame(GameVersion.colosseum);
      final xd = GcShadowEncounter.forGame(GameVersion.xd);
      expect({for (final e in colo) e.shadowId}.length, greaterThanOrEqualTo(48));
      expect({for (final e in xd) e.shadowId}.length, greaterThanOrEqualTo(80));
      for (final e in [...colo, ...xd]) {
        expect(e.seeds, isNotEmpty, reason: '${e.game} ${e.shadowId}');
        expect(e.moves.length, 4);
        final r = GcShadowRoll.fromSeed(e.seeds.first);
        expect(GcShadowRoll.isCxd(r.pid, r.ivs), isTrue);
        // Coincide con los encuentros generales (mismo id, especie y medidor).
        final g = GcEncounter.byShadowId(e.shadowId, xd: e.xd);
        expect(g.any((x) => x.species == e.species && x.gauge == e.gauge && x.location == e.location), isTrue,
            reason: '${e.game} ${e.shadowId}');
      }
      // Teddiursa de XD: solo en Poké Ball.
      expect(GcShadowEncounter.byShadowId(GameVersion.xd, 1).single.ball, 4);
    });

    test('PID/IV al azar no salen del RNG de GameCube', () {
      expect(GcShadowRoll.isCxd(0x12345678, const [1, 2, 3, 4, 5, 6]), isFalse);
    });
  });

  for (final game in [GameVersion.colosseum, GameVersion.xd]) {
    final isXd = game == GameVersion.xd;
    group(game.name, () {
      Uint8List save() => isXd ? SyntheticSaves.xdDemo() : SyntheticSaves.colosseumDemo();

      test('crear cada oscuro: coherente y sin avisos de legalidad', () {
        final ed = SaveEditor.open(save());
        final t = ed.readTrainer();
        for (final e in GcShadowEncounter.forGame(game)) {
          final pk = GcShadow.create(e, t, region: GcRegion.ntscU, random: Random(e.shadowId))..dataGame = game;
          expect(pk.species, e.species);
          expect(pk.level, e.level);
          expect(pk.metLevel, e.level);
          expect(pk.metLocation, e.location);
          expect(pk.version, 15);
          expect(pk.moves, e.moves);
          expect(pk.ball, e.ball);
          expect(pk.tid, t.tid);
          expect(pk.otName, t.name);
          expect(pk.fatefulEncounter, isXd);
          expect(pk.gc!.shadowId, e.shadowId);
          expect(pk.gc!.isShadow, isTrue);
          expect(pk.gc!.purification, e.gauge);
          expect(Ribbons.get(pk, 'RibbonNational'), 0);
          if (isXd) expect(pk.isShiny, isFalse);
          expect(codes(pk, game).where(gcCodes.contains), isEmpty, reason: '${e.shadowId} #${e.species}');
          expect(Legality.check(pk, game).where((i) => i.severity == LegalitySeverity.warning), isEmpty,
              reason: '${e.shadowId} #${e.species}: ${Legality.check(pk, game).map((i) => i.code)}');
        }
      });

      test('guardar y releer: oscuro y purificado, Strategy Memo y tabla de XD', () {
        final ed = SaveEditor.open(save()) as GcEditor;
        final t = ed.readTrainer();
        final list = GcShadowEncounter.forGame(game);
        final a = list.firstWhere((e) => !ed.pokedex.isSeen(e.species));
        final b = list.lastWhere((e) => e.species != a.species);
        final shadow = GcShadow.create(a, t, region: ed.region, gauge: a.gauge ~/ 2, random: Random(1));
        final purified = GcShadow.create(b, t, region: ed.region, purified: true, random: Random(2));
        ed.set(const SlotRef.box(1, 0), shadow);
        ed.set(const SlotRef.box(1, 1), purified);
        final bytes = ed.buildVerified();
        final back = SaveEditor.open(bytes) as GcEditor;
        final s = back.get(const SlotRef.box(1, 0))!;
        final p = back.get(const SlotRef.box(1, 1))!;
        expect(s.pid, shadow.pid);
        expect(s.ivs, shadow.ivs);
        expect(s.moves, a.moves);
        expect(s.gc!.shadowId, a.shadowId);
        expect(s.gc!.isShadow, isTrue);
        expect(s.gc!.purification, a.gauge ~/ 2);
        expect(Ribbons.get(s, 'RibbonNational'), 0);
        expect(p.gc!.shadowId, b.shadowId);
        expect(p.gc!.isPurified, isTrue);
        expect(Ribbons.get(p, 'RibbonNational'), 1);
        expect(back.pokedex.isSeen(a.species), isTrue);
        if (isXd) {
          final row = back.xdShadowTable.firstWhere((r) => r.id == a.shadowId);
          expect(row.species, a.species);
          expect(row.snagged, isTrue);
          expect(row.purified, isFalse);
          expect(row.purification, a.gauge ~/ 2);
          expect(back.xdShadowTable.firstWhere((r) => r.id == b.shadowId).purified, isTrue);
        } else {
          expect(back.pokedex.isCaught(a.species), isTrue);
        }
        for (final pk in [s, p]) {
          expect(codes(pk, game).where(gcCodes.contains), isEmpty);
        }
        // Volver a guardar sin cambios conserva los bytes.
        expect(SaveEditor.open(bytes).buildPayload(), bytes);
      });

      test('purificar y volver a oscuro', () {
        final ed = SaveEditor.open(save());
        final e = GcShadowEncounter.forGame(game).first;
        final pk = GcShadow.create(e, ed.readTrainer(), region: GcRegion.ntscU, random: Random(3));
        GcShadow.setPurified(pk, true);
        expect(pk.gc!.isPurified, isTrue);
        expect(Ribbons.get(pk, 'RibbonNational'), 1);
        expect(codes(pk, game).where(gcCodes.contains), isEmpty);
        GcShadow.setPurified(pk, false);
        expect(pk.gc!.isShadow, isTrue);
        expect(pk.gc!.purification, e.gauge);
        expect(Ribbons.get(pk, 'RibbonNational'), 0);
        expect(codes(pk, game).where(gcCodes.contains), isEmpty);
      });

      test('avisos: id inexistente, especie no oscura, PID/IV y variocolor', () {
        final ed = SaveEditor.open(save());
        final e = GcShadowEncounter.forGame(game).first;
        final pk = GcShadow.create(e, ed.readTrainer(), region: GcRegion.ntscU, random: Random(4));
        pk.gc!.shadowId = 999;
        expect(codes(pk, game), contains(LegalityCode.shadowIdUnknown));
        pk.gc!.shadowId = e.shadowId;
        pk.species = 25; // Pikachu nunca es oscuro aquí
        expect(codes(pk, game), contains(LegalityCode.shadowSpeciesNotShadow));
        pk.species = e.species;
        pk.pid = pk.pid ^ 0x00010000;
        expect(codes(pk, game), contains(LegalityCode.shadowPidIvMismatch));
        if (isXd) {
          pk.setShiny(true);
          expect(codes(pk, game), contains(LegalityCode.xdShadowShiny));
        }
      });

      final out = io.Platform.environment['SHADOW_OUT'];
      test('saves para el oráculo PKHeX', skip: out == null ? 'sin SHADOW_OUT' : null, () {
        // Save vacío y un Pokémon por id oscuro (en el juego cada id es un único Pokémon).
        final ed = SaveEditor.open(isXd ? SyntheticSaves.xd() : SyntheticSaves.colosseum()) as GcEditor;
        final t = ed.readTrainer();
        var slot = 0;
        final seen = <int>{};
        for (final e in GcShadowEncounter.forGame(game)) {
          if (!seen.add(e.shadowId)) continue;
          final box = slot ~/ 30;
          if (box >= ed.boxCount) break;
          final pk = GcShadow.create(e, t,
              region: ed.region, purified: slot.isOdd, gauge: slot % 3 == 0 ? e.gauge ~/ 3 : null, random: Random(slot));
          ed.set(SlotRef.box(box, slot % 30), pk);
          slot++;
        }
        io.Directory(out!).createSync(recursive: true);
        io.File('$out/shadow_${game.name}.bin').writeAsBytesSync(ed.buildVerified());
      });
    });
  }
}
