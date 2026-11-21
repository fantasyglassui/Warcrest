--[[
  Warcrest
  Your profile: what you tell the guild about yourself. Main spec and role,
  the days and times you usually play, your birthday and a short note. Your
  item level is added from the gear you're wearing. Opened from your player
  card (Edit profile), Guild > Profiles, or /warcrest profile. Everyone's
  profiles are the Guild > Profiles view (/warcrest profiles).
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate
local UI = ns.UI

local W, H = 480, 350
local win
local days = {}
local role = ""
local month = 0

local function monthOptions()
  local opts = { { 0, ns.T("Month") } }
  for i, name in ipairs(ns.MONTH_NAMES) do opts[#opts + 1] = { i, ns.T(name) } end
  return opts
end

local function paintDays()
  for i, b in ipairs(win.dayButtons) do b:SetStyle(days[i] and "primary" or nil) end
end

local function load()
  local p = ns.MemberProfile(UnitName("player"))
  win.spec:SetText(p and p.spec or "")
  role = p and p.role or ""
  win.role:SetValue(role)
  for i = 1, 7 do days[i] = p and p.days[i] or false end
  paintDays()
  win.hours:SetText(p and p.hours or "")
  win.hours.hint:SetShown(win.hours:GetText() == "")
  local m, d = (p and p.bday or ""):match("^(%d%d)%-(%d%d)$")
  month = tonumber(m) or 0
  local opts = monthOptions()
  win.month.options = opts
  win.month.index = month + 1
  win.month.value = month
  win.month:SetText(opts[month + 1][2])
  win.day:SetText(d and tostring(tonumber(d)) or "")
  win.note:SetText(p and p.note or "")
  local ilvl = ns.MyItemLevel()
  win.ilvl:SetText(ilvl > 0 and ns.TF("Your item level: %d. It's shared with your profile and kept up to date as your gear changes.", ilvl)
    or ns.T("Your item level is shared with your profile and kept up to date as your gear changes."))
end

local function save()
  local bday = ""
  local d = tonumber(win.day:GetText() or "")
  if month > 0 and d and d >= 1 and d <= 31 then bday = ("%02d-%02d"):format(month, d) end
  local e = ns.SaveMyProfile({ spec = win.spec:GetText(), role = role, days = days, hours = win.hours:GetText(),
    bday = bday, note = win.note:GetText() })
  if e then
    win:Hide()
    if ns.RefreshPanel then ns.RefreshPanel() end
  end
end

local function Build()
  win = UI.Window("WarcrestProfile", W, H, ns.T("Your profile"))
  local x, inner = 16, W - 32

  UI.Label(win, "Tell the guild about yourself. It shows on your player card.", "MutedSmall"):SetPoint("TOPLEFT", x, -42)

  UI.FieldLabel(win, "Main spec", x, -66)
  win.spec = UI.EditBox(win, 190, 24)
  win.spec:SetHeight(26)
  win.spec:SetPoint("TOPLEFT", x, -78)
  UI.FieldLabel(win, "Role", x + 202, -66)
  win.role = UI.Segmented(win, { { "", "None" }, { "tank", "Tank" }, { "healer", "Healer" }, { "dps", "DPS" } },
    function(v) role = v end)
  win.role:SetPoint("TOPLEFT", x + 202, -78)

  UI.FieldLabel(win, "Days you usually play", x, -116)
  win.dayButtons = {}
  local bw = math.floor((inner - 6 * 4) / 7)
  for i, name in ipairs(ns.PROFILE_DAYS) do
    local b = UI.Button(win, name, bw)
    b:SetHeight(24)
    b:SetPoint("TOPLEFT", x + (i - 1) * (bw + 4), -128)
    b:SetScript("OnClick", function() days[i] = not days[i]; paintDays() end)
    win.dayButtons[i] = b
  end

  UI.FieldLabel(win, "Times (24-hour, your time)", x, -164)
  win.hours = UI.EditBox(win, 140, 11)
  win.hours:SetHeight(26)
  win.hours:SetPoint("TOPLEFT", x, -176)
  win.hours.hint = UI.Label(win.hours, "19:00-23:00", "MutedSmall")
  win.hours.hint:SetPoint("LEFT", 8, 0)
  win.hours:HookScript("OnTextChanged", function(self) self.hint:SetShown((self:GetText() or "") == "") end)

  UI.FieldLabel(win, "Birthday (optional)", x + 202, -164)
  win.month = UI.Cycle(win, 130, monthOptions(), function(v) month = v end)
  win.month:SetHeight(26)
  win.month:SetPoint("TOPLEFT", x + 202, -176)
  win.day = UI.EditBox(win, 48, 2)
  win.day:SetHeight(26)
  win.day:SetNumeric(true)
  win.day:SetPoint("LEFT", win.month, "RIGHT", 6, 0)
  UI.Tooltip(win.month, "Birthday", "Click to pick the month, then type the day. The guild is told on the day (no year is shared).")

  UI.FieldLabel(win, "A short note (optional)", x, -214)
  win.note = UI.EditBox(win, inner, 80)
  win.note:SetHeight(26)
  win.note:SetPoint("TOPLEFT", x, -226)

  win.ilvl = UI.Label(win, "", "MutedSmall")
  win.ilvl:SetPoint("TOPLEFT", x, -264)
  win.ilvl:SetWidth(inner)
  win.ilvl:SetSpacing(2)

  local saveB = UI.Button(win, "Save and share", 140, "primary")
  saveB:SetHeight(28)
  saveB:SetPoint("BOTTOMLEFT", x, 16)
  saveB:SetScript("OnClick", save)
  local cancel = UI.Button(win, "Cancel", 90)
  cancel:SetHeight(28)
  cancel:SetPoint("LEFT", saveB, "RIGHT", 6, 0)
  cancel:SetScript("OnClick", function() win:Hide() end)
end

function ns.ShowProfileEditor()
  if not IsInGuild() then ns.Say("You need to be in a guild to share a profile.") return end
  if not win then Build() end
  load()
  win:Show()
end

------------------------------------------------------------------------
-- Everyone's profiles: a list to see the guild's specs, item levels and
-- who plays when (a gear check for officers planning raids).
------------------------------------------------------------------------
local LW = UI.PAGE_W
local list -- the page
local sortBy = "name"
local ROLE_TEXT = { tank = "Tank", healer = "Healer", dps = "DPS" }

local function rows()
  local out = {}
  for _, p in ipairs(ns.MemberProfiles()) do
    local m = ns.Member(p.name)
    p.classFile = m and m.classFile
    p.level = m and m.level or 0
    out[#out + 1] = p
  end
  table.sort(out, function(a, b)
    if sortBy == "ilvl" and a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
    if sortBy == "role" and a.role ~= b.role then return (a.role ~= "" and a.role or "z") < (b.role ~= "" and b.role or "z") end
    return a.name < b.name
  end)
  return out
end

local function BuildList(page)
  list = page
  local mine = UI.Button(page.headerBar, "Edit my profile", 130, "primary")
  mine:SetHeight(26)
  mine:SetPoint("RIGHT")
  mine:SetScript("OnClick", ns.ShowProfileEditor)
  list.sort = UI.Segmented(page.headerBar, { { "name", "Name" }, { "role", "Role" }, { "ilvl", "Item level" } }, function(v)
    sortBy = v
    ns.RefreshPanel()
  end)
  list.sort:SetPoint("RIGHT", mine, "LEFT", -8, 0)
  UI.Tooltip(list.sort, "Sort by", "Sort the guild's profiles by name, role or item level.")

  list.info = UI.Label(page, "", "MutedSmall")
  list.info:SetPoint("TOPLEFT", 4, -4)
  list.info:SetWidth(LW - 8)
  list.info:SetWordWrap(false)

  local box = UI.Box(page, 0, -24, LW, 386)
  local heads = { { "NAME", 12 }, { "SPEC", 170 }, { "ROLE", 330 }, { "ITEM LVL", 410 }, { "PLAYS", 500 } }
  local y = UI.TableHeads(box, heads)
  list.rows = UI.List(box, LW - 4, 386 + y - 2, 24,
    function(row)
      row.name = UI.Label(row, "", "Subheading")
      row.name:SetPoint("LEFT", 12, 0)
      row.name:SetWidth(150)
      row.name:SetWordWrap(false)
      row.spec = UI.Label(row, "", "Small")
      row.spec:SetPoint("LEFT", 170, 0)
      row.spec:SetWidth(150)
      row.spec:SetWordWrap(false)
      row.role = UI.Label(row, "", "Small")
      row.role:SetPoint("LEFT", 330, 0)
      row.ilvl = UI.Label(row, "", "Number")
      row.ilvl:SetPoint("LEFT", 410, 0)
      row.plays = UI.Label(row, "", "MutedSmall")
      row.plays:SetPoint("LEFT", 500, 0)
      row.plays:SetWidth(LW - 500 - 30)
      row.plays:SetWordWrap(false)
      UI.RowLine(row)
      row:SetScript("OnClick", function(self) ns.ShowPlayerCard(self.item.name) end)
      UI.Tooltip(row, function() return Ambiguate(row.item.name, "short") end, function()
        local p = row.item
        local lines = {}
        if p.note ~= "" then lines[#lines + 1] = "\"" .. p.note .. "\"" end
        local avail = ns.AvailabilityText(p)
        if avail ~= "" then lines[#lines + 1] = ns.T("Plays") .. ": " .. avail end
        local bday = ns.BirthdayText(p.bday)
        if bday ~= "" then lines[#lines + 1] = ns.T("Birthday") .. ": " .. bday end
        lines[#lines + 1] = ns.T("Click for their player card.")
        return table.concat(lines, "\n")
      end)
    end,
    function(row, p)
      row.name:SetText(Ambiguate(p.name, "short"))
      row.name:SetTextColor(UI.ClassColor(p.classFile))
      row.spec:SetText(p.spec ~= "" and p.spec or (UI.Code("faint") .. "-|r"))
      row.role:SetText(p.role ~= "" and ns.T(ROLE_TEXT[p.role]) or (UI.Code("faint") .. "-|r"))
      row.ilvl:SetText(p.ilvl > 0 and p.ilvl or (UI.Code("faint") .. "-|r"))
      local avail = ns.AvailabilityText(p)
      row.plays:SetText(avail ~= "" and avail or (UI.Code("faint") .. "-|r"))
    end, true)
  list.rows.frame:SetPoint("TOPLEFT", box, "TOPLEFT", 0, y - 1)
  UI.Grow(page, box, 1, 1)
  UI.Grow(page, list.rows, 1, 1)
end

local function Refresh()
  list.sort:SetValue(sortBy)
  local r = rows()
  list.rows:SetEmptyText(ns.EmptyHint("Nobody has shared a profile yet. Ask your guild to fill theirs in: /warcrest profile."))
  list.rows:SetItems(r)
  local roster = #ns.GetRoster()
  local tanks, healers, sum, geared = 0, 0, 0, 0
  for _, p in ipairs(r) do
    if p.role == "tank" then tanks = tanks + 1 elseif p.role == "healer" then healers = healers + 1 end
    if p.ilvl > 0 then sum, geared = sum + p.ilvl, geared + 1 end
  end
  list.info:SetText(ns.TF("%d of %d members have a profile · tanks: %d · healers: %d · average item level: %s",
    #r, roster, tanks, healers, geared > 0 and tostring(math.floor(sum / geared + 0.5)) or "-"))
end

-- Only while the page is showing.
function ns.RefreshProfiles()
  if list and list:IsShown() then Refresh() end
end

-- Opens Guild > Profiles.
function ns.ShowProfiles()
  ns.OpenPanel("profiles")
end

UI.AddTab({ id = "profiles", title = "Profiles", build = BuildList, refresh = Refresh })
