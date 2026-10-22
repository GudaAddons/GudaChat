local addonName, ns = ...

---------------------------------------------------------------------------
-- Themes
--
-- Every UI colour GudaChat draws comes from one palette, ns.Theme.C. Each entry is a
-- {r, g, b, a} table that is filled in place from the active theme, so code that keeps
-- a reference (unpack(C.iconHover)) always reads the current colour. Frames and
-- textures styled through ns.ApplyDarkBackdrop / ns.Paint are remembered (weak keys)
-- and restyled when the theme or accent changes, so switching needs no /reload.
--
-- Theme tables are plain data (colours, backdrop styles, font file) so the other Guda
-- addons can reuse the format. Colour values may be { accent = true, a = alpha }: the
-- accent is the player's class colour or a custom colour (GudaChatDB.accent), and only
-- themes with usesAccent take it; the others keep their gold.
---------------------------------------------------------------------------

local Theme = {}
ns.Theme = Theme

local TEXTURE_PATH = "Interface\\AddOns\\GudaChat\\Assets\\Theme\\"
local FIRA_FONT = "Interface\\AddOns\\GudaChat\\Assets\\Fonts\\FiraSans-Medium.ttf"
local WHITE = "Interface\\Buttons\\WHITE8x8"

-- Clients whose own letters FiraSans lacks; their themes keep the game's font
local NO_FIRA_LOCALE = { zhCN = true, zhTW = true, koKR = true }

local DEFAULT_THEME = "modern"
local LEGACY_THEME = "classic"

local function Accent(alpha)
    return { accent = true, a = alpha }
end

-- Blizzard: FrameXML's own palette. NORMAL_FONT_COLOR gold (1, 0.82, 0), tooltip
-- background (0.09, 0.09, 0.19), grey tooltip edges, the dialog box art for popups,
-- the red panel button left untinted, and a blue-white list highlight.
local BLIZZARD_GOLD = { 1, 0.82, 0, 1 }
local BLIZZARD_GOLD_DIM = { 0.7, 0.6, 0.35, 0.9 }
local BLIZZARD_TOOLTIP_BG = { 0.09, 0.09, 0.19, 0.92 }
local BLIZZARD_EDGE = { 0.65, 0.65, 0.65, 1 }
local BLIZZARD_HIGHLIGHT = { 0.48, 0.64, 1, 0.18 }

local MODERN_TEXT = { 0.91, 0.92, 0.94, 1 }
local MODERN_DIM = { 0.55, 0.58, 0.64, 1 }

