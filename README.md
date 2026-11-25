# Warcrest

[![Tests](https://github.com/fantasyglassui/Imperium-Guild-Tools/actions/workflows/tests.yml/badge.svg)](https://github.com/fantasyglassui/Imperium-Guild-Tools/actions/workflows/tests.yml)

**[Download on CurseForge](https://www.curseforge.com/wow/addons/warcrest)** · **[Website](https://warcrest-addon.com/)** · **[Discord](https://discord.gg/qeSMwQWyPR)**

Guild tools for World of Warcraft: Forever. Raid sign-ups, DKP with live loot auctions and wishlists, PvP kill alerts and leaderboards, a wanted list of gankers, achievements, player cards and officer tools, shared automatically between everyone in your guild who has it.

Warcrest started life as **The Imperium**, the guild addon of <The Imperium>, and is now for any guild. Members of <The Imperium> still see their own emblem and name.

## Features

- **Raid sign-ups.** Officers schedule raids; members sign up by role and get a reminder before the raid. Raids shows who's coming by class and warns when a raid is short of tanks, healers or a class.
- **Weekly recap.** After the Tuesday reset, a summary of the guild's week: kills and top head hunters, raids, bosses and loot.
- **DKP.** Earned on time and every hour of a raid, or awarded by officers. Spent by bidding on loot in live auctions.
- **Death alerts.** When a guild member dies, everyone in the guild running the addon gets an alert in chat and as a banner at the top of the screen, with a sound. Two kinds of death are covered: world PvP, and falling, drowning or fatigue. Deaths to monsters, and deaths in battlegrounds and arenas, are not announced.
- **PvP kill alerts.** When a guild member kills an enemy player, the guild hears about it. Guildmates who take down the same player together share one alert.
- **Choose what you see.** Turn each alert type on or off for yourself.
- **Deaths on the map.** Recent guild deaths (24 hours by default, adjustable from 1 hour to 7 days) are marked on the world map with an X (a skull for PvP), including inside OpenMap. Click a mark to set a TomTom waypoint.
- **Player cards.** Click any guild member's name to see their kills, deaths, nemesis, best kill streak, DKP, attendance and loot in one place.
- **Loot wishlists.** Mark the items you Need or Want; officers and bidders see who wants an item when it's auctioned.
- **Raid progress and calendar.** Boss kills are recorded for the guild, with progress per raid, wipes, best kill times and guild-first announcements. Events > Calendar shows the month's raids, raid nights, boss kills and guild events.
- **Alert sounds.** A sound for every kind of alert, from 87 sounds made for Warcrest, the game's, SharedMedia's or your own files.
- **Alert banners.** Guild alerts drop in at the top of the screen with a colour, icon and sound for each kind. Click one to open what it's about.
- **Loot council.** Vote on who gets an item, with each candidate's wishlist, attendance and recent loot in front of the officers. Works with or without DKP.
- **Raid night recap.** When the raid night ends, the guild gets a summary of the bosses, loot, attendance and the DKP each person earned.
- **Raid groups planner.** Put sign-ups into groups and on the bench before the raid; Arrange raid moves everyone into place.
- **Bounties.** Officers can put a reward on a ganker's head; the guild member who kills them claims it. Off until an officer turns it on.
- **Attunements.** Who's attuned for Molten Core, Onyxia, Blackwing Lair and Naxxramas, and who has the UBRS and Scholomance keys. Sign-ups who aren't attuned are flagged.
- **Raid assignments.** Officers write who does what on each boss and post it to raid chat; everyone sees their own job, and is reminded of it when the boss is pulled.
- **Wipe tracking.** Every boss pull is recorded, kill or wipe, with the best kill time for each boss.
- **Guild polls.** Ask the guild a question; everyone with Warcrest votes.
- **World buffs and world bosses.** The guild hears when a world buff drops or a world boss is seen (Events > World buffs).
- **Groups.** Post what you're doing and how many you need; guildmates ask to join and you invite them (Guild > Groups).
- **Profession cooldowns.** Who has a transmute, Mooncloth, Cured Rugged Hide or a Salt Shaker ready (Guild > Crafters > Cooldowns).
- **Raid check.** Every raid member's flask, elixirs, food and world buffs before the pull (Raids > Raid check).
- **Crafting orders.** Order from a guild crafter in Guild > Crafters; they accept, decline or mark it done.
- **German, French and Spanish.** Follows your game's language, or pick one in Settings.
- **Achievements and titles.** 315 achievements for kills, streaks, revenge, bounties, raids, bosses, loot and guild life, with 78 titles to show after your name, in chat and in alerts.
- **Kill streaks and revenge.** The guild hears when someone is on a kill streak (from Killing Spree at 3 to Godlike at 20 and Beyond Godlike at 30), when a big streak is ended, and when a guildmate's killer gets paid back.
- **Kill log and Top Head Hunters.** Every PvP kill by guild members, with killing blows and assists, and a monthly board of the guild's top PvP killers.
- **Wanted list.** Enemy players who keep killing guild members. When a guildmate sees one, the whole guild is alerted and the sighting goes on the map.
- **Celebrations.** The guild cheers when a member reaches every 10th level and max level, or every level if you prefer.
- **Shared history.** Logs and leaderboards are shared between guildmates, so you catch up on what happened while you were offline.
- **Quiet mode.** Alerts wait until you're out of a dungeon or raid, and optionally out of combat.
- **Version check.** The addon tells you when a newer version is out, and officers can see who is out of date.
- **Guild tools for officers.** A searchable roster where officers can edit notes, promote, demote, remove and invite members, and update the Message of the Day.
- **Guild-wide settings.** Officers can turn death alerts on or off, or choose which death types are announced, for the entire guild at once.
- **Inactive members.** Officers see who hasn't logged in for 14, 30, 60 or 90 days, with their rank and last raid.
- **Officer Log.** A record of promotions, demotions, removals, joins, leaves, note edits, Message of the Day changes and settings changes.

## Installation

1. Download the latest `Warcrest-x.y.z.zip`.
2. Extract it into your WoW Forever `Interface/AddOns` folder, so you end up with `Interface/AddOns/Warcrest/Warcrest.toc`.
3. Restart the game, or type `/reload` if you're already logged in.
4. Make sure **Warcrest** is enabled in the AddOns list on the character select screen.

When updating by hand, delete the old `Warcrest` folder first so no old files are left behind. The small `TheImperium` and `Bannerhold` folders that older versions came with aren't needed any more: delete them.

## Opening the addon

- Click the crest on the edge of your minimap. Left-click opens guild tools, right-click opens Settings, and Shift-click opens Kills. Drag it to move it.
- Type `/warcrest` (or `/wc`; the old `/imperium` works too).
- Click **Warcrest** in the addons menu by the minimap.
- Press Esc, open **Options > AddOns > Warcrest**, and click **Open Guild Tools**.

## Commands

| Command | What it does |
| --- | --- |
| `/warcrest` | Open or close the guild tools window |
| `/warcrest raids` | Open raid sign-ups |
| `/warcrest dkp` | Open DKP |
| `/warcrest calendar` | Open the calendar |
| `/warcrest auction [item] [min bid]` | Auction an item to your raid (officers; Shift-click the item into the command) |
| `/warcrest council` | The loot council vote, or start one (officers) |
| `/warcrest raidrecap` | The last raid night's recap |
| `/warcrest attune` | Who's attuned for each raid |
| `/warcrest assign` | Raid assignments for each boss |
| `/warcrest polls` | Guild polls |
| `/warcrest orders` | Your crafting orders |
| `/warcrest inactive` | Members who haven't logged in lately (officers) |
| `/warcrest kills` | Open the kill log |
| `/warcrest wanted` | Open the wanted list |
| `/warcrest card [name]` | Show a guild member's player card (yours if no name) |
| `/warcrest wishlist` | Open the loot wishlist |
| `/warcrest achievements` | Open your achievements |
| `/warcrest quiet` | Turn holding alerts during combat on or off |
| `/warcrest sync` | Fetch the last two days of guild history from guildmates |
| `/warcrest test` | Show a test alert (a different death type each time) |
| `/warcrest sound` | Turn alert sounds on or off for you |
| `/warcrest warn` | Turn on-screen alert banners on or off for you |
| `/warcrest minimap` | Show or hide the minimap button |
| `/warcrest share` | A short message about Warcrest, to copy and send to a friend or another guild |
| `/warcrest invite` | Invite your guildmates to get Warcrest (officers post it in guild chat) |
| `/warcrest debug` | Show error details in chat, for troubleshooting |
| `/warcrest updates` | Show what changed in recent versions |
| `/warcrest addon` | See who has the addon installed |
| `/warcrest versions` | Ask guildmates which version they have |
| `/warcrest version` | Show your installed version |

## How deaths are detected

WoW Forever doesn't let addons read the combat log, so the addon can't see exactly what killed you. Instead, each member's addon works out their own death from the situation and reports it:

- **Falling, drowning or fatigue:** you died just after falling, or when your breath or fatigue bar ran out.
- **World PvP:** you died PvP-flagged in the open world with an enemy player nearby.
- **Monsters:** if a monster was attacking you, the death isn't announced. Deaths inside dungeons and raids are only announced for falling, drowning or fatigue.

During a fight, the addon keeps track of which enemy is attacking you, and that's who gets named as the killer. It works best with enemy nameplates turned on, since the addon can only see enemies that are on your nameplates, targeted or focused. Some names can't be read during boss fights.

PvP deaths are marked with a skull.

## Deaths on the map

When a guild member dies, their addon sends where it happened along with the alert. The mark is placed on Blizzard's world map, so it also shows in map addons built on it, such as OpenMap. The game hides your position inside dungeons and raids, so falls there have no map mark. Marks only appear for deaths recorded while you were online, and only from members on version 1.6.0 or later.

## Raids and sign-ups

When it's time, officers click **Invite sign-ups** to invite everyone online who accepted or is tentative; a party is turned into a raid automatically. Members who signed up but aren't there when the raid starts get a reminder.

Officers click **New raid** in Raids, then fill in the raid's name, day, start time (24-hour, in your own time; everyone sees it in theirs) and optional notes. Members pick a raid on the left, choose their role, and click Accept, Tentative or Decline. Anyone who accepted or is tentative gets a reminder 15 minutes before the start. **Show current raid group** lists everyone in your raid with their sign-up and DKP.

## DKP

**Earning.** On raid night, an officer in the raid clicks **Start raid** in Raids, with the on-time and hourly amounts (10 and 10 by default). Every guild member in the raid who is online gets the on-time DKP straight away, then the hourly DKP every hour until the officer clicks **End raid**. The hourly awards come from the officer who started the raid, so they should stay in the raid. Officers can also give or take DKP by hand in Loot > Standings: tick members (or click **Select current raid**), enter an amount and reason, and click Add DKP or Remove DKP.

**Spending.** An officer Shift-clicks an item into the item box in Loot > Standings, sets the minimum bid and time, and clicks **Start auction**. Everyone in the raid with the addon gets a bid window. Each bid must beat the highest bid and can't be more than your DKP; a bid in the last 5 seconds adds 5 more seconds. When time runs out, the highest bidder wins and their DKP is deducted automatically.

**Standby.** During a raid night, officers open **Show current raid group** in Raids and add members to standby. They get the same on-time and hourly DKP as the raid and count as attending.

**Attendance and no-shows.** Loot > Standings shows each member's attendance over the last 30 days. Anyone who accepted a raid but didn't come (and wasn't on standby) is marked as a no-show on that raid and in their attendance details.

**Decay.** Officers can take a percentage off everyone's DKP with **Decay now**, or tick **Every week** to have it done automatically after each Tuesday reset. This stops DKP piling up and keeps newer members competitive. Each week can only be decayed once.

**Hidden bids.** Officers can switch auctions to hidden bids. Nobody sees anyone else's bid; the highest bid wins but only pays one more than the second-highest bid. People can bid what an item is really worth to them without being outbid by a point or overpaying.

**Boss DKP.** When starting a raid, officers can set DKP per boss kill. It's awarded automatically to everyone in the raid (and on standby) each time a boss dies, once per boss per night.

**Free rolls.** If an auction ends with no bids, the raid gets 20 seconds to roll for the item, and the highest roll wins it for free. Only each raid member's first roll counts.

**Class check.** The bid window warns you before you bid on armor or weapons your class can't use, and asks you to confirm.

**Alts.** Open **Alts** in Loot > Standings. On your alt, type your main's name and click **Ask to link**, then log in on your main and click **Confirm**. Linking needs both characters, so nobody can claim someone else's character. Alts share their main's DKP and attendance. Officers can also link or unlink alts directly.

**Corrections.** Switch Loot to **All changes** to see every DKP change. Officers can right-click one to undo it. Right-clicking an item in **Loot history** lets officers refund it or give it to someone else. Undone changes stay visible, marked as undone, so the history is always complete.

**Starting balances.** Officers can click **Import balances** and paste lines like "Alice, 120" to set everyone's DKP at once. This is handy when moving from another DKP addon or a spreadsheet.

**Seasons.** Every DKP change is kept, so after many months there's a lot of history to add up. Officers can click **New season** in Loot > Standings: everyone keeps their current DKP, but DKP changes and loot history from before the season, and raids and attendance older than 30 days, are archived for good. Export first if you want a copy. A good rhythm is a new season each raid tier or every few months.

**Loot history.** In Loot, switch from Standings to **Loot history** to see every item won in an auction: who won it, for how much, and on which raid night. Hover an item for its tooltip, or search by item or winner.

**Backups.** Officers can click **Export DKP** to get a plain-text copy of standings, loot and every DKP change, ready to paste into a text file or spreadsheet.

**Keeping it fair.** Every raid, sign-up and DKP change is kept in a shared record that's never edited, only added to. Only officers can create raids or change DKP. An officer's change is only accepted straight from that officer or passed along by another officer, so nobody can add fake DKP. Members catch up on changes they missed whenever an officer is online.

## Shared history

Each person's addon records events while they're online. When you log in, your addon asks the guild for anything from the last two days that you missed, and one online guildmate sends it to you privately, a few entries a second. Events you already have are skipped, and shared history never sets off alerts. History is only accepted from guild members.

## The Wanted list

An enemy player becomes wanted after killing guild members in world PvP a set number of times in the last 30 days (3 by default; change it in PvP > Wanted). When a guildmate's addon sees a wanted player on their target, focus, mouseover or nameplates, the guild gets an alert and the spot is marked on the map with a purple diamond for 30 minutes. The same player is reported at most once every 10 minutes. Right-click someone in PvP > Wanted to hide them from your own list.

When a guild member kills a wanted player, the bounty is claimed: the kill alert says so, and they drop off the list. Only guild deaths after that kill count toward them, so they come back if they keep ganking. Untick "Remove from the list when a guild member kills them" at the bottom of PvP > Wanted to keep them listed instead.

## Clearing logs

Only the Guild Master can clear the Kills and Officer logs. A clear removes everything in that log up to that moment for the whole guild, and old entries can't come back through shared history. Guildmates who were offline get the clear the next time they catch up with an officer online.

## Quiet mode

In Settings, "Hold alerts in dungeons and raids" is on by default and "Hold alerts during combat" is off. Held alerts are listed together in chat once you're out.

## How PvP kills are detected

The addon can't see killing blows, so a kill counts for you only if you actually attacked that enemy player in the last 10 seconds before they died: you cast a harmful spell while they were your target, you were auto-attacking or shooting them, or your pet was attacking them. Being in a party that gets honor for the kill, targeting the enemy, or being attacked by them isn't enough.

**Killing blows and assists.** Each guild member who took part reports how long before the death they last hit the victim. Whoever hit last gets the killing blow; everyone else gets an assist. It's a best guess, since the exact blow can't be seen, but it's close. Top Head Hunters ranks by killing blows, with assists shown next to them.

**No grey kills.** Kills of players at a grey level (far below the killer's) are never announced or logged, so farming low-level players doesn't climb the leaderboard.

**Removing bad kills.** Officers can right-click a kill in PvP > Kills to remove it for the whole guild. It stays removed for everyone, including guildmates who were offline at the time.

Healers who only healed don't get credit, since healing isn't an attack.

## Good to know

- Raid deaths and battleground kills are turned off by default for each person, since they can send a lot of alerts. Turn them on in **Alert Settings** if you want them.
- The officer log records what happens while you're online. Each person has their own copy.
- The guild tools window closes when you enter combat and reopens when combat ends. The game doesn't allow its guild action buttons to be used in combat.
- The Officers section only appears for officers. The text of edited notes is never shared, only that a note was changed.

## For officers

- Buttons in Guild > Roster only work for actions your guild rank already allows. The game server checks every action, so the addon can't give anyone extra powers.
- Who counts as an officer in Warcrest (the Officers section, scheduling raids, guild settings): the Guild Master, the rank directly below, and every rank that can read officer chat in the game's guild control. The Guild Master can change this in Settings > Alerts.
- Settings reach everyone who is online when you save. Members who log in later get the current settings from any online officer.
- **Guild > Who has Warcrest** shows who has the addon and who needs to update. Click **Check now** to ask everyone online.

## More help

The [wiki](https://github.com/fantasyglassui/Imperium-Guild-Tools/wiki) has step-by-step guides for members and officers. Found a bug or have an idea? [Open an issue](https://github.com/fantasyglassui/Imperium-Guild-Tools/issues/new/choose).

## Contributing

Every change is checked automatically by luacheck and a test suite that runs the addon outside the game. See [CONTRIBUTING.md](CONTRIBUTING.md) for where things live in the code, how to run the tests yourself, and how releases work.

## License

Copyright (c) 2026 Fantasy Glass UI.

The code is released under the [MIT License](LICENSE).

The **Warcrest** name and crest emblem, and the emblem and artwork of **<The Imperium>** (in `Media/` and `Media/Imperium/`), are not covered by the MIT License. Please don't use them for your own addons or projects, or to suggest that a project is Warcrest or made by its authors.

## Credits

The interface uses the [Inter](https://rsms.me/inter/) typeface by Rasmus Andersson, included under the SIL Open Font License (see `Media/Fonts/LICENSE-Inter.txt`).
