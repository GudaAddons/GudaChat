local addonName, ns = ...

---------------------------------------------------------------------------
-- Tab strip: one renderer for both tab rows (the bar above the header and the inline
-- tabs inside it). It fits as many tabs as there is room for, keeps the selected tab
-- visible, puts the rest in an overflow menu, blinks unread tabs and reorders tabs by
-- drag and drop.
--
-- Tab strips are rebuilt on every tab switch, blink and window change. Frames can never
-- be freed in WoW, so buttons go back to a pool and are reconfigured on the next refresh;
-- each strip keeps one "more" button and its overflow menu keeps its item buttons.
---------------------------------------------------------------------------

local TAB_GAP = 6
local MARGIN_RIGHT = 6
local MORE_BUTTON_SIZE = 12
local OVERFLOW_EXTRA = TAB_GAP + MORE_BUTTON_SIZE
local TAB_HEIGHT = 16
local TAB_TEXT_PADDING = 8
local DRAG_THRESHOLD = 5
local OVERFLOW_ITEM_HEIGHT = 18
local OVERFLOW_PADDING = 6
local OVERFLOW_MIN_WIDTH = 60
local OVERFLOW_HIDE_DELAY = 0.3
local DRAG_INDICATOR_COLOR = { 0.8, 0.6, 0.0, 1 }

local measureFont

-- Width of a tab label in GameFontNormalSmall, measured with one shared FontString
local function MeasureTabText(text)
    if not measureFont then
        measureFont = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        measureFont:SetAlpha(0)
    end
    measureFont:SetText(text)
    return measureFont:GetStringWidth()
end

-- A tab button with its label and its looping unread-blink animation, created once
local function AcquireTabButton(pool, parent)
    local btn = tremove(pool)
    if btn then
        btn:SetParent(parent)
        btn:Show()
        return btn
    end
    btn = CreateFrame("Button", nil, parent)
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", btn, "LEFT", 0, 0)
    btn.text = text
    local blinkAG = text:CreateAnimationGroup()
    blinkAG:SetLooping("BOUNCE")
    local fade = blinkAG:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.2)
    fade:SetDuration(0.5)
    fade:SetSmoothing("IN_OUT")
    btn.blinkAG = blinkAG
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    return btn
end

local function ReleaseTabButtons(pool, list)
    for _, btn in ipairs(list) do
        btn:Hide()
        btn:ClearAllPoints()
        btn:SetScript("OnUpdate", nil)
        btn.blinkAG:Stop()
        btn.blinking = nil
        btn.tabIdx = nil
        tinsert(pool, btn)
    end
    wipe(list)
end

local function SetTabTextColor(text, col, active)
    if active then
        text:SetTextColor(col[1], col[2], col[3], 1)
    else
        text:SetTextColor(col[1] * 0.5, col[2] * 0.5, col[3] * 0.5, 0.8)
    end
end

local function IsSelectedFrame(cf)
    return cf and cf:IsShown()
end

-- How many tabs fit in availableWidth (first gap, tab gaps and the right margin included).
-- When not all fit, room is kept for the overflow button and the selected tab is swapped
-- into the last visible slot. allTabs and widths are reordered in place for that swap.
local function FitTabs(allTabs, widths, availableWidth, firstGap)
    local function CountFitting(limit)
        local totalW, count = firstGap, 0
        for idx = 1, #allTabs do
            totalW = totalW + widths[idx] + (idx > 1 and TAB_GAP or 0)
            if totalW > limit then break end
            count = idx
        end
        return count
    end

    if CountFitting(availableWidth - MARGIN_RIGHT) == #allTabs then
        return #allTabs
    end

    local maxUsable = availableWidth - OVERFLOW_EXTRA - MARGIN_RIGHT
    local fitCount = CountFitting(maxUsable)

    local selectedTabIdx
    for idx, def in ipairs(allTabs) do
        if def.cf and def.cf:IsShown() then
            selectedTabIdx = idx
            break
        end
    end
    if selectedTabIdx and selectedTabIdx > fitCount and fitCount > 0 then
        allTabs[fitCount], allTabs[selectedTabIdx] = allTabs[selectedTabIdx], allTabs[fitCount]
        widths[fitCount], widths[selectedTabIdx] = widths[selectedTabIdx], widths[fitCount]
        fitCount = CountFitting(maxUsable)
    end
    return fitCount
end

local Strip = {}
Strip.__index = Strip

