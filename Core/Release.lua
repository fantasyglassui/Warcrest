--[[
  Warcrest
  Release: starts everyone on a clean slate (first at 2.1.0, again at 4.3.0).

  The first time a player loads this version, everything shared with the
  guild is cleared: kills, deaths, Wanted, raids, sign-ups, DKP, loot,
  events, polls, profiles, titles, achievements, crafters and the Officer
  log. Personal settings and the guild's settings are kept. It only happens
  once.

  From then on, anything stamped before the release time is refused, so test
  data can't come back from players still on an older version.
]]

local _, ns = ...

ns.RELEASE_ID = "4.3.0"
ns.RELEASE_CUTOFF = 1795627112 -- 25 Nov 2026, 17:18 UTC: the 4.3.0 fresh start

-- True for anything recorded before the release.
function ns.BeforeRelease(t)
  return (tonumber(t) or 0) < ns.RELEASE_CUTOFF
end

-- Everything shared with the guild, and what was worked out from it. Each
-- player's own settings (alerts, sounds, accessibility, the window, the
-- minimap button, Getting started) and the guild's settings set by officers
-- are kept.
local SHARED = {
  "killLog", "deathLog", "spotted", "audit", "ledger", "reminded", "wantedHidden", "session", "duelLog", "wipes",
  "crafters", "myCrafts", "craftNames", "enemyGuilds", "achievements", "goalsDone", "bounties", "celebrated",
  "addonUsers", "postedAch", "bossChecks", "championMonth", "trialsNoted", "recapWeek", "ordersSeen",
  "eventReminded", "worldBuffs", "cooldowns", "firstSeen", "bladesAt", "ilvlSharedAt", "mapPins",
  "repPeak", "repRank", "repSession",
}

-- Runs before every other part of the addon sets up its data.
ns.OnLoad(function()
  local db = ns.db
  if db.releaseReset == ns.RELEASE_ID then return end
  local hadData = (db.killLog and #db.killLog > 0) or (db.deathLog and #db.deathLog > 0)
    or (db.ledger and next(db.ledger) ~= nil)
  for _, key in ipairs(SHARED) do db[key] = nil end
  db.killLog, db.deathLog, db.spotted, db.audit = {}, {}, {}, {}
  db.ledger, db.reminded, db.wantedHidden = {}, {}, {}
  db.releaseReset = ns.RELEASE_ID
  if hadData then
    C_Timer.After(10, function()
      ns.Say("Warcrest 4.3.0 starts fresh: kills, raids, DKP, loot, events, profiles, titles and achievements "
        .. "have been cleared for the whole guild. Your own settings are kept.")
    end)
  end
end)
