--[[
  Warcrest
  Home: what's happening in the guild, on one page. A greeting, your next
  Getting started step, then cards: the next raid (and your job in it), your
  DKP, the open poll, PvP this week and the guild's news. Each card opens its
  section.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C
local Ambiguate = ns.Ambiguate

local P = {}
local GAP = 12
local STRIP_H = 40

local function me() return UnitName("player") end

-- A card: a dark box with a small heading. Clicking it opens `open` (a section's tab).
local function Card(parent, open)
  local f = CreateFrame("Button", nil, parent)
  UI.Card(f, 0)
  local hover = f:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(1, 1, 1, 0.02)
  f.kicker = UI.Label(f, "", "Label")
  f.kicker:SetPoint("TOPLEFT", 16, -14)
  if open then f:SetScript("OnClick", function() ns.OpenPanel(open[1], open[2]) end) end
  return f
end

-- Lines of text in a card, one under another from y.
local function Lines(card, n, y, font)
  card.lines = {}
  for i = 1, n do
    local l = UI.Label(card, "", font or "Body")
    l:SetPoint("TOPLEFT", 16, y - (i - 1) * 20)
    l:SetWordWrap(false)
    card.lines[i] = l
  end
end

local function fit(card, w)
  for _, l in ipairs(card.lines or {}) do l:SetWidth(w - 32) end
end

------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------
local function BuildStrip(page)
  local s = CreateFrame("Frame", nil, page)
  s:SetHeight(STRIP_H)
  UI.Fill(s, C.accent, 0.08)
  UI.Border(s, C.accent[1], C.accent[2], C.accent[3], 0.45)
  s.label = UI.Label(s, "Next step", "Subheading")
  s.label:SetPoint("LEFT", 14, 0)
  s.label:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  s.text = UI.Label(s, "", "Body")
  s.text:SetPoint("LEFT", s.label, "RIGHT", 14, 0)
  s.text:SetWordWrap(false)
  s.later = UI.Button(s, "Later", 96)
  s.later:SetHeight(26)
  s.later:SetPoint("RIGHT", -8, 0)
  s.later:SetScript("OnClick", function() P.later = true; ns.RefreshPanel() end)
  UI.Tooltip(s.later, function() return s.later.tip == "nudge" and ns.T("Hide") or ns.T("Later") end,
    function() return s.later.tip == "nudge"
      and ns.T("Hides this reminder. It comes back only if 5 or more active members are still without Warcrest.")
      or ns.T("Hides this until you next log in. The Getting started card in the side menu stays.") end)
  s.go = UI.Button(s, "", 150, "primary")
  s.go:SetHeight(26)
  s.go:SetPoint("RIGHT", s.later, "LEFT", -6, 0)
  P.strip = s
end

local function BuildRaid(page)
  local c = Card(page, { "raids" })
  c.title = UI.Label(c, "", "Display")
  c.title:SetPoint("TOPLEFT", 16, -34)
  c.title:SetWordWrap(false)
  c.info = UI.Label(c, "", "Body")
  c.info:SetPoint("TOPLEFT", 16, -64)
  c.info:SetWordWrap(false)
  c.roles = UI.Label(c, "", "Small")
  c.roles:SetPoint("TOPLEFT", 16, -88)
  c.roles:SetWordWrap(false)
  c.jobsLabel = UI.Label(c, "", "Label")
  c.jobsLabel:SetPoint("TOPLEFT", 16, -116)
  c.job = CreateFrame("Frame", nil, c)
  c.job:SetPoint("TOPLEFT", 16, -132)
  c.job:SetHeight(48)
  UI.Fill(c.job, C.sidebar)
  c.jobText = UI.Label(c.job, "", "Body")
  c.jobText:SetPoint("TOPLEFT", 10, -8)
  c.jobText:SetSpacing(4)
  if c.jobText.SetMaxLines then c.jobText:SetMaxLines(2) end
  c.open = UI.Button(c, "Open raid", 110)
  c.open:SetHeight(26)
  c.open:SetPoint("TOPRIGHT", -14, -36)
  c.open:SetScript("OnClick", function() ns.OpenPanel("raids") end)
  P.raid = c
end

local function BuildDKP(page)
  local c = Card(page, { "dkp", "standings" })
  c.big = UI.Label(c, "", "Display")
  c.big:SetPoint("TOPLEFT", 16, -34)
  c.big:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  Lines(c, 3, -66, "Small")
  P.dkp = c
end

local function BuildPoll(page)
  local c = Card(page, { "events", "polls" })
  c.q = UI.Label(c, "", "Subheading")
  c.q:SetPoint("TOPLEFT", 16, -32)
  c.q:SetSpacing(3)
  if c.q.SetMaxLines then c.q:SetMaxLines(2) end
  c.opts = {}
  for i = 1, 3 do
    local b = CreateFrame("Button", nil, c)
    b:SetHeight(24)
    b.bg = UI.Fill(b, C.sidebar)
    b.mine = UI.Fill(b, C.accent, 0.14, "BORDER")
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.05)
    b.text = UI.Label(b, "", "Small")
    b.text:SetPoint("LEFT", 8, 0)
    b.text:SetWordWrap(false)
    b.count = UI.Label(b, "", "MutedSmall")
    b.count:SetPoint("RIGHT", -8, 0)
    b:SetScript("OnClick", function(self)
      if self.poll and ns.VotePoll(self.poll.id, self.choice) then ns.RefreshPanel() end
    end)
    UI.Tooltip(b, "Vote", "Click an answer to vote. You can change your vote while the poll is open.")
    c.opts[i] = b
  end
  c.empty = UI.Label(c, "", "Small")
  c.empty:SetPoint("TOPLEFT", 16, -34)
  P.poll = c
end

local function BuildPvP(page)
  local c = Card(page, { "kills" })
  c.rows = {}
  for i = 1, 3 do
    local name = UI.Label(c, "", "Body")
    name:SetPoint("TOPLEFT", 16, -34 - (i - 1) * 22)
    name:SetWordWrap(false)
    local n = UI.Label(c, "", "Number")
    n:SetPoint("TOPRIGHT", -16, -34 - (i - 1) * 22)
    c.rows[i] = { name = name, n = n }
  end
  c.wanted = UI.Label(c, "", "Small")
  c.wanted:SetPoint("BOTTOMLEFT", 16, 14)
  c.wanted:SetWordWrap(false)
  P.pvp = c
end

local function BuildNews(page)
  local c = Card(page, nil)
  Lines(c, 5, -34, "Small")
  P.news = c
end

-- Place everything for the page's size: the strip, then a 3 x 2 grid (the raid card two wide).
local function Layout(w, h)
  local y = 0
  if P.strip:IsShown() then
    P.strip:ClearAllPoints()
    P.strip:SetPoint("TOPLEFT", 0, 0)
    P.strip:SetWidth(w)
    P.strip.text:SetWidth(math.max(40, w - P.strip.label:GetStringWidth() - 270))
    y = STRIP_H + GAP
  end
  local cw = math.floor((w - 2 * GAP) / 3)
  local ch = math.floor((h - y - GAP) / 2)
  local function place(card, col, row, span)
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", col * (cw + GAP), -(y + row * (ch + GAP)))
    card:SetSize(cw * span + GAP * (span - 1), ch)
    fit(card, card:GetWidth())
  end
  place(P.raid, 0, 0, 2)
  place(P.dkp, 2, 0, 1)
  place(P.poll, 0, 1, 1)
  place(P.pvp, 1, 1, 1)
  place(P.news, 2, 1, 1)
  local rw = P.raid:GetWidth()
  P.raid.title:SetWidth(rw - 160)
  P.raid.info:SetWidth(rw - 32)
  P.raid.roles:SetWidth(rw - 32)
  P.raid.job:SetWidth(rw - 32)
  P.raid.jobText:SetWidth(rw - 52)
  P.poll.q:SetWidth(cw - 32)
  for i, b in ipairs(P.poll.opts) do
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 16, -72 - (i - 1) * 28)
    b:SetWidth(cw - 32)
    b.text:SetWidth(cw - 90)
  end
  P.pvp.wanted:SetWidth(cw - 32)
  for _, r in ipairs(P.pvp.rows) do r.name:SetWidth(cw - 80) end
end

local function Build(page)
  local holder = CreateFrame("Frame", nil, page)
  holder:SetAllPoints()
  P.holder = holder
  BuildStrip(holder)
  BuildRaid(holder)
  BuildDKP(holder)
  BuildPoll(holder)
  BuildPvP(holder)
  BuildNews(holder)
  -- Anyone can pass Warcrest on: a short message to copy.
  local share = UI.Button(page.headerBar, "Share Warcrest", 130)
  share:SetHeight(26)
  share:SetPoint("RIGHT")
  share:SetScript("OnClick", function() ns.ShowShare() end)
  UI.Tooltip(share, "Share Warcrest", "A short message about Warcrest to copy and send to a friend or another guild.")
  P.share = share
  -- Laid out for the page's size, and again whenever the window is resized.
  P.w, P.h = UI.PAGE_W, UI.PAGE_H
  page.growth = page.growth or {}
  table.insert(page.growth, function(dw, dh)
    P.w, P.h = UI.PAGE_W + dw, UI.PAGE_H + dh
    Layout(P.w, P.h)
  end)
end

------------------------------------------------------------------------
-- Filling in
------------------------------------------------------------------------
-- The strip: officers are reminded to invite the guild when fewer than half
-- the active members have Warcrest; otherwise your next Getting started step.
local function laterButton(label, tip, onClick)
  P.strip.later:SetText(ns.T(label))
  P.strip.later:SetScript("OnClick", onClick)
  P.strip.later.tip = tip
end

local function RefreshStrip()
  local s = P.strip
  if ns.ShouldNudge() then
    local have, active = ns.WarcrestCount()
    s:Show()
    s.label:SetText(ns.T("Your guild"))
    s.text:SetText(ns.TF("%d of %d active members have Warcrest. Invite the rest.", have, active))
    s.go:SetText(ns.T("Invite"))
    s.go:SetScript("OnClick", function() ns.ShowInvite() end)
    laterButton("Hide", "nudge", function() ns.DismissNudge(); ns.RefreshPanel() end)
    P.nudging = true
    return
  end
  P.nudging = false
  local step = ns.NextStartedStep and ns.NextStartedStep()
  local show = step and not P.later and not ns.db.started.dismissed
  s:SetShown(show and true or false)
  if not show then return end
  s.label:SetText(ns.T("Next step"))
  s.text:SetText(ns.T(step.title) .. UI.Code("muted") .. "  ·  " .. ns.T(step.hint) .. "|r")
  s.go:SetText(step.button)
  s.go:SetScript("OnClick", step.go)
  laterButton("Later", "later", function() P.later = true; ns.RefreshPanel() end)
end

-- The next raid that hasn't finished (or tonight's raid night).
local function nextRaid()
  local now = time()
  for _, e in ipairs(ns.RaidEvents()) do
    if e.start >= now - 4 * 3600 then return e end
  end
