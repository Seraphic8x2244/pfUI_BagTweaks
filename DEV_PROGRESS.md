# pfUI BagTweaks Development Progress

## Current
- Branch: `dev`
- Version: `0.5.11-dev`
- Development code head: `aba98f21f8879d4a20285361e2d91c948702e94c` (latest addon-affecting checkpoint; the following DEV_PROGRESS handoff commit is documentation-only)
- Stable baseline: `0.1.42` / `25474f32f5e20d189c73f84caa6af3e10f30584a`
- Goal: Runtime-validate the new opt-in Inventory Tracking UX/settings reset while preserving the inherited `0.5.10-dev` Account Inventory performance fix.
- Current scope boundary: `0.5.11-dev` is an isolated Inventory Tracking UX/settings checkpoint. Do not mix in toolbar polling changes, open-all-containers, or unrelated tracking refactors before its runtime results are known.

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
- `0.5.5-dev` routed pfUI `CreateBags`-triggered BagTweaks relayouts through the existing `RequestRelayout()` scheduler instead of calling `RelayoutView()` immediately. Runtime testing showed this was insufficient: first and second Disenchant casts still resorted instantly.
- `0.5.6-dev` additionally made the public `pfUI.bagtweaks.Relayout()` path scheduler-owned and armed protection for ordinary right-click carried-item use. Runtime testing still showed Disenchant reordering immediately.
- `0.5.7-dev` corrected the timing semantics so `ProtectAutoResort()` armed the next inventory mutation instead of immediately starting the countdown. Runtime testing confirmed this finally produced some real delay on Disenchant.
- `0.5.8-dev` completed the cast-hold part of the inactivity/coalescing model for repeated Disenchant/Lockpicking actions.
- Runtime feedback then exposed the broader design flaw: splitting a stack reordered immediately because the scheduler still depended on action-specific arming. `0.5.9-dev` removes that requirement. Every pfUI `UpdateBag` mutation now starts or restarts the Auto resort inactivity deadline. This naturally covers stack splitting/moving, equipping, consuming/opening items, manual selling and programmatic selling such as VendorTweaks. Cast-based DE/Pick Lock still use a hold only to prevent an older pending deadline expiring during the cast; their resulting bag mutation releases the hold and restarts the full delay.
- Raid testing then reported shaky FPS particularly when loot was picked up from a corpse. Inspection found Account Inventory's `OnBagUpdated` was synchronously rescanning all carried bags for every pfUI BAG_UPDATE and could immediately serialize/write the published account file when sharing was enabled. `0.5.10-dev` queues carried/keyring/bank dirty flags and waits 0.15 seconds after the last update in the burst before performing one combined rescan/publish. The scan driver is hidden when idle; bank-close and logout flush pending work so snapshots are not lost.
- `0.5.11-dev` replaces the legacy publish/include settings model with the agreed opt-in scopes: **Character Bank**, **Cross-Character**, and **Cross-Account**, all default OFF. **Cross-Account** is now the sole account-level sharing/consumption control; when ON, every valid actively sharing remote account participates automatically.
- The `0.5.11-inventory-settings-1` one-time reset is settings-only: it preserves tracked `itemTracking.characters` snapshots, the opaque account ID, the current nickname, categories, assignments, Auto resort settings and unrelated BagTweaks state. It clears legacy publish/include preferences, forces the three new scopes OFF, and tombstones previously published state; if Nampower is unavailable at reset time the tombstone remains pending and is retried when the bridge becomes available.
- **Available Account Inventories** is read-only and validates account files before display. It shows only accounts whose current shared file is successfully parsed and still marked published; the current account appears only while its own Cross-Account setting is ON.

