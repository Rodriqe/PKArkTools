import 'dart:io';
import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/src/formats/switch_saves.dart' show SwitchSizes;
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

/// Leyendas Pokémon Z-A: lo que provocó el fallo del owner al importar en el
/// juego un save editado (Totodile creado con fecha de encuentro 00/00/00 y
/// obediencia 0) y lo que pkcore leía distinto de PKHeX (tiempo de juego).
/// Todo con saves sintéticos; el save real es opcional (ver el final).
const _ps = 0x158 + 0x88; // hueco del equipo en el bloque

Uint8List _partyBlock(Uint8List save) => SCBlockSet(SwishCrypto.decrypt(save))[SCKeys.svParty]!.data;

void main() {
  group('lectura', () {
    test('el tiempo de juego sale del bloque double (PKHeX PlayTime9a), no del bloque sin usar', () {
      final save = SyntheticSaves.legendsZA(
          party: const [SynthMon(158)], revision: 2, playedSeconds: 23 * 60 + 31.75);
      final s = SaveDetector.read(save);
      expect(s.trainer.playTime, const Duration(minutes: 23, seconds: 31));
      expect(SaveEditor.open(save).readTrainer().playTime, const Duration(minutes: 23, seconds: 31));
    });

    test('editar el tiempo de juego escribe el double conservando la fracción', () {
      final save = SyntheticSaves.legendsZA(party: const [SynthMon(158)], revision: 2, playedSeconds: 100.5);
      final ed = SaveEditor.open(save);
      final t = ed.readTrainer();
      ed.writeTrainer(t.copyWith(playTime: const Duration(hours: 2, minutes: 3, seconds: 4)));
      final out = ed.buildVerified();
      final b = SCBlockSet(SwishCrypto.decrypt(out))[SCKeys.zaPlayedSeconds]!;
      expect(ByteData.sublistView(b.data).getFloat64(0, Endian.little), 2 * 3600 + 3 * 60 + 4.5);
      expect(SaveDetector.read(out).trainer.playTime, const Duration(hours: 2, minutes: 3, seconds: 4));
    });

    test('revisión desconocida: se lee con un aviso claro', () {
      final s = SaveDetector.read(SyntheticSaves.legendsZA(party: const [SynthMon(158)], revision: 9));
      expect(s.game, GameVersion.legendsZA);
      expect(s.party, hasLength(1));
      expect(s.warnings.join(' '), contains('revisión 9'));
    });

    test('sin bloque de equipo: UnsupportedSaveException que nombra Z-A y la versión', () {
      final bytes = SyntheticSaves.legendsZA(revision: 3, withParty: false);
      expect(
          () => SaveDetector.read(bytes),
          throwsA(isA<UnsupportedSaveException>()
              .having((e) => e.message, 'message', allOf(contains('Z-A'), contains('revisión 3'), contains('versión')))));
    });
  });

  group('escritura del equipo', () {
    test('los huecos vacíos que escribió el juego quedan intactos al añadir un Pokémon', () {
      final save = SyntheticSaves.legendsZA(party: const [SynthMon(158)], revision: 2, gameEmptySlots: true);
      final before = _partyBlock(save);
      final ed = SaveEditor.open(save);
      final pk = PkmFactory.create(GameVersion.legendsZA, ed.readTrainer(), species: 158, level: 16);
      ed.writeParty([ed.readPartySlot(0), pk]);
      final after = _partyBlock(ed.buildVerified());
      // Huecos 2..5: byte a byte iguales (antes se reescribían con otro relleno).
      expect(after.sublist(2 * _ps), before.sublist(2 * _ps));
      expect(after.sublist(0, _ps), before.sublist(0, _ps));
      expect(after[_ps + 0x158], 1, reason: 'marca de presencia de la revisión con DLC');
      expect(after[_ps + 0x158 + 0x48], 1);
    });

    test('quitar un Pokémon deja el hueco vacío como PKHeX (WriteEmpty) y el recuento baja', () {
      final save = SyntheticSaves.legendsZA(
          party: const [SynthMon(158), SynthMon(25)], revision: 2, gameEmptySlots: true);
      final ed = SaveEditor.open(save);
      ed.writeParty([ed.readPartySlot(0)]);
      final out = ed.buildVerified();
      final again = SaveEditor.open(out);
      expect(again.partyCount, 1);
      final d = _partyBlock(out);
      final blank = Pkm.fromDecrypted(PkFormat.pa9, Uint8List(PkFormat.pa9.partySize)).encryptParty();
      expect(d.sublist(_ps, _ps + 0x158), blank);
      expect(d[_ps + 0x158], 1);
      expect(d[_ps + 0x158 + 0x48], 1);
    });

    test('round-trip sin cambios idéntico', () {
      final save = SyntheticSaves.legendsZA(
          party: const [SynthMon(158)], revision: 2, gameEmptySlots: true, playedSeconds: 5);
      expect(SaveEditor.open(save).build(), save);
    });
  });

  group('Pokémon creado', () {
    final tr = SaveEditor.open(SyntheticSaves.legendsZA(revision: 2)).readTrainer();

    test('origen coherente: versión Z-A, fecha de hoy, nivel y obediencia de encuentro', () {
      final pk = PkmFactory.create(GameVersion.legendsZA, tr, species: 158, level: 16, today: DateTime(2026, 11, 22));
      expect(pk.version, 52);
      expect(pk.metDate, DateTime(2026, 11, 22));
      expect(pk.metLevel, 16);
      expect(pk.data[0x11F], 16, reason: 'ObedienceLevel');
      final codes = {for (final i in Legality.check(pk, GameVersion.legendsZA)) i.code};
      expect(codes, isNot(contains(LegalityCode.metDateInvalid)));
      expect(codes, isNot(contains(LegalityCode.obedienceLevelInvalid)));
      expect(codes, isNot(contains(LegalityCode.originVersionMissing)));
    });

    test('como el Totodile del owner (fecha 00/00/00, obediencia 0): avisos con corrección', () {
      final pk = PkmFactory.create(GameVersion.legendsZA, tr, species: 158, level: 16)
        ..metLocation = 273
        ..metDate = null
        ..refreshChecksum();
      pk.data[0x11F] = 0;
      final issues = Legality.check(pk, GameVersion.legendsZA);
      final date = issues.firstWhere((i) => i.code == LegalityCode.metDateInvalid);
      final obey = issues.firstWhere((i) => i.code == LegalityCode.obedienceLevelInvalid);
      final fixed = Legality.applyFix(Legality.applyFix(pk, date, GameVersion.legendsZA)!, obey, GameVersion.legendsZA)!;
      expect(fixed.metDate, isNotNull);
      expect(fixed.data[0x11F], 16);
      final codes = {for (final i in Legality.check(fixed, GameVersion.legendsZA)) i.code};
      expect(codes, isNot(anyOf(contains(LegalityCode.metDateInvalid), contains(LegalityCode.obedienceLevelInvalid))));
    });
  });

  group('movimientos «plus» (PKHeX PlusMoveSufficientLevelMissing)', () {
    final tr = SaveEditor.open(SyntheticSaves.legendsZA(revision: 2)).readTrainer();
    const za = GameVersion.legendsZA;
    int idx(int move) => GameDataTable.zaPlusMoves.indexOf(move);
    Set<int> flagged(Pkm pk) => {
          for (var i = 0; i < Pkm.plusFlagCount; i++)
            if (pk.plusFlag(i)) PlusMoves.moveAt(i),
        };

    test('tabla de PKHeX: 340 movimientos, Placaje primero de Totodile', () {
      expect(GameDataTable.zaPlusMoves, hasLength(340));
      // plus_za.pkl de Totodile: Arañazo/Malicioso a 10, Pistola Agua a 9, Mordisco a 13.
      final plus = GameDataTable.forGame(za).plusLevelMoves(158);
      expect(plus.take(4).toList(), [
        (move: 33, level: 10),
        (move: 43, level: 10),
        (move: 55, level: 9),
        (move: 44, level: 13),
      ]);
    });

    test('flags en el formato PA9: índices 0‥263 en 0xD6 y 264‥359 en 0x94', () {
      final pk = PkmFactory.create(za, tr, species: 158, level: 5);
      pk.setPlusFlag(0, true);
      pk.setPlusFlag(9, true);
      pk.setPlusFlag(264, true);
      pk.setPlusFlag(271, true);
      expect(pk.data[0xD6], 0x01);
      expect(pk.data[0xD7], 0x02);
      expect(pk.data[0x94], 0x81);
      pk.setPlusFlag(271, false);
      expect(pk.data[0x94], 0x01);
      expect(pk.plusFlag(264), isTrue);
    });

    test('Pokémon creado: flags exactas por su nivel y sin avisos', () {
      final lv7 = PkmFactory.create(za, tr, species: 158, level: 7);
      expect(flagged(lv7), isEmpty);
      final lv16 = PkmFactory.create(za, tr, species: 158, level: 16);
      expect(flagged(lv16), {33, 43, 55, 44});
      final codes = {for (final i in Legality.check(lv16, za)) i.code};
      expect(codes, isNot(anyOf(contains(LegalityCode.plusMoveMissing), contains(LegalityCode.plusMoveInvalid))));
    });

    test('Rotom con forma lleva también las flags de la forma 0', () {
      final pk = PkmFactory.create(za, tr, species: 479, level: 50)..form = 1;
      PlusMoves.sync(pk);
      final t = GameDataTable.forGame(za);
      final expected = {
        for (final f in [0, 1])
          for (final lm in t.plusLevelMoves(479, f))
            if (lm.level <= 50) lm.move,
      };
      expect(flagged(pk), expected);
      expect(PlusMoves.missingIndexes(pk), isEmpty);
      expect(PlusMoves.invalidIndexes(pk), isEmpty);
    });

    test('subir de nivel añade las que tocan; bajar quita las imposibles y conserva las de MT', () {
      final pk = PkmFactory.create(za, tr, species: 158, level: 16);
      pk.level = 60;
      PlusMoves.sync(pk);
      expect(flagged(pk), containsAll([61, 453, 784, 103, 710, 56, 200]));
      // Una flag por MT (Semilla de Maestría) es legal a cualquier nivel.
      final tm = GameDataTable.forGame(za).machineMoves(158).firstWhere((m) => idx(m) >= 0 && !flagged(pk).contains(m));
      pk.setPlusFlag(idx(tm), true);
      pk.level = 12;
      PlusMoves.sync(pk);
      final tms = GameDataTable.forGame(za).machineMoves(158);
      // Quedan las obligatorias (33, 43, 55), Mordisco (lo aprende a 10) y la de MT;
      // se van las que no aprende a nivel 12 ni por MT (p. ej. Hidrobomba, 56, si no es MT).
      expect(flagged(pk), containsAll([33, 43, 55, 44, tm]));
      expect(flagged(pk).where((m) => !tms.contains(m) && !{33, 43, 55, 44}.contains(m)), isEmpty);
    });

    test('Totodile de save sin flags: aviso con corrección que las pone', () {
      final pk = PkmFactory.create(za, tr, species: 158, level: 16);
      for (var i = 0; i < Pkm.plusFlagCount; i++) {
        pk.setPlusFlag(i, false);
      }
      expect(PlusMoves.permittedMoves(pk), isNot(contains(53)));
      pk.setPlusFlag(idx(53), true); // Lanzallamas: Totodile no lo aprende
      pk.setPlusFlag(350, true); // índice fuera de la tabla
      final issues = Legality.check(pk, za);
      final missing = issues.firstWhere((i) => i.code == LegalityCode.plusMoveMissing);
      expect(issues.map((i) => i.code), contains(LegalityCode.plusMoveInvalid));
      final fixed = Legality.applyFix(pk, missing, za)!;
      expect(flagged(fixed), {33, 43, 55, 44});
      expect(fixed.plusFlag(350), isFalse);
      final codes = {for (final i in Legality.check(fixed, za)) i.code};
      expect(codes, isNot(anyOf(contains(LegalityCode.plusMoveMissing), contains(LegalityCode.plusMoveInvalid))));
    });

    test('fuera de Z-A no hay flags plus', () {
      final pk = PkmFactory.create(GameVersion.scarletViolet, tr, species: 158, level: 30);
      expect(pk.hasPlusFlags, isFalse);
      expect(PlusMoves.requiredIndexes(pk), isEmpty);
      expect(Legality.check(pk, GameVersion.scarletViolet).map((i) => i.code),
          isNot(contains(LegalityCode.plusMoveMissing)));
    });
  });

  // Save real opcional: cualquier `main` de Z-A copiado a .scratch/odin3/za/
  // (nunca se versiona). Solo se comprueban propiedades sin datos personales.
  final real = _realZa();
  group('save real de Z-A', skip: real == null ? 'sin save de Z-A en .scratch/odin3/za/' : null, () {
    test('lectura, round-trip idéntico y añadir al equipo sin tocar los huecos vacíos', () {
      final bytes = Uint8List.fromList(real!);
      final s = SaveDetector.read(bytes);
      expect(s.game, GameVersion.legendsZA);
      expect(s.checksum, ChecksumStatus.valid);
      final ed = SaveEditor.open(bytes);
      expect(ed.build(), bytes);
      final n = ed.partyCount;
      if (n >= 6) return;
      final before = _partyBlock(bytes);
      ed.writeParty([for (var i = 0; i < n; i++) ed.readPartySlot(i), PkmFactory.create(ed.game, ed.readTrainer())]);
      final after = _partyBlock(ed.buildVerified());
      expect(after.sublist((n + 1) * _ps), before.sublist((n + 1) * _ps));
      expect(after.sublist(0, n * _ps), before.sublist(0, n * _ps));
    });
  });
}

Uint8List? _realZa() {
  for (final base in ['../../.scratch/odin3/za', '.scratch/odin3/za']) {
    final dir = Directory(base);
    if (!dir.existsSync()) continue;
    for (final f in dir.listSync().whereType<File>()) {
      if (!SwitchSizes.za.contains(f.lengthSync())) continue;
      final b = f.readAsBytesSync();
      try {
        if (SaveDetector.detect(b).game == GameVersion.legendsZA) return b;
      } catch (_) {}
    }
  }
  return null;
}
