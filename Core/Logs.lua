local addonName, ns = ...

---------------------------------------------------------------------------
-- Loot log and addon message log
--
-- Both are stored as top-level GudaChatDB arrays, deliberately NOT inside
-- GudaChatDB.history: InitHistorySeq deletes any history entry without string
-- sender/message fields, and #HISTORY_FILTER_KEYS is the per-channel prune
-- divisor, so adding buckets there would shrink every chat channel's cap.
---------------------------------------------------------------------------

local function Cap()
    return GudaChatDB and GudaChatDB.historyMax or 2000
end

local function Push(list, entry)
    if type(list) ~= "table" then return end
    tinsert(list, entry)
    local max = Cap()
    while #list > max do
        tremove(list, 1)
    end
end

---------------------------------------------------------------------------
-- Loot source tracking
--
-- CHAT_MSG_LOOT carries the looter but never the unit that dropped the item,
-- so remember it while the loot window is open and attach it to the loot
-- lines that follow.
---------------------------------------------------------------------------

local lastLootSource
local clearSourceAt

-- Read the loot window title across client versions (the frame differs).
local function LootWindowTitle()
    local fs = _G["LootFrameTitleText"]
    if not fs and LootFrame then
        fs = LootFrame.TitleText or LootFrame.Title
    end
    if fs and fs.GetText then
        local ok, text = pcall(fs.GetText, fs)
        if ok and type(text) == "string" and text ~= "" then
            return text
        end
    end
    return nil
end

local function CaptureLootSource()
    clearSourceAt = nil

    -- A looted corpse is normally the current target. UnitName can return a
    -- secret string on modern clients while we're tainted, so it must go
    -- through SafeName before it can be stored or compared.
    if UnitExists("target") and UnitIsDead("target") then
        local name = ns.SafeName(UnitName("target"))
        if name and name ~= "" then
            lastLootSource = name
            return
        end
    end

    -- Chests, herb nodes, ore veins, mail: no unit, but the window is titled.
    lastLootSource = LootWindowTitle()
end

local lootFrame = CreateFrame("Frame")
lootFrame:SetScript("OnEvent", function(self, event, msg, sender, ...)
    if not GudaChatDB then return end

    if event == "LOOT_READY" or event == "LOOT_OPENED" then
        CaptureLootSource()
        return
    end

    if event == "LOOT_CLOSED" then
        -- Not cleared immediately: with autoloot, CHAT_MSG_LOOT can arrive
        -- after the window has already closed.
        clearSourceAt = GetTime() + 2
        C_Timer.After(2, function()
            if clearSourceAt and GetTime() >= clearSourceAt then
                lastLootSource = nil
                clearSourceAt = nil
            end
        end)
        return
    end

    -- CHAT_MSG_LOOT
    if not GudaChatDB.logLoot then return end
    local text = ns.SafeName(msg)
    if not text then return end

    local link = text:match("(|c%x+|Hitem:.-|h.-|h|r)") or text:match("(|Hitem:.-|h.-|h)")
    if not link then return end

    -- LOOT_ITEM_*_MULTIPLE is "...%sx%d." — the count trails the link, with or
    -- without a space depending on locale. No match means a single item.
    local count = tonumber(text:match("|rx(%d+)")
        or text:match("|r%s*x(%d+)")
        or text:match("x(%d+)%.?%s*$")) or 1

    Push(GudaChatDB.lootLog, {
        time = time(),
        -- The event's message is already the finished, localized chat line
        -- ("You receive loot: [Item]x2.", "Vieta receives loot: [Item]."), so
        -- storing it verbatim makes the Loot tab read exactly like chat.
        message = text,
        item = link,
        count = count,
        looter = ns.SafeName(sender) or "",
        source = lastLootSource,
    })
end)

---------------------------------------------------------------------------
-- Addon message capture
--
-- Addons print through frame:AddMessage, which never reaches a chat message
-- event filter. Hook AddMessage (via hooksecurefunc — assigning our own
-- closure to a Blizzard frame method taints the field) and treat everything
-- that did not arrive as a chat event as addon output.
---------------------------------------------------------------------------

local pendingChat = 0
local resetQueued = false

-- The counter alone is not enough: it assumes every filtered message reaches a
-- hooked AddMessage exactly once, which breaks whenever a message is suppressed,
-- shown in a frame we skip, or routed through a path of its own. So also keep the
-- raw body of recent chat messages and reject any line that contains one. This is
-- what catches NPC speech (MONSTER_YELL and friends), whose sender is not wrapped
-- in a player link and so slips past the hyperlink test below.
local RECENT_MAX = 16
local MIN_BODY = 12          -- shorter bodies would match far too eagerly
local recentChat = {}
local recentIdx = 0

local function RememberChatBody(msg)
    -- Always via SafeName: this runs inside a filter callback, where a secret
    -- string still reports type "string" but throws on any read such as #msg.
    local text = ns.SafeName(msg)
    if not text or #text < MIN_BODY then return end
    recentIdx = recentIdx % RECENT_MAX + 1
    recentChat[recentIdx] = text
end

local function MatchesRecentChat(text)
    for i = 1, RECENT_MAX do
        local body = recentChat[i]
        if body and text:find(body, 1, true) then return true end
    end
    return false
