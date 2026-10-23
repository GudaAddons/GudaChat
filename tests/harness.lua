-- Minimal WoW API stubs for the offline tests. Each H.Load() call builds a fresh addon
-- namespace from the real addon files, so tests can load the addon several times with
-- different clients (interface version), locales and player names.

local H = {}

H.ROOT = "."

-- A string the issecretvalue stub reports as secret. Real secret values cannot be read
-- at all; the filters must recognise this one before touching it.
H.SECRET = "<secret value>"

-- Files loaded for the tests, in TOC order. UI files and GudaChat.lua need a real client.
H.FILES = {
    "Locales.lua",
    "Core/Locales.lua",
    "Core/Theme.lua",
    "Core/Constants.lua",
    "Core/Emojis.lua",
    "Core/Filters.lua",
    "Core/Abbrev.lua",
    "Core/Logs.lua",
    "Core/WhisperModel.lua",
}

local function Noop() end

-- A frame whose every method is a no-op
local function NewFrame()
    return setmetatable({}, { __index = function() return Noop end })
end

local ENUS_LOOT = {
    LOOT_ITEM_SELF = "You receive loot: %s.",
    LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d.",
    LOOT_ITEM_PUSHED_SELF = "You receive item: %s.",
    LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d.",
    LOOT_ITEM_CREATED_SELF = "You create: %s.",
    LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %sx%d.",
    LOOT_ITEM = "%s receives loot: %s.",
    LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d.",
    LOOT_ITEM_PUSHED = "%s receives item: %s.",
    LOOT_ITEM_PUSHED_MULTIPLE = "%s receives item: %sx%d.",
}

-- Installs the global API the loaded files touch. opts:
--   interface  4th GetBuildInfo return (default 11509, Classic Era)
--   locale     GetLocale() (default "enUS")
--   name       first UnitName("player") value (default "Vati")
--   family     second UnitName("player") value (Forever family name)
local function InstallGlobals(opts)
    H.filters = {}
    H.sounds = 0

    _G.tinsert = table.insert
    _G.tremove = table.remove
    _G.wipe = function(t)
        for key in pairs(t) do t[key] = nil end
        return t
    end
    _G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    _G.time = os.time
    H.now = 1000
    _G.GetTime = function() return H.now end
    _G.CreateFrame = NewFrame
    _G.hooksecurefunc = Noop
    _G.C_Timer = { After = Noop, NewTicker = NewFrame }
    _G.GetBuildInfo = function() return "1.0.0", "1", "Oct 1 2026", opts.interface or 11509 end
    _G.GetLocale = function() return opts.locale or "enUS" end
    _G.GetRealmName = function() return "Realm" end
    _G.UnitName = function(unit)
        if unit == "player" then return opts.name or "Vati", opts.family end
        return nil
    end
    _G.UnitClass = function() return "Mage", "MAGE" end
    _G.UnitExists = function() return false end
    _G.UnitLevel = function() return 0 end
    _G.IsInGuild = function() return false end
    _G.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    _G.SOUNDKIT = { TELL_MESSAGE = 1 }
    _G.PlaySound = function() H.sounds = H.sounds + 1 end
    _G.issecretvalue = function(value) return value == H.SECRET end
    _G.ChatFrame_AddMessageEventFilter = function(event, fn)
        H.filters[event] = H.filters[event] or {}
        table.insert(H.filters[event], fn)
    end
    _G.NUM_CHAT_WINDOWS = 10
    _G.GetChannelList = function() return unpack(H.channels or {}) end
    for key, value in pairs(ENUS_LOOT) do
        _G[key] = value
    end
    _G.GudaChatDB = {
        copyLinks = true,
        emojis = true,
        emojiSize = 12,
        highlightName = true,
        highlightSound = true,
        showLevel = false,
    }
    _G.GudaChatCharDB = { lootLog = {}, addonLog = {} }
end

-- Loads the addon files into a new namespace and returns it
function H.Load(opts)
    opts = opts or {}
    InstallGlobals(opts)
    local ns = {}
    for _, file in ipairs(H.FILES) do
        local chunk = assert(loadfile(H.ROOT .. "/" .. file))
        chunk("GudaChat", ns)
    end
    return ns
end

-- The one chat filter that enable() registers for CHAT_MSG_SAY
function H.CaptureFilter(enable)
    H.filters = {}
    enable()
    local list = H.filters.CHAT_MSG_SAY
    assert(list and #list == 1, "expected one CHAT_MSG_SAY filter")
    return list[1]
end

-- Calls a chat filter like ChatFrame_MessageEventHandler does: arg1 message, arg2 sender,
-- arg11 lineID. Returns every value the filter returns.
function H.CallFilter(filter, msg, sender, lineID)
    return filter(nil, "CHAT_MSG_SAY", msg, sender, nil, nil, nil, nil, nil, nil, nil, nil, lineID)
end

-- Reads a file below the addon root, or nil
function H.ReadFile(path)
    local handle = io.open(H.ROOT .. "/" .. path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end

return H
