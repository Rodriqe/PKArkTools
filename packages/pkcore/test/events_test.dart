import 'dart:io' as io;
import 'dart:math';
import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

/// Base de eventos (Mystery Gift) de PKHeX y creación de Pokémon de evento.
///
/// Con `EVENTS_OUT=<carpeta>` escribe además saves sintéticos con todos los
/// eventos creados (dos entrenadores distintos por formato) para comprobarlos
/// con el oráculo PKHeX (`tool/check_events_pkhex.sh`).
const _trainers = [
  (SynthTrainer(name: 'Prueba', tid: 4242, sid: 31337, gender: 1), 7, false),
  (SynthTrainer(name: 'Tester', tid: 60123, sid: 999, gender: 0), 2, true),
];

/// Save sintético vacío de cada formato con el entrenador [t].
(GameVersion, Uint8List) syntheticFor(PkFormat f, SynthTrainer t) => switch (f) {
      PkFormat.pk3 => (GameVersion.emerald, SyntheticSaves.gen3(trainer: t)),
      PkFormat.pk4 => (GameVersion.heartGoldSoulSilver, SyntheticSaves.gen4(layout: Gen4Layout.hgss, trainer: t)),
      PkFormat.pk5 => (GameVersion.black2White2, SyntheticSaves.gen5(layout: Gen5Layout.b2w2, trainer: _v(t, 22))),
      PkFormat.pk6 => (GameVersion.omegaRubyAlphaSapphire, SyntheticSaves.ctr(layout: CtrLayout.oras, trainer: _v(t, 26))),
      PkFormat.pk7 => (GameVersion.ultraSunUltraMoon, SyntheticSaves.ctr(layout: CtrLayout.usum, trainer: _v(t, 32))),
      PkFormat.pb7 => (GameVersion.letsGo, SyntheticSaves.letsGo(trainer: _v(t, 42))),
      PkFormat.pk8 => (GameVersion.swordShield, SyntheticSaves.swordShield(trainer: _v(t, 44))),
      PkFormat.pb8 => (GameVersion.brilliantDiamondShiningPearl, SyntheticSaves.bdsp(trainer: t)),
      PkFormat.pa8 => (GameVersion.legendsArceus, SyntheticSaves.legendsArceus(trainer: t)),
      PkFormat.pk9 => (GameVersion.scarletViolet, SyntheticSaves.scarletViolet(trainer: _v(t, 50))),
      PkFormat.pa9 => (GameVersion.legendsZA, SyntheticSaves.legendsZA(trainer: t)),
      _ => throw ArgumentError(f),
    };

SynthTrainer _v(SynthTrainer t, int v) =>
    SynthTrainer(name: t.name, tid: t.tid, sid: t.sid, gender: t.gender, versionId: v);

