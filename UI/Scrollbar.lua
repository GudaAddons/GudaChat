local addonName, ns = ...

---------------------------------------------------------------------------
-- Scrollbar
---------------------------------------------------------------------------

-- Fallback sync period. Scrolling through any ScrollingMessageFrame method updates the bar
-- at once through the hooks below; the ticker only catches changes no method reports,
-- such as new lines growing the scroll range. It is parented to its chat frame, so it
-- stops while the window is hidden.
local SYNC_INTERVAL = 0.2
local SCROLL_METHODS = { "ScrollUp", "ScrollDown", "ScrollToTop", "ScrollToBottom", "PageUp", "PageDown" }

local FADE_IN_DURATION = 0.15
local FADE_OUT_DURATION = 0.25

local function CreateScrollbar(chatFrame)
    if chatFrame.gudaScrollbar then return end
    local slider = CreateFrame("Slider", nil, chatFrame, "BackdropTemplate")
    chatFrame.gudaScrollbar = slider
    slider:SetWidth(ns.SCROLLBAR_W)
    -- Sit just inside the right edge of the message area (which extends CHAT_EDGE_PAD past
    -- the frame's own right edge on retail). ApplyFrameInsets reserves the matching gutter.
    local rightEdge = ns.CHAT_EDGE_PAD - 2
    slider:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", rightEdge, -2)
    slider:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", rightEdge, 2)
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
    thumb:SetSize(ns.SCROLLBAR_W, 30)
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

    local scrollDown

    local function SyncSlider()
        local maxScroll = chatFrame:GetMaxScrollRange()
        slider:SetMinMaxValues(0, maxScroll)
        local offset = chatFrame:GetScrollOffset()
        slider:SetValue(maxScroll - offset)
        if scrollDown then
            scrollDown:SetShown(offset > 0)
        end
    end

    hooksecurefunc(chatFrame, "SetScrollOffset", SyncSlider)
    for _, method in ipairs(SCROLL_METHODS) do
        if chatFrame[method] then
            hooksecurefunc(chatFrame, method, SyncSlider)
        end
    end

    local ticker = CreateFrame("Frame", nil, chatFrame)
    local elapsed = 0
    ticker:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= SYNC_INTERVAL then
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

    local sbFadeIn = ns.CreateFade(slider, 1, FADE_IN_DURATION)
    local sbFadeOut = ns.CreateFade(slider, 0, FADE_OUT_DURATION)

    function slider.FadeIn()
        sbFadeOut:Stop()
        if slider:GetAlpha() >= 1 then return end
        sbFadeIn:PlayFromCurrent()
    end

    function slider.FadeOut()
        sbFadeIn:Stop()
        if slider:GetAlpha() <= 0 then return end
        sbFadeOut:PlayFromCurrent()
    end

    -- Scroll to bottom button
    scrollDown = CreateFrame("Button", nil, chatFrame)
    scrollDown:SetSize(20, 20)
    scrollDown:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", rightEdge, 2)
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
    SyncSlider()

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
