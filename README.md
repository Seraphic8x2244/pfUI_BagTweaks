# pfUI_BagTweaks

Development build for Vanilla WoW 1.12.1 / pfUI.

## 0.1.0-dev

This is deliberately only a layout proof-of-concept.

It keeps pfUI's existing bag slot buttons and normal bag behaviour, then visually divides the backpack into two groups:

- **General** — every normal item plus all empty bag slots.
- **Test Group** — Hearthstone, item ID `6948`.

Nothing is moved between physical bag slots. There is no automatic sorting, no drag/drop classification, and no permanent group configuration yet.

The bank is intentionally untouched in this build.

### What to test

1. Open and close the backpack normally.
2. Confirm the `General` and `Test Group` headers appear inside the normal pfUI bag window.
3. Confirm the Hearthstone appears under `Test Group` while other items remain under `General`.
4. Move the Hearthstone between physical bag slots and confirm it remains visually in `Test Group` after the bag update.
5. Confirm normal item interaction still works: use, drag, split stacks, tooltips, cooldowns, bag-slot display, search, etc.
6. Test on both Shagu pfUI and brues-code pfUI.

### Expected limitations

- The group is hard-coded only to prove the layout hook.
- Group creation/rename/delete does not exist yet.
- Group headers are not drop targets yet.
- Per-group sorting does not exist yet.
- Header/search/button controls do not exist yet.
- The visual styling is intentionally minimal and temporary.
