-- Section header on a page: icon, section name and separator line.

local VERTICAL_SPACING = 50
local SECOND_PAGE_OFFSET = 510
local HORIZONTAL_OFFSET = 40

MSB_class "MSB_CCategoryItem"
{
	__init = function(self, parent)
		self.frame = CreateFrame("Frame", nil, parent)
		self.frame:SetWidth(450)
		self.frame:SetHeight(20)

		-- Icon left of the name
		self.specIconFrame = CreateFrame("Frame", nil, self.frame)
		self.specIconFrame:SetWidth(22)
		self.specIconFrame:SetHeight(22)
		self.specIconFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, 1)
		self.specIconFrame:SetBackdrop({
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 8,
			insets = { left = 1, right = 1, top = 1, bottom = 1 }
		})
		self.specIconFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

		self.specIcon = self.specIconFrame:CreateTexture(nil, "OVERLAY")
		self.specIcon:SetWidth(18)
		self.specIcon:SetHeight(18)
		self.specIcon:SetPoint("CENTER", self.specIconFrame, "CENTER", 0, 0)
		self.specIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

		self.text = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.text:SetPoint("LEFT", self.specIconFrame, "RIGHT", 5, 0)
		self.text:SetTextColor(0, 0, 0)
		self.text:SetShadowOffset(0, 0)
		self.text:SetFont(MSB_GetFont(), 17)

		-- Soft light behind the name
		self.lightBorder = self.frame:CreateTexture(nil, "ARTWORK")
		self.lightBorder:SetWidth(256)
		self.lightBorder:SetHeight(52)	-- soft edges all round, so it blends into the page
		self.lightBorder:SetPoint("LEFT", self.specIconFrame, "LEFT", -10, 0)
		self.lightBorder:SetTexture("Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\spellbook-section-highlight")
		self.lightBorder:SetBlendMode("ADD")
		self.lightBorder:SetAlpha(0.4)

		self.separator = self.frame:CreateTexture(nil, "OVERLAY")
		self.separator:SetWidth(400)
		self.separator:SetHeight(10)
		self.separator:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -30)
		self.separator:SetTexture("Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\separator")
	end;

	-- ========================= SET ===============================

	Set = function(self, categoryName, currentPageRows, page, fallbackIcon)
		self.text:SetText(categoryName)

		-- Icon of the spellbook tab, else of the class tab you don't have yet
		-- (no spell of that school), else of the talent tree, else of the
		-- section's first spell
		local icon = nil
		for t = 1, C_SpellBook.GetNumSpellBookSkillLines() do
			local line = C_SpellBook.GetSpellBookSkillLineInfo(t)
			if (line.name == categoryName) then
				icon = line.iconID
				break
			end
		end
		icon = icon or MSB_ClassSectionIcon(categoryName)
		if (not icon) then
			for t = 1, GetNumTalentTabs() do
				local tabName, tabIcon = GetTalentTabInfo(t)
				if (tabName == categoryName) then
					icon = tabIcon
					break
				end
			end
		end
		icon = icon or fallbackIcon
		if (icon) then self.specIcon:SetTexture(icon) end
		if (not icon) then
			self.specIconFrame:Hide()
			self.text:SetPoint("LEFT", self.specIconFrame, "LEFT", 0, 0)
		else
			self.specIconFrame:Show()
			self.text:SetPoint("LEFT", self.specIconFrame, "RIGHT", 5, 0)
		end

		self.frame:SetPoint("TOPLEFT", ModernSpellBookFrame, "TOPLEFT", HORIZONTAL_OFFSET +SECOND_PAGE_OFFSET*(page -1), MSB_LAYOUT.contentTop +currentPageRows *-VERTICAL_SPACING -5)
		self.frame:Show()
	end;

	Hide = function(self)
		self.frame:Hide()
	end;
}
