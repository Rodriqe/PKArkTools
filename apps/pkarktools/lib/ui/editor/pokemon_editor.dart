import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pkcore/pkcore.dart';

import '../../theme/app_theme.dart';
import '../../theme/game_palette.dart';
import '../common/format.dart';
import '../common/species_avatar.dart';
import '../common/game_icons.dart';
import 'legality_view.dart';
import 'origin_panel.dart';
import 'shadow_panel.dart';
import 'pickers.dart';
import 'ribbons_panel.dart';

/// Qué decidió el usuario al cerrar el editor.
sealed class EditorResult {
  const EditorResult();
}

class EditorApply extends EditorResult {
  const EditorApply(this.pk);
  final Pkm pk;
}

class EditorDelete extends EditorResult {
  const EditorDelete();
}

/// «Transferir a otra partida…»: el Pokémon guardado (sin cambios sin aplicar).
class EditorTransfer extends EditorResult {
  const EditorTransfer();
}

class EditorClone extends EditorResult {
  const EditorClone(this.pk);
  final Pkm pk;
}

/// Editor completo de un Pokémon. Trabaja sobre una copia: nada llega al
/// borrador hasta pulsar "Aplicar".
class PokemonEditorScreen extends StatefulWidget {
  const PokemonEditorScreen({
    super.key,
    required this.game,
    required this.initial,
    required this.slotLabel,
    this.isNew = false,
    this.onExport,
    this.canDelete = true,
    this.canTransfer = false,
  });

  final GameVersion game;
  final bool canTransfer;
  final Pkm initial;
  final String slotLabel;
  final bool isNew;
  final bool canDelete;
  final Future<void> Function(Pkm pk)? onExport;

  static Future<EditorResult?> open(
    BuildContext context, {
    required GameVersion game,
    required Pkm pk,
    required String slotLabel,
    bool isNew = false,
    bool canDelete = true,
    bool canTransfer = false,
    Future<void> Function(Pkm pk)? onExport,
  }) =>
      // Navegador raíz: el editor ocupa toda la pantalla (sin la barra inferior).
      Navigator.of(context, rootNavigator: true).push<EditorResult>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PokemonEditorScreen(
          game: game,
          initial: pk,
          slotLabel: slotLabel,
          isNew: isNew,
          canDelete: canDelete,
          canTransfer: canTransfer,
          onExport: onExport,
        ),
      ));

  @override
  State<PokemonEditorScreen> createState() => _PokemonEditorScreenState();
}

class _PokemonEditorScreenState extends State<PokemonEditorScreen> {
  late Pkm pk = widget.initial.clone()..dataGame = widget.game;
  late final GameDataTable table = GameDataTable.forGame(widget.game);
  bool _changed = false;

  String get ctx => table.context;
  PkFormat get f => pk.format;
  int get gen => f.generation;

  late final List<PickOption> _species = speciesOptions(context, widget.game);
  late final List<PickOption> _items = itemOptions(context, widget.game);
  List<PickOption>? _moves;
  int _movesFor = -1;

  List<PickOption> get moveOpts {
    final key = pk.species * 100 + pk.form;
    if (_moves == null || _movesFor != key) {
      _moves = moveOptions(context, widget.game, table.learnableMoves(pk.species, pk.form));
      _movesFor = key;
    }
    return _moves!;
  }

