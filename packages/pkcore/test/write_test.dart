import 'dart:typed_data';

import 'package:crypto/crypto.dart' show md5;
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/src/edit/nds_editors.dart' show Gen5Blocks;
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

/// Un fixture sintético por formato de escritura.
class Fixture {
  const Fixture(this.name, this.game, this.build, {this.hasBoxNames = true, this.inventory = true});
  final String name;
  final GameVersion game;
  final Uint8List Function() build;
  final bool hasBoxNames;
  final bool inventory;
}

const _team = [SynthMon(25, level: 30), SynthMon(6, level: 40, nickname: 'DRACO'), SynthMon(131, level: 22)];
const _gbTeam = [SynthMon(25, level: 30), SynthMon(6, level: 40), SynthMon(131, level: 22)];

final fixtures = <Fixture>[
  Fixture('RBY', GameVersion.redBlue,
      () => SyntheticSaves.gen1(party: _gbTeam, boxes: const {0: [SynthMon(1, level: 5)], 3: [SynthMon(4, level: 7)]}),
      hasBoxNames: false),
  Fixture('Amarillo (RTC)', GameVersion.yellow,
      () => SyntheticSaves.withRtcFooter(SyntheticSaves.gen1(yellow: true, party: _gbTeam), 0x10),
      hasBoxNames: false),
  Fixture('Oro/Plata', GameVersion.goldSilver,
      () => SyntheticSaves.gen2(party: _gbTeam, boxes: const {0: [SynthMon(152, level: 5)], 2: [SynthMon(155)]})),
  Fixture('Cristal', GameVersion.crystal, () => SyntheticSaves.gen2(crystal: true, party: _gbTeam)),
  Fixture('Rubí/Zafiro', GameVersion.rubySapphire,
      () => SyntheticSaves.gen3(game: GameVersion.rubySapphire, party: _team, boxes: const {0: [SynthMon(252)]})),
  Fixture('Esmeralda', GameVersion.emerald,
      () => SyntheticSaves.gen3(party: _team, boxes: const {0: [SynthMon(252), null, SynthMon(255)], 5: [SynthMon(258)]})),
  Fixture('RFVH', GameVersion.fireRedLeafGreen,
      () => SyntheticSaves.gen3(game: GameVersion.fireRedLeafGreen, party: _team, boxes: const {1: [SynthMon(1)]})),
  Fixture('Diamante/Perla', GameVersion.diamondPearl,
      () => SyntheticSaves.gen4(layout: Gen4Layout.dp, party: _team, boxes: const {0: [SynthMon(387)]})),
  Fixture('Platino (.dsv)', GameVersion.platinum,
      () => SyntheticSaves.withDesmumeFooter(SyntheticSaves.gen4(party: _team, boxes: const {2: [SynthMon(390)]}))),
  Fixture('HGSS', GameVersion.heartGoldSoulSilver,
      () => SyntheticSaves.gen4(layout: Gen4Layout.hgss, party: _team, boxes: const {0: [SynthMon(152)]})),
  Fixture('Negro/Blanco', GameVersion.blackWhite,
      () => SyntheticSaves.gen5(party: _team, boxes: const {0: [SynthMon(495)]})),
  Fixture('Negro 2/Blanco 2', GameVersion.black2White2,
      () => SyntheticSaves.gen5(layout: Gen5Layout.b2w2, party: _team, boxes: const {1: [SynthMon(498)]})),
  Fixture('X/Y', GameVersion.xy,
      () => SyntheticSaves.ctr(layout: CtrLayout.xy, party: _team, boxes: const {0: [SynthMon(650)]})),
  Fixture('ROZA', GameVersion.omegaRubyAlphaSapphire,
      () => SyntheticSaves.ctr(party: _team, boxes: const {0: [SynthMon(252)]})),
  Fixture('Sol/Luna', GameVersion.sunMoon,
      () => SyntheticSaves.ctr(layout: CtrLayout.sm, party: _team, boxes: const {0: [SynthMon(722)]})),
  Fixture('USUL', GameVersion.ultraSunUltraMoon,
      () => SyntheticSaves.ctr(layout: CtrLayout.usum, party: _team, boxes: const {0: [SynthMon(725)]})),
  Fixture("Let's Go", GameVersion.letsGo,
      () => SyntheticSaves.letsGo(party: _team, boxes: const {0: [SynthMon(133, level: 12)]}),
      hasBoxNames: false),
  Fixture('Espada/Escudo', GameVersion.swordShield,
      () => SyntheticSaves.swordShield(party: _team, boxes: const {0: [SynthMon(810)], 1: [SynthMon(813)]})),
  Fixture('DBPR', GameVersion.brilliantDiamondShiningPearl,
      () => SyntheticSaves.bdsp(party: _team, boxes: const {0: [SynthMon(387)]})),
  Fixture('Leyendas Arceus', GameVersion.legendsArceus,
      () => SyntheticSaves.legendsArceus(party: _team, boxes: const {0: [SynthMon(722)]})),
  Fixture('Escarlata/Púrpura', GameVersion.scarletViolet,
      () => SyntheticSaves.scarletViolet(party: _team, boxes: const {0: [SynthMon(906)]})),
  Fixture('Leyendas Z-A', GameVersion.legendsZA,
      () => SyntheticSaves.legendsZA(party: _team, boxes: const {0: [SynthMon(152)]})),
];

