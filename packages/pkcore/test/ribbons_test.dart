import 'dart:typed_data';


import 'package:pkcore/pkcore.dart';
import 'package:pkcore/src/data/generated/ribbon_data.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

const _mon = [SynthMon(25, level: 30)];

/// Saves sintéticos de cada formato con cintas.
final Map<String, Uint8List Function()> _saves = {
  'pk3': () => SyntheticSaves.gen3(party: _mon),
  'pk4': () => SyntheticSaves.gen4(party: _mon),
  'pk5': () => SyntheticSaves.gen5(party: _mon),
  'pk6': () => SyntheticSaves.ctr(party: _mon),
  'pk7': () => SyntheticSaves.ctr(layout: CtrLayout.usum, trainer: const SynthTrainer(name: 'Elio', versionId: 32), party: _mon),
  'pb7': () => SyntheticSaves.letsGo(party: _mon),
  'pk8': () => SyntheticSaves.swordShield(party: _mon),
  'pb8': () => SyntheticSaves.bdsp(party: _mon),
  'pa8': () => SyntheticSaves.legendsArceus(party: _mon),
  'pk9': () => SyntheticSaves.scarletViolet(party: _mon),
  'pa9': () => SyntheticSaves.legendsZA(party: _mon),
};

void main() {
  test('cada cinta de cada formato tiene ficha (categoría, nombre y descripción)', () {
    for (final entry in kRibbonLayouts.entries) {
      for (final (name, _, _, _) in entry.value) {
        if (name.startsWith('Has')) continue;
        final info = Ribbons.info(name);
        expect(info, isNotNull, reason: '${entry.key}: $name sin ficha');
        expect(info!.name(DataLanguage.es), isNot(startsWith('Ribbon')), reason: name);
        expect(info.name(DataLanguage.en), isNotEmpty);
        expect(info.description(DataLanguage.es), isNot('Cinta especial.'), reason: name);
      }
    }
  });

  test('número de cintas por formato (PKHeX)', () {
    int n(PkFormat f) => Ribbons.forFormat(f).length;
    expect(n(PkFormat.pk3), 17); // 12 banderas + 5 contadores de concurso
    expect(n(PkFormat.pk4), 80);
    expect(n(PkFormat.pk6), 46);
    expect(n(PkFormat.pk7), 50);
    expect(n(PkFormat.pk8), 111); // 109 + 2 contadores de recuerdo
    expect(n(PkFormat.pk9), 111);
    expect(Ribbons.supports(PkFormat.pk2), isFalse);
  });

  for (final MapEntry(key: fmt, value: build) in _saves.entries) {
    test('$fmt: dar y quitar cada cinta sobrevive a guardar y reabrir', () {
      final editor = SaveEditor.open(build());
      final pk = editor.get(const SlotRef.party(0))!;
      expect(pk.format.extension, fmt);
      final before = Ribbons.of(pk).where((s) => s.has).length;
      expect(before, 0);
      final list = Ribbons.forFormat(pk.format);
      // Patrón alterno para detectar bits cruzados.
      for (var i = 0; i < list.length; i++) {
        final r = list[i];
        Ribbons.set(pk, r.key, i.isEven ? (r.isCount ? (r.maxCount > 4 ? 3 : 2) : 1) : 0);
      }
      if (Ribbons.supportsAffixed(pk.format)) Ribbons.setAffixed(pk, 'RibbonChampionKalos');
      editor.set(const SlotRef.party(0), pk);
      final reopened = SaveEditor.open(editor.build()).get(const SlotRef.party(0))!;
      expect(reopened.checksumValid, isTrue);
      expect(reopened.species, 25);
      for (var i = 0; i < list.length; i++) {
        final r = list[i];
        final want = i.isEven ? (r.isCount ? (r.maxCount > 4 ? 3 : 2) : 1) : 0;
        expect(Ribbons.get(reopened, r.key), want, reason: '$fmt ${r.key}');
      }
      if (Ribbons.supportsAffixed(pk.format)) expect(Ribbons.affixed(reopened), 'RibbonChampionKalos');
      Ribbons.removeAll(reopened);
      expect(Ribbons.countOwned(reopened), 0);
      expect(Ribbons.affixed(reopened), isNull);
    });
  }

  test('contadores de recuerdo marcan la bandera «tiene la cinta» (Gen 6+)', () {
    final pk = SaveEditor.open(_saves['pk8']!()).get(const SlotRef.party(0))!;
    Ribbons.set(pk, 'RibbonCountMemoryContest', 99);
    expect(Ribbons.get(pk, 'RibbonCountMemoryContest'), 40); // recortado al máximo
    expect(pk.data[0x38] & (1 << 5), isNot(0));
    Ribbons.set(pk, 'RibbonCountMemoryContest', 0);
    expect(pk.data[0x38] & (1 << 5), 0);
  });

  test('legalidad: cinta de Kalos en un Pokémon de Espada es imposible; Galar no', () {
    final pk = SaveEditor.open(_saves['pk8']!()).get(const SlotRef.party(0))!;
    pk.version = 44;
    Ribbons.set(pk, 'RibbonChampionKalos', 1);
    Ribbons.set(pk, 'RibbonChampionGalar', 1);
    final issues = Ribbons.check(pk);
    expect(issues.map((i) => (i.kind, i.ribbon?.key)), contains((RibbonIssueKind.unobtainable, 'RibbonChampionKalos')));
    expect(issues.any((i) => i.ribbon?.key == 'RibbonChampionGalar'), isFalse);
    // Un Pokémon de X que llegó a Espada sí pudo ganarla.
    pk.version = 24;
    expect(Ribbons.check(pk).where((i) => i.kind == RibbonIssueKind.unobtainable), isEmpty);
  });

  test('legalidad: dos marcas de encuentro y marca sin capturarlo allí', () {
    final pk = SaveEditor.open(_saves['pk9']!()).get(const SlotRef.party(0))!;
    pk.version = 50;
    Ribbons.set(pk, 'RibbonMarkRainy', 1);
    Ribbons.set(pk, 'RibbonMarkCurry', 1); // solo Espada/Escudo
    final kinds = Ribbons.check(pk).map((i) => i.kind).toSet();
    expect(kinds, containsAll([RibbonIssueKind.multipleMarks, RibbonIssueKind.markOrigin]));
  });

  test('dar todas las válidas: Gen 3 en Esmeralda solo da cintas de Hoenn', () {
    final pk = SaveEditor.open(_saves['pk3']!()).get(const SlotRef.party(0))!;
    pk.version = 3;
    final given = Ribbons.giveAllValid(pk);
    expect(given, greaterThan(5));
    expect(Ribbons.get(pk, 'RibbonCountG3Cool'), 4);
    expect(Ribbons.get(pk, 'RibbonChampionG3'), 1);
    expect(Ribbons.get(pk, 'RibbonCountry'), 0); // evento
    expect(Ribbons.check(pk), isEmpty);
  });

  test('dar todas las válidas: Pokémon de Platino en Escarlata', () {
    final pk = SaveEditor.open(_saves['pk9']!()).get(const SlotRef.party(0))!;
    pk.version = 12;
    Ribbons.giveAllValid(pk);
    expect(Ribbons.get(pk, 'RibbonChampionSinnoh'), 1);
    expect(Ribbons.get(pk, 'RibbonChampionKalos'), 1);
    expect(Ribbons.get(pk, 'RibbonCountMemoryContest'), 40);
    expect(Ribbons.get(pk, 'RibbonMarkRainy'), 0); // marca de encuentro: no se da
    expect(Ribbons.check(pk).where((i) => !i.isInfo), isEmpty);
  });

  test('un huevo no puede tener cintas', () {
    final pk = SaveEditor.open(_saves['pk8']!()).get(const SlotRef.party(0))!;
    pk.isEgg = true;
    Ribbons.set(pk, 'RibbonEffort', 1);
    expect(Ribbons.check(pk).single.kind, RibbonIssueKind.egg);
    expect(Ribbons.giveAllValid(pk), 0);
  });
}
