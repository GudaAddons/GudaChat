local addonName, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Whisper icon, hover list, quick reply and whisper ring
--
-- On by default (GudaChatDB.whisperIcon.enabled). A themed icon shows how many PEOPLE
-- sent unread whispers this session; hovering lists them, clicking replies to the latest.
-- The "Whisper ring" key binding opens an OPie-style ring at the cursor while held
-- (release over a person to reply), and a quick tap replies to the latest. Received
-- whispers still show in chat as usual; this only adds a way to answer. The data lives
-- in the pure model of Core/WhisperModel.lua. Nothing runs per frame unless the ring
-- key is held. The reply box takes keyboard focus only when the player opens it.
---------------------------------------------------------------------------

local C = ns.Theme.C
local WHITE = "Interface\\Buttons\\WHITE8x8"
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local BATTLENET_ICON = "Interface\\FriendsFrame\\Battlenet-Battleneticon"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local ICON_SIZE = 32
local ICON_GLYPH_SIZE = 18
local BADGE_HEIGHT = 16
local DEFAULT_ICON_X, DEFAULT_ICON_Y = 4, 58
local LIST_WIDTH = 290
local LIST_HEADER_HEIGHT = 26
local LIST_ROW_HEIGHT = 36
local LIST_HIDE_DELAY = 0.2
local REPLY_WIDTH = 320
local REPLY_LINE_GAP = 2
local REPLY_BOX_HEIGHT = 26
local PANEL_GAP = 6
local CURSOR_OFFSET_X, CURSOR_OFFSET_Y = -24, 12
local PULSE_SECONDS = 3
local PULSE_ALPHA = 0.5
local PULSE_STEP = 0.5
local RING_RADIUS = 92
local RING_INNER_RADIUS = 34
local RING_SLOT_WIDTH, RING_SLOT_HEIGHT = 80, 60
local RING_DISC_SIZE = 38
local RING_CENTER_WIDTH, RING_CENTER_HEIGHT = 150, 54
local DOT_SIZE = 7

local BINDING = "GUDACHAT_WHISPER_RING"
local BATTLENET_COLOR = { 0, 0.68, 0.94 }

BINDING_HEADER_GUDACHAT = "GudaChat"
_G["BINDING_NAME_" .. BINDING] = L["BINDING_WHISPER_RING"]

local model = ns.NewWhisperModel()
ns.whisperModel = model

local icon, list, reply, ring
local Update

local SendChat = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
local SendBattleNet = BNSendWhisper or (C_BattleNet and C_BattleNet.SendWhisper)

local function Settings()
    return GudaChatDB and GudaChatDB.whisperIcon
end

local function Enabled()
    local settings = Settings()
    return settings ~= nil and settings.enabled == true
end

---------------------------------------------------------------------------
-- People: names, colours, icons
---------------------------------------------------------------------------

local function ClassFromGUID(guid)
    if not guid or ns.IsSecret(guid) or not GetPlayerInfoByGUID then return nil end
    local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
    if not ok or ns.IsSecret(class) then return nil end
    return ns.SafeName(class)
end

local function PersonColor(person)
    if person.bnAccountID then return BATTLENET_COLOR[1], BATTLENET_COLOR[2], BATTLENET_COLOR[3] end
    local c = person.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[person.class]
    if c then return c.r, c.g, c.b end
    return 1, 0.5, 1
end

local function WhisperTextColor(person)
    local info = ChatTypeInfo and ChatTypeInfo[person.bnAccountID and "BN_WHISPER" or "WHISPER"]
    if info and info.r then return info.r, info.g, info.b end
    return 1, 0.5, 1
end

local function SetPersonIcon(texture, person)
    if person.bnAccountID then
        texture:SetTexture(BATTLENET_ICON)
        texture:SetTexCoord(0, 1, 0, 1)
        return
    end
    local coords = person.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[person.class]
    if coords then
        texture:SetTexture(CLASS_ICONS)
        texture:SetTexCoord(unpack(coords))
    else
        texture:SetTexture(UNKNOWN_ICON)
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function ClockTime(t)
    return t and date("%H:%M", t) or ""
