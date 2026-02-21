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
    local extraR = ns.IS_RETAIL and 13 or 0
    if position == "top" then
        eb:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", -4, 4)
        eb:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 4 + extraR, 4)
    else
        eb:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", -4, -4)
        eb:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 4 + extraR, -4)
    end
end
ns.PositionEditBox = PositionEditBox

-- Add margin to chat messages on the side where the input bar sits,
-- and reserve screen-edge space so the input bar doesn't go off-screen.
local INPUT_BAR_CLAMP = 34 -- 28px bar + 4px gap + 4px breathing room
ns.INPUT_BAR_CLAMP = INPUT_BAR_CLAMP

local function ApplyChatMargins()
    local pos = GudaChatDB and GudaChatDB.inputPosition or "bottom"
    local topPad = (pos == "top") and INPUT_BAR_MARGIN or 0
    local botPad = (pos == "bottom") and INPUT_BAR_MARGIN or 0
    local topClamp = (pos == "top") and 32 or 4
    local botClamp = (pos == "bottom") and INPUT_BAR_CLAMP or 4

    ns.ForEachChatWindow(function(cf)
        if cf.SetTextInsets then
            cf:SetTextInsets(0, 0, topPad, botPad)
        end
        cf:SetClampRectInsets(-4, 4, topClamp, -botClamp)
        cf:SetClampedToScreen(true)
    end)
end
ns.ApplyChatMargins = ApplyChatMargins

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

    local header = _G["ChatFrame" .. index .. "EditBoxHeader"]
    if header then
        header:SetTextColor(0.6, 0.6, 0.6)
        header:ClearAllPoints()
        header:SetPoint("LEFT", eb, "LEFT", 4, 0)
    end

    -- Override Blizzard's SetTextInsets to always use tight left inset
    local origSetTextInsets = eb.SetTextInsets
    eb.SetTextInsets = function(self, left, right, top, bottom)
        local hdr = _G["ChatFrame" .. index .. "EditBoxHeader"]
        if hdr and hdr:IsShown() then
            left = hdr:GetStringWidth() + 8
        else
            left = 4
        end
        origSetTextInsets(self, left, 28, top or 0, bottom or 0)
    end
    eb:SetTextInsets(0, 28, 0, 0)

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

    eb:HookScript("OnEditFocusGained", function(self)
        if self.gudaBg then
            self.gudaBg:SetBackdropBorderColor(unpack(ns.COLOR_GOLDEN_A))
        end
    end)
    eb:HookScript("OnEditFocusLost", function(self)
        if self.gudaBg then
            self.gudaBg:SetBackdropBorderColor(unpack(ns.COLOR_DARK_BORDER))
        end
        local picker = _G["GudaChatEmojiPicker"]
        if picker and picker:IsShown() then
            picker:Hide()
        end
    end)
end
ns.StyleEditBox = StyleEditBox

-- Prevent Blizzard's FCF_UpdateButtonSide from re-adding button side spacing
if FCF_UpdateButtonSide then
    hooksecurefunc("FCF_UpdateButtonSide", function(cf)
        if cf and cf.SetTextInsets then
            local pos = GudaChatDB and GudaChatDB.inputPosition or "bottom"
            local topPad = (pos == "top") and INPUT_BAR_MARGIN or 0
            local botPad = (pos == "bottom") and INPUT_BAR_MARGIN or 0
            cf:SetTextInsets(0, 0, topPad, botPad)
        end
    end)
end
