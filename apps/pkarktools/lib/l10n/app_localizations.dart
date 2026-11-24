import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'PKArkTools'**
  String get appTitle;

  /// No description provided for @navArca.
  ///
  /// In es, this message translates to:
  /// **'Arca'**
  String get navArca;

  /// No description provided for @navActivity.
  ///
  /// In es, this message translates to:
  /// **'Actividad'**
  String get navActivity;

  /// No description provided for @navSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get navSettings;

  /// No description provided for @arcaTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu Arca'**
  String get arcaTitle;

  /// No description provided for @arcaSubtitle.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Aún no hay partidas} =1{1 partida a salvo} other{{count} partidas a salvo}}'**
  String arcaSubtitle(int count);

  /// No description provided for @importAction.
  ///
  /// In es, this message translates to:
  /// **'Importar'**
  String get importAction;

  /// No description provided for @importFile.
  ///
  /// In es, this message translates to:
  /// **'Importar archivo'**
  String get importFile;

  /// No description provided for @importFolder.
  ///
  /// In es, this message translates to:
  /// **'Importar carpeta'**
  String get importFolder;

  /// No description provided for @importSheetTitle.
  ///
  /// In es, this message translates to:
  /// **'Añadir al Arca'**
  String get importSheetTitle;

  /// No description provided for @importFileDesc.
  ///
  /// In es, this message translates to:
  /// **'Saves de cartucho o exportados: .sav, .srm, .dsv, main…'**
  String get importFileDesc;

  /// No description provided for @importFolderDesc.
  ///
  /// In es, this message translates to:
  /// **'Carpetas de Checkpoint, JKSM o de emuladores de Switch. Se buscan saves dentro.'**
  String get importFolderDesc;

  /// No description provided for @emptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu Arca está vacía'**
  String get emptyTitle;

  /// No description provided for @emptyBody.
  ///
  /// In es, this message translates to:
  /// **'Importa un save para guardar una copia segura con su historial. Nada sale de este dispositivo.'**
  String get emptyBody;

  /// No description provided for @loadDemo.
  ///
  /// In es, this message translates to:
  /// **'Probar con partidas de ejemplo'**
  String get loadDemo;

  /// No description provided for @demoLoaded.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Se añadió 1 partida de ejemplo} other{Se añadieron {count} partidas de ejemplo}}'**
  String demoLoaded(int count);

  /// No description provided for @hoursShort.
  ///
  /// In es, this message translates to:
  /// **'{hours} h'**
  String hoursShort(int hours);

  /// No description provided for @playTime.
  ///
  /// In es, this message translates to:
  /// **'Tiempo de juego'**
  String get playTime;

  /// No description provided for @trainerId.
  ///
  /// In es, this message translates to:
  /// **'ID'**
  String get trainerId;

  /// No description provided for @secretId.
  ///
  /// In es, this message translates to:
  /// **'ID secreta'**
  String get secretId;

  /// No description provided for @inBoxes.
  ///
  /// In es, this message translates to:
  /// **'En cajas'**
  String get inBoxes;

  /// No description provided for @copies.
  ///
  /// In es, this message translates to:
  /// **'Copias'**
  String get copies;

  /// No description provided for @lastCopy.
  ///
  /// In es, this message translates to:
  /// **'Última copia: {date}'**
  String lastCopy(String date);

  /// No description provided for @team.
  ///
  /// In es, this message translates to:
  /// **'Equipo'**
  String get team;

  /// No description provided for @boxes.
  ///
  /// In es, this message translates to:
  /// **'Cajas'**
  String get boxes;

  /// No description provided for @history.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get history;

  /// No description provided for @emptyTeam.
  ///
  /// In es, this message translates to:
  /// **'Sin Pokémon en el equipo'**
  String get emptyTeam;

  /// No description provided for @notSupportedStorage.
  ///
  /// In es, this message translates to:
  /// **'Este juego todavía no muestra equipo ni cajas; llegará en una próxima fase. El entrenador y el historial ya funcionan.'**
  String get notSupportedStorage;

  /// No description provided for @shiny.
  ///
  /// In es, this message translates to:
  /// **'Variocolor'**
  String get shiny;

  /// No description provided for @egg.
  ///
  /// In es, this message translates to:
  /// **'Huevo'**
  String get egg;

  /// No description provided for @level.
  ///
  /// In es, this message translates to:
  /// **'Nv. {level}'**
  String level(int level);

  /// No description provided for @export.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get export;

  /// No description provided for @restore.
  ///
  /// In es, this message translates to:
  /// **'Restaurar'**
  String get restore;

  /// No description provided for @viewing.
  ///
  /// In es, this message translates to:
  /// **'En pantalla'**
  String get viewing;

  /// No description provided for @view.
  ///
  /// In es, this message translates to:
  /// **'Ver'**
  String get view;

  /// No description provided for @latest.
  ///
  /// In es, this message translates to:
  /// **'Más reciente'**
  String get latest;

  /// No description provided for @exportDone.
  ///
  /// In es, this message translates to:
  /// **'Exportado a {path}'**
  String exportDone(String path);

  /// No description provided for @exportFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo exportar: {error}'**
  String exportFailed(String error);

  /// No description provided for @restoreTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Restaurar esta copia?'**
  String get restoreTitle;

  /// No description provided for @restoreBody.
  ///
  /// In es, this message translates to:
  /// **'Se reemplazará el archivo original:\n{path}\n\nAntes, el Arca guardará una copia del archivo actual para que puedas volver atrás.'**
  String restoreBody(String path);

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @restoreDone.
  ///
  /// In es, this message translates to:
  /// **'Copia restaurada en su ubicación original'**
  String get restoreDone;

  /// No description provided for @restoreFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo restaurar: {error}'**
  String restoreFailed(String error);

  /// No description provided for @restoreUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Esta copia no tiene un archivo original accesible. Usa Exportar para guardarla donde quieras.'**
  String get restoreUnavailable;

  /// No description provided for @importResultTitle.
  ///
  /// In es, this message translates to:
  /// **'Importación terminada'**
  String get importResultTitle;

  /// No description provided for @importAdded.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 copia nueva} other{{count} copias nuevas}}'**
  String importAdded(int count);

  /// No description provided for @importDuplicates.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 ya estaba en el Arca} other{{count} ya estaban en el Arca}}'**
  String importDuplicates(int count);

  /// No description provided for @importFailedCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 archivo no reconocido} other{{count} archivos no reconocidos}}'**
  String importFailedCount(int count);

  /// No description provided for @done.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get done;

  /// No description provided for @openSave.
  ///
  /// In es, this message translates to:
  /// **'Abrir partida'**
  String get openSave;

  /// No description provided for @folderScanning.
  ///
  /// In es, this message translates to:
  /// **'Buscando saves… {count} archivos revisados'**
  String folderScanning(int count);

  /// No description provided for @folderFound.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{No se encontraron saves} =1{1 save encontrado} other{{count} saves encontrados}}'**
  String folderFound(int count);

  /// No description provided for @folderNoneHint.
  ///
  /// In es, this message translates to:
  /// **'Revisa que la carpeta tenga archivos de save (no ROMs). En emuladores de Switch elige la carpeta nand/user/save.'**
  String get folderNoneHint;

  /// No description provided for @importSelected.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Importar 1 save} other{Importar {count} saves}}'**
  String importSelected(int count);

  /// No description provided for @deleteSave.
  ///
  /// In es, this message translates to:
  /// **'Eliminar del Arca'**
  String get deleteSave;

  /// No description provided for @deleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar esta partida del Arca?'**
  String get deleteTitle;

  /// No description provided for @deleteBody.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Se borrará su copia guardada.} other{Se borrarán sus {count} copias guardadas.}} Los archivos originales no se tocan.'**
  String deleteBody(int count);

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @checksumValid.
  ///
  /// In es, this message translates to:
  /// **'Checksum correcto'**
  String get checksumValid;

  /// No description provided for @activityEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aquí verás cada copia que entre al Arca, en orden.'**
  String get activityEmpty;

  /// No description provided for @theme.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get theme;

  /// No description provided for @themeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get themeSystem;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get languageSystem;

  /// No description provided for @about.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get about;

  /// No description provided for @aboutBody.
  ///
  /// In es, this message translates to:
  /// **'PKArkTools guarda copias versionadas de tus partidas de Pokémon de todas las generaciones. Es software libre (GPL-3.0) y porta lógica de PKHeX.Core. No incluye ROMs, claves ni contenido de los juegos.'**
  String get aboutBody;

  /// No description provided for @licenses.
  ///
  /// In es, this message translates to:
  /// **'Licencias de código abierto'**
  String get licenses;

  /// No description provided for @sampleData.
  ///
  /// In es, this message translates to:
  /// **'Datos de ejemplo'**
  String get sampleData;

  /// No description provided for @sampleDataDesc.
  ///
  /// In es, this message translates to:
  /// **'Añade partidas sintéticas para explorar la app.'**
  String get sampleDataDesc;

  /// No description provided for @originFile.
  ///
  /// In es, this message translates to:
  /// **'Archivo'**
  String get originFile;

  /// No description provided for @originFolder.
  ///
  /// In es, this message translates to:
  /// **'Carpeta'**
  String get originFolder;

  /// No description provided for @originSaf.
  ///
  /// In es, this message translates to:
  /// **'Carpeta del emulador'**
  String get originSaf;

  /// No description provided for @originDemo.
  ///
  /// In es, this message translates to:
  /// **'Ejemplo'**
  String get originDemo;

  /// No description provided for @originRestore.
  ///
  /// In es, this message translates to:
  /// **'Respaldo antes de restaurar'**
  String get originRestore;

  /// No description provided for @genLabel.
  ///
  /// In es, this message translates to:
  /// **'Gen {gen}'**
  String genLabel(int gen);

  /// No description provided for @boxEmpty.
  ///
  /// In es, this message translates to:
  /// **'Caja vacía'**
  String get boxEmpty;

  /// No description provided for @loadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer esta copia: {error}'**
  String loadError(String error);

  /// No description provided for @moreActions.
  ///
  /// In es, this message translates to:
  /// **'Más acciones'**
  String get moreActions;

  /// No description provided for @pokemonCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 Pokémon} other{{count} Pokémon}}'**
  String pokemonCount(int count);

  /// No description provided for @snapshotOf.
  ///
  /// In es, this message translates to:
  /// **'Copia del {date}'**
  String snapshotOf(String date);

  /// No description provided for @searchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar por entrenador o juego'**
  String get searchHint;

  /// No description provided for @noResults.
  ///
  /// In es, this message translates to:
  /// **'Nada coincide con «{query}»'**
  String noResults(String query);

  /// No description provided for @ability.
  ///
  /// In es, this message translates to:
  /// **'Habilidad'**
  String get ability;

  /// No description provided for @addItem.
  ///
  /// In es, this message translates to:
  /// **'Añadir objeto'**
  String get addItem;

  /// No description provided for @addToSlot.
  ///
  /// In es, this message translates to:
  /// **'Añadir al hueco'**
  String get addToSlot;

  /// No description provided for @addToTeam.
  ///
  /// In es, this message translates to:
  /// **'Añadir al equipo'**
  String get addToTeam;

  /// No description provided for @andMore.
  ///
  /// In es, this message translates to:
  /// **'…y {count} cambios más'**
  String andMore(int count);

  /// No description provided for @applyChanges.
  ///
  /// In es, this message translates to:
  /// **'Aplicar cambios'**
  String get applyChanges;

  /// No description provided for @avs.
  ///
  /// In es, this message translates to:
  /// **'Valores de despertar (AV)'**
  String get avs;

  /// No description provided for @ball.
  ///
  /// In es, this message translates to:
  /// **'Poké Ball'**
  String get ball;

  /// No description provided for @baseTotal.
  ///
  /// In es, this message translates to:
  /// **'Total base'**
  String get baseTotal;

  /// No description provided for @boxFull.
  ///
  /// In es, this message translates to:
  /// **'Esa caja está llena'**
  String get boxFull;

  /// No description provided for @boxesFull.
  ///
  /// In es, this message translates to:
  /// **'Todas las cajas están llenas'**
  String get boxesFull;

  /// No description provided for @changeNote.
  ///
  /// In es, this message translates to:
  /// **'Descripción de los cambios'**
  String get changeNote;

  /// No description provided for @changesStayInDraft.
  ///
  /// In es, this message translates to:
  /// **'Los cambios van al borrador; el archivo original no se toca.'**
  String get changesStayInDraft;

  /// No description provided for @clonePokemon.
  ///
  /// In es, this message translates to:
  /// **'Clonar en la primera caja libre'**
  String get clonePokemon;

  /// No description provided for @clonedTo.
  ///
  /// In es, this message translates to:
  /// **'Clon colocado en {slot}'**
  String clonedTo(String slot);

  /// No description provided for @createPokemon.
  ///
  /// In es, this message translates to:
  /// **'Crear Pokémon'**
  String get createPokemon;

  /// No description provided for @createPokemonDesc.
  ///
  /// In es, this message translates to:
  /// **'Con tu nombre de entrenador, tu ID y movimientos de su nivel'**
  String get createPokemonDesc;

  /// No description provided for @deletePokemon.
  ///
  /// In es, this message translates to:
  /// **'Borrar del save'**
  String get deletePokemon;

  /// No description provided for @discard.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get discard;

  /// No description provided for @discardDraftBody.
  ///
  /// In es, this message translates to:
  /// **'Se perderán todas las ediciones que no hayas guardado en el Arca.'**
  String get discardDraftBody;

  /// No description provided for @discardDraftTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar los cambios?'**
  String get discardDraftTitle;

  /// No description provided for @discardPokemonBody.
  ///
  /// In es, this message translates to:
  /// **'Los cambios de este Pokémon no se aplicarán al borrador.'**
  String get discardPokemonBody;

  /// No description provided for @discardPokemonTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Salir sin aplicar?'**
  String get discardPokemonTitle;

  /// No description provided for @dragHint.
  ///
  /// In es, this message translates to:
  /// **'Arrastra un Pokémon para moverlo o intercambiarlo; suéltalo en el nombre de una caja para enviarlo allí.'**
  String get dragHint;

  /// No description provided for @dragHintGb.
  ///
  /// In es, this message translates to:
  /// **'En Game Boy las cajas son listas: al mover o borrar, los Pokémon se reordenan sin huecos.'**
  String get dragHintGb;

  /// No description provided for @dragHintTouch.
  ///
  /// In es, this message translates to:
  /// **'Mantén pulsado un Pokémon para arrastrarlo; suéltalo en otro hueco o en el nombre de una caja.'**
  String get dragHintTouch;

  /// No description provided for @dvs.
  ///
  /// In es, this message translates to:
  /// **'DVs (valores determinantes)'**
  String get dvs;

  /// No description provided for @editBoxName.
  ///
  /// In es, this message translates to:
  /// **'Caja {box} renombrada a «{name}»'**
  String editBoxName(int box, String name);

  /// No description provided for @editClear.
  ///
  /// In es, this message translates to:
  /// **'{species} borrado de {slot}'**
  String editClear(String species, String slot);

  /// No description provided for @editInventory.
  ///
  /// In es, this message translates to:
  /// **'Inventario actualizado'**
  String get editInventory;

  /// No description provided for @editMove.
  ///
  /// In es, this message translates to:
  /// **'Movido de {from} a {to}'**
  String editMove(String from, String to);

  /// No description provided for @editPokemon.
  ///
  /// In es, this message translates to:
  /// **'Editar Pokémon'**
  String get editPokemon;

  /// No description provided for @editSet.
  ///
  /// In es, this message translates to:
  /// **'{species} en {slot}'**
  String editSet(String species, String slot);

  /// No description provided for @editTrainer.
  ///
  /// In es, this message translates to:
  /// **'Datos del entrenador actualizados'**
  String get editTrainer;

  /// No description provided for @editedSuffix.
  ///
  /// In es, this message translates to:
  /// **'editado'**
  String get editedSuffix;

  /// No description provided for @evTotal.
  ///
  /// In es, this message translates to:
  /// **'{total} / {max}'**
  String evTotal(int total, int max);

  /// No description provided for @evs.
  ///
  /// In es, this message translates to:
  /// **'EVs (puntos de esfuerzo)'**
  String get evs;

  /// No description provided for @experience.
  ///
  /// In es, this message translates to:
  /// **'Experiencia'**
  String get experience;

  /// No description provided for @exportFile.
  ///
  /// In es, this message translates to:
  /// **'Exportar archivo'**
  String get exportFile;

  /// No description provided for @exportPokemon.
  ///
  /// In es, this message translates to:
  /// **'Exportar como .{ext}'**
  String exportPokemon(String ext);

  /// No description provided for @exportReady.
  ///
  /// In es, this message translates to:
  /// **'Archivo listo para el juego en {path}'**
  String exportReady(String path);

  /// No description provided for @female.
  ///
  /// In es, this message translates to:
  /// **'Chica'**
  String get female;

  /// No description provided for @form.
  ///
  /// In es, this message translates to:
  /// **'Forma'**
  String get form;

  /// No description provided for @formBase.
  ///
  /// In es, this message translates to:
  /// **'Normal'**
  String get formBase;

  /// No description provided for @formN.
  ///
  /// In es, this message translates to:
  /// **'Forma {n}'**
  String formN(int n);

  /// No description provided for @friendship.
  ///
  /// In es, this message translates to:
  /// **'Amistad'**
  String get friendship;

  /// No description provided for @gender.
  ///
  /// In es, this message translates to:
  /// **'Género'**
  String get gender;

  /// No description provided for @gvs.
  ///
  /// In es, this message translates to:
  /// **'Niveles de esfuerzo (GV)'**
  String get gvs;

  /// No description provided for @heldItem.
  ///
  /// In es, this message translates to:
  /// **'Objeto equipado'**
  String get heldItem;

  /// No description provided for @hiddenAbility.
  ///
  /// In es, this message translates to:
  /// **'oculta'**
  String get hiddenAbility;

  /// No description provided for @hours.
  ///
  /// In es, this message translates to:
  /// **'Horas'**
  String get hours;

  /// No description provided for @hpDerived.
  ///
  /// In es, this message translates to:
  /// **'El DV de PS se deriva del resto'**
  String get hpDerived;

  /// No description provided for @importInvalidPokemon.
  ///
  /// In es, this message translates to:
  /// **'El archivo no contiene un Pokémon válido (checksum incorrecto).'**
  String get importInvalidPokemon;

  /// No description provided for @importPokemon.
  ///
  /// In es, this message translates to:
  /// **'Importar .{ext}'**
  String importPokemon(String ext);

  /// No description provided for @importPokemonDesc.
  ///
  /// In es, this message translates to:
  /// **'Un Pokémon exportado de este mismo formato'**
  String get importPokemonDesc;

  /// No description provided for @importWrongFormat.
  ///
  /// In es, this message translates to:
  /// **'Un .{got} no es compatible con este juego; necesita .{want}.'**
  String importWrongFormat(String got, String want);

  /// No description provided for @importedPokemon.
  ///
  /// In es, this message translates to:
  /// **'{species} importado al borrador'**
  String importedPokemon(String species);

  /// No description provided for @inventoryApplied.
  ///
  /// In es, this message translates to:
  /// **'Inventario aplicado al borrador'**
  String get inventoryApplied;

  /// No description provided for @inventoryUnsupported.
  ///
  /// In es, this message translates to:
  /// **'El inventario de este juego todavía no se puede editar.'**
  String get inventoryUnsupported;

  /// No description provided for @itemWrongPouch.
  ///
  /// In es, this message translates to:
  /// **'Este objeto no suele ir en este bolsillo'**
  String get itemWrongPouch;

  /// No description provided for @ivs.
  ///
  /// In es, this message translates to:
  /// **'IVs (valores individuales)'**
  String get ivs;

  /// No description provided for @keepEditing.
  ///
  /// In es, this message translates to:
  /// **'Seguir editando'**
  String get keepEditing;

  /// No description provided for @leaveDraftBody.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Hay 1 cambio sin guardar en el Arca.} other{Hay {count} cambios sin guardar en el Arca.}} Si sales, se descartan.'**
  String leaveDraftBody(int count);

  /// No description provided for @leaveDraftTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Salir sin guardar?'**
  String get leaveDraftTitle;

  /// No description provided for @legalityClean.
  ///
  /// In es, this message translates to:
  /// **'Sin avisos de legalidad básicos.'**
  String get legalityClean;

  /// No description provided for @legalityHint.
  ///
  /// In es, this message translates to:
  /// **'Son solo avisos: puedes guardar igualmente.'**
  String get legalityHint;

  /// No description provided for @legalityTitle.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 aviso} other{{count} avisos}}'**
  String legalityTitle(int count);

  /// No description provided for @legendBase.
  ///
  /// In es, this message translates to:
  /// **'Base'**
  String get legendBase;

  /// No description provided for @levelLabel.
  ///
  /// In es, this message translates to:
  /// **'Nivel'**
  String get levelLabel;

  /// No description provided for @male.
  ///
  /// In es, this message translates to:
  /// **'Chico'**
  String get male;

  /// No description provided for @maxPpUps.
  ///
  /// In es, this message translates to:
  /// **'Más PP al máximo'**
  String get maxPpUps;

  /// No description provided for @mint.
  ///
  /// In es, this message translates to:
  /// **'Menta (naturaleza de stats)'**
  String get mint;

  /// No description provided for @minutes.
  ///
  /// In es, this message translates to:
  /// **'Minutos'**
  String get minutes;

  /// No description provided for @money.
  ///
  /// In es, this message translates to:
  /// **'Dinero'**
  String get money;

  /// No description provided for @moneyMax.
  ///
  /// In es, this message translates to:
  /// **'Máximo {max}'**
  String moneyMax(int max);

  /// No description provided for @moveN.
  ///
  /// In es, this message translates to:
  /// **'Movimiento {n}'**
  String moveN(int n);

  /// No description provided for @nature.
  ///
  /// In es, this message translates to:
  /// **'Naturaleza'**
  String get nature;

  /// No description provided for @neutral.
  ///
  /// In es, this message translates to:
  /// **'neutra'**
  String get neutral;

  /// No description provided for @newPokemon.
  ///
  /// In es, this message translates to:
  /// **'Nuevo Pokémon'**
  String get newPokemon;

  /// No description provided for @nickname.
  ///
  /// In es, this message translates to:
  /// **'Apodo'**
  String get nickname;

  /// No description provided for @no.
  ///
  /// In es, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @noChanges.
  ///
  /// In es, this message translates to:
  /// **'Sin cambios: el borrador coincide con esta copia'**
  String get noChanges;

  /// No description provided for @noMatches.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados'**
  String get noMatches;

  /// No description provided for @none.
  ///
  /// In es, this message translates to:
  /// **'Ninguno'**
  String get none;

  /// No description provided for @originEdit.
  ///
  /// In es, this message translates to:
  /// **'Edición'**
  String get originEdit;

  /// No description provided for @otGender.
  ///
  /// In es, this message translates to:
  /// **'Género del entrenador'**
  String get otGender;

  /// No description provided for @otName.
  ///
  /// In es, this message translates to:
  /// **'Entrenador original'**
  String get otName;

  /// No description provided for @pokemon.
  ///
  /// In es, this message translates to:
  /// **'Pokémon'**
  String get pokemon;

  /// No description provided for @pouchBalls.
  ///
  /// In es, this message translates to:
  /// **'Poké Balls'**
  String get pouchBalls;

  /// No description provided for @pouchBattle.
  ///
  /// In es, this message translates to:
  /// **'Combate'**
  String get pouchBattle;

  /// No description provided for @pouchBerries.
  ///
  /// In es, this message translates to:
  /// **'Bayas'**
  String get pouchBerries;

  /// No description provided for @pouchCandy.
  ///
  /// In es, this message translates to:
  /// **'Caramelos y materiales'**
  String get pouchCandy;

  /// No description provided for @pouchEmpty.
  ///
  /// In es, this message translates to:
  /// **'Este bolsillo está vacío. Añade objetos con el buscador.'**
  String get pouchEmpty;

  /// No description provided for @pouchFull.
  ///
  /// In es, this message translates to:
  /// **'Bolsillo lleno'**
  String get pouchFull;

  /// No description provided for @pouchIngredients.
  ///
  /// In es, this message translates to:
  /// **'Ingredientes'**
  String get pouchIngredients;

  /// No description provided for @pouchItems.
  ///
  /// In es, this message translates to:
  /// **'Objetos'**
  String get pouchItems;

  /// No description provided for @pouchKey.
  ///
  /// In es, this message translates to:
  /// **'Objetos clave'**
  String get pouchKey;

  /// No description provided for @pouchMail.
  ///
  /// In es, this message translates to:
  /// **'Cartas'**
  String get pouchMail;

  /// No description provided for @pouchMedicine.
  ///
  /// In es, this message translates to:
  /// **'Botiquín'**
  String get pouchMedicine;

  /// No description provided for @pouchPc.
  ///
  /// In es, this message translates to:
  /// **'PC'**
  String get pouchPc;

  /// No description provided for @pouchTms.
  ///
  /// In es, this message translates to:
  /// **'MT y MO'**
  String get pouchTms;

  /// No description provided for @pouchTreasure.
  ///
  /// In es, this message translates to:
  /// **'Tesoros'**
  String get pouchTreasure;

  /// No description provided for @pouchUsage.
  ///
  /// In es, this message translates to:
  /// **'{used} / {capacity}'**
  String pouchUsage(int used, int capacity);

  /// No description provided for @pouchZ.
  ///
  /// In es, this message translates to:
  /// **'Cristales Z / mejoras'**
  String get pouchZ;

  /// No description provided for @ppUps.
  ///
  /// In es, this message translates to:
  /// **'Más PP'**
  String get ppUps;

  /// No description provided for @presetClear.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get presetClear;

  /// No description provided for @presetMaxAvs.
  ///
  /// In es, this message translates to:
  /// **'Todos a 200'**
  String get presetMaxAvs;

  /// No description provided for @presetMaxGvs.
  ///
  /// In es, this message translates to:
  /// **'Todos a 10'**
  String get presetMaxGvs;

  /// No description provided for @presetMaxStatExp.
  ///
  /// In es, this message translates to:
  /// **'Todo al máximo'**
  String get presetMaxStatExp;

  /// No description provided for @presetPerfectIvs.
  ///
  /// In es, this message translates to:
  /// **'IVs perfectos'**
  String get presetPerfectIvs;

  /// No description provided for @presetPhysWall.
  ///
  /// In es, this message translates to:
  /// **'Muro físico'**
  String get presetPhysWall;

  /// No description provided for @presetPhysical.
  ///
  /// In es, this message translates to:
  /// **'Atacante físico'**
  String get presetPhysical;

  /// No description provided for @presetSpecWall.
  ///
  /// In es, this message translates to:
  /// **'Muro especial'**
  String get presetSpecWall;

  /// No description provided for @presetSpecial.
  ///
  /// In es, this message translates to:
  /// **'Atacante especial'**
  String get presetSpecial;

  /// No description provided for @presetZeroAttack.
  ///
  /// In es, this message translates to:
  /// **'0 en Ataque'**
  String get presetZeroAttack;

  /// No description provided for @presetZeroSpeed.
  ///
  /// In es, this message translates to:
  /// **'0 en Velocidad'**
  String get presetZeroSpeed;

  /// No description provided for @redo.
  ///
  /// In es, this message translates to:
  /// **'Rehacer'**
  String get redo;

  /// No description provided for @removeItem.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get removeItem;

  /// No description provided for @restorePp.
  ///
  /// In es, this message translates to:
  /// **'Rellenar PP'**
  String get restorePp;

  /// No description provided for @revert.
  ///
  /// In es, this message translates to:
  /// **'Revertir'**
  String get revert;

  /// No description provided for @saveDraftBody.
  ///
  /// In es, this message translates to:
  /// **'Se crea una copia nueva en el Arca con estos cambios. La copia actual y el archivo original quedan intactos.'**
  String get saveDraftBody;

  /// No description provided for @saveDraftTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardar en el Arca'**
  String get saveDraftTitle;

  /// No description provided for @saveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar: {error}'**
  String saveFailed(String error);

  /// No description provided for @saveToArca.
  ///
  /// In es, this message translates to:
  /// **'Guardar en el Arca'**
  String get saveToArca;

  /// No description provided for @savedToArca.
  ///
  /// In es, this message translates to:
  /// **'Guardado como copia nueva en el Arca'**
  String get savedToArca;

  /// No description provided for @seconds.
  ///
  /// In es, this message translates to:
  /// **'Segundos'**
  String get seconds;

  /// No description provided for @sectionIdentity.
  ///
  /// In es, this message translates to:
  /// **'Identidad'**
  String get sectionIdentity;

  /// No description provided for @sectionInventory.
  ///
  /// In es, this message translates to:
  /// **'Inventario'**
  String get sectionInventory;

  /// No description provided for @sectionMoves.
  ///
  /// In es, this message translates to:
  /// **'Movimientos'**
  String get sectionMoves;

  /// No description provided for @sectionPokemon.
  ///
  /// In es, this message translates to:
  /// **'Pokémon'**
  String get sectionPokemon;

  /// No description provided for @sectionStats.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas'**
  String get sectionStats;

  /// No description provided for @sectionTrainer.
  ///
  /// In es, this message translates to:
  /// **'Entrenador original'**
  String get sectionTrainer;

  /// No description provided for @sectionTrainerTab.
  ///
  /// In es, this message translates to:
  /// **'Entrenador'**
  String get sectionTrainerTab;

  /// No description provided for @sectionTraits.
  ///
  /// In es, this message translates to:
  /// **'Nivel y rasgos'**
  String get sectionTraits;

  /// No description provided for @shinySquare.
  ///
  /// In es, this message translates to:
  /// **'Cuadrado'**
  String get shinySquare;

  /// No description provided for @shinyStar.
  ///
  /// In es, this message translates to:
  /// **'Estrella'**
  String get shinyStar;

  /// No description provided for @slotBox.
  ///
  /// In es, this message translates to:
  /// **'{box}, hueco {n}'**
  String slotBox(String box, int n);

  /// No description provided for @slotParty.
  ///
  /// In es, this message translates to:
  /// **'Equipo, hueco {n}'**
  String slotParty(int n);

  /// No description provided for @special.
  ///
  /// In es, this message translates to:
  /// **'Especial'**
  String get special;

  /// No description provided for @species.
  ///
  /// In es, this message translates to:
  /// **'Especie'**
  String get species;

  /// No description provided for @statExp.
  ///
  /// In es, this message translates to:
  /// **'Stat exp'**
  String get statExp;

  /// No description provided for @statsAtLevel.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas a nivel {level}'**
  String statsAtLevel(int level);

  /// No description provided for @teraOriginal.
  ///
  /// In es, this message translates to:
  /// **'Teratipo original'**
  String get teraOriginal;

  /// No description provided for @teraType.
  ///
  /// In es, this message translates to:
  /// **'Teratipo'**
  String get teraType;

  /// No description provided for @trainerApplied.
  ///
  /// In es, this message translates to:
  /// **'Datos del entrenador aplicados al borrador'**
  String get trainerApplied;

  /// No description provided for @trainerGender.
  ///
  /// In es, this message translates to:
  /// **'Personaje'**
  String get trainerGender;

  /// No description provided for @trainerIdLong.
  ///
  /// In es, this message translates to:
  /// **'ID de entrenador (16 bits)'**
  String get trainerIdLong;

  /// No description provided for @trainerIdNote.
  ///
  /// In es, this message translates to:
  /// **'Cambiar el ID no cambia el de tus Pokémon: los que capturaste dejarían de ser \"tuyos\".'**
  String get trainerIdNote;

  /// No description provided for @trainerName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get trainerName;

  /// No description provided for @trainerNotEditable.
  ///
  /// In es, this message translates to:
  /// **'Los datos del entrenador de este save no se pueden editar.'**
  String get trainerNotEditable;

  /// No description provided for @undo.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get undo;

  /// No description provided for @unsavedChanges.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 cambio sin guardar} other{{count} cambios sin guardar}}'**
  String unsavedChanges(int count);

  /// No description provided for @useSpeciesName.
  ///
  /// In es, this message translates to:
  /// **'Usar el nombre de la especie'**
  String get useSpeciesName;

  /// No description provided for @visibleId.
  ///
  /// In es, this message translates to:
  /// **'En el juego: {id}'**
  String visibleId(String id);

  /// No description provided for @pouchMega.
  ///
  /// In es, this message translates to:
  /// **'Megapiedras'**
  String get pouchMega;

  /// No description provided for @pouchRecipes.
  ///
  /// In es, this message translates to:
  /// **'Recetas'**
  String get pouchRecipes;

  /// No description provided for @pouchSatchel.
  ///
  /// In es, this message translates to:
  /// **'Bolsa'**
  String get pouchSatchel;

  /// No description provided for @pouchStorage.
  ///
  /// In es, this message translates to:
  /// **'Almacén'**
  String get pouchStorage;

  /// No description provided for @sectionPokedex.
  ///
  /// In es, this message translates to:
  /// **'Pokédex'**
  String get sectionPokedex;

  /// No description provided for @sectionEvents.
  ///
  /// In es, this message translates to:
  /// **'Eventos'**
  String get sectionEvents;

  /// No description provided for @legalityAreaOrigin.
  ///
  /// In es, this message translates to:
  /// **'Origen y encuentro'**
  String get legalityAreaOrigin;

  /// No description provided for @legalityAreaMoves.
  ///
  /// In es, this message translates to:
  /// **'Movimientos'**
  String get legalityAreaMoves;

  /// No description provided for @legalityAreaStats.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas'**
  String get legalityAreaStats;

  /// No description provided for @legalityAreaMisc.
  ///
  /// In es, this message translates to:
  /// **'Otros datos'**
  String get legalityAreaMisc;

  /// No description provided for @legalityFix.
  ///
  /// In es, this message translates to:
  /// **'Intentar corregir'**
  String get legalityFix;

  /// No description provided for @legalityFixAll.
  ///
  /// In es, this message translates to:
  /// **'Corregir lo seguro ({n})'**
  String legalityFixAll(int n);

  /// No description provided for @legalityManual.
  ///
  /// In es, this message translates to:
  /// **'Sin corrección automática: revísalo a mano.'**
  String get legalityManual;

  /// No description provided for @legalityScope.
  ///
  /// In es, this message translates to:
  /// **'Se comprueban reglas de origen, ball, habilidad, variocolor y aprendizaje, y el encuentro (lugar, nivel y especie) contra las tablas de PKHeX. Incluye las incursiones Dinamax de Espada/Escudo; eventos y teraincursiones aún no se verifican.'**
  String get legalityScope;

  /// No description provided for @legalityFixedSnack.
  ///
  /// In es, this message translates to:
  /// **'Corrección aplicada. Revisa el resultado antes de guardar.'**
  String get legalityFixedSnack;

  /// No description provided for @dexSeen.
  ///
  /// In es, this message translates to:
  /// **'Vistos'**
  String get dexSeen;

  /// No description provided for @dexCaught.
  ///
  /// In es, this message translates to:
  /// **'Capturados'**
  String get dexCaught;

  /// No description provided for @dexShiny.
  ///
  /// In es, this message translates to:
  /// **'Variocolor vistos'**
  String get dexShiny;

  /// No description provided for @dexFilterAll.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get dexFilterAll;

  /// No description provided for @dexFilterMissing.
  ///
  /// In es, this message translates to:
  /// **'Por capturar'**
  String get dexFilterMissing;

  /// No description provided for @dexFilterSeen.
  ///
  /// In es, this message translates to:
  /// **'Solo vistas'**
  String get dexFilterSeen;

  /// No description provided for @dexFilterCaught.
  ///
  /// In es, this message translates to:
  /// **'Capturadas'**
  String get dexFilterCaught;

  /// No description provided for @dexSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar por nombre o número'**
  String get dexSearch;

  /// No description provided for @dexComplete.
  ///
  /// In es, this message translates to:
  /// **'Completar'**
  String get dexComplete;

  /// No description provided for @dexCompleteShiny.
  ///
  /// In es, this message translates to:
  /// **'Completar con variocolor'**
  String get dexCompleteShiny;

  /// No description provided for @dexClear.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get dexClear;

  /// No description provided for @dexConfirmCompleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Completar la Pokédex?'**
  String get dexConfirmCompleteTitle;

  /// No description provided for @dexConfirmCompleteBody.
  ///
  /// In es, this message translates to:
  /// **'Las {n} especies quedarán vistas y capturadas. Algunos juegos dan premios o activan eventos al completarla, así que cambia tu progreso. Puedes deshacerlo antes de guardar.'**
  String dexConfirmCompleteBody(int n);

  /// No description provided for @dexConfirmClearTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Limpiar la Pokédex?'**
  String get dexConfirmClearTitle;

  /// No description provided for @dexConfirmClearBody.
  ///
  /// In es, this message translates to:
  /// **'Se borrarán todos los registros de vistos y capturados. Puedes deshacerlo antes de guardar.'**
  String get dexConfirmClearBody;

  /// No description provided for @dexUnsupported.
  ///
  /// In es, this message translates to:
  /// **'La Pokédex de este juego todavía no se puede editar.'**
  String get dexUnsupported;

  /// No description provided for @dexNoMatch.
  ///
  /// In es, this message translates to:
  /// **'Ninguna especie coincide con el filtro.'**
  String get dexNoMatch;

  /// No description provided for @dexToggleSeen.
  ///
  /// In es, this message translates to:
  /// **'Visto'**
  String get dexToggleSeen;

  /// No description provided for @dexToggleCaught.
  ///
  /// In es, this message translates to:
  /// **'Capturado'**
  String get dexToggleCaught;

  /// No description provided for @dexToggleShiny.
  ///
  /// In es, this message translates to:
  /// **'Variocolor'**
  String get dexToggleShiny;

  /// No description provided for @eventsWarningTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambiar eventos puede romper la partida'**
  String get eventsWarningTitle;

  /// No description provided for @eventsWarningBody.
  ///
  /// In es, this message translates to:
  /// **'Flags y constantes controlan la historia, los objetos recogidos y los combates. Un valor equivocado puede bloquear el avance o hacer desaparecer personajes. Cambia solo lo que entiendas: el original queda a salvo en el Arca.'**
  String get eventsWarningBody;

  /// No description provided for @eventsFlags.
  ///
  /// In es, this message translates to:
  /// **'Flags ({n})'**
  String eventsFlags(int n);

  /// No description provided for @eventsWork.
  ///
  /// In es, this message translates to:
  /// **'Constantes ({n})'**
  String eventsWork(int n);

  /// No description provided for @eventsNamed.
  ///
  /// In es, this message translates to:
  /// **'Con nombre'**
  String get eventsNamed;

  /// No description provided for @eventsRaw.
  ///
  /// In es, this message translates to:
  /// **'Lista completa'**
  String get eventsRaw;

  /// No description provided for @eventsSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar por nombre o número'**
  String get eventsSearch;

  /// No description provided for @eventsUnsupported.
  ///
  /// In es, this message translates to:
  /// **'Este juego todavía no tiene editor de eventos.'**
  String get eventsUnsupported;

  /// No description provided for @eventsNoMatch.
  ///
  /// In es, this message translates to:
  /// **'Nada coincide con la búsqueda.'**
  String get eventsNoMatch;

  /// No description provided for @eventsUnnamed.
  ///
  /// In es, this message translates to:
  /// **'Sin nombre conocido'**
  String get eventsUnnamed;

  /// No description provided for @eventsNoNames.
  ///
  /// In es, this message translates to:
  /// **'Para este juego no hay tabla de nombres fiable: se muestra la lista cruda.'**
  String get eventsNoNames;

  /// No description provided for @eventsShowing.
  ///
  /// In es, this message translates to:
  /// **'Mostrando {shown} de {n}'**
  String eventsShowing(int n, String shown);

  /// No description provided for @bulkTitle.
  ///
  /// In es, this message translates to:
  /// **'Importación en bloque'**
  String get bulkTitle;

  /// No description provided for @bulkDetected.
  ///
  /// In es, this message translates to:
  /// **'Detectados ({n})'**
  String bulkDetected(int n);

  /// No description provided for @bulkDuplicates.
  ///
  /// In es, this message translates to:
  /// **'Ya en el Arca ({n})'**
  String bulkDuplicates(int n);

  /// No description provided for @bulkRepeated.
  ///
  /// In es, this message translates to:
  /// **'Repetidos en la selección ({n})'**
  String bulkRepeated(int n);

  /// No description provided for @bulkUnrecognized.
  ///
  /// In es, this message translates to:
  /// **'No reconocidos ({n})'**
  String bulkUnrecognized(int n);

  /// No description provided for @bulkIgnored.
  ///
  /// In es, this message translates to:
  /// **'{n} archivos ignorados por tamaño o tipo (ROMs, claves, imágenes…).'**
  String bulkIgnored(int n);

  /// No description provided for @bulkImportNew.
  ///
  /// In es, this message translates to:
  /// **'Importar {n} nuevos'**
  String bulkImportNew(int n);

  /// No description provided for @bulkNothingNew.
  ///
  /// In es, this message translates to:
  /// **'No hay nada nuevo que importar.'**
  String get bulkNothingNew;

  /// No description provided for @bulkSubfolders.
  ///
  /// In es, this message translates to:
  /// **'{n} archivos revisados en la carpeta y sus subcarpetas.'**
  String bulkSubfolders(int n);

  /// No description provided for @archiveExport.
  ///
  /// In es, this message translates to:
  /// **'Exportar el Arca (zip)'**
  String get archiveExport;

  /// No description provided for @archiveExportDesc.
  ///
  /// In es, this message translates to:
  /// **'Todas las copias con su estructura por juego y un manifiesto JSON.'**
  String get archiveExportDesc;

  /// No description provided for @archiveRestore.
  ///
  /// In es, this message translates to:
  /// **'Restaurar desde zip'**
  String get archiveRestore;

  /// No description provided for @archiveRestoreDesc.
  ///
  /// In es, this message translates to:
  /// **'Recupera un zip exportado: añade lo que falte y salta los duplicados.'**
  String get archiveRestoreDesc;

  /// No description provided for @archiveExported.
  ///
  /// In es, this message translates to:
  /// **'Arca exportada: {n} copias.'**
  String archiveExported(int n);

  /// No description provided for @archiveEmpty.
  ///
  /// In es, this message translates to:
  /// **'El Arca está vacía: no hay nada que exportar.'**
  String get archiveEmpty;

  /// No description provided for @archiveInvalid.
  ///
  /// In es, this message translates to:
  /// **'Ese zip no es una exportación del Arca (falta manifest.json).'**
  String get archiveInvalid;

  /// No description provided for @compareAction.
  ///
  /// In es, this message translates to:
  /// **'Comparar con…'**
  String get compareAction;

  /// No description provided for @compareTitle.
  ///
  /// In es, this message translates to:
  /// **'Comparar copias'**
  String get compareTitle;

  /// No description provided for @compareBefore.
  ///
  /// In es, this message translates to:
  /// **'Antes'**
  String get compareBefore;

  /// No description provided for @compareAfter.
  ///
  /// In es, this message translates to:
  /// **'Después'**
  String get compareAfter;

  /// No description provided for @comparePick.
  ///
  /// In es, this message translates to:
  /// **'Elige la otra copia'**
  String get comparePick;

  /// No description provided for @compareTrainer.
  ///
  /// In es, this message translates to:
  /// **'Entrenador'**
  String get compareTrainer;

  /// No description provided for @compareParty.
  ///
  /// In es, this message translates to:
  /// **'Equipo'**
  String get compareParty;

  /// No description provided for @compareBoxes.
  ///
  /// In es, this message translates to:
  /// **'Cajas'**
  String get compareBoxes;

  /// No description provided for @compareInventory.
  ///
  /// In es, this message translates to:
  /// **'Inventario'**
  String get compareInventory;

  /// No description provided for @comparePokedex.
  ///
  /// In es, this message translates to:
  /// **'Pokédex'**
  String get comparePokedex;

  /// No description provided for @compareAdded.
  ///
  /// In es, this message translates to:
  /// **'Entró'**
  String get compareAdded;

  /// No description provided for @compareRemoved.
  ///
  /// In es, this message translates to:
  /// **'Salió'**
  String get compareRemoved;

  /// No description provided for @compareChanged.
  ///
  /// In es, this message translates to:
  /// **'Cambió'**
  String get compareChanged;

  /// No description provided for @compareMoved.
  ///
  /// In es, this message translates to:
  /// **'Se movió'**
  String get compareMoved;

  /// No description provided for @compareIdentical.
  ///
  /// In es, this message translates to:
  /// **'Las dos copias tienen el mismo contenido.'**
  String get compareIdentical;

  /// No description provided for @compareSummary.
  ///
  /// In es, this message translates to:
  /// **'{n} diferencias'**
  String compareSummary(int n);

  /// No description provided for @compareDexGained.
  ///
  /// In es, this message translates to:
  /// **'{n} especies nuevas en la Pokédex'**
  String compareDexGained(int n);

  /// No description provided for @compareDexLost.
  ///
  /// In es, this message translates to:
  /// **'{n} especies quitadas de la Pokédex'**
  String compareDexLost(int n);

  /// No description provided for @compareSwap.
  ///
  /// In es, this message translates to:
  /// **'Intercambiar'**
  String get compareSwap;

  /// No description provided for @fieldName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get fieldName;

  /// No description provided for @fieldTid.
  ///
  /// In es, this message translates to:
  /// **'ID'**
  String get fieldTid;

  /// No description provided for @fieldSid.
  ///
  /// In es, this message translates to:
  /// **'ID secreto'**
  String get fieldSid;

  /// No description provided for @fieldMoney.
  ///
  /// In es, this message translates to:
  /// **'Dinero'**
  String get fieldMoney;

  /// No description provided for @fieldPlayTime.
  ///
  /// In es, this message translates to:
  /// **'Tiempo de juego'**
  String get fieldPlayTime;

  /// No description provided for @fieldGender.
  ///
  /// In es, this message translates to:
  /// **'Género'**
  String get fieldGender;

  /// No description provided for @fieldSpecies.
  ///
  /// In es, this message translates to:
  /// **'Especie'**
  String get fieldSpecies;

  /// No description provided for @fieldForm.
  ///
  /// In es, this message translates to:
  /// **'Forma'**
  String get fieldForm;

  /// No description provided for @fieldNickname.
  ///
  /// In es, this message translates to:
  /// **'Mote'**
  String get fieldNickname;

  /// No description provided for @fieldLevel.
  ///
  /// In es, this message translates to:
  /// **'Nivel'**
  String get fieldLevel;

  /// No description provided for @fieldExp.
  ///
  /// In es, this message translates to:
  /// **'Experiencia'**
  String get fieldExp;

  /// No description provided for @fieldMoves.
  ///
  /// In es, this message translates to:
  /// **'Movimientos'**
  String get fieldMoves;

  /// No description provided for @fieldItem.
  ///
  /// In es, this message translates to:
  /// **'Objeto'**
  String get fieldItem;

  /// No description provided for @fieldAbility.
  ///
  /// In es, this message translates to:
  /// **'Habilidad'**
  String get fieldAbility;

  /// No description provided for @fieldNature.
  ///
  /// In es, this message translates to:
  /// **'Naturaleza'**
  String get fieldNature;

  /// No description provided for @fieldIvs.
  ///
  /// In es, this message translates to:
  /// **'IVs'**
  String get fieldIvs;

  /// No description provided for @fieldEvs.
  ///
  /// In es, this message translates to:
  /// **'EVs'**
  String get fieldEvs;

  /// No description provided for @fieldShiny.
  ///
  /// In es, this message translates to:
  /// **'Variocolor'**
  String get fieldShiny;

  /// No description provided for @fieldBall.
  ///
  /// In es, this message translates to:
  /// **'Ball'**
  String get fieldBall;

  /// No description provided for @fieldFriendship.
  ///
  /// In es, this message translates to:
  /// **'Amistad'**
  String get fieldFriendship;

  /// No description provided for @showMore.
  ///
  /// In es, this message translates to:
  /// **'Mostrar más'**
  String get showMore;

  /// No description provided for @editPokedex.
  ///
  /// In es, this message translates to:
  /// **'Pokédex actualizada'**
  String get editPokedex;

  /// No description provided for @editEvents.
  ///
  /// In es, this message translates to:
  /// **'Eventos modificados'**
  String get editEvents;

  /// No description provided for @dexRegionAll.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get dexRegionAll;

  /// No description provided for @dexRegionNational.
  ///
  /// In es, this message translates to:
  /// **'Nacional'**
  String get dexRegionNational;

  /// No description provided for @dexRegion_galar.
  ///
  /// In es, this message translates to:
  /// **'Galar'**
  String get dexRegion_galar;

  /// No description provided for @dexRegion_armor.
  ///
  /// In es, this message translates to:
  /// **'Isla de la Armadura'**
  String get dexRegion_armor;

  /// No description provided for @dexRegion_crown.
  ///
  /// In es, this message translates to:
  /// **'Corona Nieve'**
  String get dexRegion_crown;

  /// No description provided for @dexRegion_hisui.
  ///
  /// In es, this message translates to:
  /// **'Hisui'**
  String get dexRegion_hisui;

  /// No description provided for @dexRegion_paldea.
  ///
  /// In es, this message translates to:
  /// **'Paldea'**
  String get dexRegion_paldea;

  /// No description provided for @dexRegion_kitakami.
  ///
  /// In es, this message translates to:
  /// **'Kitakami'**
  String get dexRegion_kitakami;

  /// No description provided for @dexRegion_blueberry.
  ///
  /// In es, this message translates to:
  /// **'Arándano'**
  String get dexRegion_blueberry;

  /// No description provided for @dexRegion_lumiose.
  ///
  /// In es, this message translates to:
  /// **'Luminalia'**
  String get dexRegion_lumiose;

  /// No description provided for @dexRegion_hyperspace.
  ///
  /// In es, this message translates to:
  /// **'Hiperespacio'**
  String get dexRegion_hyperspace;

  /// No description provided for @dexDetailHint.
  ///
  /// In es, this message translates to:
  /// **'Mantén pulsada una especie (o clic derecho) para editar géneros y formas.'**
  String get dexDetailHint;

  /// No description provided for @dexDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Registro de la Pokédex'**
  String get dexDetailTitle;

  /// No description provided for @dexDetailSeen.
  ///
  /// In es, this message translates to:
  /// **'Visto'**
  String get dexDetailSeen;

  /// No description provided for @dexDetailCaught.
  ///
  /// In es, this message translates to:
  /// **'Capturado'**
  String get dexDetailCaught;

  /// No description provided for @dexDetailShiny.
  ///
  /// In es, this message translates to:
  /// **'Visto variocolor'**
  String get dexDetailShiny;

  /// No description provided for @dexDetailGenders.
  ///
  /// In es, this message translates to:
  /// **'Géneros vistos'**
  String get dexDetailGenders;

  /// No description provided for @dexDetailMale.
  ///
  /// In es, this message translates to:
  /// **'Macho'**
  String get dexDetailMale;

  /// No description provided for @dexDetailFemale.
  ///
  /// In es, this message translates to:
  /// **'Hembra'**
  String get dexDetailFemale;

  /// No description provided for @dexDetailGenderless.
  ///
  /// In es, this message translates to:
  /// **'Sin género'**
  String get dexDetailGenderless;

  /// No description provided for @dexDetailForms.
  ///
  /// In es, this message translates to:
  /// **'Formas vistas'**
  String get dexDetailForms;

  /// No description provided for @dexDetailForm.
  ///
  /// In es, this message translates to:
  /// **'Forma {form}'**
  String dexDetailForm(String form);

  /// No description provided for @dexDetailFormBase.
  ///
  /// In es, this message translates to:
  /// **'Base'**
  String get dexDetailFormBase;

  /// No description provided for @dexDetailFormUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No está en este juego'**
  String get dexDetailFormUnavailable;

  /// No description provided for @dexResearch.
  ///
  /// In es, this message translates to:
  /// **'Investigación'**
  String get dexResearch;

  /// No description provided for @dexResearchNote.
  ///
  /// In es, this message translates to:
  /// **'El nivel de investigación se calcula a partir de las tareas del juego; aquí solo se muestra. Completar la Pokédex no lo modifica.'**
  String get dexResearchNote;

  /// No description provided for @dexDetailApply.
  ///
  /// In es, this message translates to:
  /// **'Aplicar'**
  String get dexDetailApply;

  /// No description provided for @dexRegionalNumber.
  ///
  /// In es, this message translates to:
  /// **'{region} n.º {number}'**
  String dexRegionalNumber(String number, String region);

  /// No description provided for @exportVerified.
  ///
  /// In es, this message translates to:
  /// **'Exportado y verificado (checksums y contenido releídos): {path}'**
  String exportVerified(String path);

  /// No description provided for @exportVerifyFailed.
  ///
  /// In es, this message translates to:
  /// **'No se exportó: al releer el archivo generado no coincidía con el borrador ({detail}). Tu save original no se ha tocado.'**
  String exportVerifyFailed(String detail);

  /// No description provided for @legalityAreaEncounter.
  ///
  /// In es, this message translates to:
  /// **'Encuentro según las tablas del juego (lugar, nivel y especie)'**
  String get legalityAreaEncounter;

  /// No description provided for @originAdopted.
  ///
  /// In es, this message translates to:
  /// **'Adoptado de la carpeta'**
  String get originAdopted;

  /// No description provided for @originMigrated.
  ///
  /// In es, this message translates to:
  /// **'Migrado del Arca anterior'**
  String get originMigrated;

  /// No description provided for @onbEyebrow.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido a PKArkTools'**
  String get onbEyebrow;

  /// No description provided for @onbTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu Arca, en tu carpeta'**
  String get onbTitle;

  /// No description provided for @onbBody.
  ///
  /// In es, this message translates to:
  /// **'Elige una carpeta y todas tus copias vivirán ahí. Si la carpeta está en una nube que sincroniza, tus dispositivos compartirán el Arca sin hacer nada más.'**
  String get onbBody;

  /// No description provided for @onbSuggestICloud.
  ///
  /// In es, this message translates to:
  /// **'Sugerencia: crea una carpeta en iCloud Drive y tendrás el mismo Arca en el iPhone, el iPad y el Mac.'**
  String get onbSuggestICloud;

  /// No description provided for @onbSuggestDocuments.
  ///
  /// In es, this message translates to:
  /// **'Sugerencia: una carpeta en Documentos, o dentro de Google Drive, OneDrive, Dropbox o Syncthing para compartirla entre dispositivos.'**
  String get onbSuggestDocuments;

  /// No description provided for @onbChoose.
  ///
  /// In es, this message translates to:
  /// **'Elegir carpeta'**
  String get onbChoose;

  /// No description provided for @onbUseLocal.
  ///
  /// In es, this message translates to:
  /// **'Usar carpeta local de la app'**
  String get onbUseLocal;

  /// No description provided for @onbLater.
  ///
  /// In es, this message translates to:
  /// **'Puedes cambiarla cuando quieras en Ajustes.'**
  String get onbLater;

  /// No description provided for @onbPointNoAccount.
  ///
  /// In es, this message translates to:
  /// **'Sin cuentas ni inicio de sesión'**
  String get onbPointNoAccount;

  /// No description provided for @onbPointReadable.
  ///
  /// In es, this message translates to:
  /// **'Archivos legibles: Juego / Entrenador / fecha'**
  String get onbPointReadable;

  /// No description provided for @onbPointSafe.
  ///
  /// In es, this message translates to:
  /// **'Nada se sobrescribe nunca'**
  String get onbPointSafe;

  /// No description provided for @onbLegacy.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Tu copia actual se copiará a la carpeta elegida y se comprobará.} other{Tus {count} copias actuales se copiarán a la carpeta elegida y se comprobarán una a una.}}'**
  String onbLegacy(int count);

  /// No description provided for @folderPreparing.
  ///
  /// In es, this message translates to:
  /// **'Preparando el Arca…'**
  String get folderPreparing;

  /// No description provided for @folderProgress.
  ///
  /// In es, this message translates to:
  /// **'Copiando y verificando {done} de {total}'**
  String folderProgress(int done, int total);

  /// No description provided for @migrationFailures.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 copia no se pudo migrar.} other{{count} copias no se pudieron migrar.}} El Arca anterior se conserva intacta para no perder nada.'**
  String migrationFailures(int count);

  /// No description provided for @folderPickFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo usar esa carpeta: {error}'**
  String folderPickFailed(String error);

  /// No description provided for @accessLostTitle.
  ///
  /// In es, this message translates to:
  /// **'No podemos abrir tu Arca'**
  String get accessLostTitle;

  /// No description provided for @accessLostBody.
  ///
  /// In es, this message translates to:
  /// **'La app perdió el permiso sobre la carpeta o ya no está disponible (unidad desconectada, carpeta movida o permiso revocado). Tus copias siguen en la carpeta: vuelve a elegirla para continuar.'**
  String get accessLostBody;

  /// No description provided for @accessRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get accessRetry;

  /// No description provided for @accessChooseAgain.
  ///
  /// In es, this message translates to:
  /// **'Volver a elegir la carpeta'**
  String get accessChooseAgain;

  /// No description provided for @folderSection.
  ///
  /// In es, this message translates to:
  /// **'Carpeta del Arca'**
  String get folderSection;

  /// No description provided for @folderSectionDesc.
  ///
  /// In es, this message translates to:
  /// **'Todas las copias viven en esta carpeta. La base de datos de la app es solo un índice de este dispositivo y se reconstruye desde aquí.'**
  String get folderSectionDesc;

  /// No description provided for @folderSynced.
  ///
  /// In es, this message translates to:
  /// **'Sincronizada con {provider}'**
  String folderSynced(String provider);

  /// No description provided for @folderLocalOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo en este dispositivo'**
  String get folderLocalOnly;

  /// No description provided for @folderAppLocal.
  ///
  /// In es, this message translates to:
  /// **'Carpeta local de la app'**
  String get folderAppLocal;

  /// No description provided for @folderReindex.
  ///
  /// In es, this message translates to:
  /// **'Reindexar'**
  String get folderReindex;

  /// No description provided for @folderChange.
  ///
  /// In es, this message translates to:
  /// **'Cambiar carpeta…'**
  String get folderChange;

  /// No description provided for @folderChangeTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Mover o copiar el Arca?'**
  String get folderChangeTitle;

  /// No description provided for @folderChangeBody.
  ///
  /// In es, this message translates to:
  /// **'Las copias se escribirán en la carpeta nueva y se comprobará cada una por su SHA-256. Al mover, la carpeta anterior solo se vacía de las copias ya verificadas.'**
  String get folderChangeBody;

  /// No description provided for @folderMove.
  ///
  /// In es, this message translates to:
  /// **'Mover'**
  String get folderMove;

  /// No description provided for @folderCopy.
  ///
  /// In es, this message translates to:
  /// **'Copiar y conservar la anterior'**
  String get folderCopy;

  /// No description provided for @folderChangeDone.
  ///
  /// In es, this message translates to:
  /// **'Arca en la carpeta nueva: {copied} copiadas, {skipped} ya estaban.'**
  String folderChangeDone(int copied, int skipped);

  /// No description provided for @folderLeftBehind.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 archivo suelto se quedó en la carpeta anterior.} other{{count} archivos sueltos se quedaron en la carpeta anterior.}}'**
  String folderLeftBehind(int count);

  /// No description provided for @reindexNever.
  ///
  /// In es, this message translates to:
  /// **'Aún no se ha revisado la carpeta en esta sesión.'**
  String get reindexNever;

  /// No description provided for @reindexLast.
  ///
  /// In es, this message translates to:
  /// **'Última revisión: {time}'**
  String reindexLast(String time);

  /// No description provided for @reindexResult.
  ///
  /// In es, this message translates to:
  /// **'Reindexado: {added} nuevas, {removed} quitadas, {dups} duplicadas.'**
  String reindexResult(int added, int removed, int dups);

  /// No description provided for @statBackups.
  ///
  /// In es, this message translates to:
  /// **'copias'**
  String get statBackups;

  /// No description provided for @statIssues.
  ///
  /// In es, this message translates to:
  /// **'problemas'**
  String get statIssues;

  /// No description provided for @ignoredFiles.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 archivo omitido (temporal, parcial o copia de conflicto de la nube).} other{{count} archivos omitidos (temporales, parciales o copias de conflicto de la nube).}}'**
  String ignoredFiles(int count);

  /// No description provided for @snapshotDamaged.
  ///
  /// In es, this message translates to:
  /// **'Esta copia está dañada en la carpeta del Arca.'**
  String get snapshotDamaged;

  /// No description provided for @dexSearchShort.
  ///
  /// In es, this message translates to:
  /// **'Nombre o número'**
  String get dexSearchShort;

  /// No description provided for @dexDetailHintTouch.
  ///
  /// In es, this message translates to:
  /// **'Mantén pulsada una especie para editar géneros y formas.'**
  String get dexDetailHintTouch;

  /// No description provided for @dexFilterLabel.
  ///
  /// In es, this message translates to:
  /// **'Filtrar Pokédex'**
  String get dexFilterLabel;

  /// No description provided for @onbSuggestGoogleDrive.
  ///
  /// In es, this message translates to:
  /// **'Sugerencia: elige una carpeta dentro de Google Drive para compartir el Arca con tus otros dispositivos, o en Documentos para tenerla solo en este teléfono.'**
  String get onbSuggestGoogleDrive;

  /// No description provided for @onbSuggestOneDrive.
  ///
  /// In es, this message translates to:
  /// **'Sugerencia: crea una carpeta en OneDrive y tendrás el mismo Arca en todos tus PC.'**
  String get onbSuggestOneDrive;

  /// No description provided for @onbSuggestSyncthing.
  ///
  /// In es, this message translates to:
  /// **'Sugerencia: una carpeta sincronizada con Syncthing te da el mismo Arca en todos tus equipos, sin cuentas.'**
  String get onbSuggestSyncthing;

  /// No description provided for @boxPrevious.
  ///
  /// In es, this message translates to:
  /// **'Caja anterior'**
  String get boxPrevious;

  /// No description provided for @boxNext.
  ///
  /// In es, this message translates to:
  /// **'Caja siguiente'**
  String get boxNext;

  /// No description provided for @pouchSwipeHint.
  ///
  /// In es, this message translates to:
  /// **'Desliza un objeto hacia la izquierda para quitarlo.'**
  String get pouchSwipeHint;

  /// No description provided for @cardNoParty.
  ///
  /// In es, this message translates to:
  /// **'Sin equipo en esta copia'**
  String get cardNoParty;

  /// No description provided for @checksumMinor.
  ///
  /// In es, this message translates to:
  /// **'Verificación: aviso leve'**
  String get checksumMinor;

  /// No description provided for @checksumMajor.
  ///
  /// In es, this message translates to:
  /// **'Datos dañados'**
  String get checksumMajor;

  /// No description provided for @damageMinorTitle.
  ///
  /// In es, this message translates to:
  /// **'Se lee entero, pero una verificación no coincide'**
  String get damageMinorTitle;

  /// No description provided for @damageMajorTitle.
  ///
  /// In es, this message translates to:
  /// **'Parte de este save no se puede leer'**
  String get damageMajorTitle;

  /// No description provided for @damagePartWhole.
  ///
  /// In es, this message translates to:
  /// **'Las sumas de verificación del archivo no coinciden con sus datos.'**
  String get damagePartWhole;

  /// No description provided for @damagePartTrainer.
  ///
  /// In es, this message translates to:
  /// **'El bloque del entrenador no coincide con su verificación.'**
  String get damagePartTrainer;

  /// No description provided for @damagePartParty.
  ///
  /// In es, this message translates to:
  /// **'El bloque del equipo no coincide con su verificación.'**
  String get damagePartParty;

  /// No description provided for @damagePartBoxes.
  ///
  /// In es, this message translates to:
  /// **'El bloque de cajas no coincide con su verificación.'**
  String get damagePartBoxes;

  /// No description provided for @damagePartOther.
  ///
  /// In es, this message translates to:
  /// **'Un bloque de otros datos de la partida (objetos, Pokédex, eventos…) no coincide con su verificación.'**
  String get damagePartOther;

  /// No description provided for @damagePartSignature.
  ///
  /// In es, this message translates to:
  /// **'La firma digital del save no corresponde a sus datos.'**
  String get damagePartSignature;

  /// No description provided for @damagePartFileHash.
  ///
  /// In es, this message translates to:
  /// **'El hash de verificación del archivo completo no coincide.'**
  String get damagePartFileHash;

  /// No description provided for @damagePartUnreadable.
  ///
  /// In es, this message translates to:
  /// **'Hay datos que no se pueden leer (Pokémon o valores imposibles).'**
  String get damagePartUnreadable;

  /// No description provided for @damageMinorMeaning.
  ///
  /// In es, this message translates to:
  /// **'Todos los datos se leen bien y puedes verlos. Se abrió en solo lectura porque el juego comprueba estas verificaciones: con una que no coincide, podría no cargar el save o darlo por dañado.'**
  String get damageMinorMeaning;

  /// No description provided for @damageMajorMeaning.
  ///
  /// In es, this message translates to:
  /// **'Lo que ves puede estar incompleto o ser incorrecto. Se abrió en solo lectura: no es seguro editarlo.'**
  String get damageMajorMeaning;

  /// No description provided for @damageWhy.
  ///
  /// In es, this message translates to:
  /// **'Suele pasar cuando el archivo se copió a medias, cuando es un save de otra versión o formato, o cuando otra herramienta lo editó sin recalcular sus verificaciones.'**
  String get damageWhy;

  /// No description provided for @damageMinorTodo.
  ///
  /// In es, this message translates to:
  /// **'Si el juego carga este save sin problemas, usa «Reparar checksums y exportar» para obtener una copia con las verificaciones recalculadas (la copia del Arca no se toca). Si no, vuelve a copiar el save desde la consola o el emulador.'**
  String get damageMinorTodo;

  /// No description provided for @damageMajorTodo.
  ///
  /// In es, this message translates to:
  /// **'Vuelve a copiar el save original desde la consola o el emulador e impórtalo de nuevo. Puedes exportar esta copia tal cual con «Exportar».'**
  String get damageMajorTodo;

  /// No description provided for @damageRepairExport.
  ///
  /// In es, this message translates to:
  /// **'Reparar checksums y exportar'**
  String get damageRepairExport;

  /// No description provided for @damageTechnical.
  ///
  /// In es, this message translates to:
  /// **'Detalle técnico'**
  String get damageTechnical;

  /// No description provided for @repairedSuffix.
  ///
  /// In es, this message translates to:
  /// **'reparado'**
  String get repairedSuffix;

  /// No description provided for @exportRepaired.
  ///
  /// In es, this message translates to:
  /// **'Copia reparada, verificada y exportada: {path}'**
  String exportRepaired(String path);

  /// No description provided for @versionPickMenu.
  ///
  /// In es, this message translates to:
  /// **'Fijar versión del juego…'**
  String get versionPickMenu;

  /// No description provided for @versionPickTitle.
  ///
  /// In es, this message translates to:
  /// **'Versión del juego'**
  String get versionPickTitle;

  /// No description provided for @versionPickBody.
  ///
  /// In es, this message translates to:
  /// **'El save no indica qué cartucho es. Elige uno para el color y el título; se guarda en el .json de cada copia.'**
  String get versionPickBody;

  /// No description provided for @versionUnspecified.
  ///
  /// In es, this message translates to:
  /// **'Sin especificar (pareja)'**
  String get versionUnspecified;

  /// No description provided for @versionFromSave.
  ///
  /// In es, this message translates to:
  /// **'Este save ya indica la versión: {name}.'**
  String versionFromSave(String name);

  /// No description provided for @spritesSection.
  ///
  /// In es, this message translates to:
  /// **'Iconos'**
  String get spritesSection;

  /// No description provided for @spritesSectionDesc.
  ///
  /// In es, this message translates to:
  /// **'Los sprites de Pokémon, objetos, Balls, tipos y cintas no vienen con la app: se descargan la primera vez que se ven y se guardan en la caché de la app (nunca en la carpeta del Arca). Sin conexión se muestran las iniciales.'**
  String get spritesSectionDesc;

  /// No description provided for @spritesCacheSize.
  ///
  /// In es, this message translates to:
  /// **'En caché: {size} · descarga completa: {total} ({count} iconos)'**
  String spritesCacheSize(int count, String size, String total);

  /// No description provided for @spritesDownloadAll.
  ///
  /// In es, this message translates to:
  /// **'Descargar todos los iconos ({size})'**
  String spritesDownloadAll(String size);

  /// No description provided for @spritesClear.
  ///
  /// In es, this message translates to:
  /// **'Borrar caché de iconos'**
  String get spritesClear;

  /// No description provided for @spritesProgress.
  ///
  /// In es, this message translates to:
  /// **'{done} de {total} iconos'**
  String spritesProgress(int done, int total);

  /// No description provided for @spritesDone.
  ///
  /// In es, this message translates to:
  /// **'Todos los iconos están descargados.'**
  String get spritesDone;

  /// No description provided for @spritesFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron descargar {count} iconos; vuelve a intentarlo con conexión.'**
  String spritesFailed(int count);

  /// No description provided for @spritesCancelled.
  ///
  /// In es, this message translates to:
  /// **'Descarga cancelada.'**
  String get spritesCancelled;

  /// No description provided for @spritesProgressBytes.
  ///
  /// In es, this message translates to:
  /// **'{done} de {total} iconos · {size} de {totalSize}'**
  String spritesProgressBytes(
    int done,
    int total,
    String size,
    String totalSize,
  );

  /// No description provided for @spritesOffline.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión a Internet: no se pudo contactar con GitHub. Lo ya descargado se conserva; vuelve a intentarlo con conexión.'**
  String get spritesOffline;

  /// No description provided for @spritesCleared.
  ///
  /// In es, this message translates to:
  /// **'Caché de iconos borrada.'**
  String get spritesCleared;

  /// No description provided for @spritesCredits.
  ///
  /// In es, this message translates to:
  /// **'Iconos de Pokémon: iconos de caja de Pokémon HOME del repositorio de sprites de Smogon / Pokémon Showdown (github.com/smogon/sprites, commit {pokemonCommit}); Gigamax, Megas nuevas y formas especiales variocolor salen del mismo commit (iconos y renders de HOME, iconos de Pokémon Champions). Objetos, Balls, tipos y cintas: recursos de PKHeX (github.com/kwsch/PKHeX, commit {pkhexCommit}). Se descargan bajo demanda, nunca se incluyen. Los sprites son © Nintendo / Game Freak / The Pokémon Company.'**
  String spritesCredits(String pokemonCommit, String pkhexCommit);

  /// No description provided for @sectionOrigin.
  ///
  /// In es, this message translates to:
  /// **'Origen'**
  String get sectionOrigin;

  /// No description provided for @sectionRibbons.
  ///
  /// In es, this message translates to:
  /// **'Cintas y marcas'**
  String get sectionRibbons;

  /// No description provided for @originGame.
  ///
  /// In es, this message translates to:
  /// **'Juego de origen'**
  String get originGame;

  /// No description provided for @originPlace.
  ///
  /// In es, this message translates to:
  /// **'Lugar de captura'**
  String get originPlace;

  /// No description provided for @originHatchPlace.
  ///
  /// In es, this message translates to:
  /// **'Lugar de eclosión'**
  String get originHatchPlace;

  /// No description provided for @originLevel.
  ///
  /// In es, this message translates to:
  /// **'Nivel de encuentro'**
  String get originLevel;

  /// No description provided for @originDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get originDate;

  /// No description provided for @originEggDate.
  ///
  /// In es, this message translates to:
  /// **'Huevo recibido'**
  String get originEggDate;

  /// No description provided for @originEncounterHere.
  ///
  /// In es, this message translates to:
  /// **'aparece aquí'**
  String get originEncounterHere;

  /// No description provided for @originShowAll.
  ///
  /// In es, this message translates to:
  /// **'Mostrar todos los lugares del juego'**
  String get originShowAll;

  /// No description provided for @originOnlyValid.
  ///
  /// In es, this message translates to:
  /// **'Solo lugares donde aparece'**
  String get originOnlyValid;

  /// No description provided for @originFateful.
  ///
  /// In es, this message translates to:
  /// **'Encuentro fatídico (evento)'**
  String get originFateful;

  /// No description provided for @originEggReceived.
  ///
  /// In es, this message translates to:
  /// **'Huevo recibido en {place} el {date}'**
  String originEggReceived(String date, String place);

  /// No description provided for @originHatched.
  ///
  /// In es, this message translates to:
  /// **'Eclosionó en {place} el {date}'**
  String originHatched(String date, String place);

  /// No description provided for @originMet.
  ///
  /// In es, this message translates to:
  /// **'Capturado en {place}, nivel {nLevel}, {date}'**
  String originMet(String date, int nLevel, String place);

  /// No description provided for @originNoDate.
  ///
  /// In es, this message translates to:
  /// **'sin fecha (Gen 3)'**
  String get originNoDate;

  /// No description provided for @originTrainer.
  ///
  /// In es, this message translates to:
  /// **'Entrenador original: {name} (ID {tid})'**
  String originTrainer(String name, String tid);

  /// No description provided for @originHomeTracker.
  ///
  /// In es, this message translates to:
  /// **'Pasó por Pokémon HOME (rastreador {tracker})'**
  String originHomeTracker(String tracker);

  /// No description provided for @originNotInGame.
  ///
  /// In es, this message translates to:
  /// **'Esta especie no aparece en las tablas de encuentros de su juego de origen (¿evento, intercambio o huevo?).'**
  String get originNotInGame;

  /// No description provided for @originValidPlaces.
  ///
  /// In es, this message translates to:
  /// **'El lugar o el nivel no cuadran con su juego. Lugares válidos: {places}'**
  String originValidPlaces(String places);

  /// No description provided for @transferPalPark.
  ///
  /// In es, this message translates to:
  /// **'Parque Compi'**
  String get transferPalPark;

  /// No description provided for @transferPokeTransfer.
  ///
  /// In es, this message translates to:
  /// **'Pokétransfer'**
  String get transferPokeTransfer;

  /// No description provided for @transferTransporter.
  ///
  /// In es, this message translates to:
  /// **'Poké Transporter / Banco'**
  String get transferTransporter;

  /// No description provided for @transferVirtualConsole.
  ///
  /// In es, this message translates to:
  /// **'Consola Virtual → Poké Transporter'**
  String get transferVirtualConsole;

  /// No description provided for @transferBank.
  ///
  /// In es, this message translates to:
  /// **'Pokémon Banco'**
  String get transferBank;

  /// No description provided for @ribbonsContest.
  ///
  /// In es, this message translates to:
  /// **'Concursos'**
  String get ribbonsContest;

  /// No description provided for @ribbonsBattle.
  ///
  /// In es, this message translates to:
  /// **'Batalla'**
  String get ribbonsBattle;

  /// No description provided for @ribbonsCommemorative.
  ///
  /// In es, this message translates to:
  /// **'Conmemorativas'**
  String get ribbonsCommemorative;

  /// No description provided for @ribbonsEvent.
  ///
  /// In es, this message translates to:
  /// **'Eventos'**
  String get ribbonsEvent;

  /// No description provided for @ribbonsMarks.
  ///
  /// In es, this message translates to:
  /// **'Marcas'**
  String get ribbonsMarks;

  /// No description provided for @ribbonsOwned.
  ///
  /// In es, this message translates to:
  /// **'{count} de {nTotal}'**
  String ribbonsOwned(int count, int nTotal);

  /// No description provided for @ribbonsOnlyOwned.
  ///
  /// In es, this message translates to:
  /// **'Solo las que tiene'**
  String get ribbonsOnlyOwned;

  /// No description provided for @ribbonsGiveAll.
  ///
  /// In es, this message translates to:
  /// **'Dar todas las válidas'**
  String get ribbonsGiveAll;

  /// No description provided for @ribbonsRemoveAll.
  ///
  /// In es, this message translates to:
  /// **'Quitar todas'**
  String get ribbonsRemoveAll;

  /// No description provided for @ribbonsGiven.
  ///
  /// In es, this message translates to:
  /// **'{count} cintas añadidas.'**
  String ribbonsGiven(int count);

  /// No description provided for @ribbonsNone.
  ///
  /// In es, this message translates to:
  /// **'No tiene cintas ni marcas.'**
  String get ribbonsNone;

  /// No description provided for @ribbonHas.
  ///
  /// In es, this message translates to:
  /// **'La tiene'**
  String get ribbonHas;

  /// No description provided for @ribbonAffixed.
  ///
  /// In es, this message translates to:
  /// **'Cinta mostrada'**
  String get ribbonAffixed;

  /// No description provided for @ribbonAffixedHint.
  ///
  /// In es, this message translates to:
  /// **'Se muestra junto a su nombre (título).'**
  String get ribbonAffixedHint;

  /// No description provided for @ribbonAffixedNow.
  ///
  /// In es, this message translates to:
  /// **'Muestra: {name}'**
  String ribbonAffixedNow(String name);

  /// No description provided for @ribbonEventOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo se repartió en eventos.'**
  String get ribbonEventOnly;

  /// No description provided for @ribbonEncounterMark.
  ///
  /// In es, this message translates to:
  /// **'Marca de encuentro: la pone el juego al capturarlo.'**
  String get ribbonEncounterMark;

  /// No description provided for @ribbonObtainable.
  ///
  /// In es, this message translates to:
  /// **'Se puede conseguir en los juegos por los que pudo pasar.'**
  String get ribbonObtainable;

  /// No description provided for @ribbonNotObtainable.
  ///
  /// In es, this message translates to:
  /// **'No se puede conseguir en los juegos por los que pudo pasar.'**
  String get ribbonNotObtainable;

  /// No description provided for @originDateUnknown.
  ///
  /// In es, this message translates to:
  /// **'sin fecha'**
  String get originDateUnknown;

  /// No description provided for @filtersAction.
  ///
  /// In es, this message translates to:
  /// **'Filtros'**
  String get filtersAction;

  /// No description provided for @filtersTitle.
  ///
  /// In es, this message translates to:
  /// **'Filtros'**
  String get filtersTitle;

  /// No description provided for @filtersClear.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get filtersClear;

  /// No description provided for @filtersClearAll.
  ///
  /// In es, this message translates to:
  /// **'Limpiar filtros'**
  String get filtersClearAll;

  /// No description provided for @filtersShow.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Ninguna partida} =1{Ver 1 partida} other{Ver {count} partidas}}'**
  String filtersShow(int count);

  /// No description provided for @filtersResults.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 partida de {nTotal}} other{{count} partidas de {nTotal}}}'**
  String filtersResults(int count, int nTotal);

  /// No description provided for @filtersNoMatchTitle.
  ///
  /// In es, this message translates to:
  /// **'Ninguna partida coincide'**
  String get filtersNoMatchTitle;

  /// No description provided for @filtersNoMatchBody.
  ///
  /// In es, this message translates to:
  /// **'Prueba a quitar algún filtro o cambia la búsqueda.'**
  String get filtersNoMatchBody;

  /// No description provided for @filtersRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar filtro {label}'**
  String filtersRemove(String label);

  /// No description provided for @sortLabel.
  ///
  /// In es, this message translates to:
  /// **'Ordenar'**
  String get sortLabel;

  /// No description provided for @sortRecent.
  ///
  /// In es, this message translates to:
  /// **'Más reciente'**
  String get sortRecent;

  /// No description provided for @sortTrainer.
  ///
  /// In es, this message translates to:
  /// **'Entrenador'**
  String get sortTrainer;

  /// No description provided for @sortGame.
  ///
  /// In es, this message translates to:
  /// **'Juego / generación'**
  String get sortGame;

  /// No description provided for @sortPlayTime.
  ///
  /// In es, this message translates to:
  /// **'Horas de juego'**
  String get sortPlayTime;

  /// No description provided for @sortCopies.
  ///
  /// In es, this message translates to:
  /// **'Número de copias'**
  String get sortCopies;

  /// No description provided for @filterGeneration.
  ///
  /// In es, this message translates to:
  /// **'Generación'**
  String get filterGeneration;

  /// No description provided for @filterGenShort.
  ///
  /// In es, this message translates to:
  /// **'Gen {gen}'**
  String filterGenShort(int gen);

  /// No description provided for @filterPlatform.
  ///
  /// In es, this message translates to:
  /// **'Consola'**
  String get filterPlatform;

  /// No description provided for @filterSource.
  ///
  /// In es, this message translates to:
  /// **'Origen'**
  String get filterSource;

  /// No description provided for @sourceEmulator.
  ///
  /// In es, this message translates to:
  /// **'Emulador'**
  String get sourceEmulator;

  /// No description provided for @sourceMobile.
  ///
  /// In es, this message translates to:
  /// **'Port Android/iOS'**
  String get sourceMobile;

  /// No description provided for @sourceCheckpoint.
  ///
  /// In es, this message translates to:
  /// **'Checkpoint/JKSM'**
  String get sourceCheckpoint;

  /// No description provided for @sourceCartridge.
  ///
  /// In es, this message translates to:
  /// **'Cartucho'**
  String get sourceCartridge;

  /// No description provided for @sourceOther.
  ///
  /// In es, this message translates to:
  /// **'Otro / desconocido'**
  String get sourceOther;

  /// No description provided for @filterGame.
  ///
  /// In es, this message translates to:
  /// **'Juego'**
  String get filterGame;

  /// No description provided for @filterStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get filterStatus;

  /// No description provided for @statusDamaged.
  ///
  /// In es, this message translates to:
  /// **'Con avisos de daño'**
  String get statusDamaged;

  /// No description provided for @statusLegality.
  ///
  /// In es, this message translates to:
  /// **'Con avisos de legalidad'**
  String get statusLegality;

  /// No description provided for @statusEdited.
  ///
  /// In es, this message translates to:
  /// **'Editadas por mí'**
  String get statusEdited;

  /// No description provided for @statusMultiple.
  ///
  /// In es, this message translates to:
  /// **'Con varias copias'**
  String get statusMultiple;

  /// No description provided for @legalityScanning.
  ///
  /// In es, this message translates to:
  /// **'Revisando legalidad… {done} de {nTotal}'**
  String legalityScanning(int done, int nTotal);

  /// No description provided for @filterDate.
  ///
  /// In es, this message translates to:
  /// **'Última copia'**
  String get filterDate;

  /// No description provided for @datePresetWeek.
  ///
  /// In es, this message translates to:
  /// **'Última semana'**
  String get datePresetWeek;

  /// No description provided for @datePresetMonth.
  ///
  /// In es, this message translates to:
  /// **'Último mes'**
  String get datePresetMonth;

  /// No description provided for @datePresetYear.
  ///
  /// In es, this message translates to:
  /// **'Último año'**
  String get datePresetYear;

  /// No description provided for @dateCustom.
  ///
  /// In es, this message translates to:
  /// **'Elegir fechas…'**
  String get dateCustom;

  /// No description provided for @dateRange.
  ///
  /// In es, this message translates to:
  /// **'{from} – {to}'**
  String dateRange(String from, String to);

  /// No description provided for @spritesOnDisk.
  ///
  /// In es, this message translates to:
  /// **'Guardados y válidos: {nValid} de {nTotal} iconos.'**
  String spritesOnDisk(int nTotal, int nValid);

  /// No description provided for @spritesMissing.
  ///
  /// In es, this message translates to:
  /// **'Faltan {count} iconos o están dañados (vacíos o cortados): «Reparar iconos» descarga solo esos.'**
  String spritesMissing(int count);

  /// No description provided for @spritesRepair.
  ///
  /// In es, this message translates to:
  /// **'Reparar iconos ({count})'**
  String spritesRepair(int count);

  /// No description provided for @spritesIncomplete.
  ///
  /// In es, this message translates to:
  /// **'La descarga terminó, pero faltan {count} iconos. Pulsa «Reparar iconos» con conexión.'**
  String spritesIncomplete(int count);

  /// No description provided for @originRestored.
  ///
  /// In es, this message translates to:
  /// **'Restaurada'**
  String get originRestored;

  /// No description provided for @currentVersionTitle.
  ///
  /// In es, this message translates to:
  /// **'Versión actual · {date}'**
  String currentVersionTitle(String date);

  /// No description provided for @mainFileLabel.
  ///
  /// In es, this message translates to:
  /// **'En la carpeta como «{name}», lista para copiar al juego o al emulador.'**
  String mainFileLabel(String name);

  /// No description provided for @openFolder.
  ///
  /// In es, this message translates to:
  /// **'Abrir carpeta'**
  String get openFolder;

  /// No description provided for @openFolderTitle.
  ///
  /// In es, this message translates to:
  /// **'Carpeta de la partida'**
  String get openFolderTitle;

  /// No description provided for @openFolderBody.
  ///
  /// In es, this message translates to:
  /// **'Dentro de la carpeta del Arca ({root}):\n\n{path}'**
  String openFolderBody(String path, String root);

  /// No description provided for @copyPath.
  ///
  /// In es, this message translates to:
  /// **'Copiar ruta'**
  String get copyPath;

  /// No description provided for @pathCopied.
  ///
  /// In es, this message translates to:
  /// **'Ruta copiada'**
  String get pathCopied;

  /// No description provided for @historyCount.
  ///
  /// In es, this message translates to:
  /// **'Historial ({count})'**
  String historyCount(int count);

  /// No description provided for @historyFoldedHint.
  ///
  /// In es, this message translates to:
  /// **'Todas las copias, de la más reciente a la más antigua. Nunca se modifican.'**
  String get historyFoldedHint;

  /// No description provided for @mainModifiedTitle.
  ///
  /// In es, this message translates to:
  /// **'El archivo principal cambió fuera de la app'**
  String get mainModifiedTitle;

  /// No description provided for @mainModifiedBody.
  ///
  /// In es, this message translates to:
  /// **'«{name}» no coincide con ninguna copia del historial (¿copiaste encima un save nuevo?). Guárdalo como copia nueva para conservarlo; nunca se borra.'**
  String mainModifiedBody(String name);

  /// No description provided for @saveAsNewCopy.
  ///
  /// In es, this message translates to:
  /// **'Guardar como nueva copia'**
  String get saveAsNewCopy;

  /// No description provided for @savedAsNewCopy.
  ///
  /// In es, this message translates to:
  /// **'Guardado en el historial: {name}'**
  String savedAsNewCopy(String name);

  /// No description provided for @restoreAsCurrentTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Restaurar como versión actual?'**
  String get restoreAsCurrentTitle;

  /// No description provided for @restoreAsCurrentBody.
  ///
  /// In es, this message translates to:
  /// **'Se creará una entrada nueva en el historial con esta copia y el archivo principal («{name}») pasará a ser esta versión. Ninguna copia del historial se modifica.'**
  String restoreAsCurrentBody(String name);

  /// No description provided for @restoreAlsoSource.
  ///
  /// In es, this message translates to:
  /// **'Restaurar y escribir en el original'**
  String get restoreAlsoSource;

  /// No description provided for @restoredAsCurrent.
  ///
  /// In es, this message translates to:
  /// **'Copia restaurada como versión actual'**
  String get restoredAsCurrent;

  /// No description provided for @restoredNote.
  ///
  /// In es, this message translates to:
  /// **'Restaurada desde la copia del {date}'**
  String restoredNote(String date);

  /// No description provided for @arcaLayoutTitle.
  ///
  /// In es, this message translates to:
  /// **'Cómo se organiza la carpeta'**
  String get arcaLayoutTitle;

  /// No description provided for @arcaLayoutDesc.
  ///
  /// In es, this message translates to:
  /// **'Cada partida tiene su carpeta con la última versión, con el nombre que usa el juego (main, SaveData.bin, Esmeralda.sav…), lista para copiar al juego o al emulador. Debajo, historial/ guarda todas las copias sin modificarlas nunca. La última versión es una copia derivada: se regenera siempre desde el historial, así que nada se pierde aunque la borres o la cambies.'**
  String get arcaLayoutDesc;

  /// No description provided for @historyMigrated.
  ///
  /// In es, this message translates to:
  /// **'Carpeta actualizada: {count} copias movidas a historial/'**
  String historyMigrated(int count);

  /// No description provided for @originInbox.
  ///
  /// In es, this message translates to:
  /// **'Bandeja de entrada'**
  String get originInbox;

  /// No description provided for @gameFoldersQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿Quieres crear las carpetas de tus juegos?'**
  String get gameFoldersQuestion;

  /// No description provided for @gameFoldersQuestionBody.
  ///
  /// In es, this message translates to:
  /// **'Así sabrás dónde dejar cada save: PKArkTools lo recoge solo y lo guarda con su historial.'**
  String get gameFoldersQuestionBody;

  /// No description provided for @gameFoldersAll.
  ///
  /// In es, this message translates to:
  /// **'Sí, todos los juegos'**
  String get gameFoldersAll;

  /// No description provided for @gameFoldersChoose.
  ///
  /// In es, this message translates to:
  /// **'Elegir juegos…'**
  String get gameFoldersChoose;

  /// No description provided for @gameFoldersNotNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get gameFoldersNotNow;

  /// No description provided for @gameFoldersCreate.
  ///
  /// In es, this message translates to:
  /// **'Crear carpetas de juegos'**
  String get gameFoldersCreate;

  /// No description provided for @gameFoldersCreateDesc.
  ///
  /// In es, this message translates to:
  /// **'Una carpeta por juego con un LEEME que dice qué save dejar. Lo que dejes ahí se recoge solo.'**
  String get gameFoldersCreateDesc;

  /// No description provided for @gameFoldersPickerTitle.
  ///
  /// In es, this message translates to:
  /// **'Carpetas de juegos'**
  String get gameFoldersPickerTitle;

  /// No description provided for @gameFoldersPickAll.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get gameFoldersPickAll;

  /// No description provided for @gameFoldersPickNone.
  ///
  /// In es, this message translates to:
  /// **'Ninguno'**
  String get gameFoldersPickNone;

  /// No description provided for @gameFoldersPickOwned.
  ///
  /// In es, this message translates to:
  /// **'Los que tengo'**
  String get gameFoldersPickOwned;

  /// No description provided for @gameFoldersGeneration.
  ///
  /// In es, this message translates to:
  /// **'Generación {n}'**
  String gameFoldersGeneration(int n);

  /// No description provided for @gameFoldersExists.
  ///
  /// In es, this message translates to:
  /// **'ya existe'**
  String get gameFoldersExists;

  /// No description provided for @gameFoldersConfirm.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Crear 1 carpeta} other{Crear {count} carpetas}}'**
  String gameFoldersConfirm(int count);

  /// No description provided for @gameFoldersDone.
  ///
  /// In es, this message translates to:
  /// **'Carpetas creadas: {created} (ya existían: {existing})'**
  String gameFoldersDone(String created, String existing);

  /// No description provided for @inboxAdoptedToast.
  ///
  /// In es, this message translates to:
  /// **'Recogido de la bandeja: {files}'**
  String inboxAdoptedToast(String files);

  /// No description provided for @inboxProblemsToast.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 save de la bandeja necesita tu atención} other{{count} saves de la bandeja necesitan tu atención}}'**
  String inboxProblemsToast(int count);

  /// No description provided for @inboxSee.
  ///
  /// In es, this message translates to:
  /// **'Ver'**
  String get inboxSee;

  /// No description provided for @problemsNone.
  ///
  /// In es, this message translates to:
  /// **'Arca sin problemas'**
  String get problemsNone;

  /// No description provided for @problemsSummary.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 problema en el Arca} other{{n} problemas en el Arca}}'**
  String problemsSummary(int n);

  /// No description provided for @problemsErrors.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 error} other{{n} errores}}'**
  String problemsErrors(int n);

  /// No description provided for @problemsWarnings.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 aviso} other{{n} avisos}}'**
  String problemsWarnings(int n);

  /// No description provided for @problemsFixAll.
  ///
  /// In es, this message translates to:
  /// **'Arreglar todo'**
  String get problemsFixAll;

  /// No description provided for @problemsFix.
  ///
  /// In es, this message translates to:
  /// **'Arreglar'**
  String get problemsFix;

  /// No description provided for @problemsIgnore.
  ///
  /// In es, this message translates to:
  /// **'Ignorar'**
  String get problemsIgnore;

  /// No description provided for @problemsFixGroup.
  ///
  /// In es, this message translates to:
  /// **'Arreglar ({n})'**
  String problemsFixGroup(int n);

  /// No description provided for @problemsIgnoreGroup.
  ///
  /// In es, this message translates to:
  /// **'Ignorar ({n})'**
  String problemsIgnoreGroup(int n);

  /// No description provided for @problemsShowIgnored.
  ///
  /// In es, this message translates to:
  /// **'Mostrar ignorados ({n})'**
  String problemsShowIgnored(int n);

  /// No description provided for @problemsHideIgnored.
  ///
  /// In es, this message translates to:
  /// **'Ocultar ignorados'**
  String get problemsHideIgnored;

  /// No description provided for @problemsUnignore.
  ///
  /// In es, this message translates to:
  /// **'Dejar de ignorar'**
  String get problemsUnignore;

  /// No description provided for @problemsIgnoredHint.
  ///
  /// In es, this message translates to:
  /// **'No vuelven a avisar mientras el archivo no cambie. Se guardan solo en este dispositivo.'**
  String get problemsIgnoredHint;

  /// No description provided for @problemsMore.
  ///
  /// In es, this message translates to:
  /// **'y {n} más'**
  String problemsMore(int n);

  /// No description provided for @problemsConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{¿Arreglar 1 problema?} other{¿Arreglar {n} problemas?}}'**
  String problemsConfirmTitle(int n);

  /// No description provided for @problemsConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Los .json se regeneran desde sus saves, los saves sueltos se adoptan y las copias que ya están en el historial se retiran. Nada se borra: lo que no se pueda reparar se mueve a PKArkTools/_cuarentena/ con una nota.'**
  String get problemsConfirmBody;

  /// No description provided for @problemsFixing.
  ///
  /// In es, this message translates to:
  /// **'Arreglando {nDone} de {nTotal}…'**
  String problemsFixing(int nDone, int nTotal);

  /// No description provided for @problemsResultFixed.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 arreglado} other{{n} arreglados}}'**
  String problemsResultFixed(int n);

  /// No description provided for @problemsResultQuarantined.
  ///
  /// In es, this message translates to:
  /// **'{n} en cuarentena'**
  String problemsResultQuarantined(int n);

  /// No description provided for @problemsResultFailed.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 sin arreglar} other{{n} sin arreglar}}'**
  String problemsResultFailed(int n);

  /// No description provided for @problemsSeeSettings.
  ///
  /// In es, this message translates to:
  /// **'Ver en Ajustes'**
  String get problemsSeeSettings;

  /// No description provided for @problemCorruptSidecar.
  ///
  /// In es, this message translates to:
  /// **'.json dañado'**
  String get problemCorruptSidecar;

  /// No description provided for @problemCorruptSidecarDesc.
  ///
  /// In es, this message translates to:
  /// **'No se puede leer. Arreglar lo regenera releyendo su save.'**
  String get problemCorruptSidecarDesc;

  /// No description provided for @problemMissingSidecar.
  ///
  /// In es, this message translates to:
  /// **'Save sin su .json'**
  String get problemMissingSidecar;

  /// No description provided for @problemMissingSidecarDesc.
  ///
  /// In es, this message translates to:
  /// **'Puede estar sincronizándose. Arreglar crea el .json desde el save.'**
  String get problemMissingSidecarDesc;

  /// No description provided for @problemMissingSave.
  ///
  /// In es, this message translates to:
  /// **'.json sin su save'**
  String get problemMissingSave;

  /// No description provided for @problemMissingSaveDesc.
  ///
  /// In es, this message translates to:
  /// **'Puede estar sincronizándose. Arreglar aparta el .json a la cuarentena.'**
  String get problemMissingSaveDesc;

  /// No description provided for @problemContentMismatch.
  ///
  /// In es, this message translates to:
  /// **'El save no coincide con su .json'**
  String get problemContentMismatch;

  /// No description provided for @problemContentMismatchDesc.
  ///
  /// In es, this message translates to:
  /// **'Se cambió por fuera. Arreglar guarda su contenido como copia nueva y aparta la pareja antigua.'**
  String get problemContentMismatchDesc;

  /// No description provided for @problemUnreadable.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer'**
  String get problemUnreadable;

  /// No description provided for @problemUnreadableDesc.
  ///
  /// In es, this message translates to:
  /// **'Permiso o archivo bloqueado. Arreglar lo vuelve a leer y regenera el .json.'**
  String get problemUnreadableDesc;

  /// No description provided for @problemMainFailed.
  ///
  /// In es, this message translates to:
  /// **'Última versión sin actualizar'**
  String get problemMainFailed;

  /// No description provided for @problemMainFailedDesc.
  ///
  /// In es, this message translates to:
  /// **'No se pudo escribir el archivo principal o ultima.json. Arreglar los reconstruye desde el historial.'**
  String get problemMainFailedDesc;

  /// No description provided for @problemInboxUnreadable.
  ///
  /// In es, this message translates to:
  /// **'Bandeja: no es un save legible'**
  String get problemInboxUnreadable;

  /// No description provided for @problemInboxUnreadableDesc.
  ///
  /// In es, this message translates to:
  /// **'Arreglar lo aparta a la cuarentena.'**
  String get problemInboxUnreadableDesc;

  /// No description provided for @problemInboxWrongGame.
  ///
  /// In es, this message translates to:
  /// **'Bandeja: save de otro juego'**
  String get problemInboxWrongGame;

  /// No description provided for @problemInboxWrongGameDesc.
  ///
  /// In es, this message translates to:
  /// **'Arreglar lo guarda en la partida de su juego.'**
  String get problemInboxWrongGameDesc;

  /// No description provided for @problemModifiedMain.
  ///
  /// In es, this message translates to:
  /// **'Última versión cambiada a mano'**
  String get problemModifiedMain;

  /// No description provided for @problemModifiedMainDesc.
  ///
  /// In es, this message translates to:
  /// **'Su contenido no está en el historial. Arreglar lo guarda como copia nueva; el archivo se queda.'**
  String get problemModifiedMainDesc;

  /// No description provided for @problemConflictCopy.
  ///
  /// In es, this message translates to:
  /// **'Copia de conflicto de la nube'**
  String get problemConflictCopy;

  /// No description provided for @problemConflictCopyDesc.
  ///
  /// In es, this message translates to:
  /// **'Si su contenido ya está en el historial, Arreglar la retira; si no, la adopta.'**
  String get problemConflictCopyDesc;

  /// No description provided for @problemLooseSave.
  ///
  /// In es, this message translates to:
  /// **'Save suelto'**
  String get problemLooseSave;

  /// No description provided for @problemLooseSaveDesc.
  ///
  /// In es, this message translates to:
  /// **'Copiado a mano fuera de su sitio. Arreglar detecta su juego y lo guarda en el historial.'**
  String get problemLooseSaveDesc;

  /// No description provided for @problemDuplicateCopy.
  ///
  /// In es, this message translates to:
  /// **'Copias duplicadas en el historial'**
  String get problemDuplicateCopy;

  /// No description provided for @problemDuplicateCopyDesc.
  ///
  /// In es, this message translates to:
  /// **'Mismo contenido (SHA-256) que una copia más antigua de la misma partida. Arreglar conserva la más antigua y aparta las demás, con su .json, a _cuarentena/duplicados/.'**
  String get problemDuplicateCopyDesc;

  /// No description provided for @problemDuplicateOf.
  ///
  /// In es, this message translates to:
  /// **'Igual que {name}, que se conserva'**
  String problemDuplicateOf(String name);

  /// No description provided for @folderNetwork.
  ///
  /// In es, this message translates to:
  /// **'Carpeta de red (NAS) · {name}'**
  String folderNetwork(String name);

  /// No description provided for @folderNetworkHint.
  ///
  /// In es, this message translates to:
  /// **'En una carpeta de red los cambios de otros dispositivos se buscan cada minuto mientras la app está abierta y al volver a ella.'**
  String get folderNetworkHint;

  /// No description provided for @networkLostTitle.
  ///
  /// In es, this message translates to:
  /// **'Carpeta de red no disponible'**
  String get networkLostTitle;

  /// No description provided for @networkLostBody.
  ///
  /// In es, this message translates to:
  /// **'Tu Arca está en una carpeta de red ({name}) que ahora no está montada o no responde. Conéctate al NAS (en el Mac: Finder → Ir → Conectarse al servidor) y pulsa Reintentar. Mientras tanto no se crea, mueve ni borra nada.'**
  String networkLostBody(String name);

  /// No description provided for @accessChooseOther.
  ///
  /// In es, this message translates to:
  /// **'Elegir otra'**
  String get accessChooseOther;

  /// No description provided for @importProgress.
  ///
  /// In es, this message translates to:
  /// **'Importando {done} de {total}…'**
  String importProgress(String done, String total);

  /// No description provided for @updateCheck.
  ///
  /// In es, this message translates to:
  /// **'Buscar actualizaciones'**
  String get updateCheck;

  /// No description provided for @updateChecking.
  ///
  /// In es, this message translates to:
  /// **'Buscando…'**
  String get updateChecking;

  /// No description provided for @updateCurrent.
  ///
  /// In es, this message translates to:
  /// **'Versión {version}'**
  String updateCurrent(String version);

  /// No description provided for @updateUpToDate.
  ///
  /// In es, this message translates to:
  /// **'Tienes la última versión ({version}).'**
  String updateUpToDate(String version);

  /// No description provided for @updateAutoCheck.
  ///
  /// In es, this message translates to:
  /// **'Buscar actualizaciones automáticamente'**
  String get updateAutoCheck;

  /// No description provided for @updateAutoCheckDesc.
  ///
  /// In es, this message translates to:
  /// **'Al abrir la app, como mucho una vez al día. Solo consulta api.github.com; no se envía nada tuyo.'**
  String get updateAutoCheckDesc;

  /// No description provided for @updateBannerTitle.
  ///
  /// In es, this message translates to:
  /// **'PKArkTools {version} disponible'**
  String updateBannerTitle(String version);

  /// No description provided for @updateBannerBody.
  ///
  /// In es, this message translates to:
  /// **'Mira las novedades y actualiza cuando quieras.'**
  String get updateBannerBody;

  /// No description provided for @updateNotes.
  ///
  /// In es, this message translates to:
  /// **'Novedades'**
  String get updateNotes;

  /// No description provided for @updateNow.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get updateNow;

  /// No description provided for @updateDownload.
  ///
  /// In es, this message translates to:
  /// **'Descargar'**
  String get updateDownload;

  /// No description provided for @updateSkip.
  ///
  /// In es, this message translates to:
  /// **'Omitir esta versión'**
  String get updateSkip;

  /// No description provided for @updateLater.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get updateLater;

  /// No description provided for @updateSkipped.
  ///
  /// In es, this message translates to:
  /// **'No volverás a ver el aviso de la {version}.'**
  String updateSkipped(String version);

  /// No description provided for @updateOpenPage.
  ///
  /// In es, this message translates to:
  /// **'Abrir la página del release'**
  String get updateOpenPage;

  /// No description provided for @updateDownloading.
  ///
  /// In es, this message translates to:
  /// **'Descargando {done} de {total}…'**
  String updateDownloading(String done, String total);

  /// No description provided for @updateVerifying.
  ///
  /// In es, this message translates to:
  /// **'Comprobando la firma del APK…'**
  String get updateVerifying;

  /// No description provided for @updateCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get updateCancel;

  /// No description provided for @updateInstalling.
  ///
  /// In es, this message translates to:
  /// **'Confirma la instalación en la ventana de Android. La app se cerrará y se abrirá ya actualizada, con tus copias y ajustes.'**
  String get updateInstalling;

  /// No description provided for @updateAndroidHint.
  ///
  /// In es, this message translates to:
  /// **'Se descarga el APK de GitHub, se comprueba que está firmado con la misma clave que esta app y Android te pide confirmar. Tus copias, ajustes y la carpeta del Arca se conservan.'**
  String get updateAndroidHint;

  /// No description provided for @updateDesktopHint.
  ///
  /// In es, this message translates to:
  /// **'Se descarga el archivo del release; luego lo instalas tú. Tus copias y ajustes se conservan.'**
  String get updateDesktopHint;

  /// No description provided for @updateIosHint.
  ///
  /// In es, this message translates to:
  /// **'En iPhone y iPad no se puede instalar desde la app: se abre la página del release.'**
  String get updateIosHint;

  /// No description provided for @updatePermissionTitle.
  ///
  /// In es, this message translates to:
  /// **'Permitir instalar la actualización'**
  String get updatePermissionTitle;

  /// No description provided for @updatePermissionBody.
  ///
  /// In es, this message translates to:
  /// **'Android solo deja que PKArkTools instale su propia actualización si se lo permites una vez. En la pantalla que se abre, activa «Permitir de esta fuente», vuelve aquí y pulsa otra vez «Actualizar».'**
  String get updatePermissionBody;

  /// No description provided for @updatePermissionOpen.
  ///
  /// In es, this message translates to:
  /// **'Abrir ajustes'**
  String get updatePermissionOpen;

  /// No description provided for @updateSaved.
  ///
  /// In es, this message translates to:
  /// **'Guardado en {path}'**
  String updateSaved(String path);

  /// No description provided for @updateShowFolder.
  ///
  /// In es, this message translates to:
  /// **'Mostrar en la carpeta'**
  String get updateShowFolder;

  /// No description provided for @updateStepsMacos.
  ///
  /// In es, this message translates to:
  /// **'Cierra PKArkTools, descomprime el zip y arrastra PKArkTools.app a Aplicaciones sustituyendo la anterior. Ábrela de nuevo.'**
  String get updateStepsMacos;

  /// No description provided for @updateStepsWindows.
  ///
  /// In es, this message translates to:
  /// **'Cierra PKArkTools y ejecuta el instalador: actualiza la versión instalada.'**
  String get updateStepsWindows;

  /// No description provided for @updateStepsLinux.
  ///
  /// In es, this message translates to:
  /// **'Cierra PKArkTools, descomprime el tar.gz y sustituye la carpeta anterior por la nueva.'**
  String get updateStepsLinux;

  /// No description provided for @updateErrorNetwork.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con GitHub. Revisa la conexión e inténtalo de nuevo.'**
  String get updateErrorNetwork;

  /// No description provided for @updateErrorRate.
  ///
  /// In es, this message translates to:
  /// **'GitHub limita las consultas sin cuenta. Inténtalo dentro de un rato.'**
  String get updateErrorRate;

  /// No description provided for @updateErrorGeneric.
  ///
  /// In es, this message translates to:
  /// **'No se pudo actualizar ({code}).'**
  String updateErrorGeneric(String code);

  /// No description provided for @updateErrorSize.
  ///
  /// In es, this message translates to:
  /// **'La descarga llegó incompleta o con otro tamaño. Inténtalo de nuevo.'**
  String get updateErrorSize;

  /// No description provided for @updateErrorAborted.
  ///
  /// In es, this message translates to:
  /// **'Actualización cancelada.'**
  String get updateErrorAborted;

  /// No description provided for @updateErrorSignature.
  ///
  /// In es, this message translates to:
  /// **'No se ha instalado: el APK descargado no está firmado con el mismo certificado que esta app. Descárgalo solo desde la página oficial del release.'**
  String get updateErrorSignature;

  /// No description provided for @updateErrorUntrusted.
  ///
  /// In es, this message translates to:
  /// **'El enlace de descarga no es del repositorio de PKArkTools en GitHub: no se descarga.'**
  String get updateErrorUntrusted;

  /// No description provided for @updateErrorConflict.
  ///
  /// In es, this message translates to:
  /// **'Android no puede instalar esta versión encima de la tuya: está firmada con otra clave. Exporta tu Arca antes de desinstalar e instalar la nueva.'**
  String get updateErrorConflict;

  /// No description provided for @updateErrorStorage.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la descarga (¿falta espacio?).'**
  String get updateErrorStorage;

  /// No description provided for @updateErrorPermission.
  ///
  /// In es, this message translates to:
  /// **'Falta el permiso para instalar apps de esta fuente.'**
  String get updateErrorPermission;

  /// No description provided for @updateNoAsset.
  ///
  /// In es, this message translates to:
  /// **'Este release no tiene descarga para tu sistema.'**
  String get updateNoAsset;

  /// No description provided for @updateRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get updateRetry;

  /// No description provided for @navDex.
  ///
  /// In es, this message translates to:
  /// **'Dex'**
  String get navDex;

  /// No description provided for @dexSubtitle.
  ///
  /// In es, this message translates to:
  /// **'{caught} de {total} capturados · {saves} partidas'**
  String dexSubtitle(String caught, String saves, String total);

  /// No description provided for @dexSubtitleLiving.
  ///
  /// In es, this message translates to:
  /// **'{caught} de {total} en tus cajas · {saves} partidas'**
  String dexSubtitleLiving(String caught, String saves, String total);

  /// No description provided for @dexEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu Dex está vacía'**
  String get dexEmptyTitle;

  /// No description provided for @dexEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Importa partidas al Arca: la Dex se llena con lo que tengas registrado o capturado en cualquiera de ellas.'**
  String get dexEmptyBody;

  /// No description provided for @dexStatCaught.
  ///
  /// In es, this message translates to:
  /// **'Capturados'**
  String get dexStatCaught;

  /// No description provided for @dexStatSeen.
  ///
  /// In es, this message translates to:
  /// **'Vistos'**
  String get dexStatSeen;

  /// No description provided for @dexStatShiny.
  ///
  /// In es, this message translates to:
  /// **'Variocolor'**
  String get dexStatShiny;

  /// No description provided for @dexStatForms.
  ///
  /// In es, this message translates to:
  /// **'Formas'**
  String get dexStatForms;

  /// No description provided for @dexStatOwned.
  ///
  /// In es, this message translates to:
  /// **'En cajas'**
  String get dexStatOwned;

  /// No description provided for @dexSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar por nombre o número'**
  String get dexSearchHint;

  /// No description provided for @dexFilterSeenOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo vistos'**
  String get dexFilterSeenOnly;

  /// No description provided for @dexFilterShiny.
  ///
  /// In es, this message translates to:
  /// **'Variocolor'**
  String get dexFilterShiny;

  /// No description provided for @dexFilterLockedForms.
  ///
  /// In es, this message translates to:
  /// **'Formas por desbloquear'**
  String get dexFilterLockedForms;

  /// No description provided for @dexFilterType.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get dexFilterType;

  /// No description provided for @dexFilterGeneration.
  ///
  /// In es, this message translates to:
  /// **'Generación'**
  String get dexFilterGeneration;

  /// No description provided for @dexFilterGame.
  ///
  /// In es, this message translates to:
  /// **'Juego'**
  String get dexFilterGame;

  /// No description provided for @dexAnyType.
  ///
  /// In es, this message translates to:
  /// **'Cualquier tipo'**
  String get dexAnyType;

  /// No description provided for @dexAnyGeneration.
  ///
  /// In es, this message translates to:
  /// **'Todas las generaciones'**
  String get dexAnyGeneration;

  /// No description provided for @dexAnyGame.
  ///
  /// In es, this message translates to:
  /// **'Todos los juegos'**
  String get dexAnyGame;

  /// No description provided for @dexSortNumber.
  ///
  /// In es, this message translates to:
  /// **'Por número'**
  String get dexSortNumber;

  /// No description provided for @dexSortName.
  ///
  /// In es, this message translates to:
  /// **'Por nombre'**
  String get dexSortName;

  /// No description provided for @dexResults.
  ///
  /// In es, this message translates to:
  /// **'{count} especies'**
  String dexResults(int count);

  /// No description provided for @dexNoResults.
  ///
  /// In es, this message translates to:
  /// **'Ninguna especie coincide con los filtros.'**
  String get dexNoResults;

  /// No description provided for @dexGenRegion.
  ///
  /// In es, this message translates to:
  /// **'Gen. {gen} · {region}'**
  String dexGenRegion(String gen, String region);

  /// No description provided for @dexProgress.
  ///
  /// In es, this message translates to:
  /// **'Progreso'**
  String get dexProgress;

  /// No description provided for @dexByGeneration.
  ///
  /// In es, this message translates to:
  /// **'Por generación y región'**
  String get dexByGeneration;

  /// No description provided for @dexByGame.
  ///
  /// In es, this message translates to:
  /// **'Por juego'**
  String get dexByGame;

  /// No description provided for @dexGameLine.
  ///
  /// In es, this message translates to:
  /// **'{caught} capturados · {seen} vistos de {available} · {count, plural, =1{1 partida} other{{count} partidas}}'**
  String dexGameLine(String available, String caught, int count, String seen);

  /// No description provided for @dexSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes de la Dex'**
  String get dexSettings;

  /// No description provided for @dexLivingTitle.
  ///
  /// In es, this message translates to:
  /// **'Living dex'**
  String get dexLivingTitle;

  /// No description provided for @dexLivingBody.
  ///
  /// In es, this message translates to:
  /// **'Cuenta como capturada solo una especie que tengas en cajas o equipo en alguna partida, no solo registrada en su Pokédex. Así ves qué te falta de verdad.'**
  String get dexLivingBody;

  /// No description provided for @dexLivingBadge.
  ///
  /// In es, this message translates to:
  /// **'Living dex'**
  String get dexLivingBadge;

  /// No description provided for @dexStatusCaught.
  ///
  /// In es, this message translates to:
  /// **'Capturado'**
  String get dexStatusCaught;

  /// No description provided for @dexStatusSeen.
  ///
  /// In es, this message translates to:
  /// **'Visto'**
  String get dexStatusSeen;

  /// No description provided for @dexStatusUnknown.
  ///
  /// In es, this message translates to:
  /// **'No registrado'**
  String get dexStatusUnknown;

  /// No description provided for @dexStatusOwned.
  ///
  /// In es, this message translates to:
  /// **'En tus cajas'**
  String get dexStatusOwned;

  /// No description provided for @dexBaseStats.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas base'**
  String get dexBaseStats;

  /// No description provided for @dexStatTotal.
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get dexStatTotal;

  /// No description provided for @dexAbilities.
  ///
  /// In es, this message translates to:
  /// **'Habilidades'**
  String get dexAbilities;

  /// No description provided for @dexHiddenAbility.
  ///
  /// In es, this message translates to:
  /// **'oculta'**
  String get dexHiddenAbility;

  /// No description provided for @dexGender.
  ///
  /// In es, this message translates to:
  /// **'Género'**
  String get dexGender;

  /// No description provided for @dexGenderless.
  ///
  /// In es, this message translates to:
  /// **'Sin género'**
  String get dexGenderless;

  /// No description provided for @dexGenderRatio.
  ///
  /// In es, this message translates to:
  /// **'{male} % machos · {female} % hembras'**
  String dexGenderRatio(String female, String male);

  /// No description provided for @dexEvolution.
  ///
  /// In es, this message translates to:
  /// **'Evolución'**
  String get dexEvolution;

  /// No description provided for @dexNoEvolution.
  ///
  /// In es, this message translates to:
  /// **'No evoluciona.'**
  String get dexNoEvolution;

  /// No description provided for @dexForms.
  ///
  /// In es, this message translates to:
  /// **'Formas'**
  String get dexForms;

  /// No description provided for @dexSpecialForms.
  ///
  /// In es, this message translates to:
  /// **'Formas especiales'**
  String get dexSpecialForms;

  /// No description provided for @dexSpecialFormsHint.
  ///
  /// In es, this message translates to:
  /// **'Megaevoluciones, Gigamax y otras formas de combate. Se desbloquean con un ejemplar que las habilite en un juego donde existen; la variocolor, con uno variocolor.'**
  String get dexSpecialFormsHint;

  /// No description provided for @dexGames.
  ///
  /// In es, this message translates to:
  /// **'Juegos donde está'**
  String get dexGames;

  /// No description provided for @dexRecords.
  ///
  /// In es, this message translates to:
  /// **'Tus registros'**
  String get dexRecords;

  /// No description provided for @dexRecordsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Ninguna partida la tiene registrada.'**
  String get dexRecordsEmpty;

  /// No description provided for @dexSpecimens.
  ///
  /// In es, this message translates to:
  /// **'Tus ejemplares'**
  String get dexSpecimens;

  /// No description provided for @dexSpecimensEmpty.
  ///
  /// In es, this message translates to:
  /// **'No tienes ninguno en equipos ni cajas.'**
  String get dexSpecimensEmpty;

  /// No description provided for @dexInParty.
  ///
  /// In es, this message translates to:
  /// **'Equipo, posición {slot}'**
  String dexInParty(String slot);

  /// No description provided for @dexInBox.
  ///
  /// In es, this message translates to:
  /// **'Caja {box}, hueco {slot}'**
  String dexInBox(String box, String slot);

  /// No description provided for @dexOpenInBox.
  ///
  /// In es, this message translates to:
  /// **'Ver en su caja'**
  String get dexOpenInBox;

  /// No description provided for @dexNormal.
  ///
  /// In es, this message translates to:
  /// **'Normal'**
  String get dexNormal;

  /// No description provided for @dexShinyVariant.
  ///
  /// In es, this message translates to:
  /// **'Variocolor'**
  String get dexShinyVariant;

  /// No description provided for @dexUnlockedBy.
  ///
  /// In es, this message translates to:
  /// **'{trainer} · {game}'**
  String dexUnlockedBy(String game, String trainer);

  /// No description provided for @dexLocked.
  ///
  /// In es, this message translates to:
  /// **'Bloqueada'**
  String get dexLocked;

  /// No description provided for @dexHowMega.
  ///
  /// In es, this message translates to:
  /// **'Ten un {species} en {games}.'**
  String dexHowMega(String games, String species);

  /// No description provided for @dexHowMegaForm.
  ///
  /// In es, this message translates to:
  /// **'Ten un {species} ({form}) en {games}.'**
  String dexHowMegaForm(String form, String games, String species);

  /// No description provided for @dexHowGmax.
  ///
  /// In es, this message translates to:
  /// **'Ten un {species} con factor Gigamax en Espada/Escudo.'**
  String dexHowGmax(String species);

  /// No description provided for @dexHowUltra.
  ///
  /// In es, this message translates to:
  /// **'Ten un Necrozma fusionado (Melena Crepuscular o Alas del Alba) en Ultrasol/Ultraluna.'**
  String get dexHowUltra;

  /// No description provided for @dexHowShiny.
  ///
  /// In es, this message translates to:
  /// **'La variocolor necesita un ejemplar variocolor.'**
  String get dexHowShiny;

  /// No description provided for @dexItemInBag.
  ///
  /// In es, this message translates to:
  /// **'{item} en la mochila: {where}'**
  String dexItemInBag(String item, String where);

  /// No description provided for @dexItemMissing.
  ///
  /// In es, this message translates to:
  /// **'{item}: no está en la mochila de esas partidas'**
  String dexItemMissing(String item);

  /// No description provided for @dexGigantamax.
  ///
  /// In es, this message translates to:
  /// **'Gigamax'**
  String get dexGigantamax;

  /// No description provided for @dexFormOwned.
  ///
  /// In es, this message translates to:
  /// **'Tienes esta forma'**
  String get dexFormOwned;

  /// No description provided for @dexFormMissing.
  ///
  /// In es, this message translates to:
  /// **'Sin ejemplar'**
  String get dexFormMissing;

  /// No description provided for @dexEvoLevel.
  ///
  /// In es, this message translates to:
  /// **'Nivel {level}'**
  String dexEvoLevel(String level);

  /// No description provided for @dexEvoLevelUp.
  ///
  /// In es, this message translates to:
  /// **'Subir de nivel'**
  String get dexEvoLevelUp;

  /// No description provided for @dexEvoFriendship.
  ///
  /// In es, this message translates to:
  /// **'Amistad alta'**
  String get dexEvoFriendship;

  /// No description provided for @dexEvoFriendshipDay.
  ///
  /// In es, this message translates to:
  /// **'Amistad alta, de día'**
  String get dexEvoFriendshipDay;

  /// No description provided for @dexEvoFriendshipNight.
  ///
  /// In es, this message translates to:
  /// **'Amistad alta, de noche'**
  String get dexEvoFriendshipNight;

  /// No description provided for @dexEvoTrade.
  ///
  /// In es, this message translates to:
  /// **'Intercambio'**
  String get dexEvoTrade;

  /// No description provided for @dexEvoTradeItem.
  ///
  /// In es, this message translates to:
  /// **'Intercambio con {item}'**
  String dexEvoTradeItem(String item);

  /// No description provided for @dexEvoTradeWith.
  ///
  /// In es, this message translates to:
  /// **'Intercambio por {species}'**
  String dexEvoTradeWith(String species);

  /// No description provided for @dexEvoItemMale.
  ///
  /// In es, this message translates to:
  /// **'{item} (♂)'**
  String dexEvoItemMale(String item);

  /// No description provided for @dexEvoItemFemale.
  ///
  /// In es, this message translates to:
  /// **'{item} (♀)'**
  String dexEvoItemFemale(String item);

  /// No description provided for @dexEvoLevelMale.
  ///
  /// In es, this message translates to:
  /// **'{level} (♂)'**
  String dexEvoLevelMale(String level);

  /// No description provided for @dexEvoLevelFemale.
  ///
  /// In es, this message translates to:
  /// **'{level} (♀)'**
  String dexEvoLevelFemale(String level);

  /// No description provided for @dexEvoDay.
  ///
  /// In es, this message translates to:
  /// **'{level}, de día'**
  String dexEvoDay(String level);

  /// No description provided for @dexEvoNight.
  ///
  /// In es, this message translates to:
  /// **'{level}, de noche'**
  String dexEvoNight(String level);

  /// No description provided for @dexEvoDusk.
  ///
  /// In es, this message translates to:
  /// **'{level}, al atardecer'**
  String dexEvoDusk(String level);

  /// No description provided for @dexEvoHeldDay.
  ///
  /// In es, this message translates to:
  /// **'Subir de nivel con {item}, de día'**
  String dexEvoHeldDay(String item);

  /// No description provided for @dexEvoHeldNight.
  ///
  /// In es, this message translates to:
  /// **'Subir de nivel con {item}, de noche'**
  String dexEvoHeldNight(String item);

  /// No description provided for @dexEvoKnowMove.
  ///
  /// In es, this message translates to:
  /// **'Subir de nivel sabiendo {move}'**
  String dexEvoKnowMove(String move);

  /// No description provided for @dexEvoMoveType.
  ///
  /// In es, this message translates to:
  /// **'Subir de nivel con un movimiento de tipo {type}'**
  String dexEvoMoveType(String type);

  /// No description provided for @dexEvoTeammate.
  ///
  /// In es, this message translates to:
  /// **'Subir de nivel con {species} en el equipo'**
  String dexEvoTeammate(String species);

  /// No description provided for @dexEvoLocation.
  ///
  /// In es, this message translates to:
  /// **'Subir de nivel en un lugar concreto'**
  String get dexEvoLocation;

  /// No description provided for @dexEvoStats.
  ///
  /// In es, this message translates to:
  /// **'{level}, según Ataque y Defensa'**
  String dexEvoStats(String level);

  /// No description provided for @dexEvoRandom.
  ///
  /// In es, this message translates to:
  /// **'{level} (al azar)'**
  String dexEvoRandom(String level);

  /// No description provided for @dexEvoOther.
  ///
  /// In es, this message translates to:
  /// **'Método especial'**
  String get dexEvoOther;

  /// No description provided for @dexPrev.
  ///
  /// In es, this message translates to:
  /// **'Anterior'**
  String get dexPrev;

  /// No description provided for @dexNext.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get dexNext;

  /// No description provided for @dexFormsCount.
  ///
  /// In es, this message translates to:
  /// **'{count} formas'**
  String dexFormsCount(int count);

  /// No description provided for @dexLockedCount.
  ///
  /// In es, this message translates to:
  /// **'{count} por desbloquear'**
  String dexLockedCount(int count);

  /// No description provided for @dexShinyCount.
  ///
  /// In es, this message translates to:
  /// **'{count} variocolor'**
  String dexShinyCount(int count);

  /// No description provided for @dexAllSpecies.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get dexAllSpecies;

  /// No description provided for @dexMissingSpecies.
  ///
  /// In es, this message translates to:
  /// **'Faltantes'**
  String get dexMissingSpecies;

  /// No description provided for @dexCaughtSpecies.
  ///
  /// In es, this message translates to:
  /// **'Capturados'**
  String get dexCaughtSpecies;

  /// No description provided for @sectionShadow.
  ///
  /// In es, this message translates to:
  /// **'Pokémon oscuro'**
  String get sectionShadow;

  /// No description provided for @shadowStateShadow.
  ///
  /// In es, this message translates to:
  /// **'Oscuro: corazón cerrado'**
  String get shadowStateShadow;

  /// No description provided for @shadowStatePurified.
  ///
  /// In es, this message translates to:
  /// **'Purificado'**
  String get shadowStatePurified;

  /// No description provided for @shadowIdLabel.
  ///
  /// In es, this message translates to:
  /// **'Id oscuro {id}'**
  String shadowIdLabel(String id);

  /// No description provided for @shadowGauge.
  ///
  /// In es, this message translates to:
  /// **'Medidor de corazón'**
  String get shadowGauge;

  /// No description provided for @shadowGaugeHint.
  ///
  /// In es, this message translates to:
  /// **'Restante, de 0 a {max}. A 0 se puede purificar en el juego.'**
  String shadowGaugeHint(String max);

  /// No description provided for @shadowGaugeUnknown.
  ///
  /// In es, this message translates to:
  /// **'Restante (el máximo de este id no está en las tablas).'**
  String get shadowGaugeUnknown;

  /// No description provided for @shadowPurify.
  ///
  /// In es, this message translates to:
  /// **'Marcar como purificado…'**
  String get shadowPurify;

  /// No description provided for @shadowPurifyTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Marcar como purificado?'**
  String get shadowPurifyTitle;

  /// No description provided for @shadowPurifyBody.
  ///
  /// In es, this message translates to:
  /// **'En el juego, purificar abre el corazón en la Cámara de Purificación o el Altar: da la Cinta Nacional, la experiencia acumulada y a veces movimientos nuevos. Aquí solo se cambia el estado y se añade la Cinta Nacional; la experiencia y los movimientos no cambian. Un Pokémon oscuro no puede salir de Colosseum/XD sin purificarse.'**
  String get shadowPurifyBody;

  /// No description provided for @shadowPurifyConfirm.
  ///
  /// In es, this message translates to:
  /// **'Purificar'**
  String get shadowPurifyConfirm;

  /// No description provided for @shadowRevert.
  ///
  /// In es, this message translates to:
  /// **'Volver a oscuro…'**
  String get shadowRevert;

  /// No description provided for @shadowRevertTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Volver a hacerlo oscuro?'**
  String get shadowRevertTitle;

  /// No description provided for @shadowRevertBody.
  ///
  /// In es, this message translates to:
  /// **'Un Pokémon purificado no vuelve a ser oscuro en el juego. Solo tiene sentido para deshacer un cambio: se cierra el corazón con el medidor al máximo y se quita la Cinta Nacional.'**
  String get shadowRevertBody;

  /// No description provided for @shadowRevertConfirm.
  ///
  /// In es, this message translates to:
  /// **'Volver a oscuro'**
  String get shadowRevertConfirm;

  /// No description provided for @shadowCannotLeaveNote.
  ///
  /// In es, this message translates to:
  /// **'No se puede llevar a otro juego hasta purificarlo.'**
  String get shadowCannotLeaveNote;

  /// No description provided for @shadowPurifiedNote.
  ///
  /// In es, this message translates to:
  /// **'Fue oscuro; al purificarlo recibió la Cinta Nacional.'**
  String get shadowPurifiedNote;

  /// No description provided for @navRibbonHunter.
  ///
  /// In es, this message translates to:
  /// **'Ribbon Hunter'**
  String get navRibbonHunter;

  /// No description provided for @navRibbonsShort.
  ///
  /// In es, this message translates to:
  /// **'Cintas'**
  String get navRibbonsShort;

  /// No description provided for @rmSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Elige cualquier Pokémon y mira todas las cintas que puede ganar un mismo ejemplar, de la generación más antigua a la más nueva.'**
  String get rmSubtitle;

  /// No description provided for @rmSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Busca una especie o forma (nombre o número)'**
  String get rmSearchHint;

  /// No description provided for @rmRanking.
  ///
  /// In es, this message translates to:
  /// **'Ranking por niveles'**
  String get rmRanking;

  /// No description provided for @rmRankingShort.
  ///
  /// In es, this message translates to:
  /// **'Ranking'**
  String get rmRankingShort;

  /// No description provided for @rmRankingSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Especies y formas agrupadas por el máximo de cintas que pueden ganar jugando hoy. Entra en un nivel para ver todas las de ese nivel.'**
  String get rmRankingSubtitle;

  /// No description provided for @rmSeeRanking.
  ///
  /// In es, this message translates to:
  /// **'Ver el ranking'**
  String get rmSeeRanking;

  /// No description provided for @rmTierCount.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 especie o forma} other{{n} especies y formas}}'**
  String rmTierCount(int n);

  /// No description provided for @rmTierPos.
  ///
  /// In es, this message translates to:
  /// **'Nivel {n}'**
  String rmTierPos(int n);

  /// No description provided for @rmTierOriginAll.
  ///
  /// In es, this message translates to:
  /// **'Origen común: {kind} en {games}'**
  String rmTierOriginAll(String kind, String games);

  /// No description provided for @rmTierOriginMost.
  ///
  /// In es, this message translates to:
  /// **'Origen más común: {kind} en {games} ({n} de {total})'**
  String rmTierOriginMost(String kind, String games, int n, int total);

  /// No description provided for @rmTierFilterHint.
  ///
  /// In es, this message translates to:
  /// **'Filtrar este nivel (nombre o número)'**
  String get rmTierFilterHint;

  /// No description provided for @rmTierOfRanking.
  ///
  /// In es, this message translates to:
  /// **'Nivel {n} de {count} del ranking · {species}'**
  String rmTierOfRanking(int n, int count, String species);

  /// No description provided for @rmTierNotFound.
  ///
  /// In es, this message translates to:
  /// **'Ese nivel no existe.'**
  String get rmTierNotFound;

  /// No description provided for @rmRibbons.
  ///
  /// In es, this message translates to:
  /// **'{n} cintas'**
  String rmRibbons(int n);

  /// No description provided for @rmMaxToday.
  ///
  /// In es, this message translates to:
  /// **'Máximo hoy'**
  String get rmMaxToday;

  /// No description provided for @rmOrigin.
  ///
  /// In es, this message translates to:
  /// **'Origen recomendado'**
  String get rmOrigin;

  /// No description provided for @rmGen.
  ///
  /// In es, this message translates to:
  /// **'Gen {gen}'**
  String rmGen(String gen);

  /// No description provided for @rmTimeline.
  ///
  /// In es, this message translates to:
  /// **'Ruta para convertirlo en Ribbon Master, juego a juego'**
  String get rmTimeline;

  /// No description provided for @rmTransferOnly.
  ///
  /// In es, this message translates to:
  /// **'Aquí no se gana ninguna cinta nueva: es un paso de la transferencia.'**
  String get rmTransferOnly;

  /// No description provided for @rmAlsoHere.
  ///
  /// In es, this message translates to:
  /// **'También aquí: {list}'**
  String rmAlsoHere(String list);

  /// No description provided for @rmUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No disponibles hoy'**
  String get rmUnavailable;

  /// No description provided for @rmUnavailableBody.
  ///
  /// In es, this message translates to:
  /// **'Cintas de eventos y de servicios en línea cerrados. No suman al máximo.'**
  String get rmUnavailableBody;

  /// No description provided for @rmClosedOnline.
  ///
  /// In es, this message translates to:
  /// **'Servicio cerrado'**
  String get rmClosedOnline;

  /// No description provided for @rmEventOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo eventos'**
  String get rmEventOnly;

  /// No description provided for @rmOnline.
  ///
  /// In es, this message translates to:
  /// **'En línea'**
  String get rmOnline;

  /// No description provided for @rmMarks.
  ///
  /// In es, this message translates to:
  /// **'Marcas'**
  String get rmMarks;

  /// No description provided for @rmMarksPost.
  ///
  /// In es, this message translates to:
  /// **'Ya capturado, puede ganar en Escarlata/Púrpura: {list}.'**
  String rmMarksPost(String list);

  /// No description provided for @rmMarksCapture.
  ///
  /// In es, this message translates to:
  /// **'Si lo capturas en {games} puede llevar además una marca de encuentro ({n} posibles, como mucho una por ejemplar).'**
  String rmMarksCapture(String games, int n);

  /// No description provided for @rmMarksNote.
  ///
  /// In es, this message translates to:
  /// **'Las marcas no suman al total: solo se ponen al capturarlo.'**
  String get rmMarksNote;

  /// No description provided for @rmMemory.
  ///
  /// In es, this message translates to:
  /// **'Al pasar a Gen 6 sus cintas de concurso ({contest}) y de combate ({battle}) de Gen 3 y 4 se convierten en los Recuerdos de Concurso y de Combate: en el juego final verás {n} cintas.'**
  String rmMemory(String battle, String contest, int n);

  /// No description provided for @rmYourSpecimens.
  ///
  /// In es, this message translates to:
  /// **'Tus ejemplares de esta especie'**
  String get rmYourSpecimens;

  /// No description provided for @rmSpecimenLine.
  ///
  /// In es, this message translates to:
  /// **'{have, plural, =1{1 cinta} other{{have} cintas}} · {missing, plural, =1{le falta 1 que aún puede ganar} other{le faltan {missing} que aún puede ganar}}'**
  String rmSpecimenLine(int have, int missing);

  /// No description provided for @rmSpecimenComplete.
  ///
  /// In es, this message translates to:
  /// **'{have, plural, =1{1 cinta} other{{have} cintas}} · nada pendiente desde su juego'**
  String rmSpecimenComplete(int have);

  /// No description provided for @rmSpecimensEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay ejemplares de esta forma en tu Arca.'**
  String get rmSpecimensEmpty;

  /// No description provided for @rmMissingTitle.
  ///
  /// In es, this message translates to:
  /// **'Le faltan ({n})'**
  String rmMissingTitle(int n);

  /// No description provided for @rmShare.
  ///
  /// In es, this message translates to:
  /// **'Compartir guía'**
  String get rmShare;

  /// No description provided for @rmCopyText.
  ///
  /// In es, this message translates to:
  /// **'Copiar texto para foros'**
  String get rmCopyText;

  /// No description provided for @rmCopied.
  ///
  /// In es, this message translates to:
  /// **'Guía copiada al portapapeles'**
  String get rmCopied;

  /// No description provided for @rmSaveImage.
  ///
  /// In es, this message translates to:
  /// **'Guardar como imagen'**
  String get rmSaveImage;

  /// No description provided for @rmImageSaved.
  ///
  /// In es, this message translates to:
  /// **'Imagen guardada: {path}'**
  String rmImageSaved(String path);

  /// No description provided for @rmOpenGuide.
  ///
  /// In es, this message translates to:
  /// **'Guía Ribbon Hunter'**
  String get rmOpenGuide;

  /// No description provided for @rmKindEgg.
  ///
  /// In es, this message translates to:
  /// **'huevo'**
  String get rmKindEgg;

  /// No description provided for @rmKindWild.
  ///
  /// In es, this message translates to:
  /// **'salvaje'**
  String get rmKindWild;

  /// No description provided for @rmKindStatic.
  ///
  /// In es, this message translates to:
  /// **'encuentro fijo'**
  String get rmKindStatic;

  /// No description provided for @rmKindGift.
  ///
  /// In es, this message translates to:
  /// **'regalo'**
  String get rmKindGift;

  /// No description provided for @rmKindTrade.
  ///
  /// In es, this message translates to:
  /// **'intercambio'**
  String get rmKindTrade;

  /// No description provided for @rmKindShadow.
  ///
  /// In es, this message translates to:
  /// **'Pokémon oscuro'**
  String get rmKindShadow;

  /// No description provided for @rmKindRaid.
  ///
  /// In es, this message translates to:
  /// **'incursión'**
  String get rmKindRaid;

  /// No description provided for @rmKindGo.
  ///
  /// In es, this message translates to:
  /// **'Pokémon GO'**
  String get rmKindGo;

  /// No description provided for @rmKindEvent.
  ///
  /// In es, this message translates to:
  /// **'evento'**
  String get rmKindEvent;

  /// No description provided for @rmNoGuide.
  ///
  /// In es, this message translates to:
  /// **'No hay guía para esta forma.'**
  String get rmNoGuide;

  /// No description provided for @rmResults.
  ///
  /// In es, this message translates to:
  /// **'{n} resultados'**
  String rmResults(int n);

  /// No description provided for @rmHowTitle.
  ///
  /// In es, this message translates to:
  /// **'Cómo se calcula'**
  String get rmHowTitle;

  /// No description provided for @rmHowBody.
  ///
  /// In es, this message translates to:
  /// **'Se elige el origen que permite más cintas (el más antiguo posible), se recorre el grafo de transferencias solo hacia adelante y se suman las cintas que se pueden ganar hoy jugando, sin conexión o en línea. Cada cinta cuenta una vez, en el primer juego donde se puede ganar. Las reglas y la disponibilidad de cada especie y forma están comprobadas contra PKHeX.'**
  String get rmHowBody;

  /// No description provided for @rmOriginEvent.
  ///
  /// In es, this message translates to:
  /// **'Esta especie solo tiene origen en eventos o repartos.'**
  String get rmOriginEvent;

  /// No description provided for @rmStepCount.
  ///
  /// In es, this message translates to:
  /// **'+{n}'**
  String rmStepCount(int n);

  /// No description provided for @rmFormsLabel.
  ///
  /// In es, this message translates to:
  /// **'Puede estar como: {list}'**
  String rmFormsLabel(String list);

  /// No description provided for @rmMemoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Recuerdos de Gen 3 y 4'**
  String get rmMemoryTitle;

  /// No description provided for @rmContestG3.
  ///
  /// In es, this message translates to:
  /// **'Concursos de Hoenn ({n})'**
  String rmContestG3(int n);

  /// No description provided for @rmContestG4.
  ///
  /// In es, this message translates to:
  /// **'Superconcursos de Sinnoh ({n})'**
  String rmContestG4(int n);

  /// No description provided for @rmContestOrderG3.
  ///
  /// In es, this message translates to:
  /// **'Cada categoría se gana en orden: Normal → Alto → Avanzado → Experto. Cualquier especie puede participar.'**
  String get rmContestOrderG3;

  /// No description provided for @rmContestOrderG4.
  ///
  /// In es, this message translates to:
  /// **'Cada categoría se gana en orden: Normal → Difícil → Superior → Experto (Ciudad Corazón). Todas las especies menos Ditto y Unown.'**
  String get rmContestOrderG4;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