### Inventory Tracking Settings — Agreed UX
- Replace the current implementation-facing Account Inventory controls ("publish/share", "included account sources", Nampower availability status) with the following user-facing layout:
  - **[Subheader] Inventory Tracking**
    - **Character Bank** `[ ]`
    - **Cross-Character** `[ ]`
    - **Cross-Account** `[ ]`
    - **Current Account Nickname** `[ editable text ]`
  - **[Subheader] Available Account Inventories**
    - read-only list of WoW accounts that are actively sharing inventory, e.g. `Blackwaves`, `Blackwavestwo`.
- Defaults for the three main tracking scope toggles are **OFF**. Tracking beyond the current character's carried inventory is therefore explicitly enabled by the user.
- **Character Bank** controls whether the current character's last-known bank snapshot contributes to tracking/tooltips.
- **Cross-Character** controls whether other characters on the same WoW account contribute.
- **Cross-Account** is the single account-level participation control for cross-WoW-account inventory. ON means this WoW account publishes its inventory and reads all other currently shared account inventories. OFF means this account is not shared and does not consume cross-account inventory.
- If Nampower custom-file capability is unavailable, **Cross-Account** remains visible but disabled/greyed and includes **"(requires Nampower.dll)"** in its label/help.
- **Current Account Nickname** is the human-readable name advertised for this WoW account because addon Lua does not expose the real WoW account/folder/login name.
- Known accounts are identified internally by the existing opaque per-WoW-account ID stored in that account's SavedVariables and discovered through the Nampower shared registry; account-folder structure is not inspected.
- **Available Account Inventories** has no checkboxes or per-account interaction. It is visibility/status only.
- The list shows only accounts that are actively sharing. Do not surface unpublished, sharing-off, stale, tombstoned, unavailable, or otherwise non-sharing account names in the normal UI.
- The currently logged-in account appears in **Available Account Inventories** when its own **Cross-Account** setting is ON; when Cross-Account is OFF it is not listed.
- There is no per-account include/exclude model. If a WoW account should not participate or appear, Cross-Account is disabled on that account.
- Do not expose "publish", "source", "registry", opaque account IDs, tombstones, or other implementation language in the normal settings UI.

### Inventory Tracking Settings — One-Time Test Reset
- The first build implementing the above UX must include a **one-time Inventory Tracking settings reset** so the user can validate the new defaults and setup flow from a clean state.
- Scope the reset to Inventory Tracking settings/preferences only. Preserve BagTweaks categories, subcategories, item assignments, Auto resort settings, and unrelated addon configuration.
- Preserve existing tracked character/item snapshots and the opaque per-WoW-account identity unless implementation proves a reset is required for correctness; this is a settings reset, not another destructive inventory-history wipe.
- Reset the three new scope toggles to their agreed defaults: **Character Bank OFF, Cross-Character OFF, Cross-Account OFF**.
- Clear legacy publish/include UI preference state so it cannot silently override the new model. The old per-account inclusion selection is retired rather than migrated.
- Existing discovery metadata may remain internally, but the normal UI must surface only accounts that are currently sharing.
- If the account was previously publishing, disabling Cross-Account during the one-time reset must also make the previously published shared state non-authoritative (use the existing published=0/tombstone mechanism) so "Cross-Account OFF" is true in practice, not just in the local UI.
- Use a new one-time reset epoch/version marker so the reset runs once per WoW account and is not repeated on subsequent logins.

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
- Each account has an editable **Current Account Nickname** for display, independent of its opaque internal account ID.
- **Cross-Account** is the only user-facing account participation control. It replaces the old separate publish/share and included-account controls.
- Cross-Account ON means the current WoW account is intentionally visible/shared and all other actively shared account inventories are eligible for the combined cross-account view.
- Cross-Account OFF means the current WoW account is not visible/shared to other accounts and does not consume cross-account inventory.
- The normal settings UI provides a read-only **Available Account Inventories** list containing only accounts that are actively sharing. Unshared account names are deliberately not surfaced.
- Account identity is generated automatically and is not a routine user control. The earlier exposed **Regenerate account identity** button was removed in `0.5.4-dev` after first-run testing showed it was easy to mistake for a harmless refresh/reset action.
- Account discovery/tombstone metadata may remain internally for protocol correctness, but privacy-facing UI follows the user's sharing choice rather than exposing registry history.

