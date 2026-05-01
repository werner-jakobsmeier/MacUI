local addonName, addonTable = ...

local UnitClass = UnitClass

-- Only load if playing a Paladin
local _, playerClass = UnitClass("player")
if playerClass ~= "PALADIN" then return end

-- Localize Globals
local CreateFrame = CreateFrame
local UnitPower = UnitPower
local Enum = Enum
local C_UnitAuras = C_UnitAuras
local GetTime = GetTime
local string = string
local UIParent = UIParent
local table = table

-- Spell IDs
local SPELL_SOTR = 132403
local SPELL_CONSECRATION_BUFF = 188370 -- Buff gained while standing in Consecration

-- Create Container Frame
local tracker = CreateFrame("Frame", "MacUIPaladinTracker", UIParent)
tracker:SetSize(150, 100)
tracker.defaultPoint = {"CENTER", UIParent, "CENTER", 0, -100}
table.insert(addonTable.MovableFrames, tracker)
tracker:Hide() -- Hide by default until spec is confirmed

-- Helper to create FontStrings
local function CreateTrackerText(parent, yOffset)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOP", parent, "TOP", 0, yOffset)
    return fs
end

-- FontStrings
local holyPowerText = CreateTrackerText(tracker, 0)
local sotrBuffText = CreateTrackerText(tracker, -25)
local consecrationText = CreateTrackerText(tracker, -50)
tracker.fontStrings = { holyPowerText, sotrBuffText, consecrationText }

-- Update Functions
local function UpdateHolyPower()
    -- Holy Power is power type 9
    local hp = UnitPower("player", Enum.PowerType.HolyPower) or 0
    -- Yellow/Gold font
    holyPowerText:SetText(string.format("|cFFFFE680Holy Power: %d|r", hp))
end

local function UpdateSotRBuff()
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_SOTR)
    local durationStr = "0.0s"
    
    if auraData and auraData.expirationTime then
        local remaining = auraData.expirationTime - GetTime()
        if remaining > 0 then
            durationStr = string.format("%.1fs", remaining)
        end
    end
    
    -- Bright Yellow
    sotrBuffText:SetText(string.format("|cFFFFFF00SotR Buff: %s|r", durationStr))

    -- Performance: only run OnUpdate when the buff is actually active
    if auraData then
        if not tracker.onUpdateActive then
            tracker:SetScript("OnUpdate", function(self, elapsed)
                if not self.updateTimer then self.updateTimer = 0 end
                self.updateTimer = self.updateTimer + elapsed
                if self.updateTimer > 0.1 then -- Throttle to 10 times a second
                    UpdateSotRBuff()
                    self.updateTimer = 0
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

local function UpdateConsecration()
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_CONSECRATION_BUFF)
    if auraData then
        consecrationText:SetText("|cFFFFFF00Consecration: Active|r")
    else
        consecrationText:SetText("|cFF888888Consecration: Inactive|r")
    end
end

local function RebuildTracker()
    -- Only show these specific trackers if the player is Protection (spec 2)
    if addonTable.playerSpec == 2 then
        tracker:Show()
        UpdateHolyPower()
        UpdateSotRBuff()
        UpdateConsecration()
    else
        tracker:Hide()
        tracker:SetScript("OnUpdate", nil)
        tracker.onUpdateActive = false
    end
end

-- Hook into the spec change callback system
table.insert(addonTable.OnSpecChanged, function()
    RebuildTracker()
end)

-- Event Registration
tracker:RegisterEvent("UNIT_POWER_UPDATE")
tracker:RegisterEvent("UNIT_AURA")
tracker:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Event Handler
tracker:SetScript("OnEvent", function(self, event, unit, powerType)
    if event == "PLAYER_ENTERING_WORLD" then
        RebuildTracker()
    elseif event == "UNIT_POWER_UPDATE" and unit == "player" and powerType == "HOLY_POWER" then
        if addonTable.playerSpec == 2 then UpdateHolyPower() end
    elseif event == "UNIT_AURA" and unit == "player" then
        if addonTable.playerSpec == 2 then
            UpdateSotRBuff()
            UpdateConsecration()
        end
    end
end)