Theme.THEMES = {
    classic = {
        tabStyle = "chatType",
        chatBg = { r = 0.08, g = 0.08, b = 0.08, a = 0 },
        colors = {
            panelBg = { 0.08, 0.08, 0.08, 0.95 },
            panelBorder = { 0.3, 0.3, 0.3, 0.6 },
            accentBorder = { 0.8, 0.6, 0.0, 0.8 },
            copyBg = { 0.1, 0.1, 0.1, 0.95 },
            headerBg = { 0.05, 0.05, 0.05, 0.85 },
            headerBorder = { 0.25, 0.25, 0.25, 0.5 },
            barBg = { 0.05, 0.05, 0.05, 0.75 },
            barBorder = { 0.25, 0.25, 0.25, 0.5 },
            pickerBg = { 0.08, 0.08, 0.08, 0.95 },
            pickerBorder = { 0.3, 0.3, 0.3, 0.8 },
            iconNormal = { 0.7, 0.7, 0.7, 0.9 },
            iconHover = { 1, 1, 1, 1 },
            iconActive = { 1, 1, 1, 1 },
            iconInactive = { 0.7, 0.7, 0.7, 0.9 },
            iconDim = { 0.6, 0.6, 0.6, 1 },
            menuTitle = { 0.9, 0.75, 0.3, 1 },
            menuArrow = { 0.7, 0.7, 0.7, 1 },
            menuHover = { 1, 1, 1, 0.1 },
            pickerHover = { 1, 1, 1, 0.15 },
            dimText = { 0.6, 0.6, 0.6, 1 },
            editText = { 0.9, 0.9, 0.9, 1 },
            bodyText = { 1, 1, 1, 1 },
            tabLabel = { 0.6, 0.45, 0.0, 0.8 },
            tabLabelHover = { 1, 0.8, 0, 1 },
            chatTypeLabel = { 0.8, 0.8, 0.8, 1 },
            chatTypeLabelHover = { 1, 0.8, 0, 1 },
            chatTypeCmd = { 0.5, 0.5, 0.5, 1 },
            chatTypeCmdHover = { 0.8, 0.6, 0, 1 },
            subtabActive = { 1, 1, 1, 1 },
            subtabInactive = { 0.5, 0.5, 0.5, 0.8 },
            subtabHover = { 0.9, 0.9, 0.9, 1 },
            dragIndicator = { 0.8, 0.6, 0.0, 1 },
            scrollTrack = { 0, 0, 0, 0.3 },
            scrollThumb = { 1, 1, 1, 0.4 },
            scrollThumbHover = { 1, 1, 1, 0.7 },
            scrollDownBg = { 0.08, 0.08, 0.08, 0.8 },
            scrollDownBgHover = { 0.12, 0.12, 0.12, 0.9 },
            scrollDownIcon = { 0.8, 0.6, 0, 0.9 },
            scrollDownIconHover = { 1, 0.8, 0, 1 },
            swatchBorder = { 0.5, 0.5, 0.5, 0.8 },
            separatorText = { 0.9, 0.75, 0.3, 1 },
            separatorLine = { 0.5, 0.5, 0.5, 0.5 },
            dangerButton = { 0.6, 0.1, 0.1, 1 },
            dangerButtonPushed = { 0.5, 0.05, 0.05, 1 },
            tabActive = { 1, 1, 1, 1 },
            tabInactive = { 0.5, 0.5, 0.5, 0.8 },
            tabHover = { 1, 1, 1, 1 },
            tabUnderline = { 0, 0, 0, 0 },
            windowBg = { 0.08, 0.08, 0.08, 0.95 },
            windowBorder = { 0.3, 0.3, 0.3, 0.6 },
            heading = { 0.9, 0.75, 0.3, 1 },
            cardBg = { 1, 1, 1, 0.03 },
            cardBorder = { 0.25, 0.25, 0.25, 0.5 },
            cardTitle = { 0.9, 0.75, 0.3, 1 },
            labelText = { 0.9, 0.9, 0.9, 1 },
            navText = { 0.6, 0.6, 0.6, 1 },
            navActiveText = { 1, 1, 1, 1 },
            navActiveBg = { 0.8, 0.6, 0, 0.12 },
            navBar = { 0.8, 0.6, 0, 1 },
            navHover = { 1, 1, 1, 0.05 },
            rowRule = { 0.25, 0.25, 0.25, 0.5 },
            controlOff = { 0.1, 0.1, 0.1, 1 },
            controlOn = { 0.8, 0.6, 0, 1 },
            controlBorder = { 0.33, 0.33, 0.33, 1 },
            checkMark = { 1, 0.82, 0, 1 },
            fieldBg = { 0.05, 0.05, 0.05, 0.85 },
            buttonText = { 0.9, 0.9, 0.9, 1 },
            badgeBg = { 0.8, 0.6, 0, 1 },
            badgeText = { 0, 0, 0, 1 },
        },
    },

    modern = {
        usesAccent = true,
        rounded = true,
        switches = true,
        uiFont = FIRA_FONT,
        tabStyle = "plain",
        tabUnderline = true,
        chatBg = { r = 0.05, g = 0.05, b = 0.07, a = 0.35 },
        colors = {
            panelBg = { 0.067, 0.071, 0.09, 0.94 },
            panelBorder = { 1, 1, 1, 0.09 },
            accentBorder = Accent(0.8),
            copyBg = { 0.067, 0.071, 0.09, 0.96 },
            headerBg = { 0.047, 0.051, 0.067, 0.82 },
            headerBorder = { 1, 1, 1, 0.07 },
            barBg = { 0.047, 0.051, 0.067, 0.78 },
            barBorder = { 1, 1, 1, 0.06 },
            pickerBg = { 0.067, 0.071, 0.09, 0.94 },
            pickerBorder = { 1, 1, 1, 0.09 },
            iconNormal = { 0.62, 0.65, 0.71, 0.9 },
            iconHover = { 1, 1, 1, 1 },
            iconActive = Accent(1),
            iconInactive = { 0.62, 0.65, 0.71, 0.9 },
            iconDim = MODERN_DIM,
            menuTitle = Accent(1),
            menuArrow = MODERN_DIM,
            menuHover = Accent(0.16),
            pickerHover = Accent(0.2),
            dimText = MODERN_DIM,
            editText = MODERN_TEXT,
            bodyText = MODERN_TEXT,
            tabLabel = Accent(0.85),
            tabLabelHover = Accent(1),
            chatTypeLabel = { 0.85, 0.86, 0.9, 1 },
            chatTypeLabelHover = Accent(1),
            chatTypeCmd = MODERN_DIM,
            chatTypeCmdHover = Accent(0.8),
            subtabActive = MODERN_TEXT,
            subtabInactive = MODERN_DIM,
            subtabHover = { 1, 1, 1, 1 },
            dragIndicator = Accent(1),
            scrollTrack = { 0, 0, 0, 0.3 },
            scrollThumb = Accent(0.55),
            scrollThumbHover = Accent(0.85),
            scrollDownBg = { 0.067, 0.071, 0.09, 0.85 },
            scrollDownBgHover = { 0.1, 0.105, 0.13, 0.92 },
            scrollDownIcon = Accent(0.9),
            scrollDownIconHover = Accent(1),
            swatchBorder = { 1, 1, 1, 0.15 },
            separatorText = Accent(1),
            separatorLine = { 1, 1, 1, 0.06 },
            dangerButton = { 0.55, 0.16, 0.16, 1 },
            dangerButtonPushed = { 0.45, 0.12, 0.12, 1 },
            tabActive = MODERN_TEXT,
            tabInactive = MODERN_DIM,
            tabHover = { 1, 1, 1, 1 },
            tabUnderline = Accent(1),
            windowBg = { 0.067, 0.071, 0.09, 0.96 },
            windowBorder = { 1, 1, 1, 0.09 },
            heading = { 1, 1, 1, 1 },
            cardBg = { 1, 1, 1, 0.045 },
            cardBorder = { 1, 1, 1, 0.06 },
            cardTitle = Accent(1),
            labelText = MODERN_TEXT,
            navText = MODERN_DIM,
            navActiveText = MODERN_TEXT,
            navActiveBg = Accent(0.12),
            navBar = Accent(1),
            navHover = { 1, 1, 1, 0.045 },
            rowRule = { 1, 1, 1, 0.06 },
            controlOff = { 0.17, 0.18, 0.23, 1 },
            controlOn = Accent(1),
            controlBorder = { 1, 1, 1, 0.12 },
            checkMark = { 1, 1, 1, 1 },
            fieldBg = { 0.047, 0.051, 0.067, 0.9 },
            buttonText = MODERN_TEXT,
            badgeBg = Accent(1),
            badgeText = { 0.07, 0.07, 0.09, 1 },
        },
    },

    blizzard = {
        blizzardArt = true,
        tabStyle = "plain",
        chatBg = { r = 0, g = 0, b = 0, a = 0.35 },
        colors = {
            panelBg = BLIZZARD_TOOLTIP_BG,
            panelBorder = BLIZZARD_EDGE,
            accentBorder = BLIZZARD_GOLD,
            copyBg = { 1, 1, 1, 0.95 },
            headerBg = BLIZZARD_TOOLTIP_BG,
            headerBorder = BLIZZARD_EDGE,
            barBg = BLIZZARD_TOOLTIP_BG,
            barBorder = BLIZZARD_EDGE,
            pickerBg = { 1, 1, 1, 0.95 },
            pickerBorder = { 1, 1, 1, 1 },
            iconNormal = { 0.85, 0.85, 0.85, 0.9 },
            iconHover = { 1, 1, 1, 1 },
            iconActive = BLIZZARD_GOLD,
            iconInactive = { 0.85, 0.85, 0.85, 0.9 },
            iconDim = { 0.75, 0.75, 0.75, 1 },
            menuTitle = BLIZZARD_GOLD,
            menuArrow = BLIZZARD_GOLD,
            menuHover = BLIZZARD_HIGHLIGHT,
            pickerHover = BLIZZARD_HIGHLIGHT,
            dimText = { 0.5, 0.5, 0.5, 1 },
            editText = { 1, 1, 1, 1 },
            bodyText = { 1, 1, 1, 1 },
            tabLabel = BLIZZARD_GOLD,
            tabLabelHover = { 1, 1, 1, 1 },
            chatTypeLabel = BLIZZARD_GOLD,
            chatTypeLabelHover = { 1, 1, 1, 1 },
            chatTypeCmd = { 0.5, 0.5, 0.5, 1 },
            chatTypeCmdHover = { 0.85, 0.85, 0.85, 1 },
            subtabActive = BLIZZARD_GOLD,
            subtabInactive = BLIZZARD_GOLD_DIM,
            subtabHover = { 1, 1, 1, 1 },
            dragIndicator = BLIZZARD_GOLD,
            scrollTrack = { 0, 0, 0, 0.4 },
            scrollThumb = { 1, 0.82, 0, 0.5 },
            scrollThumbHover = { 1, 0.82, 0, 0.85 },
            scrollDownBg = BLIZZARD_TOOLTIP_BG,
            scrollDownBgHover = { 0.14, 0.14, 0.28, 0.95 },
            scrollDownIcon = BLIZZARD_GOLD,
            scrollDownIconHover = { 1, 1, 1, 1 },
            swatchBorder = { 0.6, 0.6, 0.6, 1 },
            separatorText = BLIZZARD_GOLD,
            separatorLine = { 1, 0.82, 0, 0.22 },
            dangerButton = { 1, 1, 1, 1 },
            dangerButtonPushed = { 1, 1, 1, 1 },
            tabActive = BLIZZARD_GOLD,
            tabInactive = BLIZZARD_GOLD_DIM,
            tabHover = { 1, 1, 1, 1 },
            tabUnderline = { 0, 0, 0, 0 },
            windowBg = { 1, 1, 1, 0.95 },
            windowBorder = { 1, 1, 1, 1 },
            heading = BLIZZARD_GOLD,
            cardBg = { 0, 0, 0, 0.35 },
            cardBorder = { 0.35, 0.35, 0.35, 1 },
            cardTitle = BLIZZARD_GOLD,
            labelText = { 1, 1, 1, 1 },
            navText = BLIZZARD_GOLD,
            navActiveText = { 1, 1, 1, 1 },
            navActiveBg = BLIZZARD_HIGHLIGHT,
            navBar = { 0, 0, 0, 0 },
            navHover = { 0.48, 0.64, 1, 0.12 },
            rowRule = { 1, 1, 1, 0.06 },
            controlOff = { 0, 0, 0, 1 },
            controlOn = BLIZZARD_GOLD,
            controlBorder = { 0.54, 0.54, 0.54, 1 },
            checkMark = BLIZZARD_GOLD,
            fieldBg = { 0, 0, 0, 0.9 },
            buttonText = BLIZZARD_GOLD,
            badgeBg = { 0.56, 0.1, 0.06, 1 },
            badgeText = BLIZZARD_GOLD,
        },
    },
}

