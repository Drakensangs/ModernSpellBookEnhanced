-- A spell on the page: icon, name and rank text, and the trail behind them.
-- Clicks work as in the default book: click casts, right-click toggles pet
-- autocast, drag or shift-click picks up (shift-click links in chat or adds
-- a macro line when those are open). With Clique's panel open a click binds
-- the spell instead. The rank flyout's buttons reuse its handlers.

local ICON_SIZE = 28
local SPELL_HORIZONTAL_SPACING = 150
local VERTICAL_SPACING = 50
local SECOND_PAGE_OFFSET = 510
local HORIZONTAL_OFFSET = 40
local SPELL_INSET = 20
local RANK_ARROW_TEXTURE = "Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\rank-arrow"
local RANK_ARROW_SIZE = 16
local RANK_ARROW_HIT_WIDTH = 20
local RANK_ARROW_HIT_HEIGHT = 12

-- Top-left corner of a spell on the page, from the window's top-left corner
function MSB_SpellItemPosition(page, row, gridX)
	return HORIZONTAL_OFFSET + SPELL_INSET + SECOND_PAGE_OFFSET * (page - 1) + gridX * SPELL_HORIZONTAL_SPACING,
		MSB_LAYOUT.contentTop + row * -VERTICAL_SPACING
end

-- Clique's binding panel is open: clicks bind spells instead of casting them
local function IsCliqueBinding()
	return Clique and CliqueFrame and CliqueFrame:IsVisible()
end

