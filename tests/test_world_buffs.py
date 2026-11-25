"""Events > World buffs: world buffs dropped and world bosses seen, shared with the guild."""
from harness import Guild

MEMBERS = [("Alice", 1), ("Bob", 3), ("Cara", 3)]


def setup():
    guild = Guild(MEMBERS)
    for c in guild.clients.values():
        c.login()
    guild.run(30)
    return guild


def give_buff(c, spell, left, duration):
    c.run('auras.player = { { spellId = %d, expirationTime = GetTime() + %d, duration = %d } }' % (spell, left, duration))
    c.fire("UNIT_AURA", "player")


def test_a_fresh_world_buff_is_shared_with_the_guild():
    guild = setup()
    alice, bob = guild["Alice"], guild["Bob"]
    give_buff(alice, 22888, 7195, 7200)
    guild.run(3)
    last = bob.ns.LastWorldBuffs()
    assert last["dragonslayer"] is not None and last["dragonslayer"].by == "Alice"
    assert bob.said("Rallying Cry of the Dragonslayer dropped in Stranglethorn Vale")
    # The same drop again (another aura update) isn't sent twice.
    sent = len([m for m in guild.sent if "WB" in str(m)])
    alice.fire("UNIT_AURA", "player")
    guild.run(3)
    assert len([m for m in guild.sent if "WB" in str(m)]) == sent
    assert not alice.errors() and not bob.errors()


def test_an_old_buff_is_not_a_new_drop():
    guild = setup()
    give_buff(guild["Alice"], 16609, 1800, 3600)  # half gone: picked up long ago
    guild.run(3)
    assert guild["Bob"].ns.LastWorldBuffs()["warchief"] is None


def test_world_boss_sightings_are_shared_once():
    guild = setup()
    alice, bob = guild["Alice"], guild["Bob"]
    alice.run('units.target = { name = "Azuregos", npc = 6109 }')
    guild.run(5)
    s = bob.ns.BossSightings()
    assert len(s) == 1 and s[1].key == "azuregos" and not s[1].dead
    guild.run(10)
    assert len(bob.ns.BossSightings()) == 1
    alice.run('units.target.dead = true')
    guild.run(5)
    assert bob.ns.BossSightings()[1].dead


def test_alerts_can_be_turned_off():
    guild = setup()
    bob = guild["Bob"]
    bob.ns.db.worldBuffAlerts = False
    bob.said()
    give_buff(guild["Alice"], 24425, 7200, 7200)
    guild.run(3)
    assert bob.ns.LastWorldBuffs()["zandalar"] is not None
    assert not bob.said("Spirit of Zandalar")


def test_latecomers_catch_up():
    guild = Guild(MEMBERS)
    alice, cara = guild["Alice"], guild["Cara"]
    guild.set_online("Cara", False)
    alice.login(); guild["Bob"].login()
    guild.run(30)
    give_buff(alice, 22888, 7200, 7200)
    guild.run(3)
    guild.set_online("Cara", True)
    cara.login()
    guild.run(60)
    assert cara.ns.LastWorldBuffs()["dragonslayer"] is not None


def test_the_view_shows_without_errors():
    guild = setup()
    give_buff(guild["Alice"], 22888, 7200, 7200)
    guild["Alice"].run('units.target = { name = "Kazzak", npc = 12397 }')
    guild.run(5)
    bob = guild["Bob"]
    bob.ns.OpenPanel("worldbuffs")
    guild.run(1)
    assert not bob.errors()
