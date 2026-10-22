local addonName, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Right-click menu for chat windows: rename, new window, remove or leave, font size,
-- background colour and Blizzard's chat settings
---------------------------------------------------------------------------

local FONT_SIZES = { 12, 14, 16, 18, 20, 24, 27 }
local CONTEXT_MENU_WIDTH = 160
local FONT_SUBMENU_WIDTH = 80
local SUBMENU_HIDE_DELAY = 0.2
local DEFAULT_BG_ALPHA = 0.25

-- The context menu's items are built once; each ShowContextMenu only re-labels, shows or
-- hides and re-stacks them. contextIndex is the chat window the menu acts on.
local contextMenu, fontSubMenu
local contextIndex = 1
local contextItems
local CONTEXT_LAYOUT = { "rename", "newWindow", "remove", "leave", "display", "font", "background", "settings" }

local function RenameWindow(name)
    local chatFrame = ns._renamingFrame
    local id = ns._renamingIndex
    if chatFrame and name and name ~= "" and id then
        FCF_SetWindowName(chatFrame, name)
        ns.SafeSelectDockFrame(chatFrame)
    end
end

StaticPopupDialogs["GUDACHAT_RENAME_WINDOW"] = {
    text = L["PROMPT_RENAME_WINDOW"],
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    OnShow = function(self)
        local id = ns._renamingIndex or 1
        self.EditBox:SetText(ns.GetChatTabName(id))
        self.EditBox:HighlightText()
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self)
        RenameWindow(self.EditBox:GetText())
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        RenameWindow(parent.EditBox:GetText())
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function ns.IsContextMenuShown()
    return contextMenu ~= nil and contextMenu:IsShown()
end

function ns.IsFontSubMenuShown()
    return fontSubMenu ~= nil and fontSubMenu:IsShown()
end

function ns.HideContextMenu()
    if contextMenu then contextMenu:Hide() end
    if fontSubMenu then fontSubMenu:Hide() end
end

local function SelectedChatFrame()
    return _G["ChatFrame" .. ns.GetSelectedChatFrameIndex()]
end

-- Shows the check mark next to the size the selected window uses
local function MarkCurrentFontSize(menu, size, item)
    local cf = SelectedChatFrame()
    if not cf then return end
    local _, curSize = cf:GetFont()
    curSize = math.floor(curSize + 0.5)
    for _, child in ipairs({ menu:GetChildren() }) do
        if child.check then
            child.check:Hide()
        end
    end
    if math.floor(size + 0.5) == curSize and item.check then
        item.check:Show()
    end
end

local function ApplyFontSize(size)
    GudaChatDB.chatFontSize = size
    if ns.ApplyChatFontSize then
        ns.ApplyChatFontSize(size)
        return
    end
    local cf = SelectedChatFrame()
    if cf then
        local fontObj, _, flags = cf:GetFont()
        cf:SetFont(fontObj, size, flags)
    end
end

local function CreateFontSubMenu()
    local f = CreateFrame("Frame", "GudaChatFontSubMenu", UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(210)
    ns.ApplyDarkBackdrop(f)
    f:Hide()

    local yOff = -4
    for _, size in ipairs(FONT_SIZES) do
        local btn = ns.CreateMenuItem(f, string.format(L["FONT_SIZE_POINTS"], size), nil, false, false, true)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, yOff)
        btn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, yOff)
        btn:SetScript("OnClick", function()
            ApplyFontSize(size)
            if contextMenu then contextMenu:Hide() end
            f:Hide()
        end)
        btn:SetScript("OnEnter", function(self)
            MarkCurrentFontSize(f, size, self)
        end)
        yOff = yOff - ns.MENU_ITEM_HEIGHT
    end

    f:SetSize(FONT_SUBMENU_WIDTH, math.abs(yOff) + 4)
    fontSubMenu = f
    return f
end

