# pfUI BagTweaks Development Progress

## Current
- Branch: `dev`
- Version: `0.5.35-dev`
- Development code head: `75a016d68457b6253f29b222477debff94f960fb` (latest addon-affecting checkpoint; subsequent DEV_PROGRESS handoff commits are documentation-only)
- Stable baseline: `0.5.35` / `8d538035b85c08bd1f91bee2acbf05484f56e61c`
- Goal: Preserve the successful direct Bagshui swap baseline while runtime-validating the refreshed cross-account tooltip layout on bag and generic item-link tooltips.
- Current scope boundary: `0.5.35-dev` preserves the `0.5.32-dev` physical Bagshui pathway, `0.5.33-dev` popout restoration, and `0.5.34-dev` generic item-link hook unchanged. The only new behavior is tooltip presentation: `Across Accounts: <total>` as the title, pfUI green/blue for title/account labels, gold character names, white counts, and Bags/Keys/Bank detail only for the currently logged-in character. Do not start open-all-containers, toolbar performance work, unrelated refactors, or later work until this workflow is runtime accepted.

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
- The `0.5.11-inventory-settings-1` one-time reset was settings-only: it preserved tracked `itemTracking.characters` snapshots, the opaque account ID and nickname while resetting the new scope preferences.
- **Changed requirement before runtime testing:** `0.5.12-dev` deliberately supersedes that preservation behaviour for this test checkpoint. Its one-time `0.5.12-first-run-tracking-1` reset removes the entire local `db.itemTracking` subtree so account identity, nickname, tracked character/bank/item snapshots and all sharing/scope state start fresh. Categories, subcategories, item assignments, Auto resort and all unrelated BagTweaks configuration remain untouched.
- With the Nampower custom-file bridge available during the reset, the old account file is tombstoned and the shared account registry is cleared once for the new clean-start epoch before a fresh local identity/store is created.
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
- The original `0.5.11-dev` implementation used a settings-only reset, but the user changed the runtime-test requirement before testing: the experience should now behave like a first-ever Inventory Tracking / Account Sync setup.
- `0.5.12-dev` therefore performs a **one-time full Inventory Tracking reset** using epoch `0.5.12-first-run-tracking-1`.
- The reset removes the entire local `db.itemTracking` subtree. This intentionally discards tracked character/item/bank snapshots, opaque account identity, Current Account Nickname, the three scope settings, legacy publish/include state, and any other Inventory Tracking-local metadata.
- Immediately afterwards, normal startup creates a new Inventory Tracking store/opaque account ID, gives the current account its normal default nickname, rescans the current character's carried/keyring inventory, and leaves **Character Bank**, **Cross-Character**, and **Cross-Account** OFF.
- Preserve all non-Inventory-Tracking data: BagTweaks categories, subcategories, item assignments, Auto resort settings, toolbar/settings, layout configuration and unrelated addon state must remain outside this reset.
- When Nampower custom-file capability is available during the reset, tombstone the old account file and clear the shared discovery registry once per installation using the shared reset marker file before the new account can opt back into Cross-Account.
- If the bridge is unavailable during that first reset, local Inventory Tracking state still resets, but external custom files cannot be deleted/tombstoned at that moment. This limitation matters only when deliberately testing no-Nampower startup with old published data already present.
- The reset is one-shot per WoW account. Subsequent logins on the same `0.5.12-dev` checkpoint must not repeatedly erase newly collected tracking data.

### Bag Replacement Workflow — Agreed UX / Design
- **Status:** UX/design approved; implementation assembled. Runtime on brues-code/ClassicAPI proved both the original strict executor and the later partial Bagshui adaptation were too divergent from known-good behavior. `0.5.32-dev` removes the old physical executor and directly follows Bagshui's move queue/equip callback semantics while preserving BagTweaks-specific planning/UI requirements.
- Purpose: BagTweaks' filtered/category presentation deliberately hides the physical distribution of items across bags. Users therefore need a safe way to replace an equipped bag without manually finding and emptying that physical bag first.
- Scope includes both carried equipped bags and purchased bank bags. The backpack itself is not replaceable.
- Entry interactions:
  - support normal **drag-and-drop**: drag a replacement bag item onto the equipped bag slot to replace;
  - support **click-and-click**: select/click the replacement bag item, then click the equipped bag slot to replace.
- Reuse pfUI's existing visible bag-slot controls rather than adding a separate Bag Swap toolbar button/window.
- If the target equipped bag is already empty, preserve the normal/simple swap path; do not add unnecessary ceremony.
- If the target bag contains items, BagTweaks takes ownership of the replacement workflow and performs the operation automatically when safe.
- The user does not need to know where the evacuated items physically go. BagTweaks should treat physical placement as an implementation detail because the filtered presentation is the user's inventory model.
- **Do not move evacuated items back into the newly equipped bag after the swap.** Their destination after evacuation is accepted. If the user later wants physical repacking, the existing pfUI Sort control remains available.
- If the replacement bag itself is physically inside the target bag, stage it automatically into another compatible slot first and continue. Do not expose this special case to the user unless the operation cannot proceed.
- Specialty bags (quivers, soul bags, profession/specialty bags) must be supported using compatibility-aware destination planning. Compatible general-purpose slots may be used where valid; illegal item/bag-family moves must never be attempted.
- **Pre-sort before final space rejection:** before reporting insufficient space, run the normal pfUI bag sort for the relevant inventory so partial stacks can consolidate and real free slots can be created. Then re-run preflight against the actual post-sort state.
- **Execution timing decision changed after runtime evidence:** pfUI Sort completion remains event/state verified, but physical bag-swap execution now intentionally follows Bagshui/Swapper's proven short-delay/retry model. Transient Vanilla lock/cursor states are retried instead of treated as immediate fatal mismatches.
- Audit note: current pfUI `libbagsort` already uses `BAG_UPDATE_DELAYED` between its consolidate and final-placement phases but exposes no clean public completion callback. BagTweaks must therefore wait for/observe inventory events and verify the sort has actually completed before running post-sort preflight; do not assume one event means completion.
- Movement execution uses Bagshui-style queued retries: normal successful moves advance after a short settling delay; locked/rejected attempts retry with longer delays up to a bounded limit. This supersedes the original one-event/one-proof requirement for the physical swap executor.
- **Safety boundary:** the old equipped bag remains equipped until every item has successfully evacuated from it. Never deliberately remove a populated bag.
- Preflight remains compatibility-aware and authoritative for destination selection. During execution, transient locks are normal retry conditions; only exhausted retries, unavailable targets, or genuinely rejected operations stop the transaction.
- If there is enough compatible post-sort space: proceed automatically.
- If there is not enough compatible post-sort space: move nothing further, keep the existing bag equipped, and fail gracefully.
- Blocking UX while BagTweaks owns the transaction:
  - place a click-intercepting overlay over the affected pfUI bag or bank window;
  - inherit the overlay's **size and background styling/colour from pfUI**, rather than hard-coding BagTweaks styling;
  - block item interaction, toolbar actions and bag-slot actions within the affected window while the transaction is active;
  - show centered status text such as **Preparing bag swap…**, **Sorting bags…**, **Moving items 4 / 11…**, or **Equipping new bag…**;
  - on an unexpected safe-stop, use the same overlay to explain why the operation stopped.
- Insufficient-space failure UX:
  - clear message, e.g. **Not enough space to replace this bag.**
  - include the useful amount where known, e.g. **3 more compatible slots are needed.**
  - acknowledgement button text: **I'll make some space...**
  - the overlay remains until the user acknowledges the message, rather than disappearing before they can read it.
- Bank-bag replacement uses the same transaction model and the overlay belongs to the pfUI bank window. Bank replacement is only available while the bank is open.
- Dependency policy:
  - target normal pfUI as the baseline; bag replacement must not require Nampower, SuperWoW, ClassicAPI or another DLL;
  - use native/pfUI APIs where sufficient;
  - ClassicAPI may be capability-detected as an **optional internal fast/reliability path** only if audit/implementation proves a real benefit;
  - behaviour and UX must remain identical when ClassicAPI is absent; do not expose this as a user setting.
