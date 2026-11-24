/// Núcleo de PKArkTools: detección, lectura y (en fases futuras) escritura
/// de partidas guardadas de Pokémon de todas las generaciones.
///
/// Dart puro, sin dependencias de Flutter.
library;

export 'src/crypto/pk_crypto.dart' show PkCrypto;
export 'src/crypto/sc_block.dart' show SCBlock, SCBlockSet, SCTypeCode, SCXorShift32;
export 'src/crypto/gc_crypto.dart' show ColoCrypto, XdCrypto, GeniusCrypto;
export 'src/crypto/meme_crypto.dart' show MemeCrypto;
export 'src/crypto/swish_crypto.dart' show SwishCrypto;
export 'src/data/forms.dart';
export 'src/data/game_data.dart';
export 'src/data/species.dart';
export 'src/data/species_convert.dart';
export 'src/detect/save_detector.dart';
export 'src/dex/dex_forms.dart';
export 'src/dex/dex_scan.dart';
export 'src/dex/evolutions.dart';
export 'src/dex/global_dex.dart';
export 'src/dex/special_forms.dart';
export 'src/legal/balls.dart';
export 'src/legal/encounters.dart';
export 'src/legal/gc_legality.dart';
export 'src/legal/legality.dart';
export 'src/legal/origin.dart';
export 'src/legal/plus_moves.dart';
export 'src/legal/ribbons.dart';
export 'src/edit/events.dart';
export 'src/edit/gc_editor.dart';
export 'src/edit/storage_editors.dart';
export 'src/edit/pokedex.dart';
export 'src/edit/pokedex_modern.dart';
export 'src/edit/save_diff.dart';
export 'src/edit/save_editor.dart';
export 'src/edit/save_verifier.dart';
export 'src/edit/switch_editors.dart' show SCDexKeys;
export 'src/edit/save_edits.dart';
export 'src/edit/version_inference.dart';
export 'src/formats/gc_container.dart';
export 'src/formats/batrev.dart';
export 'src/formats/ranch.dart';
export 'src/formats/rsbox.dart';
export 'src/formats/stadium.dart';
export 'src/formats/gc_saves.dart' show GcSaveData;
export 'src/formats/switch_saves.dart' show SCKeys;
export 'src/model/game.dart';
export 'src/model/save.dart';
export 'src/pkm/gc_pkm.dart';
export 'src/pkm/pk_format.dart';
export 'src/pkm/pkm.dart';
export 'src/pkm/pkm_factory.dart';
export 'src/strings/string_codec.dart';
export 'src/util/checksums.dart';
export 'src/write/save_writer.dart';
