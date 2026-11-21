# Growth Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Warcrest easy for a new guild to discover, try and roll out (add-on 4.2.0 + website), then list it on more add-on sites and prepare outreach posts.

**Architecture:**
- One new Lua module, `Guild/Spread.lua`, holds the logic:
  - counts of who has Warcrest;
  - the invite and share texts;
  - the one guild-chat post;
  - the reminder state.
- One new UI module, `UI/Spread.lua`, holds the copy box, the invite window and the share window.
- Existing pages call into these.
- The welcome tour ships as TGA pictures made from the website's screenshots.
- Website and outreach work happens outside the add-on.

**Tech Stack:** Lua 5.1 (WoW Forever, mainline 12.x API); pytest + lupa harness (`tests/harness.py`); Python tools for the translations (/tmp/claude-0/loc), the site (`tools/site/build.py`) and images (Pillow).

**Spec:** `design/2026-11-21-growth-update-design.md`

## Global Constraints

- **No spam:** Warcrest never sends chat or whispers on its own. A chat line goes out only after the player clicks **Post in guild chat**. Whispers are never sent by Warcrest.
- No telemetry or phoning home.
- Reminders show at most once and can be dismissed for good; they come back only if the count drops again by **5 or more**.
- "Active member" means online now, or `m.offlineDays <= 14` (from `ns.GetRoster()`).
- The reminder shows when fewer than **half** of active members have Warcrest.
- Chat sends go through `ns.SendChat` (held during lockdown); a guild-chat line is at most **255** characters.
- Every new player-facing string gets German, French and Spanish translations (fix.py/add*.py, then `python3 gen.py`).
- **The Imperium keeps its own look.**
- **WoW Forever only.**
- Version **4.2.0**.
- Commits are made as `Fantasy Glass UI <fantasyglassui@gmail.com>`, with no attribution lines.
- Every public post, email and listing is approved by the author before it goes out. The author creates all accounts and tokens.
- The tour pictures are power-of-two TGA files at **512x256**, in `Media/Tour/`, adding about 2.5 MB at most.

## Review Focus

1. **Roster not loaded yet** (`GetRoster()` is empty): counts must give 0 of 0, no reminder, and no divide-by-zero. The test goes in Task 1.
2. **An officer edits the invite to more than 255 characters, or types `|`:** the edit box is limited to 255 characters, and `|` is escaped to `||` before sending, so the post can't break or inject chat links. Test in Task 1.
3. **Posting during a boss fight (chat lockdown):** the line is held, sent once when the fight ends, and the "last posted" time is still recorded once. Test in Task 1.
4. **A member who isn't an officer** reaches the invite window (for example through `/warcrest invite`): they get the copy box only, never a Post button, and `ns.PostGuildInvite` refuses. Tests in Tasks 1 and 2.
5. **The reminder is dismissed, then two new members without Warcrest join:** it stays hidden; it comes back only once 5 or more more active members are missing. Test in Task 3.

---

### Task 1: Spread logic (`Guild/Spread.lua`)

**Files:**
- Create: `Guild/Spread.lua` (add to `Warcrest.toc` after `Guild\Guild.lua`)
- Test: `tests/test_spread.py`

**Interfaces:**
- Produces:
  - `ns.WarcrestCount() -> have, active, total` (numbers). `have` counts active members whose status in the Who has Warcrest rows is yes or old; reuse that logic by moving `rows()` from `UI/Tabs/AddonUsers.lua` to `ns.AddonUserRows()` in this file.
  - `ns.AddonUserRows() -> rows, newest` (moved as-is).
  - `ns.InviteText() -> string`: translated, ≤255 characters, mentions CurseForge and `warcrest-addon.com`.
  - `ns.ShareText() -> string`: translated, one line, for pasting anywhere.
  - `ns.CanInvite() -> bool`: officer or guild leader (`ns.IsOfficer()`).
  - `ns.PostGuildInvite(text) -> ok, why`. Refuses with `"officer"` if `not ns.CanInvite()`. Otherwise it escapes `|`, trims to 255, calls `ns.SendChat(text, "GUILD")`, and sets `ns.db.invite.last = time()`.
  - `ns.LastInvite() -> number|nil`.
  - `ns.ShouldNudge() -> bool`: true when the player is an officer, `have < active/2`, and either it hasn't been dismissed or `active - have >= ns.db.invite.dismissedMissing + 5`.
  - `ns.DismissNudge()`: stores `ns.db.invite.dismissedMissing = active - have`.
  - `ns.AloneInGuild() -> bool`: true when `have <= 1` and `active > 1`.

