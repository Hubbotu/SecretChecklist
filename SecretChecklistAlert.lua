-- =================================================================
-- SecretChecklistAlert.lua
-- Shows a toast alert (using WoW's AlertFrame system) when the
-- player newly collects a tracked secret during a play session.
--
-- Alert fires when:
--   mount/pet/toy  → journal update event triggers a diff vs snapshot
--   achievement     → ACHIEVEMENT_EARNED event
--   quest          → QUEST_TURNED_IN event
--
-- Clicking the toast opens the addon and navigates to the guide.
-- =================================================================

local SC = _G.SecretChecklist
if not SC then return end

-- ==============================================
-- MIXIN  (referenced by name in the XML template)
-- ==============================================

SecretChecklist_AlertFrameMixin = {}

-- Every alert frame the pool has ever spawned, registered from OnLoad.
--
-- RefreshAlertTheme used to look these up as globals named
-- "SecretChecklist_AlertFrame_Template1", "…2" and so on. Blizzard's
-- AddQueuedAlertFrameSubSystem builds its pool with CreateFramePool, which
-- creates frames with a nil name, so those globals never existed: the loop
-- found nothing on its first iteration and returned, every time. Theme changes
-- therefore never reached a toast that had already been created.
--
-- OnLoad is the one place guaranteed to run for every pooled instance,
-- regardless of how Blizzard names or pools them. Bounded by the sub-system's
-- own maxAlerts, so this holds nothing alive that the pool did not already.
local alertFrames = {}

function SecretChecklist_AlertFrameMixin:OnLoad()
	alertFrames[#alertFrames + 1] = self

	-- Dark background panel – no custom texture file needed; uses
	-- SetColorTexture so this works with any WoW client version.
	local bg = self:CreateTexture(nil, "BACKGROUND", nil, -8)
	bg:SetAllPoints()
	bg:SetColorTexture(0.04, 0.03, 0.09, 0.96)
	self._defaultBg = bg

	-- Gold top accent line
	local topLine = self:CreateTexture(nil, "BACKGROUND", nil, -7)
	topLine:SetHeight(2)
	topLine:SetPoint("TOPLEFT",  0, 0)
	topLine:SetPoint("TOPRIGHT", 0, 0)
	topLine:SetColorTexture(0.80, 0.65, 0.10, 1)
	self._topLine = topLine

	-- Subtle bottom line
	local botLine = self:CreateTexture(nil, "BACKGROUND", nil, -7)
	botLine:SetHeight(1)
	botLine:SetPoint("BOTTOMLEFT",  0, 0)
	botLine:SetPoint("BOTTOMRIGHT", 0, 0)
	botLine:SetColorTexture(0.40, 0.32, 0.05, 1)
	self._botLine = botLine

	-- Apply ElvUI skin immediately if that theme is already active
	SC:ApplyAlertTheme(self)
end

function SecretChecklist_AlertFrameMixin:SetAlert(entry, icon)
	self.entry = entry
	self.Icon.Texture:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
	self.Name:SetText("Secret Collected!")
	self.Label:SetText(SC:GetEntryName(entry))

	-- Trigger the glow / shine animations
	if self.glow  then self.glow:Show();  self.glow.animIn:Play()  end
	if self.shine then self.shine:Show(); self.shine.animIn:Play() end
end

function SecretChecklist_AlertFrameMixin:OnEnter()
	if not self.entry then return end
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPRIGHT", -10, -2)
	GameTooltip:SetText(SC:GetEntryName(self.entry), 1, 1, 1)
	GameTooltip:AddLine("Click to view guide", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

function SecretChecklist_AlertFrameMixin:OnLeave()
	GameTooltip:Hide()
end

function SecretChecklist_AlertFrameMixin:OnClick(button, down)
	-- Right-click dismisses the toast.
	--
	-- This used to delegate to AlertFrame_OnClick, a Classic-era global that
	-- does not exist on retail. The `and` guard meant no error, but also meant
	-- right-click did nothing at all.
	if button == "RightButton" then
		self:Hide()
		return
	end
	-- Left-click: open the checklist and jump straight to the guide entry
	if self.entry then
		SC:OpenSecretsFrame()
		if SC.OpenGuideForEntry then
			SC:OpenGuideForEntry(self.entry)
		end
	end
end

-- ==============================================
-- THEME INTEGRATION
-- ==============================================

-- Called from OnLoad (when frame first spawns) and from ApplyTheme via Themes.lua.
-- Skins a single alert frame instance to match the active theme.
-- Original colours of the Lua-built background and accent lines, so the
-- default branch can restore them after a theme has recoloured them.
local DEFAULT_BG   = { 0.04, 0.03, 0.09, 0.96 }
local DEFAULT_TOP  = { 0.80, 0.65, 0.10, 1 }
local DEFAULT_BOT  = { 0.40, 0.32, 0.05, 1 }

function SC:ApplyAlertTheme(alertFrame)
	if not alertFrame then return end
	local isElvUI = (SC.currentThemeName == "ElvUI") and ElvUI
	local euiSkin = (SC.currentThemeName == "EllesmereUI") and SC._euiSkin or nil

	if euiSkin then
		-- Recolour our own background and lines from EllesmereUI rather than
		-- running its Panel primitive: the toast's glow and shine are direct
		-- texture regions on this frame, and Panel's art removal alphas every
		-- region out, which would kill both animations.
		local pr, pg, pb, pa = euiSkin.GetPanelColor()
		local ar, ag, ab     = euiSkin.GetAccentColor()
		if alertFrame._defaultBg then
			alertFrame._defaultBg:Show()
			-- Toasts float over the world, so keep them close to opaque even
			-- when the panel fill itself is semi-transparent.
			alertFrame._defaultBg:SetColorTexture(pr, pg, pb, math.max(pa or 0, 0.95))
		end
		if alertFrame._topLine then
			alertFrame._topLine:Show()
			alertFrame._topLine:SetColorTexture(ar, ag, ab, 1)
		end
		if alertFrame._botLine then
			alertFrame._botLine:Show()
			alertFrame._botLine:SetColorTexture(ar * 0.5, ag * 0.5, ab * 0.5, 1)
		end
		if alertFrame.backdrop then alertFrame.backdrop:Hide() end
		if alertFrame.Icon then
			euiSkin.SquareIcon(alertFrame.Icon.Texture, alertFrame.Icon)
			if alertFrame.Icon.Overlay then
				alertFrame.Icon.Overlay:SetVertexColor(ar, ag, ab, 1)
			end
		end
		euiSkin.Font(alertFrame.Name)
		euiSkin.Font(alertFrame.Label)
	elseif isElvUI then
		local E = unpack(ElvUI)
		-- Replace the plain colour bg with an ElvUI Transparent backdrop
		if alertFrame._defaultBg then alertFrame._defaultBg:Hide() end
		if alertFrame._topLine   then alertFrame._topLine:Hide()   end
		if alertFrame._botLine   then alertFrame._botLine:Hide()   end
		if not alertFrame.backdrop and alertFrame.CreateBackdrop then
			alertFrame:CreateBackdrop("Transparent")
		end
		if alertFrame.backdrop then alertFrame.backdrop:Show() end
		-- Accent the icon border with ElvUI's border colour
		if alertFrame.Icon then
			local br, bg, bb = 0.3, 0.3, 0.3
			if E.media and E.media.bordercolor then
				br, bg, bb = E.media.bordercolor[1], E.media.bordercolor[2], E.media.bordercolor[3]
			end
			if alertFrame.Icon.Overlay then
				alertFrame.Icon.Overlay:SetVertexColor(br, bg, bb, 1)
			end
		end
	else
		-- Restore default look.  Colours are re-set explicitly, not just
		-- re-shown: the EllesmereUI branch above recolours these same textures
		-- in place, so showing them again is not enough to undo it.
		if alertFrame._defaultBg then
			alertFrame._defaultBg:Show()
			alertFrame._defaultBg:SetColorTexture(unpack(DEFAULT_BG))
		end
		if alertFrame._topLine then
			alertFrame._topLine:Show()
			alertFrame._topLine:SetColorTexture(unpack(DEFAULT_TOP))
		end
		if alertFrame._botLine then
			alertFrame._botLine:Show()
			alertFrame._botLine:SetColorTexture(unpack(DEFAULT_BOT))
		end
		if alertFrame.backdrop then alertFrame.backdrop:Hide() end
		if alertFrame.Icon and alertFrame.Icon.Overlay then
			alertFrame.Icon.Overlay:SetVertexColor(1, 1, 1, 1)
		end
	end
end

-- Re-skins every alert frame the pool has spawned, so a theme change reaches
-- toasts that already exist. Called by the theme OnApply / OnReset hooks.
-- Safe before any toast has been created: the list is simply empty.
function SC:RefreshAlertTheme()
	for i = 1, #alertFrames do
		self:ApplyAlertTheme(alertFrames[i])
	end
end

-- ==============================================
-- ALERT SYSTEM
-- ==============================================

local alertSubSystem = nil

function SC:InitAlertSystem()
	if not AlertFrame or not AlertFrame.AddQueuedAlertFrameSubSystem then return end

	local function SetUp(frame, entry, icon)
		frame:SetAlert(entry, icon)
	end

	alertSubSystem = AlertFrame:AddQueuedAlertFrameSubSystem(
		"SecretChecklist_AlertFrame_Template",
		SetUp,
		4,   -- max simultaneous toasts
		10   -- vertical spacing between stacked toasts
	)
end

function SC:FireSecretAlert(entry)
	if not alertSubSystem then return end
	if SecretChecklistDB and SecretChecklistDB.alertsEnabled == false then return end
	alertSubSystem:AddAlert(entry, SC:GetEntryIcon(entry))
end

-- ==============================================
-- COLLECTION SNAPSHOT  (diff-based detection)
-- ==============================================
--
-- SC._alertSnapshot  – keyed by entry table reference
--   true   = confirmed collected at snapshot time
--   false  = confirmed missing  at snapshot time
--   nil    = status was unknown at snapshot time
--
-- Alerts fire only when snapshot is false AND current status is collected.
-- This ensures we never alert for items already owned before this session.
-- ==============================================

SC._alertSnapshot = nil
SC._alertReady    = false

function SC:BuildAlertSnapshot()
	SC._alertSnapshot = {}
	for _, entry in ipairs(SC.entries or {}) do
		if entry.kind ~= "manual" and entry.kind ~= "housing" then
			local status = SC:GetEntryStatus(entry)
			if status == "collected" then
				SC._alertSnapshot[entry] = true
			elseif status == "missing" then
				SC._alertSnapshot[entry] = false
			end
			-- "unknown" intentionally left as nil
		end
		-- housing entries are excluded here; their snapshots are managed by
		-- CheckHousingCollections, triggered by HOUSING_STORAGE_ENTRY_UPDATED
		-- (per-item ownership change) and HOUSE_DECOR_ADDED_TO_CHEST events.
	end
	SC._alertReady = true
end

function SC:CheckForNewCollections()
	if not SC._alertReady or not SC._alertSnapshot then return end
	for _, entry in ipairs(SC.entries or {}) do
		-- Housing is excluded: its catalog data loads asynchronously and would
		-- cause false-positive toasts. Use CheckHousingCollections instead.
		if entry.kind ~= "manual" and entry.kind ~= "housing" then
			local status     = SC:GetEntryStatus(entry)
			local isCollected = (status == "collected")
			local isMissing   = (status == "missing")
			local snapshot    = SC._alertSnapshot[entry]

			if isCollected then
				if snapshot == false then
					-- Confirmed transition: missing → collected
					SC:FireSecretAlert(entry)
				end
				SC._alertSnapshot[entry] = true
			elseif isMissing and snapshot == nil then
				-- First confirmed missing reading; set it so future collection fires
				SC._alertSnapshot[entry] = false
			end
			-- "unknown" status: leave snapshot unchanged
		end
	end
end

-- Called when HOUSING_STORAGE_ENTRY_UPDATED fires (a specific entry's ownership changed)
-- or HOUSE_DECOR_ADDED_TO_CHEST fires (item looted into housing chest).
-- Silently sets the housing snapshot on first read; fires alert only on missing→collected transitions.
function SC:CheckHousingCollections()
	if not SC._alertSnapshot then return end
	for _, entry in ipairs(SC.entries or {}) do
		if entry.kind == "housing" then
			local status    = SC:GetEntryStatus(entry)
			local snapshot  = SC._alertSnapshot[entry]
			if status == "collected" then
				if snapshot == false then
					-- Confirmed transition: missing → collected during this session
					SC:FireSecretAlert(entry)
				end
				-- snapshot == nil means catalog just loaded with item already owned –
				-- do NOT toast; just record as collected.
				SC._alertSnapshot[entry] = true
			elseif status == "missing" then
				-- Never downgrade a confirmed-collected housing item to false.
				-- HOUSING_STORAGE_UPDATED can fire early (totalNumStored=0) before
				-- the catalog is fully merged, producing a spurious false→true swing
				-- that re-fires the toast on every zone. Housing items can't become
				-- un-collected mid-session, so a true snapshot is sticky.
				if snapshot ~= true then
					SC._alertSnapshot[entry] = false
				end
			end
			-- "unknown" status: leave snapshot unchanged
		end
	end
end
