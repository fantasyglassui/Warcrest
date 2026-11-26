-- Lua checks for The Imperium, run on every pull request by
-- .github/workflows/tests.yml. Run locally with: luacheck .
std = "lua51"
max_line_length = false
self = false -- unused "self" in methods is normal
exclude_files = { "tests/**", ".luarocks/**", ".lua/**" }

-- Globals the addon creates on purpose.
globals = {
  "WarcrestDB", "WarcrestState", "TheImperiumDB", -- saved variables (TheImperiumDB: the old name, handed over once)
  "SlashCmdList", "SLASH_WARCREST1", "SLASH_WARCREST2", "SLASH_WARCREST3", "SLASH_WARCREST4",
  "StaticPopupDialogs",
  "ColorPickerFrame",                 -- the game's colour picker (its callbacks are set on it)
  "Warcrest_OnAddonCompartmentClick", "Warcrest_OnAddonCompartmentEnter",
  "Warcrest_OnAddonCompartmentLeave",
  "WarcrestDeathPinMixin",            -- named by UI/MapPins.xml
  "BINDING_HEADER_WARCREST", "BINDING_NAME_WARCREST_TOGGLE", -- Bindings.xml
}

-- The game's own functions and tables the addon uses. A name missing here
-- is flagged, which catches typos; add new game functions as they're used.
read_globals = {
  -- 4.3.0
  "GetRealmName", "GetSpellCooldown", "C_Container", "GetItemCooldown", "IsPlayerSpell", "GetItemCount",
  "C_UnitAuras", "UnitGUID", "UnitIsDead", "C_PvP", "IsActiveBattlefieldArena", "GetMaxBattlefieldID",
  "GetBattlefieldStatus", "C_TTSSettings", "C_VoiceChat", "FlashClientIcon", "debugstack",
  -- Professions (the crafters directory) and chat
  "GetTradeSkillLine", "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillItemLink",
  "GetCraftDisplaySkillLine", "GetNumCrafts", "GetCraftInfo", "GetCraftItemLink", "GetSpellInfo",
  "ChatFrame_OpenChat", "GetGuildRosterLastOnline", "UnitClassification", "C_QuestLog", "IsQuestFlaggedCompleted",
  -- Bug reports
  "GetNumAddOns", "GetAddOnInfo", "IsAddOnLoaded", "GetBuildInfo", "UpdateAddOnMemoryUsage", "GetAddOnMemoryUsage",
  -- Lua helpers WoW adds
  "date", "time", "strsplit", "strtrim", "tinsert", "wipe", "hooksecurefunc", "issecretvalue",
  -- Profiles and recruiting
  "GetChannelList", "GetInventoryItemLink", "GetItemInfo", "GuildInvite", "SendChatMessage", "UnitIsConnected",
  "LOCALIZED_CLASS_NAMES_MALE", "ChatFrame_AddMessageEventFilter",
  -- C_ namespaces and Enum
  "C_AddOns", "C_ChatInfo", "C_TradeSkillUI", "RaidWarningUtil", "C_ClassColor", "C_DateAndTime", "C_GuildInfo", "C_Item", "C_Map",
  "C_NamePlate", "C_PartyInfo", "C_RandomRoll", "C_Spell", "C_Timer", "Enum",
  -- Units, groups and the guild
  "Ambiguate", "GetGuildInfo", "GetGuildRosterInfo", "GetGuildRosterMOTD", "GetNormalizedRealmName",
  "GetNumGroupMembers", "GetNumGuildMembers", "GetRaidRosterInfo", "GetUnitName", "GuildControlGetNumRanks",
  "GuildControlGetRankName", "GuildRoster", "GuildRosterSetOfficerNote", "GuildRosterSetPublicNote",
  "CanEditMOTD", "CanEditOfficerNote", "CanEditPublicNote", "CanGuildDemote", "CanGuildInvite",
  "CanGuildPromote", "CanGuildRemove", "CanViewOfficerNote", "ConvertToRaid", "InviteUnit",
  "IsInGroup", "IsInGuild", "GetGuildRosterShowOffline", "SetGuildRosterShowOffline", "IsInInstance", "IsInRaid", "GetInstanceInfo", "UnitIsGroupAssistant", "SetRaidSubgroup", "SwapRaidSubgroup", "GetLocale", "CreateColor", "UnitAffectingCombat", "UnitCanAttack", "UnitClass",
  "UnitExists", "UnitIsDeadOrGhost", "UnitIsFeignDeath", "UnitIsGroupLeader", "UnitIsPVP", "UnitIsPlayer",
  "UnitIsUnit", "UnitLevel", "UnitName", "UnitReaction",
  -- Game state
  "GetAddOnMetadata", "GetCursorPosition", "GetItemIcon", "GetItemInfoInstant", "GetMaxPlayerLevel",
  "GetMinimapShape", "GetPVPLifetimeStats", "GetRealZoneText", "GetServerTime", "GetTime", "GetZoneText",
  "InCombatLockdown", "IsFalling", "IsHarmfulSpell", "IsShiftKeyDown", "PlaySound", "PlaySoundFile", "LibStub", "RandomRoll",
  -- Interface
  "ChatEdit_InsertLink", "ChatFontNormal", "ChatFrameUtil", "ChatFrame_SendTell", "ChatTypeInfo", "CreateFont", "CreateFrame", "CreateFromMixins", "STANDARD_TEXT_FONT",
  "CreateVector2D", "GameTooltip", "HideUIPanel", "MapCanvasDataProviderMixin", "MapCanvasPinMixin",
  "Minimap", "Mixin", "OpenWorldMap", "PanelTemplates_SetNumTabs", "PanelTemplates_SetTab",
  "PanelTemplates_TabResize", "RaidNotice_AddMessage", "RaidWarningFrame", "Settings", "SettingsPanel",
  "ShowUIPanel", "StaticPopup_Show", "UIParent", "UISpecialFrames", "WorldMapFrame",
  -- Constants and global strings
  "CANCEL", "MAX_PLAYER_LEVEL", "NO", "OKAY", "RAID_CLASS_COLORS", "RANDOM_ROLL_RESULT", "SOUNDKIT", "YES",
  -- Other addons
  "TomTom",
}
