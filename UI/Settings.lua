local addonName, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- UI control factories
---------------------------------------------------------------------------

local function CreateCheckbox(parent, label, checked, onClick)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(26)

    local cb
    if DoesTemplateExist and DoesTemplateExist("SettingsCheckBoxTemplate") then
        cb = CreateFrame("CheckButton", nil, container, "SettingsCheckBoxTemplate")
    elseif DoesTemplateExist and DoesTemplateExist("SettingsCheckboxTemplate") then
        cb = CreateFrame("CheckButton", nil, container, "SettingsCheckboxTemplate")
    else
        cb = CreateFrame("CheckButton", nil, container, "InterfaceOptionsCheckButtonTemplate")
    end

    cb:SetPoint("LEFT", container, "LEFT", 0, 0)
    cb:SetText("")
    cb:SetChecked(checked)
    cb:SetScript("OnClick", function(self)
        onClick(self:GetChecked())
    end)

    local text = container:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)

    container:EnableMouse(true)
    container:SetScript("OnMouseUp", function() cb:Click() end)

    container.checkbox = cb
    container.label = text
    return container
end

local function CreateSeparator(parent, label)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(20)

    local text = container:CreateFontString(nil, "OVERLAY", "GudaChatFontNormalSmall")
    text:SetPoint("LEFT", container, "LEFT", 0, 0)
    text:SetJustifyH("LEFT")
    ns.Paint(text, ns.Theme.C.separatorText)
    text:SetText(label)

    local line = container:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", text, "RIGHT", 6, 0)
    line:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    line:SetTexture("Interface\\Buttons\\WHITE8x8")
    ns.Paint(line, ns.Theme.C.separatorLine)

    return container
end

local function CreateSlider(parent, label, minVal, maxVal, step, currentVal, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(36)

    local text = container:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlight")
    text:SetPoint("LEFT", container, "LEFT", 0, 0)
    text:SetText(label)

    local useModernSlider = DoesTemplateExist and DoesTemplateExist("MinimalSliderWithSteppersTemplate")
    local slider, valueText

    if useModernSlider then
        slider = CreateFrame("Slider", nil, container, "MinimalSliderWithSteppersTemplate")
        slider:SetPoint("LEFT", container, "CENTER", -50, 0)
        slider:SetPoint("RIGHT", container, "RIGHT", -50, 0)
        slider:SetHeight(20)

        local steps = (maxVal - minVal) / step
        slider:Init(currentVal, minVal, maxVal, steps, {
            [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
                return WHITE_FONT_COLOR:WrapTextInColorCode(string.format("%d", value))
            end)
        })

        slider:RegisterCallback("OnValueChanged", function(_, value)
            value = math.floor(value + 0.5)
            onChange(value)
        end)

        container.GetValue = function() return slider:GetValue() end
        container.SetValue = function(_, val) slider:SetValue(val) end
    else
        slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
        slider:SetPoint("LEFT", container, "CENTER", -50, 0)
        slider:SetPoint("RIGHT", container, "RIGHT", -55, 0)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        slider.Text:SetText("")
        slider.Low:SetText("")
        slider.High:SetText("")
        slider:SetValue(currentVal)

        valueText = container:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlight")
        valueText:SetPoint("LEFT", slider, "RIGHT", 5, 0)
        valueText:SetWidth(40)
        valueText:SetJustifyH("LEFT")
        valueText:SetText(currentVal)

        slider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            valueText:SetText(value)
            onChange(value)
        end)

        container.GetValue = function() return slider:GetValue() end
        container.SetValue = function(_, val) slider:SetValue(val) end
    end

    container:EnableMouseWheel(true)
    container:SetScript("OnMouseWheel", function(self, delta)
        local current = container.GetValue()
        local val = current + (delta * step)
        val = math.max(minVal, math.min(maxVal, val))
        container.SetValue(nil, val)
        onChange(math.floor(val + 0.5))
    end)

    container.slider = slider
    container.valueText = valueText
    return container
end

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

local dropdownCounter = 0

-- Range of the loot log and addon log size sliders (History tab)
local LOG_CAP_MIN = 100
local LOG_CAP_MAX = 2000
local LOG_CAP_STEP = 100

