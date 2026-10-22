local addonName, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Chat header bar: hover-reveal, drag to move, icon buttons, the tab label with its
-- window dropdown, and the inline tabs. The tab bars, menus and selection logic live in
-- their own files (UI/Tabs, ContextMenu, ChatTypeMenu, CombatLogTabs, Selection).
---------------------------------------------------------------------------

local ICON_SIZE = 16
local HEADER_HEIGHT = 22
local ICON_GAP = 6
local HEADER_HIDE_DELAY = 0.3
local INLINE_FIRST_GAP = 8
local INLINE_MIN_SPACE = 60
local TAB_LABEL_MIN_WIDTH = 40
local DROPDOWN_ITEM_HEIGHT = 20
local DROPDOWN_MIN_WIDTH = 60

local C = ns.Theme.C

-- True when the mouse is over the scrollbar of a visible chat frame
local function IsOverScrollbar()
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf and cf.gudaScrollbar and cf:IsVisible() and cf.gudaScrollbar:IsMouseOver() then
            return true
        end
    end
    return false
end

-- True while the cursor is anywhere in the chat UI: header, chat frame, tab bars,
-- scrollbars, or one of the open menus
local function IsOverChatUI(header, parentFrame)
    local combatSubTabs, chatSubTabs = ns.combatSubTabs, ns.chatSubTabs
    if header:IsMouseOver() or parentFrame:IsMouseOver() then return true end
    if combatSubTabs and combatSubTabs:IsShown() and combatSubTabs:IsMouseOver() then return true end
    if chatSubTabs and chatSubTabs:IsShown() and chatSubTabs:GetAlpha() > 0 and chatSubTabs:IsMouseOver() then return true end
    if IsOverScrollbar() then return true end
    if GudaChatTabDropdown and GudaChatTabDropdown:IsShown() then return true end
    if GudaChatTypeDropdown and GudaChatTypeDropdown:IsShown() then return true end
    if GudaChatEmoteSubMenu and GudaChatEmoteSubMenu:IsShown() then return true end
    if DropDownList1 and DropDownList1:IsShown() then return true end
    if ns.IsContextMenuShown() or ns.IsFontSubMenuShown() then return true end
    if GudaChatInlineTabOverflow and GudaChatInlineTabOverflow:IsShown() and GudaChatInlineTabOverflow:IsMouseOver() then return true end
    return false
end

local function SetCombatSubTabsAlpha(alpha)
    local combatSubTabs = ns.combatSubTabs
    if combatSubTabs and combatSubTabs:IsShown() then combatSubTabs:SetAlpha(alpha) end
end

-- Fades the header in while the mouse is over the chat UI and out 0.3 s after it leaves
-- (unless an inline tab is blinking). The monitor is a child of the header and polls every
-- HOVER_CHECK_INTERVAL; a generation counter drops stale hide timers.
local function AddHeaderHoverFade(header, parentFrame)
    local fadeIn = ns.CreateFade(header, 1, ns.FADE_IN_DURATION)
    fadeIn:HookScript("OnFinished", function()
        SetCombatSubTabsAlpha(1)
    end)
    local fadeOut = ns.CreateFade(header, 0, ns.FADE_OUT_DURATION)
    fadeOut:HookScript("OnFinished", function()
        if ns.combatSubTabs then ns.combatSubTabs:SetAlpha(0) end
    end)
    local isHovering = false
    local hidePending = false
    local hideTimerGen = 0

    local function ShowHeader()
        if ns.hideHeaderForInput then return end
        if isHovering then return end
        isHovering = true
        hidePending = false
        hideTimerGen = hideTimerGen + 1
        fadeOut:Stop()
        fadeIn:PlayFromCurrent()
        SetCombatSubTabsAlpha(header:GetAlpha())
        ns.FadeInScrollbar()
    end
    ns.ShowChatHeader = ShowHeader

    local function HideHeader()
        if not isHovering then return end
        isHovering = false
        hidePending = true
        hideTimerGen = hideTimerGen + 1
        local gen = hideTimerGen
        C_Timer.After(HEADER_HIDE_DELAY, function()
            if gen ~= hideTimerGen then return end
            hidePending = false
            if isHovering then return end
            if IsOverChatUI(header, parentFrame)
                or (GudaChatDB.inlineTabBar and ns.HasBlinkingTabs()) then
                isHovering = true
                return
            end
            fadeIn:Stop()
            fadeOut:PlayFromCurrent()
            SetCombatSubTabsAlpha(header:GetAlpha())
            ns.FadeOutScrollbar()
        end)
    end

    -- Safety net for a header left visible while the hover state says hidden (anything
    -- that set its alpha outside ShowHeader): treat it as hovered so the normal delayed
    -- fade-out runs.
    local function HideStrayHeader()
        if isHovering or hidePending or fadeOut:IsPlaying() then return end
        if header:GetAlpha() <= 0 then return end
        isHovering = true
        HideHeader()
    end

    local monitor = CreateFrame("Frame", nil, header)
    local sinceHoverCheck = 0
    monitor:SetScript("OnUpdate", function(self, elapsed)
        sinceHoverCheck = sinceHoverCheck + elapsed
        if sinceHoverCheck < ns.HOVER_CHECK_INTERVAL then return end
        sinceHoverCheck = 0
        local overChat = IsOverChatUI(header, parentFrame)
        ns.UpdateIdleText(overChat)
        if ns.hideHeaderForInput then
            if isHovering then
                isHovering = false
                fadeIn:Stop()
                header:SetAlpha(0)
                if ns.combatSubTabs then ns.combatSubTabs:SetAlpha(0) end
                ns.FadeOutScrollbar()
            end
            return
        end
        if overChat then
            ShowHeader()
        else
            HideHeader()
            HideStrayHeader()
        end
    end)
