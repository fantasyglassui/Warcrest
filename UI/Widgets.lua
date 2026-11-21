--[[
  Warcrest
  UI widgets: shared helpers for building the guild tools window, drawn in
  the Nightwatch theme (UI/Theme.lua).
]]

local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI
local C = UI.C

UI.tabs = {} -- registered by each tab file: { id, title, build(page), refresh(page), visible(), subtitle() }

function UI.AddTab(tab) UI.tabs[#UI.tabs + 1] = tab end

-- Text set on a label or button shows translated (Core/Locale.lua) when the
-- whole text is a known piece of English.
function UI.Translated(w)
  local set = w.SetText
  w.SetText = function(self, s) return set(self, ns.T(s)) end
  return w
end

-- Text. template: one of the game's text styles (GameFontHighlight, ...) or an
-- Imperium style name (Body, Heading, ...); either way the Imperium font is used.
function UI.Label(parent, text, template)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(UI.Font(template or "Body"))
  UI.Translated(fs)
  fs:SetText(text or "")
  fs:SetJustifyH("LEFT")
  return fs
end

------------------------------------------------------------------------
-- Buttons
------------------------------------------------------------------------
-- Flat button look. style "primary": gold, for the main action on a screen.
local function skinButton(b, text, width, style)
  b:SetSize(width or 100, 22)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.border = UI.Border(b, C.edge[1], C.edge[2], C.edge[3], 1)
  local hover = b:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(1, 1, 1, 0.06)

  local fs = b:CreateFontString(nil, "OVERLAY")
  fs:SetPoint("CENTER")
  fs:SetFontObject(UI.Fonts.Button)
  b:SetFontString(fs)
  b:SetPushedTextOffset(0, -1)

  function b:SetStyle(s)
    self.style = s
    local primary = s == "primary"
    local bg = primary and C.accent or C.control
    local edge = primary and C.accent or C.edge
    self.bg:SetColorTexture(bg[1], bg[2], bg[3], 1)
    self.border:SetColor(edge[1], edge[2], edge[3], 1)
    local font = primary and UI.Fonts.ButtonAccent or UI.Fonts.Button
    self:SetNormalFontObject(font)
    self:SetHighlightFontObject(font)
    self:SetDisabledFontObject(UI.Fonts.ButtonDisabled)
  end
  b:SetStyle(style)
  UI.Translated(b)
  -- Greyed out: dim the fill so it reads as unavailable.
  b:HookScript("OnDisable", function(self) self.bg:SetAlpha(0.45) end)
  b:HookScript("OnEnable", function(self) self.bg:SetAlpha(1) end)
  b:SetText(text or "")
  return b
end

function UI.Button(parent, text, width, style)
  return skinButton(CreateFrame("Button", nil, parent), text, width, style)
end

-- A button that runs a game slash command (like /gpromote) when clicked.
-- Guild actions are protected, so addons have to go through the game's own
-- commands on a secure button instead of calling them directly.
function UI.SecureButton(parent, text, width, style)
  local b = skinButton(CreateFrame("Button", nil, parent, "SecureActionButtonTemplate"), text, width, style)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", "")
  return b
end

-- Set the command a secure button runs. Not allowed during combat.
function UI.SetCommand(b, text)
  if InCombatLockdown() then return false end
  b:SetAttribute("macrotext", text or "")
  return true
end

-- A button that cycles through options: { { value, label }, ... }
function UI.Cycle(parent, width, options, onChange)
  local b = UI.Button(parent, options[1][2], width)
  b:GetFontString():ClearAllPoints()
  b:GetFontString():SetPoint("CENTER", -6, 0)
  local chevron = UI.Icon(b, "chevron", 10, C.accent)
  chevron:SetPoint("RIGHT", -7, 0)
  b.index = 1
  b.value = options[1][1]
  b.options = options -- may be replaced later to change the choices
  b:SetScript("OnClick", function(self)
    local opts = self.options
    self.index = self.index % #opts + 1
    self.value = opts[self.index][1]
    self:SetText(opts[self.index][2])
    if onChange then onChange(self.value) end
  end)
  return b
end

-- A row of options where one is picked, like "This month | Last month | ...":
-- options { { value, label }, ... }. seg.value is the picked one; seg:SetValue(v)
-- picks one without calling onChange.
function UI.Segmented(parent, options, onChange, height)
  height = height or 26
  local seg = CreateFrame("Frame", nil, parent)
  UI.Fill(seg, C.control)
  UI.Border(seg, C.edge[1], C.edge[2], C.edge[3], 1)
  seg.buttons = {}
  local x = 3
  for i, opt in ipairs(options) do
    local b = CreateFrame("Button", nil, seg)
    b.bg = UI.Fill(b, C.edge)
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.05)
    b.text = UI.Label(b, opt[2], "Small")
    b.text:SetPoint("CENTER")
    local w = math.floor(b.text:GetStringWidth() + 22)
    b:SetSize(w, height - 6)
    b:SetPoint("TOPLEFT", x, -3)
    x = x + w
    b.value = opt[1]
    b:SetScript("OnClick", function()
      seg:SetValue(opt[1])
      if onChange then onChange(opt[1]) end
    end)
    seg.buttons[i] = b
  end
  seg:SetSize(x + 3, height)
  function seg:SetValue(v)
    self.value = v
    for _, b in ipairs(self.buttons) do
      local on = b.value == v
      b.bg:SetShown(on)
      b.text:SetFontObject(on and UI.Fonts.Button or UI.Fonts.Small)
      local c = on and C.text or C.muted
      b.text:SetTextColor(c[1], c[2], c[3])
    end
  end
  -- Show or hide one option (the rest close up).
  function seg:SetOptionShown(v, shown)
    local px = 3
    for _, b in ipairs(self.buttons) do
      if b.value == v then b.off = not shown; b:SetShown(shown) end
      if not b.off then
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", px, -3)
        px = px + b:GetWidth()
      end
    end
    self:SetWidth(px + 3)
  end
  -- Pick an option as if it were clicked (onChange runs).
  function seg:Pick(v)
    self:SetValue(v)
    if onChange then onChange(v) end
  end
  seg:SetValue(options[1][1])
  return seg
