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