  /// Aplica la corrección segura de un aviso de legalidad.
  void _fix(LegalityIssue issue) {
    final fixed = Legality.applyFix(pk, issue, widget.game);
    if (fixed == null) return;
    mutate((p) => p.data.setRange(0, p.data.length, fixed.data));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.l10n.legalityFixedSnack)));
  }

  void _fixAll(List<LegalityIssue> issues) {
    var p = pk;
    for (var round = 0; round < 3; round++) {
      final pending = Legality.check(p, widget.game).where((i) => i.fix != null).toList();
      if (pending.isEmpty) break;
      for (final i in pending) {
        p = Legality.applyFix(p, i, widget.game) ?? p;
      }
    }
    final data = p.data;
    mutate((x) => x.data.setRange(0, x.data.length, data));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.l10n.legalityFixedSnack)));
  }

  void mutate(void Function(Pkm p) change) {
    setState(() {
      final before = (pk.species, pk.form, pk.level, pk.moves.join(','));
      change(pk);
      // Leyendas Z-A: al cambiar nivel, especie, forma o movimientos, las flags
      // «plus» se ajustan como lo haría el juego (y como exige PKHeX).
      if (pk.hasPlusFlags && before != (pk.species, pk.form, pk.level, pk.moves.join(','))) PlusMoves.sync(pk);
      pk.refreshPartyStats();
      _changed = true;
    });
  }

  Future<bool> _confirmDiscard() async {
    if (!_changed) return true;
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.discardPokemonTitle),
        content: Text(l10n.discardPokemonBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.keepEditing)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.discard)),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1040;
    final phone = width < 600;
    final pad = phone ? 16.0 : 28.0;
    final issues = Legality.check(pk, widget.game, lang: context.dataLang);

    final specimen = _Specimen(pk: pk, game: widget.game, issues: issues, onFix: _fix, onFixAll: () => _fixAll(issues));
    final form = _EditorForm(state: this);

    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          // Teléfono: el hueco va debajo del título (dos líneas) para que ninguno se corte.
          toolbarHeight: phone ? 64 : null,
          titleSpacing: phone ? 0 : null,
          title: phone
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(widget.isNew ? l10n.newPokemon : l10n.editPokemon, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(widget.slotLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge!.copyWith(color: context.tokens.muted)),
                ])
              : Text(widget.isNew ? l10n.newPokemon : l10n.editPokemon),
          actions: [
            if (!phone)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Text(widget.slotLabel, style: context.text.labelLarge!.copyWith(color: context.tokens.muted)),
                ),
              ),
            if (!widget.isNew)
              PopupMenuButton<String>(
                tooltip: l10n.moreActions,
                onSelected: (v) async {
                  final nav = Navigator.of(context);
                  switch (v) {
                    case 'export':
                      await widget.onExport?.call(pk);
                    case 'clone':
                      nav.pop(EditorClone(pk));
                    case 'transfer':
                      nav.pop(const EditorTransfer());
                    case 'delete':
                      nav.pop(const EditorDelete());
                  }
                },
                itemBuilder: (_) => [
                  if (widget.onExport != null)
                    PopupMenuItem(value: 'export', child: Text(l10n.exportPokemon(f.extension))),
                  if (widget.canTransfer) PopupMenuItem(value: 'transfer', child: Text(l10n.transferTo)),
                  PopupMenuItem(value: 'clone', child: Text(l10n.clonePokemon)),
                  if (widget.canDelete) PopupMenuItem(value: 'delete', child: Text(l10n.deletePokemon)),
                ],
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 420,
                    child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(pad, 8, 12, 120), child: specimen),
                  ),
                  Expanded(
                    child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(12, 8, pad, 120), child: form),
                  ),
                ])
              : ListView(
                  padding: EdgeInsets.fromLTRB(pad, 8, pad, 120),
                  children: [specimen, const SizedBox(height: 28), form],
                ),
        ),
        bottomNavigationBar: _ActionBar(
          changed: _changed || widget.isNew,
          onCancel: () async {
            if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop();
          },
          onApply: () {
            pk.refreshPartyStats();
            pk.refreshChecksum();
            Navigator.of(context).pop(EditorApply(pk));
          },
          applyLabel: widget.isNew ? l10n.addToSlot : l10n.applyChanges,
        ),
      ),
    );
  }
}

// =================================================================== ficha

