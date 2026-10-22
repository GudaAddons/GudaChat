# GudaChat: architecture and development guide

GudaChat replaces the look of Blizzard's chat frame (tabs, buttons, input bar, scrollbar) with its own clean UI. It does not replace Blizzard's chat logic: messages, channels and windows stay Blizzard's, and GudaChat adds filters, hooks and its own frames around them.

Read this before changing code. The taint rules below exist because breaking them crashed the chat on Retail 12.

## Files and load order

Load order is the order in `GudaChat.toc`. Every file starts with `local addonName, ns = ...` and shares the `ns` table.

| File | What it does |
|------|--------------|
| `Locales.lua` | All translations (`ns.Locales.enUS`, `deDE`, ...). esMX copies esES and overrides a few keys. |
| `Core/Locales.lua` | Builds `ns.L`: English first, then the client's language on top. A missing key returns the key name. |
| `Core/Theme.lua` | Themes (Classic, Modern Dark, Blizzard): the palette `ns.Theme.C`, `ns.ApplyDarkBackdrop` / `ns.SetPanelBorder` (themed panels), `ns.Paint` (themed text and textures), `Theme.PaintTab`, theme font objects, live switching. Loaded before Constants. See "Themes". |
| `Core/Constants.lua` | Shared helpers and constants: client detection, secret-value helpers, name comparison, `LineMemo`, `CreateFade`, backdrops, `ForEachChatWindow` / `ForEachChatFrame`, chat position helpers, copy popup, `UTF8Lower`, `ns.Blizz`, `ns.SlashCmd`. |
| `Core/Emojis.lua` | Emoji data, picker, `SplitProtected` (splits a message into plain text and links), emoji replacement filter. |
| `Core/EditBox.lua` | Input bar style and position, emoji button. Runs once per edit box (`eb.gudaStyled`). |
| `Core/Filters.lua` | Class colours, player level, copyable URL links, own-name highlight and mention sound. Link click handling. |
| `Core/Logs.lua` | Loot log and addon message log (ring buffers), loot line parsing. |
| `Core/WhisperModel.lua` | Pure data for the whisper icon: received whispers per person (`ns.NewWhisperModel`, `ns.WhisperKey`), unread count, newest-first list, "latest" person, ring order, and the ring geometry and tap helpers. No frames, so the tests cover it. |
| `Core/Chrome.lua` | Hides Blizzard's chat chrome (tabs, buttons, dock manager), lock state, window colours. |
| `UI/Widgets.lua` | Shared widgets: icon buttons, menu items (`ns.CreateMenuItem`, reusable `ns.GetMenuItem`), click-outside closers, `ns.ShowColorPicker` (both picker generations), fade and hover timings. |
| `UI/Controls.lua` | Themed controls for the settings and history windows: `ns.CreateThemedWindow`, `ns.CreateScrollArea`, `ns.CreateCard`, `ns.CreateSettingsRow`, `ns.CreateToggle`, `ns.CreateSlider`, `ns.CreateDropdown`, `ns.CreateSwatch`, `ns.CreateThemedButton`, `ns.CreateTextTabs`, and `ns.OnRestyle`. |
| `UI/Selection.lua` | Which chat window is selected: `ns.SafeSelectDockFrame`, `ns.GetSelectedChatFrame(Index)`, `ns.OnFrameSelected`, `ns.SetCombatLogVisible`, `ns.GetChatTabName`, `ns.RequestTabRefresh`. |
| `UI/Tabs/Model.lua` | Tab data: which windows get a tab (`ns.CollectChatTabs`), tab colours, saved tab order and drag moves, unread blink state with its one event listener. |
| `UI/Tabs/TabStrip.lua` | One tab strip renderer (fit, overflow menu, drag to reorder, blink, button pools) used twice: the bar above the header (created here) and the inline tabs (created by the header). |
| `UI/ContextMenu.lua` | Right-click window menu: rename, new window, remove or leave, font size, background colour. `ns.RemoveWindow`. |
| `UI/CombatLogTabs.lua` | Combat log sub-tabs (My Actions / What Happened to Me?) and Blizzard filter switching. |
| `UI/Whisper.lua` | Whispers window, whisper routing and its logout undo, switching to the right tab when the player sends a message. |
| `UI/ChatTypeMenu.lua` | Chat type and emote menus on the header's chat icon. |
| `UI/Scrollbar.lua` | Thin scrollbar and scroll-to-bottom button per chat frame. |
| `UI/Header.lua` | The header bar itself: hover fade, drag to move, icon buttons, tab label and window dropdown, inline tab setup. |
| `UI/IdleText.lua` | "Hide text when chat is not in use": fades the message text of every chat frame when the chat is idle. See "Idle chat text". |
| `UI/History.lua` | History capture, the history viewer (search, channel tabs, copy), replay at login. |
| `UI/WhisperIcon.lua` | Whisper icon with unread badge, hover list, reply panel, whisper ring, the "Whisper ring" key binding handler and the Whisper icon settings card. See "Whisper icon". |
| `UI/Settings.lua` | Settings window: sidebar pages Appearance, Chat, Messages, Tabs & Alerts, History & Logs, About (see "Settings window"). Chat font options and helpers. |
| `GudaChat.lua` | Slash command, saved data defaults and migrations, login setup, logout handling. |
| `Bindings.xml` | The "Whisper ring" key binding under Key Bindings > GudaChat (unbound by default). The game loads it by itself; it is not in the TOC. |
| `tests/` | Offline tests. Not in the TOC, so the game never loads them. |

