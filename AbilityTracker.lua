local addonName, addonTable = ...

local CreateFrame = CreateFrame
local UIParent = UIParent
local C_UnitAuras = C_UnitAuras
local UnitAffectingCombat = UnitAffectingCombat
local ipairs = ipairs
local pairs = pairs
local table = table
local PlaySound = PlaySound
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo or GetSpellInfo

-- Cache player class at load time
local playerClass = addonTable.playerClass

-- Invisible event-only frame (no visual footprint, just handles events and audio)
local eventFrame = CreateFrame("Frame", "MacUIAbilityTrackerEvents", UIParent)

-- Store references to active indicator frames (keyed by spellID for fast lookup)
local indicatorFrames = {}
-- Pool of hidden, reusable frames
local framePool = {}

local ICON_SIZE = 28
local DEFAULT_STAGGER = 36 -- px between staggered default positions

-- Helper: Create a single ability indicator with spell icon
-- Parent is UIParent so each icon is independently positionable
local function CreateIndicatorRow()
    local row = CreateFrame("Frame", nil, UIParent)
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
    row.isRed = false
    row.audioTimer = 0

    return row
end

-- Set indicator to green (active/available)
local function SetIndicatorGreen(indicator)
    indicator.border:SetBackdropBorderColor(0, 1, 0, 1)
    indicator.icon:SetDesaturated(false)
    indicator.icon:SetAlpha(1)
    indicator.isRed = false
end

-- Set indicator to red (missing/on cooldown)
local function SetIndicatorRed(indicator)
    indicator.border:SetBackdropBorderColor(1, 0, 0, 1)
    indicator.icon:SetDesaturated(true)
    indicator.icon:SetAlpha(0.6)
    if not indicator.isRed then
        indicator.audioTimer = 3 -- Force immediate play on transition
    end
    indicator.isRed = true
end

-- Set indicator to gray (out of combat / neutral)
local function SetIndicatorGray(indicator)
    indicator.border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    indicator.icon:SetDesaturated(false)
    indicator.icon:SetAlpha(0.8)
    indicator.isRed = false
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
    local needsAudioUpdate = false

    for _, indicator in pairs(indicatorFrames) do
        UpdateIndicator(indicator)
        if indicator.isRed and MacUIDB and MacUIDB.audioAlerts and MacUIDB.audioAlerts[indicator.spellID] then
            needsAudioUpdate = true
        end
    end

    -- Dynamically enable/disable OnUpdate throttle for audio to save CPU
    if needsAudioUpdate then
        if not eventFrame.onUpdateActive then
            eventFrame:SetScript("OnUpdate", function(self, elapsed)
                for _, ind in pairs(indicatorFrames) do
                    if ind.isRed and MacUIDB.audioAlerts and MacUIDB.audioAlerts[ind.spellID] then
                        ind.audioTimer = (ind.audioTimer or 0) + elapsed
                        if ind.audioTimer >= 3.0 then
                            PlaySound(MacUIDB.audioAlerts[ind.spellID])
                            ind.audioTimer = 0
                        end
                    end
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

-- Apply a saved or default position to an indicator
local function ApplyIndicatorPosition(indicator, index)
    local frameName = indicator:GetName()
    if not frameName then return end

    if MacUIDB and MacUIDB.positions and MacUIDB.positions[frameName] then
        local pos = MacUIDB.positions[frameName]
        indicator:ClearAllPoints()
        indicator:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        -- Default: stagger icons starting from center-right of screen
        indicator:ClearAllPoints()
        indicator:SetPoint("CENTER", UIParent, "CENTER", 200, 50 - ((index - 1) * DEFAULT_STAGGER))
    end
end

-- Rebuild the tracker UI based on MacUIDB.trackedAbilities
local function RebuildTrackerUI()
    -- Return existing frames to the pool instead of leaking them
    for spellID, indicator in pairs(indicatorFrames) do
        indicator:Hide()
        for i, mf in ipairs(addonTable.MovableFrames) do
            if mf == indicator then
                table.remove(addonTable.MovableFrames, i)
                break
            end
        end
        table.insert(framePool, indicator)
    end
    indicatorFrames = {}

    if not MacUIDB or not MacUIDB.trackedAbilities then return end

    local abilitiesToTrack = {}
    
    -- 1. Gather Class Defaults
    local classDefaults = addonTable.DefaultAbilities and addonTable.DefaultAbilities[addonTable.playerClass]
    local specDefaults = classDefaults and classDefaults[addonTable.playerSpec]
    if specDefaults then
        for _, ability in ipairs(specDefaults) do
            -- Defaults are tracked unless explicitly disabled
            if MacUIDB.trackedAbilities[ability.spellID] ~= false then
                table.insert(abilitiesToTrack, { spellID = ability.spellID, type = ability.type })
            end
        end
    end
    


    local index = 0
    for _, ability in ipairs(abilitiesToTrack) do
        local spellID = ability.spellID
        index = index + 1

        -- Reuse a pooled frame or create a new one
        local row = table.remove(framePool) or CreateIndicatorRow()
        local frameName = "MacUIIndicator_" .. spellID
        
        -- Since SetName is not possible, we recreate if name mismatch
        if row:GetName() ~= frameName then
            row:Hide()
            row = CreateFrame("Frame", frameName, UIParent)
            row:SetSize(ICON_SIZE, ICON_SIZE)
            local border = CreateFrame("Frame", nil, row, "BackdropTemplate")
            border:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
            border:SetPoint("CENTER", row, "CENTER", 0, 0)
            border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
            border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(ICON_SIZE, ICON_SIZE)
            icon:SetPoint("CENTER", row, "CENTER", 0, 0)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.border = border
            row.icon = icon
            row.isRed = false
            row.audioTimer = 0
        end

        row.spellID = spellID
        row.abilityType = ability.type

        local iconTexture = GetSpellTexture(spellID)
        if not iconTexture then
            local spellInfo = GetSpellInfo(spellID)
            iconTexture = spellInfo and spellInfo.iconID
        end
        if iconTexture then row.icon:SetTexture(iconTexture) end

        ApplyIndicatorPosition(row, index)
        table.insert(addonTable.MovableFrames, row)
        row:Show()
        indicatorFrames[spellID] = row
    end

    UpdateAllIndicators()
end

-- Make RebuildTrackerUI accessible to Config.lua
addonTable.RebuildTrackerUI = RebuildTrackerUI

-- Register for spec changes so we can rebuild when the player respeccs
table.insert(addonTable.OnSpecChanged, function()
    RebuildTrackerUI()
end)

-- Event Registration
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
-- NOTE (Guideline #8 exception): This module uses its own ADDON_LOADED handler
-- because it needs MacUIDB.trackedAbilities to exist before calling RebuildTrackerUI().
-- MacUI.lua initializes the core DB, but this module must independently verify its own
-- subset of keys before building UI elements.
eventFrame:RegisterEvent("ADDON_LOADED")

-- Event Handler
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
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
