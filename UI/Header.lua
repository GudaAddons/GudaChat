local addonName, ns = ...

---------------------------------------------------------------------------
-- Chat header bar (hover-reveal, icon buttons)
---------------------------------------------------------------------------

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

local function SetTooltipFontSize(size)
    if GameTooltipTextLeft1 then
        local font, _, flags = GameTooltipTextLeft1:GetFont()
        if font then GameTooltipTextLeft1:SetFont(font, size, flags) end
    end
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
            SetTooltipFontSize(12)
            GameTooltip:Show()
        end
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
-- Custom chat context menu
---------------------------------------------------------------------------

local FONT_SIZES = { 12, 14, 16, 18, 20, 24, 27 }

local contextMenu, fontSubMenu

local function GetSelectedChatFrameIndex()
    local current = FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame()
    if current then
        for i = 1, NUM_CHAT_WINDOWS do
            if _G["ChatFrame" .. i] == current then return i end
        end
        -- Check temporary frames (index > NUM_CHAT_WINDOWS)
        if CHAT_FRAMES then
            for _, name in ipairs(CHAT_FRAMES) do
                local cf = _G[name]
                if cf == current then return cf:GetID() end
            end
        end
    end
    local selected = SELECTED_DOCK_FRAME or SELECTED_CHAT_FRAME
    if selected then
        for i = 1, NUM_CHAT_WINDOWS do
            if _G["ChatFrame" .. i] == selected then return i end
        end
        if CHAT_FRAMES then
            for _, name in ipairs(CHAT_FRAMES) do
                local cf = _G[name]
                if cf == selected then return cf:GetID() end
            end
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
    ns.ApplyDarkBackdrop(f)
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