end

---------------------------------------------------------------------------
-- Positioning
---------------------------------------------------------------------------

local function CursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

-- Places frame next to the icon, on the side and in the direction with more room
local function AnchorBesideIcon(frame)
    frame:ClearAllPoints()
    local x, y = icon:GetCenter()
    local width, height = UIParent:GetSize()
    if not x then
        frame:SetPoint("CENTER")
        return
    end
    local toRight = x < width / 2
    local upward = y < height / 2
    local vertical = upward and "BOTTOM" or "TOP"
    frame:SetPoint(vertical .. (toRight and "LEFT" or "RIGHT"), icon,
        vertical .. (toRight and "RIGHT" or "LEFT"), toRight and PANEL_GAP or -PANEL_GAP, 0)
end

local function AnchorAtCursor(frame)
    local x, y = CursorPosition()
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x + CURSOR_OFFSET_X, y + CURSOR_OFFSET_Y)
end

local function RestoreIconPosition()
    local settings = Settings()
    icon:ClearAllPoints()
    if settings and settings.point then
        icon:SetPoint(settings.point, UIParent, settings.relPoint or settings.point, settings.x or 0, settings.y or 0)
    else
        icon:SetPoint("BOTTOMRIGHT", ChatFrame1, "TOPRIGHT", (ns.CHAT_EDGE_PAD or 0) + DEFAULT_ICON_X, DEFAULT_ICON_Y)
    end
end

local function SaveIconPosition()
    local settings = Settings()
    local point, _, relPoint, x, y = icon:GetPoint(1)
    if settings and point then
        settings.point, settings.relPoint, settings.x, settings.y = point, relPoint, x, y
    end
end

-- Back to the default spot above the right side of the chat window
function ns.ResetWhisperIconPosition()
    local settings = Settings()
    if not settings then return end
    settings.point, settings.relPoint, settings.x, settings.y = nil, nil, nil, nil
    if icon then RestoreIconPosition() end
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

local function SendReply(person, text)
    if not text or text == "" then return end
    if person.bnAccountID then
        if SendBattleNet then SendBattleNet(person.bnAccountID, text) end
        return
    end
    if SendChat and person.target then
        SendChat(text, "WHISPER", nil, person.target)
    end
end

---------------------------------------------------------------------------
-- Reply panel
---------------------------------------------------------------------------

local function LineText(person, line)
    local r, g, b = PersonColor(person)
    local name = string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, person.display or "")
    local prefix
    if line.out then
        prefix = string.format(ns.Blizz(CHAT_WHISPER_INFORM_GET, "To %s: "), name)
    else
        prefix = string.format(ns.Blizz(CHAT_WHISPER_GET, "%s whispers: "), name)
    end
    return "|cff808080[" .. ClockTime(line.time) .. "]|r " .. prefix .. (line.text or "")
end

local function FillReply()
    local person = model:Get(reply.key)
    if not person then
        reply:Hide()
        return
    end
    reply.name:SetText(person.display or "")
    reply.name:SetTextColor(PersonColor(person))
    local wr, wg, wb = WhisperTextColor(person)
    local y = LIST_HEADER_HEIGHT + 6
    for i = 1, ns.WHISPER_MAX_LINES do
        local fs = reply.lines[i]
        local line = person.lines[i]
        if line then
            fs:SetText(LineText(person, line))
            fs:SetTextColor(wr, wg, wb)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", reply, "TOPLEFT", 10, -y)
            fs:SetPoint("RIGHT", reply, "RIGHT", -10, 0)
            fs:Show()
            y = y + fs:GetStringHeight() + REPLY_LINE_GAP
        else
            fs:Hide()
        end
    end
    reply.to:SetText(string.format(L["WHISPER_TO"], person.display or ""))
    reply.to:SetTextColor(wr, wg, wb)
    reply.box:SetTextInsets(reply.to:GetStringWidth() + 14, 8, 0, 0)
    reply.box:ClearAllPoints()
    reply.box:SetPoint("TOPLEFT", reply, "TOPLEFT", 8, -(y + 4))
    reply.box:SetPoint("RIGHT", reply, "RIGHT", -8, 0)
    reply:SetHeight(y + 4 + REPLY_BOX_HEIGHT + 22)