end

local function MarkChatEvent(self, event, msg)
    RememberChatBody(msg)
    pendingChat = pendingChat + 1
    if not resetQueued then
        resetQueued = true
        -- A filter that suppresses a message never reaches AddMessage, so the
        -- count must not survive the frame it was raised in.
        C_Timer.After(0, function()
            pendingChat = 0
            resetQueued = false
        end)
    end
    return false
end

local function StripColors(text)
    local ok, plain = pcall(function()
        return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end)
    return ok and plain or nil
end

-- Second line of defence behind the marker filter. Blizzard wraps the sender of
-- every chat line in a player link, and numbered channels add a channel link;
-- addon output never contains either. Needed because the marker misses any chat
-- path that reaches AddMessage without running the message event filters, which
-- is how joined channels (LookingForGroup and friends) were leaking into the log.
local CHAT_LINK_MARKERS = { "|Hplayer:", "|HBNplayer:", "|Hchannel:" }

local function LooksLikeChatLine(text)
    for _, marker in ipairs(CHAT_LINK_MARKERS) do
        if text:find(marker, 1, true) then return true end
    end
    -- Bare channel prefix, e.g. "[4. LookingForGroup]", when links are stripped
    local plain = StripColors(text) or text
    if plain:match("^%s*%[%d+%.%s") then return true end
    return false
end

local function OnAddMessage(frame, msg)
    if not GudaChatDB or not GudaChatDB.logAddon then return end
    -- ReplayHistory writes last session's chat back into ChatFrame1; those are
    -- not chat events and would otherwise all be logged as addon output.
    if ns._replayingHistory then return end
    if type(msg) ~= "string" then return end

    if pendingChat > 0 then
        pendingChat = pendingChat - 1
        return
    end

    local text = ns.SafeName(msg)
    if not text or text == "" then return end
    if LooksLikeChatLine(text) then return end
    if MatchesRecentChat(text) then return end

    local plain = StripColors(text) or text
    local tag = plain:match("^%s*%[(.-)%]")

    Push(GudaChatDB.addonLog, {
        time = time(),
        tag = tag,
        message = text,
    })
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

function ns.RegisterLogCapture()
    lootFrame:RegisterEvent("CHAT_MSG_LOOT")
    lootFrame:RegisterEvent("LOOT_READY")
    lootFrame:RegisterEvent("LOOT_OPENED")
    lootFrame:RegisterEvent("LOOT_CLOSED")

    -- Mark every chat event this client knows about. Deriving the list from
    -- ChatTypeInfo self-adapts per version and covers the events
    -- ns.CHAT_MSG_CHANNELS omits (LOOT, SYSTEM, MONSTER_*, ACHIEVEMENT, ...).
    local marked = {}
    local function Mark(event)
        if marked[event] then return end
        marked[event] = true
        ChatFrame_AddMessageEventFilter(event, MarkChatEvent)
    end

    if ChatTypeInfo then
        for chatType in pairs(ChatTypeInfo) do
            Mark("CHAT_MSG_" .. chatType)
        end
    end
    -- Explicit floor: ChatTypeInfo's contents vary by client, and joined
    -- channels must be marked or they end up in the addon log.
    Mark("CHAT_MSG_CHANNEL")
    Mark("CHAT_MSG_CHANNEL_JOIN")
    Mark("CHAT_MSG_CHANNEL_LEAVE")
    Mark("CHAT_MSG_CHANNEL_NOTICE")
    Mark("CHAT_MSG_CHANNEL_NOTICE_USER")
    Mark("CHAT_MSG_CHANNEL_LIST")
    Mark("CHAT_MSG_SYSTEM")
    -- Loot has its own tab; it must never also count as addon output
    Mark("CHAT_MSG_LOOT")
    Mark("CHAT_MSG_CURRENCY")
    Mark("CHAT_MSG_MONEY")
    -- NPC speech: no player link on the sender, so the hyperlink test can't see it
    Mark("CHAT_MSG_MONSTER_SAY")
    Mark("CHAT_MSG_MONSTER_YELL")
    Mark("CHAT_MSG_MONSTER_WHISPER")
    Mark("CHAT_MSG_MONSTER_EMOTE")
    Mark("CHAT_MSG_MONSTER_PARTY")
    Mark("CHAT_MSG_RAID_BOSS_EMOTE")
    Mark("CHAT_MSG_RAID_BOSS_WHISPER")
    Mark("CHAT_MSG_EMOTE")
    Mark("CHAT_MSG_TEXT_EMOTE")
    for _, event in ipairs(ns.CHAT_MSG_CHANNELS) do
        Mark(event)
    end

    ns.ForEachChatWindow(function(cf)
        -- Skip the combat log: Blizzard_CombatLog formats its lines itself and
        -- calls AddMessage directly, bypassing the message event filters, so
        -- every combat line would be counted as addon output.
        if cf == ChatFrame2 or cf.isCombatLog then return end
        if cf.AddMessage and not cf.gudaLogHooked then
            cf.gudaLogHooked = true
            hooksecurefunc(cf, "AddMessage", OnAddMessage)
        end
    end)
end
