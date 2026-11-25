--[[
  Warcrest
  DKP: balances, officer awards, and loot auctions.

  Balances add up every DKP entry in the ledger. Officers award or deduct
  DKP by hand, and attendance DKP comes from raid sessions (Raids.lua).

  Auctions run over the raid's addon channel. An officer puts an item up
  for a set time; raid members bid, and every bid must beat the current
  highest bid and be within the bidder's DKP. A bid in the last 5 seconds
  adds time. The highest bidder wins, and their DKP is deducted.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local NAMES_PER_ENTRY_CHARS = 170
local SNIPE_GUARD = 5
local cache
local catchUp -- (below)
-- Balances only change with DKP changes, undos, alt links and seasons.
ns.OnLedgerChanged(function() catchUp() end)

------------------------------------------------------------------------
-- Balances
------------------------------------------------------------------------
------------------------------------------------------------------------
-- Alts: a member's alts share their main's DKP and attendance
------------------------------------------------------------------------
-- A link needs both characters to agree: the alt asks ("req") and the main
-- confirms ("ok"), which proves the same person plays both. Officers can
-- also link or unlink directly.
local links, pending
local mains = {} -- name -> main, kept until the links change (ns.MainOf)
local altsCache = {} -- main key -> its alts, kept until the links change (ns.AltsOf)

local function loadLinks()
  links, pending, mains, altsCache = {}, {}, {}, {}
  for _, e in ipairs(ns.LedgerEntries("AL")) do
    local alt, main, author = ns.Key(e.alt), ns.Key(e.main), ns.Key(e.a)
    if alt ~= "" and alt ~= main then
      if e.state == "req" and author == alt then
        pending[alt] = e.main
      elseif e.state == "ok" and author == main and pending[alt] and ns.Key(pending[alt]) == main then
        links[alt], pending[alt] = Ambiguate(e.main, "short"), nil
      elseif e.state == "set" and ns.IsOfficerName(e.a) then
        links[alt], pending[alt] = Ambiguate(e.main, "short"), nil
      elseif e.state == "off" and (author == alt or ns.IsOfficerName(e.a)
          or (links[alt] and author == ns.Key(links[alt])) or (pending[alt] and author == ns.Key(pending[alt]))) then
        links[alt], pending[alt] = nil, nil
      end
    end
  end
end

-- The main a character belongs to (or the character itself).
function ns.MainOf(name)
  if not links then loadLinks() end
  name = name or ""
  local known = mains[name]
  if known then return known end
  local current, seen = Ambiguate(name, "short"), 0
  while links[ns.Key(current)] and seen < 3 do -- follow at most a short chain
    current = links[ns.Key(current)]
    seen = seen + 1
  end
  mains[name] = current
  return current
end

-- (A shared list: don't change it.)
function ns.AltsOf(main)
  if not links then loadLinks() end
  local k = ns.Key(main)
  if altsCache[k] then return altsCache[k] end
  local out = {}
  for alt, m in pairs(links) do
    if ns.Key(m) == k then
      local r = ns.Member(alt)
      local name = r and Ambiguate(r.name, "short") or alt
      out[#out + 1] = name
    end
  end
  table.sort(out)
  altsCache[k] = out
  return out
end

-- Alts asking you (their main) to confirm.
function ns.PendingAltRequests()
  if not pending then loadLinks() end
  local me, out = ns.Key(UnitName("player")), {}
  for alt, main in pairs(pending) do
    if ns.Key(main) == me then
      local r = ns.Member(alt)
      local name = r and Ambiguate(r.name, "short") or alt
      out[#out + 1] = name
    end
  end
  table.sort(out)
  return out
end

-- Asked from the alt: who you've asked to be your main, if anyone.
function ns.MyAltRequest()
  if not pending then loadLinks() end
  return pending[ns.Key(UnitName("player"))]
end

function ns.RequestAltLink(main)
  main = Ambiguate(strtrim(main or ""), "none")
  if main == "" then return end
  if ns.RankOf(main) == nil then ns.Say(main .. " isn't in the guild.") return end
  if ns.IsMe(main) then return end
  ns.LedgerAdd("AL", { alt = UnitName("player"), main = main, state = "req" })
  ns.Say(ns.TF("Asked to link this character as an alt of %s. Log in on %s and confirm it with Alts in Loot > Standings.", main, main))
end

function ns.ConfirmAlt(alt)
  ns.LedgerAdd("AL", { alt = alt, main = UnitName("player"), state = "ok" })
  ns.Say(alt .. " is now linked as your alt. Its DKP and attendance count toward yours.")
end

function ns.UnlinkAlt(alt)
  ns.LedgerAdd("AL", { alt = alt, main = ns.MainOf(alt), state = "off" })
end

function ns.OfficerLinkAlt(alt, main)
  alt, main = Ambiguate(strtrim(alt or ""), "none"), Ambiguate(strtrim(main or ""), "none")
  if alt == "" or main == "" or ns.Key(alt) == ns.Key(main) then return end
  for _, n in ipairs({ alt, main }) do
    if ns.RankOf(n) == nil then ns.Say(n .. " isn't in the guild.") return end
  end
  ns.LedgerAdd("AL", { alt = alt, main = main, state = "set" })
  ns.Say(ns.TF("Linked %s as an alt of %s.", alt, main))
end

-- Tell a main when an alt asks to be linked.
local toldAbout = {}
ns.OnLedgerChanged(function()
  links, pending = nil, nil
  for _, alt in ipairs(ns.PendingAltRequests()) do
    if not toldAbout[alt] then
      toldAbout[alt] = true
      ns.Say(ns.TF("%s wants to be linked as your alt. Confirm it with Alts in Loot > Standings.", alt))
    end
  end
end)

------------------------------------------------------------------------
-- Undone DKP changes
------------------------------------------------------------------------
-- DKP change id -> the undo entry.
local function undoneSet()
  local set = {}
  for _, u in ipairs(ns.LedgerEntries("UN")) do set[u.ref] = u end
  return set
end
ns.UndoneSet = undoneSet

-- Balances from the DKP record. fromT/toT limit which changes count; base is
-- a set of starting balances (a season's) to add them to.
local function newTally(fromT, toT, base)
  local balances, history = {}, {}
  local decayed = {} -- name key .. week -> true, so a week's decay only counts once
  local function add(name, amount, entry)
    local main = ns.MainOf(name) -- alts count toward their main
    local k = ns.Key(main)
    local b = balances[k]
    if not b then
      b = { key = k, name = Ambiguate(main, "short"), dkp = 0 }
      balances[k] = b
      history[k] = {}
    end
    b.dkp = b.dkp + amount
    if entry then table.insert(history[k], 1, entry) end -- newest first
  end
  for _, b in ipairs(base or {}) do add(b.name, b.amount) end
  -- Count one DKP change (oldest first).
  local function apply(e, undone)
    local inRange = not (fromT and e.t < fromT) and not (toT and e.t >= toT)
    if inRange and not undone[e.id] then
      local week = e.reason:match("^Decay %d+%% %(week (%d+)%)$")
      for listed in e.names:gmatch("[^,]+") do
        -- If two officers decayed the same week at once, only the first counts.
        local key = week and (ns.Key(ns.MainOf(listed)) .. ":" .. week)
        if not (key and decayed[key]) then
          if key then decayed[key] = true end
          add(listed, e.amount, e)
        end
      end
    end
  end
  return { balances = balances, history = history, apply = apply }
end

local function tally(fromT, toT, base)
  local t = newTally(fromT, toT, base)
  local undone = undoneSet()
  for _, e in ipairs(ns.LedgerEntries("DK")) do t.apply(e, undone) end
  return t.balances, t.history
end

-- A season's starting balances: { name, amount } per member.
local function seasonBase(sn)
  local base = {}
  for _, ss in ipairs(ns.LedgerEntries("SS")) do
    if ss.ref == sn.id then
      for name in ss.names:gmatch("[^,]+") do base[#base + 1] = { name = name, amount = ss.amount } end
    end
  end
  return base
end

local function build()
  local sn = ns.CurrentSeason()
  local t = sn and newTally(sn.t, nil, seasonBase(sn)) or newTally()
  local undone = undoneSet()
  local list = ns.LedgerEntries("DK")
  for _, e in ipairs(list) do t.apply(e, undone) end
  cache = { balances = t.balances, history = t.history, tally = t, count = #list, last = list[#list],
    undone = undone, otherStamp = ns.LedgerStamp("UN", "AL", "SN", "SS") }
  return cache
end

-- New DKP changes (the usual case: an award or a won item just now) are added
-- to the balances instead of working everything out again. Anything else (an
-- undo, an alt link, a season, or a change older than the newest) starts over.
function catchUp()
  if not cache or cache.otherStamp ~= ns.LedgerStamp("UN", "AL", "SN", "SS") then cache = nil return end
  local list = ns.LedgerEntries("DK")
  if #list < cache.count or list[cache.count] ~= cache.last then cache = nil return end
  for i = cache.count + 1, #list do cache.tally.apply(list[i], cache.undone) end
  cache.count, cache.last = #list, list[#list]
end

-- Officers: start a new season. Everyone keeps their DKP; older history is archived.
function ns.StartSeason(name)
  if not ns.IsAddonOfficer() then ns.Say("Only officers can start a new season.") return end
  name = strtrim(name or "")
  if name == "" then name = "Season " .. ns.Date("%b %Y") end
  -- Everyone's DKP up to now (changes made this very second count after the start).
  local now = GetServerTime()
  local sn = ns.CurrentSeason()
  local balances = tally(sn and sn.t or nil, now, sn and seasonBase(sn) or nil)
  local byAmount = {}
  for _, b in pairs(balances) do
    if b.dkp ~= 0 then
      byAmount[b.dkp] = byAmount[b.dkp] or {}
      table.insert(byAmount[b.dkp], b.name)
    end
  end
  -- Group members with the same balance, in pieces that fit one message each.
  local parts = {}
  for amount, names in pairs(byAmount) do
    local chunk, len = {}, 0
    for _, n in ipairs(names) do
      if len + #n > 170 then
        parts[#parts + 1] = { amount = amount, names = table.concat(chunk, ",") }
        chunk, len = {}, 0
      end
      chunk[#chunk + 1] = n
      len = len + #n + 1
    end
    if #chunk > 0 then parts[#parts + 1] = { amount = amount, names = table.concat(chunk, ",") } end
  end
  local e = ns.LedgerAdd("SN", { name = name, parts = #parts })
  if not e then return end
  for _, p in ipairs(parts) do ns.LedgerAdd("SS", { ref = e.id, amount = p.amount, names = p.names }) end
  ns.Say(ns.TF("%s has started. Everyone kept their DKP; older history has been archived.", name))
end

function ns.DKPBalances() return (cache or build()).balances end

function ns.Balance(name)
  local b = ns.DKPBalances()[ns.Key(ns.MainOf(name))]
  return b and b.dkp or 0
end

function ns.DKPHistory(name)
  return (cache or build()).history[ns.Key(ns.MainOf(name))] or {}
end

-- Everyone to show on the DKP tab: the guild roster plus anyone with DKP.
function ns.DKPStandings()
  local list, seen = {}, {}
  local balances = ns.DKPBalances()
  for _, m in ipairs(ns.GetRoster()) do
    local k = ns.Key(m.name)
    seen[k] = true
    if ns.Key(ns.MainOf(m.name)) == k then -- alts are shown under their main
      list[#list + 1] = { key = k, name = Ambiguate(m.name, "short"), full = m.name, classFile = m.classFile,
        online = m.online, dkp = balances[k] and balances[k].dkp or 0, alts = ns.AltsOf(m.name) }
    end
  end
  for k, b in pairs(balances) do
    if not seen[k] then list[#list + 1] = { key = k, name = b.name, dkp = b.dkp, left = true } end
  end
  return list
end

-- Award (or with a negative amount, deduct) DKP. Big groups are split
-- across several entries so each fits in one message.
function ns.AwardDKP(names, amount, reason)
  amount = math.floor(tonumber(amount) or 0)
  if amount == 0 or #names == 0 then return end
  if not ns.IsAddonOfficer() then ns.Say("Only officers can change DKP.") return end
  reason = (reason and reason ~= "") and reason or "Officer adjustment"
  local chunk, len = {}, 0
  local function flush()
    if #chunk > 0 then ns.LedgerAdd("DK", { amount = amount, names = table.concat(chunk, ","), reason = reason }) end
    chunk, len = {}, 0
  end
  for _, name in ipairs(names) do
    if len + #name > NAMES_PER_ENTRY_CHARS then flush() end
    chunk[#chunk + 1] = name
    len = len + #name + 1
  end
  flush()
  return true
end

------------------------------------------------------------------------
-- Loot history
------------------------------------------------------------------------
-- Every item won in an auction, newest first: { t, item, winner, amount, by, raid }.
-- Built from the DKP record, so it's the same for everyone.
-- Kept until the record changes: the list is shared, so read it, don't change it.
local lootCache, lootVersion, lootSeason
function ns.LootHistory()
  if lootCache and lootVersion == ns.LedgerVersion() and lootSeason == ns.CurrentSeason() then return lootCache end
  -- Raid nights (oldest first), to say which raid each item dropped in.
  local sessions = {}
  local ends = {}
  for _, e in ipairs(ns.LedgerEntries("RE")) do ends[e.ref] = e.t end
  for _, s in ipairs(ns.LedgerEntries("RS")) do
    sessions[#sessions + 1] = { from = s.t, to = ends[s.id] or (s.t + 12 * 3600), title = s.title }
  end
  -- The newest raid night that started at or before t, if t falls inside it.
  local function raidAt(t)
    local lo, hi, found = 1, #sessions, nil
    while lo <= hi do
      local mid = math.floor((lo + hi) / 2)
      if sessions[mid].from <= t then found = mid; lo = mid + 1 else hi = mid - 1 end
    end
    for i = found or 0, math.max(1, (found or 0) - 3), -1 do -- overlapping nights: check a few back
      if sessions[i] and t <= sessions[i].to then return sessions[i].title end
    end
  end
  local out = {}
  local undone = undoneSet()
  for _, e in ipairs(ns.LedgerEntries("DK")) do
    local item = e.reason:match("^Won (.+)$")
    if item then item = item:gsub(" %(free roll%)$", ""):gsub(" %(council%)$", "") end
    local sn = ns.CurrentSeason()
    if item and e.amount <= 0 and not undone[e.id] and not (sn and e.t < sn.t) then
      local raid = raidAt(e.t)
      for name in e.names:gmatch("[^,]+") do
        out[#out + 1] = { t = e.t, item = item, winner = Ambiguate(name, "short"), amount = -e.amount,
          by = e.a, raid = raid, id = e.id, roll = e.reason:find("%(free roll%)$") ~= nil,
          council = e.reason:find("%(council%)$") ~= nil }
      end
    end
  end
  table.sort(out, function(a, b) return a.t > b.t end)
  lootCache, lootVersion, lootSeason = out, ns.LedgerVersion(), ns.CurrentSeason()
  return out
end

------------------------------------------------------------------------
-- Export (a plain-text backup officers can copy out of the game)
------------------------------------------------------------------------
local function plain(text)
  -- "[Item Name]" instead of a full item link; drop color codes.
  text = tostring(text or ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return text
end

function ns.ExportDKP()
  local lines = {}
  local function add(s) lines[#lines + 1] = s end
  add((ns.GuildName() or "Guild") .. " - Warcrest DKP export, " .. date("%Y-%m-%d %H:%M"))
  add("")
  add("STANDINGS")
  add("Name,DKP")
  local standings = {}
  for _, b in pairs(ns.DKPBalances()) do standings[#standings + 1] = b end
  table.sort(standings, function(a, b)
    if a.dkp ~= b.dkp then return a.dkp > b.dkp end
    return a.name < b.name
  end)
  for _, b in ipairs(standings) do add(b.name .. "," .. b.dkp) end
  add("")
  add("LOOT")
  add("Date,Item,Winner,DKP,Raid")
  for _, l in ipairs(ns.LootHistory()) do
    add(("%s,%s,%s,%d,%s"):format(date("%Y-%m-%d %H:%M", l.t), plain(l.item):gsub(",", ""), l.winner, l.amount,
      (l.raid or ""):gsub(",", "")))
  end
  add("")
  add("ALL DKP CHANGES")
  add("Date,Change,Members,Reason,Officer")
  local undone = undoneSet()
  for _, e in ipairs(ns.LedgerEntries("DK")) do
    add(("%s,%s%d,%s,%s,%s%s"):format(date("%Y-%m-%d %H:%M", e.t), e.amount >= 0 and "+" or "", e.amount,
      (e.names:gsub(",", ";")), plain(e.reason):gsub(",", ""), e.a,
      undone[e.id] and (" (undone by " .. undone[e.id].a .. ")") or ""))
  end
  return table.concat(lines, "\n")
end

------------------------------------------------------------------------
-- Corrections: undo a DKP change, or give an item to someone else
------------------------------------------------------------------------
function ns.UndoDKP(entry, why)
  if not ns.IsAddonOfficer() then ns.Say("Only officers can undo DKP changes.") return end
  if undoneSet()[entry.id] then ns.Say("That change was already undone.") return end
  local sn = ns.CurrentSeason()
  if sn and entry.t < sn.t then ns.Say("That change is from before this season and can't be undone.") return end
  ns.LedgerAdd("UN", { ref = entry.id, reason = why or "" })
  return true
end

-- Every DKP change, newest first, with whether it was undone.
function ns.DKPChanges()
  local undone, out = undoneSet(), {}
  local list = ns.LedgerEntries("DK")
  local sn = ns.CurrentSeason()
  for i = #list, 1, -1 do
    local e = list[i]
    if sn and e.t < sn.t then break end -- older changes belong to an earlier season
    out[#out + 1] = { entry = e, undone = undone[e.id] }
  end
  return out
end

-- A loot win: refund it, or move it (and its cost) to someone else.
function ns.ReassignLoot(l, newWinner)
  local entry = ns.db.ledger[l.id]
  if not entry then return end
  newWinner = strtrim(newWinner or "")
  if newWinner ~= "" and ns.RankOf(newWinner) == nil then ns.Say(newWinner .. " isn't in the guild.") return end
  if not ns.UndoDKP(entry, newWinner ~= "" and ("Reassigned to " .. newWinner) or "Refunded") then return end
  if newWinner ~= "" then
    newWinner = Ambiguate(newWinner, "none")
    ns.LedgerAdd("DK", { amount = entry.amount, names = newWinner, reason = entry.reason })
    ns.Say(ns.TF("%s now goes to %s for %d DKP; %s was refunded.", l.item, newWinner, l.amount, l.winner))
  else
    ns.Say(ns.TF("%s was refunded %d DKP for %s.", l.winner, l.amount, l.item))
  end
end

------------------------------------------------------------------------
-- Import starting balances
------------------------------------------------------------------------
-- Lines like "Alice, 120" or "Alice 120". Returns the parsed list and any
-- lines that couldn't be read.
function ns.ParseImport(text)
  local rows, bad = {}, {}
  for line in (text or ""):gmatch("[^\r\n]+") do
    local name, amount = line:match("^%s*([^%s,;\t]+)[%s,;\t]+(%-?%d+)%s*$")
    if name and tonumber(amount) then
      rows[#rows + 1] = { name = name, amount = tonumber(amount), known = ns.RankOf(name) ~= nil }
    elseif strtrim(line) ~= "" and not line:lower():find("^%s*name") then
      bad[#bad + 1] = line
    end
  end
  return rows, bad
end

-- Set each member's balance to the given number.
function ns.ImportBalances(rows)
  if not ns.IsAddonOfficer() then ns.Say("Only officers can import DKP.") return end
  local byDiff, changed = {}, 0
  for _, r in ipairs(rows) do
    local diff = r.amount - ns.Balance(r.name)
    if diff ~= 0 then
      byDiff[diff] = byDiff[diff] or {}
      table.insert(byDiff[diff], Ambiguate(r.name, "none"))
      changed = changed + 1
    end
  end
  for diff, names in pairs(byDiff) do ns.AwardDKP(names, diff, "Starting balance") end
  ns.Say(ns.TP(changed, "Imported %d balance (%d already matched).", "Imported %d balances (%d already matched).",
    changed, #rows - changed))
end

------------------------------------------------------------------------
-- Can a class use an item? (to warn before bidding)
------------------------------------------------------------------------
local ARMOR = {      -- armor subclass -> classes that can wear it
  [2] = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, ROGUE = 1, SHAMAN = 1, DRUID = 1, DEATHKNIGHT = 1, MONK = 1, DEMONHUNTER = 1 },
  [3] = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, SHAMAN = 1, DEATHKNIGHT = 1, EVOKER = 1 },
  [4] = { WARRIOR = 1, PALADIN = 1, DEATHKNIGHT = 1 },
  [6] = { WARRIOR = 1, PALADIN = 1, SHAMAN = 1 },
  [7] = { PALADIN = 1 }, [8] = { DRUID = 1 }, [9] = { SHAMAN = 1 },
}
local WEAPON = {     -- weapon subclass -> classes that can use it
  [0]  = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, ROGUE = 1, SHAMAN = 1, DEATHKNIGHT = 1, MONK = 1, DEMONHUNTER = 1, EVOKER = 1 },
  [1]  = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, SHAMAN = 1, DEATHKNIGHT = 1, EVOKER = 1 },
  [2]  = { WARRIOR = 1, HUNTER = 1, ROGUE = 1 },
  [3]  = { WARRIOR = 1, HUNTER = 1, ROGUE = 1 },
  [4]  = { WARRIOR = 1, PALADIN = 1, ROGUE = 1, PRIEST = 1, SHAMAN = 1, DRUID = 1, DEATHKNIGHT = 1, MONK = 1, EVOKER = 1 },
  [5]  = { WARRIOR = 1, PALADIN = 1, SHAMAN = 1, DRUID = 1, DEATHKNIGHT = 1, EVOKER = 1 },
  [6]  = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, DRUID = 1, DEATHKNIGHT = 1, MONK = 1 },
  [7]  = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, ROGUE = 1, MAGE = 1, WARLOCK = 1, DEATHKNIGHT = 1, MONK = 1, DEMONHUNTER = 1, EVOKER = 1 },
  [8]  = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, DEATHKNIGHT = 1, EVOKER = 1 },
  [10] = { WARRIOR = 1, HUNTER = 1, PRIEST = 1, SHAMAN = 1, MAGE = 1, WARLOCK = 1, DRUID = 1, MONK = 1, EVOKER = 1 },
  [13] = { WARRIOR = 1, HUNTER = 1, ROGUE = 1, SHAMAN = 1, DRUID = 1, MONK = 1, DEMONHUNTER = 1, EVOKER = 1 },
  [15] = { WARRIOR = 1, HUNTER = 1, ROGUE = 1, PRIEST = 1, SHAMAN = 1, MAGE = 1, WARLOCK = 1, DRUID = 1, EVOKER = 1 },
  [16] = { WARRIOR = 1, HUNTER = 1, ROGUE = 1 },
  [18] = { WARRIOR = 1, HUNTER = 1, ROGUE = 1 },
  [19] = { PRIEST = 1, MAGE = 1, WARLOCK = 1 },
}

-- true, false, or nil when it can't tell (cloth, jewelry, trinkets, unknown items).
function ns.CanUseItem(link, classFile)
  if not (link and classFile) then return nil end
  local getInfo = C_Item.GetItemInfoInstant
  if not getInfo then return nil end
  local ok, _, _, _, _, _, classID, subclassID = pcall(getInfo, link)
  if not ok or not classID then return nil end
  local table_ = (classID == 4 and ARMOR[subclassID]) or (classID == 2 and WEAPON[subclassID]) or nil
  if not table_ then return nil end
  return table_[classFile] ~= nil
end

------------------------------------------------------------------------
-- DKP rules (decay and hidden bids), set by officers for the whole guild
------------------------------------------------------------------------
local WEEK = 7 * 86400
local WEEK_START = 486000 -- weeks start Tuesday 15:00 UTC (the US weekly reset)

local function weekOf(t) return math.floor((t - WEEK_START) / WEEK) end

-- A raid week (Tuesday reset to Tuesday reset) as a time range.
-- offset 0 = this week, -1 = last week. Returns its start, its end and its number.
function ns.WeekRange(offset)
  local w = weekOf(GetServerTime()) + (offset or 0)
  local fromT = WEEK_START + w * WEEK
  return fromT, fromT + WEEK, w
end

-- { decay = percent, auto = weekly decay on, hidden = hidden bids on, t = when set }
function ns.DKPRules()
  local list = ns.LedgerEntries("DS")
  local r = list[#list]
  if not r then return { decay = 10, auto = false, hidden = false, t = 0 } end
  return { decay = r.decay > 0 and r.decay or 10, auto = r.auto == "1", hidden = r.hidden == "1", t = r.t }
end

function ns.SetDKPRules(decay, auto, hidden)
  decay = math.max(1, math.min(50, math.floor(tonumber(decay) or 10)))
  ns.LedgerAdd("DS", { decay = decay, auto = auto and "1" or "0", hidden = hidden and "1" or "0" })
end

local function decayedThisWeek(week)
  for _, e in ipairs(ns.LedgerEntries("DK")) do
    local w = e.reason:match("%(week (%d+)%)$")
    if w and tonumber(w) == week then return true end
  end
  return false
end

-- Take a percentage off everyone with DKP. Members losing the same amount
-- share one entry, to keep the record small.
function ns.ApplyDecay(percent, automatic)
  if not ns.IsAddonOfficer() then ns.Say("Only officers can decay DKP.") return end
  percent = math.max(1, math.min(50, math.floor(tonumber(percent) or 10)))
  local week = weekOf(GetServerTime())
  if decayedThisWeek(week) then
    if not automatic then ns.Say("DKP has already been decayed this week.") end
    return
  end
  local byAmount = {}
  for _, b in pairs(ns.DKPBalances()) do
    local cut = math.floor(b.dkp * percent / 100)
    if cut > 0 then
      byAmount[cut] = byAmount[cut] or {}
      table.insert(byAmount[cut], b.name)
    end
  end
  local members = 0
  for cut, names in pairs(byAmount) do
    members = members + #names
    ns.AwardDKP(names, -cut, ("Decay %d%% (week %d)"):format(percent, week))
  end
  ns.Say(ns.TP(members, "DKP decayed by %d%% for %d member.", "DKP decayed by %d%% for %d members.", percent, members))
end

-- Weekly decay: an online officer applies it once the new week has started.
local function autoDecay()
  if not ns.IsAddonOfficer() then return end
  local rules = ns.DKPRules()
  if not rules.auto then return end
  local week = weekOf(GetServerTime())
  if week <= weekOf(rules.t) then return end -- turned on this week: starts next week
  if decayedThisWeek(week) then return end
  ns.ApplyDecay(rules.decay, true)
end

table.insert(ns.OnGuildReady, function()
  -- Wait for the record to catch up first, and spread officers out.
  C_Timer.After(90 + math.random() * 120, autoDecay)
  C_Timer.NewTicker(30 * 60, autoDecay)
end)

------------------------------------------------------------------------
-- Auctions: the officer running it
------------------------------------------------------------------------
local auction -- the auction this officer is running

local function finish()
  local a = auction
  auction = nil
  if not a then return end
  if a.hidden then
    -- Highest bid wins (earliest if tied) and pays the second-highest bid + 1.
    local list = {}
    for name, b in pairs(a.bids) do list[#list + 1] = { name = name, amount = b.amount, t = b.t } end
    table.sort(list, function(x, y)
      if x.amount ~= y.amount then return x.amount > y.amount end
      return x.t < y.t
    end)
    if list[1] then
      a.bidder = list[1].name
      a.high = list[2] and math.min(list[1].amount, list[2].amount + 1) or a.min
    end
  end
  if a.bidder then
    ns.AwardDKP({ a.bidder }, -a.high, "Won " .. a.link)
    ns.SendRaid("B4", a.id, Ambiguate(a.bidder, "short"), a.high)
  else
    -- Nobody bid: open a free roll instead.
    ns.SendRaid("B4", a.id, "", 0, "roll")
    ns.StartFreeRoll(a.id, a.link)
  end
end

------------------------------------------------------------------------
-- Free rolls: when nobody bids, anyone in the raid can /roll for it
------------------------------------------------------------------------
local ROLL_TIME = 20
local roll        -- the roll this officer is running
local rollPattern

function ns.StartFreeRoll(id, link)
  roll = { id = id, link = link, ends = GetTime() + ROLL_TIME, rolls = {} }
  rollPattern = rollPattern or ns.FormatToPattern(RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)")
  ns.SendRaid("B7", id, ROLL_TIME)
end

local function finishRoll()
  local r = roll
  roll = nil
  local best
  for _, x in ipairs(r.rolls) do
    if not best or x.value > best.value then best = x end -- ties go to whoever rolled first
  end
  if best then
    ns.LedgerAdd("DK", { amount = 0, names = best.name, reason = "Won " .. r.link .. " (free roll)" })
  end
  ns.SendRaid("B8", r.id, best and Ambiguate(best.name, "short") or "", best and best.value or 0)
end

-- Count each raid member's first 1-100 roll.
ns.OnEvent("CHAT_MSG_SYSTEM", function(text)
  if not roll or not rollPattern then return end
  text = ns.Usable(text)
  if type(text) ~= "string" then return end
  local name, value, low, high = text:match(rollPattern)
  value, low, high = tonumber(value), tonumber(low), tonumber(high)
  if not (name and value and low == 1 and high == 100) then return end
  local inRaid = false
  for _, m in ipairs(ns.CurrentRaidMembers()) do
    if ns.Key(m.name) == ns.Key(name) then inRaid = true break end
  end
  if not inRaid then return end
  for _, x in ipairs(roll.rolls) do
    if ns.Key(x.name) == ns.Key(name) then return end
  end
  table.insert(roll.rolls, { name = Ambiguate(name, "none"), value = value })
end)

ns.OnLoad(function()
  C_Timer.NewTicker(0.5, function()
    -- Rolls can't be seen during a boss fight: wait for it to end.
    if roll and not ns.HoldCountdown(roll, ROLL_TIME) and GetTime() >= roll.ends then finishRoll() end
  end)
end)

local function tick()
  local a = auction
  if not a then return end
  -- Nobody can bid while addon chat is locked (a boss fight): the clock waits.
  if ns.HoldCountdown(a, SNIPE_GUARD * 2) then a.held = true return end
  if a.held then
    -- Everyone's clock waited too; put the leader's time right.
    a.held = nil
    if not a.hidden and a.bidder then
      ns.SendRaid("B3", a.id, a.high, Ambiguate(a.bidder, "short"), math.ceil(a.ends - GetTime()))
    end
  end
  if GetTime() >= a.ends then finish() end
end

function ns.StartAuction(link, minBid, duration)
  if not ns.UsesDKP() then ns.Say("DKP is turned off for the guild (Settings > Alerts > Use DKP for loot).") return end
  if not ns.IsAddonOfficer() then ns.Say("Only officers can run loot auctions.") return end
  if not IsInRaid() then ns.Say("You need to be in a raid group to run an auction.") return end
  if auction then ns.Say("An auction is already running.") return end
  if ns.ChatLocked() then ns.Say("Wait for the fight to end: the game blocks addon messages until then, so nobody could bid.") return end
  link = strtrim(link or "")
  if link == "" then ns.Say("Put an item in first: Shift-click it into the item box.") return end
  minBid = math.max(1, math.floor(tonumber(minBid) or 1))
  duration = math.max(10, math.floor(tonumber(duration) or 30))
  local hidden = ns.DKPRules().hidden
  auction = { id = tostring(GetServerTime()), link = link, min = minBid, high = 0,
    ends = GetTime() + duration, hidden = hidden, bids = {} }
  ns.SendRaid("B1", auction.id, link, minBid, duration, hidden and "hidden" or "open")
  return true
end

function ns.CancelAuction()
  if roll then roll = nil end
  if not auction then return end
  local id = auction.id
  auction = nil
  ns.SendRaid("B4", id, "", 0, "cancelled")
end

function ns.AuctionRunning() return auction ~= nil or roll ~= nil end

-- A bid arrived. Only the officer running the auction acts on it.
ns.OnMessage("B2", function(p, sender)
  local a = auction
  if not a or p[2] ~= a.id then return end
  local amount = math.floor(tonumber(p[3]) or 0)
  local function reject(reason) ns.SendTo(sender, "B5", a.id, reason) end
  if ns.RankOf(sender) == nil then return reject("Only guild members can bid.") end
  if a.hidden then
    if amount < a.min then return reject(("Bids must be at least %d."):format(a.min)) end
    if amount > ns.Balance(sender) then return reject(("You only have %d DKP."):format(ns.Balance(sender))) end
    local name = Ambiguate(sender, "none")
    a.bids[name] = { amount = amount, t = (a.bids[name] and a.bids[name].t) or GetTime() }
    ns.SendTo(sender, "B6", a.id, amount)
    return
  end
  local needed = a.bidder and (a.high + 1) or a.min
  if amount < needed then return reject(("Bids must be at least %d."):format(needed)) end
  if amount > ns.Balance(sender) then
    return reject(("You only have %d DKP."):format(ns.Balance(sender)))
  end
  a.high, a.bidder = amount, Ambiguate(sender, "none")
  if a.ends - GetTime() < SNIPE_GUARD then a.ends = GetTime() + SNIPE_GUARD end
  ns.SendRaid("B3", a.id, amount, Ambiguate(sender, "short"), math.ceil(a.ends - GetTime()))
end)

ns.OnLoad(function() C_Timer.NewTicker(0.5, tick) end)

------------------------------------------------------------------------
-- Auctions: everyone in the raid
------------------------------------------------------------------------
ns.auction = nil -- what the bid window shows

ns.OnMessage("B1", function(p, sender)
  local link = p[3]
  if not link or link == "" then return end
  local duration = tonumber(p[5]) or 30
  ns.auction = { id = p[2], link = link, min = tonumber(p[4]) or 1, high = 0, leader = nil,
    ends = GetTime() + duration, by = Ambiguate(sender, "short"), hidden = p[6] == "hidden" }
  if ns.ShowAuctionWindow then ns.ShowAuctionWindow() end
  ns.Notify(ns.TF("|cffffd200Loot auction: %s - minimum bid %d DKP.|r", link, ns.auction.min), nil, nil, true, "loot")
  if ns.OnAuctionStarted then ns.OnAuctionStarted(ns.auction) end
end)

ns.OnMessage("B3", function(p)
  local a = ns.auction
  if not a or a.id ~= p[2] then return end
  a.high, a.leader = tonumber(p[3]) or a.high, (p[4] ~= "" and p[4]) or a.leader
  a.ends = GetTime() + (tonumber(p[5]) or 0)
  if ns.RefreshAuctionWindow then ns.RefreshAuctionWindow() end
end)

ns.OnMessage("B4", function(p)
  local a = ns.auction
  if not a or a.id ~= p[2] then return end
  a.done = true
  local winner, amount = p[3], tonumber(p[4]) or 0
  if p[5] == "roll" then
    a.result = "No bids. Free roll for anyone who wants it!"
    if ns.RefreshAuctionWindow then ns.RefreshAuctionWindow() end
    return
  elseif p[5] == "cancelled" then
    a.result = "Auction cancelled."
  elseif winner and winner ~= "" then
    a.result = ("%s won it for %d DKP."):format(winner, amount)
    ns.Say(ns.TF("%s won %s for %d DKP.", winner, a.link, amount))
  else
    a.result = "No bids. Nobody won it."
  end
  if ns.RefreshAuctionWindow then ns.RefreshAuctionWindow() end
  C_Timer.After(6, function()
    if ns.auction == a and ns.HideAuctionWindow then ns.HideAuctionWindow() end
  end)
end)

-- A free roll opened (nobody bid).
ns.OnMessage("B7", function(p)
  local a = ns.auction
  if not a or a.id ~= p[2] then return end
  a.rolling, a.ends = true, GetTime() + (tonumber(p[3]) or 20)
  if ns.RefreshAuctionWindow then ns.RefreshAuctionWindow() end
end)

-- The free roll's result.
ns.OnMessage("B8", function(p)
  local a = ns.auction
  if not a or a.id ~= p[2] then return end
  a.rolling, a.done = false, true
  local winner, value = p[3], tonumber(p[4]) or 0
  a.result = (winner and winner ~= "") and ("%s won the roll (%d)."):format(winner, value) or "Nobody rolled."
  if winner and winner ~= "" then ns.Say(ns.TF("%s won %s with a roll of %d.", winner, a.link, value)) end
  if ns.RefreshAuctionWindow then ns.RefreshAuctionWindow() end
  C_Timer.After(6, function()
    if ns.auction == a and ns.HideAuctionWindow then ns.HideAuctionWindow() end
  end)
end)

function ns.RollForItem()
  local f = RandomRoll
  if f then pcall(f, 1, 100) end
end

-- Hidden bids: the officer confirms yours privately.
ns.OnMessage("B6", function(p)
  local a = ns.auction
  if not a or a.id ~= p[2] then return end
  a.myBid = tonumber(p[3])
  if ns.RefreshAuctionWindow then ns.RefreshAuctionWindow() end
end)

ns.OnMessage("B5", function(p)
  local a = ns.auction
  if a and a.id == p[2] then ns.Say("|cffff6060Bid not accepted: " .. (p[3] or "") .. "|r") end
end)

function ns.PlaceBid(amount)
  local a = ns.auction
  if not a or a.done then return end
  amount = math.floor(tonumber(amount) or 0)
  if amount <= 0 then return end
  ns.SendRaid("B2", a.id, amount)
end
