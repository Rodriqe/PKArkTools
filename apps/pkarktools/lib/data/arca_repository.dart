import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart';
import 'package:pkcore/pkcore.dart';

import 'db/arca_database.dart';
import 'folder/arca_folder.dart';
import 'folder/arca_game_folders.dart';
import 'folder/arca_layout.dart';
import 'folder/arca_main_files.dart';
import 'folder/arca_migration.dart';
import 'folder/folder_fs.dart';
import 'save_source.dart';

export 'save_source.dart' show SaveSource;

/// Lee un save en otro isolate. Es una función de nivel superior para que
/// el closure solo capture los bytes (nunca la base de datos).
Future<SaveFile> parseSaveInIsolate(Uint8List bytes) => Isolate.run(() => readSaveWithVersion(bytes));

/// Avisos de legalidad (severidad «aviso») de todos los Pokémon del save:
/// equipo y cajas. 0 si el save no se puede abrir con el editor.
int countLegalityWarnings(Uint8List bytes) {
  final SaveEditor editor;
  try {
    editor = SaveEditor.open(bytes);
  } catch (_) {
    return 0;
  }
  int warnings(Pkm pk) => Legality.check(pk, editor.game).where((i) => i.severity == LegalitySeverity.warning).length;
  var n = 0;
  try {
    for (final pk in editor.party) {
      n += warnings(pk);
    }
    for (var b = 0; b < editor.boxCount; b++) {
      for (var i = 0; i < editor.boxSlotCount; i++) {
        final pk = editor.get(SlotRef.box(b, i));
        if (pk != null) n += warnings(pk);
      }
    }
  } catch (_) {
    // Lo que no se puede leer ya lo señala el aviso de daño.
  }
  return n;
}

/// Lee el save y, si no guarda su versión concreta (Rubí o Zafiro, Oro HG o
/// Plata SS…), la deduce de los Pokémon del propio entrenador.
SaveFile readSaveWithVersion(Uint8List bytes) {
  final s = SaveDetector.read(bytes);
  if (s.versionId != null) return s;
  final v = GameVersions.infer(bytes, s);
  return v == null ? s : s.withVersion(v);
}

/// Origen de un import.
enum ImportOrigin {
  file('file'),
  folder('folder'),
  saf('saf'),
  demo('demo'),
  restoreBackup('restore-backup'),
  edit('edit'),
  adopted('adopted'),
  migrated('migrated'),

  /// Copia antigua restaurada como versión actual (entrada nueva del historial).
  restored('restored'),

  /// Save dejado suelto en la carpeta de su juego (bandeja de entrada).
  inbox('inbox');

  const ImportOrigin(this.code);
  final String code;

  static ImportOrigin fromCode(String c) =>
      values.firstWhere((o) => o.code == c, orElse: () => ImportOrigin.file);
}

/// Resultado de importar un archivo.
sealed class ImportOutcome {
  const ImportOutcome(this.fileName);
  final String fileName;
}

class ImportAdded extends ImportOutcome {
  const ImportAdded(super.fileName, this.slotId, this.snapshotId, this.save, {required this.newSlot});
  final int slotId;
  final int snapshotId;
  final SaveFile save;
  final bool newSlot;
}

class ImportDuplicate extends ImportOutcome {
  const ImportDuplicate(super.fileName, this.slotId, this.save);
  final int slotId;
  final SaveFile save;
}

class ImportFailed extends ImportOutcome {
  const ImportFailed(super.fileName, this.reason);
  final String reason;
}

/// Una partida del Arca con su snapshot más reciente.
class ArcaEntry {
  const ArcaEntry({
    required this.slot,
    required this.latest,
    required this.snapshotCount,
    this.sources = const {},
    this.edited = false,
  });
  final SaveSlot slot;
  final Snapshot latest;
  final int snapshotCount;

  /// De dónde salieron las copias importadas (sin contar las ediciones).
  final Set<SaveSource> sources;

  /// Alguna copia nació de una edición hecha en la app.
  final bool edited;

  /// La copia más reciente tiene checksums que no cuadran o un problema de
  /// lectura detectado al reindexar.
  bool get damaged => latest.checksum == ChecksumStatus.invalid.name || latest.problem != null;

  GameVersion get game => GameVersion.fromCode(slot.gameCode) ?? GameVersion.redBlue;
}

/// Un elemento del registro de actividad.
class ActivityItem {
  const ActivityItem(this.snapshot, this.slot);
  final Snapshot snapshot;
  final SaveSlot slot;
}

/// Resultado de un reindexado de la carpeta.
class ReindexReport {
  ReindexReport({required this.at});
  final DateTime at;
  int added = 0;
  int removed = 0;
  int unchanged = 0;

  /// Copias con el mismo contenido que otra de la misma partida (p. ej. dos
  /// dispositivos importaron el mismo save): se indexa solo la primera.
  int duplicates = 0;
  final List<ArcaIssue> issues = [];

