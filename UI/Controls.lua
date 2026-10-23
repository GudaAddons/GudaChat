local addonName, ns = ...

---------------------------------------------------------------------------
-- Themed controls for the settings and history windows: the window frame, cards,
-- switches / checkboxes, sliders with an editable value, dropdowns on GudaChat's own
-- menu, colour swatches, buttons and text tabs. Everything paints from the theme
-- palette and restyles itself live when the theme or accent changes; nothing here
-- runs per frame unless the mouse is dragging a slider.
---------------------------------------------------------------------------

local C = ns.Theme.C
local WHITE = "Interface\\Buttons\\WHITE8x8"
local ROUNDED = "Interface\\AddOns\\GudaChat\\Assets\\Theme\\rounded.png"
local CHECK_TEXTURE = "Interface\\Buttons\\UI-CheckBox-Check"

-- The red panel button art every client ships, cut to the button part of the texture
local PANEL_BUTTON_UP = "Interface\\Buttons\\UI-Panel-Button-Up"
local PANEL_BUTTON_DOWN = "Interface\\Buttons\\UI-Panel-Button-Down"
local PANEL_BUTTON_HIGHLIGHT = "Interface\\Buttons\\UI-Panel-Button-Highlight"
local PANEL_BUTTON_COORDS = { 0, 0.625, 0, 0.6875 }

local TITLE_HEIGHT = 34
local ROW_HEIGHT = 28
local HINT_HEIGHT = 12
local CARD_PADDING = 12
local CARD_TITLE_HEIGHT = 26
local SWITCH_WIDTH, SWITCH_HEIGHT, KNOB_SIZE = 32, 16, 12
local CHECK_SIZE = 16
local SLIDER_TRACK_WIDTH = 140
local VALUE_BOX_WIDTH = 46
local DROPDOWN_WIDTH = 170
local DROPDOWN_ITEM_HEIGHT = 20
local SWATCH_WIDTH, SWATCH_HEIGHT = 26, 16

ns.SETTINGS_ROW_HEIGHT = ROW_HEIGHT
ns.WINDOW_TITLE_HEIGHT = TITLE_HEIGHT

local restylers = {}

-- Runs fn now and after every theme or accent change
local function OnRestyle(fn)
    tinsert(restylers, fn)
    fn()
end
ns.OnRestyle = OnRestyle

ns.Theme.OnChange(function()
    for _, fn in ipairs(restylers) do
        fn()
    end
end)

local function NewTexture(parent, layer, entry)
    local tex = parent:CreateTexture(nil, layer)
    tex:SetTexture(WHITE)
    if entry then ns.Paint(tex, entry) end
    return tex
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

-- Restores a window to the position saved under GudaChatDB[key], or centres it
local function RestorePosition(frame, key)
    frame:ClearAllPoints()
    local pos = key and GudaChatDB and GudaChatDB[key]
    if type(pos) == "table" and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        frame:SetPoint("CENTER")
    end
end

local function SavePosition(frame, key)
    if not key or not GudaChatDB then return end
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if point then
        GudaChatDB[key] = { point = point, relPoint = relPoint, x = x, y = y }
    end
end