-- Hands a permanent window's message groups and channels to General before it closes
local function MoveWindowContentToGeneral(id)
    if GetChatWindowMessages then
        for _, msgGroup in ipairs({ GetChatWindowMessages(id) }) do
            ChatFrame_AddMessageGroup(ChatFrame1, msgGroup)
            if AddChatWindowMessages then
                AddChatWindowMessages(1, msgGroup)
            end
        end
    end
    if not GetChatWindowChannels then return end
    local channels = { GetChatWindowChannels(id) }
    for i = 1, #channels, 2 do
        local chName = channels[i]
        if type(chName) == "string" then
            if AddChatWindowChannel then
                AddChatWindowChannel(1, chName)
            end
            if ChatFrame1.channelList and not tContains(ChatFrame1.channelList, chName) then
                tinsert(ChatFrame1.channelList, chName)
            end
            if ChatFrame1.zoneChannelList and not tContains(ChatFrame1.zoneChannelList, chName) then
                tinsert(ChatFrame1.zoneChannelList, chName)
            end
        end
    end
end

-- Pops a temporary whisper window back in; the manual fallback clears the exclusion
-- lists itself so whispers from that person reach General or the Whispers window again
local function CloseTemporaryWindow(chatFrame)
    local target = chatFrame.chatTarget
    if FCF_PopInWindow then
        FCF_PopInWindow(chatFrame)
    elseif FCF_RestoreChatsToFrame then
        FCF_RestoreChatsToFrame(ChatFrame1, chatFrame)
        FCF_Close(chatFrame)
    else
        if target then
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
    if not GudaChatDB.whisperTab then
        ChatFrame_AddMessageGroup(ChatFrame1, "WHISPER")
        ChatFrame_AddMessageGroup(ChatFrame1, "BN_WHISPER")
    end
end

-- Closes chat window id and routes its content back to General. Temporary whisper windows
-- are popped back in; permanent windows first hand their message groups and channels to
-- General. Whispers are re-added to General only while the Whispers tab is off.
local function RemoveWindow(id)
    local chatFrame = _G["ChatFrame" .. id]
    if chatFrame then
        if chatFrame.isTemporary then
            CloseTemporaryWindow(chatFrame)
        else
            MoveWindowContentToGeneral(id)
            FCF_Close(chatFrame)
        end
    end
    contextMenu:Hide()
    ns.SafeSelectDockFrame(ChatFrame1)
end
ns.RemoveWindow = RemoveWindow

-- The channel a channel-based window can leave, or nil
local function LeaveableChannel(id)
    local tabName = ns.GetChatTabName(id)
    if not (tabName and GetChannelName) then return nil end
    local chNum = GetChannelName(tabName)
    if chNum and chNum > 0 then return tabName end
    return nil
end

local function ShowFrameBackground(chatFrame, alpha)
    local bg = _G[chatFrame:GetName() .. "Background"]
    if not bg then return end
    bg:SetScript("OnShow", nil)
    bg:Show()
    bg:SetAlpha(alpha)
end

-- Like ShowFrameBackground, but an alpha of 0 hides the background and keeps it hidden
local function RestoreFrameBackground(chatFrame, alpha)
    if alpha > 0 then
        ShowFrameBackground(chatFrame, alpha)
        return
    end
    local bg = _G[chatFrame:GetName() .. "Background"]
    if not bg then return end
    bg:Hide()
    bg:SetScript("OnShow", function(self) self:Hide() end)
end

