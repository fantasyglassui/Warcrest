--[[
  Warcrest
  The Events tab's Polls view: the guild's polls on the left (open ones
  first), the one picked on the right with its answers as bars you click to
  vote, and a form to start a new one.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local M = {}
UI.PollsView = M

local LIST_W = 290
local RIGHT_X = LIST_W + 14
local RIGHT_W = 740 - RIGHT_X
local INNER = RIGHT_W - 32
local MAX_OPTS = 6
local selected
local mode = "poll" -- "poll" or "new"
local newDays = 3

local function timeLeft(p)
  if not p.open then return UI.Code("muted") .. ns.T("Closed") .. "|r" end
  local secs = p.ends - GetServerTime()
  if secs < 3600 then return UI.Code("warn") .. ns.T("Closes within the hour") .. "|r" end
  if secs < 86400 then return UI.Code("good") .. ns.TP(math.ceil(secs / 3600), "1 hour left", "%d hours left", math.ceil(secs / 3600)) .. "|r" end
  local d = math.ceil(secs / 86400)
  return UI.Code("good") .. ns.TP(d, "1 day left", "%d days left", d) .. "|r"
end

local function BuildPoll(right)
  local v = CreateFrame("Frame", nil, right)
  v:SetAllPoints()
  M.pollFrame = v
  v.label = UI.Label(v, "", "Label")
  v.label:SetPoint("TOPLEFT", 16, -14)
  v.q = UI.Label(v, "", "Title")
  v.q:SetPoint("TOPLEFT", 16, -30)
  v.q:SetWidth(INNER)
  v.by = UI.Label(v, "", "MutedSmall")
  v.by:SetPoint("TOPLEFT", v.q, "BOTTOMLEFT", 0, -6)
  v.by:SetWidth(INNER)
  v.opts = {}
  for i = 1, MAX_OPTS do
    local b = CreateFrame("Button", nil, v)
    b:SetSize(INNER, 40)
    UI.Fill(b, C.window, 1)
    UI.Border(b, C.cardEdge[1], C.cardEdge[2], C.cardEdge[3], 1)
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetPoint("TOPLEFT", 1, -1)
    b.bar:SetPoint("BOTTOMLEFT", 1, 1)
    b.text = UI.Label(b, "", "Subheading")
    b.text:SetPoint("LEFT", 12, 0)
    b.text:SetWidth(INNER - 110)
    b.text:SetWordWrap(false)
    b.count = UI.Label(b, "", "Small")
    b.count:SetPoint("RIGHT", -12, 0)
    b.count:SetJustifyH("RIGHT")
    b:SetScript("OnClick", function(self)
      if selected then ns.VotePoll(selected, self.index) end
    end)
    UI.Tooltip(b, function() return b.text:GetText() end, function()
      local p = ns.Poll(selected)
      if not p then return "" end
      local names = {}
      for _, vote in pairs(p.votes) do if vote.choice == b.index then names[#names + 1] = vote.name end end
      table.sort(names)
      local who = #names > 0 and table.concat(names, ", ") or ns.T("Nobody yet.")
      return p.open and (who .. "\n\n" .. ns.T("Click to vote for this. You can change your vote while the poll is open.")) or who
    end)
    b.index = i
    v.opts[i] = b
  end
  v.total = UI.Label(v, "", "MutedSmall")
  v.close = UI.Button(v, "Close poll", 120)
  v.close:SetHeight(26)
  v.close:SetPoint("BOTTOMRIGHT", -16, 14)
  v.close:SetScript("OnClick", function() if selected then ns.ClosePoll(selected) end end)
  UI.Tooltip(v.close, "Close poll", "Ends the poll now for everyone. Whoever asked, or an officer, can.")
  v.empty = UI.Label(v, "", "MutedSmall")
  v.empty:SetPoint("TOPLEFT", 16, -40)
  v.empty:SetWidth(INNER)
  v.empty:SetSpacing(2)
end

local function BuildNew(right)
  local n = CreateFrame("Frame", nil, right)
  n:SetAllPoints()
  M.newFrame = n
  UI.Label(n, "NEW POLL", "Label"):SetPoint("TOPLEFT", 16, -14)
  UI.FieldLabel(n, "Question", 16, -36)
  n.q = UI.EditBox(n, INNER, 80)
  n.q:SetHeight(26)
  n.q:SetPoint("TOPLEFT", 16, -50)
  UI.FieldLabel(n, "Answers (two or more)", 16, -88)
  n.opts = {}
  for i = 1, MAX_OPTS do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local box = UI.EditBox(n, (INNER - 8) / 2, 28)
    box:SetHeight(26)
    box:SetPoint("TOPLEFT", 16 + col * ((INNER - 8) / 2 + 8), -102 - row * 32)
    n.opts[i] = box
  end
  UI.FieldLabel(n, "Open for", 16, -206)
  n.days = UI.Segmented(n, { { 1, "1 day" }, { 2, "2 days" }, { 3, "3 days" }, { 7, "A week" } },
    function(v) newDays = v end)
  n.days:SetPoint("TOPLEFT", 16, -220)
  n.create = UI.Button(n, "Start poll", 140, "primary")
  n.create:SetHeight(28)
  n.create:SetPoint("TOPLEFT", 16, -262)
  n.create:SetScript("OnClick", function()
    local answers = {}
    for _, box in ipairs(n.opts) do answers[#answers + 1] = box:GetText() end
    local e = ns.StartPoll(n.q:GetText(), answers, newDays)
    if e then
      n.q:SetText("")
      for _, box in ipairs(n.opts) do box:SetText("") end
      selected, mode = e.id, "poll"
      ns.RefreshPanel()
    end
  end)
  n.cancel = UI.Button(n, "Cancel", 100)
  n.cancel:SetHeight(28)
  n.cancel:SetPoint("LEFT", n.create, "RIGHT", 8, 0)
  n.cancel:SetScript("OnClick", function() mode = "poll"; ns.RefreshPanel() end)
  n.why = UI.Label(n, "", "MutedSmall")
  n.why:SetPoint("TOPLEFT", 16, -302)
  n.why:SetWidth(INNER)
  n.why:SetSpacing(2)
end

function M.Build(page)
  local f = CreateFrame("Frame", nil, page)
  M.frame = f
  f:SetPoint("TOPLEFT")
  f:SetSize(740, 450)

  local card = UI.Box(f, 0, 0, LIST_W, 450)
  M.card = card
  UI.Label(card, "POLLS", "Label"):SetPoint("TOPLEFT", 14, -13)
  M.list = UI.List(card, LIST_W - 24, 450 - 40 - 46, 58,
    function(row)
      UI.RowSelection(row)
      row.q = UI.Label(row, "", "Subheading")
      row.q:SetPoint("TOPLEFT", 12, -10)
      row.q:SetWidth(LIST_W - 50)
      row.q:SetWordWrap(false)
      row.left = UI.Label(row, "", "Small")
      row.left:SetPoint("TOPLEFT", 12, -30)
      row.votes = UI.Label(row, "", "MutedSmall")
      row.votes:SetPoint("TOPRIGHT", -12, -31)
      row.votes:SetJustifyH("RIGHT")
      UI.RowLine(row)
      row:SetScript("OnClick", function(self) selected, mode = self.item.id, "poll"; ns.RefreshPanel() end)
    end,
    function(row, p)
      UI.SetRowSelected(row, p.id == selected and mode == "poll")
      row.q:SetText(p.q)
      row.left:SetText(timeLeft(p))
      row.votes:SetText(ns.TP(p.total, "1 vote", "%d votes", p.total))
    end, true)
  M.list.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -33)
  M.new = UI.Button(card, "New poll", LIST_W - 28, "primary")
  M.new:SetHeight(26)
  M.new:SetPoint("BOTTOMLEFT", 14, 12)
  M.new:SetScript("OnClick", function() mode = "new"; ns.RefreshPanel() end)

  local right = CreateFrame("Frame", nil, f)
  right:SetPoint("TOPLEFT", RIGHT_X + 1, -1)
  right:SetSize(RIGHT_W - 2, 448)
  UI.Card(right, 1)
  M.right = right
  BuildPoll(right)
  BuildNew(right)
  return f
end

function M.Refresh()
  local polls = ns.Polls()
  if not ns.Poll(selected) then selected = polls[1] and polls[1].id end
  M.list:SetEmptyText(ns.EmptyHint("No polls yet."))
  M.list:SetItems(polls)
  local can, why = ns.CanStartPoll()
  UI.SetEnabled(M.new, can)
  M.new.tooltipWhy = why
  if mode == "new" and not can then mode = "poll" end
  M.pollFrame:SetShown(mode == "poll")
  M.newFrame:SetShown(mode == "new")
  if mode == "new" then
    M.newFrame.days:SetValue(newDays)
    M.newFrame.why:SetText(ns.T(ns.MembersCanPoll()
      and "Each member can have one poll open at a time. Everyone with Warcrest can vote, and votes aren't secret."
      or "Everyone with Warcrest can vote, and votes aren't secret."))
    return
  end

  local v = M.pollFrame
  local p = ns.Poll(selected)
  v.empty:SetShown(p == nil)
  v.close:SetShown(p ~= nil and p.open and (ns.IsMe(p.by) or ns.IsAddonOfficer()))
  if not p then
    for _, b in ipairs(v.opts) do b:Hide() end
    v.label:SetText("")
    v.q:SetText("")
    v.by:SetText("")
    v.total:SetText("")
    v.empty:SetText(ns.T(can and "No polls yet. Start one with New poll: a question and a few answers, and the guild votes."
      or "No polls yet. Officers can start one" .. (ns.MembersCanPoll() and "" or ", and can let members start them too (Settings)") .. "."))
    return
  end
  v.label:SetText(p.open and ns.Upper(ns.T("Open poll")) or ns.Upper(ns.T("Closed poll")))
  v.q:SetText(p.q)
  v.by:SetText(ns.TF("Asked by %s, %s", ns.Ambiguate(p.by, "short"), ns.Date("%b %d", p.t)) .. "  ·  " .. timeLeft(p))
  local mine = ns.MyVote(p)
  local best = 0
  for i = 1, #p.opts do best = math.max(best, p.counts[i]) end
  local y = -30 - (v.q:GetStringHeight() or 20) - 30
  for i, b in ipairs(v.opts) do
    local text = p.opts[i]
    b:SetShown(text ~= nil)
    if text then
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", 16, y - (i - 1) * 46)
      local n = p.counts[i]
      local share = p.total > 0 and n / p.total or 0
      b.bar:SetWidth(math.max(1, (INNER - 2) * share))
      local col = (mine == i) and C.accent or ((n == best and n > 0) and C.good or C.text)
      b.bar:SetColorTexture(col[1], col[2], col[3], mine == i and 0.28 or 0.12)
      b.text:SetText((mine == i and (UI.Code("accent") .. "> |r") or "") .. text)
      b.count:SetText(n .. "  " .. UI.Code("muted") .. math.floor(share * 100 + 0.5) .. "%|r")
      UI.SetEnabled(b, p.open)
    end
  end
  v.total:ClearAllPoints()
  v.total:SetPoint("TOPLEFT", 16, y - #p.opts * 46 - 4)
  v.total:SetText(ns.TP(p.total, "1 vote so far.", "%d votes so far.", p.total)
    .. (p.open and (mine and (" " .. ns.T("Click another answer to change your vote.")) or (" " .. ns.T("Click an answer to vote."))) or ""))
end

function M.Show(id)
  if id then selected = id end
  mode = "poll"
end
