import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/arca_layout.dart';
import 'package:pkarktools/data/folder/arca_main_files.dart';
import 'package:pkarktools/data/folder/arca_migration.dart';
import 'package:pkarktools/data/folder/folder_access.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';

ArcaDatabase memoryDb() => ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

Uint8List emerald({String name = 'MAY', int hours = 48}) =>
    SyntheticSaves.gen3(trainer: SynthTrainer(name: name, hours: hours));

String sha(Uint8List b) => ArcaFolder.sha256Of(b);

const mayDir = 'PKArkTools/Pokémon Esmeralda/MAY (12345)';
const mayMain = '$mayDir/Pokémon Esmeralda.sav';

/// Ruta relativa a la raíz del Arca (como en los informes).
const mayMainRel = 'Pokémon Esmeralda/MAY (12345)/Pokémon Esmeralda.sav';

/// [MemoryFolderFs] que falla en la operación número [failAt] (borrar o
/// escribir), para simular un corte a mitad.
class FlakyFs extends MemoryFolderFs {
  int? failDeleteAt;
  int? failWriteAt;
  int _deletes = 0;
  int _writes = 0;

  @override
  Future<void> delete(String path) async {
    if (failDeleteAt != null && ++_deletes == failDeleteAt) throw const FileSystemException('corte simulado');
    return super.delete(path);
  }

  @override
  Future<void> writeNew(String path, Uint8List bytes) async {
    if (failWriteAt != null && ++_writes == failWriteAt) throw const FileSystemException('corte simulado');
    return super.writeNew(path, bytes);
  }
}