-- A themed, movable window: title bar with optional icon, title, small version text and
-- close button. Closes on Escape and on entering combat; dragged by its title bar. With
-- opts.positionKey the position is saved in GudaChatDB and restored on creation.
local function CreateThemedWindow(name, width, height, title, opts)
    opts = opts or {}
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(width, height)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    ns.ApplyDarkBackdrop(f, C.windowBg, C.windowBorder)
    RestorePosition(f, opts.positionKey)

    tinsert(UISpecialFrames, name)
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:SetScript("OnEvent", function(self) self:Hide() end)

    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    bar:SetHeight(TITLE_HEIGHT)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() f:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        f:SetUserPlaced(false)
        SavePosition(f, opts.positionKey)
    end)

    local left = 12
    if opts.icon then
        local icon = bar:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT", bar, "LEFT", left, 0)
        icon:SetTexture(opts.icon)
        left = left + 24
    end

    local titleText = bar:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlight")
    titleText:SetPoint("LEFT", bar, "LEFT", left, 0)
    titleText:SetText(title)
    ns.Paint(titleText, C.heading)
    f.titleText = titleText

    if opts.version then
        local version = bar:CreateFontString(nil, "OVERLAY", "GudaChatFontDisableSmall")
        version:SetPoint("LEFT", titleText, "RIGHT", 6, -1)
        version:SetText(opts.version)
        ns.Paint(version, C.dimText)
    end

    local close = ns.CreateIconButton(bar, ns.ASSET_PATH .. "close.png", 14)
    close:SetPoint("RIGHT", bar, "RIGHT", -10, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    local rule = NewTexture(bar, "ARTWORK", C.rowRule)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 1, 0)
    rule:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 0)

    f.titleBar = bar
    f:Hide()
    return f
end
ns.CreateThemedWindow = CreateThemedWindow

-- A vertical scroll area with a slim themed scroll indicator. Returns the scroll frame;
-- its scroll child (child) takes the content and its height decides the range.
local function CreateScrollArea(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll.child = child

    local track = NewTexture(scroll, "ARTWORK", C.scrollTrack)
    track:SetWidth(3)
    track:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 0)
    local thumb = NewTexture(scroll, "OVERLAY", C.scrollThumb)
    thumb:SetWidth(3)

    local function UpdateThumb()
        local range = scroll:GetVerticalScrollRange()
        local height = scroll:GetHeight()
        if range <= 0 or height <= 0 then
            track:Hide()
            thumb:Hide()
            return
        end
        track:Show()
        thumb:Show()
        local thumbHeight = math.max(20, height * height / (height + range))
        local offset = (height - thumbHeight) * (scroll:GetVerticalScroll() / range)
        thumb:SetHeight(thumbHeight)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, -offset)
    end
    scroll.UpdateThumb = UpdateThumb

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        local target = math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40))
        self:SetVerticalScroll(target)
    end)
    scroll:SetScript("OnVerticalScroll", UpdateThumb)
    scroll:SetScript("OnScrollRangeChanged", UpdateThumb)
    scroll:SetScript("OnSizeChanged", function(self, w)
        child:SetWidth(w)
        UpdateThumb()
    end)
    return scroll
end
ns.CreateScrollArea = CreateScrollArea

---------------------------------------------------------------------------
-- Cards and rows
---------------------------------------------------------------------------

-- A titled group of rows. card:AddRow(row) appends; row.collapsed hides a row without
-- removing it; card:Relayout() restacks the visible rows and sets the card's height.
local function CreateCard(parent, title)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    ns.ApplyDarkBackdrop(card, C.cardBg, C.cardBorder, true)

    local titleText = card:CreateFontString(nil, "OVERLAY", "GudaChatFontNormalSmall")
    titleText:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PADDING, -10)
    titleText:SetPoint("RIGHT", card, "RIGHT", -CARD_PADDING, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)
    titleText:SetText(title)
    ns.Paint(titleText, C.cardTitle)

    card.rows = {}

    function card:AddRow(row)
        row:SetParent(self)
        row.rule = row.rule or NewTexture(row, "ARTWORK", C.rowRule)
        row.rule:SetHeight(1)
        row.rule:ClearAllPoints()
        row.rule:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.rule:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
        tinsert(self.rows, row)
        self:Relayout()
        return row
    end

    function card:Relayout()
        local y = CARD_TITLE_HEIGHT
        local first = true
        for _, row in ipairs(self.rows) do
            if row.collapsed then
                row:Hide()
            else
                row:Show()
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", self, "TOPLEFT", CARD_PADDING, -y)
                row:SetPoint("RIGHT", self, "RIGHT", -CARD_PADDING, 0)
                row.rule:SetShown(not first and not row.noRule)
                first = false
                y = y + row:GetHeight()
            end
        end
        self:SetHeight(y + 6)
    end

    return card
