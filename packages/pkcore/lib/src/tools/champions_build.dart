import '../data/forms.dart';
import '../model/game.dart';
import '../pkm/pkm.dart';
import 'champions.dart';
import 'champions_dex.dart';
import 'showdown.dart';

/// Un Pokémon preparado para Pokémon Champions: especie (y Mega), naturaleza,
/// puntos de estadística, habilidad, objeto y movimientos. Lo usan la
/// calculadora de estadísticas, la de daño y los equipos.
class ChampionsBuild {
  ChampionsBuild({
    required this.speciesId,
    this.megaId = '',
    this.nickname = '',
    this.nature = 0,
    List<int>? sp,
    this.ability = '',
    this.item = '',
    List<String>? moves,
  }) : sp = sp ?? List<int>.filled(6, 0),
       moves = moves ?? <String>[];

  /// Id de Showdown de la especie o forma (`garchomp`, `rotomwash`).
  String speciesId;

  /// Id de la Mega en uso (vacío = sin megaevolucionar).
  String megaId;
  String nickname;

  /// Naturaleza (id de PKArkTools, 0 = Fuerte).
  int nature;

  /// Puntos de estadística (PS … Vel).
  List<int> sp;

  /// Ids de Showdown.
  String ability;
  String item;
  List<String> moves;

  ChampionsSpecies? get species => ChampionsDex.species(speciesId);
  ChampionsSpecies? get mega => megaId.isEmpty ? null : ChampionsDex.species(megaId);

  /// La forma con la que combate (la Mega si está activada).
  ChampionsSpecies? get battleSpecies => mega ?? species;

  List<int> get stats {
    final s = battleSpecies;
    if (s == null) return List.filled(6, 0);
    return ChampionsStats.all(base: s.baseStats, sp: sp, nature: nature, shedinja: s.num == 292);
  }

  /// Habilidad en combate: la Mega tiene la suya.
  String get battleAbility {
    final m = mega;
    if (m != null && m.abilities.isNotEmpty) return m.abilities.first;
    return ability;
  }

  ChampionsBuild copy() => ChampionsBuild(
    speciesId: speciesId,
    megaId: megaId,
    nickname: nickname,
    nature: nature,
    sp: [...sp],
    ability: ability,
    item: item,
    moves: [...moves],
  );

  Map<String, Object?> toJson() => {
    'species': speciesId,
    if (megaId.isNotEmpty) 'mega': megaId,
    if (nickname.isNotEmpty) 'nickname': nickname,
    'nature': Showdown.natureName(nature),
    'sp': sp,
    if (ability.isNotEmpty) 'ability': ability,
    if (item.isNotEmpty) 'item': item,
    'moves': moves,
  };

  static ChampionsBuild fromJson(Map<String, Object?> j) {
    final sp = j['sp'];
    return ChampionsBuild(
      speciesId: j['species'] is String ? j['species']! as String : '',
      megaId: j['mega'] is String ? j['mega']! as String : '',
      nickname: j['nickname'] is String ? j['nickname']! as String : '',
      nature: Showdown.natureId(j['nature'] is String ? j['nature']! as String : '') ?? 0,
      sp: sp is List && sp.length == 6 && sp.every((v) => v is int) ? sp.cast<int>().toList() : null,
      ability: j['ability'] is String ? j['ability']! as String : '',
      item: j['item'] is String ? j['item']! as String : '',
      moves: [
        if (j['moves'] case final List<Object?> l)
          for (final m in l.take(4))
            if (m is String) m,
      ],
    );
  }

  /// Avisos del set con la regulación vigente (vacío = sin problemas).
  List<String> problems({required bool es}) {
    final s = species;
    if (s == null) return [es ? 'Especie sin datos de Champions: $speciesId.' : 'No Champions data for $speciesId.'];
    final out = <String>[];
    final key = s.key;
    if (key != null) {
      for (final r in ChampionsFormat.speciesReasons(key.$1, key.$2)) {
        out.add(ChampionsEligibility.reasonText(r, es: es));
      }
    }
    out.addAll(ChampionsStats.problems(sp, es: es));
    final m = mega;
    if (m != null) {
      if (!ChampionsFormat.data.megaIds.contains(m.id)) {
        out.add(es ? '${m.name} no está en la regulación vigente.' : '${m.name} is not in the current regulation.');
      }
      if (item != m.megaStone) {
        final stone = ChampionsDex.item(m.megaStone)?.name ?? m.megaStone;
        out.add(es ? 'Para megaevolucionar necesita $stone.' : 'It needs $stone to Mega Evolve.');
      }
    }
    for (final id in moves) {
      if (!ChampionsDex.canLearn(s, id)) {
        final n = ChampionsDex.move(id)?.name ?? id;
        out.add(es ? 'No puede aprender $n en Champions.' : 'It cannot learn $n in Champions.');
      }
    }
    if (ability.isNotEmpty && !s.abilities.contains(ability)) {
      out.add(es ? 'Habilidad no disponible para la especie.' : 'Ability not available for this species.');
    }
    if (item.isNotEmpty && ChampionsDex.item(item) == null) {
      out.add(es ? 'Objeto que no existe en Champions.' : 'Item that does not exist in Champions.');
    }
    return out;
  }