class _Specimen extends StatelessWidget {
  const _Specimen({required this.pk, required this.game, required this.issues, this.onFix, this.onFixAll});
  final Pkm pk;
  final GameVersion game;
  final List<LegalityIssue> issues;
  final ValueChanged<LegalityIssue>? onFix;
  final VoidCallback? onFixAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final species = pokemonName(context, pk.species, pk.form, pk.dataGame);
    final nick = pk.isNicknamed ? pk.nickname : null;
    // Tipos de la forma en el juego (Decidueye de Hisui: Planta/Lucha).
    final (t1, t2) = SpeciesForms.types(pk.species, pk.form, game);
    final g = pk.gender;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SpeciesAvatar(species: pk.species, form: pk.form, game: pk.dataGame, female: pk.gender == 1, shiny: pk.isShiny, egg: pk.isEgg, size: 104, showNumber: true),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nick ?? species, style: context.text.displaySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              [
                if (nick != null) species,
                l10n.level(pk.level),
                if (g == 0) '♂' else if (g == 1) '♀',
              ].join('  '),
              style: context.text.titleMedium!.copyWith(color: tokens.muted),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _TypePill(type: t1),
              if (t2 != PokemonType.none && t2 != t1) _TypePill(type: t2),
              if (pk.isShiny)
                _Pill(
                    label: pk.isSquareShiny ? l10n.shinySquare : l10n.shiny,
                    color: tokens.shiny,
                    icon: Icons.auto_awesome),
            ]),
          ]),
        ),
      ]),
      if (pk.generation >= 3) ...[
        const SizedBox(height: 14),
        OriginSummary(pk: pk),
      ],
      const SizedBox(height: 26),
      StatComposition(pk: pk),
      const SizedBox(height: 26),
      LegalityPanel(issues: issues, onFix: onFix, onFixAll: onFixAll),
    ]);
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});
  final PokemonType type;
  @override
  Widget build(BuildContext context) {
    final names = GameStrings.typeList(context.dataLang);
    final idx = type.index - 1;
    return _Pill(
        label: idx >= 0 && idx < names.length ? names[idx] : '?',
        color: TypePalette.of(type),
        leading: TypeIcon(type: type, size: 16));
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon, this.leading});
  final String label;
  final Color color;
  final IconData? icon;
  final Widget? leading;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (leading != null) ...[leading!, const SizedBox(width: 5)],
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 5)],
          Text(label, style: context.text.labelMedium),
        ]),
      );
}

/// Estadísticas calculadas como barras compuestas: base, IV y EV en el
/// mismo trazo, con la naturaleza marcada. Es la vista previa en vivo.
class StatComposition extends StatelessWidget {
  const StatComposition({super.key, required this.pk});
  final Pkm pk;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final stats = pk.computeStats();
    final personal = GameDataTable.forGame(pk.dataGame!).entry(pk.species, pk.form);
    if (stats == null || personal == null) return const SizedBox.shrink();
    final ivs = pk.ivs, evs = pk.evs;
    final effect = pk.format.generation >= 3 ? GameStrings.natureEffect(pk.statNature) : null;
    final scale = math.max(stats.reduce(math.max).toDouble(), 1.0);
    final base = context.colors.secondary;
    final iv = context.colors.primary;
    final ev = const Color(0xFF52C98A);
    final gb = pk.format.isGameBoy;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: tokens.raised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.hairline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(l10n.statsAtLevel(pk.level), style: context.text.titleMedium)),
          Text('${l10n.baseTotal} ${personal.baseStatTotal}',
              style: context.text.labelMedium!.copyWith(color: tokens.muted)),
        ]),
        const SizedBox(height: 14),
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(
                width: 78,
                child: Row(children: [
                  Flexible(
                    child: Text(Legality.statName(i, context.dataLang),
                        overflow: TextOverflow.ellipsis, style: context.text.labelMedium),
                  ),
                  if (effect?.$1 == i) Icon(Icons.arrow_drop_up_rounded, size: 20, color: ev),
                  if (effect?.$2 == i) Icon(Icons.arrow_drop_down_rounded, size: 20, color: context.colors.error),
                ]),
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  final total = c.maxWidth * (stats[i] / scale);
                  // Contribuciones relativas: 2·base, IV y EV/4 (stat exp en GB).
                  final b = 2.0 * personal.baseStats[i];
                  final v = gb ? 2.0 * ivs[i] : ivs[i].toDouble();
                  final e = gb ? math.sqrt(evs[i]) / 4 : evs[i] / 4.0;
                  final sum = math.max(b + v + e, 1.0);
                  return Container(
                    height: 12,
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(color: tokens.sunken, borderRadius: BorderRadius.circular(6)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      width: total,
                      height: 12,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(flex: math.max((b / sum * 1000).round(), 1), child: ColoredBox(color: base)),
                        if (v > 0) Expanded(flex: math.max((v / sum * 1000).round(), 1), child: ColoredBox(color: iv)),
                        if (e > 0) Expanded(flex: math.max((e / sum * 1000).round(), 1), child: ColoredBox(color: ev)),
                      ]),
                    ),
                  );
                }),
              ),
              SizedBox(
                width: 52,
                child: Text('${stats[i]}',
                    textAlign: TextAlign.right,
                    style: context.text.titleSmall!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ]),
          ),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 6, children: [
          _Legend(color: base, label: l10n.legendBase),
          _Legend(color: iv, label: gb ? 'DV' : 'IV'),
          _Legend(color: ev, label: gb ? l10n.statExp : 'EV'),
        ]),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: context.text.labelSmall!.copyWith(color: context.tokens.muted)),
      ]);
}

