import 'dart:typed_data';

import '../util/bytes.dart';

/// Región de un juego de GameCube (PKHeX `GCRegion`; el índice es el byte guardado).
enum GcRegion {
  none('—'),
  ntscJ('NTSC-J'),
  ntscU('NTSC-U'),
  pal('PAL');

  const GcRegion(this.label);
  final String label;

  static GcRegion fromByte(int b) => b >= 0 && b < values.length ? values[b] : none;

  /// Región según la última letra del código de juego (`GC6E` → NTSC-U).
  static GcRegion fromGameCode(String code) => switch (code.isEmpty ? '' : code[code.length - 1]) {
        'J' => ntscJ,
        'E' => ntscU,
        'P' => pal,
        _ => none,
      };
}

/// Juegos de Pokémon de GameCube que guardan en la Memory Card.
enum GcTitle {
  colosseum('GC6', 0x60000),
  xd('GXX', 0x56000),
  rsBox('GPX', 0x76000);

  const GcTitle(this.prefix, this.saveSize);

  /// Tres primeras letras del código de juego (la cuarta es la región).
  final String prefix;

  /// Tamaño de los datos del archivo (sin la cabecera GCI de 0x40).
  final int saveSize;

  static GcTitle? fromGameCode(String code) {
    if (code.length != 4) return null;
    for (final t in values) {
      if (code.startsWith(t.prefix) && const {'J', 'E', 'P'}.contains(code[3])) return t;
    }
    return null;
  }
}

String _ascii(Uint8List d, int ofs, int len) {
  final out = StringBuffer();
  for (var i = 0; i < len; i++) {
    final c = d[ofs + i];
    if (c == 0) break;
    out.writeCharCode(c);
  }
  return out.toString();
}

/// Entrada de directorio de la Memory Card (PKHeX `DEntry`, 0x40 bytes).
///
/// Es también la cabecera de un archivo `.gci`.
class GcDirEntry {
  GcDirEntry(this.raw, {this.index = -1}) : assert(raw.length == size);

  static const int size = 0x40;

  /// Copia de los 0x40 bytes.
  final Uint8List raw;

  /// Posición en el directorio de la tarjeta (-1 en un `.gci`).
  final int index;

  String get gameCode => _ascii(raw, 0, 4);
  String get makerCode => _ascii(raw, 4, 2);
  String get fileName => _ascii(raw, 8, 0x20);
  int get modificationTime => raw.u32be(0x28);
  int get firstBlock => raw.u16be(0x36);
  int get blockCount => raw.u16be(0x38);
  int get dataLength => blockCount * GcMemoryCard.blockSize;

  bool get isEmpty {
    final v = raw.u32be(0);
    return v == 0 || v == 0xFFFFFFFF;
  }

  GcTitle? get title => GcTitle.fromGameCode(gameCode);
  GcRegion get region => GcRegion.fromGameCode(gameCode);

  /// Nombre con el que Dolphin exporta el archivo (`01-GC6E-<archivo>.gci`).
  String get standardFileName {
    final name = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return '$makerCode-$gameCode-$name.gci';
  }
}

/// Archivo `.gci` (cabecera `DEntry` de 0x40 + bloques de datos), tal como lo
/// exporta el gestor de Memory Card de Dolphin o la carpeta GCI.
abstract final class GciFile {
  static const int headerSize = GcDirEntry.size;

  /// Cabecera si [d] es un `.gci` de un juego de Pokémon con el tamaño esperado.
  static GcDirEntry? parse(Uint8List d) {
    if (d.length < headerSize + GcMemoryCard.blockSize) return null;
    final e = GcDirEntry(d.copyRange(0, headerSize));
    final t = e.title;
    if (t == null) return null;
    if (e.blockCount * GcMemoryCard.blockSize != t.saveSize) return null;
    if (d.length != headerSize + t.saveSize) return null;
    return e;
  }
}

/// Imagen completa de una Memory Card (`.raw` de Dolphin, `.gcp`, `.mci`…).
///
/// Bloques de 0x2000: 0 cabecera, 1–2 directorio (y copia), 3–4 tabla de
/// bloques (BAT) y copia; los datos empiezan en el bloque 5. Cada archivo es
/// una cadena de bloques en la BAT. Portado de PKHeX `SAV3GCMemoryCard` y del
/// formato documentado por Dolphin (`GCMemcard`), siguiendo las cadenas de la
/// BAT en vez de suponer bloques contiguos.
class GcMemoryCard {
  GcMemoryCard._(this.data, this._dirBlock, this._batBlock);