Theme.ORDER = { "classic", "modern", "blizzard" }

-- Backdrop styles. Classic is GudaChat 1.x's flat 1px frame. Blizzard uses the game's own
-- art by path (present since Vanilla, nothing shipped): tooltip edges for bars and menus,
-- the dialog box for popups.
local BACKDROP_FLAT_EDGE = {
    bgFile = WHITE,
    edgeFile = WHITE,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local BACKDROP_BLIZZARD_TOOLTIP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local BACKDROP_BLIZZARD_DIALOG = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

-- Palette entries whose panels count as popups (Blizzard dialog art instead of tooltip art)
local POPUP_BACKGROUNDS = { copyBg = true, pickerBg = true, windowBg = true }

local C = {}
Theme.C = C
for name in pairs(Theme.THEMES.classic.colors) do
    C[name] = { 1, 1, 1, 1 }
end
local paletteName = {}
for name, entry in pairs(C) do
    paletteName[entry] = name
end

Theme.chatBg = { r = 0.08, g = 0.08, b = 0.08, a = 0 }

local current = Theme.THEMES.classic
local currentName = LEGACY_THEME
local accentColor = { 1, 0.82, 0 }

local panels = setmetatable({}, { __mode = "k" })
local painted = setmetatable({}, { __mode = "k" })
local listeners = {}

local function PlayerClassColor()
    local _, class = UnitClass("player")
    if not class then return nil end
    if C_ClassColor and C_ClassColor.GetClassColor then
        local c = C_ClassColor.GetClassColor(class)
        if c then return c.r, c.g, c.b end
    end
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return nil
end

-- The accent as r, g, b: GudaChatDB.accent is "class" (the default) or a {r, g, b} table
function Theme.ResolveAccent(setting)
    if type(setting) == "table" and setting.r then
        return setting.r, setting.g, setting.b
    end
    local r, g, b = PlayerClassColor()
    if r then return r, g, b end
    return 1, 0.82, 0
end

local function FillEntry(entry, value)
    if value.accent then
        entry[1], entry[2], entry[3], entry[4] = accentColor[1], accentColor[2], accentColor[3], value.a or 1
    else
        entry[1], entry[2], entry[3], entry[4] = value[1], value[2], value[3], value[4] or 1
    end
end

local function FillPalette()
    for name, entry in pairs(C) do
        FillEntry(entry, current.colors[name] or Theme.THEMES.classic.colors[name])
    end
    local bg = current.chatBg
    Theme.chatBg.r, Theme.chatBg.g, Theme.chatBg.b, Theme.chatBg.a = bg.r, bg.g, bg.b, bg.a
end

---------------------------------------------------------------------------
-- Rounded panels (Modern Dark)
---------------------------------------------------------------------------

-- Fraction of each source texture taken by one corner, and the corner size on screen
local ROUNDED_CORNER_FRACTION = 0.25
local ROUNDED_CORNER = 6
local SHADOW_CORNER_FRACTION = 0.375
local SHADOW_CORNER = 12
local SHADOW_OUTSET = 6
local SHADOW_ALPHA = 0.55

-- Nine textures (corners, edges, centre) cut from one texture and stretched around frame
local function CreateSlices(frame, layer, sublevel)
    local slices = {}
    for i = 1, 9 do
        slices[i] = frame:CreateTexture(nil, layer, nil, sublevel)
    end
    return slices
end

local function LayoutSlices(slices, frame, file, fraction, corner, outset)
    local f, g = fraction, 1 - fraction
    local tl, t, tr, l, c, r, bl, b, br = unpack(slices)
    for _, tex in ipairs(slices) do
        tex:SetTexture(file)
        tex:ClearAllPoints()
    end
    tl:SetSize(corner, corner)
    tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset, outset)
    tl:SetTexCoord(0, f, 0, f)
    tr:SetSize(corner, corner)
    tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", outset, outset)
    tr:SetTexCoord(g, 1, 0, f)
    bl:SetSize(corner, corner)
    bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -outset, -outset)
    bl:SetTexCoord(0, f, g, 1)
    br:SetSize(corner, corner)
    br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset, -outset)
    br:SetTexCoord(g, 1, g, 1)
    t:SetPoint("TOPLEFT", tl, "TOPRIGHT")
    t:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    t:SetTexCoord(f, g, 0, f)
    b:SetPoint("TOPLEFT", bl, "TOPRIGHT")
    b:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    b:SetTexCoord(f, g, g, 1)
    l:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
    l:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    l:SetTexCoord(0, f, f, g)
    r:SetPoint("TOPLEFT", tr, "BOTTOMLEFT")
    r:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    r:SetTexCoord(g, 1, f, g)
    c:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT")
    c:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
    c:SetTexCoord(f, g, f, g)