- Do not introduce a separate physical sorting model for BagTweaks. pfUI remains the owner of ordinary physical Sort behaviour; BagTweaks performs only the minimum physical moves required for this explicit replacement transaction.
- Implementation must preserve the already runtime-accepted `0.5.16-dev` bag-open, Auto Resort and Inventory Tracking behaviour.

### Bag Replacement Workflow — Development Sequence
- Use a **one-slice-per-chat** workflow for this feature. Each development chat should verify the documented `dev` head, implement only that slice, run the available static checks, update `DEV_PROGRESS.md` in a final documentation-only handoff commit, and stop at that implementation checkpoint so the next slice can continue in a fresh chat.
- **Runtime testing is deferred until the complete `0.5.17-dev` through `0.5.22-dev` workflow is assembled.** The per-slice runtime-target bullets define the eventual integrated test coverage; they are not runtime gates between implementation slices. Only stop early for a targeted runtime check if the user explicitly requests it or a concrete implementation uncertainty cannot be resolved safely through inspection/static checks.
- Preserve one shared high-level pipeline throughout: **select → preflight → optional pfUI sort → re-preflight → evacuate → equip → refresh**. As of `0.5.32-dev`, evacuate/equip use the direct Bagshui-style move queue and equip callback semantics; the earlier strict pending-event verifier has been removed.
- Carried bags and bank bags must feed the same pipeline. Bank support must be an adapter/configuration of the shared transaction engine, not a second independently implemented workflow.

#### `0.5.17-dev` — Interaction + overlay foundation
- **Status:** implemented and statically checked at code checkpoint `2182a5b3336a6634b246133a1a634e4b7892c1b2`; intentionally not runtime-tested as a standalone slice. Continue to `0.5.18-dev`.
- Hook the existing carried and bank bag-slot controls.
- Recognize the replacement bag item and target equipped bag slot for both drag-and-drop and click-and-click.
- Create the pfUI-derived blocking overlay and agreed status/failure presentation, including **I'll make some space...**.
- Add the transaction/state-machine skeleton and explicit ownership/cleanup rules.
- Do **not** physically move inventory yet.
- Runtime target: selection semantics, target detection, overlay sizing/styling, click interception, carried/bank ownership and clean cancellation.

#### `0.5.18-dev` — Read-only preflight planner
- **Status:** implemented and statically checked at code checkpoint `6064c9ea6a1d302e62b4f58c6570f138af1dadf6`; intentionally not runtime-tested as a standalone slice. Continue to `0.5.19-dev`.
- Identify all physical items contained by the target equipped bag.
- Locate the replacement bag physically, including the replacement-bag-inside-target case.
- Build compatibility-aware candidate destinations outside the target bag.
- Account for normal bags, quivers, soul bags and other specialty families.
- Determine whether the operation is possible from the current physical state.
- Do **not** physically move inventory yet.
- Temporary development diagnostics are acceptable if useful for validating planner decisions, but must remain isolated/dev-only.
- Runtime target: verify planner decisions across empty/populated targets, specialty cases, replacement-inside-target and insufficient-space inventories.

#### `0.5.19-dev` — pfUI sort + re-preflight pipeline
- **Status:** implemented and statically checked at code checkpoint `2dfad7a586b6f5cdf19e44f5509738b780bd5ab0`; intentionally not runtime-tested as a standalone slice. Continued into `0.5.20-dev`.
- If initial preflight lacks usable space, invoke pfUI's normal sort for the relevant inventory.
- Show **Sorting bags…** on the blocking overlay.
- Sort completion remains event/state driven. The `0.5.32-dev` Bagshui execution pathway does **not** change pfUI Sort ownership/completion verification; Bagshui-style short-delay retries apply only after a plan is ready for physical replacement.
- Positively verify pfUI sorting has completed before proceeding. The current pfUI `libbagsort` uses `BAG_UPDATE_DELAYED` internally and exposes no public completion callback, so one observed event must not be treated as proof of completion by itself.
- Rebuild preflight from the actual post-sort inventory state.
- End in either a verified ready-to-execute plan or the agreed insufficient-space failure overlay.
- Still do **not** perform the final bag replacement transaction.
- Runtime target: partial-stack consolidation creating space, unchanged genuinely-insufficient inventories, specialty compatibility and correct event-driven resumption.

#### `0.5.20-dev` — Core carried-bag transaction
- **Status:** implemented and statically checked at code checkpoint `a42f2c2b7b4eb6731cf6ae338b5473b4a1bcc876`; intentionally not runtime-tested as a standalone slice. Continued into `0.5.21-dev`.
- Execute only a verified plan.
- Evacuate one planned move at a time.
- `0.5.20-dev` originally waited for exact inventory-event proof after every move. That behavior is historical as of `0.5.32-dev`; the active executor now directly mirrors Bagshui's cursor-result move completion plus bounded delayed retry queue.
- Keep the old bag equipped until it is confirmed empty.
- If the replacement bag started inside the target bag, stage it automatically using the verified plan.
- Equip the replacement into the exact target carried-bag slot only after evacuation is complete.
- Do not move evacuated items back into the newly equipped bag.
- Finish with normal pfUI/BagTweaks refresh and transaction cleanup.
- Runtime target: extensive carried-bag testing including empty/populated target, replacement inside target, specialty bags, sort-created space, insufficient-space refusal and normal completion.

#### `0.5.21-dev` — Bank bags through the same pipeline
- **Status:** implemented and statically checked at code checkpoint `454ae6d3a049160a15390f67f4517be3b4b8f4a9`; intentionally not runtime-tested as a standalone slice. Stop here; continue with `0.5.22-dev` in the next development chat.
- Reuse the established preflight/state-machine/execution engine.
- Add only the bank-specific adapter details: bank container IDs, equipped bank-bag slots, permitted destination inventory, bank-open requirement and pfUI bank overlay parent.
- Do not fork a parallel bank transaction implementation.
- Runtime target: equivalent empty/populated/specialty/sort-created-space/insufficient-space cases for purchased bank bag slots.

#### `0.5.22-dev` — Recovery + edge-case hardening
- **Status:** implemented and statically checked at code checkpoint `da4e8b1832897ff23a3e8b2883524d957ce08f95`; not runtime-tested yet.
- Historical `0.5.22-dev` behavior safe-stopped immediately on unexpected locks/cursor/mismatched wake-ups. Runtime showed transient Vanilla states repeatedly triggered false failures, so `0.5.32-dev` removes that physical verifier and uses Bagshui-style retries instead. Bag/bank closure or lost target access still stops safely.
- Safe-stop clears pending/ready transaction state, performs no further automatic movement, and leaves the existing overlay latched with the specific reason plus a no-further-moves message until the user explicitly cancels.
- Carried and bank paths continue to use the same `BagReplacement` transaction engine; no parallel recovery or bank state machine was added.
- Final runtime target: the complete carried/bank replacement matrix plus regression coverage for Auto Resort, Inventory Tracking, pfUI Sort and normal bag interaction.

#### Optional ClassicAPI follow-up — only if justified
- The baseline feature must already work on ordinary pfUI without ClassicAPI.
- After the native/pfUI implementation is runtime accepted, investigate a capability-detected ClassicAPI path only if profiling or runtime evidence shows a concrete reliability or performance advantage.
- Do not add ClassicAPI merely because the capability exists.
- No user-facing setting or UX divergence; optional acceleration/reliability must remain transparent.

