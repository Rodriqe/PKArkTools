import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/data/arca_problems.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/arca_layout.dart';
import 'package:pkarktools/data/folder/arca_migration.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';
import 'package:pkarktools/data/team_store.dart';

const root = 'PKArkTools';

ChampionsBuild set(String text) => ChampionsBuild.fromShowdown(Showdown.parse(text).single)!.build;

void main() {
  final dbs = <ArcaDatabase>[];
  tearDown(() async {
    for (final db in dbs) {
      await db.close();
    }
    dbs.clear();
    ChampionsFormat.reset();
  });

  ArcaRepository device(MemoryFolderFs fs) {
    final db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    dbs.add(db);
    return ArcaRepository(db, ArcaFolder(fs), deviceName: 'A', inboxSettle: Duration.zero);
  }

  ChampionsTeam sample(String name) => ChampionsTeam(
    name: name,
    members: [
      set(
        'Garchomp @ Life Orb\nAbility: Rough Skin\nEVs: 2 HP / 32 Atk / 32 Spe\nJolly Nature\n- Earthquake\n- Dragon Claw',
      ),
      set(
        'Incineroar @ Sitrus Berry\nAbility: Intimidate\nEVs: 32 HP / 32 SpD / 2 Spe\nCareful Nature\n- Fake Out\n- Flare Blitz',
      ),
    ],
  );

  test('crear, editar, renombrar, duplicar, borrar y volver a leer', () async {
    final fs = MemoryFolderFs();
    final store = TeamStore(ArcaFolder(fs));
    var s = await store.save(sample('Lluvia/Sol'));
    expect(s.path, 'Competitive/Teams/Lluvia - Sol.json');
    expect(fs.files.keys, contains('$root/Competitive/Teams/Lluvia - Sol.json'));
    final json = jsonDecode(utf8.decode(fs.files['$root/${s.path}']!.$1)) as Map;
    expect(json['schema'], 'pkarktools-team');
    expect(json['schemaVersion'], 1);

    // Editar y renombrar: el archivo pasa a llamarse como el equipo.
    s.team.members.first.sp[3] = 0;
    s.team.name = 'Arena';
    s = await store.save(s.team, previous: s);
    expect(s.path, 'Competitive/Teams/Arena.json');
    expect(fs.files.keys.where((k) => k.contains('Lluvia')), isEmpty);

    // Otro equipo con el mismo nombre no pisa el primero.
    final other = await store.save(sample('Arena'));
    expect(other.path, 'Competitive/Teams/Arena (2).json');
    final dup = await store.duplicate(s, 'Arena copia');
    expect(dup.team.id, isNot(s.team.id));

    final read = (await store.list()).teams;
    expect(read.map((t) => t.team.name), ['Arena', 'Arena', 'Arena copia']);
    final again = read.firstWhere((t) => t.team.id == s.team.id);
    expect(again.team.toShowdown(), s.team.toShowdown());
    expect(again.team.members, hasLength(2));

    await store.delete(dup);
    expect((await store.list()).teams, hasLength(2));
  });

  test('importar un .json exportado y un equipo de Showdown (ida y vuelta)', () async {
    final store = TeamStore(ArcaFolder(MemoryFolderFs()));
    final t = sample('VGC');
    final imported = await store.importJson(t.encode());
    expect(imported.team.id, isNot(t.id), reason: 'siempre como equipo nuevo');
    expect(imported.team.toShowdown(), t.toShowdown());
    final back = ChampionsTeam.fromShowdown('VGC', t.toShowdown());
    expect(back.skipped, isEmpty);
    expect(back.team.toShowdown(), t.toShowdown());
    expect(() => ChampionsTeam.decode('{"schema":"pkarktools-team","schemaVersion":99}'), throwsFormatException);
  });

  test('reglas del formato: especie y objeto repetidos, tamaño', () {
    final t = sample('X');
    expect(t.teamIssues(es: false), [contains('At least 4')]);
    t.members.add(t.members.first.copy());
    final issues = t.teamIssues(es: false);
    expect(issues, contains(contains('Species clause')));
    expect(issues, contains(contains('Item clause')));
  });

  test('miembro que deja de estar permitido con otra regulación: se marca, no se borra', () {
    final t = sample('X');
    expect(t.notAllowed(), isEmpty);
    final j = jsonDecode(ChampionsData.builtinJson) as Map<String, Object?>;
    j['allowed'] = [
      for (final id in (j['allowed'] as List).cast<String>())
        if (id != 'garchomp') id,
    ];
    ChampionsFormat.use(ChampionsData.fromJson(j));
    expect(t.notAllowed(), [0]);
    expect(t.members, hasLength(2));
    expect(t.members.first.problems(es: false), contains(contains('not on the regulation list')));
  });

  test('el Arca ignora Competitive/: ni partidas ni problemas', () async {
    final fs = MemoryFolderFs();
    final repo = device(fs);
    await repo.importBytes(
      SyntheticSaves.gen3(trainer: SynthTrainer(name: 'MAY', hours: 2)),
      fileName: 'e.sav',
      origin: ImportOrigin.file,
      now: DateTime(2026, 1, 1, 10),
    );
    final store = TeamStore(repo.folder);
    await store.save(sample('Equipo'));
    // Un archivo cualquiera dentro de Competitive/ (tamaño de save de GB) tampoco cuenta.
    fs.files['$root/Competitive/Teams/raro.sav'] = (
      SyntheticSaves.gen3(trainer: SynthTrainer(name: 'X', hours: 1)),
      DateTime(2026),
    );
    final report = await repo.reindex();
    expect(arcaProblemsOf(report), isEmpty);
    expect(await repo.allSlots(), hasLength(1));
    expect(ArcaLayout.ignoreReason('Competitive/Teams/Equipo.json'), IgnoreReason.appData);
    // El README del Arca (plantilla) explica la carpeta.
    expect(ArcaLayout.readme(), contains('Competitive/Teams/'));
  });

  test('al cambiar de carpeta los equipos van con el Arca', () async {
    final from = ArcaFolder(MemoryFolderFs());
    final to = ArcaFolder(MemoryFolderFs());
    await TeamStore(from).save(sample('Viaja'));
    await ArcaMigration.copyFolder(from: from, to: to, move: true);
    expect((await TeamStore(to).list()).teams.single.team.name, 'Viaja');
    expect((await TeamStore(from).list()).teams, isEmpty);
  });
}
