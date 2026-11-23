import 'dart:typed_data';

import '../detect/save_detector.dart';
import '../model/game.dart';
import '../model/save.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';
import 'ctr_editors.dart';
import 'gb_editors.dart';
import 'gba_editor.dart';
import 'events.dart';
import 'nds_editors.dart';
import 'pokedex.dart';
import 'save_verifier.dart';
import 'switch_editors.dart';

/// Referencia a un hueco del equipo o de una caja.
class SlotRef {
  const SlotRef.party(this.slot) : box = -1;
  const SlotRef.box(this.box, this.slot);

  /// Índice de caja, o -1 para el equipo.
  final int box;
  final int slot;

  bool get isParty => box < 0;

  @override
  bool operator ==(Object other) => other is SlotRef && other.box == box && other.slot == slot;

  @override
  int get hashCode => Object.hash(box, slot);

  @override
  String toString() => isParty ? 'equipo[$slot]' : 'caja ${box + 1}[$slot]';
}

/// Campos del entrenador que un juego permite editar.
enum TrainerField { name, tid, sid, money, playTime, gender }

/// Datos editables del entrenador.
class TrainerData {
  const TrainerData({
    required this.name,
    required this.tid,
    this.sid = 0,
    this.money = 0,
    this.playTime = Duration.zero,
    this.gender,
  });

  final String name;
  final int tid;
  final int sid;
  final int money;
  final Duration playTime;
  final int? gender;

  TrainerData copyWith({String? name, int? tid, int? sid, int? money, Duration? playTime, int? gender}) => TrainerData(
        name: name ?? this.name,
        tid: tid ?? this.tid,
        sid: sid ?? this.sid,
        money: money ?? this.money,
        playTime: playTime ?? this.playTime,
        gender: gender ?? this.gender,
      );

  @override
  bool operator ==(Object other) =>
      other is TrainerData &&
      other.name == name &&
      other.tid == tid &&
      other.sid == sid &&
      other.money == money &&
      other.playTime == playTime &&
      other.gender == gender;

  @override
  int get hashCode => Object.hash(name, tid, sid, money, playTime, gender);
}

/// Un objeto con su cantidad dentro de un bolsillo.
class InventoryItem {
  const InventoryItem(this.item, this.count, {this.extra = 0});

  final int item;
  final int count;

  /// Bits extra del formato (nuevo, favorito, orden…), se conservan al reescribir.
  final int extra;

  InventoryItem withCount(int c) => InventoryItem(item, c, extra: extra);

  @override
  bool operator ==(Object other) => other is InventoryItem && other.item == item && other.count == count;

  @override
  int get hashCode => Object.hash(item, count);
}

/// Un bolsillo del inventario.
class InventoryPouch {
  const InventoryPouch({
    required this.type,
    required this.capacity,
    required this.maxCount,
    required this.legalItems,
    required this.items,
  });

  /// Nombre del tipo de bolsillo de PKHeX (`Items`, `KeyItems`, `Balls`, `TMHMs`, …).
  final String type;

  /// Número máximo de entradas distintas.
  final int capacity;

  /// Cantidad máxima por objeto.
  final int maxCount;

  /// Objetos que admite el bolsillo (vacío = cualquiera).
  final List<int> legalItems;

  /// Objetos presentes (sin huecos vacíos).
  final List<InventoryItem> items;

  InventoryPouch withItems(List<InventoryItem> items) =>
      InventoryPouch(type: type, capacity: capacity, maxCount: maxCount, legalItems: legalItems, items: items);
}

/// El formato del archivo no permite la operación pedida.
class SaveEditException implements Exception {
  const SaveEditException(this.message);
  final String message;
  @override
  String toString() => 'SaveEditException: $message';
}

/// Editor de un save concreto: lee y escribe Pokémon, entrenador e inventario
/// sobre una copia de trabajo y produce un archivo listo para el juego.
///
/// Nunca modifica los bytes de entrada. Si no se edita nada, [build] devuelve
/// exactamente los mismos bytes (round-trip).
abstract class SaveEditor {
  SaveEditor(this.game, {this.versionId});

  final GameVersion game;
  final int? versionId;

  /// Bytes del contenedor que no forman parte del save (pie RTC, pie .dsv…).
  Uint8List suffix = Uint8List(0);

  PkFormat get format => PkFormat.forGame(game);

