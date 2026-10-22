# In-game checklist for 1.4.0

Run `git sync`, then check each client. Keep BugSack/BugGrabber on and look for errors after each step. Use `/console taintLog 1` on Retail and Forever if anything says "Interface action failed".

## Every client (Forever, Anniversary or Era, Retail)

### Tabs and windows
- [ ] Switch tabs with the tab bar, the header dropdown, the overflow menu and by sending a message: the header label and icons always show the current tab.
- [ ] Right-click menu: right items per window type, Leave Channel, font size submenu (reads "12 pt" etc.), background colour picker.
- [ ] Colour picker: the opacity slider goes the right way, and Cancel restores the old colour (modern picker on Retail and MoP, old picker on Era).
- [ ] "New window" from the context menu selects the new window, also when a middle slot (for example 6 of 1-7) is free.
- [ ] Switch tabs 50+ times, open and close menus: no duplicated buttons, nothing stale.
- [ ] Tab blink: a message in a hidden tab blinks it; selecting it stops the blink; turning a notification off stops that blink.
- [ ] Drag a tab to reorder: the order is kept after `/reload`.

### Whispers
- [ ] Whisper tab on: whispers show only there, not in General. No pop-out windows.
- [ ] Close the Whispers window, then send a whisper: the chat does not go blank, and whispers show in General again.
- [ ] Temporary whisper windows (ChatFrame11+): one emoji button only, scrollbar present, URL links clickable.
- [ ] Battle.net whisper: saved in history with the BattleTag, still readable after a relog.

### Links, emojis, names
- [ ] Click a URL in General and in a whisper window: the copy popup opens. No "Unknown link type" error.
- [ ] Click item, spell and player links: Blizzard's normal tooltip or menu.
- [ ] Emojis: ":)" and ">:(" become images; "(Plan B)", "maxDPS" stay text.
- [ ] Your name in someone's message is coloured, the mention sound plays once.
- [ ] Player levels show when the option is on, and in the login replay only when it is on.

### Combat log
- [ ] Open the combat log, pick "My Actions" or "What happened to me", switch to another tab and back: the choice is kept and the sub-tab colour matches.
- [ ] `/reload` and a dock update (a whisper popping a window) during combat: no "action forbidden" error, the combat log still toggles after combat.

### Look and feel
- [ ] Header, tab bar and scrollbar fade in and out smoothly on hover.
- [ ] Scroll up with the mouse wheel: the scroll-to-bottom button appears; it hides at the bottom.

### History and logs
- [ ] History search reacts after a short pause, not on every key.
- [ ] Copy on a large history (2000+ lines) opens without a freeze.
- [ ] History keeps up to the "Max messages" setting (test 4000) and the font size setting after `/reload`.
- [ ] Loot log: own and others' loot is logged, Need/Greed/won roll lines are not. Test on a non-English client too.
- [ ] Loot and Log tabs stay in order after their limit (500 / 300) is reached.

### Settings
- [ ] History & Logs page: the max loot entries and max addon messages sliders fit in their card.
- [ ] Timestamps: the "Applies after /reload" note sits under the label without overlap (check German, French, Russian).
- [ ] History channel tabs fit in one row in every language (de, ru, es especially).
- [ ] Fading and font changes reach every chat window, including whisper windows.

