--[[
  Warcrest
  Settings > Sounds: the sound for each kind of alert (click it to pick
  another, the play button to hear it), whether sounds play and on which
  channel, and your own sound files. The picker lists Warcrest's sounds, your
  own, SharedMedia's and the game's, with a search.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local M = {}
UI.SoundsView = M

local W, H = 740, 450
local TABLE_W = 460
local SIDE_X = TABLE_W + 14
local SIDE_W = W - SIDE_X
local INNER = SIDE_W - 30
local ROW = 26 -- 16 alert kinds fit in the box
local SOUND_X, SOUND_W = 196, 196

local GROUP_NAMES = { None = "", Warcrest = "Warcrest", Yours = "Yours", SharedMedia = "Other add-on", Game = "Game" }

local function groupTag(s)
  local g = s.category or GROUP_NAMES[s.group] or s.group
  return g ~= "" and (UI.Code("faint") .. ns.T(g) .. "|r") or ""
end

local function PlayButton(parent, size)
  local b = UI.Button(parent, "", size)
  b:SetHeight(size)
  UI.Icon(b, "play", 12, C.textSoft):SetPoint("CENTER", 1, 0)
  return b
end

------------------------------------------------------------------------
-- The picker
------------------------------------------------------------------------
local picker
local pickKind
local search = ""

local function pickerItems()
  local out, q = {}, search:lower()
  for _, s in ipairs(ns.SoundLibrary()) do
    if q == "" or ns.T(s.name):lower():find(q, 1, true) or s.name:lower():find(q, 1, true)
        or (s.category and ns.T(s.category):lower():find(q, 1, true)) then
      out[#out + 1] = s
    end
  end
  return out
end

local function refreshPicker()
  if not (picker and picker:IsShown()) then return end
  local label
  for _, k in ipairs(ns.SOUND_KINDS) do if k.key == pickKind then label = k.label end end
  picker.for_:SetText(ns.TF("Sound for: %s", ns.T(label or "")))
  picker.list:SetItems(pickerItems())
end

local function BuildPicker()
  picker = UI.Window("WarcrestSoundPicker", 380, 470, "Choose a sound")
  picker.for_ = UI.Label(picker, "", "Subheading")
  picker.for_:SetPoint("TOPLEFT", 16, -42)
  picker.for_:SetWidth(348)
  picker.for_:SetWordWrap(false)
  picker.search = UI.SearchBox(picker, 348, "Search sounds", function(text)
    search = text
    refreshPicker()
  end)
  picker.search:SetPoint("TOPLEFT", 16, -66)
  local box = UI.Box(picker, 15, -100, 350, 310)
  picker.list = UI.List(box, 340, 304, 26,
    function(row)
      UI.RowSelection(row)
      row.name = UI.Label(row, "", "Body")
      row.name:SetPoint("LEFT", 12, 0)
      row.name:SetWidth(190)
      row.name:SetWordWrap(false)
      row.group = UI.Label(row, "", "MutedSmall")
      row.group:SetPoint("RIGHT", -12, 0)
      row:SetScript("OnClick", function(self)
        ns.SetAlertSound(pickKind, self.item.id)
        ns.PlaySoundID(self.item.id)
        refreshPicker()
        if ns.RefreshPanel then ns.RefreshPanel() end
      end)
    end,
    function(row, s)
      row.name:SetText(s.name)
      row.group:SetText(groupTag(s))
      UI.SetRowSelected(row, ns.AlertSound(pickKind) == s.id)
    end, true)
  picker.list.frame:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -3)
  picker.list:SetEmptyText("No sounds match your search.")
  local hint = UI.Label(picker, "Click a sound to hear it and use it.", "MutedSmall")
  hint:SetPoint("BOTTOMLEFT", 16, 18)
  hint:SetWidth(236)
  hint:SetHeight(28)
  hint:SetJustifyV("MIDDLE")
  local done = UI.Button(picker, "Done", 100, "primary")
  done:SetHeight(28)
  done:SetPoint("BOTTOMRIGHT", -16, 14)
  done:SetScript("OnClick", function() picker:Hide() end)
end

function ns.ShowSoundPicker(kind)
  if not picker then BuildPicker() end
  pickKind = kind
  search = ""
  picker.search:SetText("")
  picker:Show()
  refreshPicker()
  -- Start with the current sound in view.
  local items = pickerItems()
  for i, s in ipairs(items) do
    if s.id == ns.AlertSound(kind) and picker.list.ScrollTo then picker.list:ScrollTo(i) end
  end
end

------------------------------------------------------------------------
-- The view
------------------------------------------------------------------------
local function BuildTable(f)
  local box = UI.Box(f, 0, 0, TABLE_W, H)
  M.table = box
  local y = UI.TableHeads(box, { { "ALERT", 14 }, { "SOUND", SOUND_X } })
  M.rows = {}
  for i, k in ipairs(ns.SOUND_KINDS) do
    local row = CreateFrame("Frame", nil, box)
    row:SetPoint("TOPLEFT", 0, y - 4 - (i - 1) * ROW)
    row:SetPoint("TOPRIGHT", 0, y - 4 - (i - 1) * ROW)
    row:SetHeight(ROW)
    local label = UI.Label(row, k.label, "Body")
    label:SetPoint("LEFT", 14, 0)
    label:SetWidth(SOUND_X - 22)
    label:SetWordWrap(false)
    row.pick = UI.Button(row, "", SOUND_W)
    row.pick:SetHeight(24)
    row.pick:SetPoint("LEFT", SOUND_X, 0)
    row.pick:SetScript("OnClick", function() ns.ShowSoundPicker(k.key) end)
    UI.Tooltip(row.pick, "Choose a sound", "Pick from Warcrest's sounds, your own, SharedMedia's and the game's.")
    row.play = PlayButton(row, 24)
    row.play:SetPoint("LEFT", row.pick, "RIGHT", 6, 0)
    row.play:SetScript("OnClick", function() ns.PlaySoundID(ns.AlertSound(k.key)) end)
    UI.Tooltip(row.play, "Play", "Hear this sound.")
    if i < #ns.SOUND_KINDS then UI.RowLine(row) end
    row.kind = k.key
    M.rows[i] = row
  end
end

local function BuildSettingsCard(f)
  local c = UI.Box(f, SIDE_X, 0, SIDE_W, 176, "Sound settings")
  M.settings = c
  M.on = UI.Check(c, "Play alert sounds", 10, -36)
  M.on:SetScript("OnClick", function(self) ns.db.sound = self:GetChecked() and true or false end)
  -- Other add-ons can share their sounds (SharedMedia). Off unless you want them.
  M.shared = UI.Check(c, "Sounds from other add-ons", 10, -62)
  M.shared:SetScript("OnClick", function(self)
    ns.db.sharedSounds = self:GetChecked() and true or false
    ns.RefreshSoundLibrary()
    ns.RefreshPanel()
  end)
  UI.Tooltip(M.shared, "Sounds from other add-ons", "Also list sounds that your other add-ons share (through "
    .. "SharedMedia). They're named by whoever made those add-ons, not by Warcrest.")
  local ch = UI.Label(c, "Channel", "Body")
  ch:SetPoint("TOPLEFT", 14, -100)
  M.channel = UI.Cycle(c, 120, ns.SOUND_CHANNELS, function(v) ns.db.soundChannel = v end)
  M.channel:SetHeight(24)
  M.channel:SetPoint("TOPRIGHT", -14, -94)
  M.channel.Sync = function(self)
    for i, o in ipairs(self.options) do
      if o[1] == (ns.db.soundChannel or "Master") then self.index, self.value = i, o[1]; self:SetText(o[2]) end
    end
  end
  UI.Tooltip(M.channel, "Channel", "Which of the game's volume sliders alert sounds follow. Master plays them even "
    .. "when game effects are turned down.")
  local reset = UI.Button(c, "Use Warcrest's sounds again", INNER)
  reset:SetHeight(26)
  reset:SetPoint("BOTTOMLEFT", 14, 14)
  reset:SetScript("OnClick", function() ns.ResetAlertSounds(); ns.RefreshPanel() end)
  UI.Tooltip(reset, "Use Warcrest's sounds again", "Puts every alert back to the sound it started with.")
end

local function BuildCustomCard(f)
  local c = UI.Box(f, SIDE_X, -190, SIDE_W, H - 190, "Your own sounds")
  M.custom = c
  local how = UI.Label(c, "Make a folder called WarcrestSounds in Interface\\AddOns, put .ogg or .mp3 files in it, "
    .. "and restart the game. Then add each one by its file name.", "MutedSmall")
  how:SetPoint("TOPLEFT", 14, -36)
  how:SetWidth(INNER)
  how:SetSpacing(2)
  UI.FieldLabel(c, "File name", 14, -92)
  M.file = UI.EditBox(c, INNER - 94, 120)
  M.file:SetHeight(26)
  M.file:SetPoint("TOPLEFT", 14, -108)
  M.file.hint = UI.Label(M.file, "For example horn.ogg", "MutedSmall")
  M.file.hint:SetPoint("LEFT", 8, 0)
  M.file:HookScript("OnTextChanged", function(self) self.hint:SetShown((self:GetText() or "") == "") end)
  local add = UI.Button(c, "Add", 86, "primary")
  add:SetHeight(26)
  add:SetPoint("LEFT", M.file, "RIGHT", 8, 0)
  add:SetScript("OnClick", function()
    if ns.AddCustomSound(M.file:GetText()) then M.file:SetText(""); M.file:ClearFocus(); ns.RefreshPanel() end
  end)
  M.file:SetScript("OnEnterPressed", function() add:Click() end)
  UI.Tooltip(add, "Add", "Plays the file to check it's there, then adds it to the sounds you can pick.")
  M.customList = UI.List(c, INNER + 4, H - 190 - 150, 24,
    function(row)
      row.name = UI.Label(row, "", "Small")
      row.name:SetPoint("LEFT", 2, 0)
      row.name:SetWidth(INNER - 70)
      row.name:SetWordWrap(false)
      row.play = PlayButton(row, 20)
      row.play:SetPoint("RIGHT", -28, 0)
      row.play:SetScript("OnClick", function(self) ns.PlaySoundID("custom:" .. self:GetParent().item.file) end)
      row.remove = UI.Button(row, "", 20)
      row.remove:SetHeight(20)
      row.remove:SetPoint("RIGHT", -2, 0)
      UI.Icon(row.remove, "close", 10, C.textSoft):SetPoint("CENTER")
      row.remove:SetScript("OnClick", function(self)
        ns.RemoveCustomSound(self:GetParent().item.file)
        ns.RefreshPanel()
      end)
      UI.Tooltip(row.remove, "Remove", "Takes it out of your list (the file stays where it is).")
    end,
    function(row, c2) row.name:SetText(c2.name .. UI.Code("faint") .. "  " .. c2.file .. "|r") end, true)
  M.customList.frame:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -144)
  M.customList:SetEmptyText("No sounds of your own yet.")
end

function M.Build(page)
  local f = CreateFrame("Frame", nil, page)
  f:SetPoint("TOPLEFT")
  f:SetSize(W, H)
  M.frame = f
  BuildTable(f)
  BuildSettingsCard(f)
  BuildCustomCard(f)
  return f
end

function M.Refresh()
  M.on:SetChecked(ns.db.sound)
  M.shared:SetChecked(ns.db.sharedSounds)
  M.channel:Sync()
  for _, row in ipairs(M.rows) do
    local s = ns.SoundByID(ns.AlertSound(row.kind))
    row.pick:SetText(s and s.name or "")
    UI.SetEnabled(row.play, s ~= nil and s.id ~= "none")
  end
  M.customList:SetItems(ns.db.customSounds)
  refreshPicker()
end