-- Creates a strip. config:
--   parent           frame the tab buttons, more button and drag indicator belong to
--   overflowName     global name of the overflow menu frame
--   firstGap         gap before the first tab
--   isEnabled()      false hides the strip (onDisabled runs instead of a refresh)
--   onDisabled()     optional, runs when the strip is turned off
--   onEnabled()      optional, runs before every refresh while it is on
--   getLayout()      startAnchor, startPoint, availableWidth; nil availableWidth skips it
--   placeMoreButton(btn, margin)    anchors the "more" button, margin from the right end
--   anchorOverflow(menu, moreBtn)   anchors the overflow menu to the "more" button
--   overflowAutoHide when true, the overflow menu hides itself once the mouse leaves it
function ns.CreateTabStrip(config)
    local strip = setmetatable({
        config = config,
        pool = {},
        buttons = {},
        dragState = { dragging = false },
    }, Strip)
    return strip
end

function Strip:HideOverflow()
    if self.overflow then self.overflow:Hide() end
end

function Strip:IsOverflowShown()
    return self.overflow ~= nil and self.overflow:IsShown()
end

function Strip:GetDragIndicator()
    if not self.dragIndicator then
        local indicator = self.config.parent:CreateTexture(nil, "OVERLAY")
        indicator:SetTexture("Interface\\Buttons\\WHITE8x8")
        indicator:SetVertexColor(unpack(DRAG_INDICATOR_COLOR))
        indicator:SetSize(2, 14)
        indicator:Hide()
        self.dragIndicator = indicator
    end
    return self.dragIndicator
end

-- The index in allTabs before which the dragged tab would be dropped, from the cursor X
function Strip:GetInsertIndex()
    local scale = self.config.parent:GetEffectiveScale()
    local cursorX = GetCursorPosition() / scale
    for _, tabBtn in ipairs(self.buttons) do
        if tabBtn.tabIdx then
            local left, right = tabBtn:GetLeft(), tabBtn:GetRight()
            if left and right and cursorX < (left + right) / 2 then
                return tabBtn.tabIdx
            end
        end
    end
    return self.fitCount + 1
end

-- Moves the drop indicator to the gap before insertIdx, or hides it when the drop would
-- not move anything
function Strip:UpdateIndicator(insertIdx, srcIdx)
    local indicator = self:GetDragIndicator()
    local state = self.dragState
    if not insertIdx or insertIdx == srcIdx or insertIdx == srcIdx + 1 then
        indicator:Hide()
        state.insertIdx = nil
        return
    end
    state.insertIdx = insertIdx
    local anchorBtn, lastBtn
    for _, tabBtn in ipairs(self.buttons) do
        if tabBtn.tabIdx then
            lastBtn = tabBtn
            if insertIdx <= self.fitCount and tabBtn.tabIdx == insertIdx then
                anchorBtn = tabBtn
            end
        end
    end
    indicator:ClearAllPoints()
    if anchorBtn then
        indicator:SetPoint("RIGHT", anchorBtn, "LEFT", -3, 0)
    elseif lastBtn then
        indicator:SetPoint("LEFT", lastBtn, "RIGHT", 3, 0)
    end
    indicator:Show()
end

function Strip:FinishDrag(srcBtn)
    local state = self.dragState
    if not state.dragging then return end
    local insertIdx, srcIdx = state.insertIdx, state.sourceIdx
    if insertIdx and srcIdx and insertIdx ~= srcIdx and insertIdx ~= srcIdx + 1 then
        ns.SaveTabMove(self.baseOrder, self.allTabs, srcIdx, insertIdx, self.fitCount)
    end
    self:GetDragIndicator():Hide()
    state.dragging = false
    state.sourceIdx = nil
    state.sourceBtn = nil
    state.insertIdx = nil
    srcBtn:SetScript("OnUpdate", nil)
    self:Refresh()
end

