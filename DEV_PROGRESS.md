# pfUI BagTweaks Development Progress

## Current
- Branch: `dev`
- Version: `0.5.4-dev`
- Development code head: `f2b4d7f34c1885f8e4eff2f6711f32e9b2bbf2d0` (latest addon-affecting checkpoint; the following DEV_PROGRESS handoff commit is documentation-only)
- Stable baseline: `0.1.42` / `25474f32f5e20d189c73f84caa6af3e10f30584a`
- Goal: Perform a deliberate clean-start Account Inventory test with the `0.5.3-dev` tooltip fix retained, all local Account Inventory state reset once per WoW account, the shared discovery registry reset once per installation, and the exposed identity-regeneration control removed.
- Current scope boundary: Validate the clean-start Account Inventory/tooltips first, then fix the observed Auto resort regressions as a separate reversible checkpoint. Do not start open-all-containers-on-right-click yet.

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
- Multi-account-wide item tracking is implemented below as isolated `0.5.0-dev` native tracking, `0.5.1-dev` Nampower bridge and `0.5.2-dev` tooltip/options checkpoints. `0.5.3-dev` is a targeted tooltip-injection correction after live testing proved collection/aggregation but no tooltip output.
- `0.5.4-dev` is an intentionally destructive Account Inventory clean-start checkpoint requested during first live validation. On the first `PLAYER_ENTERING_WORLD` per WoW account, it discards only that account's `db.itemTracking` data (identity, friendly label, publish/inclusion choices and character snapshots), creates a fresh identity/store and immediately rescans the current character. Other BagTweaks settings/categories are preserved.
- The same build uses a shared reset marker so the Nampower discovery registry is truncated only once for this clean-start epoch across the installation. The previous current account file is tombstoned when its old ID is known. Old historical custom files are non-authoritative and no longer discoverable after the registry reset.
- The normal Settings UI no longer exposes **Regenerate account identity**, and the runtime regeneration method/localized caption were removed. If identity recovery is ever needed again, design a guarded/confirmed recovery path rather than exposing a routine-looking destructive button.
- Runtime testing is in progress. Bind each result to the exact checkpoint and keep fixes isolated so regressions can be stepped back cleanly.
- Open all containers on right click remains the next feature after Account Inventory review/runtime validation; exact interaction ownership/target surface still needs inspection before implementation, and it has not been started.

### Multi-Account Item Tracking — Agreed Design
- Native WoW SavedVariables remain account-local. BagTweaks cannot use normal addon SavedVariables to directly read a sibling WoW account's `WTF\\Account\\<account>\\SavedVariables` data.
- Cross-account inventory sharing will therefore use Nampower's custom-file capability in the shared WoW installation. This is an optional enhancement: without the required custom-file API, BagTweaks must continue working normally with its existing per-account SavedVariables behaviour.
- Keep existing BagTweaks categories, subcategories, assignments and ordinary settings in `pfUIBagTweaksDB`. The custom-file system is for cross-account inventory/item tracking, not a wholesale replacement for SavedVariables.
- Each WoW account gets a stable opaque BagTweaks account ID generated once and stored in that account's own `pfUIBagTweaksDB`. Do not depend on the WoW account login/folder name being exposed to addon Lua.
- Each account owns a separate custom inventory database file keyed by that stable ID, e.g. `pfUI_BagTweaks_account_<accountID>.txt`.
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
- Account identity is generated automatically and is not a routine user control. The earlier exposed **Regenerate account identity** button was removed in `0.5.4-dev` after first-run testing showed it was easy to mistake for a harmless refresh/reset action.
- Publishing and inclusion are separate decisions: an account may publish its inventory without the current account including it, and the current account may include only a subset of discovered published accounts.
- This separation is required for shared WoW installations where different people use different WoW accounts.
- Do not automatically treat every discovered account database as part of one user's totals merely because it exists in the same installation.
- Preflight resolved the defaults and first presentation as documented below.

