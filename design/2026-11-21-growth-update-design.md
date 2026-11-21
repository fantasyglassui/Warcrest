# Warcrest: the growth update

*Design, 21 November 2026. Status: waiting for approval.*

## Why

The goal is to get Warcrest to **more than 1,000 people**, mainly by making it easier to find outside the guilds that already use it.

Warcrest spreads a guild at a time. Nearly everything it does (kills, raids, DKP, polls, profiles, crafters) depends on guildmates also having it. A player who installs it alone gets little out of it. So the person to win over is the **guild leader or officer**, who brings 20 to 50 members at once. In practice, 1,000 people means a few dozen guilds using it, not 1,000 lone downloads.

At the moment:
- Warcrest is listed only on CurseForge (project 1803056).
- It has a website (warcrest-addon.com) in English, German, French and Spanish, a wiki and a Discord.
- New WoW Forever players find add-ons mostly through "best WoW Forever add-ons" round-ups (Icy Veins, Mobalytics, Overgear, Skill Capped, the CurseForge blog), the Blizzard WoW Forever forums, Reddit and Discord. The round-ups lean toward personal UI add-ons, and guild tools barely appear in them.

## Goals

1. **Ready for strangers:** a leader who installs Warcrest in a guild where nobody else has it can see, within a few minutes, what it will look like once the guild is on it, and knows exactly how to roll it out.
2. **It spreads itself:** inside a guild, getting the rest of the members to install it takes one click from an officer. Members can pass it on easily.
3. **Get it out there:**
   - Warcrest is on CurseForge, Wago and WoWInterface, all updated by every release.
   - There are ready-to-publish posts for the Blizzard forums, Reddit and Discord, and pitches to the round-up writers.
4. **Success:** more than 1,000 total downloads across the add-on sites, and new guilds showing up (Discord joins, contact-form messages, CurseForge comments).

## Non-goals

- New guild features (more raid or PvP tools). This update is about reach, not scope.
- Supporting retail WoW or other game versions. **Warcrest stays WoW Forever only.**
- Paid promotion or ads.

## Anti-goals (fail even if it works)

- **No spam.**
  - Warcrest never whispers, posts in chat or advertises on its own.
  - Every message a player sends about Warcrest is one they chose to send, and they see the text first.
  - Nothing goes to people outside the guild unless the player sends it themselves.
- **No tracking.** No telemetry and no phoning home. We measure success from public download counts and the guilds that get in touch.
- **No nagging.** Reminders to install or invite show at most once and can be dismissed for good. Warcrest must not feel like an ad inside the game.
- **Nothing published without the author.** Every forum post, Reddit post, Discord message and email is written by Claude and approved by the author before it goes out, under the author's own accounts.

## Constraints

- WoW Forever runs on the mainline 12.x API. Links in chat can't be clicked, so the website address has to be shown in a box the player can copy (Ctrl+C).
- Chat sends must respect the chat lockdown (`ns.ChatLocked`, `ns.HoldCountdown`).
- Every new string needs German, French and Spanish translations, made with the existing tools in /tmp/claude-0/loc.
- **The Imperium keeps its own look.**
- Account creation and sign-ins (Wago, WoWInterface, Reddit, forums) are done by the author; Claude can't create accounts or enter passwords.
- Releases: the author publishes the GitHub release; the release workflow (BigWigs packager) uploads to CurseForge.
- This spec lives in `design/`, not `docs/`, because `docs/` is the public website.

## Approaches considered

1. **Outreach only:** list Warcrest on more sites and post about it, with no add-on changes. It's quick, but new leaders land in an add-on that looks empty until their guild joins, and many leave.
2. **Spreading from inside the game only:** fills existing guilds, but nobody outside them hears about Warcrest.
3. **Both, in three steps (chosen):** first make it ready for strangers, then make it spread itself, then get it out there. The first two make the third pay off. The author chose this.

## What gets built

### Step 1: Ready for strangers

**A tour in the welcome window.**
- The first page of the welcome window (UI/Welcome.lua) gets a short picture tour: four or five screenshots of the main pages filled with an example guild, each with one line of text.
- The pictures are the website's tour shots, scaled down and shipped in `Media/Tour/`.
- The tour stays reachable from Help ("See it in action").
- *Claude's call:* pictures, not a live example mode. A live mode would put fake data next to real guild data in the saved variables and in the shared sync; pictures can't leak.

