# pfUI BagTweaks Development Progress

## Current
- Branch: `dev`
- Version: `0.1.41-dev`
- Goal: Smoke-test the completed VanillaTemplate workflow/name migration without changing existing bag behaviour.
- Workflow: Migrated to the canonical `VanillaTemplate` development contract.

## Recent Commits
- `08b5d750903522eedc9d34dce0decdf59c6dd9de` — Restore the standard pfUI colour treatment in the addon-list title.
- `e1f4fd7e2896de9a2b42ae69b6fec635edf5b225` — Migrate pfUI BagTweaks to canonical workflow.
- `7a2222089480eb0b923487fbc5842b258ebe45a6` — Adopt canonical development handoff.
- `59659ad105137dc2efc50ef2aa1dafe3ade941e9` — Record 0.1.41 stable promotion.
- `599b3babc16493e8b481ef18bb2fbe2dec1f7f5e` — Stable `main` release 0.1.41.

## Completed / Verified
- Stable release `0.1.41` remains on `main`; active development remains on `dev`.
- Lucide Close/X integration, hover/tooltip, native close action, responsive sizing and normal/wrapped toolbar geometry were confirmed in game before the workflow migration.
- Downward internal toolbar wrapping, bag background/border coherence and height behaviour were confirmed in game.
- Regenerated Eye/EyeOff toolbar assets render correctly in game.
- Backpack/bank persistent Disenchant/Pick mode disarm behaviour was confirmed for bag close, bank close and world transition.
- L-shaped Subcategory accent and Disenchant left-click targeting were confirmed in game.

## Implemented / Awaiting Test
- Canonical workflow migration:
  - `DEV_GUIDE.md` adopted unchanged from VanillaTemplate.
  - legacy `HANDOFF.md` replaced by concise `DEV_PROGRESS.md`.
  - visible addon branding normalized to `pfUI BagTweaks`; technical addon identity remains `pfUI_BagTweaks`.
  - addon-list title retains the standard pfUI colour treatment: `|cff33ffccpf|cffffffffUI|r BagTweaks-dev`.
  - dev TOC title is `pfUI BagTweaks-dev`; version remains `0.1.41-dev`.
  - TOC is the sole version source; Lua reads `ADDON_VERSION` through `GetAddOnMetadata`.
  - localization moved from root `locales.lua` to `locales/enUS.lua`.
  - all 19 artwork/licence files flattened into `artwork/`; all original Git blob SHAs were preserved.
  - all 14 live toolbar texture paths now point to `Interface\\AddOns\\pfUI_BagTweaks\\artwork\\...`.
- Static migration checks passed:
  - no root `locales.lua`, legacy `HANDOFF.md`, `textures/` files or old texture-path references remain.
  - no hardcoded `0.1.41-dev` version remains in Lua.
  - visible locale and README branding resolve to `pfUI BagTweaks`.
  - remaining `pfUI_BagTweaks` occurrences are intentional technical identifiers: `ADDON_NAME`, Lua filename/TOC entry and addon-folder texture paths.
- Legacy Quest migration/repair improvements from 0.1.33-dev remain code-reviewed but are not currently reproducible on available affected clients.

## Current Issues
- None known.

## Testing

### Last Test
- Version/commit: pre-migration `0.1.41-dev`.
- Passed: Close/X integration, hover/tooltip, native close action, responsive toolbar sizing, wrapped toolbar geometry, downward internal wrapping/background/height behaviour.
- Failed: None reported.
- Not tested: current canonical workflow/file-layout migration at `e1f4fd7`.

### Next Test
- Install current `dev`.
- Confirm addon-list title renders as coloured `pfUI BagTweaks-dev`.
- Confirm pfUI Thirdparty/options entry and header show `pfUI BagTweaks`.
- Confirm localized labels resolve normally.
- Confirm existing SavedVariables/categories/subcategories remain intact.
- Confirm backpack and bank open normally.
- Confirm all toolbar icons, Eye/EyeOff and Close/X render correctly from the new flat `artwork/` path.

## Planned / To-do
- Complete the migration smoke test above.
- After that, continue new BagTweaks work from `dev`.
- Keep `main` untouched until a tested stable state is explicitly approved for promotion.

## Ideas / Backlog
- Rogue Pick Lock workflow test.
- Disenchant targeting-cursor / candidate-item hover discoverability.
- Remaining direct-toolbar edge-case checks: active overlays, conditional visibility, multi-Category New Subcategory selection, third-party ordering and Options artwork.
- Reduce the 0.20s toolbar layout refresh only if profiling or visible behaviour justifies it.

## Deferred
- Packing optimisation unless future inventories show a real problem.
- Any unrelated refactor during the workflow migration.

## Exact Next Step
Install current `dev` at `08b5d75` and perform the migration smoke test, starting with the coloured addon-list title, pfUI branding and toolbar artwork loading.
