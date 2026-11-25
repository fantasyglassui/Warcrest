--[[
  Warcrest
  Alert sounds. Every kind of alert (a guild kill, a wanted ganker spotted, a
  boss down...) has its own sound, and you can pick any sound for each one:

    - Warcrest's own 87 sounds (Media/Sounds), made for these alerts, in
      kinds: horns and fanfares, bells, drums, combat, magic, alerts,
      nature and music,
    - the game's sounds,
    - sounds from SharedMedia add-ons (LibSharedMedia), if you turn on
      "Sounds from other add-ons" (they're named by those add-ons' makers),
    - your own sound files: .ogg or .mp3 files you put in
      Interface\AddOns\WarcrestSounds (a folder of your own, so updates to
      Warcrest never touch it), added by file name in Settings > Sounds.

  Sounds play on the channel you pick (Master by default), so they follow that
  volume slider in the game's sound options.
]]

local _, ns = ...

local OWN = ns.MEDIA .. "Sounds\\"
ns.CUSTOM_SOUND_FOLDER = "Interface\\AddOns\\WarcrestSounds\\"

-- Warcrest's own sounds, by kind: file name, then the name shown.
local OWN_SOUNDS = {
  { "Horns & fanfares", {
    { "WarHorn", "War horn" }, { "BattleHorn", "Battle horn" }, { "DistantHorn", "Distant horn" },
    { "HuntHorn", "Hunting horn" }, { "RallyCry", "Rally cry" }, { "VictoryFanfare", "Victory fanfare" },
    { "RoyalFanfare", "Royal fanfare" }, { "ShortFanfare", "Short fanfare" }, { "TrumpetCall", "Trumpet call" },
    { "TriumphStab", "Triumph" }, { "GuildFirst", "Guild first" },
  } },
  { "Bells & chimes", {
    { "BellChime", "Bell chime" }, { "TripleChime", "Triple chime" }, { "DoubleBell", "Double bell" },
    { "HandBell", "Hand bell" }, { "AchievementChime", "Achievement chime" }, { "NotifyDing", "Ding" },
    { "CrystalPing", "Crystal ping" }, { "GlassTink", "Glass tink" }, { "WindChimes", "Wind chimes" },
    { "MusicBox", "Music box" }, { "TowerBell", "Tower bell" }, { "ChurchBells", "Church bells" },
    { "SingingBowl", "Singing bowl" }, { "Gong", "Gong" }, { "SkullToll", "Death toll" },
  } },
  { "Drums", {
    { "WarDrums", "War drums" }, { "TribalDrums", "Tribal drums" }, { "TaikoHit", "Taiko" },
    { "DrumRoll", "Drum roll" }, { "TimpaniRoll", "Timpani roll" }, { "SnareHit", "Snare" },
    { "Woodblock", "Woodblock" }, { "Heartbeat", "Heartbeat" }, { "HeavyImpact", "Heavy impact" },
  } },
  { "Combat", {
    { "SwordClash", "Sword clash" }, { "SwordDraw", "Sword drawn" }, { "BladeSwish", "Blade swish" },
    { "AxeChop", "Axe chop" }, { "MaceHit", "Mace hit" }, { "ShieldBash", "Shield bash" },
    { "ShieldBlock", "Shield block" }, { "Anvil", "Anvil" }, { "BowRelease", "Bow shot" },
    { "ArrowThunk", "Arrow thunk" }, { "ArrowVolley", "Arrow volley" }, { "BattleCry", "Battle cry" },
  } },
  { "Magic", {
    { "ArcaneBlast", "Arcane blast" }, { "FireWhoosh", "Fire whoosh" }, { "FrostShimmer", "Frost shimmer" },
    { "HolyLight", "Holy light" }, { "ShadowPulse", "Shadow pulse" }, { "NatureChime", "Nature chime" },
    { "Portal", "Portal" }, { "PowerUp", "Power up" }, { "MagicWhoosh", "Magic whoosh" },
    { "Sparkle", "Sparkle" }, { "LevelUp", "Level up" }, { "HeroicChoir", "Heroic choir" },
  } },
  { "Alerts", {
    { "AlarmPulse", "Alarm" }, { "WarningKlaxon", "Klaxon" }, { "Siren", "Siren" }, { "DangerRise", "Rising danger" },
    { "RadarPing", "Radar ping" }, { "BeepBeep", "Beep beep" }, { "TripleBeep", "Triple beep" },
    { "Countdown", "Countdown" }, { "TickTock", "Tick tock" }, { "ErrorBuzz", "Error buzz" },
    { "Success", "Success" }, { "SoftNotice", "Soft notice" }, { "SoftPop", "Soft pop" }, { "Coins", "Coins" },
  } },
  { "Nature", {
    { "Thunder", "Thunder" }, { "Thunderclap", "Thunderclap" }, { "RainBurst", "Rain" }, { "WindGust", "Wind" },
    { "WolfHowl", "Wolf howl" }, { "RavenCaw", "Raven" }, { "LowGrowl", "Low growl" },
  } },
  { "Music", {
    { "HarpGliss", "Harp" }, { "LutePluck", "Lute" }, { "Pizzicato", "Pizzicato" }, { "MarimbaDing", "Marimba" },
    { "FluteCall", "Flute call" }, { "OrganChord", "Organ" }, { "OminousDrone", "Ominous drone" },
  } },
}

