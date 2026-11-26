# Changelog

## 4.5.1
- **Pick your own banner colours.** Settings > Sounds now has a colour for each kind of alert: click it to choose a colour with the game's colour picker, or right-click it to go back to Warcrest's. "Use Warcrest's colours again" puts them all back. Your colours win over the colour-blind friendly ones.
- "Rival guild spotted" is now translated in Settings > Sounds.

## 4.5.0
### New: guild rep
Standing with the guild, earned **only by playing together**. Nobody can give it out or take it away, and it never goes down.
- **How it's earned:** 10 for every 10 minutes grouped with a guildmate (counted only when both of you have Warcrest and both report the same group), 100 for a raid night, 25 for a guild boss kill, 50 for a guild event, 5 for helping a guildmate with a kill, 15 for a revenge kill, and 25 for a crafting order you finish for a guildmate. Up to **1,000 a day**.
- **Ranks:** Neutral, Friendly at 3,000, Honored at 9,000, Revered at 21,000 and Exalted at 42,000.
- **Where it shows:** your rep, today's progress and a bar to the next rank on **Home**; a sortable **Rep** column on the **Roster**; and every **player card**. Reaching a new rank shows a banner with its own colour and sound (Settings > Sounds), and is posted in guild chat when you have achievements posted there.
- Everything except grouped time is counted from what the guild already shares (raid nights, boss kills, events, kills, crafting orders), so everyone's addon shows the same numbers, including rep earned before this update. Grouped time is new: Warcrest notes it every 30 minutes and when the group ends. Nothing goes in chat.

### Titles
- The secret achievement **The Blades** now gives the title **the Blades**. Like the achievement, it stays hidden from everyone else's title list.

## 4.4.0
### Guilds on warcrest-addon.com
- **New: WoW: Forever guild boards** at [warcrest-addon.com/guilds](https://warcrest-addon.com/guilds/), from Blizzard's armory and updated every hour: race to 60, raid progress, gear, most active, quests, monsters slain, PvP and the biggest guilds, with a page for every guild and player, search, and the latest firsts (members reaching 60, each guild's first boss kills).
- **Put us on the website** (officers, in **Guild > Who has Warcrest**): a link to copy into your browser that adds the guild to the boards with the Warcrest badge. Warcrest itself never goes online.

### Fixes
- The secret achievement now goes by the character's full name as WoW: Forever writes it, first name and surname (it was looking at the realm, which WoW: Forever doesn't have).

## 4.3.1
### Memory and speed
In a big guild Warcrest's memory could climb past 100 MB. This release brings it well down:
- **Achievements are worked out far less often and far more cheaply.** Every synced entry used to make Warcrest go over every member's 315 achievements again, about once a second while the guild's history synced. Now it waits for things to settle (in a 500-member guild, at most every 25 seconds), works out each kind of count once per member instead of once per tier, reuses what it made last time, and only keeps achievements that are earned or under way. In a test guild of 500 members with months of history, the garbage this made fell from about 113 MB a minute to about 5 MB, and the memory kept from about 45 MB to about 22 MB.
- **Pages make much less garbage when they redraw:** Home about 7 times less, Achievements > Guild about 12 times less, and most other pages about 7 times less. The guild's achievement list, the "who has Warcrest" count, alts and the kill log's fingerprints are no longer rebuilt on every redraw.

### Polish
- Achievement progress shows thousands separators (1 / 1,000), in the player's language.
- Guild > Who has Warcrest shows "Has it" instead of "v?" for a guildmate whose version isn't known yet.
- When the game blocks something Warcrest tried ("Interface action failed"), it's now kept for `/warcrest report` with where it came from, so it can be tracked down.

## 4.3.0
### A fresh start
- **Everything shared is reset.** The first time each member loads 4.3.0, Warcrest clears what it shares with the guild: kills, deaths, streaks, Wanted, guild wars, bounties, raids, sign-ups, DKP and loot, events and polls, profiles, titles, achievements, crafters and orders, and the Officer log. Anything from before the reset that arrives from members still on an older version is refused, so it can't come back.
- **Kept:** your own settings (alerts, sounds, accessibility, the window, the minimap button) and the guild's settings set by officers.

### New: guild helpers
- **World buffs and world bosses** (**Events > World buffs**). When a guildmate with Warcrest gets Rallying Cry of the Dragonslayer (the Onyxia or Nefarian head), Warchief's Blessing (Rend's head) or Spirit of Zandalar (the Heart of Hakkar) just as it drops, the guild hears where and when, and the view shows each buff's last drop and how long it lasts. Sightings of Azuregos, Lord Kazzak and the Emerald Dragons are shared the same way, with whether they were up or dead. It goes by the buff itself, so it works in every language. **Alert me** turns the banners off just for you, and the alert has its own sound in Settings > Sounds. Guildmates who log in later catch up on the day's drops and sightings.
- **Groups** (**Guild > Groups**): post what you're doing and how many you need, with the roles. Guildmates click **Ask to join** (as Tank, Healer or Damage), you see who asked and click **Invite**. Nothing goes in chat, and nothing is sent without a click. Posts end after an hour, when you close them, or when you log off.
- **Profession cooldowns** (**Guild > Crafters > Cooldowns**): who has a transmute, Mooncloth, Cured Rugged Hide or a Salt Shaker, and when each is ready. Each member's addon reads their own from the game and shares it when it changes.
- **Raid check** (the button at the top of **Raids**): each raid member's flask, elixirs, food and world buffs, the least prepared first. It reads the buffs straight from the game, so members without Warcrest show too. The game hides buffs during combat, so it works outside it.
- **Inactive, with alts** (**Officers > Officer log > Inactive**): linked alts are grouped with their main, so a player only shows as away when none of their characters has been online, and their last raid counts every character. Alts show as +1, +2 next to the name, and in the tooltip.

### Fixes
- **Battleground and arena kills no longer count anywhere.** Kills in battlegrounds and arenas are no longer reported or accepted from guildmates, and kills already in the log from one are cleared out when you log in. They don't count toward kills, streaks, achievements, guild wars or the Wanted list. The battleground filter in PvP > Kills is gone, and so are the three battleground achievements.
- **Profiles are shared again.** A profile or title changed while a guildmate was offline now reaches them when they log in, even if no officer is online: each member sends their own latest profile and title to whoever logs in. Officers also fill in gaps when they have the same number of entries but different ones.
- **Memory and lag.** In busy places Warcrest's memory could climb to 80 MB and make the game stutter. It now:
  - redraws its window at most a few times a second, instead of once for every roster update and every synced entry (that alone made about 70 KB of garbage each time);
  - reuses one list of the units around you instead of making new ones several times a second;
  - updates an enemy's guild in place, at most once a minute, instead of making a new entry every second they're in sight, and keeps that list capped while you play;
  - forgets enemies you attacked once they're out of reach, and skips scanning when you're not fighting anyone;
  - doesn't do anything in the send queue when nothing is waiting.