end

local function CreateReply()
    local f = CreateFrame("Frame", "GudaChatWhisperReply", UIParent, "BackdropTemplate")
    f:SetWidth(REPLY_WIDTH)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    ns.ApplyDarkBackdrop(f)
    tinsert(UISpecialFrames, "GudaChatWhisperReply")

    local name = f:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlight")
    name:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -7)
    name:SetPoint("RIGHT", f, "RIGHT", -28, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    f.name = name

    local close = ns.CreateIconButton(f, ns.ASSET_PATH .. "close.png", 12)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -7)
    close:SetScript("OnClick", function() f:Hide() end)

    local rule = f:CreateTexture(nil, "ARTWORK")
    rule:SetTexture(WHITE)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -LIST_HEADER_HEIGHT)
    rule:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -LIST_HEADER_HEIGHT)
    ns.Paint(rule, C.rowRule)

    f.lines = {}
    for i = 1, ns.WHISPER_MAX_LINES do
        local fs = f:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        f.lines[i] = fs
    end

    local box = CreateFrame("EditBox", "GudaChatWhisperReplyBox", f, "BackdropTemplate")
    box:SetHeight(REPLY_BOX_HEIGHT)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetMaxLetters(255)
    ns.ApplyDarkBackdrop(box, C.fieldBg, C.accentBorder, true)
    ns.Paint(box, C.editText)
    f.box = box

    local to = box:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
    to:SetPoint("LEFT", box, "LEFT", 8, 0)
    f.to = to

    local keys = f:CreateFontString(nil, "OVERLAY", "GudaChatFontDisableSmall")
    keys:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 2, -5)
    keys:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    keys:SetJustifyH("LEFT")
    keys:SetWordWrap(false)
    keys:SetText(L["WHISPER_KEYS_HINT"])
    ns.Paint(keys, C.dimText)

    box:SetScript("OnEnterPressed", function(self)
        local person = model:Get(f.key)
        local keepOpen = IsShiftKeyDown()
        if person then SendReply(person, self:GetText()) end
        self:SetText("")
        if not keepOpen then f:Hide() end
    end)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    f:SetScript("OnHide", function() box:ClearFocus() end)
    f:Hide()
    return f
end

-- Opens the reply panel for one person, next to the icon (where = "icon") or at the
-- cursor (where = "cursor"), and puts the cursor in its reply box. Only called from a
-- click or the ring key, so the panel never takes the keyboard by itself.
local function OpenReply(key, where)
    if not model:Get(key) then return end
    if list then list:Hide() end
    reply.key = key
    model:MarkRead(key)
    FillReply()
    if where == "cursor" then
        AnchorAtCursor(reply)
    else
        AnchorBesideIcon(reply)
    end
    reply:Show()
    reply.box:SetFocus()
    Update()
end
ns.OpenWhisperReply = OpenReply

---------------------------------------------------------------------------
-- Hover list
---------------------------------------------------------------------------

local function ListRow(i)
    local row = list.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, list)
    row:SetHeight(LIST_ROW_HEIGHT)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(WHITE)
    ns.Paint(hl, C.menuHover)

    local name = row:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlightSmall")
    name:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -5)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.name = name

    local dot = row:CreateTexture(nil, "OVERLAY")
    dot:SetSize(DOT_SIZE, DOT_SIZE)
    dot:SetTexture(WHITE)
    dot:SetPoint("LEFT", name, "RIGHT", 5, 0)
    ns.Paint(dot, C.badgeBg)
    row.dot = dot

    local stamp = row:CreateFontString(nil, "OVERLAY", "GudaChatFontDisableSmall")
    stamp:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -5)
    ns.Paint(stamp, C.dimText)
    row.stamp = stamp

    local last = row:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlightSmall")
    last:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    last:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    last:SetJustifyH("LEFT")
    last:SetWordWrap(false)
    row.last = last

    row:SetScript("OnClick", function(self)
        if self.key then OpenReply(self.key, "icon") end
    end)
    row:SetScript("OnLeave", function() ns.ScheduleWhisperListHide() end)
    list.rows[i] = row
    return row
