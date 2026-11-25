import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:pkcore/pkcore.dart';

import '../../editing/draft.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/adaptive.dart';
import '../common/format.dart';
import '../common/species_avatar.dart';
import '../editor/legality_view.dart';
import '../editor/pokemon_editor.dart';
import '../editor/shadow_panel.dart';
import '../events/event_explorer.dart';

/// Lo que viaja al arrastrar un Pokémon.
class SlotDrag {
  const SlotDrag(this.ref, this.pk);
  final SlotRef ref;
  final Pkm pk;
}

bool get _touchFirst =>
    defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

/// Acciones sobre los huecos del borrador (abrir editor, mover, importar…).
class StorageActions {
  StorageActions(this.context, this.ref, this.snapshotId, this.game);
  final BuildContext context;
  final WidgetRef ref;
  final int snapshotId;
  final GameVersion game;

  DraftController get _draft => ref.read(draftProvider(snapshotId).notifier);
  SaveEditor get _editor => ref.read(draftProvider(snapshotId)).editor!;

  String slotLabel(SlotRef r) => r.isParty
      ? context.l10n.slotParty(r.slot + 1)
      : context.l10n.slotBox(_editor.boxName(r.box), r.slot + 1);

  void _apply(SaveEditOp op) {
    try {
      _draft.apply(op);
    } on SaveEditException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> exportPokemon(Pkm pk) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    // Colosseum/XD: el formato nativo (.ck3/.xk3) conserva el estado oscuro.
    final gc = _gcKind;
    final native = StoragePkm.extensionFor(game);
    final ext = gc?.extension ?? native ?? pk.format.extension;
    final bytes = gc != null ? GcPkm.toFile(pk, gc) : (native != null ? StoragePkm.toFile(pk, game) : pk.toFile());
    final name = '${speciesName(context, pk.species)}_${pk.level}.$ext';
    final path = await ref.read(fileSourcesProvider).exportBytes(name, bytes);
    if (path != null) messenger.showSnackBar(SnackBar(content: Text(l10n.exportDone(path))));
  }

  /// Formato de archivo suelto de GameCube del juego abierto (null si no lo es).
  GcKind? get _gcKind => switch (game) {
        GameVersion.colosseum => GcKind.ck3,
        GameVersion.xd => GcKind.xk3,
        _ => null,
      };

  /// Extensiones que acepta «Importar» en este juego.
  String get _importExts {
    final main = PkFormat.forGame(game).extension;
    final own = _gcKind?.extension ?? StoragePkm.extensionFor(game);
    return own == null ? main : '$own / .$main';
  }

