-- =================================================================
-- SecretChecklistWidgets.lua
-- Small shared widgets used by more than one panel.
-- =================================================================

local SC = _G.SecretChecklist
if not SC then return end

local L = _G.SecretChecklistLocale or {}

-- ==============================================
-- COPY-LINK DIALOG
-- ==============================================
--
-- WoW gives addons no way to put text on the system clipboard, so "copy this
-- URL" means showing a focused, pre-selected EditBox and letting the player
-- press Ctrl+C.
--
-- This existed as two near-identical 50-line copies, one in TabAbout and one in
-- TabGuides. They drifted: the Guides copy restored the dialog's current URL on
-- edit, while the About copy restored a hardcoded discordURL, so opening it from
-- the Warcraft Secrets button and then typing snapped the text back to the
-- Discord link. One implementation cannot disagree with itself.

local copyDialog

local function CreateCopyDialog()
	local dialog = CreateFrame("Frame", nil, UIParent)
	dialog:SetSize(305, 52)
	dialog:SetFrameStrata("FULLSCREEN_DIALOG")
	dialog:SetFrameLevel(100)
	dialog:SetClampedToScreen(true)
	dialog:Hide()

	local bg = dialog:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.05, 0.05, 0.08, 0.95)

	local borderLine = dialog:CreateTexture(nil, "BORDER")
	borderLine:SetPoint("TOPLEFT", dialog, "TOPLEFT", 1, -1)
	borderLine:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -1, 1)
	borderLine:SetColorTexture(0.35, 0.30, 0.18, 0.9)

	local label = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", dialog, "TOPLEFT", 8, -5)
	label:SetText(L["COPY_HINT"] or "Ctrl+C to copy  ·  Esc to close")
	label:SetTextColor(0.65, 0.65, 0.65)

	local box = CreateFrame("EditBox", nil, dialog)
	box:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 8, 6)
	box:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -8, 6)
	box:SetHeight(24)
	box:SetAutoFocus(true)
	box:SetMaxLetters(512)
	box:SetFontObject("ChatFontNormal")
	box:SetJustifyH("LEFT")
	box:SetTextInsets(4, 4, 2, 2)

	local boxBg = box:CreateTexture(nil, "BACKGROUND")
	boxBg:SetAllPoints()
	boxBg:SetColorTexture(0.1, 0.1, 0.15, 0.95)

	box:SetScript("OnEscapePressed", function() dialog:Hide() end)
	box:SetScript("OnEnterPressed", function() dialog:Hide() end)
	box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	-- The box is display-only: typing restores the URL it was opened with rather
	-- than letting the player edit what they are about to copy.
	box:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			self:SetText(dialog.currentURL or "")
			self:HighlightText()
		end
	end)

	dialog.box = box
	return dialog
end

-- Shows the copy dialog for `url`, positioned just below `anchorFrame`.
--
-- The anchor is converted into UIParent's coordinate space rather than being
-- anchored to the button directly, so the popup stays put if the main window is
-- dragged out from under it.
function SC:ShowCopyDialog(anchorFrame, url)
	if type(url) ~= "string" or url == "" then return end
	copyDialog = copyDialog or CreateCopyDialog()

	copyDialog.currentURL = url
	copyDialog:ClearAllPoints()
	if anchorFrame then
		local bx, by = anchorFrame:GetCenter()
		if bx and by then
			local scale = anchorFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
			copyDialog:SetPoint("TOP", UIParent, "BOTTOMLEFT",
				bx * scale,
				(by - anchorFrame:GetHeight() * 0.5) * scale - 4)
		end
	end
	if not copyDialog:GetPoint() then
		copyDialog:SetPoint("CENTER", UIParent, "CENTER")
	end

	copyDialog.box:SetText(url)
	copyDialog:Show()
	copyDialog.box:SetFocus()
	copyDialog.box:HighlightText()
end

function SC:HideCopyDialog()
	if copyDialog then copyDialog:Hide() end
end