-- Watches a pressed tab: past DRAG_THRESHOLD pixels it becomes a drag that moves the
-- drop indicator; releasing the button finishes the drag
function Strip:StartPendingDrag(btn, col)
    local strip = self
    local state = self.dragState
    local cx, cy = GetCursorPosition()
    local scale = btn:GetEffectiveScale()
    state.startX = cx / scale
    state.startY = cy / scale
    state.pending = true
    state.pendingBtn = btn
    state.pendingIdx = btn.tabIdx
    btn:SetScript("OnUpdate", function(self)
        if not state.pending and not state.dragging then
            self:SetScript("OnUpdate", nil)
            return
        end
        if not IsMouseButtonDown("LeftButton") then
            if state.dragging then
                strip:FinishDrag(self)
            end
            state.pending = false
            self:SetScript("OnUpdate", nil)
            return
        end
        if state.pending then
            local x, y = GetCursorPosition()
            local s = self:GetEffectiveScale()
            local dx, dy = x / s - state.startX, y / s - state.startY
            if (dx * dx + dy * dy) > DRAG_THRESHOLD * DRAG_THRESHOLD then
                state.pending = false
                state.dragging = true
                state.sourceIdx = state.pendingIdx
                state.sourceBtn = self
                self.text:SetTextColor(col[1] * 0.3, col[2] * 0.3, col[3] * 0.3, 0.5)
            end
        end
        if state.dragging then
            strip:UpdateIndicator(strip:GetInsertIndex(), state.sourceIdx)
        end
    end)
end

function Strip:CreateTabButton(def, tabIdx)
    local strip = self
    local state = self.dragState
    local col = def.col
    local btn = AcquireTabButton(self.pool, self.config.parent)
    btn:SetHeight(TAB_HEIGHT)
    btn.tabIdx = tabIdx
    btn.text:SetText(def.name)
    SetTabTextColor(btn.text, col, IsSelectedFrame(def.cf))

    btn:SetScript("OnClick", function(self, button)
        if state.dragging then
            strip:FinishDrag(self)
            return
        end
        if button == "RightButton" then
            ns.ShowContextMenu(self, def.frameIndex)
        else
            if ns.IsTabBlinking(def.frameIndex) then
                ns.ClearTabBlink(def.frameIndex)
                self.blinkAG:Stop()
            end
            ns.SafeSelectDockFrame(def.cf)
        end
    end)
    btn:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            strip:StartPendingDrag(self, col)
        end
    end)
    btn:SetScript("OnEnter", function(self)
        self.text:SetTextColor(col[1], col[2], col[3], 1)
        ns.RevealHeader()
    end)
    btn:SetScript("OnLeave", function(self)
        if state.dragging and state.sourceBtn == self then return end
        if self.blinking then return end
        SetTabTextColor(self.text, col, IsSelectedFrame(def.cf))
    end)

    if ns.IsTabBlinking(def.frameIndex) then
        btn.blinking = true
        btn.blinkAG:Play()
        btn.text:SetTextColor(col[1], col[2], col[3], 1)
    end
    return btn
end

function Strip:GetMoreButton()
    if not self.moreBtn then
        local btn = CreateFrame("Button", nil, self.config.parent)
        btn:SetSize(MORE_BUTTON_SIZE, MORE_BUTTON_SIZE)
        local icon = btn:CreateTexture(nil, "OVERLAY")
        icon:SetAllPoints()
        icon:SetTexture(ns.ASSET_PATH .. "more.png")
        icon:SetVertexColor(0.6, 0.6, 0.6, 1)
        btn.icon = icon
        btn:SetScript("OnEnter", function(self)
            self.icon:SetVertexColor(1, 1, 1, 1)
            ns.RevealHeader()
        end)
        btn:SetScript("OnLeave", function(self)
            self.icon:SetVertexColor(0.6, 0.6, 0.6, 1)
        end)
        local strip = self
        btn:SetScript("OnClick", function(clicked)
            strip:ToggleOverflow(clicked)
        end)
        self.moreBtn = btn
    end
    return self.moreBtn
end

-- Hides the overflow menu a moment after the mouse leaves it and the "more" button,
-- but never while the right-click menu opened from it is up
function Strip:AddOverflowAutoHide(menu)
    local strip = self
    local hideElapsed = 0
    menu:SetScript("OnUpdate", function(m, dt)
        if not m:IsShown() then return end
        if ns.IsContextMenuShown() then
            hideElapsed = 0
            return
        end
        local overMenu = m:IsMouseOver(0, 0, 10, 0)
        local overMore = strip.moreBtn and strip.moreBtn:IsMouseOver()
        if overMenu or overMore then
            hideElapsed = 0
        else
            hideElapsed = hideElapsed + dt
            if hideElapsed >= OVERFLOW_HIDE_DELAY then
                m:Hide()
                hideElapsed = 0
            end
        end
    end)
    menu:SetScript("OnShow", function()
        hideElapsed = 0
    end)
end

