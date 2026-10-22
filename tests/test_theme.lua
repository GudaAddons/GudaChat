-- Theme palette: token lookup per theme, accent resolution, profile defaults, and the
-- Classic theme keeping the GudaChat 1.x colours

local function Same(T, entry, expected, label)
    for i = 1, 4 do
        T.eq(entry[i], expected[i], label .. "[" .. i .. "]")
    end
end

local function Near(T, value, expected, label)
    T.ok(math.abs(value - expected) < 1e-6, string.format("%s: got %s, want %s", label, tostring(value), tostring(expected)))
end

return function(T, H)
    local ns = H.Load()
    local Theme, C = ns.Theme, ns.Theme.C

    T.case("every theme defines every palette token", function()
        for _, name in ipairs(Theme.ORDER) do
            local colors = Theme.THEMES[name].colors
            for token in pairs(C) do
                T.ok(colors[token] ~= nil, name .. " lacks " .. token)
            end
        end
    end)

    T.case("Classic keeps the GudaChat 1.x colours", function()
        GudaChatDB.accent = "class"
        Theme.Set("classic")
        Same(T, C.panelBg, { 0.08, 0.08, 0.08, 0.95 }, "panelBg")
        Same(T, C.panelBorder, { 0.3, 0.3, 0.3, 0.6 }, "panelBorder")
        Same(T, C.accentBorder, { 0.8, 0.6, 0.0, 0.8 }, "accentBorder")
        Same(T, C.copyBg, { 0.1, 0.1, 0.1, 0.95 }, "copyBg")
        Same(T, C.headerBg, { 0.05, 0.05, 0.05, 0.85 }, "headerBg")
        Same(T, C.headerBorder, { 0.25, 0.25, 0.25, 0.5 }, "headerBorder")
        Same(T, C.barBg, { 0.05, 0.05, 0.05, 0.75 }, "barBg")
        Same(T, C.tabLabel, { 0.6, 0.45, 0.0, 0.8 }, "tabLabel")
        Same(T, C.scrollDownIcon, { 0.8, 0.6, 0, 0.9 }, "scrollDownIcon")
        Same(T, C.menuTitle, { 0.9, 0.75, 0.3, 1 }, "menuTitle")
        T.eq(Theme.chatBg.a, 0, "classic chat background is off")
    end)

    T.case("the old colour names point at the palette", function()
        T.ok(ns.COLOR_DARK_BG == C.panelBg, "COLOR_DARK_BG")
        T.ok(ns.COLOR_GOLDEN_A == C.accentBorder, "COLOR_GOLDEN_A")
        T.ok(ns.COLOR_HEADER_BG == C.headerBg, "COLOR_HEADER_BG")
    end)

    T.case("palette entries are filled in place on a switch", function()
        local entry = C.panelBg
        Theme.Set("blizzard")
        T.ok(C.panelBg == entry, "same table")
        Same(T, entry, { 0.09, 0.09, 0.19, 0.92 }, "blizzard panelBg")
        Same(T, C.tabActive, { 1, 0.82, 0, 1 }, "blizzard gold tab")
    end)

    T.case("Modern Dark takes the class colour as accent", function()
        GudaChatDB.accent = "class"
        Theme.Set("modern")
        Near(T, C.accentBorder[1], 0.25, "r")
        Near(T, C.accentBorder[2], 0.78, "g")
        Near(T, C.accentBorder[3], 0.92, "b")
        Near(T, C.accentBorder[4], 0.8, "a")
    end)

    T.case("a custom accent replaces the class colour", function()
        Theme.Set("modern")
        Theme.SetAccent({ r = 0.1, g = 0.2, b = 0.3 })
        Near(T, C.tabUnderline[1], 0.1, "r")
        Near(T, C.tabUnderline[3], 0.3, "b")
        T.ok(type(GudaChatDB.accent) == "table", "saved")
    end)

    T.case("Classic and Blizzard ignore the accent", function()
        Theme.SetAccent({ r = 0.1, g = 0.2, b = 0.3 })
        Theme.Set("classic")
        Same(T, C.accentBorder, { 0.8, 0.6, 0.0, 0.8 }, "classic gold")
        Theme.Set("blizzard")
        Same(T, C.accentBorder, { 1, 0.82, 0, 1 }, "blizzard gold")
    end)

    T.case("ResolveAccent: class, custom, and no class known", function()
        local r = Theme.ResolveAccent("class")
        Near(T, r, 0.25, "class r")
        local cr, cg, cb = Theme.ResolveAccent({ r = 0.4, g = 0.5, b = 0.6 })
        Near(T, cr, 0.4, "custom r")
        Near(T, cg, 0.5, "custom g")
        Near(T, cb, 0.6, "custom b")
        local saved = UnitClass
        UnitClass = function() return nil, nil end
        local gr, gg, gb = Theme.ResolveAccent("class")
        UnitClass = saved
        T.eq(gr, 1, "gold r")
        T.eq(gg, 0.82, "gold g")
        T.eq(gb, 0, "gold b")
    end)

    T.case("fresh installs start Modern Dark, 1.x profiles stay Classic", function()
        GudaChatDB = {}
        Theme.Init(true)
        T.eq(GudaChatDB.theme, "modern", "fresh")
        T.eq(GudaChatDB.accent, "class", "fresh accent")
        T.eq(Theme.Current(), "modern", "applied")
        GudaChatDB = { copyLinks = true }
        Theme.Init(false)
        T.eq(GudaChatDB.theme, "classic", "existing profile")
        GudaChatDB = { theme = "blizzard" }
        Theme.Init(false)
        T.eq(GudaChatDB.theme, "blizzard", "saved choice kept")
        GudaChatDB = { theme = "nonsense" }
        Theme.Init(true)
        T.eq(GudaChatDB.theme, "modern", "unknown theme replaced")
    end)

    T.case("Paint keeps regions themed across switches", function()
        local colored
        local region = { SetVertexColor = function(_, r, g, b, a) colored = { r, g, b, a } end }
        Theme.Set("classic")
        ns.Paint(region, C.iconDim)
        Same(T, colored, { 0.6, 0.6, 0.6, 1 }, "classic")
        Theme.Set("blizzard")
        Same(T, colored, { 0.75, 0.75, 0.75, 1 }, "repainted")
    end)

    T.case("PaintTab: chat colour in Classic, palette in plain themes", function()
        local got
        local text = { SetTextColor = function(_, r, g, b, a) got = { r, g, b, a } end }
        Theme.Set("classic")
        Theme.PaintTab(text, { 1, 1, 0 }, "inactive")
        Same(T, got, { 0.5, 0.5, 0, 0.8 }, "classic inactive")
        Theme.PaintTab(text, { 1, 1, 0 }, "drag")
        Same(T, got, { 0.3, 0.3, 0, 0.5 }, "classic drag")
        Theme.Set("blizzard")
        Theme.PaintTab(text, { 1, 1, 0 }, "active")
        Same(T, got, { 1, 0.82, 0, 1 }, "blizzard active")
        T.ok(not Theme.HasTabUnderline(), "no underline in Blizzard")
        Theme.Set("modern")
        T.ok(Theme.HasTabUnderline(), "underline in Modern Dark")
    end)
end
