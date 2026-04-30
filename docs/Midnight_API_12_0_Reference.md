# World of Warcraft 12.0 (Midnight) API Reference & Breaking Changes

This document serves as a persistent reference for the major UI and API breaking changes introduced in WoW 12.0 (Midnight) and 12.0.5. Keeping this in the repository ensures developers have access to the ruleset across all coding sessions.

## 1. Private Auras & Secret Values
- Blizzard flags specific boss debuffs, player cooldowns, and mechanics as "secret".
- **Rule:** Addons cannot read the duration, stacks, or existence of these specific auras using traditional `UnitAura` or `AuraUtil` methods. Attempting to track them via code will fail or return nil.

## 2. Combat Log Restrictions
- `COMBAT_LOG_EVENT_UNFILTERED` is heavily restricted.
- **Rule:** Do not rely on this event for catch-all combat parsing or tracking secret mechanics. If you need standard combat events, ensure you are only listening for un-restricted spell IDs.

## 3. Aura Filtering
- Manual whitelist/blacklist of exact Spell IDs for custom unit frames is restricted.
- **Rule:** You must use Blizzard's built-in curated aura categories (e.g., "Crowd Control", "Big Defensive", "Dispelable") for unit frame filtering.

## 4. Combat Lockdown
- **Rule:** No dynamic raid marker setting via addons in combat. Querying social statuses (AFK/DND) is locked down. `InCombatLockdown()` must be strictly respected. You cannot create frames or change frame anchor points (unless using Secure Templates) while in combat.

## 5. Boss Mod API & New Endpoints (12.0.5)
- **Boss Mods:** Must hook into base UI elements to show cast counts, set custom colors for official timeline bars, and use `SetEventSound`.
- **Healers:** Use `UnitHealPredictionCalculator` for healing/absorb predictions instead of parsing raw events.
