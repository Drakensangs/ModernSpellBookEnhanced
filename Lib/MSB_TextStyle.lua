-- Text colors, shadows and trail blend for the "Spell text color" setting
-- (light or dark), learned and unlearned.

MSB_class "MSB_CTextStyle"
{
	IsDark = function(self)
		return ModernSpellBook_DB and ModernSpellBook_DB.textColorMode == "dark"
	end;

	-- mode: "normal" or "unlearned"
	ApplyToSpell = function(self, nameFS, subFS, lightBorder, mode)
		local isDark = self:IsDark()

		if (mode == "unlearned") then
			if (isDark) then
				nameFS:SetTextColor(0.4, 0.4, 0.4)
				subFS:SetTextColor(0.4, 0.4, 0.4)
			else
				nameFS:SetTextColor(0.6, 0.55, 0.35)
				subFS:SetTextColor(0.6, 0.6, 0.6)
			end
			nameFS:SetShadowOffset(1, -1)
			nameFS:SetShadowColor(0, 0, 0, 0.7)
			subFS:SetShadowOffset(1, -1)
			subFS:SetShadowColor(0, 0, 0, 0.7)
		elseif (isDark) then
			nameFS:SetTextColor(0, 0, 0)
			subFS:SetTextColor(0.2, 0.2, 0.2)
			nameFS:SetShadowOffset(0, 0)
			subFS:SetShadowOffset(0, 0)
		else
			nameFS:SetTextColor(0.989, 0.857, 0.343)
			subFS:SetTextColor(1, 1, 1)
			nameFS:SetShadowOffset(1, -1)
			nameFS:SetShadowColor(0, 0, 0, 0.7)
			subFS:SetShadowOffset(1, -1)
			subFS:SetShadowColor(0, 0, 0, 0.7)
		end

		if (lightBorder) then
			-- Fainter trail on unlearned spells, to match their faded icons
			lightBorder:SetAlpha(mode == "unlearned" and 0.6 or 1)
			lightBorder:SetBlendMode(isDark and "ADD" or "BLEND")
		end
	end;
}

MSB_TextStyle = MSB_CTextStyle()