local function ShowContextMenu(anchor, overrideIndex)
    if not contextMenu then
        local f = CreateFrame("Frame", "GudaChatContextMenu", UIParent, "BackdropTemplate")
        f:SetFrameStrata("TOOLTIP")
        f:SetFrameLevel(205)
        ns.ApplyDarkBackdrop(f)
        f:Hide()
        tinsert(UISpecialFrames, "GudaChatContextMenu")
        f:SetScript("OnHide", function()
            if fontSubMenu then fontSubMenu:Hide() end
        end)
        contextMenu = f
    end

    for _, child in ipairs({contextMenu:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local id = overrideIndex or GetSelectedChatFrameIndex()
    local cf = _G["ChatFrame" .. id]
    local yOff = -4
    local maxW = 160

    -- Helper to close a window, routing its content back to General
    local function RemoveWindow()
        local chatFrame = _G["ChatFrame" .. id]
        if chatFrame then
            if chatFrame.isTemporary then
                -- Temporary whisper windows: clear exclusion lists so
                -- whispers route back to General / Whispers windows
                local target = chatFrame.chatTarget
                if FCF_PopInWindow then
                    FCF_PopInWindow(chatFrame)
                elseif FCF_RestoreChatsToFrame then
                    FCF_RestoreChatsToFrame(ChatFrame1, chatFrame)
                    FCF_Close(chatFrame)
                else
                    -- Manual fallback: clear exclusion list entries
                    if target then
                        -- Remove from all docked frames' exclusion lists
                        ns.ForEachChatWindow(function(cf)
                            if cf.excludePrivateMessageList then
                                cf.excludePrivateMessageList[strlower(target)] = nil
                            end
                            if cf.excludeBNPrivateMessageList then
                                cf.excludeBNPrivateMessageList[strlower(target)] = nil
                            end
                        end)
                    end
                    FCF_Close(chatFrame)
                end
                -- Ensure General receives whispers again
                ChatFrame_AddMessageGroup(ChatFrame1, "WHISPER")
                ChatFrame_AddMessageGroup(ChatFrame1, "BN_WHISPER")
            else
                -- Permanent windows: move messages/channels to General, then close
                if GetChatWindowMessages then
                    local msgs = { GetChatWindowMessages(id) }
                    for _, msgGroup in ipairs(msgs) do
                        ChatFrame_AddMessageGroup(ChatFrame1, msgGroup)
                        if AddChatWindowMessages then
                            AddChatWindowMessages(1, msgGroup)
                        end
                    end
                end
                if GetChatWindowChannels then
                    local channels = { GetChatWindowChannels(id) }
                    for i = 1, #channels, 2 do
                        local chName = channels[i]
                        if type(chName) == "string" then
                            if AddChatWindowChannel then
                                AddChatWindowChannel(1, chName)
                            end
                            if ChatFrame1.channelList then
                                tinsert(ChatFrame1.channelList, chName)
                            end
                            if ChatFrame1.zoneChannelList then
                                tinsert(ChatFrame1.zoneChannelList, chName)
                            end
                        end
                    end
                end
                FCF_Close(chatFrame)
            end
        end
        contextMenu:Hide()
        FCF_SelectDockFrame(ChatFrame1)
    end

    -------------------------------------------------------------------
    -- Actions
    -------------------------------------------------------------------
    local renameBtn = CreateContextMenuItem(contextMenu, "Rename Window", function()
        local chatFrame = _G["ChatFrame" .. id]
        if chatFrame then
            ns._renamingFrame = chatFrame
            ns._renamingIndex = id
            StaticPopup_Show("GUDACHAT_RENAME_WINDOW")
        end
        contextMenu:Hide()
    end)
    renameBtn:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
    renameBtn:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
    yOff = yOff - 20

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

    if id ~= 1 then
        -- Use "Close Whisper Window" for temp whisper tabs, "Remove Window" otherwise
        local isTemp = cf and cf.isTemporary
        local removeLabel = isTemp and "Close Whisper Window" or "Remove Window"
        local removeBtn = CreateContextMenuItem(contextMenu, removeLabel, function()
            RemoveWindow()
        end)
        removeBtn:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
        removeBtn:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
        yOff = yOff - 20

        -- "Leave Channel" for channel-based windows
        if not isTemp then
            local tabName = GetChatTabName(id)
            if tabName and GetChannelName then
                local chNum = GetChannelName(tabName)
                if chNum and chNum > 0 then
                    local leaveBtn = CreateContextMenuItem(contextMenu, "Leave " .. tabName, function()
                        LeaveChannelByName(tabName)
                        RemoveWindow()
                    end)
                    leaveBtn:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
                    leaveBtn:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
                    yOff = yOff - 20
                end
            end
        end
    end

    -------------------------------------------------------------------
    -- Display section
    -------------------------------------------------------------------
    local displaySep = CreateContextMenuItem(contextMenu, "Display", nil, true)
    displaySep:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
    displaySep:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
    yOff = yOff - 20

    local fontBtn = CreateContextMenuItem(contextMenu, "Font Size", nil, false, true)
    fontBtn:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
    fontBtn:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
    yOff = yOff - 20

    local fsm = fontSubMenu or CreateFontSubMenu()

    fontBtn:SetScript("OnEnter", function(self)
        local curCf = _G["ChatFrame" .. id]
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

    local bgBtn = CreateContextMenuItem(contextMenu, "Background")
    bgBtn:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
    bgBtn:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
    yOff = yOff - 20

    local swatch = bgBtn:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(14, 14)
    swatch:SetPoint("RIGHT", bgBtn, "RIGHT", -8, 0)
    swatch:SetTexture("Interface\\Buttons\\WHITE8x8")

    local r, g, b, a = 0, 0, 0, 0.5
    if cf then
        r, g, b = FCF_GetCurrentChatFrameBackgroundColor and FCF_GetCurrentChatFrameBackgroundColor(cf) or 0, 0, 0
        a = cf.oldAlpha or 0.25
    end
    swatch:SetVertexColor(r, g, b, math.max(a, 0.3))

    local swatchBorder = bgBtn:CreateTexture(nil, "OVERLAY")
    swatchBorder:SetSize(16, 16)
    swatchBorder:SetPoint("CENTER", swatch, "CENTER", 0, 0)
    swatchBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
    swatchBorder:SetVertexColor(0.5, 0.5, 0.5, 0.8)
    swatchBorder:SetDrawLayer("ARTWORK", -1)

    bgBtn:SetScript("OnClick", function()
        local chatFrame = _G["ChatFrame" .. id]
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

    -------------------------------------------------------------------
    -- Settings
    -------------------------------------------------------------------
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
    contextMenu:SetPoint("BOTTOM", anchor, "TOP", 0, 2)
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
-- Uses Blizzard's native Blizzard_CombatLog filter system:
--   Filter 1 = Self (My Actions)
--   Filter 2 = Everything
--   Filter 3 = What Happened to Me?
--   Filter 4 = Kills
---------------------------------------------------------------------------

local combatLogFilter = "mine"

-- Subtab bar UI
local combatSubTabs

local function SwitchCombatLogFilter(key)
    combatLogFilter = key
    if not Blizzard_CombatLog_Filters then return end
    local filters = Blizzard_CombatLog_Filters.filters
    if not filters then return end

    -- Use direct index: on TBC Anniversary there are typically 2 filters
    -- Filter 1 = My Actions (source = player), Filter 2 = What Happened to Me (dest = player)
    -- Try both orderings by checking filter count
    local total = #filters
    local idx
    if key == "mine" then
        idx = 1
    elseif key == "tome" then
        -- "What happened to me?" is the last filter before Kills (if present)
        -- On 2-filter setups it's index 2; on 4-filter setups it's index 3
        if total >= 4 then idx = 3 else idx = total end
    end

    if not idx or not filters[idx] then return end

    Blizzard_CombatLog_CurrentSettings = filters[idx]
    Blizzard_CombatLog_Filters.currentFilter = idx
    if Blizzard_CombatLog_ApplyFilters then
        Blizzard_CombatLog_ApplyFilters(filters[idx])
    end
    if Blizzard_CombatLog_Refilter then
        Blizzard_CombatLog_Refilter()
    end
end

local function CreateCombatSubTabs(header)
    local bar = CreateFrame("Frame", "GudaChatCombatSubTabs", UIParent, "BackdropTemplate")
    bar:SetHeight(20)
    bar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 1)
    bar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 1)
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(101)

    ns.ApplyDarkBackdrop(bar, { 0.05, 0.05, 0.05, 0.75 }, { 0.25, 0.25, 0.25, 0.5 })
    bar:EnableMouse(true)
    bar:SetAlpha(0)
    bar:Hide()

    local tabs = {}
    local tabDefs = {
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
            SwitchCombatLogFilter(def.key)
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
-- Chat window subtab bar (below header, like combat subtabs)
---------------------------------------------------------------------------

local chatSubTabs
local chatSubTabButtons = {}

-- Tab blink state: tracks which frameIndex values have unread messages
local blinkingTabs = {}

-- Chat events that should trigger tab blink notifications
local BLINK_EVENTS = {
    CHAT_MSG_GUILD = "GUILD", CHAT_MSG_OFFICER = "OFFICER",
    CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT", CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
    CHAT_MSG_WHISPER = "WHISPER", CHAT_MSG_BN_WHISPER = "BN_WHISPER",
}

local blinkListener = CreateFrame("Frame")
blinkListener:SetScript("OnEvent", function(self, event, msg, sender)
    if not GudaChatDB or not GudaChatDB.showTabBar then return end
    local msgGroup = BLINK_EVENTS[event]
    if not msgGroup then return end

    local selectedIdx = GetSelectedChatFrameIndex()
    local changed = false

    -- Check permanent windows
    for i = 1, NUM_CHAT_WINDOWS do
        if i ~= selectedIdx and i ~= 2 then
            local cf = _G["ChatFrame" .. i]
            if cf and (cf.isDocked or i == 1) then
                local msgs = { GetChatWindowMessages(i) }
                for _, grp in ipairs(msgs) do
                    if grp == msgGroup or grp == event:gsub("CHAT_MSG_", "") then
                        if not blinkingTabs[i] then
                            blinkingTabs[i] = true
                            changed = true
                        end
                    end
                end
            end
        end
    end

    -- Check temporary whisper windows (match sender to chatTarget)
    if (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER") and CHAT_FRAMES then
        local senderShort = sender and sender:match("^([^%-]+)") or sender
        for _, frameName in ipairs(CHAT_FRAMES) do
            local cf = _G[frameName]
            if cf and cf.isTemporary and cf.inUse and cf.isDocked then
                local idx = cf:GetID()
                if idx ~= selectedIdx then
                    local target = cf.chatTarget
                    local targetShort = target and target:match("^([^%-]+)") or target
                    if targetShort and senderShort and targetShort:lower() == senderShort:lower() then
                        if not blinkingTabs[idx] then
                            blinkingTabs[idx] = true
                            changed = true
                        end
                    end
                end
            end
        end
    end

    if changed then
        if ns.RefreshChatSubTabs then ns.RefreshChatSubTabs() end
        if ns.ShowTabBar then ns.ShowTabBar() end
    end
end)

for ev in pairs(BLINK_EVENTS) do
    blinkListener:RegisterEvent(ev)
end

-- Clear blink when a tab is selected
hooksecurefunc("FCF_SelectDockFrame", function(cf)
    if not cf then return end
    local cleared = false
    for i = 1, NUM_CHAT_WINDOWS do
        if _G["ChatFrame" .. i] == cf then
            if blinkingTabs[i] then
                blinkingTabs[i] = nil
                cleared = true
            end
            break
        end
    end
    if not cleared and CHAT_FRAMES then
        for _, name in ipairs(CHAT_FRAMES) do
            if _G[name] == cf then
                local idx = cf:GetID()
                if blinkingTabs[idx] then
                    blinkingTabs[idx] = nil
                end
                break
            end
        end
    end
end)

-- Public helpers
function ns.HasBlinkingTabs()
    return next(blinkingTabs) ~= nil
end
function ns.StartTabBlink(frameIndex)
    blinkingTabs[frameIndex] = true
end
function ns.StopTabBlink(frameIndex)
    blinkingTabs[frameIndex] = nil
end

-- Map common tab names to Blizzard ChatTypeInfo keys
local TAB_NAME_TO_CHATTYPE = {
    ["Guild"]    = "GUILD",
    ["Party"]    = "PARTY",
    ["Raid"]     = "RAID",
    ["Whispers"] = "WHISPER",
    ["Officer"]  = "OFFICER",
    ["Say"]      = "SAY",
    ["Yell"]     = "YELL",
}
local TAB_COLOR_DEFAULT = { 0.8, 0.6, 0.0 }
local TAB_COLOR_GENERAL = { 1.0, 1.0, 0.0 }

local function GetTabColor(name, frameIndex)
    if name == "General" then return TAB_COLOR_GENERAL end

    -- Direct name → ChatTypeInfo lookup (Guild, Party, Raid, etc.)
    local chatType = TAB_NAME_TO_CHATTYPE[name]
    if chatType and ChatTypeInfo[chatType] then
        local info = ChatTypeInfo[chatType]
        return { info.r, info.g, info.b }
    end

    -- Channel-based windows (Trade, LFG, custom channels, etc.)
    -- GetChatWindowChannels returns channel names; resolve number via GetChannelName
    if frameIndex and GetChatWindowChannels and GetChannelName then
        local channels = { GetChatWindowChannels(frameIndex) }
        for i = 1, #channels do
            local chName = channels[i]
            if type(chName) == "string" then
                local chNum = GetChannelName(chName)
                if chNum and chNum > 0 then
                    local info = ChatTypeInfo["CHANNEL" .. chNum]
                    if info then return { info.r, info.g, info.b } end
                end
            end
        end
    end

    -- Windows with message groups — use the first group's color
    if frameIndex and GetChatWindowMessages then
        local msgs = { GetChatWindowMessages(frameIndex) }
        if #msgs > 0 and ChatTypeInfo[msgs[1]] then
            local info = ChatTypeInfo[msgs[1]]
            return { info.r, info.g, info.b }
        end
    end

    return TAB_COLOR_DEFAULT
end

local overflowDropdown  -- persistent overflow menu frame


-- Drag state for tab reordering
local dragState = {
    dragging = false,
    sourceIdx = nil,   -- index in allTabs being dragged
    sourceBtn = nil,   -- the button frame being dragged
    insertIdx = nil,   -- insertion point (drop before this index)
}

-- Persistent insertion indicator line
local dragIndicator

local function ApplySavedTabOrder(allTabs)
    local saved = GudaChatDB.tabOrder
    if not saved or #saved == 0 then return end
    -- Build lookup: frameIndex → position in saved order
    local orderMap = {}
    for pos, frameIdx in ipairs(saved) do
        orderMap[frameIdx] = pos
    end
    local nextPos = #saved + 1
    table.sort(allTabs, function(a, b)
        local posA = orderMap[a.frameIndex] or nextPos
        local posB = orderMap[b.frameIndex] or nextPos
        if posA == posB then
            return a.frameIndex < b.frameIndex
        end
        return posA < posB
    end)
end

local function SaveTabOrder(allTabs)
    local order = {}
    for _, def in ipairs(allTabs) do
        tinsert(order, def.frameIndex)
    end
    GudaChatDB.tabOrder = order
end

local function RefreshChatSubTabs(header)
    if not chatSubTabs then return end
    if not GudaChatDB.showTabBar then
        chatSubTabs:Hide()
        return
    end

    for _, btn in ipairs(chatSubTabButtons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    wipe(chatSubTabButtons)
    if overflowDropdown then overflowDropdown:Hide() end

    local selectedIndex = GetSelectedChatFrameIndex()

    -- 1) Collect all tab definitions: { name, col, frameIndex, cf, isTemp }
    local allTabs = {}

    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if cf and tab then
            local isDocked = cf.isDocked or (i == 1)
            local shown = (i == 1) or tab:IsShown()
            if isDocked and shown and i ~= 2 then
                -- Hide whisper tab from tab bar when setting is disabled
                if not GudaChatDB.whisperTab and ns.whisperFrame and cf == ns.whisperFrame then
                    -- skip
                else
                    local name = GetChatTabName(i)
                    local col = GetTabColor(name, i)
                    tinsert(allTabs, { name = name, col = col, frameIndex = i, cf = cf })
                end
            end
        end
    end

    if CHAT_FRAMES then
        for _, frameName in ipairs(CHAT_FRAMES) do
            local cf = _G[frameName]
            if cf and cf.isTemporary and cf.inUse and cf.isDocked then
                local idx = cf:GetID()
                local tab = _G[frameName .. "Tab"]
                local name = tab and (tab.Text and tab.Text:GetText() or tab:GetText()) or ("Chat " .. idx)
                local whisperInfo = (cf.chatType == "WHISPER" or cf.chatType == "BN_WHISPER") and ChatTypeInfo["WHISPER"]
                local col = whisperInfo and { whisperInfo.r, whisperInfo.g, whisperInfo.b } or GetTabColor(name, idx)
                tinsert(allTabs, { name = name, col = col, frameIndex = idx, cf = cf, isTemp = true })
            end
        end
    end

    -- 1b) Apply saved tab order
    ApplySavedTabOrder(allTabs)

    -- 2) Measure which tabs fit; reserve space for overflow button
    local barWidth = chatSubTabs:GetWidth() or 300
    local overflowBtnWidth = 16  -- width of overflow icon button
    local xOff = 6
    local fitCount = #allTabs  -- assume all fit

    -- Measure total width needed
    local tempFont = chatSubTabs:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local widths = {}
    for idx, def in ipairs(allTabs) do
        tempFont:SetText(def.name)
        widths[idx] = tempFont:GetStringWidth() + 8
    end
    tempFont:Hide()

    -- Find which tab is selected
    local selectedTabIdx
    for idx, def in ipairs(allTabs) do
        if def.cf and def.cf:IsShown() then
            selectedTabIdx = idx
            break
        end
    end

    -- Find how many fit
    local totalW = 6
    local allFit = true
    for idx = 1, #allTabs do
        totalW = totalW + widths[idx] + 8
    end
    if totalW > barWidth then
        -- Not all fit — recalculate with reserved space for overflow icon
        allFit = false
        local maxUsable = barWidth - overflowBtnWidth - 12
        totalW = 6
        fitCount = 0
        for idx = 1, #allTabs do
            totalW = totalW + widths[idx] + 8
            if totalW > maxUsable then
                break
            end
            fitCount = idx
        end
        -- If selected tab is in overflow, swap it with the last visible tab
        if selectedTabIdx and selectedTabIdx > fitCount and fitCount > 0 then
            local swapIdx = fitCount
            allTabs[swapIdx], allTabs[selectedTabIdx] = allTabs[selectedTabIdx], allTabs[swapIdx]
            widths[swapIdx], widths[selectedTabIdx] = widths[selectedTabIdx], widths[swapIdx]
            -- Recalculate fitCount since widths changed
            totalW = 6
            fitCount = 0
            for idx = 1, #allTabs do
                totalW = totalW + widths[idx] + 8
                if totalW > maxUsable then
                    break
                end
                fitCount = idx
            end
        end
    end

    -- 3) Create visible tab buttons
    local function IsSelectedFrame(cf)
        return cf and cf:IsShown()
    end

    local DRAG_THRESHOLD = 5  -- pixels before a click becomes a drag

    -- Create / fetch the insertion indicator (thin vertical golden line)
    if not dragIndicator then
        dragIndicator = chatSubTabs:CreateTexture(nil, "OVERLAY")
        dragIndicator:SetTexture("Interface\\Buttons\\WHITE8x8")
        dragIndicator:SetVertexColor(0.8, 0.6, 0.0, 1)
        dragIndicator:SetSize(2, 14)
        dragIndicator:Hide()
    end

    -- Compute insertion index from cursor X position
    -- Returns the index in allTabs *before which* the dragged tab should be inserted
    local function GetInsertIndex(srcIdx)
        local scale = chatSubTabs:GetEffectiveScale()
        local cursorX = GetCursorPosition() / scale
        -- Walk visible tab buttons and find the gap the cursor falls into
        for _, tabBtn in ipairs(chatSubTabButtons) do
            if tabBtn.tabIdx then
                local left = tabBtn:GetLeft()
                local right = tabBtn:GetRight()
                if left and right then
                    local mid = (left + right) / 2
                    if cursorX < mid then
                        return tabBtn.tabIdx
                    end
                end
            end
        end
        -- Past the last tab → insert at end
        return fitCount + 1
    end

    -- Position the indicator line at the gap before `insertIdx`
    local function UpdateIndicator(insertIdx, srcIdx)
        if not insertIdx or insertIdx == srcIdx or insertIdx == srcIdx + 1 then
            -- No-op position (would result in no move)
            dragIndicator:Hide()
            dragState.insertIdx = nil
            return
        end
        dragState.insertIdx = insertIdx
        -- Find anchor: the left edge of the button at insertIdx, or right edge of last button
        local anchorBtn
        if insertIdx <= fitCount then
            for _, tabBtn in ipairs(chatSubTabButtons) do
                if tabBtn.tabIdx == insertIdx then
                    anchorBtn = tabBtn
                    break
                end
            end
        end
        dragIndicator:ClearAllPoints()
        if anchorBtn then
            dragIndicator:SetPoint("RIGHT", anchorBtn, "LEFT", -3, 0)
        else
            -- After last visible tab
            local lastBtn
            for _, tabBtn in ipairs(chatSubTabButtons) do
                if tabBtn.tabIdx then lastBtn = tabBtn end
            end
            if lastBtn then
                dragIndicator:SetPoint("LEFT", lastBtn, "RIGHT", 3, 0)
            end
        end
        dragIndicator:Show()
    end

    local function FinishTabDrag(srcBtn)
        if not dragState.dragging then return end
        local insertIdx = dragState.insertIdx
        local srcIdx = dragState.sourceIdx
        if insertIdx and srcIdx and insertIdx ~= srcIdx and insertIdx ~= srcIdx + 1 then
            local moved = table.remove(allTabs, srcIdx)
            if moved then
                local dest = insertIdx
                if dest > srcIdx then dest = dest - 1 end
                table.insert(allTabs, dest, moved)
                SaveTabOrder(allTabs)
            end
        end
        dragIndicator:Hide()
        dragState.dragging = false
        dragState.sourceIdx = nil
        dragState.sourceBtn = nil
        dragState.insertIdx = nil
        srcBtn:SetScript("OnUpdate", nil)
        RefreshChatSubTabs(header)
    end

    local function CreateTabBtn(def, parent, tabIdx)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetHeight(16)
        btn.tabIdx = tabIdx

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", btn, "LEFT", 0, 0)
        text:SetText(def.name)
        btn.text = text

        local col = def.col
        if IsSelectedFrame(def.cf) then
            text:SetTextColor(col[1], col[2], col[3], 1)
        else
            text:SetTextColor(col[1] * 0.5, col[2] * 0.5, col[3] * 0.5, 0.8)
        end

        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetScript("OnClick", function(self, button)
            if dragState.dragging then
                FinishTabDrag(self)
                return
            end
            if button == "RightButton" then
                ShowContextMenu(self, def.frameIndex)
            else
                FCF_SelectDockFrame(def.cf)
            end
        end)

        btn:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                local cx, cy = GetCursorPosition()
                local scale = self:GetEffectiveScale()
                dragState.startX = cx / scale
                dragState.startY = cy / scale
                dragState.pending = true
                dragState.pendingBtn = self
                dragState.pendingIdx = self.tabIdx
                self:SetScript("OnUpdate", function(self)
                    if not dragState.pending and not dragState.dragging then
                        self:SetScript("OnUpdate", nil)
                        return
                    end
                    if not IsMouseButtonDown("LeftButton") then
                        if dragState.dragging then
                            FinishTabDrag(self)
                        end
                        dragState.pending = false
                        self:SetScript("OnUpdate", nil)
                        return
                    end
                    -- Check drag threshold
                    if dragState.pending then
                        local cx, cy = GetCursorPosition()
                        local scale = self:GetEffectiveScale()
                        local dx = cx / scale - dragState.startX
                        local dy = cy / scale - dragState.startY
                        if (dx * dx + dy * dy) > DRAG_THRESHOLD * DRAG_THRESHOLD then
                            dragState.pending = false
                            dragState.dragging = true
                            dragState.sourceIdx = dragState.pendingIdx
                            dragState.sourceBtn = self
                            self.text:SetTextColor(col[1] * 0.3, col[2] * 0.3, col[3] * 0.3, 0.5)
                        end
                    end
                    -- Update insertion indicator while dragging
                    if dragState.dragging then
                        local ins = GetInsertIndex(dragState.sourceIdx)
                        UpdateIndicator(ins, dragState.sourceIdx)
                    end
                end)
            end
        end)

        btn:SetScript("OnEnter", function(self)
            self.text:SetTextColor(col[1], col[2], col[3], 1)
            if chatHeader then chatHeader:SetAlpha(1) end
        end)
        btn:SetScript("OnLeave", function(self)
            if dragState.dragging and dragState.sourceBtn == self then return end
            if self.blinking then return end
            if IsSelectedFrame(def.cf) then
                self.text:SetTextColor(col[1], col[2], col[3], 1)
            else
                self.text:SetTextColor(col[1] * 0.5, col[2] * 0.5, col[3] * 0.5, 0.8)
            end
        end)

        -- Blink animation for unread messages
        if blinkingTabs[def.frameIndex] then
            btn.blinking = true
            local blinkAG = text:CreateAnimationGroup()
            blinkAG:SetLooping("BOUNCE")
            local fade = blinkAG:CreateAnimation("Alpha")
            fade:SetFromAlpha(1)
            fade:SetToAlpha(0.2)
            fade:SetDuration(0.5)
            fade:SetSmoothing("IN_OUT")
            blinkAG:Play()
            text:SetTextColor(col[1], col[2], col[3], 1)
            btn.blinkAG = blinkAG
        end

        return btn
    end

    for idx = 1, fitCount do
        local def = allTabs[idx]
        local btn = CreateTabBtn(def, chatSubTabs, idx)
        btn:SetWidth(widths[idx])
        btn:SetPoint("LEFT", chatSubTabs, "LEFT", xOff, 0)
        xOff = xOff + widths[idx] + 8
        tinsert(chatSubTabButtons, btn)
    end

    -- 4) Create overflow button if there are hidden tabs
    if fitCount < #allTabs then
        local moreBtn = CreateFrame("Button", nil, chatSubTabs)
        moreBtn:SetSize(12, 12)
        moreBtn:SetPoint("RIGHT", chatSubTabs, "RIGHT", -6, 0)

        local moreIcon = moreBtn:CreateTexture(nil, "OVERLAY")
        moreIcon:SetAllPoints()
        moreIcon:SetTexture(ns.ASSET_PATH .. "more.png")
        moreIcon:SetVertexColor(0.6, 0.6, 0.6, 1)
        moreBtn.icon = moreIcon

        moreBtn:SetScript("OnEnter", function(self)
            self.icon:SetVertexColor(1, 1, 1, 1)
            if chatHeader then chatHeader:SetAlpha(1) end
        end)
        moreBtn:SetScript("OnLeave", function(self)
            self.icon:SetVertexColor(0.6, 0.6, 0.6, 1)
        end)

        moreBtn:SetScript("OnClick", function(self)
            if overflowDropdown and overflowDropdown:IsShown() then
                overflowDropdown:Hide()
                return
            end

            if not overflowDropdown then
                overflowDropdown = CreateFrame("Frame", "GudaChatTabOverflow", UIParent, "BackdropTemplate")
                overflowDropdown:SetFrameStrata("TOOLTIP")
                overflowDropdown:SetClampedToScreen(true)
                ns.ApplyDarkBackdrop(overflowDropdown, { 0.08, 0.08, 0.08, 0.95 }, { 0.3, 0.3, 0.3, 0.6 })
                overflowDropdown:EnableMouse(true)
            end

            -- Clear old children
            for _, child in ipairs({ overflowDropdown:GetChildren() }) do
                child:Hide()
                child:SetParent(nil)
            end

            local itemHeight = 18
            local padding = 6
            local maxW = 60
            local items = {}

            for idx = fitCount + 1, #allTabs do
                local def = allTabs[idx]
                local item = CreateFrame("Button", nil, overflowDropdown)
                item:SetHeight(itemHeight)

                local text = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                text:SetPoint("LEFT", item, "LEFT", 8, 0)
                text:SetText(def.name)
                item.text = text

                local col = def.col
                if def.frameIndex == selectedIndex then
                    text:SetTextColor(col[1], col[2], col[3], 1)
                else
                    text:SetTextColor(col[1] * 0.5, col[2] * 0.5, col[3] * 0.5, 0.8)
                end

                item:SetScript("OnEnter", function(self)
                    self.text:SetTextColor(col[1], col[2], col[3], 1)
                end)
                item:SetScript("OnLeave", function(self)
                    if def.frameIndex == GetSelectedChatFrameIndex() then
                        self.text:SetTextColor(col[1], col[2], col[3], 1)
                    else
                        self.text:SetTextColor(col[1] * 0.5, col[2] * 0.5, col[3] * 0.5, 0.8)
                    end
                end)
                item:SetScript("OnClick", function()
                    FCF_SelectDockFrame(def.cf)
                    overflowDropdown:Hide()
                end)

                local w = text:GetStringWidth() + 16
                if w > maxW then maxW = w end
                tinsert(items, item)
            end

            local totalH = #items * itemHeight + padding * 2
            overflowDropdown:SetSize(maxW, totalH)
            -- Anchor above the "..." button
            overflowDropdown:ClearAllPoints()
            overflowDropdown:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 2)

            for i, item in ipairs(items) do
                item:SetWidth(maxW)
                item:SetPoint("TOPLEFT", overflowDropdown, "TOPLEFT", 0, -padding - (i - 1) * itemHeight)
                item:Show()
            end

            overflowDropdown:Show()
        end)

        tinsert(chatSubTabButtons, moreBtn)
    end