  Future<void> edit(SlotRef slot, Pkm pk) async {
    final res = await PokemonEditorScreen.open(
      context,
      game: game,
      pk: pk,
      slotLabel: slotLabel(slot),
      canDelete: !_editor.isSlotLocked(slot),
      onExport: exportPokemon,
    );
    if (!context.mounted || res == null) return;
    switch (res) {
      case EditorApply(:final pk):
        _apply(SetSlotEdit(slot, pk));
      case EditorDelete():
        _apply(ClearSlotEdit(slot, species: pk.species));
      case EditorClone(:final pk):
        final target = _editor.firstEmptyBoxSlot(slot.isParty ? 0 : slot.box);
        if (target == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.boxesFull)));
          return;
        }
        _apply(SetSlotEdit(target, pk, label: 'Clonado'));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.clonedTo(slotLabel(target)))));
    }
  }

  Future<void> emptySlot(SlotRef slot) async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.add_circle_outline_rounded),
            title: Text(l10n.createPokemon),
            subtitle: Text(l10n.createPokemonDesc),
            onTap: () => Navigator.pop(ctx, 'create'),
          ),
          if (game.isColosseumOrXd)
            ListTile(
              key: const ValueKey('create-shadow'),
              leading: const Icon(Icons.heart_broken_outlined),
              title: Text(l10n.shadowCreate),
              subtitle: Text(l10n.shadowCreateDesc),
              onTap: () => Navigator.pop(ctx, 'shadow'),
            ),
          if (EventDb.creatableIn(game).isNotEmpty) ...[
            ListTile(
              key: const ValueKey('create-event'),
              leading: const Icon(Icons.card_giftcard_rounded),
              title: Text(l10n.createFromEvent),
              subtitle: Text(l10n.createFromEventDesc),
              onTap: () => Navigator.pop(ctx, 'event'),
            ),
            ListTile(
              key: const ValueKey('import-event-card'),
              leading: const Icon(Icons.redeem_rounded),
              title: Text(l10n.importEventCard),
              subtitle: Text(l10n.importEventCardDesc),
              onTap: () => Navigator.pop(ctx, 'card'),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.file_open_outlined),
            title: Text(l10n.importPokemon(_importExts)),
            subtitle: Text(l10n.importPokemonDesc),
            onTap: () => Navigator.pop(ctx, 'import'),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'create') {
      final t = _editor.readTrainer();
      final pk = PkmFactory.create(game, t, language: context.isSpanish ? 7 : 2, versionId: _editor.versionId);
      final res = await PokemonEditorScreen.open(context, game: game, pk: pk, slotLabel: slotLabel(slot), isNew: true);
      if (res is EditorApply && context.mounted) _apply(SetSlotEdit(slot, res.pk, label: 'Creado'));
    } else if (choice == 'shadow') {
      final pick = await ShadowPicker.show(context, game);
      if (pick == null || !context.mounted) return;
      final ed = _editor;
      final pk = GcShadow.create(pick.encounter, ed.readTrainer(),
          region: ed is GcEditor ? ed.region : GcRegion.ntscU,
          language: context.isSpanish ? 7 : 2,
          purified: pick.purified)
        ..dataGame = game;
      final res = await PokemonEditorScreen.open(context, game: game, pk: pk, slotLabel: slotLabel(slot), isNew: true);
      if (res is EditorApply && context.mounted) _apply(SetSlotEdit(slot, res.pk, label: 'Creado'));
    } else if (choice == 'event') {
      final lang = guessSaveLanguage(_editor, fallback: context.isSpanish ? 7 : 2);
      final pick = await EventPicker.show(context, game, saveLanguage: lang);
      if (pick == null || !context.mounted) return;
      await _createEvent(slot, pick.gift, language: pick.language, shiny: pick.shiny);
    } else if (choice == 'card') {
      await importEventCard(slot);
    } else {
      await importInto(slot);
    }
  }

  /// Crea [gift] para el entrenador de la partida y abre el editor antes de ponerlo en [slot].
  Future<void> _createEvent(SlotRef slot, EventGift gift, {required int language, bool? shiny}) async {
    final ed = _editor;
    final pk = EventFactory.create(gift, game, ed.readTrainer(), language: language, versionId: ed.versionId, shiny: shiny);
    final res = await PokemonEditorScreen.open(context, game: game, pk: pk, slotLabel: slotLabel(slot), isNew: true);
    if (res is EditorApply && context.mounted) {
      _apply(SetSlotEdit(slot, res.pk, label: 'Evento'));
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.eventCreated(pokemonName(context, gift.species, gift.form, game)))));
    }
  }

  /// Importa una tarjeta de Regalo Misterioso y la «recibe» en [slot].
  Future<void> importEventCard(SlotRef slot) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final files = await ref.read(fileSourcesProvider).pickFiles();
    if (files.isEmpty || !context.mounted) return;
    final f = files.first;
    final ext = p.extension(f.name).replaceFirst('.', '').toLowerCase();
    final gift = EventCards.identify(ext, f.bytes);
    if (gift == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.eventCardUnknown)));
      return;
    }
    if (!EventFactory.canCreateIn(gift, game)) {
      final es = context.isSpanish;
      final games = gift.games.map((g) => es ? g.nameEs : g.nameEn).join(', ');
      messenger.showSnackBar(SnackBar(content: Text(l10n.eventCardWrongGame(games.isEmpty ? 'Gen ${gift.generation}' : games))));
      return;
    }
    // X/Y, ROZA, Sol/Luna y USUL guardan las tarjetas recibidas: se ofrece dejarla en la bandeja.
    if (GiftTray.of(_editor) != null && GiftTray.accepts(gift, game)) {
      final inTray = await showDialog<bool>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(l10n.giftTrayTitle),
          children: [
            ListTile(
              key: const Key('giftTrayInGame'),
              leading: const Icon(Icons.card_giftcard_rounded),
              title: Text(l10n.giftTrayInGame),
              subtitle: Text(l10n.giftTrayInGameDesc),
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              key: const Key('giftTrayInSlot'),
              leading: const Icon(Icons.catching_pokemon_rounded),
              title: Text(l10n.giftTrayInSlot),
              subtitle: Text(l10n.giftTrayInSlotDesc),
              onTap: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      );
      if (inTray == null || !context.mounted) return;
      if (inTray) {
        try {
          _draft.apply(ReceiveGiftCardEdit(gift.rawCard!, title: gift.title));
          messenger.showSnackBar(SnackBar(content: Text(l10n.giftTrayDone(gift.title))));
        } on SaveEditException catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(e.message)));
        }
        return;
      }
    }
    final lang = guessSaveLanguage(_editor, fallback: context.isSpanish ? 7 : 2);
    await _createEvent(slot, gift, language: EventFactory.languageFor(gift, lang));
  }

  Future<void> importInto(SlotRef slot) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final lang = context.isSpanish ? SpeciesLanguage.es : SpeciesLanguage.en;
    final files = await ref.read(fileSourcesProvider).pickFiles();
    if (files.isEmpty) return;
    final f = files.first;
    final want = PkFormat.forGame(game);
    final ext = p.extension(f.name).replaceFirst('.', '').toLowerCase();
    final format = PkFormat.fromExtension(ext);
    final gcFile = GcKind.fromExtension(ext);
    final native = StoragePkm.extensionFor(game);
    final isNative = native != null && ext == native;
    if (format != want && !isNative && (gcFile == null || gcFile != _gcKind)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.importWrongFormat(ext.isEmpty ? '?' : ext, _importExts))));
      return;
    }
    final pk = gcFile != null
        ? GcPkm.fromFile(gcFile, f.bytes)
        : (isNative ? StoragePkm.fromFile(ext, f.bytes) : Pkm.fromFile(want, f.bytes));
    if (pk == null || (!want.isGameBoy && !pk.checksumValid)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.importInvalidPokemon)));
      return;
    }
    _apply(SetSlotEdit(slot, pk..dataGame = game, label: 'Importado'));
    messenger.showSnackBar(SnackBar(content: Text(l10n.importedPokemon(Species.name(pk.species, lang)))));
  }

  void move(SlotRef from, SlotRef to) {
    if (from == to) return;
    _apply(SwapSlotsEdit(from, to));
  }

  void moveToBox(SlotRef from, int box) {
    final editor = _editor;
    for (var s = 0; s < editor.boxSlotCount; s++) {
      if (editor.get(SlotRef.box(box, s)) == null) {
        move(from, SlotRef.box(box, s));
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.boxFull)));
  }
}