### Achievements and titles
- **157 new achievements**, mostly higher tiers for kills, assists, revenge, raids, bosses, loot, events and more, with new titles at the top: the Deathbringer, the Unbreakable, the Midnight Blade, the Scourge, the Rivalbane, the Retributor, the Undying, the Unwavering, the Titan, the Gilded, the Heart of the Guild and the Exalted.
- **A bit harder:** tiered achievements now need roughly half as much again (for example 1,500 killing blows for Thousand Cuts, 150 raid nights for Centurion's tier). Achievements you've already earned stay earned, titles included.
- **No more look-alike titles, and clearer names:** the Legendary is now the Deathless, the Godlike the Untouchable, and the Legend the Feared. Titles that matched the game's PvP ranks (the Warlord, the Commander, the Centurion, the Champion) and other near-duplicates have new names too: the Bloodsworn, the Shotcaller, the Veteran, the Crowned, the Sworn Blade, the Roamer, the Dreaded, the Kingslayer, the Wrathful, the Guardian, the Tracker, the Nemesis Bane, the Ever-Present, the Unfailing, the Usurper, the Unyielding, the Worldbreaker, the Blessed and the Grandmaster. If you showed one of these, you now show its new name.
- **A secret achievement**, hidden until it's earned. Its owner knows who they are.
- Achievement names that clashed are renamed: Warlord is Bloodsworn, Legend is Feared, and Headhunter (recruits) is Talent Scout.

### Accessibility
New in **Settings > Accessibility**:
- **Text size up to 130%.**
- **Font:** Warcrest's own, the game's font, or a plain one some find easier to read.
- **Thicker letters** (an outline around every letter) and **more space between lines**.
- **Banner size:** alert banners at 100%, 125% or 150%.
- **Read alerts aloud** with the game's text to speech, using the voice, speed and volume from the game's own options.
- **Flash the game's taskbar icon** when an alert comes in while the game is in the background.
- **A key to open Warcrest:** set it in the game's Key Bindings, under AddOns.

### Alert banners
- **Every kind of alert has its own colour.** Before, several shared Warcrest gold (achievements, bosses, bounties and Top head hunters) and some were near twins (kills and deaths, revenge and rival guilds). Now each of the 15 kinds has a colour clearly apart from all the others, and guild kills are green. Colour-blind friendly colours (Settings > Accessibility) keep their safe set, and every banner still names its kind in words.

### Guild roster
- **Sort by any column:** click Name, Lvl, Rank or Where to sort, and again to turn the order around. Where sorts online members by zone, then offline members by how recently they were on.
- **Show** only members with Warcrest, without it, at level 60, or officers.
- **Search** finds classes, zones and public notes as well as names and ranks.
- Your choices are remembered.

## 4.2.0
### Get your guild on Warcrest
Warcrest gets better the more of your guild has it, so this update makes it easy to bring the rest in, without ever spamming anyone.
- **Invite the guild** (officers, in **Guild > Who has Warcrest**, or `/warcrest invite`): a short message about Warcrest that you can edit, then post in guild chat with **Post in guild chat**. Nothing is sent until you click it, and the window shows when it was last posted. Members get the same message to copy and send their officers. Right-click someone without Warcrest in the list for a message to whisper them yourself.
- **Share Warcrest** (on Home, in Help, or `/warcrest share`): a one-line message with where to get it, to paste to a friend, a Discord or another guild.
- **A picture tour** in the welcome window: what Home, Kills, Raids, Loot and Profiles look like once the guild is on it. **Help > See it in action** shows it again.
- **Empty pages explain themselves:** while few guildmates have Warcrest, pages like Kills, Wanted, Standings, Profiles, Crafters, Polls and Guild wars say how many have it and how to invite the rest.
- **One reminder for officers:** when fewer than half of the guild's active members (online in the last 14 days) have Warcrest, Home shows it with an **Invite** button. **Hide** puts it away for good, unless 5 or more active members are still missing it later on.
- **Getting started** has an extra first step when you're the only one in the guild with Warcrest: officers invite the guild, members tell their officers.
- Warcrest never whispers, posts or advertises on its own, and it doesn't track anyone.

## 4.1.0
- **Profiles and Crafters are views in the Guild section** now, next to Roster and Who has Warcrest, instead of windows of their own. They fill the Warcrest window and grow with it. `/warcrest profiles`, `/warcrest craft` and `/warcrest orders` open them there, and Getting started's "Share your recipes" step goes straight to Crafters. Crafters' Recipes and Orders switch, and Profiles' sort and **Edit my profile**, sit at the top right. Editing your own profile is still a small window.
- **Help, tooltips and messages use the new names.** Everything that still said "the DKP tab", "the Kills tab" and so on now names the section and view, for example Loot > Standings, PvP > Kills, Events > Polls or Officers > Recruit, in all four languages.
- **Release notes on GitHub and CurseForge** now show just that version's changes instead of the whole changelog.

## 4.0.1
- **A new logo**, chosen by the guild: the crowned seal. A crown sits on a round seal with "Warcrest · Guild tools · Forever" around the ring and a W made of two swords at its heart. Smaller versions (the minimap button, chat and the add-on list) keep just the crown, the ring and the W so it stays clear. The website, its link preview and the screenshots use it too. The Imperium keeps its own emblem.

## 4.0.0
### A new look
The guild voted for layout F of the UI concepts, and here it is: both of its steps (the new menu and Home, then the joined-up sections) in one release.
- **The side menu is grouped:** Home, then **Guild** (Guild, Events), **Raids & loot** (Raids, Loot), **PvP & glory** (PvP, Achievements) and **Officers**. Officers only see the Officers section. Small notes next to some items show what's going on: how many guildmates are online, open polls you haven't voted in, and a raid tonight (or one in progress).
- **Related tabs are one section each, with their views along the top** next to the section's name:
  - **Guild:** Roster, and Who has Warcrest (the old Addon tab).
  - **Events:** Events, Polls and Calendar.
  - **Loot:** Standings, Loot history and All changes (the old DKP tab), and Wishlist. Guilds without DKP see just the wishlist.
  - **PvP:** Kills, Wanted, Guild wars and Bounties (the old Kills and Wanted tabs).
  - **Officers:** Officer log and Recruit.
  - Raids and Achievements keep their own views.
- **Home**, the new first page: a greeting and who's online; your next Getting started step; the next raid (or tonight's raid night) with the sign-ups by role and your jobs in the raid assignments, or who's coming; your DKP, place and attendance, and the top of your wishlist (your achievements and title, in guilds without DKP); the open poll, which you can vote in right there; PvP this week (the top three and the latest wanted ganker); and guild news (bosses killed and achievements earned this week). Click a card to open its section.
- **Getting started** has a card above Settings and Help showing how far you've got, until it's all done. **Hide this** in the checklist takes it off the menu and Home; `/warcrest start` brings it back.
- **Settings and Help** are at the bottom of the side menu.
- Warcrest reopens on the section and view you left it on. Commands that open a tab (`/warcrest dkp`, `/warcrest kills` and the rest) open its new section.

## 3.12.0
### Accessibility
A new **Accessibility** view in Settings (or `/warcrest access`). Everything is off until you turn it on, and each setting is just for you.
- **Text size:** 100%, 110% or 120%. Makes Warcrest's text bigger in every window and on alert banners without making the windows bigger. For both, combine it with the window Size on the General view.
- **Colour-blind friendly colours:** alert banners, and the colours for good and bad news, use a palette that stays distinct with red-green or blue-yellow colour blindness (based on the Okabe-Ito colours). Good news turns blue and bad news orange instead of green and red, including kills and deaths in chat. Every alert also names its kind in words, so colour is never the only cue.
- **High contrast:** brighter grey text and stronger borders and row lines, for low vision or a bright room.
- **Alert banners:** choose how long they stay (normal, twice as long, or until you dismiss them), and turn off their sliding and fading.
- Colour changes apply everywhere after `/reload`; text size and banner settings change straight away.

## 3.11.0
- **Getting started.** New members get a short checklist instead of the old welcome window: open Warcrest, sign up for a raid, fill in your profile, share your recipes and pick a title. Each step ticks itself off when you've done it. Officers set the guild up from the same window (**Guild setup**). Open it any time with `/warcrest start` or from Help > Getting started.
- **Boss fights and PvP matches no longer lose messages.** WoW: Forever, like the current retail game, blocks addon messages during boss encounters, keystone runs and PvP matches. Warcrest used to treat a blocked message as sent, so DKP awards, recorded pulls, battleground kills and bids made mid-fight could be lost. It now holds them (and any chat posts, like achievements or raid assignments) and sends everything as soon as the fight ends. It tells you once per fight when it's holding messages.
- **Loot auctions and loot council votes wait out a fight.** They can't be started while messages are blocked, and one that's running pauses (the bid window says so) and carries on when the fight ends.
- Messages the game hands over as hidden ("secret") values during a fight are skipped safely, including boss names for the "your job" reminders.

## 3.10.0
A clean-up release.
- **The Imperium and Bannerhold folders are gone.** They only handed saved data over from the addon's old names, and that was done long ago. Warcrest no longer comes with them; if they're still in your `Interface/AddOns` folder you can delete them.
- **Settings is at the bottom of the side menu**, next to Help, so the everyday tabs come first.
- The help window's topics fit again (the last one ran into the website and Discord boxes), and the tips in Settings > General no longer have a gap between them.
- **WoW: Forever only:** Warcrest now calls only the game functions WoW: Forever has (checked against its own list), with no older fallbacks left over.
- Leftovers from removed features are gone: the map of guild fights (the kill positions it saved are cleared from your history) and the hand-over from the old names.
- The tests always run against a stand-in for the WoW: Forever client.

## 3.9.3
Checked every game function Warcrest uses against the WoW: Forever game client's own list (from [Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources/tree/forever)). Several had moved; these are fixed:
- **Recipes weren't shared.** Forever has one profession window for every profession (enchanting too), read through `C_TradeSkillUI`, and none of the old trade skill functions or events. Warcrest now reads it the new way, so opening your profession window shares your recipes again. The old events also stopped part of the crafters code loading at all.
- **Achievements weren't posted in guild chat**, and **Post to raid chat** (raid assignments) and **posting the recruiting message** did nothing: `SendChatMessage` is now `C_ChatInfo.SendChatMessage`.
- **The raid warning alert style** showed nothing: it now uses `RaidWarningUtil.AddMessage`.
- **Whisper buttons** (crafters) and the **guild message of the day** on the Roster tab use the new chat and guild functions.
- An event a game client doesn't have no longer stops the rest of a file loading.
- The tests now also run as the WoW: Forever client: its functions, its events, and its "Name Realm" names.

## 3.9.2
- **Fix: titles didn't show in chat.** WoW: Forever's game client moved the function chat add-ons use to change how messages look (`ChatFrame_AddMessageEventFilter` is now `ChatFrameUtil.AddMessageEventFilter`), so Warcrest never added guildmates' titles in front of their messages. It now uses the new one, and the old one on clients that still have it.

