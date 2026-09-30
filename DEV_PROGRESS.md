# pfUI BagTweaks Development Progress

## Current
- Branch: `dev`
- Version: `0.1.43-dev`
- Development head: `d7b2042927edb0f159f0b5f98fd1e1601586f65e` (last addon/runtime-changing development state; the workflow-migration commit after this is documentation-only)
- Stable baseline: `0.1.42` / `25474f32f5e20d189c73f84caa6af3e10f30584a`
- Goal: Add an interaction-aware delay/suppression to automatic visual sorting so item locations do not churn while the user is actively interacting with inventory items.
- Current scope boundary: Address the auto-sort interaction problem first. Do not broaden this work into unrelated bag layout, classification, persistence or toolbar refactors. Multi-account-wide item tracking is the next planned feature after this task.

## Current Design / Development Contract

### Architecture / Ownership
- BagTweaks is a pfUI plugin for WoW 1.12.1 and keeps pfUI as the owner of physical inventory sorting.
- BagTweaks' categorization/layout is visual; it must not physically move inventory except through the explicit pfUI Sort control.
- Existing single-main-Lua architecture is preserved unless a concrete requirement justifies a structural change.
- Existing `artwork/` layout is retained; workflow adoption does not rename runtime asset paths merely to match the newer template default.

### Invariants
- User-created Categories contain dynamically packed Subcategories.
- Manual item categorization takes priority over automatic rules such as Quest.
- Deleting a user Subcategory releases its saved item assignments rather than creating permanent General overrides.
- General remains fixed at the bottom and contains all empty physical slots.
- Layout width, item size, borders, anchoring and physical sorting continue to respect pfUI bag settings.
- Existing native functionality must not become DLL-dependent without an explicit reason.

### Protocol / Data Model
- SavedVariables: `pfUIBagTweaksDB`.
- Current-schema startup normalization is intended to be idempotent: valid data should not be rewritten merely by logging in.
- Raw SavedVariables text/key order is not a stable semantic representation because Lua table serialization order is unordered.
- One-time legacy migration and malformed-state repair remain supported.

### Active Decisions
- The supplied before/after SavedVariables differences were serialization-order churn, not evidence of a BagTweaks state mutation.
- Keep the 0.1.43-dev no-op normalization guards; do not add further guards merely to chase raw key-order differences.
- If byte/text-stable backup comparison is ever required, prefer semantic/canonical comparison in the backup tooling rather than redesigning BagTweaks persistence solely for textual ordering.
- Auto-sort delay/suppression should protect active item interactions such as vendoring and disenchanting from visual item-location churn. The trigger and timing mechanism are not yet chosen and must be based on the actual event/interaction paths rather than an arbitrary delay.
- Multi-account-wide item tracking is planned after the auto-sort interaction work; its exact persistence model and scope must be designed before implementation.

## Recent Relevant Commits
- `d7b2042927edb0f159f0b5f98fd1e1601586f65e` — Record SavedVariables serialization-order finding.
- `01f6564ba7aa8cbb3de80fb285bda1ed45894afb` — Record SavedVariables no-op fix for testing.
- `300f2c3bbb3038bacf31c59b57ef5cb535ad8654` — Bump BagTweaks to 0.1.43-dev.
- `4b0d0cfb4a7adbf13165259b046a00ad4f1a2de5` — Avoid no-op SavedVariables normalization.
- `25474f32f5e20d189c73f84caa6af3e10f30584a` — Release pfUI BagTweaks 0.1.42 to `main`.

## Completed / User-Verified
- Stable release `0.1.42` is on `main`.
- Canonical workflow/name migration smoke test passed in game for 0.1.42.
- Existing SavedVariables/categories, backpack/bank behaviour, toolbar, Eye/EyeOff and Close/X artwork were confirmed good for 0.1.42.

## Implemented / Awaiting Runtime Test
- 0.1.43-dev guards SavedVariables startup normalization so already-valid category/subcategory structures, IDs, Quest fields, legacy fields and schema version are only rewritten when a real migration/repair/normalization change is required.
- One-time legacy migration and malformed-state repair behaviour are retained.
- No bag layout, classification, sorting or toolbar paths were changed by the 0.1.43-dev SavedVariables fix.

## Static / Automated Checks
- Static diff review of the 0.1.43-dev SavedVariables fix passed.
- Canonical Lua 5.0.3 compiler check: not recorded as run for the current 0.1.43-dev state.

## Current Issues
- Automatic visual sorting can churn item locations while the user is actively interacting with inventory items, making it easier to click the wrong item during workflows such as vendoring or disenchanting.
- Raw SavedVariables backups may differ only in Lua table key order even when their BagTweaks state is semantically identical.

## Testing

### Last Runtime Test
- Version/commit: `0.1.42` / stable release baseline
- Passed: addon load, branding, existing SavedVariables/categories, backpack/bank behaviour and toolbar/artwork.
- Failed: None reported.
- Not tested: 0.1.43-dev SavedVariables no-op normalization delta; legacy Quest migration/repair remains non-reproducible on available affected clients.

### Next Runtime Test
- After the auto-sort delay/suppression is implemented, exercise it during at least vendoring and disenchanting, then confirm normal automatic visual sorting resumes when the interaction ends.
- Also confirm one deliberate BagTweaks setting/category change still persists normally on the 0.1.43-dev lineage.

## Planned / Next Work
1. Auto-sort interaction delay/suppression while actively vendoring, disenchanting or performing similar item interactions.
2. Multi-account-wide item tracking.
3. Open all containers on right click.
4. Rogue Pick Lock workflow test.
5. Disenchant targeting-cursor / candidate-item hover discoverability.
6. Remaining direct-toolbar edge-case checks.
7. Reduce the 0.20s toolbar layout refresh only if profiling or visible behaviour justifies it.

## Deferred / Out of Scope
- Packing optimisation unless future inventories show a real problem.
- Unrelated refactors while addressing auto-sort interaction churn.
- Persisted-schema redesign solely for raw SavedVariables text-order stability.

## Release / Promotion Notes
- Main-only or release-only content to preserve: stable `.toc` Title/Version metadata; development contract/status files are not part of stable releases.
- Known validation debt accepted for release: None currently.
- External/runtime prerequisites: pfUI. Nampower, SuperWoW and ClassicAPI remain optional capability enhancements unless a future feature explicitly requires one.

## Exact Next Step
Inspect the current automatic visual-sort/rebuild path and the inventory interaction events used during vendoring and disenchanting, then design the narrowest interaction-aware suppression/resume mechanism before changing runtime code.