// =================================================================== formulario

class _EditorForm extends StatelessWidget {
  const _EditorForm({required this.state});
  final _PokemonEditorScreenState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final pk = s.pk;
    final gen = s.gen;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Section(title: context.l10n.sectionIdentity, child: _IdentityFields(s: s)),
      _Section(title: context.l10n.sectionTraits, child: _TraitFields(s: s)),
      _Section(title: context.l10n.sectionMoves, child: _MoveFields(s: s)),
      _Section(title: context.l10n.sectionStats, child: _StatFields(s: s)),
      if (!pk.isEgg) _Section(title: context.l10n.sectionTrainer, child: _OtFields(s: s, gen: gen)),
      if (ShadowPanel.applies(pk, s.widget.game))
        _Section(title: context.l10n.sectionShadow, child: ShadowPanel(pk: pk, game: s.widget.game, mutate: s.mutate)),
      if (gen >= 3) _Section(title: context.l10n.sectionOrigin, child: OriginPanel(pk: pk, game: s.widget.game, mutate: s.mutate)),
      if (Ribbons.supports(pk.format))
        _Section(title: context.l10n.sectionRibbons, child: RibbonsPanel(pk: pk, mutate: s.mutate)),
    ]);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: context.text.headlineSmall),
          const SizedBox(height: 14),
          child,
        ]),
      );
}

/// Rejilla responsiva de campos.
class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.children, this.min = 240});
  final List<Widget> children;
  final double min;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = math.max(1, (c.maxWidth / min).floor());
        const gap = 14.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
}

class _IdentityFields extends StatelessWidget {
  const _IdentityFields({required this.s});
  final _PokemonEditorScreenState s;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pk = s.pk;
    final game = s.widget.game;
    final lang = context.isSpanish ? DataLanguage.es : DataLanguage.en;
    // Formas que existen en el juego (más la actual, aunque no exista, para no ocultarla).
    final forms = {...SpeciesForms.presentForms(pk.species, game), pk.form}.toList()..sort();
    final ratio = s.table.entry(pk.species, pk.form)?.genderRatio ?? 255;
    String formLabel(int f) {
      final n = SpeciesForms.formName(pk.species, f, game, lang);
      if (n.isNotEmpty) return n;
      return f == 0 ? l10n.formBase : l10n.formN(f);
    }
    return _FieldGrid(children: [
      SearchPicker(
        label: l10n.species,
        options: s._species,
        value: pk.species,
        onSelected: (v) => s.mutate((p) {
          final present = SpeciesForms.presentForms(v, game);
          p.species = v;
          _setForm(p, present.isEmpty ? 0 : present.first, game);
        }),
      ),
      if (forms.length > 1)
        _Dropdown<int>(
          label: l10n.form,
          value: pk.form,
          items: {for (final f in forms) f: formLabel(f)},
          onChanged: (v) => s.mutate((p) => _setForm(p, v, game)),
        ),
      _TextFieldCommit(
        label: l10n.nickname,
        value: pk.nickname,
        maxLength: pk.format.maxNicknameLength,
        onCommit: (v) => s.mutate((p) => p.setNickname(v.trim().isEmpty ? null : v)),
        trailing: IconButton(
          tooltip: l10n.useSpeciesName,
          icon: const Icon(Icons.restart_alt_rounded),
          onPressed: () => s.mutate((p) => p.setDefaultNickname()),
        ),
      ),
      _LabeledControl(
        label: l10n.shiny,
        child: s.gen >= 8
            ? FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 0, label: Text(l10n.no)),
                  ButtonSegment(value: 1, label: Text(l10n.shinyStar)),
                  ButtonSegment(value: 2, label: Text(l10n.shinySquare)),
                ],
                selected: {pk.isShiny ? (pk.isSquareShiny ? 2 : 1) : 0},
                onSelectionChanged: (v) => s.mutate((p) => p.setShiny(v.first != 0, square: v.first == 2)),
              ))
            : Switch(value: pk.isShiny, onChanged: (v) => s.mutate((p) => p.setShiny(v))),
      ),
      if (s.gen >= 2)
        _LabeledControl(
          label: l10n.gender,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('♂')),
              ButtonSegment(value: 1, label: Text('♀')),
              ButtonSegment(value: 2, label: Text('—')),
            ],
            selected: {pk.gender.clamp(0, 2)},
            onSelectionChanged: (ratio == 255 || ratio == 254 || ratio == 0)
                ? null
                : (v) => s.mutate((p) => p.gender = v.first == 2 ? 0 : v.first),
          ),
        ),
      if (s.gen >= 3)
        _Dropdown<int>(
          label: l10n.language,
          value: kLanguages.containsKey(pk.language) ? pk.language : 2,
          items: kLanguages,
          onChanged: (v) => s.mutate((p) => p.language = v),
        ),
    ]);
  }
}

