local addonName, ns = ...

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function KillFrame(frame)
    if not frame then return end
    frame:Hide()
    frame:SetAlpha(0)
    frame:SetSize(0.001, 0.001)
    frame.Show = frame.Hide
end

---------------------------------------------------------------------------
-- Edit box positioning
---------------------------------------------------------------------------

local INPUT_BAR_MARGIN = 6

local function PositionEditBox(chatFrame, index, position)
    local eb = _G["ChatFrame" .. index .. "EditBox"]
    if not eb then return end
    eb:ClearAllPoints()
    if position == "top" then
        eb:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", -4, 4)
        eb:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 4, 4)
    else
        eb:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", -4, -4)
        eb:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 4, -4)
    end
end

-- Add margin to chat messages on the side where the input bar sits,
-- and reserve screen-edge space so the input bar doesn't go off-screen.
local INPUT_BAR_CLAMP = 34 -- 28px bar + 4px gap + 4px breathing room

local function ApplyChatMargins()
    local pos = GudaChatDB and GudaChatDB.inputPosition or "bottom"
    local topPad = (pos == "top") and INPUT_BAR_MARGIN or 0
    local botPad = (pos == "bottom") and INPUT_BAR_MARGIN or 0
    local topClamp = (pos == "top") and 32 or 4
    local botClamp = (pos == "bottom") and INPUT_BAR_CLAMP or 4

    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then
            if cf.SetTextInsets then
                cf:SetTextInsets(0, 0, topPad, botPad)
            end
            cf:SetClampRectInsets(-4, 4, topClamp, -botClamp)
            cf:SetClampedToScreen(true)
        end
    end
end

---------------------------------------------------------------------------
-- Emoji Picker
---------------------------------------------------------------------------

local EMOJI_PICKER_ITEMS = {
    { plain = ":)",    file = "emoji_smile.png" },
    { plain = ":(",    file = "emoji_sad.png" },
    { plain = ":D",    file = "emoji_grin.png" },
    { plain = ":P",    file = "emoji_tongue.png" },
    { plain = ";)",    file = "emoji_wink.png" },
    { plain = ":O",    file = "emoji_surprised.png" },
    { plain = "xD",    file = "emoji_laugh.png" },
    { plain = ":'(",   file = "emoji_cry.png" },
    { plain = ">:(",   file = "emoji_angry.png" },
    { plain = "B)",    file = "emoji_cool.png" },
    { plain = "<3",    file = "emoji_heart.png" },
    { plain = ":+1:",  file = "emoji_thumbsup.png" },
    { plain = ":-1:",  file = "emoji_thumbsdown.png" },
    { plain = ":fire:",    file = "emoji_fire.png" },
    { plain = ":skull:",   file = "emoji_skull.png" },
    { plain = ":poop:",    file = "emoji_poop.png" },
    { plain = ":clown:",   file = "emoji_clown.png" },
    { plain = ":nerd:",    file = "emoji_nerd.png" },
    { plain = ":eyeroll:", file = "emoji_eyeroll.png" },
    { plain = ":thinking:",file = "emoji_thinking.png" },
    { plain = "zzz",       file = "emoji_zzz.png" },
    { plain = ":star:",    file = "emoji_star.png" },
    { plain = ":moon:",    file = "emoji_moon.png" },
    { plain = ":check:",   file = "emoji_check.png" },
    { plain = ":x:",       file = "emoji_x.png" },
    { plain = ":diamond:", file = "emoji_diamond.png" },
    { plain = ":circle:",  file = "emoji_circle.png" },
    { plain = ":triangle:",file = "emoji_triangle.png" },
    { plain = ":square:",  file = "emoji_square.png" },
    { plain = ":cross:",   file = "emoji_cross.png" },
}

