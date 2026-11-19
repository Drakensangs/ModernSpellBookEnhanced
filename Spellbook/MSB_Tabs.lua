-- Tabs in the strip under the title bar: class, General, pet, "Other" and
-- the Clique tab (two page view; MSB_CSideButton below in the one page view).
-- The tab art hangs flipped, lip on top, its bottom tucked under the
-- separator. The selected tab is taller, brighter and lit from below.

local SELECTED_TEXTURE = "Interface\\Spellbook\\UI-SpellBook-Tab3-Selected"
local UNSELECTED_TEXTURE = "Interface\\Spellbook\\UI-SpellBook-Tab-Unselected"
-- The default spellbook's tab highlight
local GLOW_TEXTURE = "Interface\\SpellBook\\UI-SpellbookPanel-Tab-Highlight"
local TEX_WIDTH, TEX_HEIGHT = 128, 64

-- Pixel rects on the 128x64 tab art, cut into six slices so the caps keep
-- their size. textX/textY place the label from the bottom centre (the art
-- is off-centre, so the label is too).
local SELECTED_ART = { left = 12, capLeft = 28, capRight = 100, right = 116,
	top = 45, lip = 37, bottom = 18, height = 33, textX = 2, textY = 15 }
local UNSELECTED_ART = { left = 13, capLeft = 29, capRight = 99, right = 115,
	top = 46, lip = 39, bottom = 18, height = 26, textX = 1.5, textY = 13 }

-- Glow behind the selected tab's label: the upper half of the highlight,
-- its brightest edge on the separator
local GLOW_RECT = { 17, 115, 18, 31 }
local GLOW_HEIGHT = 16
local GLOW_INSET = 4		-- keeps the glow inside the tab's metal sides
local GLOW_ALPHA = 0.3

local HIGHLIGHT_ALPHA = 0.35

local TAB_GAP = 4			-- space between tabs
local TAB_PADDING = 30		-- added to the text width
local TAB_MIN_WIDTH = 70

-- Text colors
local normalFontColor = {1, 0.82, 0}
local highlightFontColor = {1, 1, 1}
local disabledFontColor = {0.5, 0.41, 0}

