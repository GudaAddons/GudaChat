-- Channel abbreviations: the automatic rule, what users may type, and the chat filter
-- that shortens the channel prefix without making Blizzard drop the message

-- Blizzard drops a channel message from a frame unless the filtered channel string is
-- longer than the channel's name, then builds the prefix with "(%d+. )(.*)"
local function BlizzardKeeps(channelString, channelName)
    return #channelString > #channelName
end

local function Visible(text)
    return (text:gsub("|r", ""))
end

local function CaptureChannelFilter(H, ns)
    H.filters = {}
    ns.EnableChannelAbbrev()
    local list = H.filters.CHAT_MSG_CHANNEL
    assert(list and #list == 1, "expected one CHAT_MSG_CHANNEL filter")
    return list[1]
end

local function CallChannelFilter(filter, msg, channelString)
    return filter(nil, "CHAT_MSG_CHANNEL", msg, "Bob", "", channelString,
        "", "", 2, 2, "Trade", nil, 7, "guid", nil, nil)
end

return function(T, H)
    local ns = H.Load()

    T.case("PascalCase, kebab, snake and spaces give word initials", function()
        T.eq(ns.AutoAbbrev("LookingForGroup"), "LFG", "PascalCase")
        T.eq(ns.AutoAbbrev("looking-for-group"), "lfg", "kebab")
        T.eq(ns.AutoAbbrev("my_guild_alts"), "mga", "snake")
        T.eq(ns.AutoAbbrev("World Defense"), "WD", "spaces")
        T.eq(ns.AutoAbbrev("LocalDefense"), "LD", "two words")
    end)

    T.case("the zone part is dropped", function()
        T.eq(ns.AutoAbbrev("Trade - City"), "T", "Trade - City")
        T.eq(ns.AutoAbbrev("General - Stormwind City"), "G", "General")
    end)

    T.case("a name that is already short stays whole", function()
        T.eq(ns.AutoAbbrev("LFG"), "LFG", "all capitals")
        T.eq(ns.AutoAbbrev("Trade"), "T", "one word")
    end)

    T.case("non-Latin names keep their first whole character", function()
        T.eq(ns.AutoAbbrev("Торговля - Город"), "Т", "Cyrillic")
        T.eq(ns.AutoAbbrev("交易"), "交", "CJK")
    end)

    T.case("typed abbreviations lose brackets, pipes and spaces and are capped", function()
        T.eq(ns.SanitizeAbbrev("[L F|G]"), "LFG", "stripped")
        T.eq(ns.SanitizeAbbrev("ABCDEFGHIJK"), "ABCDEFGH", "8 characters")
        T.eq(ns.SanitizeAbbrev("ТорговляГород"), "Торговля", "8 UTF-8 characters")
        T.eq(ns.SanitizeAbbrev("  "), nil, "empty means automatic")
    end)

    T.case("a custom value replaces the automatic one, for every zone", function()
        ns.SetCustomAbbrev("LookingForGroup", "GRP")
        T.eq(ns.ChannelAbbrev("LookingForGroup"), "GRP", "custom")
        ns.SetCustomAbbrev("Trade - City", "TR")
        T.eq(ns.ChannelAbbrev("Trade - Stormwind"), "TR", "stored by base name")
        ns.SetCustomAbbrev("LookingForGroup", "")
        T.eq(ns.ChannelAbbrev("LookingForGroup"), "LFG", "cleared")
        wipe(GudaChatDB.channelAbbrev)
    end)

    T.case("fixed chat types use the locale label unless set", function()
        T.eq(ns.FixedAbbrev("Guild"), "G", "default")
        ns.SetCustomFixedAbbrev("Guild", "GLD")
        T.eq(ns.FixedAbbrev("Guild"), "GLD", "custom")
        T.eq(#ns.CustomAbbrevChannels(), 0, "fixed values are not listed as channels")
        wipe(GudaChatDB.channelAbbrev)
    end)

    T.case("the shortened channel string still passes Blizzard's checks", function()
        for _, original in ipairs({ "2. Trade - City", "4. LookingForGroup", "1. General - Stormwind City", "12. X" }) do
            local out = ns.AbbreviateChannelArg(original)
            local name = original:match("^%d+. (.+)$")
            T.ok(BlizzardKeeps(out, name), original .. " is long enough")
            T.ok(out:match("(%d+. )(.*)") ~= nil, original .. " keeps the number prefix")
        end
        T.eq(Visible(ns.AbbreviateChannelArg("4. LookingForGroup")), "4. LFG", "draws as the short form")
    end)

    T.case("community channels are left alone", function()
        T.eq(ns.AbbreviateChannelArg("5. Community:1234:1"), nil, "community")
        T.eq(ns.AbbreviateChannelArg("Trade"), nil, "no number")
    end)

    T.case("the filter does nothing while abbreviations are off", function()
        GudaChatDB.abbrevChannels = false
        local filter = CaptureChannelFilter(H, ns)
        local hidden, msg = CallChannelFilter(filter, "hi", "2. Trade - City")
        T.eq(hidden, false, "never hides")
        T.eq(msg, nil, "unchanged")
    end)

    T.case("the filter shortens the channel and passes every other argument through", function()
        GudaChatDB.abbrevChannels = true
        local filter = CaptureChannelFilter(H, ns)
        local out = { CallChannelFilter(filter, "hi", "2. Trade - City") }
        T.eq(out[1], false, "never hides")
        T.eq(out[2], "hi", "message")
        T.eq(out[3], "Bob", "sender")
        T.eq(Visible(out[5]), "2. T", "channel string")
        T.eq(out[10], "Trade", "channel base name")
        T.eq(out[12], 7, "line ID")
        T.eq(select("#", CallChannelFilter(filter, "hi", "2. Trade - City")), 15, "all fourteen arguments")
        GudaChatDB.abbrevChannels = false
    end)

    T.case("the 'In chat' switch turns the filter off on its own", function()
        GudaChatDB.abbrevChannels = true
        GudaChatDB.abbrevInChat = false
        local filter = CaptureChannelFilter(H, ns)
        local _, msg = CallChannelFilter(filter, "hi", "2. Trade - City")
        T.eq(msg, nil, "unchanged")
        T.eq(ns.AbbrevActive("header"), true, "header still on")
        GudaChatDB.abbrevChannels, GudaChatDB.abbrevInChat = false, nil
    end)

    T.case("secret arguments are never touched", function()
        GudaChatDB.abbrevChannels = true
        local filter = CaptureChannelFilter(H, ns)
        local _, msg = CallChannelFilter(filter, "hi", H.SECRET)
        T.eq(msg, nil, "secret channel string")
        _, msg = CallChannelFilter(filter, H.SECRET, "2. Trade - City")
        T.eq(msg, nil, "secret message")
        GudaChatDB.abbrevChannels = false
    end)

    T.case("tab names are shortened only while header abbreviations are on", function()
        GudaChatDB.abbrevChannels = false
        T.eq(ns.TabLabel("LookingForGroup"), "LookingForGroup", "off")
        GudaChatDB.abbrevChannels = true
        T.eq(ns.TabLabel("LookingForGroup"), "LFG", "on")
        T.eq(ns.TabLabel("General"), "G", "every window name")
        ns.SetCustomAbbrev("General", "Gen")
        T.eq(ns.TabLabel("General"), "Gen", "custom")
        GudaChatDB.abbrevInHeader = false
        T.eq(ns.TabLabel("LookingForGroup"), "LookingForGroup", "header switch off")
        GudaChatDB.abbrevChannels, GudaChatDB.abbrevInHeader = false, nil
        wipe(GudaChatDB.channelAbbrev)
    end)

    T.case("joined channels are read from triplets, sorted, without communities", function()
        H.channels = { 4, "LookingForGroup", false, 2, "Trade", false, 5, "Community:1:1", false, 1, "General", true }
        local list = ns.JoinedChannels()
        T.eq(#list, 3, "count")
        T.eq(list[1].num, 1, "sorted")
        T.eq(list[3].name, "LookingForGroup", "last")
        H.channels = { 2, "Trade", 1, "General" }
        T.eq(#ns.JoinedChannels(), 2, "old pair format")
        H.channels = nil
    end)
end