-- The game's sounds (SOUNDKIT names). Names differ between game versions, so
-- only the ones this client has are offered.
local GAME_SOUNDS = {
  { "RAID_WARNING", "Raid warning" }, { "READY_CHECK", "Ready check" }, { "PVP_THROUGH_QUEUE", "Battleground ready" },
  { "PVP_ENTER_QUEUE", "Joined a queue" }, { "ALARM_CLOCK_WARNING_1", "Alarm clock 1" },
  { "ALARM_CLOCK_WARNING_2", "Alarm clock 2" }, { "ALARM_CLOCK_WARNING_3", "Alarm clock 3" },
  { "ACHIEVEMENT_MENU_OPEN", "Achievements open" }, { "UI_RAID_BOSS_DEFEATED", "Boss defeated" },
  { "LOOTWINDOWCOINSOUND", "Loot coins" }, { "LOOT_WINDOW_COIN_SOUND", "Loot coins (2)" },
  { "IG_BACKPACK_COIN_SELECT", "Coin pickup" }, { "MONEY_FRAME_OPEN", "Money" },
  { "TELL_MESSAGE", "Whisper" }, { "IG_PLAYER_INVITE", "Group invite" }, { "UI_BNET_TOAST", "Friend toast" },
  { "LFG_ROLE_CHECK", "Role check" }, { "LFG_REWARDS", "Dungeon rewards" }, { "UI_EPICLOOT_TOAST", "Epic loot" },
  { "UI_LEGENDARY_LOOT_TOAST", "Legendary loot" }, { "UI_WORLDQUEST_COMPLETE", "World quest complete" },
  { "UI_PET_BATTLE_START", "Pet battle start" }, { "IG_QUEST_LIST_COMPLETE", "Quest complete" },
  { "IG_QUEST_LOG_ABANDON_QUEST", "Quest abandoned" }, { "AUCTION_WINDOW_OPEN", "Auction house" },
  { "IG_CHARACTER_INFO_OPEN", "Character sheet" }, { "IG_SPELLBOOK_OPEN", "Spellbook" },
  { "UI_GARRISON_MISSION_COMPLETE_ENCOUNTER_CHANCE", "Mission complete" },
  { "UI_DIG_SITE_COMPLETION_TOAST", "Dig site done" }, { "UI_GROUP_FINDER_RECEIVE_APPLICATION", "Group applicant" },
  { "IG_MINIMAP_ZOOM_IN", "Click" }, { "UI_BATTLEGROUND_COUNTDOWN_TIMER", "Countdown" },
  { "UI_BATTLEGROUND_COUNTDOWN_FINISHED", "Countdown done" }, { "UI_CORE_NOTIFICATION", "Notification" },
  { "MAP_PING", "Map ping" }, { "IG_ABILITY_PAGE_TURN", "Page turn" }, { "UI_RAID_LOOT_TOAST_LESSER_ITEM_WON", "Item won" },
}

