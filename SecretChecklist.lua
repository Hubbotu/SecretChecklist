-- Localize frequently-used globals for performance
local type, pairs, ipairs = type, pairs, ipairs
local math_min = math.min
local select = select

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local SC = {}
_G.SecretChecklist = SC

-- ==============================================
-- SAVED VARIABLES
-- ==============================================

-- Bumped to 2 because the first cut of this migration never ran: dbVersion was
-- listed in DB_DEFAULTS, so the defaults loop stamped it to the current version
-- *before* the migration gate read it, and every existing profile looked
-- already-migrated. Profiles carrying that bogus stamp are cleaned by the
-- version-2 gate below.
local DB_VERSION = 2

-- Every key the addon persists, with its default.
--
-- dbVersion is deliberately NOT here: it must be read before defaults are
-- applied, and is stamped once, after migrations have run.
local DB_DEFAULTS = {
	hideMinimapButton    = false,
	hideAddonCompartment = false,
	minimapAngle         = 225,
	alertsEnabled        = true,
	guidesStyle          = "sidetabs",
	debugMode            = false,
	-- theme / themeUserSet are deliberately absent: nil is meaningful for both
	-- (it is what the ElvUI / EllesmereUI auto-select checks for on first run).
	tabFilters           = {},
}

-- Kinds a saved filter may legitimately contain. Used to prune keys left behind
-- by kinds that no longer exist.
local VALID_KINDS = {
	mount = true, pet = true, toy = true, achievement = true,
	quest = true, transmog = true, housing = true, mystery = true,
}

-- Top-level keys written by features that have since been removed. They persist
-- in every existing user's SavedVariables forever unless something deletes them.
local RETIRED_KEYS = {
	"filterKinds",  -- superseded by tabFilters.<tab>.kinds
	"filterStatus", -- superseded by tabFilters.<tab>.showCollected / showMissing
	"lastError",    -- removed error-reporting feature
	"lastReport",   -- removed error-reporting feature
}

-- Idempotent: safe to call more than once.
function SC:InitDB()
	-- A client crash mid-write can leave the SavedVariables file truncated, in
	-- which case the global may be absent or not a table. Indexing it would then
	-- error before anything else in the addon runs.
	if type(SecretChecklistDB) ~= "table" then
		SecretChecklistDB = {}
	end
	local db = SecretChecklistDB

	-- Read the stored version BEFORE applying defaults. If dbVersion were seeded
	-- as a default, every existing profile would be stamped current and skip
	-- every migration below -- which is exactly what the first version of this
	-- function did.
	local fromVersion = db.dbVersion or 0

	for key, default in pairs(DB_DEFAULTS) do
		if db[key] == nil then
			db[key] = (type(default) == "table") and {} or default
		end
	end

	-- Migrations are ordered and gated on the version the profile arrived with.
	-- Each step is written to be idempotent, so a profile that took the bogus
	-- version-1 stamp is corrected here rather than needing a separate step.
	if fromVersion < 2 then
		for _, key in ipairs(RETIRED_KEYS) do
			db[key] = nil
		end
		-- Installs predating themeUserSet: a theme already saved counts as the
		-- user's own choice, so upgrading never moves anyone off the theme they
		-- picked. Seeding it here -- before any auto-select runs -- is what stops
		-- an auto-pick being mistaken for a deliberate one. This used to be
		-- duplicated in the PLAYER_LOGIN handler and in the EllesmereUI skin
		-- callback because neither knew which would run first; with InitDB
		-- running at ADDON_LOADED, both are strictly later and can just read it.
		if db.themeUserSet == nil then
			db.themeUserSet = (db.theme ~= nil)
		end
		if type(db.tabFilters) == "table" then
			for _, filter in pairs(db.tabFilters) do
				if type(filter) == "table" and type(filter.kinds) == "table" then
					for kind in pairs(filter.kinds) do
						if not VALID_KINDS[kind] then
							filter.kinds[kind] = nil
						end
					end
				end
			end
		end
	end

	-- Stamped once, after every migration has had a chance to run.
	db.dbVersion = DB_VERSION

	return db
