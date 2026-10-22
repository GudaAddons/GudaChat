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
- [ ] History tab: the two new sliders (max loot entries, max addon messages) fit in the panel.
- [ ] Timestamps: the "Applies after /reload" note sits under the label without overlap (check German, French, Russian).
- [ ] History channel tabs fit in one row in every language (de, ru, es especially).
- [ ] Fading and font changes reach every chat window, including whisper windows.

## WoW: Forever only

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
