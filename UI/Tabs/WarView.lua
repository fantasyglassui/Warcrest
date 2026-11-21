--[[
  Warcrest
  The Wanted tab's Guilds view: the war board. Enemy guilds, with how many of
  theirs we've killed and how many of ours they have, rivals first. On the
  right, the guild picked: the score, who's been doing the damage, and (for
  officers) marking it as a rival, which turns on alerts when a group of
  them is spotted and puts the war in the weekly recap.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate
local UI = ns.UI

local M = {}
UI.WarView = M

local TABLE_W = 470
local SIDE_X = TABLE_W + 14
local SIDE_W = 740 - SIDE_X
local INNER = SIDE_W - 30
local RIVAL = "|cffff8c3a"
local selected
local period = "month"

local PERIODS = { { "month", "This month" }, { "lastmonth", "Last month" }, { "week", "7 days" }, { "all", "All time" } }

local function range()
  if period == "month" then return ns.MonthRange(0) end
  if period == "lastmonth" then return ns.MonthRange(-1) end
  if period == "week" then return time() - 7 * 86400, nil end
  return nil, nil
end

-- Who on each side did the most against this guild in the period.
local function topHands(guild, fromT, toT)
  fromT, toT = fromT or 0, toT or math.huge
  local ours, theirs = {}, {}
  for _, k in ipairs(ns.db.killLog or {}) do
    if k.t >= fromT and k.t < toT and not ns.KillHidden(k) and (k.vg or ns.EnemyGuild(k.victim)) == guild then
      local kb = ns.KillingBlow(k)
      if kb then ours[kb] = (ours[kb] or 0) + 1 end
    end
  end
  for _, d in ipairs(ns.db.deathLog or {}) do
    if d.kind == "pvp" and d.killer and d.killer ~= "" and d.t >= fromT and d.t < toT
        and (d.kg or ns.EnemyGuild(d.killer)) == guild then
      local n = Ambiguate(d.killer, "short")
      theirs[n] = (theirs[n] or 0) + 1
    end
  end
  local function best(t)
    local name, n = nil, 0
    for k, v in pairs(t) do if v > n or (v == n and name and k < name) then name, n = k, v end end
    return name, n
  end
  local a, an = best(ours)
  local b, bn = best(theirs)
  return a, an, b, bn
end

local function score(r)
  local diff = r.kills - r.deaths
  if diff > 0 then return UI.Code("good") .. "+" .. diff .. "|r" end
  if diff < 0 then return UI.Code("bad") .. diff .. "|r" end
  return UI.Code("muted") .. "0|r"
end

function M.Build(page)
  local f = CreateFrame("Frame", nil, page)
  M.frame = f
  f:SetPoint("TOPLEFT")
  f:SetSize(740, 450)

  local card = UI.Box(f, 0, 0, TABLE_W, 450)
  M.card = card
  local y = UI.TableHeads(card, { { "GUILD", 12 }, { "WE KILLED", 220 }, { "THEY KILLED", 310 }, { "SCORE", TABLE_W - 40, right = true } })
  M.list = UI.List(card, TABLE_W - 24, 450 + y - 2, 26,
    function(row)
      UI.RowSelection(row)
      row.guild = UI.Label(row, "", "Subheading")
      row.guild:SetPoint("LEFT", 12, 0)
      row.guild:SetWidth(200)
      row.guild:SetWordWrap(false)
      row.kills = UI.Label(row, "", "Number")
      row.kills:SetPoint("LEFT", 220, 0)
      row.deaths = UI.Label(row, "", "Number")
      row.deaths:SetPoint("LEFT", 310, 0)
      row.score = UI.Label(row, "", "Number")
      row.score:SetPoint("RIGHT", -16, 0)
      row.score:SetJustifyH("RIGHT")
      UI.RowLine(row)
      row:SetScript("OnClick", function(self) selected = self.item.guild; ns.RefreshPanel() end)
    end,
    function(row, r)
      row.guild:SetText((r.rival and RIVAL or "|cffe8e8e8") .. "<" .. r.guild .. ">|r")
      row.kills:SetText(r.kills)
      row.deaths:SetText(r.deaths)
      row.score:SetText(score(r))
      UI.SetRowSelected(row, r.guild == selected)
    end, true)
  M.list.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, y - 1)

  local side = CreateFrame("Frame", nil, f)
  M.side = side
  side:SetPoint("TOPLEFT", SIDE_X, 0)
  side:SetSize(SIDE_W, 450)

  -- The guild picked.
  local d = UI.Box(side, 0, 0, SIDE_W, 236)
  M.detail = d
  d.label = UI.Label(d, "", "Label")
  d.label:SetPoint("TOPLEFT", 14, -14)
  d.name = UI.Label(d, "", "Title")
  d.name:SetPoint("TOPLEFT", 14, -30)
  d.name:SetWidth(INNER)
  d.name:SetWordWrap(false)
  d.lines = UI.Label(d, "", "Small")
  d.lines:SetPoint("TOPLEFT", 14, -62)
  d.lines:SetWidth(INNER)
  d.lines:SetSpacing(3)
  d.rival = UI.Button(d, "Mark as rival", INNER)
  d.rival:SetHeight(26)
  d.rival:SetPoint("BOTTOMLEFT", 14, 14)
  d.rival:SetScript("OnClick", function()
    if selected then ns.SetRival(selected, not ns.IsRival(selected)) end
  end)
  UI.Tooltip(d.rival, "Rival guilds", "Rivals are listed first, the guild is alerted when 3 or more of them are seen together, "
    .. "and the weekly recap says how the war went. Officers choose them for the whole guild.")

  -- Period, adding a rival by name, and how it works.
  local info = CreateFrame("Frame", nil, side)
  M.info = info
  info:SetPoint("BOTTOMLEFT", 1, 1)
  info:SetSize(SIDE_W - 2, 200)
  UI.Card(info, 1)
  M.period = UI.Cycle(info, INNER, PERIODS, function(v) period = v; ns.RefreshPanel() end)
  M.period:SetHeight(26)
  M.period:SetPoint("TOPLEFT", 14, -14)
  UI.Tooltip(M.period, "Period", "Click to change which kills and deaths are counted.")
  M.infoText = UI.Label(info, "Enemy guilds come from what guildmates see: nameplates, targets and the players they kill or die to.", "MutedSmall")
  M.infoText:SetPoint("TOPLEFT", 14, -50)
  M.infoText:SetWidth(INNER)
  M.infoText:SetSpacing(2)
  M.addName = UI.EditBox(info, INNER - 96, 40)
  M.addName:SetHeight(26)
  M.addName:SetPoint("BOTTOMLEFT", 14, 14)
  M.addName.hint = UI.Label(M.addName, "Guild name", "MutedSmall")
  M.addName.hint:SetPoint("LEFT", 8, 0)
  M.addName:HookScript("OnTextChanged", function(self) self.hint:SetShown((self:GetText() or "") == "") end)
  M.add = UI.Button(info, "Add rival", 90)
  M.add:SetHeight(26)
  M.add:SetPoint("LEFT", M.addName, "RIGHT", 6, 0)
  M.add:SetScript("OnClick", function()
    local g = strtrim(M.addName:GetText() or ""):gsub("^<", ""):gsub(">$", "")
    if g ~= "" and ns.SetRival(g, true) then
      selected = g
      M.addName:SetText("")
      M.addName:ClearFocus()
    end
  end)
  UI.Tooltip(M.add, "Add a rival", "Marks a guild as a rival by its name, even before anyone has met them.")
  return f
