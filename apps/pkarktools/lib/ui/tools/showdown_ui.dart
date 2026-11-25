import 'package:flutter/material.dart';
import 'package:pkcore/pkcore.dart';

import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../common/species_avatar.dart';
import 'tools_common.dart';

/// Dónde colocar los Pokémon importados.
enum ShowdownTarget { party, boxes }

/// Resultado del diálogo de importación.
class ShowdownImportResult {
  const ShowdownImportResult(this.pokemon, this.target);
  final List<Pkm> pokemon;
  final ShowdownTarget target;
}

/// Huecos donde irán [count] Pokémon nuevos: primero el equipo (si se pide y
/// hay sitio) y después los huecos libres de las cajas, en orden.
List<SlotRef> placementFor(SaveEditor editor, int count, ShowdownTarget target) {
  final out = <SlotRef>[];
  if (target == ShowdownTarget.party) {
    for (var i = editor.partyCount; i < editor.partyCapacity && out.length < count; i++) {
      out.add(SlotRef.party(i));
    }
  }
  for (var b = 0; b < editor.boxCount && out.length < count; b++) {
    for (var s = 0; s < editor.boxSlotCount && out.length < count; s++) {
      final ref = SlotRef.box(b, s);
      if (editor.get(ref) == null && !editor.isSlotLocked(ref)) out.add(ref);
    }
  }
  return out;
}

/// Pide el texto de Showdown, lo analiza contra el juego del save y devuelve
/// los Pokémon que se pueden crear.
Future<ShowdownImportResult?> showShowdownImport(BuildContext context, {required SaveEditor editor}) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => ShowdownImportScreen(editor: editor)));

class ShowdownImportScreen extends StatefulWidget {
  const ShowdownImportScreen({super.key, required this.editor});
  final SaveEditor editor;

  @override
  State<ShowdownImportScreen> createState() => _ShowdownImportScreenState();
}

class _ShowdownImportScreenState extends State<ShowdownImportScreen> {
  final _text = TextEditingController();
  List<ShowdownImport>? _results;
  late ShowdownTarget _target = widget.editor.partyCapacity > widget.editor.partyCount
      ? ShowdownTarget.party
      : ShowdownTarget.boxes;

  void _analyze() {
    final game = widget.editor.game;
    final trainer = widget.editor.readTrainer();
    final lang = context.isSpanish ? DataLanguage.es : DataLanguage.en;
    setState(() {
      _results = [
        for (final s in Showdown.parse(_text.text))
          Showdown.toPkm(s, game, trainer, versionId: widget.editor.versionId, lang: lang),
      ];
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final es = context.isSpanish;
    final results = _results;
    final ok = results?.where((r) => r.ok).toList() ?? const <ShowdownImport>[];
    final room = placementFor(widget.editor, ok.length, _target).length;
    final hasParty = widget.editor.partyCapacity > 0;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.toolsImportFromShowdown)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Text(
            context.l10n.toolsPasteOneOrMorePok,
            style: context.text.bodyMedium!.copyWith(color: context.tokens.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('showdown-text'),
            controller: _text,
            minLines: 8,
            maxLines: 16,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'Garchomp @ Life Orb\nAbility: Rough Skin\nLevel: 50\nJolly Nature\n- Earthquake',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('showdown-analyze'),
                onPressed: _analyze,
                icon: const Icon(Icons.manage_search_rounded),
                label: Text(context.l10n.toolsAnalyze),
              ),
              if (hasParty)
                SegmentedButton<ShowdownTarget>(
                  segments: [
                    ButtonSegment(value: ShowdownTarget.party, label: Text(context.l10n.toolsParty)),
                    ButtonSegment(value: ShowdownTarget.boxes, label: Text(context.l10n.toolsBoxes)),
                  ],
                  selected: {_target},
                  onSelectionChanged: (s) => setState(() => _target = s.first),
                ),
            ],
          ),
          if (results != null) ...[
            const SizedBox(height: 20),
            if (results.isEmpty) Text(context.l10n.toolsNoPokemonFoundIn),
            for (final r in results) _ResultTile(result: r, game: widget.editor.game, es: es),
            if (ok.isNotEmpty && room < ok.length)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  context.l10n.toolsOnlyRoomForOf(room, ok.length),
                  style: TextStyle(color: context.colors.error),
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            key: const ValueKey('showdown-add'),
            onPressed: ok.isEmpty || room == 0
                ? null
                : () =>
                      Navigator.of(context).pop(ShowdownImportResult([for (final r in ok.take(room)) r.pkm!], _target)),
            icon: const Icon(Icons.add_rounded),
            label: Text(context.l10n.toolsAddToTheSave(ok.isEmpty ? '' : ok.length.clamp(0, room))),
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result, required this.game, required this.es});
  final ShowdownImport result;
  final GameVersion game;
  final bool es;

  @override
  Widget build(BuildContext context) {
    final pk = result.pkm;
    final warn = result.warnings;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pk != null)
              SpeciesAvatar(
                species: pk.species,
                form: pk.form,
                game: game,
                shiny: pk.isShiny,
                female: pk.gender == 1,
                size: 48,
              )
            else
              Icon(Icons.block_rounded, size: 40, color: context.colors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pk == null
                        ? result.set.speciesText
                        : '${pokemonName(context, pk.species, pk.form, game)} · ${context.l10n.level(pk.level)}',
                    style: context.text.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  if (warn.isEmpty)
                    Text(context.l10n.toolsNoWarnings, style: TextStyle(color: context.tokens.muted))
                  else
                    for (final w in warn)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: context.colors.error),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(w.message(es: es), style: context.text.bodySmall),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Muestra el texto de Showdown de [team] con botones para copiar y compartir.
Future<void> showShowdownExport(BuildContext context, List<Pkm> team, GameVersion game) {
  final text = Showdown.exportTeam(team, game);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.l10n.toolsShowdownText),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: SelectableText(
            text.isEmpty ? ctx.l10n.toolsNoPokemon : text,
            key: const ValueKey('showdown-export-text'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(MaterialLocalizations.of(ctx).closeButtonLabel)),
        OutlinedButton.icon(
          onPressed: text.isEmpty ? null : () => copyText(ctx, text),
          icon: const Icon(Icons.copy_rounded),
          label: Text(ctx.l10n.toolsCopy),
        ),
        Builder(
          builder: (b) => FilledButton.icon(
            onPressed: text.isEmpty ? null : () => shareText(b, text, subject: 'Pokémon Showdown'),
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(ctx.l10n.toolsShare),
          ),
        ),
      ],
    ),
  );
}
