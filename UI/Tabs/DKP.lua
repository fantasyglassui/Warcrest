--[[
  Warcrest
  DKP tab: everyone's DKP, each member's history, and (for officers)
  awarding DKP and running loot auctions.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate
local UI = ns.UI

local P = {}
local selected = {}       -- name key -> true, for officer awards
local filterText = ""
local raidOnly = false
local view = "standings"  -- "loot" or "changes"

StaticPopupDialogs["IMPERIUM_DECAY"] = {
  text = "Take %s%% off everyone's DKP now? This can only be done once a week.",
  button1 = YES,
  button2 = NO,
  OnAccept = function() ns.ApplyDecay(P.decay:GetText()) end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["IMPERIUM_NEW_SEASON"] = {
  text = "Start a new DKP season?\n\nEveryone keeps their DKP, but DKP changes and loot history from before today, and raids older than 30 days, are archived for good. Export first if you want a copy.\n\nSeason name:",
  button1 = OKAY,
  button2 = CANCEL,
  hasEditBox = true,
  OnShow = function(self)
    local box = self.editBox or self.EditBox
    if box then box:SetText("Season " .. ns.Date("%b %Y")) end
  end,
  OnAccept = function(self)
    local box = self.editBox or self.EditBox
    ns.StartSeason(box and box:GetText() or "")
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["IMPERIUM_UNDO_DKP"] = {
  text = "Undo this DKP change for everyone?\n\n%s",
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, entry) if entry and ns.UndoDKP(entry, "") then ns.Say("DKP change undone.") end end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["IMPERIUM_FIX_LOOT"] = {
  text = "%s\n\nType a name to give it to someone else instead, or leave it blank to refund the DKP.",
  button1 = OKAY,
  button2 = CANCEL,
  hasEditBox = true,
  OnAccept = function(self, l)
    local box = self.editBox or self.EditBox
    if l then ns.ReassignLoot(l, box and box:GetText() or "") end
  end,
  EditBoxOnEnterPressed = function(self)
    local parent = self:GetParent()
    if parent.data then ns.ReassignLoot(parent.data, self:GetText()) end
    parent:Hide()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

local C = UI.C
local LEFT_W = 420              -- the table; the cards on the right fill the rest
local SIDE_X = LEFT_W + 14
local SIDE_W = 740 - SIDE_X
local ROW_H = 26
local SEARCH_HINT = { standings = "Search members", loot = "Search loot or winners", changes = "Search names or reasons" }

-- Heading text for a table column. right: offset from the right edge (the rows'
-- offset minus the scroll bar's room), else from the left.
local function Head(parent, text, x, right)
  local fs = UI.Label(parent, text, "Label")
  if right then
    fs:SetPoint("RIGHT", parent, "RIGHT", x, 0)
    fs:SetJustifyH("RIGHT")
  else
    fs:SetPoint("LEFT", x, 0)
  end
  return fs
end

local SCROLL_ROOM = 26 -- rows end this much left of the card's edge, for the scroll bar

local function RefreshChanges()
  local q, shown = filterText:lower(), {}
  for _, c in ipairs(ns.DKPChanges()) do
    local e = c.entry
    if q == "" or e.names:lower():find(q, 1, true) or e.reason:lower():find(q, 1, true) then shown[#shown + 1] = c end
  end
  P.changeList:SetEmptyText(q == "" and "No DKP changes yet." or "No changes match your search.")
  P.changeList:SetItems(shown)
end

local function RefreshLoot()
  local q, shown = filterText:lower(), {}
  for _, l in ipairs(ns.LootHistory()) do
    local itemText = l.item:gsub("|H.-|h(.-)|h", "%1"):lower()
    if q == "" or l.winner:lower():find(q, 1, true) or itemText:find(q, 1, true) then shown[#shown + 1] = l end
  end
  P.lootList:SetEmptyText(q == "" and "No loot has been won in an auction yet." or "No loot matches your search.")
  P.lootList:SetItems(shown)
end

local function Refresh()
  local officer = ns.IsAddonOfficer()
  local standings, loot, changes = view == "standings", view == "loot", view == "changes"
  P.list.frame:SetShown(standings)
  P.lootList.frame:SetShown(loot)
  P.changeList.frame:SetShown(changes)
  P.standingsHeads:SetShown(standings)
  P.lootHeads:SetShown(loot)
  P.changeHeads:SetShown(changes)
  P.raidOnly:SetShown(standings)
  P.search.hint:SetText(SEARCH_HINT[view])
  if loot then RefreshLoot() end
  if changes then RefreshChanges() end
  local requests = #ns.PendingAltRequests()
  P.alts:SetText(requests > 0 and ("Alts " .. UI.Code("bad") .. "(" .. requests .. ")|r") or "Alts")

  local list = ns.DKPStandings()
  local inRaid
  if raidOnly then
    inRaid = {}
    for _, m in ipairs(ns.CurrentRaidMembers()) do inRaid[ns.Key(m.name)] = true end
  end
  local q, shown = filterText:lower(), {}
  for _, m in ipairs(list) do
    if (q == "" or m.name:lower():find(q, 1, true)) and (not inRaid or inRaid[m.key]) then
      shown[#shown + 1] = m
    end
  end
  table.sort(shown, function(a, b)
    if a.dkp ~= b.dkp then return a.dkp > b.dkp end
    return a.name < b.name
  end)
  if q ~= "" or raidOnly then
    P.list:SetEmptyText(raidOnly and "Nobody in your raid matches." or "Nobody matches your search.")
  else
    P.list:SetEmptyText(ns.EmptyHint("Nobody has any DKP yet. Officers award it here, or it builds up from raid nights."))
  end
  P.list:SetItems(shown)

  local count = 0
  for _ in pairs(selected) do count = count + 1 end
  P.selectedText:SetText(count == 0 and "Tick members in the list" or (count .. " selected"))
  local c = count == 0 and C.faint or C.accent
  P.selectedText:SetTextColor(c[1], c[2], c[3])

  -- Officers get the award and auction tools; everyone else sees their own DKP.
  P.officer:SetShown(officer)
  P.member:SetShown(not officer)
  local sn = ns.CurrentSeason()
  P.mine:SetText(ns.Balance(UnitName("player")))
  P.season:SetText(sn and sn.name or "")
  local lines = {}
  for i, e in ipairs(ns.DKPHistory(UnitName("player"))) do
    if i > 16 then break end
    lines[#lines + 1] = ("%s%s|r  %s%+d|r  %s"):format(UI.Code("muted"), ns.Date("%b %d", e.t),
      e.amount >= 0 and UI.Code("good") or UI.Code("bad"), e.amount, e.reason)
  end
  P.myHistory:SetText(#lines > 0 and table.concat(lines, "\n") or (UI.Code("muted") .. "No DKP changes yet.|r"))

  local rules = ns.DKPRules()
  if not P.decay:HasFocus() then P.decay:SetText(rules.decay) end
  P.weekly:SetChecked(rules.auto)
  P.hidden:SetChecked(rules.hidden)
  P.rulesText:SetText(("%s%s|r decay%s · %s"):format(UI.Code("text"), rules.decay .. "%", rules.auto and " weekly" or "",
    rules.hidden and "hidden bids, winner pays 2nd-highest + 1" or "open bids"))
  local running = ns.AuctionRunning()
  P.auctionStart:SetShown(not running)
  P.auctionCancel:SetShown(running)
  UI.SetEnabled(P.auctionStart, officer and not running)
  UI.SetEnabled(P.auctionCancel, officer and running)
end

local function selectedNames()
  local names, list = {}, ns.DKPStandings()
  for _, m in ipairs(list) do
    if selected[m.key] then names[#names + 1] = m.full and Ambiguate(m.full, "none") or m.name end
  end
  return names
end

local function award(sign)
  local amount = tonumber(P.amount:GetText())
  if not amount or amount <= 0 then ns.Say("Enter an amount of DKP.") return end
  local names = selectedNames()
  if #names == 0 then ns.Say("Tick the members to give DKP to.") return end
  local reason = strtrim(P.reason:GetText() or "")
  if ns.AwardDKP(names, sign * amount, reason) then
    ns.Say(("%s %d DKP %s %d member%s."):format(sign > 0 and "Gave" or "Took", amount,
      sign > 0 and "to" or "from", #names, #names == 1 and "" or "s"))
    wipe(selected)
    P.reason:SetText("")
    ns.RefreshPanel()
  end
end

-- A card on the right, at y, this tall. Returns the frame.
local function Card(parent, y, height, title)
  local f = CreateFrame("Frame", nil, parent)
  f:SetPoint("TOPLEFT", 1, y - 1)
  f:SetSize(SIDE_W - 2, height)
  UI.Card(f, 1)
  if title then
    f.title = UI.Label(f, title, "Heading")
    f.title:SetPoint("TOPLEFT", 14, -12)
  end
  return f
end

-- A small field name above an input.
local function FieldLabel(parent, text, x, y)
  local fs = UI.Label(parent, text:upper(), "Label")
  fs:SetPoint("TOPLEFT", x, y)
  return fs
end

local function BuildOfficer(parent)
  local o = CreateFrame("Frame", nil, parent)
  o:SetAllPoints()
  P.officer = o
  local inner = SIDE_W - 30 -- width inside a card's padding

  -- Award DKP
  local awardCard = Card(o, 0, 142, "Award DKP")
  P.selectedText = UI.Label(awardCard, "", "Small")
  P.selectedText:SetPoint("TOPRIGHT", -14, -14)
  P.selectedText:SetJustifyH("RIGHT")
  local raidBtn = UI.Button(awardCard, "Select current raid", 136)
  raidBtn:SetPoint("TOPLEFT", 14, -36)
  UI.Tooltip(raidBtn, "Select current raid", "Ticks everyone in your raid group in the list, ready for an award.")
  raidBtn:SetScript("OnClick", function()
    for _, n in ipairs(ns.RaidAttendees()) do selected[ns.Key(n)] = true end
    ns.RefreshPanel()
  end)
  local clearBtn = UI.Button(awardCard, "Clear selection", 110)
  clearBtn:SetPoint("LEFT", raidBtn, "RIGHT", 6, 0)
  clearBtn:SetScript("OnClick", function() wipe(selected); ns.RefreshPanel() end)

  FieldLabel(awardCard, "Amount", 14, -68)
  P.amount = UI.EditBox(awardCard, 64, 5)
  P.amount:SetHeight(24)
  P.amount:SetPoint("TOPLEFT", 14, -80)
  P.amount:SetNumeric(true)
  FieldLabel(awardCard, "Reason", 88, -68)
  P.reason = UI.EditBox(awardCard, inner - 74, 60)
  P.reason:SetHeight(24)
  P.reason:SetPoint("TOPLEFT", 88, -80)

  local add = UI.Button(awardCard, "Add DKP", (inner - 6) / 2, "primary")
  add:SetHeight(24)
  add:SetPoint("TOPLEFT", 14, -112)
  add:SetScript("OnClick", function() award(1) end)
  UI.Tooltip(add, "Add DKP", "Gives the amount to everyone ticked, with the reason typed. Every guildmate's addon records it, and it can be undone from All changes.")
  local remove = UI.Button(awardCard, "Remove DKP", (inner - 6) / 2)
  remove:SetHeight(24)
  remove:SetPoint("LEFT", add, "RIGHT", 6, 0)
  remove:SetScript("OnClick", function() award(-1) end)
  UI.Tooltip(remove, "Remove DKP", "Takes the amount off everyone ticked, with the reason typed. It can be undone from All changes.")

  -- Loot auction
  local auction = Card(o, -154, 124, "Loot auction")
  P.item = UI.EditBox(auction, inner, 255)
  P.item:SetHeight(26)
  P.item:SetPoint("TOPLEFT", 14, -34)
  P.item.hint = UI.Label(P.item, "Shift-click an item to put it here", "MutedSmall")
  P.item.hint:SetPoint("LEFT", 8, 0)
  P.item:HookScript("OnTextChanged", function(self) self.hint:SetShown((self:GetText() or "") == "") end)
  P.item:SetScript("OnEnter", function(self)
    local link = self:GetText()
    if link and link:find("|H") then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      pcall(GameTooltip.SetHyperlink, GameTooltip, link:match("|H(.-)|h"))
      GameTooltip:Show()
    end
  end)
  P.item:SetScript("OnLeave", function() GameTooltip:Hide() end)

  FieldLabel(auction, "Min bid", 14, -70)
  P.minBid = UI.EditBox(auction, 60, 5)
  P.minBid:SetHeight(24)
  P.minBid:SetPoint("TOPLEFT", 14, -82)
  P.minBid:SetNumeric(true)
  P.minBid:SetText("10")
  P.duration = UI.Cycle(auction, 96, { { 30, "30 seconds" }, { 45, "45 seconds" }, { 60, "60 seconds" },
    { 20, "20 seconds" } })
  P.duration:SetHeight(24)
  P.duration:SetPoint("TOPLEFT", 80, -82)
  UI.Tooltip(P.duration, "Bidding time", "How long bidding stays open. Click to change.")

  local startW = inner - 60 - 96 - 12
  P.auctionStart = UI.Button(auction, "Start", startW, "primary")
  P.auctionStart:SetHeight(24)
  P.auctionStart:SetPoint("TOPLEFT", 182, -82)
  P.auctionStart:SetScript("OnClick", function()
    if ns.StartAuction(P.item:GetText(), P.minBid:GetText(), P.duration.value) then
      P.item:SetText("")
      P.item:ClearFocus()
    end
    ns.RefreshPanel()
  end)
  UI.Tooltip(P.auctionStart, "Start auction", "Opens bidding on the item for everyone in your raid with the addon, for the time chosen. The highest bid wins and the DKP comes off automatically. If nobody bids, raiders can /roll for it free.")
  -- While an auction runs, the same spot cancels it.
  P.auctionCancel = UI.Button(auction, "Cancel", startW)
  P.auctionCancel:SetHeight(24)
  P.auctionCancel:SetPoint("TOPLEFT", 182, -82)
  P.auctionCancel:SetScript("OnClick", function() ns.CancelAuction(); ns.RefreshPanel() end)
  UI.Tooltip(P.auctionCancel, "Cancel auction", "Stops the auction running now. Nobody pays anything.")

  -- Rules, for the whole guild
  local rules = Card(o, -290, 160, "Rules")
  rules:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", 1, 1)
  P.rulesText = UI.Label(rules, "", "MutedSmall")
  P.rulesText:SetPoint("TOPLEFT", 14, -32)
  P.rulesText:SetWidth(inner)
  P.rulesText:SetWordWrap(false)

  local function saveRules()
    ns.SetDKPRules(P.decay:GetText(), P.weekly:GetChecked(), P.hidden:GetChecked())
  end
  FieldLabel(rules, "Decay %", 14, -52)
  P.decay = UI.EditBox(rules, 40, 2)
  P.decay:SetHeight(24)
  P.decay:SetPoint("TOPLEFT", 14, -64)
  P.decay:SetNumeric(true)
  P.decay:SetScript("OnEnterPressed", function(self) self:ClearFocus(); saveRules() end)
  local apply = UI.Button(rules, "Decay now", 84)
  apply:SetHeight(24)
  apply:SetPoint("TOPLEFT", 60, -64)
  apply:SetScript("OnClick", function() StaticPopup_Show("IMPERIUM_DECAY", P.decay:GetText()) end)
  UI.Tooltip(apply, "Decay now", "Takes the percentage off everyone's DKP right away. It can only be done once per week.")
  P.weekly = UI.Check(rules, "Every week", 150, -62)
  P.weekly:SetScript("OnClick", saveRules)
  UI.Tooltip(P.weekly, "Weekly decay", "An online officer's addon takes this percentage off everyone's DKP once each week, after the Tuesday reset.")
  P.hidden = UI.Check(rules, "Hidden bids", 10, -90)
  P.hidden:SetScript("OnClick", saveRules)
  UI.Tooltip(P.hidden, "Hidden bids", "Nobody sees anyone else's bid. The highest bid wins, but only pays one more than the second-highest bid, so people can bid what an item is really worth to them.")

  local third = (inner - 12) / 3
  P.export = UI.Button(rules, "Export", third)
  P.export:SetPoint("BOTTOMLEFT", 14, 14)
  P.export:SetScript("OnClick", function() ns.ShowExport(ns.ExportDKP()) end)
  UI.Tooltip(P.export, "Export DKP", "Shows everyone's DKP as text you can copy, for example into a spreadsheet.")
  P.import = UI.Button(rules, "Import", third)
  P.import:SetPoint("LEFT", P.export, "RIGHT", 6, 0)
  P.import:SetScript("OnClick", function() ns.ShowImportWindow() end)
  UI.Tooltip(P.import, "Import balances", "Sets members' DKP from a list you paste in, such as one copied from a spreadsheet.")
  P.newSeason = UI.Button(rules, "New season", third)
  P.newSeason:SetPoint("LEFT", P.import, "RIGHT", 6, 0)
  P.newSeason:SetScript("OnClick", function() StaticPopup_Show("IMPERIUM_NEW_SEASON") end)
  UI.Tooltip(P.newSeason, "Start a new DKP season", "Everyone keeps their DKP. Older history is archived to keep the addon fast: DKP changes and loot from before today, and raids and attendance older than 30 days. Export first if you want a copy.")
end

local function BuildMember(parent)
  local m = CreateFrame("Frame", nil, parent)
  m:SetAllPoints()
  P.member = m
  local mine = Card(m, 0, 86)
  UI.Label(mine, "YOUR DKP", "Label"):SetPoint("TOPLEFT", 14, -13)
  P.mine = UI.Label(mine, "", "Display")
  P.mine:SetPoint("TOPLEFT", 14, -30)
  P.mine:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  P.season = UI.Label(mine, "", "MutedSmall")
  P.season:SetPoint("TOPLEFT", 14, -62)

  local recent = Card(m, -98, 352, "Recent changes")
  recent:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", 1, 1)
  P.myHistory = UI.Label(recent, "", "Small")
  P.myHistory:SetPoint("TOPLEFT", 14, -36)
  P.myHistory:SetWidth(SIDE_W - 30)
  P.myHistory:SetSpacing(5)
end

-- A table card with a heading row and a scrolling list inside.
local function TableCard(page)
  local card = CreateFrame("Frame", nil, page)
  card:SetPoint("TOPLEFT", 1, -37)
  card:SetSize(LEFT_W - 2, 412)
  UI.Card(card, 1)
  local rule = card:CreateTexture(nil, "BORDER")
  rule:SetPoint("TOPLEFT", 0, -26)
  rule:SetPoint("TOPRIGHT", 0, -26)
  rule:SetHeight(1)
  rule:SetColorTexture(C.cardEdge[1], C.cardEdge[2], C.cardEdge[3], 1)
  return card
end

local function Heads(card)
  local h = CreateFrame("Frame", nil, card)
  h:SetPoint("TOPLEFT")
  h:SetPoint("TOPRIGHT")
  h:SetHeight(26)
  return h
end

local function RowLine(row)
  local line = row:CreateTexture(nil, "BORDER")
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")
  line:SetHeight(1)
  line:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
end

local function Build(page)
  -- Header: which view, and alts.
  local bar = page.headerBar
  P.alts = UI.Button(bar, "Alts", 70)
  P.alts:SetHeight(26)
  P.alts:SetPoint("RIGHT")
  P.alts:SetScript("OnClick", function() ns.ShowAltsWindow() end)
  UI.Tooltip(P.alts, "Alts", "Link your alts to your main so they share its DKP. A number in red means alts are waiting for you to confirm them.")
  P.view = UI.Segmented(bar, { { "standings", "Standings" }, { "loot", "Loot history" }, { "changes", "All changes" } },
    function(v) view = v; ns.RefreshPanel() end)
  P.view:SetPoint("RIGHT", P.alts, "LEFT", -8, 0)

  -- Search and the raid filter.
  local search = UI.EditBox(page, 280, 40)
  search:SetHeight(26)
  search:SetPoint("TOPLEFT", 1, -1)
  search:SetTextInsets(28, 8, 0, 0)
  local glass = UI.Icon(search, "search", 13, C.faint)
  glass:SetPoint("LEFT", 9, 0)
  search.hint = UI.Label(search, "", "MutedSmall")
  search.hint:SetPoint("LEFT", 28, 0)
  search:SetScript("OnTextChanged", function(self)
    filterText = self:GetText() or ""
    self.hint:SetShown(filterText == "")
    ns.RefreshPanel()
  end)
  P.search = search
  local raid = UI.Check(page, "Raid only", 290, 0)
  raid:SetScript("OnClick", function(self) raidOnly = self:GetChecked() and true or false; ns.RefreshPanel() end)
  UI.Tooltip(raid, "Raid only", "Show only the people in your raid group right now.")
  P.raidOnly = raid

  local card = TableCard(page)
  P.card = card
  local listW, listH = LEFT_W - 24, 384

  -- Standings
  P.standingsHeads = Heads(card)
  Head(P.standingsHeads, "MEMBER", 32)
  Head(P.standingsHeads, "ATTENDANCE", -80 - SCROLL_ROOM, true)
  Head(P.standingsHeads, "DKP", -10 - SCROLL_ROOM, true)
  P.list = UI.List(card, listW, listH, ROW_H,
    function(row)
      row.check = UI.CheckBox(row, 14)
      row.check:SetPoint("LEFT", 9, 0)
      row.check:SetScript("OnClick", function(self)
        selected[row.item.key] = self:GetChecked() and true or nil
        ns.RefreshPanel()
      end)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("LEFT", 32, 0)
      row.name:SetPoint("RIGHT", -160, 0)
      row.name:SetWordWrap(false)
      row.att = UI.Label(row, "", "Small")
      row.att:SetPoint("RIGHT", -80, 0)
      row.att:SetJustifyH("RIGHT")
      row.dkp = UI.Label(row, "", "Number")
      row.dkp:SetPoint("RIGHT", -10, 0)
      row.dkp:SetJustifyH("RIGHT")
      RowLine(row)
      row:SetScript("OnClick", function(self) ns.ShowPlayerCard(self.item.name) end)
      row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.item.name .. ": " .. self.item.dkp .. " DKP")
        if self.item.alts and #self.item.alts > 0 then
          GameTooltip:AddLine("Alts: " .. table.concat(self.item.alts, ", "), 0.7, 0.7, 1, true)
        end
        local attended, total, noShows = ns.Attendance(self.item.name)
        if total > 0 then
          GameTooltip:AddLine(("Attendance: %d of %d raids in the last 30 days (%d%%)"):format(attended, total,
            math.floor(attended / total * 100 + 0.5)), 0.4, 0.8, 1)
        end
        if #noShows > 0 then
          GameTooltip:AddLine(("No-shows: %d (%s)"):format(#noShows, table.concat(noShows, ", ")), 1, 0.4, 0.4, true)
        end
        GameTooltip:AddLine("Click for their player card.", 0.6, 0.6, 0.6)
        GameTooltip:AddLine(" ")
        for i, e in ipairs(ns.DKPHistory(self.item.name)) do
          if i > 10 then break end
          GameTooltip:AddDoubleLine(ns.Date("%b %d", e.t) .. "  " .. e.reason, (e.amount >= 0 and "+" or "") .. e.amount,
            0.8, 0.8, 0.8, e.amount >= 0 and 0.25 or 1, e.amount >= 0 and 1 or 0.4, 0.25)
        end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    function(row, m)
      local officer = ns.IsAddonOfficer()
      row.check:SetShown(officer)
      row.check:SetChecked(selected[m.key] or false)
      row.name:ClearAllPoints()
      row.name:SetPoint("LEFT", officer and 32 or 12, 0)
      row.name:SetPoint("RIGHT", -160, 0)
      row.name:SetText(m.name .. (m.left and (" " .. UI.Code("muted") .. "(left guild)|r") or "")
        .. ((m.alts and #m.alts > 0) and (" " .. UI.Code("muted") .. "+" .. #m.alts .. " alt" .. (#m.alts > 1 and "s" or "") .. "|r") or ""))
      local r, g, b = UI.ClassColor(m.classFile)
      row.name:SetTextColor(r, g, b)
      row.name:SetAlpha(m.online == false and 0.6 or 1)
      row.dkp:SetText(m.dkp or 0)
      local attended, total, noShows = ns.Attendance(m.name)
      if total > 0 then
        local pct = math.floor(attended / total * 100 + 0.5)
        local color = pct >= 75 and UI.Code("good") or (pct >= 40 and UI.Code("accent") or UI.Code("bad"))
        row.att:SetText(("%s%d / %d|r"):format(color, attended, total) .. (#noShows > 0 and (" " .. UI.Code("bad") .. "!|r") or ""))
      else
        row.att:SetText(UI.Code("faint") .. "-|r")
      end
    end, true)
  P.list.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -27)

  -- Loot history
  P.lootHeads = Heads(card)
  Head(P.lootHeads, "DATE", 12)
  Head(P.lootHeads, "ITEM", 64)
  Head(P.lootHeads, "WINNER", -60 - SCROLL_ROOM, true)
  Head(P.lootHeads, "DKP", -10 - SCROLL_ROOM, true)
  P.lootList = UI.List(card, listW, listH, ROW_H,
    function(row)
      row.date = UI.Label(row, "", "MutedSmall")
      row.date:SetPoint("LEFT", 12, 0)
      row.winner = UI.Label(row, "", "Small")
      row.winner:SetPoint("RIGHT", -60, 0)
      row.winner:SetWidth(92)
      row.winner:SetJustifyH("RIGHT")
      row.winner:SetWordWrap(false)
      row.item = UI.Label(row, "", "Small")
      row.item:SetPoint("LEFT", 64, 0)
      row.item:SetPoint("RIGHT", row.winner, "LEFT", -8, 0)
      row.item:SetWordWrap(false)
      row.dkp = UI.Label(row, "", "Number")
      row.dkp:SetPoint("RIGHT", -10, 0)
      row.dkp:SetJustifyH("RIGHT")
      RowLine(row)
      row:RegisterForClicks("RightButtonUp")
      row:SetScript("OnClick", function(self, button)
        if button == "RightButton" and ns.IsAddonOfficer() then
          local l = self.item
          StaticPopup_Show("IMPERIUM_FIX_LOOT", ("%s won %s for %d DKP."):format(l.winner, l.item, l.amount), nil, l)
        end
      end)
      row:SetScript("OnEnter", function(self)
        local l = self.item
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, l.item:match("|H(.-)|h") or "")
        if not ok then GameTooltip:SetText(l.item) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(("Won by %s for %d DKP"):format(l.winner, l.amount), C.accent[1], C.accent[2], C.accent[3])
        GameTooltip:AddLine(ns.Date("%A %b %d, %H:%M", l.t) .. (l.raid and (" - " .. l.raid) or ""), 0.8, 0.8, 0.8)
        GameTooltip:AddLine((l.roll and "Free roll" or (l.council and "Loot council" or "Auction")) .. " run by " .. l.by, 0.6, 0.6, 0.6)
        if ns.IsAddonOfficer() then
          GameTooltip:AddLine("Right-click to refund it or give it to someone else.", 1, 0.5, 0.5)
        end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    function(row, l)
      row.date:SetText(ns.Date("%b %d", l.t))
      row.item:SetText(l.item)
      row.winner:SetText(l.winner)
      row.dkp:SetText(l.roll and (UI.Code("muted") .. "roll|r") or (l.council and (UI.Code("muted") .. "council|r") or l.amount))
    end, true)
  P.lootList.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -27)

  -- All changes
  P.changeHeads = Heads(card)
  Head(P.changeHeads, "DATE", 12)
  Head(P.changeHeads, "DKP", 62)
  Head(P.changeHeads, "WHO", 110)
  Head(P.changeHeads, "REASON", 226)
  P.changeList = UI.List(card, listW, listH, ROW_H,
    function(row)
      row.date = UI.Label(row, "", "MutedSmall")
      row.date:SetPoint("LEFT", 12, 0)
      row.amount = UI.Label(row, "", "Number")
      row.amount:SetPoint("LEFT", 62, 0)
      row.who = UI.Label(row, "", "Small")
      row.who:SetPoint("LEFT", 110, 0)
      row.who:SetWidth(108)
      row.who:SetWordWrap(false)
      row.reason = UI.Label(row, "", "Small")
      row.reason:SetPoint("LEFT", 226, 0)
      row.reason:SetPoint("RIGHT", -10, 0)
      row.reason:SetWordWrap(false)
      RowLine(row)
      row:RegisterForClicks("RightButtonUp")
      row:SetScript("OnClick", function(self, button)
        local c = self.item
        if button == "RightButton" and ns.IsAddonOfficer() and not c.undone then
          local e = c.entry
          StaticPopup_Show("IMPERIUM_UNDO_DKP", ("%s%d DKP for %s: %s"):format(e.amount >= 0 and "+" or "", e.amount,
            e.names:gsub(",", ", "), e.reason), nil, e)
        end
      end)
      row:SetScript("OnEnter", function(self)
        local c, e = self.item, self.item.entry
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(("%s%d DKP"):format(e.amount >= 0 and "+" or "", e.amount), 1, 1, 1)
        GameTooltip:AddLine(e.reason, C.accent[1], C.accent[2], C.accent[3], true)
        GameTooltip:AddLine(e.names:gsub(",", ", "), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(("%s, by %s"):format(ns.Date("%A %b %d, %H:%M", e.t), e.a), 0.6, 0.6, 0.6)
        if c.undone then
          GameTooltip:AddLine(("Undone by %s%s"):format(c.undone.a, c.undone.reason ~= "" and (": " .. c.undone.reason) or ""), 1, 0.4, 0.4, true)
        elseif ns.IsAddonOfficer() then
          GameTooltip:AddLine("Right-click to undo it.", 1, 0.5, 0.5)
        end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    function(row, c)
      local e = c.entry
      local dim = c.undone and 0.45 or 1
      row.date:SetText(ns.Date("%b %d", e.t))
      row.amount:SetText((e.amount >= 0 and UI.Code("good") .. "+" or UI.Code("bad")) .. e.amount .. "|r")
      row.who:SetText(e.names:gsub(",", ", "))
      row.reason:SetText(c.undone and (UI.Code("muted") .. "(undone) " .. e.reason .. "|r") or e.reason)
      row.amount:SetAlpha(dim); row.who:SetAlpha(dim); row.date:SetAlpha(dim)
    end, true)
  P.changeList.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -27)

  -- The cards on the right.
  local right = CreateFrame("Frame", nil, page)
  right:SetPoint("TOPLEFT", SIDE_X, 0)
  right:SetSize(SIDE_W, 450)
  BuildOfficer(right)
  BuildMember(right)

  -- A bigger window: the table gets the room; the cards move right and the last ones grow taller.
  UI.Grow(page, card, 1, 1)
  for _, list in ipairs({ P.list, P.lootList, P.changeList }) do UI.Grow(page, list, 1, 1) end
  UI.Follow(page, right, 1, 0)
  UI.Grow(page, right, 0, 1)

  -- Shift-clicking an item puts its link in the auction box while it has focus.
  local function insert(link)
    if P.item and P.item:HasFocus() and link then P.item:SetText(link) end
  end
  hooksecurefunc(ChatFrameUtil, "InsertLink", insert)
end

------------------------------------------------------------------------
-- Export window: the text is selected, ready to copy with Ctrl+C.
------------------------------------------------------------------------
local exportWin

function ns.ShowExport(text)
  if not exportWin then
    local f = UI.Window("WarcrestExport", 560, 420, "DKP export")
    exportWin = f
    local hint = UI.Label(f, "Press Ctrl+C to copy, then paste it into a text file or spreadsheet.", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, -32)
    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    UI.SkinScrollBar(sf)
    UI.Card(sf, 4)
    sf:SetPoint("TOPLEFT", 16, -52)
    sf:SetPoint("BOTTOMRIGHT", -34, 16)
    local box = CreateFrame("EditBox", nil, sf)
    box:SetMultiLine(true)
    box:SetFontObject(UI.Fonts.Body)
    box:SetWidth(500)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    -- Keep the text as exported, even if someone types in the box.
    box:SetScript("OnTextChanged", function(self, userInput)
      if userInput then self:SetText(f.text or ""); self:HighlightText() end
    end)
    sf:SetScrollChild(box)
    f.box = box
  end
  exportWin.text = text
  exportWin.box:SetText(text)
  exportWin:Show()
  exportWin.box:SetFocus()
  exportWin.box:HighlightText()
end

-- The header's subtitle: your own DKP, and whether a raid night is earning more.
local function Subtitle()
  local text = ns.TF("Your DKP: %d", ns.Balance(UnitName("player")))
  local s = ns.ActiveSession()
  if s then text = text .. " · " .. ns.TF("%s raid night in progress", s.title) end
  return text
end

local TAB = { id = "dkp", title = "DKP", build = function(page) Build(page); P.tab.view = P.view end,
  refresh = Refresh, subtitle = Subtitle, visible = function() return ns.UsesDKP() end }
P.tab = TAB
UI.AddTab(TAB)
