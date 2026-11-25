import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../../data/update/events_update.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../common/species_avatar.dart';

/// Lo que se elige al crear desde un evento.
typedef EventChoice = ({EventGift gift, bool? shiny, int language});

/// Explorador de eventos (Regalo Misterioso) de la base de PKHeX: búsqueda,
/// filtros (especie, juego, generación, año, región, idioma, variocolor y tipo
/// de distribución) y ficha con todos los datos fijos.
///
/// Con [pickFor] solo muestra los que se pueden crear en esa partida y la
/// ficha ofrece «Crear en esta partida» (devuelve un [EventChoice]).
class EventExplorer extends ConsumerStatefulWidget {
  const EventExplorer({super.key, this.pickFor, this.species, this.saveLanguage = 2, this.onPicked});
  final GameVersion? pickFor;
  final int? species;

  /// Idioma de la partida (ids de PKHeX) para proponer el del Pokémon.
  final int saveLanguage;
  final ValueChanged<EventChoice>? onPicked;

  @override
  ConsumerState<EventExplorer> createState() => _EventExplorerState();
}

class _EventExplorerState extends ConsumerState<EventExplorer> {
  late EventFilter _filter = EventFilter(species: widget.species, creatableIn: widget.pickFor);
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(EventFilter Function(EventFilter f) change) => setState(() => _filter = change(_filter));

  EventFilter _copy({
    String? text,
    Object? generation = _keep,
    Object? game = _keep,
    Object? year = _keep,
    Object? region = _keep,
    Object? language = _keep,
    Object? shiny = _keep,
    Object? distribution = _keep,
    Object? species = _keep,
  }) {
    final f = _filter;
    return EventFilter(
      text: text ?? f.text,
      generation: generation == _keep ? f.generation : generation as int?,
      game: game == _keep ? f.game : game as GameVersion?,
      year: year == _keep ? f.year : year as int?,
      region: region == _keep ? f.region : region as EventRegion?,
      language: language == _keep ? f.language : language as int?,
      shiny: shiny == _keep ? f.shiny : shiny as bool?,
      distribution: distribution == _keep ? f.distribution : distribution as EventDistribution?,
      species: species == _keep ? f.species : species as int?,
      creatableIn: f.creatableIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Carga la última base descargada (y la busca en GitHub si toca).
    final newKeys = ref.watch(eventsDataProvider).value?.newKeys ?? const <String>{};
    final base = widget.pickFor == null ? EventDb.all : EventDb.creatableIn(widget.pickFor!);
    final list = _filter.apply(base,
        nameEs: (s) => Species.name(s, SpeciesLanguage.es), nameEn: (s) => Species.name(s, SpeciesLanguage.en));
    final years = {for (final g in base) if (g.year != null) g.year!}.toList()..sort();
    final games = <GameVersion>{for (final g in base) ...g.games}.toList()..sort((a, b) => a.index.compareTo(b.index));
    final gens = {for (final g in base) g.generation}.toList()..sort();
    final langs = {for (final g in base) ...g.languages}.toList()..sort();
    final es = context.isSpanish;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        key: const ValueKey('events-search'),
        controller: _search,
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l10n.eventsSearch),
        onChanged: (v) => _set((_) => _copy(text: v)),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (_filter.species != null)
          InputChip(
            key: const ValueKey('events-species-chip'),
            label: Text(speciesName(context, _filter.species!)),
            onDeleted: () => _set((_) => _copy(species: null)),
          ),
        _FilterChipMenu<int>(
          keyName: 'gen',
          label: l10n.eventsFilterGen,
          value: _filter.generation,
          options: [for (final g in gens) (g, 'Gen $g')],
          onChanged: (v) => _set((_) => _copy(generation: v)),
        ),
        _FilterChipMenu<GameVersion>(
          keyName: 'game',
          label: l10n.eventsFilterGame,
          value: _filter.game,
          options: [for (final g in games) (g, es ? g.nameEs : g.nameEn)],
          onChanged: (v) => _set((_) => _copy(game: v)),
        ),
        _FilterChipMenu<int>(
          keyName: 'year',
          label: l10n.eventsFilterYear,
          value: _filter.year,
          options: [for (final y in years.reversed) (y, '$y')],
          onChanged: (v) => _set((_) => _copy(year: v)),
        ),
        _FilterChipMenu<EventRegion>(
          keyName: 'region',
          label: l10n.eventsFilterRegion,
          value: _filter.region,
          options: [for (final r in EventRegion.values) (r, regionName(context, r))],
          onChanged: (v) => _set((_) => _copy(region: v)),
        ),
        _FilterChipMenu<int>(
          keyName: 'lang',
          label: l10n.eventsFilterLanguage,
          value: _filter.language,
          options: [for (final l in langs) (l, eventLanguageName(l, es: es))],
          onChanged: (v) => _set((_) => _copy(language: v)),
        ),
        _FilterChipMenu<bool>(
          keyName: 'shiny',
          label: l10n.eventsFilterShiny,
          value: _filter.shiny,
          options: [(true, l10n.eventsShinyYes), (false, l10n.eventsShinyNo)],
          onChanged: (v) => _set((_) => _copy(shiny: v)),
        ),
        _FilterChipMenu<EventDistribution>(
          keyName: 'type',
          label: l10n.eventsFilterType,
          value: _filter.distribution,
          options: [for (final d in EventDistribution.values) (d, distributionName(context, d))],
          onChanged: (v) => _set((_) => _copy(distribution: v)),
        ),
      ]),
      const SizedBox(height: 10),
      Text(l10n.eventsCount(list.length), style: context.text.labelMedium!.copyWith(color: context.tokens.muted)),
      const SizedBox(height: 4),
      Expanded(
        child: list.isEmpty
            ? Center(child: Text(l10n.eventsEmpty, key: const ValueKey('events-empty')))
            : ListView.builder(
                key: const ValueKey('events-list'),
                itemCount: list.length,
                itemBuilder: (context, i) => _EventTile(
                  gift: list[i],
                  isNew: newKeys.contains(list[i].key),
                  onTap: () => _openDetail(context, list[i]),
                ),
              ),
      ),
    ]);
  }

  Future<void> _openDetail(BuildContext context, EventGift g) async {
    final choice = await showModalBottomSheet<EventChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, scroll) => EventDetailView(
          gift: g,
          scroll: scroll,
          pickFor: widget.pickFor,
          saveLanguage: widget.saveLanguage,
        ),
      ),
    );
    if (choice != null) widget.onPicked?.call(choice);
  }
}

