local addonName, ns = ...

---------------------------------------------------------------------------
-- Class colors
---------------------------------------------------------------------------

local CLASS_COLOR_GROUPS = {
    "SAY", "YELL", "GUILD", "OFFICER", "GUILD_ACHIEVEMENT",
    "ACHIEVEMENT", "WHISPER", "BN_WHISPER", "PARTY", "PARTY_LEADER",
    "RAID", "RAID_LEADER", "RAID_WARNING",
    "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
}

-- Custom channels CHANNEL1..CHANNEL20; only those the client defines in ChatTypeInfo are set
local MAX_CHANNEL_GROUPS = 20
for i = 1, MAX_CHANNEL_GROUPS do
    tinsert(CLASS_COLOR_GROUPS, "CHANNEL" .. i)
end

-- The name-by-class flag is global per chat type, not per window, so each group is set
-- once, and only when ChatTypeInfo says it differs (the call also saves chat settings).
local function SetClassColors(enabled)
    enabled = enabled and true or false
    for _, group in ipairs(CLASS_COLOR_GROUPS) do
        local info = ChatTypeInfo and ChatTypeInfo[group]
        if info and (info.colorNameByClass and true or false) ~= enabled then
            SetChatColorNameByClass(group, enabled)
        end
    end
end

function ns.ApplyClassColors()
    SetClassColors(GudaChatDB.classColors)
end

---------------------------------------------------------------------------
-- Player level in chat
---------------------------------------------------------------------------

-- CompactName -> level, or false for "looked up and not found". Misses are cached too, so a
-- busy channel full of strangers does not rescan every unit on every line; the whole cache
-- is wiped every LEVEL_CACHE_SECONDS and on guild roster changes so new targets and
-- level-ups show up.
local levelCache = {}
local LEVEL_CACHE_SECONDS = 60

local LEVEL_UNITS = { "target", "focus", "mouseover" }
for i = 1, 4 do tinsert(LEVEL_UNITS, "party" .. i) end
for i = 1, 40 do tinsert(LEVEL_UNITS, "raid" .. i) end
for i = 1, 40 do tinsert(LEVEL_UNITS, "nameplate" .. i) end

-- CompactName -> level for the guild roster, rebuilt on demand after GUILD_ROSTER_UPDATE
-- instead of scanning the whole roster for every chat line.
local guildLevels = {}
local guildLevelsDirty = true

-- A usable level, or nil for unknown (0, -1) and secret levels, which throw on compare
local function PlainLevel(level)
    if type(level) ~= "number" or ns.IsSecret(level) or level <= 0 then return nil end
    return level
end

local function RebuildGuildLevels()
    wipe(guildLevels)
    guildLevelsDirty = false
    if not (IsInGuild and IsInGuild()) then return end
    local numMembers = GetNumGuildMembers and GetNumGuildMembers() or 0
    for i = 1, numMembers do
        local gName, _, _, gLevel = GetGuildRosterInfo(i)
        local key = ns.CompactName(gName)
        local level = key and PlainLevel(gLevel)
        if level then
            guildLevels[key] = level
        end
    end
end

local function FindUnitLevel(key)
    for _, unit in ipairs(LEVEL_UNITS) do
        if UnitExists(unit) and ns.CompactName(ns.UnitFullName(unit)) == key then
            local level = PlainLevel(UnitLevel(unit))
            if level then return level end
        end
    end
    if guildLevelsDirty then RebuildGuildLevels() end
    return guildLevels[key]
end

local function GetPlayerLevel(name)
    local key = ns.CompactName(name)
    if not key then return nil end
    local cached = levelCache[key]
    if cached ~= nil then return cached or nil end
    local level = FindUnitLevel(key)
    levelCache[key] = level or false
    return level
end
ns.GetPlayerLevel = GetPlayerLevel

local guildWatcher = CreateFrame("Frame")
guildWatcher:RegisterEvent("GUILD_ROSTER_UPDATE")
guildWatcher:RegisterEvent("PLAYER_GUILD_UPDATE")
guildWatcher:SetScript("OnEvent", function()
    guildLevelsDirty = true
    wipe(levelCache)
end)

