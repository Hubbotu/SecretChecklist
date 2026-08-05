-- =============================================================
-- BeledarHelper.lua
-- Minimal BeledarOrchestra player client for SecretChecklist.
--
-- Listens on the "BeledarOrch" addon message prefix for MEASURE,
-- OVERRIDE, START, and RETRY messages broadcast by a raid leader
-- running BeledarOrchestra, then shows a compact popup to the
-- current player with their assigned emote for the active measure.
--
-- Automatically disabled if BeledarOrchestra itself is loaded so
-- no duplicate popups ever appear.
-- =============================================================

local SC = _G.SecretChecklist

local BH_PREFIX   = "BeledarOrch"
local BH_NPC_ID   = 255888   -- Divine Flame of Beledar (Hallowfall)
local BH_ZONE_ID  = 2215     -- Hallowfall

-- Panel geometry
local BH_PANEL_W  = 252
local BH_PANEL_H  = 128
local BH_HEADER_H = 24

-- Reads a colour from the active theme, falling back to the Default palette if
-- the theme registry is unavailable. This file used to hardcode a tooltip
-- backdrop and so was the one part of the addon that ignored the theme entirely.
local function BH_Color(key, fallback)
    if SC and SC.ThemeColor then
        return SC:ThemeColor(key)
    end
    return fallback
end

-- =============================================
-- EMOTE DEFINITIONS (mirrors BeledarOrchestra)
-- =============================================
local BH_EMOTES = {
    CHEER       = { command = "CHEER",        display = "/cheer"        },
    SING        = { command = "SING",         display = "/sing"         },
    DANCE       = { command = "DANCE",        display = "/dance"        },
    VIOLIN      = { command = "VIOLIN",       display = "/violin"       },
    APPLAUD     = { command = "APPLAUD",      display = "/applaud"      },
    CONGRATS    = { command = "CONGRATULATE", display = "/congratulate" },
    ROAR        = { command = "ROAR",         display = "/roar"         },
    PLACEHOLDER = { command = nil,            display = "?"             },
}

-- =============================================
-- DATASYNC: receive measures table from leader
-- =============================================
-- Mirrors BeledarOrchestra/DataSync.lua encoding:
--   P=PLACEHOLDER  S=SING   D=DANCE   V=VIOLIN
--   C=CHEER        A=APPLAUD  R=ROAR  G=CONGRATS
-- 25 measures × 40 slots = 1 000-char flat string,
-- broadcast by the leader in ≤238-char chunks.

local BH_DS_PREFIX = "BO_DATASYNC"
local BH_DS_DEC    = {
    P = "PLACEHOLDER", S = "SING",    D = "DANCE",  V = "VIOLIN",
    C = "CHEER",       A = "APPLAUD", R = "ROAR",   G = "CONGRATS",
}

local bh_dsMeasures = nil  -- decoded 25×40 table; nil until leader broadcasts
local bh_dsBuffer   = {}   -- chunk accumulator

local function BH_DecodeMeasures(str)
    if #str ~= 1000 then return nil end
    local tbl, idx = {}, 1
    for m = 1, 25 do
        tbl[m] = {}
        for b = 1, 40 do
            tbl[m][b] = BH_DS_DEC[str:sub(idx, idx)] or "PLACEHOLDER"
            idx = idx + 1
        end
    end
    return tbl
end

-- =============================================
-- MODULE STATE
-- =============================================
local bh_active  = false   -- set true after ADDON_LOADED check passes
local bh_state   = {
    currentMeasure   = nil,
    overrides        = {},
    measureLocked    = false,
    measureStarted   = false,
    countdownEndTime = nil,
    danceMoving      = false,
    danceComplete    = false,
    closed           = false,  -- player manually closed popup this session
}
local bh_ui      = {}
local bh_frame   = CreateFrame("Frame")

-- Defined at the bottom of the file; forward-declared so the START message
-- handler above it can start the countdown ticker.
local BH_StartCountdownTicker

-- Defined alongside BH_CreatePopup; forward-declared so BH_UpdatePopup, which
-- comes first, can repaint the panel when it shows it.
local BH_ApplyPopupTheme

