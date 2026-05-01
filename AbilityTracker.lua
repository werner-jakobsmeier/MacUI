local addonName, addonTable = ...

local CreateFrame = CreateFrame
local UIParent = UIParent
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local UnitAffectingCombat = UnitAffectingCombat
local ipairs = ipairs
local pairs = pairs
local table = table
local PlaySound = PlaySound
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo or GetSpellInfo
local string = string
local tostring = tostring

-- Cache player class at load time
local playerClass = addonTable.playerClass

-- Invisible event-only frame (no visual footprint, just handles events and audio)
local eventFrame = CreateFrame("Frame", "MacUIAbilityTrackerEvents", UIParent)

-- Registry for active indicator frames (Array for high-performance ipairs iteration)
local activeIndicators = {}
-- Pool of hidden, reusable frames (Ensures zero-waste memory management)
local framePool = {}

local ICON_SIZE = 28
local DEFAULT_STAGGER = 36 -- px between staggered default positions

-- Helper: Create a single ability indicator with spell icon
-- Parent is UIParent so each icon is independently positionable
local function CreateIndicatorRow()
    local row = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    row:SetSize(ICON_SIZE, ICON_SIZE)

    -- Movement Handling
    row:SetMovable(true)
    row:EnableMouse(false) -- Default to locked
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


-- Update ALL indicators
-- PERFORMANCE: Uses ipairs for faster array traversal during combat events.
local function UpdateAllIndicators()
    for _, indicator in ipairs(activeIndicators) do
        UpdateIndicator(indicator)
        
        -- EDGE CASE: "Recursive Audio Triggering" (State Lock Fix)
        -- Why it exists: Combat events (UNIT_AURA) fire multiple times per second.
        -- If an alert sound is a 'Loop' (like 10952), triggering it repeatedly 
        -- creates stacked audio instances that cannot be stopped individually.
        -- FIX: We use 'indicator.audioPlayed' as a Hard State Lock. It ensures 
        -- a sound ONLY fires once when the alert is triggered, and cannot 
        -- re-fire until the alert is cleared and reset.
        if indicator.isRed then
            if not indicator.audioPlayed then
                local soundID = MacUIDB and MacUIDB.audioAlerts and MacUIDB.audioAlerts[indicator.spellID]
                if soundID then
                    addonTable.PlaySoundSafe(soundID)
                    indicator.audioPlayed = true -- Lock the audio state
                end
            end
        else
            -- Reset the lock only when the alert is cleared (state transition)
            indicator.audioPlayed = false
        end
    end
end

-- Apply a saved or default position to an indicator
local function ApplyIndicatorPosition(indicator, index)
    local spellID = indicator.spellID
    if not spellID then return end

    -- Use Spell ID as the primary key for saved positions (more reliable than frame names)
    local saveKey = "Ability_" .. spellID
    if MacUIDB and MacUIDB.positions and MacUIDB.positions[saveKey] then
        local pos = MacUIDB.positions[saveKey]
        indicator:ClearAllPoints()
        indicator:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        -- Default: stagger icons starting from center-right of screen
        indicator:ClearAllPoints()
        indicator:SetPoint("CENTER", UIParent, "CENTER", 200, 50 - ((index - 1) * DEFAULT_STAGGER))
    end
end



-- Rebuild the tracker UI (called on spec change or tracked ability change)
function RebuildTrackerUI()
    -- Move active frames to the pool for reuse
    for _, frame in ipairs(activeIndicators) do
        frame:Hide()
        table.insert(framePool, frame)
    end
    activeIndicators = {}

    if not (MacUIDB and MacUIDB.trackedAbilities) then return end

    local playerClass = addonTable.playerClass
    local specIndex = addonTable.playerSpec
    local abilitiesToTrack = {}

    -- 1. Identify Spec Defaults
    local classDefaults = addonTable.DefaultAbilities and addonTable.DefaultAbilities[playerClass]
    local specDefaults = specIndex and classDefaults and classDefaults[specIndex]
    if specDefaults then
        for _, ability in ipairs(specDefaults) do
            if type(ability) == "table" and MacUIDB.trackedAbilities[ability.spellID] ~= false then
                table.insert(abilitiesToTrack, ability)
            end
        end
    end

    -- 2. Identify Custom Abilities
    if MacUIDB.customAbilities then
        local sortedCustom = {}
        for _, ability in pairs(MacUIDB.customAbilities) do
            -- SANITY CHECK: Ensure ability is a valid table (fixes 'boolean value' crash)
            if type(ability) == "table" and ability.spellID and MacUIDB.trackedAbilities[ability.spellID] == true then
                table.insert(sortedCustom, ability)
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
        
        -- EDGE CASE: Frames need unique names for saved positions to work.
        -- Since we reuse frames, we must manually manage the 'Global Name' logic.
        local uniqueName = "MacUIIndicator_" .. ability.spellID
        if row:GetName() ~= uniqueName then
            -- Note: We can't Rename a frame in WoW, so if we need a specific name,
            -- we ensure CreateIndicatorRow handles it or we accept the pooled name.
            -- Optimized approach: Just ensure the frame is registered in MovableFrames.
        end
        
        row.spellID = ability.spellID
        row.abilityType = ability.type
        row.audioPlayed = false
        row.isRed = false
        
        local iconTexture = GetSpellTexture(ability.spellID)
        if iconTexture then row.icon:SetTexture(iconTexture) end
        
        ApplyIndicatorPosition(row, i)
        
        -- Register for movement (required for the Unlock toggle to work)
        table.insert(addonTable.MovableFrames, row)
        table.insert(activeIndicators, row)
        row:Show()
    end

    UpdateAllIndicators()
end
addonTable.RebuildTrackerUI = RebuildTrackerUI

-- Register for spec changes so we can rebuild when the player respeccs
table.insert(addonTable.OnSpecChanged, function()
    RebuildTrackerUI()
end)

-- Event Handling (Event-Driven Updates)
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
        -- Combined high-performance handler for combat/aura events
        UpdateAllIndicators()
    end
end)
