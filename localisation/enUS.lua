-- English (US) - Default locale
local L = {}

-- General
L["ADDON_NAME"] = "Secret Checklist"
L["ADDON_LOADED"] = "Loaded. Type /secrets to open."

-- UI Elements
L["WINDOW_TITLE"] = "Secret Checklist"
L["PAGE_FORMAT"] = "Page %d / %d"
L["SECRETS"] = "Secrets"
L["MIND_SEEKER"] = "Mind-Seeker"

-- Filter
L["FILTER"] = "Filter"
L["FILTER_WITH_COUNT"] = "Filter (%d)"
L["FILTER_BY_STATUS"] = "Status"
L["FILTER_BY_TYPE"] = "Type"
L["FILTER_ALL"] = "All"
L["FILTER_COLLECTED"] = "Collected"
L["FILTER_MISSING"] = "Missing"
L["FILTER_NOT_COLLECTED"] = "Not Collected"
L["FILTER_SELECT_ALL"] = "Select All"
L["FILTER_DESELECT_ALL"] = "Deselect All"
L["FILTER_BY_TRACKER"] = "Filter by Tracker"
L["FILTER_MIND_SEEKER_ONLY"] = "Mind-Seeker only"
L["SORT_BY"] = "Sort by"
L["SORT_TYPE"] = "Type"
L["SORT_NAME"] = "Name"
L["SORT_STATUS"] = "Status"
L["SORT_STATUS_INC"] = "Incomplete first"
L["SORT_STATUS_COL"] = "Collected first"
-- Entry Types (singular)
L["KIND_TOY"] = "Toy"
L["KIND_MOUNT"] = "Mount"
L["KIND_PET"] = "Pet"
L["KIND_ACHIEVEMENT"] = "Achievement"
L["KIND_TRANSMOG"] = "Transmog"
L["KIND_QUEST"] = "Quest"
L["KIND_MANUAL"] = "Manual"
L["KIND_HOUSING"] = "Housing"
L["KIND_MYSTERY"] = "Mystery"

-- Entry Types (plural - for filter menu)
L["KIND_TOYS"] = "Toys"
L["KIND_MOUNTS"] = "Mounts"
L["KIND_PETS"] = "Pets"
L["KIND_ACHIEVEMENTS"] = "Achievements"
L["KIND_TRANSMOGS"] = "Transmog"
L["KIND_QUESTS"] = "Quests"
L["KIND_HOUSINGS"] = "Housing (Decor)"
L["KIND_MYSTERIES"] = "Mysteries"

-- Tooltips
L["TOOLTIP_CLICK_TOGGLE"] = "Click to toggle window"
L["TOOLTIP_DRAG_MOVE"] = "Drag to move"
L["TOOLTIP_COLLECTED"] = "Collected"
L["TOOLTIP_NOT_COLLECTED"] = "Not collected"
L["TOOLTIP_COMPLETED"] = "Completed"
L["TOOLTIP_NOT_COMPLETED"] = "Not completed"

-- Settings
L["SETTINGS_TITLE"] = "SecretChecklist"
L["SETTINGS_MINIMAP_BUTTON"] = "Show Minimap Button"
L["SETTINGS_MINIMAP_BUTTON_DESC"] = "Show or hide the SecretChecklist minimap button."
L["SETTINGS_ADDON_COMPARTMENT"] = "Show Addon Compartment Button"
L["SETTINGS_ADDON_COMPARTMENT_DESC"] = "Show or hide the SecretChecklist button in the minimap addon compartment."
L["SETTINGS_ALERTS"] = "Show Collection Alerts"
L["SETTINGS_ALERTS_DESC"] = "Show a toast notification when a tracked secret is newly collected."

-- Slash Commands
L["CMD_OPTIONS"] = "Opening settings..."
L["CMD_MINIMAP_SHOW"] = "Minimap button shown."
L["CMD_MINIMAP_HIDE"] = "Minimap button hidden."

-- Vendor watch
-- Shown after an item link: "<link> is for sale here right now."
L["VENDOR_AVAILABLE_NOW"] = "is for sale here right now."
-- %s is the item that must be worn, %s the secret it reveals.
L["VENDOR_NEEDS_EQUIPPED"] = "Equip %s to see whether %s is stocked here."
-- %s is the secret.
L["VENDOR_NOT_STOCKED"] = "%s is not stocked here today."

