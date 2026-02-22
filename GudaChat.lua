local addonName, ns = ...

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

SLASH_GUDACHAT1 = "/gudachat"
SLASH_GUDACHAT2 = "/gc"
SlashCmdList["GUDACHAT"] = function(msg)
    msg = strtrim(msg):lower()
    if msg == "" or msg == "settings" or msg == "options" then
        ns.ToggleSettings()
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
        if GudaChatDB.locked == nil then
            GudaChatDB.locked = false
        end
        if GudaChatDB.showLevel == nil then
            GudaChatDB.showLevel = false
        end
        if GudaChatDB.emojis == nil then
            GudaChatDB.emojis = true
        end
        if GudaChatDB.emojiSize == nil then
            GudaChatDB.emojiSize = ns.DEFAULT_EMOJI_SIZE
        end
        if GudaChatDB.whisperTab == nil then
            GudaChatDB.whisperTab = false
        end
        -- chatFont: nil means default (Fonts\FRIZQT__.TTF)
        if GudaChatDB.showTabBar == nil then
            GudaChatDB.showTabBar = true
        end
        -- History: per-channel buckets
        if type(GudaChatDB.history) ~= "table" or GudaChatDB.history[1] ~= nil then
            -- Reset if old flat-array format or missing
            GudaChatDB.history = {}
        end
        GudaChatDB.historyMax = GudaChatDB.historyMax or 500
        if GudaChatDB.historyEnabled == nil then
            GudaChatDB.historyEnabled = true
        end
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.ForEachChatWindow(function(_, i) ns.StripChatChrome(i) end)

        if GeneralDockManagerOverflowButton then
            ns.KillFrame(GeneralDockManagerOverflowButton)
        end
        if GeneralDockManager then
            ns.KillFrame(GeneralDockManager)
        end

        hooksecurefunc("FCF_OpenTemporaryWindow", function(chatType, chatTarget)
            -- Blizzard already created, configured, docked, and selected the frame.
            -- We just need to find it, strip its chrome, and refresh our tab bar.
            for _, name in ipairs(CHAT_FRAMES) do
                local cf = _G[name]
                if cf and cf.isTemporary and cf.inUse and cf.isDocked then
                    local idx = cf:GetID()
                    ns.StripChatChrome(idx)
                    cf:ClearAllPoints()
                    cf:SetPoint(ChatFrame1:GetPoint(1))
                    cf:SetSize(ChatFrame1:GetSize())
                    if GudaChatDB.chatFont then
                        local _, size, flags = cf:GetFont()
                        cf:SetFont(GudaChatDB.chatFont, size, flags)
                    end
                end
            end
            if ns.RefreshChatSubTabs then ns.RefreshChatSubTabs() end
        end)

        -- Auto-select newly created chat windows
        if FCF_OpenNewWindow then
            hooksecurefunc("FCF_OpenNewWindow", function()
                for i = NUM_CHAT_WINDOWS, 1, -1 do
                    local cf = _G["ChatFrame" .. i]
                    if cf and cf:IsShown() then
                        FCF_SelectDockFrame(cf)
                        break
                    end
                end
            end)
        end

        -- Auto-select renamed window and refresh tab label
        if FCF_SetWindowName then
            hooksecurefunc("FCF_SetWindowName", function(chatFrame)
                if chatFrame then
                    FCF_SelectDockFrame(chatFrame)
                end
            end)
        end

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
                hooksecurefunc(funcName, ns.RehideAllTabs)
            end
        end

        -- Also catch channel events that trigger tab changes
        local tabWatcher = CreateFrame("Frame")
        tabWatcher:RegisterEvent("CHANNEL_UI_UPDATE")
        tabWatcher:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
        tabWatcher:RegisterEvent("UPDATE_CHAT_WINDOWS")
        tabWatcher:SetScript("OnEvent", function()
            C_Timer.After(0.1, ns.RehideAllTabs)
        end)

        -- Remove ChatFrame1 from Blizzard's managed frame layout so
        -- UIParent_ManageFramePositions stops repositioning it
        if UIPARENT_MANAGED_FRAME_POSITIONS then
            UIPARENT_MANAGED_FRAME_POSITIONS["ChatFrame1"] = nil
        end

        -- Block Blizzard's UIParentPanelManager from repositioning ChatFrame1.
        -- We keep the original methods for our own use via ns.CF1_SetPoint / ns.CF1_ClearAllPoints,
        -- and replace the frame methods with versions that ignore external callers.
        local origSetPoint = ChatFrame1.SetPoint
        local origClearAllPoints = ChatFrame1.ClearAllPoints
        ns.CF1_SetPoint = origSetPoint
        ns.CF1_ClearAllPoints = origClearAllPoints
        ns.cf1PositionLocked = false

        ChatFrame1.SetPoint = function(self, ...)
            if ns.cf1PositionLocked then return end
            origSetPoint(self, ...)
        end
        ChatFrame1.ClearAllPoints = function(self, ...)
            if ns.cf1PositionLocked then return end
            origClearAllPoints(self, ...)
        end

        -- Block Blizzard from resizing ChatFrame1
        local origSetSize = ChatFrame1.SetSize
        local origSetWidth = ChatFrame1.SetWidth
        local origSetHeight = ChatFrame1.SetHeight
        ChatFrame1.SetSize = function(self, ...)
            if ns.cf1PositionLocked then return end
            origSetSize(self, ...)
        end
        ChatFrame1.SetWidth = function(self, ...)
            if ns.cf1PositionLocked then return end
            origSetWidth(self, ...)
        end
        ChatFrame1.SetHeight = function(self, ...)
            if ns.cf1PositionLocked then return end
            origSetHeight(self, ...)
        end

        -- Restore saved chat size
        if GudaChatDB.chatSize then
            local s = GudaChatDB.chatSize
            ChatFrame1:SetSize(s.w, s.h)
        end

        -- Restore saved chat position
        if GudaChatDB.position then
            local p = GudaChatDB.position
            ChatFrame1:SetMovable(true)
            ChatFrame1:ClearAllPoints()
            ChatFrame1:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
            ChatFrame1:SetUserPlaced(false)
        end

        -- Lock position after initial setup so UIParentPanelManager can't move it
        ns.cf1PositionLocked = true

        ChatFrame1:SetFading(GudaChatDB.fading)
        if GudaChatDB.chatFont then
            ns.ApplyChatFont(GudaChatDB.chatFont)
        end
        ns.ApplyClassColors()
        ns.EnableLevelDisplay()
        ns.EnableCopyLinks()
        ns.EnableEmojis()
        ns.SetupLinkHook()
        ns.RegisterHistoryEvents()
        ns.ForEachChatWindow(function(cf)
            ns.CreateScrollbar(cf)
            if GudaChatDB.hideScrollbar and cf.gudaScrollbar then
                cf.gudaScrollbar:Hide()
            end
        end)
        if GudaChatDB.whisperTab then
            ns.SetupWhisperFrame()
        end
        ns.CreateChatHeader(ChatFrame1)
        ns.ApplyLockState()
        ns.ApplyChatMargins()

        -- Reapply clamp insets after Blizzard dock updates reset them
        if FCF_DockUpdate then
            hooksecurefunc("FCF_DockUpdate", ns.ApplyChatMargins)
        end

        ns.ReplayHistory()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffGudaChat|r loaded — type |cffffd200/gc|r for settings")
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
