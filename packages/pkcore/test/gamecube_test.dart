import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/src/crypto/gc_crypto.dart';
import 'package:pkcore/src/edit/gc_editor.dart';
import 'package:pkcore/src/formats/gc_container.dart';
import 'package:pkcore/src/pkm/gc_pkm.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  final colo = SyntheticSaves.colosseumDemo();
  final xd = SyntheticSaves.xdDemo();

  group('crypto', () {
    test('Colosseum: descifrar y volver a cifrar es la identidad', () {
      final slot = colo.sublist(ColoCrypto.slotOffset(1), ColoCrypto.slotOffset(1) + ColoCrypto.slotSize);
      final copy = Uint8List.fromList(slot);
      ColoCrypto.decrypt(copy);
      expect(_same(copy, slot), isFalse);
      final (h, b) = ColoCrypto.checksumsValid(copy);
      expect(h && b, isTrue);
      ColoCrypto.encrypt(copy);
      expect(_same(copy, slot), isTrue);
    });

    test('XD: Genius Sonority y sumas', () {
      final slot = xd.sublist(XdCrypto.slotOffset(1), XdCrypto.slotOffset(1) + XdCrypto.slotSize);
      final copy = Uint8List.fromList(slot);
      XdCrypto.decryptSlot(copy);
      final (h, b) = XdCrypto.checksumsValid(copy, 0);
      expect(h && b, isTrue);
      copy[0x500] ^= 1;
      expect(XdCrypto.checksumsValid(copy, 0).$2, isFalse);
      copy[0x500] ^= 1;
      XdCrypto.encryptSlot(copy);
      expect(_same(copy, slot), isTrue);
    });

    test('la ranura activa es la de mayor contador', () {
      expect(ColoCrypto.latest(colo).$1, 1);
      expect(XdCrypto.latest(xd).$1, 1);
    });
  });

  group('detección y lectura', () {
    test('Colosseum sin cabecera', () {
      final s = SaveDetector.read(colo);
      expect(s.game, GameVersion.colosseum);
      expect(s.versionId, 66);
      expect(s.trainer.name, 'WES');
      expect(s.trainer.tid, 31337);
      expect(s.trainer.sid, 4242);
      expect(s.trainer.playTime.inHours, 41);
      expect(s.checksum, ChecksumStatus.valid);
      expect(s.party.map((p) => p.species), [197, 196, 153, 156, 244]);
      expect(s.party.first.nickname, 'NOX');
      expect(s.boxes.length, 3);
      expect(s.boxes.first.name, 'SNAGGED');
      expect(s.boxes.first.count, 3);
    });

    test('XD sin cabecera', () {
      final s = SaveDetector.read(xd);
      expect(s.game, GameVersion.xd);
      expect(s.versionId, 67);
      expect(s.trainer.name, 'MICHAEL');
      expect(s.checksum, ChecksumStatus.valid);
      expect(s.party.map((p) => p.species), [133, 216, 37, 363]);
      expect(s.boxes.length, 8);
    });

    test('.gci con cabecera y región', () {
      final g = SyntheticSaves.gci(xd, GcTitle.xd, region: GcRegion.pal);
      final det = SaveDetector.detect(g);
      expect(det.game, GameVersion.xd);
      expect(det.container, contains('GXXP'));
      expect(det.payload.length, 0x56000);
      expect(SaveDetector.read(g).trainer.name, 'MICHAEL');
    });

    test('Memory Card con dos juegos y bloques no contiguos', () {
      final card = SyntheticSaves.memoryCard([(GcTitle.colosseum, colo), (GcTitle.xd, xd)], scatter: true);
      final mc = GcMemoryCard.tryParse(card)!;
      expect(mc.pokemonEntries.map((e) => e.title), [GcTitle.colosseum, GcTitle.xd]);
      expect(_same(mc.read(mc.pokemonEntries.first), colo), isTrue);
      expect(_same(mc.read(mc.pokemonEntries.last), xd), isTrue);
      final s = SaveDetector.read(card);
      expect(s.game, GameVersion.colosseum);
      expect(s.warnings.single, contains('GXXE'));
      final gci = mc.exportGci(mc.pokemonEntries.last);
      expect(SaveDetector.read(gci).game, GameVersion.xd);
    });

    test('una Memory Card con la suma del directorio rota usa la copia', () {
      final card = SyntheticSaves.memoryCard([(GcTitle.xd, xd)]);
      card[0x2000 + 0x10] ^= 0xFF; // directorio principal dañado
      expect(GcMemoryCard.tryParse(card), isNotNull);
      expect(SaveDetector.read(card).game, GameVersion.xd);
    });

    test('un archivo con el tamaño de Colosseum pero sin estructura no se reconoce', () {
      expect(() => SaveDetector.detect(Uint8List(0x60000)), throwsA(isA<UnsupportedSaveException>()));
    });
  });

  group('round-trip', () {
    for (final (name, bytes) in [
      ('Colosseum', colo),
      ('XD', xd),
      ('GCI', SyntheticSaves.gci(colo, GcTitle.colosseum)),
      ('Memory Card', SyntheticSaves.memoryCard([(GcTitle.colosseum, colo), (GcTitle.xd, xd)], scatter: true)),
    ]) {
      test('$name sin cambios: idéntico byte a byte', () {
        final ed = SaveEditor.open(bytes);
        expect(ed.readOnly, isFalse, reason: ed.integrityIssues.join('; '));
        expect(_same(ed.build(), bytes), isTrue);
        expect(_same(ed.buildRepaired(), bytes), isTrue, reason: 'recalcular sumas no cambia nada');
      });
    }

    test('mover y volver a dejar un Pokémon no cambia el archivo', () {
      final ed = SaveEditor.open(xd);
      ed.swap(const SlotRef.box(0, 0), const SlotRef.box(0, 10));
      ed.swap(const SlotRef.box(0, 10), const SlotRef.box(0, 0));
      ed.set(const SlotRef.party(1), ed.get(const SlotRef.party(1)));
      expect(_same(ed.build(), xd), isTrue);
    });
  });

  group('escritura', () {
    test('entrenador, Pokémon, caja e inventario (Colosseum en Memory Card)', () {
      final card = SyntheticSaves.memoryCard([(GcTitle.colosseum, colo), (GcTitle.xd, xd)]);
      final ed = SaveEditor.open(card);
      ed.writeTrainer(ed.readTrainer().copyWith(name: 'LEO', money: 999999, playTime: const Duration(hours: 50)));
      final pk = ed.get(const SlotRef.party(0))!;
      pk.setNickname('UMBRA');
      ed.set(const SlotRef.party(0), pk);
      ed.setBoxName(1, 'NEW');
      final inv = ed.readInventory()!;
      ed.writeInventory([
        for (final p in inv) p.type == 'Items' ? p.withItems([...p.items, const InventoryItem(19, 7)]) : p,
      ]);
      final out = ed.buildVerified();
      expect(out.length, card.length);
      // Solo cambian los bloques del archivo de Colosseum; XD sigue igual.
      final mc = GcMemoryCard.tryParse(out)!;
      expect(_same(mc.read(mc.pokemonEntries.last), xd), isTrue);
      for (var i = 0; i < 5 * 0x2000; i++) {
        if (out[i] != card[i]) fail('el directorio o la BAT cambiaron (0x${i.toRadixString(16)})');
      }
      final re = SaveEditor.open(out);
      expect(re.readTrainer().name, 'LEO');
      expect(re.readTrainer().money, 999999);
      expect(re.readTrainer().playTime.inHours, 50);
      expect(re.get(const SlotRef.party(0))!.nickname, 'UMBRA');
      expect(re.boxName(1), 'NEW');
      expect(re.readInventory()!.first.items.last, const InventoryItem(19, 7));
      expect(SaveVerifier.checksums(out), isEmpty);
      // El resto del CK3 no cambia.
      final before = (SaveEditor.open(card) as GcEditor).get(const SlotRef.party(0))!.gc!.raw;
      final after = (re as GcEditor).get(const SlotRef.party(0))!.gc!.raw;
      final diff = [for (var i = 0; i < before.length; i++) if (before[i] != after[i]) i];
      expect(diff.every((i) => i >= 0x2E && i < 0x5A), isTrue, reason: 'solo apodo y apodo mostrado: $diff');
    });

    test('un PK3 de GBA se convierte en XK3 con la región del save', () {
      final gba = SaveEditor.open(SyntheticSaves.gen3(party: const [SynthMon(25, level: 20, nickname: 'SPARKY')]));
      final pika = gba.get(const SlotRef.party(0))!;
      final ed = SaveEditor.open(SyntheticSaves.gci(xd, GcTitle.xd, region: GcRegion.pal));
      ed.set(const SlotRef.box(2, 0), pika);
      final out = ed.buildVerified();
      final re = SaveEditor.open(out);
      final got = re.get(const SlotRef.box(2, 0))!;
      expect(got.species, 25);
      expect(got.nickname, 'SPARKY');
      expect(got.pid, pika.pid);
      expect(got.ivs, pika.ivs);
      expect(got.moves, pika.moves);
      expect(got.version, pika.version);
      expect(got.gc!.currentRegion, GcRegion.ntscU, reason: 'la región del save sintético es NTSC-U');
      expect(out.sublist(0, 0x40), SyntheticSaves.gci(xd, GcTitle.xd, region: GcRegion.pal).sublist(0, 0x40));
    });
  });

  group('Pokémon oscuros', () {
    test('Colosseum: id, medidor y purificación en el CK3', () {
      final ed = SaveEditor.open(colo);
      final shadow = ed.get(const SlotRef.party(2))!;
      expect(shadow.gc!.shadowId, 2);
      expect(shadow.gc!.isShadow, isTrue);
      expect(shadow.gc!.purification, 1500);
      final purified = ed.get(const SlotRef.party(3))!;
      expect(purified.gc!.isPurified, isTrue);
      expect(purified.gc!.purification, kColoPurified);
      expect(Ribbons.get(purified, 'RibbonNational'), 1);
      shadow.gc!.setPurified(true);
      Ribbons.set(shadow, 'RibbonNational', 1);
      ed.set(const SlotRef.party(2), shadow);
      final re = SaveEditor.open(ed.buildVerified());
      final got = re.get(const SlotRef.party(2))!;
      expect(got.gc!.isPurified, isTrue);
      expect(Ribbons.get(got, 'RibbonNational'), 1);
    });

    test('XD: estado en la tabla de oscuros del save', () {
      final ed = SaveEditor.open(xd) as GcEditor;
      final vulpix = ed.get(const SlotRef.party(2))!;
      expect(vulpix.gc!.shadowId, 2);
      expect(vulpix.gc!.isShadow, isTrue);
      expect(vulpix.gc!.xdPurification, 1000);
      final teddy = ed.get(const SlotRef.party(1))!;
      expect(teddy.gc!.isPurified, isTrue);
      expect(ed.xdShadowTable.map((e) => e.species), containsAll([216, 37, 363, 296]));
      vulpix.gc!.purification = 123;
      ed.set(const SlotRef.party(2), vulpix);
      final re = SaveEditor.open(ed.buildVerified()) as GcEditor;
      expect(re.get(const SlotRef.party(2))!.gc!.xdPurification, 123);
      expect(re.xdShadowTable.firstWhere((e) => e.id == 2).purification, 123);
    });
  });

  group('Strategy Memo', () {
    test('Colosseum: vistos y capturados', () {
      final dex = SaveEditor.open(colo).pokedex!;
      expect(dex.isSeen(196), isTrue);
      expect(dex.isCaught(196), isTrue);
      expect(dex.isSeen(197), isTrue);
      expect(dex.isCaught(197), isFalse);
      expect(dex.isSeen(1), isFalse);
    });

    test('editar y releer', () {
      final ed = SaveEditor.open(xd);
      final dex = ed.pokedex!;
      expect(dex.counts.seen, 4);
      dex.setSeen(25, true);
      dex.setSeen(133, false);
      final re = SaveEditor.open(ed.buildVerified()).pokedex!;
      expect(re.isSeen(25), isTrue);
      expect(re.isSeen(133), isFalse);
      expect(re.counts.seen, 4);
    });
  });

  group('archivos sueltos', () {
    test('.ck3 y .xk3 ida y vuelta', () {
      final ed = SaveEditor.open(colo);
      final pk = ed.get(const SlotRef.party(4))!;
      final file = GcPkm.toFile(pk, GcKind.ck3);
      expect(file.length, 312);
      expect(_same(file, pk.gc!.raw), isTrue);
      final back = GcPkm.fromFile(GcKind.ck3, file)!;
      expect(back.species, 244);
      expect(back.gc!.shadowId, pk.gc!.shadowId);
      final x = SaveEditor.open(xd).get(const SlotRef.box(0, 0))!;
      expect(GcPkm.fromFile(GcKind.xk3, GcPkm.toFile(x, GcKind.xk3))!.species, 27);
    });
  });
}
