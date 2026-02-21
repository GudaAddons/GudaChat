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