## Saved data

| Variable | Scope | Contents |
|----------|-------|----------|
| `GudaChatDB` | Account | All settings: `position`, `chatSize`, `locked`, `fading`, `chatFont`, `chatFontSize`, `inputPosition`, `transparentInput`, `showTabBar`, `inlineTabBar`, `tabOrder`, `whisperTab`, `whisperFrameIndex`, `origWhisperMode`, `theme`, `accent`, `settingsPosition`, `historyPosition`, `useGlobalBg`, `bgFromTheme`, `globalBgColor`, `globalBgAlpha`, `classColors`, `showLevel`, `copyLinks`, `highlightName`, `highlightSound`, `emojis`, `emojiSize`, `historyEnabled`, `historyMax`, `historyFontSize`, `logLoot`, `logAddon`, `lootLogMax`, `addonLogMax`, `hideScrollbar`, `hideIdleText`, `notifications`, `whisperIcon` (`enabled`, `userSet`, `alwaysShow`, `hideInCombat`, saved icon `point`/`relPoint`/`x`/`y`). On WoW: Forever also `charCopies` (see below). |
| `GudaChatCharDB` | Character | `history` (one bucket per channel, keyed by channel label), `lootLog`, `addonLog` (ring buffers with a `head` field), `logSchema`, `savedAt`. |

- Defaults and one-time migrations run in `GudaChat.lua` at `ADDON_LOADED`. Older versions kept history and logs in `GudaChatDB`; the first character that logs in takes them over.
- The history cap (`historyMax`, 500 to 4000) is shared by the channel buckets. The loot log (`lootLogMax`, default 500) and the addon log (`addonLogMax`, default 300) have their own caps.
- Never save a secret value. Use `ns.SafeName` before storing any chat argument.

### WoW: Forever and lost saved data

Forever often does not load SavedVariables back after a full restart, and the player-side fix (Forever Data Protect) only restores account-wide files. So on Forever only:

- At `PLAYER_LOGOUT`, `GudaChatCharDB` is stamped with `savedAt` and copied into `GudaChatDB.charCopies[<character GUID>]`.
- At `ADDON_LOADED`, the copy replaces `GudaChatCharDB` when it is newer or the character file is missing.

This is the same design as GudaBags (`Core/Database.lua`).

## Clients and detection

