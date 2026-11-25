import 'dart:async';
import 'dart:io' as io;

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
import 'package:pkarktools/data/arca_session.dart';
import 'package:pkarktools/data/db/arca_database.dart';
import 'package:pkarktools/data/folder/arca_folder.dart';
import 'package:pkarktools/data/folder/memory_folder_fs.dart';
import 'package:pkarktools/data/sprites/sprite_cache.dart';
import 'package:pkarktools/l10n/app_localizations.dart';
import 'package:pkarktools/providers.dart';
import 'package:pkarktools/ui/editor/pokemon_editor.dart';

import '../test/dex_demo.dart';

/// Recorrido del vídeo de demostración, en tiempo real y con datos sintéticos.
/// No captura nada: el vídeo lo graba `adb shell screenrecord` mientras corre
/// (ver tool/make_demo_video.sh, que lo lanza y monta el montaje final):
///
///   flutter drive --profile -d emulator-5554 --driver test_driver/integration_test.dart \
///     --target integration_test/demo_video_test.dart --dart-define=DEMO_LANG=es
///
/// Cada escena imprime «DEMO_SCENE nombre» al empezar; «DEMO_READY» marca que
/// los iconos ya están en caché y el recorrido empieza en unos segundos.
const _lang = String.fromEnvironment('DEMO_LANG', defaultValue: 'en');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('recorrido del vídeo de demostración', skip: !io.Platform.isAndroid && !io.Platform.isIOS, (tester) async {
    // Fotogramas a su ritmo, como la app de verdad (no los que bombea la prueba).
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    final locale = _lang == 'es' ? const Locale('es', 'ES') : const Locale('en', 'US');
    tester.platformDispatcher.localesTestValue = [locale];
    tester.platformDispatcher.localeTestValue = locale;
    final l10n = lookupAppLocalizations(locale);
    final es = _lang == 'es';

    // Iconos precargados: en la grabación no se ve ninguno cargando.
    await tester.runAsync(() => SpriteCache.instance.downloadAll());

    final db = ArcaDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final repo = ArcaRepository(db, ArcaFolder(MemoryFolderFs(label: 'PKArkTools')));
    final ids = <String, int>{};
    // Dex sintética (Pokédex medio llenas, Charizard con factor Gigamax).
    final dex = demoDex();
    final demo = SyntheticSaves.demoSet();
    // Espada con un Pokémon «sospechoso» para los avisos de legalidad.
    final sv = SaveEditor.open(demo['Espada_main']!);
    final odd = sv.get(const SlotRef.party(0))!
      ..setEvs(const [252, 252, 252, 0, 0, 0])
      ..ball = 30
      ..setRelearnMove(0, 14)
      ..refreshPartyStats();
    sv.set(const SlotRef.party(0), odd);
    final saves = {
      ...demo,
      'Espada_main': sv.build(),
      'Oro.sav': SyntheticSaves.gen2(
          trainer: const SynthTrainer(name: 'ETHAN', tid: 4242), party: const [SynthMon(155, level: 30), SynthMon(25, level: 22)]),
      'Rubi.sav': SyntheticSaves.gen3(
          game: GameVersion.rubySapphire,
          trainer: const SynthTrainer(name: 'BRENDAN', tid: 2024, sid: 77),
          party: const [SynthMon(258, level: 34), SynthMon(282, level: 30)]),
    };
    for (final e in saves.entries) {
      final r = await tester.runAsync(() => repo.importBytes(e.value, fileName: e.key, origin: ImportOrigin.file));
      if (r is ImportAdded) ids[e.key] = r.slotId;
    }

    Future<void> hold(int ms) async {
      await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
      await tester.pump();
    }

    void scene(String name) => debugPrint('DEMO_SCENE $name');

    Future<void> open(String location, {ArcaSetup? setup}) async {
      await tester.pumpWidget(const ColoredBox(color: Color(0xFF0E1116)));
      await hold(50);
      await tester.pumpWidget(_Touches(
        child: ProviderScope(
          key: UniqueKey(),
          overrides: [
            arcaRepositoryProvider.overrideWithValue(repo),
            globalDexProvider.overrideWith((ref) async => dex),
            if (setup != null) initialArcaSetupProvider.overrideWithValue(setup),
          ],
          child: PKArkToolsApp(initialLocation: location),
        ),
      ));
      await hold(900);
    }

    ScrollPosition position() {
      final editor = find.byType(PokemonEditorScreen);
      final f = editor.evaluate().isNotEmpty
          ? find.descendant(of: editor, matching: find.byType(Scrollable)).first
          : find.byType(Scrollable).first;
      return tester.state<ScrollableState>(f).position;
    }

    /// Desplazamiento suave hasta que [f] queda a la altura [alignment].
    Future<void> glide(Finder f, {double alignment = 0.15, int ms = 700}) async {
      var guard = 0;
      while (f.evaluate().isEmpty && guard++ < 30) {
        final p = position();
        final to = (p.pixels + 600).clamp(p.minScrollExtent, p.maxScrollExtent);
        await p.animateTo(to, duration: const Duration(milliseconds: 220), curve: Curves.linear);
        await tester.pump();
      }
      final ctx = tester.element(f.first);
      unawaited(Scrollable.ensureVisible(ctx,
          alignment: alignment, duration: Duration(milliseconds: ms), curve: Curves.easeInOutCubic));
      await hold(ms + 120);
    }

    Future<void> toTop({int ms = 600}) async {
      unawaited(position().animateTo(0, duration: Duration(milliseconds: ms), curve: Curves.easeInOutCubic));
      await hold(ms + 100);
    }

    /// Escribe como si se tecleara (la prueba en vivo no registra testTextInput).
    Future<void> typeInto(Finder field, String text, {int step = 1, int ms = 90}) async {
      final st = tester.state<EditableTextState>(find.descendant(of: field, matching: find.byType(EditableText)).first);
      for (var i = step; i < text.length + step; i += step) {
        final t = text.substring(0, i.clamp(0, text.length));
        st.updateEditingValue(TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length)));
        await hold(ms);
      }
    }

    Future<void> tap(Finder f, {int after = 700}) async {
      // Si está fuera de la vista (p. ej. al fondo de la hoja de filtros), se
      // desplaza hasta él con animación antes de pulsar.
      final hit = tester.hitTestOnBinding(tester.getCenter(f.first, warnIfMissed: false));
      if (!hit.path.any((e) => e.target == tester.renderObject(f.first))) {
        unawaited(Scrollable.ensureVisible(tester.element(f.first),
            alignment: 0.5, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic));
        await hold(500);
      }
      await tester.tap(f.first);
      await hold(after);
    }

    // Pantalla en negro mientras arranca la grabación.
    await tester.pumpWidget(const ColoredBox(color: Color(0xFF0E1116)));
    await hold(200);
    debugPrint('DEMO_READY');
    await hold(4000);

    // 1. Bienvenida con el logo.
    scene('welcome');
    await open('/bienvenida', setup: const SetupNeeded());
    await hold(1800);

    // 2. Arca con colores por versión.
    scene('arca');
    await open('/arca');
    await hold(1200);
    final grid = find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first;
    final gridPos = tester.state<ScrollableState>(grid).position;
    unawaited(gridPos.animateTo(gridPos.maxScrollExtent * 0.6,
        duration: const Duration(milliseconds: 1600), curve: Curves.easeInOutCubic));
    await hold(1900);
    unawaited(gridPos.animateTo(0, duration: const Duration(milliseconds: 900), curve: Curves.easeInOutCubic));
    await hold(1100);

    // 3. Filtros.
    scene('filters');
    await tap(find.byKey(const Key('arca-filters-button')), after: 900);
    await tap(find.byKey(const Key('platform-nintendoSwitch')), after: 600);
    await tap(find.byKey(const Key('sort-playTime')), after: 700);
    await tap(find.byKey(const Key('panel-show')), after: 1500);
    await tap(find.byKey(const Key('arca-filters-clear')), after: 900);

    // 4. Una partida: equipo y cajas con iconos (Espada).
    scene('save');
    final scarletCard = find.text('Gloria');
    if (scarletCard.evaluate().isEmpty) {
      await tester.scrollUntilVisible(scarletCard, 250, scrollable: grid, maxScrolls: 40);
    }
    await tap(scarletCard, after: 1400);
    // Versión actual (el archivo principal) y el historial plegado debajo.
    await glide(find.byKey(const ValueKey('history-fold')), alignment: 0.35, ms: 600);
    await tap(find.byKey(const ValueKey('history-fold')), after: 1100);
    await glide(find.text(l10n.boxes), alignment: 0.1, ms: 1100);
    await hold(900);
    await toTop(ms: 700);

    // 5. Editor: nivel, variocolor y movimientos.
    scene('editor');
    final mon = find.bySemanticsLabel(RegExp('Inteleon'));
    await glide(mon, alignment: 0.4, ms: 500);
    await tap(mon, after: 1500);
    final species = speciesNameFor(818, es);
    expect(find.text(species), findsWidgets);
    // Variocolor (estrella).
    await glide(find.text(l10n.shinyStar), alignment: 0.35, ms: 900);
    await tap(find.text(l10n.shinyStar), after: 500);
    await toTop(ms: 600);
    await hold(900);
    // Nivel: arrastra el control deslizante hasta 100.
    await glide(find.text(l10n.levelLabel), alignment: 0.3, ms: 900);
    final slider = find.byType(Slider).first;
    final r = tester.getRect(slider);
    final g = await tester.startGesture(Offset(r.left + r.width * 0.73, r.center.dy));
    for (var i = 1; i <= 16; i++) {
      await g.moveTo(Offset(r.left + r.width * (0.73 + 0.27 * i / 16) + 4, r.center.dy));
      await hold(28);
    }
    await g.up();
    await hold(700);
    // Movimiento 4: busca y elige.
    final moveName = GameStrings.move(745, es ? DataLanguage.es : DataLanguage.en); // Disparo Certero / Snipe Shot
    final move4 = find.byKey(ValueKey('move3-818'));
    await glide(move4, alignment: 0.35, ms: 900);
    await tap(find.descendant(of: move4, matching: find.byType(TextField)), after: 400);
    final field = find.descendant(of: move4, matching: find.byType(TextField));
    await typeInto(field, moveName.substring(0, 5), ms: 140);
    await hold(500);
    await tap(find.text(moveName).last, after: 900);

    // 6. Origen y cintas.
    scene('origin');
    await glide(find.text(l10n.sectionOrigin).last, alignment: 0.05, ms: 1000);
    await hold(1300);
    await glide(find.text(l10n.ribbonsGiveAll), alignment: 0.1, ms: 900);
    await tap(find.text(l10n.ribbonsGiveAll), after: 1600);

    // 7. Avisos de legalidad y corrección.
    scene('legality');
    final fixAll = find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith(l10n.legalityFixAll(0).split('(').first));
    await toTop(ms: 1000);
    await glide(fixAll, alignment: 0.2, ms: 700);
    await hold(1500);
    if (fixAll.evaluate().isNotEmpty) await tap(fixAll, after: 1800);

    // 8. Aplicar, guardar en el Arca y comparar copias.
    scene('save_arca');
    await tap(find.text(l10n.applyChanges), after: 1200);
    await toTop(ms: 500);
    await glide(find.text(l10n.saveToArca), alignment: 0.3, ms: 500);
    await tap(find.text(l10n.saveToArca), after: 900);
    final note = find.byType(TextField).last;
    await tap(note, after: 300);
    await typeInto(note, es ? 'Inteleon variocolor, nivel 100' : 'Shiny Inteleon, level 100', step: 2, ms: 45);
    await hold(500);
    await tap(find.text(l10n.saveToArca).last, after: 1800);
    scene('compare');
    await toTop(ms: 500);
    if (find.text(l10n.compareAction).evaluate().isEmpty) {
      await glide(find.byKey(const ValueKey('history-fold')), alignment: 0.3, ms: 500);
      await tap(find.byKey(const ValueKey('history-fold')), after: 700);
    }
    await glide(find.text(l10n.compareAction), alignment: 0.4, ms: 900);
    await tap(find.text(l10n.compareAction), after: 2200);
    await hold(2200);

    // 9. La Dex: todas las especies de todas las partidas.
    await open('/arca');
    scene('dex');
    await tap(find.text(l10n.navDex).last, after: 1600);
    final dexGrid = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    unawaited(dexGrid.animateTo(dexGrid.pixels + 900, duration: const Duration(milliseconds: 1300), curve: Curves.easeInOutCubic));
    await hold(1500);
    unawaited(dexGrid.animateTo(0, duration: const Duration(milliseconds: 700), curve: Curves.easeInOutCubic));
    await hold(900);

    // 10. Ficha de Charizard: formas especiales, Gigamax desbloqueada.
    scene('dex_species');
    await tap(find.byKey(const ValueKey('dex-6')), after: 1500);
    await glide(find.byKey(const ValueKey('dex-special-gmax:6:*')), alignment: 0.3, ms: 1200);
    await hold(2200);

    scene('end');
    await tester.pumpWidget(const ColoredBox(color: Color(0xFF0E1116)));
    await hold(1500);
    debugPrint('DEMO_DONE');
    await db.close();
  });
}

