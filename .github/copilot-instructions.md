# MacUI — AI Coding Instructions

**IMPORTANT: Before writing or modifying ANY code in this repository, you MUST read and follow the rules in `.github/AI_DEVELOPMENT_GUIDELINES.md`.**

This is a World of Warcraft addon targeting the **12.0.5 (Midnight)** API. The guidelines contain critical rules about:

1. **API Compliance** — Which APIs are deprecated, which return tables vs positional values, and which auras are "secret" and unreadable.
2. **Performance** — All globals must be upvalued, `OnUpdate` must be throttled and disabled when inactive, frames must be pooled.
3. **Architecture** — Class modules must early-return for non-matching classes, spec checks must happen at runtime not load time, cross-file communication uses `addonTable`.
4. **No Global Leaks** — Never pollute the WoW global namespace. The only exceptions are `SLASH_` commands and `AddonCompartment` callbacks (documented in the guidelines).
5. **SavedVariables Safety** — Always guard `MacUIDB` access. It is `nil` until `ADDON_LOADED` fires.

## Pre-Commit Checklist (Section 11 of Guidelines)
Before finalizing any change, verify:
- [ ] Every global API function is upvalued at the top of the file.
- [ ] No `local` variable is declared twice in the same scope.
- [ ] All `OnUpdate` timer variables use `self.varName`, never bare names.
- [ ] All `addonTable` exports reference variables that are already initialized.
- [ ] Class-specific files early-return if `playerClass` doesn't match.
- [ ] Spec-sensitive logic checks `addonTable.playerSpec` and hooks `OnSpecChanged`.
- [ ] Any `C_` API migration uses the correct return type (table vs positional).
- [ ] Any intentional guideline exception has a `-- NOTE (Guideline #N exception):` comment.

## File Structure
- `MacUI.lua` — Core event handler, DB init, spec change system.
- `Config.lua` — Options panel, Lock/Unlock, font size, Smart Input Box.
- `AbilityTracker.lua` — Custom spell tracking with independent, draggable icons.
- `Square.lua`, `WarriorTracker.lua`, `PaladinTracker.lua` — Class-specific modules.
- `PlayerHealth.lua` — Player health percentage display.
- `Animations.lua` — Reusable animation functions.
- `MinimapButton.lua` — AddonCompartment + legacy draggable minimap button.
