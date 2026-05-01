local addonName, addonTable = ...

-- Localize Globals for optimization
local CreateFrame = CreateFrame
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local string = string
local math = math
local UIParent = UIParent
local table = table

-- Create an independent, movable frame for the health text
local frame = CreateFrame("Frame", "MacUIPlayerHealth", UIParent)
frame:SetSize(150, 30)
frame.defaultPoint = {"CENTER", UIParent, "CENTER", 0, -60}
table.insert(addonTable.MovableFrames, frame)

-- Create FontString
local healthText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
healthText:SetPoint("CENTER", frame, "CENTER", 0, 0)
frame.fontStrings = { healthText }

-- Update Function
local function UpdateHealth()
    local health = UnitHealth("player") or 0
    local maxHealth = UnitHealthMax("player") or 1
    
    -- Prevent division by zero
    if maxHealth <= 0 then maxHealth = 1 end
    
    -- Calculate percentage and round down to nearest whole number
    local percent = math.floor((health / maxHealth) * 100)
    
    -- Green font
    healthText:SetText(string.format("|cFF00FF00Health: %d%%|r", percent))
end

-- Event Registration
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_MAXHEALTH")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Event Handler
frame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        UpdateHealth()
    elseif (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") and unit == "player" then
        UpdateHealth()
    end
end)