### Multi-Account Item Tracking — Implementation Preflight
#### Local authority and tracked data
- Same-account tracking must remain native and work without Nampower. `pfUIBagTweaksDB` is the authoritative store for the current WoW account's tracked character snapshots; Nampower is only the bridge used to publish/read snapshots between WoW accounts.
- Add a nested inventory-tracking data model rather than changing the existing category schema/version semantics. Current shape keeps `version=1`, `accountID`, `accountLabel`, `characters`, plus string-backed scope preferences `characterBank`, `crossCharacter`, and `crossAccount`. Legacy `publish` / `includedAccounts` values are cleared by the one-time `0.5.11` settings reset and are not part of the active user model.
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
- `0.5.10-dev` added a targeted 0.15-second coalescing window for Account Inventory scans/publishes after observed raid/loot hitching. Dirty carried/keyring/bank flags are combined after the BAG_UPDATE burst settles; bank close and logout flush pending work so snapshots are not lost.

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
- The new settings UX makes additional tracking scopes explicit opt-ins: **Character Bank OFF, Cross-Character OFF, Cross-Account OFF** by default.
- Current-character carried inventory remains the baseline local view.
- There is no per-account include/exclude preference. When Cross-Account is ON, all valid actively shared account inventories participate in the cross-account view.
- Cross-Account OFF means the account must not remain authoritatively published to other WoW accounts; legacy published state must be tombstoned during the one-time migration/reset.
- Registry entries marked unpublished or with missing/invalid account files may remain discoverable internally for protocol repair, but never contribute inventory counts and never appear in **Available Account Inventories**.

#### Read/refresh and presentation
- Load/parse the registry and valid actively shared remote sources at `PLAYER_ENTERING_WORLD` when Cross-Account is enabled.
- Refresh actively shared remote account files when the backpack or bank is opened, reusing the existing bag `CreateBags` lifecycle rather than polling on a timer. This gives a fresh cross-account view during normal bag use without arbitrary background I/O.
- The pfUI GUI page is lazily populated on first show, so refresh the registry before building **Available Account Inventories**. A newly shared account discovered after that page has already been built may require reopening after `/reload` in the first implementation; do not add a polling/rebuild system solely for this edge case.
- First presentation surface: append a BagTweaks tracking section to pfUI bag-item tooltips by wrapping the existing pfUI slot frame `OnEnter` handlers during BagTweaks' existing slot-hook pass. Do not globally replace all game item tooltips.
- Tooltip data is compiled according to the three scope toggles. When Cross-Account is enabled, all valid actively shared account inventories participate; there is no per-account inclusion filter. Show only characters with a positive tracked count for the hovered item, grouped by friendly account nickname; retain carried/keyring/bank split where non-zero and include a compiled tracked total.
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
- `aba98f21f8879d4a20285361e2d91c948702e94c` — Implement Inventory Tracking UX, scoped tooltip compilation and settings-only reset (`0.5.11-dev`).
- `694995382ffd0c97b7744a104e1e6590380d4e3f` — Replace legacy Account Inventory settings copy with the new Inventory Tracking labels.
- `f7e80fba1613ca1cc4063c3ed6ab2b0d29a6395d` — Start the isolated `0.5.11-dev` Inventory Tracking UX checkpoint.
- `371fa27398c16a9bdd074ebefb32ecf0faaac10a` — Coalesce Account Inventory scans/publishes after BAG_UPDATE bursts (`0.5.10-dev`).
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
- `0.5.11-dev` retires the legacy per-account inclusion model. The active preferences are **Character Bank**, **Cross-Character**, and **Cross-Account**, all string-backed OFF by default; Cross-Account ON automatically consumes all currently published, successfully parsed remote account files.
- The one-time `0.5.11-inventory-settings-1` reset preserves existing tracked character/item snapshots, account identity and nickname while clearing legacy publish/include preference state. Previously published state is tombstoned, with a persisted retry marker if the bridge is temporarily unavailable.
- Tooltip compilation now follows the three scopes: current-character carried/keyring data is the baseline, Character Bank adds the current character's last-known bank, Cross-Character adds other same-account character snapshots, and Cross-Account adds all valid actively sharing remote account snapshots.
- `0.5.11-dev` replaces the old implementation-facing options with **Current Account Nickname** and read-only **Available Account Inventories**; there are no per-account include/exclude controls. Cross-Account is visibly disabled as requiring Nampower when the custom-file bridge is unavailable.
- Unscanned banks are not represented as known zero; tooltip detail marks `bank unscanned` only when bank data is actually in the selected scope.
- `0.1.44-dev` Auto resort remains awaiting runtime validation and is inherited unchanged by the `0.5.x` line.
- `0.1.43-dev` SavedVariables no-op normalization guards remain inherited unchanged.

