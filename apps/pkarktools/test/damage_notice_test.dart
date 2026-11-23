// Aviso de save dañado: nunca «checksum mismatch» a secas; dice qué parte
// falla, qué significa, por qué puede pasar y qué hacer, con detalle técnico
// desplegable. Bug de la Odin3: los saves reales de Sol/Luna y Ultrasol/
// Ultraluna (firmados con MemeCrypto) salían todos como dañados.
//
// Con `DAMAGE_SHOT=<carpeta>` guarda capturas PNG del aviso (para informes).
import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pkcore/pkcore.dart';
import 'package:pkcore/testing.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/theme/app_theme.dart';
import 'package:pkarktools/ui/detail/damage_notice.dart';

import 'phone_layout_test.dart' show loadAppFonts;

const _team = [SynthMon(722, level: 12), SynthMon(25, level: 30)];

Uint8List _usum() => SyntheticSaves.ctr(layout: CtrLayout.usum, party: _team, boxes: const {1: [SynthMon(734)]});

/// USUM con el checksum del bloque de cajas roto (daño leve). La firma se
/// rehace para que solo falle ese bloque.
Uint8List _usumBadBoxes() {
  final d = _usum();
  final bo = d.length - 0x200;
  final boxBlock = CtrBlocks.usum.indexWhere((b) => b.$1 == CtrLayout.usum.box);
  d[bo + 0x14 + boxBlock * 8 + 6] ^= 0x5A;
  MemeCrypto.signSave(d, GameVersion.ultraSunUltraMoon);
  return d;
}

/// Solo para capturas: iconos de Material y una fuente monoespaciada reales
/// (en los tests se dibujan como cuadros).
Future<void> _loadShotFonts() async {
  for (final (family, file) in [
    ('MaterialIcons', p.join(io.Platform.environment['FLUTTER_ROOT'] ?? '', 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')),
    ('monospace', '/System/Library/Fonts/SFNSMono.ttf'),
  ]) {
    final f = io.File(file);
    if (!f.existsSync()) continue;
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
  }
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    if (io.Platform.environment['DAMAGE_SHOT'] != null) await _loadShotFonts();
  });

  Widget wrap(Widget child, {Locale locale = const Locale('es')}) => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RepaintBoundary(
                key: const Key('shot'),
                child: Builder(
                  builder: (context) => ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Padding(padding: const EdgeInsets.all(16), child: child),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    final dir = io.Platform.environment['DAMAGE_SHOT'];
    if (dir == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      io.File(p.join(dir, '$name.png')).writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  test('Sol/Luna y Ultrasol/Ultraluna firmados como el juego: sin daño', () {
    for (final layout in [CtrLayout.sm, CtrLayout.usum]) {
      final e = SaveEditor.open(SyntheticSaves.ctr(layout: layout, party: _team));
      expect(e.damage, SaveDamage.none, reason: layout.game.name);
      expect(e.readOnly, isFalse);
    }
  });

  testWidgets('daño leve: parte afectada, explicación, reparar y detalle técnico', (tester) async {
    phone(tester);
    final e = SaveEditor.open(_usumBadBoxes());
    expect(e.damage, SaveDamage.minor);
    var repaired = false;
    await tester.pumpWidget(wrap(DamageNotice(editor: e, onRepairExport: () => repaired = true)));
    await tester.pumpAndSettle();

    expect(find.text('Se lee entero, pero una verificación no coincide'), findsOneWidget);
    expect(find.text('El bloque de cajas no coincide con su verificación.'), findsOneWidget);
    expect(find.text('La firma digital del save no corresponde a sus datos.'), findsNothing);
    expect(find.textContaining('solo lectura'), findsOneWidget);
    expect(find.textContaining('copió a medias'), findsOneWidget);
    expect(find.textContaining(RegExp('mismatch', caseSensitive: false)), findsNothing);

    // Detalle técnico plegado hasta que se toca.
    expect(find.textContaining('guardado 0x'), findsNothing);
    await tester.tap(find.text('Detalle técnico'));
    await tester.pumpAndSettle();
    expect(find.textContaining('guardado 0x'), findsOneWidget);
    await shot(tester, 'aviso_leve_es');

    await tester.tap(find.text('Reparar checksums y exportar'));
    expect(repaired, isTrue);
    expect(SaveVerifier.checksumProblems(e.buildRepaired()), isEmpty);
  });

  testWidgets('daño grave: sin botón de reparar', (tester) async {
    phone(tester);
    final d = SyntheticSaves.ctr(layout: CtrLayout.sm, party: _team);
    d[CtrLayout.sm.party + 6 * PkCrypto.size6Party] = 200; // equipo imposible
    final e = SaveEditor.open(d);
    expect(e.damage, SaveDamage.major);
    await tester.pumpWidget(wrap(DamageNotice(editor: e, onRepairExport: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Parte de este save no se puede leer'), findsOneWidget);
    expect(find.textContaining('no es seguro editarlo'), findsOneWidget);
    expect(find.text('Reparar checksums y exportar'), findsNothing);
    await tester.tap(find.text('Detalle técnico'));
    await tester.pumpAndSettle();
    await shot(tester, 'aviso_grave_es');
  });

  testWidgets('etiqueta corta del estado (inglés): nunca «mismatch»', (tester) async {
    await tester.pumpWidget(wrap(Builder(builder: (context) {
      final l10n = AppLocalizations.of(context);
      return Column(children: [for (final d in SaveDamage.values) Text(damageChipLabel(l10n, d))]);
    }), locale: const Locale('en')));
    expect(find.textContaining(RegExp('mismatch', caseSensitive: false)), findsNothing);
    expect(find.text('Verification: minor issue'), findsOneWidget);
  });
}
