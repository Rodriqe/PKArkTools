import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pkcore/testing.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/blob_store.dart';
import 'package:pkarktools/data/file_sources.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/arca_layout.dart';
import 'package:pkarktools/data/folder/arca_migration.dart';
import 'package:pkarktools/data/folder/folder_access.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';

ArcaDatabase memoryDb() => ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

Uint8List emerald({String name = 'MAY', int hours = 48}) =>
    SyntheticSaves.gen3(trainer: SynthTrainer(name: name, hours: hours));

/// Archivos (relativos a la carpeta elegida) que hay en [dir].
List<String> filesIn(Directory dir) => [
      for (final e in dir.listSync(recursive: true))
        if (e is File) p.relative(e.path, from: dir.path).split(p.separator).join('/'),
    ]..sort();

void main() {
  late Directory tmp;
  final dbs = <ArcaDatabase>[];

  ArcaRepository device(Directory root, String name) {
    final db = memoryDb();
    dbs.add(db);
    return ArcaRepository(db, ArcaFolder(IoFolderFs(root)), deviceName: name);
  }

  setUp(() async => tmp = await Directory.systemTemp.createTemp('arca_folder'));

  tearDown(() async {
    for (final db in dbs) {
      await db.close();
    }
    dbs.clear();
    await tmp.delete(recursive: true);
  });

  group('layout y nombres', () {
    test('sanea segmentos para todos los sistemas de archivos', () {
      expect(ArcaLayout.safeSegment('Pokémon Rojo / Azul'), 'Pokémon Rojo - Azul');
      expect(ArcaLayout.safeSegment(r'a:b\c*d?"e<f>g|h'), 'a - b - c_d__e_f_g_h');
      expect(ArcaLayout.safeSegment('  ..oculto. . '), 'oculto');
      expect(ArcaLayout.safeSegment('CON'), '_CON');
      expect(ArcaLayout.safeSegment('nul.txt'), '_nul.txt');
      expect(ArcaLayout.safeSegment(''), '_');
      expect(ArcaLayout.safeSegment('\u0000\u0001'), '__');
      expect(ArcaLayout.safeSegment('ニックネーム ♂'), 'ニックネーム ♂');
      expect(ArcaLayout.safeSegment('x' * 200).runes.length, ArcaLayout.maxSegment);
    });

    test('ruta del save: Juego/Entrenador (TID)/historial/fecha_hash8.ext', () {
      final path = ArcaLayout.savePath(
        gameCode: 'emerald',
        trainerName: 'MAY',
        displayTid: '12345',
        importedAt: DateTime(2026, 11, 22, 9, 5, 7),
        sha256: 'abcdef0123456789' * 4,
        originalName: 'Pokemon Esmeralda.SAV',
      );
      expect(path, 'Pokémon Esmeralda/MAY (12345)/historial/2026-11-22_090507_abcdef01.sav');
      expect(ArcaLayout.sidecarFor(path), '$path.json');
      expect(ArcaLayout.managedSave.hasMatch(path.split('/').last), isTrue);
      expect(
          ArcaLayout.savePath(
              gameCode: 'rby',
              trainerName: 'RED/BLUE',
              displayTid: '00001',
              importedAt: DateTime(2026),
              sha256: '0' * 64,
              originalName: 'main',
              attempt: 1),
          'Pokémon Rojo - Azul/RED - BLUE (00001)/historial/2026-01-01_000000_00000000-2.sav');
    });

    test('extensión original o .sav si no es razonable', () {
      expect(ArcaLayout.extensionFor('x.dsv'), '.dsv');
      expect(ArcaLayout.extensionFor('main'), '.sav');
      expect(ArcaLayout.extensionFor('x.json'), '.sav');
      expect(ArcaLayout.extensionFor('x.weird ext'), '.sav');
      expect(ArcaLayout.extensionFor('.hidden'), '.sav');
    });

    test('reconoce archivos de conflicto y parciales de la nube', () {
      const base = 'Juego/ASH (1)';
      final cases = {
        '$base/.2026-01-01_000000_00000000.sav.icloud': IgnoreReason.cloudPlaceholder,
        '$base/2026-01-01_000000_00000000.sav.tmp': IgnoreReason.partial,
        '$base/~\$algo.sav': IgnoreReason.partial,
        '$base/descarga.sav.crdownload': IgnoreReason.partial,
        '$base/2026-01-01_000000_00000000 (1).sav': IgnoreReason.conflictCopy,
        '$base/2026-01-01_000000_00000000 2.sav': IgnoreReason.conflictCopy,
        '$base/2026-01-01_000000_00000000-PORTATIL.sav': IgnoreReason.conflictCopy,
        '$base/2026-01-01_000000_00000000.sav (conflicted copy 2026-01-02).json': IgnoreReason.conflictCopy,
        '$base/partida.sync-conflict-20260101-120000-ABCDEF.sav': IgnoreReason.conflictCopy,
        '$base/Esmeralda (Ana\'s conflicted copy).sav': IgnoreReason.conflictCopy,
        '$base/Esmeralda (1).sav': IgnoreReason.conflictCopy,
        '.arca-anterior/blobs/ab/abc.sav': IgnoreReason.hidden,
        '$base/.DS_Store': IgnoreReason.hidden,
      };
      cases.forEach((path, reason) => expect(ArcaLayout.ignoreReason(path), reason, reason: path));
      expect(ArcaLayout.ignoreReason('$base/2026-01-01_000000_00000000.sav'), isNull);
      expect(ArcaLayout.ignoreReason('$base/2026-01-01_000000_00000000.sav.json'), isNull);
      expect(ArcaLayout.ignoreReason('suelto/Esmeralda.sav'), isNull);
    });

    test('el JSON del snapshot ida y vuelta; los rotos se rechazan', () async {
      final repo = device(tmp, 'Mac de prueba');
      final out = await repo.importBytes(emerald(), fileName: 'Esmeralda.sav', origin: ImportOrigin.file, note: 'nota');
      final snap = await repo.snapshot((out as ImportAdded).snapshotId);
      final meta = await repo.folder.readMeta(snap.relPath!);
      final again = SnapshotMeta.decode(meta.encode());
      expect(again.toJson(), meta.toJson());
      final json = jsonDecode(meta.encode()) as Map<String, Object?>;
      expect(json['schemaVersion'], ArcaLayout.schemaVersion);
      expect((json['device'] as Map)['name'], 'Mac de prueba');
      expect((json['trainer'] as Map)['name'], 'MAY');
      expect((json['game'] as Map)['code'], 'emerald');
      expect(json['sha256'], snap.sha256);
      expect(json['note'], 'nota');
      expect(() => SnapshotMeta.decode('{'), throwsFormatException);
      expect(() => SnapshotMeta.decode('{"schema":"otra"}'), throwsFormatException);
      expect(() => SnapshotMeta.decode('{"schema":"pkarktools-snapshot","sha256":"x"}'), throwsFormatException);
    });
  });

  group('carpeta como fuente de verdad', () {
    test('importar escribe save + json + README con la estructura legible', () async {
      final repo = device(tmp, 'A');
      final out = await repo.importBytes(emerald(), fileName: 'Esmeralda.sav', origin: ImportOrigin.file,
          now: DateTime(2026, 11, 22, 18, 30, 42));
      expect(out, isA<ImportAdded>());
      final sha = ArcaRepository.sha256Of(emerald());
      final name = '2026-11-22_183042_${sha.substring(0, 8)}.sav';
      expect(filesIn(tmp), [
        'PKArkTools/Pokémon Esmeralda/MAY (12345)/Pokémon Esmeralda.sav',
        'PKArkTools/Pokémon Esmeralda/MAY (12345)/historial/$name',
        'PKArkTools/Pokémon Esmeralda/MAY (12345)/historial/$name.json',
        'PKArkTools/Pokémon Esmeralda/MAY (12345)/ultima.json',
        'PKArkTools/README.txt',
      ]);
      // El archivo principal es la última versión, lista para el juego.
      expect(File(p.join(tmp.path, 'PKArkTools', 'Pokémon Esmeralda', 'MAY (12345)', 'Pokémon Esmeralda.sav')).readAsBytesSync(),
          emerald());
      expect(File(p.join(tmp.path, 'PKArkTools', 'README.txt')).readAsStringSync(), startsWith(ArcaLayout.readmeMarker));
      // Los bytes se leen de la carpeta verificando el hash.
      final snap = await repo.snapshot((out as ImportAdded).snapshotId);
      expect(await repo.snapshotBytes(snap), emerald());
      // Duplicado exacto: no escribe nada nuevo.
      expect(await repo.importBytes(emerald(), fileName: 'otra.sav', origin: ImportOrigin.file), isA<ImportDuplicate>());
      expect(filesIn(tmp), hasLength(5));
    });

    test('el índice se reconstruye desde la carpeta con los mismos datos', () async {
      final a = device(tmp, 'A');
      await a.importBytes(emerald(), fileName: 'E.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1));
      final edited = emerald(hours: 50);
      final slotId = (await a.allSlots()).single.$1.id;
      await a.saveEdited(edited, slotId: slotId, fileName: 'E.sav', note: 'Equipo', now: DateTime(2026, 1, 2));
      await a.importBytes(SyntheticSaves.gen4(trainer: const SynthTrainer(name: 'LYRA')), fileName: 'hgss.sav',
          origin: ImportOrigin.folder, sourcePath: '/ruta/hgss.sav', now: DateTime(2026, 1, 3));

      final b = device(tmp, 'B');
      final r = await b.reindex();
      expect(r.added, 3);
      expect(r.issues, isEmpty);
      List<String> describe(List<(SaveSlot, List<Snapshot>)> all) => [
            for (final (slot, snaps) in all..sort((x, y) => x.$1.identityKey.compareTo(y.$1.identityKey)))
              for (final s in snaps)
                '${slot.identityKey}|${slot.trainerName}|${s.sha256}|${s.importedAt.toUtc()}|${s.origin}|${s.note}|'
                    '${s.sourcePath}|${s.playTimeSeconds}|${s.partySummary}|${s.boxedCount}|${s.relPath}',
          ];
      expect(describe(await b.allSlots()), describe(await a.allSlots()));
      // Incremental: nada nuevo la segunda vez.
      final again = await b.reindex();
      expect((again.added, again.removed, again.unchanged), (0, 0, 3));
    });

    test('reindexado incremental: archivos añadidos o borrados por fuera', () async {
      final a = device(tmp, 'A');
      final out = await a.importBytes(emerald(), fileName: 'E.sav', origin: ImportOrigin.file);
      final rel = (await a.snapshot((out as ImportAdded).snapshotId)).relPath!;
      // Otro "dispositivo" borra la copia.
      File(p.join(tmp.path, 'PKArkTools', rel)).deleteSync();
      File(p.join(tmp.path, 'PKArkTools', '$rel.json')).deleteSync();
      final r = await a.reindex();
      expect(r.removed, 1);
      expect(await a.allSlots(), isEmpty);
    });

    test('dos dispositivos escribiendo en la misma carpeta', () async {
      final a = device(tmp, 'Mac');
      final b = device(tmp, 'iPhone');
      // Ambos importan el mismo save en momentos distintos (sin ver al otro).
      await a.importBytes(emerald(), fileName: 'E.sav', origin: ImportOrigin.file, now: DateTime(2026, 3, 1, 10));
      await b.importBytes(emerald(), fileName: 'E.sav', origin: ImportOrigin.file, now: DateTime(2026, 3, 1, 11));
      // Y cada uno una partida distinta, a la vez (mismo segundo).
      final t = DateTime(2026, 3, 2, 12);
      await Future.wait([
        a.importBytes(SyntheticSaves.gen4(trainer: const SynthTrainer(name: 'LYRA')), fileName: 'hg.sav', origin: ImportOrigin.file, now: t),
        b.importBytes(SyntheticSaves.gen5(trainer: const SynthTrainer(name: 'HILDA')), fileName: 'bw.sav', origin: ImportOrigin.file, now: t),
      ]);
      // Mismo save, mismo segundo, en los dos: mismo nombre → se reutiliza.
      final same = DateTime(2026, 3, 3, 8);
      final gs = SyntheticSaves.gen2(trainer: const SynthTrainer(name: 'GOLD'));
      await Future.wait([
        a.importBytes(gs, fileName: 'gs.sav', origin: ImportOrigin.file, now: same),
        b.importBytes(gs, fileName: 'gs.sav', origin: ImportOrigin.file, now: same),
      ]);
      final saves = filesIn(tmp).where((f) => f.endsWith('.sav') && f.contains('/historial/')).toList();
      expect(saves, hasLength(5), reason: '2 copias del mismo Esmeralda + HG + BW + 1 Oro: $saves');
      expect(filesIn(tmp).where((f) => f.contains('.tmp')), isEmpty);

      final ra = await a.reindex();
      final rb = await b.reindex();
      expect(ra.duplicates + rb.duplicates, greaterThanOrEqualTo(1));
      for (final repo in [a, b]) {
        final all = await repo.allSlots();
        expect(all.map((e) => e.$1.trainerName).toSet(), {'MAY', 'LYRA', 'HILDA', 'GOLD'});
        // Deduplicado por hash: el Esmeralda aparece una vez.
        expect(all.firstWhere((e) => e.$1.trainerName == 'MAY').$2, hasLength(1));
      }
      // Ambos eligen la misma copia (la más antigua): índice idéntico.
      final relA = (await a.allSlots()).firstWhere((e) => e.$1.trainerName == 'MAY').$2.single.relPath;
      final relB = (await b.allSlots()).firstWhere((e) => e.$1.trainerName == 'MAY').$2.single.relPath;
      expect(relA, relB);
      expect(relA, contains('_100000_'));
    });

    test('ignora conflictos y parciales; marca json/sav faltantes o dañados y sigue', () async {
      final a = device(tmp, 'A');
      final out = await a.importBytes(emerald(), fileName: 'E.sav', origin: ImportOrigin.file);
      final rel = (await a.snapshot((out as ImportAdded).snapshotId)).relPath!;
      final dir = p.join(tmp.path, 'PKArkTools', p.dirname(rel));
      final base = p.basenameWithoutExtension(rel);
      void put(String name, List<int> bytes) => File(p.join(dir, name)).writeAsBytesSync(bytes);
      put('$base (1).sav', emerald());
      put('$base (1).sav.json', [1, 2]);
      put('.$base.sav.icloud', [0]);
      put('$base.sav.tmp', [0]);
      put('~\$bloqueo.sav', emerald());
      put('partida.sync-conflict-20260101-120000-ABCDEF.sav', emerald());
      // Sidecar dañado de un save válido.
      put('2026-02-02_020202_aaaaaaaa.sav', emerald(name: 'BRENDAN'));
      put('2026-02-02_020202_aaaaaaaa.sav.json', utf8.encode('{"schema": "pkarktools-snapshot"'));
      // Save sin .json (otro dispositivo aún sincronizando).
      put('2026-02-03_030303_bbbbbbbb.sav', emerald(name: 'WALLY'));
      // .json sin save.
      put('2026-02-04_040404_cccccccc.sav.json', utf8.encode('{}'));

      final b = device(tmp, 'B');
      final r = await b.reindex();
      expect(r.added, 1);
      expect(r.loose, isEmpty);
      expect(r.ignored[IgnoreReason.conflictCopy], 3);
      expect(r.ignored[IgnoreReason.cloudPlaceholder], 1);
      expect(r.ignored[IgnoreReason.partial], 2);
      expect(r.placeholders, hasLength(1));
      expect({for (final i in r.issues) i.kind}, {
        ArcaIssueKind.corruptSidecar,
        ArcaIssueKind.missingSidecar,
        ArcaIssueKind.missingSave,
      });
      // El tamaño distinto del declarado se marca, no se cae.
      File(p.join(tmp.path, 'PKArkTools', rel)).writeAsBytesSync([...emerald(), 0], flush: true);
      final r2 = await b.reindex();
      expect(r2.issues.map((i) => i.kind), contains(ArcaIssueKind.sizeMismatch));
      final snap = (await b.allSlots()).single.$2.single;
      expect(snap.problem, 'size');
      // Y el hash distinto se detecta al leer.
      await expectLater(b.snapshotBytes(snap), throwsA(isA<ArcaFileCorruptException>()));
      expect((await b.snapshot(snap.id)).problem, 'hash');
    });

    test('adoptar saves sueltos copiados a mano', () async {
      final repo = device(tmp, 'A');
      await repo.folder.ensureReadme();
      final loose = File(p.join(tmp.path, 'PKArkTools', 'copiados', 'Mi Esmeralda.sav'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(emerald());
      File(p.join(tmp.path, 'PKArkTools', 'copiados', 'notas.txt')).writeAsStringSync('hola');
      final r = await repo.reindex();
      expect(r.loose.map((e) => e.path), ['copiados/Mi Esmeralda.sav']);
      final out = await repo.adopt('copiados/Mi Esmeralda.sav');
      expect(out, isA<ImportAdded>());
      expect((out as ImportAdded).save.game.code, 'emerald');
      expect(loose.existsSync(), isFalse);
      expect(repo.lastReport!.loose, isEmpty);
      final snap = (await repo.allSlots()).single.$2.single;
      expect(snap.origin, 'adopted');
      expect(snap.fileName, 'Mi Esmeralda.sav');
      // Un suelto que no es un save se queda donde está.
      File(p.join(tmp.path, 'PKArkTools', 'basura.bin')).writeAsBytesSync(Uint8List(0x20000));
      final r2 = await repo.reindex();
      expect(r2.loose, hasLength(1));
      expect(await repo.adopt('basura.bin'), isA<ImportFailed>());
      expect(File(p.join(tmp.path, 'PKArkTools', 'basura.bin')).existsSync(), isTrue);
    });

    test('importar una carpeta que contiene el Arca no reimporta sus copias', () async {
      // Caso real: «Importar carpeta» sobre ROMs/Saves (que contiene
      // PKArkTools/) duplicaba cada copia del historial con fecha nueva.
      final repo = device(tmp, 'A');
      await repo.importBytes(emerald(), fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1));
      await repo.reindex();
      File(p.join(tmp.path, 'GBA', 'Pokemon Emerald.sav'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(emerald(hours: 70));
      File(p.join(tmp.path, 'PKArkTools', '_cuarentena', 'x.sav'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(emerald(hours: 80));
      final scan = await const FileSources().scanDirectory(tmp);
      // Solo el save externo y el principal derivado (duplicado por hash).
      expect(scan.found.map((c) => c.relativePath.split(p.separator).last).toSet(), {'Pokemon Emerald.sav', 'Pokémon Esmeralda.sav'});
      expect(FileSources.isArcaCopy('PKArkTools/Pokémon Esmeralda/MAY (12345)/historial/2026-01-01_000000_abcdef01.sav'), isTrue);
      expect(FileSources.isArcaCopy(r'PKArkTools\_cuarentena\a.sav'), isTrue);
      expect(FileSources.isArcaCopy('GBA/Pokemon Emerald.sav'), isFalse);
    });

    test('nunca sobrescribe: mismo nombre con otro contenido usa sufijo', () async {
      final folder = ArcaFolder(IoFolderFs(tmp));
      final repo = device(tmp, 'A');
      await repo.importBytes(emerald(), fileName: 'E.sav', origin: ImportOrigin.file, now: DateTime(2026, 5, 5));
      final rel = (await repo.allSlots()).single.$2.single.relPath!;
      // Alguien dejó otro contenido con ese nombre: writeNew lo respeta.
      await expectLater(folder.fs.writeNew('PKArkTools/$rel', Uint8List(3)), throwsA(isA<FsExistsException>()));
      expect(File(p.join(tmp.path, 'PKArkTools', rel)).readAsBytesSync(), emerald());
    });

    test('una carpeta PKArkTools elegida directamente se usa tal cual', () async {
      final a = device(tmp, 'A');
      await a.importBytes(emerald(), fileName: 'E.sav', origin: ImportOrigin.file);
      final inner = await ArcaFolder.open(IoFolderFs(Directory(p.join(tmp.path, 'PKArkTools'))));
      expect(inner.prefix, '');
      final db = memoryDb();
      dbs.add(db);
      final b = ArcaRepository(db, inner);
      expect((await b.reindex()).added, 1);
      expect((await ArcaFolder.open(IoFolderFs(tmp))).prefix, 'PKArkTools');
    });
  });

  group('migración', () {
    Future<(ArcaDatabase, BlobStore)> legacyArca(Directory dir, {bool corruptOne = false}) async {
      final db = memoryDb();
      dbs.add(db);
      final blobs = BlobStore(Directory(p.join(dir.path, 'blobs')));
      final saves = [emerald(), emerald(hours: 60), SyntheticSaves.gen4(trainer: const SynthTrainer(name: 'LYRA'))];
      // Arca antigua escrita "a mano" (como lo hacía la versión anterior).
      for (final (i, bytes) in saves.indexed) {
        final sha = ArcaRepository.sha256Of(bytes);
        final key = i < 2 ? 'emerald:12345:54321:MAY' : 'hgss:12345:54321:LYRA';
        var slot = await (db.select(db.saveSlots)..where((s) => s.identityKey.equals(key))).getSingleOrNull();
        slot ??= await db.into(db.saveSlots).insertReturning(SaveSlotsCompanion.insert(
              identityKey: key,
              gameCode: i < 2 ? 'emerald' : 'hgss',
              generation: i < 2 ? 3 : 4,
              trainerName: i < 2 ? 'MAY' : 'LYRA',
              tid: 12345,
              sid: const Value(54321),
              displayTid: '12345',
              createdAt: DateTime(2025, 1, 1 + i),
              updatedAt: DateTime(2025, 1, 1 + i),
            ));
        await db.into(db.snapshots).insert(SnapshotsCompanion.insert(
              slotId: slot.id,
              sha256: sha,
              importedAt: DateTime(2025, 1, 1 + i, 12),
              fileName: 'save$i.sav',
              origin: i == 1 ? 'edit' : 'file',
              note: Value(i == 1 ? 'Nivel 100' : null),
              sizeBytes: bytes.length,
              playTimeSeconds: 3600 * (i + 1),
              trainerName: i < 2 ? 'MAY' : 'LYRA',
              gameCode: i < 2 ? 'emerald' : 'hgss',
              partySummary: '25,6s',
              boxedCount: i,
              formatInfo: 'test',
              checksum: 'valid',
            ));
        await blobs.put(sha, (corruptOne && i == 2) ? Uint8List.fromList([...bytes]..[100] ^= 0xFF) : bytes);
      }
      return (db, blobs);
    }

    test('Arca interna → carpeta: todo copiado y verificado, con fechas y notas', () async {
      final legacyDir = Directory(p.join(tmp.path, 'antigua'));
      final (ldb, blobs) = await legacyArca(legacyDir);
      final dest = ArcaFolder(IoFolderFs(Directory(p.join(tmp.path, 'nube'))));
      final progress = <int>[];
      final r = await ArcaMigration.fromLegacy(legacyDb: ldb, blobs: blobs, dest: dest, onProgress: (d, _) => progress.add(d));
      expect(r.ok, isTrue, reason: '${r.failures}');
      expect(r.copied, 3);
      expect(progress, [0, 1, 2, 3]);

      final repo = device(Directory(p.join(tmp.path, 'nube')), 'A');
      expect((await repo.reindex()).added, 3);
      final all = await repo.allSlots();
      final may = all.firstWhere((e) => e.$1.trainerName == 'MAY').$2;
      expect(may, hasLength(2));
      expect(may[1].note, 'Nivel 100');
      expect(may[1].origin, 'edit');
      expect(may[0].importedAt, DateTime(2025, 1, 1, 12));
      for (final (_, snaps) in all) {
        for (final s in snaps) {
          await repo.snapshotBytes(s); // verifica el SHA-256
        }
      }
    });

    test('un blob dañado se informa y no detiene el resto', () async {
      final (ldb, blobs) = await legacyArca(Directory(p.join(tmp.path, 'antigua')), corruptOne: true);
      final dest = ArcaFolder(IoFolderFs(Directory(p.join(tmp.path, 'nube'))));
      final r = await ArcaMigration.fromLegacy(legacyDb: ldb, blobs: blobs, dest: dest);
      expect(r.ok, isFalse);
      expect(r.copied, 2);
      expect(r.failures.single, contains('SHA-256'));
    });

    test('LegacyArca real en disco: cuenta, migra y se aparta sin borrarse', () async {
      final docs = Directory(p.join(tmp.path, 'Documentos'));
      final legacyDir = Directory(p.join(docs.path, 'PKArkTools', 'arca'))..createSync(recursive: true);
      final file = File(p.join(legacyDir.path, 'arca.sqlite'));
      final db = ArcaDatabase(DatabaseConnection(NativeDatabase(file)));
      final bytes = emerald();
      final sha = ArcaRepository.sha256Of(bytes);
      final slot = await db.into(db.saveSlots).insertReturning(SaveSlotsCompanion.insert(
          identityKey: 'k', gameCode: 'emerald', generation: 3, trainerName: 'MAY', tid: 1, displayTid: '00001',
          createdAt: DateTime(2025), updatedAt: DateTime(2025)));
      await db.into(db.snapshots).insert(SnapshotsCompanion.insert(
          slotId: slot.id, sha256: sha, importedAt: DateTime(2025), fileName: 'e.sav', origin: 'file',
          sizeBytes: bytes.length, playTimeSeconds: 1, trainerName: 'MAY', gameCode: 'emerald', partySummary: '',
          boxedCount: 0, formatInfo: '', checksum: 'valid'));
      await db.close();
      await BlobStore(Directory(p.join(legacyDir.path, 'blobs'))).put(sha, bytes);

      final legacy = LegacyArca(legacyDir);
      expect(await legacy.count(), 1);
      // La carpeta local de la app es Documentos: el Arca vive en Documentos/PKArkTools.
      final dest = await ArcaFolder.open(IoFolderFs(docs));
      final r = await legacy.migrateTo(dest);
      expect(r.ok, isTrue);
      await legacy.retire();
      expect(legacyDir.existsSync(), isFalse);
      expect(File(p.join(docs.path, 'PKArkTools', '.arca-anterior', 'arca.sqlite')).existsSync(), isTrue);
      // El Arca antigua apartada no aparece como "suelto" ni como problema.
      final repo = device(docs, 'A');
      final rep = await repo.reindex();
      expect((rep.added, rep.loose.length, rep.issues.length), (1, 0, 0));
    });

    test('cambiar de carpeta: mover verifica y solo borra lo verificado', () async {
      final from = Directory(p.join(tmp.path, 'vieja'));
      final to = Directory(p.join(tmp.path, 'nueva'));
      final a = device(from, 'A');
      await a.importBytes(emerald(), fileName: 'E.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1));
      await a.importBytes(SyntheticSaves.gen4(trainer: const SynthTrainer(name: 'LYRA')), fileName: 'h.sav',
          origin: ImportOrigin.file, now: DateTime(2026, 1, 2));
      // Una copia dañada en el origen y un suelto.
      final bad = (await a.allSlots()).firstWhere((e) => e.$1.trainerName == 'LYRA').$2.single.relPath!;
      final badFile = File(p.join(from.path, 'PKArkTools', bad));
      badFile.writeAsBytesSync(Uint8List.fromList(badFile.readAsBytesSync()..[200] ^= 1));
      File(p.join(from.path, 'PKArkTools', 'suelto.sav')).writeAsBytesSync(emerald(name: 'X'));

      final progress = <(int, int)>[];
      final r = await ArcaMigration.copyFolder(
          from: a.folder, to: ArcaFolder(IoFolderFs(to)), move: true, onProgress: (d, t) => progress.add((d, t)));
      expect(r.copied, 1);
      expect(r.failures.single, contains(bad));
      expect(r.leftBehind, 1);
      expect(progress.last, (2, 2));
      // Origen: queda la copia dañada (nunca se borra), su archivo principal
      // y el suelto; el principal de lo movido se retira.
      final badDir = ArcaLayout.ownerDirOf(bad);
      expect(filesIn(from).where((f) => !f.endsWith('README.txt')).toList()..sort(), [
        'PKArkTools/$bad',
        'PKArkTools/$bad.json',
        'PKArkTools/$badDir/Pokémon Platino.sav',
        'PKArkTools/$badDir/ultima.json',
        'PKArkTools/suelto.sav',
      ]..sort());
      // Destino: la copia buena, verificada, y reindexable.
      final b = device(to, 'A');
      expect((await b.reindex()).added, 1);

      // Copiar (sin mover) otra vez es idempotente.
      final again = await ArcaMigration.copyFolder(from: b.folder, to: ArcaFolder(IoFolderFs(to)));
      expect((again.copied, again.skipped), (0, 1));
    });
  });

  test('detecta el proveedor de sincronización por la ruta', () {
    expect(detectSyncProvider('/Users/x/Library/Mobile Documents/com~apple~CloudDocs/Arca'), SyncProvider.iCloud);
    expect(detectSyncProvider('/Users/x/Library/CloudStorage/GoogleDrive-a@b/Mi unidad'), SyncProvider.googleDrive);
    expect(detectSyncProvider(r'C:\Users\x\OneDrive\Arca'), SyncProvider.oneDrive);
    expect(detectSyncProvider('/home/x/Dropbox/Arca'), SyncProvider.dropbox);
    expect(detectSyncProvider('/home/x/Sync/Arca'), SyncProvider.syncthing);
    expect(detectSyncProvider('/home/x/Documentos'), SyncProvider.none);
  });
}
