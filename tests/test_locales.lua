-- Every locale has exactly the English keys with the same format codes, and every
-- L["KEY"] the addon code uses exists in English.

local LOCALES = { "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }

-- Counts of the format codes and colour escapes a translation must keep
local function FormatSignature(text)
    local counts = { s = 0, d = 0, percent = 0, color = 0, reset = 0 }
    for code in text:gmatch("%%[%d%$]*([sd%%])") do
        if code == "%" then
            counts.percent = counts.percent + 1
        else
            counts[code] = counts[code] + 1
        end
    end
    for _ in text:gmatch("|c%x%x%x%x%x%x%x%x") do counts.color = counts.color + 1 end
    for _ in text:gmatch("|r") do counts.reset = counts.reset + 1 end
    return string.format("s=%d d=%d %%=%d c=%d r=%d",
        counts.s, counts.d, counts.percent, counts.color, counts.reset)
end

local function TocFiles(H)
    local files = {}
    local toc = assert(H.ReadFile("GudaChat.toc"), "GudaChat.toc not found")
    for line in toc:gmatch("[^\r\n]+") do
        if line:find("%.lua%s*$") and not line:find("^#") then
            files[#files + 1] = (line:gsub("\\", "/"):gsub("%s+$", ""))
        end
    end
    return files
end

return function(T, H)
    local ns = H.Load()
    local english = ns.Locales.enUS

    for _, locale in ipairs(LOCALES) do
        T.case(locale .. " has every English key", function()
            local strings = ns.Locales[locale]
            for key in pairs(english) do
                T.ok(type(strings[key]) == "string" and strings[key] ~= "", locale .. " misses " .. key)
            end
        end)

        T.case(locale .. " has no extra keys", function()
            for key in pairs(ns.Locales[locale]) do
                T.ok(english[key] ~= nil, locale .. " has unknown key " .. key)
            end
        end)

        T.case(locale .. " keeps the format codes", function()
            for key, text in pairs(english) do
                local translated = ns.Locales[locale][key]
                if translated then
                    T.eq(FormatSignature(translated), FormatSignature(text), locale .. " " .. key)
                end
            end
        end)
    end

    T.case("every L key used in the code exists in English", function()
        for _, file in ipairs(TocFiles(H)) do
            if file ~= "Locales.lua" then
                local source = assert(H.ReadFile(file), file .. " not found")
                for key in source:gmatch("L%[\"([%w_]+)\"%]") do
                    T.ok(english[key] ~= nil, file .. " uses missing key " .. key)
                end
            end
        end
    end)
end
