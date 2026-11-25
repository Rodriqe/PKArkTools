import 'dart:convert';
import 'dart:typed_data';

import '../data/generated/event_data.dart';
import '../legal/origin.dart';
import '../model/game.dart';
import '../pkm/pk_format.dart';
import '../pkm/pkm.dart';

/// Regla de variocolor de un evento (PKHeX `Shiny`).
enum EventShiny {
  /// Nunca variocolor (se corrige el PID si saliera variocolor para el receptor).
  never,

  /// PID al azar: puede salir (o hacerse) variocolor.
  random,

  /// Siempre variocolor.
  always,

  /// Siempre variocolor «estrella» (Gen 8+).
  alwaysStar,

  /// Siempre variocolor «cuadrado» (Gen 8+).
  alwaysSquare,

  /// PID fijo de la tarjeta.
  fixed;

  static EventShiny parse(String s) => switch (s) {
        'Never' => never,
        'Random' => random,
        'Always' => always,
        'AlwaysStar' => alwaysStar,
        'AlwaysSquare' => alwaysSquare,
        _ => fixed,
      };

  bool get isShiny => this == always || this == alwaysStar || this == alwaysSquare;
}

/// Cómo se distribuyó un evento.
enum EventDistribution {
  /// Tarjeta de Regalo Misterioso (DS, 3DS, Switch).
  card,

  /// Regalo de Pokémon HOME.
  home,

  /// Evento de Gen 3 (cartucho de distribución, e-Reader, tiendas).
  gen3,

  /// Pokémon Center de Nueva York o Japón (Gen 3).
  pokemonCenter,
}

/// Región por idioma del Pokémon recibido.
enum EventRegion {
  japan({1}),
  international({2, 3, 4, 5, 7}),
  korea({8}),
  china({9, 10});

  const EventRegion(this.languages);
  final Set<int> languages;

  static Set<EventRegion> of(Iterable<int> langs) => {
        for (final r in values)
          if (langs.any(r.languages.contains)) r,
      };
}

/// Un evento (Mystery Gift) de la base de PKHeX: datos fijos, tarjeta en bruto
/// y plantilla legal (generada con PKHeX `ConvertToPKM`) para crearlo.
class EventGift {
  EventGift._(this._src, this.id, Map<String, Object?> m)
      : db = m['db'] as String,
        dbIndex = m['i'] as int,
        cardId = (m['c'] as int?) ?? 0,
        title = (m['t'] as String?) ?? '',
        species = m['s'] as int,
        form = (m['f'] as int?) ?? 0,
        level = (m['l'] as int?) ?? 0,
        shiny = EventShiny.parse((m['sh'] as String?) ?? ''),
        generation = (m['g'] as int?) ?? 0,
        format = _format(m['fmt'] as String?),
        versions = [for (final v in (m['v'] as List?) ?? const []) v as int],
        trainerLanguages = [for (final v in (m['tl'] as List?) ?? const []) v as int],
        languages = [for (final v in (m['pl'] as List?) ?? const []) v as int],
        cardDate = _date(m['d']),
        windowStart = _date(m['ws']),
        windowEnd = _date(m['we']),
        method = m['m'] as String?,
        fixedOtName = m['on'] as String?,
        templateVersion = (m['tv'] as int?) ?? 0,
        templateLanguage = (m['tlg'] as int?) ?? 2,
        error = m['err'] as String?,
        _flags = (m['x'] as String?) ?? '',
        otByLanguage = {
          for (final e in ((m['ot'] as Map?) ?? const {}).entries) int.parse(e.key as String): e.value as String,
        },
        nicknameByLanguage = {
          for (final e in ((m['nk'] as Map?) ?? const {}).entries) int.parse(e.key as String): _nick(e.value as String),
        };

  /// Base de datos de la que sale (la integrada o una descargada).
  final EventData _src;

  /// Posición en [EventDb.all].
  final int id;

  /// Identifica el evento entre versiones de la base (para marcar los nuevos).
  String get key => '$db:$cardId:$species:$form:$level:$title';

