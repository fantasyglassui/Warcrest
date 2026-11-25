--[[
  Warcrest
  Guild > Groups: post what you're doing and how many you need; guildmates
  ask to join with a click, and you invite them with a click.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate
local UI = ns.UI

local P = {}
local LEFT_W = 450
local SIDE_X = LEFT_W + 14
local SIDE_W = 740 - SIDE_X
local INNER = SIDE_W - 28
local myRole = "dps"

local ROLE_LABEL = { tank = "Tank", healer = "Healer", dps = "Damage" }

local function rolesText(roles)
  if not roles or roles == "" then return ns.T("any role") end
  local out = {}
  for r in roles:gmatch("[^,]+") do out[#out + 1] = ns.T(ROLE_LABEL[r] or r) end
  return table.concat(out, ", ")
end

local function Refresh()
  local mine = ns.MyGroup()
  P.post:SetText(mine and "Update my group" or "Post my group")
  P.close:SetShown(mine ~= nil)
  if mine and not P.what:HasFocus() and (P.what:GetText() or "") == "" then P.what:SetText(mine.what) end
  local asks = ns.GroupAsks()
  P.asks:SetEmptyText(mine and "Nobody has asked yet." or "Post your group, and guildmates who ask to join show here.")
  P.asks:SetItems(asks)
  P.list:SetEmptyText("No open groups. Post yours on the right.")
  P.list:SetItems(ns.OpenGroups())
  P.role:SetText(ROLE_LABEL[myRole])
end

local function Build(page)
  -- Open groups
  local card = UI.Box(page, 0, 0, LEFT_W, 410, "Open groups")
  P.card = card
  P.role = UI.Cycle(card, 110, { { "dps", "Damage" }, { "healer", "Healer" }, { "tank", "Tank" } },
    function(v) myRole = v end)
  P.role:SetHeight(24)
  P.role:SetPoint("TOPRIGHT", -12, -8)
  UI.Tooltip(P.role, "Your role", "The role you ask to join as.")
  P.list = UI.List(card, LEFT_W - 24, 410 - 48, 52,
    function(row)
      row.what = UI.Label(row, "", "Subheading")
      row.what:SetPoint("TOPLEFT", 12, -6)
      row.what:SetWidth(LEFT_W - 170)
      row.what:SetWordWrap(false)
      row.info = UI.Label(row, "", "MutedSmall")
      row.info:SetPoint("TOPLEFT", 12, -26)
      row.info:SetWidth(LEFT_W - 170)
      row.info:SetWordWrap(false)
      row.ask = UI.Button(row, "Ask to join", 116)
      row.ask:SetHeight(24)
      row.ask:SetPoint("RIGHT", -10, 0)
      row.ask:SetScript("OnClick", function(self) ns.AskToJoin(self:GetParent().item.by, myRole) end)
      UI.RowLine(row)
    end,
    function(row, g)
      row.what:SetText(g.what)
      row.info:SetText(ns.TF("%s · needs %d · %s · %s", g.by, g.need, rolesText(g.roles), ns.AgoShort(g.t)))
      local mine = ns.IsMe(g.by)
      local done = ns.AskedToJoin(g.by)
      row.ask:SetShown(not mine)
      row.ask:SetText(done and "Asked" or "Ask to join")
      UI.SetEnabled(row.ask, not done)
    end, true)
  P.list.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -40)

  -- Your group
  local side = UI.Box(page, SIDE_X, 0, SIDE_W, 410, "Your group")
  P.side = side
  UI.FieldLabel(side, "What for", 14, -42)
  P.what = UI.EditBox(side, INNER, 60)
  P.what:SetHeight(26)
  P.what:SetPoint("TOPLEFT", 14, -58)
  UI.FieldLabel(side, "How many you need", 14, -94)
  local needs = {}
  for i = 1, 9 do needs[#needs + 1] = { i, tostring(i) } end
  needs[#needs + 1] = { 19, "Raid" }
  P.need = UI.Cycle(side, 80, needs, function() end)
  P.need:SetHeight(24)
  P.need:SetPoint("TOPLEFT", 14, -110)
  P.roles = {}
  for i, r in ipairs(ns.GROUP_ROLES) do
    local cb = UI.Check(side, ROLE_LABEL[r], 10 + (i - 1) * 84, -142)
    P.roles[r] = cb
  end
  P.post = UI.Button(side, "Post my group", INNER, "primary")
  P.post:SetHeight(26)
  P.post:SetPoint("TOPLEFT", 14, -176)
  P.post:SetScript("OnClick", function()
    local roles = {}
    for _, r in ipairs(ns.GROUP_ROLES) do if P.roles[r]:GetChecked() then roles[#roles + 1] = r end end
    if ns.PostGroup(P.what:GetText(), P.need.value, table.concat(roles, ",")) then
      P.what:ClearFocus()
    else
      ns.Say("Write what the group is for first.")
    end
  end)
  UI.Tooltip(P.post, "Post my group", "Shows your group to guildmates with Warcrest for an hour. Nothing goes in chat.")
  P.close = UI.Button(side, "Close my group", INNER)
  P.close:SetHeight(26)
  P.close:SetPoint("TOPLEFT", 14, -208)
  P.close:SetScript("OnClick", function() ns.CloseGroup(); P.what:SetText("") end)

  UI.FieldLabel(side, "Asking to join", 14, -246)
  P.asks = UI.List(side, SIDE_W - 16, 140, 34,
    function(row)
      row.name = UI.Label(row, "", "Body")
      row.name:SetPoint("LEFT", 8, 0)
      row.name:SetWidth(SIDE_W - 120)
      row.name:SetWordWrap(false)
      row.invite = UI.Button(row, "Invite", 76)
      row.invite:SetHeight(24)
      row.invite:SetPoint("RIGHT", -6, 0)
      row.invite:SetScript("OnClick", function(self) ns.InviteToGroup(self:GetParent().item.name) end)
      UI.RowLine(row)
    end,
    function(row, a)
      local m = ns.Member(a.name)
      local r, g, b = UI.ClassColor(m and m.classFile)
      row.name:SetText(a.role ~= "" and (Ambiguate(a.name, "short") .. "  " .. UI.Code("muted") .. ns.T(ROLE_LABEL[a.role]) .. "|r")
        or Ambiguate(a.name, "short"))
      row.name:SetTextColor(r, g, b)
      row.invite:SetText(a.invited and "Invited" or "Invite")
      UI.SetEnabled(row.invite, not a.invited)
    end, true)
  P.asks.frame:SetPoint("TOPLEFT", side, "TOPLEFT", 8, -262)

  UI.Grow(page, P.card, 1, 1)
  UI.Grow(page, P.list, 1, 1)
  UI.Follow(page, P.side, 1, 0)
end

UI.AddTab({ id = "groups", title = "Groups", build = Build, refresh = Refresh,
  subtitle = function() return "Find a group inside the guild" end })
