-- Search box: filters the book as you type (name, rank, section, "talent",
-- description). Placeholder text, search icon and clear button; a click
-- anywhere else ends typing.

local BUTTONS = "Interface\\AddOns\\ModernSpellBook\\Assets\\Buttons\\"

MSB_class "MSB_CSearchBar"
{
	__init = function(self, parent, placeholderText, onTextChanged)
		self.frame = CreateFrame("EditBox", "ModernSpellBookFrameSearchBar", parent)
		self.frame:SetWidth(200)
		self.frame:SetHeight(20)
		self.frame:SetAutoFocus(false)
		self.frame:SetFontObject(ChatFontNormal)
		self.frame:SetTextInsets(16, 20, 0, 0)

		-- Background
		local left = self.frame:CreateTexture(nil, "BACKGROUND")
		left:SetTexture("Interface\\Common\\Common-Input-Border")
		left:SetWidth(8)
		left:SetHeight(20)
		left:SetPoint("LEFT", self.frame, "LEFT", -5, 0)
		left:SetTexCoord(0, 0.0625, 0, 0.625)

		local right = self.frame:CreateTexture(nil, "BACKGROUND")
		right:SetTexture("Interface\\Common\\Common-Input-Border")
		right:SetWidth(8)
		right:SetHeight(20)
		right:SetPoint("RIGHT", self.frame, "RIGHT", 5, 0)
		right:SetTexCoord(0.9375, 1, 0, 0.625)

		local mid = self.frame:CreateTexture(nil, "BACKGROUND")
		mid:SetTexture("Interface\\Common\\Common-Input-Border")
		mid:SetWidth(10)
		mid:SetHeight(20)
		mid:SetPoint("LEFT", left, "RIGHT", 0, 0)
		mid:SetPoint("RIGHT", right, "LEFT", 0, 0)
		mid:SetTexCoord(0.0625, 0.9375, 0, 0.625)

		-- Search icon
		self.searchIcon = self.frame:CreateTexture(nil, "OVERLAY")
		self.searchIcon:SetWidth(14)
		self.searchIcon:SetHeight(14)
		-- 1 px lower: the glass sits high in its texture
		self.searchIcon:SetPoint("LEFT", self.frame, "LEFT", 2, -1)
		self.searchIcon:SetTexture(BUTTONS .. "search-icon")
		self.searchIcon:SetVertexColor(0.6, 0.6, 0.6)

		-- Placeholder text
		self.instructions = self.frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		self.instructions:SetPoint("LEFT", self.frame, "LEFT", 16, 0)
		self.instructions:SetPoint("RIGHT", self.frame, "RIGHT", -20, 0)
		self.instructions:SetJustifyH("LEFT")
		self.instructions:SetText(placeholderText)

		-- Clear button
		self.clearButton = CreateFrame("Button", nil, self.frame)
		self.clearButton:SetWidth(14)
		self.clearButton:SetHeight(14)
		self.clearButton:SetPoint("RIGHT", self.frame, "RIGHT", -3, 0)
		self.clearButton:SetNormalTexture(BUTTONS .. "search-clear")
		self.clearButton:Hide()

		-- ====================== SCRIPTS ==========================

		local instructions = self.instructions
		local clearBtn = self.clearButton
		local editBox = self.frame

		-- Several scripts fire for one edit: refresh only when the text changed
		local lastText = ""
		local function notify()
			local text = editBox:GetText() or ""
			if (text == lastText) then return end
			lastText = text
			onTextChanged()
		end

		clearBtn:SetScript("OnClick", function()
			editBox:SetText("")
			instructions:Show()
			clearBtn:Hide()
			editBox:SetFocus()
			notify()
		end)

		editBox:SetScript("OnTextChanged", function()
			notify()
			local inputText = editBox:GetText()
			if (inputText == "") then
				clearBtn:Hide()
				return
			end
			instructions:Hide()
			clearBtn:Show()
		end)

		editBox:SetScript("OnEscapePressed", function() editBox:ClearFocus() end)
		editBox:SetScript("OnEnterPressed", function() editBox:ClearFocus() end)

		editBox:SetScript("OnEditFocusLost", function()
			editBox:UnregisterEvent("GLOBAL_MOUSE_DOWN")
			local inputText = editBox:GetText()
			if (inputText == "" or string.find(inputText, "^%s*$")) then
				instructions:Show()
				editBox:SetText("")
			end
			editBox:HighlightText(0, 0)
			notify()
		end)

		editBox:SetScript("OnEditFocusGained", function()
			editBox:HighlightText()
			instructions:Hide()
			editBox:RegisterEvent("GLOBAL_MOUSE_DOWN")
		end)

		-- A click outside the box ends typing
		editBox:SetScript("OnEvent", function()
			if (not editBox:IsMouseOver()) then editBox:ClearFocus() end
		end)
	end;

	Hide = function(self)
		self.frame:Hide()
	end;

	Show = function(self)
		self.frame:Show()
	end;

	IsShown = function(self)
		return self.frame:IsShown()
	end;

	GetText = function(self)
		return self.frame:GetText()
	end;

	ClearFocus = function(self)
		self.frame:ClearFocus()
	end;

	SetPoint = function(self, point, relativeTo, relativePoint, x, y)
		self.frame:SetPoint(point, relativeTo, relativePoint, x, y)
	end;

	-- Empties the box and ends typing (the text change refreshes the page)
	Clear = function(self)
		self.frame:SetText("")
		self.instructions:Show()
		self.frame:ClearFocus()
	end;
}