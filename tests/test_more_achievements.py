"""The 3.1 achievements: double kills, night kills, zones, grudges, rolls, attendance, full clears, alts and more."""
import time
from harness import Guild
from test_bosses import RAID, in_raid_instance, kill as boss_kill

MEMBERS = [("Alice", 1), ("Bob", 3), ("Cara", 3), ("Dan", 3), ("Eve", 3), ("Finn", 3)]


def add_kills(guild, kills):
    """kills: (killer, victim, zone, time) put straight into everyone's kill log."""
    for c in guild.clients.values():
        c.lua.eval("""function(ns, list)
          for _, k in ipairs(list) do
            table.insert(ns.db.killLog, 1, { t = k[4], victim = k[2], killers = { k[1] }, zone = k[3],
              kind = "kill_world", level = 60 })
          end
          ns.OnHistoryChanged()
        end""")(c.ns, c.lua.table_from([c.lua.table_from(list(k)) for k in kills]))
    guild.run(3)


def earned(client, name):
    return {k for k, e in client.ns.MemberAchievements(name).items() if e.t is not None}


def local_time(hour, days_ago, now):
    """A time days_ago days before now, at hour o'clock on this computer's clock."""
    d = time.localtime(now - days_ago * 86400)
    return int(time.mktime((d.tm_year, d.tm_mon, d.tm_mday, hour, 30, 0, 0, 0, -1)))


def test_double_kill_night_owl_and_globetrotter():
    guild = Guild(MEMBERS)
    now = int(guild.clock)
    day = local_time(14, 3, now)
    add_kills(guild, [("Alice", "Grim", "Duskwood", day), ("Alice", "Vex", "Duskwood", day + 8),      # double kill
                      ("Bob", "Grim", "Duskwood", day), ("Bob", "Vex", "Duskwood", day + 30),          # too slow
                      ("Cara", "Skarn", "Westfall", local_time(2, 2, now))]                            # 2:30 in the morning
             + [("Dan", "Foe%d" % i, "Zone%d" % i, day + i * 600) for i in range(15)])                 # 15 zones
    cara = guild["Cara"]
    assert "double" in earned(cara, "Alice") and "double" not in earned(cara, "Bob")
    assert "night" in earned(cara, "Cara") and "night" not in earned(cara, "Alice")
    assert "zones" in earned(cara, "Dan")
    assert cara.ns.MemberAchievements("Alice")["zones"].progress == 1


def test_grudge_match_and_hero_counts():
    guild = Guild(MEMBERS)
    now = int(guild.clock)
    add_kills(guild, [("Eve", "Grim", "Duskwood", now - 5000 + i * 900) for i in range(5)])
    got = earned(guild["Bob"], "Eve")
    assert "grudge" in got
    # Decorated and Guild Hero count everything else earned.
    progress = guild["Bob"].ns.MemberAchievements("Eve")
    metas = {"decorated", "hero", "meta50", "meta75", "meta100"}
    assert progress["hero"].progress == len(set(got) - metas)


def test_full_clear_needs_every_boss_within_a_week():
    guild = Guild(MEMBERS, raid=RAID)
    in_raid_instance(guild, "Onyxia's Lair")       # 1 boss
    boss_kill(guild, 1084, "Onyxia")
    assert "clear" in earned(guild["Bob"], "Finn")
    in_raid_instance(guild, "Barrow Deeps")         # 8 bosses: only 2 down
    boss_kill(guild, 3001, "Gravewarden Ulric")
    boss_kill(guild, 3002, "The Hollow King")
    progress = guild["Bob"].ns.RaidProgress()
    assert any(r.raid == "Barrow Deeps" and r.killed == 2 for r in progress.values())


def test_perfect_attendance():
    guild = Guild(MEMBERS, raid=["Alice", "Bob", "Cara"])
    a = guild["Alice"].ns
    # Four raid nights last month, Bob at all of them, Cara at three.
    guild["Alice"].lua.eval("""function(ns, now)
      local d = date("*t", now)
      local first = time({ year = d.year, month = d.month - 1, day = 3, hour = 20 })
      for i = 0, 3 do
        local s = ns.LedgerAdd("RS", { ref = "", onTime = 0, hourly = 0, title = "Hyjal Summit", boss = 0 })
        s.t = first + i * 7 * 86400
        local who = i == 3 and "Alice,Bob" or "Alice,Bob,Cara"
        local at = ns.LedgerAdd("AT", { ref = s.id, names = who, how = "raid" })
        at.t = s.t
      end
    end""")(a, int(guild.clock))
    guild.run(3)
    alice = guild["Alice"]
    assert "perfect" in earned(alice, "Bob")
    assert "perfect" not in earned(alice, "Cara")


def test_new_tabs_show_without_errors():
    from render import Renderer, demo_guild
    guild, me = demo_guild()
    for view in ("pvp", "hunt", "raid", "loot", "social", "guild"):
        me.ns.OpenPanel("achievements", view)
    assert len(me.ns.ACHIEVEMENTS) == 316
    assert not me.errors()
