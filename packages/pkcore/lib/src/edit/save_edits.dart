import 'dart:typed_data';

import '../data/species.dart';
import '../model/save.dart';
import '../pkm/pkm.dart';
import '../write/save_writer.dart';
import 'pokedex.dart';
import 'save_editor.dart';

/// Tipo de edición (para que la interfaz genere descripciones localizadas).
enum SaveEditKind { setSlot, clearSlot, swapSlots, trainer, inventory, boxName, pokedex, events }

/// Edición aplicable sobre un [SaveEditor]. Inmutable: guarda copias de los datos.
sealed class SaveEditOp implements SaveEdit {
  const SaveEditOp();

  SaveEditKind get kind;
  void applyTo(SaveEditor editor);
}

/// Coloca (o sustituye) un Pokémon en un hueco.
class SetSlotEdit extends SaveEditOp {
  SetSlotEdit(this.ref, Pkm pk, {this.label}) : pk = pk.clone();

  final SlotRef ref;
  final Pkm pk;

  /// Texto opcional (p. ej. "importado de archivo").
  final String? label;

  @override
  SaveEditKind get kind => SaveEditKind.setSlot;

  @override
  void applyTo(SaveEditor editor) => editor.set(ref, pk.clone());

  @override
  String get description => '${label ?? 'Editado'}: ${Species.name(pk.species)} ($ref)';
}

/// Vacía un hueco (en el equipo, compacta).
class ClearSlotEdit extends SaveEditOp {
  const ClearSlotEdit(this.ref, {this.species = 0});

  final SlotRef ref;
  final int species;

  @override
  SaveEditKind get kind => SaveEditKind.clearSlot;

  @override
  void applyTo(SaveEditor editor) => editor.set(ref, null);

  @override
  String get description => 'Borrado: ${species > 0 ? Species.name(species) : 'Pokémon'} ($ref)';
}

/// Intercambia dos huecos (mover a vacío = mover).
class SwapSlotsEdit extends SaveEditOp {
  const SwapSlotsEdit(this.from, this.to);

  final SlotRef from;
  final SlotRef to;

  @override
  SaveEditKind get kind => SaveEditKind.swapSlots;

  @override
  void applyTo(SaveEditor editor) => editor.swap(from, to);

  @override
  String get description => 'Movido $from → $to';
}

class SetTrainerEdit extends SaveEditOp {
  const SetTrainerEdit(this.trainer);
  final TrainerData trainer;

  @override
  SaveEditKind get kind => SaveEditKind.trainer;

  @override
  void applyTo(SaveEditor editor) => editor.writeTrainer(trainer);

  @override
  String get description => 'Entrenador actualizado';
}

class SetInventoryEdit extends SaveEditOp {
  SetInventoryEdit(List<InventoryPouch> pouches) : pouches = List.unmodifiable(pouches);
  final List<InventoryPouch> pouches;

  @override
  SaveEditKind get kind => SaveEditKind.inventory;

  @override
  void applyTo(SaveEditor editor) => editor.writeInventory(pouches);

  @override
  String get description => 'Inventario actualizado';
}

class SetBoxNameEdit extends SaveEditOp {
  const SetBoxNameEdit(this.box, this.name);
  final int box;
  final String name;

  @override
  SaveEditKind get kind => SaveEditKind.boxName;

  @override
  void applyTo(SaveEditor editor) => editor.setBoxName(box, name);

  @override
  String get description => 'Caja ${box + 1} renombrada a "$name"';
}

/// Acción masiva sobre la Pokédex.
enum PokedexBulk { none, completeAll, completeAllShiny, clearAll }

/// Cambia registros de la Pokédex (por especie o en bloque).
class PokedexEdit extends SaveEditOp {
  PokedexEdit(List<DexEntry> entries) : entries = List.unmodifiable(entries), bulk = PokedexBulk.none;
  const PokedexEdit.bulk(this.bulk) : entries = const [];

  final List<DexEntry> entries;
  final PokedexBulk bulk;

  @override
  SaveEditKind get kind => SaveEditKind.pokedex;

  @override
  void applyTo(SaveEditor editor) {
    final dex = editor.pokedex;
    if (dex == null) throw const SaveEditException('Este juego no tiene editor de Pokédex.');
    switch (bulk) {
      case PokedexBulk.completeAll:
        dex.completeAll();
      case PokedexBulk.completeAllShiny:
        dex.completeAll(shiny: true);
      case PokedexBulk.clearAll:
        dex.clearAll();
      case PokedexBulk.none:
        entries.forEach(dex.apply);
    }
  }

  @override
  String get description => switch (bulk) {
        PokedexBulk.completeAll || PokedexBulk.completeAllShiny => 'Pokédex completada',
        PokedexBulk.clearAll => 'Pokédex limpiada',
        PokedexBulk.none => 'Pokédex: ${entries.length} especie(s)',
      };
}

/// Cambia flags y constantes de eventos.
class EventEdit extends SaveEditOp {
  EventEdit({Map<int, bool> flags = const {}, Map<int, int> work = const {}})
      : flags = Map.unmodifiable(flags),
        work = Map.unmodifiable(work);

  final Map<int, bool> flags;
  final Map<int, int> work;

  @override
  SaveEditKind get kind => SaveEditKind.events;

  @override
  void applyTo(SaveEditor editor) {
    final ev = editor.events;
    if (ev == null) throw const SaveEditException('Este juego no tiene editor de eventos.');
    for (final i in [...flags.keys, ...work.keys]) {
      if (i < 0) throw SaveEditException('Índice de evento no válido: $i');
    }
    if (flags.keys.any((i) => i >= ev.flagCount) || work.keys.any((i) => i >= ev.workCount)) {
      throw const SaveEditException('Índice de evento fuera de rango para este juego.');
    }
    flags.forEach(ev.setFlag);
    work.forEach(ev.setWork);
  }

  @override
  String get description => 'Eventos: ${flags.length + work.length} cambio(s)';
}

/// Implementación de [SaveWriter] basada en [SaveEditor].
class EditorSaveWriter implements SaveWriter {
  const EditorSaveWriter();

  @override
  bool canWrite(SaveFile save) => save.support.party || save.support.boxes || save.support.trainer;

  @override
  Uint8List apply(SaveFile save, List<SaveEdit> edits) {
    final editor = SaveEditor.open(save.raw);
    for (final e in edits) {
      if (e is! SaveEditOp) throw ArgumentError('Edición no soportada: ${e.runtimeType}');
      editor.checkWritable();
      e.applyTo(editor);
    }
    return editor.buildVerified();
  }
}
