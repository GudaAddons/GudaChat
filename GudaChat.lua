local addonName, ns = ...
local L = ns.L

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
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffGudaChat|r " .. L["CMD_HEADER"])
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/gc|r — " .. L["CMD_OPEN_SETTINGS"])
    end
end

---------------------------------------------------------------------------
-- Account copy of the per-character data (WoW: Forever only)
--
-- Forever writes SavedVariables at logout but often does not load them back,
-- and the player-side workaround (Forever Data Protect) restores account-wide
-- SavedVariables only. So on Forever GudaChatCharDB (history, loot log, addon
-- log) is also copied into GudaChatDB.charCopies at logout, keyed by the
-- character GUID; at load the newer of the two wins. Same design as GudaBags.
---------------------------------------------------------------------------

local function CharCopyKey()
    local guid = ns.SafeName(UnitGUID("player"))
    if guid and guid ~= "" then return guid end
    return ns.UnitFullName("player")
end

local function RestoreCharCopy()
    local copies = GudaChatDB.charCopies
    local key = copies and CharCopyKey()
    local copy = key and copies[key]
    if type(copy) ~= "table" then return end
    local own = GudaChatCharDB
    if type(own) == "table" and (tonumber(own.savedAt) or 0) >= (tonumber(copy.savedAt) or 0) then return end
    GudaChatCharDB = copy
end

local function SaveCharCopy()
    if type(GudaChatCharDB) ~= "table" then return end
    local key = CharCopyKey()
    if not key then return end
    GudaChatCharDB.savedAt = time()
    GudaChatDB.charCopies = GudaChatDB.charCopies or {}
    GudaChatDB.charCopies[key] = GudaChatCharDB
end

---------------------------------------------------------------------------
-- Combat log frame
--
-- ChatFrame2 stays Show()n and is toggled by alpha (ns.SetCombatLogVisible):
-- Show/Hide on it runs Blizzard's protected ClearEventFilters(), which is
-- forbidden in combat. Blizzard dock updates can still hide it, so it is shown
-- again, but only out of combat; in combat that waits for PLAYER_REGEN_ENABLED.
---------------------------------------------------------------------------

local combatLogRegenWatcher = CreateFrame("Frame")

local function KeepCombatLogShown()
    if not ChatFrame2 or ChatFrame2:IsShown() then return end
    if InCombatLockdown() then
        combatLogRegenWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    ChatFrame2:Show()
    ns.SetCombatLogVisible(ns.GetSelectedChatFrame() == ChatFrame2)
end

combatLogRegenWatcher:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    KeepCombatLogShown()
end)

---------------------------------------------------------------------------
-- Chat windows created after login
---------------------------------------------------------------------------

-- Everything a chat window gets at login, for windows that appear later: temporary
-- whisper windows (ChatFrame11 and up) and new windows from the context menu. Runs once
-- per frame; Blizzard reuses closed temporary frames, and their setup is still in place.
local function SetUpLateChatFrame(cf)
    if cf.gudaSetUp then return end
    cf.gudaSetUp = true
    ns.StripChatChrome(cf:GetID())
    if GudaChatDB.chatFont then
        local _, size, flags = cf:GetFont()
        cf:SetFont(GudaChatDB.chatFont, GudaChatDB.chatFontSize or size, flags)
    end
    if GudaChatDB.chatLineSpacing and cf.SetSpacing then
        cf:SetSpacing(GudaChatDB.chatLineSpacing)
    end
    cf:SetFading(GudaChatDB.fading)
    ns.HookLinkClicks(cf)
    ns.CreateScrollbar(cf)
    if GudaChatDB.hideScrollbar and cf.gudaScrollbar then
        cf.gudaScrollbar:Hide()
    end
    if ns.WantsGlobalBackground() then
        ns.ApplyGlobalBackground()
    end
end

-- Whisper tabs show the target without "-Realm"
local function StripRealmFromTab(tab)
    if not tab then return end
    local tabText = tab.Text and tab.Text:GetText() or tab:GetText()
    local shortName = tabText and tabText:match("^([^%-]+)")
    if shortName and shortName ~= tabText then
        if tab.Text then tab.Text:SetText(shortName) else tab:SetText(shortName) end
    end
end

