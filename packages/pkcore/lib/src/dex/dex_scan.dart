import 'dart:convert';
import 'dart:typed_data';

import '../detect/save_detector.dart';
import '../edit/save_editor.dart';
import '../model/game.dart';
import '../model/save.dart';
import '../pkm/pkm.dart';
import 'special_forms.dart';

/// Un Pokémon concreto de una partida (equipo o caja), lo justo para la Dex.
class DexSpecimen {
  const DexSpecimen({
    required this.species,
    this.form = 0,
    this.shiny = false,
    this.egg = false,
    this.gigantamax = false,
    this.level = 1,
    this.box = -1,
    this.slot = 0,
    this.heldItem = 0,
    this.nickname,
  });

  final int species;
  final int form;
  final bool shiny;
  final bool egg;

  /// Factor Gigamax (PK8 `CanGigantamax`).
  final bool gigantamax;
  final int level;

  /// Caja (desde 0) o -1 para el equipo.
  final int box;
  final int slot;
  final int heldItem;

  /// Apodo, si lo tiene.
  final String? nickname;

  bool get inParty => box < 0;

  List<Object?> toJson() => [
        species,
        form,
        (shiny ? 1 : 0) | (egg ? 2 : 0) | (gigantamax ? 4 : 0),
        level,
        box,
        slot,
        heldItem,
        if (nickname != null) nickname,
      ];

  static DexSpecimen fromJson(List<dynamic> j) {
    final flags = j[2] as int;
    return DexSpecimen(
      species: j[0] as int,
      form: j[1] as int,
      shiny: flags & 1 != 0,
      egg: flags & 2 != 0,
      gigantamax: flags & 4 != 0,
      level: j[3] as int,
      box: j[4] as int,
      slot: j[5] as int,
      heldItem: j[6] as int,
      nickname: j.length > 7 ? j[7] as String? : null,
    );
  }

  @override
  String toString() => 'DexSpecimen(#$species f$form lv$level${shiny ? ' ★' : ''}${gigantamax ? ' G' : ''} @$box/$slot)';
}

/// Lo que la Dex global necesita de una partida: su Pokédex (vistos,
/// capturados, formas), sus Pokémon y los objetos activadores del inventario.
///
/// Se calcula una vez por copia (por SHA-256) y se cachea en el índice local
/// como JSON compacto ([encode]/[decode]).
class SaveDexScan {
  SaveDexScan({
    required this.game,
    this.versionId,
    this.hasPokedex = false,
    this.seen = const {},
    this.caught = const {},
    this.shinySeen = const {},
    this.formsSeen = const {},
    this.specimens = const [],
    this.items = const {},
  });

  /// Versión del formato de caché: si cambia, se recalcula.
  static const int formatVersion = 1;

  final GameVersion game;
  final int? versionId;

  /// `true` si se pudo leer la Pokédex del juego.
  final bool hasPokedex;
  final Set<int> seen;
  final Set<int> caught;
  final Set<int> shinySeen;

  /// Formas vistas por especie (máscara de bits), si el juego las guarda.
  final Map<int, int> formsSeen;
  final List<DexSpecimen> specimens;

  /// Objetos activadores (piedras, orbes, cristal Z) presentes en el inventario.
  final Set<int> items;

  /// Ids de objeto que interesan a la Dex (activadores de [SpecialForms]).
  static final Set<int> activatorItems = {for (final f in SpecialForms.all) if (f.item != 0) f.item};

