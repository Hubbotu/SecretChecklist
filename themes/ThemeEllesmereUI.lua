-- =================================================================
-- SecretChecklist/themes/ThemeEllesmereUI.lua
-- EllesmereUI integration theme.
--
-- EllesmereUI 8.6+ exposes a public skinning API for third-party addons:
-- EllesmereUI.RegisterSkin(name, fn) hands us a facade `S` whose primitives
-- paint our frames in the user's active EUI style and keep them in sync with
-- their live accent / theme / font settings.
-- Developer guide: Interface\AddOns\EllesmereUI\SKINNING_API.md
--
-- Two parts of that contract shape this file:
--
--   * The callback fires once, at PLAYER_LOGIN (or immediately when we
--     register later than that), and never fires at all when EUI's skin
--     module is disabled or the user switched us off per-addon. So `S`
--     arriving is the ONLY reliable signal that this theme can paint
--     anything -- hence Available starts false and is flipped in the
--     callback rather than being derived from "is EllesmereUI loaded".
--
--   * The primitives remove art by alpha only, and the textures they add
--     live in EUI-private per-frame state we cannot reach. Adding a skin is
--     live; REMOVING one needs a /reload. That is EUI's own documented
--     behaviour for its Blizzard window skins and it applies to us too,
--     which is why OnReset restores only what is genuinely ours and asks
--     for a reload for the rest.
-- =================================================================

local SC = _G.SecretChecklist
if not SC then return end

local THEME_KEY = "EllesmereUI"

-- Skinning facade handed to us by EllesmereUI. nil until it dispatches.
SC._euiSkin = nil

-- ==============================================
-- COLOUR RESOLUTION
-- ==============================================
-- The theme's colour entries are functions so SC:ThemeColor resolves them on
-- every read. EUI mutates its accent table in place during theme cross-fades,
-- so these values must never be cached across calls.

local FALLBACK_PANEL  = { 0.08, 0.08, 0.08, 0.92 }
local FALLBACK_ACCENT = { 0.047, 0.824, 0.616 }

local function PanelColor(alpha)
	local S = SC._euiSkin
	if not S then
		return { FALLBACK_PANEL[1], FALLBACK_PANEL[2], FALLBACK_PANEL[3], alpha or FALLBACK_PANEL[4] }
	end
	local r, g, b, a = S.GetPanelColor()
	return { r, g, b, alpha or a }
end

local function AccentColor(alpha, scale)
	local S = SC._euiSkin
	local r, g, b
	if S then
		r, g, b = S.GetAccentColor()
	else
		r, g, b = FALLBACK_ACCENT[1], FALLBACK_ACCENT[2], FALLBACK_ACCENT[3]
	end
	scale = scale or 1
	return { r * scale, g * scale, b * scale, alpha or 1 }
end

-- ==============================================
-- SKIN APPLICATION
-- ==============================================

-- One physical pixel, in the coordinate space of the frame it is drawn in.
--
-- The theme draws a few hairlines itself. At a UI scale that is not EUI's
-- "perfect" scale, a width of 1 is not one screen pixel, so those lines round
-- inconsistently -- some land on 1px, some on 2, some vanish. PP.perfect is
-- 768 / physical screen height; dividing by the frame's own effective scale
-- converts it into that frame's units.
--
-- PP.mult is deliberately only the fallback: it is PP.perfect over UIParent's
-- scale, which is right for the options panel and wrong for a frame with a
-- scale of its own.
--
-- EllesmereUI.PP is a public entry point but is not in SKINNING_API.md, so
-- every read is guarded and the whole thing degrades to 1.
local function OnePixel(frame)
	local pp = EllesmereUI and EllesmereUI.PP
	local scale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale()
	if pp and pp.perfect and scale and scale > 0 then
		return pp.perfect / scale
	end
	return (pp and pp.mult) or 1
end

