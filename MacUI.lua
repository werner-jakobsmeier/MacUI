local addonName, addonTable = ...

local CreateFrame = CreateFrame
local print = print

-- Initialize global registry for movable frames
addonTable.MovableFrames = {}
-- Main addon frame to handle events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        print("|cFF33FF99" .. addonName .. "|r has been successfully loaded!")
        
        -- Initialize SavedVariables if needed
        if not MacUIDB then
            MacUIDB = {}
        end
        
        -- Unregister the event since we only need it once
        self:UnregisterEvent("ADDON_LOADED")
    end
end)


