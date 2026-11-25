"""Battleground and arena kills don't count: only world PvP does."""
from harness import Guild, START

M = [("Alice", 1), ("Bob", 3)]


def kill(c, kind, zone, victim="Orc"):
    return c.ns.MergeKill(c.lua.eval('{ t = %d, kind = "%s", victim = "%s", zone = "%s", killers = { "Alice" } }'
                                     % (START - 600, kind, victim, zone)))


def test_battleground_kills_are_not_logged():
    a = Guild(M)["Alice"]
    assert not kill(a, "kill_bg", "Warsong Gulch")
    assert not kill(a, "kill_world", "Arathi Basin", "Orc2")   # old versions sent some as world kills
    assert not kill(a, "kill_world", "Nagrand Arena", "Orc3")
    assert kill(a, "kill_world", "Ashenvale", "Orc4")
    assert len(list(a.ns.db.killLog.values())) == 1


def test_knows_when_you_are_in_a_battleground():
    a = Guild(M)["Alice"]
    assert not a.ns.InBattleground()
    a.run('inInstance, instanceType = true, "pvp"')
    assert a.ns.InBattleground()
    a.run('inInstance, instanceType = true, "arena"')
    assert a.ns.InBattleground()
    a.run('inInstance, instanceType = false, "none"; GetRealZoneText = function() return "Alterac Valley" end')
    assert a.ns.InBattleground()


def test_old_battleground_kills_are_dropped():
    a = Guild(M)["Alice"]
    for t, kind, v, z in ((START - 300, "kill_bg", "A", "Warsong Gulch"), (START - 200, "kill_world", "B", "Eye of the Storm"),
                          (START - 100, "kill_world", "C", "Duskwood")):
        a.lua.eval("function(log, k) table.insert(log, k) end")(
            a.ns.db.killLog, a.lua.eval('{ t = %d, kind = "%s", victim = "%s", zone = "%s", killers = { "Alice" } }' % (t, kind, v, z)))
    assert a.ns.DropBattlegroundKills() == 2
    log = a.ns.db.killLog
    assert [log[i].victim for i in range(1, len(log) + 1)] == ["C"]
    assert a.errors() == []