const Object _keep = Object();

String regionName(BuildContext context, EventRegion r) {
  final l10n = context.l10n;
  return switch (r) {
    EventRegion.japan => l10n.eventsRegionJapan,
    EventRegion.international => l10n.eventsRegionInternational,
    EventRegion.korea => l10n.eventsRegionKorea,
    EventRegion.china => l10n.eventsRegionChina,
  };
}

String distributionName(BuildContext context, EventDistribution d) {
  final l10n = context.l10n;
  return switch (d) {
    EventDistribution.card => l10n.eventsTypeCard,
    EventDistribution.home => l10n.eventsTypeHome,
    EventDistribution.gen3 => l10n.eventsTypeGen3,
    EventDistribution.pokemonCenter => l10n.eventsTypePokemonCenter,
  };
}

String shinyRuleName(BuildContext context, EventShiny s) {
  final l10n = context.l10n;
  return switch (s) {
    EventShiny.never => l10n.eventsShinyNever,
    EventShiny.random => l10n.eventsShinyRandom,
    EventShiny.always => l10n.eventsShinyAlways,
    EventShiny.alwaysStar => l10n.eventsShinyStar,
    EventShiny.alwaysSquare => l10n.eventsShinySquare,
    EventShiny.fixed => l10n.eventsShinyFixed,
  };
}

