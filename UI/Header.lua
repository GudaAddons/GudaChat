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
    end
    local selected = SELECTED_DOCK_FRAME or SELECTED_CHAT_FRAME
    if selected then
        for i = 1, NUM_CHAT_WINDOWS do
            if _G["ChatFrame" .. i] == selected then return i end
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

local function ShowContextMenu(anchor)
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

    local id = GetSelectedChatFrameIndex()
    local cf = _G["ChatFrame" .. id]
    local yOff = -4
    local maxW = 140

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
        local removeBtn = CreateContextMenuItem(contextMenu, "Remove Window", function()
            local chatFrame = _G["ChatFrame" .. id]
            if chatFrame and FCF_Close then
                FCF_Close(chatFrame)
                FCF_SelectDockFrame(ChatFrame1)
            end
            contextMenu:Hide()
        end)
        removeBtn:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
        removeBtn:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
        yOff = yOff - 20
    end

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
        local curCf = _G["ChatFrame" .. GetSelectedChatFrameIndex()]
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

    local curCf = _G["ChatFrame" .. id]
    local r, g, b, a = 0, 0, 0, 0.5
    if curCf then
        r, g, b = FCF_GetCurrentChatFrameBackgroundColor and FCF_GetCurrentChatFrameBackgroundColor(curCf) or 0, 0, 0
        a = curCf.oldAlpha or 0.25
    end
    swatch:SetVertexColor(r, g, b, math.max(a, 0.3))

    local swatchBorder = bgBtn:CreateTexture(nil, "OVERLAY")
    swatchBorder:SetSize(16, 16)
    swatchBorder:SetPoint("CENTER", swatch, "CENTER", 0, 0)
    swatchBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
    swatchBorder:SetVertexColor(0.5, 0.5, 0.5, 0.8)
    swatchBorder:SetDrawLayer("ARTWORK", -1)

    bgBtn:SetScript("OnClick", function()
        local chatFrame = _G["ChatFrame" .. GetSelectedChatFrameIndex()]
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

    local filterSep = CreateContextMenuItem(contextMenu, "Filters", nil, true)
    filterSep:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 0, yOff)
    filterSep:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", 0, yOff)
    yOff = yOff - 20

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
    contextMenu:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
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
---------------------------------------------------------------------------

local combatLogFilter = "all"
local shouldShowCombatMessage = true

local combatFilterFrame = CreateFrame("Frame")
combatFilterFrame:SetScript("OnEvent", function()
    if combatLogFilter == "all" then
        shouldShowCombatMessage = true
        return
    end

    local _, _, _, sourceGUID, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    local playerGUID = UnitGUID("player")

    if combatLogFilter == "mine" then
        shouldShowCombatMessage = (sourceGUID == playerGUID)
    elseif combatLogFilter == "tome" then
        shouldShowCombatMessage = (destGUID == playerGUID)
    end
end)

local origCF2AddMessage
local function HookCombatLogAddMessage()
    if not ChatFrame2 then return end
    if origCF2AddMessage then return end
    origCF2AddMessage = ChatFrame2.AddMessage
    ChatFrame2.AddMessage = function(self, ...)
        if combatLogFilter ~= "all" and not shouldShowCombatMessage then
            return
        end
        return origCF2AddMessage(self, ...)
    end
end

-- Subtab bar UI
local combatSubTabs