- **Priority changed:** bag replacement is now the next feature. Open all containers on right click moves behind the bag-replacement slice.

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
- `da4e8b1832897ff23a3e8b2883524d957ce08f95` — Complete `0.5.22-dev` recovery/edge-case hardening and version bump; shared carried/bank transaction now safe-stops on stale or rejected state.
- `fd6ddc8e27ae8f2e9ea96087c43bde6c6753f5ac` — Add shared safe-stop recovery, mismatch/lock/cursor/access guards and rejected-operation handling.
- `454ae6d3a049160a15390f67f4517be3b4b8f4a9` — Extend the shared verified bag-replacement transaction to purchased bank bag slots without a parallel bank workflow (`0.5.21-dev`).
- `a42f2c2b7b4eb6731cf6ae338b5473b4a1bcc876` — Execute verified carried-bag replacement plans one move at a time and equip only after confirmed evacuation (`0.5.20-dev`).
- `2dfad7a586b6f5cdf19e44f5509738b780bd5ab0` — Add pfUI sort invocation, event-driven completion verification and post-sort re-preflight (`0.5.19-dev`).
- `68771bca4b7ce7670c679c4f5dcffea86c7ec760` — Start the isolated `0.5.19-dev` sort/re-preflight checkpoint.
- `6064c9ea6a1d302e62b4f58c6570f138af1dadf6` — Add the non-mutating compatibility-aware bag-replacement preflight planner (`0.5.18-dev`).
- `ab5292a14f61da59e6abb28c87ff208102bdb7e9` — Start the isolated `0.5.18-dev` preflight-planner checkpoint.
- `2182a5b3336a6634b246133a1a634e4b7892c1b2` — Add the non-mutating bag-replacement interaction, shared transaction skeleton and pfUI-derived blocking overlay (`0.5.17-dev`).
- `4955c0a7925788685f6c2c940f89604da84dc8c0` — Add bag-replacement status/failure strings, including **I'll make some space...**.
- `bf8c9b8a7f6de392d6f6a18b7c2e9bfb10a247b4` — Start the isolated `0.5.17-dev` checkpoint.
- `ce538b1a5a7b6e5d8fdd4357edc55d060f84af06` — Compact shared-account rows directly under their header and add passive shared-state ticks (`0.5.16-dev`).
- `d3a1a12be4880ad511fddf1dd6c29159634316e1` — Start the isolated `0.5.16-dev` compact shared-account list checkpoint.
- `f8bef1e3ac105c5dd75f544db71d801e298ad2c8` — Complete BagTweaks layout immediately for genuine visible bag/bank opens while keeping internal CreateBags work scheduled (`0.5.15-dev`).
- `06884a2a8dd3e7e4739ef70319856be49bb1180b` — Start the isolated `0.5.15-dev` visible bag-open layout checkpoint.
- `a23e1f31cb535978d2e84d5d15dc00cd26595fb7` — Style available account values white and the empty state muted grey (`0.5.14-dev`).
- `4b6a618b675fcc30b9c30d0473125c1850dfbbda` — Start the isolated `0.5.14-dev` inventory-list text styling checkpoint.
- `996bca34aebf0f188af20e68e30547726373159c` — Refresh Available Account Inventories immediately after local Cross-Account/nickname changes (`0.5.13-dev`).
- `31178d44e929afde75a521c138c9d5b37018b9aa` — Start the isolated `0.5.13-dev` live inventory-list refresh checkpoint.
- `e35802f651af0e93b565b9c314ecdf49388d3e1c` — Reset all Inventory Tracking state once for clean first-run runtime validation (`0.5.12-dev`).
- `8f1aa7b32d1f2fd2eafdad1a8a1fc8ca8e635895` — Start the isolated `0.5.12-dev` clean-first-run tracking checkpoint.
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
- `0.5.16-dev` / `ce538b1a5a7b6e5d8fdd4357edc55d060f84af06`: user reports **all requested runtime tests passed**.
- Verified through that checkpoint: genuine bag opens complete the BagTweaks categorized layout immediately even during an active Auto Resort delay; mutation-driven re-layout still waits for the configured inactivity delay; bank open behaves correctly; the compact Available Account Inventories list sits directly under its header with ticked white shared-account rows and grey unticked empty state; Cross-Account OFF/ON and nickname changes update immediately; second-account sharing works without include/exclude controls; Character Bank and Cross-Character scope toggles work; corpse-loot/raid smoothness passed the requested recheck.

