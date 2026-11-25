"""The 3.7 achievements: 117 more across PvP, hunts, raids, loot and the new
Social group, worked out from the same shared history."""
from harness import Guild
from test_more_achievements import add_kills, earned, local_time

MEMBERS = [("Alice", 1), ("Bob", 3), ("Cara", 3), ("Dan", 3), ("Eve", 3), ("Finn", 3)]


def add_deaths(guild, deaths):
    """deaths: (who, kind, sub, killer, time) put straight into everyone's death history."""
    for c in guild.clients.values():
        c.lua.eval("""function(ns, list)
          ns.db.deathLog = ns.db.deathLog or {}
          for _, d in ipairs(list) do
            table.insert(ns.db.deathLog, 1, { who = d[1], kind = d[2], sub = d[3], killer = d[4], t = d[5] })
          end
          ns.OnHistoryChanged()
        end""")(c.ns, c.lua.table_from([c.lua.table_from(list(d)) for d in deaths]))
    guild.run(3)


def ledger(client, kind, fields):
    tbl = client.lua.table_from(fields)
    assert client.ns.LedgerAdd(kind, tbl)
    client.guild.run(1)


def test_there_are_over_a_hundred_new_ones_with_unique_ids():
    guild = Guild(MEMBERS)
    ns = guild["Alice"].ns
    ids = [ns.ACHIEVEMENTS[i].id for i in range(1, len(ns.ACHIEVEMENTS) + 1)]
    assert len(ids) == len(set(ids)) == 316
    cats = {ns.ACHIEVEMENTS[i].cat for i in range(1, len(ids) + 1)}
    assert cats == {"pvp", "hunt", "raid", "loot", "social"}


def test_quick_kills_big_days_and_many_victims():
    guild = Guild(MEMBERS)
    now = int(guild.clock)
    day = local_time(14, 3, now)
    kills = [("Alice", "Foe%d" % i, "Duskwood", day + i * 9) for i in range(4)]            # 4 in 27 seconds
    kills += [("Bob", "Foe%d" % i, "Duskwood", day + i * 600) for i in range(16)]          # 16 in one day
    add_kills(guild, kills)
    cara = guild["Cara"]
    alice, bob = earned(cara, "Alice"), earned(cara, "Bob")
    assert {"double", "triple", "quad", "kill1"} <= alice
    assert "triple" not in bob and "day10" in bob and "victims10" in bob and "day20" not in bob
    assert cara.ns.MemberAchievements("Bob")["victims50"].progress == 16


def test_skulls_rivals_and_enemy_guilds():
    guild = Guild(MEMBERS)
    alice = guild["Alice"]
    alice.ns.SetRival("Bloodfang", True)
    guild.run(2)
    now = int(guild.clock)
    for c in guild.clients.values():
        c.lua.eval("""function(ns, now)
          for i = 1, 10 do
            table.insert(ns.db.killLog, 1, { t = now - 5000 + i * 60, victim = "Orc" .. i, killers = { "Dan" },
              zone = "Ashenvale", kind = "kill_world", level = (i == 1) and -1 or 60,
              vg = (i <= 8) and ("Guild" .. i) or "Bloodfang" })
          end
          ns.OnHistoryChanged()
        end""")(c.ns, now)
    guild.run(3)
    got = earned(guild["Cara"], "Dan")
    assert {"skull1", "guilds5"} <= got
    progress = guild["Cara"].ns.MemberAchievements("Dan")
    assert progress["rival10"].progress == 2