-- =============================================
-- HELPERS
-- =============================================
-- Do NOT reimplement this by parsing UnitGUID.
--
-- That is the obvious-looking alternative and it is wrong on current clients:
-- UnitGUID returns a *secret string*, and splitting or converting one raises
--   "attempt to perform string conversion on a secret string value"
-- and taints execution. Taint is not confined to the addon that causes it, so a
-- helper for one NPC in one zone ends up breaking unrelated addons and
-- Blizzard's own UI. This runs from PLAYER_TARGET_CHANGED, so it fires on every
-- target change -- it was reported 350 times in a single session.
--
-- UnitCreatureID answers the question directly and never touches the GUID,
-- which is presumably why it exists.
local function BH_IsTargetFlame()
    local id = UnitCreatureID("target")
    return id and tonumber(id) == BH_NPC_ID
end

local function BH_IsHallowfall()
    return C_Map.GetBestMapForUnit("player") == BH_ZONE_ID
end

local function BH_ComputeRaidSlot()
    local members = {}
    if IsInRaid() then
        for i = 1, 40 do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if name then
                table.insert(members, {
                    subgroup = subgroup or 9,
                    raidIndex = i,
                    unit = "raid" .. i,
                })
            end
        end
    elseif IsInGroup() then
        local num = GetNumGroupMembers()
        for i = 1, num do
            local unit = (i == num) and "player" or ("party" .. i)
            local name = UnitFullName(unit)
            if name then
                table.insert(members, {
                    subgroup = 1,
                    raidIndex = i,
                    unit = unit,
                })
            end
        end
    else
        return 1  -- solo testing: treat as slot 1
    end
    table.sort(members, function(a, b)
        if a.subgroup ~= b.subgroup then return a.subgroup < b.subgroup end
        return a.raidIndex < b.raidIndex
    end)
    for visualSlot, member in ipairs(members) do
        if member.unit and UnitIsUnit(member.unit, "player") then
            return visualSlot
        end
    end
    return nil
end

-- The slot only changes when the roster does, but BH_UpdatePopup asks for it on
-- every call -- and during a countdown that is every frame. Recomputing meant
-- allocating a members table plus one table per raid member and sorting them,
-- roughly 2,400 table allocations a second straight into the GC.
local bh_cachedSlot = nil
local bh_slotDirty  = true

local function BH_InvalidateRaidSlot()
    bh_slotDirty = true
end

local function BH_GetRaidSlot()
    if bh_slotDirty then
        bh_cachedSlot = BH_ComputeRaidSlot()
        bh_slotDirty  = false
    end
    return bh_cachedSlot
end

local function BH_GetEmote(measure, slot)
    if not measure or not slot then return "PLACEHOLDER" end
    local ov = bh_state.overrides[measure]
    if ov and ov[slot] then return ov[slot] end
    if not bh_dsMeasures then return "PLACEHOLDER" end
    local row = bh_dsMeasures[measure]
    return (row and row[slot]) or "PLACEHOLDER"
end