-- Opens the color picker for one window's background. The modern picker
-- (SetupColorPickerAndShow) works in alpha; the old one in opacity, which is 1 - alpha.
local function OpenBackgroundPicker(chatFrame)
    local cr, cg, cb = 0, 0, 0
    if FCF_GetCurrentChatFrameBackgroundColor then
        cr, cg, cb = FCF_GetCurrentChatFrameBackgroundColor(chatFrame)
    end
    local ca = chatFrame.gudaBgAlpha or DEFAULT_BG_ALPHA
    local modernPicker = ColorPickerFrame.SetupColorPickerAndShow ~= nil

    ns.ShowColorPicker({
        r = cr, g = cg, b = cb,
        opacity = modernPicker and ca or (1 - ca),
        hasOpacity = true,
        swatchFunc = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            if FCF_SetWindowColor then
                FCF_SetWindowColor(chatFrame, nr, ng, nb)
            end
            ShowFrameBackground(chatFrame, chatFrame.gudaBgAlpha or DEFAULT_BG_ALPHA)
        end,
        opacityFunc = function()
            local newAlpha
            if modernPicker then
                newAlpha = ColorPickerFrame:GetColorAlpha() or ca
            else
                newAlpha = 1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0)
            end
            if FCF_SetWindowAlpha then
                FCF_SetWindowAlpha(chatFrame, newAlpha)
            end
            chatFrame.gudaBgAlpha = newAlpha
            ShowFrameBackground(chatFrame, newAlpha)
        end,
        cancelFunc = function(prev)
            if FCF_SetWindowColor then
                FCF_SetWindowColor(chatFrame, prev.r, prev.g, prev.b)
            end
            local prevAlpha = ca
            if modernPicker and prev.a then
                prevAlpha = prev.a
            elseif not modernPicker and prev.opacity then
                prevAlpha = 1 - prev.opacity
            end
            if FCF_SetWindowAlpha then
                FCF_SetWindowAlpha(chatFrame, prevAlpha)
            end
            chatFrame.gudaBgAlpha = prevAlpha
            RestoreFrameBackground(chatFrame, prevAlpha)
        end,
    })
end

local function AddContextItem(key, label, onClick, isSeparator, hasArrow)
    local item = ns.CreateMenuItem(contextMenu, label, onClick, isSeparator, hasArrow)
    contextItems[key] = item
    return item
end

local function BuildFontItem()
    local fsm = fontSubMenu or CreateFontSubMenu()
    local fontBtn = AddContextItem("font", ns.Blizz(FONT_SIZE, "Font Size"), nil, false, true)
    fontBtn:SetScript("OnEnter", function(self)
        local curCf = _G["ChatFrame" .. contextIndex]
        if curCf then
            local _, curSize = curCf:GetFont()
            curSize = math.floor(curSize + 0.5)
            for _, child in ipairs({ fsm:GetChildren() }) do
                if child.check then
                    local sizeStr = child.label and child.label:GetText()
                    local sz = sizeStr and tonumber(sizeStr:match("(%d+)"))
                    child.check:SetShown(sz == curSize)
                end
            end
        end
        fsm:ClearAllPoints()
        fsm:SetPoint("TOPLEFT", self, "TOPRIGHT", 2, 4)
        fsm:Show()
    end)
    fontBtn:SetScript("OnLeave", function(self)
        C_Timer.After(SUBMENU_HIDE_DELAY, function()
            if fsm and not fsm:IsMouseOver() and not self:IsMouseOver() then
                fsm:Hide()
            end
        end)
    end)
end

local function BuildBackgroundItem()
    local bgBtn = AddContextItem("background", ns.Blizz(BACKGROUND, "Background"), function()
        local chatFrame = _G["ChatFrame" .. contextIndex]
        if not chatFrame then return end
        contextMenu:Hide()
        OpenBackgroundPicker(chatFrame)
    end)

    local swatch = bgBtn:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(14, 14)
    swatch:SetPoint("RIGHT", bgBtn, "RIGHT", -8, 0)
    swatch:SetTexture("Interface\\Buttons\\WHITE8x8")
    bgBtn.swatch = swatch

    local swatchBorder = bgBtn:CreateTexture(nil, "OVERLAY")
    swatchBorder:SetSize(16, 16)
    swatchBorder:SetPoint("CENTER", swatch, "CENTER", 0, 0)
    swatchBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
    ns.Paint(swatchBorder, ns.Theme.C.swatchBorder)
    swatchBorder:SetDrawLayer("ARTWORK", -1)

    bgBtn:SetScript("OnEnter", function()
        if fontSubMenu then fontSubMenu:Hide() end
    end)
end

