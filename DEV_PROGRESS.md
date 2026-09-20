# pfUI BagTweaks Development Progress

## Current
- Branch: `dev`
- Version: `0.1.41-dev`
- Goal: Migrate pfUI BagTweaks to the canonical VanillaTemplate workflow and normalize user-facing branding without changing bag behaviour.
- Workflow: Migration in progress from the legacy `HANDOFF.md` model to `DEV_GUIDE.md` + `DEV_PROGRESS.md`.

## Recent Commits
- `59659ad105137dc2efc50ef2aa1dafe3ade941e9` — Record 0.1.41 stable promotion.
- `599b3babc16493e8b481ef18bb2fbe2dec1f7f5e` — Stable `main` release 0.1.41.
- `5aba63f` — Integrate the native Close button into BagTweaks toolbar sizing/visuals.
- `474dbc4` — Preserve Close hover state across periodic relayout.
- `b937712` — Move toolbar overflow rows downward inside the bag and reserve their exact height.

## Completed / Verified
- Stable release `0.1.41` is on `main`; active development remains on `dev`.
- Lucide Close/X integration, hover/tooltip, native close action, responsive sizing and normal/wrapped toolbar geometry were confirmed in game.
- Downward internal toolbar wrapping, bag background/border coherence and height behaviour were confirmed in game.
- Regenerated Eye/EyeOff toolbar assets render correctly in game.
- Backpack/bank persistent Disenchant/Pick mode disarm behaviour was confirmed for bag close, bank close and world transition.
- L-shaped Subcategory accent and Disenchant left-click targeting were confirmed in game.

## Implemented / Awaiting Test
- Legacy Quest migration/repair improvements from 0.1.33-dev remain code-reviewed but are not currently reproducible on available affected clients.
- Remaining direct-toolbar interaction/edge-case checks include active overlays, conditional visibility, multi-Category New Subcategory selection, third-party ordering and Options artwork.

## Current Issues
- None known.

## Testing

### Last Test
- Version/commit: `0.1.41-dev` before stable promotion.
- Passed: Close/X integration, hover/tooltip, native close action, responsive toolbar sizing, wrapped toolbar geometry, downward internal wrapping/background/height behaviour.
- Failed: None reported.
- Not tested: Canonical workflow/file-layout migration has not yet been applied.

### Next Test
- After the migration commit, install current `dev`.
- Confirm addon-list title is `pfUI BagTweaks-dev`.
- Confirm pfUI options show `pfUI BagTweaks`.
- Confirm localized labels resolve normally.
- Confirm existing SavedVariables/categories remain intact.
- Confirm backpack and bank open normally and all toolbar/Eye/Close artwork renders from the new flat `artwork/` path.

## Planned / To-do
- Adopt `DEV_GUIDE.md` unchanged from VanillaTemplate.
- Replace legacy `HANDOFF.md` with this concise `DEV_PROGRESS.md`.
- Normalize visible branding to `pfUI BagTweaks` while retaining technical identifier `pfUI_BagTweaks`.
- Make the TOC the sole version source and read `ADDON_VERSION` with `GetAddOnMetadata`.
- Move `locales.lua` to `locales/enUS.lua`.
- Flatten all addon artwork into `artwork/` and update texture paths without changing asset bytes.
- Keep `main` untouched until the migrated `dev` build is user-tested and explicitly promoted.

## Ideas / Backlog
- Rogue Pick Lock workflow test.
- Disenchant targeting-cursor / candidate-item hover discoverability.
- Reduce the 0.20s toolbar layout refresh only if profiling or visible behaviour justifies it.

## Deferred
- Packing optimisation unless future inventories show a real problem.
- Any unrelated refactor during the workflow migration.

## Exact Next Step
Apply the canonical file-layout, version-source and `pfUI BagTweaks` branding migration on `dev` without changing runtime bag behaviour.