MSB_class "MSB_CTab"
{
	__init = function(self, parent, name, tabNumber, onClickCallback)
		self.tab_number = tabNumber
		self.name = name

		self.frame = CreateFrame("Button", "ModernSpellBookFrame_Tab".. tabNumber, parent)
		self.frame:SetHeight(UNSELECTED_ART.height)

		-- Tab art, its mouseover brightening, and the selected tab's glow
		self.slices = self:CreateSlices("BORDER")
		self.highlightSlices = self:CreateSlices("HIGHLIGHT")
		self.glow = self.frame:CreateTexture(nil, "ARTWORK")
		self.glow:SetTexture(GLOW_TEXTURE)
		self.glow:SetTexCoord(GLOW_RECT[1] / TEX_WIDTH, GLOW_RECT[2] / TEX_WIDTH,
			GLOW_RECT[3] / TEX_HEIGHT, GLOW_RECT[4] / TEX_HEIGHT)
		self.glow:SetBlendMode("ADD")
		self.glow:SetAlpha(GLOW_ALPHA)
		self.glow:SetHeight(GLOW_HEIGHT)
		self.glow:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", GLOW_INSET, 0)
		self.glow:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -GLOW_INSET, 0)
		self.glow:Hide()

		local tabText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.frame:SetFontString(tabText)

		self:SetName(name)

		if (tabNumber == 1) then
			self:SetSelected()
		else
			self:SetDeselected()
		end

		local tab = self
		self.frame:SetScript("OnClick", function()
			onClickCallback(tab)
		end)

		self.frame:SetScript("OnEnter", function()
			tab.frame:GetFontString():SetTextColor(unpack(highlightFontColor))
		end)

		self.frame:SetScript("OnLeave", function()
			tab:SetDefaultFontColor()
		end)
	end;

	-- ========================= METHODS ===========================

	SetName = function(self, name)
		self.name = name
		self.frame:GetFontString():SetText(name)
		self.frame:SetWidth(math.max(TAB_MIN_WIDTH, self.frame:GetFontString():GetStringWidth() + TAB_PADDING))
	end;

	-- Lines the tab up after the previous visible tab, bottoms on the separator
	UpdatePosition = function(self, tabgroups)
		self.frame:ClearAllPoints()

		local anchor = nil
		for j = self.tab_number - 1, 1, -1 do
			local prevTab = tabgroups[j]
			if (prevTab and prevTab:IsShown()) then
				anchor = prevTab
				break
			end
		end

		if (anchor) then
			self.frame:SetPoint("BOTTOMLEFT", anchor.frame, "BOTTOMRIGHT", TAB_GAP, 0)
		else
			self.frame:SetPoint("BOTTOMLEFT", ModernSpellBookFrame, "TOPLEFT",
				MSB_LAYOUT.tabsLeft, MSB_LAYOUT.tabBottom)
		end
	end;

	GetWidthWithGap = function(self)
		return self.frame:GetWidth() + TAB_GAP
	end;

	SetDefaultFontColor = function(self)
		if (ModernSpellBookFrame.selectedTab == self.tab_number) then
			self.frame:GetFontString():SetTextColor(unpack(normalFontColor))
		else
			self.frame:GetFontString():SetTextColor(unpack(disabledFontColor))
		end
	end;

	-- ======================== VISUAL STATE =======================

	-- Six textures on one layer: lip and body for the left cap, middle and right cap
	CreateSlices = function(self, layer)
		local slices = {}
		for i = 1, 6 do
			slices[i] = self.frame:CreateTexture(nil, layer)
		end
		return slices
	end;

	-- Cuts one state's art over a set of slices. The caps keep their natural
	-- width, the lip its natural height; the rest follows the frame's size.
	LayoutSlices = function(self, slices, path, art)
		local frame = self.frame
		local capWidth = art.capLeft - art.left
		local lipHeight = art.top - art.lip
		-- Per column: texture x range, then the left and right edges as
		-- (side of the frame, offset)
		local columns = {
			{ art.left, art.capLeft, "LEFT", 0, "LEFT", capWidth },
			{ art.capLeft, art.capRight, "LEFT", capWidth, "RIGHT", -capWidth },
			{ art.capRight, art.right, "RIGHT", -capWidth, "RIGHT", 0 },
		}
		for c = 1, 3 do
			local column = columns[c]
			local x1, x2 = column[1] / TEX_WIDTH, column[2] / TEX_WIDTH
			local lip, body = slices[c * 2 - 1], slices[c * 2]

			lip:SetTexture(path)
			lip:SetTexCoord(x1, x2, art.top / TEX_HEIGHT, art.lip / TEX_HEIGHT)
			lip:ClearAllPoints()
			lip:SetPoint("TOPLEFT", frame, "TOP" .. column[3], column[4], 0)
			lip:SetPoint("BOTTOMRIGHT", frame, "TOP" .. column[5], column[6], -lipHeight)

			body:SetTexture(path)
			body:SetTexCoord(x1, x2, art.lip / TEX_HEIGHT, art.bottom / TEX_HEIGHT)
			body:ClearAllPoints()
			body:SetPoint("TOPLEFT", frame, "TOP" .. column[3], column[4], -lipHeight)
			body:SetPoint("BOTTOMRIGHT", frame, "BOTTOM" .. column[5], column[6], 0)
		end
	end;

	-- Art and height for one state; the highlight brightens the same art
	SetTabArt = function(self, path, art, brightness)
		self.frame:SetHeight(art.height)
		local label = self.frame:GetFontString()
		label:ClearAllPoints()
		label:SetPoint("CENTER", self.frame, "BOTTOM", art.textX, art.textY)
		self:LayoutSlices(self.slices, path, art)
		for _, slice in ipairs(self.slices) do
			slice:SetVertexColor(brightness, brightness, brightness, 1)
		end
		self:LayoutSlices(self.highlightSlices, path, art)
		for _, slice in ipairs(self.highlightSlices) do
			slice:SetBlendMode("ADD")
			slice:SetAlpha(HIGHLIGHT_ALPHA)
		end
	end;

	-- The art is laid out only when the state changes (every page flip
	-- calls these); the label color is always reset
	SetSelected = function(self)
		if (self.selected ~= true) then
			self.selected = true
			self:SetTabArt(SELECTED_TEXTURE, SELECTED_ART, 1)
			self.glow:Show()
		end
		self.frame:GetFontString():SetTextColor(unpack(normalFontColor))
	end;

	SetDeselected = function(self)
		if (self.selected ~= false) then
			self.selected = false
			self:SetTabArt(UNSELECTED_TEXTURE, UNSELECTED_ART, 0.8)
			self.glow:Hide()
		end
		self.frame:GetFontString():SetTextColor(unpack(disabledFontColor))
	end;

	-- ====================== DELEGATION ===========================

	Hide = function(self)
		self.frame:Hide()
	end;

	Show = function(self)
		self.frame:Show()
	end;

	SetShown = function(self, shown)
		self.frame:SetShown(shown)
	end;

	IsShown = function(self)
		return self.frame:IsShown()
	end;
}