-- The kinds of alert with a sound, in the order Settings lists them, and the sound each starts with.
ns.SOUND_KINDS = {
  { key = "kill",        label = "Guild kill",            default = "wc:SwordClash" },
  { key = "death",       label = "Guild member down",     default = "wc:SkullToll" },
  { key = "wanted",      label = "Wanted ganker spotted", default = "wc:LowGrowl" },
  { key = "bounty",      label = "Bounty",                default = "wc:Coins" },
  { key = "streak",      label = "Kill streak",           default = "wc:WarDrums" },
  { key = "revenge",     label = "Revenge",               default = "wc:ShieldBash" },
  { key = "champion",    label = "Top head hunters",      default = "wc:VictoryFanfare" },
  { key = "boss",        label = "Boss down",             default = "wc:GuildFirst" },
  { key = "raid",        label = "Raid",                  default = "wc:WarHorn" },
  { key = "event",       label = "Guild event",           default = "wc:HandBell" },
  { key = "rival",       label = "Rival guild spotted",   default = "wc:WarHorn" },
  { key = "loot",        label = "Loot auction",          default = "wc:TripleChime" },
  { key = "achievement", label = "Achievement",           default = "wc:AchievementChime" },
  { key = "celebrate",   label = "Guild news",            default = "wc:LevelUp" },
  { key = "worldbuff",   label = "World buffs and bosses", default = "wc:WarHorn" },
}
local DEFAULTS = {}
for _, k in ipairs(ns.SOUND_KINDS) do DEFAULTS[k.key] = k.default end

ns.SOUND_CHANNELS = { { "Master", "Master" }, { "SFX", "Effects" }, { "Dialog", "Dialog" }, { "Ambience", "Ambience" },
  { "Music", "Music" } }

ns.OnLoad(function()
  ns.db.alertSounds = ns.db.alertSounds or {}   -- kind -> sound id
  ns.db.customSounds = ns.db.customSounds or {} -- list of { file, name }
  ns.db.soundChannel = ns.db.soundChannel or "Master"
end)

------------------------------------------------------------------------
-- The library
------------------------------------------------------------------------
local library, byId

