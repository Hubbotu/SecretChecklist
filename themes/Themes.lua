-- =================================================================
-- SecretChecklist/themes/Themes.lua
-- Lightweight theme registry inspired by BetterBags (MIT License).
--
-- Each theme is a table:
--   Name        string   Display name shown in options.
--   Description string   Short description shown in options.
--   Available   boolean  false if a required addon (e.g. ElvUI) is absent.
--   colors      table    Named colour arrays {r, g, b, a}.
--
-- Public API (on the SC object):
--   SC:RegisterTheme(key, theme)   Add or override a theme.
--   SC:ApplyTheme(key)             Switch active theme; persists to SavedVariables.
--   SC:ThemeColor(key)             Return {r,g,b,a} for a named colour in the active theme.
-- =================================================================

local SC = _G.SecretChecklist
if not SC then return end

-- ==============================
-- Theme registry
-- ==============================

SC.themes          = {}
SC.currentThemeName = "Default"
SC.themeTargets    = SC.themeTargets or {}   -- populated by Core and panel files

function SC:RegisterTheme(key, theme)
	theme.key     = key
	SC.themes[key] = theme
end

-- The gold that marks a collected item. Shared so the themes cannot drift apart
-- on what "collected" looks like.
SC.COLLECTED_GOLD = { 0.85, 0.65, 0.13 }

-- ==============================
-- Theme primitives
-- ==============================
--
-- A theme may supply drawing routines for widgets whose appearance is genuinely
-- theme-specific:
--
--   StyleIconSlot(button, isCollected, isMissing)
--       Paints an Overview icon button. The button carries iconTexture,
--       iconTextureUncollected, iconFrame, the three slotFrame* atlas textures,
--       and button:GetIconBorder() for a 1px border frame the theme owns.
--
--   StyleTab(button, isActive)
--       Paints a bottom tab. The button carries Left/Right/Middle and the
--       *Active variants, plus Text.
--
-- Panels used to branch on SC.currentThemeName themselves, in three different
-- files, so adding a theme meant editing the panels and every panel had to know
-- the name of every theme. Now the panel asks for a primitive and draws with
-- whatever it gets.
--
-- Default implements both, so a primitive is always available and callers need
-- no fallback path.
function SC:ThemePrimitive(name)
	local theme = SC.themes[SC.currentThemeName or "Default"]
	local fn    = theme and theme[name]
	if fn then return fn end
	local default = SC.themes["Default"]
	return default and default[name]
end

-- Returns {r,g,b,a} for a named colour; falls back to Default then white.
-- A colour entry may be a function returning {r,g,b,a} instead of a literal
-- table.  Themes that derive their palette from another addon (EllesmereUI's
-- live accent, for example) use that form so every read resolves fresh --
-- those sources mutate their colour tables in place and must not be cached.
function SC:ThemeColor(key)
	local name  = SC.currentThemeName or "Default"
	local theme = SC.themes[name]
	local c     = theme and theme.colors and theme.colors[key]
	if not c then
		local def = SC.themes["Default"]
		c = def and def.colors and def.colors[key]
	end
	if type(c) == "function" then c = c() end
	return c or {1, 1, 1, 1}
end

-- Activates the theme.  Updates all registered targets and notifies panels.
function SC:ApplyTheme(key)
	local requested = key
	local theme     = SC.themes[key]
	if not theme or not theme.Available then
		key   = "Default"
		theme = SC.themes["Default"]
	end
	if not theme then return end

	-- Reset previous theme first
	local oldKey = SC.currentThemeName
	if oldKey and oldKey ~= key then
		local oldTheme = SC.themes[oldKey]
		if oldTheme and oldTheme.OnReset then oldTheme.OnReset() end
	end

	SC.currentThemeName = key

	-- Only persist when the requested theme was actually applied.  A theme
	-- whose host addon has not finished loading is briefly unavailable (the
	-- EllesmereUI skin callback arrives after PLAYER_LOGIN, for example), and
	-- writing the Default fallback here would silently erase the user's choice
	-- before the real theme has had a chance to register.
	if requested == key then
		SecretChecklistDB.theme = key
	end

	-- Inset background
	local t = SC.themeTargets
	if t.insetBg then
		local c = self:ThemeColor("insetBg")
		t.insetBg:SetColorTexture(c[1], c[2], c[3], c[4])
	end

	-- Divider (stored by TabGuides after creation)
	if t.divider then
		local c = self:ThemeColor("divider")
		t.divider:SetColorTexture(c[1], c[2], c[3], c[4])
	end

	-- Theme-specific extra work (e.g. ElvUI frame skinning)
	if theme.OnApply then theme.OnApply() end

	-- Notify the Guides panel to recolour existing rows
	if SC.onThemeChanged then SC.onThemeChanged() end

	-- Notify the Overview panel to update icon border style
	if SC.updateOverviewIcons then SC.updateOverviewIcons() end