Supported: Retail (12.x), MoP Classic (5.5.x), TBC Anniversary (2.5.x), Classic Era (1.15.x) and WoW: Forever (1.60.x, Interface 16001). One TOC lists all of them.

| Flag (`Core/Constants.lua`) | Meaning |
|------|---------|
| `ns.IS_RETAIL` | Interface 110000 or higher. |
| `ns.IS_FOREVER` | Interface 16000 to 19999. Forever has no `WOW_PROJECT_ID`. |
| `ns.HAS_MAINLINE_CHAT` | Retail or Forever. Both run Blizzard's Mainline chat code, so use this flag, not `IS_RETAIL`, for chat behaviour (link clicks, the 13 px right gutter `CHAT_EDGE_PAD`). |

Prefer feature checks (`if SomeFunction then`, `DoesTemplateExist`) over version checks. Moved Blizzard functions go through `ns.OpenChat`, `ns.SendTell` and `ns.PerformEmote`.

### Secret values

On Retail 12 and on Forever, some chat arguments (message, sender, GUID, level) can be "secret": addon code cannot read, compare or join them, and trying throws an error.

- Every chat filter starts with `if not msg or ns.IsSecret(msg) then return false end`.
- Use `ns.SafeName`, `ns.SafeShortName`, `ns.NamesMatch`, `ns.CompactName` and `ns.SameCharacter` for names. They return nil or "no match" for secret values.

### Names

Compare characters with `ns.SameCharacter(a, b)`. It ignores the realm, spaces and case, so it works for `Name-Realm` (Classic, Retail) and for Forever's two-part names (`Given Family`, `GivenFamily`). `ns.UnitFullName(unit)` returns `Given Family` on Forever, where `UnitName` returns the two parts as two values.

## Taint rules

Taint is what happens when addon code touches something Blizzard's protected code later uses. On Retail 12 it ends in "secret value" crashes and "Interface action failed" errors.

1. Never replace a Blizzard method or global function (`frame.Show = ...`, `FCF_StartDragging = ...`). Use `hooksecurefunc` or `frame:HookScript` instead.
2. Never write Blizzard tables or fields (`UIPARENT_MANAGED_FRAME_POSITIONS`, `editBox.chatFrame`). Store our own data under `gudaXxx` names.
3. To hide a Blizzard frame, use `ns.KillFrame` (reparent to a hidden frame), never override `Show`.
4. Do not call `FCF_SelectDockFrame` from addon code. Use `ns.SafeSelectDockFrame`. It writes exactly two Blizzard values, on purpose: `GENERAL_CHAT_DOCK.selected`, so Blizzard's dock updates keep our tab on top, and `SELECTED_CHAT_FRAME`, which Blizzard's chat input and window options read. GudaChat reads its own `ns.GetUserSelectedFrame()` instead of those globals.
5. `ChatFrame2:Show()` triggers protected code. It is shown once outside combat and then toggled with alpha (`ns.SetCombatLogVisible`). In combat the show waits for `PLAYER_REGEN_ENABLED`.
6. Link clicks: Retail and Forever add a `HookScript("OnHyperlinkClick")` handler and hide a stray tooltip with a `hooksecurefunc("SetItemRef")` post-hook. **Classic exception:** Classic's `SetItemRef` errors with "Unknown link type" on our `gudachat:` links before any hook could run, so on Classic only the chat frame's `OnHyperlinkClick` script is wrapped and our links never reach `SetItemRef`.
7. Menus: use `WowStyle1DropdownTemplate` + `MenuUtil` where the client has them. `UIDropDownMenu` shares global state with Blizzard's unit menus.
8. The timestamp option sets the CVar only and applies after `/reload`; writing `CHAT_TIMESTAMP_FORMAT` from addon code would taint every chat message.

## Whisper tab and routing

With the Whispers tab on, `ApplyWhisperRouting` (UI/Whisper.lua):

- saves the player's `whisperMode` CVar once in `origWhisperMode` and sets it to `inline`, so whispers do not pop out into their own windows;
- removes the `WHISPER` and `BN_WHISPER` groups from General, so whispers show only in the Whispers tab.

