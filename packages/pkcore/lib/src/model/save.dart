import 'dart:typed_data';

import 'game.dart';

/// Datos del entrenador dueño de la partida.
class TrainerInfo {
  const TrainerInfo({
    required this.name,
    required this.tid,
    this.sid,
    this.gender,
    required this.playTime,
    this.language,
    this.sixDigitIds = false,
  });

  final String name;

  /// TID de 16 bits (Gen 1–6) tal como se guarda.
  final int tid;

  /// SID de 16 bits (Gen 3 en adelante).
  final int? sid;

  /// 0 = masculino, 1 = femenino, null = no disponible.
  final int? gender;
  final Duration playTime;

  /// Idioma de la partida según el juego (si está disponible).
  final int? language;

  /// Gen 7+ muestran el ID de 32 bits partido en 6 dígitos (TID) + 4 (SID).
  final bool sixDigitIds;

  int get id32 => (tid & 0xFFFF) | ((sid ?? 0) << 16);

  /// ID visible en la ficha de entrenador.
  String get displayTid => sixDigitIds
      ? (id32 % 1000000).toString().padLeft(6, '0')
      : tid.toString().padLeft(5, '0');

  /// SID visible (o null si el juego no lo tiene).
  String? get displaySid {
    if (sid == null) return null;
    return sixDigitIds
        ? (id32 ~/ 1000000).toString().padLeft(4, '0')
        : sid!.toString().padLeft(5, '0');
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'tid': tid,
        'sid': sid,
        'gender': gender,
        'playTimeSeconds': playTime.inSeconds,
        'language': language,
        'sixDigitIds': sixDigitIds,
      };
}

/// Resumen de un Pokémon (solo lectura) suficiente para listarlo.
class PokemonSummary {
  const PokemonSummary({
    required this.species,
    this.form = 0,
    this.nickname,
    required this.level,
    this.isShiny = false,
    this.isEgg = false,
    this.heldItem = 0,
    this.pid,
  });

  /// Número de la Pokédex Nacional.
  final int species;
  final int form;

  /// Apodo, solo si el Pokémon fue apodado (null = nombre de especie).
  final String? nickname;
  final int level;
  final bool isShiny;
  final bool isEgg;
  final int heldItem;
  final int? pid;

  Map<String, Object?> toJson() => {
        'species': species,
        'form': form,
        'nickname': nickname,
        'level': level,
        'shiny': isShiny,
        'egg': isEgg,
      };

  @override
  String toString() =>
      'PokemonSummary(#$species lv$level${isShiny ? ' ★' : ''}${nickname != null ? ' "$nickname"' : ''})';
}

/// Una caja del PC.
class PokemonBox {
  const PokemonBox({required this.index, required this.name, required this.slots});

  final int index;

  /// Nombre de la caja (puede ser genérico si el juego no lo guarda).
  final String name;

  /// Huecos de la caja, null = vacío.
  final List<PokemonSummary?> slots;

  int get count => slots.where((s) => s != null).length;
}

/// Qué partes del save se pudieron leer para este formato.
class ReadSupport {
  const ReadSupport({this.trainer = true, this.party = false, this.boxes = false});

  final bool trainer;
  final bool party;
  final bool boxes;

  static const trainerOnly = ReadSupport();
  static const full = ReadSupport(party: true, boxes: true);
}

enum ChecksumStatus { valid, invalid, notChecked }

/// Resultado de leer un save: inmutable y desacoplado del buffer.
class SaveFile {
  SaveFile({
    required this.game,
    required this.trainer,
    required this.raw,
    required this.format,
    this.versionId,
    this.party = const [],
    this.boxes = const [],
    this.support = ReadSupport.trainerOnly,
    this.checksum = ChecksumStatus.notChecked,
    this.warnings = const [],
    this.versionInferred = false,
  });

  final GameVersion game;

  /// `true` si [versionId] no viene del save sino de los Pokémon del
  /// entrenador (`GameVersions.infer`).
  final bool versionInferred;

  /// Copia con otra versión concreta (deducida).
  SaveFile withVersion(int? v, {bool inferred = true}) => SaveFile(
        game: game,
        trainer: trainer,
        raw: raw,
        format: format,
        versionId: v,
        party: party,
        boxes: boxes,
        support: support,
        checksum: checksum,
        warnings: warnings,
        versionInferred: inferred,
      );

  /// Id de versión concreta (p. ej. 44 = Espada) si el save lo guarda.
  final int? versionId;
  final TrainerInfo trainer;
  final List<PokemonSummary> party;
  final List<PokemonBox> boxes;
  final ReadSupport support;
  final ChecksumStatus checksum;

  /// Descripción del contenedor detectado (p. ej. "SCBlock cifrado (SwishCrypto)").
  final String format;
  final List<String> warnings;

  /// Bytes originales exactos del archivo importado.
  final Uint8List raw;

  int get generation => game.generation;

  String get titleEs => GameTitles.nameEs(versionId) ?? game.nameEs;
  String get titleEn => GameTitles.nameEn(versionId) ?? game.nameEn;

  int get boxedCount => boxes.fold(0, (a, b) => a + b.count);

  /// Clave para agrupar snapshots de "la misma partida" en el Arca.
  String get identityKey =>
      '${game.code}:${trainer.tid}:${trainer.sid ?? 0}:${trainer.name}';
}

/// El archivo no corresponde a ningún formato de save soportado.
class UnsupportedSaveException implements Exception {
  const UnsupportedSaveException(this.message, {this.size});

  final String message;
  final int? size;

  @override
  String toString() => 'UnsupportedSaveException: $message';
}

/// El formato se reconoció pero los datos están dañados o incompletos.
class CorruptSaveException implements Exception {
  const CorruptSaveException(this.game, this.message);

  final GameVersion game;
  final String message;

  @override
  String toString() => 'CorruptSaveException(${game.code}): $message';
}
