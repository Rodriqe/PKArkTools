import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_problems.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/arca_layout.dart';
import 'package:pkarktools/data/folder/folder_access.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';

import 'arca_folder_test.dart' show memoryDb;
import 'arca_screen_test.dart' show settle;
import 'folder_ui_test.dart' show FakeFolderAccess;

void main() {
  late List<ArcaDatabase> dbs;
  late Directory tmp;
  late Directory arca;

  setUp(() async {
    dbs = [];
    tmp = await Directory.systemTemp.createTemp('problems_ui');
    arca = Directory(p.join(tmp.path, 'Arca'))..createSync(recursive: true);
  });

  tearDown(() async {
    for (final db in dbs) {
      await db.close();
    }
    await tmp.delete(recursive: true);
  });

  ArcaRepository device(String name) {
    final db = memoryDb();
    dbs.add(db);
    return ArcaRepository(db, ArcaFolder(IoFolderFs(arca)), deviceName: name);
  }

  String root(String rel) => p.joinAll([arca.path, 'PKArkTools', ...rel.split('/')]);

  /// Arca con tres problemas: un .json dañado (error), un save suelto y una
  /// copia de conflicto (avisos). Devuelve el repositorio de un dispositivo
  /// "nuevo" que acaba de indexar.
  Future<ArcaRepository> withProblems(WidgetTester tester) async {
    late ArcaRepository repo;
    await tester.runAsync(() async {
      final a = device('A');
      await a.importBytes(SyntheticSaves.gen3(trainer: const SynthTrainer(name: 'MAY')),
          fileName: 'E.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 1, 10));
      await a.importBytes(SyntheticSaves.gen3(trainer: const SynthTrainer(name: 'MAY', hours: 60)),
          fileName: 'E.sav', origin: ImportOrigin.file, now: DateTime(2026, 1, 2, 10));
      final rels = (await a.allSlots()).single.$2.map((s) => s.relPath!).toList()..sort();
      File('${root(rels.first)}.json').writeAsStringSync('{"schema": "pkarktools-snapshot", roto');
      File(root(rels.last.replaceFirst('.sav', ' (1).sav'))).writeAsBytesSync(File(root(rels.last)).readAsBytesSync());
      File(root('copiados/Platino de DAWN con un nombre de archivo bastante largo.sav'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(SyntheticSaves.gen4(trainer: const SynthTrainer(name: 'DAWN')));
      repo = device('B');
      await repo.reindex();
    });
    return repo;
  }

  Future<void> pump(WidgetTester tester, ArcaRepository repo, {String at = '/ajustes', Size size = const Size(1280, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        arcaRepositoryProvider.overrideWithValue(repo),
        initialArcaSetupProvider.overrideWithValue(SetupReady(ArcaLocation(LocationKind.path, value: arca.path, label: arca.path))),
        folderAccessProvider.overrideWithValue(FakeFolderAccess(arca, arca)),
      ],
      child: PKArkToolsApp(initialLocation: at),
    ));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
    await settle(tester);
  }

  Finder summary() => find.byKey(const ValueKey('arca-problems-summary'));

  /// Centra [f] en su lista (que no quede bajo la barra de navegación) y lo pulsa.
  Future<void> tapCentered(WidgetTester tester, Finder f) async {
    await Scrollable.ensureVisible(tester.element(f.first), alignment: 0.5);
    await tester.pump();
    await tester.tap(f.first);
    await settle(tester);
  }

  Future<void> expand(WidgetTester tester) async {
    await tapCentered(tester, summary());
  }

  for (final size in const [Size(360, 800), Size(430, 932), Size(1280, 900)]) {
    testWidgets('plegado por defecto, se despliega agrupado y sin desbordes (${size.width.toInt()}×${size.height.toInt()})',
        (tester) async {
      final repo = await withProblems(tester);
      await pump(tester, repo, size: size);
      expect(find.text('3 problemas en el Arca'), findsOneWidget);
      // En el teléfono el desglose no cabe: solo el título completo y el icono.
      expect(find.text('1 error · 2 avisos'), size.width > 600 ? findsOneWidget : findsNothing);
      expect(find.textContaining('.json dañado'), findsNothing, reason: 'plegado');
      expect(find.byKey(const ValueKey('arca-problems-fix-all')), findsNothing);

      await expand(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('.json dañado (1)'), findsOneWidget);
      expect(find.text('Copia de conflicto de la nube (1)'), findsOneWidget);
      expect(find.text('Save suelto (1)'), findsOneWidget);
      expect(find.text('No se puede leer. Arreglar lo regenera releyendo su save.'), findsOneWidget);
      expect(find.textContaining('PKArkTools/copiados/Platino de DAWN'), findsOneWidget);
      // Errores primero.
      expect(tester.getTopLeft(find.text('.json dañado (1)')).dy,
          lessThan(tester.getTopLeft(find.text('Save suelto (1)')).dy));
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await settle(tester);
      expect(tester.takeException(), isNull);

      // Se vuelve a plegar.
      await expand(tester);
      expect(find.text('Save suelto (1)'), findsNothing);
    });
  }

  testWidgets('ignorar: oculta, se guarda en este dispositivo y se puede deshacer', (tester) async {
    final repo = await withProblems(tester);
    await pump(tester, repo, size: const Size(430, 932));
    await expand(tester);
    final item = find.ancestor(of: find.text('Platino de DAWN con un nombre de archivo bastante largo.sav'), matching: find.byType(Row));
    await tapCentered(tester, find.descendant(of: item.first, matching: find.byTooltip('Ignorar')));
    expect(find.text('2 problemas en el Arca'), findsOneWidget);
    expect(find.text('Save suelto (1)'), findsNothing);
    expect(find.text('Mostrar ignorados (1)'), findsOneWidget);
    final keys = await tester.runAsync(() => ArcaProblemIgnores.load(repo));
    expect(keys, hasLength(1));
    expect(keys!.single, startsWith('copiados/Platino de DAWN'));
    // Nada en la carpeta del Arca.
    expect(arca.listSync(recursive: true).where((e) => e.path.contains('ignor')), isEmpty);

    // Ignorar un grupo entero.
    await tapCentered(tester, find.text('Ignorar (1)'));
    expect(find.text('1 problema en el Arca'), findsOneWidget);
    expect(find.text('Mostrar ignorados (2)'), findsOneWidget);

    // Revisarlos y dejar de ignorar uno.
    await tapCentered(tester, find.text('Mostrar ignorados (2)'));
    expect(find.textContaining('No vuelven a avisar'), findsOneWidget);
    await tapCentered(tester, find.byTooltip('Dejar de ignorar'));
    expect(find.text('2 problemas en el Arca'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignorado deja de valer si el archivo cambia', (tester) async {
    final repo = await withProblems(tester);
    final loose = root('copiados/Platino de DAWN con un nombre de archivo bastante largo.sav');
    await tester.runAsync(() async {
      final p = arcaProblemsOf(repo.lastReport).firstWhere((p) => p.kind == ArcaProblemKind.looseSave);
      await ArcaProblemIgnores.save(repo, {p.ignoreKey});
    });
    await pump(tester, repo);
    expect(find.text('2 problemas en el Arca'), findsOneWidget);
    await tester.runAsync(() async {
      File(loose).writeAsBytesSync(SyntheticSaves.gen4(trainer: const SynthTrainer(name: 'DAWN', hours: 9)));
      File(loose).setLastModifiedSync(DateTime(2026, 3, 1));
      await repo.reindex();
    });
    await settle(tester);
    expect(find.text('3 problemas en el Arca'), findsOneWidget);
  });

  testWidgets('Arreglar todo: confirmación propia, progreso y resultado; nada se borra', (tester) async {
    final repo = await withProblems(tester);
    await pump(tester, repo, size: const Size(360, 800));
    await expand(tester);
    await tapCentered(tester, find.byKey(const ValueKey('arca-problems-fix-all')));
    expect(find.byKey(const ValueKey('arca-problems-confirm')), findsOneWidget);
    expect(find.text('¿Arreglar 3 problemas?'), findsOneWidget);
    expect(find.textContaining('_cuarentena'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Cancelar no toca nada.
    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    expect(find.text('3 problemas en el Arca'), findsOneWidget);

    await tapCentered(tester, find.byKey(const ValueKey('arca-problems-fix-all')));
    await tester.tap(find.byKey(const ValueKey('arca-problems-confirm-fix')));
    for (var i = 0; i < 8 && find.textContaining('3 arreglados').evaluate().isEmpty; i++) {
      await settle(tester, until: find.textContaining('3 arreglados'));
    }
    expect(find.textContaining('3 arreglados'), findsWidgets);
    await settle(tester);
    expect(find.byKey(const ValueKey('arca-problems-progress')), findsNothing);
    expect(find.text('Arca sin problemas'), findsOneWidget);
    final saves = (await tester.runAsync(repo.allSlots))!;
    expect(saves.map((s) => s.$2.length).fold(0, (a, b) => a + b), 3, reason: '2 de MAY + DAWN adoptado');
    // El .json dañado se apartó (no se borró).
    final q = Directory(p.join(arca.path, 'PKArkTools', ArcaLayout.quarantineDir));
    expect(q.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.sav.json')), hasLength(1));
    expect(
        utf8.decode(q.listSync(recursive: true).whereType<File>().firstWhere((f) => f.path.endsWith('.nota.txt')).readAsBytesSync()),
        contains('Nothing was deleted'));
  });

  testWidgets('sin problemas: solo un check discreto', (tester) async {
    late ArcaRepository repo;
    await tester.runAsync(() async {
      repo = device('A');
      await repo.importBytes(SyntheticSaves.gen3(trainer: const SynthTrainer(name: 'MAY')),
          fileName: 'E.sav', origin: ImportOrigin.file);
      await repo.reindex();
    });
    await pump(tester, repo);
    expect(find.text('Arca sin problemas'), findsOneWidget);
    expect(summary(), findsNothing);
    await pump(tester, repo, at: '/arca');
    expect(find.byKey(const ValueKey('arca-problems-notice')), findsNothing);
  });

  for (final size in const [Size(360, 800), Size(1280, 900)]) {
    testWidgets('pestaña Arca: una línea discreta que lleva a Ajustes (${size.width.toInt()})', (tester) async {
      final repo = await withProblems(tester);
      await pump(tester, repo, at: '/arca', size: size);
      final notice = find.byKey(const ValueKey('arca-problems-notice'));
      expect(notice, findsOneWidget);
      expect(tester.getSize(notice).height, lessThan(40));
      expect(find.text('3 problemas en el Arca'), findsOneWidget);
      expect(find.textContaining('.json dañado'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(notice);
      await settle(tester);
      expect(summary(), findsOneWidget);
    });
  }
}