end

-- Dragging the header moves the chat (unless locked). An OnUpdate catches interrupted
-- drags (e.g. targeting a unit mid-drag) and keeps docked frames in step; the position is
-- saved and locked against UIParentPanelManager when the drag ends.
local function AddHeaderDrag(header, parentFrame)
    header:RegisterForDrag("LeftButton")

    local function FinishDrag(self)
        if not self.isDragging then return end
        parentFrame:StopMovingOrSizing()
        parentFrame:SetUserPlaced(false)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
        ns.SaveChatPosition()
        ns.cf1PositionLocked = true
    end

    header:SetScript("OnDragStart", function(self)
        if GudaChatDB.locked then return end
        ns.cf1PositionLocked = false
        parentFrame:SetMovable(true)
        parentFrame:StartMoving()
        self.isDragging = true
        self:SetScript("OnUpdate", function(self)
            if not IsMouseButtonDown("LeftButton") then
                FinishDrag(self)
            else
                ns.SyncDockedFrames()
            end
        end)
    end)
    header:SetScript("OnDragStop", FinishDrag)

    header:SetScript("OnEnter", function(self)
        if not GudaChatDB.locked then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L["TIP_DRAG_TO_MOVE"], 0.7, 0.7, 0.7)
            ns.SetTooltipFontSize(12)
            GameTooltip:Show()
        end
    end)
    header:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- The window list shown when the tab label is clicked: every docked window except the
-- combat log, active one bright
local function RefreshTabDropdown(dropdown, onPicked)
    local yOff = -4
    local maxW = DROPDOWN_MIN_WIDTH
    local count = 0
    local selectedIdx = ns.GetSelectedChatFrameIndex()

    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if cf and tab and (cf.isDocked or i == 1) and i ~= 2 then
            local name = ns.GetChatTabName(i)
            count = count + 1
            local mb = ns.GetMenuItem(dropdown, count, DROPDOWN_ITEM_HEIGHT)
            mb:RegisterForClicks("LeftButtonUp")
            mb:ClearAllPoints()
            mb:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 4, yOff)
            mb:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", -4, yOff)
            mb:Show()

            local mbText = mb.text
            mbText:ClearAllPoints()
            mbText:SetPoint("LEFT", mb, "LEFT", 6, 0)
            mbText:SetText(name)

            local col = ns.GetTabColor(name, i)
            if selectedIdx == i then
                ns.Theme.PaintTab(mbText, col, "active")
            else
                ns.Theme.PaintTab(mbText, col, "inactive")
            end
            mb:SetScript("OnEnter", function()
                ns.Theme.PaintTab(mbText, col, "hover")
            end)
            mb:SetScript("OnLeave", function()
                if ns.GetSelectedChatFrameIndex() ~= i then
                    ns.Theme.PaintTab(mbText, col, "inactive")
                end
            end)
            mb:SetScript("OnClick", function()
                ns.SafeSelectDockFrame(_G["ChatFrame" .. i])
                onPicked()
            end)

            maxW = math.max(maxW, mbText:GetStringWidth() + 16)
            yOff = yOff - DROPDOWN_ITEM_HEIGHT
        end
    end
    ns.HideMenuItemsFrom(dropdown, count + 1)
    dropdown:SetSize(maxW + 8, math.abs(yOff) + 4)
