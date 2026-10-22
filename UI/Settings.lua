local addonName, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Font options
---------------------------------------------------------------------------

local ADDON_FONTS = "Interface\\AddOns\\GudaChat\\Assets\\Fonts\\"

-- Blizzard ships these four filenames on every client, with locale-appropriate
-- glyphs inside, so they are safe everywhere.
local BLIZZARD_FONTS = {
    { label = ns.Blizz(DEFAULT, "Default") .. " (Friz Quadrata)", value = "Fonts\\FRIZQT__.TTF" },
    { label = "Arial Narrow",           value = "Fonts\\ARIALN.TTF" },
    { label = "Morpheus",               value = "Fonts\\MORPHEUS.TTF" },
    { label = "Skurri",                 value = "Fonts\\SKURRI.TTF" },
}

-- Bundled faces. `cyrillic` marks the ones that actually carry Cyrillic glyphs;
-- none of them carry CJK, so all four are withheld on zhCN/zhTW/koKR.
local BUNDLED_FONTS = {
    { label = "Fira Sans Medium", value = ADDON_FONTS .. "FiraSans-Medium.ttf",       cyrillic = true },
    { label = "Ubuntu",           value = ADDON_FONTS .. "Ubuntu-Regular.ttf",        cyrillic = true },
    { label = "Archivo Black",    value = ADDON_FONTS .. "ArchivoBlack-Regular.ttf" },
    { label = "Audiowide",        value = ADDON_FONTS .. "Audiowide-Regular.ttf" },
}

-- SetFont fails silently when a file cannot be loaded, and a frame left without a
-- font makes AddMessage drop every line (see the note in UI/Header.lua). Probe by
-- applying to a throwaway FontString and reading the path back.
local fontProbe
local function FontLoads(path)
    if not path or path == "" then return false end
    if not fontProbe then
        fontProbe = UIParent:CreateFontString(nil, "OVERLAY")
        fontProbe:Hide()
    end
    if not pcall(fontProbe.SetFont, fontProbe, path, 12) then return false end
    local applied = fontProbe:GetFont()
    return applied ~= nil and applied:lower() == path:lower()
end
ns.FontLoads = FontLoads

