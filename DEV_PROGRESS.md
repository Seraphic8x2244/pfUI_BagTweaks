# pfUI BagTweaks Development Progress

## Current
- Branch: `dev`
- Version: `0.1.44-dev`
- Development head: `3c6dba19240ec83de1fcf1551283b93c136303d2` (pre-preflight-documentation branch head; Auto resort delay remains the latest runtime-changing checkpoint)
- Stable baseline: `0.1.42` / `25474f32f5e20d189c73f84caa6af3e10f30584a`
- Goal: Preserve `0.1.44-dev` as the Auto resort delay checkpoint, then begin the Account Inventory feature line at `0.5.0-dev` while runtime testing is deferred until the user is home.
- Current scope boundary: Keep each additional feature in its own versioned/committed stepping stone for fault isolation and reversibility. Account Inventory / multi-account-wide item tracking starts a deliberate `0.5.x` development line at `0.5.0-dev`; after that, open-all-containers-on-right-click. Do not fold unrelated refactors into either checkpoint.

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
- Multi-account-wide item tracking design is now agreed below. It must be implemented as its own versioned checkpoint after `0.1.44-dev`, without altering the Auto resort delay behaviour unless a concrete dependency requires it.
- The user will batch runtime-test these checkpoints later; implemented-but-untested status must remain explicit for each version so regressions can be isolated by stepping back through known commits.
- Open all containers on right click is planned immediately after multi-account-wide item tracking; exact interaction ownership/target surface still needs inspection before implementation.

### Multi-Account Item Tracking — Agreed Design
- Native WoW SavedVariables remain account-local. BagTweaks cannot use normal addon SavedVariables to directly read a sibling WoW account's `WTF\\Account\\<account>\\SavedVariables` data.
- Cross-account inventory sharing will therefore use Nampower's custom-file capability in the shared WoW installation. This is an optional enhancement: without the required custom-file API, BagTweaks must continue working normally with its existing per-account SavedVariables behaviour.
- Keep existing BagTweaks categories, subcategories, assignments and ordinary settings in `pfUIBagTweaksDB`. The custom-file system is for cross-account inventory/item tracking, not a wholesale replacement for SavedVariables.
- Each WoW account gets a stable opaque BagTweaks account ID generated once and stored in that account's own `pfUIBagTweaksDB`. Do not depend on the WoW account login/folder name being exposed to addon Lua.
- Each account owns a separate custom inventory database file keyed by that stable ID, e.g. `pfUI_BagTweaks_<accountID>.txt`.
- Single-writer ownership is intentional: an account writes only its own inventory file. Other accounts may read it but must not rewrite it. This avoids multiple simultaneously running WoW clients contending over one shared inventory database.
- BagTweaks compiles the displayed cross-account view at runtime from the selected per-account files; source databases remain independently owned.
- A small shared account registry provides discovery metadata for known BagTweaks account IDs and friendly labels. The registry is discovery-only and must never be the authoritative inventory store.
- Registry parsing must tolerate duplicate, stale or partial entries. Losing or duplicating a registry entry must not corrupt any per-account inventory database; an account can register itself again.
- Do not execute shared custom-file contents as Lua. Use a deliberately simple, versioned data format and parse it defensively.
- Account identity and user-selection preferences remain in the local account's SavedVariables. Shared custom files contain only the information intentionally published for cross-account inventory tracking.

### Multi-Account Item Tracking — User Controls / Privacy
- Each account has an editable friendly **Account label** for display, independent of its opaque internal account ID.
- Provide a **Share/publish this account's inventory** control. Publishing controls whether this account writes/updates its cross-account inventory database.
- Provide an **Included accounts** list for the current account. Only checked source accounts contribute to compiled item totals/views.
- Publishing and inclusion are separate decisions: an account may publish its inventory without the current account including it, and the current account may include only a subset of discovered published accounts.
- This separation is required for shared WoW installations where different people use different WoW accounts.
- Do not automatically treat every discovered account database as part of one user's totals merely because it exists in the same installation.
- Preflight resolved the defaults and first presentation as documented below.

### Multi-Account Item Tracking — Implementation Preflight
#### Local authority and tracked data
- Same-account tracking must remain native and work without Nampower. `pfUIBagTweaksDB` is the authoritative store for the current WoW account's tracked character snapshots; Nampower is only the bridge used to publish/read snapshots between WoW accounts.
- Add a nested inventory-tracking data model rather than changing the existing category schema/version semantics. Proposed shape: `db.itemTracking = { version=1, accountID=..., accountLabel=..., publish="0", includedAccounts={}, characters={} }`.
- Current-account character keys continue to be realm + character name, consistent with the existing BagTweaks character-key model.
- Track BagTweaks/pfUI bag surfaces only for the first slice:
  - carried bags: IDs `0-4`;
  - keyring: ID `-2`;
  - bank: IDs `-1, 5-11`.
