# pfUI_BagTweaks Development Handoff

## Start Here

- Repository: `Seraphic8x2244/pfUI_BagTweaks`.
- Work from the `dev` branch. Fetch current files before editing; the user may have changed the repo externally.
- Current development version: `0.1.38-dev`.
- Work directly on `dev`; do not open a PR unless asked.
- `main` is the stable user branch. Do not develop directly on `main`.
- Keep this handoff updated when behaviour, invariants, test status, or TODOs change.
- The user drives UX/design decisions; flag compatibility/performance risks instead of adding unnecessary options.
- Primary test target is brues-code pfUI. Shagu pfUI compatibility is best-effort unless a tester is available.

## Current Status

- Branch: `dev`.
- Version: `0.1.38-dev`.
- Latest functional commit: `5028d2d` — reorder toolbar controls by function. Latest asset rebuild commit: `74958e1` — regenerate Eye/EyeOff toolbar textures from scratch as fresh 32x32 uncompressed RGBA TGAs. Previous attempted eye repair commit: `bed6c82`; Options cog wiring commit: `6bb247f`; core redesign commit: `05a294d`.
- Texture integrity commit: `caf6016` — repair the Lucide texture blobs so all eight committed 32x32 TGA assets exactly match the generated source files.
- Icon integration commit: `849ecf8` — add the finalized Lucide toolbar textures, centered icon sizing, hover tint/tooltips, license attribution, and bump Lua/TOC to 0.1.34-dev.
- Previous Quest functional commit: `47bf529` — narrow the explicit legacy Quest repair to account-wide plus current-character overrides and ensure name metadata is available for active-objective matching.
- Latest TOC version commit: `89020d9` — sync TOC to 0.1.38-dev.
- Latest docs commit before this handoff: `eea6a8f` — record 0.1.35 artwork cleanup.
- Completed this pass: account-wide parent Category model confirmed; automatic packing validated in-game and produced the desired wide Healing/Spellpower plus compact Tank/Melee/PvP arrangement; wider horizontal Subcategory separation; tighter/better-balanced vertical spacing; DE changed to left-click; persistent mode disarms on bag close, bank close, and world transition; right-edge divider replaced with the requested L-shaped grey accent (existing top underline plus matching left edge).
- Tested this pass: L-shaped Subcategory accent renders correctly relative to the header; DE left-click targeting works. The 0.1.29-dev screenshot showed item frames overlapping the left accent, and backpack-close disarm failed because pfUI can replace the bag frame's OnHide script during CreateBags().
- Completed in 0.1.30-dev: Subcategory item grids were inset right by one pfUI spacing unit while the accent/header origin stayed fixed; Subcategory footprint/top line grew by the same inset; packing calculations included that extra width. Persistent DE/Pick now also disarms when the existing toolbar watcher observes the backpack frame hidden, so it no longer depends solely on the replaceable OnHide wrapper.
- 0.1.31-dev moved the icons 2 px left from 0.1.30-dev and proved slightly too far left.
- Completed in 0.1.32-dev: set the extra Subcategory item inset to `border * 2`, moving icons 1 px right from 0.1.31-dev / 1 px left from 0.1.30-dev while preserving the accent/header origin and matching width/packing calculations.
- Tested this pass: temporary active-quest objective detection for ordinary item-class items works in-game.
- Tested this pass: backpack-close and bank-close persistent-mode disarm both work in-game. The 0.1.30-dev item inset is about 2 px too far right.
- Tested this pass: backpack-close, bank-close, and world/instance-transition persistent-mode disarm all work in-game. On the tested instance transition the backpack is also forcibly closed, so the hidden-bag fallback already guarantees disarm there; the explicit `PLAYER_ENTERING_WORLD` disarm remains as a cheap safety net for alternate transition/order behaviour.
- Untested this pass: revised item-grid inset/accent width and any resulting packing changes.
- Deferred: packing optimisation unless future inventories show a real problem, Pick Lock workflow test, DE hover/cursor discoverability, possible toolbar refresh profiling.
- Root cause confirmed from history: the 0.1.16 system-Quest migration used old `questGroupID` only to enable the new Quest system, leaving the old designated group and its assignments as normal manual overrides. Deleting that old group then converted those assignments to `GENERAL_OVERRIDE`, permanently outranking automatic Quest detection.
- Completed in 0.1.33-dev: future direct legacy upgrades reuse the old designated Quest Subcategory as the system Quest Subcategory; deleting a normal Subcategory now removes its saved assignments instead of manufacturing General overrides; `IsQuestMetadata()` now accepts class ID 12 OR textual Quest type; `pfUI.bagtweaks.RepairLegacyQuestOverrides()` explicitly releases account/current-character General overrides that currently qualify for Quest automation. The repair is explicit because automatic cleanup could erase intentional modern General overrides.
- Untested in-game: all 0.1.33-dev Quest migration/repair changes.
- Toolbar icon direction finalized: use Lucide only; do not mix icon families. Live 0.1.35 choices are New Category=`SquarePlus`, New Subcategory=`Grid2x2Plus`, Search=`Search`, Sort=`ArrowUpDown`, Bags=`Backpack`, Keys=`KeyRound`, Empty Subcategories=`Eye`/`EyeOff`, Quest=`ScrollText`, Disenchant=`WandSparkles`, Pick Lock=`LockKeyhole`, Open=`PackageOpen`, Options=`Settings` (cog; the current Lucide `settings-2` glyph is slider-style). Spare `Lock`, `LockOpen`, and the previous `PanelsTopLeft` artwork remain available for future use.
- Completed in 0.1.34-dev: the eight locked controls now use rasterized Lucide 32x32 RGBA TGA textures; icons are centered and sized from the pfUI toolbar height (clamped to 8-14 px), retain the existing grey/yellow hover treatment, and show the existing localized control label as a tooltip. `+` and discovered third-party controls remain text. Existing active overlays and click handlers are unchanged. Lucide/Feather attribution is stored beside the textures.
- Asset verification: all eight committed TGA files are exactly 4,140 bytes and their Git blob hashes match the locally generated source files. This verifies repository-byte integrity, not Vanilla client rendering.
- Tested in-game: the 0.1.34-dev Lucide toolbar icons render cleanly and are visually successful; hover tint is a clean gold border and tooltips work. The Disenchant tooltip has been expanded from `DE` to `Disenchant`. Remaining toolbar interaction checks are active overlays and conditional hiding. The explicit legacy Quest repair cannot currently be reproduced because both available affected clients are already fixed; the 0.1.33-dev migration/repair path remains code-reviewed but not reproducibly testable in-game.
- Completed in 0.1.35-dev: removed the View dropdown; exposed direct Bags, Keys, and Empty Subcategories controls; split the old `+` menu into direct New Category and New Subcategory buttons; moved KeyRound to Keys and LockKeyhole to Pick Lock; added Eye/EyeOff state artwork; retained current toolbar/button sizing; kept Sort/DE/Pick conditional visibility; placed discovered third-party controls before Options; preserved Options immediately before Close. New Subcategory opens directly when only one Category exists and retains the Category-choice menu when multiple Categories exist. New Lucide assets plus spare Lock/LockOpen were committed in `2414b85`; spare `Lock` and `LockOpen` were moved to `textures/artwork/` in `21e23ad` so only live toolbar assets remain under `textures/toolbar/`.
- Untested in-game: the complete 0.1.35-dev toolbar redesign. The legacy Quest override repair cannot currently be reproduced on the available clients.
- 0.1.36-dev attempted to repair malformed Eye/EyeOff texture files by restoring their declared 32x32 RGBA byte length, but in-game testing showed the Eye icon still wrapped/bleeded over its border. Conclusion: the original raster pixel data itself was invalid, not just truncated. Options cog artwork remained correct.
- Completed in 0.1.38-dev: discarded both prior Eye/EyeOff binaries and regenerated the pair from scratch as fresh 32x32 uncompressed RGBA TGAs using the same Vanilla-safe 4,140-byte file layout as the known-good toolbar assets. No toolbar logic/order changes in this build.
- Completed in 0.1.37-dev: reordered the backpack toolbar to `Sort -> Open -> Disenchant -> Pick Lock -> Search -> Empty Subcategories -> Quest -> Keys -> Bags -> New Category -> New Subcategory -> third-party extras -> Options -> Close`; bank mirrors the applicable subset as `Sort -> Search -> Empty Subcategories -> Quest -> Bags -> New Category -> New Subcategory -> Options -> Close`. Conditional visibility and existing control behaviour are unchanged.
- Exact next step: install 0.1.38-dev and verify only that Eye and EyeOff render cleanly inside their borders in both states. If confirmed, continue the toolbar logic/reorder testing from 0.1.37 without further asset work.