end

local function FillList()
    local people = model:List()
    list.count:SetText(string.format(L["WHISPER_UNREAD"], model:UnreadCount()))
    for i, person in ipairs(people) do
        local row = ListRow(i)
        row.key = person.key
        row.name:SetText(person.display or "")
        row.name:SetTextColor(PersonColor(person))
        row.dot:SetShown(person.unread)
        row.stamp:SetText(ClockTime(person.time))
        row.last:SetText(person.last or "")
        if person.unread then
            row.last:SetTextColor(WhisperTextColor(person))
        else
            row.last:SetTextColor(C.dimText[1], C.dimText[2], C.dimText[3], C.dimText[4])
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -(LIST_HEADER_HEIGHT + 2 + (i - 1) * LIST_ROW_HEIGHT))
        row:SetPoint("RIGHT", list, "RIGHT", -4, 0)
        row:Show()
    end
    for i = #people + 1, #list.rows do
        list.rows[i]:Hide()
    end
    list:SetHeight(LIST_HEADER_HEIGHT + 8 + #people * LIST_ROW_HEIGHT)
end

local function CreateList()
    local f = CreateFrame("Frame", "GudaChatWhisperList", UIParent, "BackdropTemplate")
    f:SetWidth(LIST_WIDTH)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    ns.ApplyDarkBackdrop(f)

    local title = f:CreateFontString(nil, "OVERLAY", "GudaChatFontNormalSmall")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    title:SetText(L["WHISPER_LIST_TITLE"])
    ns.Paint(title, C.heading)

    local count = f:CreateFontString(nil, "OVERLAY", "GudaChatFontDisableSmall")
    count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -9)
    ns.Paint(count, C.dimText)
    f.count = count

    local rule = f:CreateTexture(nil, "ARTWORK")
    rule:SetTexture(WHITE)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -LIST_HEADER_HEIGHT)
    rule:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -LIST_HEADER_HEIGHT)
    ns.Paint(rule, C.rowRule)

    f.rows = {}
    f:SetScript("OnLeave", function() ns.ScheduleWhisperListHide() end)
    f:Hide()
    return f
end

local function ShowList()
    if #model:List() == 0 then return end
    FillList()
    AnchorBesideIcon(list)
    list:Show()
end

-- Hides the hover list shortly after the mouse left both the icon and the list
function ns.ScheduleWhisperListHide()
    C_Timer.After(LIST_HIDE_DELAY, function()
        if list and list:IsShown() and not list:IsMouseOver() and not (icon and icon:IsMouseOver()) then
            list:Hide()
        end
    end)
end

---------------------------------------------------------------------------
-- Icon
---------------------------------------------------------------------------

local pulseToken = 0

local function Pulse()
    if not icon or not icon:IsShown() then return end
    pulseToken = pulseToken + 1
    local token = pulseToken
    icon.pulse:Stop()
    icon.pulse:Play()
    C_Timer.After(PULSE_SECONDS, function()
        if token == pulseToken then icon.pulse:Stop() end
    end)
end