## Implemented / Awaiting Runtime Test
- `0.5.22-dev` adds a single shared safe-stop path to the existing carried/bank transaction. Safe-stop clears pending/ready state, records the failed phase, leaves the overlay reason visible when the view is available again, and prevents later unrelated inventory/equipment wake-ups from resuming stale work.
- A relevant pending wake-up must now either change the pending operation identity/clear it through verified progress or the transaction stops. Unexpected locks, cursor-held items, unavailable target/bank access and mismatched physical state are explained on the overlay rather than left silently pending.
- Source/destination staging and evacuation calls detect rejected pickup/place operations from immediate cursor state. Final `PutItemInBag` also requires the replacement to be synchronously present in the exact equipment slot; otherwise equip is treated as rejected and the transaction safe-stops.
- Closing the carried bag view or bank no longer auto-cancels and hides the reason mid-transaction; it latches a safe-stop. No further automatic movement occurs until the user explicitly cancels/cleans up.
- `0.5.21-dev` lets both carried targets and purchased bank-bag targets consume the same shared `BagReplacement` plan once it is marked `possible`/ready. The carried-only execution gate is removed; both views enter the same `BeginTransaction -> AdvanceTransaction -> VerifyPending -> FinishTransaction` engine.
- The bank adapter validates that the pfUI bank view is still open, the target maps to a purchased bank-bag index (`targetBag - 4 <= GetNumBankSlots()`), and the target physical container is available before starting or advancing.
- Exact equipped-slot resolution is view-specific only at the adapter boundary: carried targets use `ContainerIDToInventoryID(targetBag)`; bank targets follow Vanilla's bank button path with `BankButtonIDToInvSlotID(targetBag, 1)`. Both feed the same sole `PutItemInBag(targetInventorySlot)` equip operation.
- If the selected replacement is still on the cursor and evacuation is required, it is first returned to its reserved external origin. If the replacement originated inside the target, the planner reserves one external general-purpose staging slot and execution verifies that stage before any evacuation; this also gives the old equipped bag a stable external landing slot for the final swap.
- Each planned evacuation revalidates the old bag is still equipped, the exact source item/link/count is still present and unlocked, the destination is still empty/unlocked and family-compatible, then issues one source-to-destination `PickupContainerItem` move. The transaction advances only after a relevant pfUI inventory update confirms the source is empty, the destination contains the expected stack and the cursor is clear.
- Equip completion remains proof-driven for both views: the replacement link must be present in the exact equipped slot, the old bag must be stored in the replacement's external source/staging slot, and the cursor must be clear. `UNIT_INVENTORY_CHANGED` remains a carried equipment wake-up; bank equipment also wakes verification from Vanilla's `PLAYERBANKBAGSLOTS_CHANGED` event. Neither event is treated as proof by itself.
- Verified completion refreshes the affected view through normal pfUI ownership: `CreateBags()` for carried inventory and `CreateBags("bank")` for bank inventory, after transaction/overlay cleanup.
- No evacuated item is deliberately moved back into the newly equipped bag. No separate bank transaction or new mutation primitive was added. Generalized rejected-operation recovery, mismatch explanation and closure/lock hardening remain owned by `0.5.22-dev`.
- `0.5.19-dev` runs sorting only when the initial `0.5.18-dev` plan reports `needsSort`; already-possible plans are marked ready without invoking pfUI Sort.
- Sorting reuses the affected pfUI bag/bank frame's existing native Sort `OnClick` path. BagTweaks does not call `libbagsort:Sort` directly and does not introduce a second physical sorting model.
- A selected replacement still on the cursor is returned to its normal source with `ClearCursor()` before sorting. This is cursor cleanup required to let pfUI sort validly; no evacuation or equipment operation is issued by `0.5.19-dev`.
- The blocking overlay shows **Sorting bags…** while pfUI owns the sort. Sort progress wakes only from relevant inventory updates routed through the existing pfUI `UpdateBag` wrapper; there is no timeout or per-frame polling.
- One inventory update is not treated as completion. Post-sort preflight runs only after pfUI's sorter has cleared its active `bagList` state and all physical slots in the affected view are unlocked. A positively idle/no-mutation pfUI sort is the only synchronous completion path because it produces no inventory event to resume from.
- Post-sort preflight re-locates the replacement bag by scanning actual affected inventory state, so a replacement moved by pfUI Sort is not assumed to remain at its remembered source slot.
- Re-preflight rebuilds the `0.5.18-dev` plan from actual post-sort state. At the `0.5.19-dev` checkpoint a possible plan ended in `repreflight` with `active.ready=true`; `0.5.20-dev` first consumed that seam for carried bags and `0.5.21-dev` now routes purchased bank targets through the same shared execution engine. A still-insufficient plan continues to use the agreed insufficient-space overlay.
- `0.5.17-dev` hooks the existing pfUI carried/bank bag-slot controls and recognizes a replacement bag selected from a visible BagTweaks item frame for both click-and-click and drag-and-drop targeting. Bag candidates are limited to bag/quiver equip locations at this foundation stage.
- The shared `BagReplacement` transaction owner now carries the same source/target/phase state into the `0.5.18-dev` read-only preflight rather than creating a second planner path.
- `0.5.18-dev` snapshots every physical item remaining in the target bag, records the replacement bag's remembered physical origin plus whether it is still in that container or currently on the cursor, and explicitly detects replacement-inside-target from the remembered source location.
- The planner scans only empty physical destinations outside the target within the affected carried/bank inventory. General bags are universal destinations; specialty destinations are accepted only when compatibility can be proven.
- Specialty compatibility has a no-DLL baseline: an equipped specialty bag is keyed by its own item type/subtype, and items already residing in a specialty target inherit that exact family key. Optional item-family APIs are capability-detected only as an additional refinement; they are not a prerequisite. This covers quiver/ammo, soul-bag and other same-family specialty moves without guessing illegal cross-family placements.
- Replacement-inside-target now always reserves one external general-purpose staging slot before execution, including an otherwise-empty target, so the replacement can leave the target safely and the old equipped bag has an external landing slot during the final swap. Family-compatible specialty slots are allocated first, then remaining items use general slots, preserving scarce general capacity.
- The resulting plan records candidate destinations, staged replacement location, proposed source/destination moves, `missingSlots`, `possible`, and `needsSort`. A currently insufficient plan remains read-only for `0.5.19-dev`; it does not fail finally before pfUI Sort/re-preflight has had its chance to create space.
- No sorting, evacuation, equipping or other physical inventory mutation is issued by `0.5.18-dev`.
- The affected pfUI bag/bank frame gets a full-size mouse-intercepting overlay using pfUI's own backdrop constructor/configuration, centered status text, cancellation cleanup and the agreed insufficient-space acknowledgement presentation. The bag-slot popout is hidden while ownership is active so it cannot bypass the blocker.
- Recognized target clicks/drops are consumed instead of forwarding pfUI's normal bag-slot swap handler. Closing the affected view cancels ownership and returns any user-held cursor item to its source via normal cursor cleanup.
- `0.5.0-dev` adds native same-WoW-account inventory snapshots under `db.itemTracking`: carried bags `0-4`, keyring `-2`, and last-known bank `-1,5-11` with an explicit `bankKnown` flag.
- Native tracking reuses the existing pfUI `UpdateBag` and `CreateBags` ownership paths; it adds no competing bag-event scanner. The current character is initialized at `PLAYER_ENTERING_WORLD`.
- `0.5.1-dev` adds the optional Nampower bridge. Native tracking remains functional when `ReadCustomFile` / `WriteCustomFile` are unavailable.
- Cross-account files use inert deterministic `BTINV 1` text, one writer per opaque account ID, a tolerant append-only `BTREG1` registry, pcall-wrapped custom-file I/O, and a `published=0` tombstone when sharing is disabled.
- `0.5.11-dev` retires the legacy per-account inclusion model. The active preferences are **Character Bank**, **Cross-Character**, and **Cross-Account**, all OFF by default; Cross-Account ON automatically consumes all currently published, successfully parsed remote account files.
- Tooltip compilation follows the three scopes: current-character carried/keyring data is the baseline, Character Bank adds the current character's last-known bank, Cross-Character adds other same-account character snapshots, and Cross-Account adds all valid actively sharing remote account snapshots.
- The settings page uses **Current Account Nickname** plus read-only **Available Account Inventories**; there are no per-account include/exclude controls. Cross-Account is visibly disabled as requiring Nampower when the custom-file bridge is unavailable.
- `0.5.12-dev` changes only the pre-runtime reset semantics: on its first startup it deletes `db.itemTracking` once so the user sees a genuinely fresh Inventory Tracking setup, while keeping all non-tracking BagTweaks data intact.
- With Nampower available on that reset, `0.5.12-dev` tombstones the previous account file and clears the shared registry once using `pfUI_BagTweaks_reset.txt`; startup then creates a new account identity/store and rescans only the current character's live carried/keyring inventory.
- `0.5.13-dev` keeps the same data/protocol behaviour but refreshes the read-only Available Account Inventories rows immediately after the local Cross-Account checkbox callback and after Current Account Nickname edits. Enabling should add the current nickname without reopening Settings, disabling should remove it, and renaming should update the visible row immediately.
- `0.5.14-dev` keeps **Available Account Inventories** as the normal teal pfUI section header, renders actual account nickname rows in white, and renders **None currently sharing** in muted 60% grey.
- **Changed performance recommendation after runtime feedback:** scheduling every BagTweaks `CreateBags()` relayout was too aggressive. `0.5.15-dev` distinguishes a genuine visible pfBag/pfBank `OnShow` call (Vanilla global `this` equals the shown view frame) from internal maintenance/update `CreateBags()` calls. Genuine opens now run `RelayoutView(view)` immediately so the user cannot see pfUI's intermediate/raw layout; internal CreateBags calls and ordinary UpdateBag mutations still use the existing delayed scheduler.
- `0.5.16-dev` implements the user's shared-account list direction: the first account row sits directly beneath **Available Account Inventories**, additional rows pack tightly beneath it, visible shared accounts show a small teal/green check texture and white nickname, and **None currently sharing** remains unticked muted grey. Unshared accounts remain hidden; there is deliberately no cross state.
- Unscanned banks are not represented as known zero; tooltip detail marks `bank unscanned` only when bank data is actually in the selected scope.
- `0.1.44-dev` Auto resort remains awaiting runtime validation and is inherited unchanged by the `0.5.x` line.
- `0.1.43-dev` SavedVariables no-op normalization guards remain inherited unchanged.