  /// Saves sueltos que el usuario puede "adoptar".
  List<FsEntry> loose = const [];
  Map<IgnoreReason, int> ignored = const {};
  List<String> placeholders = const [];

  /// Archivos principales (última versión de cada carpeta de entrenador).
  List<MainFileStatus> mains = const [];

  /// Copias de conflicto de la nube del principal retiradas (ya estaban en
  /// el historial).
  int conflictsCleaned = 0;

  /// Copias del diseño anterior movidas a `historial/` en este reindexado.
  MigrationResult? historyMigration;

  /// Saves recogidos de la bandeja de entrada (`<Juego>/archivo`) en este
  /// reindexado: archivo, juego y entrenador.
  List<(String, GameVersion, String)> inboxAdopted = [];

  /// Saves de la bandeja que no se pudieron recoger (se quedan donde están).
  List<InboxProblem> inboxProblems = const [];

  /// Saves de la bandeja aún escribiéndose (se recogen en un momento).
  int inboxPending = 0;

  /// Principales reemplazados a mano (contenido fuera del historial).
  List<MainFileStatus> get modifiedMains => [for (final m in mains) if (m.state == MainState.modified) m];

  int get ignoredCount => ignored.values.fold(0, (a, b) => a + b);
}

enum InboxProblemKind {
  /// No se pudo leer o no es un save reconocible.
  unreadable,

  /// Es un save de otro juego (se ofrece moverlo a su carpeta).
  wrongGame,
}

/// Un save de la bandeja de entrada que se queda donde está.
class InboxProblem {
  const InboxProblem(this.kind, this.path, {this.detail, this.actualGame, this.folderGame});
  final InboxProblemKind kind;
  final String path;
  final String? detail;

  /// Juego real del save (si se pudo leer).
  final GameVersion? actualGame;

  /// Juego de la carpeta donde se dejó.
  final GameVersion? folderGame;
}

/// Identidad de este dispositivo (se guarda en el `.json` de cada copia).
class ArcaDevice {
  const ArcaDevice(this.id, this.name);
  final String id;
  final String name;
}

/// Lógica de negocio del Arca: importar, listar, leer y exportar snapshots.
///
/// La fuente de verdad es la carpeta ([ArcaFolder]); la base drift es un
/// índice local de este dispositivo que [reindex] reconstruye.
class ArcaRepository {
  ArcaRepository(this.db, ArcaFolder? folder, {String? deviceName, this.inboxSettle = const Duration(seconds: 5)})
      : _folder = folder,
        _deviceName = deviceName;

  /// Un save de la bandeja modificado hace menos de esto aún se está
  /// copiando o sincronizando: se recoge en el siguiente reindexado.
  final Duration inboxSettle;

  final ArcaDatabase db;
  ArcaFolder? _folder;
  final String? _deviceName;
  ArcaDevice? _device;

  final _reports = StreamController<ReindexReport>.broadcast();
  final MainHashCache _mainHashes = {};
  ReindexReport? _lastReport;
  Future<ReindexReport>? _running;
  bool _rerun = false;

  bool get hasFolder => _folder != null;

  ArcaFolder get folder => _folder ?? (throw StateError('El Arca no tiene carpeta configurada'));

  /// Cambia la carpeta: vacía el índice local y lo reconstruye.
  Future<ReindexReport> attachFolder(ArcaFolder folder) async {
    await _running;
    _folder = folder;
    await clearIndex();
    await folder.ensureReadme();
    return reindex();
  }

  /// Reabre la misma carpeta (p. ej. tras renovar el permiso) sin vaciar el índice.
  void replaceFolder(ArcaFolder folder) => _folder = folder;

  ReindexReport? get lastReport => _lastReport;
  Stream<ReindexReport> get reports => _reports.stream;

  static String sha256Of(Uint8List bytes) => crypto.sha256.convert(bytes).toString();

  static String encodeParty(List<PokemonSummary> party) =>
      party.map((p) => '${p.species}${p.isShiny ? 's' : ''}${p.isEgg ? 'e' : ''}').join(',');

  static List<({int species, bool shiny, bool egg})> decodeParty(String s) => [
        for (final part in s.split(',').where((e) => e.isNotEmpty))
          (
            species: int.tryParse(part.replaceAll(RegExp('[se]'), '')) ?? 0,
            shiny: part.contains('s'),
            egg: part.contains('e'),
          ),
      ];

  Future<ArcaDevice> device() async {
    if (_device != null) return _device!;
    var id = await getSetting('deviceId');
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = List.generate(8, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await setSetting('deviceId', id);
    }
    var name = _deviceName;
    if (name == null) {
      try {
        name = '${io.Platform.localHostname} (${io.Platform.operatingSystem})';
      } catch (_) {
        name = io.Platform.operatingSystem;
      }
    }
    return _device = ArcaDevice(id, name);
  }

  static SlotMeta _slotMetaOf(SaveSlot s) => SlotMeta(
        identityKey: s.identityKey,
        gameCode: s.gameCode,
        generation: s.generation,
        versionId: s.versionId,
        trainerName: s.trainerName,
        tid: s.tid,
        sid: s.sid,
        displayTid: s.displayTid,
        displaySid: s.displaySid,
      );

