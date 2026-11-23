import 'package:drift/drift.dart';

part 'arca_database.g.dart';

/// Una partida del Arca: agrupa todos los snapshots del mismo juego + entrenador.
@DataClassName('SaveSlot')
class SaveSlots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get identityKey => text().unique()();
  TextColumn get gameCode => text()();
  IntColumn get generation => integer()();
  IntColumn get versionId => integer().nullable()();
  TextColumn get trainerName => text()();
  IntColumn get tid => integer()();
  IntColumn get sid => integer().nullable()();
  TextColumn get displayTid => text()();
  TextColumn get displaySid => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Copia inmutable de un archivo de save en un momento dado.
///
/// Desde la versión 3 la fuente de verdad es la carpeta del Arca: el save
/// vive en [relPath] (relativo a `PKArkTools/`) junto a su `.json`, y esta
/// tabla es solo un índice local reconstruible.
@DataClassName('Snapshot')
class Snapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get slotId => integer().references(SaveSlots, #id, onDelete: KeyAction.cascade)();
  TextColumn get sha256 => text()();
  DateTimeColumn get importedAt => dateTime()();
  TextColumn get fileName => text()();

  /// file | folder | saf | demo | restore-backup | edit | adopted | migrated | restored
  TextColumn get origin => text()();

  /// Ruta (o URI SAF) de donde se importó, para restaurar en el mismo sitio.
  TextColumn get sourcePath => text().nullable()();
  IntColumn get sizeBytes => integer()();
  IntColumn get playTimeSeconds => integer()();
  TextColumn get trainerName => text()();
  TextColumn get gameCode => text()();
  IntColumn get versionId => integer().nullable()();

  /// Especies del equipo: "25,6s,143" (s = variocolor).
  TextColumn get partySummary => text()();
  IntColumn get boxedCount => integer()();
  TextColumn get formatInfo => text()();
  TextColumn get checksum => text()();

  /// Descripción de los cambios cuando el snapshot nace de una edición.
  TextColumn get note => text().nullable()();

  /// Ruta del save dentro de la carpeta del Arca (null en una base antigua).
  TextColumn get relPath => text().nullable()();

  /// Dispositivo que creó la copia.
  TextColumn get deviceName => text().nullable()();

  /// Problema detectado al leer la copia (tamaño o hash distintos…).
  TextColumn get problem => text().nullable()();

  // Desde la versión 4 una partida puede tener varias copias con el mismo
  // contenido: restaurar una copia antigua crea una entrada nueva del
  // historial. La deduplicación de importaciones la hace el repositorio.
}

/// Caché de la Dex global: lo que la Dex necesita de cada copia (Pokédex,
/// ejemplares, activadores), por SHA-256 del archivo. Se calcula en segundo
/// plano al reindexar; si cambia el formato ([version]) se recalcula.
@DataClassName('DexScanRow')
class DexScans extends Table {
  TextColumn get sha256 => text()();
  IntColumn get version => integer()();
  TextColumn get data => text()();

  @override
  Set<Column> get primaryKey => {sha256};
}

/// Preferencias clave/valor.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [SaveSlots, Snapshots, Settings, DexScans])
class ArcaDatabase extends _$ArcaDatabase {
  ArcaDatabase(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(snapshots, snapshots.note);
          if (from < 3) {
            await m.addColumn(snapshots, snapshots.relPath);
            await m.addColumn(snapshots, snapshots.deviceName);
            await m.addColumn(snapshots, snapshots.problem);
          }
          // Sin la restricción única (partida, sha256): se recrea la tabla.
          if (from < 4) await m.alterTable(TableMigration(snapshots));
          if (from < 5) await m.createTable(dexScans);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
