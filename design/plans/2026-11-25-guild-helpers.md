# Guild helpers Implementation Plan

> Executed natively in this session (the author approved the design; subagents hit the usage limit last time).

**Goal:** World buffs, Groups, Cooldowns, Raid check and Inactive-with-alts, in 4.3.0.
**Spec:** design/2026-11-25-guild-helpers-design.md

## Global constraints
- Lua 5.1, `ns` namespace, `ns.OnLoad`, `ns.OnEvent`, `ns.OnMessage(kind, fn)` (one handler per kind), `ns.Send` (guild), `ns.QueueTo` (whisper).
- Message kinds must be new and unused (checked with grep): WB, WBQ, WS, GP, GX, GJ, CD, CDQ.
- Every game API call that can return secret values goes through `pcall` and `ns.Usable`.
- New files added to Warcrest.toc. New strings translated (de, fr, es). Version stays 4.3.0.

## Tasks
1. **World buffs** — `Guild/WorldBuffs.lua`, `UI/Tabs/WorldBuffs.lua` (tab `worldbuffs`, Events section).
   - `ns.WORLD_BUFFS` {key, spellID, duration}; UNIT_AURA on player: a buff with remaining ≥ duration − 60 s and not seen in the last 10 min → `ns.NoteWorldBuff(key, zone, t, by)` + `Send("WB", ...)`.
   - `ns.WORLD_BOSSES` npcID list; nameplate/target scan (1 s, shared NearbyUnits) → `ns.NoteBossSighting(npc, zone, t, dead, by)` + `Send("WS", ...)`, one per boss per 10 min.
   - Kept 24 h in `ns.db.worldBuffs`; `WBQ` at login answered (random delay) with your newest of each.
   - Alert kind `worldbuff` (banner), personal toggle `ns.db.worldBuffAlerts` (default on).
   - Tests: tests/test_world_buffs.py — buff applied → guild hears and lists it; stale buff (half duration) ignored; boss sighting shared once; toggle off silences banners.
2. **Groups** — `Guild/Groups.lua`, `UI/Tabs/Groups.lua` (tab `groups`, Guild section).
   - `ns.PostGroup(what, need, roles)`, `ns.CloseGroup()`, `ns.AskToJoin(poster, role)`, `ns.OpenGroups()`, `ns.GroupAsks()`; GP/GX broadcast, GJ whisper; 1 h expiry; poster offline → gone; `GQ` at login answered by posters.
   - Invite button calls `C_PartyInfo.InviteUnit` (or `InviteUnit`) on click.
   - Tests: tests/test_groups.py — post reaches guild; ask reaches poster only; close/expiry removes; nothing sent without a click.
3. **Cooldowns** — `Guild/Cooldowns.lua`, view `cooldowns` in UI/Tabs/Crafters.lua.
   - `ns.TRACKED_COOLDOWNS` {key, label, spells or item}; read own with `C_Spell.GetSpellCooldown`/`GetSpellCooldown`/`C_Container.GetItemCooldown` for known spells or carried item; ready time as `time()`; broadcast CD on change (throttled) and answer CDQ.
   - `ns.GuildCooldowns()` rows {name, key, readyAt}.
   - Tests: tests/test_cooldowns.py — own transmute shared with ready time; ready shows as ready; unknown spell not listed.
4. **Raid check** — `Raids/RaidCheck.lua`, `UI/RaidCheck.lua` window, button on Raids header.
   - `ns.RaidCheck()` → rows {name, flask, elixirs (n), food, world (n), missing addon irrelevant}; reads `C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")`; refuses in combat (returns nil, "combat").
   - Tests: tests/test_raid_check.py — stub auras → right counts; combat → message.
5. **Inactive with alts** — UI/Tabs/InactiveView.lua.
   - Group by `ns.MainOf`; days = min over main + alts in roster; last raid = max over them; row shows "+N alts".
   - Tests: tests/test_inactive_alts.py — main gone 60 d but alt online yesterday → not listed at 30 d; both gone → one row with alts.
6. **Ship** — translations, What's new and CHANGELOG (4.3.0), Help/wiki/site, both test passes, commit, push, zip.
