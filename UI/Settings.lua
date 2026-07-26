local addonName, ns = ...

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

    local text = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
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

    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", container, "LEFT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetTextColor(0.9, 0.75, 0.3)
    text:SetText(label)

    local line = container:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", text, "RIGHT", 6, 0)
    line:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    line:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    return container
end

local function CreateSlider(parent, label, minVal, maxVal, step, currentVal, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(36)

    local text = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
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

        valueText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
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

local FONT_OPTIONS = {
    { label = "Default (Friz Quadrata)", value = "Fonts\\FRIZQT__.TTF" },
    { label = "Arial Narrow",           value = "Fonts\\ARIALN.TTF" },
    { label = "Morpheus",               value = "Fonts\\MORPHEUS.TTF" },
    { label = "Skurri",                 value = "Fonts\\SKURRI.TTF" },
    { label = "Fira Sans Medium",       value = "Interface\\AddOns\\GudaChat\\Assets\\Fonts\\FiraSans-Medium.ttf" },
    { label = "Ubuntu",                 value = "Interface\\AddOns\\GudaChat\\Assets\\Fonts\\Ubuntu-Regular.ttf" },
    { label = "Archivo Black",          value = "Interface\\AddOns\\GudaChat\\Assets\\Fonts\\ArchivoBlack-Regular.ttf" },
    { label = "Audiowide",              value = "Interface\\AddOns\\GudaChat\\Assets\\Fonts\\Audiowide-Regular.ttf" },
}

local function ApplyChatFont(fontPath)
    ns.ForEachChatWindow(function(cf)
        local _, size, flags = cf:GetFont()
        cf:SetFont(fontPath, size, flags)
    end)
    local histMsgFrame = _G["GudaChatHistoryMsgFrame"]
    if histMsgFrame then
        local _, size, flags = histMsgFrame:GetFont()
        histMsgFrame:SetFont(fontPath, size, flags)
    end
end
ns.ApplyChatFont = ApplyChatFont

local function ApplyChatFontSize(size)
    ns.ForEachChatWindow(function(cf)
        local font, _, flags = cf:GetFont()
        cf:SetFont(font, size, flags)
    end)
end
ns.ApplyChatFontSize = ApplyChatFontSize

local TIMESTAMP_OPTIONS = {
    { label = "None",          value = "none" },
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

local function CreateDropdown(parent, label, options, currentValue, onChange)
    dropdownCounter = dropdownCounter + 1
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(30)

    local text = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", container, "LEFT", 0, 0)
    text:SetText(label)

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

---------------------------------------------------------------------------
-- Clear history popup
---------------------------------------------------------------------------

StaticPopupDialogs["GUDACHAT_CLEAR_HISTORY"] = {
    text = "Are you sure you want to clear all chat history?",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function()
        if GudaChatDB and GudaChatDB.history then
            for k in pairs(GudaChatDB.history) do
                wipe(GudaChatDB.history[k])
            end
        end
        if GudaChatDB and GudaChatDB.lootLog then wipe(GudaChatDB.lootLog) end
        if GudaChatDB and GudaChatDB.addonLog then wipe(GudaChatDB.addonLog) end
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
    local f = CreateFrame("Frame", "GudaChatSettingsPopup", UIParent, "ButtonFrameTemplate")
    f:SetSize(400, 520)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)

    tinsert(UISpecialFrames, "GudaChatSettingsPopup")

    -- Close on entering combat
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:SetScript("OnEvent", function(self) self:Hide() end)

    ButtonFrameTemplate_HidePortrait(f)
    ButtonFrameTemplate_HideButtonBar(f)
    if f.Inset then f.Inset:Hide() end

    f:SetTitle("GudaChat Settings")

    ns.CreateDragRegion(f)

    -------------------------------------------------------------------
    -- Tabs (Blizzard style)
    -------------------------------------------------------------------
    local tabTemplate
    if DoesTemplateExist and DoesTemplateExist("PanelTopTabButtonTemplate") then
        tabTemplate = "PanelTopTabButtonTemplate"
    else
        tabTemplate = "TabButtonTemplate"
    end

    local tabDefs = { "General", "Messages", "History", "Notifications" }
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

        Add(CreateSeparator(tabPanels[1], "Chat Window"))

        AddPair(
            CreateCheckbox(tabPanels[1], "Lock chat position", GudaChatDB.locked, function(checked)
                GudaChatDB.locked = checked
                ns.ApplyLockState()
            end),
            CreateCheckbox(tabPanels[1], "Disable message fading", not GudaChatDB.fading, function(checked)
                GudaChatDB.fading = not checked
                ChatFrame1:SetFading(GudaChatDB.fading)
            end)
        )

        local currentFont = GudaChatDB.chatFont or "Fonts\\FRIZQT__.TTF"
        Add(CreateDropdown(tabPanels[1], "Font", FONT_OPTIONS, currentFont, function(value)
            GudaChatDB.chatFont = value
            ApplyChatFont(value)
        end))

        Add(CreateCheckbox(tabPanels[1], "Hide scrollbar", GudaChatDB.hideScrollbar, function(checked)
            GudaChatDB.hideScrollbar = checked
            ns.ForEachChatWindow(function(cf)
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
        Add(CreateDropdown(tabPanels[1], "Timestamps", TIMESTAMP_OPTIONS, currentTimestamp, function(value)
            SetCVar("showTimestamps", value)
        end))

        Add(CreateSeparator(tabPanels[1], "Input Bar"))

        AddPair(
            CreateCheckbox(tabPanels[1], "Input bar on top", GudaChatDB.inputPosition == "top", function(checked)
                GudaChatDB.inputPosition = checked and "top" or "bottom"
                ns.ApplyInputBarPosition()
            end),
            CreateCheckbox(tabPanels[1], "Transparent input bar", GudaChatDB.transparentInput, function(checked)
                GudaChatDB.transparentInput = checked
                ns.ApplyTransparentInput()
            end)
        )

        Add(CreateSeparator(tabPanels[1], "Tabs"))

        AddPair(
            CreateCheckbox(tabPanels[1], "Show tab bar", GudaChatDB.showTabBar, function(checked)
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
            CreateCheckbox(tabPanels[1], "Inline tab bar", GudaChatDB.inlineTabBar, function(checked)
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

        Add(CreateCheckbox(tabPanels[1], "Whisper tab", GudaChatDB.whisperTab, function(checked)
            GudaChatDB.whisperTab = checked
            if checked then
                ns.SetupWhisperFrame()
            else
                -- Restore the player's whisper mode and route whispers back to General.
                ns.ApplyWhisperRouting()
                if ns.whisperFrame and ns.whisperFrame:IsShown() then
                    C_Timer.After(0, function() FCF_SelectDockFrame(ChatFrame1) end)
                end
            end
            if ns.RefreshChatSubTabs then ns.RefreshChatSubTabs() end
            if ns.RefreshInlineTabs then ns.RefreshInlineTabs() end
        end))

        Add(CreateSeparator(tabPanels[1], "Background"))

        do
            local bgRow = CreateFrame("Frame", nil, tabPanels[1])
            bgRow:SetHeight(36)

            local bgAlphaPercent = math.floor((GudaChatDB.globalBgAlpha or 0) * 100)
            local bgSlider = CreateSlider(bgRow, "Opacity", 0, 100, 5, bgAlphaPercent, function(value)
                GudaChatDB.globalBgAlpha = value / 100
                if GudaChatDB.useGlobalBg then
                    ns.ApplyGlobalBackground()
                end
            end)
            bgSlider:SetParent(bgRow)
            bgSlider:ClearAllPoints()
            bgSlider:SetPoint("TOPLEFT", bgRow, "TOPLEFT", 0, 0)
            bgSlider:SetPoint("RIGHT", bgRow, "RIGHT", -34, 0)

            local bgColor = GudaChatDB.globalBgColor or { r = 0.08, g = 0.08, b = 0.08 }
            local swatch = CreateFrame("Button", nil, bgRow)
            swatch:SetSize(20, 20)
            swatch:SetPoint("RIGHT", bgRow, "RIGHT", 0, 0)

            local swatchTex = swatch:CreateTexture(nil, "ARTWORK")
            swatchTex:SetAllPoints()
            swatchTex:SetTexture("Interface\\Buttons\\WHITE8x8")
            swatchTex:SetVertexColor(bgColor.r, bgColor.g, bgColor.b, math.max(GudaChatDB.globalBgAlpha or 0, 0.3))

            local swatchBorder = swatch:CreateTexture(nil, "OVERLAY")
            swatchBorder:SetSize(22, 22)
            swatchBorder:SetPoint("CENTER", swatch, "CENTER")
            swatchBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
            swatchBorder:SetVertexColor(0.5, 0.5, 0.5, 0.8)
            swatchBorder:SetDrawLayer("ARTWORK", -1)

            swatch:SetScript("OnClick", function()
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
                if ColorPickerFrame.SetupColorPickerAndShow then
                    ColorPickerFrame:SetupColorPickerAndShow(info)
                else
                    ColorPickerFrame:SetColorRGB(info.r, info.g, info.b)
                    ColorPickerFrame.hasOpacity = false
                    ColorPickerFrame.func = info.swatchFunc
                    ColorPickerFrame.cancelFunc = info.cancelFunc
                    ColorPickerFrame.previousValues = { r = info.r, g = info.g, b = info.b }
                    ColorPickerFrame:Hide()
                    ColorPickerFrame:Show()
                end
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

            Add(CreateCheckbox(tabPanels[1], "Override per-tab backgrounds", GudaChatDB.useGlobalBg, function(checked)
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

        Add(CreateSeparator(tabPanels[2], "Messages"))

        AddPair(
            CreateCheckbox(tabPanels[2], "Class colored names", GudaChatDB.classColors, function(checked)
                GudaChatDB.classColors = checked
                ns.ApplyClassColors()
            end),
            CreateCheckbox(tabPanels[2], "Show player level", GudaChatDB.showLevel, function(checked)
                GudaChatDB.showLevel = checked
            end)
        )

        Add(CreateCheckbox(tabPanels[2], "Copyable links", GudaChatDB.copyLinks, function(checked)
            GudaChatDB.copyLinks = checked
        end))

        Add(CreateSeparator(tabPanels[2], "Name Highlight"))

        AddPair(
            CreateCheckbox(tabPanels[2], "Highlight my name", GudaChatDB.highlightName, function(checked)
                GudaChatDB.highlightName = checked
            end),
            CreateCheckbox(tabPanels[2], "Sound on mention", GudaChatDB.highlightSound, function(checked)
                GudaChatDB.highlightSound = checked
            end)
        )

        Add(CreateSeparator(tabPanels[2], "Emojis"))

        Add(CreateCheckbox(tabPanels[2], "Enable emojis", GudaChatDB.emojis, function(checked)
            GudaChatDB.emojis = checked
            ns.ForEachChatWindow(function(_, i)
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

        Add(CreateSlider(tabPanels[2], "Emoji size", 10, 32, 1, GudaChatDB.emojiSize or ns.DEFAULT_EMOJI_SIZE, function(value)
            GudaChatDB.emojiSize = value
        end))
    end

    -------------------------------------------------------------------
    -- Tab 3: History
    -------------------------------------------------------------------
    do
        local Add, AddPair = BuildPanel(tabPanels[3])

        Add(CreateSeparator(tabPanels[3], "History"))

        Add(CreateCheckbox(tabPanels[3], "Enable history", GudaChatDB.historyEnabled ~= false, function(checked)
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
            CreateCheckbox(tabPanels[3], "Log loot", GudaChatDB.logLoot ~= false, function(checked)
                GudaChatDB.logLoot = checked
            end),
            CreateCheckbox(tabPanels[3], "Log addon messages", GudaChatDB.logAddon ~= false, function(checked)
                GudaChatDB.logAddon = checked
            end)
        )

        Add(CreateSlider(tabPanels[3], "Max messages", 500, 4000, 100, GudaChatDB.historyMax or 2000, function(value)
            GudaChatDB.historyMax = value
        end))

        Add(CreateSlider(tabPanels[3], "Font size", 8, 24, 1, GudaChatDB.historyFontSize or 14, function(value)
            GudaChatDB.historyFontSize = value
            local histMsgFrame = _G["GudaChatHistoryMsgFrame"]
            if histMsgFrame then
                local fontPath, _, flags = histMsgFrame:GetFont()
                histMsgFrame:SetFont(fontPath, value, flags)
            end
        end))

        local clearBtn = CreateFrame("Button", nil, tabPanels[3], "UIPanelButtonTemplate")
        clearBtn:SetSize(120, 24)
        clearBtn:SetText("Clear History")
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

        Add(CreateSeparator(tabPanels[4], "Tab Blink Notifications"))

        AddPair(
            CreateCheckbox(tabPanels[4], "Enable notifications", GudaChatDB.notifications.general, function(checked)
                GudaChatDB.notifications.general = checked
            end),
            CreateCheckbox(tabPanels[4], "General tab", GudaChatDB.notifications.generalTab, function(checked)
                GudaChatDB.notifications.generalTab = checked
            end)
        )

        AddPair(
            CreateCheckbox(tabPanels[4], "Party", GudaChatDB.notifications.party, function(checked)
                GudaChatDB.notifications.party = checked
            end),
            CreateCheckbox(tabPanels[4], "Raid / Instance", GudaChatDB.notifications.raid, function(checked)
                GudaChatDB.notifications.raid = checked
            end)
        )

        AddPair(
            CreateCheckbox(tabPanels[4], "Guild / Officer", GudaChatDB.notifications.guild, function(checked)
                GudaChatDB.notifications.guild = checked
            end),
            CreateCheckbox(tabPanels[4], "Whispers", GudaChatDB.notifications.whispers, function(checked)
                GudaChatDB.notifications.whispers = checked
            end)
        )

        Add(CreateSeparator(tabPanels[4], "Numbered Channels"))

        AddPair(
            CreateCheckbox(tabPanels[4], "Trade", GudaChatDB.notifications.trade, function(checked)
                GudaChatDB.notifications.trade = checked
            end),
            CreateCheckbox(tabPanels[4], "LookingForGroup", GudaChatDB.notifications.lfg, function(checked)
                GudaChatDB.notifications.lfg = checked
            end)
        )

        Add(CreateCheckbox(tabPanels[4], "Other (custom channels)", GudaChatDB.notifications.other, function(checked)
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