  /// Abre un archivo de save. Lanza [UnsupportedSaveException] si no se
  /// reconoce y [CorruptSaveException] si se reconoce pero no se puede leer.
  ///
  /// Nunca deja escapar errores internos (RangeError, StateError…): un
  /// archivo truncado o manipulado produce siempre una excepción controlada.
  /// Si la lectura completa encuentra datos imposibles, el editor se abre en
  /// solo lectura ([integrityIssues] no vacío) para no escribir un save inválido.
  static SaveEditor open(Uint8List bytes) {
    final det = SaveDetector.detect(bytes);
    try {
      final payload = Uint8List.fromList(det.payload);
      final save = det.read();
      final SaveEditor editor = switch (det.game) {
        GameVersion.redBlue || GameVersion.yellow => Gen1Editor.open(payload, det.game),
        GameVersion.goldSilver || GameVersion.crystal => Gen2Editor.open(payload, det.game),
        GameVersion.rubySapphire || GameVersion.emerald || GameVersion.fireRedLeafGreen => Gen3Editor(payload, det.game),
        GameVersion.diamondPearl || GameVersion.platinum || GameVersion.heartGoldSoulSilver => Gen4Editor(payload, det.game),
        GameVersion.blackWhite || GameVersion.black2White2 => Gen5Editor(payload, det.game, versionId: save.versionId),
        GameVersion.xy ||
        GameVersion.omegaRubyAlphaSapphire ||
        GameVersion.sunMoon ||
        GameVersion.ultraSunUltraMoon =>
          CtrEditor(payload, det.game, versionId: save.versionId),
        GameVersion.letsGo => LetsGoEditor(payload, versionId: save.versionId),
        GameVersion.brilliantDiamondShiningPearl => BdspEditor(payload),
        GameVersion.swordShield || GameVersion.legendsArceus || GameVersion.scarletViolet || GameVersion.legendsZA =>
          SwishEditor(payload, det.game, versionId: save.versionId),
      };
      editor.suffix = bytes.length > payload.length ? bytes.sublist(payload.length) : Uint8List(0);
      final checksumProblems = <ChecksumProblem>[
        if (save.checksum != ChecksumStatus.valid) ...SaveVerifier.checksumProblems(bytes),
      ];
      if (save.checksum == ChecksumStatus.invalid && checksumProblems.isEmpty) {
        checksumProblems.add(const ChecksumProblem(SavePart.whole, 'Las sumas de comprobación no son válidas.'));
      }
      editor.checksumProblems = List.unmodifiable(checksumProblems);
      editor.readErrors = List.unmodifiable(editor.checkIntegrity());
      editor.integrityIssues = List.unmodifiable([
        for (final p in checksumProblems) 'Checksum: ${p.detail}',
        ...editor.readErrors,
      ]);
      return editor;
    } on UnsupportedSaveException {
      rethrow;
    } on CorruptSaveException {
      rethrow;
    } on Object catch (e) {
      throw CorruptSaveException(det.game, 'No se pudo abrir el save: $e');
    }
  }

  /// Problemas encontrados al leer todo el save al abrirlo. Si hay alguno, el
  /// editor está en solo lectura ([readOnly]).
  ///
  /// Es la unión de [checksumProblems] y [readErrors].
  List<String> integrityIssues = const [];

  /// Checksums, hashes o firmas del archivo que no coinciden con sus datos.
  List<ChecksumProblem> checksumProblems = const [];

  /// Datos que no se pudieron leer o son imposibles (Pokémon corruptos…).
  List<String> readErrors = const [];

  /// Gravedad del daño: [SaveDamage.minor] si todo se lee bien y solo fallan
  /// checksums (se puede reparar con [buildRepaired]); [SaveDamage.major] si
  /// hay datos que no se pueden leer.
  SaveDamage get damage => readErrors.isNotEmpty
      ? SaveDamage.major
      : checksumProblems.isNotEmpty
          ? SaveDamage.minor
          : SaveDamage.none;

  /// Si es `true`, [buildPayload] recalcula todos los checksums, hashes y
  /// firmas aunque los datos no hayan cambiado. Solo lo activa [buildRepaired].
  bool forceChecksums = false;