end
ns.RefreshChatSubTabs = RefreshChatSubTabs

local function CreateChatSubTabs(header)
    local bar = CreateFrame("Frame", "GudaChatSubTabs", UIParent, "BackdropTemplate")
    bar:SetHeight(20)
    bar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 1)
    bar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 1)
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(101)

    ns.ApplyDarkBackdrop(bar, { 0.05, 0.05, 0.05, 0.75 }, { 0.25, 0.25, 0.25, 0.5 })
    bar:EnableMouse(true)
    bar:SetAlpha(0)

    -- Independent hover fade for the tab bar
    local tabBarHovering = false
    local tabBarFadeIn, tabBarFadeOut

    local function ShowTabBar()
        if tabBarHovering then return end
        tabBarHovering = true
        if tabBarFadeOut then tabBarFadeOut:Stop() end
        tabBarFadeIn = bar:CreateAnimationGroup()
        local anim = tabBarFadeIn:CreateAnimation("Alpha")
        anim:SetFromAlpha(bar:GetAlpha())
        anim:SetToAlpha(1)
        anim:SetDuration(0.15)
        tabBarFadeIn:SetScript("OnFinished", function() bar:SetAlpha(1) end)
        tabBarFadeIn:Play()
    end

    local function HideTabBar()
        if not tabBarHovering then return end
        tabBarHovering = false
        C_Timer.After(0.3, function()
            if tabBarHovering then return end
            if ns.HasBlinkingTabs and ns.HasBlinkingTabs() then
                tabBarHovering = true
                return
            end
            if bar:IsMouseOver() or (ns._tabLabelBtn and ns._tabLabelBtn:IsMouseOver()) or (overflowDropdown and overflowDropdown:IsShown() and overflowDropdown:IsMouseOver()) then
                tabBarHovering = true
                return
            end
            if tabBarFadeIn then tabBarFadeIn:Stop() end
            tabBarFadeOut = bar:CreateAnimationGroup()
            local anim = tabBarFadeOut:CreateAnimation("Alpha")
            anim:SetFromAlpha(bar:GetAlpha())
            anim:SetToAlpha(0)
            anim:SetDuration(0.25)
            tabBarFadeOut:SetScript("OnFinished", function()
                bar:SetAlpha(0)
                if overflowDropdown then overflowDropdown:Hide() end
            end)
            tabBarFadeOut:Play()
        end)
    end

    local tabBarMonitor = CreateFrame("Frame")
    tabBarMonitor:SetScript("OnUpdate", function()
        if not bar:IsShown() then return end
        local overBar = bar:IsMouseOver()
        local overLabel = ns._tabLabelBtn and ns._tabLabelBtn:IsMouseOver()
        local overOverflow = overflowDropdown and overflowDropdown:IsShown() and overflowDropdown:IsMouseOver()
        if overBar or overLabel or overOverflow then
            ShowTabBar()
        else
            HideTabBar()
        end
    end)

    ns.ShowTabBar = ShowTabBar

    chatSubTabs = bar
    ns.chatSubTabs = bar
    return bar
