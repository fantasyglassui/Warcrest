--[[
  Warcrest
  Spreading the word: how many active guild members have Warcrest, the invite
  and share texts, and the single guild-chat post an officer can ask for.
  Nothing here sends anything by itself; only PostGuildInvite talks, and only
  when called.
]]

local _, ns = ...

local ACTIVE_DAYS = 14
local MAX_CHAT = 255

-- Every guild member with their addon status.
function ns.AddonUserRows()
  local newest = ns.NewestVersion()
  local users = ns.db.addonUsers or {}
  local out = {}
  for _, m in ipairs(ns.GetRoster()) do
    local u = users[ns.Key(m.name)]
    local live = ns.versions[m.full]               -- confirmed this session
    local version = live or (u and u.version)
    local status
    if live or u then
      status = (version and ns.CompareVersions(version, newest) < 0) and "old" or "yes"
    else
      status = "no"
    end
    out[#out + 1] = { m = m, version = version, seen = u and u.t, status = status, live = live ~= nil }
  end
  return out, newest
end

-- Active = online, or seen within the last two weeks (offline with no date counts as gone).
local function isActive(m)
  return m.online or (m.offlineDays or math.huge) <= ACTIVE_DAYS
end

-- How many active members have Warcrest, how many are active, and the whole roster.
function ns.WarcrestCount()
  local have, active = 0, 0
  local rows = ns.AddonUserRows()
  for _, r in ipairs(rows) do
    if isActive(r.m) then
      active = active + 1
      if r.status ~= "no" then have = have + 1 end
    end
  end
  return have, active, #rows
end

function ns.InviteText()
  return ns.T("Our guild uses Warcrest for raids, DKP and more. Get it free on CurseForge or at warcrest-addon.com")
end

function ns.ShareText()
  return ns.T("Warcrest: free guild tools for WoW Forever. Get it on CurseForge or at warcrest-addon.com")
end

function ns.CanInvite()
  return ns.IsAddonOfficer() or false
end

local function inviteState()
  ns.db.invite = ns.db.invite or {}
  return ns.db.invite
end

-- An empty page's text, plus how many have Warcrest while few do: most pages
-- fill up from guildmates who have it, so that's usually why it's empty.
function ns.EmptyHint(text)
  text = ns.T(text)
  local have, active = ns.WarcrestCount()
  if not (ns.AloneInGuild() or (active > 0 and have < 3)) then return text end
  return text .. "\n\n" .. ns.TF("%d of %d members have Warcrest. Officers can invite the rest from Guild > Who has Warcrest.", have, active)
end

-- The one thing Warcrest says in guild chat, and only when asked.
function ns.PostGuildInvite(text)
  if not ns.CanInvite() then return false, "officer" end
  text = tostring(text or "")
  if not text:find("%S") then return false, "empty" end
  text = text:gsub("|", "||"):sub(1, MAX_CHAT)
  -- Trimming must not cut an escaped pair in half.
  local bars = text:match("|+$")
  if bars and #bars % 2 == 1 then text = text:sub(1, -2) end
  local ok, why = ns.SendChat(text, "GUILD")
  if ok then inviteState().last = time() end
  return ok, why
end

function ns.LastInvite()
  return inviteState().last
end

function ns.ShouldNudge()
  if not ns.IsAddonOfficer() then return false end
  local have, active = ns.WarcrestCount()
  if have >= active / 2 then return false end
  local dismissed = inviteState().dismissedMissing
  return dismissed == nil or active - have >= dismissed + 5
end

function ns.DismissNudge()
  local have, active = ns.WarcrestCount()
  inviteState().dismissedMissing = active - have
end

function ns.AloneInGuild()
  local have, active = ns.WarcrestCount()
  return have <= 1 and active > 1
end
