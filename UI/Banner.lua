--[[
  Warcrest
  Alert banners: guild alerts drop in at the top of the screen as a card in
  the Warcrest look, with a coloured edge and icon for each kind (a kill, a
  boss down, a wanted ganker spotted...), a small heading saying what it is,
  and the news under it. Up to three stack; each fades after a few seconds.
  Click one to open the matching tab, right-click to dismiss it. Shift-drag
  moves them (Settings > Alerts > Reset banner position puts them back).

  Settings > Alerts > On screen picks Banner, the game's raid warning text,
  or chat only (ns.db.alertStyle).
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local W, H = 440, 60
local GAP = 6
local MAX_SHOWN = 3
local FADE_IN, FADE_OUT = 0.2, 0.6

local function rgb(hex)
  return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
end

-- What each kind of alert looks like: heading, colour, icon, the tab a click opens, how long it stays.
-- Every kind has its own colour (at least 13 apart in CIE ΔE2000 from every other on the dark banner).
ns.BANNER_KINDS = {
  kill        = { title = "Guild kill",         color = rgb("2ee35a"), icon = "kills",    tab = "kills" },
  death       = { title = "Guild member down",  color = rgb("e8467c"), icon = "warning",  tab = "kills" },
  wanted      = { title = "Wanted ganker spotted", color = rgb("b56cff"), icon = "wanted", tab = "wanted", hold = 7 },
  streak      = { title = "Kill streak",        color = rgb("ffa31a"), icon = "kills",    tab = "kills" },
  revenge     = { title = "Revenge",            color = rgb("ff7438"), icon = "kills",    tab = "kills" },
  champion    = { title = "Top head hunters",   color = rgb("cfd8e3"),      icon = "trophy",   tab = "kills", hold = 8 },
  bounty      = { title = "Bounty",             color = rgb("b8865b"),      icon = "wanted",   tab = "wanted" },
  boss        = { title = "Boss down",          color = rgb("fff27a"),      icon = "progress",    tab = "raids", hold = 7 },
  raid        = { title = "Raid",               color = rgb("3d8bff"), icon = "calendar", tab = "raids", hold = 7 },
  rival       = { title = "Rival guild",        color = rgb("ffa8a0"), icon = "wanted",   tab = "wanted", hold = 7 },
  event       = { title = "Guild event",        color = rgb("2fd3c3"), icon = "events",   tab = "events", hold = 7 },
  loot        = { title = "Loot auction",       color = rgb("b5ef3a"), icon = "dkp",      tab = "dkp" },
  achievement = { title = "Achievement",        color = C.accent,      icon = "trophy",   tab = "achievements", hold = 6 },
  celebrate   = { title = "Guild news",         color = rgb("7fe0ff"),        icon = "roster",   tab = "roster" },
  worldbuff   = { title = "World buff",         color = rgb("ff6bea"), icon = "events",   tab = "worldbuffs", hold = 8 },
  rep         = { title = "Guild rep",          color = rgb("98b050"), icon = "trophy",   tab = "home", hold = 7 },
}
local DEFAULT_KIND = { title = "Guild alert", color = rgb("9aa3b2"), icon = "warning", tab = "roster" }

------------------------------------------------------------------------
-- Your own banner colours (Settings > Sounds): kind -> "rrggbb"
------------------------------------------------------------------------
local function hex(c)
  return string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
    math.floor(c[3] * 255 + 0.5))
end

-- The colour a kind of banner shows in: yours, then colour-blind friendly, then Warcrest's.
function ns.BannerColor(kind)
  local mine = ns.db and ns.db.bannerColors and ns.db.bannerColors[kind]
  if type(mine) == "string" and mine:match("^%x%x%x%x%x%x$") then return rgb(mine) end
  local k = ns.BANNER_KINDS[kind] or DEFAULT_KIND
  return ns.AccessKindColor(kind) or k.color
end

-- Whether you've picked your own colour for this kind.
function ns.HasOwnBannerColor(kind)
  return ns.db and ns.db.bannerColors and ns.db.bannerColors[kind] ~= nil
end

function ns.SetBannerColor(kind, r, g, b)
  if not ns.BANNER_KINDS[kind] then return end
  ns.db.bannerColors = ns.db.bannerColors or {}
  if r then ns.db.bannerColors[kind] = hex({ r, g, b }) else ns.db.bannerColors[kind] = nil end
end

function ns.ResetBannerColors() ns.db.bannerColors = {} end

local anchor
local pool, shown = {}, {}
local ticker

local function savePos()
  local x, y = anchor:GetCenter()
  local ux, uy = UIParent:GetCenter()
  if x and ux then ns.db.bannerPos = { x - ux, y - uy * 2 + (anchor:GetHeight() or 0) / 2 } end
end

local function placeAnchor()
  anchor:ClearAllPoints()
  local p = ns.db and ns.db.bannerPos
  if p then anchor:SetPoint("TOP", UIParent, "TOP", p[1], p[2]) else anchor:SetPoint("TOP", UIParent, "TOP", 0, -110) end
end

local function makeBanner()
  local b = CreateFrame("Button", nil, anchor)
  b:SetSize(W, H)
  b:SetFrameStrata("HIGH")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.bg = UI.Fill(b, C.window)
  b.bg:SetAlpha(0.96)
  b.border = UI.Border(b, C.edge[1], C.edge[2], C.edge[3], 1)
  -- A glow of the kind's colour from the left edge.
  b.glow = b:CreateTexture(nil, "BORDER")
  b.glow:SetPoint("TOPLEFT", 3, 0)
  b.glow:SetPoint("BOTTOMLEFT", 3, 0)
  b.glow:SetWidth(W * 0.6)
  b.glow:SetColorTexture(1, 1, 1, 1)
  b.bar = b:CreateTexture(nil, "ARTWORK")
  b.bar:SetPoint("TOPLEFT")
  b.bar:SetPoint("BOTTOMLEFT")
  b.bar:SetWidth(3)
  b.iconBg = b:CreateTexture(nil, "ARTWORK")
  b.iconBg:SetSize(36, 36)
  b.iconBg:SetPoint("LEFT", 14, 0)
  b.icon = UI.Icon(b, "kills", 18)
  b.icon:SetPoint("CENTER", b.iconBg, "CENTER")
  b.kicker = UI.Label(b, "", "Label")
  b.kicker:SetPoint("TOPLEFT", 62, -11)
  b.kicker:SetWidth(W - 76)
  b.kicker:SetWordWrap(false)
  b.text = UI.Label(b, "", "Subheading")
  b.text:SetPoint("TOPLEFT", 62, -27)
  b.text:SetWidth(W - 76)
  b.text:SetSpacing(2)
  if b.text.SetMaxLines then b.text:SetMaxLines(2) end
  -- Time left, as a thin line along the bottom.
  b.timer = b:CreateTexture(nil, "OVERLAY")
  b.timer:SetPoint("BOTTOMLEFT", 3, 0)
  b.timer:SetHeight(2)
  b:SetScript("OnClick", function(self, button)
    if button == "LeftButton" and self.kind.tab and ns.OpenPanel then ns.OpenPanel(self.kind.tab) end
    self.ends = math.min(self.ends, GetTime())
  end)
  b:SetMovable(true)
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function() if IsShiftKeyDown() then anchor:StartMoving() end end)
  b:SetScript("OnDragStop", function() anchor:StopMovingOrSizing(); savePos() end)
  b:SetScript("OnEnter", function(self) self.paused = GetTime() end)
  b:SetScript("OnLeave", function(self)
    if self.paused then self.ends = self.ends + (GetTime() - self.paused); self.paused = nil end
  end)
  return b