/// Cambia la forma y rehace lo que depende de ella: la habilidad (misma
/// ranura, con las habilidades de la nueva forma), el género si la forma lo
/// fija (Basculegion, Indeedee…) y, en Ogerpon, el teratipo de la máscara.
void _setForm(Pkm p, int form, GameVersion game) {
  final slot = p.abilitySlot;
  p.form = form;
  p.setAbilitySlot(slot);
  final r = GameDataTable.forGame(game).entry(p.species, form)?.genderRatio ?? 255;
  if (p.generation >= 4) p.gender = r == 255 ? 2 : (r == 254 ? 1 : (r == 0 ? 0 : p.gender.clamp(0, 1)));
  if (p.format.hasTeraType && p.species == 1017) {
    p.teraTypeOriginal = SpeciesForms.defaultTeraType(p.species, form, game);
    p.teraType = p.teraTypeOriginal;
  }
}

class _TraitFields extends StatelessWidget {
  const _TraitFields({required this.s});
  final _PokemonEditorScreenState s;

  String _natureLabel(BuildContext context, int n) {
    final name = GameStrings.nature(n, context.dataLang);
    final e = GameStrings.natureEffect(n);
    if (e == null) return '$name (${context.l10n.neutral})';
    String short(int i) => Legality.statName(i, context.dataLang);
    return '$name (+${short(e.$1)} −${short(e.$2)})';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pk = s.pk;
    final gen = s.gen;
    final personal = s.table.entry(pk.species, pk.form);
    final abilities = personal?.abilities ?? const <int>[];
    final natures = {for (var i = 0; i < 25; i++) i: _natureLabel(context, i)};
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _FieldGrid(children: [
        _LabeledControl(
          label: l10n.levelLabel,
          child: Row(children: [
            Expanded(
              child: Slider(
                value: pk.level.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                label: '${pk.level}',
                onChanged: (v) => s.mutate((p) => p.level = v.round()),
              ),
            ),
            SizedBox(
              width: 64,
              child: _NumberField(value: pk.level, min: 1, max: 100, onCommit: (v) => s.mutate((p) => p.level = v)),
            ),
          ]),
        ),
        _NumberField(
          label: l10n.experience,
          value: pk.exp,
          min: 0,
          max: Species.expForLevel(pk.species, 100),
          onCommit: (v) => s.mutate((p) => p.exp = v),
        ),
        if (gen >= 2)
          _LabeledControl(
            label: '${l10n.friendship} · ${pk.friendship}',
            child: Slider(
              value: pk.friendship.toDouble(),
              max: 255,
              onChanged: (v) => s.mutate((p) => p.friendship = v.round()),
            ),
          ),
        if (gen >= 3)
          _Dropdown<int>(
            label: l10n.nature,
            value: pk.nature.clamp(0, 24),
            items: natures,
            onChanged: (v) => s.mutate((p) => p.nature = v),
          ),
        if (pk.format.hasStatNature)
          _Dropdown<int>(
            label: l10n.mint,
            value: pk.statNature.clamp(0, 24),
            items: natures,
            onChanged: (v) => s.mutate((p) => p.statNature = v),
          ),
        if (gen >= 2)
          SearchPicker(
            label: l10n.heldItem,
            options: s._items,
            value: pk.heldItem,
            allowNone: true,
            noneLabel: l10n.none,
            onSelected: (v) => s.mutate((p) => p.heldItem = v),
          ),
        if (pk.format.hasTeraType) ...[
          _Dropdown<int>(
            label: l10n.teraOriginal,
            value: pk.teraTypeOriginal.clamp(0, 17),
            items: {for (var t = 0; t < 18; t++) t: GameStrings.type(t, context.dataLang)},
            onChanged: (v) => s.mutate((p) {
              final cur = p.teraType;
              p.teraTypeOriginal = v;
              p.teraType = cur;
            }),
          ),
          _Dropdown<int>(
            label: l10n.teraType,
            value: pk.teraType.clamp(0, 17),
            items: {for (var t = 0; t < 18; t++) t: GameStrings.type(t, context.dataLang)},
            onChanged: (v) => s.mutate((p) => p.teraType = v),
          ),
        ],
      ]),
      if (gen >= 3 && abilities.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text(l10n.ability, style: context.text.labelLarge),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < abilities.length && i < (gen == 3 || gen == 4 ? 2 : 3); i++)
            ChoiceChip(
              selected: pk.abilitySlot == i,
              showCheckmark: false,
              label: Text(i == 2
                  ? '${GameStrings.ability(abilities[i], context.dataLang)} (${l10n.hiddenAbility})'
                  : GameStrings.ability(abilities[i], context.dataLang)),
              onSelected: (_) => s.mutate((p) => p.setAbilitySlot(i)),
            ),
        ]),
      ],
    ]);
  }
}