Both changes are stored by the game, not in SavedVariables. If `GudaChatDB` were lost, nothing could undo them and General would stop showing whispers. So `UndoWhisperRoutingForLogout` puts both back at every `PLAYER_LOGOUT`, and `ApplyWhisperRouting` sets them again at login. Closing the Whispers window turns the feature off.

## Themes

`Core/Theme.lua` holds three themes as plain data (colours, backdrop style, font file), so GudaBags and GudaDamage can reuse the format:

| Theme | Look |
|-------|------|
| `classic` | GudaChat 1.x, unchanged: flat 1px frames, gold accent, tab text in each tab's chat colour. |
| `modern` | Modern Dark: flat dark panels with rounded corners and a soft shadow (`Assets/Theme/rounded.png`, `rounded-border.png`, `shadow.png`, cut into nine slices), FiraSans labels (game font on zhCN, zhTW and koKR), the accent for state (focus, active tab underline, icons, scrollbar). |
| `blizzard` | The game's own art by path, nothing shipped: tooltip background and edges for bars and menus, the dialog box for popups, gold `NORMAL_FONT_COLOR` text, a blue-white hover highlight, the red panel button left untinted. |

- **Palette.** `ns.Theme.C` has one `{ r, g, b, a }` table per token (`panelBg`, `headerBg`, `iconActive`, `tabLabel`, `scrollThumb`, ...). A theme switch refills these tables in place, so code that keeps a reference always reads the current colour. Never write colour literals in UI code; add a token to all three themes instead (the tests check that every theme defines every token).
- **Themed frames.** `ns.ApplyDarkBackdrop(frame, bgToken, borderToken, noShadow)` styles a BackdropTemplate frame and remembers it; `ns.SetPanelBorder` changes only the border (focus). `ns.Paint(region, token)` colours a FontString, EditBox, texture or backdrop and remembers the last token. Both registries have weak keys.
- **Tabs.** `Theme.PaintTab(text, chatColour, state)` (active, inactive, hover, drag): Classic dims the chat colour, the other themes use the `tab*` tokens. Modern Dark adds an accent underline under the selected tab.
- **Fonts.** UI text uses GudaChat's font objects (`GudaChatFontNormalSmall`, `GudaChatFontHighlightSmall`, `GudaChatFontHighlight`, `GudaChatFontDisableSmall`), copies of the game's. A theme with a `uiFont` swaps their font file; FontStrings follow live. The chat message font option is separate.
- **Accent.** `GudaChatDB.accent` is `"class"` (default) or `{ r, g, b }`. Only Modern Dark uses it; Classic and Blizzard keep their gold.
- **Live switching.** `ns.Theme.Set(name)` and `ns.Theme.SetAccent(value)` refill the palette, restyle every remembered panel and painted region, update the fonts and run the `Theme.OnChange` listeners (the tab strips rebuild, the chat background follows the theme). Nothing runs per frame.
- **Defaults.** Every profile uses `blizzard` until the player picks a theme on the Appearance page. `Theme.Choose` sets `GudaChatDB.themeUserSet`; only a theme picked that way is kept when the default changes.
- **Chat background.** Each theme has a default (`Theme.chatBg`). It is used while `GudaChatDB.bgFromTheme` is set (fresh installs); the first time the player changes the opacity or colour, `ns.TakeOverChatBackground` copies the shown values into `globalBgColor` / `globalBgAlpha` and the player's own values win from then on. `ns.GetChatBackground` returns what is in use.

## Settings window

`UI/Settings.lua` builds the window the first time it opens (`/gc` or the header cog).