  static const int blockSize = 0x2000;
  static const int _firstDataBlock = 5;
  static const int _entries = 127;

  final Uint8List data;
  final int _dirBlock;
  final int _batBlock;

  int get blockCount => data.length ~/ blockSize;

  /// Tamaño razonable: potencia de 2 entre 512 KB (59 bloques) y 16 MB (2043).
  static bool isCardSize(int n) => n >= 0x80000 && n <= 0x1000000 && (n & (n - 1)) == 0;

  /// (suma, suma inversa) de palabras de 16 bits big endian (0xFFFF → 0).
  static (int, int) checksum(Uint8List d, int ofs, int len) {
    var c = 0, inv = 0;
    for (var i = ofs; i < ofs + len; i += 2) {
      final v = d.u16be(i);
      c = (c + v) & 0xFFFF;
      inv = (inv + (~v & 0xFFFF)) & 0xFFFF;
    }
    if (c == 0xFFFF) c = 0;
    if (inv == 0xFFFF) inv = 0;
    return (c, inv);
  }

  static bool _sumOk(Uint8List d, int ofs, int len, int at) {
    final (c, inv) = checksum(d, ofs, len);
    return d.u16be(at) == c && d.u16be(at + 2) == inv;
  }

  static bool _dirOk(Uint8List d, int block) => _sumOk(d, block * blockSize, 0x1FFC, block * blockSize + 0x1FFC);
  static bool _batOk(Uint8List d, int block) => _sumOk(d, block * blockSize + 4, 0x1FFC, block * blockSize);

  /// Interpreta [d] como Memory Card, o null si no lo es (tamaño, cabecera o
  /// sumas del directorio y la BAT).
  static GcMemoryCard? tryParse(Uint8List d) {
    if (!isCardSize(d.length)) return null;
    if (d.u32be(0) == 0xFFFFFFFF && d.u32be(4) == 0xFFFFFFFF) return null;
    final mbit = d.length ~/ blockSize ~/ 0x10;
    if (d.u16be(0x22) != mbit) return null;
    if (!_sumOk(d, 0, 0x1FC, 0x1FC)) return null;
    int? pick(bool Function(Uint8List, int) ok, int a, int b, int counterOfs) {
      final okA = ok(d, a), okB = ok(d, b);
      if (okA && okB) {
        return d.u16be(b * blockSize + counterOfs) > d.u16be(a * blockSize + counterOfs) ? b : a;
      }
      return okA ? a : (okB ? b : null);
    }

    final dir = pick(_dirOk, 1, 2, 0x1FFA);
    final bat = pick(_batOk, 3, 4, 4);
    if (dir == null || bat == null) return null;
    return GcMemoryCard._(d, dir, bat);
  }

  /// Entradas ocupadas del directorio activo.
  List<GcDirEntry> get entries => [
        for (var i = 0; i < _entries; i++)
          if (GcDirEntry(data.copyRange(_dirBlock * blockSize + i * GcDirEntry.size, GcDirEntry.size), index: i)
              case final e when !e.isEmpty)
            e,
      ];

  /// Entradas de juegos de Pokémon cuyo archivo se puede leer entero.
  List<GcDirEntry> get pokemonEntries => [
        for (final e in entries)
          if (e.title != null && e.dataLength == e.title!.saveSize && blocksOf(e) != null) e,
      ];

  int _next(int block) => data.u16be(_batBlock * blockSize + 0x0A + (block - _firstDataBlock) * 2);

  /// Bloques del archivo siguiendo la BAT, o null si la cadena está rota.
  List<int>? blocksOf(GcDirEntry e) {
    final out = <int>[];
    var b = e.firstBlock;
    for (var i = 0; i < e.blockCount; i++) {
      if (b < _firstDataBlock || b >= blockCount || out.contains(b)) return null;
      out.add(b);
      if (i < e.blockCount - 1) b = _next(b);
    }
    return out;
  }

  /// Datos del archivo (sin cabecera).
  Uint8List read(GcDirEntry e) {
    final blocks = blocksOf(e) ?? (throw StateError('Cadena de bloques rota en la Memory Card.'));
    final out = Uint8List(blocks.length * blockSize);
    for (var i = 0; i < blocks.length; i++) {
      out.setRange(i * blockSize, (i + 1) * blockSize, data, blocks[i] * blockSize);
    }
    return out;
  }