end
ns.CreateCard = CreateCard

-- A row with a label on the left (cut with "..." when too long) and an optional grey
-- hint line under it. controlWidth is the space kept free on the right for the control.
local function CreateRow(label, hint, controlWidth)
    local row = CreateFrame("Frame")
    row:SetHeight(ROW_HEIGHT + (hint and HINT_HEIGHT or 0))

    local text = row:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlight")
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(label or "")
    ns.Paint(text, C.labelText)
    row.label = text

    if hint then
        text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -7)
        local hintText = row:CreateFontString(nil, "OVERLAY", "GudaChatFontDisableSmall")
        hintText:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
        hintText:SetPoint("RIGHT", row, "RIGHT", -((controlWidth or 0) + 8), 0)
        hintText:SetJustifyH("LEFT")
        hintText:SetWordWrap(false)
        hintText:SetText(hint)
        ns.Paint(hintText, C.dimText)
        row.hint = hintText
    else
        text:SetPoint("LEFT", row, "LEFT", 0, 0)
    end
    text:SetPoint("RIGHT", row, "RIGHT", -((controlWidth or 0) + 8), 0)
    return row
end
ns.CreateSettingsRow = CreateRow

---------------------------------------------------------------------------
-- Switch / checkbox
---------------------------------------------------------------------------

-- An on/off row. Modern Dark draws a switch, the other themes a square checkbox with a
-- gold check. get() reads the current value, set(value) stores and applies it.
-- toggle:Refresh() (alias SetChecked) redraws after the value changed elsewhere.
local function CreateToggle(label, get, set, hint)
    local row = CreateRow(label, hint, SWITCH_WIDTH)

    local btn = CreateFrame("Button", nil, row)
    btn:SetSize(SWITCH_WIDTH, SWITCH_HEIGHT)
    btn:SetPoint("RIGHT", row, "RIGHT", 0, 0)

    local track = btn:CreateTexture(nil, "ARTWORK")
    track:SetAllPoints()
    track:SetTexture(ROUNDED)
    local knob = btn:CreateTexture(nil, "OVERLAY")
    knob:SetSize(KNOB_SIZE, KNOB_SIZE)
    knob:SetTexture(ROUNDED)

    local box = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    box:SetSize(CHECK_SIZE, CHECK_SIZE)
    box:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
    box:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    local check = box:CreateTexture(nil, "OVERLAY")
    check:SetSize(CHECK_SIZE + 6, CHECK_SIZE + 6)
    check:SetPoint("CENTER", box, "CENTER", 1, 1)
    check:SetTexture(CHECK_TEXTURE)

    local function Refresh()
        local on = get() and true or false
        if ns.Theme.UsesSwitches() then
            box:Hide()
            track:Show()
            knob:Show()
            local fill = on and C.controlOn or C.controlOff
            track:SetVertexColor(fill[1], fill[2], fill[3], fill[4])
            knob:SetVertexColor(1, 1, 1, 1)
            knob:ClearAllPoints()
            knob:SetPoint(on and "RIGHT" or "LEFT", btn, on and "RIGHT" or "LEFT", on and -2 or 2, 0)
        else
            track:Hide()
            knob:Hide()
            box:Show()
            box:SetBackdropColor(C.controlOff[1], C.controlOff[2], C.controlOff[3], C.controlOff[4])
            box:SetBackdropBorderColor(C.controlBorder[1], C.controlBorder[2], C.controlBorder[3], C.controlBorder[4])
            check:SetVertexColor(C.checkMark[1], C.checkMark[2], C.checkMark[3], C.checkMark[4])
            check:SetShown(on)
        end
    end

    local function Toggle()
        set(not get())
        Refresh()
    end
    btn:SetScript("OnClick", Toggle)
    row:EnableMouse(true)
    row:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then Toggle() end
    end)

    row.Refresh = Refresh
    row.SetChecked = function() Refresh() end
    OnRestyle(Refresh)
    return row
