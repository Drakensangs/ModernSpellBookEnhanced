-- Per class, data the game can't be asked for (checked against VMaNGOS
-- 1.12.1). Names come from ClassicAPI, in the client's language.
--   quest[spellID]   questID, or { [raceMask] = questID or { questID, ... } }
--                    when races differ; a list holds every version of the
--                    quest, the race's usual one first
--   book[spellID]    itemID of the book that teaches it
--   needs[spellID]   spellID that must be known first (not the lower rank)
--   general[spellID] trainer level of a General tab passive (armor, Parry,
--                    Dual Wield); shown from level 1, since trainers list
--                    them only a few levels early
-- Profession recipes (poisons, Blinding Powder) are never listed.

-- Race bits, from UnitRaceBase's race ID (Human 1 ... Troll 8)
local HUMAN, ORC, DWARF, NIGHTELF, UNDEAD, TAUREN, GNOME, TROLL = 1, 2, 4, 8, 16, 32, 64, 128

local CLASS_SOURCES = {
	WARRIOR = {
		quest = {
			-- Defensive Stance, Taunt, Sunder Armor (Path of Defense)
			[71] = { [HUMAN] = 1665, [DWARF + GNOME] = 1678, [NIGHTELF] = 1683, [ORC + TAUREN + TROLL] = 1498, [UNDEAD] = 1819 },
			[355] = { [HUMAN] = 1665, [DWARF + GNOME] = 1678, [NIGHTELF] = 1683, [ORC + TAUREN + TROLL] = 1498, [UNDEAD] = 1819 },
			[7386] = { [HUMAN] = 1665, [DWARF + GNOME] = 1678, [NIGHTELF] = 1683, [ORC + TAUREN + TROLL] = 1498, [UNDEAD] = 1819 },
			[2458] = 1719,	-- Berserker Stance (The Affray)
			[20252] = 1719,	-- Intercept
		},
		book = { [25286] = 21297, [25288] = 21299, [25289] = 21298 },
		-- Parry, Dual Wield, Plate Mail
		general = { [3127] = 6, [674] = 20, [750] = 40 },
	},
	PALADIN = {
		quest = {
			[5502] = 1652,	-- Sense Undead
			[7328] = { [HUMAN] = 1788, [DWARF] = 1785 },	-- Redemption
			[13819] = 1661,	-- Summon Warhorse
			[23214] = 7647,	-- Summon Charger
		},
		book = { [25290] = 21288, [25291] = 21289, [25292] = 21290 },
		-- Parry, Plate Mail
		general = { [3127] = 8, [750] = 40 },
		needs = {
			[25782] = 19838,	-- Greater Blessing of Might: Blessing of Might 6
			[25916] = 25291,	-- Greater Blessing of Might 2: Blessing of Might 7
			[25894] = 19854,	-- Greater Blessing of Wisdom: Blessing of Wisdom 5
			[25918] = 25290,	-- Greater Blessing of Wisdom 2: Blessing of Wisdom 6
			[25890] = 19979,	-- Greater Blessing of Light: Blessing of Light 3
			[25895] = 1038,		-- Greater Blessing of Salvation: Blessing of Salvation
			[25898] = 20217,	-- Greater Blessing of Kings: Blessing of Kings (talent)
			[25899] = 20914,	-- Greater Blessing of Sanctuary: Blessing of Sanctuary 4
		},
	},
	HUNTER = {
		quest = {
			-- Taming the Beast: Tame Beast, Call Pet, Dismiss Pet
			[1515] = { [ORC + TROLL] = 6082, [DWARF] = 6085, [TAUREN] = 6088, [NIGHTELF] = 6102 },
			[883] = { [ORC + TROLL] = 6082, [DWARF] = 6085, [TAUREN] = 6088, [NIGHTELF] = 6102 },
			[2641] = { [ORC + TROLL] = 6082, [DWARF] = 6085, [TAUREN] = 6088, [NIGHTELF] = 6102 },
			-- Training the Beast: Feed Pet, Revive Pet, Beast Training
			[6991] = { [ORC + TROLL] = 6081, [DWARF] = 6086, [TAUREN] = 6089, [NIGHTELF] = 6103 },
			[982] = { [ORC + TROLL] = 6081, [DWARF] = 6086, [TAUREN] = 6089, [NIGHTELF] = 6103 },
			[5149] = { [ORC + TROLL] = 6081, [DWARF] = 6086, [TAUREN] = 6089, [NIGHTELF] = 6103 },
		},
		book = { [19801] = 16665, [25294] = 21304, [25295] = 21306, [25296] = 21307 },
		-- Parry, Dual Wield, Mail
		general = { [3127] = 8, [674] = 20, [8737] = 40 },
	},
	ROGUE = {
		quest = {
			-- Poisons (Klaven's Tower, Hinott's Assistance)
			[2842] = { [HUMAN + DWARF + NIGHTELF + GNOME] = 2359, [ORC + UNDEAD + TROLL] = 2480 },
		},
		book = { [25300] = 21300, [25302] = 21303, [31016] = 24102 },
		-- Dual Wield, Parry
		general = { [674] = 10, [3127] = 12 },
	},
	PRIEST = {
		quest = {
			[13896] = { [HUMAN] = { 5676, 5677, 5678 } },	-- Feedback
			[13908] = { [HUMAN + DWARF] = { 5634, 5635, 5636, 5637, 5638, 5639, 5640 } },	-- Desperate Prayer
			[6346] = { [DWARF] = { 5641, 5645, 5647 } },	-- Fear Ward
			[2651] = { [NIGHTELF] = { 5672, 5673, 5674, 5675 } },	-- Elune's Grace
			[10797] = { [NIGHTELF] = { 5627, 5628, 5629, 5630, 5631, 5632, 5633 } },	-- Starshards
			[2652] = { [UNDEAD] = { 5658, 5659, 5660, 5661, 5662, 5663 } },	-- Touch of Weakness
			[2944] = { [UNDEAD] = { 5644, 5646, 5679 } },	-- Devouring Plague
			[9035] = { [TROLL] = { 5652, 5654, 5655, 5656, 5657 } },	-- Hex of Weakness
			[18137] = { [TROLL] = { 5642, 5643, 5680 } },	-- Shadowguard
		},
		book = { [21562] = 17413, [21564] = 17414, [25314] = 21284, [25315] = 21285, [25316] = 21287, [27683] = 22393 },
		needs = {
			[27681] = 14752,	-- Prayer of Spirit: Divine Spirit (talent)
		},
	},
	SHAMAN = {
		quest = {
			[8071] = { [ORC + TROLL] = { 1518, 1521 }, [TAUREN] = { 1521, 1518 } },	-- Stoneskin Totem (Call of Earth)
			[3599] = 1527,	-- Searing Totem (Call of Fire)
			[5394] = 96,	-- Healing Stream Totem (Call of Water)
		},
		book = { [25357] = 21291, [25359] = 21293, [25361] = 21292, [29228] = 23320 },
		-- Mail
		general = { [8737] = 40 },
	},
	MAGE = {
		quest = {
			[10140] = 7463,	-- Conjure Water 7
			[28272] = 9364,	-- Polymorph: Pig
		},
		book = { [23028] = 18600, [25304] = 21214, [25306] = 21279, [25345] = 21280, [28271] = 22739, [28609] = 22890, [28612] = 22897 },
	},
	WARLOCK = {
		quest = {
			[688] = { [HUMAN] = { 1598, 1599 }, [GNOME] = { 1599, 1598 }, [ORC] = { 1485, 1470 }, [UNDEAD] = { 1470, 1485 } },	-- Summon Imp
			[697] = { [HUMAN + GNOME] = 1689, [ORC] = { 1504, 1471 }, [UNDEAD] = { 1471, 1504 } },	-- Summon Voidwalker
			[712] = { [HUMAN + GNOME] = 1739, [ORC] = { 1513, 1474 }, [UNDEAD] = { 1474, 1513 } },	-- Summon Succubus
			[691] = 1795,	-- Summon Felhunter
			[5784] = 4490,	-- Summon Felsteed
			[1122] = 7603,	-- Inferno
			[18540] = 7583,	-- Ritual of Doom
			[23161] = 7631,	-- Summon Dreadsteed
		},
		book = { [18540] = 4213, [25307] = 21281, [25309] = 21282, [25311] = 21283, [28610] = 22891 },
		-- Each stone needs the one before it
		needs = {
			[6202] = 6201, [5699] = 6202, [11729] = 5699, [11730] = 11729,
			[20752] = 693, [20755] = 20752, [20756] = 20755, [20757] = 20756,
			[17951] = 6366, [17952] = 17951, [17953] = 17952,
			[17727] = 2362, [17728] = 17727,
		},
	},
	DRUID = {
		quest = {
			[5487] = { [NIGHTELF] = 6001, [TAUREN] = 6002 },	-- Bear Form
			[6795] = { [NIGHTELF] = 6001, [TAUREN] = 6002 },	-- Growl
			[6807] = { [NIGHTELF] = 6001, [TAUREN] = 6002 },	-- Maul
			[8946] = { [NIGHTELF] = 6125, [TAUREN] = 6130 },	-- Cure Poison
			[1066] = { [NIGHTELF] = 5061, [TAUREN] = 31 },		-- Aquatic Form
		},
		book = { [21849] = 17682, [21850] = 17683, [25297] = 21294, [25298] = 21295, [25299] = 21296, [31018] = 24101 },
		needs = {
			[9634] = 5487,	-- Dire Bear Form: Bear Form
		},
	},
}