String _gamesText(BuildContext context, EventGift g) {
  final es = context.isSpanish;
  final names = [for (final x in g.games) es ? x.nameEs : x.nameEn];
  return names.isEmpty ? 'Gen ${g.generation}' : names.join(', ').replaceAll('Pokémon ', '');
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.gift, required this.onTap, this.isNew = false});
  final EventGift gift;

  /// Nuevo desde la última vez que se abrió el explorador.
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final g = gift;
    final name = pokemonName(context, g.species, g.form, g.games.firstOrNull);
    final title = g.title.isEmpty ? name : '$name — ${g.title}';
    final langs = g.languages.map((l) => eventLanguageName(l, es: context.isSpanish)).take(3).join(', ');
    final extra = [
      if (g.year != null) '${g.year}',
      if (g.languages.isNotEmpty) g.languages.length > 3 ? l10n.eventsManyLanguages(g.languages.length) : langs,
      if (g.cardId > 0) l10n.eventsCardNo(g.cardId),
    ].join(' · ');
    return ListTile(
      key: ValueKey('event-${g.id}'),
      onTap: onTap,
      leading: SpeciesAvatar(species: g.species, form: g.form, shiny: g.shiny.isShiny, egg: g.isEgg, size: 40),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${l10n.eventsEntry(_gamesText(context, g), g.generation, g.level)}\n$extra',
          maxLines: 2, overflow: TextOverflow.ellipsis),
      isThreeLine: true,
      trailing: isNew || g.shiny.isShiny
          ? Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              if (isNew)
                Text(l10n.eventsNew,
                    key: ValueKey('event-new-${g.id}'),
                    style: context.text.labelSmall!.copyWith(color: context.colors.primary, fontWeight: FontWeight.w800)),
              if (g.shiny.isShiny) const Icon(Icons.auto_awesome_rounded, size: 18),
            ])
          : null,
    );
  }
}

/// Chip de filtro con menú de opciones («Todos» lo quita).
class _FilterChipMenu<T> extends StatelessWidget {
  const _FilterChipMenu({
    required this.keyName,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String keyName;
  final String label;
  final T? value;
  final List<(T, String)> options;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = options.where((o) => o.$1 == value).firstOrNull;
    return PopupMenuButton<Object>(
      key: ValueKey('events-filter-$keyName'),
      tooltip: label,
      onSelected: (v) => onChanged(v == _keep ? null : v as T),
      itemBuilder: (_) => [
        PopupMenuItem<Object>(value: _keep, child: Text(context.l10n.eventsAll)),
        for (final (v, text) in options) PopupMenuItem<Object>(value: v as Object, child: Text(text)),
      ],
      child: Chip(
        avatar: Icon(current == null ? Icons.filter_list_rounded : Icons.check_rounded, size: 16),
        label: Text(current == null ? label : '$label: ${current.$2}'),
        backgroundColor: current == null ? null : context.colors.secondaryContainer,
      ),
    );
  }
}

/// Ficha de un evento con todos sus datos fijos y las acciones posibles.
class EventDetailView extends ConsumerStatefulWidget {
  const EventDetailView({super.key, required this.gift, this.scroll, this.pickFor, this.saveLanguage = 2});
  final EventGift gift;
  final ScrollController? scroll;
  final GameVersion? pickFor;
  final int saveLanguage;

  @override
  ConsumerState<EventDetailView> createState() => _EventDetailViewState();
}

class _EventDetailViewState extends ConsumerState<EventDetailView> {
  bool _shiny = false;
  late int _language = EventFactory.languageFor(widget.gift, widget.saveLanguage);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final g = widget.gift;
    final d = EventDetails.of(g);
    final es = context.isSpanish;
    final lang = es ? DataLanguage.es : DataLanguage.en;
    final game = g.games.firstOrNull;
    final name = pokemonName(context, g.species, g.form, game);
    String date(DateTime x) => formatDate(context, x);

