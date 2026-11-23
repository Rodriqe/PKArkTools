import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:test/test.dart';

/// Huecos vacíos tal como los escribe el juego (Gen 4+): estructura a cero
/// cifrada. Hallado con un save real de SoulSilver: el editor los leía como
/// Pokémon de especie 0 y, al vaciar un hueco, escribía ceros literales, que el
/// juego descifra como basura (Huevo Malo).
int _indexOf(Uint8List hay, Uint8List needle) {
  outer:
  for (var i = 0; i + needle.length <= hay.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

void main() {
  test('el hueco vacío cifrado de Gen 4 no son ceros y se descifra como vacío', () {
    final blank = Pkm.blankEncrypted(PkFormat.pk4);
    expect(blank.length, PkCrypto.size4Stored);
    expect(blank.any((b) => b != 0), isTrue, reason: 'el cifrado con semilla 0 produce datos no nulos');
    final pk = Pkm.fromEncrypted(PkFormat.pk4, blank)!;
    expect(pk.species, 0);
    expect(pk.checksumValid, isTrue);
  });

  final cases = <(String, Uint8List Function())>[
    ('DP', () => SyntheticSaves.gen4(layout: Gen4Layout.dp, party: const [SynthMon(25)], boxes: const {0: [SynthMon(152), SynthMon(155)]})),
    ('HGSS', () => SyntheticSaves.gen4(layout: Gen4Layout.hgss, party: const [SynthMon(25)], boxes: const {0: [SynthMon(152), SynthMon(155)]})),
    ('BW', () => SyntheticSaves.gen5(party: const [SynthMon(25)], boxes: const {0: [SynthMon(495), SynthMon(498)]})),
    ('ORAS', () => SyntheticSaves.ctr(party: const [SynthMon(25)], boxes: const {0: [SynthMon(252), SynthMon(255)]})),
    ("Let's Go", () => SyntheticSaves.letsGo(party: const [SynthMon(25)], boxes: const {0: [SynthMon(133), SynthMon(1)]})),
  ];

  for (final (name, build) in cases) {
    test('$name: los huecos vacíos cifrados se leen como vacíos y vaciar escribe el vacío cifrado', () {
      final bytes = build();
      final ed = SaveEditor.open(Uint8List.fromList(bytes));
      expect(ed.readOnly, isFalse, reason: '${ed.integrityIssues}');
      // Ningún hueco vacío aparece como Pokémon de especie 0.
      for (var b = 0; b < ed.boxCount; b++) {
        for (var s = 0; s < ed.boxSlotCount; s++) {
          final pk = ed.get(SlotRef.box(b, s));
          if (pk != null) expect(pk.species, isNot(0), reason: 'caja $b hueco $s');
        }
      }
      // Primer Pokémon de caja que se puede vaciar (en Let's Go el equipo vive en las cajas).
      final occupied = [
        for (var s = 0; s < ed.boxSlotCount; s++)
          if (ed.get(SlotRef.box(0, s)) != null) SlotRef.box(0, s),
      ];
      final party = {for (final p in ed.party) p.pid};
      final target = occupied.firstWhere((r) => !party.contains(ed.get(r)!.pid));
      final other = occupied.lastWhere((r) => r != target);
      final first = ed.get(target)!;
      final stored = ed.format == PkFormat.pb7 ? first.clone().encryptParty() : first.clone().encryptStored();
      final ofs = _indexOf(ed.build(), stored);
      expect(ofs, greaterThanOrEqualTo(0));

      ed.set(target, null);
      final out = ed.build();
      final blank = Pkm.blankEncrypted(ed.format, party: ed.format == PkFormat.pb7);
      if (ed.format == PkFormat.pb7) {
        // Let's Go compacta el almacenamiento al exportar: el vacío queda al final.
        expect(_indexOf(out, blank), greaterThanOrEqualTo(0));
      } else {
        expect(out.sublist(ofs, ofs + blank.length), blank);
      }
      final re = SaveEditor.open(out);
      expect(re.readOnly, isFalse);
      if (ed.format == PkFormat.pb7) {
        expect(re.summary().boxedCount, SaveDetector.read(bytes).boxedCount - 1);
      } else {
        expect(re.get(target), isNull);
        expect(re.get(other)?.species, ed.get(other)?.species);
      }
    });
  }
}