void main() {
  group('base de eventos', () {
    final all = EventDb.all;
    test('todos los eventos de PKHeX (Gen 3–9) con plantilla legal', () {
      expect(all.length, greaterThan(2900));
      final dbs = {for (final g in all) g.db};
      expect(dbs, containsAll(['wc3', 'pcny', 'pcjp', 'pcd', 'pgf', 'wc6', 'wc7', 'wb7', 'wc8', 'wb8', 'wa8', 'wc9', 'wa9']));
      final creatable = all.where((g) => g.canCreate).length;
      expect(creatable, greaterThan(all.length - 10));
      for (final g in all) {
        expect(Species.isValid(g.species), isTrue, reason: '$g');
        if (!g.canCreate) continue;
        final pk = g.template()!;
        expect(pk.species, g.species, reason: '$g');
        expect(pk.checksumValid, isTrue, reason: '$g');
      }
    });

    test('datos fijos: Mew de Gen 3 (MYSTRY) y tarjetas con fecha', () {
      final mew = all.firstWhere((g) => g.db == 'wc3' && g.species == 151 && g.fixedOtName == 'MYSTRY');
      expect(mew.shiny, EventShiny.never);
      expect(mew.distribution, EventDistribution.gen3);
      expect(mew.template()!.otName, 'MYSTRY');
      expect(mew.cardExtension, isNull);
      final withYear = all.where((g) => g.year != null).length;
      expect(withYear, greaterThan(1500));
      final home = all.where((g) => g.distribution == EventDistribution.home);
      expect(home, isNotEmpty);
    });

    test('regiones e idiomas', () {
      final jp = all.where((g) => g.regions.contains(EventRegion.japan)).length;
      final intl = all.where((g) => g.regions.contains(EventRegion.international)).length;
      final kor = all.where((g) => g.regions.contains(EventRegion.korea)).length;
      expect(jp, greaterThan(300));
      expect(intl, greaterThan(300));
      expect(kor, greaterThan(50));
    });

    test('tarjeta en bruto: se reconoce al importarla (también con bytes cambiados)', () {
      final g = all.firstWhere((g) => g.db == 'wc7' && g.canCreate);
      final raw = g.rawCard!;
      expect(EventDb.byRawCard(raw), same(g));
      expect(EventCards.identify('wc7', raw), same(g));
      final tocada = Uint8List.fromList(raw)..[0x4C] ^= 0xFF;
      expect(EventCards.identify('wc7', tocada), same(g));
      // .wc7full: cabecera de redistribución y la tarjeta al final.
      final full = Uint8List(0x310)..setRange(0x208, 0x310, raw);
      expect(EventCards.identify('wc7full', full), same(g));
      expect(EventCards.identify('wc7', Uint8List(0x108)), isNull);
      expect(EventCards.fileName(g, 'Mr. Mime'), endsWith('.wc7'));
      for (final db in ['pcd', 'pgf', 'wc6', 'wb7', 'wc8', 'wb8', 'wa8', 'wc9', 'wa9']) {
        final x = all.firstWhere((e) => e.db == db);
        final ext = x.cardExtension!;
        expect(EventCards.identify(ext, x.rawCard!), same(x), reason: db);
      }
      final pcd = all.firstWhere((e) => e.db == 'pcd');
      expect(EventCards.identify('pgt', Uint8List.sublistView(pcd.rawCard!, 0, 0x104)), isNotNull);
      expect(all.firstWhere((e) => e.db == 'wc3').cardExtension, isNull);
    });
  });

  group('explorador: filtros y datos fijos', () {
    String es(int s) => Species.name(s, SpeciesLanguage.es);
    String en(int s) => Species.name(s, SpeciesLanguage.en);
    final all = EventDb.all;
    test('filtros', () {
      final mew = const EventFilter(text: 'mew').apply(all, nameEs: es, nameEn: en);
      expect(mew, isNotEmpty);
      expect(mew.every((g) => g.species == 151 || g.species == 150 || es(g.species).toLowerCase().contains('mew') || g.title.toLowerCase().contains('mew')), isTrue);
      final jp4 = const EventFilter(generation: 4, region: EventRegion.japan).apply(all, nameEs: es, nameEn: en);
      expect(jp4, isNotEmpty);
      expect(jp4.every((g) => g.generation == 4 && g.languages.contains(1)), isTrue);
      final shiny = const EventFilter(shiny: true, generation: 8).apply(all, nameEs: es, nameEn: en);
      expect(shiny.every((g) => g.shiny != EventShiny.never), isTrue);
      final swsh = const EventFilter(creatableIn: GameVersion.swordShield).apply(all, nameEs: es, nameEn: en);
      expect(swsh, isNotEmpty);
      expect(swsh.every((g) => g.format == PkFormat.pk8), isTrue);
      final y2020 = const EventFilter(year: 2020).apply(all, nameEs: es, nameEn: en);
      expect(y2020, isNotEmpty);
      final home = const EventFilter(distribution: EventDistribution.home).apply(all, nameEs: es, nameEn: en);
      expect(home.every((g) => g.isHome), isTrue);
      expect(const EventFilter().isEmpty, isTrue);
      expect(eventLanguageName(7), 'Español');
    });

    test('datos fijos de la ficha', () {
      final mew = all.firstWhere((g) => g.db == 'wc3' && g.fixedOtName == 'MYSTRY');
      final d = EventDetails.of(mew)!;
      expect(d.otName, 'MYSTRY');
      expect(d.level, 10);
      expect(d.moves, contains(1)); // Destructor
      expect(d.displayId, '06930');
      // Algún evento con los 6 IV fijos y alguno con naturaleza fija.
      expect(all.where((g) => g.canCreate).map(EventDetails.of).any((x) => x != null && x.fixedIvs.every((v) => v != null)), isTrue);
      expect(all.where((g) => g.canCreate && g.generation >= 6).map(EventDetails.of).any((x) => x?.fixedNature != null), isTrue);
      // Cintas de evento (Clásica, Evento…) en las plantillas de Gen 6+.
      expect(all.where((g) => g.generation >= 6 && g.canCreate).map(EventDetails.of).any((x) => x!.ribbons.isNotEmpty), isTrue);
      final recv = all.firstWhere((g) => g.recipientOt && g.recipientId && g.canCreate);
      expect(EventDetails.of(recv)!.otName, isNull);
      expect(EventDetails.of(recv)!.displayId, isNull);
    });
  });

  group('crear desde un evento', () {
    final rnd = Random(7);
    for (final f in [PkFormat.pk3, PkFormat.pk4, PkFormat.pk5, PkFormat.pk6, PkFormat.pk7, PkFormat.pb7, PkFormat.pk8, PkFormat.pb8, PkFormat.pa8, PkFormat.pk9, PkFormat.pa9]) {
      test('${f.extension}: datos del receptor y regla de variocolor', () {
        final (game, raw) = syntheticFor(f, _trainers.first.$1);
        final ed = SaveEditor.open(raw);
        final t = ed.readTrainer();
        final gifts = EventDb.creatableIn(game);
        expect(gifts, isNotEmpty);
        for (final g in gifts) {
          final pk = EventFactory.create(g, game, t, language: 7, versionId: ed.versionId, random: rnd);
          expect(pk.species, g.species, reason: '$g');
          if (g.recipientOt && !(f == PkFormat.pk3 && pk.language == 1)) expect(pk.otName, t.name.length > f.maxTrainerNameLength ? anything : t.name, reason: '$g');
          if (g.recipientId) expect((pk.tid, pk.sid), (t.tid, t.sid), reason: '$g');
          if (g.shiny == EventShiny.never) expect(pk.isShiny, isFalse, reason: '$g');
          if (g.shiny.isShiny && f.generation >= 5) expect(pk.isShiny, isTrue, reason: '$g');
          expect(pk.checksumValid, isTrue);
          // Legalidad de pkcore: el evento se reconoce y no hay ni un aviso
          // (PKHeX da por legales todos estos: tool/check_events_pkhex.sh).
          expect(EventMatch.find(pk), contains(g), reason: '$g');
          expect(Legality.check(pk, game), isEmpty, reason: '$g');
        }
      });
    }
  });

  group('reconocer eventos al validar', () {
    test('un Pokémon con el OT o el lugar cambiados ya no es el evento', () {
      final (game, raw) = syntheticFor(PkFormat.pk6, _trainers.first.$1);
      final ed = SaveEditor.open(raw);
      final g = EventDb.creatableIn(game).firstWhere((g) => !g.recipientOt && !g.isEgg && g.species == 151);
      final pk = EventFactory.create(g, game, ed.readTrainer(), random: Random(1));
      expect(EventMatch.best(pk), isNotNull);
      final otro = pk.clone()..otName = 'Hacker';
      expect(EventMatch.find(otro), isNot(contains(g)));
      final lugar = pk.clone()..metLocation = 8;
      expect(EventMatch.find(lugar), isNot(contains(g)));
    });

    test('movimiento especial de evento sin marca fatídica (Metang de Gen 3 con Alivio)', () {
      final (game, raw) = syntheticFor(PkFormat.pk3, _trainers.first.$1);
      final ed = SaveEditor.open(raw);
      final g = EventDb.creatableIn(game).firstWhere((g) => g.species == 375);
      final pk = EventFactory.create(g, game, ed.readTrainer(), random: Random(1));
      expect(pk.fatefulEncounter, isFalse);
      expect([for (final i in Legality.check(pk, game)) i.code], isNot(contains(LegalityCode.moveNotLearnable)));
    });
  });

  final out = io.Platform.environment['EVENTS_OUT'];
  test('archivos para el oráculo PKHeX', skip: out == null ? 'sin EVENTS_OUT' : null, () {
    io.Directory(out!).createSync(recursive: true);
    for (final f in [PkFormat.pk3, PkFormat.pk4, PkFormat.pk5, PkFormat.pk6, PkFormat.pk7, PkFormat.pb7, PkFormat.pk8, PkFormat.pb8, PkFormat.pa8, PkFormat.pk9, PkFormat.pa9]) {
      for (var ti = 0; ti < _trainers.length; ti++) {
        final (st, lang, shiny) = _trainers[ti];
        final (game, raw) = syntheticFor(f, st);
        final ed = SaveEditor.open(raw);
        for (final g in EventDb.creatableIn(game)) {
          final pk = EventFactory.create(g, game, ed.readTrainer(),
              language: lang, versionId: ed.versionId, shiny: shiny && EventFactory.canBeShiny(g) ? true : null, random: Random(g.id));
          io.File('$out/ev_${g.db}_${g.dbIndex}_$ti.${f.extension}').writeAsBytesSync(pk.toFile());
        }
      }
    }
  });
}