function Strip:GetOverflowMenu()
    if not self.overflow then
        local menu = CreateFrame("Frame", self.config.overflowName, UIParent, "BackdropTemplate")
        menu:SetFrameStrata("TOOLTIP")
        menu:SetClampedToScreen(true)
        ns.ApplyDarkBackdrop(menu, ns.COLOR_DARK_BG, ns.COLOR_DARK_BORDER)
        menu:EnableMouse(true)
        if self.config.overflowAutoHide then
            self:AddOverflowAutoHide(menu)
        end
        self.overflow = menu
    end
    return self.overflow
end

-- Lists the tabs that did not fit; left click selects one, right click opens its menu
function Strip:ToggleOverflow(moreBtn)
    if self:IsOverflowShown() then
        self.overflow:Hide()
        return
    end
    local menu = self:GetOverflowMenu()
    local selectedIndex = ns.GetSelectedChatFrameIndex()
    local maxW = OVERFLOW_MIN_WIDTH
    local items = {}

    for idx = self.fitCount + 1, #self.allTabs do
        local def = self.allTabs[idx]
        local col = def.col
        local item = ns.GetMenuItem(menu, #items + 1, OVERFLOW_ITEM_HEIGHT)
        item.text:SetText(def.name)
        SetTabTextColor(item.text, col, def.frameIndex == selectedIndex)
        item:SetScript("OnEnter", function(self)
            self.text:SetTextColor(col[1], col[2], col[3], 1)
        end)
        item:SetScript("OnLeave", function(self)
            SetTabTextColor(self.text, col, def.frameIndex == ns.GetSelectedChatFrameIndex())
        end)
        item:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                ns.ShowContextMenu(self, def.frameIndex)
            else
                ns.SafeSelectDockFrame(def.cf)
                menu:Hide()
            end
        end)
        maxW = math.max(maxW, item.text:GetStringWidth() + 16)
        tinsert(items, item)
    end
    ns.HideMenuItemsFrom(menu, #items + 1)

    menu:SetSize(maxW, #items * OVERFLOW_ITEM_HEIGHT + OVERFLOW_PADDING * 2)
    menu:ClearAllPoints()
    self.config.anchorOverflow(menu, moreBtn)
    for i, item in ipairs(items) do
        item:SetWidth(maxW)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, -OVERFLOW_PADDING - (i - 1) * OVERFLOW_ITEM_HEIGHT)
        item:Show()
    end
    menu:Show()
end

function Strip:Refresh()
    local config = self.config
    ReleaseTabButtons(self.pool, self.buttons)
    if self.moreBtn then self.moreBtn:Hide() end
    self:HideOverflow()

    if not config.isEnabled() then
        if config.onDisabled then config.onDisabled() end
        return
    end
    if config.onEnabled then config.onEnabled() end

    local allTabs = ns.CollectChatTabs()
    ns.PruneBlinksToTabs(allTabs)
    self.allTabs = allTabs
    self.baseOrder = { unpack(allTabs) }

    local startAnchor, startPoint, availableWidth = config.getLayout()
    if not availableWidth then return end

    local widths = {}
    for idx, def in ipairs(allTabs) do
        widths[idx] = MeasureTabText(def.name) + TAB_TEXT_PADDING
    end
    self.fitCount = FitTabs(allTabs, widths, availableWidth, config.firstGap)
    self:GetDragIndicator()

    local prev
    for idx = 1, self.fitCount do
        local btn = self:CreateTabButton(allTabs[idx], idx)
        btn:SetWidth(widths[idx])
        if prev then
            btn:SetPoint("LEFT", prev, "RIGHT", TAB_GAP, 0)
        else
            btn:SetPoint("LEFT", startAnchor, startPoint, config.firstGap, 0)
        end
        prev = btn
        tinsert(self.buttons, btn)
    end

    if self.fitCount < #allTabs then
        local moreBtn = self:GetMoreButton()
        moreBtn:ClearAllPoints()
        config.placeMoreButton(moreBtn, MARGIN_RIGHT)
        moreBtn:Show()
    end
end

---------------------------------------------------------------------------
-- The tab bar above the header
---------------------------------------------------------------------------

local TAB_BAR_HEIGHT = 20
local TAB_BAR_BG = { 0.05, 0.05, 0.05, 0.75 }
local TAB_BAR_BORDER = { 0.25, 0.25, 0.25, 0.5 }
local TAB_BAR_FIRST_GAP = 6
local TAB_BAR_DEFAULT_WIDTH = 300
local TAB_BAR_HIDE_DELAY = 0.3

local externalStrip

-- Rebuilds the bar above the header (no-op until it exists). Kept on ns under its old
-- name because Settings and GudaChat.lua call it.
function ns.RefreshChatSubTabs()
    if externalStrip then externalStrip:Refresh() end
end

function ns.IsTabBarOverflowShown()
    return externalStrip ~= nil and externalStrip:IsOverflowShown()
end

-- The bar fades in while the mouse is over it, the header's tab label, its overflow menu
-- or an open right-click menu, and stays up while a tab is blinking
local function AddTabBarHoverFade(bar)
    local tabBarHovering = false
    local tabBarFadeIn = ns.CreateFade(bar, 1, ns.FADE_IN_DURATION)
    local tabBarFadeOut = ns.CreateFade(bar, 0, ns.FADE_OUT_DURATION)
    tabBarFadeOut:HookScript("OnFinished", function()
        externalStrip:HideOverflow()
    end)
    local tabBarHideGen = 0

    local function IsOverTabBarUI()
        return bar:IsMouseOver()
            or (ns._tabLabelBtn and ns._tabLabelBtn:IsMouseOver())
            or (externalStrip:IsOverflowShown() and externalStrip.overflow:IsMouseOver())
    end

    local function ShowTabBar()
        if ns.hideHeaderForInput then return end
        if tabBarHovering then return end
        tabBarHovering = true
        tabBarHideGen = tabBarHideGen + 1
        tabBarFadeOut:Stop()
        tabBarFadeIn:PlayFromCurrent()
    end

    local function HideTabBar()
        if not tabBarHovering then return end
        tabBarHovering = false
        tabBarHideGen = tabBarHideGen + 1
        local gen = tabBarHideGen
        C_Timer.After(TAB_BAR_HIDE_DELAY, function()
            if gen ~= tabBarHideGen then return end
            if tabBarHovering then return end
            if ns.HasBlinkingTabs() or ns.IsContextMenuShown() or IsOverTabBarUI() then
                tabBarHovering = true
                return
            end
            tabBarFadeIn:Stop()
            tabBarFadeOut:PlayFromCurrent()
        end)
    end

    local tabBarMonitor = CreateFrame("Frame", nil, bar)
    local sinceHoverCheck = 0
    tabBarMonitor:SetScript("OnUpdate", function(self, elapsed)
        sinceHoverCheck = sinceHoverCheck + elapsed
        if sinceHoverCheck < ns.HOVER_CHECK_INTERVAL then return end
        sinceHoverCheck = 0
        if ns.hideHeaderForInput then
            if tabBarHovering then
                tabBarHovering = false
                bar:SetAlpha(0)
            end
            return
        end
        if IsOverTabBarUI() or ns.IsContextMenuShown() then
            ShowTabBar()
        else
            HideTabBar()
        end
    end)

    ns.ShowTabBar = ShowTabBar
end

function ns.CreateChatSubTabs(header)
    local bar = CreateFrame("Frame", "GudaChatSubTabs", UIParent, "BackdropTemplate")
    bar:SetHeight(TAB_BAR_HEIGHT)
    bar:SetPoint("BOTTOMLEFT", header, "TOPLEFT", 0, -1)
    bar:SetPoint("BOTTOMRIGHT", header, "TOPRIGHT", 0, -1)
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(101)
    ns.ApplyDarkBackdrop(bar, TAB_BAR_BG, TAB_BAR_BORDER)
    bar:EnableMouse(true)
    bar:SetAlpha(0)

    externalStrip = ns.CreateTabStrip({
        parent = bar,
        overflowName = "GudaChatTabOverflow",
        firstGap = TAB_BAR_FIRST_GAP,
        isEnabled = function()
            return GudaChatDB.showTabBar and not GudaChatDB.inlineTabBar
        end,
        onDisabled = function()
            bar:Hide()
        end,
        getLayout = function()
            return bar, "LEFT", bar:GetWidth() or TAB_BAR_DEFAULT_WIDTH
        end,
        placeMoreButton = function(moreBtn, marginRight)
            moreBtn:SetPoint("RIGHT", bar, "RIGHT", -marginRight, 0)
        end,
        anchorOverflow = function(menu, moreBtn)
            menu:SetPoint("BOTTOMLEFT", moreBtn, "TOPLEFT", 0, 2)
        end,
    })

    AddTabBarHoverFade(bar)

    ns.chatSubTabs = bar
    return bar
end
