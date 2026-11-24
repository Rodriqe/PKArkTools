import 'dart:typed_data';

import '../crypto/sc_block.dart';
import '../crypto/swish_crypto.dart';
import '../formats/ctr_saves.dart';
import '../formats/gb_saves.dart';
import '../formats/gc_container.dart';
import '../formats/gc_saves.dart';
import '../formats/rsbox.dart';
import '../formats/stadium.dart';
import '../edit/storage_editors.dart';
import '../formats/gen3.dart';
import '../formats/nds_saves.dart';
import '../formats/switch_saves.dart';
import '../model/game.dart';
import '../model/save.dart';
import '../util/bytes.dart';

/// Resultado de la detección de formato (sin parsear el contenido completo).
class Detection {
  const Detection._(this.game, this.container, this.payload, this._read, [this.rewrap, this.warnings = const []]);

  final GameVersion game;

  /// Contenedor/variación detectada (p. ej. "DeSmuME .dsv", "pie RTC de emulador").
  final String? container;

  /// Bytes del save sin cabeceras/pies de emulador.
  final Uint8List payload;
  final SaveFile Function() _read;

  /// Vuelve a meter un [payload] editado en el contenedor original cuando no
  /// basta con añadir un pie (cabecera GCI, archivo dentro de una Memory
  /// Card). null = el contenedor es el payload más un pie opcional.
  final Uint8List Function(Uint8List payload)? rewrap;

  /// Avisos de la detección (p. ej. varios saves en una Memory Card).
  final List<String> warnings;

  SaveFile read() => _read();
}

/// Punto de entrada: identifica la generación y el juego de un archivo de save.
///
/// La lógica de identificación sigue a PKHeX.Core `SaveUtil` (GPL-3.0):
/// tamaño exacto + firmas + checksums/estructura.
abstract final class SaveDetector {
  /// Tamaño máximo razonable para un save (los de SV con DLC rondan 4.5 MB).
  static const int maxSize = 16 * 1024 * 1024;

  /// Pistas rápidas de tamaño para filtrar archivos al escanear carpetas.
  static bool isPlausibleSize(int size) {
    if (size < 0x2000 || size > maxSize) return false;
    return true;
  }

  /// Detecta el formato. Lanza [UnsupportedSaveException] si no se reconoce.
  static Detection detect(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const UnsupportedSaveException('El archivo está vacío.', size: 0);
    }
    if (bytes.length > maxSize) {
      throw UnsupportedSaveException(
          'El archivo es demasiado grande para ser un save (${_fmtSize(bytes.length)}).',
          size: bytes.length);
    }

    // 1) Contenedores de emulador.
    var data = bytes;
    String? container;
    const desmumeFooter = 0x7A;
    if (data.length == 0x80000 + desmumeFooter && data.endsWithAscii('|-DESMUME SAVE-|')) {
      data = data.view(0, 0x80000);
      container = 'DeSmuME (.dsv)';
    } else {
      final footer = data.length & 0x3F;
      final plausible = footer == 0x07 || (footer.isEven && footer >= 0x0C && footer <= 0x30);
      final base = data.length - footer;
      if (footer != 0 && plausible && (base == 0x20000 || base == 0x10000 || base == 0x8000)) {
        data = data.view(0, base);
        container = 'Pie RTC de emulador (${footer}B)';
      }
    }

    final d = data;
    Detection hit(GameVersion g, SaveFile Function() read) => Detection._(g, container, d, read);

    // GameCube: .gci, imagen de Memory Card o datos sin cabecera de Colosseum/XD.
    final gc = _detectGameCube(bytes);
    if (gc != null) return gc;

