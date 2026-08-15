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

local function ScanMerchant()
	local watched = WatchedItems()
	local today   = ServerDateStamp()
	if not today then return end

	local db = SecretChecklistDB
	if type(db) ~= "table" then return end
	db.vendorSeen = db.vendorSeen or {}

	local numItems = GetMerchantNumItems and GetMerchantNumItems() or 0
	for i = 1, numItems do
		-- The link rather than an id getter: GetMerchantItemLink has been stable
		-- for as long as merchants have existed, and the id falls out of it.
		local link = GetMerchantItemLink and GetMerchantItemLink(i)
		local itemID = link and tonumber(link:match("item:(%d+)"))
		local entry = itemID and watched[itemID]
		if entry then
			local alreadySeenToday = (db.vendorSeen[itemID] == today)
			db.vendorSeen[itemID] = today
			-- Once per item per day. Opening the same vendor repeatedly while
			-- deciding what to buy should not repeat the message.
			if not alreadySeenToday and SC.GetEntryStatus and SC:GetEntryStatus(entry) ~= "collected" then
				DEFAULT_CHAT_FRAME:AddMessage(string.format(
					"|cffffcc00SecretChecklist:|r %s %s",
					link,
					L["VENDOR_AVAILABLE_NOW"] or "is for sale here right now."))
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
