local addonName, ns = ...

---------------------------------------------------------------------------
-- Emoji data
---------------------------------------------------------------------------

local EMOJI_DATA = {
    { plain = ":)",    pattern = ":%)",    file = "emoji_smile.png" },
    { plain = ":(",    pattern = ":%(",    file = "emoji_sad.png" },
    { plain = ":D",    pattern = ":D",     file = "emoji_grin.png" },
    { plain = ":P",    pattern = ":P",     file = "emoji_tongue.png" },
    { plain = ";)",    pattern = ";%)",    file = "emoji_wink.png" },
    { plain = ":O",    pattern = ":O",     file = "emoji_surprised.png" },
    { plain = "xD",    pattern = "xD",     file = "emoji_laugh.png" },
    { plain = "XD",    pattern = "XD",     file = "emoji_laugh.png", pickerHidden = true },
    { plain = ":'(",   pattern = ":'%(",   file = "emoji_cry.png" },
    { plain = ">:(",   pattern = ">:%(",   file = "emoji_angry.png" },
    { plain = "B)",    pattern = "B%)",    file = "emoji_cool.png" },
    { plain = "<3",    pattern = "<3",     file = "emoji_heart.png" },
    { plain = ":+1:",  pattern = ":%+1:",  file = "emoji_thumbsup.png" },
    { plain = ":-1:",  pattern = ":%-1:",  file = "emoji_thumbsdown.png" },
    { plain = ":fire:",    pattern = ":fire:",    file = "emoji_fire.png" },
    { plain = ":skull:",   pattern = ":skull:",   file = "emoji_skull.png" },
    { plain = ":poop:",    pattern = ":poop:",    file = "emoji_poop.png" },
    { plain = ":clown:",   pattern = ":clown:",   file = "emoji_clown.png" },
    { plain = ":nerd:",    pattern = ":nerd:",    file = "emoji_nerd.png" },
    { plain = ":eyeroll:", pattern = ":eyeroll:", file = "emoji_eyeroll.png" },
    { plain = ":thinking:",pattern = ":thinking:",file = "emoji_thinking.png" },
    { plain = "zzz",       pattern = "zzz",       file = "emoji_zzz.png" },
    { plain = ":star:",    pattern = ":star:",    file = "emoji_star.png" },
    { plain = ":moon:",    pattern = ":moon:",    file = "emoji_moon.png" },
    { plain = ":check:",   pattern = ":check:",   file = "emoji_check.png" },
    { plain = ":x:",       pattern = ":x:",       file = "emoji_x.png" },
    { plain = ":diamond:", pattern = ":diamond:", file = "emoji_diamond.png" },
    { plain = ":circle:",  pattern = ":circle:",  file = "emoji_circle.png" },
    { plain = ":triangle:",pattern = ":triangle:",file = "emoji_triangle.png" },
    { plain = ":square:",  pattern = ":square:",  file = "emoji_square.png" },
    { plain = ":cross:",   pattern = ":cross:",   file = "emoji_cross.png" },
    { plain = ":cat:",     pattern = ":cat:",     file = "emoji_cat.png" },
    { plain = ":cat_laugh:",pattern = ":cat_laugh:",file = "emoji_cat_laugh.png" },
    { plain = ":cat_heart:",pattern = ":cat_heart:",file = "emoji_cat_heart.png" },
    { plain = ":cat_cry:", pattern = ":cat_cry:", file = "emoji_cat_cry.png" },
    { plain = ":party:",   pattern = ":party:",   file = "emoji_party.png" },
    { plain = ":confetti:",pattern = ":confetti:",file = "emoji_confetti.png" },
    { plain = ":trophy:",  pattern = ":trophy:",  file = "emoji_trophy.png" },
    { plain = ":clap:",    pattern = ":clap:",    file = "emoji_clap.png" },
}
ns.EMOJI_DATA = EMOJI_DATA

---------------------------------------------------------------------------
-- Emoji Picker
---------------------------------------------------------------------------

local function CreateEmojiPicker()
    local COLS = 8
    local BTN_SIZE = 24
    local PADDING = 4
    local MARGIN = 8

    local pickerItems = {}
    for _, entry in ipairs(EMOJI_DATA) do
        if not entry.pickerHidden then
            tinsert(pickerItems, entry)
        end
    end

    local rows = math.ceil(#pickerItems / COLS)
    local width = MARGIN * 2 + COLS * BTN_SIZE + (COLS - 1) * PADDING
    local height = MARGIN * 2 + rows * BTN_SIZE + (rows - 1) * PADDING

    local f = CreateFrame("Frame", "GudaChatEmojiPicker", UIParent, "BackdropTemplate")
    f:SetSize(width, height)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:SetClampedToScreen(true)

    ns.ApplyDarkBackdrop(f, ns.COLOR_DARK_BG, { 0.3, 0.3, 0.3, 0.8 })

    for i, entry in ipairs(pickerItems) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)

        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(BTN_SIZE, BTN_SIZE)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", MARGIN + col * (BTN_SIZE + PADDING), -(MARGIN + row * (BTN_SIZE + PADDING)))

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("CENTER")
        tex:SetSize(BTN_SIZE - 4, BTN_SIZE - 4)
        tex:SetTexture(ns.ASSET_PATH .. entry.file)

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
    return f
end

function ns.ToggleEmojiPicker(editBox)
    local picker = _G["GudaChatEmojiPicker"] or CreateEmojiPicker()
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

---------------------------------------------------------------------------
-- Emoji text replacement filter
---------------------------------------------------------------------------