end

------------------------------------------------------------------------
-- Inputs
------------------------------------------------------------------------
-- A read-only box that selects all when clicked, ready for Ctrl+C. The caller places it.
function UI.CopyBox(parent, width, text)
  local box = UI.EditBox(parent, width)
  box:SetHeight(24)
  box:SetFontObject(UI.Fonts.Small)
  box.copyText = text
  box:SetText(text)
  box:SetCursorPosition(0)
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput then self:SetText(self.copyText); self:HighlightText() end
  end)
  box:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
  box:HookScript("OnEditFocusLost", function(self) self:HighlightText(0, 0); self:SetCursorPosition(0) end)
  -- Change what the box holds (it stays read only for the person typing).
  function box:SetCopyText(t)
    self.copyText = t
    self:SetText(t)
    self:SetCursorPosition(0)
  end
  return box
end

function UI.EditBox(parent, width, maxLetters)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetSize(width, 22)
  e:SetFontObject(UI.Fonts.Body)
  e:SetTextColor(C.text[1], C.text[2], C.text[3])
  e:SetTextInsets(7, 7, 0, 0)
  e:SetAutoFocus(false)
  e:SetMaxLetters(maxLetters or 0)
  UI.Fill(e, C.control)
  e.border = UI.Border(e, C.edge[1], C.edge[2], C.edge[3], 1)
  -- Gold edge while typing.
  e:HookScript("OnEditFocusGained", function(self) self.border:SetColor(C.accent[1], C.accent[2], C.accent[3], 0.8) end)
  e:HookScript("OnEditFocusLost", function(self) self.border:SetColor(C.edge[1], C.edge[2], C.edge[3], 1) end)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  e:SetScript("OnEnterPressed", e.ClearFocus)
  return e
end

-- A bare checkbox (no label), for list rows.
function UI.CheckBox(parent, size)
  size = size or 14
  local cb = CreateFrame("CheckButton", nil, parent)
  cb:SetSize(size, size)
  UI.Fill(cb, C.control)
  cb.border = UI.Border(cb, C.edge[1], C.edge[2], C.edge[3], 1)
  local mark = cb:CreateTexture(nil, "ARTWORK")
  mark:SetTexture(UI.IconPath("check"))
  mark:SetPoint("CENTER")
  mark:SetSize(size, size)
  mark:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
  cb:SetCheckedTexture(mark)
  local greyMark = cb:CreateTexture(nil, "ARTWORK")
  greyMark:SetTexture(UI.IconPath("check"))
  greyMark:SetPoint("CENTER")
  greyMark:SetSize(size, size)
  greyMark:SetVertexColor(C.faint[1], C.faint[2], C.faint[3])
  cb:SetDisabledCheckedTexture(greyMark)
  local hover = cb:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(1, 1, 1, 0.08)
  return cb
