local addonName, ns = ...

---------------------------------------------------------------------------
-- Edit box positioning
---------------------------------------------------------------------------

local INPUT_BAR_MARGIN = 6
ns.INPUT_BAR_MARGIN = INPUT_BAR_MARGIN

local function PositionEditBox(chatFrame, index, position)
    local eb = _G["ChatFrame" .. index .. "EditBox"]
    if not eb then return end
    eb:ClearAllPoints()
    local extraR = ns.CHAT_EDGE_PAD
    if position == "top" then
        eb:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", -4, -2)
        eb:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 4 + extraR, -2)
    else
        eb:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", -4, -4)
        eb:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 4 + extraR, -4)
    end
end
ns.PositionEditBox = PositionEditBox

-- Recompute the editbox left inset from the header width and apply via the REAL SetTextInsets,
-- instead of permanently overriding the method (the override taints it).
local function ApplyEditBoxInset(index)
    local eb = _G["ChatFrame" .. index .. "EditBox"]
    if not eb or not eb.SetTextInsets then return end
    local hdr = _G["ChatFrame" .. index .. "EditBoxHeader"]
    local left = (hdr and hdr:IsShown()) and (hdr:GetStringWidth() + 8) or 4
    eb:SetTextInsets(left, 28, 0, 0)
end
ns.ApplyEditBoxInset = ApplyEditBoxInset

-- Add margin to chat messages on the side where the input bar sits,
-- and reserve screen-edge space so the input bar doesn't go off-screen.
local INPUT_BAR_CLAMP = 34 -- 28px bar + 4px gap + 4px breathing room
ns.INPUT_BAR_CLAMP = INPUT_BAR_CLAMP

-- How much of the chat frame's own width the scrollbar covers, so the message text can
-- stop where the bar begins. On retail the bar sits outside the frame (CHAT_EDGE_PAD is
-- wider than the bar) so nothing needs reserving; hiding the bar returns the column too.
local function ScrollbarTextInset()
    if GudaChatDB and GudaChatDB.hideScrollbar then return 0 end
    return math.max(0, ns.SCROLLBAR_W + 2 - ns.CHAT_EDGE_PAD)
end
ns.ScrollbarTextInset = ScrollbarTextInset

-- Text insets for one chat frame: input-bar margin top/bottom, scrollbar gutter on the right.
-- Every writer of a chat frame's text insets must go through here, or it wipes the gutter.
local function ApplyFrameInsets(cf)
    if not cf or not cf.SetTextInsets then return end
    local pos = GudaChatDB and GudaChatDB.inputPosition or "bottom"
    local topPad = (pos == "top") and INPUT_BAR_MARGIN or 0
    local botPad = (pos == "bottom") and INPUT_BAR_MARGIN or 0
    cf:SetTextInsets(0, ScrollbarTextInset(), topPad, botPad)
end
ns.ApplyFrameInsets = ApplyFrameInsets

local function ApplyChatMargins()
    local pos = GudaChatDB and GudaChatDB.inputPosition or "bottom"
    local topClamp = (pos == "top") and 32 or 4
    local botClamp = (pos == "bottom") and INPUT_BAR_CLAMP or 4

    ns.ForEachChatWindow(function(cf)
        ApplyFrameInsets(cf)
        cf:SetClampRectInsets(-4, 4, topClamp, -botClamp)
        cf:SetClampedToScreen(true)
    end)
end
ns.ApplyChatMargins = ApplyChatMargins

-- Flip the input bar between top and bottom. The chat window itself does not move; only the
-- clamp reserve changes sides. If the new reserve genuinely pushes the frame (the bar would
-- land off-screen), SettleChatPosition persists that correction so nothing snaps it later.
local function ApplyInputBarPosition()
    ns.ForEachChatWindow(function(cf, i)
        ns.PositionEditBox(cf, i, GudaChatDB and GudaChatDB.inputPosition or "bottom")
    end)
    ApplyChatMargins()
    ns.SettleChatPosition()
end
ns.ApplyInputBarPosition = ApplyInputBarPosition

---------------------------------------------------------------------------
-- Edit box styling
---------------------------------------------------------------------------

