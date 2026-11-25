--[[
  Warcrest
  Updates panel: after the addon is updated, shows what changed since the
  version you last used. Reopen it any time with /warcrest updates.

  To add a release: put a new entry at the TOP of CHANGES.
]]

local _, ns = ...
local UI = ns.UI

-- Newest first. Players see every entry newer than the version they last used.
local CHANGES = {
  { version = "4.4.0", date = "Nov 25, 2026", items = {
    "WoW: Forever guild boards at warcrest-addon.com/guilds: race to 60, raid progress, gear, activity and more, updated every hour from Blizzard's armory.",
    "Officers: Put us on the website (Guild > Who has Warcrest) gives a link that adds the guild to the boards with the Warcrest badge.",
  } },
  { version = "4.3.1", date = "Nov 25, 2026", items = {
    "Much less memory and lag in big guilds: achievements are worked out far less often and more cheaply, and pages make much less garbage when they redraw.",
    "Achievement progress shows thousands separators, and Who has Warcrest says \"Has it\" when a version isn't known yet.",
  } },
  { version = "4.3.0", date = "Nov 25, 2026", items = {
    "A fresh start: everything shared with the guild (kills, raids, DKP, loot, events, profiles, titles, achievements) is reset once for everyone. Your own settings and the guild's settings are kept.",
    "World buffs and world bosses (Events > World buffs): the guild hears when the Onyxia, Nefarian or Rend head or the Heart of Hakkar drops, and when a world boss is seen.",
    "Groups (Guild > Groups): post what you're doing and how many you need; guildmates ask to join with a click, and you invite them with a click.",
    "Profession cooldowns (Guild > Crafters > Cooldowns): who has a transmute, Mooncloth, Cured Rugged Hide or a Salt Shaker, and when each is ready.",
    "Raid check (on Raids): every raid member's flask, elixirs, food and world buffs before the pull, even without Warcrest.",
    "Officers > Inactive groups alts with their main, so nobody shows as away while they play an alt.",
    "Battleground and arena kills no longer count anywhere (kills, streaks, achievements, guild wars), and old ones are cleared out.",
    "Profiles and titles now reach guildmates who were offline when they changed, even when no officer is online.",
    "Less memory and less lag: Warcrest makes far less garbage while you play, and redraws its window at most a few times a second when a lot happens at once.",
    "157 new achievements, and the existing ones take a bit more to earn. Ones you've already earned stay earned.",
    "Clearer titles: no more look-alikes, and some new names (the Legendary is now the Deathless, Godlike's title is the Untouchable).",
    "More accessibility settings: 130% text, a choice of font, thicker letters, more space between lines, bigger banners, alerts read aloud, a flashing taskbar icon, and a key to open Warcrest.",
    "Organize the guild roster: sort by any column, and show only members with or without Warcrest, at level 60, or officers. Search also finds classes, zones and notes.",
  } },
  { version = "4.2.0", date = "Nov 21, 2026", items = {
    "Get your guild on Warcrest: officers have Invite the guild in Guild > Who has Warcrest, which shows the message first and posts it in guild chat only when you click Post. Warcrest never posts anything on its own.",
    "Share Warcrest (on Home, in Help, or /warcrest share): a short message to copy and send to a friend or another guild.",
    "The welcome window opens with a picture tour of Warcrest. See it again any time from Help > See it in action.",
    "Pages that are empty because few guildmates have Warcrest yet say so, and officers get one reminder on Home when fewer than half the active members have it.",
  } },
  { version = "4.1.0", date = "Nov 21, 2026", items = {
    "Profiles and Crafters are now views in the Guild section, next to Roster and Who has Warcrest, instead of separate windows. /warcrest profiles, craft and orders open them there.",
    "Help, tooltips and messages name the new sections and views (for example Loot > Standings or PvP > Kills) instead of the old tabs.",
  } },
  { version = "4.0.1", date = "Nov 21, 2026", items = {
    "A new logo, chosen by the guild: the crowned seal, with a W of two swords at its heart. It's on the minimap button, the side menu, the add-on list and the website.",
  } },
  { version = "4.0.0", date = "Nov 21, 2026", items = {
    "A new look, voted for by the guild: a side menu grouped into Guild, Raids & loot, PvP & glory and Officers, with related tabs joined into one section each (Loot: DKP and the wishlist; PvP: kills, the Wanted list, guild wars and bounties; Events: events, polls and the calendar).",
    "Home: what's happening in the guild on one page, with the next raid and your jobs in it, your DKP, the open poll (vote right there), PvP this week and guild news.",
    "Getting started sits above Settings and Help until you've done it, and Home shows your next step.",
  } },
  { version = "3.12.0", date = "Nov 20, 2026", items = {
    "Accessibility settings (Settings > Accessibility, or /warcrest access): bigger text, colour-blind friendly colours, high contrast, and alert banners that stay longer or until you dismiss them, with no sliding or fading.",
  } },
  { version = "3.11.0", date = "Nov 20, 2026", items = {
    "Getting started: a short checklist for new members that ticks itself off as you go (sign up for a raid, fill in your profile, share your recipes, pick a title). Officers set the guild up from it too. /warcrest start, or Help.",
    "Boss fights and PvP matches: the game blocks addon messages until they end. Warcrest now holds what it has to send (DKP, kills, pulls, bids, chat posts) and sends it when the fight is over, instead of losing it.",
    "Loot auctions and loot council votes pause while a boss fight blocks messages, and can't be started during one, so nobody misses the chance to bid.",
  } },
  { version = "3.10.0", date = "Nov 20, 2026", items = {
    "Settings moved to the bottom of the side menu, next to Help.",
    "The small The Imperium and Bannerhold folders aren't needed any more: you can delete them from your AddOns folder.",
    "Clean-up: Warcrest now uses only WoW: Forever's own game functions, and leftovers from removed features are gone.",
  } },
  { version = "3.9.3", date = "Nov 20, 2026", items = {
    "Fix: on WoW: Forever, guildmates' recipes weren't shared (the profession window is read the new way now), achievements weren't posted in guild chat, raid assignments couldn't be posted, the recruiting message couldn't be posted, and the raid warning alert style showed nothing.",
  } },
  { version = "3.9.2", date = "Nov 20, 2026", items = {
    "Fix: titles didn't show in chat on newer game clients.",
  } },
  { version = "3.9.1", date = "Nov 20, 2026", items = {
    "Fix: changes made while a guildmate was offline (profiles, recipes, guild settings and more) didn't reach them when they logged in, because the game writes names as \"Name Realm\".",
  } },
  { version = "3.9.0", date = "Nov 20, 2026", items = {
    "Fix: \"No player named ... is currently playing\" filling chat. Warcrest now whispers guildmates by a name the server knows, and not at all when they're offline.",
    "Kill streak alerts have names, from Killing Spree at 3 kills to Godlike at 20 and Beyond Godlike at 30, and the streak achievements and titles match them.",
    "Every rank that can read officer chat now counts as an officer in Warcrest (the Recruit and Officers tabs, raids, guild settings), with no setup. The Guild Master can turn this off in Settings.",
    "The calendar has its own tab on the left, under Events (/warcrest calendar).",
    "The world map no longer shows where the guild fights.",
  } },
  { version = "3.8.3", date = "Nov 20, 2026", items = {
    "Fix: the profile editor (Edit profile, /warcrest profile) didn't open and the crafters window was blank on newer game clients.",
  } },
  { version = "3.8.2", date = "Nov 20, 2026", items = {
    "Fix: solo kills showed you as your own assist (\"assist: Name Realm\"). Kills already logged are tidied up.",
  } },
  { version = "3.8.1", date = "Nov 20, 2026", items = {
    "Kill streak and revenge alerts now show the killer's title, like kill alerts do.",
  } },
  { version = "3.8.0", date = "Nov 20, 2026", items = {
    "Attunements: who's attuned for Molten Core, Onyxia, Blackwing Lair and Naxxramas, and who has the Upper Blackrock Spire and Scholomance keys (/warcrest attune). Sign-ups who aren't attuned are flagged.",
    "Raid assignments: officers write who does what on each boss and can post it to raid chat; you're told your job when the boss is pulled (/warcrest assign).",
    "Guild polls on the Events tab: ask a question, the guild votes (/warcrest polls).",
    "Crafting orders: click a recipe in the crafters window to ask a guild crafter to make it (/warcrest orders).",
    "Wipe tracking: wipes and the best kill time for each boss on Progress, and the raid hears when it beats its best.",
    "Officers: the Inactive view on the Officers tab lists who hasn't logged in lately (/warcrest inactive).",
    "The world map shows where the guild fights: where guild members killed enemy players or died to them this week.",
  } },
  { version = "3.7.3", date = "Nov 20, 2026", items = {
    "Bug reports: /warcrest report gives you a report to copy into the Discord or the website's contact form, with your version, settings and any errors.",
    "Officers setting up a guild now also choose which alerts the guild hears and whether achievements are posted in guild chat (/warcrest setup).",
    "The Warcrest Discord: /warcrest discord, or copy the invite from the help window.",
  } },
  { version = "3.7.2", date = "Nov 20, 2026", items = {
    "Fix: alerts and messages could show twice in chat, the second time with your realm after your name (\"Name-Realm\").",
    "When two guildmates spot the same wanted enemy at once, the sighting is shown once.",
  } },
  { version = "3.7.1", date = "Nov 19, 2026", items = {
    "Warcrest has a website: guides, every achievement, and a form to send bugs and ideas to the developer. Find the address in the help window (/warcrest website).",
    "Fix: the Wanted tab's view switch no longer leaves a gap when bounties are off.",
  } },
  { version = "3.7.0", date = "Nov 19, 2026", items = {
    "117 new achievements, 161 in all, with a new Social group and 42 more titles. Each group has pages: use the arrows or the mouse wheel.",
    "War board: the Wanted tab's Guilds view shows the score against every enemy guild. Officers mark rivals, and the guild is alerted when a group of them is spotted.",
    "Guild goals: officers set targets for the week or month on the Achievements tab (Guild view), and the guild hears when one is reached.",
    "Crafters: find who in the guild can make something and whisper them (Roster tab, or /warcrest craft).",
  } },
  { version = "3.6.5", date = "Nov 19, 2026", items = {
    "Alerts, chat messages and the remaining screen text are now in your language.",
    "Polish: Raids, Recruit, player card and Guild profiles.",
  } },
  { version = "3.6.4", date = "Nov 19, 2026", items = {
    "Faster in big guilds: every tab refreshes in a few milliseconds.",
    "Day and month names in dates are now in your language.",
  } },
  { version = "3.6.3", date = "Nov 19, 2026", items = {
    "Titles show in chat, in kill alerts and on the Kills tab.",
  } },
  { version = "3.6.2", date = "Nov 19, 2026", items = {
    "Achievements are posted in guild chat when you earn them, so everyone sees them (officers can turn this off).",
  } },
  { version = "3.6.1", date = "Nov 19, 2026", items = {
    "Fix: your own kills and achievements like First Blood count the moment they happen.",
  } },
  { version = "3.6.0", date = "Nov 19, 2026", items = {
    "New Events tab: PvP nights, world bosses, meetings and more. Anyone can plan one; guildmates answer and get reminded.",
    "Member profiles: your spec, when you play and your birthday, on your player card. Your item level is added automatically.",
    "Officers: a Recruit tab for recruits, trials and the recruiting message.",
    "/warcrest check shows why an achievement has or hasn't counted.",
  } },
  { version = "3.5.5", date = "Nov 19, 2026", items = {
    "Lost achievements come back once one officer, or two guildmates, have seen them earned.",
    "History saved under the older name Bannerhold is found and added back.",
  } },
  { version = "3.5.4", date = "Nov 19, 2026", items = {
    "Fix: kills were deleted after the killer levelled up, and the achievements that came from them went too. That's stopped.",
    "Achievements members lost are put back from what officers' addons remember.",
  } },
  { version = "3.5.3", date = "Nov 19, 2026", items = {
    "Your achievements are now kept with the guild too, so they come back even if this computer's saved data is lost.",
    "If Warcrest's saved history doesn't load, it says so and asks the guild to send it back.",
    "Achievements and titles update straight away, without a reload.",
    "Choose your title with the Title button on the Achievements tab: it lists every title and how to earn it.",
  } },
  { version = "3.5.0", date = "Nov 19, 2026", items = {
    "50 more alert sounds, 87 in all, sorted by kind in the sound picker (Settings > Sounds).",
  } },
  { version = "3.4.1", date = "Nov 19, 2026", items = {
    "Offline guild members count again everywhere, including player cards and achievements, and the player card names the guild.",
  } },
  { version = "3.4.0", date = "Nov 19, 2026", items = {
    "Choose the sound for each kind of alert in Settings > Sounds: 37 new Warcrest sounds, the game's sounds, SharedMedia sounds or your own files.",
  } },
  { version = "3.3.1", date = "Nov 19, 2026", items = {
    "Faster, especially in big guilds: catching up after time away, DKP awards and achievements no longer cause a hitch.",
    "The Alts window is redesigned, and the player card fits its contents.",
  } },
  { version = "3.3.0", date = "Nov 19, 2026", items = {
    "Raid night recap: when an officer ends the raid night, the whole guild gets a summary of the bosses, loot, attendance and the DKP you earned. /warcrest raidrecap shows the last one again.",
    "Help and What's new are now in German, French and Spanish too.",
  } },
  { version = "3.2.0", date = "Nov 18, 2026", items = {
    "Alert banners: guild alerts drop in at the top of the screen, with a colour, icon and sound for each kind. Click one to open its tab.",
    "Loot council: vote on who gets an item (/warcrest council, or the button on the Wishlist tab).",
    "Raid groups planner: the Raids tab's Plan view puts sign-ups into groups, and Arrange raid moves everyone into place.",
    "Bounties: officers can turn them on in Settings, then put a reward on a ganker's head.",
    "Warcrest now speaks German, French and Spanish (Settings > General > Language).",
  } },
  { version = "3.1.1", date = "Nov 18, 2026", items = {
    "Ready for raid launch: /warcrest bosses shows the last raid bosses that died and whether each counted for the guild (and why not).",
  } },
  { version = "3.1.0", date = "Nov 18, 2026", items = {
    "Raid progress: boss kills are recorded for the guild. The Raids tab's Progress view shows how far you've got in each raid, and guild first kills are announced.",
    "Raid calendar: the Raids tab's Calendar view shows the month's raids, raid nights and boss kills.",
    "22 new achievements, 43 in all, in four groups: PvP, Hunts, Raids, and Loot & more. 14 new titles to earn.",
    "A welcome and guild setup for new players and guilds, and guilds can now turn DKP off.",
    "Help: click Help at the bottom of the side menu, or type /warcrest help.",
    "Faster in big guilds, and lots of polish.",
  } },
  { version = "3.0.0", date = "Nov 18, 2026", items = {
    "The Imperium is now Warcrest, guild tools for any guild. Members of <The Imperium> keep the Imperium emblem; your settings and history came with you.",
    "Commands start with /warcrest, or /wc for short. /imperium still works.",
  } },
  { version = "2.14.0", date = "Nov 18, 2026", items = {
    "Loot wishlists: mark the items you Need or Want on the new Wishlist tab. When one is auctioned, you're told, and the auction window shows who wants it.",
    "Achievements and titles: 21 achievements for kills, streaks, revenge, bounties, raids and loot on the new Achievements tab. Some come with a title to show after your name.",
    "The Wanted, Settings, Officers and Addon tabs are redesigned in the new look.",
    "New commands: /warcrest wishlist and /warcrest achievements.",
  } },
  { version = "2.13.0", date = "Nov 18, 2026", items = {
    "Player cards: click a guild member's name on the Roster, Kills, DKP or Raids tab to see their kills, deaths, nemesis, best streak, DKP, attendance and loot in one place. Or type /warcrest card Name.",
    "Kill streaks: the guild hears when someone gets 3, 5, 10 or more kills in a row, and when a big streak is ended. The Kills tab shows the period's best streak.",
    "Revenge: the guild hears when someone kills an enemy player who just killed a guildmate.",
    "The DKP, Raids and Roster tabs are redesigned in the new look.",
  } },
  { version = "2.12.0", date = "Nov 17, 2026", items = {
    "A new look: the guild panel and its windows are redesigned, dark and flat with Imperium gold, a new font, and a side menu with icons.",
    "The Kills tab is redesigned: a kill table, this month's leader, and Top Head Hunters with bars. Pick the period at the top, and drag the borders between column headings to see long names in full.",
    "Resize the window: drag its bottom-right corner to show more rows, or set its size in Settings > Guild window.",
    "Every list says something when it's empty, and the panel opens on the tab you used last.",
    "Tooltips on buttons that didn't explain themselves. They show even when a button is greyed out.",
  } },
  { version = "2.11.1", date = "Nov 17, 2026", items = {
    "Fixed: kills of grey-level players were still being logged. Grey kills are now never announced or logged, and any already in your Kills tab are cleared out.",
  } },
  { version = "2.11.0", date = "Nov 17, 2026", items = {
    "Raid makeup: the Raids tab shows who's coming by class and warns when a raid is short of tanks or healers, or has a class nobody signed up with. Raids with gaps get an orange ! in the list.",
    "Officers get a heads-up an hour before a raid if its makeup has gaps.",
    "Weekly recap: after the Tuesday reset you get a summary of the guild's week in chat: kills, top head hunters, raids, bosses and loot. Turn it off in Settings, or type /warcrest recap to see it again.",
  } },
  { version = "2.10.0", date = "Nov 16, 2026", items = {
    "Top Head Hunters now starts fresh on the 1st of each month. Switch to Last month or All time on the Kills tab to see earlier standings.",
    "On reset day (the 1st), the guild hears last month's top three head hunters. Last month's champion is also shown under the board.",
    "Fixed: Top Head Hunters could credit a different killing blow on different guildmates' screens for some older kills.",
  } },
  { version = "2.9.0", date = "Nov 15, 2026", items = {
    "DKP seasons: officers can start a new season from the DKP tab. Everyone keeps their DKP, and older history is archived so the addon stays fast.",
    "DKP, raids and attendance are worked out much faster, especially with a lot of history.",
  } },
  { version = "2.8.0", date = "Nov 15, 2026", items = {
    "Alts: link your alts to your main on the DKP tab (Alts). They share your DKP and attendance. Linking needs both characters, so only you can link your own alts.",
    "Boss DKP: officers can set DKP per boss kill when starting a raid. It's awarded automatically each time the raid kills a boss.",
    "Free rolls: if nobody bids on an item, the raid gets a free roll for it instead.",
    "Class check: you're warned before bidding on gear your class can't use.",
    "Officers can undo any DKP change, refund loot or give it to someone else, and import starting balances.",
  } },
  { version = "2.7.0", date = "Nov 15, 2026", items = {
    "Attendance: the DKP tab shows each member's raid attendance over the last 30 days. Hover a name for details.",
    "Standby: officers can put members on standby during a raid. They earn the same DKP as the raid and count as attending.",
    "No-shows: after a raid night, anyone who accepted but didn't come is marked on the Raids tab and in their attendance.",
    "Raid invites: officers can invite everyone who signed up with one click. If a raid starts without you, you get a reminder.",
    "DKP decay: officers can take a percentage off everyone's DKP, now or automatically each week.",
    "Hidden bids: officers can switch auctions to hidden bids, where the winner pays the second-highest bid + 1.",
  } },
  { version = "2.6.0", date = "Nov 15, 2026", items = {
    "Loot history: on the DKP tab, switch to Loot history to see every item won in an auction, who won it, for how much, and on which raid night. Hover an item for its tooltip.",
    "Officers can export DKP as a text backup of standings, loot and every DKP change.",
    "More reliable on busy nights: messages are now paced to stay within the game's limits, so kills and loot bids are no longer lost when lots is happening at once.",
  } },
  { version = "2.5.0", date = "Nov 15, 2026", items = {
    "Killing blows and assists: the guild member who hit an enemy last gets the killing blow, everyone else who helped gets an assist. Top Head Hunters now ranks by killing blows, with assists shown alongside.",
    "Honor kills only: grey kills (much lower level, no honor) no longer count, on by default for the guild. Officers can change it in Settings.",
    "Officers can right-click a kill on the Kills tab to remove it for the whole guild.",
  } },
  { version = "2.4.1", date = "Nov 15, 2026", items = {
    "Fixed: guildmates' Kills tabs and Top Head Hunters could show different kills. Kill logs now compare with each other every 15 minutes and fill in anything missing, both ways, so everyone ends up with the same kills.",
    "Fixed: killing the same player again within 2 minutes (camping) only counted once. Kills are now only combined when they're within 30 seconds of each other.",
  } },
  { version = "2.4.0", date = "Nov 15, 2026", items = {
    "New Addon tab: see which guild members have The Imperium installed, which version, and when their addon was last seen. Filter by who has it, who doesn't, or who needs to update.",
    "Click Check now to ask everyone online. Open it with /warcrest addon.",
  } },
  { version = "2.3.0", date = "Nov 15, 2026", items = {
    "New: when a guild member kills a wanted player, the bounty is claimed and they drop off the Wanted list. Their count starts over, so they come back if they keep ganking.",
    "Kill alerts say \"Wanted bounty claimed!\" when the victim was on the Wanted list.",
    "You can turn this off with the new checkbox at the bottom of the Wanted tab.",
  } },
  { version = "2.2.0", date = "Nov 14, 2026", items = {
    "New: this Updates panel. It appears after each update with what changed. Reopen it with /warcrest updates.",
  } },
  { version = "2.1.1", date = "Nov 14, 2026", items = {
    "Fixed: deaths to damage over time were announced as falling to death. A death now only counts as a fall if you dropped for at least a second, died as you landed, and weren't in combat.",
  } },
  { version = "2.1.0", date = "Nov 13, 2026", items = {
    "Release! Test data from before launch was cleared so the guild starts fresh. Your settings were kept.",
    "PvP kill alerts with the Top Head Hunters board, a Wanted list of gankers, raid sign-ups, and DKP with live loot auctions.",
  } },
}