end

local function TintSlices(slices, r, g, b, a)
    for _, tex in ipairs(slices) do
        tex:SetVertexColor(r, g, b, a)
    end
end

local function ShowSlices(slices, shown)
    for _, tex in ipairs(slices) do
        tex:SetShown(shown)
    end
end

local function EnsureRounded(frame)
    local rounded = frame.gudaRounded
    if rounded then return rounded end
    rounded = {
        shadow = CreateSlices(frame, "BACKGROUND", -8),
        fill = CreateSlices(frame, "BACKGROUND", -7),
        border = CreateSlices(frame, "BORDER", -8),
    }
    LayoutSlices(rounded.shadow, frame, TEXTURE_PATH .. "shadow.png", SHADOW_CORNER_FRACTION, SHADOW_CORNER, SHADOW_OUTSET)
    LayoutSlices(rounded.fill, frame, TEXTURE_PATH .. "rounded.png", ROUNDED_CORNER_FRACTION, ROUNDED_CORNER, 0)
    LayoutSlices(rounded.border, frame, TEXTURE_PATH .. "rounded-border.png", ROUNDED_CORNER_FRACTION, ROUNDED_CORNER, 0)
    frame.gudaRounded = rounded
    return rounded
end

local function HideRounded(frame)
    local rounded = frame.gudaRounded
    if not rounded then return end
    ShowSlices(rounded.shadow, false)
    ShowSlices(rounded.fill, false)
    ShowSlices(rounded.border, false)
