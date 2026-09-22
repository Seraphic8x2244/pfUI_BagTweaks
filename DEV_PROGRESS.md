# pfUI BagTweaks Development Progress

## Current
- Branch: `dev`
- Version: `0.1.43-dev`
- Goal: Verify the SavedVariables no-op startup fix in game.
- Workflow: Canonical `VanillaTemplate` development contract.

## Recent Commits
- `300f2c3bbb3038bacf31c59b57ef5cb535ad8654` — Bump BagTweaks to 0.1.43-dev.
- `4b0d0cfb4a7adbf13165259b046a00ad4f1a2de5` — Avoid no-op SavedVariables normalization.
- `27bdaa4036c3c7e229fb6a9fc138074b8c5afe99` — Document SavedVariables churn investigation.
- `25474f32f5e20d189c73f84caa6af3e10f30584a` — Release pfUI BagTweaks 0.1.42 to `main`.
- `6f0c66752f59cf6e181303f32d390c4fb533e681` — Prepare pfUI BagTweaks 0.1.42 release.

## Completed / Verified
- Stable release `0.1.42` is on `main`; active development remains on `dev`.
- Canonical workflow/name migration smoke test passed in game.
- Existing SavedVariables/categories, backpack/bank behaviour, toolbar, Eye/EyeOff and Close/X artwork were confirmed good for 0.1.42.
- The earlier design rule that normal logins should not mutate an already-valid database has been restored in 0.1.43-dev.

## Implemented / Awaiting Test
- SavedVariables startup normalization is now guarded/idempotent:
  - current-schema `categories` and `subcategories` tables are not reassigned when already present;
  - legacy fields are only cleared when they actually exist;
  - numeric IDs are only rewritten when normalization changes their stored value;
  - Quest system fields are only rewritten when repair is needed;
  - canonical Category `subcategories` arrays are preserved instead of rebuilt on every startup;
  - `schemaVersion` is only written when it differs.
- One-time legacy migration and malformed-state repair behaviour is retained.
- Static diff review passed; no bag layout, classification, sorting or toolbar paths were changed.

## Current Issues
- User reported SavedVariables backup tooling detecting BagTweaks file edits despite no intentional BagTweaks changes.
- 0.1.43-dev addresses addon-side no-op DB mutation.
- WoW may still rewrite/touch a registered SavedVariables file during logout/reload even when serialized content is unchanged. If the backup tool reacts only to modification time/write events, that remaining behaviour is client-owned rather than BagTweaks-owned.

## Testing

### Last Test
- Version/commit: 0.1.42 migration release.
- Passed: addon load, branding, existing SavedVariables/categories, backpack/bank behaviour and toolbar/artwork.
- Failed: None reported at release time.
- Not tested: 0.1.43-dev SavedVariables fix; legacy Quest migration/repair remains non-reproducible on available affected clients.

### Next Test
- On `0.1.43-dev`, make no BagTweaks changes.
- Capture/compare the contents of `pfUIBagTweaksDB.lua` before and after a login/logout or `/reload`.
- Confirm the serialized DB content is unchanged.
- If backup software still flags it while file contents are identical, treat that as timestamp/write-event detection by the client rather than addon data churn.
- Confirm one deliberate BagTweaks change still persists normally.

## Planned / To-do
- User-test 0.1.43-dev no-op SavedVariables behaviour.
- If an actual content diff remains, inspect that exact before/after diff and remove the remaining non-idempotent path without broad refactoring.

## Ideas / Backlog
- Rogue Pick Lock workflow test.
- Disenchant targeting-cursor / candidate-item hover discoverability.
- Remaining direct-toolbar edge-case checks.
- Reduce the 0.20s toolbar layout refresh only if profiling or visible behaviour justifies it.

## Deferred
- Packing optimisation unless future inventories show a real problem.
- Unrelated refactors while fixing SavedVariables churn.

## Exact Next Step
Install/test `0.1.43-dev` with no BagTweaks interaction and compare the SavedVariables file contents before/after. If the contents differ, use that exact diff to identify the remaining writer; if only the file timestamp changes, no further BagTweaks data-write fix is indicated.
