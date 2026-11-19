-- MSB_CSpellBookIcon: MSB_CIcon plus the spellbook visuals: glows (new,
-- trainable, active stance), the pulse on spells on no action bar, pet
-- autocast corners and sparks, the New and Train badges, round passives,
-- and the unlearned icon cut to the frame's opening.

local SPELLBOOK_ASSETS = "Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\"
local DEFAULT_ICON_SIZE = 28
local DEFAULT_SOCKET_SIZE = 22

-- Square socket under the icon when the icon frame is off
local SOCKET_TEXTURE = SPELLBOOK_ASSETS .. "spell-socket"

-- Passive icons are round, at the scale of a normal 28 px icon and shown to
-- the edge of the square frame's opening (13.3 from the centre, hiding the
-- icon's dark edge). Their ring or socket starts at that edge. Texcoords
-- are each quad's size times the normal icon's scale.

-- Passives with the icon frame off: round copy of the square socket
local PASSIVE_SOCKET_TEXTURE = SPELLBOOK_ASSETS .. "passive-socket"
local PASSIVE_SOCKET_SIZE = 34
-- Round icon in the socket: the mask spans the quad, so the quad is the disc
local PASSIVE_SOCKET_ICON_SIZE = 26.6
local PASSIVE_SOCKET_TEXCOORD = { 0.063, 0.937, 0.063, 0.937 }
-- Round glow, its line on the socket's edge as on the gold ring's
local PASSIVE_SOCKET_GLOW_SIZE = 53

-- Passives with the icon frame on: gold ring (64x64 art for a ~36 px ring)
local PASSIVE_RING_TEXTURE = SPELLBOOK_ASSETS .. "passive-ring"
local PASSIVE_RING_PADDING = 8
-- Icon under the ring: a 30 px quad clipped to the opening by PASSIVE_RING_MASK
local PASSIVE_ICON_SIZE = 30
local PASSIVE_TEXCOORD = { 1 / 140, 139 / 140, 1 / 140, 139 / 140 }
-- The ring's opening, on the ring's rect: nothing of the icon shows through
-- a faded ring
local PASSIVE_RING_MASK = SPELLBOOK_ASSETS .. "passive-ring-mask"
-- Hover highlight: the game's CheckButtonHilight, or a round copy of it for
-- passives, sized to sit as far from the opening as the square one
local HOVER_TEXTURE = "Interface\\Buttons\\CheckButtonHilight"
local PASSIVE_HOVER_TEXTURE = SPELLBOOK_ASSETS .. "passive-highlight"
local PASSIVE_HOVER_SIZE = 28
local PASSIVE_SOCKET_HOVER_SIZE = PASSIVE_SOCKET_ICON_SIZE
-- Glow of new and trainable spells: CheckButtonGlow, or a round copy whose
-- line sits on the gold ring's outer edge
local GLOW_TEXTURE = "Interface\\Buttons\\CheckButtonGlow"
local PASSIVE_GLOW_TEXTURE = SPELLBOOK_ASSETS .. "passive-glow"
local GLOW_SIZE = 60
-- Square icons crop their built-in edge (same values as MSB_CIcon)
local ICON_TEXCOORD = { 0.04, 0.96, 0.04, 0.96 }
-- Unlearned spells: greyed, then tinted slightly warm to suit the page
local UNLEARNED_TINT = { 1, 0.93, 0.8 }
-- Unlearned passives are tinted instead: ClassicAPI greys with a pixel
-- shader, which skips the round mask, so a greyed passive turns square
local UNLEARNED_PASSIVE_TINT = { 0.62, 0.57, 0.5 }

