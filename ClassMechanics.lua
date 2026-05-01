local addonName, addonTable = ...

local CreateFrame = CreateFrame
local C_UnitAuras = C_UnitAuras
local GetSpellCharges = C_Spell and C_Spell.GetSpellCharges or GetSpellCharges
local GetTime = GetTime
local string = string
local tostring = tostring
local UIParent = UIParent
local table = table
local pairs = pairs
local ipairs = ipairs

-- Helper for large numbers
local function FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fm", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fk", num / 1000)
    end
    return tostring(num)
end

local activeFrames = {}
local eventFrame = CreateFrame("Frame", "MacUIClassMechanicsEvents", UIParent)

local function ClearFrames()
    for _, f in ipairs(activeFrames) do
        f:Hide()
        f:SetParent(nil)
    end
    activeFrames = {}
    eventFrame:SetScript("OnUpdate", nil)
    eventFrame.onUpdateActive = false
end

local function RebuildMechanics()
    ClearFrames()
    
    local classData = addonTable.ClassMechanics and addonTable.ClassMechanics[addonTable.playerClass]
    if not classData then return end
    
    local mechanics = classData[addonTable.playerSpec]
    if not mechanics then return end
    
    for i, mech in ipairs(mechanics) do
        local frame = CreateFrame("Frame", "MacUIClassMechanic_" .. mech.id .. "_" .. i, UIParent)
        frame:SetSize(150, 25)
        local defaultPoint = mech.point or {0, -100 - (i*25)}
        frame.defaultPoint = {"CENTER", UIParent, "CENTER", unpack(defaultPoint)}
        
        -- Try to restore saved point/scale
        local frameName = frame:GetName()
        if MacUIDB and MacUIDB.positions and MacUIDB.positions[frameName] then
            local pos = MacUIDB.positions[frameName]
            frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
        else
            frame:SetPoint(unpack(frame.defaultPoint))
        end
        if MacUIDB and MacUIDB.scales and MacUIDB.scales[frameName] then
            frame:SetScale(MacUIDB.scales[frameName])
        end
        
        table.insert(addonTable.MovableFrames, frame)
        table.insert(activeFrames, frame)
        
        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        text:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.fontStrings = { text }
        frame.text = text
        frame.mech = mech
        frame:Show()
    end
    
    -- Force an initial update
    for _, frame in ipairs(activeFrames) do
        if frame.mech.type == "charges" then
            eventFrame:GetScript("OnEvent")(eventFrame, "SPELL_UPDATE_CHARGES")
        else
            eventFrame:GetScript("OnEvent")(eventFrame, "UNIT_AURA", "player")
        end
    end
end

local function UpdateAuras()
    local needsOnUpdate = false
    
    for _, frame in ipairs(activeFrames) do
        local mech = frame.mech
        local c = mech.color
        local hexColor = string.format("%02x%02x%02x", c[1]*255, c[2]*255, c[3]*255)
        local prefix = string.format("|cFF%s%s:|r ", hexColor, mech.label)
        
        if mech.type == "absorb" or mech.type == "buff" or mech.type == "active" then
            local auraData = C_UnitAuras.GetPlayerAuraBySpellID(mech.id)
            
            if mech.type == "absorb" then
                local absorb = (auraData and auraData.points and auraData.points[1]) or 0
                if absorb > 0 then
                    frame.text:SetText(prefix .. string.format("|cFF%s%s|r", hexColor, FormatNumber(absorb)))
                else
                    frame.text:SetText(prefix .. string.format("|cFF%s0|r", hexColor))
                end
            elseif mech.type == "active" then
                if auraData then
                    frame.text:SetText(prefix .. string.format("|cFF%sActive|r", hexColor))
                else
                    frame.text:SetText(string.format("|cFF888888%s: Inactive|r", mech.label))
                end
            elseif mech.type == "buff" then
                local durationStr = "0.0s"
                if auraData and auraData.expirationTime then
                    local remaining = auraData.expirationTime - GetTime()
                    if remaining > 0 then
                        durationStr = string.format("%.1fs", remaining)
                        needsOnUpdate = true
                    end
                end
                frame.text:SetText(prefix .. string.format("|cFF%s%s|r", hexColor, durationStr))
            end
        end
    end
    
    -- Handle OnUpdate for duration countdowns
    if needsOnUpdate then
        if not eventFrame.onUpdateActive then
            eventFrame:SetScript("OnUpdate", function(self, elapsed)
                if not self.updateTimer then self.updateTimer = 0 end
                self.updateTimer = self.updateTimer + elapsed
                if self.updateTimer > 0.1 then
                    UpdateAuras()
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

local function UpdateCharges()
    for _, frame in ipairs(activeFrames) do
        local mech = frame.mech
        if mech.type == "charges" then
            local c = mech.color
            local hexColor = string.format("%02x%02x%02x", c[1]*255, c[2]*255, c[3]*255)
            local chargesInfo = GetSpellCharges(mech.id)
            local charges = chargesInfo and chargesInfo.currentCharges or 0
            
            frame.text:SetText(string.format("|cFF%s%s: %d|r", hexColor, mech.label, charges))
        end
    end
end

eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        RebuildMechanics()
    elseif event == "UNIT_AURA" and unit == "player" then
        UpdateAuras()
    elseif event == "SPELL_UPDATE_CHARGES" then
        UpdateCharges()
    end
end)

table.insert(addonTable.OnSpecChanged, function()
    RebuildMechanics()
end)
