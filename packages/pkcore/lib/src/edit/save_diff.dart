import '../data/game_data.dart';
import '../pkm/pkm.dart';
import 'pokedex.dart';
import 'save_editor.dart';

/// Un campo que cambió entre dos copias (valores ya formateados para mostrar).
class FieldChange {
  const FieldChange(this.field, this.before, this.after);

  /// Clave estable: `name`, `money`, `species`, `level`, `moves`, `item`…
  final String field;
  final String before;
  final String after;

  @override
  String toString() => '$field: $before → $after';
}

enum MonChangeKind { added, removed, changed, moved }

/// Cambio de un Pokémon entre dos copias.
class MonDiff {
  const MonDiff(this.kind, {this.before, this.after, this.from, this.to, this.fields = const []});
  final MonChangeKind kind;
  final Pkm? before;
  final Pkm? after;
  final SlotRef? from;
  final SlotRef? to;
  final List<FieldChange> fields;

  Pkm get mon => (after ?? before)!;
}

/// Cambio de cantidad de un objeto.
class ItemDiff {
  const ItemDiff(this.pouch, this.item, this.before, this.after);
  final String pouch;
  final int item;
  final int before;
  final int after;
}

/// Cambio de un registro de la Pokédex.
class DexDiff {
  const DexDiff(this.before, this.after);
  final DexEntry before;
  final DexEntry after;
}

/// Diferencias entre dos copias del mismo save ([a] = antes, [b] = después).
class SaveDiff {
  const SaveDiff({required this.trainer, required this.mons, required this.items, required this.dex});

  final List<FieldChange> trainer;
  final List<MonDiff> mons;
  final List<ItemDiff> items;
  final List<DexDiff> dex;

  bool get isEmpty => trainer.isEmpty && mons.isEmpty && items.isEmpty && dex.isEmpty;

  Iterable<MonDiff> get party => mons.where((m) => (m.to ?? m.from)!.isParty);
  Iterable<MonDiff> get boxes => mons.where((m) => !(m.to ?? m.from)!.isParty);

  static SaveDiff compare(SaveEditor a, SaveEditor b, {DataLanguage lang = DataLanguage.es}) => SaveDiff(
        trainer: _trainer(a, b),
        mons: _mons(a, b, lang),
        items: _items(a, b),
        dex: _dex(a, b),
      );