end

-- The header's controls. Left: General (logo), combat log, history. Centre: the current
-- tab's name, which opens the window list (left click) or the window menu (right click).
-- Right: settings, chat channels, chat type menu.
local function CreateHeaderControls(header)
    local controls = {}

    local dropdown = CreateFrame("Frame", "GudaChatTabDropdown", header, "BackdropTemplate")
    dropdown:SetFrameStrata("TOOLTIP")
    ns.ApplyDarkBackdrop(dropdown)
    dropdown:Hide()
    local function CloseDropdown()
        dropdown:Hide()
    end
    controls.CloseDropdown = CloseDropdown

    local logoBtn = ns.CreateIconButton(header, ns.ASSET_PATH .. "logo.png", ICON_SIZE + 2, ns.Blizz(GENERAL, "General"))
    logoBtn:SetPoint("LEFT", header, "LEFT", 4, 0)
    logoBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    logoBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ns.ShowContextMenu(self, 1)
        else
            ns.SafeSelectDockFrame(ChatFrame1)
        end
        CloseDropdown()
    end)
    controls.logoBtn = logoBtn

    local combatBtn = ns.CreateIconButton(header, ns.ASSET_PATH .. "combat.png", ICON_SIZE, ns.Blizz(COMBAT_LOG, "Combat Log"))
    combatBtn:SetPoint("LEFT", logoBtn, "RIGHT", ICON_GAP, 0)
    combatBtn:SetScript("OnClick", function()
        if ChatFrame2 then
            local target = (ns.GetUserSelectedFrame() == ChatFrame2) and ChatFrame1 or ChatFrame2
            ns.SafeSelectDockFrame(target)
        end
        CloseDropdown()
    end)
    controls.combatBtn = combatBtn

    local historyBtn = ns.CreateIconButton(header, ns.ASSET_PATH .. "history.png", ICON_SIZE + 3, L["TIP_HISTORY"])
    historyBtn:SetPoint("LEFT", combatBtn, "RIGHT", ICON_GAP, 0)
    historyBtn:SetScript("OnClick", function()
        ns.ToggleHistory()
        CloseDropdown()
    end)
    if GudaChatDB and not GudaChatDB.historyEnabled then
        historyBtn:Hide()
    end
    ns.historyBtn = historyBtn
    controls.historyBtn = historyBtn

    local tabLabel = header:CreateFontString(nil, "OVERLAY", "GudaChatFontNormalSmall")
    tabLabel:SetPoint("CENTER", header, "CENTER", 0, 0)
    ns.Paint(tabLabel, C.tabLabel)
    tabLabel:SetText(ns.GetChatTabName(1))
    controls.tabLabel = tabLabel

    local tabLabelBtn = CreateFrame("Button", nil, header)
    ns._tabLabelBtn = tabLabelBtn
    tabLabelBtn:SetPoint("CENTER", tabLabel, "CENTER", 0, 0)
    tabLabelBtn:SetHeight(HEADER_HEIGHT)
    tabLabelBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tabLabelBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            CloseDropdown()
            if ns.IsContextMenuShown() then
                ns.HideContextMenu()
            else
                ns.ShowContextMenu(self)
            end
            return
        end
        if ns.IsContextMenuShown() then
            ns.HideContextMenu()
        end
        if dropdown:IsShown() then
            CloseDropdown()
        else
            RefreshTabDropdown(dropdown, CloseDropdown)
            dropdown:ClearAllPoints()
            dropdown:SetPoint("BOTTOM", self, "TOP", 0, 2)
            dropdown:Show()
        end
    end)
    tabLabelBtn:SetScript("OnEnter", function(self)
        ns.Paint(tabLabel, C.tabLabelHover)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["TIP_TAB_SWITCH"], 0.7, 0.7, 0.7)
        ns.SetTooltipFontSize(12)
        GameTooltip:Show()
        ns.RevealHeader()
    end)
    tabLabelBtn:SetScript("OnLeave", function()
        ns.Paint(tabLabel, C.tabLabel)
        GameTooltip:Hide()
    end)
    controls.tabLabelBtn = tabLabelBtn

    function controls.UpdateTabLabelBtnWidth()
        tabLabelBtn:SetWidth(math.max(tabLabel:GetStringWidth() + 16, TAB_LABEL_MIN_WIDTH))
    end
    controls.UpdateTabLabelBtnWidth()

    ns.CreateClickCloser(dropdown,
        function() return dropdown:IsMouseOver() or tabLabelBtn:IsMouseOver() end,
        CloseDropdown)

    local settingsBtn = ns.CreateIconButton(header, ns.ASSET_PATH .. "cog.png", ICON_SIZE, ns.Blizz(SETTINGS, "Settings"))
    settingsBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    settingsBtn:SetScript("OnClick", function()
        ns.ToggleSettings()
        CloseDropdown()
    end)

    local channelsBtn = ns.CreateIconButton(header, ns.ASSET_PATH .. "voice.png", ICON_SIZE - 1, L["TIP_CHAT_CHANNELS"])
    channelsBtn:SetPoint("RIGHT", settingsBtn, "LEFT", -ICON_GAP, 0)
    channelsBtn:SetScript("OnClick", function()
        if ToggleChannelFrame then ToggleChannelFrame() end
        CloseDropdown()
    end)

    local chatTypeBtn = ns.CreateIconButton(header, ns.ASSET_PATH .. "chat.png", ICON_SIZE - 1, L["TIP_CHAT_TYPE"])
    chatTypeBtn:SetPoint("RIGHT", channelsBtn, "LEFT", -ICON_GAP, 0)
    ns.CreateChatTypeMenu(chatTypeBtn, CloseDropdown)
    controls.chatTypeBtn = chatTypeBtn

    return controls
