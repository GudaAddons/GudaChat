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
    elseif msg == "debugfilters" then
        local cf = DEFAULT_CHAT_FRAME
        cf:AddMessage("|cff00ccffGudaChat|r combat log filter debug:")
        cf:AddMessage("QUICKBUTTON_NAME_SELF = " .. tostring(QUICKBUTTON_NAME_SELF))
        cf:AddMessage("QUICKBUTTON_NAME_ME = " .. tostring(QUICKBUTTON_NAME_ME))
        cf:AddMessage("COMBATLOG_FILTER_ME = " .. tostring(COMBATLOG_FILTER_ME))
        cf:AddMessage("Blizzard_CombatLog_ApplyFilters = " .. tostring(Blizzard_CombatLog_ApplyFilters))
        cf:AddMessage("Blizzard_CombatLog_Refilter = " .. tostring(Blizzard_CombatLog_Refilter))
        cf:AddMessage("CombatLog_SwitchToFilter = " .. tostring(CombatLog_SwitchToFilter))
        cf:AddMessage("ChatFrame2.combatLogProcessor = " .. tostring(ChatFrame2 and ChatFrame2.combatLogProcessor))
        -- Scan ChatFrame2 for processor-like keys
        if ChatFrame2 then
            local cf2keys = {}
            for k, v in pairs(ChatFrame2) do
                if type(k) == "string" and (k:lower():find("combat") or k:lower():find("processor") or k:lower():find("filter")) then
                    tinsert(cf2keys, k .. "=" .. type(v))
                end
            end
            cf:AddMessage("ChatFrame2 combat keys: " .. (#cf2keys > 0 and table.concat(cf2keys, ", ") or "none"))
        end
        -- Scan globals for CombatLog functions
        local found = {}
        for k, v in pairs(_G) do
            if type(k) == "string" and k:find("CombatLog") and (type(v) == "function" or type(v) == "table") then
                tinsert(found, k .. "=" .. type(v))
            end
        end
        table.sort(found)
        cf:AddMessage("CombatLog globals: " .. (#found > 0 and table.concat(found, ", ") or "none"))
        cf:AddMessage("Blizzard_CombatLog_CurrentSettings = " .. tostring(Blizzard_CombatLog_CurrentSettings))
        cf:AddMessage("currentFilter = " .. tostring(Blizzard_CombatLog_Filters and Blizzard_CombatLog_Filters.currentFilter))
        if Blizzard_CombatLog_Filters and Blizzard_CombatLog_Filters.filters then
            local filters = Blizzard_CombatLog_Filters.filters
            cf:AddMessage("Total filters: " .. #filters)
            for i, f in ipairs(filters) do
                cf:AddMessage("  [" .. i .. "] name=" .. tostring(f.name) .. " | quickButtonName=" .. tostring(f.quickButtonName))
            end
        else
            cf:AddMessage("Blizzard_CombatLog_Filters not available")
        end
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
        -- History: per-channel buckets
        if type(GudaChatDB.history) ~= "table" or GudaChatDB.history[1] ~= nil then
            -- Reset if old flat-array format or missing
            GudaChatDB.history = {}
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
        if type(GudaChatDB.lootLog) ~= "table" then
            GudaChatDB.lootLog = {}
        end
        if type(GudaChatDB.addonLog) ~= "table" then
            GudaChatDB.addonLog = {}
        end
        if GudaChatDB.logLoot == nil then
            GudaChatDB.logLoot = true
        end
        if GudaChatDB.logAddon == nil then
            GudaChatDB.logAddon = true
        end
        -- One-time reset: entries captured before loot, combat log, joined
        -- channels and NPC speech were excluded are still sitting in the
        -- addon log. Bump this whenever the capture rules tighten again.
        if GudaChatDB.logSchema ~= 3 then
            wipe(GudaChatDB.addonLog)
            GudaChatDB.logSchema = 3
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
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.ForEachChatWindow(function(_, i) ns.StripChatChrome(i) end)
        if GudaChatDB.useGlobalBg and GudaChatDB.globalBgAlpha > 0 then
            ns.ApplyGlobalBackground()
        end

        -- On modern engines, Show/Hide on ChatFrame2 triggers protected ClearEventFilters()
        -- which causes taint during combat. We Show() it once here (safe, not in combat)
        -- and keep it always "shown" — SafeSelectDockFrame uses SetAlpha(0/1) to toggle.
        if ns.IS_MODERN and ChatFrame2 then
            ChatFrame2:Show()
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
                        cf:SetFont(GudaChatDB.chatFont, GudaChatDB.chatFontSize or size, flags)
                    end
                    -- Strip realm from tab name
                    local tab = _G[name .. "Tab"]
                    if tab then
                        local tabText = tab.Text and tab.Text:GetText() or tab:GetText()
                        if tabText then
                            local shortName = tabText:match("^([^%-]+)")
                            if shortName and shortName ~= tabText then
                                if tab.Text then tab.Text:SetText(shortName) else tab:SetText(shortName) end
                            end
                        end
                    end
                end
            end
            -- StripChatChrome above leaves the new window without our clamp insets
            ns.ApplyChatMargins()
            if ns.RefreshChatSubTabs then ns.RefreshChatSubTabs() end
        end)

        -- Auto-select newly created chat windows
        if FCF_OpenNewWindow then
            hooksecurefunc("FCF_OpenNewWindow", function()
                for i = NUM_CHAT_WINDOWS, 1, -1 do
                    local cf = _G["ChatFrame" .. i]
                    if cf and cf:IsShown() then
                        ns.SafeSelectDockFrame(cf)
                        break
                    end
                end
            end)
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

        -- Remove ChatFrame1 from Blizzard's managed frame layout so
        -- UIParent_ManageFramePositions stops repositioning it
        if UIPARENT_MANAGED_FRAME_POSITIONS then
            UIPARENT_MANAGED_FRAME_POSITIONS["ChatFrame1"] = nil
        end

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
        local function ReapplyChatFrame1Geometry()
            if ns._cf1Reapplying then return end          -- reentrancy guard
            if not ns.cf1PositionLocked then return end     -- user dragging/resizing; leave it
            if not GudaChatDB.position then return end
            ns._cf1Reapplying = true
            local p = GudaChatDB.position
            ChatFrame1:ClearAllPoints()
            ChatFrame1:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
            if GudaChatDB.chatSize then
                ChatFrame1:SetSize(GudaChatDB.chatSize.w, GudaChatDB.chatSize.h)
            end
            -- Docked/temporary frames must follow, or they stay behind at the old spot
            ns.SyncDockedFrames()
            ns._cf1Reapplying = false
        end
        ns.ReapplyChatFrame1Geometry = ReapplyChatFrame1Geometry

        if UIParent_ManageFramePositions then
            hooksecurefunc("UIParent_ManageFramePositions", ReapplyChatFrame1Geometry)
        end

        -- Lock position after initial setup so UIParentPanelManager can't move it
        ns.cf1PositionLocked = true

        ChatFrame1:SetFading(GudaChatDB.fading)
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
        ns.ApplyClassColors()
        ns.EnableLevelDisplay()
        ns.EnableCopyLinks()
        ns.EnableEmojis()
        ns.EnableNameHighlight()
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
                if GudaChatDB.useGlobalBg and GudaChatDB.globalBgAlpha > 0 then
                    ns.ApplyGlobalBackground()
                end
                -- On modern engines, keep ChatFrame2 always "shown" (alpha controls visibility)
                -- Blizzard dock updates can re-hide it.
                if ns.IS_MODERN and ChatFrame2 and not ChatFrame2:IsShown() then
                    ChatFrame2:Show()
                    local sel = SELECTED_CHAT_FRAME or (GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.selected)
                    ns.SetCombatLogVisible(sel == ChatFrame2)
                end
            end)
        end

        -- The initial ApplyGlobalBackground above runs before our FCF_DockUpdate hook is
        -- installed, so a dock update during init can recolor after us. Re-apply once more
        -- after init settles to lock in the saved color on load.
        if GudaChatDB.useGlobalBg and GudaChatDB.globalBgAlpha > 0 then
            C_Timer.After(0.2, ns.ApplyGlobalBackground)
        end

        ns.ReplayHistory()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffGudaChat|r loaded — type |cffffd200/gc|r for settings")
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