local emojiPickerFrame
local function CreateEmojiPicker()
    local COLS = 8
    local BTN_SIZE = 24
    local PADDING = 4
    local MARGIN = 8

    local rows = math.ceil(#EMOJI_PICKER_ITEMS / COLS)
    local width = MARGIN * 2 + COLS * BTN_SIZE + (COLS - 1) * PADDING
    local height = MARGIN * 2 + rows * BTN_SIZE + (rows - 1) * PADDING

    local f = CreateFrame("Frame", "GudaChatEmojiPicker", UIParent, "BackdropTemplate")
    f:SetSize(width, height)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:SetClampedToScreen(true)

    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)

    for i, entry in ipairs(EMOJI_PICKER_ITEMS) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)

        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(BTN_SIZE, BTN_SIZE)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", MARGIN + col * (BTN_SIZE + PADDING), -(MARGIN + row * (BTN_SIZE + PADDING)))

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("CENTER")
        tex:SetSize(BTN_SIZE - 4, BTN_SIZE - 4)
        tex:SetTexture("Interface\\AddOns\\GudaChat\\Assets\\" .. entry.file)

        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
        highlight:SetVertexColor(1, 1, 1, 0.15)

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(entry.plain, 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        btn:SetScript("OnClick", function()
            if f.editBox then
                f.editBox:Insert(entry.plain .. " ")
                f.editBox:SetFocus()
            end
            f:Hide()
        end)
    end

    f:Hide()
    tinsert(UISpecialFrames, "GudaChatEmojiPicker")
    emojiPickerFrame = f
    return f
end

function ToggleEmojiPicker(editBox)
    local picker = emojiPickerFrame or CreateEmojiPicker()
    if picker:IsShown() then
        picker:Hide()
        return
    end

    picker.editBox = editBox
    picker:ClearAllPoints()
    local pos = GudaChatDB and GudaChatDB.inputPosition or "bottom"
    if pos == "top" then
        picker:SetPoint("TOPRIGHT", editBox, "BOTTOMRIGHT", 0, -2)
    else
        picker:SetPoint("BOTTOMRIGHT", editBox, "TOPRIGHT", 0, 2)
    end
    picker:Show()
end

local function StyleEditBox(chatFrame, index)
    local eb = _G["ChatFrame" .. index .. "EditBox"]
    if not eb then return end

    -- Strip Blizzard edit box textures (preserve cursor)
    for _, region in pairs({eb:GetRegions()}) do
        if region:GetObjectType() == "Texture" then
            local layer = region:GetDrawLayer()
            if layer ~= "OVERLAY" then
                region:SetTexture(nil)
                region:Hide()
            end
        end
    end
    local focusLeft = _G["ChatFrame" .. index .. "EditBoxFocusLeft"]
    local focusMid = _G["ChatFrame" .. index .. "EditBoxFocusMid"]
    local focusRight = _G["ChatFrame" .. index .. "EditBoxFocusRight"]
    if focusLeft then focusLeft:SetTexture(nil) end
    if focusMid then focusMid:SetTexture(nil) end
    if focusRight then focusRight:SetTexture(nil) end

    eb:SetHeight(28)

    -- Position based on saved setting
    local pos = GudaChatDB and GudaChatDB.inputPosition or "bottom"
    PositionEditBox(chatFrame, index, pos)

    -- Backdrop
    if not eb.gudaBg then
        local bg = CreateFrame("Frame", nil, eb, "BackdropTemplate")
        bg:SetAllPoints(eb)
        bg:SetFrameLevel(eb:GetFrameLevel() - 1)
        bg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        bg:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
        bg:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
        eb.gudaBg = bg
    end

    local header = _G["ChatFrame" .. index .. "EditBoxHeader"]
    if header then
        header:SetTextColor(0.6, 0.6, 0.6)
        header:ClearAllPoints()
        header:SetPoint("LEFT", eb, "LEFT", 4, 0)
    end

    -- Override Blizzard's SetTextInsets to always use tight left inset
    local origSetTextInsets = eb.SetTextInsets
    eb.SetTextInsets = function(self, left, right, top, bottom)
        local hdr = _G["ChatFrame" .. index .. "EditBoxHeader"]
        if hdr and hdr:IsShown() then
            left = hdr:GetStringWidth() + 8
        else
            left = 4
        end
        origSetTextInsets(self, left, 28, top or 0, bottom or 0)
    end
    eb:SetTextInsets(0, 28, 0, 0)

    -- Emoji picker button
    local emojiBtn = CreateFrame("Button", nil, eb)
    emojiBtn:SetSize(18, 18)
    emojiBtn:SetPoint("RIGHT", eb, "RIGHT", -5, 0)

    local emojiIcon = emojiBtn:CreateTexture(nil, "ARTWORK")
    emojiIcon:SetAllPoints()
    emojiIcon:SetTexture("Interface\\AddOns\\GudaChat\\Assets\\emoji_smile.png")
    emojiIcon:SetAlpha(0.5)

    emojiBtn:SetScript("OnEnter", function() emojiIcon:SetAlpha(1) end)
    emojiBtn:SetScript("OnLeave", function() emojiIcon:SetAlpha(0.5) end)
    emojiBtn:SetScript("OnClick", function()
        ToggleEmojiPicker(eb)
    end)

    -- Show/hide based on emoji setting
    if GudaChatDB and GudaChatDB.emojis then
        emojiBtn:Show()
    else
        emojiBtn:Hide()
    end
    eb.emojiBtn = emojiBtn

    eb:SetAlpha(1)
    eb.chatFrame = chatFrame

    eb:HookScript("OnEditFocusGained", function(self)
        if self.gudaBg then
            self.gudaBg:SetBackdropBorderColor(0.8, 0.6, 0.0, 0.8)
        end
    end)
    eb:HookScript("OnEditFocusLost", function(self)
        if self.gudaBg then
            self.gudaBg:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
        end
    end)
end

---------------------------------------------------------------------------
-- Class colors
---------------------------------------------------------------------------

local function EnableClassColors()
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then
            for _, group in ipairs({
                "SAY", "YELL", "GUILD", "OFFICER", "GUILD_ACHIEVEMENT",
                "ACHIEVEMENT", "WHISPER", "BN_WHISPER", "PARTY", "PARTY_LEADER",
                "RAID", "RAID_LEADER", "RAID_WARNING",
                "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
                "CHANNEL1", "CHANNEL2", "CHANNEL3", "CHANNEL4", "CHANNEL5",
                "CHANNEL6", "CHANNEL7", "CHANNEL8", "CHANNEL9", "CHANNEL10",
            }) do
                SetChatColorNameByClass(group, true)
            end
        end
    end
end

local function DisableClassColors()
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then
            for _, group in ipairs({
                "SAY", "YELL", "GUILD", "OFFICER", "GUILD_ACHIEVEMENT",
                "ACHIEVEMENT", "WHISPER", "BN_WHISPER", "PARTY", "PARTY_LEADER",
                "RAID", "RAID_LEADER", "RAID_WARNING",
                "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
                "CHANNEL1", "CHANNEL2", "CHANNEL3", "CHANNEL4", "CHANNEL5",
                "CHANNEL6", "CHANNEL7", "CHANNEL8", "CHANNEL9", "CHANNEL10",
            }) do
                SetChatColorNameByClass(group, false)
            end
        end
    end
end

local function ApplyClassColors()
    if GudaChatDB.classColors then
        EnableClassColors()
    else
        DisableClassColors()
    end
end

---------------------------------------------------------------------------
-- Player level in chat
---------------------------------------------------------------------------

local levelCache = {}

local function GetPlayerLevel(name)
    if not name then return nil end
    -- Check cache first
    if levelCache[name] then return levelCache[name] end

    -- Try unit IDs
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

    -- Try guild roster
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

local function GetLevelDifficultyColor(level)
    if GetQuestDifficultyColor then
        local c = GetQuestDifficultyColor(level)
        if c then return c.r, c.g, c.b end
    end
    -- Fallback: manual difficulty color based on player level difference
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

local function EnableLevelDisplay()
    for _, channel in ipairs(LEVEL_CHANNELS) do
        ChatFrame_AddMessageEventFilter(channel, FilterAddLevel)
    end
end

-- Clear cache periodically to stay fresh
C_Timer.NewTicker(60, function() wipe(levelCache) end)

---------------------------------------------------------------------------
-- Copyable links
---------------------------------------------------------------------------

-- Copy popup (reusable frame with an edit box to select+copy text)
local copyFrame

local function ShowCopyPopup(text)
    if not copyFrame then
        local f = CreateFrame("Frame", "GudaChatCopyPopup", UIParent, "BackdropTemplate")
        f:SetSize(320, 50)
        f:SetPoint("CENTER")
        f:SetFrameStrata("TOOLTIP")
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        f:SetBackdropBorderColor(0.8, 0.6, 0.0, 0.8)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            self:SetUserPlaced(false)
        end)

        tinsert(UISpecialFrames, "GudaChatCopyPopup")

        -- Label
        local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
        label:SetText("Ctrl+C to copy, Escape to close")
        label:SetTextColor(0.6, 0.6, 0.6)

        -- Edit box for selecting/copying
        local eb = CreateFrame("EditBox", nil, f, "BackdropTemplate")
        eb:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -20)
        eb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 6)
        eb:SetFontObject(ChatFontNormal)
        eb:SetAutoFocus(true)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        eb:SetScript("OnEditFocusLost", function() f:Hide() end)
        f.editBox = eb

        copyFrame = f
    end

    copyFrame.editBox:SetText(text)
    copyFrame:Show()
    copyFrame.editBox:HighlightText()
    copyFrame.editBox:SetFocus()
end

-- URL patterns to detect in chat
local URL_PATTERNS = {
    -- http(s)://...
    "(https?://[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]+)",
    -- www.domain.tld
    "(www%.[%w%.%-]+%.%a%a+[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
    -- bare domain.tld/path (common TLDs)
    "(%a[%w%-]+%.com[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
    "(%a[%w%-]+%.net[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
    "(%a[%w%-]+%.org[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
    "(%a[%w%-]+%.io[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
    "(%a[%w%-]+%.gg[%w%.%-_~:/?#%[%]@!$&'%(%)%*%+,;=%%]*)",
}

local function LinkifyURL(url)
    -- Wrap URL in a clickable garrmission link (custom type for our hook)
    return "|cff33bbff|Hgudachat:url:" .. url .. "|h[" .. url .. "]|h|r"
end

local function FilterAddURLLinks(self, event, msg, ...)
    if not GudaChatDB or not GudaChatDB.copyLinks then return false end

    local changed = false
    for _, pattern in ipairs(URL_PATTERNS) do
        local newMsg = msg:gsub(pattern, function(url)
            -- Don't linkify if already inside a hyperlink
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

-- Hook hyperlink clicks to handle our custom gudachat:url: links
local function SetupLinkHook()
    local origSetHyperlink = ItemRefTooltip.SetHyperlink

    -- Hook OnHyperlinkClick on each chat frame
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then
            cf:HookScript("OnHyperlinkClick", function(self, link, text, button)
                local url = link:match("^gudachat:url:(.+)$")
                if url then
                    ShowCopyPopup(url)
                end
            end)
        end
    end

    -- Prevent the default tooltip from erroring on our custom link type
    ItemRefTooltip.SetHyperlink = function(self, link, ...)
        if link and link:match("^gudachat:url:") then return end
        return origSetHyperlink(self, link, ...)
    end
end

local function EnableCopyLinks()
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_WARNING", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT_LEADER", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", FilterAddURLLinks)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", FilterAddURLLinks)
end

---------------------------------------------------------------------------
-- Emoji text replacement
---------------------------------------------------------------------------

