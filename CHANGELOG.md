# Changelog

All notable changes to this project. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). The first published
version is PKArkTools 0.1.0 (`0.1.0+1` in `apps/pkarktools/pubspec.yaml`); the
sections after it are the internal development milestones that led to it.

Versión en español: [CHANGELOG.es.md](CHANGELOG.es.md). The user and
developer documentation in `docs/` is in Spanish.

## [Unreleased]

## [2.0.0] — 2026-11-25

PKArkTools 2.0.0 brings four big additions: **Mystery Gift events and the
Living Dex**, **Pokémon transfer between saves** (a "local HOME" validated
against PKHeX), **tools** (Showdown, stat calculator, box sorting, Official
format and share card) and **Shadow Pokémon** for Colosseum and XD. The
macOS app is signed and notarized.

### Events and Living Dex

- **Mystery Gift events.** PKHeX's whole event database (2922 Pokémon gifts,
  Gen 3 to Gen 9: WC3/PCNY/PCJP, PCD/PGT, PGF, WC6, WC7, WB7, WC8, WB8, WA8,
  WC9, WA9), regenerated with `tool/gen_event_data.sh` and loaded lazily.
  - **Event explorer** (Dex → Events, and from each species page): search by
    species, card title, OT or card number and filter by game, generation,
    year, region, language, shiny and distribution type; each event card shows
    all its fixed data (OT/ID, moves, relearn moves, Ball, item, fixed IVs,
    nature, ribbons, dates) and can export the card file.
  - **Create from an event** (empty slot → “From an event”) in any compatible
    save: fixed data are kept and the receiving trainer's OT, ID, gender and
    language are applied as the game does, with PKHeX-valid PID/IV variants
    (Gen 3/4 RNG methods, Gen 5 shiny and ID-correlated PIDs, Z-A seeds).
    `tool/check_events_pkhex.sh` checks every creatable gift for two trainers
    with PKHeX: 0 invalid out of 5830.
  - **Import event cards** (.pgt, .pcd/.wc4, .pgf, .wc6/.wc6full,
    .wc7/.wc7full, .wb7, .wc8, .wb8, .wa8, .wc9, .wa9) and receive them in a
    slot.
  - **The event database updates itself.** A daily GitHub Action
    (`events-data.yml`) clones PKHeX's latest commit in the runner,
    regenerates `data/events/events.json`, validates it with
    `check_events_pkhex.sh` (a single invalid event, or a drop of more than
    10%, fails without committing) and commits it only when the events change.
    PKHeX fills templates at random, so unchanged events keep their previous
    entry. The explorer downloads it at most every 24 h, or with **Check for
    new events**, through a plain anonymous GET. It caches the file and falls
    back to the cache or the built-in copy. The screen shows "N events ·
    updated on <date> · PKHeX <commit>" and marks events that are new since
    the last view. Current data: PKHeX a5311f9 (2026-11-22), 0 invalid out of
    5830.
  - **Receive cards in the game's Mystery Gift tray** (X/Y, Omega Ruby/Alpha
    Sapphire, Sun/Moon, Ultra Sun/Ultra Moon): importing a WC6/WC7 card now
    offers to leave it as a received card to pick up in the game from the
    delivery person, like the original distribution (checked with PKHeX's
    oracle, command `gifts`). Gen 4/5 store cards encrypted with the rest of
    the block and Let's Go/Switch games keep no pending cards, so there the
    card is still received by creating the Pokémon in a slot.
  - **Dex and Ribbon Hunter**: legendaries/mythicals that no game gives
    without an event are marked “Event only · distribution ended”; event
    ribbons count as origin ribbons and are listed as not obtainable today.
  - **Legality** now recognizes Pokémon that come from an event (fixed OT/ID,
    Ball, place and level): their special moves, item and Ball no longer raise
    notices and the encounter tables are not applied.