## Static / Automated Checks
- Before writing, `dev` was verified identical to the requested handoff `d2be5ec8fe110e8afff601a6b7a16f1c73c58eb9`. The latest addon-affecting checkpoint is `aba98f21f8879d4a20285361e2d91c948702e94c`.
- Full compare from the requested handoff through the `0.5.11-dev` addon checkpoint changes only `pfUI_BagTweaks.lua`, `locales/enUS.lua` and `pfUI_BagTweaks.toc`; toolbar/open-all-container implementation files or paths were not touched.
- Exact static comparison confirms the inherited Auto resort scheduler block is byte-identical between the requested handoff and `0.5.11-dev`.
- Exact static comparison confirms the `0.5.10-dev` Account Inventory scan-coalescing block from `RescanCurrent` through immediately before `OnCreateBags` is byte-identical between the requested handoff and `0.5.11-dev`.
- The destructive `db.itemTracking = nil` clean-start path is absent from `0.5.11-dev`; legacy `includedAccounts` / `publish` references remain only in the one-time reset that clears/migrates them, and the old `SetPublish` / `SetIncluded` runtime controls are absent.
- The prior exact local-count inspection remains the last exact compiler-local count. This checkpoint keeps its added helpers inside the nested `InventoryTracker` subsystem, and a like-for-like indentation-level comparison showed no increase in the parent module's local declarations versus the requested handoff.
- Static later-Lua-syntax scan of the final Lua found none of the checked post-5.0 constructs (`#` length operator, `goto`/labels, `//`, or variable attributes).
- Nampower custom-file API/overwrite/append behaviour was checked against the current Nampower documentation/source before implementing the bridge.
- No repository CI/workflow is present for this branch.
- Canonical vendored Lua 5.0 compiler check: **not run**. The canonical checker/source can be read through the GitHub connection but is not mounted in the executable environment; the shell has a C compiler but cannot clone/download GitHub content, and no system `lua`/`luac` is installed. Do not treat the static checks above as a compiler pass or in-game test.

## Current Issues
- The earlier tooltip-injection correction has not yet had a clean direct runtime confirmation on the current `0.5.11-dev` checkpoint.
- `0.5.11-dev` Cross-Account publish/read behaviour, scope toggles, settings-only reset, pending legacy tombstone retry and read-only **Available Account Inventories** filtering still require target-client validation.
- Auto resort runtime gaps: `0.5.9-dev` generalises delay to every observed bag mutation and still awaits full target-client validation.
- Performance: `0.5.10-dev` addresses a reported raid/loot hitch by coalescing Account Inventory BAG_UPDATE scans/publishes. If continuous FPS loss remains outside inventory activity, the permanent toolbar OnUpdate is the next suspect to isolate.
- Raw SavedVariables backups may differ only in Lua table key order even when their BagTweaks state is semantically identical.

## Testing

