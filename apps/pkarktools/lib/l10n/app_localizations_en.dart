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
  String get statLoose => 'loose';

  @override
  String get statIgnored => 'ignored';

  @override
  String get issuesTitle => 'Issues';

  @override
  String get issueMissingSave =>
      'The save for this .json is missing (it may still be syncing)';

  @override
  String get issueMissingSidecar =>
      'The .json for this save is missing (it may still be syncing)';

  @override
  String get issueCorruptSidecar => 'Damaged or unreadable .json';

  @override
  String get issueSizeMismatch => 'Size does not match the .json';

  @override
  String get issueHashMismatch => 'Content does not match its SHA-256';

  @override
  String get issueUnreadable => 'Could not be read';

  @override
  String get looseTitle => 'Loose saves';

  @override
  String get looseDesc =>
      'Files copied into the folder by hand. Adopting them detects their game and files them in place with their .json.';

  @override
  String get adopt => 'Adopt';

  @override
  String get adoptAll => 'Adopt all';

  @override
  String adoptDone(String game) {
    return 'Adopted: $game';
  }

  @override
  String ignoredFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count files ignored (temporary, partial or cloud conflict copies).',
      one: '1 file ignored (temporary, partial or a cloud conflict copy).',
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
    return 'Pokémon icons: Pokémon HOME box icons from the Smogon / Pokémon Showdown sprite repository (github.com/smogon/sprites, commit $pokemonCommit). Items, Balls, types and ribbons: PKHeX resources (github.com/kwsch/PKHeX, commit $pkhexCommit). Downloaded on demand, never bundled. Sprites are © Nintendo / Game Freak / The Pokémon Company.';
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
}
