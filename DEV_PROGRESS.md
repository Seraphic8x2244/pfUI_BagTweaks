# pfUI BagTweaks Development Progress

## Current
- Branch: `dev`
- Version: `0.1.42-dev`
- Goal: Eliminate unnecessary SavedVariables churn on normal logins while preserving one-time migration/repair behaviour.
- Workflow: Canonical `VanillaTemplate` development contract.

## Recent Commits
- `25474f32f5e20d189c73f84caa6af3e10f30584a` — Release pfUI BagTweaks 0.1.42 to `main`.
- `6f0c66752f59cf6e181303f32d390c4fb533e681` — Prepare pfUI BagTweaks 0.1.42 release.
- `08b5d750903522eedc9d34dce0decdf59c6dd9de` — Restore the standard pfUI colour treatment in the addon-list title.
- `e1f4fd7e2896de9a2b42ae69b6fec635edf5b225` — Migrate pfUI BagTweaks to canonical workflow.
- `7a2222089480eb0b923487fbc5842b258ebe45a6` — Adopt canonical development handoff.

## Completed / Verified
- Stable release `0.1.42` is on `main`; active development remains on `dev`.
- Canonical workflow/name migration smoke test passed in game.
- Existing SavedVariables/categories, backpack/bank behaviour, toolbar, Eye/EyeOff and Close/X artwork were confirmed good for 0.1.42.
- Earlier SavedVariables work intentionally avoided rewriting already-valid defaults/migrations during normal startup.

## Implemented / Awaiting Test
- No code fix yet for the newly reported SavedVariables churn.
- Investigation found a regression in the current Category/Subcategory schema startup path:
  - startup now unconditionally reassigns several already-valid scalar/table fields;
  - `NormalizeCategories()` rebuilds every Category's `subcategories` array on every startup even when its contents are already canonical;
  - the older implementation explicitly guarded equivalent normalization so normal logins left a valid database untouched.
- One-time legacy migrations and malformed-state repair must remain intact.

## Current Issues
- SavedVariables backup tooling is observing BagTweaks edits/churn even when the user has made no BagTweaks setting/category changes.
- Most likely addon-side cause: non-idempotent/in-place startup normalization introduced during the Category/Subcategory migration.

## Testing

### Last Test
- Version/commit: 0.1.42 migration release.
- Passed: addon load, branding, existing SavedVariables/categories, backpack/bank behaviour and toolbar/artwork.
- Failed: None reported at release time.
- Not tested: legacy Quest migration/repair remains non-reproducible on available affected clients.

### Next Test
- Compare `pfUIBagTweaksDB.lua` before and after a login/logout cycle with no BagTweaks interaction.
- Confirm a valid current-schema DB remains byte-for-byte semantically unchanged by addon startup.
- Confirm deliberate BagTweaks changes still persist.
- Regression-check legacy migration/repair logic statically; in-game legacy-state reproduction remains optional if unavailable.

## Planned / To-do
- Restore guarded/idempotent SavedVariables normalization.
- Avoid replacing canonical `subcategories` arrays unless cleanup actually changes their contents.
- Avoid assigning already-correct scalar fields during startup where practical.
- Keep malformed/legacy repair behaviour unchanged.

## Ideas / Backlog
- Rogue Pick Lock workflow test.
- Disenchant targeting-cursor / candidate-item hover discoverability.
- Remaining direct-toolbar edge-case checks.
- Reduce the 0.20s toolbar layout refresh only if profiling or visible behaviour justifies it.

## Deferred
- Packing optimisation unless future inventories show a real problem.
- Unrelated refactors while fixing SavedVariables churn.

## Exact Next Step
Patch `pfUI_BagTweaks.lua` on `dev` so startup normalization is idempotent: only write a SavedVariables field or replace a Category subcategory list when the stored value actually needs migration/repair, then perform a static diff review before asking for the no-op login/logout test.
