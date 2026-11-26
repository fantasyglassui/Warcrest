--[[
  Warcrest
  Bug reports: /warcrest report opens a window with what the developer needs
  to look into a problem (versions, language, guild size, settings, how much
  history there is, other addons, and the last errors), ready to copy into
  the Discord or the website's contact form.

  No names are included: not yours, not your guild's, not your guildmates'.
]]

local _, ns = ...
local UI = ns.UI

local W, H = 600, 440
local win

local function count(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end

local function yes(v) return v and "on" or "off" end

-- The other addons that are loaded (conflicts are a common cause of trouble).
local function otherAddons()
  local num, info, loaded = C_AddOns.GetNumAddOns, C_AddOns.GetAddOnInfo, C_AddOns.IsAddOnLoaded
  local list = {}
  for i = 1, num() do
    local name = info(i)
    if type(name) == "string" and name ~= "Warcrest" and loaded(i) then list[#list + 1] = name end
  end
  table.sort(list)
  if #list == 0 then return "none" end
  return #list .. ": " .. table.concat(list, ", ")
end

-- The report's text, in English (it's read by the developer).
function ns.BugReport()
  local lines = {}
  local function add(s) lines[#lines + 1] = s end
  local version, build = "?", "?"
  if GetBuildInfo then version, build = GetBuildInfo() end
  add("Warcrest " .. tostring(ns.version) .. " bug report (" .. date("%Y-%m-%d %H:%M") .. ")")
  add("Game: " .. tostring(version) .. " (build " .. tostring(build) .. "), client " .. tostring(GetLocale and GetLocale() or "?")
    .. ", Warcrest language " .. tostring(ns.LocaleCode and ns.LocaleCode() or "?"))
  local level = UnitLevel and UnitLevel("player") or 0
  local _, class = UnitClass("player")
  add("Character: level " .. tostring(level) .. " " .. tostring(class or "?"))
  if IsInGuild() then
    local members = GetNumGuildMembers and (GetNumGuildMembers() or 0) or 0
    local users = 0
    for _, u in pairs(ns.db.addonUsers or {}) do if u.version then users = users + 1 end end
    add(("Guild: %d members, %d with Warcrest seen, you are %s"):format(members, users,
      ns.IsAddonOfficer() and "an officer" or "a member"))
  else
    add("Guild: not in a guild")
  end
  local cfg = ns.cfg or {}
  add(("Guild settings: saved %s, DKP %s, bounties %s, alerts %s"):format(
    (cfg.stamp or 0) > 0 and "yes" or "never", yes(ns.UsesDKP and ns.UsesDKP()),
    yes(ns.BountiesOn and ns.BountiesOn()), yes(cfg.enabled)))
  add(("Your settings: quiet in dungeons %s, quiet in combat %s, debug %s"):format(
    yes(ns.db.quietInstances), yes(ns.db.quietCombat), yes(ns.db.debug)))
  add(("History: %d shared records, %d kills, %d deaths, %d enemy guilds known, %d crafters"):format(
    count(ns.db.ledger), #(ns.db.killLog or {}), #(ns.db.deathLog or {}), count(ns.db.enemyGuilds), count(ns.db.crafters)))
  add(("Messages waiting to send: %d"):format(ns.QueueSize and ns.QueueSize() or 0))
  if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
    pcall(UpdateAddOnMemoryUsage)
    local ok, kb = pcall(GetAddOnMemoryUsage, "Warcrest")
    if ok and kb then add(("Memory: %.1f MB"):format(kb / 1024)) end
  end
  add("Other addons: " .. otherAddons())
  if ns.ChatTitleReport then
    local ok, text = pcall(ns.ChatTitleReport)
    if ok and text then add(text) end
  end
  local errors = ns.recentErrors or {}
  if #errors == 0 then
    add("Errors: none since you logged in")
  else
    add("Errors since you logged in (newest last):")
    for _, e in ipairs(errors) do
      add(("  [%s]%s %s"):format(date("%H:%M", e.t), e.n > 1 and (" x" .. e.n) or "", e.text))
    end
  end
  return table.concat(lines, "\n")
end

function ns.ShowBugReport()
  if not win then
    win = UI.Window("WarcrestReport", W, H, ns.T("Bug report"))
    local hint = UI.Label(win, "Press Ctrl+C to copy, then paste it in the Warcrest Discord or the contact form on warcrest-addon.com, and say what you were doing.", "MutedSmall")
    hint:SetPoint("TOPLEFT", 16, -36)
    hint:SetWidth(W - 32)
    hint:SetSpacing(2)
    local sf = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
    UI.SkinScrollBar(sf)
    UI.Card(sf, 4)
    sf:SetPoint("TOPLEFT", 16, -70)
    sf:SetPoint("BOTTOMRIGHT", -34, 16)
    local box = CreateFrame("EditBox", nil, sf)
    box:SetMultiLine(true)
    box:SetFontObject(UI.Fonts.Small)
    box:SetWidth(W - 60)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function() win:Hide() end)
    -- Keep the report as written, even if someone types in the box.
    box:SetScript("OnTextChanged", function(self, userInput)
      if userInput then self:SetText(win.text or ""); self:HighlightText() end
    end)
    sf:SetScrollChild(box)
    win.box = box
  end
  win.text = ns.BugReport()
  win.box:SetText(win.text)
  win:Show()
  win.box:SetFocus()
  win.box:HighlightText()
end
