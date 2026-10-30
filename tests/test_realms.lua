-- Hide realm names: only the shown text of player links loses "-Realm", the link target
-- keeps the full name so whisper and invite still reach the right player

local SAY_LINE = "|Hplayer:Vati-Pyrewood:42:SAY|h[|cffc79c6eVati-Pyrewood|r]|h says: hi there - all"

return function(T, H)
    local ns = H.Load()
    local Strip = ns.StripRealmsFromLinks

    T.case("the shown name loses its realm, the link keeps it", function()
        local out = Strip(SAY_LINE)
        T.contains(out, "|Hplayer:Vati-Pyrewood:42:SAY|h", "link target")
        T.contains(out, "[|cffc79c6eVati|r]", "shown name")
        T.contains(out, "says: hi there - all", "message text untouched")
    end)

    T.case("uncolored and emote names are stripped", function()
        T.eq(Strip("|Hplayer:Bob-Realm|h[Bob-Realm]|h: yo"), "|Hplayer:Bob-Realm|h[Bob]|h: yo")
        T.eq(Strip("|Hplayer:Bob-Realm:7|hBob-Realm|h waves."), "|Hplayer:Bob-Realm:7|hBob|h waves.")
    end)

    T.case("realms with apostrophes are stripped", function()
        T.eq(Strip("|Hplayer:Bob-Kel'Thuzad|h[Bob-Kel'Thuzad]|h"), "|Hplayer:Bob-Kel'Thuzad|h[Bob]|h")
    end)

    T.case("every player link in a line is stripped", function()
        local out = Strip("|Hplayer:A-X|h[A-X]|h and |Hplayer:B-Y|h[B-Y]|h")
        T.eq(out, "|Hplayer:A-X|h[A]|h and |Hplayer:B-Y|h[B]|h")
    end)

    T.case("lines without a realm are left alone", function()
        T.eq(Strip("|Hplayer:Bob:1|h[Bob]|h: well-known"), nil, "same-realm name")
        T.eq(Strip("plain - text"), nil, "no player link")
        T.eq(Strip("|cff1eff00|Hitem:1|h[Item-Name]|h|r"), nil, "item link")
    end)

    T.case("the option is offered on Classic clients only", function()
        T.ok(H.Load({ interface = 11509 }).CAN_HIDE_REALMS, "Era")
        T.ok(H.Load({ interface = 20506 }).CAN_HIDE_REALMS, "Anniversary")
        T.ok(H.Load({ interface = 50504 }).CAN_HIDE_REALMS, "MoP")
        T.ok(not H.Load({ interface = 120105 }).CAN_HIDE_REALMS, "Retail")
        T.ok(not H.Load({ interface = 16001 }).CAN_HIDE_REALMS, "Forever")
    end)
end