- **Living Dex generator.** “Generate a Living Dex in this save” on the save
  sheet fills the boxes with one Pokémon of every species and form the game
  supports (regional forms and box-storable cosmetic forms included,
  battle-only forms, fusions and Totem/Noble Pokémon left out), in National
  Dex order, normal or shiny, with the save's OT, ID, gender and language.
  Each one comes from a real encounter of that version (hatched egg, static or
  wild, evolved at the lowest legal level) chosen by PKHeX
  (`tool/gen_living_dex_data.sh`, oracle command `livingdex`), or from an
  official event for mythicals/legendaries that only existed that way. Shiny
  only where the game allows it. It warns that the boxes are overwritten (the
  previous version stays in the Arca history) and what does not fit.
  `tool/check_living_dex_pkhex.sh` checks the full normal and shiny Living
  Dex of 16 games read back from the save: 0 invalid out of 16938.
  Covered forms include Furfrou's trims where they stay in a box (Sun/Moon,
  USUM; in X/Y and ORAS they revert to the base form when deposited, so only
  the base form is generated), 18 Vivillon patterns (Fancy and Poké Ball are
  event-only), female Meowstic in Gen 6-7, all 28 Unown in BDSP and BDSP trade
  evolutions (with the trade partner as handler). After saving, a summary
  lists everything not generated grouped by reason (battle-only form,
  fusion/Totem, reverts in the box, event only, needs another region, no
  encounter in this version, impossible shiny, did not fit). Known limits:
  seed-correlated encounters (some Gen 3-4 wild ones, SWSH symbols, Z-A) stay
  normal when shiny is asked; Let's Go mythicals are not included.

### Transfers

- **Transfer Pokémon…** (above the party, or ⋮ in a Pokémon's sheet): move
  (default) or copy one or several Pokémon to another save in the Ark, even
  from another generation. Pick the destination save and slot, review a
  preview (format route, moves, Ball, held item, ribbons, name, ability,
  level and legality at the destination) and confirm. Both saves are stored
  as new copies; the originals stay in the history.
- `PkTransfer` in pkcore, ported from PKHeX's `EntityConverter`: Time
  Capsule (Gen 1 ↔ 2), Virtual Console → Gen 7, Pal Park, Poké Transfer, Poké
  Transporter, Pokémon Bank and Pokémon HOME between Gen 7, Let's Go and the
  Switch games. Only real routes: forward only (both ways among Switch
  games), no eggs across formats, no unpurified Shadow Pokémon, species and
  forms must exist at the destination, Spinda/Nincada stay in BDSP.
- HOME tracker: generated locally (non-zero, unique, kept on later moves).
  A prominent notice, acknowledged once per device, explains that the app
  only guarantees continuity up to Alola and recommends not uploading these
  Pokémon to HOME; a "Take it to Alola and continue with Bank/HOME" option
  and a step-by-step guide offer the official route. Copying a Pokémon that
  has a tracker asks for explicit confirmation (it would be a clone);
  `HomeTrackerClones` finds repeated trackers.
- Validation: every generation hop is checked with the PKHeX oracle
  (`tool/transfer_oracle.sh`, legal synthetic sources generated from PKHeX
  encounter templates); all converted Pokémon are legal in PKHeX, and saves
  round-trip with valid checksums.
- **HOME clone detector** (Settings → HOME clones): looks through the latest
  copy of every save in the Ark for Pokémon that share a HOME tracker (copies
  of the same Pokémon) and shows the save and box of each one.
- Sword/Shield: the trainer who receives a Pokémon becomes its handler with
  the link-trade memory PKHeX expects (no MemoryMissingHT "Fishy" notice),
  also between two saves of Switch games.
- Poké Transfer drops contest scarves (never released in Gen 5) and on
  Switch the ♂/♀ symbols in names are stored as Unicode (Nidoran).
- Event and Living Dex Pokémon survive a transfer:
  `packages/pkcore/test/integration_test.dart` creates events and Living Dex
  Pokémon, transfers them and reads them back from the destination save;
  with the PKHeX oracle, 0 invalid out of 429. The Living Dex stays in
  National Dex order (sorting the boxes moves nothing) and the Official
  format checks it without legality warnings.

### Tools

- **Pokémon Showdown**: import one or more sets (species and form, nickname,
  gender, item, ability, level, shiny, nature, EVs/IVs, moves, Tera Type,
  happiness, Gigantamax, Hidden Power type) into the party or the boxes of the
  open save, with warnings for everything the game does not allow and the
  serious legality warnings; origin data Showdown does not carry is filled in
  with the checker's safe fixes. Export the party or a single Pokémon as
  Showdown text (copy or system share sheet).
- **Stat and IV calculator** in the Pokémon editor: final stats at level 50
  and 100, IV ranges from the stats you see in the game (with *Apply IVs*
  when they are exact) and Hidden Power type and power (Gen 2–7).
- **Sort boxes** by Dex number, type, generation, living dex (each species in
  its slot, duplicates after the last number), level or shiny first; all boxes
  or a range, with a preview and a single undo step.
- **Official format**: the current Pokémon Champions regulation (VGC 2026
  Reg M-C) with its rules, searchable allowed and banned lists, Mega
  Evolution marks and which Pokémon in your saves are eligible and why the
  others are not. Species list generated from Pokémon Showdown's `champions`
  mod (`tool/gen_champions_data.py`, versioned with commit and date);
  unconfirmed dates and the missing item list are flagged in the app.
- **Official format updates itself**: a daily GitHub Action
  (`champions-data.yml`) regenerates `data/champions/champions.json` from
  Showdown, validates it and commits it only when the data changes. When the
  screen opens (at most every 12 h, or with **Check for updates**), the app
  downloads it with a plain anonymous GET and caches it. Offline, it uses the
  cached copy or the one built into the app. The screen shows the update date
  and the Showdown commit, when the regulation ends and the next one (or "not
  announced yet"). Data with a newer schema is ignored with a hint to update
  the app. Regulation dates (M-A, M-B, M-C, unconfirmed) live in
  `tool/champions_regulations.json` with their source. Checked against
  Showdown's "Implement Champions National Dex" (#12488): the list is still
  the VGC Reg M-C one.
- **Share card**: an image of a Pokémon (app logo, icon, name and form, level,
  types, shiny, nature, ability, item, Tera Type, origin, ribbons, IVs/EVs and
  moves), saved as PNG or sent through the system share sheet.
- User guides: `herramientas.md`, `formato-oficial.md` and
  `instalar.md` (including iPhone/iPad with AltStore and the 7-day refresh).

### Shadow Pokémon

- **Create Shadow Pokémon in Colosseum and XD.** An empty slot offers
  “Shadow Pokémon”: pick one of the game's Shadow encounters (PKHeX
  `Encounters3ColoShadow` / `Encounters3XD`, without the Japanese e-Reader
  ones) and it is created as the game would snag it — species, level, moves,
  place, ball, your OT/ID, Colosseum/XD origin, XD fateful flag, Shadow ID and
  full heart gauge — already Shadow or purified with the National Ribbon. PID
  and IVs come from the GameCube RNG with seeds that respect the NPC trainer's
  team locks, so PKHeX accepts them. The editor can also turn any Pokémon of
  those games into a Shadow one, change its Shadow encounter, set the heart
  gauge and purify or revert it, with confirmation. In XD the Shadow table
  entry is filled (species, snagged, gauge) and the Strategy Memo records the
  species.
- Legality notices for Shadow Pokémon: Shadow ID that does not exist in the
  game, species that is never Shadow in that game, PID/IV not coming from the
  CXD generator and shiny Shadow Pokémon in XD.

### macOS signed and notarized

- **The macOS app is now signed and notarized.** The release is signed with
  Developer ID with the hardened runtime and notarized by Apple, so it opens
  with a double-click (no more right-click → Open). It also comes as a
  `PKArkTools-vX.Y.Z-macos.dmg`; the `-macos.zip` used by the in-app updater
  stays.

### Other changes

- The sidebar logo is much larger (96 px on the extended rail, 72 px on the
  compact one) with the name below it.
- Settings → About says PKArkTools is not affiliated with Nintendo, The
  Pokémon Company or Game Freak.
- In English the app says "Ark" everywhere (some texts still said "Arca").
- Every text of the tools lives in the `.arb` files (Spanish/English).
- Dipplin, Poltchageist and Sinistcha use the game's growth rates (the
  Artisan forms of the Scarlet/Violet Living Dex showed a level below their
  met level).
