# AI Development Guidelines for MacUI

This document contains rules and best practices that the AI assistant must verify before planning or implementing any changes in this repository.

## 1. World of Warcraft API Compliance
- **Target API Version:** Always write code compatible with the latest expansion (Version 12.0 / 12.0.5+ Midnight).
- **Breaking Changes:** Reference Section 6 ("API Version Compatibility") of this document before touching combat logs, aura parsing, or raid markers.
- **Combat Lockdown:** Never attempt to dynamically create frames, move anchor points, or change secure states while the player is in combat (`InCombatLockdown()`). Use `SecureTemplates` if combat interaction is strictly necessary.

## 2. Architecture & File Structure
- **Separation of Concerns:** Do not dump all logic into a single file. 
- **Modularity:** Break out distinct UI elements (e.g., `Square.lua`, `ActionBars.lua`) and core systems into their own dedicated files.
- **TOC Management:** Always remember to add new `.lua` files to `MacUI.toc` in the correct loading order (core utilities first, then modules/UI).

## 3. WoW Addon Code Optimization & Best Practices
- **Localizing Globals (Upvaluing):** For code that runs frequently (like inside `OnUpdate` or combat events), localize Blizzard API functions at the top of the file (e.g., `local UnitHealth = UnitHealth`). Lua accesses local variables significantly faster than global table lookups.
- **Event Handling:** Unregister events as soon as they are no longer needed (e.g., `ADDON_LOADED`). Consolidate event handlers to a single parent frame when possible rather than creating dozens of frames listening to the same event.
- **Throttling Updates:** Never do heavy calculations inside an `OnUpdate` script without a throttle. If an `OnUpdate` is necessary, use a timer variable to execute logic every `0.1` or `0.2` seconds instead of every single rendered frame.
- **Disable OnUpdate when inactive:** If an `OnUpdate` script is only needed during specific states (e.g., while a buff is active or during combat), dynamically attach and remove it (`frame:SetScript("OnUpdate", nil)`) to save CPU cycles when it's not needed.
- **Frame Pooling:** Do not constantly use `CreateFrame` dynamically if you need a lot of UI elements that appear and disappear (like custom buff icons or damage numbers). Instead, create a "Frame Pool" to reuse existing hidden frames, which prevents memory bloat and garbage collection stutters.
- **Global Namespace Protection:** Do NOT pollute the WoW global namespace. Use the private `addonTable` provided at the top of every file (`local addonName, addonTable = ...`) to share variables and functions between your own files.
- **Avoiding UI Taint:** Be extremely careful when hooking or modifying default Blizzard frames. Always prefer `hooksecurefunc()` over directly overriding default functions. Modifying default UI execution paths incorrectly can lead to the dreaded "Action Blocked by MacUI" taint errors during combat.

## 4. UI Aesthetics & Rendering
- **Design:** Ensure UI elements are clean, using proper `BackdropTemplate`, modern fonts, and consistent pixel-perfect positioning.
- **Textures:** When using custom assets, try to keep dimensions to powers of 2 (e.g., 16x16, 64x64, 256x256) for optimal rendering performance.
- **Frame Strata/Level:** Manage your `FrameStrata` (e.g., "BACKGROUND", "MEDIUM", "HIGH", "DIALOG") and `FrameLevel` explicitly to prevent your custom UI elements from overlapping randomly or hiding behind default game elements.

## 5. Code Hygiene & Review Lessons
- **Cache immutable values at load time:** Data that never changes during a session (e.g., `UnitClass("player")`, `GetRealmName()`) must be read once at the top of the file and stored in a local variable. Never call these inside event handlers or `OnUpdate` scripts.
- **Consistent upvaluing in every file:** Even files that only run once at load time should upvalue their globals (e.g., `local CreateFrame = CreateFrame`). This keeps the codebase consistent and makes it easier to spot actual global namespace leaks. **Common missed upvalues include: `table`, `math`, `pairs`, `ipairs`, `tonumber`, `print`, `PlaySound`, `GetSpellTexture`.**
- **No dead code (Zero-Waste Engineering):** Variables that are set but never read, or functions that are defined but never called, must be removed immediately. Do NOT add 'precautionary' upvalues (e.g., `local math = math`) unless they are explicitly used in the file logic. Dead code creates confusion and false assumptions about what the code does.
- **Redundancy Audit:** After every feature implementation or refactor, perform a mandatory pass to find and remove any orphaned variables, unused upvalues, or stale forward declarations.
- **No duplicate declarations:** Never declare the same `local` variable twice in the same file scope. The second declaration shadows the first, creating dead code and masking the original. Use `grep` to verify before adding new upvalues.
- **Defensive guards on SavedVariables:** Always check that `MacUIDB` exists before writing to it. SavedVariables are `nil` until `ADDON_LOADED` fires, so any function that could theoretically be called early must guard against this.
- **Comment intentional exceptions:** If you must break a guideline (e.g., creating `SLASH_` globals for the WoW slash command API), add a comment explaining why it is an intentional exception. This prevents future reviewers from "fixing" something that isn't broken.

