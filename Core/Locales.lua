local addonName, ns = ...

---------------------------------------------------------------------------
-- Locale loader
--
-- English is copied in as the base, then the client's locale is overlaid key
-- by key. A key that is missing or empty in a translation therefore resolves
-- to English rather than to nil, so a partial translation can never leave a
-- blank label in the UI.
--
-- Follows the same shape as GudaBags/Core/Locales.lua.
---------------------------------------------------------------------------

local AllLocales = ns.Locales or {}

ns.L = {}
for key, value in pairs(AllLocales.enUS or {}) do
    ns.L[key] = value
end

local function ApplyLocaleOverlay(localeCode)
    local overlay = AllLocales[localeCode]
    if not overlay then return false end
    for key, translation in pairs(overlay) do
        if type(translation) == "string" and translation ~= "" then
            ns.L[key] = translation
        end
    end
    return true
end

local currentLocale = GetLocale()
if currentLocale ~= "enUS" then
    ApplyLocaleOverlay(currentLocale)
end

-- Missing keys return the key itself rather than nil: a typo shows up as a
-- visible "OPT_SOMETHING" label instead of erroring inside a SetText call.
setmetatable(ns.L, {
    __index = function(_, key)
        return key
    end,
})

ns.GetLocaleCode = function() return currentLocale end