## 3.9.1
- **Fix: shared changes didn't reach everyone.** WoW: Forever gives the names of addon messages' senders as "Name Realm", and Warcrest didn't recognise those as guildmates in private (whispered) messages. Catching up when you log in uses those messages, so anything shared while a guildmate was offline (profiles, recipes, achievements, and the rest of the guild's shared record) never reached them. Officers' guild settings could be ignored for the same reason. Everyone gets caught up within a few minutes of logging in with 3.9.1 (or type `/warcrest sync`).
- The tests now also run with names written the way WoW: Forever writes them.

## 3.9.0
- **Fix:** "No player named 'Name Realm' is currently playing" could fill your chat. The game gives some names with the realm after a space, which can't be whispered; Warcrest now whispers guildmates by the roster's name for them, and doesn't whisper guildmates who are offline.
- **Kill streaks have names:** Killing Spree (3), Rampage (5), Dominating (10), Unstoppable (15), Godlike (20), Legendary (25) and Beyond Godlike (30): "Lyra the Avenger is Godlike! (20 kills in a row)". The streak achievements match: Killing Spree, Rampage, Dominating (title: the Dominator), Unstoppable (the Unstoppable), Godlike, now at 20 kills (the Godlike), and Legendary at 25 (the Legendary). Achievements already earned stay earned.
- **Officers, without setup:** every rank that can read officer chat (in the game's guild control) now counts as an officer in Warcrest: the Recruit and Officers tabs, scheduling raids, and the guild settings. Before, only the Guild Master and the rank below did, unless the Guild Master changed it. The Guild Master can still pick ranks under **Who can change these** in Settings, and can turn the officer chat rule off there (**And every rank with officer chat**).
- **Calendar tab:** the calendar moved from a view on the Raids tab to its own tab on the left, under Events. `/warcrest calendar` opens it.
- **Removed:** the world map's "where the guild fights" circles, and their setting.
- The calendar's raid nights and boss kills are now translated.

## 3.8.3
- Fix: **Edit profile** and `/warcrest profile` did nothing, and the **crafters window** was blank. WoW: Forever's game client no longer has the old item and spell lookups (`GetItemInfo`, `GetSpellInfo`) that Warcrest used for your item level and recipe names; it now uses the newer ones, and the old ones on clients that still have them.

## 3.8.2
- Fix: a solo kill could show the killer as their own assist ("Lyra killed Grim (assist: Lyra Realm)"), when the game wrote your realm after your name with a space. Kills already in the log are tidied up when you log in, and the same fix stops any of your own messages being handled twice.

## 3.8.1
- Kill streak alerts (and the alert when a streak ends) and revenge alerts now show the guildmate's title, like kill alerts do: "Lyra the Avenger is on a 5-kill streak!"

## 3.8.0
### Raids
- **Attunements:** a new window (the Attunements button on the Raids tab's Progress view, or `/warcrest attune`) shows who in the guild is attuned for **Molten Core, Onyxia, Blackwing Lair and Naxxramas**, and who has the **Upper Blackrock Spire** and **Scholomance** keys. Warcrest checks the attunement quests you've finished and shares them; search by name, or show level 60s only. Your player card lists your attunements, the guild hears when someone gets a new one, and a raid's sign-up list flags anyone who isn't attuned for it.
- **Raid assignments:** officers write who does what on each boss (tanks, healers, interrupts, a line per job) with the Assignments button on Progress, or `/warcrest assign`. Everyone sees the plan with their own name picked out and their jobs at the top, and Warcrest reminds you of your job in chat when the boss is pulled. **Post to raid chat** posts the plan a line at a time.
- **Wipe tracking:** every boss pull in a guild raid is recorded, kill or wipe, with how long it took. Progress now shows **wipes** and the **best kill time** for each boss (hover for pulls, wipes before the first kill and the last kill time), and the raid hears when it beats its best time.

### Guild
- **Guild polls:** the Events tab has a **Polls** view (`/warcrest polls`). Ask a question with 2 to 6 answers, open for 1 day to a week; everyone with Warcrest votes, and can change their vote while it's open. Officers can always start polls, and can let members start them too (Settings, **Members can start polls**).
- **Crafting orders:** click a recipe in the crafters window to order it: pick a crafter (online ones first), say if you're bringing the materials, add a note. The crafter accepts, declines or marks it done, and both of you hear about every change. The new **Orders** view (`/warcrest orders`) lists yours.
- **Inactive members (officers):** the Officers tab's new **Inactive** view (`/warcrest inactive`) lists who hasn't logged in for 14, 30, 60 or 90 days, longest gone first, with their rank, level and last raid.

### PvP
- **Where the guild fights:** circles on the world map show where guild members killed enemy players or died to them in the last 7 days: bigger for more fights, gold where we won more, red where we lost more. Hover one for the numbers and the enemies we meet most there. Turn it off in Settings > General.

### Also
- The Raids tab's subtitle and Progress list are now translated.
- The help window has a new topic for polls and orders, and the new commands.

## 3.7.3
- **Bug reports:** type `/warcrest report` (or `/warcrest bug`) and a window opens with everything needed to look into a problem: your Warcrest and game versions, language, guild size, settings, how much history you have, your other addons, and any errors since you logged in. Copy it (Ctrl+C) into the [Warcrest Discord](https://discord.gg/qeSMwQWyPR) or the contact form on [warcrest-addon.com](https://warcrest-addon.com/#contact). It has no names in it: not yours, your guild's or your guildmates'.
- **Guild setup, finished in one go:** officers setting Warcrest up for their guild now also choose which alerts the guild hears (kills, streaks, the Wanted list, deaths, achievements, raids, celebrations) and whether achievements are posted in guild chat, then save it all for everyone. `/warcrest setup` opens it any time.
- Officers in a guild nobody has set up yet get a reminder in chat, once a session.
- **The Warcrest Discord:** `/warcrest discord`, or copy the invite from the bottom of the help window, under the website.

## 3.7.2
- Fix: **alerts and chat messages showed twice** (wanted sightings, achievements, events, raid and guild news: everything but kills, which were already merged), the second copy with a realm after the name ("spotted in Feralas by Sathryus-Realm"). The game sends your own guild messages back to you with a realm attached that doesn't always match the one it reports for you, so Warcrest didn't recognise them as yours and handled them twice. It now recognises you by name.
- Names show without the realm everywhere, even where the game would add it.
- When two guildmates spot the same wanted enemy at the same moment, the sighting is shown once instead of twice.

## 3.7.1
- **Warcrest has a website:** https://warcrest-addon.com/. It has a tour of every tab, all 161 achievements and titles, how to install, the commands, and a **contact form** to send bugs and ideas straight to the developer.
- The address is at the bottom of the **help window**, ready to copy (click it, then Ctrl+C). `/warcrest website` (or `/warcrest feedback`) opens it there and prints it in chat.
- Fix: on the Wanted tab, the Wanted / Guilds switch no longer leaves a gap on the right when bounties are off.

## 3.7.0
### 117 new achievements (161 in all)
- **A new Social group** for events, profiles, crafting, levels and the guild, and more in every other group. **42 new titles** (67 in all), from "the Whirlwind" to "the Paragon".
- **PvP:** more killing-blow and assist milestones (up to 1,000), Triple and Quad Kills, 20- and 25-kill streaks, 10 or 20 kills in one day, Early Bird and Weekend Warrior, kills in 5, 20 and 30 zones, battleground kills, kills of ?? level enemies, different enemy players killed (up to 250), and kills of rival guilds and of different enemy guilds.
- **Hunts:** more revenge, bounty and claim milestones, Personal Vendetta (kill your own killer within 30 minutes), avenging different guildmates, Obsessed (the same enemy 10 times), 6 and 12 months as champion, and the other side of it: dying to enemy players, being hunted by the same enemy, falling, drowning and fatigue.
- **Raids:** 75 and 100 raid nights, 3 and 6 months of perfect attendance, raid sign-ups accepted, standby, raid nights led, 10, 50 and 250 boss kills, 5 or 10 bosses in one day, guild firsts of 10 and 20 bosses, and full clears of 3 and 5 different raids.
- **Loot:** up to 100 items won, 5 items in one day, free-roll and loot council wins, 200 and 500 DKP on one item, 1,000 DKP spent in all, 500 and 1,000 DKP saved, and 10 wishlist items.
- **Social:** guild events attended (up to 50) and of 5 different kinds, events planned, sharing your profile, showing a title, linking an alt, levels 10 to 50, professions shared, 300 skill and up to 200 recipes, recruits brought in (officers), and 50, 75 and 100 achievements.
- **Pages of tiles:** each group shows 16 at a time. Turn the page with the arrows next to your name, or the mouse wheel. "Loot & more" is now "Loot".
- Your achievements are recorded with the guild several to an entry, so earning a lot at once doesn't fill the guild's record.
- Everything you've done before counts, as far back as the guild's shared history goes. Only achievements earned in the last hour are announced, so the new ones won't flood chat.

### The war board: rival guilds
- **The Wanted tab has a new Guilds view:** every enemy guild the guild has met, with how many of theirs we've killed, how many of ours they've killed, and the score, for this month, last month, 7 days or all time. Click a guild to see who on our side has hit them hardest, and who on theirs has hit us.
- Which guild an enemy is in comes from what guildmates see (nameplates, targets, mouseovers) and travels with every kill and death report, so everyone's addon learns it.
- **Officers mark rival guilds** (or add one by name). Rivals are listed first, and when **3 or more players of a rival guild are seen together**, the guild is alerted where. The **weekly recap** says how each war went.

### Guild goals
- **Officers set goals for the whole guild** on the Achievements tab, Guild view: enemy players killed, rival guild kills, raid bosses, raid nights, guild events, achievements earned or loot handed out, for the week or the month. Up to 4 at a time.
- Everyone sees the progress, and the guild hears when a goal is reached.

### The crafters directory
- **Who in the guild can make what.** Open your profession windows and your recipes are shared with the guild (only when they change). Search everyone's recipes by name, filter by profession, and **click a recipe to whisper the crafter**. Online crafters are listed first.
- Open it with **Crafters** on the Roster tab, or `/warcrest craft` (with a word to search, like `/warcrest craft mooncloth`).
- Recipes show in your own language.

### Also
- Translations for everything new in German, French and Spanish, and fixes for a few achievement descriptions that ran over three lines in German.

## 3.6.5
### Everything in your language
- **Alerts and chat messages are now translated** (German, French and Spanish): kills and deaths, streaks and revenge, Wanted sightings, bounties, guild firsts and full clears, raid reminders, raid-night DKP awards, loot auctions and the loot council, alt links, DKP decay and imports, the weekly recap, level-ups and more. About 100 messages were still in English because they were put together from pieces (names, numbers, places).
- **Screens too:** the player card's PvP and loot lines, the Wanted details, the officer log ("Thorne promoted Mira to Veteran"), the raid's tank and healer check, the Kills tab's best streak and monthly champion, the raid plan's group headings, the DKP tab's header, the welcome window, and "and higher" for ranks in Settings.
- Singular and plural are now right in every language ("1 guild member", "3 guild members"), instead of only in English.

### Polish
- **Raids tab:** while a raid night is running, the On time / Per hour / Per boss boxes are hidden. They only apply to the next raid night you start, and showed different numbers from the one in progress.
- **Recruit tab:** a recruit who has joined the guild shows their level and class from the roster, and class names read "Mage" rather than "MAGE".
- **Player card:** "Item level 66" now matches the rest of the line.
- **Guild profiles:** the window is wider, so play times fit.
- **Events tab:** the attendance note can use two lines in longer languages.
- **Settings > General:** "Good to know" mentions profiles and /warcrest check.
- German times read "vor 8 h" instead of "vor 8 Std.." (no more double full stops).

## 3.6.4
### Performance
- **Faster in big guilds.** Checking whether someone is in the guild was reading the whole guild roster from the game, member by member, every time the answer was "no" (whispers from strangers, recruits, party members from outside the guild). It now answers straight away. The Recruit tab with 200 recruits refreshes in about 10 ms instead of a quarter of a second.
- **Titles in chat** look up a guildmate's title instantly instead of going through every title choice in the guild for each chat line.
- **The Events tab** works out everyone's answers and attendance once per change instead of once per row: about five times quicker with many events.
- Every tab refreshes in a few milliseconds in a 500-member guild with full history, events, profiles and recruits.

### Polish
- **Dates are in your language.** Day and month names ("Friday, Nov 20") were always in English, because the game's date function only knows English. They now follow your language everywhere in Warcrest: raids, events, the calendar, player cards, the officer log and more.
- **Your item level is only shared once the game has loaded all your gear,** so it's never shared lower than it is. A changed item level is shared at most once a day.
- Old event reminders and last year's birthday notes are tidied out of your saved data.
- Layout fixes in German, French and Spanish: the new-event form, the profile editor (the Role buttons stuck out), and the Guild profiles list (the summary ran under the sort buttons, which are now at the bottom).

## 3.6.3
- **Titles in chat.** When a guildmate with a title says something (guild, officer, say, yell, party, raid, whispers and chat channels), your chat window shows their title in gold at the start: **[Lyra]: (the Avenger) anyone up for Tarren Mill?** It only changes what your own chat window shows, so players without Warcrest see their messages as normal. Turn it off with **Show titles in chat** in the Title window (Achievements tab).
- **Titles in kill alerts:** "Lyra the Avenger killed Grim in Stranglethorn Vale".
- **Titles on the Kills tab:** the head hunter in the lead has their title shown under their name, and kill tooltips show the killer's title.

## 3.6.2
- **Achievements are now posted in guild chat.** When you earn one, your addon posts it in /guild ("Blaauurgh earned First Blood!"), so the whole guild sees it, even members without Warcrest. Several earned at once share one line, and each is only posted once. Only the player who earned it posts, so there are no repeats.
  - Officers can turn this off for the whole guild: Settings > Alerts, **Posted in guild chat**, then Save for whole guild. Anyone can turn it off for their own achievements with the box in the You column.
- Fix: **achievement alerts were missed when a kill arrived late.** Alerts were only shown for achievements earned in the last 15 minutes, and a kill that reached a guildmate through a later catch-up (as happened before 3.6.1) could miss that window. It's now an hour.
- **/warcrest check** also says whether achievement alerts and guild chat posts are on, for the guild and for you.

## 3.6.1
- Fix: **your own kills (and achievements like First Blood) now count the moment they happen.** Warcrest was waiting for the game to send your own guild messages back to you, as retail WoW does. WoW: Forever doesn't, so your own kill only reached your log later, when a guildmate's copy synced. Everything you send to the guild or your raid is now handled on your side as it goes out: your kills, deaths, Wanted sightings, bids and the rest show up straight away.

## 3.6.0
### Guild events
- **A new Events tab for everything that isn't a raid:** PvP nights, world boss hunts, dungeon runs, guild meetings and get-togethers. **Anyone in the guild can plan one**, not only officers.
- Guildmates answer **Going, Maybe or Can't go**, get an alert when a new event is planned (you can turn that off), and a **reminder 15 minutes before** events they're going to.
- Whoever planned the event, or an officer, can **invite everyone going** in one click, **take attendance** from their group, and cancel it.
- Events show on the **Raids calendar** in their own colours (PvP red, world boss purple, and so on). Click one to open it.
- Events attended show on player cards, and count for recruits' trials.

### Member profiles
- **Tell the guild about yourself:** main spec, role, the days and times you usually play, your birthday and a short note. Open it with **Edit profile** on your own player card, or **/warcrest profile**.
- **Your item level is added automatically** from the gear you're wearing, and kept up to date as it changes.
- Profiles show on **player cards**. The new **Profiles** button on the Roster tab lists everyone's spec, role, item level and play times, sortable by role or item level: a quick gear check before a raid.
- **Birthdays and anniversaries:** the guild hears about a member's birthday when they log in on the day (no year is shared), and when someone has been in the guild for a year or more.

### Recruiting (officers)
- **A new Recruit tab** with the guild's recruit list, shared by every officer. Each recruit moves through **New, Contacted, Trial, Joined or Declined**, with a note.
- **Trials:** set a recruit to Trial when they join and Warcrest tracks it: days in, raid nights and events attended. Officers are told when a trial is over. Trials last 14 days unless you pick 7, 21 or 30.
- **Whispers about joining:** when a player outside the guild whispers an officer about joining ("guild invite?", "are you recruiting?"), they're listed on the Recruit tab with an Add button.
- **The recruiting message:** write it once for every officer, pick a channel (Trade, General...) and post it with one click. **Guild invite** and **Whisper** buttons for each recruit.

### Also
- New: **/warcrest check [name]** shows why achievements have or haven't counted: kills in your log (killing blows, assists, and any that didn't count for honor), whether your last kill was sent and came back from the guild, and what's recorded with the guild. Use it if an achievement doesn't show up straight away.
- New sounds setting: **Guild event** (Settings > Sounds).

## 3.5.5
- **Lost achievements come back for everyone, not only through officers.** Every guildmate's Warcrest remembers what each guildmate has earned. Now members' addons vouch for achievements a guildmate has lost too, a few minutes after they log in. An achievement comes back once **one officer, or two different guildmates**, have seen it earned, so nobody can hand out achievements on their own. The more of the guild logs in on 3.5.5, the more comes back.
- **History saved under Warcrest's older names is found and added back.** For a short while Warcrest was called Bannerhold and kept its history under that name. A small **Warcrest: data from Bannerhold** helper now comes in the zip (like the one for The Imperium). If any of that history is still on your computer, Warcrest adds what's missing (kills, deaths, the guild record and achievements) once, and tells you.

## 3.5.4
- Fix: **kills were being deleted after the killer levelled up**, and with them the achievements that came from them. Each time you logged in, Warcrest cleared out kills it thought were "grey" (no honor), judged by the killers' levels *now* instead of at the time of the kill. Once someone had levelled, many of their earlier kills looked grey and were removed, from every guildmate's copy. Since 3.4.1 (when offline members' levels became known) this hit the whole guild. Kills are now only checked for grey when they happen; nothing in the log is ever removed for it later, and older kills from guildmates' logs are taken as recorded.
- **Achievements members lost are put back.** Every officer's Warcrest remembers what each guildmate has earned. Any of those that aren't in the guild's record yet are now added to it by officers' addons a minute or two after they log in, and whenever someone comes back with their history missing, so the member gets them back.

## 3.5.3
- **Your achievements are now kept with the guild, not only on your computer.** Each one you earn is recorded in the guild's shared record, so if this computer's saved data is ever lost (after an update, a crash, or the game not saving), your achievements come back from your guildmates as soon as you log in.
- **If Warcrest's saved history doesn't load, it now notices and gets it back.** Warcrest keeps a small note of how much history you had. If it starts with nothing though there was history last time, it tells you and asks the guild to send it back: the guild record (raids, DKP, sign-ups, achievements) from officers, and up to 60 days of kills and deaths from any guildmate.
- **Saving is safer.** Just before the game writes Warcrest's saved data, anything it can't save (such as the "secret" values newer game clients use for some names) is taken out, so one bad value can't stop the whole save.
- Fix: **achievements and titles now update straight away**, without a /reload. Warcrest used to work achievements out again a moment after a change, and anything that read them in between (the Achievements tab, titles, player cards) could show the old ones until a reload. They're now worked out fresh whenever something they come from has changed: a kill, a death, a boss, loot, raid attendance or a level-up.
- Fix: **reaching max level now counts at once** (it used to wait for a reload).
- **Choosing your title has moved to the Achievements tab, and works properly.** The Title button at the top right opens a list of every title: the ones you've earned (click one to use it), and the ones you haven't yet, with the achievement that gives each. The title picker in Settings is gone.

## 3.5.1
- **Sounds shared by your other add-ons are no longer added to the sound picker on their own.** Warcrest was listing every sound other add-ons share through SharedMedia, named however those add-ons' makers named them. They're now off unless you tick **Sounds from other add-ons** in Settings > Sounds, and they're marked "Other add-on" in the picker. An alert that was set to one of them goes back to its own sound.

## 3.5.0
- **50 more alert sounds, 87 in all**, sorted into kinds in the sound picker:
  - **Horns & fanfares:** battle horn, distant horn, hunting horn, royal fanfare, triumph.
  - **Bells & chimes:** church bells, wind chimes, music box, hand bell, double bell, singing bowl.
  - **Drums:** tribal drums, taiko, timpani roll, snare, woodblock, heavy impact.
  - **Combat:** sword drawn, axe chop, mace hit, shield block, bow shot, arrow volley, battle cry.
  - **Magic:** arcane blast, fire whoosh, frost shimmer, holy light, shadow pulse, nature chime, portal, power up.
  - **Alerts:** siren, beep beep, triple beep, tick tock, countdown, error buzz, success, soft notice.
  - **Nature:** thunderclap, rain, wind, wolf howl, raven.
  - **Music:** marimba, flute call, organ, pizzicato, ominous drone.
- The picker shows each sound's kind, and searching finds kinds too (type "magic" or "drums").

## 3.4.1
- Fix: **offline guild members were treated as not in the guild** when "Show offline members" was unticked in the game's guild window (the game then lists only who's online). Their player card said "Not in the guild right now", and they could be missed for achievements, the guild's achievement feed, and checking who's an officer. Warcrest now keeps offline members listed, so everyone counts whether they're online or not. (Warcrest's own Roster tab still has its own Show offline box.)
- The player card now names the guild: "Level 60 Mage · Officer · <Your Guild>". For someone outside your guild it says which guild they're in when the game can tell (they're your target, mouseover, in your group or on a nameplate), or "Not in your guild".
- Fix: kills and deaths are now always recorded, even when the guild has turned that kind of alert off. The alert settings only decide what's shown; kills still count toward the leaderboard, streaks and achievements like First Blood.
- /warcrest debug now also says, after a kill, whether it counted, and if not, why (a grey kill: the enemy's level gives no honor, so it doesn't count).

