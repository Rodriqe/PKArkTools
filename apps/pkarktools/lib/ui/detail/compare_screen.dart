import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkcore/pkcore.dart';

import '../../data/db/arca_database.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../common/species_avatar.dart';
import '../editor/pickers.dart';

/// Resultado de comparar dos snapshots.
class SnapshotComparison {
  const SnapshotComparison(this.before, this.after, this.diff, this.boxNames);
  final Snapshot before;
  final Snapshot after;
  final SaveDiff diff;
  final List<String> boxNames;
}

final _comparisonProvider = FutureProvider.autoDispose
    .family<SnapshotComparison, (int, int, DataLanguage)>((ref, args) async {
  final repo = ref.watch(arcaRepositoryProvider);
  final a = await repo.snapshot(args.$1);
  final b = await repo.snapshot(args.$2);
  final ea = SaveEditor.open(await repo.snapshotBytes(a));
  final eb = SaveEditor.open(await repo.snapshotBytes(b));
  return SnapshotComparison(
      a, b, SaveDiff.compare(ea, eb, lang: args.$3), [for (var i = 0; i < eb.boxCount; i++) eb.boxName(i)]);
});

/// Diferencias entre dos copias de la misma partida.
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key, required this.beforeId, required this.afterId, required this.game});
  final int beforeId;
  final int afterId;
  final GameVersion game;

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  late int _a = widget.beforeId;
  late int _b = widget.afterId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 720 ? 16.0 : 32.0;
    final async = ref.watch(_comparisonProvider((_a, _b, context.dataLang)));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.compareTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.loadError('$e'))),
        data: (c) => ListView(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 80),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: _Body(
                  c: c,
                  game: widget.game,
                  onSwap: () => setState(() {
                    final t = _a;
                    _a = _b;
                    _b = t;
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.c, required this.game, required this.onSwap});
  final SnapshotComparison c;
  final GameVersion game;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final d = c.diff;
    final total = d.trainer.length + d.mons.length + d.items.length + d.dex.length;
    final party = d.party.toList();
    final boxes = d.boxes.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Header(before: c.before, after: c.after, onSwap: onSwap),
      const SizedBox(height: 18),
      Text(d.isEmpty ? l10n.compareIdentical : l10n.compareSummary(total),
          style: context.text.titleMedium!.copyWith(color: tokens.muted)),
      if (d.trainer.isNotEmpty) ...[
        _Title(l10n.compareTrainer, d.trainer.length),
        _FieldTable(fields: d.trainer),
      ],
      if (party.isNotEmpty) ...[
        _Title(l10n.compareParty, party.length),
        for (final m in party) _MonCard(diff: m, boxNames: c.boxNames),
      ],
      if (boxes.isNotEmpty) ...[
        _Title(l10n.compareBoxes, boxes.length),
        for (final m in boxes) _MonCard(diff: m, boxNames: c.boxNames),
      ],
      if (d.items.isNotEmpty) ...[
        _Title(l10n.compareInventory, d.items.length),
        _Items(items: d.items, game: game),
      ],
      if (d.dex.isNotEmpty) ...[
        _Title(l10n.comparePokedex, d.dex.length),
        _Dex(dex: d.dex),
      ],
    ]);
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, this.count);
  final String text;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 32, bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(text, style: context.text.headlineSmall),
          const SizedBox(width: 10),
          Text('$count', style: context.text.titleMedium!.copyWith(color: context.tokens.muted)),
        ]),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.before, required this.after, required this.onSwap});
  final Snapshot before;
  final Snapshot after;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    Widget side(String label, Snapshot s, CrossAxisAlignment align) => Expanded(
          child: Column(crossAxisAlignment: align, children: [
            Text(label, style: context.text.labelLarge!.copyWith(color: tokens.muted)),
            const SizedBox(height: 4),
            Text(formatDate(context, s.importedAt, withTime: true),
                textAlign: align == CrossAxisAlignment.end ? TextAlign.end : TextAlign.start, style: context.text.titleLarge),
            const SizedBox(height: 2),
            Text('${formatPlayTime(Duration(seconds: s.playTimeSeconds))}  ${s.sha256.substring(0, 8)}',
                style: context.text.bodySmall!.copyWith(color: tokens.muted, fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(color: tokens.raised, borderRadius: BorderRadius.circular(22), border: Border.all(color: tokens.hairline)),
      child: Row(children: [
        side(l10n.compareBefore, before, CrossAxisAlignment.start),
        IconButton.filledTonal(tooltip: l10n.compareSwap, onPressed: onSwap, icon: const Icon(Icons.swap_horiz_rounded)),
        side(l10n.compareAfter, after, CrossAxisAlignment.end),
      ]),
    );
  }
}

String fieldLabel(BuildContext context, String field) {
  final l = context.l10n;
  return switch (field) {
    'name' => l.fieldName,
    'tid' => l.fieldTid,
    'sid' => l.fieldSid,
    'money' => l.fieldMoney,
    'playTime' => l.fieldPlayTime,
    'gender' => l.fieldGender,
    'species' => l.fieldSpecies,
    'form' => l.fieldForm,
    'nickname' => l.fieldNickname,
    'level' => l.fieldLevel,
    'exp' => l.fieldExp,
    'moves' => l.fieldMoves,
    'item' => l.fieldItem,
    'ability' => l.fieldAbility,
    'nature' => l.fieldNature,
    'ivs' => l.fieldIvs,
    'evs' => l.fieldEvs,
    'shiny' => l.fieldShiny,
    'ball' => l.fieldBall,
    'friendship' => l.fieldFriendship,
    _ => field,
  };
}

class _FieldTable extends StatelessWidget {
  const _FieldTable({required this.fields});
  final List<FieldChange> fields;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(children: [
      for (final f in fields)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 130, child: Text(fieldLabel(context, f.field), style: context.text.bodyMedium!.copyWith(color: tokens.muted))),
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(
                    text: f.before,
                    style: TextStyle(color: tokens.muted, decoration: TextDecoration.lineThrough, decorationColor: tokens.muted)),
                const TextSpan(text: '   '),
                TextSpan(text: f.after, style: const TextStyle(fontWeight: FontWeight.w700)),
              ]), style: context.text.bodyMedium),
            ),
          ]),
        ),
    ]);
  }
}