local EMOJI_PATH = "Interface\\AddOns\\GudaChat\\Assets\\"
local DEFAULT_EMOJI_SIZE = 12
local EMOJI_REPLACEMENTS = {
    { plain = ":)",   pattern = ":%)",    file = "emoji_smile.png" },
    { plain = ":(",   pattern = ":%(",    file = "emoji_sad.png" },
    { plain = ":D",   pattern = ":D",     file = "emoji_grin.png" },
    { plain = ":P",   pattern = ":P",     file = "emoji_tongue.png" },
    { plain = ";)",   pattern = ";%)",    file = "emoji_wink.png" },
    { plain = ":O",   pattern = ":O",     file = "emoji_surprised.png" },
    { plain = "<3",   pattern = "<3",     file = "emoji_heart.png" },
    { plain = ":star:",    pattern = ":star:",    file = "emoji_star.png" },
    { plain = ":skull:",   pattern = ":skull:",   file = "emoji_skull.png" },
    { plain = ":check:",   pattern = ":check:",   file = "emoji_check.png" },
    { plain = ":x:",       pattern = ":x:",       file = "emoji_x.png" },
    { plain = ":moon:",    pattern = ":moon:",    file = "emoji_moon.png" },
    { plain = ":diamond:", pattern = ":diamond:", file = "emoji_diamond.png" },
    { plain = ":circle:",  pattern = ":circle:",  file = "emoji_circle.png" },
    { plain = ":triangle:",pattern = ":triangle:",file = "emoji_triangle.png" },
    { plain = ":square:",  pattern = ":square:",  file = "emoji_square.png" },
    { plain = ":cross:",   pattern = ":cross:",   file = "emoji_cross.png" },
    { plain = "xD",   pattern = "xD",    file = "emoji_laugh.png" },
    { plain = "XD",   pattern = "XD",    file = "emoji_laugh.png" },
    { plain = ":'(",  pattern = ":'%(",  file = "emoji_cry.png" },
    { plain = "zzz",  pattern = "zzz",   file = "emoji_zzz.png" },
    { plain = ":+1:",  pattern = ":%+1:",  file = "emoji_thumbsup.png" },
    { plain = ":-1:",  pattern = ":%-1:",  file = "emoji_thumbsdown.png" },
    { plain = ">:(",  pattern = ">:%(",   file = "emoji_angry.png" },
    { plain = "B)",   pattern = "B%)",    file = "emoji_cool.png" },
    { plain = ":fire:",  pattern = ":fire:",  file = "emoji_fire.png" },
    { plain = ":poop:",  pattern = ":poop:",  file = "emoji_poop.png" },
    { plain = ":clown:", pattern = ":clown:", file = "emoji_clown.png" },
    { plain = ":nerd:",  pattern = ":nerd:",  file = "emoji_nerd.png" },
    { plain = ":eyeroll:", pattern = ":eyeroll:", file = "emoji_eyeroll.png" },
    { plain = ":thinking:", pattern = ":thinking:", file = "emoji_thinking.png" },
}

local function FilterAddEmojis(self, event, msg, ...)
    if not GudaChatDB or not GudaChatDB.emojis then return false end

    local size = GudaChatDB.emojiSize or DEFAULT_EMOJI_SIZE
    local changed = false
    for _, entry in ipairs(EMOJI_REPLACEMENTS) do
        if msg:find(entry.plain, 1, true) then
            local tex = "|T" .. EMOJI_PATH .. entry.file .. ":" .. size .. "|t"
            msg = msg:gsub(entry.pattern, tex)
            changed = true
        end
    end

    if changed then
        return false, msg, ...
    end
    return false
end

local EMOJI_CHANNELS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_CHANNEL",
}

local function EnableEmojis()
    for _, channel in ipairs(EMOJI_CHANNELS) do
        ChatFrame_AddMessageEventFilter(channel, FilterAddEmojis)
    end
end

---------------------------------------------------------------------------
-- Lock / unlock chat frame movement
---------------------------------------------------------------------------

local function ApplyLockState()
    local locked = GudaChatDB.locked
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then
            cf:SetMovable(not locked)
            cf:SetClampedToScreen(true)
            if locked then
                cf:SetScript("OnDragStart", nil)
            end
        end
    end
    -- Also prevent Blizzard's FloatingChatFrame drag functions
    if locked then
        if not ns._origStartMoving then
            ns._origStartMoving = FCF_StartDragging
        end
        FCF_StartDragging = function() end
    else
        if ns._origStartMoving then
            FCF_StartDragging = ns._origStartMoving
        end
    end
end

---------------------------------------------------------------------------
-- Chrome stripping
---------------------------------------------------------------------------

local function StripChatChrome(index)
    local cf = _G["ChatFrame" .. index]
    if not cf then return end

    KillFrame(_G["ChatFrame" .. index .. "ButtonFrameUpButton"])
    KillFrame(_G["ChatFrame" .. index .. "ButtonFrameDownButton"])
    KillFrame(_G["ChatFrame" .. index .. "ButtonFrameBottomButton"])
    KillFrame(_G["ChatFrame" .. index .. "ScrollToBottomButton"])
    KillFrame(_G["ChatFrame" .. index .. "ButtonFrameMinimizeButton"])
    KillFrame(_G["ChatFrame" .. index .. "ButtonFrame"])
    local tab = _G["ChatFrame" .. index .. "Tab"]
    if tab then
        tab:SetAlpha(0)
        tab:SetSize(0.001, 0.001)
        tab:EnableMouse(false)
    end

    -- Remove Blizzard's built-in spacing (ApplyChatMargins sets proper clamp insets later)
    cf:SetClampRectInsets(0, 0, 0, 0)
    cf:SetClampedToScreen(true)

    -- Remove text insets (method name varies by client version)
    if cf.SetTextInsets then
        cf:SetTextInsets(0, 0, 0, 0)
    elseif cf.SetInsertMode then
        -- fallback
    end

    -- Blizzard's FCF_UpdateButtonSide sets indented text area — override it
    if cf.SetIndentedWordWrap then
        cf:SetIndentedWordWrap(false)
    end

    -- Keep background frame functional but transparent by default (color picker controls it)
    local bg = _G["ChatFrame" .. index .. "Background"]
    if bg then
        bg:SetAlpha(0)
    end
    local resize = _G["ChatFrame" .. index .. "ResizeButton"]
    if resize then KillFrame(resize) end

    StyleEditBox(cf, index)
end

-- Prevent Blizzard from re-adding button side spacing; apply our margins instead
if FCF_UpdateButtonSide then
    hooksecurefunc("FCF_UpdateButtonSide", function(cf)
        if cf and cf.SetTextInsets then
            local pos = GudaChatDB and GudaChatDB.inputPosition or "bottom"
            local topPad = (pos == "top") and INPUT_BAR_MARGIN or 0
            local botPad = (pos == "bottom") and INPUT_BAR_MARGIN or 0
            cf:SetTextInsets(0, 0, topPad, botPad)
        end
    end)
end

local function RehideAllTabs()
    for i = 1, NUM_CHAT_WINDOWS do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab then
            tab:SetAlpha(0)
            tab:SetSize(0.001, 0.001)
            tab:EnableMouse(false)
        end
    end
end

---------------------------------------------------------------------------
-- Scrollbar
---------------------------------------------------------------------------

local function CreateScrollbar(chatFrame)
    local slider = CreateFrame("Slider", "GudaChatScrollbar", chatFrame, "BackdropTemplate")
    slider:SetWidth(6)
    slider:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -2, -2)
    slider:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", -2, 2)
    slider:SetOrientation("VERTICAL")
    slider:SetMinMaxValues(0, 1)
    slider:SetValue(0)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)

    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    slider:SetBackdropColor(0, 0, 0, 0.3)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
    thumb:SetVertexColor(1, 1, 1, 0.4)
    thumb:SetSize(6, 30)
    slider:SetThumbTexture(thumb)

    slider:SetScript("OnEnter", function()
        thumb:SetVertexColor(1, 1, 1, 0.7)
    end)
    slider:SetScript("OnLeave", function()
        thumb:SetVertexColor(1, 1, 1, 0.4)
    end)

    slider:SetScript("OnValueChanged", function(self, value)
        local maxScroll = chatFrame:GetMaxScrollRange()
        local offset = maxScroll - value
        if offset >= 0 then
            chatFrame:SetScrollOffset(offset)
        end
    end)

    local function SyncSlider()
        local maxScroll = chatFrame:GetMaxScrollRange()
        slider:SetMinMaxValues(0, maxScroll)
        local offset = chatFrame:GetScrollOffset()
        slider:SetValue(maxScroll - offset)
    end

    hooksecurefunc(chatFrame, "SetScrollOffset", SyncSlider)

    local ticker = CreateFrame("Frame")
    local elapsed = 0
    ticker:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.2 then
            elapsed = 0
            SyncSlider()
        end
    end)

    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            chatFrame:ScrollUp()
        else
            chatFrame:ScrollDown()
        end
        SyncSlider()
    end)

    slider:SetAlpha(0)

    local sbFadeIn, sbFadeOut
    function slider.FadeIn()
        if sbFadeOut then sbFadeOut:Stop() end
        sbFadeIn = slider:CreateAnimationGroup()
        local anim = sbFadeIn:CreateAnimation("Alpha")
        anim:SetFromAlpha(slider:GetAlpha())
        anim:SetToAlpha(1)
        anim:SetDuration(0.15)
        sbFadeIn:SetScript("OnFinished", function() slider:SetAlpha(1) end)
        sbFadeIn:Play()
    end

    function slider.FadeOut()
        if sbFadeIn then sbFadeIn:Stop() end
        sbFadeOut = slider:CreateAnimationGroup()
        local anim = sbFadeOut:CreateAnimation("Alpha")
        anim:SetFromAlpha(slider:GetAlpha())
        anim:SetToAlpha(0)
        anim:SetDuration(0.25)
        sbFadeOut:SetScript("OnFinished", function() slider:SetAlpha(0) end)
        sbFadeOut:Play()
    end

    ns.scrollbar = slider
    return slider
