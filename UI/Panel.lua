--[[
  Warcrest
  Panel: the guild tools window and its Options entry.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C
local panel

local WIDTH, HEIGHT = 910, 554           -- the smallest the window can be
local MAX_WIDTH, MAX_HEIGHT = 1600, 1000
local SIDEBAR = 150   -- width of the side menu
local HEADER = 52     -- height of the header above each tab
local SWITCH_H = 34   -- the row of views under it, in sections that have them
local MIN_SCALE, MAX_SCALE = 0.7, 1.5

-- What a tab is about, by its id (the header's second line when the tab has none of its own).
local TAB_INFO = {
  home = "What's happening in the guild",
  roster = "Members, notes and ranks",
  profiles = "Specs, roles, item levels and when people play",
  raids = "Sign-ups, raid nights and invites",
  events = "PvP nights, world bosses, meetings and more",
  calendar = "The month's raids, raid nights and events",
  recruit = "Recruits, trials and the recruiting message",
  dkp = "Standings, loot and auctions",
  wishlist = "The loot the guild wants",
  kills = "PvP kills by guild members",
  achievements = "Achievements and titles",
  wanted = "Enemy players who keep killing guild members",
  settings = "Alerts for the whole guild, and just for you",
  officers = "Guild changes seen while you're online",
  addon = "Who has Warcrest installed",
}

------------------------------------------------------------------------
-- Sections: the side menu. Each shows one tab, or several as views along
-- the top. An item: { tab = id, view = one of that tab's own views (its own
-- switch is then hidden), label = its name in the switch, visible = fn }.
------------------------------------------------------------------------
local function onlineBadge()
  local n = 0
  for _, m in ipairs(ns.GetRoster()) do if m.online then n = n + 1 end end
  if n > 0 then return ns.TF("%d on", n) end
end

local function pollBadge()
  local n = 0
  for _, p in ipairs(ns.Polls and ns.Polls() or {}) do
    if p.open and not ns.MyVote(p) then n = n + 1 end
  end
  if n == 1 then return ns.T("1 poll"), "accent" end
  if n > 1 then return ns.TF("%d polls", n), "accent" end
end

local function raidBadge()
  if ns.ActiveSession and ns.ActiveSession() then return ns.T("live"), "good" end
  local today = date("%Y-%m-%d")
  for _, e in ipairs(ns.RaidEvents and ns.RaidEvents() or {}) do
    if e.start >= time() - 3 * 3600 and date("%Y-%m-%d", e.start) == today then return ns.T("tonight"), "good" end
  end
end

local SECTIONS = {
  { id = "home", title = "Home", icon = "home", items = { { tab = "home" } } },
  { group = "Guild" },
  { id = "guild", title = "Guild", icon = "roster", badge = onlineBadge, items = {
    { tab = "roster", label = "Roster" }, { tab = "profiles", label = "Profiles" },
    { tab = "crafters", label = "Crafters" }, { tab = "addon", label = "Who has Warcrest" } } },
  { id = "events", title = "Events", icon = "events", badge = pollBadge, items = {
    { tab = "events", view = "events", label = "Events" }, { tab = "events", view = "polls", label = "Polls" },
    { tab = "calendar", label = "Calendar" } } },
  { group = "Raids & loot" },
  { id = "raids", title = "Raids", icon = "raids", badge = raidBadge, items = { { tab = "raids" } } },
  { id = "loot", title = "Loot", icon = "dkp", items = {
    { tab = "dkp", view = "standings", label = "Standings" }, { tab = "dkp", view = "loot", label = "Loot history" },
    { tab = "dkp", view = "changes", label = "All changes" }, { tab = "wishlist", label = "Wishlist" } } },
  { group = "PvP & glory" },
  { id = "pvp", title = "PvP", icon = "kills", items = {
    { tab = "kills", label = "Kills" }, { tab = "wanted", view = "wanted", label = "Wanted" },
    { tab = "wanted", view = "guilds", label = "Guild wars" },
    { tab = "wanted", view = "bounties", label = "Bounties", visible = function() return ns.BountiesOn() end } } },
  { id = "achievements", title = "Achievements", icon = "trophy", items = { { tab = "achievements" } } },
  { group = "Officers" },
  { id = "officers", title = "Officers", icon = "officers", items = {
    { tab = "officers", label = "Officer log" }, { tab = "recruit", label = "Recruit" } } },
}
local SETTINGS = { id = "settings", title = "Settings", items = { { tab = "settings" } } }
UI.SECTIONS = SECTIONS

local section, item = SECTIONS[1], 1 -- what's showing

local function tabIndex(id)
  for i, t in ipairs(UI.tabs) do if t.id == id then return i end end
end

local function tabVisible(id)
  local t = UI.tabs[tabIndex(id) or 0]
  return t ~= nil and (not t.visible or t.visible())
end

local function itemVisible(it)
  return tabVisible(it.tab) and (not it.visible or it.visible())
end

local function sectionVisible(s)
  for _, it in ipairs(s.items) do if itemVisible(it) then return true end end
  return false
end

-- The section an item's tab (and view) is in.
local function find(tab, view)
  for _, s in ipairs({ SETTINGS, unpack(SECTIONS) }) do
    for i, it in ipairs(s.items or {}) do
      if it.tab == tab and (not view or not it.view or it.view == view) then return s, i end
    end
  end
end

-- Highlight the current section in the menu.
local function paintNav()
  for _, b in ipairs(panel.navButtons) do
    local active = b.section == section
    b.active:SetShown(active)
    b.bar:SetShown(active)
    b.text:SetFontObject(active and UI.Fonts.NavActive or UI.Fonts.Nav)
    local c = active and C.accent or C.navText
    b.icon:SetVertexColor(c[1], c[2], c[3])
  end
  local on = section == SETTINGS
  local sb = panel.settingsButton
  sb.active:SetShown(on)
  sb.text:SetFontObject(on and UI.Fonts.NavActive or UI.Fonts.Nav)
  local c = on and C.accent or C.navText
  sb.icon:SetVertexColor(c[1], c[2], c[3])
end

local function currentTab()
  local it = section.items[item]
  return UI.tabs[tabIndex(it.tab)], it
end

local function setHeader()
  local t = currentTab()
  panel.heading:SetText(t.heading and t.heading() or ns.T(section.title))
  panel.subheading:SetText((t.subtitle and t.subtitle()) or ns.T(TAB_INFO[t.id] or ""))
end

-- The switch between a section's views, next to its name.
local function layoutSwitch()
  for _, s in ipairs(SECTIONS) do
    if s.switch then
      local shown = 0
      for i, it in ipairs(s.items) do
        local on = itemVisible(it)
        s.switch:SetOptionShown(i, on)
        if on then shown = shown + 1 end
      end
      s.switch:SetShown(s == section and shown > 1)
      if s == section then
        s.switch:SetValue(item)
      end
    end
  end
end

-- Show item i of section s (the first one shown, if that one isn't).
local function ShowSection(s, i)
  if not sectionVisible(s) then s, i = SECTIONS[1], 1 end
  i = i or 1
  if not s.items[i] or not itemVisible(s.items[i]) then
    for n, it in ipairs(s.items) do if itemVisible(it) then i = n break end end
  end
  section, item = s, i
  local t, it = currentTab()
  ns.db.lastTab, ns.db.lastSection, ns.db.lastItem = t.id, s.id, i -- reopen here next time
  for _, x in ipairs(UI.tabs) do x.page:SetShown(x == t) end
  if it.view and t.view then t.view:Pick(it.view) end
  paintNav()
  layoutSwitch()
  ns.RefreshPanel()
end
UI.ShowSection = ShowSection

-- Officer-only sections come and go with your rank: lay out the menu again.
local function UpdateTabVisibility()
  local y = -62
  local pendingGroup
  for _, b in ipairs(panel.navItems) do
    if b.group then
      b:Hide()
      pendingGroup = b
    else
      local shown = sectionVisible(b.section)
      b:SetShown(shown)
      if shown then
        if pendingGroup then
          pendingGroup:Show()
          pendingGroup:ClearAllPoints()
          pendingGroup:SetPoint("TOPLEFT", 21, y - 8)
          y = y - 22
          pendingGroup = nil
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 10, y)
        y = y - 26
        local text, color = nil, nil
        if b.section.badge then text, color = b.section.badge() end
        b.badge:SetText(text or "")
        local c = C[color or "faint"]
        b.badge:SetTextColor(c[1], c[2], c[3])
        -- No room for the note next to a long name (in some languages): a dot instead.
        local fits = b.text:GetStringWidth() + b.badge:GetStringWidth() + 34 + 14 <= SIDEBAR - 20
        b.badge:SetShown(fits)
        b.dot:SetShown(text ~= nil and not fits)
        b.dot:SetColorTexture(c[1], c[2], c[3], 1)
      end
    end
  end
  if not sectionVisible(section) or not itemVisible(section.items[item]) then ShowSection(section, item) end
end

local function MakeNavButton(parent, s)
  local b = CreateFrame("Button", nil, parent)
  b.section = s
  b:SetSize(SIDEBAR - 20, 26)
  b.active = UI.Fill(b, C.accent, 0.12)
  b.bar = b:CreateTexture(nil, "BORDER")
  b.bar:SetPoint("TOPLEFT")
  b.bar:SetPoint("BOTTOMLEFT")
  b.bar:SetWidth(2)
  b.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
  local hover = b:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(1, 1, 1, 0.04)
  b.icon = UI.Icon(b, s.icon or "addon", 14, C.navText)
  b.icon:SetPoint("LEFT", 11, 0)
  b.text = UI.Label(b, s.title, "Nav")
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 9, 0)
  b.badge = UI.Label(b, "", "MutedSmall")
  b.badge:SetPoint("RIGHT", -8, 0)
  b.dot = b:CreateTexture(nil, "OVERLAY")
  b.dot:SetSize(6, 6)
  b.dot:SetPoint("RIGHT", -10, 0)
  b.dot:Hide()
  b:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    ShowSection(s, s == section and item or 1)
  end)
  return b