**Empty pages explain themselves.**
- When a page is empty because nobody else in the guild has Warcrest yet, it says so and offers what to do, instead of a bare "nothing here".
- Pages affected: Kills, Wanted, Standings, Profiles, Crafters, Polls, Who has Warcrest.
- Example: "Kills show up when guildmates with Warcrest kill or die in PvP. 1 of 34 members has Warcrest. [Invite the guild]".

**Getting started for a lone installer.**
- If the player is the only one in the guild with Warcrest, Getting started adds a first step:
  - officers see "Invite your guild";
  - members see "Tell your officers", with a ready message to copy.

**A "For guild leaders" part on the website.**
- It goes on the home page, near the top, in all four languages.
- It gives a 30-second pitch, then three steps to roll it out:
  1. install it;
  2. run the setup;
  3. post the message in guild chat.
- It includes a short looping animation of the main window (an animated WebP, made from the rendered screens).
- The CurseForge description (Warcrest-description.md) gets the same pitch at the top.

### Step 2: It spreads itself

**"Invite the guild" in Guild > Who has Warcrest** (officers and the guild leader).
- Opens a small window with a ready message for guild chat, for example: "Our guild uses Warcrest for raids, DKP and PvP. Get it on CurseForge or warcrest-addon.com (search 'Warcrest')."
- The officer can edit the message, then click **Post in guild chat**.
- It posts once, through the normal send queue, and is held during chat lockdown.
- After posting, the button shows when it was last used, so officers don't post it twice the same day.
- Members without Warcrest also show in the list with a "Copy invite" option for a personal whisper. The officer types or pastes the whisper themselves; Warcrest never sends whispers.

**"Share Warcrest"** (everyone).
- Lives in Help and on the Home page footer, and is opened with `/warcrest share`.
- Opens a copy box with a one-line description and the website address, in the player's language, to paste anywhere (a whisper, a Discord, another guild).

**Gentle reminder for officers.**
- When fewer than half of the guild's active members (online in the last 14 days) have Warcrest, an officer sees one card on Home: "12 of 34 active members have Warcrest. Invite the rest."
- It can be dismissed for good per character, and comes back only if the count drops again by 5 or more.

**Not included:** automatic messages to other guilds or players nearby. This is an anti-goal.

### Step 3: Get it out there

**More add-on sites.**
- Add Wago and WoWInterface listings. The BigWigs packager already supports both: the TOC gets `X-Wago-ID` and `X-WoWI-ID`, and the workflow gets `WAGO_API_TOKEN` and `WOWI_API_TOKEN`.
- The author creates the accounts and the projects and adds the tokens as GitHub secrets; Claude prepares everything else and shows the author where each value goes.
- **First check (builder):** whether Wago and WoWInterface list WoW Forever add-ons at all, and under which game version. If one doesn't, skip it and say so.

**CurseForge page.**
- Lead with the guild-leader pitch.
- Check the categories and tags (Guild, Raids, PvP, DKP) and the summary line.
- The screenshots are already current.

**Posts, all drafted by Claude and approved one by one by the author before posting:**
- Blizzard forums, WoW Forever section, US and EU: one "Warcrest: free guild tools for WoW Forever" post. Plus a reply template for guild recruitment threads, only where the author is already taking part.
- Reddit: one post for the WoW Forever community (the right subreddit to be found and checked against its self-promotion rules first).
- Discord: a short announcement for the Warcrest Discord, and a version the author can share in communities they belong to.
- Pitches by email or contact form to the round-up writers: Icy Veins, Mobalytics, Overgear, Skill Capped and the CurseForge blog. Each pitch is short and has a screenshot, the guild-leader angle, and why their readers would care.

**Timing:** the posts go out after the update with steps 1 and 2 is released, so new readers land on the new first-run experience.

## Release

- Steps 1 and 2 ship as one add-on release.
  - Version 4.2.0 (*Claude's call*: it adds features without changing how existing ones work).
  - It includes a What's new entry and a CHANGELOG section.
- The website changes go out with it.
- Step 3 starts after the release and is mostly outside the code. The Wago and WoWInterface upload lines in the release workflow can land in the same release or the next one, whenever the author has the tokens.

## Left to the builder

- The exact text of every new message and button. It should be plain and short, match the add-on's existing tone, and be translated.
- Picking the tour screenshots and their order.
- How "active member" is counted (last online within 14 days, from the roster).
- The layout of the invite window and the copy box (follow the existing UI helpers, UI.Window and UI.Code).
- The order of work within each step.
- Tests for each new behaviour, in the existing pytest and lupa harness. The main points to cover:
  - the invite posts only on click;
  - the invite is held during lockdown;
  - the reminder respects dismissal;
  - nothing is sent automatically.
