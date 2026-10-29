# pfUI [BagTweaks]

BagTweaks modernises and expands pfUI's bag UI for Vanilla WoW.

## Highlights

Designed to work across pfUI versions and forks while respecting your existing bag profile settings.

- Flexible **filter categories and subcategories** with drag-and-drop organisation
- **Inventory tracking** across characters and multiple WoW accounts
- Improved **bag controls**, including *toggleable* **Disenchant**/**Pick Lock** and swapping populated bags without emptying them first

## Feature List

- Create custom **Categories** and **Subcategories** to visually organise inventory
- Drag-and-drop item organisation
- Set Subcategories as **Account Wide** or **Per Character**
- Sort by **Default, Name, Vendor Value or Character Slot**
- Automatic **Quest** category with active quest-objective detection
- Compact backpack and bank toolbars with **Search, Sort, Bags, Keys, Quest, Disenchant, Pick Lock, Open** and category controls
- **Disenchant** and **Pick Lock** work as persistent *toggle modes*
- **Inventory Tracking** across characters, banks and optionally multiple WoW accounts
- Cross-account inventory tracking requires **Nampower.dll**
- Replace equipped bags without emptying them first
- **Compact Empty Slots** (optional): combine unused ordinary bag slots into one numbered counter to reduce inventory height. Click with an empty cursor to reveal/re-collapse real empty slots, or left-click the General counter with a split/held stack to place it in an eligible physical slot and show the result immediately. Specialty counters reveal their real slots when an item is held.
- Independent **Keyring** and **Quivers** sections, with their own empty capacity counters. Quiver and keyring capacity is never included in normal bag free space.
- **Show Quivers** setting hides the entire quiver section visually without moving items or disabling the equipped quiver. Existing Keys toolbar control still owns keyring visibility.
- Configure **Collapse empty slots into counters** (off by default) and **Show Quivers** (on by default) under pfUI → Thirdparty → pfUI [BagTweaks]. Other specialty bags remain visible and do not inflate the general-purpose empty-slot counter.

**Requirements:** pfUI  
**Optional:** Nampower.dll for cross-account inventory tracking

`main` = stable release  
`dev` = active development/testing

**Development note:** `dev` is currently `0.5.49-dev`, adding direct General-counter placement for cursor-held stacks with immediate placement visibility. This change is awaiting in-game runtime validation. Stable `main` remains `0.5.48`.