local cachedFontOptions
local function GetFontOptions()
    if cachedFontOptions then return cachedFontOptions end

    local locale = GetLocale()
    local nonLatin = ns.NON_LATIN_LOCALE[locale]
    local options, seen = {}, {}

    local function add(path, label)
        if path and path ~= "" and not seen[path] and FontLoads(path) then
            seen[path] = true
            options[#options + 1] = { label = label, value = path }
        end
    end

    -- The client's own standard font is always correct for this locale
    add(STANDARD_TEXT_FONT, ns.Blizz(DEFAULT, "Default"))
    for _, f in ipairs(BLIZZARD_FONTS) do add(f.value, f.label) end
    for _, f in ipairs(BUNDLED_FONTS) do
        -- Latin-only faces would render CJK as blocks and Cyrillic as nothing
        if not nonLatin or (locale == "ruRU" and f.cyrillic) then
            add(f.value, f.label)
        end
    end

    if #options == 0 then
        options[1] = { label = ns.Blizz(DEFAULT, "Default"), value = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" }
    end
    cachedFontOptions = options
    return options
end
ns.GetFontOptions = GetFontOptions

-- True when the path is offered on this client. Stricter than FontLoads: a
-- Latin-only bundled face loads fine on zhCN, it just renders blocks.
function ns.IsFontAllowed(path)
    if not path then return false end
    for _, opt in ipairs(GetFontOptions()) do
        if opt.value == path then return true end
    end
    return false
end

-- Never leave a frame fontless: fall back to the client's standard font.
local function SafeSetFont(frame, path, size, flags)
    local fallback = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    -- GetFont can return nil (e.g. after an earlier failed SetFont), and passing
    -- a nil path to SetFont errors outright
    if not path or path == "" then
        frame:SetFont(fallback, size or 14, flags)
        return false
    end
    if frame:SetFont(path, size, flags) ~= false and frame:GetFont() then return true end
    frame:SetFont(fallback, size or 14, flags)
    return false
end
ns.SafeSetFont = SafeSetFont

local function ApplyChatFont(fontPath)
    if not FontLoads(fontPath) then
        fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    end
    ns.ForEachChatFrame(function(cf)
        local _, size, flags = cf:GetFont()
        SafeSetFont(cf, fontPath, size, flags)
    end)
    local histMsgFrame = _G["GudaChatHistoryMsgFrame"]
    if histMsgFrame then
        local _, size, flags = histMsgFrame:GetFont()
        SafeSetFont(histMsgFrame, fontPath, size, flags)
    end
end
ns.ApplyChatFont = ApplyChatFont

local function ApplyChatFontSize(size)
    ns.ForEachChatFrame(function(cf)
        local font, _, flags = cf:GetFont()
        SafeSetFont(cf, font, size, flags)
    end)
end
ns.ApplyChatFontSize = ApplyChatFontSize

local TIMESTAMP_OPTIONS = {
    { label = ns.Blizz(NONE, "None"),        value = "none" },
    { label = "03:27",         value = "%I:%M " },
    { label = "03:27:32",      value = "%I:%M:%S " },
    { label = "03:27 PM",      value = "%I:%M %p " },
    { label = "03:27:32 PM",   value = "%I:%M:%S %p " },
    { label = "15:27",         value = "%H:%M " },
    { label = "15:27:32",      value = "%H:%M:%S " },
    { label = "[03:27]",       value = "[%I:%M] " },
    { label = "[03:27:32]",    value = "[%I:%M:%S] " },
    { label = "[03:27 PM]",    value = "[%I:%M %p] " },
    { label = "[03:27:32 PM]", value = "[%I:%M:%S %p] " },
    { label = "[15:27]",       value = "[%H:%M] " },
    { label = "[15:27:32]",    value = "[%H:%M:%S] " },
}

---------------------------------------------------------------------------
-- Clear history popup
---------------------------------------------------------------------------

StaticPopupDialogs["GUDACHAT_CLEAR_HISTORY"] = {
    text = L["CONFIRM_CLEAR_HISTORY"],
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function()
        if GudaChatCharDB and GudaChatCharDB.history then
            for k in pairs(GudaChatCharDB.history) do
                wipe(GudaChatCharDB.history[k])
            end
        end
        if GudaChatCharDB and GudaChatCharDB.lootLog then wipe(GudaChatCharDB.lootLog) end
        if GudaChatCharDB and GudaChatCharDB.addonLog then wipe(GudaChatCharDB.addonLog) end
        if ns.historyFrame and ns.historyFrame.RefreshHistory then
            ns.historyFrame:RefreshHistory()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

---------------------------------------------------------------------------
-- Settings window
--
-- A themed window with a sidebar of pages; each page is a scrolling column of cards.
-- Cards are registered with ns.AddSettingsCard(page, order, build) and built the first
-- time the window opens, so other files can add their own (phase 4 adds the whisper
-- icon card to the "tabs" page at order 40). build(page) returns a card from
-- ns.CreateCard; page:Relayout() restacks the cards after one changes height.
---------------------------------------------------------------------------

local WINDOW_WIDTH, WINDOW_HEIGHT = 660, 470
local SIDEBAR_WIDTH = 172
local NAV_HEIGHT = 30
local PAGE_PADDING = 14
local CARD_GAP = 10

local LOG_CAP_MIN = 100
local LOG_CAP_MAX = 2000
local LOG_CAP_STEP = 100

local CHAT_FONT_SIZE_MIN, CHAT_FONT_SIZE_MAX = 8, 24
local HISTORY_FONT_SIZE_MIN, HISTORY_FONT_SIZE_MAX = 8, 24

local SUPPORTED_CLIENTS = "Retail, MoP Classic, TBC Anniversary, Classic Era, WoW: Forever"
local SLASH_COMMANDS = "/gc, /gudachat"

local C = ns.Theme.C

local PAGES = {
    { key = "appearance", label = L["SEC_APPEARANCE"], icon = "cog.png" },
    { key = "chat", label = ns.Blizz(CHAT, "Chat"), icon = "chat.png" },
    { key = "messages", label = L["TAB_MESSAGES"], icon = "voice.png" },
    { key = "tabs", label = L["NAV_TABS_ALERTS"], icon = "characters.png" },
    { key = "history", label = L["NAV_HISTORY_LOGS"], icon = "history.png" },
    { key = "about", label = L["NAV_ABOUT"], icon = "logo.png" },
}

local cardBuilders = {}

function ns.AddSettingsCard(pageKey, order, build)
    cardBuilders[pageKey] = cardBuilders[pageKey] or {}
    tinsert(cardBuilders[pageKey], { order = order, build = build })
end
local AddCard = ns.AddSettingsCard

local function Toggle(label, key, onChange, hint)
    return ns.CreateToggle(label, function() return GudaChatDB[key] end, function(value)
        GudaChatDB[key] = value
        if onChange then onChange(value) end
    end, hint)
end

local function NotificationToggle(label, key)
    return ns.CreateToggle(label, function() return GudaChatDB.notifications[key] end, function(value)
        GudaChatDB.notifications[key] = value
    end)
end

local function AddonVersion()
    local getter = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return getter and getter(addonName, "Version") or ""
end

---------------------------------------------------------------------------
-- Live preview
---------------------------------------------------------------------------

local PREVIEW_HEIGHT = 150
local PREVIEW_SCENE = { 0.2, 0.19, 0.24, 1 }
local PREVIEW_TAB_GENERAL = { 1, 1, 0 }
local PREVIEW_FONT_SCALE = 0.85

local function ClassColored(name, class)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not (GudaChatDB.classColors and c) then return "[" .. name .. "]" end
    return string.format("|cff%02x%02x%02x[%s]|r", c.r * 255, c.g * 255, c.b * 255, name)
end

local function ChatTypeRGB(chatType, fallback)
    local info = ChatTypeInfo and ChatTypeInfo[chatType]
    if info and info.r then return info.r, info.g, info.b end
    return fallback[1], fallback[2], fallback[3]
end

-- The preview's sample lines: chat type, fallback colour and the text builder
local function PreviewLines()
    local whispers = ns.Blizz(CHAT_WHISPER_GET, "%s whispers: ")
    local says = ns.Blizz(CHAT_SAY_GET, "%s says: ")
    return {
        { "GUILD", { 0.25, 1, 0.25 }, "[" .. ns.Blizz(GUILD, "Guild") .. "] " .. ClassColored("Garrosh", "WARRIOR") .. ": " .. L["PREVIEW_GUILD"] },
        { "WHISPER", { 1, 0.5, 1 }, string.format(whispers, ClassColored("Sylvanas", "HUNTER")) .. L["PREVIEW_WHISPER"] },
        { "SAY", { 1, 1, 1 }, string.format(says, ClassColored("Uther", "PALADIN")) .. L["PREVIEW_SAY"] },
    }
end

-- A small fake chat built from the themed widgets: header, tabs, a few lines in the chat
-- font and the input bar. Redraws on theme, accent, font and background changes.
local function CreatePreview(parent)
    local box = CreateFrame("Frame", nil, parent)
    box:SetHeight(PREVIEW_HEIGHT)

    local scene = box:CreateTexture(nil, "BACKGROUND")
    scene:SetAllPoints()
    scene:SetColorTexture(unpack(PREVIEW_SCENE))

    local header = CreateFrame("Frame", nil, box, "BackdropTemplate")
    header:SetHeight(20)
    header:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
    header:SetPoint("TOPRIGHT", box, "TOPRIGHT", -8, -8)
    ns.ApplyDarkBackdrop(header, C.headerBg, C.headerBorder, true)
    local headerTitle = header:CreateFontString(nil, "OVERLAY", "GudaChatFontNormalSmall")
    headerTitle:SetPoint("CENTER")
    headerTitle:SetText(ns.Blizz(GENERAL, "General"))
    ns.Paint(headerTitle, C.tabLabel)
    for i, icon in ipairs({ "characters.png", "chat.png" }) do
        local tex = header:CreateTexture(nil, "ARTWORK")
        tex:SetSize(12, 12)
        tex:SetPoint("LEFT", header, "LEFT", 6 + (i - 1) * 16, 0)
        tex:SetTexture(ns.ASSET_PATH .. icon)
        ns.Paint(tex, C.iconNormal)
    end
    local cog = header:CreateTexture(nil, "ARTWORK")
    cog:SetSize(12, 12)
    cog:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    cog:SetTexture(ns.ASSET_PATH .. "cog.png")
    ns.Paint(cog, C.iconNormal)

    local tabDefs = {
        { label = ns.Blizz(GENERAL, "General"), col = PREVIEW_TAB_GENERAL, state = "active" },
        { label = ns.Blizz(WHISPER, "Whisper"), col = { ChatTypeRGB("WHISPER", { 1, 0.5, 1 }) }, state = "inactive" },
        { label = ns.Blizz(TRADE, "Trade"), col = { 1, 0.75, 0.75 }, state = "inactive" },
    }
    local tabs = {}
    for i, def in ipairs(tabDefs) do
        local text = box:CreateFontString(nil, "OVERLAY", "GudaChatFontNormalSmall")
        text:SetText(def.label)
        if i == 1 then
            text:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 8, -5)
        else
            text:SetPoint("LEFT", tabs[i - 1], "RIGHT", 14, 0)
        end
        tabs[i] = text
    end
    local underline = box:CreateTexture(nil, "ARTWORK")
    underline:SetTexture("Interface\\Buttons\\WHITE8x8")
    underline:SetHeight(1)
    underline:SetPoint("TOPLEFT", tabs[1], "BOTTOMLEFT", 0, -2)
    underline:SetPoint("TOPRIGHT", tabs[1], "BOTTOMRIGHT", 0, -2)

    local messages = CreateFrame("Frame", nil, box)
    messages:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -24)
    messages:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -24)
    messages:SetHeight(62)
    local messagesBg = messages:CreateTexture(nil, "BACKGROUND")
    messagesBg:SetAllPoints()
    messagesBg:SetTexture("Interface\\Buttons\\WHITE8x8")

    local lines = {}
    for i = 1, 3 do
        local line = messages:CreateFontString(nil, "OVERLAY")
        line:SetPoint("TOPLEFT", messages, "TOPLEFT", 6, -4 - (i - 1) * 19)
        line:SetPoint("RIGHT", messages, "RIGHT", -6, 0)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        line:SetShadowOffset(1, -1)
        lines[i] = line
    end

    local input = CreateFrame("Frame", nil, box, "BackdropTemplate")
    input:SetHeight(20)
    input:SetPoint("TOPLEFT", messages, "BOTTOMLEFT", 0, -4)
    input:SetPoint("TOPRIGHT", messages, "BOTTOMRIGHT", 0, -4)
    ns.ApplyDarkBackdrop(input, C.headerBg, C.accentBorder, true)
    local inputText = input:CreateFontString(nil, "OVERLAY")
    inputText:SetPoint("LEFT", input, "LEFT", 6, 0)
    inputText:SetShadowOffset(1, -1)

    function box.Update()
        local font, size, flags = ChatFrame1:GetFont()
        font = GudaChatDB.chatFont or font or STANDARD_TEXT_FONT
        size = math.floor((GudaChatDB.chatFontSize or size or 14) * PREVIEW_FONT_SCALE + 0.5)
        for i, def in ipairs(PreviewLines()) do
            ns.SafeSetFont(lines[i], font, size, flags)
            lines[i]:SetText(def[3])
            lines[i]:SetTextColor(ChatTypeRGB(def[1], def[2]))
        end
        ns.SafeSetFont(inputText, font, size, flags)
        inputText:SetText(ns.Blizz(SAY, "Say") .. ": " .. L["PREVIEW_INPUT"])
        local color, alpha = ns.GetChatBackground()
        messagesBg:SetVertexColor(color.r, color.g, color.b, alpha)
        for i, def in ipairs(tabDefs) do
            ns.Theme.PaintTab(tabs[i], def.col, def.state)
        end
        underline:SetShown(ns.Theme.HasTabUnderline())
        underline:SetVertexColor(C.tabUnderline[1], C.tabUnderline[2], C.tabUnderline[3], C.tabUnderline[4])
    end

    ns.OnRestyle(box.Update)
    return box
