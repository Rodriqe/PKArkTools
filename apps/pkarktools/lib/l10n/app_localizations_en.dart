// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PKArkTools';

  @override
  String get navArca => 'Ark';

  @override
  String get navActivity => 'Activity';

  @override
  String get navSettings => 'Settings';

  @override
  String get arcaTitle => 'Your Ark';

  @override
  String arcaSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saves kept safe',
      one: '1 save kept safe',
      zero: 'No saves yet',
    );
    return '$_temp0';
  }

  @override
  String get importAction => 'Import';

  @override
  String get importFile => 'Import file';

  @override
  String get importFolder => 'Import folder';

  @override
  String get importSheetTitle => 'Add to the Ark';

  @override
  String get importFileDesc =>
      'Cartridge or exported saves: .sav, .srm, .dsv, main…';

  @override
  String get importFolderDesc =>
      'Checkpoint, JKSM or Switch emulator folders. Saves inside are found for you.';

  @override
  String get emptyTitle => 'Your Ark is empty';

  @override
  String get emptyBody =>
      'Import a save to keep a safe copy with its history. Nothing leaves this device.';

  @override
  String get loadDemo => 'Try sample saves';

  @override
  String demoLoaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count sample saves',
      one: 'Added 1 sample save',
    );
    return '$_temp0';
  }

  @override
  String hoursShort(int hours) {
    return '$hours h';
  }

  @override
  String get playTime => 'Play time';

  @override
  String get trainerId => 'ID';

  @override
  String get secretId => 'Secret ID';

  @override
  String get inBoxes => 'In boxes';

  @override
  String get copies => 'Copies';

  @override
  String lastCopy(String date) {
    return 'Last copy: $date';
  }

  @override
  String get team => 'Team';

  @override
  String get boxes => 'Boxes';

  @override
  String get history => 'History';

  @override
  String get emptyTeam => 'No Pokémon in the team';

  @override
  String get notSupportedStorage =>
      'This game doesn\'t show team or boxes yet; it\'s coming in a later phase. Trainer info and history already work.';

  @override
  String get shiny => 'Shiny';

  @override
  String get egg => 'Egg';

  @override
  String level(int level) {
    return 'Lv. $level';
  }

  @override
  String get export => 'Export';

  @override
  String get restore => 'Restore';

  @override
  String get viewing => 'Showing';

  @override
  String get view => 'View';

  @override
  String get latest => 'Latest';

  @override
  String exportDone(String path) {
    return 'Exported to $path';
  }

  @override
  String exportFailed(String error) {
    return 'Couldn\'t export: $error';
  }

  @override
  String get restoreTitle => 'Restore this copy?';

  @override
  String restoreBody(String path) {
    return 'The original file will be replaced:\n$path\n\nFirst, the Ark keeps a copy of the current file so you can go back.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get restoreDone => 'Copy restored to its original location';

  @override
  String restoreFailed(String error) {
    return 'Couldn\'t restore: $error';
  }

  @override
  String get restoreUnavailable =>
      'This copy has no reachable original file. Use Export to save it wherever you like.';

  @override
  String get importResultTitle => 'Import finished';

  @override
  String importAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new copies',
      one: '1 new copy',
    );
    return '$_temp0';
  }

  @override
  String importDuplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count were already in the Ark',
      one: '1 was already in the Ark',
    );
    return '$_temp0';
  }

  @override
  String importFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files not recognized',
      one: '1 file not recognized',
    );
    return '$_temp0';
  }

  @override
  String get done => 'Done';

  @override
  String get openSave => 'Open save';

  @override
  String folderScanning(int count) {
    return 'Looking for saves… $count files checked';
  }

  @override
  String folderFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saves found',
      one: '1 save found',
      zero: 'No saves found',
    );
    return '$_temp0';
  }

  @override
  String get folderNoneHint =>
      'Check the folder holds save files (not ROMs). For Switch emulators pick the nand/user/save folder.';

  @override
  String importSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count saves',
      one: 'Import 1 save',
    );
    return '$_temp0';
  }

  @override
  String get deleteSave => 'Remove from the Ark';

  @override
  String get deleteTitle => 'Remove this save from the Ark?';

  @override
  String deleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Its $count stored copies will be deleted.',
      one: 'Its stored copy will be deleted.',
    );
    return '$_temp0 Original files are untouched.';
  }

  @override
  String get delete => 'Remove';

  @override
  String get checksumValid => 'Checksum OK';

  @override
  String get activityEmpty =>
      'Every copy that enters the Ark shows up here, in order.';

  @override
  String get theme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get about => 'About';

  @override
  String get aboutBody =>
      'PKArkTools keeps versioned copies of your Pokémon saves from every generation. It\'s free software (GPL-3.0) and ports logic from PKHeX.Core. It ships no ROMs, keys or game content.';

  @override
  String get licenses => 'Open source licenses';

  @override
  String get sampleData => 'Sample data';

  @override
  String get sampleDataDesc => 'Add synthetic saves to explore the app.';

  @override
  String get originFile => 'File';

  @override
  String get originFolder => 'Folder';

  @override
  String get originSaf => 'Emulator folder';

  @override
  String get originDemo => 'Sample';

  @override
  String get originRestore => 'Backup before restore';

  @override
  String genLabel(int gen) {
    return 'Gen $gen';
  }

  @override
  String get boxEmpty => 'Empty box';

  @override
  String loadError(String error) {
    return 'Couldn\'t read this copy: $error';
  }

  @override
  String get moreActions => 'More actions';

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
    return 'Copy from $date';
  }

  @override
  String get searchHint => 'Search trainer or game';

  @override
  String noResults(String query) {
    return 'Nothing matches “$query”';
  }

  @override
  String get ability => 'Ability';

  @override
  String get addItem => 'Add item';

  @override
  String get addToSlot => 'Add to slot';

  @override
  String get addToTeam => 'Add to team';

  @override
  String andMore(int count) {
    return '…and $count more changes';
  }

  @override
  String get applyChanges => 'Apply changes';

  @override
  String get avs => 'Awakening values (AV)';

  @override
  String get ball => 'Poké Ball';

  @override
  String get baseTotal => 'Base total';

  @override
  String get boxFull => 'That box is full';

  @override
  String get boxesFull => 'All boxes are full';

  @override
  String get changeNote => 'Description of changes';

  @override
  String get changesStayInDraft =>
      'Changes go to the draft; the original file is never touched.';

  @override
  String get clonePokemon => 'Clone into the first free box slot';

  @override
  String clonedTo(String slot) {
    return 'Clone placed in $slot';
  }

  @override
  String get createPokemon => 'Create Pokémon';

  @override
  String get createPokemonDesc =>
      'With your trainer name, ID and level-appropriate moves';

  @override
  String get deletePokemon => 'Delete from save';

  @override
  String get discard => 'Discard';

  @override
  String get discardDraftBody =>
      'Every edit you have not saved to the Ark will be lost.';

  @override
  String get discardDraftTitle => 'Discard changes?';

  @override
  String get discardPokemonBody =>
      'Changes to this Pokémon will not be applied to the draft.';

  @override
  String get discardPokemonTitle => 'Leave without applying?';

  @override
  String get dragHint =>
      'Drag a Pokémon to move or swap it; drop it on a box name to send it there.';

  @override
  String get dragHintGb =>
      'On Game Boy, boxes are lists: moving or deleting re-packs them without gaps.';

  @override
  String get dragHintTouch =>
      'Long-press a Pokémon to drag it; drop it on another slot or a box name.';

  @override
  String get dvs => 'DVs (determinant values)';

  @override
  String editBoxName(int box, String name) {
    return 'Box $box renamed to “$name”';
  }

  @override
  String editClear(String species, String slot) {
    return '$species removed from $slot';
  }

  @override
  String get editInventory => 'Inventory updated';

  @override
  String editMove(String from, String to) {
    return 'Moved from $from to $to';
  }

  @override
  String get editPokemon => 'Edit Pokémon';

  @override
  String editSet(String species, String slot) {
    return '$species in $slot';
  }

  @override
  String get editTrainer => 'Trainer data updated';

  @override
  String get editedSuffix => 'edited';

  @override
  String evTotal(int total, int max) {
    return '$total / $max';
  }

  @override
  String get evs => 'EVs (effort values)';

  @override
  String get experience => 'Experience';

  @override
  String get exportFile => 'Export file';

  @override
  String exportPokemon(String ext) {
    return 'Export as .$ext';
  }

  @override
  String exportReady(String path) {
    return 'Game-ready file saved to $path';
  }

  @override
  String get female => 'Girl';

  @override
  String get form => 'Form';

  @override
  String get formBase => 'Default';

  @override
  String formN(int n) {
    return 'Form $n';
  }

  @override
  String get friendship => 'Friendship';

  @override
  String get gender => 'Gender';

  @override
  String get gvs => 'Effort levels (GV)';

  @override
  String get heldItem => 'Held item';

  @override
  String get hiddenAbility => 'hidden';

  @override
  String get hours => 'Hours';

  @override
  String get hpDerived => 'HP DV is derived from the others';

  @override
  String get importInvalidPokemon =>
      'The file does not contain a valid Pokémon (bad checksum).';

  @override
  String importPokemon(String ext) {
    return 'Import .$ext';
  }

  @override
  String get importPokemonDesc => 'A Pokémon exported in this same format';

  @override
  String importWrongFormat(String got, String want) {
    return 'A .$got file is not compatible with this game; it needs .$want.';
  }

  @override
  String importedPokemon(String species) {
    return '$species imported into the draft';
  }

  @override
  String get inventoryApplied => 'Inventory applied to the draft';

  @override
  String get inventoryUnsupported =>
      'This game\'s inventory cannot be edited yet.';

  @override
  String get itemWrongPouch =>
      'This item does not usually belong in this pouch';

  @override
  String get ivs => 'IVs (individual values)';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String leaveDraftBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'There are $count changes not saved to the Ark.',
      one: 'There is 1 change not saved to the Ark.',
    );
    return '$_temp0 Leaving discards them.';
  }

  @override
  String get leaveDraftTitle => 'Leave without saving?';

  @override
  String get legalityClean => 'No basic legality warnings.';

  @override
  String get legalityHint => 'These are only warnings: you can still save.';

  @override
  String legalityTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count warnings',
      one: '1 warning',
    );
    return '$_temp0';
  }

  @override
  String get legendBase => 'Base';

  @override
  String get levelLabel => 'Level';

  @override
  String get male => 'Boy';

  @override
  String get maxPpUps => 'Max PP Ups';

  @override
  String get mint => 'Mint (stat nature)';

  @override
  String get minutes => 'Minutes';

  @override
  String get money => 'Money';

  @override
  String moneyMax(int max) {
    return 'Maximum $max';
  }

  @override
  String moveN(int n) {
    return 'Move $n';
  }

  @override
  String get nature => 'Nature';

  @override
  String get neutral => 'neutral';

  @override
  String get newPokemon => 'New Pokémon';

  @override
  String get nickname => 'Nickname';

  @override
  String get no => 'No';

  @override
  String get noChanges => 'No changes: the draft matches this copy';

  @override
  String get noMatches => 'No matches';

  @override
  String get none => 'None';

  @override
  String get originEdit => 'Edit';

  @override
  String get otGender => 'Trainer gender';

  @override
  String get otName => 'Original trainer';

  @override
  String get pokemon => 'Pokémon';

  @override
  String get pouchBalls => 'Poké Balls';

  @override
  String get pouchBattle => 'Battle items';

  @override
  String get pouchBerries => 'Berries';

  @override
  String get pouchCandy => 'Candy & materials';

  @override
  String get pouchEmpty =>
      'This pouch is empty. Add items with the search field.';

  @override
  String get pouchFull => 'Pouch full';

  @override
  String get pouchIngredients => 'Ingredients';

  @override
  String get pouchItems => 'Items';

  @override
  String get pouchKey => 'Key items';

  @override
  String get pouchMail => 'Mail';

  @override
  String get pouchMedicine => 'Medicine';

  @override
  String get pouchPc => 'PC';

  @override
  String get pouchTms => 'TMs & HMs';

  @override
  String get pouchTreasure => 'Treasures';

  @override
  String pouchUsage(int used, int capacity) {
    return '$used / $capacity';
  }

  @override
  String get pouchZ => 'Z-Crystals / power-ups';

  @override
  String get ppUps => 'PP Ups';

  @override
  String get presetClear => 'Clear';

  @override
  String get presetMaxAvs => 'All to 200';

  @override
  String get presetMaxGvs => 'All to 10';

  @override
  String get presetMaxStatExp => 'Max all';

  @override
  String get presetPerfectIvs => 'Perfect IVs';

  @override
  String get presetPhysWall => 'Physical wall';

  @override
  String get presetPhysical => 'Physical attacker';

  @override
  String get presetSpecWall => 'Special wall';

  @override
  String get presetSpecial => 'Special attacker';

  @override
  String get presetZeroAttack => '0 Attack';

  @override
  String get presetZeroSpeed => '0 Speed';

  @override
  String get redo => 'Redo';

  @override
  String get removeItem => 'Remove';

  @override
  String get restorePp => 'Restore PP';

  @override
  String get revert => 'Revert';

  @override
  String get saveDraftBody =>
      'A new copy with these changes is created in the Ark. The current copy and the original file stay untouched.';

  @override
  String get saveDraftTitle => 'Save to the Ark';

  @override
  String saveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String get saveToArca => 'Save to the Ark';

  @override
  String get savedToArca => 'Saved as a new copy in the Ark';

  @override
  String get seconds => 'Seconds';

  @override
  String get sectionIdentity => 'Identity';

  @override
  String get sectionInventory => 'Inventory';

  @override
  String get sectionMoves => 'Moves';

  @override
  String get sectionPokemon => 'Pokémon';

  @override
  String get sectionStats => 'Stats';

  @override
  String get sectionTrainer => 'Original trainer';

  @override
  String get sectionTrainerTab => 'Trainer';

  @override
  String get sectionTraits => 'Level & traits';

  @override
  String get shinySquare => 'Square';

  @override
  String get shinyStar => 'Star';

  @override
  String slotBox(String box, int n) {
    return '$box, slot $n';
  }

  @override
  String slotParty(int n) {
    return 'Team, slot $n';
  }

  @override
  String get special => 'Special';

  @override
  String get species => 'Species';

  @override
  String get statExp => 'Stat exp';

  @override
  String statsAtLevel(int level) {
    return 'Stats at level $level';
  }

  @override
  String get teraOriginal => 'Original Tera Type';

  @override
  String get teraType => 'Tera Type';

  @override
  String get trainerApplied => 'Trainer data applied to the draft';

  @override
  String get trainerGender => 'Character';

  @override
  String get trainerIdLong => 'Trainer ID (16-bit)';

  @override
  String get trainerIdNote =>
      'Changing your ID does not update your Pokémon: the ones you caught would stop being \"yours\".';

  @override
  String get trainerName => 'Name';

  @override
  String get trainerNotEditable =>
      'This save\'s trainer data cannot be edited.';

  @override
  String get undo => 'Undo';

  @override
  String unsavedChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unsaved changes',
      one: '1 unsaved change',
    );
    return '$_temp0';
  }

  @override
  String get useSpeciesName => 'Use the species name';

  @override
  String visibleId(String id) {
    return 'In game: $id';
  }

  @override
  String get pouchMega => 'Mega Stones';

  @override
  String get pouchRecipes => 'Recipes';

  @override
  String get pouchSatchel => 'Satchel';

  @override
  String get pouchStorage => 'Storage';

  @override
  String get sectionPokedex => 'Pokédex';

  @override
  String get sectionEvents => 'Events';

  @override
  String get legalityAreaOrigin => 'Origin and encounter';

  @override
  String get legalityAreaMoves => 'Moves';

  @override
  String get legalityAreaStats => 'Stats';

  @override
  String get legalityAreaMisc => 'Other data';

  @override
  String get legalityFix => 'Try to fix';

  @override
  String legalityFixAll(int n) {
    return 'Fix safe issues ($n)';
  }

  @override
  String get legalityManual => 'No automatic fix: review it by hand.';

  @override
  String get legalityScope =>
      'Origin, ball, ability, shiny and learnset rules are checked, plus the encounter (location, level and species) against PKHeX\'s tables. Max Raids (Sword/Shield) are included; events and Tera Raids are not verified yet.';

  @override
  String get legalityFixedSnack =>
      'Fix applied. Review the result before saving.';

  @override
  String get dexSeen => 'Seen';

  @override
  String get dexCaught => 'Caught';

  @override
  String get dexShiny => 'Shiny seen';

  @override
  String get dexFilterAll => 'All';

  @override
  String get dexFilterMissing => 'Not caught';

  @override
  String get dexFilterSeen => 'Seen only';

  @override
  String get dexFilterCaught => 'Caught';

  @override
  String get dexSearch => 'Search by name or number';

  @override
  String get dexComplete => 'Complete';

  @override
  String get dexCompleteShiny => 'Complete with shinies';

  @override
  String get dexClear => 'Clear';

  @override
  String get dexConfirmCompleteTitle => 'Complete the Pokédex?';

  @override
  String dexConfirmCompleteBody(int n) {
    return 'All $n species will be marked as seen and caught. Some games give rewards or trigger events when it is complete, so this changes your progress. You can undo it before saving.';
  }

  @override
  String get dexConfirmClearTitle => 'Clear the Pokédex?';

  @override
  String get dexConfirmClearBody =>
      'Every seen and caught record will be erased. You can undo it before saving.';

  @override
  String get dexUnsupported => 'This game\'s Pokédex can\'t be edited yet.';

  @override
  String get dexNoMatch => 'No species match the filter.';

  @override
  String get dexToggleSeen => 'Seen';

  @override
  String get dexToggleCaught => 'Caught';

  @override
  String get dexToggleShiny => 'Shiny';

  @override
  String get eventsWarningTitle => 'Changing events can break your game';

  @override
  String get eventsWarningBody =>
      'Flags and constants drive the story, collected items and battles. A wrong value can block progress or make characters vanish. Only change what you understand: the original stays safe in the Arca.';

  @override
  String eventsFlags(int n) {
    return 'Flags ($n)';
  }

  @override
  String eventsWork(int n) {
    return 'Constants ($n)';
  }

  @override
  String get eventsNamed => 'Named';

  @override
  String get eventsRaw => 'Full list';

  @override
  String get eventsSearch => 'Search by name or number';

  @override
  String get eventsUnsupported => 'This game has no event editor yet.';

  @override
  String get eventsNoMatch => 'Nothing matches the search.';

  @override
  String get eventsUnnamed => 'No known name';

  @override
  String get eventsNoNames =>
      'There is no reliable name table for this game: showing the raw list.';

  @override
  String eventsShowing(int n, String shown) {
    return 'Showing $shown of $n';
  }

  @override
  String get bulkTitle => 'Bulk import';

  @override
  String bulkDetected(int n) {
    return 'Detected ($n)';
  }

  @override
  String bulkDuplicates(int n) {
    return 'Already in the Arca ($n)';
  }

  @override
  String bulkRepeated(int n) {
    return 'Repeated in the selection ($n)';
  }

  @override
  String bulkUnrecognized(int n) {
    return 'Not recognized ($n)';
  }

  @override
  String bulkIgnored(int n) {
    return '$n files skipped by size or type (ROMs, keys, images…).';
  }

  @override
  String bulkImportNew(int n) {
    return 'Import $n new';
  }

  @override
  String get bulkNothingNew => 'There is nothing new to import.';

  @override
  String bulkSubfolders(int n) {
    return '$n files checked in the folder and its subfolders.';
  }

  @override
  String get archiveExport => 'Export the Arca (zip)';

  @override
  String get archiveExportDesc =>
      'Every copy, organised by game, with a JSON manifest.';

  @override
  String get archiveRestore => 'Restore from zip';

  @override
  String get archiveRestoreDesc =>
      'Bring back an exported zip: adds what is missing and skips duplicates.';

  @override
  String archiveExported(int n) {
    return 'Arca exported: $n copies.';
  }

  @override
  String get archiveEmpty => 'The Arca is empty: nothing to export.';

  @override
  String get archiveInvalid =>
      'That zip is not an Arca export (manifest.json is missing).';

  @override
  String get compareAction => 'Compare with…';

  @override
  String get compareTitle => 'Compare copies';

  @override
  String get compareBefore => 'Before';

  @override
  String get compareAfter => 'After';

  @override
  String get comparePick => 'Choose the other copy';

  @override
  String get compareTrainer => 'Trainer';

  @override
  String get compareParty => 'Party';

  @override
  String get compareBoxes => 'Boxes';

  @override
  String get compareInventory => 'Inventory';

  @override
  String get comparePokedex => 'Pokédex';

  @override
  String get compareAdded => 'Joined';

  @override
  String get compareRemoved => 'Left';

  @override
  String get compareChanged => 'Changed';

  @override
  String get compareMoved => 'Moved';

  @override
  String get compareIdentical => 'Both copies have the same content.';

  @override
  String compareSummary(int n) {
    return '$n differences';
  }

  @override
  String compareDexGained(int n) {
    return '$n new Pokédex species';
  }

  @override
  String compareDexLost(int n) {
    return '$n Pokédex species removed';
  }

  @override
  String get compareSwap => 'Swap';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldTid => 'ID';

  @override
  String get fieldSid => 'Secret ID';

  @override
  String get fieldMoney => 'Money';

  @override
  String get fieldPlayTime => 'Play time';

  @override
  String get fieldGender => 'Gender';

  @override
  String get fieldSpecies => 'Species';

  @override
  String get fieldForm => 'Form';

  @override
  String get fieldNickname => 'Nickname';

  @override
  String get fieldLevel => 'Level';

  @override
  String get fieldExp => 'Experience';

  @override
  String get fieldMoves => 'Moves';

  @override
  String get fieldItem => 'Item';

  @override
  String get fieldAbility => 'Ability';

  @override
  String get fieldNature => 'Nature';

  @override
  String get fieldIvs => 'IVs';

  @override
  String get fieldEvs => 'EVs';

  @override
  String get fieldShiny => 'Shiny';

  @override
  String get fieldBall => 'Ball';

  @override
  String get fieldFriendship => 'Friendship';

  @override
  String get showMore => 'Show more';

  @override
  String get editPokedex => 'Pokédex updated';

  @override
  String get editEvents => 'Events changed';

  @override
  String get dexRegionAll => 'All';

  @override
  String get dexRegionNational => 'National';

  @override
  String get dexRegion_galar => 'Galar';

  @override
  String get dexRegion_armor => 'Isle of Armor';

  @override
  String get dexRegion_crown => 'Crown Tundra';

  @override
  String get dexRegion_hisui => 'Hisui';

  @override
  String get dexRegion_paldea => 'Paldea';

  @override
  String get dexRegion_kitakami => 'Kitakami';

  @override
  String get dexRegion_blueberry => 'Blueberry';

  @override
  String get dexRegion_lumiose => 'Lumiose';

  @override
  String get dexRegion_hyperspace => 'Hyperspace';

  @override
  String get dexDetailHint =>
      'Long-press a species (or right-click) to edit genders and forms.';

  @override
  String get dexDetailTitle => 'Pokédex entry';

  @override
  String get dexDetailSeen => 'Seen';

  @override
  String get dexDetailCaught => 'Caught';

  @override
  String get dexDetailShiny => 'Seen shiny';

  @override
  String get dexDetailGenders => 'Genders seen';

  @override
  String get dexDetailMale => 'Male';

  @override
  String get dexDetailFemale => 'Female';

  @override
  String get dexDetailGenderless => 'Genderless';

  @override
  String get dexDetailForms => 'Forms seen';

  @override
  String dexDetailForm(String form) {
    return 'Form $form';
  }

  @override
  String get dexDetailFormBase => 'Base';

  @override
  String get dexDetailFormUnavailable => 'Not in this game';

  @override
  String get dexResearch => 'Research';

  @override
  String get dexResearchNote =>
      'Research level is computed from the game\'s tasks; it is shown here read-only. Completing the Pokédex does not change it.';

  @override
  String get dexDetailApply => 'Apply';

  @override
  String dexRegionalNumber(String number, String region) {
    return '$region #$number';
  }

  @override
  String exportVerified(String path) {
    return 'Exported and verified (checksums and contents re-read): $path';
  }

  @override
  String exportVerifyFailed(String detail) {
    return 'Not exported: re-reading the generated file did not match the draft ($detail). Your original save is untouched.';
  }

  @override
  String get legalityAreaEncounter =>
      'Encounter vs. the game\'s tables (location, level and species)';

  @override
  String get originAdopted => 'Adopted from the folder';

  @override
  String get originMigrated => 'Migrated from the previous Arca';

  @override
  String get onbEyebrow => 'Welcome to PKArkTools';

  @override
  String get onbTitle => 'Your Arca, in your folder';

  @override
  String get onbBody =>
      'Pick a folder and all your backups will live there. If the folder is in a syncing cloud, your devices will share the Arca with nothing else to do.';

  @override
  String get onbSuggestICloud =>
      'Tip: create a folder in iCloud Drive and you will have the same Arca on your iPhone, iPad and Mac.';

  @override
  String get onbSuggestDocuments =>
      'Tip: a folder in Documents, or inside Google Drive, OneDrive, Dropbox or Syncthing to share it between devices.';

  @override
  String get onbChoose => 'Choose folder';

  @override
  String get onbUseLocal => 'Use the app\'s local folder';

  @override
  String get onbLater => 'You can change it any time in Settings.';

  @override
  String get onbPointNoAccount => 'No accounts, no sign-in';

  @override
  String get onbPointReadable => 'Readable files: Game / Trainer / date';

  @override
  String get onbPointSafe => 'Nothing is ever overwritten';

  @override
  String onbLegacy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Your $count current backups will be copied to the chosen folder and verified one by one.',
      one:
          'Your current backup will be copied to the chosen folder and verified.',
    );
    return '$_temp0';
  }

  @override
  String get folderPreparing => 'Preparing the Arca…';

  @override
  String folderProgress(int done, int total) {
    return 'Copying and verifying $done of $total';
  }

  @override
  String migrationFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count backups could not be migrated.',
      one: '1 backup could not be migrated.',
    );
    return '$_temp0 The previous Arca is kept untouched so nothing is lost.';
  }

  @override
  String folderPickFailed(String error) {
    return 'That folder could not be used: $error';
  }

  @override
  String get accessLostTitle => 'We can\'t open your Arca';

  @override
  String get accessLostBody =>
      'The app lost permission to the folder or it is no longer available (drive disconnected, folder moved or permission revoked). Your backups are still in the folder: choose it again to continue.';

  @override
  String get accessRetry => 'Retry';

  @override
  String get accessChooseAgain => 'Choose the folder again';

  @override
  String get folderSection => 'Arca folder';

  @override
  String get folderSectionDesc =>
      'All backups live in this folder. The app\'s database is only an index on this device and is rebuilt from here.';

  @override
  String folderSynced(String provider) {
    return 'Synced with $provider';
  }

  @override
  String get folderLocalOnly => 'Only on this device';

  @override
  String get folderAppLocal => 'App\'s local folder';

  @override
  String get folderReindex => 'Reindex';

  @override
  String get folderChange => 'Change folder…';

  @override
  String get folderChangeTitle => 'Move or copy the Arca?';

  @override
  String get folderChangeBody =>
      'Backups will be written to the new folder and each one checked by its SHA-256. When moving, only verified backups are removed from the previous folder.';

  @override
  String get folderMove => 'Move';

  @override
  String get folderCopy => 'Copy and keep the old one';

  @override
  String folderChangeDone(int copied, int skipped) {
    return 'Arca in the new folder: $copied copied, $skipped already there.';
  }

  @override
  String folderLeftBehind(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count loose files stayed in the previous folder.',
      one: '1 loose file stayed in the previous folder.',
    );
    return '$_temp0';
  }

  @override
  String get reindexNever =>
      'The folder has not been checked in this session yet.';

  @override
  String reindexLast(String time) {
    return 'Last check: $time';
  }

  @override
  String reindexResult(int added, int removed, int dups) {
    return 'Reindexed: $added new, $removed removed, $dups duplicates.';
  }

  @override
  String get statBackups => 'backups';

  @override
  String get statIssues => 'issues';

  @override
  String ignoredFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count files skipped (temporary, partial or cloud conflict copies).',
      one: '1 file skipped (temporary, partial or a cloud conflict copy).',
    );
    return '$_temp0';
  }

  @override
  String get snapshotDamaged => 'This backup is damaged in the Arca folder.';

  @override
  String get dexSearchShort => 'Name or number';

  @override
  String get dexDetailHintTouch =>
      'Long-press a species to edit genders and forms.';

  @override
  String get dexFilterLabel => 'Filter Pokédex';

  @override
  String get onbSuggestGoogleDrive =>
      'Tip: pick a folder inside Google Drive to share the Arca with your other devices, or in Documents to keep it on this phone only.';

  @override
  String get onbSuggestOneDrive =>
      'Tip: create a folder in OneDrive and you will have the same Arca on all your PCs.';

  @override
  String get onbSuggestSyncthing =>
      'Tip: a folder synced with Syncthing gives you the same Arca on all your machines, no accounts needed.';

  @override
  String get boxPrevious => 'Previous box';

  @override
  String get boxNext => 'Next box';

  @override
  String get pouchSwipeHint => 'Swipe an item to the left to remove it.';

  @override
  String get cardNoParty => 'No team in this backup';

  @override
  String get checksumMinor => 'Verification: minor issue';

  @override
  String get checksumMajor => 'Damaged data';

  @override
  String get damageMinorTitle =>
      'Fully readable, but a verification check doesn\'t match';

  @override
  String get damageMajorTitle => 'Part of this save can\'t be read';

  @override
  String get damagePartWhole => 'The file\'s checksums don\'t match its data.';

  @override
  String get damagePartTrainer =>
      'The trainer block doesn\'t match its checksum.';

  @override
  String get damagePartParty => 'The party block doesn\'t match its checksum.';

  @override
  String get damagePartBoxes => 'The box block doesn\'t match its checksum.';

  @override
  String get damagePartOther =>
      'A block of other game data (items, Pokédex, events…) doesn\'t match its checksum.';

  @override
  String get damagePartSignature =>
      'The save\'s digital signature doesn\'t match its data.';

  @override
  String get damagePartFileHash =>
      'The whole-file verification hash doesn\'t match.';

  @override
  String get damagePartUnreadable =>
      'Some data can\'t be read (Pokémon or impossible values).';

  @override
  String get damageMinorMeaning =>
      'All data reads fine and you can browse it. It was opened read-only because the game checks these values: with one that doesn\'t match, it might refuse to load the save or treat it as corrupted.';

  @override
  String get damageMajorMeaning =>
      'What you see may be incomplete or wrong. It was opened read-only: it isn\'t safe to edit.';

  @override
  String get damageWhy =>
      'This usually happens when the file was only partly copied, when it\'s a save from another version or format, or when another tool edited it without recalculating its checks.';

  @override
  String get damageMinorTodo =>
      'If the game loads this save fine, use “Repair checksums and export” to get a copy with the checks recalculated (the copy in the Ark isn\'t touched). Otherwise, copy the save again from the console or emulator.';

  @override
  String get damageMajorTodo =>
      'Copy the original save again from the console or emulator and import it again. You can export this copy as-is with “Export”.';

  @override
  String get damageRepairExport => 'Repair checksums and export';

  @override
  String get damageTechnical => 'Technical details';

  @override
  String get repairedSuffix => 'repaired';

  @override
  String exportRepaired(String path) {
    return 'Repaired copy verified and exported: $path';
  }

  @override
  String get versionPickMenu => 'Set game version…';

  @override
  String get versionPickTitle => 'Game version';

  @override
  String get versionPickBody =>
      'The save doesn\'t say which cartridge it is. Pick one for the color and title; it\'s stored in each copy\'s .json.';

  @override
  String get versionUnspecified => 'Unspecified (pair)';

  @override
  String versionFromSave(String name) {
    return 'This save already states its version: $name.';
  }

  @override
  String get spritesSection => 'Icons';

  @override
  String get spritesSectionDesc =>
      'Pokémon, item, Ball, type and ribbon sprites don\'t ship with the app: they\'re downloaded the first time they\'re shown and kept in the app\'s cache (never in the Arca folder). Offline, initials are shown instead.';

  @override
  String spritesCacheSize(int count, String size, String total) {
    return 'Cached: $size · full download: $total ($count icons)';
  }

  @override
  String spritesDownloadAll(String size) {
    return 'Download all icons ($size)';
  }

  @override
  String get spritesClear => 'Clear icon cache';

  @override
  String spritesProgress(int done, int total) {
    return '$done of $total icons';
  }

  @override
  String get spritesDone => 'All icons are downloaded.';

  @override
  String spritesFailed(int count) {
    return '$count icons couldn\'t be downloaded; try again when online.';
  }

  @override
  String get spritesCancelled => 'Download cancelled.';

  @override
  String spritesProgressBytes(
    int done,
    int total,
    String size,
    String totalSize,
  ) {
    return '$done of $total icons · $size of $totalSize';
  }

  @override
  String get spritesOffline =>
      'No Internet connection: GitHub couldn\'t be reached. What was already downloaded is kept; try again when online.';

  @override
  String get spritesCleared => 'Icon cache cleared.';

  @override
  String spritesCredits(String pokemonCommit, String pkhexCommit) {
    return 'Pokémon icons: Pokémon HOME box icons from the Smogon / Pokémon Showdown sprite repository (github.com/smogon/sprites, commit $pokemonCommit); Gigantamax, new Megas and the shiny special forms come from the same commit (HOME icons and renders, Pokémon Champions icons). Items, Balls, types and ribbons: PKHeX resources (github.com/kwsch/PKHeX, commit $pkhexCommit). Downloaded on demand, never bundled. Sprites are © Nintendo / Game Freak / The Pokémon Company.';
  }

  @override
  String get sectionOrigin => 'Origin';

  @override
  String get sectionRibbons => 'Ribbons and marks';

  @override
  String get originGame => 'Origin game';

  @override
  String get originPlace => 'Met location';

  @override
  String get originHatchPlace => 'Hatch location';

  @override
  String get originLevel => 'Met level';

  @override
  String get originDate => 'Date';

  @override
  String get originEggDate => 'Egg received';

  @override
  String get originEncounterHere => 'appears here';

  @override
  String get originShowAll => 'Show every place in the game';

  @override
  String get originOnlyValid => 'Only places where it appears';

  @override
  String get originFateful => 'Fateful encounter (event)';

  @override
  String originEggReceived(String date, String place) {
    return 'Egg received at $place on $date';
  }

  @override
  String originHatched(String date, String place) {
    return 'Hatched at $place on $date';
  }

  @override
  String originMet(String date, int nLevel, String place) {
    return 'Met at $place, level $nLevel, $date';
  }

  @override
  String get originNoDate => 'no date (Gen 3)';

  @override
  String originTrainer(String name, String tid) {
    return 'Original trainer: $name (ID $tid)';
  }

  @override
  String originHomeTracker(String tracker) {
    return 'Went through Pokémon HOME (tracker $tracker)';
  }

  @override
  String get originNotInGame =>
      'This species doesn\'t appear in its origin game\'s encounter tables (event, trade or egg?).';

  @override
  String originValidPlaces(String places) {
    return 'The place or level doesn\'t match its game. Valid places: $places';
  }

  @override
  String get transferPalPark => 'Pal Park';

  @override
  String get transferPokeTransfer => 'Poké Transfer';

  @override
  String get transferTransporter => 'Poké Transporter / Bank';

  @override
  String get transferVirtualConsole => 'Virtual Console → Poké Transporter';

  @override
  String get transferBank => 'Pokémon Bank';

  @override
  String get ribbonsContest => 'Contests';

  @override
  String get ribbonsBattle => 'Battle';

  @override
  String get ribbonsCommemorative => 'Commemorative';

  @override
  String get ribbonsEvent => 'Events';

  @override
  String get ribbonsMarks => 'Marks';

  @override
  String ribbonsOwned(int count, int nTotal) {
    return '$count of $nTotal';
  }

  @override
  String get ribbonsOnlyOwned => 'Only owned';

  @override
  String get ribbonsGiveAll => 'Give all valid';

  @override
  String get ribbonsRemoveAll => 'Remove all';

  @override
  String ribbonsGiven(int count) {
    return '$count ribbons added.';
  }

  @override
  String get ribbonsNone => 'No ribbons or marks.';

  @override
  String get ribbonHas => 'Has it';

  @override
  String get ribbonAffixed => 'Displayed ribbon';

  @override
  String get ribbonAffixedHint => 'Shown next to its name (title).';

  @override
  String ribbonAffixedNow(String name) {
    return 'Displaying: $name';
  }

  @override
  String get ribbonEventOnly => 'Only distributed at events.';

  @override
  String get ribbonEncounterMark =>
      'Encounter mark: given by the game on capture.';

  @override
  String get ribbonObtainable =>
      'Obtainable in the games it could have visited.';

  @override
  String get ribbonNotObtainable =>
      'Not obtainable in any game it could have visited.';

  @override
  String get originDateUnknown => 'no date';

  @override
  String get filtersAction => 'Filters';

  @override
  String get filtersTitle => 'Filters';

  @override
  String get filtersClear => 'Clear';

  @override
  String get filtersClearAll => 'Clear filters';

  @override
  String filtersShow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count games',
      one: 'Show 1 game',
      zero: 'No games',
    );
    return '$_temp0';
  }

  @override
  String filtersResults(int count, int nTotal) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count games of $nTotal',
      one: '1 game of $nTotal',
    );
    return '$_temp0';
  }

  @override
  String get filtersNoMatchTitle => 'No games match';

  @override
  String get filtersNoMatchBody =>
      'Try removing a filter or changing the search.';

  @override
  String filtersRemove(String label) {
    return 'Remove filter $label';
  }

  @override
  String get sortLabel => 'Sort';

  @override
  String get sortRecent => 'Most recent';

  @override
  String get sortTrainer => 'Trainer';

  @override
  String get sortGame => 'Game / generation';

  @override
  String get sortPlayTime => 'Play time';

  @override
  String get sortCopies => 'Number of copies';

  @override
  String get filterGeneration => 'Generation';

  @override
  String filterGenShort(int gen) {
    return 'Gen $gen';
  }

  @override
  String get filterPlatform => 'Console';

  @override
  String get filterSource => 'Source';

  @override
  String get sourceEmulator => 'Emulator';

  @override
  String get sourceMobile => 'Android/iOS port';

  @override
  String get sourceCheckpoint => 'Checkpoint/JKSM';

  @override
  String get sourceCartridge => 'Cartridge';

  @override
  String get sourceOther => 'Other / unknown';

  @override
  String get filterGame => 'Game';

  @override
  String get filterStatus => 'Status';

  @override
  String get statusDamaged => 'With damage warnings';

  @override
  String get statusLegality => 'With legality warnings';

  @override
  String get statusEdited => 'Edited by me';

  @override
  String get statusMultiple => 'With several copies';

  @override
  String legalityScanning(int done, int nTotal) {
    return 'Checking legality… $done of $nTotal';
  }

  @override
  String get filterDate => 'Last backup';

  @override
  String get datePresetWeek => 'Last week';

  @override
  String get datePresetMonth => 'Last month';

  @override
  String get datePresetYear => 'Last year';

  @override
  String get dateCustom => 'Pick dates…';

  @override
  String dateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String spritesOnDisk(int nTotal, int nValid) {
    return 'Saved and valid: $nValid of $nTotal icons.';
  }

  @override
  String spritesMissing(int count) {
    return '$count icons are missing or damaged (empty or cut off): “Repair icons” downloads only those.';
  }

  @override
  String spritesRepair(int count) {
    return 'Repair icons ($count)';
  }

  @override
  String spritesIncomplete(int count) {
    return 'The download finished, but $count icons are missing. Tap “Repair icons” when online.';
  }

  @override
  String get originRestored => 'Restored';

  @override
  String currentVersionTitle(String date) {
    return 'Current version · $date';
  }

  @override
  String mainFileLabel(String name) {
    return 'In the folder as “$name”, ready to copy to the game or emulator.';
  }

  @override
  String get openFolder => 'Open folder';

  @override
  String get openFolderTitle => 'Save folder';

  @override
  String openFolderBody(String path, String root) {
    return 'Inside the Ark folder ($root):\n\n$path';
  }

  @override
  String get copyPath => 'Copy path';

  @override
  String get pathCopied => 'Path copied';

  @override
  String historyCount(int count) {
    return 'History ($count)';
  }

  @override
  String get historyFoldedHint =>
      'Every copy, newest first. They are never modified.';

  @override
  String get mainModifiedTitle => 'The main file changed outside the app';

  @override
  String mainModifiedBody(String name) {
    return '“$name” doesn\'t match any copy in the history (did you copy a new save over it?). Save it as a new copy to keep it; it is never deleted.';
  }

  @override
  String get saveAsNewCopy => 'Save as new copy';

  @override
  String savedAsNewCopy(String name) {
    return 'Saved to the history: $name';
  }

  @override
  String get restoreAsCurrentTitle => 'Restore as the current version?';

  @override
  String restoreAsCurrentBody(String name) {
    return 'A new history entry is created from this copy and the main file (“$name”) becomes this version. No copy in the history is modified.';
  }

  @override
  String get restoreAlsoSource => 'Restore and write to the original';

  @override
  String get restoredAsCurrent => 'Copy restored as the current version';

  @override
  String restoredNote(String date) {
    return 'Restored from the copy of $date';
  }

  @override
  String get arcaLayoutTitle => 'How the folder is organized';

  @override
  String get arcaLayoutDesc =>
      'Each save has its own folder with the latest version, named the way the game expects (main, SaveData.bin, Emerald.sav…), ready to copy to the game or emulator. Below it, historial/ keeps every copy and never modifies them. The latest version is derived: it is always rebuilt from the history, so nothing is lost even if you delete or change it.';

  @override
  String historyMigrated(int count) {
    return 'Folder updated: $count copies moved to historial/';
  }

  @override
  String get originInbox => 'Inbox';

  @override
  String get gameFoldersQuestion => 'Create folders for your games?';

  @override
  String get gameFoldersQuestionBody =>
      'So you know where to drop each save: PKArkTools picks it up and keeps it with its history.';

  @override
  String get gameFoldersAll => 'Yes, all games';

  @override
  String get gameFoldersChoose => 'Choose games…';

  @override
  String get gameFoldersNotNow => 'Not now';

  @override
  String get gameFoldersCreate => 'Create game folders';

  @override
  String get gameFoldersCreateDesc =>
      'One folder per game with a README saying which save to drop. Anything you drop there is picked up automatically.';

  @override
  String get gameFoldersPickerTitle => 'Game folders';

  @override
  String get gameFoldersPickAll => 'All';

  @override
  String get gameFoldersPickNone => 'None';

  @override
  String get gameFoldersPickOwned => 'The ones I have';

  @override
  String gameFoldersGeneration(int n) {
    return 'Generation $n';
  }

  @override
  String get gameFoldersExists => 'already exists';

  @override
  String gameFoldersConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Create $count folders',
      one: 'Create 1 folder',
    );
    return '$_temp0';
  }

  @override
  String gameFoldersDone(String created, String existing) {
    return 'Folders created: $created (already there: $existing)';
  }

  @override
  String inboxAdoptedToast(String files) {
    return 'Picked up from the inbox: $files';
  }

  @override
  String inboxProblemsToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inbox saves need your attention',
      one: '1 inbox save needs your attention',
    );
    return '$_temp0';
  }

  @override
  String get inboxSee => 'View';

  @override
  String get problemsNone => 'No problems in the Arca';

  @override
  String problemsSummary(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n problems in the Arca',
      one: '1 problem in the Arca',
    );
    return '$_temp0';
  }

  @override
  String problemsErrors(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n errors',
      one: '1 error',
    );
    return '$_temp0';
  }

  @override
  String problemsWarnings(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n warnings',
      one: '1 warning',
    );
    return '$_temp0';
  }

  @override
  String get problemsFixAll => 'Fix all';

  @override
  String get problemsFix => 'Fix';

  @override
  String get problemsIgnore => 'Ignore';

  @override
  String problemsFixGroup(int n) {
    return 'Fix ($n)';
  }

  @override
  String problemsIgnoreGroup(int n) {
    return 'Ignore ($n)';
  }

  @override
  String problemsShowIgnored(int n) {
    return 'Show ignored ($n)';
  }

  @override
  String get problemsHideIgnored => 'Hide ignored';

  @override
  String get problemsUnignore => 'Stop ignoring';

  @override
  String get problemsIgnoredHint =>
      'They won\'t warn again unless the file changes. Saved on this device only.';

  @override
  String problemsMore(int n) {
    return 'and $n more';
  }

  @override
  String problemsConfirmTitle(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Fix $n problems?',
      one: 'Fix 1 problem?',
    );
    return '$_temp0';
  }

  @override
  String get problemsConfirmBody =>
      'Each .json is rebuilt from its save, loose saves are adopted and copies already in the history are removed. Nothing is deleted: anything that can\'t be repaired is moved to PKArkTools/_cuarentena/ with a note.';

  @override
  String problemsFixing(int nDone, int nTotal) {
    return 'Fixing $nDone of $nTotal…';
  }

  @override
  String problemsResultFixed(int n) {
    return '$n fixed';
  }

  @override
  String problemsResultQuarantined(int n) {
    return '$n quarantined';
  }

  @override
  String problemsResultFailed(int n) {
    return '$n not fixed';
  }

  @override
  String get problemsSeeSettings => 'View in Settings';

  @override
  String get problemCorruptSidecar => 'Damaged .json';

  @override
  String get problemCorruptSidecarDesc =>
      'It can\'t be read. Fix rebuilds it by re-reading its save.';

  @override
  String get problemMissingSidecar => 'Save without its .json';

  @override
  String get problemMissingSidecarDesc =>
      'It may still be syncing. Fix creates the .json from the save.';

  @override
  String get problemMissingSave => '.json without its save';

  @override
  String get problemMissingSaveDesc =>
      'It may still be syncing. Fix moves the .json to quarantine.';

  @override
  String get problemContentMismatch => 'Save doesn\'t match its .json';

  @override
  String get problemContentMismatchDesc =>
      'It was changed outside the app. Fix saves its content as a new copy and sets the old pair aside.';

  @override
  String get problemUnreadable => 'Couldn\'t be read';

  @override
  String get problemUnreadableDesc =>
      'Permission or locked file. Fix reads it again and rebuilds the .json.';

  @override
  String get problemMainFailed => 'Latest version not updated';

  @override
  String get problemMainFailedDesc =>
      'The main file or ultima.json couldn\'t be written. Fix rebuilds them from the history.';

  @override
  String get problemInboxUnreadable => 'Inbox: not a readable save';

  @override
  String get problemInboxUnreadableDesc => 'Fix moves it to quarantine.';

  @override
  String get problemInboxWrongGame => 'Inbox: save from another game';

  @override
  String get problemInboxWrongGameDesc => 'Fix files it under its own game.';

  @override
  String get problemModifiedMain => 'Latest version changed by hand';

  @override
  String get problemModifiedMainDesc =>
      'Its content isn\'t in the history. Fix saves it as a new copy; the file stays.';

  @override
  String get problemConflictCopy => 'Cloud conflict copy';

  @override
  String get problemConflictCopyDesc =>
      'If its content is already in the history, Fix removes it; otherwise it adopts it.';

  @override
  String get problemLooseSave => 'Loose save';

  @override
  String get problemLooseSaveDesc =>
      'Copied by hand outside its place. Fix detects its game and files it in the history.';

  @override
  String get problemDuplicateCopy => 'Duplicate copies in the history';

  @override
  String get problemDuplicateCopyDesc =>
      'Same content (SHA-256) as an older copy of the same save. Fix keeps the oldest and moves the others, with their .json, to _cuarentena/duplicados/.';

  @override
  String problemDuplicateOf(String name) {
    return 'Same as $name, which is kept';
  }

  @override
  String folderNetwork(String name) {
    return 'Network folder (NAS) · $name';
  }

  @override
  String get folderNetworkHint =>
      'In a network folder, changes from other devices are checked every minute while the app is open and whenever you return to it.';

  @override
  String get networkLostTitle => 'Network folder unavailable';

  @override
  String networkLostBody(String name) {
    return 'Your Arca is in a network folder ($name) that isn\'t mounted or isn\'t responding right now. Connect to the NAS (on a Mac: Finder → Go → Connect to Server) and press Retry. Meanwhile nothing is created, moved or deleted.';
  }

  @override
  String get accessChooseOther => 'Choose another';

  @override
  String importProgress(String done, String total) {
    return 'Importing $done of $total…';
  }

  @override
  String get updateCheck => 'Check for updates';

  @override
  String get updateChecking => 'Checking…';

  @override
  String updateCurrent(String version) {
    return 'Version $version';
  }

  @override
  String updateUpToDate(String version) {
    return 'You have the latest version ($version).';
  }

  @override
  String get updateAutoCheck => 'Check for updates automatically';

  @override
  String get updateAutoCheckDesc =>
      'When the app opens, at most once a day. It only asks api.github.com; nothing of yours is sent.';

  @override
  String updateBannerTitle(String version) {
    return 'PKArkTools $version available';
  }

  @override
  String get updateBannerBody => 'See what\'s new and update when you like.';

  @override
  String get updateNotes => 'What\'s new';

  @override
  String get updateNow => 'Update';

  @override
  String get updateDownload => 'Download';

  @override
  String get updateSkip => 'Skip this version';

  @override
  String get updateLater => 'Not now';

  @override
  String updateSkipped(String version) {
    return 'You won\'t be reminded about $version again.';
  }

  @override
  String get updateOpenPage => 'Open the release page';

  @override
  String updateDownloading(String done, String total) {
    return 'Downloading $done of $total…';
  }

  @override
  String get updateVerifying => 'Checking the APK signature…';

  @override
  String get updateCancel => 'Cancel';

  @override
  String get updateInstalling =>
      'Confirm the installation in the Android window. The app will close and reopen updated, with your copies and settings.';

  @override
  String get updateAndroidHint =>
      'The APK is downloaded from GitHub, checked to be signed with the same key as this app, and Android asks you to confirm. Your copies, settings and Ark folder are kept.';

  @override
  String get updateDesktopHint =>
      'The release file is downloaded; then you install it yourself. Your copies and settings are kept.';

  @override
  String get updateIosHint =>
      'On iPhone and iPad it can\'t be installed from the app: the release page opens.';

  @override
  String get updatePermissionTitle => 'Allow installing the update';

  @override
  String get updatePermissionBody =>
      'Android only lets PKArkTools install its own update if you allow it once. On the screen that opens, turn on \"Allow from this source\", come back and press \"Update\" again.';

  @override
  String get updatePermissionOpen => 'Open settings';

  @override
  String updateSaved(String path) {
    return 'Saved to $path';
  }

  @override
  String get updateShowFolder => 'Show in folder';

  @override
  String get updateStepsMacos =>
      'Quit PKArkTools, unzip the file and drag PKArkTools.app into Applications, replacing the old one. Then open it again.';

  @override
  String get updateStepsWindows =>
      'Close PKArkTools and run the installer: it updates the installed version.';

  @override
  String get updateStepsLinux =>
      'Close PKArkTools, extract the tar.gz and replace the old folder with the new one.';

  @override
  String get updateErrorNetwork =>
      'Couldn\'t reach GitHub. Check your connection and try again.';

  @override
  String get updateErrorRate =>
      'GitHub limits requests without an account. Try again in a while.';

  @override
  String updateErrorGeneric(String code) {
    return 'Couldn\'t update ($code).';
  }

  @override
  String get updateErrorSize =>
      'The download was incomplete or the wrong size. Try again.';

  @override
  String get updateErrorAborted => 'Update cancelled.';

  @override
  String get updateErrorSignature =>
      'Not installed: the downloaded APK isn\'t signed with the same certificate as this app. Only download it from the official release page.';

  @override
  String get updateErrorUntrusted =>
      'The download link isn\'t from the PKArkTools repository on GitHub: it won\'t be downloaded.';

  @override
  String get updateErrorConflict =>
      'Android can\'t install this version over yours: it\'s signed with a different key. Export your Ark before uninstalling and installing the new one.';

  @override
  String get updateErrorStorage =>
      'Couldn\'t save the download (out of space?).';

  @override
  String get updateErrorPermission =>
      'Permission to install apps from this source is missing.';

  @override
  String get updateNoAsset => 'This release has no download for your system.';

  @override
  String get updateRetry => 'Retry';

  @override
  String get navDex => 'Dex';

  @override
  String dexSubtitle(String caught, String saves, String total) {
    return '$caught of $total caught · $saves saves';
  }

  @override
  String dexSubtitleLiving(String caught, String saves, String total) {
    return '$caught of $total in your boxes · $saves saves';
  }

  @override
  String get dexEmptyTitle => 'Your Dex is empty';

  @override
  String get dexEmptyBody =>
      'Import saves into the Ark: the Dex fills in with everything registered or caught in any of them.';

  @override
  String get dexStatCaught => 'Caught';

  @override
  String get dexStatSeen => 'Seen';

  @override
  String get dexStatShiny => 'Shiny';

  @override
  String get dexStatForms => 'Forms';

  @override
  String get dexStatOwned => 'In boxes';

  @override
  String get dexSearchHint => 'Search by name or number';

  @override
  String get dexFilterSeenOnly => 'Seen only';

  @override
  String get dexFilterShiny => 'Shiny';

  @override
  String get dexFilterLockedForms => 'Forms to unlock';

  @override
  String get dexFilterType => 'Type';

  @override
  String get dexFilterGeneration => 'Generation';

  @override
  String get dexFilterGame => 'Game';

  @override
  String get dexAnyType => 'Any type';

  @override
  String get dexAnyGeneration => 'All generations';

  @override
  String get dexAnyGame => 'All games';

  @override
  String get dexSortNumber => 'By number';

  @override
  String get dexSortName => 'By name';

  @override
  String dexResults(int count) {
    return '$count species';
  }

  @override
  String get dexNoResults => 'No species match the filters.';

  @override
  String dexGenRegion(String gen, String region) {
    return 'Gen $gen · $region';
  }

  @override
  String get dexProgress => 'Progress';

  @override
  String get dexByGeneration => 'By generation and region';

  @override
  String get dexByGame => 'By game';

  @override
  String dexGameLine(String available, String caught, int count, String seen) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saves',
      one: '1 save',
    );
    return '$caught caught · $seen seen of $available · $_temp0';
  }

  @override
  String get dexSettings => 'Dex settings';

  @override
  String get dexLivingTitle => 'Living dex';

  @override
  String get dexLivingBody =>
      'Counts a species as caught only if you have one in a box or team in some save, not just registered in its Pokédex. Shows what you are really missing.';

  @override
  String get dexLivingBadge => 'Living dex';

  @override
  String get dexStatusCaught => 'Caught';

  @override
  String get dexStatusSeen => 'Seen';

  @override
  String get dexStatusUnknown => 'Not registered';

  @override
  String get dexStatusOwned => 'In your boxes';

  @override
  String get dexBaseStats => 'Base stats';

  @override
  String get dexStatTotal => 'Total';

  @override
  String get dexAbilities => 'Abilities';

  @override
  String get dexHiddenAbility => 'hidden';

  @override
  String get dexGender => 'Gender';

  @override
  String get dexGenderless => 'Genderless';

  @override
  String dexGenderRatio(String female, String male) {
    return '$male% male · $female% female';
  }

  @override
  String get dexEvolution => 'Evolution';

  @override
  String get dexNoEvolution => 'Does not evolve.';

  @override
  String get dexForms => 'Forms';

  @override
  String get dexSpecialForms => 'Special forms';

  @override
  String get dexSpecialFormsHint =>
      'Mega Evolutions, Gigantamax and other battle forms. Unlocked by a specimen that enables them in a game where they exist; the shiny one, by a shiny specimen.';

  @override
  String get dexGames => 'Games it appears in';

  @override
  String get dexRecords => 'Your records';

  @override
  String get dexRecordsEmpty => 'No save has it registered.';

  @override
  String get dexSpecimens => 'Your specimens';

  @override
  String get dexSpecimensEmpty => 'You have none in teams or boxes.';

  @override
  String dexInParty(String slot) {
    return 'Team, slot $slot';
  }

  @override
  String dexInBox(String box, String slot) {
    return 'Box $box, slot $slot';
  }

  @override
  String get dexOpenInBox => 'Show in its box';

  @override
  String get dexNormal => 'Normal';

  @override
  String get dexShinyVariant => 'Shiny';

  @override
  String dexUnlockedBy(String game, String trainer) {
    return '$trainer · $game';
  }

  @override
  String get dexLocked => 'Locked';

  @override
  String dexHowMega(String games, String species) {
    return 'Have a $species in $games.';
  }

  @override
  String dexHowMegaForm(String form, String games, String species) {
    return 'Have a $species ($form) in $games.';
  }

  @override
  String dexHowGmax(String species) {
    return 'Have a $species with the Gigantamax Factor in Sword/Shield.';
  }

  @override
  String get dexHowUltra =>
      'Have a fused Necrozma (Dusk Mane or Dawn Wings) in Ultra Sun/Ultra Moon.';

  @override
  String get dexHowShiny => 'The shiny one needs a shiny specimen.';

  @override
  String dexItemInBag(String item, String where) {
    return '$item in the bag: $where';
  }

  @override
  String dexItemMissing(String item) {
    return '$item: not in the bag of those saves';
  }

  @override
  String get dexGigantamax => 'Gigantamax';

  @override
  String get dexFormOwned => 'You have this form';

  @override
  String get dexFormMissing => 'No specimen';

  @override
  String dexEvoLevel(String level) {
    return 'Level $level';
  }

  @override
  String get dexEvoLevelUp => 'Level up';

  @override
  String get dexEvoFriendship => 'High friendship';

  @override
  String get dexEvoFriendshipDay => 'High friendship, daytime';

  @override
  String get dexEvoFriendshipNight => 'High friendship, nighttime';

  @override
  String get dexEvoTrade => 'Trade';

  @override
  String dexEvoTradeItem(String item) {
    return 'Trade holding $item';
  }

  @override
  String dexEvoTradeWith(String species) {
    return 'Trade for $species';
  }

  @override
  String dexEvoItemMale(String item) {
    return '$item (♂)';
  }

  @override
  String dexEvoItemFemale(String item) {
    return '$item (♀)';
  }

  @override
  String dexEvoLevelMale(String level) {
    return '$level (♂)';
  }

  @override
  String dexEvoLevelFemale(String level) {
    return '$level (♀)';
  }

  @override
  String dexEvoDay(String level) {
    return '$level, daytime';
  }

  @override
  String dexEvoNight(String level) {
    return '$level, nighttime';
  }

  @override
  String dexEvoDusk(String level) {
    return '$level, at dusk';
  }

  @override
  String dexEvoHeldDay(String item) {
    return 'Level up holding $item, daytime';
  }

  @override
  String dexEvoHeldNight(String item) {
    return 'Level up holding $item, nighttime';
  }

  @override
  String dexEvoKnowMove(String move) {
    return 'Level up knowing $move';
  }

  @override
  String dexEvoMoveType(String type) {
    return 'Level up knowing a $type-type move';
  }

  @override
  String dexEvoTeammate(String species) {
    return 'Level up with $species in the team';
  }

  @override
  String get dexEvoLocation => 'Level up at a special location';

  @override
  String dexEvoStats(String level) {
    return '$level, depending on Attack and Defense';
  }

  @override
  String dexEvoRandom(String level) {
    return '$level (random)';
  }

  @override
  String get dexEvoOther => 'Special method';

  @override
  String get dexPrev => 'Previous';

  @override
  String get dexNext => 'Next';

  @override
  String dexFormsCount(int count) {
    return '$count forms';
  }

  @override
  String dexLockedCount(int count) {
    return '$count to unlock';
  }

  @override
  String dexShinyCount(int count) {
    return '$count shiny';
  }

  @override
  String get dexAllSpecies => 'All';

  @override
  String get dexMissingSpecies => 'Missing';

  @override
  String get dexCaughtSpecies => 'Caught';

  @override
  String get navRibbonHunter => 'Ribbon Hunter';

  @override
  String get navRibbonsShort => 'Ribbons';

  @override
  String get rmSubtitle =>
      'Pick any Pokémon and see every ribbon a single specimen can earn, from the oldest generation to the newest.';

  @override
  String get rmSearchHint => 'Search a species or form (name or number)';

  @override
  String get rmRanking => 'Ranking by tiers';

  @override
  String get rmRankingShort => 'Ranking';

  @override
  String get rmRankingSubtitle =>
      'Species and forms grouped by the most ribbons they can earn by playing today. Open a tier to see every one in it.';

  @override
  String get rmSeeRanking => 'See the ranking';

  @override
  String rmTierCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n species & forms',
      one: '1 species or form',
    );
    return '$_temp0';
  }

  @override
  String rmTierPos(int n) {
    return 'Tier $n';
  }

  @override
  String rmTierOriginAll(String kind, String games) {
    return 'Common origin: $kind in $games';
  }

  @override
  String rmTierOriginMost(String kind, String games, int n, int total) {
    return 'Most common origin: $kind in $games ($n of $total)';
  }

  @override
  String get rmTierFilterHint => 'Filter this tier (name or number)';

  @override
  String rmTierOfRanking(int n, int count, String species) {
    return 'Tier $n of $count in the ranking · $species';
  }

  @override
  String get rmTierNotFound => 'That tier doesn\'t exist.';

  @override
  String rmRibbons(int n) {
    return '$n ribbons';
  }

  @override
  String get rmMaxToday => 'Max today';

  @override
  String get rmOrigin => 'Recommended origin';

  @override
  String rmGen(String gen) {
    return 'Gen $gen';
  }

  @override
  String get rmTimeline => 'Route to Ribbon Master, game by game';

  @override
  String get rmTransferOnly => 'No new ribbons here: it\'s a transfer step.';

  @override
  String rmAlsoHere(String list) {
    return 'Also here: $list';
  }

  @override
  String get rmUnavailable => 'Not available today';

  @override
  String get rmUnavailableBody =>
      'Event ribbons and ribbons from closed online services. They don\'t count towards the max.';

  @override
  String get rmClosedOnline => 'Closed service';

  @override
  String get rmEventOnly => 'Events only';

  @override
  String get rmOnline => 'Online';

  @override
  String get rmMarks => 'Marks';

  @override
  String rmMarksPost(String list) {
    return 'Once caught, it can earn in Scarlet/Violet: $list.';
  }

  @override
  String rmMarksCapture(String games, int n) {
    return 'If you catch it in $games it can also carry one encounter mark ($n possible, at most one per specimen).';
  }

  @override
  String get rmMarksNote =>
      'Marks don\'t add to the total: they\'re only given on capture.';

  @override
  String rmMemory(String battle, String contest, int n) {
    return 'When it moves to Gen 6 its Gen 3–4 contest ($contest) and battle ($battle) ribbons become the Contest and Battle Memory ribbons: in the final game you\'ll see $n ribbons.';
  }

  @override
  String get rmYourSpecimens => 'Your specimens of this species';

  @override
  String rmSpecimenLine(String have, String missing) {
    return '$have ribbons · $missing left that it can still earn';
  }

  @override
  String rmSpecimenComplete(String have) {
    return '$have ribbons · nothing left from its game';
  }

  @override
  String get rmSpecimensEmpty =>
      'There are no specimens of this form in your Arca.';

  @override
  String rmMissingTitle(int n) {
    return 'Missing ($n)';
  }

  @override
  String get rmShare => 'Share guide';

  @override
  String get rmCopyText => 'Copy text for forums';

  @override
  String get rmCopied => 'Guide copied to the clipboard';

  @override
  String get rmSaveImage => 'Save as image';

  @override
  String rmImageSaved(String path) {
    return 'Image saved: $path';
  }

  @override
  String get rmOpenGuide => 'Ribbon Hunter guide';

  @override
  String get rmKindEgg => 'egg';

  @override
  String get rmKindWild => 'wild';

  @override
  String get rmKindStatic => 'static encounter';

  @override
  String get rmKindGift => 'gift';

  @override
  String get rmKindTrade => 'in-game trade';

  @override
  String get rmKindShadow => 'Shadow Pokémon';

  @override
  String get rmKindRaid => 'raid';

  @override
  String get rmKindGo => 'Pokémon GO';

  @override
  String get rmKindEvent => 'event';

  @override
  String get rmNoGuide => 'There\'s no guide for this form.';

  @override
  String rmResults(int n) {
    return '$n results';
  }

  @override
  String get rmHowTitle => 'How it\'s calculated';

  @override
  String get rmHowBody =>
      'We pick the origin that allows the most ribbons (the oldest possible), walk the transfer graph forward only and add up the ribbons you can earn today by playing, offline or online. Each ribbon counts once, in the first game where it can be earned. The rules and each species/form\'s availability are checked against PKHeX.';

  @override
  String get rmOriginEvent =>
      'This species only comes from events or distributions.';

  @override
  String rmStepCount(int n) {
    return '+$n';
  }

  @override
  String rmFormsLabel(String list) {
    return 'Can be: $list';
  }

  @override
  String get rmMemoryTitle => 'Gen 3–4 memories';

  @override
  String rmContestG3(int n) {
    return 'Hoenn contests ($n)';
  }

  @override
  String rmContestG4(int n) {
    return 'Sinnoh Super Contests ($n)';
  }

  @override
  String get rmContestOrderG3 =>
      'Each condition is won in order: Normal → Super → Hyper → Master. Any species can enter.';

  @override
  String get rmContestOrderG4 =>
      'Each condition is won in order: Normal → Great → Ultra → Master (Hearthome City). Any species except Ditto and Unown.';
}
