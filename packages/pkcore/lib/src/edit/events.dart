import 'dart:typed_data';

import '../crypto/sc_block.dart';
import '../data/generated/event_labels.dart';

/// Categoría de una etiqueta de evento (PKHeX `NamedEventType`).
enum EventCategory { general, item, gift, battle, story, flyTo, system, other }

EventCategory _category(String c) => switch (c.trim()) {
      'h' || 'i' => EventCategory.item,
      'g' => EventCategory.gift,
      'r' || 'b' || 't' => EventCategory.battle,
      's' || 'q' => EventCategory.story,
      'f' => EventCategory.flyTo,
      '*' => EventCategory.system,
      'm' || 'e' || 'u' => EventCategory.other,
      _ => EventCategory.general,
    };

/// Valor con nombre para una constante (p. ej. `387: Turtwig`).
class EventOption {
  const EventOption(this.value, this.label);
  final int value;
  final String label;
}

/// Flag o constante con nombre legible.
class EventLabel {
  const EventLabel(this.index, this.text, this.category, {this.options = const []});
  final int index;
  final String text;
  final EventCategory category;
  final List<EventOption> options;
}

/// Idioma de las etiquetas.
enum EventLanguage { es, en }

/// Tablas de etiquetas de PKHeX para un juego (`gs`, `e`, `pt`, `bdsp`…).
abstract final class EventLabels {
  static final Map<String, List<EventLabel>> _cache = {};

  static List<EventLabel> flags(String? key, EventLanguage lang) => _get('flags', key, lang);
  static List<EventLabel> work(String? key, EventLanguage lang) => _get('work', key, lang);

  static List<EventLabel> _get(String kind, String? key, EventLanguage lang) {
    if (key == null) return const [];
    final id = '${kind}_${key}_${lang.name}';
    return _cache.putIfAbsent(id, () {
      final raw = kEventLabels[id] ?? kEventLabels['${kind}_${key}_en'];
      if (raw == null) return const [];
      final seen = <int>{};
      final out = <EventLabel>[];
      for (final line in raw.split('\n')) {
        final p = line.split('\t');
        if (p.length < 3) continue;
        final n = p[0].trim();
        final idx = n.startsWith('0x') ? int.tryParse(n.substring(2), radix: 16) : int.tryParse(n);
        if (idx == null || !seen.add(idx)) continue;
        final options = <EventOption>[];
        if (p.length > 3) {
          for (final pair in p[3].split(',')) {
            final kv = pair.split(':');
            final v = kv.length == 2 ? int.tryParse(kv[0].trim()) : null;
            if (v != null) options.add(EventOption(v, kv[1].trim()));
          }
        }
        out.add(EventLabel(idx, p[2].trim(), _category(p[1]), options: options));
      }
      return out;
    });
  }

  static final Map<String, Map<int, (String, String)>> _blocks = {};

  /// Nombre de un bloque SwishCrypto ([game] = swsh, la, sv, za): (nombre, comentario).
  static (String, String)? blockName(String game, int key) => _blocks.putIfAbsent(game, () {
        final raw = kBlockNames[game] ?? '';
        return {
          for (final line in raw.split('\n'))
            if (line.split('\t') case [final k, final name, final comment, ...])
              int.parse(k, radix: 16): (name, comment),
        };
      })[key];
}

/// Flags y constantes de eventos de un save.
abstract class EventStore {
  /// Clave de las tablas de etiquetas (null = sin nombres, solo lista cruda).
  String? get labelKey;
  int get flagCount;
  int get workCount;
  bool getFlag(int index);
  void setFlag(int index, bool value);
  int getWork(int index);
  void setWork(int index, int value);

  /// Valor máximo de una constante.
  int get workMax => 0xFFFF;

  /// Nombre legible de un flag (si hay tabla) o null.
  String? flagName(int index, EventLanguage lang) => _labelOf(EventLabels.flags(labelKey, lang), index)?.text;
  String? workName(int index, EventLanguage lang) => _labelOf(EventLabels.work(labelKey, lang), index)?.text;

  List<EventLabel> namedFlags(EventLanguage lang) =>
      [for (final l in EventLabels.flags(labelKey, lang)) if (l.index < flagCount) l];
  List<EventLabel> namedWork(EventLanguage lang) =>
      [for (final l in EventLabels.work(labelKey, lang)) if (l.index < workCount) l];

  static EventLabel? _labelOf(List<EventLabel> list, int index) {
    for (final l in list) {
      if (l.index == index) return l;
    }
    return null;
  }
}

/// Flags como bitfield y constantes u16 consecutivas (Gen 1–4, BDSP).
class BitEventStore extends EventStore {
  BitEventStore(this.data,
      {required this.flagOffset,
      required this.flagCount,
      this.workOffset = -1,
      this.workCount = 0,
      this.workSize = 2,
      this.labelKey});

  final Uint8List data;
  final int flagOffset;
  @override
  final int flagCount;
  final int workOffset;
  @override
  final int workCount;

  /// Bytes por constante (1 en Gen 2, 2 en Gen 3–4, 4 en BDSP).
  final int workSize;
  @override
  final String? labelKey;