  /// Archivo con los mismos datos y todos los checksums recalculados.
  ///
  /// Solo para daño [SaveDamage.minor] (o ninguno): si hay datos ilegibles
  /// lanza [SaveEditException]. Antes de devolverlo se relee y se comprueba
  /// como [buildVerified].
  Uint8List buildRepaired() {
    if (damage == SaveDamage.major) {
      throw const SaveEditException('El save tiene datos que no se pueden leer; recalcular los checksums no lo arregla.');
    }
    forceChecksums = true;
    final Uint8List out;
    try {
      out = build();
    } finally {
      forceChecksums = false;
    }
    final problems = SaveVerifier.verifyExport(this, out);
    if (problems.isNotEmpty) throw SaveVerificationException(problems);
    return out;
  }

  /// `true` si el save tiene datos que no se pueden leer: no se permite editar.
  bool get readOnly => integrityIssues.isNotEmpty;

  /// Lanza [SaveEditException] si el editor está en solo lectura.
  void checkWritable() {
    if (readOnly) {
      throw SaveEditException('El save tiene datos dañados y se abrió en solo lectura: ${integrityIssues.first}');
    }
  }

  /// Lee todo lo que el editor expone y devuelve los fallos encontrados.
  List<String> checkIntegrity() {
    final out = <String>[];
    void tryRead(String what, void Function() f) {
      try {
        f();
      } on Object catch (e) {
        out.add('$what: $e');
      }
    }

    tryRead('Entrenador', readTrainer);
    tryRead('Equipo', () {
      final n = partyCount;
      if (n < 0 || n > partyCapacity) throw RangeError.range(n, 0, partyCapacity, 'partyCount');
      for (var i = 0; i < n; i++) {
        readPartySlot(i);
      }
    });
    tryRead('Cajas', () {
      for (var b = 0; b < boxCount; b++) {
        boxName(b);
        for (var s = 0; s < boxSlotCount; s++) {
          readBoxSlot(b, s);
        }
      }
    });
    tryRead('Inventario', readInventory);
    tryRead('Pokédex', () => pokedex?.counts);
    tryRead('Eventos', () {
      final ev = events;
      if (ev == null) return;
      for (var i = 0; i < ev.flagCount; i++) {
        ev.getFlag(i);
      }
      for (var i = 0; i < ev.workCount; i++) {
        ev.getWork(i);
      }
    });
    return out;
  }

  // ------------------------------------------------------------ almacenamiento

  int get partyCapacity => 6;
  int get boxCount;
  int get boxSlotCount;

  /// `false` si el formato no permite escribir Pokémon (p. ej. saves coreanos de Gen 2).
  bool get canEditStorage => true;

  /// Número de Pokémon en el equipo.
  int get partyCount;

  /// Lee el Pokémon del equipo en [index] (< [partyCount]).
  Pkm readPartySlot(int index);

  /// Reescribe el equipo completo (de 0 a 6 miembros, compactado).
  void writeParty(List<Pkm> party);

  Pkm? readBoxSlot(int box, int slot);
  void writeBoxSlot(int box, int slot, Pkm? pk);

  String boxName(int box) => 'Caja ${box + 1}';
  bool get canRenameBoxes => false;
  void setBoxName(int box, String name) => throw const SaveEditException('Este juego no guarda nombres de caja.');

  /// Huecos que el juego no permite vaciar ni mover (p. ej. el compañero de Let's Go).
  bool isSlotLocked(SlotRef ref) => false;

  // ------------------------------------------------------------ entrenador

  Set<TrainerField> get trainerFields;
  int get maxMoney => game.generation >= 5 ? 9999999 : 999999;
  int get maxTrainerNameLength => switch (game.generation) {
        1 || 2 => 7,
        3 || 4 || 5 => 7,
        _ => 12,
      };
  TrainerData readTrainer();
  void writeTrainer(TrainerData t);

  // ------------------------------------------------------------ inventario

  /// Bolsillos del inventario, o null si este juego no tiene editor de inventario.
  List<InventoryPouch>? readInventory() => null;
  void writeInventory(List<InventoryPouch> pouches) => throw const SaveEditException('Inventario no soportado.');

  // ------------------------------------------------------------ Pokédex y eventos

  /// Pokédex editable, o null si este juego aún no la soporta.
  Pokedex? get pokedex => null;

  /// Flags y constantes de eventos, o null si no hay editor para este juego.
  EventStore? get events => null;

  // ------------------------------------------------------------ salida

  /// Bytes del save sin contenedor, con checksums corregidos.
  Uint8List buildPayload();