- **Frame.** `ns.CreateThemedWindow` (UI/Controls.lua): a themed panel about 660×470 with a title bar (logo, "GudaChat", version from the TOC, close button). It is dragged by the title bar, and its position is saved in `GudaChatDB.settingsPosition` and kept on screen. Escape closes it (`UISpecialFrames`), and so does entering combat. The history viewer uses the same frame (`GudaChatDB.historyPosition`) with `ns.CreateTextTabs` for its channel tabs.
- **Pages.** A sidebar with six pages; the right side is a scroll area (`ns.CreateScrollArea`) showing one page at a time. Each page is a column of cards.
- **Cards.** `ns.AddSettingsCard(page, order, build)` registers a card; `build(page)` returns a card from `ns.CreateCard`. Cards are sorted by `order` and built when the window is first opened, so any file loaded before that can add one. Built-in orders are 10, 20, 30...; the whisper icon card goes on the `tabs` page at order 40. A row with `row.collapsed = true` is hidden by `card:Relayout()`; call `page:Relayout()` after a card changes height.
- **Controls.** `ns.CreateToggle` (a switch in Modern Dark, a square checkbox with a gold check in Classic and Blizzard), `ns.CreateSlider` (track plus a value box; Enter applies, Escape restores, values snap with `ns.ClampSliderValue`), `ns.CreateDropdown` (GudaChat's own pooled menu, no UIDropDownMenu or WowStyle1 dropdown), `ns.CreateSwatch` (the shared colour picker) and `ns.CreateThemedButton` (the red panel button under Blizzard, flat otherwise). They read the current value through a `get` function and store through `set`, using the same `GudaChatDB` keys and apply functions as before.
- **Live restyle.** Controls register with `ns.OnRestyle(fn)`, which runs `fn` once and again after every theme or accent change. Nothing in the window runs per frame, except while the mouse drags a slider.
- **Appearance page.** Theme cards with thumbnails drawn in each theme's own colours (`ns.Theme.ColorOf`), the accent (class colour, class swatches, custom colour; Classic and Blizzard show a note instead), a live preview of the chat built from the themed widgets, the chat font and size, and the background (override, opacity, colour).

## Whisper icon

On by default (`GudaChatDB.whisperIcon.enabled`; `userSet` records that the player changed it, until then it is switched on at load). Received whispers still show in chat as usual; the icon only adds a quick way to answer.

- **Data.** `Core/WhisperModel.lua` keeps this session's received whispers (`CHAT_MSG_WHISPER`, `CHAT_MSG_BN_WHISPER`; never the player's own) for up to 10 people, newest first, with the last 5 lines each, including the player's replies from the `*_INFORM` events. Characters are keyed `pc:` + `ns.CompactName` (so the Forever name shapes meet), Battle.net friends `bn:` + account id (arg13) and shown by BattleTag (`ns.BattleTagFor`). A secret sender is ignored; a secret message counts but keeps no text.
- **Icon.** Themed button (default above the right side of the chat window, drag to move). The badge counts PEOPLE with unread whispers; the icon hides at 0 unless "Always show icon" is on, and in combat when "Hide in combat" is on (it comes back on `PLAYER_REGEN_ENABLED`). A new whisper pulses it for 3 s (one animation, made once).
- **Hover list and reply.** Hovering shows the list; a click on a row, or on the icon (the newest unread person, else the newest), opens the reply panel with that conversation. Enter sends (`SendChatMessage(..., "WHISPER", nil, target)` with the name as received; `BNSendWhisper` for friends) and closes, Shift+Enter keeps it open, Escape or × closes. Opening a person or whispering them from anywhere marks them read. The reply box only takes the keyboard when the player opens it.
- **Whisper ring.** `Bindings.xml` binds `GudaChat_WhisperRingKey(keystate)` with `runOnUp`. Holding the key (longer than `ns.WHISPER_TAP_TIME` or moving the cursor) opens a ring of up to 8 people at the cursor, unread first; the slot under the cursor (`ns.RingSlotAt`) is highlighted and named in the centre, and releasing over it opens the reply panel at the cursor. Releasing in the centre cancels. A quick tap replies to the latest person. The only `OnUpdate` runs while the key is held. Plain frames only, so it is safe in combat.

## Idle chat text

