--[[
  Warcrest
  The raid check window (Raids > Raid check): each raid member's flask,
  elixirs, food and world buffs, the least prepared first.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local W, H = 560, 460
local win

local function yes(on) return on and (UI.Code("good") .. ns.T("Yes") .. "|r") or (UI.Code("bad") .. ns.T("No") .. "|r") end
local function count(n) return n > 0 and (UI.Code("good") .. n .. "|r") or (UI.Code("faint") .. "0|r") end

local function Refresh()
  local rows, why = ns.RaidCheck()
  if not rows then
    win.list:SetEmptyText(why == "combat" and "The game hides buffs during combat. Check again after the fight."
      or "Join a raid or a party to check it.")
    win.list:SetItems({})
    win.summary:SetText("")
    return
  end
  local flasks, fed = 0, 0
  for _, r in ipairs(rows) do
    if r.flask then flasks = flasks + 1 end
    if r.food then fed = fed + 1 end
  end
  win.summary:SetText(ns.TF("%d members · %d with a flask · %d fed", #rows, flasks, fed))
  win.list:SetEmptyText("Nobody in the group.")
  win.list:SetItems(rows)
end

local function Build()
  win = UI.Window("WarcrestRaidCheck", W, H, ns.T("Raid check"))
  win.summary = UI.Label(win, "", "Small")
  win.summary:SetPoint("TOPLEFT", 16, -42)
  local again = UI.Button(win, "Check again", 120)
  again:SetHeight(24)
  again:SetPoint("TOPRIGHT", -16, -38)
  again:SetScript("OnClick", Refresh)

  local card = UI.Box(win, 15, -72, W - 30, H - 110)
  local heads = { { "MEMBER", 12 }, { "FLASK", 200 }, { "ELIXIRS", 280 }, { "FOOD", 370 }, { "WORLD BUFFS", 430 } }
  local y = UI.TableHeads(card, heads)
  win.list = UI.List(card, W - 54, H - 110 + y - 2, 24,
    function(row)
      row.cols = {}
      for i, h in ipairs(heads) do
        local fs = UI.Label(row, "", i == 1 and "Subheading" or "Small")
        fs:SetPoint("LEFT", h[2], 0)
        fs:SetWidth(i == 1 and 180 or 70)
        fs:SetWordWrap(false)
        row.cols[i] = fs
      end
      UI.RowLine(row)
    end,
    function(row, r)
      row.cols[1]:SetText(r.name)
      row.cols[1]:SetTextColor(UI.ClassColor(r.classFile))
      row.cols[1]:SetAlpha(r.here and 1 or 0.5)
      row.cols[2]:SetText(yes(r.flask))
      row.cols[3]:SetText(count(r.elixirs))
      row.cols[4]:SetText(yes(r.food))
      row.cols[5]:SetText(count(r.world))
    end, true)
  win.list.frame:SetPoint("TOPLEFT", card, "TOPLEFT", 0, y - 1)
  local note = UI.Label(win, "Read from the game, so everyone shows, with or without Warcrest. Not during combat.", "MutedSmall")
  note:SetPoint("BOTTOMLEFT", 16, 14)
  note:SetWidth(W - 32)
end

function ns.ShowRaidCheck()
  if not win then Build() end
  Refresh()
  win:Show()
end

function ns.RaidCheckWindow() return win end