  /// Base de PKHeX: wc3, pcny, pcjp, pcd, pgf, wc6, wc7, wb7, wc8, wb8, wa8, wc9, wa9.
  final String db;
  final int dbIndex;
  final int cardId;
  final String title;
  final int species;
  final int form;
  final int level;
  final EventShiny shiny;
  final int generation;

  /// Formato del Pokémon que crea (null si PKHeX no pudo generar uno legal).
  final PkFormat? format;

  /// Versiones de origen (ids de PKHeX) con las que PKHeX lo da por legal.
  final List<int> versions;

  /// Idiomas de la partida que pueden recibirlo.
  final List<int> trainerLanguages;

  /// Idiomas que puede tener el Pokémon recibido.
  final List<int> languages;
  final DateTime? cardDate;
  final DateTime? windowStart;
  final DateTime? windowEnd;

  /// Gen 3: método PID/IV de PKHeX (BACD_R, Channel…) o el regalo del Pokémon Center.
  final String? method;
  final String? fixedOtName;
  final int templateVersion;
  final int templateLanguage;

  /// Motivo por el que PKHeX no pudo generarlo legal (solo consulta).
  final String? error;
  final String _flags;
  final Map<int, String> otByLanguage;
  final Map<int, (int, bool, String)> nicknameByLanguage;

  bool get isEgg => _flags.contains('E');

  /// El Pokémon toma el nombre de entrenador de quien lo recibe.
  bool get recipientOt => _flags.contains('O');

  /// Toma el ID/SID de quien lo recibe.
  bool get recipientId => _flags.contains('I');
  bool get recipientGender => _flags.contains('G');
  bool get isHome => _flags.contains('H');

  /// La fecha de encuentro es la de recepción (hoy); si no, es fija.
  bool get metToday => _flags.contains('T');

  bool get canCreate => format != null && _src._tpl[id].isNotEmpty && !needsRecipientRng;

  /// Gen 3 variocolor con el ID de quien lo recibe (Pichu huevo japonés,
  /// BACD_TS): el PID sale del RNG en función del ID, sin variante reutilizable.
  bool get needsRecipientRng => format == PkFormat.pk3 && recipientId && shiny.isShiny;

  EventDistribution get distribution => switch (db) {
        'wc3' => EventDistribution.gen3,
        'pcny' || 'pcjp' => EventDistribution.pokemonCenter,
        _ => isHome ? EventDistribution.home : EventDistribution.card,
      };

  /// Juegos (familias) desde los que se podía recibir.
  Set<GameVersion> get games => {
        for (final v in versions)
          if (OriginPlace.gameOf(v) case final g? when !g.isColosseumOrXd) g,
      };

  Set<EventRegion> get regions => EventRegion.of(languages);

  /// Año de la tarjeta o del inicio de la distribución (null si no se conoce).
  int? get year => (windowStart ?? cardDate)?.year;

  /// Extensión del archivo de tarjeta (null en Gen 3: no tiene formato de archivo).
  String? get cardExtension => switch (db) {
        'wc3' || 'pcny' || 'pcjp' => null,
        _ => db,
      };

  /// Tarjeta en bruto tal como la guarda PKHeX (null en Gen 3).
  Uint8List? get rawCard {
    final s = _src._raw[id];
    return s.isEmpty ? null : base64Decode(s);
  }

  /// Pokémon de plantilla (copia nueva en cada llamada).
  Pkm? template([GameVersion? game]) {
    final f = format;
    if (f == null || _src._tpl[id].isEmpty) return null;
    return Pkm.fromDecrypted(f, base64Decode(_src._tpl[id]))..dataGame = game ?? _defaultGame;
  }

  GameVersion? get _defaultGame => OriginPlace.gameOf(templateVersion);

  /// Variantes legales de PID/EC/IV/naturaleza/habilidad/género (Gen 4+).
  List<EventVariant> get variants {
    final s = _src._var[id];
    if (s.isEmpty || hasFullVariants) return const [];
    final d = base64Decode(s);
    return [for (var o = 0; o + 20 <= d.length; o += 20) EventVariant._(Uint8List.sublistView(d, o, o + 20))];
  }

