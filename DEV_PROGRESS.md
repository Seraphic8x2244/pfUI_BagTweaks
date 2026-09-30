# pfUI BagTweaks Development Progress

## Current
- Branch: `dev`
- Version: `0.1.44-dev`
- Development head: `57a741cca2ce75c6785d612cdb4301866c567594` (pre-status-update branch head; Auto resort delay implementation complete)
- Stable baseline: `0.1.42` / `25474f32f5e20d189c73f84caa6af3e10f30584a`
- Goal: Runtime-validate the implemented Auto resort delay before starting the next planned feature.
- Current scope boundary: Address the auto-sort interaction problem first. Do not broaden this work into unrelated bag layout, classification, persistence or toolbar refactors. Then implement multi-account-wide item tracking, followed by open-all-containers-on-right-click.

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
- Multi-account-wide item tracking is planned after the auto-resort interaction work; its exact persistence model and scope must be designed before implementation.
- Open all containers on right click is planned immediately after multi-account-wide item tracking; exact interaction ownership/target surface still needs inspection before implementation.

### Auto Resort Delay — Agreed Design
- Product rationale: prevent mis-clicks caused by BagTweaks moving another item into the screen position the user is about to click while they are rapidly selling, opening, unlocking or disenchanting inventory items.
- User setting: **Auto resort delay**.
- Range: **0–10 seconds**.
- Default: **3 seconds**.
- `0` means no grace period: automatic visual resort happens immediately, matching current behaviour as closely as possible.
- Tooltip text: **"Delay automatic bag rearrangement after selling, opening or disenchanting items."**
- The delay is an inactivity/grace timer, not a fixed freeze for the entire merchant or Disenchant session.
- Each relevant inventory interaction resets the deadline to `now + configuredDelay`. Repeated actions therefore keep the visible item positions stable. After the configured quiet period expires, BagTweaks performs one coalesced visual relayout.
- Relevant workflows for the first implementation:
  - selling items at a merchant;
  - opening ordinary openable containers through the pfUI/BagTweaks Open Container control;
  - BagTweaks persistent Disenchant workflow;
  - Pick Lock activity, so lockbox work cannot cause item positions to shuffle underneath subsequent clicks.
- Lockboxes are not treated as a special container type. pfUI exposes opening and Pick Lock as separate actions: Pick Lock participates in interaction protection, and once the unlocked box is actually opened that opening resets the same auto-resort delay.
- The later Open All Containers feature must reuse the same protection: every container-open/inventory-change operation extends the same inactivity deadline rather than introducing a second sorting scheduler.

### Auto Resort Delay — Runtime Path / Programming Notes
- Confirmed visual churn path: pfUI coalesces `BAG_UPDATE`, calls `pfUI.bag:UpdateBag`, BagTweaks' wrapper calls `RequestRelayout()`, and deferred `RelayoutView()` recollects/sorts items and reanchors the existing clickable slot frames.
- The underlying physical inventory is not being sorted by BagTweaks during this path; the risk comes from reanchoring the visible slot frames after contents change.
- Do **not** delay or suppress pfUI's own `UpdateBag` / slot update work. Icons, counts, empty slots, lock state and other actual inventory state must update immediately.
- Delay only BagTweaks' **automatic visual relayout** scheduling. Explicit user-driven BagTweaks layout changes (category edits, sort-mode changes, empty-category toggle, etc.) and required structural `CreateBags` rebuilds remain immediate unless a concrete runtime issue proves otherwise.
- `RequestRelayout()` should become a coalescing inactivity scheduler:
  - mark automatic relayout dirty when one is requested;
  - if the configured delay is `0`, schedule/run using the existing immediate-next-frame behaviour;
  - when a protected interaction occurs, set/reset an auto-resort deadline from `GetTime()`;
  - while dirty and before that deadline, do not reanchor item frames;
  - when the deadline expires, perform one relayout and clear the dirty state;
  - if another protected interaction occurs before expiry, extend the deadline rather than queueing another relayout.
- The deferred driver must check the current deadline again immediately before calling `Relayout()`, closing the race where an interaction occurs after a relayout was already scheduled.
- Vendoring has explicit `MERCHANT_SHOW` / `MERCHANT_CLOSED` lifecycle events in the target brues-code pfUI fork, but the chosen design is **not** to freeze for the whole merchant window. Merchant state is context for identifying/protecting sale-driven inventory churn; the inactivity deadline controls when visual movement resumes.
- Disenchant uses BagTweaks' existing persistent mode and `ContainerFrameItemButton_OnClick` interception, then invokes pfUI's native Disenchant targeting and `PickupContainerItem`. Existing `SPELLCAST_*` events may assist lifecycle awareness but must not cause an immediate relayout between sequential disenchant actions.
- pfUI's Open Container control finds items through `C_Container.IsContainerItemOpenable` and opens the next candidate with `UseContainerItem`; BagTweaks' replacement toolbar currently calls that native Open handler. This is the entry point to mark/reset container-opening interaction protection.
- Pick Lock remains a separate pfUI spell path. Protect the BagTweaks persistent Pick Lock workflow from relayout churn even though the tooltip summarizes the user-visible item-changing operations as selling/opening/disenchanting.
- Avoid a broad "delay every BAG_UPDATE" policy unless runtime evidence requires it. The design target is interaction-caused churn, not unrelated inventory changes such as loot arriving while the user is idle.
- No new module/system is required; preserve the current single-main-Lua architecture and existing relayout ownership.

