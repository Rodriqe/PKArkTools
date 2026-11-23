import 'package:flutter/material.dart';
import 'package:pkcore/pkcore.dart';

import '../../theme/app_theme.dart';
import '../common/format.dart';

/// Una opción de un selector con búsqueda.
class PickOption {
  const PickOption(this.id, this.label, {this.hint, this.highlight = false});
  final int id;
  final String label;

  /// Texto secundario (tipo, "aprende por nivel 12"…).
  final String? hint;

  /// Opciones destacadas (p. ej. movimientos aprendibles) van primero.
  final bool highlight;
}

/// Normaliza para buscar sin tildes ni mayúsculas.
String foldText(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñç';
  const to = 'aaaaeeeeiiiioooouuuunc';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b.toString();
}

/// Campo con autocompletado sobre una lista de ids con nombre.
class SearchPicker extends StatefulWidget {
  const SearchPicker({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onSelected,
    this.allowNone = false,
    this.noneLabel,
    this.leading,
    this.dense = false,
    this.labelFor,
  });

  /// Nombre para ids que no están entre las opciones (p. ej. un movimiento inexistente en el juego).
  final String Function(int id)? labelFor;

  final String label;
  final List<PickOption> options;
  final int value;
  final ValueChanged<int> onSelected;
  final bool allowNone;
  final String? noneLabel;
  final Widget? leading;
  final bool dense;

  @override
  State<SearchPicker> createState() => _SearchPickerState();
}

class _SearchPickerState extends State<SearchPicker> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  String _labelFor(int id) {
    if (id == 0 && widget.allowNone) return '';
    for (final o in widget.options) {
      if (o.id == id) return o.label;
    }
    if (id == 0) return '';
    return widget.labelFor?.call(id) ?? '#$id';
  }

  @override
  void initState() {
    super.initState();
    _controller.text = _labelFor(widget.value);
    _focus.addListener(() {
      if (!_focus.hasFocus) _controller.text = _labelFor(widget.value);
    });
  }

  @override
  void didUpdateWidget(covariant SearchPicker old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && (old.value != widget.value || old.options != widget.options)) {
      _controller.text = _labelFor(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Iterable<PickOption> _filter(String q) {
    final f = foldText(q.trim());
    final list = widget.options.where((o) => f.isEmpty || foldText(o.label).contains(f)).toList()
      ..sort((a, b) {
        if (a.highlight != b.highlight) return a.highlight ? -1 : 1;
        if (f.isNotEmpty) {
          final sa = foldText(a.label).startsWith(f), sb = foldText(b.label).startsWith(f);
          if (sa != sb) return sa ? -1 : 1;
        }
        return 0;
      });
    return [
      if (widget.allowNone && f.isEmpty) PickOption(0, widget.noneLabel ?? '—'),
      ...list.take(60),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return RawAutocomplete<PickOption>(
      textEditingController: _controller,
      focusNode: _focus,
      optionsBuilder: (v) => _filter(_focus.hasFocus && v.text == _labelFor(widget.value) ? '' : v.text),
      displayStringForOption: (o) => o.label,
      onSelected: (o) {
        widget.onSelected(o.id);
        _focus.unfocus();
      },
      fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
        controller: controller,
        focusNode: focus,
        onTap: () => controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length),
        decoration: InputDecoration(
          labelText: widget.label,
          isDense: widget.dense,
          prefixIcon: widget.leading,
          suffixIcon: const Icon(Icons.search_rounded, size: 18),
        ),
        onSubmitted: (_) => onSubmit(),
      ),
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: tokens.raised,
            elevation: 8,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 420),
              child: list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(context.l10n.noMatches, style: context.text.bodyMedium!.copyWith(color: tokens.muted)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final o = list[i];
                        final active = AutocompleteHighlightedOption.of(context) == i;
                        return InkWell(
                          onTap: () => onSelected(o),
                          child: Container(
                            color: active ? context.colors.primary.withValues(alpha: 0.10) : null,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            child: Row(children: [
                              if (o.highlight)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(Icons.check_circle_rounded, size: 14, color: context.colors.primary),
                                ),
                              Expanded(child: Text(o.label, style: context.text.bodyMedium)),
                              if (o.hint != null)
                                Text(o.hint!, style: context.text.labelSmall!.copyWith(color: tokens.muted)),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Nombres de datos en el idioma de la interfaz.
extension GameTextX on BuildContext {
  DataLanguage get dataLang => isSpanish ? DataLanguage.es : DataLanguage.en;
}

/// Opciones de especies disponibles en el juego.
List<PickOption> speciesOptions(BuildContext context, GameVersion game) {
  final table = GameDataTable.forGame(game);
  final max = switch (game.generation) {
    1 => 151,
    2 => 251,
    3 => 386,
    4 => 493,
    5 => 649,
    6 => 721,
    7 => game == GameVersion.letsGo ? 809 : 807,
    8 => 905,
    _ => Species.max,
  };
  return [
    for (var s = 1; s <= max; s++)
      if (table.hasSpecies(s)) PickOption(s, speciesName(context, s), hint: '#${s.toString().padLeft(4, '0')}'),
  ];
}

/// Opciones de movimientos del juego, con los aprendibles destacados.
List<PickOption> moveOptions(BuildContext context, GameVersion game, Set<int> learnable) {
  final table = GameDataTable.forGame(game);
  final ctx = table.context;
  final lang = context.dataLang;
  return [
    for (var m = 1; m <= MoveData.maxMove(ctx); m++)
      if (MoveData.existsIn(m, ctx))
        PickOption(m, GameStrings.move(m, lang),
            hint: GameStrings.type(MoveData.type(m, ctx), lang), highlight: learnable.contains(m)),
  ];
}

/// Objetos equipables del juego (o todos si no hay lista).
List<PickOption> itemOptions(BuildContext context, GameVersion game) {
  final gen = game.generation;
  final lang = context.dataLang;
  final held = ItemTables.held(game);
  final ids = held.isNotEmpty ? (held.toList()..sort()) : [for (var i = 1; i < GameStrings.itemList(gen, lang).length; i++) i];
  return [
    for (final i in ids)
      if (i > 0) PickOption(i, GameStrings.item(i, gen, lang)),
  ];
}

/// Nombre de la Poké Ball por id de ball (Gen 3+), incluidas las de Hisui.
String ballName(BuildContext context, int ball) => BallTables.name(ball, context.dataLang);

/// Balls del selector para [game]; conserva la Ball actual aunque no sea del juego.
List<int> ballsFor(GameVersion game, [int current = 0]) => BallTables.pickerOptions(game, current);

/// Idiomas de juego (ids de PKHeX).
const kLanguages = {1: '日本語', 2: 'English', 3: 'Français', 4: 'Italiano', 5: 'Deutsch', 7: 'Español', 8: '한국어', 9: '简体中文', 10: '繁體中文'};