local function GetLevelDifficultyColor(level)
    if GetQuestDifficultyColor then
        local c = GetQuestDifficultyColor(level)
        if c then return c.r, c.g, c.b end
    end
    local playerLevel = UnitLevel("player") or 60
    local diff = level - playerLevel
    if diff >= 5 then
        return 1.0, 0.1, 0.1       -- red
    elseif diff >= 3 then
        return 1.0, 0.5, 0.25      -- orange
    elseif diff >= -2 then
        return 1.0, 1.0, 0.0       -- yellow
    elseif diff >= -(playerLevel / 5 + 2) then
        return 0.25, 0.75, 0.25    -- green
    else
        return 0.5, 0.5, 0.5       -- grey
    end
end
ns.GetLevelDifficultyColor = GetLevelDifficultyColor

local levelMemo = ns.NewLineMemo()

local function FilterAddLevel(self, event, msg, sender, ...)
    if not GudaChatDB or not GudaChatDB.showLevel then return false end
    if not msg or ns.IsSecret(msg) then return false end

    local lineID = ns.PlainLineID(select(9, ...))
    local hit, output = levelMemo:Get(lineID, msg)
    if not hit then
        output = false
        local level = GetPlayerLevel(sender)
        if level then
            local r, g, b = GetLevelDifficultyColor(level)
            output = string.format("|cff%02x%02x%02x[%d]|r ", r * 255, g * 255, b * 255, level) .. msg
        end
        levelMemo:Set(lineID, msg, output)
    end
    if output then
        return false, output, sender, ...
    end
    return false
end

local LEVEL_CHANNELS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_CHANNEL",
}

function ns.EnableLevelDisplay()
    for _, channel in ipairs(LEVEL_CHANNELS) do
        ChatFrame_AddMessageEventFilter(channel, FilterAddLevel)
    end
end

C_Timer.NewTicker(LEVEL_CACHE_SECONDS, function() wipe(levelCache) end)

---------------------------------------------------------------------------
-- Copyable links
---------------------------------------------------------------------------

local copyFrame

local function ShowCopyPopup(text)
    if not copyFrame then
        copyFrame = ns.CreateCopyPopupFrame("GudaChatCopyPopup", 320, 50, false)
    end

    copyFrame.editBox:SetText(text)
    copyFrame:Show()
    copyFrame.editBox:HighlightText()
    copyFrame.editBox:SetFocus()
end

local URL_PATTERNS = {
    "(https?://[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]+)",
    "(www%.[%w%.%-]+%.%a%a+[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
    "(%a[%w%-]+%.com[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
    "(%a[%w%-]+%.net[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
    "(%a[%w%-]+%.org[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
    "(%a[%w%-]+%.io[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
    "(%a[%w%-]+%.gg[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
}

local function LinkifyURL(url)
    return "|cff33bbff|Hgudachat:url:" .. url .. "|h[" .. url .. "]|h|r"
end

-- Skips messages that already contain our link: re-processing would nest the hyperlink
-- inside itself. Only plain text is linkified, never inside existing hyperlinks or
-- [brackets] (same splitter as the emoji filter), so a URL-like substring inside an item
-- link is left alone. Returns the new message, or false when nothing changed.
local function LinkifyMessage(msg)
    if msg:find("|Hgudachat:url:", 1, true) then return false end
    local parts = (ns.SplitProtected and ns.SplitProtected(msg)) or { { text = msg, free = true } }
    local changed = false
    for _, part in ipairs(parts) do
        if part.free then
            for _, pattern in ipairs(URL_PATTERNS) do
                local newText, n = part.text:gsub(pattern, LinkifyURL)
                if n > 0 then
                    part.text = newText
                    changed = true
                    break
                end
            end
        end
    end
    return changed and ns.JoinParts(parts) or false
end
ns.LinkifyMessage = LinkifyMessage

