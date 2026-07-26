local addonName, ns = ...

---------------------------------------------------------------------------
-- Translations
--
-- English is the base; every other locale is a partial overlay, so a key that
-- is missing or left empty simply falls back to the English text. To add a
-- language, fill in its section below — no UI code has to change.
--
-- Only strings with no Blizzard equivalent live here. Anything the client
-- already translates (Settings, Search, Copy, Guild, Party, ...) goes through
-- ns.Blizz in Core/Constants.lua instead, so it needs no translation at all.
---------------------------------------------------------------------------

local Locales = {
    enUS = {}, deDE = {}, frFR = {}, ruRU = {}, esES = {}, esMX = {},
    ptBR = {}, itIT = {}, zhCN = {}, zhTW = {}, koKR = {},
}

ns.Locales = Locales

---------------------------------------------------------------------------
-- English (base language)
---------------------------------------------------------------------------

local L = Locales.enUS

-- Window titles
L["HISTORY_TITLE"] = "GudaChat History"

-- Settings: tabs
L["TAB_GENERAL"] = "General"
L["TAB_MESSAGES"] = "Messages"
L["TAB_HISTORY"] = "History"
L["TAB_NOTIFICATIONS"] = "Notifications"

-- Settings: section headers
L["SEC_CHAT_WINDOW"] = "Chat Window"
L["SEC_INPUT_BAR"] = "Input Bar"
L["SEC_TABS"] = "Tabs"
L["SEC_BACKGROUND"] = "Background"
L["SEC_MESSAGES"] = "Messages"
L["SEC_NAME_HIGHLIGHT"] = "Name Highlight"
L["SEC_EMOJIS"] = "Emojis"
L["SEC_HISTORY"] = "History"
L["SEC_TAB_BLINK"] = "Tab Blink Notifications"
L["SEC_NUMBERED_CHANNELS"] = "Numbered Channels"

-- Settings: general tab
L["OPT_LOCK_POSITION"] = "Lock chat position"
L["OPT_DISABLE_FADING"] = "Disable message fading"
L["OPT_FONT"] = "Font"
L["OPT_HIDE_SCROLLBAR"] = "Hide scrollbar"
L["OPT_TIMESTAMPS"] = "Timestamps"
L["OPT_INPUT_BAR_TOP"] = "Input bar on top"
L["OPT_TRANSPARENT_INPUT"] = "Transparent input bar"
L["OPT_SHOW_TAB_BAR"] = "Show tab bar"
L["OPT_INLINE_TAB_BAR"] = "Inline tab bar"
L["OPT_WHISPER_TAB"] = "Whisper tab"
L["OPT_OVERRIDE_BACKGROUNDS"] = "Override per-tab backgrounds"

-- Settings: messages tab
L["OPT_CLASS_COLORS"] = "Class colored names"
L["OPT_SHOW_LEVEL"] = "Show player level"
L["OPT_COPYABLE_LINKS"] = "Copyable links"
L["OPT_HIGHLIGHT_NAME"] = "Highlight my name"
L["OPT_MENTION_SOUND"] = "Sound on mention"
L["OPT_ENABLE_EMOJIS"] = "Enable emojis"
L["OPT_EMOJI_SIZE"] = "Emoji size"

-- Settings: history tab
L["OPT_ENABLE_HISTORY"] = "Enable history"
L["OPT_LOG_LOOT"] = "Log loot"
L["OPT_LOG_ADDON"] = "Log addon messages"
L["OPT_MAX_MESSAGES"] = "Max messages"
L["OPT_FONT_SIZE"] = "Font size"
L["BTN_CLEAR_HISTORY"] = "Clear History"
L["CONFIRM_CLEAR_HISTORY"] = "Are you sure you want to clear all chat history?"

