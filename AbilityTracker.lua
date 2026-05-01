local addonName, addonTable = ...

-- Guideline #9: Gate class-specific modules at load time
local playerClass = addonTable.playerClass
if not (playerClass == "WARRIOR" or playerClass == "PALADIN") then
    return
end

-- Upvalues
local CreateFrame = CreateFrame
local UIParent = UIParent
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local UnitAffectingCombat = UnitAffectingCombat
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
local ipairs = ipairs
local pairs = pairs
local table = table
local PlaySound = PlaySound
local IsPlayerSpell = IsPlayerSpell

-- Invisible event-only frame
local eventFrame = CreateFrame("Frame", "MacUIAbilityTrackerEvents", UIParent)

-- Registry for active indicator frames
local activeIndicators = {}
-- Pool of hidden, reusable frames
local framePool = {}

local ICON_SIZE = 28
local DEFAULT_STAGGER = 36 -- px between staggered default positions

-- Helper: Create a single ability indicator with spell icon
local function CreateIndicatorRow()
    local row = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    row:SetSize(ICON_SIZE, ICON_SIZE)

    -- Movement Handling
    row:SetMovable(true)
    row:EnableMouse(false)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function(self) if addonTable.IsUnlocked then self:StartMoving() end end)
    row:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        if self.spellID then
            local saveKey = "Ability_" .. self.spellID
            if not MacUIDB.positions then MacUIDB.positions = {} end
            MacUIDB.positions[saveKey] = { point = p, relativePoint = rp, x = x, y = y }
        end
    end)

    -- Colored border frame
    local border = CreateFrame("Frame", nil, row, "BackdropTemplate")
    border:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
    border:SetPoint("CENTER", row, "CENTER", 0, 0)
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    -- Spell icon texture
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER", row, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.border = border
    row.icon = icon
    row.spellID = nil
    row.abilityType = nil
    row.isRed = false
    row.audioTimer = 0

    return row
end

local function SetIndicatorGreen(indicator)
    indicator.border:SetBackdropBorderColor(0, 1, 0, 1)
    indicator.icon:SetDesaturated(false)
    indicator.icon:SetAlpha(1)
    indicator.isRed = false
end

local function SetIndicatorRed(indicator)
    indicator.border:SetBackdropBorderColor(1, 0, 0, 1)
    indicator.icon:SetDesaturated(true)
    indicator.icon:SetAlpha(0.6)
    indicator.isRed = true
end

local function SetIndicatorGray(indicator)
    indicator.border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    indicator.icon:SetDesaturated(false)
    indicator.icon:SetAlpha(0.8)
    indicator.isRed = false
end

local function UpdateIndicator(indicator)
    if not indicator.spellID then return end

    local inCombat = UnitAffectingCombat("player")
    local auraData = GetPlayerAuraBySpellID(indicator.spellID)

    if indicator.abilityType == "buff" then
        if auraData then
            SetIndicatorGreen(indicator)
        elseif inCombat then
            SetIndicatorRed(indicator)
        else
            SetIndicatorGray(indicator)
        end
    elseif indicator.abilityType == "absorb" then
        local hasAbsorb = auraData and auraData.points and auraData.points[1] and auraData.points[1] > 0
        if hasAbsorb then
            SetIndicatorGreen(indicator)
        elseif inCombat then
            SetIndicatorRed(indicator)
        else
            SetIndicatorGray(indicator)
        end
    end
end

local function UpdateAllIndicators()
    for _, indicator in ipairs(activeIndicators) do
        UpdateIndicator(indicator)
        
        if indicator.isRed then
            if not indicator.audioPlayed then
                local soundID = MacUIDB and MacUIDB.audioAlerts and MacUIDB.audioAlerts[indicator.spellID]
                if soundID then
                    addonTable.PlaySoundSafe(soundID)
                    indicator.audioPlayed = true
                end
            end
        else
            indicator.audioPlayed = false
        end
    end
end

local function ApplyIndicatorPosition(indicator, index)
    local spellID = indicator.spellID
    if not spellID then return end

    local saveKey = "Ability_" .. spellID
    if MacUIDB and MacUIDB.positions and MacUIDB.positions[saveKey] then
        local pos = MacUIDB.positions[saveKey]
        indicator:ClearAllPoints()
        indicator:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        indicator:ClearAllPoints()
        indicator:SetPoint("CENTER", UIParent, "CENTER", 200, 50 - ((index - 1) * DEFAULT_STAGGER))
    end
end

function RebuildTrackerUI()
    for _, frame in ipairs(activeIndicators) do
        frame:Hide()
        table.insert(framePool, frame)
    end
    activeIndicators = {}

    if not (MacUIDB and MacUIDB.trackedAbilities) then return end

    local specIndex = addonTable.playerSpec
    local abilitiesToTrack = {}

    -- 1. Identify Spec Defaults
    local classDefaults = addonTable.DefaultAbilities and addonTable.DefaultAbilities[playerClass]
    local specDefaults = specIndex and classDefaults and classDefaults[specIndex]
    if specDefaults then
        for _, ability in ipairs(specDefaults) do
            if type(ability) == "table" and MacUIDB.trackedAbilities[ability.spellID] ~= false then
                if ability.isBaseline or IsPlayerSpell(ability.spellID) then
                    table.insert(abilitiesToTrack, ability)
                end
            end
        end
    end

    -- 2. Identify Custom Abilities
    if MacUIDB.customAbilities then
        local sortedCustom = {}
        for _, ability in pairs(MacUIDB.customAbilities) do
            if type(ability) == "table" and ability.spellID and MacUIDB.trackedAbilities[ability.spellID] == true then
                if ability.isBaseline or IsPlayerSpell(ability.spellID) then
                    table.insert(sortedCustom, ability)
                end
            end
        end
        table.sort(sortedCustom, function(a, b) return a.name and b.name and a.name < b.name end)
        for _, ability in ipairs(sortedCustom) do
            table.insert(abilitiesToTrack, ability)
        end
    end

    -- 3. Provision Frames
    for i, ability in ipairs(abilitiesToTrack) do
        local row = table.remove(framePool) or CreateIndicatorRow()
        
        row.spellID = ability.spellID
        row.abilityType = ability.type
        row.audioPlayed = false
        row.isRed = false
        
        local iconTexture = GetSpellTexture(ability.spellID)
        if iconTexture then row.icon:SetTexture(iconTexture) end
        
        ApplyIndicatorPosition(row, i)
        
        -- Registry (Check for duplicates)
        local found = false
        for _, f in ipairs(addonTable.MovableFrames) do
            if f == row then found = true break end
        end
        if not found then
            table.insert(addonTable.MovableFrames, row)
        end

        table.insert(activeIndicators, row)
        row:Show()
    end

    UpdateAllIndicators()
end
addonTable.RebuildTrackerUI = RebuildTrackerUI

table.insert(addonTable.OnSpecChanged, function()
    RebuildTrackerUI()
end)

eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not MacUIDB then MacUIDB = {} end
        if not MacUIDB.trackedAbilities then MacUIDB.trackedAbilities = {} end
        RebuildTrackerUI()
        self:UnregisterEvent("ADDON_LOADED")
    else
        UpdateAllIndicators()
    end
end)