local function CreateCombatSubTabs(header)
    local bar = CreateFrame("Frame", "GudaChatCombatSubTabs", UIParent, "BackdropTemplate")
    bar:SetHeight(20)
    bar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -1)
    bar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -1)
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(101)

    ns.ApplyDarkBackdrop(bar, ns.COLOR_DARK_BG, { 0.3, 0.3, 0.3, 0.8 })
    bar:EnableMouse(true)
    bar:SetAlpha(0)
    bar:Hide()

    local tabs = {}
    local tabDefs = {
        { key = "all",  label = "All" },
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
            combatLogFilter = def.key
            shouldShowCombatMessage = true
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
-- Whisper frame setup
---------------------------------------------------------------------------

local function EnforceWhisperGroups(cf)
    ChatFrame_RemoveAllMessageGroups(cf)
    ChatFrame_AddMessageGroup(cf, "WHISPER")
    ChatFrame_AddMessageGroup(cf, "BN_WHISPER")
end

local function SetupWhisperFrame()
    local idx = GudaChatDB.whisperFrameIndex
    if idx then
        local cf = _G["ChatFrame" .. idx]
        local name = cf and GetChatWindowInfo(idx)
        if cf and name == "Whispers" then
            ns.whisperFrame = cf
            ns.whisperFrameIndex = idx
            EnforceWhisperGroups(cf)
            return
        end
        GudaChatDB.whisperFrameIndex = nil
    end

    for i = 3, NUM_CHAT_WINDOWS do
        local name = GetChatWindowInfo(i)
        if name == "Whispers" then
            local cf = _G["ChatFrame" .. i]
            ns.whisperFrame = cf
            ns.whisperFrameIndex = i
            GudaChatDB.whisperFrameIndex = i
            EnforceWhisperGroups(cf)
            return
        end
    end

    if FCF_OpenNewWindow then
        FCF_OpenNewWindow("Whispers")
        for i = NUM_CHAT_WINDOWS, 1, -1 do
            local cf = _G["ChatFrame" .. i]
            if cf then
                EnforceWhisperGroups(cf)
                ns.StripChatChrome(i)
                ns.whisperFrame = cf
                ns.whisperFrameIndex = i
                GudaChatDB.whisperFrameIndex = i
                FCF_DockFrame(cf)
                FCF_SelectDockFrame(ChatFrame1)
                break
            end
        end
    end
end
ns.SetupWhisperFrame = SetupWhisperFrame

-- Listen for incoming whispers to trigger blink notification
local whisperListener = CreateFrame("Frame")
whisperListener:SetScript("OnEvent", function()
    if not GudaChatDB or not GudaChatDB.whisperTab then return end
    if ns.whisperFrame and not ns.whisperFrame:IsShown() and ns.StartWhisperBlink then
        ns.StartWhisperBlink()
    end
end)

---------------------------------------------------------------------------
-- Create chat header
---------------------------------------------------------------------------

local function CreateChatHeader(parentFrame)
    local header = CreateFrame("Frame", "GudaChatHeader", UIParent, "BackdropTemplate")
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("BOTTOMLEFT", parentFrame, "TOPLEFT", -4, 0)
    header:SetPoint("BOTTOMRIGHT", parentFrame, "TOPRIGHT", 4, 0)
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
    header:SetScript("OnDragStart", function(self)
        if GudaChatDB.locked then return end
        parentFrame:SetMovable(true)
        parentFrame:SetUserPlaced(true)
        parentFrame:StartMoving()
        self.isDragging = true
    end)
    header:SetScript("OnDragStop", function(self)
        if self.isDragging then
            parentFrame:StopMovingOrSizing()
            self.isDragging = false
            local point, _, relPoint, x, y = parentFrame:GetPoint(1)
            GudaChatDB.position = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)

    header:SetScript("OnEnter", function(self)
        if not GudaChatDB.locked then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Drag to move", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end)
    header:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -------------------------------------------------------------------
    -- Left side: Tab switcher icon + dropdown
    -------------------------------------------------------------------
    local tabBtn = CreateIconButton(header, ns.ASSET_PATH .. "logo.png", ICON_SIZE, "Chat Tabs")
    tabBtn:SetPoint("LEFT", header, "LEFT", 4, 0)

    local dropdown = CreateFrame("Frame", "GudaChatTabDropdown", tabBtn, "BackdropTemplate")
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
                if isDocked and i ~= 2 and i ~= (ns.whisperFrameIndex or -1) then
                    local mb = CreateFrame("Button", nil, dropdown)
                    mb:SetHeight(20)
                    mb:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 4, yOff)
                    mb:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", -4, yOff)

                    local mbText = mb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    mbText:SetPoint("LEFT", mb, "LEFT", 6, 0)
                    mbText:SetText(name)

                    local isActive = (GetSelectedChatFrameIndex() == i)
                    mbText:SetTextColor(isActive and 1 or 0.8, isActive and 0.8 or 0.8, isActive and 0 or 0.8, 1)

                    mb:SetScript("OnEnter", function()
                        mbText:SetTextColor(1, 0.8, 0, 1)
                    end)
                    mb:SetScript("OnLeave", function()
                        local active = (GetSelectedChatFrameIndex() == i)
                        if not active then
                            mbText:SetTextColor(0.8, 0.8, 0.8, 1)
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
        dropdown:ClearAllPoints()
        dropdown:SetPoint("BOTTOMLEFT", tabBtn, "TOPLEFT", -4, 2)
    end

    tabBtn:SetScript("OnClick", function()
        if dropdown:IsShown() then
            CloseDropdown()
        else
            RefreshDropdown()
            dropdown:Show()
        end
    end)

    local closer = CreateFrame("Frame", nil, dropdown)
    closer:SetScript("OnUpdate", function()
        if dropdown:IsShown() and not dropdown:IsMouseOver() and not tabBtn:IsMouseOver() then
            if IsMouseButtonDown("LeftButton") then
                CloseDropdown()
            end
        end
    end)

    -------------------------------------------------------------------
    -- Left side: Combat log icon
    -------------------------------------------------------------------
    local combatBtn = CreateIconButton(header, ns.ASSET_PATH .. "combat.png", ICON_SIZE, "Combat Log")
    combatBtn:SetPoint("LEFT", tabBtn, "RIGHT", 6, 0)

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
    -- Left side: Whisper icon
    -------------------------------------------------------------------
    local whisperBtn = CreateIconButton(header, ns.ASSET_PATH .. "characters.png", ICON_SIZE, "Whispers")
    whisperBtn:SetPoint("LEFT", combatBtn, "RIGHT", 6, 0)
    if not GudaChatDB.whisperTab then whisperBtn:Hide() end
    ns.whisperBtn = whisperBtn

    -- Blink animation for incoming whispers
    local blinkGroup = whisperBtn:CreateAnimationGroup()
    blinkGroup:SetLooping("REPEAT")
    local blinkFadeOut = blinkGroup:CreateAnimation("Alpha")
    blinkFadeOut:SetFromAlpha(1)
    blinkFadeOut:SetToAlpha(0.2)
    blinkFadeOut:SetDuration(0.5)
    blinkFadeOut:SetOrder(1)
    local blinkFadeIn = blinkGroup:CreateAnimation("Alpha")
    blinkFadeIn:SetFromAlpha(0.2)
    blinkFadeIn:SetToAlpha(1)
    blinkFadeIn:SetDuration(0.5)
    blinkFadeIn:SetOrder(2)

    local function StartWhisperBlink()
        if not blinkGroup:IsPlaying() then
            whisperBtn.icon:SetVertexColor(1, 0.8, 0, 1)
            blinkGroup:Play()
        end
        ShowHeader()
    end

    local function StopWhisperBlink()
        if blinkGroup:IsPlaying() then
            blinkGroup:Stop()
            whisperBtn.icon:SetVertexColor(0.7, 0.7, 0.7, 0.9)
            whisperBtn:SetAlpha(1)
        end
    end

    ns.StartWhisperBlink = StartWhisperBlink
    ns.StopWhisperBlink = StopWhisperBlink

    whisperBtn:SetScript("OnClick", function()
        if ns.whisperFrame then
            if ns.whisperFrame:IsShown() then
                FCF_SelectDockFrame(ChatFrame1)
            else
                FCF_SelectDockFrame(ns.whisperFrame)
                StopWhisperBlink()
            end
        end
    end)
    whisperBtn:HookScript("OnClick", function() CloseDropdown() end)

    -------------------------------------------------------------------
    -- Center: Current tab name
    -------------------------------------------------------------------
    local tabLabel = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tabLabel:SetPoint("CENTER", header, "CENTER", 0, 0)
    tabLabel:SetTextColor(0.6, 0.45, 0.0, 0.8)
    tabLabel:SetText(GetChatTabName(1))

    local tabLabelBtn = CreateFrame("Button", nil, header)
    tabLabelBtn:SetPoint("CENTER", tabLabel, "CENTER", 0, 0)
    tabLabelBtn:SetHeight(HEADER_HEIGHT)
    tabLabelBtn:RegisterForClicks("RightButtonUp")
    tabLabelBtn:SetScript("OnClick", function(self, button)
        if button ~= "RightButton" then return end
        if contextMenu and contextMenu:IsShown() then
            contextMenu:Hide()
            if fontSubMenu then fontSubMenu:Hide() end
        else
            ShowContextMenu(self)
        end
    end)
    tabLabelBtn:SetScript("OnEnter", function(self)
        tabLabel:SetTextColor(1, 0.8, 0, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Right-click for options", 0.7, 0.7, 0.7)
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

    -- Highlight active icon based on selected frame
    local ICON_ACTIVE = {1, 1, 1, 1}
    local ICON_INACTIVE = {0.7, 0.7, 0.7, 0.9}

    local function UpdateIconHighlights(cf)
        local isCombat = (cf == ChatFrame2)
        local isWhisper = (ns.whisperFrame and cf == ns.whisperFrame)
        local isGeneral = (not isCombat and not isWhisper)

        combatBtn.icon:SetVertexColor(unpack(isCombat and ICON_ACTIVE or ICON_INACTIVE))
        if whisperBtn:IsShown() and not (ns.StartWhisperBlink and blinkGroup:IsPlaying()) then
            whisperBtn.icon:SetVertexColor(unpack(isWhisper and ICON_ACTIVE or ICON_INACTIVE))
        end
        tabBtn.icon:SetVertexColor(unpack(isGeneral and ICON_ACTIVE or ICON_INACTIVE))
    end

    tabBtn:HookScript("OnLeave", function()
        local sel = SELECTED_DOCK_FRAME or FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame()
        local isActive = sel and sel ~= ChatFrame2 and sel ~= ns.whisperFrame
        if isActive then tabBtn.icon:SetVertexColor(unpack(ICON_ACTIVE)) end
    end)
    combatBtn:HookScript("OnLeave", function()
        local sel = SELECTED_DOCK_FRAME or FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame()
        if sel == ChatFrame2 then combatBtn.icon:SetVertexColor(unpack(ICON_ACTIVE)) end
    end)
    whisperBtn:HookScript("OnLeave", function()
        local sel = SELECTED_DOCK_FRAME or FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame()
        if ns.whisperFrame and sel == ns.whisperFrame and not blinkGroup:IsPlaying() then
            whisperBtn.icon:SetVertexColor(unpack(ICON_ACTIVE))
        end
    end)

    -- Update label and icon highlights when tabs switch
    hooksecurefunc("FCF_SelectDockFrame", function(cf)
        if not cf then return end
        ns.ForEachChatWindow(function(frame, i)
            if frame == cf then
                tabLabel:SetText(GetChatTabName(i))
                UpdateTabLabelBtnWidth()
            end
        end)
        UpdateIconHighlights(cf)
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

    -------------------------------------------------------------------
    -- Right side: History icon
    -------------------------------------------------------------------
    local historyBtn = CreateIconButton(header, ns.ASSET_PATH .. "history.png", ICON_SIZE - 1, "History")
    historyBtn:SetPoint("RIGHT", chatTypeBtn, "LEFT", -6, 0)
    ns.historyBtn = historyBtn

    historyBtn:SetScript("OnClick", function()
        ns.ToggleHistory()
        CloseDropdown()
    end)

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
    HookCombatLogAddMessage()
    -- COMBAT_LOG_EVENT_UNFILTERED is restricted in Retail; only register where available
    if CombatLogGetCurrentEventInfo and (select(4, GetBuildInfo()) or 0) < 110000 then
        combatFilterFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
    whisperListener:RegisterEvent("CHAT_MSG_WHISPER")
    whisperListener:RegisterEvent("CHAT_MSG_BN_WHISPER")

    hooksecurefunc("FCF_SelectDockFrame", function(cf)
        if combatSubTabs then
            if cf == ChatFrame2 then
                combatSubTabs:Show()
                combatSubTabs:SetAlpha(header:GetAlpha())
            else
                combatSubTabs:Hide()
                combatLogFilter = "all"
                shouldShowCombatMessage = true
            end
        end
    end)

    chatHeader = header
    ns.chatHeader = header
    return header
end
ns.CreateChatHeader = CreateChatHeader
