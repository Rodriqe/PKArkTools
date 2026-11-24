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

  group('resolución de nombres', () {
    test('Pokémon: especie, forma, hembra, huevo y caídas a la especie', () {
      expect(Sprites.pokemon(25)!.key, 'pokemon/spikachu');
      // Sin iconos variocolor de las formas normales: mismo icono (la interfaz pone la insignia).
      expect(Sprites.pokemon(25, shiny: true)!.key, 'pokemon/spikachu');
      // Las formas especiales sí tienen variocolor.
      expect(Sprites.pokemon(3, form: 1, shiny: true)!.key, 'pokemon_small_shiny/0003-001-Venusaur-Mega');
      expect(Sprites.pokemon(36, form: 1, shiny: true)!.key, 'pokemon_champions/sclefable-omega-s');
      expect(Sprites.pokemon(479, form: 2)!.key, 'pokemon/srotom-owash'); // Rotom Lavado
      expect(Sprites.pokemon(25, form: 99)!.key, 'pokemon/spikachu'); // forma sin icono → especie
      expect(Sprites.pokemon(592, female: true)!.key, 'pokemon/sfrillish-f');
      expect(Sprites.pokemon(25, female: true)!.key, 'pokemon/spikachu'); // sin icono de hembra
      expect(Sprites.pokemon(25, egg: true)!.key, 'pokemon/xegg');
      expect(Sprites.pokemon(0), isNull);
      expect(Sprites.pokemon(1026), isNull);
    });

    test('todas las especies 1–1025 tienen icono propio', () {
      final seen = <String>{};
      for (var sp = 1; sp <= 1025; sp++) {
        final r = Sprites.pokemon(sp);
        expect(r, isNotNull, reason: '#$sp');
        expect(seen.add(r!.name), isTrue, reason: '#$sp repite ${r.name}');
      }
      // Muestras con nombres «aplanados» de smogon.
      expect(Sprites.pokemon(29)!.name, 'snidoran_f');
      expect(Sprites.pokemon(83)!.name, 'sfarfetchd');
      expect(Sprites.pokemon(122)!.name, 'smr_mime');
      expect(Sprites.pokemon(250)!.name, 'sho_oh');
      expect(Sprites.pokemon(669)!.name, 'sflabebe');
      expect(Sprites.pokemon(906)!.name, 'ssprigatito');
      expect(Sprites.pokemon(1024)!.name, 'sterapagos');
      expect(Sprites.pokemon(1025)!.name, 'specharunt');
    });

    test('formas de Gen 1–9 y Leyendas (índices de forma de PKHeX)', () {
      const cases = {
        (3, 1): 'svenusaur-omega',
        (6, 1): 'scharizard-omega_x',
        (6, 2): 'scharizard-omega_y',
        (25, 8): 'spikachu-ostarter',
        (52, 2): 'smeowth-ogalar',
        (58, 1): 'sgrowlithe-ohisui',
        (80, 2): 'sslowbro-ogalar',
        (128, 1): 'stauros-opaldea_combat',
        (128, 3): 'stauros-opaldea_aqua',
        (194, 1): 'swooper-opaldea',
        (201, 26): 'sunown-oexclamation',
        (483, 1): 'sdialga-oorigin',
        (550, 2): 'sbasculin-owhite_striped',
        (666, 0): 'svivillon-oicy_snow',
        (666, 6): 'svivillon',
        (670, 5): 'sfloette-oeternal',
        (678, 1): 'smeowstic-of',
        (716, 0): 'sxerneas-oneutral',
        (718, 1): 'szygarde-o10',
        (718, 4): 'szygarde-ocomplete',
        (741, 2): 'soricorio-opau',
        (774, 0): 'sminior-ometeor',
        (774, 7): 'sminior',
        (774, 13): 'sminior-oviolet',
        (869, 8): 'salcremie-orainbow_swirl',
        (892, 1): 'surshifu-orapid_strike',
        (898, 2): 'scalyrex-oshadow',
        (901, 1): 'sursaluna-obloodmoon',
        (902, 1): 'sbasculegion-of',
        (905, 1): 'senamorus-otherian',
        (916, 1): 'soinkologne-of',
        (925, 1): 'smaushold-ofour',
        (931, 3): 'ssquawkabilly-owhite',
        (964, 1): 'spalafin-ohero',
        (978, 2): 'statsugiri-ostretchy',
        (982, 1): 'sdudunsparce-othree_segment',
        (999, 1): 'sgimmighoul-oroaming',
        (1013, 1): 'ssinistcha-omasterpiece',
        (1017, 3): 'sogerpon-ocornerstone',
        (1017, 4): 'sogerpon', // Teal teracristalizada: mismo icono
        (1017, 6): 'sogerpon-ohearthflame',
      };
      for (final MapEntry(key: (sp, f), :value) in cases.entries) {
        expect(Sprites.pokemon(sp, form: f)?.name, value, reason: '$sp-$f');
      }
      // Formas que no están en la carpeta principal: otras carpetas del mismo commit.
      const extra = {
        (36, 1): 'pokemon_champions/sclefable-omega',
        (26, 2): 'pokemon_champions/sraichu-omega_x',
        (678, 3): 'pokemon_champions/smeowstic-of_mega',
        (491, 1): 'pokemon_preview/sdarkrai-omega',
        (978, 5): 'pokemon_preview/statsugiri-ostretchy_mega',
        (773, 5): 'pokemon_small/0773-005-Silvally-Rock',
        (1024, 1): 'pokemon_preview/sterapagos-oterastal',
        (1024, 2): 'pokemon_preview/sterapagos-ostellar',
      };
      for (final MapEntry(key: (sp, f), :value) in extra.entries) {
        expect(Sprites.pokemon(sp, form: f)?.key, value, reason: '$sp-$f');
      }
      // Sin icono propio en ninguna fuente (modos de Koraidon/Miraidon, Pichu
      // picoreja): icono de la especie, nunca iniciales (docs/usuario/iconos.md).
      for (final (sp, f) in [(1007, 1), (1008, 4), (172, 1)]) {
        expect(Sprites.pokemon(sp, form: f)?.name, Sprites.pokemon(sp)!.name, reason: '$sp-$f');
      }
    });

    test('Gigamax: icono propio por especie y por forma, normal y variocolor', () {
      expect(Sprites.pokemon(6, gigantamax: true)!.key, 'pokemon_small/0006-000-Charizard-Gmax');
      expect(Sprites.pokemon(6, gigantamax: true, shiny: true)!.key, 'pokemon_small_shiny/0006-000-Charizard-Gmax');
      expect(Sprites.pokemon(812, gigantamax: true)!.key, 'pokemon_preview/srillaboom-g');
      expect(Sprites.pokemon(849, form: 1, gigantamax: true)!.key, 'pokemon_preview/stoxtricity-olow_key-g');
      expect(Sprites.pokemon(892, form: 1, gigantamax: true, shiny: true)!.key, 'pokemon_preview/surshifu-orapid_strike-g-s');
      expect(Sprites.pokemon(869, form: 5, gigantamax: true)!.key, 'pokemon_small/0869-000-Alcremie-Gmax');
      // Sin Gigamax: el icono normal de la forma.
      expect(Sprites.pokemon(1, gigantamax: true)!.key, 'pokemon/sbulbasaur');
    });

    test('todas las formas especiales de SpecialForms tienen icono propio y variocolor en la fuente fijada', () {
      final names = <String>{};
      for (final f in SpecialForms.all) {
        final normal = Sprites.special(f), shiny = Sprites.special(f, shiny: true);
        expect(normal, isNotNull, reason: f.key);
        expect(Sprites.hasSpecialIcon(f), isTrue, reason: '${f.key} usa el icono de la especie');
        expect(Sprites.hasSpecialShinyIcon(f), isTrue, reason: '${f.key} sin variocolor');
        expect(Sprites.exists(normal!.group, normal.name), isTrue, reason: f.key);
        expect(Sprites.exists(shiny!.group, shiny.name), isTrue, reason: f.key);
        expect(Sprites.bytesOfRef(normal), greaterThan(0), reason: f.key);
        expect(SpriteCache.urlOf(normal).toString(), contains('/smogon/sprites/${kSpriteCommits['smogon/sprites']}/src/'));
        names.add(normal.key);
      }
      // Cada forma tiene el suyo (Toxtricity y Urshifu: uno por forma).
      expect(names.length, SpecialForms.all.length);
    });

    test('todas las formas del índice apuntan a un archivo que existe', () {
      for (final e in kPokemonIconForms.entries) {
        expect(Sprites.exists('pokemon', e.value), isTrue, reason: e.key);
      }
      for (final t in [kPokemonIconFormsExtra, kPokemonIconShinyForms, kPokemonIconGmax, kPokemonIconGmaxShiny]) {
        for (final e in t.entries) {
          expect(Sprites.exists(e.value.$1, e.value.$2), isTrue, reason: '${e.key} → ${e.value}');
        }
      }
      for (final sp in kPokemonIconFemale) {
        expect(Sprites.exists('pokemon', '${kPokemonIconBase[sp]}-f'), isTrue, reason: '$sp');
      }
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
      final u = SpriteCache.urlOf(const SpriteRef('pokemon', 'spikachu')).toString();
      expect(u, 'https://raw.githubusercontent.com/smogon/sprites/${kSpriteCommits['smogon/sprites']}/src/minisprites/pokemon/home/spikachu.png');
      final i = SpriteCache.urlOf(const SpriteRef('item', 'bitem_1'), SpriteCache.mirrorUrl).toString();
      expect(i, contains('cdn.jsdelivr.net/gh/kwsch/PKHeX@${kSpriteCommits['kwsch/PKHeX']}/'));
      expect(i, endsWith('Big%20Items/bitem_1.png'));
      final g = SpriteCache.urlOf(const SpriteRef('pokemon_small', '0006-000-Charizard-Gmax')).toString();
      expect(g, endsWith('/src/_uncategorized/canonical/home/small/0006-000-Charizard-Gmax.png'));
      final m = SpriteCache.urlOf(const SpriteRef('pokemon_small_shiny', '0006-001-Charizard-Mega~X')).toString();
      expect(m, endsWith('/small-shiny/0006-001-Charizard-Mega~X.png'));
    });
  });

  group('caché', () {
    test('descarga una vez y luego lee del disco', () async {
      var calls = 0;
      final cache = SpriteCache(strictSizes: false, directory: () async => tmp, fetcher: (u) async {
        calls++;
        return _png;
      });
      const ref = SpriteRef('pokemon', 'spikachu');
      expect(await cache.load(ref), _png);
      expect(calls, 1);
      expect(File('${tmp.path}/pokemon_spikachu.png').existsSync(), isTrue);
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
      expect(await cache.load(const SpriteRef('pokemon', 'sbulbasaur')), isNull);
      expect(calls, 6); // 3 intentos en raw.githubusercontent y 3 en jsDelivr
      expect(await cache.load(const SpriteRef('pokemon', 'sbulbasaur')), isNull);
      expect(calls, 6); // fallo recordado
    });

    test('rechaza respuestas que no son PNG o demasiado grandes', () async {
      final notPng = SpriteCache(strictSizes: false, directory: () async => tmp, fetcher: (u) async => Uint8List.fromList('<html>404</html>'.codeUnits));
      expect(await notPng.load(const SpriteRef('pokemon', 'sivysaur')), isNull);
      final big = SpriteCache(strictSizes: false, directory: () async => tmp, maxFileBytes: 10, fetcher: (u) async => _png);
      expect(await big.load(const SpriteRef('pokemon', 'svenusaur')), isNull);
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
      File('${tmp.path}/pokemon_sbulbasaur.png.part').writeAsBytesSync([1, 2]);
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
          if (key == 'sbulbasaur.png') throw SpriteHttpStatusException(404, u);
          if (key == 'sivysaur.png' && u.host == 'raw.githubusercontent.com') throw SpriteHttpStatusException(503, u);
          if (key == 'svenusaur.png' && hits[k]! < 2) throw const SocketException('reset');
          return _png;
        },
      );
      final r = await cache.downloadAll();
      expect(r.failed, 1); // solo sbulbasaur (404)
      expect(hits['raw.githubusercontent.com sbulbasaur.png'], 1);
      expect(hits['cdn.jsdelivr.net sbulbasaur.png'], isNull);
      expect(hits['raw.githubusercontent.com sivysaur.png'], 3);
      expect(hits['cdn.jsdelivr.net sivysaur.png'], 1);
      expect(hits['raw.githubusercontent.com svenusaur.png'], 2);
      expect(r.offline, isFalse);
      expect(File('${tmp.path}/pokemon_sivysaur.png').existsSync(), isTrue);
      expect(File('${tmp.path}/pokemon_sbulbasaur.png').existsSync(), isFalse);
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
      expect(await cache.load(const SpriteRef('pokemon', 'spikachu')), isNull);
      expect(calls, 0);
    });

    test('primero los iconos de los equipos del Arca', () async {
      final order = <String>[];
      final cache = SpriteCache(strictSizes: false, directory: () async => tmp, fetcher: (u) async {
        order.add(u.pathSegments.last);
        return _png;
      });
      final prio = SpriteCache.refsForParty([
        (species: 445, form: 0, shiny: true, egg: false),
        (species: 906, form: 0, shiny: false, egg: false),
        (species: 445, form: 0, shiny: false, egg: false),
        (species: 1, form: 0, shiny: false, egg: true),
      ]);
      expect(prio.map((r) => r.key), ['pokemon/sgarchomp', 'pokemon/ssprigatito', 'pokemon/xegg']);
      await cache.downloadAll(priority: prio, concurrency: 1, cancel: () => order.length >= 3);
      expect(order, ['sgarchomp.png', 'ssprigatito.png', 'xegg.png']);
    });
  });

  group('widget', () {
    testWidgets('sin icono muestra el respaldo (iniciales)', (t) async {
      await t.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: SpriteImage(sprite: SpriteRef('pokemon', 'spikachu'), size: 40, fallback: Text('Pi')),
      ));
      await t.pump();
      expect(find.text('Pi'), findsOneWidget);
    });

    testWidgets('con icono en caché pinta la imagen', (t) async {
      final prev = SpriteCache.instance;
      SpriteCache.instance = SpriteCache(strictSizes: false, directory: () async => null, fetcher: (u) async => _png);
      addTearDown(() => SpriteCache.instance = prev);
      await t.runAsync(() => SpriteCache.instance.load(const SpriteRef('pokemon', 'spikachu')));
      await t.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: SpriteImage(sprite: SpriteRef('pokemon', 'spikachu'), size: 40, fallback: Text('Pi')),
      ));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))); // decodificación
      await t.pump();
      expect(find.text('Pi'), findsNothing);
    });
  });
}