## Goals

- Vanilla WoW 1.12.1.
- ClassicAPI is optional; feature-detect it.
- Keep the addon simple, visual, fast, and dependency-free.
- Backpack and bank share the same Category/Subcategory model.
- Visual layout/sorting never moves physical inventory.
- Only explicit Sort delegates to pfUI's physical inventory sorter.
- pfUI remains authoritative for bag width, bank width, icon/button size, borders, anchoring, movement, and native bag behaviours.

## Terminology / Model

- **Category**: full-width organisational container. Categories are always account-wide and do not directly own item assignments or sorting rules.
- **Subcategory**: item classification target. This is what the pre-0.1.28 addon called a Category.
- **General**: fixed full-width special section at the bottom; not a normal Category/Subcategory.
- **Quest**: built-in system Subcategory with fixed display name and account scope.

## Project Rules

- Use Category/Subcategory terminology consistently in new code, UI, docs, and SavedVariables. Group names are migration-only.
- Keep implementation in `pfUI_BagTweaks.lua` unless technically necessary. `locales.lua` remains separate.
- All user-facing strings belong in `locales.lua`.
- Persist through `_G.pfUIBagTweaksDB`; pfUI module environments must not own SavedVariables.
- Empty physical slots belong only to General.
- Manual Subcategory assignment wins over automatic Quest assignment. Explicitly moving an item to General also creates a General override; deleting a Subcategory must not create one.
- Account/character assignment is item-ID based, so all copies follow the same Subcategory.
- Backpack and bank share Categories, Subcategories, order, assignments, scope, visual sort, Quest state, and Empty Subcategories state.
- Do not physically move items for Category/Subcategory layout or visual sorting.
- Prefer pfUI native handlers for physical Sort, Disenchant, Pick Lock, Open, and fork-specific spell behaviour.
- Preserve wrapped scripts and third-party addon chains.
- Avoid polling, repeated SavedVariable writes, and cleanup in relayout hot paths.
- Coalesce bag/item-data relayouts.
- Do not auto-expand/collapse the player's quest log except for the guarded temporary scan that restores the exact prior state.