  static String _time(Duration d) =>
      '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  static List<FieldChange> _trainer(SaveEditor a, SaveEditor b) {
    final ta = a.readTrainer(), tb = b.readTrainer();
    return [
      if (ta.name != tb.name) FieldChange('name', ta.name, tb.name),
      if (ta.tid != tb.tid) FieldChange('tid', '${ta.tid}', '${tb.tid}'),
      if (ta.sid != tb.sid) FieldChange('sid', '${ta.sid}', '${tb.sid}'),
      if (ta.money != tb.money) FieldChange('money', '${ta.money}', '${tb.money}'),
      if (ta.playTime != tb.playTime) FieldChange('playTime', _time(ta.playTime), _time(tb.playTime)),
      if (ta.gender != tb.gender) FieldChange('gender', '${ta.gender}', '${tb.gender}'),
    ];
  }

  /// Identidad estable de un Pokémon entre copias.
  static String _identity(Pkm p) {
    if (p.format.isGameBoy) {
      // Sin PID: DVs + OT + especie original del hueco.
      return 'gb:${p.tid}:${p.otName}:${p.ivs.join('.')}:${p.species}';
    }
    final ec = p.format.hasEncryptionConstant ? p.encryptionConstant : 0;
    return '${p.pid}:$ec:${p.tid}:${p.sid}';
  }

  static List<(SlotRef, Pkm)> _all(SaveEditor e) => [
        if (e.canEditStorage) ...[
          for (var i = 0; i < e.partyCount; i++) (SlotRef.party(i), e.get(SlotRef.party(i))!),
          for (var bx = 0; bx < e.boxCount; bx++)
            for (var s = 0; s < e.boxSlotCount; s++)
              if (e.get(SlotRef.box(bx, s)) case final p?) (SlotRef.box(bx, s), p),
        ],
      ];

  static List<MonDiff> _mons(SaveEditor a, SaveEditor b, DataLanguage lang) {
    final before = <String, List<(SlotRef, Pkm)>>{};
    for (final e in _all(a)) {
      before.putIfAbsent(_identity(e.$2), () => []).add(e);
    }
    final out = <MonDiff>[];
    for (final (ref, pk) in _all(b)) {
      final list = before[_identity(pk)];
      if (list == null || list.isEmpty) {
        out.add(MonDiff(MonChangeKind.added, after: pk, to: ref));
        continue;
      }
      final idx = list.indexWhere((e) => e.$1 == ref);
      final (oldRef, old) = list.removeAt(idx < 0 ? 0 : idx);
      final fields = monFields(old, pk, lang);
      if (oldRef != ref) {
        out.add(MonDiff(MonChangeKind.moved, before: old, after: pk, from: oldRef, to: ref, fields: fields));
      } else if (fields.isNotEmpty) {
        out.add(MonDiff(MonChangeKind.changed, before: old, after: pk, from: oldRef, to: ref, fields: fields));
      }
    }
    for (final list in before.values) {
      for (final (ref, pk) in list) {
        out.add(MonDiff(MonChangeKind.removed, before: pk, from: ref));
      }
    }
    return out;
  }

  /// Campos que difieren entre dos versiones del mismo Pokémon.
  static List<FieldChange> monFields(Pkm a, Pkm b, [DataLanguage lang = DataLanguage.es]) {
    final gen = a.format.generation;
    String moves(Pkm p) => [for (final m in p.moves) if (m != 0) GameStrings.move(m, lang)].join(', ');
    String stats(List<int> v) => v.join('/');
    return [
      if (a.species != b.species) FieldChange('species', GameStrings.species(a.species, lang), GameStrings.species(b.species, lang)),
      if (a.form != b.form) FieldChange('form', '${a.form}', '${b.form}'),
      if (a.nickname != b.nickname) FieldChange('nickname', a.nickname, b.nickname),
      if (a.level != b.level) FieldChange('level', '${a.level}', '${b.level}'),
      if (a.level == b.level && a.exp != b.exp) FieldChange('exp', '${a.exp}', '${b.exp}'),
      if (moves(a) != moves(b)) FieldChange('moves', moves(a), moves(b)),
      if (a.heldItem != b.heldItem)
        FieldChange('item', a.heldItem == 0 ? '—' : GameStrings.item(a.heldItem, gen, lang),
            b.heldItem == 0 ? '—' : GameStrings.item(b.heldItem, gen, lang)),
      if (gen >= 3 && a.ability != b.ability)
        FieldChange('ability', GameStrings.ability(a.ability, lang), GameStrings.ability(b.ability, lang)),
      if (gen >= 3 && a.nature != b.nature) FieldChange('nature', GameStrings.nature(a.nature, lang), GameStrings.nature(b.nature, lang)),
      if (stats(a.ivs) != stats(b.ivs)) FieldChange('ivs', stats(a.ivs), stats(b.ivs)),
      if (stats(a.evs) != stats(b.evs)) FieldChange('evs', stats(a.evs), stats(b.evs)),
      if (a.isShiny != b.isShiny) FieldChange('shiny', a.isShiny ? '✦' : '—', b.isShiny ? '✦' : '—'),
      if (gen >= 3 && a.ball != b.ball) FieldChange('ball', '${a.ball}', '${b.ball}'),
      if (a.friendship != b.friendship) FieldChange('friendship', '${a.friendship}', '${b.friendship}'),
    ];
  }

  static List<ItemDiff> _items(SaveEditor a, SaveEditor b) {
    final ia = a.readInventory(), ib = b.readInventory();
    if (ia == null || ib == null) return const [];
    Map<(String, int), int> flat(List<InventoryPouch> ps) => {
          for (final p in ps)
            for (final it in p.items) (p.type, it.item): it.count,
        };
    final fa = flat(ia), fb = flat(ib);
    return [
      for (final k in {...fa.keys, ...fb.keys})
        if ((fa[k] ?? 0) != (fb[k] ?? 0)) ItemDiff(k.$1, k.$2, fa[k] ?? 0, fb[k] ?? 0),
    ];
  }

  static List<DexDiff> _dex(SaveEditor a, SaveEditor b) {
    final da = a.pokedex, db = b.pokedex;
    if (da == null || db == null) return const [];
    return [
      for (final s in da.species)
        if (da.entry(s) != db.entry(s)) DexDiff(da.entry(s), db.entry(s)),
    ];
  }
}
