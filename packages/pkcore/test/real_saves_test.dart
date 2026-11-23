import 'dart:io';
import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/src/formats/nds_saves.dart' show Gen4Layout;
import 'package:test/test.dart';

/// Pruebas opcionales con saves reales del owner en `.ref/real-saves/` (fuera
/// del repositorio, en .gitignore). Si el archivo no existe, se saltan. Nunca
/// se modifica el archivo: todo se hace sobre copias en memoria, y las
/// aserciones no incluyen datos personales (nombre, IDs).
Uint8List? _load(String name) {
  for (final base in ['../../.ref/real-saves', '.ref/real-saves']) {
    final f = File('$base/$name');
    if (f.existsSync()) return Uint8List.fromList(f.readAsBytesSync());
  }
  return null;
}

int _u32(Uint8List d, int o) => d[o] | d[o + 1] << 8 | d[o + 2] << 16 | d[o + 3] << 24;

/// Avisos que, en Pokémon de una partida real, indican un falso positivo del verificador.
const _falsePositiveCodes = {
  LegalityCode.encounterNotInGame,
  LegalityCode.encounterWrongLocation,
  LegalityCode.encounterWrongLevel,
  LegalityCode.moveNotLearnable,
  LegalityCode.eventSpeciesNotFateful,
  LegalityCode.speciesNotInGame,
  LegalityCode.noMoves,
  LegalityCode.ballInvalid,
  LegalityCode.originVersionMissing,
};

