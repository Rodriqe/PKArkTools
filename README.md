<p align="center">
  <img src="apps/pkarktools/assets/branding/logo_256.png" width="160" alt="PKArkTools logo">
</p>

<h1 align="center">PKArkTools</h1>

<p align="center">
  <b>The Ark for your game saves: versioned backups, a reader and an editor for every generation, on every device.</b>
</p>

<p align="center">
  <a href="docs/media/pkarktools-demo.mp4"><img src="docs/media/pkarktools-demo.webp" width="600" alt="Animated preview: the Ark with version colours, filters and a save with its party and boxes"></a><br>
  <sub>▶ <a href="docs/media/pkarktools-demo.mp4">Watch the full demo (49 s, MP4)</a> · <a href="#demo">what it shows</a></sub>
</p>

<p align="center">
  <a href="https://github.com/Rodriqe/PKArkTools/actions/workflows/ci.yml"><img src="https://github.com/Rodriqe/PKArkTools/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue.svg" alt="License: GPL-3.0"></a>
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-lightgrey" alt="Platforms">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter" alt="Flutter 3.47"></a>
</p>

<p align="center">
  <b>English</b> · <a href="README.es.md">Español</a>
</p>

> [!IMPORTANT]
> **Disclaimer.** PKArkTools is an unofficial, non-commercial **fan project**.
> **PKArkTools is not affiliated with Nintendo, The Pokémon Company or Game
> Freak**, nor endorsed or sponsored by them or Creatures Inc. Pokémon and all related names are
> trademarks of their respective owners. The app and this repository include
> **no ROMs, BIOS, console keys or sprites** (icons are optionally downloaded
> on demand, see [Icons](docs/usuario/iconos.md)). Use it **only with your own
> saves**, made from games you own.

<p align="center">
  <img src="docs/screenshots/v2/mac_02_arca_colores.png" width="100%" alt="The Ark on macOS">
</p>

## What is it?

Every save you import goes into **the Ark** (*el Arca*): a folder **you**
choose, where each copy is stored **immutable and versioned**, next to a
readable `.json` with its game, trainer, date and SHA-256. The original file
is never touched. From there you can browse the history of each playthrough,
compare copies, read and edit everything inside a save, and export a verified
file back to your console or emulator.

No accounts, no servers, no telemetry: put the Ark in iCloud Drive, Google
Drive, OneDrive, Dropbox or Syncthing and all your devices share it.

## New in 2.0

<p align="center">
  <img src="docs/screenshots/v2.0/07_transfer.png" width="100%" alt="Transfer Pokémon from Ultra Sun to Scarlet, with the HOME notice and the Take it to Alola option">
</p>

**Transfer Pokémon between saves.** A "local HOME": move (default) or copy
Pokémon from one save in the Ark to another, even across generations,
following the real rules of the Time Capsule, Pal Park, Poké Transfer, Poké
Transporter, Pokémon Bank and Pokémon HOME, with a preview of what changes and
the legality at the destination (every hop is validated against PKHeX). The
app can only guarantee continuity **up to Alola** (Gen 7): beyond that, the
HOME tracker is generated locally by the app, not by HOME's servers, so we
recommend not uploading those Pokémon to HOME. The recommended route to
Switch: transfer with the app to Sun/Moon or Ultra Sun/Ultra Moon (**Take it
to Alola and continue with Bank/HOME**), then use the official Pokémon Bank →
Pokémon HOME. A **HOME clone detector** (Settings) finds Pokémon that share a
tracker. [Transfer guide (Spanish)](docs/usuario/transferir.md).

| Events | Create from an event | Living Dex |
|---|---|---|
| <img src="docs/screenshots/v2.0/01_events_explorer.png" alt="Mystery Gift event explorer"> | <img src="docs/screenshots/v2.0/02_create_from_event.png" alt="Create Zeraora from its HOME gift"> | <img src="docs/screenshots/v2.0/06_living_dex_summary.png" alt="Living Dex summary: what was not generated and why"> |

**Mystery Gift events and the Living Dex.** PKHeX's whole event database
(2922 gifts, Gen 3 to 9) with filters by game, generation, year, region,
language, shiny and distribution; create any event Pokémon in a compatible
save with your trainer data (0 invalid out of 5830 in PKHeX) and receive
WC6/WC7 cards in the game's tray. **Generate a Living Dex in this save**:
normal or shiny, one legal Pokémon of every species and form from a real
encounter of that version, with your OT/ID, a warning before overwriting the
boxes and a summary of the forms left out and why (0 invalid out of 16938 in
PKHeX). Event and Living Dex Pokémon survive transfers.
[Events](docs/usuario/eventos.md) · [Living Dex](docs/usuario/living-dex.md).

