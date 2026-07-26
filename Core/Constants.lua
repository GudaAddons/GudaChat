local addonName, ns = ...

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- Permanently-hidden container. Reparenting a Blizzard frame onto this keeps it from ever
-- rendering WITHOUT overriding its `:Show` method. Overriding `frame.Show = frame.Hide` from
-- addon (insecure) code TAINTS the Show field; Blizzard later reads that tainted field when it
-- tries to show the frame during chat message handling (e.g. the scroll-to-bottom button on a
-- new message), which taints the whole MessageEventHandler execution and crashes
-- ChatHistory_GetToken on secret senders (MONSTER_SAY/YELL/EMOTE). Reparenting avoids that.
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
ns.hiddenParent = hiddenParent

local function KillFrame(frame)
    if not frame then return end
    frame:Hide()
    frame:SetAlpha(0)
    frame:SetSize(0.001, 0.001)
    if frame.SetParent then
        -- pcall: a few Blizzard frames disallow reparenting; fall back to just staying hidden.
        pcall(frame.SetParent, frame, hiddenParent)
    end
end
ns.KillFrame = KillFrame

-- On modern clients (11.0+), name-returning APIs and CHAT_MSG `sender`/`name` args can be "secret"
-- strings while our execution is tainted. Indexing them (:match/:lower) or comparing with `==`
-- throws ("a secret string value"). These helpers do those ops inside pcall so a secret value
-- simply yields nil / "no match" instead of erroring the caller. See chat handlers in Filters.lua
-- and Header.lua.
local function SafeShortName(name)
    if not name then return nil end
    local ok, short = pcall(function() return name:match("^([^%-]+)") or name end)
    return ok and short or nil
end
ns.SafeShortName = SafeShortName

local function NamesMatch(a, b)
    local ok, equal = pcall(function() return a == b end)
    return ok and equal
end
ns.NamesMatch = NamesMatch

-- Returns the full name as a plain string, or nil if it's a secret value (concatenation forces a
-- read that throws on secret strings). Use before storing a CHAT_MSG sender into SavedVariables —
-- a secret string must never be persisted.
local function SafeName(name)
    if not name then return nil end
    local ok, s = pcall(function() return name .. "" end)
    return ok and s or nil
end
ns.SafeName = SafeName

---------------------------------------------------------------------------
-- Shared constants
---------------------------------------------------------------------------

local ASSET_PATH = "Interface\\AddOns\\GudaChat\\Assets\\"
ns.ASSET_PATH = ASSET_PATH

local COLOR_DARK_BG       = { 0.08, 0.08, 0.08, 0.95 }
local COLOR_DARK_BORDER   = { 0.3,  0.3,  0.3,  0.6  }
local COLOR_GOLDEN_A      = { 0.8,  0.6,  0.0,  0.8  }
local COLOR_COPY_BG       = { 0.1,  0.1,  0.1,  0.95 }
local COLOR_HEADER_BG     = { 0.05, 0.05, 0.05, 0.85 }
local COLOR_HEADER_BORDER = { 0.25, 0.25, 0.25, 0.5  }

ns.COLOR_DARK_BG       = COLOR_DARK_BG
ns.COLOR_DARK_BORDER   = COLOR_DARK_BORDER
ns.COLOR_GOLDEN_A      = COLOR_GOLDEN_A
ns.COLOR_COPY_BG       = COLOR_COPY_BG
ns.COLOR_HEADER_BG     = COLOR_HEADER_BG
ns.COLOR_HEADER_BORDER = COLOR_HEADER_BORDER

local BACKDROP_DARK = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
ns.BACKDROP_DARK = BACKDROP_DARK

local BACKDROP_FLAT = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}
ns.BACKDROP_FLAT = BACKDROP_FLAT

---------------------------------------------------------------------------
-- Shared helpers
---------------------------------------------------------------------------

local function ApplyDarkBackdrop(frame, bgColor, borderColor)
    frame:SetBackdrop(BACKDROP_DARK)
    frame:SetBackdropColor(unpack(bgColor or COLOR_DARK_BG))
    frame:SetBackdropBorderColor(unpack(borderColor or COLOR_DARK_BORDER))
end
ns.ApplyDarkBackdrop = ApplyDarkBackdrop

local function ForEachChatWindow(fn)
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then fn(cf, i) end
    end
end
ns.ForEachChatWindow = ForEachChatWindow

-- Sync all docked chat frames (permanent + temporary) to ChatFrame1's position/size
local function SyncDockedFrames()
    local point, _, relPoint, x, y = ChatFrame1:GetPoint(1)
    local w, h = ChatFrame1:GetSize()
    if not point then return end
    for i = 2, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf and cf.isDocked then
            cf:ClearAllPoints()
            cf:SetPoint(point, UIParent, relPoint, x, y)
            cf:SetSize(w, h)
        end
    end
    -- Also sync temporary frames
    if CHAT_FRAMES then
        for _, name in ipairs(CHAT_FRAMES) do
            local cf = _G[name]
            if cf and cf.isTemporary and cf.isDocked then
                cf:ClearAllPoints()
                cf:SetPoint(point, UIParent, relPoint, x, y)
                cf:SetSize(w, h)
            end
        end
    end
