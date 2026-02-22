local addonName, ns = ...

---------------------------------------------------------------------------
-- Lock / unlock chat frame movement
---------------------------------------------------------------------------

local function ApplyLockState()
    local locked = GudaChatDB.locked
    ns.ForEachChatWindow(function(cf)
        cf:SetMovable(not locked)
        cf:SetClampedToScreen(true)
        if locked then
            cf:SetScript("OnDragStart", nil)
        end
        if cf.gudaResizeHandle then
            cf.gudaResizeHandle:EnableMouse(not locked)
            if locked then
                cf.gudaResizeHandle.grip:SetAlpha(0)
            end
        end
    end)
    if locked then
        if not ns._origStartMoving then
            ns._origStartMoving = FCF_StartDragging
        end
        FCF_StartDragging = function() end
    else
        if ns._origStartMoving then
            FCF_StartDragging = ns._origStartMoving
        end
    end
end
ns.ApplyLockState = ApplyLockState

---------------------------------------------------------------------------
-- Chrome stripping
---------------------------------------------------------------------------

local function StripChatChrome(index)
    local cf = _G["ChatFrame" .. index]
    if not cf then return end

    ns.KillFrame(_G["ChatFrame" .. index .. "ButtonFrameUpButton"])
    ns.KillFrame(_G["ChatFrame" .. index .. "ButtonFrameDownButton"])
    ns.KillFrame(_G["ChatFrame" .. index .. "ButtonFrameBottomButton"])
    ns.KillFrame(_G["ChatFrame" .. index .. "ScrollToBottomButton"])
    ns.KillFrame(_G["ChatFrame" .. index .. "ButtonFrameMinimizeButton"])
    ns.KillFrame(_G["ChatFrame" .. index .. "ButtonFrame"])
    -- Retail scrollbar and scroll-to-bottom elements
    -- Use OnShow lock because ScrollingMessageFrame re-shows these internally
    if cf.ScrollBar then
        cf.ScrollBar:Hide()
        cf.ScrollBar:UnregisterAllEvents()
        cf.ScrollBar:SetScript("OnShow", cf.ScrollBar.Hide)
    end
    if cf.scrollBar then
        cf.scrollBar:Hide()
        cf.scrollBar:UnregisterAllEvents()
        cf.scrollBar:SetScript("OnShow", cf.scrollBar.Hide)
    end
    if cf.ScrollToBottomButton then
        cf.ScrollToBottomButton:Hide()
        cf.ScrollToBottomButton:SetScript("OnShow", cf.ScrollToBottomButton.Hide)
    end
    if cf.scrollToBottomButton then
        cf.scrollToBottomButton:Hide()
        cf.scrollToBottomButton:SetScript("OnShow", cf.scrollToBottomButton.Hide)
    end
    ns.KillFrame(_G["ChatFrame" .. index .. "ScrollBar"])
    ns.KillFrame(_G["ChatFrame" .. index .. "OverlayFrame"])
    -- Retail: prevent Blizzard from re-showing scroll elements
    if cf.UpdateScrollChildRect then cf.UpdateScrollChildRect = function() end end
    if cf.SetScrollBarShown then cf.SetScrollBarShown = function() end end
    -- Retail: kill the clickable overlay that extends the frame width
    if cf.clickAnywhereButton then ns.KillFrame(cf.clickAnywhereButton) end
    if cf.ResizeBar then ns.KillFrame(cf.ResizeBar) end
    local tab = _G["ChatFrame" .. index .. "Tab"]
    if tab then
        tab:SetAlpha(0)
        tab:SetSize(0.001, 0.001)
        tab:EnableMouse(false)
    end

    cf:SetClampRectInsets(0, 0, 0, 0)
    cf:SetClampedToScreen(true)

    if cf.SetTextInsets then
        cf:SetTextInsets(0, 0, 0, 0)
    elseif cf.SetInsertMode then
        -- fallback
    end

    if cf.SetIndentedWordWrap then
        cf:SetIndentedWordWrap(false)
    end

    local bg = _G["ChatFrame" .. index .. "Background"]
    if bg then
        bg:SetAlpha(0)
    end
    local resize = _G["ChatFrame" .. index .. "ResizeButton"]
    if resize then ns.KillFrame(resize) end

    -- Custom resize handle (bottom-right corner)
    if not cf.gudaResizeHandle then
        cf:SetResizable(true)
        if cf.SetResizeBounds then
            cf:SetResizeBounds(200, 100)
        elseif cf.SetMinResize then
            cf:SetMinResize(200, 100)
        end

        local handle = CreateFrame("Frame", nil, cf)
        handle:SetSize(16, 16)
        handle:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 4, -4)
        handle:SetFrameLevel(cf:GetFrameLevel() + 10)
        handle:EnableMouse(true)

        local grip = handle:CreateTexture(nil, "OVERLAY")
        grip:SetAllPoints()
        grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        grip:SetAlpha(0)
        handle.grip = grip

        handle:SetScript("OnEnter", function(self)
            if GudaChatDB.locked then return end
            self.grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
            self.grip:SetAlpha(0.8)
            SetCursor("UI_RESIZE_CURSOR")
        end)
        handle:SetScript("OnLeave", function(self)
            self.grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
            self.grip:SetAlpha(0)
            ResetCursor()
        end)

        handle:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" or GudaChatDB.locked then return end
            ns.cf1PositionLocked = false
            cf:SetMovable(true)
            cf:StartSizing("BOTTOMRIGHT")
            self.isSizing = true
            self.grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        end)
        handle:SetScript("OnMouseUp", function(self)
            if not self.isSizing then return end
            cf:StopMovingOrSizing()
            self.isSizing = false
            self.grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
            ns.cf1PositionLocked = true
            -- Save size
            local w, h = cf:GetSize()
            GudaChatDB.chatSize = { w = w, h = h }
            -- Save position (may shift during resize)
            local point, _, relPoint, x, y = cf:GetPoint(1)
            if point then
                GudaChatDB.position = { point = point, relPoint = relPoint, x = x, y = y }
            end
            cf:SetUserPlaced(false)
        end)

        cf.gudaResizeHandle = handle
    end

    ns.StyleEditBox(cf, index)
end
ns.StripChatChrome = StripChatChrome

---------------------------------------------------------------------------
-- Rehide all tabs
---------------------------------------------------------------------------

local function RehideAllTabs()
    ns.ForEachChatWindow(function(_, i)
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab then
            tab:SetAlpha(0)
            tab:SetSize(0.001, 0.001)
            tab:EnableMouse(false)
        end
    end)
end
ns.RehideAllTabs = RehideAllTabs