| Official format | Stat calculator | Share card |
|---|---|---|
| <img src="docs/screenshots/v2.0/08_official_format.png" alt="Official format: Pokémon Champions regulation"> | <img src="docs/screenshots/v2.0/09_stat_calculator.png" alt="Stat and IV calculator"> | <img src="docs/screenshots/v2.0/11_share_card.png" alt="Share card"> |

**Tools.** Import and export **Pokémon Showdown** text, a **stat and IV
calculator** with Hidden Power, **sort boxes** (Dex, type, generation, living
dex, level, shiny) with a preview and one undo, the **Official format**
(current Pokémon Champions regulation and which of your Pokémon are eligible)
and a **share card** image. [Tools guide](docs/usuario/herramientas.md).

**Shadow Pokémon** in Colosseum and XD: create them as the game would snag
them (PID/IV from the GameCube RNG respecting team locks), change the heart
gauge, purify or revert them. **macOS** builds are signed with Developer ID
and notarized by Apple.

## New in 1.1: Ribbon Hunter

<p align="center">
  <img src="docs/screenshots/ribbons/03_guide_bulbasaur.png" width="100%" alt="Ribbon Hunter: Bulbasaur's route from FireRed/LeafGreen to Scarlet/Violet">
</p>

A **ribbon guide for every species**: pick any Pokémon (species and form) and
see **every ribbon a single specimen can earn**, game by game, from its oldest
possible origin (Pokémon XD and Colosseum included) to Scarlet/Violet (the
route to make it a **Ribbon Master**): how to
get each one in a line, its requirement, when to transfer (Pal Park, Bank and
HOME are one-way), when a regional form appears, what isn't available today
(events, closed online services) and which marks it can carry. A **ranking by
tiers** groups the species by the most ribbons they can earn (open a tier to
see them all),
your own specimens show what they're still missing, and the guide can be
copied as text for forums or saved as an image. Every species/form's route is
checked against PKHeX's ribbon verifier: **0 contradictions** across 1333
species and forms. [Ribbon Hunter guide](docs/usuario/ribbon-hunter.md).

## New in 1.1: GameCube, Nintendo 64 and Wii games

<p align="center">
  <img src="docs/screenshots/gamecube/03_xd_shadow_pokemon.png" width="100%" alt="Pokémon XD: a Shadow Pokémon with its shadow ID and heart gauge">
</p>