end

-- General and combat log icons light up while their window is selected
local function AddIconHighlights(controls)
    local logoBtn, combatBtn = controls.logoBtn, controls.combatBtn

    function controls.UpdateIconHighlights(cf)
        ns.Paint(logoBtn.icon, cf == ChatFrame1 and C.iconActive or C.iconInactive)
        ns.Paint(combatBtn.icon, cf == ChatFrame2 and C.iconActive or C.iconInactive)
    end

    logoBtn:HookScript("OnLeave", function()
        if ns.GetSelectedChatFrame() == ChatFrame1 then ns.Paint(logoBtn.icon, C.iconActive) end
    end)
    combatBtn:HookScript("OnLeave", function()
        if ns.GetSelectedChatFrame() == ChatFrame2 then ns.Paint(combatBtn.icon, C.iconActive) end
    end)
end

-- Label and icon highlights follow every tab switch, Blizzard's and GudaChat's
local function FollowFrameSelection(controls)
    local tabLabel = controls.tabLabel
    local function UpdateHeaderForFrame(cf)
        if not cf or not cf.GetID then return end
        local idx = cf:GetID()
        if idx <= NUM_CHAT_WINDOWS then
            tabLabel:SetText(ns.GetChatTabName(idx))
        else
            local tab = _G[cf:GetName() .. "Tab"]
            tabLabel:SetText(tab and (tab.Text and tab.Text:GetText() or tab:GetText()) or ns.GetChatTabName(idx))
        end
        controls.UpdateTabLabelBtnWidth()
        controls.UpdateIconHighlights(cf)
        ns.RequestTabRefresh()
    end
    hooksecurefunc("FCF_SelectDockFrame", UpdateHeaderForFrame)
    ns.OnFrameSelected(UpdateHeaderForFrame)
end

