local addonName, ns = ...

---------------------------------------------------------------------------
-- Tab routing rules: which incoming messages auto-select a tab, and the message groups
-- GudaChat keeps on every tab. The event handling, tab selection and Blizzard chat
-- config writes are in UI/Tabs/AutoSelect.lua.
---------------------------------------------------------------------------

-- Chat types the player can pick for auto-select, in settings order
ns.AUTO_SELECT_KEYS = { "Guild", "Officer", "Party", "Raid", "Instance", "Whisper" }

-- No auto-select within this many seconds of the last tab switch, by the player or by
-- GudaChat, so a busy raid and a chatty guild cannot flip the window back and forth
ns.AUTO_SELECT_HOLD = 10

-- Incoming chat event -> settings key and the message group a window must show.
-- Numbered channels are picked per channel name instead of by a key.
local AUTO_SELECT_EVENTS = {
    CHAT_MSG_GUILD = { "Guild", "GUILD" },
    CHAT_MSG_OFFICER = { "Officer", "OFFICER" },
    CHAT_MSG_PARTY = { "Party", "PARTY" },
    CHAT_MSG_PARTY_LEADER = { "Party", "PARTY" },
    CHAT_MSG_RAID = { "Raid", "RAID" },
    CHAT_MSG_RAID_LEADER = { "Raid", "RAID" },
    CHAT_MSG_RAID_WARNING = { "Raid", "RAID_WARNING" },
    CHAT_MSG_INSTANCE_CHAT = { "Instance", "INSTANCE_CHAT" },
    CHAT_MSG_INSTANCE_CHAT_LEADER = { "Instance", "INSTANCE_CHAT" },
    CHAT_MSG_WHISPER = { "Whisper", "WHISPER" },
    CHAT_MSG_BN_WHISPER = { "Whisper", "BN_WHISPER" },
    CHAT_MSG_CHANNEL = { nil, "CHANNEL" },
}
ns.AUTO_SELECT_EVENTS = AUTO_SELECT_EVENTS

-- Saved form of a channel name: no zone part, lower case. "Trade - City" and "trade"
-- are the same channel.
local function ChannelKey(name)
    return ns.UTF8Lower(ns.BaseChannelName(name))
end
ns.ChannelKey = ChannelKey

-- Server channels (General, Trade, LocalDefense, LookingForGroup, ...), which are never
-- offered for auto-select. EnumerateServerChannels lists them in the client's language.
function ns.IsGlobalChannel(name)
    if not EnumerateServerChannels then return false end
    local key = ChannelKey(name)
    for _, server in ipairs({ EnumerateServerChannels() }) do
        if type(server) == "string" and ChannelKey(server) == key then return true end
    end
    return false
end

-- True when permanent window idx shows message group `group`. Temporary whisper windows
-- (ChatFrame11 and up) have no stored chat config and never match.
function ns.WindowHasGroup(idx, group)
    if not idx or idx > NUM_CHAT_WINDOWS then return false end
    for _, grp in ipairs({ GetChatWindowMessages(idx) }) do
        if grp == group then return true end
    end
    return false
end

-- True when permanent window idx shows the numbered channel saved as `key`.
-- GetChatWindowChannels returns name, zone pairs.
function ns.WindowHasChannel(idx, key)
    if not idx or idx > NUM_CHAT_WINDOWS then return false end
    local values = { GetChatWindowChannels(idx) }
    for i = 1, #values, 2 do
        if type(values[i]) == "string" and ChannelKey(values[i]) == key then return true end
    end
    return false
end

local function SavedTable(field)
    if type(GudaChatDB[field]) ~= "table" then GudaChatDB[field] = {} end
    return GudaChatDB[field]
end

function ns.GetAutoSelectType(key)
    return SavedTable("autoSelectTypes")[key] == true
end

function ns.SetAutoSelectType(key, on)
    SavedTable("autoSelectTypes")[key] = on or nil
end

function ns.GetAutoSelectChannel(name)
    return SavedTable("autoSelectChannels")[ChannelKey(name)] == true
end

function ns.SetAutoSelectChannel(name, on)
    SavedTable("autoSelectChannels")[ChannelKey(name)] = on or nil
end

-- The message group a window must show for this incoming message to auto-select it, or
-- nil when the player did not pick its chat type. channelName is arg9 of
-- CHAT_MSG_CHANNEL and may be a secret value.
function ns.AutoSelectGroup(event, channelName)
    if not GudaChatDB or not GudaChatDB.autoSelectTab then return nil end
    local rule = AUTO_SELECT_EVENTS[event]
    if not rule then return nil end
    if event == "CHAT_MSG_CHANNEL" then
        if type(channelName) ~= "string" or ns.IsSecret(channelName) or channelName == "" then return nil end
        if not ns.GetAutoSelectChannel(channelName) or ns.IsGlobalChannel(channelName) then return nil end
        return rule[2]
    end
    if not ns.GetAutoSelectType(rule[1]) then return nil end
    return rule[2]
end

local lastTabSwitch

function ns.NoteTabSwitch()
    lastTabSwitch = GetTime()
end

function ns.AutoSelectOnHold()
    return lastTabSwitch ~= nil and GetTime() - lastTabSwitch < ns.AUTO_SELECT_HOLD
end

---------------------------------------------------------------------------
-- Message groups shown on every tab
---------------------------------------------------------------------------

ns.SHARED_GROUPS = { "SYSTEM", "SKILL" }

-- The changes that put the shared groups on exactly the windows that want them.
-- windows[idx] = { eligible = bool, groups = { [group] = true } } for the permanent
-- windows; added[idx] = { [group] = true } records the groups GudaChat put there itself.
-- Returns { idx, group, add } entries; a removal with present = false only clears the
-- record (the player or Blizzard already took the group off). A group the window had on
-- its own is never recorded, so it is never removed.
function ns.PlanSharedGroups(windows, added, enabled)
    local changes = {}
    for idx = 1, NUM_CHAT_WINDOWS do
        local win = windows[idx]
        local mine = added[idx] or {}
        for _, group in ipairs(ns.SHARED_GROUPS) do
            local present = win ~= nil and win.groups[group] == true
            if enabled and win and win.eligible then
                if not present then
                    changes[#changes + 1] = { idx = idx, group = group, add = true }
                end
            elseif mine[group] then
                changes[#changes + 1] = { idx = idx, group = group, add = false, present = present }
            end
        end
    end
    return changes
end