  /// Copia de la tarjeta con el archivo [e] reemplazado por [content] (mismo
  /// tamaño). El directorio y la BAT no cambian, así que sus sumas siguen
  /// siendo válidas.
  Uint8List withFile(GcDirEntry e, Uint8List content) {
    final blocks = blocksOf(e) ?? (throw StateError('Cadena de bloques rota en la Memory Card.'));
    if (content.length != blocks.length * blockSize) {
      throw ArgumentError('El archivo cambió de tamaño (${content.length} ≠ ${blocks.length * blockSize}).');
    }
    final out = Uint8List.fromList(data);
    for (var i = 0; i < blocks.length; i++) {
      out.setRange(blocks[i] * blockSize, (blocks[i] + 1) * blockSize, content, i * blockSize);
    }
    return out;
  }

  /// Si [bytes] es una Memory Card con más de un save de Pokémon (p. ej.
  /// Colosseum y XD), cada uno como `.gci` con su nombre estándar; si no, null.
  static List<(String, Uint8List)>? splitPokemonSaves(Uint8List bytes) {
    final card = tryParse(bytes);
    if (card == null) return null;
    final entries = [for (final e in card.pokemonEntries) if (e.title != GcTitle.rsBox) e];
    if (entries.length < 2) return null;
    return [for (final e in entries) (e.standardFileName, card.exportGci(e))];
  }

  /// Exporta una entrada como `.gci` (cabecera + datos).
  Uint8List exportGci(GcDirEntry e) {
    final body = read(e);
    return Uint8List(GciFile.headerSize + body.length)
      ..setRange(0, GciFile.headerSize, e.raw)
      ..setRange(GciFile.headerSize, GciFile.headerSize + body.length, body);
  }
}

/// Cómo venía guardado un save de GameCube, para reconstruir el mismo contenedor.
enum GcContainerKind { raw, gci, memoryCard }

class GcContainer {
  const GcContainer._(this.kind, this.entry, this.card);

  /// Datos del save sin cabecera (p. ej. extraídos con otra herramienta).
  const GcContainer.raw() : this._(GcContainerKind.raw, null, null);

  /// `.gci` con su cabecera de 0x40 bytes.
  GcContainer.gci(GcDirEntry header) : this._(GcContainerKind.gci, header, null);

  /// Archivo dentro de una imagen de Memory Card.
  GcContainer.card(GcMemoryCard card, GcDirEntry entry) : this._(GcContainerKind.memoryCard, entry, card);

  final GcContainerKind kind;
  final GcDirEntry? entry;
  final GcMemoryCard? card;

  /// Código de juego (`GC6E`, `GXXP`…) si el contenedor lo indica.
  String? get gameCode => entry?.gameCode;

  /// Vuelve a meter los datos del save en el mismo contenedor.
  Uint8List wrap(Uint8List payload) => switch (kind) {
        GcContainerKind.raw => payload,
        GcContainerKind.gci => Uint8List(GciFile.headerSize + payload.length)
          ..setRange(0, GciFile.headerSize, entry!.raw)
          ..setRange(GciFile.headerSize, GciFile.headerSize + payload.length, payload),
        GcContainerKind.memoryCard => card!.withFile(entry!, payload),
      };

  String get description => switch (kind) {
        GcContainerKind.raw => 'datos sin cabecera GCI',
        GcContainerKind.gci => 'GCI ${entry!.gameCode} (${entry!.region.label})',
        GcContainerKind.memoryCard =>
          'Memory Card ${card!.blockCount - 5} bloques, ${entry!.gameCode} (${entry!.region.label})',
      };

  /// Busca un save de [title] en [bytes]: `.gci`, imagen de Memory Card
  /// (la primera entrada de ese juego) o datos sin cabecera del tamaño exacto.
  /// Devuelve (contenedor, datos del save).
  static (GcContainer, Uint8List)? find(Uint8List bytes, {Set<GcTitle>? titles}) {
    final gci = GciFile.parse(bytes);
    if (gci != null && (titles == null || titles.contains(gci.title))) {
      return (GcContainer.gci(gci), bytes.view(GciFile.headerSize, bytes.length - GciFile.headerSize));
    }
    final card = GcMemoryCard.tryParse(bytes);
    if (card != null) {
      for (final e in card.pokemonEntries) {
        if (titles == null || titles.contains(e.title)) return (GcContainer.card(card, e), card.read(e));
      }
    }
    return null;
  }
}
