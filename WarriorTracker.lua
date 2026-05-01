local addonName, addonTable = ...

local UnitClass = UnitClass

-- Only load if playing a Protection Warrior (spec 3)
local _, playerClass = UnitClass("player")
if playerClass ~= "WARRIOR" then return end

-- Localize Globals for optimization (following our new guidelines)
local CreateFrame = CreateFrame
local UnitPower = UnitPower
local Enum = Enum
local C_UnitAuras = C_UnitAuras
-- C_Spell.GetSpellCharges replaces GetSpellCharges in 12.0.5+
local GetSpellCharges = C_Spell and C_Spell.GetSpellCharges or GetSpellCharges
local GetTime = GetTime
local string = string
local tostring = tostring
local UIParent = UIParent

-- Spell IDs for accurate tracking regardless of client language
local SPELL_IGNORE_PAIN = 190456
local SPELL_SHIELD_BLOCK = 2565

-- Create Container Frame
local tracker = CreateFrame("Frame", "MacUIWarriorTracker", UIParent)
tracker:SetSize(150, 100)
-- Register for moving and scaling
tracker.defaultPoint = {"CENTER", UIParent, "CENTER", 0, -100}
table.insert(addonTable.MovableFrames, tracker)

-- Helper to create FontStrings
local function CreateTrackerText(parent, yOffset)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOP", parent, "TOP", 0, yOffset)
    return fs
end

-- FontStrings
local rageText = CreateTrackerText(tracker, 0)
local ipText = CreateTrackerText(tracker, -25)
local sbChargesText = CreateTrackerText(tracker, -50)
local sbBuffText = CreateTrackerText(tracker, -75)
tracker.fontStrings = { rageText, ipText, sbChargesText, sbBuffText }

-- Formatting helper for large numbers (e.g., 120k for Ignore Pain)
local function FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fm", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fk", num / 1000)
    end
    return tostring(num)
end

-- Update Functions
local function UpdateRage()
    -- Rage is power type 4, but Enum.PowerType.Rage is safer
    local rage = UnitPower("player", Enum.PowerType.Rage) or 0
    -- Red font
    rageText:SetText(string.format("|cFFFF0000Rage: %d|r", rage))
end

local function UpdateIgnorePain()
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_IGNORE_PAIN)
    -- The absorb amount for Ignore Pain is typically in points[1]
    local absorb = (auraData and auraData.points and auraData.points[1]) or 0
    
    -- Orange font
    if absorb > 0 then
        ipText:SetText(string.format("|cFFFF8000Ignore Pain: %s|r", FormatNumber(absorb)))
    else
        ipText:SetText("|cFFFF8000Ignore Pain: 0|r")
    end
end

local function UpdateShieldBlockCharges()
    local charges = GetSpellCharges(SPELL_SHIELD_BLOCK) or 0
    -- Silver/Blue
    sbChargesText:SetText(string.format("|cFF88AAFFSB Charges: %d|r", charges))
end

local function UpdateShieldBlockBuff()
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_SHIELD_BLOCK)
    local durationStr = "0.0s"
    
    if auraData and auraData.expirationTime then
        local remaining = auraData.expirationTime - GetTime()
        if remaining > 0 then
            durationStr = string.format("%.1fs", remaining)
        end
    end
    
    -- Silver/Blue
    sbBuffText:SetText(string.format("|cFF88AAFFSB Buff: %s|r", durationStr))

    -- Performance: only run OnUpdate when the buff is actually active
    if auraData then
        if not tracker.onUpdateActive then
            tracker:SetScript("OnUpdate", function(self, elapsed)
                updateTimer = updateTimer + elapsed
                if updateTimer > 0.1 then
                    UpdateShieldBlockBuff()
                    updateTimer = 0
                end
            end)
            tracker.onUpdateActive = true
        end
    else
        if tracker.onUpdateActive then
            tracker:SetScript("OnUpdate", nil)
            tracker.onUpdateActive = false
        end
    end
end

-- Event Registration
tracker:RegisterEvent("UNIT_POWER_UPDATE")
tracker:RegisterEvent("UNIT_AURA")
tracker:RegisterEvent("SPELL_UPDATE_CHARGES")
tracker:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Event Handler
tracker:SetScript("OnEvent", function(self, event, unit, powerType)
    if event == "PLAYER_ENTERING_WORLD" then
        UpdateRage()
        UpdateIgnorePain()
        UpdateShieldBlockCharges()
        UpdateShieldBlockBuff()
    elseif event == "UNIT_POWER_UPDATE" and unit == "player" and powerType == "RAGE" then
        UpdateRage()
    elseif event == "UNIT_AURA" and unit == "player" then
        UpdateIgnorePain()
        -- Shield Block buff is also updated here when initially applied or removed
        UpdateShieldBlockBuff()
    elseif event == "SPELL_UPDATE_CHARGES" then
        UpdateShieldBlockCharges()
    end
end)