### Multi-Account Item Tracking — Implementation Preflight
#### Local authority and tracked data
- Same-account tracking must remain native and work without Nampower. `pfUIBagTweaksDB` is the authoritative store for the current WoW account's tracked character snapshots; Nampower is only the bridge used to publish/read snapshots between WoW accounts.
- Add a nested inventory-tracking data model rather than changing the existing category schema/version semantics. Implemented shape: `db.itemTracking = { version=1, accountID=..., accountLabel=..., publish="0", includedAccounts={}, characters={} }`.
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
- Implemented safe filename: `pfUI_BagTweaks_account_<accountID>.txt`.
- Use a deterministic, line-oriented version-1 text format. Implemented records:
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
- `31ac615a20d1b17d517e0ddae2695f62739958f1` — Add Account Inventory tooltip and options UI (`0.5.2-dev`).
- `fab533e6213051e3b870c969114aae1d95276ea5` — Add optional Nampower account inventory publish/read bridge (`0.5.1-dev`).
- `c2457e53fb2b8b3b11a13557b3c12ca0299cfdb7` — Add native per-account SavedVariables inventory snapshots (`0.5.0-dev`).
- `074243a84dffd1e03fd03e0125a1d188e243084f` — Set the Account Inventory development line to `0.5.0-dev` in the preflight contract.
- `57a741cca2ce75c6785d612cdb4301866c567594` — Bump BagTweaks to 0.1.44-dev for Auto resort delay runtime validation.
- `2f2ba7cdc9c355c66ab6c06e80cb410cee3244eb` — Implement the inactivity-based Auto resort delay and protected interaction hooks.
- `015ccdea2b2364a12057767454f49f64ba86c266` — Add Auto resort delay option/tooltip locale strings.
- `0d8b539c7de11fb98a8dd0e549daaad42c7946ed` — Document the agreed Auto resort delay design.
- `25474f32f5e20d189c73f84caa6af3e10f30584a` — Release pfUI BagTweaks 0.1.42 to `main`.

## Completed / User-Verified
- Stable release `0.1.42` is on `main`.
- Canonical workflow/name migration smoke test passed in game for 0.1.42.
- Existing SavedVariables/categories, backpack/bank behaviour, toolbar, Eye/EyeOff and Close/X artwork were confirmed good for 0.1.42.

## Implemented / Awaiting Runtime Test
- `0.5.0-dev` adds native same-WoW-account inventory snapshots under `db.itemTracking`: carried bags `0-4`, keyring `-2`, and last-known bank `-1,5-11` with an explicit `bankKnown` flag.
- Native tracking reuses the existing pfUI `UpdateBag` and `CreateBags` ownership paths; it adds no competing bag-event scanner. The current character is initialized at `PLAYER_ENTERING_WORLD`.
- `0.5.1-dev` adds the optional Nampower bridge. Native tracking remains functional when `ReadCustomFile` / `WriteCustomFile` are unavailable.
- Cross-account files use inert deterministic `BTINV 1` text, one writer per opaque account ID, a tolerant append-only `BTREG1` registry, pcall-wrapped custom-file I/O, and a `published=0` tombstone when sharing is disabled.
- Publishing defaults off. Remote accounts are discovered separately from inclusion and default to not included. Only selected, currently published, successfully parsed remote account files contribute counts.
- A published account re-registers once on a later session even when its snapshot is unchanged; if the login snapshot changed, that change-triggered publish is reused rather than writing twice.
- `0.5.2-dev` adds the scoped presentation: pfUI bag-slot tooltips only, grouped by account/character with carried/keyring/bank splits and tracked total, plus Account Inventory options for label, publish/share, identity regeneration and per-source inclusion.
- Unscanned banks are not represented as known zero; tooltip detail explicitly marks `bank unscanned`.
- Account identity regeneration tombstones the old published ID when the bridge is available before creating/publishing the replacement ID.
- `0.1.44-dev` Auto resort remains awaiting runtime validation and is inherited unchanged by the `0.5.x` line.
- `0.1.43-dev` SavedVariables no-op normalization guards remain inherited unchanged.

## Static / Automated Checks
- Branch/head verification passed before and after implementation; `dev` matched the requested `074243a84dffd1e03fd03e0125a1d188e243084f` handoff before writing and matched `31ac615a20d1b17d517e0ddae2695f62739958f1` after the final addon change.
- Exact static comparison confirms the Auto resort scheduler block from `local relayoutDriver` through `pfUI.bagtweaks.Relayout = Relayout` is byte-identical between the requested handoff and `0.5.2-dev`.
- Full compare from the handoff to `0.5.2-dev` changes only `pfUI_BagTweaks.lua`, `locales/enUS.lua` and the `.toc`; open-all-containers implementation markers are absent.
- Static local-count inspection counted 149 top-level locals in the main pfUI module callback after Account Inventory, below Lua 5.0's 200-local compiler limit. The tracker helpers are nested inside the dedicated `InventoryTracker` subsystem as designed.
- Static later-Lua-syntax scan of the final Lua found none of the checked post-5.0 constructs (`#` length operator, `goto`/labels, `//`, bitwise operators or variable attributes).
- Nampower custom-file API/overwrite/append behaviour was checked against the current Nampower documentation/source before implementing the bridge.
- No repository CI/workflow is present for this branch.
- Canonical vendored Lua 5.0 compiler check: **not run**. The canonical checker/source can be read through the GitHub connection but is not mounted in the executable environment; the shell has a C compiler but cannot clone/download GitHub content, and no system `lua`/`luac` is installed. Do not treat the static checks above as a compiler pass or in-game test.