  @override
  int get workMax => switch (workSize) { 1 => 0xFF, 2 => 0xFFFF, _ => 0x7FFFFFFF };

  @override
  bool getFlag(int index) => (data[flagOffset + (index >> 3)] >> (index & 7)) & 1 == 1;

  @override
  void setFlag(int index, bool value) {
    final o = flagOffset + (index >> 3);
    data[o] = value ? data[o] | (1 << (index & 7)) : data[o] & ~(1 << (index & 7));
  }

  @override
  int getWork(int index) {
    final o = workOffset + index * workSize;
    var v = 0;
    for (var i = workSize - 1; i >= 0; i--) {
      v = (v << 8) | data[o + i];
    }
    return v;
  }

  @override
  void setWork(int index, int value) {
    final o = workOffset + index * workSize;
    final v = value.clamp(0, workMax);
    for (var i = 0; i < workSize; i++) {
      data[o + i] = (v >> (8 * i)) & 0xFF;
    }
  }
}

/// Diamante Brillante/Perla Reluciente (PKHeX `FlagWork8b`): cada flag ocupa
/// 4 bytes (0/1) y cada constante es un entero de 32 bits con signo.
class WordEventStore extends EventStore {
  WordEventStore(this.data,
      {required this.flagOffset, required this.flagCount, required this.workOffset, required this.workCount, this.labelKey});

  final Uint8List data;
  final int flagOffset;
  final int workOffset;
  @override
  final int flagCount;
  @override
  final int workCount;
  @override
  final String? labelKey;

  @override
  int get workMax => 0x7FFFFFFF;

  int _u32(int o) => data[o] | (data[o + 1] << 8) | (data[o + 2] << 16) | (data[o + 3] << 24);
  void _setU32(int o, int v) {
    for (var i = 0; i < 4; i++) {
      data[o + i] = (v >> (8 * i)) & 0xFF;
    }
  }

  @override
  bool getFlag(int index) => _u32(flagOffset + index * 4) != 0;

  @override
  void setFlag(int index, bool value) {
    if (getFlag(index) == value) return; // conserva valores distintos de 1
    _setU32(flagOffset + index * 4, value ? 1 : 0);
  }

  @override
  int getWork(int index) => _u32(workOffset + index * 4).toSigned(32).clamp(0, workMax);

  @override
  void setWork(int index, int value) => _setU32(workOffset + index * 4, value.clamp(0, workMax));
}

/// Gen 8–9: cada flag es un bloque booleano y cada constante un bloque numérico.
class SwishEventStore extends EventStore {
  SwishEventStore(List<SCBlock> blocks, this.game, {required this.onChange})
      : _flags = [for (final b in blocks) if (b.type == SCTypeCode.bool1 || b.type == SCTypeCode.bool2) b]
          ..sort((a, b) => a.key.compareTo(b.key)),
        _work = [
          for (final b in blocks)
            if (const {SCTypeCode.byte, SCTypeCode.uint16, SCTypeCode.uint32, SCTypeCode.int32, SCTypeCode.sbyte, SCTypeCode.int16}
                .contains(b.type))
              b,
        ]..sort((a, b) => a.key.compareTo(b.key));

  final List<SCBlock> _flags;
  final List<SCBlock> _work;

  /// Clave de nombres de bloque (swsh, la, sv, za).
  final String game;
  final void Function() onChange;

  @override
  String? get labelKey => null;
  @override
  int get flagCount => _flags.length;
  @override
  int get workCount => _work.length;

  /// Clave del bloque del flag/constante [index].
  int flagKey(int index) => _flags[index].key;
  int workKey(int index) => _work[index].key;

  @override
  int get workMax => 0x7FFFFFFF;

  @override
  bool getFlag(int index) => _flags[index].type == SCTypeCode.bool2;

  @override
  void setFlag(int index, bool value) {
    _flags[index].type = value ? SCTypeCode.bool2 : SCTypeCode.bool1;
    onChange();
  }

  @override
  int getWork(int index) => _work[index].intValue;

  @override
  void setWork(int index, int value) {
    _work[index].intValue = value;
    onChange();
  }

  String _name(int key) {
    final n = EventLabels.blockName(game, key);
    if (n == null) return '0x${key.toRadixString(16).toUpperCase().padLeft(8, '0')}';
    return n.$2.isEmpty ? n.$1 : '${n.$1} — ${n.$2}';
  }

  @override
  String? flagName(int index, EventLanguage lang) => EventLabels.blockName(game, _flags[index].key) == null ? null : _name(_flags[index].key);
  @override
  String? workName(int index, EventLanguage lang) => EventLabels.blockName(game, _work[index].key) == null ? null : _name(_work[index].key);

  @override
  List<EventLabel> namedFlags(EventLanguage lang) => [
        for (var i = 0; i < _flags.length; i++)
          if (EventLabels.blockName(game, _flags[i].key) != null) EventLabel(i, _name(_flags[i].key), EventCategory.system),
      ];

  @override
  List<EventLabel> namedWork(EventLanguage lang) => [
        for (var i = 0; i < _work.length; i++)
          if (EventLabels.blockName(game, _work[i].key) != null) EventLabel(i, _name(_work[i].key), EventCategory.system),
      ];
}
