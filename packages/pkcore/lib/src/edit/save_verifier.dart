import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../crypto/meme_crypto.dart';
import '../crypto/swish_crypto.dart';
import '../detect/save_detector.dart';
import '../formats/ctr_saves.dart';
import '../model/game.dart';
import '../model/save.dart';
import '../util/bytes.dart';
import '../util/checksums.dart';
import 'ctr_editors.dart';
import 'save_editor.dart';

/// La comprobación posterior a la exportación encontró problemas: el archivo
/// no se entrega al usuario.
class SaveVerificationException implements Exception {
  const SaveVerificationException(this.problems);
  final List<String> problems;

  @override
  String toString() => 'SaveVerificationException: ${problems.join('; ')}';
}

/// Comprobaciones de integridad de un archivo de save ya construido.
///
/// * [checksums]: recalcula todas las sumas del formato (CRC por sector o por
///   bloque, tabla BEEF de 3DS/Let's Go, MD5 de BDSP, SHA-256 de SwishCrypto).
/// * [verifyExport]: relee el archivo exportado con un editor nuevo y compara
///   entrenador, equipo, cajas, inventario, Pokédex y eventos con el editor de
///   origen.
/// Parte del save a la que afecta un [ChecksumProblem].
enum SavePart {
  /// El archivo entero o una parte que el formato no permite precisar.
  whole,

  /// Datos del entrenador (nombre, ID, tiempo de juego…).
  trainer,

  /// Equipo.
  party,

  /// Cajas.
  boxes,

  /// Otros datos de la partida (objetos, Pokédex, eventos…).
  other,

  /// Firma digital del save (MemeCrypto de Sol/Luna y Ultrasol/Ultraluna).
  signature,

  /// Hash de verificación del archivo completo (SHA-256 de Switch, MD5 de DBPR).
  fileHash,
}

/// Un checksum que no coincide: qué parte afecta y el detalle técnico.
class ChecksumProblem {
  const ChecksumProblem(this.part, this.detail, {this.block});

  final SavePart part;

  /// Índice del bloque (3DS/Let's Go), si aplica.
  final int? block;

  /// Descripción técnica (para usuarios avanzados y registros).
  final String detail;

  @override
  String toString() => detail;
}

abstract final class SaveVerifier {
  /// Problemas de checksum del archivo completo (lista vacía = correcto).
  static List<String> checksums(Uint8List file) => [for (final p in checksumProblems(file)) p.detail];

  /// Como [checksums], con la parte del save afectada por cada problema.
  static List<ChecksumProblem> checksumProblems(Uint8List file) {
    final Detection det;
    try {
      det = SaveDetector.detect(file);
    } on Object catch (e) {
      return [ChecksumProblem(SavePart.whole, 'El archivo no se reconoce como save: $e')];
    }
    final d = det.payload;
    final problems = <ChecksumProblem>[];
    switch (det.game) {
      case GameVersion.xy || GameVersion.omegaRubyAlphaSapphire || GameVersion.sunMoon || GameVersion.ultraSunUltraMoon:
        final blocks = switch (det.game) {
          GameVersion.xy => CtrBlocks.xy,
          GameVersion.omegaRubyAlphaSapphire => CtrBlocks.oras,
          GameVersion.sunMoon => CtrBlocks.sm,
          _ => CtrBlocks.usum,
        };
        final gen7 = det.game.generation == 7;
        // SM/USUM: el juego calcula el CRC del bloque 36 con la firma a cero y la
        // escribe después (PKHeX `SAV7.ClearMemeCrypto`).
        final data = Uint8List.fromList(d);
        MemeCrypto.clearSave(data, det.game);
        final layout = CtrLayout.all.firstWhere((l) => l.game == det.game);
        problems.addAll(_beef(data, blocks, d.length - 0x200,
            (b, s, e) => gen7 ? (~Checksums.crc16Arc(b, s, e, 0xFFFF)) & 0xFFFF : Checksums.crc16Ccitt(b, s, e),
            (ofs, len) => _ctrPart(layout, ofs, len)));
        if (gen7 && !MemeCrypto.isSaveSignatureValid(d, det.game)) {
          problems.add(const ChecksumProblem(
              SavePart.signature, 'La firma MemeCrypto (bloque 36) no corresponde a la tabla de checksums.'));
        }
      case GameVersion.letsGo:
        problems.addAll(_beef(d, CtrBlocks.lgpe, 0xB8800 - 0x200, (b, s, e) => Checksums.crc16Arc(b, s, e, 0),
            (ofs, len) => _lgpePart(ofs)));
      case GameVersion.brilliantDiamondShiningPearl:
        const hash = 0xE9818;
        if (d.length >= hash + 0x10) {
          final copy = Uint8List.fromList(d)..fillRange(hash, hash + 0x10, 0);
          final digest = md5.convert(copy).bytes;
          for (var i = 0; i < 0x10; i++) {
            if (digest[i] != d[hash + i]) {
              problems.add(const ChecksumProblem(SavePart.fileHash, 'El MD5 del save de DBPR no coincide.'));
              break;
            }
          }
        }
      case GameVersion.swordShield || GameVersion.legendsArceus || GameVersion.scarletViolet || GameVersion.legendsZA:
        if (!SwishCrypto.isHashValid(d)) {
          problems.add(const ChecksumProblem(SavePart.fileHash, 'El SHA-256 de SwishCrypto no coincide.'));
        }
      default:
        try {
          if (det.read().checksum == ChecksumStatus.invalid) {
            problems.add(const ChecksumProblem(SavePart.whole, 'Las sumas de comprobación no son válidas.'));
          }
        } on Object catch (e) {
          problems.add(ChecksumProblem(SavePart.whole, 'El save no se puede leer: $e'));
        }
    }
    return problems;
  }

