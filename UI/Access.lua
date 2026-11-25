--[[
  Warcrest
  Accessibility (Settings > Accessibility), all off until a player turns them on:
    - Text size: Warcrest's text at 100-130%, without scaling whole windows.
    - Font: Warcrest's own (Inter), the game's font, or a plain one; thicker
      letters (an outline) and more space between lines.
    - Colour-blind friendly colours: alert colours, and good/bad colours, that
      stay apart with red-green or blue-yellow colour blindness (Okabe-Ito).
      Every alert also names its kind in words, so colour is never the only cue.
    - High contrast: brighter secondary text, stronger borders and lines.
    - Alert banners: how long they stay (normal, longer, until dismissed), their
      size, no slide or fade, reading them aloud (the game's text to speech), and
      flashing the game's taskbar icon.
  Colours are set before any window is built, so changing them in a session
  needs a /reload for windows already open; text size and banners change at once.
]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local function has(list, v)
  for _, x in ipairs(list) do if x == v then return true end end
end

local function hex(h)
  return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
end

ns.TEXT_SIZES = { 100, 110, 120, 130 }
ns.BANNER_HOLDS = { "normal", "long", "sticky" }
ns.BANNER_SIZES = { 100, 125, 150 }
ns.FONT_FACES = { "warcrest", "game", "plain" }
local FACES = {
  game = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
  plain = "Fonts\\ARIALN.TTF",
}
local DEFAULTS = { textSize = 100, colorblind = false, contrast = false, bannerHold = "normal", reduceMotion = false,
  font = "warcrest", outline = false, spacing = false, bannerSize = 100, speak = false, flash = false }

-- Okabe-Ito colours, lightened a little where they'd be too dark on Warcrest's near-black.
local CB = {
  vermillion = "f0743a", orange = "e69f00", sky = "56b4e9", green = "2fb98f",
  yellow = "f0e442", purple = "cc79a7",
}
local CB_KINDS = {
  kill = "vermillion", death = "purple", wanted = "orange", streak = "yellow", revenge = "vermillion",
  champion = "yellow", bounty = "orange", boss = "yellow", raid = "sky", rival = "orange", event = "green",
  loot = "yellow", achievement = "yellow", celebrate = "sky",
}
-- The theme's own colours in each mode (only the ones that change).
local CB_THEME = { good = CB.sky, bad = CB.vermillion, warn = CB.orange }
local CONTRAST_THEME = {
  textSoft = "e6e9ef", muted = "b6bfcc", faint = "9ca6b6", navText = "ccd3de",
  edge = "434d5e", line = "333b48", cardEdge = "3a4352",
}
-- Chat colours for kills and deaths (normally green and red).
local CB_CHAT = { kill = CB.sky, death = CB.vermillion }

local original = {} -- the theme's colours as shipped, to go back to
for k, c in pairs(C) do original[k] = { c[1], c[2], c[3] } end

function ns.Access()
  local a = ns.db and ns.db.access
  return a or DEFAULTS
end

-- Text: every Warcrest font at the chosen size, in the theme's (current) colours.
function UI.ApplyFonts()
  local a = ns.Access()
  local pct = a.textSize or 100
  local face = FACES[a.font]
  local flags = a.outline and "OUTLINE" or ""
  for key, base in pairs(UI.FontBase) do
    local f = UI.Fonts[key]
    local size = math.floor(base.size * pct / 100 + 0.5)
    if f:SetFont(face or UI.FontFile(base.weight), size, flags) == false then
      f:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, flags)
    end
    f:SetTextColor(base.color[1], base.color[2], base.color[3])
    if f.SetSpacing then f:SetSpacing(a.spacing and math.floor(size * 0.35 + 0.5) or 0) end
  end
end

-- Colours: the theme as shipped, then high contrast and colour-blind changes on top.
-- The colour tables are changed in place, so everything built afterwards uses them.
function UI.ApplyColors()
  local a = ns.Access()
  for k, c in pairs(original) do C[k][1], C[k][2], C[k][3] = c[1], c[2], c[3] end
  if a.contrast then
    for k, h in pairs(CONTRAST_THEME) do C[k][1], C[k][2], C[k][3] = hex(h) end
  end
  if a.colorblind then
    for k, h in pairs(CB_THEME) do C[k][1], C[k][2], C[k][3] = hex(h) end
  end
  UI.ApplyFonts()
end

-- An alert kind's colour ({ r, g, b }), or nil to use its usual one.
function ns.AccessKindColor(kind)
  local name = ns.Access().colorblind and CB_KINDS[kind]
  if name then return { hex(CB[name]) } end
end

-- A chat colour code for "kill" or "death", or nil for the usual one.
function ns.AccessChatColor(what)
  local h = ns.Access().colorblind and CB_CHAT[what]
  return h and ("|cff" .. h) or nil
end

-- How long a banner stays: its usual time, twice that, or until it's dismissed (nil).
function ns.BannerHold(seconds)
  local hold = ns.Access().bannerHold
  if hold == "sticky" then return nil end
  if hold == "long" then return seconds * 2 end
  return seconds
end

function ns.ReduceMotion() return ns.Access().reduceMotion == true end

-- Alert banners' size, as a scale (1, 1.25 or 1.5).
function ns.BannerScale() return (ns.Access().bannerSize or 100) / 100 end

-- Text without colour codes, icons or links, the way it's read aloud.
function ns.PlainText(text)
  text = tostring(text or "")
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
  text = text:gsub("|H.-|h(.-)|h", "%1")
  text = text:gsub("|n", ". "):gsub("%s+", " ")
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Settings > Accessibility > Read alerts aloud: the game's text to speech says
-- the alert, with the voice, speed and volume picked in the game's own options
-- (Accessibility > Text to speech). Nothing happens on clients without it.
local function speak(text)
  local voice = 0
  if C_TTSSettings and C_TTSSettings.GetVoiceOptionID then
    voice = C_TTSSettings.GetVoiceOptionID(0) or 0
  end
  local rate = C_TTSSettings and C_TTSSettings.GetSpeechRate and C_TTSSettings.GetSpeechRate() or 0
  local volume = C_TTSSettings and C_TTSSettings.GetSpeechVolume and C_TTSSettings.GetSpeechVolume() or 100
  C_VoiceChat.SpeakText(voice, text, rate, volume, false)
end

-- Settings > Accessibility > Flash the taskbar icon: only does anything while
-- the game is in the background.
function ns.FlashForAlert()
  if ns.Access().flash and FlashClientIcon then pcall(FlashClientIcon) return true end
  return false
end

function ns.SpeakAlert(title, text)
  if not ns.Access().speak then return false end
  if not (C_VoiceChat and C_VoiceChat.SpeakText) then return false end
  local said = ns.PlainText(text)
  if title and title ~= "" then said = ns.PlainText(title) .. ". " .. said end
  if said == "" then return false end
  return (pcall(speak, said))
end

-- Change a setting. Colours need a /reload for windows already built.
function ns.SetAccess(key, value)
  local a = ns.db.access
  if a[key] == value then return end
  a[key] = value
  if key == "textSize" or key == "font" or key == "outline" or key == "spacing" then
    UI.ApplyFonts()
  elseif key == "colorblind" or key == "contrast" then
    UI.ApplyColors()
    ns.Say("Colours changed. Type /reload to see them in every window.")
  end
end

ns.OnLoad(function()
  local a = ns.db.access or {}
  ns.db.access = a
  if not has(ns.TEXT_SIZES, a.textSize) then a.textSize = 100 end
  if not has(ns.BANNER_HOLDS, a.bannerHold) then a.bannerHold = "normal" end
  if not has(ns.BANNER_SIZES, a.bannerSize) then a.bannerSize = 100 end
  if not has(ns.FONT_FACES, a.font) then a.font = "warcrest" end
  a.colorblind, a.contrast, a.reduceMotion = a.colorblind == true, a.contrast == true, a.reduceMotion == true
  a.outline, a.spacing, a.speak, a.flash = a.outline == true, a.spacing == true, a.speak == true, a.flash == true
  if a.colorblind or a.contrast or a.textSize ~= 100 or a.font ~= "warcrest" or a.outline or a.spacing then
    UI.ApplyColors()
  end
end)
