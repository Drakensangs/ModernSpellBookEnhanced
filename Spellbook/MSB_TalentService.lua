-- Watches talent points: a talent that gets its first point is marked "New"
-- (talents without a spellbook button send no learned-spell event), and the
-- book is rebuilt after every change, a reset included.

MSB_class "MSB_CTalentService"
{
	__init = function(self)
		local service = self
		-- The starting ranks are read on entering the world; later changes
		-- come with CHARACTER_POINTS_CHANGED
		self.frame = CreateFrame("Frame")
		self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
		self.frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
		self.frame:SetScript("OnEvent", function()
			if (event == "PLAYER_ENTERING_WORLD") then
				service.ranks = service.ranks or service:ReadRanks()
				return
			end
			service:MarkNewTalents()
			MSB_SpellBook:OnSpellsChanged()
		end)
	end;

	-- Current rank of every talent, keyed by its rank 1 spell ID
	ReadRanks = function(self)
		local ranks = {}
		for t = 1, GetNumTalentTabs() do
			for i = 1, GetNumTalents(t) do
				local _, _, _, _, currRank = GetTalentInfo(t, i)
				local spellID = GetTalentSpellID(t, i, 1)
				if (spellID) then ranks[spellID] = currRank end
			end
		end
		return ranks
	end;

	MarkNewTalents = function(self)
		local ranks = self:ReadRanks()
		local before = self.ranks
		if (before) then
			for spellID, rank in pairs(ranks) do
				if (rank > 0 and (before[spellID] or 0) == 0) then
					ModernSpellBook_DB.newSpells[spellID] = true
				end
			end
		end
		self.ranks = ranks
	end;
}

MSB_TalentService = MSB_CTalentService()
