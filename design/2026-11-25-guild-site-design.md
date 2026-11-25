# Warcrest guild site

*Design, 25 November 2026. Waiting for the author's approval.*

## Why
Warcrest grows a guild at a time. A public page for each guild, with realm boards that guilds compete on, gives officers something to share (every share is a link to warcrest-addon.com) and gives players a reason to look at the site. It's the same idea as Forever Guilds (forever-guilds.web.app), in Warcrest's own look, with its own boards and wording.

## Goals
1. **Guild pages** at warcrest-addon.com/guilds/: name, faction, ruleset (PvP or PvE), crest colours, members, level spread, classes, number at 60, raid and dungeon progress from members' boss kills, the guild's achievements, recent activity, and a "Uses Warcrest" badge.
2. **Player pages**: level, class, guild, gear item level, boss kills, achievements, reputations, professions.
3. **Boards** (per ruleset and overall):
   - **Race to 60**: the first players to reach 60, and the guilds with the most 60s.
   - **Raid firsts**: the first guild to kill each raid boss and to clear each raid.
   - **Progress**: raid and dungeon bosses killed, harder content worth more.
   - **Gear**: average item level of each guild's top members.
   - **Most active**: members seen playing in the last 7 days.
4. **Firsts feed**: the latest firsts across the game (first to 60, first kills).
5. **Search**: guilds and players by name.
6. **Adding guilds**: The Imperium to start, then any guild that asks.

## Non-goals and anti-goals
- **The add-on never sends anything on its own.** WoW blocks it anyway, and Warcrest's rule is no tracking. Everything on the site comes from Blizzard's public API or from what an officer chooses to submit.
- No sign-in, no comments, no paid hosting, no ads.
- Nothing that isn't already public on Blizzard's armory (no notes, DKP or officer data).
- Not copying another site's text, design or scoring.

## Constraints (checked on 25 November 2026)
- Blizzard's API answers for WoW: Forever, unofficially: namespaces `profile-forever-us`, `dynamic-forever-us`, `static-forever-us`.
  - `/data/wow/guild/{slug}` and `/data/wow/guild/{slug}/roster` work (The Imperium: 81 members).
  - Rulesets 1, 2, 3 and 15 in the US (1 is PvP). Guilds and characters have no realm; characters are `First-Surname` slugs.
  - The dungeon and raid list (journal) is empty, so progress comes from each character's boss kills.
  - Characters only appear from level 10 and after logging out.
  - It can change without notice: the site shows the last good data and hides a section whose data is missing.
- The keys live only in GitHub secrets (`BLIZZARD_CLIENT_ID`, `BLIZZARD_CLIENT_SECRET`).
- The site stays static on GitHub Pages; Blizzard allows about 36,000 calls an hour and 100 a second.

## Approaches
1. **A scheduled GitHub job and static data (chosen).** Every hour a GitHub Actions job asks Blizzard about every known guild and its members, works out the boards, and publishes JSON files with the site. Free, no new accounts, nothing to keep running. Hourly, not live.
2. A Cloudflare worker and database: faster and could take forms directly, but needs a new account and a DNS change. Kept for later if the site outgrows approach 1.
3. Firebase: its scheduled jobs need a paid plan.

## Adding guilds (the author asked for guilds that use the add-on)
The add-on can't tell the site it's installed, so:
- **In the add-on:** officers get **Put our guild on warcrest-addon.com** (Guild > Who has Warcrest). It shows a link to copy, with the guild's name and ruleset filled in, to a short GitHub form. The job checks the guild exists on Blizzard's API and adds it within the hour, with the "Uses Warcrest" badge (it came from the add-on).
- **On the site:** "Missing a guild?" goes to the same form (without the badge), or the Discord.
- **Guilds we already know:** The Imperium to start.
- Removal: a guild leader asks on Discord, or the author removes it from the list file.

## Data job (details left to the builder)
- `tools/guilds/` (Python): sign in, fetch guilds, rosters and member profiles (boss kills, equipment summary, achievements, reputations, professions), only for members changed since the last run (by `last_login_timestamp`), within Blizzard's limits.
- Keeps first-seen dates (first to 60, first kills) in a small history file, since Blizzard only gives the current state.
- Writes `docs/data/` (an index for search and boards, one file per guild and per player) on a `site-data` branch published with Pages, so data commits don't fill the main history.
- The pages are plain HTML and JavaScript in the existing site's style, in English first (the other languages after the data settles).

## Guild rep (the add-on, separate update)
Rep is earned only by playing (officers can't hand it out): grouping or raiding with guildmates, guild events, kills with guildmates, crafting orders filled. Ranks Neutral to Exalted show on player cards and the roster. It's in the add-on, so on the site it only shows if an officer publishes it later; it isn't part of this design.
