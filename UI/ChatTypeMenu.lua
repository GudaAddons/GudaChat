local addonName, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Chat type menu (header chat icon): pick a channel to type in, or an emote
---------------------------------------------------------------------------

local MENU_MIN_WIDTH = 60
local C = ns.Theme.C

-- "/bye" rather than "/goodbye": both are the same emote, but the token is BYE, so this
-- is also correct via the upper-case fallback on a client whose localized command table
-- has no English "/goodbye" alias.
local EMOTES = {
    { label = L["EMOTE_WAVE"],     cmd = "/wave" },
    { label = L["EMOTE_DANCE"],    cmd = "/dance" },
    { label = L["EMOTE_BOW"],      cmd = "/bow" },
    { label = L["EMOTE_CHEER"],    cmd = "/cheer" },
    { label = L["EMOTE_CLAP"],     cmd = "/clap" },
    { label = L["EMOTE_CRY"],      cmd = "/cry" },
    { label = L["EMOTE_FLEX"],     cmd = "/flex" },
    { label = L["EMOTE_GOODBYE"],  cmd = "/bye" },
    { label = L["EMOTE_HELLO"],    cmd = "/hello" },
    { label = L["EMOTE_KISS"],     cmd = "/kiss" },
    { label = L["EMOTE_LAUGH"],    cmd = "/laugh" },
    { label = L["EMOTE_NO"],       cmd = "/no" },
    { label = L["EMOTE_POINT"],    cmd = "/point" },
    { label = L["EMOTE_RUDE"],     cmd = "/rude" },
    { label = L["EMOTE_SALUTE"],   cmd = "/salute" },
    { label = L["EMOTE_SHY"],      cmd = "/shy" },
    { label = L["EMOTE_SIT"],      cmd = "/sit" },
    { label = L["EMOTE_SLEEP"],    cmd = "/sleep" },
    { label = L["EMOTE_SMILE"],    cmd = "/smile" },
    { label = L["EMOTE_THANK"],    cmd = "/thank" },
    { label = L["EMOTE_YES"],      cmd = "/yes" },
    { label = L["EMOTE_ANGRY"],    cmd = "/angry" },
    { label = L["EMOTE_BEG"],      cmd = "/beg" },
    { label = L["EMOTE_APPLAUD"],  cmd = "/applaud" },
}

