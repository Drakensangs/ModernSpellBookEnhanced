-- Clique support (the 1.12.1 Ace2 Clique). Its binding panel, normally in
-- the default book, opens beside this one: a "Clique" tab in the two page
-- view, a side button in the one page view. With the panel open, a click on
-- a spell binds it to that button and the held modifiers. Nothing is added
-- while Clique is off (Auto Self Cast on).

local CLIQUE_ICON = "Interface\\AddOns\\Clique\\images\\CliqueIcon"

-- Name of Clique's "Default Friendly" binding set, in the client's language
local function DefaultSetName()
	local ok, name = pcall(function()
		return AceLibrary("AceLocale-2.0"):new("Clique")["DEFAULT_FRIENDLY"]
	end)
	return (ok and name) or "Default Friendly"
end

-- Clique keeps the binding set being edited to itself and only picks it
-- when the default spellbook opens. Its own set menu is used to pick the
-- default set here, on every opening, the same as the default book does.
local function SelectDefaultSet()
	local set = Clique.db and Clique.db.char and Clique.db.char[DefaultSetName()]
	if (type(set) ~= "table") then return end
	local previousThis = this
	this = { value = set }
	local ok, err = pcall(Clique.DropDown_OnClick)
	this = previousThis
	if (not ok) then geterrorhandler()(err) end
end

-- A click on a spell while the panel is open: adds the binding the same
-- way Clique does for the default spell buttons. A spell on the page binds
-- without a rank (Clique then casts the best rank you know), a button in
-- the rank flyout binds that exact rank.
function MSB_CliqueBindSpell(spellInfo, button)
	if (CliqueEditFrame and CliqueEditFrame:IsVisible()) then return end
	if (spellInfo.isPassive or spellInfo.isUnlearned or spellInfo.isTalent) then
		StaticPopup_Show("CLIQUE_PASSIVE_SKILL")
		return
	end
	local set = UIDropDownMenu_GetSelectedValue(CliqueDropDown)
	if (type(set) ~= "table") then return end

	local modifiers = (IsAltKeyDown() and 1 or 0) + (IsControlKeyDown() and 2 or 0) + (IsShiftKeyDown() and 4 or 0)
	if (Clique:CheckBinding(button, modifiers)) then return end

	local rank = nil
	if (spellInfo.isRankEntry) then
		local _, _, number = string.find(spellInfo.bookRank or "", "(%d+)")
		rank = number
	end
	table.insert(set, {
		button = button,
		texture = spellInfo.spellIcon,
		modifiers = modifiers,
		name = spellInfo.spellName,
		rank = rank,
	})
	Clique:ListScrollUpdate()
	Clique:BuildActionTable()
end

-- The parts of Clique this file uses; another Clique version gets no tab
local function IsSupportedClique()
	if (type(Clique) ~= "table" or not CliqueFrame or not CliqueDropDown) then return false end
	for _, method in ipairs({ "Toggle", "CheckBinding", "ListScrollUpdate", "BuildActionTable", "DropDown_OnClick" }) do
		if (type(Clique[method]) ~= "function") then return false end
	end
	return type(Clique.db) == "table" and type(Clique.db.char) == "table"
end

-- With the game's Auto Self Cast option on, Clique stays off for the session
-- (it asks you to turn the option off) and adds nothing to the default book.
-- Its spell list is read only once it is on, so that tells.
local function IsCliqueOn()
	return type(Clique.spellbook) == "table"
end

function MSB_SetupCliqueIntegration(spellBook)
	if (not IsSupportedClique() or not IsCliqueOn()) then return end
	local frame = spellBook.frame

	-- Out of the hidden default book; kept on screen beside this one
	CliqueFrame:SetParent(UIParent)
	CliqueFrame:Hide()
	CliqueFrame:SetClampedToScreen(true)
	CliqueFrame:SetFrameStrata("HIGH")
	CliqueFrame:HookScript("OnShow", function() spellBook:UpdateCompatButtons() end)
	CliqueFrame:HookScript("OnHide", function() spellBook:UpdateCompatButtons() end)

	-- Runs on this opening too (callbacks follow the integration setup)
	spellBook:AddOnShowCallback(SelectDefaultSet)

	frame.cliqueTab = spellBook:AddCompatAction({
		name = "Clique",
		tabLabel = "Clique",
		tooltip = "Clique",
		icon = CLIQUE_ICON,
		onClick = function()
			Clique:Toggle()
			if (CliqueFrame:IsShown()) then spellBook:PlaceCompatPanel(CliqueFrame) end
		end,
		isOpen = function() return CliqueFrame:IsShown() end,
	})

	-- The panel closes with the book, as it does with the default one
	frame:HookScript("OnHide", function()
		if (CliqueFrame:IsShown()) then Clique:Toggle() end
	end)
end
