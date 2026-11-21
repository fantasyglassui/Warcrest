--[[
  Warcrest
  The welcome and guild setup window. New players get Getting started
  (UI/GettingStarted.lua) the first time Warcrest loads for a character in a
  guild; officers open this from there, or with /warcrest setup. The steps:
    1. What Warcrest does.
    2. Guild setup: officers choose who manages Warcrest and whether the
       guild uses DKP. Members are told their officers handle this.
    3. (Officers) What the guild hears: which alerts, and whether
       achievements are posted in guild chat. Then save it for everyone.
    4. Where to start: the tabs worth a look first.
  /warcrest setup opens the guild setup.
  Officers in a guild nobody has set up yet are reminded once a session.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local WIDTH, HEIGHT = 520, 448
local INNER = WIDTH - 48
local win
local step = 1
local pages = {}
local rankValue, dkpValue
local order = {} -- the pages shown, in order (members skip the officers' ones)

-- n: the position in `order`.
local function setStep(n)
  step = n
  local page = order[n]
  for _, p in ipairs(pages) do p:SetShown(p == page) end
  for i, dot in ipairs(win.dots) do
    dot:SetShown(i <= #order)
    local col = i == n and C.accent or C.faint
    dot:SetColorTexture(col[1], col[2], col[3], 1)
    dot:ClearAllPoints()
    dot:SetPoint("TOPRIGHT", win, "TOPRIGHT", -24 - (#order - i) * 16, -58)
  end
  win.back:SetShown(n > 1)
  win.next:SetText(n == #order and "Open Warcrest" or "Next")
  if page.refresh then page.refresh() end
end

local function Page(title, subtitle)
  local p = CreateFrame("Frame", nil, win)
  p:SetPoint("TOPLEFT", 0, -28)
  p:SetSize(WIDTH, HEIGHT - 28 - 57)
  p.title = UI.Label(p, title, "Title")
  p.title:SetPoint("TOPLEFT", 24, -22)
  if subtitle then
    p.sub = UI.Label(p, subtitle, "Small")
    p.sub:SetPoint("TOPLEFT", 24, -50)
    p.sub:SetWidth(INNER)
    p.sub:SetSpacing(3)
  end
  pages[#pages + 1] = p
  return p
end

-- A line with an icon: what Warcrest does, or where to start.
local function Feature(parent, y, icon, title, text)
  local i = UI.Icon(parent, icon, 16, C.accent)
  i:SetPoint("TOPLEFT", 24, y)
  local t = UI.Label(parent, title, "Subheading")
  t:SetPoint("TOPLEFT", 52, y + 1)
  local d = UI.Label(parent, text, "MutedSmall")
  d:SetPoint("TOPLEFT", 52, y - 17)
  d:SetWidth(INNER - 28)
  return t, d
end

-- The tour's pictures (Media/Tour, made by tools/tour_images.py) and captions.
local TOUR = {
  { "home", "Everything happening in your guild, on one page." },
  { "kills", "Every PvP kill and death, with a monthly leaderboard." },
  { "raids", "Sign up for raids by role; officers see who's coming." },
  { "dkp", "DKP, live loot auctions and wishlists, shared by everyone." },
  { "profiles", "Specs, roles, item levels and when people play." },
}
local TOUR_W, TOUR_H = 432, 216
local tourAt = 1

local function BuildWelcome()
  local p = Page("Welcome to Warcrest", "")
  p.refresh = function()
    local guild = ns.GuildName()
    p.sub:SetText(guild and ns.TF("Guild tools for %s, shared automatically with every guildmate who has Warcrest.", UI.Code("accent") .. guild .. "|r")
      or "Guild tools, shared automatically with every guildmate who has Warcrest. Join a guild to get started.")
  end
  -- The tour: what Warcrest looks like once the guild is on it.
  local pic = p:CreateTexture(nil, "ARTWORK")
  pic:SetPoint("TOP", 0, -92)
  pic:SetSize(TOUR_W, TOUR_H)
  local edge = CreateFrame("Frame", nil, p)
  edge:SetAllPoints(pic)
  UI.Border(edge, C.cardEdge[1], C.cardEdge[2], C.cardEdge[3], 1)
  p.pic = pic
  p.caption = UI.Label(p, "", "Body")
  p.caption:SetPoint("TOPLEFT", pic, "BOTTOMLEFT", 0, -10)
  p.caption:SetWidth(TOUR_W - 60)
  p.count = UI.Label(p, "", "MutedSmall")
  p.count:SetPoint("TOPRIGHT", pic, "BOTTOMRIGHT", 0, -12)
  local function arrow(text, d, point, x)
    local b = UI.Button(p, text, 28)
    b:SetHeight(28)
    b:SetPoint(point, pic, point, x, 0)
    b:SetScript("OnClick", function() ns.TourStep(d) end)
    return b
  end
  p.prev = arrow("<", -1, "LEFT", 6)
  p.nextPic = arrow(">", 1, "RIGHT", -6)
  win.tour = p
end

function ns.TourStep(d)
  tourAt = (tourAt - 1 + d) % #TOUR + 1
  local p = win and win.tour
  if not p then return end
  local t = TOUR[tourAt]
  p.pic:SetTexture("Interface\\AddOns\\Warcrest\\Media\\Tour\\" .. t[1])
  p.caption:SetText(ns.T(t[2]))
  p.count:SetText(tourAt .. " / " .. #TOUR)
end

local function BuildSetup()
  local p = Page("Set up your guild", "")
  local officerBox = CreateFrame("Frame", nil, p)
  officerBox:SetPoint("TOPLEFT", 0, -98)
  officerBox:SetSize(WIDTH, 230)
  local memberText = UI.Label(p, "", "Body")
  memberText:SetPoint("TOPLEFT", 24, -88)
  memberText:SetWidth(INNER)
  memberText:SetSpacing(4)

  UI.FieldLabel(officerBox, "Who manages Warcrest", 24, 0)
  local down = UI.Button(officerBox, "<", 28)
  down:SetHeight(26)
  down:SetPoint("TOPLEFT", 24, -16)
  local rankText = UI.Label(officerBox, "", "Body")
  rankText:SetPoint("LEFT", down, "RIGHT", 10, 0)
  rankText:SetWidth(220)
  local up = UI.Button(officerBox, ">", 28)
  up:SetHeight(26)
  up:SetPoint("LEFT", down, "RIGHT", 240, 0)
  local function stepRank(d)
    rankValue = math.max(0, math.min(UI.NumRanks() - 1, rankValue + d))
    rankText:SetText(ns.TF("%s and higher", UI.RankName(rankValue)))
  end
  down:SetScript("OnClick", function() stepRank(-1) end)
  up:SetScript("OnClick", function() stepRank(1) end)
  local rankHint = UI.Label(officerBox, "These ranks run raids and DKP, and set the guild's alerts. Only the Guild Master can change this.", "MutedSmall")
  rankHint:SetPoint("TOPLEFT", 24, -48)
  rankHint:SetWidth(INNER)

  UI.FieldLabel(officerBox, "Loot", 24, -86)
  local dkp = UI.Segmented(officerBox, { { "yes", "Use DKP" }, { "no", "No DKP" } }, function(v) dkpValue = v end)
  dkp:SetPoint("TOPLEFT", 24, -102)
  local dkpHint = UI.Label(officerBox, "No DKP hides DKP standings and loot auctions. Raids, sign-ups, attendance, "
    .. "wishlists and everything else still work. You can change this later in Settings.", "MutedSmall")
  dkpHint:SetPoint("TOPLEFT", 24, -134)
  dkpHint:SetWidth(INNER)

  local nextHint = UI.Label(officerBox, "Next: the alerts the guild hears, then save it all for everyone.", "Small")
  nextHint:SetPoint("TOPLEFT", 24, -184)
  nextHint:SetWidth(INNER)

  p.refresh = function()
    local officer = ns.IsAddonOfficer()
    local gm = ns.MyRank() == 0
    officerBox:SetShown(officer)
    memberText:SetShown(not officer)
    if officer then
      p.sub:SetText(ns.cfg.stamp > 0
        and ("Your guild's settings were last saved by " .. ns.cfg.by .. ". Change anything here, or later in Settings.")
        or "Nobody has set Warcrest up for your guild yet. It takes a minute: these two things, then the guild's alerts.")
      rankValue = rankValue or ns.cfg.officerRank
      rankText:SetText(ns.TF("%s and higher", UI.RankName(rankValue)))
      UI.SetEnabled(down, gm)
      UI.SetEnabled(up, gm)
      dkpValue = dkpValue or (ns.UsesDKP() and "yes" or "no")
      dkp:SetValue(dkpValue)
    else
      p.sub:SetText("")
      memberText:SetText(ns.TF("Your officers (%s and higher) look after Warcrest's guild settings: raids, DKP and which alerts the guild hears.\n\n"
        .. "You choose what you see yourself. Every alert can be turned off just for you in %sSettings|r, and quiet mode holds alerts in dungeons, raids and combat.",
        UI.RankName(ns.cfg.officerRank), UI.Code("accent")))
    end
  end
end


-- Officers: which alerts the guild hears, then save everything.
local GROUPS = { "kill", "streak", "wanted", "death", "achievement", "raid", "celebrate" }
local function BuildAlerts()
  local p = Page("What the guild hears", "Officers choose the alerts that reach everyone with Warcrest. "
    .. "Each member can still turn any of them off just for themselves.")
  p.officerOnly = true
  local checks = {}
  for i, g in ipairs(GROUPS) do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local cb = UI.Check(p, ns.GROUP_LABELS[g], 24 + col * 236, -96 - row * 30)
    cb.group = g
    local names = {}
    for _, t in ipairs(ns.TYPES) do
      if t.group == g and not t.hidden and not t.feature then names[#names + 1] = ns.T(t.label) end
    end
    UI.Tooltip(cb, ns.GROUP_LABELS[g], table.concat(names, "\n"))
    checks[#checks + 1] = cb
  end
  local chat = UI.Check(p, "Post achievements in guild chat", 24, -222)
  UI.Tooltip(chat, "Posted in guild chat", "Achievements are posted in guild chat, so guildmates without Warcrest see them too.")
  local save = UI.Button(p, "Save for the guild", 180, "primary")
  save:SetHeight(28)
  save:SetPoint("TOPLEFT", 24, -262)
  local saved = UI.Label(p, "", "Small")
  saved:SetPoint("LEFT", save, "RIGHT", 12, 0)
  save:SetScript("OnClick", function()
    local types = {}
    for k, v in pairs(ns.cfg.types) do types[k] = v end
    for _, cb in ipairs(checks) do
      for _, t in ipairs(ns.TYPES) do
        if t.group == cb.group and not t.hidden and not t.feature then types[t.key] = cb:GetChecked() and true or false end
      end
    end
    types.achievement_chat = chat:GetChecked() and true or false
    if ns.PushConfig({ enabled = true, types = types, officerRank = rankValue or ns.cfg.officerRank,
        dkp = (dkpValue or (ns.UsesDKP() and "yes" or "no")) == "yes" }) then
      saved:SetText(UI.Code("good") .. ns.T("Saved and sent to everyone online.") .. "|r")
    end
  end)
  p.checks, p.chat, p.save = checks, chat, save
  p.refresh = function()
    for _, cb in ipairs(checks) do
      local on = false
      for _, t in ipairs(ns.TYPES) do
        if t.group == cb.group and not t.hidden and not t.feature and ns.cfg.types[t.key] then on = true end
      end
      cb:SetChecked(on)
    end
    chat:SetChecked(ns.cfg.types.achievement_chat ~= false)
    saved:SetText("")
  end
end

local function BuildStart()
  local p = Page("Where to start", "A few places worth a look first. Type /warcrest (or /wc), or click the crest by your minimap, any time.")
  local items = {
    { "raids", "Raids", "Sign up for the next raid, or see the calendar and the guild's progress.", "raids" },
    { "roster", "Roster", "Click any name for their player card: kills, DKP, attendance and loot.", "roster" },
    { "trophy", "Achievements", "See what you've earned already, and pick a title.", "achievements" },
    { "settings", "Settings", "Choose which alerts you see, and how.", "settings" },
  }
  for i, it in ipairs(items) do
    local y = -96 - (i - 1) * 50
    Feature(p, y, it[1], it[2], it[3])
    local open = UI.Button(p, "Open", 64)
    open:SetHeight(24)
    open:SetPoint("TOPRIGHT", -24, y + 2)
    open:SetScript("OnClick", function() win:Hide(); ns.OpenPanel(it[4]) end)
  end
end

local function Build()
  win = UI.Window("WarcrestWelcome", WIDTH, HEIGHT, "Warcrest")
  -- The footer: step dots, Back and Next.
  local rule = win:CreateTexture(nil, "BORDER")
  rule:SetPoint("BOTTOMLEFT", 0, 56)
  rule:SetPoint("BOTTOMRIGHT", 0, 56)
  rule:SetHeight(1)
  rule:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
  win.next = UI.Button(win, "Next", 130, "primary")
  win.next:SetHeight(30)
  win.next:SetPoint("BOTTOMRIGHT", -24, 13)
  win.next:SetScript("OnClick", function()
    if step < #order then setStep(step + 1) else win:Hide(); ns.OpenPanel() end
  end)
  win.back = UI.Button(win, "Back", 90)
  win.back:SetHeight(30)
  win.back:SetPoint("RIGHT", win.next, "LEFT", -8, 0)
  win.back:SetScript("OnClick", function() setStep(step - 1) end)
  local help = UI.Button(win, "Help", 70)
  help:SetHeight(30)
  help:SetPoint("BOTTOMLEFT", 24, 13)
  help:SetScript("OnClick", function() win:Hide(); if ns.ShowHelp then ns.ShowHelp() end end)

  BuildWelcome()
  BuildSetup()
  BuildAlerts()
  win.pages = pages
  BuildStart()
  win.dots = {}
  for i = 1, #pages do
    local dot = win:CreateTexture(nil, "ARTWORK")
    dot:SetSize(8, 8)
    win.dots[i] = dot
  end
end

-- first: the step to open on (2: the guild setup).
function ns.ShowWelcome(first)
  if not win then Build() end
  rankValue, dkpValue = nil, nil
  local officer = ns.IsAddonOfficer()
  order = {}
  for _, p in ipairs(pages) do
    if officer or not p.officerOnly then order[#order + 1] = p end
  end
  setStep(math.max(1, math.min(tonumber(first) or 1, #order)))
  ns.TourStep(0)
  win:Show()
  ns.db.welcomed = true
end

-- The tour, from Help: the welcome window's first page.
function ns.ShowTour()
  tourAt = 1
  ns.ShowWelcome(1)
end

-- Officers in a guild nobody has set Warcrest up for: a reminder, once a session.
local reminded = false
local function remind()
  if reminded or not ns.IsAddonOfficer() or (ns.cfg.stamp or 0) > 0 then return end
  if win and win:IsShown() then return end
  reminded = true
  ns.Say("Warcrest isn't set up for your guild yet. Type |cffffffff/warcrest setup|r to choose who manages it, DKP and the guild's alerts. It takes a minute.")
end

-- The first time Warcrest loads for this character in a guild. Players who
-- already used it (or came over from The Imperium) know their way around,
-- unless they're an officer in a guild nobody has set up yet.
local isNew
ns.OnLoad(function() isNew = ns.isNewInstall end)
table.insert(ns.OnGuildReady, function()
  C_Timer.After(90, remind)
  if ns.db.welcomed then return end
  local needsSetup = ns.IsAddonOfficer() and ns.cfg.stamp == 0
  if not isNew and not needsSetup then ns.db.welcomed = true return end
  C_Timer.After(4, function()
    if ns.db.welcomed or InCombatLockdown() or not ns.GuildName() then return end
    if ns.ShowGettingStarted then ns.ShowGettingStarted() else ns.ShowWelcome() end
  end)
end)
