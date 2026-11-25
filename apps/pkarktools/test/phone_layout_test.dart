// Teléfono: ninguna pantalla principal se desborda (RenderFlex overflow) en
// 320×568 (iPhone SE 1.ª gen.), 360×800 (Android pequeño) y 430×932 (iPhone
// Pro Max), y los textos dependen de la plataforma (atajos, onboarding).
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/file_sources.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_access.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/common/adaptive.dart';
import 'package:pkarktools/ui/detail/compare_screen.dart';
import 'package:pkarktools/ui/editor/legality_view.dart';
import 'package:pkarktools/ui/import/import_flow.dart';

import 'arca_folder_test.dart' show memoryDb;
import 'arca_screen_test.dart' show settle;
import 'folder_ui_test.dart' show FakeFolderAccess;

const phoneSizes = {
  'iPhone SE 320×568': (Size(320, 568), 1.0),
  'Android 360×800': (Size(360, 800), 1.0),
  'iPhone Pro Max 430×932': (Size(430, 932), 1.0),
  // Texto grande (ajustes de accesibilidad) en un Android estándar.
  'Android 360×800 con texto al 130 %': (Size(360, 800), 1.3),
};

/// Selector simulado con la sugerencia de una plataforma concreta.
class _PlatformAccess extends FakeFolderAccess {
  _PlatformAccess(super.picked, super.local, this.suggestion);
  @override
  final FolderSuggestion suggestion;
}

final _errors = <String>[];

