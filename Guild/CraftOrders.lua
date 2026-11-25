--[[
  Warcrest
  Crafting orders: ask a guild crafter to make something, from the crafters
  directory. Say whether you're bringing the materials and add a note. The
  crafter accepts (or declines) and marks it done when it's made; you can
  cancel it. Both of you see where it's up to, and hear when it changes.

  Shared record: CO { crafter, recipe, mats, note } an order (by whoever
  wants it), CU { ref, status } a change: accepted, declined or done (by the
  crafter) or cancelled (by whoever ordered it). The latest change counts.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local KEEP_DAYS = 30        -- orders older than this are gone
local DONE_DAYS = 7         -- finished orders stay listed this long
local NOTE_MAX = 60

ns.ORDER_STATUSES = {
  open      = { label = "Waiting",   color = "ffd200" },
  accepted  = { label = "Accepted",  color = "66ccff" },
  done      = { label = "Done",      color = "5ed36b" },
  declined  = { label = "Declined",  color = "8a8a8a" },
  cancelled = { label = "Cancelled", color = "8a8a8a" },
}
local BY_CRAFTER = { accepted = true, declined = true, done = true }

ns.OnLoad(function()
  ns.db.ordersSeen = ns.db.ordersSeen or {} -- order id -> the status you last heard about
end)

------------------------------------------------------------------------
-- The orders
------------------------------------------------------------------------
local cache, cacheStamp
local function build()
  local stamp = ns.LedgerStamp("CO", "CU")
  if cache and cacheStamp == stamp then return cache end
  cache, cacheStamp = { list = {}, byId = {} }, stamp
  local now = GetServerTime()
  for _, e in ipairs(ns.LedgerEntries("CO")) do
    if now - e.t < KEEP_DAYS * 86400 and e.recipe and e.recipe:match("^e?%d+$") and (e.crafter or "") ~= "" then
      local o = { id = e.id, by = e.a, crafter = e.crafter, recipe = e.recipe, mats = e.mats == "1",
        note = e.note or "", t = e.t, status = "open", changed = e.t }
      cache.byId[e.id] = o
      cache.list[#cache.list + 1] = o
    end
  end
  for _, u in ipairs(ns.LedgerEntries("CU")) do -- oldest first: the latest change counts
    local o = cache.byId[u.ref]
    if o and ns.ORDER_STATUSES[u.status] then
      local crafter = ns.Key(u.a) == ns.Key(o.crafter)
      local orderer = ns.Key(u.a) == ns.Key(o.by)
      local final = o.status == "done" or o.status == "declined" or o.status == "cancelled"
      if not final and ((BY_CRAFTER[u.status] and crafter) or (u.status == "cancelled" and orderer)) then
        o.status, o.changed = u.status, u.t
      end
    end
  end
  local keep = {}
  for _, o in ipairs(cache.list) do
    local finished = o.status == "done" or o.status == "declined" or o.status == "cancelled"
    if not finished or now - o.changed < DONE_DAYS * 86400 then keep[#keep + 1] = o end
  end
  cache.list = keep
  table.sort(cache.list, function(a, b) return a.t > b.t end)
  return cache
end

function ns.CraftOrder(id) return build().byId[id] end

-- Orders finished for a guildmate (not for yourself), still in the record:
-- crafter key -> sorted list of the times they were marked done.
function ns.CraftOrdersDone()
  local out = {}
  for _, o in pairs(build().byId) do
    if o.status == "done" and ns.Key(o.crafter) ~= ns.Key(o.by) then
      local k = ns.Key(o.crafter)
      out[k] = out[k] or {}
      table.insert(out[k], o.changed)
    end
  end
  for _, list in pairs(out) do table.sort(list) end
  return out
end

-- Your orders: the ones for you to make and the ones you asked for, newest first.
function ns.MyCraftOrders()
  local me = ns.Key(UnitName("player"))
  local forMe, mine = {}, {}
  for _, o in ipairs(build().list) do
    if ns.Key(o.crafter) == me then forMe[#forMe + 1] = o end
    if ns.Key(o.by) == me then mine[#mine + 1] = o end
  end
  return forMe, mine
end

-- How many orders are waiting for you to answer (for the Orders button).
function ns.OrdersWaiting()
  local n = 0
  for _, o in ipairs((ns.MyCraftOrders())) do if o.status == "open" then n = n + 1 end end
  return n
end

function ns.PlaceCraftOrder(crafter, recipe, mats, note)
  crafter = Ambiguate(crafter or "", "short")
  if crafter == "" or not tostring(recipe or ""):match("^e?%d+$") then return end
  if ns.IsMe(crafter) then ns.Say("That's you: open your profession window to make it.") return end
  -- The same thing from the same crafter, still open: don't order it twice.
  for _, o in ipairs((select(2, ns.MyCraftOrders()))) do
    if o.recipe == recipe and ns.Key(o.crafter) == ns.Key(crafter) and (o.status == "open" or o.status == "accepted") then
      ns.Say("You've already asked them for that.")
      return
    end
  end
  note = strtrim((note or ""):gsub("[%^|~]", " ")):sub(1, NOTE_MAX)
  return ns.LedgerAdd("CO", { crafter = crafter, recipe = recipe, mats = mats and "1" or "0", note = note })
end

function ns.UpdateCraftOrder(id, status)
  local o = ns.CraftOrder(id)
  if not o or not ns.ORDER_STATUSES[status] then return end
  if BY_CRAFTER[status] and not ns.IsMe(o.crafter) then return end
  if status == "cancelled" and not ns.IsMe(o.by) then return end
  if o.status == status then return true end
  return ns.LedgerAdd("CU", { ref = id, status = status })
end

------------------------------------------------------------------------
-- Hearing about your orders
------------------------------------------------------------------------
local function describe(o)
  local name = ns.RecipeName(o.recipe) or ("#" .. o.recipe)
  return "|cffffffff" .. name .. "|r"
end

local function check()
  if not ns.db or not ns.db.ordersSeen then return end
  local forMe, mine = ns.MyCraftOrders()
  local seen = ns.db.ordersSeen
  for _, o in ipairs(forMe) do
    if not seen[o.id] then
      seen[o.id] = o.status
      if o.status == "open" then
        ns.Notify(ns.TF("%s asks you to craft %s%s. See Orders in the crafters window.", Ambiguate(o.by, "short"),
          describe(o), o.mats and (" " .. ns.T("(bringing the materials)")) or ""), nil, nil, nil, "event", "Crafting order")
      end
    end
  end
  for _, o in ipairs(mine) do
    if seen[o.id] ~= o.status then
      local before = seen[o.id]
      seen[o.id] = o.status
      if before and o.status ~= "cancelled" then
        local text = o.status == "accepted" and ns.TF("%s will craft %s for you.", Ambiguate(o.crafter, "short"), describe(o))
          or o.status == "done" and ns.TF("%s has made %s for you.", Ambiguate(o.crafter, "short"), describe(o))
          or o.status == "declined" and ns.TF("%s can't craft %s for you this time.", Ambiguate(o.crafter, "short"), describe(o))
        if text then ns.Notify(text, nil, nil, nil, "event", "Crafting order") end
      end
    end
  end
  -- Forget orders that are gone.
  for id in pairs(seen) do if not ns.CraftOrder(id) then seen[id] = nil end end
end
ns.CheckCraftOrders = check

ns.OnLoad(function()
  ns.OnLedgerChanged(function() C_Timer.After(1, check) end)
end)
table.insert(ns.OnGuildReady, function()
  -- Orders that came in while you were away are news; changes to yours were seen already.
  local _, mine = ns.MyCraftOrders()
  for _, o in ipairs(mine) do ns.db.ordersSeen[o.id] = ns.db.ordersSeen[o.id] or o.status end
  C_Timer.After(30, check)
end)
