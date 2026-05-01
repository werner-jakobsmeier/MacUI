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
local ipairs = ipairs

-- Spell IDs
local SPELL_SOTR = 132403
local SPELL_CONSECRATION_BUFF = 188370

------------------------------------------------
-- Helper: Create a named, movable text frame
------------------------------------------------
local function CreateTextFrame(frameName, defaultX, defaultY)
    local frame = CreateFrame("Frame", frameName, UIParent)
    frame:SetSize(150, 25)
    frame.defaultPoint = {"CENTER", UIParent, "CENTER", defaultX, defaultY}
    table.insert(addonTable.MovableFrames, frame)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.fontStrings = { text }
    frame.text = text

    return frame
end

------------------------------------------------
-- Create 3 independent frames
------------------------------------------------
local holyPowerFrame = CreateTextFrame("MacUIPaladinHolyPower", 0, -100)
local sotrFrame = CreateTextFrame("MacUIPaladinSotR", 0, -125)
local consecFrame = CreateTextFrame("MacUIPaladinConsecration", 0, -150)

-- Invisible event-only frame (handles events + SotR OnUpdate timer)
local eventFrame = CreateFrame("Frame", "MacUIPaladinTrackerEvents", UIParent)

------------------------------------------------
-- Update Functions
------------------------------------------------
local function UpdateHolyPower()
    local hp = UnitPower("player", Enum.PowerType.HolyPower) or 0
    holyPowerFrame.text:SetText(string.format("|cFFFFE680Holy Power: %d|r", hp))
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
    
    sotrFrame.text:SetText(string.format("|cFFFFFF00SotR Buff: %s|r", durationStr))

    -- Performance: only run OnUpdate when the buff is actually active
    if auraData then
        if not eventFrame.onUpdateActive then
            eventFrame:SetScript("OnUpdate", function(self, elapsed)
                if not self.updateTimer then self.updateTimer = 0 end
                self.updateTimer = self.updateTimer + elapsed
                if self.updateTimer > 0.1 then
                    UpdateSotRBuff()
                    self.updateTimer = 0
                end
            end)
            eventFrame.onUpdateActive = true
        end
    else
        if eventFrame.onUpdateActive then
            eventFrame:SetScript("OnUpdate", nil)
            eventFrame.onUpdateActive = false
        end
    end
end

local function UpdateConsecration()
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_CONSECRATION_BUFF)
    if auraData then
        consecFrame.text:SetText("|cFFFFFF00Consecration: Active|r")
    else
        consecFrame.text:SetText("|cFF888888Consecration: Inactive|r")
    end
end

------------------------------------------------
-- Spec-aware rebuild: show only for Protection (spec 2)
------------------------------------------------
local allFrames = { holyPowerFrame, sotrFrame, consecFrame }

local function RebuildTracker()
    if addonTable.playerSpec == 2 then
        for _, f in ipairs(allFrames) do f:Show() end
        UpdateHolyPower()
        UpdateSotRBuff()
        UpdateConsecration()
    else
        for _, f in ipairs(allFrames) do f:Hide() end
        eventFrame:SetScript("OnUpdate", nil)
        eventFrame.onUpdateActive = false
    end
end

-- Hook into the spec change callback system
table.insert(addonTable.OnSpecChanged, function()
    RebuildTracker()
end)

------------------------------------------------
-- Event Registration & Handler
------------------------------------------------
eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, unit, powerType)
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
