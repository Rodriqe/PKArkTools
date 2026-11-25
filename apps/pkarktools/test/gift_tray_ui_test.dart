import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/file_sources.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/folder_fs.dart';
import 'package:pkarktools/editing/draft.dart';
import 'package:pkarktools/providers.dart';

import 'arca_screen_test.dart' show settle;

/// Selector de archivos falso: devuelve siempre la tarjeta indicada.
class _CardSource extends FileSources {
  _CardSource(this.name, this.bytes);
  final String name;
  final Uint8List bytes;

  @override
  Future<List<PickedSave>> pickFiles() async => [PickedSave(name: name, bytes: bytes, origin: ImportOrigin.demo)];
}

/// «Importar tarjeta» en X/Y: elegir entre la bandeja del juego o crear el Pokémon.
void main() {
  late ArcaDatabase db;
  late Directory tmp;
  late ArcaRepository repo;

  setUp(() async {
    db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    tmp = await Directory.systemTemp.createTemp('gift_tray_ui_test');
    repo = ArcaRepository(db, ArcaFolder(IoFolderFs(tmp)));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  testWidgets('la tarjeta WC6 se deja en la bandeja del juego', (tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final gift = EventDb.all.firstWhere((g) => GiftTray.accepts(g, GameVersion.xy) && g.canCreate);
    final bytes = SyntheticSaves.ctr(layout: CtrLayout.xy, trainer: const SynthTrainer(name: 'Serena', versionId: 24));
    final out = await tester.runAsync(() => repo.importBytes(bytes, fileName: 'xy.sav', origin: ImportOrigin.demo));
    final snapId = (out! as ImportAdded).snapshotId;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        arcaRepositoryProvider.overrideWithValue(repo),
        fileSourcesProvider.overrideWithValue(_CardSource('regalo.wc6', gift.rawCard!)),
      ],
      child: const PKArkToolsApp(),
    ));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
    await settle(tester);
    await tester.tap(find.text('Serena'));
    await settle(tester, until: find.text('Equipo'));

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('import-event-card')));
    await tester.pumpAndSettle();

    // Diálogo: bandeja del juego o crear el Pokémon en el hueco.
    expect(find.text('¿Cómo quieres recibir la tarjeta?'), findsOneWidget);
    expect(find.byKey(const Key('giftTrayInSlot')), findsOneWidget);
    await tester.tap(find.byKey(const Key('giftTrayInGame')));
    await tester.pumpAndSettle();
    expect(find.textContaining('en la bandeja del juego'), findsOneWidget);

    // El borrador tiene la tarjeta en el primer hueco de la bandeja y el equipo sigue vacío.
    final container = ProviderScope.containerOf(tester.element(find.text('Equipo').first));
    final editor = container.read(draftProvider(snapId)).editor!;
    expect(GiftTray.of(editor)!.cards.first, gift.rawCard);
    expect(editor.partyCount, 0);
  });
}
