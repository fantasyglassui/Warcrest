--[[
  Warcrest
  Events > World buffs: the last drop of each world buff and the latest
  world boss sightings, as seen by guildmates with Warcrest today.
]]

local _, ns = ...
local UI = ns.UI

local P = {}
local LEFT_W = 360
local RIGHT_X = LEFT_W + 14
local RIGHT_W = 740 - RIGHT_X

-- "5 min ago", "2 h ago".
function ns.AgoShort(t)
  local s = math.max(0, time() - (tonumber(t) or time()))
  if s < 90 then return ns.T("just now") end
  if s < 3600 then return ns.TF("%d min ago", math.floor(s / 60)) end
  return ns.TF("%d h ago", math.floor(s / 3600))
end

local function Refresh()
  P.alerts:SetChecked(ns.WorldBuffAlertsOn())
  local last = ns.LastWorldBuffs()
  for _, b in ipairs(ns.WORLD_BUFFS) do
    local row, d = P.buffs[b.key], last[b.key]
    if d then
      row.status:SetText(ns.TF("Dropped %s in %s, seen by %s.", ns.AgoShort(d.t),
        d.zone ~= "" and d.zone or ns.T("an unknown zone"), d.by ~= "" and d.by or "?"))
      local ends = d.t + b.duration
      if ends > time() then
        row.left:SetText(UI.Code("good") .. ns.TF("Lasts until %s for those who got it.", date("%H:%M", ends)) .. "|r")
      else
        row.left:SetText(UI.Code("faint") .. ns.T("Worn off.") .. "|r")
      end
    else
      row.status:SetText(UI.Code("muted") .. ns.T("No drop seen today.") .. "|r")
      row.left:SetText("")
    end
  end
  P.list:SetEmptyText("No world bosses seen today. When a guildmate with Warcrest sees one, it shows here.")
  P.list:SetItems(ns.BossSightings())
end

local function Build(page)
  -- World buffs
  local box = UI.Box(page, 0, 0, LEFT_W, 410, "World buffs")
  P.box = box
  P.alerts = UI.Check(box, "Alert me", LEFT_W - 120, -8)
  P.alerts:SetScript("OnClick", function(self)
    ns.db.worldBuffAlerts = self:GetChecked() and true or false
  end)
  UI.Tooltip(P.alerts, "Alert me", "A banner and a sound when a guildmate sees a world buff dropped or a world boss up.")

  P.buffs = {}
  for i, b in ipairs(ns.WORLD_BUFFS) do
    local y = -44 - (i - 1) * 112
    local row = {}
    row.name = UI.Label(box, b.name, "Subheading")
    row.name:SetPoint("TOPLEFT", 14, y)
    row.from = UI.Label(box, ns.TF("From %s", ns.T(b.from)), "MutedSmall")
    row.from:SetPoint("TOPLEFT", 14, y - 20)
    row.status = UI.Label(box, "", "Small")
    row.status:SetPoint("TOPLEFT", 14, y - 42)
    row.status:SetWidth(LEFT_W - 30)
    row.left = UI.Label(box, "", "Small")
    row.left:SetPoint("TOPLEFT", 14, y - 76)
    row.left:SetWidth(LEFT_W - 30)
    P.buffs[b.key] = row
  end
  local hint = UI.Label(page, "Seen by guildmates with Warcrest who get the buff, in every language.", "MutedSmall")
  hint:SetPoint("TOPLEFT", 4, -420)
  hint:SetWidth(730)

  -- World bosses
  local card = UI.Box(page, RIGHT_X, 0, RIGHT_W, 410, "World bosses")
  P.card = card
  P.list = UI.List(card, RIGHT_W - 24, 410 - 48, 44,
    function(row)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("TOPLEFT", 12, -5)
      row.info = UI.Label(row, "", "MutedSmall")
      row.info:SetPoint("TOPLEFT", 12, -24)
      row.info:SetWidth(RIGHT_W - 60)
      row.info:SetWordWrap(false)
      UI.RowLine(row)
    end,
    function(row, s)
      local b
      for _, x in ipairs(ns.WORLD_BOSSES) do if x.key == s.key then b = x end end
      row.name:SetText(ns.T(b and b.name or s.key) .. "  " .. (s.dead and (UI.Code("faint") .. ns.T("dead") .. "|r")
        or (UI.Code("good") .. ns.T("up") .. "|r")))
      row.info:SetText(ns.TF("%s · %s · seen by %s", s.zone ~= "" and s.zone or "?", ns.AgoShort(s.t), s.by))
    end, true)
  P.list.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -40)
  UI.Grow(page, P.card, 1, 1)
  UI.Grow(page, P.list, 1, 1)
  UI.Grow(page, P.box, 0, 1)
  UI.Follow(page, hint, 0, 1)
end

UI.AddTab({ id = "worldbuffs", title = "World buffs", build = Build, refresh = Refresh,
  subtitle = function() return "World buffs dropped and world bosses seen today" end })
