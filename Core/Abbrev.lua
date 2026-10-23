local addonName, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Channel abbreviations
--
-- "[2. Trade - City]" becomes "[2. T]", "[4. LookingForGroup]" becomes "[4. LFG]".
-- A channel's short name is the user's own (Settings > Messages) or else the first
-- letter of each word. Guild, Officer, Party, Raid and Instance get a short label from
-- the locale table, used in the History window and the header chat type menu only:
-- live chat builds their "[Guild]" from Blizzard's CHAT_GUILD_GET-style globals, read
-- per message by the secure chat handler, and writing those would taint every line.
---------------------------------------------------------------------------

ns.ABBREV_MAX_LEN = 8

-- The fixed chat types that get a short label, in Settings order. History and the
-- chat type menu use these same keys.
ns.ABBREV_FIXED_KEYS = { "Guild", "Officer", "Party", "Raid", "Instance" }

-- Custom values for fixed types are stored under this prefix, so they can never clash
-- with a channel name in the same table
local FIXED_PREFIX = "@"

-- One UTF-8 character: a lead byte and its continuation bytes
local UTF8_CHAR = "[\1-\127\194-\244][\128-\191]*"

local function TruncateUTF8(text, maxChars)
    local out, count = {}, 0
    for ch in text:gmatch(UTF8_CHAR) do
        count = count + 1
        if count > maxChars then break end
        out[count] = ch
    end
    return table.concat(out)
end

-- "Trade - City" -> "Trade". Zone channels carry the zone after " - "; a dash with no
-- spaces around it ("looking-for-group") is part of the name.
local function BaseChannelName(name)
    return (name:gsub("%s+%-%s+.*$", ""))
end
ns.BaseChannelName = BaseChannelName

local function IsSeparator(ch)
    return ch == " " or ch == "-" or ch == "_" or ch == "\t"
end