end
ns.CreateToggle = CreateToggle

---------------------------------------------------------------------------
-- Slider
---------------------------------------------------------------------------

-- A flat slider with a value box. Dragging or clicking the track, the mouse wheel over
-- the row, or typing in the box (Enter applies, Escape restores) all snap to step and
-- stay inside min..max. set(value) runs only when the value actually changes.
local function CreateSlider(label, minVal, maxVal, step, get, set)
    local row = CreateRow(label, nil, SLIDER_TRACK_WIDTH + VALUE_BOX_WIDTH + 10)

    local box = CreateFrame("EditBox", nil, row, "BackdropTemplate")
    box:SetSize(VALUE_BOX_WIDTH, 20)
    box:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    box:SetAutoFocus(false)
    box:SetFontObject(GudaChatFontHighlightSmall)
    box:SetJustifyH("CENTER")
    box:SetTextInsets(2, 2, 0, 0)
    box:SetMaxLetters(6)
    ns.ApplyDarkBackdrop(box, C.fieldBg, C.controlBorder, true)
    ns.Paint(box, C.editText)

    local track = CreateFrame("Frame", nil, row)
    track:SetSize(SLIDER_TRACK_WIDTH, 16)
    track:SetPoint("RIGHT", box, "LEFT", -10, 0)
    track:EnableMouse(true)

    local line = NewTexture(track, "ARTWORK", C.controlOff)
    line:SetHeight(4)
    line:SetPoint("LEFT", track, "LEFT", 0, 0)
    line:SetPoint("RIGHT", track, "RIGHT", 0, 0)
    local fill = NewTexture(track, "ARTWORK", C.controlOn)
    fill:SetHeight(4)
    fill:SetPoint("LEFT", track, "LEFT", 0, 0)
    local thumb = track:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(10, 14)
    thumb:SetTexture(ROUNDED)
    ns.Paint(thumb, C.labelText)

    local function Show(value)
        local fraction = (maxVal > minVal) and (value - minVal) / (maxVal - minVal) or 0
        local width = track:GetWidth() > 0 and track:GetWidth() or SLIDER_TRACK_WIDTH
        fill:SetWidth(math.max(1, width * fraction))
        thumb:ClearAllPoints()
        thumb:SetPoint("CENTER", track, "LEFT", width * fraction, 0)
        if not box:HasFocus() then
            box:SetText(ns.FormatSliderValue(value))
        end
    end

    local function Apply(value)
        value = ns.ClampSliderValue(value, minVal, maxVal, step)
        if not value then
            Show(get())
            return
        end
        if value ~= get() then set(value) end
        Show(value)
    end

    local function ValueAtCursor()
        local scale = track:GetEffectiveScale()
        local x = GetCursorPosition() / scale
        return ns.SliderValueAt(x, track:GetLeft() or 0, track:GetWidth(), minVal, maxVal, step)
    end

    track:SetScript("OnMouseDown", function(self)
        Apply(ValueAtCursor())
        self:SetScript("OnUpdate", function()
            if IsMouseButtonDown("LeftButton") then
                Apply(ValueAtCursor())
            else
                self:SetScript("OnUpdate", nil)
            end
        end)
    end)
    track:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    track:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)

    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta)
        Apply(get() + delta * step)
    end)

    box:SetScript("OnEnterPressed", function(self)
        Apply(self:GetText())
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        Show(get())
    end)
    box:SetScript("OnEditFocusLost", function() Show(get()) end)

    row.Refresh = function() Show(get()) end
    track:SetScript("OnSizeChanged", row.Refresh)
    Show(get())
    return row
end
ns.CreateSlider = CreateSlider

---------------------------------------------------------------------------
-- Text input
---------------------------------------------------------------------------

