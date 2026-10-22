-- Character name comparison across client name shapes, and the unit name on Forever

return function(T, H)
    local ns = H.Load()

    T.case("realm suffix and case are ignored", function()
        T.eq(ns.CompactName("Vati-Realm"), "vati")
        T.ok(ns.SameCharacter("Vati-Realm", "vati"), "Vati-Realm vs vati")
        T.ok(not ns.SameCharacter("Vati", "Vatiman"), "different names")
    end)

    T.case("Forever two-part names match in every shape", function()
        T.ok(ns.SameCharacter("Joob Stabber", "JoobStabber"), "space vs no space")
        T.ok(ns.SameCharacter("joob stabber-Realm", "Joob Stabber"), "lower case with realm")
        T.ok(not ns.SameCharacter("Joob Stabber", "Joob"), "given name alone")
    end)

    T.case("non-ASCII names fold case", function()
        T.ok(ns.SameCharacter("Вати", "вати"), "Cyrillic")
    end)

    T.case("secret, empty and missing names never match", function()
        T.eq(ns.CompactName(H.SECRET), nil, "secret")
        T.eq(ns.CompactName(""), nil, "empty")
        T.eq(ns.CompactName(nil), nil, "nil")
        T.ok(not ns.SameCharacter(nil, nil), "nil vs nil")
        T.ok(not ns.SameCharacter(H.SECRET, H.SECRET), "secret vs secret")
    end)

    T.case("UnitFullName joins given and family name on Forever", function()
        local forever = H.Load({ interface = 16001, name = "Joob", family = "Stabber" })
        T.ok(forever.IS_FOREVER, "IS_FOREVER")
        T.ok(forever.HAS_MAINLINE_CHAT, "HAS_MAINLINE_CHAT")
        T.eq(forever.UnitFullName("player"), "Joob Stabber")
    end)

    T.case("UnitFullName ignores a realm second value", function()
        local forever = H.Load({ interface = 16001, name = "Joob", family = "Realm" })
        T.eq(forever.UnitFullName("player"), "Joob")
    end)

    T.case("Classic and Retail use the first UnitName value", function()
        local era = H.Load({ interface = 11509, name = "Vati", family = "Realm2" })
        T.ok(not era.IS_FOREVER and not era.HAS_MAINLINE_CHAT, "Era flags")
        T.eq(era.UnitFullName("player"), "Vati")
        local retail = H.Load({ interface = 120105 })
        T.ok(retail.IS_RETAIL and retail.HAS_MAINLINE_CHAT and not retail.IS_FOREVER, "Retail flags")
    end)
end
