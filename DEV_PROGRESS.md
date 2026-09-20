# pfUI BagTweaks Development Progress

## Current
- Branch: `dev`
- Version: `0.1.42-dev`
- Goal: Smoke-test the completed VanillaTemplate workflow/name migration without changing existing bag behaviour.
- Workflow: Migrated to the canonical `VanillaTemplate` development contract.

## Recent Commits
- `25474f32f5e20d189c73f84caa6af3e10f30584a` — Release pfUI BagTweaks 0.1.42 to `main`.
- `6f0c66752f59cf6e181303f32d390c4fb533e681` — Prepare pfUI BagTweaks 0.1.42 release.
- Release preparation: migration smoke test confirmed good in game; promote as `0.1.42`.
- `08b5d750903522eedc9d34dce0decdf59c6dd9de` — Restore the standard pfUI colour treatment in the addon-list title.
- `e1f4fd7e2896de9a2b42ae69b6fec635edf5b225` — Migrate pfUI BagTweaks to canonical workflow.
- `7a2222089480eb0b923487fbc5842b258ebe45a6` — Adopt canonical development handoff.
- `59659ad105137dc2efc50ef2aa1dafe3ade941e9` — Record 0.1.41 stable promotion.
- `599b3babc16493e8b481ef18bb2fbe2dec1f7f5e` — Stable `main` release 0.1.41.

## Completed / Verified
- Stable release `0.1.42` is on `main` at `25474f3`; active development remains on `dev`.
- Canonical workflow/name migration smoke test passed in game: addon loads correctly, coloured addon-list title is correct, pfUI branding is correct, existing SavedVariables remain intact, backpack/bank behaviour is good, and migrated artwork renders correctly.
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
- Version/commit: migrated `dev` at `3fa56a0` (release metadata only will move to `0.1.42-dev`).
- Passed: addon loads correctly; coloured `pfUI BagTweaks-dev` addon-list title; pfUI branding; existing SavedVariables/categories; backpack/bank behaviour; toolbar, Eye/EyeOff and Close/X artwork from `artwork/`.
- Failed: None reported.
- Not tested: legacy Quest migration/repair remains non-reproducible on available affected clients.

### Next Test
- None required for the migration release.

## Planned / To-do
- Continue new BagTweaks work from `dev`.

## Ideas / Backlog
- Rogue Pick Lock workflow test.
- Disenchant targeting-cursor / candidate-item hover discoverability.
- Remaining direct-toolbar edge-case checks: active overlays, conditional visibility, multi-Category New Subcategory selection, third-party ordering and Options artwork.
- Reduce the 0.20s toolbar layout refresh only if profiling or visible behaviour justifies it.

## Deferred
- Packing optimisation unless future inventories show a real problem.
- Any unrelated refactor during the workflow migration.

## Exact Next Step
Continue new BagTweaks work from `dev`; `main` is the stable 0.1.42 baseline.