end
ns.SyncDockedFrames = SyncDockedFrames

-- Single writer for GudaChatDB.position. ReapplyChatFrame1Geometry treats that table as the
-- source of truth, so anything that moves ChatFrame1 must go through here — otherwise the
-- next dock update / UIParent_ManageFramePositions snaps the frame back to stale coords.
local function SaveChatPosition()
    if not GudaChatDB then return end
    local point, _, relPoint, x, y = ChatFrame1:GetPoint(1)
    if not point then return end
    GudaChatDB.position = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
    SyncDockedFrames()
end
ns.SaveChatPosition = SaveChatPosition

-- Changing SetClampRectInsets does not reposition a frame that already violates the new
-- clamp rect; it sits out of bounds until some later event snaps it. Re-apply the saved
-- anchor to force the engine to re-evaluate clamping now, then persist where it landed.
local function SettleChatPosition()
    local p = GudaChatDB and GudaChatDB.position
    if not p then return end        -- never moved: leave Blizzard's default layout alone
    ns.cf1PositionLocked = false    -- keep ReapplyChatFrame1Geometry inert meanwhile
    ChatFrame1:ClearAllPoints()
    ChatFrame1:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    C_Timer.After(0, function()
        SaveChatPosition()          -- record the post-clamp position
        ns.cf1PositionLocked = true
    end)
end
ns.SettleChatPosition = SettleChatPosition

local function CreateCloseButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(12, 12)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -4)
    btn:SetNormalTexture(ASSET_PATH .. "close.png")
    btn:GetNormalTexture():SetVertexColor(0.6, 0.6, 0.6)
    btn:SetScript("OnEnter", function(self)
        self:GetNormalTexture():SetVertexColor(1, 1, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:GetNormalTexture():SetVertexColor(0.6, 0.6, 0.6)
    end)
    btn:SetScript("OnClick", function() parent:Hide() end)
    return btn
end
ns.CreateCloseButton = CreateCloseButton

local function CreateDragRegion(parent)
    local drag = CreateFrame("Frame", nil, parent)
    drag:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    drag:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -28, 0)
    drag:SetHeight(24)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        parent:StartMoving()
        parent:SetUserPlaced(false)
    end)
    drag:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        parent:SetUserPlaced(false)
    end)
    return drag
end
ns.CreateDragRegion = CreateDragRegion

local function CreateCopyPopupFrame(globalName, width, height, multiLine)
    local f = CreateFrame("Frame", globalName, UIParent, "BackdropTemplate")
    f:SetSize(width, height)
    f:SetPoint("CENTER")
    f:SetFrameStrata("TOOLTIP")
    ApplyDarkBackdrop(f, COLOR_COPY_BG, COLOR_GOLDEN_A)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)
    end)
    tinsert(UISpecialFrames, globalName)

    CreateCloseButton(f)

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
    label:SetText(multiLine and "Ctrl+C to copy. Escape to close." or "Ctrl+C to copy, Escape to close")
    label:SetTextColor(0.6, 0.6, 0.6)

    if multiLine then
        local scrollFrame = CreateFrame("ScrollFrame", globalName .. "Scroll", f, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -22)
        scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 8)

        local eb = CreateFrame("EditBox", nil, scrollFrame)
        eb:SetFontObject(GameFontHighlight)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetTextColor(0.9, 0.9, 0.9)
        eb:SetMaxLetters(0)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        eb:SetScript("OnEnter", function(self)
            scrollFrame:UpdateScrollChildRect()
            self:SetFocus()
        end)
        eb:SetScript("OnLeave", function(self) self:ClearFocus() end)
        eb:SetScript("OnCursorChanged", function(self, x, y, w, h)
            local scroll = -y
            local maxScroll = max(0, self:GetHeight() - scrollFrame:GetHeight())
            scrollFrame:SetVerticalScroll(min(max(0, scroll), maxScroll))
        end)
        scrollFrame:SetScrollChild(eb)

        f.editBox = eb
        f.scrollFrame = scrollFrame
    else
        local eb = CreateFrame("EditBox", nil, f, "BackdropTemplate")
        eb:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -20)
        eb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 6)
        eb:SetFontObject(ChatFontNormal)
        eb:SetAutoFocus(true)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        eb:SetScript("OnEditFocusLost", function() f:Hide() end)
        f.editBox = eb
    end

    f:Hide()
    return f
end
ns.CreateCopyPopupFrame = CreateCopyPopupFrame