end

local preview

local function UpdatePreview()
    if preview then preview.Update() end
end

---------------------------------------------------------------------------
-- Appearance page
---------------------------------------------------------------------------

local THEME_LABELS = { classic = "THEME_CLASSIC", modern = "THEME_MODERN", blizzard = "THEME_BLIZZARD" }
local THUMB_HEIGHT = 46

-- One clickable theme card: a thumbnail drawn in that theme's own colours, and its name
local function CreateThemeChoice(parent, name, onPick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(THUMB_HEIGHT + 30)
    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })

    local thumb = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    thumb:SetPoint("TOPLEFT", btn, "TOPLEFT", 6, -6)
    thumb:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -6, -6)
    thumb:SetHeight(THUMB_HEIGHT)
    thumb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })

    local stripe = thumb:CreateTexture(nil, "ARTWORK")
    stripe:SetTexture("Interface\\Buttons\\WHITE8x8")
    stripe:SetPoint("TOPLEFT", thumb, "TOPLEFT", 6, -6)
    local thumbTitle = thumb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    thumbTitle:SetPoint("TOPLEFT", thumb, "TOPLEFT", 6, -4)
    thumbTitle:SetText("GudaChat")
    local bars = {}
    for i = 1, 3 do
        local bar = thumb:CreateTexture(nil, "ARTWORK")
        bar:SetTexture("Interface\\Buttons\\WHITE8x8")
        bar:SetHeight(2)
        bar:SetPoint("TOPLEFT", thumb, "TOPLEFT", 6, -18 - (i - 1) * 7)
        bar:SetPoint("RIGHT", thumb, "RIGHT", -6 - (i - 1) * 12, 0)
        bar:SetVertexColor(1, 1, 1, 0.18)
        bars[i] = bar
    end

    local label = btn:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlightSmall")
    label:SetPoint("BOTTOM", btn, "BOTTOM", 0, 7)
    label:SetPoint("LEFT", btn, "LEFT", 4, 0)
    label:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    label:SetWordWrap(false)
    label:SetText(L[THEME_LABELS[name]])

    function btn.Refresh()
        local selected = ns.Theme.Current() == name
        thumb:SetBackdropColor(ns.Theme.ColorOf(name, "panelBg"))
        thumb:SetBackdropBorderColor(ns.Theme.ColorOf(name, "panelBorder"))
        if name == "blizzard" then
            stripe:Hide()
            thumbTitle:Show()
        else
            thumbTitle:Hide()
            stripe:Show()
            local token = name == "modern" and "tabUnderline" or "accentBorder"
            stripe:SetVertexColor(ns.Theme.ColorOf(name, token))
            stripe:SetSize(name == "modern" and 30 or 60, name == "modern" and 2 or 4)
        end
        btn:SetBackdropColor(0, 0, 0, 0)
        local border = selected and C.accentBorder or C.cardBorder
        btn:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
        local text = selected and C.navActiveText or C.navText
        label:SetTextColor(text[1], text[2], text[3], text[4])
    end

    btn:SetScript("OnClick", function() onPick(name) end)
    ns.OnRestyle(btn.Refresh)
    return btn
