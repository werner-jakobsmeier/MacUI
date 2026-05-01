local addonName, addonTable = ...

local CreateFrame = CreateFrame
local UIParent = UIParent
local SlashCmdList = SlashCmdList
local print = print
local tonumber = tonumber
local string = string

-- Slash Command Registration
-- NOTE: SLASH_ globals are required by the WoW API to register commands.
-- This is an intentional exception to the "no globals" rule.
SLASH_MACUI1 = "/macui"
local configFrame = CreateFrame("Frame")

-- Applies the saved font size to all registered font strings
local function ApplyFontSize(size)
    if not size or size <= 0 then return end
    if not MacUIDB then return end
    MacUIDB.fontSize = size
    
    for _, frame in ipairs(addonTable.MovableFrames or {}) do
        if frame.fontStrings then
            for _, fs in ipairs(frame.fontStrings) do
                local fontPath, _, fontFlags = fs:GetFont()
                fs:SetFont(fontPath or "Fonts\\FRIZQT__.TTF", size, fontFlags)
            end
        end
    end
end

-- Applies the saved position to a specific frame
local function ApplyFramePosition(frame)
    if not frame then return end
    local frameName = frame:GetName()
    
    if MacUIDB.positions and MacUIDB.positions[frameName] then
        local pos = MacUIDB.positions[frameName]
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        if frame.defaultPoint then
            frame:ClearAllPoints()
            frame:SetPoint(unpack(frame.defaultPoint))
        end
    end
end

local function UnlockFrames()
    print("|cFF33FF99MacUI|r: Frames UNLOCKED.")
    
    for _, frame in ipairs(addonTable.MovableFrames or {}) do
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        
        if not frame.dragTexture then
            frame.dragTexture = frame:CreateTexture(nil, "BACKGROUND")
            frame.dragTexture:SetAllPoints()
            frame.dragTexture:SetColorTexture(0, 1, 0, 0.4)
        end
        frame.dragTexture:Show()
    end
end

local function LockFrames()
    print("|cFF33FF99MacUI|r: Frames LOCKED and positions saved.")
    
    MacUIDB.positions = MacUIDB.positions or {}
    
    for _, frame in ipairs(addonTable.MovableFrames or {}) do
        frame:EnableMouse(false)
        frame:SetMovable(false)
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
        
        if frame.dragTexture then
            frame.dragTexture:Hide()
        end
        
        local point, _, relativePoint, x, y = frame:GetPoint()
        if point then
            MacUIDB.positions[frame:GetName()] = {
                point = point,
                relativePoint = relativePoint,
                x = x,
                y = y
            }
        end
    end
end

------------------------------------------------
-- GUI Options Panel — Brutalist Design
------------------------------------------------

-- Custom black panel with NO border (floating brutalist style)
local optionsPanel = CreateFrame("Frame", "MacUIOptionsPanel", UIParent, "BackdropTemplate")
optionsPanel:SetSize(260, 360)
optionsPanel:SetPoint("CENTER")
optionsPanel:Hide()
optionsPanel:SetMovable(true)
optionsPanel:EnableMouse(true)
optionsPanel:RegisterForDrag("LeftButton")
optionsPanel:SetScript("OnDragStart", optionsPanel.StartMoving)
optionsPanel:SetScript("OnDragStop", optionsPanel.StopMovingOrSizing)
optionsPanel:SetFrameStrata("DIALOG")

-- Solid black backdrop, no edge
optionsPanel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
})
optionsPanel:SetBackdropColor(0, 0, 0, 0.95)

-- Split-weight title: bold "MAC" + thin "UI"
local titleBold = optionsPanel:CreateFontString(nil, "OVERLAY")
titleBold:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
titleBold:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 16, -14)
titleBold:SetText("|cFFFFFFFFMAC|r")

local titleThin = optionsPanel:CreateFontString(nil, "OVERLAY")
titleThin:SetFont("Fonts\\FRIZQT__.TTF", 22)
titleThin:SetPoint("LEFT", titleBold, "RIGHT", 0, 0)
titleThin:SetText("|cFFAAAAAAUI|r")

-- Minimal × close button (top right)
local closeBtn = CreateFrame("Button", nil, optionsPanel)
closeBtn:SetSize(20, 20)
closeBtn:SetPoint("TOPRIGHT", optionsPanel, "TOPRIGHT", -10, -10)
local closeBtnText = closeBtn:CreateFontString(nil, "OVERLAY")
closeBtnText:SetFont("Fonts\\FRIZQT__.TTF", 18)
closeBtnText:SetPoint("CENTER")
closeBtnText:SetText("|cFFFFFFFF×|r")
closeBtn:SetScript("OnClick", function() optionsPanel:Hide() end)
closeBtn:SetScript("OnEnter", function() closeBtnText:SetText("|cFFFF4444×|r") end)
closeBtn:SetScript("OnLeave", function() closeBtnText:SetText("|cFFFFFFFF×|r") end)

