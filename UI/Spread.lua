--[[
  Warcrest
  Spreading the word: the invite window (an officer posts it in guild chat,
  anyone else copies it) and the share window (a short text to copy).
  Opening either window sends nothing; only the Post button talks.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local function ago(t)
  local s = math.max(0, time() - t)
  if s < 120 then return ns.T("just now") end
  if s < 3600 then return ns.TF("%d min ago", math.floor(s / 60)) end
  if s < 86400 then return ns.TF("%d h ago", math.floor(s / 3600)) end
  return ns.TF("%d d ago", math.floor(s / 86400))
end

------------------------------------------------------------------------
-- Invite
------------------------------------------------------------------------
local invite

local function BuildInvite()
  local win = UI.Window("WarcrestInvite", 460, 250, ns.T("Invite the guild"))
  invite = win
  local intro = UI.Label(win, "The text below goes to guild chat when you click Post. Edit it first if you like.", "MutedSmall")
  intro:SetPoint("TOPLEFT", 16, -42)
  intro:SetWidth(428)
  win.intro = intro

  local bg = win:CreateTexture(nil, "BORDER")
  win.boxBg = bg
  bg:SetPoint("TOPLEFT", 16, -76)
  bg:SetSize(428, 64)
  bg:SetColorTexture(C.control[1], C.control[2], C.control[3], 1)
  local box = CreateFrame("EditBox", nil, win)
  box:SetMultiLine(true)
  box:SetFontObject(UI.Fonts.Small)
  box:SetTextColor(C.text[1], C.text[2], C.text[3])
  box:SetPoint("TOPLEFT", 22, -80)
  box:SetSize(416, 56)
  box:SetMaxLetters(255)
  box:SetAutoFocus(false)
  box:SetScript("OnEscapePressed", box.ClearFocus)
  win.box = box

  win.post = UI.Button(win, "Post in guild chat", 160, "primary")
  win.post:SetHeight(26)
  win.post:SetPoint("TOPLEFT", 16, -150)
  win.post:SetScript("OnClick", function()
    local ok = ns.PostGuildInvite(box:GetText())
    if ok then win:Hide() end
  end)
  UI.Tooltip(win.post, "Post in guild chat", "Sends this one message to guild chat. Warcrest never posts anything else on its own.")

  win.last = UI.Label(win, "", "MutedSmall")
  win.last:SetPoint("LEFT", win.post, "RIGHT", 12, 0)

  win.hint = UI.Label(win, "Copy this and send it to your officers.", "MutedSmall")
  win.hint:SetPoint("TOPLEFT", 16, -42)
  win.hint:SetWidth(428)
  win.copy = UI.CopyBox(win, 428, ns.InviteText())
  win.copy:SetPoint("TOPLEFT", 16, -64)
  return win
end

function ns.ShowInvite()
  local win = invite or BuildInvite()
  local can = ns.CanInvite()
  win.box:SetText(ns.InviteText())
  win.box:SetCursorPosition(0)
  win.post:SetShown(can)
  win.box:SetShown(can)
  win.boxBg:SetShown(can)
  win:SetHeight(can and 250 or 130)
  win.intro:SetShown(can)
  local last = ns.LastInvite()
  win.last:SetShown(can and last ~= nil)
  win.last:SetText(last and ns.TF("Last posted: %s", ago(last)) or "")
  -- Members can't post, so they get the same text to copy.
  win.hint:SetShown(not can)
  -- For members, getting the message is the Getting started step done.
  if not can and ns.NoteStarted then ns.NoteStarted("invite") end
  win.copy:SetShown(not can)
  win.copy:SetCopyText(ns.InviteText())
  win:Show()
  return win
end

------------------------------------------------------------------------
-- Share
------------------------------------------------------------------------
local share

function ns.ShowShare(text)
  if not share then
    share = UI.Window("WarcrestShare", 460, 130, ns.T("Share Warcrest"))
    local hint = UI.Label(share, "Click the box, press Ctrl+C, then paste it to a friend or another guild.", "MutedSmall")
    hint:SetPoint("TOPLEFT", 16, -42)
    hint:SetWidth(428)
    share.box = UI.CopyBox(share, 428, "")
    share.box:SetPoint("TOPLEFT", 16, -74)
  end
  share.box:SetCopyText(text or ns.ShareText())
  share:Show()
  if share.box.SetFocus then share.box:SetFocus() end
  return share
end