end

---------------------------------------------------------------------------
-- Panels and painted regions
---------------------------------------------------------------------------

local function BackdropFor(bgEntry)
    if current.blizzardArt then
        return POPUP_BACKGROUNDS[paletteName[bgEntry]] and BACKDROP_BLIZZARD_DIALOG or BACKDROP_BLIZZARD_TOOLTIP
    end
    return BACKDROP_FLAT_EDGE
end

local function StylePanel(frame, state)
    local bg, border = state.bg, state.border
    if current.rounded then
        if frame.SetBackdrop then frame:SetBackdrop(nil) end
        local rounded = EnsureRounded(frame)
        ShowSlices(rounded.shadow, not state.noShadow)
        ShowSlices(rounded.fill, true)
        ShowSlices(rounded.border, true)
        TintSlices(rounded.shadow, 0, 0, 0, SHADOW_ALPHA)
        TintSlices(rounded.fill, bg[1], bg[2], bg[3], bg[4])
        TintSlices(rounded.border, border[1], border[2], border[3], border[4])
        return
    end
    HideRounded(frame)
    frame:SetBackdrop(BackdropFor(bg))
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

-- Styles frame as a panel with palette entries for its background and border (defaults:
-- the menu panel colours) and keeps it themed. The frame must use BackdropTemplate.
-- noShadow leaves out the Modern Dark drop shadow (for panels drawn inside others).
local function ApplyDarkBackdrop(frame, bgEntry, borderEntry, noShadow)
    local state = panels[frame] or {}
    state.bg = bgEntry or C.panelBg
    state.border = borderEntry or C.panelBorder
    state.noShadow = noShadow
    panels[frame] = state
    StylePanel(frame, state)