## 6. API Version Compatibility
- **Use safe fallbacks for deprecated APIs:** When Blizzard moves an API from the global namespace into a `C_` namespace (e.g., `GetSpellCharges` → `C_Spell.GetSpellCharges`), use a fallback pattern: `local GetSpellCharges = C_Spell and C_Spell.GetSpellCharges or GetSpellCharges`. This ensures the addon works across patch boundaries.
- **Verify API changes before each major patch:** Before a new WoW patch drops, search Blizzard's patch notes and the community API changelog for any renamed, moved, or removed functions that the addon currently uses.
- **Check return value types after API migrations:** When an API migrates to a `C_` namespace, the return value often changes from positional returns to a table. For example, `C_Spell.GetSpellCharges()` returns a `chargesInfo` table with `.currentCharges`, `.maxCharges`, etc., NOT the raw numbers that the old `GetSpellCharges()` returned. Always verify the new return signature in the API docs.

### 12.0 (Midnight) Restrictions & Breaking Changes
- **Secret Number Values (Health & Power):** In 12.0.5, APIs like `UnitHealth("player")` and `UnitPower("player")` return locked "secret number values" in combat. You **cannot** perform arithmetic (e.g., `(health / max) * 100`) or string manipulation (e.g., `string.format("%d", health)`) on these values, as doing so triggers a Lua taint error (`attempt to perform arithmetic on a secret number value`). To display these values, you must pass the raw secret variable directly into Blizzard's rendering APIs (e.g., `FontString:SetText(health)`). Any coloring must be done via `SetTextColor()`, not via hex string interpolation.
- **Private Auras & Secret Values:** Blizzard flags specific boss debuffs, player cooldowns, and mechanics as "secret". Addons cannot read the duration, stacks, or existence of these auras using traditional `UnitAura` or `AuraUtil` methods. Attempting to track them will return nil.
- **Combat Log Restrictions:** `COMBAT_LOG_EVENT_UNFILTERED` is heavily restricted. Do not rely on this event for catch-all combat parsing or tracking secret mechanics.
- **Aura Filtering:** Manual whitelist/blacklist of exact Spell IDs for custom unit frames is restricted. You must use Blizzard's built-in curated aura categories (e.g., "Crowd Control", "Big Defensive", "Dispelable") for unit frame filtering.
- **Combat Lockdown:** No dynamic raid marker setting via addons in combat. `InCombatLockdown()` must be strictly respected. You cannot create frames or change frame anchor points unless using Secure Templates.
- **Boss Mod API (12.0.5):** Boss mods must hook into base UI elements for timeline bars, cast counts, and `SetEventSound`. Healers should use `UnitHealPredictionCalculator` for healing/absorb predictions instead of parsing raw events.

### Reference Links
- **12.0.0 API Changes (Midnight):** https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes
- **12.0.5 API Changes:** https://warcraft.wiki.gg/wiki/Patch_12.0.5/API_changes
- **All API Change Summaries:** https://warcraft.wiki.gg/wiki/API_change_summaries
- **WoW API Reference:** https://warcraft.wiki.gg/wiki/World_of_Warcraft_API
- **Widget API:** https://warcraft.wiki.gg/wiki/Widget_API
- **Events Reference:** https://warcraft.wiki.gg/wiki/Events

## 7. Frame Pooling & Dynamic UI
- **Always pool dynamically created frames:** When UI elements are created and destroyed repeatedly (e.g., toggling tracked abilities or changing specialization), maintain a frame pool (`table.insert` on hide, `table.remove` on reuse). Never rely on creating new frames endlessly — the WoW client does not garbage-collect frames, so orphaned frames leak memory permanently.
- **Mandatory pooling for UI Rebuilds:** Any function that "rebuilds" a UI component (like `RebuildMechanics`) MUST use a frame pool for any elements that are hidden and replaced.
- **Prevent Registry Bloat:** When adding frames to a persistent registry (like `addonTable.MovableFrames`), always check if the frame is already in the list before `table.insert`. This prevents infinite list growth during repeated UI rebuilds.
- **Minimize work in factory functions:** If a factory function sets properties (like anchor points) that are immediately overridden by the caller, remove the redundant work from the factory. The caller should be responsible for positioning.

## 8. Event Handler Consolidation
- **Prefer a single `ADDON_LOADED` handler:** Ideally only `MacUI.lua` should register for `ADDON_LOADED`. After initializing `MacUIDB`, it should call init functions exposed by other modules via `addonTable`. This prevents N frames all listening for the same one-shot event. If multiple handlers are necessary, **document why** with a comment like: `-- NOTE (Guideline #8 exception): ...`
- **Avoid duplicate event listeners for the same data:** If two modules both need to react to `UNIT_AURA` for the same spell, consider having one module update a shared state in `addonTable` that the other reads, rather than both independently querying the API.

