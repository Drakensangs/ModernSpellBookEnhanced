-- Settings: defaults, saved data upkeep, and the cog button with its
-- dropdown menu (the game's UIDropDownMenu). Options live in ModernSpellBook_DB.

-- Every setting's default. Applied at login to missing or mistyped keys
-- (tables key by key) and by /msb reset.
MSB_DEFAULTS = {
	showPassives = true,
	showSpellCounter = true,
	showTalents = true,
	rememberPage = true,
	showUnlearned = true,
	showUpcoming = true,
	showContinuationHeaders = true,
	lockPositionAndScale = false,
	classColoredBookmark = false,
	highlightUnplaced = false,
	isMinimized = false,
	fontSize = 11.5,
	textColorMode = "light",
	highlights = { learnedGlow = true, learnedBadge = true, availableGlow = true, availableBadge = true },
	iconFrame = { spells = true, other = true, unlearned = false },
}

-- Saved spell data, keyed by spell ID:
--   trainer[id]      training cost of each spell a class trainer listed
--   trainerLevel[id] trainer's level, only where it differs from ClassicAPI's
--   trainerNeeds[id] spell the trainer requires first (not the lower rank)
--   newSpells[id]    true while a learned spell is "New"
--   trainSeen[id]    true once a trainable spell was hovered (no more "Train" cue)
MSB_SPELL_TABLES = { "trainer", "trainerLevel", "trainerNeeds", "newSpells", "trainSeen" }

-- Keeps number keys with number or true values
local function CleanSpellTable(t)
	for key, value in pairs(t) do
		if (type(key) ~= "number" or (type(value) ~= "number" and value ~= true)) then t[key] = nil end
	end
end

function MSB_ApplyDefaults(db)
	for key, value in pairs(MSB_DEFAULTS) do
		if (type(value) == "table") then
			if (type(db[key]) ~= "table") then db[key] = {} end
			for subKey, subValue in pairs(value) do
				if (type(db[key][subKey]) ~= type(subValue)) then db[key][subKey] = subValue end
			end
		elseif (type(db[key]) ~= type(value)) then
			db[key] = value
		end
	end
	for _, name in ipairs(MSB_SPELL_TABLES) do
		if (type(db[name]) ~= "table") then db[name] = {} end
		CleanSpellTable(db[name])
	end
end

-- Converts saved data of another version (5 and older): settings and the
-- window position are kept; the old name-keyed spell list becomes the
-- trainer costs and "New" marks by spell ID.
function MSB_MigrateDB(db)
	local old = db.spells
	local keep = { position = true, windowScale = true, lastTab = true, lastPage = true }
	for key in pairs(db) do
		if (MSB_DEFAULTS[key] == nil and not keep[key]) then db[key] = nil end
	end
	db.trainer, db.newSpells = {}, {}
	if (type(old) ~= "table") then return end
	for _, entry in pairs(old) do
		if (type(entry) == "table" and type(entry.spellID) == "number" and C_Spell.DoesSpellExist(entry.spellID)) then
			if (type(entry.cost) == "number") then db.trainer[entry.spellID] = entry.cost end
			if (entry.learned and entry.seen_new == false) then db.newSpells[entry.spellID] = true end
		end
	end
end

MSB_class "MSB_CSettingsMenu"
{
	__init = function(self, parent, onSettingChanged)
		self.on_setting_changed = onSettingChanged

		-- Cog button on the stone strip. Its art has a 3 px margin at 24x24,
		-- left out of the click area.
		local COG = "Interface\\AddOns\\ModernSpellBook\\Assets\\Frame\\settings-cog"
		self.button = CreateFrame("Button", nil, parent)
		self.button:SetWidth(MSB_LAYOUT.cogSize)
		self.button:SetHeight(MSB_LAYOUT.cogSize)
		self.button:SetHitRectInsets(MSB_LAYOUT.cogMargin, MSB_LAYOUT.cogMargin, MSB_LAYOUT.cogMargin, MSB_LAYOUT.cogMargin)
		self.button:SetPoint("RIGHT", ModernSpellBookFrame.searchBar.frame, "LEFT", -MSB_LAYOUT.cogGap, 0)
		self.button:SetNormalTexture(COG)
		-- Hover glow
		self.button:SetHighlightTexture(COG .. "-highlight")
		self.button:GetHighlightTexture():SetBlendMode("ADD")
		-- Pressed: the cog sinks 1 px and darkens
		self.button:SetPushedTexture(COG)
		local pushed = self.button:GetPushedTexture()
		pushed:ClearAllPoints()
		pushed:SetPoint("TOPLEFT", self.button, "TOPLEFT", 1, -1)
		pushed:SetPoint("BOTTOMRIGHT", self.button, "BOTTOMRIGHT", 1, -1)
		pushed:SetVertexColor(0.75, 0.75, 0.75)
		-- The hover glow sinks with it
		local cogButton = self.button
		local highlight = self.button:GetHighlightTexture()
		local function SetHighlightPressed(pressed)
			local offset = pressed and 1 or 0
			highlight:ClearAllPoints()
			highlight:SetPoint("TOPLEFT", cogButton, "TOPLEFT", offset, -offset)
			highlight:SetPoint("BOTTOMRIGHT", cogButton, "BOTTOMRIGHT", offset, -offset)
		end
		self.button:SetScript("OnMouseDown", function() SetHighlightPressed(true) end)
		self.button:SetScript("OnMouseUp", function() SetHighlightPressed(false) end)
		self.button:SetScript("OnHide", function() SetHighlightPressed(false) end)

		-- Only the dropdown's menu is used; the box stays hidden
		self.dropdown = CreateFrame("Frame", "ModernSpellBookSettingsDropDown", parent, "UIDropDownMenuTemplate")

		-- Filled in on opening; 1.12.1 calls initialize(level)
		local settingsMenu = self
		self.dropdown.initialize = function(level) settingsMenu:InitializeDropdown(level) end
		self.dropdown.displayMode = "MENU"
		self.dropdown:Hide()

		-- Moves this menu's submenus 10 px away from the main menu, right after
		-- the game places them (a delayed move would flicker)
		local dropdown = self.dropdown
		local SUBMENU_NUDGE = 10
		hooksecurefunc("ToggleDropDownMenu", function(level)
			if (not level or level < 2 or not settingsMenu:IsMenuOpen()) then return end
			local list = getglobal("DropDownList" .. level)
			if not list or not list:IsShown() then return end
			local point, anchor, relPoint, x, y = list:GetPoint(1)
			if not point or not anchor then return end
			-- Opened to the left near the screen edge: move left instead
			local nudge = string.find(point, "RIGHT") and -SUBMENU_NUDGE or SUBMENU_NUDGE
			list:ClearAllPoints()
			list:SetPoint(point, anchor, relPoint, (x or 0) + nudge, y or 0)
		end)

		self.button:SetScript("OnClick", function()
			PlaySound(MSB_SOUND.CHECKBOX_ON)
			ToggleDropDownMenu(1, nil, dropdown, settingsMenu.button, MSB_LAYOUT.cogMargin, MSB_LAYOUT.cogMargin)
		end)

		-- Closing the spellbook closes the menu
		parent:HookScript("OnHide", function()
			if (settingsMenu:IsMenuOpen()) then CloseDropDownMenus() end
		end)

		ModernSpellBookFrame.settingsButton = self.button
	end;

	-- 1.12.1 keeps the open menu's frame name in UIDROPDOWNMENU_OPEN_MENU
	IsMenuOpen = function(self)
		return UIDROPDOWNMENU_OPEN_MENU == self.dropdown:GetName()
	end;

	-- =================== DROPDOWN ================================

	InitializeDropdown = function(self, level)
		level = level or 1
		local info
		local onChanged = self.on_setting_changed

		if (level == 1) then
			-- Show passive spells
			info = {}
			info.text = MSB_L.SHOW_PASSIVES
			info.checked = ModernSpellBook_DB.showPassives
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.showPassives = not ModernSpellBook_DB.showPassives
				onChanged()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Remember page
			info = {}
			info.text = MSB_L.REMEMBER_PAGE
			info.checked = ModernSpellBook_DB.rememberPage
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.rememberPage = not ModernSpellBook_DB.rememberPage
			end
			UIDropDownMenu_AddButton(info, level)

			-- Spell counter
			info = {}
			info.text = MSB_L.SPELL_COUNTER
			info.checked = ModernSpellBook_DB.showSpellCounter
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.showSpellCounter = not ModernSpellBook_DB.showSpellCounter
				MSB_SpellDataService:UpdateSpellCounter()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Show talents (unlearned ones only with "Show unlearned" on).
			-- Off, it hides passive and unlearned talents; learned active
			-- talents and their trainer ranks stay (MSB_IsHiddenTalentSpell).
			-- onChanged redraws the page and the upcoming spells row.
			info = {}
			info.text = MSB_L.SHOW_TALENTS
			info.checked = ModernSpellBook_DB.showTalents
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.showTalents = not ModernSpellBook_DB.showTalents
				onChanged()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Show unlearned spells
			info = {}
			info.text = MSB_L.SHOW_UNLEARNED
			info.checked = ModernSpellBook_DB.showUnlearned
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.showUnlearned = not ModernSpellBook_DB.showUnlearned
				onChanged()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Show upcoming spells
			info = {}
			info.text = MSB_L.SHOW_UPCOMING
			info.checked = ModernSpellBook_DB.showUpcoming
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.showUpcoming = not ModernSpellBook_DB.showUpcoming
				MSB_SpellBook:UpdateUpcomingSpells()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Continuation headers
			info = {}
			info.text = MSB_L.CONTINUATION_HEADERS
			info.checked = ModernSpellBook_DB.showContinuationHeaders
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.showContinuationHeaders = not ModernSpellBook_DB.showContinuationHeaders
				onChanged()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Lock position & scale
			info = {}
			info.text = MSB_L.LOCK_POSITION
			info.checked = ModernSpellBook_DB.lockPositionAndScale
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.lockPositionAndScale = not ModernSpellBook_DB.lockPositionAndScale
				MSB_SpellBook:UpdateLockVisuals()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Class-colored bookmark
			info = {}
			info.text = MSB_L.CLASS_BOOKMARK
			info.checked = ModernSpellBook_DB.classColoredBookmark
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.classColoredBookmark = not ModernSpellBook_DB.classColoredBookmark
				MSB_SpellBook:UpdateBookmarkTexture()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Pulse on spells that aren't on any action bar
			info = {}
			info.text = MSB_L.HIGHLIGHT_UNPLACED
			info.checked = ModernSpellBook_DB.highlightUnplaced
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.highlightUnplaced = not ModernSpellBook_DB.highlightUnplaced
				MSB_ActionBarHelper:InvalidatePlacedSpells()
				MSB_SpellBook:UpdateUnplacedHighlights()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Highlights submenu
			info = {}
			info.text = MSB_L.HIGHLIGHTS
			info.hasArrow = 1
			info.notCheckable = 1
			info.value = "highlights"
			UIDropDownMenu_AddButton(info, level)

			-- Font size submenu
			info = {}
			info.text = MSB_L.FONT_SIZE
			info.hasArrow = 1
			info.notCheckable = 1
			info.value = "fontSize"
			UIDropDownMenu_AddButton(info, level)

			-- Spell text color submenu
			info = {}
			info.text = MSB_L.TEXT_COLOR
			info.hasArrow = 1
			info.notCheckable = 1
			info.value = "textColor"
			UIDropDownMenu_AddButton(info, level)

			-- Icon frame submenu
			info = {}
			info.text = MSB_L.ICON_FRAME
			info.hasArrow = 1
			info.notCheckable = 1
			info.value = "iconFrame"
			UIDropDownMenu_AddButton(info, level)

			info = {}
			info.text = MSB_L.RESET_POSITION
			info.notCheckable = 1
			info.func = function()
				ModernSpellBook_DB.position = nil
				ModernSpellBook_DB.windowScale = nil
				MSB_SpellBook:RestorePosition()
				CloseDropDownMenus()
			end
			UIDropDownMenu_AddButton(info, level)

		elseif (level == 2) then
			if (UIDROPDOWNMENU_MENU_VALUE == "textColor") then
				info = {}
				info.text = MSB_L.TEXT_COLOR_LIGHT
				info.checked = ModernSpellBook_DB.textColorMode ~= "dark"
				info.func = function()
					ModernSpellBook_DB.textColorMode = "light"
					onChanged()
					CloseDropDownMenus()
				end
				UIDropDownMenu_AddButton(info, level)

				info = {}
				info.text = MSB_L.TEXT_COLOR_DARK
				info.checked = ModernSpellBook_DB.textColorMode == "dark"
				info.func = function()
					ModernSpellBook_DB.textColorMode = "dark"
					onChanged()
					CloseDropDownMenus()
				end
				UIDropDownMenu_AddButton(info, level)

			elseif (UIDROPDOWNMENU_MENU_VALUE == "fontSize") then
				local sizes = {9, 10, 10.5, 11, 11.5, 12, 13}
				for _, size in ipairs(sizes) do
					local fontSize = size
					info = {}
					info.text = tostring(size)
					info.value = size
					info.checked = (ModernSpellBook_DB.fontSize == size)
					info.func = function()
						ModernSpellBook_DB.fontSize = fontSize
						onChanged()
						CloseDropDownMenus()
					end
					UIDropDownMenu_AddButton(info, level)
				end

			elseif (UIDROPDOWNMENU_MENU_VALUE == "highlights") then
				info = {}
				info.text = MSB_L.LEARNED_GLOW
				info.checked = ModernSpellBook_DB.highlights.learnedGlow
				info.keepShownOnClick = 1
				info.func = function()
					ModernSpellBook_DB.highlights.learnedGlow = not ModernSpellBook_DB.highlights.learnedGlow
					onChanged()
				end
				UIDropDownMenu_AddButton(info, level)

				info = {}
				info.text = MSB_L.LEARNED_BADGE
				info.checked = ModernSpellBook_DB.highlights.learnedBadge
				info.keepShownOnClick = 1
				info.func = function()
					ModernSpellBook_DB.highlights.learnedBadge = not ModernSpellBook_DB.highlights.learnedBadge
					onChanged()
				end
				UIDropDownMenu_AddButton(info, level)

				info = {}
				info.text = MSB_L.AVAILABLE_GLOW
				info.checked = ModernSpellBook_DB.highlights.availableGlow
				info.keepShownOnClick = 1
				info.func = function()
					ModernSpellBook_DB.highlights.availableGlow = not ModernSpellBook_DB.highlights.availableGlow
					onChanged()
				end
				UIDropDownMenu_AddButton(info, level)

				info = {}
				info.text = MSB_L.AVAILABLE_BADGE
				info.checked = ModernSpellBook_DB.highlights.availableBadge
				info.keepShownOnClick = 1
				info.func = function()
					ModernSpellBook_DB.highlights.availableBadge = not ModernSpellBook_DB.highlights.availableBadge
					onChanged()
				end
				UIDropDownMenu_AddButton(info, level)

			elseif (UIDROPDOWNMENU_MENU_VALUE == "iconFrame") then
				info = {}
				info.text = MSB_L.ICON_FRAME_SPELLS
				info.checked = ModernSpellBook_DB.iconFrame.spells
				info.keepShownOnClick = 1
				info.func = function()
					ModernSpellBook_DB.iconFrame.spells = not ModernSpellBook_DB.iconFrame.spells
					onChanged()
				end
				UIDropDownMenu_AddButton(info, level)

				info = {}
				info.text = MSB_L.ICON_FRAME_OTHER
				info.checked = ModernSpellBook_DB.iconFrame.other
				info.keepShownOnClick = 1
				info.func = function()
					ModernSpellBook_DB.iconFrame.other = not ModernSpellBook_DB.iconFrame.other
					onChanged()
				end
				UIDropDownMenu_AddButton(info, level)

				info = {}
				info.text = MSB_L.ICON_FRAME_UNLEARNED
				info.checked = ModernSpellBook_DB.iconFrame.unlearned
				info.keepShownOnClick = 1
				info.func = function()
					ModernSpellBook_DB.iconFrame.unlearned = not ModernSpellBook_DB.iconFrame.unlearned
					onChanged()
				end
				UIDropDownMenu_AddButton(info, level)
			end
		end
	end;
}