-- ============== Unlearned icon inside the square icon frame ==============
-- The frame is half transparent on unlearned spells, so the square icon
-- would show through its cut corners. A mask can't cut it (the grey shader
-- skips masks), so the icon is drawn as 7 pieces: 3 solid ones filling the
-- opening and 4 strips along the cut corners, faded across the edge with
-- vertex alpha (kept by the shader). Touching pieces share exact corners.
--
-- Opening of spellbook-frame (128 px drawn at 46), in UI units from the
-- icon's centre (+y up), at half coverage of the black inner line
local OCT_LEFT, OCT_RIGHT, OCT_TOP, OCT_BOTTOM = -13.295, 13.284, 13.299, -13.371
-- Corner cuts of the opening: h along the top or bottom edge, v along the side
local OCT_CUTS = {
	TL = { h = 2.641, v = 2.875 }, TR = { h = 2.873, v = 2.923 },
	BL = { h = 3.093, v = 2.320 }, BR = { h = 3.328, v = 2.423 },
}
-- Width of the fade across a cut corner, centred on the edge (about 1 px)
local OCT_RAMP = 0.8
-- texture:SetVertexOffset corners (ClassicAPI's UPPER_LEFT_VERTEX, ... values)
local UPPER_LEFT, LOWER_LEFT, UPPER_RIGHT, LOWER_RIGHT = 1, 2, 3, 4

-- Texture coordinate of a point (UI units from the centre) on the cropped
-- 28 px icon, so each piece shows the pixels the square icon had there
local function OctagonTexCoord(x, y)
	local half = DEFAULT_ICON_SIZE / 2
	local u = ICON_TEXCOORD[1] + (x + half) / DEFAULT_ICON_SIZE * (ICON_TEXCOORD[2] - ICON_TEXCOORD[1])
	local v = ICON_TEXCOORD[3] + (half - y) / DEFAULT_ICON_SIZE * (ICON_TEXCOORD[4] - ICON_TEXCOORD[3])
	return u, v
end

-- The pieces: anchors on the opening's rect, optional width, vertex offsets
-- (+y up) and the drawn corners (UL, LL, UR, LR) for the texture coordinates.
-- ramp: which side of a strip is the outer edge (alpha 0).
local OCTAGON_PIECES = (function()
	local L, R, T, B = OCT_LEFT, OCT_RIGHT, OCT_TOP, OCT_BOTTOM
	-- Cuts moved in by half the fade, so the fade is centred on the frame's edge
	local cut = {}
	for name, c in pairs(OCT_CUTS) do
		local len = math.sqrt(c.h * c.h + c.v * c.v)
		cut[name] = { h = c.h + OCT_RAMP / 2 * len / c.v, v = c.v + OCT_RAMP / 2 * len / c.h }
	end
	-- One height for both top cuts (and both bottom ones): the caps stay rects
	local topV = (cut.TL.v + cut.TR.v) / 2
	local botV = (cut.BL.v + cut.BR.v) / 2
	local hTL, hTR, hBL, hBR = cut.TL.h, cut.TR.h, cut.BL.h, cut.BR.h
	-- Outward normal of each cut, times the fade width
	local function Normal(h, v, sx, sy)
		local len = math.sqrt(h * h + v * v)
		return OCT_RAMP * sx * v / len, OCT_RAMP * sy * h / len
	end
	local nTLx, nTLy = Normal(hTL, topV, -1, 1)
	local nTRx, nTRy = Normal(hTR, topV, 1, 1)
	local nBLx, nBLy = Normal(hBL, botV, -1, -1)
	local nBRx, nBRy = Normal(hBR, botV, 1, -1)
	local W = 1 -- width of a strip's own rect, moved onto the cut by its offsets

	local pieces = {
		{ -- top cap
			anchors = { { "TOPLEFT", "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", "TOPRIGHT", 0, -topV } },
			offsets = { [UPPER_LEFT] = { hTL, 0 }, [UPPER_RIGHT] = { -hTR, 0 } },
			corners = { { L + hTL, T }, { L, T - topV }, { R - hTR, T }, { R, T - topV } },
		},
		{ -- middle band
			anchors = { { "TOPLEFT", "TOPLEFT", 0, -topV }, { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, botV } },
			offsets = {},
			corners = { { L, T - topV }, { L, B + botV }, { R, T - topV }, { R, B + botV } },
		},
		{ -- bottom cap
			anchors = { { "TOPLEFT", "BOTTOMLEFT", 0, botV }, { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 } },
			offsets = { [LOWER_LEFT] = { hBL, 0 }, [LOWER_RIGHT] = { -hBR, 0 } },
			corners = { { L, B + botV }, { L + hBL, B }, { R, B + botV }, { R - hBR, B } },
		},
		{ -- top-left strip: right side on the cut, left side outside it
			anchors = { { "TOPRIGHT", "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", "TOPLEFT", 0, -topV } },
			width = W,
			offsets = {
				[UPPER_LEFT] = { hTL + nTLx + W, nTLy },
				[LOWER_LEFT] = { nTLx + W, nTLy },
				[UPPER_RIGHT] = { hTL, 0 },
			},
			corners = { { L + hTL + nTLx, T + nTLy }, { L + nTLx, T - topV + nTLy }, { L + hTL, T }, { L, T - topV } },
			ramp = "left",
		},
		{ -- top-right strip: left side on the cut
			anchors = { { "TOPLEFT", "TOPRIGHT", 0, 0 }, { "BOTTOMLEFT", "TOPRIGHT", 0, -topV } },
			width = W,
			offsets = {
				[UPPER_LEFT] = { -hTR, 0 },
				[UPPER_RIGHT] = { -hTR + nTRx - W, nTRy },
				[LOWER_RIGHT] = { nTRx - W, nTRy },
			},
			corners = { { R - hTR, T }, { R, T - topV }, { R - hTR + nTRx, T + nTRy }, { R + nTRx, T - topV + nTRy } },
			ramp = "right",
		},
		{ -- bottom-left strip: right side on the cut
			anchors = { { "TOPRIGHT", "BOTTOMLEFT", 0, botV }, { "BOTTOMRIGHT", "BOTTOMLEFT", 0, 0 } },
			width = W,
			offsets = {
				[UPPER_LEFT] = { nBLx + W, nBLy },
				[LOWER_LEFT] = { hBL + nBLx + W, nBLy },
				[LOWER_RIGHT] = { hBL, 0 },
			},
			corners = { { L + nBLx, B + botV + nBLy }, { L + hBL + nBLx, B + nBLy }, { L, B + botV }, { L + hBL, B } },
			ramp = "left",
		},
		{ -- bottom-right strip: left side on the cut
			anchors = { { "TOPLEFT", "BOTTOMRIGHT", 0, botV }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 0 } },
			width = W,
			offsets = {
				[LOWER_LEFT] = { -hBR, 0 },
				[UPPER_RIGHT] = { nBRx - W, nBRy },
				[LOWER_RIGHT] = { -hBR + nBRx - W, nBRy },
			},
			corners = { { R, B + botV }, { R - hBR, B }, { R + nBRx, B + botV + nBRy }, { R - hBR + nBRx, B + nBRy } },
			ramp = "right",
		},
	}
	for _, piece in ipairs(pieces) do
		local c = piece.corners
		local ulx, uly = OctagonTexCoord(c[1][1], c[1][2])
		local llx, lly = OctagonTexCoord(c[2][1], c[2][2])
		local urx, ury = OctagonTexCoord(c[3][1], c[3][2])
		local lrx, lry = OctagonTexCoord(c[4][1], c[4][2])
		piece.texCoord = { ulx, uly, llx, lly, urx, ury, lrx, lry }
	end
	return pieces
end)()

