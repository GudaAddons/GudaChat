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

        local closeBtn = CreateFrame("Button", nil, f)
        closeBtn:SetSize(12, 12)
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
        closeBtn:SetNormalTexture("Interface\\AddOns\\GudaChat\\Assets\\close.png")
        closeBtn:GetNormalTexture():SetVertexColor(0.6, 0.6, 0.6)
        closeBtn:SetScript("OnEnter", function(self)
            self:GetNormalTexture():SetVertexColor(1, 1, 1)
        end)
        closeBtn:SetScript("OnLeave", function(self)
            self:GetNormalTexture():SetVertexColor(0.6, 0.6, 0.6)
        end)
        closeBtn:SetScript("OnClick", function() f:Hide() end)

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
    if chatFrame.gudaScrollbar then return end
    local slider = CreateFrame("Slider", nil, chatFrame, "BackdropTemplate")
    chatFrame.gudaScrollbar = slider
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

    -- Scroll to bottom button
    local scrollDown = CreateFrame("Button", nil, chatFrame)
    scrollDown:SetSize(20, 20)
    scrollDown:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", -2, 2)
    scrollDown:SetFrameStrata("DIALOG")

    local sdBg = scrollDown:CreateTexture(nil, "BACKGROUND")
    sdBg:SetAllPoints()
    sdBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    sdBg:SetVertexColor(0.08, 0.08, 0.08, 0.8)

    local sdIcon = scrollDown:CreateTexture(nil, "ARTWORK")
    sdIcon:SetPoint("CENTER")
    sdIcon:SetSize(12, 12)
    sdIcon:SetTexture("Interface\\AddOns\\GudaChat\\Assets\\down.png")
    sdIcon:SetVertexColor(0.8, 0.6, 0, 0.9)

    scrollDown:SetScript("OnEnter", function()
        sdIcon:SetVertexColor(1, 0.8, 0, 1)
        sdBg:SetVertexColor(0.12, 0.12, 0.12, 0.9)
    end)
    scrollDown:SetScript("OnLeave", function()
        sdIcon:SetVertexColor(0.8, 0.6, 0, 0.9)
        sdBg:SetVertexColor(0.08, 0.08, 0.08, 0.8)
    end)

    scrollDown:SetScript("OnClick", function()
        chatFrame:ScrollToBottom()
        SyncSlider()
    end)

    scrollDown:Hide()

    -- Show/hide based on scroll position
    local scrollDownMonitor = CreateFrame("Frame")
    scrollDownMonitor:SetScript("OnUpdate", function(self, dt)
        local offset = chatFrame:GetScrollOffset()
        if offset > 0 then
            scrollDown:Show()
        else
            scrollDown:Hide()
        end
    end)

    return slider
end

local function FadeInScrollbar()
    if GudaChatDB and GudaChatDB.hideScrollbar then return end
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf and cf.gudaScrollbar and cf:IsVisible() then
            cf.gudaScrollbar.FadeIn()
        end
    end
end

local function FadeOutScrollbar()
    if GudaChatDB and GudaChatDB.hideScrollbar then return end
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf and cf.gudaScrollbar and cf:IsVisible() then
            cf.gudaScrollbar.FadeOut()
        end
    end
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

---------------------------------------------------------------------------
-- Whisper frame setup
---------------------------------------------------------------------------

local function EnforceWhisperGroups(cf)
    ChatFrame_RemoveAllMessageGroups(cf)
    ChatFrame_AddMessageGroup(cf, "WHISPER")
    ChatFrame_AddMessageGroup(cf, "BN_WHISPER")
end

local function SetupWhisperFrame()
    -- Check if we already have a saved whisper frame that's still valid
    local idx = GudaChatDB.whisperFrameIndex
    if idx then
        local cf = _G["ChatFrame" .. idx]
        local name = cf and GetChatWindowInfo(idx)
        if cf and name == "Whispers" then
            ns.whisperFrame = cf
            ns.whisperFrameIndex = idx
            EnforceWhisperGroups(cf)
            return
        end
        -- Saved index is stale
        GudaChatDB.whisperFrameIndex = nil
    end

    -- Find an existing frame named "Whispers"
    for i = 3, NUM_CHAT_WINDOWS do
        local name = GetChatWindowInfo(i)
        if name == "Whispers" then
            local cf = _G["ChatFrame" .. i]
            ns.whisperFrame = cf
            ns.whisperFrameIndex = i
            GudaChatDB.whisperFrameIndex = i
            EnforceWhisperGroups(cf)
            return
        end
    end

    -- Create a new whisper window
    if FCF_OpenNewWindow then
        FCF_OpenNewWindow("Whispers")
        for i = NUM_CHAT_WINDOWS, 1, -1 do
            local cf = _G["ChatFrame" .. i]
            if cf then
                EnforceWhisperGroups(cf)
                StripChatChrome(i)
                ns.whisperFrame = cf
                ns.whisperFrameIndex = i
                GudaChatDB.whisperFrameIndex = i
                -- Dock it and switch back to General
                FCF_DockFrame(cf)
                FCF_SelectDockFrame(ChatFrame1)
                break
            end
        end
    end
end

-- Listen for incoming whispers to trigger blink notification
local whisperListener = CreateFrame("Frame")
whisperListener:RegisterEvent("CHAT_MSG_WHISPER")
whisperListener:RegisterEvent("CHAT_MSG_BN_WHISPER")
whisperListener:SetScript("OnEvent", function()
    if not GudaChatDB or not GudaChatDB.whisperTab then return end
    -- Only blink if whisper frame is not currently shown
    if ns.whisperFrame and not ns.whisperFrame:IsShown() and ns.StartWhisperBlink then
        ns.StartWhisperBlink()
    end
end)

-- History channel mapping and filter keys
local HISTORY_CHANNEL_LABELS = {
    SAY = "Say", YELL = "Yell", GUILD = "Guild", OFFICER = "Officer",
    WHISPER = "Whisper", WHISPER_INFORM = "Whisper",
    PARTY = "Party", PARTY_LEADER = "Party",
    RAID = "Raid", RAID_LEADER = "Raid",
    INSTANCE_CHAT = "Instance", INSTANCE_CHAT_LEADER = "Instance",
    BN_WHISPER = "Whisper", BN_WHISPER_INFORM = "Whisper",
}

local HISTORY_FILTER_KEYS = {
    "Say", "Yell", "Guild", "Officer", "Whisper", "Party", "Raid", "Instance",
}

local CHANNEL_TO_CHATTYPE = {
    Say = "SAY", Yell = "YELL", Guild = "GUILD", Officer = "OFFICER",
    Whisper = "WHISPER", Party = "PARTY", Raid = "RAID",
    Instance = "INSTANCE_CHAT",
}

-- Message capture for chat history
local historyCaptureFrame = CreateFrame("Frame")
local HISTORY_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
}
for _, ev in ipairs(HISTORY_EVENTS) do
    historyCaptureFrame:RegisterEvent(ev)
