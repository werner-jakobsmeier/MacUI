local addonName, addonTable = ...

-- Ability Registry: Data-only definitions for all trackable abilities per class.
-- type = "buff" (active buff on player), "absorb" (absorb shield active)
-- spec = (optional) spec index that this ability is relevant to. nil = all specs.
--   Warrior: 1=Arms, 2=Fury, 3=Protection
addonTable.AbilityRegistry = {
    WARRIOR = {
        { spellID = 2565,   name = "Shield Block",   type = "buff",   spec = 3 },
        { spellID = 23920,  name = "Spell Reflect",  type = "buff"              },
        { spellID = 190456, name = "Ignore Pain",    type = "absorb", spec = 3 },
    },
    -- Future classes can be added here:
    -- PALADIN = { ... },
    -- DEATHKNIGHT = { ... },
}