local function CreateIcon()
    local btn = CreateFrame("Button", "GudaChatWhisperIcon", UIParent, "BackdropTemplate")
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(20)
    btn:SetMovable(true)
    btn:SetClampedToScreen(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("LeftButtonUp")
    ns.ApplyDarkBackdrop(btn, C.headerBg, C.headerBorder)

    local glyph = btn:CreateTexture(nil, "ARTWORK")
    glyph:SetSize(ICON_GLYPH_SIZE, ICON_GLYPH_SIZE)
    glyph:SetPoint("CENTER")
    glyph:SetTexture(ns.ASSET_PATH .. "chat.png")
    ns.Paint(glyph, C.iconNormal)
    btn.glyph = glyph

    local glow = btn:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
    glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    glow:SetTexture(WHITE)
    glow:SetBlendMode("ADD")
    ns.Paint(glow, C.accentBorder)
    glow:SetAlpha(0)
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(PULSE_ALPHA)
    fade:SetDuration(PULSE_STEP)
    pulse:SetScript("OnStop", function() glow:SetAlpha(0) end)
    btn.pulse = pulse

    local badge = CreateFrame("Frame", nil, btn)
    badge:SetHeight(BADGE_HEIGHT)
    badge:SetPoint("CENTER", btn, "TOPRIGHT", -2, -2)
    badge:SetFrameLevel(btn:GetFrameLevel() + 5)
    local badgeBg = badge:CreateTexture(nil, "BACKGROUND")
    badgeBg:SetAllPoints()
    badgeBg:SetTexture(WHITE)
    ns.Paint(badgeBg, C.badgeBg)
    local badgeText = badge:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlightSmall")
    badgeText:SetPoint("CENTER")
    ns.Paint(badgeText, C.badgeText)
    badge.text = badgeText
    btn.badge = badge

    btn:SetScript("OnDragStart", function(self)
        if list then list:Hide() end
        self:StartMoving()
    end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)
        SaveIconPosition()
    end)
    btn:SetScript("OnClick", function()
        local person = model:Latest()
        if person then OpenReply(person.key, "icon") end
    end)
    btn:SetScript("OnEnter", function(self)
        ns.Paint(self.glyph, C.iconHover)
        if #model:List() > 0 then
            ShowList()
        else
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L["WHISPER_LIST_TITLE"], 1, 1, 1)
            GameTooltip:AddLine(L["WHISPER_ICON_TOOLTIP"], nil, nil, nil, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        ns.Paint(self.glyph, C.iconNormal)
        GameTooltip:Hide()
        ns.ScheduleWhisperListHide()
    end)
    btn:Hide()
    return btn
end

local function IconWanted()
    local settings = Settings()
    if not Enabled() then return false end
    if settings.hideInCombat and InCombatLockdown() then return false end
    return model:UnreadCount() > 0 or settings.alwaysShow == true
end

Update = function()
    if not icon then return end
    local unread = model:UnreadCount()
    icon.badge:SetShown(unread > 0)
    icon.badge.text:SetText(unread)
    icon.badge:SetWidth(math.max(BADGE_HEIGHT, icon.badge.text:GetStringWidth() + 8))
    icon:SetShown(IconWanted())
    if not Enabled() then
        list:Hide()
        reply:Hide()
        return
    end
    if list:IsShown() then FillList() end
    if reply:IsShown() then FillReply() end
end
ns.UpdateWhisperIcon = Update

---------------------------------------------------------------------------
-- Whisper ring
---------------------------------------------------------------------------

local function RingSlot(i)
    local slot = ring.slots[i]
    if slot then return slot end
    slot = CreateFrame("Frame", nil, ring)
    slot:SetSize(RING_SLOT_WIDTH, RING_SLOT_HEIGHT)

    local hot = slot:CreateTexture(nil, "BACKGROUND")
    hot:SetSize(RING_DISC_SIZE + 6, RING_DISC_SIZE + 6)
    hot:SetPoint("TOP", slot, "TOP", 0, 3)
    hot:SetTexture(WHITE)
    ns.Paint(hot, C.accentBorder)
    slot.hot = hot

    local disc = slot:CreateTexture(nil, "ARTWORK")
    disc:SetSize(RING_DISC_SIZE, RING_DISC_SIZE)
    disc:SetPoint("TOP", slot, "TOP", 0, 0)
    slot.disc = disc

    local dot = slot:CreateTexture(nil, "OVERLAY")
    dot:SetSize(DOT_SIZE + 2, DOT_SIZE + 2)
    dot:SetTexture(WHITE)
    dot:SetPoint("CENTER", disc, "TOPRIGHT", -2, -2)
    ns.Paint(dot, C.badgeBg)
    slot.dot = dot

    local name = slot:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlightSmall")
    name:SetPoint("TOP", disc, "BOTTOM", 0, -3)
    name:SetWidth(RING_SLOT_WIDTH)
    name:SetWordWrap(false)
    slot.name = name

    ring.slots[i] = slot
    return slot
end