end

-- Called again from ADDON_LOADED; this early call keeps the file-scope readers
-- (the minimap button's saved angle, for one) working until they move.
SC:InitDB()

-- Globals required by AddonCompartmentFunc / Enter / Leave
-- When registered via RegisterAddon() (not TOC), the calling convention is:
--   func(_, menuInputData, menu)  where menuInputData.buttonName = "LeftButton"/"RightButton"
--   funcOnEnter(button, addonInfo)
--   funcOnLeave(button, addonInfo)
function SecretChecklist_OnAddonCompartmentClick(_, menuInputData, menu)
	local buttonName = menuInputData and menuInputData.buttonName or "LeftButton"
	if buttonName == "RightButton" then
		if SC.OpenOptionsPanel then SC:OpenOptionsPanel() end
	else
		SC:ToggleSecretsFrame()
	end
end

function SecretChecklist_OnAddonCompartmentEnter(button, addonInfo)
	local L = _G.SecretChecklistLocale or {}
	GameTooltip:SetOwner(button, "ANCHOR_LEFT")
	GameTooltip:SetText(L["ADDON_NAME"] or "Secret Checklist", 1, 1, 1)
	GameTooltip:AddLine(L["TOOLTIP_CLICK_TOGGLE"] or "Click to toggle window", 0.8, 0.8, 0.8)
	GameTooltip:AddLine(L["TOOLTIP_RIGHT_CLICK_OPTIONS"] or "Right-click to open options", 0.8, 0.8, 0.8)
	GameTooltip:Show()
end

function SecretChecklist_OnAddonCompartmentLeave(button, addonInfo)
	GameTooltip:Hide()
end

-- Entries are now defined in data/SecretEntries.lua

-- ==============================================
-- HELPER FUNCTIONS
-- ==============================================

function SC:GetEntryIcon(entry)
	if type(entry) ~= "table" then
		return FALLBACK_ICON
	end

	-- For mounts with mountID specified (e.g., Fathom Dweller)
	if type(entry.mountID) == "number" then
		if C_MountJournal and C_MountJournal.GetMountInfoByID then
			local _, _, icon = C_MountJournal.GetMountInfoByID(entry.mountID)
			if icon then
				return icon
			end
		end
	end

	-- For pets with speciesID (e.g., Jenafur)
	if type(entry.speciesID) == "number" then
		if C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID then
			local _, icon = C_PetJournal.GetPetInfoBySpeciesID(entry.speciesID)
			if icon then
				return icon
			end
		end
	end

	if type(entry.itemID) == "number" then
		if C_Item and C_Item.GetItemIconByID then
			local icon = C_Item.GetItemIconByID(entry.itemID)
			if icon then
				return icon
			end
		end
	end

	if type(entry.achievementID) == "number" then
		local _, _, _, _, _, _, _, _, _, icon = GetAchievementInfo(entry.achievementID)
		if icon then
			return icon
		end
	end
	-- Custom icon specified directly
	if type(entry.icon) == "number" or type(entry.icon) == "string" then
		return entry.icon
	end
	return FALLBACK_ICON
end

function SC:GetEntryName(entry)
	if type(entry) ~= "table" then
		return "Unknown"
	end

	-- Try to get localized name from game APIs
	if entry.kind == "mount" and type(entry.mountID) == "number" then
		if C_MountJournal and C_MountJournal.GetMountInfoByID then
			local name = C_MountJournal.GetMountInfoByID(entry.mountID)
			if name and name ~= "" then
				return name
			end
		end
	end

	if entry.kind == "pet" and type(entry.speciesID) == "number" then
		if C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID then
			local name = C_PetJournal.GetPetInfoBySpeciesID(entry.speciesID)
			if name and name ~= "" then
				return name
			end
		end
	end

	if (entry.kind == "toy" or entry.kind == "transmog" or entry.kind == "housing") and type(entry.itemID) == "number" then
		if C_Item and C_Item.GetItemInfo then
			local name = C_Item.GetItemInfo(entry.itemID)
			if name and name ~= "" then
				return name
			end
		end
	end

	if entry.kind == "achievement" and type(entry.achievementID) == "number" then
		local _, name = GetAchievementInfo(entry.achievementID)
		if name and name ~= "" then
			return name
		end
	end

	if entry.kind == "quest" and type(entry.questID) == "number" then
		if C_QuestLog and C_QuestLog.GetTitleForQuestID then
			local title = C_QuestLog.GetTitleForQuestID(entry.questID)
			if title and title ~= "" then
				return title
			end
		end
	end

	-- Fall back to hardcoded name in data file
	if type(entry.name) == "string" and entry.name ~= "" then
		return entry.name
	end

	return "Unknown"
end

-- Intentionally a no-op, kept as a stable call site for the panel files.
--
-- This used to call C_MountJournal.SetDefaultFilters / C_PetJournal.SetDefaultFilters
-- / C_ToyBox.ForceToyRefilter to "prime" the journals. Those are mutators, not
-- getters: every page turn, tab switch and filter change silently reset the
-- player's own Collections journal filters, and fought with addons that persist
-- journal state (Collectionator, BetterWardrobe, AllTheThings). They also fed a
-- MOUNT_JOURNAL_SEARCH_UPDATED -> refresh loop that had to be worked around in
-- TabOverview.
--
-- None of it was needed: GetMountInfoByID, GetNumCollectedInfo and PlayerHasToy
-- read account collection data directly and do not depend on journal filter
-- state or on the Collections UI having been opened.
function SC:RefreshCaches()
end

-- Status cache, keyed by entry table.
--
-- A single Overview page turn asks for entry status several times over: once
-- per entry to apply the collected/missing filter, again to build the sort key,
-- again per visible button to pick its border and colour, and again for the
-- progress counters -- and each answer costs 1-3 C API calls. The alert scan
-- walks every entry as well. Nothing about that changes between the calls.
--
-- "unknown" is deliberately never cached: it means the journal or catalog has
-- not finished loading, so re-asking is exactly the right behaviour. Only
-- settled answers are stored.
--
-- Invalidated wholesale by SC:InvalidateStatusCache, which the collection, bag
-- and housing event handlers call. Keys are entry tables from SC.entries, which
-- live for the session, so the cache is bounded and holds nothing else alive.
local statusCache, detailCache = {}, {}

function SC:InvalidateStatusCache()
	wipe(statusCache)
	wipe(detailCache)
end

function SC:GetEntryStatus(entry)
	-- Returns: "collected" | "missing" | "unknown" | "manual", plus optional detail
	if type(entry) ~= "table" then
		return "unknown", "Invalid entry"
	end

	local cached = statusCache[entry]
	if cached then
		return cached, detailCache[entry]
	end

	local status, detail
	if entry.kind == "manual" then
		status, detail = "manual", entry.note
	else
		local have, d = self:CheckEntry(entry)
		detail = d
		if have == true then
			status = "collected"
		elseif have == false then
			status = "missing"
		else
			status = "unknown"
		end
	end

	if status ~= "unknown" then
		statusCache[entry] = status
		detailCache[entry] = detail
	end
	return status, detail
end

function SC:CheckEntry(entry)
	-- Always check questID first — most secrets flag a hidden quest on completion,
	-- and this is more reliable than API-specific checks (e.g. ensemble transmog items).
	if type(entry.questID) == "number" and C_QuestLog and C_QuestLog.IsQuestFlaggedCompletedOnAccount then
		if C_QuestLog.IsQuestFlaggedCompletedOnAccount(entry.questID) == true then
			return true, "quest"
		end
	end

	if entry.kind == "toy" then
		if type(entry.itemID) ~= "number" then
			return nil, "Toy missing itemID."
		end
		local hasToy = PlayerHasToy(entry.itemID)
		if hasToy == true then
			return true, "toy"
		elseif hasToy == false then
			return false, "toy"
		end
		-- If PlayerHasToy returns nil, toy data might not be loaded yet
		if C_ToyBox and C_ToyBox.GetToyInfo then
			local toyName = C_ToyBox.GetToyInfo(entry.itemID)
			if toyName == nil then
				return nil, "Toy data has not finished loading yet."
			end
		end
		return false, "toy"
	end

	if entry.kind == "mount" then
		if not C_MountJournal or not C_MountJournal.GetMountInfoByID then
			return nil, "MountJournal API unavailable (try after fully logged in)."
		end

		-- Check if mount specified by mountID (e.g., Fathom Dweller)
		if type(entry.mountID) == "number" then
			local isCollected = select(11, C_MountJournal.GetMountInfoByID(entry.mountID))
			if isCollected == nil then
				return nil, "Mount data has not finished loading yet."
			end
			return isCollected == true, "mount"
		end

		local mountID
		if type(entry.itemID) == "number" and C_MountJournal.GetMountFromItem then
			mountID = C_MountJournal.GetMountFromItem(entry.itemID)
		end
		if type(mountID) == "number" then
			local isCollected = select(11, C_MountJournal.GetMountInfoByID(mountID))
			if isCollected == nil then
				return nil, "Mount data has not finished loading yet."
			end
			return isCollected == true, "mount"
		end

		return nil, "Could not map to a mount yet (no mountID or itemID matched)."
	end

	if entry.kind == "pet" then
		if not C_PetJournal then
			return nil, "PetJournal API unavailable (try after fully logged in)."
		end

		if type(entry.speciesID) ~= "number" then
			return nil, "Pet missing speciesID."
		end
		if not C_PetJournal.GetNumCollectedInfo then
			return nil, "PetJournal API unavailable."
		end
		local numOwned = select(1, C_PetJournal.GetNumCollectedInfo(entry.speciesID))
		if numOwned == nil then
			return nil, "Pet data has not finished loading yet."
		end
		return numOwned > 0, "pet"
	end

	if entry.kind == "achievement" then
		local _, _, _, completed = GetAchievementInfo(entry.achievementID)
		return completed == true, "achievement"
	end

	if entry.kind == "quest" then
		if C_QuestLog and C_QuestLog.IsQuestFlaggedCompletedOnAccount then
			return C_QuestLog.IsQuestFlaggedCompletedOnAccount(entry.questID) == true, "quest"
		end
		return nil, "Quest API unavailable."
	end

	if entry.kind == "transmog" then
		if not C_TransmogCollection then
			return nil, "TransmogCollection API unavailable."
		end
		if type(entry.itemID) ~= "number" then
			return nil, "Transmog missing itemID."
		end
		-- Check if player knows this appearance
		if C_TransmogCollection.PlayerHasTransmog then
			local hasTransmog = C_TransmogCollection.PlayerHasTransmog(entry.itemID)
			if hasTransmog ~= nil then
				return hasTransmog == true, "transmog"
			end
		end
		-- Fallback: use C_TransmogCollection.GetItemInfo
		local _, _, _, _, isCollected = C_TransmogCollection.GetItemInfo(entry.itemID)
		if isCollected ~= nil then
			return isCollected == true, "transmog"
		end
		return nil, "Appearance data has not finished loading yet."
	end

	if entry.kind == "housing" then
		if not C_HousingCatalog or not C_HousingCatalog.GetCatalogEntryInfoByItem then
			return nil, "HousingCatalog API unavailable."
		end
		if type(entry.itemID) ~= "number" then
			return nil, "Housing entry missing itemID."
		end
		-- pcall guards against Lua errors thrown by the API during catalog reloads
		-- (e.g. zone transitions), matching the same pattern used by HousingCompanion
		-- and AllTheThings for robustness.
		local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, entry.itemID, true)
		if not ok or not info then
			return nil, "Housing catalog data not loaded yet."
		end
		-- Primary ownership check: totalNumStored + numPlaced + totalNumPlaced.
		-- entrySubtype (0=Invalid, 1=Unowned, 2=OwnedModified, 3=OwnedUnmodified) is
		-- documented as the ownership signal but has been observed to stay 1 even for
		-- owned items (Blizzard API inconsistency confirmed in-game). The quantity fields
		-- are reliable: storage-loaded items show totalNumStored>0 when owned.
		local totalOwned = (info.totalNumStored or 0) + (info.numPlaced or 0) + (info.totalNumPlaced or 0)
		if totalOwned > 0 then
			return true, "housing"
		end
		-- Fallback to entrySubtype for items where quantity fields are absent or zero.
		-- subtype 0/nil = catalog not merged yet → nil (unknown).
		-- subtype 1 = API reports Unowned; guard with _housingStorageReady to avoid
		-- false-negative flicker during zone transitions where storage briefly clears.
		local subtype = info.entryID and info.entryID.entrySubtype
		if not subtype or subtype == 0 then
			return nil, "Housing catalog data not loaded yet."
		end
		if subtype == 1 and not SC._housingStorageReady then
			return nil, "Housing storage not loaded yet."
		end
		return (subtype ~= 1), "housing"
	end

	if entry.kind == "mystery" then
		if entry.steps and #entry.steps > 0 then
			local allDone = true
			for _, step in ipairs(entry.steps) do
				if SC:GetStepStatus(step) ~= "done" then
					allDone = false
					break
				end
			end
			if allDone then
				return true, "mystery"
			end
		end
		return nil, "Reward unknown – in active investigation"
	end

	if entry.kind == "manual" then
		return nil, entry.note or "Manual check"
	end

	return nil, "Unknown kind"
