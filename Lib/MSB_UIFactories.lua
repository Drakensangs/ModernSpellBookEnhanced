-- Shared UI pieces: glows and badges (returned hidden, frame level relative
-- to the parent), the shared pulse animation and the training cost line.

function MSB_CreateGlow(parent, size, color, frameLevel, texture)
	local glowFrame = CreateFrame("Frame", nil, parent)
	glowFrame:SetWidth(size)
	glowFrame:SetHeight(size)
	glowFrame:SetFrameLevel(parent:GetFrameLevel() + (frameLevel or 5))
	glowFrame:Hide()

	local glowTex = glowFrame:CreateTexture(nil, "OVERLAY")
	glowTex:SetAllPoints(glowFrame)
	glowTex:SetTexture(texture or "Interface\\Buttons\\CheckButtonGlow")
	glowTex:SetBlendMode("ADD")
	if (color) then
		glowTex:SetVertexColor(color[1], color[2], color[3])
	end

	return glowFrame, glowTex
end

-- Small label ("New", "Train"), at least 32 wide and wider for longer words
function MSB_CreateBadge(parent, text, bgColor, borderColor, frameLevel)
	local badge = CreateFrame("Frame", nil, parent)
	badge:SetWidth(32)
	badge:SetHeight(14)
	badge:SetFrameLevel(parent:GetFrameLevel() + (frameLevel or 7))
	badge:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 8, edgeSize = 8,
		insets = { left = 2, right = 2, top = 2, bottom = 2 }
	})
	badge:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
	badge:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
	badge:Hide()

	local badgeText = badge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	badgeText:SetPoint("CENTER", badge, "CENTER", 0, 1)
	badgeText:SetFont(MSB_GetFont(), 8)
	badgeText:SetText(text)
	badgeText:SetTextColor(1, 1, 1)
	badge:SetWidth(math.max(32, math.ceil(badgeText:GetStringWidth()) + 10))

	return badge, badgeText
end

-- ==================== PULSE DRIVER ====================
-- One OnUpdate pulses every registered texture in step (1 s period,
-- alpha 1 -> 0.5 -> 1) and stops itself while none of them is visible.

local pulseTextures = {}
local pulseClock = 0
local pulseDriver = CreateFrame("Frame")
pulseDriver:Hide()
pulseDriver:SetScript("OnUpdate", function()
	pulseClock = math.mod(pulseClock + (arg1 or 0), 1)
	local u
	if (pulseClock < 0.5) then u = 1 - pulseClock / 0.5 else u = (pulseClock - 0.5) / 0.5 end
	local alpha = 1 - 0.5 * u * u
	local any = false
	for tex in pairs(pulseTextures) do
		if (tex:IsVisible()) then
			tex:SetAlpha(alpha)
			any = true
		elseif (not tex:GetParent():IsShown()) then
			pulseTextures[tex] = nil
		end
	end
	if (not any) then pulseDriver:Hide() end
end)

function MSB_StartPulse(texture)
	pulseTextures[texture] = true
	pulseDriver:Show()
end

function MSB_StopPulse(texture)
	pulseTextures[texture] = nil
	texture:SetAlpha(1)
end

-- ==================== TRAINING COST ====================

-- "Training cost: 1g 20s" (the cost seen at the last trainer visit), red
-- when you can't afford it
function MSB_AddTrainingCostLine(tooltip, cost)
	if (not cost) then return end
	if (cost <= 0) then
		tooltip:AddDoubleLine(MSB_L.TRAINING_COST, MSB_L.TRAINING_FREE, 1, 0.82, 0, 1, 1, 1)
		return
	end
	local r, g, b = 1, 1, 1
	if (GetMoney() < cost) then r, g, b = 1, 0.2, 0.2 end
	tooltip:AddDoubleLine(MSB_L.TRAINING_COST, GetCoinTextureString(cost), 1, 0.82, 0, r, g, b)
end
