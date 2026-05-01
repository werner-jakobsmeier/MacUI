local addonName, addonTable = ...

local UnitClass = UnitClass

-- Only load if playing a Warrior
local _, playerClass = UnitClass("player")
if playerClass ~= "WARRIOR" then return end

-- Localize Globals
local CreateFrame = CreateFrame
local UnitPower = UnitPower
local Enum = Enum
local C_UnitAuras = C_UnitAuras
local GetSpellCharges = C_Spell and C_Spell.GetSpellCharges or GetSpellCharges
local GetTime = GetTime
local string = string
local tostring = tostring
local UIParent = UIParent
local table = table

-- Spell IDs
local SPELL_IGNORE_PAIN = 190456
local SPELL_SHIELD_BLOCK = 2565

-- Formatting helper for large numbers (e.g., 120k for Ignore Pain)
local function FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fm", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fk", num / 1000)
    end
    return tostring(num)
end

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
-- Create 4 independent frames
------------------------------------------------
local rageFrame = CreateTextFrame("MacUIWarriorRage", 0, -100)
local ipFrame = CreateTextFrame("MacUIWarriorIgnorePain", 0, -125)
local sbChargesFrame = CreateTextFrame("MacUIWarriorSBCharges", 0, -150)
local sbBuffFrame = CreateTextFrame("MacUIWarriorSBBuff", 0, -175)

-- Invisible event-only frame (handles events + SB Buff OnUpdate timer)
local eventFrame = CreateFrame("Frame", "MacUIWarriorTrackerEvents", UIParent)

------------------------------------------------
-- Update Functions
------------------------------------------------
local function UpdateRage()
    local rage = UnitPower("player", Enum.PowerType.Rage) or 0
    rageFrame.text:SetText(string.format("|cFFFF0000Rage: %d|r", rage))
end

local function UpdateIgnorePain()
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_IGNORE_PAIN)
    local absorb = (auraData and auraData.points and auraData.points[1]) or 0
    
    if absorb > 0 then
        ipFrame.text:SetText(string.format("|cFFFF8000Ignore Pain: %s|r", FormatNumber(absorb)))
    else
        ipFrame.text:SetText("|cFFFF8000Ignore Pain: 0|r")
    end
end

local function UpdateShieldBlockCharges()
    local chargesInfo = GetSpellCharges(SPELL_SHIELD_BLOCK)
    local charges = chargesInfo and chargesInfo.currentCharges or 0
    sbChargesFrame.text:SetText(string.format("|cFF88AAFFSB Charges: %d|r", charges))
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
    
    sbBuffFrame.text:SetText(string.format("|cFF88AAFFSB Buff: %s|r", durationStr))

    -- Performance: only run OnUpdate when the buff is actually active
    if auraData then
        if not eventFrame.onUpdateActive then
            eventFrame:SetScript("OnUpdate", function(self, elapsed)
                if not self.updateTimer then self.updateTimer = 0 end
                self.updateTimer = self.updateTimer + elapsed
                if self.updateTimer > 0.1 then
                    UpdateShieldBlockBuff()
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

------------------------------------------------
-- Spec-aware rebuild: show only for Protection (spec 3)
------------------------------------------------
local allFrames = { rageFrame, ipFrame, sbChargesFrame, sbBuffFrame }

local function RebuildTracker()
    if addonTable.playerSpec == 3 then
        for _, f in ipairs(allFrames) do f:Show() end
        UpdateRage()
        UpdateIgnorePain()
        UpdateShieldBlockCharges()
        UpdateShieldBlockBuff()
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
eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, unit, powerType)
    if event == "PLAYER_ENTERING_WORLD" then
        RebuildTracker()
    elseif event == "UNIT_POWER_UPDATE" and unit == "player" and powerType == "RAGE" then
        if addonTable.playerSpec == 3 then UpdateRage() end
    elseif event == "UNIT_AURA" and unit == "player" then
        if addonTable.playerSpec == 3 then
            UpdateIgnorePain()
            UpdateShieldBlockBuff()
        end
    elseif event == "SPELL_UPDATE_CHARGES" then
        if addonTable.playerSpec == 3 then UpdateShieldBlockCharges() end
    end
end)