void main() {
  final ss = _load('Pokemon Soul Silver.sav');
  group('SoulSilver real', skip: ss == null ? 'sin .ref/real-saves/Pokemon Soul Silver.sav' : null, () {
    late Uint8List bytes;
    setUp(() => bytes = Uint8List.fromList(ss!));

    test('lectura completa: juego, checksums de ambos bloques, cajas sin huecos fantasma', () {
      final save = SaveDetector.read(bytes);
      expect(save.game, GameVersion.heartGoldSoulSilver);
      expect(save.checksum, ChecksumStatus.valid);
      const l = Gen4Layout.hgss;
      for (final (begin, len) in [(0, l.generalSize), (l.storageStart, l.storageSize)]) {
        for (final p in [0, Gen4Layout.partitionSize]) {
          final b = begin + p;
          expect(Checksums.crc16Ccitt(bytes, b, b + len - l.footerSize), bytes[b + len - 2] | bytes[b + len - 1] << 8,
              reason: 'bloque @${b.toRadixString(16)}');
          expect(_u32(bytes, b + len - 0xC), len);
          expect(_u32(bytes, b + len - 0x8), Gen4Layout.magicIntl);
        }
      }
      final ed = SaveEditor.open(bytes);
      expect(ed.integrityIssues, isEmpty);
      expect(ed.partyCount, inInclusiveRange(1, 6));
      var boxed = 0;
      for (var b = 0; b < ed.boxCount; b++) {
        for (var s = 0; s < ed.boxSlotCount; s++) {
          final pk = ed.get(SlotRef.box(b, s));
          if (pk == null) continue;
          boxed++;
          expect(pk.species, inInclusiveRange(1, 493));
          expect(pk.checksumValid, isTrue);
          expect(pk.level, inInclusiveRange(1, 100));
        }
      }
      expect(boxed, save.boxedCount, reason: 'el editor y el lector ven los mismos Pokémon');
      final t = ed.readTrainer();
      expect(t.money, inInclusiveRange(0, ed.maxMoney));
      expect(ed.readInventory(), isNotEmpty);
      expect(ed.pokedex!.counts.seen, inInclusiveRange(0, 493));
    });

    test('round-trip sin cambios = bytes idénticos', () {
      final ed = SaveEditor.open(bytes);
      expect(ed.build(), bytes);
      expect(ed.buildVerified(), bytes);
    });

    test('edición real: nivel, movimiento, dinero, objeto, mover de caja y Pokédex', () {
      final ed = SaveEditor.open(bytes);
      final from = [
        for (var b = 0; b < ed.boxCount; b++)
          for (var s = 0; s < ed.boxSlotCount; s++)
            if (ed.get(SlotRef.box(b, s)) case final pk? when pk.level < 90) (SlotRef.box(b, s), pk),
      ].first;
      final empty = ed.firstEmptyBoxSlot()!;
      final (ref, pk) = from;
      final edited = pk.clone()
        ..level = pk.level + 5
        ..setMove(3, 33, context: '4'); // Placaje
      ed.set(ref, edited);
      ed.swap(ref, empty);
      ed.writeTrainer(ed.readTrainer().copyWith(money: 123456));
      final inv = ed.readInventory()!;
      final items = inv.firstWhere((p) => p.type == 'Items');
      final firstItem = items.items.first;
      ed.writeInventory([
        for (final p in inv) p.type == 'Items' ? p.withItems([firstItem.withCount(7), ...items.items.skip(1)]) : p,
      ]);
      final dex = ed.pokedex!;
      final wasCaught = dex.isCaught(25);
      dex.setCaught(25, !wasCaught);
      final out = ed.buildVerified();

      final re = SaveEditor.open(out);
      expect(re.integrityIssues, isEmpty);
      expect(SaveDetector.read(out).checksum, ChecksumStatus.valid);
      expect(re.get(ref), isNull);
      final moved = re.get(empty)!;
      expect(moved.species, pk.species);
      expect(moved.level, pk.level + 5);
      expect(moved.moves[3], 33);
      expect(moved.checksumValid, isTrue);
      expect(re.readTrainer().money, 123456);
      expect(re.readInventory()!.firstWhere((p) => p.type == 'Items').items.first, InventoryItem(firstItem.item, 7));
      expect(re.pokedex!.isCaught(25), !wasCaught);

      // Solo cambian los bloques activos (general y almacenamiento); el resto del archivo es idéntico.
      const l = Gen4Layout.hgss;
      final activeGeneral = _u32(bytes, l.generalSize - 0x10) < _u32(bytes, Gen4Layout.partitionSize + l.generalSize - 0x10)
          ? Gen4Layout.partitionSize
          : 0;
      final activeStorage = _u32(bytes, l.storageStart + l.storageSize - 0x10) <
              _u32(bytes, Gen4Layout.partitionSize + l.storageStart + l.storageSize - 0x10)
          ? Gen4Layout.partitionSize + l.storageStart
          : l.storageStart;
      bool inside(int i) =>
          (i >= activeGeneral && i < activeGeneral + l.generalSize) ||
          (i >= activeStorage && i < activeStorage + l.storageSize);
      for (var i = 0; i < out.length; i++) {
        if (out[i] != bytes[i]) expect(inside(i), isTrue, reason: 'byte 0x${i.toRadixString(16)} fuera del bloque activo');
      }
    });

    test('legalidad: sin falsos positivos en Pokémon reales', () {
      final ed = SaveEditor.open(bytes);
      final mons = [
        ...ed.party,
        for (var b = 0; b < ed.boxCount; b++)
          for (var s = 0; s < ed.boxSlotCount; s++) ?ed.get(SlotRef.box(b, s)),
      ];
      final bad = <String>[
        for (final pk in mons)
          for (final i in Legality.check(pk, ed.game))
            if (_falsePositiveCodes.contains(i.code)) '#${pk.species}: ${i.code.name} ${i.args}',
      ];
      expect(bad, isEmpty);
      // Los únicos avisos: PP por encima del máximo (3 movimientos de un mismo
      // Pokémon), que PKHeX también marca (MovePPTooHigh).
      final pp = [for (final pk in mons) for (final i in Legality.check(pk, ed.game)) i.code];
      expect(pp, List.filled(3, LegalityCode.ppTooHigh));
    });
  });

  final sw = _load('sword/main');
  group('Espada real (Switch, SCBlock/SwishCrypto)', skip: sw == null ? 'sin .ref/real-saves/sword/main' : null, () {
    late Uint8List bytes;
    setUp(() => bytes = Uint8List.fromList(sw!));

    test('lectura completa: bloques descifrados, hash válido, cajas sin huecos fantasma', () {
      final save = SaveDetector.read(bytes);
      expect(save.game, GameVersion.swordShield);
      expect(save.checksum, ChecksumStatus.valid);
      final ed = SaveEditor.open(bytes);
      expect(ed.integrityIssues, isEmpty);
      expect(ed.partyCount, inInclusiveRange(1, 6));
      var boxed = 0;
      for (var b = 0; b < ed.boxCount; b++) {
        for (var s = 0; s < ed.boxSlotCount; s++) {
          final pk = ed.get(SlotRef.box(b, s));
          if (pk == null) continue;
          boxed++;
          expect(pk.species, inInclusiveRange(1, 898));
          expect(pk.checksumValid, isTrue);
          expect(pk.level, inInclusiveRange(1, 100));
        }
      }
      expect(boxed, save.boxedCount);
      expect(ed.readTrainer().money, inInclusiveRange(0, ed.maxMoney));
      expect(ed.readInventory(), isNotEmpty);
      expect(ed.pokedex!.counts.seen, inInclusiveRange(1, 898));
    });

    test('round-trip sin cambios = bytes idénticos', () {
      final ed = SaveEditor.open(bytes);
      expect(ed.build(), bytes);
      expect(ed.buildVerified(), bytes);
    });

    test('edición real: nivel, movimiento, dinero, objeto, mover de caja y Pokédex', () {
      final ed = SaveEditor.open(bytes);
      final (ref, pk) = [
        for (var b = 0; b < ed.boxCount; b++)
          for (var s = 0; s < ed.boxSlotCount; s++)
            if (ed.get(SlotRef.box(b, s)) case final pk? when pk.level < 90) (SlotRef.box(b, s), pk),
      ].first;
      final empty = ed.firstEmptyBoxSlot()!;
      ed.set(ref, pk.clone()
        ..level = pk.level + 5
        ..setMove(3, 33, context: '8'));
      ed.swap(ref, empty);
      ed.writeTrainer(ed.readTrainer().copyWith(money: 123456));
      final inv = ed.readInventory()!;
      final med = inv.firstWhere((p) => p.type == 'Medicine');
      ed.writeInventory([
        for (final p in inv) p.type == 'Medicine' ? p.withItems([med.items.first.withCount(7), ...med.items.skip(1)]) : p,
      ]);
      final wasCaught = ed.pokedex!.isCaught(25);
      ed.pokedex!.setCaught(25, !wasCaught);
      final out = ed.buildVerified();

      final re = SaveEditor.open(out);
      expect(re.integrityIssues, isEmpty);
      expect(SaveDetector.read(out).checksum, ChecksumStatus.valid);
      expect(re.get(ref), isNull);
      final moved = re.get(empty)!;
      expect((moved.species, moved.level, moved.moves[3]), (pk.species, pk.level + 5, 33));
      expect(moved.checksumValid, isTrue);
      expect(re.readTrainer().money, 123456);
      expect(re.readInventory()!.firstWhere((p) => p.type == 'Medicine').items.first, InventoryItem(med.items.first.item, 7));
      expect(re.pokedex!.isCaught(25), !wasCaught);
      // Cada bloque SCBlock se cifra por separado: solo cambian los bloques
      // editados (dos huecos de caja, dinero, bolsillo, Pokédex) y el hash final.
      var changed = 0;
      for (var i = 0; i < out.length; i++) {
        if (out[i] != bytes[i]) changed++;
      }
      expect(changed, lessThan(1500));
      expect(out.sublist(out.length - 0x20), isNot(bytes.sublist(bytes.length - 0x20)));
    });

    test('legalidad: solo los avisos que PKHeX también marca', () {
      // Verificado con tools/pkhex_oracle (tool/compare_with_pkhex.sh): antes de
      // las correcciones había 80 avisos sin respaldo de PKHeX (DT desalineadas,
      // incursiones, aves errantes, combo de captura de Let's Go, movimientos y
      // recordables que viajan por HOME, eventos variocolor y Código Cero). El
      // único que queda lo marca PKHeX también (EncInvalid).
      final ed = SaveEditor.open(bytes);
      final mons = [
        ...ed.party,
        for (var b = 0; b < ed.boxCount; b++)
          for (var s = 0; s < ed.boxSlotCount; s++) ?ed.get(SlotRef.box(b, s)),
      ];
      final counts = <String, int>{};
      for (final pk in mons) {
        for (final i in Legality.check(pk, ed.game)) {
          counts.update('${i.code.name}/${i.severity.name}', (n) => n + 1, ifAbsent: () => 1);
        }
      }
      expect(counts, {'encounterWrongLocation/notice': 1});
    });
  });

  // Sol/Luna y Ultrasol/Ultraluna: el juego firma el save (MemeCrypto) después
  // de calcular los checksums. Antes pkcore marcaba el bloque 36 como incorrecto
  // en todos los saves reales (bug de la Odin3).
  for (final (name, game) in [('sm/main', GameVersion.sunMoon), ('usum/main', GameVersion.ultraSunUltraMoon)]) {
    final real = _load(name);
    group('${game.nameEs} real (firma MemeCrypto)', skip: real == null ? 'sin .ref/real-saves/$name' : null, () {
      test('checksums y firma válidos; sin cambios, archivo intacto', () {
        final bytes = Uint8List.fromList(real!);
        expect(SaveVerifier.checksumProblems(bytes), isEmpty);
        expect(MemeCrypto.isSaveSignatureValid(bytes, game), isTrue);
        final ed = SaveEditor.open(bytes);
        expect(ed.game, game);
        expect(ed.damage, SaveDamage.none);
        expect(ed.build(), bytes);
        // Volver a firmar sin cambios reproduce exactamente la firma del juego.
        expect(ed.buildRepaired(), bytes);
      });

      test('editar → checksums y firma válidos al releer', () {
        final ed = SaveEditor.open(Uint8List.fromList(real!));
        ed.writeTrainer(ed.readTrainer().copyWith(money: 123456));
        final out = ed.buildVerified();
        expect(SaveVerifier.checksumProblems(out), isEmpty);
        expect(MemeCrypto.isSaveSignatureValid(out, game), isTrue);
        expect(SaveEditor.open(out).readTrainer().money, 123456);
      });
    });
  }
}