## SavedVariables

Schema 2:

- `schemaVersion = 2`.
- `categories`: ordered parent Category definitions; each has `subcategories={...}`.
- `nextCategoryID`: next stable parent Category ID.
- `subcategories`: item Subcategory definitions.
- `nextSubcategoryID`: next stable Subcategory ID.
- `accountSubcategories[itemID] = subcategoryID`.
- `characterSubcategories[characterKey][itemID] = subcategoryID`.
- `generalSort`, `generalReverse`.
- `showEmptyCategories` (legacy key retained for compatibility; UI label is Empty Subcategories).
- `questEnabled`.

General override remains ID `0`.

Migration from schema 1:
- Existing Categories become Subcategories without changing their IDs, scope, sorting, or item assignments.
- Existing row order is flattened into one parent Category named `Categories`.
- Legacy `rows`, `accountCategories`, `characterCategories`, `groups`, `nextGroupID`, `accountAssignments`, `charAssignments`, `assignments`, `questCategoryID`, and `questGroupID` are migration-only.
- When a directly upgraded legacy DB still identifies a designated Quest group/category, that exact Subcategory is promoted to the system Quest Subcategory instead of leaving it behind as a manual-override source.

## Layout

- Category containers always span pfUI's existing bag width.
- Backpack uses pfUI `bagrowlength`; bank uses `bankrowlength`.
- Item size comes from pfUI's calculated `button_size`; border/spacing comes from pfUI bag border settings.
- Subcategories pack left-to-right in stable user order and wrap when the next block will not fit.
- Horizontal Subcategory gaps are accounted for inside pfUI's existing bag width; BagTweaks does not widen the bag.
- Each Subcategory uses a subtle grey L-shaped accent: the existing header underline is the top edge, with a matching grey line descending from its top-left intersection along the left edge. There is no right-edge divider.
- Item icons sit slightly farther below their Subcategory underline, while wrapped Subcategory rows use a tighter vertical gap.
- Preferred Subcategory width is count-driven: approximately `ceil(sqrt(itemCount * 1.5))`, clamped to the parent width with a two-slot minimum where possible.
- Spare columns are only assigned when they reduce a Subcategory's item-row count.
- This is deliberately greedy/deterministic rather than a bin-packing optimiser.