-- Split message into protected (hyperlinks, [bracketed]) and free segments
local function SplitProtected(msg)
    local parts = {}
    local pos = 1
    local len = #msg
    while pos <= len do
        -- WoW hyperlinks: |H...|h...|h or |T...|t or |c...|r
        local hStart = msg:find("|[HcT]", pos)
        -- Bracketed text: [...]
        local bStart = msg:find("%[", pos)
        local nextProtected = nil
        local nextEnd = nil
        if hStart and (not bStart or hStart <= bStart) then
            -- Find the matching closing sequence
            if msg:sub(hStart, hStart + 1) == "|H" then
                -- |H...|h[...]|h — find second |h
                local _, firstH = msg:find("|h", hStart + 2, true)
                if firstH then
                    local _, secondH = msg:find("|h", firstH + 1, true)
                    nextEnd = secondH or len
                else
                    nextEnd = len
                end
            elseif msg:sub(hStart, hStart + 1) == "|T" then
                local _, tEnd = msg:find("|t", hStart + 2, true)
                nextEnd = tEnd or len
            elseif msg:sub(hStart, hStart + 1) == "|c" then
                local _, rEnd = msg:find("|r", hStart + 2, true)
                nextEnd = rEnd or len
            end
            nextProtected = hStart
        elseif bStart then
            local bEnd = msg:find("%]", bStart + 1)
            nextProtected = bStart
            nextEnd = bEnd or len
        end

        if nextProtected and nextProtected >= pos then
            -- Free text before the protected segment
            if nextProtected > pos then
                tinsert(parts, { text = msg:sub(pos, nextProtected - 1), free = true })
            end
            tinsert(parts, { text = msg:sub(nextProtected, nextEnd), free = false })
            pos = nextEnd + 1
        else
            tinsert(parts, { text = msg:sub(pos), free = true })
            break
        end
    end
    return parts
end
ns.SplitProtected = SplitProtected

-- Codes are replaced longest first, so ">:(" is not eaten by ":(" and ":cat_laugh:" not by
-- a shorter code. The picker keeps EMOJI_DATA's own order.
local REPLACE_ORDER = {}
for index, entry in ipairs(EMOJI_DATA) do
    REPLACE_ORDER[index] = entry
end
do
    local position = {}
    for index, entry in ipairs(EMOJI_DATA) do
        position[entry] = index
    end
    table.sort(REPLACE_ORDER, function(a, b)
        if #a.plain ~= #b.plain then return #a.plain > #b.plain end
        return position[a] < position[b]
    end)
end

local function IsWordByte(text, pos)
    return pos >= 1 and text:sub(pos, pos):find("^%w") ~= nil
end

local function HasOpenParenBefore(text, pos)
    local depth = 0
    for paren in text:sub(1, pos - 1):gmatch("[()]") do
        depth = depth + (paren == "(" and 1 or -1)
    end
    return depth > 0
end

-- Replaces every stand-alone use of an emoji code. A code that starts or ends with a
-- letter or digit ("xD", "B)", "zzz") must not touch another letter or digit on that side,
-- so "maxDPS", "0xDEAD" and "Jazzz" stay text; "B)" also stays text when it closes an
-- open bracket, as in "(Plan B)".
local function ReplaceEmoji(text, plain, tex)
    local wordStart = plain:find("^%w") ~= nil
    local wordEnd = plain:find("%w$") ~= nil
    local closesBracket = wordStart and plain:sub(-1) == ")"
    local out, pos, count = {}, 1, 0
    while true do
        local first, last = text:find(plain, pos, true)
        if not first then break end
        local standalone = not (wordStart and IsWordByte(text, first - 1))
            and not (wordEnd and IsWordByte(text, last + 1))
            and not (closesBracket and HasOpenParenBefore(text, first))
        out[#out + 1] = text:sub(pos, first - 1)
        out[#out + 1] = standalone and tex or plain
        if standalone then count = count + 1 end
        pos = last + 1
    end
    if count == 0 then return text, 0 end
    out[#out + 1] = text:sub(pos)
    return table.concat(out), count
end
ns.ReplaceEmoji = ReplaceEmoji

-- Returns msg with every emoji code in its plain text replaced by the texture, or false
-- when it has none.
local function EmojifyMessage(msg, size)
    local parts = SplitProtected(msg)
    local changed = false
    for _, part in ipairs(parts) do
        if part.free then
            for _, entry in ipairs(REPLACE_ORDER) do
                if part.text:find(entry.plain, 1, true) then
                    local tex = "|T" .. ns.ASSET_PATH .. entry.file .. ":" .. size .. "|t"
                    local newText, count = ReplaceEmoji(part.text, entry.plain, tex)
                    if count > 0 then
                        part.text = newText
                        changed = true
                    end
                end
            end
        end
    end
    return changed and ns.JoinParts(parts) or false
end
ns.EmojifyMessage = EmojifyMessage

local emojiMemo = ns.NewLineMemo()

local function FilterAddEmojis(self, event, msg, ...)
    if not GudaChatDB or not GudaChatDB.emojis then return false end
    if not msg or ns.IsSecret(msg) then return false end

    local lineID = ns.PlainLineID(select(10, ...))
    local hit, output = emojiMemo:Get(lineID, msg)
    if not hit then
        output = EmojifyMessage(msg, GudaChatDB.emojiSize or ns.DEFAULT_EMOJI_SIZE)
        emojiMemo:Set(lineID, msg, output)
    end
    if output then
        return false, output, ...
    end
    return false
end

function ns.EnableEmojis()
    for _, channel in ipairs(ns.CHAT_MSG_CHANNELS) do
        ChatFrame_AddMessageEventFilter(channel, FilterAddEmojis)
    end
end