-- =============================================
-- UI
-- =============================================
local function BH_UpdatePopup()
    if not bh_ui.frame then return end

    -- Hide (and reset closed flag) when no longer targeting the NPC
    if not BH_IsTargetFlame() then
        if bh_ui.frame:IsShown() then bh_ui.frame:Hide() end
        bh_state.closed = false
        return
    end

    -- Player manually closed it this targeting session
    if bh_state.closed then return end

    if not bh_ui.frame:IsShown() then
        -- Repaint on show: the player may have changed theme since last time.
        if BH_ApplyPopupTheme then BH_ApplyPopupTheme() end
        bh_ui.frame:Show()
    end

    local slot    = BH_GetRaidSlot()
    local token   = BH_GetEmote(bh_state.currentMeasure, slot)
    local emote   = BH_EMOTES[token] or BH_EMOTES.PLACEHOLDER
    local measure = bh_state.currentMeasure

    -- Measure / slot labels
    bh_ui.measureText:SetText(measure and ("Measure " .. measure) or "Waiting for measure")
    bh_ui.slotText:SetText(slot and ("Raid slot " .. slot) or "No raid slot")

    -- Modified indicator
    local isOverridden = measure and slot and bh_state.overrides[measure] and bh_state.overrides[measure][slot]
    bh_ui.modifiedText:SetShown(isOverridden and true or false)

    -- Button state
    local btn = bh_ui.button
    if bh_state.measureLocked then
        btn:SetText("Done!")
        btn:SetEnabled(false)
        btn:SetAlpha(0.5)
    elseif not measure then
        btn:SetText("Waiting...")
        btn:SetEnabled(false)
        btn:SetAlpha(0.6)
    elseif not slot then
        btn:SetText("No raid slot")
        btn:SetEnabled(false)
        btn:SetAlpha(0.6)
    elseif not bh_dsMeasures then
        btn:SetText("No data from leader")
        btn:SetEnabled(false)
        btn:SetAlpha(0.6)
    elseif token == "PLACEHOLDER" then
        btn:SetText("No assignment")
        btn:SetEnabled(false)
        btn:SetAlpha(0.6)
    elseif not bh_state.measureStarted then
        if bh_state.countdownEndTime then
            local remaining = bh_state.countdownEndTime - GetTime()
            if remaining > 0 then
                btn:SetText(string.format("Get ready... %d", math.ceil(remaining)))
                btn:SetEnabled(false)
                btn:SetAlpha(0.8)
            else
                bh_state.measureStarted = true
                bh_state.countdownEndTime = nil
                btn:SetText(emote.display)
                btn:SetEnabled(true)
                btn:SetAlpha(1)
            end
        else
            btn:SetText(emote.display .. " (waiting)")
            btn:SetEnabled(false)
            btn:SetAlpha(0.6)
        end
    else
        btn:SetText(emote.display)
        btn:SetEnabled(true)
        btn:SetAlpha(1)
    end
end

local function BH_PressEmote()
    local slot    = BH_GetRaidSlot()
    local measure = bh_state.currentMeasure

    if not slot or not measure then
        BH_UpdatePopup()
        return
    end

    -- Allow pressing if countdown expired but flag not yet set
    if not bh_state.measureStarted then
        if bh_state.countdownEndTime and (bh_state.countdownEndTime - GetTime()) <= 0 then
            bh_state.measureStarted = true
            bh_state.countdownEndTime = nil
        else
            return
        end
    end

    if bh_state.measureLocked then return end

    local token = BH_GetEmote(measure, slot)
    local emote = BH_EMOTES[token]
    if not emote or not emote.command then return end

    DoEmote(emote.command)
    bh_state.measureLocked = true

    if IsInGroup() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        C_ChatInfo.SendAddonMessage(BH_PREFIX, string.format("PERFORMED:%d:%d", measure, slot), channel)
    end

    -- DANCE requires move-then-stop; register movement tracking
    if token == "DANCE" then
        bh_frame:RegisterEvent("PLAYER_STARTED_MOVING")
        bh_frame:RegisterEvent("PLAYER_STOPPED_MOVING")
    end

    BH_UpdatePopup()
end

-- Recolours the panel from the active theme. Applied when the popup is shown
-- rather than through a theme-change callback: it is shown and hidden on every
-- target change, so the next show repaints it, and that avoids adding another
-- global hook for a frame most players never see.
BH_ApplyPopupTheme = function()
    local f = bh_ui.frame
    if not f then return end

    local panel  = BH_Color("insetBg", { 0.12, 0.10, 0.08, 0.98 })
    local border = BH_Color("divider", { 0.30, 0.25, 0.20, 0.80 })
    local header = BH_Color("rowSel",  { 0.25, 0.20, 0.10, 0.60 })

    -- Floating over the world, so keep it readable even when the theme's panel
    -- fill is semi-transparent.
    f:SetBackdropColor(panel[1], panel[2], panel[3], math.max(panel[4] or 1, 0.92))
    f:SetBackdropBorderColor(border[1], border[2], border[3], 1)
    bh_ui.headerBg:SetColorTexture(header[1], header[2], header[3], math.max(header[4] or 0.6, 0.55))
    bh_ui.headerLine:SetColorTexture(border[1], border[2], border[3], 1)
end