-- Pulse traced on the icon frame's octagon (art from DragonUI), sized for a 28 px icon
local UNPLACED_TEXTURE = SPELLBOOK_ASSETS .. "unplaced-glow"
local UNPLACED_SIZE = 39
local UNPLACED_TEXCOORD = 127 / 128

-- Pet autocast: gold corners when the spell can autocast, sparks circling
-- the icon while it's on (as on the pet bar)
local AUTOCAST_CORNERS_TEXTURE = SPELLBOOK_ASSETS .. "autocast-corners"
local AUTOCAST_CORNERS_TEXCOORD = 90 / 128
local AUTOCAST_CORNERS_SIZE = 30
local SPARK_TEXTURE = SPELLBOOK_ASSETS .. "autocast-spark"
-- Round passive icons: the game's round portrait mask (ClassicAPI SetMask)
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SPARK_SIZES = { 12, 9, 6, 4 }
local SPARK_LAP_SECONDS = { 8, 16, 24, 32 }

-- One driver moves the sparks of every visible pet spell
local sparkEmitters = {}
local sparkClock = 0
local sparkDriver = CreateFrame("Frame")
sparkDriver:Hide()

-- Point at fraction t (0..1) of the way around a square, from its top-left corner
local function Perimeter(t, side)
	local u = math.mod(t, 1) * 4
	local edge = math.floor(u)
	local f = u - edge
	if (edge == 0) then return f * side, 0 end
	if (edge == 1) then return side, -f * side end
	if (edge == 2) then return side - f * side, -side end
	return 0, f * side - side