    Widget row(String label, String value, {Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 150, child: Text(label, style: context.text.labelLarge!.copyWith(color: context.tokens.muted))),
            Expanded(child: Text(value)),
          ]),
        );

    final rows = <Widget>[
      row(l10n.eventsFilterType, distributionName(context, g.distribution)),
      if (g.cardId > 0) row(l10n.eventsDetailCard, '${g.cardId}${g.title.isEmpty ? '' : ' · ${g.title}'}'),
      if (g.method != null) row(l10n.eventsDetailMethod, g.method!),
      row(l10n.eventsDetailGames, _gamesText(context, g)),
      if (g.windowStart != null)
        row(
          l10n.eventsDetailDate,
          g.windowEnd == null
              ? l10n.eventsDetailWindowOpen(date(g.windowStart!))
              : l10n.eventsDetailWindow(date(g.windowEnd!), date(g.windowStart!)),
        )
      else if (g.cardDate != null)
        row(l10n.eventsDetailDate, date(g.cardDate!)),
      row(l10n.eventsFilterRegion, g.regions.map((r) => regionName(context, r)).join(', ')),
      row(l10n.eventsFilterLanguage, g.languages.map((x) => eventLanguageName(x, es: es)).join(', ')),
      row(l10n.eventsDetailShiny, shinyRuleName(context, g.shiny)),
      if (g.isEgg) row(l10n.eventsDetailEgg, l10n.yesLabel),
      if (d != null) ...[
        row(l10n.eventsDetailLevel, g.isEgg ? '${d.metLevel}' : '${d.level}'),
        row(l10n.eventsDetailOt, d.otName ?? l10n.eventsDetailOtRecipient),
        row(l10n.eventsDetailId, d.displayId ?? l10n.eventsDetailOtRecipient),
        row(l10n.eventsDetailBall, BallTables.name(d.ball, lang)),
        if (!g.isEgg && g.versions.isNotEmpty)
          row(l10n.eventsDetailLocation, EncounterTables.locationName(g.versions.first, d.metLocation, lang)),
        row(l10n.eventsDetailMoves, d.moves.map((m) => GameStrings.move(m, lang)).join(', ')),
        if (d.relearnMoves.isNotEmpty)
          row(l10n.eventsDetailRelearn, d.relearnMoves.map((m) => GameStrings.move(m, lang)).join(', ')),
        if (d.heldItem != 0) row(l10n.eventsDetailItem, GameStrings.item(d.heldItem, g.generation, lang)),
        row(l10n.eventsDetailNature, d.fixedNature == null ? l10n.eventsDetailRandom : GameStrings.nature(d.fixedNature!, lang)),
        row(
          l10n.eventsDetailIvs,
          d.fixedIvs.every((v) => v == null)
              ? l10n.eventsDetailRandom
              : [
                  for (var i = 0; i < 6; i++)
                    '${Legality.statName(i, lang)} ${d.fixedIvs[i] ?? '?'}',
                ].join(' · '),
        ),
        if (d.ribbons.isNotEmpty)
          row(l10n.eventsDetailRibbons, d.ribbons.map((k) => Ribbons.info(k)?.name(lang) ?? k).join(', ')),
        row(l10n.eventsDetailFateful, d.fateful ? l10n.yesLabel : l10n.no),
      ],
    ];

    final pickFor = widget.pickFor;
    final canCreate = pickFor != null && EventFactory.canCreateIn(g, pickFor);
    final ext = g.cardExtension;
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Row(children: [
          SpeciesAvatar(species: g.species, form: g.form, shiny: g.shiny.isShiny, egg: g.isEgg, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: context.text.headlineSmall),
              Text(l10n.eventsEnded, style: context.text.labelMedium!.copyWith(color: context.tokens.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        ...rows,
        if (!g.canCreate) ...[
          const SizedBox(height: 12),
          Text(g.needsRecipientRng ? l10n.eventsGen3Rng : l10n.eventsNotCreatable(g.error ?? '?'),
              key: const ValueKey('event-not-creatable'),
              style: context.text.bodySmall!.copyWith(color: context.colors.error)),
        ],
        const SizedBox(height: 16),
        if (canCreate) ...[
          if (g.trainerLanguages.length > 1)
            DropdownButtonFormField<int>(
              key: const ValueKey('event-language'),
              initialValue: _language,
              decoration: InputDecoration(labelText: l10n.eventsLanguagePick),
              items: [
                for (final x in g.trainerLanguages)
                  DropdownMenuItem(value: x, child: Text(eventLanguageName(x, es: es))),
              ],
              onChanged: (v) => setState(() => _language = v ?? _language),
            ),
          if (EventFactory.canBeShiny(g) && !g.shiny.isShiny)
            SwitchListTile(
              key: const ValueKey('event-shiny'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.eventsCreateShiny),
              value: _shiny,
              onChanged: (v) => setState(() => _shiny = v),
            ),
          if (!g.games.contains(pickFor))
            Text(l10n.eventsOtherGame(_gamesText(context, g)), style: context.text.bodySmall),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('event-create'),
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: Text(l10n.eventsCreateHere),
            onPressed: () => Navigator.pop<EventChoice>(
                context, (gift: g, shiny: _shiny ? true : null, language: _language)),
          ),
          const SizedBox(height: 8),
        ],
        if (ext != null)
          OutlinedButton.icon(
            key: const ValueKey('event-export'),
            icon: const Icon(Icons.save_alt_rounded),
            label: Text(l10n.eventsExportCard(ext)),
            onPressed: () => _export(context, g),
          ),
      ],
    );
  }

  Future<void> _export(BuildContext context, EventGift g) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final bytes = EventCards.export(g);
    final name = EventCards.fileName(g, speciesName(context, g.species));
    if (bytes == null || name == null) return;
    final path = await ref.read(fileSourcesProvider).exportBytes(name, bytes);
    if (path != null) messenger.showSnackBar(SnackBar(content: Text(l10n.exportDone(path))));
  }
}

