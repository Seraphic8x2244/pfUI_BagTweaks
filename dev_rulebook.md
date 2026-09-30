# Vanilla Addon Development Rulebook

This document is the canonical development workflow for Vanilla WoW 1.12.1 addon projects based on this template.

It supersedes `DEV_GUIDE.md` once adopted.

Project-specific development state, architecture decisions, invariants, protocols, testing state, deferred scope and exceptions belong in `DEV_PROGRESS.md`.

Permanent product or user documentation may exist where useful, but it is not a competing development source of truth.

---

## 1. Authority and sources of truth

Use these sources for different kinds of truth:

- `dev_rulebook.md` — canonical development workflow and engineering rules.
- `DEV_PROGRESS.md` — current project state, project-specific development contract and fresh-chat recovery source.
- Git history and current code — historical implementation record and implemented reality.
- The addon `.toc` — version source of truth.

Development branches using this workflow must carry the canonical VanillaTemplate `dev_rulebook.md` unchanged.

Addon-development chats must treat `dev_rulebook.md` as read-only and authoritative. They follow it; they do not modify it.

Project-specific requirements or exceptions belong in `DEV_PROGRESS.md`, not in a modified local rulebook.

Do not maintain competing live handoff documents. Once still-relevant information from a legacy `HANDOFF.md` has been migrated into `DEV_PROGRESS.md`, delete the legacy handoff.

Git history carries history. `DEV_PROGRESS.md` carries current state.

---

## 2. Default structure

Default layout:

```text
AddonName/
    AddonName.toc
    AddonName.lua
    locales/
        enUS.lua
        [optional translations]
    assets/
        [artwork, sounds and other static assets]
    dev_rulebook.md
    DEV_PROGRESS.md
    Debug.lua       # dev only, when needed
```

Defaults:

- Prefer one main Lua file unless the established architecture or an explicitly agreed design calls for more.
- Preserve established multi-file architectures in existing addons.
- `Debug.lua` is the normal development-only exception.
- Put user-facing strings in the project's localization system. For new template addons, use `locales/enUS.lua`.
- Put translations in the corresponding locale file.
- Put addon-owned artwork, sounds and other static assets under `assets/`, flattened unless there is a concrete reason for subdirectories.
- Avoid bundled libraries, frameworks or dependencies unless they solve a concrete requirement.

---

## 3. Target environment

Default target:

- World of Warcraft 1.12.1.
- `## Interface: 11200`.
- Lua 5.0.3.
- Native WoW 1.12.1 API unless an explicitly supported client extension supplies additional capability.

Do not use later Lua syntax or later WoW APIs.

### Lua 5.0.3 implementation limits

Lua 5.0.3 has a parser/compiler limit of 200 local variables in a function.

The top-level addon chunk is compiled as a function, so large single-file addons can also hit this limit through top-level locals.

Watch local counts as files grow. Do not solve a local-limit failure by blindly globalizing internal state; use a deliberate structural fix consistent with the addon architecture.

Static compatibility inspection is useful but is not an in-game test.

### Canonical Lua 5.0.3 compiler check

VanillaTemplate provides the canonical reproducible Lua 5.0.3 checker under `tools/lua50/`. It vendors the Lua 5.0.3 compiler source and builds a temporary `luac` with the host C compiler. A system-installed `lua` or `luac` is neither required nor expected.

Repository access and executable-environment access are different. Being able to read the checker through GitHub does not necessarily mean its files are available to the chat's shell/container.

When the checker files are accessible from the executable environment and a usable C compiler is available, run the canonical checker before claiming that changed Lua files received a Lua 5.0.3 compiler pass. The checker may be run from VanillaTemplate against another addon checkout; it does not need to be copied into every addon repository.

Do not treat the absence of a system-installed `lua` or `luac` as proof that the compiler check cannot be performed. First determine whether the vendored checker can be used.

If the checker cannot actually be run, record the concrete limitation and do not claim a compiler pass.

A successful compiler pass proves Lua 5.0.3 parsing and compiler-limit compatibility for the files actually checked. It does not prove WoW API correctness or in-game behaviour.

---

## 4. Optional client extensions

Nampower, SuperWoW, ClassicAPI and other explicitly selected client extensions may be supported.

Rules:

- Treat extensions as optional capability enhancements unless the project explicitly requires one.
- Prefer the native 1.12.1 path when it provides a good solution.
- Use an extension when it materially improves correctness, capability or implementation quality.
- Preserve a native/non-DLL path where reasonably possible.
- Do not make existing native functionality DLL-dependent without an explicit reason.
- If a feature cannot reasonably preserve a native fallback, flag that dependency before treating it as required.
- When an extension is an explicit prerequisite, use its real capabilities rather than duplicating weaker fallback implementations without a reason.

---

## 5. Versioning

The addon `.toc` is the single source of truth for version.

Example:

```lua
local ADDON_NAME = "AddonName"
local ADDON_VERSION = GetAddOnMetadata(ADDON_NAME, "Version")
```

Rules:

- Never hardcode the addon version separately in Lua.
- Use the real addon/folder name with `GetAddOnMetadata`.
- Development builds use `-dev`.
- Every addon-affecting code, runtime, loader or metadata revision must bump the addon version before or as part of that revision. Do not use Git commits as a substitute for version increments.
- Increment the patch component for ordinary development revisions within the same planned release line, for example `2.1.0-dev` -> `2.1.1-dev` -> `2.1.2-dev`.
- A deliberate major/minor release-line change may instead bump that component, for example moving from the native 2.1 line to `3.0.0-dev`.
- Documentation-only/status-only commits that do not change the addon product may keep the current addon version.
- Do not invent suffix counters such as `-dev1` or `-dev2`; the numeric semantic version is the revision counter and `-dev` only marks development status.

Development:

```toc
## Title: AddonName-dev
## Version: 0.1.1-dev
```

Stable:

```toc
## Title: AddonName
## Version: 0.1.1
```

A user-tested result belongs to the exact version/commit that was tested. A later version may inherit that known-good baseline, but its new delta remains untested until exercised.

---

## 6. Branch model

### `dev`

For new template addons, active development happens on `dev`.

The development branch:

- uses development Title/Version metadata;
- contains `dev_rulebook.md` and `DEV_PROGRESS.md`;
- may contain dev-only debug/test helpers;
- may contain clearly documented incomplete or experimental work.

Existing repositories may use an established development or feature branch instead. The same development rules apply to whichever branch owns the current work.

### `main`

`main` contains stable releases or the project's intentionally stable baseline.

For template addons, stable releases must:

- use stable Title/Version metadata;
- exclude `DEV_PROGRESS.md`;
- exclude dev-only debug/test helpers;
- exclude development-only loader entries;
- exclude knowingly speculative work unless the user explicitly authorizes release with the remaining validation debt documented.

Project-specific release exceptions belong in `DEV_PROGRESS.md`.

---

## 7. Starting or resuming development

Before substantial code changes:

1. Read `dev_rulebook.md`.
2. Read `DEV_PROGRESS.md`.
3. Resolve the documented development branch and handoff/head.
4. Verify that the actual remote branch head still matches the state being resumed.
5. Identify the latest stable runtime/release baseline separately from the current development state.
6. Confirm the requested work does not silently cross a documented deferred boundary or contradict the current development contract.

If the branch has moved since the recorded handoff, inspect and reconcile the new state before writing.

Do not force-update over concurrent work.

A casual chat request must not silently override the written project contract. If the request intentionally changes that contract, make the change explicit in `DEV_PROGRESS.md`.

---

## 8. Scope and architecture

General rules:

- Preserve existing architecture unless deliberately changing it.
- Do not silently broaden scope.
- Do not perform unrelated refactors during a targeted fix.
- Structural changes require an explicit reason.
- Do not add systems, abstractions, modules or dependencies without a concrete need.
- Fix underlying causes rather than layering accidental bandages over them.
- Temporary workarounds require explicit agreement and must remain identified as temporary.

### Architectural ownership

When a domain already has an authoritative request path, coordinator, state owner or lifecycle front door:

- route new entry points through that owner;
- do not bypass it unintentionally;
- do not create a parallel scheduler or state machine for work already owned elsewhere;
- preserve clear ownership of identity, state mutation and lifecycle transitions.

Before adding a new execution path, check whether the project already has an owner for that operation.

---

## 9. User agency and addon design

Design for capable users.

Valid behaviour should remain available even when it is unusual, extreme or inconvenient.

Restrict behaviour only when necessary to preserve correctness, state integrity, an architectural invariant or a genuine external/API constraint.