-- Settings: notifications tab
L["OPT_ENABLE_NOTIFICATIONS"] = "Enable notifications"
L["OPT_GENERAL_TAB"] = "General tab"
L["OPT_NOTIFY_PARTY"] = "Party"
L["OPT_NOTIFY_RAID"] = "Raid / Instance"
L["OPT_NOTIFY_GUILD"] = "Guild / Officer"
L["OPT_NOTIFY_WHISPERS"] = "Whispers"
L["OPT_NOTIFY_TRADE"] = "Trade"
L["OPT_NOTIFY_LFG"] = "LookingForGroup"
L["OPT_NOTIFY_OTHER"] = "Other (custom channels)"

-- Header: tooltips and menus
L["TIP_HISTORY"] = "History"
L["TIP_CHAT_CHANNELS"] = "Chat Channels"
L["TIP_CHAT_TYPE"] = "Chat Type"
L["TIP_DRAG_TO_MOVE"] = "Drag to move"
L["TIP_TAB_SWITCH"] = "Click to switch tabs, right-click for options"
L["MENU_NEW_WINDOW"] = "Create New Window"
L["MENU_LEAVE"] = "Leave %s"
L["PROMPT_RENAME_WINDOW"] = "Enter new name for this chat window:"

-- History viewer
L["TIP_LOOT"] = "Loot"
L["TIP_LOG"] = "Log"
L["LOOT_FROM"] = "from"
L["COPY_HINT"] = "Ctrl+C to copy. Escape to close."
L["COPY_HINT_SHORT"] = "Ctrl+C to copy, Escape to close"
L["PREVIOUS_SESSION"] = "--- previous session ---"

-- Emote menu. Keys match the emote tokens in UI/Header.lua; the tokens
-- themselves must not be translated, only these display labels.
L["EMOTE_WAVE"] = "Wave"
L["EMOTE_DANCE"] = "Dance"
L["EMOTE_BOW"] = "Bow"
L["EMOTE_CHEER"] = "Cheer"
L["EMOTE_CLAP"] = "Clap"
L["EMOTE_CRY"] = "Cry"
L["EMOTE_FLEX"] = "Flex"
L["EMOTE_GOODBYE"] = "Goodbye"
L["EMOTE_HELLO"] = "Hello"
L["EMOTE_KISS"] = "Kiss"
L["EMOTE_LAUGH"] = "Laugh"
L["EMOTE_NO"] = "No"
L["EMOTE_POINT"] = "Point"
L["EMOTE_RUDE"] = "Rude"
L["EMOTE_SALUTE"] = "Salute"
L["EMOTE_SHY"] = "Shy"
L["EMOTE_SIT"] = "Sit"
L["EMOTE_SLEEP"] = "Sleep"
L["EMOTE_SMILE"] = "Smile"
L["EMOTE_THANK"] = "Thank"
L["EMOTE_YES"] = "Yes"
L["EMOTE_ANGRY"] = "Angry"
L["EMOTE_BEG"] = "Beg"
L["EMOTE_APPLAUD"] = "Applaud"

-- Slash command output
L["LOADED"] = "loaded — type |cffffd200/gc|r for settings"
L["CMD_HEADER"] = "commands:"
L["CMD_OPEN_SETTINGS"] = "open settings"

---------------------------------------------------------------------------
-- Deutsch
---------------------------------------------------------------------------
L = Locales.deDE

---------------------------------------------------------------------------
-- Français
---------------------------------------------------------------------------
L = Locales.frFR

---------------------------------------------------------------------------
-- Русский
---------------------------------------------------------------------------
L = Locales.ruRU

---------------------------------------------------------------------------
-- Español (EU)
---------------------------------------------------------------------------
L = Locales.esES

---------------------------------------------------------------------------
-- Español (AL)
---------------------------------------------------------------------------
L = Locales.esMX

---------------------------------------------------------------------------
-- Português
---------------------------------------------------------------------------
L = Locales.ptBR

---------------------------------------------------------------------------
-- Italiano
---------------------------------------------------------------------------
L = Locales.itIT

---------------------------------------------------------------------------
-- 简体中文
---------------------------------------------------------------------------
L = Locales.zhCN

---------------------------------------------------------------------------
-- 繁體中文
---------------------------------------------------------------------------
L = Locales.zhTW

---------------------------------------------------------------------------
-- 한국어
---------------------------------------------------------------------------
L = Locales.koKR
