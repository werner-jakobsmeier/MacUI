local addonName, addonTable = ...

-- Localize Globals for optimization
local CreateFrame = CreateFrame
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local string = string
local math = math
local UIParent = UIParent

-- Create Container Frame
local tracker = CreateFrame("Frame", "MacUIPlayerHealthTracker", UIParent)
tracker:SetSize(100, 30)
-- Register for moving and scaling
tracker.defaultPoint = {"CENTER", UIParent, "CENTER", 0, -60}
table.insert(addonTable.MovableFrames, tracker)

-- Create FontString
local healthText = tracker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
healthText:SetPoint("CENTER", tracker, "CENTER", 0, 0)
tracker.fontStrings = { healthText }

-- Update Function
local function UpdateHealth()
    local health = UnitHealth("player") or 0
    local maxHealth = UnitHealthMax("player") or 1
    
    -- Prevent division by zero
    if maxHealth <= 0 then maxHealth = 1 end
    
    -- Calculate percentage and round down to nearest whole number
    local percent = math.floor((health / maxHealth) * 100)
    
    -- Green font (|cFF00FF00)
    healthText:SetText(string.format("|cFF00FF00Health: %d%%|r", percent))
end

-- Event Registration
tracker:RegisterEvent("UNIT_HEALTH")
tracker:RegisterEvent("UNIT_MAXHEALTH")
tracker:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Event Handler
tracker:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        UpdateHealth()
    elseif (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") and unit == "player" then
        UpdateHealth()
    end
end)
