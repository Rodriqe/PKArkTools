import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_access.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';

import 'arca_folder_test.dart' show memoryDb;
import 'arca_screen_test.dart' show settle;

/// Selector de carpetas simulado: "elige" [picked] y la carpeta local es [local].
class FakeFolderAccess implements FolderAccess {
  FakeFolderAccess(this.picked, this.local);
  final Directory picked;
  final Directory local;
  int picks = 0;

  @override
  FolderSuggestion get suggestion => FolderSuggestion.iCloudDrive;

  @override
  Future<OpenedFolder?> pick() async {
    picks++;
    return OpenedFolder(ArcaLocation(LocationKind.path, value: picked.path, label: picked.path), IoFolderFs(picked));
  }

  @override
  Future<OpenedFolder> appLocal() async =>
      OpenedFolder(ArcaLocation(LocationKind.appLocal, label: local.path), IoFolderFs(local));

  @override
  Future<OpenedFolder> open(ArcaLocation location) async {
    final dir = Directory(location.value.isEmpty ? local.path : location.value);
    if (!dir.existsSync()) throw FolderAccessLostException('No existe ${dir.path}');
    return OpenedFolder(location, IoFolderFs(dir));
  }
}

void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late Directory cloud;
  late Directory local;
  late FakeFolderAccess access;

  setUp(() async {
    db = memoryDb();
    tmp = await Directory.systemTemp.createTemp('folder_ui');
    cloud = Directory(p.join(tmp.path, 'iCloud Drive', 'Arca'))..createSync(recursive: true);
    local = Directory(p.join(tmp.path, 'Documentos'))..createSync(recursive: true);
    access = FakeFolderAccess(cloud, local);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    required ArcaRepository repo,
    required ArcaSetup setup,
    String initial = '/arca',
    Size size = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        arcaRepositoryProvider.overrideWithValue(repo),
        initialArcaSetupProvider.overrideWithValue(setup),
        folderAccessProvider.overrideWithValue(access),
      ],
      child: PKArkToolsApp(initialLocation: initial),
    ));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
    await settle(tester);
  }

  testWidgets('onboarding: explica, sugiere iCloud Drive y usa la carpeta local', (tester) async {
    final repo = ArcaRepository(db, null, deviceName: 'test');
    await pumpApp(tester, repo: repo, setup: const SetupNeeded(legacyCount: 3));
    expect(find.text('Tu Arca, en tu carpeta'), findsOneWidget);
    expect(find.textContaining('iCloud Drive y tendrás el mismo Arca'), findsOneWidget);
    expect(find.textContaining('Tus 3 copias actuales'), findsOneWidget);
    expect(find.text('Elegir carpeta'), findsOneWidget);
    expect(find.text('Usar carpeta local de la app'), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await tester.tap(find.text('Usar carpeta local de la app'));
    await settle(tester, until: find.text('Tu Arca está vacía'));
    expect(find.text('Tu Arca está vacía'), findsOneWidget);
    expect(File(p.join(local.path, 'PKArkTools', 'README.txt')).existsSync(), isTrue);
    expect(await repo.getSetting(ArcaController.locationKey), contains('appLocal'));
  });

  testWidgets('onboarding: elegir una carpeta con copias de otro dispositivo las muestra', (tester) async {
    // Otro dispositivo ya dejó una copia en la carpeta.
    final otherDb = memoryDb();
    addTearDown(otherDb.close);
    await tester.runAsync(() => ArcaRepository(otherDb, ArcaFolder(IoFolderFs(cloud)), deviceName: 'iPhone').importBytes(
        SyntheticSaves.gen3(trainer: const SynthTrainer(name: 'MAY')),
        fileName: 'E.sav',
        origin: ImportOrigin.file));

    final repo = ArcaRepository(db, null, deviceName: 'Mac');
    await pumpApp(tester, repo: repo, setup: const SetupNeeded());
    expect(find.textContaining('Tus'), findsNothing);
    await tester.tap(find.text('Elegir carpeta'));
    await settle(tester, until: find.text('MAY'));
    expect(access.picks, 1);
    expect(find.text('MAY'), findsWidgets);
  });

  testWidgets('acceso perdido: pantalla clara y volver a elegir la carpeta', (tester) async {
    final repo = ArcaRepository(db, null, deviceName: 'Mac');
    final gone = ArcaLocation(LocationKind.bookmark, value: 'xx', label: '/Volumes/USB/Arca');
    await pumpApp(tester, repo: repo, setup: SetupAccessLost(gone, 'La carpeta no está disponible'));
    expect(find.text('No podemos abrir tu Arca'), findsOneWidget);
    expect(find.textContaining('/Volumes/USB/Arca'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Volver a elegir la carpeta'));
    await settle(tester, until: find.text('Tu Arca está vacía'));
    expect(find.text('Tu Arca está vacía'), findsOneWidget);
  });

  testWidgets('Ajustes: carpeta, reindexar y adoptar un save suelto', (tester) async {
    final repo = ArcaRepository(db, ArcaFolder(IoFolderFs(cloud)), deviceName: 'Mac');
    await tester.runAsync(() async {
      await repo.importBytes(SyntheticSaves.gen3(trainer: const SynthTrainer(name: 'MAY')),
          fileName: 'E.sav', origin: ImportOrigin.file);
      File(p.join(cloud.path, 'PKArkTools', 'Platino copiado.sav'))
          .writeAsBytesSync(SyntheticSaves.gen4(trainer: const SynthTrainer(name: 'DAWN')));
      File(p.join(cloud.path, 'PKArkTools', 'x (conflicted copy).sav')).writeAsBytesSync([1, 2, 3]);
      await repo.reindex();
    });
    await pumpApp(tester,
        repo: repo,
        setup: SetupReady(ArcaLocation(LocationKind.path, value: cloud.path, label: cloud.path)),
        initial: '/ajustes',
        size: const Size(1280, 1600));
    expect(find.text('Carpeta del Arca'), findsOneWidget);
    expect(find.text('Sincronizada con iCloud Drive'), findsOneWidget);
    expect(find.text('Saves sueltos (1)'), findsOneWidget);
    expect(find.textContaining('1 archivo ignorado'), findsOneWidget);

    await tester.tap(find.text('Reindexar'));
    await settle(tester, until: find.textContaining('Reindexado:'));
    expect(find.textContaining('Reindexado: 0 nuevas'), findsOneWidget);

    await tester.tap(find.text('Adoptar').first);
    for (var i = 0; i < 5 && find.textContaining('Adoptado:').evaluate().isEmpty; i++) {
      await settle(tester, until: find.textContaining('Adoptado:'));
    }
    expect(find.textContaining(RegExp(r'Adoptado: Pokémon .+ · DAWN')), findsOneWidget);
    await settle(tester);
    expect(find.textContaining('Saves sueltos'), findsNothing);
    expect(File(p.join(cloud.path, 'PKArkTools', 'Platino copiado.sav')).existsSync(), isFalse);
  });
}