/// Envuelve un hueco con arrastrar (si tiene Pokémon) y soltar.
class _SlotDnD extends StatelessWidget {
  const _SlotDnD({required this.slot, required this.pk, required this.actions, required this.locked, required this.builder});
  final SlotRef slot;
  final Pkm? pk;
  final StorageActions actions;
  final bool locked;
  final Widget Function(BuildContext context, bool hovering) builder;

  @override
  Widget build(BuildContext context) {
    final target = DragTarget<SlotDrag>(
      onWillAcceptWithDetails: (d) => d.data.ref != slot && !locked,
      onAcceptWithDetails: (d) => actions.move(d.data.ref, slot),
      builder: (context, candidates, _) => builder(context, candidates.isNotEmpty),
    );
    final pk = this.pk;
    if (pk == null || locked) return target;
    final feedback = Material(
      color: Colors.transparent,
      child: Transform.scale(
        scale: 1.08,
        child: SpeciesAvatar(species: pk.species, form: pk.form, game: pk.dataGame, female: pk.gender == 1, shiny: pk.isShiny, egg: pk.isEgg, size: 64),
      ),
    );
    final data = SlotDrag(slot, pk);
    final dim = Opacity(opacity: 0.25, child: builder(context, false));
    return _touchFirst
        ? LongPressDraggable<SlotDrag>(data: data, feedback: feedback, childWhenDragging: dim, child: target)
        : Draggable<SlotDrag>(data: data, feedback: feedback, childWhenDragging: dim, child: target);
  }
}

