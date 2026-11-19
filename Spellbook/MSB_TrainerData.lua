-- Reads a class trainer's list when it opens and saves its spells by ID
-- (cost, and level or requirement where needed), so the book can show the
-- spells you haven't learned. Everything else comes from ClassicAPI.

local TRAINER_FILTER_TYPES = { "available", "unavailable", "used" }

-- "Name (Rank 2)" -> "Name", "Rank 2"; anything else -> the whole text, ""
local function SplitAbility(text)
	local _, _, name, rank = string.find(text, "^(.-)%s*%((.-)%)$")
	if (name and name ~= "") then return name, rank end
	return text, ""
end

MSB_class "MSB_CTrainerDataService"
{
	__init = function(self)
		local service = self
		self.frame = CreateFrame("Frame")
		self.frame:RegisterEvent("TRAINER_SHOW")
		self.frame:RegisterEvent("TRAINER_CLOSED")
		-- Read 0.3 s after the trainer opens (the list fills in after the
		-- event); closing it first cancels the read
		self.visit = 0
		self.frame:SetScript("OnEvent", function()
			service.visit = service.visit + 1
			if (event ~= "TRAINER_SHOW") then return end
			local visit = service.visit
			MSB_After(0.3, function()
				if (service.visit == visit) then service:CaptureTrainerData() end
			end)
		end)
	end;

	-- =================== CAPTURE =============================

	HasTrainerData = function(self)
		return next(ModernSpellBook_DB.trainer) ~= nil
	end;

	-- IsTradeskillTrainer() is not used: a rogue trainer with poisons can
	-- report itself as one. ScanTrainerServices instead keeps only lists
	-- with a spell of your class, which skips profession, pet and weapon
	-- trainers.
	CaptureTrainerData = function(self)
		-- The trainer lists only what its filters and headers let through, so
		-- all are opened first, and put back afterwards even if reading fails
		local savedFilters = self:ShowAllTrainerServices()
		local collapsed = self:ExpandAllHeaders()
		local ok, err = pcall(self.ScanTrainerServices, self)
		self:RestoreHeaders(collapsed)
		self:RestoreTrainerFilters(savedFilters)
		if (not ok) then geterrorhandler()(err) end
	end;

	-- Turns every trainer filter on; returns the player's previous settings
	ShowAllTrainerServices = function(self)
		local savedFilters = {}
		for _, filterType in ipairs(TRAINER_FILTER_TYPES) do
			savedFilters[filterType] = GetTrainerServiceTypeFilter(filterType) and 1 or 0
			if (savedFilters[filterType] == 0) then SetTrainerServiceTypeFilter(filterType, 1) end
		end
		return savedFilters
	end;

	RestoreTrainerFilters = function(self, savedFilters)
		for filterType, isOn in pairs(savedFilters) do
			if (isOn == 0) then SetTrainerServiceTypeFilter(filterType, 0) end
		end
	end;

	-- A collapsed header hides its spells from the list: opens them all
	-- and returns the names of the headers that were closed
	ExpandAllHeaders = function(self)
		local collapsed = {}
		for i = 1, GetNumTrainerServices() do
			local name, _, serviceType, isExpanded = GetTrainerServiceInfo(i)
			if (serviceType == "header" and not isExpanded) then
				table.insert(collapsed, name)
			end
		end
		if (table.getn(collapsed) > 0) then ExpandTrainerSkillLine(0) end
		return collapsed
	end;

	-- Closes those headers again, from the bottom so the indexes stay valid
	RestoreHeaders = function(self, collapsed)
		if (table.getn(collapsed) == 0) then return end
		local wasCollapsed = {}
		for _, name in ipairs(collapsed) do wasCollapsed[name] = true end
		for i = GetNumTrainerServices(), 1, -1 do
			local name, _, serviceType = GetTrainerServiceInfo(i)
			if (serviceType == "header" and wasCollapsed[name]) then
				CollapseTrainerSkillLine(i)
			end
		end
	end;

	-- IDs of the spells your class and race can learn, from ClassicAPI:
	-- byRank["Name|Rank"], and byName["Name"] when one spell has that name
	-- (false when several do). Built on the first trainer visit.
	GetSpellIDMap = function(self)
		if (self.spellIDMap) then return self.spellIDMap end
		local byRank, byName = {}, {}
		local function Add(spellID)
			-- Recipes (rogue poisons) are left out, so their rows are skipped
			if (MSB_IsRecipeSpell(spellID)) then return end
			local name = C_Spell.GetSpellName(spellID)
			if (not name) then return end
			byRank[name .. "|" .. (C_Spell.GetSpellSubtext(spellID) or "")] = spellID
			if (byName[name] == nil) then byName[name] = spellID
			elseif (byName[name] ~= spellID) then byName[name] = false end
		end
		for level = 1, GetMaxPlayerLevel() do
			for _, spellID in ipairs(C_SpellBook.GetCurrentLevelSpells(level)) do Add(spellID) end
		end
		-- General abilities (Plate Mail, Dual Wield, ...): some have no spell
		-- level, so the level lists miss them
		MSB_SpellSources:ForEachGeneralSpell(Add)
		self.spellIDMap = { byRank = byRank, byName = byName }
		return self.spellIDMap
	end;

	-- Spell ID of a trainer row. Rows without a rank number (Parry, Plate
	-- Mail) may leave out "Passive": then the name alone is enough.
	FindSpellID = function(self, name, rank)
		local map = self:GetSpellIDMap()
		local spellID = map.byRank[name .. "|" .. (rank or "")]
		if (not spellID and MSB_RankNumber(rank) == 0) then spellID = map.byName[name] end
		return spellID or nil
	end;

	-- Expected training level: the addon's for general abilities, else ClassicAPI's
	BaseLevel = function(self, spellID)
		return MSB_SpellSources:GetGeneralLevel(spellID) or C_SpellBook.GetSpellLevelLearned(spellID)
	end;

	-- Drops recipes saved by older versions (3.2.2 kept rogue poisons).
	-- Nothing saves them now, so once per session is enough.
	ForgetRecipes = function(self)
		if (self.recipesForgotten) then return end
		self.recipesForgotten = true
		local db = ModernSpellBook_DB
		for spellID in pairs(db.trainer) do
			if (MSB_IsRecipeSpell(spellID)) then
				db.trainer[spellID] = nil
				db.trainerLevel[spellID] = nil
				db.trainerNeeds[spellID] = nil
			end
		end
	end;

	-- Reads the list; expects every filter and header open
	ScanTrainerServices = function(self)
		local numServices = GetNumTrainerServices()
		local db = ModernSpellBook_DB
		self:ForgetRecipes()

		-- Spell IDs of the rows, and whether some spell is of your class (pet
		-- trainers and weapon masters have none)
		local found = {}
		local isClassTrainer = false
		for i = 1, numServices do
			local name, rank, serviceType = GetTrainerServiceInfo(i)
			if (name and serviceType ~= "header") then
				local spellID = self:FindSpellID(name, rank)
				if (spellID) then
					found[i] = spellID
					local _, skillID = C_SpellBook.GetSpellSkillLine(spellID)
					if (MSB_IsClassSkill(skillID)) then isClassTrainer = true end
				end
			end
		end
		if (not isClassTrainer) then return end

		-- Merged with earlier visits: costs change with reputation, and
		-- another trainer can list other spells
		local newCount = 0
		for i, spellID in pairs(found) do
			if (db.trainer[spellID] == nil) then newCount = newCount + 1 end
			db.trainer[spellID] = GetTrainerServiceCost(i)
			-- The level is saved only when it differs from the expected one
			local level = GetTrainerServiceLevelReq(i)
			if (level and level > 0 and level ~= self:BaseLevel(spellID)) then
				db.trainerLevel[spellID] = level
			else
				db.trainerLevel[spellID] = nil
			end
			db.trainerNeeds[spellID] = self:ReadRequiredSpell(i, spellID)
		end

		if (newCount > 0) then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ModernSpellBook:|r " .. string.format(MSB_L.TRAINER_CAPTURED, newCount))
		end

		-- Rebuilt even while the book is closed, so the next opening is current
		MSB_SpellBook:DrawPage()
	end;

	-- A spell the trainer requires first other than the lower rank
	-- (Greater Blessing of Kings needs Blessing of Kings)
	ReadRequiredSpell = function(self, index, spellID)
		local ownName = C_Spell.GetSpellName(spellID)
		for r = 1, GetTrainerServiceNumAbilityReq(index) do
			local ability = GetTrainerServiceAbilityReq(index, r)
			if (ability) then
				local name, rank = SplitAbility(ability)
				if (name ~= ownName) then
					local required = self:FindSpellID(name, rank) or self:FindSpellID(ability, "")
					if (required) then return required end
				end
			end
		end
		return nil
	end;

	-- ================= UNLEARNED SPELLS =======================

	-- Highest rank in the spellbook of each spell name
	GetKnownRanks = function(self)
		local ranks = {}
		local bank = Enum.SpellBookSpellBank.Player
		for tab = 1, C_SpellBook.GetNumSpellBookSkillLines() do
			local line = C_SpellBook.GetSpellBookSkillLineInfo(tab)
			for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
				local info = C_SpellBook.GetSpellBookItemInfo(slot, bank)
				if (info) then
					local rankNum = MSB_RankNumber(info.subName)
					if (not ranks[info.name] or rankNum > ranks[info.name]) then ranks[info.name] = rankNum end
				end
			end
		end
		return ranks
	end;

	-- Names of the talents you have no point in (set by name)
	GetUnlearnedTalentSpells = function(self)
		local names = {}
		for t = 1, GetNumTalentTabs() do
			for i = 1, GetNumTalents(t) do
				local nameTalent, _, _, _, currRank = GetTalentInfo(t, i)
				if (nameTalent and currRank == 0) then
					local spellID = GetTalentSpellID(t, i, 1)
					names[(spellID and C_Spell.GetSpellName(spellID)) or nameTalent] = true
				end
			end
		end
		return names
	end;

	-- Names of every talent (set by name)
	GetTalentSpellNames = function(self)
		local names = {}
		for t = 1, GetNumTalentTabs() do
			for i = 1, GetNumTalents(t) do
				local nameTalent = GetTalentInfo(t, i)
				if (nameTalent) then
					local spellID = GetTalentSpellID(t, i, 1)
					names[(spellID and C_Spell.GetSpellName(spellID)) or nameTalent] = true
				end
			end
		end
		return names
	end;

	-- Forgets the result of GetUnlearnedSpells (the spell lists changed)
	Invalidate = function(self)
		self.unlearnedCache = nil
	end;

	-- Unlearned trainer, quest and book spells and talents, by section.
	-- Cached until Invalidate: every tab and the counter read it.
	GetUnlearnedSpells = function(self)
		if (self.unlearnedCache) then return self.unlearnedCache end

		local db = ModernSpellBook_DB
		self:ForgetRecipes()
		local knownRanks = self:GetKnownRanks()
		local unlearnedTalents = self:GetUnlearnedTalentSpells()
		local talentNames = self:GetTalentSpellNames()
		local byCategory, unlearnedNames = {}, {}

		local function Add(spellID, isTrainerSpell)
			if (IsSpellKnown(spellID) or IsPlayerSpell(spellID)) then return end
			local name, rank, rankNum = MSB_SpellNameRank(spellID)
			if (not name) then return end
			-- Skips ranks at or below one you know
			local highest = knownRanks[name]
			if (highest and (rankNum <= highest or highest == 0)) then return end

			-- Profession recipes (rogue poisons) are not spellbook spells
			if (MSB_IsRecipeSpell(spellID)) then return end

			local _, tabName, skillID = MSB_SpellTab(spellID)
			local category = tabName or MSB_GeneralSection(skillID)
			-- General abilities (Parry, Plate Mail, Dual Wield, ...) are passives
			local isGeneral = MSB_SpellSources:GetGeneralLevel(spellID) ~= nil
			local isPassive = C_Spell.IsSpellPassive(spellID) or isGeneral
			local level = db.trainerLevel[spellID] or self:BaseLevel(spellID) or 0
			local needs = MSB_SpellSources:GetNeeds(spellID)
			local needsName = needs and C_Spell.GetSpellName(needs)
			-- Trainers teach a rank only after the one before it: the rank still missing
			local lowerRank = isTrainerSpell and rankNum > 1 and (highest or 0) < rankNum - 1 and (rankNum - 1) or nil

			if (rank == "" and isPassive) then rank = MSB_STR.PASSIVE end
			byCategory[category] = byCategory[category] or {}
			table.insert(byCategory[category], {
				spellName = name,
				spellRank = rank,
				spellIcon = C_Spell.GetSpellTexture(spellID),
				spellID = spellID,
				cost = db.trainer[spellID],
				isPassive = isPassive,
				isUnlearned = true,
				isTrainerSpell = isTrainerSpell,
				-- A rank of a talent ability (Mortal Strike rank 2), named like
				-- the talent's spell, as ClassicAPI tags the learned ranks
				isTalentAbility = talentNames[name] or nil,
				-- A rank of a talent you have no point in ("Show talents" off hides
				-- it; ranks of a talent you have stay)
				talentUnlearned = unlearnedTalents[name] or nil,
				-- Needs a talent you have no point in (directly or through the required spell)
				talentBlocked = (unlearnedTalents[name] or (needsName and unlearnedTalents[needsName])) and true or false,
				needs = needs,
				lowerRank = lowerRank,
				needsMet = (not needs or IsSpellKnown(needs) or IsPlayerSpell(needs)) and not lowerRank,
				levelReq = (level > 0) and level or nil,
				category = category,
			})
			unlearnedNames[name] = true
		end

		for spellID in pairs(db.trainer) do Add(spellID, true) end
		-- General abilities show without a trainer visit: trainers list them
		-- only a few levels before their level
		MSB_SpellSources:ForEachGeneralSpell(function(spellID)
			if (not db.trainer[spellID]) then Add(spellID, true) end
		end)
		MSB_SpellSources:ForEachSourceSpell(function(spellID)
			if (not db.trainer[spellID]) then Add(spellID, false) end
		end)

		-- Unlearned talents that are single-rank or have trainer ranks show
		-- as "Talent" spells, without a trainer visit
		for t = 1, GetNumTalentTabs() do
			local treeName = GetTalentTabInfo(t)
			for i = 1, GetNumTalents(t) do
				local nameTalent, icon, tier, _, currRank, maxRank = GetTalentInfo(t, i)
				local spellID = GetTalentSpellID(t, i, 1)
				local spellName = (spellID and C_Spell.GetSpellName(spellID)) or nameTalent
				if (nameTalent and currRank == 0 and not knownRanks[spellName]
					and (unlearnedNames[spellName] or maxRank == 1)) then
					local _, tabName = MSB_SpellTab(spellID)
					local category = tabName or treeName
					byCategory[category] = byCategory[category] or {}
					table.insert(byCategory[category], {
						spellName = spellName,
						spellRank = MSB_L.TALENT,
						spellIcon = icon,
						spellID = spellID,
						-- Passive talents get the round icon, like learned ones
						isPassive = (spellID and C_Spell.IsSpellPassive(spellID)) and true or nil,
						isTalent = true,
						talentGrid = { t, i },
						isUnlearned = true,
						levelReq = 10 + (tier - 1) * 5,
						category = category,
					})
				end
			end
		end

		-- Each spell's ranks together, ordered by the level of its first rank
		for _, spells in pairs(byCategory) do
			local groupMinLevel = {}
			for _, sp in ipairs(spells) do
				local lvl = sp.levelReq or 0
				if (not groupMinLevel[sp.spellName] or lvl < groupMinLevel[sp.spellName]) then
					groupMinLevel[sp.spellName] = lvl
				end
			end
			table.sort(spells, function(a, b)
				local aGroupLvl, bGroupLvl = groupMinLevel[a.spellName], groupMinLevel[b.spellName]
				if (aGroupLvl ~= bGroupLvl) then return aGroupLvl < bGroupLvl end
				if (a.spellName ~= b.spellName) then return a.spellName < b.spellName end
				if ((a.levelReq or 0) ~= (b.levelReq or 0)) then return (a.levelReq or 0) < (b.levelReq or 0) end
				return a.spellID < b.spellID
			end)
		end

		self.unlearnedCache = byCategory
		return byCategory
	end;
}

MSB_TrainerDataService = MSB_CTrainerDataService()
