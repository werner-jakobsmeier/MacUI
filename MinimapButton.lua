local addonName, addonTable = ...

local CreateFrame = CreateFrame
local Minimap = Minimap
local math = math
local GetCursorPosition = GetCursorPosition

local button = CreateFrame("Button", "MacUIMinimapButton", Minimap)
button:SetSize(32, 32)
button:SetFrameLevel(8)
button:SetFrameStrata("MEDIUM")
button:RegisterForDrag("LeftButton")
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

local icon = button:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_EngGizmos_17") -- Cool gear icon
icon:SetSize(20, 20)
icon:SetPoint("CENTER")

-- Circular mask so the icon doesn't poke out of the border
local mask = button:CreateMaskTexture()
mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
mask:SetAllPoints(icon)
icon:AddMaskTexture(mask)

local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")

local highlight = button:CreateTexture(nil, "HIGHLIGHT")
highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
highlight:SetBlendMode("ADD")
highlight:SetAllPoints(icon)

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

-- Click Handlers
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
