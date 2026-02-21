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
    f:SetSize(340, 460)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)

    tinsert(UISpecialFrames, "GudaChatSettingsPopup")

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

    local tabDefs = { "General", "Messages", "History" }
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
        tab:SetScript("OnShow", function(self)
            PanelTemplates_TabResize(self, 8, nil, 36)
            PanelTemplates_DeselectTab(self)
        end)
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
        return Add, ctrls
    end

    -------------------------------------------------------------------
    -- Tab 1: General
    -------------------------------------------------------------------
    do
        local Add = BuildPanel(tabPanels[1])

        Add(CreateSeparator(tabPanels[1], "Chat Window"))

        Add(CreateCheckbox(tabPanels[1], "Lock chat position", GudaChatDB.locked, function(checked)
            GudaChatDB.locked = checked
            ns.ApplyLockState()
        end))

        Add(CreateCheckbox(tabPanels[1], "Disable message fading", not GudaChatDB.fading, function(checked)
            GudaChatDB.fading = not checked
            ChatFrame1:SetFading(GudaChatDB.fading)
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
        end))

        local currentTimestamp = GetCVar("showTimestamps") or "none"
        Add(CreateDropdown(tabPanels[1], "Timestamps", TIMESTAMP_OPTIONS, currentTimestamp, function(value)
            SetCVar("showTimestamps", value)
        end))

        Add(CreateSeparator(tabPanels[1], "Input Bar"))

        Add(CreateCheckbox(tabPanels[1], "Show input bar on top", GudaChatDB.inputPosition == "top", function(checked)
            local wasTop = GudaChatDB.inputPosition == "top"
            GudaChatDB.inputPosition = checked and "top" or "bottom"
            ns.ForEachChatWindow(function(cf, i)
                ns.PositionEditBox(cf, i, GudaChatDB.inputPosition)
            end)
            local point, rel, relPoint, x, y = ChatFrame1:GetPoint(1)
            if point and rel then
                if wasTop and not checked then
                    ChatFrame1:SetPoint(point, rel, relPoint, x, y + ns.INPUT_BAR_CLAMP)
                elseif not wasTop and checked then
                    ChatFrame1:SetPoint(point, rel, relPoint, x, y - ns.INPUT_BAR_CLAMP)
                end
            end
            ns.ApplyChatMargins()
        end))

        Add(CreateSeparator(tabPanels[1], "Tabs"))

        Add(CreateCheckbox(tabPanels[1], "Whisper tab", GudaChatDB.whisperTab, function(checked)
            GudaChatDB.whisperTab = checked
            if checked then
                ns.SetupWhisperFrame()
                if ns.whisperBtn then ns.whisperBtn:Show() end
            else
                if ns.whisperFrame and ns.whisperFrame:IsShown() then
                    FCF_SelectDockFrame(ChatFrame1)
                end
                if ns.whisperBtn then ns.whisperBtn:Hide() end
            end
        end))
    end

    -------------------------------------------------------------------
    -- Tab 2: Messages
    -------------------------------------------------------------------
    do
        local Add = BuildPanel(tabPanels[2])

        Add(CreateSeparator(tabPanels[2], "Messages"))

        Add(CreateCheckbox(tabPanels[2], "Class colored names", GudaChatDB.classColors, function(checked)
            GudaChatDB.classColors = checked
            ns.ApplyClassColors()
        end))

        Add(CreateCheckbox(tabPanels[2], "Show player level", GudaChatDB.showLevel, function(checked)
            GudaChatDB.showLevel = checked
        end))

        Add(CreateCheckbox(tabPanels[2], "Copyable links", GudaChatDB.copyLinks, function(checked)
            GudaChatDB.copyLinks = checked
        end))

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
        local Add = BuildPanel(tabPanels[3])

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

        Add(CreateSlider(tabPanels[3], "Max messages", 100, 2000, 100, GudaChatDB.historyMax or 500, function(value)
            GudaChatDB.historyMax = value
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

    SelectSettingsTab(1)

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
        PanelTemplates_SetTab(settingsFrame, 1)
    end
end
ns.ToggleSettings = ToggleSettings
