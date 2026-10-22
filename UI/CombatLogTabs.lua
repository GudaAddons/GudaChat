local addonName, ns = ...

---------------------------------------------------------------------------
-- Combat log filtering (My Actions / What Happened to Me?)
-- Uses Blizzard's native Blizzard_CombatLog filter system:
--   Filter 1 = Self (My Actions)
--   Filter 2 = Everything
--   Filter 3 = What Happened to Me?
--   Filter 4 = Kills
---------------------------------------------------------------------------

local SUBTAB_BAR_HEIGHT = 20
local C = ns.Theme.C
local FILTER_RETRY_DELAY = 1

local combatLogFilter = "mine"
local combatSubTabList = {}

-- White for the active filter's subtab, grey for the other
local function UpdateCombatSubTabColors()
    for _, t in ipairs(combatSubTabList) do
        if t.key == combatLogFilter then
            ns.Paint(t.btn.text, C.subtabActive)
        else
            ns.Paint(t.btn.text, C.subtabInactive)
        end
    end
end
ns.UpdateCombatSubTabColors = UpdateCombatSubTabColors

-- First filter whose saved settings have COMBATLOG_FILTER_ME as source only ("mine") or
-- as destination ("tome")
local function FindFilterByFlags(filters, key)
    if not COMBATLOG_FILTER_ME then return nil end
    local function FirstFlag(flags)
        if type(flags) == "table" then return flags[1] or 0 end
        return flags
    end
    for i, filter in ipairs(filters) do
        local settings = filter.settings or filter
        if key == "mine" and settings.sourceFlags then
            local flags = FirstFlag(settings.sourceFlags)
            if type(flags) == "number" and bit.band(flags, COMBATLOG_FILTER_ME) > 0 then
                local dFlags = FirstFlag(settings.destFlags)
                if not dFlags or dFlags == 0 or type(dFlags) ~= "number" then
                    return i
                end
            end
        elseif key == "tome" and settings.destFlags then
            local flags = FirstFlag(settings.destFlags)
            if type(flags) == "number" and bit.band(flags, COMBATLOG_FILTER_ME) > 0 then
                return i
            end
        end
    end
    return nil
end

-- Index of the Blizzard filter for key: by its localized quick-button name, then by its
-- flags, then by position
local function FindFilterIndex(filters, key)
    local targetName
    if key == "mine" then
        targetName = type(QUICKBUTTON_NAME_SELF) == "string" and QUICKBUTTON_NAME_SELF or nil
    elseif key == "tome" then
        targetName = type(QUICKBUTTON_NAME_ME) == "string" and QUICKBUTTON_NAME_ME or nil
    end
    if targetName then
        for i, filter in ipairs(filters) do
            if filter.name == targetName then return i end
        end
        for i, filter in ipairs(filters) do
            if filter.hasQuickButton and filter.quickButtonName == targetName then return i end
        end
    end

    local idx = FindFilterByFlags(filters, key)
    if idx then return idx end

    if key == "mine" then return 1 end
    if key == "tome" then return #filters >= 4 and 3 or #filters end
    return nil
end

-- Switches the combat log to "mine" (My Actions) or "tome" (What Happened to Me?). Only
-- called when the player picks a subtab and once at login: refiltering rebuilds the whole
-- combat log, and the player's choice must survive switching to other tabs.
-- CombatLog_SwitchToFilter (present on modern and Classic clients) updates the
-- CombatLogProcessor's filterSettings correctly and refreshes the window. Assigning
-- combatLogProcessor.filterSettings ourselves corrupts the processor's state and makes
-- Blizzard_CombatLogProcessor throw on every combat event. The ApplyFilters path is the
-- legacy fallback for older clients.
local function SwitchCombatLogFilter(key)
    combatLogFilter = key
    UpdateCombatSubTabColors()
    if not Blizzard_CombatLog_Filters then return end
    local filters = Blizzard_CombatLog_Filters.filters
    if not filters then return end

    local idx = FindFilterIndex(filters, key)
    if not idx or not filters[idx] then return end

    if CombatLog_SwitchToFilter then
        CombatLog_SwitchToFilter(idx)
    elseif Blizzard_CombatLog_ApplyFilters then
        Blizzard_CombatLog_CurrentSettings = filters[idx]
        Blizzard_CombatLog_Filters.currentFilter = idx
        Blizzard_CombatLog_ApplyFilters(filters[idx])
        if Blizzard_CombatLog_Refilter then
            Blizzard_CombatLog_Refilter()
        end
    end
end
ns.SwitchCombatLogFilter = SwitchCombatLogFilter

-- The subtab bar above the header while the combat log is selected. Its labels are
-- Blizzard's own combat-log filter names, already localized.
function ns.CreateCombatSubTabs(header)
    local bar = CreateFrame("Frame", "GudaChatCombatSubTabs", UIParent, "BackdropTemplate")
    bar:SetHeight(SUBTAB_BAR_HEIGHT)
    bar:SetPoint("BOTTOMLEFT", header, "TOPLEFT", 0, -1)
    bar:SetPoint("BOTTOMRIGHT", header, "TOPRIGHT", 0, -1)
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(101)

    ns.ApplyDarkBackdrop(bar, C.barBg, C.barBorder)
    bar:EnableMouse(true)
    bar:SetAlpha(0)
    bar:Hide()

    local tabDefs = {
        { key = "mine", label = ns.Blizz(QUICKBUTTON_NAME_SELF, "My Actions") },
        { key = "tome", label = ns.Blizz(QUICKBUTTON_NAME_ME, "What Happened to Me?") },
    }

    local xOff = 6
    for _, def in ipairs(tabDefs) do
        local btn = CreateFrame("Button", nil, bar)
        btn:SetHeight(16)

        local text = btn:CreateFontString(nil, "OVERLAY", "GudaChatFontNormalSmall")
        text:SetPoint("LEFT", btn, "LEFT", 0, 0)
        text:SetText(def.label)
        btn.text = text

        btn:SetWidth(text:GetStringWidth() + 8)
        btn:SetPoint("LEFT", bar, "LEFT", xOff, 0)
        xOff = xOff + btn:GetWidth() + 8

        btn:SetScript("OnClick", function()
            SwitchCombatLogFilter(def.key)
        end)
        btn:SetScript("OnEnter", function(self)
            ns.Paint(self.text, C.subtabHover)
            ns.RevealHeader()
        end)
        btn:SetScript("OnLeave", UpdateCombatSubTabColors)

        tinsert(combatSubTabList, { key = def.key, btn = btn })
    end

    UpdateCombatSubTabColors()
    ns.combatSubTabs = bar

    SwitchCombatLogFilter("mine")
    if not Blizzard_CombatLog_Filters then
        C_Timer.After(FILTER_RETRY_DELAY, function() SwitchCombatLogFilter(combatLogFilter) end)
    end

    return bar
end
