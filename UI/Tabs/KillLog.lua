--[[
  Warcrest
  Kills tab: PvP kills by guild members as a table, this period's leader,
  and the Top Head Hunters board. The period and kill type are picked in
  the panel's header.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local P = {}
local TOP_N = 8          -- places on the board
local TABLE_W = 480      -- the kill table; the cards on the right fill the rest
local ROW_H = 34
local SIDE_X = TABLE_W + 14
local SIDE_W = 740 - SIDE_X

StaticPopupDialogs["IMPERIUM_REMOVE_KILL"] = {
  text = "Remove this kill for the whole guild?\n\n%s",
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, k) if k then ns.RemoveKill(k) end end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["IMPERIUM_CLEAR_KILLS"] = {
  text = "Clear the kill log for the whole guild? This can't be undone.",
  button1 = YES,
  button2 = NO,
  OnAccept = function() ns.ClearKillLog() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

-- How each period is described: { leader card label, subtitle suffix }.
local PERIOD_TEXT = {
  month = { "Leading this month", "this month" },
  lastmonth = { "Leading last month", "last month" },
  week = { "Leading this week", "in the last 7 days" },
  all = { "Leading of all time", "in all" },
}

-- The kills for the picked period and type.
local function shownKills()
  local period = P.period and P.period.value or "month"
  local fromT, toT
  if period == "month" then
    fromT, toT = ns.MonthRange(0)
  elseif period == "lastmonth" then
    fromT, toT = ns.MonthRange(-1)
  elseif period == "week" then
    fromT = time() - 7 * 86400
  end
  return ns.QueryKills("all", fromT, toT), period
end

-- The second line under a kill's zone.
local function detail(k)
  local assists = ns.Assists(k)
  if #assists > 0 then return ns.TF("Assist: %s", table.concat(assists, ", ")) end
  if k.bounty then return "Wanted bounty claimed" end
  return "World PvP"
end

local function Refresh()
  local kills, period = shownKills()
  P.clear:SetShown(ns.IsGuildMaster()) -- only the Guild Master can clear logs
  P.list:SetEmptyText(ns.EmptyHint(period == "all" and "No kills recorded yet." or "No kills in this period yet."))
  P.list:SetItems(kills)

  -- This period's leader.
  local top = ns.KillStats(kills, TOP_N)
  P.leaderLabel:SetText(PERIOD_TEXT[period][1]:upper())
  local first, second = top[1], top[2]
  if first then
    P.leaderName:SetText(first.name)
    P.leaderCount:SetText(first.count)
    local sub
    if not second then
      sub = ns.T("The only head hunter so far")
    elseif second.count == first.count then
      sub = ns.T("Tied with") .. " " .. second.name
    else
      sub = ns.TF("%d ahead of %s", first.count - second.count, second.name)
    end
    -- Their title, in gold, ahead of the rest.
    local title = ns.TitleOf and ns.TitleOf(first.name)
    P.leaderSub:SetText(title and (UI.Code("accent") .. ns.T(title) .. "|r  ·  " .. sub) or sub)
  else
    P.leaderName:SetText("Nobody yet")
    P.leaderCount:SetText("")
    P.leaderSub:SetText("The first kill takes the lead")
  end

  -- The board, with a bar for each place against the leader.
  local most = first and first.count or 1
  for i, row in ipairs(P.board) do
    local e = top[i]
    row.entry = e
    row:SetShown(e ~= nil)
    if e then
      row.rank:SetText(i)
      row.name:SetText(e.name)
      row.count:SetText(e.count)
      local c = i == 1 and C.accent or { 0.29, 0.33, 0.40 }
      row.fill:SetColorTexture(c[1], c[2], c[3], 1)
      row.fill:SetWidth(math.max(2, (SIDE_W - 62) * e.count / most))
    end
  end
  P.boardEmpty:SetShown(first == nil)

  -- The longest streak in this period.
  local fromT, toT = ns.MonthRange(0)
  if period == "lastmonth" then fromT, toT = ns.MonthRange(-1)
  elseif period == "week" then fromT, toT = time() - 7 * 86400, nil
  elseif period == "all" then fromT, toT = nil, nil end
  local best = ns.BestStreaks(fromT, toT, 1)[1]
  P.streak:SetText(best and ns.TF("Best streak: %s · %d kills in a row", UI.Code("text") .. best.name .. "|r", best.count)
    or ns.T("Best streak: none yet"))

  -- Last month's winner.
  local lastFrom, lastTo, lastName = ns.MonthRange(-1)
  local champ = ns.KillStats(ns.QueryKills("all", lastFrom, lastTo), 1)[1]
  P.champion:SetText(champ and ns.TF(champ.count == 1 and "%s champion: %s · 1 kill" or "%s champion: %s · %d kills",
    lastName, UI.Code("text") .. champ.name .. "|r", champ.count) or ns.TF("No champion for %s", lastName))
end

-- The header's subtitle: how many kills the table shows.
local function Subtitle()
  local kills, period = shownKills()
  return ns.TF("PvP kills by guild members · %d %s", #kills, ns.T(PERIOD_TEXT[period][2]))
end

local function Column(parent, text, x, right)
  local fs = UI.Label(parent, text, "Label")
  if right then fs:SetPoint("RIGHT", parent, "RIGHT", x, 0) else fs:SetPoint("LEFT", x, 0) end
  return fs
end

------------------------------------------------------------------------
-- Column widths: drag the borders between the column headings, or
-- double-click one to fit the column to its longest name. Where takes
-- whatever room is left.
------------------------------------------------------------------------
local COLUMNS = { "killer", "victim" }          -- the columns with a border you can drag
local DEFAULT_WIDTH = { killer = 86, victim = 96 }
local MIN_WIDTH, MIN_WHERE = 50, 90
local GAP, WHEN_W = 8, 92                       -- space between columns; room for the time

local function colWidth(col)
  local saved = ns.db.killColumns and ns.db.killColumns[col]
  return saved or DEFAULT_WIDTH[col]
end

-- Where each column starts and how wide it is, for a row this wide.
local function columnLayout(rowWidth)
  local killerX = 12
  local victimX = killerX + colWidth("killer") + GAP
  local whereX = victimX + colWidth("victim") + GAP
  return {
    killer = { killerX, colWidth("killer") },
    victim = { victimX, colWidth("victim") },
    where = { whereX, math.max(MIN_WHERE, rowWidth - whereX - WHEN_W) },
  }
end

local function rowWidth() return (P.list and P.list.width or (TABLE_W - 24)) - 4 end

local function layoutRow(row, L)
  row.killer:ClearAllPoints()
  row.killer:SetPoint("LEFT", L.killer[1], 0)
  row.killer:SetWidth(L.killer[2])
  row.victim:ClearAllPoints()
  row.victim:SetPoint("LEFT", L.victim[1], 0)
  row.victim:SetWidth(L.victim[2])
  row.zone:ClearAllPoints()
  row.zone:SetPoint("TOPLEFT", L.where[1], -5)
  row.zone:SetWidth(L.where[2])
  row.detail:ClearAllPoints()
  row.detail:SetPoint("TOPLEFT", L.where[1], -19)
  row.detail:SetWidth(L.where[2])
end

-- Put the headings, borders and every row's text where the widths say.
local function relayout()
  if not P.heads then return end
  local L = columnLayout(rowWidth())
  for col, fs in pairs(P.heads) do
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", L[col][1], 0)
  end
  for i, col in ipairs(COLUMNS) do
    local h = P.handles[i]
    h:ClearAllPoints()
    h:SetPoint("CENTER", P.head, "LEFT", L[col][1] + L[col][2] + GAP / 2, 0)
  end
  for _, row in ipairs(P.list.rows) do layoutRow(row, L) end
end

-- Most a column can widen before Where gets too narrow.
local function maxWidth(col)
  local others = 0
  for _, c in ipairs(COLUMNS) do if c ~= col then others = others + colWidth(c) end end
  return rowWidth() - 12 - others - 2 * GAP - WHEN_W - MIN_WHERE
end

function ns.SetKillColumnWidth(col, width)
  ns.db.killColumns = ns.db.killColumns or {}
  ns.db.killColumns[col] = math.floor(math.max(MIN_WIDTH, math.min(maxWidth(col), width)))
  relayout()
end

-- The width of a column's longest name among the kills shown.
local function longest(col)
  local most = 0
  for _, row in ipairs(P.list.rows) do
    if row:IsShown() then
      local fs = row[col]
      local w = (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()) or fs:GetStringWidth()
      most = math.max(most, w)
    end
  end
  return most + 4
end

local function makeHandle(head, i)
  local col = COLUMNS[i]
  local h = CreateFrame("Button", nil, head)
  h:SetSize(10, 28)
  local line = h:CreateTexture(nil, "ARTWORK")
  line:SetPoint("TOP", 0, -7)
  line:SetPoint("BOTTOM", 0, 7)
  line:SetWidth(1)
  line:SetColorTexture(C.edge[1], C.edge[2], C.edge[3], 1)
  local function paint(on)
    local c = on and C.accent or C.edge
    line:SetColorTexture(c[1], c[2], c[3], 1)
  end
  h:SetScript("OnEnter", function(self)
    paint(true)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Column width")
    GameTooltip:AddLine("Drag to resize. Double-click to fit the longest name.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  h:SetScript("OnLeave", function(self)
    if not self.dragging then paint(false) end
    GameTooltip:Hide()
  end)
  h:SetScript("OnMouseDown", function(self)
    local x = GetCursorPosition()
    self.dragging = { x = x / self:GetEffectiveScale(), width = colWidth(col) }
    self:SetScript("OnUpdate", function(me)
      local now = GetCursorPosition() / me:GetEffectiveScale()
      ns.SetKillColumnWidth(col, me.dragging.width + now - me.dragging.x)
    end)
  end)
  h:SetScript("OnMouseUp", function(self)
    self.dragging = nil
    self:SetScript("OnUpdate", nil)
    if not self:IsMouseOver() then paint(false) end
  end)
  h:SetScript("OnDoubleClick", function() ns.SetKillColumnWidth(col, longest(col)) end)
  return h
end

local function BuildTable(page)
  local card = CreateFrame("Frame", nil, page)
  P.card = card
  card:SetPoint("TOPLEFT", 1, -1)
  card:SetSize(TABLE_W - 2, 420)
  UI.Card(card, 1)

  local head = CreateFrame("Frame", nil, card)
  head:SetPoint("TOPLEFT")
  head:SetPoint("TOPRIGHT")
  head:SetHeight(28)
  P.head = head
  P.heads = { killer = Column(head, "KILLER", 12), victim = Column(head, "VICTIM", 104), where = Column(head, "WHERE", 208) }
  Column(head, "WHEN", -32, true) -- lines up with the times, left of the scroll bar
  local rule = head:CreateTexture(nil, "BORDER")
  rule:SetPoint("BOTTOMLEFT")
  rule:SetPoint("BOTTOMRIGHT")
  rule:SetHeight(1)
  rule:SetColorTexture(C.cardEdge[1], C.cardEdge[2], C.cardEdge[3], 1)

  -- The rows scroll; the scroll bar sits inside the card's right edge.
  P.list = UI.List(card, TABLE_W - 24, 390, ROW_H,
    function(row)
      row.killer = UI.Label(row, "", "Subheading")
      row.killer:SetPoint("LEFT", 12, 0)
      row.killer:SetWidth(86)
      row.killer:SetWordWrap(false)
      row.killer:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
      row.victim = UI.Label(row, "", "Subheading")
      row.victim:SetPoint("LEFT", 104, 0)
      row.victim:SetWidth(96)
      row.victim:SetWordWrap(false)
      row.zone = UI.Label(row, "", "Small")
      row.zone:SetPoint("TOPLEFT", 208, -5)
      row.zone:SetWidth(140)
      row.zone:SetWordWrap(false)
      row.detail = UI.Label(row, "", "MutedSmall")
      row.detail:SetPoint("TOPLEFT", 208, -19)
      row.detail:SetWidth(140)
      row.detail:SetWordWrap(false)
      row.when = UI.Label(row, "", "MutedSmall")
      row.when:SetPoint("RIGHT", -6, 0)
      row.when:SetJustifyH("RIGHT")
      layoutRow(row, columnLayout(rowWidth()))
      local line = row:CreateTexture(nil, "BORDER")
      line:SetPoint("BOTTOMLEFT")
      line:SetPoint("BOTTOMRIGHT")
      line:SetHeight(1)
      line:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)

      row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
          if ns.IsAddonOfficer() then
            StaticPopup_Show("IMPERIUM_REMOVE_KILL", ns.DescribeKill(self.item), nil, self.item)
          end
        else
          ns.ShowPlayerCard(ns.KillingBlow(self.item))
        end
      end)
      row:SetScript("OnEnter", function(self)
        local k = self.item
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(k.victim .. (k.level and k.level > 0 and ("  (level " .. k.level .. ")") or ""), 1, 1, 1)
        GameTooltip:AddLine("Killing blow: " .. ns.TitledName(ns.KillingBlow(k)), C.accent[1], C.accent[2], C.accent[3])
        local assists = ns.Assists(k)
        if #assists > 0 then GameTooltip:AddLine("Assists: " .. table.concat(assists, ", "), 0.8, 0.8, 0.8, true) end
        GameTooltip:AddLine(k.zone .. ", " .. UI.FormatTime(k.t), 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Click for " .. ns.KillingBlow(k) .. "'s player card.", 0.6, 0.6, 0.6)
        if ns.IsAddonOfficer() then GameTooltip:AddLine("Right-click to remove this kill for the guild.", 1, 0.5, 0.5) end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    function(row, k)
      row.killer:SetText(ns.KillingBlow(k))
      row.victim:SetText(k.victim)
      row.zone:SetText(k.zone)
      row.detail:SetText(detail(k))
      row.when:SetText(ns.Date("%b %d · %H:%M", k.t))
    end, true)
  P.list.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -29)

  P.handles = {}
  for i = 1, #COLUMNS do P.handles[i] = makeHandle(head, i) end
  relayout()

  -- Under the table: how kills are credited, and the Guild Master's Clear log.
  local note = UI.Label(page, "Killer: whoever hit closest to the death (a best guess).", "MutedSmall")
  P.note = note
  note:SetPoint("TOPLEFT", 4, -431)
  note:SetWidth(TABLE_W - 100)
  note:SetWordWrap(false)
  P.clear = UI.Button(page, "Clear log", 80)
  P.clear:SetHeight(20)
  P.clear:SetPoint("TOPLEFT", page, "TOPLEFT", TABLE_W - 80, -426)
  P.clear:SetScript("OnClick", function() StaticPopup_Show("IMPERIUM_CLEAR_KILLS") end)
  UI.Tooltip(P.clear, "Clear the kill log", "Clears the kill log and the leaderboard for the whole guild. Only the Guild Master can do this, and you'll be asked to confirm.")
end

local function BuildSide(page)
  -- Who's leading.
  local lead = CreateFrame("Frame", nil, page)
  P.lead = lead
  lead:SetPoint("TOPLEFT", SIDE_X + 1, -1)
  lead:SetSize(SIDE_W - 2, 82)
  UI.Card(lead, 1)
  P.leaderLabel = UI.Label(lead, "", "Label")
  P.leaderLabel:SetPoint("TOPLEFT", 14, -13)
  P.leaderName = UI.Label(lead, "", "Display")
  P.leaderName:SetPoint("TOPLEFT", 14, -30)
  P.leaderName:SetWidth(SIDE_W - 80)
  P.leaderName:SetWordWrap(false)
  P.leaderCount = UI.Label(lead, "", "Display")
  P.leaderCount:SetPoint("TOPRIGHT", -14, -30)
  P.leaderCount:SetJustifyH("RIGHT")
  P.leaderCount:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  P.leaderSub = UI.Label(lead, "", "MutedSmall")
  P.leaderSub:SetPoint("TOPLEFT", 14, -60)

  -- Top Head Hunters.
  local board = CreateFrame("Frame", nil, page)
  P.boardCard = board
  board:SetPoint("TOPLEFT", SIDE_X + 1, -95)
  board:SetSize(SIDE_W - 2, 354)
  UI.Card(board, 1)
  local title = UI.Label(board, "TOP HEAD HUNTERS", "Label")
  title:SetPoint("TOPLEFT", 14, -13)
  -- Hover the title for how the board works.
  local why = CreateFrame("Frame", nil, board)
  why:SetPoint("TOPLEFT", 10, -8)
  why:SetSize(130, 18)
  UI.Tooltip(why, "Top Head Hunters", "Ranked by killing blows in the period picked above. The board starts fresh on the 1st of each month, and the winner is announced to the guild.")

  P.board = {}
  for i = 1, TOP_N do
    local row = CreateFrame("Frame", nil, board)
    row:SetPoint("TOPLEFT", 0, -34 - (i - 1) * 30)
    row:SetSize(SIDE_W - 2, 30)
    row.rank = UI.Label(row, "", "Muted")
    row.rank:SetPoint("TOPLEFT", 14, -2)
    row.rank:SetWidth(14)
    row.rank:SetJustifyH("RIGHT")
    row.name = UI.Label(row, "", "Subheading")
    row.name:SetPoint("TOPLEFT", 36, -2)
    row.name:SetWidth(SIDE_W - 100)
    row.name:SetWordWrap(false)
    row.count = UI.Label(row, "", "Number")
    row.count:SetPoint("TOPRIGHT", -14, -2)
    row.count:SetJustifyH("RIGHT")
    local track = row:CreateTexture(nil, "BORDER")
    track:SetPoint("TOPLEFT", 36, -19)
    track:SetPoint("TOPRIGHT", -14, -19)
    track:SetHeight(3)
    track:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
    row.fill = row:CreateTexture(nil, "ARTWORK")
    row.fill:SetPoint("TOPLEFT", 36, -19)
    row.fill:SetHeight(3)
    -- Hover a name for their assists too.
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
      local e = self.entry
      if not e then return end
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:SetText(ns.TitledName(e.name))
      GameTooltip:AddLine(("%d killing blow%s, %d assist%s"):format(e.count, e.count == 1 and "" or "s",
        e.assists, e.assists == 1 and "" or "s"), 1, 1, 1)
      GameTooltip:AddLine("Click for their player card.", 0.6, 0.6, 0.6)
      GameTooltip:Show()
    end)
    row:SetScript("OnMouseUp", function(self, button)
      if button == "LeftButton" and self.entry then ns.ShowPlayerCard(self.entry.name) end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    P.board[i] = row
  end
  P.boardEmpty = UI.Label(board, "No kills in this period yet.", "Muted")
  P.boardEmpty:SetPoint("TOPLEFT", 14, -38)

  local rule = board:CreateTexture(nil, "BORDER")
  rule:SetPoint("BOTTOMLEFT", 14, 58)
  rule:SetPoint("BOTTOMRIGHT", -14, 58)
  rule:SetHeight(1)
  rule:SetColorTexture(C.cardEdge[1], C.cardEdge[2], C.cardEdge[3], 1)
  P.streak = UI.Label(board, "", "MutedSmall")
  P.streak:SetPoint("BOTTOMLEFT", 14, 36)
  P.streak:SetWidth(SIDE_W - 30)
  P.streak:SetWordWrap(false)
  local streakHover = CreateFrame("Frame", nil, board)
  streakHover:SetPoint("BOTTOMLEFT", 10, 32)
  streakHover:SetSize(SIDE_W - 22, 18)
  UI.Tooltip(streakHover, "Kill streaks", "Killing blows in a row without dying to an enemy player, each within an hour of the last. The guild hears about streaks of 3, 5, 10 and more, and when a streak of 5 or more is ended.")
  P.champion = UI.Label(board, "", "MutedSmall")
  P.champion:SetPoint("BOTTOMLEFT", 14, 14)
  P.champion:SetWidth(SIDE_W - 30)
  P.champion:SetWordWrap(false)
end

local function BuildHeader(bar)
  P.period = UI.Segmented(bar, {
    { "month", "This month" }, { "lastmonth", "Last month" }, { "week", "7 days" }, { "all", "All time" },
  }, ns.RefreshPanel)
  P.period:SetPoint("RIGHT")
end

local function Build(page)
  BuildHeader(page.headerBar)
  BuildTable(page)
  BuildSide(page)

  -- A bigger window: the table gets the extra room; the cards on the right move over.
  UI.Grow(page, P.card, 1, 1)
  UI.Grow(page, P.list, 1, 1)
  UI.Follow(page, P.note, 0, 1)
  UI.Follow(page, P.clear, 1, 1)
  table.insert(page.growth, relayout) -- a wider table gives Where more room
  UI.FollowAll(page, { P.lead, P.boardCard }, 1, 0)
  UI.Grow(page, P.boardCard, 0, 1)
end

UI.AddTab({ id = "kills", title = "Kills", build = Build, refresh = Refresh, subtitle = Subtitle })