## Static / Automated Checks
- `0.5.22-dev` resume verification: `dev` exactly matched requested handoff `9ca18a8fe461886e3d00d9fef3daf09cdd66d891` before implementation; that handoff documented `454ae6d3a049160a15390f67f4517be3b4b8f4a9` as the latest addon-affecting checkpoint.
- `.toc` is now `0.5.22-dev`; latest addon-affecting code checkpoint is `da4e8b1832897ff23a3e8b2883524d957ce08f95`.
- Compare from handoff `9ca18a8...` through the `0.5.22-dev` code checkpoint changes only `pfUI_BagTweaks.lua`, `locales/enUS.lua` and `pfUI_BagTweaks.toc`.
- Shared-engine invariant remains intact: exactly one each of `SafeStop`, `VerifyPendingState`, `VerifyPending`, `BeginTransaction`, `AdvanceTransaction`, `IssueEquip` and `OnViewHidden`; no `BeginBank` / `AdvanceBank` / `VerifyBank` / `FinishBank` path exists.
- Direct physical mutation-call counts are unchanged from the handoff: `PickupContainerItem` 8 -> 8, `ClearCursor` 4 -> 4, `PutItemInBag` 1 -> 1; `PickupBagFromSlot`, `SplitContainerItem`, `UseContainerItem`, `SwapItems` and `MoveItem` remain 0. Recovery adds verification/stop logic, not a new movement primitive.
- Static later-Lua-syntax scan found none of the checked post-5.0 constructs (`#`, `goto`/labels, `//`, variable attributes). Stripped block-count sanity check remains exact: `function + if + for + while == end` (1439).
- Canonical vendored Lua 5.0.3 compiler check: **not run/unavailable**. GCC is present, but no system `lua`/`luac`, no mounted `tools/lua50` source, and the shell cannot fetch repository files; no compiler pass is claimed.
- `0.5.21-dev` resume verification: `dev` exactly matched requested handoff `c58755a7d850c66b52be410b085b53618cb15dbd` before implementation; that handoff documented `a42f2c2b7b4eb6731cf6ae338b5473b4a1bcc876` as the latest addon-affecting checkpoint.
- `.toc` is now `0.5.21-dev`; latest addon-affecting code checkpoint is `454ae6d3a049160a15390f67f4517be3b4b8f4a9`.
- Compare from handoff `c58755a7...` through the `0.5.21-dev` code checkpoint changes only `pfUI_BagTweaks.lua` and `pfUI_BagTweaks.toc`.
- pfUI/Vanilla 1.12.1 source audit confirms pfUI exposes only purchased bank bag buttons as container IDs `5+`; Vanilla resolves a bank bag button with `BankButtonIDToInvSlotID(id, 1)` and equips through `PutItemInBag(inventoryID)`. The bank adapter follows that native slot mapping while preserving the existing shared equip primitive.
- Exact handoff -> `0.5.21-dev` direct mutation-call counts are unchanged: `PickupContainerItem` 8 -> 8, `ClearCursor` 4 -> 4, `PutItemInBag` 1 -> 1, and `PickupBagFromSlot`, `SplitContainerItem`, `UseContainerItem`, `SwapItems` and `MoveItem` remain 0. No bank-specific physical mutation primitive was added.
- No parallel bank state machine exists: no `BeginBank`, `AdvanceBank`, `VerifyBank` or `FinishBank` path is present. The bank delta is limited to target availability/purchase validation, native bank equipment-slot mapping, `PLAYERBANKBAGSLOTS_CHANGED` as an equip wake-up, and the bank-specific final pfUI refresh.
- Static later-Lua-syntax scan found none of the checked post-5.0 constructs (`#` length operator, `goto`/labels, `//`, or variable attributes). Lightweight lexical structural check reports balanced parentheses/brackets/braces and exact block closure; in the stripped current file `function + if + for + while == end` (1397).
- Canonical vendored Lua 5.0.3 compiler check: **not run/unavailable**. A C compiler is present, but no system `lua`/`luac` and no mounted `tools/lua50` source are available in the executable environment, so no compiler pass is claimed.
- `0.5.20-dev` resume verification: `dev` exactly matched requested handoff `32673b4e08311acf3cdd41c71383dd13cdc48ffc` before implementation; that handoff documented `2dfad7a586b6f5cdf19e44f5509738b780bd5ab0` as the latest addon-affecting checkpoint.
- `.toc` is now `0.5.20-dev`; latest addon-affecting code checkpoint is `a42f2c2b7b4eb6731cf6ae338b5473b4a1bcc876`.
- Compare from handoff `32673b4e...` through the `0.5.20-dev` code checkpoint changes only `pfUI_BagTweaks.lua` and `pfUI_BagTweaks.toc`.
- Vanilla 1.12.1 FrameXML audit confirms the native carried bag-slot click path calls `PutItemInBag(id)` and the drag path uses `PickupBagFromSlot(id)`; `0.5.20-dev` uses `ContainerIDToInventoryID(targetBag)` with `PutItemInBag` for the exact carried slot and does not call `PickupBagFromSlot`.
- Exact handoff -> `0.5.20-dev` mutation-call counts are: `PickupContainerItem` 2 -> 8, `ClearCursor` 3 -> 4, `PutItemInBag` 0 -> 1; `PickupBagFromSlot`, `SplitContainerItem`, `UseContainerItem`, `SwapItems` and `MoveItem` remain 0. The new calls are confined to carried replacement return/staging, one-at-a-time evacuation, final carried equip and old-bag storage.
- No bank execution primitive/path was added: carried execution is explicitly gated to `view == "backpack"` and target container IDs `1-4`; bank plans remain read-only/ready for `0.5.21-dev`.
- Static later-Lua-syntax scan found none of the checked post-5.0 constructs (`#` length operator, `goto`/labels, `//`, or variable attributes).
- Lightweight lexical structural check reports balanced parentheses/brackets/braces and exact block closure for both handoff and `0.5.20-dev` Lua; in the stripped current file `function + if + for + while == end` (1388) with no negative delimiter depth. This is a static sanity check, not a compiler/runtime test.
- The `0.5.20-dev` execution code is added as `BagReplacement` methods/properties and adds no new parent `Initialize`-scope locals; the previously documented callback-level local-declaration heuristic therefore remains 154, below Lua 5.0.3's 200-local compiler limit.
- Canonical vendored Lua 5.0.3 compiler check: **not run/unavailable**. GCC/CC are present, but no system `lua`/`luac` and no mounted `tools/lua50` source were found in the executable environment, so no compiler pass is claimed.
- `0.5.19-dev` resume verification: `dev` exactly matched requested handoff `4ebfb9c5ab0bffb595141ef19299bd64a61e3503` before implementation; that handoff documented `6064c9ea6a1d302e62b4f58c6570f138af1dadf6` as the latest addon-affecting planner checkpoint.
- `.toc` is now `0.5.19-dev`; latest addon-affecting code checkpoint is `2dfad7a586b6f5cdf19e44f5509738b780bd5ab0`.
- Compare from handoff `4ebfb9c5...` through the `0.5.19-dev` code checkpoint changes only `pfUI_BagTweaks.lua` and `pfUI_BagTweaks.toc`.
- Current pfUI audit confirms its normal sorter consolidates partial stacks, waits on `BAG_UPDATE_DELAYED` when consolidation work was fired, performs final placement, then clears `libbagsort.bagList`. BagTweaks invokes the native affected-view Sort button script and uses inventory events only as wake-ups; completion additionally requires that sorter state to be idle and all affected slots unlocked.
- At the `0.5.19-dev` checkpoint, mutation-call counts were `PickupContainerItem` 2, `ClearCursor` 3, and `PickupBagFromSlot`, `PutItemInBag`, `SplitContainerItem`, `UseContainerItem`, `SwapItems` and `MoveItem` all 0. Relative to `0.5.18-dev`, that slice added only one `ClearCursor()` before pfUI Sort and no evacuation/equip primitive.
- No direct `libbagsort:Sort(...)` invocation exists in BagTweaks; physical sorting remains owned by pfUI's native Sort handler.
- Static later-Lua-syntax scan found none of the checked post-5.0 constructs (`#` length operator, `goto`/labels, `//`, or variable attributes).
- Lightweight lexical structural check reports balanced delimiters and block structure for both the handoff Lua and current Lua; this is a static sanity check, not a compiler/runtime test.
- The `0.5.19-dev` additions are nested `BagReplacement` methods and add no parent module-callback locals; the documented callback-level local-declaration heuristic remains 154, below Lua 5.0.3's 200-local compiler limit.
- Canonical vendored Lua 5.0.3 compiler check: **not run/unavailable**. The executable environment has GCC/CC but no system `lua`/`luac`; the canonical `tools/lua50` source is not mounted into the executable environment, and shell network access cannot fetch it. Repository connector access does not make those files executable locally, so no compiler pass is claimed.
- `0.5.18-dev` resume verification: `dev` exactly matched requested handoff `0e2a2bc2e654aba20fdbe145f475ce476f0465e8` before implementation; that handoff documented `2182a5b3336a6634b246133a1a634e4b7892c1b2` as the last addon-affecting checkpoint.
- `.toc` is now `0.5.18-dev`; latest addon-affecting code checkpoint is `6064c9ea6a1d302e62b4f58c6570f138af1dadf6`.
- Compare from handoff `0e2a2bc2...` through the `0.5.18-dev` code checkpoint changes only `pfUI_BagTweaks.lua` and `pfUI_BagTweaks.toc`.
- Removing the new nested BagReplacement planner methods plus the single `Start -> Preflight` call reproduces the handoff Lua byte-for-byte. No unrelated runtime code changed.
- Exact base/head mutation-call counts are unchanged: `PickupContainerItem` 2 -> 2, `ClearCursor` 2 -> 2, and `PickupBagFromSlot`, `PutItemInBag`, `SplitContainerItem`, `UseContainerItem`, `SwapItems` and `MoveItem` remain 0 -> 0. No pfUI/libbagsort Sort invocation was added.
- Static later-Lua-syntax scan found none of the checked post-5.0 constructs (`#` length operator, `goto`/labels, `//`, or variable attributes).
- The new planner is implemented entirely as nested `BagReplacement` methods and adds no parent module-callback locals; the documented callback-level local-declaration heuristic therefore remains 154, below Lua 5.0.3's 200-local compiler limit.
- Canonical vendored Lua 5.0.3 compiler check: **not run/unavailable**. The executable environment has GCC/CC but no system `lua`/`luac`, and the canonical `tools/lua50` source is not mounted/available in the executable environment, so no compiler pass is claimed.
- Resume verification: `dev` was exactly identical to requested handoff `b3a3f8a8bf6034c0c431829a8b45bcad7a3055b2` before `0.5.17-dev` work began.
- `.toc` is now `0.5.17-dev`; latest addon-affecting code checkpoint is `2182a5b3336a6634b246133a1a634e4b7892c1b2`.
- Compare from handoff `b3a3f8a8...` through the code checkpoint changes only `pfUI_BagTweaks.lua`, `locales/enUS.lua` and `pfUI_BagTweaks.toc`.
- Exact call-count comparison shows `PickupContainerItem` remains 2 -> 2 and no `PickupBagFromSlot`, `PutItemInBag`, `SplitContainerItem` or `UseContainerItem` calls exist in either baseline or `0.5.17-dev`. The only new cursor mutation is `ClearCursor()` for cancellation/cleanup, returning the user's held item rather than relocating inventory.
- Static later-Lua-syntax scan found none of the checked post-5.0 constructs (`#` length operator, `goto`/labels, `//`, or variable attributes).
- Callback-level local-declaration heuristic is 154, below Lua 5.0.3's 200-local compiler limit.
- Canonical vendored Lua 5.0.3 compiler check: **not run/unavailable**. The private GitHub-connected VanillaTemplate checker/source is not mounted in the executable environment; no system `lua`/`luac` is installed and runtime network access cannot fetch the source. A C compiler is present, but without the vendored source no canonical compiler pass can be claimed.
- Before the new regression work, `dev` was verified identical to the documented `0.5.14-dev` handoff `1eb5b707beb1e73c058098ae6538f24df2cdfcb0`.
- `.toc` is now `0.5.16-dev`; latest addon-affecting code checkpoint is `ce538b1a5a7b6e5d8fdd4357edc55d060f84af06`.
- Compare from the `0.5.14-dev` handoff through the `0.5.16-dev` code checkpoint changes only `pfUI_BagTweaks.lua` and `pfUI_BagTweaks.toc`. The performance and UX adjustments are split into their own sequential versioned commits.
- Exact static comparison confirms the Account Inventory pending-rescan/coalescing block is unchanged from `0.5.14-dev`.
- Exact static comparison confirms the core `RequestRelayout()` Auto Resort inactivity scheduler is unchanged from `0.5.14-dev`.
- `0.5.15-dev` adds exactly one genuine-visible-open branch: when the current Vanilla script context `this` is the shown pfBag/pfBank frame, the matching BagTweaks view lays out immediately; all other CreateBags calls continue through `RequestRelayout()`.
- `0.5.16-dev` uses the standard Blizzard `Interface\\Buttons\\UI-CheckBox-Check` texture as a passive indicator, tinted to the pfUI teal/green accent. It does not add a clickable per-account state.
- The shared account rows are manually re-anchored to 18px rows with a 2px first-row gap and 1px subsequent-row gap beneath the existing pfUI teal header.
- The earlier `0.5.16-dev` static checks remain historical context; do not treat either those checks or the new `0.5.17-dev` inspection as an in-game test.

