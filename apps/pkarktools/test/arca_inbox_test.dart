import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/arca_game_folders.dart';
import 'package:pkarktools/data/folder/arca_layout.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';

ArcaDatabase memoryDb() => ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

Uint8List emerald({String name = 'MAY', int hours = 48}) =>
    SyntheticSaves.gen3(trainer: SynthTrainer(name: name, hours: hours));

const emeraldDir = 'PKArkTools/Pokémon Esmeralda';
const mayMain = '$emeraldDir/MAY (12345)/Pokémon Esmeralda.sav';

void main() {
  final dbs = <ArcaDatabase>[];

  ArcaRepository device(MemoryFolderFs fs, {Duration settle = Duration.zero}) {
    final db = memoryDb();
    dbs.add(db);
    return ArcaRepository(db, ArcaFolder(fs), deviceName: 'A', inboxSettle: settle);
  }

  tearDown(() async {
    for (final db in dbs) {
      await db.close();
    }
    dbs.clear();
  });

  group('carpetas de juegos', () {
    test('creación selectiva, idempotente y con los mismos nombres que el layout', () async {
      final fs = MemoryFolderFs();
      final folder = ArcaFolder(fs);
      final r = await ArcaGameFolders.create(folder, {GameVersion.emerald, GameVersion.swordShield}, es: true);
      expect((r.created, r.existing), (2, 0));
      expect(fs.files.keys.where((k) => k != 'PKArkTools/README.txt').toList()..sort(),
          ['PKArkTools/Pokémon Esmeralda/LEEME.txt', 'PKArkTools/Pokémon Espada - Escudo/LEEME.txt']);
      expect(ArcaGameFolders.dirOf(GameVersion.emerald), ArcaLayout.gameDir('emerald'));
      // Repetir (en otro idioma incluso) no duplica ni pisa.
      final again = await ArcaGameFolders.create(folder, {GameVersion.emerald, GameVersion.platinum}, es: false);
      expect((again.created, again.existing), (1, 1));
      expect(fs.files.containsKey('PKArkTools/Pokémon Esmeralda/README.txt'), isFalse);
      expect(fs.files.containsKey('PKArkTools/Pokémon Platino/README.txt'), isTrue);
      expect(await ArcaGameFolders.existing(folder), {GameVersion.emerald, GameVersion.swordShield, GameVersion.platinum});
    });

    test('el LEEME dice qué archivo dejar y con qué nombre suele venir', () {
      final swsh = ArcaGameFolders.readme(GameVersion.swordShield, es: true);
      expect(swsh, contains('«main»'));
      expect(swsh, contains('JKSM'));
      expect(ArcaGameFolders.readme(GameVersion.brilliantDiamondShiningPearl, es: false), contains('SaveData.bin'));
      expect(ArcaGameFolders.readme(GameVersion.xy, es: true), contains('Checkpoint'));
      expect(ArcaGameFolders.readme(GameVersion.platinum, es: true), contains('.dsv'));
      expect(ArcaGameFolders.readme(GameVersion.emerald, es: false), contains('.sav'));
      expect(ArcaGameFolders.readme(GameVersion.emerald, es: false), contains('historial/'));
    });

    test('los LEEME no cuentan como sueltos ni ignorados', () async {
      final fs = MemoryFolderFs();
      final repo = device(fs);
      await ArcaGameFolders.create(repo.folder, GameVersion.values, es: true);
      final r = await repo.reindex();
      expect(r.loose, isEmpty);
      expect(r.ignoredCount, 0);
      expect(r.inboxProblems, isEmpty);
    });
  });

  group('bandeja de entrada', () {
    test('un save del juego correcto se adopta, pasa a ser el principal y se retira de la bandeja', () async {
      final fs = MemoryFolderFs();
      final repo = device(fs);
      await repo.importBytes(emerald(), fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1));
      final fresh = emerald(hours: 70);
      await fs.writeNew('$emeraldDir/POKEMON_EMER_BPEE01.sav', fresh);
      final r = await repo.reindex();
      expect(r.inboxAdopted.single.$1, 'POKEMON_EMER_BPEE01.sav');
      expect(r.inboxAdopted.single.$2, GameVersion.emerald);
      expect(r.inboxAdopted.single.$3, 'MAY');
      expect(fs.files.containsKey('$emeraldDir/POKEMON_EMER_BPEE01.sav'), isFalse, reason: 'se mueve, no se copia');
      expect(fs.files[mayMain]!.$1, fresh);
      final snaps = (await repo.allSlots()).single.$2;
      expect(snaps.last.origin, 'inbox');
      expect(snaps.last.sha256, ArcaFolder.sha256Of(fresh));
      expect(r.loose, isEmpty);
    });

    test('una partida nueva crea su carpeta de entrenador desde la bandeja', () async {
      final fs = MemoryFolderFs();
      final repo = device(fs);
      await fs.writeNew('PKArkTools/Pokémon Platino/plat.dsv', SyntheticSaves.gen4(trainer: const SynthTrainer(name: 'DAWN')));
      final r = await repo.reindex();
      expect(r.inboxAdopted, hasLength(1));
      expect(fs.files.keys.where((k) => k.startsWith('PKArkTools/Pokémon Platino/DAWN (12345)/')).map((k) => k.split('/').last),
          containsAll(['Pokémon Platino.dsv', 'ultima.json']));
    });

    test('un save de otro juego se queda y se ofrece moverlo a su juego', () async {
      final fs = MemoryFolderFs();
      final repo = device(fs);
      const path = '$emeraldDir/equivocado.sav';
      await fs.writeNew(path, SyntheticSaves.gen4(trainer: const SynthTrainer(name: 'DAWN')));
      final r = await repo.reindex();
      final p = r.inboxProblems.single;
      expect(p.kind, InboxProblemKind.wrongGame);
      expect(p.actualGame, GameVersion.platinum);
      expect(p.folderGame, GameVersion.emerald);
      expect(fs.files.containsKey(path), isTrue);
      expect(await repo.allSlots(), isEmpty);
      // «Mover a Platino»: se adopta en su juego y se retira.
      expect(await repo.adopt(p.path), isA<ImportAdded>());
      expect(fs.files.containsKey(path), isFalse);
      expect(fs.files.keys.any((k) => k.startsWith('PKArkTools/Pokémon Platino/DAWN (12345)/historial/')), isTrue);
    });

    test('un archivo ilegible se queda donde está con su aviso', () async {
      final fs = MemoryFolderFs();
      final repo = device(fs);
      const path = '$emeraldDir/roto.sav';
      final junk = Uint8List.fromList(List.generate(131072, (i) => (i * 7) & 0xff));
      await fs.writeNew(path, junk);
      final r = await repo.reindex();
      expect(r.inboxProblems.single.kind, InboxProblemKind.unreadable);
      expect(r.inboxProblems.single.detail, isNotEmpty);
      expect(fs.files[path]!.$1, junk);
      // Sigue avisando en cada reindexado, sin tocarlo.
      expect((await repo.reindex()).inboxProblems, hasLength(1));
    });

    test('duplicado por hash: ya está en el historial, la bandeja se vacía sin copia nueva', () async {
      final fs = MemoryFolderFs();
      final repo = device(fs);
      await repo.importBytes(emerald(), fileName: 'e.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1));
      await fs.writeNew('$emeraldDir/otra vez.sav', emerald());
      final r = await repo.reindex();
      expect(r.inboxAdopted, hasLength(1));
      expect(fs.files.containsKey('$emeraldDir/otra vez.sav'), isFalse);
      expect((await repo.allSlots()).single.$2, hasLength(1));
    });

    test('un save aún copiándose espera; parciales de la nube y sueltos fuera de un juego no se tocan', () async {
      final fs = MemoryFolderFs();
      final repo = device(fs, settle: const Duration(hours: 1));
      await fs.writeNew('$emeraldDir/llegando.sav', emerald());
      await fs.writeNew('$emeraldDir/.llegando2.sav.icloud', Uint8List(100));
      await fs.writeNew('$emeraldDir/llegando3.sav.tmp', emerald());
      await fs.writeNew('PKArkTools/Otra carpeta/suelto.sav', emerald(name: 'X'));
      final r = await repo.reindex();
      expect(r.inboxPending, 1);
      expect(r.inboxAdopted, isEmpty);
      expect(fs.files.containsKey('$emeraldDir/llegando.sav'), isTrue);
      expect(r.loose.map((e) => e.path), ['Otra carpeta/suelto.sav']);
      // Pasado el margen se recoge.
      final later = device(fs);
      expect((await later.reindex()).inboxAdopted, hasLength(1));
    });

    test('carpetas de juego creadas a mano también funcionan como bandeja', () async {
      final fs = MemoryFolderFs();
      final repo = device(fs);
      await fs.writeNew('PKArkTools/${ArcaLayout.gameDir('crystal')}/cristal.sav',
          SyntheticSaves.gen2(trainer: const SynthTrainer(name: 'KRIS'), crystal: true));
      final r = await repo.reindex();
      expect(r.inboxAdopted.single.$2, GameVersion.crystal);
      expect(utf8.decode(fs.files['PKArkTools/README.txt']!.$1), startsWith(ArcaLayout.readmeMarker));
    });
  });
}
