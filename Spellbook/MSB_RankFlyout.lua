-- Rank flyout: a panel opened from the arrow under a spell with more than
-- one learned rank. Each rank is a full spell button (cast, drag, shift-click,
-- tooltip, cooldown, Clique binding).

local ICON_SIZE = 28
local ICON_GAP = 10
local MAX_COLUMNS = 7
local PADDING = 10
local ICONS_TOP = 26        -- room for the title row
local OWNER_GAP = 12        -- gap between the spell and the panel
local BOOK_EDGE = 14        -- keeps the panel inside the window border
local OPEN_DURATION = 0.15  -- fade-in and slide on opening
local OPEN_SLIDE = 8        -- slide distance in pixels
local CLOSE_DURATION = 0.12 -- fade-out and slide back on closing
local BORDER_TEXTURE = "Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\spell_border_gray"

-- Dark panel that still lets a hint of the page through
local BACKGROUND_COLOR = {0.07, 0.055, 0.04, 0.9}
local BORDER_COLOR = {0.82, 0.66, 0.35, 1}
local ICON_BORDER_COLOR = {0.95, 0.78, 0.42}

local function IsMouseOverFrame(frame)
	return frame and frame:IsVisible() and frame:IsMouseOver() and true or false
end

-- ============================================================
-- MSB_CRankButton: one rank in the flyout, with MSB_CSpellItem's click,
-- tooltip, cooldown and drag handlers.
-- ============================================================

MSB_class "MSB_CRankButton"
:extends("MSB_CSpellItem")
{
	__init = function(self, parent, index)
		self.frame = CreateFrame("Button", "ModernSpellBookRankButton" .. index, parent)
		self.frame:SetWidth(ICON_SIZE)
		self.frame:SetHeight(ICON_SIZE)
		self.frame:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp", "Button4Up", "Button5Up")
		self.frame:RegisterForDrag("LeftButton")

		self.spellIcon = MSB_CSpellBookIcon(self.frame)
		self:InstallScripts()

		-- Compact look: thin gold border, no socket
		local icon = self.spellIcon
		icon.socket:Hide()
		icon.border:SetTexture(BORDER_TEXTURE)
		icon.border:SetVertexColor(ICON_BORDER_COLOR[1], ICON_BORDER_COLOR[2], ICON_BORDER_COLOR[3])
		icon.border_frame:SetWidth(ICON_SIZE + 4)
		icon.border_frame:SetHeight(ICON_SIZE + 4)
		icon.border_frame:Show()

		-- Rank number in the bottom-right corner (above the cooldown swipe)
		self.rankLabel = icon.border_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.rankLabel:SetPoint("BOTTOMRIGHT", icon.icon, "BOTTOMRIGHT", -1, 2)
		self.rankLabel:SetFont(MSB_GetFont(), 11, "OUTLINE")
		self.rankLabel:SetTextColor(1, 1, 1)
		self.rankLabel:SetJustifyH("RIGHT")

		self.frame:Hide()
	end;

	Set = function(self, spellInfo, x, y)
		self.spellInfo = spellInfo
		self.tipIsNew = false

		self.spellIcon.icon:SetTexture(spellInfo.spellIcon)
		self.spellIcon:SetDesaturated(false)
		self.spellIcon.icon:SetAlpha(1)
		self.spellIcon.border:SetAlpha(1)
		self.rankLabel:SetText(spellInfo.rankNum or "")

		self:ResetCooldown()
		self:UpdateCooldown()

		self.frame:ClearAllPoints()
		self.frame:SetPoint("TOPLEFT", self.frame:GetParent(), "TOPLEFT", x, y)
		self.frame:Show()
	end;
}

-- ============================================================
-- MSB_CRankFlyout: the one panel of the book.
-- ============================================================

