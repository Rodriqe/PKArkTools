# Changelog

All notable changes to this project. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). The first published
version is PKArkTools 0.1.0 (`0.1.0+1` in `apps/pkarktools/pubspec.yaml`); the
sections after it are the internal development milestones that led to it.

Versión en español: [CHANGELOG.es.md](CHANGELOG.es.md). The user and
developer documentation in `docs/` is in Spanish.

## [Unreleased]

### Added
- **Arca problems in Settings, folded into one line**: "3 problems in the
  Arca" with a severity icon, collapsed by default. Expanded, problems are
  grouped by kind with a count, a short plain-language explanation and the
  relative path of each file. The Arca tab shows at most a one-line notice
  that opens Settings; with no problems there is only a discreet check. See
  [The Ark › Arca problems](docs/usuario/arca.md#problemas-del-arca) (Spanish).
- **Fix** per file, per group or **Fix all** (with its own confirmation,
  progress and a "2 fixed, 1 quarantined" result): rebuilds a damaged or
  missing `.json` from its save, rebuilds the main file and `ultima.json`
  from the history, adopts loose saves and cloud conflict copies, removes
  copies whose exact content is already in the history and saves a main file
  changed by hand as a new copy. Nothing is deleted: anything that can't be
  repaired is moved to `PKArkTools/_cuarentena/` with a note, after checking
  it by SHA-256.
- **Ignore** per file or per group: hidden from the summary until the file
  changes (path + size + date), stored only in this device's settings;
  **Show ignored (N)** lists them to undo.

### Fixed
- Arks created while the app was still called PokeSavTool: their `.json`
  files (schema `pokesavtool-snapshot`) were all reported as damaged and the
  move to `historial/` failed on every reindex. They are now read as our own
  and rewritten with the current schema when migrated.
- Importing a folder that contains the Ark itself (for example `ROMs/Saves`)
  no longer re-imports every history copy as a new copy with today's date.
- Cloud conflict copies of history files (`… (1).sav`) were skipped silently;
  they are now listed so they can be removed or adopted. A copy whose SHA-256
  doesn't match, found while reading it, is now reported on reindex.

### Changed
- Settings no longer shows the long, always-expanded lists of issues, inbox
  saves, hand-edited main files and loose saves; they live in the folded
  summary above.

## [0.1.1] — 2026-11-23

The Ark folder now shows the latest version of each save under the name the
game uses, with the copies in `historial/`; 0.1.0 folders are migrated
automatically. Pokémon HOME icons for all 1025 species, and bigger.

### Added
- **Latest version in plain sight**: each trainer folder in the Ark holds the
  latest version's file under the name the game uses (`main` on Switch and
  3DS, `SaveData.bin` in BDSP, `savedata.bin` in Let's Go,
  `<Game>.sav`/`.dsv`/`.srm`… on GB, GBA and DS), a derived `ultima.json` and
  the immutable copies in `historial/`. The history is the source of truth:
  the main file is written atomically (also through SAF) and regenerated from
  it. See [The Ark › Inside the folder](docs/usuario/arca.md#la-carpeta-por-dentro)
  (Spanish).
- **Main file changed by hand**: detected on reindex (SHA-256 not in the
  history), never overwritten or deleted, and **Save as new copy** is
  offered.
- **Save details**: "Current version · date" highlighted with **Export**
  (with the game's file name) and **Open folder**; the history is collapsed
  below it. Ark settings explain the structure.
- **Per-game folders (optional)**: after choosing the folder the app asks once
  whether to create them (all, choose, or not now); also in **Settings ›
  Create game folders**, with a picker by generation, platform or the games
  you already have. Each one has a `LEEME.txt` saying which save to drop
  there.
- **Inbox**: a loose save in `PKArkTools/<Game>/` is validated, stored as a
  new copy of its trainer (becoming the latest version) and removed after
  verifying the hash; unreadable files or saves from another game stay put
  with a warning and **Move to <game>**.
- **Demo video**: 40-second demo video
  ([`docs/media/pkarktools-demo.mp4`](docs/media/pkarktools-demo.mp4)) with an
  animated preview at the top of the README. It is recorded on the headless
  Android emulator with synthetic saves
  (`integration_test/demo_video_test.dart`, `tool/record_demo_video.sh`) and
  edited with ffmpeg (`tool/make_demo_video.sh`), also in vertical and square
  Spanish versions for social media.
- **Gen 9 and Legends Z-A icons**: Pokémon now use the Pokémon HOME box icons
  from the Smogon / Pokémon Showdown sprite repository (`smogon/sprites`,
  pinned commit): all **1025 species** and 330 forms (regional, Paldean,
  Ogerpon, Urshifu, Alcremie, Vivillon…) with an explicit species-form → file
  mapping. Previously, species 906 onwards showed initials. Items, Balls,
  types and ribbons still come from PKHeX.

### Changed
- **Bigger icons**: each group's scale is computed from the non-transparent
  content of the whole set (92nd percentile) so it fills 88 % of the slot, the
  same for every icon in the group, without cropping or distortion;
  previously the whole canvas was scaled and the Pokémon took up ~40 %. Pixel
  art uses integer or nearest-neighbour scaling. See
  [before/after](docs/screenshots/iconos_antes_despues.png).
- Shiny: the new source has no shiny icons, so the badge and the golden border
  stay.
- "Download all icons" is now ~16 MB (2168 files); the previous version's
  cache is deleted automatically. Settings › About lists both sources.
- **Restore** creates a new "Restored" entry in the history and updates the
  latest version (the history is never rewritten); also writing to the
  original file is an option in the same dialog.
- **Automatic migration** of 0.1.0 folders: the loose `date_hash.*` copies
  move into `historial/`, verifying each SHA-256 before removing the original;
  idempotent and safe against interruptions. The root `README.txt` is
  updated.
- Cloud conflict copies of the main file (`main (1)`, `conflicted copy`) are
  removed if their content is already in the history.
- Local index (drift) at schema 4: without the unique `(save, sha256)`
  constraint.

### Known limitations
- Forms without their own HOME icon (new Legends Z-A megas, Terapagos's
  Terastal Form, Silvally types, Koraidon/Miraidon modes…) use the species
  icon.
- No shiny icons: a shiny Pokémon is marked with the golden border and the ✦
  badge.
- Those of 0.1.0 still apply (Legends Z-A and Create Pokémon, Windows/Linux
  validated in CI only, iPhone/iPad built from source).

## [0.1.0] — 2026-11-23

First published version. Downloads in
[Releases](https://github.com/Rodriqe/PKArkTools/releases/tag/v0.1.0): Android
APK, macOS app (zip, not notarized), Windows (installer and portable zip,
unsigned) and Linux (tar.gz); iPhone/iPad built from source. The Windows and
Linux builds have only been validated by compiling them in CI.

### What's included
- **Ark** of immutable, verified (SHA-256) copies in the folder you choose,
  multi-device through the cloud, with history, notes, compare, restore,
  export and full zip; filters, sorting and search.
- **Import** files or whole folders: GB/GBA/DS and Switch emulators (and
  their Android ports), cartridge dumps and Checkpoint/JKSM; detection by
  content.
- **Reading** of every main-series game from Red/Blue to Legends Z-A.
- **Editor** with draft and undo: Pokémon, boxes, trainer, inventory,
  Pokédex, events, ribbons and origin; standalone Pokémon `.pk1`…`.pa9`.
- **Legality** with PKHeX's rules and encounter tables and safe fixes;
  checksum diagnosis and repair.
- On-demand icons, per-version colours, light and dark themes, Spanish and
  English. Android, iOS/iPadOS, macOS, Windows and Linux.

### Added
- Releases from CI: on every `v*` tag, Android APK (signed with the keystore
  from GitHub secrets or, if there is none, with the debug key), macOS zip,
  Windows installer and zip and Linux tar.gz, in a draft Release with the
  notes from this CHANGELOG (`tool/release_notes.py`). Windows and Linux are
  also built on every push and pull request.
- Filters in the Ark tab, combinable and with a count per option:
  generation, console, origin (emulator, Android/iOS port, Checkpoint/JKSM,
  cartridge), game with its version colour, status (damage, legality, edited,
  several copies) and date of the latest copy; sort by recent, trainer, game,
  hours or copies. Bottom sheet on phones, side panel on desktop, removable
  chips, empty state and selection remembered per device.
- Open-source readiness: `CONTRIBUTING.md` (es/en), `CODE_OF_CONDUCT.md`,
  `SECURITY.md`, issue and PR templates, and `.github/workflows/ci.yml`
  (analysis and tests on Ubuntu; on `v*` tags, release APK and macOS app as a
  draft Release). README in English (`README.md`) and Spanish
  (`README.es.md`) with logo, features, games, screenshots and disclaimer.
- Full documentation in `docs/`: user guide, supported formats,
  architecture, development, data safety, licences and app store publishing
  audit.
- `tool/check_links.py`: checks links, anchors and images in the `.md` files
  (in `tool/ci.sh`).
- iOS Privacy Manifest (`PrivacyInfo.xcprivacy`), `CFBundleLocalizations`
  (es, en) on iOS and macOS, and `NSPhotoLibraryUsageDescription`.

### Fixed
- Legends Z-A: Pokémon made with "Create Pokémon" get a valid version, met
  level, met date and location, and obedience level (previously
  `DateCalendarInvalidMet` and `TransferObedienceLevel` in PKHeX), with
  warnings and a fix for those already saved; empty party slots are not
  rewritten; play time is read and written (previously 0:00:00); clear
  message if the save is from an unknown revision.
- Icons: downloads are validated (complete PNG with the size from the index),
  writes are atomic, transient failures get a second pass, and Settings shows
  how many are missing with a **Repair icons** button. Previously, empty or
  truncated icons could be left behind without warning.
- Icons with consistent proportions: each sprite is drawn with its original
  canvas at its group's scale (Pokémon, items, Balls, types, ribbons),
  without cropping or stretching; previously a Joltik looked as big as a
  Wailord.
- Legends Z-A: created or edited Pokémon (level, species, form or moves) get
  the "plus" move flags due for their level and learnset, like PKHeX (no
  `PlusMoveSufficientLevelMissing`), and impossible ones are removed. New
  legality warning with a fix for those already saved.
- Android release without the `INTERNET` permission: icons did not download
  in store builds.
- macOS sandbox without `network.client`: icons did not download in the
  signed app.
- `flutter build appbundle` failed with paths containing spaces
  (`apkanalyzer`); `tool/android_setup.sh` now patches it.

### Known limitations
- Legends Z-A: a Pokémon made with **Create Pokémon** may not match PKHeX's
  encounter tables (`EncInvalid`) even if the rest of its data is valid; the
  app does not invent a specific encounter.
- Windows and Linux have only been validated by building them in CI: nobody
  has tried them on a real PC yet.
- iPhone/iPad: no distribution (neither App Store nor TestFlight); the app has
  to be built from source with Xcode.

## Ribbons, icons, origin, colours and logo — 2026-11-22
### Added
- Gen 3–9 ribbons and marks in the editor (groups, filter, give/remove all,
  displayed ribbon) with legality warnings in the style of `RibbonVerifier`.
- On-demand icons (sprites) from PKHeX's resources on GitHub (pinned commit)
  with cache, limits, retries and offline fallback; Settings › Icons.
- Origin section: game, location, met level and date, egg, transfers and
  Ball, with valid pickers per game.
- Official per-version colours in the Ark (one colour or the pair on a
  diagonal); version inferred or set by hand.
- New logo on every platform, native splash screen and
  `tool/gen_branding.py`.
- Offscreen desktop screenshots with `flutter test` (a window is never
  opened).
### Fixed
- Shiny badge kept within the avatar's bounds.

## Mobile polish — 2026-11-22
### Added
- Phone layout: pill tabs, filters as chips, boxes with arrows and swipe,
  bottom sheets, full-screen editor, collapsing FAB; overflow-free tests at
  320×568, 360×800 and 430×932 at 100 % and 130 %.
- iPhone SE, iPhone 16 Pro and Android screenshots.
### Fixed
- Sun/Moon and Ultra Sun/Ultra Moon checksums: MemeCrypto signature of block
  36.

## Android — 2026-11-22
### Added
- Android environment inside the project (`tool/android_setup.sh`,
  `tool/android_env.sh`), optional build in `tool/ci.sh`.
- Smoke test on a headless emulator (`tool/android_smoke.sh`): real SAF
  picker, persistent permission, saving and reindexing through SAF.

## The Ark in a folder — 2026-11-22
### Added
- The Ark lives in a folder chosen by the user (save + `.json` per copy),
  multi-device through the cloud, rebuildable drift index, incremental
  reindexing, adoptable loose saves and tolerance of cloud conflicts.
- Persistent permissions: bookmarks on iOS/macOS, SAF on Android.
- Migration of the previous internal Ark and folder change with
  verification.

## Validation with real saves — 2026-11-22
### Added
- Differential oracle against PKHeX (`tools/pkhex_oracle`,
  `tool/compare_with_pkhex.sh`).
- Optional tests with real saves in `.ref/real-saves/`.
### Fixed
- Reading and legality aligned with PKHeX on real SoulSilver and Sword saves;
  Gen 3/4 legality without false positives; empty Gen 4+ slots handled like
  the game.

## Phase 4: complete Pokédex, events and legality — 2026-11-22
### Added
- Gen 6–9 Pokédex with regional Pokédexes, forms, gender and shiny.
- Named events in X/Y, ORAS, SM, USUM, Let's Go and BDSP.
- Encounter legality against PKHeX's tables (Gen 3–9).
- Balls per game (Hisuian ones included).
- Robustness: verified export, damaged saves read-only, mutation tests for
  the 22 formats.

## Phase 3: Pokédex, events, origin legality and bulk Ark — 2026-11-22
### Added
- Pokédex (Gen 1–5) and event editor (Gen 1–5, Gen 8–9).
- Origin legality with safe fixes.
- Bulk import with a summary, Ark as a zip with a manifest, and copy
  comparison.

## Phase 2: writing and editor — 2026-11-22
### Added
- Writing of Gen 1–9 saves and the `Pkm` entity (PK1–PK9, PB7, PB8, PA8,
  PA9).
- Editor with draft and undo: Pokémon, boxes, trainer and inventory; basic
  legality.
- Legends Arceus and Z-A inventory; Korean Gold/Silver.

## Phase 1: the Ark — 2026-11-22
### Added
- `pkcore`: detection and reading of Gen 1–9 saves with SwishCrypto.
- Flutter app: save Ark with import, details and history; SAF on Android;
  local CI.

## Start — 2026-11-21
- Initial commit.