end

-- Returns the total count across step.itemID or any ID in step.itemIDs (whichever is set).
local function StepItemCount(step)
	if step.itemIDs then
		local total = 0
		for _, id in ipairs(step.itemIDs) do
			total = total + C_Item.GetItemCount(id, true, nil, nil, true)
		end
		return total
	elseif step.itemID then
		return C_Item.GetItemCount(step.itemID, true, nil, nil, true)
	end
	return 0
end

-- Returns the status of a single progress step:
--   "done"    – quest flagged completed
--   "ready"   – quest not done, but item(s) are in bags/bank
--   "missing" – quest not done and item(s) not found
function SC:GetStepStatus(step)
	if step.questID and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
		if C_QuestLog.IsQuestFlaggedCompleted(step.questID) then
			return "done"
		end
	end
	if step.criteriaID and step.achievementID and GetAchievementCriteriaInfoByID then
		local _, _, criteriaCompleted = GetAchievementCriteriaInfoByID(step.achievementID, step.criteriaID)
		if criteriaCompleted then return "done" end
	end
	if step.achievementID then
		local _, _, _, completed = GetAchievementInfo(step.achievementID)
		if completed then return "done" end
	end
	if step.renownReq and C_MajorFactions and C_MajorFactions.GetCurrentRenownLevel then
		local current = C_MajorFactions.GetCurrentRenownLevel(step.renownReq.factionID)
		if current and current >= step.renownReq.level then return "done" end
		return "missing"
	end
	if step.mindseekerReq then
		local count = 0
		for _, e in ipairs(SC.entries or {}) do
			if e.mindSeeker and SC:GetEntryStatus(e) == "collected" then
				count = count + 1
			end
		end
		if count >= step.mindseekerReq then return "done" end
		return "missing"
	end
	if step.repReq then
		local data = C_Reputation and C_Reputation.GetFactionDataByID and
		C_Reputation.GetFactionDataByID(step.repReq.factionID)
		local standingID = data and data.reaction or 0
		if standingID >= step.repReq.standingID then return "done" end
		return "missing"
	end
	if SC:ResolveSubsteps(step) then
		-- If the parent item is already in bags, it's done regardless of substep state
		-- (substep items may be consumed on combine, e.g. Quartered Ancient Rings)
		if (step.itemID or step.itemIDs) and StepItemCount(step) >= (step.count or 1) then return "done" end
		-- If a final item is required but not yet obtained, stay red — substep rows show per-key progress
		if step.itemID or step.itemIDs then return "missing" end
		-- No final item: derive status purely from substep completion
		local done, total = SC:GetSubstepProgress(step)
		if done >= total then return "done" end
		return "missing"
	end
	if step.itemID or step.itemIDs then
		local have = StepItemCount(step)
		if have >= (step.count or 1) then
			-- No questID means having the item IS completion (e.g. ring drops, climb rewards).
			-- With a questID, the item is a prerequisite you're holding but haven't used yet → yellow.
			if not step.questID then return "done" end
			return "ready"
		end
		if step.itemID and PlayerHasToy and PlayerHasToy(step.itemID) then return "done" end
		-- Housing items go to the catalog (not bags) on purchase — check ownership there.
		if step.itemID and C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
			local ok, hinfo = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, step.itemID, true)
			if ok and hinfo then
				local hTotal = (hinfo.totalNumStored or 0) + (hinfo.numPlaced or 0) + (hinfo.totalNumPlaced or 0)
				if hTotal > 0 then return "done" end
			end
		end
	end
	return "missing"
