import 'dart:typed_data';

import 'event_db.dart';

/// Archivos de tarjeta de Regalo Misterioso (formato de PKHeX).
///
/// Importar reconoce la tarjeta en la base de eventos (con unos pocos bytes de
/// margen: fecha de recepción, marca de usada, checksum) y exportar escribe la
/// tarjeta tal como la guarda PKHeX. Gen 3 no tiene formato de archivo.
abstract final class EventCards {
  /// Extensiones aceptadas (sin punto) → base de eventos y tamaño.
  static const Map<String, (String, int)> formats = {
    'pgt': ('pcd', 0x104),
    'pcd': ('pcd', 0x358),
    'wc4': ('pcd', 0x358),
    'pgf': ('pgf', 0xCC),
    'wc5full': ('pgf', 0x2D0),
    'wc6': ('wc6', 0x108),
    'wc6full': ('wc6', 0x310),
    'wc7': ('wc7', 0x108),
    'wc7full': ('wc7', 0x310),
    'wb7': ('wb7', 0x310),
    'wb7full': ('wb7', 0x310),
    'wc8': ('wc8', 0x2D0),
    'wb8': ('wb8', 0x2DC),
    'wa8': ('wa8', 0x2C8),
    'wc9': ('wc9', 0x2C8),
    'wa9': ('wa9', 0x2C8),
  };

  /// Bytes distintos que se toleran al reconocer una tarjeta.
  static const int tolerance = 24;

  /// Evento de la base que corresponde al archivo [bytes] con extensión [ext]
  /// (sin punto), o null si no es una tarjeta conocida.
  static EventGift? identify(String ext, Uint8List bytes) {
    final spec = formats[ext.toLowerCase()];
    if (spec == null) return null;
    final (db, size) = spec;
    if (bytes.length < size) return null;
    final card = _cardOf(ext.toLowerCase(), Uint8List.sublistView(bytes, 0, size));
    EventGift? best;
    var bestDiff = tolerance + 1;
    for (final g in EventDb.all) {
      if (g.db != db) continue;
      final raw = g.rawCard;
      if (raw == null) continue;
      final cmp = ext == 'pgt' ? Uint8List.sublistView(raw, 0, 0x104) : raw;
      if (cmp.length != card.length) continue;
      var diff = 0;
      for (var i = 0; i < cmp.length && diff < bestDiff; i++) {
        if (cmp[i] != card[i]) diff++;
      }
      if (diff < bestDiff) {
        best = g;
        bestDiff = diff;
        if (diff == 0) break;
      }
    }
    return best;
  }

  /// La parte de la tarjeta que guarda la base (las «full» llevan la tarjeta al final).
  static Uint8List _cardOf(String ext, Uint8List file) => switch (ext) {
        'wc6full' || 'wc7full' => Uint8List.sublistView(file, 0x310 - 0x108),
        'wc5full' => Uint8List.sublistView(file, 0x2D0 - 0xCC),
        _ => file,
      };

  /// Nombre de archivo para exportar [g] (null en Gen 3).
  static String? fileName(EventGift g, String speciesName) {
    final ext = g.cardExtension;
    if (ext == null) return null;
    final id = g.cardId > 0 ? g.cardId.toString().padLeft(4, '0') : '${g.dbIndex}';
    final safe = speciesName.replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '_');
    return '${id}_$safe.$ext';
  }

  /// Tarjeta para exportar (la de la base, como la guarda PKHeX).
  static Uint8List? export(EventGift g) => g.rawCard;
}
