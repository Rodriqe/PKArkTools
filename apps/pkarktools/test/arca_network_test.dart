import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/arca_layout.dart';
import 'package:pkarktools/data/folder/folder_access.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';
import 'package:pkarktools/data/folder/resilient_folder_fs.dart';
import 'package:pkarktools/data/folder/unicode_names.dart';
import 'package:pkarktools/data/folder/volume_info.dart';

import 'arca_folder_test.dart' show memoryDb, emerald, filesIn;
import 'fake_network_fs.dart';

const _smb = MountEntry(mountPoint: '/Volumes/Compartido', fsType: 'smbfs', source: '//ana@NAS._smb._tcp.local/Compartido');

/// Carpeta temporal "montada" como recurso SMB en una tabla de montajes falsa.
StaticMountTable mountsFor(Directory share, {bool mounted = true}) => StaticMountTable([
      const MountEntry(mountPoint: '/', fsType: 'apfs', source: '/dev/disk3s1'),
      if (mounted) MountEntry(mountPoint: share.path, fsType: 'smbfs', source: _smb.source),
    ]);

void main() {
  late Directory tmp;
  final dbs = <ArcaDatabase>[];

  ArcaDatabase db() {
    final d = memoryDb();
    dbs.add(d);
    return d;
  }

  setUp(() async => tmp = await Directory.systemTemp.createTemp('arca_red'));
  tearDown(() async {
    for (final d in dbs) {
      await d.close();
    }
    dbs.clear();
    await tmp.delete(recursive: true);
  });

  group('detección de volúmenes de red', () {
    test('origen del montaje: servidor y recurso', () {
      expect(VolumeInfo.parseSource('//ana@NASRIGO._smb._tcp.local/SharedFiles'), ('NASRIGO', 'SharedFiles'));
      expect(VolumeInfo.parseSource('//DOM;ana@nas.local/Mis%20Juegos'), ('nas.local', 'Mis Juegos'));
      expect(VolumeInfo.parseSource('//nas/share'), ('nas', 'share'));
      expect(VolumeInfo.parseSource('nas.local:/volume1/juegos'), ('nas.local', 'juegos'));
      expect(VolumeInfo.parseSource('https://nas:5006/webdav/arca'), ('nas', 'arca'));
      expect(VolumeInfo.parseSource(r'\\NAS\Juegos'), ('NAS', 'Juegos'));
      expect(VolumeInfo.parseSource('/dev/disk3s1'), (null, null));
    });

    test('el punto de montaje más largo decide; smbfs/afpfs/nfs/webdav son red', () {
      final mounts = [
        const MountEntry(mountPoint: '/', fsType: 'apfs', source: '/dev/disk3s1'),
        _smb,
        const MountEntry(mountPoint: '/Volumes/Fotos', fsType: 'afpfs', source: '//nas/Fotos'),
        const MountEntry(mountPoint: '/Volumes/Exp', fsType: 'nfs', source: 'nas:/exp'),
        const MountEntry(mountPoint: '/Volumes/Dav', fsType: 'webdav', source: 'https://nas/dav'),
        const MountEntry(mountPoint: '/Volumes/USB', fsType: 'exfat', source: '/dev/disk8s1'),
      ];
      final v = MountTable.volumeFor('/Volumes/Compartido/Juegos/Arca', mounts)!;
      expect(v.isNetwork, isTrue);
      expect(v.protocol, 'SMB');
      expect(v.displayName, 'NAS/Compartido');
      expect(MountTable.volumeFor('/Volumes/Fotos/x', mounts)!.protocol, 'AFP');
      expect(MountTable.volumeFor('/Volumes/Exp/x', mounts)!.isNetwork, isTrue);
      expect(MountTable.volumeFor('/Volumes/Dav', mounts)!.protocol, 'WebDAV');
      expect(MountTable.volumeFor('/Volumes/USB/x', mounts)!.isNetwork, isFalse);
      // /Volumes/Compartido2 no está dentro de /Volumes/Compartido.
      expect(MountTable.volumeFor('/Volumes/Compartido2/x', mounts)!.fsType, 'apfs');
      expect(MountTable.volumeFor('/Users/ana/Arca', mounts)!.isNetwork, isFalse);
    });

    test('Linux: /proc/self/mounts con escapes (cifs, nfs4)', () {
      final m = ProcMountTable.parse('/dev/sda1 / ext4 rw 0 0\n'
          '//nas/juegos /mnt/mis\\040juegos cifs rw 0 0\n'
          'nas:/exp /mnt/nfs nfs4 rw 0 0\n');
      final v = MountTable.volumeFor('/mnt/mis juegos/Arca', m)!;
      expect(v.isNetwork, isTrue);
      expect(v.displayName, 'nas/juegos');
      expect(MountTable.volumeFor('/mnt/nfs/a', m)!.protocol, 'NFS');
    });

    test('macOS: getfsstat lee la tabla real sin bloquear', () {
      final mounts = const DarwinMountTable().mounts();
      expect(mounts.any((m) => m.mountPoint == '/'), isTrue);
      expect(const DarwinMountTable().volumeOf(tmp.path), isNotNull);
    }, skip: !Platform.isMacOS);

    test('proveedor «NAS / red» en la detección de sincronización', () {
      expect(detectSyncProvider('/Volumes/Compartido/Arca', network: true), SyncProvider.nas);
      expect(detectSyncProvider('smb://nas/juegos'), SyncProvider.nas);
      expect(detectSyncProvider('/Users/ana/Library/Mobile Documents/com~apple~CloudDocs'), SyncProvider.iCloud);
      expect(SafFolderFs.isNetworkTree('content://com.wa2c.android.cifsdocumentsprovider/tree/abc'), isTrue);
      expect(SafFolderFs.isNetworkTree('content://com.android.externalstorage.documents/tree/primary%3AArca'), isFalse);
    });

    test('la ubicación recuerda que es de red', () {
      const loc = ArcaLocation(LocationKind.bookmark, value: 'b64', label: '/Volumes/Compartido/Arca', network: true, volume: 'NAS/Compartido');
      final back = ArcaLocation.fromJson(jsonDecode(encodeLocation(loc)) as Map<String, Object?>)!;
      expect(back.network, isTrue);
      expect(back.volume, 'NAS/Compartido');
      // Ubicaciones guardadas por versiones anteriores siguen leyéndose.
      expect(ArcaLocation.fromJson({'kind': 'path', 'value': '/x', 'label': '/x'})!.network, isFalse);
    });
  });

  group('nombres', () {
    test('NFC: compone lo que smbfs devuelve en NFD', () {
      expect(toNfc('Poke\u0301mon Esmeralda'), 'Pokémon Esmeralda');
      expect(toNfc('\u30ab\u3099\u30f3'), 'ガン');
      expect(toNfc('\u1100\u1161\u11a8'), '각');
      expect(toNfc('a\u0323\u0302'), 'ậ');
      expect(toNfc('MAY (12345)'), 'MAY (12345)');
      expect(toNfd('Pokémon'), 'Poke\u0301mon');
      expect(toNfc(toNfd('Pokémon Rubí Omega / Zafiro Alfa ガ')), 'Pokémon Rubí Omega / Zafiro Alfa ガ');
      expect(toNfd('각'), '각');
      expect(toNfd('ǖ'), 'ǖ');
      expect(toNfd('MAY (12345)'), 'MAY (12345)');
    });

    test('lo que solo aparece por NFD (smbfs tras listar) se encuentra: writeNew no lo pisa', () async {
      final root = Directory(p.join(tmp.path, 'share'))..createSync();
      final dir = Directory(p.join(root.path, 'PKArkTools', toNfd('Pokémon Esmeralda')))..createSync(recursive: true);
      File(p.join(dir.path, toNfd('Pokémon Esmeralda.sav'))).writeAsStringSync('viejo');
      final fs = IoFolderFs(root, mounts: StaticMountTable(const []), nfdLookups: true);
      const rel = 'PKArkTools/Pokémon Esmeralda/Pokémon Esmeralda.sav';
      expect(await fs.exists(rel), isTrue);
      expect(utf8.decode(await fs.read(rel)), 'viejo');
      await expectLater(fs.writeNew(rel, Uint8List(1)), throwsA(isA<FsExistsException>()));
      await fs.writeNew('PKArkTools/Pokémon Esmeralda/MAY/ñ.sav', Uint8List(1));
      expect(Directory(p.join(root.path, 'PKArkTools')).listSync().map((e) => toNfc(p.basename(e.path))), ['Pokémon Esmeralda']);
      expect(utf8.decode(await fs.read(rel)), 'viejo');
    });

    test('se ignoran AppleDouble, .DS_Store y las papeleras e índices del NAS', () {
      for (final path in [
        'Pokémon Esmeralda/._2026-01-01_120000_1a2b3c4d.sav',
        '.DS_Store',
        'Pokémon Esmeralda/Thumbs.db',
        '@eaDir/Pokémon Esmeralda.sav/SYNOFILE_THUMB_M.jpg',
        '#recycle/viejo.sav',
        r'$RECYCLE.BIN/S-1-5/x.sav',
        '.snapshot/hourly.0/x.sav',
        'Pokémon Esmeralda/@eaDir/x.sav',
        '@Recycle/x.sav',
      ]) {
        expect(ArcaLayout.ignoreReason(path), IgnoreReason.hidden, reason: path);
      }
      expect(ArcaLayout.ignoreReason('Pokémon Esmeralda/Esmeralda.sav'), isNull);
    });

    test('caracteres no válidos en SMB/Windows y longitud de ruta acotada', () {
      expect(ArcaLayout.safeSegment('A:B*C?"D<E>F|G'), 'A - B_C__D_E_F_G');
      expect(ArcaLayout.safeSegment('Rojo. '), 'Rojo');
      final longest = ArcaLayout.savePath(
        gameCode: 'oras',
        trainerName: 'ñ' * 300,
        displayTid: '123456',
        importedAt: DateTime(2026),
        sha256: 'a' * 64,
        originalName: 'x.sav',
        attempt: 49,
      );
      // `PKArkTools/` + ruta + `.json`: muy por debajo de los 255 de SMB y
      // de MAX_PATH de Windows aunque el recurso tenga una ruta larga.
      expect('PKArkTools/${ArcaLayout.sidecarFor(longest)}'.length, lessThan(200));
    });
  });

  group('IoFolderFs en un recurso de red', () {
    test('desmontado: no escribe en la carpeta local que queda en /Volumes', () async {
      // macOS deja a veces /Volumes/<recurso> como carpeta local vacía.
      final share = Directory(p.join(tmp.path, 'Volumes', 'Compartido'))..createSync(recursive: true);
      final mounts = mountsFor(share);
      final fs = IoFolderFs(share, mounts: mounts);
      expect(fs.isNetwork, isTrue);
      expect(await fs.checkAccess(), isTrue);
      mounts.entries = mountsFor(share, mounted: false).entries;
      expect(await fs.checkAccess(), isFalse);
      await expectLater(fs.writeNew('PKArkTools/README.txt', Uint8List(1)), throwsA(isA<NetworkFolderUnavailableException>()));
      await expectLater(fs.list(''), throwsA(isA<NetworkFolderUnavailableException>()));
      expect(filesIn(share), isEmpty);
      expect(Directory(p.join(share.path, 'PKArkTools')).existsSync(), isFalse);
    });

    test('abrir una ubicación de red no montada: «no disponible», sin crear nada', () async {
      final share = Directory(p.join(tmp.path, 'Volumes', 'Compartido'));
      const loc = ArcaLocation(LocationKind.bookmark, value: 'b', label: '', network: true, volume: 'NAS/Compartido');
      await expectLater(
        PlatformFolderAccess.openIoFolder(loc, share.path, mounts: mountsFor(share, mounted: false)),
        throwsA(isA<NetworkFolderUnavailableException>()),
      );
      expect(share.existsSync(), isFalse);
      // Con la carpeta local vacía en su lugar, tampoco.
      share.createSync(recursive: true);
      await expectLater(
        PlatformFolderAccess.openIoFolder(loc, share.path, mounts: mountsFor(share, mounted: false)),
        throwsA(isA<NetworkFolderUnavailableException>()),
      );
      expect(share.listSync(), isEmpty);
      // Montado: se abre, se detecta la red y se envuelve con reintentos.
      final opened = await PlatformFolderAccess.openIoFolder(loc, share.path, mounts: mountsFor(share));
      expect(opened.fs, isA<ResilientFolderFs>());
      expect(opened.location.network, isTrue);
      expect(opened.location.volume, 'NAS/Compartido');
    });

    test('nunca crea la raíz de una carpeta de red (sí la de una local nueva)', () async {
      final gone = Directory(p.join(tmp.path, 'no-existe'));
      final fs = IoFolderFs(gone, mounts: StaticMountTable(const []), expectNetwork: true);
      await expectLater(fs.writeNew('PKArkTools/a.txt', Uint8List(1)), throwsA(isA<FolderAccessLostException>()));
      await expectLater(fs.writeReplace('a.txt', Uint8List(1)), throwsA(isA<FolderAccessLostException>()));
      expect(gone.existsSync(), isFalse);
      // Una carpeta local nueva (p. ej. destino de «Cambiar carpeta») sí se crea.
      final local = IoFolderFs(gone, mounts: StaticMountTable(const []));
      await local.writeNew('PKArkTools/a.txt', Uint8List(1));
      expect(gone.existsSync(), isTrue);
    });

    test('macOS: no crea nada bajo /Volumes/<x> si ese volumen no está montado', () async {
      final fs = IoFolderFs(Directory('/Volumes/PKArkTools-no-montado-${DateTime.now().microsecondsSinceEpoch}/Arca'),
          mounts: StaticMountTable(const [MountEntry(mountPoint: '/', fsType: 'apfs', source: '/dev/disk3s1')]));
      await expectLater(fs.writeNew('PKArkTools/a.txt', Uint8List(1)), throwsA(isA<FolderAccessLostException>()));
    }, skip: !Platform.isMacOS);

    test('el listado no baja a @eaDir/#recycle ni lista AppleDouble', () async {
      final root = Directory(p.join(tmp.path, 'share'))..createSync();
      void put(String rel) => (File(p.join(root.path, rel))..parent.createSync(recursive: true)).writeAsStringSync('x');
      put('PKArkTools/Pokémon Esmeralda/Esmeralda.sav');
      put('PKArkTools/Pokémon Esmeralda/._Esmeralda.sav');
      put('PKArkTools/.DS_Store');
      for (var i = 0; i < 50; i++) {
        put('PKArkTools/@eaDir/Esmeralda.sav/thumb$i.jpg');
        put('#recycle/old$i.sav');
      }
      put(r'$RECYCLE.BIN/x.sav');
      final fs = IoFolderFs(root, mounts: StaticMountTable(const []));
      expect([for (final e in await fs.list('')) e.path], ['PKArkTools/Pokémon Esmeralda/Esmeralda.sav']);
    });

    test('nombres NFD en disco: listado en NFC y lectura por la ruta NFC', () async {
      final root = Directory(p.join(tmp.path, 'share'))..createSync();
      final nfdDir = Directory(p.join(root.path, 'PKArkTools', toNfd('Pokémon Esmeralda')))..createSync(recursive: true);
      File(p.join(nfdDir.path, 'x.sav')).writeAsStringSync('hola');
      final fs = IoFolderFs(root, mounts: StaticMountTable(const []));
      final listed = await fs.list('PKArkTools');
      expect(listed.single.path, 'PKArkTools/Pokémon Esmeralda/x.sav');
      expect(utf8.decode(await fs.read(listed.single.path)), 'hola');
      await fs.writeNew('PKArkTools/Pokémon Esmeralda/y.sav', Uint8List(2));
      // Se escribe en la carpeta existente, no en una «gemela» en NFC.
      expect(root.listSync(recursive: true).whereType<Directory>().length, 2);
    });
  });

  group('reintentos y tiempos máximos', () {
    test('fallos pasajeros (EAGAIN, ETIMEDOUT, ENOENT momentáneo) se reintentan', () async {
      final inner = FakeNetworkFs(failPlan: (op, path, n) => switch (op) {
            'writeNew' when n == 1 => osError(TransientErrors.eagain, path),
            'list' when n <= 2 => osError(TransientErrors.etimedout, path),
            'read' when n == 1 => osError(TransientErrors.enoent, path),
            _ => null,
          });
      final fs = ResilientFolderFs(inner, backoff: const Duration(milliseconds: 1));
      await fs.writeNew('a.sav', Uint8List.fromList([1, 2]));
      expect(await fs.read('a.sav'), [1, 2]);
      expect([for (final e in await fs.list('')) e.path]..sort(), ['._a.sav', 'a.sav']);
      expect(fs.retried, 4);
    });

    test('un ENOENT al comprobar no se reintenta (el archivo no existe)', () async {
      final inner = FakeNetworkFs(failPlan: (op, path, n) => op == 'delete' ? osError(TransientErrors.enoent, path) : null);
      final fs = ResilientFolderFs(inner, backoff: const Duration(milliseconds: 1));
      await expectLater(fs.delete('x'), throwsA(isA<FileSystemException>()));
      expect(fs.retried, 0);
    });

    test('la red caída de forma persistente es «carpeta de red no disponible»', () async {
      final inner = FakeNetworkFs(failPlan: (op, path, n) => osError(TransientErrors.ehostdown, path));
      final fs = ResilientFolderFs(inner, retries: 2, backoff: const Duration(milliseconds: 1));
      await expectLater(fs.list(''), throwsA(isA<NetworkFolderUnavailableException>()));
      expect(inner.calls['list'], 3);
    });

    test('un servidor que no responde no cuelga: tiempo máximo', () async {
      final inner = FakeNetworkFs()..hang = true;
      final fs = ResilientFolderFs(inner,
          timeout: const Duration(milliseconds: 50), listTimeout: const Duration(milliseconds: 80));
      final sw = Stopwatch()..start();
      await expectLater(fs.read('a'), throwsA(isA<NetworkFolderUnavailableException>()));
      await expectLater(fs.list(''), throwsA(isA<NetworkFolderUnavailableException>()));
      expect(await fs.checkAccess(), isFalse);
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });
  });

  group('Arca sobre un NAS simulado (SMB con latencia y fallos)', () {
    test('importar, reindexar y converger con NFD, mayúsculas, AppleDouble y fallos', () async {
      var failures = 0;
      final nas = FakeNetworkFs(failPlan: (op, path, n) {
        // Uno de cada 5 accesos falla una vez con un error pasajero.
        if (n % 5 == 0) {
          failures++;
          return osError(TransientErrors.eagain, path);
        }
        return null;
      });
      final fs = ResilientFolderFs(nas, backoff: const Duration(milliseconds: 1));
      final mac = ArcaRepository(db(), ArcaFolder(fs), deviceName: 'Mac');
      for (final (name, hours) in [('MAY', 10), ('MAY', 11), ('BRENDAN', 5)]) {
        final out = await mac.importBytes(emerald(name: name, hours: hours), fileName: 'Esmeralda.sav', origin: ImportOrigin.file);
        expect(out, isA<ImportAdded>());
      }
      expect(failures, greaterThan(0));
      // Los nombres vuelven en NFD (Pokémon) y con AppleDouble: el índice no cambia.
      final r1 = await mac.reindex();
      expect((r1.added, r1.removed), (0, 0));
      expect(r1.issues, isEmpty);
      expect(r1.loose, isEmpty);
      final writes = nas.writes;
      final r2 = await mac.reindex();
      expect((r2.added, r2.removed), (0, 0));
      // Reindexar no reescribe los archivos principales (nada que cambie).
      expect(nas.writes, writes);

      // Otro dispositivo (Android por SAF con un proveedor SMB) ve lo mismo.
      final android = ArcaRepository(db(), ArcaFolder(ResilientFolderFs(nas, backoff: const Duration(milliseconds: 1))),
          deviceName: 'Android');
      final ra = await android.reindex();
      expect(ra.added, 3);
      expect(await android.db.select(android.db.saveSlots).get(), hasLength(2));
      // Misma copia desde los dos: no se duplica.
      final dup = await android.importBytes(emerald(name: 'MAY', hours: 11), fileName: 'main', origin: ImportOrigin.file);
      expect(dup, isA<ImportDuplicate>());
    });

    test('una carpeta con otra grafía se reutiliza (SMB no distingue mayúsculas)', () async {
      final nas = FakeNetworkFs();
      final folder = ArcaFolder(nas);
      nas.files['pkarktools/pokémon esmeralda/may (12345)/historial/x.sav'] =
          ('PKArkTools/pokémon esmeralda/MAY (12345)/historial/x.sav', Uint8List(1), DateTime.now());
      await folder.listing();
      expect(folder.canonicalCase('Pokémon Esmeralda/MAY (12345)/historial/y.sav'),
          'pokémon esmeralda/MAY (12345)/historial/y.sav');
      expect(folder.canonicalCase('Pokémon Rubí/RUBY (1)/historial/y.sav'), 'Pokémon Rubí/RUBY (1)/historial/y.sav');
    });

    test('el NAS se desmonta durante el uso: sin acceso y con el índice intacto', () async {
      final nas = FakeNetworkFs();
      final repo = ArcaRepository(db(), ArcaFolder(nas), deviceName: 'Mac');
      await repo.importBytes(emerald(), fileName: 'E.sav', origin: ImportOrigin.file);
      nas.mounted = false;
      final out = await repo.importBytes(emerald(hours: 99), fileName: 'E.sav', origin: ImportOrigin.file);
      expect(out, isA<ImportFailed>());
      await expectLater(repo.reindex(), throwsA(isA<NetworkFolderUnavailableException>()));
      expect(await repo.db.select(repo.db.snapshots).get(), hasLength(1));
    });
  });

  group('elegir la carpeta del NAS', () {
    test('una carpeta con PKArkTools/ existente la reconoce y no crea otra', () async {
      // Réplica sintética de /Volumes/SharedFiles/PKArkToosl con su Arca.
      final share = Directory(p.join(tmp.path, 'PKArkToosl'))..createSync();
      final other = ArcaRepository(db(), ArcaFolder(IoFolderFs(share, mounts: mountsFor(share))), deviceName: 'iPhone');
      await other.importBytes(emerald(), fileName: 'E.sav', origin: ImportOrigin.file);
      // Sin README raíz (solo carpetas de juego con LEEME): igual se reconoce.
      File(p.join(share.path, 'PKArkTools', 'README.txt')).deleteSync();
      File(p.join(share.path, 'PKArkTools', 'Pokémon Esmeralda', 'LEEME.txt')).writeAsStringSync('${ArcaLayout.readmeMarker} · E');
      final before = filesIn(share);

      final folder = await ArcaFolder.open(IoFolderFs(share, mounts: mountsFor(share)));
      expect(folder.prefix, ArcaLayout.rootDir);
      final mac = ArcaRepository(db(), null, deviceName: 'Mac');
      final r = await mac.attachFolder(folder);
      expect(r.added, 1);
      expect(Directory(p.join(share.path, 'PKArkTools', 'PKArkTools')).existsSync(), isFalse);
      expect(share.listSync().map((e) => p.basename(e.path)), ['PKArkTools']);
      // Solo se repone el README (y nada fuera de PKArkTools/).
      expect(filesIn(share).toSet().difference(before.toSet()), {'PKArkTools/README.txt'});
    });

    test('elegir la propia carpeta PKArkTools (sin README) no anida otra', () async {
      final arca = Directory(p.join(tmp.path, 'SharedFiles', 'PKArkTools'))..createSync(recursive: true);
      File(p.join(arca.path, 'Pokémon Esmeralda', 'LEEME.txt'))
        ..parent.createSync()
        ..writeAsStringSync('x');
      final folder = await ArcaFolder.open(IoFolderFs(arca, mounts: StaticMountTable(const [])));
      expect(folder.prefix, '');
      final empty = Directory(p.join(tmp.path, 'Otra', 'pkarktools'))..createSync(recursive: true);
      expect((await ArcaFolder.open(IoFolderFs(empty, mounts: StaticMountTable(const [])))).prefix, '');
    });
  });

  group('vigilancia de una carpeta de red', () {
    ProviderContainer container(ArcaRepository repo, ArcaLocation loc, FolderAccess access) {
      final c = ProviderContainer(overrides: [
        arcaRepositoryProvider.overrideWithValue(repo),
        initialArcaSetupProvider.overrideWithValue(SetupReady(loc)),
        folderAccessProvider.overrideWithValue(access),
        networkPollIntervalProvider.overrideWithValue(const Duration(milliseconds: 60)),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('sondea cada intervalo, se pausa en segundo plano y pasa a «no disponible»', () async {
      final nas = FakeNetworkFs(latency: Duration.zero);
      final repo = ArcaRepository(db(), ArcaFolder(nas), deviceName: 'Mac');
      const loc = ArcaLocation(LocationKind.bookmark, value: 'b', label: '/Volumes/Compartido/Juegos');
      final access = _NasAccess(nas, loc);
      final c = container(repo, loc, access);
      final ctrl = c.read(arcaSetupProvider.notifier)..startWatching();
      expect(ctrl.polling, isTrue);

      // Otro dispositivo escribe en el NAS: el sondeo lo recoge.
      final other = ArcaRepository(db(), ArcaFolder(FakeNetworkFsView(nas)), deviceName: 'PC');
      await other.importBytes(emerald(), fileName: 'E.sav', origin: ImportOrigin.file);
      await _until(() async => (await repo.db.select(repo.db.snapshots).get()).length == 1);
      expect(ctrl.networkPolls, greaterThan(0));

      ctrl.appPaused();
      final polls = ctrl.networkPolls;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(ctrl.networkPolls, polls);
      expect(ctrl.polling, isFalse);

      // Se desmonta: al volver a primer plano, «carpeta de red no disponible».
      nas.mounted = false;
      access.available = false;
      await ctrl.appResumed();
      final s = c.read(arcaSetupProvider);
      expect(s, isA<SetupAccessLost>());
      expect((s as SetupAccessLost).location.network, isTrue);
      expect(await repo.db.select(repo.db.snapshots).get(), hasLength(1));

      // Vuelve el NAS: al volver a la app se reintenta solo.
      nas.mounted = true;
      access.available = true;
      await ctrl.appResumed();
      expect(c.read(arcaSetupProvider), isA<SetupReady>());
      expect(ctrl.polling, isTrue);
    });

    test('al arrancar con el NAS desmontado no se trata como Arca vacía', () async {
      final nas = FakeNetworkFs();
      const loc = ArcaLocation(LocationKind.bookmark, value: 'b', label: '/Volumes/Compartido/Juegos', network: true);
      final access = _NasAccess(nas, loc)..available = false;
      final index = db();
      final boot = await bootstrapArca(indexDb: index, access: access).then((b) async {
        await b.repo.setJsonSetting(ArcaController.locationKey, loc.toJson());
        return bootstrapArca(indexDb: index, access: access);
      });
      expect(boot.setup, isA<SetupAccessLost>());
      expect((boot.setup as SetupAccessLost).location.network, isTrue);
      expect(boot.repo.hasFolder, isFalse);
      expect(nas.files, isEmpty);
    });
  });
}

Future<void> _until(Future<bool> Function() ok) async {
  for (var i = 0; i < 100; i++) {
    if (await ok()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('no se cumplió a tiempo');
}

/// Acceso a carpetas que devuelve el NAS simulado o «no disponible».
class _NasAccess implements FolderAccess {
  _NasAccess(this.nas, this.location);
  final FakeNetworkFs nas;
  final ArcaLocation location;
  bool available = true;

  @override
  FolderSuggestion get suggestion => FolderSuggestion.iCloudDrive;

  @override
  Future<OpenedFolder> appLocal() => throw UnimplementedError();

  @override
  Future<OpenedFolder?> pick() async => OpenedFolder(location, nas);

  @override
  Future<OpenedFolder> open(ArcaLocation location) async {
    if (!available) throw const NetworkFolderUnavailableException('Compartido no está montado');
    return OpenedFolder(location.withVolumeOf(nas), nas);
  }
}

/// Otra vista (otro dispositivo) del mismo NAS simulado.
class FakeNetworkFsView extends MemoryFolderFs {
  FakeNetworkFsView(this.nas);
  final FakeNetworkFs nas;

  @override
  Future<List<FsEntry>> list(String dir) => nas.list(dir);
  @override
  Future<Uint8List> read(String path) => nas.read(path);
  @override
  Future<bool> exists(String path) => nas.exists(path);
  @override
  Future<void> writeNew(String path, Uint8List bytes) => nas.writeNew(path, bytes);
  @override
  Future<void> writeReplace(String path, Uint8List bytes) => nas.writeReplace(path, bytes);
  @override
  Future<void> delete(String path) => nas.delete(path);
}