MSB_class "MSB_CSpellItem"
{
	__init = function(self, parent, index)
		self.frame = CreateFrame("Button", "ModernSpellBookSpell" .. index, parent)
		self.frame:SetWidth(ICON_SIZE)
		self.frame:SetHeight(ICON_SIZE)
		-- All five mouse buttons, for Clique bindings
		self.frame:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp", "Button4Up", "Button5Up")
		self.frame:RegisterForDrag("LeftButton")
		self.frame:Hide()

		self.spellIcon = MSB_CSpellBookIcon(self.frame)
		self:InstallScripts()

		-- Text to the right of the icon
		self.textGroup = CreateFrame("Frame", nil, self.frame)
		self.textGroup:SetWidth(98)
		self.textGroup:SetHeight(ICON_SIZE)
		self.textGroup:SetPoint("LEFT", self.frame, "LEFT", 36, 0)

		self.nameText = self.textGroup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.nameText:SetPoint("TOPLEFT", self.textGroup, "TOPLEFT", 0, 0)
		self.nameText:SetWidth(98)
		self.nameText:SetJustifyH("LEFT")
		self.nameText:SetJustifyV("TOP")
		self.nameText:SetFont(MSB_GetFont(), ModernSpellBook_DB.fontSize)

		-- Soft shadow behind the text, starting at the icon's right edge so it
		-- never shows through faded unlearned icons
		self.trailBg = self.frame:CreateTexture(nil, "BACKGROUND")
		self.trailBg:SetWidth(162)
		self.trailBg:SetHeight(44)
		self.trailBg:SetPoint("LEFT", self.frame, "CENTER", 8, 0)
		self.trailBg:SetTexture("Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\spellbook-trail")

		-- Rank or level text
		self.rankText = self.textGroup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.rankText:SetPoint("TOPLEFT", self.nameText, "BOTTOMLEFT", 0, -1)
		self.rankText:SetFont(MSB_GetFont(), 9.5)
		self.rankText:SetJustifyH("LEFT")
		self.rankText:SetWidth(80)
		self.rankText:SetHeight(10)

		MSB_TextStyle:ApplyToSpell(self.nameText, self.rankText, self.trailBg, "normal")

		-- Arrow under the icon that opens the rank flyout
		self:CreateRankArrow()
	end;

	-- ====================== RANK ARROW ===========================

	CreateRankArrow = function(self)
		local item = self
		local arrow = CreateFrame("Button", nil, self.frame)
		arrow:SetWidth(RANK_ARROW_HIT_WIDTH)
		arrow:SetHeight(RANK_ARROW_HIT_HEIGHT)
		arrow:SetPoint("CENTER", self.spellIcon.icon, "BOTTOM", 0, -2)
		-- Above the icon border, hover, stance and new/train glows
		arrow:SetFrameLevel(self.frame:GetFrameLevel() + 16)
		arrow:RegisterForClicks("LeftButtonUp")

		arrow.tex = arrow:CreateTexture(nil, "ARTWORK")
		arrow.tex:SetWidth(RANK_ARROW_SIZE)
		arrow.tex:SetHeight(RANK_ARROW_SIZE)
		arrow.tex:SetPoint("CENTER", arrow, "CENTER", 0, 0)
		arrow.tex:SetTexture(RANK_ARROW_TEXTURE)

		arrow.highlight = arrow:CreateTexture(nil, "HIGHLIGHT")
		arrow.highlight:SetAllPoints(arrow.tex)
		arrow.highlight:SetTexture(RANK_ARROW_TEXTURE)
		arrow.highlight:SetBlendMode("ADD")
		arrow.highlight:SetAlpha(0.6)

		arrow:SetScript("OnClick", function()
			PlaySound(MSB_SOUND.CHECKBOX_ON)
			ModernSpellBookFrame.rankFlyout:Toggle(item)
			-- Refresh the "Show / Hide ranks" tooltip text
			if (GameTooltip:IsOwned(arrow)) then
				local onEnter = arrow:GetScript("OnEnter")
				if (onEnter) then onEnter() end
			end
		end)
		arrow:SetScript("OnEnter", function()
			GameTooltip:SetOwner(arrow, "ANCHOR_RIGHT")
			if (ModernSpellBookFrame.rankFlyout:IsOpenFor(item)) then
				GameTooltip:SetText(MSB_L.HIDE_RANKS, 1, 1, 1)
			else
				GameTooltip:SetText(MSB_L.SHOW_RANKS, 1, 1, 1)
			end
			GameTooltip:Show()
		end)
		arrow:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		arrow:Hide()
		self.rankArrow = arrow
	end;

	-- Arrow points down when collapsed, up while the flyout is open
	SetRankArrowExpanded = function(self, isExpanded)
		if (isExpanded) then
			self.rankArrow.tex:SetTexCoord(0, 1, 1, 0)
			self.rankArrow.highlight:SetTexCoord(0, 1, 1, 0)
		else
			self.rankArrow.tex:SetTexCoord(0, 1, 0, 1)
			self.rankArrow.highlight:SetTexCoord(0, 1, 0, 1)
		end
	end;

	UpdateRankArrow = function(self, spellInfo)
		self.spellInfo = spellInfo
		self:SetRankArrowExpanded(false)
		if (not spellInfo.isUnlearned and spellInfo.learnedRanks and table.getn(spellInfo.learnedRanks) > 1) then
			self.rankArrow:Show()
		else
			self.rankArrow:Hide()
		end
	end;

	-- ====================== DELEGATION ===========================

	Hide = function(self)
		self.frame:Hide()
	end;

	Show = function(self)
		self.frame:Show()
	end;

	IsShown = function(self)
		return self.frame:IsShown()
	end;

	SetPosition = function(self, x, y)
		self.frame:ClearAllPoints()
		self.frame:SetPoint("TOPLEFT", self.frame:GetParent(), "TOPLEFT", x, y)
	end;

	SetStance = function(self, isActive)
		self.spellIcon:SetStance(isActive)
	end;

	-- ======================= SCRIPTS =============================

	-- Set once; they act on the spell the button currently shows
	InstallScripts = function(self)
		local item = self
		self.frame:SetScript("OnEnter", function() item:OnEnter() end)
		self.frame:SetScript("OnLeave", function()
			GameTooltip:Hide()
			item.spellIcon.hover_glow:Hide()
		end)
		self.frame:SetScript("OnClick", function() item:OnClick(arg1) end)
		self.frame:SetScript("OnDragStart", function() item:PickUp() end)
	end;

	-- Spellbook slot of a castable spell, checked against the current book
	GetCastSlot = function(self)
		local spellInfo = self.spellInfo
		if (not spellInfo or spellInfo.isUnlearned or spellInfo.isTalent) then return nil end
		return MSB_ResolveSpellSlot(spellInfo)
	end;

	PickUp = function(self)
		if (self.spellInfo.isPassive) then return end
		local slot, bookType = self:GetCastSlot()
		if (slot) then PickupSpell(slot, bookType) end
	end;

	OnClick = function(self, button)
		local spellInfo = self.spellInfo
		if (not spellInfo) then return end
		-- Clicking a spell on the page closes an open rank flyout
		-- (clicks inside the flyout keep it open)
		if (not spellInfo.isRankEntry) then ModernSpellBookFrame.rankFlyout:Close() end

		if (IsCliqueBinding()) then
			MSB_CliqueBindSpell(spellInfo, button)
			return
		end
		if (button ~= "LeftButton" and button ~= "RightButton") then return end

		if (IsShiftKeyDown()) then
			self:OnShiftClick()
			return
		end

		local slot, bookType = self:GetCastSlot()
		if (not slot or spellInfo.isPassive) then return end
		if (button == "RightButton" and bookType == BOOKTYPE_PET) then
			ToggleSpellAutocast(slot, bookType)
		else
			CastSpell(slot, bookType)
		end
	end;

	-- Typing in chat: links the spell. Macro window open: adds a /cast line,
	-- as the default book does. Otherwise picks the spell up.
	OnShiftClick = function(self)
		local spellInfo = self.spellInfo
		local focus = GetCurrentKeyBoardFocus()
		if (focus and focus ~= MacroFrameText and focus ~= ModernSpellBookFrameSearchBar) then
			local link
			if (spellInfo.isTalent) then
				link = MSB_GetTalentLink(spellInfo.talentGrid[1], spellInfo.talentGrid[2])
			else
				link = GetSpellLink(spellInfo.spellID)
			end
			if (link) then focus:Insert(link) end
		elseif (MacroFrame and MacroFrame:IsVisible()) then
			if (not spellInfo.isPassive and not spellInfo.isUnlearned and not spellInfo.isTalent) then
				local rank = spellInfo.bookRank or ""
				if (rank ~= "") then
					MacroFrame_AddMacroLine(SLASH_CAST1 .. " " .. spellInfo.spellName .. "(" .. rank .. ")")
				else
					MacroFrame_AddMacroLine(SLASH_CAST1 .. " " .. spellInfo.spellName)
				end
			end
		else
			self:PickUp()
		end
	end;

	-- ======================== CONTENT ============================

	SetTextContent = function(self, spellInfo)
		self.nameText:SetFont(MSB_GetFont(), ModernSpellBook_DB.fontSize)
		self.nameText:SetText(spellInfo.spellName)
		if (spellInfo.isUnlearned and spellInfo.levelReq) then
			local rankText = spellInfo.spellRank or ""
			if (rankText ~= "") then
				self.rankText:SetText(rankText .. " (" .. MSB_STR.LEVEL_SHORT .. " " .. spellInfo.levelReq .. ")")
			else
				self.rankText:SetText(MSB_STR.LEVEL_SHORT .. " " .. spellInfo.levelReq)
			end
		else
			self.rankText:SetText(spellInfo.spellRank)
		end
	end;

	-- Name and rank centred next to the icon
	SetTextPosition = function(self, spellInfo)
		local subHeight = 0
		if ((spellInfo.spellRank and spellInfo.spellRank ~= "")
			or (spellInfo.isUnlearned and spellInfo.levelReq)) then
			subHeight = 11
		end
		local yOffset = (ICON_SIZE - self.nameText:GetStringHeight() - subHeight) / 2
		self.textGroup:ClearAllPoints()
		self.textGroup:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 36, -yOffset)
	end;

	OnEnter = function(self)
		local spellInfo = self.spellInfo
		if (not spellInfo) then return end
		local spellIcon = self.spellIcon
		spellIcon.hover_glow:Show()

		spellIcon:DismissAvailableHighlight(spellInfo)

		-- Hovering a new spell marks it (and its other ranks) as seen
		if (self.tipIsNew) then
			self.tipIsNew = false
			-- Other ranks on the same page lose their glow at once
			if (MSB_SpellDataService:MarkSeen(spellInfo)) then MSB_SpellBook:RefreshPageElements() end
		end
		spellIcon:DismissNewHighlight()

		GameTooltip:SetOwner(self.frame, "ANCHOR_RIGHT")
		if (spellInfo.isTalent) then
			-- Learned or not: the talent's own tooltip, without "Click to learn"
			GameTooltip:SetTalent(spellInfo.talentGrid[1], spellInfo.talentGrid[2])
			MSB_StripLearnPromptFromTooltip()
		elseif (spellInfo.isUnlearned) then
			GameTooltip:SetSpellByID(spellInfo.spellID, false, true)
		else
			local slot, bookType = self:GetCastSlot()
			if (slot) then
				GameTooltip:SetSpell(slot, bookType)
			else
				GameTooltip:SetSpellByID(spellInfo.spellID, spellInfo.isPetSpell, true)
			end
		end
		if (spellInfo.isUnlearned) then self:AddRequirementLines(spellInfo) end
		if (not spellInfo.isRankEntry and ModernSpellBook_DB.highlightUnplaced
			and MSB_ActionBarHelper:IsSpellUnplaced(spellInfo)) then
			GameTooltip:AddLine(MSB_L.NOT_ON_BARS, 1, 0.45, 0.2)
		end
		GameTooltip:Show()
	end;

	-- What an unlearned spell needs and where it is learned
	AddRequirementLines = function(self, spellInfo)
		local levelReq = spellInfo.levelReq
		if (levelReq) then
			local text = string.format(MSB_STR.REQUIRES_LEVEL, levelReq)
			if (UnitLevel("player") >= levelReq) then
				GameTooltip:AddLine(text, 0.2, 1, 0.2)
			else
				GameTooltip:AddLine(text, 1, 0.2, 0.2)
			end
		end
		if (spellInfo.isTalent) then
			GameTooltip:AddLine(MSB_L.REQUIRES_TALENT, 1, 0.82, 0)
			return
		end
		MSB_SpellSources:AddTooltipLines(GameTooltip, spellInfo, self)
		-- A later rank of a talent you have no point in
		if (spellInfo.talentBlocked) then
			GameTooltip:AddLine(MSB_L.REQUIRES_TALENT, 1, 0.82, 0)
		end
		if (spellInfo.isTrainerSpell) then
			-- Saved from the trainer's list on the last visit
			MSB_AddTrainingCostLine(GameTooltip, spellInfo.cost)
			GameTooltip:AddLine(MSB_L.VISIT_TRAINER, 1, 0.82, 0)
		end
	end;

	-- Cooldown swipe and numbers, from Set and SPELL_UPDATE_COOLDOWN.
	-- Restarted only when the cooldown changed.
	UpdateCooldown = function(self)
		local spellInfo = self.spellInfo
		local slot, bookType
		if (spellInfo and not spellInfo.isPassive) then slot, bookType = self:GetCastSlot() end
		if (not slot) then
			self:ResetCooldown()
			self.spellIcon:SetCooldown(nil)
			return
		end
		-- enable is 0 while the cooldown waits to start (e.g. until Stealth ends)
		local start, duration, enable = GetSpellCooldown(slot, bookType)
		if (start == self.cdStart and duration == self.cdDuration and enable == self.cdEnable) then return end
		self.cdStart, self.cdDuration, self.cdEnable = start, duration, enable
		self.spellIcon:SetCooldown(start, duration, enable == 1)
	end;

	-- Forces the next UpdateCooldown to apply
	ResetCooldown = function(self)
		self.cdStart, self.cdDuration, self.cdEnable = nil, nil, nil
	end;

	-- "Not on action bars" pulse (settings option)
	UpdateUnplacedHighlight = function(self, spellInfo)
		spellInfo = spellInfo or self.spellInfo
		local isUnplaced = ModernSpellBook_DB.highlightUnplaced and MSB_ActionBarHelper:IsSpellUnplaced(spellInfo)
		self.spellIcon:SetUnplaced(isUnplaced and true or false)
	end;

	-- Autocast corners and sparks on pet spells
	UpdateAutocast = function(self, spellInfo)
		spellInfo = spellInfo or self.spellInfo
		local allowed, enabled = false, false
		if (spellInfo and spellInfo.isPetSpell and not spellInfo.isPassive) then
			local slot, bookType = MSB_ResolveSpellSlot(spellInfo)
			if (slot) then
				local canAutocast, isOn = GetSpellAutocast(slot, bookType)
				allowed, enabled = canAutocast and true or false, isOn and true or false
			end
		end
		self.spellIcon:SetAutocast(allowed, enabled)
	end;

	-- =================== LEARNED STATE ===========================

	SetLearnedState = function(self, spellInfo)
		self.spellIcon:SetLearnedState(spellInfo)
		if (spellInfo.isUnlearned) then
			MSB_TextStyle:ApplyToSpell(self.nameText, self.rankText, self.trailBg, "unlearned")
		else
			MSB_TextStyle:ApplyToSpell(self.nameText, self.rankText, self.trailBg, "normal")
		end
	end;

	-- =================== MAIN ENTRY POINT ========================

	-- Shows a spell (spellInfo from MSB_SpellDataService)
	Set = function(self, spellInfo)
		self.spellInfo = spellInfo
		self:SetTextContent(spellInfo)

		-- Active stance, form or aura
		local stanceState = false
		if (spellInfo.stanceIndex ~= nil) then
			local _, _, isActive = GetShapeshiftFormInfo(spellInfo.stanceIndex)
			stanceState = isActive
			ModernSpellBookFrame.stanceButtons[spellInfo.spellName] = self
		end
		self.spellIcon:SetStance(stanceState)

		self:SetTextPosition(spellInfo)

		local isNew = MSB_IsNewSpell(spellInfo)
		self.spellIcon:SetHighlights(spellInfo, isNew)
		self:UpdateUnplacedHighlight(spellInfo)
		self:UpdateAutocast(spellInfo)

		self.tipIsNew = isNew
		self:ResetCooldown()
		self:UpdateCooldown()

		self.spellIcon:SetSpell(spellInfo)
		self:SetLearnedState(spellInfo)
		self:UpdateRankArrow(spellInfo)
	end;
}