-- After a theme or accent change: rebuild the tab strips in the new colours, and follow
-- the theme's chat background while the player has not chosen their own
ns.Theme.OnChange(function()
    if ns.RequestTabRefresh and ns.chatHeader then
        ns.RequestTabRefresh()
    end
    if GudaChatDB and GudaChatDB.bgFromTheme and GudaChatDB.useGlobalBg and ns.chatHeader then
        ns.ApplyGlobalBackground()
    end
end)

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("PLAYER_LOGOUT")
loader:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        local isFreshInstall = GudaChatDB == nil
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
        if GudaChatDB.highlightName == nil then
            GudaChatDB.highlightName = true
        end
        if GudaChatDB.highlightSound == nil then
            GudaChatDB.highlightSound = true
        end
        if GudaChatDB.locked == nil then
            GudaChatDB.locked = false
        end
        if GudaChatDB.showLevel == nil then
            GudaChatDB.showLevel = false
        end
        if GudaChatDB.emojis == nil then
            GudaChatDB.emojis = false
        end
        if GudaChatDB.emojiSize == nil then
            GudaChatDB.emojiSize = ns.DEFAULT_EMOJI_SIZE
        end
        if GudaChatDB.whisperTab == nil then
            GudaChatDB.whisperTab = false
        end
        if GudaChatDB.abbrevChannels == nil then
            GudaChatDB.abbrevChannels = false
        end
        if GudaChatDB.abbrevInChat == nil then
            GudaChatDB.abbrevInChat = true
        end
        if GudaChatDB.abbrevInHeader == nil then
            GudaChatDB.abbrevInHeader = true
        end
        if type(GudaChatDB.channelAbbrev) ~= "table" then
            GudaChatDB.channelAbbrev = {}
        end
        if GudaChatDB.transparentInput == nil then
            GudaChatDB.transparentInput = false
        end
        if GudaChatDB.useGlobalBg == nil then
            GudaChatDB.useGlobalBg = true
        end
        if GudaChatDB.globalBgAlpha == nil then
            GudaChatDB.globalBgAlpha = 0
        end
        if GudaChatDB.globalBgColor == nil then
            GudaChatDB.globalBgColor = { r = 0.08, g = 0.08, b = 0.08 }
        end
        -- chatFont: nil means default (Fonts\FRIZQT__.TTF)
        if GudaChatDB.showTabBar == nil then
            GudaChatDB.showTabBar = true
        end
        if GudaChatDB.hideIdleText == nil then
            GudaChatDB.hideIdleText = false
        end
        ---------------------------------------------------------------
        -- Per-character storage
        --
        -- Chat history, the loot log and the addon log are recorded per
        -- character; settings stay account-wide so preferences follow
        -- you across alts.
        ---------------------------------------------------------------
        if ns.IS_FOREVER then
            RestoreCharCopy()
        end
        GudaChatCharDB = GudaChatCharDB or {}
        local charDB = GudaChatCharDB

        -- One-time migration from the account-wide tables. Whichever character
        -- logs in first inherits the existing history, then the old copy is
        -- cleared so it is not duplicated onto every alt.
        if type(GudaChatDB.history) == "table" then
            if type(charDB.history) ~= "table" or next(charDB.history) == nil then
                charDB.history = GudaChatDB.history
            end
            GudaChatDB.history = nil
        end
        if type(GudaChatDB.lootLog) == "table" then
            if type(charDB.lootLog) ~= "table" or #charDB.lootLog == 0 then
                charDB.lootLog = GudaChatDB.lootLog
            end
            GudaChatDB.lootLog = nil
        end
        if type(GudaChatDB.addonLog) == "table" then
            if type(charDB.addonLog) ~= "table" or #charDB.addonLog == 0 then
                charDB.addonLog = GudaChatDB.addonLog
            end
            GudaChatDB.addonLog = nil
        end
        GudaChatDB.logSchema = nil  -- moved to the per-character table

        -- History: per-channel buckets
        if type(charDB.history) ~= "table" or charDB.history[1] ~= nil then
            -- Reset if old flat-array format or missing
            charDB.history = {}
        end
        GudaChatDB.historyMax = GudaChatDB.historyMax or 2000
        -- Clamp profiles saved before the slider's range became 500-4000
        if GudaChatDB.historyMax < 500 then
            GudaChatDB.historyMax = 500
        elseif GudaChatDB.historyMax > 4000 then
            GudaChatDB.historyMax = 4000
        end
        if GudaChatDB.historyEnabled == nil then
            GudaChatDB.historyEnabled = true
        end
        -- Loot log and addon message log (separate from the chat history buckets)
        if type(charDB.lootLog) ~= "table" then
            charDB.lootLog = {}
        end
        if type(charDB.addonLog) ~= "table" then
            charDB.addonLog = {}
        end
        if GudaChatDB.logLoot == nil then
            GudaChatDB.logLoot = true
        end
        if GudaChatDB.logAddon == nil then
            GudaChatDB.logAddon = true
        end
        GudaChatDB.lootLogMax = GudaChatDB.lootLogMax or ns.LOOT_LOG_DEFAULT
        GudaChatDB.addonLogMax = GudaChatDB.addonLogMax or ns.ADDON_LOG_DEFAULT
        ns.TrimLog(charDB.lootLog, GudaChatDB.lootLogMax)
        ns.TrimLog(charDB.addonLog, GudaChatDB.addonLogMax)
        -- One-time reset: entries captured before loot, combat log, joined
        -- channels and NPC speech were excluded are still sitting in the
        -- addon log. Bump this whenever the capture rules tighten again.
        if charDB.logSchema ~= 3 then
            wipe(charDB.addonLog)
            charDB.logSchema = 3
        end
        if GudaChatDB.notifications == nil then
            GudaChatDB.notifications = {
                general = true,
                generalTab = true,
                party = true,
                raid = true,
                guild = true,
                whispers = true,
                trade = false,
                lfg = false,
                other = false,
            }
        end
        if GudaChatDB.notifications.generalTab == nil then
            GudaChatDB.notifications.generalTab = true
        end
        if GudaChatDB.bgFromTheme == nil then
            GudaChatDB.bgFromTheme = isFreshInstall
        end
        GudaChatDB.whisperIcon = ns.ApplyWhisperIconDefaults(GudaChatDB.whisperIcon)
        ns.Theme.Init()
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGOUT" then
        if not GudaChatDB then return end
        if ns.UndoWhisperRoutingForLogout then
            ns.UndoWhisperRoutingForLogout()
        end
        if ns.IS_FOREVER then
            SaveCharCopy()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.Theme.Refresh()
        ns.ForEachChatWindow(function(cf, i)
            ns.StripChatChrome(i)
            cf.gudaSetUp = true
        end)
        if ns.WantsGlobalBackground() then
            ns.ApplyGlobalBackground()
        end

        if ChatFrame2 then
            KeepCombatLogShown()
            ns.SetCombatLogVisible(false)
        end

        if GeneralDockManagerOverflowButton then
            -- Hide WITHOUT reparenting. KillFrame reparents onto hiddenParent, but Blizzard's
            -- GeneralDockManagerOverflowButton_UpdateList reads `self:GetParent().DOCKED_CHAT_FRAMES`
            -- during FCF_DockFrame; a hiddenParent has no DOCKED_CHAT_FRAMES, so pairs() crashes.
            -- Keeping it parented to GeneralDockManager (killed/hidden right below) keeps it
            -- invisible while leaving the dock chain intact.
            local ofb = GeneralDockManagerOverflowButton
            ofb:Hide()
            ofb:SetAlpha(0)
            ofb:SetScript("OnShow", ofb.Hide)
        end
        if GeneralDockManager then
            ns.KillFrame(GeneralDockManager)
        end
        if QuickJoinToastButton then
            ns.KillFrame(QuickJoinToastButton)
        end

        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            for _, name in ipairs(CHAT_FRAMES) do
                local cf = _G[name]
                if cf and cf.isTemporary and cf.inUse and cf.isDocked then
                    SetUpLateChatFrame(cf)
                    StripRealmFromTab(_G[name .. "Tab"])
                end
            end
            ns.SyncDockedFrames()
            ns.ApplyChatMargins()
            if ns.RefreshChatSubTabs then ns.RefreshChatSubTabs() end
        end)

        if FCF_OpenNewWindow then
            local windowsBeforeOpen = ns.InUseChatWindows()
            local function RememberWindows()
                windowsBeforeOpen = ns.InUseChatWindows()
            end
            hooksecurefunc("FCF_OpenNewWindow", function()
                local cf = ns.FindNewChatWindow(windowsBeforeOpen)
                if cf then
                    SetUpLateChatFrame(cf)
                    ns.SafeSelectDockFrame(cf)
                end
                RememberWindows()
            end)
            hooksecurefunc("FCF_Close", RememberWindows)
            hooksecurefunc("FCF_DockUpdate", RememberWindows)
        end

        -- Auto-select renamed window and refresh tab label
        if FCF_SetWindowName then
            hooksecurefunc("FCF_SetWindowName", function(chatFrame)
                if chatFrame then
                    ns.SafeSelectDockFrame(chatFrame)
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

        -- Keep ChatFrame1 pinned WITHOUT replacing any Blizzard method. Replacing a method taints
        -- the field; Blizzard secure code that later calls it taints the whole execution -> the 12.0
        -- ChatConfig "secret value" arithmetic crash. ns.CF1_* kept for safety (no readers today).
        ns.CF1_SetPoint = ChatFrame1.SetPoint
        ns.CF1_ClearAllPoints = ChatFrame1.ClearAllPoints

        -- Guard: when false, the re-apply hook is inert (user is actively dragging/resizing).
        ns.cf1PositionLocked = false

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
            if ChatFrame1.SetUserPlaced then ChatFrame1:SetUserPlaced(false) end
        end

        -- Re-apply saved geometry whenever Blizzard tries to manage/move the frame.
        local function ApplySavedGeometry()
            local p = GudaChatDB.position
            ChatFrame1:ClearAllPoints()
            ChatFrame1:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
            if GudaChatDB.chatSize then
                ChatFrame1:SetSize(GudaChatDB.chatSize.w, GudaChatDB.chatSize.h)
            end
            ns.SyncDockedFrames()
        end

        -- _cf1Reapplying guards against re-entry (SetPoint can trigger the hooks that call
        -- this again). It is cleared even when the body throws, or the saved position would
        -- never be re-applied again for the rest of the session.
        local function ReapplyChatFrame1Geometry()
            if ns._cf1Reapplying or not ns.cf1PositionLocked or not GudaChatDB.position then return end
            ns._cf1Reapplying = true
            local ok, err = pcall(ApplySavedGeometry)
            ns._cf1Reapplying = false
            if not ok then geterrorhandler()(err) end
        end
        ns.ReapplyChatFrame1Geometry = ReapplyChatFrame1Geometry

        if UIParent_ManageFramePositions then
            hooksecurefunc("UIParent_ManageFramePositions", ReapplyChatFrame1Geometry)
        end
        ns.HookEditModeChatPosition()

        -- Lock position after initial setup so UIParentPanelManager can't move it
        ns.cf1PositionLocked = true

        ns.ApplyFading()
        -- A profile saved on an English client can carry a Latin-only font that
        -- renders nothing on zhCN/koKR/ruRU. Drop it so the client default is used.
        if GudaChatDB.chatFont and ns.IsFontAllowed and not ns.IsFontAllowed(GudaChatDB.chatFont) then
            GudaChatDB.chatFont = nil
        end
        if GudaChatDB.chatFont then
            ns.ApplyChatFont(GudaChatDB.chatFont)
        end
        if GudaChatDB.chatFontSize then
            ns.ApplyChatFontSize(GudaChatDB.chatFontSize)
        end
        if GudaChatDB.chatLineSpacing then
            ns.ApplyChatLineSpacing(GudaChatDB.chatLineSpacing)
        end
        ns.ApplyClassColors()
        ns.EnableLevelDisplay()
        ns.EnableCopyLinks()
        ns.EnableEmojis()
        ns.EnableNameHighlight()
        ns.EnableChannelAbbrev()
        ns.SetupLinkHook()
        ns.InitHistorySeq()
        ns.RegisterHistoryEvents()
        ns.RegisterLogCapture()
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
        ns.ApplyIdleText()
        ns.InitWhisperIcon()
        ns.ApplyLockState()
        ns.ApplyChatMargins()
        -- The saved position is restored above, before the clamp insets exist. If it no
        -- longer fits (resolution / UI-scale change), settle it now and re-save so
        -- SavedVariables matches what's actually on screen instead of snapping later.
        ns.SettleChatPosition()

        -- Reapply clamp insets after Blizzard dock updates reset them
        if FCF_DockUpdate then
            hooksecurefunc("FCF_DockUpdate", function()
                ns.ApplyChatMargins()
                ns.ReapplyChatFrame1Geometry()
                -- Blizzard's dock update restores each window's own stored color, clobbering our
                -- global background (same reason ApplyChatMargins is re-applied here). Re-apply it.
                if ns.WantsGlobalBackground() then
                    ns.ApplyGlobalBackground()
                end
                KeepCombatLogShown()
            end)
        end

        -- The initial ApplyGlobalBackground above runs before our FCF_DockUpdate hook is
        -- installed, so a dock update during init can recolor after us. Re-apply once more
        -- after init settles to lock in the saved color on load.
        if ns.WantsGlobalBackground() then
            C_Timer.After(0.2, ns.ApplyGlobalBackground)
        end

        -- Blizzard restores its own chat window layout during login, and that can
        -- land after our init has finished, through a path that fires neither
        -- UIParent_ManageFramePositions nor FCF_DockUpdate. Re-assert the saved
        -- geometry once things settle so the frame does not end up back at
        -- Blizzard's default after a reload.
        if GudaChatDB.position then
            C_Timer.After(0.5, ns.ReapplyChatFrame1Geometry)
            C_Timer.After(2.0, ns.ReapplyChatFrame1Geometry)
        end

        ns.ReplayHistory()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffGudaChat|r " .. L["LOADED"])
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