end
ns.ApplyDarkBackdrop = ApplyDarkBackdrop
Theme.ApplyPanel = ApplyDarkBackdrop

-- Changes only the border of a themed panel (for example gold on focus)
local function SetPanelBorder(frame, borderEntry)
    local state = panels[frame]
    if not state then
        ApplyDarkBackdrop(frame, nil, borderEntry)
        return
    end
    state.border = borderEntry
    StylePanel(frame, state)
end
ns.SetPanelBorder = SetPanelBorder

-- Colours a FontString or EditBox (text), a Texture (vertex colour) or a backdrop frame
-- (backdrop colour) with a palette entry and keeps it themed; the last entry painted is
-- the one restored after a theme change
local function Paint(region, entry)
    painted[region] = entry
    if region.SetTextColor then
        region:SetTextColor(entry[1], entry[2], entry[3], entry[4])
    elseif region.SetVertexColor then
        region:SetVertexColor(entry[1], entry[2], entry[3], entry[4])
    else
        region:SetBackdropColor(entry[1], entry[2], entry[3], entry[4])
    end
end
ns.Paint = Paint

-- Colours tab text. "chatType" themes (Classic) use the tab's chat colour, dimmed when
-- inactive; "plain" themes use the palette's tab colours. state: active, inactive,
-- hover or drag.
local TAB_DIM = { inactive = { 0.5, 0.8 }, drag = { 0.3, 0.5 } }

function Theme.PaintTab(text, col, state)
    if current.tabStyle == "chatType" then
        local dim = TAB_DIM[state]
        if dim then
            text:SetTextColor(col[1] * dim[1], col[2] * dim[1], col[3] * dim[1], dim[2])
        else
            text:SetTextColor(col[1], col[2], col[3], 1)
        end
        return
    end
    local entry = (state == "active" and C.tabActive) or (state == "hover" and C.tabHover) or C.tabInactive
    local alpha = state == "drag" and entry[4] * 0.5 or entry[4]
    text:SetTextColor(entry[1], entry[2], entry[3], alpha)
end

-- True when the active theme marks the selected tab with an accent underline
function Theme.HasTabUnderline()
    return current.tabUnderline == true
end

-- True when the active theme draws on/off settings as switches (Modern Dark); the
-- others use square Blizzard-style checkboxes
function Theme.UsesSwitches()
    return current.switches == true