local function StyleEditBox(chatFrame, index)
    local eb = _G["ChatFrame" .. index .. "EditBox"]
    if not eb then return end

    -- Strip Blizzard edit box textures (preserve cursor)
    for _, region in pairs({eb:GetRegions()}) do
        if region:GetObjectType() == "Texture" then
            local layer = region:GetDrawLayer()
            if layer ~= "OVERLAY" then
                region:SetTexture(nil)
                region:Hide()
            end
        end
    end
    local focusLeft = _G["ChatFrame" .. index .. "EditBoxFocusLeft"]
    local focusMid = _G["ChatFrame" .. index .. "EditBoxFocusMid"]
    local focusRight = _G["ChatFrame" .. index .. "EditBoxFocusRight"]
    if focusLeft then focusLeft:SetTexture(nil) end
    if focusMid then focusMid:SetTexture(nil) end
    if focusRight then focusRight:SetTexture(nil) end

    eb:SetHeight(28)

    -- Position based on saved setting
    local pos = GudaChatDB and GudaChatDB.inputPosition or "bottom"
    PositionEditBox(chatFrame, index, pos)

    -- Backdrop
    if not eb.gudaBg then
        local bg = CreateFrame("Frame", nil, eb, "BackdropTemplate")
        bg:SetAllPoints(eb)
        bg:SetFrameLevel(eb:GetFrameLevel() - 1)
        ns.ApplyDarkBackdrop(bg, ns.COLOR_HEADER_BG, ns.COLOR_DARK_BORDER)
        eb.gudaBg = bg
    end

    if GudaChatDB and GudaChatDB.transparentInput and eb.gudaBg then
        eb.gudaBg:SetAlpha(0)
    end

    local header = _G["ChatFrame" .. index .. "EditBoxHeader"]
    if header then
        header:SetTextColor(0.6, 0.6, 0.6)
        header:ClearAllPoints()
        header:SetPoint("LEFT", eb, "LEFT", 4, 0)
    end

    -- Apply tight left inset once (no method replacement).
    ns.ApplyEditBoxInset(index)

    -- Emoji picker button
    local emojiBtn = CreateFrame("Button", nil, eb)
    emojiBtn:SetSize(18, 18)
    emojiBtn:SetPoint("RIGHT", eb, "RIGHT", -5, 0)

    local emojiIcon = emojiBtn:CreateTexture(nil, "ARTWORK")
    emojiIcon:SetAllPoints()
    emojiIcon:SetTexture(ns.ASSET_PATH .. "emoji_smile.png")
    emojiIcon:SetAlpha(0.5)

    emojiBtn:SetScript("OnEnter", function() emojiIcon:SetAlpha(1) end)
    emojiBtn:SetScript("OnLeave", function() emojiIcon:SetAlpha(0.5) end)
    emojiBtn:SetScript("OnClick", function()
        ns.ToggleEmojiPicker(eb)
    end)

    -- Show/hide based on emoji setting
    if GudaChatDB and GudaChatDB.emojis then
        emojiBtn:Show()
    else
        emojiBtn:Hide()
    end
    eb.emojiBtn = emojiBtn

    eb:SetAlpha(1)
    eb.chatFrame = chatFrame

    -- On the modern engine, force classic-style edit box: hidden until focused.
    -- Hook OnShow so Blizzard's chat style system cannot keep it visible.
    if ns.IS_MODERN then
        eb:Hide()
        eb:SetAutoFocus(false)
        eb:HookScript("OnShow", function(self)
            -- Allow show only during chat activation (focus will follow).
            -- If shown without focus and not about to get it, re-hide next frame.
            C_Timer.After(0, function()
                if self:IsShown() and not self:HasFocus() then
                    self:Hide()
                end
            end)
        end)
    end

    eb:HookScript("OnEditFocusGained", function(self)
        ns.hideHeaderForInput = true
        self:Show()
        ns.ApplyEditBoxInset(index)
        if self.gudaBg then
            if GudaChatDB and GudaChatDB.transparentInput then
                self.gudaBg:SetAlpha(0)
            else
                self.gudaBg:SetBackdropBorderColor(unpack(ns.COLOR_GOLDEN_A))
            end
        end
    end)
    eb:HookScript("OnEditFocusLost", function(self)
        ns.hideHeaderForInput = false
        if ns.IS_MODERN then
            self:Hide()
        end
        ns.ApplyEditBoxInset(index)
        if self.gudaBg then
            if GudaChatDB and GudaChatDB.transparentInput then
                self.gudaBg:SetAlpha(0)
            else
                self.gudaBg:SetBackdropBorderColor(unpack(ns.COLOR_DARK_BORDER))
            end
        end
        local picker = _G["GudaChatEmojiPicker"]
        if picker and picker:IsShown() then
            picker:Hide()
        end
    end)
end
ns.StyleEditBox = StyleEditBox

function ns.ApplyTransparentInput()
    local transparent = GudaChatDB and GudaChatDB.transparentInput
    ns.ForEachChatWindow(function(_, i)
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb and eb.gudaBg then
            if transparent then
                eb.gudaBg:SetAlpha(0)
            else
                eb.gudaBg:SetAlpha(1)
                eb.gudaBg:SetBackdropBorderColor(unpack(ns.COLOR_DARK_BORDER))
            end
        end
    end)
end

-- Prevent Blizzard's FCF_UpdateButtonSide from re-adding button side spacing
if FCF_UpdateButtonSide then
    hooksecurefunc("FCF_UpdateButtonSide", function(cf)
        ns.ApplyFrameInsets(cf)
    end)
end
