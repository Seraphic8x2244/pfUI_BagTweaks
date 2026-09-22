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
- User supplied before/after SavedVariables files from the backup manager. They contain the same observed BagTweaks state but are serialized in different table-key order.
- Examples include top-level sections moving position, fields inside subcategory records changing order, and account/character item-assignment keys being emitted in different order while retaining the same values.
- This is textual serialization-order churn from unordered Lua tables, not evidence of a BagTweaks setting/category mutation.
- 0.1.43-dev still correctly removes addon-side no-op normalization writes, but those guards cannot make WoW's table serialization order stable.

## Testing

### Last Test
- Version/commit: 0.1.42 migration release.
- Passed: addon load, branding, existing SavedVariables/categories, backpack/bank behaviour and toolbar/artwork.
- Failed: None reported at release time.
- Not tested: 0.1.43-dev SavedVariables fix; legacy Quest migration/repair remains non-reproducible on available affected clients.

### Next Test
- No further no-op mutation test is needed to explain the supplied raw-text diff: the observed change is table serialization order.
- Confirm one deliberate BagTweaks change still persists normally on 0.1.43-dev.
- If strict byte/text-stable SavedVariables are required, decide explicitly between changing the backup manager to compare Lua tables semantically or redesigning BagTweaks' persisted schema into a canonical ordered representation.

## Planned / To-do
- Keep the 0.1.43-dev idempotent-normalization fix.
- Do not add further write guards for the supplied diff; they cannot control serializer key order.
- Prefer semantic/canonical comparison in backup tooling over redesigning BagTweaks persistence solely for text-order stability.

## Ideas / Backlog
- Rogue Pick Lock workflow test.
- Disenchant targeting-cursor / candidate-item hover discoverability.
- Remaining direct-toolbar edge-case checks.
- Reduce the 0.20s toolbar layout refresh only if profiling or visible behaviour justifies it.

## Deferred
- Packing optimisation unless future inventories show a real problem.
- Unrelated refactors while fixing SavedVariables churn.

## Exact Next Step
Treat the supplied before/after files as serialization-order-only churn. Keep 0.1.43-dev as-is and, if the backup manager must stop flagging this, change its comparison to canonical/semantic Lua-table comparison rather than raw line ordering.