class _MoveFields extends StatelessWidget {
  const _MoveFields({required this.s});
  final _PokemonEditorScreenState s;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pk = s.pk;
    final ctx = s.ctx;
    final opts = s.moveOpts;
    final noUps = ctx == '8a' || ctx == '9a';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < 4; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: SearchPicker(
                key: ValueKey('move$i-${pk.species}'),
                label: l10n.moveN(i + 1),
                options: opts,
                value: pk.move(i),
                allowNone: true,
                noneLabel: l10n.none,
                labelFor: (id) => GameStrings.move(id, context.dataLang),
                onSelected: (v) => s.mutate((p) => p.setMove(i, v, context: ctx)),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 82,
              child: _NumberField(
                label: 'PP',
                value: pk.pp(i),
                min: 0,
                max: math.max(MoveData.maxPp(pk.move(i), ctx, pk.ppUps(i)), pk.pp(i)),
                onCommit: (v) => s.mutate((p) => p.setPp(i, v)),
              ),
            ),
            if (!noUps) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 96,
                child: _Dropdown<int>(
                  label: l10n.ppUps,
                  value: pk.ppUps(i),
                  items: const {0: '0', 1: '1', 2: '2', 3: '3'},
                  onChanged: (v) => s.mutate((p) {
                    p.setPpUps(i, v);
                    p.setPp(i, MoveData.maxPp(p.move(i), ctx, v));
                  }),
                ),
              ),
            ],
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: 8, children: [
          OutlinedButton.icon(
            onPressed: () => s.mutate((p) => p.healPp(ctx)),
            icon: const Icon(Icons.local_drink_rounded, size: 18),
            label: Text(l10n.restorePp),
          ),
          if (!noUps)
            OutlinedButton.icon(
              onPressed: () => s.mutate((p) {
                for (var i = 0; i < 4; i++) {
                  p.setPpUps(i, 3);
                }
                p.healPp(ctx);
              }),
              icon: const Icon(Icons.trending_up_rounded, size: 18),
              label: Text(l10n.maxPpUps),
            ),
        ]),
      ),
    ]);
  }
}

class _StatFields extends StatelessWidget {
  const _StatFields({required this.s});
  final _PokemonEditorScreenState s;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pk = s.pk;
    final f = pk.format;
    final gb = f.isGameBoy;
    final ivs = pk.ivs, evs = pk.evs;
    final evTotal = gb ? 0 : evs.fold(0, (a, b) => a + b);
    final maxEv = gb ? 65535 : (f.generation >= 6 ? 252 : 255);
    void evPreset(List<int> v) => s.mutate((p) => p.setEvs(v));