local TEXT_INPUT_WIDTH = 90

-- A row with a short text box. Enter or clicking away applies through set(text), Escape
-- restores. placeholder() is drawn greyed out while the box is empty. row:Bind(label,
-- get, set, placeholder) points a pooled row at another value.
local function CreateTextInput(label, get, set, placeholder, maxLetters)
    local row = CreateRow(label, nil, TEXT_INPUT_WIDTH)

    local box = CreateFrame("EditBox", nil, row, "BackdropTemplate")
    box:SetSize(TEXT_INPUT_WIDTH, 20)
    box:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    box:SetAutoFocus(false)
    box:SetFontObject(GudaChatFontHighlightSmall)
    box:SetJustifyH("CENTER")
    box:SetTextInsets(4, 4, 0, 0)
    if maxLetters then box:SetMaxLetters(maxLetters) end
    ns.ApplyDarkBackdrop(box, C.fieldBg, C.controlBorder, true)
    ns.Paint(box, C.editText)

    local hint = box:CreateFontString(nil, "OVERLAY", "GudaChatFontDisableSmall")
    hint:SetPoint("CENTER")
    ns.Paint(hint, C.dimText)

    local function Show()
        if not box:HasFocus() then box:SetText(get() or "") end
        hint:SetText(placeholder and placeholder() or "")
        hint:SetShown(box:GetText() == "" and not box:HasFocus())
    end

    local cancelled = false
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self)
        cancelled = true
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusGained", function() hint:Hide() end)
    box:SetScript("OnEditFocusLost", function(self)
        if not cancelled then set(self:GetText()) end
        cancelled = false
        Show()
    end)

    function row:Bind(newLabel, newGet, newSet, newPlaceholder)
        self.label:SetText(newLabel or "")
        get, set, placeholder = newGet, newSet, newPlaceholder
        Show()
    end

    row.Refresh = Show
    Show()
    return row
end
ns.CreateTextInput = CreateTextInput

---------------------------------------------------------------------------
-- Dropdown
---------------------------------------------------------------------------

local dropdownMenu
local dropdownOwner

local function CloseDropdownMenu()
    if dropdownMenu then dropdownMenu:Hide() end
    dropdownOwner = nil
end
ns.CloseSettingsDropdown = CloseDropdownMenu

