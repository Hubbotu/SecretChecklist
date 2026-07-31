-- =================================================================
-- SecretChecklist/tabs/TabOverview.lua
-- Builds the Overview tab panel (secret button grid + paging).
--
-- SC:BuildOverviewPanel(frame, L) is called first in Initialize()
-- inside SecretChecklistFrame.lua.
--
-- Shared state access:
--   SC:GetFilteredEntries()    -- filter logic lives in Frame.lua
--   SC.currentTab              -- checked before doing overview work
--
-- Exposes:
--   SC.updateOverviewPage(newPage)  -- used by SwitchTab and OnFilterChanged
-- =================================================================

local SC = _G.SecretChecklist
if not SC then return end

local math_min, math_max, math_ceil = math.min, math.max, math.ceil
local select        = select
local string_format = string.format

function SC:BuildOverviewPanel(frame, L)

	-- ==============================================
	-- LAYOUT CONSTANTS
	-- ==============================================

	local BUTTON_WIDTH     = 208
	local BUTTON_HEIGHT    = 50
	local BUTTONS_PER_ROW  = 3
	local BUTTONS_PER_PAGE = 21
	local START_OFFSET_X   = 38
	local START_OFFSET_Y   = -40
	local BUTTON_PADDING_X = 0
	local BUTTON_PADDING_Y = 16

	-- ==============================================
	-- STATE
	-- ==============================================

	frame.buttonPool  = {}
	frame.currentPage = 1

	-- ==============================================
	-- BUTTON CREATION
	-- ==============================================

	-- Safe tooltip helper: defined once here, shared by all buttons in the pool.
	--
	-- Takes the GameTooltip method name and its arguments rather than a closure.
	-- The closure form allocated a fresh function object per attempt, and a single
	-- mouseover makes up to three attempts, so sweeping the cursor across a page
	-- of 21 icons churned out several dozen short-lived closures.
	local function TryTooltip(method, ...)
		local fn = GameTooltip[method]
		if not fn then return false end
		return pcall(fn, GameTooltip, ...) == true
	end

	local function CreateSecretButton(parent, index)
		local button = CreateFrame("Button", nil, parent)
		button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)

		-- Constrain hit rect to icon area only (left side, 56px width including border)
		button:SetHitRectInsets(0, BUTTON_WIDTH - 56, 0, 0)

		-- Icon texture (shown when collected)
		local iconTexture = button:CreateTexture(nil, "BORDER")
		iconTexture:SetSize(46, 46)
		iconTexture:SetPoint("LEFT", 4, 0)
		iconTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		button.iconTexture = iconTexture

		-- Uncollected icon overlay
		local iconTextureUncollected = button:CreateTexture(nil, "BORDER")
		iconTextureUncollected:SetSize(46, 46)
		iconTextureUncollected:SetPoint("LEFT", 4, 0)
		iconTextureUncollected:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		iconTextureUncollected:SetDesaturated(true)
		iconTextureUncollected:Hide()
		button.iconTextureUncollected = iconTextureUncollected

		-- Slot frame for collected (background border)
		local slotFrameCollected = button:CreateTexture(nil, "ARTWORK", nil, -1)
		slotFrameCollected:SetSize(56, 56)
		slotFrameCollected:SetPoint("CENTER", iconTexture, "CENTER", 0, 0)
		slotFrameCollected:SetAtlas("collections-itemborder-collected")
		button.slotFrameCollected = slotFrameCollected

		-- Slot frame for uncollected
		local slotFrameUncollected = button:CreateTexture(nil, "ARTWORK", nil, -1)
		slotFrameUncollected:SetSize(56, 56)
		slotFrameUncollected:SetPoint("CENTER", iconTexture, "CENTER", 0, 0)
		slotFrameUncollected:SetAtlas("collections-itemborder-uncollected")
		slotFrameUncollected:Hide()
		button.slotFrameUncollected = slotFrameUncollected

		-- Inner glow for uncollected
		local slotFrameUncollectedInnerGlow = button:CreateTexture(nil, "ARTWORK")
		slotFrameUncollectedInnerGlow:SetSize(56, 56)
		slotFrameUncollectedInnerGlow:SetPoint("CENTER", slotFrameUncollected)
		slotFrameUncollectedInnerGlow:SetAtlas("collections-itemborder-glow")
		slotFrameUncollectedInnerGlow:SetBlendMode("ADD")
		slotFrameUncollectedInnerGlow:Hide()
		button.slotFrameUncollectedInnerGlow = slotFrameUncollectedInnerGlow

		-- Thin container frame so flat themes (ElvUI) can attach a backdrop border
		-- Same center as iconTexture; 1px wider on each side = 48x48.
		local iconFrame = CreateFrame("Frame", nil, button)
		iconFrame:SetSize(48, 48)
		iconFrame:SetPoint("CENTER", iconTexture, "CENTER", 0, 0)
		button.iconFrame = iconFrame

		-- Name text beside icon
		local name = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		name:SetSize(140, 0)
		name:SetPoint("LEFT", 65, 1)
		name:SetJustifyH("LEFT")
		name:SetMaxLines(2)
		button.name = name

		-- Highlight texture (only around icon, not text)
		local highlight = button:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
		highlight:SetBlendMode("ADD")
		highlight:SetSize(46, 46)
		highlight:SetPoint("CENTER", iconTexture, "CENTER", 0, 0)
		button:SetHighlightTexture(highlight)

		-- Tooltip handler
		button:SetScript("OnEnter", function(self)
			if not self.entry then return end
			local entry = self.entry

			GameTooltip:SetOwner(self, "ANCHOR_NONE")
			GameTooltip:SetPoint("BOTTOMLEFT", self.slotFrameCollected, "TOPRIGHT", -2, -2)

			local success = false
			if entry.kind == "toy" and entry.itemID then
				success = TryTooltip("SetToyByItemID", entry.itemID)
			elseif entry.kind == "mount" then
				if entry.mountID and C_MountJournal and C_MountJournal.GetMountInfoByID then
					local _, spellID = C_MountJournal.GetMountInfoByID(entry.mountID)
					if spellID then success = TryTooltip("SetMountBySpellID", spellID) end
				end
				if not success and entry.spellID then
					success = TryTooltip("SetMountBySpellID", entry.spellID)
				end
				if not success and entry.itemID then
					success = TryTooltip("SetItemByID", entry.itemID)
				end
				if success and C_MountJournal then
					local mountID = entry.mountID
					if not mountID and entry.itemID and C_MountJournal.GetMountFromItem then
						mountID = C_MountJournal.GetMountFromItem(entry.itemID)
					end
					if mountID then
						local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
						if C_MountJournal.GetMountInfoExtraByID then
							local _, description, source = C_MountJournal.GetMountInfoExtraByID(mountID)
							if source and source ~= "" then
								GameTooltip:AddLine(source, 1, 0.82, 0, true)
							end
							if description and description ~= "" then
								GameTooltip:AddLine(description, 0.8, 0.8, 0.8, true)
							end
						end
						if isCollected ~= nil then
							local collected = isCollected == true
							GameTooltip:AddLine(
								collected and (L["TOOLTIP_COLLECTED"] or "Collected") or (L["TOOLTIP_NOT_COLLECTED"] or "Not collected"),
								collected and 0 or 1, collected and 1 or 0, 0
							)
						end
					end
				end
			elseif entry.kind == "pet" then
				if entry.itemID then
					success = TryTooltip("SetItemByID", entry.itemID)
				end
				if success and entry.speciesID and C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID then
					local _, _, _, _, sourceText, description = C_PetJournal.GetPetInfoBySpeciesID(entry.speciesID)
					if sourceText and sourceText ~= "" then
						GameTooltip:AddLine(sourceText, 1, 0.82, 0, true)
					end
					if description and description ~= "" then
						GameTooltip:AddLine(description, 0.8, 0.8, 0.8, true)
					end
					local numOwned = C_PetJournal.GetNumCollectedInfo and select(1, C_PetJournal.GetNumCollectedInfo(entry.speciesID))
					local collected = numOwned and numOwned > 0
					GameTooltip:AddLine(
						collected and (L["TOOLTIP_COLLECTED"] or "Collected") or (L["TOOLTIP_NOT_COLLECTED"] or "Not collected"),
						collected and 0 or 1, collected and 1 or 0, 0
					)
				end
				if not success and entry.speciesID and C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID then
					local speciesName, _, _, _, sourceText, description = C_PetJournal.GetPetInfoBySpeciesID(entry.speciesID)
					if speciesName then
						local rareColor = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[3] or { r = 0, g = 0.44, b = 0.87 }
						GameTooltip:SetText(speciesName, rareColor.r, rareColor.g, rareColor.b)
						if sourceText and sourceText ~= "" then
							GameTooltip:AddLine(sourceText, 1, 0.82, 0, true)
						end
						if description and description ~= "" then
							GameTooltip:AddLine(description, 0.8, 0.8, 0.8, true)
						end
						local numOwned = C_PetJournal.GetNumCollectedInfo and select(1, C_PetJournal.GetNumCollectedInfo(entry.speciesID))
						local collected = numOwned and numOwned > 0
						GameTooltip:AddLine(
							collected and (L["TOOLTIP_COLLECTED"] or "Collected") or (L["TOOLTIP_NOT_COLLECTED"] or "Not collected"),
							collected and 0 or 1, collected and 1 or 0, 0
						)
						success = true
					end
				end
			elseif entry.kind == "achievement" and entry.achievementID then
				-- A full achievement link carries the achievement id, the player
				-- GUID, a completed flag, the completion date and four criteria
				-- fields. "achievement:<id>" supplies only the first, so the tooltip
				-- has no GUID to resolve and sits on "Retrieving data" while it
				-- waits for information that is never going to arrive.
				local achLink = GetAchievementLink and GetAchievementLink(entry.achievementID)
				if achLink then
					success = TryTooltip("SetHyperlink", achLink)
					if success then
						-- Blizzard's achievement tooltip resolves the earning
						-- character's name from the GUID embedded in the link.
						-- Achievements are account-wide but the link records which
						-- character earned it, so for one earned on an alt that
						-- lookup goes to the server and can stay unresolved --
						-- leaving a RETRIEVING_DATA line sitting under the title
						-- forever. Blank it rather than show the player a permanent
						-- "Retrieving data" on a secret they have demonstrably
						-- already completed.
						for i = 2, GameTooltip:NumLines() do
							local line = _G["GameTooltipTextLeft" .. i]
							if line and line:GetText() == RETRIEVING_DATA then
								line:SetText(" ")
							end
						end
					end
				end
				if not success then
					-- GetAchievementLink returns nil for an achievement the player
					-- has not earned, so linking is not an option for exactly the
					-- entries a checklist most needs to describe. Falling back to
					-- the malformed short link just reproduced "Retrieving data";
					-- build the tooltip from the achievement's own fields instead.
					local _, achName, _, completed, _, _, _, achDesc = GetAchievementInfo(entry.achievementID)
					if achName then
						GameTooltip:SetText(achName, 1, 1, 1)
						if achDesc and achDesc ~= "" then
							GameTooltip:AddLine(achDesc, 0.8, 0.8, 0.8, true)
						end
						GameTooltip:AddLine(
							completed and (L["TOOLTIP_COMPLETED"] or "Completed")
							or (L["TOOLTIP_NOT_COMPLETED"] or "Not completed"),
							completed and 0 or 1, completed and 1 or 0, 0)
						success = true
					end
				end
			elseif entry.kind == "transmog" and entry.itemID then
				success = TryTooltip("SetItemByID", entry.itemID)
			elseif entry.kind == "housing" and entry.itemID then
				success = TryTooltip("SetItemByID", entry.itemID)
				if success and C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
					local info = C_HousingCatalog.GetCatalogEntryInfoByItem(entry.itemID, true)
					if info then
						local owned = (info.quantity or 0) + (info.numPlaced or 0) + (info.remainingRedeemable or 0) > 0
						GameTooltip:AddLine(
							owned and (L["TOOLTIP_COLLECTED"] or "Collected") or (L["TOOLTIP_NOT_COLLECTED"] or "Not collected"),
							owned and 0 or 1, owned and 1 or 0, 0
						)
					end
				end
			elseif entry.kind == "quest" and entry.questID then
				GameTooltip:SetText(SC:GetEntryName(entry), 1, 1, 1)
				if C_QuestLog and C_QuestLog.IsQuestFlaggedCompletedOnAccount then
					local completed = C_QuestLog.IsQuestFlaggedCompletedOnAccount(entry.questID)
					local statusText = completed and (L["TOOLTIP_COMPLETED"] or "Completed") or (L["TOOLTIP_NOT_COMPLETED"] or "Not completed")
					GameTooltip:AddLine(statusText, completed and 0 or 1, completed and 1 or 0, 0)
				end
				success = true
			end

			if not success then
				GameTooltip:SetText(SC:GetEntryName(entry), 1, 1, 1)
				if entry.note then
					GameTooltip:AddLine(entry.note, 0.8, 0.8, 0.8, true)
				end
			end

			GameTooltip:Show()
		end)

		button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		button:SetScript("OnClick", function(self)
			if not self.entry then return end
			local entry = self.entry
			if IsControlKeyDown() then
				-- Ctrl+Click: insert an item/achievement link into the active chat box
				local link
				if entry.itemID then
					link = select(2, C_Item.GetItemInfo(entry.itemID))
				elseif entry.achievementID then
					link = GetAchievementLink and GetAchievementLink(entry.achievementID)
				end
				if link then
					ChatEdit_InsertLink(link)
				end
			else
				if SC.OpenGuideForEntry then
					SC:OpenGuideForEntry(entry)
				end
			end
		end)

		return button
	end

	local function GetButton(index)
		if not frame.buttonPool[index] then
			frame.buttonPool[index] = CreateSecretButton(frame, index)
		end
		return frame.buttonPool[index]
	end

	-- ==============================================
	-- LAYOUT
	-- ==============================================

	-- `entries` is optional: callers that have already run the filter pass hand it
	-- in so it is not repeated. GetFilteredEntries allocates a result table, a
	-- lowercased-name table and a comparator closure per call, so the passes are
	-- worth counting.
	local function LayoutCurrentPage(entries)
		if SC.currentTab ~= "overview" then return end
		entries = entries or SC:GetFilteredEntries()

		local startIndex = (frame.currentPage - 1) * BUTTONS_PER_PAGE + 1
		local endIndex   = math_min(startIndex + BUTTONS_PER_PAGE - 1, #entries)

		for _, button in pairs(frame.buttonPool) do button:Hide() end

		local buttonIndex = 1
		local row, col    = 0, 0

		-- Theme lookups are invariant across the page, so resolve them once here
		-- rather than per button. The ElvUI border colour in particular used to
		-- cost an unpack(ElvUI) plus an unpack of its media table for every
		-- uncollected icon, up to 21 times per redraw.
		local themeName = SC.currentThemeName
		local euiSkin   = (themeName == "EllesmereUI") and SC._euiSkin or nil
		local useFlat   = ElvUI and themeName == "ElvUI"
		local elvBorderR, elvBorderG, elvBorderB = 0.3, 0.3, 0.3
		if useFlat then
			local E = unpack(ElvUI)
			if E and E.media and E.media.bordercolor then
				elvBorderR, elvBorderG, elvBorderB = unpack(E.media.bordercolor)
			end
		end

		for i = startIndex, endIndex do
			local entry  = entries[i]
			local button = GetButton(buttonIndex)

			button.entry = entry
			local icon = SC:GetEntryIcon(entry)
			button.iconTexture:SetTexture(icon)
			button.iconTextureUncollected:SetTexture(icon)
			button.name:SetText(SC:GetEntryName(entry))

			local status = SC:GetEntryStatus(entry) or "unknown"
			local isCollected = status == "collected"
			local isMissing   = status == "missing"

			button.iconTexture:SetShown(isCollected)
			button.iconTextureUncollected:SetShown(not isCollected)

			if euiSkin then
				-- EllesmereUI: squared, 1px-bordered icons in place of the round
				-- atlas slot art, matching how EUI treats icons elsewhere.
				button.slotFrameCollected:Hide()
				button.slotFrameUncollected:Hide()
				button.slotFrameUncollectedInnerGlow:Hide()
				if button.iconFrame and button.iconFrame.backdrop then
					button.iconFrame.backdrop:Hide()
				end
				-- Border once only: both textures share the same geometry, and
				-- BorderRegion draws a fresh set of lines per region.
				euiSkin.SquareIcon(button.iconTexture, button.iconFrame)
				euiSkin.SquareIcon(button.iconTextureUncollected)
			elseif useFlat then
				-- Flat theme: hide round atlas borders, use ElvUI backdrop border instead
				button.slotFrameCollected:Hide()
				button.slotFrameUncollected:Hide()
				button.slotFrameUncollectedInnerGlow:Hide()
				if button.iconFrame then
					-- Lazy-create ElvUI backdrop once per button
					if not button.iconFrame.backdrop and button.iconFrame.CreateBackdrop then
						button.iconFrame:CreateBackdrop()
					end
					if button.iconFrame.backdrop then
						button.iconFrame.backdrop:Show()
						if isCollected then
							button.iconFrame.backdrop:SetBackdropBorderColor(0.85, 0.65, 0.13, 1)
						else
							button.iconFrame.backdrop:SetBackdropBorderColor(elvBorderR, elvBorderG, elvBorderB, 1)
						end
					end
				end
			else
				-- Default theme: restore round atlas borders, hide backdrop if present
				if button.iconFrame and button.iconFrame.backdrop then
					button.iconFrame.backdrop:Hide()
				end
				button.slotFrameCollected:SetShown(isCollected)
				button.slotFrameUncollected:SetShown(not isCollected)
				button.slotFrameUncollectedInnerGlow:SetShown(isMissing)
			end

			if isCollected then
				button.name:SetTextColor(1, 0.82, 0, 1)
				button.name:SetShadowColor(0, 0, 0, 1)
			else
				button.name:SetTextColor(0.33, 0.27, 0.20, 1)
				button.name:SetShadowColor(0, 0, 0, 0.33)
			end

			local x = START_OFFSET_X + col * (BUTTON_WIDTH + BUTTON_PADDING_X)
			local y = START_OFFSET_Y - row * (BUTTON_HEIGHT + BUTTON_PADDING_Y)
			button:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", x, y)
			button:Show()

			buttonIndex = buttonIndex + 1
			col = col + 1
			if col >= BUTTONS_PER_ROW then
				row = row + 1
				col = 0
			end
		end
	end

	-- ==============================================
	-- PAGING
	-- ==============================================

	-- Last page count computed by UpdatePage. The scroll-wheel handler needs a
	-- bound but must not trigger another filter pass to get one; the paging
	-- buttons are enabled/disabled from the same value.
	local currentMaxPages = 1

	local function UpdateProgressBar()
		local totalAll, collectedAll = 0, 0
		local totalMS,  collectedMS  = 0, 0
		for _, entry in ipairs(SC.entries or {}) do
			local isNotManual  = entry.kind ~= "manual"
			local isMindSeeker = entry.mindSeeker and not entry.linkedSecret
			if isNotManual or isMindSeeker then
				-- Goes through GetEntryStatus rather than CheckEntry directly so the
				-- counters read the same cached answer the list and buttons use.
				-- Equivalent: CheckEntry returning true is exactly "collected", and a
				-- manual entry resolves to "manual" where it previously returned nil.
				local collected = SC:GetEntryStatus(entry) == "collected"
				if isNotManual then
					totalAll = totalAll + 1
					if collected then collectedAll = collectedAll + 1 end
				end
				if isMindSeeker then
					totalMS = totalMS + 1
					if collected then collectedMS = collectedMS + 1 end
				end
			end
		end
		frame.ProgressBar.TotalText:SetText(
			string_format("|cffffffff%d|r / %d %s", collectedAll, totalAll, L["SECRETS"] or "Secrets"))
		frame.ProgressBar.MindSeekerText:SetText(
			string_format("%s: |cffffffff%d|r / %d", L["MIND_SEEKER"] or "Mind-Seeker", collectedMS, totalMS))
	end

	local function UpdatePage(newPage)
		SC:RefreshCaches()
		-- One filter+sort pass, shared by the page count and the layout. This used
		-- to run twice per call: once inside LayoutCurrentPage and again inside
		-- CalculateTotalPages.
		local entries     = SC:GetFilteredEntries()
		currentMaxPages   = math_max(1, math_ceil(#entries / BUTTONS_PER_PAGE))
		-- Clamp rather than trust the caller, so a page turn cannot run off the end
		-- when a filter change has shortened the list.
		frame.currentPage = math_max(1, math_min(newPage or 1, currentMaxPages))
		LayoutCurrentPage(entries)
		UpdateProgressBar()
		frame.PagingFrame.PageText:SetText(
			string_format(L["PAGE_FORMAT"] or "Page %d / %d", frame.currentPage, currentMaxPages))
		frame.PagingFrame.PrevPageButton:SetEnabled(frame.currentPage > 1)
		frame.PagingFrame.NextPageButton:SetEnabled(frame.currentPage < currentMaxPages)
	end

	-- Mouse wheel scrolling through pages (only active on overview tab)
	frame:SetScript("OnMouseWheel", function(self, delta)
		if SC.currentTab ~= "overview" then return end
		-- Read the bound computed by the last UpdatePage instead of re-running the
		-- filter pass on every wheel notch.
		local maxPages = currentMaxPages
		if delta > 0 then
			if frame.currentPage > 1 then
				PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
				UpdatePage(frame.currentPage - 1)
			end
		else
			if frame.currentPage < maxPages then
				PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
				UpdatePage(frame.currentPage + 1)
			end
		end
	end)

	-- Paging button handlers
	frame.PagingFrame.PrevPageButton:SetScript("OnClick", function()
		if frame.currentPage > 1 then
			PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
			UpdatePage(frame.currentPage - 1)
		end
	end)

	frame.PagingFrame.NextPageButton:SetScript("OnClick", function()
		if frame.currentPage < currentMaxPages then
			PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
			UpdatePage(frame.currentPage + 1)
		end
	end)

	-- Expose UpdatePage for SwitchTab and OnFilterChanged in Frame.lua
	SC.updateOverviewPage  = UpdatePage
	-- Lightweight refresh used by background collection events (no RefreshCaches to avoid
	-- re-triggering MOUNT_JOURNAL_SEARCH_UPDATED via SetDefaultFilters and causing a loop).
	SC.refreshOverviewDisplay = function(page)
		frame.currentPage = page or frame.currentPage or 1
		LayoutCurrentPage()
		UpdateProgressBar()
	end
	SC.updateProgressBar   = UpdateProgressBar
	SC.updateOverviewIcons = LayoutCurrentPage

end  -- SC:BuildOverviewPanel
