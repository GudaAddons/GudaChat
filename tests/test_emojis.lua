-- Emoji codes are replaced only where they stand alone, longest code first

return function(T, H)
    local ns = H.Load()

    local function Emojify(msg)
        return ns.EmojifyMessage(msg, 12)
    end

    T.case("codes are replaced", function()
        T.contains(Emojify("hello :)"), "emoji_smile.png", ":)")
        T.contains(Emojify("so tired zzz"), "emoji_zzz.png", "zzz")
        T.contains(Emojify("xD"), "emoji_laugh.png", "xD")
        T.contains(Emojify("nice B)"), "emoji_cool.png", "B)")
        T.contains(Emojify("<3 you"), "emoji_heart.png", "<3")
    end)

    T.case("text that only looks like a code stays text", function()
        T.eq(Emojify("(Plan B)"), false, "(Plan B)")
        T.eq(Emojify("maxDPS"), false, "maxDPS")
        T.eq(Emojify("0xDEAD"), false, "0xDEAD")
        T.eq(Emojify("Jazzz"), false, "Jazzz")
        T.eq(Emojify("plain words"), false, "no codes")
    end)

    T.case("the longest code wins", function()
        local angry = Emojify("no >:(")
        T.contains(angry, "emoji_angry.png", ">:(")
        T.ok(not angry:find("emoji_sad.png", 1, true), ">:( is not :(")
        local cat = Emojify(":cat_laugh:")
        T.contains(cat, "emoji_cat_laugh.png", ":cat_laugh:")
        T.ok(not cat:find("emoji_cat.png", 1, true), ":cat_laugh: is not :cat:")
    end)

    T.case("codes inside links and brackets stay text", function()
        local link = "|cffffffff|Hitem:1::|h[Sword :)]|h|r"
        T.eq(Emojify(link), false, "item link")
        T.eq(Emojify("[:)]"), false, "brackets")
    end)

    T.case("the size setting is used", function()
        T.contains(ns.EmojifyMessage(":)", 20), ":20|t", "size 20")
    end)
end
