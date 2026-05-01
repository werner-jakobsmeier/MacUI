local addonName, addonTable = ...

local CreateFrame = CreateFrame
local UIParent = UIParent
local InCombatLockdown = InCombatLockdown
local math = math
local tonumber = tonumber
local pairs = pairs
local ipairs = ipairs
local table = table
local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo or GetSpellInfo
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
local PlaySound = PlaySound
local print = print
local string = string

-- Slash Command Registration
-- NOTE: SLASH_ globals are required by the WoW API to register commands.
-- This is an intentional exception to the "no globals" rule.
SLASH_MACUI1 = "/macui"
local configFrame = CreateFrame("Frame")

-- Applies the saved font size to all registered font strings

-- Applies the saved position and scale to a specific frame
local function ApplyFrameSettings(frame)
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
    
    if MacUIDB.scales and MacUIDB.scales[frameName] then
        frame:SetScale(MacUIDB.scales[frameName])
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
        
        if not frame.resizeControls then
            local rc = CreateFrame("Frame", nil, frame, "BackdropTemplate")
            rc:SetSize(40, 20)
            rc:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 20, -10)
            rc:SetFrameStrata("TOOLTIP")
            
            local btnMinus = CreateFrame("Button", nil, rc, "BackdropTemplate")
            btnMinus:SetSize(20, 20)
            btnMinus:SetPoint("LEFT", rc, "LEFT")
            btnMinus:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            btnMinus:SetBackdropColor(0.15, 0.15, 0.15, 1)
            btnMinus:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            local minusText = btnMinus:CreateFontString(nil, "OVERLAY")
            minusText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
            minusText:SetPoint("CENTER", 0, 1)
            minusText:SetText("-")
            
            local btnPlus = CreateFrame("Button", nil, rc, "BackdropTemplate")
            btnPlus:SetSize(20, 20)
            btnPlus:SetPoint("RIGHT", rc, "RIGHT")
            btnPlus:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            btnPlus:SetBackdropColor(0.15, 0.15, 0.15, 1)
            btnPlus:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            local plusText = btnPlus:CreateFontString(nil, "OVERLAY")
            plusText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
            plusText:SetPoint("CENTER", 0, 1)
            plusText:SetText("+")
            
            local function ChangeScale(delta)
                local currentScale = frame:GetScale() or 1.0
                local newScale = currentScale + delta
                if newScale < 0.5 then newScale = 0.5 end
                if newScale > 3.0 then newScale = 3.0 end
                frame:SetScale(newScale)
            end
            
            btnMinus:SetScript("OnClick", function() ChangeScale(-0.1) end)
            btnPlus:SetScript("OnClick", function() ChangeScale(0.1) end)
            
            frame.resizeControls = rc
        end
        frame.resizeControls:Show()
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
        if frame.resizeControls then
            frame.resizeControls:Hide()
        end
        
        MacUIDB.scales = MacUIDB.scales or {}
        MacUIDB.scales[frame:GetName()] = frame:GetScale()
        
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

-- Expose options panel to addonTable AFTER creation (Issue #1 fix)
addonTable.optionsPanel = optionsPanel

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

-- Expose Lock/Unlock to addonTable for MinimapButton (Issue #7 fix)
addonTable.UnlockFrames = UnlockFrames
addonTable.LockFrames = LockFrames
addonTable.IsUnlocked = false

local function ToggleLock()
    if addonTable.IsUnlocked then
        LockFrames()
        addonTable.IsUnlocked = false
    else
        UnlockFrames()
        addonTable.IsUnlocked = true
    end
end
addonTable.ToggleLock = ToggleLock

-- Buttons — side by side
local btnUnlock = CreatePillButton(optionsPanel, "UNLOCK")
btnUnlock:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 20, -55)
btnUnlock:SetScript("OnClick", function()
    UnlockFrames()
    addonTable.IsUnlocked = true
end)

local btnLock = CreatePillButton(optionsPanel, "LOCK")
btnLock:SetPoint("TOPRIGHT", optionsPanel, "TOPRIGHT", -20, -55)
btnLock:SetScript("OnClick", function()
    LockFrames()
    addonTable.IsUnlocked = false
end)

------------------------------------------------
-- Player Stats (Grid Tiles)
------------------------------------------------

local statsLabel = optionsPanel:CreateFontString(nil, "OVERLAY")
statsLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
statsLabel:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 20, -100)
statsLabel:SetText("|cFF888888PLAYER STATS|r")