## 3.4.0
- New: **a sound for every kind of alert, and you choose them.** Settings has a new **Sounds** view listing each kind of alert (a guild kill, a guild member down, a wanted ganker spotted, a bounty, a kill streak, revenge, Top Head Hunters, a boss down, raids, loot auctions, achievements and guild news) with its sound. Click a sound to pick another, or the play button to hear it.
- New: **37 sound effects made for Warcrest**: war horn, rally cry, victory fanfare, trumpet call, heroic choir, war drums, drum roll, thunder, sword clash, shield bash, anvil, bells and chimes, a death toll, alarms, coins, sparkles, harp, lute and more. Each alert starts with one that fits it.
- **Pick from the game's sounds too** (ready check, battleground ready, epic loot and others), and from any **SharedMedia** sounds your other add-ons have.
- **Add your own sounds.** Make a folder called WarcrestSounds in Interface\AddOns, put .ogg or .mp3 files in it, restart the game, and add each one by its file name in Settings > Sounds. Updates to Warcrest never touch that folder.
- Choose which **volume channel** alert sounds play on (Master by default, so they play even with game effects turned down), or turn alert sounds off.
- Fix: the "nothing here" text in lists now shows in your language.

## 3.3.1
- **Faster, especially in big guilds with a long history.**
  - Catching up after time away no longer slows down as the record grows. Taking in thousands of guild changes (raids, DKP, sign-ups) used to re-sort the whole record for each one; it now files each change in place. In a test guild with 10,000 changes, that went from over a minute and a half to a third of a second.
  - A DKP award, a sign-up or a won item no longer makes Warcrest work out everything again: DKP balances add just the new change, and boss kills, PvP stats and the kill log are only rebuilt when they actually change.
  - Achievements for the whole guild are checked a few dozen members at a time instead of all in one go, so there's no hitch when something changes in a big guild.
  - The kill log, loot history and achievements look things up instead of searching every entry, and a long queue of outgoing messages no longer costs time on every tick.