def test_deaths_vendettas_and_avenging_guildmates():
    guild = Guild(MEMBERS)
    now = int(guild.clock)
    t0 = now - 20000
    add_deaths(guild, [("Bob", "pvp", "world", "Ganker", t0 + i * 3600) for i in range(5)]       # killed 5 times
               + [("Cara", "pvp", "world", "Ganker", t0 + 4 * 3600 + 60),
                  ("Eve", "environment", "falling", "", t0),
                  ("Eve", "environment", "drowning", "", t0 + 10)])
    # Bob gets him back 10 minutes after the last time: his vendetta, and Cara avenged.
    add_kills(guild, [("Bob", "Ganker", "Duskwood", t0 + 4 * 3600 + 600)])
    dan = guild["Dan"]
    bob = earned(dan, "Bob")
    assert {"death1", "hunted", "vendetta", "revenge1", "nemesis"} <= bob
    assert dan.ns.MemberAchievements("Bob")["avenge5"].progress == 1      # Cara (not himself)
    assert {"fall", "drown"} <= earned(dan, "Eve") and "fatigue" not in earned(dan, "Eve")


def test_raid_leading_standby_and_sign_ups():
    guild = Guild(MEMBERS)
    alice = guild["Alice"]
    ledger(alice, "RS", {"ref": "", "onTime": 0, "hourly": 0, "title": "MC", "boss": 0})
    ledger(alice, "AT", {"ref": "x", "names": "Bob,Cara", "how": "standby"})
    ev = alice.ns.LedgerAdd("EV", alice.lua.table_from({"title": "MC", "start": int(guild.clock) + 86400, "notes": ""}))
    guild.run(1)
    guild["Dan"].ns.SignUp(ev.id, "accept", "dps")
    guild["Dan"].ns.SignUp(ev.id, "accept", "tank")     # changing role doesn't count twice
    guild.run(2)
    eve = guild["Eve"]
    assert "lead1" in earned(eve, "Alice")
    assert "standby1" in earned(eve, "Bob") and "standby1" in earned(eve, "Cara")
    assert eve.ns.MemberAchievements("Dan")["signup10"].progress == 1


def test_social_profile_title_levels_and_crafting():
    guild = Guild(MEMBERS)
    bob = guild["Bob"]
    ledger(bob, "PF", {"spec": "Arms", "role": "dps", "days": "", "hours": "", "bday": "", "ilvl": 60, "note": ""})
    bob.run('tradeSkill = { name = "Alchemy", rank = 300, max = 300, recipes = {'
            '{ "Major Mana Potion", "optimal", "|Hitem:13444|h[Major Mana Potion]|h" } } }')
    bob.fire("TRADE_SKILL_SHOW")
    guild.run(40)
    cara = guild["Cara"]
    got = earned(cara, "Bob")
    assert {"profile", "level50", "level", "prof1", "rank300"} <= got
    assert cara.ns.MemberAchievements("Bob")["recipes50"].progress == 1
    # Show a title: Show Off.
    assert "titled" not in earned(cara, "Bob")
    bob.ns.SetTitle("rank300")
    guild.run(2)
    assert "titled" in earned(cara, "Bob")


def test_achievements_are_recorded_several_to_an_entry():
    guild = Guild(MEMBERS)
    now = int(guild.clock)
    add_kills(guild, [("Bob", "Foe%d" % i, "Zone%d" % i, now - 9000 + i * 200) for i in range(20)])
    bob = guild["Bob"]
    bob.ns.RecordMyAchievements()
    guild.run(30)
    entries = [e for e in bob.ns.LedgerEntries("AB").values() if e.a == "Bob"]
    assert 1 <= len(entries) <= 3
    # Everyone's addon keeps them: they come back even with the kill log gone.
    cara = guild["Cara"]
    cara.ns.db.killLog = cara.lua.table_from([])
    cara.ns.db.achievements = cara.lua.table_from({})
    cara.ns.OnHistoryChanged()
    guild.run(3)
    assert {"kill10", "victims10", "zones5", "day10"} <= earned(cara, "Bob")


def test_tiles_come_in_pages():
    guild = Guild(MEMBERS)
    alice = guild["Alice"]
    alice.ns.OpenPanel("achievements", "pvp")
    guild.run(1)
    tab = alice.lua.eval("WarcrestPanel")
    assert tab is not None
    alice.ns.OpenPanel("achievements", "social")
    alice.ns.OpenPanel("achievements", "guild")
    assert alice.errors() == []
