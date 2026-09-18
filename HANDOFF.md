# pfUI_BagTweaks Development Handoff

## Start Here

- Repository: `Seraphic8x2244/pfUI_BagTweaks`.
- Work from the `dev` branch. Fetch current files before editing; the user may have changed the repo externally.
- Current development version: `0.1.27-dev`.
- Work directly on `dev`; do not open a PR unless asked.
- `main` is the stable user branch. Do not develop directly on `main`.
- Keep this handoff updated when behaviour, invariants, test status, or TODOs change.
- The user drives UX/design decisions; implementation should flag compatibility or performance risks rather than adding unnecessary options.
- Do not make Shagu pfUI a test/release gate; the user's active test target is brues-code pfUI.

## Goals

- Vanilla WoW 1.12.1.
- Primary target: brues-code pfUI.
- Shagu pfUI compatibility is best-effort unless a tester is available.
- ClassicAPI is optional; feature-detect it.
- Keep the addon simple, visual, fast, and dependency-free.
- Backpack and bank use the same category model.
- Visual category sorting never moves physical inventory.
- Only explicit Sort delegates to pfUI's physical inventory sorter.

## Project Rules

- Use **Category** terminology throughout code, UI, docs, and SavedVariables. Do not reintroduce Group terminology except legacy migration keys.
- Keep implementation in `pfUI_BagTweaks.lua` unless a split is technically necessary. `locales.lua` remains separate.
- All user-facing strings belong in `locales.lua`.
- Persist through `_G.pfUIBagTweaksDB`; pfUI module environments must not own SavedVariables.
- General is fixed and always bottom.
- Category rows allow one or two categories only.
- Empty physical slots belong only to General.
- Manual categorization wins over automatic Quest categorization.
- Account/character categorization is item-ID based, so all copies follow the same category.
- Backpack and bank share category definitions, row order, categorization, scope, visual sort, Quest state, and Empty Categories state.
- Do not physically move items for category layout or visual sorting.
- Prefer pfUI native handlers for physical Sort, Disenchant, Pick Lock, Open, and fork-specific spell behaviour.
- Preserve wrapped scripts and third-party addon chains.
- Avoid polling, repeated SavedVariable writes, and cleanup in relayout hot paths.
- Coalesce bag/item-data relayouts.
- Do not auto-expand/collapse the player's quest log except for the guarded temporary scan that restores the exact prior state.

## SavedVariables

Current schema:

- `categories`: category definitions.
- `nextCategoryID`: next stable category ID.
- `rows`: visual category row layout.
- `accountCategories[itemID] = categoryID`.
- `characterCategories[characterKey][itemID] = categoryID`.
- `generalSort`, `generalReverse`.
- `showEmptyCategories`.
- `questEnabled`.

General override is category ID `0`.

Legacy `groups`, `nextGroupID`, `accountAssignments`, `charAssignments`, `assignments`, and `questGroupID` are migration-only names.

## Behaviour Invariants

- Category scope is account-wide or per-character.
- Quest is a built-in system category with fixed display name and account scope.
- Quest automatic precedence: manual category -> real Quest-class item / active item objective -> General.
- Active quest-objective matching is runtime-only.
- Default visual sort means current physical traversal order.
- Other visual sorts: Name, Vendor Value, Character Slot; each supports Reverse.
- Bank Default uses bank physical traversal order.
- Bank DE/Pick/Open controls are intentionally absent.
- Backpack DE does not consume bank-item right-clicks.

## Toolbar

Backpack:

`[+] [Search] [Sort?] [View] [Quest] [DE?] [Pick?] [Open] [Options] [X]`

Bank:

`[+] [Search] [Sort?] [View] [Quest] [Options] [X]`

- Backpack View: Bags / Keys / Empty Categories.
- Bank View: Bags / Empty Categories.
- Sort is hidden if the pfUI fork has no native sorter.
- No BagTweaks options are currently exposed.

## Tested

Confirmed on brues-code pfUI:

- Login/reload without Lua errors.
- Backpack categories, drag/reorder, one/two-column layout, scope, sorting, Reverse, Quest, Search, View, Options.
- Bank categories and toolbar; shared categorization/order behaves correctly.
- Physical backpack/bank Sort delegates to pfUI.
- Persistent Disenchant works using right-click.
- Quest class-12 categorization and manual precedence work.

## TODO / Untested

- Rogue Pick Lock workflow.
- Temporary active-quest objective detection for ordinary item-class items; implemented but not yet encountered in-game.
- DE discoverability: targeting-style cursor / candidate-item hover feedback; keep right-click behaviour.
- Custom tiny toolbar artwork: Search, Sort, Options, DE, Pick, Open. Built-in pfUI art was judged too small/muddy; this is pinned for later.
- Consider reducing the 0.20s toolbar layout refresh only if profiling or visible behaviour justifies it.

## Branches

- `main`: stable user branch; no HANDOFF.md.
- `dev`: active development branch; keep this HANDOFF.md current.
