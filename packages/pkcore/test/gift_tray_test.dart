import 'dart:io' as io;

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

/// Bandeja del Regalo Misterioso (Gen 6–7). Con `GIFTS_OUT=<carpeta>` escribe los
/// saves con tarjetas para comprobarlos con el oráculo PKHeX (`gifts <save>`).
void main() {
  final out = io.Platform.environment['GIFTS_OUT'];
  final saves = [
    (GameVersion.xy, SyntheticSaves.ctr(layout: CtrLayout.xy, trainer: const SynthTrainer(name: 'Serena', versionId: 24))),
    (GameVersion.omegaRubyAlphaSapphire, SyntheticSaves.ctr(layout: CtrLayout.oras, trainer: const SynthTrainer(name: 'May', versionId: 26))),
    (GameVersion.sunMoon, SyntheticSaves.ctr(layout: CtrLayout.sm, trainer: const SynthTrainer(name: 'Moon', versionId: 30))),
    (GameVersion.ultraSunUltraMoon, SyntheticSaves.ctr(layout: CtrLayout.usum, trainer: const SynthTrainer(name: 'Elio', versionId: 32))),
  ];

  for (final (game, raw) in saves) {
    test('${game.code}: recibe tarjetas en la bandeja y se releen tras guardar', () {
      final ed = SaveEditor.open(raw);
      final tray = GiftTray.of(ed)!;
      expect(tray.capacity, game.generation == 6 ? 24 : 48);
      final gifts = [for (final g in EventDb.all) if (GiftTray.accepts(g, game) && g.canCreate) g].take(3).toList();
      expect(gifts.length, 3);
      for (final g in gifts) {
        ReceiveGiftCardEdit(g.rawCard!, title: g.title).applyTo(ed);
      }
      expect(() => ReceiveGiftCardEdit(gifts.first.rawCard!).applyTo(ed), throwsA(isA<SaveEditException>()));
      final bytes = ed.build();
      final again = GiftTray.of(SaveEditor.open(bytes))!;
      final cards = again.cards.whereType<Object>().toList();
      expect(cards.length, 3);
      expect(again.cards[1], gifts[1].rawCard);
      if (out != null) {
        io.Directory(out).createSync(recursive: true);
        io.File('$out/${game.code}.sav').writeAsBytesSync(bytes);
      }
    });
  }

  test('sin bandeja en Gen 3–5 ni en Switch', () {
    expect(GiftTray.of(SaveEditor.open(SyntheticSaves.gen3())), isNull);
    expect(GiftTray.of(SaveEditor.open(SyntheticSaves.swordShield())), isNull);
    expect(GiftTray.dbFor(GameVersion.scarletViolet), isNull);
  });
}
