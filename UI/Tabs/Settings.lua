--[[
  Warcrest
  Settings tab. Two views, switched at the top:
    Alerts:  every alert type with a Guild column (set by officers for
             everyone) and a You column (your own choice), plus how alerts
             appear.
    General: quiet mode, the world map, the weekly recap and the guild
             window's size. (Your title is chosen on the Achievements tab.)
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local MAX_PIN_HOURS = 7 * 24
local P = { guildTypes = {}, myTypes = {}, views = {} }
local TAB

local TABLE_W = 460
local SIDE_X = TABLE_W + 14
local SIDE_W = 740 - SIDE_X
local INNER = SIDE_W - 30
local GUILD_R, YOU_R = -86, -30  -- the two checkbox columns, from the card's right edge
local ROW, GROUP = 20, 18

local function formatHours(h)
  if h < 24 then return h == 1 and "1 hour" or (h .. " hours") end
  local d, rest = math.floor(h / 24), h % 24
  local text = d == 1 and "1 day" or (d .. " days")
  if rest > 0 then text = text .. " " .. (rest == 1 and "1 hour" or (rest .. " hours")) end
  return text
end

local function RefreshAlerts()
  local c, db = ns.cfg, ns.db
  local officer = ns.IsAddonOfficer()
  local isGM = ns.MyRank() == 0

  P.enabled:SetChecked(c.enabled)
  UI.SetEnabled(P.enabled, officer)
  P.dkp:SetChecked(c.dkp)
  UI.SetEnabled(P.dkp, officer)
  P.bounties:SetChecked(c.bounties)
  UI.SetEnabled(P.bounties, officer)
  P.memberPolls:SetChecked(c.memberPolls)
  UI.SetEnabled(P.memberPolls, officer)
  for key, cb in pairs(P.guildTypes) do
    cb:SetChecked(c.types[key])
    UI.SetEnabled(cb, officer and c.enabled)
  end
  P.rankValue = P.rankValue or c.officerRank
  if not P.rankDirty then P.rankValue = c.officerRank end
  P.rankText:SetText(ns.TF("%s and higher", UI.RankName(P.rankValue)))
  if not P.rankDirty then P.chatOfficers:SetChecked(c.chatOfficers) end
  UI.SetEnabled(P.chatOfficers, isGM)
  UI.SetEnabled(P.rankDown, isGM)
  UI.SetEnabled(P.rankUp, isGM)
  UI.SetEnabled(P.save, officer)

  local status = officer and "You can change the guild column."
    or ns.TF("Only %s and higher can change the guild column.", UI.RankName(c.officerRank))
  if c.stamp > 0 then
    status = status .. "\nLast saved by " .. c.by .. ", " .. ns.Date("%b %d at %H:%M", c.stamp) .. "."
  end
  P.status:SetText(status)

  for key, cb in pairs(P.myTypes) do
    local note
    if cb.filter then
      -- A filter: on for the guild means on for everyone; otherwise your choice.
      local guildOn = c.types[key]
      cb:SetChecked(guildOn or db.show[key])
      UI.SetEnabled(cb, not guildOn)
      note = guildOn and "on for everyone" or nil
    else
      local guildOn = c.enabled and c.types[key]
      cb:SetChecked(db.show[key])
      UI.SetEnabled(cb, guildOn)
      note = not guildOn and "off for the guild" or nil
    end
    cb.note:SetText(note or "")
    cb.rowLabel:SetAlpha(note and not cb.filter and 0.55 or 1)
  end

  P.sound:SetChecked(db.sound)
  P.warn:Sync()
end

local function RefreshGeneral()
  local db = ns.db
  P.quietInstances:SetChecked(db.quietInstances)
  P.quietCombat:SetChecked(db.quietCombat)
  P.recap:SetChecked(db.weeklyRecap)
  P.lang:Sync()
  local pct = math.floor((db.panelScale or 1) * 100 + 0.5)
  P.scaleSlider:SetQuietly(pct)
  P.scaleValue:SetText(pct .. "%")
  P.pins:SetChecked(db.mapPins)
  P.pinSlider:SetQuietly(db.pinHours)
  P.pinValue:SetText(formatHours(db.pinHours))
  UI.SetEnabled(P.pinSlider, db.mapPins)
  P.pinLabel:SetAlpha(db.mapPins and 1 or 0.5)
  P.pinValue:SetAlpha(db.mapPins and 1 or 0.5)
end

local function SyncCycle(cycle, value)
  for i, o in ipairs(cycle.options) do
    if o[1] == value then cycle.index, cycle.value = i, o[1]; cycle:SetText(o[2]) end
  end
end

local function RefreshAccess()
  local a = ns.Access()
  SyncCycle(P.textSize, a.textSize)
  SyncCycle(P.bannerHold, a.bannerHold)
  SyncCycle(P.font, a.font)
  SyncCycle(P.bannerSize, a.bannerSize)
  P.outline:SetChecked(a.outline)
  P.spacing:SetChecked(a.spacing)
  P.speak:SetChecked(a.speak)
  P.flash:SetChecked(a.flash)
  P.colorblind:SetChecked(a.colorblind)
  P.contrast:SetChecked(a.contrast)
  P.still:SetChecked(a.reduceMotion)
end

local function Refresh()
  local view = P.view.value
  for id, f in pairs(P.views) do f:SetShown(id == view) end
  if view == "alerts" then RefreshAlerts()
  elseif view == "sounds" then UI.SoundsView.Refresh()
  elseif view == "access" then RefreshAccess()
  else RefreshGeneral() end
end

------------------------------------------------------------------------
-- Alerts view
------------------------------------------------------------------------
local function BuildAlertTable(parent)
  local card = UI.Box(parent, 0, 0, TABLE_W, 448)
  P.table = card
  UI.TableHeads(card, { { "ALERT", 14 } })
  for _, h in ipairs({ { "GUILD", GUILD_R }, { "YOU", YOU_R } }) do
    local fs = UI.Label(card, h[1], "Label")
    fs:SetPoint("TOP", card, "TOPRIGHT", h[2], -9)
    fs:SetJustifyH("CENTER")
  end
  local y = -32
  local group
  for _, t in ipairs(ns.TYPES) do
    if not t.hidden then -- hidden: no longer a choice
      if t.group ~= group then
        group = t.group
        local g = UI.Label(card, ns.GROUP_LABELS[group]:upper(), "Label")
        g:SetPoint("TOPLEFT", 14, y - 6)
        g:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
        y = y - GROUP
      end
      local label = UI.Label(card, t.label, "Body")
      label:SetPoint("TOPLEFT", 14, y - 5)
      label:SetWidth(TABLE_W - 230)
      label:SetWordWrap(false)

      local g = UI.CheckBox(card, 16)
      g:SetPoint("TOP", card, "TOPRIGHT", GUILD_R, y - 4)
      UI.Tooltip(g, t.label, t.key == "achievement_chat"
        and "Guild-wide: when someone earns an achievement, their addon posts it in guild chat, so everyone sees it, even without Warcrest. Officers set this and click Save for whole guild."
        or "Guild-wide: whether this is announced at all, for everyone. Officers set this and click Save for whole guild.")
      P.guildTypes[t.key] = g

      local me = UI.CheckBox(card, 16)
      me:SetPoint("TOP", card, "TOPRIGHT", YOU_R, y - 4)
      me.filter = t.filter
      me.rowLabel = label
      me.note = UI.Label(card, "", "MutedSmall")
      me.note:SetPoint("TOPRIGHT", card, "TOPRIGHT", GUILD_R - 22, y - 6)
      me.note:SetJustifyH("RIGHT")
      me:SetScript("OnClick", function(self)
        ns.db.show[t.key] = self:GetChecked() and true or false
        if t.filter and ns.OnHistoryChanged then ns.OnHistoryChanged() end
      end)
      UI.Tooltip(me, t.label, t.youTip or "Just for you: untick to stop seeing this alert yourself. Greyed out when the guild has turned it off.")
      P.myTypes[t.key] = me

      local line = card:CreateTexture(nil, "BORDER")
      line:SetPoint("TOPLEFT", 14, y - ROW)
      line:SetPoint("TOPRIGHT", -14, y - ROW)
      line:SetHeight(1)
      line:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
      y = y - ROW
    end
  end
end

local function BuildGuildCard(parent)
  local g = UI.Box(parent, SIDE_X, 0, SIDE_W, 280, "Guild-wide")
  P.guildCard = g
  local d = UI.Label(g, "Set by officers for everyone.", "MutedSmall")
  d:SetPoint("TOPLEFT", 14, -34)

  P.enabled = UI.Check(g, "Guild alerts on", 10, -50)
  P.enabled:SetScript("OnClick", function(self)
    for _, cb in pairs(P.guildTypes) do UI.SetEnabled(cb, self:GetChecked()) end
  end)
  UI.Tooltip(P.enabled, "Guild alerts on", "Turns every alert off or on for the whole guild at once. Click Save for whole guild to send it.")
  P.dkp = UI.Check(g, "Use DKP for loot", 10, -74)
  UI.Tooltip(P.dkp, "Use DKP for loot", "Off: DKP standings, loot auctions and raid night DKP are hidden for everyone. "
    .. "Raids, sign-ups, attendance, wishlists and everything else still work. Click Save for whole guild to send it.")

  P.bounties = UI.Check(g, "Bounties", 10, -98)
  UI.Tooltip(P.bounties, "Bounties", "Officers can put a reward on an enemy player's head, and the guild member who kills them "
    .. "claims it (paid in DKP if the guild uses DKP). Off until an officer turns it on. Click Save for whole guild to send it.")

  P.memberPolls = UI.Check(g, "Members can start polls", 10, -122)
  UI.Tooltip(P.memberPolls, "Members can start polls", "Off: only officers can start guild polls (Events > Polls). "
    .. "On: any member can, one open poll each. Click Save for whole guild to send it.")

  UI.FieldLabel(g, "Who can change these", 14, -146)
  P.rankDown = UI.Button(g, "<", 26)
  P.rankDown:SetHeight(24)
  P.rankDown:SetPoint("TOPLEFT", 14, -160)
  P.rankUp = UI.Button(g, ">", 26)
  P.rankUp:SetHeight(24)
  P.rankUp:SetPoint("TOPRIGHT", -14, -160)
  P.rankText = UI.Label(g, "", "Small")
  P.rankText:SetPoint("LEFT", P.rankDown, "RIGHT", 8, 0)
  P.rankText:SetPoint("RIGHT", P.rankUp, "LEFT", -8, 0)
  P.rankText:SetJustifyH("CENTER")
  P.rankText:SetWordWrap(false)
  local function step(delta)
    P.rankValue = math.max(0, math.min(UI.NumRanks() - 1, P.rankValue + delta))
    P.rankDirty = true
    P.rankText:SetText(ns.TF("%s and higher", UI.RankName(P.rankValue)))
  end
  P.rankDown:SetScript("OnClick", function() step(-1) end)
  P.rankUp:SetScript("OnClick", function() step(1) end)
  UI.Tooltip(P.rankDown, "Higher ranks only", "Only the Guild Master can change who may edit the guild settings.")
  UI.Tooltip(P.rankUp, "More ranks", "Only the Guild Master can change who may edit the guild settings.")
  P.chatOfficers = UI.Check(g, "And every rank with officer chat", 10, -188)
  UI.Tooltip(P.chatOfficers, "And every rank with officer chat", "On: every rank that can read officer chat (set in the game's guild "
    .. "control) counts as an officer in Warcrest too: the Officers section, scheduling raids, guild settings. "
    .. "Off: only the ranks picked above. Only the Guild Master can change this.")

  P.save = UI.Button(g, "Save for whole guild", INNER, "primary")
  P.save:SetHeight(28)
  P.save:SetPoint("TOPLEFT", 14, -214)
  UI.Tooltip(P.save, "Save for whole guild", "Sends the Guild column to every guildmate's addon. Members who are offline get it when they next log in while an officer is online.")
  P.save:SetScript("OnClick", function()
    local types = {}
    for key, cb in pairs(P.guildTypes) do types[key] = cb:GetChecked() and true or false end
    P.rankDirty = nil
    ns.PushConfig({
      enabled = P.enabled:GetChecked() and true or false,
      types = types,
      officerRank = P.rankValue,
      dkp = P.dkp:GetChecked() and true or false,
      bounties = P.bounties:GetChecked() and true or false,
      memberPolls = P.memberPolls:GetChecked() and true or false,
      chatOfficers = P.chatOfficers:GetChecked() and true or false,
    })
  end)

  P.status = UI.Label(g, "", "MutedSmall")
  P.status:SetPoint("TOPLEFT", 14, -248)
  P.status:SetWidth(INNER)
  P.status:SetSpacing(2)
end

local function BuildAppearCard(parent)
  local a = CreateFrame("Frame", nil, parent)
  P.appear = a
  a:SetPoint("BOTTOMLEFT", SIDE_X + 1, 1)
  a:SetSize(SIDE_W - 2, 164)
  UI.Card(a, 1)
  UI.Label(a, "How alerts appear", "Heading"):SetPoint("TOPLEFT", 14, -12)
  P.sound = UI.Check(a, "Play a sound", 10, -36)
  P.sound:SetScript("OnClick", function(self) ns.db.sound = self:GetChecked() and true or false end)
  UI.Tooltip(P.sound, "Play a sound", "Each kind of alert has its own sound. Pick them on the Sounds view at the top.")
  local onScreen = UI.Label(a, "On screen", "Body")
  onScreen:SetPoint("TOPLEFT", 14, -70)
  P.warn = UI.Cycle(a, 150, { { "banner", "Banner" }, { "warning", "Raid warning text" }, { "off", "Chat only" } },
    function(v)
      ns.db.alertStyle = v
      ns.db.warning = v ~= "off"
    end)
  P.warn:SetHeight(24)
  P.warn:SetPoint("TOPRIGHT", -14, -64)
  P.warn.Sync = function(self)
    local style = ns.AlertStyle()
    for i, o in ipairs(self.options) do
      if o[1] == style then self.index, self.value = i, o[1]; self:SetText(o[2]) end
    end
  end
  UI.Tooltip(P.warn, "On screen", "Banner: a card at the top of the screen with an icon and colour for each kind of alert. "
    .. "Click it to open what it's about, right-click to dismiss, Shift-drag to move. Raid warning text: the game's "
    .. "big text in the middle of the screen. Chat only: nothing on screen.")
  local chat = UI.Label(a, "Alerts always go to chat too.", "MutedSmall")
  chat:SetPoint("TOPLEFT", 14, -98)

  local test = UI.Button(a, "Show test alert", INNER)
  test:SetHeight(26)
  test:SetPoint("BOTTOMLEFT", 14, 14)
  test:SetScript("OnClick", ns.TestAlert)
  UI.Tooltip(test, "Show test alert", "Shows an example alert just for you, so you can see how alerts look and sound. A different kind each click. Nobody else sees it.")
end

local function BuildAlerts(page)
  local f = CreateFrame("Frame", nil, page)
  f:SetPoint("TOPLEFT")
  f:SetSize(740, 450)
  P.views.alerts = f
  BuildAlertTable(f)
  BuildGuildCard(f)
  BuildAppearCard(f)
  return f
end

------------------------------------------------------------------------
-- General view
------------------------------------------------------------------------
local COL_W = (740 - 14) / 2

local function BuildGeneral(page)
  local f = CreateFrame("Frame", nil, page)
  f:SetPoint("TOPLEFT")
  f:SetSize(740, 450)
  P.views.general = f
  local x2 = COL_W + 14
  local inner = COL_W - 30

  -- Quiet mode
  local q = UI.Box(f, 0, 0, COL_W, 138, "Quiet mode")
  P.quietInstances = UI.Check(q, "Hold alerts in dungeons and raids", 10, -36)
  P.quietInstances:SetScript("OnClick", function(self) ns.db.quietInstances = self:GetChecked() and true or false end)
  P.quietCombat = UI.Check(q, "Hold alerts during combat", 10, -62)
  P.quietCombat:SetScript("OnClick", function(self) ns.db.quietCombat = self:GetChecked() and true or false end)
  local qhint = UI.Label(q, "Held alerts are listed in chat once you're out.", "MutedSmall")
  qhint:SetPoint("TOPLEFT", 14, -100)
  qhint:SetWidth(inner)

  -- World map
  local m = UI.Box(f, 0, -152, COL_W, 130, "World map")
  P.pins = UI.Check(m, "Mark guild deaths on the world map", 10, -36)
  P.pins:SetScript("OnClick", function(self)
    ns.db.mapPins = self:GetChecked() and true or false
    if ns.RefreshMapPins then ns.RefreshMapPins() end
    ns.RefreshPanel()
  end)
  P.pinLabel = UI.FieldLabel(m, "Keep marks for", 14, -74)
  P.pinSlider = UI.Slider(m, inner - 110, 1, MAX_PIN_HOURS, 1, function(h)
    ns.db.pinHours = h
    P.pinValue:SetText(formatHours(h))
    if ns.RefreshMapPins then ns.RefreshMapPins() end
  end)
  P.pinSlider:SetPoint("TOPLEFT", 14, -94)
  P.pinValue = UI.Label(m, "", "Small")
  P.pinValue:SetPoint("LEFT", P.pinSlider, "RIGHT", 12, 0)
  UI.Tooltip(P.pinSlider, "How long a guild death stays marked on the map", "Drag, or use the mouse wheel. 1 hour to 7 days.")

  -- Weekly recap
  local r = UI.Box(f, 0, -296, COL_W, 154, "Weekly recap")
  P.recap = UI.Check(r, "Show it after the Tuesday reset", 10, -36)
  P.recap:SetScript("OnClick", function(self) ns.db.weeklyRecap = self:GetChecked() and true or false end)
  local rhint = UI.Label(r, "Kills, top head hunters, raids, bosses and loot from the guild's week, in chat.", "MutedSmall")
  rhint:SetPoint("TOPLEFT", 14, -68)
  rhint:SetWidth(inner)
  local half = (inner - 6) / 2
  local last = UI.Button(r, "Show last week", half)
  last:SetHeight(26)
  last:SetPoint("BOTTOMLEFT", 14, 14)
  last:SetScript("OnClick", function() ns.ShowRecap(-1) end)
  local this = UI.Button(r, "This week so far", half)
  this:SetHeight(26)
  this:SetPoint("LEFT", last, "RIGHT", 6, 0)
  this:SetScript("OnClick", function() ns.ShowRecap(0) end)

  -- Guild window
  local w = UI.Box(f, x2, 0, COL_W, 130, "Guild window")
  UI.FieldLabel(w, "Size", 14, -38)
  -- The new size applies when you let go, so the window doesn't shift under the mouse while dragging.
  local pending
  local function apply()
    if pending then ns.SetPanelScale(pending / 100); pending = nil end
  end
  P.scaleSlider = UI.Slider(w, inner - 60, 70, 150, 5, function(v)
    pending = v
    P.scaleValue:SetText(v .. "%")
  end)
  P.scaleSlider:SetPoint("TOPLEFT", 14, -58)
  P.scaleSlider:HookScript("OnMouseUp", apply)
  P.scaleSlider:HookScript("OnMouseWheel", apply)
  P.scaleValue = UI.Label(w, "", "Small")
  P.scaleValue:SetPoint("LEFT", P.scaleSlider, "RIGHT", 12, 0)
  UI.Tooltip(P.scaleSlider, "Window size", "Makes this window and its pop-ups bigger or smaller, text and all. Drag, or use the mouse wheel. To show more rows instead, drag the window's bottom-right corner.")
  local reset = UI.Button(w, "Reset size and position", inner - 136)
  reset:SetHeight(26)
  reset:SetPoint("BOTTOMLEFT", 14, 14)
  -- Language: takes effect after /reload (windows are built once).
  local langs = {}
  for _, l in ipairs(ns.LANGUAGES) do langs[#langs + 1] = { l[1], ns.T(l[2]) } end
  P.lang = UI.Cycle(w, 130, langs, function(v)
    ns.db.locale = v
    ns.Say("Language changed. Type /reload to see it everywhere.")
  end)
  P.lang:SetHeight(26)
  P.lang:SetPoint("LEFT", reset, "RIGHT", 6, 0)
  UI.Tooltip(P.lang, "Language", "The language for Warcrest's windows, messages and help. Game language follows your game client.")
  P.lang.Sync = function(self)
    for i, l in ipairs(self.options) do
      if l[1] == (ns.db.locale or "auto") then self.index = i; self.value = l[1]; self:SetText(l[2]) end
    end
  end
  reset:SetScript("OnClick", function() ns.ResetPanelSize(); ns.RefreshPanel() end)
  UI.Tooltip(reset, "Reset size and position", "Puts the window back to its normal size, in the middle of the screen.")

  -- Commands
  local h = UI.Box(f, x2, -144, COL_W, 306, "Good to know")
  local tips = UI.Label(h, "/warcrest card Name opens a guild member's player card, and /warcrest profile "
    .. "your own profile. /warcrest check explains an achievement that hasn't shown up, and /warcrest updates "
    .. "shows what's new. /warcrest help lists every command in chat.", "Small")
  local titles = UI.Label(h, "Your title is chosen in Achievements, at the top right. Everyone's profiles "
    .. "are in Guild > Profiles.", "Small")
  titles:SetPoint("TOPLEFT", tips, "BOTTOMLEFT", 0, -12)
  titles:SetWidth(inner)
  titles:SetSpacing(3)
  tips:SetPoint("TOPLEFT", 14, -38)
  tips:SetWidth(inner)
  tips:SetSpacing(3)
  return f
end


------------------------------------------------------------------------
-- Accessibility view
------------------------------------------------------------------------
local function BuildAccess(page)
  local f = CreateFrame("Frame", nil, page)
  f:SetPoint("TOPLEFT")
  f:SetSize(740, 450)
  P.views.access = f
  local x2 = COL_W + 14
  local inner = COL_W - 30

  local function check(box, key, label, y, tip)
    local cb = UI.Check(box, label, 10, y)
    cb:SetScript("OnClick", function(self) ns.SetAccess(key, self:GetChecked() and true or false) end)
    UI.Tooltip(cb, label, tip)
    return cb
  end
  local function cycle(box, label, width, options, key, y, tip)
    local l = UI.Label(box, label, "Body")
    l:SetPoint("TOPLEFT", 14, y - 6)
    local c = UI.Cycle(box, width, options, function(v) ns.SetAccess(key, v) end)
    c:SetHeight(24)
    c:SetPoint("TOPRIGHT", -14, y)
    UI.Tooltip(c, label, tip)
    return c
  end

  -- Text
  local t = UI.Box(f, 0, 0, COL_W, 214, "Text")
  local sizes = {}
  for _, s in ipairs(ns.TEXT_SIZES) do sizes[#sizes + 1] = { s, s .. "%" } end
  P.textSize = cycle(t, "Text size", 110, sizes, "textSize", -38,
    "Makes Warcrest's text bigger, in every window and on alert banners. Click to step through the sizes.")
  P.font = cycle(t, "Font", 150, { { "warcrest", "Warcrest" }, { "game", "Game font" }, { "plain", "Plain" } }, "font", -68,
    "Warcrest's own font, the game's font, or a plain, simple one that some find easier to read.")
  P.outline = check(t, "outline", "Thicker letters", -98, "A dark outline around every letter, so text stands out from what's behind it.")
  P.spacing = check(t, "spacing", "More space between lines", -124, "More room between the lines of longer text, easier to follow for some readers (dyslexia).")
  local thint = UI.Label(t, "Bigger text without bigger windows. To make whole windows bigger, use Size on the General view. Some windows fit best after /reload.", "MutedSmall")
  thint:SetPoint("TOPLEFT", 14, -158)
  thint:SetWidth(inner)
  thint:SetSpacing(2)

  -- Colours
  local c = UI.Box(f, 0, -228, COL_W, 222, "Colours")
  P.colorblind = check(c, "colorblind", "Colour-blind friendly colours", -36, "Alert colours, and the colours for good and bad news (like kills and deaths in chat), "
    .. "that stay apart with red-green or blue-yellow colour blindness. Every alert also says what kind it is in words.")
  local cbhint = UI.Label(c, "Blue for good news, orange for bad, instead of green and red.", "MutedSmall")
  cbhint:SetPoint("TOPLEFT", 40, -60)
  cbhint:SetWidth(inner - 26)
  P.contrast = check(c, "contrast", "High contrast", -90, "Brighter grey text and stronger borders and lines, for low vision or a bright room.")
  local hchint = UI.Label(c, "Brighter grey text, stronger borders and lines.", "MutedSmall")
  hchint:SetPoint("TOPLEFT", 40, -114)
  hchint:SetWidth(inner - 26)
  local reload = UI.Label(c, "Colours change everywhere after /reload.", "Small")
  reload:SetPoint("BOTTOMLEFT", 14, 16)
  reload:SetWidth(inner)

  -- Alert banners
  local b = UI.Box(f, x2, 0, COL_W, 266, "Alert banners")
  P.bannerHold = cycle(b, "Time on screen", 150, { { "normal", "Normal" }, { "long", "Twice as long" }, { "sticky", "Until dismissed" } },
    "bannerHold", -38, "How long alert banners stay. Until dismissed: each stays until you click it "
    .. "(left-click opens what it's about, right-click closes it). Up to three show at once; a new one replaces the oldest.")
  local bsizes = {}
  for _, s in ipairs(ns.BANNER_SIZES) do bsizes[#bsizes + 1] = { s, s .. "%" } end
  P.bannerSize = cycle(b, "Banner size", 110, bsizes, "bannerSize", -68, "Makes alert banners bigger, text and all.")
  P.still = check(b, "reduceMotion", "No sliding or fading", -98, "Banners appear and disappear at once, without moving.")
  P.speak = check(b, "speak", "Read alerts aloud", -124, "The game's text to speech reads each alert banner out loud. "
    .. "The voice, speed and volume are the ones set in the game's options (Accessibility > Text to speech).")
  P.flash = check(b, "flash", "Flash the game's taskbar icon", -150, "When an alert comes in while the game is in the background, "
    .. "its icon on the taskbar flashes, so you notice it without sound.")
  local bhint = UI.Label(b, "Hovering over a banner always keeps it on screen.", "MutedSmall")
  bhint:SetPoint("TOPLEFT", 14, -186)
  bhint:SetWidth(inner)
  local test = UI.Button(b, "Show test alert", inner)
  test:SetHeight(26)
  test:SetPoint("BOTTOMLEFT", 14, 14)
  test:SetScript("OnClick", ns.TestAlert)

  -- More that helps
  local m = UI.Box(f, x2, -280, COL_W, 170, "Also helps")
  local tips = UI.Label(m, "Chat only: Alerts > How alerts appear > On screen. Alerts then only go to chat, "
    .. "where they stay to read at your own pace.", "Small")
  tips:SetPoint("TOPLEFT", 14, -38)
  tips:SetWidth(inner)
  tips:SetSpacing(3)
  local tips2 = UI.Label(m, "Keyboard: set a key to open Warcrest in Key Bindings > AddOns. Esc closes it.", "Small")
  tips2:SetPoint("TOPLEFT", tips, "BOTTOMLEFT", 0, -10)
  tips2:SetWidth(inner)
  tips2:SetSpacing(3)
  return f
end

local function Build(page)
  P.view = UI.Segmented(page.headerBar, { { "alerts", "Alerts" }, { "sounds", "Sounds" }, { "general", "General" }, { "access", "Accessibility" } },
    ns.RefreshPanel)
  P.view:SetPoint("RIGHT")
  TAB.view = P.view
  local alerts = BuildAlerts(page)
  local general = BuildGeneral(page)
  local access = BuildAccess(page)
  local sounds = UI.SoundsView.Build(page)
  P.views.sounds = sounds

  -- A bigger window: the alert table gets the room; the side cards move right.
  UI.Grow(page, alerts, 1, 1)
  UI.Grow(page, general, 1, 1)
  UI.Grow(page, access, 1, 1)
  UI.Grow(page, sounds, 1, 1)
  UI.Grow(page, P.table, 1, 0)
  UI.FollowAll(page, { P.guildCard, P.appear }, 1, 0)
end

TAB = { id = "settings", title = "Settings", build = Build, refresh = Refresh,
  subtitle = function()
    if P.view and P.view.value == "general" then return "Quiet mode, the map, the weekly recap and the window" end
    if P.view and P.view.value == "sounds" then return "A sound and a banner colour for each kind of alert, and your own sounds" end
    if P.view and P.view.value == "access" then return "Text, fonts, colours, and how alerts show and sound" end
    return "Alerts for the whole guild, and just for you"
  end }
UI.AddTab(TAB)