local urlMemo = ns.NewLineMemo()

local function FilterAddURLLinks(self, event, msg, ...)
    if not GudaChatDB or not GudaChatDB.copyLinks then return false end
    if not msg or ns.IsSecret(msg) or msg == "" then return false end

    local lineID = ns.PlainLineID(select(10, ...))
    local hit, output = urlMemo:Get(lineID, msg)
    if not hit then
        output = LinkifyMessage(msg)
        urlMemo:Set(lineID, msg, output)
    end
    if output then
        return false, output, ...
    end
    return false
end

-- Clicks on our gudachat:url: links open the copy popup.
--
-- Mainline chat (Retail, Forever): an additive HookScript, so no addon closure ever sits in
-- the secure item-link -> SetItemRef -> SetHyperlink path (tainting it crashes on 12.0
-- secret colour values). Mainline SetItemRef ignores unknown link types; a post-hook only
-- hides a stray ItemRefTooltip.
--
-- Classic (Era, Anniversary, MoP): SetItemRef ends with ItemRefTooltip:SetHyperlink(link)
-- for unknown link types and throws "Unknown link type", and a HookScript runs only after
-- that. So there the click handler is still wrapped, which taints the chat frames' link
-- clicks; our links stop in the wrapper and every other link goes to Blizzard's handler.
-- Kept to Classic until a hook-only path is confirmed in game there.
local function HookLinkClicks(cf)
    if cf.gudaLinkHooked then return end
    cf.gudaLinkHooked = true
    if ns.HAS_MAINLINE_CHAT then
        cf:HookScript("OnHyperlinkClick", function(self, link)
            local url = link and link:match("^gudachat:url:(.+)$")
            if url then
                ShowCopyPopup(url)
            end
        end)
        return
    end
    local orig = cf:GetScript("OnHyperlinkClick")
    cf:SetScript("OnHyperlinkClick", function(self, link, text, button, ...)
        local url = link and link:match("^gudachat:url:(.+)$")
        if url then
            ShowCopyPopup(url)
            return
        end
        if orig then return orig(self, link, text, button, ...) end
    end)
end
ns.HookLinkClicks = HookLinkClicks

function ns.SetupLinkHook()
    ns.ForEachChatFrame(HookLinkClicks)
    if ns.HAS_MAINLINE_CHAT then
        hooksecurefunc("SetItemRef", function(link)
            if link and link:match("^gudachat:url:") and ItemRefTooltip then
                ItemRefTooltip:Hide()
            end
        end)
    end
end

function ns.EnableCopyLinks()
    for _, channel in ipairs(ns.CHAT_MSG_CHANNELS) do
        ChatFrame_AddMessageEventFilter(channel, FilterAddURLLinks)
    end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", FilterAddURLLinks)
end

---------------------------------------------------------------------------
-- Highlight own name + sound on mention
---------------------------------------------------------------------------

local NAME_HIGHLIGHT_CHANNELS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_CHANNEL",
}

local namePattern, plainName, classHex
local lastMentionSound = 0
local MENTION_SOUND_THROTTLE = 0.3

local function BuildNameHighlight()
    local name = UnitName("player")
    if not name then return end
    namePattern, plainName = nil, nil
    if ns.IsNonAscii(name) then
        -- Lua character classes are byte-based and ASCII-only: the first byte of a
        -- Cyrillic/Hangul/Han name is not %w, so a %f[%w] frontier could never
        -- match and highlighting was silently dead on those clients. Use a plain
        -- substring search instead — also correct case-wise, as those scripts have
        -- no case, and %a below would have expanded nothing anyway.
        plainName = name
    else
        -- Match the name as a whole word, case-insensitively: "Vati" -> "[Vv][Aa][Tt][Ii]".
        local body = name:gsub("%a", function(c) return "[" .. c:upper() .. c:lower() .. "]" end)
        namePattern = "%f[%w]" .. body .. "%f[%W]"
    end
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS[class]
    classHex = c and string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) or "|cffffd200"