String speciesNameFor(int species, bool es) => GameStrings.species(species, es ? DataLanguage.es : DataLanguage.en);

/// Círculos donde «toca» la prueba, como «Mostrar toques» de Android.
class _Touches extends StatefulWidget {
  const _Touches({required this.child});
  final Widget child;
  @override
  State<_Touches> createState() => _TouchesState();
}

class _TouchesState extends State<_Touches> {
  final _dots = <int, (Offset, bool)>{};

  // Visible un momento aunque la pulsación dure un solo fotograma; luego se apaga.
  void _release(int id, Offset at) {
    Future<void>.delayed(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _dots[id] = (at, false));
    });
    Future<void>.delayed(const Duration(milliseconds: 520), () {
      if (mounted) setState(() => _dots.remove(id));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => setState(() => _dots[e.pointer] = (e.position, true)),
      onPointerMove: (e) => setState(() => _dots[e.pointer] = (e.position, true)),
      onPointerUp: (e) => _release(e.pointer, e.position),
      onPointerCancel: (e) => _release(e.pointer, e.position),
      child: Stack(textDirection: TextDirection.ltr, children: [
        widget.child,
        for (final MapEntry(key: id, value: d) in _dots.entries)
          Positioned(
            key: ValueKey(id),
            left: d.$1.dx - 22,
            top: d.$1.dy - 22,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: d.$2 ? 1 : 0,
                duration: const Duration(milliseconds: 360),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0x55FFFFFF),
                    border: Border.all(color: const Color(0xCCFFFFFF), width: 2),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
