local addonName, ns = ...

---------------------------------------------------------------------------
-- Hide realm names
--
-- Blizzard builds both the shown name and the player link from the sender (arg2), so a
-- message filter can only shorten the two together, and whispers to cross-realm players
-- would then go to the wrong realm. Instead the line is rewritten after it is drawn: only
-- the shown text of each player link loses its "-Realm", the link keeps the full name.
--
-- Classic clients only (Era, Anniversary, MoP). There the chat frame keeps its lines in a
-- Lua history buffer we can edit. On Retail and Forever senders can be secret values and
-- the chat path is taint-sensitive, so the option is not offered there.
---------------------------------------------------------------------------

ns.CAN_HIDE_REALMS = not ns.HAS_MAINLINE_CHAT

-- "[|cffc79c6eName-Realm|r]" -> "[|cffc79c6eName|r]". Player names never contain a hyphen,
-- so the first hyphen in the shown text starts the realm.
local function StripRealm(shown)
    return (shown:gsub("%-[^|%]%s]+", "", 1))
end

-- Strips the realm from the shown text of every player link in a chat line.
-- Returns the new line, or nil when nothing changed.
local function StripRealmsFromLinks(text)
    if not text:find("|Hplayer:", 1, true) then return nil end
    local changed = false
    local out = text:gsub("(|Hplayer:[^|]*|h)(.-)(|h)", function(open, shown, close)
        local short = StripRealm(shown)
        if short == shown then return nil end
        changed = true
        return open .. short .. close
    end)
    return changed and out or nil
end
ns.StripRealmsFromLinks = StripRealmsFromLinks

-- AddMessage pushes the new line to the front of the history buffer (entry 1, see
-- ScrollingMessageFrameMixin:GetMessageInfo). The entry is only rewritten when it still
-- holds this exact line, so an unexpected buffer layout leaves chat untouched.
local function OnAddMessage(frame, msg)
    if not GudaChatDB or not GudaChatDB.hideRealms then return end
    if type(msg) ~= "string" or ns.IsSecret(msg) then return end
    local short = StripRealmsFromLinks(msg)
    if not short then return end
    local buffer = frame.historyBuffer
    local entry = buffer and buffer.GetEntryAtIndex and buffer:GetEntryAtIndex(1)
    if not entry or entry.message ~= msg then return end
    entry.message = short
    if frame.MarkDisplayDirty then frame:MarkDisplayDirty() end
end

function ns.EnableRealmStrip()
    if not ns.CAN_HIDE_REALMS then return end
    ns.ForEachChatWindow(function(cf)
        if cf == ChatFrame2 or cf.isCombatLog then return end
        if cf.AddMessage and not cf.gudaRealmHooked then
            cf.gudaRealmHooked = true
            hooksecurefunc(cf, "AddMessage", OnAddMessage)
        end
    end)
end