-- Main chat type entries. Commands come from Blizzard's localized SLASH_* globals — a
-- hardcoded "/bg" is not registered on every locale and would be pasted as literal text,
-- sending the message to say instead.
-- `abbrev` is the ns.ABBREV_FIXED_KEYS key whose short label replaces the name while
-- header abbreviations are on. Joined numbered channels follow the fixed entries.
local function ChatTypeEntries()
    local entries = {
        { label = ns.Blizz(SAY, "Say"),                   cmd = ns.SlashCmd("SLASH_SAY", "/s") },
        { label = ns.Blizz(PARTY, "Party Chat"),          cmd = ns.SlashCmd("SLASH_PARTY", "/p"), abbrev = "Party" },
        { label = ns.Blizz(RAID, "Raid"),                 cmd = ns.SlashCmd("SLASH_RAID", "/raid"), abbrev = "Raid" },
        { label = ns.Blizz(BATTLEGROUND, "Battleground"), cmd = ns.SlashCmd("SLASH_BATTLEGROUND", "/bg"), abbrev = "Instance" },
        { label = ns.Blizz(GUILD, "Guild Chat"),          cmd = ns.SlashCmd("SLASH_GUILD", "/g"), abbrev = "Guild" },
        { label = ns.Blizz(YELL, "Yell"),                 cmd = ns.SlashCmd("SLASH_YELL", "/y") },
        { label = ns.Blizz(WHISPER, "Whisper"),           cmd = ns.SlashCmd("SLASH_WHISPER", "/w") },
        { label = ns.Blizz(EMOTE, "Emote"),               cmd = ns.SlashCmd("SLASH_EMOTE", "/e"), hasArrow = true },
        { label = ns.Blizz(REPLY, "Reply"),               cmd = ns.SlashCmd("SLASH_REPLY", "/r") },
    }
    local short = ns.AbbrevActive("header")
    for _, entry in ipairs(entries) do
        if short and entry.abbrev then
            entry.full = entry.label
            entry.label = ns.FixedAbbrev(entry.abbrev)
        end
    end
    for _, ch in ipairs(ns.JoinedChannels()) do
        local base = ns.BaseChannelName(ch.name)
        local entry = { label = ch.num .. ". " .. base, cmd = "/" .. ch.num }
        if short then
            entry.full = entry.label
            entry.label = ch.num .. ". " .. ns.ChannelAbbrev(base)
        end
        entries[#entries + 1] = entry
    end
    return entries
end

-- Resolve a slash command to the token DoEmote actually expects. Upper-casing the command
-- is wrong wherever the two differ — "/goodbye" is the BYE token, so DoEmote("GOODBYE")
-- silently did nothing. Blizzard's own EMOTE%d_CMD%d -> EMOTE%d_TOKEN tables are the
-- authority, and they are localized, so this also resolves correctly when the client's
-- emote commands are translated.
local emoteTokens
local function EmoteToken(cmd)
    if not emoteTokens then
        emoteTokens = {}
        for i = 1, 512 do
            local token = _G["EMOTE" .. i .. "_TOKEN"]
            if token then
                for j = 1, 8 do
                    local c = _G["EMOTE" .. i .. "_CMD" .. j]
                    if not c then break end
                    emoteTokens[c:lower()] = token
                end
            end
        end
    end
    return emoteTokens[cmd:lower()] or cmd:sub(2):upper()
end
ns.EmoteToken = EmoteToken

-- A menu row: label on the left, the slash command (or ">") on the right
local function AddCommandRow(menu, yOff, label, rightText)
    local mb = CreateFrame("Button", nil, menu)
    mb:SetHeight(ns.MENU_ITEM_HEIGHT)
    mb:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, yOff)
    mb:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, yOff)

    local labelText = mb:CreateFontString(nil, "OVERLAY", "GudaChatFontNormalSmall")
    labelText:SetPoint("LEFT", mb, "LEFT", 6, 0)
    labelText:SetText(label)
    ns.Paint(labelText, C.chatTypeLabel)

    local cmdText = mb:CreateFontString(nil, "OVERLAY", "GudaChatFontNormalSmall")
    cmdText:SetPoint("RIGHT", mb, "RIGHT", -6, 0)
    cmdText:SetText(rightText)
    ns.Paint(cmdText, C.chatTypeCmd)

    mb.labelText = labelText
    mb.cmdText = cmdText
    mb.width = labelText:GetStringWidth() + cmdText:GetStringWidth() + 32
    return mb
end

local function HighlightRow(mb, on)
    ns.Paint(mb.labelText, on and C.chatTypeLabelHover or C.chatTypeLabel)
    ns.Paint(mb.cmdText, on and C.chatTypeCmdHover or C.chatTypeCmd)
end

