local addonName, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Tab model: which tabs exist, their colours and saved order, and unread blink state.
-- Both tab strips (the bar above the header and the inline tabs) render from this.
---------------------------------------------------------------------------

-- Tab blink state: frameIndex values that have unread messages
local blinkingTabs = {}

-- Chat events that should trigger tab blink notifications
local BLINK_EVENTS = {
    CHAT_MSG_SAY = "SAY", CHAT_MSG_YELL = "YELL", CHAT_MSG_EMOTE = "EMOTE",
    CHAT_MSG_GUILD = "GUILD", CHAT_MSG_OFFICER = "OFFICER",
    CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT", CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
    CHAT_MSG_WHISPER = "WHISPER", CHAT_MSG_BN_WHISPER = "BN_WHISPER",
    CHAT_MSG_CHANNEL = "CHANNEL",
}

-- Map events to notification category keys in GudaChatDB.notifications
local EVENT_TO_NOTIFY_CATEGORY = {
    CHAT_MSG_PARTY = "party", CHAT_MSG_PARTY_LEADER = "party",
    CHAT_MSG_RAID = "raid", CHAT_MSG_RAID_LEADER = "raid", CHAT_MSG_RAID_WARNING = "raid",
    CHAT_MSG_INSTANCE_CHAT = "raid", CHAT_MSG_INSTANCE_CHAT_LEADER = "raid",
    CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "guild",
    CHAT_MSG_WHISPER = "whispers", CHAT_MSG_BN_WHISPER = "whispers",
}

-- Numeric zone channel ids, which are the same on every locale (2 = Trade,
-- 26 = LookingForGroup). channelBaseName is translated and cannot be matched.
local ZONE_CHANNEL_CATEGORY = { [2] = "trade", [26] = "lfg" }

-- Notification category of a numbered channel message. arg7 (zoneChannelID) is the 5th
-- vararg after msg and sender, arg9 (channelBaseName) the 7th. Custom channels report no
-- zone id; the English names stay as a secondary test so enUS behaviour is unchanged.
local function ChannelCategory(...)
    local _, _, _, _, zoneID, _, channelName = ...
    local category = ZONE_CHANNEL_CATEGORY[zoneID]
    if category then return category end
    if channelName and channelName:find("Trade") then return "trade" end
    if channelName and channelName:find("LookingForGroup") then return "lfg" end
    return "other"
end

-- False when the player turned notifications off for this message's category. General
-- is the master toggle.
local function NotificationAllowed(event, ...)
    local notif = GudaChatDB.notifications
    if not notif then return true end
    if not notif.general then return false end
    local category = EVENT_TO_NOTIFY_CATEGORY[event]
    if event == "CHAT_MSG_CHANNEL" then
        category = ChannelCategory(...)
    end
    return not category or notif[category]
end

local function MarkBlinking(idx)
    if blinkingTabs[idx] then return false end
    blinkingTabs[idx] = true
    return true
end

-- Permanent windows (not the selected one, not the combat log) that are hidden behind the
-- selected tab and receive this message group start blinking
local function BlinkPermanentWindows(event, msgGroup, selectedIdx)
    local notif = GudaChatDB.notifications
    local changed = false
    local plainGroup = event:gsub("CHAT_MSG_", "")
    for i = 1, NUM_CHAT_WINDOWS do
        local skipGeneral = i == 1 and notif and not notif.generalTab
        if i ~= selectedIdx and i ~= 2 and not skipGeneral then
            local cf = _G["ChatFrame" .. i]
            if cf and (cf.isDocked or i == 1) and not cf:IsShown() then
                for _, grp in ipairs({ GetChatWindowMessages(i) }) do
                    if (grp == msgGroup or grp == plainGroup) and MarkBlinking(i) then
                        changed = true
                    end
                end
            end
        end
    end
    return changed
end

-- Temporary whisper windows blink when their chat target sent the whisper
local function BlinkWhisperWindows(sender, selectedIdx)
    if not CHAT_FRAMES then return false end
    local changed = false
    for _, frameName in ipairs(CHAT_FRAMES) do
        local cf = _G[frameName]
        if cf and cf.isTemporary and cf.inUse and cf.isDocked then
            local idx = cf:GetID()
            if idx ~= selectedIdx and not cf:IsShown()
                and ns.SameCharacter(cf.chatTarget, sender) and MarkBlinking(idx) then
                changed = true
            end
        end
    end
    return changed
end

