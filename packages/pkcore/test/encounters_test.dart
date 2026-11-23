import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

Pkm _mon(PkFormat f, GameVersion game, {required int species, required int version, required int location, required int met, int level = 30}) {
  final pk = Pkm.fromDecrypted(f, Uint8List(f.partySize))..dataGame = game;
  pk.species = species;
  pk.version = version;
  pk.metLocation = location;
  pk.metLevel = met;
  pk.exp = Species.expForLevel(species, level);
  pk.ball = 4;
  return pk;
}

List<LegalityIssue> _enc(Pkm pk, GameVersion game, [DataLanguage lang = DataLanguage.es]) => [
      for (final i in Legality.check(pk, game, lang: lang))
        if (i.area == LegalityArea.encounter) i,
    ];

void main() {
  group('Tablas de encuentros (PKHeX)', () {
    test('hay tablas para todas las versiones de Gen 3 a Gen 9', () {
      for (final v in [1, 2, 3, 4, 5, 7, 8, 10, 11, 12, 20, 21, 22, 23, 24, 25, 26, 27, 30, 31, 32, 33, 42, 43, 44, 45, 47, 48, 49, 50, 51, 52]) {
        expect(EncounterTables.forVersion(v), isNotEmpty, reason: 'versión $v');
      }
    });

    test('cadena evolutiva y nombres de lugares', () {
      expect(EncounterTables.evolutionChain(26), [26, 25, 172]); // Raichu ← Pikachu ← Pichu
      expect(EncounterTables.evolutionChain(1), [1]);
      final first = EncounterTables.forVersion(24).firstWhere((e) => e.species == 25 && e.kind == EncounterKind.wild);
      expect(EncounterTables.locationName(24, first.location), isNot(startsWith('#')));
      expect(EncounterTables.locationName(24, first.location, DataLanguage.en), 'Santalune Forest');
      expect(EncounterTables.locationName(24, first.location), 'Bosque de Novarte');
    });

    test('X/Y: Pikachu salvaje correcto no genera avisos de encuentro', () {
      final slot = EncounterTables.forVersion(24).firstWhere((e) => e.species == 25 && e.kind == EncounterKind.wild);
      final pk = _mon(PkFormat.pk6, GameVersion.xy, species: 25, version: 24, location: slot.location, met: slot.minLevel);
      expect(_enc(pk, GameVersion.xy), isEmpty);
      // Evolucionado después: Raichu con los mismos datos de encuentro también es válido.
      pk.species = 26;
      expect(_enc(pk, GameVersion.xy), isEmpty);
    });

    test('X/Y: nivel de encuentro imposible → aviso con corrección segura', () {
      final slot = EncounterTables.forVersion(24).firstWhere((e) => e.species == 25 && e.kind == EncounterKind.wild);
      final pk = _mon(PkFormat.pk6, GameVersion.xy, species: 25, version: 24, location: slot.location, met: 60, level: 70);
      final issues = _enc(pk, GameVersion.xy);
      expect(issues.single.code, LegalityCode.encounterWrongLevel);
      expect(issues.single.severity, LegalitySeverity.warning);
      expect(issues.single.detail(), contains('Corregir pone el nivel de encuentro'));
      final fixed = Legality.applyFix(pk, issues.single, GameVersion.xy)!;
      expect(_enc(fixed, GameVersion.xy), isEmpty);
      expect(fixed.metLevel, lessThanOrEqualTo(fixed.level));
    });

    test('X/Y: lugar equivocado → aviso que lista los lugares posibles, sin corrección', () {
      final pk = _mon(PkFormat.pk6, GameVersion.xy, species: 25, version: 24, location: 10, met: 5);
      final issue = _enc(pk, GameVersion.xy).single;
      expect(issue.code, LegalityCode.encounterWrongLocation);
      expect(issue.fix, isNull);
      expect(issue.detail(), contains('niv.'));
      expect(issue.detail(), contains('Bosque de Novarte'));
      expect(_enc(pk, GameVersion.xy, DataLanguage.en).single.detail(DataLanguage.en), contains('Santalune Forest'));
    });

    test('X/Y: Mew sin marca de evento no se encuentra en el juego', () {
      final pk = _mon(PkFormat.pk6, GameVersion.xy, species: 151, version: 24, location: 14, met: 5);
      expect(_enc(pk, GameVersion.xy).single.code, LegalityCode.encounterNotInGame);
    });

    test('estáticos y regalos: Zygarde nivel 70 en X/Y y el inicial de Sol/Luna', () {
      final z = EncounterTables.forVersion(24).firstWhere((e) => e.species == 718 && e.kind == EncounterKind.static);
      expect(z.minLevel, 70);
      final pk = _mon(PkFormat.pk6, GameVersion.xy, species: 718, version: 24, location: z.location, met: 70, level: 70);
      expect(_enc(pk, GameVersion.xy), isEmpty);
      final rowlet = EncounterTables.forVersion(30).firstWhere((e) => e.species == 722);
      expect(rowlet.kind, EncounterKind.gift);
      expect(rowlet.minLevel, 5);
    });

    test('huevos, eventos y lugares especiales no se comprueban', () {
      final pk = _mon(PkFormat.pk6, GameVersion.xy, species: 151, version: 24, location: 30001, met: 5);
      expect(_enc(pk, GameVersion.xy), isEmpty, reason: 'intercambio/lugar especial');
      pk.metLocation = 14;
      pk.data..[0xD8] = 60002 & 0xFF..[0xD9] = 60002 >> 8; // eclosionado
      expect(_enc(pk, GameVersion.xy), isEmpty);
    });

    test('Escarlata/Púrpura: tablas parciales → aviso informativo', () {
      final pk = _mon(PkFormat.pk9, GameVersion.scarletViolet, species: 151, version: 50, location: 6, met: 5);
      final issue = _enc(pk, GameVersion.scarletViolet).single;
      expect(issue.severity, LegalitySeverity.notice);
      expect(issue.detail(), contains('informativo'));
    });

    test('Leyendas Arceus y Z-A tienen salvajes con lugar y nivel', () {
      final la = EncounterTables.forVersion(47).firstWhere((e) => e.species == 399); // Bidoof
      final pk = _mon(PkFormat.pa8, GameVersion.legendsArceus, species: 399, version: 47, location: la.location, met: la.minLevel);
      pk.ball = 28;
      expect(_enc(pk, GameVersion.legendsArceus), isEmpty);
      expect(EncounterTables.forVersion(52).where((e) => e.species == 25), isNotEmpty);
    });
  });

  group('lugar sin nombre', () {
    test('nunca se muestra como «#0»', () {
      expect(EncounterTables.locationName(44, 0), 'un lugar desconocido');
      expect(EncounterTables.locationName(44, 0, DataLanguage.en), 'an unknown place');
      expect(EncounterTables.locationName(44, 65000), isNot(contains('#')));
    });

    test('los Pokémon de ejemplo de Espada no tienen avisos de lugar de encuentro', () {
      final raw = SyntheticSaves.demoSet()['Espada_main']!;
      final ed = SaveEditor.open(raw);
      final mons = [
        for (var i = 0; i < 6; i++) ed.get(SlotRef.party(i)),
        for (var b = 0; b < ed.boxCount; b++)
          for (var i = 0; i < ed.boxSlotCount; i++) ed.get(SlotRef.box(b, i)),
      ].whereType<Pkm>().toList();
      expect(mons.map((p) => p.species), containsAll([818, 890]));
      for (final pk in mons) {
        final issues = Legality.check(pk, GameVersion.swordShield)
            .where((i) => i.code == LegalityCode.encounterWrongLocation || i.code == LegalityCode.encounterWrongLevel);
        expect(issues, isEmpty, reason: 'especie ${pk.species}: ${issues.map((i) => i.detail()).join('; ')}');
        expect(pk.metLocation, isNot(0));
      }
    });
  });
}
