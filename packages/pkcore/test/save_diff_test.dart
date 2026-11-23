import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

void main() {
  for (final (name, build) in [
    ('Esmeralda', () => SyntheticSaves.gen3(party: const [SynthMon(25, level: 30), SynthMon(6, level: 40)], boxes: const {0: [SynthMon(1)]})),
    ('Espada/Escudo', () => SyntheticSaves.swordShield(party: const [SynthMon(25, level: 30), SynthMon(6, level: 40)], boxes: const {0: [SynthMon(1)]})),
    ('Cristal', () => SyntheticSaves.gen2(crystal: true, party: const [SynthMon(25, level: 30), SynthMon(6, level: 40)], boxes: const {0: [SynthMon(1)]})),
  ]) {
    test('$name: diferencias de entrenador, equipo, cajas, inventario y Pokédex', () {
      final before = build();
      final e = SaveEditor.open(before);
      expect(SaveDiff.compare(SaveEditor.open(before), e).isEmpty, isTrue);

      e.writeTrainer(e.readTrainer().copyWith(money: 4321));
      final pika = e.get(const SlotRef.party(0))!..level = 55;
      pika.setMove(1, 85, context: GameDataTable.forGame(e.game).context);
      e.set(const SlotRef.party(0), pika);
      e.swap(const SlotRef.box(0, 0), const SlotRef.box(1, 3)); // mover
      e.set(const SlotRef.box(2, 0), e.get(const SlotRef.party(1))); // clon = entra uno nuevo con la misma identidad
      final inv = e.readInventory()!;
      e.writeInventory([inv.first.withItems([InventoryItem(inv.first.legalItems.first, 3)]), ...inv.skip(1)]);
      e.pokedex?.setCaught(e.pokedex!.contains(150) ? 150 : 25, true);

      final diff = SaveDiff.compare(SaveEditor.open(before), SaveEditor.open(e.build()));
      expect(diff.trainer.map((f) => f.field), contains('money'));
      final changed = diff.mons.firstWhere((m) => m.kind == MonChangeKind.changed);
      expect(changed.fields.map((f) => f.field), containsAll(['level', 'moves']));
      expect(diff.mons.where((m) => m.kind == MonChangeKind.moved).single.to?.box, 1); // GB compacta las cajas
      expect(diff.mons.where((m) => m.kind == MonChangeKind.added), hasLength(1));
      expect(diff.items, isNotEmpty);
      if (e.pokedex != null) expect(diff.dex.single.after.caught, isTrue);
    });
  }

  test('Pokémon borrado aparece como salido', () {
    final before = SyntheticSaves.scarletViolet(party: const [SynthMon(25), SynthMon(6)], boxes: const {0: [SynthMon(1)]});
    final e = SaveEditor.open(before)..set(const SlotRef.box(0, 0), null);
    final diff = SaveDiff.compare(SaveEditor.open(before), SaveEditor.open(e.build()));
    expect(diff.mons.single.kind, MonChangeKind.removed);
    expect(diff.mons.single.mon.species, 1);
  });
}
