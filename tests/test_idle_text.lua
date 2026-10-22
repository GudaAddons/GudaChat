-- "Hide text when chat is not in use": when chat text is shown (option off, hover,
-- typing, an open emoji picker or settings window, a recent message) and when it hides

local function State(fields)
    local state = { enabled = true, hovered = false, inputFocused = false, overlayOpen = false, now = 100 }
    for key, value in pairs(fields or {}) do state[key] = value end
    return state
end

return function(T, H)
    local ns = H.Load()

    T.case("with the option off the text always shows", function()
        T.eq(ns.ShouldShowChatText(State({ enabled = false })), true)
    end)

    T.case("idle chat hides its text", function()
        T.eq(ns.ShouldShowChatText(State()), false, "no message yet")
        T.eq(ns.ShouldShowChatText(State({ lastMessageAt = 50 })), false, "old message")
    end)

    T.case("hover, typing and open overlays show the text", function()
        T.eq(ns.ShouldShowChatText(State({ hovered = true })), true, "hovered")
        T.eq(ns.ShouldShowChatText(State({ inputFocused = true })), true, "typing")
        T.eq(ns.ShouldShowChatText(State({ overlayOpen = true })), true, "menu or settings open")
    end)

    T.case("a new message shows the text for a while", function()
        local seconds = ns.IDLE_TEXT_SHOW_SECONDS
        T.eq(ns.ShouldShowChatText(State({ lastMessageAt = 100 })), true, "just arrived")
        T.eq(ns.ShouldShowChatText(State({ lastMessageAt = 100 - seconds + 1 })), true, "still recent")
        T.eq(ns.ShouldShowChatText(State({ lastMessageAt = 100 - seconds })), false, "timed out")
    end)
end