## Current Issues
- `0.5.24-dev` runtime validation still **failed at workflow entry** with Vanilla's native `You can only do that with empty bags` rejection. Stock 1.12 FrameXML confirms `UIErrorsFrame_OnEvent(event, arg1)` handles `UI_ERROR_MESSAGE`; Bagshui replaces that global through its hook manager. BagTweaks' equivalent global wrapper was evidently not durable in the target addon stack. `0.5.25-dev` therefore also registers `UI_ERROR_MESSAGE` on BagTweaks' own event frame and calls the same `OnNativeNonEmptyBagError(arg1)` recovery directly, independent of the global hook chain.
- Runtime testing must confirm actual 1.12.1 event ordering for replacement return/staging, one-at-a-time evacuation, `PutItemInBag`, native old-bag landing vs explicit cursor storage, bank `PLAYERBANKBAGSLOTS_CHANGED`, and the correct `CreateBags()` / `CreateBags("bank")` refresh.
- The recovery pass must deliberately exercise lock/mismatch/cursor/rejected-equip and bag/bank-close cases to confirm safe-stop messages appear and no stale transaction resumes from later events.
- The sort completion path deliberately depends on current pfUI's observable sorter state (`libbagsort.bagList`) plus physical slot locks after an inventory-event wake-up. The final integrated runtime test must confirm both consolidation and final-placement event ordering on the target 1.12.1/pfUI environment, including the no-op sort path.
- On a baseline 1.12 client without an item-family helper, items from a general target are conservatively planned into general-purpose destinations unless specialty compatibility can be proven. This may produce an initial `needsSort` result where pfUI Sort can create better packing; it deliberately prefers a safe false-negative preflight over guessing an illegal specialty move.
- No active runtime blocker remains from the `0.5.12-dev` through `0.5.16-dev` Inventory Tracking / bag-open validation slice.
- The previously reported half-generated bag-open symptom is considered resolved by the `0.5.15-dev` visible-OnShow immediate relayout change based on the user's passing runtime test.
- The previously reported disjointed Available Account Inventories presentation is considered resolved by the `0.5.16-dev` compact ticked list based on the user's passing runtime test.
- If Nampower custom-file capability is deliberately unavailable on the first clean reset, BagTweaks still cannot tombstone/clear old external custom files during that login; local first-run state resets correctly. This is a documented capability limitation rather than a current failing test.
- Raw SavedVariables backups may differ only in Lua table key order even when their BagTweaks state is semantically identical.

## Testing

### Last Runtime Test
- Version: `0.5.22-dev` / code checkpoint `da4e8b1832897ff23a3e8b2883524d957ce08f95`.
- User result: **BLOCKED / FAIL at bag-replacement entry**.
- Normal carried replacement failed for both drag/drop and click-and-click with Vanilla's native **You can only do that with empty bags** message; BagTweaks never reached Preparing/preflight.
- Runtime diagnostics: target bag-slot hook = true; replacement source item-frame hook = true; `BagReplacement.candidate` = nil; direct `IsReplacementBag(2,7)` on the real replacement bag = false.
- Direct client metadata check on that source returned nil item type/subtype/equip-location from `GetItemInfo(GetContainerItemLink(2,7))`.
- This result is bound only to `0.5.22-dev`; it does not invalidate the previously accepted `0.5.16-dev` Inventory Tracking/bag-open checkpoint.