end

---------------------------------------------------------------------------
-- Whisper frame setup
---------------------------------------------------------------------------

local function EnforceWhisperGroups(cf, idx)
    -- Add whisper message groups so Blizzard routes whispers to this frame
    ChatFrame_AddMessageGroup(cf, "WHISPER")
    ChatFrame_AddMessageGroup(cf, "BN_WHISPER")
    ChatFrame_AddMessageGroup(cf, "WHISPER_INFORM")
    ChatFrame_AddMessageGroup(cf, "BN_WHISPER_INFORM")
    -- Server-side registration so config persists across reloads
    if idx and AddChatWindowMessages then
        AddChatWindowMessages(idx, "WHISPER")
        AddChatWindowMessages(idx, "BN_WHISPER")
        AddChatWindowMessages(idx, "WHISPER_INFORM")
        AddChatWindowMessages(idx, "BN_WHISPER_INFORM")
    end
end

local function SetupWhisperFrame()
    local function InitWhisperFrame(cf, idx)
        ns.whisperFrame = cf
        ns.whisperFrameIndex = idx
        GudaChatDB.whisperFrameIndex = idx
        EnforceWhisperGroups(cf, idx)
        -- Ensure the frame is docked so FCF_SelectDockFrame can show it
        if not cf.isDocked then
            FCF_DockFrame(cf)
        end
        -- Sync with ChatFrame1 so it shares the same area
        cf:ClearAllPoints()
        cf:SetPoint(ChatFrame1:GetPoint(1))
        cf:SetSize(ChatFrame1:GetSize())
        -- Always ensure font is set — AddMessage silently fails without one
        local font, size, flags = cf:GetFont()
        if not font then
            font, size, flags = ChatFrame1:GetFont()
        end
        if GudaChatDB.chatFont then
            font = GudaChatDB.chatFont
        end
        if font then
            cf:SetFont(font, size or 14, flags or "")
        end
        cf:SetMaxLines(500)
        cf:SetFading(GudaChatDB.fading or false)
        cf:SetJustifyH("LEFT")
        FCF_SelectDockFrame(ChatFrame1)
    end

    local idx = GudaChatDB.whisperFrameIndex
    if idx then
        local cf = _G["ChatFrame" .. idx]
        local name = cf and GetChatWindowInfo(idx)
        if cf and name == "Whispers" then
            InitWhisperFrame(cf, idx)
            return
        end
        GudaChatDB.whisperFrameIndex = nil
    end

    for i = 3, NUM_CHAT_WINDOWS do
        local name = GetChatWindowInfo(i)
        if name == "Whispers" then
            local cf = _G["ChatFrame" .. i]
            InitWhisperFrame(cf, i)
            return
        end
    end

    if FCF_OpenNewWindow then
        FCF_OpenNewWindow("Whispers")
        for i = NUM_CHAT_WINDOWS, 1, -1 do
            local cf = _G["ChatFrame" .. i]
            if cf then
                ns.StripChatChrome(i)
                InitWhisperFrame(cf, i)
                FCF_DockFrame(cf)
                FCF_SelectDockFrame(ChatFrame1)
                break
            end
        end
    end