local statsSeparator = optionsPanel:CreateTexture(nil, "OVERLAY")
statsSeparator:SetColorTexture(0.3, 0.3, 0.3, 1)
statsSeparator:SetSize(240, 1)
statsSeparator:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 20, -113)

local function CreateStatTile(parent, id, xOffset, label, typeLabel, defaultColor)
    local tile = CreateFrame("Button", nil, parent, "BackdropTemplate")
    tile:SetSize(74, 50)
    tile:SetPoint("TOPLEFT", parent, "TOPLEFT", 20 + xOffset, -120)
    tile:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    
    local nameText = tile:CreateFontString(nil, "OVERLAY")
    nameText:SetFont("Fonts\\FRIZQT__.TTF", 9)
    nameText:SetPoint("TOP", tile, "TOP", 0, -12)
    nameText:SetText(label)
    
    local typeText = tile:CreateFontString(nil, "OVERLAY")
    typeText:SetFont("Fonts\\FRIZQT__.TTF", 8)
    typeText:SetPoint("BOTTOM", tile, "BOTTOM", 0, 12)
    typeText:SetText(typeLabel)
    
    tile.id = id
    tile.color = defaultColor
    
    local function UpdateVisual(isEnabled)
        if isEnabled then
            tile:SetBackdropColor(0.06, 0.06, 0.06, 1)
            tile:SetBackdropBorderColor(defaultColor[1], defaultColor[2], defaultColor[3], 1)
            nameText:SetTextColor(defaultColor[1], defaultColor[2], defaultColor[3])
            typeText:SetTextColor(0.4, 0.4, 0.4)
        else
            tile:SetBackdropColor(0.04, 0.04, 0.04, 1)
            tile:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
            nameText:SetTextColor(0.4, 0.4, 0.4)
            typeText:SetTextColor(0.3, 0.3, 0.3)
        end
    end
    
    tile:SetScript("OnClick", function(self)
        if not MacUIDB.displays then MacUIDB.displays = { health = true, resource = true, power = true } end
        MacUIDB.displays[id] = not MacUIDB.displays[id]
        UpdateVisual(MacUIDB.displays[id])
        
        -- Notify modules
        for _, cb in ipairs(addonTable.OnDisplayChanged) do
            cb(id, MacUIDB.displays[id])
        end
    end)
    
    tile.UpdateVisual = UpdateVisual
    return tile
end

-- Create the 3 tiles
local healthTile = CreateStatTile(optionsPanel, "health", 0, "HEALTH", "HP %", {0, 1, 0})
local resourceTile, powerTile

local classInfo = addonTable.ClassDisplayInfo and addonTable.ClassDisplayInfo[addonTable.playerClass]
if classInfo and classInfo.resource then
    resourceTile = CreateStatTile(optionsPanel, "resource", 82, string.upper(classInfo.resource.name), "Resource", classInfo.resource.color)
end

if classInfo and classInfo.power then
    powerTile = CreateStatTile(optionsPanel, "power", 164, string.upper(classInfo.power.name), "Power", classInfo.power.color)
else
    -- Dimmed N/A tile
    local naTile = CreateFrame("Frame", nil, optionsPanel, "BackdropTemplate")
    naTile:SetSize(76, 50)
    naTile:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 184, -120)
    naTile:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    naTile:SetBackdropColor(0.04, 0.04, 0.04, 1)
    naTile:SetBackdropBorderColor(0.13, 0.13, 0.13, 1)
    
    local nameText = naTile:CreateFontString(nil, "OVERLAY")
    nameText:SetFont("Fonts\\FRIZQT__.TTF", 9)
    nameText:SetPoint("TOP", naTile, "TOP", 0, -12)
    nameText:SetText("POWER")
    nameText:SetTextColor(0.2, 0.2, 0.2)
    
    local typeText = naTile:CreateFontString(nil, "OVERLAY")
    typeText:SetFont("Fonts\\FRIZQT__.TTF", 8)
    typeText:SetPoint("BOTTOM", naTile, "BOTTOM", 0, 12)
    typeText:SetText("N/A")
    typeText:SetTextColor(0.13, 0.13, 0.13)
end