Off by default (`GudaChatDB.hideIdleText`, Chat page). When on, the message text of every chat frame fades out with the header when the mouse leaves the chat UI, and fades back in on hover, while typing in the chat input, while the emoji picker or the settings window is open, and for `ns.IDLE_TEXT_SHOW_SECONDS` (10 s) after a new message in a visible chat frame. The decision is the pure `ns.ShouldShowChatText` (tested); the header hover monitor calls `ns.UpdateIdleText` on each check, and a fade starts only when the result changes.

- **What fades:** the frame's `FontStringContainer` where the client has one (it holds only the message lines), so the background, the scrollbar and ChatFrame2's frame alpha (the combat log toggle) are untouched. Without it the chat frame itself fades, and ChatFrame2 is skipped.
- **Taint:** only widget methods (`SetAlpha`, animation groups made once per frame in a local weak table) and `hooksecurefunc(cf, "AddMessage")`. No Blizzard field or method is written.
- Independent of "Disable message fading" (Blizzard's per-message fading).

## Performance patterns

Chat code runs for every message, often once per chat frame, so keep it cheap.

- **Memoized filters:** `ns.NewLineMemo()` keeps a filter's last result per message line ID. A message shown in three chat frames is processed once.
- **No string building in loops:** collect parts in a table and use `table.concat` (`ns.JoinParts`).
- **Pools:** menus, tab buttons and dropdown items are created once and reused. Never `SetParent(nil)` and recreate on refresh.
- **One refresh per change:** tab bar updates go through `ns.RequestTabRefresh()`, which runs once on the next frame however many hooks ask for it.
- **One fade per frame:** `ns.CreateFade(frame, alpha, duration)` makes the animation once; call `:PlayFromCurrent()`.
- **No per-frame work:** hover checks run every 0.05 s and are children of their frame, so they stop when it hides. Timers stop while their window is hidden.
- **Caches:** player levels are cached (also "not found") for 60 s; the guild level map is rebuilt only on `GUILD_ROSTER_UPDATE`.
- **Ring buffers:** `ns.PushLog` overwrites the oldest entry instead of shifting the array.
- **History search** waits 0.2 s after the last key press; Copy builds the text once.

## Languages

- Never hard-code text players see. Add a key to `Locales.lua` for **all 11 languages** in the same change: enUS, deDE, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW.
- Keep the same format codes (`%s`, `%d`, `|cff...|r`) in every language. The tests check this.
- Use Blizzard's own translated globals where one fits exactly, through `ns.Blizz(GLOBAL, "English fallback")`.
- Do not translate player names, channel names, emoji codes or slash commands.
- English is simple; translations say the same thing in the same simple way.

## Code style

- No comments inside function bodies and none at the end of a line. Explain the why in a comment block above the function or constant.
- Commit messages are a title only, for example `fix: whisper tab blink`.

## Tests

Offline tests run with Lua 5.1 (the version WoW uses) in WSL, from the addon folder:

```
lua5.1 tests/run.lua
```

- `tests/harness.lua` stubs the WoW API and loads the real addon files (locales, Constants, Emojis, Filters, Logs) into a fresh namespace. `H.Load({ interface = 16001, locale = "ruRU", name = "Joob", family = "Stabber" })` loads them as a given client.
- Suites: locale parity and used keys, name comparison and client flags, chat filters (links, highlight, secret messages, memo), emojis, loot parsing and ring buffers, themes, slider helpers, and the whisper model (unread people, order, limits, latest, read on reply, Battle.net and Forever keys, secret values, ring geometry and tap).
- The exit code is 1 when a test fails.
- UI behaviour needs the real client: see `tests/IN_GAME_CHECKLIST.md`.

## Copying to the game clients

The repository lives in the Anniversary client's AddOns folder. `git sync` (a git alias for `.git/sync.sh`) copies the addon to `_classic_`, `_classic_era_`, `_retail_`, `_forever_` and `_classic_beta_`. It deletes the old copy first and skips `.git` and `tmp`.
