local addonName, addonTable = ...

local CreateFrame = CreateFrame
local UIParent = UIParent
local InCombatLockdown = InCombatLockdown
local math = math
local pairs = pairs
local ipairs = ipairs
local table = table
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
local PlaySound = PlaySound
local print = print

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
            minusText:SetFont("Fonts\\ARIALN.TTF", 14, "OUTLINE")
            minusText:SetPoint("CENTER", 0, 1)
            minusText:SetText("-")
            
            local btnPlus = CreateFrame("Button", nil, rc, "BackdropTemplate")
            btnPlus:SetSize(20, 20)
            btnPlus:SetPoint("RIGHT", rc, "RIGHT")
            btnPlus:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            btnPlus:SetBackdropColor(0.15, 0.15, 0.15, 1)
            btnPlus:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            local plusText = btnPlus:CreateFontString(nil, "OVERLAY")
            plusText:SetFont("Fonts\\ARIALN.TTF", 14, "OUTLINE")
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
optionsPanel:SetSize(300, 360)
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

-- Solid black backdrop with a stark 2px white border
optionsPanel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 2,
})
optionsPanel:SetBackdropColor(0, 0, 0, 0.95)
optionsPanel:SetBackdropBorderColor(1, 1, 1, 1)

-- Split-weight title: bold "MAC" + thin "UI"
local titleBold = optionsPanel:CreateFontString(nil, "OVERLAY")
titleBold:SetFont("Fonts\\ARIALN.TTF", 22, "OUTLINE")
titleBold:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 16, -14)
titleBold:SetText("|cFFFFFFFFMAC|r")

local titleThin = optionsPanel:CreateFontString(nil, "OVERLAY")
titleThin:SetFont("Fonts\\ARIALN.TTF", 22)
titleThin:SetPoint("LEFT", titleBold, "RIGHT", 0, 0)
titleThin:SetText("|cFFFFFFFFUI|r")

-- Top Right System Buttons (LOCK / RELOAD / CLOSE)
local btnToggleLock = CreateFrame("Button", nil, optionsPanel, "BackdropTemplate")
btnToggleLock:SetSize(58, 18)
btnToggleLock:SetPoint("TOPRIGHT", optionsPanel, "TOPRIGHT", -126, -14)
btnToggleLock:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})

local lockText = btnToggleLock:CreateFontString(nil, "OVERLAY")
lockText:SetFont("Fonts\\ARIALN.TTF", 8) -- Smaller font
lockText:SetPoint("CENTER")
btnToggleLock.text = lockText

function btnToggleLock:SetText(newText) self.text:SetText(newText) end
function btnToggleLock:SetState(isActive)
    if isActive then
        self:SetBackdropColor(1, 1, 1, 1)
        self:SetBackdropBorderColor(1, 1, 1, 1)
        self.text:SetTextColor(0, 0, 0, 1)
    else
        self:SetBackdropColor(0, 0, 0, 0)
        self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        self.text:SetTextColor(1, 1, 1, 1)
    end
end

local function UpdateLockUI()
    if addonTable.IsUnlocked then
        btnToggleLock:SetText("UNLOCKED")
        btnToggleLock:SetState(true)
    else
        btnToggleLock:SetText("LOCKED")
        btnToggleLock:SetState(false)
    end
end
addonTable.UpdateLockUI = UpdateLockUI
btnToggleLock:SetScript("OnClick", function() addonTable.ToggleLock() end)
UpdateLockUI()

local btnReload = CreateFrame("Button", nil, optionsPanel, "BackdropTemplate")
btnReload:SetSize(48, 18)
btnReload:SetPoint("TOPRIGHT", optionsPanel, "TOPRIGHT", -72, -14)
btnReload:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
btnReload:SetBackdropBorderColor(1, 1, 1, 1)

local reloadText = btnReload:CreateFontString(nil, "OVERLAY")
reloadText:SetFont("Fonts\\ARIALN.TTF", 8)
reloadText:SetPoint("CENTER")
reloadText:SetText("RELOAD")
btnReload:SetScript("OnClick", function() ReloadUI() end)

local btnClose = CreateFrame("Button", nil, optionsPanel, "BackdropTemplate")
btnClose:SetSize(48, 18)
btnClose:SetPoint("TOPRIGHT", optionsPanel, "TOPRIGHT", -16, -14)
btnClose:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
btnClose:SetBackdropBorderColor(1, 1, 1, 1)

local closeText = btnClose:CreateFontString(nil, "OVERLAY")
closeText:SetFont("Fonts\\ARIALN.TTF", 8)
closeText:SetPoint("CENTER")
closeText:SetText("CLOSE")
btnClose:SetScript("OnClick", function() optionsPanel:Hide() end)