end

-- True when the active theme uses the game's own frame art (red panel buttons and so on)
function Theme.UsesBlizzardArt()
    return current.blizzardArt == true
end

-- True when the active theme takes the accent colour (the others keep their gold)
function Theme.UsesAccent()
    return current.usesAccent == true
end

-- A palette colour of any theme as r, g, b, a, accent included, without switching to it.
-- The settings window draws its theme thumbnails with this.
function Theme.ColorOf(name, token)
    local theme = Theme.THEMES[name] or current
    local value = theme.colors[token] or Theme.THEMES.classic.colors[token]
    if value.accent then
        local r, g, b = Theme.ResolveAccent(GudaChatDB and GudaChatDB.accent)
        return r, g, b, value.a or 1
    end
    return value[1], value[2], value[3], value[4] or 1
end

---------------------------------------------------------------------------
-- Fonts
---------------------------------------------------------------------------

-- GudaChat's own font objects, copies of the game's. Themes with a uiFont swap the font
-- file; the game's colours and sizes stay. FontStrings created from these follow live.
local FONT_OBJECTS = {
    { name = "GudaChatFontNormalSmall", source = "GameFontNormalSmall" },
    { name = "GudaChatFontHighlightSmall", source = "GameFontHighlightSmall" },
    { name = "GudaChatFontHighlight", source = "GameFontHighlight" },
    { name = "GudaChatFontDisableSmall", source = "GameFontDisableSmall" },
}

local function UpdateFonts()
    local useFont = current.uiFont and not NO_FIRA_LOCALE[GetLocale()]
    for _, def in ipairs(FONT_OBJECTS) do
        local font = _G[def.name] or (CreateFont and CreateFont(def.name))
        local source = _G[def.source]
        if font and source then
            font:CopyFontObject(source)
            if useFont then
                local _, size, flags = font:GetFont()
                font:SetFont(current.uiFont, size or 12, flags or "")
            end
        end
    end
end

---------------------------------------------------------------------------
-- Switching
---------------------------------------------------------------------------

-- Runs fn() after every theme or accent change (after panels and painted regions are
-- restyled), for UI that rebuilds itself, such as the tab strips
function Theme.OnChange(fn)
    tinsert(listeners, fn)
end

local function Refresh()
    if current.usesAccent then
        accentColor[1], accentColor[2], accentColor[3] = Theme.ResolveAccent(GudaChatDB and GudaChatDB.accent)
    end
    FillPalette()
    UpdateFonts()
    for frame, state in pairs(panels) do
        StylePanel(frame, state)
    end
    for region, entry in pairs(painted) do
        Paint(region, entry)
    end
    for _, fn in ipairs(listeners) do
        fn()
    end
end
Theme.Refresh = Refresh

function Theme.Current()
    return currentName
end

function Theme.Set(name)
    if not Theme.THEMES[name] then name = DEFAULT_THEME end
    currentName = name
    current = Theme.THEMES[name]
    if GudaChatDB then GudaChatDB.theme = name end
    Refresh()
end

-- setting: "class" or {r, g, b}
function Theme.SetAccent(setting)
    if GudaChatDB then GudaChatDB.accent = setting end
    Refresh()
end

-- The theme a profile starts with: fresh installs get Modern Dark, profiles saved by
-- GudaChat 1.x (no theme field yet) keep the 1.x look
function Theme.DefaultFor(isFreshInstall)
    return isFreshInstall and DEFAULT_THEME or LEGACY_THEME
end

-- Called once GudaChatDB exists. Fills the theme and accent defaults, then applies.
function Theme.Init(isFreshInstall)
    if GudaChatDB.theme == nil or not Theme.THEMES[GudaChatDB.theme] then
        GudaChatDB.theme = Theme.DefaultFor(isFreshInstall)
    end
    if GudaChatDB.accent == nil then
        GudaChatDB.accent = "class"
    end
    Theme.Set(GudaChatDB.theme)
end

FillPalette()
UpdateFonts()

ns.COLOR_DARK_BG = C.panelBg
ns.COLOR_DARK_BORDER = C.panelBorder
ns.COLOR_GOLDEN_A = C.accentBorder
ns.COLOR_COPY_BG = C.copyBg
ns.COLOR_HEADER_BG = C.headerBg
ns.COLOR_HEADER_BORDER = C.headerBorder