- **Polish.**
  - The Alts window is redesigned in the Warcrest look, and only shows what applies to you (an alt sees Unlink, a main sees the request to link).
  - The player card fits its contents, without empty space at the bottom.

## 3.3.0
- New: **raid night recap.** When an officer clicks End raid, the whole guild gets a short summary in chat, with a banner to say it's there: how long the raid night ran, the bosses killed (guild firsts marked), the loot and who won it, how many attended and who was on standby, and the DKP you earned. /warcrest raidrecap shows the last one again. Officers can turn it off for the guild in Settings > Alerts (Raid night recaps), and anyone can turn it off for themselves.
- **Help and What's new in German, French and Spanish**, so the whole addon now follows your language (Settings > General > Language).

## 3.2.0
- New: **alert banners.** Guild alerts now drop in at the top of the screen as a card in the Warcrest look, with a colour, icon and heading for each kind: a guild kill, a wanted ganker spotted, a boss down, a bounty, a kill streak, an achievement. Up to three stack, and each fades after a few seconds. Click one to open the matching tab, right-click to dismiss it, Shift-drag to move them. Each kind also has its own sound. Prefer the old look? Settings > Alerts > On screen switches to the game's raid warning text, or chat only.
- New: **loot council.** Hand out loot by vote instead of DKP (it works whether or not the guild uses DKP). An officer starts a vote with /warcrest council or the Loot council button on the Wishlist tab; everyone in the raid gets a small window to say Need, Greed or Pass. Officers see everyone who wants it with their wishlist, raid attendance, items won in the last 30 days and DKP, and vote with a click. The officer who started it awards the item, and it goes in the loot history.
- New: **raid groups planner.** The Raids tab's new Plan view lets officers put the sign-ups into groups 1 to 8 or on the bench: click a name, then a group. Auto-fill does it for you (tanks in group 1, a healer in each group, then everyone else, up to the raid size you pick). Everyone can see the plan. At raid time, Invite sign-ups invites only the planned groups, and Arrange raid moves everyone into their planned group.
- New: **bounties**, off until a guild leader or officer turns them on (Settings > Alerts > Bounties). Officers put a reward on an enemy player's head on the Wanted tab's Bounties view; the first guild member to kill them in the next 30 days claims it and is paid automatically (in DKP, if the guild uses it). The guild hears when a bounty is placed and when it's claimed.
- New: **German, French and Spanish.** Warcrest follows your game's language. Pick another in Settings > General (Language), then /reload. Help and the changelog stay in English for now.
- New achievement: Collector (claim a bounty), 44 in all.
- Polish: achievement tiles give long names the full width (the TITLE tag moved to the bottom), a single-boss raid's clear is announced without "all 1 bosses", the Achievements header no longer repeats your count, and the help covers the new features.

