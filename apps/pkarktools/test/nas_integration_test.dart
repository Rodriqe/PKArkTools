// Prueba real contra un NAS montado (no se ejecuta en CI).
//
//   PKARK_NAS_TEST_DIR=/Volumes/<recurso>/<carpeta>/_prueba-nas-pkarktools \
//     flutter test test/nas_integration_test.dart
//
// La carpeta indicada NO debe existir: la prueba la crea, trabaja solo dentro
// de ella y al terminar borra exactamente esa carpeta (nada fuera de ella).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pkcore/pkcore.dart' show GameVersion;
import 'package:pkcore/testing.dart';
import 'package:pkarktools/data/arca_problems.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/blob_store.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/arca_game_folders.dart';
import 'package:pkarktools/data/folder/arca_layout.dart';
import 'package:pkarktools/data/folder/folder_access.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/data/folder/resilient_folder_fs.dart';
import 'package:pkarktools/data/folder/unicode_names.dart';
import 'package:pkarktools/data/folder/volume_info.dart';

import 'arca_folder_test.dart' show memoryDb, emerald;

final _dir = Platform.environment['PKARK_NAS_TEST_DIR'];

/// El archivo [rel] (en NFC) tal como está en disco, buscando cada nombre por
/// listado como haría el Finder (smbfs lista en NFD).
File onDisk(Directory root, String rel) {
  var path = root.path;
  for (final seg in rel.split('/')) {
    final d = Directory(path);
    final hit = d.existsSync()
        ? d.listSync().map((e) => p.basename(e.path)).where((n) => toNfc(n) == seg).firstOrNull
        : null;
    path = p.join(path, hit ?? seg);
  }
  return File(path);
}