## Editing / Dragging

- Toolbar has separate New Category and New Subcategory icon buttons.
- When multiple Categories exist, New Subcategory asks which Category should receive it.
- Category header menu: New Subcategory, Rename, Move Up, Move Down, Delete.
- The last remaining Category cannot be deleted.
- Deleting a Category moves its Subcategories to another Category; assignments are preserved.
- Subcategory menu retains Rename, Account Wide / Per Character, Sorting, Reverse, Delete.
- Deleting a Subcategory releases its saved assignments. Items then fall through to automatic rules such as Quest, otherwise General.
- Drag a Subcategory before/after another Subcategory to reorder or move it between Categories.
- Drag a Subcategory onto Category space to append it to that Category.

## Behaviour Invariants

- Quest automatic precedence: manual Subcategory -> real Quest-class item / active item objective -> General.
- Active quest-objective matching is runtime-only.
- Default visual sort means current physical traversal order.
- Other visual sorts: Name, Vendor Value, Character Slot; each supports Reverse.
- Bank Default uses bank physical traversal order.
- Bank DE/Pick/Open controls are intentionally absent.
- Backpack DE uses Vanilla-style left-click targeting and does not consume bank-item left-clicks.
- Persistent DE/Pick mode is disarmed when the backpack closes, the bank closes, or `PLAYER_ENTERING_WORLD` fires (including loading/world transitions).

## Toolbar

Backpack:

`[Sort?] [Open] [DE?] [Pick?] [Search] [Empty] [Quest] [Keys] [Bags] [New Category] [New Subcategory] [Third-party?] [Options] [X]`

Bank:

`[Sort?] [Search] [Empty] [Quest] [Bags] [New Category] [New Subcategory] [Options] [X]`

- Bags, Keys, and Empty Subcategories are direct toggles; Bags/Keys use the active overlay when enabled.
- Empty Subcategories swaps Eye/EyeOff with state and also uses the active overlay when enabled.
- Keys is backpack-only.
- Sort is hidden if the pfUI fork has no native sorter; DE/Pick remain availability-gated.
- Discovered third-party bag controls stay before Options; Options stays immediately before Close.
- No BagTweaks options are currently exposed.

## Test Status

Previously confirmed on the pre-0.1.28 brues-code pfUI base:
- Login/reload without Lua errors.
- Item assignment, account/per-character scope, visual sorting, Reverse, Quest, Search, View, Options.
- Backpack/bank shared categorization.
- Physical backpack/bank Sort delegates to pfUI.
- Persistent Disenchant worked on the pre-0.1.29 implementation; 0.1.29 changes its target click to Vanilla-style left-click.
- Quest class-12 categorization and manual precedence work.

`0.1.29-dev` requires a fresh in-game pass after the Category/Subcategory refactor and spacing/DE changes:
- Schema-1 migration and reload persistence.
- Category/Subcategory creation, rename, delete, and ordering.
- Dynamic packing at different pfUI bag row lengths and icon sizes.
- Horizontal Subcategory gap, top+left grey L-shaped accent, and revised vertical spacing.
- Subcategory drag/reorder/move between Categories.
- Backpack and bank layout parity.
- Empty Subcategories toggle.
- Existing assignment/scope/sort/Quest behaviour after migration.
- DE left-click targeting and disarm on backpack close, bank close, and world/instance transition.

## TODO / Untested

- Rogue Pick Lock workflow.
- DE discoverability: targeting-style cursor / candidate-item hover feedback; keep Vanilla-style left-click targeting.
- In-game test the 0.1.38-dev from-scratch Eye/EyeOff assets first. Cog Options artwork is expected correct from 0.1.36. Then finish the direct-toolbar redesign checks: state overlays, conditional buttons, parent selection for New Subcategory, and worst-case toolbar width. The prior 0.1.34 Lucide rendering, visual quality, hover tint, and tooltips are confirmed good.
- Consider reducing the 0.20s toolbar layout refresh only if profiling or visible behaviour justifies it.

## Branches

- `main`: stable user branch; no HANDOFF.md.
- `dev`: active development branch; keep this HANDOFF.md current.