local function CreateRing()
    local f = CreateFrame("Frame", "GudaChatWhisperRing", UIParent)
    f:SetSize(1, 1)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f.slots = {}

    local center = CreateFrame("Frame", nil, f, "BackdropTemplate")
    center:SetSize(RING_CENTER_WIDTH, RING_CENTER_HEIGHT)
    center:SetPoint("CENTER")
    ns.ApplyDarkBackdrop(center)
    local cname = center:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlight")
    cname:SetPoint("TOP", center, "TOP", 0, -10)
    cname:SetWidth(RING_CENTER_WIDTH - 16)
    cname:SetWordWrap(false)
    center.name = cname
    local clast = center:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlightSmall")
    clast:SetPoint("TOP", cname, "BOTTOM", 0, -4)
    clast:SetWidth(RING_CENTER_WIDTH - 16)
    clast:SetWordWrap(false)
    ns.Paint(clast, C.dimText)
    center.last = clast
    f.center = center
    f:Hide()
    return f
end

local function ShowRingFocus(person)
    for _, slot in ipairs(ring.slots) do
        slot.hot:SetShown(slot.person ~= nil and slot.person == person)
    end
    if person then
        ring.center.name:SetText(person.display or "")
        ring.center.name:SetTextColor(PersonColor(person))
        ring.center.last:SetText(person.last or "")
    else
        ring.center.name:SetText("")
        ring.center.last:SetText("")
    end
end