    Widget row(String label, int value, int max, ValueChanged<int> onChanged, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            SizedBox(width: 92, child: Text(label, style: context.text.labelMedium)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(activeTrackColor: color, thumbColor: color),
                child: Slider(value: value.clamp(0, max).toDouble(), max: max.toDouble(), onChanged: (v) => onChanged(v.round())),
              ),
            ),
            SizedBox(width: 78, child: _NumberField(value: value, min: 0, max: max, onCommit: onChanged)),
          ]),
        );

    // En Gen 1/2 PS y Especial se derivan; se ocultan las duplicadas.
    final visible = gb ? [0, 1, 2, 3, 5] : [0, 1, 2, 3, 4, 5];
    String statLabel(int i) => gb && i == 3 ? l10n.special : Legality.statName(i, context.dataLang);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(gb ? l10n.dvs : l10n.ivs, style: context.text.titleMedium),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ActionChip(label: Text(l10n.presetPerfectIvs), onPressed: () => s.mutate((p) => p.setIvs(List.filled(6, f.maxIv)))),
        if (!gb) ActionChip(label: Text(l10n.presetZeroSpeed), onPressed: () => s.mutate((p) => p.setIv(5, 0))),
        if (!gb) ActionChip(label: Text(l10n.presetZeroAttack), onPressed: () => s.mutate((p) => p.setIv(1, 0))),
      ]),
      const SizedBox(height: 8),
      for (final i in visible)
        if (!(gb && i == 0))
          row(statLabel(i), ivs[i], f.maxIv, (v) => s.mutate((p) => p.setIv(i, v)), context.colors.primary)
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text('${l10n.hpDerived}: ${ivs[0]}', style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
          ),
      if (f != PkFormat.pb7) ...[
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Text(gb ? l10n.statExp : l10n.evs, style: context.text.titleMedium)),
          if (!gb)
            Text(l10n.evTotal(evTotal, 510),
                style: context.text.labelLarge!.copyWith(
                    color: evTotal > 510 ? context.colors.error : context.tokens.muted,
                    fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (gb)
            ActionChip(label: Text(l10n.presetMaxStatExp), onPressed: () => evPreset(List.filled(6, 65535)))
          else ...[
            ActionChip(label: Text(l10n.presetPhysical), onPressed: () => evPreset(const [4, 252, 0, 0, 0, 252])),
            ActionChip(label: Text(l10n.presetSpecial), onPressed: () => evPreset(const [4, 0, 0, 252, 0, 252])),
            ActionChip(label: Text(l10n.presetPhysWall), onPressed: () => evPreset(const [252, 0, 252, 0, 4, 0])),
            ActionChip(label: Text(l10n.presetSpecWall), onPressed: () => evPreset(const [252, 0, 4, 0, 252, 0])),
          ],
          ActionChip(label: Text(l10n.presetClear), onPressed: () => evPreset(List.filled(6, 0))),
        ]),
        const SizedBox(height: 8),
        for (final i in visible)
          row(statLabel(i), evs[i], maxEv, (v) => s.mutate((p) => p.setEv(i, v)), const Color(0xFF52C98A)),
      ],
      if (f.hasAwakeningValues) ...[
        const SizedBox(height: 18),
        Text(l10n.avs, style: context.text.titleMedium),
        const SizedBox(height: 6),
        ActionChip(
            label: Text(l10n.presetMaxAvs),
            onPressed: () => s.mutate((p) {
                  for (var i = 0; i < 6; i++) {
                    p.setAv(i, 200);
                  }
                })),
        for (var i = 0; i < 6; i++)
          row(Legality.statName(i, context.dataLang), pk.avs[i], 200, (v) => s.mutate((p) => p.setAv(i, v)),
              const Color(0xFFE8A14A)),
      ],
      if (f.hasGanbaruValues) ...[
        const SizedBox(height: 18),
        Text(l10n.gvs, style: context.text.titleMedium),
        const SizedBox(height: 6),
        ActionChip(
            label: Text(l10n.presetMaxGvs),
            onPressed: () => s.mutate((p) {
                  for (var i = 0; i < 6; i++) {
                    p.setGv(i, 10);
                  }
                })),
        for (var i = 0; i < 6; i++)
          row(Legality.statName(i, context.dataLang), pk.gvs[i], 10, (v) => s.mutate((p) => p.setGv(i, v)),
              const Color(0xFFE8A14A)),
      ],
    ]);
  }
}

