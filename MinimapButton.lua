local addonName, addonTable = ...

local CreateFrame = CreateFrame
local Minimap = Minimap
local math = math
local GetCursorPosition = GetCursorPosition
local GameTooltip = GameTooltip

------------------------------------------------
-- 1. AddonCompartmentFrame (Modern 10.0+ / 12.0.5 API)
--    Registered via TOC metadata. These global functions are REQUIRED
--    by the Blizzard API and are an intentional exception to Guideline #3.
------------------------------------------------

-- NOTE: AddonCompartmentFunc requires GLOBAL functions (not local).
-- This is an intentional exception to the "no globals" rule (see Guideline #5).
function MacUI_OnAddonCompartmentClick(addonName, buttonName)
    if buttonName == "LeftButton" then
        if addonTable.optionsPanel then
            addonTable.optionsPanel:SetShown(not addonTable.optionsPanel:IsShown())
        end
    elseif buttonName == "RightButton" then
        if addonTable.ToggleLock then
            addonTable.ToggleLock()
        end
    end
end

function MacUI_OnAddonCompartmentEnter(addonName, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_RIGHT")
    GameTooltip:SetText("|cFFFFFFFFMac|r|cFFAAAAAAUI|r")
    GameTooltip:AddLine("Left-Click: Toggle Config Panel", 1, 1, 1)
    GameTooltip:AddLine("Right-Click: Lock/Unlock Frames", 1, 1, 1)
    GameTooltip:Show()
end

function MacUI_OnAddonCompartmentLeave(addonName, menuButtonFrame)
    GameTooltip:Hide()
end

------------------------------------------------
-- 2. Classic Minimap Button (Legacy draggable icon)
--    For users who prefer a dedicated, visible, draggable icon
--    on the minimap ring itself.
------------------------------------------------

local button = CreateFrame("Button", "MacUIMinimapButton", Minimap)
button:SetSize(32, 32)
button:SetFrameLevel(8)
button:SetFrameStrata("MEDIUM")
button:RegisterForDrag("LeftButton")
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

local icon = button:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\AddOns\\MacUI\\MinimapIcon")
icon:SetSize(20, 20)
icon:SetPoint("CENTER")

-- No mask needed for the new brutalist square icon
-- (Mask logic removed)

local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")

local highlight = button:CreateTexture(nil, "HIGHLIGHT")
highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
highlight:SetBlendMode("ADD")
highlight:SetAllPoints(icon)

-- Tooltip on hover (matches the Compartment tooltip)
button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("|cFFFFFFFFMac|r|cFFAAAAAAUI|r")
    GameTooltip:AddLine("Left-Click: Toggle Config Panel", 1, 1, 1)
    GameTooltip:AddLine("Right-Click: Lock/Unlock Frames", 1, 1, 1)
    GameTooltip:AddLine("Drag: Move this button", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Updates the position of the button on the minimap ring
local function UpdatePosition()
    if not MacUIDB or not MacUIDB.minimap then return end
    local angle = math.rad(MacUIDB.minimap.angle or 45)
    -- Minimap radius is ~80px
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Dragging Math
button:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function(self)
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        
        px = px / scale
        py = py / scale
        
        -- Calculate angle between cursor and minimap center
        local angle = math.atan2(py - my, px - mx)
        
        if not MacUIDB.minimap then MacUIDB.minimap = {} end
        MacUIDB.minimap.angle = math.deg(angle)
        UpdatePosition()
    end)
end)

button:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self:SetScript("OnUpdate", nil)
end)

-- Click Handlers (same logic as Compartment)
button:SetScript("OnClick", function(self, btn)
    if btn == "LeftButton" then
        if addonTable.optionsPanel then
            addonTable.optionsPanel:SetShown(not addonTable.optionsPanel:IsShown())
        end
    elseif btn == "RightButton" then
        if addonTable.ToggleLock then
            addonTable.ToggleLock()
        end
    end
end)

-- Initialize position after DB loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    UpdatePosition()
end)