local function ApplySkin()
	local S = SC._euiSkin
	if not S then return end
	local frame = _G.SecretChecklistFrame
	if not frame then return end

	-- ---- Main window ----
	-- Shell fades the PortraitFrameTemplate art itself and paints the EUI
	-- backdrop plus window border, so NineSlice / Bg / TopTileStreaks need no
	-- separate handling here.
	S.Shell(frame)

	-- The engine has a RemovePortrait helper but it is not on the public
	-- facade, so fade the portrait the same alpha-only way the primitives do.
	local pc = frame.PortraitContainer
	if pc then
		S.FadeRegions(pc)
		if pc.portrait then pc.portrait:SetAlpha(0) end
	end
	if frame.portrait then frame.portrait:SetAlpha(0) end

	if frame.CloseButton then S.CloseButton(frame.CloseButton) end
	if frame.Inset then S.Inset(frame.Inset) end

	-- Our own inset fill would sit on top of the shell backdrop.
	if SC.themeTargets and SC.themeTargets.insetBg then
		SC.themeTargets.insetBg:Hide()
	end

	local title = (frame.TitleContainer and frame.TitleContainer.TitleText) or frame.TitleText
	if title then S.Font(title) end

	-- ---- Progress counters and paging ----
	if frame.ProgressBar then
		S.Font(frame.ProgressBar.TotalText)
		S.Font(frame.ProgressBar.MindSeekerText)
		if frame.ProgressBar.Separator then S.Font(frame.ProgressBar.Separator) end
	end
	local paging = frame.PagingFrame
	if paging then
		S.PageButton(paging.PrevPageButton, "<")
		S.PageButton(paging.NextPageButton, ">")
		S.Font(paging.PageText)
	end

	if frame.FilterDropdown then S.Dropdown(frame.FilterDropdown) end
	if SC.guidesSearchBox then S.EditBox(SC.guidesSearchBox) end

	-- ---- Bottom tab row ----
	-- EUI resolves tab selection from tab.isSelected when the parent is not a
	-- PanelTemplates-managed tab system (ours is not); SetTabActive keeps that
	-- flag current and re-calls S.Tab, which is idempotent.
	for _, btn in ipairs(SC.tabButtons_list or {}) do
		btn._euiSkinned = true
		S.Tab(btn)
	end

	-- ---- Guides panel ----
	if SC.guidesLinkBtn then
		S.Button(SC.guidesLinkBtn)
		-- The Guide button is disabled until an entry has a URL, so mirror the
		-- enabled/disabled label colour rather than forcing plain white.
		S.StateButtonLabel(SC.guidesLinkBtn)
	end
	-- The Info/Model sub-tabs are deliberately left alone.  They are hidden in
	-- the default "sidetabs" guide style, and in "horizontal" style
	-- SwitchDetailTab rewrites their background colour on every switch, which
	-- would fight the Tab primitive.  They already read as flat dark plates.
	--
	-- Skill-line side tabs: flat block instead of the SpellBook parchment tab
	-- art, with the icon squared and bordered. Button's art removal would take
	-- the icon too, so keep it explicitly.
	for _, btn in ipairs(SC.guidesSkillTabBtns or {}) do
		S.Button(btn, { "iconTex" })
		if btn.iconTex then S.SquareIcon(btn.iconTex, btn) end
	end

	-- ---- Scrollbar thumb ----
	-- S.ScrollBar targets MinimalScrollBar-shaped bars (Track / Back / Forward);
	-- ours is a plain Slider, so it is a no-op there. Colour the thumb from the
	-- theme instead.
	if SC.themeTargets and SC.themeTargets.scrollBar then
		local thumb = SC.themeTargets.scrollBar:GetThumbTexture()
		if thumb then
			local c = SC:ThemeColor("divider")
			thumb:SetColorTexture(c[1], c[2], c[3], c[4])
		end
	end

	-- ---- Divider ----
	-- Drawn by the Guides panel at a fixed width; narrowed here to a single
	-- screen pixel so it matches how EllesmereUI draws its own hairlines.
	if SC.themeTargets and SC.themeTargets.divider then
		SC.themeTargets.divider:SetWidth(OnePixel(SC.themeTargets.divider))
	end

	-- ---- Toasts ----
	if SC.RefreshAlertTheme then SC:RefreshAlertTheme() end

	-- ---- Live recolouring ----
	-- Frames painted by the primitives track EUI changes on their own. The
	-- elements we coloured ourselves (rows, divider, scrollbar thumb, toasts)
	-- do not, so re-run the theme when EUI's looks change.
	if not SC._euiLooksHooked then
		SC._euiLooksHooked = true
		S.OnLooksChanged(function()
			if SC.currentThemeName == THEME_KEY then
				SC:ApplyTheme(THEME_KEY)
			end
		end)
	end
end

local function ResetSkin()
	-- Only our own elements can be put back. Everything the EUI primitives
	-- painted (window shell, tab plates, buttons) lives in state private to
	-- EllesmereUI, so a full revert needs a reload -- the same rule EUI
	-- documents for its own skins.
	if SC.themeTargets and SC.themeTargets.insetBg then
		SC.themeTargets.insetBg:Show()
		local c = SC:ThemeColor("insetBg")
		SC.themeTargets.insetBg:SetColorTexture(c[1], c[2], c[3], c[4])
	end
	if SC.RefreshAlertTheme then SC:RefreshAlertTheme() end
	print("|cffffcc00SecretChecklist:|r EllesmereUI skinning stays on existing frames until you |cff00ff00/reload|r.")