local function GetDropdownMenu()
    if dropdownMenu then return dropdownMenu end
    local menu = CreateFrame("Frame", "GudaChatSettingsDropdownMenu", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    ns.ApplyDarkBackdrop(menu)
    menu:Hide()
    ns.CreateClickCloser(menu, function()
        return menu:IsMouseOver() or (dropdownOwner and dropdownOwner:IsMouseOver())
    end, CloseDropdownMenu)
    tinsert(UISpecialFrames, "GudaChatSettingsDropdownMenu")
    dropdownMenu = menu
    return menu
end

-- Fills the shared menu with options under the button and shows it. The current value
-- is drawn in the highlight colour.
local function OpenDropdownMenu(button, options, get, onPick)
    local menu = GetDropdownMenu()
    if menu:IsShown() and dropdownOwner == button then
        CloseDropdownMenu()
        return
    end
    dropdownOwner = button
    local current = get()
    for i, opt in ipairs(options) do
        local item = ns.GetMenuItem(menu, i, DROPDOWN_ITEM_HEIGHT)
        if not item.gudaHighlight then
            local hl = item:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture(WHITE)
            ns.Paint(hl, C.menuHover)
            item.gudaHighlight = hl
            item.text:SetPoint("RIGHT", item, "RIGHT", -8, 0)
            item.text:SetJustifyH("LEFT")
            item.text:SetWordWrap(false)
        end
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * DROPDOWN_ITEM_HEIGHT)
        item:SetPoint("RIGHT", menu, "RIGHT", -4, 0)
        item.text:SetText(opt.label)
        ns.Paint(item.text, opt.value == current and C.controlOn or C.labelText)
        item:SetScript("OnClick", function()
            CloseDropdownMenu()
            onPick(opt.value)
        end)
        item:Show()
    end
    ns.HideMenuItemsFrom(menu, #options + 1)
    menu:SetSize(button:GetWidth(), #options * DROPDOWN_ITEM_HEIGHT + 8)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    menu:Show()
end

-- A row with a dropdown button. options is a list of { label, value } or a function
-- returning one; set(value) stores and applies the choice.
local function CreateDropdown(label, options, get, set, hint)
    local row = CreateRow(label, hint, DROPDOWN_WIDTH)

    local button = CreateFrame("Button", nil, row, "BackdropTemplate")
    button:SetSize(DROPDOWN_WIDTH, 22)
    button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    ns.ApplyDarkBackdrop(button, C.fieldBg, C.controlBorder, true)

    local text = button:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlightSmall")
    text:SetPoint("LEFT", button, "LEFT", 8, 0)
    text:SetPoint("RIGHT", button, "RIGHT", -20, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    ns.Paint(text, C.editText)

    local arrow = button:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlightSmall")
    arrow:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    arrow:SetText("v")
    ns.Paint(arrow, C.menuArrow)

    local function List()
        return type(options) == "function" and options() or options
    end

    local function Refresh()
        local current = get()
        local shown = ""
        for _, opt in ipairs(List()) do
            if opt.value == current then
                shown = opt.label
                break
            end
        end
        text:SetText(shown)
    end

    button:SetScript("OnClick", function(self)
        OpenDropdownMenu(self, List(), get, function(value)
            set(value)
            Refresh()
        end)
    end)
    button:SetScript("OnHide", function(self)
        if dropdownOwner == self then CloseDropdownMenu() end
    end)

    row.Refresh = Refresh
    Refresh()
    return row
end
ns.CreateDropdown = CreateDropdown

---------------------------------------------------------------------------
-- Colour swatch
---------------------------------------------------------------------------

-- A small colour button. get() returns r, g, b; pick(r, g, b) runs while the colour
-- picker moves; cancel(r, g, b) gets the colour from before the picker opened.
local function CreateSwatch(parent, get, pick, cancel)
    local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    swatch:SetSize(SWATCH_WIDTH, SWATCH_HEIGHT)
    swatch:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })

    local function Refresh()
        local r, g, b = get()
        swatch:SetBackdropColor(r, g, b, 1)
        swatch:SetBackdropBorderColor(C.swatchBorder[1], C.swatchBorder[2], C.swatchBorder[3], C.swatchBorder[4])
    end

    swatch:SetScript("OnClick", function()
        local r, g, b = get()
        ns.ShowColorPicker({
            r = r, g = g, b = b,
            hasOpacity = false,
            swatchFunc = function()
                pick(ColorPickerFrame:GetColorRGB())
                Refresh()
            end,
            cancelFunc = function()
                cancel(r, g, b)
                Refresh()
            end,
        })
    end)

    swatch.Refresh = Refresh
    OnRestyle(Refresh)
    return swatch
end
ns.CreateSwatch = CreateSwatch

---------------------------------------------------------------------------
-- Button
---------------------------------------------------------------------------

-- A text button: the red Blizzard panel button under the Blizzard theme, a flat themed
-- button otherwise
local function CreateButton(parent, label, onClick, width)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or 130, 24)

    local flat = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    flat:SetAllPoints()
    flat:SetFrameLevel(btn:GetFrameLevel())
    ns.ApplyDarkBackdrop(flat, C.fieldBg, C.controlBorder, true)

    local up = btn:CreateTexture(nil, "BACKGROUND")
    up:SetAllPoints()
    up:SetTexture(PANEL_BUTTON_UP)
    up:SetTexCoord(unpack(PANEL_BUTTON_COORDS))
    local down = btn:CreateTexture(nil, "BACKGROUND")
    down:SetAllPoints()
    down:SetTexture(PANEL_BUTTON_DOWN)
    down:SetTexCoord(unpack(PANEL_BUTTON_COORDS))
    down:Hide()

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()

    local text = btn:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlightSmall")
    text:SetPoint("CENTER")
    text:SetText(label)
    ns.Paint(text, C.buttonText)
    btn.text = text

    local function Restyle()
        local blizzard = ns.Theme.UsesBlizzardArt()
        flat:SetShown(not blizzard)
        up:SetShown(blizzard)
        down:Hide()
        if blizzard then
            highlight:SetTexture(PANEL_BUTTON_HIGHLIGHT)
            highlight:SetTexCoord(unpack(PANEL_BUTTON_COORDS))
            highlight:SetBlendMode("ADD")
            highlight:SetVertexColor(1, 1, 1, 1)
        else
            highlight:SetTexture(WHITE)
            highlight:SetTexCoord(0, 1, 0, 1)
            highlight:SetBlendMode("BLEND")
            highlight:SetVertexColor(C.navHover[1], C.navHover[2], C.navHover[3], C.navHover[4])
        end
    end

    btn:SetScript("OnMouseDown", function()
        if ns.Theme.UsesBlizzardArt() then
            up:Hide()
            down:Show()
        end
    end)
    btn:SetScript("OnMouseUp", Restyle)
    btn:SetScript("OnClick", function(self) onClick(self) end)

    OnRestyle(Restyle)
    return btn
