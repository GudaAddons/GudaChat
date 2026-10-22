local addonName, ns = ...

---------------------------------------------------------------------------
-- Whisper icon model
--
-- The session's received whispers, per person, for the whisper icon, its hover list,
-- the reply panel and the whisper ring. Pure Lua with no frames, so the offline tests
-- cover it. People are keyed "bn:<account id>" for Battle.net friends and
-- "pc:<compact name>" for characters (ns.CompactName: no realm, no spaces, lower case,
-- so the Forever "Given Family" shapes all meet). Secret values are never stored: a
-- secret sender is ignored, a secret message is kept as a line without text.
---------------------------------------------------------------------------

local MAX_PEOPLE = 10
local MAX_LINES = 5
local RING_SLOTS = 8

-- A press shorter than this, with the cursor moved less than TAP_DISTANCE pixels, is a
-- tap (reply to the latest) rather than a hold (open the ring)
local TAP_TIME = 0.25
local TAP_DISTANCE = 6

ns.WHISPER_MAX_PEOPLE = MAX_PEOPLE
ns.WHISPER_MAX_LINES = MAX_LINES
ns.WHISPER_RING_SLOTS = RING_SLOTS
ns.WHISPER_TAP_TIME = TAP_TIME
ns.WHISPER_TAP_DISTANCE = TAP_DISTANCE

local Model = {}
Model.__index = Model

-- The person key for a whisper sender, or nil when the sender cannot be read.
-- bnAccountID is set for Battle.net whispers.
local function WhisperKey(sender, bnAccountID)
    if bnAccountID ~= nil then
        if type(bnAccountID) ~= "number" or ns.IsSecret(bnAccountID) then return nil end
        return "bn:" .. bnAccountID
    end
    local compact = ns.CompactName(sender)
    return compact and ("pc:" .. compact) or nil
end
ns.WhisperKey = WhisperKey

-- A readable copy of a message, or nil for secret or missing text
local function PlainText(text)
    if text == nil or ns.IsSecret(text) then return nil end
    return ns.SafeName(text)
end

function Model.New()
    return setmetatable({ people = {}, seq = 0 }, Model)
end
ns.NewWhisperModel = Model.New

local function AddLine(person, line)
    tinsert(person.lines, line)
    while #person.lines > MAX_LINES do
        tremove(person.lines, 1)
    end
end

-- Drops the person who whispered longest ago once more than MAX_PEOPLE are kept
function Model:Trim()
    local count, oldestKey, oldestSeq = 0, nil, nil
    for key, person in pairs(self.people) do
        count = count + 1
        if not oldestSeq or person.seq < oldestSeq then
            oldestKey, oldestSeq = key, person.seq
        end
    end
    if count > MAX_PEOPLE and oldestKey then
        self.people[oldestKey] = nil
    end
end

-- Records a received whisper. info: sender (name as received, used as the reply target),
-- bnAccountID, display (shown name), class (class file), text, time. Returns the person,
-- or nil when the sender cannot be read.
function Model:Receive(info)
    local key = WhisperKey(info.sender, info.bnAccountID)
    if not key then return nil end
    self.seq = self.seq + 1
    local person = self.people[key]
    if not person then
        person = { key = key, lines = {} }
        self.people[key] = person
    end
    person.seq = self.seq
    person.target = ns.SafeName(info.sender) or person.target
    person.bnAccountID = info.bnAccountID
    person.display = ns.SafeName(info.display) or person.display or person.target
    person.class = info.class or person.class
    person.last = PlainText(info.text)
    person.time = info.time
    person.unread = true
    AddLine(person, { out = false, text = person.last, time = info.time })
    self:Trim()
    return person
end

-- Records a whisper the player sent. It marks that person read and adds the line to
-- their conversation; whispers to people who never whispered this session are ignored.
function Model:Sent(target, bnAccountID, text, time)
    local key = WhisperKey(target, bnAccountID)
    local person = key and self.people[key]
    if not person then return nil end
    person.unread = false
    AddLine(person, { out = true, text = PlainText(text), time = time })
    return person
end

function Model:Get(key)
    return self.people[key]
end

function Model:MarkRead(key)
    local person = self.people[key]
    if person then person.unread = false end
end

-- Number of PEOPLE with unread whispers (the badge)
function Model:UnreadCount()
    local count = 0
    for _, person in pairs(self.people) do
        if person.unread then count = count + 1 end
    end
    return count
end

-- Everyone, newest whisper first (the hover list)
function Model:List()
    local list = {}
    for _, person in pairs(self.people) do
        tinsert(list, person)
    end
    table.sort(list, function(a, b) return a.seq > b.seq end)
    return list
end

-- The person a reply without choosing goes to: the newest unread, else the newest
function Model:Latest()
    local newest, newestUnread
    for _, person in pairs(self.people) do
        if not newest or person.seq > newest.seq then newest = person end
        if person.unread and (not newestUnread or person.seq > newestUnread.seq) then
            newestUnread = person
        end
    end
    return newestUnread or newest
end

-- Up to RING_SLOTS people for the whisper ring: unread first, each group newest first
function Model:RingList()
    local list = self:List()
    table.sort(list, function(a, b)
        if a.unread ~= b.unread then return a.unread end
        return a.seq > b.seq
    end)
    while #list > RING_SLOTS do
        tremove(list)
    end
    return list
end

---------------------------------------------------------------------------
-- Ring geometry
---------------------------------------------------------------------------

-- Offset of slot index (1-based) of count from the ring centre: slot 1 at the top, the
-- rest clockwise, in screen coordinates (y up)
function ns.RingSlotOffset(index, count, radius)
    local angle = math.pi / 2 - (index - 1) * (2 * math.pi / count)
    return math.cos(angle) * radius, math.sin(angle) * radius
end

-- The slot the cursor points at, from its offset (dx, dy; y up) to the ring centre, or
-- nil inside innerRadius (the centre, which cancels) or when there are no slots
function ns.RingSlotAt(dx, dy, count, innerRadius)
    if count < 1 then return nil end
    if dx * dx + dy * dy < innerRadius * innerRadius then return nil end
    local degrees = math.deg(math.atan2(dy, dx))
    local fromTop = (90 - degrees) % 360
    local step = 360 / count
    return math.floor((fromTop + step / 2) / step) % count + 1
end

-- True when a key press was a tap: short and with the cursor (nearly) still
function ns.IsRingTap(heldSeconds, movedPixels)
    return heldSeconds < TAP_TIME and movedPixels < TAP_DISTANCE
end

-- Fills the whisper icon settings (GudaChatDB.whisperIcon) with their defaults and
-- returns the table. The icon is on by default. Unreleased 2.0 builds saved it as off,
-- so until the player changes the option themselves (userSet, written by the settings
-- toggle) it is switched on at every load; after that their own choice is kept.
function ns.ApplyWhisperIconDefaults(settings)
    if type(settings) ~= "table" then
        settings = {}
    end
    if settings.userSet ~= true then
        settings.enabled = true
    end
    if settings.alwaysShow == nil then
        settings.alwaysShow = false
    end
    if settings.hideInCombat == nil then
        settings.hideInCombat = false
    end
    return settings
end