end

-- Your jobs in a raid's assignments: "Boss: job" lines.
local function myJobs(raid)
  local out = {}
  if not (raid and ns.AssignmentBosses and ns.Assignment and ns.JobsIn) then return out end
  for _, boss in ipairs(ns.AssignmentBosses(raid)) do
    local plan = ns.Assignment(raid, boss)
    if plan and plan.text and plan.text ~= "" then
      for _, job in ipairs(ns.JobsIn(plan.text, me())) do
        out[#out + 1] = (boss == ns.WHOLE_RAID and ns.T("Whole raid") or boss) .. ": " .. job
      end
    end
  end
  return out
end

local STATUS = { accept = "you're in", tentative = "you're tentative", decline = "you can't come" }
local function RefreshRaid()
  local c = P.raid
  local active = ns.ActiveSession and ns.ActiveSession()
  local e = nextRaid()
  c.jobsLabel:SetText("")
  c.roles:SetText("")
  c.job:Hide()
  if active then
    c.kicker:SetText(ns.Upper(ns.T("Raid night in progress")))
    c.title:SetText(active.title or "")
  elseif e then
    c.kicker:SetText(ns.Upper(ns.T("Next raid")))
    c.title:SetText(e.title)
  else
    c.kicker:SetText(ns.Upper(ns.T("Next raid")))
    c.title:SetText(ns.T("No raids scheduled"))
    c.info:SetText(ns.IsAddonOfficer() and ns.T("Officers: schedule one with New raid in Raids.")
      or ns.T("Your officers haven't scheduled one yet."))
    c.open:SetText(ns.T("Raids"))
    return
  end
  c.open:SetText(ns.T("Open raid"))
  local parts = {}
  if e then
    parts[#parts + 1] = ns.Date("%a %b %d, %H:%M", e.start)
    local counts = ns.SignupCounts(e.id)
    parts[#parts + 1] = ns.TF("%d accepted", counts.accept)
    local mine = ns.MySignup(e.id)
    if mine then
      local s = ns.T(STATUS[mine.status] or "")
      if mine.status == "accept" then s = UI.Code("good") .. ns.TF("you're in, as %s", ns.T(mine.role == "dps" and "DPS" or (mine.role == "tank" and "Tank" or "Healer"))) .. "|r" end
      parts[#parts + 1] = s
    else
      parts[#parts + 1] = UI.Code("accent") .. ns.T("you haven't signed up") .. "|r"
    end
  end
  c.info:SetText(table.concat(parts, "  ·  "))
  if e then
    local counts = ns.SignupCounts(e.id)
    local roles = ns.TF("Tanks %d  ·  Healers %d  ·  DPS %d", counts.tank, counts.healer, counts.dps)
    local mk = ns.RaidMakeup and ns.RaidMakeup(e.id)
    local warn = mk and mk.warnings and mk.warnings[1]
    c.roles:SetText(UI.Code("muted") .. roles .. "|r" .. (warn and ("   " .. UI.Code("warn") .. warn .. "|r") or ""))
  end
  local jobs = myJobs(e and e.title or (active and active.title))
  if #jobs == 0 and e then
    -- No jobs for you: who's coming instead.
    local names = {}
    for _, su in ipairs((ns.Signups(e.id))) do
      if su.status == "accept" then names[#names + 1] = Ambiguate(su.name, "short") end
    end
    if #names > 0 then
      table.sort(names)
      c.jobsLabel:SetText(ns.Upper(ns.T("Coming")))
      c.jobText:SetText(table.concat(names, ", "))
      c.job:Show()
    end
  elseif #jobs > 0 then
    c.jobsLabel:SetText(ns.Upper(ns.T("Your jobs")))
    c.jobText:SetText(table.concat(jobs, "\n"))
    c.job:Show()
  end
end

local function RefreshDKP()
  local c = P.dkp
  if ns.UsesDKP() then
    c.kicker:SetText(ns.Upper(ns.T("Your DKP")))
    c:SetScript("OnClick", function() ns.OpenPanel("dkp", "standings") end)
    local mine = ns.Balance(me())
    c.big:SetText(tostring(mine))
    local list = ns.DKPStandings()
    local place = 1
    for _, s in ipairs(list) do if s.dkp > mine then place = place + 1 end end
    local attended, total = ns.Attendance(me())
    c.lines[1]:SetText(ns.TF("Place %d of %d", place, #list))
    c.lines[2]:SetText(total > 0 and ns.TF("%d of %d raids attended (30 days)", attended, total) or "")
    local wish = ns.Wishes(me())[1]
    c.lines[3]:SetText(wish and ns.TF("On your wishlist: %s", wish.name or "?") or ns.T("Your wishlist is empty."))
  else
    c.kicker:SetText(ns.Upper(ns.T("Your achievements")))
    c:SetScript("OnClick", function() ns.OpenPanel("achievements") end)
    local n = ns.AchievementCount(me())
    c.big:SetText(tostring(n))
    c.lines[1]:SetText(ns.TF("of %d achievements", ns.ACHIEVEMENT_TOTAL))
    local title = ns.TitleOf(me())
    c.lines[2]:SetText(title and ns.TF("Your title: %s", ns.T(title)) or ns.T("No title chosen yet."))
    c.lines[3]:SetText("")
  end
end

local function RefreshPoll()
  local c = P.poll
  local poll
  for _, p in ipairs(ns.Polls()) do if p.open then poll = p break end end
  for _, b in ipairs(c.opts) do b:Hide() end
  if not poll then
    c.kicker:SetText(ns.Upper(ns.T("Polls")))
    c.q:SetText("")
    c.empty:SetText(ns.T("No open polls."))
    c.empty:Show()
    return
  end
  c.empty:Hide()
  local left = poll.ends - GetServerTime()
  local days = math.floor(left / 86400)
  c.kicker:SetText(ns.Upper(ns.T("Poll")) .. " · " .. ns.Upper(days >= 1 and ns.TF("%d days left", days + (left % 86400 > 0 and 1 or 0)) or ns.T("ends today")))
  c.q:SetText(poll.q)
  local mine = ns.MyVote(poll)
  for i, b in ipairs(c.opts) do
    if poll.opts[i] then
      b.poll, b.choice = poll, i
      b.text:SetText(poll.opts[i])
      b.count:SetText(tostring(poll.counts[i] or 0))
      b.mine:SetShown(mine == i)
      b:Show()
    end
  end
end

local function RefreshPvP()
  local c = P.pvp
  c.kicker:SetText(ns.Upper(ns.T("PvP this week")))
  local fromT, toT = ns.WeekRange(0)
  local kills = ns.QueryKills("all", fromT, toT)
  local top = ns.KillStats(kills, 3)
  local myKey = ns.Key(me())
  for i, r in ipairs(c.rows) do
    local t = top[i]
    if t then
      local you = ns.Key(t.name) == myKey and (" " .. UI.Code("muted") .. ns.T("(you)") .. "|r") or ""
      r.name:SetText(Ambiguate(t.name, "short") .. you)
      r.n:SetText(tostring(t.count))
      local col = i == 1 and C.accent or C.text
      r.n:SetTextColor(col[1], col[2], col[3])
    else
      r.name:SetText(i == 1 and #kills == 0 and UI.Code("muted") .. ns.T("No kills yet this week.") .. "|r" or "")
      r.n:SetText("")
    end
  end
  local w = ns.WantedList()[1]
  if w then
    local where = w.seen and w.seen.zone or w.lastZone
    c.wanted:SetText(UI.Code("bad") .. ns.TF("Wanted: %s", w.name) .. "|r"
      .. (where and where ~= "" and (UI.Code("muted") .. ", " .. where .. "|r") or ""))
    c.wanted:Show()
  else
    c.wanted:SetText("")
  end
end

local function RefreshNews()
  local c = P.news
  c.kicker:SetText(ns.Upper(ns.T("Guild news")))
  local since = GetServerTime() - 7 * 86400
  local items = {}
  for _, k in ipairs(ns.BossKills(since)) do
    items[#items + 1] = { t = k.t, text = ns.TF("%s down", "|cffffffff" .. k.name .. "|r") }
  end
  for i, a in ipairs(ns.GuildAchievements()) do
    if a.t < since or i > 20 then break end
    local def = ns.Achievement(a.id)
    if def then
      items[#items + 1] = { t = a.t, text = ns.TF("%s earned %s", a.name, UI.Code("accent") .. ns.T(def.name) .. "|r") }
    end
  end
  table.sort(items, function(a, b) return a.t > b.t end)
  for i, l in ipairs(c.lines) do
    if items[i] then l:SetText(items[i].text)
    elseif i == 1 then l:SetText(UI.Code("muted") .. ns.T("A quiet week so far.") .. "|r")
    else l:SetText("") end
  end
end

local function Refresh()
  RefreshStrip()
  RefreshRaid()
  RefreshDKP()
  RefreshPoll()
  RefreshPvP()
  RefreshNews()
  Layout(P.w, P.h)
end

-- The header: a greeting, and who's online.
local function Heading()
  local hour = tonumber(date("%H")) or 12
  local greet = hour < 5 and "Good evening, %s" or hour < 12 and "Good morning, %s"
    or hour < 18 and "Good afternoon, %s" or "Good evening, %s"
  return ns.TF(greet, me())
end

local function Subtitle()
  local online, total = 0, 0
  for _, m in ipairs(ns.GetRoster()) do
    total = total + 1
    if m.online then online = online + 1 end
  end
  local text = ns.TF("%d of %d online", online, total)
  if ns.ActiveSession and ns.ActiveSession() then
    text = text .. "  ·  " .. ns.T("raid night in progress")
  else
    local e = nextRaid()
    if e and date("%Y-%m-%d", e.start) == date("%Y-%m-%d") then text = text .. "  ·  " .. ns.T("raid tonight") end
  end
  return text
end

UI.AddTab({ id = "home", title = "Home", build = Build, refresh = Refresh, heading = Heading, subtitle = Subtitle })