end

-- Wrap every occurrence of the player's name in the class colour.
-- Returns the new text and the number of replacements.
local function HighlightIn(text)
    if namePattern then
        return text:gsub(namePattern, function(m) return classHex .. m .. "|r" end)
    end
    if not plainName then return text, 0 end
    local out, pos, count = {}, 1, 0
    while true do
        local s, e = text:find(plainName, pos, true)
        if not s then break end
        out[#out + 1] = text:sub(pos, s - 1)
        out[#out + 1] = classHex
        out[#out + 1] = text:sub(s, e)
        out[#out + 1] = "|r"
        pos = e + 1
        count = count + 1
    end
    if count == 0 then return text, 0 end
    out[#out + 1] = text:sub(pos)
    return table.concat(out), count
end

-- Public channels (General / Trade / LocalDefense / LookingForGroup) are skipped
-- to avoid spam. Keyed on the numeric zone channel id, which is locale-independent:
-- channelBaseName is translated ("交易", "Торговля", "Handel"), so the English
-- name test below never matched on a non-English client and the guard was dead.
local PUBLIC_ZONE_CHANNELS = { [1] = true, [2] = true, [22] = true, [26] = true }

local function IsPublicChannel(zoneID, channelName)
    if zoneID and PUBLIC_ZONE_CHANNELS[zoneID] then return true end
    -- Custom and community channels report no zone id; keep the English names as
    -- a secondary test so enUS behaviour is unchanged.
    if not channelName then return false end
    return channelName:find("Trade") ~= nil
        or channelName:find("General") ~= nil
        or channelName:find("LookingForGroup") ~= nil
end

-- Colors the player's name in plain text only, never inside existing hyperlinks or
-- [brackets]. Returns the new message, or false when the name does not appear.
local function HighlightMessage(msg)
    local parts = (ns.SplitProtected and ns.SplitProtected(msg)) or { { text = msg, free = true } }
    local changed = false
    for _, part in ipairs(parts) do
        if part.free then
            local newText, n = HighlightIn(part.text)
            if n > 0 then
                part.text = newText
                changed = true
            end
        end
    end
    return changed and ns.JoinParts(parts) or false
end

local highlightMemo = ns.NewLineMemo()

-- The mention sound plays once per message: memo hits (the same line shown in another chat
-- frame) return before it, and our own messages and bursts within MENTION_SOUND_THROTTLE
-- stay silent.
local function FilterHighlightName(self, event, msg, sender, ...)
    if not GudaChatDB or not GudaChatDB.highlightName then return false end
    if not namePattern and not plainName then BuildNameHighlight() end
    if (not namePattern and not plainName) or not msg or ns.IsSecret(msg) then return false end
    -- select(5, ...) is arg7 zoneChannelID, select(7, ...) is arg9 channelBaseName
    if event == "CHAT_MSG_CHANNEL" and IsPublicChannel(select(5, ...), select(7, ...)) then
        return false
    end

    local lineID = ns.PlainLineID(select(9, ...))
    local hit, output = highlightMemo:Get(lineID, msg)
    if hit then
        if output then return false, output, sender, ... end
        return false
    end

    output = HighlightMessage(msg)
    highlightMemo:Set(lineID, msg, output)
    if not output then return false end

    local isSelf = ns.SameCharacter(sender, ns.UnitFullName("player"))
    if not isSelf and GudaChatDB.highlightSound and SOUNDKIT and SOUNDKIT.TELL_MESSAGE then
        local now = GetTime()
        if now - lastMentionSound > MENTION_SOUND_THROTTLE then
            lastMentionSound = now
            PlaySound(SOUNDKIT.TELL_MESSAGE)
        end
    end
    return false, output, sender, ...
end

function ns.EnableNameHighlight()
    BuildNameHighlight()
    for _, channel in ipairs(NAME_HIGHLIGHT_CHANNELS) do
        ChatFrame_AddMessageEventFilter(channel, FilterHighlightName)
    end
end