## 3.1.1
- Ready for raid launch: Warcrest now notes every raid boss that dies and whether it counted for the guild, and why not if it didn't (not a raid instance, not in a raid group, fewer than 5 guild members, or guild members under half the raid). Type /warcrest bosses to see the last few. With /warcrest debug on, each check also shows in chat as it happens.
- Boss kills are also picked up from the game's boss-kill event, in case the encounter event doesn't come, and a boss the game gives no ID for still counts (by its name).

## 3.1.0
- New: raid progress. When the guild kills a raid boss, it's recorded for everyone: which boss, which raid, and who was there. The Raids tab's new Progress view shows how far the guild has got in each raid (like 4 / 13 bosses in Hyjal Summit), with each boss's first kill, how many times it's died, and the last kill. A kill counts when 5 or more guild members, at least half the raid, kill a raid boss.
- Guild firsts: the first time the guild kills a boss, everyone hears about it, and again when a raid is fully cleared for the first time. Turn it off under Settings > Alerts (Guild first boss kills).
- New: raid calendar. The Raids tab's Calendar view shows a month at a glance: raids scheduled (gold), raid nights held (green) with how many bosses died, and past raids. Hover a day for the details, or click a raid to open it.
- 22 new achievements, 43 in all, now in four groups on the Achievements tab: PvP, Hunts, Raids, and Loot & more.
  - PvP: Legend (500 killing blows), Shield Brother (100 assists), Godlike (a 15-kill streak), Double Kill (two killing blows within 10 seconds), Night Owl (a kill between midnight and 5 in the morning) and Globetrotter (kills in 10 zones).
  - Hunts: Manhunter (5 kills of wanted enemies), Grudge Match (kill the same enemy 5 times) and Dynasty (top of Top Head Hunters for 3 months).
  - Raids: Stalwart (50 raid nights), Perfect Attendance (every raid night in a month, at least 4), Boss Down, Boss Slayer (25 boss kills), Raidbreaker (100), Pioneer (the guild's first kill of a boss), Trailblazer (5 guild firsts) and Full Clear (every boss of a raid within a week).
  - Loot & more: Geared Up (10 items), Lucky Roll (win a free roll), Fortunate (5 wishlist items won), Altoholic (3 alts linked) and Guild Hero (25 other achievements).
  - 14 new titles: the Legend, the Godlike, the Manhunter, the Relentless, the Undisputed, the Stalwart, the Dependable, the Slayer, the Raidbreaker, the Pioneer, the Trailblazer, the Conqueror, the Fortunate and the Hero.
- Player cards show how many boss kills someone was there for, and how many were guild firsts.
- The weekly recap lists the bosses the guild killed.
- New: a welcome for new players and guilds. The first time Warcrest loads, a short welcome shows what it does and where to start. Officers in a guild nobody has set up yet choose who manages Warcrest and whether the guild uses DKP, and save it for everyone. /warcrest welcome shows it again.
- Guilds can now turn DKP off (Settings > Alerts > Use DKP for loot). Without DKP, the DKP tab, loot auctions and raid night DKP are hidden for everyone; raids, sign-ups, attendance, boss kills, wishlists and everything else still work.
- New: a help window, with short answers about every part of Warcrest and every command. Open it with Help at the bottom of the side menu, /warcrest help, or from the welcome.
- Big guilds: Warcrest stays smooth with hundreds of members and thousands of kills. Lists only make the rows you can see, the roster is read once instead of over and over, and streaks and achievements are worked out in one pass.
- Polish: the Achievements tiles widen with the window, raids with no sign-ups yet show a grey 0 instead of green, the raid night card leaves out DKP when the guild doesn't use it, and messages are shorter and clearer. An unknown /warcrest command now lists the main commands and points to the help.

## 3.0.0
- The Imperium is now **Warcrest**, guild tools for any guild on WoW Forever. Members of <The Imperium> still see the Imperium emblem and name; every other guild gets the Warcrest crest, with their own guild's name under it.
- Updating keeps everything: your settings, DKP, raids, logs and history move over by themselves the first time you log in. The download includes a small TheImperium folder that does the hand-over; leave it installed.
- Guildmates still on The Imperium 2.x keep working with you while everyone updates, and they're told a newer version is out.
- Commands start with /warcrest, or /wc for short. /imperium and /imp still work.
- Level-up celebrations, the DKP export and the guild window use your own guild's name.
- Everything from 2.12.0, 2.13.0 and 2.14.0 below is included.

## 2.14.0
- New: loot wishlists. The new Wishlist tab is where you mark the items you're after: Shift-click an item into the box, pick Need (a big upgrade) or Want (nice to have), and click Add. Your list is shared with the guild. The table shows every item guildmates want, Need first, with who wants it; "In my raid" narrows it to the people in your raid. Click one of your items to switch Need and Want, or the X to remove it.
- When an item is auctioned, everyone who has it on their wishlist gets a message, the auction window shows who wished for it (Need in gold), and the officer running the auction gets the list with each person's DKP in chat. Once you win an item, it's marked Won on your list and you no longer count as wanting it. Player cards show what's on someone's wishlist.
- New: achievements and titles. 21 achievements on the new Achievements tab: killing blows (1, 25, 100, 250), assists, kill streaks (3, 5, 10), revenge kills, bounty kills on wanted enemies, killing your nemesis, finishing a month top of Top Head Hunters, raid nights (1, 10, 25), winning loot, spending 100 DKP on one item, winning an item from your wishlist, reaching max level, and earning 10 others. They're worked out from the guild's shared history, so everyone sees the same ones, including what was earned before this version.
- Tiles show what you've earned (with the date) and your progress on the rest. The Guild view lists what's been earned across the guild, newest first, and who has the most. The guild hears when someone earns one while you're online; turn that off under Settings > Alerts (Achievements earned).
- Ten achievements come with a title, like "the Avenger" or "the Iron Raider". Pick yours at the top of the Achievements tab or in Settings > General; it shows after your name on your player card and on the Roster. Only titles you've earned can be shown.
- Player cards have a button showing how many achievements someone has, which opens them.
- The Wanted tab is redesigned: a table of wanted enemies, a card for the one you picked (or the most wanted) with their last kill and last sighting, Show on map and Hide buttons, and a card explaining how the list works. The "wanted after" setting and Show hidden are at the top.
- The Settings tab is redesigned in two views. Alerts: one table with a Guild column (set by officers) and a You column for every alert, the guild-wide card (guild alerts on, who can change them, Save for whole guild) and how alerts appear. General: quiet mode, the world map, the weekly recap, your title, the window's size and a few handy commands.
- The Officers tab is redesigned: a searchable table of guild changes with a filter at the top (ranks, joins and leaves, notes and settings), and the last 7 days at a glance (promotions, demotions, joins, leaves).
- The Addon tab is redesigned: tiles for how many members have the addon, how many are out of date, how many online have it and the newest version, then a searchable member table with a filter at the top. Click a member for their player card.
- New commands: /imperium wishlist and /imperium achievements.

## 2.13.0
- New: player cards. Click a guild member's name to see everything about them in one place: kills this month and all time, assists, deaths to enemy players, their current and best kill streak, their nemesis (the enemy player who has killed them most) and who they've killed most, plus their DKP, raid attendance, no-shows, items won and recent loot, with their alts or main. A Whisper button starts a whisper. Open one from the Roster (View player card, or double-click a name), by clicking a killer on the Kills tab or a name on Top Head Hunters, a name in the DKP standings, or a sign-up on the Raids tab. Or type /imperium card Name (/imperium card on its own shows yours).
- New: kill streaks. Killing blows in a row without dying to an enemy player, each within an hour of the last, make a streak. The guild hears when someone reaches 3, 5, 10, 15, 20, 25 and 30 kills, and when a streak of 5 or more is ended (and by whom). The Kills tab shows the best streak of the period under Top Head Hunters.
- New: revenge. When a guild member kills an enemy player who killed a guildmate in the last 30 minutes, the guild hears about it.
- Streaks and revenge are a new alert group in Settings ("Streaks and revenge"), on by default; officers can turn them off for the guild, and anyone can turn them off for themselves.
- The DKP tab is redesigned in the new look: standings, loot and changes are one table with a switch at the top, and a search box that works on all three. Officers get cards beside it for awarding DKP, running a loot auction, and the DKP rules (decay, hidden bids, export, import and new season). Members see their own DKP and their recent changes.
- The Raids tab is redesigned: upcoming raids are cards on the left with your answer and a warning for makeup gaps, and the raid night controls sit under them. The selected raid shows its date, notes, sign-up counts, the classes coming, the makeup banner, a Tank / Healer / DPS switch (in place of the role button you clicked through) and your Accept / Tentative / Decline buttons, then the sign-up list. A switch at the top shows your raid group instead.
- The Roster tab is redesigned: a member table with level, rank and where they are, a member card for notes and rank changes, and a Guild card for invites and the Message of the Day.

## 2.12.0
- New look: the guild panel and every window have been redesigned. It's dark and flat with Imperium gold accents, in a clean new font (Inter), with a side menu with icons in place of the tabs along the bottom, and a header naming the tab you're on. Buttons, inputs, checkboxes and lists all match, and each screen's main action (Add DKP, Start raid, Bid, Save for whole guild...) is in gold. Your own sign-up answer on the Raids tab is shown in gold too.
- The loot auction, Alts, Import, Export and What's new windows use the new look.
- The header under each tab's name shows something useful at a glance: guild size and how many are online, raids scheduled and whether a raid night is on, your own DKP, how many are wanted, and how many members have the addon.
- Slimmer scroll bars in the theme's colors.
- The Kills tab is redesigned: kills are a table (killer, victim, where with assists or battleground underneath, and when), with a "Leading this month" card showing the leader, their count and how far ahead they are, and Top Head Hunters with a bar for each place. Pick the period (this month, last month, 7 days, all time) and kill type at the top; the header shows how many kills that is. Hover a hunter for their assists. Drag the borders between the Killer, Victim and Where headings to resize those columns and see long names in full, or double-click a border to fit the column to its longest name; your widths are remembered.
- Lists have a dark card background, and every other row is shaded, so it's easier to follow a row across.
- Every list says something when it's empty or nothing matches your search, including ones that used to be blank: the roster, DKP standings and changes, raid sign-ups, your raid group and the Addon tab.
- Resizable: drag the bottom-right corner of the guild window to make it bigger, and the lists stretch to show more rows (the kill table, roster, DKP standings, loot and changes, raids and sign-ups, the Wanted list, the officer log and the Addon tab). Settings > Guild window has a Size slider (70% to 150%) that scales the window and its pop-ups, text and all, and a button to reset the size and position. Both are remembered.
- The guild panel opens on the tab you used last.
- Tooltips on 30 buttons that didn't explain themselves, such as Promote, Start raid, Add DKP, Decay now, Import balances and the kill log filters. They show even when a button is greyed out, so you can see what it does.
- On the Raids tab, sign-up counts are only in color when there are some, so "0 declined" no longer shows in red.
- Fixed: on the Raids tab, the raid night details could run into the On time / Per hour / Per boss boxes below them.
- Behind the scenes: the addon's files are organized into folders by feature (Core, Guild, PvP, Raids, and the panel's tabs under UI/Tabs). Nothing changes in game. If you install by hand, delete the old TheImperium folder before unzipping the new one, so the old loose files don't stay behind (they're unused, but it keeps things tidy).

