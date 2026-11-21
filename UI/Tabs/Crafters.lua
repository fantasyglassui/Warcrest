--[[
  Warcrest
  Guild > Crafters: search what the guild can make, see who makes it
  (online first), and pick a recipe to order it from a crafter or whisper
  them. The Orders view lists the orders for you to make and the ones you've
  asked for. Also /warcrest craft or /warcrest orders.
]]

local _, ns = ...
local UI = ns.UI

local W = UI.PAGE_W
local win -- the page
local query, prof = "", nil
local view = "recipes" -- "recipes" or "orders"
local picked           -- the recipe row picked: { id, name, crafters }
local orderTo          -- the crafter to order it from

local function profOptions()
  local opts = { { "", "All professions" } }
  for _, p in ipairs(ns.CraftProfessions()) do opts[#opts + 1] = { p, p } end
  return opts
end

local function craftersText(r)
  local names = {}
  for i, c in ipairs(r.crafters) do
    if i > 3 then
      names[#names + 1] = UI.Code("muted") .. ns.TF("+%d more", #r.crafters - 3) .. "|r"
      break
    end
    names[#names + 1] = (c.online and UI.Code("good") or UI.Code("muted")) .. c.name .. "|r"
  end
  return table.concat(names, ", ")
end

local TAB = { id = "crafters", title = "Crafters" }

local function Build(page)
  win = page
  win.search = UI.SearchBox(page, 260, "Search recipes", function(text)
    query = text
    ns.RefreshCrafters()
  end)
  win.search:SetPoint("TOPLEFT", 1, 0)
  win.prof = UI.Cycle(page, 180, profOptions(), function(v)
    prof = v ~= "" and v or nil
    ns.RefreshCrafters()
  end)
  win.prof:SetHeight(26)
  win.prof:SetPoint("LEFT", win.search, "RIGHT", 8, 0)
  UI.Tooltip(win.prof, "Profession", "Click to show one profession's recipes.")
  win.view = UI.Segmented(page.headerBar, { { "recipes", "Recipes" }, { "orders", "Orders" } }, function(v)
    view = v
    ns.RefreshPanel()
  end)
  win.view:SetPoint("RIGHT")
  TAB.view = win.view -- so OpenPanel("crafters", "orders") picks the view

  local box = CreateFrame("Frame", nil, win)
  win.recipeBox = box
  box:SetPoint("TOPLEFT", 1, -37)
  box:SetSize(W - 2, 326)
  UI.Card(box, 1)
  local y = UI.TableHeads(box, { { "RECIPE", 12 }, { "PROFESSION", 320 }, { "CRAFTERS", 460 } })
  win.rows = UI.List(box, W - 4, 326 + y - 2, 24,
    function(row)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("LEFT", 12, 0)
      row.name:SetWidth(298)
      row.name:SetWordWrap(false)
      row.prof = UI.Label(row, "", "Small")
      row.prof:SetPoint("LEFT", 320, 0)
      row.prof:SetWidth(120)
      row.prof:SetWordWrap(false)
      row.who = UI.Label(row, "", "Small")
      row.who:SetPoint("LEFT", 460, 0)
      row.who:SetWidth(W - 460 - 30)
      row.who:SetWordWrap(false)
      UI.RowSelection(row)
      UI.RowLine(row)
      row:SetScript("OnClick", function(self)
        picked = self.item
        orderTo = self.item.crafters[1] and self.item.crafters[1].name
        ns.RefreshCrafters()
      end)
      UI.Tooltip(row, function() return row.item.name end, function()
        local lines = {}
        for _, c in ipairs(row.item.crafters) do
          lines[#lines + 1] = (c.online and UI.Code("good") or UI.Code("muted")) .. c.name .. "|r"
            .. UI.Code("muted") .. "  (" .. c.rank .. ")" .. "|r"
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = ns.T("Click to order it, or whisper the crafter.")
        return table.concat(lines, "\n")
      end)
    end,
    function(row, r)
      row.name:SetText(r.name)
      row.prof:SetText(r.prof)
      row.who:SetText(craftersText(r))
      UI.SetRowSelected(row, picked ~= nil and r.id == picked.id)
    end, true)
  win.rows.frame:SetPoint("TOPLEFT", box, "TOPLEFT", 0, y - 1)

  win.hint = UI.Label(page, "Open your profession windows to share your recipes with the guild.", "MutedSmall")
  win.hint:SetPoint("TOPLEFT", 4, -376)
  win.hint:SetWidth(W - 8)
  win.hint:SetWordWrap(false)

  -- Ordering the recipe picked.
  local o = CreateFrame("Frame", nil, page)
  win.order = o
  o:SetPoint("TOPLEFT", 1, -374)
  o:SetSize(W - 2, 44)
  o.what = UI.Label(o, "", "Subheading")
  o.what:SetPoint("TOPLEFT", 0, -2)
  o.what:SetWidth(W - 240)
  o.what:SetWordWrap(false)
  o.to = UI.Cycle(o, 220, { { "", "" } }, function(v) orderTo = v; ns.RefreshCrafters() end)
  o.to:SetHeight(24)
  o.to:SetPoint("TOPRIGHT", 0, 2)
  UI.Tooltip(o.to, "Crafter", "Click to pick who to ask. Online crafters come first.")
  o.mats = UI.Check(o, "I'll bring the materials", -4, -22)
  o.note = UI.EditBox(o, 220, 60)
  o.note:SetHeight(24)
  o.note:SetPoint("TOPLEFT", 200, -22)
  o.note.hint = UI.Label(o.note, "Note (optional)", "MutedSmall")
  o.note.hint:SetPoint("LEFT", 8, 0)
  o.note:HookScript("OnTextChanged", function(self) self.hint:SetShown((self:GetText() or "") == "") end)
  o.send = UI.Button(o, "Place order", 120, "primary")
  o.send:SetHeight(24)
  o.send:SetPoint("TOPLEFT", 428, -22)
  o.send:SetScript("OnClick", function()
    if picked and orderTo and ns.PlaceCraftOrder(orderTo, picked.id, o.mats:GetChecked(), o.note:GetText()) then
      o.note:SetText("")
      ns.Say(ns.TF("Order sent to %s.", orderTo))
    end
  end)
  o.whisper = UI.Button(o, "Whisper", 104)
  o.whisper:SetHeight(24)
  o.whisper:SetPoint("LEFT", o.send, "RIGHT", 8, 0)
  o.whisper:SetScript("OnClick", function() if picked and orderTo then ns.AskCrafter(orderTo, picked.id) end end)

  -- Orders: for you to make, and the ones you asked for.
  local ob = CreateFrame("Frame", nil, page)
  win.ordersBox = ob
  ob:SetPoint("TOPLEFT", 1, 0)
  ob:SetSize(W - 2, 364)
  UI.Card(ob, 1)
  local oy = UI.TableHeads(ob, { { "RECIPE", 12 }, { "ORDER", 260 }, { "STATUS", 460 } })
  win.orders = UI.List(ob, W - 4, 364 + oy - 2, 30,
    function(row)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("LEFT", 12, 0)
      row.name:SetWidth(240)
      row.name:SetWordWrap(false)
      row.who = UI.Label(row, "", "Small")
      row.who:SetPoint("LEFT", 260, 0)
      row.who:SetWidth(190)
      row.who:SetWordWrap(false)
      row.status = UI.Label(row, "", "Small")
      row.status:SetPoint("LEFT", 460, 0)
      row.b2 = UI.Button(row, "", 76)
      row.b2:SetHeight(22)
      row.b2:SetPoint("RIGHT", -14, 0)
      row.b1 = UI.Button(row, "", 76)
      row.b1:SetHeight(22)
      row.b1:SetPoint("RIGHT", row.b2, "LEFT", -6, 0)
      for _, b in ipairs({ row.b1, row.b2 }) do
        b:SetScript("OnClick", function(self) if self.status then ns.UpdateCraftOrder(row.item.id, self.status) end end)
      end
      UI.RowLine(row)
      UI.Tooltip(row, function() return row.item.label end, function()
        local it = row.item
        local lines = { ns.TF("Asked %s", ns.Date("%b %d, %H:%M", it.t)) }
        lines[#lines + 1] = it.mats and ns.T("Bringing the materials.") or ns.T("Not bringing materials.")
        if it.note ~= "" then lines[#lines + 1] = "\"" .. it.note .. "\"" end
        return table.concat(lines, "\n")
      end)
    end,
    function(row, it)
      row.name:SetText(it.label)
      row.who:SetText((it.forMe and ns.TF("From %s", UI.Code("text") .. ns.Ambiguate(it.by, "short") .. "|r")
        or ns.TF("Asked %s", UI.Code("text") .. ns.Ambiguate(it.crafter, "short") .. "|r"))
        .. (it.mats and (UI.Code("muted") .. " · " .. ns.T("mats") .. "|r") or ""))
      local st = ns.ORDER_STATUSES[it.status]
      row.status:SetText("|cff" .. st.color .. ns.T(st.label) .. "|r")
      local acts = {}
      if it.forMe then
        if it.status == "open" then acts = { { "Accept", "accepted" }, { "Decline", "declined" } }
        elseif it.status == "accepted" then acts = { { "Done", "done" }, { "Decline", "declined" } } end
      elseif it.status == "open" or it.status == "accepted" then
        acts = { { "Cancel", "cancelled" } }
      end
      local buttons = { row.b1, row.b2 }
      if #acts == 1 then buttons = { row.b2 } ; row.b1:Hide() end
      for i, b in ipairs(buttons) do
        local a = acts[i]
        b:SetShown(a ~= nil)
        if a then b:SetText(ns.T(a[1])); b.status = a[2] end
      end
    end, true)
  win.orders.frame:SetPoint("TOPLEFT", ob, "TOPLEFT", 0, oy - 1)

  -- A bigger window: the lists get the room, the order line stays under them.
  UI.Grow(page, box, 1, 1)
  UI.Grow(page, win.rows, 1, 1)
  UI.Grow(page, ob, 1, 1)
  UI.Grow(page, win.orders, 1, 1)
  UI.Follow(page, o, 0, 1)
  UI.Follow(page, win.hint, 0, 1)
end

local function refreshOrders()
  local forMe, mine = ns.MyCraftOrders()
  local rows = {}
  for _, o in ipairs(forMe) do
    rows[#rows + 1] = { id = o.id, label = ns.RecipeName(o.recipe) or ("#" .. o.recipe), by = o.by, crafter = o.crafter,
      status = o.status, mats = o.mats, note = o.note, t = o.t, forMe = true }
  end
  for _, o in ipairs(mine) do
    rows[#rows + 1] = { id = o.id, label = ns.RecipeName(o.recipe) or ("#" .. o.recipe), by = o.by, crafter = o.crafter,
      status = o.status, mats = o.mats, note = o.note, t = o.t, forMe = false }
  end
  win.orders:SetEmptyText(ns.T("No orders. Pick a recipe on Recipes to order it from a guild crafter."))
  win.orders:SetItems(rows)
end

local function Refresh()
  win.view:SetValue(view)
  local waiting = ns.OrdersWaiting()
  win.recipeBox:SetShown(view == "recipes")
  win.ordersBox:SetShown(view == "orders")
  win.search:SetShown(view == "recipes")
  win.prof:SetShown(view == "recipes")
  win.hint:SetText(ns.T(view == "orders" and (waiting > 0 and "Orders waiting for you: accept or decline them." or "Your orders, and the orders for you to make.")
    or "Open your profession windows to share your recipes with the guild."))
  if view == "orders" then
    win.order:Hide()
    refreshOrders()
    return
  end
  -- The profession list grows as lists arrive.
  local opts = profOptions()
  win.prof.options = opts
  local found = false
  for i, o in ipairs(opts) do
    if o[1] == (prof or "") then win.prof.index, win.prof.value, found = i, o[1], true end
  end
  if not found then prof, win.prof.index, win.prof.value = nil, 1, "" end
  win.prof:SetText(win.prof.index == 1 and ns.T(opts[1][2]) or opts[win.prof.index][2])

  local list = ns.CraftSearch(query, prof)
  -- The recipe picked, and who to order it from.
  local still
  for _, r in ipairs(list) do if picked and r.id == picked.id then still = r end end
  picked = still
  local o = win.order
  o:SetShown(picked ~= nil)
  win.hint:SetShown(picked == nil)
  if picked then
    local who, has = {}, false
    for _, c in ipairs(picked.crafters) do
      if not ns.IsMe(c.name) then
        who[#who + 1] = { c.name, c.name .. (c.online and "" or (" (" .. ns.T("offline") .. ")")) }
        if c.name == orderTo then has = true end
      end
    end
    if #who == 0 then who = { { "", ns.T("Only you make this") } } end
    if not has then orderTo = who[1][1] ~= "" and who[1][1] or nil end
    o.to.options = who
    for i, op in ipairs(who) do if op[1] == (orderTo or "") then o.to.index, o.to.value = i, op[1] end end
    o.to:SetText(who[o.to.index or 1][2])
    o.what:SetText(ns.TF("Order %s", UI.Code("accent") .. picked.name .. "|r"))
    UI.SetEnabled(o.send, orderTo ~= nil)
    UI.SetEnabled(o.whisper, orderTo ~= nil)
  end
  win.rows:SetEmptyText(query ~= "" and ns.T("Nobody in the guild makes that yet.")
    or ns.EmptyHint("No recipes shared yet. They show up once guildmates open their profession windows."))
  win.rows:SetItems(list)
end

-- Only while the page is showing.
function ns.RefreshCrafters()
  if win and win:IsShown() then Refresh() end
end

-- The header's subtitle: how many crafters and recipes.
local function Subtitle()
  local people, recipes = ns.CraftStats()
  return ns.TF("%d crafters · %d recipes", people, recipes)
end

-- Opens Guild > Crafters; which: "recipes" or "orders".
function ns.ShowCrafters(search, which)
  if which then view = which end
  ns.OpenPanel("crafters", which)
  if win and search and search ~= "" then win.search:SetText(search) end
end

TAB.build, TAB.refresh, TAB.subtitle = Build, Refresh, Subtitle
UI.AddTab(TAB)

ns.OnLoad(function() ns.OnLedgerChanged(function() if view == "orders" then ns.RefreshCrafters() end end) end)