------------------------------------------------
-- Ability Selector Checkboxes
------------------------------------------------

-- Section label
local abilitiesLabel = optionsPanel:CreateFontString(nil, "OVERLAY")
abilitiesLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
abilitiesLabel:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 20, -185)
abilitiesLabel:SetText("|cFF888888ABILITY TRACKING|r")

-- Separator line
local separator = optionsPanel:CreateTexture(nil, "OVERLAY")
separator:SetColorTexture(0.3, 0.3, 0.3, 1)
separator:SetSize(240, 1)
separator:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 20, -198)

------------------------------------------------
-- Audio Dropdown Menu
------------------------------------------------
local SOUND_OPTIONS = {
    { name = "None", id = nil },
    { name = "Warning", id = 8959 }, -- Raid Warning
    { name = "Ready Check", id = 8960 },
    { name = "Ping", id = 5674 },
    { name = "Coin", id = 1483 },
}

local audioDropdown = CreateFrame("Frame", "MacUIAudioDropdown", UIParent, "BackdropTemplate")
audioDropdown:SetSize(100, #SOUND_OPTIONS * 20 + 4)
audioDropdown:SetFrameStrata("TOOLTIP")
audioDropdown:Hide()
audioDropdown:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
audioDropdown:SetBackdropColor(0, 0, 0, 0.95)
audioDropdown:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

local dropdownButtons = {}
for i, option in ipairs(SOUND_OPTIONS) do
    local btn = CreateFrame("Button", nil, audioDropdown)
    btn:SetSize(96, 20)
    btn:SetPoint("TOP", audioDropdown, "TOP", 0, -2 - ((i - 1) * 20))
    
    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 10)
    text:SetPoint("LEFT", btn, "LEFT", 5, 0)
    text:SetText(option.name)
    btn.text = text
    
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetColorTexture(1, 1, 1, 0.2)
    highlight:SetAllPoints(btn)
    
    btn:SetScript("OnClick", function()
        if audioDropdown.activeSpellID and MacUIDB and MacUIDB.audioAlerts then
            MacUIDB.audioAlerts[audioDropdown.activeSpellID] = option.id
            if option.id then PlaySound(option.id) end
            
            if audioDropdown.activeRow then
                audioDropdown.activeRow.UpdateAudioVisual(option.id)
            end
        end
        audioDropdown:Hide()
    end)
    dropdownButtons[i] = btn
end

-- Close dropdown if options panel hides
optionsPanel:HookScript("OnHide", function() audioDropdown:Hide() end)

-- Helper: Create a brutalist checkbox row
local function CreateAbilityCheckbox(parent, ability, yOffset, isCustom)
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

    -- Custom delete button
    if isCustom then
        local delBtn = CreateFrame("Button", nil, row)
        delBtn:SetSize(12, 12)
        delBtn:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
        local delText = delBtn:CreateFontString(nil, "OVERLAY")
        delText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        delText:SetPoint("CENTER", delBtn, "CENTER", 0, 0)
        delText:SetText("|cFFFF5555X|r")
        
        delBtn:SetScript("OnClick", function()
            if MacUIDB and MacUIDB.customAbilities then
                MacUIDB.customAbilities[ability.spellID] = nil
                if MacUIDB.trackedAbilities then MacUIDB.trackedAbilities[ability.spellID] = nil end
                -- Rebuild the UI (forward declaration requirement: BuildAbilityCheckboxes)
                -- We will call the global or addonTable hook instead of direct function call to avoid scope issues
                if addonTable.RebuildConfigUI then addonTable.RebuildConfigUI() end
                if addonTable.RebuildTrackerUI then addonTable.RebuildTrackerUI() end
            end
        end)
    end

    -- Audio toggle button ('A' icon)
    local audioBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
    audioBtn:SetSize(16, 16)
    audioBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    audioBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    
    local audioText = audioBtn:CreateFontString(nil, "OVERLAY")
    audioText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    audioText:SetPoint("CENTER", audioBtn, "CENTER", 1, 0)
    audioText:SetText("A")
    
    local function UpdateAudioVisual(soundID)
        if soundID then
            audioBtn:SetBackdropColor(0.2, 0.8, 0.2, 1) -- Green background when on
            audioBtn:SetBackdropBorderColor(0, 1, 0, 1)
            audioText:SetTextColor(0, 0, 0, 1)
        else
            audioBtn:SetBackdropColor(0.15, 0.15, 0.15, 1)
            audioBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
            audioText:SetTextColor(0.5, 0.5, 0.5, 1)
        end
    end
    
    audioBtn:SetScript("OnClick", function()
        if audioDropdown:IsShown() and audioDropdown.activeSpellID == ability.spellID then
            audioDropdown:Hide()
        else
            audioDropdown.activeSpellID = ability.spellID
            audioDropdown.activeRow = row
            audioDropdown:ClearAllPoints()
            audioDropdown:SetPoint("TOPRIGHT", audioBtn, "BOTTOMRIGHT", 0, -2)
            
            -- Highlight current selection
            local currentVal = MacUIDB and MacUIDB.audioAlerts and MacUIDB.audioAlerts[ability.spellID]
            for i, opt in ipairs(SOUND_OPTIONS) do
                if opt.id == currentVal then
                    dropdownButtons[i].text:SetTextColor(0, 1, 0, 1)
                else
                    dropdownButtons[i].text:SetTextColor(1, 1, 1, 1)
                end
            end
            
            audioDropdown:Show()
        end
    end)

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
    row.UpdateAudioVisual = UpdateAudioVisual
    row.spellID = ability.spellID
    return row
