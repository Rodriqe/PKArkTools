import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

void main() {
  test('fechas de encuentro y huevo sobreviven a guardar y reabrir', () {
    final ed = SaveEditor.open(SyntheticSaves.swordShield(party: const [SynthMon(25, level: 20)]));
    final pk = ed.get(const SlotRef.party(0))!
      ..metDate = DateTime(2021, 3, 14)
      ..eggDate = DateTime(2020, 12, 1)
      ..eggLocation = 60002;
    pk.refreshChecksum();
    ed.set(const SlotRef.party(0), pk);
    final back = SaveEditor.open(ed.build()).get(const SlotRef.party(0))!;
    expect(back.metDate, DateTime(2021, 3, 14));
    expect(back.eggDate, DateTime(2020, 12, 1));
    expect(back.eggLocation, 60002);
    expect(back.hatchedFromEgg, isTrue);
  });

  test('traspasos según origen y formato', () {
    final pk = SaveEditor.open(SyntheticSaves.scarletViolet(party: const [SynthMon(25)])).get(const SlotRef.party(0))!;
    pk.version = 12; // Platino → Escarlata
    expect(pk.transfers, [TransferStep.pokeTransfer, TransferStep.transporter, TransferStep.bank, TransferStep.home]);
    pk.version = 3; // Esmeralda
    expect(pk.transfers.first, TransferStep.palPark);
    pk.version = 44; // Espada → Escarlata
    expect(pk.transfers, [TransferStep.home]);
    pk.version = 50;
    expect(pk.transfers, isEmpty);
    pk.version = 39; // Oro (Consola Virtual)
    expect(pk.transfers.first, TransferStep.virtualConsole);
  });

  test('lugares válidos según las tablas de encuentros', () {
    final opts = OriginPlace.locations(44, 25, DataLanguage.es);
    expect(opts, isNotEmpty);
    expect(opts.every((o) => o.encounter), isTrue);
    final all = OriginPlace.locations(44, 25, DataLanguage.es, all: true);
    expect(all.length, greaterThan(opts.length));
    expect(OriginPlace.originVersions(PkFormat.pk4), containsAll([1, 3, 10, 12, 7]));
    expect(OriginPlace.originVersions(PkFormat.pk4), isNot(contains(20)));
    expect(OriginPlace.originVersions(PkFormat.pk9), containsAll([3, 44, 47, 52, 39]));
    // Leyendas Arceus: solo Balls de Hisui (y Extraña/Gloria) aunque esté en Escarlata.
    expect(OriginPlace.balls(47, GameVersion.scarletViolet), everyElement(anyOf(16, 27, inInclusiveRange(28, 37))));
  });
}
