local addonName, addonTable = ...

local CreateFrame = CreateFrame
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local GetSpellCharges = C_Spell and C_Spell.GetSpellCharges or GetSpellCharges
local GetTime = GetTime
local string = string
local UIParent = UIParent
local table = table
local ipairs = ipairs
local unpack = unpack

-- Helper for large numbers


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


local RebuildMechanics, UpdateAuras, UpdateCharges, UpdatePower

UpdateAuras = function()
    local needsOnUpdate = false
    
    for _, frame in ipairs(activeFrames) do
        local mech = frame.mech
        local c = mech.color
        local hexColor = string.format("%02x%02x%02x", c[1]*255, c[2]*255, c[3]*255)
        
        if mech.type == "absorb" or mech.type == "buff" or mech.type == "active" or mech.type == "totem" then
            local auraData = (mech.type ~= "totem") and GetPlayerAuraBySpellID(mech.id)
            
            if mech.type == "totem" then
                local haveTotem, name, startTime, duration = GetTotemInfo(1)
                local durationStr = "0.0"
                if haveTotem and duration > 0 then
                    local remaining = (startTime + duration) - GetTime()
                    if remaining > 0 then
                        durationStr = string.format("%.1f", remaining)
                        needsOnUpdate = true
                    end
                end
                frame.text:SetText(string.format("|cFF%s%s|r", hexColor, durationStr))
            elseif mech.type == "absorb" then
                local absorb = (auraData and auraData.points and auraData.points[1]) or 0
                if absorb > 0 then
                    frame.text:SetText(string.format("|cFF%s%s|r", hexColor, addonTable.FormatNumber(absorb)))
                else
                    frame.text:SetText(string.format("|cFF%s0|r", hexColor))
                end
            elseif mech.type == "active" then
                if auraData then
                    frame.text:SetText(string.format("|cFF%sActive|r", hexColor))
                else
                    frame.text:SetText("|cFF8888880|r")
                end
            elseif mech.type == "buff" then
                local durationStr = "0.0"
                if auraData and auraData.expirationTime then
                    local remaining = auraData.expirationTime - GetTime()
                    if remaining > 0 then
                        durationStr = string.format("%.1f", remaining)
                        needsOnUpdate = true
                    end
                end
                frame.text:SetText(string.format("|cFF%s%s|r", hexColor, durationStr))
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

UpdateCharges = function()
    for _, frame in ipairs(activeFrames) do
        local mech = frame.mech
        if mech.type == "charges" then
            local c = mech.color
            local hexColor = string.format("%02x%02x%02x", c[1]*255, c[2]*255, c[3]*255)
            local chargesInfo = GetSpellCharges(mech.id)
            local charges = chargesInfo and chargesInfo.currentCharges or 0
            
            frame.text:SetText(string.format("|cFF%s%d|r", hexColor, charges))
        end
    end
end

UpdatePower = function()
    for _, frame in ipairs(activeFrames) do
        local mech = frame.mech
        if mech.type == "power" then
            local c = mech.color
            local hexColor = string.format("%02x%02x%02x", c[1]*255, c[2]*255, c[3]*255)
            local power = UnitPower("player", mech.id)
            frame.text:SetText(string.format("|cFF%s%d|r", hexColor, power))
        end
    end
end

eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        RebuildMechanics()
    elseif event == "UNIT_AURA" and unit == "player" then
        UpdateAuras()
    elseif event == "UNIT_POWER_UPDATE" and unit == "player" then
        UpdatePower()
    elseif event == "SPELL_UPDATE_CHARGES" then
        UpdateCharges()
    end
end)

table.insert(addonTable.OnSpecChanged, function()
    RebuildMechanics()
end)

RebuildMechanics = function()
    ClearFrames()
    
    local classData = addonTable.ClassMechanics and addonTable.ClassMechanics[addonTable.playerClass]
    if not classData then return end
    
    local mechanics = classData[addonTable.playerSpec]
    if not mechanics then return end
    
    for i, mech in ipairs(mechanics) do
        -- Check Config: Only show if NOT disabled in the rack
        local isEnabled = true
        if MacUIDB and MacUIDB.trackedAbilities then
            isEnabled = MacUIDB.trackedAbilities[mech.id] ~= false
        end
        
        if isEnabled then
            local frame = CreateFrame("Frame", "MacUIClassMechanic_" .. mech.id .. "_" .. i, UIParent)
            frame:SetSize(150, 25)
            local defaultPoint = mech.point or {0, -100 - (i*25)}
            frame.defaultPoint = {"CENTER", UIParent, "CENTER", unpack(defaultPoint)}
            
            -- Movement Handling
            local frameName = frame:GetName()
            frame:SetMovable(true)
            frame:EnableMouse(false) -- Default to locked
            frame:RegisterForDrag("LeftButton")
            frame:SetScript("OnDragStart", function(self) if addonTable.IsUnlocked then self:StartMoving() end end)
            frame:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                local p, _, rp, x, y = self:GetPoint()
                if not MacUIDB.positions then MacUIDB.positions = {} end
                MacUIDB.positions[frameName] = { point = p, relativePoint = rp, x = x, y = y }
            end)

            -- Try to restore saved point/scale
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
            
            local text = frame:CreateFontString(nil, "OVERLAY")
            text:SetFont("Fonts\\ARIALN.TTF", 18, "OUTLINE")
            text:SetPoint("CENTER", frame, "CENTER", 0, 0)
            frame.fontStrings = { text }
            frame.text = text
            frame.mech = mech
            frame:Show()
        end
    end
    
    -- Force an initial update
    UpdateAuras()
    UpdateCharges()
    UpdatePower()
end

addonTable.RebuildMechanics = RebuildMechanics
