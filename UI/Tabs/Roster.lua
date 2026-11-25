--[[
  Warcrest
  Roster tab: member list, notes, rank changes, invites, MOTD, addon versions.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate
local UI = ns.UI

local P = {}          -- widgets on this page
local selected
local filterText = ""

-- The game's own guild commands (localized names when available).
local CMD = {
  promote = _G.SLASH_GUILD_PROMOTE1 or "/gpromote",
  demote  = _G.SLASH_GUILD_DEMOTE1 or "/gdemote",
  remove  = _G.SLASH_GUILD_UNINVITE1 or "/gremove",
  invite  = _G.SLASH_GUILD_INVITE1 or "/ginvite",
  motd    = _G.SLASH_GUILD_MOTD1 or "/gmotd",
}

-- Name as the slash commands expect it: no realm for your own realm.
local function cmdName(m) return Ambiguate(m.name, "none") end

local function hideRemoveConfirm()
  if P.detail and P.detail.confirm and not InCombatLockdown() then
    P.detail.confirm:Hide()
    P.detail.cancel:Hide()
  end
end

local function addonVersionText(m)
  local v = ns.versions[m.full]
  if not v then
    return m.online and (UI.Code("muted") .. "Addon not detected|r") or ""
  end
  if ns.CompareVersions(v, ns.NewestVersion()) < 0 then
    return UI.Code("bad") .. "Addon v" .. v .. " (out of date)|r"
  end
  return UI.Code("good") .. "Addon v" .. v .. "|r"
end

local function UpdateDetail()
  local d = P.detail
  local p = ns.Perms()
  local m = selected

  for _, w in ipairs({ d.pub, d.off, d.save, d.promote, d.demote, d.remove }) do
    UI.SetEnabled(w, false)
  end
  UI.SetEnabled(d.card, m ~= nil)

  if not m then
    hideRemoveConfirm()
    d.name:SetText(IsInGuild() and "Select a member" or "You're not in a guild")
    d.name:SetTextColor(UI.C.accent[1], UI.C.accent[2], UI.C.accent[3])
    d.info:SetText("")
    d.zone:SetText("")
    d.addon:SetText("")
    d.pub:SetText("")
    d.off:SetText("")
    d.offHidden:Hide()
    return
  end

  local myRank = ns.MyRank() or 99
  local isMe = ns.IsMe(m.name)

  UI.SetCommand(d.promote, CMD.promote .. " " .. cmdName(m))
  UI.SetCommand(d.demote, CMD.demote .. " " .. cmdName(m))
  UI.SetCommand(d.confirm, CMD.remove .. " " .. cmdName(m))

  local title = ns.TitleOf and ns.TitleOf(m.name)
  d.name:SetText(Ambiguate(m.name, "guild") .. (title and (" " .. UI.Code("accent") .. title .. "|r") or ""))
  d.name:SetTextColor(UI.ClassColor(m.classFile))
  d.info:SetText(("Level %d %s  ·  %s"):format(m.level, m.className, m.rankName))
  if m.online then
    d.zone:SetText("Online in " .. (m.zone ~= "" and m.zone or "unknown zone"))
  else
    d.zone:SetText(m.mobile and "On mobile" or "Offline")
  end
  d.addon:SetText(addonVersionText(m))

  if not d.pub:HasFocus() then d.pub:SetText(m.publicNote) end
  if not d.off:HasFocus() then d.off:SetText(p.viewOfficerNote and m.officerNote or "") end
  d.offHidden:SetShown(not p.viewOfficerNote)

  UI.SetEnabled(d.pub, p.publicNote)
  UI.SetEnabled(d.off, p.officerNote)
  UI.SetEnabled(d.save, p.publicNote or p.officerNote)
  -- You can only act on ranks below your own; the server enforces this too.
  UI.SetEnabled(d.promote, p.promote and not isMe and m.rankIndex > myRank + 1)
  UI.SetEnabled(d.demote, p.demote and not isMe and m.rankIndex > myRank and m.rankIndex < UI.NumRanks() - 1)
  UI.SetEnabled(d.remove, p.remove and not isMe and m.rankIndex > myRank)
end

------------------------------------------------------------------------
-- Organizing the list: sort by any column (click its heading; again to
-- reverse) and show only some members. Remembered per character.
------------------------------------------------------------------------
local MAX_LEVEL = 60
ns.ROSTER_SORTS = { "rank", "name", "level", "where" }
ns.ROSTER_SHOWS = { "all", "warcrest", "nowarcrest", "max", "officers" }

local function view()
  local v = ns.db.rosterView
  if type(v) ~= "table" then v = {}; ns.db.rosterView = v end
  local ok = false
  for _, k in ipairs(ns.ROSTER_SORTS) do if v.sort == k then ok = true end end
  if not ok then v.sort, v.desc = "rank", false end
  ok = false
  for _, k in ipairs(ns.ROSTER_SHOWS) do if v.show == k then ok = true end end
  if not ok then v.show = "all" end
  v.desc = v.desc == true
  return v
end

-- Click a heading: sort by it, or turn the order around if it already is.
function ns.SortRoster(key)
  local v = view()
  if v.sort == key then v.desc = not v.desc else v.sort, v.desc = key, key == "level" end
  ns.RefreshPanel()
end

function ns.ShowRoster(which)
  view().show = which
  ns.RefreshPanel()
end

local function wanted(m, show)
  if show == "warcrest" then return ns.versions[m.full] ~= nil end
  if show == "nowarcrest" then return ns.versions[m.full] == nil end
  if show == "max" then return (m.level or 0) >= MAX_LEVEL end
  if show == "officers" then return ns.IsOfficerRank(m.rankIndex) end
  return true
end

local function matches(m, q)
  if q == "" then return true end
  for _, s in ipairs({ m.name, m.rankName, m.className, m.zone, m.publicNote }) do
    if s and s:lower():find(q, 1, true) then return true end
  end
end

-- Where: online first (by zone), then offline, the most recently seen first.
local function whereOrder(a, b)
  if a.online ~= b.online then return a.online and true or false end
  if a.online then
    if a.zone ~= b.zone then return a.zone < b.zone end
    return nil
  end
  if (a.offlineDays or 0) ~= (b.offlineDays or 0) then return (a.offlineDays or 0) < (b.offlineDays or 0) end
end

local ORDER = {
  rank = function(a, b) if a.rankIndex ~= b.rankIndex then return a.rankIndex < b.rankIndex end end,
  name = function(a, b) if a.name ~= b.name then return a.name < b.name end end,
  level = function(a, b) if a.level ~= b.level then return a.level < b.level end end,
  where = whereOrder,
}

-- The members to list, in order: the roster filtered by the search box, the
-- "Show" choice and Show offline, sorted by the chosen column.
function ns.RosterRows(roster, q, showOffline)
  local v = view()
  local shown = {}
  for _, m in ipairs(roster) do
    if (showOffline or m.online) and wanted(m, v.show) and matches(m, q) then shown[#shown + 1] = m end
  end
  local by, desc = ORDER[v.sort], v.desc
  table.sort(shown, function(a, b)
    local r = by(a, b)
    if r == nil then r = by(b, a); if r ~= nil then r = not r end end
    if r ~= nil then
      if desc then return not r end
      return r
    end
    if a.rankIndex ~= b.rankIndex then return a.rankIndex < b.rankIndex end
    return a.name < b.name
  end)
  return shown
end

local function Refresh()
  local roster = ns.GetRoster()
  local showOffline = P.offline:GetChecked()
  local q = filterText:lower()
  local v = view()
  local shown = ns.RosterRows(roster, q, showOffline)
  for key, h in pairs(P.heads) do
    local on = v.sort == key
    local c = on and UI.C.accent or UI.C.faint
    h.label:SetTextColor(c[1], c[2], c[3])
    h.arrow:SetShown(on)
    if h.arrow.SetRotation then h.arrow:SetRotation(v.desc and 0 or math.pi) end
  end
  P.show.index = 1
  for i, o in ipairs(P.show.options) do if o[1] == v.show then P.show.index = i; P.show:SetText(o[2]) end end
  P.show.value = v.show

  if selected then
    local fresh
    for _, m in ipairs(roster) do
      if m.full == selected.full then fresh = m break end
    end
    selected = fresh
  end

  P.list:SetEmptyText((q ~= "" or v.show ~= "all") and "Nobody matches your search." or "The guild roster is still loading.")
  P.list:SetItems(shown)

  local online, with, outdated = ns.VersionSummary(roster)
  local summary = ("%d shown  ·  %d of %d online have the addon"):format(#shown, with, online)
  if outdated > 0 then summary = summary .. ("  ·  %s%d out of date|r"):format(UI.Code("bad"), outdated) end
  P.count:SetText(summary)

  UpdateDetail()

  local p = ns.Perms()
  UI.SetEnabled(P.inviteBox, p.invite)
  UI.SetEnabled(P.inviteBtn, p.invite)
  UI.SetEnabled(P.motdBox, p.motd)
  UI.SetEnabled(P.motdBtn, p.motd)
  if not P.motdBox:HasFocus() then
    P.motdBox:SetText(C_GuildInfo.GetMOTD() or "")
  end
end

local C = UI.C
local LEFT_W = 440               -- the member table; the cards on the right fill the rest
local SIDE_X = LEFT_W + 14
local SIDE_W = 740 - SIDE_X
local INNER = SIDE_W - 30        -- width inside a card's padding

local function FieldLabel(parent, text, x, y)
  local fs = UI.Label(parent, text:upper(), "Label")
  fs:SetPoint("TOPLEFT", x, y)
  return fs
end

local function Card(parent, x, y, w, h)
  local f = CreateFrame("Frame", nil, parent)
  f:SetPoint("TOPLEFT", x + 1, y - 1)
  f:SetSize(w - 2, h)
  UI.Card(f, 1)
  return f
end

local function BuildTable(page)
  local search = UI.EditBox(page, 150, 40)
  search:SetHeight(26)
  search:SetPoint("TOPLEFT", 1, -1)
  search:SetTextInsets(28, 8, 0, 0)
  local glass = UI.Icon(search, "search", 13, C.faint)
  glass:SetPoint("LEFT", 9, 0)
  search.hint = UI.Label(search, "Search", "MutedSmall")
  search.hint:SetPoint("LEFT", 28, 0)
  search:SetScript("OnTextChanged", function(self)
    filterText = self:GetText() or ""
    self.hint:SetShown(filterText == "")
    ns.RefreshPanel()
  end)
  UI.Tooltip(search, "Search", "Finds members by name, rank, class, zone or public note.")
  P.offline = UI.Check(page, "Show offline", 158, 0)
  P.offline:SetScript("OnClick", ns.RefreshPanel)
  P.show = UI.Cycle(page, 150, { { "all", "Everyone" }, { "warcrest", "With Warcrest" }, { "nowarcrest", "Without Warcrest" },
    { "max", "Level 60" }, { "officers", "Officers" } }, ns.ShowRoster)
  P.show:SetHeight(26)
  P.show:SetPoint("TOPLEFT", LEFT_W - 150, -1)
  UI.Tooltip(P.show, "Show", "Show everyone, or only members with or without Warcrest, at level 60, or officers. "
    .. "Click a column's heading to sort by it; click it again to turn the order around.")

  local card = Card(page, 0, -36, LEFT_W, 390)
  P.card = card
  local heads = { { "name", "NAME", 12 }, { "level", "LVL", 166 }, { "rank", "RANK", 202 }, { "where", "WHERE", 318 } }
  P.heads = {}
  for _, h in ipairs(heads) do
    local b = CreateFrame("Button", nil, card)
    b:SetPoint("TOPLEFT", h[3] - 4, -3)
    b:SetSize(h[1] == "level" and 34 or 70, 20)
    b.label = UI.Label(b, h[2], "Label")
    b.label:SetPoint("LEFT", 4, 0)
    b.arrow = UI.Icon(b, "chevron", 8, C.accent)
    b.arrow:SetPoint("LEFT", b.label, "RIGHT", 3, 0)
    b:SetScript("OnClick", function() ns.SortRoster(h[1]) end)
    UI.Tooltip(b, h[2], "Sort by this column. Click again to turn the order around.")
    P.heads[h[1]] = b
  end
  local rule = card:CreateTexture(nil, "BORDER")
  rule:SetPoint("TOPLEFT", 0, -26)
  rule:SetPoint("TOPRIGHT", 0, -26)
  rule:SetHeight(1)
  rule:SetColorTexture(C.cardEdge[1], C.cardEdge[2], C.cardEdge[3], 1)

  P.list = UI.List(card, LEFT_W - 24, 390 - 28, 24,
    function(row)
      row.sel = row:CreateTexture(nil, "BACKGROUND")
      row.sel:SetAllPoints()
      row.sel:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.10)
      row.bar = row:CreateTexture(nil, "BORDER")
      row.bar:SetPoint("TOPLEFT")
      row.bar:SetPoint("BOTTOMLEFT")
      row.bar:SetWidth(2)
      row.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("LEFT", 12, 0)
      row.name:SetWidth(148)
      row.name:SetWordWrap(false)
      row.level = UI.Label(row, "", "Small")
      row.level:SetPoint("LEFT", 166, 0)
      row.rank = UI.Label(row, "", "Small")
      row.rank:SetPoint("LEFT", 202, 0)
      row.rank:SetWidth(108)
      row.rank:SetWordWrap(false)
      row.where = UI.Label(row, "", "MutedSmall")
      row.where:SetPoint("LEFT", 318, 0)
      row.where:SetPoint("RIGHT", -8, 0)
      row.where:SetWordWrap(false)
      local line = row:CreateTexture(nil, "BORDER")
      line:SetPoint("BOTTOMLEFT")
      line:SetPoint("BOTTOMRIGHT")
      line:SetHeight(1)
      line:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
      row:SetScript("OnClick", function(self)
        selected = self.item
        hideRemoveConfirm()
        ns.RefreshPanel()
      end)
      row:SetScript("OnDoubleClick", function(self) ns.ShowPlayerCard(self.item.name) end)
    end,
    function(row, m)
      local r, g, b = UI.ClassColor(m.classFile)
      local dim = m.online and 1 or 0.5
      row.name:SetText(Ambiguate(m.name, "guild"))
      row.name:SetTextColor(r, g, b)
      row.name:SetAlpha(dim)
      row.level:SetText(m.level)
      row.level:SetAlpha(dim)
      row.rank:SetText(m.rankName)
      row.rank:SetAlpha(dim)
      if m.online then
        row.where:SetText(m.zone ~= "" and m.zone or "Online")
      else
        row.where:SetText(m.mobile and "On mobile" or (UI.Code("faint") .. "Offline|r"))
      end
      local on = selected ~= nil and selected.full == m.full
      row.sel:SetShown(on)
      row.bar:SetShown(on)
    end, true)
  P.list.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -27)

  P.count = UI.Label(page, "", "MutedSmall")
  P.count:SetPoint("TOPLEFT", 4, -436)
end

local function BuildMember(side)
  local d = Card(side, 0, 0, SIDE_W, 300)
  P.detail = d

  d.name = UI.Label(d, "", "Title")
  d.name:SetPoint("TOPLEFT", 14, -14)
  d.name:SetWidth(INNER)
  d.name:SetWordWrap(false)
  d.info = UI.Label(d, "", "Small")
  d.info:SetPoint("TOPLEFT", 14, -38)
  d.zone = UI.Label(d, "", "MutedSmall")
  d.zone:SetPoint("TOPLEFT", 14, -54)
  d.addon = UI.Label(d, "", "Small")
  d.addon:SetPoint("TOPLEFT", 14, -68)

  FieldLabel(d, "Public note", 14, -92)
  d.pub = UI.EditBox(d, INNER, 31)
  d.pub:SetHeight(24)
  d.pub:SetPoint("TOPLEFT", 14, -104)
  FieldLabel(d, "Officer note", 14, -136)
  d.off = UI.EditBox(d, INNER, 31)
  d.off:SetHeight(24)
  d.off:SetPoint("TOPLEFT", 14, -148)
  d.offHidden = UI.Label(d, "Your rank can't see officer notes", "MutedSmall")
  d.offHidden:SetPoint("LEFT", d.off, "LEFT", 8, 0)

  d.save = UI.Button(d, "Save notes", 100)
  d.save:SetHeight(24)
  d.save:SetPoint("TOPLEFT", 14, -182)
  UI.Tooltip(d.save, "Save notes", "Saves the public and officer notes typed above. Each one needs your rank to have permission to edit it.")
  d.save:SetScript("OnClick", function()
    local m = selected
    if not m then return end
    local p = ns.Perms()
    d.pub:ClearFocus()
    d.off:ClearFocus()
    if p.publicNote and d.pub:GetText() ~= m.publicNote then ns.SetNote(m, d.pub:GetText(), true) end
    if p.officerNote and d.off:GetText() ~= m.officerNote then ns.SetNote(m, d.off:GetText(), false) end
  end)

  local function afterAction() C_Timer.After(1, ns.RequestRoster) end
  local third = (INNER - 12) / 3

  d.promote = UI.SecureButton(d, "Promote", third)
  d.promote:SetHeight(26)
  d.promote:SetPoint("TOPLEFT", 14, -222)
  d.promote:HookScript("PostClick", afterAction)
  UI.Tooltip(d.promote, "Promote", "Moves this member up one guild rank. Your rank needs permission to promote, and it can't be done in combat.")

  d.demote = UI.SecureButton(d, "Demote", third)
  d.demote:SetHeight(26)
  d.demote:SetPoint("LEFT", d.promote, "RIGHT", 6, 0)
  d.demote:HookScript("PostClick", afterAction)
  UI.Tooltip(d.demote, "Demote", "Moves this member down one guild rank. Your rank needs permission to demote, and it can't be done in combat.")

  -- Remove asks for confirmation: the first click shows a confirm button.
  d.remove = UI.Button(d, "Remove", third)
  d.remove:SetHeight(26)
  d.remove:SetPoint("LEFT", d.demote, "RIGHT", 6, 0)
  UI.Tooltip(d.remove, "Remove from guild", "Removes this member from the guild. You'll be asked to confirm first.")
  d.remove:SetScript("OnClick", function()
    if selected and not InCombatLockdown() then
      d.confirm:SetText("Remove " .. Ambiguate(selected.name, "guild") .. "?")
      d.confirm:Show()
      d.cancel:Show()
    end
  end)

  d.confirm = UI.SecureButton(d, "Confirm", INNER - 86, "primary")
  d.confirm:SetHeight(26)
  d.confirm:SetPoint("TOPLEFT", 14, -256)
  d.confirm:Hide()
  d.confirm:HookScript("PostClick", function()
    hideRemoveConfirm()
    afterAction()
  end)
  d.cancel = UI.Button(d, "Cancel", 80)
  d.cancel:SetHeight(26)
  d.cancel:SetPoint("LEFT", d.confirm, "RIGHT", 6, 0)
  d.cancel:Hide()
  d.cancel:SetScript("OnClick", hideRemoveConfirm)

  d.card = UI.Button(d, "View player card", INNER)
  d.card:SetHeight(24)
  d.card:SetPoint("BOTTOMLEFT", 14, 12)
  d.card:SetScript("OnClick", function() if selected then ns.ShowPlayerCard(selected.name) end end)
  UI.Tooltip(d.card, "Player card", "Their kills, deaths, nemesis, best streak, DKP, attendance and loot in one place. Double-click a name in the list to open it too.")
end

local function BuildGuild(side)
  local gc = CreateFrame("Frame", nil, side)
  gc:SetPoint("BOTTOMLEFT", 1, 1)
  gc:SetSize(SIDE_W - 2, 136)
  UI.Card(gc, 1)
  UI.Label(gc, "Guild", "Heading"):SetPoint("TOPLEFT", 14, -12)

  -- Invite
  FieldLabel(gc, "Invite player", 14, -36)
  P.inviteBox = UI.EditBox(gc, INNER - 86, 60)
  P.inviteBox:SetHeight(24)
  P.inviteBox:SetPoint("TOPLEFT", 14, -48)
  P.inviteBtn = UI.SecureButton(gc, "Invite", 80)
  P.inviteBtn:SetHeight(24)
  P.inviteBtn:SetPoint("LEFT", P.inviteBox, "RIGHT", 6, 0)
  UI.Tooltip(P.inviteBtn, "Invite to guild", "Invites the player named in the box to the guild.")
  P.inviteBox:SetScript("OnTextChanged", function(self)
    local name = strtrim(self:GetText() or "")
    UI.SetCommand(P.inviteBtn, name ~= "" and (CMD.invite .. " " .. name) or "")
  end)
  P.inviteBtn:HookScript("PostClick", function()
    P.inviteBox:SetText("")
    P.inviteBox:ClearFocus()
  end)

  -- Message of the day
  FieldLabel(gc, "Message of the day", 14, -82)
  P.motdBox = UI.EditBox(gc, INNER - 86, 128)
  P.motdBox:SetHeight(24)
  P.motdBox:SetPoint("TOPLEFT", 14, -94)
  P.motdBtn = UI.SecureButton(gc, "Save", 80)
  P.motdBtn:SetHeight(24)
  P.motdBtn:SetPoint("LEFT", P.motdBox, "RIGHT", 6, 0)
  UI.Tooltip(P.motdBtn, "Save message of the day", "Sets the guild's message of the day to this text, for everyone.")
  P.motdBox:SetScript("OnTextChanged", function(self)
    local text = (self:GetText() or ""):gsub("[\r\n]", " ")
    UI.SetCommand(P.motdBtn, CMD.motd .. " " .. text)
  end)
  P.motdBtn:HookScript("PostClick", function()
    P.motdBox:ClearFocus()
    if ns.LogAction then ns.LogAction("motd") end
    C_Timer.After(1, ns.RequestRoster)
  end)
end

local function Build(page)
  local check = UI.Button(page.headerBar, "Check addon versions", 160)
  check:SetHeight(26)
  check:SetPoint("RIGHT")
  check:SetScript("OnClick", ns.CheckVersions)
  UI.Tooltip(check, "Check addon versions", "Asks every online guildmate which version of Warcrest they have. The list and Guild > Who has Warcrest update as they answer.")

  BuildTable(page)
  local side = CreateFrame("Frame", nil, page)
  side:SetPoint("TOPLEFT", SIDE_X, 0)
  side:SetSize(SIDE_W, 450)
  BuildMember(side)
  BuildGuild(side)

  -- A bigger window: the table gets the room, the cards move right, the Guild card stays at the bottom.
  UI.Grow(page, P.card, 1, 1)
  UI.Grow(page, P.list, 1, 1)
  UI.Follow(page, P.count, 0, 1)
  UI.Follow(page, side, 1, 0)
  UI.Grow(page, side, 0, 1)
end

-- The header's subtitle: guild size and who's online.
local function Subtitle()
  local roster, online = ns.GetRoster(), 0
  for _, m in ipairs(roster) do if m.online then online = online + 1 end end
  if #roster == 0 then return "Members, notes and ranks" end
  return ns.TF("%d members · %d online", #roster, online)
end

UI.AddTab({ id = "roster", title = "Roster", build = Build, refresh = Refresh, subtitle = Subtitle })
