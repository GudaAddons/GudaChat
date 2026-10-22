-- Offline test runner (Lua 5.1, the language version WoW uses).
-- Usage, from the addon folder: lua5.1 tests/run.lua
-- Exits with code 1 when any test fails.

local ROOT = arg[1] or "."
package.path = ROOT .. "/tests/?.lua;" .. package.path

local H = require("harness")
H.ROOT = ROOT

local T = { passed = 0, failed = 0, current = "" }

local function Fail(message)
    error({ gudaFailure = true, message = message }, 0)
end

function T.eq(actual, expected, label)
    if actual ~= expected then
        Fail(string.format("%s: got %s, want %s", label or "value", tostring(actual), tostring(expected)))
    end
end

function T.ok(condition, label)
    if not condition then Fail(label or "expected true") end
end

function T.contains(text, part, label)
    if type(text) ~= "string" or not text:find(part, 1, true) then
        Fail(string.format("%s: %s does not contain %s", label or "text", tostring(text), part))
    end
end

function T.case(name, fn)
    local ok, err = pcall(fn)
    if ok then
        T.passed = T.passed + 1
    else
        T.failed = T.failed + 1
        local message = type(err) == "table" and err.message or tostring(err)
        print(string.format("  FAIL %s > %s\n      %s", T.current, name, message))
    end
end

local SUITES = {
    "test_locales",
    "test_names",
    "test_filters",
    "test_emojis",
    "test_logs",
    "test_theme",
    "test_controls",
    "test_whisper",
}

for _, suite in ipairs(SUITES) do
    T.current = suite
    local before = T.failed
    require(suite)(T, H)
    print(string.format("%s %s", T.failed == before and "ok  " or "FAIL", suite))
end

print(string.format("\n%d passed, %d failed", T.passed, T.failed))
os.exit(T.failed == 0 and 0 or 1)
