local addonName, ns = ...

---------------------------------------------------------------------------
-- Whispers tab: the dedicated Whispers window, whisper routing, and switching to the
-- right tab when the player sends a message
---------------------------------------------------------------------------

local WHISPER_FRAME_MAX_LINES = 500
local WHISPER_FRAME_DEFAULT_FONT_SIZE = 14

local function EnforceWhisperGroups(cf, idx)
    ChatFrame_AddMessageGroup(cf, "WHISPER")
    ChatFrame_AddMessageGroup(cf, "BN_WHISPER")
    ChatFrame_AddMessageGroup(cf, "WHISPER_INFORM")
    ChatFrame_AddMessageGroup(cf, "BN_WHISPER_INFORM")
    if idx and AddChatWindowMessages then
        AddChatWindowMessages(idx, "WHISPER")
        AddChatWindowMessages(idx, "BN_WHISPER")
        AddChatWindowMessages(idx, "WHISPER_INFORM")
        AddChatWindowMessages(idx, "BN_WHISPER_INFORM")
    end
end

-- Keep every whisper in the single dedicated Whispers tab instead of letting retail spawn a
-- separate conversation window per target. The `whisperMode` CVar drives that popout behavior:
-- "popout"/"popout_and_inline" open a temp window for each whisper, while "inline" keeps whispers
-- in the frames that registered the WHISPER group (our Whispers frame). We also drop the WHISPER
-- groups from General so whispers land ONLY in the dedicated tab, not duplicated into General.
-- The player's original mode is remembered once (never overwritten by our own "inline" on
-- later reloads) so turning the feature off can restore it. The reverse mirrors the cleanup
-- already done when a whisper window is closed (see RemoveWindow in ContextMenu.lua).
local function ApplyWhisperRouting()
    if GudaChatDB.whisperTab then
        local cur = GetCVar and GetCVar("whisperMode")
        if cur and cur ~= "inline" and GudaChatDB.origWhisperMode == nil then
            GudaChatDB.origWhisperMode = cur
        end
        pcall(SetCVar, "whisperMode", "inline")
        if ChatFrame_RemoveMessageGroup then
            ChatFrame_RemoveMessageGroup(ChatFrame1, "WHISPER")
            ChatFrame_RemoveMessageGroup(ChatFrame1, "BN_WHISPER")
        end
        if RemoveChatWindowMessages then
            RemoveChatWindowMessages(1, "WHISPER")
            RemoveChatWindowMessages(1, "BN_WHISPER")
        end
    else
        if GudaChatDB.origWhisperMode then
            pcall(SetCVar, "whisperMode", GudaChatDB.origWhisperMode)
            GudaChatDB.origWhisperMode = nil
        end
        ChatFrame_AddMessageGroup(ChatFrame1, "WHISPER")
        ChatFrame_AddMessageGroup(ChatFrame1, "BN_WHISPER")
        if AddChatWindowMessages then
            AddChatWindowMessages(1, "WHISPER")
            AddChatWindowMessages(1, "BN_WHISPER")
        end
    end
end
ns.ApplyWhisperRouting = ApplyWhisperRouting

-- Logout half of ApplyWhisperRouting. The whisperMode CVar and General's WHISPER groups
-- are saved by the game, outside SavedVariables; if GudaChatDB is lost (the WoW: Forever
-- SavedVariables bug) the next session could never undo them and General would stop
-- showing whispers. So they go back to the player's own setup at every logout, and
-- ApplyWhisperRouting sets them again at login. origWhisperMode is kept for that.
local function UndoWhisperRoutingForLogout()
    if not GudaChatDB.whisperTab then return end
    if GudaChatDB.origWhisperMode then
        pcall(SetCVar, "whisperMode", GudaChatDB.origWhisperMode)
    end
    if AddChatWindowMessages then
        AddChatWindowMessages(1, "WHISPER")
        AddChatWindowMessages(1, "BN_WHISPER")
    end
end
ns.UndoWhisperRoutingForLogout = UndoWhisperRoutingForLogout

-- Makes cf the Whispers window: whisper groups, docked, same place and size as General,
-- a font (AddMessage silently fails without one), then routes all whispers to it
local function InitWhisperFrame(cf, idx)
    ns.whisperFrame = cf
    ns.whisperFrameIndex = idx
    GudaChatDB.whisperFrameIndex = idx
    EnforceWhisperGroups(cf, idx)
    if not cf.isDocked then
        FCF_DockFrame(cf)
    end
    cf:ClearAllPoints()
    cf:SetPoint(ChatFrame1:GetPoint(1))
    cf:SetSize(ChatFrame1:GetSize())
    local font, size, flags = cf:GetFont()
    if not font then
        font, size, flags = ChatFrame1:GetFont()
    end
    if GudaChatDB.chatFont then
        font = GudaChatDB.chatFont
    end
    if font then
        cf:SetFont(font, GudaChatDB.chatFontSize or size or WHISPER_FRAME_DEFAULT_FONT_SIZE, flags or "")
    end
    cf:SetMaxLines(WHISPER_FRAME_MAX_LINES)
    cf:SetFading(GudaChatDB.fading or false)
    cf:SetJustifyH("LEFT")
    ApplyWhisperRouting()
    ns.SafeSelectDockFrame(ChatFrame1)