local function sharedMedia()
  local lib = LibStub and LibStub("LibSharedMedia-3.0", true)
  if not (lib and lib.List and lib.Fetch) then return {} end
  local ok, names = pcall(lib.List, lib, "sound")
  if not ok or type(names) ~= "table" then return {} end
  local out = {}
  for _, name in ipairs(names) do
    local path = lib:Fetch("sound", name, true)
    -- (LibSharedMedia's own "None" is silence: Warcrest has its own.)
    if path and name ~= "None" and not tostring(path):find("Interface\\Quiet", 1, true) then
      out[#out + 1] = { id = "lsm:" .. name, name = name, group = "SharedMedia", file = path }
    end
  end
  table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
  return out
end

-- Every sound you can pick: { id, name, group, category (Warcrest's), file or kit }, in display order.
function ns.SoundLibrary()
  if library then return library end
  library, byId = {}, {}
  local function add(s) library[#library + 1] = s; byId[s.id] = s end
  add({ id = "none", name = "No sound", group = "None" })
  for _, cat in ipairs(OWN_SOUNDS) do
    for _, s in ipairs(cat[2]) do
      add({ id = "wc:" .. s[1], name = s[2], group = "Warcrest", category = cat[1], file = OWN .. s[1] .. ".ogg" })
    end
  end
  for _, c in ipairs(ns.db and ns.db.customSounds or {}) do
    add({ id = "custom:" .. c.file, name = c.name or c.file, group = "Yours", file = ns.CustomSoundPath(c.file) })
  end
  -- Other add-ons' sounds, only if you asked for them (Settings > Sounds).
  if ns.db and ns.db.sharedSounds then
    for _, s in ipairs(sharedMedia()) do add(s) end
  end
  for _, s in ipairs(GAME_SOUNDS) do
    if SOUNDKIT and SOUNDKIT[s[1]] then add({ id = "kit:" .. s[1], name = s[2], group = "Game", kit = s[1] }) end
  end
  return library
end

-- Look again (after adding your own sound, or once SharedMedia add-ons have loaded).
function ns.RefreshSoundLibrary() library, byId = nil, nil end
ns.OnEvent("PLAYER_ENTERING_WORLD", function() ns.RefreshSoundLibrary() end)

function ns.SoundByID(id)
  if not byId then ns.SoundLibrary() end
  return byId[id or ""]
end

-- A file name in your folder, or a full path if you gave one.
function ns.CustomSoundPath(file)
  if file:find("[/\\]") then return (file:gsub("/", "\\")) end
  return ns.CUSTOM_SOUND_FOLDER .. file
end

------------------------------------------------------------------------
-- Choosing and playing
------------------------------------------------------------------------
function ns.AlertSound(kind)
  local id = ns.db.alertSounds[kind or ""]
  if id and ns.SoundByID(id) then return id end
  return DEFAULTS[kind or ""] or "wc:NotifyDing"
end

function ns.SetAlertSound(kind, id)
  if not DEFAULTS[kind] then return end
  ns.db.alertSounds[kind] = (id ~= DEFAULTS[kind]) and id or nil
end

function ns.ResetAlertSounds() wipe(ns.db.alertSounds) end

-- Play a sound from the library. Returns whether the game could play it.
function ns.PlaySoundID(id)
  local s = ns.SoundByID(id)
  if not s or id == "none" then return false end
  local channel = ns.db.soundChannel or "Master"
  if s.kit then
    local ok, willPlay = pcall(PlaySound, SOUNDKIT[s.kit], channel)
    return ok and willPlay ~= false
  end
  local ok, willPlay = pcall(PlaySoundFile, s.file, channel)
  return ok and willPlay and true or false
end

-- The sound for a kind of alert, if sounds are on.
function ns.PlayAlertSound(kind)
  if not ns.db.sound then return end
  if not ns.PlaySoundID(ns.AlertSound(kind)) and ns.AlertSound(kind) ~= "none" then
    ns.PlaySoundID(DEFAULTS[kind or ""] or "wc:NotifyDing") -- a missing file: the default instead
  end
end

------------------------------------------------------------------------
-- Your own sounds
------------------------------------------------------------------------
-- file: a file name in Interface\AddOns\WarcrestSounds (or a full path). Plays
-- it to check it's there; returns true when added.
function ns.AddCustomSound(file, name)
  file = strtrim(file or ""):gsub("^[\"']", ""):gsub("[\"']$", "")
  if file == "" then return end
  if not (file:lower():find("%.ogg$") or file:lower():find("%.mp3$")) then
    ns.Say("Sound files need to be .ogg or .mp3.")
    return
  end
  for _, c in ipairs(ns.db.customSounds) do
    if c.file:lower() == file:lower() then ns.Say("That sound is already in your list.") return end
  end
  local ok, willPlay = pcall(PlaySoundFile, ns.CustomSoundPath(file), ns.db.soundChannel or "Master")
  if not (ok and willPlay) then
    ns.Say(ns.TF("Couldn't play %s. Check the file is in %s and the name is right, then restart the game "
      .. "(the game only sees new files after a restart).", file, ns.CUSTOM_SOUND_FOLDER))
    return
  end
  name = strtrim(name or "")
  if name == "" then name = file:gsub("^.*[/\\]", ""):gsub("%.%w+$", "") end
  table.insert(ns.db.customSounds, { file = file, name = name })
  ns.RefreshSoundLibrary()
  ns.Say(ns.TF("Added %s to your sounds.", name))
  return true
end

function ns.RemoveCustomSound(file)
  for i, c in ipairs(ns.db.customSounds) do
    if c.file == file then
      table.remove(ns.db.customSounds, i)
      for kind, id in pairs(ns.db.alertSounds) do
        if id == "custom:" .. file then ns.db.alertSounds[kind] = nil end
      end
      ns.RefreshSoundLibrary()
      return true
    end
  end
end
