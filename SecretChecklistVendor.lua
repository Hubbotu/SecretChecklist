-- =============================================================
-- SecretChecklistVendor.lua
-- Notices when a tracked secret is actually for sale in front of you.
--
-- Some secrets are gated behind a vendor that only stocks them some of the
-- time. Crimson Tidestallion is the expensive case: Mrrl in Nazjatar lists it
-- on no fixed schedule, and the trading chain that pays for it is built from
-- items that expire after 24 hours -- so starting the chain on a day the mount
-- is not listed throws the whole thing away.
--
-- There is no way to ask the game whether a vendor is stocking something from
-- a distance; a merchant's inventory only exists while its window is open. So
-- this does the one thing that is possible: when a merchant window opens, it
-- reads what is on offer, and records the date for anything the addon tracks.
--
-- That turns "squint at Mrrl's list with the cape equipped" into an answer, and
-- gives the Guides tab a date to show for when a secret was last seen for sale.
-- =============================================================

local SC = _G.SecretChecklist
if not SC then return end

local L = _G.SecretChecklistLocale or {}

-- Today, by the realm's clock rather than the player's, since vendor stock
-- turns over on server time.
local function ServerDateStamp()
	if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
		local t = C_DateAndTime.GetCurrentCalendarTime()
		if t and t.year and t.month and t.monthDay then
			return string.format("%04d-%02d-%02d", t.year, t.month, t.monthDay)
		end
	end
	return nil
end

-- itemID -> entry, for every entry whose reward is an item. Built once on first
-- use: entries do not change at runtime, and most sessions never open a
-- merchant that matters.
local watchedItems
local function WatchedItems()
	if watchedItems then return watchedItems end
	watchedItems = {}
	for _, entry in ipairs(SC.entries or {}) do
		if type(entry.itemID) == "number" then
			watchedItems[entry.itemID] = entry
		end
	end
	return watchedItems
end

-- The date a tracked item was last seen on a vendor, or nil.
function SC:GetVendorSeenDate(itemID)
	local db = SecretChecklistDB
	return db and db.vendorSeen and db.vendorSeen[itemID] or nil
end

local function Say(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00SecretChecklist:|r " .. msg)
end

local function IsEquipped(itemID)
	local isEquipped = (C_Item and C_Item.IsEquippedItem) or IsEquippedItem
	if not isEquipped then return true end
	local ok, equipped = pcall(isEquipped, itemID)
	return ok and equipped == true
end

-- Every itemID currently on the open merchant.
local function MerchantItemIDs()
	local ids = {}
	local numItems = GetMerchantNumItems and GetMerchantNumItems() or 0
	for i = 1, numItems do
		-- The link rather than an id getter: GetMerchantItemLink has been stable
		-- for as long as merchants have existed, and the id falls out of it.
		local link = GetMerchantItemLink and GetMerchantItemLink(i)
		local itemID = link and tonumber(link:match("item:(%d+)"))
		if itemID then ids[itemID] = link end
	end
	return ids
end

local function ScanMerchant()
	local today = ServerDateStamp()
	if not today then return end

	local db = SecretChecklistDB
	if type(db) ~= "table" then return end
	db.vendorSeen = db.vendorSeen or {}

	local onSale  = MerchantItemIDs()
	local watched = WatchedItems()
	local mapID   = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")

	-- Anything tracked and on sale gets recorded, at any vendor anywhere.
	for itemID, link in pairs(onSale) do
		local entry = watched[itemID]
		if entry then
			local alreadySeenToday = (db.vendorSeen[itemID] == today)
			db.vendorSeen[itemID] = today
			-- Once per item per day: reopening the same vendor while deciding
			-- what to buy should not repeat itself.
			if not alreadySeenToday and SC.GetEntryStatus and SC:GetEntryStatus(entry) ~= "collected" then
				Say(link .. " " .. (L["VENDOR_AVAILABLE_NOW"] or "is for sale here right now."))
			end
		end
	end

	-- Entries that asked to be watched in this zone report the negative too.
	--
	-- Silence is the wrong answer for these. At Mrrl it is indistinguishable
	-- from "you forgot the cape", from "the addon is broken", and from "not
	-- today" -- and the whole point is deciding whether to start a chain that
	-- costs a day if you get it wrong.
	if not mapID then return end
	for _, entry in ipairs(SC.entries or {}) do
		local watch = entry.vendorWatch
		if watch and watch.mapID == mapID and type(entry.itemID) == "number"
			and SC.GetEntryStatus and SC:GetEntryStatus(entry) ~= "collected" then
			local name = SC.GetEntryName and SC:GetEntryName(entry) or entry.name
			if watch.requiresEquipped and not IsEquipped(watch.requiresEquipped) then
				local reqName = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(watch.requiresEquipped)
				Say(string.format(
					L["VENDOR_NEEDS_EQUIPPED"] or "Equip %s to see whether %s is stocked here.",
					reqName or ("item:" .. watch.requiresEquipped), name))
			elseif not onSale[entry.itemID] then
				Say(string.format(
					L["VENDOR_NOT_STOCKED"] or "%s is not stocked here today.", name))
			end
		end
	end
end

local vendorFrame = CreateFrame("Frame")
vendorFrame:RegisterEvent("MERCHANT_SHOW")
vendorFrame:SetScript("OnEvent", function(_, event)
	if event == "MERCHANT_SHOW" then
		ScanMerchant()
	end
end)
