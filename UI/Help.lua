--[[
  Warcrest
  The help window: short answers about every part of Warcrest, by topic.
  Opened with /warcrest help, the ? in the guild window, or from the welcome.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local WIDTH, HEIGHT = 640, 492
local LIST_W = 170
local win
local current = 1

local function B(text) return UI.Code("accent") .. text .. "|r" end
local T, TF = ns.T, ns.TF
-- A paragraph that starts with a highlighted heading: "Heading: the rest."
local function P(head, body) return B(T(head)) .. " " .. T(body) end
-- A command and what it does.
local function CMD(cmd, what) return B(cmd) .. "  " .. T(what) end
local function join(list, sep) return table.concat(list, sep or "\n\n") end

local TOPICS = {
  { "Getting started", function() return join({
    T("Warcrest shares raids, DKP, kills and history between everyone in your guild who has it. There's nothing to set up for members: install it and it starts syncing."),
    TF("Open it with %s (or %s), the crest by your minimap, or Options > AddOns > Warcrest.", B("/warcrest"), B("/wc")),
    T("The more guildmates who have it, the better it works: only players with Warcrest share what they see. Guild > Who has Warcrest shows who has it."),
    T("Click any guild member's name, almost anywhere, to open their player card."),
    TF("New here? %s opens a short checklist that ticks itself off as you go: sign up for a raid, fill in your profile, share your recipes and pick a title.", B("/warcrest start")),
    TF("Officers: the guild setup (%s) sets who manages Warcrest, whether the guild uses DKP, and the guild's alerts.", B("/warcrest setup")),
  }) end },
  { "Raids and sign-ups", function() return join({
    P("Signing up:", "pick a raid in Raids, choose Tank, Healer or DPS, then Accept, Tentative or Decline. You can change your answer any time."),
    P("Reminders:", "you're reminded before raids you signed up for. Officers are warned when a raid is short of tanks or healers."),
    P("Events > Calendar:", "the month's raids (gold), raid nights held (green), bosses killed and guild events. Click a raid or an event to open it."),
    P("Progress:", "the bosses the guild has killed in each raid, with first kills. A kill counts when 5 or more guild members, at least half the raid, kill a raid boss. The first kill of each boss is announced."),
    P("Plan:", "officers put the sign-ups into groups 1 to 8 or on the bench, by clicking a name and then a group, or with Auto-fill (tanks in group 1, a healer in each group). Everyone can see the plan. At raid time, Invite sign-ups invites only the planned groups, and Arrange raid moves everyone into their group (raid leader or assistant)."),
    P("Raid night recap:", "when an officer clicks End raid, the whole guild gets a summary in chat: the bosses killed, the loot and who won it, how many attended, and the DKP you earned. /warcrest raidrecap shows the last one again."),
    P("Officers:", "New raid schedules one. Start raid on raid night records who's there (and gives DKP, if the guild uses it). Invite sign-ups invites everyone who accepted."),
    P("Wipes and kill times:", "every boss pull in a guild raid is recorded, kill or wipe. Progress shows the wipes and the best kill time for each boss, and the raid hears when it beats its best."),
    P("Attunements:", "the Attunements button on Progress shows who's attuned for Molten Core, Onyxia, Blackwing Lair and Naxxramas, and who has the Upper Blackrock Spire and Scholomance keys. Sign-ups who aren't attuned are flagged."),
    P("Assignments:", "officers write who does what on each boss with the Assignments button on Progress, and can post it to raid chat. When the boss is pulled, you're told your job."),
  }) end },
  { "Loot council", function() return join({
    T("A way to hand out loot by vote instead of DKP, and it works whether or not the guild uses DKP."),
    B(T("Starting a vote:")) .. " " .. TF("an officer in the raid opens %s (or the Loot council button in Loot > Wishlist), Shift-clicks the item in, and clicks Start vote.", B("/warcrest council")),
    P("Everyone in the raid:", "a small window asks Need, Greed or Pass. You can change your answer until time runs out."),
    P("Officers:", "see everyone who said Need or Greed, with their wishlist, raid attendance, items won lately and DKP, and click a name to vote. The officer who started it awards the item; it's recorded in the loot history, free of charge."),
  }) end },
  { "DKP and loot", function()
    if not ns.UsesDKP() then
      return T("Your guild doesn't use DKP, so DKP standings and loot auctions are hidden. Officers can turn DKP on in Settings > Alerts (Use DKP for loot).")
    end
    return join({
      P("Earning DKP:", "for being on time, each hour of a raid night and each boss killed, as your officers set it. Alts share their main's DKP."),
      P("Auctions:", "when an officer auctions an item, a window opens for everyone in the raid. Type a bid and click Bid. If nobody bids, there's a free roll."),
      P("Your DKP:", "Loot > Standings shows your total, and All changes every change. Click a name in the standings for their player card."),
      P("Officers:", "award or remove DKP, run auctions, set decay, and start a new season in Loot > Standings. Any change can be undone."),
    })
  end },
  { "Wishlists", function() return join({
    TF("Mark the loot you're after in Loot > Wishlist: Shift-click an item into the box, pick %s (a big upgrade) or %s (nice to have), and click Add.", B(T("Need")), B(T("Want"))),
    T("Everyone sees the guild's wishlist. In my raid shows only the people in your raid right now."),
    T("When an item on your wishlist is auctioned, you're told in chat, and the auction window shows who wants it."),
    T("Click one of your items to switch Need and Want, or the X to remove it. Items you win are marked Won."),
  }) end },
  { "PvP and the Wanted list", function() return join({
    P("Kills:", "when a guild member kills an enemy player, the guild hears about it, and it goes in the shared kill log. Grey kills never count."),
    P("Top Head Hunters:", "the monthly leaderboard in PvP > Kills. The champion is announced on the 1st."),
    P("Streaks and revenge:", "the guild hears about kill streaks, when a big streak is ended, and when someone kills a guildmate's killer."),
    P("Wanted:", "enemy players who keep killing guild members. When anyone spots one, everyone is alerted and the spot is marked on the map."),
    P("Rival guilds:", "PvP > Guild wars shows the score against every enemy guild. Officers mark rivals: the guild is alerted when a group of them is seen, and the weekly recap says how the war went."),
    P("Bounties:", "off until an officer turns them on (Settings > Alerts > Bounties). Then officers can put a reward on an enemy player's head in PvP > Bounties, and the first guild member to kill them in 30 days claims it, paid in DKP if the guild uses it."),
  }) end },
  { "Achievements and titles", function() return join({
    T("Achievements shows what you've earned and your progress on the rest, for PvP, raids, bosses and loot. They come from the guild's shared history, so they count what you did before you installed Warcrest."),
    TF("Some achievements come with a %s. Click the Title button at the top right of Achievements to see every title and pick one you've earned. It shows after your name on your player card.", B(T("title"))),
    T("The Guild view shows what's been earned lately, the guild's goals and who has the most. Officers set goals for the week or month there, like killing 50 enemy players."),
  }) end },
  { "Polls and orders", function() return join({
    P("Polls:", "Events > Polls. Ask the guild a question with a few answers, and everyone with Warcrest votes. Officers can always start one; they can let members start them too (Settings > Alerts)."),
    P("Crafting orders:", "find a recipe in Guild > Crafters (/warcrest craft), click it, pick a crafter and place an order, saying if you're bringing the materials. The crafter accepts, declines or marks it done, and you hear when it changes. Orders shows yours."),
  }) end },
  { "Alerts and settings", function() return join({
    P("Alerts:", "Settings > Alerts lists every alert. The Guild column is set by officers for everyone; the You column is just for you."),
    P("On screen:", "alerts drop in as a banner at the top of the screen, with a colour and icon for each kind. Click one to open what it's about, right-click to dismiss it, Shift-drag to move them. Settings > Alerts can switch to the game's raid warning text, or chat only."),
    P("Sounds:", "each kind of alert has its own sound. Settings > Sounds lets you pick another for any of them, from Warcrest's sounds, the game's, SharedMedia's or your own (put .ogg or .mp3 files in Interface\\AddOns\\WarcrestSounds and restart the game)."),
    P("Quiet mode:", "hold alerts in dungeons, raids or combat. Held alerts are listed in chat once you're out."),
    P("Language:", "Warcrest follows your game's language (English, German, French or Spanish). Pick another in Settings > General, then /reload."),
    P("The window:", "drag the bottom-right corner to make it bigger, or use the Size slider in Settings > General."),
  }) end },
  { "For officers", function() return join({
    P("Roster:", "notes, promote, demote and remove, invites and the Message of the Day. Warcrest can only do what your guild rank allows."),
    P("Officer log:", "promotions, joins, leaves and note changes, recorded while you're online."),
    P("Guild settings:", "which alerts the guild hears, who counts as an officer, and whether the guild uses DKP: Settings > Alerts, then Save for whole guild."),
    P("Who has Warcrest:", "who has Warcrest, who's out of date, and Check now to ask everyone online."),
    P("Inactive members:", "Officers > Officer log, Inactive, lists who hasn't logged in for 14, 30, 60 or 90 days, with their rank and last raid."),
  }) end },
  { "Commands", function() return join({
    CMD("/warcrest  /wc", "open Warcrest"),
    B("/warcrest raids") .. ", " .. B("dkp") .. ", " .. B("kills") .. ", " .. B("wanted") .. ", " .. B("wishlist") .. ", " .. B("achievements") .. ", " .. B("events") .. ", " .. B("recruit") .. "  " .. T("open that page"),
    CMD("/warcrest card Name", "a guild member's player card"),
    CMD("/warcrest profile", "your profile: spec, when you play, birthday"),
    CMD("/warcrest profiles", "everyone's profiles, with item levels"),
    CMD("/warcrest craft [search]", "who in the guild can craft what"),
    CMD("/warcrest auction [item] [min bid]", "auction an item to your raid (officers)"),
    CMD("/warcrest council  /warcrest lc", "the loot council vote"),
    CMD("/warcrest calendar", "Events > Calendar"),
    CMD("/warcrest raidrecap", "the last raid night's recap"),
    CMD("/warcrest attune", "who in the guild is attuned for each raid"),
    CMD("/warcrest assign", "raid assignments for each boss"),
    CMD("/warcrest polls", "guild polls"),
    CMD("/warcrest orders", "your crafting orders"),
    CMD("/warcrest inactive", "members who haven't logged in lately (officers)"),
    CMD("/warcrest recap", "last week's guild recap"),
    CMD("/warcrest quiet", "hold alerts during combat on or off"),
    CMD("/warcrest test", "show a test alert"),
    CMD("/warcrest sync", "fetch recent history from guildmates"),
    CMD("/warcrest minimap", "show or hide the minimap button"),
    CMD("/warcrest share", "a short message about Warcrest, to copy and send"),
    CMD("/warcrest invite", "invite guildmates to get Warcrest"),
    CMD("/warcrest start", "the Getting started checklist"),
    CMD("/warcrest access", "accessibility: text size, colours and alert banners"),
    CMD("/warcrest updates", "what's new"),
    CMD("/warcrest bosses", "the last raid bosses that died, and whether each counted"),
    CMD("/warcrest check [name]", "why achievements have or haven't counted (kills, honor, the guild record)"),
    CMD("/warcrest debug", "show error details (and boss checks) in chat"),
    CMD("/warcrest website", "the website, with guides and a contact form"),
    CMD("/warcrest discord", "the Warcrest Discord invite"),
    CMD("/warcrest report", "a bug report to copy into the Discord or the contact form"),
    CMD("/warcrest setup", "set Warcrest up for your guild (officers)"),
  }, "\n") end },
}

local function show(i)
  current = i
  for n, b in ipairs(win.topics) do UI.SetRowSelected(b, n == i) end
  win.heading:SetText(TOPICS[i][1])
  if win.checklist then win.checklist:SetShown(i == 1) end
  win.text:SetText(TOPICS[i][2]())
  win.scroll:SetVerticalScroll(0)
  win.content:SetHeight(math.max(1, win.text:GetStringHeight() + 20))
end

local function Build()
  win = UI.Window("WarcrestHelp", WIDTH, HEIGHT, "Warcrest help")
  local side = win:CreateTexture(nil, "BACKGROUND", nil, 1)
  side:SetPoint("TOPLEFT", 0, -29)
  side:SetPoint("BOTTOMLEFT")
  side:SetWidth(LIST_W)
  side:SetColorTexture(C.sidebar[1], C.sidebar[2], C.sidebar[3], 1)

  win.topics = {}
  for i, t in ipairs(TOPICS) do
    local b = CreateFrame("Button", nil, win)
    b:SetPoint("TOPLEFT", 0, -40 - (i - 1) * 28)
    b:SetSize(LIST_W, 28)
    UI.RowSelection(b)
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.06)
    local label = UI.Label(b, t[1], "Body")
    label:SetPoint("LEFT", 16, 0)
    label:SetWidth(LIST_W - 24)
    label:SetWordWrap(false)
    b:SetScript("OnClick", function() show(i) end)
    win.topics[i] = b
  end

  -- The website and the Discord, to copy (the game can't open links).
  local function copyBox(text, bottom, title, tip)
    local box = UI.CopyBox(win, LIST_W - 24, text)
    box:SetPoint("BOTTOMLEFT", 12, bottom)
    UI.Tooltip(box, title, tip)
    return box
  end
  local links = UI.Label(win, "WEBSITE AND DISCORD", "Label")
  links:SetPoint("BOTTOMLEFT", 16, 76)
  links:SetWidth(LIST_W - 24)
  links:SetWordWrap(false)
  win.site = copyBox(ns.WEBSITE, 46, "Warcrest website",
    "Guides, every achievement, and a form to send bugs and ideas to the developer. Click, then press Ctrl+C to copy the address.")
  win.discord = copyBox(ns.DISCORD, 16, "Warcrest Discord",
    "Help with setting it up, news about new versions, and other guilds using Warcrest. Click, then press Ctrl+C to copy the invite.")
  win.share = UI.Button(win, "Share Warcrest", LIST_W - 24)
  win.share:SetHeight(22)
  win.share:SetPoint("BOTTOMLEFT", 12, 102)
  win.share:SetScript("OnClick", function() ns.ShowShare() end)
  UI.Tooltip(win.share, "Share Warcrest", "Opens a short message about Warcrest to copy and send to a friend or another guild.")
  win.tour = UI.Button(win, "See it in action", LIST_W - 24)
  win.tour:SetHeight(22)
  win.tour:SetPoint("BOTTOMLEFT", 12, 130)
  win.tour:SetScript("OnClick", function() win:Hide(); ns.ShowTour() end)
  UI.Tooltip(win.tour, "See it in action", "A short picture tour of Warcrest, as it looks once your guild has it.")

  win.heading = UI.Label(win, "", "Title")
  win.heading:SetPoint("TOPLEFT", LIST_W + 24, -44)
  -- On Getting started: the checklist.
  win.checklist = UI.Button(win, "Open the checklist", 150, "primary")
  win.checklist:SetHeight(26)
  win.checklist:SetPoint("TOPRIGHT", -24, -42)
  win.checklist:SetScript("OnClick", function() win:Hide(); ns.ShowGettingStarted() end)
  local sf = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", LIST_W + 24, -80)
  sf:SetSize(WIDTH - LIST_W - 24 - 30, HEIGHT - 80 - 20)
  UI.SkinScrollBar(sf)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(WIDTH - LIST_W - 24 - 34, 1)
  sf:SetScrollChild(content)
  win.text = UI.Label(content, "", "Body")
  win.text:SetPoint("TOPLEFT")
  win.text:SetWidth(WIDTH - LIST_W - 24 - 40)
  win.text:SetSpacing(4)
  win.scroll, win.content = sf, content
end

-- Open the help, on a topic (its number or its title) if given.
-- copy: "discord" (or true, for the website) selects that address, ready to copy.
function ns.ShowHelp(topic, copy)
  if not win then Build() end
  local i = tonumber(topic) or current
  if type(topic) == "string" then
    for n, t in ipairs(TOPICS) do if t[1]:lower():find(topic:lower(), 1, true) then i = n break end end
  end
  show(i)
  win:Show()
  local box = copy == "discord" and win.discord or (copy and win.site)
  if box then box:SetFocus(); box:HighlightText() end
end