int _warnings(Pkm pk, GameVersion game) =>
    Legality.check(pk, game).where((i) => i.severity == LegalitySeverity.warning).length;

// =================================================================== equipo

/// Equipo: tarjetas con avatar, nombre, apodo y nivel. Tocar = editar; arrastrar = mover.
/// Hueco al que saltar al abrir la partida (desde la Dex): caja (-1 = equipo) y hueco.
typedef SlotFocus = ({int box, int slot});

/// Lleva a la vista el widget de [context] tras el primer frame.
void ensureVisibleSoon(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      Scrollable.ensureVisible(context, alignment: 0.2, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  });
}

class PartyGrid extends StatefulWidget {
  const PartyGrid({super.key, required this.party, required this.actions, required this.capacity, this.focusSlot});
  final List<Pkm> party;
  final StorageActions actions;
  final int capacity;

  /// Hueco resaltado (salto desde la Dex).
  final int? focusSlot;

  @override
  State<PartyGrid> createState() => _PartyGridState();
}

class _PartyGridState extends State<PartyGrid> {
  @override
  void initState() {
    super.initState();
    if (widget.focusSlot != null) ensureVisibleSoon(context);
  }

  List<Pkm> get party => widget.party;
  StorageActions get actions => widget.actions;
  int get capacity => widget.capacity;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 760 ? 3 : (c.maxWidth >= 420 ? 2 : 1);
          const gap = 12.0;
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < party.length; i++)
                SizedBox(
                  width: w,
                  child: _SlotDnD(
                    slot: SlotRef.party(i),
                    pk: party[i],
                    actions: actions,
                    locked: false,
                    builder: (context, hover) => _PartyTile(
                      p: party[i],
                      hover: hover || widget.focusSlot == i,
                      warnings: _warnings(party[i], actions.game),
                      onTap: () => actions.edit(SlotRef.party(i), party[i]),
                    ),
                  ),
                ),
              if (party.length < capacity)
                SizedBox(
                  width: w,
                  child: _SlotDnD(
                    slot: SlotRef.party(party.length),
                    pk: null,
                    actions: actions,
                    locked: false,
                    builder: (context, hover) => _AddTile(hover: hover, onTap: () => actions.emptySlot(SlotRef.party(party.length))),
                  ),
                ),
            ],
          );
        },
      );
}