end

sparkDriver:SetScript("OnUpdate", function()
	sparkClock = sparkClock + arg1
	local any = false
	for emitter in pairs(sparkEmitters) do
		if (emitter:IsVisible()) then
			any = true
			-- The size it was made with: GetWidth includes the scale, which
			-- moved the sparks off the icon on a resized book
			local side = emitter.side
			for _, dot in ipairs(emitter.dots) do
				dot:SetPoint("CENTER", emitter, "TOPLEFT", Perimeter(sparkClock / dot.lap + dot.lane, side))
			end
		elseif (not emitter:IsShown()) then
			sparkEmitters[emitter] = nil
		end
	end
	if (not any) then sparkDriver:Hide() end
end)

local function CreateSparks(parent, anchor, side)
	local emitter = CreateFrame("Frame", nil, parent)
	emitter:SetWidth(side)
	emitter:SetHeight(side)
	emitter:SetPoint("CENTER", anchor, "CENTER", 0, 0)
	emitter.side = side
	emitter.dots = {}
	for lane = 0, 3 do
		for size = 1, 4 do
			local dot = emitter:CreateTexture(nil, "OVERLAY")
			dot:SetWidth(SPARK_SIZES[size])
			dot:SetHeight(SPARK_SIZES[size])
			dot:SetTexture(SPARK_TEXTURE)
			dot:SetBlendMode("ADD")
			dot:SetVertexColor(0.95, 0.95, 0.32)
			dot.lap = SPARK_LAP_SECONDS[size]
			dot.lane = lane / 4
			table.insert(emitter.dots, dot)
		end
	end
	emitter:Hide()
	return emitter
end

