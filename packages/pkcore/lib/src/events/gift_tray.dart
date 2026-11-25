import 'dart:typed_data';

import '../edit/ctr_editors.dart';
import '../edit/save_editor.dart';
import '../model/game.dart';
import 'event_db.dart';

/// Bandeja de tarjetas del Regalo Misterioso de una partida: donde el juego deja
/// la tarjeta recibida hasta que el repartidor entrega el regalo.
///
/// Solo X/Y, ROZA, Sol/Luna y USUL (PKHeX `MysteryBlock6/7`): bloque propio sin
/// cifrar cuyo checksum se recalcula al guardar. Gen 4 (PGT/PCD) y Gen 5 (PGF)
/// guardan las tarjetas cifradas con el resto del bloque y no están soportadas
/// todavía; Let's Go y la Switch no guardan tarjetas pendientes (el regalo se
/// recibe directamente): ahí la tarjeta se recibe creando el Pokémon en un hueco.
class GiftTray {
  GiftTray._(this._e);
  final CtrEditor _e;

  /// Bandeja de [editor], o null si el juego no tiene una soportada.
  static GiftTray? of(SaveEditor editor) => editor is CtrEditor ? GiftTray._(editor) : null;

  /// Base de eventos de las tarjetas que admite [game] en la bandeja.
  static String? dbFor(GameVersion game) => switch (game) {
        GameVersion.xy || GameVersion.omegaRubyAlphaSapphire => 'wc6',
        GameVersion.sunMoon || GameVersion.ultraSunUltraMoon => 'wc7',
        _ => null,
      };

  /// `true` si [gift] se puede dejar en la bandeja de una partida de [game].
  static bool accepts(EventGift gift, GameVersion game) => dbFor(game) == gift.db && gift.rawCard?.length == CtrEditor.giftCardSize;

  int get capacity => _e.giftTrayCapacity;

  /// Tarjetas presentes (null = hueco libre).
  List<Uint8List?> get cards => [for (var i = 0; i < capacity; i++) _e.giftCard(i)];

  /// Número de tarjeta (u16 al inicio de la WC6/WC7).
  static int cardId(Uint8List card) => card[0] | (card[1] << 8);

  /// `true` si ya hay una tarjeta con el mismo número.
  bool contains(Uint8List card) => cards.any((c) => c != null && cardId(c) == cardId(card));

  /// Deja [card] en el primer hueco libre y devuelve su índice. Lanza
  /// [SaveEditException] si ya está o la bandeja está llena.
  int receive(Uint8List card) {
    if (contains(card)) throw const SaveEditException('La tarjeta ya está en la bandeja del juego.');
    final all = cards;
    final i = all.indexWhere((c) => c == null);
    if (i < 0) throw const SaveEditException('La bandeja del Regalo Misterioso está llena.');
    _e.setGiftCard(i, card);
    return i;
  }
}