void main() {
  final dbs = <ArcaDatabase>[];

  ArcaRepository device(MemoryFolderFs fs, [String name = 'A']) {
    final db = memoryDb();
    dbs.add(db);
    return ArcaRepository(db, ArcaFolder(fs), deviceName: name);
  }

  tearDown(() async {
    for (final db in dbs) {
      await db.close();
    }
    dbs.clear();
  });

  /// Pasa la carpeta al diseño anterior: copias sueltas en la carpeta del
  /// entrenador, sin principal ni ultima.json.
  void toLegacy(MemoryFolderFs fs) {
    for (final k in fs.files.keys.toList()) {
      final name = k.split('/').last;
      if (k.contains('/historial/')) {
        fs.files[k.replaceFirst('/historial/', '/')] = fs.files.remove(k)!;
      } else if (name == ArcaLayout.latestName || (!name.startsWith('20') && name != ArcaLayout.readmeName)) {
        fs.files.remove(k);
      }
    }
  }

  group('nombre del archivo principal', () {
    test('tabla por juego y contenedor', () {
      final cases = {
        ('swsh', 'main'): 'main',
        ('swsh', 'backup.bin'): 'main',
        ('pla', 'main'): 'main',
        ('sv', 'main'): 'main',
        ('za', 'main'): 'main',
        ('bdsp', 'SaveData.bin'): 'SaveData.bin',
        ('lgpe', 'savedata.bin'): 'savedata.bin',
        ('xy', 'main'): 'main',
        ('oras', '00000000.sav'): 'main',
        ('sm', 'main'): 'main',
        ('usum', 'main'): 'main',
        ('emerald', 'POKEMON_EMER_BPEE01.sav'): 'Pokémon Esmeralda.sav',
        ('emerald', 'Pokemon Emerald.srm'): 'Pokémon Esmeralda.srm',
        ('frlg', 'fr.SA1'): 'Pokémon Rojo Fuego - Verde Hoja.sa1',
        ('pt', 'Pokemon Platinum.dsv'): 'Pokémon Platino.dsv',
        ('pt', 'POKEMON_PL_CPUS01.sav'): 'Pokémon Platino.sav',
        ('hgss', 'raro.xyz'): 'Pokémon Oro HeartGold - Plata SoulSilver.sav',
        ('crystal', 'main'): 'Pokémon Cristal.sav',
        ('rby', 'red.fla'): 'Pokémon Rojo - Azul.fla',
      };
      cases.forEach((k, v) => expect(ArcaLayout.mainFileName(k.$1, k.$2), v, reason: '$k'));
    });

    test('rutas: carpeta del entrenador, historial y conflictos', () {
      const h = 'J/E (1)/historial/2026-01-01_000000_00000000.sav';
      expect(ArcaLayout.ownerDirOf(h), 'J/E (1)');
      expect(ArcaLayout.ownerDirOf('J/E (1)/2026-01-01_000000_00000000.sav'), 'J/E (1)');
      expect(ArcaLayout.inHistory(h), isTrue);
      expect(ArcaLayout.historyPathFor('J/E (1)/2026-01-01_000000_00000000.sav'), h);
      for (final c in ['main (1)', 'main 2', 'main-PORTATIL', "main (Ana's conflicted copy 2026-01-02)"]) {
        expect(ArcaLayout.isConflictOf(c, 'main'), isTrue, reason: c);
      }
      expect(ArcaLayout.isConflictOf('Pokémon Esmeralda (1).sav', 'Pokémon Esmeralda.sav'), isTrue);
      expect(ArcaLayout.isConflictOf('main', 'main'), isFalse);
      expect(ArcaLayout.isConflictOf('mainframe.sav', 'main'), isFalse);
      expect(ArcaLayout.isConflictOf('Pokémon Esmeralda.dsv', 'Pokémon Esmeralda.sav'), isFalse);
    });
  });

  group('archivo principal', () {
    test('cada copia nueva actualiza el principal; ultima.json apunta a ella', () async {
      final fs = MemoryFolderFs();
      final repo = device(fs);
      await repo.importBytes(emerald(), fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1));
      expect(fs.files[mayMain]!.$1, emerald());
      final v2 = emerald(hours: 60);
      await repo.importBytes(v2, fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 2));
      expect(fs.files[mayMain]!.$1, v2);
      final latest = jsonDecode(utf8.decode(fs.files['$mayDir/ultima.json']!.$1)) as Map<String, Object?>;
      final entry = (latest['files'] as Map)['Pokémon Esmeralda.sav'] as Map;
      expect(entry['sha256'], sha(v2));
      expect(entry['history'], startsWith('historial/2026-01-02_'));
      // Una copia más antigua que llega después (otro dispositivo) no lo cambia.
      await repo.importBytes(emerald(hours: 55), fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2025, 12, 31));
      expect(fs.files[mayMain]!.$1, v2);
      // Reindexar sin cambios no reescribe nada.
      final writes = fs.replaceCount;
      final r = await repo.reindex();
      expect(r.mains.single.state, MainState.current);
      expect(fs.replaceCount, writes);
    });

    test('si falta se regenera desde el historial, y un save de otro formato tiene su propio archivo', () async {
      final fs = MemoryFolderFs();
      final repo = device(fs);
      await repo.importBytes(emerald(), fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1));
      await repo.importBytes(emerald(hours: 70), fileName: 'Emerald.srm', origin: ImportOrigin.file, now: DateTime(2026, 1, 2));
      expect(fs.files.keys.where((k) => k.startsWith(mayDir) && !k.contains('historial')).toList()..sort(),
          ['$mayDir/Pokémon Esmeralda.sav', '$mayDir/Pokémon Esmeralda.srm', '$mayDir/ultima.json']);
      fs.files.remove(mayMain);
      final r = await repo.reindex();
      expect(r.mains.where((m) => m.state == MainState.written).single.path, mayMainRel);
      expect(fs.files[mayMain]!.$1, emerald());
      expect(r.loose, isEmpty, reason: 'los principales no son saves sueltos');
    });

    test('principal reemplazado a mano: se detecta, nunca se borra y se guarda como copia nueva', () async {
      final fs = MemoryFolderFs();
      final repo = device(fs);
      await repo.importBytes(emerald(), fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1));
      // El usuario copia encima un save nuevo desde el juego.
      final fromGame = emerald(hours: 99);
      await fs.writeReplace(mayMain, fromGame);
      var r = await repo.reindex();
      expect(r.modifiedMains.single.path, mayMainRel);
      expect(r.modifiedMains.single.fileSha, sha(fromGame));
      expect(fs.files[mayMain]!.$1, fromGame, reason: 'no se pisa');
      // Llega otra copia más nueva: el principal manual sigue intacto.
      await repo.importBytes(emerald(hours: 80), fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 3));
      expect(fs.files[mayMain]!.$1, fromGame);
      // «Guardar como nueva copia»: pasa al historial y es la versión actual.
      expect(await repo.saveMainAsCopy(mayMainRel), isA<ImportAdded>());
      r = await repo.reindex();
      expect(r.modifiedMains, isEmpty);
      expect(r.mains.single.state, MainState.current);
      expect(fs.files[mayMain]!.$1, fromGame);
      final snaps = (await repo.allSlots()).single.$2;
      expect(snaps.last.sha256, sha(fromGame));
      expect(snaps, hasLength(3));
    });

    test('restaurar crea una entrada nueva «restaurada» y actualiza el principal; el historial no cambia', () async {
      final fs = MemoryFolderFs();
      final repo = device(fs);
      final v1 = emerald();
      final v2 = emerald(hours: 60);
      await repo.importBytes(v1, fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1));
      await repo.importBytes(v2, fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 2));
      final before = {for (final e in fs.files.entries) if (e.key.contains('/historial/')) e.key: sha(e.value.$1)};
      final old = (await repo.allSlots()).single.$2.first;
      final out = await repo.restoreAsCurrent(old, note: 'Restaurada', now: DateTime(2026, 1, 3));
      expect(out, isA<ImportAdded>());
      expect(fs.files[mayMain]!.$1, v1);
      final after = {for (final e in fs.files.entries) if (e.key.contains('/historial/')) e.key: sha(e.value.$1)};
      // Lo que había sigue igual; se añade un save + su .json.
      before.forEach((k, v) => expect(after[k], v));
      expect(after.length, before.length + 2);
      final snaps = (await repo.allSlots()).single.$2;
      expect(snaps.map((s) => s.origin), ['file', 'file', 'restored']);
      expect(snaps.last.sha256, sha(v1));
      // Otro dispositivo reindexa desde cero: misma versión actual, la
      // restauración no se colapsa con la copia original.
      final b = device(fs, 'B');
      final r = await b.reindex();
      expect(r.added, 3);
      expect(r.mains.single.state, MainState.current);
    });
  });

  group('migración al diseño con historial/', () {
    test('mueve todo a historial/, verifica hashes, conserva el índice y es idempotente', () async {
      final fs = MemoryFolderFs();
      final repo = device(fs);
      await repo.importBytes(emerald(), fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1));
      await repo.importBytes(emerald(hours: 60), fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 2));
      await repo.importBytes(SyntheticSaves.gen4(trainer: const SynthTrainer(name: 'LYRA')), fileName: 'pt.dsv',
          origin: ImportOrigin.file, now: DateTime(2026, 1, 3));
      final hashes = {for (final e in fs.files.entries) if (e.key.contains('/historial/')) e.key.split('/').last: sha(e.value.$1)};
      // Índice y carpeta como los dejaría la versión anterior.
      toLegacy(fs);
      final ids = <int>[];
      for (final s in (await repo.allSlots()).expand((e) => e.$2)) {
        ids.add(s.id);
        await repo.db.customStatement(
            'UPDATE snapshots SET rel_path = ? WHERE id = ?', [s.relPath!.replaceFirst('/historial/', '/'), s.id]);
      }
      final listing = await repo.folder.listing();
      expect(ArcaMigration.needsHistoryLayout(listing), isTrue);

      final r = await repo.reindex();
      expect(r.historyMigration!.copied, 3);
      expect(r.historyMigration!.failures, isEmpty);
      expect(r.added, 0, reason: 'mismas filas del índice');
      expect(r.removed, 0);
      final snaps = (await repo.allSlots()).expand((e) => e.$2).toList();
      expect(snaps.map((s) => s.id).toSet(), ids.toSet());
      expect(snaps.every((s) => ArcaLayout.inHistory(s.relPath!)), isTrue);
      // Mismos bytes en historial/, nada suelto y principales generados.
      for (final MapEntry(:key, :value) in fs.files.entries) {
        if (key.contains('/historial/')) expect(sha(value.$1), hashes[key.split('/').last], reason: key);
        expect(ArcaLayout.managedSave.hasMatch(key.split('/').last) && !key.contains('/historial/'), isFalse, reason: key);
      }
      expect(fs.files[mayMain]!.$1, emerald(hours: 60));
      expect(fs.files.containsKey('PKArkTools/Pokémon Platino/LYRA (12345)/Pokémon Platino.dsv'), isTrue);
      // README de la raíz actualizado a la estructura nueva.
      expect(utf8.decode(fs.files['PKArkTools/README.txt']!.$1), contains(ArcaLayout.readmeRevision));

      // Repetirla no cambia nada.
      final snapshot = {for (final e in fs.files.entries) e.key: sha(e.value.$1)};
      final again = await repo.reindex();
      expect(again.historyMigration, isNull);
      expect({for (final e in fs.files.entries) e.key: sha(e.value.$1)}, snapshot);
    });

    test('cortada a mitad (tras escribir, tras borrar el .json): se completa sin perder nada', () async {
      for (final cut in [1, 2, 3]) {
        final fs = FlakyFs();
        final repo = device(fs);
        await repo.importBytes(emerald(), fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1));
        await repo.importBytes(emerald(hours: 60), fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 2));
        final expected = {for (final e in fs.files.entries) if (e.key.contains('/historial/')) e.key: sha(e.value.$1)};
        toLegacy(fs);
        // 1: falla al borrar el primer .json antiguo; 2: tras borrarlo, al
        // borrar el save antiguo; 3: al escribir el .json en historial/.
        if (cut == 3) {
          fs.failWriteAt = 2;
        } else {
          fs.failDeleteAt = cut;
        }
        final b = device(fs, 'B');
        final first = await b.reindex();
        expect(first.historyMigration!.failures, isNotEmpty, reason: 'corte $cut');
        fs
          ..failDeleteAt = null
          ..failWriteAt = null;
        await b.reindex();
        final r = await b.reindex();
        expect(r.issues, isEmpty, reason: 'corte $cut: ${r.issues}');
        expect({for (final e in fs.files.entries) if (e.key.contains('/historial/')) e.key: sha(e.value.$1)}, expected,
            reason: 'corte $cut');
        expect(fs.files.keys.where((k) => ArcaLayout.managedSave.hasMatch(k.split('/').last) && !k.contains('/historial/')),
            isEmpty);
        expect((await b.allSlots()).single.$2, hasLength(2));
        expect(fs.files[mayMain]!.$1, emerald(hours: 60));
      }
    });

    test('una copia dañada no se mueve y se informa', () async {
      final fs = MemoryFolderFs();
      final repo = device(fs);
      await repo.importBytes(emerald(), fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1));
      toLegacy(fs);
      final key = fs.files.keys.firstWhere((k) => k.endsWith('.sav'));
      final bad = Uint8List.fromList(fs.files[key]!.$1)..[300] ^= 1;
      fs.files[key] = (bad, DateTime.now());
      final r = await device(fs, 'B').reindex();
      expect(r.historyMigration!.failures.single, contains(key.substring('PKArkTools/'.length)));
      expect(fs.files[key]!.$1, bad, reason: 'nunca se borra');
    });
  });

  group('varios dispositivos', () {
    test('escrituras a la vez: el historial no choca y el principal converge en la más nueva', () async {
      final fs = MemoryFolderFs();
      final a = device(fs, 'Mac');
      final b = device(fs, 'Android');
      final va = emerald(hours: 50);
      final vb = emerald(hours: 51);
      await Future.wait([
        a.importBytes(va, fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 2, 1, 10)),
        b.importBytes(vb, fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 2, 1, 11)),
      ]);
      expect(fs.files.keys.where((k) => k.contains('/historial/') && k.endsWith('.sav')), hasLength(2));
      for (final repo in [a, b]) {
        await repo.reindex();
        expect(fs.files[mayMain]!.$1, vb);
      }
    });

    test('copias de conflicto del principal: se retiran si su contenido está en el historial; si no, se ofrecen', () async {
      final fs = MemoryFolderFs();
      final repo = device(fs);
      final v1 = emerald();
      await repo.importBytes(v1, fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1));
      final stranger = emerald(hours: 77);
      await fs.writeNew('$mayDir/Pokémon Esmeralda (1).sav', v1);
      await fs.writeNew('$mayDir/Pokémon Esmeralda 2.sav', v1);
      await fs.writeNew("$mayDir/Pokémon Esmeralda (Ana's conflicted copy).sav", stranger);
      await fs.writeNew('$mayDir/.Pokémon Esmeralda.sav.icloud', Uint8List(10));
      await fs.writeNew('$mayDir/ultima (1).json', Uint8List.fromList(utf8.encode('{}')));
      final r = await repo.reindex();
      expect(r.conflictsCleaned, 2);
      expect(fs.files.containsKey('$mayDir/Pokémon Esmeralda (1).sav'), isFalse);
      expect(fs.files.containsKey('$mayDir/Pokémon Esmeralda 2.sav'), isFalse);
      expect(r.loose.single.path, "$mayDir/Pokémon Esmeralda (Ana's conflicted copy).sav".substring('PKArkTools/'.length));
      expect(fs.files[mayMain]!.$1, v1);
      // Adoptarla la pasa al historial antes de retirarla: nada se pierde.
      await repo.adopt(r.loose.single.path);
      expect((await repo.allSlots()).single.$2.map((s) => s.sha256), contains(sha(stranger)));
    });

    test('principal de otro dispositivo cuyo historial aún no llegó: se espera sin tocarlo', () async {
      final fs = MemoryFolderFs();
      final a = device(fs, 'Mac');
      await a.importBytes(emerald(), fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1));
      // El otro dispositivo escribió una copia más nueva: llegaron el
      // principal y ultima.json, pero aún no su historial.
      final newer = emerald(hours: 90);
      await fs.writeReplace(mayMain, newer);
      await fs.writeReplace(
          '$mayDir/ultima.json',
          ArcaMainFiles.encodeLatest({
            'Pokémon Esmeralda.sav': {
              'sha256': sha(newer),
              'history': 'historial/2026-01-05_000000_${sha(newer).substring(0, 8)}.sav',
              'importedAt': DateTime.utc(2026, 1, 5).toIso8601String(),
            },
          }));
      final r = await a.reindex();
      expect(r.mains.single.state, MainState.pending);
      expect(r.modifiedMains, isEmpty);
      expect(fs.files[mayMain]!.$1, newer);
    });

    test('eliminar la partida retira también su principal y ultima.json', () async {
      final fs = MemoryFolderFs();
      final repo = device(fs);
      await repo.importBytes(emerald(), fileName: 'e.sav', origin: ImportOrigin.file);
      await repo.deleteSlot((await repo.allSlots()).single.$1.id);
      expect(fs.files.keys.where((k) => k.startsWith(mayDir)), isEmpty);
    });
  });

  group('SAF y bookmarks (fakes de plataforma)', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const saf = MethodChannel('dev.pkarktools/saf');
    const apple = MethodChannel('dev.pkarktools/folder');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() {
      messenger.setMockMethodCallHandler(saf, null);
      messenger.setMockMethodCallHandler(apple, null);
    });

    test('SAF: migración, principal atómico (treeReplace) y reindexado por el canal', () async {
      // Árbol SAF simulado: el canal opera sobre un mapa como MainActivity.kt.
      final tree = <String, Uint8List>{};
      final calls = <String>[];
      messenger.setMockMethodCallHandler(saf, (call) async {
        final args = (call.arguments as Map).cast<String, Object?>();
        final path = args['path'] as String?;
        calls.add(call.method);
        switch (call.method) {
          case 'treeCheck':
            return true;
          case 'treeList':
            final dir = args['dir']! as String;
            return [
              for (final MapEntry(:key, :value) in tree.entries)
                if (dir.isEmpty || key.startsWith('$dir/')) {'path': key, 'size': value.length, 'modified': 0},
            ];
          case 'treeRead':
            final b = tree[path];
            if (b == null) throw PlatformException(code: 'not_found');
            return b;
          case 'treeExists':
            return tree.containsKey(path);
          case 'treeWriteNew':
            if (tree.containsKey(path)) throw PlatformException(code: 'exists');
            tree[path!] = args['bytes']! as Uint8List;
            return null;
          case 'treeReplace':
            tree[path!] = args['bytes']! as Uint8List;
            return null;
          case 'treeDelete':
            tree.remove(path);
            return null;
        }
        return null;
      });
      final fs = SafFolderFs('content://tree/primary%3AArca', 'Arca');
      // Carpeta en el diseño anterior escrita por otro dispositivo.
      final mem = MemoryFolderFs();
      final old = device(mem, 'Viejo');
      await old.importBytes(emerald(), fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1));
      toLegacy(mem);
      tree.addAll({for (final e in mem.files.entries) e.key: e.value.$1});

      final repo = ArcaRepository(memoryDb()..also(dbs.add), await ArcaFolder.open(fs), deviceName: 'Android');
      final r = await repo.reindex();
      expect(r.historyMigration!.copied, 1);
      expect(tree[mayMain], emerald());
      expect(calls, contains('treeReplace'));
      expect(tree.keys.where((k) => k.contains('/historial/')), hasLength(2));
      // Principal cambiado a mano en el móvil: se detecta igual.
      tree[mayMain] = emerald(hours: 12);
      expect((await repo.reindex()).modifiedMains, hasLength(1));
    });

    test('bookmark (iOS/macOS): se resuelve a una ruta y funciona igual con dart:io', () async {
      final dir = await Directory.systemTemp.createTemp('arca_bookmark');
      addTearDown(() => dir.delete(recursive: true));
      messenger.setMockMethodCallHandler(apple, (call) async {
        expect(call.method, 'resolve');
        return {'path': dir.path, 'bookmark': 'renovado'};
      });
      final opened = await const PlatformFolderAccess().open(const ArcaLocation(LocationKind.bookmark, value: 'b64'));
      expect(opened.location.value, 'renovado');
      final repo = ArcaRepository(memoryDb()..also(dbs.add), await ArcaFolder.open(opened.fs), deviceName: 'iPhone');
      await repo.importBytes(emerald(), fileName: 'e.sav', origin: ImportOrigin.file);
      final main = File('${dir.path}/$mayMain');
      expect(main.readAsBytesSync(), emerald());
      // Sin temporales a la vista tras la escritura atómica.
      expect(dir.listSync(recursive: true).where((e) => e.path.endsWith('.tmp')), isEmpty);
      // Reemplazo atómico del principal al llegar otra copia.
      await repo.importBytes(emerald(hours: 70), fileName: 'e.sav', origin: ImportOrigin.file,
          now: DateTime.now().add(const Duration(minutes: 1)));
      expect(main.readAsBytesSync(), emerald(hours: 70));
    });
  });
}

extension<T> on T {
  T also(void Function(T) f) {
    f(this);
    return this;
  }
}
