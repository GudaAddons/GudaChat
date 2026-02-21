local addonName, ns = ...

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function KillFrame(frame)
    if not frame then return end
    frame:Hide()
    frame:SetAlpha(0)
    frame:SetSize(0.001, 0.001)
    frame.Show = frame.Hide
end

---------------------------------------------------------------------------
-- Edit box positioning
---------------------------------------------------------------------------

local function PositionEditBox(chatFrame, index, position)
    local eb = _G["ChatFrame" .. index .. "EditBox"]
    if not eb then return end
    eb:ClearAllPoints()
    if position == "top" then
        eb:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", -2, 4)
        eb:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 2, 4)
    else
        eb:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", -2, -4)
        eb:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 2, -4)
    end
end

local function StyleEditBox(chatFrame, index)
    local eb = _G["ChatFrame" .. index .. "EditBox"]
    if not eb then return end

    -- Strip Blizzard edit box textures
    for _, region in pairs({eb:GetRegions()}) do
        if region:GetObjectType() == "Texture" then
            region:SetTexture(nil)
            region:Hide()
        end
    end
    local focusLeft = _G["ChatFrame" .. index .. "EditBoxFocusLeft"]
    local focusMid = _G["ChatFrame" .. index .. "EditBoxFocusMid"]
    local focusRight = _G["ChatFrame" .. index .. "EditBoxFocusRight"]
    if focusLeft then focusLeft:SetTexture(nil) end
    if focusMid then focusMid:SetTexture(nil) end
    if focusRight then focusRight:SetTexture(nil) end

    eb:SetHeight(28)

    -- Position based on saved setting
    local pos = GudaChatDB and GudaChatDB.inputPosition or "bottom"
    PositionEditBox(chatFrame, index, pos)

    -- Backdrop
    if not eb.gudaBg then
        local bg = CreateFrame("Frame", nil, eb, "BackdropTemplate")
        bg:SetAllPoints(eb)
        bg:SetFrameLevel(eb:GetFrameLevel() - 1)
        bg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        bg:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
        bg:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
        eb.gudaBg = bg
    end

    eb:SetTextInsets(8, 8, 0, 0)

    local header = _G["ChatFrame" .. index .. "EditBoxHeader"]
    if header then
        header:SetTextColor(0.6, 0.6, 0.6)
    end

    eb:SetAlpha(1)
    eb.chatFrame = chatFrame

    eb:HookScript("OnEditFocusGained", function(self)
        if self.gudaBg then
            self.gudaBg:SetBackdropBorderColor(0.4, 0.7, 1.0, 0.8)
        end
    end)
    eb:HookScript("OnEditFocusLost", function(self)
        if self.gudaBg then
            self.gudaBg:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
        end
    end)
end

---------------------------------------------------------------------------
-- Class colors
---------------------------------------------------------------------------

local function EnableClassColors()
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then
            for _, group in ipairs({
                "SAY", "YELL", "GUILD", "OFFICER", "GUILD_ACHIEVEMENT",
                "ACHIEVEMENT", "WHISPER", "BN_WHISPER", "PARTY", "PARTY_LEADER",
                "RAID", "RAID_LEADER", "RAID_WARNING",
                "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
                "CHANNEL1", "CHANNEL2", "CHANNEL3", "CHANNEL4", "CHANNEL5",
                "CHANNEL6", "CHANNEL7", "CHANNEL8", "CHANNEL9", "CHANNEL10",
            }) do
                SetChatColorNameByClass(group, true)
            end
        end
    end
end

local function DisableClassColors()
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then
            for _, group in ipairs({
                "SAY", "YELL", "GUILD", "OFFICER", "GUILD_ACHIEVEMENT",
                "ACHIEVEMENT", "WHISPER", "BN_WHISPER", "PARTY", "PARTY_LEADER",
                "RAID", "RAID_LEADER", "RAID_WARNING",
                "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
                "CHANNEL1", "CHANNEL2", "CHANNEL3", "CHANNEL4", "CHANNEL5",
                "CHANNEL6", "CHANNEL7", "CHANNEL8", "CHANNEL9", "CHANNEL10",
            }) do
                SetChatColorNameByClass(group, false)
            end
        end
    end
end

local function ApplyClassColors()
    if GudaChatDB.classColors then
        EnableClassColors()
    else
        DisableClassColors()
    end
end

---------------------------------------------------------------------------
-- Copyable links
---------------------------------------------------------------------------

-- Copy popup (reusable frame with an edit box to select+copy text)
local copyFrame

