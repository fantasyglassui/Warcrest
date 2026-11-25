--[[
  Warcrest
  Raids tab: scheduled raids with sign-ups, the current raid group, and
  (for officers) creating raids and running raid sessions for attendance DKP.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate
local UI = ns.UI

local P = {}
local selectedId
local TAB
local view = "event"          -- "event", "plan", "group", "progress" or "new"
local FULL = { plan = true, progress = true } -- views that use the whole page
local myRole = "dps"
local newDay = 0               -- days from today for a new raid

local ROLE_TEXT = { tank = "Tank", healer = "Healer", dps = "DPS" }

-- Midnight of today + n days, local time.
local function dayStart(n)
  local d = date("*t")
  d.hour, d.min, d.sec = 0, 0, 0
  return time(d) + n * 86400
end

local function parseTime(text)
  local h, m = (text or ""):match("^%s*(%d%d?):(%d%d)%s*$")
  h, m = tonumber(h), tonumber(m)
  if not h or h > 23 or m > 59 then return nil end
  return h * 3600 + m * 60
end

local C = UI.C
local LEFT_W = 280                -- the raids list and raid night; the selected raid fills the rest
local RIGHT_X = LEFT_W + 14
local RIGHT_W = 740 - RIGHT_X
local MAX_CHIPS = 12
local SCROLL_ROOM = 26            -- rows end this much left of their box, for the scroll bar

-- Statuses in words, colored.
local function statusText(status)
  if status == "accept" then return UI.Code("good") .. ns.T("Accepted") .. "|r" end
  if status == "tentative" then return UI.Code("accent") .. "Tentative|r" end
  return UI.Code("muted") .. "Declined|r"
end

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------
-- The class chips: "Mage 3", "Warrior 2"... in class colors, as many as fit.
local function layoutChips(mk)
  local d, x, shown = P.event, 0, 0
  local room = RIGHT_W - 36
  for i, chip in ipairs(d.chips) do
    local cl = mk.classes[i]
    if cl then
      local r, g, b = UI.ClassColor(cl.classFile)
      chip.text:SetText(("|cff%02x%02x%02x%s|r %s%d|r"):format(math.floor(r * 255), math.floor(g * 255),
        math.floor(b * 255), cl.name, UI.Code("textSoft"), cl.count))
      local w = math.floor(chip.text:GetStringWidth() + 20)
      if x + w > room then
        chip:Hide()
      else
        chip:SetWidth(w)
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", d.chipRow, "TOPLEFT", x, 0)
        chip:Show()
        x = x + w + 6
        shown = shown + 1
      end
    else
      chip:Hide()
    end
  end
  d.chipRow:SetShown(shown > 0)
end

local function RefreshEvent(event)
  local d = P.event
  for _, b in ipairs(d.statusButtons) do b:SetShown(event ~= nil) end
  d.role:SetShown(event ~= nil)
  d.signupBox:SetShown(event ~= nil)
  if not event then
    d.title:SetText("No raid selected")
    d.when:SetText(#ns.RaidEvents() == 0 and "No raids are scheduled yet." or "Pick a raid on the left.")
    d.notes:SetText("")
    for _, stat in pairs(d.stats) do stat:Hide() end
    d.chipRow:Hide()
    d.banner:Hide()
    d.invite:Hide()
    d.noShows:SetText("")
    return
  end
  d.title:SetText(event.title)
  d.when:SetText(ns.Date("%a %b %d, %H:%M", event.start) .. "  ·  " .. ns.T("by") .. " " .. event.a)
  d.notes:SetText(event.notes ~= "" and event.notes or "No notes.")

  local c = ns.SignupCounts(event.id)
  for key, n in pairs({ accept = c.accept, tentative = c.tentative, decline = c.decline }) do
    local stat = d.stats[key]
    stat.number:SetText(n)
    local col = n == 0 and C.faint or (key == "accept" and C.good or (key == "tentative" and C.text or C.muted))
    stat.number:SetTextColor(col[1], col[2], col[3])
    stat:Show()
  end

  -- Who's coming by class, and what the raid is short of.
  local mk = ns.RaidMakeup(event.id)
  layoutChips(mk)
  if mk.accept == 0 then
    d.banner:Hide()
  else
    local warn = #mk.warnings > 0
    local col = warn and C.warn or C.good
    d.banner.fill:SetColorTexture(col[1], col[2], col[3], 0.08)
    d.banner.border:SetColor(col[1], col[2], col[3], 0.35)
    d.banner.icon:SetTexture(UI.IconPath(warn and "warning" or "check"))
    d.banner.icon:SetVertexColor(col[1], col[2], col[3])
    d.banner.text:SetText(warn and (table.concat(mk.warnings, ". ") .. ".") or
      ns.TF("Tanks and healers covered for %d players.", mk.accept))
    d.banner.text:SetTextColor(col[1], col[2], col[3])
    d.banner:Show()
  end

  -- After the raid night, mark accepted sign-ups who never came.
  local noShows, attended = ns.NoShows(event.id)
  local rows = {}
  -- A raid that needs an attunement: flag sign-ups whose addon says they don't have it.
  local need = ns.AttunementForRaid and ns.AttunementForRaid(event.title)
  for _, su in ipairs((ns.Signups(event.id))) do
    local set = need and ns.AttunementsOf(su.name)
    rows[#rows + 1] = { name = su.name, role = su.role, status = su.status, classFile = mk.classOf[ns.Key(su.name)],
      noShow = attended ~= nil and su.status == "accept" and not attended[ns.Key(su.name)],
      notAttuned = set ~= nil and su.status ~= "decline" and not set[need.key] and need or nil }
  end
  P.signups:SetEmptyText("Nobody has signed up yet.")
  P.signups:SetItems(rows)
  if noShows then
    d.noShows:SetText(#noShows > 0 and (UI.Code("bad") .. ns.T("No-shows:") .. "|r " .. table.concat(noShows, ", "))
      or (UI.Code("good") .. ns.T("Everyone who accepted showed up.") .. "|r"))
  else
    d.noShows:SetText("")
  end
  d.invite:SetShown(ns.IsAddonOfficer())

  local mine = ns.MySignup(event.id)
  if mine then myRole = mine.role end
  d.role:SetValue(myRole)
  for _, b in ipairs(d.statusButtons) do
    -- Your current answer is shown in gold.
    b:SetStyle(mine and mine.status == b.status and "primary" or nil)
  end
end

local function RefreshGroup(event)
  local members = ns.CurrentRaidMembers()
  local byKey = {}
  if event then
    local _, signups = ns.Signups(event.id)
    byKey = signups
  end
  for _, m in ipairs(members) do
    m.signup = byKey[ns.Key(m.name)]
    m.dkp = ns.Balance(m.name)
  end
  P.group:SetEmptyText("You're not in a raid group. When you are, everyone in it shows here with their sign-up and DKP.")
  P.group:SetItems(members)
  local inGuild = 0
  for _, m in ipairs(members) do if m.inGuild then inGuild = inGuild + 1 end end
  P.groupInfo:SetText(IsInRaid()
    and ("%d in your raid, %d of them guild members.%s"):format(#members, inGuild,
      event and (" Sign-ups shown for " .. event.title .. ".") or "")
    or "You're not in a raid group.")

  local session = ns.ActiveSession()
  local standby = session and ns.StandbyList(session.id) or {}
  if session then
    P.standbyText:SetText(#standby > 0 and table.concat(standby, ", ")
      or (UI.Code("muted") .. "Nobody. Standby members earn the same DKP as the raid.|r"))
  else
    P.standbyText:SetText(UI.Code("muted") .. "Start the raid to add standby members.|r")
  end
  local officer = ns.IsAddonOfficer()
  for _, w in ipairs({ P.standbyName, P.standbyAdd, P.standbyRemove }) do
    w:SetShown(officer)
    UI.SetEnabled(w, session ~= nil)
  end
end

local function RefreshSession()
  local s = ns.ActiveSession()
  local officer = ns.IsAddonOfficer()
  local dkp = ns.UsesDKP()
  if s then
    local text = ("%sIn progress:|r %s, started %s by %s."):format(UI.Code("good"), s.title, date("%H:%M", s.t), s.a)
    if dkp and s.hourly > 0 then
      text = text .. (" %d DKP per hour%s."):format(s.hourly, (s.boss or 0) > 0 and (", " .. s.boss .. " per boss") or "")
      local mine = ns.db.session
      if mine and mine.id == s.id then
        text = text .. (" Next hourly award in %d min."):format(math.max(0, math.ceil((mine.nextTick - GetServerTime()) / 60)))
      end
    end
    P.sessionText:SetText(text)
    P.sessionButton:SetText("End raid")
    P.sessionButton:SetStyle(nil)
  else
    P.sessionText:SetText(not officer and "No raid night in progress."
      or (dkp and "Not started. Starting gives everyone in the raid the On time DKP, then hourly and boss DKP."
      or "Not started. Starting records who's in the raid for attendance."))
    P.sessionButton:SetText("Start raid")
    P.sessionButton:SetStyle("primary")
  end
  -- The DKP amounts for starting a raid night: only when the guild uses DKP,
  -- and not while one is running (the text above says what that one gives).
  for _, w in ipairs({ P.onTime, P.hourly, P.boss, P.onTimeLabel, P.hourlyLabel, P.bossLabel }) do
    w:SetShown(officer and dkp and not s)
  end
  P.sessionButton:SetShown(officer)
  for _, w in ipairs({ P.onTime, P.hourly, P.boss, P.sessionButton }) do UI.SetEnabled(w, officer) end
end

local function Refresh()
  -- The switch at the top was set from outside (ns.OpenPanel with a view).
  if view ~= "new" and P.view.value ~= view then view = P.view.value end
  local events = ns.RaidEvents()
  if selectedId and not ns.RaidEvent(selectedId) then selectedId = nil end
  if not selectedId and events[1] then selectedId = events[1].id end
  P.list:SetItems(events)
  local event = ns.RaidEvent(selectedId)

  local officer = ns.IsAddonOfficer()
  P.newButton:SetShown(officer)
  P.cancelButton:SetShown(officer)
  UI.SetEnabled(P.cancelButton, officer and event ~= nil)

  P.event:SetShown(view == "event")
  P.groupFrame:SetShown(view == "group")
  P.newFrame:SetShown(view == "new")
  P.view:SetShown(view ~= "new")
  if view ~= "new" then P.view:SetValue(view) end
  -- Plan and Progress use the whole page.
  local full = FULL[view] or false
  for _, f in ipairs({ P.raidsCard, P.night, P.right }) do f:SetShown(not full) end
  UI.RaidProgress.frame:SetShown(view == "progress")
  UI.RaidPlanView.frame:SetShown(view == "plan")
  if view == "plan" then UI.RaidPlanView.Refresh(event) return end
  if view == "progress" then UI.RaidProgress.Refresh() return end

  if view == "event" then RefreshEvent(event)
  elseif view == "group" then RefreshGroup(event)
  else
    P.newDayText:SetText(ns.Date("%A, %b %d", dayStart(newDay)))
  end
  RefreshSession()
end

------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------
StaticPopupDialogs["IMPERIUM_CANCEL_RAID"] = {
  text = "Cancel %s for everyone?",
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, id) ns.CancelRaid(id) end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

local function FieldLabel(parent, text, x, y)
  local fs = UI.Label(parent, text:upper(), "Label")
  fs:SetPoint("TOPLEFT", x, y)
  return fs
end

-- A bordered box holding a table: heading row and a scrolling list.
local function TableBox(parent, heads)
  local box = CreateFrame("Frame", nil, parent)
  UI.Border(box, C.cardEdge[1], C.cardEdge[2], C.cardEdge[3], 1)
  local headBg = box:CreateTexture(nil, "BACKGROUND")
  headBg:SetPoint("TOPLEFT")
  headBg:SetPoint("TOPRIGHT")
  headBg:SetHeight(24)
  headBg:SetColorTexture(C.window[1], C.window[2], C.window[3], 1)
  local rule = box:CreateTexture(nil, "BORDER")
  rule:SetPoint("TOPLEFT", 0, -24)
  rule:SetPoint("TOPRIGHT", 0, -24)
  rule:SetHeight(1)
  rule:SetColorTexture(C.cardEdge[1], C.cardEdge[2], C.cardEdge[3], 1)
  for _, h in ipairs(heads) do
    local fs = UI.Label(box, h[1], "Label")
    if h[3] then
      fs:SetPoint("TOPRIGHT", h[2] - SCROLL_ROOM, -8)
      fs:SetJustifyH("RIGHT")
    else
      fs:SetPoint("TOPLEFT", h[2], -8)
    end
  end
  return box
end

local function RowLine(row)
  local line = row:CreateTexture(nil, "BORDER")
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")
  line:SetHeight(1)
  line:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
end

local function BuildEventView(parent)
  local d = CreateFrame("Frame", nil, parent)
  d:SetAllPoints()
  P.event = d

  d.title = UI.Label(d, "", "Title")
  d.title:SetPoint("TOPLEFT", 18, -16)
  d.when = UI.Label(d, "", "Small")
  d.when:SetPoint("TOPLEFT", 18, -40)
  d.when:SetWidth(RIGHT_W - 36 - 190) -- clear of the counts on the right
  d.when:SetWordWrap(false)
  d.notes = UI.Label(d, "", "MutedSmall")
  d.notes:SetPoint("TOPLEFT", 18, -57)
  d.notes:SetWidth(RIGHT_W - 200)
  d.notes:SetWordWrap(false)

  -- Accepted / tentative / declined, top right.
  d.stats = {}
  local x = -18
  for _, s in ipairs({ { "decline", "declined" }, { "tentative", "tentative" }, { "accept", "accepted" } }) do
    local stat = CreateFrame("Frame", nil, d)
    stat:SetSize(58, 38)
    stat:SetPoint("TOPRIGHT", x, -14)
    stat.number = UI.Label(stat, "", "Heading")
    stat.number:SetPoint("TOP", 0, 0)
    stat.number:SetJustifyH("CENTER")
    local word = UI.Label(stat, s[2], "MutedSmall")
    word:SetPoint("TOP", 0, -20)
    word:SetJustifyH("CENTER")
    d.stats[s[1]] = stat
    x = x - 60
  end

  -- Class chips.
  d.chipRow = CreateFrame("Frame", nil, d)
  d.chipRow:SetPoint("TOPLEFT", 18, -80)
  d.chipRow:SetSize(RIGHT_W - 36, 22)
  d.chips = {}
  for i = 1, MAX_CHIPS do
    local chip = CreateFrame("Frame", nil, d.chipRow)
    chip:SetHeight(22)
    UI.Fill(chip, C.control)
    UI.Border(chip, C.edge[1], C.edge[2], C.edge[3], 1)
    chip.text = UI.Label(chip, "", "Small")
    chip.text:SetPoint("CENTER")
    d.chips[i] = chip
  end

  -- The makeup banner: what the raid is short of, or that it's covered.
  local banner = CreateFrame("Frame", nil, d)
  banner:SetPoint("TOPLEFT", 18, -112)
  banner:SetSize(RIGHT_W - 36, 28)
  banner.fill = UI.Fill(banner, C.warn, 0.08)
  banner.border = UI.Border(banner, C.warn[1], C.warn[2], C.warn[3], 0.35)
  banner.icon = UI.Icon(banner, "warning", 14, C.warn)
  banner.icon:SetPoint("LEFT", 10, 0)
  banner.text = UI.Label(banner, "", "Small")
  banner.text:SetPoint("LEFT", banner.icon, "RIGHT", 8, 0)
  banner.text:SetPoint("RIGHT", -10, 0)
  banner.text:SetWordWrap(false)
  banner:EnableMouse(true)
  banner:SetScript("OnEnter", function(self)
    if not selectedId then return end
    local mk = ns.RaidMakeup(selectedId)
    if mk.accept == 0 then return end
    local tanks, healers = ns.RolesWanted(mk.accept)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Raid makeup")
    GameTooltip:AddLine(("For %d players: about %d tank%s and %d healer%s (one healer per five players)."):format(
      mk.accept, tanks, tanks == 1 and "" or "s", healers, healers == 1 and "" or "s"), 1, 1, 1, true)
    GameTooltip:AddLine(("Signed up: %d tank, %d healer, %d DPS. Tentative: %d tank, %d healer, %d DPS."):format(
      mk.roles.tank, mk.roles.healer, mk.roles.dps, mk.maybe.tank, mk.maybe.healer, mk.maybe.dps), 1, 1, 1, true)
    GameTooltip:AddLine("Once 10 have accepted, classes in the guild that nobody has signed up with are listed too.",
      0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  banner:SetScript("OnLeave", function() GameTooltip:Hide() end)
  d.banner = banner

  -- Your sign-up: role, then your answer.
  d.role = UI.Segmented(d, { { "tank", "Tank" }, { "healer", "Healer" }, { "dps", "DPS" } }, function(v)
    myRole = v
    local mine = selectedId and ns.MySignup(selectedId)
    if mine then ns.SignUp(selectedId, mine.status, myRole) end
    ns.RefreshPanel()
  end)
  d.role:SetPoint("TOPLEFT", 18, -152)
  UI.Tooltip(d.role, "Your role", "Pick the role you'll play. If you've already signed up, your sign-up changes too.")
  d.statusButtons = {}
  local prev
  for i = 3, 1, -1 do
    local s = ({ { "accept", "Accept" }, { "tentative", "Tentative" }, { "decline", "Decline" } })[i]
    local b = UI.Button(d, s[2], 72)
    b:SetHeight(26)
    b.status = s[1]
    if prev then b:SetPoint("RIGHT", prev, "LEFT", -6, 0) else b:SetPoint("TOPRIGHT", -18, -152) end
    b:SetScript("OnClick", function() if selectedId then ns.SignUp(selectedId, s[1], myRole) end end)
    d.statusButtons[i] = b
    prev = b
  end

  -- Sign-ups.
  d.signupBox = TableBox(d, { { "NAME", 12 }, { "ROLE", 190 }, { "STATUS", 280 } })
  d.signupBox:SetPoint("TOPLEFT", 18, -192)
  d.signupBox:SetPoint("BOTTOMRIGHT", -18, 50)
  P.signups = UI.List(d.signupBox, RIGHT_W - 36 - 4, 450 - 192 - 50 - 26, 24,
    function(row)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("LEFT", 12, 0)
      row.name:SetWidth(170)
      row.name:SetWordWrap(false)
      row.role = UI.Label(row, "", "Small")
      row.role:SetPoint("LEFT", 190, 0)
      row.status = UI.Label(row, "", "Small")
      row.status:SetPoint("LEFT", 280, 0)
      RowLine(row)
      row:SetScript("OnClick", function(self) ns.ShowPlayerCard(self.item.name) end)
      UI.Tooltip(row, function() return Ambiguate(row.item.name, "short") end, "Click for their player card.")
    end,
    function(row, s)
      row.name:SetText(Ambiguate(s.name, "short"))
      row.name:SetTextColor(UI.ClassColor(s.classFile))
      row.role:SetText(ROLE_TEXT[s.role])
      row.status:SetText(s.noShow and (UI.Code("bad") .. "No-show|r") or statusText(s.status))
      if s.notAttuned and not s.noShow then
        row.status:SetText(statusText(s.status) .. "  " .. UI.Code("warn") .. ns.TF("Not attuned (%s)", s.notAttuned.short) .. "|r")
      end
    end, true)
  P.signups.frame:SetPoint("TOPLEFT", d.signupBox, "TOPLEFT", 0, -25)

  d.noShows = UI.Label(d, "", "Small")
  d.noShows:SetPoint("BOTTOMLEFT", 18, 22)
  d.noShows:SetWidth(RIGHT_W - 200)
  d.noShows:SetWordWrap(false)
  d.invite = UI.Button(d, "Invite sign-ups", 130)
  d.invite:SetHeight(26)
  d.invite:SetPoint("BOTTOMRIGHT", -18, 14)
  d.invite:SetScript("OnClick", function() if selectedId then ns.InviteSignups(selectedId) end end)
  UI.Tooltip(d.invite, "Invite everyone who signed up", "Invites every online guild member who accepted or is tentative and isn't in your group yet. A party is turned into a raid automatically.")

  local page = parent:GetParent()
  UI.Grow(page, P.signups, 1, 1)
  UI.Grow(page, banner, 1, 0)
end

local function BuildGroupView(parent)
  local g = CreateFrame("Frame", nil, parent)
  g:SetAllPoints()
  P.groupFrame = g
  UI.Label(g, "Current raid group", "Title"):SetPoint("TOPLEFT", 18, -16)
  P.groupInfo = UI.Label(g, "", "Small")
  P.groupInfo:SetPoint("TOPLEFT", 18, -40)
  P.groupInfo:SetWidth(RIGHT_W - 36)

  local heads = { { "NAME", 12 }, { "ROLE", 170 }, { "SIGNED UP", 240 }, { "DKP", -12, true } }
  local box = TableBox(g, heads)
  box:SetPoint("TOPLEFT", 18, -66)
  box:SetPoint("BOTTOMRIGHT", -18, 104)
  P.group = UI.List(box, RIGHT_W - 36 - 4, 450 - 66 - 104 - 26, 24,
    function(row)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("LEFT", 12, 0)
      row.name:SetWidth(150)
      row.name:SetWordWrap(false)
      row.role = UI.Label(row, "", "Small")
      row.role:SetPoint("LEFT", 170, 0)
      row.signup = UI.Label(row, "", "Small")
      row.signup:SetPoint("LEFT", 240, 0)
      row.dkp = UI.Label(row, "", "Number")
      row.dkp:SetPoint("RIGHT", -12, 0)
      row.dkp:SetJustifyH("RIGHT")
      RowLine(row)
    end,
    function(row, m)
      local r, gg, b = UI.ClassColor(m.classFile)
      row.name:SetText(Ambiguate(m.name, "short") .. (m.inGuild and "" or (" " .. UI.Code("muted") .. "(not in guild)|r")))
      row.name:SetTextColor(r, gg, b)
      row.name:SetAlpha(m.online and 1 or 0.5)
      row.role:SetText(m.role and ROLE_TEXT[m.role] or (UI.Code("faint") .. "-|r"))
      row.signup:SetText(m.signup and statusText(m.signup.status) or (UI.Code("muted") .. "Not signed up|r"))
      row.dkp:SetText(m.inGuild and m.dkp or "")
    end, true)
  P.group.frame:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -25)

  local standbyLabel = UI.Label(g, "Standby", "Heading")
  standbyLabel:SetPoint("BOTTOMLEFT", 18, 78)
  P.standbyText = UI.Label(g, "", "Small")
  P.standbyText:SetPoint("BOTTOMLEFT", 18, 58)
  P.standbyText:SetWidth(RIGHT_W - 36)
  P.standbyText:SetWordWrap(false)
  P.standbyName = UI.EditBox(g, 160, 40)
  P.standbyName:SetHeight(26)
  P.standbyName:SetPoint("BOTTOMLEFT", 18, 16)
  P.standbyName.hint = UI.Label(P.standbyName, "Member name", "MutedSmall")
  P.standbyName.hint:SetPoint("LEFT", 8, 0)
  P.standbyName:HookScript("OnTextChanged", function(self) self.hint:SetShown((self:GetText() or "") == "") end)
  P.standbyAdd = UI.Button(g, "Add to standby", 120)
  P.standbyAdd:SetHeight(26)
  P.standbyAdd:SetPoint("LEFT", P.standbyName, "RIGHT", 8, 0)
  UI.Tooltip(P.standbyAdd, "Add to standby", "Puts the guild member named in the box on standby for tonight's raid night. They earn the same DKP as the raid, and count as attending.")
  P.standbyAdd:SetScript("OnClick", function()
    ns.AddStandby(P.standbyName:GetText())
    P.standbyName:SetText("")
    ns.RefreshPanel()
  end)
  P.standbyRemove = UI.Button(g, "Remove", 80)
  P.standbyRemove:SetHeight(26)
  P.standbyRemove:SetPoint("LEFT", P.standbyAdd, "RIGHT", 6, 0)
  UI.Tooltip(P.standbyRemove, "Remove from standby", "Takes the guild member named in the box off standby.")
  P.standbyRemove:SetScript("OnClick", function()
    ns.RemoveStandby(P.standbyName:GetText())
    P.standbyName:SetText("")
    ns.RefreshPanel()
  end)

  UI.Grow(parent:GetParent(), P.group, 1, 1)
end

local function BuildNewView(parent)
  local n = CreateFrame("Frame", nil, parent)
  n:SetAllPoints()
  P.newFrame = n
  UI.Label(n, "Schedule a raid", "Title"):SetPoint("TOPLEFT", 18, -16)
  UI.Label(n, "Guild members can sign up as soon as it's created, and get a reminder before it starts.", "MutedSmall")
    :SetPoint("TOPLEFT", 18, -40)

  FieldLabel(n, "Raid", 18, -68)
  P.newTitle = UI.EditBox(n, 300, 40)
  P.newTitle:SetHeight(26)
  P.newTitle:SetPoint("TOPLEFT", 18, -80)

  FieldLabel(n, "Day", 18, -118)
  local prev = UI.Button(n, "<", 26)
  prev:SetHeight(26)
  prev:SetPoint("TOPLEFT", 18, -130)
  P.newDayText = UI.Label(n, "", "Subheading")
  P.newDayText:SetPoint("LEFT", prev, "RIGHT", 10, 0)
  P.newDayText:SetWidth(150)
  local nextB = UI.Button(n, ">", 26)
  nextB:SetHeight(26)
  nextB:SetPoint("LEFT", prev, "RIGHT", 170, 0)
  prev:SetScript("OnClick", function() newDay = math.max(0, newDay - 1); ns.RefreshPanel() end)
  nextB:SetScript("OnClick", function() newDay = math.min(60, newDay + 1); ns.RefreshPanel() end)

  FieldLabel(n, "Start time (24-hour, your time)", 18, -168)
  P.newTime = UI.EditBox(n, 70, 5)
  P.newTime:SetHeight(26)
  P.newTime:SetPoint("TOPLEFT", 18, -180)
  P.newTime:SetText("20:00")

  FieldLabel(n, "Notes (optional)", 18, -218)
  P.newNotes = UI.EditBox(n, RIGHT_W - 36, 120)
  P.newNotes:SetHeight(26)
  P.newNotes:SetPoint("TOPLEFT", 18, -230)

  local create = UI.Button(n, "Create raid", 120, "primary")
  create:SetHeight(28)
  create:SetPoint("TOPLEFT", 18, -276)
  create:SetScript("OnClick", function()
    local seconds = parseTime(P.newTime:GetText())
    if not seconds then ns.Say("Enter the start time like 20:00.") return end
    local e = ns.CreateRaid(strtrim(P.newTitle:GetText() or ""), dayStart(newDay) + seconds,
      strtrim(P.newNotes:GetText() or ""))
    if e then
      selectedId, view = e.id, "event"
      P.newTitle:SetText("")
      P.newNotes:SetText("")
      ns.RefreshPanel()
    end
  end)
  local back = UI.Button(n, "Cancel", 90)
  back:SetHeight(28)
  back:SetPoint("LEFT", create, "RIGHT", 6, 0)
  back:SetScript("OnClick", function() view = "event"; P.view:SetValue("event"); ns.RefreshPanel() end)
end

local function Build(page)
  -- Header: the selected raid, or your raid group right now.
  P.view = UI.Segmented(page.headerBar, { { "event", "Raid" }, { "plan", "Plan" }, { "group", "Group" },
    { "progress", "Progress" } }, function(v) view = v; ns.RefreshPanel() end)
  P.view:SetPoint("RIGHT")
  TAB.view = P.view
  local check = UI.Button(page.headerBar, "Raid check", 104)
  check:SetHeight(26)
  check:SetPoint("RIGHT", P.view, "LEFT", -8, 0)
  check:SetScript("OnClick", function() ns.ShowRaidCheck() end)
  UI.Tooltip(check, "Raid check", "Each raid member's flask, elixirs, food and world buffs, the least prepared first. Outside combat only.")
  UI.Tooltip(P.view, "Switch view", "Raid: the selected raid's sign-ups. Plan: its groups and bench. Group: everyone in your raid group right now. "
    .. "Progress: the bosses the guild has killed in each raid. (The calendar is in Events > Calendar.)")

  -- Upcoming raids.
  local raids = CreateFrame("Frame", nil, page)
  P.raidsCard = raids
  raids:SetPoint("TOPLEFT", 1, -1)
  raids:SetSize(LEFT_W - 2, 252)
  UI.Card(raids, 1)
  UI.Label(raids, "UPCOMING RAIDS", "Label"):SetPoint("TOPLEFT", 14, -13)
  local rule = raids:CreateTexture(nil, "BORDER")
  rule:SetPoint("TOPLEFT", 0, -32)
  rule:SetPoint("TOPRIGHT", 0, -32)
  rule:SetHeight(1)
  rule:SetColorTexture(C.cardEdge[1], C.cardEdge[2], C.cardEdge[3], 1)

  P.list = UI.List(raids, LEFT_W - 24, 252 - 33 - 46, 42,
    function(row)
      row.sel = row:CreateTexture(nil, "BACKGROUND")
      row.sel:SetAllPoints()
      row.sel:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.10)
      row.bar = row:CreateTexture(nil, "BORDER")
      row.bar:SetPoint("TOPLEFT")
      row.bar:SetPoint("BOTTOMLEFT")
      row.bar:SetWidth(2)
      row.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
      row.title = UI.Label(row, "", "Subheading")
      row.title:SetPoint("TOPLEFT", 14, -7)
      row.title:SetPoint("RIGHT", -80, 0)
      row.title:SetWordWrap(false)
      row.when = UI.Label(row, "", "MutedSmall")
      row.when:SetPoint("TOPLEFT", 14, -24)
      row.count = UI.Label(row, "", "Heading")
      row.count:SetPoint("RIGHT", -12, 4)
      row.count:SetJustifyH("RIGHT")
      row.count:SetTextColor(C.good[1], C.good[2], C.good[3])
      row.mine = UI.Label(row, "", "MutedSmall")
      row.mine:SetPoint("TOPRIGHT", -12, -25)
      row.mine:SetJustifyH("RIGHT")
      row.warn = UI.Icon(row, "warning", 13, C.warn)
      row.warn:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
      RowLine(row)
      row:SetScript("OnClick", function(self)
        selectedId = self.item.id
        if view == "new" or FULL[view] then view = "event"; P.view:SetValue("event") end
        ns.RefreshPanel()
      end)
    end,
    function(row, e)
      local on = e.id == selectedId
      row.sel:SetShown(on)
      row.bar:SetShown(on)
      row.title:SetText(e.title)
      row.when:SetText(ns.Date("%a %b %d · %H:%M", e.start))
      local c = ns.SignupCounts(e.id)
      local mine = ns.MySignup(e.id)
      row.count:SetText(c.accept)
      local cc = c.accept > 0 and C.good or C.faint -- nobody yet: grey, not green
      row.count:SetTextColor(cc[1], cc[2], cc[3])
      row.mine:SetText(mine and statusText(mine.status) or "")
      row.warn:SetShown(c.accept > 0 and #ns.RaidMakeup(e.id).warnings > 0)
    end, true)
  P.list.frame:SetPoint("TOPLEFT", raids, "TOPLEFT", 0, -33)
  P.list:SetEmptyText("No raids scheduled.")

  local half = (LEFT_W - 2 - 34) / 2
  P.newButton = UI.Button(raids, "New raid", half)
  P.newButton:SetHeight(26)
  P.newButton:SetPoint("BOTTOMLEFT", 14, 12)
  UI.Tooltip(P.newButton, "Schedule a raid", "Adds a raid to the calendar for guild members to sign up to. They get a reminder before it starts.")
  P.newButton:SetScript("OnClick", function() view = "new"; ns.RefreshPanel() end)
  P.cancelButton = UI.Button(raids, "Cancel raid", half)
  P.cancelButton:SetHeight(26)
  P.cancelButton:SetPoint("LEFT", P.newButton, "RIGHT", 6, 0)
  UI.Tooltip(P.cancelButton, "Cancel raid", "Cancels the selected raid for everyone. You'll be asked to confirm first.")
  P.cancelButton:SetScript("OnClick", function()
    local e = ns.RaidEvent(selectedId)
    if e then StaticPopup_Show("IMPERIUM_CANCEL_RAID", e.title, nil, e.id) end
  end)

  -- Raid night (attendance DKP).
  local night = CreateFrame("Frame", nil, page)
  P.night = night
  night:SetPoint("TOPLEFT", 1, -265)
  night:SetSize(LEFT_W - 2, 184)
  UI.Card(night, 1)
  UI.Label(night, "Raid night", "Heading"):SetPoint("TOPLEFT", 14, -12)
  P.sessionText = UI.Label(night, "", "MutedSmall")
  P.sessionText:SetPoint("TOPLEFT", 14, -32)
  P.sessionText:SetWidth(LEFT_W - 32)
  P.sessionText:SetSpacing(2)
  local third = (LEFT_W - 2 - 28 - 16) / 3
  local function rate(label, x, default)
    local fs = FieldLabel(night, label, x, -92)
    local box = UI.EditBox(night, third, 4)
    box:SetHeight(24)
    box:SetPoint("TOPLEFT", x, -104)
    box:SetNumeric(true)
    box:SetText(default)
    return fs, box
  end
  P.onTimeLabel, P.onTime = rate("On time", 14, "10")
  P.hourlyLabel, P.hourly = rate("Per hour", 14 + third + 8, "10")
  P.bossLabel, P.boss = rate("Per boss", 14 + 2 * (third + 8), "0")
  P.sessionButton = UI.Button(night, "Start raid", LEFT_W - 30, "primary")
  P.sessionButton:SetHeight(28)
  P.sessionButton:SetPoint("BOTTOMLEFT", 14, 14)
  UI.Tooltip(P.sessionButton, function() return ns.ActiveSession() and "End raid" or "Start raid" end, function()
    if ns.ActiveSession() then return "Stops awarding DKP for tonight's raid night." end
    return "Starts tonight's raid night. Everyone in your raid gets the On time DKP now, Per hour DKP every hour, and Per boss DKP for each boss killed. Attendance is recorded."
  end)
  P.sessionButton:SetScript("OnClick", function()
    if ns.ActiveSession() then
      ns.EndRaidSession()
    else
      local e = ns.RaidEvent(selectedId)
      local title = e and e.title or ("Raid " .. ns.Date("%b %d"))
      ns.StartRaidSession(e and e.id or "", title, P.onTime:GetText(), P.hourly:GetText(), P.boss:GetText())
    end
    ns.RefreshPanel()
  end)

  -- The selected raid, the raid group, or the new raid form.
  local right = CreateFrame("Frame", nil, page)
  P.right = right
  right:SetPoint("TOPLEFT", RIGHT_X + 1, -1)
  right:SetSize(RIGHT_W - 2, 448)
  UI.Card(right, 1)
  BuildEventView(right)
  BuildGroupView(right)
  BuildNewView(right)

  -- Plan and Progress.
  local planView = UI.RaidPlanView.Build(page)
  UI.Grow(page, planView, 1, 1)
  local prog = UI.RaidProgress
  prog.Build(page)

  -- A bigger window: more upcoming raids show, raid night moves down, and the right side grows.
  table.insert(page.growth, function(dw, dh)
    UI.RaidPlanView.Resize(740 + dw, 450 + dh)
  end)
  UI.Grow(page, prog.frame, 1, 1)
  UI.Grow(page, prog.card, 1, 1)
  UI.Grow(page, prog.bosses, 1, 1)
  UI.Grow(page, prog.raidsCard, 0, 1)
  UI.Grow(page, prog.raids, 0, 1)
  UI.Grow(page, raids, 0, 1)
  UI.Grow(page, P.list, 0, 1)
  UI.Follow(page, night, 0, 1)
  UI.Grow(page, right, 1, 1)
end

-- The header's subtitle: how many raids are coming up, and whether one is on.
local function Subtitle()
  local n = #ns.RaidEvents()
  local text = n == 0 and ns.T("No raids scheduled") or ns.TP(n, "1 raid scheduled", "%d raids scheduled", n)
  if ns.ActiveSession() then text = text .. " · " .. ns.T("raid night in progress") end
  return text
end

-- Pick a different raid without changing the view (the Plan view's arrows).
function ns.PickRaid(id)
  selectedId = id
  ns.RefreshPanel()
end

-- Open a raid on the Raids tab (from the calendar, say).
function ns.SelectRaid(id)
  selectedId = id
  view = "event"
  if P.view then P.view:SetValue("event") end
  ns.OpenPanel("raids")
end

TAB = { id = "raids", title = "Raids", build = Build, refresh = Refresh, subtitle = Subtitle }
UI.AddTab(TAB)