  /// Importa un archivo. Nunca lanza: los errores se devuelven como [ImportFailed].
  Future<ImportOutcome> importBytes(
    Uint8List bytes, {
    required String fileName,
    required ImportOrigin origin,
    String? sourcePath,
    DateTime? now,
    String? note,
    int? forceSlotId,
  }) async {
    final allowDuplicate = origin == ImportOrigin.restored;
    final SaveFile save;
    try {
      save = await parseSaveInIsolate(bytes);
    } on UnsupportedSaveException catch (e) {
      return ImportFailed(fileName, e.message);
    } on CorruptSaveException catch (e) {
      return ImportFailed(fileName, 'Archivo de ${e.game.nameEs} dañado: ${e.message}');
    } catch (e) {
      return ImportFailed(fileName, 'Error inesperado al leer el archivo: $e');
    }

    final sha = sha256Of(bytes);
    // Sin fracciones de segundo: la fecha viaja en el nombre y en el JSON.
    final ts = DateTime.fromMillisecondsSinceEpoch(((now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000) * 1000);
    final t = save.trainer;
    final dev = await device();
    final folder = this.folder;

    try {
      return await db.transaction<(ImportOutcome, String?)>(() async {
        final slot = forceSlotId != null
            ? await (db.select(db.saveSlots)..where((s) => s.id.equals(forceSlotId))).getSingleOrNull()
            : await (db.select(db.saveSlots)..where((s) => s.identityKey.equals(save.identityKey))).getSingleOrNull();
        if (slot != null && !allowDuplicate) {
          final existing = await (db.select(db.snapshots)
                ..where((s) => s.slotId.equals(slot.id) & s.sha256.equals(sha))
                ..limit(1))
              .getSingleOrNull();
          if (existing != null) return (ImportDuplicate(fileName, slot.id, save), null);
        }
        final slotMeta = slot != null
            ? (forceSlotId != null
                ? SlotMeta(
                    identityKey: slot.identityKey,
                    gameCode: slot.gameCode,
                    generation: slot.generation,
                    versionId: save.versionId ?? slot.versionId,
                    trainerName: t.name,
                    tid: slot.tid,
                    sid: slot.sid,
                    displayTid: t.displayTid,
                    displaySid: t.displaySid,
                  )
                : _slotMetaOf(slot))
            : SlotMeta(
                identityKey: save.identityKey,
                gameCode: save.game.code,
                generation: save.generation,
                versionId: save.versionId,
                trainerName: t.name,
                tid: t.tid,
                sid: t.sid,
                displayTid: t.displayTid,
                displaySid: t.displaySid,
              );
        final meta = SnapshotMeta(
          sha256: sha,
          sizeBytes: bytes.length,
          importedAt: ts,
          originalFileName: fileName,
          origin: origin.code,
          sourcePath: sourcePath,
          note: note,
          deviceId: dev.id,
          deviceName: dev.name,
          gameCode: save.game.code,
          generation: save.generation,
          versionId: save.versionId,
          format: save.format,
          checksum: save.checksum.name,
          trainerName: t.name,
          tid: t.tid,
          sid: t.sid,
          displayTid: t.displayTid,
          displaySid: t.displaySid,
          playTimeSeconds: t.playTime.inSeconds,
          partySummary: encodeParty(save.party),
          boxedCount: save.boxedCount,
          slot: slotMeta,
        );
        final rel = await folder.writeSnapshot(bytes, meta);
        final (slotId, newSlot) = await _upsertSlot(slotMeta, ts, renamed: forceSlotId != null);
        final snapId = await _insertSnapshot(slotId, meta, rel);
        return (ImportAdded(fileName, slotId, snapId, save, newSlot: newSlot), rel);
      }).then((r) async {
        // La copia nueva puede ser la última: se actualiza ya el archivo principal.
        if (r.$2 != null) await refreshMainsFor(ArcaLayout.ownerDirOf(r.$2!));
        return r.$1;
      });
    } catch (e) {
      return ImportFailed(fileName, 'No se pudo escribir en la carpeta del Arca: $e');
    }
  }

  /// Recalcula el archivo principal de una sola carpeta de entrenador (tras
  /// importar, editar o restaurar). Nunca lanza: un fallo se corrige en el
  /// próximo reindexado.
  Future<List<MainFileStatus>> refreshMainsFor(String ownerDir) async {
    try {
      final folder = this.folder;
      final listing = await folder.listing(sub: ownerDir);
      final rows = await db.select(db.snapshots).get();
      final history = [
        for (final r in rows)
          if (r.relPath != null && r.problem == null && ArcaLayout.ownerDirOf(r.relPath!) == ownerDir && listing.pairs.containsKey(r.relPath))
            HistoryEntry(path: r.relPath!, sha256: r.sha256, importedAt: r.importedAt, gameCode: r.gameCode, originalName: r.fileName),
      ];
      final out = await ArcaMainFiles.sync(
        folder: folder,
        listing: listing,
        history: history,
        cache: _mainHashes,
        knownShas: {for (final r in rows) r.sha256},
      );
      return out.mains;
    } catch (_) {
      return const [];
    }
  }

  /// Crea la partida si no existe o actualiza sus fechas. Devuelve (id, nueva).
  Future<(int, bool)> _upsertSlot(SlotMeta m, DateTime ts, {bool renamed = false}) async {
    final slot = await (db.select(db.saveSlots)..where((s) => s.identityKey.equals(m.identityKey))).getSingleOrNull();
    if (slot == null) {
      final id = await db.into(db.saveSlots).insert(SaveSlotsCompanion.insert(
            identityKey: m.identityKey,
            gameCode: m.gameCode,
            generation: m.generation,
            versionId: Value(m.versionId),
            trainerName: m.trainerName,
            tid: m.tid,
            sid: Value(m.sid),
            displayTid: m.displayTid,
            displaySid: Value(m.displaySid),
            createdAt: ts,
            updatedAt: ts,
          ));
      return (id, true);
    }
    final newer = !ts.isBefore(slot.updatedAt);
    await (db.update(db.saveSlots)..where((s) => s.id.equals(slot.id))).write(SaveSlotsCompanion(
      updatedAt: newer ? Value(ts) : const Value.absent(),
      createdAt: ts.isBefore(slot.createdAt) ? Value(ts) : const Value.absent(),
      versionId: Value(m.versionId ?? slot.versionId),
      trainerName: newer && renamed ? Value(m.trainerName) : const Value.absent(),
      displayTid: newer && renamed ? Value(m.displayTid) : const Value.absent(),
      displaySid: newer && renamed ? Value(m.displaySid) : const Value.absent(),
    ));
    return (slot.id, false);
  }

  Future<int> _insertSnapshot(int slotId, SnapshotMeta m, String rel, {String? problem}) =>
      db.into(db.snapshots).insert(SnapshotsCompanion.insert(
            slotId: slotId,
            sha256: m.sha256,
            importedAt: m.importedAt,
            fileName: m.originalFileName,
            origin: m.origin,
            sourcePath: Value(m.sourcePath),
            sizeBytes: m.sizeBytes,
            playTimeSeconds: m.playTimeSeconds,
            trainerName: m.trainerName,
            gameCode: m.gameCode,
            versionId: Value(m.versionId),
            partySummary: m.partySummary,
            boxedCount: m.boxedCount,
            formatInfo: m.format,
            checksum: m.checksum,
            note: Value(m.note),
            relPath: Value(rel),
            deviceName: Value(m.deviceName),
            problem: Value(problem),
          ));

  // ---------------------------------------------------------------- índice

  /// Vacía el índice local (la carpeta no se toca).
  Future<void> clearIndex() => db.transaction(() async {
        await db.delete(db.snapshots).go();
        await db.delete(db.saveSlots).go();
      });

  /// Reindexado incremental: añade los snapshots nuevos de la carpeta, quita
  /// los que ya no están y marca los problemas sin detenerse. Si ya hay uno en
  /// marcha, se encadena otro al terminar.
  Future<ReindexReport> reindex() {
    if (_running != null) {
      _rerun = true;
      return _running!;
    }
    final f = _reindexLoop();
    _running = f;
    return f.whenComplete(() => _running = null);
  }

  Future<ReindexReport> _reindexLoop() async {
    ReindexReport r;
    final adopted = <(String, GameVersion, String)>[];
    var rounds = 0;
    do {
      _rerun = false;
      r = await _reindexOnce();
      adopted.addAll(r.inboxAdopted);
      // Lo recogido de la bandeja cambia la carpeta: otra pasada la pone al día.
      if (r.inboxAdopted.isNotEmpty && rounds++ < 3) _rerun = true;
    } while (_rerun);
    r.inboxAdopted = adopted;
    _lastReport = r;
    _reports.add(r);
    return r;
  }

  Future<ReindexReport> _reindexOnce() async {
    final folder = this.folder;
    final report = ReindexReport(at: DateTime.now());
    var listing = await folder.listing();
    if (ArcaMigration.needsHistoryLayout(listing)) {
      // Diseño anterior: las copias pasan a historial/ conservando sus filas
      // del índice (mismo id), y se vuelve a listar.
      await folder.ensureReadme();
      report.historyMigration = await ArcaMigration.toHistoryLayout(folder, listing, onMoved: (from, to) async {
        await (db.update(db.snapshots)..where((s) => s.relPath.equals(from))).write(SnapshotsCompanion(relPath: Value(to)));
      });
      listing = await folder.listing();
    }
    report
      ..loose = listing.loose
      ..ignored = listing.ignored
      ..placeholders = listing.placeholders;
    for (final side in listing.missingSave) {
      report.issues.add(ArcaIssue(ArcaIssueKind.missingSave, side));
    }
    for (final e in listing.missingSidecar) {
      report.issues.add(ArcaIssue(ArcaIssueKind.missingSidecar, e.path));
    }

    final rows = await db.select(db.snapshots).get();
    final known = <String, Snapshot>{for (final r in rows) if (r.relPath != null) r.relPath!: r};

    // 1. Quitar del índice lo que ya no está en la carpeta (o no tiene ruta).
    final gone = [
      for (final r in rows)
        if (r.relPath == null || !listing.pairs.containsKey(r.relPath)) r.id,
    ];
    // 2. Revisar los que siguen (tamaño) y leer los nuevos.
    final metas = <(String, SnapshotMeta, String?)>[];
    for (final MapEntry(key: rel, value: _) in listing.pairs.entries) {
      final size = listing.files[rel]!.size;
      final row = known[rel];
      if (row != null) {
        report.unchanged++;
        final problem = size != row.sizeBytes ? 'size' : (row.problem == 'size' ? null : row.problem);
        if (problem != row.problem) {
          await (db.update(db.snapshots)..where((s) => s.id.equals(row.id))).write(SnapshotsCompanion(problem: Value(problem)));
        }
        if (problem == 'size') report.issues.add(ArcaIssue(ArcaIssueKind.sizeMismatch, rel));
        continue;
      }
      try {
        final meta = await folder.readMeta(rel);
        String? problem;
        if (meta.sizeBytes != size) {
          problem = 'size';
          report.issues.add(ArcaIssue(ArcaIssueKind.sizeMismatch, rel, '${meta.sizeBytes} ≠ $size'));
        }
        metas.add((rel, meta, problem));
      } on FormatException catch (e) {
        report.issues.add(ArcaIssue(ArcaIssueKind.corruptSidecar, listing.pairs[rel]!, e.message));
      } on Exception catch (e) {
        report.issues.add(ArcaIssue(ArcaIssueKind.unreadable, listing.pairs[rel]!, '$e'));
      }
    }
    // Orden estable en todos los dispositivos: la copia más antigua gana.
    metas.sort((a, b) {
      final c = a.$2.importedAt.compareTo(b.$2.importedAt);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });

    await db.transaction(() async {
      if (gone.isNotEmpty) {
        await (db.delete(db.snapshots)..where((s) => s.id.isIn(gone))).go();
        report.removed = gone.length;
      }
      for (final (rel, meta, problem) in metas) {
        final (slotId, _) = await _upsertSlot(meta.slot, meta.importedAt, renamed: true);
        // Una restauración es siempre una entrada propia del historial aunque
        // repita el contenido de otra copia.
        final dup = meta.origin == ImportOrigin.restored.code
            ? null
            : await (db.select(db.snapshots)
                  ..where((s) =>
                      s.slotId.equals(slotId) & s.sha256.equals(meta.sha256) & s.origin.equals(ImportOrigin.restored.code).not())
                  ..limit(1))
                .getSingleOrNull();
        if (dup != null) {
          report.duplicates++;
          // Todos los dispositivos convergen en la misma copia: la más antigua
          // (y, a igual fecha, la de ruta menor).
          final c = meta.importedAt.compareTo(dup.importedAt);
          if (c < 0 || (c == 0 && rel.compareTo(dup.relPath ?? '') < 0)) {
            await (db.update(db.snapshots)..where((s) => s.id.equals(dup.id))).write(SnapshotsCompanion(
              relPath: Value(rel),
              importedAt: Value(meta.importedAt),
              fileName: Value(meta.originalFileName),
              origin: Value(meta.origin),
              sourcePath: Value(meta.sourcePath),
              note: Value(meta.note),
              deviceName: Value(meta.deviceName),
              problem: Value(problem),
            ));
          }
          continue;
        }
        await _insertSnapshot(slotId, meta, rel, problem: problem);
        report.added++;
      }
      if (gone.isNotEmpty) await _dropEmptySlots();
    });

    // Archivo principal de cada carpeta: copia de la entrada más reciente del
    // historial (copias íntegras; las dañadas no cuentan).
    final indexed = {for (final r in await db.select(db.snapshots).get()) if (r.relPath != null) r.relPath!: r};
    final fresh = {for (final (rel, meta, problem) in metas) rel: (meta, problem)};
    final history = <HistoryEntry>[];
    for (final rel in listing.pairs.keys) {
      final row = indexed[rel];
      final m = fresh[rel];
      if (row != null) {
        if (row.problem != null) continue;
        history.add(HistoryEntry(
            path: rel, sha256: row.sha256, importedAt: row.importedAt, gameCode: row.gameCode, originalName: row.fileName));
      } else if (m != null && m.$2 == null) {
        // Duplicado de otra copia (mismo contenido): cuenta para la fecha.
        history.add(HistoryEntry(
            path: rel,
            sha256: m.$1.sha256,
            importedAt: m.$1.importedAt,
            gameCode: m.$1.gameCode,
            originalName: m.$1.originalFileName));
      }
    }
    final mains = await ArcaMainFiles.sync(
        folder: folder, listing: listing, history: history, cache: _mainHashes, knownShas: {for (final r in indexed.values) r.sha256});
    report
      ..mains = mains.mains
      ..conflictsCleaned = mains.conflictsCleaned
      ..loose = mains.loose;
    await _processInbox(report);
    return report;
  }

  /// Bandeja de entrada: un save suelto directamente en `<Juego>/` se valida,
  /// se guarda como copia nueva de su entrenador (y pasa a ser la última
  /// versión) y, con la copia verificada por su hash, se retira de la bandeja.
  /// Lo que no se puede leer o es de otro juego se queda donde está.
  Future<void> _processInbox(ReindexReport report) async {
    final inbox = [
      for (final e in report.loose)
        if (e.path.split('/').length == 2 && ArcaGameFolders.gameOfDir(e.path.split('/').first) != null) e,
    ];
    if (inbox.isEmpty) return;
    final now = DateTime.now();
    final problems = <InboxProblem>[];
    final handled = <String>{};
    for (final e in inbox) {
      final folderGame = ArcaGameFolders.gameOfDir(e.path.split('/').first)!;
      final name = e.path.split('/').last;
      if (e.modified != null && now.difference(e.modified!) < inboxSettle) {
        report.inboxPending++;
        handled.add(e.path);
        continue;
      }
      handled.add(e.path);
      final Uint8List bytes;
      final SaveFile save;
      try {
        bytes = await folder.read(e.path);
        save = await parseSaveInIsolate(bytes);
      } on UnsupportedSaveException catch (err) {
        problems.add(InboxProblem(InboxProblemKind.unreadable, e.path, detail: err.message, folderGame: folderGame));
        continue;
      } on CorruptSaveException catch (err) {
        problems.add(InboxProblem(InboxProblemKind.unreadable, e.path, detail: err.message, folderGame: folderGame));
        continue;
      } catch (err) {
        problems.add(InboxProblem(InboxProblemKind.unreadable, e.path, detail: '$err', folderGame: folderGame));
        continue;
      }
      if (ArcaGameFolders.dirOf(save.game) != ArcaGameFolders.dirOf(folderGame)) {
        problems.add(InboxProblem(InboxProblemKind.wrongGame, e.path, actualGame: save.game, folderGame: folderGame));
        continue;
      }
      final out = await importBytes(bytes, fileName: name, origin: ImportOrigin.inbox);
      final sha = sha256Of(bytes);
      final verified = switch (out) {
        ImportAdded(:final snapshotId) => await _verifyStored(snapshotId, sha),
        // Mismo contenido ya en el historial: la bandeja se vacía igual.
        ImportDuplicate() => true,
        ImportFailed() => false,
      };
      if (!verified) {
        problems.add(InboxProblem(InboxProblemKind.unreadable, e.path,
            detail: out is ImportFailed ? out.reason : 'copia no verificada', folderGame: folderGame));
        continue;
      }
      try {
        await folder.delete(e.path);
      } catch (_) {
        // Se retira en el próximo reindexado (la copia ya está a salvo).
      }
      report.inboxAdopted.add((name, save.game, save.trainer.name));
    }
    report
      ..inboxProblems = problems
      ..loose = [for (final e in report.loose) if (!handled.contains(e.path)) e];
  }

  /// Archivo principal (ruta relativa a la raíz del Arca) de la partida de
  /// [latest], su copia más reciente.
  static String? mainPathOf(Snapshot latest) {
    final rel = latest.relPath;
    if (rel == null) return null;
    return ArcaLayout.mainPath(ArcaLayout.ownerDirOf(rel), ArcaLayout.mainFileName(latest.gameCode, latest.fileName));
  }

  /// Guarda en el historial un archivo principal reemplazado a mano. Pasa a
  /// ser la versión actual; el archivo nunca se borra.
  Future<ImportOutcome> saveMainAsCopy(String mainPath) async {
    final name = mainPath.split('/').last;
    final Uint8List bytes;
    try {
      bytes = await folder.read(mainPath);
    } catch (e) {
      return ImportFailed(name, 'No se pudo leer $mainPath: $e');
    }
    final out = await importBytes(bytes, fileName: name, origin: ImportOrigin.adopted, sourcePath: null);
    await reindex();
    return out;
  }

  /// Restaura una copia antigua como versión actual: crea una entrada nueva
  /// del historial (origen «restaurada») con su contenido y actualiza el
  /// archivo principal. El historial nunca se reescribe.
  Future<ImportOutcome> restoreAsCurrent(Snapshot s, {String? note, DateTime? now}) async {
    final bytes = await snapshotBytes(s);
    final out = await importBytes(bytes,
        fileName: s.fileName,
        origin: ImportOrigin.restored,
        sourcePath: s.sourcePath,
        note: note,
        now: now,
        forceSlotId: s.slotId);
    await reindex();
    return out;
  }

  Future<void> _dropEmptySlots() => db.customStatement(
      'DELETE FROM save_slots WHERE id NOT IN (SELECT DISTINCT slot_id FROM snapshots)');

  /// Adopta un save suelto de la carpeta: lo identifica, lo coloca en su sitio
  /// con su `.json` y, una vez verificada la copia, borra el suelto.
  Future<ImportOutcome> adopt(String relPath) async {
    final name = relPath.split('/').last;
    final Uint8List bytes;
    try {
      bytes = await folder.read(relPath);
    } catch (e) {
      return ImportFailed(name, 'No se pudo leer $relPath: $e');
    }
    final out = await importBytes(bytes, fileName: name, origin: ImportOrigin.adopted);
    final sha = sha256Of(bytes);
    final keep = switch (out) {
      ImportAdded(:final snapshotId) => await _verifyStored(snapshotId, sha),
      ImportDuplicate() => true,
      ImportFailed() => false,
    };
    if (keep) await folder.delete(relPath);
    await reindex();
    return out;
  }

  Future<bool> _verifyStored(int snapshotId, String sha) async {
    try {
      final s = await snapshot(snapshotId);
      await folder.readVerified(s.relPath!, sha);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------- lectura

  /// Partidas del Arca, la actualizada más recientemente primero.
  Stream<List<ArcaEntry>> watchArca() {
    final q = db.select(db.snapshots).join([
      innerJoin(db.saveSlots, db.saveSlots.id.equalsExp(db.snapshots.slotId)),
    ]);
    return q.watch().map((rows) {
      final bySlot = <int, List<Snapshot>>{};
      final slots = <int, SaveSlot>{};
      for (final r in rows) {
        final snap = r.readTable(db.snapshots);
        slots[snap.slotId] = r.readTable(db.saveSlots);
        bySlot.putIfAbsent(snap.slotId, () => []).add(snap);
      }
      final entries = [
        for (final MapEntry(:key, :value) in bySlot.entries)
          ArcaEntry(
            slot: slots[key]!,
            latest: value.reduce((a, b) => _newer(a, b) ? a : b),
            snapshotCount: value.length,
            sources: _sources(value),
            edited: value.any((s) => s.origin == ImportOrigin.edit.code),
          ),
      ]..sort((a, b) => b.slot.updatedAt.compareTo(a.slot.updatedAt));
      return entries;
    });
  }

  static Set<SaveSource> _sources(List<Snapshot> snaps) {
    const derived = {'edit', 'restore-backup', 'restored'};
    final imported = snaps.where((s) => !derived.contains(s.origin));
    final found = {for (final s in imported) SaveSource.ofSnapshot(s)};
    if (found.length > 1) found.remove(SaveSource.other);
    return found.isEmpty ? const {SaveSource.other} : found;
  }

  static bool _newer(Snapshot a, Snapshot b) {
    final c = a.importedAt.compareTo(b.importedAt);
    return c != 0 ? c > 0 : a.id > b.id;
  }

  Stream<SaveSlot?> watchSlot(int slotId) =>
      (db.select(db.saveSlots)..where((s) => s.id.equals(slotId))).watchSingleOrNull();

  /// Snapshots de una partida, del más reciente al más antiguo.
  Stream<List<Snapshot>> watchSnapshots(int slotId) => (db.select(db.snapshots)
        ..where((s) => s.slotId.equals(slotId))
        ..orderBy([(s) => OrderingTerm.desc(s.importedAt), (s) => OrderingTerm.desc(s.id)]))
      .watch();

  Stream<List<ActivityItem>> watchActivity({int limit = 200}) {
    final q = db.select(db.snapshots).join([
      innerJoin(db.saveSlots, db.saveSlots.id.equalsExp(db.snapshots.slotId)),
    ])
      ..orderBy([OrderingTerm.desc(db.snapshots.importedAt), OrderingTerm.desc(db.snapshots.id)])
      ..limit(limit);
    return q.watch().map((rows) => [
          for (final r in rows) ActivityItem(r.readTable(db.snapshots), r.readTable(db.saveSlots)),
        ]);
  }

  Stream<int> watchSnapshotCount() {
    final c = db.snapshots.id.count();
    return (db.selectOnly(db.snapshots)..addColumns([c])).map((r) => r.read(c) ?? 0).watchSingle();
  }

  /// Avisos de legalidad de una copia, calculados en otro isolate.
  Future<int> legalityWarnings(Snapshot s) async {
    final bytes = await snapshotBytes(s);
    return Isolate.run(() => countLegalityWarnings(bytes));
  }

  Future<Snapshot> snapshot(int id) => (db.select(db.snapshots)..where((s) => s.id.equals(id))).getSingle();

  /// Bytes de un snapshot, comprobando su SHA-256. Si no coincide, la copia
  /// se marca como dañada y se lanza [ArcaFileCorruptException].
  Future<Uint8List> snapshotBytes(Snapshot s) async {
    final rel = s.relPath;
    if (rel == null) throw ArcaFileCorruptException(s.fileName, 'sin ruta en la carpeta');
    try {
      return await folder.readVerified(rel, s.sha256);
    } on ArcaFileCorruptException {
      await (db.update(db.snapshots)..where((x) => x.id.equals(s.id))).write(const SnapshotsCompanion(problem: Value('hash')));
      rethrow;
    } on io.FileSystemException catch (e) {
      throw ArcaFileCorruptException(rel, 'no se pudo leer (${e.message})');
    }
  }

  /// Lee y parsea un snapshot fuera del hilo de UI.
  Future<SaveFile> parseSnapshot(int snapshotId) async {
    final s = await snapshot(snapshotId);
    return parseSaveInIsolate(await snapshotBytes(s));
  }

  /// Guarda el resultado de una edición como snapshot nuevo de la misma partida.
  Future<ImportOutcome> saveEdited(
    Uint8List bytes, {
    required int slotId,
    required String fileName,
    required String note,
    String? sourcePath,
    DateTime? now,
  }) =>
      importBytes(bytes,
          fileName: fileName, origin: ImportOrigin.edit, sourcePath: sourcePath, now: now, note: note, forceSlotId: slotId);

  /// Elimina una partida: borra del índice y de la carpeta sus copias (save +
  /// `.json`). Los demás dispositivos lo verán en su próximo reindexado.
  /// Fija a mano la versión concreta de una partida (cuando el save no la
  /// guarda). Se escribe en el .json de cada snapshot de la partida, así
  /// sobrevive a un reindexado y viaja con la carpeta del Arca.
  Future<void> setSlotVersion(int slotId, int? versionId) async {
    final snaps = await (db.select(db.snapshots)..where((s) => s.slotId.equals(slotId))).get();
    for (final s in snaps) {
      final rel = s.relPath;
      if (rel == null) continue;
      try {
        final meta = await folder.readMeta(rel);
        await folder.rewriteMeta(rel, meta.withSlotVersion(versionId));
      } catch (_) {
        // Un sidecar ilegible se queda como está; el índice se actualiza igual.
      }
    }
    final fallback = snaps.map((s) => s.versionId).nonNulls.firstOrNull;
    await (db.update(db.saveSlots)..where((s) => s.id.equals(slotId)))
        .write(SaveSlotsCompanion(versionId: Value(versionId ?? fallback)));
  }

  Future<void> deleteSlot(int slotId) async {
    final snaps = await (db.select(db.snapshots)..where((s) => s.slotId.equals(slotId))).get();
    await db.transaction(() async {
      await (db.delete(db.snapshots)..where((s) => s.slotId.equals(slotId))).go();
      await (db.delete(db.saveSlots)..where((s) => s.id.equals(slotId))).go();
    });
    final dirs = <String>{};
    final shas = {for (final s in snaps) s.sha256};
    for (final s in snaps) {
      final rel = s.relPath;
      if (rel == null) continue;
      dirs.add(ArcaLayout.ownerDirOf(rel));
      // Primero el .json: sin él, otro dispositivo nunca indexa un save a medias.
      await folder.delete(ArcaLayout.sidecarFor(rel));
      await folder.delete(rel);
    }
    // Archivos principales derivados de esas copias (nunca uno modificado a mano).
    for (final dir in dirs) {
      final names = {for (final s in snaps) if (s.relPath != null && ArcaLayout.ownerDirOf(s.relPath!) == dir) ArcaLayout.mainFileName(s.gameCode, s.fileName)};
      for (final name in names) {
        final path = ArcaLayout.mainPath(dir, name);
        try {
          if (await folder.exists(path) && shas.contains(ArcaFolder.sha256Of(await folder.read(path)))) await folder.delete(path);
        } catch (_) {}
      }
      await folder.delete(ArcaLayout.latestPath(dir));
    }
  }

  /// SHA-256 de todos los snapshots del Arca (para detectar duplicados antes de importar).
  Future<Set<String>> knownHashes() async => {for (final s in await db.select(db.snapshots).get()) s.sha256};

  /// Todas las partidas con sus snapshots (del más antiguo al más reciente).
  Future<List<(SaveSlot, List<Snapshot>)>> allSlots() async {
    final slots = await db.select(db.saveSlots).get();
    final snaps = await (db.select(db.snapshots)
          ..orderBy([(s) => OrderingTerm.asc(s.importedAt), (s) => OrderingTerm.asc(s.id)]))
        .get();
    return [for (final slot in slots) (slot, snaps.where((s) => s.slotId == slot.id).toList())];
  }

  // ---- Preferencias (locales de este dispositivo) ----

  Future<String?> getSetting(String key) async =>
      (await (db.select(db.settings)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSetting(String key, String value) =>
      db.into(db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> setJsonSetting(String key, Map<String, Object?> value) => setSetting(key, jsonEncode(value));

  Future<Map<String, Object?>?> getJsonSetting(String key) async {
    final v = await getSetting(key);
    if (v == null || v.isEmpty) return null;
    try {
      return jsonDecode(v) as Map<String, Object?>;
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() => _reports.close();
}
