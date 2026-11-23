import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Almacén de blobs del Arca interna anterior (hasta la Fase 4), direccionado
/// por SHA-256. Solo se usa para migrar esas copias a la carpeta del Arca.
///
/// Cada blob se escribe una sola vez (`<raíz>/ab/abcdef….sav`) y nunca se
/// modifica: los snapshots del Arca son inmutables.
class BlobStore {
  BlobStore(this.root);

  final Directory root;

  File _fileFor(String sha) => File(p.join(root.path, sha.substring(0, 2), '$sha.sav'));

  Future<bool> exists(String sha) => _fileFor(sha).exists();

  Future<void> put(String sha, Uint8List bytes) async {
    final f = _fileFor(sha);
    if (await f.exists() && await f.length() == bytes.length) return;
    await f.parent.create(recursive: true);
    // Escritura atómica: archivo temporal + rename.
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
  }

  Future<Uint8List> read(String sha) => _fileFor(sha).readAsBytes();

  Future<void> delete(String sha) async {
    final f = _fileFor(sha);
    if (await f.exists()) await f.delete();
  }
}
