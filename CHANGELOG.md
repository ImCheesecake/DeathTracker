# Changelog

## 1.7.0 (2026-11-25)

A warning when a player who killed you is near, and friends with more than one WoW account.

### New

- **Grudge warning:** when a player who killed you, another of your characters or a friend in the last 7 days comes into view, a raid warning and a horn tell you. Turn it off with **Warn me when a player who killed me or a friend is near**.
- **Friends:** share with a Battle.net friend once and every WoW account under their BattleTag shares too, as one row. On an account with both Horde and Alliance characters, each name shows its faction crest.

### Changed

- **Monthly recap:** repair bills in gold, silver and copper coins.

### Fixed

- **History window:** a long nemesis name wraps instead of running out, and the scrollbar no longer sits on the divider.

## 1.6.1 (2026-11-22)

Fixes for the death count and for chat spam.

### Fixed

- **Counter:** no longer shows 0 deaths when the game leaves out your realm name. Deaths saved meanwhile move back to the right character.
- **Chat:** no more "No player named ... is currently playing." over and over when a guildmate or party member logs off.
- **Monthly recap and wanted poster:** the mob's model shows whole, and long names fit.

## 1.6.0 (2026-11-18)

Your month in deaths, as a short recap.

### New

- **Monthly recap:** when a month ends, a few short slides on how you died across all your characters: the count, your worst day, who died most, your nemesis and your repair bills, each with a roast. It pops up when you log in, and **Play November recap** on Records plays it again. It has music; turn it off with **Play music with the monthly recap** in the settings.
- **Road to 60:** reach level 60 and get the same kind of recap for that character: every death on the way, your first, your nemesis, your death type and more. **Play road to 60** on Records plays it again. Characters already at 60 get theirs at their next login.
- **Settings:** **Show a recap** shows this month's so far.

### Changed

- **History window:** more space between the groups in the list on the left.

### Fixed

- **History window:** on the Friends page, clicking one of your own characters now shows your deaths.

## 1.5.1 (2026-11-17)

A fix for paying respects.

### Fixed

- **Friend popups:** **Pay respects** now reaches a friend who looked offline to the addon. The button says **Respects paid** once it's sent.

## 1.5.0 (2026-11-16)

Every death your friends share, and a joke for every death.

### New

- **History window:** pick a friend to see all their deaths on every page, the same as yours. Both of you need 1.5.0.
- **History window:** click an event or record on the Friends page to open it, and hover Recent for its details.
- **Jokes:** jokes for 61 kinds of mob, under your deaths and your friends'.

### Changed

- **Counter bar:** a long killer name takes a second line instead of shrinking.
- **Friends page:** Recent follows the time you pick.

### Fixed

- Fixes for friends showing offline, avenging, the nemesis and the counter bar.

## 1.4.1 (2026-11-15)

Details for your friends' deaths, and a round of fixes.

### New

- **History window:** click a friend's death to see its details.

### Changed

- **History window:** a day now runs midnight to midnight.
- **Trophies:** every step fits its box, and a few long step names are shorter.

### Fixed

- Fixes for the history window, the nemesis, the wanted poster and friends.

## 1.4.0 (2026-11-14)

See how each death happened: click it in the history window.

### New

- **History window:** click a death to see its details on the right: the killer, how fast you died, the damage, and the last hits with their icons and your health after each. Deaths from before this update show only the killing blow.
- **History window:** click a killer to see how it kills you, or a zone to see what kills you there.
- **Records and Trophies:** a click opens that death's details.

### Changed

- **History window:** a click on a row no longer filters the list. The button in its details does, such as **Show deaths to Rocklance**.
- **History window:** the red X on **Filter** also clears a picked killer, zone or record. The **Show every killer** link is gone.

## 1.3.1 (2026-11-12)

Friend popups you can't miss, and every killer in its color.

### New

- **Friends:** **Pay respects** is a button now. After a click it says **Respects paid**.
- **Friends:** when a friend pays respects, you see which death it was for, with a candle and their class color.
- **Friends:** a friend's death shows a skull and the spell that killed them.
- **Settings:** **Play a sound when a friend dies**.

### Changed

- **Death card:** the killer's name is in its color, as on the counter. Fire is red now, lava orange.
- **Friends:** popups show lower on the screen, clear of the button to release your spirit.
- **History window:** the line at the top says whose character you're looking at.

### Fixed

- **Friends:** long names no longer spill out of popups and cards.
- **Friends:** mobs that killed a friend in a dungeon no longer show as "?" (once your friend updates too).
- **History window:** a long character name no longer runs into its death count.
- **/deathtracker friends** no longer shows an error.

## 1.3.0 (2026-11-12)

Trophies for how you die, a longer Records page, and your friends' deaths on every page.

### New

