local addonName, addonTable = ...

-- Create a custom square frame
local squareFrame = CreateFrame("Frame", "MacUISquare", UIParent, "BackdropTemplate")
squareFrame:SetSize(40, 40)
-- Point, RelativeFrame, RelativePoint, X-Offset, Y-Offset
squareFrame:SetPoint("CENTER", UIParent, "CENTER", -200, 100)

-- Set up the black background and 4-pixel white border
squareFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 4,
})
squareFrame:SetBackdropColor(0, 0, 0, 1) -- Black background (R, G, B, Alpha)
squareFrame:SetBackdropBorderColor(1, 1, 1, 1) -- White border (R, G, B, Alpha)