end

AddCard("appearance", 10, function(page)
    local card = ns.CreateCard(page, L["OPT_THEME"])
    local row = CreateFrame("Frame")
    row:SetHeight(THUMB_HEIGHT + 40)
    row.noRule = true
    local choices = {}
    for i, name in ipairs(ns.Theme.ORDER) do
        local choice = CreateThemeChoice(row, name, function(picked)
            ns.Theme.Choose(picked)
            page:Relayout()
        end)
        choices[i] = choice
    end
    row:SetScript("OnSizeChanged", function(self, width)
        local gap = 8
        local each = (width - gap * (#choices - 1)) / #choices
        for i, choice in ipairs(choices) do
            choice:ClearAllPoints()
            choice:SetPoint("TOPLEFT", self, "TOPLEFT", (i - 1) * (each + gap), -4)
            choice:SetWidth(each)
        end
    end)
    card:AddRow(row)
    return card
end)

-- Classes whose colour the accent row offers, in the client's own order
local function AccentClasses()
    local list = {}
    local order = CLASS_SORT_ORDER
    if type(order) ~= "table" then
        order = {}
        for class in pairs(RAID_CLASS_COLORS or {}) do tinsert(order, class) end
        table.sort(order)
    end
    for _, class in ipairs(order) do
        if RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then tinsert(list, class) end
    end
    return list
end

local CLASS_SWATCH_SIZE = 14

AddCard("appearance", 20, function(page)
    local card = ns.CreateCard(page, L["OPT_ACCENT_COLOR"])
    local rows = {}

    rows.useClass = ns.CreateToggle(L["OPT_ACCENT_CLASS"], function() return GudaChatDB.accent == "class" end, function(value)
        if value then
            ns.Theme.SetAccent("class")
        else
            local r, g, b = ns.Theme.ResolveAccent(GudaChatDB.accent)
            ns.Theme.SetAccent({ r = r, g = g, b = b })
        end
    end)
    card:AddRow(rows.useClass)

    local classes = AccentClasses()
    rows.classes = ns.CreateSettingsRow(L["OPT_CLASS_PALETTE"], nil, #classes * (CLASS_SWATCH_SIZE + 3))
    for i, class in ipairs(classes) do
        local c = RAID_CLASS_COLORS[class]
        local sw = CreateFrame("Button", nil, rows.classes)
        sw:SetSize(CLASS_SWATCH_SIZE, CLASS_SWATCH_SIZE)
        sw:SetPoint("RIGHT", rows.classes, "RIGHT", -(#classes - i) * (CLASS_SWATCH_SIZE + 3), 0)
        local tex = sw:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetColorTexture(c.r, c.g, c.b, 1)
        sw:SetScript("OnClick", function() ns.Theme.SetAccent({ r = c.r, g = c.g, b = c.b }) end)
        sw:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class, c.r, c.g, c.b)
            GameTooltip:Show()
        end)
        sw:SetScript("OnLeave", GameTooltip_Hide)
    end
    card:AddRow(rows.classes)

    rows.custom = ns.CreateSettingsRow(L["OPT_CUSTOM_COLOR"], nil, 30)
    local swatch = ns.CreateSwatch(rows.custom,
        function() return ns.Theme.ResolveAccent(GudaChatDB.accent) end,
        function(r, g, b) ns.Theme.SetAccent({ r = r, g = g, b = b }) end,
        function(r, g, b) ns.Theme.SetAccent({ r = r, g = g, b = b }) end)
    swatch:SetPoint("RIGHT", rows.custom, "RIGHT", 0, 0)
    card:AddRow(rows.custom)

    rows.note = ns.CreateSettingsRow(L["NOTE_ACCENT_MODERN"])
    rows.note.label:SetFontObject(GudaChatFontDisableSmall)
    ns.Paint(rows.note.label, C.dimText)
    card:AddRow(rows.note)

    ns.OnRestyle(function()
        local uses = ns.Theme.UsesAccent()
        rows.useClass.collapsed = not uses
        rows.classes.collapsed = not uses
        rows.custom.collapsed = not uses
        rows.note.collapsed = uses
        rows.useClass.Refresh()
        card:Relayout()
        if page.Relayout then page:Relayout() end
    end)
    return card
end)

AddCard("appearance", 30, function(page)
    local card = ns.CreateCard(page, L["SEC_PREVIEW"])
    local row = CreateFrame("Frame")
    row:SetHeight(PREVIEW_HEIGHT + 8)
    row.noRule = true
    preview = CreatePreview(row)
    preview:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    preview:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    card:AddRow(row)
    return card
end)

AddCard("appearance", 40, function(page)
    local card = ns.CreateCard(page, L["OPT_FONT"])
    card:AddRow(ns.CreateDropdown(L["OPT_FONT"], GetFontOptions,
        function() return GudaChatDB.chatFont or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end,
        function(value)
            GudaChatDB.chatFont = value
            ApplyChatFont(value)
            UpdatePreview()
        end))
    card:AddRow(ns.CreateSlider(L["OPT_FONT_SIZE"], CHAT_FONT_SIZE_MIN, CHAT_FONT_SIZE_MAX, 1,
        function()
            local _, size = ChatFrame1:GetFont()
            return GudaChatDB.chatFontSize or math.floor((size or 14) + 0.5)
        end,
        function(value)
            GudaChatDB.chatFontSize = value
            ApplyChatFontSize(value)
            UpdatePreview()
        end))
    return card
end)

-- Puts every chat window back on its own saved background (override turned off)
local function RestoreWindowBackgrounds()
    ns.ForEachChatWindow(function(cf, i)
        local bg = _G["ChatFrame" .. i .. "Background"]
        if not bg then return end
        local savedAlpha = select(6, GetChatWindowInfo(i)) or 0
        if savedAlpha > 0 then
            bg:SetScript("OnShow", nil)
            bg:Show()
            bg:SetAlpha(savedAlpha)
            cf.gudaBgAlpha = savedAlpha
        else
            bg:SetAlpha(0)
            bg:Hide()
            bg:SetScript("OnShow", function(self) self:Hide() end)
            cf.gudaBgAlpha = 0
        end
    end)
end

local function ApplyBackgroundIfWanted()
    if GudaChatDB.useGlobalBg then
        ns.ApplyGlobalBackground()
    end
    UpdatePreview()
end

AddCard("appearance", 50, function(page)
    local card = ns.CreateCard(page, L["SEC_BACKGROUND"])
    local opacity, colorRow

    local override = Toggle(L["OPT_OVERRIDE_BACKGROUNDS"], "useGlobalBg", function(checked)
        if checked then
            ns.ApplyGlobalBackground()
        else
            RestoreWindowBackgrounds()
        end
        opacity.collapsed = not checked
        colorRow.collapsed = not checked
        card:Relayout()
        page:Relayout()
        UpdatePreview()
    end)
    card:AddRow(override)

    opacity = ns.CreateSlider(ns.Blizz(OPACITY, "Opacity"), 0, 100, 5,
        function()
            local _, alpha = ns.GetChatBackground()
            return math.floor(alpha * 100 + 0.5)
        end,
        function(value)
            ns.TakeOverChatBackground()
            GudaChatDB.globalBgAlpha = value / 100
            ApplyBackgroundIfWanted()
        end)
    opacity.collapsed = not GudaChatDB.useGlobalBg
    card:AddRow(opacity)

    colorRow = ns.CreateSettingsRow(ns.Blizz(COLOR, "Colour"), nil, 30)
    local swatch = ns.CreateSwatch(colorRow,
        function()
            local color = ns.GetChatBackground()
            return color.r, color.g, color.b
        end,
        function(r, g, b)
            ns.TakeOverChatBackground()
            GudaChatDB.globalBgColor = { r = r, g = g, b = b }
            ApplyBackgroundIfWanted()
        end,
        function(r, g, b)
            GudaChatDB.globalBgColor = { r = r, g = g, b = b }
            ApplyBackgroundIfWanted()
        end)
    swatch:SetPoint("RIGHT", colorRow, "RIGHT", 0, 0)
    colorRow.collapsed = not GudaChatDB.useGlobalBg
    card:AddRow(colorRow)

    ns.OnRestyle(function()
        opacity.Refresh()
        swatch.Refresh()
    end)
    return card
end)

---------------------------------------------------------------------------
-- Chat page
---------------------------------------------------------------------------

AddCard("chat", 10, function(page)
    local card = ns.CreateCard(page, L["SEC_CHAT_WINDOW"])
    card:AddRow(Toggle(L["OPT_LOCK_POSITION"], "locked", function() ns.ApplyLockState() end))
    card:AddRow(ns.CreateToggle(L["OPT_DISABLE_FADING"], function() return not GudaChatDB.fading end, function(value)
        GudaChatDB.fading = not value
        ns.ApplyFading()
    end))
    card:AddRow(Toggle(L["OPT_HIDE_IDLE_TEXT"], "hideIdleText", function()
        ns.ApplyIdleText()
    end, L["HINT_HIDE_IDLE_TEXT"]))
    card:AddRow(Toggle(L["OPT_HIDE_SCROLLBAR"], "hideScrollbar", function(checked)
        ns.ForEachChatFrame(function(cf)
            if cf.gudaScrollbar then
                if checked then
                    cf.gudaScrollbar:Hide()
                else
                    cf.gudaScrollbar:Show()
                    cf.gudaScrollbar:SetAlpha(0)
                end
            end
        end)
        ns.ApplyChatMargins()
    end))
    card:AddRow(ns.CreateDropdown(L["OPT_TIMESTAMPS"], TIMESTAMP_OPTIONS,
        function() return GetCVar("showTimestamps") or "none" end,
        function(value) SetCVar("showTimestamps", value) end,
        L["NOTE_APPLIES_AFTER_RELOAD"]))
    return card
end)

AddCard("chat", 20, function(page)
    local card = ns.CreateCard(page, L["SEC_INPUT_BAR"])
    card:AddRow(ns.CreateToggle(L["OPT_INPUT_BAR_TOP"], function() return GudaChatDB.inputPosition == "top" end, function(value)
        GudaChatDB.inputPosition = value and "top" or "bottom"
        ns.ApplyInputBarPosition()
    end))
    card:AddRow(Toggle(L["OPT_TRANSPARENT_INPUT"], "transparentInput", function() ns.ApplyTransparentInput() end))
    return card
end)

---------------------------------------------------------------------------
-- Messages page
---------------------------------------------------------------------------

AddCard("messages", 10, function(page)
    local card = ns.CreateCard(page, L["SEC_MESSAGES"])
    card:AddRow(Toggle(L["OPT_CLASS_COLORS"], "classColors", function()
        ns.ApplyClassColors()
        UpdatePreview()
    end))
    card:AddRow(Toggle(L["OPT_SHOW_LEVEL"], "showLevel"))
    card:AddRow(Toggle(L["OPT_COPYABLE_LINKS"], "copyLinks"))
    return card
end)

AddCard("messages", 20, function(page)
    local card = ns.CreateCard(page, L["SEC_NAME_HIGHLIGHT"])
    card:AddRow(Toggle(L["OPT_HIGHLIGHT_NAME"], "highlightName"))
    card:AddRow(Toggle(L["OPT_MENTION_SOUND"], "highlightSound"))
    return card
end)

AddCard("messages", 30, function(page)
    local card = ns.CreateCard(page, L["SEC_EMOJIS"])
    card:AddRow(Toggle(L["OPT_ENABLE_EMOJIS"], "emojis", function(checked)
        ns.ForEachChatFrame(function(_, i)
            local eb = _G["ChatFrame" .. i .. "EditBox"]
            if eb and eb.emojiBtn then
                if checked then eb.emojiBtn:Show() else eb.emojiBtn:Hide() end
            end
        end)
        if not checked then
            local picker = _G["GudaChatEmojiPicker"]
            if picker then picker:Hide() end
        end
    end))
    card:AddRow(ns.CreateSlider(L["OPT_EMOJI_SIZE"], 10, 32, 1,
        function() return GudaChatDB.emojiSize or ns.DEFAULT_EMOJI_SIZE end,
        function(value) GudaChatDB.emojiSize = value end))
    return card
end)

---------------------------------------------------------------------------
-- Tabs & Alerts page (phase 4 adds the whisper icon card at order 40)
---------------------------------------------------------------------------

local function ShowTabBar()
    ns.RefreshChatSubTabs(ns.chatHeader)
    ns.chatSubTabs:Show()
    ns.chatSubTabs:SetAlpha(0)
end

AddCard("tabs", 10, function(page)
    local card = ns.CreateCard(page, L["SEC_TABS"])
    card:AddRow(Toggle(L["OPT_SHOW_TAB_BAR"], "showTabBar", function(checked)
        if not ns.chatSubTabs then return end
        if checked then ShowTabBar() else ns.chatSubTabs:Hide() end
    end))
    card:AddRow(Toggle(L["OPT_INLINE_TAB_BAR"], "inlineTabBar", function(checked)
        if ns.RefreshInlineTabs then ns.RefreshInlineTabs() end
        if not ns.chatSubTabs then return end
        if checked then
            ns.chatSubTabs:Hide()
        elseif GudaChatDB.showTabBar then
            ShowTabBar()
        end
    end))
    local whisperTab = Toggle(L["OPT_WHISPER_TAB"], "whisperTab", function(checked)
        if checked then
            ns.SetupWhisperFrame()
        else
            ns.ApplyWhisperRouting()
            if ns.whisperFrame and ns.whisperFrame:IsShown() then
                ns.SafeSelectDockFrame(ChatFrame1)
            end
        end
        if ns.RefreshChatSubTabs then ns.RefreshChatSubTabs() end
        if ns.RefreshInlineTabs then ns.RefreshInlineTabs() end
    end)
    ns.whisperTabCheckbox = whisperTab
    card:AddRow(whisperTab)
    return card
end)

AddCard("tabs", 20, function(page)
    local card = ns.CreateCard(page, L["SEC_TAB_BLINK"])
    card:AddRow(NotificationToggle(L["OPT_ENABLE_NOTIFICATIONS"], "general"))
    card:AddRow(NotificationToggle(L["OPT_GENERAL_TAB"], "generalTab"))
    card:AddRow(NotificationToggle(L["OPT_NOTIFY_PARTY"], "party"))
    card:AddRow(NotificationToggle(L["OPT_NOTIFY_RAID"], "raid"))
    card:AddRow(NotificationToggle(L["OPT_NOTIFY_GUILD"], "guild"))
    card:AddRow(NotificationToggle(L["OPT_NOTIFY_WHISPERS"], "whispers"))
    return card
end)

AddCard("tabs", 30, function(page)
    local card = ns.CreateCard(page, L["SEC_NUMBERED_CHANNELS"])
    card:AddRow(NotificationToggle(L["OPT_NOTIFY_TRADE"], "trade"))
    card:AddRow(NotificationToggle(L["OPT_NOTIFY_LFG"], "lfg"))
    card:AddRow(NotificationToggle(L["OPT_NOTIFY_OTHER"], "other"))
    return card
end)

---------------------------------------------------------------------------
-- History & Logs page
---------------------------------------------------------------------------

AddCard("history", 10, function(page)
    local card = ns.CreateCard(page, L["SEC_HISTORY"])
    card:AddRow(ns.CreateToggle(L["OPT_ENABLE_HISTORY"], function() return GudaChatDB.historyEnabled ~= false end, function(value)
        GudaChatDB.historyEnabled = value
        if ns.historyBtn then
            if value then ns.historyBtn:Show() else ns.historyBtn:Hide() end
        end
    end))
    card:AddRow(ns.CreateToggle(L["OPT_LOG_LOOT"], function() return GudaChatDB.logLoot ~= false end, function(value)
        GudaChatDB.logLoot = value
    end))
    card:AddRow(ns.CreateToggle(L["OPT_LOG_ADDON"], function() return GudaChatDB.logAddon ~= false end, function(value)
        GudaChatDB.logAddon = value
    end))
    return card
end)

AddCard("history", 20, function(page)
    local card = ns.CreateCard(page, L["SEC_LIMITS"])
    card:AddRow(ns.CreateSlider(L["OPT_MAX_MESSAGES"], 500, ns.HISTORY_MAX_LIMIT, 100,
        function() return GudaChatDB.historyMax or 2000 end,
        function(value) GudaChatDB.historyMax = value end))
    card:AddRow(ns.CreateSlider(L["OPT_MAX_LOOT_LOG"], LOG_CAP_MIN, LOG_CAP_MAX, LOG_CAP_STEP,
        function() return ns.LootLogCap() end,
        function(value)
            GudaChatDB.lootLogMax = value
            if GudaChatCharDB then ns.TrimLog(GudaChatCharDB.lootLog, value) end
        end))
    card:AddRow(ns.CreateSlider(L["OPT_MAX_ADDON_LOG"], LOG_CAP_MIN, LOG_CAP_MAX, LOG_CAP_STEP,
        function() return ns.AddonLogCap() end,
        function(value)
            GudaChatDB.addonLogMax = value
            if GudaChatCharDB then ns.TrimLog(GudaChatCharDB.addonLog, value) end
        end))
    card:AddRow(ns.CreateSlider(L["OPT_HISTORY_FONT_SIZE"], HISTORY_FONT_SIZE_MIN, HISTORY_FONT_SIZE_MAX, 1,
        function() return GudaChatDB.historyFontSize or 14 end,
        function(value)
            GudaChatDB.historyFontSize = value
            local histMsgFrame = _G["GudaChatHistoryMsgFrame"]
            if histMsgFrame then
                local fontPath, _, flags = histMsgFrame:GetFont()
                histMsgFrame:SetFont(fontPath, value, flags)
            end
        end))

    local buttonRow = CreateFrame("Frame")
    buttonRow:SetHeight(36)
    local clear = ns.CreateThemedButton(buttonRow, L["BTN_CLEAR_HISTORY"], function()
        StaticPopup_Show("GUDACHAT_CLEAR_HISTORY")
    end, 140)
    clear:SetPoint("LEFT", buttonRow, "LEFT", 0, 0)
    card:AddRow(buttonRow)
    return card
end)

---------------------------------------------------------------------------
-- About page
---------------------------------------------------------------------------

-- A card holding one block of wrapped text
local function TextCard(page, title, text)
    local card = ns.CreateCard(page, title)
    local row = CreateFrame("Frame")
    row.noRule = true
    local body = row:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlight")
    body:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    body:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    body:SetJustifyH("LEFT")
    body:SetText(text)
    ns.Paint(body, C.labelText)
    row:SetHeight(24)
    row:SetScript("OnSizeChanged", function(self)
        local height = math.max(20, body:GetStringHeight() + 8)
        if math.abs(self:GetHeight() - height) > 0.5 then
            self:SetHeight(height)
            card:Relayout()
            page:Relayout()
        end
    end)
    card:AddRow(row)
    return card
end

AddCard("about", 10, function(page)
    return TextCard(page, "GudaChat", L["ABOUT_TEXT"] .. "\n" .. string.format(L["ABOUT_VERSION"], AddonVersion()))
end)

AddCard("about", 20, function(page)
    return TextCard(page, L["SEC_CLIENTS"], SUPPORTED_CLIENTS)
end)

AddCard("about", 30, function(page)
    return TextCard(page, L["SEC_COMMANDS"], SLASH_COMMANDS)
end)

---------------------------------------------------------------------------
-- Window, sidebar and pages
---------------------------------------------------------------------------

local settingsFrame

-- A page: its heading and its cards stacked top to bottom. page:Relayout() restacks the
-- cards and, while the page is shown, sizes the scroll child to it.
local PAGE_HEADING_HEIGHT = 24
local SCROLL_GUTTER = 6

local function BuildPage(scroll, def)
    local page = CreateFrame("Frame", nil, scroll.child)
    page:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, 0)
    page:SetPoint("RIGHT", scroll.child, "RIGHT", 0, 0)
    page.cards = {}

    function page:Relayout()
        local y = PAGE_PADDING + PAGE_HEADING_HEIGHT
        for _, card in ipairs(self.cards) do
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", self, "TOPLEFT", PAGE_PADDING, -y)
            card:SetPoint("RIGHT", self, "RIGHT", -PAGE_PADDING - SCROLL_GUTTER, 0)
            y = y + card:GetHeight() + CARD_GAP
        end
        self:SetHeight(y + PAGE_PADDING)
        if self:IsShown() then
            scroll.child:SetHeight(self:GetHeight())
            scroll.UpdateThumb()
        end
    end

    local heading = page:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlight")
    heading:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_PADDING, -PAGE_PADDING)
    heading:SetText(def.label)
    ns.Paint(heading, C.heading)

    local builders = cardBuilders[def.key] or {}
    table.sort(builders, function(a, b) return a.order < b.order end)
    for _, entry in ipairs(builders) do
        local card = entry.build(page)
        if card then tinsert(page.cards, card) end
    end

    page:Relayout()
    page:Hide()
    return page
end

-- One sidebar entry: icon and label, a left bar and background on the selected page
local function CreateNavButton(parent, def, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(NAV_HEIGHT)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    local bar = btn:CreateTexture(nil, "ARTWORK")
    bar:SetTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetWidth(2)
    bar:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", btn, "LEFT", 12, 0)
    icon:SetTexture(ns.ASSET_PATH .. def.icon)

    local text = btn:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlight")
    text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    text:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(def.label)

    function btn.Refresh(selected)
        btn.selected = selected
        local hover = btn:IsMouseOver()
        local textEntry = (selected or hover) and C.navActiveText or C.navText
        text:SetTextColor(textEntry[1], textEntry[2], textEntry[3], textEntry[4])
        local bgEntry = selected and C.navActiveBg or C.navHover
        bg:SetVertexColor(bgEntry[1], bgEntry[2], bgEntry[3], bgEntry[4])
        bg:SetShown(selected or hover)
        bar:SetVertexColor(C.navBar[1], C.navBar[2], C.navBar[3], C.navBar[4])
        bar:SetShown(selected)
        icon:SetAlpha((selected or hover) and 1 or 0.65)
    end

    btn:SetScript("OnClick", onClick)
    btn:SetScript("OnEnter", function(self) self.Refresh(self.selected) end)
    btn:SetScript("OnLeave", function(self) self.Refresh(self.selected) end)
    return btn
end

local function CreateSettingsFrame()
    local f = ns.CreateThemedWindow("GudaChatSettingsPopup", WINDOW_WIDTH, WINDOW_HEIGHT, "GudaChat", {
        icon = ns.ASSET_PATH .. "logo.png",
        version = AddonVersion(),
        positionKey = "settingsPosition",
    })

    local sidebar = CreateFrame("Frame", nil, f)
    sidebar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -ns.WINDOW_TITLE_HEIGHT)
    sidebar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(SIDEBAR_WIDTH)
    local divider = sidebar:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\Buttons\\WHITE8x8")
    divider:SetWidth(1)
    divider:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
    divider:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 1)
    ns.Paint(divider, C.rowRule)

    local credit = sidebar:CreateFontString(nil, "OVERLAY", "GudaChatFontDisableSmall")
    credit:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 14, 12)
    credit:SetText("by Guda")
    ns.Paint(credit, C.dimText)

    local scroll = ns.CreateScrollArea(f)
    scroll:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 1, -1)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)

    local pages, navButtons = {}, {}
    local current

    local function SelectPage(index)
        current = index
        for i, page in ipairs(pages) do
            page:SetShown(i == index)
            navButtons[i].Refresh(i == index)
        end
        scroll.child:SetHeight(pages[index]:GetHeight())
        scroll:SetVerticalScroll(0)
        scroll.UpdateThumb()
    end
    f.SelectPage = SelectPage

    for i, def in ipairs(PAGES) do
        local nav = CreateNavButton(sidebar, def, function() SelectPage(i) end)
        nav:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 6, -8 - (i - 1) * (NAV_HEIGHT + 2))
        nav:SetPoint("RIGHT", sidebar, "RIGHT", -6, 0)
        navButtons[i] = nav
    end
    for i, def in ipairs(PAGES) do
        pages[i] = BuildPage(scroll, def)
    end

    ns.OnRestyle(function()
        for i, nav in ipairs(navButtons) do nav.Refresh(i == current) end
    end)

    f:SetScript("OnHide", ns.CloseSettingsDropdown)
    SelectPage(1)
    return f
end

local function ToggleSettings()
    if not settingsFrame then
        settingsFrame = CreateSettingsFrame()
        ns.settingsFrame = settingsFrame
    end
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
    end
end
ns.ToggleSettings = ToggleSettings