- [ ] **Step 1: Write the failing tests** in `tests/test_spread.py` (use `Guild(M)` from the harness, as test_crafters does):
  - `test_counts_who_has_warcrest`: in a 6-member guild where 2 have Warcrest, `WarcrestCount()` returns `(2, 6, 6)`. A member with `offlineDays = 30` drops out of `active`.
  - `test_counts_with_empty_roster`: with the roster stubbed empty, it returns `(0, 0, 0)`, and `ShouldNudge()` is False.
  - `test_invite_posts_only_when_asked`: after load and 60 s of `guild.run`, `chatSent` has no GUILD line from Warcrest. After `PostGuildInvite(InviteText())`, exactly one GUILD line is sent and `LastInvite()` is set.
  - `test_invite_refused_for_members`: a non-officer gets `PostGuildInvite` returning `(False, "officer")`, and nothing is sent.
  - `test_invite_escapes_and_trims`: given 300 characters containing `|cff`, the sent text is ≤255 characters and contains `||cff`, not `|cff`.
  - `test_invite_held_in_lockdown`: with lockdown on (the `forever.lua` chatLockdown emulation), the post returns `held` and nothing is sent. After lockdown ends, exactly one line is sent.

- [ ] **Step 2: Run** `python3 -m pytest tests/test_spread.py -q`. Expected: it FAILS (no module yet).

- [ ] **Step 3: Implement `Guild/Spread.lua`** with the interfaces above. Move `rows()` from AddonUsers.lua and call `ns.AddonUserRows()` there. `ns.db.invite` defaults to `{}`.

- [ ] **Step 4: Run** the new tests plus `tests/test_load.py` and `tests/test_lockdown.py`. Expected: PASS.

- [ ] **Step 5: Commit** "Spread: counts, invite and share texts, one guild-chat post".

### Task 2: Copy box, invite window, share window and commands

**Files:**
- Create: `UI/Spread.lua` (TOC, after `UI\Widgets.lua`)
- Modify:
  - `UI/Help.lua` (use `UI.CopyBox` instead of its local `copyBox`; add a **Share Warcrest** button next to the website box, which calls `ns.ShowShare()`);
  - `UI/Tabs/AddonUsers.lua` (an "Invite the guild" button in `page.headerBar`, officers only; for rows with status `no`, a right-click "Copy invite" opens the share window with the invite text);
  - `Core/Core.lua` (slash commands `share` and `invite`, plus Commands help lines).
- Test: `tests/test_spread.py`

**Interfaces:**
- Consumes: everything Task 1 produces.
- Produces:
  - `UI.CopyBox(parent, width, text) -> editbox`: read-only, selects all on focus. This is Help.lua's behaviour moved here.
  - `ns.ShowInvite()`: a window, `WarcrestInvite`, containing:
    - a multi-line edit box holding `ns.InviteText()` (`SetMaxLetters(255)`);
    - **Post in guild chat** (only if `ns.CanInvite()`), which calls `ns.PostGuildInvite` and then closes;
    - a label "Last posted: <time ago>" when `ns.LastInvite()` is set;
    - for non-officers, the same text in a `UI.CopyBox` with the hint "Copy this and send it to your officers."
  - `ns.ShowShare(text)`: window `WarcrestShare`, a `UI.CopyBox` holding `text or ns.ShareText()`.
  - `/warcrest share` calls `ns.ShowShare()`; `/warcrest invite` calls `ns.ShowInvite()`.

- [ ] **Step 1: Write the failing tests:**
  - `test_invite_window_officer_and_member`: an officer's `ShowInvite()` shows the Post button. A member's shows no Post button, and `WarcrestInvite` contains the copy box.
  - `test_share_command`: `/warcrest share` shows `WarcrestShare`, and its box text equals `ShareText()`.
  - `test_no_send_on_open`: opening either window sends nothing.

- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement** the interfaces above, and add "Invite the guild" in Who has Warcrest (it calls `ns.ShowInvite`).
- [ ] **Step 4: Run** `tests/test_spread.py tests/test_render.py -k "addon or help"` plus `tests/render.py` (check `panel-addon.png` in en and de). Expected: PASS, and the header button doesn't collide with the search box.
- [ ] **Step 5: Commit** "Invite and share windows; Invite the guild in Who has Warcrest; /warcrest share and invite".

### Task 3: Home reminder card and the Getting started step for a lone installer

**Files:**
- Modify: `UI/Tabs/Home.lua` (a card above the others when `ns.ShouldNudge()`: "%d of %d active members have Warcrest. Invite the rest.", with buttons **Invite** → `ns.ShowInvite` and **Hide** → `ns.DismissNudge`; also a "Share Warcrest" link in the footer → `ns.ShowShare`).
- Modify: `UI/GettingStarted.lua`: when `ns.AloneInGuild()`, a first step `invite`. Officers see the title "Invite your guild"; members see "Tell your officers". Both open `ns.ShowInvite()`. The step counts as done once `ns.LastInvite()` is set or `have > 1`.
- Test: `tests/test_spread.py`, `tests/test_home.py`