-- Status Messages
L["DATA_NOT_READY"] = "Collection data not ready yet. Try opening Collections once."
L["UNKNOWN"] = "(unknown)"
-- Guides panel
L["GUIDES_TAB_INFO"]        = "Info"
L["GUIDES_TAB_MODEL"]       = "Model"
L["GUIDES_GUIDE_BUTTON"]    = "Guide"
L["GUIDES_CLICK_COPY"]      = "Click to copy link"
L["GUIDES_NO_GUIDE_LINK"]   = "No guide link yet"
L["GUIDES_CLICK_VIEW"]      = "Click to view"
L["GUIDES_REQUIRES"]        = "Requires:"
L["GUIDES_REQUIRED_FOR"]    = "Required for:"
-- %s is the name of the secret this one belongs to.
L["GUIDES_PART_OF"]         = "Part of: %s"
-- %d done, %d total.
L["GUIDES_PROGRESS"]        = "Progress  %d / %d  steps"
-- %d collected, %d required.
L["GUIDES_MINDSEEKER_REQ"]  = "(%d / %d secrets)"
-- %d current standing, %s required standing.
L["GUIDES_RANK_REQ"]        = "(Rank %d / %s)"
L["GUIDES_SET_WAYPOINT"]    = "Set Waypoint"
L["GUIDES_SET_ALL_WAYPOINTS"] = "Set All Waypoints"
L["GUIDES_WAYPOINT_UNSUPPORTED"] = "Blizzard's waypoint system does not support that location. Install TomTom for waypoints there."
-- %d is how many waypoints the step has.
L["GUIDES_WAYPOINT_PARTIAL"] = "Set the first of %d waypoints. Install TomTom to place them all at once."

-- Copy dialog
L["COPY_HINT"]            = "Ctrl+C to copy  ·  Esc to close"

-- Collection toast
L["ALERT_TITLE"]          = "Secret Collected!"
L["ALERT_CLICK_VIEW"]     = "Click to view guide"

-- Tabs
L["TAB_OVERVIEW"]         = "Overview"
L["TAB_GUIDES"]           = "Guides"
-- About tab
L["TAB_ABOUT"]            = "About"
L["ABOUT_BY"] = "By Calaglyn"
L["ABOUT_DESC"] = "Track secret collectibles in World of Warcraft.\nMounts, Pets, Toys, Achievements, Quests, and Transmog."
L["ABOUT_THANKS_HEADER"] = "Special Thanks"
L["ABOUT_THANKS_TEXT"] = "A huge thank you to the Secret Finding Discord community\nfor all the incredible work they put into discovering\nthese secrets and documenting how to obtain them."
L["ABOUT_DISCORD_LABEL"] = "Secret Finding Discord"
-- Theme
L["SETTINGS_THEME"]      = "Theme"
L["SETTINGS_THEME_DESC"] = "Select a visual theme for SecretChecklist."
-- Names and descriptions of the individual themes in that dropdown. "ElvUI"
-- and "EllesmereUI" are addon names and are deliberately not translated.
L["THEME_DEFAULT"]              = "Default"
L["THEME_DEFAULT_DESC"]         = "The classic SecretChecklist dark-amber look."
L["THEME_ELVUI_DESC"]           = "A flat dark theme matching ElvUI's aesthetic. Requires ElvUI."
L["THEME_ELLESMEREUI_DESC"]     = "Matches your EllesmereUI profile — window style, accent colour and UI font. Requires EllesmereUI."

-- Guides tab style
L["SETTINGS_GUIDES_STYLE"]      = "Guides tab style"
L["SETTINGS_GUIDES_STYLE_DESC"] = "Choose how the Info and Model tabs are shown in the Guides panel."
L["GUIDES_STYLE_SIDETABS"]      = "Default"
L["GUIDES_STYLE_SIDETABS_DESC"] = "SpellBook-style side tabs on the right edge of the detail pane."
L["GUIDES_STYLE_HORIZONTAL"]      = "Modern"
L["GUIDES_STYLE_HORIZONTAL_DESC"] = "Classic horizontal Info / Model tab bar inside the detail pane."
-- Minimap button
L["TOOLTIP_RIGHT_CLICK_OPTIONS"] = "Right-click to open options"
-- Publish unconditionally: enUS is the base layer that every other locale file
-- overlays (each does `local L = _G.SecretChecklistLocale or {}` and then adds
-- its own strings). Previously this only published on an English client, so a
-- deDE or ruRU client started from an empty table and every key that locale had
-- not translated fell through to a hardcoded English literal at the call site.
--
-- No __index metatable here on purpose: call sites are written as
-- `L["KEY"] or "English"`, so a key must still resolve to nil when absent for
-- that fallback to fire.
_G.SecretChecklistLocale = L

return L