end

---------------------------------------------------------------------------
-- Chat header bar (hover-reveal, icon buttons)
---------------------------------------------------------------------------

local ASSET_PATH = "Interface\\AddOns\\GudaChat\\Assets\\"
local ICON_SIZE = 16
local HEADER_HEIGHT = 22
local chatHeader

local function GetChatTabName(index)
    local tab = _G["ChatFrame" .. index .. "Tab"]
    if tab then
        local name = tab.Text and tab.Text:GetText() or tab:GetText()
        if name and name ~= "" then return name end
    end
    return "Chat " .. index
end

-- Small icon button helper
local function CreateIconButton(parent, texturePath, size, tooltip)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(texturePath)
    icon:SetVertexColor(0.7, 0.7, 0.7, 0.9)
    btn.icon = icon

    btn:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1, 1)
        if tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip, 1, 1, 1)
            GameTooltip:Show()
        end
        -- Keep header visible while hovering buttons
        if chatHeader then chatHeader:SetAlpha(1) end
    end)
    btn:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(0.7, 0.7, 0.7, 0.9)
        GameTooltip:Hide()
    end)

    return btn
end

---------------------------------------------------------------------------
-- Rename window popup
---------------------------------------------------------------------------

StaticPopupDialogs["GUDACHAT_RENAME_WINDOW"] = {
    text = "Enter new name for this chat window:",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    OnShow = function(self)
        local id = ns._renamingIndex or 1
        self.EditBox:SetText(GetChatTabName(id))
        self.EditBox:HighlightText()
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self)
        local name = self.EditBox:GetText()
        local chatFrame = ns._renamingFrame
        local id = ns._renamingIndex
        if chatFrame and name and name ~= "" and id then
            FCF_SetWindowName(chatFrame, name, true)
            FCF_SelectDockFrame(chatFrame)
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local name = parent.EditBox:GetText()
        local chatFrame = ns._renamingFrame
        local id = ns._renamingIndex
        if chatFrame and name and name ~= "" and id then
            FCF_SetWindowName(chatFrame, name, true)
            FCF_SelectDockFrame(chatFrame)
        end
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

---------------------------------------------------------------------------
-- Custom chat context menu (replaces Blizzard's tab right-click menu)
---------------------------------------------------------------------------

local FONT_SIZES = { 12, 14, 16, 18, 20, 24, 27 }

local contextMenu, fontSubMenu

local function GetSelectedChatFrameIndex()
    -- Try FCF_GetCurrentChatFrame first (most reliable)
    local current = FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame()
    if current then
        for i = 1, NUM_CHAT_WINDOWS do
            if _G["ChatFrame" .. i] == current then return i end
        end
    end
    -- Fallback: check SELECTED_DOCK_FRAME, then SELECTED_CHAT_FRAME
    local selected = SELECTED_DOCK_FRAME or SELECTED_CHAT_FRAME
    if selected then
        for i = 1, NUM_CHAT_WINDOWS do
            if _G["ChatFrame" .. i] == selected then return i end
        end
    end
    return 1
end

local function CreateContextMenuItem(parent, label, onClick, isSeparator, hasArrow, isCheckbox)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(20)

    if isSeparator then
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", btn, "LEFT", 8, 0)
        text:SetText(label)
        text:SetTextColor(0.9, 0.75, 0.3)
        btn:EnableMouse(false)
        btn.label = text
        return btn
    end

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", btn, "LEFT", 8, 0)
    text:SetText(label)
    btn.label = text

    if isCheckbox then
        local check = btn:CreateTexture(nil, "ARTWORK")
        check:SetSize(12, 12)
        check:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        check:Hide()
        btn.check = check
    end

    if hasArrow then
        local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        arrow:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        arrow:SetText(">")
        arrow:SetTextColor(0.7, 0.7, 0.7)
    end

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
    highlight:SetVertexColor(1, 1, 1, 0.1)

    btn:SetScript("OnClick", function(self)
        if onClick then onClick(self) end
    end)

    return btn
end

local function CreateFontSubMenu()
    local f = CreateFrame("Frame", "GudaChatFontSubMenu", UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(210)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
    f:Hide()

    local yOff = -4
    for _, size in ipairs(FONT_SIZES) do
        local btn = CreateContextMenuItem(f, size .. " pt", nil, false, false, true)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, yOff)
        btn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, yOff)

        btn:SetScript("OnClick", function()
            local id = GetSelectedChatFrameIndex()
            local cf = _G["ChatFrame" .. id]
            if cf then
                local tab = _G["ChatFrame" .. id .. "Tab"]
                if FCF_SetChatWindowFontSize then
                    FCF_SetChatWindowFontSize(nil, cf, size)
                else
                    local fontObj, _, flags = cf:GetFont()
                    cf:SetFont(fontObj, size, flags)
                end
            end
            if contextMenu then contextMenu:Hide() end
            f:Hide()
        end)

        btn:SetScript("OnEnter", function(self)
            -- Mark current size
            local id = GetSelectedChatFrameIndex()
            local cf = _G["ChatFrame" .. id]
            if cf then
                local _, curSize = cf:GetFont()
                curSize = math.floor(curSize + 0.5)
                for _, child in ipairs({f:GetChildren()}) do
                    if child.check then
                        child.check:Hide()
                    end
                end
                if math.floor(size + 0.5) == curSize and self.check then
                    self.check:Show()
                end
            end
        end)

        yOff = yOff - 20
    end

    f:SetSize(80, math.abs(yOff) + 4)
    fontSubMenu = f
    return f
end