end
ns.SetupWhisperFrame = SetupWhisperFrame

-- Listen for incoming whispers to trigger blink on the dedicated Whispers tab
local whisperListener = CreateFrame("Frame")
whisperListener:SetScript("OnEvent", function()
    if not GudaChatDB or not GudaChatDB.whisperTab then return end
    if ns.whisperFrame and not ns.whisperFrame:IsShown() and ns.whisperFrameIndex then
        blinkingTabs[ns.whisperFrameIndex] = true
        if ns.RefreshChatSubTabs then ns.RefreshChatSubTabs() end
        if ns.ShowTabBar then ns.ShowTabBar() end
    end
end)

ns.StartWhisperBlink = function()
    if ns.whisperFrameIndex then
        blinkingTabs[ns.whisperFrameIndex] = true
        if ns.RefreshChatSubTabs then ns.RefreshChatSubTabs() end
        if ns.ShowTabBar then ns.ShowTabBar() end
    end
end

---------------------------------------------------------------------------
-- Create chat header
---------------------------------------------------------------------------

local function CreateChatHeader(parentFrame)
    local header = CreateFrame("Frame", "GudaChatHeader", UIParent, "BackdropTemplate")
    header:SetHeight(HEADER_HEIGHT)
    local extraR = ns.IS_RETAIL and 13 or 0
    header:SetPoint("BOTTOMLEFT", parentFrame, "TOPLEFT", -4, 0)
    header:SetPoint("BOTTOMRIGHT", parentFrame, "TOPRIGHT", 4 + extraR, 0)
    header:SetFrameStrata("MEDIUM")
    header:SetFrameLevel(100)
    header:SetAlpha(0)

    ns.ApplyDarkBackdrop(header, ns.COLOR_HEADER_BG, ns.COLOR_HEADER_BORDER)

    -- Hover detection zone
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
        ns.FadeInScrollbar()
    end

    local function HideHeader()
        if not isHovering then return end
        isHovering = false
        C_Timer.After(0.3, function()
            if isHovering then return end
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
            ns.FadeOutScrollbar()
        end)
    end

    -- Detect hover via OnUpdate
    local monitor = CreateFrame("Frame")
    monitor:SetScript("OnUpdate", function()
        local over = header:IsMouseOver() or parentFrame:IsMouseOver()
            or (combatSubTabs and combatSubTabs:IsShown() and combatSubTabs:IsMouseOver())
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

    local function FinishDrag(self)
        if not self.isDragging then return end
        parentFrame:StopMovingOrSizing()
        parentFrame:SetUserPlaced(false)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
        local point, _, relPoint, x, y = parentFrame:GetPoint(1)
        GudaChatDB.position = { point = point, relPoint = relPoint, x = x, y = y }
        -- Re-lock position against UIParentPanelManager
        ns.cf1PositionLocked = true
        -- Sync all docked frames to new position
        ns.SyncDockedFrames()
    end

    header:SetScript("OnDragStart", function(self)
        if GudaChatDB.locked then return end
        -- Unlock so StartMoving can reposition the frame
        ns.cf1PositionLocked = false
        parentFrame:SetMovable(true)
        parentFrame:StartMoving()
        self.isDragging = true
        -- Catch interrupted drags (e.g. targeting a unit mid-drag)
        self:SetScript("OnUpdate", function(self)
            if not IsMouseButtonDown("LeftButton") then
                FinishDrag(self)
            else
                ns.SyncDockedFrames()
            end
        end)
    end)
    header:SetScript("OnDragStop", function(self)
        FinishDrag(self)
    end)

    header:SetScript("OnEnter", function(self)
        if not GudaChatDB.locked then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Drag to move", 0.7, 0.7, 0.7)
            SetTooltipFontSize(12)
            GameTooltip:Show()
        end
    end)
    header:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -------------------------------------------------------------------
    -- Tab switcher dropdown (shown on tab label click)
    -------------------------------------------------------------------
    local dropdown = CreateFrame("Frame", "GudaChatTabDropdown", header, "BackdropTemplate")
    dropdown:SetFrameStrata("TOOLTIP")
    ns.ApplyDarkBackdrop(dropdown)
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
                if isDocked and i ~= 2 then
                    local mb = CreateFrame("Button", nil, dropdown)
                    mb:SetHeight(20)
                    mb:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 4, yOff)
                    mb:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", -4, yOff)

                    local mbText = mb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    mbText:SetPoint("LEFT", mb, "LEFT", 6, 0)
                    mbText:SetText(name)

                    local col = GetTabColor(name, i)
                    local isActive = (GetSelectedChatFrameIndex() == i)
                    if isActive then
                        mbText:SetTextColor(col[1], col[2], col[3], 1)
                    else
                        mbText:SetTextColor(col[1] * 0.5, col[2] * 0.5, col[3] * 0.5, 0.8)
                    end

                    mb:SetScript("OnEnter", function()
                        mbText:SetTextColor(col[1], col[2], col[3], 1)
                    end)
                    mb:SetScript("OnLeave", function()
                        local active = (GetSelectedChatFrameIndex() == i)
                        if not active then
                            mbText:SetTextColor(col[1] * 0.5, col[2] * 0.5, col[3] * 0.5, 0.8)
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
    end

    local closer = CreateFrame("Frame", nil, dropdown)

    -------------------------------------------------------------------
    -- Left side: Logo icon (General tab)
    -------------------------------------------------------------------
    local logoBtn = CreateIconButton(header, ns.ASSET_PATH .. "logo.png", ICON_SIZE + 2, "General")
    logoBtn:SetPoint("LEFT", header, "LEFT", 4, 0)
    logoBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    logoBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ShowContextMenu(self, 1)
        else
            FCF_SelectDockFrame(ChatFrame1)
        end
        CloseDropdown()
    end)

    -------------------------------------------------------------------
    -- Left side: Combat log icon
    -------------------------------------------------------------------
    local combatBtn = CreateIconButton(header, ns.ASSET_PATH .. "combat.png", ICON_SIZE, "Combat Log")
    combatBtn:SetPoint("LEFT", logoBtn, "RIGHT", 6, 0)

    combatBtn:SetScript("OnClick", function()
        if ChatFrame2 then
            if ChatFrame2:IsShown() then
                FCF_SelectDockFrame(ChatFrame1)
            else
                FCF_SelectDockFrame(ChatFrame2)
            end
        end
    end)

    combatBtn:HookScript("OnClick", function() CloseDropdown() end)

    -------------------------------------------------------------------
    -- Left side: History icon
    -------------------------------------------------------------------
    local historyBtn = CreateIconButton(header, ns.ASSET_PATH .. "history.png", ICON_SIZE + 3, "History")
    historyBtn:SetPoint("LEFT", combatBtn, "RIGHT", 6, 0)
    ns.historyBtn = historyBtn

    historyBtn:SetScript("OnClick", function()
        ns.ToggleHistory()
        CloseDropdown()
    end)

    if GudaChatDB and not GudaChatDB.historyEnabled then
        historyBtn:Hide()
    end

    -------------------------------------------------------------------
    -- Center: Current tab name
    -------------------------------------------------------------------
    local tabLabel = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tabLabel:SetPoint("CENTER", header, "CENTER", 0, 0)
    tabLabel:SetTextColor(0.6, 0.45, 0.0, 0.8)
    tabLabel:SetText(GetChatTabName(1))

    local tabLabelBtn = CreateFrame("Button", nil, header)
    ns._tabLabelBtn = tabLabelBtn
    tabLabelBtn:SetPoint("CENTER", tabLabel, "CENTER", 0, 0)
    tabLabelBtn:SetHeight(HEADER_HEIGHT)
    tabLabelBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tabLabelBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            CloseDropdown()
            if contextMenu and contextMenu:IsShown() then
                contextMenu:Hide()
                if fontSubMenu then fontSubMenu:Hide() end
            else
                ShowContextMenu(self)
            end
        else
            if contextMenu and contextMenu:IsShown() then
                contextMenu:Hide()
                if fontSubMenu then fontSubMenu:Hide() end
            end
            if dropdown:IsShown() then
                CloseDropdown()
            else
                RefreshDropdown()
                dropdown:ClearAllPoints()
                dropdown:SetPoint("BOTTOM", self, "TOP", 0, 2)
                dropdown:Show()
            end
        end
    end)
    tabLabelBtn:SetScript("OnEnter", function(self)
        tabLabel:SetTextColor(1, 0.8, 0, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Click to switch tabs, right-click for options", 0.7, 0.7, 0.7)
        SetTooltipFontSize(12)
        GameTooltip:Show()
        if chatHeader then chatHeader:SetAlpha(1) end
    end)
    tabLabelBtn:SetScript("OnLeave", function(self)
        tabLabel:SetTextColor(0.6, 0.45, 0.0, 0.8)
        GameTooltip:Hide()
    end)

    local function UpdateTabLabelBtnWidth()
        tabLabelBtn:SetWidth(math.max(tabLabel:GetStringWidth() + 16, 40))
    end
    UpdateTabLabelBtnWidth()

    -- Set up closer for tab dropdown (needs tabLabelBtn reference)
    closer:SetScript("OnUpdate", function()
        if dropdown:IsShown() and not dropdown:IsMouseOver() and not tabLabelBtn:IsMouseOver() then
            if IsMouseButtonDown("LeftButton") then
                CloseDropdown()
            end
        end
    end)

    -- Highlight active icon based on selected frame
    local ICON_ACTIVE = {1, 1, 1, 1}
    local ICON_INACTIVE = {0.7, 0.7, 0.7, 0.9}

    local function UpdateIconHighlights(cf)
        local isGeneral = (cf == ChatFrame1)
        local isCombat = (cf == ChatFrame2)
        logoBtn.icon:SetVertexColor(unpack(isGeneral and ICON_ACTIVE or ICON_INACTIVE))
        combatBtn.icon:SetVertexColor(unpack(isCombat and ICON_ACTIVE or ICON_INACTIVE))
    end

    logoBtn:HookScript("OnLeave", function()
        local sel = SELECTED_DOCK_FRAME or FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame()
        if sel == ChatFrame1 then logoBtn.icon:SetVertexColor(unpack(ICON_ACTIVE)) end
    end)
    combatBtn:HookScript("OnLeave", function()
        local sel = SELECTED_DOCK_FRAME or FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame()
        if sel == ChatFrame2 then combatBtn.icon:SetVertexColor(unpack(ICON_ACTIVE)) end
    end)

    -- Set initial highlight (General is selected by default on load)
    UpdateIconHighlights(ChatFrame1)

    -- Update label and icon highlights when tabs switch
    hooksecurefunc("FCF_SelectDockFrame", function(cf)
        if not cf then return end
        local found = false
        ns.ForEachChatWindow(function(frame, i)
            if frame == cf then
                tabLabel:SetText(GetChatTabName(i))
                UpdateTabLabelBtnWidth()
                found = true
            end
        end)
        -- Check temporary frames (index > NUM_CHAT_WINDOWS)
        if not found and CHAT_FRAMES then
            for _, name in ipairs(CHAT_FRAMES) do
                local frame = _G[name]
                if frame == cf then
                    local tab = _G[name .. "Tab"]
                    local tabName = tab and (tab.Text and tab.Text:GetText() or tab:GetText()) or "Chat"
                    tabLabel:SetText(tabName)
                    UpdateTabLabelBtnWidth()
                    break
                end
            end
        end
        UpdateIconHighlights(cf)
        if ns.RefreshChatSubTabs then ns.RefreshChatSubTabs() end
    end)

    -------------------------------------------------------------------
    -- Right side: Settings icon
    -------------------------------------------------------------------
    local settingsBtn = CreateIconButton(header, ns.ASSET_PATH .. "cog.png", ICON_SIZE, "Settings")
    settingsBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)

    settingsBtn:SetScript("OnClick", function()
        ns.ToggleSettings()
        CloseDropdown()
    end)

    -------------------------------------------------------------------
    -- Right side: Chat Channels icon
    -------------------------------------------------------------------
    local channelsBtn = CreateIconButton(header, ns.ASSET_PATH .. "voice.png", ICON_SIZE - 1, "Chat Channels")
    channelsBtn:SetPoint("RIGHT", settingsBtn, "LEFT", -6, 0)

    channelsBtn:SetScript("OnClick", function()
        ToggleChannelFrame()
        CloseDropdown()
    end)

    -------------------------------------------------------------------
    -- Right side: Chat Type (emote) icon
    -------------------------------------------------------------------
    local chatTypeBtn = CreateIconButton(header, ns.ASSET_PATH .. "chat.png", ICON_SIZE - 1, "Chat Type")
    chatTypeBtn:SetPoint("RIGHT", channelsBtn, "LEFT", -6, 0)

    if GudaChatDB and not GudaChatDB.historyEnabled then
        historyBtn:Hide()
    end

    local chatTypeDropdown = CreateFrame("Frame", "GudaChatTypeDropdown", chatTypeBtn, "BackdropTemplate")
    chatTypeDropdown:SetFrameStrata("TOOLTIP")
    ns.ApplyDarkBackdrop(chatTypeDropdown)
    chatTypeDropdown:Hide()

    -- Emote submenu
    local emoteSubMenu = CreateFrame("Frame", "GudaChatEmoteSubMenu", chatTypeDropdown, "BackdropTemplate")
    emoteSubMenu:SetFrameStrata("TOOLTIP")
    emoteSubMenu:SetFrameLevel(chatTypeDropdown:GetFrameLevel() + 1)
    ns.ApplyDarkBackdrop(emoteSubMenu)
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
    whisperListener:RegisterEvent("CHAT_MSG_WHISPER")
    whisperListener:RegisterEvent("CHAT_MSG_BN_WHISPER")

    -------------------------------------------------------------------
    -- Chat window subtab bar
    -------------------------------------------------------------------
    CreateChatSubTabs(header)
    if GudaChatDB.showTabBar then
        RefreshChatSubTabs(header)
        chatSubTabs:Show()
        chatSubTabs:SetAlpha(0)
    end

    hooksecurefunc("FCF_SelectDockFrame", function(cf)
        if combatSubTabs then
            if cf == ChatFrame2 then
                combatSubTabs:Show()
                combatSubTabs:SetAlpha(header:GetAlpha())
            else
                combatSubTabs:Hide()
                SwitchCombatLogFilter("mine")
            end
        end
        if chatSubTabs and GudaChatDB.showTabBar then
            local isCombat = (cf == ChatFrame2)
            if isCombat then
                chatSubTabs:Hide()
            else
                RefreshChatSubTabs(header)
                chatSubTabs:Show()
            end
        end
    end)

    -- Refresh chat subtabs when windows are created/removed/docked
    local chatSubTabHooks = { "FCF_OpenNewWindow", "FCF_Close", "FCF_DockFrame", "FCF_UnDockFrame", "FCF_SetWindowName" }
    for _, funcName in ipairs(chatSubTabHooks) do
        if _G[funcName] then
            hooksecurefunc(funcName, function()
                if chatSubTabs and GudaChatDB.showTabBar then
                    RefreshChatSubTabs(header)
                end
            end)
        end
    end

    -- Auto-select tab when sending a message to a channel with its own window
    local AUTO_SELECT_EVENTS = {
        CHAT_MSG_GUILD = "GUILD", CHAT_MSG_OFFICER = "OFFICER",
        CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY",
        CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID",
        CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT", CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
        CHAT_MSG_WHISPER_INFORM = "WHISPER", CHAT_MSG_BN_WHISPER_INFORM = "BN_WHISPER",
    }
    local autoSelectFrame = CreateFrame("Frame")
    autoSelectFrame:SetScript("OnEvent", function(self, event, msg, sender)
        if not GudaChatDB or not GudaChatDB.showTabBar then return end
        local group = AUTO_SELECT_EVENTS[event]
        if not group then return end

        -- Only react to our own messages
        local playerName = UnitName("player")
        local senderShort = sender and sender:match("^([^%-]+)") or sender
        local isOutgoing = (event == "CHAT_MSG_WHISPER_INFORM" or event == "CHAT_MSG_BN_WHISPER_INFORM")
        if not isOutgoing and senderShort ~= playerName then return end

        -- For outgoing whispers, check temporary windows then dedicated Whispers tab
        if isOutgoing then
            if sender and CHAT_FRAMES then
                local targetShort = sender:match("^([^%-]+)") or sender
                for _, frameName in ipairs(CHAT_FRAMES) do
                    local cf = _G[frameName]
                    if cf and cf.isTemporary and cf.inUse and cf.isDocked then
                        local ct = cf.chatTarget
                        local ctShort = ct and ct:match("^([^%-]+)") or ct
                        if ctShort and targetShort and ctShort:lower() == targetShort:lower() then
                            FCF_SelectDockFrame(cf)
                            return
                        end
                    end
                end
            end
            if GudaChatDB.whisperTab and ns.whisperFrame then
                FCF_SelectDockFrame(ns.whisperFrame)
                return
            end
            return
        end

        -- For other chat types, find a non-General window that has this message group
        for i = 3, NUM_CHAT_WINDOWS do
            local cf = _G["ChatFrame" .. i]
            local tab = _G["ChatFrame" .. i .. "Tab"]
            if cf and tab then
                local isDocked = cf.isDocked
                local shown = tab:IsShown()
                if isDocked and shown then
                    local msgs = { GetChatWindowMessages(i) }
                    for _, grp in ipairs(msgs) do
                        if grp == group then
                            FCF_SelectDockFrame(cf)
                            return
                        end
                    end
                end
            end
        end
    end)
    for ev in pairs(AUTO_SELECT_EVENTS) do
        autoSelectFrame:RegisterEvent(ev)
    end

    chatHeader = header
    ns.chatHeader = header
    return header
end
ns.CreateChatHeader = CreateChatHeader