end

-- Returns the effective substep list for a step, resolving factionSubsteps by the
-- player's current faction when present, falling back to step.substeps.
function SC:ResolveSubsteps(step)
	if step.factionSubsteps then
		local fkey = (UnitFactionGroup and UnitFactionGroup("player") == "Alliance") and "alliance" or "horde"
		return step.factionSubsteps[fkey]
	end
	return step.substeps
end

-- Returns (doneCount, total) for a step with substeps.
-- Collection: doneCount = number of substeps whose item/quest is completed.
-- Chain:      doneCount = index of the currently-held item (0 = nothing held).
function SC:GetSubstepProgress(step)
	local subs = SC:ResolveSubsteps(step)
	if not subs then return 0, 0 end
	if step.chain then
		local total = #subs
		local highestHeld = 0
		for idx, sub in ipairs(subs) do
			if sub.itemID and C_Item.GetItemCount(sub.itemID, true, nil, nil, true) >= 1 then
				highestHeld = idx
			end
		end
		return highestHeld, total
	else
		local done, total = 0, 0
		for _, sub in ipairs(subs) do
			local subTotal = sub.count or 1
			total = total + subTotal
			if sub.questID and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
					and C_QuestLog.IsQuestFlaggedCompleted(sub.questID) then
				done = done + subTotal
			elseif sub.itemID then
				local have = C_Item.GetItemCount(sub.itemID, true, nil, nil, true)
				done = done + math_min(have, subTotal)
			end
		end
		return done, total
	end