MSB_class "MSB_CSpellBookIcon"
:extends("MSB_CIcon")
{
	__init = function(self, parent)
		MSB_CIcon.__init(self, parent, DEFAULT_ICON_SIZE)

		-- Spellbook socket
		self.socket:SetTexture(SPELLBOOK_ASSETS .. "spell-socket")
		self.socket:SetHeight(self.size + DEFAULT_SOCKET_SIZE)
		self.socket:SetWidth(self.size + DEFAULT_SOCKET_SIZE)

		-- Glow of new and trainable spells (colored per use)
		self.glow_frame, self.glow_tex = MSB_CreateGlow(parent, GLOW_SIZE, nil, 15)

		-- Pulse of spells on no action bar: above the icon frame, below the rank arrow
		self.unplaced_frame = CreateFrame("Frame", nil, parent)
		self.unplaced_frame:SetFrameLevel(parent:GetFrameLevel() + 5)
		self.unplaced_frame:SetAllPoints(self.icon)
		self.unplaced = self.unplaced_frame:CreateTexture(nil, "OVERLAY")
		self.unplaced:SetTexture(UNPLACED_TEXTURE)
		self.unplaced:SetTexCoord(0, UNPLACED_TEXCOORD, 0, UNPLACED_TEXCOORD)
		self.unplaced:SetBlendMode("ADD")
		self.unplaced:SetWidth(UNPLACED_SIZE)
		self.unplaced:SetHeight(UNPLACED_SIZE)
		self.unplaced:SetPoint("CENTER", self.icon, "CENTER", 0, 0)
		self.unplaced_frame:Hide()

		-- Pet autocast corners and sparks, above the icon frame
		self.autocast_frame = CreateFrame("Frame", nil, parent)
		self.autocast_frame:SetFrameLevel(parent:GetFrameLevel() + 6)
		self.autocast_frame:SetAllPoints(self.icon)
		self.autocast_corners = self.autocast_frame:CreateTexture(nil, "OVERLAY")
		self.autocast_corners:SetTexture(AUTOCAST_CORNERS_TEXTURE)
		self.autocast_corners:SetTexCoord(0, AUTOCAST_CORNERS_TEXCOORD, 0, AUTOCAST_CORNERS_TEXCOORD)
		self.autocast_corners:SetWidth(AUTOCAST_CORNERS_SIZE)
		self.autocast_corners:SetHeight(AUTOCAST_CORNERS_SIZE)
		self.autocast_corners:SetPoint("CENTER", self.icon, "CENTER", 0, 0)
		self.autocast_corners:Hide()
		self.autocast_sparks = CreateSparks(self.autocast_frame, self.icon, self.size)

		-- Unlearned icon cut to the square frame's opening (see OCTAGON_PIECES),
		-- shown instead of self.icon while the frame is drawn faded
		self.octagon = CreateFrame("Frame", nil, parent)
		self.octagon:SetWidth(OCT_RIGHT - OCT_LEFT)
		self.octagon:SetHeight(OCT_TOP - OCT_BOTTOM)
		self.octagon:SetPoint("CENTER", parent, "CENTER", (OCT_LEFT + OCT_RIGHT) / 2, (OCT_TOP + OCT_BOTTOM) / 2)
		self.octagon_pieces = {}
		for _, spec in ipairs(OCTAGON_PIECES) do
			local piece = parent:CreateTexture(nil, "OVERLAY")
			for _, a in ipairs(spec.anchors) do
				piece:SetPoint(a[1], self.octagon, a[2], a[3], a[4])
			end
			if (spec.width) then piece:SetWidth(spec.width) end
			for vertex, offset in pairs(spec.offsets) do
				piece:SetVertexOffset(vertex, offset[1], offset[2])
			end
			piece:SetTexCoord(unpack(spec.texCoord))
			piece.ramp = spec.ramp
			piece:Hide()
			table.insert(self.octagon_pieces, piece)
		end

		-- Clips passive icons to the gold ring's opening
		self.ring_mask = parent:CreateMaskTexture()
		self.ring_mask:SetTexture(PASSIVE_RING_MASK)
		self.ring_mask:SetAllPoints(self.border_frame)
		self.ringMasked = false

		-- "New" badge
		self.badge_new = MSB_CreateBadge(parent, MSB_STR.NEW, {1, 0.878, 0.078, 0.7}, {1, 0.9, 0.1, 0.8}, 12)
		self.badge_new:SetPoint("BOTTOM", parent, "TOP", 0, 2)

		-- "Train" badge
		self.badge_train = MSB_CreateBadge(parent, MSB_L.BADGE_TRAIN, {0, 0.8, 0, 0.4}, {0.1, 0.8, 0.1, 0.8}, 7)
		self.badge_train:SetPoint("BOTTOM", self.icon, "TOP", 0, 2)

		-- Glow of the active stance, form or aura
		self.glow_active_frame = CreateFrame("Frame", nil, parent)
		self.glow_active_frame:SetWidth(self.size + 2)
		self.glow_active_frame:SetHeight(self.size + 2)
		self.glow_active_frame:SetPoint("CENTER", self.icon, "CENTER", 0, 0)
		self.glow_active_frame:SetFrameLevel(parent:GetFrameLevel() + 5)
		self.glow_active = self.glow_active_frame:CreateTexture(nil, "OVERLAY")
		self.glow_active:SetWidth(self.size + 2)
		self.glow_active:SetHeight(self.size + 2)
		self.glow_active:SetAllPoints(self.glow_active_frame)
		self.glow_active:SetTexture("Interface\\Buttons\\CheckButtonHilight")
		self.glow_active:SetBlendMode("ADD")
		self.glow_active:SetAlpha(0)
	end;

	-- ========================= STYLE =============================

	-- Textures and sizes for a spell. Icon frame setting: "Spells" covers the
	-- class and General tabs, "Other" the pet and "Other" tabs.
	SetSpell = function(self, spellInfo)
		local frameSetting = ModernSpellBook_DB.iconFrame
		local showBorder
		if (spellInfo.isUnlearned) then
			showBorder = frameSetting.unlearned
		elseif (ModernSpellBookFrame.selectedTab > MSB_TAB_GENERAL) then
			showBorder = frameSetting.other
		else
			showBorder = frameSetting.spells
		end

		if (showBorder) then
			self.border_frame:Show()
			self.socket:Hide()
		else
			self.border_frame:Hide()
			self.socket:Show()
		end

		local glowSize = GLOW_SIZE
		if (spellInfo.isPassive) then
			-- Round icon at the normal icon's scale (see the passive sizes at the top)
			self.icon:SetTexture(spellInfo.spellIcon)
			self.icon:SetMask(ROUND_MASK)
			self.hover_glow:SetTexture(PASSIVE_HOVER_TEXTURE)
			self.border:SetTexture(PASSIVE_RING_TEXTURE)
			self.border_frame:SetWidth(self.size + PASSIVE_RING_PADDING)
			self.border_frame:SetHeight(self.size + PASSIVE_RING_PADDING)
			if (showBorder) then
				-- Under the gold ring, clipped to its opening
				self.icon:SetTexCoord(PASSIVE_TEXCOORD[1], PASSIVE_TEXCOORD[2], PASSIVE_TEXCOORD[3], PASSIVE_TEXCOORD[4])
				self.icon:SetWidth(PASSIVE_ICON_SIZE)
				self.icon:SetHeight(PASSIVE_ICON_SIZE)
				self:SetRingMask(true)
				self:SetHoverSize(PASSIVE_HOVER_SIZE)
			else
				-- In the round socket
				self.icon:SetTexCoord(PASSIVE_SOCKET_TEXCOORD[1], PASSIVE_SOCKET_TEXCOORD[2], PASSIVE_SOCKET_TEXCOORD[3], PASSIVE_SOCKET_TEXCOORD[4])
				self.icon:SetWidth(PASSIVE_SOCKET_ICON_SIZE)
				self.icon:SetHeight(PASSIVE_SOCKET_ICON_SIZE)
				self:SetRingMask(false)
				self:SetHoverSize(PASSIVE_SOCKET_HOVER_SIZE)
				glowSize = PASSIVE_SOCKET_GLOW_SIZE
				self.socket:SetTexture(PASSIVE_SOCKET_TEXTURE)
				self.socket:SetWidth(PASSIVE_SOCKET_SIZE)
				self.socket:SetHeight(PASSIVE_SOCKET_SIZE)
			end
			self:SetOctagonShown(false)
		else
			self.icon:SetTexture(spellInfo.spellIcon)
			self.icon:SetMask(nil)
			self:SetRingMask(false)
			self.icon:SetTexCoord(ICON_TEXCOORD[1], ICON_TEXCOORD[2], ICON_TEXCOORD[3], ICON_TEXCOORD[4])
			self.icon:SetWidth(self.size)
			self.icon:SetHeight(self.size)
			self.hover_glow:SetTexture(HOVER_TEXTURE)
			self:SetHoverSize(self.size)
			self.border:SetTexture(SPELLBOOK_ASSETS .. "spellbook-frame")
			self.border_frame:SetWidth(self.size + 18)
			self.border_frame:SetHeight(self.size + 18)
			self.socket:SetTexture(SOCKET_TEXTURE)
			self.socket:SetWidth(self.size + DEFAULT_SOCKET_SIZE)
			self.socket:SetHeight(self.size + DEFAULT_SOCKET_SIZE)
			-- The frame is faded on unlearned spells: cut the icon to its opening
			for _, piece in ipairs(self.octagon_pieces) do piece:SetTexture(spellInfo.spellIcon) end
			self:SetOctagonShown(showBorder and spellInfo.isUnlearned)
		end
		self.glow_frame:SetWidth(glowSize)
		self.glow_frame:SetHeight(glowSize)
	end;

	-- Hover highlight size (the texture fills its frame)
	SetHoverSize = function(self, size)
		self.hover_frame:SetWidth(size)
		self.hover_frame:SetHeight(size)
	end;

	-- Passive icon clipped to the gold ring's opening (on while the ring shows)
	SetRingMask = function(self, on)
		on = on and true or false
		if (on == self.ringMasked) then return end
		if (on) then
			self.icon:AddMaskTexture(self.ring_mask)
		else
			self.icon:RemoveMaskTexture(self.ring_mask)
		end
		self.ringMasked = on
	end;

	-- Cut icon (OCTAGON_PIECES) in place of the square icon
	SetOctagonShown = function(self, shown)
		for _, piece in ipairs(self.octagon_pieces) do
			if (shown) then piece:Show() else piece:Hide() end
		end
		if (shown) then self.icon:Hide() else self.icon:Show() end
	end;

	-- Colour of the cut icon. The strips take it through their alpha gradient
	-- (0 on the outer edge).
	SetOctagonColor = function(self, r, g, b, a)
		for _, piece in ipairs(self.octagon_pieces) do
			if (piece.ramp == "left") then
				piece:SetGradientAlpha("HORIZONTAL", r, g, b, 0, r, g, b, a)
			elseif (piece.ramp == "right") then
				piece:SetGradientAlpha("HORIZONTAL", r, g, b, a, r, g, b, 0)
			else
				piece:SetAlpha(a)
				piece:SetVertexColor(r, g, b)
			end
		end
	end;

	SetDesaturated = function(self, desaturated)
		MSB_CIcon.SetDesaturated(self, desaturated)
		for _, piece in ipairs(self.octagon_pieces) do piece:SetDesaturated(desaturated) end
	end;

	-- ======================= HIGHLIGHTS ==========================

	SetHighlights = function(self, spellInfo, isNew)
		local hl = ModernSpellBook_DB.highlights

		self.glow_frame:Hide()
		self.badge_new:Hide()
		self.badge_train:Hide()

		-- Round glow around passives, square around the other spells
		self.glow_tex:SetTexture(spellInfo.isPassive and PASSIVE_GLOW_TEXTURE or GLOW_TEXTURE)

		-- Newly learned: gold glow and "New" badge
		if (isNew and not spellInfo.isPassive) then
			if (hl and hl.learnedGlow) then
				self.glow_tex:SetVertexColor(1, 1, 1)
				self.glow_frame:ClearAllPoints()
				self.glow_frame:SetPoint("CENTER", self.icon, "CENTER", 0.5, 0)
				self.glow_frame:Show()
			end
			if (hl and hl.learnedBadge) then
				self.badge_new:Show()
			end
			return
		end

		-- Trainable now and not hovered yet: blue glow and green "Train" badge
		if (spellInfo.isTrainerSpell and spellInfo.levelReq and spellInfo.needsMet and not spellInfo.talentBlocked) then
			local alreadySeen = ModernSpellBook_DB.trainSeen[spellInfo.spellID]
			if (spellInfo.levelReq <= UnitLevel("player") and not alreadySeen) then
				if (hl and hl.availableGlow) then
					self.glow_tex:SetVertexColor(0.204, 0.765, 0.922)
					self.glow_frame:ClearAllPoints()
					self.glow_frame:SetPoint("CENTER", self.icon, "CENTER", 0, 0)
					self.glow_frame:Show()
				end
				if (hl and hl.availableBadge) then
					self.badge_train:Show()
				end
			end
		end
	end;

	DismissNewHighlight = function(self)
		self.glow_frame:Hide()
		self.badge_new:Hide()
		self:RefreshUnplacedGlow()
	end;

	-- The pulse hides while the new or trainable glow shows: one cue at a time
	SetUnplaced = function(self, isUnplaced)
		self.isUnplaced = isUnplaced
		self:RefreshUnplacedGlow()
	end;

	RefreshUnplacedGlow = function(self)
		if (self.isUnplaced and not self.glow_frame:IsShown()) then
			self.unplaced_frame:Show()
			MSB_StartPulse(self.unplaced)
		else
			self.unplaced_frame:Hide()
			MSB_StopPulse(self.unplaced)
		end
	end;

	-- ======================== AUTOCAST ===========================

	-- allowed: the pet spell can autocast; enabled: autocast is on
	SetAutocast = function(self, allowed, enabled)
		if (allowed) then
			self.autocast_corners:Show()
		else
			self.autocast_corners:Hide()
		end
		if (enabled) then
			self.autocast_sparks:Show()
			sparkEmitters[self.autocast_sparks] = true
			sparkDriver:Show()
		else
			self.autocast_sparks:Hide()
			sparkEmitters[self.autocast_sparks] = nil
		end
	end;

	DismissAvailableHighlight = function(self, spellInfo)
		-- Either cue may be on its own (the glow and badge are separate options)
		if (self.glow_frame:IsShown() or self.badge_train:IsShown()) then
			self.glow_frame:Hide()
			self.badge_train:Hide()
			ModernSpellBook_DB.trainSeen[spellInfo.spellID] = true
		end
	end;

	-- ===================== LEARNED STATE =========================

	SetLearnedState = function(self, spellInfo)
		if (spellInfo.isUnlearned) then
			self:SetDesaturated(true)
			self.socket:SetAlpha(0.5)
			self.icon:SetAlpha(0.5)
			self.border:SetAlpha(0.5)
			-- Warm the grey towards the parchment tone
			self.icon:SetVertexColor(UNLEARNED_TINT[1], UNLEARNED_TINT[2], UNLEARNED_TINT[3])
			self.border:SetVertexColor(UNLEARNED_TINT[1], UNLEARNED_TINT[2], UNLEARNED_TINT[3])
			self:SetOctagonColor(UNLEARNED_TINT[1], UNLEARNED_TINT[2], UNLEARNED_TINT[3], 0.5)
			if (spellInfo.isPassive) then
				-- Keeps the round mask (see UNLEARNED_PASSIVE_TINT)
				self.icon:SetDesaturated(false)
				self.icon:SetVertexColor(UNLEARNED_PASSIVE_TINT[1], UNLEARNED_PASSIVE_TINT[2], UNLEARNED_PASSIVE_TINT[3])
			end

			self.hover_glow:Hide()
		else
			self:SetDesaturated(false)
			self.socket:SetAlpha(1.0)
			self.icon:SetAlpha(1.0)
			self.border:SetAlpha(1.0)
			self.icon:SetVertexColor(1, 1, 1)
			self.border:SetVertexColor(1, 1, 1)
			self:SetOctagonColor(1, 1, 1, 1)
		end
	end;

	-- ======================== STANCE =============================

	SetStance = function(self, is_active)
		self.glow_active:SetAlpha(is_active and 1 or 0)
	end;
}