class _OtFields extends StatelessWidget {
  const _OtFields({required this.s, required this.gen});
  final _PokemonEditorScreenState s;
  final int gen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pk = s.pk;
    return _FieldGrid(min: 200, children: [
      _TextFieldCommit(
        label: l10n.otName,
        value: pk.otName,
        maxLength: pk.format.maxTrainerNameLength,
        onCommit: (v) => s.mutate((p) => p.otName = v),
      ),
      _NumberField(label: l10n.trainerIdLong, value: pk.tid, min: 0, max: 65535, onCommit: (v) => s.mutate((p) => p.tid = v)),
      if (gen >= 3)
        _NumberField(label: l10n.secretId, value: pk.sid, min: 0, max: 65535, onCommit: (v) => s.mutate((p) => p.sid = v)),
      if (gen >= 3)
        _LabeledControl(
          label: l10n.otGender,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: 0, label: Text('♂')), ButtonSegment(value: 1, label: Text('♀'))],
            selected: {pk.otGender},
            onSelectionChanged: (v) => s.mutate((p) => p.otGender = v.first),
          ),
        ),
    ]);
  }
}

// =================================================================== controles

class _LabeledControl extends StatelessWidget {
  const _LabeledControl({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: context.text.labelMedium!.copyWith(color: context.tokens.muted)),
        const SizedBox(height: 6),
        child,
      ]);
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        key: ValueKey('$label-$value'),
        initialValue: items.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );
}

/// Campo numérico que confirma al pulsar Intro o al perder el foco.
class _NumberField extends StatefulWidget {
  const _NumberField({this.label, required this.value, required this.min, required this.max, required this.onCommit});
  final String? label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onCommit;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _c = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _NumberField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) _c.text = '${widget.value}';
  }

  void _commit() {
    final v = int.tryParse(_c.text);
    if (v == null) {
      _c.text = '${widget.value}';
      return;
    }
    final clamped = v.clamp(widget.min, widget.max);
    _c.text = '$clamped';
    if (clamped != widget.value) widget.onCommit(clamped);
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        focusNode: _focus,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: widget.label == null ? TextAlign.center : TextAlign.start,
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        decoration: InputDecoration(labelText: widget.label, isDense: widget.label == null),
        onSubmitted: (_) => _commit(),
      );
}

class _TextFieldCommit extends StatefulWidget {
  const _TextFieldCommit({required this.label, required this.value, required this.onCommit, this.maxLength, this.trailing});
  final String label;
  final String value;
  final int? maxLength;
  final ValueChanged<String> onCommit;
  final Widget? trailing;

  @override
  State<_TextFieldCommit> createState() => _TextFieldCommitState();
}

class _TextFieldCommitState extends State<_TextFieldCommit> {
  late final _c = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _c.text != widget.value) widget.onCommit(_c.text);
    });
  }

  @override
  void didUpdateWidget(covariant _TextFieldCommit old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        focusNode: _focus,
        maxLength: widget.maxLength,
        decoration: InputDecoration(labelText: widget.label, counterText: '', suffixIcon: widget.trailing),
        onSubmitted: (v) {
          if (v != widget.value) widget.onCommit(v);
        },
      );
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.changed, required this.onCancel, required this.onApply, required this.applyLabel});
  final bool changed;
  final VoidCallback onCancel;
  final VoidCallback onApply;
  final String applyLabel;

  @override
  Widget build(BuildContext context) => Material(
        color: context.tokens.sunken,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: MediaQuery.sizeOf(context).width < 600
                ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (changed) ...[
                      Text(context.l10n.changesStayInDraft,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
                      const SizedBox(height: 8),
                    ],
                    Row(children: [
                      Expanded(
                        flex: 2,
                        child: SizedBox(height: 48, child: TextButton(onPressed: onCancel, child: Text(context.l10n.cancel))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: changed ? onApply : null,
                            child: Text(applyLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                    ]),
                  ])
                : Row(children: [
              if (changed)
                Expanded(
                  child: Text(context.l10n.changesStayInDraft,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall!.copyWith(color: context.tokens.muted)),
                )
              else
                const Spacer(),
              const SizedBox(width: 12),
              TextButton(onPressed: onCancel, child: Text(context.l10n.cancel)),
              const SizedBox(width: 8),
              FilledButton(onPressed: changed ? onApply : null, child: Text(applyLabel)),
            ]),
          ),
        ),
      );
}
