import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/data/arca_problems.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/arca_layout.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';

ArcaDatabase memoryDb() => ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

Uint8List emerald({String name = 'MAY', int hours = 48}) =>
    SyntheticSaves.gen3(trainer: SynthTrainer(name: name, hours: hours));

String sha(Uint8List b) => ArcaFolder.sha256Of(b);

const root = 'PKArkTools';
const mayDir = 'Pokémon Esmeralda/MAY (12345)';
final old = DateTime(2026, 1, 1);

void main() {
  final dbs = <ArcaDatabase>[];

  ArcaRepository device(MemoryFolderFs fs, [String name = 'A']) {
    final db = memoryDb();
    dbs.add(db);
    return ArcaRepository(db, ArcaFolder(fs), deviceName: name, inboxSettle: Duration.zero);
  }

  tearDown(() async {
    for (final db in dbs) {
      await db.close();
    }
    dbs.clear();
  });

  /// Arca con una copia de MAY y su ruta en el historial.
  Future<(MemoryFolderFs, ArcaRepository, String)> arca() async {
    final fs = MemoryFolderFs();
    final repo = device(fs);
    await repo.importBytes(emerald(), fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1, 10));
    final rel = (await repo.allSlots()).single.$2.single.relPath!;
    return (fs, repo, rel);
  }

  Future<List<ArcaProblem>> problems(ArcaRepository repo) async => arcaProblemsOf(await repo.reindex());

  List<String> quarantined(MemoryFolderFs fs) =>
      [for (final k in fs.files.keys) if (k.startsWith('$root/${ArcaLayout.quarantineDir}/')) k.substring(root.length + 1)]..sort();

  group('resumen', () {
    test('un Arca sana no tiene problemas; lo de la cuarentena nunca cuenta', () async {
      final (fs, repo, _) = await arca();
      fs.files['$root/${ArcaLayout.quarantineDir}/x/2026-01-01_000000_abcdef01.sav'] = (emerald(hours: 3), old);
      fs.files['$root/${ArcaLayout.quarantineDir}/suelto.sav'] = (emerald(hours: 4), old);
      expect(await problems(repo), isEmpty);
    });

    test('cada tipo con su ruta, tamaño y fecha; errores antes que avisos', () async {
      final (fs, repo, rel) = await arca();
      fs.files['$root/$rel.json'] = (Uint8List.fromList(utf8.encode('{roto')), old);
      fs.files['$root/copiados/Mi Esmeralda.sav'] = (emerald(hours: 70), old);
      // Otro dispositivo (o una instalación nueva) lee el .json al indexar.
      final list = await problems(device(fs, 'B'));
      expect(list.map((p) => p.kind), [ArcaProblemKind.corruptSidecar, ArcaProblemKind.looseSave]);
      expect(list.first.path, '$rel.json');
      expect(list.first.kind.isError, isTrue);
      expect(list.last.kind.isError, isFalse);
      expect(list.last.size, emerald().length);
      expect(list.last.modified, old);
    });
  });

  group('arreglar', () {
    test('.json dañado: se regenera desde el save, conserva fecha y origen y el antiguo va a la cuarentena', () async {
      final (fs, a, rel) = await arca();
      await a.reindex();
      final repo = device(fs, 'B');
      final good = jsonDecode(utf8.decode(fs.files['$root/$rel.json']!.$1)) as Map<String, Object?>;
      // Le falta un bloque: no se puede leer como .json del Arca.
      final broken = {...good}..remove('trainer');
      fs.files['$root/$rel.json'] = (Uint8List.fromList(utf8.encode(jsonEncode(broken))), old);
      final list = await problems(repo);
      expect(list.single.kind, ArcaProblemKind.corruptSidecar);
      final r = await ArcaRepair(repo).fixAll(list);
      expect(r.fixed, 1);
      expect(await problems(repo), isEmpty);
      final meta = await repo.folder.readMeta(rel);
      expect(meta.sha256, sha(emerald()));
      expect(meta.importedAt, DateTime(2026, 1, 1, 10));
      expect(meta.origin, 'file');
      expect(meta.trainerName, 'MAY');
      expect(quarantined(fs), ['${ArcaLayout.quarantineDir}/$rel.json', '${ArcaLayout.quarantineDir}/$rel.json.nota.txt']);
      expect((await repo.allSlots()).single.$2, hasLength(1));
    });

    test('falta el .json: se regenera con la fecha del nombre', () async {
      final (fs, repo, rel) = await arca();
      fs.files.remove('$root/$rel.json');
      final list = await problems(repo);
      expect(list.single.kind, ArcaProblemKind.missingSidecar);
      await ArcaRepair(repo).fixAll(list);
      expect(await problems(repo), isEmpty);
      final meta = await repo.folder.readMeta(rel);
      expect(meta.importedAt, ArcaRepair.stampOf(rel.split('/').last));
      expect(meta.origin, 'adopted');
      expect(quarantined(fs), isEmpty);
    });

    test('.json sin save: a la cuarentena con nota (nada se borra)', () async {
      final (fs, repo, rel) = await arca();
      final json = fs.files['$root/$rel.json']!.$1;
      fs.files['$root/$mayDir/historial/2026-01-05_000000_00000000.sav.json'] = (json, old);
      final list = await problems(repo);
      expect(list.single.kind, ArcaProblemKind.missingSave);
      final r = await ArcaRepair(repo).fixAll(list);
      expect(r.quarantined, 1);
      expect(await problems(repo), isEmpty);
      final q = '$root/${ArcaLayout.quarantineDir}/$mayDir/historial/2026-01-05_000000_00000000.sav.json';
      expect(fs.files[q]!.$1, json);
      expect(utf8.decode(fs.files['$q.nota.txt']!.$1), contains('Nothing was deleted'));
    });

    test('save que no coincide con su .json: su contenido entra como copia nueva y la pareja va a la cuarentena', () async {
      final (fs, repo, rel) = await arca();
      // Alguien copió encima otro save (de otro tamaño).
      final changed = SyntheticSaves.gen4(trainer: const SynthTrainer(name: 'LYRA'));
      fs.files['$root/$rel'] = (changed, old);
      final list = await problems(repo);
      expect(list.single.kind, ArcaProblemKind.contentMismatch);
      final r = await ArcaRepair(repo).fixAll(list);
      expect(r.fixed, 1);
      expect(await problems(repo), isEmpty);
      expect(quarantined(fs), containsAll(['${ArcaLayout.quarantineDir}/$rel', '${ArcaLayout.quarantineDir}/$rel.json']));
      final snaps = (await repo.allSlots()).single.$2;
      expect(snaps.single.sha256, sha(changed));
      expect(snaps.single.gameCode, 'pt');
      expect(fs.files.containsKey('$root/$mayDir/Pokémon Esmeralda.sav'), isTrue, reason: 'un principal nunca se borra');
    });

    test('SHA-256 distinto detectado al leer: se informa al reindexar', () async {
      final (fs, repo, rel) = await arca();
      final bad = Uint8List.fromList(emerald())..[300] ^= 1;
      fs.files['$root/$rel'] = (bad, old);
      final s = (await repo.allSlots()).single.$2.single;
      await expectLater(repo.snapshotBytes(s), throwsA(isA<ArcaFileCorruptException>()));
      final list = await problems(repo);
      expect(list.single.kind, ArcaProblemKind.contentMismatch);
      expect(list.single.path, rel);
    });

    test('saves sueltos: el legible se adopta; el que no es un save va a la cuarentena', () async {
      final (fs, repo, _) = await arca();
      fs.files['$root/copiados/Mi Esmeralda.sav'] = (emerald(hours: 70), old);
      fs.files['$root/basura.bin'] = (Uint8List(0x20000), old);
      final list = await problems(repo);
      expect(list.map((p) => p.kind), everyElement(ArcaProblemKind.looseSave));
      final r = await ArcaRepair(repo).fixAll(list);
      expect((r.fixed, r.quarantined), (1, 1));
      expect(await problems(repo), isEmpty);
      expect(fs.files.containsKey('$root/copiados/Mi Esmeralda.sav'), isFalse);
      expect(quarantined(fs), contains('${ArcaLayout.quarantineDir}/basura.bin'));
      expect((await repo.allSlots()).single.$2, hasLength(2));
    });

    test('copias de conflicto: la que ya está en el historial se retira; la desconocida se adopta', () async {
      final (fs, repo, rel) = await arca();
      // Caso real: «2026-01-01_120000_1a2b3c4d (1).sav» junto al historial.
      final copy = rel.replaceFirst('.sav', ' (1).sav');
      fs.files['$root/$copy'] = (emerald(), old);
      fs.files['$root/$mayDir/Pokémon Esmeralda (1).sav'] = (emerald(hours: 75), old);
      final list = await problems(repo);
      expect(list.map((p) => p.kind), everyElement(ArcaProblemKind.conflictCopy));
      expect(list, hasLength(2));
      final r = await ArcaRepair(repo).fixAll(list);
      expect(r.counts[FixOutcome.retired], 1);
      expect(r.counts[FixOutcome.fixed], 1);
      expect(await problems(repo), isEmpty);
      expect((await repo.allSlots()).single.$2.map((s) => s.sha256), containsAll([sha(emerald()), sha(emerald(hours: 75))]));
    });

    test('principal cambiado a mano: se guarda como copia nueva y el archivo se queda', () async {
      final (fs, repo, _) = await arca();
      const main = '$root/$mayDir/Pokémon Esmeralda.sav';
      fs.files[main] = (emerald(hours: 80), old);
      final list = await problems(repo);
      expect(list.single.kind, ArcaProblemKind.modifiedMain);
      await ArcaRepair(repo).fixAll(list);
      expect(await problems(repo), isEmpty);
      expect(fs.files[main]!.$1, emerald(hours: 80));
      expect((await repo.allSlots()).single.$2, hasLength(2));
    });

    test('bandeja: el de otro juego se mueve a su juego; el ilegible va a la cuarentena', () async {
      final (fs, repo, _) = await arca();
      fs.files['$root/Pokémon Esmeralda/Platino.sav'] = (SyntheticSaves.gen4(trainer: const SynthTrainer(name: 'LYRA')), old);
      fs.files['$root/Pokémon Esmeralda/roto.sav'] = (Uint8List(0x20000), old);
      final list = await problems(repo);
      expect(list.map((p) => p.kind).toSet(), {ArcaProblemKind.inboxUnreadable, ArcaProblemKind.inboxWrongGame});
      final r = await ArcaRepair(repo).fixAll(list);
      expect((r.fixed, r.quarantined), (1, 1));
      expect(await problems(repo), isEmpty);
      expect((await repo.allSlots()).map((s) => s.$1.gameCode).toSet(), {'emerald', 'pt'});
      expect(quarantined(fs), contains('${ArcaLayout.quarantineDir}/Pokémon Esmeralda/roto.sav'));
    });

    test('un fallo no detiene el resto y se cuenta', () async {
      final (fs, repo, _) = await arca();
      fs.files['$root/copiados/a.sav'] = (emerald(hours: 70), old);
      const ghost = ArcaProblem(ArcaProblemKind.looseSave, 'no/existe.sav');
      final list = [ghost, ...await problems(repo)];
      final progress = <int>[];
      final r = await ArcaRepair(repo).fixAll(list, onProgress: (d, _) => progress.add(d));
      expect((r.fixed, r.failed), (1, 1));
      expect(r.errors.single, startsWith('no/existe.sav'));
      expect(progress, [0, 1, 2]);
    });
  });

  group('ignorar', () {
    test('se guarda en los ajustes locales y deja de valer si el archivo cambia', () async {
      final (fs, repo, _) = await arca();
      fs.files['$root/copiados/a.sav'] = (emerald(hours: 70), old);
      final p = (await problems(repo)).single;
      await ArcaProblemIgnores.save(repo, {p.ignoreKey});
      expect(await ArcaProblemIgnores.load(repo), {p.ignoreKey});
      expect(fs.files.keys.where((k) => k.contains('ignor')), isEmpty, reason: 'nada en la carpeta del Arca');
      expect((await problems(repo)).single.ignoreKey, p.ignoreKey, reason: 'mismo archivo, misma clave');
      // El archivo cambia (contenido y fecha): vuelve a avisar.
      fs.files['$root/copiados/a.sav'] = (emerald(hours: 71), DateTime(2026, 2, 1));
      expect((await problems(repo)).single.ignoreKey, isNot(p.ignoreKey));
    });
  });
}