class _PartyTile extends StatelessWidget {
  const _PartyTile({required this.p, required this.hover, required this.warnings, required this.onTap});
  final Pkm p;
  final bool hover;
  final int warnings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final name = p.isEgg ? l10n.egg : pokemonName(context, p.species, p.form, p.dataGame);
    final nick = p.isNicknamed && !p.isEgg ? p.nickname : null;
    return Material(
      color: hover ? context.colors.primary.withValues(alpha: 0.12) : tokens.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: hover ? context.colors.primary : (p.isShiny ? tokens.shiny.withValues(alpha: 0.6) : tokens.hairline),
          width: hover ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              SpeciesAvatar(species: p.species, form: p.form, game: p.dataGame, female: p.gender == 1, shiny: p.isShiny, egg: p.isEgg, size: 52),
              if (warnings > 0) Positioned(left: -5, bottom: -5, child: LegalityDot(count: warnings)),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nick ?? name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  nick != null ? '$name  #${p.species.toString().padLeft(4, '0')}' : '#${p.species.toString().padLeft(4, '0')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall!.copyWith(color: tokens.muted, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ]),
            ),
            if (!p.isEgg)
              Text(l10n.level(p.level),
                  style: context.text.titleSmall!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: tokens.muted, size: 20),
          ]),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.hover, required this.onTap});
  final bool hover;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: hover ? context.colors.primary.withValues(alpha: 0.12) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: hover ? context.colors.primary : tokens.hairline, width: hover ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: 80,
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, color: tokens.muted),
              const SizedBox(width: 8),
              Text(context.l10n.addToTeam, style: context.text.labelLarge!.copyWith(color: tokens.muted)),
            ]),
          ),
        ),
      ),
    );
  }
}

// =================================================================== cajas

/// Navegador de cajas: selector horizontal + cuadrícula. Soltar en una caja
/// del selector manda el Pokémon a su primer hueco libre.
class BoxBrowser extends StatefulWidget {
  const BoxBrowser({
    super.key,
    required this.editor,
    required this.actions,
    required this.accent,
    required this.revision,
    this.focus,
  });
  final SaveEditor editor;
  final StorageActions actions;
  final Color accent;
  final int revision;

  /// Hueco resaltado al abrir (salto desde la Dex).
  final SlotFocus? focus;

  @override
  State<BoxBrowser> createState() => _BoxBrowserState();
}