end

-- =================================================================
-- BUILT-IN: Default
-- The classic SecretChecklist dark-amber look.
-- =================================================================
SC:RegisterTheme("Default", {
	Name        = "Default",
	Description = "The classic SecretChecklist dark-amber look.",
	-- Locale keys for the two strings above; the options dropdown prefers them
	-- and falls back to the English when a locale has not filled them in.
	NameKey     = "THEME_DEFAULT",
	DescKey     = "THEME_DEFAULT_DESC",
	Available   = true,
	colors = {
		insetBg = {0.12, 0.10, 0.08, 0.98},
		rowEven = {0,    0,    0,    0.18},
		rowOdd  = {0,    0,    0,    0.08},
		rowSel  = {0.25, 0.20, 0.10, 0.60},
		rowHov  = {1,    1,    1,    0.06},
		divider = {0.30, 0.25, 0.20, 0.80},
	},

	-- Blizzard's round collections slot art. Also the fallback the other themes
	-- delegate to before their own decorations exist.
	StyleIconSlot = function(button, isCollected, isMissing)
		if button.iconFrame and button.iconFrame.backdrop then
			button.iconFrame.backdrop:Hide()
		end
		if button.iconBorder then button.iconBorder:Hide() end
		button.slotFrameCollected:SetShown(isCollected)
		button.slotFrameUncollected:SetShown(not isCollected)
		button.slotFrameUncollectedInnerGlow:SetShown(isMissing)
	end,

	StyleTab = function(button, isActive)
		if isActive then
			button.LeftActive:Show(); button.RightActive:Show(); button.MiddleActive:Show()
			button.Left:Hide(); button.Right:Hide(); button.Middle:Hide()
		else
			button.LeftActive:Hide(); button.RightActive:Hide(); button.MiddleActive:Hide()
			button.Left:Show(); button.Right:Show(); button.Middle:Show()
		end
		button.Text:SetFontObject(isActive and "GameFontHighlightSmall" or "GameFontNormalSmall")
	end,
})

-- =================================================================
-- BUILT-IN: ElvUI
-- Flat dark theme matching ElvUI's aesthetic.
-- Only available when ElvUI is loaded.
-- Inspired by BetterBags' ElvUI theme (MIT License, Antonio Lobato).
-- =================================================================
-- ElvUI's border colour, refreshed in OnApply. Read per icon during a page
-- redraw, so it is cached rather than unpacked from E.media each time.
local elvBorder = { 0.3, 0.3, 0.3 }

local function RefreshElvBorderColor()
	if not ElvUI then return end
	local E = unpack(ElvUI)
	if E and E.media and E.media.bordercolor then
		elvBorder[1], elvBorder[2], elvBorder[3] = unpack(E.media.bordercolor)
	end
end

