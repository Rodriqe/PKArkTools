import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';
import 'package:pkarktools/data/sprites/sprite_cache.dart';
import 'package:pkarktools/providers.dart';
import 'package:pkarktools/ui/events/event_explorer.dart';
import 'package:pkarktools/ui/tools/share_card.dart';

/// Capturas de las novedades de la 2.0 en un teléfono (emulador -no-window o
/// simulador headless; nunca abre la app de escritorio):
///
///   flutter drive -d emulator-5554 --driver test_driver/screenshot_driver.dart \
///     --target integration_test/release2_screenshots_test.dart \
///     [--dart-define=SHOTS=android/v2.0] [--dart-define=SHOTS_LANG=es]
///
/// SHOTS_OUT (entorno del driver) cambia la carpeta de destino.
const _prefix = String.fromEnvironment('SHOTS', defaultValue: 'android/v2.0');
const _lang = String.fromEnvironment('SHOTS_LANG', defaultValue: 'en');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capturas de la 2.0 en el teléfono', skip: io.Platform.isMacOS || io.Platform.isWindows || io.Platform.isLinux,
      (tester) async {
    final es = _lang == 'es';
    final locale = es ? const Locale('es', 'ES') : const Locale('en', 'US');
    tester.platformDispatcher.localesTestValue = [locale];
    tester.platformDispatcher.localeTestValue = locale;
    await tester.runAsync(() => SpriteCache.instance.downloadAll());

    final db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final repo = ArcaRepository(db, ArcaFolder(MemoryFolderFs(label: 'PKArkTools')), inboxSettle: Duration.zero);
    final boxNames = [for (var i = 1; i <= 32; i++) es ? 'Caja $i' : 'Box $i'];
    Future<int> import(Uint8List bytes, String name) async {
      final r = await tester.runAsync(() => repo.importBytes(bytes, fileName: name, origin: ImportOrigin.demo));
      return (r! as ImportAdded).slotId;
    }

    final sv = await import(
        SyntheticSaves.scarletViolet(
          trainer: const SynthTrainer(name: 'Juliana', tid: 12345, sid: 2024, gender: 1, versionId: 50),
          party: const [SynthMon(908, level: 52), SynthMon(959, level: 50), SynthMon(445, level: 55), SynthMon(25, level: 40, shiny: true)],
          boxNames: boxNames,
        ),
        'sv/main');
    final us = await import(
        SyntheticSaves.ctr(
          layout: CtrLayout.usum,
          trainer: const SynthTrainer(name: 'Elio', tid: 54321, sid: 777, versionId: 32),
          party: const [SynthMon(724, level: 45), SynthMon(26, level: 40)],
          boxes: {0: const [SynthMon(722, level: 10), SynthMon(133, level: 21)]},
        ),
        'usum/main');
    final sw = await import(
        SyntheticSaves.swordShield(
          trainer: const SynthTrainer(name: 'Victor', tid: 11223, sid: 4455, versionId: 44),
          party: const [SynthMon(813, level: 20)],
          boxNames: boxNames,
        ),
        'swsh/main');

    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> until(Finder f, [int tries = 60]) async {
      for (var i = 0; i < tries && f.evaluate().isEmpty; i++) {
        await settle(4);
      }
    }

    if (io.Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    Future<void> shot(String name) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await settle(8);
      await binding.takeScreenshot('${_prefix}_$name');
    }

    Future<void> open(String at) async {
      await tester.pumpWidget(const SizedBox());
      await settle(3);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
        child: PKArkToolsApp(initialLocation: at),
      ));
      await settle(25);
    }

    BuildContext ctx() => tester.element(find.byType(Scaffold).last);
    Future<void> center(Finder f) async {
      await tester.runAsync(() => Scrollable.ensureVisible(tester.element(f.first), alignment: 0.5));
      await settle(6);
    }

    await open('/dex/eventos');
    await shot('01_events_explorer');

    await open('/arca/save/$sw');
    unawaited(EventPicker.show(ctx(), GameVersion.swordShield, saveLanguage: 2));
    await settle();
    await tester.enterText(find.byKey(const ValueKey('events-search')), 'zeraora');
    await settle(10);
    final z = EventDb.creatableIn(GameVersion.swordShield).firstWhere((g) => g.species == 807);
    await tester.tap(find.byKey(ValueKey('event-${z.id}')));
    await settle();
    await shot('02_create_from_event');

    await open('/arca/save/$sw');
    final ld = find.byKey(const Key('livingDexButton'));
    await until(ld);
    await center(ld);
    await shot('03_living_dex_button');
    await tester.tap(ld);
    await settle(10);
    await shot('04_living_dex_normal_shiny');
    await tester.tap(find.byKey(const Key('livingDexNormal')));
    await settle(10);
    await shot('05_living_dex_overwrite');
    await tester.tap(find.byType(FilledButton).last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await until(find.byKey(const Key('livingDexSummary')), 150);
    await shot('06_living_dex_summary');

    await open('/arca/save/$us');
    await until(find.byKey(const ValueKey('tool-transfer')));
    await center(find.byKey(const ValueKey('tool-transfer')));
    await tester.tap(find.byKey(const ValueKey('tool-transfer')));
    await settle(15);
    final eevee = find.byTooltip(RegExp('Eevee'));
    await until(eevee);
    if (eevee.evaluate().isNotEmpty) await tester.tap(eevee.first);
    await settle(6);
    final dest = find.textContaining(es ? 'Escarlata' : 'Scarlet');
    if (dest.evaluate().isNotEmpty) {
      await center(dest);
      await tester.tap(dest.first);
    }
    await settle(20);
    final notice = find.byIcon(Icons.warning_amber_rounded);
    if (notice.evaluate().isNotEmpty) await center(notice);
    await settle(6);
    await shot('07_transfer');

    await open('/competitivo/formato');
    await shot('08_official_format');

    await open('/arca/save/$sv');
    final latest = (await tester.runAsync(() => repo.watchSnapshots(sv).first))!.first;
    final ed = SaveEditor.open((await tester.runAsync(() => repo.snapshotBytes(latest)))!);
    final lead = ed.party.first.clone()
      ..setIvs([31, 31, 28, 30, 31, 31])
      ..setEvs([4, 252, 0, 0, 0, 252]);
    final context = GameDataTable.forGame(GameVersion.scarletViolet).context;
    for (final (i, m) in const [(0, 870), (1, 583), (2, 282), (3, 369)]) {
      lead.setMove(i, m, context: context);
    }
    lead.refreshPartyStats();
    // 9. Calculadora de estadísticas de Champions (pestaña Competitivo).
    await open('/competitivo/estadisticas');
    await shot('09_stat_calculator');
    await open('/arca/save/$sv');
    await settle(10);

    final sd = find.byKey(const ValueKey('tool-showdown-export'));
    await until(sd);
    await center(sd);
    await tester.tap(sd);
    await settle(10);
    await shot('10_showdown');
    await open('/arca/save/$sv');

    unawaited(showShareCard(ctx(), lead, GameVersion.scarletViolet));
    await settle(20);
    await shot('11_share_card');

    await tester.pumpWidget(const SizedBox());
    await settle(3);
    await db.close();
  });
}
