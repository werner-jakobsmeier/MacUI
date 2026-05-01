local addonName, addonTable = ...

local CreateFrame = CreateFrame
local UIParent = UIParent
local UnitAffectingCombat = UnitAffectingCombat
local C_UnitAuras = C_UnitAuras

local SPELL_SHIELD_BLOCK = 2565

-- Create a custom square frame
local squareFrame = CreateFrame("Frame", "MacUISquare", UIParent, "BackdropTemplate")
squareFrame:SetSize(40, 40)

-- Register for slash commands moving
squareFrame.defaultPoint = {"CENTER", UIParent, "CENTER", -200, 100}
table.insert(addonTable.MovableFrames, squareFrame)

-- Set up the default black background and 4-pixel white border
squareFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 4,
})
squareFrame:SetBackdropColor(0, 0, 0, 1) -- Black background (R, G, B, Alpha)
squareFrame:SetBackdropBorderColor(1, 1, 1, 1) -- White border (R, G, B, Alpha)

-- Logic to change color based on Combat and Shield Block status
local function UpdateSquareColor()
    -- Only check if we are playing a warrior, otherwise skip
    local _, playerClass = UnitClass("player")
    if playerClass ~= "WARRIOR" then return end

    local inCombat = UnitAffectingCombat("player")
    local hasShieldBlock = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_SHIELD_BLOCK) ~= nil

    if hasShieldBlock then
        -- Active mitigation is UP -> Solid Green (No pulsing)
        squareFrame:SetScript("OnUpdate", nil)
        squareFrame:SetBackdropColor(0, 1, 0, 1)
    elseif inCombat and not hasShieldBlock then
        -- In combat and missing active mitigation -> Start Pulsing Red
        squareFrame:SetScript("OnUpdate", addonTable.Animations.PulseRed)
    else
        -- Out of combat -> Stop pulsing and stay BLACK
        squareFrame:SetScript("OnUpdate", nil)
        squareFrame:SetBackdropColor(0, 0, 0, 1)
    end
end

-- Event Registration
squareFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Fired when entering combat
squareFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Fired when leaving combat
squareFrame:RegisterEvent("UNIT_AURA")             -- Fired when buffs change
squareFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Event Handler
squareFrame:SetScript("OnEvent", function(self, event, unit)
    -- We only care about aura updates for the player
    if event == "UNIT_AURA" and unit ~= "player" then return end
    
    UpdateSquareColor()
end)
