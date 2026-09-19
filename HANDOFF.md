# pfUI_BagTweaks Development Handoff

## Start Here

- Repository: `Seraphic8x2244/pfUI_BagTweaks`.
- Work from the `dev` branch. Fetch current files before editing; the user may have changed the repo externally.
- Current development version: `0.1.30-dev`.
- Work directly on `dev`; do not open a PR unless asked.
- `main` is the stable user branch. Do not develop directly on `main`.
- Keep this handoff updated when behaviour, invariants, test status, or TODOs change.
- The user drives UX/design decisions; flag compatibility/performance risks instead of adding unnecessary options.
- Primary test target is brues-code pfUI. Shagu pfUI compatibility is best-effort unless a tester is available.

## Current Status

- Branch: `dev`.
- Version: `0.1.30-dev`.
- Latest functional commit: `b5cd41d` — inset Subcategory item grids and add a reliable backpack-hidden persistent-mode disarm fallback.
- Previous functional commit: `458e4d3` — draw Subcategory accent on top and left.
- Latest version commits: `25d1b80` / `6b6329c` — bump Lua/TOC to 0.1.30-dev.
- Completed this pass: account-wide parent Category model confirmed; automatic packing validated in-game and produced the desired wide Healing/Spellpower plus compact Tank/Melee/PvP arrangement; wider horizontal Subcategory separation; tighter/better-balanced vertical spacing; DE changed to left-click; persistent mode disarms on bag close, bank close, and world transition; right-edge divider replaced with the requested L-shaped grey accent (existing top underline plus matching left edge).
- Tested this pass: L-shaped Subcategory accent renders correctly relative to the header; DE left-click targeting works. The 0.1.29-dev screenshot showed item frames overlapping the left accent, and backpack-close disarm failed because pfUI can replace the bag frame's OnHide script during CreateBags().
- Completed in 0.1.30-dev: Subcategory item grids are inset right by one pfUI spacing unit while the accent/header origin stays fixed; Subcategory footprint/top line grows by the same inset; packing calculations include that extra width. Persistent DE/Pick now also disarms when the existing toolbar watcher observes the backpack frame hidden, so it no longer depends solely on the replaceable OnHide wrapper.
- Tested this pass: temporary active-quest objective detection for ordinary item-class items works in-game.
- Tested this pass: backpack-close and bank-close persistent-mode disarm both work in-game. The 0.1.30-dev item inset is about 2 px too far right.
- Untested this pass: revised item-grid inset/accent width and any resulting packing changes; world/instance-transition disarm.
- Deferred: packing optimisation unless future inventories show a real problem, Pick Lock workflow test, DE hover/cursor discoverability, custom toolbar artwork, possible toolbar refresh profiling.
- Exact next step: reduce the extra Subcategory item inset from one full pfUI spacing unit (`border * 3`) to `border` (about 2 px left in the tested setup), keep the accent/header origin fixed, update width/packing calculations consistently, bump dev version, then retest visual alignment and world/instance-transition disarm.

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
- Manual Subcategory assignment wins over automatic Quest assignment.
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

- Toolbar `+` opens New Category / New Subcategory.
- When multiple Categories exist, New Subcategory asks which Category should receive it.
- Category header menu: New Subcategory, Rename, Move Up, Move Down, Delete.
- The last remaining Category cannot be deleted.
- Deleting a Category moves its Subcategories to another Category; assignments are preserved.
- Subcategory menu retains Rename, Account Wide / Per Character, Sorting, Reverse, Delete.
- Deleting a Subcategory returns its assigned items to General.
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

`[+] [Search] [Sort?] [View] [Quest] [DE?] [Pick?] [Open] [Options] [X]`

Bank:

`[+] [Search] [Sort?] [View] [Quest] [Options] [X]`

- Backpack View: Bags / Keys / Empty Subcategories.
- Bank View: Bags / Empty Subcategories.
- Sort is hidden if the pfUI fork has no native sorter.
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
- Custom tiny toolbar artwork: Search, Sort, Options, DE, Pick, Open.
- Consider reducing the 0.20s toolbar layout refresh only if profiling or visible behaviour justifies it.

## Branches

- `main`: stable user branch; no HANDOFF.md.
- `dev`: active development branch; keep this HANDOFF.md current.