end

-- Store checkbox references so we can update them on show
local abilityCheckboxes = {}

-- Forward declare input frame
local customAbilityInput

-- Build checkboxes (Custom Abilities Only)
local function BuildAbilityCheckboxes()
    -- Clear existing checkboxes
    for _, row in ipairs(abilityCheckboxes) do
        row:Hide()
    end
    abilityCheckboxes = {}

    local visibleIndex = 0

    -- Custom Abilities
    if MacUIDB and MacUIDB.customAbilities then
        for spellID, isTracked in pairs(MacUIDB.customAbilities) do
            -- C_Spell.GetSpellInfo returns a table in 12.0.5 (.name, .iconID, .spellID)
            local spellInfo = GetSpellInfo(spellID)
            if spellInfo and spellInfo.name then
                local name = spellInfo.name
                visibleIndex = visibleIndex + 1
                local yOffset = -210 - ((visibleIndex - 1) * 24)
                -- custom abilities default to "buff" type for tracking
                local ability = { spellID = spellID, name = name, type = "buff" } 
                local row = CreateAbilityCheckbox(optionsPanel, ability, yOffset, true)
                table.insert(abilityCheckboxes, row)
            end
        end
    end
    
    -- Empty State Message
    local emptyStateMessage = optionsPanel.emptyStateMessage
    if not emptyStateMessage then
        emptyStateMessage = optionsPanel:CreateFontString(nil, "OVERLAY")
        emptyStateMessage:SetFont("Fonts\\FRIZQT__.TTF", 10)
        emptyStateMessage:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 20, -210)
        emptyStateMessage:SetText("|cFF888888You are not tracking any abilities.\nShift-Click a spell from your spellbook\nbelow to get started.|r")
        optionsPanel.emptyStateMessage = emptyStateMessage
    end
    
    -- Position Smart Input Box
    local inputYOffset = -210 - (visibleIndex * 24) - 5
    
    if visibleIndex == 0 then
        emptyStateMessage:Show()
        inputYOffset = -210 - 40 - 5 -- Move below the 3-line message
    else
        emptyStateMessage:Hide()
    end
    
    if not customAbilityInput then
        customAbilityInput = CreateFrame("EditBox", nil, optionsPanel, "InputBoxTemplate")
        customAbilityInput:SetSize(150, 20)
        customAbilityInput:SetAutoFocus(false)
        customAbilityInput:SetFontObject("ChatFontNormal")
        customAbilityInput:SetText("Shift-Click spell...")
        
        customAbilityInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        customAbilityInput:SetScript("OnEditFocusGained", function(self) 
            if self:GetText() == "Shift-Click spell..." then self:SetText("") end 
        end)
        customAbilityInput:SetScript("OnEditFocusLost", function(self) 
            if self:GetText() == "" then self:SetText("Shift-Click spell...") end 
        end)
        
        local addBtn = CreateFrame("Button", nil, optionsPanel, "BackdropTemplate")
        addBtn:SetSize(20, 20)
        addBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        addBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
        addBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        
        local addText = addBtn:CreateFontString(nil, "OVERLAY")
        addText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        addText:SetPoint("CENTER", addBtn, "CENTER", 1, 0)
        addText:SetText("+")
        
        addBtn:SetScript("OnClick", function()
            local text = customAbilityInput:GetText()
            local spellID = nil
            
            -- Try to parse as exact ID
            if tonumber(text) then
                spellID = tonumber(text)
            else
                -- Try to parse as link (e.g. |cff71d5ff|Hspell:190456:0|h[Ignore Pain]|h|r)
                local linkID = text:match("|Hspell:(%d+)")
                if linkID then
                    spellID = tonumber(linkID)
                else
                    -- Try to search by name — C_Spell.GetSpellInfo(name) returns a table
                    local spellInfo = GetSpellInfo(text)
                    if spellInfo and spellInfo.spellID then
                        spellID = spellInfo.spellID
                    end
                end
            end
            
            -- Validate the spell ID actually resolves
            local validInfo = spellID and GetSpellInfo(spellID)
            if validInfo and validInfo.name then
                if not MacUIDB.customAbilities then MacUIDB.customAbilities = {} end
                MacUIDB.customAbilities[spellID] = true
                if not MacUIDB.trackedAbilities then MacUIDB.trackedAbilities = {} end
                MacUIDB.trackedAbilities[spellID] = true -- Auto-track when added
                customAbilityInput:SetText("")
                customAbilityInput:ClearFocus()
                if addonTable.RebuildConfigUI then addonTable.RebuildConfigUI() end
                if addonTable.RebuildTrackerUI then addonTable.RebuildTrackerUI() end
            else
                print("|cFFFF0000MacUI:|r Could not find spell ID for '" .. text .. "'. Make sure to Shift-Click it from the spellbook.")
            end
        end)
        customAbilityInput.addBtn = addBtn
    end
    
    customAbilityInput:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 26, inputYOffset)
    customAbilityInput.addBtn:SetPoint("LEFT", customAbilityInput, "RIGHT", 5, 0)
