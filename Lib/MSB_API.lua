-- Shared helpers and data over the 1.12.1 client and ClassicAPI.

-- Game strings in the client's language. The addon's own text is in MSB_L.
MSB_STR = {
	NEW = NEW,
	SPELLBOOK = SPELLBOOK,
	PASSIVE = SPELL_PASSIVE,
	GENERAL = GENERAL,
	RANK = RANK,
	PROFESSIONS = TRADE_SKILLS,
	LEVEL_SHORT = LEVEL_ABBR,				-- "Lvl"
	REQUIRES_LEVEL = ITEM_MIN_LEVEL,		-- "Requires Level %d"
	REQUIRES = ITEM_REQ_SKILL,				-- "Requires %s"
}

-- C_Timer.After swallows errors in its callbacks; this reports them.
function MSB_After(seconds, callback)
	C_Timer.After(seconds, function()
		local ok, err = pcall(callback)
		if (not ok) then geterrorhandler()(err) end
	end)
end

-- 1.12.1 sound names ("Abiliity" is the game's own spelling)
MSB_SOUND = {
	CHECKBOX_ON = "igMainMenuOptionCheckBoxOn",
	PAGE_TURN = "igAbiliityPageTurn",
	SPELLBOOK_OPEN = "igSpellBookOpen",
	SPELLBOOK_CLOSE = "igSpellBookClose",
	PETBOOK_OPEN = "igAbilityOpen",
	PETBOOK_CLOSE = "igAbilityClose",
}

function MSB_GetFont()
	return STANDARD_TEXT_FONT
end

-- Spell bank of a book type
MSB_BANK = {
	[BOOKTYPE_SPELL] = Enum.SpellBookSpellBank.Player,
	[BOOKTYPE_PET] = Enum.SpellBookSpellBank.Pet,
}

-- Skill lines shown in the Professions section of the General tab
MSB_PROFESSION_SKILLS = {
	[129] = true,	-- First Aid
	[40] = true,	-- Poisons (rogue)
	[142] = true,	-- Survival (Basic Campfire)
	[164] = true,	-- Blacksmithing
	[165] = true,	-- Leatherworking
	[171] = true,	-- Alchemy
	[182] = true,	-- Herbalism
	[185] = true,	-- Cooking
	[186] = true,	-- Mining
	[197] = true,	-- Tailoring
	[202] = true,	-- Engineering
	[261] = true,	-- Beast Training (hunter)
	[333] = true,	-- Enchanting
	[356] = true,	-- Fishing
	[393] = true,	-- Skinning
	[633] = true,	-- Lockpicking
	[755] = true,	-- Jewelcrafting (Turtle WoW only)
}

-- Skill lines whose class trainer rows are profession recipes (rogue
-- poisons, Blinding Powder). Recipes have no spellbook button, so the addon
-- never reads, saves or shows them.
MSB_RECIPE_SKILLS = {
	[40] = true,	-- Poisons (rogue)
}

-- The Poisons spell itself is a spellbook spell (it opens the Poisons window)
MSB_POISONS_SPELL = 2842

function MSB_IsRecipeSpell(spellID)
	if (spellID == MSB_POISONS_SPELL) then return false end
	local _, skillID = C_SpellBook.GetSpellSkillLine(spellID)
	return skillID and MSB_RECIPE_SKILLS[skillID] or false
end

function MSB_IsProfessionSpell(spellID)
	local _, skillID = C_SpellBook.GetSpellSkillLine(spellID)
	return skillID and MSB_PROFESSION_SKILLS[skillID] or false
end

-- Icon of a player spellbook slot. Attack shows the main hand weapon, as on
-- the action bars.
function MSB_SpellBookIcon(slot, info)
	if (IsAttackSpell(slot, BOOKTYPE_SPELL)) then
		local weapon = GetInventoryItemTexture("player", GetInventorySlotInfo("MainHandSlot"))
		if (weapon) then return weapon end
	end
	return info.iconID
end

-- The number in a rank text ("Rank 3" -> 3), 0 when there is none. Cached:
-- sorts call it for every comparison, and there are few distinct rank texts.
local rankNumbers = {}
function MSB_RankNumber(rankText)
	if (not rankText or rankText == "") then return 0 end
	local number = rankNumbers[rankText]
	if (not number) then
		local _, _, digits = string.find(rankText, "(%d+)")
		number = tonumber(digits) or 0
		rankNumbers[rankText] = number
	end
	return number
end

-- Name, rank text and rank number of a spell ID
function MSB_SpellNameRank(spellID)
	local name = C_Spell.GetSpellName(spellID)
	local rank = C_Spell.GetSpellSubtext(spellID) or ""
	return name, rank, MSB_RankNumber(rank)
end

-- Lower case for searching. string.lower only knows ASCII, so the UTF-8
-- capitals of the Latin-1 range (À..Þ, not ×) and Œ are folded here too.
local function LowerLatin1(c)
	return "\195" .. string.char(string.byte(c) + 32)
end
function MSB_Lower(text)
	text = string.gsub(string.lower(text), "\195([\128-\150\152-\158])", LowerLatin1)
	return (string.gsub(text, "\197\146", "\197\147"))
end

-- Skill lines of each class's spellbook tabs (SkillLine.dbc), in tab order
MSB_CLASS_SKILL_ORDER = {
	WARRIOR = { 26, 256, 257 },		-- Arms, Fury, Protection
	PALADIN = { 594, 267, 184 },	-- Holy, Protection, Retribution
	HUNTER = { 50, 163, 51 },		-- Beast Mastery, Marksmanship, Survival
	ROGUE = { 253, 38, 39 },		-- Assassination, Combat, Subtlety
	PRIEST = { 613, 56, 78 },		-- Discipline, Holy, Shadow Magic
	SHAMAN = { 375, 373, 374 },		-- Elemental Combat, Enhancement, Restoration
	MAGE = { 237, 8, 6 },			-- Arcane, Fire, Frost
	WARLOCK = { 355, 354, 593 },	-- Affliction, Demonology, Destruction
	DRUID = { 574, 134, 573 },		-- Balance, Feral Combat, Restoration
}
MSB_CLASS_SKILLS = {}
for class, order in pairs(MSB_CLASS_SKILL_ORDER) do
	MSB_CLASS_SKILLS[class] = {}
	for _, skillID in ipairs(order) do MSB_CLASS_SKILLS[class][skillID] = true end
end

function MSB_IsClassSkill(skillID)
	local skills = MSB_CLASS_SKILLS[UnitClassBase("player")]
	return skillID and skills and skills[skillID] or false
end

-- Spellbook tab icon of each class skill line: the SpellIconID of its
-- SkillLine.dbc row, which the default spellbook shows on the tab. The game
-- reports a tab's icon only once you have the tab (a spell of that school),
-- and ClassicAPI has no lookup by skill line, so these icons are listed here,
-- by skill line ID so they hold in every language.
local ICONS = "Interface\\Icons\\"
MSB_SKILL_LINE_ICONS = {
	[26] = ICONS .. "Ability_Rogue_Eviscerate",			-- Arms
	[256] = ICONS .. "Ability_Warrior_InnerRage",		-- Fury
	[257] = ICONS .. "Ability_Warrior_DefensiveStance",	-- Protection (warrior)
	[594] = ICONS .. "Spell_Holy_HolyBolt",				-- Holy (paladin)
	[267] = ICONS .. "Spell_Holy_DevotionAura",			-- Protection (paladin)
	[184] = ICONS .. "Spell_Holy_AuraOfLight",			-- Retribution
	[50] = ICONS .. "Ability_Hunter_BeastTaming",		-- Beast Mastery
	[163] = ICONS .. "Ability_Marksmanship",			-- Marksmanship
	[51] = ICONS .. "Ability_Hunter_SwiftStrike",		-- Survival
	[253] = ICONS .. "Ability_Rogue_Eviscerate",		-- Assassination
	[38] = ICONS .. "Ability_BackStab",					-- Combat
	[39] = ICONS .. "Ability_Stealth",					-- Subtlety
	[613] = ICONS .. "Spell_Holy_WordFortitude",		-- Discipline
	[56] = ICONS .. "Spell_Holy_HolyBolt",				-- Holy (priest)
	[78] = ICONS .. "Spell_Shadow_ShadowWordPain",		-- Shadow Magic
	[375] = ICONS .. "Spell_Nature_Lightning",			-- Elemental Combat
	[373] = ICONS .. "Spell_Nature_LightningShield",	-- Enhancement
	[374] = ICONS .. "Spell_Nature_MagicImmunity",		-- Restoration (shaman)
	[237] = ICONS .. "Spell_Holy_MagicalSentry",		-- Arcane
	[8] = ICONS .. "Spell_Fire_FireBolt02",				-- Fire
	[6] = ICONS .. "Spell_Frost_FrostBolt02",			-- Frost
	[355] = ICONS .. "Spell_Shadow_DeathCoil",			-- Affliction
	[354] = ICONS .. "Spell_Shadow_Metamorphosis",		-- Demonology
	[593] = ICONS .. "Spell_Shadow_RainOfFire",			-- Destruction
	[574] = ICONS .. "Spell_Nature_StarFall",			-- Balance
	[134] = ICONS .. "Ability_Racial_BearForm",			-- Feral Combat
	[573] = ICONS .. "Spell_Nature_HealingTouch",		-- Restoration (druid)
}

-- Tab icon of one of your class's sections, by its name, also before you
-- have the tab; nil for other sections
function MSB_ClassSectionIcon(sectionName)
	for _, skillID in ipairs(MSB_CLASS_SKILL_ORDER[UnitClassBase("player")] or {}) do
		if (C_SpellBook.GetSkillLineName(skillID) == sectionName) then
			return MSB_SKILL_LINE_ICONS[skillID]
		end
	end
	return nil
end

-- Sort position of each section name: the class tabs in the game's order
-- (by skill line, spellbook tab and talent tree name, so every locale
-- agrees), then General, then Professions. Other sections sort after these.
function MSB_SectionOrder()
	local order = {}
	local skills = MSB_CLASS_SKILL_ORDER[UnitClassBase("player")] or {}
	for i, skillID in ipairs(skills) do
		local name = C_SpellBook.GetSkillLineName(skillID)
		if (name) then order[name] = i end
		local tab = C_SpellBook.GetSkillLineIndexByID(skillID)
		local info = tab and C_SpellBook.GetSpellBookSkillLineInfo(tab)
		if (info and not order[info.name]) then order[info.name] = i end
	end
	for t = 1, GetNumTalentTabs() do
		local treeName = GetTalentTabInfo(t)
		if (treeName and not order[treeName]) then order[treeName] = t end
	end
	order[MSB_STR.GENERAL] = 10
	order[MSB_STR.PROFESSIONS] = 11
	return order
end

-- Spellbook tab that holds (or would hold) a spell: index, name and skill
-- line. The game adds a class tab with its first spell, so a spell of a tab
-- you don't have yet gets the tab's name and no index. No name for spells
-- outside the class tabs (General, professions, ...).
function MSB_SpellTab(spellID)
	local skillName, skillID = C_SpellBook.GetSpellSkillLine(spellID)
	local tab = skillID and C_SpellBook.GetSkillLineIndexByID(skillID)
	if (tab) then
		local info = C_SpellBook.GetSpellBookSkillLineInfo(tab)
		return tab, info and info.name, skillID
	end
	if (MSB_IsClassSkill(skillID)) then return nil, skillName, skillID end
	return nil, nil, skillID
end

-- Book section of a spell outside the class tabs
function MSB_GeneralSection(skillID)
	if (skillID and MSB_PROFESSION_SKILLS[skillID]) then return MSB_STR.PROFESSIONS end
	return MSB_STR.GENERAL
end

-- Chat link of a talent: its current rank, or rank 1 when it has no points
function MSB_GetTalentLink(tab, index)
	local spellID = GetTalentSpellID(tab, index)
	return spellID and GetSpellLink(spellID)
end

-- Blanks the "Click to learn" line of talent tooltips (the book can't learn talents)
function MSB_StripLearnPromptFromTooltip()
	for i = 2, GameTooltip:NumLines() do
		local line = getglobal("GameTooltipTextLeft" .. i)
		if (line and line:GetText() == TOOLTIP_TALENT_LEARN) then
			line:SetText("")
		end
	end
end
