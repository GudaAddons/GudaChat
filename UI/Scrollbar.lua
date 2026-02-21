local addonName, ns = ...

---------------------------------------------------------------------------
-- Scrollbar
---------------------------------------------------------------------------

local function CreateScrollbar(chatFrame)
    if chatFrame.gudaScrollbar then return end
    local slider = CreateFrame("Slider", nil, chatFrame, "BackdropTemplate")
    chatFrame.gudaScrollbar = slider
    slider:SetWidth(6)
    local scrollOffR = ns.IS_RETAIL and 12 or 0
    slider:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -2 + scrollOffR, -2)
    slider:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", -2 + scrollOffR, 2)
    slider:SetOrientation("VERTICAL")
    slider:SetMinMaxValues(0, 1)
    slider:SetValue(0)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)

    slider:SetBackdrop(ns.BACKDROP_FLAT)
    slider:SetBackdropColor(0, 0, 0, 0.3)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
    thumb:SetVertexColor(1, 1, 1, 0.4)
    thumb:SetSize(6, 30)
    slider:SetThumbTexture(thumb)

    slider:SetScript("OnEnter", function()
        thumb:SetVertexColor(1, 1, 1, 0.7)
    end)
    slider:SetScript("OnLeave", function()
        thumb:SetVertexColor(1, 1, 1, 0.4)
    end)

    slider:SetScript("OnValueChanged", function(self, value)
        local maxScroll = chatFrame:GetMaxScrollRange()
        local offset = maxScroll - value
        if offset >= 0 then
            chatFrame:SetScrollOffset(offset)
        end
    end)

    local function SyncSlider()
        local maxScroll = chatFrame:GetMaxScrollRange()
        slider:SetMinMaxValues(0, maxScroll)
        local offset = chatFrame:GetScrollOffset()
        slider:SetValue(maxScroll - offset)
    end

    hooksecurefunc(chatFrame, "SetScrollOffset", SyncSlider)

    local ticker = CreateFrame("Frame")
    local elapsed = 0
    ticker:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.2 then
            elapsed = 0
            SyncSlider()
        end
    end)

    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            chatFrame:ScrollUp()
        else
            chatFrame:ScrollDown()
        end
        SyncSlider()
    end)

    slider:SetAlpha(0)

    local sbFadeIn, sbFadeOut
    function slider.FadeIn()
        if sbFadeOut then sbFadeOut:Stop() end
        sbFadeIn = slider:CreateAnimationGroup()
        local anim = sbFadeIn:CreateAnimation("Alpha")
        anim:SetFromAlpha(slider:GetAlpha())
        anim:SetToAlpha(1)
        anim:SetDuration(0.15)
        sbFadeIn:SetScript("OnFinished", function() slider:SetAlpha(1) end)
        sbFadeIn:Play()
    end

    function slider.FadeOut()
        if sbFadeIn then sbFadeIn:Stop() end
        sbFadeOut = slider:CreateAnimationGroup()
        local anim = sbFadeOut:CreateAnimation("Alpha")
        anim:SetFromAlpha(slider:GetAlpha())
        anim:SetToAlpha(0)
        anim:SetDuration(0.25)
        sbFadeOut:SetScript("OnFinished", function() slider:SetAlpha(0) end)
        sbFadeOut:Play()
    end

    -- Scroll to bottom button
    local scrollDown = CreateFrame("Button", nil, chatFrame)
    scrollDown:SetSize(20, 20)
    scrollDown:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", -2 + scrollOffR, 2)
    scrollDown:SetFrameStrata("DIALOG")

    local sdBg = scrollDown:CreateTexture(nil, "BACKGROUND")
    sdBg:SetAllPoints()
    sdBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    sdBg:SetVertexColor(0.08, 0.08, 0.08, 0.8)

    local sdIcon = scrollDown:CreateTexture(nil, "ARTWORK")
    sdIcon:SetPoint("CENTER")
    sdIcon:SetSize(12, 12)
    sdIcon:SetTexture(ns.ASSET_PATH .. "down.png")
    sdIcon:SetVertexColor(0.8, 0.6, 0, 0.9)

    scrollDown:SetScript("OnEnter", function()
        sdIcon:SetVertexColor(1, 0.8, 0, 1)
        sdBg:SetVertexColor(0.12, 0.12, 0.12, 0.9)
    end)
    scrollDown:SetScript("OnLeave", function()
        sdIcon:SetVertexColor(0.8, 0.6, 0, 0.9)
        sdBg:SetVertexColor(0.08, 0.08, 0.08, 0.8)
    end)

    scrollDown:SetScript("OnClick", function()
        chatFrame:ScrollToBottom()
        SyncSlider()
    end)

    scrollDown:Hide()

    local scrollDownMonitor = CreateFrame("Frame")
    scrollDownMonitor:SetScript("OnUpdate", function(self, dt)
        local offset = chatFrame:GetScrollOffset()
        if offset > 0 then
            scrollDown:Show()
        else
            scrollDown:Hide()
        end
    end)

    return slider
end
ns.CreateScrollbar = CreateScrollbar

function ns.FadeInScrollbar()
    if GudaChatDB and GudaChatDB.hideScrollbar then return end
    ns.ForEachChatWindow(function(cf)
        if cf.gudaScrollbar and cf:IsVisible() then
            cf.gudaScrollbar.FadeIn()
        end
    end)
end

function ns.FadeOutScrollbar()
    if GudaChatDB and GudaChatDB.hideScrollbar then return end
    ns.ForEachChatWindow(function(cf)
        if cf.gudaScrollbar and cf:IsVisible() then
            cf.gudaScrollbar.FadeOut()
        end
    end)
end