-- Shared channel event list for message filters
ns.CHAT_MSG_CHANNELS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_CHANNEL",
}

ns.DEFAULT_EMOJI_SIZE = 12

-- Detect Retail client (interface >= 110000)
ns.IS_RETAIL = (select(4, GetBuildInfo()) or 0) >= 110000

-- Detect the modern (Dragonflight 10.0+) client engine. True on retail AND on the
-- Cataclysm/MoP-era "Classic" clients, which share retail's chat engine but report low
-- interface numbers (so IS_RETAIL alone misses them). Feature-detect via the Settings API,
-- which shipped in 10.0 alongside the modern chat frame and is absent on the 1.15/legacy
-- engine; this self-corrects for whichever engine the TBC/Anniversary client happens to run.
ns.IS_MODERN = ns.IS_RETAIL or (Settings ~= nil) or false

-- Right-edge gutter of the chat frame's message area. The retail chat frame reserves a
-- column on the right that classic engines do not have, so chrome anchored to the frame
-- must reach further right there to line up with the text.
-- Deliberately NOT gated on IS_MODERN: that is also true on MoP Classic and Classic Era
-- (both expose the Settings API) while they run legacy chat-frame geometry with no gutter,
-- which made the header/tab bar/input bar render 13px wider than the chat window there.
ns.CHAT_EDGE_PAD = ns.IS_RETAIL and 13 or 0

-- Custom scrollbar width (UI/Scrollbar.lua)
ns.SCROLLBAR_W = 6

---------------------------------------------------------------------------
-- Locale helpers
---------------------------------------------------------------------------

-- Clients whose text needs glyphs the bundled Latin fonts do not carry.
ns.NON_LATIN_LOCALE = { zhCN = true, zhTW = true, koKR = true, ruRU = true }

-- Use a Blizzard global string when the client defines one, else the English
-- literal. Blizzard's own globals are already translated for every locale, so
-- labels that have an exact equivalent come out localized for free — and a
-- global that is missing on an older flavor simply degrades to English.
function ns.Blizz(value, fallback)
    if type(value) == "string" and value ~= "" then return value end
    return fallback
end

-- Blizzard's slash tokens are localized (SLASH_SAY1 is "/s" on enUS but can
-- differ elsewhere). Index 1 is the primary token; fall back to the English
-- literal if the global is missing on this flavor.
function ns.SlashCmd(prefix, fallback)
    for i = 1, 8 do
        local token = _G[prefix .. i]
        if type(token) == "string" and token ~= "" then
            return token
        end
    end
    return fallback
end

-- UTF-8 aware lowercase. string.lower only folds A-Z, so on a Russian client a
-- typed "оружие" never matches "Оружие". Ported from GudaBags/Core/Utils.lua.
-- Every character needing a fold for the supported locales lives in
-- U+0080..U+07FF (always 2 bytes in UTF-8), so the table is generated from
-- codepoint ranges. CJK and Korean need no entries — those scripts have no case.
local UTF8_LOWER = {}
do
    local function Char2(cp)
        return string.char(192 + math.floor(cp / 64), 128 + (cp % 64))
    end
    local function AddRange(fromCp, toCp, delta, skip)
        for cp = fromCp, toCp do
            if cp ~= skip then
                UTF8_LOWER[Char2(cp)] = Char2(cp + delta)
            end
        end
    end
    -- Latin-1 Supplement À..Þ, skipping × (U+00D7), which is not a letter
    AddRange(0x00C0, 0x00DE, 0x20, 0x00D7)
    -- Cyrillic А..Я and the Ѐ..Џ block (ruRU)
    AddRange(0x0410, 0x042F, 0x20)
    AddRange(0x0400, 0x040F, 0x50)
    -- Ÿ (U+0178) is the one frFR capital outside Latin-1 Supplement
    UTF8_LOWER[Char2(0x0178)] = Char2(0x00FF)
end

-- A-Z folded by explicit byte range: on some builds the C locale's tolower also
-- rewrites bytes >= 0x80 and would corrupt the sequences we just folded.
local ASCII_LOWER = {}
for b = 65, 90 do
    ASCII_LOWER[string.char(b)] = string.char(b + 32)
end

function ns.UTF8Lower(text)
    if not text or text == "" then return text end
    -- Pure ASCII (the common case): nothing multi-byte to protect
    if not text:find("[\128-\255]") then
        return text:lower()
    end
    local folded = text:gsub("[\194-\211][\128-\191]", UTF8_LOWER)
    return (folded:gsub("[A-Z]", ASCII_LOWER))
end

-- True when the string contains bytes outside ASCII, i.e. Lua's %w/%a character
-- classes and frontier patterns cannot be trusted on it.
function ns.IsNonAscii(text)
    return text ~= nil and text:find("[\128-\255]") ~= nil
end