local function ShowCopyPopup(text)
    if not copyFrame then
        local f = CreateFrame("Frame", "GudaChatCopyPopup", UIParent, "BackdropTemplate")
        f:SetSize(320, 50)
        f:SetPoint("CENTER")
        f:SetFrameStrata("TOOLTIP")
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        f:SetBackdropBorderColor(0.4, 0.7, 1.0, 0.8)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            self:SetUserPlaced(false)
        end)

        tinsert(UISpecialFrames, "GudaChatCopyPopup")

        -- Label
        local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
        label:SetText("Ctrl+C to copy, Escape to close")
        label:SetTextColor(0.6, 0.6, 0.6)

        -- Edit box for selecting/copying
        local eb = CreateFrame("EditBox", nil, f, "BackdropTemplate")
        eb:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -20)
        eb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 6)
        eb:SetFontObject(ChatFontNormal)
        eb:SetAutoFocus(true)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        eb:SetScript("OnEditFocusLost", function() f:Hide() end)
        f.editBox = eb

        copyFrame = f
    end

    copyFrame.editBox:SetText(text)
    copyFrame:Show()
    copyFrame.editBox:HighlightText()
    copyFrame.editBox:SetFocus()
end

-- URL patterns to detect in chat
local URL_PATTERNS = {
    -- http(s)://...
    "(https?://[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]+)",
    -- www.domain.tld
    "(www%.[%w%.%-]+%.%a%a+[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
    -- bare domain.tld/path (common TLDs)
    "(%a[%w%-]+%.com[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
    "(%a[%w%-]+%.net[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
    "(%a[%w%-]+%.org[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
    "(%a[%w%-]+%.io[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
    "(%a[%w%-]+%.gg[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
}

local function LinkifyURL(url)
    -- Wrap URL in a clickable garrmission link (custom type for our hook)
    return "|cff33bbff|Hgudachat:url:" .. url .. "|h[" .. url .. "]|h|r"
end

local function FilterAddURLLinks(self, event, msg, ...)
    if not GudaChatDB or not GudaChatDB.copyLinks then return false end

    local changed = false
    for _, pattern in ipairs(URL_PATTERNS) do
        local newMsg = msg:gsub(pattern, function(url)
            -- Don't linkify if already inside a hyperlink
            changed = true
            return LinkifyURL(url)
        end)
        if changed then
            msg = newMsg
            break
        end
    end

    if changed then
        return false, msg, ...
    end
    return false
end

-- Hook hyperlink clicks to handle our custom gudachat:url: links
local function SetupLinkHook()
    local origSetHyperlink = ItemRefTooltip.SetHyperlink

    -- Hook OnHyperlinkClick on each chat frame
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then
            cf:HookScript("OnHyperlinkClick", function(self, link, text, button)
                local url = link:match("^gudachat:url:(.+)$")
                if url then
                    ShowCopyPopup(url)
                end
            end)
        end
    end

    -- Prevent the default tooltip from erroring on our custom link type
    ItemRefTooltip.SetHyperlink = function(self, link, ...)
        if link and link:match("^gudachat:url:") then return end
        return origSetHyperlink(self, link, ...)
    end
end

local function EnableCopyLinks()
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_WARNING", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT_LEADER", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", FilterAddURLLinks)
end

---------------------------------------------------------------------------
-- Chrome stripping
---------------------------------------------------------------------------

local function StripChatChrome(index)
    local cf = _G["ChatFrame" .. index]
    if not cf then return end

    KillFrame(_G["ChatFrame" .. index .. "ButtonFrameUpButton"])
    KillFrame(_G["ChatFrame" .. index .. "ButtonFrameDownButton"])
    KillFrame(_G["ChatFrame" .. index .. "ButtonFrameBottomButton"])
    KillFrame(_G["ChatFrame" .. index .. "ScrollToBottomButton"])
    KillFrame(_G["ChatFrame" .. index .. "ButtonFrameMinimizeButton"])
    KillFrame(_G["ChatFrame" .. index .. "ButtonFrame"])
    KillFrame(_G["ChatFrame" .. index .. "Tab"])

    StyleEditBox(cf, index)
end

local function RehideAllTabs()
    for i = 1, NUM_CHAT_WINDOWS do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab then
            tab:Hide()
            tab:SetAlpha(0)
            tab:SetSize(0.001, 0.001)
            tab.Show = tab.Hide
        end
    end
end

---------------------------------------------------------------------------
-- Scrollbar
---------------------------------------------------------------------------

local function CreateScrollbar(chatFrame)
    local slider = CreateFrame("Slider", "GudaChatScrollbar", chatFrame, "BackdropTemplate")
    slider:SetWidth(6)
    slider:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -2, -2)
    slider:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", -2, 2)
    slider:SetOrientation("VERTICAL")
    slider:SetMinMaxValues(0, 1)
    slider:SetValue(0)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)

    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    slider:SetBackdropColor(0, 0, 0, 0.3)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
    thumb:SetVertexColor(1, 1, 1, 0.4)
    thumb:SetSize(6, 30)
    slider:SetThumbTexture(thumb)

    slider:SetScript("OnEnter", function()
        thumb:SetVertexColor(1, 1, 1, 0.7)
    end)
    slider:SetScript("OnLeave", function()
        thumb:SetVertexColor(1, 1, 1, 0.4)
    end)

    slider:SetScript("OnValueChanged", function(self, value)
        local maxScroll = chatFrame:GetMaxScrollRange()
        local offset = maxScroll - value
        if offset >= 0 then
            chatFrame:SetScrollOffset(offset)
        end
    end)

    local function SyncSlider()
        local maxScroll = chatFrame:GetMaxScrollRange()
        slider:SetMinMaxValues(0, maxScroll)
        local offset = chatFrame:GetScrollOffset()
        slider:SetValue(maxScroll - offset)
    end

    hooksecurefunc(chatFrame, "SetScrollOffset", SyncSlider)

    local ticker = CreateFrame("Frame")
    local elapsed = 0
    ticker:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.2 then
            elapsed = 0
            SyncSlider()
        end
    end)

    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            chatFrame:ScrollUp()
        else
            chatFrame:ScrollDown()
        end
        SyncSlider()
    end)

    ns.scrollbar = slider
    return slider