    // 2) Game Boy / Game Boy Color.
    if (d.length == 0x8000) {
      if (isGbListValid(d, 0x2ED5, 30) && isGbListValid(d, 0x302D, 30)) {
        final yellow = _isYellow(d[0x29B9], d[0x2712]);
        return hit(yellow ? GameVersion.yellow : GameVersion.redBlue,
            () => GbSaveReader.readGen1(d, Gen1Layout.japanese, yellow: yellow));
      }
      if (isGbListValid(d, 0x2F2C, 20) && isGbListValid(d, 0x30C0, 20)) {
        final yellow = _isYellow(d[0x29C3], d[0x271C]);
        return hit(yellow ? GameVersion.yellow : GameVersion.redBlue,
            () => GbSaveReader.readGen1(d, Gen1Layout.international, yellow: yellow));
      }
    }
    if (d.length == 0x8000 || d.length == 0x10000) {
      final candidates = <(int, int, int, Gen2Layout)>[
        (0x288A, 0x2D6C, 20, Gen2Layout.goldSilverIntl),
        (0x2865, 0x2D10, 20, Gen2Layout.crystalIntl),
        (0x2D10, 0x283E, 30, Gen2Layout.goldSilverJp),
        (0x2D10, 0x281A, 30, Gen2Layout.crystalJp),
        (0x2DAE, 0x28CC, 20, Gen2Layout.goldSilverKor),
      ];
      for (final (a, b, max, layout) in candidates) {
        if (isGbListValid(d, a, max) && isGbListValid(d, b, max)) {
          return hit(layout.crystal ? GameVersion.crystal : GameVersion.goldSilver,
              () => GbSaveReader.readGen2(d, layout));
        }
      }
    }

    // 3) Game Boy Advance.
    if (d.length == 0x20000 || d.length == 0x10000) {
      final slots = d.length ~/ 0x10000;
      for (var slot = 0; slot < slots && slot < 2; slot++) {
        final s0 = Gen3.sector0IfComplete(d, slot);
        if (s0 != null) {
          final small = d.view(s0, Gen3.sectorUsed);
          return hit(Gen3.versionFromSmall(small), () => Gen3.read(d));
        }
      }
    }

    // Pokémon Stadium / Stadium 2 (N64): firmas «POKE»/«P3v0» al final de cada lista.
    if (StadiumLayout.detect(d) case (final l, final swapped)) {
      final g = l.generation == 1 ? GameVersion.stadium : GameVersion.stadium2;
      return hit(g, () {
        final ed = StadiumEditor(d, l, swapped: swapped);
        final teams = ed.teams.where((t) => t.$2.isNotEmpty).length;
        return storageSummary(ed, d,
            format: 'N64 ${l.label}${swapped ? ', bytes invertidos' : ''}',
            checksumOk: ed.checksumsValid,
            warnings: [if (teams > 0) 'Equipos registrados: $teams (solo lectura).']);
      });
    }

    // 4) Nintendo DS.
    if (d.length == 0x80000) {
      for (final l in Gen4Layout.all) {
        if (l.matches(d)) return hit(l.game, () => NdsSaveReader.readGen4(d, l));
      }
      for (final l in Gen5Layout.all) {
        if (l.matches(d)) return hit(l.game, () => NdsSaveReader.readGen5(d, l));
      }
    }

    // 5) Nintendo 3DS.
    for (final l in CtrLayout.all) {
      if (l.matches(d)) return hit(l.game, () => CtrSaveReader.read(d, l));
    }

    // 6) Nintendo Switch.
    if (SwitchSaveReader.isLetsGo(d)) return hit(GameVersion.letsGo, () => SwitchSaveReader.readLetsGo(d));
    if (SwitchSaveReader.isBdsp(d)) {
      return hit(GameVersion.brilliantDiamondShiningPearl, () => SwitchSaveReader.readBdsp(d));
    }
    if (d.length > SwishCrypto.hashSize + 5 && SwishCrypto.isHashValid(d)) {
      final SCBlockSet blocks;
      try {
        blocks = SCBlockSet(SwishCrypto.decrypt(d));
      } on FormatException catch (e) {
        throw UnsupportedSaveException(
            'El hash SwishCrypto es válido pero los bloques no se pudieron leer: ${e.message}',
            size: d.length);
      }
      final game = classifySwishBlocks(blocks, d.length);
      if (game == null) {
        throw UnsupportedSaveException(
            'Save cifrado de Switch reconocido (SwishCrypto), pero no corresponde a un juego conocido.',
            size: d.length);
      }
      return hit(game, () => SwitchSaveReader.readSwish(d, blocks, game));
    }