- [ ] **Step 1: Write the failing tests:**
  - `test_nudge_card_shows_and_hides`: an officer with 2 of 6 active members sees the Home card. After `DismissNudge()`, the card is hidden.
  - `test_nudge_returns_after_five_more`: after dismissing at 4 missing, adding 2 members without Warcrest keeps it hidden. Adding 5 more (9 missing in all) shows it again.
  - `test_members_never_see_nudge`: a non-officer never sees the card.
  - `test_alone_step`: a lone officer sees the `invite` step first. Once the post has gone out, the step is done.

- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `tests/test_spread.py tests/test_home.py tests/test_setup.py`, plus renders of `panel-home.png` (en and de). Expected: PASS, and the card fits at the minimum window size.
- [ ] **Step 5: Commit** "Home: invite reminder for officers; Getting started: invite step when you're alone".

### Task 4: Empty pages explain themselves

**Files:**
- Modify: `Guild/Spread.lua`: add `ns.EmptyHint(text) -> string`. While `ns.AloneInGuild()` or `have < 3`, it appends "\n\n" and "%d of %d members have Warcrest. Officers can invite the rest from Guild > Who has Warcrest." Otherwise it returns `text` unchanged.
- Modify the `SetEmptyText` calls in:
  - `UI/Tabs/KillLog.lua:75`
  - `UI/Tabs/Wanted.lua:88`
  - `UI/Tabs/DKP.lua:155`
  - `UI/Tabs/Profiles.lua:224`
  - `UI/Tabs/Crafters.lua:279` (only the non-search branch)
  - `UI/Tabs/PollsView.lua:183`
  - `UI/Tabs/WarView.lua:171`
  
  Each wraps its text in `ns.EmptyHint(...)`. Search-result empties ("Nobody matches...") stay as they are.
- Test: `tests/test_spread.py`

- [ ] **Step 1: Write the failing test** `test_empty_hint_only_when_few_have_it`. With 1 of 6, `EmptyHint("x")` contains "1 of 6". With 4 of 6, it equals `"x"`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement** and wire up the seven pages.
- [ ] **Step 4: Run** the full `tests/test_render.py` (the text must fit every page in en, de, fr, es). Expected: PASS.
- [ ] **Step 5: Commit** "Empty pages say how many have Warcrest and how to invite the rest".

### Task 5: The welcome tour