-- The first letter of every word, case kept. Words split at spaces, "-" and "_", and
-- where a capital follows a small letter (PascalCase). A run of capitals is kept whole,
-- so a name that is already short ("LFG", "OOC") stays as it is.
function ns.AutoAbbrev(name)
    if type(name) ~= "string" then return "" end
    name = BaseChannelName(name)
    local out = {}
    local prev, prevKept
    for ch in name:gmatch(UTF8_CHAR) do
        local kept = false
        if not IsSeparator(ch) then
            if prev == nil or IsSeparator(prev) then
                kept = true
            elseif ch:match("^%u$") then
                kept = prev:match("^%l$") ~= nil or (prevKept and prev:match("^%u$") ~= nil)
            end
            if kept then out[#out + 1] = ch end
        end
        prev, prevKept = ch, kept
    end
    return TruncateUTF8(table.concat(out), ns.ABBREV_MAX_LEN)
end

-- What the user typed, made safe: brackets would break the "[...]" prefix and "|" starts
-- an escape sequence. Returns nil for an empty result (meaning "use the automatic one").
function ns.SanitizeAbbrev(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("[%[%]|%s]", "")
    if text == "" then return nil end
    return TruncateUTF8(text, ns.ABBREV_MAX_LEN)
end

local function CustomTable()
    if not GudaChatDB then return nil end
    if type(GudaChatDB.channelAbbrev) ~= "table" then GudaChatDB.channelAbbrev = {} end
    return GudaChatDB.channelAbbrev
end

function ns.GetCustomAbbrev(name)
    local custom = CustomTable()
    return custom and custom[BaseChannelName(name)] or nil
end

function ns.SetCustomAbbrev(name, text)
    local custom = CustomTable()
    if custom then custom[BaseChannelName(name)] = ns.SanitizeAbbrev(text) end
end

function ns.GetCustomFixedAbbrev(key)
    local custom = CustomTable()
    return custom and custom[FIXED_PREFIX .. key] or nil
end

function ns.SetCustomFixedAbbrev(key, text)
    local custom = CustomTable()
    if custom then custom[FIXED_PREFIX .. key] = ns.SanitizeAbbrev(text) end
end

-- Channel names that have a custom value, for the Settings list (fixed keys left out)
function ns.CustomAbbrevChannels()
    local names = {}
    for key in pairs(CustomTable() or {}) do
        if key:sub(1, #FIXED_PREFIX) ~= FIXED_PREFIX then names[#names + 1] = key end
    end
    table.sort(names)
    return names
end

function ns.ChannelAbbrev(name)
    return ns.GetCustomAbbrev(name) or ns.AutoAbbrev(name)
end

function ns.DefaultFixedAbbrev(key)
    return L["ABBR_" .. key:upper()] or key
end

function ns.FixedAbbrev(key)
    return ns.GetCustomFixedAbbrev(key) or ns.DefaultFixedAbbrev(key)
end

-- Joined numbered channels as { num, name }, sorted by number. GetChannelList returns
-- id, name, disabled triplets; very old clients returned id, name pairs. Community
-- channels are left out, they are never shortened.
function ns.JoinedChannels()
    local list = {}
    if not GetChannelList then return list end
    local values = { GetChannelList() }
    local i = 1
    while i <= #values do
        local num, name = values[i], values[i + 1]
        if type(num) == "number" and type(name) == "string" then
            if not name:find("^Community:") then
                list[#list + 1] = { num = num, name = name }
            end
            i = i + (type(values[i + 2]) == "boolean" and 3 or 2)
        else
            i = i + 1
        end
    end
    table.sort(list, function(a, b) return a.num < b.num end)
    return list
end

-- What the header and tab strip show for a chat window named `name`: its short name
-- while header abbreviations are on. Temporary whisper windows are named after a
-- person and are never shortened (the callers pass them through as they are).
function ns.TabLabel(name)
    if type(name) ~= "string" or name == "" or not ns.AbbrevActive("header") then return name end
    local short = ns.ChannelAbbrev(name)
    if short == "" then return name end
    return short
end

-- where: "chat" or "header"
function ns.AbbrevActive(where)
    if not GudaChatDB or not GudaChatDB.abbrevChannels then return false end
    if where == "header" then return GudaChatDB.abbrevInHeader ~= false end
    return GudaChatDB.abbrevInChat ~= false
end

---------------------------------------------------------------------------
-- Chat filter
--
-- Blizzard builds the prefix from the filtered arg4 ("2. Trade - City"), but first
-- checks that arg4 is longer than the channel's name and drops the message from the
-- frame when it is not. "|r" codes draw nothing, so the short form is padded with them
-- up to the original length, which passed that same check.
---------------------------------------------------------------------------

-- Community channels ("Community:1234:1") are resolved to the club's name by Blizzard;
-- shortening the raw id would only produce noise
local function IsCommunityChannel(name)
    return name:find("^Community:") ~= nil
end

-- "2. Trade - City" -> "2. T" padded to at least the original length, or nil when the
-- channel string is not one we can shorten. Blizzard's own prefix match is "(%d+. )".
function ns.AbbreviateChannelArg(channelString)
    if type(channelString) ~= "string" then return nil end
    local prefix, name = channelString:match("^(%d+. )(.+)$")
    if not prefix or IsCommunityChannel(name) then return nil end
    local short = ns.ChannelAbbrev(name)
    if short == "" then return nil end
    local out = prefix .. short
    while #out <= #channelString do
        out = out .. "|r"
    end
    return out
end

local function FilterAbbrevChannel(self, event, msg, sender, language, channelString, ...)
    if not ns.AbbrevActive("chat") then return false end
    if ns.IsSecret(msg) or ns.IsSecret(channelString) then return false end
    local short = ns.AbbreviateChannelArg(channelString)
    if not short then return false end
    return false, msg, sender, language, short, ...
end

---------------------------------------------------------------------------
-- Full name on hover
---------------------------------------------------------------------------

local tooltipShown = false

local function OnHyperlinkEnter(frame, link)
    if not ns.AbbrevActive("chat") or type(link) ~= "string" or ns.IsSecret(link) then return end
    local num = tonumber(link:match("^channel:channel:(%d+)"))
    if not num or not GetChannelName then return end
    local _, name = GetChannelName(num)
    if type(name) ~= "string" or name == "" then return end
    GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
    GameTooltip:SetText(num .. ". " .. name, 1, 1, 1)
    GameTooltip:Show()
    tooltipShown = true
end

local function OnHyperlinkLeave()
    if tooltipShown then
        tooltipShown = false
        GameTooltip:Hide()
    end
end

function ns.EnableChannelAbbrev()
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", FilterAbbrevChannel)

    -- Every client fires these through EventRegistry from the chat frame mixin, which
    -- also covers windows opened later. Fall back to per-frame hooks without it.
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkEnter", function(_, frame, link)
            OnHyperlinkEnter(frame, link)
        end, ns)
        EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkLeave", OnHyperlinkLeave, ns)
    else
        ns.ForEachChatWindow(function(cf)
            cf:HookScript("OnHyperlinkEnter", OnHyperlinkEnter)
            cf:HookScript("OnHyperlinkLeave", OnHyperlinkLeave)
        end)
    end
end
