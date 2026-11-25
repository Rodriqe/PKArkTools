import 'dart:io' as io;
import 'dart:math';
import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

/// Integración de eventos y Living Dex con transferencias, ordenar cajas y el
/// formato oficial.
///
/// Con `INTEGRATION_OUT=<carpeta>` escribe además cada Pokémon transferido
/// (leído de vuelta del save de destino) como archivo suelto, para comprobarlo
/// con el oráculo PKHeX (`legal <carpeta>`).
const _src = SynthTrainer(name: 'Prueba', tid: 4242, sid: 31337, gender: 1);
const _dst = SynthTrainer(name: 'Tester', tid: 60123, sid: 999, gender: 0);

Uint8List _save(GameVersion g, SynthTrainer t) => switch (g) {
  GameVersion.platinum => SyntheticSaves.gen4(layout: Gen4Layout.pt, trainer: t),
  GameVersion.black2White2 => SyntheticSaves.gen5(layout: Gen5Layout.b2w2, trainer: _v(t, 22)),
  GameVersion.xy => SyntheticSaves.ctr(layout: CtrLayout.xy, trainer: _v(t, 24)),
  GameVersion.ultraSunUltraMoon => SyntheticSaves.ctr(layout: CtrLayout.usum, trainer: _v(t, 32)),
  GameVersion.swordShield => SyntheticSaves.swordShield(trainer: _v(t, 44)),
  GameVersion.brilliantDiamondShiningPearl => SyntheticSaves.bdsp(trainer: t),
  GameVersion.scarletViolet => SyntheticSaves.scarletViolet(trainer: _v(t, 50)),
  _ => throw ArgumentError('$g'),
};

SynthTrainer _v(SynthTrainer t, int v) => SynthTrainer(name: t.name, tid: t.tid, sid: t.sid, gender: t.gender, versionId: v);

/// Transfiere [mons] de [from] a un save nuevo de [to] (otro entrenador) y los
/// devuelve leídos del save escrito. Los que no pueden ir se omiten.
List<Pkm> _transfer(List<Pkm> mons, GameVersion from, GameVersion to, String tag) {
  final dst = SaveEditor.open(_save(to, _dst));
  final t = dst.readTrainer();
  final trainer = TransferTrainer(name: t.name, tid: t.tid, sid: t.sid, gender: t.gender ?? 0, language: 2);
  final refs = <SlotRef>[];
  var i = 0;
  for (final pk in mons) {
    if (PkTransfer.check(pk, from, to) != null) continue;
    final r = PkTransfer.convert(pk, from, to, trainer: trainer, random: Random(i));
    if (!r.ok) continue;
    final ref = SlotRef.box(i ~/ dst.boxSlotCount, i % dst.boxSlotCount);
    if (ref.box >= dst.boxCount) break;
    dst.writeBoxSlot(ref.box, ref.slot, r.pk);
    refs.add(ref);
    i++;
  }
  final back = SaveEditor.open(dst.build());
  final out = [for (final r in refs) back.get(r)!];
  final dir = io.Platform.environment['INTEGRATION_OUT'];
  if (dir != null) {
    io.Directory(dir).createSync(recursive: true);
    for (var k = 0; k < out.length; k++) {
      io.File('$dir/${tag}_$k.${out[k].format.extension}').writeAsBytesSync(out[k].toFile());
    }
  }
  return out;
}

List<LegalityIssue> _warnings(Pkm pk, GameVersion game) =>
    [for (final i in Legality.check(pk, game)) if (i.severity == LegalitySeverity.warning) i];

void main() {
  group('Pokémon de evento después de una transferencia', () {
    for (final (from, to) in [
      (GameVersion.platinum, GameVersion.black2White2),
      (GameVersion.black2White2, GameVersion.xy),
      (GameVersion.xy, GameVersion.ultraSunUltraMoon),
      (GameVersion.ultraSunUltraMoon, GameVersion.scarletViolet),
      (GameVersion.swordShield, GameVersion.scarletViolet),
      (GameVersion.brilliantDiamondShiningPearl, GameVersion.scarletViolet),
    ]) {
      test('${from.name} → ${to.name}', () {
        final ed = SaveEditor.open(_save(from, _src));
        final t = ed.readTrainer();
        final rnd = Random(3);
        final gifts = [
          for (final g in EventDb.creatableIn(from))
            if (!g.isEgg) g,
        ].take(40).toList();
        expect(gifts, isNotEmpty);
        final made = [for (final g in gifts) EventFactory.create(g, from, t, language: 2, versionId: ed.versionId, random: rnd)];
        final moved = _transfer(made, from, to, 'ev_${from.name}_${to.name}');
        expect(moved, isNotEmpty);
        for (final pk in moved) {
          expect(pk.checksumValid, isTrue);
          expect(pk.fatefulEncounter || pk.format.generation >= 8, isTrue, reason: 'sigue marcado como evento');
          expect(_warnings(pk, to), isEmpty, reason: '${pk.species} ${Legality.check(pk, to)}');
        }
      });
    }
  });

  group('Living Dex', () {
    for (final (from, to) in [
      (GameVersion.ultraSunUltraMoon, GameVersion.swordShield),
      (GameVersion.swordShield, GameVersion.scarletViolet),
      (GameVersion.brilliantDiamondShiningPearl, GameVersion.scarletViolet),
    ]) {
      test('sobrevive a una transferencia ${from.name} → ${to.name}', () {
        final ed = SaveEditor.open(_save(from, _src));
        final plan = LivingDex.plan(ed);
        final mons = LivingDex.generate(ed, plan, random: Random(5)).pokemon.take(120).toList();
        final moved = _transfer(mons, from, to, 'ld_${from.name}_${to.name}');
        expect(moved.length, greaterThan(40));
        for (final pk in moved) {
          expect(pk.checksumValid, isTrue);
          expect(_warnings(pk, to), isEmpty, reason: '${pk.species}-${pk.form} ${Legality.check(pk, to)}');
        }
      });
    }

    test('queda en orden de Pokédex: ordenar cajas por número no mueve nada', () {
      for (final g in [GameVersion.ultraSunUltraMoon, GameVersion.scarletViolet]) {
        final ed = SaveEditor.open(_save(g, _src));
        LivingDex.apply(ed, LivingDex.plan(ed), random: Random(2));
        expect(BoxSorter.plan(ed, BoxSortMode.dex).isNoop, isTrue, reason: '$g');
      }
    });

    test('formato oficial: veredicto coherente para cada Pokémon de la Living Dex de Escarlata/Púrpura', () {
      const game = GameVersion.scarletViolet;
      final ed = SaveEditor.open(_save(game, _src));
      LivingDex.apply(ed, LivingDex.plan(ed), random: Random(4));
      var eligible = 0;
      for (var b = 0; b < ed.boxCount; b++) {
        for (var s = 0; s < ed.boxSlotCount; s++) {
          final pk = ed.get(SlotRef.box(b, s));
          if (pk == null) continue;
          final r = ChampionsFormat.check(pk, game);
          // Un Pokémon generado por la app nunca da avisos de legalidad.
          expect(r.reasons, isNot(contains(ChampionsReason.legalityWarning)), reason: '${pk.species} ${r.detail}');
          if (ChampionsFormat.isMythical(pk.species)) expect(r.reasons, contains(ChampionsReason.mythical));
          if (ChampionsFormat.isRestricted(pk.species)) expect(r.reasons, contains(ChampionsReason.restricted));
          if (r.reasons.isEmpty) eligible++;
        }
      }
      expect(eligible, greaterThan(100));
    });
  });
}