**Files:**
- Create: `tools/tour_images.py`. It reads `docs/img/{home,kills,raids,dkp,profiles}.webp`, scales each to 512x256 (fit within, padded with the panel's background colour), and writes `Media/Tour/{name}.tga`, uncompressed 32-bit TGA.
- Create: `Media/Tour/*.tga` (5 files, generated).
- Modify:
  - `UI/Welcome.lua`: page 1 becomes "What Warcrest does" with the tour (picture 480x240, a caption, ‹ › buttons, dots).
  - `UI/Help.lua`: a topic button "See it in action", which calls `ns.ShowTour()` and opens the welcome window at page 1.
- Produces: `ns.ShowTour()`.
- Captions (one line each, translated):
  - Home: "Everything happening in your guild, on one page."
  - Kills: "Every PvP kill and death, with a monthly leaderboard."
  - Raids: "Sign up for raids by role; officers see who's coming."
  - Loot: "DKP, live loot auctions and wishlists, shared by everyone."
  - Profiles: "Specs, roles, item levels and when people play."
- Test: `tests/test_setup.py`

- [ ] **Step 1: Write the failing test** `test_tour_pages`. `ShowTour()` shows the welcome window on page 1, the picture's texture path ends with `Media\\Tour\\home`, and clicking › five times wraps back to home.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Run `python3 tools/tour_images.py` and check the files are 512x256 and add up to 2.5 MB or less (`du -ch Media/Tour/*.tga`).
- [ ] **Step 4: Run** `tests/test_setup.py tests/test_render.py`, plus a render of the welcome window (en and de). Expected: PASS, and captions fit on one or two lines.
- [ ] **Step 5: Commit** "Welcome: a picture tour of Warcrest; Help: See it in action".

### Task 6: Release 4.2.0

**Files:**
- `Warcrest.toc` (version 4.2.0)
- `UI/Updates.lua` (CHANGES entry, translated)
- `CHANGELOG.md` (`## 4.2.0`)
- `README.md` (the invite and share commands)
- `wiki/Commands.md` and `wiki/Getting-Started.md`
- `Locales/*` (gen.py)

- [ ] **Step 1:** Translate all new strings: `extract.py` diff against all.json, add them with a new add*.py, then run `python3 gen.py`. Verify with `python3 /tmp/claude-0/loc/unused.py` (no new unused keys) and that `tests/test_locale.py` passes.
- [ ] **Step 2:** Bump the version, and write the What's new and CHANGELOG entries.
- [ ] **Step 3:** Run the full suite twice: `python3 -m pytest -q`, then `WARCREST_REALM_SPACE=1 python3 -m pytest tests -q --ignore=tests/test_render.py`. Expected: all pass.
- [ ] **Step 4:** Commit, push `next` and `next:main`, and package the zip and changelog to the outputs folder (removing the old ones).
- [ ] **Step 5:** The author publishes the v4.2.0 release. If the author asks, open the GitHub new-release page in the browser pane and publish it there. Check that "Package and release" passes and CurseForge shows v4.2.0-forever with only its own notes.

### Task 7: Website "For guild leaders", the animation, and the CurseForge description

**Files:**
- `docs/index.html` (a new section `#leaders` after the hero: a 30-second pitch, three steps "Install it / Run the setup / Post the message in guild chat", the animation, and a nav link)
- Create: `tools/site/anim.py` (renders a 6-frame loop with `tests/render.py`'s demo guild, `WARCREST_GUILD="Ashen Vanguard"`: Home → Kills → Raids → Loot → Profiles → Crafters, 2 s each, 1000x628; writes `docs/img/tour.webp` as an animated WebP, 1.5 MB or less)
- `tools/site/i18n/{de,fr,es}.json`
- `/mnt/user-data/outputs/Warcrest-description.md` (the same pitch at the top)

- [ ] **Step 1:** Write `anim.py` and generate `tour.webp`. Check its size and that it loops.
- [ ] **Step 2:** Add the section to the page. Run `python3 tools/site/build.py --missing` and add the translations until there are 0 missing. Then run `--prune`.
- [ ] **Step 3:** Check the page with Playwright at 1280 wide and at phone width (375): no console errors, no horizontal scroll, and the animation plays. Do this for en and de.
- [ ] **Step 4:** Update Warcrest-description.md. Paste it into the CurseForge Description tab through the built-in browser (authors.curseforge.com, the Description editor in Markdown mode), after the author OKs the text.
- [ ] **Step 5:** Commit and push (the site deploys from main).

### Task 8: Wago and WoWInterface

**Files:** `Warcrest.toc`, `.github/workflows/release.yml`

- [ ] **Step 1:** Check whether Wago Addons and WoWInterface list WoW Forever add-ons, and under which game version (web search and their upload pages). Report to the author. Skip any site that doesn't support Forever.
- [ ] **Step 2:** For each supported site, the author creates the account and the project, and the author adds its token as a GitHub secret (`WAGO_API_TOKEN`, `WOWI_API_TOKEN`). Give the author the exact page and field names for each.
- [ ] **Step 3:** Add `## X-Wago-ID: <id>` / `## X-WoWI-ID: <id>` to the TOC. Add `WAGO_API_TOKEN: ${{ secrets.WAGO_API_TOKEN }}` and `WOWI_API_TOKEN: ${{ secrets.WOWI_API_TOKEN }}` to the packager step's `env`.
- [ ] **Step 4:** Commit and push. The next release uploads everywhere: check each site shows it after the release.

### Task 9: Outreach drafts and publishing

**Files:** Create `design/outreach/`:
- `forums-us.md` and `forums-eu.md` (one post each: "Warcrest: free guild tools for WoW Forever");
- `guild-reply.md` (a short reply for recruitment threads the author already takes part in);
- `reddit.md` (after finding the right subreddit and checking its self-promotion rules; the rules go at the top of the file);
- `discord-own.md` and `discord-share.md`;
- `pitch-icy-veins.md`, `pitch-mobalytics.md`, `pitch-overgear.md`, `pitch-skill-capped.md`, `pitch-curseforge-blog.md` (each with the contact route found on that site).

- [ ] **Step 1:** Research each site's contact route and each community's rules (web search). Record them at the top of each file.
- [ ] **Step 2:** Write each draft with the guild-leader angle. Keep it short and specific (what it does, why a guild leader cares, one screenshot or the tour link), with no hype words.
- [ ] **Step 3:** Commit to `next` only; `design/` isn't packaged or published.
- [ ] **Step 4:** Send the drafts to the author as one document to review. Publish only the ones approved, one at a time, through the built-in browser under the author's signed-in accounts. The author does any sign-in. Report each link after it's posted.
- [ ] **Step 5:** A week later, check CurseForge, Wago and WoWInterface download totals against the 1,000 goal and report to the author.