local function ShowContextMenu(anchor)
    if not contextMenu then
        local f = CreateFrame("Frame", "GudaChatContextMenu", UIParent, "BackdropTemplate")
        f:SetFrameStrata("TOOLTIP")
        f:SetFrameLevel(205)
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        f:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
        f:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
        f:Hide()
        tinsert(UISpecialFrames, "GudaChatContextMenu")
        f:SetScript("OnHide", function()
            if fontSubMenu then fontSubMenu:Hide() end
        end)
        contextMenu = f
    end

    -- Clear old children
    for _, child in ipairs({contextMenu:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local id = GetSelectedChatFrameIndex()
    local cf = _G["ChatFrame" .. id]
    local yOff = -4
    local maxW = 140

    -- Rename Window
    local renameBtn = CreateContextMenuItem(contextMenu, "Rename Window", function()
        local chatFrame = _G["ChatFrame" .. id]
        if chatFrame then
            -- Store which frame to rename, then show Blizzard's rename popup
            ns._renamingFrame = chatFrame
            ns._renamingIndex = id
            StaticPopup_Show("GUDACHAT_RENAME_WINDOW")
        end
        contextMenu:Hide()
    end)
    renameBtn:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
    renameBtn:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
    yOff = yOff - 20

    -- Create New Window (show name popup like Blizzard does)
    local newWinBtn = CreateContextMenuItem(contextMenu, "Create New Window", function()
        if FCF_NewChatWindow then
            FCF_NewChatWindow()
        elseif FCF_OpenNewWindow then
            FCF_OpenNewWindow()
        end
        contextMenu:Hide()
    end)
    newWinBtn:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
    newWinBtn:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
    yOff = yOff - 20

    -- Remove Window (not for General / ChatFrame1)
    if id ~= 1 then
        local removeBtn = CreateContextMenuItem(contextMenu, "Remove Window", function()
            local chatFrame = _G["ChatFrame" .. id]
            if chatFrame and FCF_Close then
                FCF_Close(chatFrame)
                FCF_SelectDockFrame(ChatFrame1)
            end
            contextMenu:Hide()
        end)
        removeBtn:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
        removeBtn:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
        yOff = yOff - 20
    end

    -- Display separator
    local displaySep = CreateContextMenuItem(contextMenu, "Display", nil, true)
    displaySep:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
    displaySep:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
    yOff = yOff - 20

    -- Font Size (with submenu arrow)
    local fontBtn = CreateContextMenuItem(contextMenu, "Font Size", nil, false, true)
    fontBtn:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
    fontBtn:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
    yOff = yOff - 20

    local fsm = fontSubMenu or CreateFontSubMenu()

    fontBtn:SetScript("OnEnter", function(self)
        -- Show current font size checkmark
        local curCf = _G["ChatFrame" .. GetSelectedChatFrameIndex()]
        if curCf then
            local _, curSize = curCf:GetFont()
            curSize = math.floor(curSize + 0.5)
            for _, child in ipairs({fsm:GetChildren()}) do
                if child.check then
                    local sizeStr = child.label and child.label:GetText()
                    local sz = sizeStr and tonumber(sizeStr:match("(%d+)"))
                    if sz == curSize then
                        child.check:Show()
                    else
                        child.check:Hide()
                    end
                end
            end
        end
        fsm:ClearAllPoints()
        fsm:SetPoint("TOPLEFT", self, "TOPRIGHT", 2, 4)
        fsm:Show()
    end)
    fontBtn:SetScript("OnLeave", function(self)
        C_Timer.After(0.2, function()
            if fsm and not fsm:IsMouseOver() and not self:IsMouseOver() then
                fsm:Hide()
            end
        end)
    end)

    -- Background (color swatch — opens Blizzard color picker)
    local bgBtn = CreateContextMenuItem(contextMenu, "Background")
    bgBtn:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
    bgBtn:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
    yOff = yOff - 20

    -- Color swatch preview
    local swatch = bgBtn:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(14, 14)
    swatch:SetPoint("RIGHT", bgBtn, "RIGHT", -8, 0)
    swatch:SetTexture("Interface\\Buttons\\WHITE8x8")

    -- Set swatch to current background color
    local curCf = _G["ChatFrame" .. id]
    local r, g, b, a = 0, 0, 0, 0.5
    if curCf then
        r, g, b = FCF_GetCurrentChatFrameBackgroundColor and FCF_GetCurrentChatFrameBackgroundColor(curCf) or 0, 0, 0
        a = curCf.oldAlpha or 0.25
    end
    swatch:SetVertexColor(r, g, b, math.max(a, 0.3))

    -- Border around swatch
    local swatchBorder = bgBtn:CreateTexture(nil, "OVERLAY")
    swatchBorder:SetSize(16, 16)
    swatchBorder:SetPoint("CENTER", swatch, "CENTER", 0, 0)
    swatchBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
    swatchBorder:SetVertexColor(0.5, 0.5, 0.5, 0.8)
    swatchBorder:SetDrawLayer("ARTWORK", -1)

    bgBtn:SetScript("OnClick", function()
        local chatFrame = _G["ChatFrame" .. GetSelectedChatFrameIndex()]
        if not chatFrame then return end
        contextMenu:Hide()

        local cr, cg, cb = 0, 0, 0
        if FCF_GetCurrentChatFrameBackgroundColor then
            cr, cg, cb = FCF_GetCurrentChatFrameBackgroundColor(chatFrame)
        end
        local ca = chatFrame.oldAlpha or 0.25

        local info = {}
        info.r = cr
        info.g = cg
        info.b = cb
        info.opacity = 1 - ca
        info.hasOpacity = true
        info.swatchFunc = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            if FCF_SetWindowColor then
                FCF_SetWindowColor(chatFrame, nr, ng, nb)
            end
        end
        info.opacityFunc = function()
            local newAlpha = 1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or ColorPickerFrame:GetColorAlpha() or 0)
            if FCF_SetWindowAlpha then
                FCF_SetWindowAlpha(chatFrame, newAlpha)
            end
        end
        info.cancelFunc = function(prev)
            if FCF_SetWindowColor then
                FCF_SetWindowColor(chatFrame, prev.r, prev.g, prev.b)
            end
            if FCF_SetWindowAlpha then
                FCF_SetWindowAlpha(chatFrame, 1 - prev.opacity)
            end
        end

        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame:SetColorRGB(info.r, info.g, info.b)
            ColorPickerFrame.hasOpacity = info.hasOpacity
            ColorPickerFrame.opacity = info.opacity
            ColorPickerFrame.func = info.swatchFunc
            ColorPickerFrame.opacityFunc = info.opacityFunc
            ColorPickerFrame.cancelFunc = info.cancelFunc
            ColorPickerFrame.previousValues = { r = info.r, g = info.g, b = info.b, opacity = info.opacity }
            ColorPickerFrame:Hide()
            ColorPickerFrame:Show()
        end
    end)

    bgBtn:SetScript("OnEnter", function()
        if fsm then fsm:Hide() end
    end)

    -- Filters separator
    local filterSep = CreateContextMenuItem(contextMenu, "Filters", nil, true)
    filterSep:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
    filterSep:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
    yOff = yOff - 20

    -- Settings (opens Blizzard chat config or our settings)
    local settBtn = CreateContextMenuItem(contextMenu, "Settings", function()
        if ChatConfigFrame and ChatConfigFrame.Show then
            ShowUIPanel(ChatConfigFrame)
        end
        contextMenu:Hide()
    end)
    settBtn:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
    settBtn:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
    yOff = yOff - 20

    contextMenu:SetSize(maxW, math.abs(yOff) + 4)
    contextMenu:ClearAllPoints()
    contextMenu:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
    contextMenu:Show()
end

-- Close context menu + font submenu when clicking outside
local contextCloser = CreateFrame("Frame")
contextCloser:SetScript("OnUpdate", function()
    if contextMenu and contextMenu:IsShown() then
        local overMenu = contextMenu:IsMouseOver()
        local overFont = fontSubMenu and fontSubMenu:IsShown() and fontSubMenu:IsMouseOver()
        if not overMenu and not overFont and IsMouseButtonDown("LeftButton") then
            contextMenu:Hide()
            if fontSubMenu then fontSubMenu:Hide() end
        end
    end
end)

---------------------------------------------------------------------------
-- Combat log filtering (My Actions / What Happened to Me?)
---------------------------------------------------------------------------

local combatLogFilter = "all" -- "all", "mine", "tome"
local shouldShowCombatMessage = true

-- Event listener for COMBAT_LOG_EVENT_UNFILTERED
local combatFilterFrame = CreateFrame("Frame")
combatFilterFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
combatFilterFrame:SetScript("OnEvent", function()
    if combatLogFilter == "all" then
        shouldShowCombatMessage = true
        return
    end

    local _, _, _, sourceGUID, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    local playerGUID = UnitGUID("player")

    if combatLogFilter == "mine" then
        shouldShowCombatMessage = (sourceGUID == playerGUID)
    elseif combatLogFilter == "tome" then
        shouldShowCombatMessage = (destGUID == playerGUID)
    end
end)

-- Override ChatFrame2.AddMessage to filter based on combat log mode
local origCF2AddMessage
local function HookCombatLogAddMessage()
    if not ChatFrame2 then return end
    if origCF2AddMessage then return end
    origCF2AddMessage = ChatFrame2.AddMessage
    ChatFrame2.AddMessage = function(self, ...)
        if combatLogFilter ~= "all" and not shouldShowCombatMessage then
            return
        end
        return origCF2AddMessage(self, ...)
    end
end

-- Subtab bar UI
local combatSubTabs

local function CreateCombatSubTabs(header)
    local bar = CreateFrame("Frame", "GudaChatCombatSubTabs", UIParent, "BackdropTemplate")
    bar:SetHeight(20)
    bar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -1)
    bar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -1)
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(101)

    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bar:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    bar:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    bar:EnableMouse(true)
    bar:SetAlpha(0)
    bar:Hide()

    local tabs = {}
    local tabDefs = {
        { key = "all",  label = "All" },
        { key = "mine", label = "My Actions" },
        { key = "tome", label = "What Happened to Me?" },
    }

    local xOff = 6
    for _, def in ipairs(tabDefs) do
        local btn = CreateFrame("Button", nil, bar)
        btn:SetHeight(16)

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", btn, "LEFT", 0, 0)
        text:SetText(def.label)
        btn.text = text

        btn:SetWidth(text:GetStringWidth() + 8)
        btn:SetPoint("LEFT", bar, "LEFT", xOff, 0)
        xOff = xOff + btn:GetWidth() + 8

        local function UpdateColors()
            for _, t in ipairs(tabs) do
                if t.key == combatLogFilter then
                    t.btn.text:SetTextColor(1, 1, 1, 1)
                else
                    t.btn.text:SetTextColor(0.5, 0.5, 0.5, 0.8)
                end
            end
        end

        btn:SetScript("OnClick", function()
            combatLogFilter = def.key
            shouldShowCombatMessage = true
            UpdateColors()
        end)

        btn:SetScript("OnEnter", function(self)
            self.text:SetTextColor(0.9, 0.9, 0.9, 1)
            if chatHeader then chatHeader:SetAlpha(1) end
        end)
        btn:SetScript("OnLeave", function()
            UpdateColors()
        end)

        tinsert(tabs, { key = def.key, btn = btn })
    end

    -- Set initial colors
    for _, t in ipairs(tabs) do
        if t.key == combatLogFilter then
            t.btn.text:SetTextColor(1, 1, 1, 1)
        else
            t.btn.text:SetTextColor(0.5, 0.5, 0.5, 0.8)
        end
    end

    combatSubTabs = bar
    return bar
