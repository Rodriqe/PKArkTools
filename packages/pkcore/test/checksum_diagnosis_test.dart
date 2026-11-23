import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

/// Diagnóstico de checksums (bug de la Odin3: todos los saves de Sol/Luna y
/// Ultrasol/Ultraluna salían «checksum mismatch» por la firma del bloque 36).
void main() {
  const team = [SynthMon(722, level: 12), SynthMon(25, level: 30)];
  Uint8List sm() => SyntheticSaves.ctr(layout: CtrLayout.sm, party: team, boxes: const {0: [SynthMon(731)]});
  Uint8List usum() => SyntheticSaves.ctr(layout: CtrLayout.usum, party: team, boxes: const {1: [SynthMon(734)]});

  bool same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  group('MemeCrypto', () {
    test('vector conocido (idéntico a PKHeX MemeCrypto.SignInPlace)', () {
      final d = Uint8List(0x6BE00);
      MemeCrypto.signSave(d, GameVersion.sunMoon);
      final hex = d.sublist(0x6BB00, 0x6BB80).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(
          hex,
          '7b6436b0c98f62380866d9432c2af0ee08ce16a171bda6951aecd95ee1307d61'
          '1c0659da7d255158348d3542bfb9a9ba2ed8a60234c5fc6efe2492afe0fe5075'
          '4f069489115e3b756f8a491be3aafa0cd0f011bdedea432e6045835afe02b870'
          '9cf96e470ef802e70375828ea8433e1a69d2b790a68c7e90f74df9eaf49cc0ee');
      expect(MemeCrypto.isSaveSignatureValid(d, GameVersion.sunMoon), isTrue);
    });

    test('la firma deja de valer si cambia la tabla de checksums', () {
      final d = usum();
      expect(MemeCrypto.isSaveSignatureValid(d, GameVersion.ultraSunUltraMoon), isTrue);
      d[d.length - 0x200 + 0x14 + 6] ^= 0xFF;
      expect(MemeCrypto.isSaveSignatureValid(d, GameVersion.ultraSunUltraMoon), isFalse);
    });

    test('otros juegos no tienen firma', () {
      expect(MemeCrypto.saveSignatureOffset(GameVersion.xy), isNull);
      expect(MemeCrypto.isSaveSignatureValid(Uint8List(16), GameVersion.xy), isTrue);
    });
  });

  group('SM/USUM firmados como el juego', () {
    for (final (name, build) in [('Sol/Luna', sm), ('Ultrasol/Ultraluna', usum)]) {
      test('$name: el bloque 36 con firma no cuenta como checksum incorrecto', () {
        final d = build();
        expect(SaveVerifier.checksumProblems(d), isEmpty);
        final e = SaveEditor.open(d);
        expect(e.damage, SaveDamage.none);
        expect(e.readOnly, isFalse);
      });

      test('$name: sin cambios se devuelve el archivo intacto; con cambios se vuelve a firmar', () {
        final d = build();
        final e = SaveEditor.open(d);
        expect(same(e.build(), d), isTrue);
        e.writeTrainer(e.readTrainer().copyWith(money: 4321));
        final out = e.buildVerified();
        expect(SaveVerifier.checksumProblems(out), isEmpty);
        expect(MemeCrypto.isSaveSignatureValid(out, e.game), isTrue);
        final sig = MemeCrypto.saveSignatureOffset(e.game)!;
        expect(same(out.sublist(sig, sig + 0x80), d.sublist(sig, sig + 0x80)), isFalse);
        expect(SaveEditor.open(out).readTrainer().money, 4321);
      });
    }
  });

  group('daño leve y grave', () {
    test('checksum de cajas incorrecto: leve, dice qué parte y se repara', () {
      final d = usum();
      final bo = d.length - 0x200;
      final boxBlock = CtrBlocks.usum.indexWhere((b) => b.$1 == CtrLayout.usum.box);
      d[bo + 0x14 + boxBlock * 8 + 6] ^= 0x5A;
      final problems = SaveVerifier.checksumProblems(d);
      expect(problems.map((p) => p.part), contains(SavePart.boxes));
      expect(problems.firstWhere((p) => p.part == SavePart.boxes).block, boxBlock);
      // La tabla cambió: la firma tampoco corresponde.
      expect(problems.map((p) => p.part), contains(SavePart.signature));

      final e = SaveEditor.open(d);
      expect(e.damage, SaveDamage.minor);
      expect(e.readOnly, isTrue);
      expect(e.readErrors, isEmpty);
      final fixed = e.buildRepaired();
      expect(SaveVerifier.checksumProblems(fixed), isEmpty);
      final re = SaveEditor.open(fixed);
      expect(re.damage, SaveDamage.none);
      expect(re.readTrainer(), e.readTrainer());
      expect(re.readBoxSlot(1, 0)!.data, e.readBoxSlot(1, 0)!.data);
    });

    test('solo la firma incorrecta: leve', () {
      final d = sm();
      d[MemeCrypto.saveSignatureOffset(GameVersion.sunMoon)! + 0x40] ^= 1;
      final e = SaveEditor.open(d);
      expect(e.checksumProblems.map((p) => p.part), [SavePart.signature]);
      expect(e.damage, SaveDamage.minor);
      expect(MemeCrypto.isSaveSignatureValid(e.buildRepaired(), GameVersion.sunMoon), isTrue);
    });

    test('hash de DBPR incorrecto: leve (hash del archivo) y reparable', () {
      final d = SyntheticSaves.bdsp(party: team);
      d[0xE9818] ^= 0xFF;
      final e = SaveEditor.open(d);
      expect(e.checksumProblems.single.part, SavePart.fileHash);
      expect(e.damage, SaveDamage.minor);
      expect(SaveVerifier.checksumProblems(e.buildRepaired()), isEmpty);
    });

    test('equipo ilegible: grave y no se ofrece reparar', () {
      final d = sm();
      // Número de Pokémon del equipo imposible (máximo 6).
      d[CtrLayout.sm.party + 6 * PkCrypto.size6Party] = 200;
      final e = SaveEditor.open(d);
      expect(e.readErrors, isNotEmpty);
      expect(e.damage, SaveDamage.major);
      expect(e.readOnly, isTrue);
      expect(e.buildRepaired, throwsA(isA<SaveEditException>()));
    });

    test('detalle técnico con bloque, offset y valores', () {
      final d = usum();
      d[d.length - 0x200 + 0x14 + 2 * 8 + 6] ^= 1;
      final p = SaveVerifier.checksumProblems(d).first;
      expect(p.block, 2);
      expect(p.detail, contains('bloque 2'));
      expect(p.detail, contains('guardado 0x'));
      expect(p.detail, contains('calculado 0x'));
    });
  });
}