end

-- ==============================================
-- THEME REGISTRATION
-- ==============================================

SC:RegisterTheme(THEME_KEY, {
	Name        = "EllesmereUI",
	Description = "Matches your EllesmereUI profile — window style, accent colour and UI font. Requires EllesmereUI.",
	-- No NameKey: "EllesmereUI" is the addon's own name and stays as it is.
	DescKey     = "THEME_ELLESMEREUI_DESC",
	-- Flipped to true only when EllesmereUI actually dispatches our skin
	-- callback. Merely having EllesmereUI loaded is not enough: the API is a
	-- silent no-op when its skin module is off, and users can disable
	-- third-party skinning per addon.
	Available   = false,
	colors = {
		insetBg = function() return PanelColor() end,
		rowEven = function() return { 1, 1, 1, 0.04 } end,
		rowOdd  = function() return { 0, 0, 0, 0.12 } end,
		rowSel  = function() return AccentColor(0.28) end,
		rowHov  = function() return { 1, 1, 1, 0.08 } end,
		divider = function() return AccentColor(0.55) end,
	},
	-- Squared icons, matching how EUI treats icons elsewhere.
	--
	-- SquareIcon is used for the texcoord crop only, without the parent frame:
	-- passing it draws EUI's own fixed black border, which takes no colour and
	-- would make collected and uncollected icons identical. The border is drawn
	-- here instead so the gold collected cue survives, as it does in the other
	-- two themes. EUI's guide says the colour getters exist for elements it has
	-- no primitive for; a tintable icon border is one of those.
	StyleIconSlot = function(button, isCollected, isMissing)
		local S = SC._euiSkin
		if not S then
			return SC.themes.Default.StyleIconSlot(button, isCollected, isMissing)
		end

		button.slotFrameCollected:Hide()
		button.slotFrameUncollected:Hide()
		button.slotFrameUncollectedInnerGlow:Hide()
		if button.iconFrame and button.iconFrame.backdrop then
			button.iconFrame.backdrop:Hide()
		end

		S.SquareIcon(button.iconTexture)
		S.SquareIcon(button.iconTextureUncollected)

		local border = button:GetIconBorder()
		-- Re-declared at a true one-pixel edge. The border is created with
		-- edgeSize = 1, which is one UI unit rather than one screen pixel, so at a
		-- non-perfect UI scale the gold ring rounds to two pixels on some icons and
		-- to none on others. SetBackdrop drops the current border colour, so the
		-- colour below has to follow it rather than precede it.
		border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = OnePixel(border) })
		if isCollected then
			local gold = SC.COLLECTED_GOLD
			border:SetBackdropBorderColor(gold[1], gold[2], gold[3], 1)
		else
			-- The same near-black EUI would have drawn, so uncollected icons keep
			-- the look the theme intends.
			border:SetBackdropBorderColor(0, 0, 0, 1)
		end
		border:Show()
	end,

	-- EUI's Tab primitive resolves selection from button.isSelected, which the
	-- caller sets before dispatching here.
	StyleTab = function(button, isActive)
		if button._euiSkinned and SC._euiSkin then
			SC._euiSkin.Tab(button)
			return
		end
		return SC.themes.Default.StyleTab(button, isActive)
	end,

	OnApply = ApplySkin,
	OnReset = ResetSkin,
})

-- ==============================================
-- REGISTRATION WITH ELLESMEREUI
-- ==============================================
-- Registering is free: if skinning is disabled the callback simply never runs,
-- and if EllesmereUI is absent the whole block is skipped.

if EllesmereUI and EllesmereUI.RegisterSkin then
	EllesmereUI.RegisterSkin("SecretChecklist", function(S)
		SC._euiSkin = S
		local theme = SC.themes and SC.themes[THEME_KEY]
		if theme then theme.Available = true end

		if SecretChecklistDB then
			-- themeUserSet is seeded by SC:InitDB at ADDON_LOADED. This callback
			-- fires at EllesmereUI's PLAYER_LOGIN, strictly later, so the value is
			-- already correct and no longer needs seeding here as well.
			if not SecretChecklistDB.themeUserSet then
				SC:ApplyTheme(THEME_KEY)
				return
			end
		end

		-- Core applies the saved theme at PLAYER_LOGIN, which may well run
		-- before this callback. In that case ApplyTheme fell back to Default
		-- (Available was still false) without overwriting the saved
		-- preference, so re-apply now that we can actually paint.
		local saved = SecretChecklistDB and SecretChecklistDB.theme
		if saved == THEME_KEY or SC.currentThemeName == THEME_KEY then
			SC:ApplyTheme(THEME_KEY)
		end
	end)
end
