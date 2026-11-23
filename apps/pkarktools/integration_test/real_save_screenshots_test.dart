import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pkcore/pkcore.dart';
import 'package:pkarktools/app.dart';
import 'package:pkarktools/data/arca_repository.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/providers.dart';

/// Importa un save real al Arca en la app de macOS y captura detalle, cajas,
/// Pokédex y editor. La app está en sandbox y no puede leer `.ref/`; el save
/// llega de una de dos formas (sin ninguna, la prueba se salta):
///
/// * comprimido (gzip + base64) por `--dart-define-from-file`, si cabe en la
///   línea de comandos (< 1 MB; sirve para los saves de NDS):
///
/// ```bash
/// python3 -c "import base64,gzip,json,sys; print(json.dumps({'REAL_SAVE_NAME': sys.argv[2], \
///   'REAL_SAVE_GZ_B64': base64.b64encode(gzip.compress(open(sys.argv[1],'rb').read())).decode()}))" \
///   "../../.ref/real-saves/Pokemon Soul Silver.sav" ss > ../../.scratch/real_save.json
/// flutter drive -d macos --driver test_driver/real_save_driver.dart \
///   --target integration_test/real_save_screenshots_test.dart --dart-define-from-file=../../.scratch/real_save.json
/// ```
///
/// * por HTTP local, para saves grandes (Switch, cifrados, no comprimen): la
///   prueba escucha en 127.0.0.1:[_port] (entitlement `network.server` de
///   debug) y el driver le envía el archivo indicado en `REAL_SAVE_PATH`:
///
/// ```bash
/// REAL_SAVE_PATH=../../.ref/real-saves/sword/main flutter drive -d macos \
///   --driver test_driver/real_save_driver.dart --target integration_test/real_save_screenshots_test.dart \
///   --dart-define=REAL_SAVE_NAME=sw --dart-define=REAL_SAVE_HTTP=true
/// ```
///
/// Las capturas pueden mostrar datos personales: el driver las guarda en
/// `.scratch/screenshots/`, que no se versiona.
const _b64 = String.fromEnvironment('REAL_SAVE_GZ_B64');
const _name = String.fromEnvironment('REAL_SAVE_NAME', defaultValue: 'real');
const _http = bool.fromEnvironment('REAL_SAVE_HTTP');
const _port = 47321;

/// Espera a que el driver envíe el save por POST a 127.0.0.1:[_port].
Future<Uint8List> _receiveSave() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
  try {
    final request = await server.first.timeout(const Duration(minutes: 3));
    final builder = BytesBuilder(copy: false);
    await request.forEach(builder.add);
    request.response.statusCode = 200;
    await request.response.close();
    return builder.takeBytes();
  } finally {
    await server.close(force: true);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final shots = <String, String>{};

  testWidgets('capturas con un save real', skip: _b64.isEmpty && !_http, (tester) async {
    final bytes = _http
        ? await tester.runAsync(_receiveSave) ?? Uint8List(0)
        : Uint8List.fromList(gzip.decode(base64Decode(_b64)));
    // Carpeta del Arca en memoria: las capturas no escriben en disco.
    final tmp = MemoryFolderFs(label: 'PKArkTools');
    final db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final repo = ArcaRepository(db, ArcaFolder(tmp));
    await repo.importBytes(bytes, fileName: 'real.sav', origin: ImportOrigin.file, now: DateTime(2026, 11, 22, 12));
    final id = (await repo.watchArca().first).single.slot.id;
    // El Arca guarda los bytes exactos del archivo importado.
    expect(await repo.snapshotBytes((await repo.watchSnapshots(id).first).first), bytes);
    final editor = SaveEditor.open(Uint8List.fromList(bytes));
    final lead = GameStrings.species(editor.party.first.species);

    final boundary = GlobalKey();
    Future<void> settle([int frames = 25]) async {
      for (var i = 0; i < frames; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await tester.pump();
      }
    }

    Future<void> show(String location, Size size) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: ProviderScope(
          key: UniqueKey(),
          overrides: [arcaRepositoryProvider.overrideWithValue(repo)],
          child: PKArkToolsApp(initialLocation: location),
        ),
      ));
      await settle(8);
      final container = ProviderScope.containerOf(tester.element(find.byType(PKArkToolsApp)));
      await container.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
      await container.read(settingsProvider.notifier).setLocale(const Locale('es'));
      await settle();
    }

    Future<void> capture(String name) async {
      final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await ro.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      shots['real_${_name}_$name'] = base64Encode(png!.buffer.asUint8List());
    }

    Future<void> tapText(String text) async {
      final f = find.text(text).first;
      await tester.ensureVisible(f);
      await settle(4);
      await tester.tap(f);
      await settle(14);
    }

    await show('/arca', const Size(1440, 900));
    await capture('arca');

    await show('/arca/save/$id', const Size(1440, 1500));
    await capture('detalle');
    await tester.ensureVisible(find.text('Cajas').first);
    await settle(8);
    await capture('cajas');

    await show('/arca/save/$id', const Size(1440, 1500));
    await tapText(lead);
    await capture('editor');
    await tester.tap(find.text('Cancelar').last);
    await settle(10);

    await tapText('Pokédex');
    await capture('pokedex');
    await tapText('Inventario');
    await capture('inventario');
    await tapText('Entrenador');
    await capture('entrenador');

    await tester.pumpWidget(const SizedBox());
    await settle(4);
    await db.close();
    binding.reportData = shots;
  });
}