end

SLASH_SECRETCHECKLIST1 = "/secrets"
SLASH_SECRETCHECKLIST2 = "/secretchecklist"
SlashCmdList.SECRETCHECKLIST = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

	if msg == "options" or msg == "settings" then
		if SC.OpenOptionsPanel then
			SC:OpenOptionsPanel()
		end
		return
	end

	if msg == "debug" then
		SecretChecklistDB.debugMode = not SecretChecklistDB.debugMode
		if SecretChecklistDB.debugMode then
			print(
			"|cffffcc00SecretChecklist:|r Debug mode |cff00ff00enabled|r — stepsOverrideOnDone is suppressed. Type /secrets debug to disable.")
		else
			print("|cffffcc00SecretChecklist:|r Debug mode |cffff4444disabled|r.")
		end
		-- Refresh the guides panel so step colours update immediately
		if SC.onFilterChange then SC.onFilterChange() end
		return
	elseif msg == "minimap" then
		if SC.ToggleMinimapButton then
			SC:ToggleMinimapButton()
		end
	elseif msg == "alert" then
		-- Fire a test toast with the first entry in the list (dev/debug helper)
		local testEntry = SC.entries and SC.entries[1]
		if testEntry and SC.FireSecretAlert then
			SC:FireSecretAlert(testEntry)
		else
			print("|cffffcc00SecretChecklist:|r Alert system not ready yet.")
		end
	else
		-- Default: open UI
		if SC.OpenCollectionsSecretsTab then
			SC:OpenCollectionsSecretsTab()
		end
	end
end
