local addonName, addonTable = ...

local CreateFrame = CreateFrame
local UIParent = UIParent
local C_UnitAuras = C_UnitAuras
local UnitAffectingCombat = UnitAffectingCombat
local ipairs = ipairs
local table = table

-- Cache player class at load time
local playerClass = addonTable.playerClass

-- Container frame for all ability indicators
local trackerGroup = CreateFrame("Frame", "MacUIAbilityTracker", UIParent)
trackerGroup:SetSize(160, 10) -- Height will be dynamically adjusted
trackerGroup.defaultPoint = {"CENTER", UIParent, "CENTER", 200, 0}
table.insert(addonTable.MovableFrames, trackerGroup)

-- Store references to active and pooled indicator frames
local indicatorFrames = {}
local framePool = {}

-- Safe fallback for GetSpellTexture (12.0.5 API compatibility)
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture

local ICON_SIZE = 28
local PADDING = 4

-- Helper: Create a single ability indicator with spell icon
local function CreateIndicatorRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(ICON_SIZE, ICON_SIZE)

    -- Colored border frame (shows green/red/gray status)
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
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Trim default icon borders

    row.border = border
    row.icon = icon
    row.spellID = nil
    row.abilityType = nil

    return row
end

-- Set indicator to green (active/available)
local function SetIndicatorGreen(indicator)
    indicator.border:SetBackdropBorderColor(0, 1, 0, 1)
    indicator.icon:SetDesaturated(false)
    indicator.icon:SetAlpha(1)
end

-- Set indicator to red (missing/on cooldown)
local function SetIndicatorRed(indicator)
    indicator.border:SetBackdropBorderColor(1, 0, 0, 1)
    indicator.icon:SetDesaturated(true)
    indicator.icon:SetAlpha(0.6)
end

-- Set indicator to gray (out of combat / neutral)
local function SetIndicatorGray(indicator)
    indicator.border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    indicator.icon:SetDesaturated(false)
    indicator.icon:SetAlpha(0.8)
end

-- Update a single indicator based on current game state
local function UpdateIndicator(indicator)
    if not indicator.spellID then return end

    local inCombat = UnitAffectingCombat("player")
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(indicator.spellID)

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

-- Update ALL indicators
local function UpdateAllIndicators()
    for _, indicator in ipairs(indicatorFrames) do
        UpdateIndicator(indicator)
    end
end

-- Rebuild the tracker UI based on MacUIDB.trackedAbilities
local function RebuildTrackerUI()
    -- Return existing frames to the pool instead of leaking them
    for _, indicator in ipairs(indicatorFrames) do
        indicator:Hide()
        table.insert(framePool, indicator)
    end
    indicatorFrames = {}

    if not MacUIDB or not MacUIDB.trackedAbilities then return end

    -- Get the abilities for the player's class
    local classAbilities = addonTable.AbilityRegistry and addonTable.AbilityRegistry[playerClass]
    if not classAbilities then return end

    local currentSpec = addonTable.playerSpec

    local index = 0
    for _, ability in ipairs(classAbilities) do
        -- Only show abilities that match the player's current spec (or have no spec requirement)
        local specMatch = (ability.spec == nil) or (ability.spec == currentSpec)

        if MacUIDB.trackedAbilities[ability.spellID] and specMatch then
            index = index + 1

            -- Reuse a pooled frame or create a new one
            local row = table.remove(framePool) or CreateIndicatorRow(trackerGroup)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", trackerGroup, "TOPLEFT", 0, -((index - 1) * (ICON_SIZE + PADDING)))
            row.spellID = ability.spellID
            row.abilityType = ability.type

            -- Set the spell icon texture
            local iconTexture = GetSpellTexture(ability.spellID)
            if iconTexture then
                row.icon:SetTexture(iconTexture)
            end

            row:Show()
            table.insert(indicatorFrames, row)
        end
    end

    -- Adjust the container to fit all icon rows
    trackerGroup:SetSize(ICON_SIZE, index * (ICON_SIZE + PADDING))

    -- If no abilities are tracked, hide the entire group
    if index == 0 then
        trackerGroup:Hide()
    else
        trackerGroup:Show()
    end

    -- Force an initial update
    UpdateAllIndicators()
end

-- Make RebuildTrackerUI accessible to Config.lua
addonTable.RebuildTrackerUI = RebuildTrackerUI

-- Register for spec changes so we can rebuild when the player respeccs
table.insert(addonTable.OnSpecChanged, function()
    RebuildTrackerUI()
end)

-- Event Registration
trackerGroup:RegisterEvent("UNIT_AURA")
trackerGroup:RegisterEvent("SPELL_UPDATE_COOLDOWN")
trackerGroup:RegisterEvent("PLAYER_REGEN_DISABLED")
trackerGroup:RegisterEvent("PLAYER_REGEN_ENABLED")
trackerGroup:RegisterEvent("PLAYER_ENTERING_WORLD")
trackerGroup:RegisterEvent("ADDON_LOADED")

-- Event Handler
trackerGroup:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Initialize tracked abilities if needed
        if not MacUIDB then MacUIDB = {} end
        if not MacUIDB.trackedAbilities then MacUIDB.trackedAbilities = {} end

        RebuildTrackerUI()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "UNIT_AURA" and arg1 == "player" then
        UpdateAllIndicators()
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        UpdateAllIndicators()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        UpdateAllIndicators()
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateAllIndicators()
    end
end)