  /// Lee la partida. Nunca lanza por partes ilegibles: se queda con lo que pueda.
  static SaveDexScan scan(Uint8List bytes, {int? versionId}) {
    SaveEditor? editor;
    try {
      editor = SaveEditor.open(bytes);
    } catch (_) {
      editor = null;
    }
    if (editor == null) return _fromSummary(SaveDetector.read(bytes));
    final game = editor.game;
    final specimens = <DexSpecimen>[];
    void add(Pkm pk, int box, int slot) {
      try {
        final species = pk.species;
        if (species <= 0 || species > 1025) return;
        final nick = pk.isNicknamed ? pk.nickname : null;
        specimens.add(DexSpecimen(
          species: species,
          form: pk.form,
          shiny: pk.isShiny,
          egg: pk.isEgg,
          gigantamax: game == GameVersion.swordShield && pk.canGigantamax,
          level: pk.level,
          box: box,
          slot: slot,
          heldItem: pk.heldItem,
          nickname: nick,
        ));
      } catch (_) {}
    }

    try {
      final party = editor.party;
      for (var i = 0; i < party.length; i++) {
        add(party[i], -1, i);
      }
    } catch (_) {}
    try {
      for (var b = 0; b < editor.boxCount; b++) {
        for (var s = 0; s < editor.boxSlotCount; s++) {
          Pkm? pk;
          try {
            pk = editor.get(SlotRef.box(b, s));
          } catch (_) {
            pk = null;
          }
          if (pk != null) add(pk, b, s);
        }
      }
    } catch (_) {}

    final items = <int>{};
    try {
      for (final pouch in editor.readInventory() ?? const <InventoryPouch>[]) {
        for (final it in pouch.items) {
          if (it.count > 0 && activatorItems.contains(it.item)) items.add(it.item);
        }
      }
    } catch (_) {}
    // Un activador equipado también cuenta como «en la partida».
    for (final s in specimens) {
      if (activatorItems.contains(s.heldItem)) items.add(s.heldItem);
    }

    final seen = <int>{}, caught = <int>{}, shiny = <int>{};
    final forms = <int, int>{};
    var hasDex = false;
    try {
      final dex = editor.pokedex;
      if (dex != null) {
        for (final s in dex.species) {
          if (s > 1025) continue;
          if (dex.isSeen(s)) seen.add(s);
          if (dex.isCaught(s)) caught.add(s);
          if (dex.hasShiny && dex.isShinySeen(s)) shiny.add(s);
          if (dex.hasForms && dex.formCount(s) > 1) {
            final m = dex.formMask(s);
            if (m != 0) forms[s] = m;
          }
        }
        hasDex = true;
      }
    } catch (_) {
      hasDex = false;
    }
    return SaveDexScan(
      game: game,
      versionId: versionId,
      hasPokedex: hasDex,
      seen: seen,
      caught: caught,
      shinySeen: shiny,
      formsSeen: forms,
      specimens: specimens,
      items: items,
    );
  }

  static SaveDexScan _fromSummary(SaveFile s) => SaveDexScan(
        game: s.game,
        versionId: s.versionId,
        specimens: [
          for (final (i, p) in s.party.indexed)
            DexSpecimen(species: p.species, form: p.form, shiny: p.isShiny, egg: p.isEgg, level: p.level, slot: i, heldItem: p.heldItem),
          for (final b in s.boxes)
            for (final (i, p) in b.slots.indexed)
              if (p != null)
                DexSpecimen(
                    species: p.species,
                    form: p.form,
                    shiny: p.isShiny,
                    egg: p.isEgg,
                    level: p.level,
                    box: b.index,
                    slot: i,
                    heldItem: p.heldItem),
        ],
      );

  Map<String, Object?> toJson() => {
        'v': formatVersion,
        'g': game.code,
        if (versionId != null) 'vid': versionId,
        'd': hasPokedex,
        's': _ranges(seen),
        'c': _ranges(caught),
        'sh': _ranges(shinySeen),
        'f': {for (final e in formsSeen.entries) '${e.key}': e.value},
        'p': [for (final s in specimens) s.toJson()],
        'i': items.toList()..sort(),
      };

  String encode() => jsonEncode(toJson());

  /// Lee una caché. Devuelve null si es de otra versión o está dañada.
  static SaveDexScan? decode(String json) {
    try {
      final j = jsonDecode(json) as Map<String, dynamic>;
      if (j['v'] != formatVersion) return null;
      final game = GameVersion.fromCode(j['g'] as String);
      if (game == null) return null;
      return SaveDexScan(
        game: game,
        versionId: j['vid'] as int?,
        hasPokedex: j['d'] as bool? ?? false,
        seen: _unranges(j['s']),
        caught: _unranges(j['c']),
        shinySeen: _unranges(j['sh']),
        formsSeen: {for (final e in (j['f'] as Map<String, dynamic>).entries) int.parse(e.key): e.value as int},
        specimens: [for (final p in j['p'] as List<dynamic>) DexSpecimen.fromJson(p as List<dynamic>)],
        items: {for (final i in j['i'] as List<dynamic>) i as int},
      );
    } catch (_) {
      return null;
    }
  }

  /// Conjunto de enteros como rangos «1-151,250» (compacto para Pokédex completas).
  static String _ranges(Set<int> set) {
    if (set.isEmpty) return '';
    final l = set.toList()..sort();
    final out = <String>[];
    var start = l.first, prev = l.first;
    for (final v in l.skip(1)) {
      if (v == prev + 1) {
        prev = v;
        continue;
      }
      out.add(start == prev ? '$start' : '$start-$prev');
      start = prev = v;
    }
    out.add(start == prev ? '$start' : '$start-$prev');
    return out.join(',');
  }

  static Set<int> _unranges(Object? s) {
    if (s is! String || s.isEmpty) return {};
    final out = <int>{};
    for (final part in s.split(',')) {
      final dash = part.indexOf('-');
      if (dash < 0) {
        out.add(int.parse(part));
      } else {
        final a = int.parse(part.substring(0, dash)), b = int.parse(part.substring(dash + 1));
        for (var v = a; v <= b; v++) {
          out.add(v);
        }
      }
    }
    return out;
  }
}