end
historyCaptureFrame:SetScript("OnEvent", function(self, event, msg, sender, ...)
    if not GudaChatDB or not GudaChatDB.historyEnabled then return end
    local channelKey = event:gsub("CHAT_MSG_", "")
    local label = HISTORY_CHANNEL_LABELS[channelKey]
    if not label then return end

    local bucket = GudaChatDB.history[label]
    if not bucket then
        GudaChatDB.history[label] = {}
        bucket = GudaChatDB.history[label]
    end

    local guid = select(10, ...)
    local classFile
    if guid and guid ~= "" then
        local _, cls = GetPlayerInfoByGUID(guid)
        classFile = cls
    end

    local senderName = sender and sender:match("^([^%-]+)")
    local level = GetPlayerLevel(senderName)

    local isOutgoing = channelKey == "WHISPER_INFORM" or channelKey == "BN_WHISPER_INFORM"

    tinsert(bucket, {
        time = time(),
        channel = label,
        sender = sender or "",
        message = msg or "",
        class = classFile,
        level = level,
        outgoing = isOutgoing,
    })

    -- Trim oldest entries per channel
    local maxPerChannel = math.floor((GudaChatDB.historyMax or 500) / #HISTORY_FILTER_KEYS)
    while #bucket > maxPerChannel do
        tremove(bucket, 1)
    end
end)

local REPLAY_CHANNEL_FORMATS = {
    Say = "says",
    Yell = "yells",
}

local function ReplayHistory()
    if not GudaChatDB or not GudaChatDB.historyEnabled then return end
    local history = GudaChatDB.history
    if not history then return end

    local all = {}
    for _, key in ipairs(HISTORY_FILTER_KEYS) do
        local bucket = history[key]
        if bucket then
            for _, entry in ipairs(bucket) do
                tinsert(all, entry)
            end
        end
    end
    if #all == 0 then return end

    table.sort(all, function(a, b) return a.time < b.time end)
    local start = math.max(1, #all - 9)

    ChatFrame1:AddMessage("|cff555555--- previous session ---|r")
    if GudaChatDB.whisperTab and ns.whisperFrame then
        ns.whisperFrame:AddMessage("|cff555555--- previous session ---|r")
    end

    local tsFmt = GetCVar("showTimestamps")
    if tsFmt == "none" then tsFmt = nil end
    local dim = 0.5

    for i = start, #all do
        local entry = all[i]
        local chatType = CHANNEL_TO_CHATTYPE[entry.channel]
        local info = chatType and ChatTypeInfo[chatType]
        local r, g, b = 0.6, 0.6, 0.6
        if info then r, g, b = info.r, info.g, info.b end
        r, g, b = r * dim, g * dim, b * dim

        local senderName = entry.sender:match("^([^%-]+)") or entry.sender
        local nameLink
        if GudaChatDB.classColors and entry.class and RAID_CLASS_COLORS[entry.class] then
            local cc = RAID_CLASS_COLORS[entry.class]
            nameLink = string.format("|cff%02x%02x%02x|Hplayer:%s|h[%s]|h|r",
                cc.r*dim*255, cc.g*dim*255, cc.b*dim*255, entry.sender, senderName)
        else
            nameLink = string.format("|Hplayer:%s|h[%s]|h", entry.sender, senderName)
        end

        -- Level indicator
        local levelStr = ""
        if entry.level then
            local lr, lg, lb = GetLevelDifficultyColor(entry.level)
            levelStr = string.format("|cff%02x%02x%02x[%d]|r ", lr*dim*255, lg*dim*255, lb*dim*255, entry.level)
        end

        -- Timestamp
        local timePrefix = ""
        if tsFmt then
            timePrefix = "|cff4d4d4d" .. date(tsFmt, entry.time) .. "|r"
        end

        -- Format like original WoW chat using CHAT_X_GET patterns
        local body
        if entry.channel == "Whisper" and entry.outgoing then
            body = string.format("To %s: %s%s", nameLink, levelStr, entry.message)
        elseif entry.channel == "Whisper" then
            body = string.format("%s whispers: %s%s", nameLink, levelStr, entry.message)
        else
            local verb = REPLAY_CHANNEL_FORMATS[entry.channel]
            if verb then
                body = string.format("%s %s: %s%s", nameLink, verb, levelStr, entry.message)
            else
                body = string.format("[%s] %s: %s%s", entry.channel, nameLink, levelStr, entry.message)
            end
        end

        body = timePrefix .. body

        ChatFrame1:AddMessage(body, r, g, b)
        if entry.channel == "Whisper" and GudaChatDB.whisperTab and ns.whisperFrame then
            ns.whisperFrame:AddMessage(body, r, g, b)
        end
    end
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
        FadeInScrollbar()
    end

    local function HideHeader()
        if not isHovering then return end
        isHovering = false
        -- Delay hide slightly so moving between buttons doesn't flicker
        C_Timer.After(0.3, function()
            if isHovering then return end
            -- Check if mouse is still over header, chat area, subtabs, or dropdowns
            if header:IsMouseOver() or parentFrame:IsMouseOver()
                or (combatSubTabs and combatSubTabs:IsShown() and combatSubTabs:IsMouseOver())
                or (GudaChatTypeDropdown and GudaChatTypeDropdown:IsShown() and GudaChatTypeDropdown:IsMouseOver())
                or (GudaChatEmoteSubMenu and GudaChatEmoteSubMenu:IsShown() and GudaChatEmoteSubMenu:IsMouseOver()) then
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
            FadeOutScrollbar()
        end)
    end

    -- Detect hover via OnUpdate on a monitoring frame
    local monitor = CreateFrame("Frame")
    monitor:SetScript("OnUpdate", function()
        local over = header:IsMouseOver() or parentFrame:IsMouseOver()
            or (combatSubTabs and combatSubTabs:IsShown() and combatSubTabs:IsMouseOver())
        -- Also check if any dropdown is open (our custom or Blizzard's)
        local dropdownOpen = GudaChatTabDropdown and GudaChatTabDropdown:IsShown()
        local chatTypeOpen = (GudaChatTypeDropdown and GudaChatTypeDropdown:IsShown()) or (GudaChatEmoteSubMenu and GudaChatEmoteSubMenu:IsShown())
        local blizzDropdownOpen = DropDownList1 and DropDownList1:IsShown()
        local contextMenuOpen = contextMenu and contextMenu:IsShown()
        local fontMenuOpen = fontSubMenu and fontSubMenu:IsShown()
        if over or dropdownOpen or chatTypeOpen or blizzDropdownOpen or contextMenuOpen or fontMenuOpen then
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
                if isDocked and i ~= 2 and i ~= (ns.whisperFrameIndex or -1) then -- skip Combat Log & Whispers (have their own buttons)
                    local mb = CreateFrame("Button", nil, dropdown)
                    mb:SetHeight(20)
                    mb:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 4, yOff)
                    mb:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", -4, yOff)

                    local mbText = mb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    mbText:SetPoint("LEFT", mb, "LEFT", 6, 0)
                    mbText:SetText(name)

                    local isActive = (GetSelectedChatFrameIndex() == i)
                    mbText:SetTextColor(isActive and 1 or 0.8, isActive and 0.8 or 0.8, isActive and 0 or 0.8, 1)

                    mb:SetScript("OnEnter", function()
                        mbText:SetTextColor(1, 0.8, 0, 1)
                    end)
                    mb:SetScript("OnLeave", function()
                        local active = (GetSelectedChatFrameIndex() == i)
                        if not active then
                            mbText:SetTextColor(0.8, 0.8, 0.8, 1)
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
        dropdown:SetPoint("BOTTOMLEFT", tabBtn, "TOPLEFT", -4, 2)
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
    -- Left side: Whisper icon
    -------------------------------------------------------------------
    local whisperBtn = CreateIconButton(header, ASSET_PATH .. "characters.png", ICON_SIZE, "Whispers")
    whisperBtn:SetPoint("LEFT", combatBtn, "RIGHT", 6, 0)
    if not GudaChatDB.whisperTab then whisperBtn:Hide() end
    ns.whisperBtn = whisperBtn

    -- Blink animation for incoming whispers
    local blinkGroup = whisperBtn:CreateAnimationGroup()
    blinkGroup:SetLooping("REPEAT")
    local blinkFadeOut = blinkGroup:CreateAnimation("Alpha")
    blinkFadeOut:SetFromAlpha(1)
    blinkFadeOut:SetToAlpha(0.2)
    blinkFadeOut:SetDuration(0.5)
    blinkFadeOut:SetOrder(1)
    local blinkFadeIn = blinkGroup:CreateAnimation("Alpha")
    blinkFadeIn:SetFromAlpha(0.2)
    blinkFadeIn:SetToAlpha(1)
    blinkFadeIn:SetDuration(0.5)
    blinkFadeIn:SetOrder(2)

    local function StartWhisperBlink()
        if not blinkGroup:IsPlaying() then
            whisperBtn.icon:SetVertexColor(1, 0.8, 0, 1)
            blinkGroup:Play()
        end
        -- Force header visible
        ShowHeader()
    end

    local function StopWhisperBlink()
        if blinkGroup:IsPlaying() then
            blinkGroup:Stop()
            whisperBtn.icon:SetVertexColor(0.7, 0.7, 0.7, 0.9)
            whisperBtn:SetAlpha(1)
        end
    end

    ns.StartWhisperBlink = StartWhisperBlink
    ns.StopWhisperBlink = StopWhisperBlink

    whisperBtn:SetScript("OnClick", function()
        if ns.whisperFrame then
            if ns.whisperFrame:IsShown() then
                FCF_SelectDockFrame(ChatFrame1)
            else
                FCF_SelectDockFrame(ns.whisperFrame)
                StopWhisperBlink()
            end
        end
    end)
    whisperBtn:HookScript("OnClick", function() CloseDropdown() end)

    -------------------------------------------------------------------
    -- Center: Current tab name
    -------------------------------------------------------------------
    local tabLabel = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tabLabel:SetPoint("CENTER", header, "CENTER", 0, 0)
    tabLabel:SetTextColor(0.6, 0.45, 0.0, 0.8)
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
        tabLabel:SetTextColor(1, 0.8, 0, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Right-click for options", 0.7, 0.7, 0.7)
        GameTooltip:Show()
        if chatHeader then chatHeader:SetAlpha(1) end
    end)
    tabLabelBtn:SetScript("OnLeave", function(self)
        tabLabel:SetTextColor(0.6, 0.45, 0.0, 0.8)
        GameTooltip:Hide()
    end)

    -- Size the button to match the label text width
    local function UpdateTabLabelBtnWidth()
        tabLabelBtn:SetWidth(math.max(tabLabel:GetStringWidth() + 16, 40))
    end
    UpdateTabLabelBtnWidth()

    -- Highlight active icon based on selected frame
    local ICON_ACTIVE = {1, 1, 1, 1}
    local ICON_INACTIVE = {0.7, 0.7, 0.7, 0.9}

    local function UpdateIconHighlights(cf)
        local isCombat = (cf == ChatFrame2)
        local isWhisper = (ns.whisperFrame and cf == ns.whisperFrame)
        local isGeneral = (not isCombat and not isWhisper)

        combatBtn.icon:SetVertexColor(unpack(isCombat and ICON_ACTIVE or ICON_INACTIVE))
        -- Only update whisper icon color if not blinking
        if whisperBtn:IsShown() and not (ns.StartWhisperBlink and blinkGroup:IsPlaying()) then
            whisperBtn.icon:SetVertexColor(unpack(isWhisper and ICON_ACTIVE or ICON_INACTIVE))
        end
        tabBtn.icon:SetVertexColor(unpack(isGeneral and ICON_ACTIVE or ICON_INACTIVE))
    end

    -- Override OnLeave to respect active state
    tabBtn:HookScript("OnLeave", function()
        local sel = SELECTED_DOCK_FRAME or FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame()
        local isActive = sel and sel ~= ChatFrame2 and sel ~= ns.whisperFrame
        if isActive then tabBtn.icon:SetVertexColor(unpack(ICON_ACTIVE)) end
    end)
    combatBtn:HookScript("OnLeave", function()
        local sel = SELECTED_DOCK_FRAME or FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame()
        if sel == ChatFrame2 then combatBtn.icon:SetVertexColor(unpack(ICON_ACTIVE)) end
    end)
    whisperBtn:HookScript("OnLeave", function()
        local sel = SELECTED_DOCK_FRAME or FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame()
        if ns.whisperFrame and sel == ns.whisperFrame and not blinkGroup:IsPlaying() then
            whisperBtn.icon:SetVertexColor(unpack(ICON_ACTIVE))
        end
    end)

    -- Update label and icon highlights when tabs switch
    hooksecurefunc("FCF_SelectDockFrame", function(cf)
        if not cf then return end
        for i = 1, NUM_CHAT_WINDOWS do
            if _G["ChatFrame" .. i] == cf then
                tabLabel:SetText(GetChatTabName(i))
                UpdateTabLabelBtnWidth()
                break
            end
        end
        UpdateIconHighlights(cf)
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
    -- Right side: Chat Channels icon
    -------------------------------------------------------------------
    local channelsBtn = CreateIconButton(header, ASSET_PATH .. "voice.png", ICON_SIZE - 1, "Chat Channels")
    channelsBtn:SetPoint("RIGHT", settingsBtn, "LEFT", -6, 0)

    channelsBtn:SetScript("OnClick", function()
        ToggleChannelFrame()
        CloseDropdown()
    end)

    -------------------------------------------------------------------
    -- Right side: Chat Type (emote) icon
    -------------------------------------------------------------------
    local chatTypeBtn = CreateIconButton(header, ASSET_PATH .. "chat.png", ICON_SIZE - 1, "Chat Type")
    chatTypeBtn:SetPoint("RIGHT", channelsBtn, "LEFT", -6, 0)

    -------------------------------------------------------------------
    -- Right side: History icon
    -------------------------------------------------------------------
    local historyBtn = CreateIconButton(header, ASSET_PATH .. "history.png", ICON_SIZE - 1, "History")
    historyBtn:SetPoint("RIGHT", chatTypeBtn, "LEFT", -6, 0)
    ns.historyBtn = historyBtn

    historyBtn:SetScript("OnClick", function()
        ns.ToggleHistory()
        CloseDropdown()
    end)

    if GudaChatDB and not GudaChatDB.historyEnabled then
        historyBtn:Hide()
    end

    local chatTypeDropdown = CreateFrame("Frame", "GudaChatTypeDropdown", chatTypeBtn, "BackdropTemplate")
    chatTypeDropdown:SetFrameStrata("TOOLTIP")
    chatTypeDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    chatTypeDropdown:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    chatTypeDropdown:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
    chatTypeDropdown:Hide()

    -- Emote submenu
    local emoteSubMenu = CreateFrame("Frame", "GudaChatEmoteSubMenu", chatTypeDropdown, "BackdropTemplate")
    emoteSubMenu:SetFrameStrata("TOOLTIP")
    emoteSubMenu:SetFrameLevel(chatTypeDropdown:GetFrameLevel() + 1)
    emoteSubMenu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    emoteSubMenu:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    emoteSubMenu:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
    emoteSubMenu:Hide()

    local emoteList = {
        { label = "Wave",     cmd = "/wave" },
        { label = "Dance",    cmd = "/dance" },
        { label = "Bow",      cmd = "/bow" },
        { label = "Cheer",    cmd = "/cheer" },
        { label = "Clap",     cmd = "/clap" },
        { label = "Cry",      cmd = "/cry" },
        { label = "Flex",     cmd = "/flex" },
        { label = "Goodbye",  cmd = "/goodbye" },
        { label = "Hello",    cmd = "/hello" },
        { label = "Kiss",     cmd = "/kiss" },
        { label = "Laugh",    cmd = "/laugh" },
        { label = "No",       cmd = "/no" },
        { label = "Point",    cmd = "/point" },
        { label = "Rude",     cmd = "/rude" },
        { label = "Salute",   cmd = "/salute" },
        { label = "Shy",      cmd = "/shy" },
        { label = "Sit",      cmd = "/sit" },
        { label = "Sleep",    cmd = "/sleep" },
        { label = "Smile",    cmd = "/smile" },
        { label = "Thank",    cmd = "/thank" },
        { label = "Yes",      cmd = "/yes" },
        { label = "Angry",    cmd = "/angry" },
        { label = "Beg",      cmd = "/beg" },
        { label = "Applaud",  cmd = "/applaud" },
    }

    local emYOff = -4
    local emMaxW = 60
    for _, entry in ipairs(emoteList) do
        local mb = CreateFrame("Button", nil, emoteSubMenu)
        mb:SetHeight(20)
        mb:SetPoint("TOPLEFT", emoteSubMenu, "TOPLEFT", 4, emYOff)
        mb:SetPoint("TOPRIGHT", emoteSubMenu, "TOPRIGHT", -4, emYOff)

        local labelText = mb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        labelText:SetPoint("LEFT", mb, "LEFT", 6, 0)
        labelText:SetText(entry.label)
        labelText:SetTextColor(0.8, 0.8, 0.8, 1)

        local cmdText = mb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cmdText:SetPoint("RIGHT", mb, "RIGHT", -6, 0)
        cmdText:SetText(entry.cmd)
        cmdText:SetTextColor(0.5, 0.5, 0.5, 1)

        mb:SetScript("OnEnter", function()
            labelText:SetTextColor(1, 0.8, 0, 1)
            cmdText:SetTextColor(0.8, 0.6, 0, 1)
        end)
        mb:SetScript("OnLeave", function()
            labelText:SetTextColor(0.8, 0.8, 0.8, 1)
            cmdText:SetTextColor(0.5, 0.5, 0.5, 1)
        end)

        local slash = entry.cmd
        mb:SetScript("OnClick", function()
            DoEmote(slash:sub(2):upper())
            emoteSubMenu:Hide()
            chatTypeDropdown:Hide()
        end)

        local tw = labelText:GetStringWidth() + cmdText:GetStringWidth() + 32
        if tw > emMaxW then emMaxW = tw end
        emYOff = emYOff - 20
    end
    emoteSubMenu:SetSize(emMaxW + 8, math.abs(emYOff) + 4)

    -- Main chat type entries
    local chatTypeEntries = {
        { label = "Say",          cmd = "/s" },
        { label = "Party Chat",   cmd = "/p" },
        { label = "Raid",         cmd = "/raid" },
        { label = "Battleground", cmd = "/bg" },
        { label = "Guild Chat",   cmd = "/g" },
        { label = "Yell",         cmd = "/y" },
        { label = "Whisper",      cmd = "/w" },
        { label = "Emote",        cmd = "/e",  hasArrow = true },
        { label = "Reply",        cmd = "/r" },
    }

    local ctYOff = -4
    local ctMaxW = 60

    for _, entry in ipairs(chatTypeEntries) do
        local mb = CreateFrame("Button", nil, chatTypeDropdown)
        mb:SetHeight(20)
        mb:SetPoint("TOPLEFT", chatTypeDropdown, "TOPLEFT", 4, ctYOff)
        mb:SetPoint("TOPRIGHT", chatTypeDropdown, "TOPRIGHT", -4, ctYOff)

        local labelText = mb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        labelText:SetPoint("LEFT", mb, "LEFT", 6, 0)
        labelText:SetText(entry.label)
        labelText:SetTextColor(0.8, 0.8, 0.8, 1)

        local cmdText = mb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cmdText:SetPoint("RIGHT", mb, "RIGHT", -6, 0)
        cmdText:SetTextColor(0.5, 0.5, 0.5, 1)

        if entry.hasArrow then
            cmdText:SetText(">")
        else
            cmdText:SetText(entry.cmd)
        end

        mb:SetScript("OnEnter", function()
            labelText:SetTextColor(1, 0.8, 0, 1)
            cmdText:SetTextColor(0.8, 0.6, 0, 1)
            if entry.hasArrow then
                emoteSubMenu:ClearAllPoints()
                emoteSubMenu:SetPoint("BOTTOMRIGHT", chatTypeDropdown, "BOTTOMLEFT", -2, 0)
                emoteSubMenu:Show()
            else
                emoteSubMenu:Hide()
            end
        end)
        mb:SetScript("OnLeave", function()
            labelText:SetTextColor(0.8, 0.8, 0.8, 1)
            cmdText:SetTextColor(0.5, 0.5, 0.5, 1)
        end)

        local slash = entry.cmd
        mb:SetScript("OnClick", function()
            ChatFrame_OpenChat(slash .. " ", ChatFrame1)
            chatTypeDropdown:Hide()
            emoteSubMenu:Hide()
        end)

        local tw = labelText:GetStringWidth() + cmdText:GetStringWidth() + 32
        if tw > ctMaxW then ctMaxW = tw end
        ctYOff = ctYOff - 20
    end

    chatTypeDropdown:SetSize(ctMaxW + 8, math.abs(ctYOff) + 4)

    chatTypeBtn:SetScript("OnClick", function(self)
        if chatTypeDropdown:IsShown() then
            chatTypeDropdown:Hide()
            emoteSubMenu:Hide()
        else
            chatTypeDropdown:ClearAllPoints()
            chatTypeDropdown:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 4, 2)
            chatTypeDropdown:Show()
        end
        CloseDropdown()
    end)

    local ctCloser = CreateFrame("Frame", nil, chatTypeDropdown)
    ctCloser:SetScript("OnUpdate", function()
        if chatTypeDropdown:IsShown()
            and not chatTypeDropdown:IsMouseOver()
            and not chatTypeBtn:IsMouseOver()
            and not (emoteSubMenu:IsShown() and emoteSubMenu:IsMouseOver()) then
            if IsMouseButtonDown("LeftButton") then
                chatTypeDropdown:Hide()
                emoteSubMenu:Hide()
            end
        end
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
                combatSubTabs:SetAlpha(header:GetAlpha())
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

StaticPopupDialogs["GUDACHAT_CLEAR_HISTORY"] = {
    text = "Are you sure you want to clear all chat history?",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function()
        if GudaChatDB and GudaChatDB.history then
            for k in pairs(GudaChatDB.history) do
                wipe(GudaChatDB.history[k])
            end
        end
        if historyFrame and historyFrame.RefreshHistory then
            historyFrame:RefreshHistory()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function CreateSettingsFrame()
    local f = CreateFrame("Frame", "GudaChatSettingsPopup", UIParent, "ButtonFrameTemplate")
    f:SetSize(340, 460)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
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

    -------------------------------------------------------------------
    -- Tabs (Blizzard style)
    -------------------------------------------------------------------
    local tabTemplate
    if DoesTemplateExist and DoesTemplateExist("PanelTopTabButtonTemplate") then
        tabTemplate = "PanelTopTabButtonTemplate"
    else
        tabTemplate = "TabButtonTemplate"
    end

    local tabDefs = { "General", "Messages", "History" }
    local tabPanels = {}
    local tabs = {}

    for i, label in ipairs(tabDefs) do
        local tab = CreateFrame("Button", "GudaChatSettingsPopupTab" .. i, f, tabTemplate)
        if i == 1 then
            tab:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -24)
        else
            tab:SetPoint("TOPLEFT", tabs[i - 1], "TOPRIGHT", 4, 0)
        end
        tab:SetText(label)
        tab:SetID(i)
        tab:SetScript("OnShow", function(self)
            PanelTemplates_TabResize(self, 8, nil, 36)
            PanelTemplates_DeselectTab(self)
        end)
        tabs[i] = tab
    end

    PanelTemplates_SetNumTabs(f, #tabDefs)

    -- Create tab content panels
    for i = 1, #tabDefs do
        local panel = CreateFrame("Frame", nil, f)
        panel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -60)
        panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
        panel:Hide()
        tabPanels[i] = panel
    end

    local function SelectSettingsTab(id)
        PanelTemplates_SetTab(f, id)
        for i, panel in ipairs(tabPanels) do
            if i == id then panel:Show() else panel:Hide() end
        end
    end

    for i, tab in ipairs(tabs) do
        tab:SetScript("OnClick", function() SelectSettingsTab(i) end)
    end

    -------------------------------------------------------------------
    -- Helper: build controls in a panel
    -------------------------------------------------------------------
    local function BuildPanel(panel)
        local yOff = 0
        local ctrls = {}
        local function Add(widget)
            widget:SetParent(panel)
            widget:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -yOff)
            widget:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -yOff)
            yOff = yOff + widget:GetHeight() + 8
            tinsert(ctrls, widget)
        end
        return Add, ctrls
    end

    -------------------------------------------------------------------
    -- Tab 1: General
    -------------------------------------------------------------------
    do
        local Add = BuildPanel(tabPanels[1])

        Add(CreateSeparator(tabPanels[1], "Chat Window"))

        Add(CreateCheckbox(tabPanels[1], "Lock chat position", GudaChatDB.locked, function(checked)
            GudaChatDB.locked = checked
            ApplyLockState()
        end))

        Add(CreateCheckbox(tabPanels[1], "Disable message fading", not GudaChatDB.fading, function(checked)
            GudaChatDB.fading = not checked
            ChatFrame1:SetFading(GudaChatDB.fading)
        end))

        Add(CreateCheckbox(tabPanels[1], "Hide scrollbar", GudaChatDB.hideScrollbar, function(checked)
            GudaChatDB.hideScrollbar = checked
            for i = 1, NUM_CHAT_WINDOWS do
                local cf = _G["ChatFrame" .. i]
                if cf and cf.gudaScrollbar then
                    if checked then
                        cf.gudaScrollbar:Hide()
                    else
                        cf.gudaScrollbar:Show()
                        cf.gudaScrollbar:SetAlpha(0)
                    end
                end
            end
        end))

        local currentTimestamp = GetCVar("showTimestamps") or "none"
        Add(CreateDropdown(tabPanels[1], "Timestamps", TIMESTAMP_OPTIONS, currentTimestamp, function(value)
            SetCVar("showTimestamps", value)
        end))

        Add(CreateSeparator(tabPanels[1], "Input Bar"))

        Add(CreateCheckbox(tabPanels[1], "Show input bar on top", GudaChatDB.inputPosition == "top", function(checked)
            GudaChatDB.inputPosition = checked and "top" or "bottom"
            for i = 1, NUM_CHAT_WINDOWS do
                PositionEditBox(_G["ChatFrame" .. i], i, GudaChatDB.inputPosition)
            end
            ApplyChatMargins()
        end))

        Add(CreateSeparator(tabPanels[1], "Tabs"))

        Add(CreateCheckbox(tabPanels[1], "Whisper tab", GudaChatDB.whisperTab, function(checked)
            GudaChatDB.whisperTab = checked
            if checked then
                SetupWhisperFrame()
                if ns.whisperBtn then ns.whisperBtn:Show() end
            else
                if ns.whisperFrame and ns.whisperFrame:IsShown() then
                    FCF_SelectDockFrame(ChatFrame1)
                end
                if ns.whisperBtn then ns.whisperBtn:Hide() end
            end
        end))
    end

    -------------------------------------------------------------------
    -- Tab 2: Messages
    -------------------------------------------------------------------
    do
        local Add = BuildPanel(tabPanels[2])

        Add(CreateSeparator(tabPanels[2], "Messages"))

        Add(CreateCheckbox(tabPanels[2], "Class colored names", GudaChatDB.classColors, function(checked)
            GudaChatDB.classColors = checked
            ApplyClassColors()
        end))

        Add(CreateCheckbox(tabPanels[2], "Show player level", GudaChatDB.showLevel, function(checked)
            GudaChatDB.showLevel = checked
        end))

        Add(CreateCheckbox(tabPanels[2], "Copyable links", GudaChatDB.copyLinks, function(checked)
            GudaChatDB.copyLinks = checked
        end))

        Add(CreateSeparator(tabPanels[2], "Emojis"))

        Add(CreateCheckbox(tabPanels[2], "Enable emojis", GudaChatDB.emojis, function(checked)
            GudaChatDB.emojis = checked
            for i = 1, NUM_CHAT_WINDOWS do
                local eb = _G["ChatFrame" .. i .. "EditBox"]
                if eb and eb.emojiBtn then
                    if checked then eb.emojiBtn:Show() else eb.emojiBtn:Hide() end
                end
            end
            if not checked and emojiPickerFrame then emojiPickerFrame:Hide() end
        end))

        Add(CreateSlider(tabPanels[2], "Emoji size", 10, 32, 1, GudaChatDB.emojiSize or DEFAULT_EMOJI_SIZE, function(value)
            GudaChatDB.emojiSize = value
        end))
    end

    -------------------------------------------------------------------
    -- Tab 3: History
    -------------------------------------------------------------------
    do
        local Add = BuildPanel(tabPanels[3])

        Add(CreateSeparator(tabPanels[3], "History"))

        Add(CreateCheckbox(tabPanels[3], "Enable history", GudaChatDB.historyEnabled ~= false, function(checked)
            GudaChatDB.historyEnabled = checked
            if ns.historyBtn then
                if checked then
                    ns.historyBtn:Show()
                else
                    ns.historyBtn:Hide()
                end
            end
        end))

        Add(CreateSlider(tabPanels[3], "Max messages", 100, 2000, 100, GudaChatDB.historyMax or 500, function(value)
            GudaChatDB.historyMax = value
        end))

        local clearBtn = CreateFrame("Button", nil, tabPanels[3], "UIPanelButtonTemplate")
        clearBtn:SetSize(120, 24)
        clearBtn:SetText("Clear History")
        local clearContainer = CreateFrame("Frame", nil, tabPanels[3])
        clearContainer:SetHeight(30)
        clearBtn:SetParent(clearContainer)
        clearBtn:SetPoint("LEFT", clearContainer, "LEFT", 0, 0)
        clearBtn:SetScript("OnClick", function()
            StaticPopup_Show("GUDACHAT_CLEAR_HISTORY")
        end)
        Add(clearContainer)
    end

    -- Default to General tab
    SelectSettingsTab(1)

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
        PanelTemplates_SetTab(settingsFrame, 1)
    end
end

ns.ToggleSettings = ToggleSettings

---------------------------------------------------------------------------
-- Chat History
---------------------------------------------------------------------------

local historyFrame

local function CreateHistoryFrame()
    local f = CreateFrame("Frame", "GudaChatHistoryPopup", UIParent, "ButtonFrameTemplate")
    f:SetSize(500, 500)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)

    tinsert(UISpecialFrames, "GudaChatHistoryPopup")

    ButtonFrameTemplate_HidePortrait(f)
    ButtonFrameTemplate_HideButtonBar(f)
    if f.Inset then f.Inset:Hide() end

    f:SetTitle("GudaChat History")

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

    -- Content area (below channel tabs)
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -60)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 16)

    -------------------------------------------------------------------
    -- Channel filter tabs (Blizzard tab style)
    -------------------------------------------------------------------
    local selectedFilter = "All"

    local tabTemplate
    if DoesTemplateExist and DoesTemplateExist("PanelTopTabButtonTemplate") then
        tabTemplate = "PanelTopTabButtonTemplate"
    else
        tabTemplate = "TabButtonTemplate"
    end

    local channelTabDefs = {
        { key = "All",      short = "All" },
        { key = "Say",      short = "S" },
        { key = "Yell",     short = "Y" },
        { key = "Guild",    short = "G" },
        { key = "Officer",  short = "O" },
        { key = "Whisper",  short = "W" },
        { key = "Party",    short = "P" },
        { key = "Raid",     short = "R" },
        { key = "Instance", short = "I" },
    }

    local channelTabs = {}
    for i, def in ipairs(channelTabDefs) do
        local tab = CreateFrame("Button", "GudaChatHistoryPopupTab" .. i, f, tabTemplate)
        if i == 1 then
            tab:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -24)
        else
            tab:SetPoint("TOPLEFT", channelTabs[i - 1], "TOPRIGHT", 4, 0)
        end
        tab:SetText(def.short)
        tab:SetID(i)
        tab:SetScript("OnShow", function(self)
            PanelTemplates_TabResize(self, 4, nil, 10)
            PanelTemplates_DeselectTab(self)
        end)

        tab:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(def.key, 1, 1, 1)
            GameTooltip:Show()
        end)
        tab:HookScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        channelTabs[i] = tab
    end

    PanelTemplates_SetNumTabs(f, #channelTabDefs)

    local function SelectChannelTab(id)
        PanelTemplates_SetTab(f, id)
        selectedFilter = channelTabDefs[id].key
        if f.RefreshHistory then f:RefreshHistory() end
    end

    for i, tab in ipairs(channelTabs) do
        tab:SetScript("OnClick", function() SelectChannelTab(i) end)
    end

    -- Search box
    local searchBox = CreateFrame("EditBox", nil, content, "BackdropTemplate")
    searchBox:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    searchBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -50, 0)
    searchBox:SetHeight(22)
    searchBox:SetFontObject(GameFontHighlight)
    searchBox:SetAutoFocus(false)
    searchBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    searchBox:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    searchBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
    searchBox:SetTextInsets(20, 20, 0, 0)

    local searchIcon = searchBox:CreateTexture(nil, "OVERLAY")
    searchIcon:SetSize(12, 12)
    searchIcon:SetPoint("LEFT", searchBox, "LEFT", 5, 0)
    searchIcon:SetTexture(ASSET_PATH .. "search.png")
    searchIcon:SetVertexColor(0.6, 0.6, 0.6)

    -- Clear button inside search box
    local clearSearchBtn = CreateFrame("Button", nil, searchBox)
    clearSearchBtn:SetSize(12, 12)
    clearSearchBtn:SetPoint("RIGHT", searchBox, "RIGHT", -4, 0)
    clearSearchBtn:SetNormalTexture(ASSET_PATH .. "close.png")
    clearSearchBtn:GetNormalTexture():SetVertexColor(0.6, 0.6, 0.6)
    clearSearchBtn:SetScript("OnEnter", function(self)
        self:GetNormalTexture():SetVertexColor(1, 1, 1)
    end)
    clearSearchBtn:SetScript("OnLeave", function(self)
        self:GetNormalTexture():SetVertexColor(0.6, 0.6, 0.6)
    end)
    clearSearchBtn:Hide()

    local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", searchBox, "LEFT", 22, 0)
    placeholder:SetText("Search...")
    searchBox:SetScript("OnEditFocusGained", function(self)
        placeholder:Hide()
        self:SetBackdropBorderColor(0.8, 0.6, 0.0, 0.8)
        searchIcon:SetVertexColor(1, 1, 1)
    end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then placeholder:Show() end
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
        searchIcon:SetVertexColor(0.6, 0.6, 0.6)
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Click anywhere on the frame clears search focus
    f:HookScript("OnMouseDown", function()
        searchBox:ClearFocus()
    end)
    content:SetScript("OnMouseDown", function()
        searchBox:ClearFocus()
    end)

    -- Copy button (Blizzard style, red background)
    local copyBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    copyBtn:SetSize(50, 22)
    copyBtn:SetPoint("LEFT", searchBox, "RIGHT", 4, 0)
    copyBtn:SetText("Copy")
    local copyNt = copyBtn:GetNormalTexture()
    if copyNt then copyNt:SetVertexColor(0.6, 0.1, 0.1) end
    local copyPt = copyBtn:GetPushedTexture()
    if copyPt then copyPt:SetVertexColor(0.5, 0.05, 0.05) end

    -- ScrollingMessageFrame for colored display
    local msgFrame = CreateFrame("ScrollingMessageFrame", "GudaChatHistoryMsgFrame", content)
    msgFrame:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -4)
    msgFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    msgFrame:SetFontObject(GameFontNormal)
    msgFrame:SetJustifyH("LEFT")
    msgFrame:SetFading(false)
    msgFrame:SetMaxLines(2000)
    msgFrame:SetIndentedWordWrap(true)
    msgFrame:EnableMouseWheel(true)
    msgFrame:SetHyperlinksEnabled(true)
    msgFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            self:ScrollUp()
            self:ScrollUp()
            self:ScrollUp()
        else
            self:ScrollDown()
            self:ScrollDown()
            self:ScrollDown()
        end
    end)

    -- Scrollbar for history
    local histSlider = CreateFrame("Slider", nil, msgFrame, "BackdropTemplate")
    histSlider:SetWidth(6)
    histSlider:SetPoint("TOPRIGHT", msgFrame, "TOPRIGHT", -2, -2)
    histSlider:SetPoint("BOTTOMRIGHT", msgFrame, "BOTTOMRIGHT", -2, 2)
    histSlider:SetOrientation("VERTICAL")
    histSlider:SetMinMaxValues(0, 1)
    histSlider:SetValue(0)
    histSlider:SetValueStep(1)
    histSlider:SetObeyStepOnDrag(true)
    histSlider:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    histSlider:SetBackdropColor(0, 0, 0, 0.3)

    local histThumb = histSlider:CreateTexture(nil, "OVERLAY")
    histThumb:SetTexture("Interface\\Buttons\\WHITE8x8")
    histThumb:SetVertexColor(1, 1, 1, 0.4)
    histThumb:SetSize(6, 30)
    histSlider:SetThumbTexture(histThumb)

    histSlider:SetScript("OnEnter", function()
        histThumb:SetVertexColor(1, 1, 1, 0.7)
    end)
    histSlider:SetScript("OnLeave", function()
        histThumb:SetVertexColor(1, 1, 1, 0.4)
    end)

    histSlider:SetScript("OnValueChanged", function(self, value)
        local maxScroll = msgFrame:GetMaxScrollRange()
        local offset = maxScroll - value
        if offset >= 0 then
            msgFrame:SetScrollOffset(offset)
        end
    end)

    local function SyncHistSlider()
        local maxScroll = msgFrame:GetMaxScrollRange()
        histSlider:SetMinMaxValues(0, maxScroll)
        local offset = msgFrame:GetScrollOffset()
        histSlider:SetValue(maxScroll - offset)
    end

    hooksecurefunc(msgFrame, "SetScrollOffset", SyncHistSlider)

    local histTicker = CreateFrame("Frame")
    histTicker:SetScript("OnUpdate", function(self, dt)
        self.elapsed = (self.elapsed or 0) + dt
        if self.elapsed >= 0.2 then
            self.elapsed = 0
            SyncHistSlider()
        end
    end)

    histSlider:EnableMouseWheel(true)
    histSlider:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            msgFrame:ScrollUp()
        else
            msgFrame:ScrollDown()
        end
        SyncHistSlider()
    end)

    -- Gather and format entries
    local function GatherEntries()
        local results = {}
        local historyDB = GudaChatDB and GudaChatDB.history or {}
        local searchText = searchBox:GetText():lower()

        if selectedFilter == "All" then
            for _, channelKey in ipairs(HISTORY_FILTER_KEYS) do
                local bucket = historyDB[channelKey]
                if bucket then
                    for _, entry in ipairs(bucket) do
                        local matchesSearch = (searchText == "") or
                            entry.message:lower():find(searchText, 1, true) or
                            entry.sender:lower():find(searchText, 1, true)
                        if matchesSearch then
                            tinsert(results, entry)
                        end
                    end
                end
            end
            table.sort(results, function(a, b) return a.time < b.time end)
        else
            local bucket = historyDB[selectedFilter]
            if bucket then
                for _, entry in ipairs(bucket) do
                    local matchesSearch = (searchText == "") or
                        entry.message:lower():find(searchText, 1, true) or
                        entry.sender:lower():find(searchText, 1, true)
                    if matchesSearch then
                        tinsert(results, entry)
                    end
                end
            end
        end
        return results
    end

    local function FormatColoredEntry(entry)
        local timeStr = date("%H:%M", entry.time)
        local senderName = entry.sender:match("^([^%-]+)") or entry.sender
        local chatType = CHANNEL_TO_CHATTYPE[entry.channel]
        local info = chatType and ChatTypeInfo[chatType]
        local r, g, b = 0.6, 0.6, 0.6
        if info then r, g, b = info.r, info.g, info.b end
        local chanColor = string.format("%02x%02x%02x", r * 255, g * 255, b * 255)

        local nameLink
        if GudaChatDB.classColors and entry.class and RAID_CLASS_COLORS[entry.class] then
            local cc = RAID_CLASS_COLORS[entry.class]
            nameLink = string.format("|cff%02x%02x%02x|Hplayer:%s|h[%s]|h|r",
                cc.r*255, cc.g*255, cc.b*255, entry.sender, senderName)
        else
            nameLink = string.format("|Hplayer:%s|h[%s]|h", entry.sender, senderName)
        end

        local levelStr = ""
        if entry.level then
            local lr, lg, lb = GetLevelDifficultyColor(entry.level)
            levelStr = string.format("|cff%02x%02x%02x[%d]|r ", lr*255, lg*255, lb*255, entry.level)
        end

        local body
        if entry.channel == "Whisper" and entry.outgoing then
            body = string.format("To %s: %s%s", nameLink, levelStr, entry.message)
        elseif entry.channel == "Whisper" then
            body = string.format("%s whispers: %s%s", nameLink, levelStr, entry.message)
        else
            local verb = REPLAY_CHANNEL_FORMATS[entry.channel]
            if verb then
                body = string.format("%s %s: %s%s", nameLink, verb, levelStr, entry.message)
            else
                body = string.format("|cff%s[%s]|r %s: %s%s", chanColor, entry.channel, nameLink, levelStr, entry.message)
            end
        end

        return string.format("|cff808080%s|r |cff%s%s|r", timeStr, chanColor, body)
    end

    local function FormatPlainEntry(entry)
        local timeStr = date("%H:%M", entry.time)
        local senderName = entry.sender:match("^([^%-]+)") or entry.sender
        local levelStr = entry.level and string.format("[%d] ", entry.level) or ""

        if entry.channel == "Whisper" and entry.outgoing then
            return string.format("%s To [%s]: %s%s", timeStr, senderName, levelStr, entry.message)
        elseif entry.channel == "Whisper" then
            return string.format("%s [%s] whispers: %s%s", timeStr, senderName, levelStr, entry.message)
        else
            local verb = REPLAY_CHANNEL_FORMATS[entry.channel]
            if verb then
                return string.format("%s [%s] %s: %s%s", timeStr, senderName, verb, levelStr, entry.message)
            else
                return string.format("%s [%s] [%s]: %s%s", timeStr, entry.channel, senderName, levelStr, entry.message)
            end
        end
    end

    local lastEntries = {}

    function f:RefreshHistory()
        msgFrame:Clear()
        local entries = GatherEntries()
        lastEntries = entries
        -- AddMessage in chronological order (oldest first, newest at bottom)
        for _, entry in ipairs(entries) do
            msgFrame:AddMessage(FormatColoredEntry(entry))
        end
        msgFrame:ScrollToBottom()
    end

    -- Copy window: EditBox popup for selecting/copying plain text
    copyBtn:SetScript("OnClick", function()
        if f.copyFrame and f.copyFrame:IsShown() then
            f.copyFrame:Hide()
            return
        end
        if #lastEntries == 0 then return end
        local lines = {}
        for _, entry in ipairs(lastEntries) do
            tinsert(lines, FormatPlainEntry(entry))
        end
        local plainText = table.concat(lines, "\n")

        -- Reuse the existing copy popup pattern
        if not f.copyFrame then
            local cf = CreateFrame("Frame", "GudaChatHistoryCopyPopup", UIParent, "BackdropTemplate")
            cf:SetSize(480, 300)
            cf:SetPoint("CENTER")
            cf:SetFrameStrata("TOOLTIP")
            cf:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            cf:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
            cf:SetBackdropBorderColor(0.8, 0.6, 0.0, 0.8)
            cf:EnableMouse(true)
            cf:SetMovable(true)
            cf:RegisterForDrag("LeftButton")
            cf:SetScript("OnDragStart", cf.StartMoving)
            cf:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                self:SetUserPlaced(false)
            end)
            tinsert(UISpecialFrames, "GudaChatHistoryCopyPopup")

            local closeBtn = CreateFrame("Button", nil, cf)
            closeBtn:SetSize(12, 12)
            closeBtn:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -4, -4)
            closeBtn:SetNormalTexture(ASSET_PATH .. "close.png")
            closeBtn:GetNormalTexture():SetVertexColor(0.6, 0.6, 0.6)
            closeBtn:SetScript("OnEnter", function(self)
                self:GetNormalTexture():SetVertexColor(1, 1, 1)
            end)
            closeBtn:SetScript("OnLeave", function(self)
                self:GetNormalTexture():SetVertexColor(0.6, 0.6, 0.6)
            end)
            closeBtn:SetScript("OnClick", function() cf:Hide() end)

            local label = cf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("TOPLEFT", cf, "TOPLEFT", 8, -6)
            label:SetText("Ctrl+C to copy. Escape to close.")
            label:SetTextColor(0.6, 0.6, 0.6)

            local scrollFrame = CreateFrame("ScrollFrame", "GudaChatHistoryCopyScroll", cf, "UIPanelScrollFrameTemplate")
            scrollFrame:SetPoint("TOPLEFT", cf, "TOPLEFT", 8, -22)
            scrollFrame:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -28, 8)

            local eb = CreateFrame("EditBox", nil, scrollFrame)
            eb:SetFontObject(GameFontHighlight)
            eb:SetMultiLine(true)
            eb:SetAutoFocus(false)
            eb:SetTextColor(0.9, 0.9, 0.9)
            eb:SetMaxLetters(0)
            eb:SetScript("OnEscapePressed", function() cf:Hide() end)
            eb:SetScript("OnEnter", function(self)
                scrollFrame:UpdateScrollChildRect()
                self:SetFocus()
            end)
            eb:SetScript("OnLeave", function(self)
                self:ClearFocus()
            end)
            eb:SetScript("OnCursorChanged", function(self, x, y, w, h)
                scrollFrame:SetVerticalScroll(-y)
            end)

            scrollFrame:SetScrollChild(eb)

            cf.editBox = eb
            cf.scrollFrame = scrollFrame
            f.copyFrame = cf
        end

        local eb = f.copyFrame.editBox
        eb:SetWidth(f.copyFrame.scrollFrame:GetWidth() or 440)
        eb:SetText("")
        eb:SetMaxLetters(0)
        for i = #lastEntries, 1, -1 do
            eb:SetCursorPosition(0)
            eb:Insert(FormatPlainEntry(lastEntries[i]) .. "\n")
        end
        -- Trim leading whitespace
        eb:SetText(eb:GetText():gsub("^[\n ]+", ""))
        f.copyFrame.scrollFrame:UpdateScrollChildRect()
        f.copyFrame:Show()
        eb:SetCursorPosition(0)
        eb:HighlightText()
        eb:SetFocus()
    end)

    clearSearchBtn:SetScript("OnClick", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
        placeholder:Show()
        clearSearchBtn:Hide()
        if f.RefreshHistory then f:RefreshHistory() end
    end)

    searchBox:SetScript("OnTextChanged", function(self, userInput)
        if self:GetText() ~= "" then
            clearSearchBtn:Show()
        else
            clearSearchBtn:Hide()
        end
        if userInput and f.RefreshHistory then f:RefreshHistory() end
    end)

    -------------------------------------------------------------------
    -- Initialize
    -------------------------------------------------------------------
    SelectChannelTab(1)

    f:SetScript("OnShow", function(self)
        SelectChannelTab(1)
    end)

    f:Hide()
    return f