-- WowStyle1DropdownTemplate + MenuUtil where the client has them (Retail, Forever and the
-- modern Classic clients). UIDropDownMenu shares global state with Blizzard's unit popups,
-- so using it from addon code can taint them; the old template stays only as a fallback.
local DROPDOWN_WIDTH = 140

local function CreateModernDropdown(container, options, currentValue, onChange)
    local selected = currentValue
    local dropdown = CreateFrame("DropdownButton", nil, container, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    dropdown:SetWidth(DROPDOWN_WIDTH)

    local entries = {}
    for _, opt in ipairs(options) do
        tinsert(entries, { opt.label, opt.value })
    end
    MenuUtil.CreateRadioMenu(dropdown,
        function(value) return value == selected end,
        function(value)
            selected = value
            onChange(value)
        end,
        unpack(entries))
    return dropdown
end

local function CreateDropdown(parent, label, options, currentValue, onChange)
    dropdownCounter = dropdownCounter + 1
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(30)

    local text = container:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlight")
    text:SetPoint("LEFT", container, "LEFT", 0, 0)
    text:SetText(label)
    container.label = text

    if DoesTemplateExist and DoesTemplateExist("WowStyle1DropdownTemplate") and MenuUtil then
        container.dropdown = CreateModernDropdown(container, options, currentValue, onChange)
        return container
    end

    local ddName = "GudaChatDropdown" .. dropdownCounter
    local dd = CreateFrame("Frame", ddName, container, "UIDropDownMenuTemplate")
    dd:SetPoint("RIGHT", container, "RIGHT", 16, -2)
    UIDropDownMenu_SetWidth(dd, 120)

    local function Initialize(self, level)
        for _, opt in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.label
            info.value = opt.value
            info.func = function(self)
                UIDropDownMenu_SetSelectedValue(dd, self.value)
                UIDropDownMenu_SetText(dd, opt.label)
                onChange(self.value)
                CloseDropDownMenus()
            end
            info.checked = (opt.value == UIDropDownMenu_GetSelectedValue(dd))
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dd, Initialize)
    UIDropDownMenu_SetSelectedValue(dd, currentValue)
    for _, opt in ipairs(options) do
        if opt.value == currentValue then
            UIDropDownMenu_SetText(dd, opt.label)
            break
        end
    end

    container.dropdown = dd
    return container
end

-- A small grey hint under a dropdown's label, e.g. that a setting applies after /reload.
-- The label moves up and the row grows by NOTE_HEIGHT so the next control is not covered.
local NOTE_HEIGHT = 12

local function AddNote(container, note)
    local label = container.label
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -4)
    local noteText = container:CreateFontString(nil, "OVERLAY", "GudaChatFontDisableSmall")
    noteText:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
    noteText:SetPoint("RIGHT", container, "RIGHT", -(DROPDOWN_WIDTH + 8), 0)
    noteText:SetJustifyH("LEFT")
    noteText:SetWordWrap(false)
    noteText:SetText(note)
    container:SetHeight(container:GetHeight() + NOTE_HEIGHT)
    return container
end

-- "Accent colour" row: a swatch showing the current accent that opens the colour picker.
-- Picking a colour turns "Use my class colour" off; Cancel restores the previous accent.
local ACCENT_SWATCH_SIZE = 20