end

-- Getting started, above Settings and Help, until it's done or hidden.
local function MakeStartCard(side)
  local card = CreateFrame("Button", nil, side)
  card:SetSize(SIDEBAR - 20, 44)
  card:SetPoint("BOTTOMLEFT", 10, 90)
  UI.Fill(card, C.accent, 0.08)
  UI.Border(card, C.accent[1], C.accent[2], C.accent[3], 0.45)
  local hover = card:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(1, 1, 1, 0.04)
  card.title = UI.Label(card, "Getting started", "Subheading")
  card.title:SetPoint("TOPLEFT", 9, -8)
  card.title:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  card.count = UI.Label(card, "", "MutedSmall")
  card.count:SetPoint("BOTTOMRIGHT", -8, 6)
  card.track = card:CreateTexture(nil, "ARTWORK")
  card.track:SetPoint("BOTTOMLEFT", 9, 10)
  card.track:SetSize(SIDEBAR - 80, 4)
  card.track:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.18)
  card.fill = card:CreateTexture(nil, "OVERLAY")
  card.fill:SetPoint("LEFT", card.track, "LEFT")
  card.fill:SetHeight(4)
  card.fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
  card:SetScript("OnClick", function() if ns.ShowGettingStarted then ns.ShowGettingStarted() end end)
  UI.Tooltip(card, "Getting started", "Five quick things so the guild sees you, and you see the guild. Each ticks itself off.")
  function card:Update()
    local _, n, total = ns.StartedSteps()
    local show = n < total and not ns.db.started.dismissed
    self:SetShown(show)
    if not show then return end
    self.count:SetText(ns.TF("%d of %d", n, total))
    self.fill:SetShown(n > 0)
    self.fill:SetWidth(math.max(1, (SIDEBAR - 80) * n / total))
  end
  return card