-- Helper: Create a pill-shaped button (white fill, black text)
-- NOTE: Caller is responsible for positioning via SetPoint after creation.
local function CreatePillButton(parent, text)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(105, 32)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(1, 1, 1, 1) -- White fill
    btn:SetBackdropBorderColor(1, 1, 1, 1)

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    btnText:SetPoint("CENTER")
    btnText:SetTextColor(0, 0, 0, 1) -- Black text
    btnText:SetText(text)

    -- Hover: invert colors (black fill, white text)
    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
        btnText:SetTextColor(1, 1, 1, 1)
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(1, 1, 1, 1)
        btnText:SetTextColor(0, 0, 0, 1)
    end)

    return btn
end

-- Buttons — side by side
local btnUnlock = CreatePillButton(optionsPanel, "UNLOCK")
btnUnlock:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 20, -55)
btnUnlock:SetScript("OnClick", function() UnlockFrames() end)

local btnLock = CreatePillButton(optionsPanel, "LOCK")
btnLock:SetPoint("TOPRIGHT", optionsPanel, "TOPRIGHT", -20, -55)
btnLock:SetScript("OnClick", function() LockFrames() end)

-- Font Size section — large prominent number
local fontSizeLabel = optionsPanel:CreateFontString(nil, "OVERLAY")
fontSizeLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
fontSizeLabel:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 20, -110)
fontSizeLabel:SetText("|cFF888888FONT SIZE|r")

local fontSizeValue = optionsPanel:CreateFontString(nil, "OVERLAY")
fontSizeValue:SetFont("Fonts\\FRIZQT__.TTF", 36, "OUTLINE")
fontSizeValue:SetPoint("TOP", optionsPanel, "TOP", 0, -125)
fontSizeValue:SetText("|cFFFFFFFF14|r")

-- Custom slider (thin white line with white handle)
local slider = CreateFrame("Slider", "MacUIFontSlider", optionsPanel)
slider:SetSize(220, 16)
slider:SetPoint("TOP", optionsPanel, "TOP", 0, -175)
slider:SetMinMaxValues(8, 32)
slider:SetValueStep(1)
slider:SetObeyStepOnDrag(true)

-- Slider track (thin white line)
local sliderTrack = slider:CreateTexture(nil, "BACKGROUND")
sliderTrack:SetColorTexture(0.4, 0.4, 0.4, 1)
sliderTrack:SetHeight(2)
sliderTrack:SetPoint("LEFT", slider, "LEFT", 0, 0)
sliderTrack:SetPoint("RIGHT", slider, "RIGHT", 0, 0)

-- Slider thumb (white circle)
local thumbTex = slider:CreateTexture(nil, "OVERLAY")
thumbTex:SetColorTexture(1, 1, 1, 1)
thumbTex:SetSize(12, 12)
slider:SetThumbTexture(thumbTex)

-- Min/Max labels
local sliderMin = slider:CreateFontString(nil, "OVERLAY")
sliderMin:SetFont("Fonts\\FRIZQT__.TTF", 9)
sliderMin:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -4)
sliderMin:SetText("|cFF666666 8|r")

local sliderMax = slider:CreateFontString(nil, "OVERLAY")
sliderMax:SetFont("Fonts\\FRIZQT__.TTF", 9)
sliderMax:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -4)
sliderMax:SetText("|cFF66666632|r")

slider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5) -- Round to nearest integer
    fontSizeValue:SetText("|cFFFFFFFF" .. value .. "|r")
    ApplyFontSize(value)
end)

------------------------------------------------
-- Ability Selector Checkboxes
------------------------------------------------

-- Section label
local abilitiesLabel = optionsPanel:CreateFontString(nil, "OVERLAY")
abilitiesLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
abilitiesLabel:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 20, -235)
abilitiesLabel:SetText("|cFF888888ABILITIES|r")

-- Separator line
local separator = optionsPanel:CreateTexture(nil, "OVERLAY")
separator:SetColorTexture(0.3, 0.3, 0.3, 1)
separator:SetSize(220, 1)
separator:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 20, -248)

-- Helper: Create a brutalist checkbox row
-- Safe fallback for GetSpellTexture (12.0.5 API compatibility)
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture

local function CreateAbilityCheckbox(parent, ability, yOffset)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(220, 20)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)

    -- Checkbox square
    local checkbox = CreateFrame("Frame", nil, row, "BackdropTemplate")
    checkbox:SetSize(14, 14)
    checkbox:SetPoint("LEFT", row, "LEFT", 0, 0)
    checkbox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    -- Checkmark text (hidden by default)
    local checkmark = checkbox:CreateFontString(nil, "OVERLAY")
    checkmark:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    checkmark:SetPoint("CENTER", checkbox, "CENTER", 0, 0)
    checkmark:SetText("|cFF000000✓|r")
    checkmark:Hide()

    -- Small spell icon preview (16x16)
    local iconPreview = row:CreateTexture(nil, "ARTWORK")
    iconPreview:SetSize(16, 16)
    iconPreview:SetPoint("LEFT", checkbox, "RIGHT", 6, 0)
    iconPreview:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local iconTexture = GetSpellTexture(ability.spellID)
    if iconTexture then
        iconPreview:SetTexture(iconTexture)
    end

    -- Ability name (after the icon)
    local nameText = row:CreateFontString(nil, "OVERLAY")
    nameText:SetFont("Fonts\\FRIZQT__.TTF", 11)
    nameText:SetPoint("LEFT", iconPreview, "RIGHT", 6, 0)
    nameText:SetText("|cFFFFFFFF" .. ability.name .. "|r")

    -- State management
    local function UpdateVisual(isEnabled)
        if isEnabled then
            checkbox:SetBackdropColor(1, 1, 1, 1)
            checkbox:SetBackdropBorderColor(1, 1, 1, 1)
            checkmark:Show()
        else
            checkbox:SetBackdropColor(0.15, 0.15, 0.15, 1)
            checkbox:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
            checkmark:Hide()
        end
    end

    row:SetScript("OnClick", function()
        if not MacUIDB then return end
        if not MacUIDB.trackedAbilities then MacUIDB.trackedAbilities = {} end

        -- Toggle
        local isNowEnabled = not MacUIDB.trackedAbilities[ability.spellID]
        MacUIDB.trackedAbilities[ability.spellID] = isNowEnabled or nil
        UpdateVisual(isNowEnabled)

        -- Rebuild the tracker UI immediately
        if addonTable.RebuildTrackerUI then
            addonTable.RebuildTrackerUI()
        end
    end)

    row.UpdateVisual = UpdateVisual
    row.spellID = ability.spellID
    return row
end

-- Store checkbox references so we can update them on show
local abilityCheckboxes = {}

-- Build checkboxes for the player's class (filtered by current spec)
local function BuildAbilityCheckboxes()
    -- Clear existing checkboxes
    for _, row in ipairs(abilityCheckboxes) do
        row:Hide()
    end
    abilityCheckboxes = {}

    local classAbilities = addonTable.AbilityRegistry and addonTable.AbilityRegistry[addonTable.playerClass]
    if not classAbilities then return end

    local currentSpec = addonTable.playerSpec
    local visibleIndex = 0

    for _, ability in ipairs(classAbilities) do
        -- Only show abilities relevant to the current spec (or spec-agnostic)
        local specMatch = (ability.spec == nil) or (ability.spec == currentSpec)
        if specMatch then
            visibleIndex = visibleIndex + 1
            local yOffset = -255 - ((visibleIndex - 1) * 24)
            local row = CreateAbilityCheckbox(optionsPanel, ability, yOffset)
            table.insert(abilityCheckboxes, row)
        end
    end
end

-- Refresh checkbox visuals based on current MacUIDB state
local function RefreshAbilityCheckboxes()
    if not MacUIDB or not MacUIDB.trackedAbilities then return end
    for _, row in ipairs(abilityCheckboxes) do
        row.UpdateVisual(MacUIDB.trackedAbilities[row.spellID] == true)
    end
end

-- Register for spec changes to rebuild the checkbox list
table.insert(addonTable.OnSpecChanged, function()
    BuildAbilityCheckboxes()
    RefreshAbilityCheckboxes()
end)

------------------------------------------------
-- The Slash Command Handler
------------------------------------------------
SlashCmdList["MACUI"] = function()
    if optionsPanel:IsShown() then
        optionsPanel:Hide()
    else
        optionsPanel:Show()
        -- Ensure slider visually matches the current saved value
        slider:SetValue(MacUIDB and MacUIDB.fontSize or 14)
        -- Refresh checkboxes to reflect current DB state
        RefreshAbilityCheckboxes()
    end
end

-- Listen for our addon to finish loading so we can read the DB
configFrame:RegisterEvent("ADDON_LOADED")
configFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not MacUIDB then MacUIDB = {} end
        if not MacUIDB.positions then MacUIDB.positions = {} end
        if not MacUIDB.fontSize then MacUIDB.fontSize = 14 end
        if not MacUIDB.trackedAbilities then MacUIDB.trackedAbilities = {} end
        
        for _, frame in ipairs(addonTable.MovableFrames or {}) do
            ApplyFramePosition(frame)
        end
        
        ApplyFontSize(MacUIDB.fontSize)
        slider:SetValue(MacUIDB.fontSize)
        
        -- Build ability checkboxes now that the DB is ready
        BuildAbilityCheckboxes()
        RefreshAbilityCheckboxes()
        
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