-- Inline tabs: the tab strip drawn inside the header, between the left icons and the chat
-- type icon. While it is on, the tab label and the General icon make room for it and the
-- bar above the header stays hidden.
local function CreateInlineTabs(header, controls)
    local logoBtn, combatBtn, historyBtn = controls.logoBtn, controls.combatBtn, controls.historyBtn
    local tabLabel, tabLabelBtn, chatTypeBtn = controls.tabLabel, controls.tabLabelBtn, controls.chatTypeBtn

    local inlineStrip = ns.CreateTabStrip({
        parent = header,
        overflowName = "GudaChatInlineTabOverflow",
        firstGap = INLINE_FIRST_GAP,
        overflowAutoHide = true,
        isEnabled = function()
            return GudaChatDB.inlineTabBar
        end,
        onDisabled = function()
            tabLabel:Show()
            tabLabelBtn:Show()
            logoBtn:Show()
            combatBtn:ClearAllPoints()
            combatBtn:SetPoint("LEFT", logoBtn, "RIGHT", ICON_GAP, 0)
        end,
        onEnabled = function()
            tabLabel:Hide()
            tabLabelBtn:Hide()
            logoBtn:Hide()
            combatBtn:ClearAllPoints()
            combatBtn:SetPoint("LEFT", header, "LEFT", 4, 0)
            if ns.chatSubTabs then ns.chatSubTabs:Hide() end
        end,
        getLayout = function()
            local leftAnchor = historyBtn:IsShown() and historyBtn or combatBtn
            local leftEdge = leftAnchor:GetRight()
            local rightEdge = chatTypeBtn:GetLeft()
            if not leftEdge or not rightEdge then return nil end
            local totalSpace = rightEdge - leftEdge
            if totalSpace < INLINE_MIN_SPACE then return nil end
            return leftAnchor, "RIGHT", totalSpace
        end,
        placeMoreButton = function(moreBtn, marginRight)
            moreBtn:SetPoint("RIGHT", chatTypeBtn, "LEFT", -marginRight, 0)
        end,
        anchorOverflow = function(menu, moreBtn)
            menu:SetPoint("TOPLEFT", moreBtn, "BOTTOMLEFT", 0, -2)
        end,
    })

    ns.RefreshInlineTabs = function()
        inlineStrip:Refresh()
    end
end

-- Shows the combat log subtabs only while the combat log is selected, and the tab bar
-- above the header for every other window
local function UpdateSubTabsForFrame(cf)
    local combatSubTabs, chatSubTabs = ns.combatSubTabs, ns.chatSubTabs
    if combatSubTabs then
        if cf == ChatFrame2 then
            ns.UpdateCombatSubTabColors()
            combatSubTabs:Show()
            combatSubTabs:SetAlpha(ns.chatHeader and ns.chatHeader:GetAlpha() or 1)
        else
            combatSubTabs:Hide()
        end
    end
    if chatSubTabs and GudaChatDB.showTabBar then
        chatSubTabs:SetShown(cf ~= ChatFrame2)
    end
    ns.RequestTabRefresh()
end

local function CreateChatHeader(parentFrame)
    local header = CreateFrame("Frame", "GudaChatHeader", UIParent, "BackdropTemplate")
    header:SetHeight(HEADER_HEIGHT)
    local extraR = ns.CHAT_EDGE_PAD
    header:SetPoint("BOTTOMLEFT", parentFrame, "TOPLEFT", -4, 0)
    header:SetPoint("BOTTOMRIGHT", parentFrame, "TOPRIGHT", 4 + extraR, 0)
    header:SetFrameStrata("MEDIUM")
    header:SetFrameLevel(100)
    header:SetAlpha(0)
    ns.ApplyDarkBackdrop(header, C.headerBg, C.headerBorder)
    header:EnableMouse(true)

    AddHeaderHoverFade(header, parentFrame)
    AddHeaderDrag(header, parentFrame)

    local controls = CreateHeaderControls(header)
    AddIconHighlights(controls)
    ns.EnsureUserSelectedFrame()
    controls.UpdateIconHighlights(ChatFrame1)
    FollowFrameSelection(controls)
    CreateInlineTabs(header, controls)

    ns.CreateCombatSubTabs(header)
    local chatSubTabs = ns.CreateChatSubTabs(header)
    if GudaChatDB.showTabBar then
        ns.RefreshChatSubTabs()
        chatSubTabs:Show()
        chatSubTabs:SetAlpha(0)
    end
    if GudaChatDB.inlineTabBar then
        ns.RefreshInlineTabs()
    end

    ns.UpdateSubTabsForFrame = UpdateSubTabsForFrame
    hooksecurefunc("FCF_SelectDockFrame", UpdateSubTabsForFrame)

    local chatSubTabHooks = { "FCF_OpenNewWindow", "FCF_Close", "FCF_DockFrame", "FCF_UnDockFrame", "FCF_SetWindowName" }
    for _, funcName in ipairs(chatSubTabHooks) do
        if _G[funcName] then
            hooksecurefunc(funcName, ns.RequestTabRefresh)
        end
    end

    ns.EnableAutoSelectOnSend()

    ns.chatHeader = header
    return header
end
ns.CreateChatHeader = CreateChatHeader
