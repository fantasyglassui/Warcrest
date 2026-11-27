--[[
  Warcrest
  Titles in chat: when a guildmate with a Warcrest title says something
  (guild, officer, say, yell, party, raid, whispers and chat channels), your
  chat window shows their title in gold at the start of the message:
      [Lyra]: (the Avenger) anyone up for Tarren Mill?
  This only changes what your own chat window shows; the message itself is
  untouched, so players without Warcrest see it as normal.

  It's off unless you turn it on (Achievements > Titles > Show titles in
  chat): on WoW: Forever, changing chat lines can make the game block the
  chat window's own actions in combat ("The game blocked ChatFrame1:Show()").
  While it's off, Warcrest doesn't touch chat at all.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local EVENTS = {
  "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY",
  "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
  "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL",
}
local GOLD = "|cffd4af37"


-- What the last chat lines looked like, for /warcrest report: why a title did or didn't show.
local seen = { lines = 0, apis = {} }
ns.chatTitleSeen = seen

-- The message with the author's title in front, or nil to leave it alone (and why).
function ns.TitledChatText(msg, author)
  if not ns.db or not ns.db.chatTitles then return nil, "titles in chat are off" end
  if issecretvalue and (issecretvalue(msg) or issecretvalue(author)) then return nil, "the game hid the line" end
  if type(msg) ~= "string" or type(author) ~= "string" or author == "" then
    return nil, "no author (" .. type(author) .. ")"
  end
  if msg:sub(1, #GOLD + 1) == GOLD .. "(" then return nil, "title already shown" end -- added once only
  if not ns.Member or not ns.Member(author) then return nil, "not found in the roster" end -- guildmates only
  local title = ns.TitleOf and ns.TitleOf(Ambiguate(author, "short"))
  if not title then return nil, "no title chosen or earned" end
  return GOLD .. "(" .. ns.T(title) .. ")|r " .. msg, "title shown"
end

local function filter(_, event, msg, author, ...)
  local ok, text, why = pcall(ns.TitledChatText, msg, author)
  seen.lines = seen.lines + 1
  if not (issecretvalue and issecretvalue(author)) then
    seen.last = { event = event, author = type(author) == "string" and author or type(author),
      why = ok and why or ("error: " .. tostring(text)), t = time() }
  end
  if ok and text then return false, text, author, ... end
  return false, msg, author, ...
end

-- Add the filter with the game's way of doing it (and the old way, when only
-- that one is there). Only while titles in chat are on.
local adding = false
local function addFilter()
  if adding or #seen.apis > 0 then return end
  adding = true
  local add, name = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter, "ChatFrameUtil"
  if type(add) ~= "function" then add, name = _G.ChatFrame_AddMessageEventFilter, "ChatFrame_AddMessageEventFilter" end
  if type(add) == "function" and pcall(function() for _, e in ipairs(EVENTS) do add(e, filter) end end) then
    seen.apis[1] = name
  end
  adding = false
end

local function removeFilter()
  local remove = ChatFrameUtil and ChatFrameUtil.RemoveMessageEventFilter or _G.ChatFrame_RemoveMessageEventFilter
  if type(remove) == "function" then pcall(function() for _, e in ipairs(EVENTS) do remove(e, filter) end end) end
  seen.apis = {}
end

-- Turn titles in chat on or off. Off needs a /reload to be fully clear of the game's chat.
function ns.SetChatTitles(on)
  ns.db.chatTitles = on and true or false
  if on then addFilter() else removeFilter() end
end

ns.OnLoad(function()
  -- Off for everyone once (4.5.3): it was on by default, and it can make the
  -- game block the chat window's actions in combat.
  if not ns.db.chatTitlesOptIn then
    ns.db.chatTitlesOptIn = true
    ns.db.chatTitles = false
  end
  if ns.db.chatTitles then addFilter() end
end)

-- For /warcrest report.
function ns.ChatTitleReport()
  local me = UnitName("player")
  local mine = ns.TitleOf and ns.TitleOf(me)
  local lines = {
    ("Titles in chat: %s, filter added with %s, %d chat lines seen"):format(ns.db.chatTitles and "on" or "off",
      #seen.apis > 0 and table.concat(seen.apis, " and ") or "nothing", seen.lines),
    ("Your title: %s"):format(mine or "none"),
  }
  local l = seen.last
  if l then
    lines[#lines + 1] = ("Last chat line: %s from \"%s\" (%s)"):format(l.event or "?", l.author or "?", l.why or "?")
  end
  return table.concat(lines, "\n")
end