local function CreateToggleItem(parent, text)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(80, 20)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    
    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetFont("Fonts\\ARIALN.TTF", 10)
    btnText:SetPoint("CENTER")
    btnText:SetText(text)
    btn.text = btnText

    function btn:SetText(newText)
        self.text:SetText(newText)
    end

    function btn:SetState(isActive)
        if isActive then
            self:SetBackdropColor(1, 1, 1, 1) -- White BG
            self:SetBackdropBorderColor(1, 1, 1, 1)
            self.text:SetTextColor(0, 0, 0, 1) -- Black Text
        else
            self:SetBackdropColor(0, 0, 0, 0) -- Transparent
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            self.text:SetTextColor(0.4, 0.4, 0.4, 1)
        end
    end

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
    if addonTable.UpdateLockUI then addonTable.UpdateLockUI() end
end
addonTable.ToggleLock = ToggleLock

-- (Lock UI section removed from body)

------------------------------------------------
-- Player Stats (Grid Tiles)
------------------------------------------------

local statsLabel = optionsPanel:CreateFontString(nil, "OVERLAY")
statsLabel:SetFont("Fonts\\ARIALN.TTF", 10)
statsLabel:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 20, -50)
statsLabel:SetText("PLAYER STATS")

local function CreateStatTile(parent, id, xOffset, label, typeLabel, defaultColor)
    local tile = CreateFrame("Button", nil, parent, "BackdropTemplate")
    tile:SetSize(80, 40) -- Slimmer
    tile:SetPoint("TOPLEFT", parent, "TOPLEFT", 20 + xOffset, -68) -- 18px gap
    tile:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    
    local typeText = tile:CreateFontString(nil, "OVERLAY")
    typeText:SetFont("Fonts\\ARIALN.TTF", 8)
    typeText:SetPoint("TOP", tile, "TOP", 0, -8) -- Tightened for 40px
    typeText:SetText(typeLabel)
    tile.typeText = typeText

    local nameText = tile:CreateFontString(nil, "OVERLAY")
    nameText:SetFont("Fonts\\ARIALN.TTF", 9)
    nameText:SetPoint("BOTTOM", tile, "BOTTOM", 0, 8) -- Tightened for 40px
    nameText:SetText(label)
    tile.nameText = nameText
    
    tile.id = id
    tile.color = defaultColor
    
    local function UpdateVisual(isEnabled)
        if isEnabled then
            tile:SetBackdropColor(0, 0, 0, 1)
            tile:SetBackdropBorderColor(1, 1, 1, 1) -- Pure White
            local c = tile.color or {1, 1, 1}
            nameText:SetTextColor(c[1], c[2], c[3]) -- Spec Color for the Name (Value)
            typeText:SetTextColor(1, 1, 1) -- Pure White for Category
        else
            tile:SetBackdropColor(0, 0, 0, 0.5)
            tile:SetBackdropBorderColor(0.2, 0.2, 0.2, 1) -- Dark Grey
            nameText:SetTextColor(0.3, 0.3, 0.3)
            typeText:SetTextColor(0.2, 0.2, 0.2)
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

-- Create the 3 tiles (Now always created, content updated dynamically)
local healthTile = CreateStatTile(optionsPanel, "health", 0, "Health", "Health", {0, 1, 0})
local resourceTile = CreateStatTile(optionsPanel, "resource", 90, "Resource", "Resource", {1, 1, 1})
local powerTile = CreateStatTile(optionsPanel, "power", 180, "Power", "Power", {1, 1, 1})

local function RefreshStatTiles()
    if not MacUIDB or not MacUIDB.displays then return end
    local classInfo = addonTable.ClassDisplayInfo and addonTable.ClassDisplayInfo[addonTable.playerClass]
    
    -- 1. Health
    healthTile.UpdateVisual(MacUIDB.displays.health)
    
    -- 2. Resource
    if classInfo and classInfo.resource then
        resourceTile:Show()
        resourceTile.nameText:SetText(classInfo.resource.name)
        resourceTile.typeText:SetText("Resource")
        resourceTile.color = classInfo.resource.color
        resourceTile.UpdateVisual(MacUIDB.displays.resource)
    else
        resourceTile:Hide()
    end
    
    -- 3. Power
    local hasPower = false
    if classInfo and classInfo.power then
        for _, s in ipairs(classInfo.power.specs) do
            if s == addonTable.playerSpec then hasPower = true break end
        end
    end
    
    if hasPower then
        powerTile:SetAlpha(1)
        powerTile:EnableMouse(true)
        powerTile.nameText:SetText(classInfo.power.name)
        powerTile.nameText:SetTextColor(1, 1, 1)
        powerTile.typeText:SetText("Power")
        powerTile.color = classInfo.power.color
        powerTile.UpdateVisual(MacUIDB.displays.power)
    else
        -- Dimmed N/A state
        powerTile:SetAlpha(1) -- Keep visible but dimmed visuals
        powerTile:EnableMouse(false)
        powerTile.nameText:SetText("POWER")
        powerTile.nameText:SetTextColor(0.2, 0.2, 0.2)
        powerTile.typeText:SetText("N/A")
        powerTile.typeText:SetTextColor(0.13, 0.13, 0.13)
        powerTile:SetBackdropColor(0.04, 0.04, 0.04, 1)
        powerTile:SetBackdropBorderColor(0.13, 0.13, 0.13, 1)
    end
