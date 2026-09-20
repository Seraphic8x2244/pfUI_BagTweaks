# Addon Development Guide

## Structure

Default layout:

```text
AddonName/
    AddonName.toc
    AddonName.lua
    locales/
        enUS.lua
        [optional translations]
    artwork/
        [flat assets]
    DEV_GUIDE.md
    DEV_PROGRESS.md
    Debug.lua       # dev only, when needed
```

- One main Lua file unless explicitly agreed otherwise.
- `Debug.lua` is the normal development exception.
- All user-facing strings go in `locales/enUS.lua`.
- Translations use `locales/<locale>.lua`.
- All artwork goes in `artwork/`, flattened unless explicitly agreed otherwise.
- Avoid bundled libraries or frameworks unless required.

## Target Environment

- World of Warcraft 1.12.1.
- `## Interface: 11200`.
- Lua 5.0.
- Code against the native WoW 1.12.1 API by default.
- Do not rely on later Lua syntax or later WoW APIs unless an explicitly supported client extension provides the required capability.

## Optional Client Extensions

Nampower, SuperWoW and ClassicAPI may be supported.

- Treat client extensions as optional capability enhancements, not default dependencies.
- Prefer the native 1.12.1 path when it provides a good solution.
- Use an extension when it materially improves correctness, capability or implementation quality.
- Preserve a native/non-DLL path where reasonably possible.
- Do not make existing native functionality DLL-dependent without an explicit reason.
- If a feature cannot reasonably preserve a native fallback, flag the dependency to the user before treating it as required.

## Versioning

The `.toc` is the single source of truth for version.

```lua
local ADDON_NAME = "AddonName"
local ADDON_VERSION = GetAddOnMetadata(ADDON_NAME, "Version")
```

- Never hardcode the version separately in Lua.
- Use `ADDON_NAME` and `ADDON_VERSION`.
- `GetAddOnMetadata` uses the real addon/folder name.

Development:

```toc
## Title: AddonName-dev
## Version: 0.1.0-dev
```

Stable:

```toc
## Title: AddonName
## Version: 0.1.0
```

- Use `-dev`, never `-dev1`, `-dev2`, etc.
- Commits identify individual development states.

## `dev` Branch

All active development happens on `dev`.

- `.toc` Title and Version include `-dev`.
- Contains `DEV_GUIDE.md` and `DEV_PROGRESS.md`.
- May contain `Debug.lua`.
- The dev `.toc` may load `Debug.lua`.
- Debug functionality must not be required for normal addon operation.
- Experimental or incomplete work is allowed when clearly recorded in `DEV_PROGRESS.md`.

`DEV_GUIDE.md` is the development contract. Development chats should not alter it unless the user explicitly changes the standard.

## `main` Branch

`main` contains stable releases only.

Push to `main` only after the user explicitly confirms a stable, clear version worth releasing.

Before pushing:

- Remove `-dev` from Title and Version.
- Do not include `DEV_GUIDE.md`.
- Do not include `DEV_PROGRESS.md`.
- Remove `Debug.lua` and its `.toc` entry.
- Do not include knowingly untested or speculative work.

`main` should always be directly installable as a known-good release.

## Development Rules

- Preserve existing architecture unless deliberately changing it.
- Do not silently broaden scope.
- Do not perform unrelated refactors during targeted fixes.
- Structural changes require explicit agreement.
- Do not add modules, systems, abstractions or dependencies without a concrete need.
- Fix underlying causes rather than adding bandages, guards, retries or compatibility hacks.
- If a workaround appears necessary, flag it to the user and explain the underlying issue.
- Temporary workarounds require explicit agreement and must not replace a proper fix.

## Testing

Keep these states distinct:

**implemented -> checked -> user tested -> stable -> released**

- Implemented does not mean tested.
- Static or code inspection does not count as an in-game test.
- User in-game confirmation is required for verified behaviour.
- Record partial tests accurately.
- Keep untested behaviour explicitly marked as untested.

## `DEV_PROGRESS.md`

`DEV_PROGRESS.md` describes the current `dev` state, not project history.

Keep it concise and sufficient for a fresh chat to resume immediately.

Track:

- Branch and version.
- Latest relevant commits.
- Current goal.
- Completed and user-verified work.
- Implemented but untested work.
- Current issues.
- Testing state and next test.
- Planned/to-do work.
- Ideas/backlog.
- Deferred work.
- Exact next step.

Development chats should update `DEV_PROGRESS.md` as work progresses and before handing work to a fresh chat.

Git history carries history; `DEV_PROGRESS.md` carries current state.