/// Comprueba los checksums propios del formato sobre un archivo exportado.
void expectChecksumsValid(GameVersion game, Uint8List original, Uint8List out) {
  final save = SaveDetector.read(out);
  expect(save.checksum, isNot(ChecksumStatus.invalid), reason: 'checksum global');
  final payload = SaveDetector.detect(out).payload;
  final origPayload = SaveDetector.detect(original).payload;
  switch (game) {
    case GameVersion.blackWhite || GameVersion.black2White2:
      final blocks = game == GameVersion.blackWhite ? Gen5Blocks.bw : Gen5Blocks.b2w2;
      for (final (ofs, len, chk, mirror) in blocks.take(blocks.length - 1)) {
        var changed = false;
        for (var i = ofs; i < ofs + len; i++) {
          if (payload[i] != origPayload[i]) changed = true;
        }
        if (!changed) continue;
        final crc = Checksums.crc16Ccitt(payload, ofs, ofs + len);
        expect(payload[chk] | (payload[chk + 1] << 8), crc, reason: 'bloque 0x${ofs.toRadixString(16)}');
        expect(payload[mirror] | (payload[mirror + 1] << 8), crc);
      }
    case GameVersion.xy ||
          GameVersion.omegaRubyAlphaSapphire ||
          GameVersion.sunMoon ||
          GameVersion.ultraSunUltraMoon ||
          GameVersion.letsGo:
      final blocks = switch (game) {
        GameVersion.xy => CtrBlocks.xy,
        GameVersion.omegaRubyAlphaSapphire => CtrBlocks.oras,
        GameVersion.sunMoon => CtrBlocks.sm,
        GameVersion.ultraSunUltraMoon => CtrBlocks.usum,
        _ => CtrBlocks.lgpe,
      };
      final bo = game == GameVersion.letsGo ? 0xB8800 - 0x200 : payload.length - 0x200;
      // SM/USUM: el CRC del bloque 36 se calcula con la firma MemeCrypto a cero.
      final data = Uint8List.fromList(payload);
      final sig = MemeCrypto.saveSignatureOffset(game);
      if (sig != null) data.fillRange(sig, sig + 0x80, 0);
      for (var i = 0; i < blocks.length; i++) {
        final (ofs, len) = blocks[i];
        final stored = payload[bo + 0x14 + i * 8 + 6] | (payload[bo + 0x14 + i * 8 + 7] << 8);
        final crc = switch (game.generation) {
          6 => Checksums.crc16Ccitt(data, ofs, ofs + len),
          _ when game == GameVersion.letsGo => Checksums.crc16Arc(data, ofs, ofs + len, 0),
          _ => (~Checksums.crc16Arc(data, ofs, ofs + len, 0xFFFF)) & 0xFFFF,
        };
        expect(stored, crc, reason: 'bloque BEEF $i');
      }
      if (sig != null) expect(MemeCrypto.isSaveSignatureValid(payload, game), isTrue, reason: 'firma MemeCrypto');
    case GameVersion.swordShield || GameVersion.scarletViolet || GameVersion.legendsArceus || GameVersion.legendsZA:
      expect(SwishCrypto.isHashValid(payload), isTrue);
    case GameVersion.brilliantDiamondShiningPearl:
      final copy = Uint8List.fromList(payload)..fillRange(0xE9818, 0xE9828, 0);
      expect(payload.sublist(0xE9818, 0xE9828), md5.convert(copy).bytes);
    default:
  }
}

