local addonName, addonTable = ...

local CreateFrame = CreateFrame
local UnitPower = UnitPower
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local Enum = Enum
local string = string
local math = math
local UIParent = UIParent
local table = table
local ipairs = ipairs

local classInfo = addonTable.ClassDisplayInfo and addonTable.ClassDisplayInfo[addonTable.playerClass]
if not classInfo then return end -- Should never happen, but safety first

-- Helper to create stat frames
local function CreateStatFrame(id, defaultX, defaultY)
    local frame = CreateFrame("Frame", "MacUIPlayerStat_" .. id, UIParent)
    frame:SetSize(150, 25)
    frame.defaultPoint = {"CENTER", UIParent, "CENTER", defaultX, defaultY}
    table.insert(addonTable.MovableFrames, frame)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
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
    
    local health = UnitHealth("player") or 0
    local maxHealth = UnitHealthMax("player") or 1
    if maxHealth <= 0 then maxHealth = 1 end
    
    local percent = math.floor((health / maxHealth) * 100)
    healthFrame.text:SetText(string.format("|cFF00FF00%d%%|r", percent))
end

local function UpdateResource()
    if not resourceFrame or not classInfo.resource then return end
    
    local pType = GetPowerTypeByName(classInfo.resource.name)
    local val = pType and UnitPower("player", pType) or 0
    local c = classInfo.resource.color
    
    -- Format number
    local hexColor = string.format("%02x%02x%02x", c[1]*255, c[2]*255, c[3]*255)
    resourceFrame.text:SetText(string.format("|cFF%s%d|r", hexColor, val))
end

local function UpdatePower()
    if not powerFrame or not classInfo.power then return end
    
    local pType = GetPowerTypeByName(classInfo.power.name)
    local val = pType and UnitPower("player", pType) or 0
    local c = classInfo.power.color
    
    local hexColor = string.format("%02x%02x%02x", c[1]*255, c[2]*255, c[3]*255)
    powerFrame.text:SetText(string.format("|cFF%s%d|r", hexColor, val))
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
            powerFrame:Show()
            UpdatePower()
        end
    end
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("UNIT_MAXHEALTH")
eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, unit, powerType)
    if event == "PLAYER_ENTERING_WORLD" then
        RebuildStats()
    elseif (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") and unit == "player" then
        UpdateHealth()
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