class _BoxBrowserState extends State<BoxBrowser> {
  late int _index = widget.focus != null && widget.focus!.box >= 0 ? widget.focus!.box : 0;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    if (widget.focus != null && widget.focus!.box >= 0) ensureVisibleSoon(context);
  }

  void _go(int i) {
    if (i == _index || i < 0 || i >= widget.editor.boxCount) return;
    setState(() {
      _forward = i > _index;
      _index = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.editor;
    if (e.boxCount == 0) return Text(context.l10n.boxEmpty);
    if (_index >= e.boxCount) _index = 0;
    final tokens = context.tokens;
    final box = _index;
    final slots = [for (var s = 0; s < e.boxSlotCount; s++) e.get(SlotRef.box(box, s))];
    final cols = e.boxSlotCount == 25 ? 5 : 6;
    final gb = e.format.isGameBoy;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(
          tooltip: context.l10n.boxPrevious,
          onPressed: box > 0 ? () => _go(box - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: ScrollingChipRow(
            selectedIndex: box,
            children: [
              for (var i = 0; i < e.boxCount; i++)
                Builder(builder: (context) {
                  final selected = i == box;
                  var count = 0;
                  for (var s = 0; s < e.boxSlotCount; s++) {
                    if (e.get(SlotRef.box(i, s)) != null) count++;
                  }
                  final name = e.boxName(i);
                  return DragTarget<SlotDrag>(
                    onWillAcceptWithDetails: (d) => d.data.ref.box != i,
                    onAcceptWithDetails: (d) => widget.actions.moveToBox(d.data.ref, i),
                    builder: (context, cand, _) => ChoiceChip(
                      selected: selected || cand.isNotEmpty,
                      onSelected: (_) => _go(i),
                      label: Text(count > 0 ? '$name  $count' : name),
                      selectedColor: widget.accent.withValues(alpha: 0.22),
                      side: BorderSide(color: selected || cand.isNotEmpty ? widget.accent : tokens.hairline),
                      showCheckmark: false,
                    ),
                  );
                }),
            ],
          ),
        ),
        IconButton(
          tooltip: context.l10n.boxNext,
          onPressed: box < e.boxCount - 1 ? () => _go(box + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ]),
      const SizedBox(height: 14),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: GestureDetector(
          // Deslizar en horizontal cambia de caja (táctil; en escritorio se arrastra).
          onHorizontalDragEnd: _touchFirst
              ? (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v.abs() >= 250) _go(v < 0 ? box + 1 : box - 1);
                }
              : null,
          child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: tokens.sunken, borderRadius: BorderRadius.circular(22)),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
            transitionBuilder: (child, a) {
              final dx = (child.key == ValueKey(box)) == _forward ? 0.06 : -0.06;
              return FadeTransition(
                opacity: a,
                child: SlideTransition(position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(a), child: child),
              );
            },
            child: GridView.builder(
            key: ValueKey(box),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: slots.length,
            itemBuilder: (context, i) {
              final ref = SlotRef.box(box, i);
              final pk = slots[i];
              final locked = e.isSlotLocked(ref);
              return _SlotDnD(
                slot: ref,
                pk: pk,
                actions: widget.actions,
                locked: locked,
                builder: (context, hover) => _BoxSlot(
                  p: pk,
                  hover: hover || (widget.focus?.box == box && widget.focus?.slot == i && pk != null),
                  locked: locked,
                  warnings: pk == null ? 0 : _warnings(pk, widget.actions.game),
                  onTap: () => pk == null ? widget.actions.emptySlot(ref) : widget.actions.edit(ref, pk),
                ),
              );
            },
          ),
          ),
        ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        gb ? context.l10n.dragHintGb : (_touchFirst ? context.l10n.dragHintTouch : context.l10n.dragHint),
        style: context.text.bodySmall!.copyWith(color: tokens.muted),
      ),
    ]);
  }
}

class _BoxSlot extends StatelessWidget {
  const _BoxSlot({required this.p, required this.hover, required this.locked, required this.warnings, required this.onTap});
  final Pkm? p;
  final bool hover;
  final bool locked;
  final int warnings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final p = this.p;
    final border = hover ? context.colors.primary : tokens.hairline;
    if (p == null) {
      return Material(
        color: hover ? context.colors.primary.withValues(alpha: 0.14) : tokens.raised.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: border, width: hover ? 2 : 1)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(child: Icon(Icons.add_rounded, size: 18, color: tokens.muted.withValues(alpha: 0.35))),
        ),
      );
    }
    final name = p.isEgg ? context.l10n.egg : pokemonName(context, p.species, p.form, p.dataGame);
    final nick = p.isNicknamed && !p.isEgg ? p.nickname : null;
    return Tooltip(
      message: '${nick ?? name}\n${p.isEgg ? '' : context.l10n.level(p.level)}${p.isShiny ? '  ${context.l10n.shiny}' : ''}',
      child: Material(
        color: hover ? context.colors.primary.withValues(alpha: 0.14) : Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), side: hover ? BorderSide(color: border, width: 2) : BorderSide.none),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, c) => Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              SpeciesAvatar(species: p.species, form: p.form, game: p.dataGame, female: p.gender == 1, shiny: p.isShiny, egg: p.isEgg, size: c.maxWidth * 0.86),
              if (!p.isEgg && c.maxWidth > 56)
                Positioned(
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: tokens.base.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(6)),
                    child: Text('${p.level}', style: context.text.labelSmall!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  ),
                ),
              if (warnings > 0) Positioned(left: 0, top: 0, child: LegalityDot(count: warnings, size: 14)),
              if (locked) Positioned(right: 2, bottom: 2, child: Icon(Icons.lock_rounded, size: 14, color: tokens.muted)),
            ]),
          ),
        ),
      ),
    );
  }
}