  /// Gen 3 y Z-A guardan variantes completas (el Pokémon almacenado): en Gen 3 el
  /// RNG del evento decide también el género del OT o el ID, y en Z-A PID, EC,
  /// IV y tamaño salen de la misma semilla.
  bool get hasFullVariants => format == PkFormat.pk3 || format == PkFormat.pa9;

  List<Uint8List> get fullVariants {
    final s = _src._var[id];
    final f = format;
    if (s.isEmpty || f == null || !hasFullVariants) return const [];
    final d = base64Decode(s);
    final n = f.storedSize;
    return [for (var o = 0; o + n <= d.length; o += n) Uint8List.sublistView(d, o, o + n)];
  }

  /// Nombre del entrenador original que trae (null si es el de quien lo recibe).
  String? otNameFor(int language) {
    if (recipientOt) return null;
    return otByLanguage[language] ?? template()?.otName;
  }

  @override
  String toString() => 'EventGift($db#$dbIndex card $cardId «$title» #$species)';

  static PkFormat? _format(String? s) => s == null ? null : PkFormat.fromExtension(s);

  static DateTime? _date(Object? s) {
    if (s is! String || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static (int, bool, String) _nick(String s) {
    final p = s.split('|');
    return (int.parse(p[0]), p[1] == '1', p.sublist(2).join('|'));
  }
}

/// PID, EC, IV (orden PKHeX: PS, Atq, Def, Vel, AtE, DfE), naturaleza,
/// naturaleza de stats, nº de habilidad (1, 2, 4; en Gen 3 el bit guardado),
/// género y habilidad de una variante legal.
class EventVariant {
  EventVariant._(this._d);
  final Uint8List _d;

  int get pid => _d[0] | (_d[1] << 8) | (_d[2] << 16) | (_d[3] << 24);
  int get encryptionConstant => _d[4] | (_d[5] << 8) | (_d[6] << 16) | (_d[7] << 24);

  /// IV en el orden de pkcore (PS, Atq, Def, AtE, DfE, Vel).
  List<int> get ivs => [_d[8], _d[9], _d[10], _d[12], _d[13], _d[11]];
  int get nature => _d[14];
  int get statNature => _d[15];
  int get abilityNumber => _d[16];
  int get gender => _d[17];

  /// Habilidad (id) que puso PKHeX.
  int get ability => _d[18] | (_d[19] << 8);
}

/// Un JSON de eventos que no se puede usar.
class EventDataException implements Exception {
  const EventDataException(this.message, {this.futureSchema});
  final String message;

  /// `schemaVersion` del JSON si es mayor que el que entiende esta versión.
  final int? futureSchema;

  @override
  String toString() => 'EventDataException: $message';
}

/// Una versión de la base de eventos: la integrada (`event_data.dart`) o la
/// descargada (`data/events/events.json`, que regenera cada día
/// `.github/workflows/events-data.yml`). Las genera `tool/gen_event_data.py`.
class EventData {
  EventData._({
    required this.schemaVersion,
    required this.generatedAt,
    required this.sourceCommit,
    required this.sourceDate,
    required List<Object> meta,
    required List<String> tpl,
    required List<String> raw,
    required List<String> variants,
  }) : _meta = meta,
       _tpl = tpl,
       _raw = raw,
       _var = variants;

  /// Versión del esquema que entiende esta versión de la app.
  static const supportedSchemaVersion = 1;

  /// Mínimo de eventos de una base válida (hoy hay unos 2900).
  static const minEvents = 1000;

  /// La copia que lleva la app.
  static final EventData builtin = EventData._(
    schemaVersion: supportedSchemaVersion,
    generatedAt: DateTime.tryParse(kEventGeneratedAt) ?? DateTime.utc(2026),
    sourceCommit: kEventSourceCommit,
    sourceDate: kEventSourceDate,
    meta: kEventMeta,
    tpl: kEventTpl,
    raw: kEventRaw,
    variants: kEventVar,
  );

  final int schemaVersion;
  final DateTime generatedAt;

  /// Commit de PKHeX (vacío si no se conoce).
  final String sourceCommit;

  /// Fecha de ese commit (`AAAA-MM-DD`).
  final String sourceDate;

  /// Datos fijos de cada evento: JSON compacto (integrada) o ya decodificado.
  final List<Object> _meta;
  final List<String> _tpl, _raw, _var;

  int get count => _meta.length;

  /// ¿Es más reciente que [other]? (por la fecha en que se generó).
  bool isNewerThan(EventData other) => generatedAt.isAfter(other.generatedAt);

  late final List<EventGift> gifts = [
    for (var i = 0; i < _meta.length; i++)
      EventGift._(this, i, switch (_meta[i]) {
        final String s => jsonDecode(s) as Map<String, Object?>,
        final m => m as Map<String, Object?>,
      }),
  ];

  static final _b64 = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
  static final _commit = RegExp(r'^[0-9a-f]{40}$');
  static final _day = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Lee y valida un JSON (lanza [EventDataException]).
  static EventData parse(String text) {
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException catch (e) {
      throw EventDataException('JSON: ${e.message}');
    }
    if (root is! Map<String, Object?>) throw const EventDataException('not an object');
    final v = root['schemaVersion'];
    if (v is! int || v < 1) throw const EventDataException('schemaVersion');
    if (v > supportedSchemaVersion) throw EventDataException('schemaVersion $v', futureSchema: v);
    Never bad(String what) => throw EventDataException(what);
    final generatedAt = DateTime.tryParse('${root['generatedAt']}') ?? bad('generatedAt');
    final source = root['source'];
    if (source is! Map<String, Object?>) bad('source');
    final commit = source['commit'], date = source['date'];
    if (commit is! String || !_commit.hasMatch(commit)) bad('source.commit');
    if (date is! String || !_day.hasMatch(date)) bad('source.date');
    final events = root['events'];
    if (events is! List || events.length < minEvents || root['count'] != events.length) bad('events');
    final meta = <Object>[], tpl = <String>[], raw = <String>[], vars = <String>[];
    for (final e in events) {
      if (e is! Map<String, Object?>) bad('event');
      final m = e['m'];
      if (m is! Map<String, Object?>) bad('event.m');
      final s = m['s'];
      if (m['db'] is! String || m['i'] is! int || s is! int || s < 1 || s > 1025) bad('event.m');
      for (final k in const ['t', 'r', 'v']) {
        final x = e[k];
        if (x is! String || x.length % 4 != 0 || !_b64.hasMatch(x)) bad('event.$k');
      }
      meta.add(m);
      tpl.add(e['t']! as String);
      raw.add(e['r']! as String);
      vars.add(e['v']! as String);
    }
    final d = EventData._(
      schemaVersion: v,
      generatedAt: generatedAt,
      sourceCommit: commit,
      sourceDate: date,
      meta: meta,
      tpl: tpl,
      raw: raw,
      variants: vars,
    );
    // Cada evento tiene que poder leerse (tipos de cada campo).
    try {
      d.gifts;
    } on Object catch (e) {
      bad('event fields: $e');
    }
    return d;
  }
}

/// Base de eventos de PKHeX (carga perezosa: se decodifica al primer uso).
abstract final class EventDb {
  static EventData _data = EventData.builtin;

  /// Base en uso: la integrada o la última descargada.
  static EventData get data => _data;

  /// Cambia la base en uso (la app, al descargar una nueva).
  static void use(EventData d) {
    if (identical(d, _data)) return;
    _data = d;
    _bySpecies = null;
  }

  /// Vuelve a la copia integrada.
  static void reset() => use(EventData.builtin);

  /// Todos los eventos de Pokémon, en el orden de PKHeX (Gen 3 → Gen 9).
  static List<EventGift> get all => _data.gifts;

  static Map<int, List<EventGift>>? _bySpecies;

  /// Eventos de [species] (cualquier forma).
  static List<EventGift> forSpecies(int species) =>
      (_bySpecies ??= _index())[species] ?? const [];

  static Map<int, List<EventGift>> _index() {
    final m = <int, List<EventGift>>{};
    for (final g in all) {
      (m[g.species] ??= []).add(g);
    }
    return m;
  }

  /// Eventos que se pueden crear en una partida de [game] (mismo formato).
  static List<EventGift> creatableIn(GameVersion game) {
    if (game.isStorage || game.isColosseumOrXd) return const [];
    final f = PkFormat.forGame(game);
    return [for (final g in all) if (g.canCreate && g.format == f) g];
  }

  /// Especies que solo se obtienen por evento en algún juego y tienen eventos.
  static Set<int> get species => (_bySpecies ??= _index()).keys.toSet();

  /// Evento cuya tarjeta en bruto es exactamente [bytes] (para importar archivos).
  static EventGift? byRawCard(Uint8List bytes) {
    final b64 = base64Encode(bytes);
    for (final g in all) {
      if (_data._raw[g.id] == b64) return g;
    }
    return null;
  }
}

/// Filtro del explorador de eventos (todos los campos opcionales).
class EventFilter {
  const EventFilter({
    this.text = '',
    this.generation,
    this.game,
    this.year,
    this.region,
    this.language,
    this.shiny,
    this.distribution,
    this.creatableIn,
    this.species,
  });

  /// Texto: especie (es/en), título de la tarjeta, OT o nº de tarjeta.
  final String text;
  final int? generation;
  final GameVersion? game;
  final int? year;
  final EventRegion? region;
  final int? language;

  /// true = solo variocolor (o que pueden serlo); false = solo no variocolor.
  final bool? shiny;
  final EventDistribution? distribution;

  /// Solo los que se pueden crear en una partida de este juego.
  final GameVersion? creatableIn;
  final int? species;

  bool get isEmpty =>
      text.trim().isEmpty &&
      generation == null &&
      game == null &&
      year == null &&
      region == null &&
      language == null &&
      shiny == null &&
      distribution == null &&
      species == null;

  List<EventGift> apply(Iterable<EventGift> gifts, {required String Function(int species) nameEs, required String Function(int species) nameEn}) {
    final q = text.trim().toLowerCase();
    final f = creatableIn == null || creatableIn!.isStorage || creatableIn!.isColosseumOrXd ? null : PkFormat.forGame(creatableIn!);
    return [
      for (final g in gifts)
        if ((species == null || g.species == species) &&
            (generation == null || g.generation == generation) &&
            (game == null || g.games.contains(game)) &&
            (year == null || g.year == year) &&
            (region == null || g.regions.contains(region)) &&
            (language == null || g.languages.contains(language)) &&
            (shiny == null || (shiny! ? (g.shiny.isShiny || g.shiny == EventShiny.random) : !g.shiny.isShiny)) &&
            (distribution == null || g.distribution == distribution) &&
            (creatableIn == null || (f != null && g.canCreate && g.format == f)) &&
            (q.isEmpty || _text(g, q, nameEs, nameEn)))
          g,
    ];
  }

  static bool _text(EventGift g, String q, String Function(int) es, String Function(int) en) {
    if (es(g.species).toLowerCase().contains(q) || en(g.species).toLowerCase().contains(q)) return true;
    if (g.title.toLowerCase().contains(q)) return true;
    if (g.cardId > 0 && g.cardId.toString() == q) return true;
    final ot = g.fixedOtName ?? (g.recipientOt ? null : g.template()?.otName);
    if (ot != null && ot.toLowerCase().contains(q)) return true;
    return g.otByLanguage.values.any((o) => o.toLowerCase().contains(q));
  }
}

/// Nombre de idioma (ids de PKHeX `LanguageID`).
String eventLanguageName(int id, {bool es = true}) => switch (id) {
      1 => es ? 'Japonés' : 'Japanese',
      2 => es ? 'Inglés' : 'English',
      3 => es ? 'Francés' : 'French',
      4 => es ? 'Italiano' : 'Italian',
      5 => es ? 'Alemán' : 'German',
      7 => es ? 'Español' : 'Spanish',
      8 => es ? 'Coreano' : 'Korean',
      9 => es ? 'Chino simplificado' : 'Simplified Chinese',
      10 => es ? 'Chino tradicional' : 'Traditional Chinese',
      _ => '#$id',
    };
