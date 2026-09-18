# pfUI_BagTweaks

A lightweight pfUI plugin for Vanilla WoW 1.12.1, developed and tested against brues-code pfUI, with compatibility code retained for Shagu pfUI where practical.

`main` is the stable branch.

## Expected Features

- Full-width user-created Categories containing dynamically packed Subcategories.
- Subcategories classify items and retain account/per-character scope plus visual sorting.
- Drag-and-drop item classification between Subcategories, and Subcategory reordering/movement between Categories.
- Optional built-in Quest Subcategory, including active item-objective detection, with manual categorization taking priority.
- General remains fixed at the bottom and contains all empty physical slots.
- Layout width, item size, borders, anchoring, and physical sorting continue to respect pfUI's own bag settings.
- Matching backpack/bank header controls for search, pfUI's physical sorting, view options, Quest, and addon options; profession shortcuts remain backpack-only.
- Visual categorization never moves physical inventory; only the explicit Sort control uses pfUI's normal inventory sorter.
