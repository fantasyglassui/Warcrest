--[[
  Warcrest
  Groups (Guild > Groups): a board for finding a group inside the guild.

  A member posts what they're going to do and how many they need ("Need 2
  for Scholomance, a healer"). Guildmates click Ask to join, which tells the
  poster only (a whisper between addons, nothing in chat). The poster sees who
  asked and clicks Invite. Nothing is ever sent without a click.

  Posts are plain messages (GP, GX), not kept in the ledger: one per member,
  gone after an hour, when it's closed, or when the poster logs off. Asking
  to join is GJ. At login, Warcrest asks (GQ) and posters send their post.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local LASTS = 3600          -- a post ends after an hour
local MAX_TEXT = 60
ns.GROUP_ROLES = { "tank", "healer", "dps" }
local ROLE_OK = { tank = true, healer = true, dps = true }

local posts = {}   -- poster key -> { by, what, need, roles = "tank,healer", t }
local asks = {}    -- asker key -> { name, role, t, invited } (asking to join your group)
local asked = {}   -- poster key -> t: you asked to join theirs

local function cleanRoles(roles)
  local out = {}
  for r in tostring(roles or ""):gmatch("[^,]+") do
    if ROLE_OK[r] then out[#out + 1] = r end
  end
  return table.concat(out, ",")
end

local function open(p)
  if not p or time() - p.t > LASTS then return false end
  local m = ns.Member(p.by)
  return m == nil or m.online -- (not in the roster yet: keep it)
end

local function note(by, what, need, roles, t)
  what = tostring(what or ""):sub(1, MAX_TEXT)
  t = tonumber(t) or time()
  if what == "" or t < time() - LASTS or t > time() + 300 then return end
  local k = ns.Key(by)
  local old = posts[k]
  if old and old.t > t then return end
  posts[k] = { by = Ambiguate(by, "short"), what = what, need = math.max(1, math.min(39, tonumber(need) or 1)),
    roles = cleanRoles(roles), t = t }
  if not old or old.t ~= t then asked[k] = nil end
  if ns.RefreshPanel then ns.RefreshPanel() end
end

------------------------------------------------------------------------
-- Posting
------------------------------------------------------------------------
-- Post (or replace) your group. need: how many more you need; roles: "tank,healer,dps" (any).
function ns.PostGroup(what, need, roles)
  what = strtrim(tostring(what or "")):sub(1, MAX_TEXT)
  if what == "" then return false end
  local t = time()
  note(UnitName("player"), what, need, roles, t)
  wipe(asks)
  local mine = posts[ns.Key(UnitName("player"))]
  ns.Send("GP", mine.what, mine.need, mine.roles, t)
  return true
end

function ns.CloseGroup()
  local k = ns.Key(UnitName("player"))
  if not posts[k] then return false end
  posts[k] = nil
  wipe(asks)
  ns.Send("GX")
  if ns.RefreshPanel then ns.RefreshPanel() end
  return true
end

function ns.MyGroup()
  local p = posts[ns.Key(UnitName("player"))]
  return open(p) and p or nil
end

-- Open posts from guildmates (and yours), newest first.
function ns.OpenGroups()
  local out = {}
  for k, p in pairs(posts) do
    if open(p) then out[#out + 1] = p else posts[k] = nil end
  end
  table.sort(out, function(a, b) return a.t > b.t end)
  return out
end

ns.OnMessage("GP", function(p, sender)
  if ns.IsMe(sender) then return end
  local fresh = not posts[ns.Key(sender)]
  note(sender, p[2], p[3], p[4], p[5])
  if fresh and posts[ns.Key(sender)] and ns.db.groupAlerts ~= false and time() - posts[ns.Key(sender)].t < 120 then
    ns.Say(ns.TF("%s is looking for %d: %s. Guild > Groups.", Ambiguate(sender, "short"),
      posts[ns.Key(sender)].need, posts[ns.Key(sender)].what))
  end
end)

ns.OnMessage("GX", function(_, sender)
  posts[ns.Key(sender)] = nil
  asked[ns.Key(sender)] = nil
  if ns.RefreshPanel then ns.RefreshPanel() end
end)

------------------------------------------------------------------------
-- Asking to join, and inviting
------------------------------------------------------------------------
function ns.AskToJoin(poster, role)
  local k = ns.Key(poster)
  local p = posts[k]
  if not open(p) or ns.IsMe(poster) then return false end
  if not ROLE_OK[role] then role = "" end
  asked[k] = time()
  ns.QueueTo(ns.WhisperName and ns.WhisperName(p.by) or p.by, "GJ", role)
  if ns.RefreshPanel then ns.RefreshPanel() end
  return true
end

function ns.AskedToJoin(poster) return asked[ns.Key(poster)] ~= nil end

ns.OnMessage("GJ", function(p, sender, channel)
  if channel ~= "WHISPER" or not ns.MyGroup() then return end
  local k = ns.Key(sender)
  if asks[k] then return end
  local role = ROLE_OK[p[2]] and p[2] or ""
  asks[k] = { name = Ambiguate(sender, "short"), role = role, t = time() }
  local label = ({ tank = "Tank", healer = "Healer", dps = "Damage" })[role]
  local text = label and ns.TF("%s asks to join your group (%s).", asks[k].name, ns.T(label))
    or ns.TF("%s asks to join your group.", asks[k].name)
  ns.Notify(ns.COLOR .. text .. "|r", nil, nil, nil, "event", "Groups")
  if ns.RefreshPanel then ns.RefreshPanel() end
end)

-- Who asked to join your group, oldest first.
function ns.GroupAsks()
  local out = {}
  for _, a in pairs(asks) do out[#out + 1] = a end
  table.sort(out, function(a, b) return a.t < b.t end)
  return out
end

-- Invite someone who asked (from a click).
function ns.InviteToGroup(name)
  local a = asks[ns.Key(name)]
  if not a then return false end
  local target = ns.WhisperName and ns.WhisperName(a.name) or a.name
  local invite = C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit
  if not invite or not pcall(invite, target) then return false end
  a.invited = true
  if ns.RefreshPanel then ns.RefreshPanel() end
  return true
end

------------------------------------------------------------------------
-- Catching up at login
------------------------------------------------------------------------
ns.OnMessage("GQ", function(_, sender)
  if ns.IsMe(sender) then return end
  local mine = ns.MyGroup()
  if mine then
    C_Timer.After(1 + math.random() * 4, function()
      if ns.MyGroup() then ns.QueueTo(sender, "GP", mine.what, mine.need, mine.roles, mine.t) end
    end)
  end
end)

ns.OnLoad(function()
  C_Timer.After(15, function() ns.Send("GQ") end)
end)