end

local function CreateChatHeader(parentFrame)
    local header = CreateFrame("Frame", "GudaChatHeader", UIParent, "BackdropTemplate")
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("BOTTOMLEFT", parentFrame, "TOPLEFT", -4, 0)
    header:SetPoint("BOTTOMRIGHT", parentFrame, "TOPRIGHT", 4, 0)
    header:SetFrameStrata("MEDIUM")
    header:SetFrameLevel(100)
    header:SetAlpha(0)

    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    header:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
    header:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)

    -- Hover detection zone (covers header + chat frame area)
    local hoverZone = CreateFrame("Frame", nil, UIParent)
    hoverZone:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    hoverZone:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", 0, 0)
    hoverZone:SetFrameStrata("BACKGROUND")
    hoverZone:EnableMouse(false)

    local fadeIn, fadeOut
    local isHovering = false

    local function ShowHeader()
        if isHovering then return end
        isHovering = true
        if fadeOut then fadeOut:Stop() end
        fadeIn = header:CreateAnimationGroup()
        local anim = fadeIn:CreateAnimation("Alpha")
        anim:SetFromAlpha(header:GetAlpha())
        anim:SetToAlpha(1)
        anim:SetDuration(0.15)
        fadeIn:SetScript("OnFinished", function()
            header:SetAlpha(1)
            if combatSubTabs and combatSubTabs:IsShown() then combatSubTabs:SetAlpha(1) end
        end)
        fadeIn:Play()
        if combatSubTabs and combatSubTabs:IsShown() then combatSubTabs:SetAlpha(header:GetAlpha()) end
        if ns.scrollbar then ns.scrollbar.FadeIn() end
    end

    local function HideHeader()
        if not isHovering then return end
        isHovering = false
        -- Delay hide slightly so moving between buttons doesn't flicker
        C_Timer.After(0.3, function()
            if isHovering then return end
            -- Check if mouse is still over header, chat area, or subtabs
            if header:IsMouseOver() or parentFrame:IsMouseOver()
                or (combatSubTabs and combatSubTabs:IsShown() and combatSubTabs:IsMouseOver()) then
                isHovering = true
                return
            end
            if fadeIn then fadeIn:Stop() end
            fadeOut = header:CreateAnimationGroup()
            local anim = fadeOut:CreateAnimation("Alpha")
            anim:SetFromAlpha(header:GetAlpha())
            anim:SetToAlpha(0)
            anim:SetDuration(0.25)
            fadeOut:SetScript("OnFinished", function()
                header:SetAlpha(0)
                if combatSubTabs then combatSubTabs:SetAlpha(0) end
            end)
            fadeOut:Play()
            if combatSubTabs and combatSubTabs:IsShown() then combatSubTabs:SetAlpha(header:GetAlpha()) end
            if ns.scrollbar then ns.scrollbar.FadeOut() end
        end)
    end

    -- Detect hover via OnUpdate on a monitoring frame
    local monitor = CreateFrame("Frame")
    monitor:SetScript("OnUpdate", function()
        local over = header:IsMouseOver() or parentFrame:IsMouseOver()
            or (combatSubTabs and combatSubTabs:IsShown() and combatSubTabs:IsMouseOver())
        -- Also check if any dropdown is open (our custom or Blizzard's)
        local dropdownOpen = GudaChatTabDropdown and GudaChatTabDropdown:IsShown()
        local blizzDropdownOpen = DropDownList1 and DropDownList1:IsShown()
        local contextMenuOpen = contextMenu and contextMenu:IsShown()
        local fontMenuOpen = fontSubMenu and fontSubMenu:IsShown()
        if over or dropdownOpen or blizzDropdownOpen or contextMenuOpen or fontMenuOpen then
            ShowHeader()
        else
            HideHeader()
        end
    end)

    header:EnableMouse(true)

    -------------------------------------------------------------------
    -- Drag to move chat (when not locked)
    -------------------------------------------------------------------
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function(self)
        if GudaChatDB.locked then return end
        parentFrame:SetMovable(true)
        parentFrame:SetUserPlaced(true)
        parentFrame:StartMoving()
        self.isDragging = true
    end)
    header:SetScript("OnDragStop", function(self)
        if self.isDragging then
            parentFrame:StopMovingOrSizing()
            self.isDragging = false
            -- Save position to persist across reloads
            local point, _, relPoint, x, y = parentFrame:GetPoint(1)
            GudaChatDB.position = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)

    -- Tooltip hint for drag
    header:SetScript("OnEnter", function(self)
        if not GudaChatDB.locked then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Drag to move", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end)
    header:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -------------------------------------------------------------------
    -- Left side: Tab switcher icon + dropdown
    -------------------------------------------------------------------
    local tabBtn = CreateIconButton(header, ASSET_PATH .. "logo.png", ICON_SIZE, "Chat Tabs")
    tabBtn:SetPoint("LEFT", header, "LEFT", 4, 0)

    -- Tab dropdown
    local dropdown = CreateFrame("Frame", "GudaChatTabDropdown", tabBtn, "BackdropTemplate")
    dropdown:SetFrameStrata("TOOLTIP")
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    dropdown:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    dropdown:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
    dropdown:Hide()

    local menuButtons = {}

    local function CloseDropdown()
        dropdown:Hide()
    end

    local function RefreshDropdown()
        for _, mb in ipairs(menuButtons) do
            mb:Hide()
            mb:SetParent(nil)
        end
        wipe(menuButtons)

        local yOff = -4
        local maxW = 60

        for i = 1, NUM_CHAT_WINDOWS do
            local cf = _G["ChatFrame" .. i]
            local tab = _G["ChatFrame" .. i .. "Tab"]
            if cf and tab then
                local name = GetChatTabName(i)
                local isDocked = cf.isDocked or (i == 1)
                if isDocked and i ~= 2 then -- skip Combat Log (has its own button)
                    local mb = CreateFrame("Button", nil, dropdown)
                    mb:SetHeight(20)
                    mb:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 4, yOff)
                    mb:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", -4, yOff)

                    local mbText = mb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    mbText:SetPoint("LEFT", mb, "LEFT", 6, 0)
                    mbText:SetText(name)

                    local isActive = (GetSelectedChatFrameIndex() == i)
                    mbText:SetTextColor(isActive and 1 or 0.7, isActive and 1 or 0.7, isActive and 1 or 0.7, isActive and 1 or 0.8)

                    mb:SetScript("OnEnter", function()
                        mbText:SetTextColor(1, 1, 1, 1)
                    end)
                    mb:SetScript("OnLeave", function()
                        local active = (GetSelectedChatFrameIndex() == i)
                        if not active then
                            mbText:SetTextColor(0.7, 0.7, 0.7, 0.8)
                        end
                    end)

                    local frameIndex = i
                    mb:SetScript("OnClick", function()
                        FCF_SelectDockFrame(_G["ChatFrame" .. frameIndex])
                        CloseDropdown()
                    end)

                    local tw = mbText:GetStringWidth() + 16
                    if tw > maxW then maxW = tw end
                    yOff = yOff - 20
                    tinsert(menuButtons, mb)
                end
            end
        end

        dropdown:SetSize(maxW + 8, math.abs(yOff) + 4)
        dropdown:ClearAllPoints()
        dropdown:SetPoint("TOPLEFT", tabBtn, "BOTTOMLEFT", -4, -2)
    end

    tabBtn:SetScript("OnClick", function()
        if dropdown:IsShown() then
            CloseDropdown()
        else
            RefreshDropdown()
            dropdown:Show()
        end
    end)

    -- Close dropdown when clicking outside
    local closer = CreateFrame("Frame", nil, dropdown)
    closer:SetScript("OnUpdate", function()
        if dropdown:IsShown() and not dropdown:IsMouseOver() and not tabBtn:IsMouseOver() then
            if IsMouseButtonDown("LeftButton") then
                CloseDropdown()
            end
        end
    end)

    -------------------------------------------------------------------
    -- Left side: Combat log icon
    -------------------------------------------------------------------
    local combatBtn = CreateIconButton(header, ASSET_PATH .. "combat.png", ICON_SIZE, "Combat Log")
    combatBtn:SetPoint("LEFT", tabBtn, "RIGHT", 6, 0)

    combatBtn:SetScript("OnClick", function()
        if ChatFrame2 then
            if ChatFrame2:IsShown() then
                FCF_SelectDockFrame(ChatFrame1)
            else
                FCF_SelectDockFrame(ChatFrame2)
            end
        end
    end)

    -- Keep existing OnEnter/OnLeave for icon color + tooltip
    combatBtn:HookScript("OnClick", function() CloseDropdown() end)

    -------------------------------------------------------------------
    -- Center: Current tab name
    -------------------------------------------------------------------
    local tabLabel = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tabLabel:SetPoint("CENTER", header, "CENTER", 0, 0)
    tabLabel:SetTextColor(0.6, 0.6, 0.6, 0.8)
    tabLabel:SetText(GetChatTabName(1))

    -- Right-click button over tab label for Blizzard context menu
    local tabLabelBtn = CreateFrame("Button", nil, header)
    tabLabelBtn:SetPoint("CENTER", tabLabel, "CENTER", 0, 0)
    tabLabelBtn:SetHeight(HEADER_HEIGHT)
    tabLabelBtn:RegisterForClicks("RightButtonUp")
    tabLabelBtn:SetScript("OnClick", function(self, button)
        if button ~= "RightButton" then return end
        if contextMenu and contextMenu:IsShown() then
            contextMenu:Hide()
            if fontSubMenu then fontSubMenu:Hide() end
        else
            ShowContextMenu(self)
        end
    end)
    tabLabelBtn:SetScript("OnEnter", function(self)
        tabLabel:SetTextColor(0.9, 0.9, 0.9, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Right-click for options", 0.7, 0.7, 0.7)
        GameTooltip:Show()
        if chatHeader then chatHeader:SetAlpha(1) end
    end)
    tabLabelBtn:SetScript("OnLeave", function(self)
        tabLabel:SetTextColor(0.6, 0.6, 0.6, 0.8)
        GameTooltip:Hide()
    end)

    -- Size the button to match the label text width
    local function UpdateTabLabelBtnWidth()
        tabLabelBtn:SetWidth(math.max(tabLabel:GetStringWidth() + 16, 40))
    end
    UpdateTabLabelBtnWidth()

    -- Update label when tabs switch
    hooksecurefunc("FCF_SelectDockFrame", function(cf)
        if not cf then return end
        for i = 1, NUM_CHAT_WINDOWS do
            if _G["ChatFrame" .. i] == cf then
                tabLabel:SetText(GetChatTabName(i))
                UpdateTabLabelBtnWidth()
                break
            end
        end
    end)

    -------------------------------------------------------------------
    -- Right side: Settings icon
    -------------------------------------------------------------------
    local settingsBtn = CreateIconButton(header, ASSET_PATH .. "cog.png", ICON_SIZE, "Settings")
    settingsBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)

    settingsBtn:SetScript("OnClick", function()
        ns.ToggleSettings()
        CloseDropdown()
    end)

    -------------------------------------------------------------------
    -- Combat log subtabs
    -------------------------------------------------------------------
    CreateCombatSubTabs(header)
    HookCombatLogAddMessage()

    -- Show/hide subtab bar when switching tabs
    hooksecurefunc("FCF_SelectDockFrame", function(cf)
        if combatSubTabs then
            if cf == ChatFrame2 then
                combatSubTabs:Show()
            else
                combatSubTabs:Hide()
                -- Reset filter when leaving combat log
                combatLogFilter = "all"
                shouldShowCombatMessage = true
            end
        end
    end)

    chatHeader = header
    ns.chatHeader = header
    return header