## Current Issues
- `0.5.2-dev` proved same-account collection/aggregation but failed to display tooltip lines. `0.5.3-dev` changed the tooltip injection path but was superseded before direct runtime retest; `0.5.4-dev` carries that same tooltip fix into the requested clean-start test.
- `0.5.4-dev` intentionally destroys prior Account Inventory state on first load per WoW account. Character snapshots therefore need to be rebuilt by revisiting characters; banks remain unknown until opened.
- Cross-account publish/read and remote inclusion still require complete target-client validation after the clean reset.
- Auto resort runtime gaps are confirmed: VendorTweaks autoselling bypasses protection; Disenchant and equip changes can still trigger immediate BagTweaks visual resort.
- Raw SavedVariables backups may differ only in Lua table key order even when their BagTweaks state is semantically identical.

## Testing

### Last Runtime Test
- Version/commit: `0.5.2-dev` / `31ac615a20d1b17d517e0ddae2695f62739958f1`
- Passed: account-wide label persisted across characters; on account `Blackwavestwo` the opaque account ID remained stable across reload and across two characters; both character records were present; direct aggregation for Mining Pick item ID `2901` returned tracked total `2`, proving same-account collection and aggregation.
- Failed: no Account Inventory lines appeared on pfUI bag-slot tooltips despite the correct tracked total.
- Auto resort partial: manual vendoring delay works. VendorTweaks automatic selling is not protected. Disenchant itself works, but the BagTweaks visual resort occurs immediately. Equipping an item also causes an immediate visual resort.
- Observation: multiple unpublished `Blackwaves` registry rows were seen after first-account setup. The user may have pressed Regenerate account identity multiple times; this is consistent with intentional tombstoning and has not been reproduced as spontaneous identity churn. `Blackwavestwo` identity remained stable.

### Next Runtime Test
1. Load `0.5.4-dev` / `f2b4d7f34c1885f8e4eff2f6711f32e9b2bbf2d0` on the first WoW account. Confirm Account Inventory has reset to a fresh default label/current-character-only snapshot, publishing is off, Included account sources is empty, and **Regenerate account identity** is absent. Existing BagTweaks categories/settings must remain intact.
2. Rename that account as desired, enable publishing, then visit each character that should be tracked. Because this build deliberately wipes the previous snapshots, each character must be logged once again to repopulate its carried/keyring data; open its bank once if bank counts are wanted.
3. Hover the known Mining Pick item ID `2901` after two characters holding one each have been revisited. Expected: the retained `0.5.3-dev` tooltip fix displays both local characters and tracked total `2`.
4. Load `0.5.4-dev` on the second WoW account. Confirm its local Account Inventory resets independently without clearing the first account's newly published registry entry; rename/publish it and confirm the first account appears exactly once as a remote source.
5. Include the remote source and confirm the tooltip groups local and remote character counts under their account labels.
6. After clean-start/tooltips pass, make the Auto resort fix its own next checkpoint: protect VendorTweaks autoselling, prevent immediate protected relayout bypasses, and include equip-driven bag changes in the inactivity deadline.

## Planned / Next Work
1. Batch runtime-test the three Account Inventory stepping stones and the inherited Auto resort checkpoint when the user is back at the target client.
2. If a regression appears, step back to the exact preceding version/commit above to isolate the first failing slice.
3. After Account Inventory/Auto resort validation, inspect and design open all containers on right click against the existing Open control and Auto resort protection owner before changing runtime code.
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
- External/runtime prerequisites: pfUI. Nampower remains optional for existing BagTweaks behaviour, but the planned cross-account custom-file inventory feature specifically requires Nampower custom-file capability. SuperWoW and ClassicAPI remain optional unless a future feature explicitly requires one.

## Exact Next Step
Have the user load `0.5.4-dev` / `f2b4d7f34c1885f8e4eff2f6711f32e9b2bbf2d0` on both WoW accounts in turn, rebuild at least two character snapshots on one account, and validate the retained tooltip fix plus clean cross-account discovery. Then implement the observed Auto resort fixes as a separate versioned checkpoint. Do not start open-all-containers-on-right-click yet.