  /// Texto de Showdown (formato de Champions: los puntos van en «EVs:»).
  String toShowdown() {
    final s = species;
    final b = StringBuffer();
    final name = s?.name ?? speciesId;
    b.write(nickname.isNotEmpty && nickname != name ? '$nickname ($name)' : name);
    final it = ChampionsDex.item(item);
    if (it != null) b.write(' @ ${it.name}');
    b.writeln();
    final ab = ChampionsDex.ability(ability);
    if (ab != null) b.writeln('Ability: ${ab.name}');
    b.writeln('Level: ${ChampionsStats.level}');
    const labels = ['HP', 'Atk', 'Def', 'SpA', 'SpD', 'Spe'];
    final evs = [
      for (var i = 0; i < 6; i++)
        if (sp[i] > 0) '${sp[i]} ${labels[i]}',
    ];
    if (evs.isNotEmpty) b.writeln('EVs: ${evs.join(' / ')}');
    b.writeln('${Showdown.natureName(nature)} Nature');
    for (final id in moves) {
      final m = ChampionsDex.move(id);
      if (m != null) b.writeln('- ${m.name}');
    }
    return b.toString().trimRight();
  }

  static String teamToShowdown(Iterable<ChampionsBuild> team) => team.map((b) => b.toShowdown()).join('\n\n');

  /// Convierte un set de Showdown. Si la línea «EVs:» parece de EVs clásicos
  /// (algún valor > 32 o total > 66), se convierte a puntos con
  /// [ChampionsStats.spFromEv] y [convertedEvs] lo indica.
  static ({ChampionsBuild build, bool convertedEvs})? fromShowdown(ShowdownSet set) {
    final id = ChampionsDex.toId(set.speciesText);
    var s = ChampionsDex.species(id);
    var megaId = '';
    if (s != null && s.isMega) {
      megaId = s.id;
      s = ChampionsDex.species(s.megaOf);
    }
    if (s == null) {
      for (final g in const [GameVersion.scarletViolet, GameVersion.legendsZA]) {
        final r = Showdown.resolveSpecies(set.speciesText, g);
        if (r != null) {
          s = ChampionsDex.byKey(r.species, r.form) ??
              (SpeciesForms.formsDiffer(r.species, 0, r.form, g) ? null : ChampionsDex.byKey(r.species, 0));
          if (s != null) break;
        }
      }
    }
    if (s == null) return null;
    final raw = [for (var i = 0; i < 6; i++) set.evs[i] ?? 0];
    final classic = raw.any((v) => v > ChampionsStats.maxPerStat) || raw.fold(0, (a, b) => a + b) > ChampionsStats.maxTotal;
    final item = ChampionsDex.toId(set.item ?? '');
    // Con la megapiedra de la especie se activa su Mega.
    if (megaId.isEmpty) {
      for (final m in ChampionsDex.megasOf(s)) {
        if (m.megaStone == item) megaId = m.id;
      }
    }
    return (
      build: ChampionsBuild(
        speciesId: s.id,
        megaId: megaId,
        nickname: set.nickname ?? '',
        nature: Showdown.natureId(set.nature ?? '') ?? 0,
        sp: classic ? raw.map(ChampionsStats.spFromEv).toList() : raw,
        ability: ChampionsDex.toId(set.ability ?? ''),
        item: item,
        moves: [for (final m in set.moves.take(4)) ChampionsDex.toId(m.replaceAll(RegExp(r'\[.*\]'), ''))],
      ),
      convertedEvs: classic,
    );
  }

  /// Un Pokémon de una partida convertido a las reglas de Champions: especie
  /// y forma, naturaleza (la de estadísticas), habilidad, objeto y
  /// movimientos que existan en Champions, y los EVs pasados a puntos con
  /// [ChampionsStats.spFromEv] (misma estadística a nivel 50 con IVs 31; no
  /// es la regla oficial de HOME). null si la especie no tiene datos.
  static ChampionsBuild? fromPkm(Pkm pk) {
    final s = ChampionsDex.byKey(pk.species, pk.form) ?? ChampionsDex.byKey(pk.species, 0);
    if (s == null) return null;
    String byNum<T>(Iterable<T> all, int Function(T) num, String Function(T) id, int n) {
      if (n <= 0) return '';
      for (final x in all) {
        if (num(x) == n) return id(x);
      }
      return '';
    }

    final ability = byNum(ChampionsDex.allAbilities, (a) => a.num, (a) => a.id, pk.ability);
    final learn = {for (final m in ChampionsDex.learnset(s)) m.num: m.id};
    final item = byNum(ChampionsDex.allItems, (i) => i.num, (i) => i.id, pk.heldItem);
    return ChampionsBuild(
      speciesId: s.id,
      nickname: pk.nickname,
      nature: pk.statNature,
      sp: [for (final e in pk.evs) ChampionsStats.spFromEv(e)],
      ability: s.abilities.contains(ability) ? ability : (s.abilities.isEmpty ? '' : s.abilities.first),
      item: item,
      moves: [
        for (final m in pk.moves)
          if (learn[m] != null) learn[m]!,
      ],
    );
  }
}
