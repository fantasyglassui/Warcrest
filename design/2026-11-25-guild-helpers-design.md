# Warcrest 4.3.0: guild helpers

*Design, 25 November 2026. Approved by the author the same day. Ships in 4.3.0 with the fixes already on `next` (one big update).*

## Why
Five things a WoW Forever guild does every week that Warcrest can make easier: catching world buffs, finding a group inside the guild, keeping track of crafting cooldowns, checking the raid is buffed before the first pull, and seeing who has really gone inactive.

## Goals
1. **World buffs and world bosses** (new view: Events > World buffs).
   - When a guildmate with Warcrest gets a world buff that has just been dropped (Rallying Cry of the Dragonslayer, Warchief's Blessing, Spirit of Zandalar), the guild hears where and when, and the view shows each buff's last drop with a timer.
   - World boss sightings (Azuregos, Lord Kazzak, Ysondre, Lethon, Emeriss, Taerar) are shared the same way, with whether it was alive or dead.
2. **Groups** (new view: Guild > Groups).
   - Post "what for" and "how many needed" (with roles). Guildmates click **Ask to join**; the poster sees who asked and clicks **Invite**.
   - Posts end after an hour, when the poster closes them, or when they log off.
3. **Profession cooldowns** (new view: Guild > Crafters > Cooldowns).
   - Transmutes, Mooncloth and the Salt Shaker: who has them and when each is ready. Each member shares their own, read from the game.
4. **Raid check** (button on Raids).
   - The raid leader (or anyone) sees, for every raid member, their flask, elixirs, food and world buffs, read straight from the game, so members without Warcrest show too. Outside combat only, since the game hides buffs in combat.
5. **Inactive, with alts** (Officers > Officer log > Inactive).
   - Linked alts are grouped under their main. A player counts as active if any of their characters was online recently; their last raid counts every character.

## Non-goals and anti-goals
- **No heat map**, ever (the author's rule).
- No automatic whispers or chat posts. Asking to join and inviting are clicks.
- No reading other players' data beyond what the game shows any player (buffs on raid members, units in sight).
- World buff timers show when a buff was last seen dropped; Warcrest doesn't guess cooldowns of the NPCs that drop them.

## Constraints
- WoW Forever runs the mainline 12.x API: auras through `C_UnitAuras`, cooldowns through `C_Spell`/`C_Container`, guarded with `pcall` and `ns.Usable` (secret values).
- Messages go through `ns.Send` (guild) and `ns.QueueTo` (whisper), never during chat lockdown (the queue already holds them).
- Every new string translated into German, French and Spanish.
- Version stays **4.3.0**.

## Approaches
- *Detecting world buffs:* from the NPC yells (text and NPC names differ per language), or from the buff itself appearing with nearly its full duration (the same in every language). **Chosen: the buff itself.**
- *Sharing groups, cooldowns, sightings:* the ledger (kept forever, synced at login) or plain messages with a short local memory. **Chosen: plain messages**, since all of it is short-lived; cooldowns and sightings are kept locally and answered when someone asks at login.
- *Raid check:* each member's addon reports, or the checker reads the raid's buffs directly. **Chosen: read directly**: works for everyone in the raid and needs no messages.

## Left to the builder
The exact spell and item IDs, message formats, layouts and wording, following the existing UI helpers (UI.Box, UI.List, UI.TableHeads, UI.Segmented) and tests in the pytest/lupa harness.
