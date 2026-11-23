import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Leyendas Arceus: inventario', () {
    final original = SyntheticSaves.legendsArceus(party: const [SynthMon(722)]);

    test('lee los cuatro bolsillos con capacidad según las mejoras de la bolsa', () {
      final inv = SaveEditor.open(original).readInventory()!;
      expect(inv.map((p) => p.type), ['Items', 'KeyItems', 'PCItems', 'Treasure']);
      expect(inv[0].capacity, 30); // 20 + 10 mejoras
      expect(inv[0].items.single, const InventoryItem(17, 4));
      expect(inv[2].items.single, const InventoryItem(26, 12));
    });

    test('round-trip sin cambios y edición (añadir, quitar, cantidades)', () {
      final e = SaveEditor.open(original);
      expect(e.build(), original);
      final inv = e.readInventory()!;
      e.writeInventory([
        inv[0].withItems([const InventoryItem(17, 999), const InventoryItem(23, 3)]),
        inv[1],
        inv[2].withItems(const []),
        inv[3],
      ]);
      final re = SaveEditor.open(e.build()).readInventory()!;
      expect(re[0].items, [const InventoryItem(17, 999), const InventoryItem(23, 3)]);
      expect(re[2].items, isEmpty);
      expect(SaveDetector.read(e.build()).trainer.name, 'Akari');
    });
  });

  group('Leyendas Z-A: inventario', () {
    final original = SyntheticSaves.legendsZA(party: const [SynthMon(152)]);

    test('lee bolsillos por id de objeto', () {
      final inv = SaveEditor.open(original).readInventory()!;
      expect(inv.map((p) => p.type), containsAll(['Medicine', 'Balls', 'MegaStones', 'KeyItems']));
      expect(inv.firstWhere((p) => p.type == 'Medicine').items.single.count, 5);
      expect(inv.firstWhere((p) => p.type == 'Balls').items.single, const InventoryItem(4, 10));
    });

    test('edición: añade, borra y respeta los máximos', () {
      final e = SaveEditor.open(original);
      expect(e.build(), original);
      final inv = e.readInventory()!;
      final med = inv.firstWhere((p) => p.type == 'Medicine');
      final balls = inv.firstWhere((p) => p.type == 'Balls');
      final mega = inv.firstWhere((p) => p.type == 'MegaStones');
      e.writeInventory([
        med.withItems([const InventoryItem(17, 50), InventoryItem(med.legalItems[1], 2)]),
        balls.withItems(const []),
        mega.withItems([InventoryItem(mega.legalItems.first, 5)]),
      ]);
      final re = SaveEditor.open(e.build()).readInventory()!;
      expect(re.firstWhere((p) => p.type == 'Medicine').items.length, 2);
      expect(re.firstWhere((p) => p.type == 'Balls').items, isEmpty);
      expect(re.firstWhere((p) => p.type == 'MegaStones').items.single.count, 1);
    });
  });
}