end
ns.CreateThemedButton = CreateButton

---------------------------------------------------------------------------
-- Text tabs
---------------------------------------------------------------------------

-- A row of text tabs. defs: { label, tooltip }. onSelect(id) runs on click; bar:Select(id)
-- marks a tab without running it. The active tab gets the highlight background and,
-- in themes with tab underlines, an accent underline.
local function CreateTextTabs(parent, defs, onSelect)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(22)
    local tabs = {}
    local selected = 1

    local function Paint()
        for i, tab in ipairs(tabs) do
            local active = i == selected
            local entry = active and C.navActiveText or (tab:IsMouseOver() and C.labelText or C.navText)
            tab.text:SetTextColor(entry[1], entry[2], entry[3], entry[4])
            tab.bg:SetShown(active)
            tab.bg:SetVertexColor(C.navActiveBg[1], C.navActiveBg[2], C.navActiveBg[3], C.navActiveBg[4])
            tab.underline:SetShown(active and ns.Theme.HasTabUnderline())
            tab.underline:SetVertexColor(C.tabUnderline[1], C.tabUnderline[2], C.tabUnderline[3], C.tabUnderline[4])
        end
    end

    for i, def in ipairs(defs) do
        local tab = CreateFrame("Button", nil, bar)
        tab:SetHeight(22)
        local text = tab:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlightSmall")
        text:SetPoint("CENTER")
        text:SetText(def.label)
        tab.text = text
        tab:SetWidth(text:GetStringWidth() + 16)
        tab.bg = NewTexture(tab, "BACKGROUND")
        tab.bg:SetAllPoints()
        tab.underline = NewTexture(tab, "ARTWORK")
        tab.underline:SetHeight(2)
        tab.underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 4, 0)
        tab.underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -4, 0)
        if i == 1 then
            tab:SetPoint("LEFT", bar, "LEFT", 0, 0)
        else
            tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", 2, 0)
        end
        tab:SetScript("OnClick", function()
            selected = i
            Paint()
            onSelect(i)
        end)
        tab:SetScript("OnEnter", function(self)
            Paint()
            if def.tooltip then
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:SetText(def.tooltip, 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        tab:SetScript("OnLeave", function()
            Paint()
            GameTooltip:Hide()
        end)
        tabs[i] = tab
    end

    function bar:Select(id)
        selected = id
        Paint()
    end

    OnRestyle(Paint)
    return bar
end
ns.CreateTextTabs = CreateTextTabs