local function MenuFrame(name, parent)
    local f = CreateFrame("Frame", name, parent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    ns.ApplyDarkBackdrop(f)
    f:Hide()
    return f
end

local function BuildEmoteMenu(chatTypeDropdown)
    local emoteSubMenu = MenuFrame("GudaChatEmoteSubMenu", chatTypeDropdown)
    emoteSubMenu:SetFrameLevel(chatTypeDropdown:GetFrameLevel() + 1)

    local yOff, maxW = -4, MENU_MIN_WIDTH
    for _, entry in ipairs(EMOTES) do
        local mb = AddCommandRow(emoteSubMenu, yOff, entry.label, entry.cmd)
        mb:SetScript("OnEnter", function() HighlightRow(mb, true) end)
        mb:SetScript("OnLeave", function() HighlightRow(mb, false) end)
        local slash = entry.cmd
        mb:SetScript("OnClick", function()
            ns.PerformEmote(EmoteToken(slash))
            emoteSubMenu:Hide()
            chatTypeDropdown:Hide()
        end)
        maxW = math.max(maxW, mb.width)
        yOff = yOff - ns.MENU_ITEM_HEIGHT
    end
    emoteSubMenu:SetSize(maxW + 8, math.abs(yOff) + 4)
    return emoteSubMenu
end

-- Builds the chat type menu on chatTypeBtn. onOpen runs whenever the button is clicked
-- (the header uses it to close its tab dropdown). The rows are filled in on every open:
-- the joined channels and the abbreviation setting can change in between.
function ns.CreateChatTypeMenu(chatTypeBtn, onOpen)
    local chatTypeDropdown = MenuFrame("GudaChatTypeDropdown", chatTypeBtn)
    local emoteSubMenu = BuildEmoteMenu(chatTypeDropdown)
    local rows = {}

    local function Populate()
        local yOff, maxW = -4, MENU_MIN_WIDTH
        local entries = ChatTypeEntries()
        for i, entry in ipairs(entries) do
            local mb = rows[i]
            if not mb then
                mb = AddCommandRow(chatTypeDropdown, yOff, "", "")
                rows[i] = mb
            end
            mb:ClearAllPoints()
            mb:SetPoint("TOPLEFT", chatTypeDropdown, "TOPLEFT", 4, yOff)
            mb:SetPoint("TOPRIGHT", chatTypeDropdown, "TOPRIGHT", -4, yOff)
            mb.labelText:SetText(entry.label)
            mb.cmdText:SetText(entry.hasArrow and ">" or entry.cmd)
            mb.width = mb.labelText:GetStringWidth() + mb.cmdText:GetStringWidth() + 32
            HighlightRow(mb, false)
            mb:SetScript("OnEnter", function(self)
                HighlightRow(self, true)
                if entry.hasArrow then
                    emoteSubMenu:ClearAllPoints()
                    emoteSubMenu:SetPoint("BOTTOMRIGHT", chatTypeDropdown, "BOTTOMLEFT", -2, 0)
                    emoteSubMenu:Show()
                else
                    emoteSubMenu:Hide()
                end
                if entry.full then
                    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                    GameTooltip:SetText(entry.full, 1, 1, 1)
                    GameTooltip:Show()
                end
            end)
            mb:SetScript("OnLeave", function(self)
                HighlightRow(self, false)
                if entry.full then GameTooltip:Hide() end
            end)
            local slash = entry.cmd
            mb:SetScript("OnClick", function()
                ns.OpenChat(slash .. " ", ChatFrame1)
                chatTypeDropdown:Hide()
                emoteSubMenu:Hide()
            end)
            mb:Show()
            maxW = math.max(maxW, mb.width)
            yOff = yOff - ns.MENU_ITEM_HEIGHT
        end
        for i = #entries + 1, #rows do
            rows[i]:Hide()
        end
        chatTypeDropdown:SetSize(maxW + 8, math.abs(yOff) + 4)
    end

    local function CloseAll()
        chatTypeDropdown:Hide()
        emoteSubMenu:Hide()
    end

    chatTypeBtn:SetScript("OnClick", function(self)
        if chatTypeDropdown:IsShown() then
            CloseAll()
        else
            Populate()
            chatTypeDropdown:ClearAllPoints()
            chatTypeDropdown:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 4, 2)
            chatTypeDropdown:Show()
        end
        onOpen()
    end)

    ns.CreateClickCloser(chatTypeDropdown,
        function()
            return chatTypeDropdown:IsMouseOver()
                or chatTypeBtn:IsMouseOver()
                or (emoteSubMenu:IsShown() and emoteSubMenu:IsMouseOver())
        end,
        CloseAll)
end