## 9. Class & Spec Awareness
- **Gate class-specific modules at load time:** Use `UnitClass("player")` at the top of a file and `return` early if the class doesn't match. This prevents the entire file from executing and registering unnecessary events. **This applies to ALL class-specific files, including utility frames like `Square.lua`, not just dedicated tracker modules.**
- **Enforce top-of-file load gating:** The class check MUST happen immediately after upvalues and before any frame creation or event registration.
- **Check spec at runtime, not load time:** Unlike class, the player's spec can change mid-session. Use `GetSpecialization()` after `PLAYER_ENTERING_WORLD` and listen for `PLAYER_SPECIALIZATION_CHANGED` to stay current. Never hardcode spec checks at file load time.
- **Always add a spec-aware `RebuildTracker()` function:** Every class module must implement a function that shows/hides the tracker based on `addonTable.playerSpec` and hook it into `addonTable.OnSpecChanged`. Do NOT process events for the wrong spec — guard every event handler with a spec check.
- **Custom abilities are user-managed:** Users add their own tracked abilities via the Smart Input Box in the Config Panel. The data is stored in `MacUIDB.customAbilities`. There is no hardcoded ability registry.

## 10. Variable Scope & Lua Pitfalls
- **Always declare loop/timer variables with `local` or as `self` properties:** A common and dangerous Lua bug is forgetting `local` on a variable inside an `OnUpdate` closure. Without `local`, the variable writes to the WoW **global** namespace on every single frame render. Use `self.timerVar` (attached to the frame) to safely store per-frame state inside closures.
  ```lua
  -- ❌ WRONG: global namespace pollution
  tracker:SetScript("OnUpdate", function(self, elapsed)
      updateTimer = updateTimer + elapsed  -- writes to _G.updateTimer!
  end)

  -- ✅ CORRECT: scoped to the frame
  tracker:SetScript("OnUpdate", function(self, elapsed)
      if not self.updateTimer then self.updateTimer = 0 end
      self.updateTimer = self.updateTimer + elapsed
  end)
  ```
- **Avoid Hoisting Errors with Forward Declarations:** In Lua, functions and variables must be defined before they are called. Calling a local function before its definition results in a "nil value" error. Instead of shuffling large blocks of code to maintain order, use **Forward Declarations** at the top of the file (e.g., `local FunctionA, FunctionB`). Then, assign them later (`FunctionA = function() ... end`). This completely eliminates hoisting errors and allows functions to call each other regardless of definition order.
- **Never reference a `local` variable before its declaration:** Lua locals are scoped from their declaration line downward. If you assign `addonTable.foo = someLocal` *before* `local someLocal = CreateFrame(...)`, `addonTable.foo` will be `nil`. Always ensure the variable exists before exporting it.
  ```lua
  -- ❌ WRONG: optionsPanel is nil at this point
  addonTable.optionsPanel = optionsPanel
  local optionsPanel = CreateFrame("Frame", ...)

  -- ✅ CORRECT: export after creation
  local optionsPanel = CreateFrame("Frame", ...)
  addonTable.optionsPanel = optionsPanel
  ```
- **Expose shared functions to `addonTable` explicitly:** If Module A defines a function that Module B needs (e.g., `ToggleLock` for the MinimapButton), you **must** assign it to `addonTable` after the function is defined. Simply defining it as `local` makes it invisible to other files. Always verify the export actually happened by checking the consuming module's usage.

## 11. Pre-Commit Review Checklist
Before finalizing any code change, verify the following:
- [ ] Every global API function used in the file is upvalued at the top.
- [ ] No `local` variable is declared twice in the same scope.
- [ ] All `OnUpdate` timer variables use `self.varName`, never bare names.
- [ ] All `addonTable` exports reference variables that are already initialized (not nil).
- [ ] Class-specific files early-return if `playerClass` doesn't match.
- [ ] Spec-sensitive logic checks `addonTable.playerSpec` and hooks `OnSpecChanged`.
- [ ] Any `C_` API migration uses the correct return type (table vs positional).
- [ ] Any intentional guideline exception has a `-- NOTE (Guideline #N exception):` comment.
- [ ] Documentation in this file reflects the current architecture (no deleted file references).
- [ ] **A Redundancy Audit has been performed and all unused variables/upvalues have been removed.**
- [ ] **Every upvalued variable at the top of the file is actively used in the logic (verified via grep).**
- [ ] **All frames added to global registries (MovableFrames) are checked for existing entries to prevent bloat.**
- [ ] **All UI rebuild components utilize frame pooling to prevent memory leaks.**
