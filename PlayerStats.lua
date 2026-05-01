local addonName, addonTable = ...

local CreateFrame = CreateFrame
local UnitPower = UnitPower
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local Enum = Enum
local string = string
local tostring = tostring
local math = math
local UIParent = UIParent
local table = table
local ipairs = ipairs
local unpack = unpack

local classInfo = addonTable.ClassDisplayInfo and addonTable.ClassDisplayInfo[addonTable.playerClass]
if not classInfo then return end -- Should never happen, but safety first

-- Helper to create stat frames
local function CreateStatFrame(id, defaultX, defaultY)
    local frame = CreateFrame("Frame", "MacUIPlayerStat_" .. id, UIParent)
    frame:SetSize(150, 25)
    frame:SetFrameStrata("HIGH") -- Ensure it renders above the Blizzard Personal Resource Display
    frame.defaultPoint = {"CENTER", UIParent, "CENTER", defaultX, defaultY}
    table.insert(addonTable.MovableFrames, frame)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\ARIALN.TTF", 18, "OUTLINE")
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.fontStrings = { text }
    frame.text = text

    return frame
end

local healthFrame = CreateStatFrame("Health", 0, -60)
local resourceFrame, powerFrame
if classInfo.resource then
    resourceFrame = CreateStatFrame("Resource", 0, -100)
end
if classInfo.power then
    powerFrame = CreateStatFrame("Power", 0, -125)
end

-- PowerType Mappings for UnitPower
local function GetPowerTypeByName(name)
    if name == "Rage" then return Enum.PowerType.Rage
    elseif name == "Mana" then return Enum.PowerType.Mana
    elseif name == "Energy" then return Enum.PowerType.Energy
    elseif name == "Holy Power" then return Enum.PowerType.HolyPower
    elseif name == "Combo Points" then return Enum.PowerType.ComboPoints
    elseif name == "Runic Power" then return Enum.PowerType.RunicPower
    elseif name == "Focus" then return Enum.PowerType.Focus
    elseif name == "Arcane Charges" then return Enum.PowerType.ArcaneCharges
    elseif name == "Soul Shards" then return Enum.PowerType.SoulShards
    elseif name == "Chi" then return Enum.PowerType.Chi
    elseif name == "Fury" then return Enum.PowerType.Fury
    elseif name == "Essence" then return Enum.PowerType.Essence
    elseif name == "Energy/Mana" then return Enum.PowerType.Energy -- Monk simplified
    end
    return nil
end

local function UpdateHealth()
    if not healthFrame then return end
    
    local health = UnitHealth("player")
    if health then
        healthFrame.text:SetTextColor(0, 1, 0)
        healthFrame.text:SetText(health)
    end
end

local function UpdateResource()
    if not resourceFrame or not classInfo.resource then return end
    
    local val = resourceFrame.pType and UnitPower("player", resourceFrame.pType)
    if val then
        local c = classInfo.resource.color
        resourceFrame.text:SetTextColor(c[1], c[2], c[3])
        resourceFrame.text:SetText(val)
    end
end

local function UpdatePower()
    if not powerFrame or not classInfo.power then return end
    
    local val
    if classInfo.power.name == "Ignore Pain" then
        -- Use aura points to avoid "Secret Number" taint (UnitGetTotalAbsorbs is protected)
        local auraData = GetPlayerAuraBySpellID(190456)
        val = (auraData and auraData.points and auraData.points[1]) or 0
    else
        val = resourceFrame.pType and UnitPower("player", resourceFrame.pType)
    end
    
    if val then
        local c = classInfo.power.color
        powerFrame.text:SetTextColor(c[1], c[2], c[3])
        if classInfo.power.name == "Ignore Pain" then
            powerFrame.text:SetText(addonTable.FormatNumber(val))
        else
            powerFrame.text:SetText(val)
        end
    end
end

local function RebuildStats()
    if healthFrame then
        if MacUIDB and MacUIDB.displays and MacUIDB.displays.health == false then
            healthFrame:Hide()
        else
            healthFrame:Show()
            UpdateHealth()
        end
    end

    if resourceFrame then
        if MacUIDB and MacUIDB.displays and MacUIDB.displays.resource == false then
            resourceFrame:Hide()
        else
            resourceFrame:Show()
            UpdateResource()
        end
    end
    
    if powerFrame then
        -- Check if current spec uses this power
        local specValid = false
        if classInfo.power and classInfo.power.specs then
            for _, s in ipairs(classInfo.power.specs) do
                if s == addonTable.playerSpec then specValid = true break end
            end
        end
        
        if (not specValid) or (MacUIDB and MacUIDB.displays and MacUIDB.displays.power == false) then
            powerFrame:Hide()
        else
            powerFrame.pType = GetPowerTypeByName(classInfo.power.name)
            powerFrame:Show()
            UpdatePower()
        end
    end
    
    if resourceFrame then
        resourceFrame.pType = GetPowerTypeByName(classInfo.resource.name)
    end
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_MAXHEALTH")
eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
eventFrame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, unit, powerType)
    if event == "PLAYER_ENTERING_WORLD" then
        RebuildStats()
    elseif (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_AURA") and unit == "player" then
        UpdateHealth()
        UpdatePower() -- Absorbs/Auras map to Power for some classes
    elseif event == "UNIT_POWER_UPDATE" and unit == "player" then
        -- Ideally we'd map string powerType back, but simple enough to just update both if active
        UpdateResource()
        UpdatePower()
    end
end)

table.insert(addonTable.OnSpecChanged, function()
    RebuildStats()
end)

table.insert(addonTable.OnDisplayChanged, function(displayId, isEnabled)
    if displayId == "health" or displayId == "resource" or displayId == "power" then
        RebuildStats()
    end
end)
