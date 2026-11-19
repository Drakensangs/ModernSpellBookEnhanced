-- Collects each tab's spells from the player and pet spellbooks, merges in
-- talents and unlearned spells, then filters and sorts them for the pages.

-- Turtle WoW's extra spellbook tabs, shown together on the "Other" tab
local otherTabNames = { Companions = true, Mounts = true, Toys = true }

local PLAYER_BANK, PET_BANK = Enum.SpellBookSpellBank.Player, Enum.SpellBookSpellBank.Pet

-- Calls func(name, slot offset, spell count, icon) for each spellbook tab, in order
local function ForEachSpellTab(func)
	for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
		func(line.name, line.itemIndexOffset, line.numSpellBookItems, line.iconID)
	end
end

local function SortByNameAndRank(a, b)
	if (a.spellName ~= b.spellName) then
		return a.spellName < b.spellName
	end
	return MSB_RankNumber(a.spellRank) < MSB_RankNumber(b.spellRank)
end

-- Current slot and book type of a spell, nil when it's gone. Slots shift
-- when a spell is learned: the saved slot is tried first, then the ID.
function MSB_ResolveSpellSlot(spellInfo)
	local slot, bookType = spellInfo.slot, spellInfo.bookType
	if (not slot) then return nil end
	local info = C_SpellBook.GetSpellBookItemInfo(slot, MSB_BANK[bookType])
	if (info and info.spellID == spellInfo.spellID) then return slot, bookType end
	return FindSpellBookSlotByID(spellInfo.spellID)
end

-- Key of a spell in ModernSpellBook_DB.newSpells: talents use their first
-- rank's spell ID, so every rank of a talent shares one "New" mark
function MSB_NewKey(spellInfo)
	return spellInfo.newKey or spellInfo.spellID
end

-- Spells hidden while "Show talents" is off: learned passive talents,
-- unlearned talents (active or passive) and the trainer ranks of talents you
-- have no point in. Learned active talent abilities stay, and so do the
-- unlearned trainer ranks of a talent you have (Consecration rank 1 and
-- rank 2, once you took Consecration).
function MSB_IsHiddenTalentSpell(spellInfo)
	-- Talent entries: learned passive talents without a book button and
	-- unlearned talents
	if (spellInfo.isTalent) then return true end
	if (spellInfo.isTalentAbility) then
		-- Passive talent spells in the book
		if (spellInfo.isPassive) then return true end
		-- Trainer ranks of a talent you have no point in
		if (spellInfo.isUnlearned and spellInfo.talentUnlearned) then return true end
	end
	return false
end

function MSB_IsNewSpell(spellInfo)
	local key = MSB_NewKey(spellInfo)
	return key ~= nil and not spellInfo.isUnlearned and ModernSpellBook_DB.newSpells[key] == true
end

