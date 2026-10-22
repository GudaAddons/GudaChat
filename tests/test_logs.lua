-- Loot line parsing and the ring buffer behind the loot and addon logs

local ITEM = "|cff1eff00|Hitem:1234::::::::60:::::|h[Sword]|h|r"

local function Collect(ns, list)
    local values = {}
    ns.ForEachLogEntry(list, function(entry) values[#values + 1] = entry end)
    return table.concat(values, ",")
end

return function(T, H)
    local ns = H.Load()

    T.case("own loot", function()
        local isSelf, count = ns.ParseLootLine("You receive loot: " .. ITEM .. ".")
        T.eq(isSelf, true, "isSelf")
        T.eq(count, 1, "count")
    end)

    T.case("own loot with a quantity", function()
        local isSelf, count = ns.ParseLootLine("You receive loot: " .. ITEM .. "x3.")
        T.eq(isSelf, true, "isSelf")
        T.eq(count, 3, "count")
    end)

    T.case("other players' loot", function()
        local isSelf, count = ns.ParseLootLine("Vieta receives loot: " .. ITEM .. ".")
        T.eq(isSelf, false, "isSelf")
        T.eq(count, 1, "count")
        local _, many = ns.ParseLootLine("Vieta receives loot: " .. ITEM .. "x2.")
        T.eq(many, 2, "count")
    end)

    T.case("roll lines are not loot", function()
        T.eq(ns.ParseLootLine("Need Roll - 54 for " .. ITEM .. " by Vieta"), nil, "roll")
        T.eq(ns.ParseLootLine("Vieta has selected Need for: " .. ITEM), nil, "selected")
        T.eq(ns.ParseLootLine("Vieta won: " .. ITEM), nil, "won")
    end)

    T.case("the ring buffer keeps the newest entries in order", function()
        local list = {}
        for i = 1, 5 do ns.PushLog(list, 3, i) end
        T.eq(#list, 3, "size")
        T.eq(Collect(ns, list), "3,4,5", "order")
        ns.PushLog(list, 3, 6)
        T.eq(Collect(ns, list), "4,5,6", "after one more")
    end)

    T.case("arrays saved without a head field still work", function()
        local list = { 1, 2, 3, 4, 5 }
        T.eq(Collect(ns, list), "1,2,3,4,5", "read as head 1")
        ns.PushLog(list, 3, 6)
        T.eq(Collect(ns, list), "4,5,6", "trimmed to the cap on push")
    end)

    T.case("a log can grow again after its cap is raised", function()
        local list = {}
        for i = 1, 5 do ns.PushLog(list, 3, i) end
        ns.PushLog(list, 5, 6)
        T.eq(Collect(ns, list), "3,4,5,6", "grows in order")
    end)

    T.case("TrimLog lowers the cap", function()
        local list = {}
        for i = 1, 6 do ns.PushLog(list, 4, i) end
        ns.TrimLog(list, 2)
        T.eq(#list, 2, "size")
        T.eq(Collect(ns, list), "5,6", "newest kept")
    end)
end