/// Pantalla del explorador (desde la Dex o la ficha de especie).
class EventExplorerScreen extends ConsumerStatefulWidget {
  const EventExplorerScreen({super.key, this.species});
  final int? species;

  @override
  ConsumerState<EventExplorerScreen> createState() => _EventExplorerScreenState();
}

class _EventExplorerScreenState extends ConsumerState<EventExplorerScreen> {
  bool _checking = false;

  Future<void> _checkNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _checking = true);
    final r = await ref.read(eventsDataProvider.notifier).checkNow();
    if (!mounted) return;
    setState(() => _checking = false);
    final text = switch (r) {
      EventsCheck.updated => l10n.eventsUpdatedTo(EventDb.all.length),
      EventsCheck.upToDate => l10n.eventsUpToDate,
      EventsCheck.failed => l10n.eventsCheckFailed,
      EventsCheck.none => null,
    };
    if (text != null) messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(eventsDataProvider).value;
    final data = status?.data ?? EventDb.data;
    final muted = context.text.bodySmall!.copyWith(color: context.tokens.muted);
    final commit = data.sourceCommit.length >= 7 ? data.sourceCommit.substring(0, 7) : '?';
    final newCount = status?.newKeys.length ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.eventsTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l10n.eventsSubtitle(EventDb.all.length), style: context.text.bodyMedium!.copyWith(color: context.tokens.muted)),
            const SizedBox(height: 4),
            Text(
              [
                l10n.eventsDataStatus(commit, data.count, formatDate(context, data.generatedAt.toLocal())),
                if (newCount > 0) l10n.eventsNewCount(newCount),
              ].join(' · '),
              key: const ValueKey('events-data-status'),
              style: muted,
            ),
            if (status?.futureSchema != null)
              Text(l10n.eventsFutureSchema,
                  key: const ValueKey('events-future-schema'),
                  style: context.text.bodySmall!.copyWith(color: context.colors.error)),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('events-check'),
                onPressed: _checking || status == null ? null : _checkNow,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(l10n.eventsCheckNew),
              ),
            ),
            Expanded(child: EventExplorer(species: widget.species)),
          ]),
        ),
      ),
    );
  }
}

/// Selector a pantalla completa para «Crear Pokémon → Desde un evento».
abstract final class EventPicker {
  static Future<EventChoice?> show(BuildContext context, GameVersion game, {int saveLanguage = 2}) =>
      Navigator.of(context).push<EventChoice>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(context.l10n.eventsPickTitle)),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: EventExplorer(
                pickFor: game,
                saveLanguage: saveLanguage,
                onPicked: (c) => Navigator.of(context).pop(c),
              ),
            ),
          ),
        ),
      ));
}
