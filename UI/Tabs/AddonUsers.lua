--[[
  Warcrest
  Addon tab: which guild members have Warcrest installed, and which
  version. Built from every message their addon has sent while you were
  online, remembered between sessions. "Check now" asks everyone online.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate
local UI = ns.UI

local P = {}
local filter = "all"

local function ago(t)
  local s = time() - t
  if s < 120 then return "just now" end
  if s < 3600 then return math.floor(s / 60) .. " min ago" end
  if s < 86400 then return math.floor(s / 3600) .. " h ago" end
  return math.floor(s / 86400) .. " d ago"
end

local rows = ns.AddonUserRows

local ORDER = { yes = 1, old = 2, no = 3 }
local C = UI.C
local query = ""

local function Refresh()
  if P.invite then P.invite:SetShown(ns.CanInvite()) end
  local all, newest = rows()
  local q = query:lower()
  local shown, counts = {}, { yes = 0, old = 0, no = 0, onlineWith = 0, online = 0 }
  for _, r in ipairs(all) do
    counts[r.status] = counts[r.status] + 1
    if r.m.online then
      counts.online = counts.online + 1
      if r.status ~= "no" then counts.onlineWith = counts.onlineWith + 1 end
    end
    local keep = filter == "all" or (filter == "with" and r.status ~= "no")
      or (filter == "without" and r.status == "no") or (filter == "old" and r.status == "old")
    if keep and (q == "" or r.m.name:lower():find(q, 1, true)) then shown[#shown + 1] = r end
  end
  table.sort(shown, function(a, b)
    if a.m.online ~= b.m.online then return a.m.online end
    if ORDER[a.status] ~= ORDER[b.status] then return ORDER[a.status] < ORDER[b.status] end
    return a.m.name < b.m.name
  end)
  P.list:SetEmptyText(#all == 0 and "The guild roster is still loading." or "Nobody matches.")
  P.list:SetItems(shown)

  local total = #all
  local with = counts.yes + counts.old
  P.tiles.with.number:SetText(("%d %s/ %d|r"):format(with, UI.Code("faint"), total))
  P.tiles.old.number:SetText(counts.old)
  local oc = counts.old > 0 and C.bad or C.text
  P.tiles.old.number:SetTextColor(oc[1], oc[2], oc[3])
  P.tiles.online.number:SetText(("%d %s/ %d|r"):format(counts.onlineWith, UI.Code("faint"), counts.online))
  P.tiles.newest.number:SetText("v" .. newest)
  -- A bar across the top tile: how much of the guild has it.
  local frac = total > 0 and with / total or 0
  P.tiles.with.fill:SetWidth(math.max(1, (P.tiles.with:GetWidth() - 28) * frac))
end

local function Build(page)
  local check = UI.Button(page.headerBar, "Check now", 110)
  check:SetHeight(26)
  check:SetPoint("RIGHT")
  UI.Tooltip(check, "Check now", "Asks every online guildmate which version of Warcrest they have.")
  check:SetScript("OnClick", function()
    ns.CheckVersions()
    C_Timer.After(8, ns.RefreshPanel)
  end)
  local f = UI.Segmented(page.headerBar, {
    { "all", "Everyone" }, { "with", "Has it" }, { "without", "Doesn't" }, { "old", "Out of date" },
  }, function(v) filter = v; ns.RefreshPanel() end)
  f:SetPoint("RIGHT", check, "LEFT", -8, 0)

  -- Tiles across the top.
  P.tiles = {}
  local tiles = { { "with", "Have the addon" }, { "old", "Out of date" }, { "online", "Online with it" },
    { "newest", "Newest version" } }
  local tileW = (740 - 3 * 12) / 4
  for i, t in ipairs(tiles) do
    P.tiles[t[1]] = UI.StatTile(page, (i - 1) * (tileW + 12), 0, tileW, 72, t[2])
  end
  local w = P.tiles.with
  local track = w:CreateTexture(nil, "BORDER")
  track:SetPoint("BOTTOMLEFT", 14, 30)
  track:SetPoint("BOTTOMRIGHT", -14, 30)
  track:SetHeight(3)
  track:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
  w.fill = w:CreateTexture(nil, "ARTWORK")
  w.fill:SetPoint("BOTTOMLEFT", 14, 30)
  w.fill:SetHeight(3)
  w.fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
  P.tiles.newest.number:SetTextColor(C.accent[1], C.accent[2], C.accent[3])

  P.search = UI.SearchBox(page, 260, "Search members", function(text)
    query = text
    ns.RefreshPanel()
  end)
  P.search:SetPoint("TOPLEFT", 1, -86)
  -- Officers: post a short invitation in guild chat (nothing is sent until they click Post).
  P.invite = UI.Button(page, "Invite the guild", 150, "primary")
  P.invite:SetHeight(26)
  P.invite:SetPoint("TOPRIGHT", -1, -86)
  UI.Tooltip(P.invite, "Invite the guild", "Post a short invitation to get Warcrest in guild chat. Nothing is sent until you click Post.")
  P.invite:SetScript("OnClick", function() ns.ShowInvite() end)

  local card = UI.Box(page, 0, -120, 740, 290)
  P.card = card
  local heads = { { "MEMBER", 12 }, { "RANK", 200 }, { "STATUS", 340 }, { "ADDON", 440 }, { "LAST SEEN WITH IT", 590 } }
  local y = UI.TableHeads(card, heads)
  P.list = UI.List(card, 740 - 24, 290 + y - 2, 24,
    function(row)
      row.cols = {}
      for i, h in ipairs(heads) do
        local fs = UI.Label(row, "", i == 1 and "Subheading" or "Small")
        fs:SetPoint("LEFT", h[2], 0)
        fs:SetWidth(i == 1 and 180 or (i == 4 and 140 or 130))
        fs:SetWordWrap(false)
        row.cols[i] = fs
      end
      UI.RowLine(row)
      row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
          -- Someone without Warcrest: a ready-made invite to copy and send them.
          if self.item.status == "no" then ns.ShowShare(ns.InviteText()) end
        else
          ns.ShowPlayerCard(self.item.m.name)
        end
      end)
    end,
    function(row, r)
      local m = r.m
      local cr, cg, cb = UI.ClassColor(m.classFile)
      local dim = m.online and 1 or 0.5
      row.cols[1]:SetText(Ambiguate(m.name, "guild"))
      row.cols[1]:SetTextColor(cr, cg, cb)
      row.cols[1]:SetAlpha(dim)
      row.cols[2]:SetText(m.rankName)
      row.cols[2]:SetAlpha(dim)
      row.cols[3]:SetText(m.online and (UI.Code("good") .. "Online|r") or (UI.Code("faint") .. "Offline|r"))
      if r.status == "yes" then
        row.cols[4]:SetText(UI.Code("good") .. "v" .. (r.version or "?") .. "|r")
      elseif r.status == "old" then
        row.cols[4]:SetText(UI.Code("bad") .. "v" .. r.version .. " · update|r")
      else
        row.cols[4]:SetText(UI.Code("muted") .. "Not detected|r")
      end
      row.cols[5]:SetText(r.live and (UI.Code("good") .. "Now|r") or (r.seen and ago(r.seen)) or (UI.Code("faint") .. "-|r"))
    end, true)
  P.list.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, y - 1)

  P.note = UI.Label(page, "\"Not detected\" means their addon hasn't been seen while you were online. "
    .. "Click Check now while they're online to ask.", "MutedSmall")
  P.note:SetPoint("TOPLEFT", 4, -428)
  P.note:SetWidth(730)
  P.note:SetWordWrap(false)
  UI.Grow(page, P.card, 1, 1)
  UI.Grow(page, P.list, 1, 1)
  UI.Follow(page, P.note, 0, 1)
end

-- The header's subtitle: how many members have it (the same count as the tab).
local function Subtitle()
  local all = rows()
  if #all == 0 then return "Who has Warcrest installed" end
  local with = 0
  for _, r in ipairs(all) do if r.status ~= "no" then with = with + 1 end end
  return ("%d of %d members have Warcrest"):format(with, #all)
end

UI.AddTab({ id = "addon", title = "Addon", build = Build, refresh = Refresh, subtitle = Subtitle })