local function BH_CreatePopup()
    local f = CreateFrame("Frame", "SecretChecklistBeledarHelper", UIParent, "BackdropTemplate")
    f:SetSize(BH_PANEL_W, BH_PANEL_H)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    f:Hide()
    bh_ui.frame = f

    -- Restore where the player last dragged it, as the main window does.
    local pos = SecretChecklistDB and SecretChecklistDB.beledarPos
    if pos and pos.point then
        f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 360, -120)
    end

    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        if point and SecretChecklistDB then
            SecretChecklistDB.beledarPos = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)

    -- The provenance line used to be a label anchored over the title. It is a
    -- tooltip now: it matters once, when you wonder where the panel came from.
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Beledar Assignment", 1, 0.82, 0)
        GameTooltip:AddLine("via SecretChecklist", 0.6, 0.6, 0.6)
        GameTooltip:AddLine("Drag to move", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ---- Header ----
    local headerBg = f:CreateTexture(nil, "ARTWORK")
    headerBg:SetPoint("TOPLEFT", 1, -1)
    headerBg:SetPoint("TOPRIGHT", -1, -1)
    headerBg:SetHeight(BH_HEADER_H)
    bh_ui.headerBg = headerBg

    local headerLine = f:CreateTexture(nil, "OVERLAY")
    headerLine:SetPoint("TOPLEFT", headerBg, "BOTTOMLEFT", 0, 0)
    headerLine:SetPoint("TOPRIGHT", headerBg, "BOTTOMRIGHT", 0, 0)
    headerLine:SetHeight(1)
    bh_ui.headerLine = headerLine

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", headerBg, "LEFT", 8, 0)
    title:SetText("Beledar Assignment")
    title:SetTextColor(1, 0.82, 0)

    -- Flat close button; UIPanelCloseButton is 32px and overhung the corner.
    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("RIGHT", headerBg, "RIGHT", -5, 0)
    local closeLbl = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeLbl:SetAllPoints()
    closeLbl:SetText("×")
    closeLbl:SetTextColor(0.65, 0.65, 0.65)
    closeBtn:SetScript("OnEnter", function() closeLbl:SetTextColor(1, 0.35, 0.35) end)
    closeBtn:SetScript("OnLeave", function() closeLbl:SetTextColor(0.65, 0.65, 0.65) end)
    closeBtn:SetScript("OnClick", function()
        bh_state.closed = true
        f:Hide()
    end)

    -- ---- Measure / slot, one row ----
    local measureText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    measureText:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -(BH_HEADER_H + 10))
    measureText:SetJustifyH("LEFT")
    measureText:SetText("Waiting for measure")
    bh_ui.measureText = measureText

    local slotText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slotText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -(BH_HEADER_H + 11))
    slotText:SetJustifyH("RIGHT")
    slotText:SetTextColor(0.65, 0.65, 0.65)
    slotText:SetText("No raid slot")
    bh_ui.slotText = slotText

    local modifiedText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modifiedText:SetPoint("TOPLEFT", measureText, "BOTTOMLEFT", 0, -4)
    modifiedText:SetJustifyH("LEFT")
    modifiedText:SetText("|cffffff00(Modified by leader)|r")
    modifiedText:Hide()
    bh_ui.modifiedText = modifiedText

    -- ---- Emote button: the only thing you act on, so it gets the space ----
    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    btn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    btn:SetHeight(34)
    btn:SetScript("OnClick", BH_PressEmote)
    btn:SetText("Waiting...")
    bh_ui.button = btn

    BH_ApplyPopupTheme()
    BH_UpdatePopup()
end