Use the narrowest constraint that solves the real problem. Prefer clear feedback over silently replacing user intent with developer judgement.

When unusual input exposes an implementation weakness, first determine whether the implementation can be made robust enough to support it rather than forbidding the input.

Timing, throttling, locking, cooldowns and retry behaviour are product behaviour. Do not introduce or tune them by guesswork; base them on concrete protocol, integrity or runtime requirements.

**Enforce correctness, not preference.**

---

## 10. Testing states and provenance

Keep these states distinct:

**implemented -> checked -> user tested -> stable -> released**

Definitions:

- **Implemented** — code exists.
- **Checked** — relevant static review, compiler/build checks, automated tests or CI actually ran and passed.
- **User tested** — the relevant runtime behaviour was exercised by the user in the target environment.
- **Stable** — the behaviour/build has been accepted as a known-good baseline.
- **Released** — the stable build has been promoted/published through the project's release mechanism.

Rules:

- Implemented does not mean tested.
- Static inspection or CI does not count as an in-game test.
- A successful adjacent test does not prove an untested path.
- Bind runtime results to the exact tested version/commit.
- Record partial tests accurately.
- When later work builds on a tested baseline, distinguish inherited known-good behaviour from the new untested delta.
- Never rewrite validation history by treating release itself as a runtime test.
- A check counts as performed only when the relevant tool actually ran against the stated files or build. Distinguish **passed**, **failed**, and **not run/unavailable**.

When runtime testing is required, present the test steps in chat as a numbered list, with one concrete check per item, so the user can reply point by point.

If the user authorizes promotion despite known untested work, record that validation debt clearly.

---

## 11. `DEV_PROGRESS.md`

`DEV_PROGRESS.md` is the sole live project-development status and contract document.

Keep it concise enough that a fresh chat can resume immediately.

At minimum track:

- current branch;
- current dev version;
- current/handoff branch-head commit;
- latest stable release/runtime version and commit;
- current goal and scope boundary;
- active architecture/design decisions and invariants;
- protocol/data-model decisions where relevant;
- recent relevant commits;
- completed and user-verified work;
- implemented but untested work;
- static/automated checks performed;
- current issues;
- last runtime test and exact tested version/commit;
- next runtime test;
- planned work;
- deferred/out-of-scope work;
- exact next step.

Where relevant, also record:

- project-specific workflow or release exceptions;
- accepted validation debt;
- external/runtime prerequisites.

Do not turn `DEV_PROGRESS.md` into a chronological diary. Remove or compress superseded implementation narrative once it no longer affects current decisions, testing or recovery.

---

## 12. Long-chat and handoff discipline

Do not push development chats until context becomes unreliable.

Before context loss becomes likely:

1. stop at a coherent checkpoint;
2. bring `DEV_PROGRESS.md` fully up to date;
3. commit the status/handoff update;
4. provide a short copy-paste resume prompt for a fresh chat.

The resume prompt should identify:

- repository;
- development branch;
- `DEV_PROGRESS.md` as the recovery source;
- current handoff commit;
- exact next step;
- any critical scope boundary.

A new chat must verify the recorded handoff against the actual repository state before continuing.

---

## 13. Commit and promotion discipline

Prefer coherent commits that identify meaningful development states.

Before release/promotion:

1. identify the exact tested/accepted development state;
2. identify the current `main` state;
3. remove development-only files, debug hooks and development-only loader entries;
4. apply stable Title/Version metadata;
5. verify the release tree contains the intended runtime delta and no unintended development material;
6. run all available relevant static/build/automated checks;
7. record any runtime validation debt honestly;
8. promote through the project's established release mechanism.

After promotion:

- record the stable version and exact stable commit;
- distinguish the promotion/release commit from the tested development commit if they differ;
- do not claim that the exact stable tree received a runtime test unless it actually did.

For projects with CI/release workflows, a temporary build artifact is not automatically a product release. Use the project's actual publishing path when releases depend on tags, checksums, GitHub Releases, updater discovery or similar metadata.

---

## 14. Development contract changes

This rulebook is the canonical shared development standard.

Ordinary addon-development work must not modify it.

A rulebook change is appropriate only when the user explicitly opens work to review or revise the development standard itself.

When the canonical rulebook changes, development branches using it should be synchronized to the canonical VanillaTemplate copy without introducing local edits.

Project-specific exceptions belong in `DEV_PROGRESS.md`.