local function CreateAccentSwatch(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(30)

    local text = container:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlight")
    text:SetPoint("LEFT", container, "LEFT", 0, 0)
    text:SetText(L["OPT_ACCENT_COLOR"])
    container.label = text

    local swatch = CreateFrame("Button", nil, container)
    swatch:SetSize(ACCENT_SWATCH_SIZE, ACCENT_SWATCH_SIZE)
    swatch:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    local swatchTex = swatch:CreateTexture(nil, "ARTWORK")
    swatchTex:SetAllPoints()
    swatchTex:SetTexture("Interface\\Buttons\\WHITE8x8")
    local swatchBorder = swatch:CreateTexture(nil, "ARTWORK", nil, -1)
    swatchBorder:SetSize(ACCENT_SWATCH_SIZE + 2, ACCENT_SWATCH_SIZE + 2)
    swatchBorder:SetPoint("CENTER")
    swatchBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
    ns.Paint(swatchBorder, ns.Theme.C.swatchBorder)

    function container.Update()
        swatchTex:SetVertexColor(ns.Theme.ResolveAccent(GudaChatDB.accent))
    end
    container.Update()

    swatch:SetScript("OnClick", function()
        local previous = GudaChatDB.accent
        local r, g, b = ns.Theme.ResolveAccent(previous)
        ns.ShowColorPicker({
            r = r, g = g, b = b,
            hasOpacity = false,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                ns.Theme.SetAccent({ r = nr, g = ng, b = nb })
                container.Update()
                if container.onPicked then container.onPicked() end
            end,
            cancelFunc = function()
                ns.Theme.SetAccent(previous)
                container.Update()
                if container.onPicked then container.onPicked() end
            end,
        })
    end)
    return container
end

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
-- Settings frame
---------------------------------------------------------------------------

local settingsFrame

local function CreateSettingsFrame()
    local f = ns.CreateButtonFramePopup("GudaChatSettingsPopup", 480, 520, "GudaChat " .. ns.Blizz(SETTINGS, "Settings"))

    -------------------------------------------------------------------
    -- Tabs (Blizzard style)
    -------------------------------------------------------------------
    local tabTemplate
    if DoesTemplateExist and DoesTemplateExist("PanelTopTabButtonTemplate") then
        tabTemplate = "PanelTopTabButtonTemplate"
    else
        tabTemplate = "TabButtonTemplate"
    end

    local tabDefs = { L["TAB_GENERAL"], L["TAB_MESSAGES"], L["TAB_HISTORY"], L["TAB_NOTIFICATIONS"] }
    local tabPanels = {}
    local tabs = {}

    for i, label in ipairs(tabDefs) do
        local tab = CreateFrame("Button", "GudaChatSettingsPopupTab" .. i, f, tabTemplate)
        if i == 1 then
            tab:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -24)
        else
            tab:SetPoint("TOPLEFT", tabs[i - 1], "TOPRIGHT", 4, 0)
        end
        tab:SetText(label)
        tab:SetID(i)
        PanelTemplates_TabResize(tab, 8, nil, 36)
        PanelTemplates_DeselectTab(tab)
        tabs[i] = tab
    end

    PanelTemplates_SetNumTabs(f, #tabDefs)

    for i = 1, #tabDefs do
        local panel = CreateFrame("Frame", nil, f)
        panel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -60)
        panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
        panel:Hide()
        tabPanels[i] = panel
    end

    local function SelectSettingsTab(id)
        PanelTemplates_SetTab(f, id)
        for i, panel in ipairs(tabPanels) do
            if i == id then panel:Show() else panel:Hide() end
        end
    end
    f.SelectTab = SelectSettingsTab

    for i, tab in ipairs(tabs) do
        tab:SetScript("OnClick", function() SelectSettingsTab(i) end)
    end

    -------------------------------------------------------------------
    -- Helper: build controls in a panel
    -------------------------------------------------------------------
    local function BuildPanel(panel)
        local yOff = 0
        local ctrls = {}
        local function Add(widget)
            widget:SetParent(panel)
            widget:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -yOff)
            widget:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -yOff)
            yOff = yOff + widget:GetHeight() + 8
            tinsert(ctrls, widget)
        end
        local function AddPair(w1, w2)
            local row = CreateFrame("Frame", nil, panel)
            local h = math.max(w1:GetHeight(), w2:GetHeight())
            row:SetHeight(h)

            w1:SetParent(row)
            w1:ClearAllPoints()
            w1:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            w1:SetPoint("RIGHT", row, "CENTER", -4, 0)

            w2:SetParent(row)
            w2:ClearAllPoints()
            w2:SetPoint("TOPLEFT", row, "TOP", 4, 0)
            w2:SetPoint("RIGHT", row, "TOPRIGHT", 0, 0)

            Add(row)
        end
        return Add, AddPair, ctrls
    end

    -------------------------------------------------------------------
    -- Tab 1: General
    -------------------------------------------------------------------
    do
        local Add, AddPair = BuildPanel(tabPanels[1])

        Add(CreateSeparator(tabPanels[1], L["SEC_APPEARANCE"]))

        local themeOptions = {
            { label = L["THEME_CLASSIC"], value = "classic" },
            { label = L["THEME_MODERN"], value = "modern" },
            { label = L["THEME_BLIZZARD"], value = "blizzard" },
        }
        Add(CreateDropdown(tabPanels[1], L["OPT_THEME"], themeOptions, ns.Theme.Current(), function(value)
            ns.Theme.Set(value)
        end))

        local accentSwatch = CreateAccentSwatch(tabPanels[1])
        Add(AddNote(accentSwatch, L["NOTE_ACCENT_MODERN"]))
        local classAccent = CreateCheckbox(tabPanels[1], L["OPT_ACCENT_CLASS"], GudaChatDB.accent == "class", function(checked)
            if checked then
                ns.Theme.SetAccent("class")
            else
                local r, g, b = ns.Theme.ResolveAccent(GudaChatDB.accent)
                ns.Theme.SetAccent({ r = r, g = g, b = b })
            end
            accentSwatch.Update()
        end)
        accentSwatch.onPicked = function()
            classAccent.checkbox:SetChecked(GudaChatDB.accent == "class")
        end
        Add(classAccent)

        Add(CreateSeparator(tabPanels[1], L["SEC_CHAT_WINDOW"]))

        AddPair(
            CreateCheckbox(tabPanels[1], L["OPT_LOCK_POSITION"], GudaChatDB.locked, function(checked)
                GudaChatDB.locked = checked
                ns.ApplyLockState()
            end),
            CreateCheckbox(tabPanels[1], L["OPT_DISABLE_FADING"], not GudaChatDB.fading, function(checked)
                GudaChatDB.fading = not checked
                ns.ApplyFading()
            end)
        )

        local currentFont = GudaChatDB.chatFont or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        Add(CreateDropdown(tabPanels[1], L["OPT_FONT"], GetFontOptions(), currentFont, function(value)
            GudaChatDB.chatFont = value
            ApplyChatFont(value)
        end))

        Add(CreateCheckbox(tabPanels[1], L["OPT_HIDE_SCROLLBAR"], GudaChatDB.hideScrollbar, function(checked)
            GudaChatDB.hideScrollbar = checked
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
            -- Give the reserved scrollbar column back to (or take it from) the message text
            ns.ApplyChatMargins()
        end))

        local currentTimestamp = GetCVar("showTimestamps") or "none"
        Add(AddNote(CreateDropdown(tabPanels[1], L["OPT_TIMESTAMPS"], TIMESTAMP_OPTIONS, currentTimestamp, function(value)
            SetCVar("showTimestamps", value)
        end), L["NOTE_APPLIES_AFTER_RELOAD"]))

        Add(CreateSeparator(tabPanels[1], L["SEC_INPUT_BAR"]))

        AddPair(
            CreateCheckbox(tabPanels[1], L["OPT_INPUT_BAR_TOP"], GudaChatDB.inputPosition == "top", function(checked)
                GudaChatDB.inputPosition = checked and "top" or "bottom"
                ns.ApplyInputBarPosition()
            end),
            CreateCheckbox(tabPanels[1], L["OPT_TRANSPARENT_INPUT"], GudaChatDB.transparentInput, function(checked)
                GudaChatDB.transparentInput = checked
                ns.ApplyTransparentInput()
            end)
        )

        Add(CreateSeparator(tabPanels[1], L["SEC_TABS"]))

        AddPair(
            CreateCheckbox(tabPanels[1], L["OPT_SHOW_TAB_BAR"], GudaChatDB.showTabBar, function(checked)
                GudaChatDB.showTabBar = checked
                if ns.chatSubTabs then
                    if checked then
                        ns.RefreshChatSubTabs(ns.chatHeader)
                        ns.chatSubTabs:Show()
                        ns.chatSubTabs:SetAlpha(0)
                    else
                        ns.chatSubTabs:Hide()
                    end
                end
            end),
            CreateCheckbox(tabPanels[1], L["OPT_INLINE_TAB_BAR"], GudaChatDB.inlineTabBar, function(checked)
                GudaChatDB.inlineTabBar = checked
                if ns.RefreshInlineTabs then ns.RefreshInlineTabs() end
                if ns.chatSubTabs then
                    if checked then
                        ns.chatSubTabs:Hide()
                    elseif GudaChatDB.showTabBar then
                        ns.RefreshChatSubTabs(ns.chatHeader)
                        ns.chatSubTabs:Show()
                        ns.chatSubTabs:SetAlpha(0)
                    end
                end
            end)
        )

        local whisperTabCheckbox = CreateCheckbox(tabPanels[1], L["OPT_WHISPER_TAB"], GudaChatDB.whisperTab, function(checked)
            GudaChatDB.whisperTab = checked
            if checked then
                ns.SetupWhisperFrame()
            else
                -- Restore the player's whisper mode and route whispers back to General.
                ns.ApplyWhisperRouting()
                if ns.whisperFrame and ns.whisperFrame:IsShown() then
                    ns.SafeSelectDockFrame(ChatFrame1)
                end
            end
            if ns.RefreshChatSubTabs then ns.RefreshChatSubTabs() end
            if ns.RefreshInlineTabs then ns.RefreshInlineTabs() end
        end)
        ns.whisperTabCheckbox = whisperTabCheckbox.checkbox
        Add(whisperTabCheckbox)

        Add(CreateSeparator(tabPanels[1], L["SEC_BACKGROUND"]))

        do
            local bgRow = CreateFrame("Frame", nil, tabPanels[1])
            bgRow:SetHeight(36)

            local shownBgColor, shownBgAlpha = ns.GetChatBackground()
            local bgAlphaPercent = math.floor(shownBgAlpha * 100)
            local bgSlider = CreateSlider(bgRow, ns.Blizz(OPACITY, "Opacity"), 0, 100, 5, bgAlphaPercent, function(value)
                ns.TakeOverChatBackground()
                GudaChatDB.globalBgAlpha = value / 100
                if GudaChatDB.useGlobalBg then
                    ns.ApplyGlobalBackground()
                end
            end)
            bgSlider:SetParent(bgRow)
            bgSlider:ClearAllPoints()
            bgSlider:SetPoint("TOPLEFT", bgRow, "TOPLEFT", 0, 0)
            bgSlider:SetPoint("RIGHT", bgRow, "RIGHT", -34, 0)

            local bgColor = shownBgColor
            local swatch = CreateFrame("Button", nil, bgRow)
            swatch:SetSize(20, 20)
            swatch:SetPoint("RIGHT", bgRow, "RIGHT", 0, 0)

            local swatchTex = swatch:CreateTexture(nil, "ARTWORK")
            swatchTex:SetAllPoints()
            swatchTex:SetTexture("Interface\\Buttons\\WHITE8x8")
            swatchTex:SetVertexColor(bgColor.r, bgColor.g, bgColor.b, math.max(shownBgAlpha, 0.3))

            local swatchBorder = swatch:CreateTexture(nil, "OVERLAY")
            swatchBorder:SetSize(22, 22)
            swatchBorder:SetPoint("CENTER", swatch, "CENTER")
            swatchBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
            ns.Paint(swatchBorder, ns.Theme.C.swatchBorder)
            swatchBorder:SetDrawLayer("ARTWORK", -1)

            swatch:SetScript("OnClick", function()
                ns.TakeOverChatBackground()
                local info = {}
                info.r = GudaChatDB.globalBgColor.r
                info.g = GudaChatDB.globalBgColor.g
                info.b = GudaChatDB.globalBgColor.b
                info.hasOpacity = false
                info.swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    GudaChatDB.globalBgColor = { r = nr, g = ng, b = nb }
                    swatchTex:SetVertexColor(nr, ng, nb, math.max(GudaChatDB.globalBgAlpha, 0.3))
                    if GudaChatDB.useGlobalBg then
                        ns.ApplyGlobalBackground()
                    end
                end
                info.cancelFunc = function(prev)
                    GudaChatDB.globalBgColor = { r = prev.r, g = prev.g, b = prev.b }
                    swatchTex:SetVertexColor(prev.r, prev.g, prev.b, math.max(GudaChatDB.globalBgAlpha, 0.3))
                    if GudaChatDB.useGlobalBg then
                        ns.ApplyGlobalBackground()
                    end
                end
                ns.ShowColorPicker(info)
            end)

            local function UpdateBgControlsVisibility(enabled)
                if enabled then
                    bgSlider:Show()
                    swatch:Show()
                else
                    bgSlider:Hide()
                    swatch:Hide()
                end
            end

            Add(CreateCheckbox(tabPanels[1], L["OPT_OVERRIDE_BACKGROUNDS"], GudaChatDB.useGlobalBg, function(checked)
                GudaChatDB.useGlobalBg = checked
                UpdateBgControlsVisibility(checked)
                if checked then
                    ns.ApplyGlobalBackground()
                else
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
            end))
            Add(bgRow)

            UpdateBgControlsVisibility(GudaChatDB.useGlobalBg)
        end
    end

    -------------------------------------------------------------------
    -- Tab 2: Messages
    -------------------------------------------------------------------
    do
        local Add, AddPair = BuildPanel(tabPanels[2])

        Add(CreateSeparator(tabPanels[2], L["SEC_MESSAGES"]))

        AddPair(
            CreateCheckbox(tabPanels[2], L["OPT_CLASS_COLORS"], GudaChatDB.classColors, function(checked)
                GudaChatDB.classColors = checked
                ns.ApplyClassColors()
            end),
            CreateCheckbox(tabPanels[2], L["OPT_SHOW_LEVEL"], GudaChatDB.showLevel, function(checked)
                GudaChatDB.showLevel = checked
            end)
        )

        Add(CreateCheckbox(tabPanels[2], L["OPT_COPYABLE_LINKS"], GudaChatDB.copyLinks, function(checked)
            GudaChatDB.copyLinks = checked
        end))

        Add(CreateSeparator(tabPanels[2], L["SEC_NAME_HIGHLIGHT"]))

        AddPair(
            CreateCheckbox(tabPanels[2], L["OPT_HIGHLIGHT_NAME"], GudaChatDB.highlightName, function(checked)
                GudaChatDB.highlightName = checked
            end),
            CreateCheckbox(tabPanels[2], L["OPT_MENTION_SOUND"], GudaChatDB.highlightSound, function(checked)
                GudaChatDB.highlightSound = checked
            end)
        )

        Add(CreateSeparator(tabPanels[2], L["SEC_EMOJIS"]))

        Add(CreateCheckbox(tabPanels[2], L["OPT_ENABLE_EMOJIS"], GudaChatDB.emojis, function(checked)
            GudaChatDB.emojis = checked
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

        Add(CreateSlider(tabPanels[2], L["OPT_EMOJI_SIZE"], 10, 32, 1, GudaChatDB.emojiSize or ns.DEFAULT_EMOJI_SIZE, function(value)
            GudaChatDB.emojiSize = value
        end))
    end

    -------------------------------------------------------------------
    -- Tab 3: History
    -------------------------------------------------------------------
    do
        local Add, AddPair = BuildPanel(tabPanels[3])

        Add(CreateSeparator(tabPanels[3], L["SEC_HISTORY"]))

        Add(CreateCheckbox(tabPanels[3], L["OPT_ENABLE_HISTORY"], GudaChatDB.historyEnabled ~= false, function(checked)
            GudaChatDB.historyEnabled = checked
            if ns.historyBtn then
                if checked then
                    ns.historyBtn:Show()
                else
                    ns.historyBtn:Hide()
                end
            end
        end))

        AddPair(
            CreateCheckbox(tabPanels[3], L["OPT_LOG_LOOT"], GudaChatDB.logLoot ~= false, function(checked)
                GudaChatDB.logLoot = checked
            end),
            CreateCheckbox(tabPanels[3], L["OPT_LOG_ADDON"], GudaChatDB.logAddon ~= false, function(checked)
                GudaChatDB.logAddon = checked
            end)
        )

        Add(CreateSlider(tabPanels[3], L["OPT_MAX_MESSAGES"], 500, ns.HISTORY_MAX_LIMIT, 100, GudaChatDB.historyMax or 2000, function(value)
            GudaChatDB.historyMax = value
        end))

        Add(CreateSlider(tabPanels[3], L["OPT_MAX_LOOT_LOG"], LOG_CAP_MIN, LOG_CAP_MAX, LOG_CAP_STEP, ns.LootLogCap(), function(value)
            GudaChatDB.lootLogMax = value
            if GudaChatCharDB then ns.TrimLog(GudaChatCharDB.lootLog, value) end
        end))

        Add(CreateSlider(tabPanels[3], L["OPT_MAX_ADDON_LOG"], LOG_CAP_MIN, LOG_CAP_MAX, LOG_CAP_STEP, ns.AddonLogCap(), function(value)
            GudaChatDB.addonLogMax = value
            if GudaChatCharDB then ns.TrimLog(GudaChatCharDB.addonLog, value) end
        end))

        Add(CreateSlider(tabPanels[3], L["OPT_FONT_SIZE"], 8, 24, 1, GudaChatDB.historyFontSize or 14, function(value)
            GudaChatDB.historyFontSize = value
            local histMsgFrame = _G["GudaChatHistoryMsgFrame"]
            if histMsgFrame then
                local fontPath, _, flags = histMsgFrame:GetFont()
                histMsgFrame:SetFont(fontPath, value, flags)
            end
        end))

        local clearBtn = CreateFrame("Button", nil, tabPanels[3], "UIPanelButtonTemplate")
        clearBtn:SetSize(120, 24)
        clearBtn:SetText(L["BTN_CLEAR_HISTORY"])
        local clearContainer = CreateFrame("Frame", nil, tabPanels[3])
        clearContainer:SetHeight(30)
        clearBtn:SetParent(clearContainer)
        clearBtn:SetPoint("LEFT", clearContainer, "LEFT", 0, 0)
        clearBtn:SetScript("OnClick", function()
            StaticPopup_Show("GUDACHAT_CLEAR_HISTORY")
        end)
        Add(clearContainer)
    end

    -------------------------------------------------------------------
    -- Tab 4: Notifications
    -------------------------------------------------------------------
    do
        local Add, AddPair = BuildPanel(tabPanels[4])

        Add(CreateSeparator(tabPanels[4], L["SEC_TAB_BLINK"]))

        AddPair(
            CreateCheckbox(tabPanels[4], L["OPT_ENABLE_NOTIFICATIONS"], GudaChatDB.notifications.general, function(checked)
                GudaChatDB.notifications.general = checked
            end),
            CreateCheckbox(tabPanels[4], L["OPT_GENERAL_TAB"], GudaChatDB.notifications.generalTab, function(checked)
                GudaChatDB.notifications.generalTab = checked
            end)
        )

        AddPair(
            CreateCheckbox(tabPanels[4], L["OPT_NOTIFY_PARTY"], GudaChatDB.notifications.party, function(checked)
                GudaChatDB.notifications.party = checked
            end),
            CreateCheckbox(tabPanels[4], L["OPT_NOTIFY_RAID"], GudaChatDB.notifications.raid, function(checked)
                GudaChatDB.notifications.raid = checked
            end)
        )

        AddPair(
            CreateCheckbox(tabPanels[4], L["OPT_NOTIFY_GUILD"], GudaChatDB.notifications.guild, function(checked)
                GudaChatDB.notifications.guild = checked
            end),
            CreateCheckbox(tabPanels[4], L["OPT_NOTIFY_WHISPERS"], GudaChatDB.notifications.whispers, function(checked)
                GudaChatDB.notifications.whispers = checked
            end)
        )

        Add(CreateSeparator(tabPanels[4], L["SEC_NUMBERED_CHANNELS"]))

        AddPair(
            CreateCheckbox(tabPanels[4], L["OPT_NOTIFY_TRADE"], GudaChatDB.notifications.trade, function(checked)
                GudaChatDB.notifications.trade = checked
            end),
            CreateCheckbox(tabPanels[4], L["OPT_NOTIFY_LFG"], GudaChatDB.notifications.lfg, function(checked)
                GudaChatDB.notifications.lfg = checked
            end)
        )

        Add(CreateCheckbox(tabPanels[4], L["OPT_NOTIFY_OTHER"], GudaChatDB.notifications.other, function(checked)
            GudaChatDB.notifications.other = checked
        end))
    end

    f:SetScript("OnShow", function()
        SelectSettingsTab(1)
    end)

    f:Hide()
    return f
end

local function ToggleSettings()
    if not settingsFrame then
        settingsFrame = CreateSettingsFrame()
    end
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
    end
end
ns.ToggleSettings = ToggleSettings