end

-- Settings and Help: rows like the menu's, at the bottom.
local function SideButton(side, text, icon, onClick)
  local b = CreateFrame("Button", nil, side)
  b:SetSize(SIDEBAR - 20, 26)
  b.active = UI.Fill(b, C.accent, 0.12)
  b.active:Hide()
  local hover = b:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(1, 1, 1, 0.04)
  if icon then
    b.icon = UI.Icon(b, icon, 14, C.navText)
    b.icon:SetPoint("LEFT", 11, 0)
  else
    b.icon = UI.Label(b, "?", "Subheading")
    b.icon:SetPoint("LEFT", 14, 0)
    b.icon:SetTextColor(C.navText[1], C.navText[2], C.navText[3])
  end
  b.text = UI.Label(b, text, "Nav")
  b.text:SetPoint("LEFT", 34, 0)
  b:SetScript("OnClick", onClick)
  return b
end

local function CreatePanel()
  panel = CreateFrame("Frame", "WarcrestPanel", UIParent)
  panel:SetSize(WIDTH, HEIGHT)
  panel:SetPoint("CENTER")
  panel:SetFrameStrata("HIGH")
  panel:SetToplevel(true)
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:SetClampedToScreen(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
  -- Resizable from the corner, back to the size it was left at.
  panel:SetResizable(true)
  panel:SetResizeBounds(WIDTH, HEIGHT, MAX_WIDTH, MAX_HEIGHT)
  panel:SetSize(math.max(WIDTH, math.min(MAX_WIDTH, ns.db.panelWidth or WIDTH)),
    math.max(HEIGHT, math.min(MAX_HEIGHT, ns.db.panelHeight or HEIGHT)))
  panel:SetScale(ns.db.panelScale or 1)
  panel:Hide()
  tinsert(UISpecialFrames, "WarcrestPanel") -- Escape closes it
  UI.Fill(panel, C.window)
  UI.Border(panel, C.edge[1], C.edge[2], C.edge[3], 1)

  -- Side menu
  local side = CreateFrame("Frame", nil, panel)
  side:SetPoint("TOPLEFT")
  side:SetPoint("BOTTOMLEFT")
  side:SetWidth(SIDEBAR)
  UI.Fill(side, C.sidebar)
  local divider = side:CreateTexture(nil, "BORDER")
  divider:SetPoint("TOPRIGHT")
  divider:SetPoint("BOTTOMRIGHT")
  divider:SetWidth(1)
  divider:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)

  local emblem = side:CreateTexture(nil, "ARTWORK")
  ns.Emblem(emblem, "PORTRAIT")
  emblem:SetSize(30, 30)
  emblem:SetPoint("TOPLEFT", 14, -16)
  local brand = UI.Label(side, "", "Brand")
  brand:SetPoint("TOPLEFT", emblem, "TOPRIGHT", 9, -1)
  brand:SetWidth(100)
  brand:SetWordWrap(false)
  local sub = UI.Label(side, "", "MutedSmall")
  sub:SetPoint("TOPLEFT", brand, "BOTTOMLEFT", 0, -3)
  sub:SetWidth(100)
  sub:SetWordWrap(false)
  panel.brand, panel.brandSub = brand, sub
  -- The Imperium: its own name, as before. Other guilds: Warcrest, with the guild's name under it.
  ns.OnLook(function()
    brand:SetText(ns.BRAND)
    sub:SetText(ns.look == "imperium" and "Guild Tools" or (ns.GuildName() or "Guild tools"))
  end)

  -- The sections, in their groups.
  panel.navButtons, panel.navItems = {}, {}
  for _, s in ipairs(SECTIONS) do
    if s.group then
      local g = CreateFrame("Frame", nil, side)
      g:SetSize(SIDEBAR - 26, 14)
      g.group = true
      local label = UI.Label(g, ns.Upper(ns.T(s.group)), "Label")
      label:SetPoint("LEFT")
      panel.navItems[#panel.navItems + 1] = g
    else
      local b = MakeNavButton(side, s)
      panel.navButtons[#panel.navButtons + 1] = b
      panel.navItems[#panel.navItems + 1] = b
    end
  end

  -- At the bottom: Getting started, then Settings and Help, and the version.
  panel.startCard = MakeStartCard(side)
  panel.settingsButton = SideButton(side, "Settings", "settings", function() ShowSection(SETTINGS, 1) end)
  panel.settingsButton:SetPoint("BOTTOMLEFT", 10, 56)
  local help = SideButton(side, "Help", nil, function() if ns.ShowHelp then ns.ShowHelp() end end)
  help:SetPoint("BOTTOMLEFT", 10, 30)
  local version = UI.Label(side, "v" .. (ns.version or "?"), "MutedSmall")
  version:SetPoint("BOTTOMLEFT", 14, 11)

  -- Header
  panel.heading = UI.Label(panel, "", "Title")
  panel.heading:SetPoint("TOPLEFT", SIDEBAR + 20, -12)
  panel.subheading = UI.Label(panel, "", "MutedSmall")
  panel.subheading:SetPoint("TOPLEFT", panel.heading, "BOTTOMLEFT", 0, -4)
  local rule = panel:CreateTexture(nil, "BORDER")
  rule:SetPoint("TOPLEFT", SIDEBAR, -HEADER)
  rule:SetPoint("TOPRIGHT", 0, -HEADER)
  rule:SetHeight(1)
  rule:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
  local close = UI.CloseButton(panel)
  close:SetSize(26, 26)
  close:SetPoint("TOPRIGHT", -12, -13)

  -- The corner handle for resizing.
  local grip = CreateFrame("Button", nil, panel)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -3, 3)
  grip:SetFrameLevel(panel:GetFrameLevel() + 20)
  local gripIcon = UI.Icon(grip, "grip", 16, C.faint)
  gripIcon:SetAllPoints()
  grip:SetScript("OnEnter", function() gripIcon:SetVertexColor(C.accent[1], C.accent[2], C.accent[3]) end)
  grip:SetScript("OnLeave", function() gripIcon:SetVertexColor(C.faint[1], C.faint[2], C.faint[3]) end)
  grip:SetScript("OnMouseDown", function() panel:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function()
    panel:StopMovingOrSizing()
    ns.db.panelWidth, ns.db.panelHeight = math.floor(panel:GetWidth() + 0.5), math.floor(panel:GetHeight() + 0.5)
  end)

  -- One page per tab. In sections with views, pages start under the row of views.
  for _, t in ipairs(UI.tabs) do
    local sec = find(t.id)
    local below = (sec and #sec.items > 1) and SWITCH_H or 0
    local page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT", SIDEBAR + 10, -HEADER - 8 - below)
    page:SetPoint("BOTTOMRIGHT", -10, 10)
    page:Hide()
    -- Room in the header, left of the close button, for the tab's own controls
    -- (shown and hidden with the tab). Anchor them to its right edge.
    page.headerBar = CreateFrame("Frame", nil, page)
    page.headerBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -46, -13)
    page.headerBar:SetSize(520, 26)
    t.page = page
    t.build(page)
    -- A bigger window: the tab's lists stretch and what's below them moves down.
    page:SetScript("OnSizeChanged", function(self, w, h) UI.ApplyGrowth(self, w, h) end)
    UI.ApplyGrowth(page, panel:GetWidth() - SIDEBAR - 20, panel:GetHeight() - HEADER - 18 - below)
  end

  -- The switch for each section with more than one view.
  for _, s in ipairs(SECTIONS) do
    if s.items and #s.items > 1 then
      local options = {}
      for i, it in ipairs(s.items) do options[i] = { i, it.label } end
      s.switch = UI.Segmented(panel, options, function(i) ShowSection(s, i) end)
      s.switch:SetPoint("TOPLEFT", SIDEBAR + 11, -HEADER - 9)
      s.switch:Hide()
    end
  end

  panel:SetScript("OnShow", function()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
    ns.RequestRoster()
    UpdateTabVisibility()
    ns.RefreshPanel()
  end)
  panel:SetScript("OnHide", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end)

  -- Open where you were last time (or Home).
  local s, i
  for _, x in ipairs({ SETTINGS, unpack(SECTIONS) }) do
    if x.id and x.id == ns.db.lastSection then s, i = x, ns.db.lastItem end
  end
  if not s and ns.db.lastTab then s, i = find(ns.db.lastTab) end
  UpdateTabVisibility()
  ShowSection(s or SECTIONS[1], i or 1)
end

-- Window size setting: scales the guild window and its pop-ups (text and all).
function ns.SetPanelScale(scale)
  scale = math.max(MIN_SCALE, math.min(MAX_SCALE, scale or 1))
  ns.db.panelScale = scale
  if panel then panel:SetScale(scale) end
  for _, w in ipairs(UI.windows) do w:SetScale(scale) end
end

-- Back to the normal size, in the middle of the screen.
function ns.ResetPanelSize()
  ns.db.panelWidth, ns.db.panelHeight = nil, nil
  ns.SetPanelScale(1)
  if panel then
    panel:SetSize(WIDTH, HEIGHT)
    panel:ClearAllPoints()
    panel:SetPoint("CENTER")
  end
end

-- Many things ask for a refresh: every roster update, and every entry that
-- arrives while the guild's history syncs (hundreds in a few seconds). Redrawing
-- the page for each made a lot of garbage and could lag the game, so requests
-- made while handling game events and guildmates' messages are drawn at most
-- every 0.3 s. Clicks and other things the player does draw straight away.
local REFRESH_GAP = 0.3
local lastRefresh, refreshQueued = -1, false
local refreshNow

function ns.RefreshPanel()
  local now = GetTime()
  if (ns.busy or 0) == 0 or now - lastRefresh >= REFRESH_GAP then return refreshNow() end
  if refreshQueued then return end
  refreshQueued = true
  C_Timer.After(REFRESH_GAP - (now - lastRefresh), refreshNow)
end

function refreshNow()
  refreshQueued = false
  lastRefresh = GetTime()
  if ns.RefreshPlayerCard then ns.RefreshPlayerCard() end
  if not (panel and panel:IsShown()) then return end
  UpdateTabVisibility()
  local t, it = currentTab()
  if t and t.refresh then t.refresh(t.page) end
  -- A view picked from the section's switch: the tab's own switch isn't needed.
  if it.view and t.view then t.view:Hide() end
  setHeader()
  layoutSwitch()
  panel.startCard:Update()
end

-- The window holds secure buttons, so it can't be opened, moved or closed
-- during combat. It closes when combat starts and reopens afterwards.
local reopenAfterCombat = false

local function blockedByCombat()
  if InCombatLockdown() then
    ns.Say("Warcrest can't be opened during combat.")
    return true
  end
end

function ns.TogglePanel()
  if blockedByCombat() then return end
  if not panel then CreatePanel() end
  panel:SetShown(not panel:IsShown())
  if panel:IsShown() and ns.NoteStarted then ns.NoteStarted("open") end
end

-- tab: a tab's id ("kills", "settings", ...), or its position. view: one
-- of the tab's views (Raids' "progress", say), if it has them.
function ns.OpenPanel(tab, view)
  if blockedByCombat() then return end
  if not panel then CreatePanel() end
  if tonumber(tab) then tab = (UI.tabs[tonumber(tab)] or UI.tabs[1]).id end
  panel:Show()
  if ns.NoteStarted then ns.NoteStarted("open") end
  local s, i = find(tab or "home", view)
  ShowSection(s or SECTIONS[1], i)
  local t, it = currentTab()
  if view and not it.view and t.view and t.id == tab then
    t.view:Pick(view)
  end
end

-- Which section and view are showing (for tests): section id, tab id.
function ns.PanelSection()
  local t = currentTab()
  return section.id, t and t.id
end

ns.OnEvent("PLAYER_REGEN_DISABLED", function()
  if panel and panel:IsShown() then
    reopenAfterCombat = true
    panel:Hide()
  end
end)

ns.OnEvent("PLAYER_REGEN_ENABLED", function()
  if reopenAfterCombat and panel then
    reopenAfterCombat = false
    panel:Show()
  end
end)

------------------------------------------------------------------------
-- Entry in Esc > Options > AddOns
------------------------------------------------------------------------
ns.OnLoad(function()
  if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
    return
  end
  local canvas = CreateFrame("Frame")

  local icon = canvas:CreateTexture(nil, "ARTWORK")
  icon:SetSize(56, 56)
  icon:SetPoint("TOPLEFT", 16, -16)
  ns.Emblem(icon, "PORTRAIT")

  local title = UI.Label(canvas, "", "GameFontNormalHuge")
  ns.OnLook(function() title:SetText(ns.COLOR .. ns.BRAND .. "|r") end)
  title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
  local sub = UI.Label(canvas, "Guild tools  -  version " .. (ns.version or "?"), "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

  local desc = UI.Label(canvas, "PvP kill and level-up alerts, raid sign-ups and DKP for the whole guild, plus roster tools "
    .. "and an activity log for officers. Everything lives in the guild tools window.", "GameFontHighlight")
  desc:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -20)
  desc:SetWidth(520)

  local open = UI.Button(canvas, "Open Guild Tools", 180)
  open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
  open:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    ns.OpenPanel("roster")
  end)

  local hint = UI.Label(canvas, "You can also type /warcrest (or /wc) or click Warcrest in the addons menu by the minimap.",
    "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -10)

  local minimapCheck = CreateFrame("CheckButton", nil, canvas, "UICheckButtonTemplate")
  minimapCheck:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -4, -8)
  local minimapLabel = UI.Label(minimapCheck, "Show the minimap button")
  minimapLabel:SetPoint("LEFT", minimapCheck, "RIGHT", 2, 0)
  minimapCheck:SetScript("OnClick", function(self)
    if ns.SetMinimapButtonShown then ns.SetMinimapButtonShown(self:GetChecked() and true or false) end
  end)
  canvas:SetScript("OnShow", function()
    minimapCheck:SetChecked(ns.IsMinimapButtonShown and ns.IsMinimapButtonShown())
  end)
  ns.OnMinimapButtonChanged = function()
    minimapCheck:SetChecked(ns.IsMinimapButtonShown and ns.IsMinimapButtonShown())
  end

  -- The artwork, with a thin gold frame.
  local frame = canvas:CreateTexture(nil, "BACKGROUND")
  frame:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 2, -10)
  frame:SetSize(324, 324)
  frame:SetColorTexture(0.83, 0.69, 0.22, 0.9)
  local art = canvas:CreateTexture(nil, "ARTWORK")
  art:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
  art:SetSize(320, 320)
  ns.Emblem(art, "ARTWORK")

  local category = Settings.RegisterCanvasLayoutCategory(canvas, "Warcrest")
  Settings.RegisterAddOnCategory(category)
  ns.optionsCategory = category
end)
