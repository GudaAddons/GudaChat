local addonName, ns = ...

---------------------------------------------------------------------------
-- History channel mapping and filter keys
---------------------------------------------------------------------------

local HISTORY_CHANNEL_LABELS = {
    SAY = "Say", YELL = "Yell", GUILD = "Guild", OFFICER = "Officer",
    WHISPER = "Whisper", WHISPER_INFORM = "Whisper",
    PARTY = "Party", PARTY_LEADER = "Party",
    RAID = "Raid", RAID_LEADER = "Raid",
    INSTANCE_CHAT = "Instance", INSTANCE_CHAT_LEADER = "Instance",
    BN_WHISPER = "Whisper", BN_WHISPER_INFORM = "Whisper",
}
ns.HISTORY_CHANNEL_LABELS = HISTORY_CHANNEL_LABELS

local HISTORY_FILTER_KEYS = {
    "Say", "Yell", "Guild", "Officer", "Whisper", "Party", "Raid", "Instance",
}
ns.HISTORY_FILTER_KEYS = HISTORY_FILTER_KEYS

local CHANNEL_TO_CHATTYPE = {
    Say = "SAY", Yell = "YELL", Guild = "GUILD", Officer = "OFFICER",
    Whisper = "WHISPER", Party = "PARTY", Raid = "RAID",
    Instance = "INSTANCE_CHAT",
}
ns.CHANNEL_TO_CHATTYPE = CHANNEL_TO_CHATTYPE

local REPLAY_CHANNEL_FORMATS = {
    Say = "says",
    Yell = "yells",
}
ns.REPLAY_CHANNEL_FORMATS = REPLAY_CHANNEL_FORMATS

---------------------------------------------------------------------------
-- Message capture for chat history
---------------------------------------------------------------------------

local historyCaptureFrame = CreateFrame("Frame")
local HISTORY_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
}
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
    local level = ns.GetPlayerLevel(senderName)

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

    local maxPerChannel = math.floor((GudaChatDB.historyMax or 500) / #HISTORY_FILTER_KEYS)
    while #bucket > maxPerChannel do
        tremove(bucket, 1)
    end
end)

function ns.RegisterHistoryEvents()
    for _, ev in ipairs(HISTORY_EVENTS) do
        historyCaptureFrame:RegisterEvent(ev)
    end
end

---------------------------------------------------------------------------
-- Replay history on login
---------------------------------------------------------------------------

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

        local levelStr = ""
        if entry.level then
            local lr, lg, lb = ns.GetLevelDifficultyColor(entry.level)
            levelStr = string.format("|cff%02x%02x%02x[%d]|r ", lr*dim*255, lg*dim*255, lb*dim*255, entry.level)
        end

        local timePrefix = ""
        if tsFmt then
            timePrefix = "|cff4d4d4d" .. date(tsFmt, entry.time) .. "|r"
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
ns.ReplayHistory = ReplayHistory