end

-- A checkbox with a label. x, y: where the old 26-pixel game checkbox sat, so
-- layouts built for it still line up (this one is centred on the same spot).
function UI.Check(parent, text, x, y)
  local cb = UI.CheckBox(parent, 16)
  cb:SetPoint("TOPLEFT", x + 5, y - 5)
  cb.label = UI.Label(cb, text, "Body")
  cb.label:SetPoint("LEFT", cb, "RIGHT", 7, 0)
  -- Clicking the words ticks the box too.
  cb:SetHitRectInsets(0, -(cb.label:GetStringWidth() + 10), -3, -3)
  return cb
end

-- A horizontal slider. onChange(value) is called with the stepped value.
function UI.Slider(parent, width, minValue, maxValue, step, onChange)
  local s = CreateFrame("Slider", nil, parent)
  s:SetOrientation("HORIZONTAL")
  s:SetSize(width, 18)
  s:SetMinMaxValues(minValue, maxValue)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:EnableMouseWheel(true)

  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetPoint("LEFT", 0, 0)
  track:SetPoint("RIGHT", 0, 0)
  track:SetHeight(4)
  track:SetColorTexture(C.edge[1], C.edge[2], C.edge[3], 1)

  -- The handle: the game's plain white texture, tinted gold.
  s:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
  local thumb = s:GetThumbTexture()
  if thumb then
    thumb:SetSize(8, 16)
    thumb:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
  end

  local function stepped(v) return math.floor(v / step + 0.5) * step end
  s:SetScript("OnValueChanged", function(self, v)
    if self.updating then return end
    onChange(stepped(v))
  end)
  s:SetScript("OnMouseWheel", function(self, delta)
    if not self:IsEnabled() then return end
    local lo, hi = self:GetMinMaxValues()
    self:SetValue(math.max(lo, math.min(hi, stepped(self:GetValue()) + delta * step)))
  end)

  -- Set the value without calling onChange.
  function s:SetQuietly(v)
    self.updating = true
    self:SetValue(v)
    self.updating = false
  end
  return s
end