    throw UnsupportedSaveException(_explain(bytes.length), size: bytes.length);
  }

  static Detection? _detectGameCube(Uint8List bytes) {
    const titles = {GcTitle.colosseum, GcTitle.xd, GcTitle.rsBox};
    GcContainer? container;
    Uint8List? payload;
    final warnings = <String>[];
    final found = GcContainer.find(bytes, titles: titles);
    if (found != null) {
      (container, payload) = found;
      final card = container.card;
      if (card != null) {
        final others = card.pokemonEntries.where((e) => e.index != container!.entry!.index).toList();
        if (others.isNotEmpty) {
          warnings.add('La Memory Card tiene ${others.length + 1} saves de Pokémon; se abre el de '
              '${container.entry!.gameCode} (${others.map((e) => e.gameCode).join(', ')} '
              'se pueden importar por separado).');
        }
      }
    } else if (RsBoxData.identify(bytes)) {
      container = const GcContainer.raw();
      payload = bytes;
    } else {
      final title = GcSaveData.identifyRaw(bytes);
      if (title == null) return null;
      container = const GcContainer.raw();
      payload = bytes;
    }
    final title = container.entry?.title ?? (RsBoxData.identify(payload) ? GcTitle.rsBox : GcSaveData.identifyRaw(payload));
    if (title == null || payload.length != title.saveSize) return null;
    final c = container;
    final p = payload;
    final game = switch (title) {
      GcTitle.colosseum => GameVersion.colosseum,
      GcTitle.xd => GameVersion.xd,
      GcTitle.rsBox => GameVersion.boxRS,
    };
    return Detection._(
      game,
      c.kind == GcContainerKind.raw ? null : c.description,
      p,
      () {
        final s = title == GcTitle.rsBox
            ? storageSummary(RsBoxEditor(p), p,
                format: 'GameCube Box Rubí/Zafiro ${c.entry?.region.label ?? ''}'.trim(),
                checksumOk: RsBoxData.open(p).checksumsValid)
            : GcSaveReader.read(p, title, c);
        if (warnings.isEmpty) return s;
        return SaveFile(
          game: s.game,
          versionId: s.versionId,
          trainer: s.trainer,
          raw: s.raw,
          format: s.format,
          party: s.party,
          boxes: s.boxes,
          support: s.support,
          checksum: s.checksum,
          warnings: [...s.warnings, ...warnings],
        );
      },
      c.kind == GcContainerKind.raw ? null : c.wrap,
      warnings,
    );
  }

  /// Detecta y lee el resumen completo.
  static SaveFile read(Uint8List bytes) {
    final det = detect(bytes);
    try {
      final save = det.read();
      if (det.container == null) return save;
      return SaveFile(
        game: save.game,
        versionId: save.versionId,
        trainer: save.trainer,
        raw: bytes,
        format: '${save.format} · ${det.container}',
        party: save.party,
        boxes: save.boxes,
        support: save.support,
        checksum: save.checksum,
        warnings: save.warnings,
      );
    } on RangeError catch (e) {
      throw CorruptSaveException(det.game, 'Datos fuera de rango al leer: ${e.message}${_versionHint(det.game)}');
    } on FormatException catch (e) {
      throw CorruptSaveException(det.game, '${e.message}${_versionHint(det.game)}');
    }
  }

  /// En los juegos que aún reciben actualizaciones, un bloque con otro tamaño
  /// suele ser una versión del juego más nueva que la app.
  static String _versionHint(GameVersion g) => g == GameVersion.legendsZA
      ? ' (save de Leyendas Pokémon Z-A con un formato que esta versión de la app no sabe leer: '
          'probablemente de una actualización o DLC más nuevos del juego)'
      : '';

  static bool _isYellow(int starter, int friendship) =>
      starter != 0 ? starter == 0x54 : friendship != 0;

  static String _fmtSize(int n) {
    if (n >= 1024 * 1024) return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (n >= 1024) return '${(n / 1024).toStringAsFixed(n % 1024 == 0 ? 0 : 1)} KB';
    return '$n B';
  }

  static String _explain(int size) {
    final s = _fmtSize(size);
    final hint = switch (size) {
      0x8000 => 'Tiene el tamaño de un save de Game Boy, pero las listas de Pokémon no son válidas (¿save vacío o de otro juego?).',
      0x10000 || 0x20000 => 'Tiene el tamaño de un save de GBA, pero faltan sectores válidos (¿save vacío o de otro juego?).',
      0x80000 => 'Tiene el tamaño de un save de NDS, pero los pies de bloque no coinciden con Gen 4 ni Gen 5.',
      _ when size > 0x100000 => 'Parece un save de Switch, pero el hash SwishCrypto no es válido (¿archivo "backup" o dañado?).',
      _ => 'El tamaño no coincide con ningún save conocido.',
    };
    return 'No se reconoce el formato ($s). $hint';
  }
}