### Last Runtime Test
- Version/commit: `0.5.9-dev` / `643b029e91485713d601df73cf9540e84da312e5`
- Performance report: gameplay felt somewhat shaky in raids, especially when picking an item up from a corpse.
- Inspection result: the strongest event-correlated suspect is Account Inventory. Every carried-bag pfUI `UpdateBag` invoked a full carried-bag rescan; bursts of BAG_UPDATE during looting could therefore repeat whole-inventory scans, and published accounts could also serialize/write the cross-account file repeatedly.
- A permanent toolbar OnUpdate also exists and was already identified as a possible sustained-FPS suspect, but it is not changed in this checkpoint so the loot/update optimization can be tested independently.
- Auto resort's pending timer itself only performs lightweight time/deadline checks and is not the primary suspect for corpse-loot hitches.

### Next Runtime Test
1. Load `0.5.11-dev` / `aba98f21f8879d4a20285361e2d91c948702e94c` on the first WoW account. Confirm the one-time settings reset leaves **Character Bank**, **Cross-Character**, and **Cross-Account** OFF while preserving existing tracked snapshots, account identity/nickname, categories, item assignments, Auto resort settings, and unrelated BagTweaks configuration.
2. Confirm the settings page shows **Current Account Nickname** and a read-only **Available Account Inventories** section, with no publish/source/include terminology or per-account checkboxes.
3. With Nampower available, enable **Cross-Account** and set the nickname. Confirm the current account becomes visible in **Available Account Inventories** and is published for other WoW accounts.
4. Enable Cross-Account on a second WoW account with its own nickname. Confirm both actively sharing accounts appear in the read-only list and their inventories participate automatically without an include/exclude step.
5. Disable Cross-Account on one account. Confirm it is tombstoned/non-authoritative, disappears from **Available Account Inventories** on the other account, and no longer contributes cross-account tooltip counts.
6. Separately validate **Character Bank** and **Cross-Character** OFF/ON scope behaviour, including last-known bank data and same-account character aggregation.
7. Recheck corpse looting/raid smoothness to confirm the inherited `0.5.10-dev` scan-coalescing fix remains good through the UX change.

## Planned / Next Work
1. Runtime-test `0.5.11-dev` clean defaults, Nampower-disabled state, nickname flow, read-only Available Account Inventories visibility, Cross-Account participation on/off, scope behaviour, and preservation of existing tracked snapshots/unrelated BagTweaks settings.
2. Recheck raid/corpse-loot smoothness so the inherited `0.5.10-dev` scan-coalescing fix is validated through the UX checkpoint.
3. Continue generic Auto resort runtime validation.
4. If a regression appears, step back to the exact preceding version/commit to isolate the first failing slice.
5. After Account Inventory/Auto resort validation, inspect and design open all containers on right click against the existing Open control and Auto resort protection owner before changing runtime code.
6. Rogue Pick Lock workflow test.
7. Disenchant targeting-cursor / candidate-item hover discoverability.
8. Remaining direct-toolbar edge-case checks.
9. Reduce the 0.20s toolbar layout refresh only if profiling or visible behaviour justifies it.

## Deferred / Out of Scope
- Packing optimisation unless future inventories show a real problem.
- Unrelated refactors while addressing auto-sort interaction churn.
- Persisted-schema redesign solely for raw SavedVariables text-order stability.

## Release / Promotion Notes
- Main-only or release-only content to preserve: stable `.toc` Title/Version metadata; development contract/status files are not part of stable releases.
- Known validation debt accepted for release: None currently.
- External/runtime prerequisites: pfUI. Nampower remains optional for existing BagTweaks behaviour, but the planned cross-account custom-file inventory feature specifically requires Nampower custom-file capability. SuperWoW and ClassicAPI remain optional unless a future feature explicitly requires one.

## Exact Next Step
Runtime-test `0.5.11-dev` / `aba98f21f8879d4a20285361e2d91c948702e94c` using the seven checks above. Do not begin toolbar performance changes, open-all-containers, or unrelated refactors until this isolated Inventory Tracking checkpoint has runtime results.