end

-- Refresh checkbox visuals based on current MacUIDB state
local function RefreshAbilityCheckboxes()
    if not MacUIDB or not MacUIDB.trackedAbilities then return end
    if not MacUIDB.audioAlerts then MacUIDB.audioAlerts = {} end
    for _, row in ipairs(abilityCheckboxes) do
        row.UpdateVisual(MacUIDB.trackedAbilities[row.spellID] == true)
        row.UpdateAudioVisual(MacUIDB.audioAlerts[row.spellID])
    end
end

-- Export RebuildConfigUI so delete buttons can call it
addonTable.RebuildConfigUI = function()
    BuildAbilityCheckboxes()
    RefreshAbilityCheckboxes()
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
        -- Refresh checkboxes to reflect current DB state
        RefreshAbilityCheckboxes()
        
        -- Refresh stats grid tiles
        if not MacUIDB.displays then MacUIDB.displays = { health = true, resource = true, power = true } end
        if healthTile then healthTile.UpdateVisual(MacUIDB.displays.health) end
        if resourceTile then resourceTile.UpdateVisual(MacUIDB.displays.resource) end
        if powerTile then powerTile.UpdateVisual(MacUIDB.displays.power) end
    end
end

-- Listen for our addon to finish loading so we can read the DB
configFrame:RegisterEvent("ADDON_LOADED")
configFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not MacUIDB then MacUIDB = {} end
        if not MacUIDB.positions then MacUIDB.positions = {} end
        if not MacUIDB.scales then MacUIDB.scales = {} end
        if not MacUIDB.trackedAbilities then MacUIDB.trackedAbilities = {} end
        
        for _, frame in ipairs(addonTable.MovableFrames or {}) do
            ApplyFrameSettings(frame)
        end
        
        -- Build ability checkboxes now that the DB is ready
        BuildAbilityCheckboxes()
        RefreshAbilityCheckboxes()
        
        if not MacUIDB.displays then MacUIDB.displays = { health = true, resource = true, power = true } end
        if healthTile then healthTile.UpdateVisual(MacUIDB.displays.health) end
        if resourceTile then resourceTile.UpdateVisual(MacUIDB.displays.resource) end
        if powerTile then powerTile.UpdateVisual(MacUIDB.displays.power) end
        
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
