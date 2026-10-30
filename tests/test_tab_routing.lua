-- Tab routing: which incoming messages auto-select a tab, the hold time, and the plan
-- that keeps System and Skill on every tab

local function Window(eligible, ...)
    local groups = {}
    for _, group in ipairs({ ... }) do groups[group] = true end
    return { eligible = eligible, groups = groups }
end

local function Describe(changes)
    local parts = {}
    for _, c in ipairs(changes) do
        parts[#parts + 1] = string.format("%s%d:%s%s", c.add and "+" or "-", c.idx, c.group,
            (not c.add and not c.present) and "(forget)" or "")
    end
    return table.concat(parts, " ")
end

return function(T, H)
    local ns = H.Load()
    _G.EnumerateServerChannels = function() return "General", "Trade", "LocalDefense", "LookingForGroup" end

    T.case("nothing auto-selects while the master switch is off", function()
        GudaChatDB.autoSelectTab = false
        ns.SetAutoSelectType("Guild", true)
        T.eq(ns.AutoSelectGroup("CHAT_MSG_GUILD"), nil, "guild")
    end)

    T.case("only checked chat types auto-select, each with its window group", function()
        GudaChatDB.autoSelectTab = true
        GudaChatDB.autoSelectTypes = { Guild = true, Raid = true }
        T.eq(ns.AutoSelectGroup("CHAT_MSG_GUILD"), "GUILD", "guild")
        T.eq(ns.AutoSelectGroup("CHAT_MSG_RAID_LEADER"), "RAID", "raid leader")
        T.eq(ns.AutoSelectGroup("CHAT_MSG_RAID_WARNING"), "RAID_WARNING", "raid warning")
        T.eq(ns.AutoSelectGroup("CHAT_MSG_PARTY"), nil, "party unchecked")
        T.eq(ns.AutoSelectGroup("CHAT_MSG_SAY"), nil, "say is never offered")
    end)

    T.case("custom channels are matched by name without the zone part, any case", function()
        GudaChatDB.autoSelectTab = true
        GudaChatDB.autoSelectChannels = {}
        ns.SetAutoSelectChannel("MyGuildAlts", true)
        T.eq(ns.AutoSelectGroup("CHAT_MSG_CHANNEL", "myguildalts"), "CHANNEL", "lower case")
        T.eq(ns.AutoSelectGroup("CHAT_MSG_CHANNEL", "Other"), nil, "unchecked channel")
        T.eq(ns.AutoSelectGroup("CHAT_MSG_CHANNEL", H.SECRET), nil, "secret name")
        T.eq(ns.AutoSelectGroup("CHAT_MSG_CHANNEL", nil), nil, "no name")
    end)

    T.case("server channels never auto-select, even with a saved setting", function()
        GudaChatDB.autoSelectTab = true
        GudaChatDB.autoSelectChannels = { trade = true }
        T.ok(ns.IsGlobalChannel("Trade - City"), "Trade is a server channel")
        T.ok(not ns.IsGlobalChannel("MyGuildAlts"), "custom channel")
        T.eq(ns.AutoSelectGroup("CHAT_MSG_CHANNEL", "Trade"), nil, "trade")
    end)

    T.case("a switch holds auto-select for the hold time", function()
        T.ok(not ns.AutoSelectOnHold(), "no switch yet")
        H.now = 1000
        ns.NoteTabSwitch()
        H.now = 1000 + ns.AUTO_SELECT_HOLD - 1
        T.ok(ns.AutoSelectOnHold(), "inside the hold")
        H.now = 1000 + ns.AUTO_SELECT_HOLD
        T.ok(not ns.AutoSelectOnHold(), "hold over")
    end)

    T.case("shared groups are added where missing and recorded nowhere else", function()
        local windows = {
            [1] = Window(true, "SAY", "SYSTEM"),
            [2] = Window(false),
            [3] = Window(true, "GUILD"),
        }
        T.eq(Describe(ns.PlanSharedGroups(windows, {}, true)), "+1:SKILL +3:SYSTEM +3:SKILL", "plan")
    end)

    T.case("turning off removes only what GudaChat added", function()
        local windows = {
            [1] = Window(true, "SYSTEM", "SKILL"),
            [3] = Window(true, "SYSTEM", "SKILL"),
        }
        local added = { [1] = { SKILL = true }, [3] = { SYSTEM = true, SKILL = true } }
        T.eq(Describe(ns.PlanSharedGroups(windows, added, false)), "-1:SKILL -3:SYSTEM -3:SKILL", "plan")
    end)

    T.case("windows that stop qualifying lose GudaChat's groups; gone groups are forgotten", function()
        local windows = {
            [3] = Window(false, "SYSTEM"),
            [4] = Window(true),
        }
        local added = { [3] = { SYSTEM = true, SKILL = true }, [4] = { SYSTEM = true } }
        T.eq(Describe(ns.PlanSharedGroups(windows, added, true)),
            "-3:SYSTEM -3:SKILL(forget) +4:SYSTEM +4:SKILL", "plan")
    end)

    T.case("nothing changes when every tab already has the groups", function()
        local windows = { [1] = Window(true, "SYSTEM", "SKILL"), [3] = Window(true, "SYSTEM", "SKILL") }
        T.eq(#ns.PlanSharedGroups(windows, { [3] = { SYSTEM = true } }, true), 0, "changes")
    end)
end