end

local function ToggleHistory()
    if not historyFrame then
        historyFrame = CreateHistoryFrame()
    end
    if historyFrame:IsShown() then
        historyFrame:Hide()
    else
        historyFrame:Show()
    end
end

ns.ToggleHistory = ToggleHistory

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
        if GudaChatDB.whisperTab == nil then
            GudaChatDB.whisperTab = false
        end
        -- History: per-channel buckets
        if type(GudaChatDB.history) ~= "table" or GudaChatDB.history[1] ~= nil then
            -- Reset if old flat-array format or missing
            GudaChatDB.history = {}
        end
        GudaChatDB.historyMax = GudaChatDB.historyMax or 500
        if GudaChatDB.historyEnabled == nil then
            GudaChatDB.historyEnabled = true
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
                local cf = _G["ChatFrame" .. i]
                StripChatChrome(i)
                if cf and not cf.gudaScrollbar then
                    CreateScrollbar(cf)
                end
            end
            ApplyChatMargins()
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
        for i = 1, NUM_CHAT_WINDOWS do
            local cf = _G["ChatFrame" .. i]
            if cf then
                CreateScrollbar(cf)
                if GudaChatDB.hideScrollbar and cf.gudaScrollbar then
                    cf.gudaScrollbar:Hide()
                end
            end
        end
        if GudaChatDB.whisperTab then
            SetupWhisperFrame()
        end
        CreateChatHeader(ChatFrame1)
        ApplyLockState()
        ApplyChatMargins()

        -- Reapply clamp insets after Blizzard dock updates reset them
        if FCF_DockUpdate then
            hooksecurefunc("FCF_DockUpdate", ApplyChatMargins)
        end

        ReplayHistory()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffGudaChat|r loaded — type |cffffd200/gc|r for settings")
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
