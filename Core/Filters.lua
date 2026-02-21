local addonName, ns = ...

---------------------------------------------------------------------------
-- Class colors
---------------------------------------------------------------------------

local CLASS_COLOR_GROUPS = {
    "SAY", "YELL", "GUILD", "OFFICER", "GUILD_ACHIEVEMENT",
    "ACHIEVEMENT", "WHISPER", "BN_WHISPER", "PARTY", "PARTY_LEADER",
    "RAID", "RAID_LEADER", "RAID_WARNING",
    "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
    "CHANNEL1", "CHANNEL2", "CHANNEL3", "CHANNEL4", "CHANNEL5",
    "CHANNEL6", "CHANNEL7", "CHANNEL8", "CHANNEL9", "CHANNEL10",
}

local function SetClassColors(enabled)
    ns.ForEachChatWindow(function()
        for _, group in ipairs(CLASS_COLOR_GROUPS) do
            SetChatColorNameByClass(group, enabled)
        end
    end)
end

function ns.ApplyClassColors()
    SetClassColors(GudaChatDB.classColors)
end

---------------------------------------------------------------------------
-- Player level in chat
---------------------------------------------------------------------------

local levelCache = {}

local function GetPlayerLevel(name)
    if not name then return nil end
    if levelCache[name] then return levelCache[name] end

    local unitIDs = { "target", "focus", "mouseover" }
    for i = 1, 4 do tinsert(unitIDs, "party" .. i) end
    for i = 1, 40 do tinsert(unitIDs, "raid" .. i) end
    for i = 1, 40 do tinsert(unitIDs, "nameplate" .. i) end

    for _, unit in ipairs(unitIDs) do
        if UnitExists(unit) then
            local unitName = UnitName(unit)
            if unitName == name then
                local level = UnitLevel(unit)
                if level and level > 0 then
                    levelCache[name] = level
                    return level
                end
            end
        end
    end

    if IsInGuild and IsInGuild() then
        local numMembers = GetNumGuildMembers and GetNumGuildMembers() or 0
        for i = 1, numMembers do
            local gName, _, _, gLevel = GetGuildRosterInfo(i)
            if gName then
                local shortName = gName:match("^([^%-]+)")
                if shortName == name and gLevel and gLevel > 0 then
                    levelCache[shortName] = gLevel
                    if shortName == name then return gLevel end
                end
            end
        end
    end

    return nil
end
ns.GetPlayerLevel = GetPlayerLevel

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

local function FilterAddLevel(self, event, msg, sender, ...)
    if not GudaChatDB or not GudaChatDB.showLevel then return false end

    local name = sender and sender:match("^([^%-]+)")
    local level = GetPlayerLevel(name)
    if level then
        local r, g, b = GetLevelDifficultyColor(level)
        local hex = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
        msg = hex .. "[" .. level .. "]|r " .. msg
        return false, msg, sender, ...
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

-- Clear cache periodically to stay fresh
C_Timer.NewTicker(60, function() wipe(levelCache) end)

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

local function FilterAddURLLinks(self, event, msg, ...)
    if not GudaChatDB or not GudaChatDB.copyLinks then return false end

    local changed = false
    for _, pattern in ipairs(URL_PATTERNS) do
        local newMsg = msg:gsub(pattern, function(url)
            changed = true
            return LinkifyURL(url)
        end)
        if changed then
            msg = newMsg
            break
        end
    end

    if changed then
        return false, msg, ...
    end
    return false
end

function ns.SetupLinkHook()
    local origSetHyperlink = ItemRefTooltip.SetHyperlink

    ns.ForEachChatWindow(function(cf)
        cf:HookScript("OnHyperlinkClick", function(self, link, text, button)
            local url = link:match("^gudachat:url:(.+)$")
            if url then
                ShowCopyPopup(url)
            end
        end)
    end)

    ItemRefTooltip.SetHyperlink = function(self, link, ...)
        if link and link:match("^gudachat:url:") then return end
        return origSetHyperlink(self, link, ...)
    end
end

function ns.EnableCopyLinks()
    for _, channel in ipairs(ns.CHAT_MSG_CHANNELS) do
        ChatFrame_AddMessageEventFilter(channel, FilterAddURLLinks)
    end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", FilterAddURLLinks)
end