### 0.5.24-dev Static Validation
- Targeted code checkpoint: `fbc9d0ce6c450ab92efff7ad32aef61ffab159bd`.
- Scope is limited to bag-replacement entry/recovery plus the dev version marker. The existing shared preflight/sort/evacuation/equip/recovery transaction engine is unchanged.
- The source item-frame hook now keeps a raw source snapshot before metadata-based recognition. This is not itself authority to swap; it is consumed only when Vanilla emits the specific populated-bag rejection.
- `UIErrorsFrame_OnEvent` is wrapped only for `UI_ERROR_MESSAGE == ERR_DESTROY_NONEMPTY_BAG`. On that error BagTweaks finds exactly one locked carried/bank bag target, uses the tracked source (or a unique locked source fallback), starts the existing transaction, and blanks the native error only when recovery successfully starts.
- Diff from the `0.5.23-dev` handoff `43e4edea09fe340f1c240bc4889b752eca198158`: only `pfUI_BagTweaks.lua` and `pfUI_BagTweaks.toc` changed.
- Direct physical mutation call counts remain `PickupContainerItem=8`, `ClearCursor=4`, `PutItemInBag=1`; `PickupBagFromSlot`, `SplitContainerItem`, `UseContainerItem`, `SwapItems` and `MoveItem` remain 0.
- Static later-Lua syntax scan found no checked post-5.0 constructs (`#` length operator, goto/labels, `//`, or variable attributes).
- Canonical Lua 5.0.3 compiler check remains unavailable/not run; no compiler pass is claimed.

### 0.5.25-dev Runtime Result
- The same populated carried-bag attempt still produced Vanilla's native **You can only do that with empty bags** message and BagTweaks did not enter the workflow. The additional error listener therefore did not solve the actual entry defect.

### 0.5.26-dev Runtime Result
- Runtime diagnostic on the replacement at bag 2 / slot 7 showed the environment split directly: legacy `GetItemInfo(...)` returned nil metadata while pfUI's own `C_Item.GetItemInfo(itemID)` returned `Container / Bag / INVTYPE_BAG`.
- `0.5.26-dev` changed `IsReplacementBag` to prefer `C_Item.GetItemInfo(itemID)`, preserving legacy `GetItemInfo` only as fallback.
- User runtime then progressed past the native empty-bag rejection into the BagTweaks overlay, proving source recognition/entry now works on this brues-code/ClassicAPI environment.
- The transaction then safe-stopped with **The cursor changed unexpectedly during bag replacement.**
- Inspection shows the normal populated-target path first returns the cursor-held replacement to its source via `ClearCursor()`. Vanilla can emit `BAG_UPDATE` while that cursor/source transition is still settling; the old verifier treated the first inconclusive wake-up as a fatal mismatch.

### 0.5.27-dev Runtime Result
- Focused retest reproduced the same **The cursor changed unexpectedly during bag replacement** safe-stop.
- This disproves the prior working assumption that the first failure was inside the asynchronous `replacement-return` verifier.
- Code inspection shows initial `LocateReplacement()` checked the remembered source slot before checking the cursor. In this ClassicAPI environment the picked-up bag can remain visible through the source-slot API while also being on the cursor, so preflight can classify it as `location="container"`, skip `replacement-return`, and immediately hit the transaction cursor guard.

### 0.5.28-dev Runtime Result
- Focused retest no longer stopped on cursor state, proving the cursor-authoritative initial preflight correction works.
- The next overlay safe-stop was **An item involved in the bag replacement became locked.**
- This shows the transaction progressed through source recognition, target interception, preflight and replacement return, then advanced into the evacuation boundary while Vanilla/ClassicAPI still exposed transient lock flags.
- The prior `0.5.27-dev` lock/cursor settling logic waited for cursor/source proof but did not require the whole affected inventory to be unlocked before starting the first planned move.

### 0.5.29-dev Runtime Result
- Focused retest still stopped with **An item involved in the bag replacement became locked.**
- This is the point where the implementation recommendation changed: continuing to add stricter event/lock settling rules was no longer justified when Bagshui already ships a proven Vanilla bag-swap mover that explicitly retries transient locks.
- The prior custom executor is therefore retained only as historical/dead-path code for now; normal execution is redirected in `0.5.30-dev`.

### 0.5.30-dev Runtime Result
- The ordinary populated carried-bag swap progressed into **Moving items ...**, proving the new executor was active and no longer failing immediately on transient locks.
- The user reported that the replacement Onyxia Scale Backpack did **not** end up in the equipped target slot.
- During the operation the pfUI/BagTweaks bag presentation looked temporarily malformed/out-of-date for several seconds.
- Code review found two remaining divergences from Bagshui semantics:
  - after `EquipCursorItem()`, BagTweaks still called `ReplacementEquipped()` synchronously and could re-run the physical equip if the ClassicAPI cache lagged;
  - pfUI `UpdateBag` / internal `CreateBags` mutations still scheduled BagTweaks category relayout while the replacement overlay owned the view.

### 0.5.31-dev Status
- Implemented and statically checked, but **not runtime-tested**. It was superseded before retest after the user requested a direct Bagshui pathway audit rather than another adapted hybrid.
- Audit found that `0.5.31-dev` still diverged materially from Bagshui: it retained custom equip-cache confirmation, omitted Bagshui's `EQUIP_BIND` popup wait, retained the old strict executor as dead code, and used custom failure semantics.

### 0.5.32-dev Runtime Result
- **PASS for the ordinary populated carried-bag replacement path.**
- User reported the same Onyxia Scale Backpack replacement finally completed successfully end-to-end.
- This runtime result proves the direct Bagshui-style physical executor for this ordinary case: evacuation, equip, and completion all succeeded.
- One presentation defect remained: the pfUI bag-slot popout used to initiate/observe the swap was closed afterward.
- Inspection found this was BagTweaks-owned behavior, not Bagshui execution: `Start()` deliberately hid `parent.bagslots` while transaction ownership was active but cleanup did not restore its previous state.

### 0.5.33-dev UI Cleanup
- Targeted code checkpoint: `f3d29c957cde09b1c751b4063f529b010c9326b7`.
- Transaction start now records whether the pfUI bag-slot popout was already shown.
- Cleanup restores the popout only when it was previously shown and the parent inventory/bank view is still open; it does not force-open a closed view.
- The direct Bagshui physical pathway is unchanged. Executable mutation counts remain `PickupContainerItem=4`, `ClearCursor=5`, `EquipCursorItem=1`, `PutItemInBag=0`; `PickupBagFromSlot` and `PutItemInBackpack` remain 0.
- Static later-Lua syntax scan found no checked post-5.0 constructs (`#` length operator, goto/labels, `//`, or variable attributes).
- Canonical Lua 5.0.3 compiler check remains unavailable/not run; no compiler pass is claimed.

### Next Runtime Test
- Retest the same ordinary Onyxia Scale Backpack swap on `0.5.33-dev` / `f3d29c957cde09b1c751b4063f529b010c9326b7` only to confirm the previously-open pfUI bag-slot popout remains/restores open after successful completion.
- If that passes, resume the remaining matrix from the `0.5.32-dev` successful physical baseline: click/click vs drag/drop, replacement-inside-target, specialty bags, pfUI-sort-created space, insufficient-space refusal, and bank bags.
- Do not re-open the already-passed ordinary physical executor unless new evidence demonstrates a regression.

### 0.5.34-dev Generic Item Tooltip Integration
- Targeted code checkpoint: `146b6cc4cb5b5a1656cb3054252ec90882b5f161`.
- Runtime report before the change: Account Inventory appeared when hovering items in pfUI bags, but not when hovering an item result in the pfQuest database browser.
- Root cause confirmed by code inspection: BagTweaks hooked only `GameTooltip:SetBagItem()`, while pfQuest item results call `GameTooltip:SetHyperlink("item:" .. id .. ...)`.
- BagTweaks now also wraps `GameTooltip:SetHyperlink()`, parses only `item:<id>` hyperlinks, and passes that ID to the existing `InventoryTracker:AppendTooltip()` renderer. Quest/spell/other hyperlink types are left untouched.
- Existing bag tooltip behavior remains unchanged.
- Static later-Lua syntax scan found no checked post-5.0 constructs (`#` length operator, goto/labels, `//`, or variable attributes).
- Canonical Lua 5.0.3 compiler check remains unavailable/not run; no compiler pass is claimed.
- Focused runtime check: search an item in pfQuest's database browser, hover it, and confirm the same **Account Inventory** section appears when tracked count is greater than zero.