-- MSB_CSideButton: button on the window's right edge, like the default
-- book's skill line tabs. Opens the Clique panel in the one page view.

local SIDE_BUTTON_SIZE = 32
local SIDE_SOCKET_TEXTURE = "Interface\\SpellBook\\SpellBook-SkillLineTab"

MSB_class "MSB_CSideButton"
{
	-- isOpen() returns true while the panel is shown (the button lights up)
	__init = function(self, parent, name, icon, texCoord, tooltip, onClick, isOpen)
		self.isOpen = isOpen
		self.tooltip = tooltip

		local button = CreateFrame("CheckButton", name, parent)
		button:SetWidth(SIDE_BUTTON_SIZE)
		button:SetHeight(SIDE_BUTTON_SIZE)
		-- Below the border, so the socket's flange tucks under the window edge
		button:SetFrameLevel(parent:GetFrameLevel() + 1)

		local socket = button:CreateTexture(nil, "BACKGROUND")
		socket:SetTexture(SIDE_SOCKET_TEXTURE)
		socket:SetWidth(64)
		socket:SetHeight(64)
		socket:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 11)

		button:SetNormalTexture(icon)
		if (texCoord) then
			button:GetNormalTexture():SetTexCoord(unpack(texCoord))
		end
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
		button:GetHighlightTexture():SetBlendMode("ADD")
		button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
		button:GetCheckedTexture():SetBlendMode("ADD")

		local sideButton = self
		button:SetScript("OnClick", function()
			PlaySound(MSB_SOUND.CHECKBOX_ON)
			onClick()
			sideButton:UpdateChecked()
		end)
		button:SetScript("OnEnter", function()
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip:SetText(sideButton.tooltip, 1, 1, 1)
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		button:SetScript("OnShow", function()
			sideButton:UpdateChecked()
		end)

		button:Hide()
		self.frame = button
	end;

	UpdateChecked = function(self)
		self.frame:SetChecked(self.isOpen and self.isOpen() and true or false)
	end;

	-- Slot 1 is the top position, the next ones below it
	SetSlot = function(self, slot)
		self.frame:ClearAllPoints()
		self.frame:SetPoint("TOPLEFT", ModernSpellBookFrame, "TOPRIGHT", -1,
			MSB_LAYOUT.sideButtonTop - (slot - 1) * MSB_LAYOUT.sideButtonSpacing)
	end;

	Show = function(self)
		self.frame:Show()
	end;

	Hide = function(self)
		self.frame:Hide()
	end;

	IsShown = function(self)
		return self.frame:IsShown()
	end;
}