local blinkListener = CreateFrame("Frame")
blinkListener:SetScript("OnEvent", function(self, event, msg, sender, ...)
    if not GudaChatDB or not (GudaChatDB.showTabBar or GudaChatDB.inlineTabBar) then return end
    local msgGroup = BLINK_EVENTS[event]
    if not msgGroup then return end
    if not NotificationAllowed(event, ...) then return end
    if ns.SameCharacter(sender, ns.UnitFullName("player")) then return end

    local selectedIdx = ns.GetSelectedChatFrameIndex()
    local changed = BlinkPermanentWindows(event, msgGroup, selectedIdx)
    if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
        changed = BlinkWhisperWindows(sender, selectedIdx) or changed
    end

    if changed then
        ns.RequestTabRefresh()
        if ns.ShowTabBar then ns.ShowTabBar() end
        if GudaChatDB.inlineTabBar then
            ns.RevealHeader()
        end
    end
end)

for ev in pairs(BLINK_EVENTS) do
    blinkListener:RegisterEvent(ev)
end

-- Selecting a tab marks it read, on Blizzard's path and on GudaChat's own
local function ClearBlinkFor(cf)
    if cf and cf.GetID then
        blinkingTabs[cf:GetID()] = nil
    end
end
hooksecurefunc("FCF_SelectDockFrame", ClearBlinkFor)
ns.OnFrameSelected(ClearBlinkFor)

function ns.IsTabBlinking(frameIndex)
    return blinkingTabs[frameIndex] == true
end

function ns.ClearTabBlink(frameIndex)
    blinkingTabs[frameIndex] = nil
end

function ns.HasBlinkingTabs()
    return next(blinkingTabs) ~= nil
end

-- Drops unread marks for tabs that are no longer shown in the tab bar (closed windows,
-- the Whispers window after the Whispers tab is turned off), so they cannot keep the
-- tab bar and the header pinned visible with nothing to click.
function ns.PruneBlinksToTabs(allTabs)
    local rendered = {}
    for _, def in ipairs(allTabs) do
        rendered[def.frameIndex] = true
    end
    for idx in pairs(blinkingTabs) do
        if not rendered[idx] then
            blinkingTabs[idx] = nil
        end
    end
end

---------------------------------------------------------------------------
-- Tab colours
---------------------------------------------------------------------------

-- Map common tab names to Blizzard ChatTypeInfo keys. GetChatWindowInfo returns
-- the name translated, so the localized globals are registered alongside the
-- English defaults — without them non-English tabs fell through to the default tint.
local TAB_NAME_TO_CHATTYPE = {
    ["Guild"]    = "GUILD",
    ["Party"]    = "PARTY",
    ["Raid"]     = "RAID",
    ["Whispers"] = "WHISPER",
    ["Officer"]  = "OFFICER",
    ["Say"]      = "SAY",
    ["Yell"]     = "YELL",
}

-- Positional pairs, not a keyed table: a missing global would be a nil key and "table
-- index is nil" is a load-time error. Several of these are absent on older flavors.
local LOCALIZED_TAB_NAMES = {
    { GUILD, "GUILD" }, { PARTY, "PARTY" }, { RAID, "RAID" },
    { OFFICER, "OFFICER" }, { SAY, "SAY" }, { YELL, "YELL" },
    { WHISPER, "WHISPER" }, { WHISPERS, "WHISPER" },
}
for _, pair in ipairs(LOCALIZED_TAB_NAMES) do
    local name, chatType = pair[1], pair[2]
    if type(name) == "string" and name ~= "" and not TAB_NAME_TO_CHATTYPE[name] then
        TAB_NAME_TO_CHATTYPE[name] = chatType
    end
end

local TAB_COLOR_DEFAULT = { 0.8, 0.6, 0.0 }
local TAB_COLOR_GENERAL = { 1.0, 1.0, 0.0 }

local function ChatTypeColor(chatType)
    local info = chatType and ChatTypeInfo[chatType]
    return info and { info.r, info.g, info.b } or nil
end

-- Colour of a numbered channel window: GetChatWindowChannels returns channel names,
-- resolved to a number via GetChannelName
local function ChannelWindowColor(frameIndex)
    if not (GetChatWindowChannels and GetChannelName) then return nil end
    for _, chName in ipairs({ GetChatWindowChannels(frameIndex) }) do
        if type(chName) == "string" then
            local chNum = GetChannelName(chName)
            if chNum and chNum > 0 then
                local col = ChatTypeColor("CHANNEL" .. chNum)
                if col then return col end
            end
        end
    end
    return nil