- Equipped items are deliberately out of the first tracking slice because they are not part of BagTweaks' bag/bank presentation surface. They can be added later without changing the cross-account file protocol.
- Store aggregate item counts per character and storage scope, not physical slot locations. Character records therefore keep separate `carried`, `keyring` and `bank` item-count maps plus a `bankKnown` flag.
- Bank data is last-known state. Never replace a saved bank snapshot with zero/empty data while the bank is closed. Until a character's bank has been successfully scanned, `bankKnown=false`.
- Use native container APIs / BagTweaks' existing `ItemID` path for collection. Do not make inventory scanning itself depend on Nampower's `GetBagItems`; this keeps same-account tracking functional without the DLL.

#### Collection/update ownership
- Reuse BagTweaks' existing wrappers around pfUI bag ownership rather than adding a competing inventory event pipeline.
- After pfUI's original `UpdateBag(bag)` runs, update the current character's aggregate snapshot:
  - a change to `0-4` or `-2` causes a carried/keyring rescan;
  - a change to `-1, 5-11` causes a bank rescan only while the bank is actually open.
- Reuse the existing `CreateBags` wrapper to capture the complete bank snapshot after `CreateBags("bank")` when the bank frame is shown. pfUI calls this path on bank open, giving a deterministic full-bank capture point. The hidden/close path must not clear bank data.
- Initialize the current character/account identity and first carried/keyring snapshot at `PLAYER_ENTERING_WORLD`, when realm/name are reliably available.
- Only mark/publish data when the aggregate snapshot actually changed.
- Do not add an arbitrary persistence debounce for the first implementation. pfUI already coalesces `BAG_UPDATE`; a changed local snapshot may publish immediately. Optimise write frequency later only if profiling or observed behaviour justifies it.

#### Nampower custom-file contract
- Capability-detect the functions rather than hard-coding a Nampower version: cross-account mode requires callable `ReadCustomFile` and `WriteCustomFile`; `CustomFileExists` and `GetNampowerVersion` are optional diagnostics/optimisations.
- Wrap every custom-file operation in `pcall`. `WriteCustomFile` has no success return value and raises a Lua error on failure; `ReadCustomFile` returns `nil` for a missing file and raises for other failures.
- Nampower restricts filenames to the shared `CustomData` directory and rejects path separators / invalid Windows filename characters. BagTweaks-generated filenames and account IDs must therefore use a safe restricted character set.
- Use normal overwrite mode (`"w"`) for each per-account inventory file. Current Nampower writes truncating files via a temporary `.tmp` file followed by `MoveFileEx(..., MOVEFILE_REPLACE_EXISTING)`, giving crash-resistant atomic replacement.
- The temporary filename is deterministic, so the single-writer-per-account rule remains important. Distinct accounts must never share the same active account ID/file.
- Nampower exposes no documented file-enumeration API. A shared registry is therefore still required for discovery.
- Registry writes use append mode (`"a"`), which writes directly rather than through the atomic temp/replace path. Treat the registry as append-only, non-authoritative metadata and make its parser tolerant of duplicate, stale, malformed or partial lines.
- Registry records are self-versioning, e.g. `BTREG1<TAB>accountID<TAB>encodedLabel<TAB>published`. The last valid record for an account ID wins. Re-registering on a later session repairs a lost/partial registry append.
- Do not use `ExecuteCustomLuaFile`. The cross-account format remains inert text parsed by BagTweaks.
- The external `nampowerDB` library was reviewed as a reference for multi-file persistence, but it is not adopted for this slice: it serializes executable Lua / loads through `ExecuteCustomLuaFile`, introduces another dependency, and does not remove BagTweaks' need for its own account discovery/inclusion semantics.

#### Published account file format
- Proposed safe filename: `pfUI_BagTweaks_account_<accountID>.txt`.
- Use a deterministic, line-oriented version-1 text format. Proposed records:
  - `BTINV<TAB>1`
  - `ACCOUNT<TAB>accountID<TAB>encodedLabel<TAB>published`
  - `CHAR<TAB>encodedRealm<TAB>encodedName<TAB>bankKnown`
  - `ITEM<TAB>itemID<TAB>carriedCount<TAB>keyringCount<TAB>bankCount`
  - `ENDCHAR`
- Emit characters and item IDs in deterministic sorted order. This is not required by the parser but makes files stable and easier to inspect/debug.
- Encode free-text fields (account label, realm, character name) rather than allowing tabs/newlines to enter the record grammar. Parser input is untrusted: reject invalid versions/IDs/counts and ignore malformed records without executing content.
- Publishing exports the current account's complete local SavedVariables snapshot to its own account file. Other accounts only read it.
- Disabling publish after an account has previously published must overwrite its account file with a valid `published=0` tombstone containing no inventory, then append a registry state record. Nampower has no delete-file API, so leaving the old inventory file untouched would incorrectly expose stale data.

