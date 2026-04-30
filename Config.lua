local addonName, addonTable = ...

local CreateFrame = CreateFrame
local UIParent = UIParent
local SlashCmdList = SlashCmdList
local print = print
local tonumber = tonumber
local string = string

-- Slash Command Registration
SLASH_MACUI1 = "/macui"
SLASH_MACUI2 = "/mu"

local isUnlocked = false
local configFrame = CreateFrame("Frame")

-- Applies the saved font size to all registered font strings
local function ApplyFontSize(size)
    if not size or size <= 0 then return end
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
    isUnlocked = true
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
    isUnlocked = false
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
-- GUI Options Panel
------------------------------------------------
-- Standard WoW window template
local optionsPanel = CreateFrame("Frame", "MacUIOptionsPanel", UIParent, "BasicFrameTemplateWithInset")
optionsPanel:SetSize(300, 250)
optionsPanel:SetPoint("CENTER")
optionsPanel:Hide() -- Hidden by default
optionsPanel:SetMovable(true)
optionsPanel:EnableMouse(true)
optionsPanel:RegisterForDrag("LeftButton")
optionsPanel:SetScript("OnDragStart", optionsPanel.StartMoving)
optionsPanel:SetScript("OnDragStop", optionsPanel.StopMovingOrSizing)

-- Title text
optionsPanel.title = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
optionsPanel.title:SetPoint("CENTER", optionsPanel.TitleBg, "CENTER", 0, 0)
optionsPanel.title:SetText("MacUI Configuration")

-- Unlock Button
local btnUnlock = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
btnUnlock:SetSize(120, 30)
btnUnlock:SetPoint("TOP", optionsPanel, "TOP", 0, -40)
btnUnlock:SetText("Unlock Layout")
btnUnlock:SetScript("OnClick", function()
    UnlockFrames()
end)

-- Lock Button
local btnLock = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
btnLock:SetSize(120, 30)
btnLock:SetPoint("TOP", btnUnlock, "BOTTOM", 0, -10)
btnLock:SetText("Lock & Save")
btnLock:SetScript("OnClick", function()
    LockFrames()
end)

-- Font Size Slider
local slider = CreateFrame("Slider", "MacUIFontSlider", optionsPanel, "OptionsSliderTemplate")
slider:SetPoint("TOP", btnLock, "BOTTOM", 0, -30)
slider:SetMinMaxValues(8, 32)
slider:SetValueStep(1)
slider:SetObeyStepOnDrag(true)

-- Slider text setup
_G[slider:GetName() .. "Low"]:SetText("8")
_G[slider:GetName() .. "High"]:SetText("32")
_G[slider:GetName() .. "Text"]:SetText("Font Size")

slider:SetScript("OnValueChanged", function(self, value)
    _G[self:GetName() .. "Text"]:SetText("Font Size: " .. value)
    ApplyFontSize(value)
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
    end
end

-- Listen for our addon to finish loading so we can read the DB
configFrame:RegisterEvent("ADDON_LOADED")
configFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not MacUIDB then MacUIDB = {} end
        if not MacUIDB.positions then MacUIDB.positions = {} end
        if not MacUIDB.fontSize then MacUIDB.fontSize = 14 end
        
        for _, frame in ipairs(addonTable.MovableFrames or {}) do
            ApplyFramePosition(frame)
        end
        
        ApplyFontSize(MacUIDB.fontSize)
        slider:SetValue(MacUIDB.fontSize)
        
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