-- =============================================
-- MESSAGE HANDLER
-- =============================================
local function BH_HandleMessage(message)
    local parts = { strsplit(":", message) }
    local action = parts[1]

    if action == "MEASURE" then
        local n = tonumber(parts[2])
        if n == 0 then n = nil end
        bh_state.currentMeasure   = n
        bh_state.measureLocked    = false
        bh_state.measureStarted   = false
        bh_state.countdownEndTime = nil
        bh_state.danceMoving      = false
        bh_state.danceComplete    = false
        bh_frame:UnregisterEvent("PLAYER_STARTED_MOVING")
        bh_frame:UnregisterEvent("PLAYER_STOPPED_MOVING")
        BH_UpdatePopup()

    elseif action == "OVERRIDE" then
        local measure = tonumber(parts[2])
        local slot    = tonumber(parts[3])
        local token   = parts[4]
        if measure and slot and token then
            bh_state.overrides[measure] = bh_state.overrides[measure] or {}
            bh_state.overrides[measure][slot] = token
            BH_UpdatePopup()
        end

    elseif action == "CLEAR_OVERRIDES" then
        bh_state.overrides = {}
        BH_UpdatePopup()

    elseif action == "CLEAR_MEASURE" then
        local m = tonumber(parts[2])
        if m then
            bh_state.overrides[m] = nil
            BH_UpdatePopup()
        end

    elseif action == "RETRY" then
        local m = tonumber(parts[2])
        if m == bh_state.currentMeasure then
            bh_state.measureLocked    = false
            bh_state.measureStarted   = false
            bh_state.countdownEndTime = nil
            bh_state.danceMoving      = false
            bh_state.danceComplete    = false
            bh_frame:UnregisterEvent("PLAYER_STARTED_MOVING")
            bh_frame:UnregisterEvent("PLAYER_STOPPED_MOVING")
            BH_UpdatePopup()
        end

    elseif action == "PING" then
        -- Respond to leader version checks so SC users show as "SC-x.x.x" in
        -- BeledarOrchestra's version grid rather than "?" (no addon).
        if IsInGroup() then
            local channel = IsInRaid() and "RAID" or "PARTY"
            local ver = C_AddOns.GetAddOnMetadata("SecretChecklist", "Version") or "?"
            C_ChatInfo.SendAddonMessage(BH_PREFIX, "PONG:SC-" .. ver, channel)
        end

    elseif action == "START" then
        local m   = tonumber(parts[2])
        local dur = tonumber(parts[3]) or 10
        if m == bh_state.currentMeasure then
            bh_state.countdownEndTime = GetTime() + dur
            bh_state.measureStarted   = false
            bh_state.measureLocked    = false
            bh_state.danceMoving      = false
            bh_state.danceComplete    = false
            bh_frame:UnregisterEvent("PLAYER_STARTED_MOVING")
            bh_frame:UnregisterEvent("PLAYER_STOPPED_MOVING")
            BH_UpdatePopup()
            -- Attach the per-frame ticker only for the duration of this countdown.
            BH_StartCountdownTicker()
        end
    end
end

-- =============================================
-- DATASYNC MESSAGE HANDLER
-- =============================================
local function BH_HandleDataSync(message)
    local action = message:match("^([^:]+)")
    if action == "ANN" then
        bh_dsBuffer = {}
    elseif action == "DAT" then
        local n, total, data = message:match("^DAT:MEASURES:(%d+)/(%d+):(.+)$")
        n, total = tonumber(n), tonumber(total)
        if n and total and data then
            bh_dsBuffer[n] = data
            local count = 0
            for _ in pairs(bh_dsBuffer) do count = count + 1 end
            if count == total then
                local assembled = ""
                for i = 1, total do
                    if not bh_dsBuffer[i] then return end
                    assembled = assembled .. bh_dsBuffer[i]
                end
                local decoded = BH_DecodeMeasures(assembled)
                if decoded then
                    bh_dsMeasures = decoded
                    bh_dsBuffer   = {}
                    BH_UpdatePopup()
                end
            end
        end
    end
end

-- =============================================
-- EVENT HANDLER
-- =============================================
bh_frame:RegisterEvent("ADDON_LOADED")