  static SavePart _ctrPart(CtrLayout l, int ofs, int len) {
    bool hits(int x) => x >= ofs && x < ofs + len;
    if (hits(l.box) || (ofs >= l.box && ofs < l.box + l.boxCount * 30 * 0xE8)) return SavePart.boxes;
    if (hits(l.party)) return SavePart.party;
    if (hits(l.myStatus) || hits(l.playTime)) return SavePart.trainer;
    return SavePart.other;
  }

  static SavePart _lgpePart(int ofs) => switch (ofs) {
        0x05C00 => SavePart.boxes,
        0x01000 || 0x01200 => SavePart.trainer,
        _ => SavePart.other,
      };

  static List<ChecksumProblem> _beef(Uint8List d, List<(int, int)> blocks, int bo,
      int Function(Uint8List, int, int) crc, SavePart Function(int ofs, int len) part) {
    final out = <ChecksumProblem>[];
    if (bo < 0 || bo + 0x14 + blocks.length * 8 > d.length) {
      return [const ChecksumProblem(SavePart.whole, 'Tabla de bloques fuera del archivo.')];
    }
    for (var i = 0; i < blocks.length; i++) {
      final (ofs, len) = blocks[i];
      if (ofs + len > d.length) continue;
      final stored = d.u16le(bo + 0x14 + i * 8 + 6);
      final actual = crc(d, ofs, ofs + len);
      if (stored != actual) {
        out.add(ChecksumProblem(
          part(ofs, len),
          'Checksum del bloque $i (0x${ofs.toRadixString(16).toUpperCase()}, '
          '0x${len.toRadixString(16).toUpperCase()} bytes) incorrecto: '
          'guardado 0x${stored.toRadixString(16).toUpperCase().padLeft(4, '0')}, '
          'calculado 0x${actual.toRadixString(16).toUpperCase().padLeft(4, '0')}.',
          block: i,
        ));
      }
    }
    return out;
  }

  /// Relee [file] y comprueba que contiene exactamente lo que tiene [source].
  static List<String> verifyExport(SaveEditor source, Uint8List file) {
    final problems = [...checksums(file)];
    if (problems.isNotEmpty) return problems;
    final SaveEditor re;
    try {
      re = SaveEditor.open(file);
    } on Object catch (e) {
      return ['El archivo exportado no se puede abrir: $e'];
    }
    if (re.game != source.game) problems.add('El archivo exportado se detecta como ${re.game.nameEs}.');
    void check(String what, bool Function() same) {
      try {
        if (!same()) problems.add('$what no coincide al releer.');
      } on Object catch (e) {
        problems.add('$what no se puede releer: $e');
      }
    }

    check('El entrenador', () => re.readTrainer() == source.readTrainer());
    check('El equipo', () {
      if (re.partyCount != source.partyCount) return false;
      for (var i = 0; i < re.partyCount; i++) {
        if (!_same(re.readPartySlot(i).data, source.readPartySlot(i).data)) return false;
      }
      return true;
    });
    check('Las cajas', () {
      if (re.boxCount != source.boxCount) return false;
      for (var b = 0; b < re.boxCount; b++) {
        for (var s = 0; s < re.boxSlotCount; s++) {
          final x = re.readBoxSlot(b, s), y = source.readBoxSlot(b, s);
          if ((x == null) != (y == null)) return false;
          if (x != null && !_same(x.data, y!.data)) return false;
        }
      }
      return true;
    });
    check('El inventario', () {
      final a = re.readInventory(), b = source.readInventory();
      if ((a == null) != (b == null)) return false;
      if (a == null) return true;
      if (a.length != b!.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i].type != b[i].type || a[i].items.length != b[i].items.length) return false;
        for (var j = 0; j < a[i].items.length; j++) {
          if (a[i].items[j] != b[i].items[j]) return false;
        }
      }
      return true;
    });
    check('La Pokédex', () {
      final a = re.pokedex, b = source.pokedex;
      if ((a == null) != (b == null)) return false;
      if (a == null) return true;
      for (final s in b!.species) {
        if (a.entry(s) != b.entry(s)) return false;
      }
      return true;
    });
    check('Los eventos', () {
      final a = re.events, b = source.events;
      if ((a == null) != (b == null)) return false;
      if (a == null) return true;
      if (a.flagCount != b!.flagCount || a.workCount != b.workCount) return false;
      for (var i = 0; i < a.flagCount; i++) {
        if (a.getFlag(i) != b.getFlag(i)) return false;
      }
      for (var i = 0; i < a.workCount; i++) {
        if (a.getWork(i) != b.getWork(i)) return false;
      }
      return true;
    });
    return problems;
  }

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
