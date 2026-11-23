import 'db/arca_database.dart';

/// De dónde salió una copia: se deduce del contenedor del save, de su ruta de
/// origen y del nombre del archivo (nunca se pregunta al usuario).
enum SaveSource {
  /// Emulador de escritorio (mGBA, melonDS, DeSmuME, Azahar, Ryujinx…).
  emulator,

  /// Emulador o port en Android/iOS (Delta, DraStic, Pizza Boy, Eden…).
  mobile,

  /// Export de Checkpoint o JKSM (3DS/Switch con homebrew).
  checkpoint,

  /// Volcado de cartucho (GBxCart, GB Operator, Joey Jr…).
  cartridge,

  /// No se puede saber (archivo suelto, demo, restauración…).
  other;

  static final _checkpoint = RegExp(r'checkpoint|jksm', caseSensitive: false);
  static final _cartridge = RegExp(
      r'gbxcart|flashgbx|gb ?operator|joey|epilogue|cart(ridge)?[ _-]?(dump|reader)|cartucho|retrode|sanni',
      caseSensitive: false);
  static final _mobile = RegExp(
      r'^content://|/android/|/storage/emulated/|/var/mobile/|file provider storage|/mobile/containers/'
      r'|delta|drastic|my ?boy|my ?oldboy|pizza ?boy|lemuroid|john ?gba|nostalgia|citra ?mmj|lime3ds.?android'
      r'|egg ?ns|skyline|strato|yuzu.?android|eden.?android|sudachi.?android|citron.?android|retroarch.?(android|ios)',
      caseSensitive: false);
  static final _emulator = RegExp(
      r'desmume|emulador|emulator|retroarch|mgba|melonds|no\$gba|visualboy|vba|bgb|sameboy|gambatte|citra|azahar'
      r'|lime3ds|panda3ds|yuzu|eden|sudachi|citron|ryujinx|suyu|nand/user/save|bis/user/save|\.srm$|\.dsv$',
      caseSensitive: false);

  /// Clasifica una copia. [origin] es el código de `Snapshot.origin`.
  static SaveSource classify({String? formatInfo, String? sourcePath, String? fileName, String? origin}) {
    final hay = [formatInfo, sourcePath, fileName].whereType<String>().join('\n');
    if (origin == 'demo') return other;
    if (_checkpoint.hasMatch(hay)) return checkpoint;
    if (_cartridge.hasMatch(hay)) return cartridge;
    if (_mobile.hasMatch(sourcePath ?? '') || _mobile.hasMatch(fileName ?? '') || origin == 'saf') return mobile;
    if (_emulator.hasMatch(hay)) return emulator;
    return other;
  }

  static SaveSource ofSnapshot(Snapshot s) =>
      classify(formatInfo: s.formatInfo, sourcePath: s.sourcePath, fileName: s.fileName, origin: s.origin);
}