end

function M.Refresh()
  local fromT, toT = range()
  local list = ns.GuildWar(fromT, toT)
  local found
  for _, r in ipairs(list) do if r.guild == selected then found = r end end
  if not found then found = list[1]; selected = found and found.guild or nil end
  M.list:SetEmptyText(ns.EmptyHint("No enemy guilds yet. They show up once guildmates have met some."))
  M.list:SetItems(list)

  for i, o in ipairs(PERIODS) do if o[1] == period then M.period.index, M.period.value = i, o[1] end end
  M.period:SetText(ns.T(PERIODS[M.period.index][2]))

  local officer = ns.IsAddonOfficer()
  M.addName:SetShown(officer)
  M.add:SetShown(officer)
  local d = M.detail
  d.rival:SetShown(officer and found ~= nil)
  if not found then
    d.label:SetText("")
    d.name:SetText(ns.T("No guild selected"))
    d.lines:SetText(UI.Code("muted") .. ns.T("Pick a guild on the left.") .. "|r")
    return
  end
  d.label:SetText(found.rival and (RIVAL .. ns.Upper(ns.T("Rival guild")) .. "|r") or ns.Upper(ns.T("Enemy guild")))
  d.name:SetText((found.rival and RIVAL or "") .. "<" .. found.guild .. ">" .. (found.rival and "|r" or ""))
  local lines = {}
  local diff = found.kills - found.deaths
  lines[#lines + 1] = ns.TF("We killed %s of theirs; they killed %s of ours.", UI.Code("text") .. found.kills .. "|r",
    UI.Code("text") .. found.deaths .. "|r")
  if found.kills + found.deaths > 0 then
    lines[#lines + 1] = diff > 0 and (UI.Code("good") .. ns.TF("We're ahead by %d.", diff) .. "|r")
      or (diff < 0 and (UI.Code("bad") .. ns.TF("They're ahead by %d.", -diff) .. "|r") or ns.T("Dead even."))
  end
  local a, an, b, bn = topHands(found.guild, fromT, toT)
  if a then lines[#lines + 1] = ns.TF("Our top hunter: %s (%d)", UI.Code("text") .. a .. "|r", an) end
  if b then lines[#lines + 1] = ns.TF("Their worst: %s (%d)", RIVAL .. b .. "|r", bn) end
  lines[#lines + 1] = UI.Code("muted") .. ns.TF("Members we know: %d", ns.EnemyGuildMembers(found.guild)) .. "|r"
  d.lines:SetText(table.concat(lines, "\n"))
  d.rival:SetText(ns.T(found.rival and "Not a rival" or "Mark as rival"))
end

function M.Subtitle()
  local n = 0
  for _ in pairs(ns.Rivals()) do n = n + 1 end
  return n == 0 and ns.T("Kills and deaths by enemy guild") or ns.TP(n, "At war with 1 guild", "At war with %d guilds", n)
end