### Settings window (2.0)
- [ ] `/gc` and the header cog open the new window; Escape and the close button close it; entering combat closes it.
- [ ] Drag it by the title bar, `/reload`: it opens where it was left and stays on screen.
- [ ] All six sidebar pages open; long pages scroll with the mouse wheel and the thin scroll indicator moves.
- [ ] Every option still works and is remembered after `/reload`: lock, fading, scrollbar, timestamps, input bar top and transparent, class colours, level, links, highlight and sound, emojis and size, tab bar, inline tabs, whisper tab, all blink options, history on/off, loot and addon logging, the four limits, Clear history.
- [ ] Switches in Modern Dark; square checkboxes with a gold check in Classic and Blizzard. Switching the theme changes them at once.
- [ ] Sliders: drag, click on the track, mouse wheel over the row, and typing a value then Enter (out-of-range values are clamped, text is ignored, Escape restores).
- [ ] Dropdowns (chat font, timestamps) open below the button, show the current value highlighted, close on a pick, on a click outside and on Escape.
- [ ] Appearance: picking a theme card switches the theme live; the thumbnails keep their own colours.
- [ ] Accent: "Use my class colour", the class swatches and the custom colour all change the accent live in Modern Dark; Classic and Blizzard show the gold note instead.
- [ ] Live preview follows theme, accent, chat font, font size, class colours and background opacity and colour.
- [ ] Background: turning "Override per-tab backgrounds" off hides the opacity and colour rows and restores each window's own background.
- [ ] Blizzard theme: the window uses the dialog box art, Clear history and Copy are red Blizzard buttons.
- [ ] Long labels in German and Russian end with "..." instead of running under the controls.
- [ ] About page shows the version from the TOC.
- [ ] History viewer: themed window, channel tabs switch the filter, its position is remembered, Copy still opens the copy window.
- [ ] Whisper tab turned off by closing the Whispers window: the switch in Settings turns off too.

### Whisper icon (2.0)
- [ ] Off by default: no icon until "Show whisper icon" is turned on (Settings > Tabs & Alerts).
- [ ] A received whisper shows the icon with badge 1 and a short pulse; a second whisper from the same person keeps 1; a whisper from someone else makes it 2. Your own whispers never count.
- [ ] Hover: the list shows each person (class colour; BattleTag for Battle.net friends), time, last message on one line and an unread dot; it hides shortly after the mouse leaves icon and list.
- [ ] Click the icon: reply panel for the newest unread person, cursor in the box. Click a row: reply panel for that person.
- [ ] Enter sends and closes; Shift+Enter sends and stays open; Escape and × close. The reply shows in the panel and in chat.
- [ ] Send a whisper to a cross-realm player (Name-Realm) and to a Battle.net friend from the panel; both arrive.
- [ ] Whispering someone from normal chat (/w, R) marks them read and lowers the badge.
- [ ] "Always show icon" keeps it at 0; "Hide in combat" hides it in combat and shows unread ones after.
- [ ] Drag the icon, /reload: same place. "Reset position" puts it back above the chat window.
- [ ] Key Bindings > GudaChat > Whisper ring: bind a key. The settings row shows the key.
- [ ] Tap the key: reply panel at the cursor for the latest person. Hold: ring of up to 8 people at the cursor (unread first, class icons, Battle.net icon for friends); the pointed one is highlighted and named in the centre; release on it opens the reply at the cursor; release in the centre cancels. Works in combat without errors.
- [ ] Switching the theme restyles icon, badge, list, panel and ring live.
- [ ] No typing or casting is interrupted when a whisper arrives (the panel never takes focus by itself).

## WoW: Forever only

- [ ] Whisper icon with two-part names ("Given Family"): the person appears once, the reply reaches them, and whispering them from chat marks them read.
- [ ] The addon loads (not "out of date") and the right edge of header, input bar and scrollbar lines up with the text (13 px gutter).
- [ ] Messages with secret values (system messages, some whispers): no Lua errors from GudaChat filters.
- [ ] Two-part names ("Given Family"): own messages do not blink tabs; whisper windows match their sender; the history whisper link opens a whisper to the full name.
- [ ] Full client restart: chat history, loot log and addon log are still there (restored from `charCopies` if the character file was not loaded).
- [ ] With the Whispers tab on, delete or rename `GudaChat.lua` in SavedVariables, start the game: General still shows whispers (routing was undone at logout).

## Anniversary / Era only

- [ ] URL links in General and whisper windows open the copy popup, and normal item and player links still work (Classic link-click exception).
- [ ] Settings dropdowns (font, timestamps) open and set their values.

## Retail only

- [ ] No secret-value errors in chat during combat, in dungeons or with monster speech.
- [ ] Settings dropdowns use the modern style.
