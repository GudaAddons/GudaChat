local addonName, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Chat window selection
--
-- Direct frame-switch that avoids FCF_SelectDockFrame entirely.
-- FCF_SelectDockFrame → FCFDock_UpdateTabs → FCF_CheckShowChatFrame calls
-- SetShown on combat-log quick buttons, which triggers the protected
-- ClearEventFilters() in Blizzard_CombatLogProcessor and causes
-- ADDON_ACTION_FORBIDDEN on retail 12.x+.
-- We manage dock state + frame visibility ourselves instead. userSelectedFrame is the
-- frame the user (or GudaChat) intentionally selected.
---------------------------------------------------------------------------

local userSelectedFrame

-- ChatFrame2 is kept Show()n on modern clients (alpha-toggled) to avoid combat taint.
-- While transparent it overlaps the visible frame, so it must not intercept mouse input
-- (a SetAlpha(0) frame still receives mouse wheel/clicks) — tie its mouse to its visibility.
local function SetCombatLogVisible(visible)
    if not ChatFrame2 then return end
    ChatFrame2:SetAlpha(visible and 1 or 0)
    ChatFrame2:EnableMouseWheel(visible)
    ChatFrame2:EnableMouse(visible)
end
ns.SetCombatLogVisible = SetCombatLogVisible

local function IsDocked(dock, cf)
    for _, frame in pairs(dock.DOCKED_CHAT_FRAMES) do
        if frame == cf then return true end
    end
    return false
end

local frameSelectedCallbacks = {}

-- Runs fn(cf) after every frame switch, whether it came from GudaChat or from Blizzard's
-- FCF_SelectDockFrame (hooked in the tab model and the header). Keeps the header label,
-- icon highlights and tab blink state in one place instead of only on Blizzard's path.
function ns.OnFrameSelected(fn)
    tinsert(frameSelectedCallbacks, fn)
end

local function NotifyFrameSelected(cf)
    for _, fn in ipairs(frameSelectedCallbacks) do
        fn(cf)
    end
end
ns.NotifyFrameSelected = NotifyFrameSelected

-- Shows cf and hides the other docked frames without FCF_SelectDockFrame (see above).
-- Two Blizzard writes stay on purpose, and they are the only ones: dock.selected, so
-- Blizzard's own dock updates keep cf on top instead of switching back, and
-- SELECTED_CHAT_FRAME, which Blizzard's chat input and window options read to know the
-- current window. GudaChat itself reads userSelectedFrame instead of those globals.
-- A frame that is not docked (popped out, or closed) is left alone: hiding every docked
-- frame without showing it would leave the chat area empty.
-- ns.UpdateSubTabsForFrame is set by the header once its tab bars exist.
local function SafeSelectDockFrame(cf)
    local dock = GENERAL_CHAT_DOCK
    if not cf or not (dock and dock.DOCKED_CHAT_FRAMES) or not IsDocked(dock, cf) then return end
    userSelectedFrame = cf
    C_Timer.After(0, function()
        if not IsDocked(dock, cf) then return end
        dock.selected = cf
        for _, frame in pairs(dock.DOCKED_CHAT_FRAMES) do
            if frame == ChatFrame2 then
                SetCombatLogVisible(frame == cf)
            elseif frame == cf then
                frame:Show()
            else
                frame:Hide()
            end
        end
        SELECTED_CHAT_FRAME = cf
        if ns.UpdateSubTabsForFrame then ns.UpdateSubTabsForFrame(cf) end
        NotifyFrameSelected(cf)
    end)
end
ns.SafeSelectDockFrame = SafeSelectDockFrame

function ns.GetUserSelectedFrame()
    return userSelectedFrame
end

-- General is the starting selection; the header calls this once it is built
function ns.EnsureUserSelectedFrame()
    userSelectedFrame = userSelectedFrame or ChatFrame1
end

-- The window the player is looking at. GudaChat's own selection comes first because
-- SafeSelectDockFrame does not go through Blizzard's selection code.
local function GetSelectedChatFrame()
    return userSelectedFrame
        or (FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame())
        or ChatFrame1
end
ns.GetSelectedChatFrame = GetSelectedChatFrame

local function GetSelectedChatFrameIndex()
    local selected = GetSelectedChatFrame()
    return selected and selected.GetID and selected:GetID() or 1
end
ns.GetSelectedChatFrameIndex = GetSelectedChatFrameIndex

-- Window name: the server-stored name first (it persists across reloads, even with hidden
-- tabs), then the Blizzard tab text, then "Chat N"
local function GetChatTabName(index)
    if GetChatWindowInfo then
        local name = GetChatWindowInfo(index)
        if name and name ~= "" then return name end
    end
    local tab = _G["ChatFrame" .. index .. "Tab"]
    if tab then
        local name = tab.Text and tab.Text:GetText() or tab:GetText()
        if name and name ~= "" then return name end
    end
    return string.format(L["CHAT_WINDOW_NUMBER"], index)
end
ns.GetChatTabName = GetChatTabName

-- One tab switch reaches both tab strips through several paths (the dock hook, the
-- frame-selected notifier and UpdateSubTabsForFrame), and a burst of chat can blink
-- several tabs in one frame. Requests are collected and both strips rebuilt once, on the
-- next frame. Drag-and-drop and settings changes still refresh directly.
local tabRefreshQueued = false

local function FlushTabRefresh()
    tabRefreshQueued = false
    if ns.RefreshChatSubTabs then ns.RefreshChatSubTabs() end
    if ns.RefreshInlineTabs then ns.RefreshInlineTabs() end
end

local function RequestTabRefresh()
    if tabRefreshQueued then return end
    tabRefreshQueued = true
    C_Timer.After(0, FlushTabRefresh)
end
ns.RequestTabRefresh = RequestTabRefresh
