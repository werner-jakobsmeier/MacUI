local addonName, addonTable = ...

local CreateFrame = CreateFrame
local print = print
local UIParent = UIParent
local UnitClass = UnitClass
local GetSpecialization = GetSpecialization
local table = table

-- Cache player class at load time (never changes)
local _, playerClass = UnitClass("player")
addonTable.playerClass = playerClass

-- Spec is not available until PLAYER_ENTERING_WORLD
addonTable.playerSpec = nil

-- Callbacks other modules can register to react to spec changes
addonTable.OnSpecChanged = {}

-- Callbacks for when display toggles change
addonTable.OnDisplayChanged = {}

-- Resource/Power metadata per class+spec
-- Each class has a primary resource; some specs also have a secondary "power".
-- This drives the Config UI tile labels and colors.
addonTable.ClassDisplayInfo = {
    WARRIOR = {
        resource = { name = "Rage", color = {1, 0, 0} },
        -- No secondary power for Warriors
    },
    PALADIN = {
        resource = { name = "Mana", color = {0, 0, 1} },
        power = { name = "Holy Power", color = {1, 0.9, 0.5}, specs = {1, 2, 3} },
    },
    ROGUE = {
        resource = { name = "Energy", color = {1, 1, 0} },
        power = { name = "Combo Points", color = {1, 0.5, 0}, specs = {1, 2, 3} },
    },
    DEATHKNIGHT = {
        resource = { name = "Runic Power", color = {0, 0.82, 1} },
    },
    HUNTER = {
        resource = { name = "Focus", color = {1, 0.5, 0.25} },
    },
    MAGE = {
        resource = { name = "Mana", color = {0, 0, 1} },
        power = { name = "Arcane Charges", color = {0.5, 0.5, 1}, specs = {1} },
    },
    WARLOCK = {
        resource = { name = "Mana", color = {0, 0, 1} },
        power = { name = "Soul Shards", color = {0.6, 0.2, 0.8}, specs = {1, 2, 3} },
    },
    MONK = {
        resource = { name = "Energy/Mana", color = {0, 1, 0.6} },
        power = { name = "Chi", color = {0.7, 1, 0.9}, specs = {3} },
    },
    DRUID = {
        resource = { name = "Mana", color = {0, 0, 1} },
    },
    PRIEST = {
        resource = { name = "Mana", color = {0, 0, 1} },
    },
    SHAMAN = {
        resource = { name = "Mana", color = {0, 0, 1} },
    },
    DEMONHUNTER = {
        resource = { name = "Fury", color = {0.8, 0.3, 0.9} },
    },
    EVOKER = {
        resource = { name = "Mana", color = {0, 0, 1} },
        power = { name = "Essence", color = {0, 0.8, 0.5}, specs = {1, 2, 3} },
    },
}

local function UpdatePlayerSpec()
    local specIndex = GetSpecialization()
    addonTable.playerSpec = specIndex
    -- Notify all registered callbacks
    for _, callback in ipairs(addonTable.OnSpecChanged) do
        callback(specIndex, playerClass)
    end
end

-- Initialize global registry for movable frames
addonTable.MovableFrames = {}
-- Main addon frame to handle events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        print("|cFF33FF99" .. addonName .. "|r has been successfully loaded!")
        
        -- Initialize SavedVariables if needed
        if not MacUIDB then MacUIDB = {} end
        if not MacUIDB.audioAlerts then MacUIDB.audioAlerts = {} end
        if not MacUIDB.customAbilities then MacUIDB.customAbilities = {} end
        if not MacUIDB.minimap then MacUIDB.minimap = { angle = 45 } end
        if not MacUIDB.displays then MacUIDB.displays = { health = true, resource = true, power = true } end
        
        -- Unregister the event since we only need it once
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdatePlayerSpec()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        UpdatePlayerSpec()
    end
end)