end

------------------------------------------------
-- Ability Selector Checkboxes
------------------------------------------------

-- Section label
local abilitiesLabel = optionsPanel:CreateFontString(nil, "OVERLAY")
abilitiesLabel:SetFont("Fonts\\ARIALN.TTF", 10)
abilitiesLabel:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 20, -132) -- 24px Gap from tiles
abilitiesLabel:SetText("ABILITY TRACKING")

-- (Underline separator removed)

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
    text:SetFont("Fonts\\ARIALN.TTF", 10)
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
    checkbox:SetSize(12, 12)
    checkbox:SetPoint("LEFT", row, "LEFT", 0, 0)
    checkbox:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    checkbox:SetBackdropBorderColor(1, 1, 1, 1)

    local checkText = checkbox:CreateFontString(nil, "OVERLAY")
    checkText:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
    checkText:SetPoint("CENTER", checkbox, "CENTER", 0, 0)
    checkText:SetText("X")
    checkText:Hide()
    row.checkText = checkText

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
    nameText:SetFont("Fonts\\ARIALN.TTF", 11)
    nameText:SetPoint("LEFT", iconPreview, "RIGHT", 6, 0)
    nameText:SetText("|cFFFFFFFF" .. ability.name .. "|r")

    -- Custom delete button
    if isCustom then
        local delBtn = CreateFrame("Button", nil, row)
        delBtn:SetSize(12, 12)
        delBtn:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
        local delText = delBtn:CreateFontString(nil, "OVERLAY")
        delText:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
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
    audioText:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
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
            checkbox:SetBackdropBorderColor(1, 1, 1, 1)
            row.checkText:Show()
        else
            checkbox:SetBackdropColor(0, 0, 0, 0)
            checkbox:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            row.checkText:Hide()
        end
    end

    row:SetScript("OnClick", function()
        if not MacUIDB then return end
        if not MacUIDB.trackedAbilities then MacUIDB.trackedAbilities = {} end

        -- Toggle logic: For defaults, nil is "true".
        local current = MacUIDB.trackedAbilities[ability.spellID]
        if current == nil then current = true end
        
        local isNowEnabled = not current
        MacUIDB.trackedAbilities[ability.spellID] = isNowEnabled
        UpdateVisual(isNowEnabled)

        -- Rebuild the tracker UI immediately
        if addonTable.RebuildTrackerUI then
            addonTable.RebuildTrackerUI()
        end
    end)

    row.UpdateVisual = UpdateVisual
    row.UpdateAudioVisual = UpdateAudioVisual
    row.spellID = ability.spellID
    row.isCustom = isCustom
    return row
end

-- Store checkbox references so we can update them on show
local abilityCheckboxes = {}

-- Forward declare input frame


-- Build checkboxes (Custom Abilities Only)
local function BuildAbilityCheckboxes()
    -- Clear existing checkboxes
    for _, row in ipairs(abilityCheckboxes) do
        row:Hide()
    end
    abilityCheckboxes = {}

    local visibleIndex = 0

    -- 1. Class Defaults
    local classDefaults = addonTable.DefaultAbilities and addonTable.DefaultAbilities[addonTable.playerClass]
    local specDefaults = classDefaults and classDefaults[addonTable.playerSpec]
    
    if specDefaults then
        for _, ability in ipairs(specDefaults) do
            visibleIndex = visibleIndex + 1
            local yOffset = -150 - ((visibleIndex - 1) * 24) -- 18px gap from label
            local row = CreateAbilityCheckbox(optionsPanel, ability, yOffset, false)
            table.insert(abilityCheckboxes, row)
        end
    end


end

-- Refresh checkbox visuals based on current MacUIDB state
local function RefreshAbilityCheckboxes()
    if not MacUIDB or not MacUIDB.trackedAbilities then return end
    if not MacUIDB.audioAlerts then MacUIDB.audioAlerts = {} end
    for _, row in ipairs(abilityCheckboxes) do
        -- For defaults, if not in DB, it's true (tracked). For custom, it must be true.
        local isEnabled
        if row.isCustom then
            isEnabled = MacUIDB.trackedAbilities[row.spellID] == true
        else
            isEnabled = MacUIDB.trackedAbilities[row.spellID] ~= false
        end
        row.UpdateVisual(isEnabled)
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
    RefreshStatTiles()
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
        RefreshStatTiles()
    end
end



-- Listen for our addon to finish loading so we can read the DB
configFrame:RegisterEvent("ADDON_LOADED")
configFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        for _, frame in ipairs(addonTable.MovableFrames or {}) do
            ApplyFrameSettings(frame)
        end
        
        -- Build ability checkboxes now that the DB is ready
        BuildAbilityCheckboxes()
        RefreshAbilityCheckboxes()
        
        RefreshStatTiles()
        
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
