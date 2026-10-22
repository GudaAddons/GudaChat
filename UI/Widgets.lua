local addonName, ns = ...

---------------------------------------------------------------------------
-- Shared widgets: icon buttons, menu items, click-outside closers, the colour
-- picker and the ButtonFrame popups used by History and Settings.
---------------------------------------------------------------------------

-- Header and tab bar fade timings, and how often their hover monitors poll the mouse.
-- The monitors are children of the bar they watch, so they stop while it is hidden.
ns.FADE_IN_DURATION = 0.15
ns.FADE_OUT_DURATION = 0.25
ns.HOVER_CHECK_INTERVAL = 0.05

local MENU_ITEM_HEIGHT = 20
ns.MENU_ITEM_HEIGHT = MENU_ITEM_HEIGHT

local ICON_COLOR_NORMAL = { 0.7, 0.7, 0.7, 0.9 }

local function SetTooltipFontSize(size)
    if GameTooltipTextLeft1 then
        local font, _, flags = GameTooltipTextLeft1:GetFont()
        if font then GameTooltipTextLeft1:SetFont(font, size, flags) end
    end
end
ns.SetTooltipFontSize = SetTooltipFontSize

-- Keeps the chat header visible while the mouse is over one of its controls
local function RevealHeader()
    if ns.chatHeader and not ns.hideHeaderForInput then ns.chatHeader:SetAlpha(1) end
end
ns.RevealHeader = RevealHeader

-- Small icon button with a tooltip; the icon brightens on hover
local function CreateIconButton(parent, texturePath, size, tooltip)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(texturePath)
    icon:SetVertexColor(unpack(ICON_COLOR_NORMAL))
    btn.icon = icon

    btn:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1, 1)
        if tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip, 1, 1, 1)
            SetTooltipFontSize(12)
            GameTooltip:Show()
        end
        RevealHeader()
    end)
    btn:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(unpack(ICON_COLOR_NORMAL))
        GameTooltip:Hide()
    end)

    return btn
end
ns.CreateIconButton = CreateIconButton

-- One row of a hand-built menu: a label, and optionally a check mark, a submenu arrow or
-- (isSeparator) a gold section title that takes no clicks
local function CreateMenuItem(parent, label, onClick, isSeparator, hasArrow, isCheckbox)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(MENU_ITEM_HEIGHT)

    if isSeparator then
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", btn, "LEFT", 8, 0)
        text:SetText(label)
        text:SetTextColor(0.9, 0.75, 0.3)
        btn:EnableMouse(false)
        btn.label = text
        return btn
    end

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", btn, "LEFT", 8, 0)
    text:SetText(label)
    btn.label = text

    if isCheckbox then
        local check = btn:CreateTexture(nil, "ARTWORK")
        check:SetSize(12, 12)
        check:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        check:Hide()
        btn.check = check
    end

    if hasArrow then
        local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        arrow:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        arrow:SetText(">")
        arrow:SetTextColor(0.7, 0.7, 0.7)
    end

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
    highlight:SetVertexColor(1, 1, 1, 0.1)

    btn:SetScript("OnClick", function(self)
        if onClick then onClick(self) end
    end)

    return btn
end
ns.CreateMenuItem = CreateMenuItem

-- The menu's idx-th reusable item button (label at btn.text), created the first time it
-- is needed. Menus that are rebuilt often (tab dropdown, overflow menus) use these so no
-- frame is ever created twice.
local function GetMenuItem(menu, idx, height)
    menu.items = menu.items or {}
    local item = menu.items[idx]
    if not item then
        item = CreateFrame("Button", nil, menu)
        local text = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", item, "LEFT", 8, 0)
        item.text = text
        item:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        menu.items[idx] = item
    end
    item:SetHeight(height)
    return item
end
ns.GetMenuItem = GetMenuItem

-- Hides the menu's reusable item buttons from idx on
local function HideMenuItemsFrom(menu, idx)
    if not menu.items then return end
    for i = idx, #menu.items do
        menu.items[i]:Hide()
    end
end
ns.HideMenuItemsFrom = HideMenuItemsFrom

-- Closes a menu when the left button goes down outside it. isInside() says whether the
-- mouse is over the menu or anything that belongs to it; onClose hides them. The watcher
-- is a child of the menu, so it only runs while the menu is open.
local function CreateClickCloser(menu, isInside, onClose)
    local closer = CreateFrame("Frame", nil, menu)
    closer:SetScript("OnUpdate", function()
        if not isInside() and IsMouseButtonDown("LeftButton") then
            onClose()
        end
    end)
    return closer
end
ns.CreateClickCloser = CreateClickCloser

-- Opens Blizzard's colour picker on both picker generations. info is the modern
-- SetupColorPickerAndShow table (r, g, b, hasOpacity, opacity, swatchFunc, opacityFunc,
-- cancelFunc); the legacy picker gets the same callbacks through its fields.
local function ShowColorPicker(info)
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow(info)
        return
    end
    ColorPickerFrame:SetColorRGB(info.r, info.g, info.b)
    ColorPickerFrame.hasOpacity = info.hasOpacity or false
    ColorPickerFrame.opacity = info.opacity
    ColorPickerFrame.func = info.swatchFunc
    ColorPickerFrame.opacityFunc = info.opacityFunc
    ColorPickerFrame.cancelFunc = info.cancelFunc
    ColorPickerFrame.previousValues = { r = info.r, g = info.g, b = info.b, opacity = info.opacity }
    ColorPickerFrame:Hide()
    ColorPickerFrame:Show()
end
ns.ShowColorPicker = ShowColorPicker

-- The movable ButtonFrameTemplate window used by History and Settings: no portrait or
-- button bar, closes on Escape and on entering combat, dragged by its title bar
local function CreateButtonFramePopup(name, width, height, title)
    local f = CreateFrame("Frame", name, UIParent, "ButtonFrameTemplate")
    f:SetSize(width, height)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)

    tinsert(UISpecialFrames, name)

    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:SetScript("OnEvent", function(self) self:Hide() end)

    ButtonFrameTemplate_HidePortrait(f)
    ButtonFrameTemplate_HideButtonBar(f)
    if f.Inset then f.Inset:Hide() end

    f:SetTitle(title)
    ns.CreateDragRegion(f)
    return f
end
ns.CreateButtonFramePopup = CreateButtonFramePopup
