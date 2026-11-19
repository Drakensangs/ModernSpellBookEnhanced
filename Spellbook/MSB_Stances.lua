-- Keeps the "active" glow of stance, form, aura and stealth spells on the
-- one in use. ClassicAPI's UPDATE_SHAPESHIFT_FORM reports form changes;
-- a paladin aura switch doesn't change the form, so PLAYER_AURAS_CHANGED is
-- watched too, only while the book is open.

local function UpdateActiveStance()
	if (not ModernSpellBookFrame or not ModernSpellBookFrame:IsVisible()) then return end
	local activeName = nil
	for i = 1, GetNumShapeshiftForms() do
		local _, name, isActive = GetShapeshiftFormInfo(i)
		if (isActive) then
			activeName = name
			break
		end
	end
	for stanceName, stanceButton in pairs(ModernSpellBookFrame.stanceButtons) do
		stanceButton:SetStance(stanceName == activeName)
	end
end

local stanceEvents = CreateFrame("Frame")
stanceEvents:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
stanceEvents:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
stanceEvents:SetScript("OnEvent", UpdateActiveStance)

-- The book calls this when it opens (true) and closes (false)
function MSB_WatchAuras(watch)
	if (watch) then
		stanceEvents:RegisterEvent("PLAYER_AURAS_CHANGED")
	else
		stanceEvents:UnregisterEvent("PLAYER_AURAS_CHANGED")
	end
end
