-- MSB_CIcon: an icon widget without spellbook logic: socket, icon, border,
-- hover highlight, cooldown swipe and countdown numbers. Callers use the
-- parts directly (icon.border:SetTexture(...)); methods cover only changes
-- that touch several parts.

local DEFAULT_ICON_SIZE = 28
local COUNTDOWN_FONT_SIZE = 13		-- for a 28 px icon
-- No numbers for cooldowns this short (the global cooldown), as in the game
local MIN_COUNTDOWN_DURATION = 2
local COUNTDOWN_UPDATE_INTERVAL = 0.1

-- Time left as the game writes it: 57, 1:56, 3m, 2h, 2d
local Up, Down = Enum.NumericRuleFormatRounding.Up, Enum.NumericRuleFormatRounding.Down
local countdownFormat = C_StringUtil.CreateNumericRuleFormatter()
countdownFormat:SetBreakpoints({
	{ threshold = 0, step = 1, rounding = Up, format = "%d" },
	{ threshold = 60, step = 1, rounding = Up, format = "%d:%02d",
		components = { { div = 60, step = 1, rounding = Down }, { mod = 60, step = 1, rounding = Down } } },
	{ threshold = 120, format = "%dm", components = { { div = 60, step = 1, rounding = Up } } },
	{ threshold = 3600, format = "%dh", components = { { div = 3600, step = 1, rounding = Up } } },
	{ threshold = 86400, format = "%dd", components = { { div = 86400, step = 1, rounding = Up } } },
})

MSB_class "MSB_CIcon"
{
	__init = function(self, parent, size)
		self.parent = parent
		self.size = size or DEFAULT_ICON_SIZE

		self.socket = parent:CreateTexture(nil, "ARTWORK")
		self.socket:SetWidth(self.size)
		self.socket:SetHeight(self.size)
		self.socket:SetPoint("CENTER", parent, "CENTER", 0, 0)

		self.icon = parent:CreateTexture(nil, "OVERLAY")
		self.icon:SetWidth(self.size)
		self.icon:SetHeight(self.size)
		self.icon:SetPoint("CENTER", parent, "CENTER", 0, 0)
		self.icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)

		self.border_frame = CreateFrame("Frame", nil, parent)
		self.border_frame:SetWidth(self.size)
		self.border_frame:SetHeight(self.size)
		self.border_frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
		self.border_frame:SetFrameLevel(parent:GetFrameLevel() + 3)
		self.border = self.border_frame:CreateTexture(nil, "OVERLAY")
		self.border:SetAllPoints(self.border_frame)

		self.hover_frame, self.hover_glow = MSB_CreateGlow(parent, self.size, nil, 4, "Interface\\Buttons\\CheckButtonHilight")
		self.hover_frame:SetPoint("CENTER", self.icon, "CENTER", 0, 0)
		self.hover_frame:Show()
		self.hover_glow:SetAlpha(0.5)
		self.hover_glow:Hide()

		-- Cooldown swipe. The numbers come from a ClassicAPI text binding,
		-- independent of the game's own countdown setting.
		self.cooldown = CreateFrame("Cooldown", nil, parent)
		self.cooldown:SetPoint("TOPLEFT", self.icon, "TOPLEFT", 0, 0)
		self.cooldown:SetPoint("BOTTOMRIGHT", self.icon, "BOTTOMRIGHT", 0, 0)
		self.cooldown:SetFrameLevel(parent:GetFrameLevel() + 2)
		self.cooldown:SetDrawEdge(false)
		self.cooldown:SetHideCountdownNumbers(true)
		self.cooldown:Hide()

		-- On its own frame above the border, so hiding the border keeps the numbers
		self.countdownFrame = CreateFrame("Frame", nil, parent)
		self.countdownFrame:SetAllPoints(self.icon)
		self.countdownFrame:SetFrameLevel(parent:GetFrameLevel() + 4)
		self.countdownText = self.countdownFrame:CreateFontString(nil, "OVERLAY")
		self.countdownText:SetPoint("CENTER", self.icon, "CENTER", 0, 0)
		self.countdownText:SetFont(MSB_GetFont(), COUNTDOWN_FONT_SIZE, "OUTLINE")
		self.countdownText:SetTextColor(1, 1, 1)

		self.countdownTime = C_DurationUtil.CreateDuration()
		self.countdown = C_DurationUtil.CreateDurationTextBinding()
		self.countdown:SetFontString(self.countdownText)
		self.countdown:SetDuration(self.countdownTime)
		self.countdown:SetFormatter(countdownFormat)
		self.countdown:SetExpiredText("")
		self.countdown:SetZeroDurationText("")
		self.countdown:SetUpdateInterval(COUNTDOWN_UPDATE_INTERVAL)

		-- An enabled binding updates every interval until disabled: stop it
		-- whenever the icon can't be seen
		local icon = self
		self.cooldown:SetScript("OnHide", function() icon:StopCountdown() end)
		parent:HookScript("OnHide", function() icon:StopCountdown() end)
		parent:HookScript("OnShow", function() icon:StartCountdown() end)
	end;

	-- start/duration in seconds, as GetSpellCooldown returns them
	SetCooldown = function(self, start, duration, enabled)
		if (enabled and start and duration and start > 0 and duration > 0) then
			self.cooldown:SetCooldown(start, duration)
			self.countdownTime:SetTimeFromStart(start, duration)
			self.hasCountdown = duration > MIN_COUNTDOWN_DURATION
			self:StartCountdown()
		else
			self.cooldown:Clear()
			self.hasCountdown = false
			self:StopCountdown()
		end
	end;

	StartCountdown = function(self)
		if (self.hasCountdown and not self.countdownTime:HasExpired() and self.parent:IsVisible()) then
			self.countdown:SetEnabled(true)
		end
	end;

	StopCountdown = function(self)
		if (self.countdown:IsEnabled()) then self.countdown:SetEnabled(false) end
		self.countdownText:SetText("")
	end;

	SetDesaturated = function(self, desaturated)
		self.socket:SetDesaturated(desaturated)
		self.icon:SetDesaturated(desaturated)
		self.border:SetDesaturated(desaturated)
		self.hover_glow:SetDesaturated(desaturated)
	end;
}
