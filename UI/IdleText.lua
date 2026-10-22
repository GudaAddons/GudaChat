local addonName, ns = ...

---------------------------------------------------------------------------
-- Hide chat text when the chat is not in use (GudaChatDB.hideIdleText, off by default)
--
-- The message text of every chat frame fades out with the header when the mouse leaves
-- the chat UI, and fades back in on hover, while typing in the chat input, while the
-- emoji picker or the settings window is open, and for ns.IDLE_TEXT_SHOW_SECONDS after a
-- new message.
--
-- What fades: the frame's FontStringContainer where the client has one (the Lua
-- ScrollingMessageFrame of modern clients). It holds only the message lines, so the chat
-- background, the scrollbar and the frame alpha of ChatFrame2 (which SetCombatLogVisible
-- uses to show and hide the combat log) are left alone. On a client without it the chat
-- frame itself fades, and ChatFrame2 is then skipped because its frame alpha already
-- means "combat log shown".
--
-- Taint: only widget methods are called (SetAlpha, animation groups created once per
-- frame and kept in a local weak table) and AddMessage is watched with hooksecurefunc,
-- so no Blizzard field or method is replaced. The state is re-checked by the header's
-- hover monitor through ns.UpdateIdleText; nothing else runs per frame.
---------------------------------------------------------------------------

-- Same delay as the header before it hides after the mouse leaves
local HOVER_GRACE_SECONDS = 0.3

local fades = setmetatable({}, { __mode = "k" })
local watchedFrames = setmetatable({}, { __mode = "k" })
local textShown = true
local lastMessageAt
local lastHoverAt
local visibilityState = {}

-- The region whose alpha hides the message text of cf, or nil to leave cf alone
local function FadeTarget(cf)
    local container = cf.FontStringContainer
    if type(container) == "table" and container.SetAlpha then
        return container
    end
    if cf == ChatFrame2 then return nil end
    return cf
end

local function FadesFor(target)
    local pair = fades[target]
    if not pair then
        pair = {
            show = ns.CreateFade(target, 1, ns.FADE_IN_DURATION),
            hide = ns.CreateFade(target, 0, ns.FADE_OUT_DURATION),
        }
        fades[target] = pair
    end
    return pair
end

local function OnMessageAdded(cf)
    if cf:IsVisible() then
        lastMessageAt = GetTime()
    end
end

local function WatchFrame(cf)
    if watchedFrames[cf] then return end
    watchedFrames[cf] = true
    hooksecurefunc(cf, "AddMessage", OnMessageAdded)
end

local function SetTextShown(shown)
    textShown = shown
    ns.ForEachChatFrame(function(cf)
        WatchFrame(cf)
        local target = FadeTarget(cf)
        if not target then return end
        local pair = FadesFor(target)
        if shown then
            pair.hide:Stop()
            pair.show:PlayFromCurrent()
        else
            pair.show:Stop()
            pair.hide:PlayFromCurrent()
        end
    end)
end

local function IsOverlayOpen()
    local picker = _G["GudaChatEmojiPicker"]
    if picker and picker:IsShown() then return true end
    return ns.settingsFrame ~= nil and ns.settingsFrame:IsShown()
end

-- Called by the header's hover monitor on every check with whether the mouse is over the
-- chat UI (or one of its menus). Starts a fade only when the visibility changes.
function ns.UpdateIdleText(hovered)
    if not (GudaChatDB and GudaChatDB.hideIdleText) then return end
    local now = GetTime()
    if hovered then
        lastHoverAt = now
    end
    visibilityState.enabled = true
    visibilityState.hovered = lastHoverAt ~= nil and now - lastHoverAt < HOVER_GRACE_SECONDS
    visibilityState.inputFocused = ns.hideHeaderForInput == true
    visibilityState.overlayOpen = IsOverlayOpen()
    visibilityState.now = now
    visibilityState.lastMessageAt = lastMessageAt
    local show = ns.ShouldShowChatText(visibilityState)
    if show ~= textShown then
        SetTextShown(show)
    end
end

-- Applies the option after a settings change or at login. Turning it off brings all text
-- back at once; turning it on starts watching for new messages and lets the next hover
-- check decide.
function ns.ApplyIdleText()
    if GudaChatDB.hideIdleText then
        ns.ForEachChatFrame(WatchFrame)
        lastMessageAt = GetTime()
        return
    end
    if not textShown then
        SetTextShown(true)
    end
end