MSB_class "MSB_CSpellDataService"
{
	__init = function(self)
		-- LEARNED_SPELL_IN_SKILL_LINE names each spell the game teaches: it is
		-- marked "New". MSB_TalentService covers talents without a button.
		self.frame = CreateFrame("Frame")
		self.frame:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
		self.frame:SetScript("OnEvent", function()
			if (arg1 and ModernSpellBook_DB) then ModernSpellBook_DB.newSpells[arg1] = true end
		end)
	end;

	-- ====================== SEARCH ===============================

	-- Lower-case text a search is matched against, built once per spell list
	GetSearchText = function(self, spellInfo)
		if (spellInfo.searchText) then return spellInfo.searchText end
		local text = spellInfo.spellName .. ";" .. (spellInfo.spellRank or "") .. ";" .. (spellInfo.category or "") .. ";"
		if (spellInfo.isTalent or spellInfo.isTalentAbility) then
			text = text .. MSB_L.TALENT .. ";"
		end
		if (not spellInfo.isTalent and spellInfo.spellID) then
			text = text .. (C_Spell.GetSpellDescription(spellInfo.spellID) or "") .. ";"
		end
		spellInfo.searchText = MSB_Lower(text)
		return spellInfo.searchText
	end;

	-- allSpells: { [section] = { spellInfo, ... } } of one tab. Every word
	-- must match; the word "New" also finds the spells marked "New".
	FilterSpells = function(self, filterString, allSpells)
		local keywords = {}
		local newWord = MSB_Lower(MSB_STR.NEW)
		-- Plain-text matching, so ( [ . - are searched literally
		for keyword in string.gfind(MSB_Lower(filterString or ""), "([^,; ]+)") do
			table.insert(keywords, keyword)
		end
		if (table.getn(keywords) == 0) then return allSpells end

		local filteredSpells = {}
		for category, spellList in pairs(allSpells) do
			for _, spellInfo in ipairs(spellList) do
				local isNew = MSB_IsNewSpell(spellInfo)
				local searchText = self:GetSearchText(spellInfo)
				local isMatch = true
				for _, keyword in ipairs(keywords) do
					if (not (isNew and keyword == newWord) and not string.find(searchText, keyword, 1, true)) then
						isMatch = false
						break
					end
				end
				if (isMatch) then
					filteredSpells[category] = filteredSpells[category] or {}
					table.insert(filteredSpells[category], spellInfo)
				end
			end
		end
		return filteredSpells
	end;

	-- ====================== RANKS ================================

	-- Stores on each learned, castable rank of a spell the list of its learned
	-- ranks (lowest first) as learnedRanks. Only spells with 2+ numbered
	-- ranks get one, and with it the rank arrow.
	AttachLearnedRanks = function(self, spellList)
		local groups = {}
		for _, spellInfo in ipairs(spellList) do
			if (not spellInfo.isUnlearned and not spellInfo.isPassive and not spellInfo.isTalent
				and not spellInfo.isPetSpell and spellInfo.slot) then
				local rankNum = MSB_RankNumber(spellInfo.spellRank)
				if (rankNum > 0) then
					local name = spellInfo.spellName
					if (not groups[name]) then groups[name] = { seen = {}, list = {} } end
					if (not groups[name].seen[rankNum]) then
						groups[name].seen[rankNum] = true
						spellInfo.rankNum = rankNum
						table.insert(groups[name].list, spellInfo)
					end
				end
			end
		end

		for _, group in pairs(groups) do
			local list = group.list
			if (table.getn(list) > 1) then
				table.sort(list, function(a, b) return a.rankNum < b.rankNum end)
				for _, spellInfo in ipairs(list) do
					spellInfo.learnedRanks = list
				end
			end
		end
	end;

	-- Keeps the highest learned rank of each spell and the next rank still to
	-- learn (the lowest one, for spells you don't know yet)
	FilterHighestRanks = function(self, spellList)
		local function RankOf(rankText)
			if (rankText == MSB_L.TALENT) then return 1 end
			return MSB_RankNumber(rankText)
		end

		local highestLearnedRank = {}
		for _, spellInfo in ipairs(spellList) do
			if (not spellInfo.isUnlearned) then
				local name = spellInfo.spellName
				local rankNum = RankOf(spellInfo.spellRank)
				if (not highestLearnedRank[name] or rankNum > highestLearnedRank[name]) then
					highestLearnedRank[name] = rankNum
				end
			end
		end

		local nextUnlearnedRank = {}
		for _, spellInfo in ipairs(spellList) do
			if (spellInfo.isUnlearned) then
				local name = spellInfo.spellName
				local rankNum = RankOf(spellInfo.spellRank)
				if (rankNum > (highestLearnedRank[name] or 0)) then
					if (not nextUnlearnedRank[name] or rankNum < nextUnlearnedRank[name]) then
						nextUnlearnedRank[name] = rankNum
					end
				end
			end
		end

		local filtered = {}
		for _, spellInfo in ipairs(spellList) do
			local name = spellInfo.spellName
			local rankNum = RankOf(spellInfo.spellRank)
			if (spellInfo.isUnlearned) then
				if (nextUnlearnedRank[name] and rankNum == nextUnlearnedRank[name]) then
					table.insert(filtered, spellInfo)
				elseif (not highestLearnedRank[name] and rankNum == 0) then
					table.insert(filtered, spellInfo)
				end
			elseif (rankNum == 0 or rankNum >= (highestLearnedRank[name] or 0)) then
				table.insert(filtered, spellInfo)
			end
		end
		return filtered
	end;

	-- =================== SPELL COLLECTION ========================

	SpellInfoFromSpellBookItem = function(self, tabName, slot)
		local info = C_SpellBook.GetSpellBookItemInfo(slot, PLAYER_BANK)
		if (not info) then return nil end
		local spellRank = info.subName
		if (info.isPassive and spellRank == "") then spellRank = MSB_STR.PASSIVE end
		return {
			spellName = info.name,
			spellRank = spellRank,
			bookRank = info.subName,
			spellIcon = MSB_SpellBookIcon(slot, info),
			slot = slot,
			bookType = BOOKTYPE_SPELL,
			spellID = info.spellID,
			category = tabName,
			isPassive = info.isPassive,
			isTalentAbility = C_SpellBook.IsClassTalentSpellBookItem(slot, PLAYER_BANK) or nil,
			stanceIndex = ModernSpellBookFrame.unlockedStances[info.name],
		}
	end;

	GetPetSpells = function(self)
		local petName = UnitName("pet")
		if (not petName) then return {} end

		local active, passive = {}, {}
		for slot = 1, (HasPetSpells() or 0) do
			local info = C_SpellBook.GetSpellBookItemInfo(slot, PET_BANK)
			if (not info) then break end
			local canAutocast = GetSpellAutocast(slot, BOOKTYPE_PET)
			local spellInfo = {
				spellName = info.name,
				spellRank = info.subName,
				bookRank = info.subName,
				spellIcon = info.iconID,
				slot = slot,
				bookType = BOOKTYPE_PET,
				spellID = info.spellID,
				isPassive = info.isPassive,
				isPetSpell = true,
				-- Right-click toggles autocast, as in the default pet book
				canAutocast = canAutocast and true or false,
				category = petName,
			}
			table.insert(spellInfo.isPassive and passive or active, spellInfo)
		end

		if (ModernSpellBook_DB.showPassives) then
			for _, spellInfo in ipairs(passive) do
				table.insert(active, spellInfo)
			end
		end
		local petSpells = {}
		petSpells[petName] = active
		return petSpells
	end;

	-- Stances, forms, auras and stealth: name -> form index
	ReadStances = function(self)
		local stances = {}
		for i = 1, GetNumShapeshiftForms() do
			local texture, name = GetShapeshiftFormInfo(i)
			if (texture and name) then stances[name] = i end
		end
		ModernSpellBookFrame.unlockedStances = stances
	end;

	-- Spells of the class tab (showGeneralTab false) or the General tab, with
	-- passives, talents and unlearned spells merged in. Profession spells
	-- (Poisons, Beast Training, ...) go to the General tab's Professions
	-- section, whichever tab the game puts them in.
	GetPlayerSpells = function(self, showGeneralTab)
		local allSpellsDict = {}
		local passiveSpellsDict = {}
		local canShowPassives = ModernSpellBook_DB.showPassives
		local canShowTalents = ModernSpellBook_DB.showTalents
		self:ReadStances()

		local service = self
		ForEachSpellTab(function(tabName, offset, numSpells)
			if (otherTabNames[tabName]) then return end
			local isGeneralTab = (tabName == MSB_STR.GENERAL)
			for slot = offset + 1, offset + numSpells do
				local spellInfo = service:SpellInfoFromSpellBookItem(tabName, slot)
				if (spellInfo) then
					local category = tabName
					if (MSB_IsProfessionSpell(spellInfo.spellID)) then category = MSB_STR.PROFESSIONS end
					local inGeneral = isGeneralTab or category == MSB_STR.PROFESSIONS
					if (inGeneral == (showGeneralTab and true or false)) then
						spellInfo.category = category
						-- Passive talents are left out with "Show talents" off;
						-- the tab still gets its section
						if (canShowTalents or not MSB_IsHiddenTalentSpell(spellInfo)) then
							local dict = spellInfo.isPassive and passiveSpellsDict or allSpellsDict
							dict[category] = dict[category] or {}
							table.insert(dict[category], spellInfo)
						end
						allSpellsDict[category] = allSpellsDict[category] or {}
					end
				end
			end
		end)

		if (canShowPassives) then
			for category, passiveSpells in pairs(passiveSpellsDict) do
				for _, spellInfo in ipairs(passiveSpells) do
					table.insert(allSpellsDict[category], spellInfo)
				end
			end
		end

		if (not showGeneralTab) then
			self:MergeTalents(allSpellsDict, canShowPassives)
		end

		-- Known spells by name and rank; unlearned ones follow, by level
		for _, spells in pairs(allSpellsDict) do
			self:SortSpells(spells)
		end
		self:MergeUnlearnedSpells(allSpellsDict, showGeneralTab)
		for category, spells in pairs(allSpellsDict) do
			self:AttachLearnedRanks(spells)
			allSpellsDict[category] = self:FilterHighestRanks(spells)
		end
		return allSpellsDict
	end;

	SortSpells = function(self, spells)
		table.sort(spells, SortByNameAndRank)
	end;

	-- Learned talents without a book button (passive talents) join their
	-- tab as passives, unless "Show talents" is off. Talents with a button
	-- are already in the book, tagged by ClassicAPI as talent abilities.
	MergeTalents = function(self, allSpellsDict, canShowPassives)
		if (not canShowPassives or not ModernSpellBook_DB.showTalents) then return end
		for t = 1, GetNumTalentTabs() do
			local treeName = GetTalentTabInfo(t)
			for i = 1, GetNumTalents(t) do
				local nameTalent, icon, _, _, currRank = GetTalentInfo(t, i)
				local spellID = nameTalent and currRank > 0 and GetTalentSpellID(t, i, currRank)
				if (spellID and not IsSpellKnown(spellID)) then
					local _, tabName = MSB_SpellTab(spellID)
					local category = tabName or treeName
					allSpellsDict[category] = allSpellsDict[category] or {}
					table.insert(allSpellsDict[category], {
						spellName = nameTalent,
						spellIcon = icon,
						spellRank = MSB_STR.PASSIVE,
						spellID = spellID,
						newKey = GetTalentSpellID(t, i, 1),
						isPassive = true,
						isTalent = true,
						talentGrid = { t, i },
						category = category,
					})
				end
			end
		end
	end;

	-- Turtle WoW's Companions, Mounts and Toys tabs, one section each
	GetOtherTabSpells = function(self)
		local spellsDict = {}
		local canShowPassives = ModernSpellBook_DB.showPassives
		local service = self
		ForEachSpellTab(function(tabName, offset, numSpells)
			if (not otherTabNames[tabName] or numSpells == 0) then return end
			local active, passive = {}, {}
			for slot = offset + 1, offset + numSpells do
				local spellInfo = service:SpellInfoFromSpellBookItem(tabName, slot)
				if (spellInfo) then
					table.insert(spellInfo.isPassive and passive or active, spellInfo)
				end
			end
			if (canShowPassives) then
				for _, spellInfo in ipairs(passive) do table.insert(active, spellInfo) end
			end
			if (table.getn(active) > 0) then
				service:SortSpells(active)
				spellsDict[tabName] = active
			end
		end)
		return spellsDict
	end;

	HasOtherTabSpells = function(self)
		local found = false
		ForEachSpellTab(function(tabName, offset, numSpells)
			if (otherTabNames[tabName] and numSpells > 0) then found = true end
		end)
		return found
	end;

	-- Spells of a tab by section, and whether they are pet spells
	GetAvailableSpells = function(self, tab)
		if (tab == MSB_TAB_CLASS) then
			return self:GetPlayerSpells(false), false
		elseif (tab == MSB_TAB_GENERAL) then
			return self:GetPlayerSpells(true), false
		elseif (tab == MSB_TAB_PET) then
			return self:GetPetSpells(), true
		elseif (tab == MSB_TAB_OTHER) then
			return self:GetOtherTabSpells(), false
		end
		return {}, false
	end;

	-- Unlearned General and Professions spells go to the General tab, the rest to the class tab
	MergeUnlearnedSpells = function(self, allSpellsDict, showGeneralTab)
		if (not ModernSpellBook_DB.showUnlearned) then return end
		local canShowPassives = ModernSpellBook_DB.showPassives
		local canShowTalents = ModernSpellBook_DB.showTalents
		for category, spells in pairs(MSB_TrainerDataService:GetUnlearnedSpells()) do
			local isGeneral = (category == MSB_STR.GENERAL or category == MSB_STR.PROFESSIONS)
			if (showGeneralTab == isGeneral) then
				allSpellsDict[category] = allSpellsDict[category] or {}
				for _, spellInfo in ipairs(spells) do
					if ((not spellInfo.isPassive or canShowPassives)
						and (canShowTalents or not MSB_IsHiddenTalentSpell(spellInfo))) then
						table.insert(allSpellsDict[category], spellInfo)
					end
				end
			end
		end
	end;

	-- ===================== NEW SPELLS ============================

	-- Hovering a new spell clears the mark on it and its other ranks.
	-- Returns true when other ranks had one (the page then redraws).
	MarkSeen = function(self, spellInfo)
		local newSpells = ModernSpellBook_DB.newSpells
		newSpells[MSB_NewKey(spellInfo)] = nil
		local hadOtherRanks = false
		for spellID in pairs(newSpells) do
			if (C_Spell.GetSpellName(spellID) == spellInfo.spellName) then
				newSpells[spellID] = nil
				hadOtherRanks = true
			end
		end
		return hadOtherRanks
	end;

	-- Drops "New" marks of spells you no longer know (after a talent reset).
	-- A talent's mark, keyed by its rank 1, stays while it has a point.
	PruneNewSpells = function(self)
		local talentRanks = MSB_TalentService.ranks or {}
		for spellID in pairs(ModernSpellBook_DB.newSpells) do
			if (not IsSpellKnown(spellID) and not IsPlayerSpell(spellID) and (talentRanks[spellID] or 0) == 0) then
				ModernSpellBook_DB.newSpells[spellID] = nil
			end
		end
	end;

	-- =================== UPCOMING SPELLS =========================

	-- Trainer spells of the next level that brings any, sorted by name.
	-- Spells that need a talent you haven't learned stay out of the row, and
	-- so do the talents "Show talents" hides while off.
	GetUpcomingSpells = function(self)
		local playerLevel = UnitLevel("player")
		local canShowTalents = ModernSpellBook_DB.showTalents
		local candidates = {}
		local nextLevel = nil
		for _, spells in pairs(MSB_TrainerDataService:GetUnlearnedSpells()) do
			for _, spellInfo in ipairs(spells) do
				local lvl = spellInfo.levelReq
				if (spellInfo.isTrainerSpell and not spellInfo.talentBlocked and lvl and lvl > playerLevel
					and (canShowTalents or not MSB_IsHiddenTalentSpell(spellInfo))) then
					table.insert(candidates, spellInfo)
					if (not nextLevel or lvl < nextLevel) then nextLevel = lvl end
				end
			end
		end
		local upcoming = {}
		for _, spellInfo in ipairs(candidates) do
			if (spellInfo.levelReq == nextLevel) then table.insert(upcoming, spellInfo) end
		end
		table.sort(upcoming, SortByNameAndRank)
		return upcoming, nextLevel
	end;

	-- "x/y learned" at the bottom left: spellbook spells plus learned talents
	-- without a button, against those plus the unlearned spells. A
	-- single-rank talent is in the unlearned list until learned, so it
	-- counts as learned afterwards. Turtle WoW's extra tabs don't count.
	UpdateSpellCounter = function(self)
		local counter = ModernSpellBookFrame.spellCounter
		if (not ModernSpellBook_DB.showSpellCounter) then
			counter:Hide()
			return
		end

		local learned = 0
		ForEachSpellTab(function(tabName, offset, numSpells)
			if (not otherTabNames[tabName]) then learned = learned + numSpells end
		end)
		for t = 1, GetNumTalentTabs() do
			for i = 1, GetNumTalents(t) do
				local nameTalent, _, _, _, currRank, maxRank = GetTalentInfo(t, i)
				local spellID = nameTalent and currRank > 0 and maxRank == 1 and GetTalentSpellID(t, i, 1)
				if (spellID and not IsSpellKnown(spellID)) then learned = learned + 1 end
			end
		end

		local unlearned = 0
		for _, spells in pairs(MSB_TrainerDataService:GetUnlearnedSpells()) do
			unlearned = unlearned + table.getn(spells)
		end

		if (not MSB_TrainerDataService:HasTrainerData()) then
			counter:SetText(string.format(MSB_L.COUNTER_LEARNED_UNKNOWN, learned))
		elseif (unlearned > 0) then
			counter:SetText(string.format(MSB_L.COUNTER_LEARNED_OF, learned, learned + unlearned))
		else
			counter:SetText(string.format(MSB_L.COUNTER_LEARNED, learned))
		end
		counter:Show()
	end;
}

MSB_SpellDataService = MSB_CSpellDataService()