  /// Archivo completo (mismo contenedor que el original).
  Uint8List build() {
    final p = buildPayload();
    if (suffix.isEmpty) return p;
    return Uint8List(p.length + suffix.length)
      ..setRange(0, p.length, p)
      ..setRange(p.length, p.length + suffix.length, suffix);
  }

  // ------------------------------------------------------------ API de alto nivel

  Pkm _tag(Pkm pk) => pk..dataGame = game;

  List<Pkm> get party => [for (var i = 0; i < partyCount; i++) _tag(readPartySlot(i))];

  Pkm? get(SlotRef ref) {
    if (ref.isParty) return ref.slot < partyCount ? _tag(readPartySlot(ref.slot)) : null;
    final pk = readBoxSlot(ref.box, ref.slot);
    return pk == null ? null : _tag(pk);
  }

  /// Coloca [pk] (o vacía con null) en [ref]. En el equipo, vaciar compacta y
  /// añadir más allá del final lo coloca al final.
  void set(SlotRef ref, Pkm? pk) {
    _checkStorage();
    if (pk != null && pk.format != format) {
      throw SaveEditException('Formato ${pk.format.extension} no compatible con ${game.nameEs} (${format.extension}).');
    }
    if (ref.isParty) {
      final list = party;
      if (pk == null) {
        if (ref.slot >= list.length) return;
        list.removeAt(ref.slot);
      } else {
        final p = pk.clone()..dataGame = game;
        if (_partyStatsEmpty(p)) p.refreshPartyStats();
        if (ref.slot < list.length) {
          list[ref.slot] = p;
        } else {
          if (list.length >= partyCapacity) throw const SaveEditException('El equipo está lleno.');
          list.add(p);
        }
      }
      writeParty(list);
    } else {
      writeBoxSlot(ref.box, ref.slot, pk);
    }
  }

  /// Intercambia el contenido de dos huecos (mover a un hueco vacío = mover).
  void swap(SlotRef a, SlotRef b) {
    if (a == b) return;
    _checkStorage();
    final pa = get(a), pb = get(b);
    if (a.isParty && b.isParty) {
      final list = party;
      if (pa == null || a.slot >= list.length) return;
      final target = b.slot.clamp(0, list.length - 1);
      final tmp = list[a.slot];
      list[a.slot] = list[target];
      list[target] = tmp;
      writeParty(list);
      return;
    }
    if (a.isParty || b.isParty) {
      final (partyRef, boxRef, partyMon, boxMon) = a.isParty ? (a, b, pa, pb) : (b, a, pb, pa);
      if (partyMon != null && boxMon == null && partyCount <= 1) {
        throw const SaveEditException('El equipo no puede quedarse vacío.');
      }
      writeBoxSlot(boxRef.box, boxRef.slot, partyMon);
      set(partyRef, boxMon);
      return;
    }
    writeBoxSlot(a.box, a.slot, pb);
    writeBoxSlot(b.box, b.slot, pa);
  }

  /// Primer hueco libre de las cajas (desde [startBox]), o null si están llenas.
  SlotRef? firstEmptyBoxSlot([int startBox = 0]) {
    for (var i = 0; i < boxCount; i++) {
      final b = (startBox + i) % boxCount;
      for (var s = 0; s < boxSlotCount; s++) {
        if (readBoxSlot(b, s) == null) return SlotRef.box(b, s);
      }
    }
    return null;
  }

  void _checkStorage() {
    checkWritable();
    if (!canEditStorage) throw const SaveEditException('Este save no permite editar Pokémon.');
  }

  static bool _partyStatsEmpty(Pkm p) => p.partyStats.every((s) => s == 0);

  /// Construye el archivo y lo verifica antes de entregarlo: lo relee con un
  /// editor nuevo y comprueba checksums y contenido ([SaveVerifier]). Lanza
  /// [SaveVerificationException] si algo no coincide y [SaveEditException] si
  /// el editor está en solo lectura con cambios.
  Uint8List buildVerified() {
    final out = build();
    final problems = SaveVerifier.verifyExport(this, out);
    if (problems.isNotEmpty) throw SaveVerificationException(problems);
    return out;
  }

  /// Resumen actualizado (relee el archivo construido).
  SaveFile summary() => SaveDetector.read(build());
}

/// Gravedad del daño de un save abierto ([SaveEditor.damage]).
enum SaveDamage {
  /// Todo coincide.
  none,

  /// Se lee completo pero algún checksum no coincide: solo lectura, reparable.
  minor,

  /// Hay datos que no se pueden leer.
  major,
}