class _MonCard extends StatelessWidget {
  const _MonCard({required this.diff, required this.boxNames});
  final MonDiff diff;
  final List<String> boxNames;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final m = diff.mon;
    String slot(SlotRef r) => r.isParty ? l10n.slotParty(r.slot + 1) : l10n.slotBox(r.box < boxNames.length ? boxNames[r.box] : '${r.box + 1}', r.slot + 1);
    final (label, color, icon) = switch (diff.kind) {
      MonChangeKind.added => (l10n.compareAdded, const Color(0xFF52C98A), Icons.login_rounded),
      MonChangeKind.removed => (l10n.compareRemoved, context.colors.error, Icons.logout_rounded),
      MonChangeKind.changed => (l10n.compareChanged, const Color(0xFFF0A23B), Icons.edit_rounded),
      MonChangeKind.moved => (l10n.compareMoved, context.colors.primary, Icons.open_with_rounded),
    };
    final where = switch (diff.kind) {
      MonChangeKind.added => slot(diff.to!),
      MonChangeKind.removed => slot(diff.from!),
      MonChangeKind.changed => slot(diff.to!),
      MonChangeKind.moved => '${slot(diff.from!)}  ⟶  ${slot(diff.to!)}',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: BoxDecoration(
        color: tokens.raised,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Opacity(
          opacity: diff.kind == MonChangeKind.removed ? 0.5 : 1,
          child: SpeciesAvatar(species: m.species, shiny: m.isShiny, egg: m.isEgg, size: 52),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(m.isNicknamed ? m.nickname : speciesName(context, m.species), style: context.text.titleMedium),
              Text(l10n.level(m.level), style: context.text.bodyMedium!.copyWith(color: tokens.muted)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 5),
                  Text(label, style: context.text.labelMedium!.copyWith(color: color)),
                ]),
              ),
            ]),
            const SizedBox(height: 4),
            Text(where, style: context.text.bodySmall!.copyWith(color: tokens.muted)),
            if (diff.fields.isNotEmpty) ...[
              const SizedBox(height: 8),
              _FieldTable(fields: diff.fields),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Items extends StatelessWidget {
  const _Items({required this.items, required this.game});
  final List<ItemDiff> items;
  final GameVersion game;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Wrap(spacing: 10, runSpacing: 10, children: [
      for (final it in items)
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(color: tokens.raised, borderRadius: BorderRadius.circular(14), border: Border.all(color: tokens.hairline)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(GameStrings.item(it.item, game.generation, context.dataLang), style: context.text.bodyMedium),
            const SizedBox(width: 10),
            Text(
              '${it.before} → ${it.after}',
              style: context.text.labelLarge!.copyWith(
                  color: it.after > it.before ? const Color(0xFF52C98A) : context.colors.error,
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ]),
        ),
    ]);
  }
}

class _Dex extends StatelessWidget {
  const _Dex({required this.dex});
  final List<DexDiff> dex;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    int score(DexEntry e) => (e.seen ? 1 : 0) + (e.caught ? 1 : 0) + (e.shiny ? 1 : 0);
    final gained = dex.where((d) => score(d.after) > score(d.before)).toList();
    final lost = dex.where((d) => score(d.after) < score(d.before)).toList();
    Widget chips(List<DexDiff> list) => Wrap(spacing: 6, runSpacing: 6, children: [
          for (final d in list.take(60))
            Chip(
              avatar: SpeciesAvatar(species: d.after.species, size: 24),
              label: Text(speciesName(context, d.after.species)),
              visualDensity: VisualDensity.compact,
            ),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (gained.isNotEmpty) ...[
        Text(l10n.compareDexGained(gained.length), style: context.text.titleSmall),
        const SizedBox(height: 8),
        chips(gained),
        const SizedBox(height: 16),
      ],
      if (lost.isNotEmpty) ...[
        Text(l10n.compareDexLost(lost.length), style: context.text.titleSmall!.copyWith(color: tokens.muted)),
        const SizedBox(height: 8),
        chips(lost),
      ],
    ]);
  }
}