SC:RegisterTheme("ElvUI", {
	Name        = "ElvUI",
	Description = "A flat dark theme matching ElvUI's aesthetic. Requires ElvUI.",
	-- No NameKey: "ElvUI" is the addon's own name and stays as it is.
	DescKey     = "THEME_ELVUI_DESC",
	-- Resolved once, at file load, so ElvUI must already be loaded by then --
	-- that is what the ## OptionalDeps line in the .toc guarantees.
	Available   = (ElvUI ~= nil),
	colors = {
		insetBg = {0.06, 0.06, 0.06, 1.00},
		rowEven = {0.10, 0.10, 0.10, 0.80},
		rowOdd  = {0.07, 0.07, 0.07, 0.70},
		rowSel  = {0.15, 0.40, 0.70, 0.50},
		rowHov  = {1,    1,    1,    0.08},
		divider = {0.20, 0.20, 0.20, 1.00},
	},

	-- Flat: no round atlas art, an ElvUI backdrop border instead, tinted gold
	-- when collected.
	StyleIconSlot = function(button, isCollected, isMissing)
		if button.iconBorder then button.iconBorder:Hide() end
		button.slotFrameCollected:Hide()
		button.slotFrameUncollected:Hide()
		button.slotFrameUncollectedInnerGlow:Hide()

		local iconFrame = button.iconFrame
		if not iconFrame then return end
		if not iconFrame.backdrop and iconFrame.CreateBackdrop then
			iconFrame:CreateBackdrop()
		end
		if not iconFrame.backdrop then
			-- ElvUI has not given us CreateBackdrop yet; fall back so the button
			-- is never left with no border at all.
			return SC.themes.Default.StyleIconSlot(button, isCollected, isMissing)
		end
		iconFrame.backdrop:Show()
		if isCollected then
			local gold = SC.COLLECTED_GOLD
			iconFrame.backdrop:SetBackdropBorderColor(gold[1], gold[2], gold[3], 1)
		else
			iconFrame.backdrop:SetBackdropBorderColor(elvBorder[1], elvBorder[2], elvBorder[3], 1)
		end
	end,

	StyleTab = function(button, isActive)
		-- elvBg is built by OnApply; before that runs there is nothing to tint.
		if not (button.elvBg and button.elvBg:IsShown() and button.elvBg.SetBackdropColor) then
			return SC.themes.Default.StyleTab(button, isActive)
		end
		local shade = isActive and 0.15 or 0.06
		button.elvBg:SetBackdropColor(shade, shade, shade, 1)
		button.Text:SetFontObject(isActive and "GameFontHighlightSmall" or "GameFontNormalSmall")
	end,

	OnApply = function()
		if not ElvUI then return end
		local E = unpack(ElvUI)  ---@type ElvUI
		local S = E:GetModule("Skins")
		local frame = _G.SecretChecklistFrame
		if not frame or not S then return end
		RefreshElvBorderColor()

		-- Non-destructively hide PortraitFrameTemplate chrome (NineSlice border,
		-- background and title streaks).  We hide rather than strip so OnReset can
		-- simply call Show() to restore them.
		if frame.NineSlice      then frame.NineSlice:Hide() end
		if frame.Bg             then frame.Bg:Hide() end
		if frame.TopTileStreaks then frame.TopTileStreaks:Hide() end

		-- Hide the portrait container entirely in ElvUI mode.
		-- The About easter egg is now on the title text instead.
		if frame.PortraitContainer then frame.PortraitContainer:Hide() end

		-- Skin the close button: strip red atlases and reset ElvUI's IsSkinned
		-- guard so HandleCloseButton always re-applies, even after OnReset.
		local closeBtn = frame.CloseButton
		if closeBtn then
			closeBtn:SetNormalAtlas("")
			closeBtn:SetPushedAtlas("")
			closeBtn:SetDisabledAtlas("")
			closeBtn:SetHighlightAtlas("")
			closeBtn.IsSkinned = nil
			if S.HandleCloseButton then
				S:HandleCloseButton(closeBtn)
			end
			closeBtn:Show()
		end

		-- Add an ElvUI backdrop to the main frame once; show it on subsequent applies.
		if not frame.backdrop and frame.CreateBackdrop then
			frame:CreateBackdrop("Transparent")
		end
		if frame.backdrop then frame.backdrop:Show() end

		-- Add ElvUI backdrop to the inset content area.
		if frame.Inset then
			if not frame.Inset.backdrop and frame.Inset.CreateBackdrop then
				frame.Inset:CreateBackdrop("Transparent")
			end
			if frame.Inset.backdrop then frame.Inset.backdrop:Show() end
		end

		-- Hide the theme-colored inset background texture (replaced by backdrop above).
		if SC.themeTargets and SC.themeTargets.insetBg then
			SC.themeTargets.insetBg:Hide()
		end

		-- Tab decoration: create a WoW BackdropTemplate child frame per tab, sized
		-- to match the button.  Store as btn.elvBg so it can be toggled without
		-- touching ElvUI internals (avoids HandleTab's early-return guard and
		-- StripTextures destroying our atlas objects).
		if SC.tabButtons_list then
			for _, btn in ipairs(SC.tabButtons_list) do
				-- Hide our original atlas textures
				for _, p in ipairs({"LeftActive","RightActive","MiddleActive","Left","Right","Middle"}) do
					if btn[p] then btn[p]:Hide() end
				end
				if not btn.elvBg then
					local bg = CreateFrame("Frame", nil, btn, "BackdropTemplate")
					local spacing = E.PixelMode and 1 or 3
					bg:SetPoint("TOPLEFT",     btn, "TOPLEFT",     spacing,  E.PixelMode and -1 or -3)
					bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -spacing,  3)
					bg:SetFrameLevel(math.max(1, btn:GetFrameLevel() - 1))
					local blankTex = (E.Media and E.Media.Textures and E.Media.Textures.White8x8)
						or "Interface\\ChatFrame\\ChatFrameBackground"
					bg:SetBackdrop({
						bgFile   = blankTex,
						edgeFile = blankTex,
						edgeSize = 1,
						insets   = { left = 1, right = 1, top = 1, bottom = 1 },
					})
					local br, bg2, bb = 0.3, 0.3, 0.3
					if E.media and E.media.bordercolor then
						br, bg2, bb = E.media.bordercolor[1], E.media.bordercolor[2], E.media.bordercolor[3]
					end
					bg:SetBackdropColor(0.06, 0.06, 0.06, 1)
					bg:SetBackdropBorderColor(br, bg2, bb, 1)
					btn.elvBg = bg
				end
				btn.elvBg:Show()
			end
		end

		-- Style the scrollbar to match the divider: flat colored thumb.
		if SC.themeTargets and SC.themeTargets.scrollBar then
			local sb = SC.themeTargets.scrollBar
			sb:SetWidth(6)
			sb:SetThumbTexture("Interface\\ChatFrame\\ChatFrameBackground")
			local thumb = sb:GetThumbTexture()
			if thumb then
				local c = SC:ThemeColor("divider")
				thumb:SetColorTexture(c[1], c[2], c[3], c[4])
				thumb:SetWidth(6)
				thumb:SetHeight(20)
			end
		end
		-- Skin the Guides skill-line side-tab buttons
		if SC.guidesSkillTabBtns then
			local blankTex = (E.Media and E.Media.Textures and E.Media.Textures.White8x8)
				or "Interface\\ChatFrame\\ChatFrameBackground"
			local br, bg2, bb = 0.3, 0.3, 0.3
			if E.media and E.media.bordercolor then
				br, bg2, bb = E.media.bordercolor[1], E.media.bordercolor[2], E.media.bordercolor[3]
			end
			for _, btn in ipairs(SC.guidesSkillTabBtns) do
				if btn.bgTex then btn.bgTex:Hide() end
				if not btn.elvBg and btn.CreateBackdrop then
					btn:CreateBackdrop("Transparent")
				end
				if btn.backdrop then
					btn.backdrop:SetBackdrop({
						bgFile   = blankTex,
						edgeFile = blankTex,
						edgeSize = 1,
						insets   = { left = 1, right = 1, top = 1, bottom = 1 },
					})
					btn.backdrop:SetBackdropColor(0.06, 0.06, 0.06, 1)
					btn.backdrop:SetBackdropBorderColor(br, bg2, bb, 1)
					btn.backdrop:Show()
				end
				-- Inset icon so the backdrop border shows around it
				if btn.iconTex then
					btn.iconTex:ClearAllPoints()
					btn.iconTex:SetSize(22, 22)
					btn.iconTex:SetPoint("CENTER", btn, "CENTER", 0, 0)
				end
			end
		end
		-- Re-skin any pooled alert frame instances
		if SC.RefreshAlertTheme then SC:RefreshAlertTheme() end
	end,
	OnReset = function()
		local frame = _G.SecretChecklistFrame
		if not frame then return end

		-- Restore PortraitFrameTemplate chrome.
		if frame.NineSlice         then frame.NineSlice:Show() end
		if frame.Bg                then frame.Bg:Show() end
		if frame.TopTileStreaks    then frame.TopTileStreaks:Show() end
		if frame.PortraitContainer then frame.PortraitContainer:Show() end

		-- Restore the original red close button (S:HandleCloseButton is not reversible).
		local closeBtn = frame.CloseButton
		if closeBtn then
			if closeBtn.Texture then closeBtn.Texture:Hide() end
			closeBtn:SetNormalAtlas("RedButton-Exit")
			closeBtn:SetPushedAtlas("RedButton-exit-pressed")
			closeBtn:SetDisabledAtlas("RedButton-Exit-Disabled")
			closeBtn:SetHighlightAtlas("RedButton-Highlight", "ADD")
		end

		-- Hide ElvUI backdrops added during OnApply.
		if frame.backdrop then frame.backdrop:Hide() end
		if frame.Inset and frame.Inset.backdrop then frame.Inset.backdrop:Hide() end

		-- Restore the theme-colored inset background texture.
		if SC.themeTargets and SC.themeTargets.insetBg then
			SC.themeTargets.insetBg:Show()
			local c = SC:ThemeColor("insetBg")
			SC.themeTargets.insetBg:SetColorTexture(c[1], c[2], c[3], c[4])
		end

		-- Hide tab BackdropTemplate frames and restore original atlas textures + active state.
		if SC.tabButtons_list then
			for _, btn in ipairs(SC.tabButtons_list) do
				if btn.elvBg then btn.elvBg:Hide() end

				local isActive = btn.tabID == (SC.currentTab or 1)
				if btn.LeftActive then
					btn.LeftActive:SetAtlas("uiframe-activetab-left", true)
					if isActive then btn.LeftActive:Show() else btn.LeftActive:Hide() end
				end
				if btn.RightActive then
					btn.RightActive:SetAtlas("uiframe-activetab-right", true)
					if isActive then btn.RightActive:Show() else btn.RightActive:Hide() end
				end
				if btn.MiddleActive then
					btn.MiddleActive:SetAtlas("_uiframe-activetab-center", true)
					if isActive then btn.MiddleActive:Show() else btn.MiddleActive:Hide() end
				end
				if btn.Left then
					btn.Left:SetAtlas("uiframe-tab-left", true)
					if isActive then btn.Left:Hide() else btn.Left:Show() end
				end
				if btn.Right then
					btn.Right:SetAtlas("uiframe-tab-right", true)
					if isActive then btn.Right:Hide() else btn.Right:Show() end
				end
				if btn.Middle then
					btn.Middle:SetAtlas("_uiframe-tab-center", true)
					if isActive then btn.Middle:Hide() else btn.Middle:Show() end
				end
				if btn.Text then
					btn.Text:SetFontObject(isActive and "GameFontHighlightSmall" or "GameFontNormalSmall")
				end
			end
		end

		-- Restore default scrollbar.
		if SC.themeTargets and SC.themeTargets.scrollBar then
			local sb = SC.themeTargets.scrollBar
			sb:SetWidth(6)
			local thumb = sb:GetThumbTexture()
			if thumb then
				local c = SC:ThemeColor("divider")
				thumb:SetColorTexture(c[1], c[2], c[3], c[4])
				thumb:SetWidth(6)
				thumb:SetHeight(20)
			end
		end
		-- Restore Guides skill-line side-tab buttons
		if SC.guidesSkillTabBtns then
			for _, btn in ipairs(SC.guidesSkillTabBtns) do
				if btn.backdrop then btn.backdrop:Hide() end
				if btn.bgTex then btn.bgTex:Show() end
				-- Restore icon to fill the full button
				if btn.iconTex then
					btn.iconTex:ClearAllPoints()
					btn.iconTex:SetAllPoints(btn)
				end
			end
		end
		-- Restore default alert frame skin
		if SC.RefreshAlertTheme then SC:RefreshAlertTheme() end
	end,
})