/// Carga las fuentes reales de la app: los anchos de texto son los del
/// dispositivo (la fuente de prueba por defecto es más ancha y daría falsos
/// positivos de truncado).
Future<void> loadAppFonts() async {
  for (final (family, file) in [
    ('Manrope', 'assets/fonts/Manrope.ttf'),
    ('Bricolage', 'assets/fonts/BricolageGrotesque.ttf'),
    ('NotoSansSymbols', 'assets/fonts/NotoSansSymbols-Subset.ttf'),
    ('NotoSansSymbols2', 'assets/fonts/NotoSansSymbols2-Subset.ttf'),
  ]) {
    final bytes = File(file).readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late ArcaRepository repo;

  setUpAll(loadAppFonts);

  setUp(() async {
    db = memoryDb();
    tmp = await Directory.systemTemp.createTemp('phone_layout');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  void phone(WidgetTester tester, Size size, [double textScale = 1]) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    // Notch/isla y barra de gestos: el contenido tiene que respetarlas.
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    // Guarda el detalle de cada error (qué widget se desborda) para el informe.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      _errors.add(details.toString());
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
  }

  Future<void> pumpApp(WidgetTester tester, {String initial = '/arca', List<Override> overrides = const []}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [arcaRepositoryProvider.overrideWithValue(repo), ...overrides],
      child: PKArkToolsApp(initialLocation: initial),
    ));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
    await settle(tester);
  }

  Widget wrap(Widget child) => ProviderScope(
        overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  /// Falla si hubo una excepción de layout (overflow incluido) en [where].
  void noOverflow(WidgetTester tester, String where) {
    final e = tester.takeException();
    expect(e, isNull, reason: 'excepción en $where: ${_errors.isEmpty ? e : _errors.first}');
    _errors.clear();
  }

  Future<Map<String, int>> importDemo(WidgetTester tester) async {
    final ids = await tester.runAsync(() async {
      final out = <String, int>{};
      for (final e in SyntheticSaves.demoSet().entries) {
        final r = await repo.importBytes(e.value, fileName: e.key, origin: ImportOrigin.demo);
        if (r is ImportAdded) out[e.key] = r.slotId;
      }
      return out;
    });
    return ids!;
  }

  Future<void> scrollToEnd(WidgetTester tester, Finder scrollable, String where, {int steps = 14}) async {
    for (var i = 0; i < steps; i++) {
      await tester.drag(scrollable, const Offset(0, -450), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      noOverflow(tester, '$where (desplazamiento $i)');
    }
  }

  Future<void> tapSection(WidgetTester tester, String label) async {
    final f = find.text(label).last;
    await tester.ensureVisible(f);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(f);
    await settle(tester);
  }

  for (final MapEntry(key: name, value: (size, scale)) in phoneSizes.entries) {
    group(name, () {
      testWidgets('onboarding y acceso perdido', (tester) async {
        phone(tester, size, scale);
        final cloud = Directory(p.join(tmp.path, 'nube'))..createSync();
        final local = Directory(p.join(tmp.path, 'local'))..createSync();
        await pumpApp(tester, overrides: [
          initialArcaSetupProvider.overrideWithValue(const SetupNeeded(legacyCount: 3)),
          folderAccessProvider.overrideWithValue(_PlatformAccess(cloud, local, FolderSuggestion.googleDrive)),
        ]);
        expect(find.text('Elegir carpeta'), findsOneWidget);
        noOverflow(tester, 'onboarding');
        await scrollToEnd(tester, find.byType(Scrollable).first, 'onboarding', steps: 6);
        // Los botones a lo ancho tienen objetivos táctiles cómodos.
        expect(tester.getSize(find.widgetWithText(FilledButton, 'Elegir carpeta')).height, greaterThanOrEqualTo(48));
        await tester.pumpWidget(const SizedBox());

        await pumpApp(tester, overrides: [
          initialArcaSetupProvider.overrideWithValue(
              SetupAccessLost(ArcaLocation(LocationKind.path, value: '/nope', label: '/storage/emulated/0/Documents/Arca'), 'Permiso revocado')),
          folderAccessProvider.overrideWithValue(_PlatformAccess(cloud, local, FolderSuggestion.googleDrive)),
        ], initial: '/acceso');
        expect(find.textContaining('Permiso revocado'), findsOneWidget);
        noOverflow(tester, 'acceso perdido');
      });

      testWidgets('Arca, detalle (todas las secciones), cajas y editor completo', (tester) async {
        phone(tester, size, scale);
        final ids = await importDemo(tester);
        await pumpApp(tester);
        noOverflow(tester, 'Arca');
        expect(find.byType(NavigationBar), findsOneWidget);
        await scrollToEnd(tester, find.byType(CustomScrollView).first, 'Arca', steps: 8);

        // Detalle de Espada: las cinco secciones caben en una barra desplazable.
        await tester.pumpWidget(const SizedBox());
        await pumpApp(tester, initial: '/arca/save/${ids['Espada_main']}');
        await settle(tester, until: find.text('Equipo'));
        noOverflow(tester, 'detalle');
        // Las filas de chips (secciones, cajas) se centran solas en horizontal,
        // pero nunca desplazan la página.
        final page = tester.state<ScrollableState>(
            find.descendant(of: find.byType(CustomScrollView).first, matching: find.byType(Scrollable)).first);
        expect(page.position.pixels, 0, reason: 'el detalle debe abrirse arriba');
        for (final s in ['Entrenador', 'Inventario', 'Pokédex', 'Pokémon']) {
          await tapSection(tester, s);
          noOverflow(tester, 'sección $s');
          await scrollToEnd(tester, find.byType(CustomScrollView).first, 'sección $s', steps: 6);
          await tester.drag(find.byType(CustomScrollView).first, const Offset(0, 20000));
          await tester.pump(const Duration(milliseconds: 300));
        }
        // Las cajas cambian con las flechas.
        // En el centro de la vista: en el borde la barra inferior las tapa.
        await Scrollable.ensureVisible(tester.element(find.byTooltip('Caja siguiente')), alignment: 0.5);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byTooltip('Caja siguiente'));
        await settle(tester);
        noOverflow(tester, 'caja siguiente');
        await Scrollable.ensureVisible(tester.element(find.byTooltip('Caja anterior')), alignment: 0.5);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byTooltip('Caja anterior'));
        await settle(tester);

        // Editor completo con desplazamiento.
        final eternatus = find.bySemanticsLabel(RegExp('Eternatus')).evaluate().isNotEmpty
            ? find.bySemanticsLabel(RegExp('Eternatus')).first
            : find.byTooltip(RegExp('Eternatus')).first;
        await tester.ensureVisible(eternatus);
        await tester.tap(eternatus);
        await settle(tester, until: find.text('Editar Pokémon'));
        expect(find.text('Editar Pokémon'), findsOneWidget);
        // El editor tapa la barra inferior (pantalla completa) y el título no se trunca.
        expect(find.byType(NavigationBar).hitTestable(), findsNothing);
        final title = tester.renderObject<RenderParagraph>(find.text('Editar Pokémon'));
        expect(title.didExceedMaxLines, isFalse, reason: 'título truncado: ${title.size} ${title.constraints}');
        noOverflow(tester, 'editor');
        await scrollToEnd(tester, find.byType(Scrollable).first, 'editor', steps: 20);
      });

      testWidgets('Pokédex: filtros sin cortar palabras y buscador a lo ancho', (tester) async {
        phone(tester, size, scale);
        final ids = await importDemo(tester);
        await pumpApp(tester, initial: '/arca/save/${ids['Espada_main']}');
        await settle(tester, until: find.text('Equipo'));
        await tapSection(tester, 'Pokédex');
        noOverflow(tester, 'Pokédex');
        for (final label in ['Todas', 'Por capturar', 'Solo vistas', 'Capturadas']) {
          final para = tester.renderObject<RenderParagraph>(find.text(label).first);
          expect(para.size.height, lessThan(30), reason: '«$label» no debe partirse en dos líneas');
          expect(para.didExceedMaxLines, isFalse);
        }
        final field = find.byType(TextField).first;
        expect(tester.getSize(field).width, greaterThan(size.width - 40), reason: 'buscador a lo ancho');
        expect(find.text('Nombre o número'), findsOneWidget);
        expect(find.textContaining('clic derecho'), findsNothing);
      });

      testWidgets('eventos y Ajustes / Actividad', (tester) async {
        phone(tester, size, scale);
        final ids = await importDemo(tester);
        await pumpApp(tester, initial: '/arca/save/${ids['UltraSol.sav']}');
        await settle(tester, until: find.text('Equipo'));
        await tapSection(tester, 'Eventos');
        noOverflow(tester, 'eventos');
        final evSearch = find.widgetWithText(TextField, 'Nombre o número');
        expect(evSearch, findsOneWidget, reason: 'placeholder corto en Eventos');
        expect(tester.getSize(evSearch).width, greaterThan(size.width - 40), reason: 'buscador de Eventos a lo ancho');
        await scrollToEnd(tester, find.byType(CustomScrollView).first, 'eventos', steps: 4);

        await tester.pumpWidget(const SizedBox());
        await pumpApp(tester, initial: '/ajustes');
        noOverflow(tester, 'Ajustes');
        await scrollToEnd(tester, find.byType(Scrollable).first, 'Ajustes', steps: 6);
        await tester.pumpWidget(const SizedBox());
        await pumpApp(tester, initial: '/actividad');
        noOverflow(tester, 'Actividad');
      });

      testWidgets('legalidad, comparar copias e importación masiva', (tester) async {
        phone(tester, size, scale);
        final pk = SaveEditor.open(SyntheticSaves.scarletViolet(party: const [SynthMon(25, level: 30)])).get(const SlotRef.party(0))!
          ..ball = 30;
        await tester.pumpWidget(wrap(Scaffold(
            body: SingleChildScrollView(child: LegalityPanel(issues: Legality.check(pk, GameVersion.scarletViolet), onFix: (_) {})))));
        await tester.tap(find.textContaining('solo existe en Leyendas Arceus'));
        await tester.pumpAndSettle();
        noOverflow(tester, 'legalidad');

        final before = SyntheticSaves.gen3(trainer: const SynthTrainer(name: 'MAY'), party: const [SynthMon(25, level: 30), SynthMon(6, level: 40)]);
        final e = SaveEditor.open(before);
        e.set(const SlotRef.party(0), e.get(const SlotRef.party(0))!..level = 60);
        e.writeTrainer(e.readTrainer().copyWith(money: 777));
        final cmp = await tester.runAsync(() async {
          final a = await repo.importBytes(before, fileName: 'E.sav', origin: ImportOrigin.file) as ImportAdded;
          final b = await repo.saveEdited(e.build(), slotId: a.slotId, fileName: 'E.sav', note: 'x') as ImportAdded;
          return (a.snapshotId, b.snapshotId);
        });
        await tester.pumpWidget(wrap(CompareScreen(beforeId: cmp!.$1, afterId: cmp.$2, game: GameVersion.emerald)));
        await settle(tester, until: find.text('Cambió'));
        noOverflow(tester, 'comparar copias');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));

        final emerald = SyntheticSaves.gen3(party: const [SynthMon(25)]);
        PickedSave f(String n, List<int> b) => PickedSave(name: n, bytes: Uint8List.fromList(b), origin: ImportOrigin.folder);
        final scan = FolderScan(
          rootLabel: '/storage/emulated/0/Documents/Checkpoint/saves',
          found: [
            FolderCandidate(file: f('a.sav', emerald), relativePath: 'Pokémon Esmeralda/partida principal/a.sav', game: GameVersion.emerald, trainer: 'MAY'),
            FolderCandidate(file: f('b.sav', emerald), relativePath: 'copia/b.sav', game: GameVersion.emerald, trainer: 'MAY'),
          ],
          scanned: 4,
          ignored: 1,
          unrecognized: const ['una/carpeta/con/un/nombre/muy/largo/raro.bin'],
        );
        await tester.pumpWidget(wrap(Scaffold(body: BulkImportDialog(scan: scan, known: const {}))));
        await tester.pump();
        noOverflow(tester, 'importación masiva');
      });
    });
  }

  // Escritorio: el rediseño de teléfono no debe empeorar macOS/Windows/Linux.
  for (final size in const [Size(1440, 900), Size(1024, 768)]) {
    testWidgets('escritorio ${size.width.toInt()}×${size.height.toInt()}: Arca, detalle y editor sin desbordes', (tester) async {
      phone(tester, size);
      tester.view.padding = FakeViewPadding.zero;
      tester.view.viewPadding = FakeViewPadding.zero;
      final ids = await importDemo(tester);
      await pumpApp(tester);
      noOverflow(tester, 'Arca escritorio');
      expect(find.byType(NavigationBar), findsNothing, reason: 'escritorio usa la barra lateral');
      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester, initial: '/arca/save/${ids['Espada_main']}');
      await settle(tester, until: find.text('Equipo'));
      noOverflow(tester, 'detalle escritorio');
      for (final s in ['Entrenador', 'Inventario', 'Pokédex', 'Pokémon']) {
        await tapSection(tester, s);
        noOverflow(tester, 'sección $s (escritorio)');
        await scrollToEnd(tester, find.byType(CustomScrollView).first, 'sección $s (escritorio)', steps: 4);
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, 20000));
        await tester.pump(const Duration(milliseconds: 300));
      }
      final eternatus = find.bySemanticsLabel(RegExp('Eternatus')).first;
      await tester.runAsync(() => Scrollable.ensureVisible(tester.element(eternatus), alignment: 0.5));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(eternatus);
      await settle(tester, until: find.text('Editar Pokémon'));
      expect(find.text('Editar Pokémon'), findsOneWidget);
      noOverflow(tester, 'editor escritorio');
      await scrollToEnd(tester, find.byType(Scrollable).last, 'editor escritorio', steps: 10);
    });
  }

  group('textos por plataforma', () {
    test('atajos: solo en escritorio y con la tecla correcta', () {
      expect(shortcutHint(AppShortcut.undo, TargetPlatform.macOS), '⌘Z');
      expect(shortcutHint(AppShortcut.redo, TargetPlatform.macOS), '⇧⌘Z');
      expect(shortcutHint(AppShortcut.undo, TargetPlatform.windows), 'Ctrl+Z');
      expect(shortcutHint(AppShortcut.redo, TargetPlatform.linux), 'Ctrl+Y');
      expect(shortcutHint(AppShortcut.undo, TargetPlatform.android), isNull);
      expect(shortcutHint(AppShortcut.undo, TargetPlatform.iOS), isNull);
      expect(withShortcut('Deshacer', AppShortcut.undo, TargetPlatform.android), 'Deshacer');
      expect(withShortcut('Deshacer', AppShortcut.undo, TargetPlatform.windows), 'Deshacer (Ctrl+Z)');
    });

    test('sugerencia de carpeta por plataforma', () {
      expect(FolderSuggestion.forPlatform(TargetPlatform.android), FolderSuggestion.googleDrive);
      expect(FolderSuggestion.forPlatform(TargetPlatform.iOS), FolderSuggestion.iCloudDrive);
      expect(FolderSuggestion.forPlatform(TargetPlatform.macOS), FolderSuggestion.iCloudDrive);
      expect(FolderSuggestion.forPlatform(TargetPlatform.windows), FolderSuggestion.oneDrive);
      expect(FolderSuggestion.forPlatform(TargetPlatform.linux), FolderSuggestion.syncthing);
      expect(FolderSuggestion.googleDrive.providers, isNot(contains('iCloud Drive')));
      expect(FolderSuggestion.googleDrive.providers.first, 'Google Drive');
    });

    for (final (sug, expected, absent) in [
      (FolderSuggestion.googleDrive, 'Google Drive para compartir', 'iCloud'),
      (FolderSuggestion.iCloudDrive, 'iCloud Drive y tendrás el mismo Arca', 'Google Drive para compartir'),
      (FolderSuggestion.oneDrive, 'OneDrive y tendrás el mismo Arca en todos tus PC', 'Google Drive para compartir'),
      (FolderSuggestion.syncthing, 'Syncthing te da el mismo Arca', 'iCloud'),
    ]) {
      testWidgets('onboarding sugiere ${sug.name}', (tester) async {
        phone(tester, const Size(390, 844));
        final d = Directory(p.join(tmp.path, sug.name))..createSync();
        await pumpApp(tester, overrides: [
          initialArcaSetupProvider.overrideWithValue(const SetupNeeded()),
          folderAccessProvider.overrideWithValue(_PlatformAccess(d, d, sug)),
        ]);
        expect(find.textContaining(expected), findsOneWidget);
        expect(find.textContaining(absent), findsNothing);
      });
    }

    testWidgets('tooltips de deshacer: sin atajo en Android, ⌘Z en macOS', (tester) async {
      phone(tester, const Size(390, 844));
      final r = await tester.runAsync(() async => await repo.importBytes(SyntheticSaves.gen3(party: const [SynthMon(25)]), fileName: 'E.sav', origin: ImportOrigin.demo));
      final slot = (r! as ImportAdded).slotId;
      await pumpApp(tester, initial: '/arca/save/$slot');
      await settle(tester, until: find.text('Equipo'));
      expect(find.byTooltip('Deshacer'), findsOneWidget);
      expect(find.byTooltip(RegExp('⌘')), findsNothing);
      await tester.pumpWidget(const SizedBox());

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        tester.view.physicalSize = const Size(1280, 900);
        await pumpApp(tester, initial: '/arca/save/$slot');
        await settle(tester, until: find.text('Equipo'));
        expect(find.byTooltip('Deshacer (⌘Z)'), findsOneWidget);
        expect(find.byTooltip('Rehacer (⇧⌘Z)'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