MSB_class "MSB_CSpellSources"
{
	__init = function(self)
		self.quest, self.book, self.needs, self.general = {}, {}, {}, {}
		local sources = self
		self.frame = CreateFrame("Frame")
		self.frame:RegisterEvent("PLAYER_LOGIN")
		self.frame:SetScript("OnEvent", function()
			if (event == "PLAYER_LOGIN") then
				sources:Load()
			elseif (arg2) then
				-- A quest title or item name arrived: refresh the tooltip asking for it
				sources:OnDataLoaded()
			end
		end)
	end;

	-- Keeps the player's class and race only; self.quest[spellID] is always
	-- a list of quest IDs. The full table is then freed.
	Load = function(self)
		local class = UnitClassBase("player")
		local _, raceID = UnitRaceBase("player")
		local raceBit = 2 ^ (raceID - 1)
		local data = class and CLASS_SOURCES[class] or {}
		for spellID, quest in pairs(data.quest or {}) do
			if (type(quest) == "table") then
				for mask, questIDs in pairs(quest) do
					if (math.mod(math.floor(mask / raceBit), 2) == 1) then
						self.quest[spellID] = (type(questIDs) == "table") and questIDs or { questIDs }
					end
				end
			else
				self.quest[spellID] = { quest }
			end
		end
		self.book = data.book or {}
		self.needs = data.needs or {}
		self.general = data.general or {}
		CLASS_SOURCES = nil
	end;

	-- ======================== QUERIES ============================

	-- Spell that must be known first, besides the lower rank. The trainer's
	-- list (read at each visit) comes first.
	GetNeeds = function(self, spellID)
		local fromTrainer = ModernSpellBook_DB.trainerNeeds[spellID]
		return fromTrainer or self.needs[spellID]
	end;

	-- Trainer level of a general ability of the player's class, else nil
	GetGeneralLevel = function(self, spellID)
		return self.general[spellID]
	end;

	-- Calls func(spellID) for every general ability of the player's class
	ForEachGeneralSpell = function(self, func)
		for spellID in pairs(self.general) do func(spellID) end
	end;

	-- Calls func(spellID) for every quest or book spell of the player
	ForEachSourceSpell = function(self, func)
		for spellID in pairs(self.quest) do func(spellID) end
		for spellID in pairs(self.book) do
			if (not self.quest[spellID]) then func(spellID) end
		end
	end;

	-- Asks the server for every quest title and book name once, so the
	-- tooltips have them when you hover
	Prefetch = function(self)
		if (self.prefetched) then return end
		self.prefetched = true
		for _, questIDs in pairs(self.quest) do
			local questID = questIDs[1]
			if (not C_QuestLog.GetTitleForQuestID(questID)) then C_QuestLog.RequestLoadQuestByID(questID) end
		end
		for _, itemID in pairs(self.book) do
			C_Item.GetItemNameByID(itemID)
		end
	end;

	-- Listens only while a tooltip waits for a title or name
	OnDataLoaded = function(self)
		local item = self.tooltipItem
		self.tooltipItem = nil
		self.frame:UnregisterEvent("QUEST_DATA_LOAD_RESULT")
		self.frame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
		if (item and item.frame:IsVisible() and GameTooltip:IsOwned(item.frame)) then
			item:OnEnter()
		end
	end;

	-- ======================== TOOLTIP ============================

	-- Where an unlearned spell comes from, in the colors of the other
	-- requirement lines: green when met, red when not, gold for hints.
	AddTooltipLines = function(self, tooltip, spellInfo, item)
		local spellID = spellInfo.spellID
		local missing = false

		local function AddRequired(name, rank, isMet)
			local text = (rank ~= "") and (name .. " (" .. rank .. ")") or name
			if (isMet) then
				tooltip:AddLine(string.format(MSB_STR.REQUIRES, text), 0.2, 1, 0.2)
			else
				tooltip:AddLine(string.format(MSB_STR.REQUIRES, text), 1, 0.2, 0.2)
			end
		end
		-- The rank before this one (never met: a met one isn't flagged)
		if (spellInfo.lowerRank) then
			AddRequired(spellInfo.spellName, MSB_STR.RANK .. " " .. spellInfo.lowerRank, false)
		end
		local needs = spellInfo.needs
		if (needs) then
			local name, rank = MSB_SpellNameRank(needs)
			if (name) then AddRequired(name, rank, IsSpellKnown(needs) or IsPlayerSpell(needs)) end
		end

		local questIDs = self.quest[spellID]
		if (questIDs) then
			-- The version in your quest log, else your race's usual one
			local questID, onQuest = questIDs[1], false
			for _, id in ipairs(questIDs) do
				if (C_QuestLog.IsOnQuest(id)) then
					questID, onQuest = id, true
					break
				end
			end
			local title = C_QuestLog.GetTitleForQuestID(questID)
			if (not title) then
				missing = true
				C_QuestLog.RequestLoadQuestByID(questID)
			end
			tooltip:AddLine(string.format(MSB_L.QUEST_REWARD, title or "..."), 1, 0.82, 0)
			if (onQuest) then tooltip:AddLine(MSB_L.QUEST_IN_LOG, 0.2, 1, 0.2) end
		end

		local itemID = self.book[spellID]
		if (itemID) then
			local itemName = C_Item.GetItemNameByID(itemID)
			if (not itemName) then missing = true end
			tooltip:AddLine(string.format(MSB_L.TAUGHT_BY, itemName or "..."), 1, 0.82, 0)
			if (C_Item.GetItemCount(itemID, true) > 0) then
				tooltip:AddLine(MSB_L.HAVE_BOOK, 0.2, 1, 0.2)
			end
		end

		if (missing) then
			self.frame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
			self.frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
			self.tooltipItem = item
		end
	end;
}

MSB_SpellSources = MSB_CSpellSources()