bh_frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        -- If BeledarOrchestra loads (before or after us) disable the helper
        if name == "BeledarOrchestra" then
            bh_active = false
            bh_frame:UnregisterAllEvents()
            if bh_ui.frame then bh_ui.frame:Hide() end
            return
        end

        if name ~= "SecretChecklist" then return end

        -- BeledarOrchestra might already be loaded
        if C_AddOns.IsAddOnLoaded("BeledarOrchestra") then return end

        bh_active = true
        C_ChatInfo.RegisterAddonMessagePrefix(BH_PREFIX)
        C_ChatInfo.RegisterAddonMessagePrefix(BH_DS_PREFIX)
        BH_CreatePopup()

        bh_frame:RegisterEvent("CHAT_MSG_ADDON")
        bh_frame:RegisterEvent("PLAYER_TARGET_CHANGED")
        bh_frame:RegisterEvent("GROUP_ROSTER_UPDATE")
        -- The emote stacks we care about sit on the Divine Flame, i.e. on the
        -- "target" unit. RegisterUnitEvent filters in C, so raid/party/nameplate
        -- aura churn never reaches Lua -- plain RegisterEvent here meant every
        -- aura tick on every unit in a 20-man raid entered this handler.
        bh_frame:RegisterUnitEvent("UNIT_AURA", "target")
        bh_frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        bh_frame:RegisterEvent("ZONE_CHANGED")
        bh_frame:RegisterEvent("ZONE_CHANGED_INDOORS")
        return
    end

    if not bh_active then return end

    if event == "CHAT_MSG_ADDON" then
        local prefix, message = ...
        if prefix == BH_PREFIX then
            BH_HandleMessage(message)
        elseif prefix == BH_DS_PREFIX then
            BH_HandleDataSync(message)
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        BH_UpdatePopup()

    elseif event == "GROUP_ROSTER_UPDATE" then
        -- The only thing that can change our visual slot.
        BH_InvalidateRaidSlot()
        BH_UpdatePopup()

    elseif event == "UNIT_AURA" then
        -- Registered as a unit event on "target", so this only fires for the
        -- Divine Flame's own aura stacks. The follower UI does not validate the
        -- raid-wide combination (that is the leader's job), but a stack change
        -- is the signal that our own emote landed, so refresh the popup.
        BH_UpdatePopup()

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        if not BH_IsHallowfall() then
            if bh_ui.frame then bh_ui.frame:Hide() end
        end

    elseif event == "PLAYER_STARTED_MOVING" then
        -- DANCE step 1: broadcast that we started moving
        if bh_state.measureLocked and not bh_state.danceMoving then
            local slot    = BH_GetRaidSlot()
            local measure = bh_state.currentMeasure
            if slot and measure and BH_GetEmote(measure, slot) == "DANCE" then
                bh_state.danceMoving = true
                if IsInGroup() then
                    local channel = IsInRaid() and "RAID" or "PARTY"
                    C_ChatInfo.SendAddonMessage(BH_PREFIX, string.format("DANCE_MOVING:%d:%d", measure, slot), channel)
                end
            end
        end

    elseif event == "PLAYER_STOPPED_MOVING" then
        -- DANCE step 2: broadcast that we stopped moving
        if bh_state.measureLocked and bh_state.danceMoving and not bh_state.danceComplete then
            local slot    = BH_GetRaidSlot()
            local measure = bh_state.currentMeasure
            if slot and measure and BH_GetEmote(measure, slot) == "DANCE" then
                bh_state.danceComplete = true
                if IsInGroup() then
                    local channel = IsInRaid() and "RAID" or "PARTY"
                    C_ChatInfo.SendAddonMessage(BH_PREFIX, string.format("DANCE_STOPPED:%d:%d", measure, slot), channel)
                end
                bh_frame:UnregisterEvent("PLAYER_STARTED_MOVING")
                bh_frame:UnregisterEvent("PLAYER_STOPPED_MOVING")
            end
        end
    end
end)

-- Countdown ticker.
--
-- This used to be a permanent OnUpdate installed at file scope: it ran every
-- frame, for every player, for the whole session, even for the overwhelming
-- majority who never set foot in Hallowfall or join a Beledar group. It bailed
-- out in four checks, but a per-frame Lua call that exists to do nothing is
-- still the first thing anyone profiling addons goes looking for.
--
-- It is now attached only while a countdown is actually running -- a window of
-- a few seconds per measure -- and detaches itself as soon as that ends, so the
-- idle cost is zero.
local function BH_CountdownTick()
    if not (bh_active and bh_state.countdownEndTime) or bh_state.measureStarted then
        bh_frame:SetScript("OnUpdate", nil)
        return
    end
    if bh_state.countdownEndTime - GetTime() <= 0 then
        bh_state.measureStarted   = true
        bh_state.countdownEndTime = nil
        BH_UpdatePopup()
        bh_frame:SetScript("OnUpdate", nil)
        return
    end
    BH_UpdatePopup()
end

-- Call whenever countdownEndTime is set. Idempotent.
BH_StartCountdownTicker = function()
    if bh_active and bh_state.countdownEndTime and not bh_frame:GetScript("OnUpdate") then
        bh_frame:SetScript("OnUpdate", BH_CountdownTick)
    end
end