local MAX_SHOWN = 6
local win

-- Entries newer than `since` (all of them if since is nil), newest first.
local function changesSince(since)
  local out = {}
  for _, c in ipairs(CHANGES) do
    if since and ns.CompareVersions(c.version, since) <= 0 then break end
    out[#out + 1] = c
    if #out >= MAX_SHOWN then break end
  end
  return out
end

local function buildText(entries)
  local lines = {}
  for _, c in ipairs(entries) do
    lines[#lines + 1] = ("%s%s|r  |cff8b95a7%s|r"):format(ns.COLOR, ns.TF("Version %s", c.version), c.date)
    for _, item in ipairs(c.items) do lines[#lines + 1] = "  |cffe0b94c•|r  " .. ns.T(item) end
    lines[#lines + 1] = " "
  end
  return table.concat(lines, "\n")
end

local function create()
  local f = UI.Window("WarcrestUpdates", 460, 380, "What's new")
  win = f
  f:ClearAllPoints()
  f:SetPoint("CENTER", 0, 40)

  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetSize(48, 48)
  icon:SetPoint("TOPLEFT", 16, -32)
  ns.Emblem(icon, "PORTRAIT")

  f.heading = UI.Label(f, "", "GameFontNormalLarge")
  f.heading:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -4)
  f.sub = UI.Label(f, "", "GameFontHighlightSmall")
  f.sub:SetPoint("TOPLEFT", f.heading, "BOTTOMLEFT", 0, -6)

  local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")

  UI.SkinScrollBar(sf)
  sf:SetPoint("TOPLEFT", 16, -92)
  sf:SetPoint("BOTTOMRIGHT", -34, 50)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(400, 10)
  sf:SetScrollChild(content)
  f.body = UI.Label(content, "", "GameFontHighlight")
  f.body:SetPoint("TOPLEFT", 0, 0)
  f.body:SetWidth(400)
  f.body:SetSpacing(3)
  f.content = content

  local close = UI.Button(f, "Got it", 110, "primary")
  close:SetPoint("BOTTOM", 0, 14)
  close:SetScript("OnClick", function() f:Hide() end)
end

-- since: the version you last used, or nil to show recent changes.
function ns.ShowUpdates(since)
  if InCombatLockdown() then
    ns.Say("The Updates panel will open after combat.")
    ns.pendingUpdates = since or false
    return
  end
  local entries = changesSince(since)
  if #entries == 0 then entries = changesSince(nil) end
  if not win then create() end
  win.heading:SetText(since and ns.TF("Updated to version %s", ns.version) or ns.TF("Version %s", ns.version))
  win.sub:SetText(since and ns.TF("Here's what changed since version %s.", since) or ns.T("Recent changes to Warcrest."))
  win.body:SetText(buildText(entries))
  win.content:SetHeight(math.max(10, win.body:GetStringHeight() + 10))
  win:Show()
end

ns.OnEvent("PLAYER_REGEN_ENABLED", function()
  if ns.pendingUpdates ~= nil then
    local since = ns.pendingUpdates or nil
    ns.pendingUpdates = nil
    C_Timer.After(1, function() ns.ShowUpdates(since) end)
  end
end)

-- After login, show the panel once if the addon was updated since last time.
ns.OnEvent("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
  if not (isLogin or isReload) then return end
  local last = ns.db.lastSeenVersion
  ns.db.lastSeenVersion = ns.version
  if last == nil then
    -- Brand-new installs see nothing. Players who had the addon before this
    -- panel existed were on 2.1.1 or earlier.
    if ns.isNewInstall then return end
    last = "2.1.1"
  end
  if ns.CompareVersions(ns.version, last) <= 0 then return end
  C_Timer.After(6, function() ns.ShowUpdates(last) end)
end)