MSB_class "MSB_CRankFlyout"
{
	__init = function(self, book)
		self.book = book
		self.owner = nil
		self.buttons = {}

		self.frame = CreateFrame("Frame", "ModernSpellBookRankFlyout", book)
		-- Above the page's spells and their glows
		self.frame:SetFrameStrata("DIALOG")
		self.frame:SetFrameLevel(book:GetFrameLevel() + 20)
		self.frame:SetBackdrop({
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 }
		})
		self.frame:SetBackdropColor(BACKGROUND_COLOR[1], BACKGROUND_COLOR[2], BACKGROUND_COLOR[3], BACKGROUND_COLOR[4])
		self.frame:SetBackdropBorderColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_COLOR[4])
		-- Takes the clicks on the panel, so spells under it get none
		self.frame:EnableMouse(true)
		self.frame:Hide()

		self.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.title:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PADDING, -9)
		self.title:SetFont(MSB_GetFont(), 10)
		self.title:SetTextColor(1, 0.82, 0)
		self.title:SetJustifyH("LEFT")

		-- A click outside the panel and its arrow closes it (ClassicAPI's
		-- GLOBAL_MOUSE_DOWN, registered while the panel is shown)
		local flyout = self
		self.frame:SetScript("OnEvent", function()
			local overArrow = flyout.owner and IsMouseOverFrame(flyout.owner.rankArrow)
			if (not IsMouseOverFrame(flyout.frame) and not overArrow) then
				flyout:Close()
			end
		end)
		self.frame:SetScript("OnShow", function() flyout.frame:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
		self.frame:SetScript("OnHide", function() flyout.frame:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
		-- Shown only while the panel fades in or out
		self.animator = CreateFrame("Frame", nil, self.frame)
		self.animator:Hide()
		self.animator:SetScript("OnUpdate", function()
			if (flyout.anim) then flyout:StepAnimation(arg1) else flyout.animator:Hide() end
		end)

		-- No fade here: OnUpdate stops in a hidden book, so a fade would
		-- finish only on the next opening, flashing the empty panel
		book:HookScript("OnHide", function()
			flyout:Close(true)
		end)
	end;

	-- ======================= STATE ===============================

	UpdateCooldowns = function(self)
		if (not self.frame:IsShown()) then return end
		for _, button in ipairs(self.buttons) do
			if (button.frame:IsShown()) then
				button:UpdateCooldown()
			end
		end
	end;

	IsOpenFor = function(self, item)
		return self.owner ~= nil and self.owner == item and self.frame:IsShown()
	end;

	Toggle = function(self, item)
		if (self:IsOpenFor(item)) then
			self:Close()
		else
			self:Open(item)
		end
	end;

	-- immediate: hide at once, without the fade
	Close = function(self, immediate)
		if (self.owner) then
			self.owner:SetRankArrowExpanded(false)
			self.owner = nil
		end
		if (not self.frame:IsShown()) then
			self.anim = nil
			return
		end
		if (immediate) then
			self.anim = nil
			self.frame:SetAlpha(1)
			self.frame:Hide()
			return
		end
		if (self.anim and self.anim.closing) then return end
		-- The buttons go at once, so none can be clicked mid-fade
		for _, button in ipairs(self.buttons) do
			button.frame:Hide()
		end
		self:StartCloseAnimation()
	end;

	-- ======================= BUILD ===============================

	GetOrCreateButton = function(self, i)
		local button = self.buttons[i]
		if (not button) then
			button = MSB_CRankButton(self.frame, i)
			self.buttons[i] = button
		end
		return button
	end;

	MakeRankEntry = function(self, rankInfo)
		local entry = {}
		for key, value in pairs(rankInfo) do
			entry[key] = value
		end
		entry.learnedRanks = nil
		entry.isRankEntry = true
		return entry
	end;

	Open = function(self, item)
		local spellInfo = item.spellInfo
		local ranks = spellInfo and spellInfo.learnedRanks
		if (not ranks or table.getn(ranks) < 2) then return end

		self:Close()
		self.owner = item

		local count = table.getn(ranks)
		local rows = math.ceil(count / MAX_COLUMNS)
		local columns = math.ceil(count / rows)

		self.title:SetText(spellInfo.spellName)
		local titleWidth = self.title:GetStringWidth()

		local gridWidth = columns * ICON_SIZE + (columns - 1) * ICON_GAP
		local width = math.max(gridWidth + 2 * PADDING, titleWidth + 2 * PADDING)
		local height = ICONS_TOP + rows * ICON_SIZE + (rows - 1) * ICON_GAP + PADDING + 2
		local gridX = math.floor((width - gridWidth) / 2)

		for i = 1, count do
			local column = math.mod(i - 1, columns)
			local row = math.floor((i - 1) / columns)
			self:GetOrCreateButton(i):Set(
				self:MakeRankEntry(ranks[i]),
				gridX + column * (ICON_SIZE + ICON_GAP),
				-(ICONS_TOP + row * (ICON_SIZE + ICON_GAP))
			)
		end
		for i = count + 1, table.getn(self.buttons) do
			self.buttons[i].frame:Hide()
		end

		self.frame:SetWidth(width)
		self.frame:SetHeight(height)
		self:Position(item, width, height, gridX)

		item:SetRankArrowExpanded(true)
		self:StartAnimation()
		self.frame:Show()
	end;

	-- ======================= ANIMATION ===========================

	-- Fades in from slightly closer to the spell, easing into place
	StartAnimation = function(self)
		local point, relativeTo, relativePoint, x, y = self.frame:GetPoint(1)
		if (not point) then return end
		self.anim = {
			elapsed = 0,
			point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y,
			-- A panel below the spell slides down, a flipped one slides up
			dy = self.isFlipped and -OPEN_SLIDE or OPEN_SLIDE,
		}
		self.animator:Show()
		self:ApplyAnimation(0)
	end;

	StepAnimation = function(self, elapsed)
		local anim = self.anim
		anim.elapsed = anim.elapsed + elapsed
		if (anim.closing) then
			local t = anim.elapsed / CLOSE_DURATION
			if (t >= 1) then
				self:FinishClose()
			else
				self:ApplyCloseAnimation(t * t)   -- ease-in
			end
			return
		end
		local t = anim.elapsed / OPEN_DURATION
		if (t >= 1) then
			self:StopAnimation()
		else
			self:ApplyAnimation(1 - (1 - t) * (1 - t) * (1 - t))   -- ease-out
		end
	end;

	ApplyAnimation = function(self, progress)
		local anim = self.anim
		self.frame:SetAlpha(progress)
		self.frame:ClearAllPoints()
		self.frame:SetPoint(anim.point, anim.relativeTo, anim.relativePoint,
			anim.x, anim.y + anim.dy * (1 - progress))
	end;

	-- Jumps to the end state of the running animation
	StopAnimation = function(self)
		local anim = self.anim
		if (not anim) then return end
		if (anim.closing) then
			self:FinishClose()
			return
		end
		self.anim = nil
		self.frame:SetAlpha(1)
		self.frame:ClearAllPoints()
		self.frame:SetPoint(anim.point, anim.relativeTo, anim.relativePoint, anim.x, anim.y)
	end;

	-- Fades out, sliding back the way the panel came
	StartCloseAnimation = function(self)
		local point, relativeTo, relativePoint, x, y = self.frame:GetPoint(1)
		if (not point) then
			self:FinishClose()
			return
		end
		self.anim = {
			closing = true,
			elapsed = 0,
			alpha = self.frame:GetAlpha() or 1,
			point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y,
			dy = self.isFlipped and -OPEN_SLIDE or OPEN_SLIDE,
		}
		self.animator:Show()
		self:ApplyCloseAnimation(0)
	end;

	ApplyCloseAnimation = function(self, progress)
		local anim = self.anim
		self.frame:SetAlpha(anim.alpha * (1 - progress))
		self.frame:ClearAllPoints()
		self.frame:SetPoint(anim.point, anim.relativeTo, anim.relativePoint,
			anim.x, anim.y + anim.dy * progress)
	end;

	-- End of the closing fade: hides the panel
	FinishClose = function(self)
		local anim = self.anim
		self.anim = nil
		self.frame:SetAlpha(1)
		if (anim) then
			self.frame:ClearAllPoints()
			self.frame:SetPoint(anim.point, anim.relativeTo, anim.relativePoint, anim.x, anim.y)
		end
		self.frame:Hide()
	end;

	-- Below the spell, first rank under its icon, kept inside the window;
	-- above the spell when there's no room below.
	Position = function(self, item, width, height, gridX)
		local book = self.book
		local owner = item.frame
		self.frame:ClearAllPoints()
		self.isFlipped = false

		local bookLeft, bookTop = book:GetLeft(), book:GetTop()
		local ownerLeft, ownerTop, ownerBottom = owner:GetLeft(), owner:GetTop(), owner:GetBottom()
		if (not bookLeft or not bookTop or not ownerLeft or not ownerTop or not ownerBottom) then
			self.frame:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", -gridX, -OWNER_GAP)
			return
		end

		local x = (ownerLeft - bookLeft) - gridX
		x = math.max(BOOK_EDGE, math.min(x, book:GetWidth() - BOOK_EDGE - width))

		local y = (ownerBottom - bookTop) - OWNER_GAP
		if (y - height < -(book:GetHeight() - BOOK_EDGE)) then
			y = (ownerTop - bookTop) + OWNER_GAP + height
			self.isFlipped = true
		end

		self.frame:SetPoint("TOPLEFT", book, "TOPLEFT", x, y)
	end;
}