end

local function layout()
  local y = 0
  for _, b in ipairs(shown) do
    b.y = y
    b:ClearAllPoints()
    b:SetPoint("TOP", anchor, "TOP", 0, -y)
    y = y + b:GetHeight() + GAP
  end
end

local function tick()
  local now = GetTime()
  for i = #shown, 1, -1 do
    local b = shown[i]
    local ends = b.paused and (b.ends + (now - b.paused)) or b.ends
    local age = now - b.started
    local alpha
    local fadeOut = b.still and 0 or FADE_OUT
    if now >= ends + fadeOut then
      b:Hide()
      table.remove(shown, i)
      pool[#pool + 1] = b
      layout()
    else
      if b.still then
        alpha = 1
      elseif age < FADE_IN then
        alpha = age / FADE_IN
        b:SetPoint("TOP", anchor, "TOP", 0, -(b.y or 0) + 10 * (1 - alpha))
      elseif now > ends then
        alpha = 1 - (now - ends) / FADE_OUT
      else
        alpha = 1
      end
      b:SetAlpha(math.max(0, math.min(1, alpha)))
      if not b.sticky then
        local left = math.max(0, math.min(1, (ends - now) / b.hold))
        b.timer:SetWidth(math.max(1, (W - 3) * left))
      end
    end
  end
  if #shown == 0 and ticker then ticker:Cancel(); ticker = nil end
end

-- Show a banner. kind: a key of ns.BANNER_KINDS. text: the news (colour codes are fine).
function ns.ShowBanner(kind, text, title)
  if not anchor then
    anchor = CreateFrame("Frame", "WarcrestBanners", UIParent)
    anchor:SetSize(W, H)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    placeAnchor()
  end
  anchor:SetScale(ns.BannerScale())
  local k = ns.BANNER_KINDS[kind] or DEFAULT_KIND
  local b = table.remove(pool) or makeBanner()
  b.kind = k
  local c = ns.BannerColor(kind)
  b.bar:SetColorTexture(c[1], c[2], c[3], 1)
  b.iconBg:SetColorTexture(c[1], c[2], c[3], 0.14)
  b.icon:SetTexture(UI.IconPath(k.icon))
  b.icon:SetVertexColor(c[1], c[2], c[3])
  if not (CreateColor and pcall(b.glow.SetGradient, b.glow, "HORIZONTAL",
      CreateColor(c[1], c[2], c[3], 0.16), CreateColor(c[1], c[2], c[3], 0))) then
    b.glow:SetColorTexture(c[1], c[2], c[3], 0.06)
  end
  b.timer:SetColorTexture(c[1], c[2], c[3], 0.55)
  b.kicker:SetText(ns.Upper(ns.T(title or k.title)))
  b.kicker:SetTextColor(c[1], c[2], c[3])
  b.text:SetText(text)
  b.text:SetTextColor(C.text[1], C.text[2], C.text[3])
  b:SetHeight(math.max(H, math.floor(b.text:GetStringHeight() + 0.5) + 44))
  -- Settings > Accessibility: longer, or until dismissed (no end, no timer line).
  local hold = ns.BannerHold(k.hold or 5)
  b.sticky = hold == nil
  b.hold = hold or 1
  b.started = GetTime()
  b.ends = b.sticky and math.huge or (b.started + b.hold)
  b.timer:SetShown(not b.sticky)
  b.paused = nil
  b.still = ns.ReduceMotion()
  b:SetAlpha(b.still and 1 or 0)
  b:Show()
  table.insert(shown, 1, b)
  while #shown > MAX_SHOWN do
    local old = table.remove(shown)
    old:Hide()
    pool[#pool + 1] = old
  end
  layout()
  if not ticker then ticker = C_Timer.NewTicker(0.02, tick) end
  ns.SpeakAlert(ns.T(title or k.title), text)
  ns.FlashForAlert()
  return b
end

-- For screenshots and tests: the banners showing now.
function ns.ShownBanners() return shown end

-- Open the game's colour picker for a kind of banner. onChange runs as the colour changes.
function ns.PickBannerColor(kind, onChange)
  if not ColorPickerFrame then return end
  local old = ns.db.bannerColors and ns.db.bannerColors[kind]
  local c = ns.BannerColor(kind)
  local function changed()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    ns.SetBannerColor(kind, r, g, b)
    if onChange then onChange() end
  end
  local function cancelled()
    ns.db.bannerColors = ns.db.bannerColors or {}
    ns.db.bannerColors[kind] = old
    if onChange then onChange() end
  end
  if ColorPickerFrame.SetupColorPickerAndShow then
    ColorPickerFrame:SetupColorPickerAndShow({ r = c[1], g = c[2], b = c[3], hasOpacity = false,
      swatchFunc = changed, cancelFunc = cancelled })
  else
    ColorPickerFrame:Hide()
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame.previousValues = { c[1], c[2], c[3] }
    ColorPickerFrame.func, ColorPickerFrame.cancelFunc = changed, cancelled
    ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
    ShowUIPanel(ColorPickerFrame)
  end
end
