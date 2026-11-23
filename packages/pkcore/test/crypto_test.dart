import 'dart:typed_data';

import 'package:pkcore/pkcore.dart';
import 'package:test/test.dart';

Uint8List _pattern(int n, [int seed = 1]) =>
    Uint8List.fromList(List.generate(n, (i) => (i * 31 + seed * 17) & 0xFF));

void main() {
  group('SCXorShift32', () {
    test('es determinista y depende de la clave', () {
      final a = SCXorShift32(0x12345678);
      final b = SCXorShift32(0x12345678);
      final c = SCXorShift32(0x12345679);
      final sa = List.generate(32, (_) => a.next());
      final sb = List.generate(32, (_) => b.next());
      final sc = List.generate(32, (_) => c.next());
      expect(sa, sb);
      expect(sa, isNot(sc));
    });

    test('next32 compone 4 bytes little-endian', () {
      final a = SCXorShift32(0xCAFEBABE);
      final b = SCXorShift32(0xCAFEBABE);
      final bytes = [b.next(), b.next(), b.next(), b.next()];
      expect(a.next32(), bytes[0] | bytes[1] << 8 | bytes[2] << 16 | bytes[3] << 24);
    });
  });

  group('SCBlock', () {
    test('serializa y vuelve a leer todos los tipos', () {
      final blocks = [
        SCBlock.object(0x0D66012C, _pattern(0x400)),
        SCBlock.boolean(0x11111111, true),
        SCBlock.boolean(0x22222222, false),
        SCBlock.value(0x33333333, SCTypeCode.uint32, 0xA1B2C3D4),
        SCBlock.value(0x44444444, SCTypeCode.byte, 0x7F),
        SCBlock.array(0x55555555, SCTypeCode.uint16, _pattern(64)),
      ];
      final payload = Uint8List.fromList(blocks.expand((b) => b.serialize()).toList());
      final read = SCBlock.readAll(payload);
      expect(read.length, blocks.length);
      expect(read[0].type, SCTypeCode.object);
      expect(read[0].data, blocks[0].data);
      expect(read[1].boolValue, isTrue);
      expect(read[2].boolValue, isFalse);
      expect(read[3].intValue, 0xA1B2C3D4);
      expect(read[4].intValue, 0x7F);
      expect(read[5].subType, SCTypeCode.uint16);
      expect(read[5].data, blocks[5].data);
    });

    test('los datos serializados están enmascarados', () {
      final data = Uint8List(64);
      final ser = SCBlock.object(0xABCDEF01, data).serialize();
      expect(ser.sublist(9).every((b) => b == 0), isFalse);
    });

    test('bloque truncado lanza FormatException', () {
      final ser = SCBlock.object(0x01020304, _pattern(100)).serialize();
      expect(() => SCBlock.readAll(Uint8List.sublistView(ser, 0, 50)), throwsFormatException);
    });
  });

  group('SwishCrypto', () {
    final blocks = [
      SCBlock.object(0xF25C070E, _pattern(0x110, 3)),
      SCBlock.value(0x01, SCTypeCode.uint64, 0x0102030405060708),
      SCBlock.object(0x0D66012C, _pattern(0x3000, 9)),
    ];

    test('encrypt produce un hash válido y decrypt recupera los bloques', () {
      final enc = SwishCrypto.encrypt(blocks);
      expect(SwishCrypto.isHashValid(enc), isTrue);
      final dec = SwishCrypto.decrypt(enc);
      expect(dec.map((b) => b.key), blocks.map((b) => b.key));
      expect(dec[0].data, blocks[0].data);
      expect(dec[2].data, blocks[2].data);
      expect(dec[1].intValue, 0x0102030405060708);
    });

    test('un solo bit alterado invalida el hash', () {
      final enc = SwishCrypto.encrypt(blocks);
      enc[100] ^= 0x01;
      expect(SwishCrypto.isHashValid(enc), isFalse);
    });

    test('el xorpad es una involución de periodo 0x7F', () {
      final d = _pattern(0x7F * 3 + 5);
      final copy = Uint8List.fromList(d);
      SwishCrypto.cryptStaticXorpad(d);
      expect(d, isNot(copy));
      expect(d[0] ^ copy[0], d[0x7F] ^ copy[0x7F]);
      SwishCrypto.cryptStaticXorpad(d);
      expect(d, copy);
    });
  });

  group('PkCrypto', () {
    Uint8List entity(int size, int pv) {
      final d = _pattern(size, pv & 0xFF);
      d[0] = pv & 0xFF;
      d[1] = (pv >> 8) & 0xFF;
      d[2] = (pv >> 16) & 0xFF;
      d[3] = (pv >> 24) & 0xFF;
      return d;
    }

    test('PK3: encrypt/decrypt son inversos para los 24 órdenes', () {
      for (var sv = 0; sv < 24; sv++) {
        final d = entity(80, sv + 24 * 1000);
        final enc = PkCrypto.encrypt3(d);
        expect(enc, isNot(d));
        expect(PkCrypto.decrypt3(enc), d, reason: 'sv=$sv');
      }
    });

    test('PK4/5: encrypt/decrypt son inversos (almacenado y equipo)', () {
      for (var i = 0; i < 32; i++) {
        final pv = i << 13;
        for (final size in [PkCrypto.size4Stored, PkCrypto.size4Party, PkCrypto.size5Party]) {
          final d = entity(size, pv);
          expect(PkCrypto.decrypt45(PkCrypto.encrypt45(d)), d, reason: 'i=$i size=$size');
        }
      }
    });

    test('PK6/7 y PK8/9: encrypt/decrypt son inversos', () {
      for (var i = 0; i < 32; i++) {
        final ec = (i << 13) | 0x1234;
        for (final size in [PkCrypto.size6Stored, PkCrypto.size6Party]) {
          final d = entity(size, ec);
          expect(PkCrypto.decrypt67(PkCrypto.encrypt67(d)), d);
        }
        for (final size in [PkCrypto.size8Stored, PkCrypto.size8Party]) {
          final d = entity(size, ec);
          expect(PkCrypto.decrypt8(PkCrypto.encrypt8(d)), d);
        }
      }
    });
  });

  group('Checksums', () {
    test('CRC16-CCITT coincide con el vector estándar "123456789"', () {
      final data = Uint8List.fromList('123456789'.codeUnits);
      expect(Checksums.crc16Ccitt(data), 0x29B1);
    });

    test('checkSum32 pliega a 16 bits', () {
      final d = Uint8List(8)
        ..[0] = 0xFF
        ..[1] = 0xFF
        ..[2] = 0x01;
      // 0x0001FFFF -> 0xFFFF + 0x0001 = 0x0000 (truncado)
      expect(Checksums.checkSum32(d, 0, 8), (0x1FFFF + 0x1) & 0xFFFF);
    });
  });
}
