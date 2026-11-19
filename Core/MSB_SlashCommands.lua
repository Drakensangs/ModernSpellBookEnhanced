-- Slash commands:
--   /msb          open or close the spellbook
--   /msb reset    settings back to defaults (saved spell data is kept)
--   /msb rescan   forget the trainer lists; read again on the next visit

local function Print(text)
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ModernSpellBook:|r " .. text)
end

local function ResetSettings()
	local old = ModernSpellBook_DB
	ModernSpellBook_DB = { dbVersion = old.dbVersion }
	for _, name in ipairs(MSB_SPELL_TABLES) do
		ModernSpellBook_DB[name] = old[name]
	end
	MSB_ApplyDefaults(ModernSpellBook_DB)
	MSB_SpellBook:ApplySettings()
	Print(MSB_L.SETTINGS_RESET)
end

local function ClearTrainerCache()
	if (not MSB_TrainerDataService:HasTrainerData()) then
		Print(MSB_L.NO_TRAINER_DATA)
		return
	end
	ModernSpellBook_DB.trainer = {}
	ModernSpellBook_DB.trainerLevel = {}
	ModernSpellBook_DB.trainerNeeds = {}
	MSB_SpellBook:DrawPage()
	Print(MSB_L.TRAINER_DATA_CLEARED)
end

SLASH_MODERNSPELLBOOK1 = "/msb"
SlashCmdList["MODERNSPELLBOOK"] = function(msg)
	local cmd = string.lower(string.gsub(string.gsub(msg or "", "^%s+", ""), "%s+$", ""))
	if (cmd == "") then
		MSB_SpellBook:Toggle(false)
	elseif (cmd == "reset") then
		ResetSettings()
	elseif (cmd == "rescan") then
		ClearTrainerCache()
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ModernSpellBook|r " .. MSB_L.COMMANDS)
		DEFAULT_CHAT_FRAME:AddMessage("  /msb - " .. MSB_L.CMD_TOGGLE)
		DEFAULT_CHAT_FRAME:AddMessage("  /msb reset - " .. MSB_L.CMD_RESET)
		DEFAULT_CHAT_FRAME:AddMessage("  /msb rescan - " .. MSB_L.CMD_RESCAN)
	end
end