end

-- Tab text colour: General is yellow, known tab names use their chat type's colour,
-- channel windows their channel colour, other windows their first message group's colour.
-- GENERAL is the localized global; the literal keeps enUS behaviour if it is missing.
local function GetTabColor(name, frameIndex)
    if name == "General" or (GENERAL and name == GENERAL) then return TAB_COLOR_GENERAL end

    local col = ChatTypeColor(TAB_NAME_TO_CHATTYPE[name])
    if col then return col end

    if frameIndex then
        col = ChannelWindowColor(frameIndex)
        if col then return col end
        if GetChatWindowMessages then
            col = ChatTypeColor((GetChatWindowMessages(frameIndex)))
            if col then return col end
        end
    end

    return TAB_COLOR_DEFAULT
end
ns.GetTabColor = GetTabColor

---------------------------------------------------------------------------
-- Tab collection and order
---------------------------------------------------------------------------

-- Every docked window that gets a tab, as { name, col, frameIndex, cf, isTemp }:
-- shown permanent windows except the combat log (the Whispers window only while the
-- Whispers tab is on), then docked temporary whisper windows. Saved order applied.
function ns.CollectChatTabs()
    local allTabs = {}

    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if cf and tab then
            local isDocked = cf.isDocked or (i == 1)
            local shown = (i == 1) or tab:IsShown()
            local hiddenWhisper = not GudaChatDB.whisperTab and ns.whisperFrame and cf == ns.whisperFrame
            if isDocked and shown and i ~= 2 and not hiddenWhisper then
                local name = ns.GetChatTabName(i)
                tinsert(allTabs, { name = name, col = GetTabColor(name, i), frameIndex = i, cf = cf })
            end
        end
    end

    if CHAT_FRAMES then
        for _, frameName in ipairs(CHAT_FRAMES) do
            local cf = _G[frameName]
            if cf and cf.isTemporary and cf.inUse and cf.isDocked then
                local idx = cf:GetID()
                local tab = _G[frameName .. "Tab"]
                local name = tab and (tab.Text and tab.Text:GetText() or tab:GetText()) or string.format(L["CHAT_WINDOW_NUMBER"], idx)
                local isWhisper = cf.chatType == "WHISPER" or cf.chatType == "BN_WHISPER"
                local col = isWhisper and ChatTypeColor("WHISPER") or GetTabColor(name, idx)
                tinsert(allTabs, { name = name, col = col, frameIndex = idx, cf = cf, isTemp = true })
            end
        end
    end

    ns.ApplySavedTabOrder(allTabs)
    return allTabs
end

function ns.ApplySavedTabOrder(allTabs)
    local saved = GudaChatDB.tabOrder
    if not saved or #saved == 0 then return end
    local orderMap = {}
    for pos, frameIdx in ipairs(saved) do
        orderMap[frameIdx] = pos
    end
    local nextPos = #saved + 1
    table.sort(allTabs, function(a, b)
        local posA = orderMap[a.frameIndex] or nextPos
        local posB = orderMap[b.frameIndex] or nextPos
        if posA == posB then
            return a.frameIndex < b.frameIndex
        end
        return posA < posB
    end)
end

local function SaveTabOrder(allTabs)
    local order = {}
    for _, def in ipairs(allTabs) do
        tinsert(order, def.frameIndex)
    end
    GudaChatDB.tabOrder = order
end

-- Saves a drag-and-drop move. allTabs is the order on screen, which can differ from the
-- saved order: the selected tab is swapped into the last visible slot when it would
-- otherwise sit in the overflow menu. The move is applied to baseOrder (the order before
-- that swap), so the temporary swap is never saved.
function ns.SaveTabMove(baseOrder, allTabs, srcIdx, insertIdx, fitCount)
    local moved = allTabs[srcIdx]
    if not moved then return end
    local before = insertIdx <= fitCount and allTabs[insertIdx] or nil
    local after = not before and allTabs[fitCount] or nil
    local order = {}
    for _, def in ipairs(baseOrder) do
        if def ~= moved then tinsert(order, def) end
    end
    local pos = #order + 1
    for i, def in ipairs(order) do
        if def == before then
            pos = i
            break
        elseif def == after then
            pos = i + 1
            break
        end
    end
    tinsert(order, pos, moved)
    SaveTabOrder(order)
end