void main() {
  for (final f in fixtures) {
    group(f.name, () {
      late Uint8List original;
      setUp(() => original = f.build());

      test('round-trip sin cambios = bytes idénticos', () {
        final editor = SaveEditor.open(original);
        expect(editor.game, f.game);
        expect(editor.build(), original);
        // Aplicar una lista vacía con el escritor también es idéntico.
        expect(const EditorSaveWriter().apply(SaveDetector.read(original), const []), original);
      });

      test('editar Pokémon del equipo → releer', () {
        final editor = SaveEditor.open(original);
        final ctx = GameDataTable.forGame(f.game).context;
        final pk = editor.get(const SlotRef.party(0))!;
        expect(pk.species, 25);
        pk.level = 55;
        pk.setNickname(f.game.generation <= 2 ? 'SPARK' : 'Chispa');
        pk.setIv(1, pk.format.maxIv);
        pk.setIv(5, pk.format.maxIv);
        pk.setEv(5, 100);
        pk.setMove(1, 85, context: ctx); // Rayo
        if (f.game.generation >= 2) pk.heldItem = f.game.generation == 2 ? 0x20 : (f.game.generation == 3 ? 13 : 234);
        pk.setShiny(true);
        pk.friendship = 200;
        pk.refreshPartyStats();
        editor.set(const SlotRef.party(0), pk);
        final out = editor.build();

        expect(out.length, original.length, reason: 'el contenedor se conserva');
        expectChecksumsValid(f.game, original, out);
        final save = SaveDetector.read(out);
        expect(save.party.length, 3);
        expect(save.party.first.species, 25);
        expect(save.party.first.level, 55);
        expect(save.party.first.isShiny, isTrue);

        final again = SaveEditor.open(out).get(const SlotRef.party(0))!;
        expect(again.nickname, f.game.generation <= 2 ? 'SPARK' : 'Chispa');
        expect(again.ivs[1], pk.format.maxIv);
        if (f.game.generation > 2) expect(again.ivs[5], pk.format.maxIv); // en GB los DVs definen el variocolor
        expect(again.evs[5], 100);
        expect(again.move(1), 85);
        expect(again.pp(1), MoveData.maxPp(85, ctx, again.ppUps(1)));
        expect(again.isShiny, isTrue);
        if (f.game.generation >= 2) expect(again.friendship, 200);
        expect(again.checksumValid, isTrue);
        expect(again.partyStats.first, greaterThan(0));
      });

      test('mover, clonar y borrar en cajas', () {
        final editor = SaveEditor.open(original);
        final first = editor.get(const SlotRef.party(0))!;
        final box1Empty = editor.get(const SlotRef.box(1, 0)) == null;
        // Intercambiar el 3.º del equipo con el primer hueco de la caja 2.
        editor.swap(const SlotRef.party(2), const SlotRef.box(1, 0));
        // Clonar un Pokémon de caja en otra caja.
        editor.set(const SlotRef.box(2, 0), first);
        final out = editor.build();
        expectChecksumsValid(f.game, original, out);
        final save = SaveDetector.read(out);
        if (f.game == GameVersion.letsGo) {
          // Let's Go guarda una lista plana que el juego mantiene compacta.
          final all = [for (final b in save.boxes) ...b.slots.whereType<PokemonSummary>()];
          expect(all.where((p) => p.species == first.species).length, 2);
          expect(all.any((p) => p.species == 131), isTrue);
        } else {
          expect(save.boxes[1].slots.whereType<PokemonSummary>().first.species, 131);
          expect(save.boxes[2].slots.first?.species, first.species);
          expect(save.party.length, box1Empty ? 2 : 3);
        }

        // Borrar el clon.
        final e2 = SaveEditor.open(out)..set(const SlotRef.box(2, 0), null);
        final s2 = SaveDetector.read(e2.build());
        if (f.game != GameVersion.letsGo) expect(s2.boxes[2].count, 0);
      });

      test('entrenador: nombre, dinero, IDs y tiempo', () {
        final editor = SaveEditor.open(original);
        final t = editor.readTrainer();
        final fields = editor.trainerFields;
        editor.writeTrainer(t.copyWith(
          name: f.game.generation <= 2 ? 'BLUE' : 'Kai',
          money: 123456,
          tid: 4242,
          sid: fields.contains(TrainerField.sid) ? 2424 : null,
          playTime: const Duration(hours: 77, minutes: 7, seconds: 7),
        ));
        final out = editor.build();
        expectChecksumsValid(f.game, original, out);
        final save = SaveDetector.read(out);
        expect(save.trainer.name, f.game.generation <= 2 ? 'BLUE' : 'Kai');
        expect(save.trainer.tid, 4242);
        if (fields.contains(TrainerField.sid)) expect(save.trainer.sid, 2424);
        expect(save.trainer.playTime, const Duration(hours: 77, minutes: 7, seconds: 7));
        final re = SaveEditor.open(out).readTrainer();
        if (fields.contains(TrainerField.money)) expect(re.money, 123456);
      });

      if (f.hasBoxNames) {
        test('renombrar caja', () {
          final editor = SaveEditor.open(original);
          if (!editor.canRenameBoxes) return;
          editor.setBoxName(3, 'FAVS');
          final save = SaveDetector.read(editor.build());
          expect(save.boxes[3].name, 'FAVS');
        });
      }

      if (f.inventory) {
        test('inventario: añadir y releer', () {
          final editor = SaveEditor.open(original);
          final pouches = editor.readInventory();
          expect(pouches, isNotNull);
          final p = pouches!.firstWhere((p) => p.type == 'Items' || p.type == 'Medicine');
          final item = p.legalItems.isNotEmpty ? p.legalItems.first : 1;
          final updated = [
            for (final x in pouches)
              x == p ? x.withItems([...x.items.where((e) => e.item != item), InventoryItem(item, 7)]) : x,
          ];
          editor.writeInventory(updated);
          final out = editor.build();
          expectChecksumsValid(f.game, original, out);
          final re = SaveEditor.open(out).readInventory()!.firstWhere((x) => x.type == p.type);
          expect(re.items.any((e) => e.item == item && e.count == 7), isTrue);
        });
      }

      test('exportar e importar Pokémon suelto', () {
        final editor = SaveEditor.open(original);
        final pk = editor.get(const SlotRef.party(1))!;
        final file = pk.toFile();
        final back = Pkm.fromFile(pk.format, file)!;
        expect(back.species, pk.species);
        expect(back.nickname, pk.nickname);
        expect(back.exp, pk.exp);
        final target = editor.firstEmptyBoxSlot(4)!;
        editor.set(target, back);
        final save = SaveDetector.read(editor.build());
        final all = [for (final b in save.boxes) ...b.slots.whereType<PokemonSummary>()];
        expect(all.any((s) => s.species == pk.species), isTrue);
      });
    });
  }

  group('Pkm', () {
    test('variocolor por generación y conservación de naturaleza en Gen 3/4', () {
      final editor = SaveEditor.open(SyntheticSaves.gen4(party: _team));
      final pk = editor.get(const SlotRef.party(0))!;
      final nature = pk.nature;
      pk.setShiny(true);
      expect(pk.isShiny, isTrue);
      expect(pk.nature, nature);
      pk.setShiny(false);
      expect(pk.isShiny, isFalse);
      expect(pk.nature, nature);
      pk.nature = 3;
      expect(pk.nature, 3);
    });

    test('Gen 8+: variocolor cuadrado y menta', () {
      final editor = SaveEditor.open(SyntheticSaves.swordShield(party: _team));
      final pk = editor.get(const SlotRef.party(0))!;
      pk.setShiny(true, square: true);
      expect(pk.isSquareShiny, isTrue);
      pk.nature = 10;
      pk.statNature = 3;
      expect(pk.nature, 10);
      expect(pk.statNature, 3);
    });

    test('estadísticas calculadas (Pikachu nivel 50, IV 31, neutral)', () {
      final editor = SaveEditor.open(SyntheticSaves.scarletViolet(party: _team));
      final pk = editor.get(const SlotRef.party(0))!;
      pk.level = 50;
      pk.setIvs(const [31, 31, 31, 31, 31, 31]);
      pk.setEvs(const [0, 0, 0, 0, 0, 0]);
      pk.nature = 0; // Fuerte (neutra)
      pk.statNature = 0;
      // Pikachu: 35/55/40/50/50/90.
      expect(pk.computeStats(), [110, 75, 60, 70, 70, 110]);
    });

    test('tera tipo en SV', () {
      final editor = SaveEditor.open(SyntheticSaves.scarletViolet(party: _team));
      final pk = editor.get(const SlotRef.party(0))!;
      pk.teraTypeOriginal = 12;
      pk.teraType = 15;
      expect(pk.teraType, 15);
      editor.set(const SlotRef.party(0), pk);
      final again = SaveEditor.open(editor.build()).get(const SlotRef.party(0))!;
      expect(again.teraType, 15);
      expect(again.teraTypeOriginal, 12);
    });

    test('Gen 1/2: DVs, stat exp y variocolor', () {
      final editor = SaveEditor.open(SyntheticSaves.gen2(party: _gbTeam));
      final pk = editor.get(const SlotRef.party(0))!;
      pk.setShiny(true);
      expect(pk.isShiny, isTrue);
      pk.setEv(0, 65535);
      expect(pk.evs[0], 65535);
      pk.setIv(0, 15);
      expect(pk.ivs[0], 15);
    });
  });

  group('SaveEdits', () {
    test('EditorSaveWriter aplica la lista de ediciones', () {
      final raw = SyntheticSaves.gen3(party: _team, boxes: const {0: [SynthMon(252)]});
      final save = SaveDetector.read(raw);
      final editor = SaveEditor.open(raw);
      final pk = editor.get(const SlotRef.party(0))!..level = 70;
      final out = const EditorSaveWriter().apply(save, [
        SetSlotEdit(const SlotRef.party(0), pk),
        const SwapSlotsEdit(SlotRef.box(0, 0), SlotRef.box(0, 5)),
        SetTrainerEdit(editor.readTrainer().copyWith(money: 999)),
        const SetBoxNameEdit(0, 'TOP'),
      ]);
      final s = SaveDetector.read(out);
      expect(s.party.first.level, 70);
      expect(s.boxes[0].slots[5]?.species, 252);
      expect(s.boxes[0].name, 'TOP');
      expect(SaveEditor.open(out).readTrainer().money, 999);
    });

    test('el equipo no puede quedarse vacío', () {
      final editor = SaveEditor.open(SyntheticSaves.gen3(party: const [SynthMon(25)]));
      expect(() => editor.swap(const SlotRef.party(0), const SlotRef.box(0, 0)), throwsA(isA<SaveEditException>()));
    });

    test('formato incompatible se rechaza', () {
      final gen3 = SaveEditor.open(SyntheticSaves.gen3(party: _team));
      final sv = SaveEditor.open(SyntheticSaves.scarletViolet(party: _team));
      expect(() => gen3.set(const SlotRef.box(0, 0), sv.get(const SlotRef.party(0))), throwsA(isA<SaveEditException>()));
    });
  });
}