#### Account identity and privacy defaults
- Generate the opaque account ID once, lazily when tracking identity is first needed, and persist it in this WoW account's SavedVariables. It must not depend on an exposed login/account-folder name.
- Provide a recovery action to regenerate the shared account identity without touching categories or other BagTweaks settings. This is needed if a user manually copies BagTweaks SavedVariables between WoW-account folders and accidentally duplicates the opaque ID; before changing IDs, tombstone the old published file when possible.
- Default friendly label: a neutral label derived from the first character seen on the account (for example `Account (Revenga)`), editable by the user.
- Local same-account tracking is automatic.
- **Publish/share this account's inventory defaults OFF.**
- The current/local account is included in tracked tooltip results by default.
- Newly discovered remote accounts default to **not included**. The user must explicitly opt each source into compiled totals.
- Registry entries marked unpublished or with missing/invalid account files remain discoverable as stale/unavailable metadata but never contribute inventory counts.

#### Read/refresh and presentation
- Load/parse the registry and selected remote sources at `PLAYER_ENTERING_WORLD`.
- Refresh selected remote account files when the backpack or bank is opened, reusing the existing bag `CreateBags` lifecycle rather than polling on a timer. This gives a fresh cross-account view during normal bag use without arbitrary background I/O.
- The pfUI GUI page is lazily populated on first show, so refresh the registry before building the Account Tracking controls. A newly published account discovered after that page has already been built may require reopening after `/reload` in the first implementation; do not add a polling/rebuild system solely for this edge case.
- First presentation surface: append a BagTweaks tracking section to pfUI bag-item tooltips by wrapping the existing pfUI slot frame `OnEnter` handlers during BagTweaks' existing slot-hook pass. Do not globally replace all game item tooltips.
- Tooltip data is compiled from the local account plus only explicitly included, currently published remote accounts. Show only characters with a positive tracked count for the hovered item, grouped by friendly account label; retain carried/keyring/bank split where non-zero and include a compiled tracked total.
- Treat bank values as last-known. The UI must not silently represent an unscanned bank as a known zero; exact wording can be concise (for example a tracked total rather than claiming a complete live total).

#### Lua 5.0.3 / structure
- The existing pfUI BagTweaks module callback is already at 143 top-level local declarations. Multi-account tracking is large enough that scattering helper locals into that callback risks the Lua 5.0.3 200-local limit.
- Keep the existing single-main-Lua-file architecture, but implement tracking behind one self-contained `InventoryTracker` table/factory (or equivalent nested subsystem) so its helper locals compile inside a separate nested function/prototype and only a small number of locals are added to the parent module.
- Re-run the local-count inspection after implementation and run the canonical Lua 5.0.3 compiler checker whenever the executable environment permits it.

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
1. Preserve `0.1.44-dev` / Auto resort delay as an untested checkpoint for later batch runtime validation.
2. Implement the agreed Account Inventory / Nampower-backed multi-account item-tracking architecture as the first build of the deliberate `0.5.x` development line: `0.5.0-dev`.
3. Implement open all containers on right click as the following separately versioned checkpoint.
4. Batch runtime-test the accumulated checkpoints, stepping back by exact version/commit if a regression is found.
5. Rogue Pick Lock workflow test.
6. Disenchant targeting-cursor / candidate-item hover discoverability.
7. Remaining direct-toolbar edge-case checks.
8. Reduce the 0.20s toolbar layout refresh only if profiling or visible behaviour justifies it.

## Deferred / Out of Scope
- Packing optimisation unless future inventories show a real problem.
- Unrelated refactors while addressing auto-sort interaction churn.
- Persisted-schema redesign solely for raw SavedVariables text-order stability.

## Release / Promotion Notes
- Main-only or release-only content to preserve: stable `.toc` Title/Version metadata; development contract/status files are not part of stable releases.
- Known validation debt accepted for release: None currently.
- External/runtime prerequisites: pfUI. Nampower remains optional for existing BagTweaks behaviour, but the planned cross-account custom-file inventory feature specifically requires Nampower custom-file capability. SuperWoW and ClassicAPI remain optional unless a future feature explicitly requires one.

## Exact Next Step
Implement the documented Account Inventory / Multi-Account Item Tracking preflight contract as the next isolated addon revision and deliberate version-line change to `0.5.0-dev`: native per-account SavedVariables snapshots first, optional Nampower publish/read bridge second, then the scoped tooltip/options UI. Preserve `0.1.44-dev` Auto resort behaviour unchanged and do not start open-all-containers-on-right-click in this checkpoint.
