# AI Development Guidelines for MacUI

This document contains rules and best practices that the AI assistant must verify before planning or implementing any changes in this repository.

## 1. World of Warcraft API Compliance
- **Target API Version:** Always write code compatible with the latest expansion (Version 12.0 / 12.0.5+ Midnight).
- **Breaking Changes:** Reference `docs/Midnight_API_12_0_Reference.md` before touching combat logs, aura parsing, or raid markers.
- **Combat Lockdown:** Never attempt to dynamically create frames, move anchor points, or change secure states while the player is in combat (`InCombatLockdown()`). Use `SecureTemplates` if combat interaction is strictly necessary.

## 2. Architecture & File Structure
- **Separation of Concerns:** Do not dump all logic into a single file. 
- **Modularity:** Break out distinct UI elements (e.g., `Square.lua`, `ActionBars.lua`) and core systems into their own dedicated files.
- **TOC Management:** Always remember to add new `.lua` files to `MacUI.toc` in the correct loading order (core utilities first, then modules/UI).

## 3. WoW Addon Code Optimization & Best Practices
- **Localizing Globals (Upvaluing):** For code that runs frequently (like inside `OnUpdate` or combat events), localize Blizzard API functions at the top of the file (e.g., `local UnitHealth = UnitHealth`). Lua accesses local variables significantly faster than global table lookups.
- **Event Handling:** Unregister events as soon as they are no longer needed (e.g., `ADDON_LOADED`). Consolidate event handlers to a single parent frame when possible rather than creating dozens of frames listening to the same event.
- **Throttling Updates:** Never do heavy calculations inside an `OnUpdate` script without a throttle. If an `OnUpdate` is necessary, use a timer variable to execute logic every `0.1` or `0.2` seconds instead of every single rendered frame.
- **Frame Pooling:** Do not constantly use `CreateFrame` dynamically if you need a lot of UI elements that appear and disappear (like custom buff icons or damage numbers). Instead, create a "Frame Pool" to reuse existing hidden frames, which prevents memory bloat and garbage collection stutters.
- **Global Namespace Protection:** Do NOT pollute the WoW global namespace. Use the private `addonTable` provided at the top of every file (`local addonName, addonTable = ...`) to share variables and functions between your own files.
- **Avoiding UI Taint:** Be extremely careful when hooking or modifying default Blizzard frames. Always prefer `hooksecurefunc()` over directly overriding default functions. Modifying default UI execution paths incorrectly can lead to the dreaded "Action Blocked by MacUI" taint errors during combat.

## 4. UI Aesthetics & Rendering
- **Design:** Ensure UI elements are clean, using proper `BackdropTemplate`, modern fonts, and consistent pixel-perfect positioning.
- **Textures:** When using custom assets, try to keep dimensions to powers of 2 (e.g., 16x16, 64x64, 256x256) for optimal rendering performance.
- **Frame Strata/Level:** Manage your `FrameStrata` (e.g., "BACKGROUND", "MEDIUM", "HIGH", "DIALOG") and `FrameLevel` explicitly to prevent your custom UI elements from overlapping randomly or hiding behind default game elements.