- **Trophies:** a new tab in the history window, or type **/trophies**. 83 trophies for how you die, who kills you and how long you last, each with points. Your past deaths count too, and each new one pops up like an achievement.
- **Records page:** your shortest life, most deaths in an hour, longest without dying, deaths per level, and where you died (open world, dungeons, raids, battlegrounds).
- **History window:** your friends sit under your characters on the left. Click one to see their deaths, killers, zones and records, or **Compare with you** on Records. Friends share more once they update too.
- **History window:** pick **Today**, **This week**, **This month** or **All time** once, and every page keeps it. **This stream** too, with Streamer.bot on.
- **Friends:** **Recent** is a tab of its own and shows the deaths you missed while you were offline (once your friend updates too), and how they died.
- **Settings:** **Show a trophy** lets you move trophy popups: drag it where you want them, then click it to close it.

### Changed

- **Corner counter:** **Alive for** is renamed **Played this life**, the time you've played since your last death.
- **Friends:** a friend in a battleground stays online in the list, and their tooltip says where they are.
- **Friends:** no more popup asking to share with your guild. A chat line and **Open settings** on the Friends page lead to **Share death counts with my guild**.

### Fixed

- **Friends:** a friend killed by another player shows the killer in the player color, not the mob color.
- **Friends:** **Share with a friend** no longer shows an error for some players.

## 1.2.0 (2026-11-12)

See your friends' deaths and who dies most.

### New

- **Friends:** a new tab in the history window. Click **Share with a friend**, or right-click a name in Blizzard's friends list. Once they say yes, you rank against each other in **Most deaths**, **Longest life** and **Records**, and a click on a friend compares the two of you.
- **Friends:** your guild can share too. The first time a guildmate with Death Tracker is online, you're asked once. Change it later with **Share death counts with my guild** in the settings. Guild deaths show in the Friends tab but never pop up.
- **Friends:** a popup when a friend dies. Choose **Off**, **Small** or **Card** under **When a friend dies** in the settings.
- **Wanted poster:** your nemesis can get away, and the poster says ESCAPED.

### Changed

- **Nemesis:** only your last 10 deaths in the open world choose it. Dungeons, raids, battlegrounds and arenas never do.
- **Nemesis:** one kill collects the bounty on a rare, elite or boss, up to 3 on a normal mob, by you or your party. Collecting it ends the nemesis.
- **History window:** the run back shows the time you spent running, not yards.
- **Records page:** one line per record, details in the tooltip.

### Fixed

- **Settings:** long names wrap instead of ending in "...".
- **Corner counter:** shows your all-time nemesis with Streamer.bot on, like the wanted poster.

## 1.1.2 (2026-11-09)

The settings now tell streamers when to import the Streamer.bot code again.

### New

- **Settings:** a **NEW** label by **Show import code** when an update changed the code, so you know to import it again.

### Changed

- **Settings:** **Count each character separately** is now **Count per character**, so the name fits.

### Fixed

- **Streamer.bot:** right after you import the code, `!deaths` names your character, without a `/reload` first. Import the code from **Show import code** again to get it.

## 1.1.1 (2026-11-09)

Streamers with alts can show All time for the character they're playing.

### New

- **Settings:** **Count each character separately**, under **Show all-time deaths**. The counter's All time counts only the character you're logged in on, so each alt has its own. Every death is still saved and shows in the history window.
- **Streamer.bot:** with it on, `!deaths` names the character: "All time on Back Stabnbe: 312." Import the code from **Show import code** again to get the name.

## 1.1.0 (2026-11-09)

Your nemesis gets a wanted poster, and the death card's joke now fits what killed you.

### New

- **Wanted poster:** a mob that kills you three times becomes your nemesis and gets a wanted poster. Kill it, alone or with your group, to collect the bounty. Right-click the poster to **Keep on screen**.
- **Death card:** jokes that fit what killed you: spiders, murlocs, raptors and more, elites and rares, a big level gap, the spell, a crit and a player's class.
- **Death card:** Blizzard's elite and rare mark before the killer's name, also in the Deaths list's tooltip.
- **Minimap button:** drag it anywhere around the minimap. Hide it with **Show the minimap button**.
- **Settings:** **Show a death** and **Show a bounty** show the card and the poster, so you can move and resize them.
- **Corner counter:** right-click it for **Show wanted poster**.

### Changed

- **Settings:** the page scrolls when it doesn't fit.
- **Addon list by the minimap:** right-click Death Tracker to open the settings. Its tooltip says what each click does.
- **Counter bar:** the labels sit over their values, and your nemesis looks like your last death.

## 1.0.0 (2026-11-08)

The history window: every death, who killed you, where and your records. Type **/deaths** to open it.

### New

