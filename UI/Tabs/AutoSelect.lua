local addonName, ns = ...

---------------------------------------------------------------------------
-- Auto-select the tab an incoming message belongs to, and keep System and Skill
-- messages on every tab. The rules are in Core/TabRouting.lua.
---------------------------------------------------------------------------

-- Every switch counts towards the hold time, on Blizzard's path and on GudaChat's own
hooksecurefunc("FCF_SelectDockFrame", ns.NoteTabSwitch)
ns.OnFrameSelected(ns.NoteTabSwitch)

-- True when cf shows this message. A temporary whisper window shows its own person's
-- whispers; sender may be a secret string (SameCharacter is taint-safe).
local function ShowsMessage(cf, group, channelKey, sender)
    if cf.isTemporary then
        return group == "WHISPER" and cf.chatType == "WHISPER" and ns.SameCharacter(cf.chatTarget, sender)
    end
    if channelKey then
        return ns.WindowHasChannel(cf:GetID(), channelKey)
    end
    return ns.WindowHasGroup(cf:GetID(), group)
end

local autoSelectFrame = CreateFrame("Frame")
autoSelectFrame:SetScript("OnEvent", function(self, event, msg, sender, ...)
    local channelName = select(7, ...)
    local group = ns.AutoSelectGroup(event, channelName)
    if not group then return end
    if ns.SameCharacter(sender, ns.UnitFullName("player")) then return end
    -- Typing in the chat input (or any other box) is never interrupted
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then return end
    if ns.AutoSelectOnHold() then return end

    local selected = ns.GetSelectedChatFrame()
    if selected == ChatFrame2 then return end
    local channelKey = event == "CHAT_MSG_CHANNEL" and ns.ChannelKey(channelName) or nil
    -- General shows nearly everything, so it is the fallback, not a match: from General a
    -- party message still opens the Party tab
    if selected and selected ~= ChatFrame1 and ShowsMessage(selected, group, channelKey, sender) then return end

    for _, def in ipairs(ns.CollectChatTabs()) do
        if def.cf ~= ChatFrame1 and ShowsMessage(def.cf, group, channelKey, sender) then
            ns.SafeSelectDockFrame(def.cf)
            return
        end
    end
    if selected ~= ChatFrame1 and ShowsMessage(ChatFrame1, group, channelKey, sender) then
        ns.SafeSelectDockFrame(ChatFrame1)
    end
end)
for event in pairs(ns.AUTO_SELECT_EVENTS) do
    autoSelectFrame:RegisterEvent(event)
end

---------------------------------------------------------------------------
-- System and Skill on every tab
---------------------------------------------------------------------------

-- Docked permanent windows except the combat log and the Whispers window. General is
-- always docked. GetChatWindowInfo returns the stored shown (7th) and docked (9th) state.
local function WantsSharedGroups(cf, idx)
    if idx == 2 or (ns.whisperFrame and cf == ns.whisperFrame) then return false end
    if idx == 1 then return true end
    local _, _, _, _, _, _, shown, _, docked = GetChatWindowInfo(idx)
    return (cf.isDocked or docked) and shown and true or false
end

-- Adds or removes the shared groups so they match the setting. The record of what
-- GudaChat added is per character, like Blizzard's chat window config.
function ns.ApplySharedGroups()
    if not GudaChatDB or not GudaChatCharDB then return end
    if type(GudaChatCharDB.sharedGroupsAdded) ~= "table" then GudaChatCharDB.sharedGroupsAdded = {} end
    local added = GudaChatCharDB.sharedGroupsAdded

    local windows = {}
    for idx = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. idx]
        if cf then
            local groups = {}
            for _, grp in ipairs({ GetChatWindowMessages(idx) }) do
                groups[grp] = true
            end
            windows[idx] = { eligible = WantsSharedGroups(cf, idx), groups = groups }
        end
    end

    for _, change in ipairs(ns.PlanSharedGroups(windows, added, GudaChatDB.systemOnAllTabs)) do
        local cf = _G["ChatFrame" .. change.idx]
        if change.add then
            if ChatFrame_AddMessageGroup then ChatFrame_AddMessageGroup(cf, change.group) end
            if AddChatWindowMessages then AddChatWindowMessages(change.idx, change.group) end
            added[change.idx] = added[change.idx] or {}
            added[change.idx][change.group] = true
        else
            if change.present then
                if ChatFrame_RemoveMessageGroup then ChatFrame_RemoveMessageGroup(cf, change.group) end
                if RemoveChatWindowMessages then RemoveChatWindowMessages(change.idx, change.group) end
            end
            added[change.idx][change.group] = nil
            if next(added[change.idx]) == nil then added[change.idx] = nil end
        end
    end
end

-- New, closed, docked and undocked windows are re-checked once Blizzard has finished
-- setting them up
local function QueueSharedGroups()
    C_Timer.After(0, ns.ApplySharedGroups)
end
for _, fn in ipairs({ "FCF_OpenNewWindow", "FCF_Close", "FCF_DockFrame", "FCF_UnDockFrame" }) do
    if _G[fn] then hooksecurefunc(fn, QueueSharedGroups) end
end
