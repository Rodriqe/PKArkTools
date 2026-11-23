import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkarktools/data/sprites/sprite_cache.dart';
import 'package:pkarktools/data/sprites/sprite_manifest.g.dart';
import 'package:pkarktools/data/sprites/sprites.dart';
import 'package:pkarktools/ui/common/sprite_image.dart';

/// Iconos que «no quedaban bien guardados» tras «Descargar todos» y sprites
/// desproporcionados. Todo con un servidor falso: cada icono se sirve como un
/// PNG válido del tamaño exacto que dice el índice (como el commit fijo de PKHeX).

/// PNG de 1×1 válido.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, //
  0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, 0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc(List<int> b) {
  var c = 0xFFFFFFFF;
  for (final x in b) {
    c = _crcTable[(c ^ x) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// El PNG de 1×1 con un bloque tEXt de relleno hasta medir exactamente [size].
Uint8List _pngOfSize(int size) {
  final pad = size - _png.length - 12;
  if (pad < 0) return _png;
  final body = [0x74, 0x45, 0x58, 0x74, ...List.filled(pad, 0x41)]; // 'tEXt' + datos
  final crc = _crc(body);
  final chunk = [
    pad >> 24 & 0xFF, pad >> 16 & 0xFF, pad >> 8 & 0xFF, pad & 0xFF, ...body,
    crc >> 24 & 0xFF, crc >> 16 & 0xFF, crc >> 8 & 0xFF, crc & 0xFF,
  ];
  final iend = _png.length - 12;
  return Uint8List.fromList([..._png.sublist(0, iend), ...chunk, ..._png.sublist(iend)]);
}

/// Carpeta del repositorio → grupo, para saber qué icono pide una URL.
final _groupByDir = {for (final e in kSpriteSources.entries) e.value.$2.split('/').last: e.key};

/// Bytes que serviría el servidor para [u]: el tamaño exacto del índice.
Uint8List _serve(Uri u) {
  final seg = u.pathSegments;
  final ref = SpriteRef(_groupByDir[seg[seg.length - 2]]!, seg.last.substring(0, seg.last.length - 4));
  return _pngOfSize(Sprites.bytesOfRef(ref));
}

File _file(Directory d, SpriteRef r) => File('${d.path}/${r.group}_${r.name}.png');

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('sprites-repair'));
  tearDown(() => tmp.deleteSync(recursive: true));

  final total = SpriteCache.allRefs().length;
  const b1 = SpriteRef('pokemon', 'sbulbasaur'), b4 = SpriteRef('pokemon', 'scharmander'), b7 = SpriteRef('pokemon', 'ssquirtle');

  group('validación de lo que se guarda', () {
    test('PNG completo: firma, IHDR e IEND; rechaza vacíos, cortados y páginas de error', () {
      expect(SpriteCache.isCompletePng(_png), isTrue);
      expect(SpriteCache.isCompletePng(_pngOfSize(500)), isTrue);
      expect(SpriteCache.isCompletePng(Uint8List(0)), isFalse);
      expect(SpriteCache.isCompletePng(_png.sublist(0, _png.length - 5)), isFalse);
      expect(SpriteCache.isCompletePng(Uint8List.fromList('<html>404</html>'.codeUnits)), isFalse);
    });

    test('una respuesta cortada (o de otro tamaño) no se guarda: se reintenta y, si persiste, cuenta como fallo', () async {
      var calls = 0;
      final cache = SpriteCache(
          directory: () async => tmp,
          retryDelay: Duration.zero,
          fetcher: (u) async {
            calls++;
            final full = _serve(u);
            return calls == 1 ? full.sublist(0, full.length - 20) : full; // la 1.ª llega cortada
          });
      final b = await cache.load(b1);
      expect(b, isNotNull);
      expect(b!.length, Sprites.bytesOfRef(b1));
      expect(calls, 2);
      expect(_file(tmp, b1).lengthSync(), Sprites.bytesOfRef(b1));
      // Siempre del tamaño equivocado: no se acepta nunca.
      final wrong = SpriteCache(directory: () async => tmp, retryDelay: Duration.zero, fetcher: (u) async => _png);
      expect(await wrong.load(b4), isNull);
      expect(_file(tmp, b4).existsSync(), isFalse);
    });

    test('un archivo de 0 bytes o truncado en disco no cuenta como descargado', () async {
      _file(tmp, b1).writeAsBytesSync(const []);
      final full = _pngOfSize(Sprites.bytesOfRef(b4));
      _file(tmp, b4).writeAsBytesSync(full.sublist(0, full.length ~/ 2));
      _file(tmp, b7).writeAsBytesSync(_pngOfSize(Sprites.bytesOfRef(b7)));
      final cache = SpriteCache(directory: () async => tmp, fetcher: (u) async => throw const SocketException('sin red'));
      final r = await cache.verify();
      expect(r.valid, 1);
      expect(r.invalid, 2);
      expect(r.missing, total - 1);
      expect(_file(tmp, b1).existsSync(), isFalse, reason: 'los inválidos se borran');
      expect(_file(tmp, b4).existsSync(), isFalse);
    });
  });

  group('descargar todo y reparar', () {
    test('fallos transitorios: segunda pasada más lenta; completo y sin faltas', () async {
      final attempts = <String, int>{};
      final cache = SpriteCache(
        directory: () async => tmp,
        retries: 0,
        retryDelay: Duration.zero,
        mirrors: const [SpriteCache.baseUrl],
        fetcher: (u) async {
          final k = u.pathSegments.last;
          final n = attempts[k] = (attempts[k] ?? 0) + 1;
          // Un 5 % de los archivos falla la primera vez (429 de GitHub, corte de red…).
          if (k.hashCode % 20 == 0 && n == 1) {
            throw k.hashCode.isEven ? SpriteHttpStatusException(429, u) : const SocketException('reset');
          }
          return _serve(u);
        },
      );
      final r = await cache.downloadAll();
      expect(attempts.values.where((n) => n == 2), isNotEmpty);
      expect(r.failed, 0);
      expect(r.missing, 0);
      expect(r.complete, isTrue);
      expect((await cache.verify()).complete, isTrue);
    });

    test('404 y escritura fallida: no se marca completo y se informa de cuántos faltan', () async {
      // Un directorio con el nombre del archivo hace fallar el rename (como un disco lleno).
      Directory('${tmp.path}/pokemon_scharmander.png').createSync();
      final cache = SpriteCache(
        directory: () async => tmp,
        retryDelay: Duration.zero,
        fetcher: (u) async {
          if (u.pathSegments.last == 'sbulbasaur.png') throw SpriteHttpStatusException(404, u);
          return _serve(u);
        },
      );
      final r = await cache.downloadAll();
      expect(r.complete, isFalse);
      expect(r.failed, 2, reason: 'sbulbasaur (404) y scharmander (no se pudo guardar)');
      expect(r.missing, 2);
      expect(r.downloaded, total - 2);
      expect(tmp.listSync().where((e) => e.path.endsWith('.part')), isEmpty);
    });

    test('reparar descarga solo los faltantes o dañados', () async {
      var calls = 0;
      SpriteCache make() => SpriteCache(
          directory: () async => tmp,
          retryDelay: Duration.zero,
          fetcher: (u) async {
            calls++;
            return _serve(u);
          });
      expect((await make().downloadAll()).complete, isTrue);
      // Daños típicos: un archivo vacío, uno cortado y uno que falta.
      _file(tmp, b1).writeAsBytesSync(const []);
      final f4 = _file(tmp, b4);
      f4.writeAsBytesSync(f4.readAsBytesSync().sublist(0, 30));
      _file(tmp, b7).deleteSync();
      final cache = make();
      final before = await cache.verify();
      expect(before.missing, 3);
      calls = 0;
      final r = await cache.repair();
      expect(calls, 3);
      expect(r.alreadyCached, total - 3);
      expect(r.downloaded, 3);
      expect(r.complete, isTrue);
      expect((await cache.verify()).missing, 0);
    });

    test('concurrencia: widgets cargando a la vez que la descarga, sin duplicados ni temporales', () async {
      final fetched = <String, int>{};
      final cache = SpriteCache(
          directory: () async => tmp,
          fetcher: (u) async {
            final k = '${u.pathSegments[u.pathSegments.length - 2]}/${u.pathSegments.last}';
            fetched[k] = (fetched[k] ?? 0) + 1;
            await Future<void>.delayed(const Duration(milliseconds: 1));
            return _serve(u);
          });
      final refs = SpriteCache.allRefs();
      final bulk = cache.downloadAll(concurrency: 32);
      final singles = [for (final r in refs.take(200)) cache.load(r)];
      final r = await bulk;
      final loaded = await Future.wait(singles);
      expect(loaded.every((b) => b != null), isTrue);
      expect(r.complete, isTrue);
      expect(fetched.values.every((n) => n == 1), isTrue, reason: 'cada icono se pide una sola vez');
      expect(fetched.length, total);
      expect(tmp.listSync().where((e) => e.path.endsWith('.part')), isEmpty);
      expect((await cache.verify()).complete, isTrue);
    });

    test('borrar la caché y volver a comprobar', () async {
      final cache = SpriteCache(directory: () async => tmp, fetcher: (u) async => _serve(u));
      await cache.downloadAll();
      await cache.clear();
      final r = await cache.verify();
      expect(r.valid, 0);
      expect(r.missing, total);
    });
  });

  group('proporciones', () {
    const pika = SpriteRef('pokemon', 'spikachu'), wailord = SpriteRef('pokemon', 'swailord');
    const gourgeist = SpriteRef('pokemon', 'sgourgeist-osuper');

    test('Pokémon: el contenido de referencia llena ~88 % del hueco, igual para todos', () {
      final ref = Sprites.contentRef('pokemon');
      for (final (size, dpr) in [(32.0, 2.3), (44.0, 3.0), (52.0, 2.0), (104.0, 2.3)]) {
        final box = size * dpr;
        final s = SpriteLayout.scaleFor(pika, box, pixelated: false);
        expect(ref * s / box, closeTo(Sprites.fill['pokemon']!, 1e-9), reason: '$size@$dpr');
        expect(SpriteLayout.scaleFor(wailord, box, pixelated: false), s, reason: 'misma escala');
      }
    });

    test('sin recortes: ningún sprite del índice se sale del hueco', () {
      for (final ref in SpriteCache.allRefs()) {
        final need = Sprites.needOf(ref) ?? Sprites.contentRef(ref.group);
        for (final box in [40.0, 73.6, 101.2, 156.0]) {
          final px = Sprites.isPixelArt(ref.group);
          expect(need * SpriteLayout.scaleFor(ref, box, pixelated: px), lessThanOrEqualTo(box + 1e-9), reason: '$ref $box');
        }
      }
      // El que supera la referencia (Gourgeist enorme) aún cabe en el margen:
      // no se reduce y conserva la escala común.
      final need = Sprites.needOf(gourgeist)!;
      expect(need, greaterThan(Sprites.contentRef('pokemon')));
      expect(SpriteLayout.scaleFor(gourgeist, 100, pixelated: false), SpriteLayout.scaleFor(pika, 100, pixelated: false));
      expect(need * SpriteLayout.scaleFor(gourgeist, 100, pixelated: false), lessThanOrEqualTo(100));
    });

    test('arte de píxeles: escala entera si aprovecha ≥ 80 %; si no, la exacta (vecino más próximo)', () {
      const item = SpriteRef('item', 'bitem_1');
      final ref = Sprites.contentRef('item');
      double exact(double box) => box * 0.88 / ref;
      // Exacta ×3,52 → ×3 (85 %).
      expect(SpriteLayout.scaleFor(item, 100), 3);
      // Exacta ×1,41 → ×1 sería el 71 %: se queda ×1,41.
      expect(SpriteLayout.scaleFor(item, 40), closeTo(exact(40), 1e-9));
      expect(SpriteLayout.filterFor(1.41, pixelated: true), FilterQuality.none);
      expect(SpriteLayout.filterFor(0.7, pixelated: true), FilterQuality.medium); // reducir: suavizado
      expect(SpriteLayout.filterFor(2, pixelated: false), FilterQuality.medium);
      // Objeto de 16×16 y de 32×32 en el mismo hueco: misma escala, mitad de tamaño.
      final small = SpriteLayout.destRect(item, 16, 16, 24, 3);
      final big = SpriteLayout.destRect(item, 32, 32, 24, 3);
      expect(big.width, closeTo(small.width * 2, 0.001));
    });

    test('nunca deforma y centra (en píxeles enteros con arte de píxeles)', () {
      for (final (size, dpr) in [(28.0, 2.3), (44.0, 2.3), (64.0, 2.0), (96.0, 3.0), (20.0, 1.0)]) {
        final r = SpriteLayout.destRect(wailord, 124, 104, size, dpr, pixelated: false);
        expect(r.width / r.height, closeTo(124 / 104, 0.0001), reason: '$size@$dpr');
        expect(r.center.dx, closeTo(size / 2, 1e-9));
        expect(r.center.dy, closeTo(size / 2, 1e-9));
        final i = SpriteLayout.destRect(const SpriteRef('item', 'bitem_1'), 32, 32, size, dpr);
        expect((i.left * dpr - (i.left * dpr).roundToDouble()).abs(), lessThan(1e-6));
      }
      // Tipos y cintas: llenan su hueco (su lienzo ya es el contenido).
      expect(SpriteLayout.destRect(const SpriteRef('type', 'type_icon_09'), 60, 60, 16, 2.3, pixelated: false).width,
          closeTo(16, 1e-9));
    });

    testWidgets('el avatar usa el lienzo completo, no un recorte por sprite', (t) async {
      final prev = SpriteCache.instance;
      SpriteCache.instance = SpriteCache(strictSizes: false, directory: () async => null, fetcher: (u) async => _png);
      addTearDown(() => SpriteCache.instance = prev);
      const ref = SpriteRef('pokemon', 'spikachu');
      await t.runAsync(() => SpriteCache.instance.load(ref));
      await t.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SpriteImage(sprite: ref, size: 44, fallback: Text('Pi'))),
      ));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump();
      expect(find.text('Pi'), findsNothing);
      expect(t.getSize(find.byType(SpriteImage)), const Size(44, 44));
    });
  });

  group('decodificación', () {
    testWidgets('bytes que no se pueden decodificar: se descartan y se piden otra vez (una vez)', (t) async {
      var calls = 0;
      // Estructura válida (firma, IHDR, IEND) pero ancho 0 y datos basura.
      final broken = Uint8List.fromList(_png)
        ..fillRange(16, 20, 0x00)
        ..fillRange(41, 54, 0x00);
      final prev = SpriteCache.instance;
      SpriteCache.instance = SpriteCache(
          strictSizes: false,
          directory: () async => tmp,
          fetcher: (u) async {
            calls++;
            return calls == 1 ? broken : _png;
          });
      addTearDown(() => SpriteCache.instance = prev);
      await t.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: SpriteImage(sprite: SpriteRef('pokemon', 'spikachu'), size: 40, fallback: Text('Pi')),
      ));
      for (var i = 0; i < 60 && (calls < 2 || find.text('Pi').evaluate().isNotEmpty); i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await t.pump();
      }
      expect(calls, 2);
      expect(find.text('Pi'), findsNothing);
    });
  });
}