## Recent Relevant Commits
- `57a741cca2ce75c6785d612cdb4301866c567594` — Bump BagTweaks to 0.1.44-dev for Auto resort delay runtime validation.
- `2f2ba7cdc9c355c66ab6c06e80cb410cee3244eb` — Implement the inactivity-based Auto resort delay and protected interaction hooks.
- `015ccdea2b2364a12057767454f49f64ba86c266` — Add Auto resort delay option/tooltip locale strings.
- `0d8b539c7de11fb98a8dd0e549daaad42c7946ed` — Document the agreed Auto resort delay design.
- `7c92f38f9844b836020fc86fbb0059146534f9bf` — Record initial interaction-hold design; superseded by the inactivity-delay design now documented below.
- `3533868b96e7f78c548400ade88a10b5d02d9f9f` — Record open-all-containers right-click backlog item.
- `ae65255ab1e1cdb2b16d647c93e41914bc71b208` — Adopt canonical VanillaTemplate development workflow.
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
- 0.1.44-dev adds `Auto resort delay` as a 0–10 second dropdown, default `3`; `0` preserves the existing immediate-next-frame automatic relayout behaviour.
- Automatic `RequestRelayout()` work is now dirty/coalesced behind one inactivity deadline. Protected actions reset that deadline; repeated actions extend it; one relayout runs after the quiet period.
- pfUI `UpdateBag` still runs before BagTweaks requests a relayout, so item icons, counts, empty-slot state and locks remain immediate while only BagTweaks frame reanchoring is delayed.
- Protected interaction entry points are: right-click selling while the merchant is open; BagTweaks Open Container; successful persistent Disenchant targeting; and persistent Pick Lock target clicks. Unrelated `BAG_UPDATE` activity does not itself start a delay.
- Direct BagTweaks layout changes and structural `CreateBags` relayouts still bypass the automatic scheduler and remain immediate.
- 0.1.43-dev guards SavedVariables startup normalization so already-valid category/subcategory structures, IDs, Quest fields, legacy fields and schema version are only rewritten when a real migration/repair/normalization change is required.
- One-time legacy migration and malformed-state repair behaviour are retained.

## Static / Automated Checks
- Static diff review of the 0.1.44-dev Auto resort delay implementation passed: automatic scheduling is isolated to `RequestRelayout()`; direct `Relayout()` / `CreateBags` paths remain immediate; protected hooks are limited to selling, Open Container, Disenchant and Pick Lock.
- Static local-count inspection: the main pfUI module callback has 143 top-level local declarations after this change, below Lua 5.0.3's 200-local compiler limit. This is not a compiler pass.
- Canonical Lua 5.0.3 compiler check: not run. The canonical checker is readable through the private `VanillaTemplate` GitHub connector but is not mounted in the executable environment; no system `lua`/`luac` is installed, and outbound network access is unavailable, so the vendored checker could not be built here.
- Static diff review of the 0.1.43-dev SavedVariables fix passed.

## Current Issues
- Auto resort delay is implemented but not yet runtime-validated in WoW 1.12.1; interaction timing and the immediate pfUI slot-update invariant still require in-game confirmation.
- Raw SavedVariables backups may differ only in Lua table key order even when their BagTweaks state is semantically identical.

## Testing

### Last Runtime Test
- Version/commit: `0.1.42` / stable release baseline
- Passed: addon load, branding, existing SavedVariables/categories, backpack/bank behaviour and toolbar/artwork.
- Failed: None reported.
- Not tested: 0.1.43-dev SavedVariables no-op normalization delta; legacy Quest migration/repair remains non-reproducible on available affected clients.

### Next Runtime Test
- After Auto resort delay is implemented, test values `0`, `3` and `10` seconds.
- With the default `3` seconds, rapidly sell several items and confirm remaining clickable item frames do not shift between clicks; confirm one visual resort occurs about 3 seconds after the last protected interaction.
- Repeat with consecutive container opens, consecutive Disenchants, and the Pick Lock/lockbox workflow.
- Confirm repeated protected actions reset/extend the same deadline rather than allowing intermediate relayouts.
- Confirm pfUI still updates item icons/counts/empty slots immediately during the grace period.
- Confirm explicit BagTweaks category/sort changes still relayout immediately.
- Also confirm one deliberate BagTweaks setting/category change still persists normally on the 0.1.43-dev lineage.

## Planned / Next Work
1. Runtime-test Auto resort delay at `0`, `3` and `10` seconds across selling, consecutive container opens, Disenchant and Pick Lock.
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
Runtime-test `0.1.44-dev` Auto resort delay using the documented `0`, `3` and `10` second checks. Do not start multi-account-wide tracking or open-all-containers-on-right-click until this slice is accepted.