local function OpenRing(x, y)
    local people = model:RingList()
    ring.people = people
    ring:ClearAllPoints()
    ring:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    for i, person in ipairs(people) do
        local slot = RingSlot(i)
        slot.person = person
        local ox, oy = ns.RingSlotOffset(i, #people, RING_RADIUS)
        slot:ClearAllPoints()
        slot:SetPoint("TOP", ring, "CENTER", ox, oy + RING_DISC_SIZE / 2)
        SetPersonIcon(slot.disc, person)
        slot.dot:SetShown(person.unread)
        slot.name:SetText(person.display or "")
        slot.name:SetTextColor(PersonColor(person))
        slot:Show()
    end
    for i = #people + 1, #ring.slots do
        ring.slots[i].person = nil
        ring.slots[i]:Hide()
    end
    ShowRingFocus(nil)
    ring:Show()
end

local held = { down = false }
local ringDriver = CreateFrame("Frame")

local function RingFollowCursor()
    local x, y = CursorPosition()
    local dx, dy = x - held.x, y - held.y
    if not held.open then
        local moved = math.sqrt(dx * dx + dy * dy)
        if not ns.IsRingTap(GetTime() - held.start, moved) then
            held.open = true
            OpenRing(held.x, held.y)
        end
        return
    end
    local people = ring.people or {}
    local index = ns.RingSlotAt(dx, dy, #people, RING_INNER_RADIUS)
    local person = index and people[index] or nil
    if person ~= held.focus then
        held.focus = person
        ShowRingFocus(person)
    end
end

-- Key binding handler (Bindings.xml, runOnUp): hold opens the ring at the cursor and the
-- release picks the person under it; a tap replies to the latest whisperer at the cursor.
-- Only plain frames are touched, never secure ones, so it is safe in combat.
function GudaChat_WhisperRingKey(keystate)
    if not Enabled() or not ring then return end
    if keystate == "down" then
        if held.down then return end
        held.down, held.open, held.focus = true, false, nil
        held.start = GetTime()
        held.x, held.y = CursorPosition()
        ringDriver:SetScript("OnUpdate", RingFollowCursor)
        return
    end
    if not held.down then return end
    held.down = false
    ringDriver:SetScript("OnUpdate", nil)
    local wasOpen, focus = held.open, held.focus
    ring:Hide()
    if wasOpen then
        if focus then OpenReply(focus.key, "cursor") end
        return
    end
    local latest = model:Latest()
    if latest then OpenReply(latest.key, "cursor") end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local function OnReceive(event, msg, sender, guid, bnAccountID)
    local isBattleNet = event == "CHAT_MSG_BN_WHISPER"
    local info = { sender = sender, text = msg, time = time() }
    if isBattleNet then
        info.bnAccountID = bnAccountID
        info.display = (ns.BattleTagFor and ns.BattleTagFor(bnAccountID)) or ns.Blizz(UNKNOWN, "Unknown")
    else
        info.display = ns.SafeShortName(sender)
        info.class = ClassFromGUID(guid)
    end
    local person = model:Receive(info)
    if not person then return end
    if reply:IsShown() and reply.key == person.key then
        model:MarkRead(person.key)
    end
    Update()
    Pulse()
end

local function OnSent(event, msg, target, bnAccountID)
    local isBattleNet = event == "CHAT_MSG_BN_WHISPER_INFORM"
    if model:Sent(target, isBattleNet and bnAccountID or nil, msg, time()) then
        Update()
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    if not Enabled() or not icon then return end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        Update()
        return
    end
    local msg, sender = ...
    local guid, bnAccountID = select(12, ...), select(13, ...)
    if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
        OnReceive(event, msg, sender, guid, bnAccountID)
    else
        OnSent(event, msg, sender, bnAccountID)
    end
end)
for _, event in ipairs({
    "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER_INFORM",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}) do
    events:RegisterEvent(event)
end

-- Builds the frames once the chat window exists (PLAYER_ENTERING_WORLD)
function ns.InitWhisperIcon()
    if icon then return end
    icon = CreateIcon()
    list = CreateList()
    reply = CreateReply()
    ring = CreateRing()
    RestoreIconPosition()
    Update()
end

---------------------------------------------------------------------------
-- Settings card (Tabs & Alerts)
---------------------------------------------------------------------------

local RING_KEY_WIDTH = 110

-- A toggle bound to one GudaChatDB.whisperIcon key. Changing "enabled" also records that
-- the player chose it, so ns.ApplyWhisperIconDefaults stops switching the icon back on.
local function SettingToggle(label, key, hint)
    return ns.CreateToggle(label, function()
        return Settings()[key] == true
    end, function(value)
        Settings()[key] = value
        if key == "enabled" then
            Settings().userSet = true
        end
        Update()
    end, hint)
end

local function RingKeyRow()
    local row = ns.CreateSettingsRow(L["OPT_WHISPER_RING_KEY"], L["HINT_KEY_BINDINGS"], RING_KEY_WIDTH)
    local value = row:CreateFontString(nil, "OVERLAY", "GudaChatFontHighlightSmall")
    value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    value:SetWidth(RING_KEY_WIDTH)
    value:SetJustifyH("RIGHT")
    value:SetWordWrap(false)
    ns.Paint(value, C.editText)
    local function Refresh()
        local key = GetBindingKey and GetBindingKey(BINDING)
        value:SetText(key and (GetBindingText and GetBindingText(key) or key) or L["KEY_NOT_BOUND"])
    end
    row:SetScript("OnShow", Refresh)
    Refresh()
    return row
end

local function NoteRow(text)
    local row = CreateFrame("Frame")
    row.noRule = true
    local note = row:CreateFontString(nil, "OVERLAY", "GudaChatFontDisableSmall")
    note:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    note:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText(text)
    ns.Paint(note, C.dimText)
    row:SetHeight(26)
    return row
end

ns.AddSettingsCard("tabs", 40, function(page)
    local card = ns.CreateCard(page, L["SEC_WHISPER_ICON"])
    card:AddRow(SettingToggle(L["OPT_WHISPER_ICON"], "enabled", L["HINT_ON_BY_DEFAULT"]))
    card:AddRow(SettingToggle(L["OPT_WHISPER_ICON_ALWAYS"], "alwaysShow"))
    card:AddRow(SettingToggle(L["OPT_HIDE_IN_COMBAT"], "hideInCombat"))
    card:AddRow(RingKeyRow())
    card:AddRow(NoteRow(L["NOTE_WHISPER_RING"]))
    local buttonRow = CreateFrame("Frame")
    buttonRow:SetHeight(36)
    local reset = ns.CreateThemedButton(buttonRow, L["BTN_RESET_POSITION"], ns.ResetWhisperIconPosition, 140)
    reset:SetPoint("LEFT", buttonRow, "LEFT", 0, 0)
    card:AddRow(buttonRow)
    return card
end)