### 0.5.35-dev Tooltip Layout / Colour Pass
- Targeted code checkpoint: `75a016d68457b6253f29b222477debff94f960fb`.
- Title is now **Across Accounts: <total>**. The title label and account names use pfUI green/blue (`0.3, 1.0, 0.8` / `#4DFFCC`); the total itself is white.
- Account names are indented one level; character rows are indented one further level.
- Character names are gold (`1.0, 0.82, 0` / `#FFD100`); character totals are white.
- Only the currently logged-in character shows physical location detail. Its Bags/Keys/Bank labels and punctuation are light grey, with location counts white. Same-account alts and cross-account characters show total only.
- Removed the rendered word **tracked** and the separate **Tracked total** footer.
- The local tracker marks the current character by its canonical character key, not by display-name comparison.
- Generic pfQuest/item-link tooltip support from `0.5.34-dev` remains present.
- Bag-swap physical mutation counts remain unchanged: `PickupContainerItem=4`, `ClearCursor=5`, `EquipCursorItem=1`, `PutItemInBag=0`, `PickupBagFromSlot=0`.
- Static later-Lua syntax scan found no checked post-5.0 constructs (`#` length operator, goto/labels, `//`, or variable attributes).
- Canonical Lua 5.0.3 compiler check remains unavailable/not run; no compiler pass is claimed.
- Focused runtime check: hover an item owned by the current character and at least one alt/account, both in a pfUI bag tooltip and a pfQuest database result, and verify the new hierarchy/colours plus current-character-only Bags/Bank detail.
- **Runtime PASS for tooltip tests 1-8:** pfQuest item tooltip hook, pfUI bag tooltip hook, title/total, account headings, character rows/colours, current-character Bags/Bank detail, same-account alt simplification, and cross-account simplification all confirmed by the user.
- **Physical bag-swap regression PASS on 0.5.35-dev:** user reported the populated replacement worked flawlessly after the tooltip changes.
- **Bag-slot popout restoration PASS:** user also confirmed the pfUI bag-slot popout restored correctly after the successful populated replacement.

## Planned / Next Work
1. Inventory Tracking / bag-open checkpoint through `0.5.16-dev`: **runtime accepted**.
2. `0.5.17-dev` interaction + overlay foundation: **implemented/checked**; standalone runtime testing intentionally deferred.
3. `0.5.18-dev` read-only preflight planner: **implemented/checked**; standalone runtime testing intentionally deferred.
4. `0.5.19-dev` pfUI sort + event-driven re-preflight: **implemented/checked**; standalone runtime testing intentionally deferred.
5. `0.5.20-dev` core carried-bag transaction: **implemented/checked**; standalone runtime testing intentionally deferred.
6. `0.5.21-dev` bank bags through the same shared transaction engine: **implemented/checked**; standalone runtime testing intentionally deferred.
7. `0.5.22-dev` recovery/edge-case hardening: **implemented/checked**; runtime testing intentionally deferred until the full workflow was assembled.
8. `0.5.23-dev` numeric-ID source recognition correction: **runtime failed at entry**; wrong metadata API for the target pfUI environment.
9. `0.5.24-dev` Bagshui/Swapper-style error-triggered entry fallback: **runtime failed at entry**.
10. `0.5.25-dev` independent `UI_ERROR_MESSAGE` recovery listener: **runtime failed at entry**; event fallback still did not own the attempt.
11. `0.5.26-dev` pfUI/ClassicAPI `C_Item.GetItemInfo` source recognition: **runtime passed entry**, then exposed cursor-state failure.
12. `0.5.27-dev` event-driven replacement-return settling: **runtime still failed with the same cursor safe-stop**, disproving the initial event-order-only diagnosis.
13. `0.5.28-dev` cursor-authoritative initial preflight classification: **runtime passed that failure point**, then exposed transient lock-state failure at the evacuation boundary.
14. `0.5.29-dev` wait-for-full-inventory-unlock before evacuation: **runtime still failed with the locked-item safe-stop**.
15. `0.5.30-dev` Bagshui/Swapper-style delayed-retry executor: **runtime reached item movement**, but final equip/presentation were incorrect because synchronous ClassicAPI cache proof and active relayout remained.
16. `0.5.31-dev` partial Bagshui adaptation cleanup: **implemented/checked but superseded before runtime retest** after audit showed material divergence from Bagshui remained.
17. `0.5.32-dev` direct Bagshui move-queue/equip-callback pathway with old physical executor removed: **ordinary populated carried-bag runtime PASS**.
18. `0.5.33-dev` restore previously-open pfUI bag-slot popout after transaction cleanup: **implemented/checked**; focused UI retest pending.
19. `0.5.34-dev` Account Inventory on generic item hyperlinks/pfQuest database results: **runtime PASS via 0.5.35-dev tooltip test**.
20. `0.5.35-dev` Across Accounts tooltip layout/colour pass + current-character-only location detail: **runtime PASS for tests 1-8**.
21. Bag-swap regression on `0.5.35-dev`: **runtime PASS**.
22. `0.5.33-dev` bag-slot popout restoration: **runtime PASS via 0.5.35-dev**.
23. Current focused tooltip/popout/regression set is fully runtime-passed; continue the remaining replacement matrix.
20. After bag replacement is runtime accepted, inspect/design **open all containers on right click** against the existing Open control and Auto Resort protection owner.
19. Continue any remaining generic Auto Resort edge-case validation only when a concrete workflow exposes one; do not reopen already-passed bag-open/mutation behaviour without evidence.
20. Rogue Pick Lock workflow test: **runtime PASS on stable 0.5.35**.
21. Disenchant targeting-cursor / candidate-item hover discoverability: **runtime PASS on stable 0.5.35**.
22. Remaining direct-toolbar edge-case checks.
23. Reduce the 0.20s toolbar layout refresh only if profiling or visible behaviour justifies it.

## Deferred / Out of Scope
- Open all containers on right click is deferred until the bag-replacement slice is implemented and runtime-accepted.
- Packing optimisation unless future inventories show a real problem.
- Unrelated refactors while addressing auto-sort interaction churn.
- Persisted-schema redesign solely for raw SavedVariables text-order stability.

## Release / Promotion Notes
- Main-only or release-only content to preserve: stable `.toc` Title/Version metadata; development contract/status files are not part of stable releases.
- Stable `0.5.35` promoted to `main` at `8d538035b85c08bd1f91bee2acbf05484f56e61c` for broader Gaia testing. Release tree contains the accepted dev product files with stable TOC metadata and excludes `DEV_PROGRESS.md` / `dev_rulebook.md`.
- Known validation debt accepted for release: user explicitly approved promotion of `0.5.35-dev` despite the remaining unexercised replacement edge cases so Gaia can broaden real-world testing. Still untested at promotion: replacement source physically residing inside the target bag (not practically arrangeable through the filtered BagTweaks view), specialty/profession-bag replacement due no suitable bag available, pfUI-sort-created-space and true insufficient-space refusal due current bags not full enough, and populated bank-bag replacement. Ordinary populated carried replacement, drag/drop entry, physical swap regression, tooltip integration/layout, and bag-slot popout restoration are runtime-passed.
- External/runtime prerequisites: pfUI. Nampower remains optional for existing BagTweaks behaviour, but the planned cross-account custom-file inventory feature specifically requires Nampower custom-file capability. SuperWoW and ClassicAPI remain optional unless a future feature explicitly requires one.

## Exact Next Step
Continue ordinary Gaia use of stable `0.5.35` from `main`. Pick Lock and Disenchant edge-case checks are now runtime-passed; record any further findings against the stable release. The remaining unexercised bag-replacement edge cases stay explicitly unpassed until observed.