end

-- Finds the Whispers window (saved index first, then by name) or opens a new one. The
-- window is named in the client's language, but the old English literal still matches so
-- windows created by earlier versions are found instead of a second one being spawned.
local function SetupWhisperFrame()
    local whisperName = (type(WHISPERS) == "string" and WHISPERS ~= "" and WHISPERS)
        or (type(WHISPER) == "string" and WHISPER ~= "" and WHISPER)
        or "Whispers"

    local function IsWhisperWindowName(name)
        return name == whisperName or name == "Whispers"
    end

    local idx = GudaChatDB.whisperFrameIndex
    if idx then
        local cf = _G["ChatFrame" .. idx]
        local name = cf and GetChatWindowInfo(idx)
        if cf and IsWhisperWindowName(name) then
            InitWhisperFrame(cf, idx)
            return
        end
        GudaChatDB.whisperFrameIndex = nil
    end

    for i = 3, NUM_CHAT_WINDOWS do
        if IsWhisperWindowName(GetChatWindowInfo(i)) then
            InitWhisperFrame(_G["ChatFrame" .. i], i)
            return
        end
    end

    if FCF_OpenNewWindow then
        local before = ns.InUseChatWindows()
        FCF_OpenNewWindow(whisperName)
        local cf, i = ns.FindNewChatWindow(before)
        if cf then
            ns.StripChatChrome(i)
            InitWhisperFrame(cf, i)
            if not cf.isDocked then FCF_DockFrame(cf) end
            ns.SafeSelectDockFrame(ChatFrame1)
        end
    end
end
ns.SetupWhisperFrame = SetupWhisperFrame

-- Closing the Whispers window turns the Whispers tab off. Otherwise the addon would keep
-- routing whispers to a closed window (General stays without whispers) and select it on
-- every whisper sent, which used to leave the chat area empty.
hooksecurefunc("FCF_Close", function(frame)
    if not ns.whisperFrame or frame ~= ns.whisperFrame then return end
    ns.whisperFrame = nil
    ns.whisperFrameIndex = nil
    GudaChatDB.whisperFrameIndex = nil
    GudaChatDB.whisperTab = false
    ApplyWhisperRouting()
    if ns.whisperTabCheckbox then ns.whisperTabCheckbox:SetChecked(false) end
end)

---------------------------------------------------------------------------
-- Auto-select the tab a sent message belongs to
---------------------------------------------------------------------------

local AUTO_SELECT_EVENTS = {
    CHAT_MSG_GUILD = "GUILD", CHAT_MSG_OFFICER = "OFFICER",
    CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT", CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
    CHAT_MSG_WHISPER_INFORM = "WHISPER", CHAT_MSG_BN_WHISPER_INFORM = "BN_WHISPER",
}

local function WindowHasGroup(idx, group)
    for _, grp in ipairs({ GetChatWindowMessages(idx) }) do
        if grp == group then return true end
    end
    return false
end

-- An outgoing whisper selects that person's temporary window, else the Whispers tab
local function SelectWhisperTarget(target)
    if CHAT_FRAMES then
        for _, frameName in ipairs(CHAT_FRAMES) do
            local cf = _G[frameName]
            if cf and cf.isTemporary and cf.inUse and cf.isDocked and ns.SameCharacter(cf.chatTarget, target) then
                ns.SafeSelectDockFrame(cf)
                return
            end
        end
    end
    if GudaChatDB.whisperTab and ns.whisperFrame then
        ns.SafeSelectDockFrame(ns.whisperFrame)
    end
end

-- Another sent message stays put when the selected window already shows its group,
-- otherwise selects the first docked non-General window that does
local function SelectWindowForGroup(group)
    local selected = ns.GetUserSelectedFrame()
    if selected and selected ~= ChatFrame2 and WindowHasGroup(selected:GetID(), group) then return end
    for i = 3, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if cf and tab and cf.isDocked and tab:IsShown() and WindowHasGroup(i, group) then
            ns.SafeSelectDockFrame(cf)
            return
        end
    end
end

-- Registered by the header once the tab bars exist. Only the player's own messages count
-- (sender may be a secret string; SameCharacter is taint-safe).
function ns.EnableAutoSelectOnSend()
    local autoSelectFrame = CreateFrame("Frame")
    autoSelectFrame:SetScript("OnEvent", function(self, event, msg, sender)
        if not GudaChatDB or not (GudaChatDB.showTabBar or GudaChatDB.inlineTabBar) then return end
        local group = AUTO_SELECT_EVENTS[event]
        if not group then return end
        local isOutgoing = (event == "CHAT_MSG_WHISPER_INFORM" or event == "CHAT_MSG_BN_WHISPER_INFORM")
        if isOutgoing then
            SelectWhisperTarget(sender)
            return
        end
        if not ns.SameCharacter(sender, ns.UnitFullName("player")) then return end
        SelectWindowForGroup(group)
    end)
    for ev in pairs(AUTO_SELECT_EVENTS) do
        autoSelectFrame:RegisterEvent(ev)
    end
end