- **History window:** type **/deaths** or click **Death Tracker** in the addon list by the minimap. Every death on every character, grouped by day, with its repair bill.
- **History window:** your characters sorted by **PvP realm** and **PvE realm**. Click one to see only its deaths. **Filter** by realm, cause and level.
- **Killers:** the mobs and players that killed you most. Click one to see every death to it.
- **Zones:** where you die most, by zone and by spot.
- **Records:** your longest life, hardest killing blow, worst day, most expensive death, longest run back and more.
- **Tooltips:** a mob or player that killed you says so in its tooltip, and if it's your nemesis. Turn it off with **Show deaths in tooltips**.

### Changed

- **Nemesis:** always one character's. Kills on your other characters no longer count.
- **Death card:** no more **Highest level yet** line. Every death after a level-up earned it.

## 0.7.1 (2026-11-06)

Streamers can hold death messages in chat until viewers see the death. Import the code from **Show import code** again to use it.

### New

- **Settings:** **Wait before posting in chat** holds each death message in chat for 0 to 30 seconds, so chat doesn't spoil a death before viewers see it. Import the code from **Show import code** again to use it.

### Changed

- **Corner counter:** with Streamer.bot on, the bar shows your all-time deaths as their own section, **ALL TIME** over the number, next to this stream's count.

## 0.7.0 (2026-11-06)

The bar is redrawn to fit smaller screens and phone crops, and a right-click on the counter switches its layout.

### New

- **Corner counter:** right-click the counter to switch between **Bar** and **Box**, or to open the settings.
- **Settings:** **Show all-time deaths**: with Streamer.bot on, the bar shows your deaths on every character under this stream's count. On at first.

### Changed

- **Corner counter:** the bar is narrower. The last death and time alive have small labels above them, and your nemesis hangs in a tab under the bar.
- **Corner counter:** shorter times, like "1h 14m" alive and "3d 2h ago" for the last death.
- **Corner counter:** long mob names are never cut with "...". In the box they take a third line.
- **Settings:** **Show the counter as a bar** is now the **Counter layout** dropdown. If you used the bar, you keep it.
- **Settings:** with the counter's background off, the bar keeps its border.

### Fixed

- **Corner counter:** a long nemesis name no longer runs out of the box.
- **Settings:** **Show it in BGs and arenas** is no longer cut off.

## 0.6.0 (2026-11-05)

The counter can now be one bar across the top of the screen, and Death Tracker no longer gets blamed for a blocked action in the options.

### New

- **Settings:** **Show the counter as a bar** puts the counter in one line at the top of the screen: your deaths, the last one, how long you've stayed alive and your nemesis with its kills. Drag and resize it like the box.

### Fixed

- **Settings:** after opening Death Tracker's settings, the Audio page's Discord checkbox no longer brings up "Death Tracker has been blocked from an action".

## 0.5.2 (2026-11-02)

The Streamer.bot setup works on more PCs, even before you've played. Import the code from **Show import code** again to get it.

### New

- **Streamer.bot:** if it can't find WoW, a window opens to choose your General.log. To choose another one later, right-click the trigger of **Death Tracker: set General.log** and click **Test Trigger**.
- **Streamer.bot:** when Streamer.bot stops hearing your Twitch chat, it says so in chat and asks you to restart it. It says so again when chat is back.

### Fixed

- **Streamer.bot:** !deaths and !nemesis answer right after the import: "Deaths this stream: 0. All time: 0." Before your first death they showed "~deathsThisStream~".

## 0.5.1 (2026-10-28)

Death Tracker is now for every player. Counting by stream only comes with Streamer.bot.

### Changed

- **Corner counter:** shows this character's deaths, all time. With **Send each death to Streamer.bot** on, it counts this stream's deaths on every character, as before.
- **Death card:** "DEATH #12" now matches the counter: your 12th death on this character.
- **New stream:** "Start counting a new stream?" only comes when **Send each death to Streamer.bot** is on. Turning that setting on starts a new stream at 0.
- **Settings:** **Reset stream count** is greyed out while **Send each death to Streamer.bot** is off.
- **Jokes:** "That's 3 for Hogger" counts Hogger's kills on this character, not on your other characters.

### Fixed

- **Settings:** **Delete last death** shows the same death number as the card. It showed your all-time count.

## 0.5.0 (2026-10-26)

First release, for WoW: Forever.

- **Death card:** what killed you, how, where and at what level, with a joke for every cause. A new nemesis, your longest life, your highest level and every 50th death get a line of their own.
- **Corner counter:** deaths this stream and what caused them, your last two deaths, how long you've stayed alive and your nemesis. Drag it and the card anywhere and resize them.
- **New stream:** when you start the game with deaths on the counter, Death Tracker asks whether to start a new stream.
- **Settings:** turn the counter, its background and the card on or off, show the card in battlegrounds and arenas, **Reset stream count**, **Delete last death** and **Delete all deaths**.
- **Streamer.bot:** posts each death in your Twitch chat, and viewers can type !deaths and !nemesis. **Show import code** sets it up.
