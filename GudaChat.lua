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
-- Chat header bar (hover-reveal, icon buttons)
---------------------------------------------------------------------------

local ASSET_PATH = "Interface\\AddOns\\GudaChat\\Assets\\"
local ICON_SIZE = 16
local HEADER_HEIGHT = 22
local chatHeader

local function GetChatTabName(index)
    local tab = _G["ChatFrame" .. index .. "Tab"]
    if tab then
        local name = tab.Text and tab.Text:GetText() or tab:GetText()
        if name and name ~= "" then return name end
    end
    return "Chat " .. index
end

-- Small icon button helper
local function CreateIconButton(parent, texturePath, size, tooltip)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(texturePath)
    icon:SetVertexColor(0.7, 0.7, 0.7, 0.9)
    btn.icon = icon

    btn:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1, 1)
        if tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip, 1, 1, 1)
            GameTooltip:Show()
        end
        -- Keep header visible while hovering buttons
        if chatHeader then chatHeader:SetAlpha(1) end
    end)
    btn:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(0.7, 0.7, 0.7, 0.9)
        GameTooltip:Hide()
    end)

    return btn
end

local function CreateChatHeader(parentFrame)
    local header = CreateFrame("Frame", "GudaChatHeader", UIParent, "BackdropTemplate")
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("BOTTOMLEFT", parentFrame, "TOPLEFT", -2, 0)
    header:SetPoint("BOTTOMRIGHT", parentFrame, "TOPRIGHT", 2, 0)
    header:SetFrameStrata("MEDIUM")
    header:SetFrameLevel(100)
    header:SetAlpha(0)

    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    header:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
    header:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)

    -- Hover detection zone (covers header + chat frame area)
    local hoverZone = CreateFrame("Frame", nil, UIParent)
    hoverZone:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    hoverZone:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", 0, 0)
    hoverZone:SetFrameStrata("BACKGROUND")
    hoverZone:EnableMouse(false)

    local fadeIn, fadeOut
    local isHovering = false

    local function ShowHeader()
        if isHovering then return end
        isHovering = true
        if fadeOut then fadeOut:Stop() end
        fadeIn = header:CreateAnimationGroup()
        local anim = fadeIn:CreateAnimation("Alpha")
        anim:SetFromAlpha(header:GetAlpha())
        anim:SetToAlpha(1)
        anim:SetDuration(0.15)
        fadeIn:SetScript("OnFinished", function() header:SetAlpha(1) end)
        fadeIn:Play()
    end

    local function HideHeader()
        if not isHovering then return end
        isHovering = false
        -- Delay hide slightly so moving between buttons doesn't flicker
        C_Timer.After(0.3, function()
            if isHovering then return end
            -- Check if mouse is still over header or chat area
            if header:IsMouseOver() or parentFrame:IsMouseOver() then
                isHovering = true
                return
            end
            if fadeIn then fadeIn:Stop() end
            fadeOut = header:CreateAnimationGroup()
            local anim = fadeOut:CreateAnimation("Alpha")
            anim:SetFromAlpha(header:GetAlpha())
            anim:SetToAlpha(0)
            anim:SetDuration(0.25)
            fadeOut:SetScript("OnFinished", function() header:SetAlpha(0) end)
            fadeOut:Play()
        end)
    end

    -- Detect hover via OnUpdate on a monitoring frame
    local monitor = CreateFrame("Frame")
    monitor:SetScript("OnUpdate", function()
        local over = header:IsMouseOver() or parentFrame:IsMouseOver()
        -- Also check if any dropdown is open
        local dropdownOpen = GudaChatTabDropdown and GudaChatTabDropdown:IsShown()
        if over or dropdownOpen then
            ShowHeader()
        else
            HideHeader()
        end
    end)

    header:EnableMouse(true)

    -------------------------------------------------------------------
    -- Left side: Tab switcher icon + dropdown
    -------------------------------------------------------------------
    local tabBtn = CreateIconButton(header, ASSET_PATH .. "characters.png", ICON_SIZE, "Chat Tabs")
    tabBtn:SetPoint("LEFT", header, "LEFT", 4, 0)

    -- Tab dropdown
    local dropdown = CreateFrame("Frame", "GudaChatTabDropdown", tabBtn, "BackdropTemplate")
    dropdown:SetFrameStrata("TOOLTIP")
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    dropdown:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    dropdown:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
    dropdown:Hide()

    local menuButtons = {}

    local function CloseDropdown()
        dropdown:Hide()
    end

    local function RefreshDropdown()
        for _, mb in ipairs(menuButtons) do
            mb:Hide()
            mb:SetParent(nil)
        end
        wipe(menuButtons)

        local yOff = -4
        local maxW = 60

        for i = 1, NUM_CHAT_WINDOWS do
            local cf = _G["ChatFrame" .. i]
            local tab = _G["ChatFrame" .. i .. "Tab"]
            if cf and tab then
                local name = GetChatTabName(i)
                local isDocked = cf.isDocked or (i == 1)
                if isDocked then
                    local mb = CreateFrame("Button", nil, dropdown)
                    mb:SetHeight(20)
                    mb:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 4, yOff)
                    mb:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", -4, yOff)

                    local mbText = mb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    mbText:SetPoint("LEFT", mb, "LEFT", 6, 0)
                    mbText:SetText(name)

                    local isActive = (SELECTED_CHAT_FRAME == cf) or (DEFAULT_CHAT_FRAME == cf and i == 1)
                    mbText:SetTextColor(isActive and 1 or 0.7, isActive and 1 or 0.7, isActive and 1 or 0.7, isActive and 1 or 0.8)

                    mb:SetScript("OnEnter", function()
                        mbText:SetTextColor(1, 1, 1, 1)
                    end)
                    mb:SetScript("OnLeave", function()
                        local active = (SELECTED_CHAT_FRAME == cf) or (DEFAULT_CHAT_FRAME == cf and i == 1)
                        if not active then
                            mbText:SetTextColor(0.7, 0.7, 0.7, 0.8)
                        end
                    end)

                    local frameIndex = i
                    mb:SetScript("OnClick", function()
                        FCF_SelectDockFrame(_G["ChatFrame" .. frameIndex])
                        CloseDropdown()
                    end)

                    local tw = mbText:GetStringWidth() + 16
                    if tw > maxW then maxW = tw end
                    yOff = yOff - 20
                    tinsert(menuButtons, mb)
                end
            end
        end

        dropdown:SetSize(maxW + 8, math.abs(yOff) + 4)
        dropdown:ClearAllPoints()
        dropdown:SetPoint("TOPLEFT", tabBtn, "BOTTOMLEFT", -4, -2)
    end

    tabBtn:SetScript("OnClick", function()
        if dropdown:IsShown() then
            CloseDropdown()
        else
            RefreshDropdown()
            dropdown:Show()
        end
    end)

    -- Close dropdown when clicking outside
    local closer = CreateFrame("Frame", nil, dropdown)
    closer:SetScript("OnUpdate", function()
        if dropdown:IsShown() and not dropdown:IsMouseOver() and not tabBtn:IsMouseOver() then
            if IsMouseButtonDown("LeftButton") then
                CloseDropdown()
            end
        end
    end)

    -------------------------------------------------------------------
    -- Left side: Combat log icon
    -------------------------------------------------------------------
    local combatBtn = CreateIconButton(header, ASSET_PATH .. "combat.png", ICON_SIZE, "Combat Log")
    combatBtn:SetPoint("LEFT", tabBtn, "RIGHT", 6, 0)

    combatBtn:SetScript("OnClick", function()
        if ChatFrame2 then
            if ChatFrame2:IsShown() then
                FCF_SelectDockFrame(ChatFrame1)
            else
                FCF_SelectDockFrame(ChatFrame2)
            end
        end
    end)

    -- Keep existing OnEnter/OnLeave for icon color + tooltip
    combatBtn:HookScript("OnClick", function() CloseDropdown() end)

    -------------------------------------------------------------------
    -- Center: Current tab name
    -------------------------------------------------------------------
    local tabLabel = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tabLabel:SetPoint("CENTER", header, "CENTER", 0, 0)
    tabLabel:SetTextColor(0.6, 0.6, 0.6, 0.8)
    tabLabel:SetText(GetChatTabName(1))

    -- Update label when tabs switch
    hooksecurefunc("FCF_SelectDockFrame", function(cf)
        if not cf then return end
        for i = 1, NUM_CHAT_WINDOWS do
            if _G["ChatFrame" .. i] == cf then
                tabLabel:SetText(GetChatTabName(i))
                break
            end
        end
    end)

    -------------------------------------------------------------------
    -- Right side: Settings icon
    -------------------------------------------------------------------
    local settingsBtn = CreateIconButton(header, ASSET_PATH .. "cog.png", ICON_SIZE, "Settings")
    settingsBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)

    settingsBtn:SetScript("OnClick", function()
        ns.ToggleSettings()
        CloseDropdown()
    end)

    chatHeader = header
    ns.chatHeader = header
    return header
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

        -- Hook all functions that can show/restore tabs
        local tabHookTargets = {
            "FCF_DockUpdate",
            "FCF_SelectDockFrame",
            "FCF_OpenNewWindow",
            "FCF_Close",
            "FCF_DockFrame",
            "FCF_UnDockFrame",
            "FCF_SetTabPosition",
            "FCF_Tab_OnShow",
        }
        for _, funcName in ipairs(tabHookTargets) do
            if _G[funcName] then
                hooksecurefunc(funcName, RehideAllTabs)
            end
        end

        -- Also catch channel events that trigger tab changes
        local tabWatcher = CreateFrame("Frame")
        tabWatcher:RegisterEvent("CHANNEL_UI_UPDATE")
        tabWatcher:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
        tabWatcher:RegisterEvent("UPDATE_CHAT_WINDOWS")
        tabWatcher:SetScript("OnEvent", function()
            C_Timer.After(0.1, RehideAllTabs)
        end)

        ChatFrame1:SetFading(GudaChatDB.fading)
        ApplyClassColors()
        EnableCopyLinks()
        SetupLinkHook()
        CreateScrollbar(ChatFrame1)
        CreateChatHeader(ChatFrame1)

        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffGudaChat|r loaded — type |cffffd200/gc|r for settings")
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