**Pokémon Colosseum** and **Pokémon XD: Gale of Darkness** (`.gci` from
Dolphin or whole Memory Card images) are read and written with their Shadow
Pokémon (shadow ID, heart gauge, *Mark as purified* with the National
Ribbon), Strategy Memo and bag. The storage games join them: **Pokémon
Stadium** and **Stadium 2** (N64), **Pokémon Box: Ruby & Sapphire**
(GameCube), **Pokémon Battle Revolution** and **My Pokémon Ranch** (Wii).
Every specimen in them shows up in the Dex and in Ribbon Hunter's "Your
specimens": a purified Pokémon already counts its National Ribbon. How to
export each save: [import guide](docs/usuario/importar.md); known limits:
[formats](docs/formatos.md#limitaciones-conocidas).

## New in 1.0: the Dex

<p align="center">
  <img src="docs/screenshots/dex/02_species_charizard.png" width="100%" alt="Dex: Charizard with its Mega Evolutions and Gigantamax unlocked">
</p>

A **global Pokédex of all your saves**: the 1025 species fill in with
everything registered or caught in any game of the Ark (silhouette, seen,
caught, ✦ shiny). Each species has an objective data sheet (types, base
stats, abilities, gender ratio, evolution methods, forms, games), where you
have seen or caught it, and **every specimen you own**, one tap away from its
box. **Mega Evolutions, Gigantamax, Primal Reversion and Ultra Necrozma**
unlock — normal and shiny separately — only with a specimen that enables them
in a game where they exist (a shiny Charizard with the Gigantamax Factor in
Sword unlocks shiny Gigantamax Charizard). Progress by generation, region and
game, filters, search and an optional **living dex**. Indexed in the
background and cached, it opens instantly. [Dex guide](docs/usuario/dex.md).

## Features

**Ark and versioned backups**
* One folder per playthrough with the **latest version on top**, named the way
  the game expects (`main`, `SaveData.bin`, `Emerald.sav`…) and ready to copy
  back, plus a `historial/` of immutable copies (`date_time_hash.sav`),
  deduplicated by SHA-256 and verified on every read.
* Optional **game folders** that double as an inbox: drop a save in
  `PKArkTools/<Game>/` and it is filed under its trainer automatically.
* History per playthrough with origin (file, folder, editor, demo), notes and
  a "latest" marker; restore or export any copy; activity log.
* **Compare copies**: what changed between two snapshots — trainer, Pokémon
  added, removed, changed (field by field) or moved, inventory and Pokédex.
* Export / restore the whole Ark as a **zip** with a manifest.

**Your own folder, multi-device**
* The Ark lives in a folder you pick (or the app's local folder), with
  persistent access on every platform (security-scoped bookmarks on
  Apple, Storage Access Framework on Android).
* Several devices can write to the same synced folder: unique file names,
  conflict copies and cloud placeholders are detected, the index is rebuilt
  from the folder at any time (*Reindex*), and loose saves you copy in by hand
  are offered for adoption.

**Import from anywhere**
* Single files or whole folders (bulk import with a summary first): GB/GBA/DS
  emulators (raw `.sav`/`.srm`, DeSmuME `.dsv`, RTC footers), Switch emulators
  (Yuzu/Eden/Sudachi/Citron, Ryujinx) and their Android ports, Dolphin
  (`.gci` and Memory Card images for Colosseum/XD), cartridge dumps
  and **Checkpoint / JKSM** backups ([import guide](docs/usuario/importar.md)).
* Detection by content (size, structure, checksums), never by extension;
  ROMs, keys and other files are ignored without being opened.

**Reading — all generations**
* Every main-series game from Red/Blue to Legends: Z-A: trainer, party, boxes,
  play time, money, badges, checksum status.
* GameCube, N64 and Wii: Colosseum and XD (Shadow Pokémon, Strategy Memo),
  Stadium 1/2, Box: Ruby & Sapphire, Battle Revolution and My Pokémon Ranch.

**Editor**
* Draft with undo/redo; nothing is written until you **Save to the Ark**
  (a new copy) or **export** (re-read and verified before writing).
* **Pokémon**: species and form, nickname, level/EXP, nature (and mint), ability,
  held item, moves and PP, IVs/EVs (AVs, GVs) with presets, shiny (PID/EC
  regenerated), gender, friendship, Ball, OT/TID/SID, language, tera type;
  live stats.
* **Boxes** with drag & drop, **trainer**, **inventory**, **Pokédex** (seen /
  caught / gender / shiny / forms), **events** with names, **ribbons and
  marks**, **origin** (game, location, date, OT).
* Loose Pokémon files `.pk1` … `.pk9`, `.pb7`, `.pb8`, `.pa8`, `.pa9`.

**Events, Living Dex and transfers**
* Mystery Gift event explorer and **create from an event**; import and
  export cards; receive WC6/WC7 cards in the game's tray.
* **Living Dex** in the current save (normal or shiny).
* **Transfer Pokémon** between saves of any generation (move or copy),
  with a legality preview and a HOME clone detector.

**Tools**
* Pokémon Showdown import/export, stat and IV calculator, box sorting,
  Official format (Pokémon Champions) and share card.
* Shadow Pokémon for Colosseum and XD.

**Legality**
* Warnings ported from PKHeX.Core's rules and encounter tables (moves, stats,
  abilities, Balls, shiny locks, encounter location and level), with
  explanations and "try to fix".

**Damaged saves**
* Checksum diagnosis per block and **repair checksums** on export
  ([guide](docs/usuario/reparar-checksums.md)).

**Look and feel**
* Species, item, Ball and ribbon **icons downloaded on demand** (optional,
  cached, resumable) — the only network access the app makes.
* Cards coloured **per game version** (pairs shown on a diagonal), light and
  dark themes, Spanish and English.

## Supported games

| Games | Platform | Read | Write | Extras |
|---|---|:-:|:-:|---|
| Red / Blue / Yellow (intl. & JP) | Game Boy | ✅ | ✅ | Pokédex, inventory + PC, raw events, `.pk1` |
| Gold / Silver / Crystal (intl., JP, KR) | Game Boy Color | ✅ | ✅ | Pokédex, named events, `.pk2` |
| Ruby / Sapphire, Emerald, FireRed / LeafGreen | GBA | ✅ | ✅ | Pokédex, events, ribbons, wild encounters, `.pk3` |
| Colosseum, XD: Gale of Darkness | GameCube | ✅ | ✅ | Shadow Pokémon, Strategy Memo, bag, encounters, `.gci` / Memory Card, `.ck3`/`.xk3` |
| Stadium, Stadium 2 | Nintendo 64 | ✅ | ✅ | boxes, registered teams (read-only), `.pk1`/`.sk2` |
| Box: Ruby & Sapphire | GameCube | ✅ | ✅ | 1500 storage slots, `.gci` / Memory Card |
| Battle Revolution, My Pokémon Ranch | Wii | ✅ | ✅ | party and boxes (BR), ranch boxes, `.bk4`/`.rk4` |
| Diamond / Pearl, Platinum, HeartGold / SoulSilver | DS | ✅ | ✅ | Pokédex + gender, events, ribbons, full encounter legality, `.pk4` |
| Black / White, Black 2 / White 2 | DS | ✅ | ✅ | Pokédex + gender/shiny, events, ribbons, encounters, `.pk5` |
| X / Y, Omega Ruby / Alpha Sapphire | 3DS | ✅ | ✅ | Pokédex with forms, events, ribbons, encounters, `.pk6` |
| Sun / Moon, Ultra Sun / Ultra Moon | 3DS | ✅ | ✅ + MemeCrypto | Pokédex, events, ribbons, encounters, `.pk7` |
| Let's Go, Pikachu! / Eevee! | Switch | ✅ | ✅ + AVs | Pokédex, events, `.pb7` |
| Sword / Shield | Switch | ✅ | ✅ | Galar + DLC Pokédex, named blocks, ribbons & marks, `.pk8` |
| Brilliant Diamond / Shining Pearl | Switch | ✅ | ✅ | Pokédex with forms, events, ribbons, `.pb8` |
| Legends: Arceus | Switch | ✅ | ✅ + GVs | Hisui Pokédex by form, named blocks, `.pa8` |
| Scarlet / Violet | Switch | ✅ | ✅ + tera type | Paldea, Kitakami, Blueberry Pokédex, `.pk9` |
| Legends: Z-A | Switch | ✅ | ✅ | Lumiose & Hyperspace Pokédex, `.pa9` |

New in 2.0, per game: **Living Dex** in every main-series game from Red/Blue
to Legends: Z-A; **create from an event** in Gen 3–9 (Let's Go, Legends:
Arceus and Z-A included); **transfer** between all of them along the real
routes (Colosseum/XD only send purified Pokémon; Z-A only receives); **Shadow
Pokémon** creation in Colosseum and XD.

Details, containers and known limits: [docs/formatos.md](docs/formatos.md).

## Demo

[**Watch the demo video**](docs/media/pkarktools-demo.mp4) (49 s, 1080p, no
audio), recorded on an Android emulator with synthetic saves: the welcome
screen, the Ark with a colour for every version, filters, a save with its party
and boxes, the Pokémon editor (level, shiny, moves), origin and ribbons,
legality warnings with safe fixes, and saving a new copy to the Ark to compare
it with the previous one. The animated preview above is the first 12 seconds.

The video is rebuilt from the recordings with `tool/record_demo_video.sh` and
`tool/make_demo_video.sh` (see [Development](docs/desarrollo.md#vídeo-de-demostración)).

## Screenshots

| Desktop | | |
|---|---|---|
| <img src="docs/screenshots/ribbons/02_ranking.png" alt="Ribbon Hunter ranking by tiers"> | <img src="docs/screenshots/ribbons/04_guide_alolan_raichu.png" alt="Ribbon Hunter: Alolan Raichu"> | <img src="docs/screenshots/ribbons/06_guide_shadow_origin.png" alt="Ribbon Hunter: Shadow Pokémon origin"> |
| <img src="docs/screenshots/gamecube/02_xd_save.png" alt="Pokémon XD save"> | <img src="docs/screenshots/gamecube/06_ribbon_hunter_purified.png" alt="Ribbon Hunter: purified Colosseum specimen with the National Ribbon"> | <img src="docs/screenshots/storage/06_battle_revolution.png" alt="Pokémon Battle Revolution"> |
| <img src="docs/screenshots/dex/01_grid.png" alt="Dex grid"> | <img src="docs/screenshots/dex/03_locked_forms.png" alt="Dex: locked special forms"> | <img src="docs/screenshots/dex/05_progress.png" alt="Dex progress"> |
| <img src="docs/screenshots/v2/mac_03_arca_colores_pareja.png" alt="Ark with version colours"> | <img src="docs/screenshots/v2/mac_04_cajas_iconos.png" alt="Boxes"> | <img src="docs/screenshots/v2/mac_05_ficha_iconos.png" alt="Pokémon editor"> |
| <img src="docs/screenshots/v2/mac_07_cintas.png" alt="Ribbons"> | <img src="docs/screenshots/20_legalidad_detallada.png" alt="Legality"> | <img src="docs/screenshots/22_comparar_copias.png" alt="Compare copies"> |
| <img src="docs/screenshots/24_pokedex_switch.png" alt="Pokédex"> | <img src="docs/screenshots/21_importacion_masiva.png" alt="Bulk import"> | <img src="docs/screenshots/v2/mac_01_onboarding_logo.png" alt="Choose your folder"> |
| <img src="docs/screenshots/v2/mac_09_arca_filtros.png" alt="Ark filters"> | <img src="docs/screenshots/android/v2_09_filtros_hoja.png" alt="Android: filters sheet"> | <img src="docs/screenshots/ios/v2_pro_10_arca_filtrada.png" alt="iPhone: filtered Ark"> |

| iPhone | | | Android | | |
|---|---|---|---|---|---|
| <img src="docs/screenshots/ios/v2_pro_02_arca_colores.png" alt="iPhone: Ark"> | <img src="docs/screenshots/ios/v2_pro_05_ficha_iconos.png" alt="iPhone: Pokémon"> | <img src="docs/screenshots/ios/v2_pro_06_origen.png" alt="iPhone: origin"> | <img src="docs/screenshots/android/v2_02_arca_colores.png" alt="Android: Ark"> | <img src="docs/screenshots/android/v2_04_cajas_iconos.png" alt="Android: boxes"> | <img src="docs/screenshots/android/v2_07_cintas.png" alt="Android: ribbons"> |

| Android 2.0 | | | | | |
|---|---|---|---|---|---|
| <img src="docs/screenshots/android/v2.0_03_living_dex_button.png" alt="Android: living dex button"> | <img src="docs/screenshots/android/v2.0_06_living_dex_summary.png" alt="Android: living dex summary"> | <img src="docs/screenshots/android/v2.0_07_transfer.png" alt="Android: transfer"> | <img src="docs/screenshots/android/v2.0_02_create_from_event.png" alt="Android: create from event"> | <img src="docs/screenshots/android/v2.0_09_stat_calculator.png" alt="Android: stat calculator"> | <img src="docs/screenshots/android/v2.0_11_share_card.png" alt="Android: share card"> |

| App icon | |
|---|---|
| <img src="docs/screenshots/v2/mac_00_icono.png" width="160" alt="macOS icon"> | <img src="docs/screenshots/android/v2_09_lanzador.png" width="160" alt="Android launcher"> |

All screenshots use synthetic saves.

## Install

The current version is **v2.0.0**. Download it from the
[latest release](https://github.com/Rodriqe/PKArkTools/releases/latest)
([all releases](https://github.com/Rodriqe/PKArkTools/releases),
[changelog](CHANGELOG.md)).

| Platform | How |
|---|---|
| Android | `PKArkTools-v2.0.0.apk`: open it on the phone and allow installing from that source when Android asks. |
| macOS | `PKArkTools-v2.0.0-macos.dmg`: open it and drag PKArkTools to Applications. It is signed and notarized by Apple, so it opens with a double-click (if a build ever ships without notarization, the release notes say so: then **right-click → Open** the first time). |
| iPhone / iPad | `PKArkTools-vX.Y.Z-ios-unsigned.ipa`, installed with AltStore and your own Apple ID (it signs it; refresh every 7 days with a free Apple ID). Step by step: [docs/usuario/instalar.md](docs/usuario/instalar.md#iphone-y-ipad-con-altstore) (Spanish). Developers can also build it from source with Xcode (below). |
| Windows | `PKArkTools-v2.0.0-windows-x64-setup.exe` (installer) or `PKArkTools-v2.0.0-windows-x64.zip` (portable: unzip and run `PKArkTools.exe`). It is not signed: if SmartScreen warns, click **More info → Run anyway**. |
| Linux | `PKArkTools-v2.0.0-linux-x64.tar.gz`: extract it and run `PKArkTools/pkarktools` (GTK 3; the folder picker needs `zenity` or `kdialog`). |

Once installed, the app checks for new versions itself (**Settings › About**) and on
Android installs them after checking the APK signature.

> The Windows and Linux builds are produced and checked by CI only: nobody has
> tested them on a real PC yet. Reports are welcome in
> [Issues](https://github.com/Rodriqe/PKArkTools/issues).

## Build from source

Requires Flutter stable (3.47+). Then:

```bash
git clone https://github.com/Rodriqe/PKArkTools.git
cd PKArkTools
flutter pub get
tool/ci.sh                          # analysis, tests, doc links
cd apps/pkarktools
flutter run                         # or: flutter build apk | macos | ios | windows | linux
```

The repo is a Dart workspace: `packages/pkcore` (pure Dart core: detection,
reading, writing, legality) and `apps/pkarktools` (Flutter app). See
[Architecture](docs/arquitectura.md) and [Development](docs/desarrollo.md).

## Your data

Saves never leave your device or your folder; the original file is never
modified; every copy and export is verified by SHA-256 / re-reading; nothing
is ever overwritten. The app only makes plain downloads, never uploads: icons,
the update check against GitHub Releases, and the Official format and event
data published in this repository. No accounts, no telemetry.
Read [Data safety and privacy](docs/seguridad-datos.md).

## Code signing policy

Free code signing on Windows provided by [SignPath.io](https://about.signpath.io),
certificate by [SignPath Foundation](https://signpath.org) (once the project is
approved; until then Windows builds are unsigned).

- Committers and reviewers: [Rodriqe](https://github.com/Rodriqe)
- Approvers: [Rodriqe](https://github.com/Rodriqe)

Only binaries built by GitHub Actions from a tagged commit of this repository
are signed. The macOS app is signed with an Apple Developer ID and notarized
by Apple; the Android APK is signed with the project's release key.

Privacy: this program does not transfer any information to other networked
systems unless specifically requested by the user or the person installing or
operating it. It only downloads data (icons, update checks, Official format and
event data from raw.githubusercontent.com and GitHub Releases); see
[Data safety and privacy](docs/seguridad-datos.md#privacidad).

## Documentation

Full documentation (in Spanish) lives in [`docs/`](docs/README.md):
[user guide](docs/usuario/README.md) ·
[Dex](docs/usuario/dex.md) ·
[Transfer](docs/usuario/transferir.md) ·
[Ribbon Hunter](docs/usuario/ribbon-hunter.md) ·
[supported formats](docs/formatos.md) ·
[data safety](docs/seguridad-datos.md) ·
[architecture](docs/arquitectura.md) ·
[development](docs/desarrollo.md) ·
[store publishing](docs/publicacion.md) ·
[licenses](docs/licencias.md) ·
[changelog](CHANGELOG.md).

## Contributing

Issues and pull requests are welcome. Please read
[CONTRIBUTING.md](CONTRIBUTING.md), the [Code of Conduct](CODE_OF_CONDUCT.md)
and, for vulnerabilities, [SECURITY.md](SECURITY.md). Never attach ROMs, keys
or other people's saves.

## Credits

* [**PKHeX**](https://github.com/kwsch/PKHeX) by Kaphotics and contributors
  (GPL-3.0): save formats, encryption, checksums, legality rules and game data
  are ported from PKHeX.Core; the optional icons are downloaded from the
  PKHeX repository.
* [**PokeAPI**](https://github.com/PokeAPI/pokeapi) (BSD-3-Clause): species
  names, types, experience tables and evolution chains.
* Fonts **Manrope** and **Bricolage Grotesque** (SIL OFL 1.1).
* Full list in [`NOTICE`](NOTICE) and [docs/licencias.md](docs/licencias.md).

## License

[GPL-3.0](LICENSE). Pokémon © Nintendo, Creatures Inc., GAME FREAK inc.;
this project is not affiliated with them.
