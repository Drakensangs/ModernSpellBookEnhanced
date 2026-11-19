-- Finds the spells that are on no action bar (setting "Highlight spells not
-- on action bars") and refreshes the pet autocast marks.

local MAX_ACTION_SLOTS = 120	-- every bar page, stance and bonus bars included

MSB_class "MSB_CActionBarHelper"
{
	__init = function(self)
		self.placedSpells = nil

		-- Keeps the highlight current while the bars change
		local helper = self
		self.frame = CreateFrame("Frame")
		self.frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
		self.frame:RegisterEvent("UPDATE_MACROS")
		self.frame:RegisterEvent("PET_BAR_UPDATE")
		self.frame:SetScript("OnEvent", function()
			helper:InvalidatePlacedSpells()
			helper:QueueHighlightUpdate()
			-- Autocast may have been toggled on the pet bar
			if (event == "PET_BAR_UPDATE") then helper:QueueAutocastUpdate() end
		end)
	end;

	-- The bars are read again on next use
	InvalidatePlacedSpells = function(self)
		self.placedSpells = nil
	end;

	-- Names of the spells on any action bar, directly or through a macro or
	-- item (C_ActionBar.GetSpell), plus the pet bar. Any rank counts.
	GetPlacedSpells = function(self)
		if (self.placedSpells) then return self.placedSpells end
		local names = {}
		for slot = 1, MAX_ACTION_SLOTS do
			local spellID = C_ActionBar.GetSpell(slot)
			local name = spellID and spellID > 0 and C_Spell.GetSpellName(spellID)
			if (name) then names[name] = true end
		end
		for i = 1, NUM_PET_ACTION_SLOTS do
			local name = GetPetActionInfo(i)
			if (name) then names[name] = true end
		end
		self.placedSpells = names
		return names
	end;

	-- True for a learned, castable spell on no bar. Passives, talents without
	-- a button and stances/forms (they have the stance bar) never count.
	IsSpellUnplaced = function(self, spellInfo)
		if (not spellInfo or spellInfo.isUnlearned or spellInfo.isPassive) then return false end
		if (spellInfo.isTalent or spellInfo.stanceIndex or not spellInfo.slot) then return false end
		return not self:GetPlacedSpells()[spellInfo.spellName]
	end;

	-- Slot events come in bursts: one page update 0.1 s after the first
	QueueHighlightUpdate = function(self)
		if (self.updateQueued or not ModernSpellBook_DB or not ModernSpellBook_DB.highlightUnplaced) then return end
		if (not ModernSpellBookFrame or not ModernSpellBookFrame:IsVisible()) then return end
		self.updateQueued = true
		local helper = self
		MSB_After(0.1, function()
			helper.updateQueued = false
			if (ModernSpellBookFrame:IsVisible()) then MSB_SpellBook:UpdateUnplacedHighlights() end
		end)
	end;

	QueueAutocastUpdate = function(self)
		if (self.autocastQueued or not ModernSpellBookFrame or not ModernSpellBookFrame:IsVisible()) then return end
		self.autocastQueued = true
		local helper = self
		MSB_After(0.1, function()
			helper.autocastQueued = false
			if (ModernSpellBookFrame:IsVisible()) then MSB_SpellBook:UpdateAutocast() end
		end)
	end;
}

MSB_ActionBarHelper = MSB_CActionBarHelper()
