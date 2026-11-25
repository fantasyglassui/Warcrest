"""Groups, profession cooldowns, the raid check and inactive players with alts."""
from harness import Guild

MEMBERS = [("Alice", 1), ("Bob", 3), ("Cara", 3), ("Dan", 3), ("Danalt", 3)]


def setup(members=MEMBERS, **kw):
    guild = Guild(members, **kw)
    for c in guild.clients.values():
        c.login()
    guild.run(30)
    return guild


# Groups ---------------------------------------------------------------
def test_a_group_post_reaches_the_guild_and_asks_reach_the_poster_only():
    guild = setup()
    alice, bob, cara = guild["Alice"], guild["Bob"], guild["Cara"]
    assert alice.ns.PostGroup("Scholomance", 2, "healer,tank")
    guild.run(3)
    groups = bob.ns.OpenGroups()
    assert len(groups) == 1 and groups[1].what == "Scholomance" and groups[1].need == 2
    assert bob.ns.AskToJoin("Alice", "healer")
    guild.run(3)
    asks = alice.ns.GroupAsks()
    assert len(asks) == 1 and asks[1].name == "Bob" and asks[1].role == "healer"
    assert len(cara.ns.GroupAsks()) == 0
    assert alice.ns.InviteToGroup("Bob")
    assert "Bob" in alice.lua.eval("invited")[1]
    assert not alice.errors() and not bob.errors()


def test_closing_or_an_hour_ends_a_post():
    guild = setup()
    alice, bob = guild["Alice"], guild["Bob"]
    alice.ns.PostGroup("Stratholme", 3, "")
    guild.run(3)
    alice.ns.CloseGroup()
    guild.run(3)
    assert len(bob.ns.OpenGroups()) == 0
    alice.ns.PostGroup("Stratholme", 3, "")
    guild.run(3)
    guild.run(3700, step=10)
    assert len(bob.ns.OpenGroups()) == 0


def test_nothing_is_posted_without_a_click():
    guild = setup()
    guild.run(60)
    assert not any("GP" in str(m) for m in guild.sent)


def test_latecomers_see_open_groups():
    guild = Guild(MEMBERS)
    guild.set_online("Cara", False)
    for n in ("Alice", "Bob"):
        guild[n].login()
    guild.run(30)
    guild["Alice"].ns.PostGroup("Blackrock Depths", 4, "dps")
    guild.run(3)
    guild.set_online("Cara", True)
    guild["Cara"].login()
    guild.run(40)
    assert len(guild["Cara"].ns.OpenGroups()) == 1


# Cooldowns --------------------------------------------------------------
def test_your_cooldowns_are_shared_with_ready_times():
    def known(c):
        if c.name == "Alice":
            c.run("knownSpells[17187] = true; knownSpells[18560] = true; spellCooldowns[18560] = { GetTime() - 100, 86400 * 4 }")
    guild = setup(setup=known)
    bob = guild["Bob"]
    rows = bob.ns.GuildCooldowns()
    got = {(rows[i].name, rows[i].key): rows[i].readyAt for i in range(1, len(rows) + 1)}
    assert got[("Alice", "transmute")] == 0               # ready
    assert got[("Alice", "mooncloth")] > guild.clock + 3 * 86400
    assert ("Alice", "salt") not in got                   # no Salt Shaker
    bob.ns.OpenPanel("crafters", "cooldowns")
    guild.run(1)
    assert not bob.errors()


# Raid check -------------------------------------------------------------
def test_the_raid_check_reads_everyones_buffs():
    guild = setup(raid=["Alice", "Bob", "Cara"])
    alice = guild["Alice"]
    alice.run("""
      units.raid1 = { name = "Alice" }; units.raid2 = { name = "Bob" }; units.raid3 = { name = "Cara" }
      auras.raid1 = { { spellId = 17628 }, { spellId = 11474 }, { spellId = 19710 }, { spellId = 22888 } }
      auras.raid2 = { { spellId = 11405 } }
    """)
    rows = alice.ns.RaidCheck()
    by = {rows[i].name: rows[i] for i in range(1, len(rows) + 1)}
    assert by["Alice"].flask and by["Alice"].elixirs == 1 and by["Alice"].food and by["Alice"].world == 1
    assert not by["Bob"].flask and by["Bob"].elixirs == 1
    assert rows[1].name == "Cara"  # the least prepared first
    alice.ns.ShowRaidCheck()
    alice.run("inCombat = true")
    rows, why = alice.lua.eval("function(ns) return ns.RaidCheck() end")(alice.ns)
    assert rows is None and why == "combat"
    assert not alice.errors()


# Inactive with alts -----------------------------------------------------
def test_alts_count_with_their_main():
    guild = setup()
    guild["Danalt"].ns.RequestAltLink("Dan")
    guild.run(3)
    guild["Dan"].ns.ConfirmAlt("Danalt")
    guild.run(3)
    alice = guild["Alice"]
    guild.set_online("Dan", False)
    guild.set_online("Danalt", False)
    alice.run("""GetGuildRosterLastOnline = function(i)
      local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
      if online then return nil end
      if name:find("^Danalt") then return 0, 0, 2, 0 end      -- the alt: 2 days
      return 0, 2, 5, 0                                         -- 65 days
    end""")
    alice.ns.RosterChanged()
    assert len(list(alice.ns.InactiveMembers(30).values())) == 0  # on the alt two days ago
    away = list(alice.ns.InactiveMembers(1).values())
    assert len(away) == 1 and away[0].name == "Dan" and list(away[0].alts.values()) == ["Danalt"]
    alice.ns.OpenPanel("officers", "inactive")
    guild.run(1)
    assert not alice.errors()
