-- MSB_CSpellBook: the addon's controller. Owns ModernSpellBookFrame (the
-- window, one and two page views, tabs, page layout, drawing, paging) and
-- its events. MSB_BlizzardBook puts it in place of the default spellbook.

local ASSETS = "Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\"

-- Version of ModernSpellBook_DB; data of another version is converted at login
local DB_VERSION = 6

-- Window scale limits (resize handle and saved scale)
local MIN_SCALE, MAX_SCALE = 0.5, 1.5

local windowSettings = {
	posy = 0,
	height = 560,
	width1 = 550,	-- one page
	width2 = 1058,	-- two pages
}

-- Tabs: class, General, pet, and "Other" (Turtle WoW's companions, mounts, toys)
MSB_TAB_CLASS, MSB_TAB_GENERAL, MSB_TAB_PET, MSB_TAB_OTHER = 1, 2, 3, 4
local CORE_TABS = 4

-- Search box width limits (it shrinks to fit beside the tabs)
local SEARCH_MAX_WIDTH = 200
local SEARCH_MIN_WIDTH = 100

-- Portrait ring art and the icon inside it (a little larger than the ring's
-- opening, so its edge tucks under the ring)
local PORTRAIT_ART_SIZE = 80
local PORTRAIT_ICON_SIZE = 48
local PORTRAIT_ICON = "Interface\\Spellbook\\Spellbook-Icon"
local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- Bookmark drawn at 64x256; the ribbon's centre is ~25 px from its left edge
local BOOKMARK_WIDTH = 64
local BOOKMARK_HEIGHT = 256
local BOOKMARK_BODY_CENTER = 25
-- One page view: half the ribbon shows left of the right border
local BOOKMARK_X_ONE_PAGE = 515

-- Classes with a class-colored bookmark (Assets\Spellbook\Bookmarks\bookmark-<class>.tga)
MSB_BookmarkClasses = {
	DRUID = true, HUNTER = true, MAGE = true, PALADIN = true, PRIEST = true,
	ROGUE = true, SHAMAN = true, WARLOCK = true, WARRIOR = true,
}


-- Bar frames the game draws above the book (XP bar parts in DIALOG strata,
-- pet and stance buttons): lowered while the book is open, then restored.
local OVERLAPPING_BAR_FRAMES = { "ExhaustionTick", "MainMenuBarOverlayFrame",
	"PetActionBarFrame", "ShapeshiftBarFrame" }
for i = 1, 10 do
	table.insert(OVERLAPPING_BAR_FRAMES, "PetActionButton" .. i)
	table.insert(OVERLAPPING_BAR_FRAMES, "ShapeshiftButton" .. i)
end
local STRATA_RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5,
	FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local loweredFrames = {}

local function LowerOverlappingBarFrames(book)
	local bookRank = STRATA_RANK[book:GetFrameStrata()] or STRATA_RANK.HIGH
	local bookLevel = book:GetFrameLevel()
	for _, name in ipairs(OVERLAPPING_BAR_FRAMES) do
		local f = getglobal(name)
		local strata = f and f:GetFrameStrata()
		local rank = STRATA_RANK[strata] or 0
		-- Above the book: a higher strata, or the book's strata at a higher level
		local above = f and (rank > bookRank or (rank == bookRank and f:GetFrameLevel() >= bookLevel))
		if (above and not loweredFrames[f]) then
			local level = f:GetFrameLevel()
			loweredFrames[f] = { strata = strata, level = level }
			f:SetFrameStrata("MEDIUM")
			-- Stays above the bar it sits on, now in the same strata
			local parent = f:GetParent()
			local parentLevel = parent and parent:GetFrameLevel() or 0
			f:SetFrameLevel(math.max(level, parentLevel + 2))
		end
	end
end

local function RestoreOverlappingBarFrames()
	for f, saved in pairs(loweredFrames) do
		-- Left alone if something else changed it meanwhile
		if (f:GetFrameStrata() == "MEDIUM") then
			f:SetFrameStrata(saved.strata)
			f:SetFrameLevel(saved.level)
		end
		loweredFrames[f] = nil
	end
end

MSB_class "MSB_CSpellBook"
{
	__init = function(self)
		self.models = {}
		self.spellLists = {}
		self.spellItems = {}
		self.categoryItems = {}

		local spellBook = self
		self.handlers = {
			ADDON_LOADED = function() spellBook:OnAddonLoaded() end,
			SPELLS_CHANGED = function() spellBook:OnSpellsChanged() end,
			SPELL_UPDATE_COOLDOWN = function() spellBook:UpdateCooldowns() end,
			PET_BAR_UPDATE_COOLDOWN = function() spellBook:UpdateCooldowns() end,
			UNIT_PET = function() if (arg1 == "player") then spellBook:OnSpellsChanged() end end,
			PLAYER_LEVEL_UP = function() spellBook:OnLevelUp() end,
			-- Attack shows the main hand weapon's icon
			PLAYER_EQUIPMENT_CHANGED = function() if (arg1 == GetInventorySlotInfo("MainHandSlot")) then spellBook:OnSpellsChanged() end end,
		}
		self.events = CreateFrame("Frame")
		for name in pairs(self.handlers) do self.events:RegisterEvent(name) end
		self.events:SetScript("OnEvent", function()
			local handler = spellBook.handlers[event]
			if (handler) then handler() end
		end)
	end;

	-- ========================= EVENTS ============================

	OnAddonLoaded = function(self)
		if (arg1 ~= "ModernSpellBook") then return end
		self.events:UnregisterEvent("ADDON_LOADED")

		if (type(ModernSpellBook_DB) ~= "table") then
			ModernSpellBook_DB = {}
		end
		local version = ModernSpellBook_DB.dbVersion
		if (version ~= DB_VERSION and next(ModernSpellBook_DB) ~= nil) then
			MSB_MigrateDB(ModernSpellBook_DB)
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ModernSpellBook:|r " .. string.format(MSB_L.DB_UPDATED, tostring(DB_VERSION)))
		end
		MSB_ApplyDefaults(ModernSpellBook_DB)
		ModernSpellBook_DB.dbVersion = DB_VERSION

		self:Setup()
	end;

	Setup = function(self)
		self.frame = CreateFrame("Frame", "ModernSpellBookFrame", UIParent)
		self.frame:Hide()
		self.frame:SetToplevel(true)
		self.frame.Tabgroups = {}
		self.frame.stanceButtons = {}
		self.frame.unlockedStances = {}

		local remember = ModernSpellBook_DB.rememberPage
		self.frame.bookTab = remember and ModernSpellBook_DB.lastTab or MSB_TAB_CLASS
		if (type(self.frame.bookTab) ~= "number" or self.frame.bookTab == MSB_TAB_PET or self.frame.bookTab > CORE_TABS) then
			self.frame.bookTab = MSB_TAB_CLASS
		end
		self.frame.selectedTab = self.frame.bookTab
		local lastPage = ModernSpellBook_DB.lastPage
		self.frame.currentPage = (remember and type(lastPage) == "number" and lastPage >= 1) and math.floor(lastPage) or 1
		self.frame.maxPages = 1

		local spellBook = self
		self.frame:SetScript("OnShow", function() spellBook:OnShow() end)
		self.frame:SetScript("OnHide", function() spellBook:OnHide() end)
		-- Escape closes the book
		table.insert(UISpecialFrames, "ModernSpellBookFrame")

		self:SetupFrame()
		self:RestorePosition()
		self:AddSearchBar()

		self.frame.tab1 = self:NewTab(UnitClass("player"))
		self.frame.tab2 = self:NewTab(MSB_STR.GENERAL)
		self.frame.tab3 = self:NewTab(MSB_L.TAB_PET)
		self.frame.tab4 = self:NewTab(MSB_L.TAB_OTHER)

		self:AddPageButtons()
		self:AddCloseButton()
		self:AddViewToggleButton()

		self.frame.settingsMenu = MSB_CSettingsMenu(self.frame, function() spellBook:DrawPage() end)
		self.frame.rankFlyout = MSB_CRankFlyout(self.frame)

		self:UpdateOptionalTabs()
		self:SetShape(ModernSpellBook_DB.isMinimized)
		self:PositionAllTabs()
		self:UpdateLockVisuals()
		MSB_BlizzardBook:Install(self)
		self.isSetUp = true
	end;

	-- SPELLS_CHANGED comes in bursts (learning, talents, pets): one rebuild
	-- 0.3 s after the first. A closed book rebuilds when it opens.
	OnSpellsChanged = function(self)
		if (not self.isSetUp) then return end
		self:MarkDirty()
		if (self.redrawQueued) then return end
		self.redrawQueued = true
		local spellBook = self
		MSB_After(0.3, function()
			spellBook.redrawQueued = false
			if (spellBook.frame:IsVisible()) then
				spellBook:UpdateOptionalTabs()
				spellBook:Apply()
			end
		end)
	end;

	-- Every trainable spell gets its "Train" cue back
	OnLevelUp = function(self)
		ModernSpellBook_DB.trainSeen = {}
		self:OnSpellsChanged()
	end;

	OnShow = function(self)
		local frame = self.frame
		PlaySound(frame.selectedTab == MSB_TAB_PET and MSB_SOUND.PETBOOK_OPEN or MSB_SOUND.SPELLBOOK_OPEN)
		LowerOverlappingBarFrames(frame)
		-- Empty action slots show while the book is open, as with the default one
		MultiActionBar_ShowAllGrids()
		UpdateMicroButtons()

		-- The upcoming spells row opens scrolled to the start
		frame.upcomingScrollOffset = 0

		MSB_SpellSources:Prefetch()
		MSB_WatchAuras(true)
		if (not self.integrationsDone) then
			self.integrationsDone = true
			if (MSB_SetupCliqueIntegration) then MSB_SetupCliqueIntegration(self) end
		end
		if (self.onShowCallbacks) then
			for _, callback in ipairs(self.onShowCallbacks) do callback() end
		end

		self:UpdateOptionalTabs()
		self:Apply()
	end;

	OnHide = function(self)
		local frame = self.frame
		PlaySound(frame.selectedTab == MSB_TAB_PET and MSB_SOUND.PETBOOK_CLOSE or MSB_SOUND.SPELLBOOK_CLOSE)
		RestoreOverlappingBarFrames()
		MultiActionBar_HideAllGrids()
		MSB_WatchAuras(false)
		self:StopResize()
		frame:StopMovingOrSizing()
		self.isMoving = false
		if (frame.searchBar) then frame.searchBar:ClearFocus() end
		if (GameTooltip:IsOwned(frame)) then GameTooltip:Hide() end
		UpdateMicroButtons()
	end;

	-- callback runs on every opening (Clique selects its default set)
	AddOnShowCallback = function(self, callback)
		self.onShowCallbacks = self.onShowCallbacks or {}
		table.insert(self.onShowCallbacks, callback)
	end;

	-- ===================== OPEN AND CLOSE ========================

	IsOpen = function(self)
		return self.frame ~= nil and self.frame:IsShown()
	end;

	-- pet: open on the pet tab. With "Remember page" off, each opening starts
	-- on the first page of the class tab.
	Open = function(self, pet)
		if (not self.isSetUp) then return end
		local frame = self.frame
		local tab = frame.bookTab or MSB_TAB_CLASS
		if (pet and self:HasPetTab()) then tab = MSB_TAB_PET end
		if (not frame:IsShown() and not ModernSpellBook_DB.rememberPage) then
			if (tab ~= MSB_TAB_PET) then tab = MSB_TAB_CLASS end
			frame.bookTab = MSB_TAB_CLASS
			frame.currentPage = 1
		end
		if (tab ~= frame.selectedTab) then frame.currentPage = 1 end
		frame.selectedTab = tab
		if (frame:IsShown()) then
			self:Apply()
		else
			frame:Show()
		end
	end;

	Close = function(self)
		if (self:IsOpen()) then self.frame:Hide() end
	end;

	-- As with the default book: the key of the open book closes it, the other
	-- key switches between the spell and pet tabs
	Toggle = function(self, pet)
		if (not self.isSetUp) then return end
		if (pet and not self:HasPetTab()) then return end
		local onPetTab = (self.frame.selectedTab == MSB_TAB_PET)
		if (self:IsOpen() and (pet and true or false) == onPetTab) then
			self:Close()
		elseif (self:IsOpen() or (CanOpenPanels() and not GetFullScreenFrame())) then
			-- Like the default book, not over the world map or game menu
			self:Open(pet)
		end
	end;

	-- ========================= SETUP =============================

	-- Default teal bookmark, or the class-colored one
	UpdateBookmarkTexture = function(self)
		if (not self.frame or not self.frame.bookmark) then return end
		local path = ASSETS .. "bookmark"
		if (ModernSpellBook_DB.classColoredBookmark) then
			local _, englishClass = UnitClass("player")
			if (englishClass and MSB_BookmarkClasses[englishClass]) then
				path = ASSETS .. "Bookmarks\\bookmark-" .. string.lower(englishClass)
			end
		end
		self.frame.bookmark:SetTexture(path)
		self:LayoutBookmark(ModernSpellBook_DB.isMinimized)
	end;

	-- Two pages: the ribbon hangs on the seam between the pages. One page:
	-- its left half shows, cut where the page ends.
	LayoutBookmark = function(self, isMinimized)
		local bookmark = self.frame and self.frame.bookmark
		if (not bookmark) then return end
		local x = isMinimized and BOOKMARK_X_ONE_PAGE or (MSB_LAYOUT.pageSplit - BOOKMARK_BODY_CENTER)
		local width = BOOKMARK_WIDTH
		if (isMinimized) then
			local clipRight = windowSettings.width1 + MSB_LAYOUT.pageRight
			width = math.max(1, math.min(BOOKMARK_WIDTH, clipRight - x))
		end
		bookmark:ClearAllPoints()
		bookmark:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, MSB_LAYOUT.pageTop - 3)
		bookmark:SetWidth(width)
		bookmark:SetHeight(BOOKMARK_HEIGHT)
		bookmark:SetTexCoord(0, width / BOOKMARK_WIDTH, 0, 1)
	end;

	UpdateLockVisuals = function(self)
		local locked = ModernSpellBook_DB.lockPositionAndScale
		self.frame:SetMovable(not locked)
		self.frame.resizeHandle:SetShown(not locked)
	end;

	-- Ends a resize and saves the scale and position
	StopResize = function(self)
		if (not self.isResizing) then return end
		self.isResizing = false
		self.frame.resizeHandle:SetScript("OnUpdate", nil)
		ModernSpellBook_DB.windowScale = self.frame:GetScale()
		self:SavePosition()
	end;

	AddSearchBar = function(self)
		local spellBook = self
		self.frame.searchBar = MSB_CSearchBar(
			self.frame,
			MSB_L.SEARCH_PLACEHOLDER,
			function() spellBook:RefreshPage() end
		)
		-- Right end of the tab strip, the settings cog to its left
		self.frame.searchBar:SetPoint("RIGHT", self.frame, "TOPRIGHT", -16, -self:GetStripMiddle())
	end;

	SetupFrame = function(self)
		local spellBook = self
		local frame = self.frame
		frame:EnableMouse(true)
		frame:SetMovable(true)
		frame:SetClampedToScreen(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", function()
			if (ModernSpellBook_DB.lockPositionAndScale) then return end
			spellBook.isMoving = true
			frame:StartMoving()
		end)
		frame:SetScript("OnDragStop", function()
			if (not spellBook.isMoving) then return end
			frame:StopMovingOrSizing()
			spellBook.isMoving = false
			spellBook:SavePosition()
		end)
		-- The mouse wheel turns pages
		frame:EnableMouseWheel(true)
		frame:SetScript("OnMouseWheel", function()
			spellBook:SetPage((frame.currentPage or 1) + ((arg1 > 0) and -1 or 1))
		end)
		frame:SetWidth(windowSettings.width2)
		frame:SetHeight(windowSettings.height)
		frame:SetFrameStrata("HIGH")
		frame:SetFrameLevel(50)

		-- Border, title bar and the strip behind the tabs
		self.chrome = MSB_CFrameChrome(frame)

		-- Resize handle in the bottom-right corner: dragging changes the scale
		local resizeHandle = CreateFrame("Button", nil, frame)
		resizeHandle:SetWidth(20)
		resizeHandle:SetHeight(20)
		resizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, MSB_LAYOUT.pageBottom + 2)
		resizeHandle:SetFrameLevel(frame:GetFrameLevel() + 10)
		resizeHandle:SetNormalTexture(ASSETS .. "resize-button")
		resizeHandle:SetHighlightTexture(ASSETS .. "resize-button")
		resizeHandle:GetHighlightTexture():SetBlendMode("ADD")
		resizeHandle:SetPushedTexture(ASSETS .. "resize-button")
		resizeHandle:GetPushedTexture():SetVertexColor(0.7, 0.7, 0.7)
		resizeHandle:SetScript("OnEnter", function()
			GameTooltip:SetOwner(resizeHandle, "ANCHOR_TOPLEFT")
			if (ModernSpellBook_DB.lockPositionAndScale) then
				GameTooltip:SetText(MSB_L.POSITION_LOCKED)
			else
				GameTooltip:SetText(MSB_L.DRAG_TO_RESIZE)
			end
			GameTooltip:Show()
		end)
		resizeHandle:SetScript("OnLeave", function() GameTooltip:Hide() end)
		resizeHandle:SetScript("OnMouseDown", function()
			if (ModernSpellBook_DB.lockPositionAndScale) then return end
			local startX, startY = GetCursorPosition()
			local startScale = frame:GetScale()
			-- The top-left corner stays in place while scaling
			local es = frame:GetEffectiveScale()
			local screenLeft, screenTop = frame:GetLeft() * es, frame:GetTop() * es
			spellBook.isResizing = true
			resizeHandle:SetScript("OnUpdate", function()
				-- The release can be missed (button let go off the window)
				if (not IsMouseButtonDown("LeftButton")) then
					spellBook:StopResize()
					return
				end
				local curX, curY = GetCursorPosition()
				local delta = ((curX - startX) + (startY - curY)) / 2
				frame:SetScale(math.max(MIN_SCALE, math.min(MAX_SCALE, startScale + delta / 500)))
				local nes = frame:GetEffectiveScale()
				frame:ClearAllPoints()
				frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", screenLeft / nes, screenTop / nes)
			end)
		end)
		resizeHandle:SetScript("OnMouseUp", function() spellBook:StopResize() end)
		frame.resizeHandle = resizeHandle

		-- Title, on the border frame so it draws above it
		frame.title = self.chrome.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		frame.title:SetPoint("CENTER", frame, "TOP", 0, MSB_LAYOUT.titleTextY)
		frame.title:SetText(MSB_STR.SPELLBOOK)

		-- Portrait: metal ring over the top-left corner around the game's
		-- spellbook icon, masked round. Art: left half ring, right half backing.
		local portrait = CreateFrame("Frame", nil, frame)
		portrait:SetWidth(PORTRAIT_ART_SIZE)
		portrait:SetHeight(PORTRAIT_ART_SIZE)
		portrait:SetPoint("CENTER", frame, "TOPLEFT", MSB_LAYOUT.portraitX, MSB_LAYOUT.portraitY)
		portrait:SetFrameLevel(frame:GetFrameLevel() + 5)

		local backing = portrait:CreateTexture(nil, "BACKGROUND")
		backing:SetAllPoints(portrait)
		backing:SetTexture(ASSETS .. "spellbook-portrait")
		backing:SetTexCoord(0.5, 1, 0, 1)

		local portraitIcon = portrait:CreateTexture(nil, "ARTWORK")
		portraitIcon:SetWidth(PORTRAIT_ICON_SIZE)
		portraitIcon:SetHeight(PORTRAIT_ICON_SIZE)
		portraitIcon:SetPoint("CENTER", portrait, "CENTER", 0, 0)
		portraitIcon:SetTexture(PORTRAIT_ICON)
		portraitIcon:SetMask(PORTRAIT_MASK)

		local ring = portrait:CreateTexture(nil, "OVERLAY")
		ring:SetAllPoints(portrait)
		ring:SetTexture(ASSETS .. "spellbook-portrait")
		ring:SetTexCoord(0, 0.5, 0, 1)

		-- Pages, anchored by SetShape for the current view
		frame.backgroundLeft = frame:CreateTexture(nil, "BORDER")
		frame.backgroundLeft:SetTexture(ASSETS .. "spellbook-page-1")
		frame.backgroundRight = frame:CreateTexture(nil, "BORDER")
		frame.backgroundRight:SetTexture(ASSETS .. "spellbook-page-2")

		-- Bookmark under the separator, placed by LayoutBookmark
		frame.bookmark = frame:CreateTexture(nil, "ARTWORK")
		self:UpdateBookmarkTexture()

		frame.noresultsText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		frame.noresultsText:SetPoint("CENTER", frame.backgroundLeft, "CENTER", 0, 0)
		frame.noResultsMessage = string.format(MSB_L.NO_RESULTS, MSB_STR.NEW, MSB_L.TALENT)
		frame.noresultsText:SetText(frame.noResultsMessage)
		frame.noresultsText:SetTextColor(0, 0, 0)
		frame.noresultsText:SetShadowOffset(0, 0)
		frame.noresultsText:Hide()

		-- Footer texts below the pages' bottom ornament; PositionFooterTexts
		-- places the trainer hint for the view
		frame.trainerHint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		frame.trainerHint:SetFont(MSB_GetFont(), 10)
		frame.trainerHint:SetTextColor(1, 1, 1)
		frame.trainerHint:Hide()

		frame.spellCounter = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		frame.spellCounter:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 60, MSB_LAYOUT.footerBottom)
		frame.spellCounter:SetFont(MSB_GetFont(), 10)
		frame.spellCounter:SetTextColor(1, 1, 1)

		self:CreateUpcomingRow()
	end;

	-- "New spells at X:" row at the top of the left page
	CreateUpcomingRow = function(self)
		local frame = self.frame
		local spellBook = self
		local ICON_SIZE, SPACING, VISIBLE, ARROW_SIZE = 24, 14, 5, 16

		local row = CreateFrame("Frame", nil, frame)
		row:SetHeight(ICON_SIZE)
		row:SetWidth(VISIBLE * ICON_SIZE + (VISIBLE - 1) * SPACING)
		row:SetPoint("TOPRIGHT", frame.backgroundLeft, "TOPRIGHT", -100, -24)
		frame.upcomingFrame = row

		frame.upcomingLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		frame.upcomingLabel:SetFont(MSB_GetFont(), 10)
		frame.upcomingLabel:SetTextColor(1, 1, 1)
		frame.upcomingLabel:SetPoint("BOTTOM", row, "TOP", 0, 6)
		frame.upcomingScrollOffset = 0

		frame.upcomingIcons = {}
		for i = 1, VISIBLE do
			local button = CreateFrame("Button", nil, row)
			button:SetWidth(ICON_SIZE)
			button:SetHeight(ICON_SIZE)
			button:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(i - 1) * (ICON_SIZE + SPACING), 0)
			button:Hide()

			local icon = MSB_CIcon(button, ICON_SIZE)
			icon.border:SetTexture(ASSETS .. "spell_border_gray")
			icon.border_frame:SetWidth(ICON_SIZE + 4)
			icon.border_frame:SetHeight(ICON_SIZE + 4)
			icon.socket:Hide()
			button.icon = icon

			-- The "New" glow, scaled down to this icon
			local ring = MSB_CreateGlow(button, 52, {1, 1, 1}, 5)
			ring:SetPoint("CENTER", icon.icon, "CENTER", 0, 0)
			ring:Show()

			button:SetScript("OnEnter", function()
				local spell = button.spell
				if (not spell) then return end
				GameTooltip:SetOwner(button, "ANCHOR_TOP")
				GameTooltip:SetSpellByID(spell.spellID, false, true)
				MSB_AddTrainingCostLine(GameTooltip, spell.cost)
				GameTooltip:Show()
			end)
			button:SetScript("OnLeave", function() GameTooltip:Hide() end)
			frame.upcomingIcons[i] = button
		end

		local function MakeArrow(direction, anchorPoint, relativePoint, x, step)
			local arrow = CreateFrame("Button", nil, row)
			arrow:SetWidth(ARROW_SIZE)
			arrow:SetHeight(ARROW_SIZE)
			arrow:SetPoint(anchorPoint, row, relativePoint, x, 0)
			local art = "Interface\\Buttons\\UI-SpellbookIcon-" .. direction .. "Page-"
			arrow:SetNormalTexture(art .. "Up")
			arrow:SetHighlightTexture(art .. "Down")
			arrow:SetPushedTexture(art .. "Down")
			arrow:SetDisabledTexture(art .. "Disabled")
			arrow:SetScript("OnClick", function()
				PlaySound(MSB_SOUND.PAGE_TURN)
				frame.upcomingScrollOffset = math.max(0, frame.upcomingScrollOffset + step)
				spellBook:UpdateUpcomingSpells()
			end)
			arrow:Hide()
			return arrow
		end
		frame.upcomingPrevArrow = MakeArrow("Prev", "RIGHT", "LEFT", -4, -1)
		frame.upcomingNextArrow = MakeArrow("Next", "LEFT", "RIGHT", 4, 1)
	end;

	-- "Page x / y" and the page arrows, bottom right
	AddPageButtons = function(self)
		local spellBook = self
		local frame = self.frame
		local function MakeArrow(direction, step)
			local arrow = CreateFrame("Button", nil, frame)
			arrow:SetWidth(25)
			arrow:SetHeight(25)
			local art = "Interface\\Buttons\\UI-SpellbookIcon-" .. direction .. "Page-"
			arrow:SetNormalTexture(art .. "Up")
			arrow:SetPushedTexture(art .. "Down")
			arrow:SetDisabledTexture(art .. "Disabled")
			arrow:SetHighlightTexture(art .. "Down")
			arrow:SetScript("OnClick", function()
				spellBook:SetPage((frame.currentPage or 1) + step)
			end)
			arrow:Hide()
			return arrow
		end
		frame.previousPage = MakeArrow("Prev", -1)
		frame.nextPage = MakeArrow("Next", 1)
		frame.previousPage:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -100, MSB_LAYOUT.pageTextBottom - 6.5)
		frame.nextPage:SetPoint("TOPLEFT", frame.previousPage, "TOPLEFT", 24, 0)

		frame.pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		frame.pageText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -110, MSB_LAYOUT.pageTextBottom)
		frame.pageText:SetTextColor(1, 1, 1)
	end;

	-- Close button in the right title bar socket
	AddCloseButton = function(self)
		local frame = self.frame
		local socket = MSB_LAYOUT.sockets[2]
		local close = CreateFrame("Button", "ModernSpellBookFrameCloseButton", frame)
		close:SetWidth(32)
		close:SetHeight(32)
		close:SetPoint("CENTER", frame, "TOPRIGHT", socket.x + MSB_LAYOUT.socketButtonOffsetX, socket.y)
		close:SetFrameLevel(frame:GetFrameLevel() + 5)
		close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
		close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
		close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
		close:GetHighlightTexture():SetBlendMode("ADD")
		close:SetScript("OnClick", function() frame:Hide() end)
		frame.CloseButton = close
	end;

	-- Button left of the close button: one or two pages
	AddViewToggleButton = function(self)
		local frame = self.frame
		local spellBook = self
		local socket = MSB_LAYOUT.sockets[1]
		local button = CreateFrame("Button", nil, frame)
		button:SetWidth(32)
		button:SetHeight(32)
		button:SetPoint("CENTER", frame, "TOPRIGHT", socket.x + MSB_LAYOUT.socketButtonOffsetX, socket.y)
		-- Above the border so it sits inside its socket
		button:SetFrameLevel(frame:GetFrameLevel() + 5)
		button:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
		button:GetHighlightTexture():SetBlendMode("ADD")

		local function ShowTooltip()
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip:SetText(ModernSpellBook_DB.isMinimized and MSB_L.TWO_PAGE_VIEW or MSB_L.ONE_PAGE_VIEW, 1, 1, 1)
			GameTooltip:Show()
		end
		button:SetScript("OnClick", function()
			PlaySound(MSB_SOUND.CHECKBOX_ON)
			spellBook:ToggleView()
			if (GameTooltip:IsOwned(button)) then ShowTooltip() end
		end)
		button:SetScript("OnEnter", ShowTooltip)
		button:SetScript("OnLeave", function() GameTooltip:Hide() end)
		frame.viewToggle = button
	end;

	-- Arrows point out (bigger) in the one page view, in (smaller) in the two page view
	UpdateViewToggle = function(self)
		local button = self.frame.viewToggle
		if (not button) then return end
		local art = "Interface\\AddOns\\ModernSpellBook\\Assets\\Buttons\\view-"
			.. (ModernSpellBook_DB.isMinimized and "bigger" or "smaller")
		button:SetNormalTexture(art .. "-up")
		button:SetPushedTexture(art .. "-down")
	end;

	-- Saved scale and position, else centred at scale 1
	RestorePosition = function(self)
		local scale = tonumber(ModernSpellBook_DB.windowScale) or 1
		self.frame:SetScale(math.max(MIN_SCALE, math.min(MAX_SCALE, scale)))
		self.frame:ClearAllPoints()
		local pos = ModernSpellBook_DB.position
		if (type(pos) == "table" and type(pos.point) == "string" and type(pos.relPoint) == "string"
			and type(pos.x) == "number" and type(pos.y) == "number") then
			self.frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
		else
			self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, windowSettings.posy)
		end
	end;

	-- Puts every setting into effect (after /msb reset)
	ApplySettings = function(self)
		self:RestorePosition()
		self:SetShape(ModernSpellBook_DB.isMinimized)
		self:PositionAllTabs()
		self:UpdateLockVisuals()
		self:UpdateBookmarkTexture()
		self.frame.currentPage = 1
		self:DrawPage()
	end;

	SavePosition = function(self)
		local point, _, relPoint, x, y = self.frame:GetPoint(1)
		ModernSpellBook_DB.position = { point = point, relPoint = relPoint, x = x, y = y }
	end;

	-- ========================= SHAPE =============================

	-- Switches between one and two pages, keeping the left edge in place and
	-- staying near the same spells
	ToggleView = function(self)
		local toOnePage = not ModernSpellBook_DB.isMinimized
		local left, top = self.frame:GetLeft(), self.frame:GetTop()
		ModernSpellBook_DB.isMinimized = toOnePage
		self:SetShape(toOnePage)
		if (left and top) then
			self.frame:ClearAllPoints()
			self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
			self:SavePosition()
		end

		-- Spread N roughly matches single pages 2N-1 and 2N (each view lays out its own pages)
		local page = self.frame.currentPage or 1
		if (toOnePage) then
			page = page * 2 - 1
		else
			page = math.ceil(page / 2)
		end
		self.frame.currentPage = page

		self:PositionAllTabs()
		self:DrawPage()
		self:ReplaceCompatPanels()
	end;

	-- Sizes the window and pages for the one page (minimized) or two page view
	SetShape = function(self, isMinimized)
		local frame = self.frame
		frame:SetWidth(isMinimized and windowSettings.width1 or windowSettings.width2)
		frame:SetHeight(windowSettings.height)

		local left, right = frame.backgroundLeft, frame.backgroundRight
		left:ClearAllPoints()
		left:SetPoint("TOPLEFT", frame, "TOPLEFT", MSB_LAYOUT.pageLeft, MSB_LAYOUT.pageTop)
		right:ClearAllPoints()
		if (isMinimized) then
			-- The single page stretches to the right border
			left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", MSB_LAYOUT.pageRight, MSB_LAYOUT.pageBottom)
			right:Hide()
		else
			left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", MSB_LAYOUT.pageSplit, MSB_LAYOUT.pageBottom)
			right:SetPoint("TOPLEFT", frame, "TOPLEFT", MSB_LAYOUT.pageSplit, MSB_LAYOUT.pageTop)
			right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", MSB_LAYOUT.pageRight, MSB_LAYOUT.pageBottom)
			right:Show()
		end

		self.chrome:Layout()
		self:LayoutBookmark(isMinimized)
		self:UpdateViewToggle()
		self:PositionFooterTexts(isMinimized)
		self:LayoutCompatActions()
		self:LayoutTopBar()
	end;

	-- Spell counter (bottom left) and trainer hint, below the pages' ornament
	PositionFooterTexts = function(self, isMinimized)
		local hint = self.frame.trainerHint
		hint:ClearAllPoints()
		if (isMinimized) then
			-- Single page: shorter text, right-aligned to stay clear of the counter
			hint:SetText(MSB_L.TRAINER_HINT_SHORT)
			hint:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -45, MSB_LAYOUT.footerBottom)
		else
			-- Two pages: centred under the right page
			hint:SetText(MSB_L.TRAINER_HINT_LONG)
			hint:SetPoint("BOTTOM", self.frame.backgroundRight, "BOTTOM", 0, 12)
		end
	end;

	-- ==================== PAGE LAYOUT ============================

	-- Splits a tab's sections into pages of rows (header 2 rows, 3 spells
	-- per row). A section that doesn't fit starts a new page; Professions
	-- always start a new page. Sections follow MSB_SectionOrder.
	CalculateSpellPositions = function(self, allSpells)
		local pageCollection = {}
		local spellPage = {}
		local currentPageRows = -2
		local maxPagesPerView = ModernSpellBook_DB.isMinimized and 1 or 2
		local drawingPageNumber = 1

		local function NextPage(rows)
			currentPageRows = rows
			drawingPageNumber = math.mod(drawingPageNumber, maxPagesPerView) + 1
			if (drawingPageNumber == 1) then
				table.insert(pageCollection, spellPage)
				spellPage = {}
			end
		end

		local categories = {}
		for category in pairs(allSpells) do
			table.insert(categories, category)
		end
		local order = MSB_SectionOrder()
		table.sort(categories, function(a, b)
			local oa, ob = order[a] or 100, order[b] or 100
			if (oa ~= ob) then return oa < ob end
			return a < b
		end)

		for _, category in ipairs(categories) do
			local spells = allSpells[category]
			local count = table.getn(spells)
			if (count > 0) then
				if (category == MSB_STR.PROFESSIONS and currentPageRows ~= -2) then
					NextPage(-2)
				elseif (currentPageRows + (count < 3 and 3 or 4) > 7.5) then
					NextPage(-2)
				end
				currentPageRows = currentPageRows + 2
				table.insert(spellPage, { isCategory = true, category = category, currentPageRows = currentPageRows, drawingPageNumber = drawingPageNumber })

				local gridX = -1
				for i, spellInfo in ipairs(spells) do
					gridX = math.mod(gridX + 1, 3)
					if (gridX == 0) then
						-- A section's last row of one or two spells may use an 8th
						-- row on a left or single page (clear of the page number)
						local isLastRowOnLeftPage = (i + 2 > count) and drawingPageNumber == 1
						local maxRows = isLastRowOnLeftPage and 8.5 or 7.75
						if (currentPageRows + 1 > maxRows) then
							NextPage(0)
							-- Header repeated where the section carries on (its rows
							-- are reserved either way)
							if (ModernSpellBook_DB.showContinuationHeaders) then
								table.insert(spellPage, { isCategory = true, category = category, currentPageRows = currentPageRows, drawingPageNumber = drawingPageNumber })
							end
						end
						currentPageRows = currentPageRows + 1
					end
					table.insert(spellPage, { spellInfo = spellInfo, currentPageRows = currentPageRows, drawingPageNumber = drawingPageNumber, gridX = gridX })
				end
			end
		end

		table.insert(pageCollection, spellPage)
		return pageCollection
	end;

	-- ================== MODELS AND REDRAWS =======================

	-- The spell lists, or settings that shape them, changed
	MarkDirty = function(self)
		self.spellLists = {}
		self.models = {}
		MSB_TrainerDataService:Invalidate()
		MSB_SpellDataService:PruneNewSpells()
	end;

	-- One tab's pages, from its spell list and the search text
	BuildModel = function(self, tab)
		local list = self.spellLists[tab]
		if (not list) then
			local spells, isPetTab = MSB_SpellDataService:GetAvailableSpells(tab)
			list = { spells = spells, isPetTab = isPetTab }
			self.spellLists[tab] = list
		end
		local model = { pages = {} }
		if (list.isPetTab and next(list.spells) == nil) then
			model.empty = MSB_L.NO_PET_SPELLS
			return model
		end
		local filtered = MSB_SpellDataService:FilterSpells(self.frame.searchBar:GetText() or "", list.spells)
		if (next(filtered) == nil) then
			model.empty = self.frame.noResultsMessage
		else
			model.pages = self:CalculateSpellPositions(filtered)
		end
		return model
	end;

	GetModel = function(self, tab)
		local model = self.models[tab]
		if (not model) then
			model = self:BuildModel(tab)
			self.models[tab] = model
		end
		return model
	end;

	-- Everything that changes the spell lists
	DrawPage = function(self)
		self:MarkDirty()
		if (self.frame:IsVisible()) then self:Apply() end
	end;

	-- Search text changed: only the filter is redone. New results start on page 1.
	RefreshPage = function(self)
		self.models = {}
		self.frame.currentPage = 1
		if (self.frame:IsVisible()) then self:Apply() end
	end;

	SelectTab = function(self, tab)
		local frame = self.frame
		if (frame.selectedTab == tab) then return end
		frame.selectedTab = tab
		if (tab ~= MSB_TAB_PET) then frame.bookTab = tab end
		frame.currentPage = 1
		PlaySound(MSB_SOUND.PAGE_TURN)
		self:Apply()
	end;

	SetPage = function(self, page)
		local frame = self.frame
		if (page < 1 or page > (frame.maxPages or 1) or page == frame.currentPage) then return end
		frame.currentPage = page
		PlaySound(MSB_SOUND.PAGE_TURN)
		self:Apply()
	end;

	-- Draws the selected tab's current page
	Apply = function(self)
		if (not self.isSetUp) then return end
		local frame = self.frame
		if (frame.selectedTab == MSB_TAB_PET and not self:HasPetTab()) then
			frame.selectedTab = frame.bookTab or MSB_TAB_CLASS
		end
		local model = self:GetModel(frame.selectedTab)
		frame.pageCollection = model.pages
		frame.maxPages = math.max(1, table.getn(model.pages))
		frame.currentPage = math.max(1, math.min(frame.currentPage or 1, frame.maxPages))
		if (frame.selectedTab ~= MSB_TAB_PET) then
			ModernSpellBook_DB.lastTab = frame.selectedTab
			ModernSpellBook_DB.lastPage = frame.currentPage
		end

		for _, tab in ipairs(frame.Tabgroups) do
			if (tab.tab_number == frame.selectedTab) then
				tab:SetSelected()
			else
				tab:SetDeselected()
			end
		end

		self:RefreshPageElements()
		if (model.empty) then
			frame.noresultsText:SetText(model.empty)
			frame.noresultsText:Show()
		else
			frame.noresultsText:Hide()
		end
		MSB_SpellDataService:UpdateSpellCounter()
		self:UpdateUpcomingSpells()
		self:UpdateTrainerHint()
	end;

	-- Trainer hint, until the first trainer visit
	UpdateTrainerHint = function(self)
		self.frame.trainerHint:SetShown(ModernSpellBook_DB.showUnlearned and not MSB_TrainerDataService:HasTrainerData())
	end;

	-- Places and fills the current page's headers and spell buttons
	RefreshPageElements = function(self)
		local frame = self.frame
		frame.rankFlyout:Close()
		-- Rebuilt on every redraw: pooled buttons change spells, so old
		-- entries would light the wrong icon
		frame.stanceButtons = {}
		-- The action bars are read once per redraw for the "not on bars" pulse
		MSB_ActionBarHelper:InvalidatePlacedSpells()

		local currentPage = frame.currentPage
		local maxPages = frame.maxPages
		if (maxPages > 1) then
			frame.pageText:SetText(string.format(MSB_L.PAGE_NUMBER, currentPage, maxPages))
			frame.pageText:Show()
			frame.previousPage:Show()
			frame.nextPage:Show()
			if (currentPage > 1) then frame.previousPage:Enable() else frame.previousPage:Disable() end
			if (currentPage < maxPages) then frame.nextPage:Enable() else frame.nextPage:Disable() end
		else
			frame.pageText:Hide()
			frame.previousPage:Hide()
			frame.nextPage:Hide()
		end

		local page = frame.pageCollection and frame.pageCollection[currentPage] or {}
		local totalCategories, totalSpells = 0, 0
		local count = table.getn(page)
		for i = 1, count do
			local element = page[i]
			if (element.isCategory) then
				totalCategories = totalCategories + 1
				-- The section's first spell icon, the header's fallback icon
				local fallbackIcon = nil
				for j = i + 1, count do
					local nextElement = page[j]
					if (nextElement.isCategory) then break end
					if (nextElement.spellInfo.spellIcon) then
						fallbackIcon = nextElement.spellInfo.spellIcon
						break
					end
				end
				self:GetOrCreateCategory(totalCategories):Set(element.category, element.currentPageRows, element.drawingPageNumber, fallbackIcon)
			else
				totalSpells = totalSpells + 1
				local item = self:GetOrCreateSpellItem(totalSpells)
				item:SetPosition(MSB_SpellItemPosition(element.drawingPageNumber, element.currentPageRows, element.gridX))
				item:Set(element.spellInfo)
				item:Show()
			end
		end
		for i = totalCategories + 1, table.getn(self.categoryItems) do
			self.categoryItems[i]:Hide()
		end
		for i = totalSpells + 1, table.getn(self.spellItems) do
			self.spellItems[i]:Hide()
		end
	end;

	-- Every spell button on the current page
	ForEachShownSpell = function(self, func)
		for _, item in ipairs(self.spellItems) do
			if (item:IsShown()) then func(item) end
		end
	end;

	-- Pet autocast toggled while the book is open
	UpdateAutocast = function(self)
		self:ForEachShownSpell(function(item) item:UpdateAutocast() end)
	end;

	-- Cooldowns of the shown spells and the rank flyout. A cast sends several
	-- cooldown events: one refresh on the next frame.
	UpdateCooldowns = function(self)
		if (not self.isSetUp or not self.frame:IsVisible() or self.cooldownsQueued) then return end
		self.cooldownsQueued = true
		local spellBook = self
		MSB_After(0, function()
			spellBook.cooldownsQueued = false
			if (not spellBook.frame:IsVisible()) then return end
			spellBook:ForEachShownSpell(function(item) item:UpdateCooldown() end)
			spellBook.frame.rankFlyout:UpdateCooldowns()
		end)
	end;

	-- "Not on action bars" pulse, after the bars changed
	UpdateUnplacedHighlights = function(self)
		self:ForEachShownSpell(function(item) item:UpdateUnplacedHighlight() end)
	end;

	-- ================ UPCOMING SPELLS ============================

	UpdateUpcomingSpells = function(self)
		local frame = self.frame
		local visible = table.getn(frame.upcomingIcons)
		for i = 1, visible do
			frame.upcomingIcons[i]:Hide()
		end
		frame.upcomingPrevArrow:Hide()
		frame.upcomingNextArrow:Hide()

		if (not ModernSpellBook_DB.showUpcoming or frame.selectedTab ~= MSB_TAB_CLASS
			or not MSB_TrainerDataService:HasTrainerData()) then
			frame.upcomingFrame:Hide()
			return
		end

		local upcoming, nextLevel = MSB_SpellDataService:GetUpcomingSpells()
		local total = table.getn(upcoming)
		if (not nextLevel or total == 0) then
			frame.upcomingFrame:Hide()
			return
		end

		frame.upcomingLabel:SetText(string.format(MSB_L.UPCOMING_SPELLS, nextLevel))
		frame.upcomingFrame:Show()

		local maxOffset = math.max(0, total - visible)
		frame.upcomingScrollOffset = math.min(frame.upcomingScrollOffset, maxOffset)
		local offset = frame.upcomingScrollOffset

		for i = 1, math.min(visible, total - offset) do
			local spell = upcoming[offset + i]
			local button = frame.upcomingIcons[i]
			button.icon.icon:SetTexture(spell.spellIcon)
			button.icon:SetDesaturated(true)
			button.icon.icon:SetAlpha(0.7)
			button.spell = spell
			button:Show()
		end
		frame.upcomingPrevArrow:SetShown(offset > 0)
		frame.upcomingNextArrow:SetShown(offset < maxOffset)
	end;

	-- ==================== POOLS ==================================

	GetOrCreateCategory = function(self, i)
		local item = self.categoryItems[i]
		if (not item) then
			item = MSB_CCategoryItem(self.frame)
			self.categoryItems[i] = item
		end
		return item
	end;

	GetOrCreateSpellItem = function(self, i)
		local item = self.spellItems[i]
		if (not item) then
			item = MSB_CSpellItem(self.frame, i)
			self.spellItems[i] = item
		end
		return item
	end;

	-- =================== TAB MANAGEMENT ==========================

	NewTab = function(self, name)
		local tabNumber = table.getn(self.frame.Tabgroups) + 1
		local spellBook = self
		local tab = MSB_CTab(self.frame, name, tabNumber, function(clickedTab)
			spellBook:SelectTab(clickedTab.tab_number)
		end)
		table.insert(self.frame.Tabgroups, tab)
		return tab
	end;

	HasPetTab = function(self)
		return (HasPetSpells() and UnitExists("pet")) and true or false
	end;

	-- The pet tab follows the pet (named after its type, e.g. "Beast"); the
	-- "Other" tab shows while Turtle WoW's extra spellbook tabs have spells
	UpdateOptionalTabs = function(self)
		local frame = self.frame
		local hasPet = self:HasPetTab()
		frame.tab1:SetName(UnitClass("player"))
		if (hasPet) then frame.tab3:SetName(UnitCreatureType("pet") or MSB_L.TAB_PET) end
		local hasOther = MSB_SpellDataService:HasOtherTabSpells()
		local changed = (frame.tab3:IsShown() ~= hasPet) or (frame.tab4:IsShown() ~= hasOther)
		frame.tab3:SetShown(hasPet)
		frame.tab4:SetShown(hasOther)

		-- The open tab is gone: back to the class tab
		if ((frame.selectedTab == MSB_TAB_PET and not hasPet) or (frame.selectedTab == MSB_TAB_OTHER and not hasOther)) then
			frame.selectedTab = MSB_TAB_CLASS
			frame.currentPage = 1
		end
		if (frame.bookTab == MSB_TAB_OTHER and not hasOther) then frame.bookTab = MSB_TAB_CLASS end
		if (changed or hasPet) then self:PositionAllTabs() end
	end;

	PositionAllTabs = function(self)
		for _, tab in ipairs(self.frame.Tabgroups) do
			tab:UpdatePosition(self.frame.Tabgroups)
		end
		self:LayoutTopBar()
	end;

	-- Vertical centre of the stone strip between the title bar and the separator
	GetStripMiddle = function(self)
		return (MSB_LAYOUT.titleBarHeight - MSB_LAYOUT.separatorTop) / 2
	end;

	-- Fits the search box between the last tab and the settings cog. Without
	-- room for it, the box hides and the cog moves to the right end.
	LayoutTopBar = function(self)
		local searchBar = self.frame.searchBar
		if (not searchBar or not self.frame.Tabgroups) then return end

		local tabsRight = MSB_LAYOUT.tabsLeft
		for _, tab in ipairs(self.frame.Tabgroups) do
			if (tab:IsShown()) then
				tabsRight = tabsRight + tab:GetWidthWithGap()
			end
		end

		-- Right margin 16, the cog plus its gap, 10 gap after the tabs
		local room = self.frame:GetWidth() - 16 - (MSB_LAYOUT.cogSize + MSB_LAYOUT.cogGap) - 10 - tabsRight
		local width = math.min(SEARCH_MAX_WIDTH, room)
		local cog = self.frame.settingsButton
		if (cog) then cog:ClearAllPoints() end
		if (width >= SEARCH_MIN_WIDTH) then
			searchBar.frame:SetWidth(width)
			searchBar:Show()
			if (cog) then cog:SetPoint("RIGHT", searchBar.frame, "LEFT", -MSB_LAYOUT.cogGap, 0) end
		else
			if (searchBar:IsShown()) then
				-- A typed search is cleared (which refreshes the page)
				if ((searchBar:GetText() or "") ~= "") then searchBar:Clear() end
				searchBar:Hide()
			end
			if (cog) then cog:SetPoint("RIGHT", self.frame, "TOPRIGHT", -16 + MSB_LAYOUT.cogMargin, -self:GetStripMiddle()) end
		end
	end;

	-- ================= COMPATIBILITY BUTTONS =====================

	-- Registers an addon panel (Clique): a tab in the two page view, a side
	-- button in the one page view. Returns the tab and the side button.
	-- action = { name, tabLabel, tooltip, icon, texCoord, onClick, isOpen }
	AddCompatAction = function(self, action)
		local frame = self.frame
		frame.compatActions = frame.compatActions or {}

		local tabNumber = table.getn(frame.Tabgroups) + 1
		local tab = MSB_CTab(frame, action.tabLabel, tabNumber, function() action.onClick() end)
		table.insert(frame.Tabgroups, tab)

		local sideButton = MSB_CSideButton(frame, "ModernSpellBookFrame_Side" .. action.name,
			action.icon, action.texCoord, action.tooltip, action.onClick, action.isOpen)

		table.insert(frame.compatActions, { tab = tab, sideButton = sideButton })
		self:LayoutCompatActions()
		self:PositionAllTabs()
		return tab, sideButton
	end;

	-- Shows each panel as a tab (two pages) or a side button (one page)
	LayoutCompatActions = function(self)
		local actions = self.frame.compatActions
		if (not actions) then return end
		local onePage = ModernSpellBook_DB.isMinimized
		for slot, action in ipairs(actions) do
			if (onePage) then
				action.tab:Hide()
				action.sideButton:SetSlot(slot)
				action.sideButton:Show()
				action.sideButton:UpdateChecked()
			else
				action.sideButton:Hide()
				action.tab:Show()
			end
		end
		for _, tab in ipairs(self.frame.Tabgroups) do
			tab:UpdatePosition(self.frame.Tabgroups)
		end
	end;

	-- Refreshes the lit state of the side buttons (a panel opened or closed)
	UpdateCompatButtons = function(self)
		local actions = self.frame.compatActions
		if (not actions) then return end
		for _, action in ipairs(actions) do
			action.sideButton:UpdateChecked()
		end
	end;

	-- Gap between the window and an addon panel (clear of the side buttons)
	GetCompatPanelOffset = function(self)
		if (ModernSpellBook_DB.isMinimized and self.frame.compatActions
			and table.getn(self.frame.compatActions) > 0) then
			return 39
		end
		return 6
	end;

	-- After a view switch: re-places open addon panels that sit beside the
	-- window. Panels dragged elsewhere are left alone.
	ReplaceCompatPanels = function(self)
		local panels = self.frame.compatPanels
		if (not panels) then return end
		for panel in pairs(panels) do
			if (panel:IsShown()) then
				local _, relativeTo = panel:GetPoint(1)
				if (relativeTo == self.frame) then
					self:PlaceCompatPanel(panel)
				end
			end
		end
	end;

	-- Places an addon panel beside the window: right, else left, else over
	-- the window (one strata higher)
	PlaceCompatPanel = function(self, panel)
		local root = self.frame
		root.compatPanels = root.compatPanels or {}
		root.compatPanels[panel] = true
		local scale = panel:GetEffectiveScale()
		local ratio = root:GetEffectiveScale() / scale
		local screen = GetScreenWidth() * UIParent:GetEffectiveScale() / scale
		local offset = self:GetCompatPanelOffset()
		local width = panel:GetWidth()
		local fitsRight = (root:GetRight() or 0) * ratio + offset + width <= screen
		local fitsLeft = (root:GetLeft() or 0) * ratio - 6 - width >= 0
		panel:ClearAllPoints()
		if (fitsRight or not fitsLeft) then
			panel:SetPoint("TOPLEFT", root, "TOPRIGHT", offset, 0)
		else
			panel:SetPoint("TOPRIGHT", root, "TOPLEFT", -6, 0)
		end
		panel:SetFrameStrata((fitsRight or fitsLeft) and "HIGH" or "DIALOG")
	end;
}

MSB_SpellBook = MSB_CSpellBook()
