// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'PKArkTools';

  @override
  String get navArca => 'Arca';

  @override
  String get navActivity => 'Actividad';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get arcaTitle => 'Tu Arca';

  @override
  String arcaSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partidas a salvo',
      one: '1 partida a salvo',
      zero: 'Aún no hay partidas',
    );
    return '$_temp0';
  }

  @override
  String get importAction => 'Importar';

  @override
  String get importFile => 'Importar archivo';

  @override
  String get importFolder => 'Importar carpeta';

  @override
  String get importSheetTitle => 'Añadir al Arca';

  @override
  String get importFileDesc =>
      'Saves de cartucho o exportados: .sav, .srm, .dsv, main…';

  @override
  String get importFolderDesc =>
      'Carpetas de Checkpoint, JKSM o de emuladores de Switch. Se buscan saves dentro.';

  @override
  String get emptyTitle => 'Tu Arca está vacía';

  @override
  String get emptyBody =>
      'Importa un save para guardar una copia segura con su historial. Nada sale de este dispositivo.';

  @override
  String get loadDemo => 'Probar con partidas de ejemplo';

  @override
  String demoLoaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se añadieron $count partidas de ejemplo',
      one: 'Se añadió 1 partida de ejemplo',
    );
    return '$_temp0';
  }

  @override
  String hoursShort(int hours) {
    return '$hours h';
  }

  @override
  String get playTime => 'Tiempo de juego';

  @override
  String get trainerId => 'ID';

  @override
  String get secretId => 'ID secreta';

  @override
  String get inBoxes => 'En cajas';

  @override
  String get copies => 'Copias';

  @override
  String lastCopy(String date) {
    return 'Última copia: $date';
  }

  @override
  String get team => 'Equipo';

  @override
  String get boxes => 'Cajas';

  @override
  String get history => 'Historial';

  @override
  String get emptyTeam => 'Sin Pokémon en el equipo';

  @override
  String get notSupportedStorage =>
      'Este juego todavía no muestra equipo ni cajas; llegará en una próxima fase. El entrenador y el historial ya funcionan.';

  @override
  String get shiny => 'Variocolor';

  @override
  String get egg => 'Huevo';

  @override
  String level(int level) {
    return 'Nv. $level';
  }

  @override
  String get export => 'Exportar';

  @override
  String get restore => 'Restaurar';

  @override
  String get viewing => 'En pantalla';

  @override
  String get view => 'Ver';

  @override
  String get latest => 'Más reciente';

  @override
  String exportDone(String path) {
    return 'Exportado a $path';
  }

  @override
  String exportFailed(String error) {
    return 'No se pudo exportar: $error';
  }

  @override
  String get restoreTitle => '¿Restaurar esta copia?';

  @override
  String restoreBody(String path) {
    return 'Se reemplazará el archivo original:\n$path\n\nAntes, el Arca guardará una copia del archivo actual para que puedas volver atrás.';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get restoreDone => 'Copia restaurada en su ubicación original';

  @override
  String restoreFailed(String error) {
    return 'No se pudo restaurar: $error';
  }

  @override
  String get restoreUnavailable =>
      'Esta copia no tiene un archivo original accesible. Usa Exportar para guardarla donde quieras.';

  @override
  String get importResultTitle => 'Importación terminada';

  @override
  String importAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copias nuevas',
      one: '1 copia nueva',
    );
    return '$_temp0';
  }

  @override
  String importDuplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ya estaban en el Arca',
      one: '1 ya estaba en el Arca',
    );
    return '$_temp0';
  }

  @override
  String importFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos no reconocidos',
      one: '1 archivo no reconocido',
    );
    return '$_temp0';
  }

  @override
  String get done => 'Listo';

  @override
  String get openSave => 'Abrir partida';

  @override
  String folderScanning(int count) {
    return 'Buscando saves… $count archivos revisados';
  }

  @override
  String folderFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saves encontrados',
      one: '1 save encontrado',
      zero: 'No se encontraron saves',
    );
    return '$_temp0';
  }

  @override
  String get folderNoneHint =>
      'Revisa que la carpeta tenga archivos de save (no ROMs). En emuladores de Switch elige la carpeta nand/user/save.';

  @override
  String importSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importar $count saves',
      one: 'Importar 1 save',
    );
    return '$_temp0';
  }

  @override
  String get deleteSave => 'Eliminar del Arca';

  @override
  String get deleteTitle => '¿Eliminar esta partida del Arca?';

  @override
  String deleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se borrarán sus $count copias guardadas.',
      one: 'Se borrará su copia guardada.',
    );
    return '$_temp0 Los archivos originales no se tocan.';
  }

  @override
  String get delete => 'Eliminar';

  @override
  String get checksumValid => 'Checksum correcto';

  @override
  String get activityEmpty =>
      'Aquí verás cada copia que entre al Arca, en orden.';

  @override
  String get theme => 'Tema';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get about => 'Acerca de';

  @override
  String get aboutBody =>
      'PKArkTools guarda copias versionadas de tus partidas de Pokémon de todas las generaciones. Es software libre (GPL-3.0) y porta lógica de PKHeX.Core. No incluye ROMs, claves ni contenido de los juegos.';

  @override
  String get licenses => 'Licencias de código abierto';

  @override
  String get sampleData => 'Datos de ejemplo';

  @override
  String get sampleDataDesc =>
      'Añade partidas sintéticas para explorar la app.';

  @override
  String get originFile => 'Archivo';

  @override
  String get originFolder => 'Carpeta';

  @override
  String get originSaf => 'Carpeta del emulador';

  @override
  String get originDemo => 'Ejemplo';

  @override
  String get originRestore => 'Respaldo antes de restaurar';

  @override
  String genLabel(int gen) {
    return 'Gen $gen';
  }

  @override
  String get boxEmpty => 'Caja vacía';

  @override
  String loadError(String error) {
    return 'No se pudo leer esta copia: $error';
  }

  @override
  String get moreActions => 'Más acciones';

  @override
  String pokemonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Pokémon',
      one: '1 Pokémon',
    );
    return '$_temp0';
  }

  @override
  String snapshotOf(String date) {
    return 'Copia del $date';
  }

  @override
  String get searchHint => 'Buscar por entrenador o juego';

  @override
  String noResults(String query) {
    return 'Nada coincide con «$query»';
  }

  @override
  String get ability => 'Habilidad';

  @override
  String get addItem => 'Añadir objeto';

  @override
  String get addToSlot => 'Añadir al hueco';

  @override
  String get addToTeam => 'Añadir al equipo';

  @override
  String andMore(int count) {
    return '…y $count cambios más';
  }

  @override
  String get applyChanges => 'Aplicar cambios';

  @override
  String get avs => 'Valores de despertar (AV)';

  @override
  String get ball => 'Poké Ball';

  @override
  String get baseTotal => 'Total base';

  @override
  String get boxFull => 'Esa caja está llena';

  @override
  String get boxesFull => 'Todas las cajas están llenas';

  @override
  String get changeNote => 'Descripción de los cambios';

  @override
  String get changesStayInDraft =>
      'Los cambios van al borrador; el archivo original no se toca.';

  @override
  String get clonePokemon => 'Clonar en la primera caja libre';

  @override
  String clonedTo(String slot) {
    return 'Clon colocado en $slot';
  }

  @override
  String get createPokemon => 'Crear Pokémon';

  @override
  String get createPokemonDesc =>
      'Con tu nombre de entrenador, tu ID y movimientos de su nivel';

  @override
  String get deletePokemon => 'Borrar del save';

  @override
  String get discard => 'Descartar';

  @override
  String get discardDraftBody =>
      'Se perderán todas las ediciones que no hayas guardado en el Arca.';

  @override
  String get discardDraftTitle => '¿Descartar los cambios?';

  @override
  String get discardPokemonBody =>
      'Los cambios de este Pokémon no se aplicarán al borrador.';

  @override
  String get discardPokemonTitle => '¿Salir sin aplicar?';

  @override
  String get dragHint =>
      'Arrastra un Pokémon para moverlo o intercambiarlo; suéltalo en el nombre de una caja para enviarlo allí.';

  @override
  String get dragHintGb =>
      'En Game Boy las cajas son listas: al mover o borrar, los Pokémon se reordenan sin huecos.';

  @override
  String get dragHintTouch =>
      'Mantén pulsado un Pokémon para arrastrarlo; suéltalo en otro hueco o en el nombre de una caja.';

  @override
  String get dvs => 'DVs (valores determinantes)';

  @override
  String editBoxName(int box, String name) {
    return 'Caja $box renombrada a «$name»';
  }

  @override
  String editClear(String species, String slot) {
    return '$species borrado de $slot';
  }

  @override
  String get editInventory => 'Inventario actualizado';

  @override
  String editMove(String from, String to) {
    return 'Movido de $from a $to';
  }

  @override
  String get editPokemon => 'Editar Pokémon';

  @override
  String editSet(String species, String slot) {
    return '$species en $slot';
  }

  @override
  String get editTrainer => 'Datos del entrenador actualizados';

  @override
  String get editedSuffix => 'editado';

  @override
  String evTotal(int total, int max) {
    return '$total / $max';
  }

  @override
  String get evs => 'EVs (puntos de esfuerzo)';

  @override
  String get experience => 'Experiencia';

  @override
  String get exportFile => 'Exportar archivo';

  @override
  String exportPokemon(String ext) {
    return 'Exportar como .$ext';
  }

  @override
  String exportReady(String path) {
    return 'Archivo listo para el juego en $path';
  }

  @override
  String get female => 'Chica';

  @override
  String get form => 'Forma';

  @override
  String get formBase => 'Normal';

  @override
  String formN(int n) {
    return 'Forma $n';
  }

  @override
  String get friendship => 'Amistad';

  @override
  String get gender => 'Género';

  @override
  String get gvs => 'Niveles de esfuerzo (GV)';

  @override
  String get heldItem => 'Objeto equipado';

  @override
  String get hiddenAbility => 'oculta';

  @override
  String get hours => 'Horas';

  @override
  String get hpDerived => 'El DV de PS se deriva del resto';

  @override
  String get importInvalidPokemon =>
      'El archivo no contiene un Pokémon válido (checksum incorrecto).';

  @override
  String importPokemon(String ext) {
    return 'Importar .$ext';
  }

  @override
  String get importPokemonDesc => 'Un Pokémon exportado de este mismo formato';

  @override
  String importWrongFormat(String got, String want) {
    return 'Un .$got no es compatible con este juego; necesita .$want.';
  }

  @override
  String importedPokemon(String species) {
    return '$species importado al borrador';
  }

  @override
  String get inventoryApplied => 'Inventario aplicado al borrador';

  @override
  String get inventoryUnsupported =>
      'El inventario de este juego todavía no se puede editar.';

  @override
  String get itemWrongPouch => 'Este objeto no suele ir en este bolsillo';

  @override
  String get ivs => 'IVs (valores individuales)';

  @override
  String get keepEditing => 'Seguir editando';

  @override
  String leaveDraftBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hay $count cambios sin guardar en el Arca.',
      one: 'Hay 1 cambio sin guardar en el Arca.',
    );
    return '$_temp0 Si sales, se descartan.';
  }

  @override
  String get leaveDraftTitle => '¿Salir sin guardar?';

  @override
  String get legalityClean => 'Sin avisos de legalidad básicos.';

  @override
  String get legalityHint => 'Son solo avisos: puedes guardar igualmente.';

  @override
  String legalityTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avisos',
      one: '1 aviso',
    );
    return '$_temp0';
  }

  @override
  String get legendBase => 'Base';

  @override
  String get levelLabel => 'Nivel';

  @override
  String get male => 'Chico';

  @override
  String get maxPpUps => 'Más PP al máximo';

  @override
  String get mint => 'Menta (naturaleza de stats)';

  @override
  String get minutes => 'Minutos';

  @override
  String get money => 'Dinero';

  @override
  String moneyMax(int max) {
    return 'Máximo $max';
  }

  @override
  String moveN(int n) {
    return 'Movimiento $n';
  }

  @override
  String get nature => 'Naturaleza';

  @override
  String get neutral => 'neutra';

  @override
  String get newPokemon => 'Nuevo Pokémon';

  @override
  String get nickname => 'Apodo';

  @override
  String get no => 'No';

  @override
  String get noChanges => 'Sin cambios: el borrador coincide con esta copia';

  @override
  String get noMatches => 'Sin resultados';

  @override
  String get none => 'Ninguno';

  @override
  String get originEdit => 'Edición';

  @override
  String get otGender => 'Género del entrenador';

  @override
  String get otName => 'Entrenador original';

  @override
  String get pokemon => 'Pokémon';

  @override
  String get pouchBalls => 'Poké Balls';

  @override
  String get pouchBattle => 'Combate';

  @override
  String get pouchBerries => 'Bayas';

  @override
  String get pouchCandy => 'Caramelos y materiales';

  @override
  String get pouchEmpty =>
      'Este bolsillo está vacío. Añade objetos con el buscador.';

  @override
  String get pouchFull => 'Bolsillo lleno';

  @override
  String get pouchIngredients => 'Ingredientes';

  @override
  String get pouchItems => 'Objetos';

  @override
  String get pouchKey => 'Objetos clave';

  @override
  String get pouchMail => 'Cartas';

  @override
  String get pouchMedicine => 'Botiquín';

  @override
  String get pouchPc => 'PC';

  @override
  String get pouchTms => 'MT y MO';

  @override
  String get pouchTreasure => 'Tesoros';

  @override
  String pouchUsage(int used, int capacity) {
    return '$used / $capacity';
  }

  @override
  String get pouchZ => 'Cristales Z / mejoras';

  @override
  String get ppUps => 'Más PP';

  @override
  String get presetClear => 'Limpiar';

  @override
  String get presetMaxAvs => 'Todos a 200';

  @override
  String get presetMaxGvs => 'Todos a 10';

  @override
  String get presetMaxStatExp => 'Todo al máximo';

  @override
  String get presetPerfectIvs => 'IVs perfectos';

  @override
  String get presetPhysWall => 'Muro físico';

  @override
  String get presetPhysical => 'Atacante físico';

  @override
  String get presetSpecWall => 'Muro especial';

  @override
  String get presetSpecial => 'Atacante especial';

  @override
  String get presetZeroAttack => '0 en Ataque';

  @override
  String get presetZeroSpeed => '0 en Velocidad';

  @override
  String get redo => 'Rehacer';

  @override
  String get removeItem => 'Quitar';

  @override
  String get restorePp => 'Rellenar PP';

  @override
  String get revert => 'Revertir';

  @override
  String get saveDraftBody =>
      'Se crea una copia nueva en el Arca con estos cambios. La copia actual y el archivo original quedan intactos.';

  @override
  String get saveDraftTitle => 'Guardar en el Arca';

  @override
  String saveFailed(String error) {
    return 'No se pudo guardar: $error';
  }

  @override
  String get saveToArca => 'Guardar en el Arca';

  @override
  String get savedToArca => 'Guardado como copia nueva en el Arca';

  @override
  String get seconds => 'Segundos';

  @override
  String get sectionIdentity => 'Identidad';

  @override
  String get sectionInventory => 'Inventario';

  @override
  String get sectionMoves => 'Movimientos';

  @override
  String get sectionPokemon => 'Pokémon';

  @override
  String get sectionStats => 'Estadísticas';

  @override
  String get sectionTrainer => 'Entrenador original';

  @override
  String get sectionTrainerTab => 'Entrenador';

  @override
  String get sectionTraits => 'Nivel y rasgos';

  @override
  String get shinySquare => 'Cuadrado';

  @override
  String get shinyStar => 'Estrella';

  @override
  String slotBox(String box, int n) {
    return '$box, hueco $n';
  }

  @override
  String slotParty(int n) {
    return 'Equipo, hueco $n';
  }

  @override
  String get special => 'Especial';

  @override
  String get species => 'Especie';

  @override
  String get statExp => 'Stat exp';

  @override
  String statsAtLevel(int level) {
    return 'Estadísticas a nivel $level';
  }

  @override
  String get teraOriginal => 'Teratipo original';

  @override
  String get teraType => 'Teratipo';

  @override
  String get trainerApplied => 'Datos del entrenador aplicados al borrador';

  @override
  String get trainerGender => 'Personaje';

  @override
  String get trainerIdLong => 'ID de entrenador (16 bits)';

  @override
  String get trainerIdNote =>
      'Cambiar el ID no cambia el de tus Pokémon: los que capturaste dejarían de ser \"tuyos\".';

  @override
  String get trainerName => 'Nombre';

  @override
  String get trainerNotEditable =>
      'Los datos del entrenador de este save no se pueden editar.';

  @override
  String get undo => 'Deshacer';

  @override
  String unsavedChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cambios sin guardar',
      one: '1 cambio sin guardar',
    );
    return '$_temp0';
  }

  @override
  String get useSpeciesName => 'Usar el nombre de la especie';

  @override
  String visibleId(String id) {
    return 'En el juego: $id';
  }

  @override
  String get pouchMega => 'Megapiedras';

  @override
  String get pouchRecipes => 'Recetas';

  @override
  String get pouchSatchel => 'Bolsa';

  @override
  String get pouchStorage => 'Almacén';

  @override
  String get sectionPokedex => 'Pokédex';

  @override
  String get sectionEvents => 'Eventos';

  @override
  String get legalityAreaOrigin => 'Origen y encuentro';

  @override
  String get legalityAreaMoves => 'Movimientos';

  @override
  String get legalityAreaStats => 'Estadísticas';

  @override
  String get legalityAreaMisc => 'Otros datos';

  @override
  String get legalityFix => 'Intentar corregir';

  @override
  String legalityFixAll(int n) {
    return 'Corregir lo seguro ($n)';
  }

  @override
  String get legalityManual => 'Sin corrección automática: revísalo a mano.';

  @override
  String get legalityScope =>
      'Se comprueban reglas de origen, ball, habilidad, variocolor y aprendizaje, y el encuentro (lugar, nivel y especie) contra las tablas de PKHeX. Incluye las incursiones Dinamax de Espada/Escudo; eventos y teraincursiones aún no se verifican.';

  @override
  String get legalityFixedSnack =>
      'Corrección aplicada. Revisa el resultado antes de guardar.';

  @override
  String get dexSeen => 'Vistos';

  @override
  String get dexCaught => 'Capturados';

  @override
  String get dexShiny => 'Variocolor vistos';

  @override
  String get dexFilterAll => 'Todas';

  @override
  String get dexFilterMissing => 'Por capturar';

  @override
  String get dexFilterSeen => 'Solo vistas';

  @override
  String get dexFilterCaught => 'Capturadas';

  @override
  String get dexSearch => 'Buscar por nombre o número';

  @override
  String get dexComplete => 'Completar';

  @override
  String get dexCompleteShiny => 'Completar con variocolor';

  @override
  String get dexClear => 'Limpiar';

  @override
  String get dexConfirmCompleteTitle => '¿Completar la Pokédex?';

  @override
  String dexConfirmCompleteBody(int n) {
    return 'Las $n especies quedarán vistas y capturadas. Algunos juegos dan premios o activan eventos al completarla, así que cambia tu progreso. Puedes deshacerlo antes de guardar.';
  }

  @override
  String get dexConfirmClearTitle => '¿Limpiar la Pokédex?';

  @override
  String get dexConfirmClearBody =>
      'Se borrarán todos los registros de vistos y capturados. Puedes deshacerlo antes de guardar.';

  @override
  String get dexUnsupported =>
      'La Pokédex de este juego todavía no se puede editar.';

  @override
  String get dexNoMatch => 'Ninguna especie coincide con el filtro.';

  @override
  String get dexToggleSeen => 'Visto';

  @override
  String get dexToggleCaught => 'Capturado';

  @override
  String get dexToggleShiny => 'Variocolor';

  @override
  String get eventsWarningTitle => 'Cambiar eventos puede romper la partida';

  @override
  String get eventsWarningBody =>
      'Flags y constantes controlan la historia, los objetos recogidos y los combates. Un valor equivocado puede bloquear el avance o hacer desaparecer personajes. Cambia solo lo que entiendas: el original queda a salvo en el Arca.';

  @override
  String eventsFlags(int n) {
    return 'Flags ($n)';
  }

  @override
  String eventsWork(int n) {
    return 'Constantes ($n)';
  }

  @override
  String get eventsNamed => 'Con nombre';

  @override
  String get eventsRaw => 'Lista completa';

  @override
  String get eventsSearch => 'Buscar por nombre o número';

  @override
  String get eventsUnsupported =>
      'Este juego todavía no tiene editor de eventos.';

  @override
  String get eventsNoMatch => 'Nada coincide con la búsqueda.';

  @override
  String get eventsUnnamed => 'Sin nombre conocido';

  @override
  String get eventsNoNames =>
      'Para este juego no hay tabla de nombres fiable: se muestra la lista cruda.';

  @override
  String eventsShowing(int n, String shown) {
    return 'Mostrando $shown de $n';
  }

  @override
  String get bulkTitle => 'Importación en bloque';

  @override
  String bulkDetected(int n) {
    return 'Detectados ($n)';
  }

  @override
  String bulkDuplicates(int n) {
    return 'Ya en el Arca ($n)';
  }

  @override
  String bulkRepeated(int n) {
    return 'Repetidos en la selección ($n)';
  }

  @override
  String bulkUnrecognized(int n) {
    return 'No reconocidos ($n)';
  }

  @override
  String bulkIgnored(int n) {
    return '$n archivos ignorados por tamaño o tipo (ROMs, claves, imágenes…).';
  }

  @override
  String bulkImportNew(int n) {
    return 'Importar $n nuevos';
  }

  @override
  String get bulkNothingNew => 'No hay nada nuevo que importar.';

  @override
  String bulkSubfolders(int n) {
    return '$n archivos revisados en la carpeta y sus subcarpetas.';
  }

  @override
  String get archiveExport => 'Exportar el Arca (zip)';

  @override
  String get archiveExportDesc =>
      'Todas las copias con su estructura por juego y un manifiesto JSON.';

  @override
  String get archiveRestore => 'Restaurar desde zip';

  @override
  String get archiveRestoreDesc =>
      'Recupera un zip exportado: añade lo que falte y salta los duplicados.';

  @override
  String archiveExported(int n) {
    return 'Arca exportada: $n copias.';
  }

  @override
  String get archiveEmpty => 'El Arca está vacía: no hay nada que exportar.';

  @override
  String get archiveInvalid =>
      'Ese zip no es una exportación del Arca (falta manifest.json).';

  @override
  String get compareAction => 'Comparar con…';

  @override
  String get compareTitle => 'Comparar copias';

  @override
  String get compareBefore => 'Antes';

  @override
  String get compareAfter => 'Después';

  @override
  String get comparePick => 'Elige la otra copia';

  @override
  String get compareTrainer => 'Entrenador';

  @override
  String get compareParty => 'Equipo';

  @override
  String get compareBoxes => 'Cajas';

  @override
  String get compareInventory => 'Inventario';

  @override
  String get comparePokedex => 'Pokédex';

  @override
  String get compareAdded => 'Entró';

  @override
  String get compareRemoved => 'Salió';

  @override
  String get compareChanged => 'Cambió';

  @override
  String get compareMoved => 'Se movió';

  @override
  String get compareIdentical => 'Las dos copias tienen el mismo contenido.';

  @override
  String compareSummary(int n) {
    return '$n diferencias';
  }

  @override
  String compareDexGained(int n) {
    return '$n especies nuevas en la Pokédex';
  }

  @override
  String compareDexLost(int n) {
    return '$n especies quitadas de la Pokédex';
  }

  @override
  String get compareSwap => 'Intercambiar';

  @override
  String get fieldName => 'Nombre';

  @override
  String get fieldTid => 'ID';

  @override
  String get fieldSid => 'ID secreto';

  @override
  String get fieldMoney => 'Dinero';

  @override
  String get fieldPlayTime => 'Tiempo de juego';

  @override
  String get fieldGender => 'Género';

  @override
  String get fieldSpecies => 'Especie';

  @override
  String get fieldForm => 'Forma';

  @override
  String get fieldNickname => 'Mote';

  @override
  String get fieldLevel => 'Nivel';

  @override
  String get fieldExp => 'Experiencia';

  @override
  String get fieldMoves => 'Movimientos';

  @override
  String get fieldItem => 'Objeto';

  @override
  String get fieldAbility => 'Habilidad';

  @override
  String get fieldNature => 'Naturaleza';

  @override
  String get fieldIvs => 'IVs';

  @override
  String get fieldEvs => 'EVs';

  @override
  String get fieldShiny => 'Variocolor';

  @override
  String get fieldBall => 'Ball';

  @override
  String get fieldFriendship => 'Amistad';

  @override
  String get showMore => 'Mostrar más';

  @override
  String get editPokedex => 'Pokédex actualizada';

  @override
  String get editEvents => 'Eventos modificados';

  @override
  String get dexRegionAll => 'Todas';

  @override
  String get dexRegionNational => 'Nacional';

  @override
  String get dexRegion_galar => 'Galar';

  @override
  String get dexRegion_armor => 'Isla de la Armadura';

  @override
  String get dexRegion_crown => 'Corona Nieve';

  @override
  String get dexRegion_hisui => 'Hisui';

  @override
  String get dexRegion_paldea => 'Paldea';

  @override
  String get dexRegion_kitakami => 'Kitakami';

  @override
  String get dexRegion_blueberry => 'Arándano';

  @override
  String get dexRegion_lumiose => 'Luminalia';

  @override
  String get dexRegion_hyperspace => 'Hiperespacio';

  @override
  String get dexDetailHint =>
      'Mantén pulsada una especie (o clic derecho) para editar géneros y formas.';

  @override
  String get dexDetailTitle => 'Registro de la Pokédex';

  @override
  String get dexDetailSeen => 'Visto';

  @override
  String get dexDetailCaught => 'Capturado';

  @override
  String get dexDetailShiny => 'Visto variocolor';

  @override
  String get dexDetailGenders => 'Géneros vistos';

  @override
  String get dexDetailMale => 'Macho';

  @override
  String get dexDetailFemale => 'Hembra';

  @override
  String get dexDetailGenderless => 'Sin género';

  @override
  String get dexDetailForms => 'Formas vistas';

  @override
  String dexDetailForm(String form) {
    return 'Forma $form';
  }

  @override
  String get dexDetailFormBase => 'Base';

  @override
  String get dexDetailFormUnavailable => 'No está en este juego';

  @override
  String get dexResearch => 'Investigación';

  @override
  String get dexResearchNote =>
      'El nivel de investigación se calcula a partir de las tareas del juego; aquí solo se muestra. Completar la Pokédex no lo modifica.';

  @override
  String get dexDetailApply => 'Aplicar';

  @override
  String dexRegionalNumber(String number, String region) {
    return '$region n.º $number';
  }

  @override
  String exportVerified(String path) {
    return 'Exportado y verificado (checksums y contenido releídos): $path';
  }

  @override
  String exportVerifyFailed(String detail) {
    return 'No se exportó: al releer el archivo generado no coincidía con el borrador ($detail). Tu save original no se ha tocado.';
  }

  @override
  String get legalityAreaEncounter =>
      'Encuentro según las tablas del juego (lugar, nivel y especie)';

  @override
  String get originAdopted => 'Adoptado de la carpeta';

  @override
  String get originMigrated => 'Migrado del Arca anterior';

  @override
  String get onbEyebrow => 'Bienvenido a PKArkTools';

  @override
  String get onbTitle => 'Tu Arca, en tu carpeta';

  @override
  String get onbBody =>
      'Elige una carpeta y todas tus copias vivirán ahí. Si la carpeta está en una nube que sincroniza, tus dispositivos compartirán el Arca sin hacer nada más.';

  @override
  String get onbSuggestICloud =>
      'Sugerencia: crea una carpeta en iCloud Drive y tendrás el mismo Arca en el iPhone, el iPad y el Mac.';

  @override
  String get onbSuggestDocuments =>
      'Sugerencia: una carpeta en Documentos, o dentro de Google Drive, OneDrive, Dropbox o Syncthing para compartirla entre dispositivos.';

  @override
  String get onbChoose => 'Elegir carpeta';

  @override
  String get onbUseLocal => 'Usar carpeta local de la app';

  @override
  String get onbLater => 'Puedes cambiarla cuando quieras en Ajustes.';

  @override
  String get onbPointNoAccount => 'Sin cuentas ni inicio de sesión';

  @override
  String get onbPointReadable =>
      'Archivos legibles: Juego / Entrenador / fecha';

  @override
  String get onbPointSafe => 'Nada se sobrescribe nunca';

  @override
  String onbLegacy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Tus $count copias actuales se copiarán a la carpeta elegida y se comprobarán una a una.',
      one: 'Tu copia actual se copiará a la carpeta elegida y se comprobará.',
    );
    return '$_temp0';
  }

  @override
  String get folderPreparing => 'Preparando el Arca…';

  @override
  String folderProgress(int done, int total) {
    return 'Copiando y verificando $done de $total';
  }

  @override
  String migrationFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copias no se pudieron migrar.',
      one: '1 copia no se pudo migrar.',
    );
    return '$_temp0 El Arca anterior se conserva intacta para no perder nada.';
  }

  @override
  String folderPickFailed(String error) {
    return 'No se pudo usar esa carpeta: $error';
  }

  @override
  String get accessLostTitle => 'No podemos abrir tu Arca';

  @override
  String get accessLostBody =>
      'La app perdió el permiso sobre la carpeta o ya no está disponible (unidad desconectada, carpeta movida o permiso revocado). Tus copias siguen en la carpeta: vuelve a elegirla para continuar.';

  @override
  String get accessRetry => 'Reintentar';

  @override
  String get accessChooseAgain => 'Volver a elegir la carpeta';

  @override
  String get folderSection => 'Carpeta del Arca';

  @override
  String get folderSectionDesc =>
      'Todas las copias viven en esta carpeta. La base de datos de la app es solo un índice de este dispositivo y se reconstruye desde aquí.';

  @override
  String folderSynced(String provider) {
    return 'Sincronizada con $provider';
  }

  @override
  String get folderLocalOnly => 'Solo en este dispositivo';

  @override
  String get folderAppLocal => 'Carpeta local de la app';

  @override
  String get folderReindex => 'Reindexar';

  @override
  String get folderChange => 'Cambiar carpeta…';

  @override
  String get folderChangeTitle => '¿Mover o copiar el Arca?';

  @override
  String get folderChangeBody =>
      'Las copias se escribirán en la carpeta nueva y se comprobará cada una por su SHA-256. Al mover, la carpeta anterior solo se vacía de las copias ya verificadas.';

  @override
  String get folderMove => 'Mover';

  @override
  String get folderCopy => 'Copiar y conservar la anterior';

  @override
  String folderChangeDone(int copied, int skipped) {
    return 'Arca en la carpeta nueva: $copied copiadas, $skipped ya estaban.';
  }

  @override
  String folderLeftBehind(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos sueltos se quedaron en la carpeta anterior.',
      one: '1 archivo suelto se quedó en la carpeta anterior.',
    );
    return '$_temp0';
  }

  @override
  String get reindexNever => 'Aún no se ha revisado la carpeta en esta sesión.';

  @override
  String reindexLast(String time) {
    return 'Última revisión: $time';
  }

  @override
  String reindexResult(int added, int removed, int dups) {
    return 'Reindexado: $added nuevas, $removed quitadas, $dups duplicadas.';
  }

  @override
  String get statBackups => 'copias';

  @override
  String get statIssues => 'problemas';

  @override
  String get statLoose => 'sueltos';

  @override
  String get statIgnored => 'ignorados';

  @override
  String get issuesTitle => 'Problemas';

  @override
  String get issueMissingSave =>
      'Falta el save de este .json (puede estar sincronizándose)';

  @override
  String get issueMissingSidecar =>
      'Falta el .json de este save (puede estar sincronizándose)';

  @override
  String get issueCorruptSidecar => '.json dañado o ilegible';

  @override
  String get issueSizeMismatch => 'El tamaño no coincide con el .json';

  @override
  String get issueHashMismatch => 'El contenido no coincide con su SHA-256';

  @override
  String get issueUnreadable => 'No se pudo leer';

  @override
  String get looseTitle => 'Saves sueltos';

  @override
  String get looseDesc =>
      'Archivos copiados a mano en la carpeta. Al adoptarlos se identifica su juego y se colocan en su sitio con su .json.';

  @override
  String get adopt => 'Adoptar';

  @override
  String get adoptAll => 'Adoptar todos';

  @override
  String adoptDone(String game) {
    return 'Adoptado: $game';
  }

  @override
  String ignoredFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count archivos ignorados (temporales, parciales o copias de conflicto de la nube).',
      one:
          '1 archivo ignorado (temporal, parcial o copia de conflicto de la nube).',
    );
    return '$_temp0';
  }

  @override
  String get snapshotDamaged =>
      'Esta copia está dañada en la carpeta del Arca.';

  @override
  String get dexSearchShort => 'Nombre o número';

  @override
  String get dexDetailHintTouch =>
      'Mantén pulsada una especie para editar géneros y formas.';

  @override
  String get dexFilterLabel => 'Filtrar Pokédex';

  @override
  String get onbSuggestGoogleDrive =>
      'Sugerencia: elige una carpeta dentro de Google Drive para compartir el Arca con tus otros dispositivos, o en Documentos para tenerla solo en este teléfono.';

  @override
  String get onbSuggestOneDrive =>
      'Sugerencia: crea una carpeta en OneDrive y tendrás el mismo Arca en todos tus PC.';

  @override
  String get onbSuggestSyncthing =>
      'Sugerencia: una carpeta sincronizada con Syncthing te da el mismo Arca en todos tus equipos, sin cuentas.';

  @override
  String get boxPrevious => 'Caja anterior';

  @override
  String get boxNext => 'Caja siguiente';

  @override
  String get pouchSwipeHint =>
      'Desliza un objeto hacia la izquierda para quitarlo.';

  @override
  String get cardNoParty => 'Sin equipo en esta copia';

  @override
  String get checksumMinor => 'Verificación: aviso leve';

  @override
  String get checksumMajor => 'Datos dañados';

  @override
  String get damageMinorTitle =>
      'Se lee entero, pero una verificación no coincide';

  @override
  String get damageMajorTitle => 'Parte de este save no se puede leer';

  @override
  String get damagePartWhole =>
      'Las sumas de verificación del archivo no coinciden con sus datos.';

  @override
  String get damagePartTrainer =>
      'El bloque del entrenador no coincide con su verificación.';

  @override
  String get damagePartParty =>
      'El bloque del equipo no coincide con su verificación.';

  @override
  String get damagePartBoxes =>
      'El bloque de cajas no coincide con su verificación.';

  @override
  String get damagePartOther =>
      'Un bloque de otros datos de la partida (objetos, Pokédex, eventos…) no coincide con su verificación.';

  @override
  String get damagePartSignature =>
      'La firma digital del save no corresponde a sus datos.';

  @override
  String get damagePartFileHash =>
      'El hash de verificación del archivo completo no coincide.';

  @override
  String get damagePartUnreadable =>
      'Hay datos que no se pueden leer (Pokémon o valores imposibles).';

  @override
  String get damageMinorMeaning =>
      'Todos los datos se leen bien y puedes verlos. Se abrió en solo lectura porque el juego comprueba estas verificaciones: con una que no coincide, podría no cargar el save o darlo por dañado.';

  @override
  String get damageMajorMeaning =>
      'Lo que ves puede estar incompleto o ser incorrecto. Se abrió en solo lectura: no es seguro editarlo.';

  @override
  String get damageWhy =>
      'Suele pasar cuando el archivo se copió a medias, cuando es un save de otra versión o formato, o cuando otra herramienta lo editó sin recalcular sus verificaciones.';

  @override
  String get damageMinorTodo =>
      'Si el juego carga este save sin problemas, usa «Reparar checksums y exportar» para obtener una copia con las verificaciones recalculadas (la copia del Arca no se toca). Si no, vuelve a copiar el save desde la consola o el emulador.';

  @override
  String get damageMajorTodo =>
      'Vuelve a copiar el save original desde la consola o el emulador e impórtalo de nuevo. Puedes exportar esta copia tal cual con «Exportar».';

  @override
  String get damageRepairExport => 'Reparar checksums y exportar';

  @override
  String get damageTechnical => 'Detalle técnico';

  @override
  String get repairedSuffix => 'reparado';

  @override
  String exportRepaired(String path) {
    return 'Copia reparada, verificada y exportada: $path';
  }

  @override
  String get versionPickMenu => 'Fijar versión del juego…';

  @override
  String get versionPickTitle => 'Versión del juego';

  @override
  String get versionPickBody =>
      'El save no indica qué cartucho es. Elige uno para el color y el título; se guarda en el .json de cada copia.';

  @override
  String get versionUnspecified => 'Sin especificar (pareja)';

  @override
  String versionFromSave(String name) {
    return 'Este save ya indica la versión: $name.';
  }

  @override
  String get spritesSection => 'Iconos';

  @override
  String get spritesSectionDesc =>
      'Los sprites de Pokémon, objetos, Balls, tipos y cintas no vienen con la app: se descargan la primera vez que se ven y se guardan en la caché de la app (nunca en la carpeta del Arca). Sin conexión se muestran las iniciales.';

  @override
  String spritesCacheSize(int count, String size, String total) {
    return 'En caché: $size · descarga completa: $total ($count iconos)';
  }

  @override
  String spritesDownloadAll(String size) {
    return 'Descargar todos los iconos ($size)';
  }

  @override
  String get spritesClear => 'Borrar caché de iconos';

  @override
  String spritesProgress(int done, int total) {
    return '$done de $total iconos';
  }

  @override
  String get spritesDone => 'Todos los iconos están descargados.';

  @override
  String spritesFailed(int count) {
    return 'No se pudieron descargar $count iconos; vuelve a intentarlo con conexión.';
  }

  @override
  String get spritesCancelled => 'Descarga cancelada.';

  @override
  String spritesProgressBytes(
    int done,
    int total,
    String size,
    String totalSize,
  ) {
    return '$done de $total iconos · $size de $totalSize';
  }

  @override
  String get spritesOffline =>
      'Sin conexión a Internet: no se pudo contactar con GitHub. Lo ya descargado se conserva; vuelve a intentarlo con conexión.';

  @override
  String get spritesCleared => 'Caché de iconos borrada.';

  @override
  String spritesCredits(String commit) {
    return 'Iconos: recursos de PKHeX (github.com/kwsch/PKHeX, commit $commit), descargados bajo demanda. Los sprites son © Nintendo / Game Freak / The Pokémon Company.';
  }

  @override
  String get sectionOrigin => 'Origen';

  @override
  String get sectionRibbons => 'Cintas y marcas';

  @override
  String get originGame => 'Juego de origen';

  @override
  String get originPlace => 'Lugar de captura';

  @override
  String get originHatchPlace => 'Lugar de eclosión';

  @override
  String get originLevel => 'Nivel de encuentro';

  @override
  String get originDate => 'Fecha';

  @override
  String get originEggDate => 'Huevo recibido';

  @override
  String get originEncounterHere => 'aparece aquí';

  @override
  String get originShowAll => 'Mostrar todos los lugares del juego';

  @override
  String get originOnlyValid => 'Solo lugares donde aparece';

  @override
  String get originFateful => 'Encuentro fatídico (evento)';

  @override
  String originEggReceived(String date, String place) {
    return 'Huevo recibido en $place el $date';
  }

  @override
  String originHatched(String date, String place) {
    return 'Eclosionó en $place el $date';
  }

  @override
  String originMet(String date, int nLevel, String place) {
    return 'Capturado en $place, nivel $nLevel, $date';
  }

  @override
  String get originNoDate => 'sin fecha (Gen 3)';

  @override
  String originTrainer(String name, String tid) {
    return 'Entrenador original: $name (ID $tid)';
  }

  @override
  String originHomeTracker(String tracker) {
    return 'Pasó por Pokémon HOME (rastreador $tracker)';
  }

  @override
  String get originNotInGame =>
      'Esta especie no aparece en las tablas de encuentros de su juego de origen (¿evento, intercambio o huevo?).';

  @override
  String originValidPlaces(String places) {
    return 'El lugar o el nivel no cuadran con su juego. Lugares válidos: $places';
  }

  @override
  String get transferPalPark => 'Parque Compi';

  @override
  String get transferPokeTransfer => 'Pokétransfer';

  @override
  String get transferTransporter => 'Poké Transporter / Banco';

  @override
  String get transferVirtualConsole => 'Consola Virtual → Poké Transporter';

  @override
  String get transferBank => 'Pokémon Banco';

  @override
  String get ribbonsContest => 'Concursos';

  @override
  String get ribbonsBattle => 'Batalla';

  @override
  String get ribbonsCommemorative => 'Conmemorativas';

  @override
  String get ribbonsEvent => 'Eventos';

  @override
  String get ribbonsMarks => 'Marcas';

  @override
  String ribbonsOwned(int count, int nTotal) {
    return '$count de $nTotal';
  }

  @override
  String get ribbonsOnlyOwned => 'Solo las que tiene';

  @override
  String get ribbonsGiveAll => 'Dar todas las válidas';

  @override
  String get ribbonsRemoveAll => 'Quitar todas';

  @override
  String ribbonsGiven(int count) {
    return '$count cintas añadidas.';
  }

  @override
  String get ribbonsNone => 'No tiene cintas ni marcas.';

  @override
  String get ribbonHas => 'La tiene';

  @override
  String get ribbonAffixed => 'Cinta mostrada';

  @override
  String get ribbonAffixedHint => 'Se muestra junto a su nombre (título).';

  @override
  String ribbonAffixedNow(String name) {
    return 'Muestra: $name';
  }

  @override
  String get ribbonEventOnly => 'Solo se repartió en eventos.';

  @override
  String get ribbonEncounterMark =>
      'Marca de encuentro: la pone el juego al capturarlo.';

  @override
  String get ribbonObtainable =>
      'Se puede conseguir en los juegos por los que pudo pasar.';

  @override
  String get ribbonNotObtainable =>
      'No se puede conseguir en los juegos por los que pudo pasar.';

  @override
  String get originDateUnknown => 'sin fecha';

  @override
  String get filtersAction => 'Filtros';

  @override
  String get filtersTitle => 'Filtros';

  @override
  String get filtersClear => 'Limpiar';

  @override
  String get filtersClearAll => 'Limpiar filtros';

  @override
  String filtersShow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ver $count partidas',
      one: 'Ver 1 partida',
      zero: 'Ninguna partida',
    );
    return '$_temp0';
  }

  @override
  String filtersResults(int count, int nTotal) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partidas de $nTotal',
      one: '1 partida de $nTotal',
    );
    return '$_temp0';
  }

  @override
  String get filtersNoMatchTitle => 'Ninguna partida coincide';

  @override
  String get filtersNoMatchBody =>
      'Prueba a quitar algún filtro o cambia la búsqueda.';

  @override
  String filtersRemove(String label) {
    return 'Quitar filtro $label';
  }

  @override
  String get sortLabel => 'Ordenar';

  @override
  String get sortRecent => 'Más reciente';

  @override
  String get sortTrainer => 'Entrenador';

  @override
  String get sortGame => 'Juego / generación';

  @override
  String get sortPlayTime => 'Horas de juego';

  @override
  String get sortCopies => 'Número de copias';

  @override
  String get filterGeneration => 'Generación';

  @override
  String filterGenShort(int gen) {
    return 'Gen $gen';
  }

  @override
  String get filterPlatform => 'Consola';

  @override
  String get filterSource => 'Origen';

  @override
  String get sourceEmulator => 'Emulador';

  @override
  String get sourceMobile => 'Port Android/iOS';

  @override
  String get sourceCheckpoint => 'Checkpoint/JKSM';

  @override
  String get sourceCartridge => 'Cartucho';

  @override
  String get sourceOther => 'Otro / desconocido';

  @override
  String get filterGame => 'Juego';

  @override
  String get filterStatus => 'Estado';

  @override
  String get statusDamaged => 'Con avisos de daño';

  @override
  String get statusLegality => 'Con avisos de legalidad';

  @override
  String get statusEdited => 'Editadas por mí';

  @override
  String get statusMultiple => 'Con varias copias';

  @override
  String legalityScanning(int done, int nTotal) {
    return 'Revisando legalidad… $done de $nTotal';
  }

  @override
  String get filterDate => 'Última copia';

  @override
  String get datePresetWeek => 'Última semana';

  @override
  String get datePresetMonth => 'Último mes';

  @override
  String get datePresetYear => 'Último año';

  @override
  String get dateCustom => 'Elegir fechas…';

  @override
  String dateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String spritesOnDisk(int nTotal, int nValid) {
    return 'Guardados y válidos: $nValid de $nTotal iconos.';
  }

  @override
  String spritesMissing(int count) {
    return 'Faltan $count iconos o están dañados (vacíos o cortados): «Reparar iconos» descarga solo esos.';
  }

  @override
  String spritesRepair(int count) {
    return 'Reparar iconos ($count)';
  }

  @override
  String spritesIncomplete(int count) {
    return 'La descarga terminó, pero faltan $count iconos. Pulsa «Reparar iconos» con conexión.';
  }

  @override
  String get originRestored => 'Restaurada';

  @override
  String currentVersionTitle(String date) {
    return 'Versión actual · $date';
  }

  @override
  String mainFileLabel(String name) {
    return 'En la carpeta como «$name», lista para copiar al juego o al emulador.';
  }

  @override
  String get openFolder => 'Abrir carpeta';

  @override
  String get openFolderTitle => 'Carpeta de la partida';

  @override
  String openFolderBody(String path, String root) {
    return 'Dentro de la carpeta del Arca ($root):\n\n$path';
  }

  @override
  String get copyPath => 'Copiar ruta';

  @override
  String get pathCopied => 'Ruta copiada';

  @override
  String historyCount(int count) {
    return 'Historial ($count)';
  }

  @override
  String get historyFoldedHint =>
      'Todas las copias, de la más reciente a la más antigua. Nunca se modifican.';

  @override
  String get mainModifiedTitle => 'El archivo principal cambió fuera de la app';

  @override
  String mainModifiedBody(String name) {
    return '«$name» no coincide con ninguna copia del historial (¿copiaste encima un save nuevo?). Guárdalo como copia nueva para conservarlo; nunca se borra.';
  }

  @override
  String get saveAsNewCopy => 'Guardar como nueva copia';

  @override
  String savedAsNewCopy(String name) {
    return 'Guardado en el historial: $name';
  }

  @override
  String get restoreAsCurrentTitle => '¿Restaurar como versión actual?';

  @override
  String restoreAsCurrentBody(String name) {
    return 'Se creará una entrada nueva en el historial con esta copia y el archivo principal («$name») pasará a ser esta versión. Ninguna copia del historial se modifica.';
  }

  @override
  String get restoreAlsoSource => 'Restaurar y escribir en el original';

  @override
  String get restoredAsCurrent => 'Copia restaurada como versión actual';

  @override
  String restoredNote(String date) {
    return 'Restaurada desde la copia del $date';
  }

  @override
  String get arcaLayoutTitle => 'Cómo se organiza la carpeta';

  @override
  String get arcaLayoutDesc =>
      'Cada partida tiene su carpeta con la última versión, con el nombre que usa el juego (main, SaveData.bin, Esmeralda.sav…), lista para copiar al juego o al emulador. Debajo, historial/ guarda todas las copias sin modificarlas nunca. La última versión es una copia derivada: se regenera siempre desde el historial, así que nada se pierde aunque la borres o la cambies.';

  @override
  String get modifiedMainsTitle => 'Archivos principales cambiados a mano';

  @override
  String get modifiedMainsDesc =>
      'No coinciden con ninguna copia del historial. Guárdalos como copia nueva; la app no los toca hasta entonces.';

  @override
  String historyMigrated(int count) {
    return 'Carpeta actualizada: $count copias movidas a historial/';
  }
}