end

---------------------------------------------------------------------------
-- Settings popup
---------------------------------------------------------------------------

local settingsFrame

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

local function CreateSettingsFrame()
    local f = CreateFrame("Frame", "GudaChatSettingsPopup", UIParent, "ButtonFrameTemplate")
    f:SetSize(340, 348)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:EnableMouse(true)

    tinsert(UISpecialFrames, "GudaChatSettingsPopup")

    ButtonFrameTemplate_HidePortrait(f)
    ButtonFrameTemplate_HideButtonBar(f)
    if f.Inset then f.Inset:Hide() end

    f:SetTitle("GudaChat Settings")

    -- Drag region
    local drag = CreateFrame("Frame", nil, f)
    drag:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    drag:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, 0)
    drag:SetHeight(24)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        f:StartMoving()
        f:SetUserPlaced(false)
    end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        f:SetUserPlaced(false)
    end)

    -- Content area
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -32)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)

    -- Build controls with vertical stacking
    local yOffset = 0
    local controls = {}

    local function AddControl(widget)
        widget:SetParent(content)
        widget:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
        widget:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -yOffset)
        yOffset = yOffset + widget:GetHeight() + 8
        tinsert(controls, widget)
    end

    -- Section: General
    AddControl(CreateSeparator(content, "General"))

    AddControl(CreateCheckbox(content, "Disable message fading", not GudaChatDB.fading, function(checked)
        GudaChatDB.fading = not checked
        ChatFrame1:SetFading(GudaChatDB.fading)
    end))

    AddControl(CreateCheckbox(content, "Class colored names", GudaChatDB.classColors, function(checked)
        GudaChatDB.classColors = checked
        ApplyClassColors()
    end))

    AddControl(CreateCheckbox(content, "Copyable links", GudaChatDB.copyLinks, function(checked)
        GudaChatDB.copyLinks = checked
    end))

    -- Section: Input Bar
    AddControl(CreateSeparator(content, "Input Bar"))

    local inputTopCb = CreateCheckbox(content, "Show input bar on top", GudaChatDB.inputPosition == "top", function(checked)
        GudaChatDB.inputPosition = checked and "top" or "bottom"
        for i = 1, NUM_CHAT_WINDOWS do
            PositionEditBox(_G["ChatFrame" .. i], i, GudaChatDB.inputPosition)
        end
    end)
    AddControl(inputTopCb)

    f.controls = controls
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

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

SLASH_GUDACHAT1 = "/gudachat"
SLASH_GUDACHAT2 = "/gc"
SlashCmdList["GUDACHAT"] = function(msg)
    msg = strtrim(msg):lower()
    if msg == "" or msg == "settings" or msg == "options" then
        ToggleSettings()
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffGudaChat|r commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/gc|r — open settings")
    end
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        GudaChatDB = GudaChatDB or {}
        if GudaChatDB.fading == nil then
            GudaChatDB.fading = false
        end
        if GudaChatDB.inputPosition == nil then
            GudaChatDB.inputPosition = "bottom"
        end
        if GudaChatDB.classColors == nil then
            GudaChatDB.classColors = true
        end
        if GudaChatDB.copyLinks == nil then
            GudaChatDB.copyLinks = true
        end
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        for i = 1, NUM_CHAT_WINDOWS do
            StripChatChrome(i)
        end

        if GeneralDockManagerOverflowButton then
            KillFrame(GeneralDockManagerOverflowButton)
        end
        if GeneralDockManager then
            KillFrame(GeneralDockManager)
        end

        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            for i = 1, NUM_CHAT_WINDOWS do
                StripChatChrome(i)
            end
        end)

        if FCF_DockUpdate then
            hooksecurefunc("FCF_DockUpdate", RehideAllTabs)
        end
        if FCF_SelectDockFrame then
            hooksecurefunc("FCF_SelectDockFrame", RehideAllTabs)
        end

        ChatFrame1:SetFading(GudaChatDB.fading)
        ApplyClassColors()
        EnableCopyLinks()
        SetupLinkHook()
        CreateScrollbar(ChatFrame1)

        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffGudaChat|r loaded — type |cffffd200/gc|r for settings")
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
