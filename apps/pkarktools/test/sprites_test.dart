import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkarktools/data/sprites/sprite_cache.dart';
import 'package:pkarktools/data/sprites/sprite_manifest.g.dart';
import 'package:pkarktools/data/sprites/sprites.dart';
import 'package:pkarktools/ui/common/sprite_image.dart';

/// PNG de 1×1 válido.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, //
  0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, 0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('sprites'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('resolución de nombres (PKHeX SpriteName)', () {
    test('forma, variocolor, género, huevo y caídas a la forma base', () {
      expect(Sprites.pokemon(25)!.key, 'pokemon/b_25');
      expect(Sprites.pokemon(25, shiny: true)!.key, 'shiny/b_25s');
      expect(Sprites.pokemon(479, form: 3)!.key, 'pokemon/b_479-3'); // Rotom Lavado
      expect(Sprites.pokemon(25, form: 99)!.key, 'pokemon/b_25'); // forma sin sprite → base
      expect(Sprites.pokemon(449, female: true)!.key, 'pokemon/b_449f'); // Hippopotas hembra
      expect(Sprites.pokemon(25, female: true)!.key, 'pokemon/b_25'); // sin sprite de género
      expect(Sprites.pokemon(25, egg: true)!.key, 'pokemon/b_egg');
      expect(Sprites.pokemon(0), isNull);
    });

    test('objetos por generación, Balls, tipos y cintas', () {
      expect(Sprites.item(1)!.key, 'item/bitem_1'); // Master Ball
      expect(Sprites.item(kItem3to4.indexOf(1), generation: 3)!.key, 'item/bitem_1');
      expect(Sprites.item(5, generation: 1), isNull); // Gen 1 no tiene objetos equipados
      expect(Sprites.ball(4)!.key, 'ball/_ball4');
      expect(Sprites.type(PokemonType.fire)!.key, 'type/type_icon_09');
      expect(Sprites.type(PokemonType.none), isNull);
      expect(Sprites.ribbon('RibbonChampionKalos')!.key, 'ribbon/ribbonchampionkalos');
      // Todas las cintas que muestra la app tienen icono salvo las que PKHeX no dibuja.
      final missing = [for (final r in Ribbons.all) if (Sprites.ribbon(r.key) == null) r.key];
      expect(missing.length, lessThan(8), reason: '$missing');
    });

    test('URL con commit fijo y espacios codificados', () {
      final u = SpriteCache.urlOf(const SpriteRef('pokemon', 'b_25')).toString();
      expect(u, contains(kSpriteCommit));
      expect(u, endsWith('Big%20Pokemon%20Sprites/b_25.png'));
      expect(u, startsWith('https://raw.githubusercontent.com/kwsch/PKHeX/'));
    });
  });

  group('caché', () {
    test('descarga una vez y luego lee del disco', () async {
      var calls = 0;
      final cache = SpriteCache(strictSizes: false, directory: () async => tmp, fetcher: (u) async {
        calls++;
        return _png;
      });
      const ref = SpriteRef('pokemon', 'b_25');
      expect(await cache.load(ref), _png);
      expect(calls, 1);
      expect(File('${tmp.path}/pokemon_b_25.png').existsSync(), isTrue);
      // Otra instancia (app reiniciada): sale del disco sin red.
      final again = SpriteCache(strictSizes: false, directory: () async => tmp, fetcher: (u) async => throw const SocketException('sin red'));
      expect(await again.load(ref), _png);
      expect(await again.diskBytes(), _png.length);
      await again.clear();
      expect(await again.diskBytes(), 0);
    });

    test('sin conexión: reintenta, devuelve null y no insiste enseguida', () async {
      var calls = 0;
      final cache = SpriteCache(
        strictSizes: false,
        directory: () async => tmp,
        retries: 2,
        retryDelay: Duration.zero,
        fetcher: (u) async {
          calls++;
          throw const SocketException('sin red');
        },
      );
      expect(await cache.load(const SpriteRef('pokemon', 'b_1')), isNull);
      expect(calls, 6); // 3 intentos en raw.githubusercontent y 3 en jsDelivr
      expect(await cache.load(const SpriteRef('pokemon', 'b_1')), isNull);
      expect(calls, 6); // fallo recordado
    });

    test('rechaza respuestas que no son PNG o demasiado grandes', () async {
      final notPng = SpriteCache(strictSizes: false, directory: () async => tmp, fetcher: (u) async => Uint8List.fromList('<html>404</html>'.codeUnits));
      expect(await notPng.load(const SpriteRef('pokemon', 'b_2')), isNull);
      final big = SpriteCache(strictSizes: false, directory: () async => tmp, maxFileBytes: 10, fetcher: (u) async => _png);
      expect(await big.load(const SpriteRef('pokemon', 'b_3')), isNull);
      expect(tmp.listSync(), isEmpty);
    });

    test('sin directorio de caché funciona solo en memoria', () async {
      final cache = SpriteCache(strictSizes: false, directory: () async => throw const FileSystemException('sin permisos'), fetcher: (u) async => _png);
      expect(await cache.load(const SpriteRef('ball', '_ball4')), _png);
      expect(cache.peek(const SpriteRef('ball', '_ball4')), _png);
    });
  });

  group('descargar todo', () {
    test('en paralelo hasta el límite, con progreso en archivos y bytes', () async {
      var active = 0, maxActive = 0, calls = 0;
      final cache = SpriteCache(strictSizes: false, directory: () async => tmp, fetcher: (u) async {
        calls++;
        active++;
        if (active > maxActive) maxActive = active;
        await Future<void>.delayed(Duration.zero);
        active--;
        return _png;
      });
      final seen = <SpriteDownloadProgress>[];
      final r = await cache.downloadAll(concurrency: 8, onProgress: seen.add);
      final total = SpriteCache.allRefs().length;
      expect(maxActive, 8);
      expect(calls, total);
      expect(r.complete, isTrue);
      expect(r.downloaded, total);
      expect(r.bytes, total * _png.length);
      expect(seen.first.done, 0);
      expect(seen.last.done, total);
      expect(seen.last.totalBytes, kSpriteTotalBytes);
      expect(tmp.listSync().length, total);
    });

    test('se cancela y luego se reanuda sin repetir lo descargado', () async {
      var calls = 0;
      SpriteCache make() => SpriteCache(strictSizes: false, directory: () async => tmp, fetcher: (u) async {
            calls++;
            return _png;
          });
      var n = 0;
      final first = await make().downloadAll(concurrency: 4, cancel: () => n >= 50, onProgress: (p) => n = p.done);
      expect(first.cancelled, isTrue);
      expect(first.downloaded, inInclusiveRange(50, 54));
      final onDisk = tmp.listSync().length;
      expect(onDisk, first.downloaded);
      // Un corte a mitad de escritura deja un .part: se descarta al reanudar.
      File('${tmp.path}/pokemon_b_1.png.part').writeAsBytesSync([1, 2]);
      calls = 0;
      final progress = <SpriteDownloadProgress>[];
      final second = await make().downloadAll(onProgress: progress.add);
      final total = SpriteCache.allRefs().length;
      expect(second.alreadyCached, onDisk);
      expect(calls, total - onDisk);
      expect(progress.first.done, onDisk); // el progreso empieza donde se quedó
      expect(second.complete, isTrue);
      expect(tmp.listSync().where((f) => f.path.endsWith('.part')), isEmpty);
      expect(tmp.listSync().length, total);
    });

    test('fallos parciales: 404 sin reintentos; 503 con reintentos y respaldo en jsDelivr', () async {
      final hits = <String, int>{};
      final cache = SpriteCache(
        strictSizes: false,
        directory: () async => tmp,
        retryDelay: Duration.zero,
        fetcher: (u) async {
          final key = u.pathSegments.last;
          final k = '${u.host} $key';
          hits[k] = (hits[k] ?? 0) + 1;
          if (key == 'b_1.png') throw SpriteHttpStatusException(404, u);
          if (key == 'b_2.png' && u.host == 'raw.githubusercontent.com') throw SpriteHttpStatusException(503, u);
          if (key == 'b_3.png' && hits[k]! < 2) throw const SocketException('reset');
          return _png;
        },
      );
      final r = await cache.downloadAll();
      expect(r.failed, 1); // solo b_1 (404)
      expect(hits['raw.githubusercontent.com b_1.png'], 1);
      expect(hits['cdn.jsdelivr.net b_1.png'], isNull);
      expect(hits['raw.githubusercontent.com b_2.png'], 3);
      expect(hits['cdn.jsdelivr.net b_2.png'], 1);
      expect(hits['raw.githubusercontent.com b_3.png'], 2);
      expect(r.offline, isFalse);
      expect(File('${tmp.path}/pokemon_b_2.png').existsSync(), isTrue);
      expect(File('${tmp.path}/pokemon_b_1.png').existsSync(), isFalse);
    });

    test('sin red (o sin permiso de Internet) aborta enseguida', () async {
      var calls = 0;
      final cache = SpriteCache(
        strictSizes: false,
        directory: () async => tmp,
        retryDelay: const Duration(milliseconds: 5),
        fetcher: (u) async {
          calls++;
          throw const SocketException('Failed host lookup', osError: OSError('Permission denied', 13));
        },
      );
      final sw = Stopwatch()..start();
      final r = await cache.downloadAll();
      expect(r.offline, isTrue);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      expect(calls, lessThan(300)); // ~la primera tanda, no 3482 × 6
      expect(r.failed, lessThan(SpriteCache.defaultConcurrency));
      expect(cache.isOffline, isTrue);
      // Las cargas sueltas tampoco esperan: avatar de iniciales al momento.
      calls = 0;
      expect(await cache.load(const SpriteRef('pokemon', 'b_25')), isNull);
      expect(calls, 0);
    });

    test('primero los iconos de los equipos del Arca', () async {
      final order = <String>[];
      final cache = SpriteCache(strictSizes: false, directory: () async => tmp, fetcher: (u) async {
        order.add(u.pathSegments.last);
        return _png;
      });
      final prio = SpriteCache.refsForParty([(species: 445, shiny: true, egg: false), (species: 1, shiny: false, egg: true)]);
      expect(prio.map((r) => r.key), ['pokemon/b_445', 'shiny/b_445s', 'pokemon/b_egg']);
      await cache.downloadAll(priority: prio, concurrency: 1, cancel: () => order.length >= 3);
      expect(order, ['b_445.png', 'b_445s.png', 'b_egg.png']);
    });
  });

  group('widget', () {
    testWidgets('sin icono muestra el respaldo (iniciales)', (t) async {
      await t.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: SpriteImage(sprite: SpriteRef('pokemon', 'b_25'), size: 40, fallback: Text('Pi')),
      ));
      await t.pump();
      expect(find.text('Pi'), findsOneWidget);
    });

    testWidgets('con icono en caché pinta la imagen', (t) async {
      final prev = SpriteCache.instance;
      SpriteCache.instance = SpriteCache(strictSizes: false, directory: () async => null, fetcher: (u) async => _png);
      addTearDown(() => SpriteCache.instance = prev);
      await t.runAsync(() => SpriteCache.instance.load(const SpriteRef('pokemon', 'b_25')));
      await t.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: SpriteImage(sprite: SpriteRef('pokemon', 'b_25'), size: 40, fallback: Text('Pi')),
      ));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))); // decodificación
      await t.pump();
      expect(find.text('Pi'), findsNothing);
    });
  });
}