end

---------------------------------------------------------------------------
-- Settings popup
---------------------------------------------------------------------------

local settingsFrame

local function CreateCheckbox(parent, label, checked, onClick)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(26)

    local cb
    if DoesTemplateExist and DoesTemplateExist("SettingsCheckBoxTemplate") then
        cb = CreateFrame("CheckButton", nil, container, "SettingsCheckBoxTemplate")
    elseif DoesTemplateExist and DoesTemplateExist("SettingsCheckboxTemplate") then
        cb = CreateFrame("CheckButton", nil, container, "SettingsCheckboxTemplate")
    else
        cb = CreateFrame("CheckButton", nil, container, "InterfaceOptionsCheckButtonTemplate")
    end

    cb:SetPoint("LEFT", container, "LEFT", 0, 0)
    cb:SetText("")
    cb:SetChecked(checked)
    cb:SetScript("OnClick", function(self)
        onClick(self:GetChecked())
    end)

    local text = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)

    container:EnableMouse(true)
    container:SetScript("OnMouseUp", function() cb:Click() end)

    container.checkbox = cb
    container.label = text
    return container
end

local function CreateSeparator(parent, label)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(20)

    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", container, "LEFT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetTextColor(0.9, 0.75, 0.3)
    text:SetText(label)

    local line = container:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", text, "RIGHT", 6, 0)
    line:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    line:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    return container
end

local function CreateSlider(parent, label, minVal, maxVal, step, currentVal, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(36)

    local text = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", container, "LEFT", 0, 0)
    text:SetText(label)

    local useModernSlider = DoesTemplateExist and DoesTemplateExist("MinimalSliderWithSteppersTemplate")
    local slider, valueText

    if useModernSlider then
        slider = CreateFrame("Slider", nil, container, "MinimalSliderWithSteppersTemplate")
        slider:SetPoint("LEFT", container, "CENTER", -50, 0)
        slider:SetPoint("RIGHT", container, "RIGHT", -50, 0)
        slider:SetHeight(20)

        local steps = (maxVal - minVal) / step
        slider:Init(currentVal, minVal, maxVal, steps, {
            [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
                return WHITE_FONT_COLOR:WrapTextInColorCode(string.format("%d", value))
            end)
        })

        slider:RegisterCallback("OnValueChanged", function(_, value)
            value = math.floor(value + 0.5)
            onChange(value)
        end)

        container.GetValue = function() return slider:GetValue() end
        container.SetValue = function(_, val) slider:SetValue(val) end
    else
        slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
        slider:SetPoint("LEFT", container, "CENTER", -50, 0)
        slider:SetPoint("RIGHT", container, "RIGHT", -55, 0)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        slider.Text:SetText("")
        slider.Low:SetText("")
        slider.High:SetText("")
        slider:SetValue(currentVal)

        valueText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        valueText:SetPoint("LEFT", slider, "RIGHT", 5, 0)
        valueText:SetWidth(40)
        valueText:SetJustifyH("LEFT")
        valueText:SetText(currentVal)

        slider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            valueText:SetText(value)
            onChange(value)
        end)

        container.GetValue = function() return slider:GetValue() end
        container.SetValue = function(_, val) slider:SetValue(val) end
    end

    container:EnableMouseWheel(true)
    container:SetScript("OnMouseWheel", function(self, delta)
        local current = container.GetValue()
        local val = current + (delta * step)
        val = math.max(minVal, math.min(maxVal, val))
        container.SetValue(nil, val)
        onChange(math.floor(val + 0.5))
    end)

    container.slider = slider
    container.valueText = valueText
    return container