local function UpdateBackgroundSwatch(cf)
    local r, g, b, a = 0, 0, 0, 0.5
    if cf then
        if FCF_GetCurrentChatFrameBackgroundColor then
            r, g, b = FCF_GetCurrentChatFrameBackgroundColor(cf)
        end
        a = cf.gudaBgAlpha or DEFAULT_BG_ALPHA
    end
    contextItems.background.swatch:SetVertexColor(r, g, b, math.max(a, 0.3))
end

local function BuildContextMenu()
    local f = CreateFrame("Frame", "GudaChatContextMenu", UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(205)
    ns.ApplyDarkBackdrop(f)
    f:Hide()
    tinsert(UISpecialFrames, "GudaChatContextMenu")
    f:SetScript("OnHide", function()
        if fontSubMenu then fontSubMenu:Hide() end
        local iod = _G["GudaChatInlineTabOverflow"]
        if iod and iod:IsShown() then iod:Hide() end
        local eod = _G["GudaChatTabOverflow"]
        if eod and eod:IsShown() then eod:Hide() end
    end)
    contextMenu = f
    contextItems = {}
    ns.CreateClickCloser(f,
        function()
            return f:IsMouseOver() or (fontSubMenu and fontSubMenu:IsShown() and fontSubMenu:IsMouseOver())
        end,
        ns.HideContextMenu)

    AddContextItem("rename", ns.Blizz(RENAME, "Rename Window"), function()
        local chatFrame = _G["ChatFrame" .. contextIndex]
        if chatFrame then
            ns._renamingFrame = chatFrame
            ns._renamingIndex = contextIndex
            StaticPopup_Show("GUDACHAT_RENAME_WINDOW")
        end
        contextMenu:Hide()
    end)
    AddContextItem("newWindow", L["MENU_NEW_WINDOW"], function()
        if FCF_NewChatWindow then
            FCF_NewChatWindow()
        elseif FCF_OpenNewWindow then
            FCF_OpenNewWindow()
        end
        contextMenu:Hide()
    end)
    AddContextItem("remove", "", function()
        RemoveWindow(contextIndex)
    end)
    AddContextItem("leave", "", function(self)
        LeaveChannelByName(self.channelName)
        RemoveWindow(contextIndex)
    end)
    AddContextItem("display", ns.Blizz(DISPLAY, "Display"), nil, true)
    BuildFontItem()
    BuildBackgroundItem()
    AddContextItem("settings", ns.Blizz(SETTINGS, "Settings"), function()
        if ChatConfigFrame and ChatConfigFrame.Show then
            ShowUIPanel(ChatConfigFrame)
        end
        contextMenu:Hide()
    end)
end

-- "Close Whisper Window" for temporary whisper tabs, "Remove Window" otherwise; General
-- (window 1) can't be removed, and only channel windows get "Leave".
function ns.ShowContextMenu(anchor, overrideIndex)
    if not contextMenu then BuildContextMenu() end

    local id = overrideIndex or ns.GetSelectedChatFrameIndex()
    contextIndex = id
    local cf = _G["ChatFrame" .. id]
    local isTemp = cf and cf.isTemporary
    local channelName = id ~= 1 and not isTemp and LeaveableChannel(id) or nil

    local visible = {
        rename = true, newWindow = true, display = true, font = true, background = true, settings = true,
        remove = id ~= 1,
        leave = channelName ~= nil,
    }
    contextItems.remove.label:SetText(isTemp and ns.Blizz(CLOSE, "Close Whisper Window")
        or ns.Blizz(REMOVE, "Remove Window"))
    contextItems.leave.channelName = channelName
    if channelName then
        contextItems.leave.label:SetText(L["MENU_LEAVE"]:format(channelName))
    end
    UpdateBackgroundSwatch(cf)

    local yOff = -4
    for _, key in ipairs(CONTEXT_LAYOUT) do
        local item = contextItems[key]
        item:SetShown(visible[key])
        if visible[key] then
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
            item:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
            yOff = yOff - ns.MENU_ITEM_HEIGHT
        end
    end

    contextMenu:SetSize(CONTEXT_MENU_WIDTH, math.abs(yOff) + 4)
    contextMenu:ClearAllPoints()
    contextMenu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    contextMenu:Show()
end
