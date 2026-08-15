# SecretChecklist

A World of Warcraft addon that helps you track and check your progress on secret collectibles including mounts, pets, toys, achievements, transmog, quests, housing items, and other hidden content.

<img width="1173" height="762" alt="cKXD4krAlE" src="https://github.com/user-attachments/assets/b4e4940b-c1d0-471d-9665-241c9bd2bdd5" />
<img width="1164" height="753" alt="gL11bkA9ow" src="https://github.com/user-attachments/assets/945a9665-e563-492b-aae6-76336934e65b" />
<img width="1042" height="783" alt="0PxHX4fTLx" src="https://github.com/user-attachments/assets/38035af6-5b34-47b6-966e-0f7895b3b885" />

## Download

- [CurseForge](https://www.curseforge.com/wow/addons/secretchecklist)
- [Wago Addons](https://addons.wago.io/addons/secretchecklist)

## Features

- **Minimap Button**: Quick access with a draggable minimap button
- **Collections-style Journal**: A standalone window styled after WoW's Collections interface
- **Automated Checking**: Automatically checks your collection status for pre-defined secret collectibles
- **Advanced Filtering**: Filter by status (All/Collected/Missing) and type (Mounts, Pets, Toys, Achievements, Quests, Transmog, Housing, Mysteries)
- **Bulk Filter Controls**: Select All / Deselect All buttons for quick filter management; menu stays open while selecting
- **Visual Feedback**: Icons are colored when collected, greyed out when missing
- **Progress Counters**: Live "collected / total" counts for all secrets and for Mind-Seeker secrets
- **Guides Tab**: Detailed view of each secret with description, wowhead guide link, and an interactive 3D model viewer
- **Search**: Find any secret by name, zone, or anything mentioned in its steps — searching "Kosumoth" or "Tazavesh" works as well as searching the item name
- **Progress Steps**: Step-by-step walkthrough per secret with click-to-waypoint support (via TomTom or built-in arrow)
- **3D Model Viewer**: Previews mounts, pets, transmog worn on your character, housing items, and weapons in a live model scene
- **Click-to-Navigate**: Click any icon in the Overview to jump directly to its Guides entry; Ctrl+Click inserts an item or achievement link into your active chat box
- **Mystery Category**: Track community secrets still being investigated (e.g. active discoveries from the Secret Finding Discord)
- **Custom Lists**: Easily edit the list to track the secrets you want
- **Pre-Configured**: Comes with 54 secrets ready to track
- **Live Requirement Checks**: Step progress automatically checks renown level, faction reputation, and Mind-Seeker secret count from the game API — shown inline as e.g. `(5 / 8)` when not yet complete
- **Themes**: Default, ElvUI, and EllesmereUI looks, matching whichever UI you run
- **Accessible Status Icons**: Collected and missing are marked with a checkmark and a cross, not colour alone
- **Collection Toasts**: A toast pops up the moment a tracked secret is collected, so you know it registered
- **Remembers Its Place**: Window position, filters, theme and minimap button all persist across sessions and characters
- **Beledar Orchestra Helper**: Built-in raid client for the Radiant Singer secret — see [Beledar Orchestra Helper](#beledar-orchestra-helper)
- **Translatable**: Both the interface and the guide content itself can be translated — see [Translating](#translating)
- **About Tab**: Always-visible About tab with addon credits and community links

## Installation

1. Download the latest release or clone this repository
2. Extract the `SecretChecklist` folder to `World of Warcraft\_retail_\Interface\AddOns\`
3. Restart World of Warcraft or reload your UI with `/reload`

## How to Use

**Click the minimap button** to open your secret checklist in the Collections Journal. The UI displays all tracked secrets with colored icons for collected items and greyed-out icons for items you're still missing.

### Slash Commands

Both `/secrets` and `/secretchecklist` work as aliases:

| Command | Description |
|---------|-------------|
| `/secrets` | Open the SecretChecklist window |
| `/secrets options` | Open the SecretChecklist options |
| `/secrets minimap` | Toggle minimap button visibility |
| `/secrets alert` | Fire a test collection toast |
| `/secrets validate` | Check the secret data for problems |
| `/secrets debug` | Toggle debug mode (shows the real per-step state on collected secrets) |
| `/secrets help` | List these commands |

- **Click an overview icon** to jump directly to that entry's full guide in the Guides tab
- **Ctrl+Click an overview icon** to insert an item or achievement link into your active chat box

### Using Filters

- **Status Filter**: Click the "Status: All" dropdown to show only Collected or Missing items
- **Type Filter**: Click the "Filter" button to select which types to display (Mounts, Pets, Toys, etc.)
- **Quick Actions**: Use "Select All" or "Deselect All" to quickly manage type filters
- **Progress Counters**: Show your overall collected / total counts regardless of active filters

### Saving Your Preferences

Everything you change is written to SavedVariables and comes back at your next
login, on every character:

- Filter settings (status and type selections)
- Window position and the Guides tab layout style
- Theme choice
- Minimap button position and visibility

## Tracked Secrets

Comes pre-configured with **54 secret collectibles** across mounts, pets, toys, achievements, transmog, quests, housing, and mysteries — with more being added regularly.

## Beledar Orchestra Helper

The Radiant Singer secret needs a 40-player raid performing a set sequence of
emotes at the Divine Flame of Beledar in Hallowfall. SecretChecklist ships a
small player-side client for that, so **only the raid leader needs the
[BeledarOrchestra](https://www.curseforge.com/wow/addons/beledarorchestra)
addon** — everyone else can just have SecretChecklist.

- Target the Divine Flame in Hallowfall and a compact popup appears with your
  raid slot and the emote you have been assigned for the current measure.
- The emote button performs it for you; the popup counts down when the leader
  starts a measure and locks in once you have bowed.
- It follows your theme (Default, ElvUI or EllesmereUI) and remembers where you
  drag it.
- It disables itself automatically if you have BeledarOrchestra installed, so
  you never get two popups.

## Translating

The interface ships in 11 languages. Guide content is a newer addition — deDE
and ruRU files exist but are still empty, so every language currently falls back
to English there. Help very much wanted.

Two separate files, because they are two different jobs:

| File | Contents |
|---|---|
| `localisation/<locale>.lua` | Interface labels — buttons, tabs, tooltips, settings |
| `localisation/data/<locale>.lua` | Guide content — every step label, note, source and description |

Guide content is keyed by its English text rather than by an id, so nothing in
the data file needs changing to add a language, and a partly finished
translation falls back to English string by string rather than all at once.

To start a new language, or to pick up strings added since the last pass:

```
python tools/extract-strings.py --locale frFR
```

It writes `localisation/data/frFR.lua` with every string listed and preserves
any translations already there, so it is safe to re-run. Add the new file to
`localisation/locale.xml` alongside the others.

Notes for translators:

- A line left empty falls back to English. Nothing breaks if you skip one.
- Placeholders such as `%d` and `%s` may be moved to suit your word order, but
  each one must appear exactly once in the translation.
- Changing an English string in the data file orphans its translation; re-running
  the extractor shows which strings need another look.

Pull requests with a new or improved locale are very welcome.

## Version History

The user-facing notes for 2.0 and later live in [CHANGELOG.md](CHANGELOG.md).
The list below is the full development history.

- **2.0.3**: Radiant Singer now states the Gift of Oddsight requirement up front — the Divine Flame cannot be targeted without the buff
- **2.0.2**: The Beledar assignment popup follows your theme instead of a plain tooltip background, with a tidier header and a remembered position
- **2.0.1**: Fixed an error on every target change introduced in 2.0.0, which also tainted execution and could affect other addons
- **2.0.0**: Large maintenance release. Search box in the Guides tab; whole Overview rows are clickable; checkmark/cross status icons so status is not colour-only; the window remembers its position; the EllesmereUI theme marks collected secrets with the same gold border as the others; guide content (steps, notes, descriptions) is translatable, not just the interface; `/secrets help` and `/secrets validate`. Fixes: a Lua error on every login that silently disabled the Beledar helper; browsing the checklist resetting your Collections journal filters; steps staying red after the reward item was consumed or equipped; achievement tooltips stuck on "Retrieving data"; step notes not reopening after a collapse; oversized waypoint-only steps; the Guides style setting being forgotten; waypoints erroring inside dungeons without TomTom; the About tab copy box showing the wrong link. Internally: on-demand widget creation, a status cache, and a good deal of dead code removed
- **1.11.0**: Added an EllesmereUI theme built on EllesmereUI 8.6's public skinning API (`EllesmereUI.RegisterSkin`) — the window, tabs, buttons and toasts are painted by EUI itself and track the accent colour, window style and UI font set on your EUI profile, live. Theme colour entries may now be functions so a palette can resolve per read instead of being frozen at load; `ApplyTheme` no longer overwrites the saved theme when it falls back to Default because a host addon has not loaded yet (this previously erased the choice at every login). Also fixed `RefreshAlertTheme` never running — its guard referenced a local declared later in the file, so the name resolved to a nil global and existing toasts were never re-skinned on a theme change
- **1.10.1**: Fixed the Shu'halo Perspective painting re-firing its "Secret Collected" toast on zone transitions (an early `HOUSING_STORAGE_UPDATED` with `totalNumStored=0` produced a spurious missing→collected swing; a confirmed-collected housing snapshot is now sticky) and made step status housing-aware so the "Buy painting" step reads as done from housing storage rather than bags
- **1.10.0**: Added Unfazed Diver secret, fix housing ownership detection
- **1.9.13**: Updated toc for 12.0.7
- **1.9.12**: Updated waypoints for Crimson Tidestallion (faction based waypoints)
- **1.9.11**: Updated toc for 12.0.5
- **1.9.10**: Fixed Mind-Seeker tracking flags: added `mindSeeker = true` to Sun Darter Hatchling (#16) and Ensemble: Fashion of the Fanatic Felcyclist (#34); removed incorrect `mindSeeker = true` from Cartel Transmorpher (not part of the 34 tracked secrets)
- **1.9.9**: Improved Secrets of Azeroth completion reliability and step structure: (1) Bound Shadehound codex flow now nests "Buy Partial Rune Codex" + all three rune pages as substeps under the combine step so progression is grouped correctly in the UI; removed fragile parent `questID=63668` dependency and rely on resulting item progress (`Intact Rune Codex`) instead; (2) added achievement-criteria fallback support in step status checks (`achievementID` + `criteriaID`) to handle secret quests that do not always report as completed; applied to Whodunnit chain steps in Tricked-Out Thinking Cap (Secret 1-15), including Secret 2 (Tuskarr Ceremonial Spear), so criteria completion now marks steps done even when quest flags are inconsistent
- **1.9.8**: Fixed housing decor (Shu'halo Perspective Painting) flickering between collected/missing when entering or exiting instances (BG/raid/dungeon) — root cause was `entrySubtype=1` being ambiguous: it means both "genuinely unowned" AND "storage not loaded yet" since housing storage is lazy-loaded by the game and only populates on first housing catalog UI open; fixed with three cooperating changes: (1) `SC._housingStorageReady` flag — reset to `false` by `HOUSING_CATALOG_CATEGORY_UPDATED` (catalog rebuilding), set to `true` by `HOUSING_STORAGE_UPDATED` (ownership confirmed); `CheckEntry` now returns `nil` (unknown, no flicker) for `subtype=1` while not ready; (2) added `HOUSING_STORAGE_UPDATED` event alongside `HOUSING_STORAGE_ENTRY_UPDATED` so bulk storage reloads on zone transitions are captured; (3) proactively trigger storage load on every `PLAYER_ENTERING_WORLD` via `C_HousingCatalog.CreateCatalogSearcher().RunSearch()` (same technique as AllTheThings) so ownership data loads at login and after every instance exit without requiring the player to open the housing UI; also wrapped `GetCatalogEntryInfoByItem` in `pcall` to match HousingCompanion/ATT defensive pattern
- **1.9.7**: Fixed false "Secret Collected!" toast for Shu'halo Perspective Painting (and any housing decor) firing on every login — root cause was `HOUSING_CATALOG_CATEGORY_UPDATED` (a catalog-structure event, added in v1.9.4) triggering the alert snapshot diff before ownership data had merged, writing `snapshot=false`, then the real ownership arrival looked like a missing→collected transition; fixed by using `entrySubtype` from `GetCatalogEntryInfoByItem` as the sole ownership signal (`0/nil`→unknown, `1`→unowned, `2/3`→owned) so partially-loaded catalog data returns `nil` instead of `false`; split housing event handlers so `HOUSING_CATALOG_CATEGORY_UPDATED` only triggers a UI redraw (fixes the separate 5–10 min delay before owned items appear collected), while `HOUSING_STORAGE_ENTRY_UPDATED` and `HOUSE_DECOR_ADDED_TO_CHEST` exclusively drive the alert snapshot
- **1.9.6**: Phoenix Wishwing — steps 1–3 (Glittering Phoenix Ember, Inert Phoenix Ash, Sacred Phoenix Ash) are now substeps of step 4 (Get Phoenix Ash Talisman from Zektar); substep rows now automatically render as completed (green/dimmed) when their parent step is already marked done
- **1.9.5**: Fixed Wan'be's Buried Goods quest IDs — updated entry-level `questID` from placeholder `000` to `53657`; added per-step `questID`s for steps 1–4 (`53653`–`53656` sourced from AllTheThings); corrected step 5 `questID` from `52192` to `53657`
- **1.9.4**: Warbank item detection — pass `includeAccountBank` flag to all `C_Item.GetItemCount` calls and register `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED` to refresh counts when the warbank opens; added `itemIDs` any-of support on steps so owning any listed item marks the step active; Blanchy Day 4 now merges Empty Bucket + Bucket of Clean Water into one step via `itemIDs`; fixed `elsif` typo in StepItemCount helper
- **1.9.3**: Added BeledarHelper — a lightweight BeledarOrchestra player client built into SecretChecklist; shows a popup with your assigned emote when targeting the Divine Flame of Beledar in Hallowfall; receives the leader's measure table and overrides via the `BO_DATASYNC` / `BeledarOrch` addon message protocol so only the raid leader needs BeledarOrchestra installed; responds to BO version checks (`PING`) reporting as `SC-x.x.x`; automatically disables itself if BeledarOrchestra is loaded
- **1.9.2**: Entry-level quest checks now use `IsQuestFlaggedCompletedOnAccount` (account-wide secret completion signal); substep/step checks keep `IsQuestFlaggedCompleted` (per-character progress tracking); `stepsOverrideOnDone` now defaults to `true` for all entries — set `stepsOverrideOnDone = false` on an entry to opt out; added Voldunai Revered reputation requirement step to Wan'be's Buried Goods; temporarily removed Wan'be's questID pending in-game verification
- **1.9.1**: Fixed collection status detection: `questID` is now checked first in all entry types before kind-specific API checks — secret quests are flagged on completion and are more reliable than `PlayerHasTransmog`/`GetItemInfo` which return `false` for ensemble container items; fixes `Ensemble: Fashion of the Fanatic Felcyclist` (and any other ensemble transmog) not marking as collected; corrected questID to 91636 for the ensemble entry
- **1.9.0**: Added Russian localisation (ru-RU, contributed by ZamestoTV); fixed `Ensemble: Fashion of the Fanatic Felcyclist` entry data
- **1.8.5**: Added full walkthroughs for 12 Orb Mystery Orb 11 (Radiant Singer — 40-player raid with Beledar Orchestra Addon at Divine Flame of Beledar, Hallowfall) and Orb 12 (Dusk Lily escort in Suramar/Azsuna for Spare Key, then Hidden Footlocker in Karazhan Catacombs); added `Ensemble: Fashion of the Fanatic Felcyclist` as a new linked transmog entry with full Dusk Lily substeps; added `Radiant Singer` substeps to its linked achievement entry; added questIDs 93764/93765 for Orb 11 and 12; added version-check broadcast (`SecretChecklistVersion.lua`) that notifies you in chat when a group member has a newer version
- **1.8.4**: Fixed AddonCompartment hover crash ("Wrong object type") caused by incorrect handler signatures when using `RegisterAddon`; corrected function signatures to match `RegisterAddon` calling convention (`funcOnEnter`/`funcOnLeave` receive `(button, addonInfo)`, `func` receives `(_, menuInputData, menu)`); added settings to show/hide the minimap addon compartment button independently
- **1.8.3**: Added AddonCompartment support — Secret Checklist now appears in the minimap addon compartment dropdown; left-click toggles the window, hovering shows a tooltip, right-click gracefully noops (reserved for future options panel)
- **1.8.2**: Fixed substep anchor cascading indent (each substep row was indented 14px more than the previous); corrected Riddler's Mind-Worm quest ID for "Loot Gift of the Mind-Seekers" (47213 → 47214); added missing `questID = 58099` to Jenafur's "Collect food in Karazhan" step
- **1.8.1**: Fixed addon title typo ("Secrets Checklist" → "Secret Checklist"); added *A Most Violent Loa* achievement (Filo / Kapara kills in Zul'Aman); added substeps for multi-item collection tracking within a single step (Sargle's Fortunes); progress steps now auto-expand for uncollected secrets and auto-collapse for collected ones; fixed item-based step tracking not updating when moving items to/from the bank
- **1.8.0**: Added live requirement checks for renown, faction reputation, and Mind-Seeker secret count — incomplete steps now display current progress inline (e.g. `(5 / 8)`); added step walkthroughs for all previously missing entries (Mimiron's Jumpjets, Pattie's Cap, Tobias' Leash, Starry-Eyed Goggles, Mind-Seeker); split Mind-Seeker secret-count requirement into its own dedicated step; About tab is now always visible (no longer a hidden easter egg); added `questID` and `repReq` to Bound Shadehound steps; updated cross-references and `requires`/`requiredFor` to arrays throughout; **note: some guide walkthroughs are still a work in progress and step data may not yet be complete or fully accurate for all entries**
- **1.7.1**: Improved Guides tab UI polish — map-pin icon on waypoint button; consistent top margin when Info/Model tab bar is hidden; increased step/note font size to 12pt for readability without ElvUI; increased gap between description and progress steps header; removed duplicate filter logic; fixed quest name lookup using correct WoW API
- **1.7.0**: Added Mystery category for community-investigated secrets; added interactive Progress Steps with click-to-waypoint in Guides tab; added step-by-step walkthroughs for Blanchy's Reins, Kosumoth (Fathom Dweller + Hungering Claw), Keys to Incognitro, and 12 Orb Mystery; added Starry-Eyed Goggles (toy) and Azeroth's Greatest Detective (achievement); fixed Hungering Claw pet speciesID; filter Deselect All now shows all entries instead of hiding them; type filter menu stays open while toggling; unknown/uninvestigated secrets now shown in grey (same as missing); model viewer hidden for entry types without a 3D model
- **1.6.3**: Fixed overview icon clicks not working; fixed guides scroll position resetting on tab switch; added toast alert when a secret is newly collected
- **1.6.2**: Fixed secret icons showing incorrect collected/missing state on first open; fixed Terky model on the About tab not rendering until switching tabs
- **1.6.1**: Added Secrets of Azeroth event entries: Tricked-Out-Thinking Cap, Torch of Pyrreth, Idol of Ohn'ahra (toys) and Whodunnit! (achievement); updated screenshots
- **1.6.0**: Added ElvUI theme support with automatic detection and visual styling; enhanced scrollbar and divider polish; added About tab with addon credits, license info, and easter egg
- **1.5.1**: Click overview icons to navigate to the Guides tab entry; Ctrl+Click to insert item/achievement link into chat; Wowhead button moved to bottom of detail pane; progress counts shown on both Overview and Guides tabs
- **1.5.0**: Added Guides tab with wowhead guide links and interactive 3D model viewer (mounts, pets, transmog on player, housing items); fixed minimap button persistence; updated filter pill visual; new entries (Bound Shadehound, Felreaver Deathcycle, Keys to Incognitro, Mimiron's Jumpjets, Nazjatar Blood Serpent, Otto, Pattie's Cap, Thrayir Eyes of the Siren, Xy Trustee's Gearglider, Courage, Glimr's Cracked Egg, Sun Darter Hatchling, Terky, Tobias' Leash, Hungering Claw, Cartel Transmorpher, Leaders of Scholomance, Mind-Seeker, Wan'be's Buried Goods, Shu'halo Perspective Painting)
- **1.2.1**: Added You Conduit! achievement (Midnight) and Gortham battle pet
- **1.2.0**: Full localization system (11 languages supported), minimap button settings panel, performance optimizations, code quality audit
- **1.1.0**: Added advanced filtering system (status + type filters), Select All/Deselect All buttons, simplified slash commands, code optimization (11% reduction)
- **1.0.1**: Added status filter dropdown (All/Collected/Missing)
- **1.0.0**: Initial public release with minimap button and Collections Journal UI

Supports WoW Interface 120007 and 120100 (Midnight).

## Credits & References

The transmog 3D model viewer logic (armor display on player character with slot zoom and camera handling) is based on the implementation from **[AppearanceTooltip](https://www.curseforge.com/wow/addons/appearancetooltip)** by [Kemayo](https://www.curseforge.com/members/kemayo/projects). Specifically, the `DressUpModel` + `TryOn` + `Dress()` pattern and `Model_ApplyUICamera` usage were adapted from that addon's source.

The Beledar Orchestra helper speaks the addon message protocol defined by **[BeledarOrchestra](https://www.curseforge.com/wow/addons/beledarorchestra)** by [Samsbase](https://github.com/samsbase), so a raid leader running that addon drives SecretChecklist users automatically. The measure data it ships with comes from the same community effort.

All secrets featured in this addon were discovered by the community over at the **[Secret Finding Discord](https://discord.gg/wowsecrets)** — the home of WoW secret hunters. A huge thanks to everyone there for their incredible detective work.

## Code Quality

This addon was created with the assistance of GitHub Copilot and Claude AI. The code is:

- **Clean and Performant**: Optimized for minimal overhead and fast execution
- **Global Namespace Safe**: Free of unnecessary global variables that pollute the WoW environment
- **Modern API**: Uses current WoW APIs without deprecated functions
- **Continuously Checked**: Every push runs luacheck, an XML well-formedness check and a packager dry-run in CI
- **Audited**: Code has been reviewed using Ketho's WoW API extension to ensure quality standards

`/secrets validate` checks the secret data against the live game — schema, cross-references between entries, and whether each waypoint's map actually accepts one. Useful if you keep your own edits to `data/SecretEntries.lua`.

## Author

Created by Calaglyn - Emerald Dream (EU)

## License

This addon is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

You are free to use, modify, and distribute this addon, but any derivative work **must**:
- Be released under the same GPL-3.0 license
- Include prominent attribution crediting **SecretChecklist by Calaglyn** as the original work
- Make the source code available

See the [LICENSE](LICENSE) file for full details.