## 2.11.1
- Fixed: kills of grey-level players (far below the killer's level) were still logged and announced, for two reasons: when the game gave an honor message the kill counted whatever the victim's level, and officers could switch "Honor kills only" off. Now the victim's level decides (the honor message only counts when the level couldn't be seen), and grey kills are never reported, announced or logged.
- Guildmates' reports are checked against the killers' levels from the guild roster, so grey kills sent by older versions, live or through kill-log sync, are dropped too. Grey kills already in your log are cleared out shortly after you log in, so the Kills tab, Top Head Hunters and the weekly recap no longer count them.
- The "Honor kills only" option is gone from Settings: it's always on.

## 2.11.0
- New: raid makeup check. The Raids tab lists who has accepted by class (in class colors, with names colored too) and warns about gaps: too few tanks (2 wanted from 10 players, otherwise 1), too few healers (about one per five players), with tentative sign-ups for that role noted. Once 10 have accepted, it also names any class that has max-level members in the guild but nobody signed up. Hover the warning for the details. Raids with gaps get an orange "!" in the Upcoming raids list.
- New: an hour before a scheduled raid, officers get one chat line about any gaps in its makeup.
- New: weekly recap. After the Tuesday reset, everyone gets a short summary of the guild's last week in chat: enemy players killed and the top three head hunters, guild members killed by enemy players and who killed us most, raid nights and bosses killed, and loot handed out with the biggest buy. Anyone offline at the reset sees it at their next login. It's skipped for quiet weeks and for a fresh install. Turn it off, or show it again, in Settings (Weekly recap), or type /imperium recap (or /imperium recap now for this week so far).

## 2.10.0
- Top Head Hunters resets monthly. The Kills tab shows this month by default (the board's title names the month); switch to Last month, Last 7 days or All time to see earlier standings. Months follow the realm's clock, so everyone resets at the same moment.
- Reset-day announcement: on the 1st, everyone online hears last month's top three head hunters, with the champion in the middle of the screen. Anyone who wasn't on that day hears it at their first login that week. Last month's champion is also shown under the board.
- Fixed: for kills recorded without hit timings (from versions before 2.5.0), different guildmates could credit the killing blow to different people. The choice is now the same on every copy.
- The kill log keeps up to 2,000 kills (was 500), so last month is always available.

## 2.9.0
- New: DKP seasons. Officers click New season on the DKP tab. Everyone keeps their current DKP; DKP changes and loot history from before the season, and raids, sign-ups and attendance older than 30 days, are archived. Alt links, DKP rules and kill removals are kept. Guildmates who were offline archive their copy when they next catch up, and archived history can't come back.
- Faster: the DKP record is now indexed once per change instead of being re-scanned and re-sorted on every lookup, which speeds up balances, attendance and the Raids and DKP tabs.

## 2.8.0
- New: alts. Link an alt to your main from the DKP tab (Alts): ask from the alt, then confirm from the main. Alts share the main's DKP and attendance, and can bid with it. Officers can link or unlink any alt directly.
- New: boss DKP. A "Per boss" amount when starting a raid, awarded automatically to the raid (and standby) on each boss kill, once per boss per night.
- New: free rolls. When an auction ends with no bids, the raid gets 20 seconds to /roll for it, and the highest roll wins it for free. Only each raid member's first roll counts.
- New: class check. The bid window warns you, and asks to confirm, before you bid on armor or weapons your class can't use.
- New: corrections. Officers can undo any DKP change from the new "All changes" view, and right-click loot to refund it or give it to someone else. Undone changes stay visible, marked as undone.
- New: import starting balances. Officers paste "Name, DKP" lines to set everyone's balance at once, useful when moving from another DKP system.

## 2.7.0
- New: attendance. The DKP tab shows each member's attendance over the last 30 days (green 75%+, yellow 40%+, red below). Hover a name for the exact count and any no-shows.
- New: standby. During a raid night, officers can add members to standby on the Raids tab (Show current raid group). Standby members get the on-time and hourly DKP and count as attending.
- New: no-show tracking. Once a raid night is held for a scheduled raid, accepted sign-ups who never came are marked "No-show" on the Raids tab and count against their attendance.
- New: Invite sign-ups. One officer button invites every online member who accepted or is tentative, turning the party into a raid automatically. When the raid starts, members who signed up but aren't there get a reminder.
- New: DKP decay. Officers can take a percentage off everyone's DKP with "Decay now", or tick "Every week" to have it applied automatically after each Tuesday reset. A week can only be decayed once.
- New: hidden bids. With this on, nobody sees anyone else's bid; the highest bid wins and pays the second-highest bid + 1 (or the minimum if there's only one bid).

## 2.6.0
- New: Loot history on the DKP tab. Every item won in an auction, the winner, the DKP paid and the raid night, with the item's tooltip on hover. Searchable by item or winner.
- New: officers can export DKP as plain text (standings, loot and every DKP change) to keep a backup outside the game.
- Fixed: on busy nights, messages could be silently dropped by the game's sending limits, losing kills, bids or catch-up data. All messages now go through a queue that stays within the limits, with alerts and loot bids sent first and catch-up data on its own channel.

## 2.5.0
- Killing blows and assists. Each killer reports how long before the death they last hit the victim; whoever hit last gets the killing blow, the rest get assists. Top Head Hunters ranks by killing blows, with assists shown next to them. Alerts read "Alice killed Ganker (assist: Bob)".
- Honor kills only. Kills the game gives no honor for (grey, much lower level victims) no longer count in alerts, the Kills tab or Top Head Hunters. On by default for the guild; officers can turn it off in Settings, and members can turn it on just for themselves. The victim's level is recorded and shown in the tooltip.
- Officers can right-click a kill on the Kills tab to remove it for the whole guild. Removals are kept in the shared record, so they stay removed for everyone.

## 2.4.1
- Fixed: guildmates' Kills tabs and Top Head Hunters drifted apart, because catching up only covered the last two days and came from one guildmate. Kill logs now compare with each other every 15 minutes and at login, and swap any differences both ways, over the full history.
- Fixed: killing the same player twice within 2 minutes counted as one kill. Reports are now only combined within 30 seconds.

## 2.4.0
- New Addon tab: every guild member with whether they have The Imperium, which version, and when their addon was last seen. Filter by has it, doesn't have it, or out of date, and click Check now to ask everyone online.
- New command: `/imperium addon`.

## 2.3.0
- New: when a guild member kills a wanted player, the bounty is claimed and they drop off the Wanted list. Only guild deaths after that kill count toward them, so they return if they keep ganking.
- Kill alerts add "Wanted bounty claimed!" when the victim was wanted.
- A checkbox at the bottom of the Wanted tab turns this on or off (on by default).

## 2.2.0
- New: an Updates panel appears once after each update, showing what changed since the version you last used. Reopen it with `/imperium updates`.

