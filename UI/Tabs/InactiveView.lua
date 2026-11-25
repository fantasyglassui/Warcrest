--[[
  Warcrest
  The Officers tab's Inactive view: players who haven't logged in on any of
  their characters for a while (linked alts count with their main), longest
  gone first, with their rank, level, last raid and notes,
  to help with promotions and clean-ups. Pick how long counts as inactive.
  (Warcrest only lists them: removing someone is done in the guild window.)
]]

local _, ns = ...
local UI = ns.UI

local M = {}
UI.InactiveView = M

local TABLE_W = 540
local SIDE_X = TABLE_W + 14
local SIDE_W = 740 - SIDE_X
local INNER = SIDE_W - 28
local days = 30

local function ago(d)
  if d < 1 then return ns.T("today") end
  d = math.floor(d)
  if d < 60 then return ns.TP(d, "1 day", "%d days", d) end
  local mo = math.floor(d / 30)
  if mo < 24 then return ns.TP(mo, "1 month", "%d months", mo) end
  return ns.TP(math.floor(mo / 12), "1 year", "%d years", math.floor(mo / 12))
end

-- Players gone for at least `minDays`, longest gone first. Linked alts count
-- with their main: a player is only away if every one of their characters is,
-- and their last raid counts every character. One row per player, under the
-- main's name, with their alts in `alts`.
function ns.InactiveMembers(minDays)
  local players = {} -- main key -> { main member or first character seen, chars = { member, ... } }
  for _, m in ipairs(ns.GetRoster()) do
    local main = ns.MainOf and ns.MainOf(ns.Ambiguate(m.name, "short")) or ns.Ambiguate(m.name, "short")
    local k = ns.Key(main)
    local p = players[k]
    if not p then p = { mainName = main, chars = {} }; players[k] = p end
    p.chars[#p.chars + 1] = m
  end
  local out = {}
  for _, p in pairs(players) do
    local away, last, head = math.huge, 0, nil
    for _, m in ipairs(p.chars) do
      away = math.min(away, m.online and 0 or (m.offlineDays or 0))
      for _, t in ipairs(ns.RaidNightsAttended and ns.RaidNightsAttended(m.name) or {}) do last = math.max(last, t) end
      if ns.Key(m.name) == ns.Key(p.mainName) then head = m end
    end
    head = head or p.chars[1]
    if away >= minDays then
      local alts = {}
      for _, m in ipairs(p.chars) do
        if m ~= head then alts[#alts + 1] = ns.Ambiguate(m.name, "short") end
      end
      table.sort(alts)
      out[#out + 1] = { name = ns.Ambiguate(head.name, "short"), classFile = head.classFile, rank = head.rankName,
        rankIndex = head.rankIndex, level = head.level, days = away, lastRaid = last > 0 and last or nil,
        note = head.publicNote ~= "" and head.publicNote or head.officerNote, alts = alts }
    end
  end
  table.sort(out, function(a, b)
    if a.days ~= b.days then return a.days > b.days end
    return a.name < b.name
  end)
  return out
end

function M.Build(page)
  local f = CreateFrame("Frame", nil, page)
  M.frame = f
  f:SetPoint("TOPLEFT")
  f:SetSize(740, 450)

  local card = UI.Box(f, 0, 0, TABLE_W, 450)
  M.card = card
  local y = UI.TableHeads(card, { { "MEMBER", 12 }, { "RANK", 150 }, { "LEVEL", 270 }, { "AWAY", 324 }, { "LAST RAID", 420 } })
  M.list = UI.List(card, TABLE_W - 24, 450 + y - 2, 26,
    function(row)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("LEFT", 12, 0)
      row.name:SetWidth(132)
      row.name:SetWordWrap(false)
      row.rank = UI.Label(row, "", "Small")
      row.rank:SetPoint("LEFT", 150, 0)
      row.rank:SetWidth(112)
      row.rank:SetWordWrap(false)
      row.level = UI.Label(row, "", "Number")
      row.level:SetPoint("LEFT", 270, 0)
      row.away = UI.Label(row, "", "Small")
      row.away:SetPoint("LEFT", 324, 0)
      row.raid = UI.Label(row, "", "MutedSmall")
      row.raid:SetPoint("LEFT", 420, 0)
      UI.RowLine(row)
      row:SetScript("OnClick", function(self) ns.ShowPlayerCard(self.item.name) end)
      UI.Tooltip(row, function() return row.item.name end, function()
        local it = row.item
        local lines = { ns.TF("Last online %s ago.", ago(it.days)) }
        if #it.alts > 0 then lines[#lines + 1] = ns.TF("Alts: %s", table.concat(it.alts, ", ")) end
        if it.note and it.note ~= "" then lines[#lines + 1] = ns.TF("Note: %s", it.note) end
        lines[#lines + 1] = ns.T("Click for their player card.")
        return table.concat(lines, "\n")
      end)
    end,
    function(row, it)
      row.name:SetText(#it.alts > 0 and (it.name .. UI.Code("muted") .. " +" .. #it.alts .. "|r") or it.name)
      row.name:SetTextColor(UI.ClassColor(it.classFile))
      row.rank:SetText(it.rank)
      row.level:SetText(it.level)
      local col = it.days >= 90 and "bad" or (it.days >= 60 and "warn" or "text")
      row.away:SetText(UI.Code(col) .. ago(it.days) .. "|r")
      row.raid:SetText(it.lastRaid and ns.Date("%b %d, %Y", it.lastRaid) or "-")
    end, true)
  M.list.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, y - 1)

  local side = UI.Box(f, SIDE_X, 0, SIDE_W, 450)
  M.side = side
  UI.Label(side, "DAYS AWAY, AT LEAST", "Label"):SetPoint("TOPLEFT", 14, -14)
  M.days = UI.Segmented(side, { { 14, "14" }, { 30, "30" }, { 60, "60" }, { 90, "90" } },
    function(v) days = v; ns.RefreshPanel() end)
  M.days:SetPoint("TOPLEFT", 14, -32)
  M.count = UI.Label(side, "", "Display")
  M.count:SetPoint("TOPLEFT", 14, -78)
  M.countLabel = UI.Label(side, "", "MutedSmall")
  M.countLabel:SetPoint("TOPLEFT", 14, -112)
  M.countLabel:SetWidth(INNER)
  M.ranks = UI.Label(side, "", "Small")
  M.ranks:SetPoint("TOPLEFT", 14, -140)
  M.ranks:SetWidth(INNER)
  M.ranks:SetSpacing(3)
  local tip = UI.Label(side, "Players who haven't logged in on any of their characters for the time picked, longest gone first. "
    .. "Linked alts are listed with their main (+1, +2). Click one for their player card. To remove or demote someone, "
    .. "use the game's guild window.", "MutedSmall")
  tip:SetPoint("BOTTOMLEFT", 14, 14)
  tip:SetWidth(INNER)
  tip:SetSpacing(2)
  return f
end

function M.Refresh()
  M.days:SetValue(days)
  local list = ns.InactiveMembers(days)
  M.list:SetEmptyText(ns.TF("Nobody has been away for %d days or more.", days))
  M.list:SetItems(list)
  M.count:SetText(#list)
  local total = #ns.GetRoster()
  M.countLabel:SetText(ns.TF("of %d members", total))
  -- By rank.
  local byRank, order = {}, {}
  for _, it in ipairs(list) do
    if not byRank[it.rank] then byRank[it.rank] = { n = 0, index = it.rankIndex }; order[#order + 1] = it.rank end
    byRank[it.rank].n = byRank[it.rank].n + 1
  end
  table.sort(order, function(a, b) return byRank[a].index < byRank[b].index end)
  local lines = {}
  for i, r in ipairs(order) do
    if i > 8 then break end
    lines[#lines + 1] = r .. ": " .. UI.Code("text") .. byRank[r].n .. "|r"
  end
  M.ranks:SetText(table.concat(lines, "\n"))
end

function M.Subtitle()
  local n = #ns.InactiveMembers(days)
  if n == 1 then return ns.TF("1 member away for %d days or more", days) end
  return ns.TF("%d members away for %d days or more", n, days)
end
