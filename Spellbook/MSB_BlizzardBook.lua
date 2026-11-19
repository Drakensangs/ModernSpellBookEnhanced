-- Puts this book in place of the default one: the spellbook and pet book
-- keys and the micro button (all call ToggleSpellBook) open it, the micro
-- button shows it open, and the Character and Talent windows close it, as
-- with the default book. 1.12.1 has no protected frames, so this works in
-- combat too.

MSB_BlizzardBook = {}

function MSB_BlizzardBook:Install(spellBook)
	if (self.installed) then return end
	self.installed = true

	-- Keys and micro button
	ToggleSpellBook = function(bookType)
		spellBook:Toggle(bookType == BOOKTYPE_PET)
	end

	-- Anything that still shows the default book gets this one instead, a
	-- frame later: hiding it inside its own ShowUIPanel confuses the panel
	-- manager.
	SpellBookFrame:HookScript("OnShow", function()
		MSB_After(0, function()
			if (not SpellBookFrame:IsShown()) then return end
			local pet = (SpellBookFrame.bookType == BOOKTYPE_PET)
			HideUIPanel(SpellBookFrame)
			spellBook:Open(pet)
		end)
	end)

	local function Close() spellBook:Close() end
	CharacterFrame:HookScript("OnShow", Close)
	hooksecurefunc("ShowUIPanel", function(frame)
		if (frame and frame == TalentFrame) then Close() end
	end)

	-- The micro button stays pressed while the book is open
	hooksecurefunc("UpdateMicroButtons", function()
		if (spellBook:IsOpen()) then
			SpellbookMicroButton:SetButtonState("PUSHED", 1)
		end
	end)

	-- UIErrorsFrame shares the book's HIGH strata: keep error messages above it
	hooksecurefunc(UIErrorsFrame, "AddMessage", function()
		if (spellBook:IsOpen()) then UIErrorsFrame:Raise() end
	end)
end