- The transfer preview shows legality in the app's language.
- Let's Go event Pokémon get a received date equal to their met date, as
  PKHeX expects (it failed for gifts created on a later day than the data).
- Let's Go (PB7) Pokémon checksum now covers the 0xE8 bytes PKHeX uses.
- The emulator integration prepared for this release (linked folders, "Open
  in…", launcher) was removed entirely: the app still reads and exports
  emulator saves as before.

### Known limits

- The Living Dex leaves seed-correlated encounters normal when shiny is asked
  (some Gen 3–4 wild ones, Sword/Shield symbols, Z-A); Let's Go mythicals are
  not included.
- Gen 4/5 store cards encrypted with the rest of the block and Let's Go and
  the Switch games keep no pending cards: there a gift is received by creating
  the Pokémon in a slot.
- The HOME tracker is generated by the app, not by HOME's servers: continuity
  is only guaranteed up to Alola; don't upload Pokémon transferred this way to
  HOME.
- The Windows and Linux builds are only checked by CI; there is no
  downloadable iPhone/iPad build.

## [1.1.0] — 2026-11-24

PKArkTools 1.1.0 brings two big additions: **Ribbon Hunter**, a per-species
ribbon guide validated against PKHeX (routes, ranking by tiers, guide export
and your own specimens), and six new games from the GameCube, Nintendo 64 and
Wii: **Pokémon Colosseum**, **Pokémon XD: Gale of Darkness**, **Pokémon
Stadium** and **Stadium 2**, **Pokémon Box: Ruby & Sapphire**, **Pokémon
Battle Revolution** and **My Pokémon Ranch**.

### Added — Ribbon Hunter
- **Ribbon Hunter** tab: a ribbon guide per species, not per specimen. Pick
  any species and form and see every ribbon one specimen can earn, game by
  game from Gen 3 to Gen 9 (the route to make it a Ribbon Master), with how
  to get each one, its requirement, the recommended (oldest possible) origin
  and the max obtainable today.
- Forward-only transfer graph with stable game ids: Colosseum and XD (traded
  to/from Ruby/Sapphire/Emerald and FireRed/LeafGreen), Pal Park, Poké
  Transfer, Poké Transporter/Bank, Virtual Console → Gen 7, HOME, and
  Let's Go/GO one-way into HOME. Notes tell you when to transfer, when a
  regional form first exists and when a game only takes the pre-evolution.
- National Ribbon (purifying a Shadow Pokémon) and Earth Ribbon (Mt. Battle)
  count as in-game ribbons from Colosseum/XD; Shadow Pokémon are valid
  origins.
- "Not available today" section (event ribbons and the closed Wi-Fi Battle
  Tower), marks shown apart (post-capture marks in Scarlet/Violet and one
  encounter mark if caught in Sword/Shield or Scarlet/Violet), and the Gen 3–4
  Contest/Battle Memory counts.
- **Ranking by tiers**: species and forms are grouped by the most ribbons they
  can earn ("87 ribbons · 33 species & forms", "86 ribbons · 107 species &
  forms"…), with every tier, sample icons and the common origin highlighted
  ("Shadow Pokémon in Colosseum / XD"). Opening a tier shows its full list,
  filterable and in Dex order, and each species opens its guide.
- "Your specimens of this species": ribbons each one has and the ones it can
  still earn from its current game. The Dex index now stores each specimen's
  ribbons (the index rebuilds once).
- Share a guide as text for forums or save it as an image.
- "Ribbon Hunter guide" button on every Dex species page.
- Verified against PKHeX: the PKHeX oracle builds every species/form from its
  best origin, transfers it forward and applies all valid ribbons; the app's
  routes match it with 0 contradictions across 1333 species and forms
  (`tool/gen_ribbon_master_data.sh`, versioned test table).

### Added — GameCube, Nintendo 64 and Wii games
- **Storage and stadium games**: Pokémon Stadium and Stadium 2 (Nintendo 64;
  international, Japanese and the original Japanese Stadium, including
  byte-swapped dumps), Pokémon Box: Ruby & Sapphire (GameCube `.gci`, Memory
  Card or headerless data), Pokémon Battle Revolution and My Pokémon Ranch
  (Wii, files from Dolphin's NAND). Content detection, full reading, writing
  with their checksums (per-box sums, Box block sums, Battle Revolution's
  Genius Sonority halves and bit-count sums, the Ranch SHA-1, counter and end
  marker), byte-for-byte round-trip and the original container kept
  (byte order, other Battle Revolution profiles). Stadium registered teams are
  shown read-only; Ranch slots above the ranch level capacity are locked.
- Loose `.sk2`, `.bk4` and `.rk4` Pokémon; BK4 is edited as PK4 without loss.
- Arca: Nintendo 64 and Wii platforms, colours for the five games, main file
  names (`PbrSaveData`, `pokemonranch.bin`, the original N64 extension) and
  game folder READMEs explaining how to get each save; box-only games show no
  empty Team section.
- **Pokémon Colosseum and Pokémon XD: Gale of Darkness (GameCube).** Saves are
  read and written from `.gci` files (Dolphin export or GCI folder), whole
  Memory Card images (`.raw`, `.gcp`, `.mci`) and headerless save data, with
  content detection of the game code (`GC6x`/`GXXx`) and region (USA, Europe,
  Japan). Trainer, party, boxes, bag (including XD discs and colognes),
  Strategy Memo and **Shadow Pokémon** (shadow ID, heart gauge, snagged and
  purified state) are read; writing redoes the SHA-1 chain cipher
  (Colosseum) or the Genius Sonority cipher (XD) and every checksum, verifies
  the export and keeps the container: the `.gci` header, or the card with
  only the save's blocks rewritten (following the block table, untouched
  directory). An unchanged save is written back byte for byte.
- Loose `.ck3`/`.xk3` Pokémon import and export; a `.pk3` from a GBA save can
  be placed in Colosseum/XD and is converted with the save's region.
- Pokémon editor: a **Shadow Pokémon** section with the state, shadow ID and
  heart gauge, and a confirmed *Mark as purified* action that also adds the
  National Ribbon.
- Arca: Colosseum and XD game folders with a README explaining what to
  export from Dolphin, version colours for both games, and the main file
  keeps the original `.gci`/`.raw` name. A Memory Card holding both games is
  imported as one `.gci` per game.
- Legality for Colosseum/XD origin: Shadow Pokémon, starters, gifts, trades
  and Poké Spots from PKHeX's tables (with location names), shadow ID vs
  species, heart gauge range, the National Ribbon exactly on purified Shadow
  Pokémon, XD's fateful-encounter flag, and Shadow Pokémon cannot leave the
  game until purified. Purified XD Pokémon moved to a GBA save get the same
  flags as an in-game trade.
- PKHeX oracle: `write` command, Memory Card images and shadow fields in the
  dump; `tool/gen_gc_data.py` and `packages/pkcore/tool/write_synthetic.dart`.

### Known limitations
- Colosseum/XD: the PID/IV correlation of the random number generator
  (Shadow Pokémon team locks) is not checked; a Memory Card holding both
  games is imported as two `.gci` files (an edited `.raw` is only rewritten
  when it holds a single Pokémon save); XD's Purifier and the Day Care are
  not edited.
- Stadium registered teams, the Stadium 2 mailbox, Battle Revolution
  profiles 2–4 (kept intact), battle passes and wardrobe, and Ranch Miis and
  toys are not edited. Stadium boxes are compact lists: emptying a slot moves
  the next ones up. Ranch slots above the ranch level capacity are locked.
- Stadium, Stadium 2, Box and the Ranch have no trainer of their own; they
  appear in the Ark as "STADIUM", "STADIUM 2", "BOX" or the ranch owner.
- Ribbon Hunter is a guide per species: event ribbons and the closed Wi-Fi
  Battle Tower are listed as not available today, and the routes are those
  PKHeX accepts, not every possible path.

### Fixed
- The fateful-encounter flag of Gen 3 Pokémon (PK3) is now read and can be
  set; it always read as off before.

## [1.0.4] — 2026-11-24

### Fixed
- Dex: a special form with its shiny variant unlocked now shows the shiny
  icon even when the normal variant is unlocked too. In 1.0.3 the card fell
  back to the normal icon unless only the shiny one was unlocked, so a
  Charizard Gigantamax (or any Mega, Primal, Ultra or Gigantamax form) with
  both variants looked non-shiny. It affected all 134 special forms whenever
  both variants were unlocked; the icon files, the manifest and the cache
  were already correct.

### Changed
- Special-form cards: each variant pill (Normal, Shiny) shows its own icon
  once unlocked, and a ✦ badge marks the card drawn shiny. If a form ever
  lacks a shiny icon in the source, the shiny variant uses the normal icon
  with the ✦ badge instead of passing silently as normal.
- Tests walk the 134 special forms × {normal, shiny}: distinct icons, in the
  manifest, in "Download all" / "Repair icons" and with their own cache file.
- New screenshots: Charizard Gigantamax normal and shiny side by side and
  shiny Mega Charizard X (desktop and Android); the icons guide lists the
  forms whose official shiny barely differs from the normal one.

## [1.0.3] — 2026-11-24

### Added
- Special forms have their own icon: all 34 Gigantamax forms (one per form
  for Toxtricity and Urshifu), all 49 Legends: Z-A and Mega Dimension Megas,
  plus the Gen 6/7 Megas, Primal Kyogre/Groudon and Ultra Necrozma, each with
  its shiny version. They come from other folders of the same pinned
  `smogon/sprites` commit (HOME box-icon dump, Pokémon Champions icons and
  HOME renders), still downloaded on demand. Silvally types and Terapagos'
  Terastal and Stellar forms get their own icon too.
- Dex: special-form cards (and their locked silhouettes) use the form's icon
  and show the shiny icon once the shiny variant is unlocked; "Your
  specimens" draws a Pokémon with the Gigantamax Factor as Gigantamax. A
  form with no icon keeps the species icon with a G / MEGA / P / ULTRA badge.

### Changed
- "Download all icons" is now ~22 MB (~2400 files); "Repair icons" covers
  the new ones. The icons guide lists the sources and the forms with no icon
  in any reliable source (Koraidon/Miraidon ride modes, Spiky-eared Pichu).
- Dex screenshots (desktop, phone, Android and iOS) show the new icons.

## [1.0.2] — 2026-11-23

### Changed
- Screenshots and demo refreshed: every image in the READMEs and `docs/`
  now shows 1.0 (Dex tab, large HOME icons, new logo, current version and
  folded history in the Ark, NAS and updates), and the demo video and its
  README preview include the Dex with an unlocked Gigantamax form.

### Fixed
- Save card overflow: with a full party, the Ark card overflowed by ~4 px in
  a 1000×700 window; the party icons now shrink to fit narrow cards.

## [1.0.1] — 2026-11-23

### Changed
- New app icon: bigger logo on the app's dark background. On every platform
  (Android adaptive, legacy and round icons, iOS, macOS, Windows and Linux)
  the full logo now fills ~84 % of the icon on the app's night blue
  (`#151927`), with no shadow; on Android it is as large as the 66 dp safe
  zone allows, so circle and squircle masks never crop it.
- Bigger logo inside the app: the logo is now cropped to its content and
  shown larger in the side bar (48 px tall), on the welcome screen (128 px on
  phones, 160 px on desktop) and in Settings › About (88 px).

## [1.0.0] — 2026-11-23

**PKArkTools 1.0: the official Ark.** This release adds the **Dex**, a global
Pokédex of every save in the Ark, and closes the 0.1.x series. Compared with
0.1.x, 1.0 brings, in one app for Android, iOS, macOS, Windows and Linux:
an Ark of immutable, versioned copies in a folder you choose (multi-device,
game folders as inbox, reindex, zip export); import from files, folders,
emulators and Checkpoint/JKSM; reading **and editing** of every generation
from Red/Blue to Scarlet/Violet and Legends: Z-A (Pokémon, boxes, trainer,
inventory, Pokédex, events, ribbons, origin); legality checks with safe fixes;
damaged-save detection and checksum repair; regional and alternate forms with
their own data; in-app updates; and now the Dex.

### Added
- **Dex tab** (next to Ark, Activity and Settings): the 1025 National Dex
  species filled in from **all saves**: silhouette (not registered), dimmed
  (seen), in colour (caught) and a ✦ badge when you own a shiny.
- **Progress**: caught, seen, shiny and unlocked forms, broken down by
  generation/region and by game (species available in that game vs. those
  registered in your saves of that game).
- **Species sheet** with objective data only (no Pokédex flavour text or
  official artwork): types, base stats, abilities (hidden included), gender
  ratio, the evolution family with methods (from PKHeX's evolution trees),
  collectable forms with their types and stats, games it appears in, **your
  records** (which saves have it seen or caught) and **your specimens** (game,
  trainer, nickname, level, shiny, form, Gigantamax Factor and slot), each
  one opening its save **at its box with the Pokémon highlighted**.
- **Unlockable special forms**, normal and shiny separately, from one rules
  table (`SpecialForms`) verified against PKHeX: Mega Evolutions per game
  (X/Y, ORAS, Sun/Moon, Ultra Sun/Ultra Moon, Let's Go and Legends: Z-A,
  including Z-A's new Megas and Mega Dimension), Primal Kyogre/Groudon, Ultra
  Necrozma (fused Necrozma in USUM) and Gigantamax (a specimen with the PK8
  Gigantamax Factor in Sword/Shield; one per form for Urshifu and
  Toxtricity). The activating stone or orb in that save's bag is shown as an
  indicator. Locked forms are silhouettes that explain how to unlock them;
  Eternamax is never unlocked. Rules: [Dex guide](docs/usuario/dex.md).
- **Filters and search**: caught, missing, seen only, shiny, forms to unlock,
  type, generation/region and game; search by name (Spanish or English,
  accent-insensitive) or number; sort by number or name.
- **Living dex** (Dex settings): a species counts as caught only if you own
  a specimen in a team or box, to see what you are really missing.

### Performance
- The Dex index is computed **in the background** when the Ark is reindexed
  or a save is imported, once per copy (by SHA-256), and cached in the local
  index (drift schema 5, `dex_scans`), incrementally. Opening the tab only
  crosses the cache: 50 synthetic saves (1,500 specimens) build, aggregate and
  filter in about 10 ms; scanning those 50 saves takes about 0.3 s, once.

### Fixed
- **♂/♀ and other symbols no longer show as a box** (Nidoran♂/♀, the gender
  selector, ★ items, ⌘ shortcuts, ⚠): the app bundles subsets of Noto Sans
  Symbols and Noto Sans Symbols 2 (SIL OFL 1.1) as a font fallback, so they
  render the same on Android, iOS, macOS, Windows, Linux and in screenshots. A
  test checks that every character of the species, form, move, ability, item,
  location, ribbon and event names (es/en) has a glyph. The Gen 5+ placeholder
  location «－－－» now reads "an unknown place".

### Development
- pkcore: `GlobalDex`, `SaveDexScan`, `SpecialForms`, `DexForms` and
  `Evolutions`; the PKHeX oracle dumps the Mega/Primal/Ultra/Gigantamax table
  and the evolution trees (`tool/gen_dex_tables.sh`).
- Tests for the unlock rules (Gigantamax with the factor in SwSh, normal and
  shiny; Megas per game with the stone; Z-A; nothing outside valid games;
  eggs), several saves crossed, living dex, filters, performance and layouts
  at 320×568, 360×800, 430×932 and desktop.

## [0.1.5] — 2026-11-23

Regional and alternate forms use their own data instead of the base
species': Hisuian Decidueye is Grass/Fighting, not Grass/Ghost. This is the
first release the app can install with its own **Check for updates** button.

### Fixed
- **Types, base stats and abilities of forms** (Alola, Galar, Hisui, Paldea,
  Paldean Tauros, Rotom, Oricorio, Lycanroc, Urshifu, Calyrex, Necrozma,
  Kyurem, Deoxys, Giratina, Shaymin, the Forces of Nature, Meloetta, Hoopa,
  Zygarde, Ogerpon, Basculegion, Wormadam, Castform, Megas in Let's Go and
  Z-A…): the type chips in the party, boxes, summary, editor, Pokédex,
  comparison and save cards, the calculated stats and the abilities now come
  from the form's personal data **in the save's game**, including types that
  changed between generations (Gardevoir or Snubbull are not Fairy in Gen 3).
- **Legality by form**: learnable moves follow the form's evolution chain
  (Alolan Sandslash learns what Alolan Sandshrew learns), encounters must match
  the form (a Hisuian Growlithe does not come from a Kanto Growlithe slot),
  abilities are checked against the form's, and a form that does not exist in
  the game is flagged (regular Decidueye in Legends: Arceus).
- The species list no longer offers form entries as species in some games
  (e.g. "species" 494+ in Diamond/Pearl), and species that only exist as a
  regional form (Growlithe in Legends: Arceus) are available.
- New Pokémon get the form's learnset, abilities and gender, and in Scarlet
  and Violet a Tera Type matching the form's first type (Ogerpon: its mask's).

### Added
- **Form names**: "Decidueye (Hisui)", "Rotom (Wash)", "Tauros (Paldea
  Blaze)" in the summary, party, boxes, legality messages and comparison. The
  editor's **Form** selector lists the forms present in the game by name and
  updates types, stats, ability, gender and (Ogerpon) Tera Type when changed.
  The Pokédex names the forms seen and shows each entry with its form.
- Save cards remember the party's forms (older entries show the base form
  until the save is reindexed).

### Development
- `SpeciesForms` in pkcore: types, base stats, abilities, gender, presence,
  names and pre-evolutions by (species, form, game).
- The PKHeX oracle has a `forms` command; `tool/gen_form_data.sh` generates the
  form names and a versioned table of **11,888** (game, species, form)
  combinations from every Gen 3–9 game, which `form_data_pkhex_test.dart`
  compares with pkcore: types, base stats, abilities, gender, presence and
  pre-evolution, 0 differences.

## [0.1.4] — 2026-11-23

PKArkTools can check for new versions and update itself: on Android it
downloads the APK, checks it is signed with the same certificate as the
installed app and opens the system installer; on desktop it downloads the
release file where you choose; on iOS it opens the release page.

### Added
- **Check for updates** in Settings › About, with the installed version, and
  **Check for updates automatically** (on by default): on startup at most once
  every 24 hours. The only new connection is
  `api.github.com/repos/Rodriqe/PKArkTools/releases/latest`, without a token,
  with the stored ETag (an unchanged answer is a 304 and doesn't count against
  GitHub's limit). Automatic checks fail silently; the button explains why a
  check failed (no network, GitHub's rate limit).
- **Update notice**: a discreet card at the top of Settings and a dot on the
  Settings icon, "PKArkTools 0.1.x available". It opens a sheet with the
  release notes and **Update** and **Skip this version**.
- **Android**: downloads the APK with progress and cancel, checks its size
  and that its package name and signing certificates (SHA-256) match the
  installed app's before handing it to the system installer; if they don't,
  nothing is installed and the app says why. It takes you to "Install unknown
  apps" with an explanation the first time. The APK is deleted after
  installing or cancelling. New permission: `REQUEST_INSTALL_PACKAGES`.
- **macOS, Windows and Linux**: downloads the release zip, installer or
  tar.gz with a Save dialog that starts in Downloads and explains the manual
  step; **Open the release page** is always there. **iOS** opens the release
  page.
- Downloads only follow HTTPS links to this repository on GitHub's domains,
  every redirect included. See
  [Getting started › Updating the app](docs/usuario/primeros-pasos.md#7-actualizar-la-app)
  and [Data security](docs/seguridad-datos.md) (Spanish).

## [0.1.3] — 2026-11-23

The Ark can live in a network folder (NAS): on a Mac with an SMB share
(also AFP/NFS/WebDAV) and on Android through an SMB documents provider.
The app detects the share, says clearly when it is not mounted instead of
treating it as an empty Ark, polls for other devices' changes while open,
retries transient network errors and handles accented names the way macOS
SMB returns them. Tested on a real SMB NAS from a Mac; **Android over
SMB/SAF has not been tested on a device yet**.

### Added
- **Ark in a network folder (NAS)** on macOS (SMB, also AFP/NFS/WebDAV) and
  Android (SAF with an SMB documents provider). The folder is detected as a
  network folder (mount table via `getfsstat`, never blocking on an
  unresponsive server) and Settings shows "Network folder (NAS) ·
  NAS/Share" with a network icon. See
  [Getting started › On a NAS](docs/usuario/primeros-pasos.md#en-un-nas-carpeta-de-red) (Spanish).
- **"Network folder unavailable"** screen with **Retry** and **Choose
  another** when the share is not mounted; retried automatically when the
  app comes back to the foreground.
- Network folders are re-indexed every 60 s while the app is in the
  foreground (FSEvents does not see other machines' changes on SMB), never
  overlapping and spaced out if the network is slow.
- Progress dialog ("Importing N of M") for large imports.

### Fixed
- Settings › About showed version 0.1.0 instead of the installed version.
- Folder names that macOS returns decomposed (NFD) on SMB/AFP volumes
  ("Pokémon") no longer make every re-index drop and re-add all copies and
  rewrite the main files.
- On macOS SMB shares, a file with an accented name ("Pokémon") is found even
  when the share only answers to its decomposed spelling (seen on a real NAS
  after a folder is listed): it is no longer reported missing, and creating it
  again can no longer replace the existing copy.
- The app never writes into an unmounted share: a stale local
  `/Volumes/<share>` folder is detected and the root folder is never created.
- Choosing a folder that already contains `PKArkTools/` (or the
  `PKArkTools` folder itself, even without its README) never nests a second
  `PKArkTools/`.

### Changed
- Network folders: transient errors (EAGAIN, ETIMEDOUT, ESTALE, a momentary
  ENOENT…) are retried with backoff and every operation has a time limit;
  replacing a main file falls back to set-aside + rename on servers that do
  not replace on rename.
- NAS and OS system files (`._*` AppleDouble, `.DS_Store`, `@eaDir`,
  `#recycle`, `@Recycle`, `.snapshot`, `$RECYCLE.BIN`, `Thumbs.db`…) are
  ignored and those folders are not even walked; listing stats files in
  parallel.
- Existing folders are reused regardless of letter case (SMB is case
  insensitive), also on Android.

## [0.1.2] — 2026-11-23

Problems in the Ark folder are folded into one line in Settings and can be
fixed or ignored there. Arks created under the app's previous name are read correctly
again.

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
- **Duplicate copies in the history** (same SHA-256 in the same trainer
  folder, for example after importing a folder that contained the Ark): Fix
  keeps the oldest copy and moves the others, with their `.json`, to
  `PKArkTools/_cuarentena/duplicados/` with a note. Restored copies don't
  count, since they repeat content on purpose.
- **Ignore** per file or per group: hidden from the summary until the file
  changes (path + size + date), stored only in this device's settings;
  **Show ignored (N)** lists them to undo.

### Fixed
- Arks created while the app still had its previous name: their `.json`
  files (schema `<previous name>-snapshot`) were all reported as damaged and the
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