## 2.1.1
- Fixed: deaths to damage over time were announced as falling to death. A death now only counts as a fall if you dropped for at least a second, died the moment you landed, and weren't in combat during the fall.

## 2.1.0 (release)
- Fresh start for release: the first time you load this version, all test data is cleared (kills, PvP deaths, Wanted sightings, raids, sign-ups, DKP and the Officer log). Your personal settings are kept.
- Anything recorded before the release is refused, so test data can't come back from players still on an older version.

## 2.0.0
- Removed duels: the Duels tab, duel alerts, the duel log and its leaderboard. Old duel data is cleared when you log in.
- The Guild Master's Clear log now covers the Kills and Officer logs.
- `/imperium debug` now shows error details in chat, for troubleshooting.

## 1.9.6
- Fixed: duels couldn't be decided when the game hides health during combat. The addon now waits for combat to end to read health, and when both duelists have the addon they share their health and the lower one lost.
- Debug mode watches more chat channels for the duel result line.

## 1.9.5
- `/imperium debug` is now listed in the command list.
- `/imperium version` also reports whether any part of the addon has run into a problem, and shows the first one.
- If one part of the addon runs into an error, the rest keeps working instead of stopping. With debug on, errors are shown in chat.

## 1.9.4
- Fixed: duels weren't announced or logged for some players. The game's duel result line is now matched more loosely, with built-in English wording as a backup, and if the line can't be read at all, the result is worked out from the game's duel events (who you dueled, whether someone left the duel area, and your health when it ended).
- New: `/imperium debug` shows what the addon sees during a duel, to help track down problems.

## 1.9.3
- Only the Guild Master sees the Clear log button on the Kills, Duels and Officers tabs.
- Clearing now clears that log for the whole guild, not just your own copy, and old entries can't come back through shared history. Guildmates who were offline get the clear when they next catch up.

## 1.9.2
- Fixed: party members who didn't fight were reported as killing enemy players. A kill now only counts if you attacked that player in the last 10 seconds: a harmful spell on them, auto-attacking or shooting them, or your pet attacking them. Shared party honor, targeting an enemy, or being attacked by one no longer counts.

## 1.9.1
- Removed the Deaths tab, including the death log and the most-deaths leaderboard.
- Shift-clicking the minimap button now opens the Kills tab.

## 1.9.0
- New Raids tab. Officers schedule raids (name, day, start time, notes). Members sign up as Tank, Healer or DPS with Accept, Tentative or Decline, and get a reminder 15 minutes before a raid they're going to. A second view shows your current raid group with each person's sign-up and DKP.
- New DKP tab. Everyone's DKP with each member's history on hover. Officers award or remove DKP for ticked members, with "Select current raid" to tick everyone in the raid.
- Attendance DKP: an officer clicks Start raid in the Raids tab. Every guild member in the raid gets the on-time bonus, then DKP every hour until the officer clicks End raid.
- Loot auctions: an officer Shift-clicks an item into the DKP tab and starts an auction. Raid members get a bid window with the item, the highest bid and a countdown. Bids must beat the highest bid and be within the bidder's DKP; a bid in the last 5 seconds adds time. The winner's DKP is deducted automatically.
- Raids and DKP are kept in a shared record that guildmates sync with each other. Only officers can create raids or change DKP, and nobody can slip in fake DKP.
- New commands: `/imperium raids`, `/imperium dkp`, `/imperium auction [item] [min bid]`.
- The guild tools window is wider to fit the new tabs.

## 1.8.2
- Removed all deaths to monsters: dungeons, raids and the open world. Only world PvP deaths and falling, drowning or fatigue are announced now, and old monster deaths are cleared from the death log.

## 1.8.1
- Kills tab: the board is now "Top Head Hunters", showing the top 18 with the top three in gold. The kills-to-deaths board was removed.
- Deaths to raid bosses and open-world bosses are no longer announced or logged. Other raid deaths, such as to trash, still are.

## 1.8.0
- New: shared history. When you log in, a guildmate who was online sends you the last two days of deaths, kills and duels you missed, so everyone's logs and leaderboards match. Type `/imperium sync` to fetch it again.
- New Kills tab: every PvP kill by guild members, with Top hunters and each member's kills next to their world PvP deaths.
- New Wanted tab: enemy players who kept killing guild members in world PvP over the last 30 days. When a guildmate sees one, the guild is alerted and the sighting is marked on the map with a purple diamond for 30 minutes.
- New: level-up celebrations. Every 10 levels and max level by default; every level up can be turned on.
- New: quiet mode. Alerts are held in dungeons and raids (on by default) and, if you choose, during combat, then listed in chat once you're out.
- The Settings tab now scrolls, and tabs have shorter names to fit: Roster, Deaths, Duels, Kills, Wanted, Settings, Officers.
- New commands: `/imperium kills`, `/imperium wanted`, `/imperium quiet`, `/imperium sync`.

## 1.7.0
- New minimap button with the guild emblem. Left-click opens guild tools, right-click opens Alert Settings, Shift-click opens the Death Log. Drag it to move it around the minimap.
- Hide or show it with `/imperium minimap` or on the Options page.

## 1.6.3
- New addon icon: the guild emblem (the trident in its golden sunburst), redrawn crisply without the shield border. Used in the AddOns list, the addons menu by the minimap, chat messages and the guild tools window.

## 1.6.2
- New slider in Alert Settings: choose how long a guild death stays marked on the world map, from 1 hour to 7 days (default 24 hours).

## 1.6.1
- Removed battleground and arena deaths. They are no longer announced, logged or shown on the leaderboard, and old ones are cleared from the death log.
- Battleground and arena kills are unchanged and can still be turned on in Alert Settings.

## 1.6.0
- New: guild deaths are marked on the world map with an X (a skull for PvP deaths) for 24 hours. Works on the normal world map and inside OpenMap. Hover a mark for details; click it to set a TomTom waypoint if you use TomTom.
- Click a death in the Death Log to open the world map where it happened.
- New Duel Log tab: recent duels with a leaderboard of most wins and most duels fought, filterable to duels between guildmates.
- New command: `/imperium duels`.
- Map marks can be turned off in Alert Settings.

## 1.5.2
- New addon icon and window portrait taken from the guild artwork: the IMPERIUM logo with the guild's heroes below it.

## 1.5.1
- The Imperium's own crest is now the addon icon: in the AddOns list, the addons menu by the minimap, the guild tools window and before every chat message.
- The full guild artwork is shown on the addon's page under Esc > Options > AddOns.

## 1.5.0
- New: duel alerts. When a guild member wins, loses or flees a duel, the guild gets an alert. A duel between two guildmates shows as one alert.
- Duel alerts can be turned on or off guild-wide by officers and for yourself.
- The Alert Settings tab is grouped into Deaths, PvP kills and Duels.
- Officers on 1.5.0 still send settings that members on 1.3.x and 1.4.x understand.

## 1.4.0
- New: PvP kill alerts. When a guild member kills an enemy player, the guild gets an alert with a red X marker. Guildmates who take down the same player together are shown in one alert.
- World PvP kills and battleground/arena kills can each be turned on or off, both guild-wide by officers and for yourself. Battleground kills start off for each person, since they can be very frequent.
- Officers on 1.4.0 still send settings that members on 1.3.x understand.

## 1.3.1
- PvP deaths now show a skull in chat, in the center-screen alert and in the death log.
- Fixed: Promote, Demote, Remove, Invite and Message of the Day were blocked by the game. They now use the game's own guild commands through secure buttons.
- Fixed: deaths to monsters didn't name the monster. The addon now keeps track of what is attacking you during a fight.
- World PvP detection is more accurate: a death is only counted as PvP when an enemy player was attacking you, if the addon saw who was.
- The guild tools window closes when you enter combat and reopens afterwards, because its secure buttons can't be used in combat.

## 1.3.0
- Death alerts now cover six death types: world PvP, battlegrounds and arenas, dungeons, raids, the open world, and falling, drowning or fatigue.
- Each member can choose which death types they see. Raid deaths are off by default.
- Officers can choose which death types are announced for the whole guild.
- New Death Log tab with recent deaths and a leaderboard of most deaths and top killers.
- Version check: you're told when a newer version is out, and the Roster tab shows who has the addon and who is out of date.
- New Officer Log tab recording promotions, demotions, removals, joins, leaves, note edits, Message of the Day changes and settings changes.
- Code reorganized into modules, with packaging set up for CurseForge and GitHub releases.
- Still shows PvP alerts sent by members on 1.2.0, but everyone should update.

## 1.2.0
- Renamed to **The Imperium**, the official guild addon.
- New guild tools window with Blizzard-style tabs and the guild crest.
- Added an entry under Esc > Options > AddOns and in the addons menu by the minimap.
- New commands: `/imperium` and `/imp`.

## 1.1.0
- Officer Roster tab: notes, promote, demote, remove, invite, Message of the Day.
- Guild-wide alert settings controlled by officers, synced to the whole guild.

## 1.0.0
- PvP death alerts for the guild.
