# pfUI_BagTweaks

A lightweight pfUI plugin for Vanilla WoW 1.12.1, developed and tested against brues-code pfUI, with compatibility code retained for Shagu pfUI where practical.

`main` is the stable branch. Active development happens on `dev`.

## Expected Features

- User-created visual item categories inside the normal pfUI backpack and bank windows.
- Drag-and-drop item classification between categories.
- Optional default Quest category, including active item-objective detection, with manual assignments taking priority.
- Per-category sorting by Default (physical bag order), name, vendor value, and character equipment slot.
- Matching backpack/bank header controls for search, pfUI's physical sorting, view options, Quest, and addon options; profession shortcuts remain backpack-only.
- Visual categorying never moves physical inventory; only the explicit Sort control uses pfUI's normal inventory sorter.
