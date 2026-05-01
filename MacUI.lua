local addonName, addonTable = ...

local CreateFrame = CreateFrame
local print = print
local UnitClass = UnitClass
local GetSpecialization = GetSpecialization

-- Cache player class at load time (never changes)
local _, playerClass = UnitClass("player")
addonTable.playerClass = playerClass

-- Spec is not available until PLAYER_ENTERING_WORLD
addonTable.playerSpec = nil

-- Callbacks other modules can register to react to spec changes
addonTable.OnSpecChanged = {}

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
        if not MacUIDB then
            MacUIDB = {}
        end
        
        -- Unregister the event since we only need it once
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdatePlayerSpec()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        UpdatePlayerSpec()
    end
end)