---------------------------------------------------------------------------
-- History viewer frame
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

    ns.CreateDragRegion(f)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -60)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 16)

    -------------------------------------------------------------------
    -- Channel filter tabs
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

    -- Search box
    local searchBox = CreateFrame("EditBox", nil, content, "BackdropTemplate")
    searchBox:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    searchBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -50, 0)
    searchBox:SetHeight(22)
    searchBox:SetFontObject(GameFontHighlight)
    searchBox:SetAutoFocus(false)
    ns.ApplyDarkBackdrop(searchBox, ns.COLOR_HEADER_BG, ns.COLOR_DARK_BORDER)
    searchBox:SetTextInsets(20, 20, 0, 0)

    local searchIcon = searchBox:CreateTexture(nil, "OVERLAY")
    searchIcon:SetSize(12, 12)
    searchIcon:SetPoint("LEFT", searchBox, "LEFT", 5, 0)
    searchIcon:SetTexture(ns.ASSET_PATH .. "search.png")
    searchIcon:SetVertexColor(0.6, 0.6, 0.6)

    local clearSearchBtn = CreateFrame("Button", nil, searchBox)
    clearSearchBtn:SetSize(12, 12)
    clearSearchBtn:SetPoint("RIGHT", searchBox, "RIGHT", -4, 0)
    clearSearchBtn:SetNormalTexture(ns.ASSET_PATH .. "close.png")
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
        self:SetBackdropBorderColor(unpack(ns.COLOR_GOLDEN_A))
        searchIcon:SetVertexColor(1, 1, 1)
    end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then placeholder:Show() end
        self:SetBackdropBorderColor(unpack(ns.COLOR_DARK_BORDER))
        searchIcon:SetVertexColor(0.6, 0.6, 0.6)
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    f:HookScript("OnMouseDown", function()
        searchBox:ClearFocus()
    end)
    content:SetScript("OnMouseDown", function()
        searchBox:ClearFocus()
    end)

    -- Copy button
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
    do
        local fontPath = GudaChatDB.chatFont
        local fontSize = GudaChatDB.historyFontSize
        if fontPath or fontSize then
            local curFont, curSize, curFlags = msgFrame:GetFont()
            msgFrame:SetFont(fontPath or curFont, fontSize or curSize, curFlags)
        end
    end
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
    histSlider:SetBackdrop(ns.BACKDROP_FLAT)
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

    local function GetTimestampFormat()
        local fmt = GetCVar("showTimestamps")
        if not fmt or fmt == "none" then return nil end
        return fmt
    end

    local function FormatColoredEntry(entry)
        local tsFmt = GetTimestampFormat()
        local timeStr = tsFmt and date(tsFmt, entry.time) or date("%H:%M ", entry.time)
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
        if GudaChatDB.showLevel and entry.level then
            local lr, lg, lb = ns.GetLevelDifficultyColor(entry.level)
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

    local lastEntries = {}

    function f:RefreshHistory()
        msgFrame:Clear()
        local entries = GatherEntries()
        lastEntries = entries
        for _, entry in ipairs(entries) do
            msgFrame:AddMessage(FormatColoredEntry(entry))
        end
        msgFrame:ScrollToBottom()
    end

    -- Copy window (colored editbox like Elephant)
    local function CreateColoredCopyFrame()
        local cf = CreateFrame("Frame", "GudaChatHistoryCopyPopup", UIParent, "BackdropTemplate")
        cf:SetSize(500, 350)
        cf:SetPoint("CENTER")
        cf:SetFrameStrata("TOOLTIP")
        ns.ApplyDarkBackdrop(cf, ns.COLOR_COPY_BG, ns.COLOR_GOLDEN_A)
        cf:EnableMouse(true)
        cf:SetMovable(true)
        cf:RegisterForDrag("LeftButton")
        cf:SetScript("OnDragStart", cf.StartMoving)
        cf:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            self:SetUserPlaced(false)
        end)
        tinsert(UISpecialFrames, "GudaChatHistoryCopyPopup")
        ns.CreateCloseButton(cf)

        local label = cf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", cf, "TOPLEFT", 8, -6)
        label:SetText("Ctrl+C to copy. Escape to close.")
        label:SetTextColor(0.6, 0.6, 0.6)

        local scrollFrame = CreateFrame("ScrollFrame", "GudaChatHistoryCopyScroll", cf, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", cf, "TOPLEFT", 8, -22)
        scrollFrame:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -28, 8)

        local eb = CreateFrame("EditBox", nil, scrollFrame)
        eb:SetFontObject(ChatFontNormal)
        if GudaChatDB.chatFont then
            local _, sz, fl = eb:GetFont()
            eb:SetFont(GudaChatDB.chatFont, GudaChatDB.historyFontSize or sz, fl)
        elseif GudaChatDB.historyFontSize then
            local fo, _, fl = eb:GetFont()
            eb:SetFont(fo, GudaChatDB.historyFontSize, fl)
        end
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(0)
        eb:SetWidth(scrollFrame:GetWidth() or 440)
        eb:SetScript("OnEscapePressed", function() cf:Hide() end)
        eb:SetScript("OnCursorChanged", function(self, x, y, w, h)
            local scroll = -y
            local maxScroll = max(0, self:GetHeight() - scrollFrame:GetHeight())
            scrollFrame:SetVerticalScroll(min(max(0, scroll), maxScroll))
        end)
        scrollFrame:SetScrollChild(eb)

        cf.editBox = eb
        cf.scrollFrame = scrollFrame
        cf:Hide()
        return cf
    end

    copyBtn:SetScript("OnClick", function()
        if f.copyFrame and f.copyFrame:IsShown() then
            f.copyFrame:Hide()
            return
        end
        if #lastEntries == 0 then return end

        if not f.copyFrame then
            f.copyFrame = CreateColoredCopyFrame()
        end

        local eb = f.copyFrame.editBox
        eb:SetWidth(f.copyFrame.scrollFrame:GetWidth() or 440)
        eb:SetText("")
        eb:SetMaxLetters(0)
        for i = #lastEntries, 1, -1 do
            eb:SetCursorPosition(0)
            eb:Insert(FormatColoredEntry(lastEntries[i]) .. "\n")
        end
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

    local function SelectChannelTab(id)
        PanelTemplates_SetTab(f, id)
        selectedFilter = channelTabDefs[id].key
        if f.RefreshHistory then f:RefreshHistory() end
    end

    for i, tab in ipairs(channelTabs) do
        tab:SetScript("OnClick", function() SelectChannelTab(i) end)
    end

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
        ns.historyFrame = historyFrame
    end
    if historyFrame:IsShown() then
        historyFrame:Hide()
    else
        historyFrame:Show()
    end
end
ns.ToggleHistory = ToggleHistory