end

local TIMESTAMP_OPTIONS = {
    { label = "None",          value = "none" },
    { label = "03:27",         value = "%I:%M " },
    { label = "03:27:32",      value = "%I:%M:%S " },
    { label = "03:27 PM",      value = "%I:%M %p " },
    { label = "03:27:32 PM",   value = "%I:%M:%S %p " },
    { label = "15:27",         value = "%H:%M " },
    { label = "15:27:32",      value = "%H:%M:%S " },
    { label = "[03:27]",       value = "[%I:%M] " },
    { label = "[03:27:32]",    value = "[%I:%M:%S] " },
    { label = "[03:27 PM]",    value = "[%I:%M %p] " },
    { label = "[03:27:32 PM]", value = "[%I:%M:%S %p] " },
    { label = "[15:27]",       value = "[%H:%M] " },
    { label = "[15:27:32]",    value = "[%H:%M:%S] " },
}

local dropdownCounter = 0

local function CreateDropdown(parent, label, options, currentValue, onChange)
    dropdownCounter = dropdownCounter + 1
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(30)

    local text = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", container, "LEFT", 0, 0)
    text:SetText(label)

    local ddName = "GudaChatDropdown" .. dropdownCounter
    local dd = CreateFrame("Frame", ddName, container, "UIDropDownMenuTemplate")
    dd:SetPoint("RIGHT", container, "RIGHT", 16, -2)
    UIDropDownMenu_SetWidth(dd, 120)

    local function Initialize(self, level)
        for _, opt in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.label
            info.value = opt.value
            info.func = function(self)
                UIDropDownMenu_SetSelectedValue(dd, self.value)
                UIDropDownMenu_SetText(dd, opt.label)
                onChange(self.value)
                CloseDropDownMenus()
            end
            info.checked = (opt.value == UIDropDownMenu_GetSelectedValue(dd))
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dd, Initialize)
    UIDropDownMenu_SetSelectedValue(dd, currentValue)
    for _, opt in ipairs(options) do
        if opt.value == currentValue then
            UIDropDownMenu_SetText(dd, opt.label)
            break
        end
    end

    container.dropdown = dd
    return container
end

local function CreateSettingsFrame()
    local f = CreateFrame("Frame", "GudaChatSettingsPopup", UIParent, "ButtonFrameTemplate")
    f:SetSize(340, 416)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:EnableMouse(true)

    tinsert(UISpecialFrames, "GudaChatSettingsPopup")

    ButtonFrameTemplate_HidePortrait(f)
    ButtonFrameTemplate_HideButtonBar(f)
    if f.Inset then f.Inset:Hide() end

    f:SetTitle("GudaChat Settings")

    -- Drag region
    local drag = CreateFrame("Frame", nil, f)
    drag:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    drag:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, 0)
    drag:SetHeight(24)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        f:StartMoving()
        f:SetUserPlaced(false)
    end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        f:SetUserPlaced(false)
    end)

    -- Content area
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -32)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)

    -- Build controls with vertical stacking
    local yOffset = 0
    local controls = {}

    local function AddControl(widget)
        widget:SetParent(content)
        widget:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
        widget:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -yOffset)
        yOffset = yOffset + widget:GetHeight() + 8
        tinsert(controls, widget)
    end

    -- Section: General
    AddControl(CreateSeparator(content, "General"))

    AddControl(CreateCheckbox(content, "Lock chat position", GudaChatDB.locked, function(checked)
        GudaChatDB.locked = checked
        ApplyLockState()
    end))

    AddControl(CreateCheckbox(content, "Disable message fading", not GudaChatDB.fading, function(checked)
        GudaChatDB.fading = not checked
        ChatFrame1:SetFading(GudaChatDB.fading)
    end))

    AddControl(CreateCheckbox(content, "Class colored names", GudaChatDB.classColors, function(checked)
        GudaChatDB.classColors = checked
        ApplyClassColors()
    end))

    AddControl(CreateCheckbox(content, "Show player level", GudaChatDB.showLevel, function(checked)
        GudaChatDB.showLevel = checked
    end))

    AddControl(CreateCheckbox(content, "Copyable links", GudaChatDB.copyLinks, function(checked)
        GudaChatDB.copyLinks = checked
    end))

    local currentTimestamp = GetCVar("showTimestamps") or "none"
    AddControl(CreateDropdown(content, "Timestamps", TIMESTAMP_OPTIONS, currentTimestamp, function(value)
        SetCVar("showTimestamps", value)
    end))

    AddControl(CreateCheckbox(content, "Emojis", GudaChatDB.emojis, function(checked)
        GudaChatDB.emojis = checked
        for i = 1, NUM_CHAT_WINDOWS do
            local eb = _G["ChatFrame" .. i .. "EditBox"]
            if eb and eb.emojiBtn then
                if checked then eb.emojiBtn:Show() else eb.emojiBtn:Hide() end
            end
        end
        if not checked and emojiPickerFrame then emojiPickerFrame:Hide() end
    end))

    AddControl(CreateSlider(content, "Emoji size", 10, 32, 1, GudaChatDB.emojiSize or DEFAULT_EMOJI_SIZE, function(value)
        GudaChatDB.emojiSize = value
    end))

    -- Section: Input Bar
    AddControl(CreateSeparator(content, "Input Bar"))

    local inputTopCb = CreateCheckbox(content, "Show input bar on top", GudaChatDB.inputPosition == "top", function(checked)
        GudaChatDB.inputPosition = checked and "top" or "bottom"
        for i = 1, NUM_CHAT_WINDOWS do
            PositionEditBox(_G["ChatFrame" .. i], i, GudaChatDB.inputPosition)
        end
        ApplyChatMargins()
    end)
    AddControl(inputTopCb)

    f.controls = controls
    f:Hide()
    return f
end

local function ToggleSettings()
    if not settingsFrame then
        settingsFrame = CreateSettingsFrame()
    end
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
    end
end

ns.ToggleSettings = ToggleSettings

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

SLASH_GUDACHAT1 = "/gudachat"
SLASH_GUDACHAT2 = "/gc"
SlashCmdList["GUDACHAT"] = function(msg)
    msg = strtrim(msg):lower()
    if msg == "" or msg == "settings" or msg == "options" then
        ToggleSettings()
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
            GudaChatDB.showLevel = true
        end
        if GudaChatDB.emojis == nil then
            GudaChatDB.emojis = true
        end
        if GudaChatDB.emojiSize == nil then
            GudaChatDB.emojiSize = DEFAULT_EMOJI_SIZE
        end
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        for i = 1, NUM_CHAT_WINDOWS do
            StripChatChrome(i)
        end

        if GeneralDockManagerOverflowButton then
            KillFrame(GeneralDockManagerOverflowButton)
        end
        if GeneralDockManager then
            KillFrame(GeneralDockManager)
        end

        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            for i = 1, NUM_CHAT_WINDOWS do
                StripChatChrome(i)
            end
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
                hooksecurefunc(funcName, RehideAllTabs)
            end
        end

        -- Also catch channel events that trigger tab changes
        local tabWatcher = CreateFrame("Frame")
        tabWatcher:RegisterEvent("CHANNEL_UI_UPDATE")
        tabWatcher:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
        tabWatcher:RegisterEvent("UPDATE_CHAT_WINDOWS")
        tabWatcher:SetScript("OnEvent", function()
            C_Timer.After(0.1, RehideAllTabs)
        end)

        -- Restore saved chat position
        if GudaChatDB.position then
            local p = GudaChatDB.position
            ChatFrame1:SetMovable(true)
            ChatFrame1:ClearAllPoints()
            ChatFrame1:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
            ChatFrame1:SetUserPlaced(true)
        end

        ChatFrame1:SetFading(GudaChatDB.fading)
        ApplyClassColors()
        EnableLevelDisplay()
        EnableCopyLinks()
        EnableEmojis()
        SetupLinkHook()
        CreateScrollbar(ChatFrame1)
        CreateChatHeader(ChatFrame1)
        ApplyLockState()
        ApplyChatMargins()

        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffGudaChat|r loaded — type |cffffd200/gc|r for settings")
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
