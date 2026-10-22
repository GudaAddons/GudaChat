-- Chat message filters: copyable links, name highlight, secret messages and the
-- per-message memo that saves repeated work for each chat frame.

local ITEM_LINK = "|cff1eff00|Hitem:1234::::::::60:::::|h[www.example.com Sword]|h|r"

return function(T, H)
    local ns = H.Load()
    local links = H.CaptureFilter(ns.EnableCopyLinks)

    T.case("a plain URL becomes a copy link", function()
        local hidden, msg = H.CallFilter(links, "see https://example.com/page now", "Bob", 1)
        T.eq(hidden, false, "never hides the message")
        T.contains(msg, "|Hgudachat:url:https://example.com/page|h", "link")
        T.contains(msg, "see ", "text before")
        T.contains(msg, " now", "text after")
    end)

    T.case("a URL inside an item link is left alone", function()
        local hidden, msg = H.CallFilter(links, "buy " .. ITEM_LINK, "Bob", 2)
        T.eq(hidden, false)
        T.eq(msg, nil, "message unchanged")
    end)

    T.case("text that already holds our link is skipped", function()
        local linked = "|cff33bbff|Hgudachat:url:www.a.com|h[www.a.com]|h|r"
        local _, msg = H.CallFilter(links, linked .. " www.b.com", "Bob", 3)
        T.eq(msg, nil, "message unchanged")
    end)

    T.case("the filter passes every other argument through", function()
        local results = { H.CallFilter(links, "www.example.com", "Bob", 4) }
        T.eq(results[3], "Bob", "sender")
        T.eq(results[12], 4, "lineID")
    end)

    T.case("secret messages are skipped without errors", function()
        local results = { pcall(H.CallFilter, links, H.SECRET, "Bob", 5) }
        T.ok(results[1], "no error: " .. tostring(results[2]))
        T.eq(results[2], false, "returns false")
        T.eq(results[3], nil, "no new message")
    end)

    T.case("a message shown in several chat frames is processed once", function()
        local realSplit = ns.SplitProtected
        local calls = 0
        ns.SplitProtected = function(msg)
            calls = calls + 1
            return realSplit(msg)
        end
        local _, first = H.CallFilter(links, "go to www.example.com", "Bob", 10)
        local _, second = H.CallFilter(links, "go to www.example.com", "Bob", 10)
        T.eq(calls, 1, "work done once for one lineID")
        T.eq(second, first, "same result")
        H.CallFilter(links, "other www.example.org", "Bob", 10)
        T.eq(calls, 2, "a different text with the same lineID is processed again")
        H.CallFilter(links, "go to www.example.com", "Bob", nil)
        H.CallFilter(links, "go to www.example.com", "Bob", nil)
        T.eq(calls, 4, "no lineID means no memo")
        ns.SplitProtected = realSplit
    end)

    T.case("the player's name is highlighted as a whole word", function()
        local highlight = H.CaptureFilter(ns.EnableNameHighlight)
        local _, msg = H.CallFilter(highlight, "hey vati, look", "Bob", 20)
        T.contains(msg, "vati|r", "highlighted")
        T.contains(msg, "|cff", "class colour")
        local _, none = H.CallFilter(highlight, "Vatiman is here", "Bob", 21)
        T.eq(none, nil, "no highlight inside another word")
    end)

    T.case("the mention sound plays once per message and not for own messages", function()
        local highlight = H.CaptureFilter(ns.EnableNameHighlight)
        local before = H.sounds
        H.now = H.now + 10
        H.CallFilter(highlight, "hi Vati", "Bob", 30)
        H.CallFilter(highlight, "hi Vati", "Bob", 30)
        T.eq(H.sounds - before, 1, "one sound for one message in two frames")
        H.now = H.now + 10
        H.CallFilter(highlight, "I am Vati", "Vati-Realm", 31)
        T.eq(H.sounds - before, 1, "no sound for own message")
    end)

    T.case("a non-ASCII name is highlighted", function()
        local ru = H.Load({ locale = "ruRU", name = "Вати" })
        local highlight = H.CaptureFilter(ru.EnableNameHighlight)
        local _, msg = H.CallFilter(highlight, "привет Вати!", "Боб", 40)
        T.contains(msg, "Вати|r", "highlighted")
    end)

    T.case("the highlight and level filters skip secret messages", function()
        local highlight = H.CaptureFilter(ns.EnableNameHighlight)
        local ok, hidden = pcall(H.CallFilter, highlight, H.SECRET, "Bob", 50)
        T.ok(ok, "highlight: no error")
        T.eq(hidden, false)
        GudaChatDB.showLevel = true
        local level = H.CaptureFilter(ns.EnableLevelDisplay)
        local okLevel, hiddenLevel, msg = pcall(H.CallFilter, level, H.SECRET, H.SECRET, 51)
        T.ok(okLevel, "level: no error")
        T.eq(hiddenLevel, false)
        T.eq(msg, nil)
        GudaChatDB.showLevel = false
    end)
end