------------------------------------------------------------------------
-- Tooltips and enabling
------------------------------------------------------------------------
-- A tooltip for a button or other control. title and text can be functions,
-- for controls whose meaning changes. Also shows while the control is greyed
-- out, so people can see what it does and why they can't use it.
function UI.Tooltip(w, title, text)
  if w.SetMotionScriptsWhileDisabled then w:SetMotionScriptsWhileDisabled(true) end
  w.hasTooltip = true
  if ns.localeSeen then ns.T(type(title) == "string" and title); ns.T(type(text) == "string" and text) end
  w:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(ns.T(type(title) == "function" and title() or title))
    local body = ns.T(type(text) == "function" and text() or text)
    if body then GameTooltip:AddLine(body, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  w:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

function UI.SetEnabled(w, on)
  -- Secure buttons can't be changed during combat.
  if InCombatLockdown() and w.IsProtected and w:IsProtected() then return end
  on = on and true or false
  if w.SetEnabled then
    w:SetEnabled(on)
  elseif on and w.Enable then
    w:Enable()
  elseif w.Disable then
    w:Disable()
  end
  if w:GetObjectType() == "EditBox" or w:GetObjectType() == "Slider" then
    w:SetAlpha(on and 1 or 0.5)
    w:EnableMouse(on)
    if not on and w.ClearFocus then w:ClearFocus() end
  elseif w.label then
    w.label:SetAlpha(on and 1 or 0.5)
  end
end

------------------------------------------------------------------------
-- Guild helpers
------------------------------------------------------------------------
function UI.ClassColor(classFile)
  local c
  if classFile then
    c = (C_ClassColor and C_ClassColor.GetClassColor(classFile)) or RAID_CLASS_COLORS[classFile]
  end
  if c then return c.r, c.g, c.b end
  return C.text[1], C.text[2], C.text[3]
end

function UI.RankName(index)
  local name = GuildControlGetRankName and GuildControlGetRankName(index + 1)
  return (name and name ~= "") and name or ("Rank " .. index)
end

function UI.NumRanks()
  return (GuildControlGetNumRanks and GuildControlGetNumRanks()) or 10
end

function UI.FormatTime(t)
  return ns.Date("%b %d %H:%M", t)
end

------------------------------------------------------------------------
-- Lists
------------------------------------------------------------------------
-- A slim scroll bar in the theme's colors, for the game's scroll frame
-- template. Only the parts that are there get restyled, so if a game version
-- builds its scroll bar differently it just keeps its usual look.
function UI.SkinScrollBar(sf)
  local bar = sf.ScrollBar
  if type(bar) ~= "table" then return end
  for _, key in ipairs({ "ScrollUpButton", "ScrollDownButton" }) do
    local b = bar[key]
    if type(b) == "table" and b.SetAlpha then
      b:SetAlpha(0)
      b:EnableMouse(false)
    end
  end
  local thumb = bar.GetThumbTexture and bar:GetThumbTexture()
  if type(thumb) == "table" and thumb.SetTexture then
    thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
    thumb:SetVertexColor(0.29, 0.33, 0.40, 1)
    thumb:SetWidth(5)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOP", 0, 0)
    track:SetPoint("BOTTOM", 0, 0)
    track:SetWidth(5)
    track:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
  end
end
-- A scrolling list on a dark card. makeRow(row) sets up a new row; fill(row,
-- item) shows an item. list:SetEmptyText(text) sets what it says when empty.
-- plain: no card of its own (for a list inside a card the caller draws).
function UI.List(parent, width, height, rowHeight, makeRow, fill, plain)
  local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  sf:SetSize(width, height)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(width - 4, 1)
  sf:SetScrollChild(content)
  UI.SkinScrollBar(sf)
  if not plain then UI.Card(sf, 2) end

  local empty = sf:CreateFontString(nil, "OVERLAY")
  empty:SetFontObject(UI.Fonts.Muted)
  empty:SetPoint("TOPLEFT", 10, -12)
  empty:SetWidth(width - 24)
  empty:SetJustifyH("LEFT")
  empty:Hide()
  UI.Translated(empty)

  -- Only the rows that fit on screen (plus one) are made. Scrolling moves
  -- them down and fills them with the items now in view, so a list of
  -- thousands costs no more than a list of twenty.
  local list = { frame = sf, rows = {}, empty = empty, width = width, height = height, items = {} }
  function list:SetEmptyText(text) self.emptyText = text end

  local function makeOne(i)
    local row = CreateFrame("Button", nil, content)
    row:SetSize(width - 4, rowHeight)
    row.stripe = row:CreateTexture(nil, "BACKGROUND") -- every other row slightly lighter, to follow a row across
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(1, 1, 1, 0.025)
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.08)
    makeRow(row)
    list.rows[i] = row
    return row
  end

  -- Fill the visible rows from the scroll position.
  local function update()
    local items = list.items
    local first = math.floor((sf:GetVerticalScroll() or 0) / rowHeight) -- items above the view
    first = math.max(0, math.min(first, math.max(0, #items - 1)))
    local visible = math.ceil(list.height / rowHeight) + 1
    for i = 1, visible do
      local index = first + i
      local item = items[index]
      local row = list.rows[i]
      if item then
        row = row or makeOne(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(index - 1) * rowHeight)
        row.index = index
        row.stripe:SetShown(index % 2 == 0)
        row.item = item
        fill(row, item)
        row:Show()
      elseif row then
        row:Hide()
      end
    end
    for i = visible + 1, #list.rows do list.rows[i]:Hide() end
  end
  list.Update = update
  sf:HookScript("OnVerticalScroll", update)
  sf:HookScript("OnScrollRangeChanged", update)

  -- A new size, rows and all (used when the window is resized).
  function list:Resize(w, h)
    width = w
    self.width, self.height = w, h
    sf:SetSize(w, h)
    content:SetWidth(w - 4)
    empty:SetWidth(w - 24)
    for _, row in ipairs(self.rows) do row:SetWidth(w - 4) end
    update()
  end

  -- Scroll so an item is in view (near the middle).
  function list:ScrollTo(index)
    local maxScroll = math.max(0, #self.items * rowHeight - self.height)
    sf:SetVerticalScroll(math.max(0, math.min(maxScroll, (index - 1) * rowHeight - self.height / 2 + rowHeight)))
    update()
  end

  function list:SetItems(items)
    self.items = items
    content:SetHeight(math.max(#items * rowHeight, 1))
    -- Keep the scroll position if it's still in range.
    local maxScroll = math.max(0, #items * rowHeight - self.height)
    if (sf:GetVerticalScroll() or 0) > maxScroll then sf:SetVerticalScroll(maxScroll) end
    update()
    empty:SetText(self.emptyText or "")
    empty:SetShown(#items == 0 and (self.emptyText or "") ~= "")
  end
  return list
end

------------------------------------------------------------------------
-- Resizing: each tab says what stretches and what moves when the window is
-- made bigger. Pages are laid out for UI.PAGE_W x UI.PAGE_H; dw and dh are
-- how much bigger the page is than that.
------------------------------------------------------------------------
UI.PAGE_W, UI.PAGE_H = 740, 450

local function growth(page)
  page.growth = page.growth or {}
  return page.growth
end

-- w (a frame, or a UI.List) gets fw x the extra width and fh x the extra height.
function UI.Grow(page, w, fw, fh)
  local bw = w.width or w:GetWidth()
  local bh = w.height or w:GetHeight()
  table.insert(growth(page), function(dw, dh)
    local nw, nh = bw + (fw or 0) * dw, bh + (fh or 0) * dh
    if w.frame then w:Resize(nw, nh) else w:SetSize(nw, nh) end -- a UI.List, or a frame
  end)
end

-- w moves right by fx x the extra width and down by fy x the extra height.
-- (Only its first anchor point moves; any others stay put.)
function UI.Follow(page, w, fx, fy)
  local points = {}
  for i = 1, w:GetNumPoints() do points[i] = { w:GetPoint(i) } end
  table.insert(growth(page), function(dw, dh)
    w:ClearAllPoints()
    for i, p in ipairs(points) do
      if i == 1 then
        w:SetPoint(p[1], p[2], p[3], p[4] + (fx or 0) * dw, p[5] - (fy or 0) * dh)
      else
        w:SetPoint(p[1], p[2], p[3], p[4], p[5])
      end
    end
  end)
end

-- Several widgets that move together.
function UI.FollowAll(page, list, fx, fy)
  for _, w in ipairs(list) do UI.Follow(page, w, fx, fy) end
end

function UI.ApplyGrowth(page, width, height)
  local dw, dh = math.max(0, width - UI.PAGE_W), math.max(0, height - UI.PAGE_H)
  for _, apply in ipairs(page.growth or {}) do apply(dw, dh) end
end

------------------------------------------------------------------------
-- Windows
------------------------------------------------------------------------
UI.windows = {} -- every UI.Window, so the size setting can scale them
-- A themed pop-up window with a title bar and a close button. Escape closes it
-- unless keepOnEscape. Returns the frame, hidden; content goes below the title
-- bar (from 32 pixels down).
function UI.Window(name, width, height, title, keepOnEscape)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetSize(width, height)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  UI.Fill(f, C.window)
  UI.Border(f, C.edge[1], C.edge[2], C.edge[3], 1)

  local bar = f:CreateTexture(nil, "BORDER") -- the title bar
  bar:SetPoint("TOPLEFT")
  bar:SetPoint("TOPRIGHT")
  bar:SetHeight(28)
  bar:SetColorTexture(C.sidebar[1], C.sidebar[2], C.sidebar[3], 1)
  local rule = f:CreateTexture(nil, "BORDER")
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", 0, -28)
  rule:SetPoint("TOPRIGHT", 0, -28)
  rule:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)

  local emblem = f:CreateTexture(nil, "ARTWORK")
  ns.Emblem(emblem, "PORTRAIT")
  emblem:SetSize(18, 18)
  emblem:SetPoint("TOPLEFT", 8, -5)
  f.title = UI.Label(f, title or "", "Subheading")
  f.title:SetPoint("LEFT", emblem, "RIGHT", 8, 0)
  f.close = UI.CloseButton(f)
  f.close:SetSize(20, 20)
  f.close:SetPoint("TOPRIGHT", -4, -4)
  if name and not keepOnEscape then tinsert(UISpecialFrames, name) end
  f:SetScale(ns.db and ns.db.panelScale or 1)
  UI.windows[#UI.windows + 1] = f
  f:Hide()
  return f
end

-- A small square close button with an X.
function UI.CloseButton(parent)
  local b = UI.Button(parent, "", 22)
  local x = UI.Icon(b, "close", 12, C.muted)
  x:SetPoint("CENTER")
  b:SetScript("OnClick", function() parent:Hide() end)
  return b
end

------------------------------------------------------------------------
-- Layout pieces shared by the tabs
------------------------------------------------------------------------
-- A card at x, y on a page, w x h, with an optional heading.
function UI.Box(parent, x, y, w, h, title)
  local f = CreateFrame("Frame", nil, parent)
  f:SetPoint("TOPLEFT", x + 1, y - 1)
  f:SetSize(w - 2, h)
  UI.Card(f, 1)
  if title then
    f.heading = UI.Label(f, title, "Heading")
    f.heading:SetPoint("TOPLEFT", 14, -12)
  end
  return f
end

-- A small capitals label over a field.
function UI.FieldLabel(parent, text, x, y)
  local fs = UI.Label(parent, ns.Upper(ns.T(text)), "Label")
  fs:SetPoint("TOPLEFT", x, y)
  return fs
end

-- Column headings across the top of a table card, with a rule under them.
-- heads: { { "NAME", x }, ... }. Returns the y below the rule.
function UI.TableHeads(card, heads)
  for _, h in ipairs(heads) do
    local fs = UI.Label(card, h[1], "Label")
    if h.right then
      fs:SetPoint("TOPRIGHT", card, "TOPLEFT", h[2], -9)
      fs:SetJustifyH("RIGHT")
    else
      fs:SetPoint("TOPLEFT", h[2], -9)
    end
  end
  local rule = card:CreateTexture(nil, "BORDER")
  rule:SetPoint("TOPLEFT", 0, -26)
  rule:SetPoint("TOPRIGHT", 0, -26)
  rule:SetHeight(1)
  rule:SetColorTexture(C.cardEdge[1], C.cardEdge[2], C.cardEdge[3], 1)
  return -27
end

-- A thin line under a table row.
function UI.RowLine(row)
  local line = row:CreateTexture(nil, "BORDER")
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")
  line:SetHeight(1)
  line:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
  return line
end

-- Selection marks for a table row: a gold tint and a gold bar on the left.
-- Show them with UI.SetRowSelected(row, on).
function UI.RowSelection(row)
  row.sel = row:CreateTexture(nil, "BACKGROUND")
  row.sel:SetAllPoints()
  row.sel:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.10)
  row.bar = row:CreateTexture(nil, "BORDER")
  row.bar:SetPoint("TOPLEFT")
  row.bar:SetPoint("BOTTOMLEFT")
  row.bar:SetWidth(2)
  row.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
end

function UI.SetRowSelected(row, on)
  row.sel:SetShown(on and true or false)
  row.bar:SetShown(on and true or false)
end

-- A search box with a magnifying glass and a hint. onChange(text).
function UI.SearchBox(parent, width, hint, onChange)
  local box = UI.EditBox(parent, width, 40)
  box:SetHeight(26)
  box:SetTextInsets(28, 8, 0, 0)
  local glass = UI.Icon(box, "search", 13, C.faint)
  glass:SetPoint("LEFT", 9, 0)
  box.hint = UI.Label(box, hint, "MutedSmall")
  box.hint:SetPoint("LEFT", 28, 0)
  box:SetScript("OnTextChanged", function(self)
    local text = self:GetText() or ""
    self.hint:SetShown(text == "")
    onChange(text)
  end)
  return box
end

-- A stat tile: a big number with a small label under it.
function UI.StatTile(parent, x, y, w, h, label)
  local t = UI.Box(parent, x, y, w, h)
  t.number = UI.Label(t, "", "Display")
  t.number:SetPoint("TOPLEFT", 14, -12)
  t.number:SetWidth(w - 28)
  t.number:SetWordWrap(false)
  t.label = UI.Label(t, ns.Upper(ns.T(label)), "Label")
  t.label:SetPoint("BOTTOMLEFT", 14, 11)
  t.label:SetWidth(w - 28)
  t.label:SetWordWrap(false)
  return t
end