void main() {
  final times = <String, Duration>{};
  Future<T> timed<T>(String what, Future<T> Function() body) async {
    final sw = Stopwatch()..start();
    try {
      return await body();
    } finally {
      times[what] = sw.elapsed;
    }
  }

  test('Arca real en un NAS: crear, importar, migrar, bandeja, arreglar y reindexar', () async {
    final base = Directory(_dir!);
    expect(p.basename(base.path), '_prueba-nas-pkarktools', reason: 'solo se trabaja en _prueba-nas-pkarktools');
    expect(base.existsSync(), isFalse, reason: 'la carpeta de prueba no debe existir: no es nuestra');
    expect(base.parent.existsSync(), isTrue);
    base.createSync();
    final dbs = <ArcaDatabase>[];
    ArcaDatabase db() {
      final d = memoryDb();
      dbs.add(d);
      return d;
    }

    // El Arca interna antigua (SQLite) vive en local, como en la app.
    final local = await Directory.systemTemp.createTemp('nas_legacy');
    try {
      // 1. Elegir la carpeta: se detecta el NAS y se envuelve con reintentos.
      final arcaDir = Directory(p.join(base.path, 'arca'))..createSync();
      final loc = ArcaLocation(LocationKind.path, value: arcaDir.path, label: arcaDir.path);
      final opened = await timed('abrir (checkAccess)', () => PlatformFolderAccess.openIoFolder(loc, arcaDir.path));
      expect(opened.fs.isNetwork, isTrue, reason: 'la carpeta debería estar en un volumen de red');
      expect(opened.fs, isA<ResilientFolderFs>());
      expect(opened.location.network, isTrue);
      // ignore: avoid_print
      print('Volumen: ${opened.fs.volume} → ${opened.location.volume}');

      // 2. Crear el Arca e importar 3 saves sintéticos.
      final folder = await ArcaFolder.open(opened.fs);
      expect(folder.prefix, ArcaLayout.rootDir);
      final mac = ArcaRepository(db(), null, deviceName: 'Mac (prueba NAS)');
      await timed('crear Arca (attach + reindex)', () => mac.attachFolder(folder));
      final saves = [
        ('Esmeralda.sav', emerald(name: 'MAY', hours: 10)),
        ('Esmeralda.sav', emerald(name: 'MAY', hours: 11)),
        ('Platino.sav', SyntheticSaves.gen4(trainer: const SynthTrainer(name: 'DAWN'))),
      ];
      await timed('importar 3 saves', () async {
        for (final (name, bytes) in saves) {
          expect(await mac.importBytes(bytes, fileName: name, origin: ImportOrigin.file), isA<ImportAdded>());
        }
      });

      // 3. Reindexar: estable (sin NFD/mayúsculas que hagan quitar y añadir).
      final r1 = await timed('reindexar (1)', mac.reindex);
      final r2 = await timed('reindexar (2, sin cambios)', mac.reindex);
      expect((r1.added, r1.removed, r2.added, r2.removed), (0, 0, 0, 0));
      expect(r2.issues, isEmpty);
      const mainRel = 'PKArkTools/Pokémon Esmeralda/MAY (12345)/Pokémon Esmeralda.sav';
      final main = onDisk(arcaDir, mainRel);
      expect(main.existsSync(), isTrue);
      // smbfs: tras listar, la ruta en NFC puede no encontrarse. Otro cliente
      // sin nombres aprendidos (IoFolderFs nuevo) debe encontrarlo igual.
      final fresh = IoFolderFs(arcaDir);
      expect(await fresh.exists(mainRel), isTrue);
      await expectLater(fresh.writeNew(mainRel, Uint8List(1)), throwsA(isA<FsExistsException>()));

      // 4. Otro dispositivo (índice propio) ve lo mismo.
      final other = ArcaRepository(db(), ArcaFolder(opened.fs), deviceName: 'Android (prueba NAS)');
      final ro = await timed('reindexar otro dispositivo (índice vacío)', other.reindex);
      expect(ro.added, 3);

      // 5. Bandeja: un save suelto en la carpeta del juego.
      await ArcaGameFolders.create(folder, {GameVersion.emerald}, es: true);
      final inboxRel = 'PKArkTools/${ArcaGameFolders.dirOf(GameVersion.emerald)}/POKEMON_EMER.sav';
      await IoFolderFs(arcaDir).writeNew(inboxRel, emerald(name: 'MAY', hours: 12));
      final inbox = onDisk(arcaDir, inboxRel);
      inbox.setLastModifiedSync(DateTime.now().subtract(const Duration(minutes: 1)));
      final ri = await timed('bandeja (reindexar + adoptar)', mac.reindex);
      expect(ri.inboxAdopted, hasLength(1));
      expect(inbox.existsSync(), isFalse);

      // 6. Arreglar: un .json dañado y un save suelto.
      final snaps = await mac.db.select(mac.db.snapshots).get();
      final victim = snaps.firstWhere((s) => s.trainerName == 'DAWN').relPath!;
      await IoFolderFs(arcaDir).writeReplace('PKArkTools/$victim.json', Uint8List.fromList(utf8.encode('{roto')));
      File(p.join(arcaDir.path, 'PKArkTools', 'suelto.sav')).writeAsBytesSync(emerald(name: 'MAY', hours: 13));
      // Otro dispositivo (índice vacío) lee los .json al indexar: ve los dos.
      final third = ArcaRepository(db(), ArcaFolder(opened.fs), deviceName: 'Otro (prueba NAS)');
      final rp = await timed('reindexar con problemas (otro dispositivo)', third.reindex);
      final problems = arcaProblemsOf(rp);
      expect(problems.map((e) => e.kind).toSet(), {ArcaProblemKind.corruptSidecar, ArcaProblemKind.looseSave});
      final fix = await timed('arreglar todo', () => ArcaRepair(third).fixAll(problems));
      expect(fix.failed, 0, reason: fix.errors.join('\n'));
      expect(arcaProblemsOf(await ArcaRepository(db(), ArcaFolder(opened.fs), deviceName: 'Cuarto').reindex()), isEmpty);
      final ra = await timed('reindexar tras arreglar', mac.reindex);
      expect(arcaProblemsOf(ra), isEmpty);

      // 7. Migración desde el Arca interna antigua (SQLite + blobs) al NAS.
      final legacyDir = Directory(p.join(local.path, 'PKArkTools', 'arca'))..createSync(recursive: true);
      final ldb = ArcaDatabase(DatabaseConnection(NativeDatabase(File(p.join(legacyDir.path, 'arca.sqlite')))));
      final bytes = emerald(name: 'BRENDAN', hours: 3);
      final sha = ArcaRepository.sha256Of(bytes);
      final slot = await ldb.into(ldb.saveSlots).insertReturning(SaveSlotsCompanion.insert(
          identityKey: 'k', gameCode: 'emerald', generation: 3, trainerName: 'BRENDAN', tid: 1, displayTid: '00001',
          createdAt: DateTime(2025), updatedAt: DateTime(2025)));
      await ldb.into(ldb.snapshots).insert(SnapshotsCompanion.insert(
          slotId: slot.id, sha256: sha, importedAt: DateTime(2025), fileName: 'e.sav', origin: 'file',
          sizeBytes: bytes.length, playTimeSeconds: 1, trainerName: 'BRENDAN', gameCode: 'emerald', partySummary: '',
          boxedCount: 0, formatInfo: '', checksum: 'valid'));
      await ldb.close();
      await BlobStore(Directory(p.join(legacyDir.path, 'blobs'))).put(sha, bytes);
      final mig = await timed('migrar Arca interna (1 copia)', () => LegacyArca(legacyDir).migrateTo(folder));
      expect(mig.ok, isTrue, reason: mig.failures.join('\n'));
      final rm = await timed('reindexar tras migrar', mac.reindex);
      expect(rm.added, 1);

      // 8. Elegir una carpeta que ya tiene PKArkTools/ no crea otra.
      final again = await ArcaFolder.open(opened.fs);
      expect(again.prefix, ArcaLayout.rootDir);
      final parent = await ArcaFolder.open(forVolume(IoFolderFs(base)));
      expect(parent.prefix, ArcaLayout.rootDir);
      expect(Directory(p.join(arcaDir.path, 'PKArkTools', 'PKArkTools')).existsSync(), isFalse);

      // 9. Reindexado periódico: lo que cuesta un sondeo sin cambios.
      final mainMtime = main.statSync().modified;
      final rs = await timed('sondeo (reindexar sin cambios)', mac.reindex);
      expect((rs.added, rs.removed), (0, 0));
      expect(main.statSync().modified, mainMtime, reason: 'reindexar no reescribe el principal');
      final listed = await opened.fs.list('');
      // ignore: avoid_print
      print('Archivos en el Arca de prueba: ${listed.length}');
      expect(listed.where((e) => p.basename(e.path).startsWith('._')), isEmpty);

      // 10. Desmontado simulado: la misma ruta con una tabla de montajes sin
      // el recurso. Ni se abre ni se escribe nada (sería una carpeta local).
      final unmounted = StaticMountTable(const [MountEntry(mountPoint: '/', fsType: 'apfs', source: '/dev/disk3s1')]);
      final netLoc = opened.location;
      await timed('abrir con el NAS «desmontado»', () async {
        await expectLater(PlatformFolderAccess.openIoFolder(netLoc, arcaDir.path, mounts: unmounted),
            throwsA(isA<NetworkFolderUnavailableException>()));
      });
      final gone = IoFolderFs(arcaDir, mounts: unmounted, expectNetwork: true);
      final countBefore = arcaDir.listSync(recursive: true).length;
      await expectLater(gone.writeNew('PKArkTools/no.txt', Uint8List(1)), throwsA(isA<FolderAccessLostException>()));
      expect(arcaDir.listSync(recursive: true).length, countBefore);
    } finally {
      for (final d in dbs) {
        await d.close();
      }
      await local.delete(recursive: true);
      // Borrar EXACTAMENTE la carpeta de prueba (comprobada otra vez).
      final exact = Directory(_dir!);
      if (p.basename(exact.path) == '_prueba-nas-pkarktools' && exact.existsSync()) {
        await exact.delete(recursive: true);
      }
      // ignore: avoid_print
      print(const JsonEncoder.withIndent('  ')
          .convert({for (final MapEntry(:key, :value) in times.entries) key: '${value.inMilliseconds} ms'}));
    }
    expect(base.existsSync(), isFalse);
  }, skip: _dir == null ? 'PKARK_NAS_TEST_DIR no definido' : false, timeout: const Timeout(Duration(minutes: 10)));
}
