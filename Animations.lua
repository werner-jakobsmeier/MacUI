local addonName, addonTable = ...

-- Initialize an Animations table within our addon namespace
addonTable.Animations = {}

local math = math
local GetTime = GetTime

-- A reusable pulsing red animation that can be attached to any frame's OnUpdate
function addonTable.Animations.PulseRed(self, elapsed)
    -- math.sin creates a smooth wave between -1 and 1
    -- We convert this to a range between 0.3 (dark red) and 1.0 (bright red)
    local wave = (math.sin(GetTime() * 6) + 1) / 2
    local intensity = 0.3 + (wave * 0.7)
    
    self:SetBackdropColor(intensity, 0, 0, 1)
end
